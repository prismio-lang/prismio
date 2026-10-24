// The few LLVM operations the C API cannot express, for llvm-api-backend.c.
//
// The backend is written against LLVM-C and stays that way: the C API is stable
// within a major version and does not tie an LLVM upgrade to C++ API churn. What
// is here is only what LLVM-C has no function for, each behind an `extern "C"`
// entry point that takes and returns the C API's opaque handles. See
// docs/LLVM_BRIDGE_PLAN.md.
//
// LLVM is built without RTTI or exceptions, so nothing here subclasses a
// polymorphic LLVM type or uses dynamic_cast/typeid, and every llvm::Error is
// consumed before it can escape: an unchecked one aborts.
//
// Windows links LLVM-C.dll, which exports the C API only, so there this file is
// empty and the backend takes its C path (PRISMIO_LLVM_BRIDGE, prismio_llvm.h).

#include "prismio_llvm.h"

#ifdef PRISMIO_LLVM_BRIDGE

#include <llvm/Analysis/LoopInfo.h>
#include <llvm/Analysis/ScalarEvolution.h>
#include <llvm/Analysis/ScalarEvolutionExpressions.h>
#include <llvm/IR/Dominators.h>
#include <llvm/IR/InstIterator.h>
#include <llvm/IR/Function.h>
#include <llvm/IR/Instructions.h>
#include <llvm/IR/IntrinsicInst.h>
#include <llvm/IR/Module.h>
#include <llvm/Linker/Linker.h>
#include <llvm/Passes/PassBuilder.h>
#include <llvm/Passes/StandardInstrumentations.h>
#include <llvm/Support/Error.h>
#include <llvm/Support/raw_ostream.h>
#include <llvm/Target/TargetMachine.h>
#include <llvm/Transforms/IPO/Annotation2Metadata.h>
#include <llvm/Transforms/IPO/ForceFunctionAttrs.h>
#include <llvm/Transforms/IPO/MemProfContextDisambiguation.h>
#include <llvm/Transforms/Scalar/AnnotationRemarks.h>
#include <llvm/Transforms/Scalar/LoopUnrollPass.h>
#include <llvm/Transforms/Utils/Cloning.h>
#include <llvm/Transforms/Utils/LoopUtils.h>
#include <llvm/Transforms/Utils/ValueMapper.h>

#include <cstdlib>
#include <cstring>
#include <memory>
#include <optional>
#include <string>
#include <utility>
#include <vector>

// A malloc'd copy, which the C side releases with tmp_free() (prismio_runtime.h).
static char* bridge_message(const std::string& text) {
    char* copy = static_cast<char*>(std::malloc(text.size() + 1));
    if (copy) std::memcpy(copy, text.c_str(), text.size() + 1);
    return copy;
}

extern "C" int prismio_llvm_materialize(LLVMValueRef function, char** error) {
    llvm::Function* f = llvm::unwrap<llvm::Function>(function);
    if (llvm::Error err = f->materialize()) {
        if (error) *error = bridge_message(llvm::toString(std::move(err)));
        else llvm::consumeError(std::move(err));
        return 1;
    }
    return 0;
}

// Makes a function of a lazily loaded module a declaration without reading its
// body. LLVM-C has no deleteBody, and deleting a body block by block cannot reach
// one that was never materialised: the function would stay materialisable, which
// codegen reads as a definition with no blocks.
extern "C" void prismio_llvm_drop_body(LLVMValueRef function) {
    llvm::unwrap<llvm::Function>(function)->deleteBody();
}

