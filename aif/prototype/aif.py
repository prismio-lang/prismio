#!/usr/bin/env python3
"""
AIF inference engine -- prototype.

Implements INFERENCE.md sections 2-5 against an AST dumped by
`prismio dump-ast`. Changes no codegen and touches no compiler; it exists to
produce the three numbers that can falsify the model before any of it is built
(BENCHMARKS H1 and H4, GAPS Level 0).

It is also intended to survive as the *oracle*: once the engine is ported into
the compiler, both run over the same source and their manifests must agree.
That is differential testing against an independent implementation, and it is
the only reliable way to catch a transfer function that is subtly wrong and
produces a silently wrong tier rather than a crash.

APPROXIMATIONS -- all of them make the result more conservative (higher tiers),
never less, so a good number here is trustworthy and a bad one may be pessimistic:

  A1  Flow-insensitive. A value's facts are the join over all program points.
      INFERENCE 11.3 already accepts this for loops; here it applies everywhere.
  A2  Field-sensitive, object-insensitive -- one node per (struct, field), as
      INFERENCE 3.1 specifies. INFERENCE 11.1 is the known cost.
  A3  Context-insensitive in the whole-program pass: every function is analysed
      at the TOP context. Contexts are measured separately (see --masks), which
      is what H4's leading indicator needs.
  A4  Thread affinity is modelled (REQUIREMENTS 15, since 2026-08-19). It was
      vacuous before that -- the language had no tasks, so every value was
      Isolated and T4a was unreachable by construction. Two departures from
      INFERENCE 4.3 are worth naming because they are shared with the compiler
      and a differential cannot see a shared decision:
        * T-SPAWN-SHARE's premise "y is still live in the parent" is read off
          the aliasing domain as A = Shared, because under affine references it
          is never syntactically true. See the `spawn` constraint.
        * E-SPAWN-J's "joined on every path" is decided syntactically, over a
          straight run of statements with no early exit between spawn and join.
          Anything less obvious answers "not joined", which costs a tier rather
          than soundness. A precise answer wants a real flow analysis.
  A5  Struct sizes are approximated by field count for the T0/T1 split, since
      the dump carries no layout.
"""

import json
import sys
import argparse
from collections import defaultdict, Counter

# ---------------------------------------------------------------------------
# Fact domains (INFERENCE 2)
# ---------------------------------------------------------------------------

# Escape. Region values are ('R', scope_id); the two top elements are flat.
CALLER = ('CALLER',)
GLOBAL = ('GLOBAL',)

# Aliasing / cyclicity as small totally-ordered chains.
UNIQUE, BORROWED, SHARED = 0, 1, 2
ACYCLIC, MAYBE_CYCLIC = 0, 1

# INFERENCE 2.3. Thread affinity, added 2026-08-19 with REQUIREMENTS 15's task
# model. Before that the domain was vacuous -- A4 below said so -- and every
# value sat at ISOLATED.
ISOLATED, TRANSFERRED, CROSS_THREAD = 0, 1, 2

ALIAS_NAME = {UNIQUE: 'Unique', BORROWED: 'Borrowed', SHARED: 'Shared'}
THREAD_NAME = {ISOLATED: 'Isolated', TRANSFERRED: 'Transferred',
               CROSS_THREAD: 'CrossThread'}

REF_SCALARS = {'Int', 'I8', 'I16', 'I32', 'I64', 'U8', 'U16', 'U32', 'U64',
               'Isize', 'Usize', 'Float', 'Bool', 'Char', 'Void', ''}

# FFI contracts for the Prismio runtime surface (FFI.md 5).
#
# `retain_in(k)` is NOT in FFI.md's vocabulary and needs to be: it says the
# callee stores this argument into argument k, so the stored value escapes
# exactly as far as the container does -- no further. FFI.md offers only
# `retain`, which means "escapes globally", and that is far too coarse for a
# container API. Collections are the most common FFI shape in a systems
# language, so the omission matters.
#
# Without these, `list_push` is a `borrow` and every element pushed into a list
# looks like it never escapes -- which is optimistic, i.e. unsound.
FFI_CONTRACTS = {
    # name          : {arg_index: contract}
    'list_push':      {0: 'borrow', 1: ('retain_in', 0)},
    # `list_set(list, index, value)` -- the stored value is argument **2**. This
    # said 1, which is the integer index, so the value only borrowed and appeared
    # never to escape. Optimistic, i.e. unsound, and the compiler had the same
    # off-by-one -- which is how a differential test agrees on a wrong answer.
    'list_set':       {0: 'borrow', 1: 'borrow', 2: ('retain_in', 0)},
    'list_get':       {0: 'borrow'},          # returns an alias into arg 0
    'list_len':       {0: 'borrow'},
    'list_new':       {},                     # produces a fresh container
    # Vec::with_capacity. Its argument is an Int, so there is no site to give a
    # contract to -- but the *return* contract matters, and leaving it out is what
    # made the oracle call five fresh containers `opaque-ret` and sink eight sites
    # to T3. See FFI_RETURNS_PRODUCE below; these two tables have to move together.
    'list_new_with_capacity': {},
    'soa':            {0: 'consume'},
    'aos':            {0: 'consume'},
    'data_len':       {0: 'borrow'},
    'str_concat':     {0: 'borrow', 1: 'borrow'},
    'str_equals':     {0: 'borrow', 1: 'borrow'},
    'str_substring':  {0: 'borrow'},
    'str_slice':      {0: 'borrow'},
    # Compiler builtins remain call-shaped in the AST even though codegen emits
    # no call. They borrow for the duration of the operation and retain nothing.
    '__builtin_string_len': {0: 'borrow'},
    '__builtin_string_byte_at': {0: 'borrow'},
    '__builtin_string_put_byte': {0: 'borrow'},
    'print':          {0: 'borrow'},
    'println':        {0: 'borrow'},
    # v0.1 concurrency. `chan_send` **consumes** its message rather than
    # retaining it into the endpoint, which is where this differs from
    # `list_push`: a list releases its elements at teardown and a channel does
    # not -- the receiver takes the message out and owns it from then on.
    'chan_send':      {0: 'borrow', 1: 'consume'},
    'chan_new':       {0: 'borrow'},
    'chan_recv':      {0: 'borrow'},
    'chan_share':     {0: 'borrow'},
    'chan_close':     {0: 'borrow'},
    'chan_len':       {0: 'borrow'},
    'chan_free':      {0: 'borrow'},
}

# Produced returns that allocate nothing here: the block was made by another
# thread and is already live, so it can be neither a frame slot nor arena-served.
# Kept in step with aifFfiTransfersExisting in src/aif/contracts.psm.
FFI_RETURNS_EXISTING = {'chan_recv'}

# Calls whose return is a channel endpoint -- a runtime object with no site.
# Kept in step with the chan_new/chan_share arm in src/aif/walk.psm.
FFI_RETURNS_ENDPOINT = {'chan_new', 'chan_share'}

# Externs whose return value aliases an argument rather than allocating
# (FFI 5.2 `alias`). Modelled by returning the argument's own sites.
#
# REQUIREMENTS 4's checked unwrap is the only entry, and it was missing until
# v0.1's channels put an `expect` in a differential source: `expect(x)` is the
# identity on a pointer, so without this the oracle reads it as an opaque extern
# return -- a fresh site, escape raised to Caller, and the unwrapped value stops
# being reclaimable by whatever owned the optional. `aifFfiAliasOf` in
# src/aif/contracts.psm has said so since optionals landed; this is the half that
# nothing had exercised. Verified discriminating: removed, tests/test_96_channels
# reports `opaque-ret: compiler=0 oracle=4`.
FFI_RETURNS_ALIAS_OF = {'expect': 0}

# Externs that read an element back out of a container: name -> argument index.
#
# `list_get` used to be in FFI_RETURNS_ALIAS_OF above, on the reading that the
# argument's value set *is* the element -- and it is not, it is the list. Reading
# an element and pushing it into a second container then recorded the container as
# the element, which hid the sharing and told the second container its elements
# were lists. A container's contents are a field key (elem_key); this reads it.
FFI_READS_ELEMENT_OF = {'list_get': 0}


def base_type(ty):
    """`List<Token>` -> `List`. Field keys are per nominal type, so a generic
    container's fields are shared across its instantiations."""
    at = ty.find('<')
    return ty if at < 0 else ty[:at]


def elem_key(container_type):
    """A container's contents, as a field key.

    Object-insensitive through base_type for the reason base_type exists: keying
    on the spelled type would put `list_new()`'s `List<Invalid>` and an annotated
    `List<Item>` on different keys, and a lost edge is the unsound direction.
    """
    return ('field', base_type(container_type), '@elem')

# Return contracts (FFI 5.2). 'produce' = a fresh owned value the caller must
# release; anything undeclared has UNKNOWN provenance and must be treated
# conservatively -- it may already be shared and may already outlive us.
FFI_RETURNS_PRODUCE = {
    'list_new', 'list_new_with_capacity',
    'soa', 'aos',
    'str_concat', 'str_substring', 'str_slice',
    'int_to_str',
    'read_file', 'get_directory', 'join_path',
    # What comes out of a channel was allocated by the sending task and is this
    # frame's from here on -- `read_file`'s shape with the allocation on another
    # thread instead of in libc. See FFI_RETURNS_EXISTING for the half that is
    # *not* like read_file.
    'chan_recv',
}

# A builtin is the one kind of runtime function this table is load-bearing for.
# Every extern a *source* declares carries its contract in the AST, so the oracle
# reads it and these tables never fire -- which is why `src/main.psm` kept
# agreeing while `list_new_with_capacity` was missing here. A builtin is never
# declared, so an omission is silent until some source in the differential's list
# calls it. `tests/test_56_list_capacity.psm` is in that list for exactly this
# reason: without it, adding a builtin and forgetting this table costs nothing
# until much later.

# SPEC 5.2.1's bracketing obligations, as a mask. Every failing one is reported,
# not the first: the clauses are a conjunction and a site typically fails
# several, which is the same reason `--why`'s placement section reports a mask.
BR_GLOBAL = 1
BR_PARAM_STORE = 2
BR_OPAQUE = 4
BR_DROP = 8
BR_SHARED_BODY = 16
BR_MULTI_CALL = 32


