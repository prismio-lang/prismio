# Prismio Language Specification: Regional Permissions (`FRP-Core` v1.0)

**Status:** Finalized Core Specification  
**Target:** Prismio Type System & PIR Borrow Verifier

---

## 1. Overview
**Regional Permissions** extend lexical borrow checking with **Stratified Presburger Index Sets** and **Hardware-Granularity Layout Projections ($\gamma$-Disjointness)**. The system enables zero-overhead, statically verified aliasing guarantees across struct fields, strided slices, and tiled multidimensional arrays without runtime bounds checks or `unsafe` pointer manipulation.

---

## 2. Stratified Region Syntax & Grammar

To guarantee 100% decidability (Linear Presburger Arithmetic without non-linear variable multiplication), multiplicative strides and additive bounds are strictly stratified:

```ebnf
RefType       ::= '&' Lifetime? Mutability? AlignAttr? Type ('@' RegionExpr)?
Mutability    ::= 'mut'
AlignAttr     ::= '@Align(' ConstInt ')'

RegionExpr    ::= AtomicRegion ('|' AtomicRegion)*
AtomicRegion  ::= FieldPath? IndexDomain?
FieldPath     ::= '.' Ident ('.' Ident)*
IndexDomain   ::= '[' DimConstraint (',' DimConstraint)* ']'

DimConstraint ::= AffineBound ('until' | '..') AffineBound
                | ConstInt '*' IndexVar ('+' ConstInt)? '|' IndexVar 'in' AffineBound 'until' AffineBound

AffineBound   ::= ConstInt
                | ConstInt? '*' SymVar
                | AffineBound ('+' | '-') AffineBound
```

* **`ConstInt` ($c, s, w, \gamma \in \mathbb{Z}_{\text{const}}$):** Compile-time integer literals or instantiated `const` generic parameters.
* **`SymVar` ($p, N, M \in \text{SymVar}$):** Immutable (`val`) runtime integer variables in lexical scope.

---

## 3. Formal Semantics

### 3.1 Logical Domain ($D$)
An atomic region $D$ over an allocation $\alpha$ of type $T$ with $d$ dimensions and leaf field subset $F \subseteq \text{Fields}(T)$ is a tuple $(F, \Phi(\vec{i}))$, where $\Phi(\vec{i})$ is a conjunction of linear inequalities over $\vec{i} \in \mathbb{Z}^d$:
$$\Phi(\vec{i}) \equiv \bigwedge_{k=1}^d \left( a_{\text{lo}, k}(\vec{p}) \le s_k \cdot i_k + c_k < a_{\text{hi}, k}(\vec{p}) \right)$$

### 3.2 Physical Granularity Projection ($\mathcal{B}_\gamma$)
Given coherence granularity $\gamma \in \{1, \text{WordSize}, 64\}$ (in bytes):
1. **Alignment Gate:** $\text{ValidGranularity}(\alpha, \gamma) \iff \gamma \mid \text{Align}(\alpha)$.
2. **Storage Projection:**
    * **AoS Layout:** Maps $(\alpha, \vec{i}, f)$ to physical block set:
      $$\mathcal{B}_\gamma(\alpha, D) = \left\{ \left(\alpha, \left\lfloor \frac{\text{Offset}(\vec{i}, f) + b}{\gamma} \right\rfloor\right) \;\middle|\; f \in F,\; \Phi(\vec{i}),\; 0 \le b < \text{sizeof}(f) \right\}$$
    * **SoA Layout:** Maps each leaf field $f \in F$ to a distinct logical sub-allocation $(\alpha, f)$ with element stride $\text{sizeof}(f)$, decoupling field offsets from dynamic array lengths $N$.

### 3.3 Lexical Capability Invariants
At every CFG program point, the borrow checker tracks two active capability sets per allocation $\alpha$: the **Write-Locked Set** $\mathcal{W}_\gamma(\alpha)$ and the **Read-Locked Set** $\mathcal{S}_\gamma(\alpha)$.

1. **Sequential Borrow Invariant ($\gamma = 1$):**
    * **Shared Borrow (`&T @ D`):** Requires $\mathcal{B}_1(\alpha, D) \cap \mathcal{W}_1(\alpha) = \emptyset$ and $\forall f \in F_D.\; \text{Freeze}(f)$ (no interior mutability). Adds $\mathcal{B}_1(\alpha, D)$ to $\mathcal{S}_1(\alpha)$ for lifetime $\ell$.
    * **Mutable Borrow (`&mut T @ D`):** Requires $\mathcal{B}_1(\alpha, D) \cap (\mathcal{W}_1(\alpha) \cup \mathcal{S}_1(\alpha)) = \emptyset$. Adds $\mathcal{B}_1(\alpha, D)$ to $\mathcal{W}_1(\alpha)$ for lifetime $\ell$.
