// LLVM C API declarations used by the Prismio LLVM backend.
//
// Why this file exists: the official LLVM binary installer for Windows ships
// lib/LLVM-C.lib and bin/LLVM-C.dll but installs only two of the llvm-c headers
// (lto.h and Remarks.h). There is no llvm-c/Core.h to include, so the
// declarations we need are written out here.
//
// This is safe in the way that matters: we link against LLVM-C.lib, so every
// symbol name below is checked by the linker. A misspelled function is a build
// error, not a runtime surprise. Signatures are our responsibility, which is why
// this file stays as small as possible and why the whole thing is bypassed the
// moment real headers are available:
//
//     clang -DPRISMIO_LLVM_REAL_HEADERS ...
//
// With that flag the authoritative headers are used instead and they validate
// every signature for us. Keep the two paths interchangeable -- if you add a
// function here, make sure it also exists in the real API with the same shape.
//
// The C API is covered by LLVM's C API compatibility policy, so these
// declarations do not rot between releases the way the C++ API would.

#ifndef PRISMIO_LLVM_H
#define PRISMIO_LLVM_H

// ---------------------------------------------------------------------------
// Pinned LLVM version.
//
// A given Prismio release targets one LLVM major version. The C API is stable
// within a major version but not across them -- LLVMBuildGEP left for
// LLVMBuildGEP2, typed pointers became opaque, LLVMArrayType gained
// LLVMArrayType2 -- so "some LLVM is installed" is not good enough.
//
// This is checked at runtime rather than only at build time, because the
// failure that actually bites is a mismatch between the headers compiled
// against and the LLVM-C shared library loaded at run time. That combination
// links cleanly and then misbehaves in ways that look like compiler bugs.
// llvm-api-backend.c calls LLVMGetVersion() once at startup and refuses to run
// on a different major version.
//
// Keep this in step with DEFAULT_VERSION in tools/setup_llvm.py.
// ---------------------------------------------------------------------------
#ifndef PRISMIO_LLVM_EXPECTED_MAJOR
#define PRISMIO_LLVM_EXPECTED_MAJOR 22
#endif

#ifdef PRISMIO_LLVM_REAL_HEADERS

#include <llvm-c/Analysis.h>
#include <llvm-c/BitWriter.h>
#include <llvm-c/Core.h>
#include <llvm-c/DebugInfo.h>
#include <llvm-c/Error.h>
#include <llvm-c/IRReader.h>
#include <llvm-c/LLJIT.h>
#include <llvm-c/Linker.h>
#include <llvm-c/Orc.h>
#include <llvm-c/Target.h>
#include <llvm-c/TargetMachine.h>
#include <llvm-c/Transforms/PassBuilder.h>

// LLJIT/Orc are here and not in the fallback block below for the same reason
// DIBuilder is, and the reason is written out at that block: the linker checks
// names, never signatures, so hand-transcribing an API whose types are opaque
// handles passed by pointer buys a build that succeeds and a run that corrupts
// memory. `--jit` is a convenience; `--jit` that mostly works is not one.

// `-g` is compiled in only on this path, and deliberately.
//
// DIBuilder is ~20 functions whose parameter lists are long and mostly integers
// -- CreateCompileUnit alone takes twenty. The linker checks the *names* in the
// block below, never the signatures, so a transcription slip there does not
// fail to build: it produces a module whose DWARF is subtly wrong, which is the
// one outcome this feature must not have. A missing `-g` is an honest gap; a
// member offset four bytes from the field is a debugger confidently pointing at
// the wrong memory.
//
// The supported configuration is real headers -- tools/setup_llvm.py refuses an
// LLVM without include/llvm-c/Core.h -- so nothing that is actually verified
// loses anything. ir_debug_begin() says so out loud rather than emitting
// nothing and letting -g look as though it worked.
#define PRISMIO_DWARF 1

// Naming a target other than the host is compiled in on this path only, and for
// the same reason, though it is not debug info and a reader should not have to
// know the two coincide.
//
// Resolving a triple means LLVMInitializeAllTargets, which is generated from the
// set of backends LLVM was built with -- there is no portable way to write it
// out by hand below. Without it the host is the only target that can be named,
// and ir_target_select() refuses anything else instead of guessing a layout.
#define PRISMIO_TARGETS 1

#else

#include <stddef.h> // size_t
#include <stdint.h> // uint64_t

