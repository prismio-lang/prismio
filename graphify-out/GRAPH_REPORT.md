# Graph Report - prismio  (2026-10-15)

## Corpus Check
- 862 files · ~1,180,015 words
- Verdict: corpus is large enough that graph structure adds value.
- Unclassified: 13 file(s) not represented in the graph (top: (none) 4, .ld 4, .ums 3)

## Summary
- 12612 nodes · 35475 edges · 657 communities (481 shown, 176 thin omitted)
- Extraction: 85% EXTRACTED · 15% INFERRED · 0% AMBIGUOUS · INFERRED: 5464 edges (avg confidence: 0.86)
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `b25e5d85`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- impl Parser
- bridge.psm
- std/io.psm
- freestanding/rust/algorithms.rs
- aif_support.c
- aifEmitManifest
- ir/expr.psm
- gate_ui.py
- llvm-api-backend.c
- model.psm
- Engine
- adversarial.psm
- Display
- setup.py
- strlen
- context.psm
- common/target.psm
- aifCallSites
- test_45_aif_affine_collections.psm
- lang_runtime.c
- std/vec.psm
- resolve_value
- ums_cli.psm
- test_262_array_return_large.psm
- unicode.psm
- build_driver.c
- analyzedModule
- cleanup_files
- process.psm
- generateAssignment
- generate_unicode_tables.py
- mapSet
- ASTNode
- neg_162_sized_array_refused.psm
- generateReleaseFn
- fs.psm
- NodeKind
- str_with_capacity
- eq.psm
- map.psm
- suite.py
- aif_intern
- aifWalk
- impl RelLoop
- TypeInfo
- Token
- aif_tier_of
- string.psm
- release.py
- elide_middle
- src/main.psm
- key.psm
- fprintf
- test_176_match_diverges.psm
- test_102_generic_trait_arguments.psm
- main
- ir_symbols.c
- alpha.psm
- impl Float
- bits_set
- Ord
- Default
- nowrap.psm
- Architecture direction — what to build next, and what the literature already settled
- data_structures.rs
- option.psm
- setup_llvm.py
- algorithms.cpp
- unicode_conformance.psm
- node_to_ptr
- impl String
- sys
- backend_fail
- ast/types.psm
- BoundedQueue
- LLVMModuleRef
- ptr_to_node
- report.psm
- run_command
- layout.py
- targets/target.psm
- input.psm
- UmsTokenKind
- ir/stmt.psm
- __builtin_string_len
- TypeKind
- panic.c
- AIF — The Inference Engine
- main
- ir_intern
- 2 · What 0.1 ships
- AIF — Design Rationale
- copy.psm
- test_101_generic_trait_impl.psm
- test_103_default_trait_methods.psm
- hosted/rust/algorithms.rs
- assign.psm
- run.py
- Code Style
- 1 · AIF core — genuinely ours
- AIF — Workload Declaration, Cost Model, and Layout Search
- package.py
- time.psm
- contents.psm
- strcmp
- hosted/prismio/algorithms.psm
- AIF — The T4 Cycle Collector
- README.md
- prismio_llvm.h
- adversarial.rs
- AIF — Adaptive Inference Framework
- release_gate.py
- aif/README.md
- block_done
- TokenType
- test_169_loop_range_proofs.psm
- Added
- generics.psm
- main
- test_238_scalar_optionals.psm
- test_289_async_await.psm
- aifEmitBrackets
- test_107_associated_types.psm
- test_116_trait_objects.psm
- enum_visibility/enums.psm
- .equals
- test_98_multiple_trait_bounds.psm
- AIF — The Target Workload
- host.psm
- build_tree
- test_127_enum_null_variant.psm
- debug_info.psm
- residues.psm
- io.rs
- symbols.psm
- 8.4 Views — slices and element references
- benchRun
- test_181_std_math.psm
- test_104_where_clauses.psm
- test_118_impl_trait.psm
- test_79_slices.psm
- test_232_channel_copies.psm
- Buffer
- hosted/rust/compute.rs
- test_105_supertraits.psm
- test_164_array_fields.psm
- test_71_nonlexical_extent.psm
- LiveProgress
- compile.psm
- impl Parser
- run
- test_286_stride_tiling.psm
- impl Parser
- struct_entry
- test_56_list_capacity.psm
- aif.py
- impl ArrayContents
- run_debug_info_test
- hardware.rs
- .solve
- platform.psm
- aif_concurrency.psm
- named_struct
- assert
- test_115_trait_imports.psm
- test_92_field_view_provenance.psm
- test_map_update.psm
- Decisions
- shapes.psm
- test_165_ranges_repeat_labels.psm
- retain
- inlineElemSizeOfList
- Tier 2 — required by specified AIF features
- test_276_float_text.psm
- float_text.psm
- test_271_array_contents.psm
- bits_test
- Interop with C, C++ and Rust, in both directions
- cyc_hdr
- test_map_probe.psm
- test_60_bracket_reset.psm
- test_100_generic_inherent_impl.psm
- test_240_overload_exactness.psm
- test_70_struct_field_release.psm
- UmsDiagnostic
- freestanding/prismio/algorithms.psm
- Model
- test_267_none_coalescing.psm
- test_75_std_string.psm
- neg_295_ptr_writes_refused.psm
- benchmarks.hpp
- test_222_type_constructors.psm
- test_128_enum_null_reserved.psm
- test_69_task_results.psm
- test_111_blanket_impls.psm
- manifest_records
- bracket_place
- add_binding
- algorithms.c
- run_hosted
- test_55_workload_profile.psm
- test_270_array_nowrap.psm
- .toString
- aif_tiers.psm
- test_108_trait_method_namespaces.psm
- test_109_trait_ownership.psm
- test_58_region_serves.psm
- Profile
- LLVMValueRef
- io.cpp
- hosted/rust/memory.rs
- test_96_channels.psm
- generateReturn
- impl Buffer
- run_freestanding
- neg_165_array_field_refused.psm
- test_132_counted_fill.psm
- test_157_shared_container_elements.psm
- test_170_match_switch.psm
- globals.psm
- test_49_aif_struct_fields.psm
- test_87_traits.psm
- check_source_lists.py
- test_269_struct_pass_through_escapes.psm
- Ownership: leaks
- test_30_diamond_imports.psm
- test_154_extern_globals.psm
- test_290_scope_spawn.psm
- test_177_type_functions.psm
- 5 · Annotations
- Progress
- ir_snapshot.py
- neg_107_impl_trait_return_mismatch.psm
- test_130_list_alias_scopes.psm
- impl I64
- workspace.psm
- manifest_writer.psm
- test_15_compiler_sim.psm
- test_82_generic_layout.psm
- PIR — Prism Semantic IR
- test_53_aif_views.psm
- test_121_guard_effect_analysis.psm
- test_184_call_result_ownership.psm
- test_192_callable_bounds.psm
- test_42_aif_stack_promotion.psm
- test_68_optional_returns.psm
- test_99_trait_coherence.psm
- test_257_global_arrays.psm
- test_46_aif_annotations.psm
- test_216_for_push_guard.psm
- test_155_vec_methods.psm
- test_43_aif_scope_drop.psm
- test_50_scalar_lists.psm
- test_119_loop_range_guard.psm
- test_29_overloads.psm
- vec_push
- Prismio performance benchmarks
- neg_65_generic_trait_impl_bound.psm
- neg_84_transitive_supertrait.psm
- test_148_struct_index.psm
- test_167_frame_struct_fields.psm
- test_140_string_search.psm
- test_66_payload_enums.psm
- test_86_impl_blocks.psm
- test_261_failure_builtin_after_owned.psm
- test_122_loop_local_index_term.psm
- test_158_sized_arrays.psm
- test_62_split_release.psm
- aif_str
- test_63_placement_pin.psm
- test_185_view_outlives_binding.psm
- test_47_aif_containers.psm
- test_44_aif_region.psm
- Debugging Prismio programs
- install.sh
- namelist_contains
- neg_66_overlapping_generic_trait_impl.psm
- neg_93_ambiguous_trait_method.psm
- neg_94_wrong_trait_qualifier.psm
- test_05_enums.psm
- test_106_associated_constants.psm
- test_129_enum_null_ownership.psm
- test_179_proved_index_nsw.psm
- test_231_cold_functions.psm
- aifEmitSummary
- main
- .spawn
- ptr_access_ir_probe.psm
- test_14_multi_args.psm
- 3 · Steps
- test_25_conventions.psm
- Known issues
- dump.psm
- test_287_multi_statement_fill.psm
- test_268_struct_pass_through.psm
- test_277_guard_dyn_call.psm
- xcalloc
- common.rs
- test_285_deferred_initialization.psm
- test_193_map_methods.psm
- umsLex
- harness.c
- test_57_pin_tiers.psm
- test_48_aif_shared_elements.psm
- test_84_task_release.psm
- format_ns
- test_113_std_eq_and_display.psm
- test_163_array_return.psm
- node_args_find
- test_73_recursive_release.psm
- impl Int
- test_288_remainder_steps.psm
- test_166_for_each_collections.psm
- 7 · Specialisation strategy and dedup
- impl I16
- Memory: what 0.1 needs, and where the architecture goes after
- neg_291_typed_ptr_refused.psm
- test_279_nested_functions.psm
- 4 · Prerequisites nobody has costed
- test_191_option_methods.psm
- kernel_i686.psm
- freestanding/prismio/compute.psm
- text.psm
- neg_57_second_bound_not_satisfied.psm
- neg_68_blanket_trait_impl.psm
- range_direction_probe.psm
- fclose
- test_144_sort_inline_elements.psm
- neg_304_visibility_marker_on_trait.psm
- test_51_optional_refs.psm
- test_171_default_values.psm
- test_143_string_compare.psm
- test_22_match.psm
- boot_aarch64_virt.c
- test_291_typed_ptr_types.psm
- prismio
- bootstrap.sh
- test_124_whole_buffer_copy.psm
- nowrapExpr
- run_array_nowrap_test
- [0.2.0] - Unreleased
- neg_77_missing_method_with_defaults.psm
- getenv
- main
- neg_298_ptr_atomics_refused.psm
- test_126_push_predication.psm
- test_186_view_pushed_directly.psm
- layout_c.psm
- .elem_key_reconcile
- kernel_aarch64.psm
- test_52_aif_cycle_collector.psm
- mem.psm
- test_283_numeric_fluency.psm
- kernel_trap_aarch64.psm
- test_47_aif_minimal_cause.psm
- math.psm
- neg_95_trait_sink_not_honoured.psm
- test_runner.py
- neg_258_global_array_computed.psm
- neg_270_repr_only_c.psm
- main
- suite.rs
- range_proof_entry_or_new
- repeated_copy_probe.psm
- neg_195_callable_bound.psm
- run_freestanding_test
- test_89_closures.psm
- BenchSphere
- test_64_generics.psm
- neg_101_dyn_self_not_object_safe.psm
- neg_104_dyn_returned.psm
- consts.psm
- neg_241_optional_impl_overlap.psm
- neg_45_bound_not_satisfied.psm
- neg_58_second_bound_not_trait.psm
- neg_82_missing_supertrait.psm
- neg_91_unknown_projection.psm
- neg_92_equality_constraint.psm
- test_01_variables.psm
- test_04_structs.psm
- test_100_reuse_token.psm
- test_100_string_append_reuse.psm
- raw.psm
- test_156_index_store.psm
- test_278_condition_syntax.psm
- adversarial.cpp
- test_275_line_start_paren.psm
- test_59_bracket_summary.psm
- test_85_passthrough_escape.psm
- aif_array_frame.psm
- use_it
- aif_array_frame_vec.psm
- neg_257_global_array_mutable.psm
- neg_259_global_array_write.psm
- test_123_loop_range_guard_wrap.psm
- array_return_huge.psm
- test_139_string_chain_append.psm
- neg_294_ptr_reads_refused.psm
- test_187_properties.psm
- loop_named
- test_94_selective_imports.psm
- test_280_closure_blocks.psm
- test_80_data_view_conversion.psm
- test_77_spawn_literal.psm
- neg_192_property_declaration.psm
- neg_251_array_length_unknown.psm
- Shape
- neg_44_impl_generic.psm
- neg_60_unrelated_method_not_conformance.psm
- neg_67_generic_trait_conformance.psm
- neg_69_generic_trait_method_parameter.psm
- neg_72_missing_bound_trait_argument.psm
- neg_73_trait_argument_bound_mismatch.psm
- impl From for String
- color_enabled
- neg_80_where_bound_not_satisfied.psm
- neg_89_missing_associated_type.psm
- neg_96_trait_inout_not_honoured.psm
- owned_return_depth2.psm
- owned_temporary_argument.psm
- recursive_enum_bindings_probe.psm
- test_294_ptr_overloads.psm
- neg_296_ptr_address_refused.psm
- test_125_stencil_range_guard.psm
- test_138_shadowing.psm
- test_13_globals.psm
- kernel_pure_aarch64.psm
- test_259_display_print.psm
- test_72_reassigned_ownership.psm
- test_162_removal_parks_under_view.psm
- test_19_runtime_split.psm
- verdict
- test_38_scoping.psm
- test_61_layout_cost_model.psm
- test_74_reinit_assignment.psm
- neg_227_function_final_expression.psm
- test_32_sized_int_modulo.psm
- test_53_memory_budget.psm
- kernel_float_aarch64.psm
- neg_20_pin_refuted.psm
- test_204_unicode_case.psm
- test_212_bidi_escapes.psm
- impl I8
- impl U32
- ir_loop_label
- Style
- neg_109_impl_trait_bound.psm
- neg_161_index_store_refused.psm
- Process
- Color
- Shape
- neg_46_impl_missing_method.psm
- neg_70_missing_trait_argument.psm
- neg_71_extra_trait_argument.psm
- neg_74_trait_argument_conformance.psm
- neg_76_unknown_trait_argument_type.psm
- neg_83_supertrait_cycle.psm
- neg_85_missing_associated_constant.psm
- neg_86_associated_constant_type.psm
- neg_87_associated_constant_not_global.psm
- neg_271_spawn_block_outside_scope.psm
- test_10_expressions.psm
- test_142_sort_patterns.psm
- test_16_arrays.psm
- test_174_slice_mut.psm
- test_217_vec_filled.psm
- test_21_loops.psm
- test_26_borrow_reuse.psm
- test_73_recursive_release_depth.psm
- test_88_single_loop_inline.psm
- run_remainder_steps_codegen_test
- neg_272_spawn_block_nested_without_scope.psm
- neg_273_await_outside_async.psm
- neg_275_future_is_not_its_result.psm
- neg_276_future_type_mismatch.psm
- neg_277_capture_is_moved_into_the_task.psm
- neg_278_future_with_too_many_arguments.psm
- test_39_typed_arrays.psm
- aif_concurrency_shared.psm
- extern_alias_escape.psm
- neg_102_dyn_associated_type.psm
- neg_103_dyn_in_struct_field.psm
- neg_108_impl_trait_position.psm
- neg_187_bare_type_function.psm
- Color
- Color
- Result
- neg_43_impl_self_position.psm
- scoreWith
- neg_62_unconstrained_generic_impl.psm
- neg_64_duplicate_impl_method_parameter.psm
- neg_79_where_unknown_parameter.psm
- neg_81_where_bound_not_trait.psm
- pointer_return_temp.psm
- recursive_optional_probe.psm
- test_02_if_else.psm
- test_03_while_loops.psm
- test_06_recursion.psm
- test_07_booleans.psm
- test_08_mutability.psm
- test_11_returns.psm
- test_149_list_literal.psm
- test_161_removal_releases_now.psm
- test_18_floats.psm
- test_206_nested_loop_breaks.psm
- test_23_move.psm
- test_33_unary_operators.psm
- test_41_punned_slot_bytes.psm
- test_93_data_view_from_helper.psm
- test_95_literal_tbaa.psm
- bootstrap.ps1
- 4 · Transfer rules
- neg_292_typed_ptr_qualifier_twice.psm
- test_235_channel_owned_messages.psm
- aif_loop_bracket.psm
- fixture_slice_escape.psm
- neg_05_drop_borrow.psm
- neg_105_dyn_unknown_trait.psm
- neg_153_extern_global_declaration.psm
- neg_155_extern_global_type.psm
- neg_160_empty_literal_untyped.psm
- neg_183_slice_returned_read_only.psm
- neg_176_param_not_inout.psm
- neg_198_array_type_argument.psm
- neg_22_push_borrowed_element.psm
- test_263_vec_literal_capacity.psm
- neg_24_unique_aliased_args.psm
- test_293_is_operand.psm
- neg_26_placement_pin_refuted.psm
- neg_47_unknown_trait.psm
- neg_48_bound_not_a_trait.psm
- neg_61_duplicate_trait_impl.psm
- neg_63_impl_for_type_parameter.psm
- neg_88_trait_constant_with_value.psm
- neg_90_trait_associated_type_value.psm
- neg_97_nonterminating_instantiation.psm
- target_cross.psm
- test_296_ptr_address.psm
- test_134_print_arguments.psm
- test_145_list_set_within_list.psm
- test_159_vec_binding_empty.psm
- test_160_i32_alias.psm
- test_180_descending_ranges.psm
- run_module_artifact_test
- test_24_drop.psm
- test_28_list.psm
- test_31_strings_in_control_flow.psm
- test_40_annotated_arrays.psm
- Particle
- 5. Ownership, handles, and globals
- 3 · The tier ladder
- refresh_seed.sh
- 5.4 `pin`
- 7 · Two-speed compilation
- neg_297_ptr_cast_refused.psm
- aif_vec_display.psm
- neg_01_type_mismatch.psm
- neg_03_use_after_move.psm
- neg_04_use_after_drop.psm
- neg_08_missing_return.psm
- neg_100_for_over_non_iterator.psm
- neg_100_struct_index_without_at.psm
- neg_10_move_in_loop.psm
- neg_13_syntax_recovery.psm
- neg_14_wrong_arity.psm
- neg_16_return_local_array.psm
- neg_172_default_without_type.psm
- 11 · Conformance boundary
- neg_189_code_after_panic.psm
- neg_207_break_outer_leaves_loop.psm
- 2 · The objects of the model
- neg_21_container_takes_ownership.psm
- neg_224_type_without_new.psm
- neg_233_channel_runtime_names.psm
- neg_23_optional_needs_unwrap.psm
- neg_27_generic_arity.psm
- neg_36_soa_non_flat.psm
- neg_38_data_view_field.psm
- neg_39_soa_moves_source.psm
- neg_40_data_element_escape.psm
- neg_41_list_set_exclusive_observed.psm
- neg_42_list_set_exclusive_inline.psm
- neg_50_closure_param_type.psm
- neg_56_channel_send_moves.psm
- neg_99_compare_without_ord.psm
- 4 · Tier derivation
- scalar_optional_expect_probe.psm
- test_117_block_comments.psm
- test_20_integers.psm
- test_120_min_max_abs.psm
- test_213_digit_separators.psm
- test_27_for.psm
- test_36_casts.psm
- test_37_bitwise_and_compound.psm
- 10 · Boundaries
- test_81_data_view_drop.psm
- test_83_list_set_exclusive.psm
- test_272_temporary_hoists.psm
- test_298_ptr_atomics.psm
- run_struct_path_tbaa_test
- neg_158_vec_last_needs_name.psm