2. **Parallel Fork Invariant ($\gamma = \text{WordSize}$ default, $\gamma = 64$ for `Coherence.CacheLine`):**
    * Across concurrent branches $e_1 \parallel_\gamma e_2$, for every mutable loan $D_m$ in $e_1$ and every active loan $D_a$ (mutable or shared) in $e_2$:
      $$\text{ValidGranularity}(\alpha, \gamma) \;\land\; \mathcal{B}_\gamma(\alpha, D_m) \cap \mathcal{B}_\gamma(\alpha, D_a) = \emptyset$$
3. **Initialization & Unwind Invariant:**
    * Standard `&mut T @ D` references may **not** move out elements without immediate replacement. All elements in $D$ must remain valid, initialized instances of $T$ across any potential panic/unwind point.

---

## 4. Canonical Code Patterns

```kotlin
struct Particle { var pos: Vec3; var vel: Vec3; var mass: Float32 }

region Spatial    = .pos
region Kinematics = .vel | .mass

// 1. Field & Stride Projection (AoS and SoA compatible)
fun stepPhysics[N: Int](
    pos: &mut Slice<Particle>[N] @ Spatial,
    kin: &Slice<Particle>[N]     @ Kinematics,
    dt:  Float32
) {
    for (i in 0 until N) {
        pos[i].pos += kin[i].vel * (dt / kin[i].mass)
    }
}

// 2. Overlapping Read Halos + Disjoint Write Tiles
fun stencil1D[N: Int](
    src:   &Slice<Float32>[N]     @ [start - 1 .. end],
    dst:   &mut Slice<Float32>[N] @ [start until end],
    start: Int,
    end:   Int
) where 1 <= start, start < end, end < N - 1 {
    for (i in start until end) {
        dst[i] = 0.25f * src[i - 1] + 0.5f * src[i] + 0.25f * src[i + 1]
    }
}

// 3. Hardware Cache-Line Disjoint Parallelism (γ = 64)
const val LINE_STRIDE = 8 // 8 * sizeof(UInt64) = 64 bytes

fun clearBuckets[Threads: Int](
    buckets: &mut @Align(64) Slice<UInt64>[Threads * LINE_STRIDE]
) {
    parallelFor(t in 0 until Threads, granularity = Coherence.CacheLine)
        borrow buckets @ [t * LINE_STRIDE until (t + 1) * LINE_STRIDE] as local
    {
        local[t * LINE_STRIDE] = 0uL
    }
}

// 4. Dynamic Fallback for Non-Affine / Runtime Indices
fun updateEdge[V: Int](nodes: &mut Slice<Float32>[V], u: Int, v: Int)
    where u in 0 until V, v in 0 until V
{
    match (nodes.tryBorrowDisjoint([u..u], [v..v])) {
        Disjoint(nu, nv) -> { nv[v] += nu[u] }
        Overlapping      -> { /* u == v fallback */ }
    }
}
```

---

## 5. Compiler Verification & Lowering Contract

1. **Decidability & Solver Bound:** Disjointness queries $\mathcal{B}_\gamma(\alpha, D_1) \cap \mathcal{B}_\gamma(\alpha, D_2) = \emptyset$ are decided via **Fourier-Motzkin Elimination + GCD Stride Tests** over integer lattices (maximum dimension $d \le 4$). Non-affine index expressions are rejected statically and must use `tryBorrowDisjoint`.
2. **Zero Runtime Representation:** Region descriptors `@ D` are **completely erased** after PIR borrow checking. A regional reference `&mut T @ D` lowers to the exact same machine pointer/slice representation as `&mut T`.
3. **LLVM IR Lowering Rules:**
    * **Never** emit parameter-level `noalias` on two parameters derived from the same base allocation $\alpha$.
    * **Always** emit instruction-level `!alias.scope` and `!noalias` metadata on individual `load` and `store` instructions derived from proven-disjoint regions $D_1 \perp_1 D_2$.
    * Preserve common base pointer SSA values for strided regions (`[2*k]` vs `[2*k+1]`) within loop bodies so LLVM’s `InterleavedAccessInfo` pass can synthesize vector shuffle instructions.