// Prismio's own passes, run inside LLVM's pipeline at an extension point rather
// than between whole pipelines, so they see the IR exactly where the decision
// they inform is made. Each is a bit of `policies` (prismio_llvm.h).
//
// HotLoopUnroll: partial unrolling where the work is, and nowhere else.
//
// LLVM's AArch64 cost model unrolls nothing partially on a CPU with no loop buffer
// (`generic`, what freestanding code targets), clang and rustc included; what C
// gets there is LoopVectorize *interleaving* a loop with independent iterations
// (VF 1, interleave count 4: binary_search's table fill becomes four `str`s as
// two `stp`s). Prismio used to turn partial unrolling on for the whole module
// with -unroll-allow-partial: instructions fell to 0.876x of C but `.text` grew
// to 1.98x, because every loop with a known trip count unrolled, set-up loops
// included, and a loop LoopVectorize had already interleaved four ways unrolled
// four ways again -- sixteen copies of a fill that runs once.
//
// So the global setting is gone and this pass decides, at the vectorizer-end
// extension point (after LoopVectorize and the pipeline's own LoopUnrollPass):
//
//   - only a hot loop: the hottest estimate in its nest -- its own iterations per
//     call (below), or an inner loop's -- at least an eighth of the function's
//     hottest. An outer loop driving a hot inner one is hot: mandelbrot's `px`
//     runs the 40-step escape loop;
//   - innermost first: a loop whose descendant was unrolled is not, so copies
//     never multiply; an outer loop is a candidate when nothing inside it was, and
//     its size then counts every block of its nest (gcd_lcm's `b` loop around
//     Euclid's, mandelbrot's `px` around the escape-time loop);
//   - only one no pragma decided: `llvm.loop.unroll.disable`, `.count`, `.full`.
//     A loop LoopVectorize interleaved stays a candidate -- matrix_multiply's k
//     loop came out interleaved two ways and unrolling it four more is 0.69x C;
//   - with a constant trip count that the chosen factor divides, so there is no
//     remainder loop; or, unrolled at run time with a remainder, an outermost loop
//     whose count the compiler cannot see -- `K * scale`, a count from the input,
//     which LLVM never unrolls on its own: pointer_chase 0.63x of C, popcount 0.86x
//     -- or a nested loop whose constant bound is at most `kShortBound` and which
//     usually stops early (mandelbrot's 40-step escape loop, 0.87x). A nested loop
//     with a long bound is not: the sieve's `j += i` loop is bounded by 100,000
//     but runs a handful of times per entry, and paying the remainder's division on
//     each of its 18,000 entries made prime_sieve 1.08x C. Nor is any loop of a
//     function that calls itself: tail-call elimination turns `fib(n-1) +
//     fib(n-2)` into an outermost loop of a few trips per call, and its remainder
//     made fibonacci 1.23x C;
//   - with a nest small enough that factor x size fits the budget
//     (PRISMIO_UNROLL_BUDGET, default 150 instructions -- LLVM's own partial
//     threshold). The factor is 4 (PRISMIO_UNROLL_COUNT), halved until it fits.
//
// The loop gets `llvm.loop.unroll.count` and a forced-only LoopUnrollPass runs.
//
// A loop's iterations per call are estimated as the product of its own trip count
// and every enclosing loop's: the exact constant when SCEV knows it, else the
// constant maximum (`it < 40` with a `break` is 40). A count the compiler cannot
// see is `kUnknownTrips` for an outermost loop, because there it is usually one
// that grows with the input, and `kUnknownInnerTrips` for a nested one, which is
// usually a short search -- Euclid's loop, a heap's sift.
static const uint64_t kUnknownTrips = uint64_t(1) << 20;
static const uint64_t kUnknownInnerTrips = 8;
static const uint64_t kTripCap = uint64_t(1) << 62;
static const unsigned kShortBound = 64;

static uint64_t saturating_product(uint64_t a, uint64_t b) {
    if (a != 0 && b > kTripCap / a) return kTripCap;
    return a * b;
}