## God Nodes (most connected - your core abstractions)
1. `ASTNode` - 855 edges
2. `ptr_to_node()` - 746 edges
3. `nodeExists()` - 529 edges
4. `nodeIsNull()` - 261 edges
5. `TypeInfo` - 210 edges
6. `node_to_ptr()` - 209 edges
7. `generateCall()` - 148 edges
8. `free()` - 141 edges
9. `ptr_null()` - 137 edges
10. `strlen()` - 133 edges

## Surprising Connections (you probably didn't know these)
- `Element references are views too — the deep consequence` --references--> `Particle`  [INFERRED]
  docs/aif/spec/SPEC.md → benchmarks/hosted/cpp/compute.cpp
- `Delivery order` --references--> `mixed_map_removal()`  [INFERRED]
  docs/FEATURE_BACKLOG.md → benchmarks/hosted/cpp/data_structures.cpp
- `A container that may be handed a string literal releases none of its elements` --references--> `container_may_hold_untracked()`  [INFERRED]
  docs/KNOWN_ISSUES.md → runtime/aif_support.c
- `Later, and not part of this plan` --references--> `link_with_cached_ld()`  [INFERRED]
  docs/LLVM_BRIDGE_PLAN.md → runtime/build_driver.c
- `1 · The one place being wrong is unsafe` --references--> `strlen()`  [INFERRED]
  docs/aif/spec/FFI.md → runtime/freestanding/libc.c

## Import Cycles
- None detected.

## Communities (657 total, 176 thin omitted)

### Community 1 - "bridge.psm"
Cohesion: 0.01
Nodes (213): diag_source_line(), ir_add_checked(), ir_arena_hint_begin(), ir_arena_hint_end(), ir_array_alloca(), ir_array_from_value(), ir_array_literal_begin(), ir_array_literal_elem() (+205 more)

### Community 2 - "std/io.psm"
Cohesion: 0.02
Nodes (123): str_with_capacity(), eprint(), eprint(), eprint(), eprint(), eprint(), eprint(), eprint() (+115 more)

### Community 3 - "freestanding/rust/algorithms.rs"
Cohesion: 0.06
Nodes (32): bench_binary_search(), bench_edit_distance(), bench_fibonacci(), bench_gcd_lcm(), bench_heapsort(), bench_knapsack(), bench_quicksort(), CAPACITY (+24 more)

### Community 4 - "aif_support.c"
Cohesion: 0.02
Nodes (70): The four annotations — **`unique` and `pin` DONE, 2026-08-07**, aif_call_edge(), aif_call_opaque(), aif_check_pins(), aif_con_arg(), aif_con_bind(), aif_con_borrow(), aif_con_escape_caller() (+62 more)

### Community 5 - "aifEmitManifest"
Cohesion: 0.09
Nodes (27): aif_arena_high_water(), aif_arena_unsized_sites(), aif_fn_name(), aif_layout_reordered(), aif_order_symbol(), aif_pt_rounds(), aif_scc_type_count(), aif_site_alias_axiom() (+19 more)

### Community 6 - "ir/expr.psm"
Cohesion: 0.07
Nodes (108): Scalars, nodeGetType(), typeIntBits(), typeIntIsUnsigned(), typeIrKey(), diag_file_path(), ir_alloc_stack(), ir_bitcast() (+100 more)

### Community 7 - "gate_ui.py"
Cohesion: 0.09
Nodes (25): D3. Mapping types, captured_stage(), header(), macos_cross_flags(), main(), pinned_llvm_bin(), run_captured(), shown() (+17 more)

### Community 8 - "llvm-api-backend.c"
Cohesion: 0.03
Nodes (62): assign_partitions(), atomic_order(), check_llvm_version(), codegen_partition_count(), codegen_thread_budget(), debug_dispose(), dump_bad_module(), ensure_context() (+54 more)

### Community 9 - "model.psm"
Cohesion: 0.03
Nodes (95): aif_check_pins(), aif_check_placement_pins(), aif_enum_new(), aif_extern_contract_set(), aif_field_has_range(), aif_field_range_bytes(), aif_field_range_hi(), aif_field_range_lo() (+87 more)

### Community 11 - "adversarial.psm"
Cohesion: 0.13
Nodes (25): benchAdversarialNext(), benchAllocationEscape(), benchAosVsSoa(), benchBranchMispredict(), benchConsumeAdversarialObject(), benchDeadCodeElimination(), benchDeadKernel(), benchDependencyChain() (+17 more)

### Community 12 - "Display"
Cohesion: 0.04
Nodes (71): eprint(), eprintln(), print(), println(), impl Display for Bool, impl Display for Char, impl Display for Float, impl Display for I16 (+63 more)

### Community 13 - "setup.py"
Cohesion: 0.10
Nodes (32): blocked(), Check, check_disk(), check_git(), check_llvm(), check_network(), check_platform(), check_python() (+24 more)

### Community 14 - "strlen"
Cohesion: 0.03
Nodes (114): A returned `String` must be freeable on every path, Allocations returned to Prismio go through `rt_base_alloc`, `extern fn` names are the ABI, The contract is part of the signature, The invariants, 2 · The model, and why it is this one, 4 · Later, Lowering (+106 more)

### Community 15 - "context.psm"
Cohesion: 0.03
Nodes (77): ir_alloc_cycle(), ir_alloc_object(), ir_alloc_rc(), ir_alloc_region(), aif_arena_at_node(), aif_arg_copies_view(), aif_call_arg_outlives_call(), aif_call_arg_retained() (+69 more)

### Community 16 - "common/target.psm"
Cohesion: 0.23
Nodes (15): ir_target_data_layout(), ir_target_is_explicit(), ir_target_pointer_bits(), ir_target_select(), ir_target_triple(), targetArchCode(), targetCurrent(), targetEnvCode() (+7 more)

### Community 17 - "aifCallSites"
Cohesion: 0.07
Nodes (42): 2.3 · Middle IR and interprocedural facts, aifCallIsSummarised(), aifDeclaredContract(), aifDeclaredReturnIsAlias(), aifDeclaredReturnIsProduce(), aifFfiAliasOf(), aifFfiAllocatesThroughArenaHint(), aifFfiArenaCannotServe() (+34 more)

### Community 18 - "test_45_aif_affine_collections.psm"
Cohesion: 0.22
Nodes (17): int_to_str(), borrows(), check(), early_exits(), early_return(), empty_substring_is_owned(), escapes(), explicit() (+9 more)

### Community 19 - "lang_runtime.c"
Cohesion: 0.02
Nodes (188): 5 · A staged path, Automatic arena placement — **DONE, 2026-08-07**, Beyond, Level 0 — facts, no behaviour change — **DONE, 2026-08-05**, Level 3 — T1 and `region` — **DONE, 2026-08-06**, Level 4 — strings and lists become move-only — **DONE, 2026-08-07**, Level 5 — T3 — **DONE, 2026-08-07**, Minimal cause and ranked repairs — **DONE, 2026-08-07** (+180 more)

### Community 20 - "std/vec.psm"
Cohesion: 0.03
Nodes (52): 5 · For 0.2: needs design first, Binary size: where it goes, clone(), concat(), contains(), countOf(), countOf(), countOf() (+44 more)

### Community 21 - "resolve_value"
Cohesion: 0.07
Nodes (69): array_base(), array_copy_bytes(), array_return_via_pointer(), array_slot(), global_named(), intern_value(), ir_array_alloca(), ir_array_alloca_zeroed() (+61 more)

### Community 22 - "ums_cli.psm"
Cohesion: 0.08
Nodes (59): diag_error_code(), compiler_spawn_arg(), compiler_program_on_path(), listUmsProjectCommands(), prismioBuiltinCommandList(), prismioBuiltinCommands(), pushStepArguments(), rejectReservedCommandNames() (+51 more)

### Community 23 - "test_262_array_return_large.psm"
Cohesion: 0.29
Nodes (12): below(), big(), bytes(), edges(), exactly(), fail(), forwarded(), main() (+4 more)

### Community 24 - "unicode.psm"
Cohesion: 0.06
Nodes (58): strSubstring(), scalarWidth(), strDisplayWidth(), strEqualsNormalized(), strGraphemeCount(), strGraphemes(), strGraphemeWidthAt(), strNormalizeNfc() (+50 more)

### Community 25 - "build_driver.c"
Cohesion: 0.05
Nodes (151): absolute_directory(), accept_if_exists(), add_freestanding_core_file(), add_freestanding_panic_core(), append_joined_argument(), build_curated_module(), build_trace_ms(), build_trace_stage() (+143 more)

### Community 26 - "analyzedModule"
Cohesion: 0.13
Nodes (20): diag_file_content(), diag_progress_clear(), diag_warning_at_code(), analyzedModule(), entryModule(), parseSource(), identifierIndex(), identifierWarnConfusable() (+12 more)

### Community 27 - "cleanup_files"
Cohesion: 0.05
Nodes (19): cleanup_files(), run_aif_drop_emission_test(), run_aif_layout_test(), run_aif_rc_test(), run_aif_struct_field_test(), run_aif_verify_test(), run_aif_view_test(), run_array_return_pointer_test() (+11 more)

### Community 28 - "process.psm"
Cohesion: 0.06
Nodes (30): StreamMode, Inherit, proc_close(), proc_env_all(), proc_env_get(), proc_env_has(), proc_env_remove(), proc_env_set() (+22 more)

### Community 29 - "generateAssignment"
Cohesion: 0.05
Nodes (91): 1.1 What crosses the boundary today, ir_array_alloca_zeroed(), ir_array_copy_into(), ir_array_copy_key(), ir_array_copy(), ir_array_zero_key(), ir_binding_owns_slot(), ir_copy_struct() (+83 more)

### Community 30 - "generate_unicode_tables.py"
Cohesion: 0.07
Nodes (35): array_rows(), case_column(), case_folding(), case_tables(), compositions(), confusables(), data_lines(), decompositions() (+27 more)

### Community 31 - "mapSet"
Cohesion: 0.14
Nodes (37): benchWordFrequency(), benchHashMap(), benchKeyValueUpdate(), benchMixedMapRemoval(), mapGetOr(), mapKeyAt(), mapLen(), mapNew() (+29 more)

### Community 32 - "ASTNode"
Cohesion: 0.03
Nodes (218): 2 · Order of work and status, M8 · The AST as raw `Ptr`: parked, aifArgTypeAt(), aifAlignUp(), aifAnnotationLeafName(), aifComputeSizes(), aifComputeSizesOf(), aifComputeStructSize() (+210 more)

### Community 34 - "generateReleaseFn"
Cohesion: 0.13
Nodes (31): ir_call_indirect_ptr(), ir_drop_count(), ir_drop_kind(), ir_drop_slot(), ir_drop_type(), ir_free_cold(), ir_free_data_view(), ir_free_list() (+23 more)

### Community 35 - "fs.psm"
Cohesion: 0.05
Nodes (73): Step 4 · Layout and symbols — built, 2 · What the audit found, Language, absolutePath(), isPrismioCheckout(), readSource(), standardModulePath(), initUmsProject() (+65 more)

### Community 36 - "NodeKind"
Cohesion: 0.04
Nodes (56): NodeKind, ARRAY_LITERAL_EXPR, ASSIGNMENT_STATEMENT, ASSOC_CONST, ASSOC_TYPE, ASSOC_TYPE_REF, BINARY_EXPR, BLOCK (+48 more)

### Community 37 - "str_with_capacity"
Cohesion: 0.13
Nodes (12): Resolved in 1.1 — was open in v1.0, str_with_capacity(), strRepeat(), termByte(), termFill(), termPutText(), termPutVisible(), termSequenceEnd() (+4 more)

### Community 38 - "eq.psm"
Cohesion: 0.10
Nodes (15): impl Eq for Bool, impl Eq for Char, impl Eq for Float, impl Eq for I16, impl Eq for I64, impl Eq for I8, impl Eq for Int, impl Eq for Isize (+7 more)

### Community 39 - "map.psm"
Cohesion: 0.10
Nodes (27): 1. `mixed_map_removal` — P0 — done 2026-09-25, API to settle before implementation, Checklist, A pass-through result in a struct field is never released, Key, mapBucketOfEntry(), mapClear(), mapEmpty() (+19 more)

### Community 40 - "suite.py"
Cohesion: 0.09
Nodes (17): build_arms(), check_prerequisites(), command_text(), elf_sections(), ensure_rust_sysroot(), _first_line(), format_count(), geomean() (+9 more)

### Community 41 - "aif_intern"
Cohesion: 0.06
Nodes (48): aif_con_pin_region(), aif_elem_key(), aif_enum_new(), aif_field_access(), aif_field_has_range(), aif_field_is_counted(), aif_field_is_cyclic(), aif_field_range_bytes() (+40 more)

### Community 42 - "aifWalk"
Cohesion: 0.05
Nodes (65): aif_compute_type_acyclic(), aif_con_at(), aif_con_bind(), aif_con_fn(), aif_con_live_in(), aif_con_pin(), aif_con_pin_region(), aif_con_return_binding() (+57 more)

### Community 43 - "impl RelLoop"
Cohesion: 0.07
Nodes (39): ir_range_proof_marked(), dbmAssign(), dbmAssumeLE(), dbmClose(), dbmCopy(), dbmCopyInto(), dbmForget(), dbmGet() (+31 more)

### Community 44 - "TypeInfo"
Cohesion: 0.04
Nodes (249): 4. Optional / nullable reference fields — **DONE, 2026-08-07; return position 2026-08-19**, 5. Where it lands, nodeIsProperty(), ptr_to_type(), nodeSetType(), typeArrayCopies(), typeArraySized(), typeChannelElem() (+241 more)