class Scopes:
    """Scope forest. Each function's body block is a root; join is the LCA,
    which exists because scopes nest (INFERENCE 2.1)."""

    def __init__(self):
        self.parent = {}
        self.depth = {}
        self.owner = {}       # scope -> owning function symbol
        self._next = 0

    def new(self, parent, owner):
        sid = self._next
        self._next += 1
        self.parent[sid] = parent
        self.depth[sid] = 0 if parent is None else self.depth[parent] + 1
        self.owner[sid] = owner
        return sid

    def lca(self, a, b):
        if self.owner[a] != self.owner[b]:
            return None          # different functions -> no common region
        while self.depth[a] > self.depth[b]:
            a = self.parent[a]
        while self.depth[b] > self.depth[a]:
            b = self.parent[b]
        while a != b:
            a, b = self.parent[a], self.parent[b]
        return a


def escape_join(scopes, x, y):
    """Least upper bound on Region(s) < Caller < Global."""
    if x == GLOBAL or y == GLOBAL:
        return GLOBAL
    if x == CALLER or y == CALLER:
        return CALLER
    m = scopes.lca(x[1], y[1])
    return CALLER if m is None else ('R', m)


def escape_le(scopes, x, y):
    return escape_join(scopes, x, y) == y


def ann_leaf_name(ann):
    """The type an annotation refers to: `[T]` and `List<T>` hang T off c1,
    and their own name is '' or 'List'. Mirrors aif_annotation_leaf_name."""
    name = ann['s1']
    kids = ann.get('c1') or []
    while kids:
        ann = kids[0]
        name = ann['s1']
        kids = ann.get('c1') or []
    return name


# ---------------------------------------------------------------------------
# Model: read the dump into functions, structs, scopes and allocation sites
# ---------------------------------------------------------------------------

class Site:
    __slots__ = ('id', 'kind', 'type', 'fn', 'scope', 'file', 'line', 'col', 'nfields')

    def __init__(self, sid, kind, ty, fn, scope, node, nfields=0):
        self.id = sid
        self.kind = kind          # 'struct' | 'string' | 'array' | 'list' | 'opaque'
        self.type = ty
        self.fn = fn
        self.scope = scope
        self.file = node['fi']
        self.line = node['ln']
        self.col = node['co']
        self.nfields = nfields


class Model:
    def __init__(self, dump):
        self.files = {f['id']: f['path'] for f in dump['files']}
        self.structs = {}          # name -> [(field, type)]
        self.enums = set()
        self.functions = {}        # symbol -> node
        self.fn_name = {}          # symbol -> plain name
        self.fn_file = {}          # symbol -> file id
        self.sealed = set()        # symbols whose bodies are not visible
        self.scopes = Scopes()
        self.sites = []
        self.type_acyclic = {}

        # Declared FFI contracts (FFI 5), read off each extern's type
        # annotations. The compiler stores them on the annotation's `s2`; the
        # dump carries that through verbatim. Index -1 is the return.
        self.contracts = {}            # (fn name, index) -> contract text

        for d in dump['decls']:
            if d['k'] == 'EXTERN_FUNCTION':
                index = 0
                for p in d['c1']:
                    if p['k'] != 'FUNCTION_PARAMETER':
                        continue
                    if p['c1'] and p['c1'][0].get('s2'):
                        self.contracts[(d['s1'], index)] = p['c1'][0]['s2']
                    index += 1
                if d['c2'] and d['c2'][0].get('s2'):
                    self.contracts[(d['s1'], -1)] = d['c2'][0]['s2']
            if d['k'] == 'STRUCT_DECL':
                self.structs[d['s1']] = [
                    (f['s1'], ann_leaf_name(f['c1'][0]) if f['c1'] else '')
                    for f in d['c1'] if f['k'] == 'STRUCT_FIELD'
                ]
            elif d['k'] == 'ENUM_DECL':
                self.enums.add(d['s1'])
            elif d['k'] == 'FUNCTION':
                sym = d['s2'] or d['s1']
                self.functions[sym] = d
                self.fn_name[sym] = d['s1']
                self.fn_file[sym] = d['fi']

        self._compute_type_acyclic()

    # -- type classification -------------------------------------------------

    def is_ref(self, ty):
        """Does a value of this type participate in the memory model at all?"""
        if ty in REF_SCALARS or ty in self.enums:
            return False
        return True

    # Cleared by --copyable-collections. Level 4 made String and List move-only
    # (types.psm), so this is what the language *is*, not an experiment -- and it
    # is what `prismio build` analyses with (main.psm's aifRun(.., true, ..)).
    #
    # It defaulted to False until 2026-08-08, describing the pre-Level-4 language.
    # That is not merely stale: with strings copyable, A-COPY fires on any string
    # site with two holders, so a plain `prismio aif` reported 82 T3 sites over
    # the compiler that the build it describes does not have. The flag inverted
    # rather than being deleted because the copyable model is still the second
    # arm of the differential, and an arm that agrees by construction is worse
    # than no arm.
    owned_collections = True

    def is_move_only(self, ty):
        if ty in self.structs:
            return True
        if self.owned_collections:
            return (ty == 'String' or ty.startswith('List')
                    or ty.startswith('DataView')
                    or ty.startswith('[') or ty.startswith('Array'))
        return False

    def site_kind(self, ty):
        if ty in self.structs:
            return 'struct'
        if ty == 'String':
            return 'string'
        if ty.startswith('List'):
            return 'list'
        if ty.startswith('DataView'):
            return 'list'
        if ty.startswith('[') or ty.startswith('Array'):
            return 'array'
        return 'opaque'

    def _compute_type_acyclic(self):
        """Tarjan-free SCC via iterative Kosaraju on the type reference graph
        (INFERENCE 4.4 stage 1). A type is acyclic when its SCC is trivial and
        it reaches no non-trivial SCC."""
        # Field types are leaf names already. This used to parse `List<...>` out
        # of the type string, which the dump never contains, so that branch could
        # not fire and the edge was silently never added.
        g = {t: set() for t in self.structs}
        for t, fields in self.structs.items():
            for _, fty in fields:
                if fty in self.structs:
                    g[t].add(fty)

        index, low, onstack, stack, comp = {}, {}, set(), [], {}
        counter = [0]

        def strongconnect(v):
            work = [(v, iter(g[v]))]
            index[v] = low[v] = counter[0]; counter[0] += 1
            stack.append(v); onstack.add(v)
            while work:
                node, it = work[-1]
                advanced = False
                for w in it:
                    if w not in index:
                        index[w] = low[w] = counter[0]; counter[0] += 1
                        stack.append(w); onstack.add(w)
                        work.append((w, iter(g[w])))
                        advanced = True
                        break
                    elif w in onstack:
                        low[node] = min(low[node], index[w])
                if advanced:
                    continue
                work.pop()
                if work:
                    low[work[-1][0]] = min(low[work[-1][0]], low[node])
                if low[node] == index[node]:
                    members = []
                    while True:
                        w = stack.pop(); onstack.discard(w); members.append(w)
                        if w == node:
                            break
                    for m in members:
                        comp[m] = id(members) if len(members) > 1 else None
                    if len(members) == 1 and members[0] in g[members[0]]:
                        comp[members[0]] = id(members)   # self-loop

        for t in g:
            if t not in index:
                strongconnect(t)

        # reachability into any non-trivial SCC
        cyclic = {t for t in g if comp.get(t) is not None}
        changed = True
        while changed:
            changed = False
            for t in g:
                if t not in cyclic and any(w in cyclic for w in g[t]):
                    cyclic.add(t); changed = True
        for t in g:
            self.type_acyclic[t] = t not in cyclic


# ---------------------------------------------------------------------------
# Engine: points-to + facts, round-synchronous to a fixed point (INFERENCE 5)
# ---------------------------------------------------------------------------

# A value-set expression: concrete sites known now, plus deferred references to
# points-to nodes whose contents are only known at the fixed point. Keeping both
# in one type is what lets `sites_of` compose uniformly over any expression.
#
# The third component is SPEC 8.4 view provenance: the collections these values
# are views *of*, each itself a (sites, keys) pair resolved at the fixed point.
# Empty for every value set that is not a view, which is nearly all of them.
VS_EMPTY = (frozenset(), frozenset(), frozenset())


def vs_sites(*ids):
    return (frozenset(ids), frozenset(), frozenset())


def vs_ref(key):
    return (frozenset(), frozenset([key]), frozenset())


def vs_union(a, b):
    return (a[0] | b[0], a[1] | b[1], a[2] | b[2])


def vs_view_of(v, container):
    """SPEC 8.4. Mark `v` as denoting views of `container`. Provenance, not a
    points-to edge -- see the same function in runtime/aif_support.c."""
    return (v[0], v[1], v[2] | frozenset([(container[0], container[1])]))