// Appends `loop` and its nest to `out` in preorder, each with the hottest estimate
// in its own nest, and answers that estimate.
static uint64_t estimate_loop_trips(llvm::ScalarEvolution& se, llvm::Loop* loop, uint64_t outer,
                                    std::vector<std::pair<llvm::Loop*, uint64_t>>& out) {
    uint64_t trips = se.getSmallConstantTripCount(loop);
    if (trips == 0) trips = se.getSmallConstantMaxTripCount(loop);
    if (trips == 0) trips = loop->getParentLoop() ? kUnknownInnerTrips : kUnknownTrips;
    uint64_t estimate = saturating_product(outer, trips);
    size_t at = out.size();
    out.emplace_back(loop, estimate);
    uint64_t nest = estimate;
    for (llvm::Loop* sub : loop->getSubLoops()) {
        uint64_t inner = estimate_loop_trips(se, sub, estimate, out);
        if (inner > nest) nest = inner;
    }
    out[at].second = nest;
    return nest;
}

static unsigned env_unsigned(const char* name, unsigned fallback) {
    const char* v = std::getenv(name);
    if (!v || !*v) return fallback;
    char* end = nullptr;
    unsigned long n = std::strtoul(v, &end, 10);
    return (end && *end == '\0') ? unsigned(n) : fallback;
}

static bool trace_policies() {
    const char* v = std::getenv("PRISMIO_POLICY_TRACE");
    return v && *v && !(v[0] == '0' && v[1] == '\0');
}

static unsigned loop_size(const llvm::Loop* loop) {
    unsigned size = 0;
    for (llvm::BasicBlock* block : loop->blocks()) {
        for (llvm::Instruction& inst : *block) {
            if (!llvm::isa<llvm::PHINode>(inst) && !inst.isDebugOrPseudoInst()) size++;
        }
    }
    return size;
}

struct HotLoopUnroll : llvm::PassInfoMixin<HotLoopUnroll> {
    llvm::PreservedAnalyses run(llvm::Function& f, llvm::FunctionAnalysisManager& fam) {
        llvm::LoopInfo& li = fam.getResult<llvm::LoopAnalysis>(f);
        if (li.empty()) return llvm::PreservedAnalyses::all();
        llvm::ScalarEvolution& se = fam.getResult<llvm::ScalarEvolutionAnalysis>(f);
        unsigned count = env_unsigned("PRISMIO_UNROLL_COUNT", 4);
        unsigned budget = env_unsigned("PRISMIO_UNROLL_BUDGET", 150);
        bool trace = trace_policies();
        std::vector<std::pair<llvm::Loop*, uint64_t>> loops;
        uint64_t hottest = 0;
        for (llvm::Loop* top : li) {
            uint64_t nest = estimate_loop_trips(se, top, 1, loops);
            if (nest > hottest) hottest = nest;
        }
        bool recursive = false;
        for (llvm::User* user : f.users()) {
            auto* call = llvm::dyn_cast<llvm::CallBase>(user);
            if (call && call->getFunction() == &f) { recursive = true; break; }
        }
        bool forced = false;
        std::vector<llvm::Loop*> unrolled;
        // `loops` is in preorder; walking it backwards visits every loop after all
        // of its descendants.
        for (auto it = loops.rbegin(); it != loops.rend(); ++it) {
            llvm::Loop* loop = it->first;
            uint64_t estimate = it->second;
            const char* verdict = nullptr;
            unsigned factor = 0;
            unsigned trips = se.getSmallConstantTripCount(loop);
            bool exact = trips != 0;
            if (!exact && !recursive) {
                // An outermost loop's count usually grows with the input; a nested
                // loop's is unrolled only when its bound is short.
                unsigned bound = se.getSmallConstantMaxTripCount(loop);
                if (!loop->getParentLoop() || (bound != 0 && bound <= kShortBound)) trips = bound;
            }
            unsigned size = loop_size(loop);
            bool inner_unrolled = false;
            for (llvm::Loop* done : unrolled) {
                if (loop != done && loop->contains(done)) { inner_unrolled = true; break; }
            }
            if (saturating_product(estimate, 8) < hottest) verdict = "cold";
            else if (inner_unrolled) verdict = "an inner loop unrolled";
            else if (llvm::getBooleanLoopAttribute(loop, "llvm.loop.unroll.disable")
                     || llvm::getBooleanLoopAttribute(loop, "llvm.loop.unroll.full")
                     || llvm::getOptionalIntLoopAttribute(loop, "llvm.loop.unroll.count")) verdict = "decided";
            else if (trips == 0) verdict = "no usable trip count";
            else {
                factor = count;
                while (factor > 1 && ((exact && trips % factor != 0) || size * factor > budget)) factor /= 2;
                if (factor < 2) verdict = "no factor fits";
            }
            if (!verdict) {
                llvm::addStringMetadataToLoop(loop, "llvm.loop.unroll.count", factor);
                unrolled.push_back(loop);
                forced = true;
            }
            if (trace) {
                llvm::errs() << "[policy] unroll " << f.getName() << " " << loop->getHeader()->getName()
                             << " depth=" << loop->getLoopDepth() << " trips=" << trips
                             << " size=" << size << " est=" << estimate << "/" << hottest << ": "
                             << (verdict ? verdict : "x") << (verdict ? "" : std::to_string(factor).c_str())
                             << "\n";
            }
        }
        if (!forced) return llvm::PreservedAnalyses::all();
        llvm::LoopUnrollPass unroller(llvm::LoopUnrollOptions(3, /*OnlyWhenForced=*/true));
        return unroller.run(f, fam);
    }
};