### Community 45 - "Token"
Cohesion: 0.28
Nodes (4): charCode(), impl Lexer, Token, main()

### Community 46 - "aif_tier_of"
Cohesion: 0.08
Nodes (45): Level 2 — T2 and scope drop — **DONE, 2026-08-06**, Struct-field ownership — **DONE, 2026-08-07**, aif_arena_at_node(), aif_cycle_at_node(), aif_elem_owner_at_node(), aif_fn_lookup(), aif_fn_may_return_param(), aif_fn_may_return_view_of_param() (+37 more)

### Community 47 - "string.psm"
Cohesion: 0.03
Nodes (73): impl Display for I64, str_find_byte_pair(), str_find_byte(), str_find_needle(), charDigitValue(), charIsAlnum(), charIsAlpha(), charIsDigit() (+65 more)

### Community 48 - "release.py"
Cohesion: 0.11
Nodes (20): bootstrap(), build_release_compiler(), check_floor(), die(), host_platform(), llvm_objdump(), macos_minos(), main() (+12 more)

### Community 49 - "elide_middle"
Cohesion: 0.06
Nodes (16): elide_middle(), run_byte_loop_vectorise_test(), run_c_abi_extension_test(), run_cold_function_test(), run_crlf_triple_string_test(), run_identifier_security_test(), run_jit_test(), run_overflow_checks_test() (+8 more)

### Community 50 - "src/main.psm"
Cohesion: 0.12
Nodes (31): aif_layout_force(), diag_print_help(), diag_set_json_mode(), ir_set_opt_level(), compiler_default_exe_path(), compiler_host_abi(), compiler_link_flag(), compiler_native_flag() (+23 more)

### Community 51 - "key.psm"
Cohesion: 0.06
Nodes (20): keyHashBytes(), keyMixInt(), keyMixWide(), keyStrengthen(), impl Key for Bool, impl Key for Char, impl Key for I64, impl Key for Int (+12 more)

### Community 52 - "fprintf"
Cohesion: 0.06
Nodes (84): compiler_bootstrap_executable(), ir_jit_run_main(), diag_add_file(), diag_detect_color(), diag_digits(), diag_elapsed(), diag_emit(), diag_emit_json() (+76 more)

### Community 53 - "test_176_match_diverges.psm"
Cohesion: 0.70
Nodes (4): code(), firstPositive(), main(), orZero()

### Community 54 - "test_102_generic_trait_arguments.psm"
Cohesion: 0.08
Nodes (28): impl ScaleBy for String, acceptsWrapped(), crossTag(), fail(), main(), make(), sameTag(), scaleWithBool() (+20 more)

### Community 55 - "main"
Cohesion: 0.13
Nodes (5): impl U16, impl U64, impl U8, fail(), main()

### Community 56 - "ir_symbols.c"
Cohesion: 0.05
Nodes (27): drop_index(), find_binding(), ir_binding_owns_slot(), ir_binding_predates_loop(), ir_drop_kind(), ir_drop_slot(), ir_drop_type(), ir_get_var_data() (+19 more)

### Community 57 - "alpha.psm"
Cohesion: 0.08
Nodes (29): main(), main(), main(), main(), fail(), main(), main(), main() (+21 more)

### Community 59 - "bits_set"
Cohesion: 0.16
Nodes (29): aif_oom(), bits_clear(), bits_count_at_least_two(), bits_ensure(), bits_free(), bits_is_empty(), bits_or(), bits_set() (+21 more)

### Community 60 - "Ord"
Cohesion: 0.06
Nodes (27): impl Ord for Char, impl Ord for Float, impl Ord for I16, impl Ord for I64, impl Ord for I8, impl Ord for Int, impl Ord for Isize, impl Ord for U16 (+19 more)

### Community 61 - "Default"
Cohesion: 0.08
Nodes (23): impl Default for Bool, impl Default for Char, impl Default for Float, impl Default for I16, impl Default for I64, impl Default for I8, impl Default for Int, impl Default for Isize (+15 more)

### Community 62 - "nowrap.psm"
Cohesion: 0.21
Nodes (25): nowrapAnalyse(), nowrapBlock(), nowrapClamp(), nowrapCondition(), nowrapDeclared(), nowrapExecutions(), nowrapExprChain(), nowrapFactsNew() (+17 more)

### Community 63 - "Architecture direction — what to build next, and what the literature already settled"
Cohesion: 0.15
Nodes (12): 0 · The diagnosis, and the one thing everybody had backwards, 1 · Close the runtime seam — built, with one deployment decision left, 2 · Reuse analysis — useful only where the program has its trigger shape, 3 · Regions: go non-lexical and polymorphic, 4 · Views and slices — bounded views and mutable data views shipped, 5 · The allocator — measured and closed for the current workload, 6 · The ranked plan, 7 · Measured dead ends — do not re-derive these (+4 more)

### Community 64 - "data_structures.rs"
Cohesion: 0.20
Nodes (3): flat_bitset(), hashmap_insert_lookup(), trie_search()

### Community 65 - "option.psm"
Cohesion: 0.04
Nodes (53): 14. Error handling — tagged unions, `Option` / `Result` — **DONE, 2026-08-19**, Result, Err, Ok, okOr(), resultErrOr(), resultIsErr(), resultIsOk() (+45 more)

### Community 66 - "setup_llvm.py"
Cohesion: 0.08
Nodes (34): Step 2 -- static LLVM on Windows, What 2a and 2b found (2026-10-14), main(), read_pin(), seed_name(), source_version(), verified(), adopt() (+26 more)

### Community 67 - "algorithms.cpp"
Cohesion: 0.12
Nodes (22): build_one_sexpr(), build_tree(), eval_sexpr_ast(), fibonacci(), gcd_lcm(), gcd_value(), knapsack(), merge_range() (+14 more)

### Community 68 - "unicode_conformance.psm"
Cohesion: 0.10
Nodes (31): identifierSkeleton(), builderPiece(), strFromScalar(), strJoin(), impl StringBuilder, StringBuilder, firstByte(), main() (+23 more)

### Community 69 - "node_to_ptr"
Cohesion: 0.06
Nodes (107): node_to_ptr(), ptr_null(), createNode(), nodeList(), nodeListPush(), nodeSpanFrom(), NodeList, resolveImports() (+99 more)

### Community 70 - "impl String"
Cohesion: 0.03
Nodes (49): A function that returns a view of its argument: the fact does not survive indirection, Language surface, semaReadLiteralAs(), proc_wait(), charIsSpace(), strChars(), strContains(), strContainsChar() (+41 more)

### Community 71 - "sys"
Cohesion: 0.04
Nodes (45): compare(), main(), parse_bracketing(), parse_compiler(), parse_oracle(), parse_threads(), run(), under_neutral_name() (+37 more)

### Community 72 - "backend_fail"
Cohesion: 0.05
Nodes (55): strncpy(), abi_ext_kind(), apply_borrow_attrs(), array_literal_push(), backend_fail(), const_from_text(), grow_table(), ir_alloca() (+47 more)

### Community 73 - "ast/types.psm"
Cohesion: 0.07
Nodes (98): 16. Fix superlinear compile time — **DONE, 2026-08-17**, ir_extern_decl_record(), ir_index_decl(), ir_reset_decl_index(), type_to_ptr(), indexModuleDeclarations(), indexTopLevel(), isExternDecl() (+90 more)

### Community 74 - "BoundedQueue"
Cohesion: 0.16
Nodes (7): BoundedQueue, cap_, closed_, mu_, not_empty_, not_full_, queue_

### Community 75 - "LLVMModuleRef"
Cohesion: 0.09
Nodes (37): Constraints on the bridge, Later, and not part of this plan, LLVM C++ bridge and static LLVM on Windows, Resuming, Step 1 -- the bridge and lazy merge, macOS and Linux, What step 1 found (2026-10-14), Why, Why a bridge and not a C++ port (+29 more)

### Community 76 - "ptr_to_node"
Cohesion: 0.03
Nodes (197): ptr_to_node(), nodeIsNull(), ir_range_proof_mark(), ir_range_proof_new(), ir_range_trace(), ir_var_is_global(), nowrapChainHasContinue(), nowrapCounter() (+189 more)

### Community 77 - "report.psm"
Cohesion: 0.06
Nodes (71): M4 · `T?` where a sentinel stands in for absence, aif_alias_name(), aif_arena_blockers(), aif_cause_build(), aif_cause_col(), aif_cause_domain_for(), aif_cause_file(), aif_cause_line() (+63 more)

### Community 78 - "run_command"
Cohesion: 0.05
Nodes (24): emitted_layout_for(), run_aif_array_frame_test(), pushes_in(), run_aif_human_report_test(), run_aif_loop_bracket_test(), run_aif_minimal_cause_test(), why(), run_bracket_summary_test() (+16 more)

### Community 79 - "layout.py"
Cohesion: 0.23
Nodes (11): candidates(), field_align(), field_width(), Layout, main(), min_size(), mu_for(), record_size() (+3 more)

### Community 80 - "targets/target.psm"
Cohesion: 0.08
Nodes (38): fail(), main(), named(), Named, umsBuildPlanCreate(), umsBuildProfileValid(), umsPlannedOutput(), UmsBuildPlan (+30 more)

### Community 81 - "input.psm"
Cohesion: 0.10
Nodes (36): 1 · The program that does not build, 3 · What to change, cheapest first, 4 · Order, Reading input: what is awkward and what to change, Toolchain, packaging and tests, io_stdin_has_line(), io_stdin_read_all(), io_stdin_take_line() (+28 more)

### Community 82 - "UmsTokenKind"
Cohesion: 0.09
Nodes (36): UmsAstStatementKind, ASSIGNMENT, CALL, UNKNOWN, UmsAstValueKind, ARRAY, BOOLEAN, IDENTIFIER (+28 more)

### Community 83 - "ir/stmt.psm"
Cohesion: 0.07
Nodes (100): M5 · `std.vec` in place of hand-rolled search loops, ir_add_nsw(), ir_add(), ir_alloca(), ir_and(), ir_br_numbered(), ir_clear_returned(), ir_cond_br_numbered() (+92 more)

### Community 84 - "__builtin_string_len"
Cohesion: 0.05
Nodes (56): charToLower(), charToUpper(), strAsciiCaseInto(), strAsciiEqualsIgnoreCase(), strByteAt(), strBytes(), strCapitalize(), strCaseDeltaAt() (+48 more)

### Community 85 - "TypeKind"
Cohesion: 0.09
Nodes (21): aif_ledger_init(), cyc_lock_init(), TypeKind, ARRAY, BOOL, CHAR, DATAELEMENT, DATAVIEW (+13 more)

### Community 86 - "panic.c"
Cohesion: 0.07
Nodes (35): Commands, 3 · Choices, 5 · Order of work, 6 · What this does not decide, 7 · What was built (2026-10-09), Freestanding memory: what a heap means with no operating system, 1 · What the probe measured (2026-10-08), 2 · Gaps, ranked by how much each blocks (+27 more)

### Community 87 - "AIF — The Inference Engine"
Cohesion: 0.05
Nodes (41): 10 · Worked example, 11.1 Field sensitivity is object-insensitive, 11.2 The context set is discovered from facts that are still moving, 11.3 Loops are handled by the lattice, not by a loop analysis, 11.4 There is no interprocedural path sensitivity, 11.5 ~~The `⊤` context is a cliff~~ — resolved in 1.2, 11.6 Everything here assumes whole-program PIR, 11 · Known weaknesses (+33 more)

### Community 88 - "main"
Cohesion: 0.05
Nodes (19): A constant shared across the seam has one spelling everywhere, find_prismio_exe(), main(), parse_runner_args(), run_aif_test(), run_bootstrap_cache_key_test(), run_curated_emits_test(), run_elem_mode_agreement_test() (+11 more)

### Community 89 - "ir_intern"
Cohesion: 0.10
Nodes (30): diag_file_module(), find_struct(), ir_caller_can_access_extern(), ir_caller_extern_hidden_level(), ir_extern_decl_record(), ir_file_declares_extern(), ir_file_imports_module(), ir_get_enum_variant() (+22 more)

### Community 90 - "2 · What 0.1 ships"
Cohesion: 0.07
Nodes (25): 1 · Left for 0.1, 2 · What 0.1 ships, 4 · Limits in 0.1, 6 · Verification, Collection methods, 1 · Decisions, `Array<T, N>` is an array whose length is part of its type, Collections (+17 more)

### Community 91 - "AIF — Design Rationale"
Cohesion: 0.10
Nodes (21): AIF — Design Rationale, Arena placement is a cost decision; `region` is a pin on it, Bake the static region, not the heap, C1, C10, C11, C2, C3 (+13 more)

### Community 92 - "copy.psm"
Cohesion: 0.09
Nodes (15): impl Copy for Bool, impl Copy for Char, impl Copy for Float, impl Copy for I16, impl Copy for I64, impl Copy for I8, impl Copy for Int, impl Copy for Isize (+7 more)

### Community 93 - "test_101_generic_trait_impl.psm"
Cohesion: 0.11
Nodes (18): fail(), main(), markAny(), pairKindAny(), readAny(), impl Marked for Label, impl PairKind for Pair, impl Positive for Int (+10 more)

### Community 94 - "test_103_default_trait_methods.psm"
Cohesion: 0.10
Nodes (17): Adding a workload, fail(), greetThrough(), main(), impl Bump for Counter, impl Greet for Cat, impl Greet for Dog, impl ScaleBy for Dog (+9 more)

### Community 95 - "hosted/rust/algorithms.rs"
Cohesion: 0.15
Nodes (8): gcd_lcm(), gcd_value(), merge_range(), mergesort_work(), quick_range(), quicksort_work(), random_values(), sorted_checksum()

### Community 96 - "assign.psm"
Cohesion: 0.25
Nodes (32): flowAssign(), flowAssignment(), flowBackEdge(), flowBlock(), flowCallNeverReturns(), flowCopy(), flowDeclare(), flowDropOpen() (+24 more)

### Community 97 - "run.py"
Cohesion: 0.13
Nodes (12): build_all(), build_key(), command_text(), cpp_lto_flags(), execute(), normalize_rss_bytes(), parse_output(), read_stamp() (+4 more)

### Community 98 - "Code Style"
Cohesion: 0.04
Nodes (52): 10. State and cleanup, 11. CLI architecture, 12. FFI and native boundaries, 13. Performance, 14. Testing and validation, 15. Working with agents, 16. A practical review checklist, 17. The governing principles (+44 more)

### Community 99 - "1 · AIF core — genuinely ours"
Cohesion: 0.10
Nodes (21): 1 · AIF core — genuinely ours, 2 · AIF's stake in language features it does not own, 3 · Compiler requirements AIF genuinely has, 4 · Measurement, 5 · Not AIF — recorded, then handed over, 6 · Over-built — defer or cut, A3. Realised context counts *(measurement)*, A4. Arena high-water marks *(measurement)* (+13 more)

### Community 100 - "AIF — Workload Declaration, Cost Model, and Layout Search"
Cohesion: 0.05
Nodes (40): 10.1 The cache model has no associativity and no conflict misses, 10.2 `HandleCost` is a placeholder, 10.3 Profiles age, 10.4.1 A fabricated instance count decides the cache tier, and therefore the layout, 10.4 Static frequency estimation is crude, 10.5 One profile, one target, 10 · Known weaknesses, 1 · The key reframing (+32 more)

### Community 101 - "package.py"
Cohesion: 0.25
Nodes (10): build_plib(), build_plib_ir(), build_runtime_bitcode(), die(), llvm_bin(), llvm_clang(), main(), run() (+2 more)

### Community 102 - "time.psm"
Cohesion: 0.16
Nodes (12): main(), time_monotonic_nanos(), time_sleep_nanos(), time_unix_nanos(), sleep(), unixTime(), impl Duration, impl Instant (+4 more)

### Community 103 - "contents.psm"
Cohesion: 0.26
Nodes (18): contentAbsent(), contentConst(), contentFail(), contentHasRelative(), contentHigher(), contentLower(), contentMax(), contentMin() (+10 more)

### Community 104 - "strcmp"
Cohesion: 0.21
Nodes (27): compiler_plib_module_registered(), strcmp(), di_basic(), di_cache(), di_cached(), di_data_element_type(), di_enum_type(), di_field_type_name() (+19 more)

