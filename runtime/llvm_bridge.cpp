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
#include <llvm/Support/Error.h>

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

// Links into `dst` only the definitions `dst` declares, and what they reach.
// Takes ownership of `src` whatever the outcome, as LLVMLinkModules2 does.
extern "C" int prismio_llvm_link_only_needed(LLVMModuleRef dst, LLVMModuleRef src) {
    std::unique_ptr<llvm::Module> source(llvm::unwrap(src));
    return llvm::Linker::linkModules(*llvm::unwrap(dst), std::move(source),
                                     llvm::Linker::Flags::LinkOnlyNeeded) ? 1 : 0;
}

#endif