// CoveredFillElimination: a frame array is zero-filled where it is declared
// (`let mut t: Array<U32, 4096>`), and most are then written whole by a loop
// before anything reads them. The fill is dead, but LLVM's DSE cannot see it:
// it kills a store only by a later store it can name, and a loop's stores are one
// instruction standing for many. In the freestanding suite 18 memsets survived to
// the image against C's 2 (both in C's source), on binary_search, crc32,
// edit_distance, heapsort, knapsack, matrix_multiply, pointer_chase, quicksort,
// ring_buffer and sha256.
//
// A `memset(a, 0, sizeof a)` on an alloca `a` is deleted when one store S writes
// every byte of `a` before any use of `a` can read it:
//
//   - S's address, as SCEV, is a chain of affine recurrences over S's innermost
//     loop and then each immediate parent in turn, ending at `a` itself; each
//     step equals the bytes the loops inside it cover (S's size first, then that
//     times each inner trip count), so the nest tiles the array with no gap and no
//     overlap, and the outermost covers exactly sizeof a;
//   - every loop in the chain has a constant trip count, exits only at its latch,
//     and runs S (or the next inner loop) on every iteration: its block dominates
//     the latch. So S executes trip-count times per level, unconditionally;
//   - the outermost loop has one exit block E, the memset's block dominates its
//     preheader, and every use of `a` other than the memset, lifetime markers and
//     plain stores into `a` is dominated by E. A store writes and never reads; any
//     load, call, copy or escape happens only once the nest has finished.
//
// Then every byte a read can observe was written by S, on every path. Anything
// short of all of that keeps the memset.
static bool store_covers(llvm::ScalarEvolution& se, llvm::LoopInfo& li, llvm::DominatorTree& dt,
                         const llvm::DataLayout& dl, llvm::StoreInst* store,
                         llvm::AllocaInst* array, uint64_t size, llvm::Loop*& outermost) {
    llvm::TypeSize stored = dl.getTypeStoreSize(store->getValueOperand()->getType());
    if (stored.isScalable()) return false;
    uint64_t span = stored.getFixedValue();
    const llvm::SCEV* address = se.getSCEV(store->getPointerOperand());
    llvm::Loop* inner = nullptr;
    llvm::BasicBlock* runs = store->getParent();
    while (auto* rec = llvm::dyn_cast<llvm::SCEVAddRecExpr>(address)) {
        if (!rec->isAffine()) return false;
        llvm::Loop* loop = const_cast<llvm::Loop*>(rec->getLoop());
        llvm::Loop* expected = inner ? inner->getParentLoop() : li.getLoopFor(store->getParent());
        if (loop != expected) return false;
        auto* step = llvm::dyn_cast<llvm::SCEVConstant>(rec->getStepRecurrence(se));
        if (!step || step->getAPInt().isNegative() || step->getAPInt().getZExtValue() != span) return false;
        unsigned trips = se.getSmallConstantTripCount(loop);
        llvm::BasicBlock* latch = loop->getLoopLatch();
        if (trips == 0 || !latch || loop->getExitingBlock() != latch) return false;
        if (!dt.dominates(runs, latch)) return false;
        if (span > (uint64_t(1) << 40) / trips) return false;
        span *= trips;
        address = rec->getStart();
        inner = loop;
        runs = loop->getHeader();
    }
    if (!inner || address != se.getSCEV(array) || span != size) return false;
    outermost = inner;
    return true;
}

