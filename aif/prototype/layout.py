#!/usr/bin/env python3
"""
AIF layout optimiser -- prototype.

Implements LAYOUT.md sections 2, 4, 5, 6 and 7 against an AST dumped by
`prismio dump-ast`. This is the half of the model that receives ~80% of the
compile budget (SPEC 9) and is the flagship claim for a game target: automatic
AoS/SoA selection over data whose access pattern the programmer never described.

It uses the STATIC access profile only -- no workload is run. LAYOUT 1 claims
the structural half of layout selection is statically exact (which fields are
co-accessed, in what order, read or written) and that a workload buys only
frequencies. This program is that claim's first test: if the static profile
picks the layouts a human would, the claim holds.

WHAT IS APPROXIMATED
  n(t)      collection length is unknown statically -> assumed larger than L3,
            which biases toward SoA. LAYOUT 2.1 says exactly this.
  iters(t)  10^(loop nesting depth), LAYOUT 10.4's admitted weak point.
  packing   skipped: bit-packing needs observed value ranges, which need a run.
  false     skipped: the language has no concurrency, so tasks(t) is always 1.
  sharing
"""

import json
import sys
import argparse
from collections import defaultdict

sys.path.insert(0, __file__.rsplit('/', 1)[0] if '/' in __file__ else '.')
from aif import Model                                        # noqa: E402

# ---------------------------------------------------------------------------
# Machine model (LAYOUT 4)
# ---------------------------------------------------------------------------

LINE = 64
C1, C2, C3 = 32 * 1024, 1024 * 1024, 32 * 1024 * 1024
MU1, MU2, MU3, MUM = 4, 12, 40, 250
V_SIMD = 32                                   # AVX2
PI = {'sequential': 0.15, 'strided': 0.5, 'random': 1.0}
ALPHA = {'T0': 0, 'T1': 3, 'T2': 90, 'T3': 95, 'T4': 110}
LAMBDA_NUM, LAMBDA_DEN = 2, 100               # 0.02, in fixed point

# Scalar widths, from types.psm: Int=i32, Float=double, Bool=i1, Char=i8.
# Struct-typed fields are pointers in the current implementation.
WIDTH = {'Int': 4, 'I8': 1, 'I16': 2, 'I32': 4, 'I64': 8,
         'U8': 1, 'U16': 2, 'U32': 4, 'U64': 8,
         'Isize': 8, 'Usize': 8, 'Float': 8, 'Bool': 1, 'Char': 1}
PTR = 8


def field_width(model, ty):
    base = ty.split('<')[0].strip('[]')
    if base in WIDTH:
        return WIDTH[base]
    return PTR              # struct, String, List, array -> a pointer today


def field_align(model, ty):
    w = field_width(model, ty)
    return min(w, 8)


# ---------------------------------------------------------------------------
# Static access profile (LAYOUT 2)
# ---------------------------------------------------------------------------

class Traversal:
    __slots__ = ('fn', 'line', 'elem', 'touched', 'writes', 'arith', 'depth',
                 'order')

    def __init__(self, fn, line, elem, order, depth):
        self.fn, self.line, self.elem = fn, line, elem
        self.order, self.depth = order, depth
        self.touched, self.writes = set(), set()
        self.arith = 0

    @property
    def iters(self):
        return 10 ** max(1, self.depth)


LOOPS = ('WHILE_STATEMENT', 'FOR_STATEMENT', 'LOOP_STATEMENT')


