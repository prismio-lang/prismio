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

#include <llvm/IR/Function.h>
#include <llvm/IR/Module.h>
#include <llvm/Linker/Linker.h>
#include <llvm/Passes/PassBuilder.h>
#include <llvm/Passes/StandardInstrumentations.h>
#include <llvm/Support/Error.h>
#include <llvm/Target/TargetMachine.h>
#include <llvm/Transforms/IPO/Annotation2Metadata.h>
#include <llvm/Transforms/IPO/ForceFunctionAttrs.h>
#include <llvm/Transforms/IPO/MemProfContextDisambiguation.h>
#include <llvm/Transforms/Scalar/AnnotationRemarks.h>

#include <cstdlib>
#include <cstring>
#include <memory>
#include <string>

// A malloc'd copy, which the C side releases with free().
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

// Runs one half of `<prefix>,default<O<level>>`, set up exactly as LLVMRunPasses
// sets it up (PassBuilderBindings.cpp, LLVM 23.1.1). Half 1 is everything up to
// and including the module simplification pipeline -- the inliner and the
// function simplification it drives, which must see the whole program. Half 2 is
// the module optimisation pipeline -- loop rotation, vectorisation, unrolling and
// their cleanups -- which works one function at a time, so a codegen partition
// can run it on its own functions. Between them they are what
// buildPerModuleDefaultPipeline builds for ThinOrFullLTOPhase::None:
//
//     MemProfRemoveInfo, Annotation2Metadata, ForceFunctionAttrs,
//     [pipeline-start callbacks: none registered here],
//     buildModuleSimplificationPipeline          <- end of half 1
//     buildModuleOptimizationPipeline,
//     function(AnnotationRemarks)                <- end of half 2
//
// with the statistics-only InstCount passes left out, as they are when
// statistics are off. `prefix` (may be empty) runs first in half 1.
extern "C" int prismio_llvm_run_default_half(LLVMModuleRef module, LLVMTargetMachineRef machine,
                                             const char* prefix, int level, int half,
                                             int unroll, int interleave, int vectorize_loops,
                                             int vectorize_slp, char** error) {
    llvm::Module* m = llvm::unwrap(module);
    llvm::PipelineTuningOptions pto;
    pto.LoopUnrolling = unroll != 0;
    pto.LoopInterleaving = interleave != 0;
    pto.LoopVectorization = vectorize_loops != 0;
    pto.SLPVectorization = vectorize_slp != 0;
    llvm::PassInstrumentationCallbacks pic;
    llvm::PassBuilder pb(reinterpret_cast<llvm::TargetMachine*>(machine), pto, std::nullopt, &pic);
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
    if (half == 1) {
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
    } else {
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