// Every use of `root` reached through address arithmetic, other than lifetime
// markers: plain stores into it go to `stores`, everything else to `others`.
// False when a use is one this cannot follow.
static bool collect_array_uses(llvm::Value* root, std::vector<llvm::StoreInst*>& stores,
                               std::vector<llvm::Instruction*>& others) {
    std::vector<llvm::Value*> work{root};
    while (!work.empty()) {
        llvm::Value* v = work.back();
        work.pop_back();
        for (llvm::User* user : v->users()) {
            auto* inst = llvm::dyn_cast<llvm::Instruction>(user);
            if (!inst) return false;
            if (llvm::isa<llvm::GetElementPtrInst>(inst) || llvm::isa<llvm::BitCastInst>(inst)) {
                work.push_back(inst);
            } else if (inst->isLifetimeStartOrEnd()) {
                continue;
            } else if (auto* st = llvm::dyn_cast<llvm::StoreInst>(inst);
                       st && st->getPointerOperand() == v && st->getValueOperand() != v
                       && !st->isVolatile()) {
                stores.push_back(st);
            } else {
                others.push_back(inst);
            }
        }
    }
    return true;
}

struct CoveredFillElimination : llvm::PassInfoMixin<CoveredFillElimination> {
    llvm::PreservedAnalyses run(llvm::Function& f, llvm::FunctionAnalysisManager& fam) {
        std::vector<llvm::MemSetInst*> fills;
        for (llvm::Instruction& inst : llvm::instructions(f)) {
            auto* ms = llvm::dyn_cast<llvm::MemSetInst>(&inst);
            if (!ms || ms->isVolatile()) continue;
            auto* value = llvm::dyn_cast<llvm::ConstantInt>(ms->getValue());
            if (!value || !value->isZero() || !llvm::isa<llvm::ConstantInt>(ms->getLength())) continue;
            if (!llvm::isa<llvm::AllocaInst>(ms->getDest())) continue;
            fills.push_back(ms);
        }
        if (fills.empty()) return llvm::PreservedAnalyses::all();
        llvm::LoopInfo& li = fam.getResult<llvm::LoopAnalysis>(f);
        llvm::DominatorTree& dt = fam.getResult<llvm::DominatorTreeAnalysis>(f);
        llvm::ScalarEvolution& se = fam.getResult<llvm::ScalarEvolutionAnalysis>(f);
        const llvm::DataLayout& dl = f.getDataLayout();
        bool trace = trace_policies();
        bool changed = false;
        for (llvm::MemSetInst* ms : fills) {
            auto* array = llvm::cast<llvm::AllocaInst>(ms->getDest());
            std::optional<llvm::TypeSize> alloc = array->getAllocationSize(dl);
            uint64_t length = llvm::cast<llvm::ConstantInt>(ms->getLength())->getZExtValue();
            const char* verdict = "kept: covers less than the whole alloca";
            if (alloc && !alloc->isScalable() && alloc->getFixedValue() == length) {
                std::vector<llvm::StoreInst*> stores;
                std::vector<llvm::Instruction*> others;
                verdict = "kept: an address use it cannot follow";
                if (collect_array_uses(array, stores, others)) {
                    verdict = "kept: no store covers it";
                    for (llvm::StoreInst* st : stores) {
                        llvm::Loop* nest = nullptr;
                        if (!store_covers(se, li, dt, dl, st, array, length, nest)) continue;
                        verdict = "kept: a use may read before the covering nest finishes";
                        llvm::BasicBlock* exit = nest->getExitBlock();
                        llvm::BasicBlock* preheader = nest->getLoopPreheader();
                        if (!exit || !preheader || nest->contains(ms->getParent())
                                || !dt.dominates(ms->getParent(), preheader)) continue;
                        bool after = true;
                        for (llvm::Instruction* use : others) {
                            if (use == ms) continue;
                            if (!dt.dominates(exit, use->getParent())) { after = false; break; }
                        }
                        if (!after) continue;
                        verdict = "deleted";
                        break;
                    }
                }
            }
            if (trace) {
                llvm::errs() << "[policy] covered fill " << f.getName() << " "
                             << array->getName() << " (" << length << " bytes): " << verdict << "\n";
            }
            if (verdict[0] == 'd') {
                ms->eraseFromParent();
                changed = true;
            }
        }
        if (!changed) return llvm::PreservedAnalyses::all();
        llvm::PreservedAnalyses kept;
        kept.preserveSet<llvm::CFGAnalyses>();
        return kept;
    }
};