class Engine:
    def __init__(self, model, ffi_default='borrow'):
        self.m = model
        self.ffi_default = ffi_default
        self.literal_strings = 0
        self.extern_alloc = 0
        self.opaque_returns = 0
        self.static_returns = 0
        self.pt = defaultdict(set)        # ('var', fn, name) | ('field', ty, f)
                                          # | ('ret', fn) | ('param', fn, i) -> {site}
        self.no_stack = set()             # sites an explicit drop() forbids T0 for
        # Sites whose allocation happened somewhere else entirely -- a produced
        # return that hands over an already-live block. Distinct from no_stack:
        # this forbids T0 without claiming somebody else performs the free.
        self.foreign = set()
        # site -> {container sites holding it}. Separate from `holders`, which
        # counts *keys* -- named locations the move checker governs. A container
        # element is neither: list_push is a call, so nothing about it is a move,
        # and two pushes of one value are two owners the language never noticed.
        self.container_of = defaultdict(set)
        # SPEC 8.4. key -> {collection sites that values bound to this key are
        # views of}. Provenance has to ride the points-to graph and not the
        # value set alone, because a view is nearly always bound to a name
        # before it travels:
        #
        #     let e = list_get(items, i)   # provenance attaches to this value set
        #     return e                     # ...and must still be here
        #
        # Grown in the points-to phase, which reads no fact. Mirrors key_views
        # in aif_support.c.
        self.key_views = defaultdict(set)
        self.E = {}                       # site -> escape
        self.A = {}                       # site -> alias
        self.C = {}                       # site -> cyclicity
        self.T = {}                       # site -> thread affinity
        # INFERENCE 4.3's T-STATIC premise, "the program creates any task", is a
        # whole-program property. Mirrors program_has_tasks in aif_support.c.
        self.has_tasks = False
        self.holders = defaultdict(set)   # site -> {holder keys}, for A-COPY
        self.constraints = []             # deferred (kind, args) edges
        self.rounds = 0
        self.pt_rounds = 0                # of rounds, how many points-to used
        self.delta = set()                # sites whose facts moved last round
        self.delta_pt = False             # did points-to move last round?
        self.widened = set()              # sites widen_unconverged raised
        # Declaring scope per ('var', fn, name). E-BIND needs the scope the
        # *variable* was declared in, not the scope the assignment sits in: a
        # value created in a loop body and assigned to a binding declared
        # outside it survives the iteration, and its escape has to say so.
        # Shadowing joins outward via the LCA, so the answer does not depend on
        # which declaration the walk saw last.
        self.var_scope = {}
        # SPEC 5.2.1's call graph, for the bracketing summary. One entry per call
        # *expression*: a set would collapse two calls to one and make every
        # callee look sole-owned, which is exactly the fact regime (a) turns on.
        # A callee of None is a call nothing can summarise.
        self.call_edges = []              # (caller, callee|None, scope)
        # What each function stores *into*. Obligation 2 asks whether every one
        # of those owners was allocated inside the extent being bracketed, so it
        # is the holder that is recorded, not the value.
        self.owner_uses = []              # (fn, vs)

    # -- construction --------------------------------------------------------

    def build(self):
        for sym, fn in self.m.functions.items():
            root = self.m.scopes.new(None, sym)
            for p_i, p in enumerate(fn['c1']):
                if p['k'] != 'FUNCTION_PARAMETER':
                    continue
                self.note_var_scope(sym, p['s1'], root)
                ty = p['ty'] or (p['c1'][0]['s1'] if p['c1'] else '')
                if self.m.is_ref(ty):
                    self.constraints.append(('bind', ('var', sym, p['s1']),
                                             self.ref(('param', sym, p_i))))
            for b in fn['c2']:
                self.walk(b, sym, root)

    def new_site(self, ty, fn, scope, node):
        s = Site(len(self.m.sites), self.m.site_kind(ty), ty, fn, scope, node,
                 len(self.m.structs.get(ty, [])))
        self.m.sites.append(s)
        self.E[s.id] = ('R', scope)
        self.A[s.id] = UNIQUE
        self.C[s.id] = ACYCLIC
        # T-DEFAULT is the bottom element and not a rule: "any node has
        # T >= Isolated" is discharged by initialising it here.
        self.T[s.id] = ISOLATED
        return s.id

    def sites_of(self, e, fn, scope):
        """Abstract evaluation: the set of allocation sites an expression may
        denote. Creates a site where the expression allocates."""
        k = e['k']
        ty = e['ty']

        if k == 'STRUCT_LITERAL_EXPR':
            sname = e['s1'] or ty
            sid = self.new_site(sname, fn, scope, e)
            for f in e['c1']:
                if f['c1']:
                    v = self.sites_of(f['c1'][0], fn, scope)
                    self.constraints.append(
                        ('store', ('field', sname, f['s1']), v, vs_sites(sid)))
                    # SPEC 5.2.1 obligation 2. Provably local -- the owner is this
                    # literal's own site -- and recorded anyway, because a clause
                    # exempted by an argument in a comment is a clause that stops
                    # being checked the moment the argument stops holding.
                    self.owner_uses.append((fn, vs_sites(sid)))
            return vs_sites(sid)

        if k == 'ARRAY_LITERAL_EXPR':
            aname = ty or 'Array'
            sid = self.new_site(aname, fn, scope, e)
            # Elements store into the array like a struct literal's initialisers
            # store into its fields; one shared key, since there is no name.
            for el in e['c1']:
                v = self.sites_of(el, fn, scope)
                self.constraints.append(
                    ('store', ('field', aname, '[]'), v, vs_sites(sid)))
                self.owner_uses.append((fn, vs_sites(sid)))
            return vs_sites(sid)

        if k == 'LITERAL_EXPR':
            # A string literal is not an allocation. It lowers to an LLVM global
            # -- static, immortal, zero cost -- so it has no place on a ladder
            # that ranks ways of reclaiming heap memory. Counted separately so
            # the exclusion is visible rather than silent.
            if ty == 'String':
                self.literal_strings += 1
            return VS_EMPTY

        if k == 'IDENTIFIER_EXPR':
            return self.ref(('var', fn, e['s1'])) if self.m.is_ref(ty) else VS_EMPTY

        if k == 'MEMBER_ACCESS_EXPR':
            obj = e['c1'][0] if e['c1'] else None
            if obj is not None and self.m.is_ref(obj['ty']):
                base = obj['ty'].split('<')[0]
                self.sites_of(obj, fn, scope)
                return self.ref(('field', base, e['s1']))
            return VS_EMPTY

        # REQUIREMENTS 15. `spawn f(a, b)`. Mirrors src/aif/walk.psm.
        #
        # The inner call is evaluated as an ordinary call first -- the callee
        # really is called, so E-CALL, A-CALL and the FFI contracts all apply
        # unchanged. What the spawn adds is one constraint carrying the two
        # rules that are about the *boundary*: INFERENCE 4.1's E-SPAWN /
        # E-SPAWN-J and 4.3's T-SPAWN-MOVE / T-SPAWN-SHARE.
        #
        # `i1` is the joined flag, and this implementation computes it itself in
        # walk() rather than reading the compiler's answer out of the dump. That
        # is the point of an oracle: a join analysis that is wrong in both
        # implementations for the same reason is exactly what a differential
        # cannot catch, so the two derive it separately from the same AST.
        if k == 'SPAWN_EXPR':
            if not e['c1']:
                return VS_EMPTY
            call = e['c1'][0]
            self.sites_of(call, fn, scope)
            args = VS_EMPTY
            for a in call['c2']:
                args = vs_union(args, self.sites_of(a, fn, scope))
            self.has_tasks = True
            self.constraints.append(('spawn', args, scope, bool(e['i1'])))
            # The task handle is a runtime object this compilation did not
            # allocate, so it contributes no site -- nothing to place, count or
            # release.
            return VS_EMPTY

        # `join t` yields an Int, and the handle it consumes was never a site.
        if k == 'JOIN_EXPR':
            return VS_EMPTY

        if k == 'CALL_EXPR':
            callee = e['s2'] or (e['c1'][0]['s1'] if e['c1'] else '')
            plain = e['c1'][0]['s1'] if e['c1'] else callee
            # A sealed function has no visible body (PIR 5), so it is analysed
            # exactly like an FFI call: contracts only, no inference across it.
            known = callee in self.m.functions and callee not in self.m.sealed
            contracts = FFI_CONTRACTS.get(plain, {})
            argvals = [self.sites_of(a, fn, scope) for a in e['c2']]

            # SPEC 5.2.1's call graph. `drop` is excluded from the opaque case:
            # it is fully modelled, by the `no_stack` constraint below, and the
            # DROP obligation reports it in terms a reader can act on. Mirrors
            # src/aif/walk.psm.
            if known:
                self.call_edges.append((fn, callee, scope))
            elif plain != 'drop' and not self.call_is_summarised(plain, len(argvals)):
                self.call_edges.append((fn, None, scope))

            # `drop(x)` lowers to a free, and a stack slot cannot be freed. A T0
            # value has no allocation to release -- its storage *is* the frame --
            # so promoting a value the source explicitly drops turns a working
            # program into heap corruption.
            #
            # Deliberately not a fact: an explicit drop says nothing about
            # lifetime or aliasing, and bending E or A to carry a codegen
            # constraint would make the manifest lie about why the tier moved.
            if plain == 'drop' and argvals:
                self.constraints.append(('no_stack', argvals[0]))

            for i, av in enumerate(argvals):
                if known:
                    self.constraints.append(('arg', ('param', callee, i), av))
                    continue
                c = self.declared_contract(plain, i)
                if c is None:
                    c = contracts.get(i, self.ffi_default)
                if c == 'consume':
                    # The callee frees it, so it must be something a free can
                    # take: never a stack slot, and no longer this frame's.
                    self.constraints.append(('no_stack', av))
                    self.constraints.append(('escape_caller', av))
                elif c == 'out':
                    self.constraints.append(('borrow', av))
                elif isinstance(c, tuple) and c[0] == 'retain_in':
                    # The callee stores this argument into another argument, so
                    # it escapes exactly as far as that container does.
                    holder = argvals[c[1]] if c[1] < len(argvals) else VS_EMPTY
                    self.constraints.append(('retain_in', av, holder))
                    # SPEC 5.2.1 obligation 2, container form. `list_push(dest, x)`
                    # on a `dest` this function did not allocate is the counter-
                    # example the summary exists to catch, and it is recorded on
                    # the *holder* because the element block reallocates whether
                    # or not the pushed value has a site.
                    self.owner_uses.append((fn, holder))
                    # ...and the container's element field now points at it, so a
                    # later read gets the element back rather than the container.
                    holder_ty = e['c2'][c[1]]['ty'] if c[1] < len(e['c2']) else ''
                    self.constraints.append(('bind', elem_key(holder_ty), av))
                elif c == 'retain':
                    self.constraints.append(('escape_global', av))
                else:
                    # FFI 5.1: `borrow` is the default -- the callee may read and
                    # write during the call but does not retain. 5.4 argues for it
                    # because `retain` would sink every FFI-touching value;
                    # --ffi=retain measures that claim.
                    self.constraints.append(('borrow', av))

            if known:
                return self.ref(('ret', callee))
            # Reading an element out of a container yields what was stored into
            # it, which is the element field rather than the container. Resolved
            # at the fixed point, so the pushes may be walked after this read.
            elem_of = FFI_READS_ELEMENT_OF.get(plain)
            if elem_of is not None and elem_of < len(e['c2']):
                element = self.ref(elem_key(e['c2'][elem_of]['ty']))
                # SPEC 8.4: an element reference IS a view, so this read produces
                # one. The element key stays exactly what it was -- a points-to
                # edge saying *which values* can come back. Provenance is
                # attached beside it, and says what the points-to graph cannot:
                # how long the container must live for the reference to be
                # legal. Both are needed; see the same comment in
                # src/aif/walk.psm.
                # Only a reference is a view. Reading an `Int` out of a
                # `List<Int>` copies it into a register, and a copy that leaves
                # the function keeps nothing alive. SPEC 8.4 says a view is a
                # *reference* to part of a collection.
                if elem_of < len(argvals) and self.m.is_ref(ty):
                    element = vs_view_of(element, argvals[elem_of])
                return element
            # v0.1 concurrency. A channel endpoint is a runtime object this
            # compilation did not allocate, so like a task handle it contributes
            # no site: nothing to place, count or release, and `chan_free` is
            # where it goes. `chan_share` hands back the same endpoint, which is
            # what makes it a second reference and not a second owner. Mirrors
            # the same arm in src/aif/walk.psm.
            if plain in FFI_RETURNS_ENDPOINT:
                return VS_EMPTY
            alias_of = FFI_RETURNS_ALIAS_OF.get(plain)
            if alias_of is not None and alias_of < len(argvals):
                return argvals[alias_of]         # FFI 5.2 `alias`
            if self.m.is_ref(ty):
                ret_contract = self.m.contracts.get((plain, -1), '')
                # FFI 5.2 `alias`: not an allocation -- it borrows from an
                # argument or from static storage. FFI.md names no argument, so
                # the return is the union of the arguments' value sets, which
                # generalises the `list_get` special case rather than adding a
                # second mechanism.
                #
                # Returning nothing would NOT be sound: an empty value set makes
                # every store through the result a no-op, so nothing inherits the
                # container's escape. Where there is nothing to alias, fall
                # through to the opaque path.
                if ret_contract == 'alias':
                    aliased = VS_EMPTY
                    for av in argvals:
                        aliased = vs_union(aliased, av)
                    if aliased != VS_EMPTY:
                        return aliased
                    # Nothing to alias means FFI 5.2's other case: static
                    # storage. Not an allocation, and so not on a ladder that
                    # ranks ways of reclaiming heap memory -- the same reason a
                    # string literal is excluded.
                    self.static_returns += 1
                    return VS_EMPTY
                self.extern_alloc += 1
                sid = self.new_site(ty, fn, scope, e)
                produces = (plain in FFI_RETURNS_PRODUCE
                            or ret_contract.startswith('produce'))
                if plain in FFI_RETURNS_EXISTING:
                    self.constraints.append(('foreign', vs_sites(sid)))
                if not produces:
                    # Undeclared return: provenance unknown. It may already be
                    # shared and may already outlive this frame, so it cannot be
                    # modelled as a fresh local allocation.
                    self.opaque_returns += 1
                    self.constraints.append(('opaque', vs_sites(sid)))
                return vs_sites(sid)
            return VS_EMPTY

        out = VS_EMPTY
        for slot in ('c1', 'c2', 'c3'):
            for c in e[slot]:
                out = vs_union(out, self.sites_of(c, fn, scope))
        return out

    def declared_contract(self, name, index):
        """What the extern declaration said, or None to fall through.

        A declared contract wins; FFI_CONTRACTS below is a fallback for the
        Prismio runtime's own surface, whose ownership semantics are a property
        of the runtime rather than of any one program's declaration of it.
        """
        text = self.m.contracts.get((name, index))
        if text is None:
            return None
        if text.startswith('retain_in:'):
            return ('retain_in', int(text.split(':', 1)[1]))
        if text in ('borrow', 'retain', 'consume', 'out'):
            return text
        return None                       # a return contract; sema rejected it

    def call_is_summarised(self, name, argc):
        """SPEC 5.2.1's bracketing question, at a call: is what this callee does
        to the values it is handed *described*, or assumed?

        FFI 5.1's `borrow` default is sound enough for a tier -- a wrong guess is
        caught by the same widening that catches everything else -- but bracketing
        hands the callee arena memory, and an undescribed callee that retains it
        turns the annotation into a use-after-free. So the default does not count
        as a description here, and the two cases have to be distinguishable:
        `self.ffi_default` is what the tier analysis falls back to, and this asks
        whether it had to.

        A declaration counts only when it is **complete** -- every parameter and
        the return. A partial one leaves undescribed exactly the argument nobody
        thought about, which is the one that retains. Mirrors
        `aifCallIsSummarised` in src/aif/contracts.psm.
        """
        if name in FFI_CONTRACTS or name in FFI_RETURNS_PRODUCE:
            return True
        if not self.m.contracts.get((name, -1), ''):
            return False
        return all(self.declared_contract(name, i) is not None for i in range(argc))

    def ref(self, key):
        self.pt[key]                      # touch so it exists
        return vs_ref(key)

    def note_var_scope(self, fn, name, scope):
        key = ('var', fn, name)
        prev = self.var_scope.get(key)
        if prev is None:
            self.var_scope[key] = scope
            return
        m = self.m.scopes.lca(prev, scope)
        if m is not None:
            self.var_scope[key] = m

    def holder_scope(self, fn, name, fallback):
        """Where a value assigned to `name` has to stay alive until."""
        return self.var_scope.get(('var', fn, name), fallback)

    # -- structured-concurrency analysis -------------------------------------
    #
    # INFERENCE 4.1's E-SPAWN-J premise: "joined on every path before scope s
    # exits". Derived here independently of src/aif/walk.psm, deliberately --
    # this is the fact that decides whether a task's arguments stay region-bound
    # at T1 or are forced to Global and from there to T4, and a shared bug in
    # the two implementations is precisely what a differential cannot see.
    #
    # Kept to the same conservative shape as the compiler's: a straight run of
    # statements from the spawn to the join, with nothing in between that can
    # leave the block. Anything else answers "not joined", which is the sound
    # direction -- it raises escape and costs a tier, where the opposite would
    # hand a scope-bound lifetime to a value a task still holds.

    STATEMENT_KINDS = frozenset((
        'BLOCK', 'IF_STATEMENT', 'MATCH_STATEMENT', 'FOR_STATEMENT',
        'WHILE_STATEMENT', 'LOOP_STATEMENT', 'RETURN_STATEMENT',
        'ASSIGNMENT_STATEMENT', 'EXPRESSION_STATEMENT', 'BREAK_STATEMENT',
        'CONTINUE_STATEMENT', 'REGION_STATEMENT', 'VARIABLE_DECL'))

    def expr_has_join_of(self, e, name):
        """Does this expression contain `join <name>`?

        Stops at any statement kind, which keeps it from wandering out of the
        expression into a nested block -- without that, `if (c) { join t }`
        would read as an unconditional join.
        """
        if e is None or e['k'] in self.STATEMENT_KINDS:
            return False
        if e['k'] == 'JOIN_EXPR' and e['c1']:
            target = e['c1'][0]
            if target['k'] == 'IDENTIFIER_EXPR' and target['s1'] == name:
                return True
        for slot in ('c1', 'c2', 'c3'):
            for c in e[slot]:
                if self.expr_has_join_of(c, name):
                    return True
        return False

    # A join in this statement's own expression, not in any block it contains.
    DIRECT_JOIN_SLOT = {
        'VARIABLE_DECL': 'c2', 'EXPRESSION_STATEMENT': 'c1',
        'RETURN_STATEMENT': 'c1', 'ASSIGNMENT_STATEMENT': 'c2',
    }

    def stmt_direct_join(self, n, name):
        slot = self.DIRECT_JOIN_SLOT.get(n['k'])
        return bool(slot and n[slot] and self.expr_has_join_of(n[slot][0], name))

    @staticmethod
    def _body(slot):
        """The statement list under a block child slot, or [] when absent."""
        return slot[0]['c1'] if slot else []

    def stmt_escapes_unjoined(self, n, name, in_loop):
        """Some path through this statement leaves the scope without joining.

        `in_loop` is what makes `break` mean different things at different
        depths: inside a loop that is itself part of the chain being scanned it
        is absorbed and control continues, at the top level it leaves. The
        previous version could not tell those apart and counted every break as
        an exit.
        """
        k = n['k']
        if k == 'RETURN_STATEMENT':
            return not (n['c1'] and self.expr_has_join_of(n['c1'][0], name))
        if k in ('BREAK_STATEMENT', 'CONTINUE_STATEMENT'):
            return not in_loop
        if k == 'IF_STATEMENT':
            if self.chain_escapes_unjoined(self._body(n['c2']), name, in_loop):
                return True
            if not n['c3']:
                return False
            els = n['c3'][0]
            if els['k'] == 'IF_STATEMENT':
                return self.stmt_escapes_unjoined(els, name, in_loop)
            return self.chain_escapes_unjoined(els['c1'], name, in_loop)
        if k == 'WHILE_STATEMENT':
            return self.chain_escapes_unjoined(self._body(n['c2']), name, True)
        if k == 'LOOP_STATEMENT':
            return self.chain_escapes_unjoined(self._body(n['c1']), name, True)
        if k == 'FOR_STATEMENT':
            return self.chain_escapes_unjoined(self._body(n['c3']), name, True)
        # A region is not a loop, so `in_loop` passes through unchanged.
        if k == 'REGION_STATEMENT':
            return self.chain_escapes_unjoined(self._body(n['c1']), name, in_loop)
        if k == 'BLOCK':
            return self.chain_escapes_unjoined(n['c1'], name, in_loop)
        if k == 'MATCH_STATEMENT':
            return any(self.chain_escapes_unjoined(self._body(arm['c2']), name, in_loop)
                       for arm in n['c2'])
        return False

    def stmt_always_joins(self, n, name, in_loop):
        """Every path through this statement joins."""
        if self.stmt_direct_join(n, name):
            return True
        k = n['k']
        if k == 'IF_STATEMENT':
            # No else means a path runs none of the arm, so the fall-through
            # decides it and the enclosing chain is what sees that.
            if not n['c3']:
                return False
            if not self.chain_joins(self._body(n['c2']), name, in_loop):
                return False
            els = n['c3'][0]
            if els['k'] == 'IF_STATEMENT':
                return self.stmt_always_joins(els, name, in_loop)
            return self.chain_joins(els['c1'], name, in_loop)
        if k == 'BLOCK':
            return self.chain_joins(n['c1'], name, in_loop)
        if k == 'REGION_STATEMENT':
            return self.chain_joins(self._body(n['c1']), name, in_loop)
        # Deliberately not MATCH: "every arm joins" would be sound only because
        # another pass checks exhaustiveness, and a hole there would surface
        # here as a use-after-free rather than as a missing-case diagnostic.
        # Nor any loop -- while/for may run zero times, `loop` may not terminate.
        return False

    def chain_escapes_unjoined(self, stmts, name, in_loop):
        for n in stmts:
            if self.stmt_escapes_unjoined(n, name, in_loop):
                return True
            if self.stmt_always_joins(n, name, in_loop):
                return False
        return False

    def chain_joins(self, stmts, name, in_loop):
        """Every path through this chain joins before control leaves it.

        The escape test runs first, and that order is the correctness argument:
        `if (c) { return 0 }` followed by `return join t` has a path that leaves
        without joining, and asking "does something later join" first would
        answer yes and miss it.
        """
        for n in stmts:
            if self.stmt_escapes_unjoined(n, name, in_loop):
                return False
            if self.stmt_always_joins(n, name, in_loop):
                return True
        return False   # fell out of the bottom with the task still running

    def spawn_is_joined(self, rest, name):
        # False at the top: the scope is the block holding the spawn, and a
        # `break` written directly in it leaves that block.
        return self.chain_joins(rest, name, False)

    def stamp_joins(self, stmts):
        """Mark every `let t = spawn ...` in this chain that is joined before the
        chain ends. The flag rides on the spawn node's i1, which the parser
        leaves 0 -- so a spawn this never reaches defaults to unjoined."""
        for i, n in enumerate(stmts):
            if n['k'] != 'VARIABLE_DECL' or not n['c2']:
                continue
            init = n['c2'][0]
            if init['k'] == 'SPAWN_EXPR':
                init['i1'] = 1 if self.spawn_is_joined(stmts[i + 1:], n['s1']) else 0

    # -- statement walk ------------------------------------------------------

    def walk(self, n, fn, scope):
        k = n['k']

        if k == 'BLOCK':
            inner = self.m.scopes.new(scope, fn)
            for slot in ('c1', 'c2', 'c3'):
                self.stamp_joins(n[slot])
                for c in n[slot]:
                    self.walk(c, fn, inner)
            return

        # SPEC 5.2. The scope is what has to match the compiler's, because scope
        # ids are what Region(s) compares. Which arena a value comes from is a
        # codegen decision and is not modelled here; the region supplies no fact
        # the escape analysis did not already have.
        if k == 'REGION_STATEMENT':
            inner = self.m.scopes.new(scope, fn)
            self.stamp_joins(n['c1'])
            for c in n['c1']:
                self.walk(c, fn, inner)
            return

        if k == 'VARIABLE_DECL':
            self.note_var_scope(fn, n['s1'], scope)
            if n['c2']:
                v = self.sites_of(n['c2'][0], fn, scope)
                self.constraints.append(('bind', ('var', fn, n['s1']), v))
                self.constraints.append(('live_in', v, scope, fn))
            return

        if k == 'ASSIGNMENT_STATEMENT':
            tgt = n['c1'][0] if n['c1'] else None
            val = self.sites_of(n['c2'][0], fn, scope) if n['c2'] else VS_EMPTY
            if tgt is not None:
                if tgt['k'] == 'IDENTIFIER_EXPR':
                    self.constraints.append(('bind', ('var', fn, tgt['s1']), val))
                    self.constraints.append(
                        ('live_in', val, self.holder_scope(fn, tgt['s1'], scope), fn))
                elif tgt['k'] == 'MEMBER_ACCESS_EXPR':
                    obj = tgt['c1'][0] if tgt['c1'] else None
                    ov = self.sites_of(obj, fn, scope) if obj is not None else VS_EMPTY
                    base = (obj['ty'].split('<')[0]) if obj is not None else ''
                    self.constraints.append(
                        ('store', ('field', base, tgt['s1']), val, ov))
                    # SPEC 5.2.1 obligation 2, and the case that can actually
                    # fail it: `param.field = Foo{}` stores into an object this
                    # function did not allocate.
                    self.owner_uses.append((fn, ov))
            return

        if k == 'RETURN_STATEMENT':
            if n['c1']:
                v = self.sites_of(n['c1'][0], fn, scope)
                self.constraints.append(('bind', ('ret', fn), v))
                self.constraints.append(('escape_caller', v))
            return

        for slot in ('c1', 'c2', 'c3'):
            for c in n[slot]:
                if c['k'] in ('BLOCK', 'VARIABLE_DECL', 'ASSIGNMENT_STATEMENT',
                              'RETURN_STATEMENT', 'IF_STATEMENT', 'WHILE_STATEMENT',
                              'FOR_STATEMENT', 'LOOP_STATEMENT', 'MATCH_STATEMENT',
                              'MATCH_ARM', 'EXPRESSION_STATEMENT', 'REGION_STATEMENT'):
                    self.walk(c, fn, scope)
                else:
                    self.sites_of(c, fn, scope)

    # -- fixed point ---------------------------------------------------------

    def resolve(self, vs):
        """Flatten a value-set expression against the current points-to state."""
        out = set(vs[0])
        for key in vs[1]:
            out |= self.pt[key]
        return out

    def resolve_views(self, vs):
        """SPEC 8.4. The collections whose lifetime this value set depends on:
        its own provenance, plus that of every key it reads through.

        Not recursive past one key hop, and it does not need to be -- a key's
        set is already the union of everything ever bound into it, provenance
        included, so the transitive closure is taken by the points-to fixed
        point rather than here. Mirrors resolve_views in aif_support.c."""
        out = set()
        for csites, ckeys in vs[2]:
            out |= self.resolve((csites, ckeys, frozenset()))
        for key in vs[1]:
            out |= self.key_views[key]
        return out

    def raise_view_owners(self, vs, target, in_fn):
        """SPEC 8.4 E-VIEW:  v is a view of c  =>  E(c) ⊒ E(v).

        Applied wherever a rule bounds how long the *view* lives, because that
        bound is exactly what the collection has to satisfy. The direction is
        the opposite of every other rule here: the collection is raised to cover
        the view, because a view must not outlive what it views.

        A is deliberately untouched -- SPEC 8.4 permits overlapping mutable
        views. Mirrors raise_view_owners in aif_support.c."""
        owners = self.resolve_views(vs)
        if not owners:
            return False
        any_moved = False
        for c in owners:
            # A Region target names a scope of `in_fn`. When the collection was
            # allocated in a different function this rule contributes nothing:
            # the view dies with that activation, and the collection reached
            # `in_fn` either as an argument (live across the call already),
            # as a return (E-RETURN has it at Caller), or from static storage
            # (E-STATIC has it Global). A view that outlives `in_fn` arrives
            # here with a function-independent target instead. See the same
            # case analysis in raise_view_owners in aif_support.c.
            if (isinstance(target, tuple) and target[0] == 'R'
                    and in_fn is not None and self.m.sites[c].fn != in_fn):
                continue
            j = escape_join(self.m.scopes, self.E[c], target)
            if j != self.E[c]:
                self.E[c] = j
                self.moved(c)
                any_moved = True
        return any_moved

    def solve_points_to(self, max_rounds):
        """Every rule that writes pt or holders reads only pt, so points-to has
        a least fixed point independent of the facts. Reaching it first changes
        no answer; it changes the frontier a truncated fact phase leaves behind
        (see widen_unconverged). Mirrors solve_points_to in aif_support.c."""
        for _ in range(max_rounds):
            self.rounds += 1
            changed = False
            for c in self.constraints:
                kind = c[0]
                if kind not in ('bind', 'arg', 'store'):
                    continue
                key, val = c[1], c[2]
                v = self.resolve(val)
                if not v <= self.pt[key]:
                    self.pt[key] |= v
                    changed = True
                # SPEC 8.4. View provenance flows with the value, into the key
                # it is bound, passed or stored into. Grown here rather than in
                # the fact loop because it reads only value sets and pt, so the
                # fact phase gets to run over a finished relation -- exactly as
                # it does for pt itself.
                vw = self.resolve_views(val)
                if vw and not vw <= self.key_views[key]:
                    self.key_views[key] |= vw
                    changed = True
                if kind == 'arg':       # passing does not make a holder
                    continue
                for s in v:
                    if kind == 'bind' and key[0] not in ('var', 'field', 'ret'):
                        continue
                    if key not in self.holders[s]:
                        self.holders[s].add(key)
                        changed = True
            if not changed:
                return True
        return False

    def solve(self, max_rounds=200):
        """Round-synchronous (Jacobi) iteration, per INFERENCE 5.1: every round
        reads the previous round's state, so the result cannot depend on the
        order constraints happen to be listed in."""
        scopes = self.m.scopes
        self.rounds = 0
        if not self.solve_points_to(max_rounds):
            self.delta_pt = True
            self.pt_rounds = self.rounds
            return False
        self.pt_rounds = self.rounds

        # Nothing proved yet, so a budget with no round left for the facts
        # leaves the whole graph unresolved. Overwritten by the first round run.
        self.delta = set(range(len(self.m.sites)))

        for r in range(self.rounds, max_rounds):
            self.rounds = r + 1
            changed = False
            self.delta = set()
            self.delta_pt = False

            for c in self.constraints:
                kind = c[0]

                if kind == 'bind':
                    _, key, val = c
                    v = self.resolve(val)
                    if not v <= self.pt[key]:
                        self.pt[key] |= v
                        changed = self.delta_pt = True
                    for s in v:
                        if key[0] in ('var', 'field', 'ret'):
                            if key not in self.holders[s]:
                                self.holders[s].add(key)
                                changed = self.delta_pt = True

                elif kind == 'arg':
                    _, key, val = c
                    v = self.resolve(val)
                    if not v <= self.pt[key]:
                        self.pt[key] |= v
                        changed = self.delta_pt = True
                    for s in v:                       # A-CALL: passing borrows
                        if self.A[s] < BORROWED:
                            self.A[s] = BORROWED
                            changed = self.moved(s)

                elif kind == 'store':
                    _, key, val, owners = c
                    v = self.resolve(val)
                    ow = self.resolve(owners)
                    if not v <= self.pt[key]:
                        self.pt[key] |= v
                        changed = self.delta_pt = True
                    for s in v:
                        if key not in self.holders[s]:
                            self.holders[s].add(key)
                            changed = self.delta_pt = True
                        # E-STORE: reachable from the container, so at least as
                        # long-lived as it.
                        for o in ow:
                            j = escape_join(scopes, self.E[s], self.E[o])
                            if j != self.E[s]:
                                self.E[s] = j
                                changed = self.moved(s)
                            # A-STORE: sharing is inherited through reachability
                            if self.A[o] > self.A[s]:
                                self.A[s] = self.A[o]
                                changed = self.moved(s)
                            # T-REACH: thread affinity is inherited through
                            # reachability too. Anything reachable from
                            # something a task can see, that task can see.
                            if self.T[o] > self.T[s]:
                                self.T[s] = self.T[o]
                                changed = self.moved(s)
                    # E-VIEW: storing a view into a field makes the viewed
                    # collection live at least as long as the object holding it.
                    for o in ow:
                        if self.raise_view_owners(val, self.E[o],
                                                  self.m.sites[o].fn):
                            changed = True

                elif kind == 'live_in':
                    _, val, scope, fn = c
                    for s in self.resolve(val):
                        site = self.m.sites[s]
                        # Cross-function flow does not extend a lifetime; only a
                        # binding in the site's own function can (see module docs).
                        tgt = ('R', scope) if site.fn == fn else CALLER
                        j = escape_join(scopes, self.E[s], tgt)
                        if j != self.E[s]:
                            self.E[s] = j
                            changed = self.moved(s)
                    # E-VIEW: this binding is how long the view lives, so it is
                    # how long the collection has to.
                    if self.raise_view_owners(val, ('R', scope), fn):
                        changed = True

                elif kind == 'opaque':
                    for s in self.resolve(c[1]):
                        if self.E[s] != GLOBAL:
                            j = escape_join(scopes, self.E[s], CALLER)
                            if j != self.E[s]:
                                self.E[s] = j
                                changed = self.moved(s)
                        if self.A[s] < SHARED:
                            self.A[s] = SHARED
                            changed = self.moved(s)
                    # A view handed to something we cannot see could be kept.
                    if self.raise_view_owners(c[1], CALLER, None):
                        changed = True

                elif kind == 'retain_in':
                    # E-STORE / A-STORE against a container reached through a
                    # call rather than a field assignment.
                    _, val, holder = c
                    hs = self.resolve(holder)
                    for s in self.resolve(val):
                        for h in hs:
                            j = escape_join(scopes, self.E[s], self.E[h])
                            if j != self.E[s]:
                                self.E[s] = j
                                changed = self.moved(s)
                            if self.A[h] > self.A[s]:
                                self.A[s] = self.A[h]
                                changed = self.moved(s)
                            # T-REACH, through a container rather than a field.
                            if self.T[h] > self.T[s]:
                                self.T[s] = self.T[h]
                                changed = self.moved(s)
                            # Which containers hold it, not merely that one does:
                            # the count is what A-CONTAIN reads.
                            if h not in self.container_of[s]:
                                self.container_of[s].add(h)
                                changed = self.moved(s)
                        if self.A[s] < BORROWED:
                            self.A[s] = BORROWED
                            changed = self.moved(s)
                    # E-VIEW: pushing a view into a container makes the viewed
                    # collection live at least as long as that container.
                    for h in hs:
                        if self.raise_view_owners(val, self.E[h],
                                                  self.m.sites[h].fn):
                            changed = True

                elif kind == 'borrow':
                    # Raises A to Borrowed for the call's duration and nothing
                    # else. Escape is untouched: a callee that does not retain
                    # cannot extend a lifetime (FFI 6, `borrow` row).
                    for s in self.resolve(c[1]):
                        if self.A[s] < BORROWED:
                            self.A[s] = BORROWED
                            changed = self.moved(s)

                elif kind == 'escape_caller':
                    for s in self.resolve(c[1]):
                        j = escape_join(scopes, self.E[s], CALLER)
                        if j != self.E[s]:
                            self.E[s] = j
                            changed = self.moved(s)
                    # E-VIEW, and the case the safety gap was actually about:
                    # `return list_get(l, i)` hands the caller a reference into
                    # a collection this frame owns. The collection follows.
                    if self.raise_view_owners(c[1], CALLER, None):
                        changed = True

                elif kind == 'foreign':
                    for s_ in self.resolve(c[1]):
                        if s_ not in self.foreign:
                            self.foreign.add(s_)
                            changed = self.moved(s_)

                elif kind == 'no_stack':
                    for s in self.resolve(c[1]):
                        if s not in self.no_stack:
                            self.no_stack.add(s)
                            changed = self.moved(s)

                elif kind == 'spawn':
                    # INFERENCE 4.1's E-SPAWN / E-SPAWN-J and 4.3's
                    # T-SPAWN-MOVE / T-SPAWN-SHARE: the same arguments seen
                    # through two domains. Mirrors AIF_CON_SPAWN.
                    _, args, sp_scope, joined = c
                    for s in self.resolve(args):
                        if joined:
                            # E-SPAWN-J. The argument has to outlive the join
                            # and nothing more. INFERENCE calls this the place
                            # structured concurrency pays, and this branch is
                            # the whole difference between T1 and T4.
                            j = escape_join(scopes, self.E[s], ('R', sp_scope))
                            if j != self.E[s]:
                                self.E[s] = j
                                changed = self.moved(s)
                        else:
                            # E-SPAWN. An unjoined task may outlive every scope
                            # here, so the value is reachable from a root whose
                            # end this analysis cannot see.
                            if self.E[s] != GLOBAL:
                                self.E[s] = GLOBAL
                                changed = self.moved(s)

                        # T-SPAWN-MOVE. The argument was moved in, so exactly
                        # one task can reach it at a time. Transferred, not
                        # CrossThread -- this is the case T3's non-atomic count
                        # is sound for, and keeping it out of CrossThread is the
                        # entire point of SPEC 11 item 10.
                        if self.T[s] < TRANSFERRED:
                            self.T[s] = TRANSFERRED
                            changed = self.moved(s)

                        # T-SPAWN-SHARE is not here. It is a per-site rule
                        # below: the argument is not the only thing the task
                        # can reach, and the sharing shows up on what it
                        # reaches rather than on the argument itself.

                elif kind == 'escape_global':
                    for s in self.resolve(c[1]):
                        if self.E[s] != GLOBAL:
                            self.E[s] = GLOBAL
                            changed = self.moved(s)
                    # E-VIEW: a view kept forever keeps its collection forever.
                    if self.raise_view_owners(c[1], GLOBAL, None):
                        changed = True


            # A-ESCAPE and the copy rule, applied to every site each round.
            for s_id, site in enumerate(self.m.sites):
                if self.E[s_id] == GLOBAL and self.A[s_id] < SHARED:
                    self.A[s_id] = SHARED
                    changed = self.moved(s_id)
                # A-COPY: only copyable types can be multiply held. Structs are
                # affine (compiler-enforced), so multiple holders means sequential
                # ownership, not aliasing.
                if (not self.m.is_move_only(site.type)
                        and len(self.holders[s_id]) >= 2
                        and self.A[s_id] < SHARED):
                    self.A[s_id] = SHARED
                    changed = self.moved(s_id)
                # A-CONTAIN: two containers holding one value is sharing, whatever
                # the type. A-COPY exempts move-only values because a second
                # *binding* is a move, so the earlier one is provably dead -- and
                # that argument does not reach a container, because list_push is a
                # call and a call is not a move. Once a container teardown releases
                # its elements, two owners is the double free.
                if (len(self.container_of[s_id]) >= 2
                        and self.A[s_id] < SHARED):
                    self.A[s_id] = SHARED
                    changed = self.moved(s_id)
                # T-SPAWN-SHARE, as a per-site rule over the two facts.
                #
                # The premise is A = Shared rather than syntax because under
                # affine references INFERENCE's "y is still live in the parent"
                # is never syntactically true -- the move checker rejects any
                # program that names the value twice. SHARED is INFERENCE 2.2's
                # "two or more references whose relative lifetimes are not
                # statically ordered", which is the fact that survives.
                #
                # Per-site rather than on the spawn's arguments because testing
                # the arguments alone is unsound: the argument is the
                # container, and the shared thing is the element, which reaches
                # Transferred through T-REACH and appears in no spawn's value
                # set. tests/aif_concurrency_shared.psm is that program.
                if (self.T[s_id] >= TRANSFERRED and self.A[s_id] >= SHARED
                        and self.T[s_id] < CROSS_THREAD):
                    self.T[s_id] = CROSS_THREAD
                    changed = self.moved(s_id)
                # T-STATIC. A static root in a program with concurrency is
                # assumed reachable from every task. INFERENCE calls this
                # deliberately blunt, and refining it wants a global
                # reachability analysis whose payoff is small where static
                # mutable roots are rare.
                if (self.has_tasks and self.E[s_id] == GLOBAL
                        and self.T[s_id] < CROSS_THREAD):
                    self.T[s_id] = CROSS_THREAD
                    changed = self.moved(s_id)
                # C-UNIQUE / C-TYPE (INFERENCE 4.4 stage 2)
                acyclic = (self.A[s_id] == UNIQUE
                           or self.m.type_acyclic.get(site.type, True))
                want = ACYCLIC if acyclic else MAYBE_CYCLIC
                if want > self.C[s_id]:
                    self.C[s_id] = want
                    changed = self.moved(s_id)

            if not changed:
                return True
        return False        # budget exhausted -> caller must widen (INFERENCE 5.3)

    def moved(self, s):
        """Records s in this round's delta and returns True, so a rule reads
        `changed = self.moved(s)`."""
        self.delta.add(s)
        return True

    def widen_unconverged(self):
        """INFERENCE 5.3: a truncated ascending iteration is a *pre*-fixed point
        and is unsound, so what is still in motion goes to TOP.

        U := delta union transitive_succs(delta). If a site's facts change in
        round r+1 then some input of it changed in round r, so the closure of
        the last round's delta contains everything still moving. Fact flow runs
        owner -> value and only through store and retain_in; every other rule
        raises from a constant and the per-site rules are self-edges. Those
        edges are read out of points-to, which is final by the time the fact
        phase runs -- unless the budget stopped points-to itself, and then no
        set is final and the whole graph is the only sound answer.
        """
        if self.delta_pt:
            u = set(range(len(self.m.sites)))
        else:
            succ = {}
            for c in self.constraints:
                if c[0] == 'store':
                    vals, owners = self.resolve(c[2]), self.resolve(c[3])
                elif c[0] == 'retain_in':
                    vals, owners = self.resolve(c[1]), self.resolve(c[2])
                else:
                    continue
                for o in owners:
                    succ.setdefault(o, set()).update(vals)

            u, work = set(self.delta), list(self.delta)
            while work:
                for w in succ.get(work.pop(), ()):
                    if w not in u:
                        u.add(w)
                        work.append(w)

        for s in u:
            self.E[s] = GLOBAL
            self.A[s] = SHARED
            self.C[s] = MAYBE_CYCLIC
            # Top of the T lattice too -- but only where a task exists to reach
            # it from. Skipping the raise entirely would make a truncated build
            # *cheaper* than a converged one, which is the unsoundness widening
            # exists to prevent. Guarding it is not a weakening: "this program
            # contains no spawn" is not something the iteration was trying to
            # prove and ran out of rounds for, it is something the constraint
            # set already said. CrossThread in a task-free module would be a
            # false statement that costs atomics.
            if self.has_tasks:
                self.T[s] = CROSS_THREAD
        self.widened = u


