// Smoke test for the LLVM C API backend.
//
// Drives the ir_* surface the same way src/ir.psm does -- handles in, handles
// out -- and checks that a module built entirely through the API passes
// LLVMVerifyModule and comes back out as valid IR.
//
// Build (Windows, with the LLVM install that ships LLVM-C.lib):
//   clang -DPRISMIO_BACKEND_LLVM_API test_llvm_backend.c llvm-api-backend.c \
//         -I. -o test_llvm_backend.exe -L"C:/Program Files/LLVM/lib" -lLLVM-C

#include <stdio.h>
#include <string.h>

// The backend's Prismio-facing surface (mirrors src/bridge.psm).
void ir_module_start(const char *);
void ir_module_end(void);
void ir_declare_function_begin(const char *, const char *);
void ir_declare_function_param(const char *);
void ir_declare_function_end(void);
void ir_function_begin(const char *, const char *);
void ir_function_param(const char *, const char *);
void ir_function_body_start(void);
void ir_function_end(void);
int ir_alloca(const char *, const char *);
int ir_load(const char *, const char *);
void ir_store(const char *, const char *, const char *);
int ir_load_ptr(const char *, const char *);
void ir_store_ptr(const char *, const char *, const char *);
int ir_struct_load_ptr(const char *, const char *, const char *, int);
void ir_struct_store_ptr(const char *, const char *, const char *, const char *, int);
int ir_add(const char *, const char *, const char *);
int ir_mul(const char *, const char *, const char *);
int ir_icmp_slt(const char *, const char *, const char *);
int ir_get_label(void);
void ir_label_numbered(int);
void ir_br_numbered(int);
void ir_cond_br_numbered(const char *, int, int);
void ir_ret(const char *, const char *);
void ir_ret_void(void);
void ir_call_begin(void);
void ir_call_arg(const char *, const char *);
int ir_call_end(const char *, const char *);
const char *ir_get_temp_name(int);
void ir_global_string(const char *, const char *);
int ir_string_ptr(const char *);
void ir_global_var(const char *, const char *, const char *, int);
void ir_struct_type_begin(const char *);
void ir_struct_type_field(const char *);
void ir_struct_type_end(void);
int ir_alloc_object(const char *);
void ir_free_object(const char *);
int ir_struct_field_ptr(const char *, const char *, int);
int ir_array_alloca(const char *, int);
int ir_elem_ptr(const char *, const char *, const char *);
int ir_zext(const char *, const char *, const char *);
int ir_write_file(const char *);
void ir_print(void);
void ir_set_alloc_function(const char *);

int main(void) {
    ir_module_start("smoke");

    // struct Point { x: Int, y: Int }
    ir_struct_type_begin("Point");
    ir_struct_type_field("i32");
    ir_struct_type_field("i32");
    ir_struct_type_end();

    // runtime declarations
    ir_declare_function_begin("println_int", "void");
    ir_declare_function_param("i32");
    ir_declare_function_end();

    ir_declare_function_begin("println", "void");
    ir_declare_function_param("ptr");
    ir_declare_function_end();

    ir_global_string(".str.s0", "hello from the api backend");
    ir_global_var("counter", "i32", "7", 0);

    // fn add_scaled(a: Int, b: Int) -> Int
    ir_function_begin("add_scaled", "i32");
    ir_function_param("i32", "p_a");
    ir_function_param("i32", "p_b");
    ir_function_body_start();

    ir_alloca("i32", "a");
    ir_alloca("i32", "b");
    ir_store("i32", "%p_a", "a");
    ir_store("i32", "%p_b", "b");

    int va = ir_load("i32", "a");
    int vb = ir_load("i32", "b");
    int scaled = ir_mul("i32", ir_get_temp_name(vb), "3"); // literal passes straight through
    int sum = ir_add("i32", ir_get_temp_name(va), ir_get_temp_name(scaled));
    ir_ret("i32", ir_get_temp_name(sum));
    ir_function_end();

    // fn main() -> Int, exercising control flow, calls, objects and arrays
    ir_function_begin("main", "i32");
    ir_function_body_start();

    ir_alloca("i32", "i");
    ir_store("i32", "0", "i");

    // print a string constant
    int sp = ir_string_ptr(".str.s0");
    ir_call_begin();
    ir_call_arg("ptr", ir_get_temp_name(sp));
    ir_call_end("void", "println");

    // an object through the allocation policy, then store both fields and read
    // one back -- this is what a struct literal plus a field access lowers to
    int obj = ir_alloc_object("Point");
    int fx = ir_struct_field_ptr("Point", ir_get_temp_name(obj), 0);
    ir_struct_store_ptr("i32", "11", ir_get_temp_name(fx), "Point", 0);
    int fy = ir_struct_field_ptr("Point", ir_get_temp_name(obj), 1);
    ir_struct_store_ptr("i32", "22", ir_get_temp_name(fy), "Point", 1);
    int read_x = ir_struct_load_ptr("i32", ir_get_temp_name(fx), "Point", 0);
    ir_call_begin();
    ir_call_arg("i32", ir_get_temp_name(read_x));
    ir_call_end("void", "println_int");

    // array of 3 i32: write index 1, read it back
    int arr = ir_array_alloca("i32", 3);
    int slot = ir_elem_ptr("i32", ir_get_temp_name(arr), "1");
    ir_store_ptr("i32", "99", ir_get_temp_name(slot));
    int elem = ir_load_ptr("i32", ir_get_temp_name(slot));
    ir_call_begin();
    ir_call_arg("i32", ir_get_temp_name(elem));
    ir_call_end("void", "println_int");

    // a loop: while (i < 3) { i = i + 1 }
    int cond_l = ir_get_label();
    int body_l = ir_get_label();
    int end_l = ir_get_label();

    ir_br_numbered(cond_l);
    ir_label_numbered(cond_l);
    int iv = ir_load("i32", "i");
    int cmp = ir_icmp_slt("i32", ir_get_temp_name(iv), "3");
    ir_cond_br_numbered(ir_get_temp_name(cmp), body_l, end_l);

    ir_label_numbered(body_l);
    int iv2 = ir_load("i32", "i");
    int next = ir_add("i32", ir_get_temp_name(iv2), "1");
    ir_store("i32", ir_get_temp_name(next), "i");
    ir_br_numbered(cond_l);

    ir_label_numbered(end_l);

    // call the other function and print the result
    ir_call_begin();
    ir_call_arg("i32", "4");
    ir_call_arg("i32", "5");
    int called = ir_call_end("i32", "add_scaled");

    ir_call_begin();
    ir_call_arg("i32", ir_get_temp_name(called));
    ir_call_end("void", "println_int");

    // release the object through the policy
    ir_free_object(ir_get_temp_name(obj));

    ir_ret("i32", "0");
    ir_function_end();

    ir_module_end();

    printf("=== generated module ===\n");
    ir_print();

    printf("=== verify + write ===\n");
    int rc = ir_write_file("smoke_out.ll");
    printf("ir_write_file -> %d (%s)\n", rc, rc == 0 ? "verified clean" : "FAILED");
    return rc;
}