// SelfRecursionUnfold: a small pure function that calls itself more than once is
// inlined into itself, one level, so that the copies' calls with equal arguments
// become one call.
//
// `fib(n - 1) + fib(n - 2)` unfolded is `fib(n - 2) + fib(n - 3) + fib(n - 3) +
// fib(n - 4)`, and a call that reads no memory with the same argument is the same
// value, which EarlyCSE and GVN merge once FunctionAttrs has marked the function
// `memory(none)`. Three calls instead of four per level is a smaller exponent, not a
// smaller constant: the growth rate per level falls from 1.618 to 1.466, and
// fibonacci(27) runs 0.40M instructions instead of 4.96M (C 5.28M). LLVM's inliner
// never inlines a function into itself; GCC's does, to a depth, which is where the
// idea comes from.
//
// A module pass at the early-simplification extension point: after SROA has put the
// body in SSA form, and before the inliner's pipeline, where FunctionAttrs, EarlyCSE
// and then TailCallElim run -- the merge needs the two calls to exist side by side,
// which they no longer do once tail-call elimination has turned the second into a
// loop. A function pass could not do it: inlining a function into itself goes through
// a clone, and a CGSCC pass may not add one to the module.
//
// One level. A second needs the first's equal calls merged, and they sit behind each
// copy's own base-case branch: EarlyCSE, GVN and SimplifyCFG run between the levels
// still left four calls, and fibonacci at 0.40M against 0.35M for one level.
//
// Only when the result is cheap and the merge likely: a body of at most
// `kUnfoldBudget` instructions, two or three calls to itself, and nothing else that
// touches memory or calls anything but an intrinsic -- without that, the calls do not
// merge and the unfolding only doubles the code. Not for a function built for size.
static const unsigned kUnfoldBudget = 40;