# ---------------------------------------------------------------------------
# Tier derivation (SPEC 4.2)
# ---------------------------------------------------------------------------

THETA_STACK_FIELDS = 8      # A5: field-count stand-in for a byte threshold


def tier_of(model, eng, sid):
    site = model.sites[sid]
    E, A, C, T = eng.E[sid], eng.A[sid], eng.C[sid], eng.T[sid]

    # in_container joins no_stack for the same reason: the container reclaims its
    # elements, and a frame slot is not something a deallocator can take.
    # Reachable whenever container and element share a scope, which leaves every
    # other T0 conjunct satisfied.
    if (E == ('R', site.scope) and A <= BORROWED
            and site.kind == 'struct' and site.nfields <= THETA_STACK_FIELDS
            and sid not in eng.no_stack and sid not in eng.foreign
            and not eng.container_of[sid]):
        return 'T0'
    # Neither this clause nor T0's tests T, which is SPEC 4.2 read literally: a
    # value whose escape bottoms inside a region never left it, and E-SPAWN-J is
    # what keeps a joined task's arguments there. INFERENCE 4.1's "this single
    # distinction determines whether concurrent code lands at T1 or T4" shows up
    # here as the *absence* of a test.
    if E != CALLER and E != GLOBAL:
        return 'T1'
    if A <= BORROWED and T <= TRANSFERRED:
        return 'T2'
    if T <= TRANSFERRED and C == ACYCLIC:
        return 'T3'
    # REQUIREMENTS 15 made this reachable; A4 used to say it was not, because
    # the language had no tasks. A module with no `spawn` still cannot get here:
    # nothing raises T above ISOLATED without a spawn constraint, so both
    # conjuncts above stay true and the ladder reads exactly as it did.
    if T == CROSS_THREAD:
        return 'T4a'
    return 'T4b'