### Community 105 - "hosted/prismio/algorithms.psm"
Cohesion: 0.11
Nodes (32): BenchSExpr, Empty, Num, Op, benchBuildOneExpr(), benchBuildTree(), benchDijkstraShortestPath(), benchEditDistance() (+24 more)

### Community 106 - "AIF — The T4 Cycle Collector"
Cohesion: 0.11
Nodes (18): 10 · What still needs measurement, 1 · What is actually in scope, 2 · The headline result, 3.1 Why trial deletion and not tracing, 3.2 The procedure, 3 · Algorithm, 4 · The cyclic-edge restriction, 5 · Object header (+10 more)

### Community 107 - "README.md"
Cohesion: 0.07
Nodes (27): Before you commit, C code style, Comments, Files and modules, Naming, Writing the code, Before a release, Code style (+19 more)

### Community 108 - "prismio_llvm.h"
Cohesion: 0.04
Nodes (25): 2 · Compile time, 3 · Binary size, 4 · Rejected, with the measurement, Build speed and binary size, Resuming, Where a build goes, bridge_message(), prismio_llvm_drop_body() (+17 more)

### Community 109 - "adversarial.rs"
Cohesion: 0.12
Nodes (21): adversarial_next(), AdversarialObject, allocation_escape(), branch_mispredict(), consume_adversarial_object(), dead_code_elimination(), dead_kernel(), function_call_overhead() (+13 more)

### Community 110 - "AIF — Adaptive Inference Framework"
Cohesion: 0.17
Nodes (12): 0 · Conformance language, 12 · What this model gives up *(informative)*, 1.1 What the invariant does not cover, 1 · The invariant, 6.1 Purpose, 6.2 Format, 6.3 Diff semantics, 6 · The tier manifest (+4 more)

### Community 111 - "release_gate.py"
Cohesion: 0.19
Nodes (31): bad(), bootstrap(), check_cross_target(), check_differential(), on_line(), check_environment_switch(), check_fixpoint(), check_generations() (+23 more)

### Community 112 - "aif/README.md"
Cohesion: 0.23
Nodes (7): AIF: the memory model, The model in one screen, The raw experiment records, AIF oracle, Approximations, Running it, Two bugs found here, both worth remembering

### Community 113 - "block_done"
Cohesion: 0.14
Nodes (35): block_done(), block_for(), element_from_memory(), element_memory_type(), element_to_memory(), flat_element_address(), ir_br_numbered(), ir_call_indirect_ptr() (+27 more)

### Community 114 - "TokenType"
Cohesion: 0.08
Nodes (25): TokenType, AMPERSAND, ARITHMETIC_OPERATOR, ARROW, ASSIGNMENT_OPERATOR, BITWISE_OR, BOOL_LITERAL, CHAR_LITERAL (+17 more)

### Community 115 - "test_169_loop_range_proofs.psm"
Cohesion: 0.18
Nodes (27): Slot, At, Empty, ascending(), binderShadow(), bisect(), bisectSum(), check() (+19 more)

### Community 116 - "Added"
Cohesion: 0.10
Nodes (25): arena_bump(), binary_codec(), bits_from_float(), build_memory_tree(), BumpArena, block, top, float_from_bits() (+17 more)

### Community 117 - "generics.psm"
Cohesion: 0.09
Nodes (67): 3 · How, A list literal is not accepted as a call argument, nodeIsCallableBound(), semaContainsProjection(), semaFindConformingMethod(), semaHasConformingMethod(), semaImplParam(), monoAddDefaultMethod() (+59 more)

### Community 118 - "main"
Cohesion: 0.36
Nodes (9): filter(), skip(), take(), chained(), fail(), longOnes(), main(), word() (+1 more)

### Community 119 - "test_238_scalar_optionals.psm"
Cohesion: 0.23
Nodes (11): Color, Blue, Green, Red, describe(), fail(), firstOr(), half() (+3 more)

### Community 120 - "test_289_async_await.psm"
Cohesion: 0.17
Nodes (20): print(), println(), check(), consume(), direct_await(), dropped_future_never_runs(), future_as_argument(), generics_and_recursion() (+12 more)

### Community 121 - "aifEmitBrackets"
Cohesion: 0.13
Nodes (19): aif_bracket_callee(), aif_bracket_count(), aif_bracket_scope(), aif_bracket_served(), aif_budget_count(), aif_region_serves(), aif_scope_budget_col(), aif_scope_budget_file() (+11 more)

### Community 122 - "test_107_associated_types.psm"
Cohesion: 0.16
Nodes (18): fail(), intContainer(), itemOf(), itemOf(), main(), matches(), pick(), same() (+10 more)

### Community 123 - "test_116_trait_objects.psm"
Cohesion: 0.16
Nodes (14): fail(), forwarded(), main(), measure(), measureScaled(), nameOf(), impl Named for Rect, impl Named for Square (+6 more)

### Community 124 - "enum_visibility/enums.psm"
Cohesion: 0.06
Nodes (42): DefaultMode, No, Yes, FileMode, Here, Only, FileShape, Circle (+34 more)

### Community 125 - ".equals"
Cohesion: 0.03
Nodes (121): 1. What exists today, aifCompilerBuiltinContract(), ptr_is_null(), loopBodyOf(), nodeMarkFromEnum(), nodeMarkPacked(), nodeMarkProperty(), nodeMarkReprC() (+113 more)

### Community 126 - "test_98_multiple_trait_bounds.psm"
Cohesion: 0.28
Nodes (8): activeScore(), checkedScore(), main(), impl Enabled for Int, impl Scored for Int, Gate, Enabled, Scored

### Community 127 - "AIF — The Target Workload"
Cohesion: 0.17
Nodes (12): 0.1 · Engine and game remain two workloads, 0 · The actual stack, 1 · The two halves, 2.1 The annotations belong to the engine layer, 2.2 T3 lives in the engine, T0–T2 in the game, 2.3 The engine/game boundary is where whole-program analysis must hold, 2.4 The manifest becomes a contract between teams, 2.5 Optimisation level has to be **per module**, not per build (+4 more)

### Community 128 - "host.psm"
Cohesion: 0.16
Nodes (25): diag_styled_err(), diag_styled(), diag_warning_code(), compiler_check_executable(), compiler_check_host_abi(), compiler_emit_local_toolchain(), compiler_forward_cli(), compiler_host_stamp_matches() (+17 more)

### Community 129 - "build_tree"
Cohesion: 0.24
Nodes (8): build_one_sexpr(), build_tree(), eval_sexpr_ast(), parse_sexpr_ast(), s_expression_parse(), SExprAST, tree_sum(), tree_traversal()

### Community 130 - "test_127_enum_null_variant.psm"
Cohesion: 0.15
Nodes (27): Maybe, None, Some, Reversed, Empty, Value, Three, First (+19 more)

### Community 131 - "debug_info.psm"
Cohesion: 0.18
Nodes (18): Channel, EAST, NORTH, SOUTH, channelOf(), checkpointTotal(), describe(), main() (+10 more)

### Community 132 - "residues.psm"
Cohesion: 0.15
Nodes (15): ir_rem_form_mark(), nowrapMarkRemainder(), loopResidues(), remainderDivisor(), remainderForm(), remainderLiteral(), residueRangeNew(), impl LoopResidues (+7 more)

### Community 133 - "io.rs"
Cohesion: 0.27
Nodes (9): alpha(), base64_codec(), byte_sum(), csv_parse(), digit(), file_read(), file_write(), space() (+1 more)

### Community 134 - "symbols.psm"
Cohesion: 0.08
Nodes (40): nodeHasType(), diag_file_count(), ir_caller_can_access_extern(), ir_caller_extern_hidden_level(), contentsBaseName(), contentsCollect(), contentsIsIntArray(), semaStdAsmBuiltin() (+32 more)

### Community 135 - "8.4 Views — slices and element references"
Cohesion: 0.20
Nodes (10): 8.1 Handles, 8.2 The compiler owns layout, 8.3 The static region, 8.4 Views — slices and element references, 8 · Representation, Cost, stated plainly, Element references are views too — the deep consequence, Invalidation, without a borrow checker (+2 more)

### Community 136 - "benchRun"
Cohesion: 0.07
Nodes (59): benchBinarySearch(), benchLz4Compress(), benchSortStrings(), benchPrint(), benchPrintln(), benchPrintln(), benchPrintln(), benchRandom() (+51 more)

### Community 137 - "test_181_std_math.psm"
Cohesion: 0.33
Nodes (7): checkBool(), checkInt(), main(), near(), same(), sumOfRoots(), sumOfRootsInline()

### Community 138 - "test_104_where_clauses.psm"
Cohesion: 0.16
Nodes (15): both(), fail(), heavy(), main(), render(), renderBoth(), impl Boxed for Box, impl Show for Bool (+7 more)

### Community 139 - "test_118_impl_trait.psm"
Cohesion: 0.23
Nodes (16): choose(), describe(), fail(), heavy(), main(), makePoint(), pair(), roundTrip() (+8 more)

### Community 140 - "test_79_slices.psm"
Cohesion: 0.50
Nodes (8): fail(), first(), main(), middle(), pointSum(), Point, Tagged, Window

### Community 141 - "test_232_channel_copies.psm"
Cohesion: 0.26
Nodes (19): closeWakesReceiver(), double(), fail(), keptAcrossIterations(), main(), next(), notesStayBoxed(), produceCount() (+11 more)

### Community 142 - "Buffer"
Cohesion: 0.09
Nodes (25): benchArenaBump(), benchManualAllocChurn(), mem_bytes_copy(), mem_bytes_resize(), mem_bytes_write_text(), mem_free(), arenaBadAlign(), arenaFull() (+17 more)

### Community 143 - "hosted/rust/compute.rs"
Cohesion: 0.09
Nodes (15): binary_search_work(), dijkstra_shortest_path(), lz4_compress(), sort_strings(), next_random(), band_sum(), BenchSphere, blake3_chunk() (+7 more)

### Community 144 - "test_105_supertraits.psm"
Cohesion: 0.17
Nodes (12): describeAny(), fail(), main(), impl Described for Item, impl Named for Item, impl Reported for Item, impl Sized for Item, Item (+4 more)

### Community 145 - "test_164_array_fields.psm"
Cohesion: 0.19
Nodes (17): Shape, Cells, Empty, corners(), fail(), fourDown(), main(), makeGrid() (+9 more)

### Community 146 - "test_71_nonlexical_extent.psm"
Cohesion: 0.23
Nodes (20): build_a(), build_b0(), build_b(), build_c0(), build_c(), build_d0(), build_d(), build_e() (+12 more)

### Community 148 - "compile.psm"
Cohesion: 0.07
Nodes (45): diag_error_count(), diag_progress_begin(), diag_progress(), diag_result(), diag_status(), diag_warning_count(), compiler_build_executable(), compiler_installed_runtime_hash() (+37 more)

### Community 150 - "run"
Cohesion: 0.09
Nodes (62): aos_vs_soa(), memcpy_mix(), binary_search_work(), dijkstra_shortest_path(), edit_distance(), graph_bfs(), lz4_compress(), prime_sieve() (+54 more)

### Community 151 - "test_286_stride_tiling.psm"
Cohesion: 0.50
Nodes (7): check(), checksumBools(), checksumInts(), main(), readback(), sieve(), strided()

### Community 152 - "impl Parser"
Cohesion: 0.09
Nodes (7): 2. Visibility markers on enums (done, uncommitted), nodeSetFnAttrs(), nodeMarkCold(), diag_error_at_code(), copyTypeAnnotationInto(), enumDefaultVisibility(), impl Parser

### Community 153 - "struct_entry"
Cohesion: 0.08
Nodes (39): ir_get_struct_field_count(), ir_get_struct_field_type_at(), ir_is_struct_type_name(), attach_cold(), attach_cold_rc(), get_or_declare_alloc_fn(), get_or_declare_free_fn(), ir_alloc_cycle() (+31 more)

### Community 154 - "test_56_list_capacity.psm"
Cohesion: 0.53
Nodes (9): print(), println(), computed_hint(), exact_fit(), fail(), grows_past_the_hint(), main(), zero_hint_is_clamped() (+1 more)

### Community 155 - "aif.py"
Cohesion: 0.11
Nodes (14): base_type(), bracket_masks(), elem_key(), ffi_arena_cannot_serve(), main(), measure_masks(), scan(), report() (+6 more)

### Community 156 - "impl ArrayContents"
Cohesion: 0.14
Nodes (9): Analysis quality — three recorded gaps closed, 2026-08-06, 2. Corrections to the proposal, 3. Surface, 4. Beyond Rust, C and C++, 6. Honest limits, 7. Open, `Ptr<T>`: a typed pointer, impl ArrayContents (+1 more)

### Community 157 - "run_debug_info_test"
Cohesion: 0.10
Nodes (12): _di_composite(), _di_located_lines(), _di_located_spans(), _di_nodes(), _di_scope_file(), _di_tuple(), _emitted_struct(), _expected_layout() (+4 more)

### Community 158 - "hardware.rs"
Cohesion: 0.22
Nodes (4): COUNTER, LOCK, REGISTERS, WORD

### Community 160 - "platform.psm"
Cohesion: 0.10
Nodes (18): Architecture, X86_64, Environment, GNU, Platform, Windows, impl PlatformQuery, PlatformQuery (+10 more)

### Community 161 - "aif_concurrency.psm"
Cohesion: 0.33
Nodes (18): cli_arg(), register_forever(), break_is_absorbed_by_its_loop(), join_on_both_paths(), joined_stays_local(), loop_between_spawn_and_join(), main(), no_task_at_all() (+10 more)

### Community 162 - "named_struct"
Cohesion: 0.12
Nodes (27): build_three_way(), byte_gep(), coerce_for(), ir_call_arg_borrow(), ir_call_arg_cstr(), ir_const_str(), ir_global_str_var(), ir_str_byte_at_long() (+19 more)

### Community 163 - "assert"
Cohesion: 0.14
Nodes (12): Language at a glance, exit(), assert(), main(), classify(), main(), b(), checkedSum() (+4 more)

### Community 164 - "test_115_trait_imports.psm"
Cohesion: 0.19
Nodes (11): fail(), greetAny(), main(), impl Greet for Local, Local, decoration(), impl Greet for Host, impl Sized for Host (+3 more)

### Community 165 - "test_92_field_view_provenance.psm"
Cohesion: 0.22
Nodes (17): Count, Absent, Present, Holder, Empty, Full, boxText(), countValue() (+9 more)

### Community 166 - "test_map_update.psm"
Cohesion: 0.16
Nodes (10): abort(), unexpectedUpdate(), impl Copy for ProbeKey, impl Copy for UpdateKey, impl CountUpdate, impl Key for ProbeKey, impl Key for UpdateKey, CountUpdate (+2 more)

### Community 167 - "Decisions"
Cohesion: 0.12
Nodes (18): clean(), A command is manifest data; which names are free is not, Current limitations, Decisions, Generated state is project-local and isolated, Host selection is a stable prefix, Incremental-build extension seam, Module boundaries (+10 more)

### Community 168 - "shapes.psm"
Cohesion: 0.18
Nodes (12): main(), main(), show(), main(), main(), makePoint(), packageOnlyValue(), secretOf() (+4 more)

### Community 169 - "test_165_ranges_repeat_labels.psm"
Cohesion: 0.12
Nodes (17): Iterator, fail(), main(), impl Iterator for Countdown, impl Iterator for Letters, Countdown, Letters, classify() (+9 more)

### Community 170 - "retain"
Cohesion: 0.07
Nodes (34): 10 · Reporting, 1 · The one place being wrong is unsafe, 2 · C-compatible layout, 3.1 The four cases, 3.2 Copy direction, 3.3 What is never copied, 3 · When a copy is mandatory, 4 · The cost model does the work (+26 more)

### Community 172 - "inlineElemSizeOfList"
Cohesion: 0.08
Nodes (34): ir_guard_safe_verdict(), ir_is_guard_safe_fn(), ir_list_has_room(), ir_list_len(), ir_list_prepare_fill(), ir_struct_is_flat(), ir_struct_size(), aif_type_is_counted() (+26 more)

### Community 173 - "Tier 2 — required by specified AIF features"
Cohesion: 0.12
Nodes (16): 10. Per-module optimisation levels **[specified 2026-08-17, not implemented]**, 11. `verify` build mode **[needed]**, 12. Handles instead of raw pointers **[needed, long-horizon]**, 1. Affine collections — `String`, `List<T>`, arrays become move-only **[done, 2026-08-07]**, 2. `region { }` — keyword, arena runtime, handle threading **[done, 2026-08-07]**, 3. Shared references **[blocker for T3/T4]**, 3a. Closures **[blocker for Xefy]**, 5. A pass between sema and codegen **[enabling]** (+8 more)