class Profile:
    """Extracted entirely from the AST. Every attribute LAYOUT 2.1 marks
    'static, exact' is exact here; the two marked dynamic are estimated."""

    def __init__(self, model, dump):
        self.m = model
        self.traversals = []
        self.reads = defaultdict(int)      # (type, field) -> count
        self.writes = defaultdict(int)
        self.allocs = defaultdict(int)     # type -> count
        for fn in model.functions.values():
            for b in fn['c2']:
                self._scan(b, fn['s2'] or fn['s1'], 0)

    # -- helpers ------------------------------------------------------------

    def _members(self, n, out, writing=False):
        """Collect (owner_type, field, is_write) for every member access in a
        subtree. Works at any nesting depth because sema typed every node:
        `a.b.c` yields (typeof(a), 'b') and (typeof(a.b), 'c')."""
        k = n['k']
        if k == 'MEMBER_ACCESS_EXPR' and n['c1']:
            owner = n['c1'][0]['ty'].split('<')[0]
            if owner in self.m.structs:
                out.append((owner, n['s1'], writing))
            self._members(n['c1'][0], out, False)
            return
        if k == 'ASSIGNMENT_STATEMENT':
            for c in n['c1']:
                self._members(c, out, True)
            for c in n['c2']:
                self._members(c, out, False)
            return
        for slot in ('c1', 'c2', 'c3'):
            for c in n[slot]:
                self._members(c, out, writing)

    def _count_arith(self, n):
        c = 1 if n['k'] in ('BINARY_EXPR', 'UNARY_EXPR') else 0
        for slot in ('c1', 'c2', 'c3'):
            for ch in n[slot]:
                c += self._count_arith(ch)
        return c

    def _loop_counters(self, body):
        """Names incremented by a literal inside the loop -- i.e. the induction
        variables. An index that is one of these is a sequential walk; anything
        else (a `next_sibling` link, another array's contents) is random."""
        found = set()

        def walk(n):
            if n['k'] == 'ASSIGNMENT_STATEMENT' and n['c1'] and n['c2']:
                tgt, val = n['c1'][0], n['c2'][0]
                if tgt['k'] == 'IDENTIFIER_EXPR' and val['k'] == 'BINARY_EXPR':
                    kids = val['c1'] + val['c2']
                    names = [x['s1'] for x in kids if x['k'] == 'IDENTIFIER_EXPR']
                    lits = [x for x in kids if x['k'] == 'LITERAL_EXPR']
                    if tgt['s1'] in names and lits:
                        found.add(tgt['s1'])
            for slot in ('c1', 'c2', 'c3'):
                for c in n[slot]:
                    walk(c)
        walk(body)
        return found

    # -- the scan -----------------------------------------------------------

    def _scan(self, n, fn, depth):
        if n['k'] in LOOPS:
            self._loop(n, fn, depth + 1)
            return
        if n['k'] == 'STRUCT_LITERAL_EXPR':
            self.allocs[n['s1'] or n['ty']] += 1
        for slot in ('c1', 'c2', 'c3'):
            for c in n[slot]:
                self._scan(c, fn, depth)

    def _loop(self, node, fn, depth):
        counters = self._loop_counters(node)

        # Element bindings: `let p = list_get(container, idx)`
        elems = []

        def find_gets(n):
            if n['k'] == 'VARIABLE_DECL' and n['c2']:
                init = n['c2'][0]
                if init['k'] == 'CALL_EXPR':
                    callee = init['c1'][0]['s1'] if init['c1'] else ''
                    if callee == 'list_get' and len(init['c2']) >= 2:
                        idx = init['c2'][1]
                        seq = (idx['k'] == 'IDENTIFIER_EXPR'
                               and idx['s1'] in counters)
                        elems.append((n['ty'].split('<')[0],
                                      'sequential' if seq else 'random'))
            if n['k'] in LOOPS and n is not node:
                return                       # inner loops handled separately
            for slot in ('c1', 'c2', 'c3'):
                for c in n[slot]:
                    find_gets(c)
        find_gets(node)

        members = []
        self._members(node, members)
        arith = self._count_arith(node)

        for owner, field, is_write in members:
            if is_write:
                self.writes[(owner, field)] += 10 ** max(1, depth)
            else:
                self.reads[(owner, field)] += 10 ** max(1, depth)

        seen = set()
        for elem, order in elems:
            if elem not in self.m.structs or elem in seen:
                continue
            seen.add(elem)
            t = Traversal(fn, node['ln'], elem, order, depth)
            for owner, field, is_write in members:
                if owner == elem:
                    t.touched.add(field)
                    if is_write:
                        t.writes.add(field)
            t.arith = arith
            if t.touched:
                self.traversals.append(t)

        # Nested structs reached through a touched field get their own
        # traversal: `n.world.px` streams Transform alongside Node.
        for owner, field, _ in members:
            fty = dict(self.m.structs.get(owner, [])).get(field, '')
            base = fty.split('<')[0]
            if base in self.m.structs and base not in seen:
                seen.add(base)
                t = Traversal(fn, node['ln'], base, 'random', depth)
                for o2, f2, w2 in members:
                    if o2 == base:
                        t.touched.add(f2)
                        if w2:
                            t.writes.add(f2)
                t.arith = arith
                if t.touched:
                    self.traversals.append(t)

        for slot in ('c1', 'c2', 'c3'):
            for c in node[slot]:
                self._scan(c, fn, depth)


