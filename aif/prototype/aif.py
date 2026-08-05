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
  A4  Thread affinity is vacuous -- the language has no tasks, so every value is
      Isolated and T4a is unreachable by construction.
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

ALIAS_NAME = {UNIQUE: 'Unique', BORROWED: 'Borrowed', SHARED: 'Shared'}

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
    'list_set':       {0: 'borrow', 1: ('retain_in', 0), 2: 'borrow'},
    'list_get':       {0: 'borrow'},          # returns an alias into arg 0
    'list_len':       {0: 'borrow'},
    'list_new':       {},                     # produces a fresh container
    'str_concat':     {0: 'borrow', 1: 'borrow'},
    'str_equals':     {0: 'borrow', 1: 'borrow'},
    'str_length':     {0: 'borrow'},
    'str_substring':  {0: 'borrow'},
    'str_index_of':   {0: 'borrow', 1: 'borrow'},
    'str_contains':   {0: 'borrow', 1: 'borrow'},
    'str_starts_with': {0: 'borrow', 1: 'borrow'},
    'str_ends_with':  {0: 'borrow', 1: 'borrow'},
    'str_char_at':    {0: 'borrow'},
    'str_byte_at':    {0: 'borrow'},
    'print':          {0: 'borrow'},
    'println':        {0: 'borrow'},
}

# Externs whose return value aliases an argument rather than allocating
# (FFI 5.2 `alias`). Modelled by returning the argument's own sites, so an
# element read back out of a list is the element, not a fresh allocation.
FFI_RETURNS_ALIAS_OF = {'list_get': 0}