# ---------------------------------------------------------------------------
# Report
# ---------------------------------------------------------------------------

def bracket_masks(model, eng):
    """SPEC 5.2.1: per function, may a caller's `region` bracket a call to it?

    The obligations, and what each one is guarding against:

      GLOBAL       an allocation in the extent escapes to static storage, so
                   nothing bounds its lifetime and no region can.
      PARAM_STORE  the extent stores into something it did not allocate:

                       fn add_to(dest: List<Node>, n: Int) {
                           list_push(dest, Node { id: n })
                       }
                       region R { add_to(long_lived_list, 5) }

                   the Node comes from R's arena and the list outlives R.
      OPAQUE       a callee with no visible body and no complete contract.
      DROP         `drop(x)` inside the extent -- the source decided when that
                   value dies, and a bump pointer is not a thing free() takes.
      SHARED_BODY  a body inside the extent is reachable from outside it, so it
                   would serve more than one placement regime. Not an allocation
                   obligation; regime (a)'s restriction on codegen, reported
                   beside the safety answer rather than folded into it. Only
                   counted for a body that allocates -- one with nothing below it
                   to allocate compiles identically inside and outside a bracket,
                   so sharing it decides no regime.
      MULTI_CALL   the body has other than exactly one call site, so which regime
                   it serves is a question about a *region* rather than about the
                   program. Split out of SHARED_BODY 2026-08-28: two call sites
                   both bracketed into the same region is still one regime. The
                   region-side half is `bracket_regime_ok` in the compiler and is
                   deliberately not modelled here, for the same reason
                   `region-calls` is not -- it depends on placement.

    Obligation 4 is not a blocker but how every clause is evaluated: mutual
    recursion makes the transitive callee set a closure, not a walk. Mirrors
    aif_fn_bracket_blockers in runtime/aif_support.c.
    """
    callees = defaultdict(set)
    calls_opaque = set()
    call_count = Counter()
    for caller, callee, _scope in eng.call_edges:
        if callee is None:
            calls_opaque.add(caller)
        else:
            callees[caller].add(callee)
            call_count[callee] += 1

    has_global, has_drop = set(), set()
    for sid, site in enumerate(model.sites):
        if eng.E[sid] == GLOBAL:
            has_global.add(site.fn)
        if sid in eng.no_stack:
            has_drop.add(site.fn)

    owner_fns = defaultdict(set)
    for f, vs in eng.owner_uses:
        for s in eng.resolve(vs):
            owner_fns[f].add(model.sites[s].fn)

    def reachable(f):
        seen, work = {f}, [f]
        while work:
            for h in callees[work.pop()]:
                if h not in seen:
                    seen.add(h)
                    work.append(h)
        return seen

    # Does this function, or anything it can reach, allocate at all? Mirrors
    # fn_allocs_reach in bracket_prepare.
    allocs_reach = defaultdict(bool)
    for site in model.sites:
        allocs_reach[site.fn] = True
    spread = True
    while spread:
        spread = False
        for g in model.functions:
            if allocs_reach[g]:
                continue
            if any(allocs_reach[h] for h in callees[g]):
                allocs_reach[g] = True
                spread = True

    masks = {}
    for f in model.functions:
        cl = reachable(f)
        mask = 0
        for g in cl:
            if g in has_global:
                mask |= BR_GLOBAL
            if g in has_drop:
                mask |= BR_DROP
            if g in calls_opaque or g in model.sealed:
                mask |= BR_OPAQUE
            if not owner_fns[g] <= cl:
                mask |= BR_PARAM_STORE
        # Regime (a), in two clauses. MULTI_CALL is the half that depends on
        # where the region is; SHARED_BODY is the half that does not, and it
        # only bites on a body the bracket would change.
        if call_count[f] != 1:
            mask |= BR_MULTI_CALL
        for caller, callee, _scope in eng.call_edges:
            if callee is None or callee == f:
                continue
            if callee in cl and caller not in cl and allocs_reach[callee]:
                mask |= BR_SHARED_BODY
        masks[f] = mask
    return masks