# ---------------------------------------------------------------------------
# Candidate space (LAYOUT 6)
# ---------------------------------------------------------------------------

class Layout:
    """grouping in {AoS, SoA, AoSoA(w)}; `hot` is the field subset kept in the
    primary allocation, the rest split cold. Field order is DERIVED, never
    searched -- descending alignment, which is optimal for padding."""

    def __init__(self, grouping, width, hot):
        self.grouping = grouping
        self.width = width
        self.hot = frozenset(hot)

    def key(self):
        return (('AoS', 'SoA', 'AoSoA').index(self.grouping), self.width,
                tuple(sorted(self.hot)))

    def name(self, all_fields):
        g = self.grouping if self.grouping != 'AoSoA' else f'AoSoA[{self.width}]'
        if len(self.hot) < len(all_fields):
            return f'{g}+split({len(self.hot)}/{len(all_fields)})'
        return g


def candidates(model, ty, profile):
    fields = model.structs[ty]
    names = [f for f, _ in fields]
    freq = {f: profile.reads[(ty, f)] + profile.writes[(ty, f)] for f in names}
    ranked = sorted(names, key=lambda f: (-freq[f], f))

    splits = [frozenset(names)]
    for cut in range(1, len(ranked)):
        if freq[ranked[cut - 1]] != freq[ranked[cut]]:
            splits.append(frozenset(ranked[:cut]))

    # AoSoA cut in 1.2: never chosen once across six programs (RESULTS-L1).
    out = []
    for grouping, width in (('AoS', 0), ('SoA', 0)):
        for hot in splits:
            out.append(Layout(grouping, width, hot))
    return out


