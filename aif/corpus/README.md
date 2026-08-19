# AIF Corpus

Seven programs, all compiling and running under the current compiler. They exist because the
compiler's own source is a poor proxy for the target workload — it is string-heavy and struct-light,
and it reports a misleading tier number
([../evidence/RESULTS-L0-tiers.md](../evidence/RESULTS-L0-tiers.md) §3).

| | Program | Shape | Written to test |
|---|---|---|---|
| G1 | `g1_particles.psm` | 12-field component; loops touch 6 / 2 / 1 fields | AoS vs SoA — the layout discriminator |
| G2 | `g2_frame_loop.psm` | Per-frame transient draw batches | T1 regions; nothing outlives the frame |
| G3 | `g3_scene_graph.psm` | Index-based transform hierarchy | Escape through a retained tree |
| G4 | `g4_ecs_world.psm` | 5 component arrays, 4 systems | Realistic ECS; no single layout serves all systems |
| G5 | `g5_asset_cache.psm` | 2000 entities over 20 meshes / 12 materials | **Real sharing** — written to force T3 |
| G6 | `g6_engine.psm` + `g6_game.psm` | Two modules, gameplay calling engine | Whether tiers survive a module boundary |

## Three things the corpus established

**G5 produced zero T3** despite roughly 100 references per asset, because entities reference assets
by **handle** — an index into a uniquely-owned pool. Handles carry no ownership, so no aliasing fact
is ever raised. That is how engines are written anyway, and it suggests the T3 population may be far
smaller than the model assumes. The limits of that claim are in RESULTS-L0 §3a.

**G3's first draft could not be written.** A `parent: Node` back-reference is rejected twice by the
current compiler — there is no null to initialise it, and `child.parent = parent` is *cannot move
out of borrowed value*. **The affine discipline makes reference cycles inexpressible**, so
[../spec/CYCLES.md](../spec/CYCLES.md) has no program that can exercise it. G3 was rewritten to the
index-based hierarchy production engines actually use.

**G6 measured what a module boundary costs.** Transparent: 100% T0–T2. Sealed: 75%, with the loss
confined to values that actually cross.

## Building

```bash
prismio build g4_ecs_world.psm -o g4.exe
```

`g6_game.psm` imports `g6_engine.psm`, so building the game module pulls the engine in.

## Gaps to fill

- **No closures anywhere**, because the language has none — which is why the T3 path is untested
  rather than absent (INFERENCE §4.5, [../evidence/EVALUATION.md](../evidence/EVALUATION.md) §5).
- **No `region` annotation**, so every allocation lands T2 where it should land T1.
- **No concurrency**, so the thread-affinity domain is `Isolated` throughout. The domain
  itself is no longer vacuous (REQUIREMENTS 15) — the corpus simply does not spawn, which
  is why `tests/aif_concurrency.psm` and `tests/aif_concurrency_shared.psm` carry that
  coverage instead and are in the differential's source list for exactly that reason.