static bool unfold_candidate(llvm::Function& f, std::vector<llvm::CallBase*>& self) {
    if (f.isDeclaration() || f.hasOptSize() || f.hasFnAttribute(llvm::Attribute::NoInline)) return false;
    unsigned size = 0;
    for (llvm::Instruction& inst : llvm::instructions(f)) {
        if (inst.isDebugOrPseudoInst()) continue;
        if (++size > kUnfoldBudget) return false;
        if (auto* call = llvm::dyn_cast<llvm::CallBase>(&inst)) {
            if (call->getCalledFunction() == &f) {
                self.push_back(call);
                continue;
            }
            if (!llvm::isa<llvm::IntrinsicInst>(call) || call->mayReadOrWriteMemory()) return false;
            continue;
        }
        if (inst.mayReadOrWriteMemory() || llvm::isa<llvm::AllocaInst>(inst)) return false;
    }
    return self.size() >= 2 && self.size() <= 3;
}

// Inlines `f` into itself at its calls in `self`, through a clone. Answers how many.
static unsigned unfold_once(llvm::Function* f, std::vector<llvm::CallBase*>& self) {
    llvm::ValueToValueMapTy map;
    llvm::Function* copy = llvm::CloneFunction(f, map);
    unsigned inlined = 0;
    for (llvm::CallBase* call : self) {
        call->setCalledFunction(copy);
        llvm::InlineFunctionInfo info;
        if (llvm::InlineFunction(*call, info).isSuccess()) {
            inlined++;
        } else {
            call->setCalledFunction(f);
        }
    }
    // The copy's own calls named `f`, so what was inlined calls `f`; nothing is left
    // that names the copy.
    copy->eraseFromParent();
    return inlined;
}

struct SelfRecursionUnfold : llvm::PassInfoMixin<SelfRecursionUnfold> {
    llvm::PreservedAnalyses run(llvm::Module& m, llvm::ModuleAnalysisManager&) {
        bool trace = trace_policies();
        bool changed = false;
        std::vector<llvm::Function*> functions;
        for (llvm::Function& f : m) functions.push_back(&f);
        for (llvm::Function* f : functions) {
            std::vector<llvm::CallBase*> self;
            if (!unfold_candidate(*f, self)) continue;
            unsigned inlined = unfold_once(f, self);
            if (trace) {
                llvm::errs() << "[policy] unfold " << f->getName() << ": " << inlined << " of "
                             << self.size() << " self-calls inlined\n";
            }
            changed = changed || inlined > 0;
        }
        return changed ? llvm::PreservedAnalyses::none() : llvm::PreservedAnalyses::all();
    }
};

static void register_policies(llvm::PassBuilder& pb, int policies) {
    // Both at the vectorizer's start: loops rotated and simplified, trip counts
    // known, the unroller and the vectorizer still to come.
    if (policies & PRISMIO_POLICY_COVERED_FILLS) {
        pb.registerVectorizerStartEPCallback(
            [](llvm::FunctionPassManager& fpm, llvm::OptimizationLevel) {
                fpm.addPass(CoveredFillElimination());
            });
    }
    if (policies & PRISMIO_POLICY_SELF_RECURSION_UNFOLD) {
        pb.registerPipelineEarlySimplificationEPCallback(
            [](llvm::ModulePassManager& mpm, llvm::OptimizationLevel, llvm::ThinOrFullLTOPhase) {
                mpm.addPass(SelfRecursionUnfold());
            });
    }
    // After LoopVectorize and the pipeline's own unroller, so it sees which loops
    // they already interleaved, vectorized or unrolled.
    if (policies & PRISMIO_POLICY_HOT_LOOP_UNROLL) {
        pb.registerVectorizerEndEPCallback(
            [](llvm::FunctionPassManager& fpm, llvm::OptimizationLevel) {
                fpm.addPass(HotLoopUnroll());
            });
    }
}