def record_size(model, ty, subset):
    """Size with padding, fields ordered by descending alignment."""
    fields = [(f, t) for f, t in model.structs[ty] if f in subset]
    fields.sort(key=lambda ft: -field_align(model, ft[1]))
    off = 0
    for _, t in fields:
        a = field_align(model, t)
        off = (off + a - 1) // a * a
        off += field_width(model, t)
    return max(1, (off + 7) // 8 * 8)


def min_size(model, ty):
    return sum(field_width(model, t) for _, t in model.structs[ty])


# ---------------------------------------------------------------------------
# Cost model (LAYOUT 5). Integer cycles -- LAYOUT 9 obligation 2 requires
# fixed-point, because parallel float reduction can flip a tie.
# ---------------------------------------------------------------------------

def mu_for(footprint):
    if footprint <= C1:
        return MU1
    if footprint <= C2:
        return MU2
    if footprint <= C3:
        return MU3
    return MUM


N_ASSUMED = 1 << 20        # collection length unknown statically -> large


def traversal_cost(model, ty, L, t):
    ftypes = dict(model.structs[ty])
    touched = [f for f in t.touched if f in ftypes]
    if not touched:
        return 0, 0

    hot_touched = [f for f in touched if f in L.hot]
    cold_touched = [f for f in touched if f not in L.hot]

    if t.order == 'random':
        groups = (1 if hot_touched else 0) + (1 if cold_touched else 0)
        if L.grouping == 'SoA':
            groups = len(touched)
        bytes_per = groups * LINE
        resident = record_size(model, ty, L.hot)
    elif L.grouping == 'AoS':
        # DIVERGENCE from the compiler (runtime/aif_support.c, layout_cost), and
        # deliberate on both sides. This models an INDEXED split: the cold half of
        # element i is at a computed offset in a parallel block, so touching it is
        # more sequential scanning and adding its bytes is right.
        #
        # The compiler's split is LINKED -- the hot record holds a pointer to a
        # separately malloc'd cold block, which is the only form expressible
        # without handles. There a cold touch is a dependent miss priced at
        # pi(random), and the hot record additionally carries the 8-byte link.
        #
        # The difference is not academic: on g1 this pricing scores 1188M for the
        # 1/12 cut against 1180M for 8/12 -- 0.7% apart, and it prefers 8/12 by
        # that margin. Add the link word the compiler pays and the order inverts,
        # so the compiler would select a cut that pushes five of `integrate`'s six
        # fields cold. See LAYOUT 5.2.1 and RESULTS-layout 5.2.
        #
        # Kept as-is here because this prototype models LAYOUT 6's candidate space
        # in general, including groupings the compiler cannot emit; the compiler
        # models the one it can.
        bytes_per = record_size(model, ty, L.hot)
        if cold_touched:
            bytes_per += record_size(model, ty, set(ftypes) - L.hot)
        resident = bytes_per
    elif L.grouping == 'SoA':
        bytes_per = sum(field_width(model, ftypes[f]) for f in touched)
        resident = bytes_per
    else:                                       # AoSoA(w)
        w = L.width
        total = 0
        for f in touched:
            blk = w * field_width(model, ftypes[f])
            total += (blk + LINE - 1) // LINE * LINE
        bytes_per = max(1, total // w)
        resident = bytes_per

    footprint = N_ASSUMED * max(1, resident)
    misses = max(1, bytes_per) / LINE
    pi_num = int(PI[t.order] * 100)
    cost = int(t.iters * N_ASSUMED * misses * mu_for(footprint) * pi_num / 100)

    # Arithmetic is a POSITIVE term, and SIMD reduces it. LAYOUT 5.4 subtracts
    # SimdCredit from a sum of memory costs, which is incoherent -- an
    # arithmetic saving has nothing to net against there, so the total can go
    # negative. Recorded as a defect; see RESULTS-L1.
    arith_cost = t.iters * N_ASSUMED * t.arith
    credit = 0
    if L.grouping in ('SoA', 'AoSoA') and t.order == 'sequential' and t.arith:
        lanes = min(V_SIMD // max(1, field_width(model, ftypes[f]))
                    for f in touched)
        if lanes > 1:
            credit = arith_cost * (lanes - 1) // lanes
    return cost + arith_cost, credit


def total_cost(model, ty, L, profile, tier='T2'):
    traversals = [t for t in profile.traversals if t.elem == ty]
    cost = credit = 0
    for t in traversals:
        c, cr = traversal_cost(model, ty, L, t)
        cost += c
        credit += cr

    size = record_size(model, ty, L.hot)
    if len(L.hot) < len(model.structs[ty]):
        size += record_size(model, ty, set(f for f, _ in model.structs[ty]) - L.hot)
    alloc = profile.allocs.get(ty, 0) * N_ASSUMED // 1000 * ALPHA[tier]
    footprint = N_ASSUMED * (size - min_size(model, ty)) * LAMBDA_NUM // LAMBDA_DEN

    # Credit can never exceed the arithmetic it is discounting, so the total is
    # bounded below by the memory terms and cannot go negative.
    return max(0, cost + alloc + footprint - credit), {
        'traversal': cost, 'simd': -credit,
        'alloc': alloc, 'footprint': footprint, 'size': size,
    }


# ---------------------------------------------------------------------------
# Search (LAYOUT 7) -- coordinate descent, deterministic ties
# ---------------------------------------------------------------------------

def search(model, profile, budget=20000):
    chosen = {}
    for ty in sorted(model.structs):
        chosen[ty] = Layout('AoS', 0, frozenset(f for f, _ in model.structs[ty]))

    evaluated = 0
    for _ in range(4):
        changed = False
        for ty in sorted(model.structs):
            if not model.structs[ty]:
                continue
            best, best_cost = None, None
            for L in candidates(model, ty, profile):
                c, _ = total_cost(model, ty, L, profile)
                evaluated += 1
                if best_cost is None or (c, L.key()) < (best_cost, best.key()):
                    best, best_cost = L, c
            if best.key() != chosen[ty].key():
                chosen[ty] = best
                changed = True
        if not changed:
            break
    return chosen, evaluated


# ---------------------------------------------------------------------------
# Report
# ---------------------------------------------------------------------------

def main():
    ap = argparse.ArgumentParser(description="AIF layout optimiser prototype")
    ap.add_argument('dump')
    ap.add_argument('--verbose', action='store_true')
    args = ap.parse_args()

    sys.setrecursionlimit(200000)
    with open(args.dump, encoding='utf-8') as f:
        dump = json.load(f)
    model = Model(dump)
    profile = Profile(model, dump)

    print(f"# {dump['source']}")
    print(f"# static access profile: {len(profile.traversals)} traversals over "
          f"{len(model.structs)} struct types\n")

    if args.verbose:
        print("traversals")
        for t in sorted(profile.traversals, key=lambda t: (t.elem, t.line)):
            tw = ','.join(sorted(t.touched))
            print(f"  {t.elem:12} {t.order:10} depth={t.depth} "
                  f"arith={t.arith:3} touched={len(t.touched)}/"
                  f"{len(model.structs[t.elem])}  [{tw}]  @{t.fn}:{t.line}")
        print()

    chosen, evaluated = search(model, profile)

    print(f"# layout selection  ({evaluated} candidates evaluated)")
    print(f"  {'type':14} {'fields':>6} {'chosen':22} {'vs AoS':>9}  traversals")
    total_base = total_chosen = 0
    for ty in sorted(model.structs):
        fields = model.structs[ty]
        if not fields:
            continue
        ts = [t for t in profile.traversals if t.elem == ty]
        allf = frozenset(f for f, _ in fields)
        base = Layout('AoS', 0, allf)
        bc, _ = total_cost(model, ty, base, profile)
        cc, br = total_cost(model, ty, chosen[ty], profile)
        total_base += bc
        total_chosen += cc
        speed = f"{bc/max(1,cc):.2f}x" if ts else "-"
        print(f"  {ty:14} {len(fields):6} {chosen[ty].name(allf):22} "
              f"{speed:>9}  {len(ts)}")

    if total_chosen:
        print(f"\n  modelled memory-cost ratio vs all-AoS baseline: "
              f"{total_base/total_chosen:.2f}x")

    print("\n# per-type detail")
    for ty in sorted(model.structs):
        ts = [t for t in profile.traversals if t.elem == ty]
        if not ts:
            continue
        fields = model.structs[ty]
        allf = frozenset(f for f, _ in fields)
        L = chosen[ty]
        _, br = total_cost(model, ty, L, profile)
        _, bb = total_cost(model, ty, Layout('AoS', 0, allf), profile)
        print(f"\n  {ty}  ({len(fields)} fields, {min_size(model,ty)}B packed)")
        print(f"    chosen      {L.name(allf)}   record {br['size']}B")
        widest = max(ts, key=lambda t: -len(t.touched))
        print(f"    narrowest   {len(widest.touched)}/{len(fields)} fields "
              f"touched ({widest.order}) @{widest.fn}:{widest.line}")
        print(f"    traversal   {bb['traversal']:>18,} -> {br['traversal']:>18,}")
        if br['simd']:
            print(f"    simd credit {'':>18}    {br['simd']:>18,}")


if __name__ == '__main__':
    main()