### Community 174 - "test_276_float_text.psm"
Cohesion: 0.26
Nodes (11): 2. `json_parse` and `json_serialize` — P1, Checklist, Model and public surface to settle, strParseFloat(), fix(), floatOf(), fmt(), invalid() (+3 more)

### Community 175 - "float_text.psm"
Cohesion: 0.15
Nodes (21): floatAssemble(), floatByteAt(), floatFormat(), floatFormatFixed(), floatFromHex(), floatHexValue(), floatInfinity(), floatLower() (+13 more)

### Community 176 - "test_271_array_contents.psm"
Cohesion: 0.23
Nodes (16): check(), conjunctBefore(), continued(), counted(), doubling(), editRows(), escaped(), independent() (+8 more)

### Community 177 - "bits_test"
Cohesion: 0.07
Nodes (33): Adding or removing a runtime source, Done, Left, with what the next attempt should know, The standing refactor, A struct on the frame: three field shapes still leak, bits_test(), aif_compute_type_acyclic(), aif_layout_cand_field_hot() (+25 more)

### Community 178 - "Interop with C, C++ and Rust, in both directions"
Cohesion: 0.07
Nodes (22): 0 · The target, as a user writes it, 1.2 A defect the probe found: small integers reach C unextended, 1.3 The toolchain already has most of the parts, 1.4 Rust's LLVM is behind ours, which settles who drives LTO, 1 · Where it stands (2026-10-10), 2 · Prior art, and what each one teaches, 4 · Steps, in order, 5 · What "fluid" means, in numbers (+14 more)

### Community 179 - "cyc_hdr"
Cohesion: 0.17
Nodes (23): 2.1 · Observability first, 2.2 · Correctness of the runtime model, 2.5 · Only if telemetry asks for them, 2 · Later, cyc_alloc(), cyc_buffer(), cyc_collect(), cyc_collect_now() (+15 more)

### Community 180 - "test_map_probe.psm"
Cohesion: 0.43
Nodes (3): impl Copy for CollidingKey, impl Key for CollidingKey, CollidingKey

### Community 181 - "test_60_bracket_reset.psm"
Cohesion: 0.44
Nodes (8): arena_objects(), print(), println(), main(), make(), served_in_a_region(), touch(), Cmd

### Community 182 - "test_100_generic_inherent_impl.psm"
Cohesion: 0.18
Nodes (9): fail(), main(), impl Box, impl Cell, impl Score for Int, Box, Cell, Pair (+1 more)

### Community 183 - "test_240_overload_exactness.psm"
Cohesion: 0.16
Nodes (8): fail(), main(), twice(), impl Dup for Int, impl Dup for T, impl Name for U8, Dup, Name

### Community 184 - "test_70_struct_field_release.psm"
Cohesion: 0.29
Nodes (17): check(), crate_inventory_again(), main(), make_crate(), make_crate_inventory(), make_inventory(), nested_owner_again(), nested_owner() (+9 more)

### Community 185 - "UmsDiagnostic"
Cohesion: 0.15
Nodes (21): UmsDependencyScope, API, IMPLEMENTATION, TEST_IMPLEMENTATION, UNKNOWN, umsDependencyFind(), umsDependencyScopeName(), impl UmsDependency (+13 more)

### Community 186 - "freestanding/prismio/algorithms.psm"
Cohesion: 0.17
Nodes (13): bench_edit_distance(), bench_fibonacci(), bench_gcd_lcm(), bench_heapsort(), bench_knapsack(), bench_quicksort(), fib(), gcd() (+5 more)

### Community 188 - "Model"
Cohesion: 0.13
Nodes (3): ann_leaf_name(), Model, Scopes

### Community 189 - "test_267_none_coalescing.psm"
Cohesion: 0.38
Nodes (9): fail(), fallback(), fallbackText(), half(), main(), nameOf(), pointFor(), Point (+1 more)

### Community 190 - "test_75_std_string.psm"
Cohesion: 0.43
Nodes (5): mem_bytes_text(), fail(), main(), referenceIndexOf(), searchFixture()

### Community 191 - "neg_295_ptr_writes_refused.psm"
Cohesion: 0.26
Nodes (8): malloc(), readOnlyField(), rebind(), storeStruct(), wholeStruct(), Header, Node, Packet

### Community 192 - "benchmarks.hpp"
Cohesion: 0.18
Nodes (5): BenchTree, left, right, value, main()

### Community 193 - "test_222_type_constructors.psm"
Cohesion: 0.20
Nodes (10): fail(), main(), size(), impl Point, Point, fail(), main(), prices() (+2 more)

### Community 194 - "test_128_enum_null_reserved.psm"
Cohesion: 0.20
Nodes (16): Exposed, Empty, Node, Generic, None, Some, OptionalTree, Empty (+8 more)

### Community 195 - "test_69_task_results.psm"
Cohesion: 0.32
Nodes (16): print(), println(), acknowledge(), check(), count_span(), int_result(), main(), name_span() (+8 more)

### Community 196 - "test_111_blanket_impls.psm"
Cohesion: 0.19
Nodes (11): fail(), main(), viaBound(), impl Pretty for T, impl Show for Cat, impl Show for Dog, Cat, Dog (+3 more)

### Community 197 - "manifest_records"
Cohesion: 0.11
Nodes (9): aif_records(), aif_thread_records(), manifest_records(), run_aif_annotation_test(), run_aif_concurrency_test(), run_aif_widening_test(), run_pin_tier_test(), run_placement_pin_test() (+1 more)

### Community 198 - "bracket_place"
Cohesion: 0.07
Nodes (40): aif_arena_blockers(), aif_arena_high_water(), aif_arena_range_first(), aif_arena_range_last(), aif_arena_unsized_sites(), aif_auto_arena_at_node(), aif_bracket_callee(), aif_bracket_count() (+32 more)

### Community 199 - "add_binding"
Cohesion: 0.13
Nodes (15): add_binding(), decl_entry(), guard_safe_entry(), hash_str(), ir_decl_at(), ir_decl_count(), ir_get_fn_return_type(), ir_guard_safe_verdict() (+7 more)

### Community 200 - "algorithms.c"
Cohesion: 0.10
Nodes (27): bench_binary_search(), bench_edit_distance(), bench_fibonacci(), bench_gcd_lcm(), bench_heapsort(), bench_knapsack(), bench_matrix_multiply(), bench_prime_sieve() (+19 more)

### Community 201 - "run_hosted"
Cohesion: 0.14
Nodes (15): compiler_identity(), elimination_benchmarks(), format_bytes(), format_seconds(), geomean(), is_elimination(), make_fixture(), measured_benchmarks() (+7 more)

### Community 202 - "test_55_workload_profile.psm"
Cohesion: 0.29
Nodes (13): exit(), print(), println(), build(), checksum(), cold(), hot(), main() (+5 more)

### Community 203 - "test_270_array_nowrap.psm"
Cohesion: 0.27
Nodes (13): check(), coalesced(), earlyExit(), headKill(), knapsack(), main(), negativeLeft(), quick() (+5 more)

### Community 204 - ".toString"
Cohesion: 0.25
Nodes (13): fail(), find(), label(), lengthOf(), main(), make(), named(), spelled() (+5 more)

### Community 205 - "aif_tiers.psm"
Cohesion: 0.27
Nodes (15): cli_arg(), str_concat(), tree_root(), main(), tier_array_elements(), tier_four_cyclic(), tier_one_dropped(), tier_one_string() (+7 more)

### Community 206 - "test_108_trait_method_namespaces.psm"
Cohesion: 0.26
Nodes (10): fail(), loudly(), main(), impl Loud for Dog, impl Loud for Robot, impl Soft for Dog, Dog, Robot (+2 more)

### Community 207 - "test_109_trait_ownership.psm"
Cohesion: 0.24
Nodes (9): fail(), main(), impl Consume for Buffer, impl Read for Buffer, impl Update for Buffer, Buffer, Consume, Read (+1 more)

### Community 208 - "test_58_region_serves.psm"
Cohesion: 0.47
Nodes (15): arena_objects(), print(), println(), fail(), main(), make(), make_out(), make_outside() (+7 more)

### Community 209 - "Profile"
Cohesion: 0.18
Nodes (4): Profile, walk(), find_gets(), Traversal

### Community 210 - "LLVMValueRef"
Cohesion: 0.11
Nodes (26): abi_target_extends(), add_abi_ext_attr(), apply_abi_extensions(), apply_param_attrs(), apply_pointer_param_attrs(), build_bswap64(), build_fmuladd(), copy_attributes_at_index() (+18 more)

### Community 211 - "io.cpp"
Cohesion: 0.26
Nodes (9): alpha(), byte_sum(), digit(), file_read(), file_write(), line_processing(), read_file(), space() (+1 more)

### Community 212 - "hosted/rust/memory.rs"
Cohesion: 0.13
Nodes (12): arena_bump(), binary_codec(), build_memory_tree(), BumpArena, get_bytes(), manual_alloc_churn(), memory_tree_sum(), MemoryParticle (+4 more)

### Community 213 - "test_96_channels.psm"
Cohesion: 0.49
Nodes (9): capacity_and_length(), fail(), main(), pool_round_trip(), serial_round_trip(), step(), worker(), Answer (+1 more)

### Community 214 - "generateReturn"
Cohesion: 0.16
Nodes (18): ir_array_load(), ir_loop_break_label(), ir_loop_break_label_named(), ir_loop_continue_label(), ir_loop_continue_label_named(), ir_loop_drop_floor(), ir_loop_drop_floor_named(), ir_loop_region_depth() (+10 more)

### Community 215 - "impl Buffer"
Cohesion: 0.10
Nodes (7): benchBinaryCodec(), mem_bytes_address(), mem_bytes_fill(), mem_bytes_index_of(), bufferAt(), impl Buffer, buffers()

### Community 216 - "run_freestanding"
Cohesion: 0.12
Nodes (12): collect_environment(), existing_suites(), first_line(), llvm_bin_from(), load_freestanding_suite(), main(), portable_command(), portable_part() (+4 more)

### Community 217 - "neg_165_array_field_refused.psm"
Cohesion: 0.16
Nodes (13): Shape, Dot, Many, Quad, fromView(), main(), Box, Grid (+5 more)

### Community 218 - "test_132_counted_fill.psm"
Cohesion: 0.27
Nodes (13): boolFill(), checkFill(), fill(), inclusiveFill(), interruptedFill(), main(), nearLimitFill(), observedFill() (+5 more)

### Community 219 - "test_157_shared_container_elements.psm"
Cohesion: 0.26
Nodes (14): Shape, Box, Dot, Tree, Leaf, Node, crossFlat(), crossList() (+6 more)

### Community 220 - "test_170_match_switch.psm"
Cohesion: 0.22
Nodes (14): Dir, East, North, South, West, byName(), byte(), classify() (+6 more)

### Community 221 - "globals.psm"
Cohesion: 0.18
Nodes (7): main(), globalsOwnPrivate(), globalsInternalFromSibling(), GLOBAL_INTERNAL, GLOBAL_OPEN, GLOBAL_PRIVATE, GLOBAL_PUBLIC

### Community 222 - "test_49_aif_struct_fields.psm"
Cohesion: 0.34
Nodes (14): check(), main(), make_crate(), make_crate_inventory(), make_inventory(), nested_owner(), owned_struct_return(), per_iteration() (+6 more)

### Community 223 - "test_87_traits.psm"
Cohesion: 0.27
Nodes (10): fail(), main(), maxOf(), pickLarger(), sortInPlace(), impl Ord for Int, impl Ord for String, impl Ord for Version (+2 more)

### Community 224 - "check_source_lists.py"
Cohesion: 0.21
Nodes (11): bootstrap_ps1_list(), bootstrap_sh_list(), Failure, freestanding_std(), llvm_targets(), macos_floors(), main(), manifest_native_sources() (+3 more)

### Community 226 - "test_269_struct_pass_through_escapes.psm"
Cohesion: 0.56
Nodes (8): check(), main(), pickLoop(), pickOuter(), pickPushed(), pickReturned(), returned(), Point

### Community 227 - "Ownership: leaks"
Cohesion: 0.14
Nodes (15): A container that may be handed a string literal releases none of its elements, A frame array frees none of its elements, A temporary on the right of `and`/`or` is never given a binding, A Vec that owns its elements: three places a displaced element still leaks, Assigning a struct field releases the value it replaces only for a fresh local, Library producers share one allocation site, Ownership: leaks, Recursive release is iterative along one self field only (+7 more)

### Community 228 - "test_30_diamond_imports.psm"
Cohesion: 0.44
Nodes (5): left_value(), right_value(), shared_double(), fail(), main()

### Community 229 - "test_154_extern_globals.psm"
Cohesion: 0.19
Nodes (10): readerArgc(), prismio_argc, main(), main(), prismio_argc, shadowed, fail(), main() (+2 more)

### Community 230 - "test_290_scope_spawn.psm"
Cohesion: 0.21
Nodes (17): print(), println(), bare_spawn_of_async_fn(), break_out(), captures(), check(), continue_out(), detached() (+9 more)

### Community 231 - "test_177_type_functions.psm"
Cohesion: 0.31
Nodes (8): fail(), main(), impl Box, impl Config, impl Server, Box, Config, Server

### Community 232 - "5 · Annotations"
Cohesion: 0.22
Nodes (9): 5.0.1 Annotations are assertions, not directives *(normative)*, 5.0 Why exactly these four *(normative rationale)*, 5.1 `unique`, 5.2.1.1 Call-site placement, and which regime it uses *(normative)*, 5.2.1.2 Non-lexical extent, and what it does to the obligations *(normative)*, 5.2.1 A region only reaches allocations in its own function *(normative limitation)*, 5.2 `region { … }`, 5.3 `workload(…)` (+1 more)

### Community 233 - "Progress"
Cohesion: 0.20
Nodes (5): Progress, Checking one file of a program, Current boundary, JSON diagnostics, Prismio IDE protocol

### Community 234 - "ir_snapshot.py"
Cohesion: 0.12
Nodes (14): Correctness, CRC-32, reflected 0xEDB88320, slicing by 8 (MB/s, higher is better), `glob_match` (eight pattern and string pairs, backtracking-heavy), Prismio in the Linux kernel: benchmarks, Reproduce, Results, Setup, What this does not show (+6 more)

### Community 235 - "neg_107_impl_trait_return_mismatch.psm"
Cohesion: 0.33
Nodes (7): main(), pick(), impl Show for A, impl Show for B, A, B, Show

### Community 236 - "test_130_list_alias_scopes.psm"
Cohesion: 0.31
Nodes (13): aliasedReceiver(), check(), digest(), growsUnderneath(), lengthObservedDuringPush(), main(), oneName(), pushBoth() (+5 more)

### Community 238 - "workspace.psm"
Cohesion: 0.08
Nodes (35): UmsCommandStepKind, BUILD, RUN, SHELL, UNKNOWN, umsCommand(), umsCommandArgument(), umsCommandFind() (+27 more)

### Community 239 - "manifest_writer.psm"
Cohesion: 0.27
Nodes (16): umsManifestAddDependency(), umsManifestAppendDependencyBlock(), umsManifestChildIndent(), umsManifestDependencyBlock(), umsManifestDependencyText(), umsManifestEscape(), umsManifestIndentAt(), umsManifestInsertDependency() (+8 more)

### Community 240 - "test_15_compiler_sim.psm"
Cohesion: 0.36
Nodes (8): compile(), create_token(), fail(), main(), parse(), tokenize(), Parser, Token

### Community 241 - "test_82_generic_layout.psm"
Cohesion: 0.42
Nodes (10): fail(), flatMatches(), genericGet(), genericSet(), instantiateNamedSet(), main(), namedMatches(), singleton() (+2 more)

### Community 242 - "PIR — Prism Semantic IR"
Cohesion: 0.14
Nodes (16): 1 · Why bodies must ship, 2.1 Not LLVM IR, 2 · Content model, 3 · Deterministic emission, 4 · Merging, 5.1 Sealed surfaces SHALL publish ownership contracts, 5 · Sealed functions, 6.1 Format versioning (+8 more)

### Community 243 - "test_53_aif_views.psm"
Cohesion: 0.53
Nodes (8): main(), scalar_read_is_not_a_view(), sum_visible(), view_escapes_by_return(), view_escapes_through_a_binding(), view_in_a_callee(), view_stays_local(), Item