def report_bracketing(model, eng):
    """The counts the differential compares against `prismio aif --summary`.

    **`region-calls` is deliberately absent**, and this is a recorded divergence
    rather than an omission: it counts call sites lexically inside an arena, and
    which scopes get an arena is a *codegen* decision (LAYOUT 7.1's cost model)
    that this oracle does not model at all -- see the note on REGION_STATEMENT in
    Engine.walk. Mirroring it would mean porting placement, which would make the
    oracle a second implementation of the thing it is supposed to check rather
    than an independent one. The compiler-side number is checked instead by
    aif/evidence/arena_census.py over the whole corpus.
    """
    masks = bracket_masks(model, eng)
    n = len(masks)
    regime = BR_SHARED_BODY | BR_MULTI_CALL
    ok = sum(1 for m in masks.values() if not m & ~regime)
    sole = sum(1 for m in masks.values() if m == 0)

    print("\n# call-site bracketing (SPEC 5.2.1) -- may a caller's region reach "
          "a callee's allocations?")
    print(f"bracketable  {ok} / {n}  (obligations 1, 2, 4: nothing the extent "
          f"allocates outlives the call)")
    print(f"sole-regime  {sole}  (of those: one call site, so regime (a) holds "
          f"whatever the region)")
    for label, bit in (("br-global", BR_GLOBAL), ("br-param", BR_PARAM_STORE),
                       ("br-opaque", BR_OPAQUE), ("br-drop", BR_DROP),
                       ("br-shared", BR_SHARED_BODY)):
        print(f"{label:12} {sum(1 for m in masks.values() if m & bit)}")
    print(f"br-multicall {sum(1 for m in masks.values() if m & BR_MULTI_CALL)}"
          f"  (more than one call site: regime (a) is then a question about the "
          f"region)")