// Runs `<prefix>,default<O<level>>`, or one half of it, set up exactly as
// LLVMRunPasses sets it up (PassBuilderBindings.cpp, LLVM 23.1.1). Half 1 is
// everything up to and including the module simplification pipeline -- the inliner
// and the function simplification it drives, which must see the whole program.
// Half 2 is the module optimisation pipeline -- loop rotation, vectorisation,
// unrolling and their cleanups -- which works one function at a time, so a codegen
// partition can run it on its own functions. Half 0 is both, in one pass manager,
// which is buildPerModuleDefaultPipeline for ThinOrFullLTOPhase::None:
//
//     MemProfRemoveInfo, Annotation2Metadata, ForceFunctionAttrs,
//     [pipeline-start callbacks: none registered here],
//     buildModuleSimplificationPipeline          <- end of half 1
//     buildModuleOptimizationPipeline,
//     function(AnnotationRemarks)                <- end of half 2
//
// with the statistics-only InstCount passes left out, as they are when
// statistics are off. `prefix` (may be empty) runs first in half 1. `policies`
// adds Prismio's passes at their extension points.
extern "C" int prismio_llvm_run_default_half(LLVMModuleRef module, LLVMTargetMachineRef machine,
                                             const char* prefix, int level, int half,
                                             int unroll, int interleave, int vectorize_loops,
                                             int vectorize_slp, int policies, char** error) {
    llvm::Module* m = llvm::unwrap(module);
    llvm::PipelineTuningOptions pto;
    pto.LoopUnrolling = unroll != 0;
    pto.LoopInterleaving = interleave != 0;
    pto.LoopVectorization = vectorize_loops != 0;
    pto.SLPVectorization = vectorize_slp != 0;
    llvm::PassInstrumentationCallbacks pic;
    llvm::PassBuilder pb(reinterpret_cast<llvm::TargetMachine*>(machine), pto, std::nullopt, &pic);
    register_policies(pb, policies);
    llvm::LoopAnalysisManager lam;
    llvm::FunctionAnalysisManager fam;
    llvm::CGSCCAnalysisManager cgam;
    llvm::ModuleAnalysisManager mam;
    pb.registerLoopAnalyses(lam);
    pb.registerFunctionAnalyses(fam);
    pb.registerCGSCCAnalyses(cgam);
    pb.registerModuleAnalyses(mam);
    pb.crossRegisterProxies(lam, fam, cgam, mam);
    llvm::StandardInstrumentations si(m->getContext(), false, false);
    si.registerCallbacks(pic, &mam);

    llvm::OptimizationLevel opt = level <= 1 ? llvm::OptimizationLevel::O1
                                : level == 2 ? llvm::OptimizationLevel::O2
                                             : llvm::OptimizationLevel::O3;
    llvm::ModulePassManager mpm;
    if (half != 2) {
        if (prefix && *prefix) {
            if (llvm::Error err = pb.parsePassPipeline(mpm, prefix)) {
                if (error) *error = bridge_message(llvm::toString(std::move(err)));
                else llvm::consumeError(std::move(err));
                return 1;
            }
        }
        mpm.addPass(llvm::MemProfRemoveInfo());
        mpm.addPass(llvm::Annotation2MetadataPass());
        mpm.addPass(llvm::ForceFunctionAttrsPass());
        mpm.addPass(pb.buildModuleSimplificationPipeline(opt, llvm::ThinOrFullLTOPhase::None));
    }
    if (half != 1) {
        mpm.addPass(pb.buildModuleOptimizationPipeline(opt, llvm::ThinOrFullLTOPhase::None));
        mpm.addPass(llvm::createModuleToFunctionPassAdaptor(llvm::AnnotationRemarksPass()));
    }
    mpm.run(*m, mam);
    return 0;
}

// Links into `dst` only the definitions `dst` declares, and what they reach.
// Takes ownership of `src` whatever the outcome, as LLVMLinkModules2 does.
extern "C" int prismio_llvm_link_only_needed(LLVMModuleRef dst, LLVMModuleRef src) {
    std::unique_ptr<llvm::Module> source(llvm::unwrap(src));
    return llvm::Linker::linkModules(*llvm::unwrap(dst), std::move(source),
                                     llvm::Linker::Flags::LinkOnlyNeeded) ? 1 : 0;
}

#endif