### Community 244 - "test_121_guard_effect_analysis.psm"
Cohesion: 0.36
Nodes (12): bumpIt(), check(), filled(), growIt(), indirectGrow(), main(), plain(), readIt() (+4 more)

### Community 246 - "test_184_call_result_ownership.psm"
Cohesion: 0.35
Nodes (12): boxed(), expectedLength(), fail(), joined(), listed(), lookup(), main(), make() (+4 more)

### Community 247 - "test_192_callable_bounds.psm"
Cohesion: 0.29
Nodes (9): Maybe, Just, Nothing, combine(), fail(), half(), main(), twice() (+1 more)

### Community 249 - "test_42_aif_stack_promotion.psm"
Cohesion: 0.26
Nodes (14): Level 1 — T0 — **DONE, 2026-08-05**, check(), escapes(), loop_local(), main(), mixed(), mutated(), nested_in_array() (+6 more)

### Community 250 - "test_68_optional_returns.psm"
Cohesion: 0.36
Nodes (12): print(), println(), bare_none_binding_still_matches(), bound_absent_is_absent(), bound_result_is_optional(), check(), find(), main() (+4 more)

### Community 251 - "test_99_trait_coherence.psm"
Cohesion: 0.22
Nodes (7): main(), useLeft(), impl Left for Bool, impl Left for Int, impl Right for Int, Left, Right

### Community 253 - "test_257_global_arrays.psm"
Cohesion: 0.31
Nodes (8): fail(), known(), main(), sum(), letters, primes, ratios, words

### Community 255 - "test_46_aif_annotations.psm"
Cohesion: 0.38
Nodes (11): str_concat(), annotated_both(), annotated_pin(), annotated_unique(), check(), main(), names_are_not_reserved(), plain_pin() (+3 more)

### Community 256 - "test_216_for_push_guard.psm"
Cohesion: 0.31
Nodes (12): appended(), armThenTail(), branches(), digest(), down(), either(), fail(), loneFill() (+4 more)

### Community 257 - "test_155_vec_methods.psm"
Cohesion: 0.13
Nodes (21): binarySearch(), contains(), get(), indexOf(), isSorted(), removeAt(), main(), fail() (+13 more)

### Community 258 - "test_43_aif_scope_drop.psm"
Cohesion: 0.45
Nodes (10): check(), early_exits(), early_return(), escapes(), explicit(), main(), nested(), per_iteration() (+2 more)

### Community 259 - "test_50_scalar_lists.psm"
Cohesion: 0.46
Nodes (7): bools_survive(), check(), float_round_trip(), grows_past_capacity(), main(), overwrite(), sum_ints()

### Community 260 - "test_119_loop_range_guard.psm"
Cohesion: 0.57
Nodes (7): check(), filled(), main(), readWrite(), sumDown(), sumDownOffset(), sumUp()

### Community 261 - "test_29_overloads.psm"
Cohesion: 0.36
Nodes (5): choose(), combine(), combine(), fail(), main()

### Community 262 - "vec_push"
Cohesion: 0.19
Nodes (12): 1 · For 0.1: no known way to corrupt memory in a program that compiles, vec_push(), aif_argv_push(), call_fn_result_held(), call_result_held(), con_value_vs(), flow_build(), flow_edge() (+4 more)

### Community 263 - "Prismio performance benchmarks"
Cohesion: 0.10
Nodes (16): Freestanding benchmarks, Layout, Run, The arms are the same program, What is measured, and why it is not time, Currently Unsupported by Prismio, Deduplicated capabilities, Potential future benchmarks unlocked (+8 more)

### Community 264 - "neg_65_generic_trait_impl_bound.psm"
Cohesion: 0.24
Nodes (7): main(), readAny(), impl Positive for Int, impl Readable for Box, Box, Positive, Readable

### Community 265 - "neg_84_transitive_supertrait.psm"
Cohesion: 0.23
Nodes (5): impl Described for String, impl Reported for String, Described, Named, Reported

### Community 266 - "test_148_struct_index.psm"
Cohesion: 0.24
Nodes (8): fail(), main(), impl Letters, impl Squares, Holder, Letters, Squares, held

### Community 267 - "test_167_frame_struct_fields.psm"
Cohesion: 0.39
Nodes (11): assignedField(), emptyLiteralField(), fail(), inALoop(), literalFields(), main(), makeJob(), namedFields() (+3 more)

### Community 268 - "test_140_string_search.psm"
Cohesion: 0.57
Nodes (6): agrees(), checkAlphabet(), fail(), generate(), main(), naiveIndexOf()

### Community 269 - "test_66_payload_enums.psm"
Cohesion: 0.26
Nodes (11): Color, Green, Red, Shape, Circle, Dot, Rect, area() (+3 more)

### Community 270 - "test_86_impl_blocks.psm"
Cohesion: 0.30
Nodes (5): fail(), main(), impl Point, impl String, Point

### Community 271 - "test_261_failure_builtin_after_owned.psm"
Cohesion: 0.67
Nodes (6): endsInExit(), endsInPanic(), endsInUnreachable(), failsInBranch(), main(), make()

### Community 272 - "test_122_loop_local_index_term.psm"
Cohesion: 0.62
Nodes (6): assignedInBody(), check(), filled(), localDecl(), main(), trulyInvariant()

### Community 273 - "test_158_sized_arrays.psm"
Cohesion: 0.62
Nodes (6): copies(), fail(), fillThrough(), lengths(), main(), zeroed()

### Community 274 - "test_62_split_release.psm"
Cohesion: 0.53
Nodes (8): build(), cold_sum(), count_ids(), main(), make_body(), simulate(), step(), Body

### Community 275 - "aif_str"
Cohesion: 0.14
Nodes (15): aif_check_placement_pins(), aif_elem_type_at_node(), aif_fn_name(), aif_fn_symbol(), aif_nominal_name(), aif_order_symbol(), aif_profile_source(), aif_region_name_at_site() (+7 more)

### Community 276 - "test_63_placement_pin.psm"
Cohesion: 0.61
Nodes (7): arena_objects(), bracketed_make(), bracketed_pin(), fail(), lexical_pin(), main(), Cmd

### Community 277 - "test_185_view_outlives_binding.psm"
Cohesion: 0.67
Nodes (5): fail(), lastOf(), lookup(), main(), make()

### Community 278 - "test_47_aif_containers.psm"
Cohesion: 0.32
Nodes (13): build(), build_row(), check(), consumes_returned_container(), forwards(), identity(), main(), nested_containers() (+5 more)

### Community 279 - "test_44_aif_region.psm"
Cohesion: 0.33
Nodes (13): arena_objects(), arena_regions(), str_concat(), breaks_out(), check(), escapes_inner(), inside(), main() (+5 more)

### Community 280 - "Debugging Prismio programs"
Cohesion: 0.18
Nodes (10): Debugging Prismio programs, Part 1 — `-g`, Part 2 — where the memory went, and why, See also, The storage plan — where each site went, `--verify` — did the inference hold?, What `-g` will not tell you, and why, Which tool answers which question (+2 more)

### Community 281 - "install.sh"
Cohesion: 0.19
Nodes (15): banner(), done_working(), error(), fatal(), fetch(), fetch_archive(), main(), row() (+7 more)

### Community 282 - "namelist_contains"
Cohesion: 0.25
Nodes (10): ir_declare_named_type(), ir_is_borrowed(), ir_is_global_name(), ir_is_moved(), ir_mark_borrowed(), ir_mark_moved(), ir_named_type_kind(), ir_register_global_name() (+2 more)

### Community 283 - "neg_66_overlapping_generic_trait_impl.psm"
Cohesion: 0.24
Nodes (5): impl Positive for Int, impl Readable for Box, Box, Positive, Readable

### Community 284 - "neg_93_ambiguous_trait_method.psm"
Cohesion: 0.27
Nodes (6): main(), impl Loud for Dog, impl Soft for Dog, Dog, Loud, Soft

### Community 285 - "neg_94_wrong_trait_qualifier.psm"
Cohesion: 0.29
Nodes (6): main(), impl Loud for Dog, impl Soft for Dog, Dog, Loud, Soft

### Community 286 - "test_05_enums.psm"
Cohesion: 0.20
Nodes (10): Color, Blue, Green, Red, ExitCode, Ok, ParseError, RuntimeError (+2 more)

### Community 287 - "test_106_associated_constants.psm"
Cohesion: 0.29
Nodes (7): fail(), main(), impl Bounded for Dial, impl Bounded for Gauge, Dial, Gauge, Bounded

### Community 289 - "test_129_enum_null_ownership.psm"
Cohesion: 0.29
Nodes (10): OwnedTree, Empty, Node, SharedEmpty, Empty, Node, build(), isEmpty() (+2 more)

### Community 290 - "test_179_proved_index_nsw.psm"
Cohesion: 0.38
Nodes (10): ascending(), check(), knapsack(), knapsackLet(), lookedUp(), main(), offsetBack(), rotated() (+2 more)

### Community 291 - "test_231_cold_functions.psm"
Cohesion: 0.35
Nodes (8): clamp(), cold(), failWith(), lengthOr(), main(), sumSquares(), impl Counter, Counter

### Community 292 - "aifEmitSummary"
Cohesion: 0.17
Nodes (13): aif_bracketable_region_call_sites(), aif_call_edge_count(), aif_con_count(), aif_fn_count(), aif_nominal_acyclic(), aif_nominal_count(), aif_nominal_is_struct(), aif_region_call_sites() (+5 more)

### Community 293 - "main"
Cohesion: 0.18
Nodes (20): volatileLoadU16(), volatileLoadU32(), calloc(), free(), malloc(), bump(), fail(), init() (+12 more)

### Community 294 - ".spawn"
Cohesion: 0.12
Nodes (21): benchStringJoin(), 1 · Headline findings, 2.1 The invariant needs a boundary the spec does not currently draw, 2.2 Structs are affine references, not values, 2 · Frozen items, one by one, 3.1 What isn't behind the seam at all, 3 · The seam, precisely, 6 · Spec changes this analysis forces (+13 more)

### Community 295 - "ptr_access_ir_probe.psm"
Cohesion: 0.12
Nodes (4): plainField(), volatileFieldRead(), volatileFieldWrite(), Regs

### Community 299 - "test_14_multi_args.psm"
Cohesion: 0.67
Nodes (6): add3(), add4(), add5(), fail(), main(), nested_calls()

### Community 300 - "3 · Steps"
Cohesion: 0.12
Nodes (18): 1 · Where `src/` stands, 2 · How a step is measured, 3 · Steps, 4 · Order, Left as it is, M11 · `prismio bench` must not report stale numbers: done in the working tree, uncommitted, M12 · Constant aggregate globals: language gap, not started, M1 · `match` for enum if-chains: done in the working tree, uncommitted (+10 more)

### Community 301 - "test_25_conventions.psm"
Cohesion: 0.67
Nodes (6): bump(), consume(), fail(), main(), peek(), Counter

### Community 302 - "Known issues"
Cohesion: 0.25
Nodes (8): A struct pushed into a Vec in a loop (`test_164_array_fields`), `benchmarks/hosted/prismio/suite.psm`, in the default (owned) model, Freestanding and the Linux kernel, `heapsort` is the one freestanding row behind C, by 1.9%, Known issues, Platform, The AIF analysis and its oracle, Traits

### Community 303 - "dump.psm"
Cohesion: 0.47
Nodes (9): dumpAstJson(), dumpChain(), dumpFileTable(), dumpNode(), hexDigit(), jsonFieldInt(), jsonFieldStr(), jsonString() (+1 more)

### Community 304 - "test_287_multi_statement_fill.psm"
Cohesion: 0.41
Nodes (13): capacityOf(), fail(), filters(), growth(), main(), overran(), pairs(), populated() (+5 more)

### Community 305 - "test_268_struct_pass_through.psm"
Cohesion: 0.67
Nodes (6): check(), main(), pickBound(), pickHeld(), Holder, Point

### Community 306 - "test_277_guard_dyn_call.psm"
Cohesion: 0.43
Nodes (5): main(), walk(), impl Grower for Pusher, Pusher, Grower

### Community 307 - "xcalloc"
Cohesion: 0.14
Nodes (38): M9 · AIF arena-placement cost: done in the working tree, uncommitted, M9 · AIF arena-placement cost: done in the working tree, uncommitted, ctz64(), xcalloc(), aif_bracketable_region_call_sites(), aif_fn_bracket_blockers(), aif_fn_bracket_hard_blockers(), bits_any() (+30 more)

### Community 309 - "test_285_deferred_initialization.psm"
Cohesion: 0.24
Nodes (13): Color, Blue, Green, Red, early(), fail(), firstBig(), grade() (+5 more)

### Community 310 - "test_193_map_methods.psm"
Cohesion: 0.36
Nodes (6): fail(), keyName(), main(), impl Copy for Clash, impl Key for Clash, Clash

### Community 311 - "umsLex"
Cohesion: 0.35
Nodes (6): umsIsAlnum(), umsIsAlpha(), umsIsDigit(), umsLex(), impl UmsLexer, UmsLexer

### Community 312 - "harness.c"
Cohesion: 0.21
Nodes (8): exit_emulator(), harness_main(), memcpy(), memmove(), put(), put_str(), put_u64(), ticks()

### Community 313 - "test_57_pin_tiers.psm"
Cohesion: 0.53
Nodes (9): print(), println(), boxed_elements(), counted_but_uncounted(), counted_elements(), deliberate_pessimisation(), fail(), main() (+1 more)

### Community 314 - "test_48_aif_shared_elements.psm"
Cohesion: 0.49
Nodes (9): borrow_into_temp(), check(), main(), overwrite_releases(), shared_between_containers(), spread(), survives_first_release(), two_hops() (+1 more)

### Community 315 - "test_84_task_release.psm"
Cohesion: 0.56
Nodes (9): print(), println(), check(), copied_handle(), join_inside_a_loop(), main(), many_frames(), simulate() (+1 more)

### Community 316 - "format_ns"
Cohesion: 0.15
Nodes (5): elimination_cell(), elimination_row(), format_ns(), FreestandingUI, RusagePopen

### Community 317 - "test_113_std_eq_and_display.psm"
Cohesion: 0.28
Nodes (9): describe(), fail(), main(), same(), impl Display for Colour, impl Eq for Colour, impl Ord for Version, Colour (+1 more)

### Community 318 - "test_163_array_return.psm"
Cohesion: 0.35
Nodes (9): bytes(), fail(), id(), main(), make(), pair(), total(), impl Grid (+1 more)

### Community 319 - "node_args_find"
Cohesion: 0.25
Nodes (8): aif_arg_copies_view(), aif_call_arg_outlives_call(), aif_call_arg_retained(), aif_note_arg_aliased(), aif_note_arg_copied(), aif_note_arg_retained(), aif_note_call_args(), node_args_find()

### Community 320 - "test_73_recursive_release.psm"
Cohesion: 0.40
Nodes (9): Tree, Leaf, Node, depth(), fail(), main(), makeDeep(), makeTree() (+1 more)

### Community 322 - "test_288_remainder_steps.psm"
Cohesion: 0.30
Nodes (11): checksumBoth(), checksumValue(), edge(), fail(), identity(), main(), nested(), notKept() (+3 more)

### Community 323 - "test_166_for_each_collections.psm"
Cohesion: 0.36
Nodes (6): countdown(), fail(), main(), impl Iterator for Countdown, Countdown, Shelf

### Community 324 - "7 · Specialisation strategy and dedup"
Cohesion: 0.25
Nodes (8): 7.0.1 Three strategies, 7.0.2 Dedup still applies, 7.0 The ownership-divergence ratio, 7.1 Layer 1 — the relevant-parameter mask *(pre-instantiation, cheapest, does the most work)*, 7.2 Layer 2 — semantic equivalence *(pre-codegen)*, 7.3 Layer 3 — structural dedup *(post-codegen)*, 7.4 Budget-driven collapse, 7 · Specialisation strategy and dedup

### Community 327 - "neg_291_typed_ptr_refused.psm"
Cohesion: 0.24
Nodes (10): dropVolatile(), fromOpaque(), gain(), holder(), opaque(), owned(), retype(), Header (+2 more)

### Community 328 - "test_279_nested_functions.psm"
Cohesion: 0.40
Nodes (7): fail(), main(), outer(), scoped(), second(), impl Counter, Counter