#ifdef __cplusplus
extern "C" {
#endif

typedef struct LLVMOpaqueContext *LLVMContextRef;
typedef struct LLVMOpaqueModule *LLVMModuleRef;
typedef struct LLVMOpaqueType *LLVMTypeRef;
typedef struct LLVMOpaqueValue *LLVMValueRef;
typedef struct LLVMOpaqueBasicBlock *LLVMBasicBlockRef;
typedef struct LLVMOpaqueBuilder *LLVMBuilderRef;
typedef struct LLVMOpaqueMetadata *LLVMMetadataRef;

typedef int LLVMBool;

// LLVMIntPredicate
#define LLVMIntEQ 32
#define LLVMIntNE 33
#define LLVMIntUGT 34
#define LLVMIntUGE 35
#define LLVMIntULT 36
#define LLVMIntULE 37
#define LLVMIntSGT 38
#define LLVMIntSGE 39
#define LLVMIntSLT 40
#define LLVMIntSLE 41

// LLVMRealPredicate
#define LLVMRealOEQ 1
#define LLVMRealOGT 2
#define LLVMRealOGE 3
#define LLVMRealOLT 4
#define LLVMRealOLE 5
#define LLVMRealONE 6

// LLVMVerifierFailureAction
#define LLVMAbortProcessAction 0
#define LLVMPrintMessageAction 1
#define LLVMReturnStatusAction 2

// LLVMLinkage
#define LLVMExternalLinkage 0
#define LLVMInternalLinkage 8
#define LLVMPrivateLinkage 9

// --- context / module / builder -------------------------------------------
LLVMContextRef LLVMContextCreate(void);
void LLVMContextDispose(LLVMContextRef C);
LLVMModuleRef LLVMModuleCreateWithNameInContext(const char *ModuleID, LLVMContextRef C);
void LLVMDisposeModule(LLVMModuleRef M);
void LLVMSetTarget(LLVMModuleRef M, const char *Triple);
void LLVMSetDataLayout(LLVMModuleRef M, const char *DataLayoutStr);
void LLVMSetSourceFileName(LLVMModuleRef M, const char *Name, size_t Len);
LLVMBuilderRef LLVMCreateBuilderInContext(LLVMContextRef C);
void LLVMDisposeBuilder(LLVMBuilderRef Builder);

// --- types ------------------------------------------------------------------
LLVMTypeRef LLVMVoidTypeInContext(LLVMContextRef C);
LLVMTypeRef LLVMInt1TypeInContext(LLVMContextRef C);
LLVMTypeRef LLVMInt8TypeInContext(LLVMContextRef C);
LLVMTypeRef LLVMInt16TypeInContext(LLVMContextRef C);
LLVMTypeRef LLVMInt32TypeInContext(LLVMContextRef C);
LLVMTypeRef LLVMInt64TypeInContext(LLVMContextRef C);
LLVMTypeRef LLVMDoubleTypeInContext(LLVMContextRef C);
LLVMTypeRef LLVMPointerTypeInContext(LLVMContextRef C, unsigned AddressSpace);
LLVMTypeRef LLVMArrayType2(LLVMTypeRef ElementType, uint64_t ElementCount);
LLVMTypeRef LLVMFunctionType(LLVMTypeRef ReturnType, LLVMTypeRef *ParamTypes,
                             unsigned ParamCount, LLVMBool IsVarArg);
LLVMTypeRef LLVMStructCreateNamed(LLVMContextRef C, const char *Name);
void LLVMStructSetBody(LLVMTypeRef StructTy, LLVMTypeRef *ElementTypes,
                       unsigned ElementCount, LLVMBool Packed);
LLVMTypeRef LLVMTypeOf(LLVMValueRef Val);

// --- constants --------------------------------------------------------------
LLVMValueRef LLVMConstInt(LLVMTypeRef IntTy, unsigned long long N, LLVMBool SignExtend);
LLVMValueRef LLVMConstReal(LLVMTypeRef RealTy, double N);
LLVMValueRef LLVMConstNull(LLVMTypeRef Ty);
LLVMValueRef LLVMConstPointerNull(LLVMTypeRef Ty);
LLVMValueRef LLVMConstStringInContext(LLVMContextRef C, const char *Str,
                                      unsigned Length, LLVMBool DontNullTerminate);
LLVMValueRef LLVMSizeOf(LLVMTypeRef Ty);

// --- functions / globals ----------------------------------------------------
LLVMValueRef LLVMAddFunction(LLVMModuleRef M, const char *Name, LLVMTypeRef FunctionTy);
LLVMValueRef LLVMGetNamedFunction(LLVMModuleRef M, const char *Name);
LLVMValueRef LLVMGetParam(LLVMValueRef Fn, unsigned Index);
LLVMTypeRef LLVMGlobalGetValueType(LLVMValueRef Global);
LLVMValueRef LLVMAddGlobal(LLVMModuleRef M, LLVMTypeRef Ty, const char *Name);
LLVMValueRef LLVMGetNamedGlobal(LLVMModuleRef M, const char *Name);
void LLVMSetInitializer(LLVMValueRef GlobalVar, LLVMValueRef ConstantVal);
void LLVMSetGlobalConstant(LLVMValueRef GlobalVar, LLVMBool IsConstant);
void LLVMSetLinkage(LLVMValueRef Global, int Linkage);
void LLVMSetUnnamedAddr(LLVMValueRef Global, LLVMBool HasUnnamedAddr);

// Metadata used by DataView's physical-column alias contract. These are part
// of LLVM-C 22 just like the builder calls below; the fallback declarations
// keep packaged Windows toolchains equivalent to builds using real headers.
LLVMMetadataRef LLVMMDStringInContext2(LLVMContextRef C, const char *Str,
                                       size_t SLen);
LLVMMetadataRef LLVMMDNodeInContext2(LLVMContextRef C, LLVMMetadataRef *MDs,
                                     size_t Count);
LLVMValueRef LLVMMetadataAsValue(LLVMContextRef C, LLVMMetadataRef MD);
LLVMMetadataRef LLVMValueAsMetadata(LLVMValueRef Val);
unsigned LLVMGetMDKindIDInContext(LLVMContextRef C, const char *Name,
                                  unsigned SLen);
void LLVMSetMetadata(LLVMValueRef Val, unsigned KindID, LLVMValueRef Node);

// --- basic blocks -----------------------------------------------------------
LLVMBasicBlockRef LLVMAppendBasicBlockInContext(LLVMContextRef C, LLVMValueRef Fn,
                                                const char *Name);
void LLVMPositionBuilderAtEnd(LLVMBuilderRef Builder, LLVMBasicBlockRef Block);
void LLVMPositionBuilderBefore(LLVMBuilderRef Builder, LLVMValueRef Instr);
LLVMBasicBlockRef LLVMGetInsertBlock(LLVMBuilderRef Builder);
LLVMValueRef LLVMGetBasicBlockTerminator(LLVMBasicBlockRef BB);
LLVMValueRef LLVMGetBasicBlockParent(LLVMBasicBlockRef BB);

// --- instructions -----------------------------------------------------------
LLVMValueRef LLVMBuildAdd(LLVMBuilderRef, LLVMValueRef, LLVMValueRef, const char *Name);
LLVMValueRef LLVMBuildSub(LLVMBuilderRef, LLVMValueRef, LLVMValueRef, const char *Name);
LLVMValueRef LLVMBuildMul(LLVMBuilderRef, LLVMValueRef, LLVMValueRef, const char *Name);
LLVMValueRef LLVMBuildSDiv(LLVMBuilderRef, LLVMValueRef, LLVMValueRef, const char *Name);
LLVMValueRef LLVMBuildUDiv(LLVMBuilderRef, LLVMValueRef, LLVMValueRef, const char *Name);
LLVMValueRef LLVMBuildSRem(LLVMBuilderRef, LLVMValueRef, LLVMValueRef, const char *Name);
LLVMValueRef LLVMBuildURem(LLVMBuilderRef, LLVMValueRef, LLVMValueRef, const char *Name);
LLVMValueRef LLVMBuildFAdd(LLVMBuilderRef, LLVMValueRef, LLVMValueRef, const char *Name);
LLVMValueRef LLVMBuildFSub(LLVMBuilderRef, LLVMValueRef, LLVMValueRef, const char *Name);
LLVMValueRef LLVMBuildFMul(LLVMBuilderRef, LLVMValueRef, LLVMValueRef, const char *Name);
LLVMValueRef LLVMBuildFDiv(LLVMBuilderRef, LLVMValueRef, LLVMValueRef, const char *Name);
LLVMValueRef LLVMBuildAnd(LLVMBuilderRef, LLVMValueRef, LLVMValueRef, const char *Name);
LLVMValueRef LLVMBuildOr(LLVMBuilderRef, LLVMValueRef, LLVMValueRef, const char *Name);
LLVMValueRef LLVMBuildXor(LLVMBuilderRef, LLVMValueRef, LLVMValueRef, const char *Name);
LLVMValueRef LLVMBuildShl(LLVMBuilderRef, LLVMValueRef, LLVMValueRef, const char *Name);
LLVMValueRef LLVMBuildLShr(LLVMBuilderRef, LLVMValueRef, LLVMValueRef, const char *Name);
LLVMValueRef LLVMBuildAShr(LLVMBuilderRef, LLVMValueRef, LLVMValueRef, const char *Name);
LLVMValueRef LLVMBuildNeg(LLVMBuilderRef, LLVMValueRef, const char *Name);
LLVMValueRef LLVMBuildFNeg(LLVMBuilderRef, LLVMValueRef, const char *Name);
LLVMValueRef LLVMBuildNot(LLVMBuilderRef, LLVMValueRef, const char *Name);
LLVMValueRef LLVMBuildICmp(LLVMBuilderRef, int Op, LLVMValueRef LHS, LLVMValueRef RHS,
                           const char *Name);
LLVMValueRef LLVMBuildFCmp(LLVMBuilderRef, int Op, LLVMValueRef LHS, LLVMValueRef RHS,
                           const char *Name);
LLVMValueRef LLVMBuildAlloca(LLVMBuilderRef, LLVMTypeRef Ty, const char *Name);
LLVMValueRef LLVMBuildArrayAlloca(LLVMBuilderRef, LLVMTypeRef Ty, LLVMValueRef Val,
                                  const char *Name);
LLVMValueRef LLVMBuildLoad2(LLVMBuilderRef, LLVMTypeRef Ty, LLVMValueRef PointerVal,
                            const char *Name);
LLVMValueRef LLVMBuildStore(LLVMBuilderRef, LLVMValueRef Val, LLVMValueRef Ptr);

// First-class aggregates, for the fat `String` -- see the note over `ir_undef`
// in llvm-api-backend.c. Declared here as well as used there because this header
// is the LLVM C API as the *packaging* build sees it: `tools/package.sh` compiles
// the backend without -DPRISMIO_LLVM_REAL_HEADERS, so anything missing from this
// shim is an implicit declaration and a hard error there while the bootstrap,
// which does use the real headers, builds cleanly. That asymmetry is why the
// test suite packages a toolchain rather than trusting a successful bootstrap.
// Type introspection, for the fat-String coercion in `coerce_for`. The enum is
// spelled out rather than included: this header is the LLVM C API as the
// *packaging* build sees it, and it deliberately declares only what the backend
// uses. LLVMStructTypeKind is 5 in llvm-c/Core.h and has been since the enum was
// introduced -- it is append-only, so the ordinal is stable.
typedef enum { PRISMIO_LLVM_STRUCT_TYPE_KIND = 5 } PrismioLLVMTypeKindProbe;
#define LLVMStructTypeKind PRISMIO_LLVM_STRUCT_TYPE_KIND
#define LLVMPointerTypeKind 12
// LLVMIntegerTypeKind is 8, from the same append-only enum and stable for the
// same reason. Read by the checked-arithmetic path, which is overloaded on the
// integer width and must refuse anything that has none.
#define LLVMIntegerTypeKind 8
int LLVMGetTypeKind(LLVMTypeRef Ty);
unsigned LLVMGetIntTypeWidth(LLVMTypeRef IntegerTy);
const char *LLVMGetStructName(LLVMTypeRef Ty);

// The anonymous struct the overflow intrinsics return -- `{iN, i1}`. Distinct
// from LLVMStructTypeInContext's named sibling used for nominal types: this one
// is structural, which is what the intrinsic signature wants.
LLVMTypeRef LLVMStructTypeInContext(LLVMContextRef C, LLVMTypeRef *ElementTypes,
                                    unsigned ElementCount, LLVMBool Packed);

LLVMValueRef LLVMGetUndef(LLVMTypeRef Ty);
LLVMBool LLVMIsConstant(LLVMValueRef Val);
LLVMValueRef LLVMGetAggregateElement(LLVMValueRef C, unsigned Idx);
LLVMValueRef LLVMBuildInsertValue(LLVMBuilderRef, LLVMValueRef AggVal,
                                  LLVMValueRef EltVal, unsigned Index,
                                  const char *Name);
LLVMValueRef LLVMBuildExtractValue(LLVMBuilderRef, LLVMValueRef AggVal,
                                   unsigned Index, const char *Name);
LLVMValueRef LLVMConstNamedStruct(LLVMTypeRef StructTy,
                                  LLVMValueRef *ConstantVals, unsigned Count);
// Writing an inline struct field copies bytes rather than storing an address.
//
// The alignment has to be the one LLVM actually placed the field at, not a
// convenient 8: a nested struct of three i32 has ABI alignment 4, so the second
// of two lands at offset 12, and promising 8 there licenses an aligned move that
// faults. LLVMABIAlignmentOfType is the same number LLVMStructSetBody used.
LLVMValueRef LLVMBuildMemCpy(LLVMBuilderRef, LLVMValueRef Dst, unsigned DstAlign,
                             LLVMValueRef Src, unsigned SrcAlign, LLVMValueRef Size);
// SPEC 5.1's `unique` on a parameter, lowered as the aliasing fact it already
// asserts. Parameter indices are 1-based; 0 is the return value.
typedef struct LLVMOpaqueAttributeRef *LLVMAttributeRef;
unsigned LLVMGetEnumAttributeKindForName(const char *Name, size_t SLen);
LLVMAttributeRef LLVMCreateEnumAttribute(LLVMContextRef, unsigned KindID, unsigned long long Val);
void LLVMAddAttributeAtIndex(LLVMValueRef F, unsigned Idx, LLVMAttributeRef A);
typedef struct LLVMOpaqueTargetData *LLVMTargetDataRef;
LLVMTargetDataRef LLVMGetModuleDataLayout(LLVMModuleRef M);
unsigned LLVMABIAlignmentOfType(LLVMTargetDataRef, LLVMTypeRef Ty);
// M4.2. The bytes one element of an inline container occupies, which is the
// number the container is stamped with at construction. Read from the module's
// data layout, so a --target build sizes for the target.
unsigned long long LLVMABISizeOfType(LLVMTargetDataRef, LLVMTypeRef Ty);
// LAYOUT 6's hot/cold split. A T3 object's cold block is reached from the
// *runtime*, which has only a pointer and a byte offset -- so rc_alloc's spare
// header word is told where in the hot record the link sits, and that number is
// the one LLVM placed it at rather than a recomputed guess. Same reason
// LLVMABIAlignmentOfType is read back above.
unsigned long long LLVMOffsetOfElement(LLVMTargetDataRef, LLVMTypeRef StructTy,
                                       unsigned Element);
LLVMValueRef LLVMBuildGEP2(LLVMBuilderRef, LLVMTypeRef Ty, LLVMValueRef Pointer,
                           LLVMValueRef *Indices, unsigned NumIndices, const char *Name);
LLVMValueRef LLVMBuildInBoundsGEP2(LLVMBuilderRef, LLVMTypeRef Ty, LLVMValueRef Pointer,
                                   LLVMValueRef *Indices, unsigned NumIndices,
                                   const char *Name);
LLVMValueRef LLVMBuildStructGEP2(LLVMBuilderRef, LLVMTypeRef Ty, LLVMValueRef Pointer,
                                 unsigned Idx, const char *Name);
LLVMValueRef LLVMBuildCall2(LLVMBuilderRef, LLVMTypeRef, LLVMValueRef Fn,
                            LLVMValueRef *Args, unsigned NumArgs, const char *Name);
LLVMValueRef LLVMBuildRet(LLVMBuilderRef, LLVMValueRef V);
LLVMValueRef LLVMBuildRetVoid(LLVMBuilderRef);
LLVMValueRef LLVMBuildBr(LLVMBuilderRef, LLVMBasicBlockRef Dest);
LLVMValueRef LLVMBuildCondBr(LLVMBuilderRef, LLVMValueRef If, LLVMBasicBlockRef Then,
                             LLVMBasicBlockRef Else);
LLVMValueRef LLVMBuildUnreachable(LLVMBuilderRef);
// The flat-`List` element view's two merges (ir_list_flat_elem). `select` picks
// between an in-range address and null without a branch, and the `phi` joins the
// flat and boxed arms -- the only phi codegen builds, because every other merge
// in this backend is a store to an alloca that mem2reg promotes.
LLVMValueRef LLVMBuildSelect(LLVMBuilderRef, LLVMValueRef If, LLVMValueRef Then,
                             LLVMValueRef Else, const char *Name);
LLVMValueRef LLVMBuildPhi(LLVMBuilderRef, LLVMTypeRef Ty, const char *Name);
void LLVMAddIncoming(LLVMValueRef PhiNode, LLVMValueRef *IncomingValues,
                     LLVMBasicBlockRef *IncomingBlocks, unsigned Count);
LLVMValueRef LLVMBuildZExt(LLVMBuilderRef, LLVMValueRef Val, LLVMTypeRef DestTy,
                           const char *Name);
LLVMValueRef LLVMBuildSExt(LLVMBuilderRef, LLVMValueRef Val, LLVMTypeRef DestTy,
                           const char *Name);
LLVMValueRef LLVMBuildTrunc(LLVMBuilderRef, LLVMValueRef Val, LLVMTypeRef DestTy,
                            const char *Name);
LLVMValueRef LLVMBuildPtrToInt(LLVMBuilderRef, LLVMValueRef Val, LLVMTypeRef DestTy,
                               const char *Name);
LLVMValueRef LLVMBuildIntToPtr(LLVMBuilderRef, LLVMValueRef Val, LLVMTypeRef DestTy,
                               const char *Name);
LLVMValueRef LLVMBuildBitCast(LLVMBuilderRef, LLVMValueRef Val, LLVMTypeRef DestTy,
                              const char *Name);
LLVMValueRef LLVMBuildSIToFP(LLVMBuilderRef, LLVMValueRef Val, LLVMTypeRef DestTy,
                             const char *Name);
LLVMValueRef LLVMBuildUIToFP(LLVMBuilderRef, LLVMValueRef Val, LLVMTypeRef DestTy,
                             const char *Name);
LLVMValueRef LLVMBuildFPToSI(LLVMBuilderRef, LLVMValueRef Val, LLVMTypeRef DestTy,
                             const char *Name);
LLVMValueRef LLVMBuildFPToUI(LLVMBuilderRef, LLVMValueRef Val, LLVMTypeRef DestTy,
                             const char *Name);
LLVMValueRef LLVMBuildGlobalStringPtr(LLVMBuilderRef, const char *Str, const char *Name);

// --- output / diagnostics ---------------------------------------------------
LLVMBool LLVMVerifyModule(LLVMModuleRef M, int Action, char **OutMessage);

// Merging the curated inlinable module into the program's (M1.1). One function,
// with a plain shape -- two opaque module handles and an int result -- which is
// why it is transcribable here where LLJIT and DIBuilder are not. It *consumes*
// Src whether it succeeds or fails; ir_link_modules is written around that.
LLVMBool LLVMLinkModules2(LLVMModuleRef Dest, LLVMModuleRef Src);
LLVMBool LLVMPrintModuleToFile(LLVMModuleRef M, const char *Filename, char **ErrorMessage);
char *LLVMPrintModuleToString(LLVMModuleRef M);
void LLVMDisposeMessage(char *Message);
void LLVMGetVersion(unsigned *Major, unsigned *Minor, unsigned *Patch);

// --- optimization (new pass manager) ----------------------------------------
typedef struct LLVMOpaqueError *LLVMErrorRef;
typedef struct LLVMOpaqueTargetMachine *LLVMTargetMachineRef;
typedef struct LLVMOpaquePassBuilderOptions *LLVMPassBuilderOptionsRef;

LLVMPassBuilderOptionsRef LLVMCreatePassBuilderOptions(void);
void LLVMDisposePassBuilderOptions(LLVMPassBuilderOptionsRef Options);
LLVMErrorRef LLVMRunPasses(LLVMModuleRef M, const char *Passes,
                           LLVMTargetMachineRef TM, LLVMPassBuilderOptionsRef Options);
char *LLVMGetErrorMessage(LLVMErrorRef Err);

#ifdef __cplusplus
}
#endif

#endif // PRISMIO_LLVM_REAL_HEADERS

#endif // PRISMIO_LLVM_H