# Return contracts (FFI 5.2). 'produce' = a fresh owned value the caller must
# release; anything undeclared has UNKNOWN provenance and must be treated
# conservatively -- it may already be shared and may already outlive us.
FFI_RETURNS_PRODUCE = {
    'list_new', 'str_concat', 'str_substring', 'str_from_char', 'int_to_str',
    'read_file', 'get_directory', 'join_path',
}


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

        for d in dump['decls']:
            if d['k'] == 'STRUCT_DECL':
                self.structs[d['s1']] = [
                    (f['s1'], f['c1'][0]['s1'] if f['c1'] else '')
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

    # Set by --owned-collections. Today's Prismio makes only structs move-only
    # (types.psm), which is scaffolding: AIF specifies affine references for
    # every heap value (SPEC 11 item 10). This flag measures the difference.
    owned_collections = False

    def is_move_only(self, ty):
        if ty in self.structs:
            return True
        if self.owned_collections:
            return (ty == 'String' or ty.startswith('List')
                    or ty.startswith('[') or ty.startswith('Array'))
        return False

    def site_kind(self, ty):
        if ty in self.structs:
            return 'struct'
        if ty == 'String':
            return 'string'
        if ty.startswith('List'):
            return 'list'
        if ty.startswith('[') or ty.startswith('Array'):
            return 'array'
        return 'opaque'

    def _compute_type_acyclic(self):
        """Tarjan-free SCC via iterative Kosaraju on the type reference graph
        (INFERENCE 4.4 stage 1). A type is acyclic when its SCC is trivial and
        it reaches no non-trivial SCC."""
        g = {t: set() for t in self.structs}
        for t, fields in self.structs.items():
            for _, fty in fields:
                base = fty.split('<')[0].strip('[]')
                if base in self.structs:
                    g[t].add(base)
                # List<T>/[T] of a struct reaches that struct
                if '<' in fty:
                    inner = fty[fty.find('<') + 1:fty.rfind('>')]
                    if inner in self.structs:
                        g[t].add(inner)

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
VS_EMPTY = (frozenset(), frozenset())


def vs_sites(*ids):
    return (frozenset(ids), frozenset())


def vs_ref(key):
    return (frozenset(), frozenset([key]))


def vs_union(a, b):
    return (a[0] | b[0], a[1] | b[1])


class Engine:
    def __init__(self, model, ffi_default='borrow'):
        self.m = model
        self.ffi_default = ffi_default
        self.literal_strings = 0
        self.extern_alloc = 0
        self.opaque_returns = 0
        self.pt = defaultdict(set)        # ('var', fn, name) | ('field', ty, f)
                                          # | ('ret', fn) | ('param', fn, i) -> {site}
        self.E = {}                       # site -> escape
        self.A = {}                       # site -> alias
        self.C = {}                       # site -> cyclicity
        self.holders = defaultdict(set)   # site -> {holder keys}, for A-COPY
        self.constraints = []             # deferred (kind, args) edges
        self.rounds = 0

    # -- construction --------------------------------------------------------

    def build(self):
        for sym, fn in self.m.functions.items():
            root = self.m.scopes.new(None, sym)
            for p_i, p in enumerate(fn['c1']):
                if p['k'] != 'FUNCTION_PARAMETER':
                    continue
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
            return vs_sites(sid)

        if k == 'ARRAY_LITERAL_EXPR':
            return vs_sites(self.new_site(ty or 'Array', fn, scope, e))

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

        if k == 'CALL_EXPR':
            callee = e['s2'] or (e['c1'][0]['s1'] if e['c1'] else '')
            plain = e['c1'][0]['s1'] if e['c1'] else callee
            # A sealed function has no visible body (PIR 5), so it is analysed
            # exactly like an FFI call: contracts only, no inference across it.
            known = callee in self.m.functions and callee not in self.m.sealed
            contracts = FFI_CONTRACTS.get(plain, {})
            argvals = [self.sites_of(a, fn, scope) for a in e['c2']]

            for i, av in enumerate(argvals):
                if known:
                    self.constraints.append(('arg', ('param', callee, i), av))
                    continue
                c = contracts.get(i, self.ffi_default)
                if isinstance(c, tuple) and c[0] == 'retain_in':
                    # The callee stores this argument into another argument, so
                    # it escapes exactly as far as that container does.
                    holder = argvals[c[1]] if c[1] < len(argvals) else VS_EMPTY
                    self.constraints.append(('retain_in', av, holder))
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
            alias_of = FFI_RETURNS_ALIAS_OF.get(plain)
            if alias_of is not None and alias_of < len(argvals):
                return argvals[alias_of]         # FFI 5.2 `alias`
            if self.m.is_ref(ty):
                self.extern_alloc += 1
                sid = self.new_site(ty, fn, scope, e)
                if plain not in FFI_RETURNS_PRODUCE:
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

    def ref(self, key):
        self.pt[key]                      # touch so it exists
        return vs_ref(key)

    # -- statement walk ------------------------------------------------------

    def walk(self, n, fn, scope):
        k = n['k']

        if k == 'BLOCK':
            inner = self.m.scopes.new(scope, fn)
            for slot in ('c1', 'c2', 'c3'):
                for c in n[slot]:
                    self.walk(c, fn, inner)
            return

        if k == 'VARIABLE_DECL':
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
                    self.constraints.append(('live_in', val, scope, fn))
                elif tgt['k'] == 'MEMBER_ACCESS_EXPR':
                    obj = tgt['c1'][0] if tgt['c1'] else None
                    ov = self.sites_of(obj, fn, scope) if obj is not None else VS_EMPTY
                    base = (obj['ty'].split('<')[0]) if obj is not None else ''
                    self.constraints.append(
                        ('store', ('field', base, tgt['s1']), val, ov))
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
                              'MATCH_ARM', 'EXPRESSION_STATEMENT'):
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

    def solve(self, max_rounds=200):
        """Round-synchronous (Jacobi) iteration, per INFERENCE 5.1: every round
        reads the previous round's state, so the result cannot depend on the
        order constraints happen to be listed in."""
        scopes = self.m.scopes
        for r in range(max_rounds):
            self.rounds = r + 1
            changed = False

            for c in self.constraints:
                kind = c[0]

                if kind == 'bind':
                    _, key, val = c
                    v = self.resolve(val)
                    if not v <= self.pt[key]:
                        self.pt[key] |= v
                        changed = True
                    for s in v:
                        if key[0] in ('var', 'field', 'ret'):
                            if key not in self.holders[s]:
                                self.holders[s].add(key)
                                changed = True

                elif kind == 'arg':
                    _, key, val = c
                    v = self.resolve(val)
                    if not v <= self.pt[key]:
                        self.pt[key] |= v
                        changed = True
                    for s in v:                       # A-CALL: passing borrows
                        if self.A[s] < BORROWED:
                            self.A[s] = BORROWED
                            changed = True

                elif kind == 'store':
                    _, key, val, owners = c
                    v = self.resolve(val)
                    ow = self.resolve(owners)
                    if not v <= self.pt[key]:
                        self.pt[key] |= v
                        changed = True
                    for s in v:
                        if key not in self.holders[s]:
                            self.holders[s].add(key)
                            changed = True
                        # E-STORE: reachable from the container, so at least as
                        # long-lived as it.
                        for o in ow:
                            j = escape_join(scopes, self.E[s], self.E[o])
                            if j != self.E[s]:
                                self.E[s] = j
                                changed = True
                            # A-STORE: sharing is inherited through reachability
                            if self.A[o] > self.A[s]:
                                self.A[s] = self.A[o]
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
                            changed = True

                elif kind == 'opaque':
                    for s in self.resolve(c[1]):
                        if self.E[s] != GLOBAL:
                            j = escape_join(scopes, self.E[s], CALLER)
                            if j != self.E[s]:
                                self.E[s] = j
                                changed = True
                        if self.A[s] < SHARED:
                            self.A[s] = SHARED
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
                                changed = True
                            if self.A[h] > self.A[s]:
                                self.A[s] = self.A[h]
                                changed = True
                        if self.A[s] < BORROWED:
                            self.A[s] = BORROWED
                            changed = True

                elif kind == 'borrow':
                    # Raises A to Borrowed for the call's duration and nothing
                    # else. Escape is untouched: a callee that does not retain
                    # cannot extend a lifetime (FFI 6, `borrow` row).
                    for s in self.resolve(c[1]):
                        if self.A[s] < BORROWED:
                            self.A[s] = BORROWED
                            changed = True

                elif kind == 'escape_caller':
                    for s in self.resolve(c[1]):
                        j = escape_join(scopes, self.E[s], CALLER)
                        if j != self.E[s]:
                            self.E[s] = j
                            changed = True

                elif kind == 'escape_global':
                    for s in self.resolve(c[1]):
                        if self.E[s] != GLOBAL:
                            self.E[s] = GLOBAL
                            changed = True

            # A-ESCAPE and the copy rule, applied to every site each round.
            for s_id, site in enumerate(self.m.sites):
                if self.E[s_id] == GLOBAL and self.A[s_id] < SHARED:
                    self.A[s_id] = SHARED
                    changed = True
                # A-COPY: only copyable types can be multiply held. Structs are
                # affine (compiler-enforced), so multiple holders means sequential
                # ownership, not aliasing.
                if (not self.m.is_move_only(site.type)
                        and len(self.holders[s_id]) >= 2
                        and self.A[s_id] < SHARED):
                    self.A[s_id] = SHARED
                    changed = True
                # C-UNIQUE / C-TYPE (INFERENCE 4.4 stage 2)
                acyclic = (self.A[s_id] == UNIQUE
                           or self.m.type_acyclic.get(site.type, True))
                want = ACYCLIC if acyclic else MAYBE_CYCLIC
                if want > self.C[s_id]:
                    self.C[s_id] = want
                    changed = True

            if not changed:
                return True
        return False        # budget exhausted -> caller must widen (INFERENCE 5.3)

    def widen_unconverged(self):
        """INFERENCE 5.3: a truncated ascending iteration is a *pre*-fixed point
        and is unsound. Everything not known stable goes to TOP."""
        for s in range(len(self.m.sites)):
            self.E[s] = GLOBAL
            self.A[s] = SHARED
            self.C[s] = MAYBE_CYCLIC


