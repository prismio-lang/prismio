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
#include <llvm-c/Core.h>
#include <llvm-c/Target.h>
#include <llvm-c/TargetMachine.h>

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

// --- basic blocks -----------------------------------------------------------
LLVMBasicBlockRef LLVMAppendBasicBlockInContext(LLVMContextRef C, LLVMValueRef Fn,
                                                const char *Name);
void LLVMPositionBuilderAtEnd(LLVMBuilderRef Builder, LLVMBasicBlockRef Block);
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
LLVMValueRef LLVMBuildZExt(LLVMBuilderRef, LLVMValueRef Val, LLVMTypeRef DestTy,
                           const char *Name);
LLVMValueRef LLVMBuildSExt(LLVMBuilderRef, LLVMValueRef Val, LLVMTypeRef DestTy,
                           const char *Name);
LLVMValueRef LLVMBuildTrunc(LLVMBuilderRef, LLVMValueRef Val, LLVMTypeRef DestTy,
                            const char *Name);
LLVMValueRef LLVMBuildPtrToInt(LLVMBuilderRef, LLVMValueRef Val, LLVMTypeRef DestTy,
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
LLVMBool LLVMPrintModuleToFile(LLVMModuleRef M, const char *Filename, char **ErrorMessage);
char *LLVMPrintModuleToString(LLVMModuleRef M);
void LLVMDisposeMessage(char *Message);
void LLVMGetVersion(unsigned *Major, unsigned *Minor, unsigned *Patch);

#ifdef __cplusplus
}
#endif

#endif // PRISMIO_LLVM_REAL_HEADERS

#endif // PRISMIO_LLVM_H