### Community 329 - "4 · Prerequisites nobody has costed"
Cohesion: 0.40
Nodes (5): 4.1 A pass between sema and codegen, 4.2 Scope-based drop, 4.3 Prismio cannot express its own solver, 4.4 Compile time, 4 · Prerequisites nobody has costed

### Community 330 - "test_191_option_methods.psm"
Cohesion: 0.52
Nodes (6): fail(), findLiteral(), findOwned(), halfOf(), main(), parse()

### Community 331 - "kernel_i686.psm"
Cohesion: 0.22
Nodes (10): portInU8(), portOutU8(), volatileLoadU8(), halt(), main(), prismio_panic_hook(), put_int(), put() (+2 more)

### Community 332 - "freestanding/prismio/compute.psm"
Cohesion: 0.12
Nodes (6): bench_sha256(), rotr(), COUNTER, LOCK, REGISTERS, WORD

### Community 333 - "text.psm"
Cohesion: 0.10
Nodes (25): typeInstancesAsWritten(), typeInstanceWord(), typeKeyNameEndsAt(), isIdentPart(), isIdentStart(), isOperator(), isSeparator(), confusablePrototype() (+17 more)

### Community 334 - "neg_57_second_bound_not_satisfied.psm"
Cohesion: 0.36
Nodes (5): activeScore(), main(), impl Scored for Int, Enabled, Scored

### Community 335 - "neg_68_blanket_trait_impl.psm"
Cohesion: 0.31
Nodes (4): impl Named for Dog, impl Named for T, Dog, Named

### Community 336 - "range_direction_probe.psm"
Cohesion: 0.58
Nodes (8): counted(), eitherWay(), endBeforeCount(), lengthUp(), literalDown(), literalUp(), main(), mark()

### Community 337 - "fclose"
Cohesion: 0.06
Nodes (34): 2 · What the runtime needs, measured, compiler_host_stamp_matches(), compiler_host_stamp_write(), compiler_plib_interface(), emit_stdlib_plib(), extract_plib_bitcode(), file_content_hash(), host_identity() (+26 more)

### Community 338 - "test_144_sort_inline_elements.psm"
Cohesion: 0.42
Nodes (8): fail(), freshSeen(), main(), rnd(), Named, Pt, Small, Wide

### Community 340 - "test_51_optional_refs.psm"
Cohesion: 0.42
Nodes (10): check(), depth_of_chain(), main(), presence_is_visible(), unwrap_is_not_a_move(), zero_first_field_is_still_present(), Carrier, Holder (+2 more)

### Community 341 - "test_171_default_values.psm"
Cohesion: 0.42
Nodes (8): fail(), fresh(), made(), main(), zero(), Box, Inner, Outer

### Community 342 - "test_143_string_compare.psm"
Cohesion: 0.36
Nodes (6): impl Ord for String, agrees(), fail(), main(), referenceOrder(), sign()

### Community 343 - "test_22_match.psm"
Cohesion: 0.33
Nodes (8): Color, Blue, Green, Red, classify(), describe(), fail(), main()

### Community 344 - "boot_aarch64_virt.c"
Cohesion: 0.61
Nodes (6): kernel_start(), prismio_panic_hook(), put(), put_int(), put_str(), semihost_exit()

### Community 346 - "test_291_typed_ptr_types.psm"
Cohesion: 0.12
Nodes (14): impl Broken for String, Broken, Mode, Busy, Idle, absent(), eitherOrder(), forget() (+6 more)

### Community 347 - "prismio"
Cohesion: 0.05
Nodes (39): Before opening a pull request, Building the compiler, Code of Conduct, Commit Messages, Contributing to Prismio, Getting Started, If you changed the syntax, Making Changes (+31 more)

### Community 348 - "bootstrap.sh"
Cohesion: 0.42
Nodes (7): cache_entry(), die(), green(), hash_stdin(), bootstrap.sh script, resolve_llvm(), step()

### Community 350 - "test_124_whole_buffer_copy.psm"
Cohesion: 0.32
Nodes (11): check(), copyAll(), copyAllFor(), copyBytes(), copyFloats(), copyFrom(), copyFromFor(), copyRounds() (+3 more)

### Community 351 - "nowrapExpr"
Cohesion: 0.21
Nodes (16): ir_nowrap_mark(), ir_nowrap_marked(), nowrapAccessed(), nowrapArith(), nowrapAssign(), nowrapExpr(), nowrapInterval(), nowrapIsIntName() (+8 more)

### Community 352 - "run_array_nowrap_test"
Cohesion: 0.22
Nodes (4): nsw_sources(), run_array_contents_test(), sources(), run_array_nowrap_test()

### Community 353 - "[0.2.0] - Unreleased"
Cohesion: 0.33
Nodes (5): [0.2.0] - Unreleased, Changelog, Documentation, Fixed, Repository

### Community 355 - "getenv"
Cohesion: 0.06
Nodes (36): 1 · Fix first, build_trace_enabled(), compiler_is_hosted(), compiler_pending_arguments(), inline_runtime_enabled(), program_opt_level(), toolchain_cache_disabled(), toolchain_cache_report() (+28 more)

### Community 356 - "main"
Cohesion: 0.19
Nodes (12): forEach(), fail(), filter(), main(), impl Parser, Parser, add(), each() (+4 more)

### Community 358 - "test_126_push_predication.psm"
Cohesion: 0.38
Nodes (10): check(), digest(), fillBreak(), fillExact(), fillGrowing(), fillOneShort(), fillPair(), fillSparse() (+2 more)

### Community 359 - "test_186_view_pushed_directly.psm"
Cohesion: 0.70
Nodes (4): fail(), lookup(), main(), make()

### Community 360 - "layout_c.psm"
Cohesion: 0.70
Nodes (4): main(), Both, Gate, Wire

### Community 363 - "kernel_aarch64.psm"
Cohesion: 0.83
Nodes (3): main(), sum(), Pair

### Community 364 - "test_52_aif_cycle_collector.psm"
Cohesion: 0.38
Nodes (11): The T4b cycle collector — **DONE, 2026-08-07**, cyc_collect_now(), node_to_ptr(), ptr_to_node(), build_cycle(), check(), collected_when_unreachable(), live_cycle_survives() (+3 more)

### Community 365 - "mem.psm"
Cohesion: 0.07
Nodes (38): bench_mem_copy(), mem_alloc(), mem_alloc_zeroed(), mem_bytes_data(), mem_bytes_equal(), mem_compare(), mem_copy(), mem_fill() (+30 more)

### Community 366 - "test_283_numeric_fluency.psm"
Cohesion: 0.38
Nodes (6): digits(), fail(), main(), CELLS, N, SHIFTED

### Community 369 - "test_47_aif_minimal_cause.psm"
Cohesion: 0.54
Nodes (7): str_concat(), boxed(), check(), direct(), local(), main(), Box

### Community 370 - "math.psm"
Cohesion: 0.18
Nodes (5): impl Isize, impl Usize, main(), impl Square, Square

### Community 373 - "test_runner.py"
Cohesion: 0.07
Nodes (21): A string literal in a curated runtime function breaks the link, compile_prismio_file(), expected_errors(), preserved_project_host(), progress(), project_host_lock(), project_host_profile(), run_cli_usage_test() (+13 more)

### Community 376 - "main"
Cohesion: 0.32
Nodes (12): calloc(), free(), malloc(), doubled(), fail(), flags(), main(), readBack() (+4 more)

### Community 379 - "range_proof_entry_or_new"
Cohesion: 0.16
Nodes (14): ir_nowrap_mark(), ir_nowrap_marked(), ir_nowrap_of(), ir_range_proof_data(), ir_range_proof_mark(), ir_range_proof_marked(), ir_range_proof_of(), ir_rem_form_mark() (+6 more)

### Community 381 - "neg_195_callable_bound.psm"
Cohesion: 0.39
Nodes (6): Maybe, Just, Nothing, apply(), main(), impl Maybe

### Community 383 - "test_89_closures.psm"
Cohesion: 0.18
Nodes (14): reverse(), sort(), main(), fail(), fill(), grow(), main(), total() (+6 more)

### Community 384 - "BenchSphere"
Cohesion: 0.25
Nodes (8): BenchSphere, cb, cg, cr, r, x, y, z

### Community 385 - "test_64_generics.psm"
Cohesion: 0.36
Nodes (8): boxUp(), fail(), firstOr(), identity(), main(), Box, Node, Pair

### Community 387 - "neg_101_dyn_self_not_object_safe.psm"
Cohesion: 0.36
Nodes (4): f(), impl Dup for D, D, Dup

### Community 388 - "neg_104_dyn_returned.psm"
Cohesion: 0.39
Nodes (4): make(), impl Show for Dog, Dog, Show

### Community 389 - "consts.psm"
Cohesion: 0.38
Nodes (12): typeIntLiteralValue(), constBinary(), constEvaluate(), constFailed(), constGlobal(), constMaxDepth(), constName(), constOf() (+4 more)

### Community 390 - "neg_241_optional_impl_overlap.psm"
Cohesion: 0.32
Nodes (3): impl Dup for Int, impl Dup for T, Dup

### Community 391 - "neg_45_bound_not_satisfied.psm"
Cohesion: 0.39
Nodes (5): main(), maxOf(), impl Ord for Int, Point, Ord

### Community 392 - "neg_58_second_bound_not_trait.psm"
Cohesion: 0.39
Nodes (5): main(), scoreWith(), impl Scored for Int, Bag, Scored

### Community 393 - "neg_82_missing_supertrait.psm"
Cohesion: 0.32
Nodes (3): impl Described for String, Described, Named

### Community 394 - "neg_91_unknown_projection.psm"
Cohesion: 0.43
Nodes (5): main(), pick(), impl Container for Bag, Bag, Container

### Community 395 - "neg_92_equality_constraint.psm"
Cohesion: 0.43
Nodes (5): intOnly(), main(), impl Container for Sack, Sack, Container

### Community 396 - "test_01_variables.psm"
Cohesion: 0.36
Nodes (7): bump_global(), fail(), main(), test_arithmetic(), x, y, z

### Community 397 - "test_04_structs.psm"
Cohesion: 0.46
Nodes (7): punned_to_ptr(), fail(), main(), Counter, Point, Punned, Vector

### Community 398 - "test_100_reuse_token.psm"
Cohesion: 0.46
Nodes (7): Tree, Leaf, Node, exit(), main(), mapAdd(), rootValue()

### Community 399 - "test_100_string_append_reuse.psm"
Cohesion: 0.46
Nodes (7): contaminated_site(), fail(), formatted_append(), main(), repeated_append(), self_append(), view_append()

### Community 401 - "raw.psm"
Cohesion: 0.04
Nodes (11): AtomicOrder, AcqRel, Acquire, Relaxed, Release, SeqCst, atomicCompareExchangeU32(), volatileStoreU8() (+3 more)

### Community 402 - "test_156_index_store.psm"
Cohesion: 0.54
Nodes (7): arrays(), fail(), main(), strings(), throughParameter(), vectors(), Pt

### Community 404 - "test_278_condition_syntax.psm"
Cohesion: 0.73
Nodes (5): fail(), main(), origin(), same(), Point

### Community 405 - "adversarial.cpp"
Cohesion: 0.10
Nodes (33): adversarial_next(), AdversarialObject, a, b, c, d, allocation_escape(), branch_mispredict() (+25 more)

### Community 406 - "test_275_line_start_paren.psm"
Cohesion: 0.67
Nodes (4): main(), step(), impl Counter, Counter

### Community 408 - "test_59_bracket_summary.psm"
Cohesion: 0.44
Nodes (9): print(), println(), bracketable(), drops(), fail(), main(), middle(), stores_param() (+1 more)

### Community 410 - "test_85_passthrough_escape.psm"
Cohesion: 0.64
Nodes (7): band(), escaping(), escapingNested(), fail(), main(), passthru(), Band

### Community 412 - "use_it"
Cohesion: 1.00
Nodes (3): main(), use_it(), Wide

### Community 418 - "test_123_loop_range_guard_wrap.psm"
Cohesion: 0.53
Nodes (8): check(), filled(), main(), runAwayDown(), runAwayUp(), strideTwo(), wrapDown(), wrapUp()

### Community 420 - "test_139_string_chain_append.psm"
Cohesion: 0.83
Nodes (3): digitsOf(), fail(), main()

### Community 422 - "neg_294_ptr_reads_refused.psm"
Cohesion: 0.31
Nodes (4): missing(), slot(), whole(), Header

### Community 423 - "test_187_properties.psm"
Cohesion: 0.42
Nodes (5): fail(), main(), impl Rect, perimeter(), Rect

### Community 426 - "loop_named"
Cohesion: 0.40
Nodes (5): ir_loop_break_label_named(), ir_loop_continue_label_named(), ir_loop_drop_floor_named(), ir_loop_region_depth_named(), loop_named()

### Community 427 - "test_94_selective_imports.psm"
Cohesion: 0.47
Nodes (3): shoutUpper(), fail(), main()

### Community 428 - "test_280_closure_blocks.psm"
Cohesion: 0.70
Nodes (4): each(), fail(), main(), run()

### Community 429 - "test_80_data_view_conversion.psm"
Cohesion: 0.57
Nodes (7): columnCount(), columnsAreReadable(), fail(), main(), mutateColumns(), Pair, Sample

### Community 431 - "test_77_spawn_literal.psm"
Cohesion: 0.70
Nodes (4): fail(), main(), measure(), measureBoth()

### Community 434 - "Shape"
Cohesion: 0.38
Nodes (6): Shape, Circle, Dot, Rect, area(), main()

### Community 435 - "neg_44_impl_generic.psm"
Cohesion: 0.38
Nodes (3): impl Readable for Box, Box, Readable

### Community 437 - "neg_67_generic_trait_conformance.psm"
Cohesion: 0.43
Nodes (3): impl Choice for Box, Box, Choice

### Community 438 - "neg_69_generic_trait_method_parameter.psm"
Cohesion: 0.38
Nodes (3): impl Valued for Box, Box, Valued

### Community 439 - "neg_72_missing_bound_trait_argument.psm"
Cohesion: 0.43
Nodes (4): main(), requireFrom(), impl From for String, From

### Community 440 - "neg_73_trait_argument_bound_mismatch.psm"
Cohesion: 0.43
Nodes (4): main(), requireFromInt(), impl From for String, From

### Community 444 - "neg_80_where_bound_not_satisfied.psm"
Cohesion: 0.43
Nodes (4): main(), render(), impl Show for Int, Show

### Community 445 - "neg_89_missing_associated_type.psm"
Cohesion: 0.38
Nodes (3): impl Container for Bag, Bag, Container

### Community 446 - "neg_96_trait_inout_not_honoured.psm"
Cohesion: 0.38
Nodes (3): impl Update for Cell, Cell, Update

### Community 447 - "owned_return_depth2.psm"
Cohesion: 0.52
Nodes (6): str_with_capacity(), depthOne(), depthTwo(), main(), pieceDepthOne(), pieceDepthTwo()

### Community 448 - "owned_temporary_argument.psm"
Cohesion: 0.57
Nodes (6): abs(), band(), drive(), main(), simulate(), Band

### Community 449 - "recursive_enum_bindings_probe.psm"
Cohesion: 0.57
Nodes (6): Expr, Leaf, build(), buildMixed(), main(), sum()

### Community 450 - "test_294_ptr_overloads.psm"
Cohesion: 0.39
Nodes (8): calloc(), free(), main(), size(), size(), size(), A, B

### Community 452 - "test_125_stencil_range_guard.psm"
Cohesion: 0.62
Nodes (6): check(), filled(), main(), neverRuns(), shiftedPastEnd(), stencil()

### Community 453 - "test_138_shadowing.psm"
Cohesion: 0.52
Nodes (6): compare(), concat(), fail(), isDigit(), main(), trim()

### Community 454 - "test_13_globals.psm"
Cohesion: 0.38
Nodes (6): fail(), main(), use_globals(), BUFFER_SIZE, global_counter, MAX_TOKENS