# ---------------------------------------------------------------------------
# Tier derivation (SPEC 4.2)
# ---------------------------------------------------------------------------

THETA_STACK_FIELDS = 8      # A5: field-count stand-in for a byte threshold


def tier_of(model, eng, sid):
    site = model.sites[sid]
    E, A, C = eng.E[sid], eng.A[sid], eng.C[sid]

    if (E == ('R', site.scope) and A <= BORROWED
            and site.kind == 'struct' and site.nfields <= THETA_STACK_FIELDS):
        return 'T0'
    if E != CALLER and E != GLOBAL:
        return 'T1'
    if A <= BORROWED:
        return 'T2'
    if C == ACYCLIC:
        return 'T3'
    return 'T4b'            # T4a is unreachable: no concurrency (A4)


# ---------------------------------------------------------------------------
# Report
# ---------------------------------------------------------------------------

def report(model, eng, converged, args):
    tiers = Counter()
    by_kind = defaultdict(Counter)
    records = []

    for sid, site in enumerate(model.sites):
        t = tier_of(model, eng, sid)
        tiers[t] += 1
        by_kind[site.kind][t] += 1
        records.append((site, t, eng.E[sid], eng.A[sid], eng.C[sid]))

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
    print("#")
    print("# tier distribution  (BENCHMARKS H1: static D over abstract values)")
    for t in ('T0', 'T1', 'T2', 'T3', 'T4b'):
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
                                                   ('T0','T1','T2','T3','T4b'))
    print(hdr)
    for kind in sorted(by_kind, key=lambda k: -sum(by_kind[k].values())):
        c = by_kind[kind]
        n = sum(c.values())
        print(f"  {kind:8} {n:6} " +
              ' '.join(f"{c[t]:6}" for t in ('T0','T1','T2','T3','T4b')))

    if args.sites:
        print("\n# worst offenders (T3/T4 by source position)")
        bad = [r for r in records if r[1] in ('T3', 'T4b')]
        bad.sort(key=lambda r: (r[0].file, r[0].line))
        for site, t, E, A, C in bad[:args.sites]:
            path = model.files.get(site.file, '?')
            e = 'Global' if E == GLOBAL else ('Caller' if E == CALLER else 'Region')
            print(f"  {t:4} {site.type:16} {path}:{site.line}:{site.col}"
                  f"   E={e} A={ALIAS_NAME[A]}")

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
                    help="treat String/List/Array as move-only, as AIF specifies "
                         "rather than as today's compiler implements")
    args = ap.parse_args()

    sys.setrecursionlimit(200000)
    with open(args.dump, encoding='utf-8') as f:
        dump = json.load(f)
    if dump.get('format') != 'aif-ast':
        sys.exit("not an aif-ast dump")

    model = Model(dump)
    model.owned_collections = args.owned_collections
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