def report(model, eng, converged, args):
    tiers = Counter()
    by_kind = defaultdict(Counter)
    records = []

    for sid, site in enumerate(model.sites):
        t = tier_of(model, eng, sid)
        tiers[t] += 1
        by_kind[site.kind][t] += 1
        records.append((site, t, eng.E[sid], eng.A[sid], eng.C[sid], eng.T[sid]))

    total = max(1, sum(tiers.values()))
    cheap = tiers['T0'] + tiers['T1'] + tiers['T2']

    print(f"aif-manifest 1 (prototype)")
    print(f"build       level=AIF-0-prototype  rounds={eng.rounds}  "
          f"converged={'yes' if converged else 'no'}  ffi-default={eng.ffi_default}")
    print(f"sites       {total}   "
          f"(excluded: {eng.literal_strings} string literals -- static, not allocated)")
    print(f"opaque-ret  {eng.opaque_returns}  "
          f"(undeclared extern/sealed returns -- provenance unknown)")
    print(f"extern-alloc {eng.extern_alloc}  "
          f"(values produced by runtime calls, e.g. str_concat)")
    print(f"static-ret  {eng.static_returns}  "
          f"(declared `alias` with nothing to alias -- static, not allocated)")
    print("#")
    print("# tier distribution  (BENCHMARKS H1: static D over abstract values)")
    for t in ('T0', 'T1', 'T2', 'T3', 'T4b', 'T4a'):
        n = tiers[t]
        bar = '#' * int(60 * n / total)
        print(f"  {t:4} {n:6}  {100*n/total:5.1f}%  {bar}")
    print(f"\n  T0-T2 (no runtime bookkeeping): {cheap} / {total} = "
          f"{100*cheap/total:.1f}%")
    print(f"  H1 kill criterion is < 70%.  "
          f"{'PASS' if 100*cheap/total >= 70 else 'FAIL'}"
          f"{'  (>= 90% = the stated claim)' if 100*cheap/total >= 90 else ''}")

    print("\n# by allocation kind -- where the residue actually lives")
    hdr = f"  {'kind':8} {'sites':>6} " + ' '.join(f'{t:>6}' for t in
                                                   ('T0','T1','T2','T3','T4b','T4a'))
    print(hdr)
    for kind in sorted(by_kind, key=lambda k: -sum(by_kind[k].values())):
        c = by_kind[kind]
        n = sum(c.values())
        print(f"  {kind:8} {n:6} " +
              ' '.join(f"{c[t]:6}" for t in ('T0','T1','T2','T3','T4b','T4a')))

    if args.sites:
        print("\n# worst offenders (T3/T4 by source position)")
        bad = [r for r in records if r[1] in ('T3', 'T4b', 'T4a')]
        bad.sort(key=lambda r: (r[0].file, r[0].line))
        for site, t, E, A, C, T in bad[:args.sites]:
            path = model.files.get(site.file, '?')
            e = 'Global' if E == GLOBAL else ('Caller' if E == CALLER else 'Region')
            print(f"  {t:4} {site.type:16} {path}:{site.line}:{site.col}"
                  f"   E={e} A={ALIAS_NAME[A]} T={THREAD_NAME[T]}")

    # INFERENCE 2.3, as a distribution. Compared by tools/aif_differential.py,
    # which is the point: the tier counts alone cannot separate "the thread
    # module agrees" from "neither implementation has one", and for six sessions
    # neither did.
    print("\n# thread affinity (INFERENCE 2.3)")
    threads = Counter(THREAD_NAME[r[5]] for r in records)
    for name in ('Isolated', 'Transferred', 'CrossThread'):
        print(f"  {name:12} {threads[name]}")

    print(f"\n# cyclicity (CYCLES 1-2)")
    cyc = [t for t, ok in model.type_acyclic.items() if not ok]
    if cyc:
        print(f"  collector needed: {len(cyc)} of {len(model.structs)} struct types "
              f"lie in or reach a non-trivial SCC")
        print(f"    {', '.join(sorted(cyc)[:12])}"
              f"{' ...' if len(cyc) > 12 else ''}")
    else:
        print(f"  none -- no struct type lies in a non-trivial SCC. "
              f"Collector omitted from the binary entirely.")

    report_bracketing(model, eng)