### Community 455 - "kernel_pure_aarch64.psm"
Cohesion: 0.11
Nodes (24): 1. Publish a seed that parses `src/` (needs the user's go-ahead), 3. The IntelliJ plugin (`../intellij-plugin`), 4. `Vec.length` and the integer types (after the plugin, per the user), 5. Smaller items, Hazards learned, Next session, in order, Visibility, numeric fluency and what is left, Where things stand (+16 more)

### Community 456 - "test_259_display_print.psm"
Cohesion: 0.43
Nodes (6): child(), fail(), main(), maybeName(), impl Display for Version, Version

### Community 457 - "test_72_reassigned_ownership.psm"
Cohesion: 0.36
Nodes (10): borrow_reassign(), callee_accumulator(), cloned_literal_keeps_length(), literal_mid_loop(), local_accumulator(), main(), makePiece(), returned_accumulator() (+2 more)

### Community 458 - "test_162_removal_parks_under_view.psm"
Cohesion: 0.67
Nodes (6): count(), early(), kept(), lent(), main(), word()

### Community 459 - "test_19_runtime_split.psm"
Cohesion: 0.52
Nodes (6): command_quote_arg(), executable_directory(), file_exists(), join_path(), fail(), main()

### Community 461 - "test_38_scoping.psm"
Cohesion: 0.43
Nodes (6): fail(), main(), reads_global(), shadows_param(), counter, label

### Community 462 - "test_61_layout_cost_model.psm"
Cohesion: 0.67
Nodes (6): advance(), build(), main(), make(), settle(), Sample

### Community 463 - "test_74_reinit_assignment.psm"
Cohesion: 0.38
Nodes (10): Tree, Leaf, Node, build(), consumeStr(), fail(), main(), mapAdd() (+2 more)

### Community 469 - "test_32_sized_int_modulo.psm"
Cohesion: 0.67
Nodes (3): fail(), main(), greeting

### Community 470 - "test_53_memory_budget.psm"
Cohesion: 1.00
Nodes (3): main(), use_it(), Wide

### Community 474 - "kernel_float_aarch64.psm"
Cohesion: 0.50
Nodes (4): check(), main(), HEAP_BASE, heapTop

### Community 483 - "ir_loop_label"
Cohesion: 0.67
Nodes (3): ir_loop_drop_floor(), ir_loop_label(), ir_loop_region_depth()

### Community 485 - "neg_109_impl_trait_bound.psm"
Cohesion: 0.53
Nodes (4): main(), make(), NoShow, Show

### Community 486 - "neg_161_index_store_refused.psm"
Cohesion: 0.53
Nodes (4): main(), impl Squares, Cell, Squares

### Community 487 - "Process"
Cohesion: 0.29
Nodes (9): proc_exec(), proc_spawn_begin(), impl Process, Process, again(), fail(), main(), readStdin() (+1 more)

### Community 488 - "Color"
Cohesion: 0.40
Nodes (4): Color, Green, Red, Pen

### Community 489 - "Shape"
Cohesion: 0.47
Nodes (5): Shape, Circle, Dot, f(), main()

### Community 500 - "test_10_expressions.psm"
Cohesion: 0.60
Nodes (5): compare_expression(), eval_expression(), fail(), main(), nested_expressions()

### Community 501 - "test_142_sort_patterns.psm"
Cohesion: 0.73
Nodes (5): checkInts(), fail(), main(), rnd(), shape()

### Community 503 - "test_16_arrays.psm"
Cohesion: 0.60
Nodes (5): array_edges(), array_sum(), fail(), main(), matrix_diagonal()

### Community 504 - "test_174_slice_mut.psm"
Cohesion: 0.60
Nodes (5): fail(), head(), main(), poke(), total()

### Community 505 - "test_217_vec_filled.psm"
Cohesion: 0.60
Nodes (4): fail(), main(), impl Copy for Point, Point

### Community 506 - "test_21_loops.psm"
Cohesion: 0.60
Nodes (5): count_to(), fail(), main(), nested(), skip_evens()

### Community 507 - "test_26_borrow_reuse.psm"
Cohesion: 0.73
Nodes (5): fail(), main(), read1(), read2(), Res

### Community 508 - "test_73_recursive_release_depth.psm"
Cohesion: 0.47
Nodes (5): Chain, End, Link, buildChain(), main()

### Community 509 - "test_88_single_loop_inline.psm"
Cohesion: 0.60
Nodes (5): cold(), crowded_a(), crowded_b(), hot(), main()

### Community 510 - "run_remainder_steps_codegen_test"
Cohesion: 0.67
Nodes (3): run_remainder_steps_codegen_test(), body(), srem_by()

### Community 520 - "aif_concurrency_shared.psm"
Cohesion: 0.80
Nodes (4): count_items(), main(), shared_element_crosses(), Item

### Community 521 - "extern_alias_escape.psm"
Cohesion: 0.70
Nodes (4): prismio_expect(), main(), make(), passthru()

### Community 525 - "neg_187_bare_type_function.psm"
Cohesion: 0.70
Nodes (3): main(), impl Config, Config

### Community 526 - "Color"
Cohesion: 0.40
Nodes (3): Color, Green, Red

### Community 527 - "Color"
Cohesion: 0.40
Nodes (3): Color, Green, Red

### Community 528 - "Result"
Cohesion: 0.50
Nodes (4): Result, Err, Ok, main()

### Community 530 - "scoreWith"
Cohesion: 0.70
Nodes (3): main(), scoreWith(), Scored

### Community 534 - "neg_81_where_bound_not_trait.psm"
Cohesion: 0.50
Nodes (3): main(), render(), Show

### Community 535 - "pointer_return_temp.psm"
Cohesion: 0.70
Nodes (4): main(), make(), wrap(), Box

### Community 536 - "recursive_optional_probe.psm"
Cohesion: 0.80
Nodes (4): main(), make(), total(), Node

### Community 537 - "test_02_if_else.psm"
Cohesion: 0.70
Nodes (4): fail(), main(), max(), test_nested_if()

### Community 538 - "test_03_while_loops.psm"
Cohesion: 0.70
Nodes (4): factorial(), fail(), main(), sum_to_n()

### Community 539 - "test_06_recursion.psm"
Cohesion: 0.70
Nodes (4): fail(), fibonacci(), gcd(), main()

### Community 540 - "test_07_booleans.psm"
Cohesion: 0.70
Nodes (4): fail(), is_between(), main(), test_equal()

### Community 541 - "test_08_mutability.psm"
Cohesion: 0.70
Nodes (4): fail(), main(), test_complex_mutation(), test_mutation()

### Community 542 - "test_11_returns.psm"
Cohesion: 0.70
Nodes (4): classify_number(), early_return(), fail(), main()

### Community 543 - "test_149_list_literal.psm"
Cohesion: 0.70
Nodes (4): fail(), main(), total(), Job

### Community 544 - "test_161_removal_releases_now.psm"
Cohesion: 0.70
Nodes (4): churn(), churnWord(), digits(), main()

### Community 545 - "test_18_floats.psm"
Cohesion: 0.70
Nodes (4): blended(), comparisons(), fail(), main()

### Community 546 - "test_206_nested_loop_breaks.psm"
Cohesion: 0.70
Nodes (4): fail(), firstAtLeast(), main(), rounds()

### Community 547 - "test_23_move.psm"
Cohesion: 0.80
Nodes (4): fail(), main(), sum(), Point

### Community 548 - "test_33_unary_operators.psm"
Cohesion: 0.60
Nodes (4): fail(), identity(), main(), neg_global

### Community 550 - "test_41_punned_slot_bytes.psm"
Cohesion: 0.80
Nodes (4): node_to_ptr(), main(), reads_as_empty(), Slot

### Community 551 - "test_93_data_view_from_helper.psm"
Cohesion: 0.80
Nodes (4): advance(), buildRows(), main(), Row

### Community 552 - "test_95_literal_tbaa.psm"
Cohesion: 0.70
Nodes (4): fail(), main(), Assigned, Initialised

### Community 554 - "4 · Transfer rules"
Cohesion: 0.25
Nodes (8): 4.1 Escape module, 4.2 Aliasing module, 4.3 Thread module, 4.4 Cyclicity module, 4.5 Closure capture, 4.6 Dynamic dispatch, 4.7 Generics and ownership contexts, 4 · Transfer rules

### Community 556 - "test_235_channel_owned_messages.psm"
Cohesion: 0.61
Nodes (7): closedSendsRelease(), fail(), main(), receivedNotesRelease(), receivedVecsRelease(), shortStringsArriveIntact(), Note

### Community 557 - "aif_loop_bracket.psm"
Cohesion: 0.83
Nodes (3): main(), perIteration(), wholeCall()

### Community 558 - "fixture_slice_escape.psm"
Cohesion: 0.83
Nodes (3): escaping_slice(), main(), Item

### Community 559 - "neg_05_drop_borrow.psm"
Cohesion: 1.00
Nodes (3): leak(), main(), Res

### Community 563 - "neg_160_empty_literal_untyped.psm"
Cohesion: 0.83
Nodes (3): count(), countAny(), main()

### Community 566 - "neg_198_array_type_argument.psm"
Cohesion: 0.83
Nodes (3): boxed(), main(), Box

### Community 567 - "neg_22_push_borrowed_element.psm"
Cohesion: 1.00
Nodes (3): hold(), main(), Item

### Community 569 - "neg_24_unique_aliased_args.psm"
Cohesion: 1.00
Nodes (3): bump(), main(), Buf

### Community 571 - "neg_26_placement_pin_refuted.psm"
Cohesion: 0.83
Nodes (3): main(), make(), Cmd

### Community 573 - "neg_48_bound_not_a_trait.psm"
Cohesion: 1.00
Nodes (3): main(), passthrough(), Bag

### Community 578 - "neg_97_nonterminating_instantiation.psm"
Cohesion: 0.67
Nodes (3): grow(), main(), Box

### Community 579 - "target_cross.psm"
Cohesion: 0.83
Nodes (3): main(), Mixed, Span

### Community 580 - "test_296_ptr_address.psm"
Cohesion: 0.46
Nodes (7): calloc(), free(), malloc(), fail(), main(), Header, Packet

### Community 581 - "test_134_print_arguments.psm"
Cohesion: 0.83
Nodes (3): fail(), main(), step()

### Community 583 - "test_145_list_set_within_list.psm"
Cohesion: 0.83
Nodes (3): fail(), main(), Pt

### Community 584 - "test_159_vec_binding_empty.psm"
Cohesion: 0.83
Nodes (3): fail(), main(), Item

### Community 585 - "test_160_i32_alias.psm"
Cohesion: 0.83
Nodes (3): main(), twice(), Point

### Community 586 - "test_180_descending_ranges.psm"
Cohesion: 0.83
Nodes (3): fail(), main(), trail()

### Community 587 - "run_module_artifact_test"
Cohesion: 0.33
Nodes (3): plib_sections(), run_module_artifact_test(), run_plib_triple_sections()

### Community 588 - "test_24_drop.psm"
Cohesion: 0.83
Nodes (3): fail(), main(), Point

### Community 589 - "test_28_list.psm"
Cohesion: 0.83
Nodes (3): fail(), main(), Item

### Community 590 - "test_31_strings_in_control_flow.psm"
Cohesion: 0.83
Nodes (3): fail(), label_for(), main()

### Community 592 - "test_40_annotated_arrays.psm"
Cohesion: 0.83
Nodes (3): exit(), fail(), main()

### Community 593 - "Particle"
Cohesion: 0.33
Nodes (6): Particle, life, vx, vy, x, y

### Community 594 - "5. Ownership, handles, and globals"
Cohesion: 0.33
Nodes (6): 5. Ownership, handles, and globals, Globals holding handles need no initializer, Handles are `Ptr`, Strings and structs are affine, Test pointer absence with pointer helpers, The old string-punning invariant is retired

### Community 595 - "3 · The tier ladder"
Cohesion: 0.33
Nodes (6): 3 · The tier ladder, T0 — Value / stack, T1 — Region / arena, T2 — Unique owned, T3 — Shared, non-atomic reference counting, T4 — Managed residue

### Community 596 - "refresh_seed.sh"
Cohesion: 0.67
Nodes (3): die(), PRISMIO_SEED_IR, refresh_seed.sh script

### Community 597 - "5.4 `pin`"
Cohesion: 0.33
Nodes (6): 5.4.1 A proven-false pin is a compile error, 5.4.2 An unproven pin is never an error, 5.4.3 Strictness is opt-in, per value, 5.4.4 The direction limit *(normative)*, 5.4.5 `pin(<region-name>)` — the placement form *(normative)*, 5.4 `pin`

### Community 598 - "7 · Two-speed compilation"
Cohesion: 0.33
Nodes (6): 7.1 Requirement, 7.2 Levels, 7.3 `verify` — facts as runtime assertions, 7.4 Layout search is opt-in, 7.5 Levels are per module, not per build, 7 · Two-speed compilation

### Community 618 - "11 · Conformance boundary"
Cohesion: 0.40
Nodes (5): 11.0 Conformance levels, 11 · Conformance boundary, Annotation governance, Frozen — normative, Open — by descending risk

### Community 622 - "2 · The objects of the model"
Cohesion: 0.40
Nodes (5): 2.1 Allocation site, 2.2 Ownership context, 2.3 Abstract value, 2.4 What tier is not, 2 · The objects of the model

### Community 639 - "4 · Tier derivation"
Cohesion: 0.40
Nodes (5): 4.1 Inputs, 4.2 The derivation function, 4.3 Monotonicity (normative property), 4.4 Cost model constants *(informative)*, 4 · Tier derivation

### Community 645 - "test_120_min_max_abs.psm"
Cohesion: 0.70
Nodes (4): check(), clampSum(), clampSumInline(), main()

### Community 651 - "10 · Boundaries"
Cohesion: 0.67
Nodes (3): 10.1 FFI, 10.2 Library distribution, 10 · Boundaries

### Community 654 - "test_272_temporary_hoists.psm"
Cohesion: 0.27
Nodes (10): toVec(), fail(), main(), visit(), visited, classify(), fail(), main() (+2 more)

### Community 658 - "test_298_ptr_atomics.psm"
Cohesion: 0.70
Nodes (4): free(), malloc(), fail(), main()

## Knowledge Gaps
- **1038 isolated node(s):** `MATRIX`, `WORD`, `LOCK`, `COUNTER`, `REGISTERS` (+1033 more)
  These have ≤1 connection - possible missing edges or undocumented components. (Counts symbols only; 2579 node(s) total have ≤1 connection when file, concept and rationale nodes are included.)
- **176 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `ASTNode` connect `ASTNode` to `impl Parser`, `bridge.psm`, `residues.psm`, `aifEmitManifest`, `ir/expr.psm`, `symbols.psm`, `consts.psm`, `model.psm`, `compile.psm`, `impl Parser`, `impl Parser`, `analyzedModule`, `generateAssignment`, `generateReleaseFn`, `NodeKind`, `aifWalk`, `impl RelLoop`, `TypeInfo`, `inlineElemSizeOfList`, `dump.psm`, `nowrap.psm`, `node_to_ptr`, `ast/types.psm`, `ptr_to_node`, `report.psm`, `ir/stmt.psm`, `generateReturn`, `nowrapExpr`, `assign.psm`, `generics.psm`, `.equals`?**
  _High betweenness centrality (0.031) - this node is a cross-community bridge._
- **Why does `join()` connect `.spawn` to `assert`, `unicode_conformance.psm`, `fs.psm`, `strlen`, `string.psm`, `Added`, `run`?**
  _High betweenness centrality (0.018) - this node is a cross-community bridge._
- **Why does `ptr_to_node()` connect `ptr_to_node` to `impl Parser`, `bridge.psm`, `residues.psm`, `consts.psm`, `symbols.psm`, `ir/expr.psm`, `model.psm`, `context.psm`, `aifCallSites`, `impl Parser`, `impl Parser`, `generateAssignment`, `ASTNode`, `generateReleaseFn`, `aifWalk`, `impl RelLoop`, `inlineElemSizeOfList`, `TypeInfo`, `dump.psm`, `nowrap.psm`, `node_to_ptr`, `ast/types.psm`, `ir/stmt.psm`, `generateReturn`, `nowrapExpr`, `assign.psm`, `contents.psm`, `generics.psm`, `.equals`?**
  _High betweenness centrality (0.016) - this node is a cross-community bridge._
- **What connects `MATRIX`, `WORD`, `LOCK` to the rest of the system?**
  _1038 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `bridge.psm` be split into smaller, more focused modules?**
  _Cohesion score 0.012116840966462315 - nodes in this community are weakly interconnected._
- **Should `std/io.psm` be split into smaller, more focused modules?**
  _Cohesion score 0.01963350785340314 - nodes in this community are weakly interconnected._
- **Should `freestanding/rust/algorithms.rs` be split into smaller, more focused modules?**
  _Cohesion score 0.06201550387596899 - nodes in this community are weakly interconnected._