def measure_masks(model, dump):
    """H4 leading indicator: how many of a function's reference parameters can
    actually influence anything? If this is close to the full parameter count,
    3^n does not collapse and specialisation is expensive.

    Approximated structurally: a reference parameter is *relevant* when it is
    stored into a field, returned, or passed on to another function -- the three
    ways INFERENCE 4 lets a parameter's mode reach a conclusion. A parameter only
    read scalar-wise cannot change any output."""
    widths, totals = [], []
    for sym, fn in model.functions.items():
        params = [p for p in fn['c1']
                  if p['k'] == 'FUNCTION_PARAMETER' and model.is_ref(p['ty'])]
        if not params:
            continue
        names = {p['s1'] for p in params}
        relevant = set()

        def scan(n, in_store, in_ret, in_call):
            if n['k'] == 'IDENTIFIER_EXPR' and n['s1'] in names:
                if in_store or in_ret or in_call:
                    relevant.add(n['s1'])
            k = n['k']
            for slot in ('c1', 'c2', 'c3'):
                for c in n[slot]:
                    scan(c,
                         in_store or (k == 'ASSIGNMENT_STATEMENT' and slot == 'c2'),
                         in_ret or k == 'RETURN_STATEMENT',
                         in_call or (k == 'CALL_EXPR' and slot == 'c2'))

        for b in fn['c2']:
            scan(b, False, False, False)
        widths.append(len(relevant))
        totals.append(len(params))

    if not widths:
        print("no reference-taking functions found")
        return

    n = len(widths)
    mean_w = sum(widths) / n
    mean_t = sum(totals) / n
    sw = sorted(widths)
    p95 = sw[min(n - 1, int(0.95 * n))]
    print(f"# relevant-parameter mask  (INFERENCE 7.1, BENCHMARKS H4 indicator)")
    print(f"  functions with reference params : {n}")
    print(f"  mean reference params           : {mean_t:.2f}")
    print(f"  mean *relevant* params (mask)   : {mean_w:.2f}")
    print(f"  p95 mask width                  : {p95}")
    print(f"  worst-case contexts 3^mean_mask : {3**mean_w:,.0f}"
          f"   (vs 3^{mean_t:.2f} = {3**mean_t:,.0f} unmasked)")
    dist = Counter(widths)
    print("  mask width distribution:")
    for w in sorted(dist):
        print(f"    {w:2} relevant : {dist[w]:5}  {'#' * int(50*dist[w]/n)}")

    # The number that actually decides code size is the absolute count of
    # bodies, not the proportional reduction the mask achieves. A ratio test is
    # meaningless when the base is already small.
    bodies_masked = sum(3 ** w for w in widths)
    bodies_raw = sum(3 ** t for t in totals)
    print(f"\n  worst-case bodies, unmasked : {bodies_raw:,} "
          f"({bodies_raw/n:.1f}x per function)")
    print(f"  worst-case bodies, masked   : {bodies_masked:,} "
          f"({bodies_masked/n:.1f}x per function)")
    print(f"  mask saves                  : "
          f"{100*(1-bodies_masked/bodies_raw):.0f}% of the worst case")
    print("\n  Note: 3^n is the *worst case*. Contexts are demand-driven "
          "(INFERENCE 6.3),\n  so the realised count is bounded by contexts that "
          "actually occur at call sites.")
    if bodies_masked / n <= 4.0:
        print("\n  -> worst-case multiplier is small. H4 indicator PASSES: `3^n` is "
              "not a\n     threat in this corpus, because n is small to begin with.")
    else:
        print(f"\n  -> worst-case multiplier is {bodies_masked/n:.1f}x. H4 indicator "
              "is INCONCLUSIVE\n     from the worst case alone; measure realised "
              "contexts before trusting it.")


def main():
    ap = argparse.ArgumentParser(description="AIF inference engine prototype")
    ap.add_argument('dump', help="JSON from `prismio dump-ast`")
    ap.add_argument('--sites', type=int, default=0,
                    help="list N worst T3/T4 sites with positions")
    ap.add_argument('--masks', action='store_true',
                    help="measure relevant-parameter mask width (H4 indicator)")
    ap.add_argument('--rounds', type=int, default=200)
    ap.add_argument('--ffi', choices=('borrow', 'retain'), default='borrow',
                    help="default contract for undeclared externs (FFI 5.4)")
    ap.add_argument('--seal', default=None,
                    help="treat functions defined in files matching this "
                         "substring as sealed (PIR 5): bodies invisible, "
                         "default contracts applied")
    ap.add_argument('--owned-collections', action='store_true',
                    help="treat String/List/Array as move-only (the default "
                         "since Level 4; accepted for compatibility)")
    ap.add_argument('--copyable-collections', action='store_true',
                    help="model String/List/Array as copyable, i.e. the "
                         "pre-Level-4 language -- the differential's second arm")
    args = ap.parse_args()

    sys.setrecursionlimit(200000)
    with open(args.dump, encoding='utf-8') as f:
        dump = json.load(f)
    if dump.get('format') != 'aif-ast':
        sys.exit("not an aif-ast dump")

    model = Model(dump)
    model.owned_collections = not args.copyable_collections
    if args.seal:
        for sym, fid in model.fn_file.items():
            if args.seal in model.files.get(fid, ''):
                model.sealed.add(sym)
        print(f"# sealed: {len(model.sealed)} functions from files matching "
              f"{args.seal!r}")
    print(f"# {dump['source']}  ({len(model.files)} files, "
          f"{len(model.functions)} functions, {len(model.structs)} structs)\n")

    if args.masks:
        measure_masks(model, dump)
        return

    eng = Engine(model, ffi_default=args.ffi)
    eng.build()
    converged = eng.solve(args.rounds)
    if not converged:
        eng.widen_unconverged()
    report(model, eng, converged, args)


if __name__ == '__main__':
    main()
