; Prismio bootstrap seed -- LLVM IR for the Prismio compiler (src/main.psm).
;
; Generated on Windows by a compiler that had reached a byte-identical gen1/gen2
; fixed point. Committed because a new platform has no prismio binary to compile
; src/main.psm with, and this is the smallest artifact that breaks that cycle.
;
; Deliberately carries no 'target triple' or 'target datalayout' line, so llc
; targets whatever host it runs on. That is safe here because the IR is entirely
; target-neutral: every function signature uses only i1/i8/i32/ptr/void, no struct
; is passed by value, and there are no byval/sret attributes or target intrinsics.
;
; Rebuild with: tools/refresh_seed.ps1
;
; ModuleID = 'self_hosted_module'
source_filename = "prismio_generated"

%Token = type { i32, ptr, i32, ptr }
%Lexer = type { ptr, i32, i32, i32 }
%ASTNode = type { i32, ptr, ptr, i32, i32, ptr, ptr, ptr, ptr, ptr }
%Parser = type { ptr }
%TypeInfo = type { i32, ptr, ptr, ptr, ptr }

@prismio_argc =  global i32 0
@prismio_argv =  global ptr null
declare ptr @malloc(i64)
declare void @free(ptr)
declare ptr @list_new()
declare void @list_push(ptr, ptr)
declare ptr @list_get(ptr, i32)
declare void @list_set(ptr, i32, ptr)
declare i32 @list_len(ptr)
declare void @println(ptr)
declare void @print(ptr)
declare void @println_int(i32)
declare void @print_int(i32)
declare void @println_float(double)
declare void @print_float(double)
declare void @println_bool(i32)
declare void @print_bool(i32)
declare void @println_char(i8)
declare void @print_char(i8)

@.str.s0 = private unnamed_addr constant [7 x i8] c"STRING\00"
@.str.s1 = private unnamed_addr constant [5 x i8] c"CHAR\00"
@.str.s2 = private unnamed_addr constant [7 x i8] c"NUMBER\00"
@.str.s3 = private unnamed_addr constant [6 x i8] c"FLOAT\00"
@.str.s4 = private unnamed_addr constant [5 x i8] c"BOOL\00"
@.str.s5 = private unnamed_addr constant [11 x i8] c"IDENTIFIER\00"
@.str.s6 = private unnamed_addr constant [8 x i8] c"KEYWORD\00"
@.str.s7 = private unnamed_addr constant [10 x i8] c"SEPARATOR\00"
@.str.s8 = private unnamed_addr constant [9 x i8] c"OPERATOR\00"
@.str.s9 = private unnamed_addr constant [7 x i8] c"REL_OP\00"
@.str.s10 = private unnamed_addr constant [10 x i8] c"ASSIGN_OP\00"
@.str.s11 = private unnamed_addr constant [6 x i8] c"ARROW\00"
@.str.s12 = private unnamed_addr constant [4 x i8] c"EOF\00"
@.str.s13 = private unnamed_addr constant [6 x i8] c"TOKEN\00"
declare i32 @str_equals(ptr, ptr)
declare i32 @str_length(ptr)
declare ptr @str_concat(ptr, ptr)
declare ptr @str_substring(ptr, i32, i32)
declare i8 @str_char_at(ptr, i32)
declare i32 @str_contains(ptr, ptr)
declare i32 @str_starts_with(ptr, ptr)
declare i32 @str_index_of(ptr, ptr)
declare ptr @int_to_str(i32)
declare i32 @str_to_int(ptr)
@.str.s14 = private unnamed_addr constant [7 x i8] c"import\00"
@.str.s15 = private unnamed_addr constant [6 x i8] c"match\00"
@.str.s16 = private unnamed_addr constant [3 x i8] c"if\00"
@.str.s17 = private unnamed_addr constant [5 x i8] c"else\00"
@.str.s18 = private unnamed_addr constant [4 x i8] c"and\00"
@.str.s19 = private unnamed_addr constant [3 x i8] c"or\00"
@.str.s20 = private unnamed_addr constant [5 x i8] c"true\00"
@.str.s21 = private unnamed_addr constant [6 x i8] c"false\00"
@.str.s22 = private unnamed_addr constant [6 x i8] c"break\00"
@.str.s23 = private unnamed_addr constant [9 x i8] c"continue\00"
@.str.s24 = private unnamed_addr constant [7 x i8] c"return\00"
@.str.s25 = private unnamed_addr constant [6 x i8] c"throw\00"
@.str.s26 = private unnamed_addr constant [6 x i8] c"while\00"
@.str.s27 = private unnamed_addr constant [5 x i8] c"loop\00"
@.str.s28 = private unnamed_addr constant [4 x i8] c"for\00"
@.str.s29 = private unnamed_addr constant [3 x i8] c"in\00"
@.str.s30 = private unnamed_addr constant [4 x i8] c"let\00"
@.str.s31 = private unnamed_addr constant [7 x i8] c"struct\00"
@.str.s32 = private unnamed_addr constant [5 x i8] c"impl\00"
@.str.s33 = private unnamed_addr constant [5 x i8] c"enum\00"
@.str.s34 = private unnamed_addr constant [6 x i8] c"trait\00"
@.str.s35 = private unnamed_addr constant [3 x i8] c"fn\00"
@.str.s36 = private unnamed_addr constant [7 x i8] c"extern\00"
@.str.s37 = private unnamed_addr constant [4 x i8] c"mut\00"
@.str.s38 = private unnamed_addr constant [6 x i8] c"inout\00"
@.str.s39 = private unnamed_addr constant [5 x i8] c"sink\00"
@.str.s40 = private unnamed_addr constant [5 x i8] c"true\00"
@.str.s41 = private unnamed_addr constant [6 x i8] c"false\00"
@.str.s42 = private unnamed_addr constant [4 x i8] c"EOF\00"
@.str.s43 = private unnamed_addr constant [1 x i8] c"\00"
@.str.s44 = private unnamed_addr constant [1 x i8] c"\00"
@.str.s45 = private unnamed_addr constant [1 x i8] c"\00"
@.str.s46 = private unnamed_addr constant [1 x i8] c"\00"
@.str.s47 = private unnamed_addr constant [1 x i8] c"\00"
@.str.s48 = private unnamed_addr constant [1 x i8] c"\00"
@.str.s49 = private unnamed_addr constant [1 x i8] c"\00"
@.str.s50 = private unnamed_addr constant [1 x i8] c"\00"
@.str.s51 = private unnamed_addr constant [3 x i8] c"==\00"
@.str.s52 = private unnamed_addr constant [3 x i8] c"!=\00"
@.str.s53 = private unnamed_addr constant [3 x i8] c"<=\00"
@.str.s54 = private unnamed_addr constant [3 x i8] c">=\00"
@.str.s55 = private unnamed_addr constant [3 x i8] c"->\00"
@.str.s56 = private unnamed_addr constant [3 x i8] c"=>\00"
@.str.s57 = private unnamed_addr constant [3 x i8] c"=>\00"
@.str.s58 = private unnamed_addr constant [1 x i8] c"\00"
@.str.s59 = private unnamed_addr constant [3 x i8] c"..\00"
@.str.s60 = private unnamed_addr constant [1 x i8] c"\00"
@.str.s61 = private unnamed_addr constant [1 x i8] c"\00"
@.str.s62 = private unnamed_addr constant [2 x i8] c"?\00"
@.str.s63 = private unnamed_addr constant [1 x i8] c"\00"
declare ptr @ptr_to_token(ptr)
declare ptr @token_to_ptr(ptr)
declare ptr @ptr_to_node(ptr)
declare ptr @node_to_ptr(ptr)
@.str.s64 = private unnamed_addr constant [1 x i8] c"\00"
@.str.s65 = private unnamed_addr constant [1 x i8] c"\00"
@.str.s66 = private unnamed_addr constant [1 x i8] c"\00"
@.str.s67 = private unnamed_addr constant [1 x i8] c"\00"
@.str.s68 = private unnamed_addr constant [1 x i8] c"\00"
@.str.s69 = private unnamed_addr constant [1 x i8] c"\00"
@.str.s70 = private unnamed_addr constant [1 x i8] c"\00"
@parser_allow_struct_lit =  global i32 1
declare void @exit(i32)
@.str.s71 = private unnamed_addr constant [10 x i8] c"Error in \00"
@.str.s72 = private unnamed_addr constant [23 x i8] c": Expected token type \00"
@.str.s73 = private unnamed_addr constant [10 x i8] c"Error in \00"
@.str.s74 = private unnamed_addr constant [19 x i8] c": Expected token '\00"
@.str.s75 = private unnamed_addr constant [2 x i8] c"'\00"
@.str.s76 = private unnamed_addr constant [7 x i8] c"import\00"
@.str.s77 = private unnamed_addr constant [17 x i8] c"import statement\00"
@.str.s78 = private unnamed_addr constant [21 x i8] c"Expected module name\00"
@.str.s79 = private unnamed_addr constant [7 x i8] c"import\00"
@.str.s80 = private unnamed_addr constant [4 x i8] c"let\00"
@.str.s81 = private unnamed_addr constant [7 x i8] c"extern\00"
@.str.s82 = private unnamed_addr constant [3 x i8] c"fn\00"
@.str.s83 = private unnamed_addr constant [7 x i8] c"struct\00"
@.str.s84 = private unnamed_addr constant [5 x i8] c"enum\00"
@.str.s85 = private unnamed_addr constant [20 x i8] c"Unknown declaration\00"
@.str.s86 = private unnamed_addr constant [2 x i8] c"[\00"
@.str.s87 = private unnamed_addr constant [2 x i8] c"]\00"
@.str.s88 = private unnamed_addr constant [11 x i8] c"array type\00"
@.str.s89 = private unnamed_addr constant [19 x i8] c"Expected type name\00"
@.str.s90 = private unnamed_addr constant [5 x i8] c"List\00"
@.str.s91 = private unnamed_addr constant [2 x i8] c"<\00"
@.str.s92 = private unnamed_addr constant [2 x i8] c">\00"
@.str.s93 = private unnamed_addr constant [19 x i8] c"list type argument\00"
@.str.s94 = private unnamed_addr constant [4 x i8] c"let\00"
@.str.s95 = private unnamed_addr constant [21 x i8] c"variable declaration\00"
@.str.s96 = private unnamed_addr constant [4 x i8] c"mut\00"
@.str.s97 = private unnamed_addr constant [14 x i8] c"variable name\00"
@.str.s98 = private unnamed_addr constant [2 x i8] c":\00"
@.str.s99 = private unnamed_addr constant [2 x i8] c"=\00"
@.str.s100 = private unnamed_addr constant [7 x i8] c"extern\00"
@.str.s101 = private unnamed_addr constant [10 x i8] c"extern fn\00"
@.str.s102 = private unnamed_addr constant [3 x i8] c"fn\00"
@.str.s103 = private unnamed_addr constant [10 x i8] c"extern fn\00"
@.str.s104 = private unnamed_addr constant [14 x i8] c"function name\00"
@.str.s105 = private unnamed_addr constant [2 x i8] c"(\00"
@.str.s106 = private unnamed_addr constant [7 x i8] c"params\00"
@.str.s107 = private unnamed_addr constant [1 x i8] c"\00"
@.str.s108 = private unnamed_addr constant [2 x i8] c")\00"
@.str.s109 = private unnamed_addr constant [15 x i8] c"parameter name\00"
@.str.s110 = private unnamed_addr constant [2 x i8] c":\00"
@.str.s111 = private unnamed_addr constant [15 x i8] c"parameter type\00"
@.str.s112 = private unnamed_addr constant [1 x i8] c"\00"
@.str.s113 = private unnamed_addr constant [2 x i8] c",\00"
@.str.s114 = private unnamed_addr constant [2 x i8] c")\00"
@.str.s115 = private unnamed_addr constant [7 x i8] c"params\00"
@.str.s116 = private unnamed_addr constant [3 x i8] c"->\00"
@.str.s117 = private unnamed_addr constant [3 x i8] c"fn\00"
@.str.s118 = private unnamed_addr constant [9 x i8] c"function\00"
@.str.s119 = private unnamed_addr constant [14 x i8] c"function name\00"
@.str.s120 = private unnamed_addr constant [2 x i8] c"(\00"
@.str.s121 = private unnamed_addr constant [7 x i8] c"params\00"
@.str.s122 = private unnamed_addr constant [1 x i8] c"\00"
@.str.s123 = private unnamed_addr constant [2 x i8] c")\00"
@.str.s124 = private unnamed_addr constant [5 x i8] c"sink\00"
@.str.s125 = private unnamed_addr constant [5 x i8] c"sink\00"
@.str.s126 = private unnamed_addr constant [6 x i8] c"inout\00"
@.str.s127 = private unnamed_addr constant [6 x i8] c"inout\00"
@.str.s128 = private unnamed_addr constant [15 x i8] c"parameter name\00"
@.str.s129 = private unnamed_addr constant [2 x i8] c":\00"
@.str.s130 = private unnamed_addr constant [15 x i8] c"parameter type\00"
@.str.s131 = private unnamed_addr constant [1 x i8] c"\00"
@.str.s132 = private unnamed_addr constant [2 x i8] c",\00"
@.str.s133 = private unnamed_addr constant [2 x i8] c")\00"
@.str.s134 = private unnamed_addr constant [7 x i8] c"params\00"
@.str.s135 = private unnamed_addr constant [3 x i8] c"->\00"
@.str.s136 = private unnamed_addr constant [7 x i8] c"struct\00"
@.str.s137 = private unnamed_addr constant [7 x i8] c"struct\00"
@.str.s138 = private unnamed_addr constant [12 x i8] c"struct name\00"
@.str.s139 = private unnamed_addr constant [2 x i8] c"{\00"
@.str.s140 = private unnamed_addr constant [12 x i8] c"struct body\00"
@.str.s141 = private unnamed_addr constant [1 x i8] c"\00"
@.str.s142 = private unnamed_addr constant [2 x i8] c"}\00"
@.str.s143 = private unnamed_addr constant [11 x i8] c"field name\00"
@.str.s144 = private unnamed_addr constant [2 x i8] c":\00"
@.str.s145 = private unnamed_addr constant [11 x i8] c"field type\00"
@.str.s146 = private unnamed_addr constant [1 x i8] c"\00"
@.str.s147 = private unnamed_addr constant [2 x i8] c",\00"
@.str.s148 = private unnamed_addr constant [2 x i8] c"}\00"
@.str.s149 = private unnamed_addr constant [12 x i8] c"struct body\00"
@.str.s150 = private unnamed_addr constant [5 x i8] c"enum\00"
@.str.s151 = private unnamed_addr constant [5 x i8] c"enum\00"
@.str.s152 = private unnamed_addr constant [10 x i8] c"enum name\00"
@.str.s153 = private unnamed_addr constant [2 x i8] c"{\00"
@.str.s154 = private unnamed_addr constant [10 x i8] c"enum body\00"
@.str.s155 = private unnamed_addr constant [1 x i8] c"\00"
@.str.s156 = private unnamed_addr constant [2 x i8] c"}\00"
@.str.s157 = private unnamed_addr constant [13 x i8] c"variant name\00"
@.str.s158 = private unnamed_addr constant [1 x i8] c"\00"
@.str.s159 = private unnamed_addr constant [2 x i8] c",\00"
@.str.s160 = private unnamed_addr constant [2 x i8] c"}\00"
@.str.s161 = private unnamed_addr constant [10 x i8] c"enum body\00"
@.str.s162 = private unnamed_addr constant [2 x i8] c"{\00"
@.str.s163 = private unnamed_addr constant [6 x i8] c"block\00"
@.str.s164 = private unnamed_addr constant [1 x i8] c"\00"
@.str.s165 = private unnamed_addr constant [2 x i8] c"}\00"
@.str.s166 = private unnamed_addr constant [1 x i8] c"\00"
@.str.s167 = private unnamed_addr constant [2 x i8] c"}\00"
@.str.s168 = private unnamed_addr constant [6 x i8] c"block\00"
@.str.s169 = private unnamed_addr constant [3 x i8] c"if\00"
@.str.s170 = private unnamed_addr constant [13 x i8] c"if statement\00"
@.str.s171 = private unnamed_addr constant [2 x i8] c"(\00"
@.str.s172 = private unnamed_addr constant [13 x i8] c"if condition\00"
@.str.s173 = private unnamed_addr constant [2 x i8] c")\00"
@.str.s174 = private unnamed_addr constant [13 x i8] c"if condition\00"
@.str.s175 = private unnamed_addr constant [5 x i8] c"else\00"
@.str.s176 = private unnamed_addr constant [3 x i8] c"if\00"
@.str.s177 = private unnamed_addr constant [6 x i8] c"while\00"
@.str.s178 = private unnamed_addr constant [16 x i8] c"while statement\00"
@.str.s179 = private unnamed_addr constant [2 x i8] c"(\00"
@.str.s180 = private unnamed_addr constant [16 x i8] c"while condition\00"
@.str.s181 = private unnamed_addr constant [2 x i8] c")\00"
@.str.s182 = private unnamed_addr constant [16 x i8] c"while condition\00"
@.str.s183 = private unnamed_addr constant [5 x i8] c"loop\00"
@.str.s184 = private unnamed_addr constant [15 x i8] c"loop statement\00"
@.str.s185 = private unnamed_addr constant [4 x i8] c"for\00"
@.str.s186 = private unnamed_addr constant [14 x i8] c"for statement\00"
@.str.s187 = private unnamed_addr constant [18 x i8] c"for loop variable\00"
@.str.s188 = private unnamed_addr constant [3 x i8] c"in\00"
@.str.s189 = private unnamed_addr constant [11 x i8] c"for ... in\00"
@.str.s190 = private unnamed_addr constant [3 x i8] c"..\00"
@.str.s191 = private unnamed_addr constant [10 x i8] c"for range\00"
@.str.s192 = private unnamed_addr constant [2 x i8] c"_\00"
@.str.s193 = private unnamed_addr constant [2 x i8] c"_\00"
@.str.s194 = private unnamed_addr constant [3 x i8] c"=>\00"
@.str.s195 = private unnamed_addr constant [10 x i8] c"match arm\00"
@.str.s196 = private unnamed_addr constant [6 x i8] c"match\00"
@.str.s197 = private unnamed_addr constant [16 x i8] c"match statement\00"
@.str.s198 = private unnamed_addr constant [2 x i8] c"(\00"
@.str.s199 = private unnamed_addr constant [16 x i8] c"match scrutinee\00"
@.str.s200 = private unnamed_addr constant [2 x i8] c")\00"
@.str.s201 = private unnamed_addr constant [16 x i8] c"match scrutinee\00"
@.str.s202 = private unnamed_addr constant [2 x i8] c"{\00"
@.str.s203 = private unnamed_addr constant [11 x i8] c"match body\00"
@.str.s204 = private unnamed_addr constant [1 x i8] c"\00"
@.str.s205 = private unnamed_addr constant [1 x i8] c"\00"
@.str.s206 = private unnamed_addr constant [2 x i8] c"}\00"
@.str.s207 = private unnamed_addr constant [1 x i8] c"\00"
@.str.s208 = private unnamed_addr constant [2 x i8] c",\00"
@.str.s209 = private unnamed_addr constant [2 x i8] c"}\00"
@.str.s210 = private unnamed_addr constant [11 x i8] c"match body\00"
@.str.s211 = private unnamed_addr constant [3 x i8] c"if\00"
@.str.s212 = private unnamed_addr constant [6 x i8] c"while\00"
@.str.s213 = private unnamed_addr constant [5 x i8] c"loop\00"
@.str.s214 = private unnamed_addr constant [6 x i8] c"match\00"
@.str.s215 = private unnamed_addr constant [4 x i8] c"for\00"
@.str.s216 = private unnamed_addr constant [6 x i8] c"break\00"
@.str.s217 = private unnamed_addr constant [9 x i8] c"continue\00"
@.str.s218 = private unnamed_addr constant [7 x i8] c"return\00"
@.str.s219 = private unnamed_addr constant [2 x i8] c"}\00"
@.str.s220 = private unnamed_addr constant [4 x i8] c"let\00"
@.str.s221 = private unnamed_addr constant [2 x i8] c"=\00"
@.str.s222 = private unnamed_addr constant [3 x i8] c"or\00"
@.str.s223 = private unnamed_addr constant [4 x i8] c"and\00"
@.str.s224 = private unnamed_addr constant [3 x i8] c"==\00"
@.str.s225 = private unnamed_addr constant [3 x i8] c"!=\00"
@.str.s226 = private unnamed_addr constant [2 x i8] c"<\00"
@.str.s227 = private unnamed_addr constant [2 x i8] c">\00"
@.str.s228 = private unnamed_addr constant [3 x i8] c"<=\00"
@.str.s229 = private unnamed_addr constant [3 x i8] c">=\00"
@.str.s230 = private unnamed_addr constant [2 x i8] c"+\00"
@.str.s231 = private unnamed_addr constant [2 x i8] c"-\00"
@.str.s232 = private unnamed_addr constant [2 x i8] c"*\00"
@.str.s233 = private unnamed_addr constant [2 x i8] c"/\00"
@.str.s234 = private unnamed_addr constant [2 x i8] c"%\00"
@.str.s235 = private unnamed_addr constant [4 x i8] c"and\00"
@.str.s236 = private unnamed_addr constant [3 x i8] c"or\00"
@.str.s237 = private unnamed_addr constant [2 x i8] c"{\00"
@.str.s238 = private unnamed_addr constant [2 x i8] c"{\00"
@.str.s239 = private unnamed_addr constant [15 x i8] c"struct literal\00"
@.str.s240 = private unnamed_addr constant [1 x i8] c"\00"
@.str.s241 = private unnamed_addr constant [2 x i8] c"}\00"
@.str.s242 = private unnamed_addr constant [21 x i8] c"struct literal field\00"
@.str.s243 = private unnamed_addr constant [2 x i8] c":\00"
@.str.s244 = private unnamed_addr constant [15 x i8] c"struct literal\00"
@.str.s245 = private unnamed_addr constant [1 x i8] c"\00"
@.str.s246 = private unnamed_addr constant [2 x i8] c",\00"
@.str.s247 = private unnamed_addr constant [2 x i8] c"}\00"
@.str.s248 = private unnamed_addr constant [15 x i8] c"struct literal\00"
@.str.s249 = private unnamed_addr constant [2 x i8] c"(\00"
@.str.s250 = private unnamed_addr constant [1 x i8] c"\00"
@.str.s251 = private unnamed_addr constant [2 x i8] c")\00"
@.str.s252 = private unnamed_addr constant [1 x i8] c"\00"
@.str.s253 = private unnamed_addr constant [2 x i8] c",\00"
@.str.s254 = private unnamed_addr constant [2 x i8] c")\00"
@.str.s255 = private unnamed_addr constant [14 x i8] c"function call\00"
@.str.s256 = private unnamed_addr constant [2 x i8] c"[\00"
@.str.s257 = private unnamed_addr constant [2 x i8] c"]\00"
@.str.s258 = private unnamed_addr constant [12 x i8] c"array index\00"
@.str.s259 = private unnamed_addr constant [2 x i8] c".\00"
@.str.s260 = private unnamed_addr constant [12 x i8] c"member name\00"
@.str.s261 = private unnamed_addr constant [2 x i8] c"(\00"
@.str.s262 = private unnamed_addr constant [2 x i8] c")\00"
@.str.s263 = private unnamed_addr constant [25 x i8] c"parenthesized expression\00"
@.str.s264 = private unnamed_addr constant [2 x i8] c"[\00"
@.str.s265 = private unnamed_addr constant [1 x i8] c"\00"
@.str.s266 = private unnamed_addr constant [2 x i8] c"]\00"
@.str.s267 = private unnamed_addr constant [1 x i8] c"\00"
@.str.s268 = private unnamed_addr constant [2 x i8] c",\00"
@.str.s269 = private unnamed_addr constant [2 x i8] c"]\00"
@.str.s270 = private unnamed_addr constant [14 x i8] c"array literal\00"
@.str.s271 = private unnamed_addr constant [33 x i8] c"Unexpected token in expression: \00"
@.str.s272 = private unnamed_addr constant [3 x i8] c" '\00"
@.str.s273 = private unnamed_addr constant [2 x i8] c"'\00"
@.str.s274 = private unnamed_addr constant [1 x i8] c"\00"
@.str.s275 = private unnamed_addr constant [1 x i8] c"\00"
declare void @ir_reset()
declare void @ir_print()
declare i32 @ir_write_file(ptr)
declare void @ir_append(ptr)
declare void @ir_append_line(ptr)
declare i32 @ir_get_temp()
declare void @ir_module_start(ptr)
declare void @ir_module_start_wasm(ptr)
declare void @ir_module_end()
declare ptr @ir_type_void()
declare ptr @ir_type_i1()
declare ptr @ir_type_i8()
declare ptr @ir_type_i32()
declare ptr @ir_type_i64()
declare ptr @ir_type_i8_ptr()
declare void @ir_declare_function_begin(ptr, ptr)
declare void @ir_declare_function_param(ptr)
declare void @ir_declare_function_end()
declare void @ir_function_begin(ptr, ptr)
declare void @ir_function_param(ptr, ptr)
declare void @ir_function_body_start()
declare void @ir_function_end()
declare void @ir_call_begin()
declare void @ir_call_arg(ptr, ptr)
declare i32 @ir_call_end(ptr, ptr)
declare i32 @ir_get_label()
declare void @ir_label(ptr)
declare void @ir_label_numbered(i32)
declare i32 @ir_alloca(ptr, ptr)
declare i32 @ir_load(ptr, ptr)
declare void @ir_store(ptr, ptr, ptr)
declare i32 @ir_load_global(ptr, ptr)
declare void @ir_store_global(ptr, ptr, ptr)
declare i32 @ir_add(ptr, ptr, ptr)
declare i32 @ir_sub(ptr, ptr, ptr)
declare i32 @ir_mul(ptr, ptr, ptr)
declare i32 @ir_sdiv(ptr, ptr, ptr)
declare i32 @ir_srem(ptr, ptr, ptr)
declare i32 @ir_udiv(ptr, ptr, ptr)
declare i32 @ir_urem(ptr, ptr, ptr)
declare i32 @ir_fadd(ptr, ptr, ptr)
declare i32 @ir_fsub(ptr, ptr, ptr)
declare i32 @ir_fmul(ptr, ptr, ptr)
declare i32 @ir_fdiv(ptr, ptr, ptr)
declare i32 @ir_neg(ptr, ptr)
declare i32 @ir_and(ptr, ptr, ptr)
declare i32 @ir_or(ptr, ptr, ptr)
declare i32 @ir_icmp_eq(ptr, ptr, ptr)
declare i32 @ir_icmp_ne(ptr, ptr, ptr)
declare i32 @ir_icmp_slt(ptr, ptr, ptr)
declare i32 @ir_icmp_sle(ptr, ptr, ptr)
declare i32 @ir_icmp_sgt(ptr, ptr, ptr)
declare i32 @ir_icmp_sge(ptr, ptr, ptr)
declare i32 @ir_icmp_ult(ptr, ptr, ptr)
declare i32 @ir_icmp_ule(ptr, ptr, ptr)
declare i32 @ir_icmp_ugt(ptr, ptr, ptr)
declare i32 @ir_icmp_uge(ptr, ptr, ptr)
declare i32 @ir_fcmp_oeq(ptr, ptr, ptr)
declare i32 @ir_fcmp_one(ptr, ptr, ptr)
declare i32 @ir_fcmp_olt(ptr, ptr, ptr)
declare i32 @ir_fcmp_ole(ptr, ptr, ptr)
declare i32 @ir_fcmp_ogt(ptr, ptr, ptr)
declare i32 @ir_fcmp_oge(ptr, ptr, ptr)
declare void @ir_ret(ptr, ptr)
declare void @ir_ret_void()
declare void @ir_br(ptr)
declare void @ir_br_numbered(i32)
declare void @ir_cond_br(ptr, ptr, ptr)
declare void @ir_cond_br_numbered(ptr, i32, i32)
declare void @ir_loop_push(i32, i32)
declare void @ir_loop_pop()
declare i32 @ir_loop_continue_label()
declare i32 @ir_loop_break_label()
declare void @ir_clear_moved()
declare void @ir_mark_moved(ptr)
declare void @ir_unmark_moved(ptr)
declare i32 @ir_is_moved(ptr)
declare void @ir_clear_borrowed()
declare void @ir_mark_borrowed(ptr)
declare i32 @ir_is_borrowed(ptr)
declare void @ir_global_string(ptr, ptr)
declare void @ir_global_var(ptr, ptr, ptr, i32)
declare ptr @ir_get_temp_name(i32)
declare ptr @ir_get_label_name(i32)
declare void @ir_register_global_name(ptr)
declare i32 @ir_is_global_name(ptr)
declare void @ir_reset_globals()
declare void @ir_reset_types()
declare void @ir_register_struct(ptr)
declare void @ir_register_struct_field(ptr, ptr, ptr)
declare i32 @ir_is_struct_type_name(ptr)
declare i32 @ir_get_struct_field_index(ptr, ptr)
declare ptr @ir_get_struct_field_type(ptr, ptr)
declare void @ir_register_enum_variant(ptr, ptr, i32)
declare i32 @ir_get_enum_variant(ptr, ptr)
declare void @ir_set_var_type(ptr, ptr)
declare ptr @ir_get_var_type(ptr)
declare i32 @ir_has_var_type(ptr)
declare void @ir_clear_var_types()
declare void @ir_clear_local_var_types()
declare void @ir_set_returned()
declare i32 @ir_has_returned()
declare void @ir_clear_returned()
declare void @ir_comment(ptr)
declare void @ir_blank_line()
declare ptr @ptr_to_type(ptr)
declare ptr @type_to_ptr(ptr)
@.str.s276 = private unnamed_addr constant [1 x i8] c"\00"
@.str.s277 = private unnamed_addr constant [1 x i8] c"\00"
@.str.s278 = private unnamed_addr constant [8 x i8] c"Invalid\00"
@.str.s279 = private unnamed_addr constant [1 x i8] c"\00"
@.str.s280 = private unnamed_addr constant [5 x i8] c"Void\00"
@.str.s281 = private unnamed_addr constant [5 x i8] c"void\00"
@.str.s282 = private unnamed_addr constant [4 x i8] c"Int\00"
@.str.s283 = private unnamed_addr constant [4 x i8] c"i32\00"
@.str.s284 = private unnamed_addr constant [6 x i8] c"Float\00"
@.str.s285 = private unnamed_addr constant [7 x i8] c"double\00"
@.str.s286 = private unnamed_addr constant [5 x i8] c"Bool\00"
@.str.s287 = private unnamed_addr constant [3 x i8] c"i1\00"
@.str.s288 = private unnamed_addr constant [5 x i8] c"Char\00"
@.str.s289 = private unnamed_addr constant [3 x i8] c"i8\00"
@.str.s290 = private unnamed_addr constant [7 x i8] c"String\00"
@.str.s291 = private unnamed_addr constant [4 x i8] c"ptr\00"
@.str.s292 = private unnamed_addr constant [4 x i8] c"Ptr\00"
@.str.s293 = private unnamed_addr constant [4 x i8] c"ptr\00"
@.str.s294 = private unnamed_addr constant [3 x i8] c"I8\00"
@.str.s295 = private unnamed_addr constant [3 x i8] c"i8\00"
@.str.s296 = private unnamed_addr constant [4 x i8] c"I16\00"
@.str.s297 = private unnamed_addr constant [4 x i8] c"i16\00"
@.str.s298 = private unnamed_addr constant [4 x i8] c"I64\00"
@.str.s299 = private unnamed_addr constant [4 x i8] c"i64\00"
@.str.s300 = private unnamed_addr constant [6 x i8] c"Isize\00"
@.str.s301 = private unnamed_addr constant [4 x i8] c"i64\00"
@.str.s302 = private unnamed_addr constant [3 x i8] c"U8\00"
@.str.s303 = private unnamed_addr constant [3 x i8] c"i8\00"
@.str.s304 = private unnamed_addr constant [4 x i8] c"U16\00"
@.str.s305 = private unnamed_addr constant [4 x i8] c"i16\00"
@.str.s306 = private unnamed_addr constant [4 x i8] c"U32\00"
@.str.s307 = private unnamed_addr constant [4 x i8] c"i32\00"
@.str.s308 = private unnamed_addr constant [4 x i8] c"U64\00"
@.str.s309 = private unnamed_addr constant [4 x i8] c"i64\00"
@.str.s310 = private unnamed_addr constant [6 x i8] c"Usize\00"
@.str.s311 = private unnamed_addr constant [4 x i8] c"i64\00"
@.str.s312 = private unnamed_addr constant [2 x i8] c"U\00"
@.str.s313 = private unnamed_addr constant [4 x i8] c"ptr\00"
@.str.s314 = private unnamed_addr constant [4 x i8] c"i32\00"
@.str.s315 = private unnamed_addr constant [6 x i8] c"Array\00"
@.str.s316 = private unnamed_addr constant [4 x i8] c"ptr\00"
@.str.s317 = private unnamed_addr constant [5 x i8] c"List\00"
@.str.s318 = private unnamed_addr constant [4 x i8] c"ptr\00"
@.str.s319 = private unnamed_addr constant [1 x i8] c"\00"
@.str.s320 = private unnamed_addr constant [2 x i8] c"[\00"
@.str.s321 = private unnamed_addr constant [2 x i8] c"]\00"
@.str.s322 = private unnamed_addr constant [10 x i8] c"[Invalid]\00"
@.str.s323 = private unnamed_addr constant [1 x i8] c"\00"
@.str.s324 = private unnamed_addr constant [6 x i8] c"List<\00"
@.str.s325 = private unnamed_addr constant [2 x i8] c">\00"
@.str.s326 = private unnamed_addr constant [5 x i8] c"List\00"
@.str.s327 = private unnamed_addr constant [1 x i8] c"\00"
@.str.s328 = private unnamed_addr constant [1 x i8] c"\00"
@.str.s329 = private unnamed_addr constant [1 x i8] c"\00"
@.str.s330 = private unnamed_addr constant [1 x i8] c"\00"
@.str.s331 = private unnamed_addr constant [5 x i8] c"void\00"
@.str.s332 = private unnamed_addr constant [7 x i8] c"double\00"
@.str.s333 = private unnamed_addr constant [3 x i8] c"i1\00"
@.str.s334 = private unnamed_addr constant [3 x i8] c"i8\00"
@.str.s335 = private unnamed_addr constant [4 x i8] c"ptr\00"
@.str.s336 = private unnamed_addr constant [4 x i8] c"ptr\00"
@.str.s337 = private unnamed_addr constant [4 x i8] c"i32\00"
@.str.s338 = private unnamed_addr constant [8 x i8] c"struct:\00"
@.str.s339 = private unnamed_addr constant [4 x i8] c"ptr\00"
@.str.s340 = private unnamed_addr constant [1 x i8] c"\00"
@.str.s341 = private unnamed_addr constant [7 x i8] c"ptrptr\00"
@.str.s342 = private unnamed_addr constant [4 x i8] c"ptr\00"
@.str.s343 = private unnamed_addr constant [1 x i8] c"\00"
@.str.s344 = private unnamed_addr constant [5 x i8] c"Void\00"
@.str.s345 = private unnamed_addr constant [6 x i8] c"Float\00"
@.str.s346 = private unnamed_addr constant [5 x i8] c"Bool\00"
@.str.s347 = private unnamed_addr constant [5 x i8] c"Char\00"
@.str.s348 = private unnamed_addr constant [7 x i8] c"String\00"
@.str.s349 = private unnamed_addr constant [4 x i8] c"Ptr\00"
@.str.s350 = private unnamed_addr constant [8 x i8] c"struct:\00"
@.str.s351 = private unnamed_addr constant [6 x i8] c"enum:\00"
@.str.s352 = private unnamed_addr constant [1 x i8] c"\00"
@.str.s353 = private unnamed_addr constant [7 x i8] c"array:\00"
@.str.s354 = private unnamed_addr constant [14 x i8] c"array:Invalid\00"
@.str.s355 = private unnamed_addr constant [1 x i8] c"\00"
@.str.s356 = private unnamed_addr constant [6 x i8] c"list:\00"
@.str.s357 = private unnamed_addr constant [13 x i8] c"list:Invalid\00"
@.str.s358 = private unnamed_addr constant [8 x i8] c"Invalid\00"
@.str.s359 = private unnamed_addr constant [7 x i8] c"ptrptr\00"
@.str.s360 = private unnamed_addr constant [4 x i8] c"ptr\00"
@.str.s361 = private unnamed_addr constant [8 x i8] c"struct:\00"
@.str.s362 = private unnamed_addr constant [4 x i8] c"ptr\00"
@.str.s363 = private unnamed_addr constant [1 x i8] c"\00"
@.str.s364 = private unnamed_addr constant [4 x i8] c"Int\00"
@.str.s365 = private unnamed_addr constant [6 x i8] c"Float\00"
@.str.s366 = private unnamed_addr constant [5 x i8] c"Bool\00"
@.str.s367 = private unnamed_addr constant [7 x i8] c"String\00"
@.str.s368 = private unnamed_addr constant [5 x i8] c"Char\00"
@.str.s369 = private unnamed_addr constant [3 x i8] c"I8\00"
@.str.s370 = private unnamed_addr constant [4 x i8] c"I16\00"
@.str.s371 = private unnamed_addr constant [4 x i8] c"I64\00"
@.str.s372 = private unnamed_addr constant [6 x i8] c"Isize\00"
@.str.s373 = private unnamed_addr constant [3 x i8] c"U8\00"
@.str.s374 = private unnamed_addr constant [4 x i8] c"U16\00"
@.str.s375 = private unnamed_addr constant [4 x i8] c"U32\00"
@.str.s376 = private unnamed_addr constant [4 x i8] c"U64\00"
@.str.s377 = private unnamed_addr constant [6 x i8] c"Usize\00"
@.str.s378 = private unnamed_addr constant [1 x i8] c"\00"
@.str.s379 = private unnamed_addr constant [4 x i8] c"i32\00"
@.str.s380 = private unnamed_addr constant [7 x i8] c"double\00"
@.str.s381 = private unnamed_addr constant [3 x i8] c"i1\00"
@.str.s382 = private unnamed_addr constant [3 x i8] c"i8\00"
@.str.s383 = private unnamed_addr constant [4 x i8] c"ptr\00"
@.str.s384 = private unnamed_addr constant [5 x i8] c"void\00"
@.str.s385 = private unnamed_addr constant [8 x i8] c"struct:\00"
@.str.s386 = private unnamed_addr constant [4 x i8] c"Int\00"
@.str.s387 = private unnamed_addr constant [6 x i8] c"Float\00"
@.str.s388 = private unnamed_addr constant [5 x i8] c"Bool\00"
@.str.s389 = private unnamed_addr constant [5 x i8] c"Char\00"
@.str.s390 = private unnamed_addr constant [7 x i8] c"String\00"
@.str.s391 = private unnamed_addr constant [4 x i8] c"Ptr\00"
@.str.s392 = private unnamed_addr constant [5 x i8] c"Void\00"
@.str.s393 = private unnamed_addr constant [3 x i8] c"I8\00"
@.str.s394 = private unnamed_addr constant [4 x i8] c"I16\00"
@.str.s395 = private unnamed_addr constant [4 x i8] c"I64\00"
@.str.s396 = private unnamed_addr constant [6 x i8] c"Isize\00"
@.str.s397 = private unnamed_addr constant [3 x i8] c"U8\00"
@.str.s398 = private unnamed_addr constant [4 x i8] c"U16\00"
@.str.s399 = private unnamed_addr constant [4 x i8] c"U32\00"
@.str.s400 = private unnamed_addr constant [4 x i8] c"U64\00"
@.str.s401 = private unnamed_addr constant [6 x i8] c"Usize\00"
@.str.s402 = private unnamed_addr constant [8 x i8] c"struct:\00"
@.str.s403 = private unnamed_addr constant [6 x i8] c"enum:\00"
@.str.s404 = private unnamed_addr constant [7 x i8] c"array:\00"
@.str.s405 = private unnamed_addr constant [6 x i8] c"list:\00"
@.str.s406 = private unnamed_addr constant [1 x i8] c"\00"
@ir_string_counter =  global i32 0
@ir_target_wasm =  global i1 false
@.str.s407 = private unnamed_addr constant [4 x i8] c"i32\00"
@.str.s408 = private unnamed_addr constant [4 x i8] c"i64\00"
@.str.s409 = private unnamed_addr constant [4 x i8] c"Int\00"
@.str.s410 = private unnamed_addr constant [4 x i8] c"i32\00"
@.str.s411 = private unnamed_addr constant [6 x i8] c"Float\00"
@.str.s412 = private unnamed_addr constant [7 x i8] c"double\00"
@.str.s413 = private unnamed_addr constant [5 x i8] c"Bool\00"
@.str.s414 = private unnamed_addr constant [3 x i8] c"i1\00"
@.str.s415 = private unnamed_addr constant [7 x i8] c"String\00"
@.str.s416 = private unnamed_addr constant [4 x i8] c"ptr\00"
@.str.s417 = private unnamed_addr constant [5 x i8] c"Char\00"
@.str.s418 = private unnamed_addr constant [3 x i8] c"i8\00"
@.str.s419 = private unnamed_addr constant [3 x i8] c"I8\00"
@.str.s420 = private unnamed_addr constant [3 x i8] c"i8\00"
@.str.s421 = private unnamed_addr constant [4 x i8] c"I16\00"
@.str.s422 = private unnamed_addr constant [4 x i8] c"i16\00"
@.str.s423 = private unnamed_addr constant [4 x i8] c"I64\00"
@.str.s424 = private unnamed_addr constant [4 x i8] c"i64\00"
@.str.s425 = private unnamed_addr constant [6 x i8] c"Isize\00"
@.str.s426 = private unnamed_addr constant [3 x i8] c"U8\00"
@.str.s427 = private unnamed_addr constant [3 x i8] c"i8\00"
@.str.s428 = private unnamed_addr constant [4 x i8] c"U16\00"
@.str.s429 = private unnamed_addr constant [4 x i8] c"i16\00"
@.str.s430 = private unnamed_addr constant [4 x i8] c"U32\00"
@.str.s431 = private unnamed_addr constant [4 x i8] c"i32\00"
@.str.s432 = private unnamed_addr constant [4 x i8] c"U64\00"
@.str.s433 = private unnamed_addr constant [4 x i8] c"i64\00"
@.str.s434 = private unnamed_addr constant [6 x i8] c"Usize\00"
@.str.s435 = private unnamed_addr constant [1 x i8] c"\00"
@.str.s436 = private unnamed_addr constant [5 x i8] c"void\00"
@.str.s437 = private unnamed_addr constant [4 x i8] c"i32\00"
@.str.s438 = private unnamed_addr constant [8 x i8] c"struct:\00"
@.str.s439 = private unnamed_addr constant [8 x i8] c"struct:\00"
@.str.s440 = private unnamed_addr constant [2 x i8] c"%\00"
@.str.s441 = private unnamed_addr constant [4 x i8] c"ptr\00"
@.str.s442 = private unnamed_addr constant [1 x i8] c"\00"
@.str.s443 = private unnamed_addr constant [7 x i8] c"ptrptr\00"
@.str.s444 = private unnamed_addr constant [4 x i8] c"ptr\00"
@.str.s445 = private unnamed_addr constant [7 x i8] c"ptrptr\00"
@.str.s446 = private unnamed_addr constant [4 x i8] c"ptr\00"
@.str.s447 = private unnamed_addr constant [4 x i8] c"ptr\00"
@.str.s448 = private unnamed_addr constant [1 x i8] c"\00"
@.str.s449 = private unnamed_addr constant [5 x i8] c"$fn$\00"
@.str.s450 = private unnamed_addr constant [1 x i8] c"\00"
@.str.s451 = private unnamed_addr constant [1 x i8] c"\00"
@.str.s452 = private unnamed_addr constant [5 x i8] c"void\00"
@.str.s453 = private unnamed_addr constant [4 x i8] c"i32\00"
@.str.s454 = private unnamed_addr constant [7 x i8] c"double\00"
@.str.s455 = private unnamed_addr constant [3 x i8] c"i1\00"
@.str.s456 = private unnamed_addr constant [3 x i8] c"i8\00"
@.str.s457 = private unnamed_addr constant [4 x i8] c"ptr\00"
@.str.s458 = private unnamed_addr constant [3 x i8] c"==\00"
@.str.s459 = private unnamed_addr constant [3 x i8] c"!=\00"
@.str.s460 = private unnamed_addr constant [3 x i8] c"i1\00"
@.str.s461 = private unnamed_addr constant [2 x i8] c"<\00"
@.str.s462 = private unnamed_addr constant [3 x i8] c"<=\00"
@.str.s463 = private unnamed_addr constant [3 x i8] c"i1\00"
@.str.s464 = private unnamed_addr constant [2 x i8] c">\00"
@.str.s465 = private unnamed_addr constant [3 x i8] c">=\00"
@.str.s466 = private unnamed_addr constant [3 x i8] c"i1\00"
@.str.s467 = private unnamed_addr constant [4 x i8] c"and\00"
@.str.s468 = private unnamed_addr constant [3 x i8] c"or\00"
@.str.s469 = private unnamed_addr constant [3 x i8] c"i1\00"
@.str.s470 = private unnamed_addr constant [6 x i8] c"print\00"
@.str.s471 = private unnamed_addr constant [8 x i8] c"println\00"
@.str.s472 = private unnamed_addr constant [5 x i8] c"void\00"
@.str.s473 = private unnamed_addr constant [10 x i8] c"print_int\00"
@.str.s474 = private unnamed_addr constant [12 x i8] c"println_int\00"
@.str.s475 = private unnamed_addr constant [5 x i8] c"void\00"
@.str.s476 = private unnamed_addr constant [12 x i8] c"print_float\00"
@.str.s477 = private unnamed_addr constant [14 x i8] c"println_float\00"
@.str.s478 = private unnamed_addr constant [5 x i8] c"void\00"
@.str.s479 = private unnamed_addr constant [13 x i8] c"println_char\00"
@.str.s480 = private unnamed_addr constant [11 x i8] c"print_char\00"
@.str.s481 = private unnamed_addr constant [5 x i8] c"void\00"
@.str.s482 = private unnamed_addr constant [13 x i8] c"println_bool\00"
@.str.s483 = private unnamed_addr constant [11 x i8] c"print_bool\00"
@.str.s484 = private unnamed_addr constant [5 x i8] c"void\00"
@.str.s485 = private unnamed_addr constant [1 x i8] c"\00"
@.str.s486 = private unnamed_addr constant [7 x i8] c"ptrptr\00"
@.str.s487 = private unnamed_addr constant [4 x i8] c"ptr\00"
@.str.s488 = private unnamed_addr constant [4 x i8] c"i32\00"
@.str.s489 = private unnamed_addr constant [4 x i8] c"i32\00"
@.str.s490 = private unnamed_addr constant [4 x i8] c"i32\00"
@.str.s491 = private unnamed_addr constant [4 x i8] c"ptr\00"
@.str.s492 = private unnamed_addr constant [4 x i8] c"i32\00"
@.str.s493 = private unnamed_addr constant [5 x i8] c"true\00"
@.str.s494 = private unnamed_addr constant [2 x i8] c"1\00"
@.str.s495 = private unnamed_addr constant [2 x i8] c"0\00"
@.str.s496 = private unnamed_addr constant [3 x i8] c"  \00"
@.str.s497 = private unnamed_addr constant [28 x i8] c" = getelementptr inbounds [\00"
@.str.s498 = private unnamed_addr constant [14 x i8] c" x i8], ptr @\00"
@.str.s499 = private unnamed_addr constant [3 x i8] c", \00"
@.str.s500 = private unnamed_addr constant [5 x i8] c" 0, \00"
@.str.s501 = private unnamed_addr constant [3 x i8] c" 0\00"
@.str.s502 = private unnamed_addr constant [3 x i8] c"  \00"
@.str.s503 = private unnamed_addr constant [18 x i8] c" = getelementptr \00"
@.str.s504 = private unnamed_addr constant [2 x i8] c"%\00"
@.str.s505 = private unnamed_addr constant [18 x i8] c", ptr null, i32 1\00"
@.str.s506 = private unnamed_addr constant [3 x i8] c"  \00"
@.str.s507 = private unnamed_addr constant [17 x i8] c" = ptrtoint ptr \00"
@.str.s508 = private unnamed_addr constant [5 x i8] c" to \00"
@.str.s509 = private unnamed_addr constant [3 x i8] c"  \00"
@.str.s510 = private unnamed_addr constant [21 x i8] c" = call ptr @malloc(\00"
@.str.s511 = private unnamed_addr constant [2 x i8] c" \00"
@.str.s512 = private unnamed_addr constant [2 x i8] c")\00"
@.str.s513 = private unnamed_addr constant [1 x i8] c"\00"
@.str.s514 = private unnamed_addr constant [3 x i8] c"  \00"
@.str.s515 = private unnamed_addr constant [27 x i8] c" = getelementptr inbounds \00"
@.str.s516 = private unnamed_addr constant [2 x i8] c"%\00"
@.str.s517 = private unnamed_addr constant [7 x i8] c", ptr \00"
@.str.s518 = private unnamed_addr constant [14 x i8] c", i32 0, i32 \00"
@.str.s519 = private unnamed_addr constant [9 x i8] c"  store \00"
@.str.s520 = private unnamed_addr constant [2 x i8] c" \00"
@.str.s521 = private unnamed_addr constant [7 x i8] c", ptr \00"
@.str.s522 = private unnamed_addr constant [3 x i8] c"  \00"
@.str.s523 = private unnamed_addr constant [27 x i8] c" = getelementptr inbounds \00"
@.str.s524 = private unnamed_addr constant [2 x i8] c"%\00"
@.str.s525 = private unnamed_addr constant [7 x i8] c", ptr \00"
@.str.s526 = private unnamed_addr constant [14 x i8] c", i32 0, i32 \00"
@.str.s527 = private unnamed_addr constant [3 x i8] c"  \00"
@.str.s528 = private unnamed_addr constant [9 x i8] c" = load \00"
@.str.s529 = private unnamed_addr constant [7 x i8] c", ptr \00"
@.str.s530 = private unnamed_addr constant [3 x i8] c"  \00"
@.str.s531 = private unnamed_addr constant [12 x i8] c" = alloca [\00"
@.str.s532 = private unnamed_addr constant [8 x i8] c" x ptr]\00"
@.str.s533 = private unnamed_addr constant [1 x i8] c"\00"
@.str.s534 = private unnamed_addr constant [3 x i8] c"  \00"
@.str.s535 = private unnamed_addr constant [28 x i8] c" = getelementptr inbounds [\00"
@.str.s536 = private unnamed_addr constant [14 x i8] c" x ptr], ptr \00"
@.str.s537 = private unnamed_addr constant [3 x i8] c", \00"
@.str.s538 = private unnamed_addr constant [5 x i8] c" 0, \00"
@.str.s539 = private unnamed_addr constant [2 x i8] c" \00"
@.str.s540 = private unnamed_addr constant [13 x i8] c"  store ptr \00"
@.str.s541 = private unnamed_addr constant [7 x i8] c", ptr \00"
@.str.s542 = private unnamed_addr constant [3 x i8] c"  \00"
@.str.s543 = private unnamed_addr constant [28 x i8] c" = getelementptr inbounds [\00"
@.str.s544 = private unnamed_addr constant [14 x i8] c" x ptr], ptr \00"
@.str.s545 = private unnamed_addr constant [3 x i8] c", \00"
@.str.s546 = private unnamed_addr constant [5 x i8] c" 0, \00"
@.str.s547 = private unnamed_addr constant [3 x i8] c" 0\00"
@.str.s548 = private unnamed_addr constant [3 x i8] c"  \00"
@.str.s549 = private unnamed_addr constant [12 x i8] c" = alloca [\00"
@.str.s550 = private unnamed_addr constant [8 x i8] c" x i32]\00"
@.str.s551 = private unnamed_addr constant [1 x i8] c"\00"
@.str.s552 = private unnamed_addr constant [3 x i8] c"  \00"
@.str.s553 = private unnamed_addr constant [28 x i8] c" = getelementptr inbounds [\00"
@.str.s554 = private unnamed_addr constant [14 x i8] c" x i32], ptr \00"
@.str.s555 = private unnamed_addr constant [3 x i8] c", \00"
@.str.s556 = private unnamed_addr constant [5 x i8] c" 0, \00"
@.str.s557 = private unnamed_addr constant [2 x i8] c" \00"
@.str.s558 = private unnamed_addr constant [13 x i8] c"  store i32 \00"
@.str.s559 = private unnamed_addr constant [7 x i8] c", ptr \00"
@.str.s560 = private unnamed_addr constant [3 x i8] c"  \00"
@.str.s561 = private unnamed_addr constant [28 x i8] c" = getelementptr inbounds [\00"
@.str.s562 = private unnamed_addr constant [14 x i8] c" x i32], ptr \00"
@.str.s563 = private unnamed_addr constant [3 x i8] c", \00"
@.str.s564 = private unnamed_addr constant [5 x i8] c" 0, \00"
@.str.s565 = private unnamed_addr constant [3 x i8] c" 0\00"
@.str.s566 = private unnamed_addr constant [4 x i8] c"i32\00"
@.str.s567 = private unnamed_addr constant [7 x i8] c"ptrptr\00"
@.str.s568 = private unnamed_addr constant [4 x i8] c"ptr\00"
@.str.s569 = private unnamed_addr constant [3 x i8] c"  \00"
@.str.s570 = private unnamed_addr constant [27 x i8] c" = getelementptr inbounds \00"
@.str.s571 = private unnamed_addr constant [7 x i8] c", ptr \00"
@.str.s572 = private unnamed_addr constant [7 x i8] c", i32 \00"
@.str.s573 = private unnamed_addr constant [3 x i8] c"  \00"
@.str.s574 = private unnamed_addr constant [9 x i8] c" = load \00"
@.str.s575 = private unnamed_addr constant [7 x i8] c", ptr \00"
@.str.s576 = private unnamed_addr constant [7 x i8] c"double\00"
@.str.s577 = private unnamed_addr constant [2 x i8] c"+\00"
@.str.s578 = private unnamed_addr constant [2 x i8] c"-\00"
@.str.s579 = private unnamed_addr constant [2 x i8] c"*\00"
@.str.s580 = private unnamed_addr constant [2 x i8] c"/\00"
@.str.s581 = private unnamed_addr constant [3 x i8] c"==\00"
@.str.s582 = private unnamed_addr constant [3 x i8] c"!=\00"
@.str.s583 = private unnamed_addr constant [2 x i8] c"<\00"
@.str.s584 = private unnamed_addr constant [3 x i8] c"<=\00"
@.str.s585 = private unnamed_addr constant [2 x i8] c">\00"
@.str.s586 = private unnamed_addr constant [3 x i8] c">=\00"
@.str.s587 = private unnamed_addr constant [2 x i8] c"+\00"
@.str.s588 = private unnamed_addr constant [2 x i8] c"-\00"
@.str.s589 = private unnamed_addr constant [2 x i8] c"*\00"
@.str.s590 = private unnamed_addr constant [3 x i8] c"==\00"
@.str.s591 = private unnamed_addr constant [3 x i8] c"!=\00"
@.str.s592 = private unnamed_addr constant [2 x i8] c"/\00"
@.str.s593 = private unnamed_addr constant [2 x i8] c"<\00"
@.str.s594 = private unnamed_addr constant [3 x i8] c"<=\00"
@.str.s595 = private unnamed_addr constant [2 x i8] c">\00"
@.str.s596 = private unnamed_addr constant [3 x i8] c">=\00"
@.str.s597 = private unnamed_addr constant [2 x i8] c"/\00"
@.str.s598 = private unnamed_addr constant [2 x i8] c"<\00"
@.str.s599 = private unnamed_addr constant [3 x i8] c"<=\00"
@.str.s600 = private unnamed_addr constant [2 x i8] c">\00"
@.str.s601 = private unnamed_addr constant [3 x i8] c">=\00"
@.str.s602 = private unnamed_addr constant [2 x i8] c"%\00"
@.str.s603 = private unnamed_addr constant [4 x i8] c"and\00"
@.str.s604 = private unnamed_addr constant [3 x i8] c"i1\00"
@.str.s605 = private unnamed_addr constant [3 x i8] c"or\00"
@.str.s606 = private unnamed_addr constant [3 x i8] c"i1\00"
@.str.s607 = private unnamed_addr constant [5 x i8] c"drop\00"
@.str.s608 = private unnamed_addr constant [1 x i8] c"\00"
@.str.s609 = private unnamed_addr constant [4 x i8] c"ptr\00"
@.str.s610 = private unnamed_addr constant [5 x i8] c"void\00"
@.str.s611 = private unnamed_addr constant [5 x i8] c"free\00"
@.str.s612 = private unnamed_addr constant [1 x i8] c"\00"
@.str.s613 = private unnamed_addr constant [6 x i8] c"print\00"
@.str.s614 = private unnamed_addr constant [8 x i8] c"println\00"
@.str.s615 = private unnamed_addr constant [1 x i8] c"\00"
@.str.s616 = private unnamed_addr constant [4 x i8] c"ptr\00"
@.str.s617 = private unnamed_addr constant [4 x i8] c"ptr\00"
@.str.s618 = private unnamed_addr constant [5 x i8] c"void\00"
@.str.s619 = private unnamed_addr constant [6 x i8] c"print\00"
@.str.s620 = private unnamed_addr constant [5 x i8] c"void\00"
@.str.s621 = private unnamed_addr constant [8 x i8] c"println\00"
@.str.s622 = private unnamed_addr constant [7 x i8] c"double\00"
@.str.s623 = private unnamed_addr constant [7 x i8] c"double\00"
@.str.s624 = private unnamed_addr constant [5 x i8] c"void\00"
@.str.s625 = private unnamed_addr constant [12 x i8] c"print_float\00"
@.str.s626 = private unnamed_addr constant [5 x i8] c"void\00"
@.str.s627 = private unnamed_addr constant [14 x i8] c"println_float\00"
@.str.s628 = private unnamed_addr constant [5 x i8] c"void\00"
@.str.s629 = private unnamed_addr constant [10 x i8] c"print_int\00"
@.str.s630 = private unnamed_addr constant [5 x i8] c"void\00"
@.str.s631 = private unnamed_addr constant [12 x i8] c"println_int\00"
@.str.s632 = private unnamed_addr constant [1 x i8] c"\00"
@.str.s633 = private unnamed_addr constant [1 x i8] c"\00"
@.str.s634 = private unnamed_addr constant [1 x i8] c"\00"
@.str.s635 = private unnamed_addr constant [5 x i8] c"void\00"
@.str.s636 = private unnamed_addr constant [5 x i8] c"void\00"
@.str.s637 = private unnamed_addr constant [1 x i8] c"\00"
@.str.s638 = private unnamed_addr constant [2 x i8] c"0\00"
@.str.s639 = private unnamed_addr constant [4 x i8] c"i32\00"
@.str.s640 = private unnamed_addr constant [1 x i8] c"\00"
@.str.s641 = private unnamed_addr constant [1 x i8] c"\00"
@.str.s642 = private unnamed_addr constant [1 x i8] c"\00"
@.str.s643 = private unnamed_addr constant [3 x i8] c"  \00"
@.str.s644 = private unnamed_addr constant [27 x i8] c" = getelementptr inbounds \00"
@.str.s645 = private unnamed_addr constant [2 x i8] c"%\00"
@.str.s646 = private unnamed_addr constant [7 x i8] c", ptr \00"
@.str.s647 = private unnamed_addr constant [14 x i8] c", i32 0, i32 \00"
@.str.s648 = private unnamed_addr constant [9 x i8] c"  store \00"
@.str.s649 = private unnamed_addr constant [2 x i8] c" \00"
@.str.s650 = private unnamed_addr constant [7 x i8] c", ptr \00"
@.str.s651 = private unnamed_addr constant [1 x i8] c"\00"
@.str.s652 = private unnamed_addr constant [1 x i8] c"\00"
@.str.s653 = private unnamed_addr constant [1 x i8] c"\00"
@.str.s654 = private unnamed_addr constant [1 x i8] c"\00"
@.str.s655 = private unnamed_addr constant [4 x i8] c"i32\00"
@.str.s656 = private unnamed_addr constant [4 x i8] c"i32\00"
@.str.s657 = private unnamed_addr constant [4 x i8] c"i32\00"
@.str.s658 = private unnamed_addr constant [4 x i8] c"i32\00"
@.str.s659 = private unnamed_addr constant [4 x i8] c"i32\00"
@.str.s660 = private unnamed_addr constant [2 x i8] c"1\00"
@.str.s661 = private unnamed_addr constant [4 x i8] c"i32\00"
@.str.s662 = private unnamed_addr constant [1 x i8] c"\00"
@.str.s663 = private unnamed_addr constant [2 x i8] c"_\00"
@.str.s664 = private unnamed_addr constant [1 x i8] c"\00"
@.str.s665 = private unnamed_addr constant [4 x i8] c"i32\00"
@.str.s666 = private unnamed_addr constant [1 x i8] c"\00"
@.str.s667 = private unnamed_addr constant [1 x i8] c"\00"
@.str.s668 = private unnamed_addr constant [1 x i8] c"\00"
@.str.s669 = private unnamed_addr constant [1 x i8] c"\00"
@.str.s670 = private unnamed_addr constant [1 x i8] c"\00"
@.str.s671 = private unnamed_addr constant [1 x i8] c"\00"
@.str.s672 = private unnamed_addr constant [4 x i8] c"i32\00"
@.str.s673 = private unnamed_addr constant [4 x i8] c"i32\00"
@.str.s674 = private unnamed_addr constant [1 x i8] c"\00"
@.str.s675 = private unnamed_addr constant [1 x i8] c"\00"
@.str.s676 = private unnamed_addr constant [1 x i8] c"\00"
@.str.s677 = private unnamed_addr constant [1 x i8] c"\00"
@.str.s678 = private unnamed_addr constant [5 x i8] c"void\00"
@.str.s679 = private unnamed_addr constant [1 x i8] c"\00"
@.str.s680 = private unnamed_addr constant [5 x i8] c"main\00"
@.str.s681 = private unnamed_addr constant [4 x i8] c"i32\00"
@.str.s682 = private unnamed_addr constant [4 x i8] c"i32\00"
@.str.s683 = private unnamed_addr constant [7 x i8] c"p_argc\00"
@.str.s684 = private unnamed_addr constant [4 x i8] c"ptr\00"
@.str.s685 = private unnamed_addr constant [7 x i8] c"p_argv\00"
@.str.s686 = private unnamed_addr constant [1 x i8] c"\00"
@.str.s687 = private unnamed_addr constant [3 x i8] c"p_\00"
@.str.s688 = private unnamed_addr constant [4 x i8] c"i32\00"
@.str.s689 = private unnamed_addr constant [8 x i8] c"%p_argc\00"
@.str.s690 = private unnamed_addr constant [13 x i8] c"prismio_argc\00"
@.str.s691 = private unnamed_addr constant [4 x i8] c"ptr\00"
@.str.s692 = private unnamed_addr constant [8 x i8] c"%p_argv\00"
@.str.s693 = private unnamed_addr constant [13 x i8] c"prismio_argv\00"
@.str.s694 = private unnamed_addr constant [1 x i8] c"\00"
@.str.s695 = private unnamed_addr constant [4 x i8] c"%p_\00"
@.str.s696 = private unnamed_addr constant [1 x i8] c"\00"
@.str.s697 = private unnamed_addr constant [1 x i8] c"\00"
@.str.s698 = private unnamed_addr constant [5 x i8] c"void\00"
@.str.s699 = private unnamed_addr constant [4 x i8] c"i32\00"
@.str.s700 = private unnamed_addr constant [2 x i8] c"0\00"
@.str.s701 = private unnamed_addr constant [2 x i8] c"0\00"
@.str.s702 = private unnamed_addr constant [7 x i8] c".str.s\00"
@.str.s703 = private unnamed_addr constant [1 x i8] c"\00"
@.str.s704 = private unnamed_addr constant [1 x i8] c"\00"
@.str.s705 = private unnamed_addr constant [1 x i8] c"\00"
@.str.s706 = private unnamed_addr constant [1 x i8] c"\00"
@.str.s707 = private unnamed_addr constant [1 x i8] c"\00"
@.str.s708 = private unnamed_addr constant [1 x i8] c"\00"
@.str.s709 = private unnamed_addr constant [1 x i8] c"\00"
@.str.s710 = private unnamed_addr constant [1 x i8] c"\00"
@.str.s711 = private unnamed_addr constant [1 x i8] c"\00"
@.str.s712 = private unnamed_addr constant [1 x i8] c"\00"
@.str.s713 = private unnamed_addr constant [1 x i8] c"\00"
@.str.s714 = private unnamed_addr constant [1 x i8] c"\00"
@.str.s715 = private unnamed_addr constant [1 x i8] c"\00"
@.str.s716 = private unnamed_addr constant [2 x i8] c"%\00"
@.str.s717 = private unnamed_addr constant [11 x i8] c" = type { \00"
@.str.s718 = private unnamed_addr constant [1 x i8] c"\00"
@.str.s719 = private unnamed_addr constant [3 x i8] c", \00"
@.str.s720 = private unnamed_addr constant [3 x i8] c" }\00"
@.str.s721 = private unnamed_addr constant [1 x i8] c"\00"
@.str.s722 = private unnamed_addr constant [1 x i8] c"\00"
@.str.s723 = private unnamed_addr constant [1 x i8] c"\00"
@.str.s724 = private unnamed_addr constant [1 x i8] c"\00"
@.str.s725 = private unnamed_addr constant [1 x i8] c"\00"
@.str.s726 = private unnamed_addr constant [1 x i8] c"\00"
@.str.s727 = private unnamed_addr constant [1 x i8] c"\00"
@.str.s728 = private unnamed_addr constant [19 x i8] c"self_hosted_module\00"
@.str.s729 = private unnamed_addr constant [19 x i8] c"self_hosted_module\00"
@.str.s730 = private unnamed_addr constant [1 x i8] c"\00"
@.str.s731 = private unnamed_addr constant [1 x i8] c"\00"
@.str.s732 = private unnamed_addr constant [13 x i8] c"prismio_argc\00"
@.str.s733 = private unnamed_addr constant [4 x i8] c"i32\00"
@.str.s734 = private unnamed_addr constant [2 x i8] c"0\00"
@.str.s735 = private unnamed_addr constant [13 x i8] c"prismio_argv\00"
@.str.s736 = private unnamed_addr constant [4 x i8] c"ptr\00"
@.str.s737 = private unnamed_addr constant [5 x i8] c"null\00"
@.str.s738 = private unnamed_addr constant [7 x i8] c"malloc\00"
@.str.s739 = private unnamed_addr constant [4 x i8] c"ptr\00"
@.str.s740 = private unnamed_addr constant [5 x i8] c"free\00"
@.str.s741 = private unnamed_addr constant [5 x i8] c"void\00"
@.str.s742 = private unnamed_addr constant [4 x i8] c"ptr\00"
@.str.s743 = private unnamed_addr constant [9 x i8] c"list_new\00"
@.str.s744 = private unnamed_addr constant [4 x i8] c"ptr\00"
@.str.s745 = private unnamed_addr constant [10 x i8] c"list_push\00"
@.str.s746 = private unnamed_addr constant [5 x i8] c"void\00"
@.str.s747 = private unnamed_addr constant [4 x i8] c"ptr\00"
@.str.s748 = private unnamed_addr constant [4 x i8] c"ptr\00"
@.str.s749 = private unnamed_addr constant [9 x i8] c"list_get\00"
@.str.s750 = private unnamed_addr constant [4 x i8] c"ptr\00"
@.str.s751 = private unnamed_addr constant [4 x i8] c"ptr\00"
@.str.s752 = private unnamed_addr constant [4 x i8] c"i32\00"
@.str.s753 = private unnamed_addr constant [9 x i8] c"list_set\00"
@.str.s754 = private unnamed_addr constant [5 x i8] c"void\00"
@.str.s755 = private unnamed_addr constant [4 x i8] c"ptr\00"
@.str.s756 = private unnamed_addr constant [4 x i8] c"i32\00"
@.str.s757 = private unnamed_addr constant [4 x i8] c"ptr\00"
@.str.s758 = private unnamed_addr constant [9 x i8] c"list_len\00"
@.str.s759 = private unnamed_addr constant [4 x i8] c"i32\00"
@.str.s760 = private unnamed_addr constant [4 x i8] c"ptr\00"
@.str.s761 = private unnamed_addr constant [8 x i8] c"println\00"
@.str.s762 = private unnamed_addr constant [5 x i8] c"void\00"
@.str.s763 = private unnamed_addr constant [4 x i8] c"ptr\00"
@.str.s764 = private unnamed_addr constant [6 x i8] c"print\00"
@.str.s765 = private unnamed_addr constant [5 x i8] c"void\00"
@.str.s766 = private unnamed_addr constant [4 x i8] c"ptr\00"
@.str.s767 = private unnamed_addr constant [12 x i8] c"println_int\00"
@.str.s768 = private unnamed_addr constant [5 x i8] c"void\00"
@.str.s769 = private unnamed_addr constant [4 x i8] c"i32\00"
@.str.s770 = private unnamed_addr constant [10 x i8] c"print_int\00"
@.str.s771 = private unnamed_addr constant [5 x i8] c"void\00"
@.str.s772 = private unnamed_addr constant [4 x i8] c"i32\00"
@.str.s773 = private unnamed_addr constant [14 x i8] c"println_float\00"
@.str.s774 = private unnamed_addr constant [5 x i8] c"void\00"
@.str.s775 = private unnamed_addr constant [7 x i8] c"double\00"
@.str.s776 = private unnamed_addr constant [12 x i8] c"print_float\00"
@.str.s777 = private unnamed_addr constant [5 x i8] c"void\00"
@.str.s778 = private unnamed_addr constant [7 x i8] c"double\00"
@.str.s779 = private unnamed_addr constant [13 x i8] c"println_bool\00"
@.str.s780 = private unnamed_addr constant [5 x i8] c"void\00"
@.str.s781 = private unnamed_addr constant [4 x i8] c"i32\00"
@.str.s782 = private unnamed_addr constant [11 x i8] c"print_bool\00"
@.str.s783 = private unnamed_addr constant [5 x i8] c"void\00"
@.str.s784 = private unnamed_addr constant [4 x i8] c"i32\00"
@.str.s785 = private unnamed_addr constant [13 x i8] c"println_char\00"
@.str.s786 = private unnamed_addr constant [5 x i8] c"void\00"
@.str.s787 = private unnamed_addr constant [3 x i8] c"i8\00"
@.str.s788 = private unnamed_addr constant [11 x i8] c"print_char\00"
@.str.s789 = private unnamed_addr constant [5 x i8] c"void\00"
@.str.s790 = private unnamed_addr constant [3 x i8] c"i8\00"
@.str.s791 = private unnamed_addr constant [1 x i8] c"\00"
@.str.s792 = private unnamed_addr constant [2 x i8] c"0\00"
@.str.s793 = private unnamed_addr constant [4 x i8] c"i32\00"
@.str.s794 = private unnamed_addr constant [1 x i8] c"\00"
@.str.s795 = private unnamed_addr constant [1 x i8] c"\00"
@.str.s796 = private unnamed_addr constant [5 x i8] c"main\00"
@.str.s797 = private unnamed_addr constant [4 x i8] c"i32\00"
@.str.s798 = private unnamed_addr constant [1 x i8] c"\00"
@.str.s799 = private unnamed_addr constant [5 x i8] c"$fn$\00"
@.str.s800 = private unnamed_addr constant [5 x i8] c"Void\00"
@.str.s801 = private unnamed_addr constant [6 x i8] c"Float\00"
@.str.s802 = private unnamed_addr constant [5 x i8] c"Bool\00"
@.str.s803 = private unnamed_addr constant [5 x i8] c"Char\00"
@.str.s804 = private unnamed_addr constant [7 x i8] c"String\00"
@.str.s805 = private unnamed_addr constant [4 x i8] c"Ptr\00"
@.str.s806 = private unnamed_addr constant [8 x i8] c"Struct_\00"
@.str.s807 = private unnamed_addr constant [6 x i8] c"Enum_\00"
@.str.s808 = private unnamed_addr constant [1 x i8] c"\00"
@.str.s809 = private unnamed_addr constant [7 x i8] c"Array_\00"
@.str.s810 = private unnamed_addr constant [14 x i8] c"Array_Invalid\00"
@.str.s811 = private unnamed_addr constant [1 x i8] c"\00"
@.str.s812 = private unnamed_addr constant [6 x i8] c"List_\00"
@.str.s813 = private unnamed_addr constant [13 x i8] c"List_Invalid\00"
@.str.s814 = private unnamed_addr constant [8 x i8] c"Invalid\00"
@.str.s815 = private unnamed_addr constant [1 x i8] c"\00"
@.str.s816 = private unnamed_addr constant [1 x i8] c"\00"
@.str.s817 = private unnamed_addr constant [1 x i8] c"\00"
@.str.s818 = private unnamed_addr constant [2 x i8] c"_\00"
@.str.s819 = private unnamed_addr constant [1 x i8] c"\00"
@.str.s820 = private unnamed_addr constant [5 x i8] c"Void\00"
@.str.s821 = private unnamed_addr constant [5 x i8] c"main\00"
@.str.s822 = private unnamed_addr constant [5 x i8] c"main\00"
@.str.s823 = private unnamed_addr constant [3 x i8] c"__\00"
@.str.s824 = private unnamed_addr constant [1 x i8] c"\00"
@.str.s825 = private unnamed_addr constant [13 x i8] c"type error: \00"
@.str.s826 = private unnamed_addr constant [13 x i8] c"type error: \00"
@.str.s827 = private unnamed_addr constant [12 x i8] c": expected \00"
@.str.s828 = private unnamed_addr constant [7 x i8] c", got \00"
@.str.s829 = private unnamed_addr constant [1 x i8] c"\00"
@.str.s830 = private unnamed_addr constant [1 x i8] c"\00"
@.str.s831 = private unnamed_addr constant [1 x i8] c"\00"
@.str.s832 = private unnamed_addr constant [1 x i8] c"\00"
@.str.s833 = private unnamed_addr constant [4 x i8] c"Int\00"
@.str.s834 = private unnamed_addr constant [6 x i8] c"Float\00"
@.str.s835 = private unnamed_addr constant [5 x i8] c"Bool\00"
@.str.s836 = private unnamed_addr constant [7 x i8] c"String\00"
@.str.s837 = private unnamed_addr constant [5 x i8] c"Char\00"
@.str.s838 = private unnamed_addr constant [3 x i8] c"I8\00"
@.str.s839 = private unnamed_addr constant [4 x i8] c"I16\00"
@.str.s840 = private unnamed_addr constant [4 x i8] c"I64\00"
@.str.s841 = private unnamed_addr constant [6 x i8] c"Isize\00"
@.str.s842 = private unnamed_addr constant [3 x i8] c"U8\00"
@.str.s843 = private unnamed_addr constant [4 x i8] c"U16\00"
@.str.s844 = private unnamed_addr constant [4 x i8] c"U32\00"
@.str.s845 = private unnamed_addr constant [4 x i8] c"U64\00"
@.str.s846 = private unnamed_addr constant [6 x i8] c"Usize\00"
@.str.s847 = private unnamed_addr constant [1 x i8] c"\00"
@.str.s848 = private unnamed_addr constant [14 x i8] c"unknown type \00"
@.str.s849 = private unnamed_addr constant [1 x i8] c"\00"
@.str.s850 = private unnamed_addr constant [4 x i8] c"Int\00"
@.str.s851 = private unnamed_addr constant [36 x i8] c"cannot move out of borrowed value: \00"
@.str.s852 = private unnamed_addr constant [1 x i8] c"\00"
@.str.s853 = private unnamed_addr constant [1 x i8] c"\00"
@.str.s854 = private unnamed_addr constant [1 x i8] c"\00"
@.str.s855 = private unnamed_addr constant [1 x i8] c"\00"
@.str.s856 = private unnamed_addr constant [1 x i8] c"\00"
@.str.s857 = private unnamed_addr constant [1 x i8] c"\00"
@.str.s858 = private unnamed_addr constant [1 x i8] c"\00"
@.str.s859 = private unnamed_addr constant [1 x i8] c"\00"
@.str.s860 = private unnamed_addr constant [30 x i8] c"ambiguous overloaded call to \00"
@.str.s861 = private unnamed_addr constant [26 x i8] c"no matching overload for \00"
@.str.s862 = private unnamed_addr constant [18 x i8] c"unknown function \00"
@.str.s863 = private unnamed_addr constant [1 x i8] c"\00"
@.str.s864 = private unnamed_addr constant [1 x i8] c"\00"
@.str.s865 = private unnamed_addr constant [15 x i8] c"unknown field \00"
@.str.s866 = private unnamed_addr constant [5 x i8] c" on \00"
@.str.s867 = private unnamed_addr constant [1 x i8] c"\00"
@.str.s868 = private unnamed_addr constant [1 x i8] c"\00"
@.str.s869 = private unnamed_addr constant [6 x i8] c"print\00"
@.str.s870 = private unnamed_addr constant [8 x i8] c"println\00"
@.str.s871 = private unnamed_addr constant [1 x i8] c"\00"
@.str.s872 = private unnamed_addr constant [22 x i8] c" expects one argument\00"
@.str.s873 = private unnamed_addr constant [10 x i8] c"print_int\00"
@.str.s874 = private unnamed_addr constant [12 x i8] c"println_int\00"
@.str.s875 = private unnamed_addr constant [12 x i8] c"print_float\00"
@.str.s876 = private unnamed_addr constant [14 x i8] c"println_float\00"
@.str.s877 = private unnamed_addr constant [11 x i8] c"print_bool\00"
@.str.s878 = private unnamed_addr constant [13 x i8] c"println_bool\00"
@.str.s879 = private unnamed_addr constant [11 x i8] c"print_char\00"
@.str.s880 = private unnamed_addr constant [13 x i8] c"println_char\00"
@.str.s881 = private unnamed_addr constant [5 x i8] c"drop\00"
@.str.s882 = private unnamed_addr constant [9 x i8] c"list_new\00"
@.str.s883 = private unnamed_addr constant [9 x i8] c"list_len\00"
@.str.s884 = private unnamed_addr constant [10 x i8] c"list_push\00"
@.str.s885 = private unnamed_addr constant [9 x i8] c"list_set\00"
@.str.s886 = private unnamed_addr constant [9 x i8] c"list_get\00"
@.str.s887 = private unnamed_addr constant [1 x i8] c"\00"
@.str.s888 = private unnamed_addr constant [1 x i8] c"\00"
@.str.s889 = private unnamed_addr constant [6 x i8] c"print\00"
@.str.s890 = private unnamed_addr constant [8 x i8] c"println\00"
@.str.s891 = private unnamed_addr constant [1 x i8] c"\00"
@.str.s892 = private unnamed_addr constant [1 x i8] c"\00"
@.str.s893 = private unnamed_addr constant [22 x i8] c" expects one argument\00"
@.str.s894 = private unnamed_addr constant [5 x i8] c"drop\00"
@.str.s895 = private unnamed_addr constant [1 x i8] c"\00"
@.str.s896 = private unnamed_addr constant [1 x i8] c"\00"
@.str.s897 = private unnamed_addr constant [26 x i8] c"drop expects one argument\00"
@.str.s898 = private unnamed_addr constant [41 x i8] c"drop requires an owned (move-only) value\00"
@.str.s899 = private unnamed_addr constant [9 x i8] c"list_new\00"
@.str.s900 = private unnamed_addr constant [1 x i8] c"\00"
@.str.s901 = private unnamed_addr constant [28 x i8] c"list_new takes no arguments\00"
@.str.s902 = private unnamed_addr constant [9 x i8] c"list_len\00"
@.str.s903 = private unnamed_addr constant [1 x i8] c"\00"
@.str.s904 = private unnamed_addr constant [24 x i8] c"list_len expects a List\00"
@.str.s905 = private unnamed_addr constant [24 x i8] c"list_len expects a List\00"
@.str.s906 = private unnamed_addr constant [9 x i8] c"list_get\00"
@.str.s907 = private unnamed_addr constant [24 x i8] c"list_get expects a List\00"
@.str.s908 = private unnamed_addr constant [15 x i8] c"list_get index\00"
@.str.s909 = private unnamed_addr constant [10 x i8] c"list_push\00"
@.str.s910 = private unnamed_addr constant [25 x i8] c"list_push expects a List\00"
@.str.s911 = private unnamed_addr constant [16 x i8] c"list_push value\00"
@.str.s912 = private unnamed_addr constant [9 x i8] c"list_set\00"
@.str.s913 = private unnamed_addr constant [24 x i8] c"list_set expects a List\00"
@.str.s914 = private unnamed_addr constant [15 x i8] c"list_set index\00"
@.str.s915 = private unnamed_addr constant [15 x i8] c"list_set value\00"
@.str.s916 = private unnamed_addr constant [10 x i8] c"print_int\00"
@.str.s917 = private unnamed_addr constant [12 x i8] c"println_int\00"
@.str.s918 = private unnamed_addr constant [12 x i8] c"print_float\00"
@.str.s919 = private unnamed_addr constant [14 x i8] c"println_float\00"
@.str.s920 = private unnamed_addr constant [11 x i8] c"print_bool\00"
@.str.s921 = private unnamed_addr constant [13 x i8] c"println_bool\00"
@.str.s922 = private unnamed_addr constant [11 x i8] c"print_char\00"
@.str.s923 = private unnamed_addr constant [13 x i8] c"println_char\00"
@.str.s924 = private unnamed_addr constant [1 x i8] c"\00"
@.str.s925 = private unnamed_addr constant [1 x i8] c"\00"
@.str.s926 = private unnamed_addr constant [22 x i8] c" expects one argument\00"
@.str.s927 = private unnamed_addr constant [10 x i8] c" argument\00"
@.str.s928 = private unnamed_addr constant [20 x i8] c"unknown identifier \00"
@.str.s929 = private unnamed_addr constant [21 x i8] c"use of moved value: \00"
@.str.s930 = private unnamed_addr constant [4 x i8] c"and\00"
@.str.s931 = private unnamed_addr constant [3 x i8] c"or\00"
@.str.s932 = private unnamed_addr constant [30 x i8] c"boolean operator left operand\00"
@.str.s933 = private unnamed_addr constant [31 x i8] c"boolean operator right operand\00"
@.str.s934 = private unnamed_addr constant [2 x i8] c"+\00"
@.str.s935 = private unnamed_addr constant [2 x i8] c"-\00"
@.str.s936 = private unnamed_addr constant [2 x i8] c"*\00"
@.str.s937 = private unnamed_addr constant [2 x i8] c"/\00"
@.str.s938 = private unnamed_addr constant [37 x i8] c"operator requires numeric operands: \00"
@.str.s939 = private unnamed_addr constant [10 x i8] c"operator \00"
@.str.s940 = private unnamed_addr constant [2 x i8] c"%\00"
@.str.s941 = private unnamed_addr constant [20 x i8] c"modulo left operand\00"
@.str.s942 = private unnamed_addr constant [21 x i8] c"modulo right operand\00"
@.str.s943 = private unnamed_addr constant [3 x i8] c"==\00"
@.str.s944 = private unnamed_addr constant [3 x i8] c"!=\00"
@.str.s945 = private unnamed_addr constant [2 x i8] c"<\00"
@.str.s946 = private unnamed_addr constant [3 x i8] c"<=\00"
@.str.s947 = private unnamed_addr constant [2 x i8] c">\00"
@.str.s948 = private unnamed_addr constant [3 x i8] c">=\00"
@.str.s949 = private unnamed_addr constant [12 x i8] c"comparison \00"
@.str.s950 = private unnamed_addr constant [18 x i8] c"unknown operator \00"
@.str.s951 = private unnamed_addr constant [1 x i8] c"\00"
@.str.s952 = private unnamed_addr constant [1 x i8] c"\00"
@.str.s953 = private unnamed_addr constant [10 x i8] c" argument\00"
@.str.s954 = private unnamed_addr constant [5 x i8] c"sink\00"
@.str.s955 = private unnamed_addr constant [5 x i8] c"main\00"
@.str.s956 = private unnamed_addr constant [38 x i8] c"member access requires a struct value\00"
@.str.s957 = private unnamed_addr constant [1 x i8] c"\00"
@.str.s958 = private unnamed_addr constant [1 x i8] c"\00"
@.str.s959 = private unnamed_addr constant [22 x i8] c"array literal element\00"
@.str.s960 = private unnamed_addr constant [12 x i8] c"array index\00"
@.str.s961 = private unnamed_addr constant [27 x i8] c"indexing requires an array\00"
@.str.s962 = private unnamed_addr constant [16 x i8] c"unknown struct \00"
@.str.s963 = private unnamed_addr constant [1 x i8] c"\00"
@.str.s964 = private unnamed_addr constant [14 x i8] c"struct field \00"
@.str.s965 = private unnamed_addr constant [23 x i8] c"unsupported expression\00"
@.str.s966 = private unnamed_addr constant [1 x i8] c"\00"
@.str.s967 = private unnamed_addr constant [1 x i8] c"\00"
@.str.s968 = private unnamed_addr constant [17 x i8] c"initializer for \00"
@.str.s969 = private unnamed_addr constant [23 x i8] c"cannot infer type for \00"
@.str.s970 = private unnamed_addr constant [11 x i8] c"assignment\00"
@.str.s971 = private unnamed_addr constant [1 x i8] c"\00"
@.str.s972 = private unnamed_addr constant [7 x i8] c"return\00"
@.str.s973 = private unnamed_addr constant [7 x i8] c"return\00"
@.str.s974 = private unnamed_addr constant [1 x i8] c"\00"
@.str.s975 = private unnamed_addr constant [13 x i8] c"if condition\00"
@.str.s976 = private unnamed_addr constant [1 x i8] c"\00"
@.str.s977 = private unnamed_addr constant [16 x i8] c"while condition\00"
@.str.s978 = private unnamed_addr constant [16 x i8] c"for range start\00"
@.str.s979 = private unnamed_addr constant [14 x i8] c"for range end\00"
@.str.s980 = private unnamed_addr constant [49 x i8] c"match scrutinee must be an integer or enum value\00"
@.str.s981 = private unnamed_addr constant [1 x i8] c"\00"
@.str.s982 = private unnamed_addr constant [2 x i8] c"_\00"
@.str.s983 = private unnamed_addr constant [14 x i8] c"match pattern\00"
@.str.s984 = private unnamed_addr constant [1 x i8] c"\00"
@.str.s985 = private unnamed_addr constant [5 x i8] c"main\00"
@.str.s986 = private unnamed_addr constant [29 x i8] c"duplicate function overload \00"
@.str.s987 = private unnamed_addr constant [1 x i8] c"\00"
@.str.s988 = private unnamed_addr constant [1 x i8] c"\00"
@.str.s989 = private unnamed_addr constant [24 x i8] c"initializer for global \00"
@.str.s990 = private unnamed_addr constant [30 x i8] c"cannot infer type for global \00"
@.str.s991 = private unnamed_addr constant [5 x i8] c"main\00"
@.str.s992 = private unnamed_addr constant [1 x i8] c"\00"
@.str.s993 = private unnamed_addr constant [6 x i8] c"inout\00"
@.str.s994 = private unnamed_addr constant [52 x i8] c"inout parameter must be a struct (reference) type: \00"
@.str.s995 = private unnamed_addr constant [5 x i8] c"sink\00"
@.str.s996 = private unnamed_addr constant [1 x i8] c"\00"
@.str.s997 = private unnamed_addr constant [1 x i8] c"\00"
@.str.s998 = private unnamed_addr constant [1 x i8] c"\00"
@.str.s999 = private unnamed_addr constant [1 x i8] c"\00"
declare ptr @read_file(ptr)
declare ptr @get_directory(ptr)
declare ptr @join_path(ptr, ptr)
declare i32 @cli_arg_count()
declare ptr @cli_arg(i32)
declare i32 @str_ends_with(ptr, ptr)
declare ptr @compiler_default_exe_path(ptr)
declare ptr @compiler_temp_ir_path(ptr)
declare i32 @compiler_build_executable(ptr, ptr)
declare i32 @compiler_bootstrap_executable(ptr, ptr)
declare i32 @compiler_run_executable(ptr)
declare ptr @compiler_runtime_source_hash()
declare ptr @compiler_installed_runtime_hash()
declare i32 @delete_file(ptr)
@.str.s1000 = private unnamed_addr constant [1 x i8] c"\00"
@.str.s1001 = private unnamed_addr constant [1 x i8] c"\00"
@.str.s1002 = private unnamed_addr constant [1 x i8] c"\00"
@.str.s1003 = private unnamed_addr constant [5 x i8] c".psm\00"
@.str.s1004 = private unnamed_addr constant [2 x i8] c".\00"
@.str.s1005 = private unnamed_addr constant [2 x i8] c"|\00"
@.str.s1006 = private unnamed_addr constant [2 x i8] c"|\00"
@.str.s1007 = private unnamed_addr constant [1 x i8] c"\00"
@.str.s1008 = private unnamed_addr constant [1 x i8] c"\00"
@.str.s1009 = private unnamed_addr constant [1 x i8] c"\00"
@.str.s1010 = private unnamed_addr constant [25 x i8] c"ERROR: Could not import \00"
@.str.s1011 = private unnamed_addr constant [1 x i8] c"\00"
@.str.s1012 = private unnamed_addr constant [7 x i8] c"Usage:\00"
@.str.s1013 = private unnamed_addr constant [45 x i8] c"  prismio build <source.psm> [-o output.exe]\00"
@.str.s1014 = private unnamed_addr constant [43 x i8] c"  prismio run <source.psm> [-o output.exe]\00"
@.str.s1015 = private unnamed_addr constant [49 x i8] c"  prismio bootstrap [source.psm] [-o output.exe]\00"
@.str.s1016 = private unnamed_addr constant [23 x i8] c"  prismio runtime-hash\00"
@.str.s1017 = private unnamed_addr constant [1 x i8] c"\00"
@.str.s1018 = private unnamed_addr constant [59 x i8] c"build/run link against the installed Prismio runtime only.\00"
@.str.s1019 = private unnamed_addr constant [66 x i8] c"bootstrap builds the compiler itself from the repository sources,\00"
@.str.s1020 = private unnamed_addr constant [71 x i8] c"linking the compiler backend as well and ignoring installed libraries.\00"
@.str.s1021 = private unnamed_addr constant [1 x i8] c"\00"
@.str.s1022 = private unnamed_addr constant [1 x i8] c"\00"
@.str.s1023 = private unnamed_addr constant [55 x i8] c"ERROR: the installed Prismio runtime library is stale.\00"
@.str.s1024 = private unnamed_addr constant [50 x i8] c"  runtime library was built from sources hashing \00"
@.str.s1025 = private unnamed_addr constant [40 x i8] c"  the runtime sources on disk now hash \00"
@.str.s1026 = private unnamed_addr constant [73 x i8] c"  Re-package the toolchain (tools/package.ps1) so lib/ matches runtime/,\00"
@.str.s1027 = private unnamed_addr constant [72 x i8] c"  or move away from the source tree to use the installed runtime as-is.\00"
@.str.s1028 = private unnamed_addr constant [1 x i8] c"\00"
@.str.s1029 = private unnamed_addr constant [4 x i8] c".ll\00"
@.str.s1030 = private unnamed_addr constant [1 x i8] c"\00"
@.str.s1031 = private unnamed_addr constant [23 x i8] c"ERROR: Could not read \00"
@.str.s1032 = private unnamed_addr constant [66 x i8] c"  bootstrap compiles the Prismio compiler from a source checkout.\00"
@.str.s1033 = private unnamed_addr constant [71 x i8] c"  Run it from the repository root, or give the source path explicitly:\00"
@.str.s1034 = private unnamed_addr constant [45 x i8] c"      prismio bootstrap path/to/src/main.psm\00"
@.str.s1035 = private unnamed_addr constant [31 x i8] c"ERROR: Could not write LLVM IR\00"
@.str.s1036 = private unnamed_addr constant [16 x i8] c"Wrote LLVM IR: \00"
@.str.s1037 = private unnamed_addr constant [27 x i8] c"ERROR: Native build failed\00"
@.str.s1038 = private unnamed_addr constant [7 x i8] c"Built \00"
@.str.s1039 = private unnamed_addr constant [35 x i8] c"ERROR: Program exited with failure\00"
@.str.s1040 = private unnamed_addr constant [1 x i8] c"\00"
@.str.s1041 = private unnamed_addr constant [1 x i8] c"\00"
@.str.s1042 = private unnamed_addr constant [1 x i8] c"\00"
@.str.s1043 = private unnamed_addr constant [13 x i8] c"runtime-hash\00"
@.str.s1044 = private unnamed_addr constant [1 x i8] c"\00"
@.str.s1045 = private unnamed_addr constant [58 x i8] c"ERROR: could not find the Prismio runtime sources to hash\00"
@.str.s1046 = private unnamed_addr constant [10 x i8] c"bootstrap\00"
@.str.s1047 = private unnamed_addr constant [10 x i8] c"bootstrap\00"
@.str.s1048 = private unnamed_addr constant [13 x i8] c"src/main.psm\00"
@.str.s1049 = private unnamed_addr constant [3 x i8] c"-o\00"
@.str.s1050 = private unnamed_addr constant [9 x i8] c"--target\00"
@.str.s1051 = private unnamed_addr constant [3 x i8] c"-o\00"
@.str.s1052 = private unnamed_addr constant [34 x i8] c"ERROR: -o requires an output path\00"
@.str.s1053 = private unnamed_addr constant [25 x i8] c"ERROR: Unknown argument \00"
@.str.s1054 = private unnamed_addr constant [6 x i8] c"build\00"
@.str.s1055 = private unnamed_addr constant [6 x i8] c"build\00"
@.str.s1056 = private unnamed_addr constant [27 x i8] c"ERROR: Missing source file\00"
@.str.s1057 = private unnamed_addr constant [4 x i8] c"run\00"
@.str.s1058 = private unnamed_addr constant [6 x i8] c"build\00"
@.str.s1059 = private unnamed_addr constant [45 x i8] c"ERROR: Use either 'build' or 'run', not both\00"
@.str.s1060 = private unnamed_addr constant [4 x i8] c"run\00"
@.str.s1061 = private unnamed_addr constant [4 x i8] c"run\00"
@.str.s1062 = private unnamed_addr constant [27 x i8] c"ERROR: Missing source file\00"
@.str.s1063 = private unnamed_addr constant [4 x i8] c"run\00"
@.str.s1064 = private unnamed_addr constant [6 x i8] c"build\00"
@.str.s1065 = private unnamed_addr constant [45 x i8] c"ERROR: Use either 'build' or 'run', not both\00"
@.str.s1066 = private unnamed_addr constant [6 x i8] c"build\00"
@.str.s1067 = private unnamed_addr constant [3 x i8] c"-o\00"
@.str.s1068 = private unnamed_addr constant [34 x i8] c"ERROR: -o requires an output path\00"
@.str.s1069 = private unnamed_addr constant [9 x i8] c"--target\00"
@.str.s1070 = private unnamed_addr constant [47 x i8] c"ERROR: --target requires a value (e.g. wasm32)\00"
@.str.s1071 = private unnamed_addr constant [7 x i8] c"wasm32\00"
@.str.s1072 = private unnamed_addr constant [6 x i8] c"build\00"
@.str.s1073 = private unnamed_addr constant [4 x i8] c"run\00"
@.str.s1074 = private unnamed_addr constant [45 x i8] c"ERROR: Use either 'build' or 'run', not both\00"
@.str.s1075 = private unnamed_addr constant [6 x i8] c"build\00"
@.str.s1076 = private unnamed_addr constant [25 x i8] c"ERROR: Unknown argument \00"

define ptr @type_to_string__Enum_TokenType(i32 %p_t) {
  %t = alloca i32
  store i32 %p_t, ptr %t
  %t1 = load i32, ptr %t
  %t2 = icmp eq i32 %t1, 0
  br i1 %t2, label %label_0, label %label_2
label_0:
  %t3 = getelementptr inbounds [7 x i8], ptr @.str.s0, i64 0, i64 0
  ret ptr %t3
label_2:
  %t4 = load i32, ptr %t
  %t5 = icmp eq i32 %t4, 1
  br i1 %t5, label %label_3, label %label_5
label_3:
  %t6 = getelementptr inbounds [5 x i8], ptr @.str.s1, i64 0, i64 0
  ret ptr %t6
label_5:
  %t7 = load i32, ptr %t
  %t8 = icmp eq i32 %t7, 2
  br i1 %t8, label %label_6, label %label_8
label_6:
  %t9 = getelementptr inbounds [7 x i8], ptr @.str.s2, i64 0, i64 0
  ret ptr %t9
label_8:
  %t10 = load i32, ptr %t
  %t11 = icmp eq i32 %t10, 3
  br i1 %t11, label %label_9, label %label_11
label_9:
  %t12 = getelementptr inbounds [6 x i8], ptr @.str.s3, i64 0, i64 0
  ret ptr %t12
label_11:
  %t13 = load i32, ptr %t
  %t14 = icmp eq i32 %t13, 4
  br i1 %t14, label %label_12, label %label_14
label_12:
  %t15 = getelementptr inbounds [5 x i8], ptr @.str.s4, i64 0, i64 0
  ret ptr %t15
label_14:
  %t16 = load i32, ptr %t
  %t17 = icmp eq i32 %t16, 5
  br i1 %t17, label %label_15, label %label_17
label_15:
  %t18 = getelementptr inbounds [11 x i8], ptr @.str.s5, i64 0, i64 0
  ret ptr %t18
label_17:
  %t19 = load i32, ptr %t
  %t20 = icmp eq i32 %t19, 18
  br i1 %t20, label %label_18, label %label_20
label_18:
  %t21 = getelementptr inbounds [8 x i8], ptr @.str.s6, i64 0, i64 0
  ret ptr %t21
label_20:
  %t22 = load i32, ptr %t
  %t23 = icmp eq i32 %t22, 6
  br i1 %t23, label %label_21, label %label_23
label_21:
  %t24 = getelementptr inbounds [10 x i8], ptr @.str.s7, i64 0, i64 0
  ret ptr %t24
label_23:
  %t25 = load i32, ptr %t
  %t26 = icmp eq i32 %t25, 8
  br i1 %t26, label %label_24, label %label_26
label_24:
  %t27 = getelementptr inbounds [9 x i8], ptr @.str.s8, i64 0, i64 0
  ret ptr %t27
label_26:
  %t28 = load i32, ptr %t
  %t29 = icmp eq i32 %t28, 9
  br i1 %t29, label %label_27, label %label_29
label_27:
  %t30 = getelementptr inbounds [7 x i8], ptr @.str.s9, i64 0, i64 0
  ret ptr %t30
label_29:
  %t31 = load i32, ptr %t
  %t32 = icmp eq i32 %t31, 12
  br i1 %t32, label %label_30, label %label_32
label_30:
  %t33 = getelementptr inbounds [10 x i8], ptr @.str.s10, i64 0, i64 0
  ret ptr %t33
label_32:
  %t34 = load i32, ptr %t
  %t35 = icmp eq i32 %t34, 15
  br i1 %t35, label %label_33, label %label_35
label_33:
  %t36 = getelementptr inbounds [6 x i8], ptr @.str.s11, i64 0, i64 0
  ret ptr %t36
label_35:
  %t37 = load i32, ptr %t
  %t38 = icmp eq i32 %t37, 20
  br i1 %t38, label %label_36, label %label_38
label_36:
  %t39 = getelementptr inbounds [4 x i8], ptr @.str.s12, i64 0, i64 0
  ret ptr %t39
label_38:
  %t40 = getelementptr inbounds [6 x i8], ptr @.str.s13, i64 0, i64 0
  ret ptr %t40
}

define i1 @is_digit__Char(i8 %p_c) {
  %c = alloca i8
  store i8 %p_c, ptr %c
  %t42 = load i8, ptr %c
  %t43 = icmp sge i8 %t42, 48
  %t44 = load i8, ptr %c
  %t45 = icmp sle i8 %t44, 57
  %t46 = and i1 %t43, %t45
  ret i1 %t46
}

define i1 @is_alpha__Char(i8 %p_c) {
  %c = alloca i8
  store i8 %p_c, ptr %c
  %t48 = load i8, ptr %c
  %t49 = icmp sge i8 %t48, 97
  %t50 = load i8, ptr %c
  %t51 = icmp sle i8 %t50, 122
  %t52 = and i1 %t49, %t51
  %t53 = load i8, ptr %c
  %t54 = icmp sge i8 %t53, 65
  %t55 = load i8, ptr %c
  %t56 = icmp sle i8 %t55, 90
  %t57 = and i1 %t54, %t56
  %t58 = or i1 %t52, %t57
  %t59 = load i8, ptr %c
  %t60 = icmp eq i8 %t59, 95
  %t61 = or i1 %t58, %t60
  ret i1 %t61
}

define i1 @is_alnum__Char(i8 %p_c) {
  %c = alloca i8
  store i8 %p_c, ptr %c
  %t63 = load i8, ptr %c
  %t64 = call i1 @is_alpha__Char(i8 %t63)
  %t65 = load i8, ptr %c
  %t66 = call i1 @is_digit__Char(i8 %t65)
  %t67 = or i1 %t64, %t66
  ret i1 %t67
}

define i1 @is_space__Char(i8 %p_c) {
  %c = alloca i8
  store i8 %p_c, ptr %c
  %t69 = load i8, ptr %c
  %t70 = icmp eq i8 %t69, 32
  %t71 = load i8, ptr %c
  %t72 = icmp eq i8 %t71, 9
  %t73 = or i1 %t70, %t72
  %t74 = load i8, ptr %c
  %t75 = icmp eq i8 %t74, 10
  %t76 = or i1 %t73, %t75
  %t77 = load i8, ptr %c
  %t78 = icmp eq i8 %t77, 13
  %t79 = or i1 %t76, %t78
  ret i1 %t79
}

define i1 @is_separator__Char(i8 %p_c) {
  %c = alloca i8
  store i8 %p_c, ptr %c
  %t81 = load i8, ptr %c
  %t82 = icmp eq i8 %t81, 40
  br i1 %t82, label %label_39, label %label_41
label_39:
  ret i1 1
label_41:
  %t83 = load i8, ptr %c
  %t84 = icmp eq i8 %t83, 41
  br i1 %t84, label %label_42, label %label_44
label_42:
  ret i1 1
label_44:
  %t85 = load i8, ptr %c
  %t86 = icmp eq i8 %t85, 123
  br i1 %t86, label %label_45, label %label_47
label_45:
  ret i1 1
label_47:
  %t87 = load i8, ptr %c
  %t88 = icmp eq i8 %t87, 125
  br i1 %t88, label %label_48, label %label_50
label_48:
  ret i1 1
label_50:
  %t89 = load i8, ptr %c
  %t90 = icmp eq i8 %t89, 91
  br i1 %t90, label %label_51, label %label_53
label_51:
  ret i1 1
label_53:
  %t91 = load i8, ptr %c
  %t92 = icmp eq i8 %t91, 93
  br i1 %t92, label %label_54, label %label_56
label_54:
  ret i1 1
label_56:
  %t93 = load i8, ptr %c
  %t94 = icmp eq i8 %t93, 44
  br i1 %t94, label %label_57, label %label_59
label_57:
  ret i1 1
label_59:
  %t95 = load i8, ptr %c
  %t96 = icmp eq i8 %t95, 46
  br i1 %t96, label %label_60, label %label_62
label_60:
  ret i1 1
label_62:
  %t97 = load i8, ptr %c
  %t98 = icmp eq i8 %t97, 58
  br i1 %t98, label %label_63, label %label_65
label_63:
  ret i1 1
label_65:
  ret i1 0
}

define i1 @is_operator__Char(i8 %p_c) {
  %c = alloca i8
  store i8 %p_c, ptr %c
  %t100 = load i8, ptr %c
  %t101 = icmp eq i8 %t100, 43
  br i1 %t101, label %label_66, label %label_68
label_66:
  ret i1 1
label_68:
  %t102 = load i8, ptr %c
  %t103 = icmp eq i8 %t102, 45
  br i1 %t103, label %label_69, label %label_71
label_69:
  ret i1 1
label_71:
  %t104 = load i8, ptr %c
  %t105 = icmp eq i8 %t104, 42
  br i1 %t105, label %label_72, label %label_74
label_72:
  ret i1 1
label_74:
  %t106 = load i8, ptr %c
  %t107 = icmp eq i8 %t106, 47
  br i1 %t107, label %label_75, label %label_77
label_75:
  ret i1 1
label_77:
  %t108 = load i8, ptr %c
  %t109 = icmp eq i8 %t108, 37
  br i1 %t109, label %label_78, label %label_80
label_78:
  ret i1 1
label_80:
  %t110 = load i8, ptr %c
  %t111 = icmp eq i8 %t110, 60
  br i1 %t111, label %label_81, label %label_83
label_81:
  ret i1 1
label_83:
  %t112 = load i8, ptr %c
  %t113 = icmp eq i8 %t112, 62
  br i1 %t113, label %label_84, label %label_86
label_84:
  ret i1 1
label_86:
  %t114 = load i8, ptr %c
  %t115 = icmp eq i8 %t114, 33
  br i1 %t115, label %label_87, label %label_89
label_87:
  ret i1 1
label_89:
  %t116 = load i8, ptr %c
  %t117 = icmp eq i8 %t116, 38
  br i1 %t117, label %label_90, label %label_92
label_90:
  ret i1 1
label_92:
  %t118 = load i8, ptr %c
  %t119 = icmp eq i8 %t118, 124
  br i1 %t119, label %label_93, label %label_95
label_93:
  ret i1 1
label_95:
  %t120 = load i8, ptr %c
  %t121 = icmp eq i8 %t120, 61
  br i1 %t121, label %label_96, label %label_98
label_96:
  ret i1 1
label_98:
  %t122 = load i8, ptr %c
  %t123 = icmp eq i8 %t122, 95
  br i1 %t123, label %label_99, label %label_101
label_99:
  ret i1 1
label_101:
  ret i1 0
}

define i32 @char_code__Char(i8 %p_c) {
  %c = alloca i8
  store i8 %p_c, ptr %c
  %t125 = load i8, ptr %c
  %t126 = icmp eq i8 %t125, 0
  br i1 %t126, label %label_102, label %label_104
label_102:
  ret i32 0
label_104:
  %t127 = load i8, ptr %c
  %t128 = icmp eq i8 %t127, 9
  br i1 %t128, label %label_105, label %label_107
label_105:
  ret i32 9
label_107:
  %t129 = load i8, ptr %c
  %t130 = icmp eq i8 %t129, 10
  br i1 %t130, label %label_108, label %label_110
label_108:
  ret i32 10
label_110:
  %t131 = load i8, ptr %c
  %t132 = icmp eq i8 %t131, 13
  br i1 %t132, label %label_111, label %label_113
label_111:
  ret i32 13
label_113:
  %t133 = load i8, ptr %c
  %t134 = icmp eq i8 %t133, 32
  br i1 %t134, label %label_114, label %label_116
label_114:
  ret i32 32
label_116:
  %t135 = load i8, ptr %c
  %t136 = icmp eq i8 %t135, 33
  br i1 %t136, label %label_117, label %label_119
label_117:
  ret i32 33
label_119:
  %t137 = load i8, ptr %c
  %t138 = icmp eq i8 %t137, 34
  br i1 %t138, label %label_120, label %label_122
label_120:
  ret i32 34
label_122:
  %t139 = load i8, ptr %c
  %t140 = icmp eq i8 %t139, 37
  br i1 %t140, label %label_123, label %label_125
label_123:
  ret i32 37
label_125:
  %t141 = load i8, ptr %c
  %t142 = icmp eq i8 %t141, 38
  br i1 %t142, label %label_126, label %label_128
label_126:
  ret i32 38
label_128:
  %t143 = load i8, ptr %c
  %t144 = icmp eq i8 %t143, 39
  br i1 %t144, label %label_129, label %label_131
label_129:
  ret i32 39
label_131:
  %t145 = load i8, ptr %c
  %t146 = icmp eq i8 %t145, 40
  br i1 %t146, label %label_132, label %label_134
label_132:
  ret i32 40
label_134:
  %t147 = load i8, ptr %c
  %t148 = icmp eq i8 %t147, 41
  br i1 %t148, label %label_135, label %label_137
label_135:
  ret i32 41
label_137:
  %t149 = load i8, ptr %c
  %t150 = icmp eq i8 %t149, 42
  br i1 %t150, label %label_138, label %label_140
label_138:
  ret i32 42
label_140:
  %t151 = load i8, ptr %c
  %t152 = icmp eq i8 %t151, 43
  br i1 %t152, label %label_141, label %label_143
label_141:
  ret i32 43
label_143:
  %t153 = load i8, ptr %c
  %t154 = icmp eq i8 %t153, 44
  br i1 %t154, label %label_144, label %label_146
label_144:
  ret i32 44
label_146:
  %t155 = load i8, ptr %c
  %t156 = icmp eq i8 %t155, 45
  br i1 %t156, label %label_147, label %label_149
label_147:
  ret i32 45
label_149:
  %t157 = load i8, ptr %c
  %t158 = icmp eq i8 %t157, 46
  br i1 %t158, label %label_150, label %label_152
label_150:
  ret i32 46
label_152:
  %t159 = load i8, ptr %c
  %t160 = icmp eq i8 %t159, 47
  br i1 %t160, label %label_153, label %label_155
label_153:
  ret i32 47
label_155:
  %t161 = load i8, ptr %c
  %t162 = icmp eq i8 %t161, 48
  br i1 %t162, label %label_156, label %label_158
label_156:
  ret i32 48
label_158:
  %t163 = load i8, ptr %c
  %t164 = icmp eq i8 %t163, 49
  br i1 %t164, label %label_159, label %label_161
label_159:
  ret i32 49
label_161:
  %t165 = load i8, ptr %c
  %t166 = icmp eq i8 %t165, 50
  br i1 %t166, label %label_162, label %label_164
label_162:
  ret i32 50
label_164:
  %t167 = load i8, ptr %c
  %t168 = icmp eq i8 %t167, 51
  br i1 %t168, label %label_165, label %label_167
label_165:
  ret i32 51
label_167:
  %t169 = load i8, ptr %c
  %t170 = icmp eq i8 %t169, 52
  br i1 %t170, label %label_168, label %label_170
label_168:
  ret i32 52
label_170:
  %t171 = load i8, ptr %c
  %t172 = icmp eq i8 %t171, 53
  br i1 %t172, label %label_171, label %label_173
label_171:
  ret i32 53
label_173:
  %t173 = load i8, ptr %c
  %t174 = icmp eq i8 %t173, 54
  br i1 %t174, label %label_174, label %label_176
label_174:
  ret i32 54
label_176:
  %t175 = load i8, ptr %c
  %t176 = icmp eq i8 %t175, 55
  br i1 %t176, label %label_177, label %label_179
label_177:
  ret i32 55
label_179:
  %t177 = load i8, ptr %c
  %t178 = icmp eq i8 %t177, 56
  br i1 %t178, label %label_180, label %label_182
label_180:
  ret i32 56
label_182:
  %t179 = load i8, ptr %c
  %t180 = icmp eq i8 %t179, 57
  br i1 %t180, label %label_183, label %label_185
label_183:
  ret i32 57
label_185:
  %t181 = load i8, ptr %c
  %t182 = icmp eq i8 %t181, 58
  br i1 %t182, label %label_186, label %label_188
label_186:
  ret i32 58
label_188:
  %t183 = load i8, ptr %c
  %t184 = icmp eq i8 %t183, 60
  br i1 %t184, label %label_189, label %label_191
label_189:
  ret i32 60
label_191:
  %t185 = load i8, ptr %c
  %t186 = icmp eq i8 %t185, 61
  br i1 %t186, label %label_192, label %label_194
label_192:
  ret i32 61
label_194:
  %t187 = load i8, ptr %c
  %t188 = icmp eq i8 %t187, 62
  br i1 %t188, label %label_195, label %label_197
label_195:
  ret i32 62
label_197:
  %t189 = load i8, ptr %c
  %t190 = icmp eq i8 %t189, 65
  br i1 %t190, label %label_198, label %label_200
label_198:
  ret i32 65
label_200:
  %t191 = load i8, ptr %c
  %t192 = icmp eq i8 %t191, 66
  br i1 %t192, label %label_201, label %label_203
label_201:
  ret i32 66
label_203:
  %t193 = load i8, ptr %c
  %t194 = icmp eq i8 %t193, 67
  br i1 %t194, label %label_204, label %label_206
label_204:
  ret i32 67
label_206:
  %t195 = load i8, ptr %c
  %t196 = icmp eq i8 %t195, 68
  br i1 %t196, label %label_207, label %label_209
label_207:
  ret i32 68
label_209:
  %t197 = load i8, ptr %c
  %t198 = icmp eq i8 %t197, 69
  br i1 %t198, label %label_210, label %label_212
label_210:
  ret i32 69
label_212:
  %t199 = load i8, ptr %c
  %t200 = icmp eq i8 %t199, 70
  br i1 %t200, label %label_213, label %label_215
label_213:
  ret i32 70
label_215:
  %t201 = load i8, ptr %c
  %t202 = icmp eq i8 %t201, 71
  br i1 %t202, label %label_216, label %label_218
label_216:
  ret i32 71
label_218:
  %t203 = load i8, ptr %c
  %t204 = icmp eq i8 %t203, 72
  br i1 %t204, label %label_219, label %label_221
label_219:
  ret i32 72
label_221:
  %t205 = load i8, ptr %c
  %t206 = icmp eq i8 %t205, 73
  br i1 %t206, label %label_222, label %label_224
label_222:
  ret i32 73
label_224:
  %t207 = load i8, ptr %c
  %t208 = icmp eq i8 %t207, 74
  br i1 %t208, label %label_225, label %label_227
label_225:
  ret i32 74
label_227:
  %t209 = load i8, ptr %c
  %t210 = icmp eq i8 %t209, 75
  br i1 %t210, label %label_228, label %label_230
label_228:
  ret i32 75
label_230:
  %t211 = load i8, ptr %c
  %t212 = icmp eq i8 %t211, 76
  br i1 %t212, label %label_231, label %label_233
label_231:
  ret i32 76
label_233:
  %t213 = load i8, ptr %c
  %t214 = icmp eq i8 %t213, 77
  br i1 %t214, label %label_234, label %label_236
label_234:
  ret i32 77
label_236:
  %t215 = load i8, ptr %c
  %t216 = icmp eq i8 %t215, 78
  br i1 %t216, label %label_237, label %label_239
label_237:
  ret i32 78
label_239:
  %t217 = load i8, ptr %c
  %t218 = icmp eq i8 %t217, 79
  br i1 %t218, label %label_240, label %label_242
label_240:
  ret i32 79
label_242:
  %t219 = load i8, ptr %c
  %t220 = icmp eq i8 %t219, 80
  br i1 %t220, label %label_243, label %label_245
label_243:
  ret i32 80
label_245:
  %t221 = load i8, ptr %c
  %t222 = icmp eq i8 %t221, 81
  br i1 %t222, label %label_246, label %label_248
label_246:
  ret i32 81
label_248:
  %t223 = load i8, ptr %c
  %t224 = icmp eq i8 %t223, 82
  br i1 %t224, label %label_249, label %label_251
label_249:
  ret i32 82
label_251:
  %t225 = load i8, ptr %c
  %t226 = icmp eq i8 %t225, 83
  br i1 %t226, label %label_252, label %label_254
label_252:
  ret i32 83
label_254:
  %t227 = load i8, ptr %c
  %t228 = icmp eq i8 %t227, 84
  br i1 %t228, label %label_255, label %label_257
label_255:
  ret i32 84
label_257:
  %t229 = load i8, ptr %c
  %t230 = icmp eq i8 %t229, 85
  br i1 %t230, label %label_258, label %label_260
label_258:
  ret i32 85
label_260:
  %t231 = load i8, ptr %c
  %t232 = icmp eq i8 %t231, 86
  br i1 %t232, label %label_261, label %label_263
label_261:
  ret i32 86
label_263:
  %t233 = load i8, ptr %c
  %t234 = icmp eq i8 %t233, 87
  br i1 %t234, label %label_264, label %label_266
label_264:
  ret i32 87
label_266:
  %t235 = load i8, ptr %c
  %t236 = icmp eq i8 %t235, 88
  br i1 %t236, label %label_267, label %label_269
label_267:
  ret i32 88
label_269:
  %t237 = load i8, ptr %c
  %t238 = icmp eq i8 %t237, 89
  br i1 %t238, label %label_270, label %label_272
label_270:
  ret i32 89
label_272:
  %t239 = load i8, ptr %c
  %t240 = icmp eq i8 %t239, 90
  br i1 %t240, label %label_273, label %label_275
label_273:
  ret i32 90
label_275:
  %t241 = load i8, ptr %c
  %t242 = icmp eq i8 %t241, 91
  br i1 %t242, label %label_276, label %label_278
label_276:
  ret i32 91
label_278:
  %t243 = load i8, ptr %c
  %t244 = icmp eq i8 %t243, 92
  br i1 %t244, label %label_279, label %label_281
label_279:
  ret i32 92
label_281:
  %t245 = load i8, ptr %c
  %t246 = icmp eq i8 %t245, 93
  br i1 %t246, label %label_282, label %label_284
label_282:
  ret i32 93
label_284:
  %t247 = load i8, ptr %c
  %t248 = icmp eq i8 %t247, 95
  br i1 %t248, label %label_285, label %label_287
label_285:
  ret i32 95
label_287:
  %t249 = load i8, ptr %c
  %t250 = icmp eq i8 %t249, 97
  br i1 %t250, label %label_288, label %label_290
label_288:
  ret i32 97
label_290:
  %t251 = load i8, ptr %c
  %t252 = icmp eq i8 %t251, 98
  br i1 %t252, label %label_291, label %label_293
label_291:
  ret i32 98
label_293:
  %t253 = load i8, ptr %c
  %t254 = icmp eq i8 %t253, 99
  br i1 %t254, label %label_294, label %label_296
label_294:
  ret i32 99
label_296:
  %t255 = load i8, ptr %c
  %t256 = icmp eq i8 %t255, 100
  br i1 %t256, label %label_297, label %label_299
label_297:
  ret i32 100
label_299:
  %t257 = load i8, ptr %c
  %t258 = icmp eq i8 %t257, 101
  br i1 %t258, label %label_300, label %label_302
label_300:
  ret i32 101
label_302:
  %t259 = load i8, ptr %c
  %t260 = icmp eq i8 %t259, 102
  br i1 %t260, label %label_303, label %label_305
label_303:
  ret i32 102
label_305:
  %t261 = load i8, ptr %c
  %t262 = icmp eq i8 %t261, 103
  br i1 %t262, label %label_306, label %label_308
label_306:
  ret i32 103
label_308:
  %t263 = load i8, ptr %c
  %t264 = icmp eq i8 %t263, 104
  br i1 %t264, label %label_309, label %label_311
label_309:
  ret i32 104
label_311:
  %t265 = load i8, ptr %c
  %t266 = icmp eq i8 %t265, 105
  br i1 %t266, label %label_312, label %label_314
label_312:
  ret i32 105
label_314:
  %t267 = load i8, ptr %c
  %t268 = icmp eq i8 %t267, 106
  br i1 %t268, label %label_315, label %label_317
label_315:
  ret i32 106
label_317:
  %t269 = load i8, ptr %c
  %t270 = icmp eq i8 %t269, 107
  br i1 %t270, label %label_318, label %label_320
label_318:
  ret i32 107
label_320:
  %t271 = load i8, ptr %c
  %t272 = icmp eq i8 %t271, 108
  br i1 %t272, label %label_321, label %label_323
label_321:
  ret i32 108
label_323:
  %t273 = load i8, ptr %c
  %t274 = icmp eq i8 %t273, 109
  br i1 %t274, label %label_324, label %label_326
label_324:
  ret i32 109
label_326:
  %t275 = load i8, ptr %c
  %t276 = icmp eq i8 %t275, 110
  br i1 %t276, label %label_327, label %label_329
label_327:
  ret i32 110
label_329:
  %t277 = load i8, ptr %c
  %t278 = icmp eq i8 %t277, 111
  br i1 %t278, label %label_330, label %label_332
label_330:
  ret i32 111
label_332:
  %t279 = load i8, ptr %c
  %t280 = icmp eq i8 %t279, 112
  br i1 %t280, label %label_333, label %label_335
label_333:
  ret i32 112
label_335:
  %t281 = load i8, ptr %c
  %t282 = icmp eq i8 %t281, 113
  br i1 %t282, label %label_336, label %label_338
label_336:
  ret i32 113
label_338:
  %t283 = load i8, ptr %c
  %t284 = icmp eq i8 %t283, 114
  br i1 %t284, label %label_339, label %label_341
label_339:
  ret i32 114
label_341:
  %t285 = load i8, ptr %c
  %t286 = icmp eq i8 %t285, 115
  br i1 %t286, label %label_342, label %label_344
label_342:
  ret i32 115
label_344:
  %t287 = load i8, ptr %c
  %t288 = icmp eq i8 %t287, 116
  br i1 %t288, label %label_345, label %label_347
label_345:
  ret i32 116
label_347:
  %t289 = load i8, ptr %c
  %t290 = icmp eq i8 %t289, 117
  br i1 %t290, label %label_348, label %label_350
label_348:
  ret i32 117
label_350:
  %t291 = load i8, ptr %c
  %t292 = icmp eq i8 %t291, 118
  br i1 %t292, label %label_351, label %label_353
label_351:
  ret i32 118
label_353:
  %t293 = load i8, ptr %c
  %t294 = icmp eq i8 %t293, 119
  br i1 %t294, label %label_354, label %label_356
label_354:
  ret i32 119
label_356:
  %t295 = load i8, ptr %c
  %t296 = icmp eq i8 %t295, 120
  br i1 %t296, label %label_357, label %label_359
label_357:
  ret i32 120
label_359:
  %t297 = load i8, ptr %c
  %t298 = icmp eq i8 %t297, 121
  br i1 %t298, label %label_360, label %label_362
label_360:
  ret i32 121
label_362:
  %t299 = load i8, ptr %c
  %t300 = icmp eq i8 %t299, 122
  br i1 %t300, label %label_363, label %label_365
label_363:
  ret i32 122
label_365:
  %t301 = load i8, ptr %c
  %t302 = icmp eq i8 %t301, 123
  br i1 %t302, label %label_366, label %label_368
label_366:
  ret i32 123
label_368:
  %t303 = load i8, ptr %c
  %t304 = icmp eq i8 %t303, 124
  br i1 %t304, label %label_369, label %label_371
label_369:
  ret i32 124
label_371:
  %t305 = load i8, ptr %c
  %t306 = icmp eq i8 %t305, 125
  br i1 %t306, label %label_372, label %label_374
label_372:
  ret i32 125
label_374:
  ret i32 0
}

define i1 @is_keyword__String(ptr %p_s) {
  %s = alloca ptr
  store ptr %p_s, ptr %s
  %t308 = load ptr, ptr %s
  %t309 = getelementptr inbounds [7 x i8], ptr @.str.s14, i64 0, i64 0
  %t310 = call i32 @str_equals(ptr %t308, ptr %t309)
  %t311 = icmp eq i32 %t310, 1
  br i1 %t311, label %label_375, label %label_377
label_375:
  ret i1 1
label_377:
  %t312 = load ptr, ptr %s
  %t313 = getelementptr inbounds [6 x i8], ptr @.str.s15, i64 0, i64 0
  %t314 = call i32 @str_equals(ptr %t312, ptr %t313)
  %t315 = icmp eq i32 %t314, 1
  br i1 %t315, label %label_378, label %label_380
label_378:
  ret i1 1
label_380:
  %t316 = load ptr, ptr %s
  %t317 = getelementptr inbounds [3 x i8], ptr @.str.s16, i64 0, i64 0
  %t318 = call i32 @str_equals(ptr %t316, ptr %t317)
  %t319 = icmp eq i32 %t318, 1
  br i1 %t319, label %label_381, label %label_383
label_381:
  ret i1 1
label_383:
  %t320 = load ptr, ptr %s
  %t321 = getelementptr inbounds [5 x i8], ptr @.str.s17, i64 0, i64 0
  %t322 = call i32 @str_equals(ptr %t320, ptr %t321)
  %t323 = icmp eq i32 %t322, 1
  br i1 %t323, label %label_384, label %label_386
label_384:
  ret i1 1
label_386:
  %t324 = load ptr, ptr %s
  %t325 = getelementptr inbounds [4 x i8], ptr @.str.s18, i64 0, i64 0
  %t326 = call i32 @str_equals(ptr %t324, ptr %t325)
  %t327 = icmp eq i32 %t326, 1
  br i1 %t327, label %label_387, label %label_389
label_387:
  ret i1 1
label_389:
  %t328 = load ptr, ptr %s
  %t329 = getelementptr inbounds [3 x i8], ptr @.str.s19, i64 0, i64 0
  %t330 = call i32 @str_equals(ptr %t328, ptr %t329)
  %t331 = icmp eq i32 %t330, 1
  br i1 %t331, label %label_390, label %label_392
label_390:
  ret i1 1
label_392:
  %t332 = load ptr, ptr %s
  %t333 = getelementptr inbounds [5 x i8], ptr @.str.s20, i64 0, i64 0
  %t334 = call i32 @str_equals(ptr %t332, ptr %t333)
  %t335 = icmp eq i32 %t334, 1
  br i1 %t335, label %label_393, label %label_395
label_393:
  ret i1 1
label_395:
  %t336 = load ptr, ptr %s
  %t337 = getelementptr inbounds [6 x i8], ptr @.str.s21, i64 0, i64 0
  %t338 = call i32 @str_equals(ptr %t336, ptr %t337)
  %t339 = icmp eq i32 %t338, 1
  br i1 %t339, label %label_396, label %label_398
label_396:
  ret i1 1
label_398:
  %t340 = load ptr, ptr %s
  %t341 = getelementptr inbounds [6 x i8], ptr @.str.s22, i64 0, i64 0
  %t342 = call i32 @str_equals(ptr %t340, ptr %t341)
  %t343 = icmp eq i32 %t342, 1
  br i1 %t343, label %label_399, label %label_401
label_399:
  ret i1 1
label_401:
  %t344 = load ptr, ptr %s
  %t345 = getelementptr inbounds [9 x i8], ptr @.str.s23, i64 0, i64 0
  %t346 = call i32 @str_equals(ptr %t344, ptr %t345)
  %t347 = icmp eq i32 %t346, 1
  br i1 %t347, label %label_402, label %label_404
label_402:
  ret i1 1
label_404:
  %t348 = load ptr, ptr %s
  %t349 = getelementptr inbounds [7 x i8], ptr @.str.s24, i64 0, i64 0
  %t350 = call i32 @str_equals(ptr %t348, ptr %t349)
  %t351 = icmp eq i32 %t350, 1
  br i1 %t351, label %label_405, label %label_407
label_405:
  ret i1 1
label_407:
  %t352 = load ptr, ptr %s
  %t353 = getelementptr inbounds [6 x i8], ptr @.str.s25, i64 0, i64 0
  %t354 = call i32 @str_equals(ptr %t352, ptr %t353)
  %t355 = icmp eq i32 %t354, 1
  br i1 %t355, label %label_408, label %label_410
label_408:
  ret i1 1
label_410:
  %t356 = load ptr, ptr %s
  %t357 = getelementptr inbounds [6 x i8], ptr @.str.s26, i64 0, i64 0
  %t358 = call i32 @str_equals(ptr %t356, ptr %t357)
  %t359 = icmp eq i32 %t358, 1
  br i1 %t359, label %label_411, label %label_413
label_411:
  ret i1 1
label_413:
  %t360 = load ptr, ptr %s
  %t361 = getelementptr inbounds [5 x i8], ptr @.str.s27, i64 0, i64 0
  %t362 = call i32 @str_equals(ptr %t360, ptr %t361)
  %t363 = icmp eq i32 %t362, 1
  br i1 %t363, label %label_414, label %label_416
label_414:
  ret i1 1
label_416:
  %t364 = load ptr, ptr %s
  %t365 = getelementptr inbounds [4 x i8], ptr @.str.s28, i64 0, i64 0
  %t366 = call i32 @str_equals(ptr %t364, ptr %t365)
  %t367 = icmp eq i32 %t366, 1
  br i1 %t367, label %label_417, label %label_419
label_417:
  ret i1 1
label_419:
  %t368 = load ptr, ptr %s
  %t369 = getelementptr inbounds [3 x i8], ptr @.str.s29, i64 0, i64 0
  %t370 = call i32 @str_equals(ptr %t368, ptr %t369)
  %t371 = icmp eq i32 %t370, 1
  br i1 %t371, label %label_420, label %label_422
label_420:
  ret i1 1
label_422:
  %t372 = load ptr, ptr %s
  %t373 = getelementptr inbounds [4 x i8], ptr @.str.s30, i64 0, i64 0
  %t374 = call i32 @str_equals(ptr %t372, ptr %t373)
  %t375 = icmp eq i32 %t374, 1
  br i1 %t375, label %label_423, label %label_425
label_423:
  ret i1 1
label_425:
  %t376 = load ptr, ptr %s
  %t377 = getelementptr inbounds [7 x i8], ptr @.str.s31, i64 0, i64 0
  %t378 = call i32 @str_equals(ptr %t376, ptr %t377)
  %t379 = icmp eq i32 %t378, 1
  br i1 %t379, label %label_426, label %label_428
label_426:
  ret i1 1
label_428:
  %t380 = load ptr, ptr %s
  %t381 = getelementptr inbounds [5 x i8], ptr @.str.s32, i64 0, i64 0
  %t382 = call i32 @str_equals(ptr %t380, ptr %t381)
  %t383 = icmp eq i32 %t382, 1
  br i1 %t383, label %label_429, label %label_431
label_429:
  ret i1 1
label_431:
  %t384 = load ptr, ptr %s
  %t385 = getelementptr inbounds [5 x i8], ptr @.str.s33, i64 0, i64 0
  %t386 = call i32 @str_equals(ptr %t384, ptr %t385)
  %t387 = icmp eq i32 %t386, 1
  br i1 %t387, label %label_432, label %label_434
label_432:
  ret i1 1
label_434:
  %t388 = load ptr, ptr %s
  %t389 = getelementptr inbounds [6 x i8], ptr @.str.s34, i64 0, i64 0
  %t390 = call i32 @str_equals(ptr %t388, ptr %t389)
  %t391 = icmp eq i32 %t390, 1
  br i1 %t391, label %label_435, label %label_437
label_435:
  ret i1 1
label_437:
  %t392 = load ptr, ptr %s
  %t393 = getelementptr inbounds [3 x i8], ptr @.str.s35, i64 0, i64 0
  %t394 = call i32 @str_equals(ptr %t392, ptr %t393)
  %t395 = icmp eq i32 %t394, 1
  br i1 %t395, label %label_438, label %label_440
label_438:
  ret i1 1
label_440:
  %t396 = load ptr, ptr %s
  %t397 = getelementptr inbounds [7 x i8], ptr @.str.s36, i64 0, i64 0
  %t398 = call i32 @str_equals(ptr %t396, ptr %t397)
  %t399 = icmp eq i32 %t398, 1
  br i1 %t399, label %label_441, label %label_443
label_441:
  ret i1 1
label_443:
  %t400 = load ptr, ptr %s
  %t401 = getelementptr inbounds [4 x i8], ptr @.str.s37, i64 0, i64 0
  %t402 = call i32 @str_equals(ptr %t400, ptr %t401)
  %t403 = icmp eq i32 %t402, 1
  br i1 %t403, label %label_444, label %label_446
label_444:
  ret i1 1
label_446:
  %t404 = load ptr, ptr %s
  %t405 = getelementptr inbounds [6 x i8], ptr @.str.s38, i64 0, i64 0
  %t406 = call i32 @str_equals(ptr %t404, ptr %t405)
  %t407 = icmp eq i32 %t406, 1
  br i1 %t407, label %label_447, label %label_449
label_447:
  ret i1 1
label_449:
  %t408 = load ptr, ptr %s
  %t409 = getelementptr inbounds [5 x i8], ptr @.str.s39, i64 0, i64 0
  %t410 = call i32 @str_equals(ptr %t408, ptr %t409)
  %t411 = icmp eq i32 %t410, 1
  br i1 %t411, label %label_450, label %label_452
label_450:
  ret i1 1
label_452:
  ret i1 0
}

define i1 @is_boolean__String(ptr %p_s) {
  %s = alloca ptr
  store ptr %p_s, ptr %s
  %t413 = load ptr, ptr %s
  %t414 = getelementptr inbounds [5 x i8], ptr @.str.s40, i64 0, i64 0
  %t415 = call i32 @str_equals(ptr %t413, ptr %t414)
  %t416 = icmp eq i32 %t415, 1
  br i1 %t416, label %label_453, label %label_455
label_453:
  ret i1 1
label_455:
  %t417 = load ptr, ptr %s
  %t418 = getelementptr inbounds [6 x i8], ptr @.str.s41, i64 0, i64 0
  %t419 = call i32 @str_equals(ptr %t417, ptr %t418)
  %t420 = icmp eq i32 %t419, 1
  br i1 %t420, label %label_456, label %label_458
label_456:
  ret i1 1
label_458:
  ret i1 0
}

define ptr @create_lexer__String(ptr %p_input) {
  %input = alloca ptr
  store ptr %p_input, ptr %input
  %t422 = getelementptr %Lexer, ptr null, i32 1
  %t423 = ptrtoint ptr %t422 to i64
  %t424 = call ptr @malloc(i64 %t423)
  %t425 = load ptr, ptr %input
  %t426 = getelementptr inbounds %Lexer, ptr %t424, i32 0, i32 0
  store ptr %t425, ptr %t426
  %t427 = getelementptr inbounds %Lexer, ptr %t424, i32 0, i32 1
  store i32 0, ptr %t427
  %t428 = getelementptr inbounds %Lexer, ptr %t424, i32 0, i32 2
  store i32 1, ptr %t428
  %t429 = getelementptr inbounds %Lexer, ptr %t424, i32 0, i32 3
  store i32 1, ptr %t429
  ret ptr %t424
}

define i8 @lexer_peek__Struct_Lexer_Int(ptr %p_lex, i32 %p_offset) {
  %lex = alloca ptr
  %offset = alloca i32
  store ptr %p_lex, ptr %lex
  store i32 %p_offset, ptr %offset
  %t432 = load ptr, ptr %lex
  %t433 = getelementptr inbounds %Lexer, ptr %t432, i32 0, i32 0
  %t434 = load ptr, ptr %t433
  %t435 = load ptr, ptr %lex
  %t436 = getelementptr inbounds %Lexer, ptr %t435, i32 0, i32 1
  %t437 = load i32, ptr %t436
  %t438 = load i32, ptr %offset
  %t439 = add i32 %t437, %t438
  %t440 = call i8 @str_char_at(ptr %t434, i32 %t439)
  ret i8 %t440
}

define i8 @lexer_current__Struct_Lexer(ptr %p_lex) {
  %lex = alloca ptr
  store ptr %p_lex, ptr %lex
  %t442 = load ptr, ptr %lex
  %t443 = getelementptr inbounds %Lexer, ptr %t442, i32 0, i32 0
  %t444 = load ptr, ptr %t443
  %t445 = load ptr, ptr %lex
  %t446 = getelementptr inbounds %Lexer, ptr %t445, i32 0, i32 1
  %t447 = load i32, ptr %t446
  %t448 = call i8 @str_char_at(ptr %t444, i32 %t447)
  ret i8 %t448
}

define void @lexer_advance__Struct_Lexer(ptr %p_lex) {
  %lex = alloca ptr
  store ptr %p_lex, ptr %lex
  %t450 = load ptr, ptr %lex
  %t451 = load ptr, ptr %lex
  %t452 = getelementptr inbounds %Lexer, ptr %t451, i32 0, i32 1
  %t453 = load i32, ptr %t452
  %t454 = add i32 %t453, 1
  %t455 = getelementptr inbounds %Lexer, ptr %t450, i32 0, i32 1
  store i32 %t454, ptr %t455
  %t456 = load ptr, ptr %lex
  %t457 = load ptr, ptr %lex
  %t458 = getelementptr inbounds %Lexer, ptr %t457, i32 0, i32 3
  %t459 = load i32, ptr %t458
  %t460 = add i32 %t459, 1
  %t461 = getelementptr inbounds %Lexer, ptr %t456, i32 0, i32 3
  store i32 %t460, ptr %t461
  ret void
}

define void @lexer_skip_whitespace__Struct_Lexer(ptr %p_lex) {
  %lex = alloca ptr
  %is_looping = alloca i1
  store ptr %p_lex, ptr %lex
  store i1 1, ptr %is_looping
  br label %label_459
label_459:
  %t464 = load i1, ptr %is_looping
  br i1 %t464, label %label_460, label %label_461
label_460:
  %t465 = load ptr, ptr %lex
  %t466 = call i8 @lexer_current__Struct_Lexer(ptr %t465)
  %t467 = call i1 @is_space__Char(i8 %t466)
  br i1 %t467, label %label_462, label %label_463
label_462:
  %t468 = load ptr, ptr %lex
  %t469 = call i8 @lexer_current__Struct_Lexer(ptr %t468)
  %t470 = icmp eq i8 %t469, 10
  br i1 %t470, label %label_465, label %label_467
label_465:
  %t471 = load ptr, ptr %lex
  %t472 = load ptr, ptr %lex
  %t473 = getelementptr inbounds %Lexer, ptr %t472, i32 0, i32 2
  %t474 = load i32, ptr %t473
  %t475 = add i32 %t474, 1
  %t476 = getelementptr inbounds %Lexer, ptr %t471, i32 0, i32 2
  store i32 %t475, ptr %t476
  %t477 = load ptr, ptr %lex
  %t478 = getelementptr inbounds %Lexer, ptr %t477, i32 0, i32 3
  store i32 0, ptr %t478
  br label %label_467
label_467:
  %t479 = load ptr, ptr %lex
  call void @lexer_advance__Struct_Lexer(ptr %t479)
  br label %label_464
label_463:
  %t480 = load ptr, ptr %lex
  %t481 = call i8 @lexer_current__Struct_Lexer(ptr %t480)
  %t482 = icmp eq i8 %t481, 47
  %t483 = load ptr, ptr %lex
  %t484 = call i8 @lexer_peek__Struct_Lexer_Int(ptr %t483, i32 1)
  %t485 = icmp eq i8 %t484, 47
  %t486 = and i1 %t482, %t485
  br i1 %t486, label %label_468, label %label_469
label_468:
  br label %label_471
label_471:
  %t487 = load ptr, ptr %lex
  %t488 = call i8 @lexer_current__Struct_Lexer(ptr %t487)
  %t489 = icmp ne i8 %t488, 10
  %t490 = load ptr, ptr %lex
  %t491 = call i8 @lexer_current__Struct_Lexer(ptr %t490)
  %t492 = icmp ne i8 %t491, 0
  %t493 = and i1 %t489, %t492
  br i1 %t493, label %label_472, label %label_473
label_472:
  %t494 = load ptr, ptr %lex
  call void @lexer_advance__Struct_Lexer(ptr %t494)
  br label %label_471
label_473:
  br label %label_470
label_469:
  store i1 0, ptr %is_looping
  br label %label_470
label_470:
  br label %label_464
label_464:
  br label %label_459
label_461:
  ret void
}

define ptr @lexer_next_token__Struct_Lexer(ptr %p_lex) {
  %lex = alloca ptr
  %c = alloca i8
  %start = alloca i32
  %length = alloca i32
  %value = alloca ptr
  %is_float = alloca i32
  %value_char = alloca i8
  %esc = alloca i8
  %next = alloca i8
  %type = alloca i32
  %val = alloca ptr
  store ptr %p_lex, ptr %lex
  %t506 = load ptr, ptr %lex
  call void @lexer_skip_whitespace__Struct_Lexer(ptr %t506)
  %t507 = load ptr, ptr %lex
  %t508 = getelementptr inbounds %Lexer, ptr %t507, i32 0, i32 1
  %t509 = load i32, ptr %t508
  %t510 = load ptr, ptr %lex
  %t511 = getelementptr inbounds %Lexer, ptr %t510, i32 0, i32 0
  %t512 = load ptr, ptr %t511
  %t513 = call i32 @str_length(ptr %t512)
  %t514 = icmp sge i32 %t509, %t513
  br i1 %t514, label %label_474, label %label_476
label_474:
  %t515 = getelementptr %Token, ptr null, i32 1
  %t516 = ptrtoint ptr %t515 to i64
  %t517 = call ptr @malloc(i64 %t516)
  %t518 = getelementptr inbounds %Token, ptr %t517, i32 0, i32 0
  store i32 20, ptr %t518
  %t519 = getelementptr inbounds [4 x i8], ptr @.str.s42, i64 0, i64 0
  %t520 = getelementptr inbounds %Token, ptr %t517, i32 0, i32 1
  store ptr %t519, ptr %t520
  %t521 = load ptr, ptr %lex
  %t522 = getelementptr inbounds %Lexer, ptr %t521, i32 0, i32 2
  %t523 = load i32, ptr %t522
  %t524 = getelementptr inbounds %Token, ptr %t517, i32 0, i32 2
  store i32 %t523, ptr %t524
  %t525 = getelementptr inbounds [1 x i8], ptr @.str.s43, i64 0, i64 0
  %t526 = getelementptr inbounds %Token, ptr %t517, i32 0, i32 3
  store ptr %t525, ptr %t526
  ret ptr %t517
label_476:
  %t527 = load ptr, ptr %lex
  %t528 = call i8 @lexer_current__Struct_Lexer(ptr %t527)
  store i8 %t528, ptr %c
  %t529 = load i8, ptr %c
  %t530 = call i1 @is_alpha__Char(i8 %t529)
  br i1 %t530, label %label_477, label %label_479
label_477:
  %t531 = load ptr, ptr %lex
  %t532 = getelementptr inbounds %Lexer, ptr %t531, i32 0, i32 1
  %t533 = load i32, ptr %t532
  store i32 %t533, ptr %start
  br label %label_480
label_480:
  %t534 = load ptr, ptr %lex
  %t535 = call i8 @lexer_current__Struct_Lexer(ptr %t534)
  %t536 = call i1 @is_alnum__Char(i8 %t535)
  br i1 %t536, label %label_481, label %label_482
label_481:
  %t537 = load ptr, ptr %lex
  call void @lexer_advance__Struct_Lexer(ptr %t537)
  br label %label_480
label_482:
  %t538 = load ptr, ptr %lex
  %t539 = getelementptr inbounds %Lexer, ptr %t538, i32 0, i32 1
  %t540 = load i32, ptr %t539
  %t541 = load i32, ptr %start
  %t542 = sub i32 %t540, %t541
  store i32 %t542, ptr %length
  %t543 = load ptr, ptr %lex
  %t544 = getelementptr inbounds %Lexer, ptr %t543, i32 0, i32 0
  %t545 = load ptr, ptr %t544
  %t546 = load i32, ptr %start
  %t547 = load i32, ptr %length
  %t548 = call ptr @str_substring(ptr %t545, i32 %t546, i32 %t547)
  store ptr %t548, ptr %value
  %t549 = load ptr, ptr %value
  %t550 = call i1 @is_keyword__String(ptr %t549)
  br i1 %t550, label %label_483, label %label_485
label_483:
  %t551 = load ptr, ptr %value
  %t552 = call i1 @is_boolean__String(ptr %t551)
  br i1 %t552, label %label_486, label %label_488
label_486:
  %t553 = getelementptr %Token, ptr null, i32 1
  %t554 = ptrtoint ptr %t553 to i64
  %t555 = call ptr @malloc(i64 %t554)
  %t556 = getelementptr inbounds %Token, ptr %t555, i32 0, i32 0
  store i32 4, ptr %t556
  %t557 = load ptr, ptr %value
  %t558 = getelementptr inbounds %Token, ptr %t555, i32 0, i32 1
  store ptr %t557, ptr %t558
  %t559 = load ptr, ptr %lex
  %t560 = getelementptr inbounds %Lexer, ptr %t559, i32 0, i32 2
  %t561 = load i32, ptr %t560
  %t562 = getelementptr inbounds %Token, ptr %t555, i32 0, i32 2
  store i32 %t561, ptr %t562
  %t563 = getelementptr inbounds [1 x i8], ptr @.str.s44, i64 0, i64 0
  %t564 = getelementptr inbounds %Token, ptr %t555, i32 0, i32 3
  store ptr %t563, ptr %t564
  ret ptr %t555
label_488:
  %t565 = getelementptr %Token, ptr null, i32 1
  %t566 = ptrtoint ptr %t565 to i64
  %t567 = call ptr @malloc(i64 %t566)
  %t568 = getelementptr inbounds %Token, ptr %t567, i32 0, i32 0
  store i32 18, ptr %t568
  %t569 = load ptr, ptr %value
  %t570 = getelementptr inbounds %Token, ptr %t567, i32 0, i32 1
  store ptr %t569, ptr %t570
  %t571 = load ptr, ptr %lex
  %t572 = getelementptr inbounds %Lexer, ptr %t571, i32 0, i32 2
  %t573 = load i32, ptr %t572
  %t574 = getelementptr inbounds %Token, ptr %t567, i32 0, i32 2
  store i32 %t573, ptr %t574
  %t575 = getelementptr inbounds [1 x i8], ptr @.str.s45, i64 0, i64 0
  %t576 = getelementptr inbounds %Token, ptr %t567, i32 0, i32 3
  store ptr %t575, ptr %t576
  ret ptr %t567
label_485:
  %t577 = getelementptr %Token, ptr null, i32 1
  %t578 = ptrtoint ptr %t577 to i64
  %t579 = call ptr @malloc(i64 %t578)
  %t580 = getelementptr inbounds %Token, ptr %t579, i32 0, i32 0
  store i32 5, ptr %t580
  %t581 = load ptr, ptr %value
  %t582 = getelementptr inbounds %Token, ptr %t579, i32 0, i32 1
  store ptr %t581, ptr %t582
  %t583 = load ptr, ptr %lex
  %t584 = getelementptr inbounds %Lexer, ptr %t583, i32 0, i32 2
  %t585 = load i32, ptr %t584
  %t586 = getelementptr inbounds %Token, ptr %t579, i32 0, i32 2
  store i32 %t585, ptr %t586
  %t587 = getelementptr inbounds [1 x i8], ptr @.str.s46, i64 0, i64 0
  %t588 = getelementptr inbounds %Token, ptr %t579, i32 0, i32 3
  store ptr %t587, ptr %t588
  ret ptr %t579
label_479:
  %t589 = load i8, ptr %c
  %t590 = call i1 @is_digit__Char(i8 %t589)
  br i1 %t590, label %label_489, label %label_491
label_489:
  %t591 = load ptr, ptr %lex
  %t592 = getelementptr inbounds %Lexer, ptr %t591, i32 0, i32 1
  %t593 = load i32, ptr %t592
  store i32 %t593, ptr %start
  store i32 0, ptr %is_float
  br label %label_492
label_492:
  %t594 = load ptr, ptr %lex
  %t595 = call i8 @lexer_current__Struct_Lexer(ptr %t594)
  %t596 = call i1 @is_digit__Char(i8 %t595)
  br i1 %t596, label %label_493, label %label_494
label_493:
  %t597 = load ptr, ptr %lex
  call void @lexer_advance__Struct_Lexer(ptr %t597)
  br label %label_492
label_494:
  %t598 = load ptr, ptr %lex
  %t599 = call i8 @lexer_current__Struct_Lexer(ptr %t598)
  %t600 = icmp eq i8 %t599, 46
  %t601 = load ptr, ptr %lex
  %t602 = call i8 @lexer_peek__Struct_Lexer_Int(ptr %t601, i32 1)
  %t603 = call i1 @is_digit__Char(i8 %t602)
  %t604 = and i1 %t600, %t603
  br i1 %t604, label %label_495, label %label_497
label_495:
  store i32 1, ptr %is_float
  %t605 = load ptr, ptr %lex
  call void @lexer_advance__Struct_Lexer(ptr %t605)
  br label %label_498
label_498:
  %t606 = load ptr, ptr %lex
  %t607 = call i8 @lexer_current__Struct_Lexer(ptr %t606)
  %t608 = call i1 @is_digit__Char(i8 %t607)
  br i1 %t608, label %label_499, label %label_500
label_499:
  %t609 = load ptr, ptr %lex
  call void @lexer_advance__Struct_Lexer(ptr %t609)
  br label %label_498
label_500:
  br label %label_497
label_497:
  %t610 = load ptr, ptr %lex
  %t611 = getelementptr inbounds %Lexer, ptr %t610, i32 0, i32 1
  %t612 = load i32, ptr %t611
  %t613 = load i32, ptr %start
  %t614 = sub i32 %t612, %t613
  store i32 %t614, ptr %length
  %t615 = load ptr, ptr %lex
  %t616 = getelementptr inbounds %Lexer, ptr %t615, i32 0, i32 0
  %t617 = load ptr, ptr %t616
  %t618 = load i32, ptr %start
  %t619 = load i32, ptr %length
  %t620 = call ptr @str_substring(ptr %t617, i32 %t618, i32 %t619)
  store ptr %t620, ptr %value
  %t621 = load i32, ptr %is_float
  %t622 = icmp eq i32 %t621, 1
  br i1 %t622, label %label_501, label %label_503
label_501:
  %t623 = getelementptr %Token, ptr null, i32 1
  %t624 = ptrtoint ptr %t623 to i64
  %t625 = call ptr @malloc(i64 %t624)
  %t626 = getelementptr inbounds %Token, ptr %t625, i32 0, i32 0
  store i32 3, ptr %t626
  %t627 = load ptr, ptr %value
  %t628 = getelementptr inbounds %Token, ptr %t625, i32 0, i32 1
  store ptr %t627, ptr %t628
  %t629 = load ptr, ptr %lex
  %t630 = getelementptr inbounds %Lexer, ptr %t629, i32 0, i32 2
  %t631 = load i32, ptr %t630
  %t632 = getelementptr inbounds %Token, ptr %t625, i32 0, i32 2
  store i32 %t631, ptr %t632
  %t633 = getelementptr inbounds [1 x i8], ptr @.str.s47, i64 0, i64 0
  %t634 = getelementptr inbounds %Token, ptr %t625, i32 0, i32 3
  store ptr %t633, ptr %t634
  ret ptr %t625
label_503:
  %t635 = getelementptr %Token, ptr null, i32 1
  %t636 = ptrtoint ptr %t635 to i64
  %t637 = call ptr @malloc(i64 %t636)
  %t638 = getelementptr inbounds %Token, ptr %t637, i32 0, i32 0
  store i32 2, ptr %t638
  %t639 = load ptr, ptr %value
  %t640 = getelementptr inbounds %Token, ptr %t637, i32 0, i32 1
  store ptr %t639, ptr %t640
  %t641 = load ptr, ptr %lex
  %t642 = getelementptr inbounds %Lexer, ptr %t641, i32 0, i32 2
  %t643 = load i32, ptr %t642
  %t644 = getelementptr inbounds %Token, ptr %t637, i32 0, i32 2
  store i32 %t643, ptr %t644
  %t645 = getelementptr inbounds [1 x i8], ptr @.str.s48, i64 0, i64 0
  %t646 = getelementptr inbounds %Token, ptr %t637, i32 0, i32 3
  store ptr %t645, ptr %t646
  ret ptr %t637
label_491:
  %t647 = load i8, ptr %c
  %t648 = icmp eq i8 %t647, 34
  br i1 %t648, label %label_504, label %label_506
label_504:
  %t649 = load ptr, ptr %lex
  call void @lexer_advance__Struct_Lexer(ptr %t649)
  %t650 = load ptr, ptr %lex
  %t651 = getelementptr inbounds %Lexer, ptr %t650, i32 0, i32 1
  %t652 = load i32, ptr %t651
  store i32 %t652, ptr %start
  br label %label_507
label_507:
  %t653 = load ptr, ptr %lex
  %t654 = call i8 @lexer_current__Struct_Lexer(ptr %t653)
  %t655 = icmp ne i8 %t654, 34
  %t656 = load ptr, ptr %lex
  %t657 = getelementptr inbounds %Lexer, ptr %t656, i32 0, i32 1
  %t658 = load i32, ptr %t657
  %t659 = load ptr, ptr %lex
  %t660 = getelementptr inbounds %Lexer, ptr %t659, i32 0, i32 0
  %t661 = load ptr, ptr %t660
  %t662 = call i32 @str_length(ptr %t661)
  %t663 = icmp slt i32 %t658, %t662
  %t664 = and i1 %t655, %t663
  br i1 %t664, label %label_508, label %label_509
label_508:
  %t665 = load ptr, ptr %lex
  call void @lexer_advance__Struct_Lexer(ptr %t665)
  br label %label_507
label_509:
  %t666 = load ptr, ptr %lex
  %t667 = getelementptr inbounds %Lexer, ptr %t666, i32 0, i32 1
  %t668 = load i32, ptr %t667
  %t669 = load i32, ptr %start
  %t670 = sub i32 %t668, %t669
  store i32 %t670, ptr %length
  %t671 = load ptr, ptr %lex
  %t672 = getelementptr inbounds %Lexer, ptr %t671, i32 0, i32 0
  %t673 = load ptr, ptr %t672
  %t674 = load i32, ptr %start
  %t675 = load i32, ptr %length
  %t676 = call ptr @str_substring(ptr %t673, i32 %t674, i32 %t675)
  store ptr %t676, ptr %value
  %t677 = load ptr, ptr %lex
  %t678 = call i8 @lexer_current__Struct_Lexer(ptr %t677)
  %t679 = icmp eq i8 %t678, 34
  br i1 %t679, label %label_510, label %label_512
label_510:
  %t680 = load ptr, ptr %lex
  call void @lexer_advance__Struct_Lexer(ptr %t680)
  br label %label_512
label_512:
  %t681 = getelementptr %Token, ptr null, i32 1
  %t682 = ptrtoint ptr %t681 to i64
  %t683 = call ptr @malloc(i64 %t682)
  %t684 = getelementptr inbounds %Token, ptr %t683, i32 0, i32 0
  store i32 0, ptr %t684
  %t685 = load ptr, ptr %value
  %t686 = getelementptr inbounds %Token, ptr %t683, i32 0, i32 1
  store ptr %t685, ptr %t686
  %t687 = load ptr, ptr %lex
  %t688 = getelementptr inbounds %Lexer, ptr %t687, i32 0, i32 2
  %t689 = load i32, ptr %t688
  %t690 = getelementptr inbounds %Token, ptr %t683, i32 0, i32 2
  store i32 %t689, ptr %t690
  %t691 = getelementptr inbounds [1 x i8], ptr @.str.s49, i64 0, i64 0
  %t692 = getelementptr inbounds %Token, ptr %t683, i32 0, i32 3
  store ptr %t691, ptr %t692
  ret ptr %t683
label_506:
  %t693 = load i8, ptr %c
  %t694 = icmp eq i8 %t693, 39
  br i1 %t694, label %label_513, label %label_515
label_513:
  %t695 = load ptr, ptr %lex
  call void @lexer_advance__Struct_Lexer(ptr %t695)
  %t696 = load ptr, ptr %lex
  %t697 = call i8 @lexer_current__Struct_Lexer(ptr %t696)
  store i8 %t697, ptr %value_char
  %t698 = load i8, ptr %value_char
  %t699 = icmp eq i8 %t698, 92
  br i1 %t699, label %label_516, label %label_518
label_516:
  %t700 = load ptr, ptr %lex
  call void @lexer_advance__Struct_Lexer(ptr %t700)
  %t701 = load ptr, ptr %lex
  %t702 = call i8 @lexer_current__Struct_Lexer(ptr %t701)
  store i8 %t702, ptr %esc
  %t703 = load i8, ptr %esc
  %t704 = icmp eq i8 %t703, 110
  br i1 %t704, label %label_519, label %label_521
label_519:
  store i8 10, ptr %value_char
  br label %label_521
label_521:
  %t705 = load i8, ptr %esc
  %t706 = icmp eq i8 %t705, 116
  br i1 %t706, label %label_522, label %label_524
label_522:
  store i8 9, ptr %value_char
  br label %label_524
label_524:
  %t707 = load i8, ptr %esc
  %t708 = icmp eq i8 %t707, 114
  br i1 %t708, label %label_525, label %label_527
label_525:
  store i8 13, ptr %value_char
  br label %label_527
label_527:
  %t709 = load i8, ptr %esc
  %t710 = icmp eq i8 %t709, 48
  br i1 %t710, label %label_528, label %label_530
label_528:
  store i8 0, ptr %value_char
  br label %label_530
label_530:
  %t711 = load i8, ptr %esc
  %t712 = icmp eq i8 %t711, 92
  br i1 %t712, label %label_531, label %label_533
label_531:
  store i8 92, ptr %value_char
  br label %label_533
label_533:
  %t713 = load i8, ptr %esc
  %t714 = icmp eq i8 %t713, 39
  br i1 %t714, label %label_534, label %label_536
label_534:
  store i8 39, ptr %value_char
  br label %label_536
label_536:
  %t715 = load i8, ptr %esc
  %t716 = icmp eq i8 %t715, 34
  br i1 %t716, label %label_537, label %label_539
label_537:
  store i8 34, ptr %value_char
  br label %label_539
label_539:
  br label %label_518
label_518:
  %t717 = load ptr, ptr %lex
  call void @lexer_advance__Struct_Lexer(ptr %t717)
  %t718 = load ptr, ptr %lex
  %t719 = call i8 @lexer_current__Struct_Lexer(ptr %t718)
  %t720 = icmp eq i8 %t719, 39
  br i1 %t720, label %label_540, label %label_542
label_540:
  %t721 = load ptr, ptr %lex
  call void @lexer_advance__Struct_Lexer(ptr %t721)
  br label %label_542
label_542:
  %t722 = getelementptr %Token, ptr null, i32 1
  %t723 = ptrtoint ptr %t722 to i64
  %t724 = call ptr @malloc(i64 %t723)
  %t725 = getelementptr inbounds %Token, ptr %t724, i32 0, i32 0
  store i32 1, ptr %t725
  %t726 = load i8, ptr %value_char
  %t727 = call i32 @char_code__Char(i8 %t726)
  %t728 = call ptr @int_to_str(i32 %t727)
  %t729 = getelementptr inbounds %Token, ptr %t724, i32 0, i32 1
  store ptr %t728, ptr %t729
  %t730 = load ptr, ptr %lex
  %t731 = getelementptr inbounds %Lexer, ptr %t730, i32 0, i32 2
  %t732 = load i32, ptr %t731
  %t733 = getelementptr inbounds %Token, ptr %t724, i32 0, i32 2
  store i32 %t732, ptr %t733
  %t734 = getelementptr inbounds [1 x i8], ptr @.str.s50, i64 0, i64 0
  %t735 = getelementptr inbounds %Token, ptr %t724, i32 0, i32 3
  store ptr %t734, ptr %t735
  ret ptr %t724
label_515:
  %t736 = load i8, ptr %c
  %t737 = call i1 @is_operator__Char(i8 %t736)
  br i1 %t737, label %label_543, label %label_545
label_543:
  %t738 = load ptr, ptr %lex
  %t739 = getelementptr inbounds %Lexer, ptr %t738, i32 0, i32 1
  %t740 = load i32, ptr %t739
  store i32 %t740, ptr %start
  %t741 = load ptr, ptr %lex
  call void @lexer_advance__Struct_Lexer(ptr %t741)
  %t742 = load ptr, ptr %lex
  %t743 = call i8 @lexer_current__Struct_Lexer(ptr %t742)
  store i8 %t743, ptr %next
  %t744 = load i8, ptr %c
  %t745 = icmp eq i8 %t744, 61
  %t746 = load i8, ptr %next
  %t747 = icmp eq i8 %t746, 61
  %t748 = and i1 %t745, %t747
  br i1 %t748, label %label_546, label %label_548
label_546:
  %t749 = load ptr, ptr %lex
  call void @lexer_advance__Struct_Lexer(ptr %t749)
  br label %label_548
label_548:
  %t750 = load i8, ptr %c
  %t751 = icmp eq i8 %t750, 33
  %t752 = load i8, ptr %next
  %t753 = icmp eq i8 %t752, 61
  %t754 = and i1 %t751, %t753
  br i1 %t754, label %label_549, label %label_551
label_549:
  %t755 = load ptr, ptr %lex
  call void @lexer_advance__Struct_Lexer(ptr %t755)
  br label %label_551
label_551:
  %t756 = load i8, ptr %c
  %t757 = icmp eq i8 %t756, 60
  %t758 = load i8, ptr %next
  %t759 = icmp eq i8 %t758, 61
  %t760 = and i1 %t757, %t759
  br i1 %t760, label %label_552, label %label_554
label_552:
  %t761 = load ptr, ptr %lex
  call void @lexer_advance__Struct_Lexer(ptr %t761)
  br label %label_554
label_554:
  %t762 = load i8, ptr %c
  %t763 = icmp eq i8 %t762, 62
  %t764 = load i8, ptr %next
  %t765 = icmp eq i8 %t764, 61
  %t766 = and i1 %t763, %t765
  br i1 %t766, label %label_555, label %label_557
label_555:
  %t767 = load ptr, ptr %lex
  call void @lexer_advance__Struct_Lexer(ptr %t767)
  br label %label_557
label_557:
  %t768 = load i8, ptr %c
  %t769 = icmp eq i8 %t768, 38
  %t770 = load i8, ptr %next
  %t771 = icmp eq i8 %t770, 38
  %t772 = and i1 %t769, %t771
  br i1 %t772, label %label_558, label %label_560
label_558:
  %t773 = load ptr, ptr %lex
  call void @lexer_advance__Struct_Lexer(ptr %t773)
  br label %label_560
label_560:
  %t774 = load i8, ptr %c
  %t775 = icmp eq i8 %t774, 124
  %t776 = load i8, ptr %next
  %t777 = icmp eq i8 %t776, 124
  %t778 = and i1 %t775, %t777
  br i1 %t778, label %label_561, label %label_563
label_561:
  %t779 = load ptr, ptr %lex
  call void @lexer_advance__Struct_Lexer(ptr %t779)
  br label %label_563
label_563:
  %t780 = load i8, ptr %c
  %t781 = icmp eq i8 %t780, 45
  %t782 = load i8, ptr %next
  %t783 = icmp eq i8 %t782, 62
  %t784 = and i1 %t781, %t783
  br i1 %t784, label %label_564, label %label_566
label_564:
  %t785 = load ptr, ptr %lex
  call void @lexer_advance__Struct_Lexer(ptr %t785)
  br label %label_566
label_566:
  %t786 = load i8, ptr %c
  %t787 = icmp eq i8 %t786, 61
  %t788 = load i8, ptr %next
  %t789 = icmp eq i8 %t788, 62
  %t790 = and i1 %t787, %t789
  br i1 %t790, label %label_567, label %label_569
label_567:
  %t791 = load ptr, ptr %lex
  call void @lexer_advance__Struct_Lexer(ptr %t791)
  br label %label_569
label_569:
  %t792 = load ptr, ptr %lex
  %t793 = getelementptr inbounds %Lexer, ptr %t792, i32 0, i32 1
  %t794 = load i32, ptr %t793
  %t795 = load i32, ptr %start
  %t796 = sub i32 %t794, %t795
  store i32 %t796, ptr %length
  %t797 = load ptr, ptr %lex
  %t798 = getelementptr inbounds %Lexer, ptr %t797, i32 0, i32 0
  %t799 = load ptr, ptr %t798
  %t800 = load i32, ptr %start
  %t801 = load i32, ptr %length
  %t802 = call ptr @str_substring(ptr %t799, i32 %t800, i32 %t801)
  store ptr %t802, ptr %value
  store i32 8, ptr %type
  %t803 = load i32, ptr %length
  %t804 = icmp eq i32 %t803, 2
  br i1 %t804, label %label_570, label %label_571
label_570:
  %t805 = load ptr, ptr %value
  %t806 = getelementptr inbounds [3 x i8], ptr @.str.s51, i64 0, i64 0
  %t807 = call i32 @str_equals(ptr %t805, ptr %t806)
  %t808 = icmp eq i32 %t807, 1
  %t809 = load ptr, ptr %value
  %t810 = getelementptr inbounds [3 x i8], ptr @.str.s52, i64 0, i64 0
  %t811 = call i32 @str_equals(ptr %t809, ptr %t810)
  %t812 = icmp eq i32 %t811, 1
  %t813 = or i1 %t808, %t812
  %t814 = load ptr, ptr %value
  %t815 = getelementptr inbounds [3 x i8], ptr @.str.s53, i64 0, i64 0
  %t816 = call i32 @str_equals(ptr %t814, ptr %t815)
  %t817 = icmp eq i32 %t816, 1
  %t818 = or i1 %t813, %t817
  %t819 = load ptr, ptr %value
  %t820 = getelementptr inbounds [3 x i8], ptr @.str.s54, i64 0, i64 0
  %t821 = call i32 @str_equals(ptr %t819, ptr %t820)
  %t822 = icmp eq i32 %t821, 1
  %t823 = or i1 %t818, %t822
  br i1 %t823, label %label_573, label %label_575
label_573:
  store i32 9, ptr %type
  br label %label_575
label_575:
  %t824 = load ptr, ptr %value
  %t825 = getelementptr inbounds [3 x i8], ptr @.str.s55, i64 0, i64 0
  %t826 = call i32 @str_equals(ptr %t824, ptr %t825)
  %t827 = icmp eq i32 %t826, 1
  %t828 = load ptr, ptr %value
  %t829 = getelementptr inbounds [3 x i8], ptr @.str.s56, i64 0, i64 0
  %t830 = call i32 @str_equals(ptr %t828, ptr %t829)
  %t831 = icmp eq i32 %t830, 1
  %t832 = or i1 %t827, %t831
  br i1 %t832, label %label_576, label %label_578
label_576:
  store i32 15, ptr %type
  %t833 = load ptr, ptr %value
  %t834 = getelementptr inbounds [3 x i8], ptr @.str.s57, i64 0, i64 0
  %t835 = call i32 @str_equals(ptr %t833, ptr %t834)
  %t836 = icmp eq i32 %t835, 1
  br i1 %t836, label %label_579, label %label_581
label_579:
  store i32 16, ptr %type
  br label %label_581
label_581:
  br label %label_578
label_578:
  br label %label_572
label_571:
  %t837 = load i8, ptr %c
  %t838 = icmp eq i8 %t837, 60
  %t839 = load i8, ptr %c
  %t840 = icmp eq i8 %t839, 62
  %t841 = or i1 %t838, %t840
  br i1 %t841, label %label_582, label %label_584
label_582:
  store i32 9, ptr %type
  br label %label_584
label_584:
  %t842 = load i8, ptr %c
  %t843 = icmp eq i8 %t842, 61
  br i1 %t843, label %label_585, label %label_587
label_585:
  store i32 12, ptr %type
  br label %label_587
label_587:
  %t844 = load i8, ptr %c
  %t845 = icmp eq i8 %t844, 33
  br i1 %t845, label %label_588, label %label_590
label_588:
  store i32 10, ptr %type
  br label %label_590
label_590:
  br label %label_572
label_572:
  %t846 = getelementptr %Token, ptr null, i32 1
  %t847 = ptrtoint ptr %t846 to i64
  %t848 = call ptr @malloc(i64 %t847)
  %t849 = load i32, ptr %type
  %t850 = getelementptr inbounds %Token, ptr %t848, i32 0, i32 0
  store i32 %t849, ptr %t850
  %t851 = load ptr, ptr %value
  %t852 = getelementptr inbounds %Token, ptr %t848, i32 0, i32 1
  store ptr %t851, ptr %t852
  %t853 = load ptr, ptr %lex
  %t854 = getelementptr inbounds %Lexer, ptr %t853, i32 0, i32 2
  %t855 = load i32, ptr %t854
  %t856 = getelementptr inbounds %Token, ptr %t848, i32 0, i32 2
  store i32 %t855, ptr %t856
  %t857 = getelementptr inbounds [1 x i8], ptr @.str.s58, i64 0, i64 0
  %t858 = getelementptr inbounds %Token, ptr %t848, i32 0, i32 3
  store ptr %t857, ptr %t858
  ret ptr %t848
label_545:
  %t859 = load i8, ptr %c
  %t860 = icmp eq i8 %t859, 46
  %t861 = load ptr, ptr %lex
  %t862 = call i8 @lexer_peek__Struct_Lexer_Int(ptr %t861, i32 1)
  %t863 = icmp eq i8 %t862, 46
  %t864 = and i1 %t860, %t863
  br i1 %t864, label %label_591, label %label_593
label_591:
  %t865 = load ptr, ptr %lex
  call void @lexer_advance__Struct_Lexer(ptr %t865)
  %t866 = load ptr, ptr %lex
  call void @lexer_advance__Struct_Lexer(ptr %t866)
  %t867 = getelementptr %Token, ptr null, i32 1
  %t868 = ptrtoint ptr %t867 to i64
  %t869 = call ptr @malloc(i64 %t868)
  %t870 = getelementptr inbounds %Token, ptr %t869, i32 0, i32 0
  store i32 17, ptr %t870
  %t871 = getelementptr inbounds [3 x i8], ptr @.str.s59, i64 0, i64 0
  %t872 = getelementptr inbounds %Token, ptr %t869, i32 0, i32 1
  store ptr %t871, ptr %t872
  %t873 = load ptr, ptr %lex
  %t874 = getelementptr inbounds %Lexer, ptr %t873, i32 0, i32 2
  %t875 = load i32, ptr %t874
  %t876 = getelementptr inbounds %Token, ptr %t869, i32 0, i32 2
  store i32 %t875, ptr %t876
  %t877 = getelementptr inbounds [1 x i8], ptr @.str.s60, i64 0, i64 0
  %t878 = getelementptr inbounds %Token, ptr %t869, i32 0, i32 3
  store ptr %t877, ptr %t878
  ret ptr %t869
label_593:
  %t879 = load i8, ptr %c
  %t880 = call i1 @is_separator__Char(i8 %t879)
  br i1 %t880, label %label_594, label %label_596
label_594:
  %t881 = load ptr, ptr %lex
  %t882 = getelementptr inbounds %Lexer, ptr %t881, i32 0, i32 0
  %t883 = load ptr, ptr %t882
  %t884 = load ptr, ptr %lex
  %t885 = getelementptr inbounds %Lexer, ptr %t884, i32 0, i32 1
  %t886 = load i32, ptr %t885
  %t887 = call ptr @str_substring(ptr %t883, i32 %t886, i32 1)
  store ptr %t887, ptr %val
  %t888 = load ptr, ptr %lex
  call void @lexer_advance__Struct_Lexer(ptr %t888)
  %t889 = getelementptr %Token, ptr null, i32 1
  %t890 = ptrtoint ptr %t889 to i64
  %t891 = call ptr @malloc(i64 %t890)
  %t892 = getelementptr inbounds %Token, ptr %t891, i32 0, i32 0
  store i32 6, ptr %t892
  %t893 = load ptr, ptr %val
  %t894 = getelementptr inbounds %Token, ptr %t891, i32 0, i32 1
  store ptr %t893, ptr %t894
  %t895 = load ptr, ptr %lex
  %t896 = getelementptr inbounds %Lexer, ptr %t895, i32 0, i32 2
  %t897 = load i32, ptr %t896
  %t898 = getelementptr inbounds %Token, ptr %t891, i32 0, i32 2
  store i32 %t897, ptr %t898
  %t899 = getelementptr inbounds [1 x i8], ptr @.str.s61, i64 0, i64 0
  %t900 = getelementptr inbounds %Token, ptr %t891, i32 0, i32 3
  store ptr %t899, ptr %t900
  ret ptr %t891
label_596:
  %t901 = load ptr, ptr %lex
  call void @lexer_advance__Struct_Lexer(ptr %t901)
  %t902 = getelementptr %Token, ptr null, i32 1
  %t903 = ptrtoint ptr %t902 to i64
  %t904 = call ptr @malloc(i64 %t903)
  %t905 = getelementptr inbounds %Token, ptr %t904, i32 0, i32 0
  store i32 19, ptr %t905
  %t906 = getelementptr inbounds [2 x i8], ptr @.str.s62, i64 0, i64 0
  %t907 = getelementptr inbounds %Token, ptr %t904, i32 0, i32 1
  store ptr %t906, ptr %t907
  %t908 = load ptr, ptr %lex
  %t909 = getelementptr inbounds %Lexer, ptr %t908, i32 0, i32 2
  %t910 = load i32, ptr %t909
  %t911 = getelementptr inbounds %Token, ptr %t904, i32 0, i32 2
  store i32 %t910, ptr %t911
  %t912 = getelementptr inbounds [1 x i8], ptr @.str.s63, i64 0, i64 0
  %t913 = getelementptr inbounds %Token, ptr %t904, i32 0, i32 3
  store ptr %t912, ptr %t913
  ret ptr %t904
}

define ptr @lex_all_tokens__Struct_Lexer(ptr %p_lex) {
  %lex = alloca ptr
  %head_ptr = alloca ptr
  %current_ptr = alloca ptr
  %scanning = alloca i1
  %current = alloca ptr
  %next_ptr = alloca ptr
  store ptr %p_lex, ptr %lex
  %t920 = load ptr, ptr %lex
  %t921 = call ptr @lexer_next_token__Struct_Lexer(ptr %t920)
  %t922 = call ptr @token_to_ptr(ptr %t921)
  store ptr %t922, ptr %head_ptr
  %t923 = load ptr, ptr %head_ptr
  store ptr %t923, ptr %current_ptr
  store i1 1, ptr %scanning
  br label %label_597
label_597:
  %t924 = load i1, ptr %scanning
  br i1 %t924, label %label_598, label %label_599
label_598:
  %t925 = load ptr, ptr %current_ptr
  %t926 = call ptr @ptr_to_token(ptr %t925)
  store ptr %t926, ptr %current
  %t927 = load ptr, ptr %current
  %t928 = getelementptr inbounds %Token, ptr %t927, i32 0, i32 0
  %t929 = load i32, ptr %t928
  %t930 = icmp eq i32 %t929, 20
  br i1 %t930, label %label_600, label %label_601
label_600:
  store i1 0, ptr %scanning
  br label %label_602
label_601:
  %t931 = load ptr, ptr %lex
  %t932 = call ptr @lexer_next_token__Struct_Lexer(ptr %t931)
  %t933 = call ptr @token_to_ptr(ptr %t932)
  store ptr %t933, ptr %next_ptr
  %t934 = load ptr, ptr %current
  %t935 = load ptr, ptr %next_ptr
  %t936 = getelementptr inbounds %Token, ptr %t934, i32 0, i32 3
  store ptr %t935, ptr %t936
  %t937 = load ptr, ptr %next_ptr
  store ptr %t937, ptr %current_ptr
  br label %label_602
label_602:
  br label %label_597
label_599:
  %t938 = load ptr, ptr %head_ptr
  %t939 = call ptr @ptr_to_token(ptr %t938)
  ret ptr %t939
}

define ptr @create_node__Enum_NodeKind(i32 %p_kind) {
  %kind = alloca i32
  store i32 %p_kind, ptr %kind
  %t941 = getelementptr %ASTNode, ptr null, i32 1
  %t942 = ptrtoint ptr %t941 to i64
  %t943 = call ptr @malloc(i64 %t942)
  %t944 = load i32, ptr %kind
  %t945 = getelementptr inbounds %ASTNode, ptr %t943, i32 0, i32 0
  store i32 %t944, ptr %t945
  %t946 = getelementptr inbounds [1 x i8], ptr @.str.s64, i64 0, i64 0
  %t947 = getelementptr inbounds %ASTNode, ptr %t943, i32 0, i32 1
  store ptr %t946, ptr %t947
  %t948 = getelementptr inbounds [1 x i8], ptr @.str.s65, i64 0, i64 0
  %t949 = getelementptr inbounds %ASTNode, ptr %t943, i32 0, i32 2
  store ptr %t948, ptr %t949
  %t950 = getelementptr inbounds %ASTNode, ptr %t943, i32 0, i32 3
  store i32 0, ptr %t950
  %t951 = getelementptr inbounds %ASTNode, ptr %t943, i32 0, i32 4
  store i32 0, ptr %t951
  %t952 = getelementptr inbounds [1 x i8], ptr @.str.s66, i64 0, i64 0
  %t953 = getelementptr inbounds %ASTNode, ptr %t943, i32 0, i32 5
  store ptr %t952, ptr %t953
  %t954 = getelementptr inbounds [1 x i8], ptr @.str.s67, i64 0, i64 0
  %t955 = getelementptr inbounds %ASTNode, ptr %t943, i32 0, i32 6
  store ptr %t954, ptr %t955
  %t956 = getelementptr inbounds [1 x i8], ptr @.str.s68, i64 0, i64 0
  %t957 = getelementptr inbounds %ASTNode, ptr %t943, i32 0, i32 7
  store ptr %t956, ptr %t957
  %t958 = getelementptr inbounds [1 x i8], ptr @.str.s69, i64 0, i64 0
  %t959 = getelementptr inbounds %ASTNode, ptr %t943, i32 0, i32 8
  store ptr %t958, ptr %t959
  %t960 = getelementptr inbounds [1 x i8], ptr @.str.s70, i64 0, i64 0
  %t961 = getelementptr inbounds %ASTNode, ptr %t943, i32 0, i32 9
  store ptr %t960, ptr %t961
  ret ptr %t943
}

define ptr @parser_create__Struct_Token(ptr %p_tokens) {
  %tokens = alloca ptr
  store ptr %p_tokens, ptr %tokens
  %t963 = getelementptr %Parser, ptr null, i32 1
  %t964 = ptrtoint ptr %t963 to i64
  %t965 = call ptr @malloc(i64 %t964)
  %t966 = load ptr, ptr %tokens
  %t967 = call ptr @token_to_ptr(ptr %t966)
  %t968 = getelementptr inbounds %Parser, ptr %t965, i32 0, i32 0
  store ptr %t967, ptr %t968
  ret ptr %t965
}

define ptr @parser_current__Struct_Parser(ptr %p_p) {
  %p = alloca ptr
  store ptr %p_p, ptr %p
  %t970 = load ptr, ptr %p
  %t971 = getelementptr inbounds %Parser, ptr %t970, i32 0, i32 0
  %t972 = load ptr, ptr %t971
  %t973 = call ptr @ptr_to_token(ptr %t972)
  ret ptr %t973
}

define ptr @parser_peek__Struct_Parser(ptr %p_p) {
  %p = alloca ptr
  %curr = alloca ptr
  store ptr %p_p, ptr %p
  %t976 = load ptr, ptr %p
  %t977 = getelementptr inbounds %Parser, ptr %t976, i32 0, i32 0
  %t978 = load ptr, ptr %t977
  %t979 = call ptr @ptr_to_token(ptr %t978)
  store ptr %t979, ptr %curr
  %t980 = load ptr, ptr %curr
  %t981 = getelementptr inbounds %Token, ptr %t980, i32 0, i32 3
  %t982 = load ptr, ptr %t981
  %t983 = call ptr @ptr_to_token(ptr %t982)
  ret ptr %t983
}

define void @parser_advance__Struct_Parser(ptr %p_p) {
  %p = alloca ptr
  %curr = alloca ptr
  store ptr %p_p, ptr %p
  %t986 = load ptr, ptr %p
  %t987 = getelementptr inbounds %Parser, ptr %t986, i32 0, i32 0
  %t988 = load ptr, ptr %t987
  %t989 = call ptr @ptr_to_token(ptr %t988)
  store ptr %t989, ptr %curr
  %t990 = load ptr, ptr %curr
  %t991 = getelementptr inbounds %Token, ptr %t990, i32 0, i32 0
  %t992 = load i32, ptr %t991
  %t993 = icmp ne i32 %t992, 20
  br i1 %t993, label %label_603, label %label_605
label_603:
  %t994 = load ptr, ptr %p
  %t995 = load ptr, ptr %curr
  %t996 = getelementptr inbounds %Token, ptr %t995, i32 0, i32 3
  %t997 = load ptr, ptr %t996
  %t998 = getelementptr inbounds %Parser, ptr %t994, i32 0, i32 0
  store ptr %t997, ptr %t998
  br label %label_605
label_605:
  ret void
}

define i1 @parser_check__Struct_Parser_Enum_TokenType(ptr %p_p, i32 %p_t) {
  %p = alloca ptr
  %t = alloca i32
  %curr = alloca ptr
  store ptr %p_p, ptr %p
  store i32 %p_t, ptr %t
  %t1002 = load ptr, ptr %p
  %t1003 = call ptr @parser_current__Struct_Parser(ptr %t1002)
  store ptr %t1003, ptr %curr
  %t1004 = load ptr, ptr %curr
  %t1005 = getelementptr inbounds %Token, ptr %t1004, i32 0, i32 0
  %t1006 = load i32, ptr %t1005
  %t1007 = load i32, ptr %t
  %t1008 = icmp eq i32 %t1006, %t1007
  ret i1 %t1008
}

define i1 @parser_check_val__Struct_Parser_Enum_TokenType_String(ptr %p_p, i32 %p_t, ptr %p_val) {
  %p = alloca ptr
  %t = alloca i32
  %val = alloca ptr
  %curr = alloca ptr
  store ptr %p_p, ptr %p
  store i32 %p_t, ptr %t
  store ptr %p_val, ptr %val
  %t1013 = load ptr, ptr %p
  %t1014 = call ptr @parser_current__Struct_Parser(ptr %t1013)
  store ptr %t1014, ptr %curr
  %t1015 = load ptr, ptr %curr
  %t1016 = getelementptr inbounds %Token, ptr %t1015, i32 0, i32 0
  %t1017 = load i32, ptr %t1016
  %t1018 = load i32, ptr %t
  %t1019 = icmp eq i32 %t1017, %t1018
  %t1020 = load ptr, ptr %curr
  %t1021 = getelementptr inbounds %Token, ptr %t1020, i32 0, i32 1
  %t1022 = load ptr, ptr %t1021
  %t1023 = load ptr, ptr %val
  %t1024 = call i32 @str_equals(ptr %t1022, ptr %t1023)
  %t1025 = icmp eq i32 %t1024, 1
  %t1026 = and i1 %t1019, %t1025
  ret i1 %t1026
}

define i1 @parser_match__Struct_Parser_Enum_TokenType(ptr %p_p, i32 %p_t) {
  %p = alloca ptr
  %t = alloca i32
  store ptr %p_p, ptr %p
  store i32 %p_t, ptr %t
  %t1029 = load ptr, ptr %p
  %t1030 = load i32, ptr %t
  %t1031 = call i1 @parser_check__Struct_Parser_Enum_TokenType(ptr %t1029, i32 %t1030)
  br i1 %t1031, label %label_606, label %label_608
label_606:
  %t1032 = load ptr, ptr %p
  call void @parser_advance__Struct_Parser(ptr %t1032)
  ret i1 1
label_608:
  ret i1 0
}

define i1 @parser_match_val__Struct_Parser_Enum_TokenType_String(ptr %p_p, i32 %p_t, ptr %p_val) {
  %p = alloca ptr
  %t = alloca i32
  %val = alloca ptr
  store ptr %p_p, ptr %p
  store i32 %p_t, ptr %t
  store ptr %p_val, ptr %val
  %t1036 = load ptr, ptr %p
  %t1037 = load i32, ptr %t
  %t1038 = load ptr, ptr %val
  %t1039 = call i1 @parser_check_val__Struct_Parser_Enum_TokenType_String(ptr %t1036, i32 %t1037, ptr %t1038)
  br i1 %t1039, label %label_609, label %label_611
label_609:
  %t1040 = load ptr, ptr %p
  call void @parser_advance__Struct_Parser(ptr %t1040)
  ret i1 1
label_611:
  ret i1 0
}

define void @parser_expect__Struct_Parser_Enum_TokenType_String(ptr %p_p, i32 %p_t, ptr %p_context) {
  %p = alloca ptr
  %t = alloca i32
  %context = alloca ptr
  store ptr %p_p, ptr %p
  store i32 %p_t, ptr %t
  store ptr %p_context, ptr %context
  %t1044 = load ptr, ptr %p
  %t1045 = load i32, ptr %t
  %t1046 = call i1 @parser_check__Struct_Parser_Enum_TokenType(ptr %t1044, i32 %t1045)
  %t1047 = icmp eq i1 %t1046, 0
  br i1 %t1047, label %label_612, label %label_614
label_612:
  %t1048 = getelementptr inbounds [10 x i8], ptr @.str.s71, i64 0, i64 0
  call void @print(ptr %t1048)
  %t1049 = load ptr, ptr %context
  call void @print(ptr %t1049)
  %t1050 = getelementptr inbounds [23 x i8], ptr @.str.s72, i64 0, i64 0
  call void @print(ptr %t1050)
  %t1051 = load i32, ptr %t
  call void @println_int(i32 %t1051)
  call void @exit(i32 1)
  br label %label_614
label_614:
  %t1052 = load ptr, ptr %p
  call void @parser_advance__Struct_Parser(ptr %t1052)
  ret void
}

define void @parser_expect_val__Struct_Parser_Enum_TokenType_String_String(ptr %p_p, i32 %p_t, ptr %p_val, ptr %p_context) {
  %p = alloca ptr
  %t = alloca i32
  %val = alloca ptr
  %context = alloca ptr
  store ptr %p_p, ptr %p
  store i32 %p_t, ptr %t
  store ptr %p_val, ptr %val
  store ptr %p_context, ptr %context
  %t1057 = load ptr, ptr %p
  %t1058 = load i32, ptr %t
  %t1059 = load ptr, ptr %val
  %t1060 = call i1 @parser_check_val__Struct_Parser_Enum_TokenType_String(ptr %t1057, i32 %t1058, ptr %t1059)
  %t1061 = icmp eq i1 %t1060, 0
  br i1 %t1061, label %label_615, label %label_617
label_615:
  %t1062 = getelementptr inbounds [10 x i8], ptr @.str.s73, i64 0, i64 0
  call void @print(ptr %t1062)
  %t1063 = load ptr, ptr %context
  call void @print(ptr %t1063)
  %t1064 = getelementptr inbounds [19 x i8], ptr @.str.s74, i64 0, i64 0
  call void @print(ptr %t1064)
  %t1065 = load ptr, ptr %val
  call void @print(ptr %t1065)
  %t1066 = getelementptr inbounds [2 x i8], ptr @.str.s75, i64 0, i64 0
  call void @println(ptr %t1066)
  call void @exit(i32 1)
  br label %label_617
label_617:
  %t1067 = load ptr, ptr %p
  call void @parser_advance__Struct_Parser(ptr %t1067)
  ret void
}

define ptr @parse_import_statement__Struct_Parser(ptr %p_p) {
  %p = alloca ptr
  %import_node = alloca ptr
  %curr = alloca ptr
  store ptr %p_p, ptr %p
  %t1071 = load ptr, ptr %p
  %t1072 = getelementptr inbounds [7 x i8], ptr @.str.s76, i64 0, i64 0
  %t1073 = getelementptr inbounds [17 x i8], ptr @.str.s77, i64 0, i64 0
  call void @parser_expect_val__Struct_Parser_Enum_TokenType_String_String(ptr %t1071, i32 18, ptr %t1072, ptr %t1073)
  %t1074 = call ptr @create_node__Enum_NodeKind(i32 1)
  store ptr %t1074, ptr %import_node
  %t1075 = load ptr, ptr %p
  %t1076 = call ptr @parser_current__Struct_Parser(ptr %t1075)
  store ptr %t1076, ptr %curr
  %t1077 = load ptr, ptr %import_node
  %t1078 = load ptr, ptr %curr
  %t1079 = getelementptr inbounds %Token, ptr %t1078, i32 0, i32 1
  %t1080 = load ptr, ptr %t1079
  %t1081 = getelementptr inbounds %ASTNode, ptr %t1077, i32 0, i32 1
  store ptr %t1080, ptr %t1081
  %t1082 = load ptr, ptr %curr
  %t1083 = getelementptr inbounds %Token, ptr %t1082, i32 0, i32 0
  %t1084 = load i32, ptr %t1083
  %t1085 = icmp eq i32 %t1084, 5
  %t1086 = load ptr, ptr %curr
  %t1087 = getelementptr inbounds %Token, ptr %t1086, i32 0, i32 0
  %t1088 = load i32, ptr %t1087
  %t1089 = icmp eq i32 %t1088, 18
  %t1090 = or i1 %t1085, %t1089
  br i1 %t1090, label %label_618, label %label_619
label_618:
  %t1091 = load ptr, ptr %p
  call void @parser_advance__Struct_Parser(ptr %t1091)
  br label %label_620
label_619:
  %t1092 = getelementptr inbounds [21 x i8], ptr @.str.s78, i64 0, i64 0
  call void @println(ptr %t1092)
  call void @exit(i32 1)
  br label %label_620
label_620:
  %t1093 = load ptr, ptr %import_node
  ret ptr %t1093
}

define ptr @parse_declaration__Struct_Parser(ptr %p_p) {
  %p = alloca ptr
  store ptr %p_p, ptr %p
  %t1095 = load ptr, ptr %p
  %t1096 = getelementptr inbounds [7 x i8], ptr @.str.s79, i64 0, i64 0
  %t1097 = call i1 @parser_check_val__Struct_Parser_Enum_TokenType_String(ptr %t1095, i32 18, ptr %t1096)
  br i1 %t1097, label %label_621, label %label_623
label_621:
  %t1098 = load ptr, ptr %p
  %t1099 = call ptr @parse_import_statement__Struct_Parser(ptr %t1098)
  ret ptr %t1099
label_623:
  %t1100 = load ptr, ptr %p
  %t1101 = getelementptr inbounds [4 x i8], ptr @.str.s80, i64 0, i64 0
  %t1102 = call i1 @parser_check_val__Struct_Parser_Enum_TokenType_String(ptr %t1100, i32 18, ptr %t1101)
  br i1 %t1102, label %label_624, label %label_626
label_624:
  %t1103 = load ptr, ptr %p
  %t1104 = call ptr @parse_variable_decl__Struct_Parser(ptr %t1103)
  ret ptr %t1104
label_626:
  %t1105 = load ptr, ptr %p
  %t1106 = getelementptr inbounds [7 x i8], ptr @.str.s81, i64 0, i64 0
  %t1107 = call i1 @parser_check_val__Struct_Parser_Enum_TokenType_String(ptr %t1105, i32 18, ptr %t1106)
  br i1 %t1107, label %label_627, label %label_629
label_627:
  %t1108 = load ptr, ptr %p
  %t1109 = call ptr @parse_extern_fn_decl__Struct_Parser(ptr %t1108)
  ret ptr %t1109
label_629:
  %t1110 = load ptr, ptr %p
  %t1111 = getelementptr inbounds [3 x i8], ptr @.str.s82, i64 0, i64 0
  %t1112 = call i1 @parser_check_val__Struct_Parser_Enum_TokenType_String(ptr %t1110, i32 18, ptr %t1111)
  br i1 %t1112, label %label_630, label %label_632
label_630:
  %t1113 = load ptr, ptr %p
  %t1114 = call ptr @parse_function_decl__Struct_Parser(ptr %t1113)
  ret ptr %t1114
label_632:
  %t1115 = load ptr, ptr %p
  %t1116 = getelementptr inbounds [7 x i8], ptr @.str.s83, i64 0, i64 0
  %t1117 = call i1 @parser_check_val__Struct_Parser_Enum_TokenType_String(ptr %t1115, i32 18, ptr %t1116)
  br i1 %t1117, label %label_633, label %label_635
label_633:
  %t1118 = load ptr, ptr %p
  %t1119 = call ptr @parse_struct_decl__Struct_Parser(ptr %t1118)
  ret ptr %t1119
label_635:
  %t1120 = load ptr, ptr %p
  %t1121 = getelementptr inbounds [5 x i8], ptr @.str.s84, i64 0, i64 0
  %t1122 = call i1 @parser_check_val__Struct_Parser_Enum_TokenType_String(ptr %t1120, i32 18, ptr %t1121)
  br i1 %t1122, label %label_636, label %label_638
label_636:
  %t1123 = load ptr, ptr %p
  %t1124 = call ptr @parse_enum_decl__Struct_Parser(ptr %t1123)
  ret ptr %t1124
label_638:
  %t1125 = getelementptr inbounds [20 x i8], ptr @.str.s85, i64 0, i64 0
  call void @println(ptr %t1125)
  call void @exit(i32 1)
  %t1126 = call ptr @create_node__Enum_NodeKind(i32 0)
  ret ptr %t1126
}

define ptr @parse_type_annotation__Struct_Parser(ptr %p_p) {
  %p = alloca ptr
  %type_node = alloca ptr
  %curr = alloca ptr
  store ptr %p_p, ptr %p
  %t1130 = call ptr @create_node__Enum_NodeKind(i32 30)
  store ptr %t1130, ptr %type_node
  %t1131 = load ptr, ptr %p
  %t1132 = getelementptr inbounds [2 x i8], ptr @.str.s86, i64 0, i64 0
  %t1133 = call i1 @parser_match_val__Struct_Parser_Enum_TokenType_String(ptr %t1131, i32 6, ptr %t1132)
  br i1 %t1133, label %label_639, label %label_641
label_639:
  %t1134 = load ptr, ptr %type_node
  %t1135 = getelementptr inbounds %ASTNode, ptr %t1134, i32 0, i32 3
  store i32 1, ptr %t1135
  %t1136 = load ptr, ptr %type_node
  %t1137 = load ptr, ptr %p
  %t1138 = call ptr @parse_type_annotation__Struct_Parser(ptr %t1137)
  %t1139 = call ptr @node_to_ptr(ptr %t1138)
  %t1140 = getelementptr inbounds %ASTNode, ptr %t1136, i32 0, i32 5
  store ptr %t1139, ptr %t1140
  %t1141 = load ptr, ptr %p
  %t1142 = getelementptr inbounds [2 x i8], ptr @.str.s87, i64 0, i64 0
  %t1143 = getelementptr inbounds [11 x i8], ptr @.str.s88, i64 0, i64 0
  call void @parser_expect_val__Struct_Parser_Enum_TokenType_String_String(ptr %t1141, i32 6, ptr %t1142, ptr %t1143)
  %t1144 = load ptr, ptr %type_node
  ret ptr %t1144
label_641:
  %t1145 = load ptr, ptr %p
  %t1146 = call ptr @parser_current__Struct_Parser(ptr %t1145)
  store ptr %t1146, ptr %curr
  %t1147 = load ptr, ptr %curr
  %t1148 = getelementptr inbounds %Token, ptr %t1147, i32 0, i32 0
  %t1149 = load i32, ptr %t1148
  %t1150 = icmp eq i32 %t1149, 5
  %t1151 = load ptr, ptr %curr
  %t1152 = getelementptr inbounds %Token, ptr %t1151, i32 0, i32 0
  %t1153 = load i32, ptr %t1152
  %t1154 = icmp eq i32 %t1153, 18
  %t1155 = or i1 %t1150, %t1154
  br i1 %t1155, label %label_642, label %label_643
label_642:
  %t1156 = load ptr, ptr %type_node
  %t1157 = load ptr, ptr %curr
  %t1158 = getelementptr inbounds %Token, ptr %t1157, i32 0, i32 1
  %t1159 = load ptr, ptr %t1158
  %t1160 = getelementptr inbounds %ASTNode, ptr %t1156, i32 0, i32 1
  store ptr %t1159, ptr %t1160
  %t1161 = load ptr, ptr %p
  call void @parser_advance__Struct_Parser(ptr %t1161)
  br label %label_644
label_643:
  %t1162 = getelementptr inbounds [19 x i8], ptr @.str.s89, i64 0, i64 0
  call void @println(ptr %t1162)
  call void @exit(i32 1)
  br label %label_644
label_644:
  %t1163 = load ptr, ptr %type_node
  %t1164 = getelementptr inbounds %ASTNode, ptr %t1163, i32 0, i32 1
  %t1165 = load ptr, ptr %t1164
  %t1166 = getelementptr inbounds [5 x i8], ptr @.str.s90, i64 0, i64 0
  %t1167 = call i32 @str_equals(ptr %t1165, ptr %t1166)
  %t1168 = icmp eq i32 %t1167, 1
  %t1169 = load ptr, ptr %p
  %t1170 = getelementptr inbounds [2 x i8], ptr @.str.s91, i64 0, i64 0
  %t1171 = call i1 @parser_match_val__Struct_Parser_Enum_TokenType_String(ptr %t1169, i32 9, ptr %t1170)
  %t1172 = and i1 %t1168, %t1171
  br i1 %t1172, label %label_645, label %label_647
label_645:
  %t1173 = load ptr, ptr %type_node
  %t1174 = getelementptr inbounds %ASTNode, ptr %t1173, i32 0, i32 4
  store i32 1, ptr %t1174
  %t1175 = load ptr, ptr %type_node
  %t1176 = load ptr, ptr %p
  %t1177 = call ptr @parse_type_annotation__Struct_Parser(ptr %t1176)
  %t1178 = call ptr @node_to_ptr(ptr %t1177)
  %t1179 = getelementptr inbounds %ASTNode, ptr %t1175, i32 0, i32 5
  store ptr %t1178, ptr %t1179
  %t1180 = load ptr, ptr %p
  %t1181 = getelementptr inbounds [2 x i8], ptr @.str.s92, i64 0, i64 0
  %t1182 = getelementptr inbounds [19 x i8], ptr @.str.s93, i64 0, i64 0
  call void @parser_expect_val__Struct_Parser_Enum_TokenType_String_String(ptr %t1180, i32 9, ptr %t1181, ptr %t1182)
  br label %label_647
label_647:
  %t1183 = load ptr, ptr %type_node
  ret ptr %t1183
}

define ptr @parse_variable_decl__Struct_Parser(ptr %p_p) {
  %p = alloca ptr
  %var_node = alloca ptr
  %curr = alloca ptr
  store ptr %p_p, ptr %p
  %t1187 = load ptr, ptr %p
  %t1188 = getelementptr inbounds [4 x i8], ptr @.str.s94, i64 0, i64 0
  %t1189 = getelementptr inbounds [21 x i8], ptr @.str.s95, i64 0, i64 0
  call void @parser_expect_val__Struct_Parser_Enum_TokenType_String_String(ptr %t1187, i32 18, ptr %t1188, ptr %t1189)
  %t1190 = call ptr @create_node__Enum_NodeKind(i32 3)
  store ptr %t1190, ptr %var_node
  %t1191 = load ptr, ptr %p
  %t1192 = getelementptr inbounds [4 x i8], ptr @.str.s96, i64 0, i64 0
  %t1193 = call i1 @parser_match_val__Struct_Parser_Enum_TokenType_String(ptr %t1191, i32 18, ptr %t1192)
  br i1 %t1193, label %label_648, label %label_650
label_648:
  %t1194 = load ptr, ptr %var_node
  %t1195 = getelementptr inbounds %ASTNode, ptr %t1194, i32 0, i32 3
  store i32 1, ptr %t1195
  br label %label_650
label_650:
  %t1196 = load ptr, ptr %p
  %t1197 = call ptr @parser_current__Struct_Parser(ptr %t1196)
  store ptr %t1197, ptr %curr
  %t1198 = load ptr, ptr %var_node
  %t1199 = load ptr, ptr %curr
  %t1200 = getelementptr inbounds %Token, ptr %t1199, i32 0, i32 1
  %t1201 = load ptr, ptr %t1200
  %t1202 = getelementptr inbounds %ASTNode, ptr %t1198, i32 0, i32 1
  store ptr %t1201, ptr %t1202
  %t1203 = load ptr, ptr %p
  %t1204 = getelementptr inbounds [14 x i8], ptr @.str.s97, i64 0, i64 0
  call void @parser_expect__Struct_Parser_Enum_TokenType_String(ptr %t1203, i32 5, ptr %t1204)
  %t1205 = load ptr, ptr %p
  %t1206 = getelementptr inbounds [2 x i8], ptr @.str.s98, i64 0, i64 0
  %t1207 = call i1 @parser_match_val__Struct_Parser_Enum_TokenType_String(ptr %t1205, i32 6, ptr %t1206)
  br i1 %t1207, label %label_651, label %label_653
label_651:
  %t1208 = load ptr, ptr %var_node
  %t1209 = load ptr, ptr %p
  %t1210 = call ptr @parse_type_annotation__Struct_Parser(ptr %t1209)
  %t1211 = call ptr @node_to_ptr(ptr %t1210)
  %t1212 = getelementptr inbounds %ASTNode, ptr %t1208, i32 0, i32 5
  store ptr %t1211, ptr %t1212
  br label %label_653
label_653:
  %t1213 = load ptr, ptr %p
  %t1214 = getelementptr inbounds [2 x i8], ptr @.str.s99, i64 0, i64 0
  %t1215 = call i1 @parser_match_val__Struct_Parser_Enum_TokenType_String(ptr %t1213, i32 12, ptr %t1214)
  br i1 %t1215, label %label_654, label %label_656
label_654:
  %t1216 = load ptr, ptr %var_node
  %t1217 = load ptr, ptr %p
  %t1218 = call ptr @parse_expression__Struct_Parser_Int(ptr %t1217, i32 0)
  %t1219 = call ptr @node_to_ptr(ptr %t1218)
  %t1220 = getelementptr inbounds %ASTNode, ptr %t1216, i32 0, i32 6
  store ptr %t1219, ptr %t1220
  br label %label_656
label_656:
  %t1221 = load ptr, ptr %var_node
  ret ptr %t1221
}

define ptr @parse_extern_fn_decl__Struct_Parser(ptr %p_p) {
  %p = alloca ptr
  %ext_node = alloca ptr
  %curr = alloca ptr
  %last_param = alloca ptr
  %is_looping = alloca i1
  %param = alloca ptr
  %last = alloca ptr
  store ptr %p_p, ptr %p
  %t1229 = load ptr, ptr %p
  %t1230 = getelementptr inbounds [7 x i8], ptr @.str.s100, i64 0, i64 0
  %t1231 = getelementptr inbounds [10 x i8], ptr @.str.s101, i64 0, i64 0
  call void @parser_expect_val__Struct_Parser_Enum_TokenType_String_String(ptr %t1229, i32 18, ptr %t1230, ptr %t1231)
  %t1232 = load ptr, ptr %p
  %t1233 = getelementptr inbounds [3 x i8], ptr @.str.s102, i64 0, i64 0
  %t1234 = getelementptr inbounds [10 x i8], ptr @.str.s103, i64 0, i64 0
  call void @parser_expect_val__Struct_Parser_Enum_TokenType_String_String(ptr %t1232, i32 18, ptr %t1233, ptr %t1234)
  %t1235 = call ptr @create_node__Enum_NodeKind(i32 2)
  store ptr %t1235, ptr %ext_node
  %t1236 = load ptr, ptr %p
  %t1237 = call ptr @parser_current__Struct_Parser(ptr %t1236)
  store ptr %t1237, ptr %curr
  %t1238 = load ptr, ptr %ext_node
  %t1239 = load ptr, ptr %curr
  %t1240 = getelementptr inbounds %Token, ptr %t1239, i32 0, i32 1
  %t1241 = load ptr, ptr %t1240
  %t1242 = getelementptr inbounds %ASTNode, ptr %t1238, i32 0, i32 1
  store ptr %t1241, ptr %t1242
  %t1243 = load ptr, ptr %p
  %t1244 = getelementptr inbounds [14 x i8], ptr @.str.s104, i64 0, i64 0
  call void @parser_expect__Struct_Parser_Enum_TokenType_String(ptr %t1243, i32 5, ptr %t1244)
  %t1245 = load ptr, ptr %p
  %t1246 = getelementptr inbounds [2 x i8], ptr @.str.s105, i64 0, i64 0
  %t1247 = getelementptr inbounds [7 x i8], ptr @.str.s106, i64 0, i64 0
  call void @parser_expect_val__Struct_Parser_Enum_TokenType_String_String(ptr %t1245, i32 6, ptr %t1246, ptr %t1247)
  %t1248 = getelementptr inbounds [1 x i8], ptr @.str.s107, i64 0, i64 0
  store ptr %t1248, ptr %last_param
  %t1249 = load ptr, ptr %p
  %t1250 = getelementptr inbounds [2 x i8], ptr @.str.s108, i64 0, i64 0
  %t1251 = call i1 @parser_check_val__Struct_Parser_Enum_TokenType_String(ptr %t1249, i32 6, ptr %t1250)
  %t1252 = icmp eq i1 %t1251, 0
  br i1 %t1252, label %label_657, label %label_659
label_657:
  store i1 1, ptr %is_looping
  br label %label_660
label_660:
  %t1253 = load i1, ptr %is_looping
  br i1 %t1253, label %label_661, label %label_662
label_661:
  %t1254 = call ptr @create_node__Enum_NodeKind(i32 29)
  store ptr %t1254, ptr %param
  %t1255 = load ptr, ptr %p
  %t1256 = call ptr @parser_current__Struct_Parser(ptr %t1255)
  store ptr %t1256, ptr %curr
  %t1257 = load ptr, ptr %param
  %t1258 = load ptr, ptr %curr
  %t1259 = getelementptr inbounds %Token, ptr %t1258, i32 0, i32 1
  %t1260 = load ptr, ptr %t1259
  %t1261 = getelementptr inbounds %ASTNode, ptr %t1257, i32 0, i32 1
  store ptr %t1260, ptr %t1261
  %t1262 = load ptr, ptr %p
  %t1263 = getelementptr inbounds [15 x i8], ptr @.str.s109, i64 0, i64 0
  call void @parser_expect__Struct_Parser_Enum_TokenType_String(ptr %t1262, i32 5, ptr %t1263)
  %t1264 = load ptr, ptr %p
  %t1265 = getelementptr inbounds [2 x i8], ptr @.str.s110, i64 0, i64 0
  %t1266 = getelementptr inbounds [15 x i8], ptr @.str.s111, i64 0, i64 0
  call void @parser_expect_val__Struct_Parser_Enum_TokenType_String_String(ptr %t1264, i32 6, ptr %t1265, ptr %t1266)
  %t1267 = load ptr, ptr %param
  %t1268 = load ptr, ptr %p
  %t1269 = call ptr @parse_type_annotation__Struct_Parser(ptr %t1268)
  %t1270 = call ptr @node_to_ptr(ptr %t1269)
  %t1271 = getelementptr inbounds %ASTNode, ptr %t1267, i32 0, i32 5
  store ptr %t1270, ptr %t1271
  %t1272 = load ptr, ptr %ext_node
  %t1273 = getelementptr inbounds %ASTNode, ptr %t1272, i32 0, i32 5
  %t1274 = load ptr, ptr %t1273
  %t1275 = getelementptr inbounds [1 x i8], ptr @.str.s112, i64 0, i64 0
  %t1276 = call i32 @str_equals(ptr %t1274, ptr %t1275)
  %t1277 = icmp eq i32 %t1276, 1
  br i1 %t1277, label %label_663, label %label_664
label_663:
  %t1278 = load ptr, ptr %ext_node
  %t1279 = load ptr, ptr %param
  %t1280 = call ptr @node_to_ptr(ptr %t1279)
  %t1281 = getelementptr inbounds %ASTNode, ptr %t1278, i32 0, i32 5
  store ptr %t1280, ptr %t1281
  br label %label_665
label_664:
  %t1282 = load ptr, ptr %last_param
  %t1283 = call ptr @ptr_to_node(ptr %t1282)
  store ptr %t1283, ptr %last
  %t1284 = load ptr, ptr %last
  %t1285 = load ptr, ptr %param
  %t1286 = call ptr @node_to_ptr(ptr %t1285)
  %t1287 = getelementptr inbounds %ASTNode, ptr %t1284, i32 0, i32 8
  store ptr %t1286, ptr %t1287
  br label %label_665
label_665:
  %t1288 = load ptr, ptr %param
  %t1289 = call ptr @node_to_ptr(ptr %t1288)
  store ptr %t1289, ptr %last_param
  %t1290 = load ptr, ptr %p
  %t1291 = getelementptr inbounds [2 x i8], ptr @.str.s113, i64 0, i64 0
  %t1292 = call i1 @parser_match_val__Struct_Parser_Enum_TokenType_String(ptr %t1290, i32 6, ptr %t1291)
  %t1293 = icmp eq i1 %t1292, 0
  br i1 %t1293, label %label_666, label %label_668
label_666:
  store i1 0, ptr %is_looping
  br label %label_668
label_668:
  br label %label_660
label_662:
  br label %label_659
label_659:
  %t1294 = load ptr, ptr %p
  %t1295 = getelementptr inbounds [2 x i8], ptr @.str.s114, i64 0, i64 0
  %t1296 = getelementptr inbounds [7 x i8], ptr @.str.s115, i64 0, i64 0
  call void @parser_expect_val__Struct_Parser_Enum_TokenType_String_String(ptr %t1294, i32 6, ptr %t1295, ptr %t1296)
  %t1297 = load ptr, ptr %p
  %t1298 = getelementptr inbounds [3 x i8], ptr @.str.s116, i64 0, i64 0
  %t1299 = call i1 @parser_match_val__Struct_Parser_Enum_TokenType_String(ptr %t1297, i32 15, ptr %t1298)
  br i1 %t1299, label %label_669, label %label_671
label_669:
  %t1300 = load ptr, ptr %ext_node
  %t1301 = load ptr, ptr %p
  %t1302 = call ptr @parse_type_annotation__Struct_Parser(ptr %t1301)
  %t1303 = call ptr @node_to_ptr(ptr %t1302)
  %t1304 = getelementptr inbounds %ASTNode, ptr %t1300, i32 0, i32 6
  store ptr %t1303, ptr %t1304
  br label %label_671
label_671:
  %t1305 = load ptr, ptr %ext_node
  ret ptr %t1305
}

define ptr @parse_function_decl__Struct_Parser(ptr %p_p) {
  %p = alloca ptr
  %fn_node = alloca ptr
  %curr = alloca ptr
  %last_param = alloca ptr
  %is_looping = alloca i1
  %param = alloca ptr
  %last = alloca ptr
  store ptr %p_p, ptr %p
  %t1313 = load ptr, ptr %p
  %t1314 = getelementptr inbounds [3 x i8], ptr @.str.s117, i64 0, i64 0
  %t1315 = getelementptr inbounds [9 x i8], ptr @.str.s118, i64 0, i64 0
  call void @parser_expect_val__Struct_Parser_Enum_TokenType_String_String(ptr %t1313, i32 18, ptr %t1314, ptr %t1315)
  %t1316 = call ptr @create_node__Enum_NodeKind(i32 4)
  store ptr %t1316, ptr %fn_node
  %t1317 = load ptr, ptr %p
  %t1318 = call ptr @parser_current__Struct_Parser(ptr %t1317)
  store ptr %t1318, ptr %curr
  %t1319 = load ptr, ptr %fn_node
  %t1320 = load ptr, ptr %curr
  %t1321 = getelementptr inbounds %Token, ptr %t1320, i32 0, i32 1
  %t1322 = load ptr, ptr %t1321
  %t1323 = getelementptr inbounds %ASTNode, ptr %t1319, i32 0, i32 1
  store ptr %t1322, ptr %t1323
  %t1324 = load ptr, ptr %p
  %t1325 = getelementptr inbounds [14 x i8], ptr @.str.s119, i64 0, i64 0
  call void @parser_expect__Struct_Parser_Enum_TokenType_String(ptr %t1324, i32 5, ptr %t1325)
  %t1326 = load ptr, ptr %p
  %t1327 = getelementptr inbounds [2 x i8], ptr @.str.s120, i64 0, i64 0
  %t1328 = getelementptr inbounds [7 x i8], ptr @.str.s121, i64 0, i64 0
  call void @parser_expect_val__Struct_Parser_Enum_TokenType_String_String(ptr %t1326, i32 6, ptr %t1327, ptr %t1328)
  %t1329 = getelementptr inbounds [1 x i8], ptr @.str.s122, i64 0, i64 0
  store ptr %t1329, ptr %last_param
  %t1330 = load ptr, ptr %p
  %t1331 = getelementptr inbounds [2 x i8], ptr @.str.s123, i64 0, i64 0
  %t1332 = call i1 @parser_check_val__Struct_Parser_Enum_TokenType_String(ptr %t1330, i32 6, ptr %t1331)
  %t1333 = icmp eq i1 %t1332, 0
  br i1 %t1333, label %label_672, label %label_674
label_672:
  store i1 1, ptr %is_looping
  br label %label_675
label_675:
  %t1334 = load i1, ptr %is_looping
  br i1 %t1334, label %label_676, label %label_677
label_676:
  %t1335 = call ptr @create_node__Enum_NodeKind(i32 29)
  store ptr %t1335, ptr %param
  %t1336 = load ptr, ptr %p
  %t1337 = getelementptr inbounds [5 x i8], ptr @.str.s124, i64 0, i64 0
  %t1338 = call i1 @parser_match_val__Struct_Parser_Enum_TokenType_String(ptr %t1336, i32 18, ptr %t1337)
  br i1 %t1338, label %label_678, label %label_679
label_678:
  %t1339 = load ptr, ptr %param
  %t1340 = getelementptr inbounds [5 x i8], ptr @.str.s125, i64 0, i64 0
  %t1341 = getelementptr inbounds %ASTNode, ptr %t1339, i32 0, i32 2
  store ptr %t1340, ptr %t1341
  br label %label_680
label_679:
  %t1342 = load ptr, ptr %p
  %t1343 = getelementptr inbounds [6 x i8], ptr @.str.s126, i64 0, i64 0
  %t1344 = call i1 @parser_match_val__Struct_Parser_Enum_TokenType_String(ptr %t1342, i32 18, ptr %t1343)
  br i1 %t1344, label %label_681, label %label_683
label_681:
  %t1345 = load ptr, ptr %param
  %t1346 = getelementptr inbounds [6 x i8], ptr @.str.s127, i64 0, i64 0
  %t1347 = getelementptr inbounds %ASTNode, ptr %t1345, i32 0, i32 2
  store ptr %t1346, ptr %t1347
  br label %label_683
label_683:
  br label %label_680
label_680:
  %t1348 = load ptr, ptr %p
  %t1349 = call ptr @parser_current__Struct_Parser(ptr %t1348)
  store ptr %t1349, ptr %curr
  %t1350 = load ptr, ptr %param
  %t1351 = load ptr, ptr %curr
  %t1352 = getelementptr inbounds %Token, ptr %t1351, i32 0, i32 1
  %t1353 = load ptr, ptr %t1352
  %t1354 = getelementptr inbounds %ASTNode, ptr %t1350, i32 0, i32 1
  store ptr %t1353, ptr %t1354
  %t1355 = load ptr, ptr %p
  %t1356 = getelementptr inbounds [15 x i8], ptr @.str.s128, i64 0, i64 0
  call void @parser_expect__Struct_Parser_Enum_TokenType_String(ptr %t1355, i32 5, ptr %t1356)
  %t1357 = load ptr, ptr %p
  %t1358 = getelementptr inbounds [2 x i8], ptr @.str.s129, i64 0, i64 0
  %t1359 = getelementptr inbounds [15 x i8], ptr @.str.s130, i64 0, i64 0
  call void @parser_expect_val__Struct_Parser_Enum_TokenType_String_String(ptr %t1357, i32 6, ptr %t1358, ptr %t1359)
  %t1360 = load ptr, ptr %param
  %t1361 = load ptr, ptr %p
  %t1362 = call ptr @parse_type_annotation__Struct_Parser(ptr %t1361)
  %t1363 = call ptr @node_to_ptr(ptr %t1362)
  %t1364 = getelementptr inbounds %ASTNode, ptr %t1360, i32 0, i32 5
  store ptr %t1363, ptr %t1364
  %t1365 = load ptr, ptr %fn_node
  %t1366 = getelementptr inbounds %ASTNode, ptr %t1365, i32 0, i32 5
  %t1367 = load ptr, ptr %t1366
  %t1368 = getelementptr inbounds [1 x i8], ptr @.str.s131, i64 0, i64 0
  %t1369 = call i32 @str_equals(ptr %t1367, ptr %t1368)
  %t1370 = icmp eq i32 %t1369, 1
  br i1 %t1370, label %label_684, label %label_685
label_684:
  %t1371 = load ptr, ptr %fn_node
  %t1372 = load ptr, ptr %param
  %t1373 = call ptr @node_to_ptr(ptr %t1372)
  %t1374 = getelementptr inbounds %ASTNode, ptr %t1371, i32 0, i32 5
  store ptr %t1373, ptr %t1374
  br label %label_686
label_685:
  %t1375 = load ptr, ptr %last_param
  %t1376 = call ptr @ptr_to_node(ptr %t1375)
  store ptr %t1376, ptr %last
  %t1377 = load ptr, ptr %last
  %t1378 = load ptr, ptr %param
  %t1379 = call ptr @node_to_ptr(ptr %t1378)
  %t1380 = getelementptr inbounds %ASTNode, ptr %t1377, i32 0, i32 8
  store ptr %t1379, ptr %t1380
  br label %label_686
label_686:
  %t1381 = load ptr, ptr %param
  %t1382 = call ptr @node_to_ptr(ptr %t1381)
  store ptr %t1382, ptr %last_param
  %t1383 = load ptr, ptr %p
  %t1384 = getelementptr inbounds [2 x i8], ptr @.str.s132, i64 0, i64 0
  %t1385 = call i1 @parser_match_val__Struct_Parser_Enum_TokenType_String(ptr %t1383, i32 6, ptr %t1384)
  %t1386 = icmp eq i1 %t1385, 0
  br i1 %t1386, label %label_687, label %label_689
label_687:
  store i1 0, ptr %is_looping
  br label %label_689
label_689:
  br label %label_675
label_677:
  br label %label_674
label_674:
  %t1387 = load ptr, ptr %p
  %t1388 = getelementptr inbounds [2 x i8], ptr @.str.s133, i64 0, i64 0
  %t1389 = getelementptr inbounds [7 x i8], ptr @.str.s134, i64 0, i64 0
  call void @parser_expect_val__Struct_Parser_Enum_TokenType_String_String(ptr %t1387, i32 6, ptr %t1388, ptr %t1389)
  %t1390 = load ptr, ptr %p
  %t1391 = getelementptr inbounds [3 x i8], ptr @.str.s135, i64 0, i64 0
  %t1392 = call i1 @parser_match_val__Struct_Parser_Enum_TokenType_String(ptr %t1390, i32 15, ptr %t1391)
  br i1 %t1392, label %label_690, label %label_692
label_690:
  %t1393 = load ptr, ptr %fn_node
  %t1394 = load ptr, ptr %p
  %t1395 = call ptr @parse_type_annotation__Struct_Parser(ptr %t1394)
  %t1396 = call ptr @node_to_ptr(ptr %t1395)
  %t1397 = getelementptr inbounds %ASTNode, ptr %t1393, i32 0, i32 7
  store ptr %t1396, ptr %t1397
  br label %label_692
label_692:
  %t1398 = load ptr, ptr %fn_node
  %t1399 = load ptr, ptr %p
  %t1400 = call ptr @parse_block__Struct_Parser(ptr %t1399)
  %t1401 = call ptr @node_to_ptr(ptr %t1400)
  %t1402 = getelementptr inbounds %ASTNode, ptr %t1398, i32 0, i32 6
  store ptr %t1401, ptr %t1402
  %t1403 = load ptr, ptr %fn_node
  ret ptr %t1403
}

define ptr @parse_struct_decl__Struct_Parser(ptr %p_p) {
  %p = alloca ptr
  %struct_node = alloca ptr
  %curr = alloca ptr
  %last_field = alloca ptr
  %field = alloca ptr
  %last = alloca ptr
  store ptr %p_p, ptr %p
  %t1410 = load ptr, ptr %p
  %t1411 = getelementptr inbounds [7 x i8], ptr @.str.s136, i64 0, i64 0
  %t1412 = getelementptr inbounds [7 x i8], ptr @.str.s137, i64 0, i64 0
  call void @parser_expect_val__Struct_Parser_Enum_TokenType_String_String(ptr %t1410, i32 18, ptr %t1411, ptr %t1412)
  %t1413 = call ptr @create_node__Enum_NodeKind(i32 5)
  store ptr %t1413, ptr %struct_node
  %t1414 = load ptr, ptr %p
  %t1415 = call ptr @parser_current__Struct_Parser(ptr %t1414)
  store ptr %t1415, ptr %curr
  %t1416 = load ptr, ptr %struct_node
  %t1417 = load ptr, ptr %curr
  %t1418 = getelementptr inbounds %Token, ptr %t1417, i32 0, i32 1
  %t1419 = load ptr, ptr %t1418
  %t1420 = getelementptr inbounds %ASTNode, ptr %t1416, i32 0, i32 1
  store ptr %t1419, ptr %t1420
  %t1421 = load ptr, ptr %p
  %t1422 = getelementptr inbounds [12 x i8], ptr @.str.s138, i64 0, i64 0
  call void @parser_expect__Struct_Parser_Enum_TokenType_String(ptr %t1421, i32 5, ptr %t1422)
  %t1423 = load ptr, ptr %p
  %t1424 = getelementptr inbounds [2 x i8], ptr @.str.s139, i64 0, i64 0
  %t1425 = getelementptr inbounds [12 x i8], ptr @.str.s140, i64 0, i64 0
  call void @parser_expect_val__Struct_Parser_Enum_TokenType_String_String(ptr %t1423, i32 6, ptr %t1424, ptr %t1425)
  %t1426 = getelementptr inbounds [1 x i8], ptr @.str.s141, i64 0, i64 0
  store ptr %t1426, ptr %last_field
  br label %label_693
label_693:
  %t1427 = load ptr, ptr %p
  %t1428 = getelementptr inbounds [2 x i8], ptr @.str.s142, i64 0, i64 0
  %t1429 = call i1 @parser_check_val__Struct_Parser_Enum_TokenType_String(ptr %t1427, i32 6, ptr %t1428)
  %t1430 = icmp eq i1 %t1429, 0
  br i1 %t1430, label %label_694, label %label_695
label_694:
  %t1431 = call ptr @create_node__Enum_NodeKind(i32 31)
  store ptr %t1431, ptr %field
  %t1432 = load ptr, ptr %p
  %t1433 = call ptr @parser_current__Struct_Parser(ptr %t1432)
  store ptr %t1433, ptr %curr
  %t1434 = load ptr, ptr %field
  %t1435 = load ptr, ptr %curr
  %t1436 = getelementptr inbounds %Token, ptr %t1435, i32 0, i32 1
  %t1437 = load ptr, ptr %t1436
  %t1438 = getelementptr inbounds %ASTNode, ptr %t1434, i32 0, i32 1
  store ptr %t1437, ptr %t1438
  %t1439 = load ptr, ptr %p
  %t1440 = getelementptr inbounds [11 x i8], ptr @.str.s143, i64 0, i64 0
  call void @parser_expect__Struct_Parser_Enum_TokenType_String(ptr %t1439, i32 5, ptr %t1440)
  %t1441 = load ptr, ptr %p
  %t1442 = getelementptr inbounds [2 x i8], ptr @.str.s144, i64 0, i64 0
  %t1443 = getelementptr inbounds [11 x i8], ptr @.str.s145, i64 0, i64 0
  call void @parser_expect_val__Struct_Parser_Enum_TokenType_String_String(ptr %t1441, i32 6, ptr %t1442, ptr %t1443)
  %t1444 = load ptr, ptr %field
  %t1445 = load ptr, ptr %p
  %t1446 = call ptr @parse_type_annotation__Struct_Parser(ptr %t1445)
  %t1447 = call ptr @node_to_ptr(ptr %t1446)
  %t1448 = getelementptr inbounds %ASTNode, ptr %t1444, i32 0, i32 5
  store ptr %t1447, ptr %t1448
  %t1449 = load ptr, ptr %struct_node
  %t1450 = getelementptr inbounds %ASTNode, ptr %t1449, i32 0, i32 5
  %t1451 = load ptr, ptr %t1450
  %t1452 = getelementptr inbounds [1 x i8], ptr @.str.s146, i64 0, i64 0
  %t1453 = call i32 @str_equals(ptr %t1451, ptr %t1452)
  %t1454 = icmp eq i32 %t1453, 1
  br i1 %t1454, label %label_696, label %label_697
label_696:
  %t1455 = load ptr, ptr %struct_node
  %t1456 = load ptr, ptr %field
  %t1457 = call ptr @node_to_ptr(ptr %t1456)
  %t1458 = getelementptr inbounds %ASTNode, ptr %t1455, i32 0, i32 5
  store ptr %t1457, ptr %t1458
  br label %label_698
label_697:
  %t1459 = load ptr, ptr %last_field
  %t1460 = call ptr @ptr_to_node(ptr %t1459)
  store ptr %t1460, ptr %last
  %t1461 = load ptr, ptr %last
  %t1462 = load ptr, ptr %field
  %t1463 = call ptr @node_to_ptr(ptr %t1462)
  %t1464 = getelementptr inbounds %ASTNode, ptr %t1461, i32 0, i32 8
  store ptr %t1463, ptr %t1464
  br label %label_698
label_698:
  %t1465 = load ptr, ptr %field
  %t1466 = call ptr @node_to_ptr(ptr %t1465)
  store ptr %t1466, ptr %last_field
  %t1467 = load ptr, ptr %p
  %t1468 = getelementptr inbounds [2 x i8], ptr @.str.s147, i64 0, i64 0
  %t1469 = call i1 @parser_match_val__Struct_Parser_Enum_TokenType_String(ptr %t1467, i32 6, ptr %t1468)
  br label %label_693
label_695:
  %t1470 = load ptr, ptr %p
  %t1471 = getelementptr inbounds [2 x i8], ptr @.str.s148, i64 0, i64 0
  %t1472 = getelementptr inbounds [12 x i8], ptr @.str.s149, i64 0, i64 0
  call void @parser_expect_val__Struct_Parser_Enum_TokenType_String_String(ptr %t1470, i32 6, ptr %t1471, ptr %t1472)
  %t1473 = load ptr, ptr %struct_node
  ret ptr %t1473
}

define ptr @parse_enum_decl__Struct_Parser(ptr %p_p) {
  %p = alloca ptr
  %enum_node = alloca ptr
  %curr = alloca ptr
  %last_var = alloca ptr
  %variant = alloca ptr
  %last = alloca ptr
  store ptr %p_p, ptr %p
  %t1480 = load ptr, ptr %p
  %t1481 = getelementptr inbounds [5 x i8], ptr @.str.s150, i64 0, i64 0
  %t1482 = getelementptr inbounds [5 x i8], ptr @.str.s151, i64 0, i64 0
  call void @parser_expect_val__Struct_Parser_Enum_TokenType_String_String(ptr %t1480, i32 18, ptr %t1481, ptr %t1482)
  %t1483 = call ptr @create_node__Enum_NodeKind(i32 6)
  store ptr %t1483, ptr %enum_node
  %t1484 = load ptr, ptr %p
  %t1485 = call ptr @parser_current__Struct_Parser(ptr %t1484)
  store ptr %t1485, ptr %curr
  %t1486 = load ptr, ptr %enum_node
  %t1487 = load ptr, ptr %curr
  %t1488 = getelementptr inbounds %Token, ptr %t1487, i32 0, i32 1
  %t1489 = load ptr, ptr %t1488
  %t1490 = getelementptr inbounds %ASTNode, ptr %t1486, i32 0, i32 1
  store ptr %t1489, ptr %t1490
  %t1491 = load ptr, ptr %p
  %t1492 = getelementptr inbounds [10 x i8], ptr @.str.s152, i64 0, i64 0
  call void @parser_expect__Struct_Parser_Enum_TokenType_String(ptr %t1491, i32 5, ptr %t1492)
  %t1493 = load ptr, ptr %p
  %t1494 = getelementptr inbounds [2 x i8], ptr @.str.s153, i64 0, i64 0
  %t1495 = getelementptr inbounds [10 x i8], ptr @.str.s154, i64 0, i64 0
  call void @parser_expect_val__Struct_Parser_Enum_TokenType_String_String(ptr %t1493, i32 6, ptr %t1494, ptr %t1495)
  %t1496 = getelementptr inbounds [1 x i8], ptr @.str.s155, i64 0, i64 0
  store ptr %t1496, ptr %last_var
  br label %label_699
label_699:
  %t1497 = load ptr, ptr %p
  %t1498 = getelementptr inbounds [2 x i8], ptr @.str.s156, i64 0, i64 0
  %t1499 = call i1 @parser_check_val__Struct_Parser_Enum_TokenType_String(ptr %t1497, i32 6, ptr %t1498)
  %t1500 = icmp eq i1 %t1499, 0
  br i1 %t1500, label %label_700, label %label_701
label_700:
  %t1501 = call ptr @create_node__Enum_NodeKind(i32 32)
  store ptr %t1501, ptr %variant
  %t1502 = load ptr, ptr %p
  %t1503 = call ptr @parser_current__Struct_Parser(ptr %t1502)
  store ptr %t1503, ptr %curr
  %t1504 = load ptr, ptr %variant
  %t1505 = load ptr, ptr %curr
  %t1506 = getelementptr inbounds %Token, ptr %t1505, i32 0, i32 1
  %t1507 = load ptr, ptr %t1506
  %t1508 = getelementptr inbounds %ASTNode, ptr %t1504, i32 0, i32 1
  store ptr %t1507, ptr %t1508
  %t1509 = load ptr, ptr %p
  %t1510 = getelementptr inbounds [13 x i8], ptr @.str.s157, i64 0, i64 0
  call void @parser_expect__Struct_Parser_Enum_TokenType_String(ptr %t1509, i32 5, ptr %t1510)
  %t1511 = load ptr, ptr %enum_node
  %t1512 = getelementptr inbounds %ASTNode, ptr %t1511, i32 0, i32 5
  %t1513 = load ptr, ptr %t1512
  %t1514 = getelementptr inbounds [1 x i8], ptr @.str.s158, i64 0, i64 0
  %t1515 = call i32 @str_equals(ptr %t1513, ptr %t1514)
  %t1516 = icmp eq i32 %t1515, 1
  br i1 %t1516, label %label_702, label %label_703
label_702:
  %t1517 = load ptr, ptr %enum_node
  %t1518 = load ptr, ptr %variant
  %t1519 = call ptr @node_to_ptr(ptr %t1518)
  %t1520 = getelementptr inbounds %ASTNode, ptr %t1517, i32 0, i32 5
  store ptr %t1519, ptr %t1520
  br label %label_704
label_703:
  %t1521 = load ptr, ptr %last_var
  %t1522 = call ptr @ptr_to_node(ptr %t1521)
  store ptr %t1522, ptr %last
  %t1523 = load ptr, ptr %last
  %t1524 = load ptr, ptr %variant
  %t1525 = call ptr @node_to_ptr(ptr %t1524)
  %t1526 = getelementptr inbounds %ASTNode, ptr %t1523, i32 0, i32 8
  store ptr %t1525, ptr %t1526
  br label %label_704
label_704:
  %t1527 = load ptr, ptr %variant
  %t1528 = call ptr @node_to_ptr(ptr %t1527)
  store ptr %t1528, ptr %last_var
  %t1529 = load ptr, ptr %p
  %t1530 = getelementptr inbounds [2 x i8], ptr @.str.s159, i64 0, i64 0
  %t1531 = call i1 @parser_match_val__Struct_Parser_Enum_TokenType_String(ptr %t1529, i32 6, ptr %t1530)
  br label %label_699
label_701:
  %t1532 = load ptr, ptr %p
  %t1533 = getelementptr inbounds [2 x i8], ptr @.str.s160, i64 0, i64 0
  %t1534 = getelementptr inbounds [10 x i8], ptr @.str.s161, i64 0, i64 0
  call void @parser_expect_val__Struct_Parser_Enum_TokenType_String_String(ptr %t1532, i32 6, ptr %t1533, ptr %t1534)
  %t1535 = load ptr, ptr %enum_node
  ret ptr %t1535
}

define ptr @parse_block__Struct_Parser(ptr %p_p) {
  %p = alloca ptr
  %block_node = alloca ptr
  %last_stmt = alloca ptr
  %stmt = alloca ptr
  %last = alloca ptr
  store ptr %p_p, ptr %p
  %t1541 = load ptr, ptr %p
  %t1542 = getelementptr inbounds [2 x i8], ptr @.str.s162, i64 0, i64 0
  %t1543 = getelementptr inbounds [6 x i8], ptr @.str.s163, i64 0, i64 0
  call void @parser_expect_val__Struct_Parser_Enum_TokenType_String_String(ptr %t1541, i32 6, ptr %t1542, ptr %t1543)
  %t1544 = call ptr @create_node__Enum_NodeKind(i32 9)
  store ptr %t1544, ptr %block_node
  %t1545 = getelementptr inbounds [1 x i8], ptr @.str.s164, i64 0, i64 0
  store ptr %t1545, ptr %last_stmt
  br label %label_705
label_705:
  %t1546 = load ptr, ptr %p
  %t1547 = getelementptr inbounds [2 x i8], ptr @.str.s165, i64 0, i64 0
  %t1548 = call i1 @parser_check_val__Struct_Parser_Enum_TokenType_String(ptr %t1546, i32 6, ptr %t1547)
  %t1549 = icmp eq i1 %t1548, 0
  br i1 %t1549, label %label_706, label %label_707
label_706:
  %t1550 = load ptr, ptr %p
  %t1551 = call ptr @parse_statement__Struct_Parser(ptr %t1550)
  store ptr %t1551, ptr %stmt
  %t1552 = load ptr, ptr %block_node
  %t1553 = getelementptr inbounds %ASTNode, ptr %t1552, i32 0, i32 5
  %t1554 = load ptr, ptr %t1553
  %t1555 = getelementptr inbounds [1 x i8], ptr @.str.s166, i64 0, i64 0
  %t1556 = call i32 @str_equals(ptr %t1554, ptr %t1555)
  %t1557 = icmp eq i32 %t1556, 1
  br i1 %t1557, label %label_708, label %label_709
label_708:
  %t1558 = load ptr, ptr %block_node
  %t1559 = load ptr, ptr %stmt
  %t1560 = call ptr @node_to_ptr(ptr %t1559)
  %t1561 = getelementptr inbounds %ASTNode, ptr %t1558, i32 0, i32 5
  store ptr %t1560, ptr %t1561
  br label %label_710
label_709:
  %t1562 = load ptr, ptr %last_stmt
  %t1563 = call ptr @ptr_to_node(ptr %t1562)
  store ptr %t1563, ptr %last
  %t1564 = load ptr, ptr %last
  %t1565 = load ptr, ptr %stmt
  %t1566 = call ptr @node_to_ptr(ptr %t1565)
  %t1567 = getelementptr inbounds %ASTNode, ptr %t1564, i32 0, i32 8
  store ptr %t1566, ptr %t1567
  br label %label_710
label_710:
  %t1568 = load ptr, ptr %stmt
  %t1569 = call ptr @node_to_ptr(ptr %t1568)
  store ptr %t1569, ptr %last_stmt
  br label %label_705
label_707:
  %t1570 = load ptr, ptr %p
  %t1571 = getelementptr inbounds [2 x i8], ptr @.str.s167, i64 0, i64 0
  %t1572 = getelementptr inbounds [6 x i8], ptr @.str.s168, i64 0, i64 0
  call void @parser_expect_val__Struct_Parser_Enum_TokenType_String_String(ptr %t1570, i32 6, ptr %t1571, ptr %t1572)
  %t1573 = load ptr, ptr %block_node
  ret ptr %t1573
}

define ptr @parse_if_statement__Struct_Parser(ptr %p_p) {
  %p = alloca ptr
  %if_node = alloca ptr
  store ptr %p_p, ptr %p
  %t1576 = load ptr, ptr %p
  %t1577 = getelementptr inbounds [3 x i8], ptr @.str.s169, i64 0, i64 0
  %t1578 = getelementptr inbounds [13 x i8], ptr @.str.s170, i64 0, i64 0
  call void @parser_expect_val__Struct_Parser_Enum_TokenType_String_String(ptr %t1576, i32 18, ptr %t1577, ptr %t1578)
  %t1579 = call ptr @create_node__Enum_NodeKind(i32 10)
  store ptr %t1579, ptr %if_node
  %t1580 = load ptr, ptr %p
  %t1581 = getelementptr inbounds [2 x i8], ptr @.str.s171, i64 0, i64 0
  %t1582 = getelementptr inbounds [13 x i8], ptr @.str.s172, i64 0, i64 0
  call void @parser_expect_val__Struct_Parser_Enum_TokenType_String_String(ptr %t1580, i32 6, ptr %t1581, ptr %t1582)
  %t1583 = load ptr, ptr %if_node
  %t1584 = load ptr, ptr %p
  %t1585 = call ptr @parse_expression__Struct_Parser_Int(ptr %t1584, i32 0)
  %t1586 = call ptr @node_to_ptr(ptr %t1585)
  %t1587 = getelementptr inbounds %ASTNode, ptr %t1583, i32 0, i32 5
  store ptr %t1586, ptr %t1587
  %t1588 = load ptr, ptr %p
  %t1589 = getelementptr inbounds [2 x i8], ptr @.str.s173, i64 0, i64 0
  %t1590 = getelementptr inbounds [13 x i8], ptr @.str.s174, i64 0, i64 0
  call void @parser_expect_val__Struct_Parser_Enum_TokenType_String_String(ptr %t1588, i32 6, ptr %t1589, ptr %t1590)
  %t1591 = load ptr, ptr %if_node
  %t1592 = load ptr, ptr %p
  %t1593 = call ptr @parse_block__Struct_Parser(ptr %t1592)
  %t1594 = call ptr @node_to_ptr(ptr %t1593)
  %t1595 = getelementptr inbounds %ASTNode, ptr %t1591, i32 0, i32 6
  store ptr %t1594, ptr %t1595
  %t1596 = load ptr, ptr %p
  %t1597 = getelementptr inbounds [5 x i8], ptr @.str.s175, i64 0, i64 0
  %t1598 = call i1 @parser_match_val__Struct_Parser_Enum_TokenType_String(ptr %t1596, i32 18, ptr %t1597)
  br i1 %t1598, label %label_711, label %label_713
label_711:
  %t1599 = load ptr, ptr %p
  %t1600 = getelementptr inbounds [3 x i8], ptr @.str.s176, i64 0, i64 0
  %t1601 = call i1 @parser_check_val__Struct_Parser_Enum_TokenType_String(ptr %t1599, i32 18, ptr %t1600)
  br i1 %t1601, label %label_714, label %label_715
label_714:
  %t1602 = load ptr, ptr %if_node
  %t1603 = load ptr, ptr %p
  %t1604 = call ptr @parse_if_statement__Struct_Parser(ptr %t1603)
  %t1605 = call ptr @node_to_ptr(ptr %t1604)
  %t1606 = getelementptr inbounds %ASTNode, ptr %t1602, i32 0, i32 7
  store ptr %t1605, ptr %t1606
  br label %label_716
label_715:
  %t1607 = load ptr, ptr %if_node
  %t1608 = load ptr, ptr %p
  %t1609 = call ptr @parse_block__Struct_Parser(ptr %t1608)
  %t1610 = call ptr @node_to_ptr(ptr %t1609)
  %t1611 = getelementptr inbounds %ASTNode, ptr %t1607, i32 0, i32 7
  store ptr %t1610, ptr %t1611
  br label %label_716
label_716:
  br label %label_713
label_713:
  %t1612 = load ptr, ptr %if_node
  ret ptr %t1612
}

define ptr @parse_while_statement__Struct_Parser(ptr %p_p) {
  %p = alloca ptr
  %while_node = alloca ptr
  store ptr %p_p, ptr %p
  %t1615 = load ptr, ptr %p
  %t1616 = getelementptr inbounds [6 x i8], ptr @.str.s177, i64 0, i64 0
  %t1617 = getelementptr inbounds [16 x i8], ptr @.str.s178, i64 0, i64 0
  call void @parser_expect_val__Struct_Parser_Enum_TokenType_String_String(ptr %t1615, i32 18, ptr %t1616, ptr %t1617)
  %t1618 = call ptr @create_node__Enum_NodeKind(i32 13)
  store ptr %t1618, ptr %while_node
  %t1619 = load ptr, ptr %p
  %t1620 = getelementptr inbounds [2 x i8], ptr @.str.s179, i64 0, i64 0
  %t1621 = getelementptr inbounds [16 x i8], ptr @.str.s180, i64 0, i64 0
  call void @parser_expect_val__Struct_Parser_Enum_TokenType_String_String(ptr %t1619, i32 6, ptr %t1620, ptr %t1621)
  %t1622 = load ptr, ptr %while_node
  %t1623 = load ptr, ptr %p
  %t1624 = call ptr @parse_expression__Struct_Parser_Int(ptr %t1623, i32 0)
  %t1625 = call ptr @node_to_ptr(ptr %t1624)
  %t1626 = getelementptr inbounds %ASTNode, ptr %t1622, i32 0, i32 5
  store ptr %t1625, ptr %t1626
  %t1627 = load ptr, ptr %p
  %t1628 = getelementptr inbounds [2 x i8], ptr @.str.s181, i64 0, i64 0
  %t1629 = getelementptr inbounds [16 x i8], ptr @.str.s182, i64 0, i64 0
  call void @parser_expect_val__Struct_Parser_Enum_TokenType_String_String(ptr %t1627, i32 6, ptr %t1628, ptr %t1629)
  %t1630 = load ptr, ptr %while_node
  %t1631 = load ptr, ptr %p
  %t1632 = call ptr @parse_block__Struct_Parser(ptr %t1631)
  %t1633 = call ptr @node_to_ptr(ptr %t1632)
  %t1634 = getelementptr inbounds %ASTNode, ptr %t1630, i32 0, i32 6
  store ptr %t1633, ptr %t1634
  %t1635 = load ptr, ptr %while_node
  ret ptr %t1635
}

define ptr @parse_loop_statement__Struct_Parser(ptr %p_p) {
  %p = alloca ptr
  %loop_node = alloca ptr
  store ptr %p_p, ptr %p
  %t1638 = load ptr, ptr %p
  %t1639 = getelementptr inbounds [5 x i8], ptr @.str.s183, i64 0, i64 0
  %t1640 = getelementptr inbounds [15 x i8], ptr @.str.s184, i64 0, i64 0
  call void @parser_expect_val__Struct_Parser_Enum_TokenType_String_String(ptr %t1638, i32 18, ptr %t1639, ptr %t1640)
  %t1641 = call ptr @create_node__Enum_NodeKind(i32 14)
  store ptr %t1641, ptr %loop_node
  %t1642 = load ptr, ptr %loop_node
  %t1643 = load ptr, ptr %p
  %t1644 = call ptr @parse_block__Struct_Parser(ptr %t1643)
  %t1645 = call ptr @node_to_ptr(ptr %t1644)
  %t1646 = getelementptr inbounds %ASTNode, ptr %t1642, i32 0, i32 5
  store ptr %t1645, ptr %t1646
  %t1647 = load ptr, ptr %loop_node
  ret ptr %t1647
}

define ptr @parse_for_statement__Struct_Parser(ptr %p_p) {
  %p = alloca ptr
  %for_node = alloca ptr
  %curr = alloca ptr
  store ptr %p_p, ptr %p
  %t1651 = load ptr, ptr %p
  %t1652 = getelementptr inbounds [4 x i8], ptr @.str.s185, i64 0, i64 0
  %t1653 = getelementptr inbounds [14 x i8], ptr @.str.s186, i64 0, i64 0
  call void @parser_expect_val__Struct_Parser_Enum_TokenType_String_String(ptr %t1651, i32 18, ptr %t1652, ptr %t1653)
  %t1654 = call ptr @create_node__Enum_NodeKind(i32 12)
  store ptr %t1654, ptr %for_node
  %t1655 = load ptr, ptr %p
  %t1656 = call ptr @parser_current__Struct_Parser(ptr %t1655)
  store ptr %t1656, ptr %curr
  %t1657 = load ptr, ptr %for_node
  %t1658 = load ptr, ptr %curr
  %t1659 = getelementptr inbounds %Token, ptr %t1658, i32 0, i32 1
  %t1660 = load ptr, ptr %t1659
  %t1661 = getelementptr inbounds %ASTNode, ptr %t1657, i32 0, i32 1
  store ptr %t1660, ptr %t1661
  %t1662 = load ptr, ptr %p
  %t1663 = getelementptr inbounds [18 x i8], ptr @.str.s187, i64 0, i64 0
  call void @parser_expect__Struct_Parser_Enum_TokenType_String(ptr %t1662, i32 5, ptr %t1663)
  %t1664 = load ptr, ptr %p
  %t1665 = getelementptr inbounds [3 x i8], ptr @.str.s188, i64 0, i64 0
  %t1666 = getelementptr inbounds [11 x i8], ptr @.str.s189, i64 0, i64 0
  call void @parser_expect_val__Struct_Parser_Enum_TokenType_String_String(ptr %t1664, i32 18, ptr %t1665, ptr %t1666)
  store i32 0, ptr @parser_allow_struct_lit
  %t1667 = load ptr, ptr %for_node
  %t1668 = load ptr, ptr %p
  %t1669 = call ptr @parse_expression__Struct_Parser_Int(ptr %t1668, i32 0)
  %t1670 = call ptr @node_to_ptr(ptr %t1669)
  %t1671 = getelementptr inbounds %ASTNode, ptr %t1667, i32 0, i32 5
  store ptr %t1670, ptr %t1671
  %t1672 = load ptr, ptr %p
  %t1673 = getelementptr inbounds [3 x i8], ptr @.str.s190, i64 0, i64 0
  %t1674 = getelementptr inbounds [10 x i8], ptr @.str.s191, i64 0, i64 0
  call void @parser_expect_val__Struct_Parser_Enum_TokenType_String_String(ptr %t1672, i32 17, ptr %t1673, ptr %t1674)
  %t1675 = load ptr, ptr %for_node
  %t1676 = load ptr, ptr %p
  %t1677 = call ptr @parse_expression__Struct_Parser_Int(ptr %t1676, i32 0)
  %t1678 = call ptr @node_to_ptr(ptr %t1677)
  %t1679 = getelementptr inbounds %ASTNode, ptr %t1675, i32 0, i32 6
  store ptr %t1678, ptr %t1679
  store i32 1, ptr @parser_allow_struct_lit
  %t1680 = load ptr, ptr %for_node
  %t1681 = load ptr, ptr %p
  %t1682 = call ptr @parse_block__Struct_Parser(ptr %t1681)
  %t1683 = call ptr @node_to_ptr(ptr %t1682)
  %t1684 = getelementptr inbounds %ASTNode, ptr %t1680, i32 0, i32 7
  store ptr %t1683, ptr %t1684
  %t1685 = load ptr, ptr %for_node
  ret ptr %t1685
}

define ptr @parse_match_arm__Struct_Parser(ptr %p_p) {
  %p = alloca ptr
  %arm = alloca ptr
  store ptr %p_p, ptr %p
  %t1688 = call ptr @create_node__Enum_NodeKind(i32 33)
  store ptr %t1688, ptr %arm
  %t1689 = load ptr, ptr %p
  %t1690 = getelementptr inbounds [2 x i8], ptr @.str.s192, i64 0, i64 0
  %t1691 = call i1 @parser_match_val__Struct_Parser_Enum_TokenType_String(ptr %t1689, i32 5, ptr %t1690)
  br i1 %t1691, label %label_717, label %label_718
label_717:
  %t1692 = load ptr, ptr %arm
  %t1693 = getelementptr inbounds [2 x i8], ptr @.str.s193, i64 0, i64 0
  %t1694 = getelementptr inbounds %ASTNode, ptr %t1692, i32 0, i32 1
  store ptr %t1693, ptr %t1694
  br label %label_719
label_718:
  %t1695 = load ptr, ptr %arm
  %t1696 = load ptr, ptr %p
  %t1697 = call ptr @parse_expression__Struct_Parser_Int(ptr %t1696, i32 0)
  %t1698 = call ptr @node_to_ptr(ptr %t1697)
  %t1699 = getelementptr inbounds %ASTNode, ptr %t1695, i32 0, i32 5
  store ptr %t1698, ptr %t1699
  br label %label_719
label_719:
  %t1700 = load ptr, ptr %p
  %t1701 = getelementptr inbounds [3 x i8], ptr @.str.s194, i64 0, i64 0
  %t1702 = getelementptr inbounds [10 x i8], ptr @.str.s195, i64 0, i64 0
  call void @parser_expect_val__Struct_Parser_Enum_TokenType_String_String(ptr %t1700, i32 16, ptr %t1701, ptr %t1702)
  %t1703 = load ptr, ptr %arm
  %t1704 = load ptr, ptr %p
  %t1705 = call ptr @parse_block__Struct_Parser(ptr %t1704)
  %t1706 = call ptr @node_to_ptr(ptr %t1705)
  %t1707 = getelementptr inbounds %ASTNode, ptr %t1703, i32 0, i32 6
  store ptr %t1706, ptr %t1707
  %t1708 = load ptr, ptr %arm
  ret ptr %t1708
}

define ptr @parse_match_statement__Struct_Parser(ptr %p_p) {
  %p = alloca ptr
  %match_node = alloca ptr
  %head = alloca ptr
  %tail_ptr = alloca ptr
  %arm = alloca ptr
  %tail = alloca ptr
  store ptr %p_p, ptr %p
  %t1715 = load ptr, ptr %p
  %t1716 = getelementptr inbounds [6 x i8], ptr @.str.s196, i64 0, i64 0
  %t1717 = getelementptr inbounds [16 x i8], ptr @.str.s197, i64 0, i64 0
  call void @parser_expect_val__Struct_Parser_Enum_TokenType_String_String(ptr %t1715, i32 18, ptr %t1716, ptr %t1717)
  %t1718 = call ptr @create_node__Enum_NodeKind(i32 11)
  store ptr %t1718, ptr %match_node
  %t1719 = load ptr, ptr %p
  %t1720 = getelementptr inbounds [2 x i8], ptr @.str.s198, i64 0, i64 0
  %t1721 = getelementptr inbounds [16 x i8], ptr @.str.s199, i64 0, i64 0
  call void @parser_expect_val__Struct_Parser_Enum_TokenType_String_String(ptr %t1719, i32 6, ptr %t1720, ptr %t1721)
  %t1722 = load ptr, ptr %match_node
  %t1723 = load ptr, ptr %p
  %t1724 = call ptr @parse_expression__Struct_Parser_Int(ptr %t1723, i32 0)
  %t1725 = call ptr @node_to_ptr(ptr %t1724)
  %t1726 = getelementptr inbounds %ASTNode, ptr %t1722, i32 0, i32 5
  store ptr %t1725, ptr %t1726
  %t1727 = load ptr, ptr %p
  %t1728 = getelementptr inbounds [2 x i8], ptr @.str.s200, i64 0, i64 0
  %t1729 = getelementptr inbounds [16 x i8], ptr @.str.s201, i64 0, i64 0
  call void @parser_expect_val__Struct_Parser_Enum_TokenType_String_String(ptr %t1727, i32 6, ptr %t1728, ptr %t1729)
  %t1730 = load ptr, ptr %p
  %t1731 = getelementptr inbounds [2 x i8], ptr @.str.s202, i64 0, i64 0
  %t1732 = getelementptr inbounds [11 x i8], ptr @.str.s203, i64 0, i64 0
  call void @parser_expect_val__Struct_Parser_Enum_TokenType_String_String(ptr %t1730, i32 6, ptr %t1731, ptr %t1732)
  %t1733 = getelementptr inbounds [1 x i8], ptr @.str.s204, i64 0, i64 0
  store ptr %t1733, ptr %head
  %t1734 = getelementptr inbounds [1 x i8], ptr @.str.s205, i64 0, i64 0
  store ptr %t1734, ptr %tail_ptr
  br label %label_720
label_720:
  %t1735 = load ptr, ptr %p
  %t1736 = getelementptr inbounds [2 x i8], ptr @.str.s206, i64 0, i64 0
  %t1737 = call i1 @parser_check_val__Struct_Parser_Enum_TokenType_String(ptr %t1735, i32 6, ptr %t1736)
  %t1738 = icmp eq i1 %t1737, 0
  br i1 %t1738, label %label_721, label %label_722
label_721:
  %t1739 = load ptr, ptr %p
  %t1740 = call ptr @parse_match_arm__Struct_Parser(ptr %t1739)
  store ptr %t1740, ptr %arm
  %t1741 = load ptr, ptr %head
  %t1742 = getelementptr inbounds [1 x i8], ptr @.str.s207, i64 0, i64 0
  %t1743 = call i32 @str_equals(ptr %t1741, ptr %t1742)
  %t1744 = icmp eq i32 %t1743, 1
  br i1 %t1744, label %label_723, label %label_724
label_723:
  %t1745 = load ptr, ptr %arm
  %t1746 = call ptr @node_to_ptr(ptr %t1745)
  store ptr %t1746, ptr %head
  %t1747 = load ptr, ptr %head
  store ptr %t1747, ptr %tail_ptr
  br label %label_725
label_724:
  %t1748 = load ptr, ptr %tail_ptr
  %t1749 = call ptr @ptr_to_node(ptr %t1748)
  store ptr %t1749, ptr %tail
  %t1750 = load ptr, ptr %tail
  %t1751 = load ptr, ptr %arm
  %t1752 = call ptr @node_to_ptr(ptr %t1751)
  %t1753 = getelementptr inbounds %ASTNode, ptr %t1750, i32 0, i32 8
  store ptr %t1752, ptr %t1753
  %t1754 = load ptr, ptr %tail
  %t1755 = getelementptr inbounds %ASTNode, ptr %t1754, i32 0, i32 8
  %t1756 = load ptr, ptr %t1755
  store ptr %t1756, ptr %tail_ptr
  br label %label_725
label_725:
  %t1757 = load ptr, ptr %p
  %t1758 = getelementptr inbounds [2 x i8], ptr @.str.s208, i64 0, i64 0
  %t1759 = call i1 @parser_match_val__Struct_Parser_Enum_TokenType_String(ptr %t1757, i32 6, ptr %t1758)
  br label %label_720
label_722:
  %t1760 = load ptr, ptr %p
  %t1761 = getelementptr inbounds [2 x i8], ptr @.str.s209, i64 0, i64 0
  %t1762 = getelementptr inbounds [11 x i8], ptr @.str.s210, i64 0, i64 0
  call void @parser_expect_val__Struct_Parser_Enum_TokenType_String_String(ptr %t1760, i32 6, ptr %t1761, ptr %t1762)
  %t1763 = load ptr, ptr %match_node
  %t1764 = load ptr, ptr %head
  %t1765 = getelementptr inbounds %ASTNode, ptr %t1763, i32 0, i32 6
  store ptr %t1764, ptr %t1765
  %t1766 = load ptr, ptr %match_node
  ret ptr %t1766
}

define ptr @parse_statement__Struct_Parser(ptr %p_p) {
  %p = alloca ptr
  %ret_node = alloca ptr
  %curr = alloca ptr
  %expr = alloca ptr
  %assign_stmt = alloca ptr
  %stmt = alloca ptr
  store ptr %p_p, ptr %p
  %t1773 = load ptr, ptr %p
  %t1774 = getelementptr inbounds [3 x i8], ptr @.str.s211, i64 0, i64 0
  %t1775 = call i1 @parser_check_val__Struct_Parser_Enum_TokenType_String(ptr %t1773, i32 18, ptr %t1774)
  br i1 %t1775, label %label_726, label %label_728
label_726:
  %t1776 = load ptr, ptr %p
  %t1777 = call ptr @parse_if_statement__Struct_Parser(ptr %t1776)
  ret ptr %t1777
label_728:
  %t1778 = load ptr, ptr %p
  %t1779 = getelementptr inbounds [6 x i8], ptr @.str.s212, i64 0, i64 0
  %t1780 = call i1 @parser_check_val__Struct_Parser_Enum_TokenType_String(ptr %t1778, i32 18, ptr %t1779)
  br i1 %t1780, label %label_729, label %label_731
label_729:
  %t1781 = load ptr, ptr %p
  %t1782 = call ptr @parse_while_statement__Struct_Parser(ptr %t1781)
  ret ptr %t1782
label_731:
  %t1783 = load ptr, ptr %p
  %t1784 = getelementptr inbounds [5 x i8], ptr @.str.s213, i64 0, i64 0
  %t1785 = call i1 @parser_check_val__Struct_Parser_Enum_TokenType_String(ptr %t1783, i32 18, ptr %t1784)
  br i1 %t1785, label %label_732, label %label_734
label_732:
  %t1786 = load ptr, ptr %p
  %t1787 = call ptr @parse_loop_statement__Struct_Parser(ptr %t1786)
  ret ptr %t1787
label_734:
  %t1788 = load ptr, ptr %p
  %t1789 = getelementptr inbounds [6 x i8], ptr @.str.s214, i64 0, i64 0
  %t1790 = call i1 @parser_check_val__Struct_Parser_Enum_TokenType_String(ptr %t1788, i32 18, ptr %t1789)
  br i1 %t1790, label %label_735, label %label_737
label_735:
  %t1791 = load ptr, ptr %p
  %t1792 = call ptr @parse_match_statement__Struct_Parser(ptr %t1791)
  ret ptr %t1792
label_737:
  %t1793 = load ptr, ptr %p
  %t1794 = getelementptr inbounds [4 x i8], ptr @.str.s215, i64 0, i64 0
  %t1795 = call i1 @parser_check_val__Struct_Parser_Enum_TokenType_String(ptr %t1793, i32 18, ptr %t1794)
  br i1 %t1795, label %label_738, label %label_740
label_738:
  %t1796 = load ptr, ptr %p
  %t1797 = call ptr @parse_for_statement__Struct_Parser(ptr %t1796)
  ret ptr %t1797
label_740:
  %t1798 = load ptr, ptr %p
  %t1799 = getelementptr inbounds [6 x i8], ptr @.str.s216, i64 0, i64 0
  %t1800 = call i1 @parser_match_val__Struct_Parser_Enum_TokenType_String(ptr %t1798, i32 18, ptr %t1799)
  br i1 %t1800, label %label_741, label %label_743
label_741:
  %t1801 = call ptr @create_node__Enum_NodeKind(i32 18)
  ret ptr %t1801
label_743:
  %t1802 = load ptr, ptr %p
  %t1803 = getelementptr inbounds [9 x i8], ptr @.str.s217, i64 0, i64 0
  %t1804 = call i1 @parser_match_val__Struct_Parser_Enum_TokenType_String(ptr %t1802, i32 18, ptr %t1803)
  br i1 %t1804, label %label_744, label %label_746
label_744:
  %t1805 = call ptr @create_node__Enum_NodeKind(i32 19)
  ret ptr %t1805
label_746:
  %t1806 = load ptr, ptr %p
  %t1807 = getelementptr inbounds [7 x i8], ptr @.str.s218, i64 0, i64 0
  %t1808 = call i1 @parser_match_val__Struct_Parser_Enum_TokenType_String(ptr %t1806, i32 18, ptr %t1807)
  br i1 %t1808, label %label_747, label %label_749
label_747:
  %t1809 = call ptr @create_node__Enum_NodeKind(i32 15)
  store ptr %t1809, ptr %ret_node
  %t1810 = load ptr, ptr %p
  %t1811 = call ptr @parser_current__Struct_Parser(ptr %t1810)
  store ptr %t1811, ptr %curr
  %t1812 = load ptr, ptr %curr
  %t1813 = getelementptr inbounds %Token, ptr %t1812, i32 0, i32 0
  %t1814 = load i32, ptr %t1813
  %t1815 = icmp ne i32 %t1814, 6
  %t1816 = load ptr, ptr %curr
  %t1817 = getelementptr inbounds %Token, ptr %t1816, i32 0, i32 1
  %t1818 = load ptr, ptr %t1817
  %t1819 = getelementptr inbounds [2 x i8], ptr @.str.s219, i64 0, i64 0
  %t1820 = call i32 @str_equals(ptr %t1818, ptr %t1819)
  %t1821 = icmp eq i32 %t1820, 0
  %t1822 = or i1 %t1815, %t1821
  br i1 %t1822, label %label_750, label %label_752
label_750:
  %t1823 = load ptr, ptr %ret_node
  %t1824 = load ptr, ptr %p
  %t1825 = call ptr @parse_expression__Struct_Parser_Int(ptr %t1824, i32 0)
  %t1826 = call ptr @node_to_ptr(ptr %t1825)
  %t1827 = getelementptr inbounds %ASTNode, ptr %t1823, i32 0, i32 5
  store ptr %t1826, ptr %t1827
  br label %label_752
label_752:
  %t1828 = load ptr, ptr %ret_node
  ret ptr %t1828
label_749:
  %t1829 = load ptr, ptr %p
  %t1830 = getelementptr inbounds [4 x i8], ptr @.str.s220, i64 0, i64 0
  %t1831 = call i1 @parser_check_val__Struct_Parser_Enum_TokenType_String(ptr %t1829, i32 18, ptr %t1830)
  br i1 %t1831, label %label_753, label %label_755
label_753:
  %t1832 = load ptr, ptr %p
  %t1833 = call ptr @parse_variable_decl__Struct_Parser(ptr %t1832)
  ret ptr %t1833
label_755:
  %t1834 = load ptr, ptr %p
  %t1835 = call ptr @parse_expression__Struct_Parser_Int(ptr %t1834, i32 0)
  store ptr %t1835, ptr %expr
  %t1836 = load ptr, ptr %p
  %t1837 = getelementptr inbounds [2 x i8], ptr @.str.s221, i64 0, i64 0
  %t1838 = call i1 @parser_match_val__Struct_Parser_Enum_TokenType_String(ptr %t1836, i32 12, ptr %t1837)
  br i1 %t1838, label %label_756, label %label_758
label_756:
  %t1839 = call ptr @create_node__Enum_NodeKind(i32 16)
  store ptr %t1839, ptr %assign_stmt
  %t1840 = load ptr, ptr %assign_stmt
  %t1841 = load ptr, ptr %expr
  %t1842 = call ptr @node_to_ptr(ptr %t1841)
  %t1843 = getelementptr inbounds %ASTNode, ptr %t1840, i32 0, i32 5
  store ptr %t1842, ptr %t1843
  %t1844 = load ptr, ptr %assign_stmt
  %t1845 = load ptr, ptr %p
  %t1846 = call ptr @parse_expression__Struct_Parser_Int(ptr %t1845, i32 0)
  %t1847 = call ptr @node_to_ptr(ptr %t1846)
  %t1848 = getelementptr inbounds %ASTNode, ptr %t1844, i32 0, i32 6
  store ptr %t1847, ptr %t1848
  %t1849 = load ptr, ptr %assign_stmt
  ret ptr %t1849
label_758:
  %t1850 = call ptr @create_node__Enum_NodeKind(i32 17)
  store ptr %t1850, ptr %stmt
  %t1851 = load ptr, ptr %stmt
  %t1852 = load ptr, ptr %expr
  %t1853 = call ptr @node_to_ptr(ptr %t1852)
  %t1854 = getelementptr inbounds %ASTNode, ptr %t1851, i32 0, i32 5
  store ptr %t1853, ptr %t1854
  %t1855 = load ptr, ptr %stmt
  ret ptr %t1855
}

define i32 @get_operator_precedence__Struct_Token(ptr %p_t) {
  %t = alloca ptr
  store ptr %p_t, ptr %t
  %t1857 = load ptr, ptr %t
  %t1858 = getelementptr inbounds %Token, ptr %t1857, i32 0, i32 1
  %t1859 = load ptr, ptr %t1858
  %t1860 = getelementptr inbounds [3 x i8], ptr @.str.s222, i64 0, i64 0
  %t1861 = call i32 @str_equals(ptr %t1859, ptr %t1860)
  %t1862 = icmp eq i32 %t1861, 1
  br i1 %t1862, label %label_759, label %label_761
label_759:
  ret i32 1
label_761:
  %t1863 = load ptr, ptr %t
  %t1864 = getelementptr inbounds %Token, ptr %t1863, i32 0, i32 1
  %t1865 = load ptr, ptr %t1864
  %t1866 = getelementptr inbounds [4 x i8], ptr @.str.s223, i64 0, i64 0
  %t1867 = call i32 @str_equals(ptr %t1865, ptr %t1866)
  %t1868 = icmp eq i32 %t1867, 1
  br i1 %t1868, label %label_762, label %label_764
label_762:
  ret i32 2
label_764:
  %t1869 = load ptr, ptr %t
  %t1870 = getelementptr inbounds %Token, ptr %t1869, i32 0, i32 0
  %t1871 = load i32, ptr %t1870
  %t1872 = icmp eq i32 %t1871, 18
  br i1 %t1872, label %label_765, label %label_767
label_765:
  ret i32 0
label_767:
  %t1873 = load ptr, ptr %t
  %t1874 = getelementptr inbounds %Token, ptr %t1873, i32 0, i32 1
  %t1875 = load ptr, ptr %t1874
  %t1876 = getelementptr inbounds [3 x i8], ptr @.str.s224, i64 0, i64 0
  %t1877 = call i32 @str_equals(ptr %t1875, ptr %t1876)
  %t1878 = icmp eq i32 %t1877, 1
  %t1879 = load ptr, ptr %t
  %t1880 = getelementptr inbounds %Token, ptr %t1879, i32 0, i32 1
  %t1881 = load ptr, ptr %t1880
  %t1882 = getelementptr inbounds [3 x i8], ptr @.str.s225, i64 0, i64 0
  %t1883 = call i32 @str_equals(ptr %t1881, ptr %t1882)
  %t1884 = icmp eq i32 %t1883, 1
  %t1885 = or i1 %t1878, %t1884
  br i1 %t1885, label %label_768, label %label_770
label_768:
  ret i32 3
label_770:
  %t1886 = load ptr, ptr %t
  %t1887 = getelementptr inbounds %Token, ptr %t1886, i32 0, i32 1
  %t1888 = load ptr, ptr %t1887
  %t1889 = getelementptr inbounds [2 x i8], ptr @.str.s226, i64 0, i64 0
  %t1890 = call i32 @str_equals(ptr %t1888, ptr %t1889)
  %t1891 = icmp eq i32 %t1890, 1
  %t1892 = load ptr, ptr %t
  %t1893 = getelementptr inbounds %Token, ptr %t1892, i32 0, i32 1
  %t1894 = load ptr, ptr %t1893
  %t1895 = getelementptr inbounds [2 x i8], ptr @.str.s227, i64 0, i64 0
  %t1896 = call i32 @str_equals(ptr %t1894, ptr %t1895)
  %t1897 = icmp eq i32 %t1896, 1
  %t1898 = or i1 %t1891, %t1897
  %t1899 = load ptr, ptr %t
  %t1900 = getelementptr inbounds %Token, ptr %t1899, i32 0, i32 1
  %t1901 = load ptr, ptr %t1900
  %t1902 = getelementptr inbounds [3 x i8], ptr @.str.s228, i64 0, i64 0
  %t1903 = call i32 @str_equals(ptr %t1901, ptr %t1902)
  %t1904 = icmp eq i32 %t1903, 1
  %t1905 = or i1 %t1898, %t1904
  %t1906 = load ptr, ptr %t
  %t1907 = getelementptr inbounds %Token, ptr %t1906, i32 0, i32 1
  %t1908 = load ptr, ptr %t1907
  %t1909 = getelementptr inbounds [3 x i8], ptr @.str.s229, i64 0, i64 0
  %t1910 = call i32 @str_equals(ptr %t1908, ptr %t1909)
  %t1911 = icmp eq i32 %t1910, 1
  %t1912 = or i1 %t1905, %t1911
  br i1 %t1912, label %label_771, label %label_773
label_771:
  ret i32 4
label_773:
  %t1913 = load ptr, ptr %t
  %t1914 = getelementptr inbounds %Token, ptr %t1913, i32 0, i32 1
  %t1915 = load ptr, ptr %t1914
  %t1916 = getelementptr inbounds [2 x i8], ptr @.str.s230, i64 0, i64 0
  %t1917 = call i32 @str_equals(ptr %t1915, ptr %t1916)
  %t1918 = icmp eq i32 %t1917, 1
  %t1919 = load ptr, ptr %t
  %t1920 = getelementptr inbounds %Token, ptr %t1919, i32 0, i32 1
  %t1921 = load ptr, ptr %t1920
  %t1922 = getelementptr inbounds [2 x i8], ptr @.str.s231, i64 0, i64 0
  %t1923 = call i32 @str_equals(ptr %t1921, ptr %t1922)
  %t1924 = icmp eq i32 %t1923, 1
  %t1925 = or i1 %t1918, %t1924
  br i1 %t1925, label %label_774, label %label_776
label_774:
  ret i32 5
label_776:
  %t1926 = load ptr, ptr %t
  %t1927 = getelementptr inbounds %Token, ptr %t1926, i32 0, i32 1
  %t1928 = load ptr, ptr %t1927
  %t1929 = getelementptr inbounds [2 x i8], ptr @.str.s232, i64 0, i64 0
  %t1930 = call i32 @str_equals(ptr %t1928, ptr %t1929)
  %t1931 = icmp eq i32 %t1930, 1
  %t1932 = load ptr, ptr %t
  %t1933 = getelementptr inbounds %Token, ptr %t1932, i32 0, i32 1
  %t1934 = load ptr, ptr %t1933
  %t1935 = getelementptr inbounds [2 x i8], ptr @.str.s233, i64 0, i64 0
  %t1936 = call i32 @str_equals(ptr %t1934, ptr %t1935)
  %t1937 = icmp eq i32 %t1936, 1
  %t1938 = or i1 %t1931, %t1937
  %t1939 = load ptr, ptr %t
  %t1940 = getelementptr inbounds %Token, ptr %t1939, i32 0, i32 1
  %t1941 = load ptr, ptr %t1940
  %t1942 = getelementptr inbounds [2 x i8], ptr @.str.s234, i64 0, i64 0
  %t1943 = call i32 @str_equals(ptr %t1941, ptr %t1942)
  %t1944 = icmp eq i32 %t1943, 1
  %t1945 = or i1 %t1938, %t1944
  br i1 %t1945, label %label_777, label %label_779
label_777:
  ret i32 6
label_779:
  ret i32 0
}

define ptr @parse_expression__Struct_Parser_Int(ptr %p_p, i32 %p_precedence) {
  %p = alloca ptr
  %precedence = alloca i32
  %left = alloca ptr
  %is_looping = alloca i1
  %curr = alloca ptr
  %is_operator = alloca i1
  %current_precedence = alloca i32
  %op = alloca ptr
  %right = alloca ptr
  %bin_expr = alloca ptr
  store ptr %p_p, ptr %p
  store i32 %p_precedence, ptr %precedence
  %t1956 = load ptr, ptr %p
  %t1957 = call ptr @parse_primary__Struct_Parser(ptr %t1956)
  store ptr %t1957, ptr %left
  store i1 1, ptr %is_looping
  br label %label_780
label_780:
  %t1958 = load i1, ptr %is_looping
  br i1 %t1958, label %label_781, label %label_782
label_781:
  %t1959 = load ptr, ptr %p
  %t1960 = call ptr @parser_current__Struct_Parser(ptr %t1959)
  store ptr %t1960, ptr %curr
  %t1961 = load ptr, ptr %curr
  %t1962 = getelementptr inbounds %Token, ptr %t1961, i32 0, i32 0
  %t1963 = load i32, ptr %t1962
  %t1964 = icmp eq i32 %t1963, 8
  %t1965 = load ptr, ptr %curr
  %t1966 = getelementptr inbounds %Token, ptr %t1965, i32 0, i32 0
  %t1967 = load i32, ptr %t1966
  %t1968 = icmp eq i32 %t1967, 9
  %t1969 = or i1 %t1964, %t1968
  %t1970 = load ptr, ptr %curr
  %t1971 = getelementptr inbounds %Token, ptr %t1970, i32 0, i32 1
  %t1972 = load ptr, ptr %t1971
  %t1973 = getelementptr inbounds [4 x i8], ptr @.str.s235, i64 0, i64 0
  %t1974 = call i32 @str_equals(ptr %t1972, ptr %t1973)
  %t1975 = icmp eq i32 %t1974, 1
  %t1976 = or i1 %t1969, %t1975
  %t1977 = load ptr, ptr %curr
  %t1978 = getelementptr inbounds %Token, ptr %t1977, i32 0, i32 1
  %t1979 = load ptr, ptr %t1978
  %t1980 = getelementptr inbounds [3 x i8], ptr @.str.s236, i64 0, i64 0
  %t1981 = call i32 @str_equals(ptr %t1979, ptr %t1980)
  %t1982 = icmp eq i32 %t1981, 1
  %t1983 = or i1 %t1976, %t1982
  store i1 %t1983, ptr %is_operator
  %t1984 = load i1, ptr %is_operator
  %t1985 = icmp eq i1 %t1984, 0
  br i1 %t1985, label %label_783, label %label_784
label_783:
  store i1 0, ptr %is_looping
  br label %label_785
label_784:
  %t1986 = load ptr, ptr %curr
  %t1987 = call i32 @get_operator_precedence__Struct_Token(ptr %t1986)
  store i32 %t1987, ptr %current_precedence
  %t1988 = load i32, ptr %current_precedence
  %t1989 = icmp eq i32 %t1988, 0
  %t1990 = load i32, ptr %current_precedence
  %t1991 = load i32, ptr %precedence
  %t1992 = icmp slt i32 %t1990, %t1991
  %t1993 = or i1 %t1989, %t1992
  br i1 %t1993, label %label_786, label %label_787
label_786:
  store i1 0, ptr %is_looping
  br label %label_788
label_787:
  %t1994 = load ptr, ptr %curr
  %t1995 = getelementptr inbounds %Token, ptr %t1994, i32 0, i32 1
  %t1996 = load ptr, ptr %t1995
  store ptr %t1996, ptr %op
  %t1997 = load ptr, ptr %p
  call void @parser_advance__Struct_Parser(ptr %t1997)
  %t1998 = load ptr, ptr %p
  %t1999 = load i32, ptr %current_precedence
  %t2000 = add i32 %t1999, 1
  %t2001 = call ptr @parse_expression__Struct_Parser_Int(ptr %t1998, i32 %t2000)
  store ptr %t2001, ptr %right
  %t2002 = call ptr @create_node__Enum_NodeKind(i32 20)
  store ptr %t2002, ptr %bin_expr
  %t2003 = load ptr, ptr %bin_expr
  %t2004 = load ptr, ptr %op
  %t2005 = getelementptr inbounds %ASTNode, ptr %t2003, i32 0, i32 1
  store ptr %t2004, ptr %t2005
  %t2006 = load ptr, ptr %bin_expr
  %t2007 = load ptr, ptr %left
  %t2008 = call ptr @node_to_ptr(ptr %t2007)
  %t2009 = getelementptr inbounds %ASTNode, ptr %t2006, i32 0, i32 5
  store ptr %t2008, ptr %t2009
  %t2010 = load ptr, ptr %bin_expr
  %t2011 = load ptr, ptr %right
  %t2012 = call ptr @node_to_ptr(ptr %t2011)
  %t2013 = getelementptr inbounds %ASTNode, ptr %t2010, i32 0, i32 6
  store ptr %t2012, ptr %t2013
  %t2014 = load ptr, ptr %bin_expr
  store ptr %t2014, ptr %left
  br label %label_788
label_788:
  br label %label_785
label_785:
  br label %label_780
label_782:
  %t2015 = load ptr, ptr %left
  ret ptr %t2015
}

define ptr @parse_primary__Struct_Parser(ptr %p_p) {
  %p = alloca ptr
  %curr = alloca ptr
  %lit = alloca ptr
  %next_tok = alloca ptr
  %struct_lit = alloca ptr
  %last_field = alloca ptr
  %field = alloca ptr
  %field_tok = alloca ptr
  %last = alloca ptr
  %ident = alloca ptr
  %expr = alloca ptr
  %is_looping = alloca i1
  %call = alloca ptr
  %last_arg = alloca ptr
  %is_arg_looping = alloca i1
  %arg = alloca ptr
  %index_node = alloca ptr
  %member_node = alloca ptr
  %curr_mem = alloca ptr
  %expr_inner = alloca ptr
  %array_lit = alloca ptr
  %last_elem = alloca ptr
  %elem = alloca ptr
  store ptr %p_p, ptr %p
  %t2039 = load ptr, ptr %p
  %t2040 = call ptr @parser_current__Struct_Parser(ptr %t2039)
  store ptr %t2040, ptr %curr
  %t2041 = load ptr, ptr %curr
  %t2042 = getelementptr inbounds %Token, ptr %t2041, i32 0, i32 0
  %t2043 = load i32, ptr %t2042
  %t2044 = icmp eq i32 %t2043, 2
  %t2045 = load ptr, ptr %curr
  %t2046 = getelementptr inbounds %Token, ptr %t2045, i32 0, i32 0
  %t2047 = load i32, ptr %t2046
  %t2048 = icmp eq i32 %t2047, 3
  %t2049 = or i1 %t2044, %t2048
  %t2050 = load ptr, ptr %curr
  %t2051 = getelementptr inbounds %Token, ptr %t2050, i32 0, i32 0
  %t2052 = load i32, ptr %t2051
  %t2053 = icmp eq i32 %t2052, 0
  %t2054 = or i1 %t2049, %t2053
  %t2055 = load ptr, ptr %curr
  %t2056 = getelementptr inbounds %Token, ptr %t2055, i32 0, i32 0
  %t2057 = load i32, ptr %t2056
  %t2058 = icmp eq i32 %t2057, 4
  %t2059 = or i1 %t2054, %t2058
  %t2060 = load ptr, ptr %curr
  %t2061 = getelementptr inbounds %Token, ptr %t2060, i32 0, i32 0
  %t2062 = load i32, ptr %t2061
  %t2063 = icmp eq i32 %t2062, 1
  %t2064 = or i1 %t2059, %t2063
  br i1 %t2064, label %label_789, label %label_791
label_789:
  %t2065 = call ptr @create_node__Enum_NodeKind(i32 22)
  store ptr %t2065, ptr %lit
  %t2066 = load ptr, ptr %lit
  %t2067 = load ptr, ptr %curr
  %t2068 = getelementptr inbounds %Token, ptr %t2067, i32 0, i32 0
  %t2069 = load i32, ptr %t2068
  %t2070 = getelementptr inbounds %ASTNode, ptr %t2066, i32 0, i32 3
  store i32 %t2069, ptr %t2070
  %t2071 = load ptr, ptr %lit
  %t2072 = load ptr, ptr %curr
  %t2073 = getelementptr inbounds %Token, ptr %t2072, i32 0, i32 1
  %t2074 = load ptr, ptr %t2073
  %t2075 = getelementptr inbounds %ASTNode, ptr %t2071, i32 0, i32 1
  store ptr %t2074, ptr %t2075
  %t2076 = load ptr, ptr %p
  call void @parser_advance__Struct_Parser(ptr %t2076)
  %t2077 = load ptr, ptr %lit
  ret ptr %t2077
label_791:
  %t2078 = load ptr, ptr %curr
  %t2079 = getelementptr inbounds %Token, ptr %t2078, i32 0, i32 0
  %t2080 = load i32, ptr %t2079
  %t2081 = icmp eq i32 %t2080, 5
  br i1 %t2081, label %label_792, label %label_794
label_792:
  %t2082 = load ptr, ptr %p
  %t2083 = call ptr @parser_peek__Struct_Parser(ptr %t2082)
  store ptr %t2083, ptr %next_tok
  %t2084 = load ptr, ptr %next_tok
  %t2085 = getelementptr inbounds %Token, ptr %t2084, i32 0, i32 0
  %t2086 = load i32, ptr %t2085
  %t2087 = icmp eq i32 %t2086, 6
  %t2088 = load ptr, ptr %next_tok
  %t2089 = getelementptr inbounds %Token, ptr %t2088, i32 0, i32 1
  %t2090 = load ptr, ptr %t2089
  %t2091 = getelementptr inbounds [2 x i8], ptr @.str.s237, i64 0, i64 0
  %t2092 = call i32 @str_equals(ptr %t2090, ptr %t2091)
  %t2093 = icmp eq i32 %t2092, 1
  %t2094 = and i1 %t2087, %t2093
  %t2095 = load i32, ptr @parser_allow_struct_lit
  %t2096 = icmp eq i32 %t2095, 1
  %t2097 = and i1 %t2094, %t2096
  br i1 %t2097, label %label_795, label %label_797
label_795:
  %t2098 = call ptr @create_node__Enum_NodeKind(i32 28)
  store ptr %t2098, ptr %struct_lit
  %t2099 = load ptr, ptr %struct_lit
  %t2100 = load ptr, ptr %curr
  %t2101 = getelementptr inbounds %Token, ptr %t2100, i32 0, i32 1
  %t2102 = load ptr, ptr %t2101
  %t2103 = getelementptr inbounds %ASTNode, ptr %t2099, i32 0, i32 1
  store ptr %t2102, ptr %t2103
  %t2104 = load ptr, ptr %p
  call void @parser_advance__Struct_Parser(ptr %t2104)
  %t2105 = load ptr, ptr %p
  %t2106 = getelementptr inbounds [2 x i8], ptr @.str.s238, i64 0, i64 0
  %t2107 = getelementptr inbounds [15 x i8], ptr @.str.s239, i64 0, i64 0
  call void @parser_expect_val__Struct_Parser_Enum_TokenType_String_String(ptr %t2105, i32 6, ptr %t2106, ptr %t2107)
  %t2108 = getelementptr inbounds [1 x i8], ptr @.str.s240, i64 0, i64 0
  store ptr %t2108, ptr %last_field
  br label %label_798
label_798:
  %t2109 = load ptr, ptr %p
  %t2110 = getelementptr inbounds [2 x i8], ptr @.str.s241, i64 0, i64 0
  %t2111 = call i1 @parser_check_val__Struct_Parser_Enum_TokenType_String(ptr %t2109, i32 6, ptr %t2110)
  %t2112 = icmp eq i1 %t2111, 0
  br i1 %t2112, label %label_799, label %label_800
label_799:
  %t2113 = call ptr @create_node__Enum_NodeKind(i32 31)
  store ptr %t2113, ptr %field
  %t2114 = load ptr, ptr %p
  %t2115 = call ptr @parser_current__Struct_Parser(ptr %t2114)
  store ptr %t2115, ptr %field_tok
  %t2116 = load ptr, ptr %field
  %t2117 = load ptr, ptr %field_tok
  %t2118 = getelementptr inbounds %Token, ptr %t2117, i32 0, i32 1
  %t2119 = load ptr, ptr %t2118
  %t2120 = getelementptr inbounds %ASTNode, ptr %t2116, i32 0, i32 1
  store ptr %t2119, ptr %t2120
  %t2121 = load ptr, ptr %p
  %t2122 = getelementptr inbounds [21 x i8], ptr @.str.s242, i64 0, i64 0
  call void @parser_expect__Struct_Parser_Enum_TokenType_String(ptr %t2121, i32 5, ptr %t2122)
  %t2123 = load ptr, ptr %p
  %t2124 = getelementptr inbounds [2 x i8], ptr @.str.s243, i64 0, i64 0
  %t2125 = getelementptr inbounds [15 x i8], ptr @.str.s244, i64 0, i64 0
  call void @parser_expect_val__Struct_Parser_Enum_TokenType_String_String(ptr %t2123, i32 6, ptr %t2124, ptr %t2125)
  %t2126 = load ptr, ptr %field
  %t2127 = load ptr, ptr %p
  %t2128 = call ptr @parse_expression__Struct_Parser_Int(ptr %t2127, i32 0)
  %t2129 = call ptr @node_to_ptr(ptr %t2128)
  %t2130 = getelementptr inbounds %ASTNode, ptr %t2126, i32 0, i32 5
  store ptr %t2129, ptr %t2130
  %t2131 = load ptr, ptr %struct_lit
  %t2132 = getelementptr inbounds %ASTNode, ptr %t2131, i32 0, i32 5
  %t2133 = load ptr, ptr %t2132
  %t2134 = getelementptr inbounds [1 x i8], ptr @.str.s245, i64 0, i64 0
  %t2135 = call i32 @str_equals(ptr %t2133, ptr %t2134)
  %t2136 = icmp eq i32 %t2135, 1
  br i1 %t2136, label %label_801, label %label_802
label_801:
  %t2137 = load ptr, ptr %struct_lit
  %t2138 = load ptr, ptr %field
  %t2139 = call ptr @node_to_ptr(ptr %t2138)
  %t2140 = getelementptr inbounds %ASTNode, ptr %t2137, i32 0, i32 5
  store ptr %t2139, ptr %t2140
  br label %label_803
label_802:
  %t2141 = load ptr, ptr %last_field
  %t2142 = call ptr @ptr_to_node(ptr %t2141)
  store ptr %t2142, ptr %last
  %t2143 = load ptr, ptr %last
  %t2144 = load ptr, ptr %field
  %t2145 = call ptr @node_to_ptr(ptr %t2144)
  %t2146 = getelementptr inbounds %ASTNode, ptr %t2143, i32 0, i32 8
  store ptr %t2145, ptr %t2146
  br label %label_803
label_803:
  %t2147 = load ptr, ptr %field
  %t2148 = call ptr @node_to_ptr(ptr %t2147)
  store ptr %t2148, ptr %last_field
  %t2149 = load ptr, ptr %p
  %t2150 = getelementptr inbounds [2 x i8], ptr @.str.s246, i64 0, i64 0
  %t2151 = call i1 @parser_match_val__Struct_Parser_Enum_TokenType_String(ptr %t2149, i32 6, ptr %t2150)
  br label %label_798
label_800:
  %t2152 = load ptr, ptr %p
  %t2153 = getelementptr inbounds [2 x i8], ptr @.str.s247, i64 0, i64 0
  %t2154 = getelementptr inbounds [15 x i8], ptr @.str.s248, i64 0, i64 0
  call void @parser_expect_val__Struct_Parser_Enum_TokenType_String_String(ptr %t2152, i32 6, ptr %t2153, ptr %t2154)
  %t2155 = load ptr, ptr %struct_lit
  ret ptr %t2155
label_797:
  br label %label_794
label_794:
  %t2156 = load ptr, ptr %curr
  %t2157 = getelementptr inbounds %Token, ptr %t2156, i32 0, i32 0
  %t2158 = load i32, ptr %t2157
  %t2159 = icmp eq i32 %t2158, 5
  br i1 %t2159, label %label_804, label %label_806
label_804:
  %t2160 = call ptr @create_node__Enum_NodeKind(i32 23)
  store ptr %t2160, ptr %ident
  %t2161 = load ptr, ptr %ident
  %t2162 = load ptr, ptr %curr
  %t2163 = getelementptr inbounds %Token, ptr %t2162, i32 0, i32 1
  %t2164 = load ptr, ptr %t2163
  %t2165 = getelementptr inbounds %ASTNode, ptr %t2161, i32 0, i32 1
  store ptr %t2164, ptr %t2165
  %t2166 = load ptr, ptr %p
  call void @parser_advance__Struct_Parser(ptr %t2166)
  %t2167 = load ptr, ptr %ident
  store ptr %t2167, ptr %expr
  store i1 1, ptr %is_looping
  br label %label_807
label_807:
  %t2168 = load i1, ptr %is_looping
  br i1 %t2168, label %label_808, label %label_809
label_808:
  %t2169 = load ptr, ptr %p
  %t2170 = getelementptr inbounds [2 x i8], ptr @.str.s249, i64 0, i64 0
  %t2171 = call i1 @parser_match_val__Struct_Parser_Enum_TokenType_String(ptr %t2169, i32 6, ptr %t2170)
  br i1 %t2171, label %label_810, label %label_811
label_810:
  %t2172 = call ptr @create_node__Enum_NodeKind(i32 24)
  store ptr %t2172, ptr %call
  %t2173 = load ptr, ptr %call
  %t2174 = load ptr, ptr %expr
  %t2175 = call ptr @node_to_ptr(ptr %t2174)
  %t2176 = getelementptr inbounds %ASTNode, ptr %t2173, i32 0, i32 5
  store ptr %t2175, ptr %t2176
  %t2177 = getelementptr inbounds [1 x i8], ptr @.str.s250, i64 0, i64 0
  store ptr %t2177, ptr %last_arg
  %t2178 = load ptr, ptr %p
  %t2179 = getelementptr inbounds [2 x i8], ptr @.str.s251, i64 0, i64 0
  %t2180 = call i1 @parser_check_val__Struct_Parser_Enum_TokenType_String(ptr %t2178, i32 6, ptr %t2179)
  %t2181 = icmp eq i1 %t2180, 0
  br i1 %t2181, label %label_813, label %label_815
label_813:
  store i1 1, ptr %is_arg_looping
  br label %label_816
label_816:
  %t2182 = load i1, ptr %is_arg_looping
  br i1 %t2182, label %label_817, label %label_818
label_817:
  %t2183 = load ptr, ptr %p
  %t2184 = call ptr @parse_expression__Struct_Parser_Int(ptr %t2183, i32 0)
  store ptr %t2184, ptr %arg
  %t2185 = load ptr, ptr %call
  %t2186 = getelementptr inbounds %ASTNode, ptr %t2185, i32 0, i32 6
  %t2187 = load ptr, ptr %t2186
  %t2188 = getelementptr inbounds [1 x i8], ptr @.str.s252, i64 0, i64 0
  %t2189 = call i32 @str_equals(ptr %t2187, ptr %t2188)
  %t2190 = icmp eq i32 %t2189, 1
  br i1 %t2190, label %label_819, label %label_820
label_819:
  %t2191 = load ptr, ptr %call
  %t2192 = load ptr, ptr %arg
  %t2193 = call ptr @node_to_ptr(ptr %t2192)
  %t2194 = getelementptr inbounds %ASTNode, ptr %t2191, i32 0, i32 6
  store ptr %t2193, ptr %t2194
  br label %label_821
label_820:
  %t2195 = load ptr, ptr %last_arg
  %t2196 = call ptr @ptr_to_node(ptr %t2195)
  store ptr %t2196, ptr %last
  %t2197 = load ptr, ptr %last
  %t2198 = load ptr, ptr %arg
  %t2199 = call ptr @node_to_ptr(ptr %t2198)
  %t2200 = getelementptr inbounds %ASTNode, ptr %t2197, i32 0, i32 8
  store ptr %t2199, ptr %t2200
  br label %label_821
label_821:
  %t2201 = load ptr, ptr %arg
  %t2202 = call ptr @node_to_ptr(ptr %t2201)
  store ptr %t2202, ptr %last_arg
  %t2203 = load ptr, ptr %p
  %t2204 = getelementptr inbounds [2 x i8], ptr @.str.s253, i64 0, i64 0
  %t2205 = call i1 @parser_match_val__Struct_Parser_Enum_TokenType_String(ptr %t2203, i32 6, ptr %t2204)
  %t2206 = icmp eq i1 %t2205, 0
  br i1 %t2206, label %label_822, label %label_824
label_822:
  store i1 0, ptr %is_arg_looping
  br label %label_824
label_824:
  br label %label_816
label_818:
  br label %label_815
label_815:
  %t2207 = load ptr, ptr %p
  %t2208 = getelementptr inbounds [2 x i8], ptr @.str.s254, i64 0, i64 0
  %t2209 = getelementptr inbounds [14 x i8], ptr @.str.s255, i64 0, i64 0
  call void @parser_expect_val__Struct_Parser_Enum_TokenType_String_String(ptr %t2207, i32 6, ptr %t2208, ptr %t2209)
  %t2210 = load ptr, ptr %call
  store ptr %t2210, ptr %expr
  br label %label_812
label_811:
  %t2211 = load ptr, ptr %p
  %t2212 = getelementptr inbounds [2 x i8], ptr @.str.s256, i64 0, i64 0
  %t2213 = call i1 @parser_match_val__Struct_Parser_Enum_TokenType_String(ptr %t2211, i32 6, ptr %t2212)
  br i1 %t2213, label %label_825, label %label_826
label_825:
  %t2214 = call ptr @create_node__Enum_NodeKind(i32 26)
  store ptr %t2214, ptr %index_node
  %t2215 = load ptr, ptr %index_node
  %t2216 = load ptr, ptr %expr
  %t2217 = call ptr @node_to_ptr(ptr %t2216)
  %t2218 = getelementptr inbounds %ASTNode, ptr %t2215, i32 0, i32 5
  store ptr %t2217, ptr %t2218
  %t2219 = load ptr, ptr %index_node
  %t2220 = load ptr, ptr %p
  %t2221 = call ptr @parse_expression__Struct_Parser_Int(ptr %t2220, i32 0)
  %t2222 = call ptr @node_to_ptr(ptr %t2221)
  %t2223 = getelementptr inbounds %ASTNode, ptr %t2219, i32 0, i32 6
  store ptr %t2222, ptr %t2223
  %t2224 = load ptr, ptr %p
  %t2225 = getelementptr inbounds [2 x i8], ptr @.str.s257, i64 0, i64 0
  %t2226 = getelementptr inbounds [12 x i8], ptr @.str.s258, i64 0, i64 0
  call void @parser_expect_val__Struct_Parser_Enum_TokenType_String_String(ptr %t2224, i32 6, ptr %t2225, ptr %t2226)
  %t2227 = load ptr, ptr %index_node
  store ptr %t2227, ptr %expr
  br label %label_827
label_826:
  %t2228 = load ptr, ptr %p
  %t2229 = getelementptr inbounds [2 x i8], ptr @.str.s259, i64 0, i64 0
  %t2230 = call i1 @parser_match_val__Struct_Parser_Enum_TokenType_String(ptr %t2228, i32 6, ptr %t2229)
  br i1 %t2230, label %label_828, label %label_829
label_828:
  %t2231 = call ptr @create_node__Enum_NodeKind(i32 25)
  store ptr %t2231, ptr %member_node
  %t2232 = load ptr, ptr %member_node
  %t2233 = load ptr, ptr %expr
  %t2234 = call ptr @node_to_ptr(ptr %t2233)
  %t2235 = getelementptr inbounds %ASTNode, ptr %t2232, i32 0, i32 5
  store ptr %t2234, ptr %t2235
  %t2236 = load ptr, ptr %p
  %t2237 = call ptr @parser_current__Struct_Parser(ptr %t2236)
  store ptr %t2237, ptr %curr_mem
  %t2238 = load ptr, ptr %member_node
  %t2239 = load ptr, ptr %curr_mem
  %t2240 = getelementptr inbounds %Token, ptr %t2239, i32 0, i32 1
  %t2241 = load ptr, ptr %t2240
  %t2242 = getelementptr inbounds %ASTNode, ptr %t2238, i32 0, i32 1
  store ptr %t2241, ptr %t2242
  %t2243 = load ptr, ptr %p
  %t2244 = getelementptr inbounds [12 x i8], ptr @.str.s260, i64 0, i64 0
  call void @parser_expect__Struct_Parser_Enum_TokenType_String(ptr %t2243, i32 5, ptr %t2244)
  %t2245 = load ptr, ptr %member_node
  store ptr %t2245, ptr %expr
  br label %label_830
label_829:
  store i1 0, ptr %is_looping
  br label %label_830
label_830:
  br label %label_827
label_827:
  br label %label_812
label_812:
  br label %label_807
label_809:
  %t2246 = load ptr, ptr %expr
  ret ptr %t2246
label_806:
  %t2247 = load ptr, ptr %p
  %t2248 = getelementptr inbounds [2 x i8], ptr @.str.s261, i64 0, i64 0
  %t2249 = call i1 @parser_match_val__Struct_Parser_Enum_TokenType_String(ptr %t2247, i32 6, ptr %t2248)
  br i1 %t2249, label %label_831, label %label_833
label_831:
  %t2250 = load ptr, ptr %p
  %t2251 = call ptr @parse_expression__Struct_Parser_Int(ptr %t2250, i32 0)
  store ptr %t2251, ptr %expr_inner
  %t2252 = load ptr, ptr %p
  %t2253 = getelementptr inbounds [2 x i8], ptr @.str.s262, i64 0, i64 0
  %t2254 = getelementptr inbounds [25 x i8], ptr @.str.s263, i64 0, i64 0
  call void @parser_expect_val__Struct_Parser_Enum_TokenType_String_String(ptr %t2252, i32 6, ptr %t2253, ptr %t2254)
  %t2255 = load ptr, ptr %expr_inner
  ret ptr %t2255
label_833:
  %t2256 = load ptr, ptr %p
  %t2257 = getelementptr inbounds [2 x i8], ptr @.str.s264, i64 0, i64 0
  %t2258 = call i1 @parser_match_val__Struct_Parser_Enum_TokenType_String(ptr %t2256, i32 6, ptr %t2257)
  br i1 %t2258, label %label_834, label %label_836
label_834:
  %t2259 = call ptr @create_node__Enum_NodeKind(i32 27)
  store ptr %t2259, ptr %array_lit
  %t2260 = getelementptr inbounds [1 x i8], ptr @.str.s265, i64 0, i64 0
  store ptr %t2260, ptr %last_elem
  %t2261 = load ptr, ptr %p
  %t2262 = getelementptr inbounds [2 x i8], ptr @.str.s266, i64 0, i64 0
  %t2263 = call i1 @parser_check_val__Struct_Parser_Enum_TokenType_String(ptr %t2261, i32 6, ptr %t2262)
  %t2264 = icmp eq i1 %t2263, 0
  br i1 %t2264, label %label_837, label %label_839
label_837:
  store i1 1, ptr %is_looping
  br label %label_840
label_840:
  %t2265 = load i1, ptr %is_looping
  br i1 %t2265, label %label_841, label %label_842
label_841:
  %t2266 = load ptr, ptr %p
  %t2267 = call ptr @parse_expression__Struct_Parser_Int(ptr %t2266, i32 0)
  store ptr %t2267, ptr %elem
  %t2268 = load ptr, ptr %array_lit
  %t2269 = getelementptr inbounds %ASTNode, ptr %t2268, i32 0, i32 5
  %t2270 = load ptr, ptr %t2269
  %t2271 = getelementptr inbounds [1 x i8], ptr @.str.s267, i64 0, i64 0
  %t2272 = call i32 @str_equals(ptr %t2270, ptr %t2271)
  %t2273 = icmp eq i32 %t2272, 1
  br i1 %t2273, label %label_843, label %label_844
label_843:
  %t2274 = load ptr, ptr %array_lit
  %t2275 = load ptr, ptr %elem
  %t2276 = call ptr @node_to_ptr(ptr %t2275)
  %t2277 = getelementptr inbounds %ASTNode, ptr %t2274, i32 0, i32 5
  store ptr %t2276, ptr %t2277
  br label %label_845
label_844:
  %t2278 = load ptr, ptr %last_elem
  %t2279 = call ptr @ptr_to_node(ptr %t2278)
  store ptr %t2279, ptr %last
  %t2280 = load ptr, ptr %last
  %t2281 = load ptr, ptr %elem
  %t2282 = call ptr @node_to_ptr(ptr %t2281)
  %t2283 = getelementptr inbounds %ASTNode, ptr %t2280, i32 0, i32 8
  store ptr %t2282, ptr %t2283
  br label %label_845
label_845:
  %t2284 = load ptr, ptr %elem
  %t2285 = call ptr @node_to_ptr(ptr %t2284)
  store ptr %t2285, ptr %last_elem
  %t2286 = load ptr, ptr %p
  %t2287 = getelementptr inbounds [2 x i8], ptr @.str.s268, i64 0, i64 0
  %t2288 = call i1 @parser_match_val__Struct_Parser_Enum_TokenType_String(ptr %t2286, i32 6, ptr %t2287)
  %t2289 = icmp eq i1 %t2288, 0
  br i1 %t2289, label %label_846, label %label_848
label_846:
  store i1 0, ptr %is_looping
  br label %label_848
label_848:
  br label %label_840
label_842:
  br label %label_839
label_839:
  %t2290 = load ptr, ptr %p
  %t2291 = getelementptr inbounds [2 x i8], ptr @.str.s269, i64 0, i64 0
  %t2292 = getelementptr inbounds [14 x i8], ptr @.str.s270, i64 0, i64 0
  call void @parser_expect_val__Struct_Parser_Enum_TokenType_String_String(ptr %t2290, i32 6, ptr %t2291, ptr %t2292)
  %t2293 = load ptr, ptr %array_lit
  ret ptr %t2293
label_836:
  %t2294 = getelementptr inbounds [33 x i8], ptr @.str.s271, i64 0, i64 0
  call void @print(ptr %t2294)
  %t2295 = load ptr, ptr %curr
  %t2296 = getelementptr inbounds %Token, ptr %t2295, i32 0, i32 0
  %t2297 = load i32, ptr %t2296
  %t2298 = call ptr @type_to_string__Enum_TokenType(i32 %t2297)
  call void @print(ptr %t2298)
  %t2299 = getelementptr inbounds [3 x i8], ptr @.str.s272, i64 0, i64 0
  call void @print(ptr %t2299)
  %t2300 = load ptr, ptr %curr
  %t2301 = getelementptr inbounds %Token, ptr %t2300, i32 0, i32 1
  %t2302 = load ptr, ptr %t2301
  call void @print(ptr %t2302)
  %t2303 = getelementptr inbounds [2 x i8], ptr @.str.s273, i64 0, i64 0
  call void @println(ptr %t2303)
  call void @exit(i32 1)
  %t2304 = call ptr @create_node__Enum_NodeKind(i32 0)
  ret ptr %t2304
}

define ptr @parse_module__Struct_Parser(ptr %p_p) {
  %p = alloca ptr
  %module = alloca ptr
  %last_stmt = alloca ptr
  %is_looping = alloca i1
  %curr = alloca ptr
  %stmt = alloca ptr
  %last = alloca ptr
  store ptr %p_p, ptr %p
  %t2312 = call ptr @create_node__Enum_NodeKind(i32 0)
  store ptr %t2312, ptr %module
  %t2313 = getelementptr inbounds [1 x i8], ptr @.str.s274, i64 0, i64 0
  store ptr %t2313, ptr %last_stmt
  store i1 1, ptr %is_looping
  br label %label_849
label_849:
  %t2314 = load i1, ptr %is_looping
  br i1 %t2314, label %label_850, label %label_851
label_850:
  %t2315 = load ptr, ptr %p
  %t2316 = call ptr @parser_current__Struct_Parser(ptr %t2315)
  store ptr %t2316, ptr %curr
  %t2317 = load ptr, ptr %curr
  %t2318 = getelementptr inbounds %Token, ptr %t2317, i32 0, i32 0
  %t2319 = load i32, ptr %t2318
  %t2320 = icmp eq i32 %t2319, 20
  br i1 %t2320, label %label_852, label %label_853
label_852:
  store i1 0, ptr %is_looping
  br label %label_854
label_853:
  %t2321 = load ptr, ptr %p
  %t2322 = call ptr @parse_declaration__Struct_Parser(ptr %t2321)
  store ptr %t2322, ptr %stmt
  %t2323 = load ptr, ptr %module
  %t2324 = getelementptr inbounds %ASTNode, ptr %t2323, i32 0, i32 5
  %t2325 = load ptr, ptr %t2324
  %t2326 = getelementptr inbounds [1 x i8], ptr @.str.s275, i64 0, i64 0
  %t2327 = call i32 @str_equals(ptr %t2325, ptr %t2326)
  %t2328 = icmp eq i32 %t2327, 1
  br i1 %t2328, label %label_855, label %label_856
label_855:
  %t2329 = load ptr, ptr %module
  %t2330 = load ptr, ptr %stmt
  %t2331 = call ptr @node_to_ptr(ptr %t2330)
  %t2332 = getelementptr inbounds %ASTNode, ptr %t2329, i32 0, i32 5
  store ptr %t2331, ptr %t2332
  br label %label_857
label_856:
  %t2333 = load ptr, ptr %last_stmt
  %t2334 = call ptr @ptr_to_node(ptr %t2333)
  store ptr %t2334, ptr %last
  %t2335 = load ptr, ptr %last
  %t2336 = load ptr, ptr %stmt
  %t2337 = call ptr @node_to_ptr(ptr %t2336)
  %t2338 = getelementptr inbounds %ASTNode, ptr %t2335, i32 0, i32 8
  store ptr %t2337, ptr %t2338
  br label %label_857
label_857:
  %t2339 = load ptr, ptr %stmt
  %t2340 = call ptr @node_to_ptr(ptr %t2339)
  store ptr %t2340, ptr %last_stmt
  br label %label_854
label_854:
  br label %label_849
label_851:
  %t2341 = load ptr, ptr %module
  ret ptr %t2341
}

define ptr @type_make__Enum_TypeKind_String_String(i32 %p_kind, ptr %p_name, ptr %p_llvm) {
  %kind = alloca i32
  %name = alloca ptr
  %llvm = alloca ptr
  store i32 %p_kind, ptr %kind
  store ptr %p_name, ptr %name
  store ptr %p_llvm, ptr %llvm
  %t2345 = getelementptr %TypeInfo, ptr null, i32 1
  %t2346 = ptrtoint ptr %t2345 to i64
  %t2347 = call ptr @malloc(i64 %t2346)
  %t2348 = load i32, ptr %kind
  %t2349 = getelementptr inbounds %TypeInfo, ptr %t2347, i32 0, i32 0
  store i32 %t2348, ptr %t2349
  %t2350 = load ptr, ptr %name
  %t2351 = getelementptr inbounds %TypeInfo, ptr %t2347, i32 0, i32 1
  store ptr %t2350, ptr %t2351
  %t2352 = load ptr, ptr %llvm
  %t2353 = getelementptr inbounds %TypeInfo, ptr %t2347, i32 0, i32 2
  store ptr %t2352, ptr %t2353
  %t2354 = getelementptr inbounds [1 x i8], ptr @.str.s276, i64 0, i64 0
  %t2355 = getelementptr inbounds %TypeInfo, ptr %t2347, i32 0, i32 3
  store ptr %t2354, ptr %t2355
  %t2356 = getelementptr inbounds [1 x i8], ptr @.str.s277, i64 0, i64 0
  %t2357 = getelementptr inbounds %TypeInfo, ptr %t2347, i32 0, i32 4
  store ptr %t2356, ptr %t2357
  ret ptr %t2347
}

define ptr @type_copy__Struct_TypeInfo(ptr %p_t) {
  %t = alloca ptr
  %dup = alloca ptr
  store ptr %p_t, ptr %t
  %t2360 = load ptr, ptr %t
  %t2361 = getelementptr inbounds %TypeInfo, ptr %t2360, i32 0, i32 0
  %t2362 = load i32, ptr %t2361
  %t2363 = load ptr, ptr %t
  %t2364 = getelementptr inbounds %TypeInfo, ptr %t2363, i32 0, i32 1
  %t2365 = load ptr, ptr %t2364
  %t2366 = load ptr, ptr %t
  %t2367 = getelementptr inbounds %TypeInfo, ptr %t2366, i32 0, i32 2
  %t2368 = load ptr, ptr %t2367
  %t2369 = call ptr @type_make__Enum_TypeKind_String_String(i32 %t2362, ptr %t2365, ptr %t2368)
  store ptr %t2369, ptr %dup
  %t2370 = load ptr, ptr %dup
  %t2371 = load ptr, ptr %t
  %t2372 = getelementptr inbounds %TypeInfo, ptr %t2371, i32 0, i32 3
  %t2373 = load ptr, ptr %t2372
  %t2374 = getelementptr inbounds %TypeInfo, ptr %t2370, i32 0, i32 3
  store ptr %t2373, ptr %t2374
  %t2375 = load ptr, ptr %dup
  %t2376 = load ptr, ptr %t
  %t2377 = getelementptr inbounds %TypeInfo, ptr %t2376, i32 0, i32 4
  %t2378 = load ptr, ptr %t2377
  %t2379 = getelementptr inbounds %TypeInfo, ptr %t2375, i32 0, i32 4
  store ptr %t2378, ptr %t2379
  %t2380 = load ptr, ptr %dup
  ret ptr %t2380
}

define ptr @type_invalid__Void() {
  %t2381 = getelementptr inbounds [8 x i8], ptr @.str.s278, i64 0, i64 0
  %t2382 = getelementptr inbounds [1 x i8], ptr @.str.s279, i64 0, i64 0
  %t2383 = call ptr @type_make__Enum_TypeKind_String_String(i32 0, ptr %t2381, ptr %t2382)
  ret ptr %t2383
}

define ptr @type_void__Void() {
  %t2384 = getelementptr inbounds [5 x i8], ptr @.str.s280, i64 0, i64 0
  %t2385 = getelementptr inbounds [5 x i8], ptr @.str.s281, i64 0, i64 0
  %t2386 = call ptr @type_make__Enum_TypeKind_String_String(i32 1, ptr %t2384, ptr %t2385)
  ret ptr %t2386
}

define ptr @type_int__Void() {
  %t2387 = getelementptr inbounds [4 x i8], ptr @.str.s282, i64 0, i64 0
  %t2388 = getelementptr inbounds [4 x i8], ptr @.str.s283, i64 0, i64 0
  %t2389 = call ptr @type_make__Enum_TypeKind_String_String(i32 2, ptr %t2387, ptr %t2388)
  ret ptr %t2389
}

define ptr @type_float__Void() {
  %t2390 = getelementptr inbounds [6 x i8], ptr @.str.s284, i64 0, i64 0
  %t2391 = getelementptr inbounds [7 x i8], ptr @.str.s285, i64 0, i64 0
  %t2392 = call ptr @type_make__Enum_TypeKind_String_String(i32 3, ptr %t2390, ptr %t2391)
  ret ptr %t2392
}

define ptr @type_bool__Void() {
  %t2393 = getelementptr inbounds [5 x i8], ptr @.str.s286, i64 0, i64 0
  %t2394 = getelementptr inbounds [3 x i8], ptr @.str.s287, i64 0, i64 0
  %t2395 = call ptr @type_make__Enum_TypeKind_String_String(i32 4, ptr %t2393, ptr %t2394)
  ret ptr %t2395
}

define ptr @type_char__Void() {
  %t2396 = getelementptr inbounds [5 x i8], ptr @.str.s288, i64 0, i64 0
  %t2397 = getelementptr inbounds [3 x i8], ptr @.str.s289, i64 0, i64 0
  %t2398 = call ptr @type_make__Enum_TypeKind_String_String(i32 5, ptr %t2396, ptr %t2397)
  ret ptr %t2398
}

define ptr @type_string__Void() {
  %t2399 = getelementptr inbounds [7 x i8], ptr @.str.s290, i64 0, i64 0
  %t2400 = getelementptr inbounds [4 x i8], ptr @.str.s291, i64 0, i64 0
  %t2401 = call ptr @type_make__Enum_TypeKind_String_String(i32 6, ptr %t2399, ptr %t2400)
  ret ptr %t2401
}

define ptr @type_ptr__Void() {
  %t2402 = getelementptr inbounds [4 x i8], ptr @.str.s292, i64 0, i64 0
  %t2403 = getelementptr inbounds [4 x i8], ptr @.str.s293, i64 0, i64 0
  %t2404 = call ptr @type_make__Enum_TypeKind_String_String(i32 7, ptr %t2402, ptr %t2403)
  ret ptr %t2404
}

define ptr @type_i8__Void() {
  %t2405 = getelementptr inbounds [3 x i8], ptr @.str.s294, i64 0, i64 0
  %t2406 = getelementptr inbounds [3 x i8], ptr @.str.s295, i64 0, i64 0
  %t2407 = call ptr @type_make__Enum_TypeKind_String_String(i32 2, ptr %t2405, ptr %t2406)
  ret ptr %t2407
}

define ptr @type_i16__Void() {
  %t2408 = getelementptr inbounds [4 x i8], ptr @.str.s296, i64 0, i64 0
  %t2409 = getelementptr inbounds [4 x i8], ptr @.str.s297, i64 0, i64 0
  %t2410 = call ptr @type_make__Enum_TypeKind_String_String(i32 2, ptr %t2408, ptr %t2409)
  ret ptr %t2410
}

define ptr @type_i64__Void() {
  %t2411 = getelementptr inbounds [4 x i8], ptr @.str.s298, i64 0, i64 0
  %t2412 = getelementptr inbounds [4 x i8], ptr @.str.s299, i64 0, i64 0
  %t2413 = call ptr @type_make__Enum_TypeKind_String_String(i32 2, ptr %t2411, ptr %t2412)
  ret ptr %t2413
}

define ptr @type_isize__Void() {
  %t2414 = getelementptr inbounds [6 x i8], ptr @.str.s300, i64 0, i64 0
  %t2415 = getelementptr inbounds [4 x i8], ptr @.str.s301, i64 0, i64 0
  %t2416 = call ptr @type_make__Enum_TypeKind_String_String(i32 2, ptr %t2414, ptr %t2415)
  ret ptr %t2416
}

define ptr @type_u8__Void() {
  %t2417 = getelementptr inbounds [3 x i8], ptr @.str.s302, i64 0, i64 0
  %t2418 = getelementptr inbounds [3 x i8], ptr @.str.s303, i64 0, i64 0
  %t2419 = call ptr @type_make__Enum_TypeKind_String_String(i32 2, ptr %t2417, ptr %t2418)
  ret ptr %t2419
}

define ptr @type_u16__Void() {
  %t2420 = getelementptr inbounds [4 x i8], ptr @.str.s304, i64 0, i64 0
  %t2421 = getelementptr inbounds [4 x i8], ptr @.str.s305, i64 0, i64 0
  %t2422 = call ptr @type_make__Enum_TypeKind_String_String(i32 2, ptr %t2420, ptr %t2421)
  ret ptr %t2422
}

define ptr @type_u32__Void() {
  %t2423 = getelementptr inbounds [4 x i8], ptr @.str.s306, i64 0, i64 0
  %t2424 = getelementptr inbounds [4 x i8], ptr @.str.s307, i64 0, i64 0
  %t2425 = call ptr @type_make__Enum_TypeKind_String_String(i32 2, ptr %t2423, ptr %t2424)
  ret ptr %t2425
}

define ptr @type_u64__Void() {
  %t2426 = getelementptr inbounds [4 x i8], ptr @.str.s308, i64 0, i64 0
  %t2427 = getelementptr inbounds [4 x i8], ptr @.str.s309, i64 0, i64 0
  %t2428 = call ptr @type_make__Enum_TypeKind_String_String(i32 2, ptr %t2426, ptr %t2427)
  ret ptr %t2428
}

define ptr @type_usize__Void() {
  %t2429 = getelementptr inbounds [6 x i8], ptr @.str.s310, i64 0, i64 0
  %t2430 = getelementptr inbounds [4 x i8], ptr @.str.s311, i64 0, i64 0
  %t2431 = call ptr @type_make__Enum_TypeKind_String_String(i32 2, ptr %t2429, ptr %t2430)
  ret ptr %t2431
}

define i1 @type_int_is_unsigned__Struct_TypeInfo(ptr %p_t) {
  %t = alloca ptr
  store ptr %p_t, ptr %t
  %t2433 = load ptr, ptr %t
  %t2434 = getelementptr inbounds %TypeInfo, ptr %t2433, i32 0, i32 0
  %t2435 = load i32, ptr %t2434
  %t2436 = icmp ne i32 %t2435, 2
  br i1 %t2436, label %label_858, label %label_860
label_858:
  ret i1 0
label_860:
  %t2437 = load ptr, ptr %t
  %t2438 = getelementptr inbounds %TypeInfo, ptr %t2437, i32 0, i32 1
  %t2439 = load ptr, ptr %t2438
  %t2440 = getelementptr inbounds [2 x i8], ptr @.str.s312, i64 0, i64 0
  %t2441 = call i32 @str_starts_with(ptr %t2439, ptr %t2440)
  %t2442 = icmp eq i32 %t2441, 1
  ret i1 %t2442
}

define i1 @type_is_move_only__Struct_TypeInfo(ptr %p_t) {
  %t = alloca ptr
  store ptr %p_t, ptr %t
  %t2444 = load ptr, ptr %t
  %t2445 = getelementptr inbounds %TypeInfo, ptr %t2444, i32 0, i32 0
  %t2446 = load i32, ptr %t2445
  %t2447 = icmp eq i32 %t2446, 8
  ret i1 %t2447
}

define ptr @type_struct__String(ptr %p_name) {
  %name = alloca ptr
  store ptr %p_name, ptr %name
  %t2449 = load ptr, ptr %name
  %t2450 = getelementptr inbounds [4 x i8], ptr @.str.s313, i64 0, i64 0
  %t2451 = call ptr @type_make__Enum_TypeKind_String_String(i32 8, ptr %t2449, ptr %t2450)
  ret ptr %t2451
}

define ptr @type_enum__String(ptr %p_name) {
  %name = alloca ptr
  store ptr %p_name, ptr %name
  %t2453 = load ptr, ptr %name
  %t2454 = getelementptr inbounds [4 x i8], ptr @.str.s314, i64 0, i64 0
  %t2455 = call ptr @type_make__Enum_TypeKind_String_String(i32 9, ptr %t2453, ptr %t2454)
  ret ptr %t2455
}

define ptr @type_array__Struct_TypeInfo(ptr %p_elem) {
  %elem = alloca ptr
  %t = alloca ptr
  store ptr %p_elem, ptr %elem
  %t2458 = getelementptr inbounds [6 x i8], ptr @.str.s315, i64 0, i64 0
  %t2459 = getelementptr inbounds [4 x i8], ptr @.str.s316, i64 0, i64 0
  %t2460 = call ptr @type_make__Enum_TypeKind_String_String(i32 10, ptr %t2458, ptr %t2459)
  store ptr %t2460, ptr %t
  %t2461 = load ptr, ptr %t
  %t2462 = load ptr, ptr %elem
  %t2463 = call ptr @type_to_ptr(ptr %t2462)
  %t2464 = getelementptr inbounds %TypeInfo, ptr %t2461, i32 0, i32 3
  store ptr %t2463, ptr %t2464
  %t2465 = load ptr, ptr %t
  ret ptr %t2465
}

define ptr @type_list__Struct_TypeInfo(ptr %p_elem) {
  %elem = alloca ptr
  %t = alloca ptr
  store ptr %p_elem, ptr %elem
  %t2468 = getelementptr inbounds [5 x i8], ptr @.str.s317, i64 0, i64 0
  %t2469 = getelementptr inbounds [4 x i8], ptr @.str.s318, i64 0, i64 0
  %t2470 = call ptr @type_make__Enum_TypeKind_String_String(i32 11, ptr %t2468, ptr %t2469)
  store ptr %t2470, ptr %t
  %t2471 = load ptr, ptr %t
  %t2472 = load ptr, ptr %elem
  %t2473 = call ptr @type_to_ptr(ptr %t2472)
  %t2474 = getelementptr inbounds %TypeInfo, ptr %t2471, i32 0, i32 3
  store ptr %t2473, ptr %t2474
  %t2475 = load ptr, ptr %t
  ret ptr %t2475
}

define i1 @type_is_valid__Struct_TypeInfo(ptr %p_t) {
  %t = alloca ptr
  store ptr %p_t, ptr %t
  %t2477 = load ptr, ptr %t
  %t2478 = getelementptr inbounds %TypeInfo, ptr %t2477, i32 0, i32 0
  %t2479 = load i32, ptr %t2478
  %t2480 = icmp ne i32 %t2479, 0
  ret i1 %t2480
}

define ptr @type_display__Struct_TypeInfo(ptr %p_t) {
  %t = alloca ptr
  store ptr %p_t, ptr %t
  %t2482 = load ptr, ptr %t
  %t2483 = getelementptr inbounds %TypeInfo, ptr %t2482, i32 0, i32 0
  %t2484 = load i32, ptr %t2483
  %t2485 = icmp eq i32 %t2484, 8
  br i1 %t2485, label %label_861, label %label_863
label_861:
  %t2486 = load ptr, ptr %t
  %t2487 = getelementptr inbounds %TypeInfo, ptr %t2486, i32 0, i32 1
  %t2488 = load ptr, ptr %t2487
  ret ptr %t2488
label_863:
  %t2489 = load ptr, ptr %t
  %t2490 = getelementptr inbounds %TypeInfo, ptr %t2489, i32 0, i32 0
  %t2491 = load i32, ptr %t2490
  %t2492 = icmp eq i32 %t2491, 9
  br i1 %t2492, label %label_864, label %label_866
label_864:
  %t2493 = load ptr, ptr %t
  %t2494 = getelementptr inbounds %TypeInfo, ptr %t2493, i32 0, i32 1
  %t2495 = load ptr, ptr %t2494
  ret ptr %t2495
label_866:
  %t2496 = load ptr, ptr %t
  %t2497 = getelementptr inbounds %TypeInfo, ptr %t2496, i32 0, i32 0
  %t2498 = load i32, ptr %t2497
  %t2499 = icmp eq i32 %t2498, 10
  br i1 %t2499, label %label_867, label %label_869
label_867:
  %t2500 = load ptr, ptr %t
  %t2501 = getelementptr inbounds %TypeInfo, ptr %t2500, i32 0, i32 3
  %t2502 = load ptr, ptr %t2501
  %t2503 = getelementptr inbounds [1 x i8], ptr @.str.s319, i64 0, i64 0
  %t2504 = call i32 @str_equals(ptr %t2502, ptr %t2503)
  %t2505 = icmp eq i32 %t2504, 0
  br i1 %t2505, label %label_870, label %label_872
label_870:
  %t2506 = getelementptr inbounds [2 x i8], ptr @.str.s320, i64 0, i64 0
  %t2507 = load ptr, ptr %t
  %t2508 = getelementptr inbounds %TypeInfo, ptr %t2507, i32 0, i32 3
  %t2509 = load ptr, ptr %t2508
  %t2510 = call ptr @ptr_to_type(ptr %t2509)
  %t2511 = call ptr @type_display__Struct_TypeInfo(ptr %t2510)
  %t2512 = call ptr @str_concat(ptr %t2506, ptr %t2511)
  %t2513 = getelementptr inbounds [2 x i8], ptr @.str.s321, i64 0, i64 0
  %t2514 = call ptr @str_concat(ptr %t2512, ptr %t2513)
  ret ptr %t2514
label_872:
  %t2515 = getelementptr inbounds [10 x i8], ptr @.str.s322, i64 0, i64 0
  ret ptr %t2515
label_869:
  %t2516 = load ptr, ptr %t
  %t2517 = getelementptr inbounds %TypeInfo, ptr %t2516, i32 0, i32 0
  %t2518 = load i32, ptr %t2517
  %t2519 = icmp eq i32 %t2518, 11
  br i1 %t2519, label %label_873, label %label_875
label_873:
  %t2520 = load ptr, ptr %t
  %t2521 = getelementptr inbounds %TypeInfo, ptr %t2520, i32 0, i32 3
  %t2522 = load ptr, ptr %t2521
  %t2523 = getelementptr inbounds [1 x i8], ptr @.str.s323, i64 0, i64 0
  %t2524 = call i32 @str_equals(ptr %t2522, ptr %t2523)
  %t2525 = icmp eq i32 %t2524, 0
  br i1 %t2525, label %label_876, label %label_878
label_876:
  %t2526 = getelementptr inbounds [6 x i8], ptr @.str.s324, i64 0, i64 0
  %t2527 = load ptr, ptr %t
  %t2528 = getelementptr inbounds %TypeInfo, ptr %t2527, i32 0, i32 3
  %t2529 = load ptr, ptr %t2528
  %t2530 = call ptr @ptr_to_type(ptr %t2529)
  %t2531 = call ptr @type_display__Struct_TypeInfo(ptr %t2530)
  %t2532 = call ptr @str_concat(ptr %t2526, ptr %t2531)
  %t2533 = getelementptr inbounds [2 x i8], ptr @.str.s325, i64 0, i64 0
  %t2534 = call ptr @str_concat(ptr %t2532, ptr %t2533)
  ret ptr %t2534
label_878:
  %t2535 = getelementptr inbounds [5 x i8], ptr @.str.s326, i64 0, i64 0
  ret ptr %t2535
label_875:
  %t2536 = load ptr, ptr %t
  %t2537 = getelementptr inbounds %TypeInfo, ptr %t2536, i32 0, i32 1
  %t2538 = load ptr, ptr %t2537
  ret ptr %t2538
}

define i1 @type_equals__Struct_TypeInfo_Struct_TypeInfo(ptr %p_a, ptr %p_b) {
  %a = alloca ptr
  %b = alloca ptr
  %ac = alloca ptr
  %bc = alloca ptr
  store ptr %p_a, ptr %a
  store ptr %p_b, ptr %b
  %t2543 = load ptr, ptr %a
  %t2544 = getelementptr inbounds %TypeInfo, ptr %t2543, i32 0, i32 0
  %t2545 = load i32, ptr %t2544
  %t2546 = load ptr, ptr %b
  %t2547 = getelementptr inbounds %TypeInfo, ptr %t2546, i32 0, i32 0
  %t2548 = load i32, ptr %t2547
  %t2549 = icmp ne i32 %t2545, %t2548
  br i1 %t2549, label %label_879, label %label_881
label_879:
  ret i1 0
label_881:
  %t2550 = load ptr, ptr %a
  %t2551 = getelementptr inbounds %TypeInfo, ptr %t2550, i32 0, i32 0
  %t2552 = load i32, ptr %t2551
  %t2553 = icmp eq i32 %t2552, 8
  %t2554 = load ptr, ptr %a
  %t2555 = getelementptr inbounds %TypeInfo, ptr %t2554, i32 0, i32 0
  %t2556 = load i32, ptr %t2555
  %t2557 = icmp eq i32 %t2556, 9
  %t2558 = or i1 %t2553, %t2557
  br i1 %t2558, label %label_882, label %label_884
label_882:
  %t2559 = load ptr, ptr %a
  %t2560 = getelementptr inbounds %TypeInfo, ptr %t2559, i32 0, i32 1
  %t2561 = load ptr, ptr %t2560
  %t2562 = load ptr, ptr %b
  %t2563 = getelementptr inbounds %TypeInfo, ptr %t2562, i32 0, i32 1
  %t2564 = load ptr, ptr %t2563
  %t2565 = call i32 @str_equals(ptr %t2561, ptr %t2564)
  %t2566 = icmp eq i32 %t2565, 1
  ret i1 %t2566
label_884:
  %t2567 = load ptr, ptr %a
  %t2568 = getelementptr inbounds %TypeInfo, ptr %t2567, i32 0, i32 0
  %t2569 = load i32, ptr %t2568
  %t2570 = icmp eq i32 %t2569, 2
  br i1 %t2570, label %label_885, label %label_887
label_885:
  %t2571 = load ptr, ptr %a
  %t2572 = getelementptr inbounds %TypeInfo, ptr %t2571, i32 0, i32 1
  %t2573 = load ptr, ptr %t2572
  %t2574 = load ptr, ptr %b
  %t2575 = getelementptr inbounds %TypeInfo, ptr %t2574, i32 0, i32 1
  %t2576 = load ptr, ptr %t2575
  %t2577 = call i32 @str_equals(ptr %t2573, ptr %t2576)
  %t2578 = icmp eq i32 %t2577, 1
  ret i1 %t2578
label_887:
  %t2579 = load ptr, ptr %a
  %t2580 = getelementptr inbounds %TypeInfo, ptr %t2579, i32 0, i32 0
  %t2581 = load i32, ptr %t2580
  %t2582 = icmp eq i32 %t2581, 10
  br i1 %t2582, label %label_888, label %label_890
label_888:
  %t2583 = load ptr, ptr %a
  %t2584 = getelementptr inbounds %TypeInfo, ptr %t2583, i32 0, i32 3
  %t2585 = load ptr, ptr %t2584
  %t2586 = getelementptr inbounds [1 x i8], ptr @.str.s327, i64 0, i64 0
  %t2587 = call i32 @str_equals(ptr %t2585, ptr %t2586)
  %t2588 = icmp eq i32 %t2587, 1
  %t2589 = load ptr, ptr %b
  %t2590 = getelementptr inbounds %TypeInfo, ptr %t2589, i32 0, i32 3
  %t2591 = load ptr, ptr %t2590
  %t2592 = getelementptr inbounds [1 x i8], ptr @.str.s328, i64 0, i64 0
  %t2593 = call i32 @str_equals(ptr %t2591, ptr %t2592)
  %t2594 = icmp eq i32 %t2593, 1
  %t2595 = or i1 %t2588, %t2594
  br i1 %t2595, label %label_891, label %label_893
label_891:
  %t2596 = load ptr, ptr %a
  %t2597 = getelementptr inbounds %TypeInfo, ptr %t2596, i32 0, i32 3
  %t2598 = load ptr, ptr %t2597
  %t2599 = load ptr, ptr %b
  %t2600 = getelementptr inbounds %TypeInfo, ptr %t2599, i32 0, i32 3
  %t2601 = load ptr, ptr %t2600
  %t2602 = call i32 @str_equals(ptr %t2598, ptr %t2601)
  %t2603 = icmp eq i32 %t2602, 1
  ret i1 %t2603
label_893:
  %t2604 = load ptr, ptr %a
  %t2605 = getelementptr inbounds %TypeInfo, ptr %t2604, i32 0, i32 3
  %t2606 = load ptr, ptr %t2605
  %t2607 = call ptr @ptr_to_type(ptr %t2606)
  %t2608 = load ptr, ptr %b
  %t2609 = getelementptr inbounds %TypeInfo, ptr %t2608, i32 0, i32 3
  %t2610 = load ptr, ptr %t2609
  %t2611 = call ptr @ptr_to_type(ptr %t2610)
  %t2612 = call i1 @type_equals__Struct_TypeInfo_Struct_TypeInfo(ptr %t2607, ptr %t2611)
  ret i1 %t2612
label_890:
  %t2613 = load ptr, ptr %a
  %t2614 = getelementptr inbounds %TypeInfo, ptr %t2613, i32 0, i32 0
  %t2615 = load i32, ptr %t2614
  %t2616 = icmp eq i32 %t2615, 11
  br i1 %t2616, label %label_894, label %label_896
label_894:
  %t2617 = load ptr, ptr %a
  %t2618 = getelementptr inbounds %TypeInfo, ptr %t2617, i32 0, i32 3
  %t2619 = load ptr, ptr %t2618
  %t2620 = getelementptr inbounds [1 x i8], ptr @.str.s329, i64 0, i64 0
  %t2621 = call i32 @str_equals(ptr %t2619, ptr %t2620)
  %t2622 = icmp eq i32 %t2621, 1
  %t2623 = load ptr, ptr %b
  %t2624 = getelementptr inbounds %TypeInfo, ptr %t2623, i32 0, i32 3
  %t2625 = load ptr, ptr %t2624
  %t2626 = getelementptr inbounds [1 x i8], ptr @.str.s330, i64 0, i64 0
  %t2627 = call i32 @str_equals(ptr %t2625, ptr %t2626)
  %t2628 = icmp eq i32 %t2627, 1
  %t2629 = or i1 %t2622, %t2628
  br i1 %t2629, label %label_897, label %label_899
label_897:
  ret i1 1
label_899:
  %t2630 = load ptr, ptr %a
  %t2631 = getelementptr inbounds %TypeInfo, ptr %t2630, i32 0, i32 3
  %t2632 = load ptr, ptr %t2631
  %t2633 = call ptr @ptr_to_type(ptr %t2632)
  store ptr %t2633, ptr %ac
  %t2634 = load ptr, ptr %b
  %t2635 = getelementptr inbounds %TypeInfo, ptr %t2634, i32 0, i32 3
  %t2636 = load ptr, ptr %t2635
  %t2637 = call ptr @ptr_to_type(ptr %t2636)
  store ptr %t2637, ptr %bc
  %t2638 = load ptr, ptr %ac
  %t2639 = call i1 @type_is_valid__Struct_TypeInfo(ptr %t2638)
  %t2640 = icmp eq i1 %t2639, 0
  %t2641 = load ptr, ptr %bc
  %t2642 = call i1 @type_is_valid__Struct_TypeInfo(ptr %t2641)
  %t2643 = icmp eq i1 %t2642, 0
  %t2644 = or i1 %t2640, %t2643
  br i1 %t2644, label %label_900, label %label_902
label_900:
  ret i1 1
label_902:
  %t2645 = load ptr, ptr %ac
  %t2646 = load ptr, ptr %bc
  %t2647 = call i1 @type_equals__Struct_TypeInfo_Struct_TypeInfo(ptr %t2645, ptr %t2646)
  ret i1 %t2647
label_896:
  ret i1 1
}

define i1 @type_is_numeric__Struct_TypeInfo(ptr %p_t) {
  %t = alloca ptr
  store ptr %p_t, ptr %t
  %t2649 = load ptr, ptr %t
  %t2650 = getelementptr inbounds %TypeInfo, ptr %t2649, i32 0, i32 0
  %t2651 = load i32, ptr %t2650
  %t2652 = icmp eq i32 %t2651, 2
  %t2653 = load ptr, ptr %t
  %t2654 = getelementptr inbounds %TypeInfo, ptr %t2653, i32 0, i32 0
  %t2655 = load i32, ptr %t2654
  %t2656 = icmp eq i32 %t2655, 3
  %t2657 = or i1 %t2652, %t2656
  ret i1 %t2657
}

define ptr @type_ir_key__Struct_TypeInfo(ptr %p_t) {
  %t = alloca ptr
  %elem = alloca ptr
  store ptr %p_t, ptr %t
  %t2660 = load ptr, ptr %t
  %t2661 = getelementptr inbounds %TypeInfo, ptr %t2660, i32 0, i32 0
  %t2662 = load i32, ptr %t2661
  %t2663 = icmp eq i32 %t2662, 1
  br i1 %t2663, label %label_903, label %label_905
label_903:
  %t2664 = getelementptr inbounds [5 x i8], ptr @.str.s331, i64 0, i64 0
  ret ptr %t2664
label_905:
  %t2665 = load ptr, ptr %t
  %t2666 = getelementptr inbounds %TypeInfo, ptr %t2665, i32 0, i32 0
  %t2667 = load i32, ptr %t2666
  %t2668 = icmp eq i32 %t2667, 2
  br i1 %t2668, label %label_906, label %label_908
label_906:
  %t2669 = load ptr, ptr %t
  %t2670 = getelementptr inbounds %TypeInfo, ptr %t2669, i32 0, i32 2
  %t2671 = load ptr, ptr %t2670
  ret ptr %t2671
label_908:
  %t2672 = load ptr, ptr %t
  %t2673 = getelementptr inbounds %TypeInfo, ptr %t2672, i32 0, i32 0
  %t2674 = load i32, ptr %t2673
  %t2675 = icmp eq i32 %t2674, 3
  br i1 %t2675, label %label_909, label %label_911
label_909:
  %t2676 = getelementptr inbounds [7 x i8], ptr @.str.s332, i64 0, i64 0
  ret ptr %t2676
label_911:
  %t2677 = load ptr, ptr %t
  %t2678 = getelementptr inbounds %TypeInfo, ptr %t2677, i32 0, i32 0
  %t2679 = load i32, ptr %t2678
  %t2680 = icmp eq i32 %t2679, 4
  br i1 %t2680, label %label_912, label %label_914
label_912:
  %t2681 = getelementptr inbounds [3 x i8], ptr @.str.s333, i64 0, i64 0
  ret ptr %t2681
label_914:
  %t2682 = load ptr, ptr %t
  %t2683 = getelementptr inbounds %TypeInfo, ptr %t2682, i32 0, i32 0
  %t2684 = load i32, ptr %t2683
  %t2685 = icmp eq i32 %t2684, 5
  br i1 %t2685, label %label_915, label %label_917
label_915:
  %t2686 = getelementptr inbounds [3 x i8], ptr @.str.s334, i64 0, i64 0
  ret ptr %t2686
label_917:
  %t2687 = load ptr, ptr %t
  %t2688 = getelementptr inbounds %TypeInfo, ptr %t2687, i32 0, i32 0
  %t2689 = load i32, ptr %t2688
  %t2690 = icmp eq i32 %t2689, 6
  br i1 %t2690, label %label_918, label %label_920
label_918:
  %t2691 = getelementptr inbounds [4 x i8], ptr @.str.s335, i64 0, i64 0
  ret ptr %t2691
label_920:
  %t2692 = load ptr, ptr %t
  %t2693 = getelementptr inbounds %TypeInfo, ptr %t2692, i32 0, i32 0
  %t2694 = load i32, ptr %t2693
  %t2695 = icmp eq i32 %t2694, 7
  br i1 %t2695, label %label_921, label %label_923
label_921:
  %t2696 = getelementptr inbounds [4 x i8], ptr @.str.s336, i64 0, i64 0
  ret ptr %t2696
label_923:
  %t2697 = load ptr, ptr %t
  %t2698 = getelementptr inbounds %TypeInfo, ptr %t2697, i32 0, i32 0
  %t2699 = load i32, ptr %t2698
  %t2700 = icmp eq i32 %t2699, 9
  br i1 %t2700, label %label_924, label %label_926
label_924:
  %t2701 = getelementptr inbounds [4 x i8], ptr @.str.s337, i64 0, i64 0
  ret ptr %t2701
label_926:
  %t2702 = load ptr, ptr %t
  %t2703 = getelementptr inbounds %TypeInfo, ptr %t2702, i32 0, i32 0
  %t2704 = load i32, ptr %t2703
  %t2705 = icmp eq i32 %t2704, 8
  br i1 %t2705, label %label_927, label %label_929
label_927:
  %t2706 = getelementptr inbounds [8 x i8], ptr @.str.s338, i64 0, i64 0
  %t2707 = load ptr, ptr %t
  %t2708 = getelementptr inbounds %TypeInfo, ptr %t2707, i32 0, i32 1
  %t2709 = load ptr, ptr %t2708
  %t2710 = call ptr @str_concat(ptr %t2706, ptr %t2709)
  ret ptr %t2710
label_929:
  %t2711 = load ptr, ptr %t
  %t2712 = getelementptr inbounds %TypeInfo, ptr %t2711, i32 0, i32 0
  %t2713 = load i32, ptr %t2712
  %t2714 = icmp eq i32 %t2713, 11
  br i1 %t2714, label %label_930, label %label_932
label_930:
  %t2715 = getelementptr inbounds [4 x i8], ptr @.str.s339, i64 0, i64 0
  ret ptr %t2715
label_932:
  %t2716 = load ptr, ptr %t
  %t2717 = getelementptr inbounds %TypeInfo, ptr %t2716, i32 0, i32 0
  %t2718 = load i32, ptr %t2717
  %t2719 = icmp eq i32 %t2718, 10
  br i1 %t2719, label %label_933, label %label_935
label_933:
  %t2720 = load ptr, ptr %t
  %t2721 = getelementptr inbounds %TypeInfo, ptr %t2720, i32 0, i32 3
  %t2722 = load ptr, ptr %t2721
  %t2723 = getelementptr inbounds [1 x i8], ptr @.str.s340, i64 0, i64 0
  %t2724 = call i32 @str_equals(ptr %t2722, ptr %t2723)
  %t2725 = icmp eq i32 %t2724, 0
  br i1 %t2725, label %label_936, label %label_938
label_936:
  %t2726 = load ptr, ptr %t
  %t2727 = getelementptr inbounds %TypeInfo, ptr %t2726, i32 0, i32 3
  %t2728 = load ptr, ptr %t2727
  %t2729 = call ptr @ptr_to_type(ptr %t2728)
  store ptr %t2729, ptr %elem
  %t2730 = load ptr, ptr %elem
  %t2731 = getelementptr inbounds %TypeInfo, ptr %t2730, i32 0, i32 0
  %t2732 = load i32, ptr %t2731
  %t2733 = icmp eq i32 %t2732, 10
  br i1 %t2733, label %label_939, label %label_941
label_939:
  %t2734 = getelementptr inbounds [7 x i8], ptr @.str.s341, i64 0, i64 0
  ret ptr %t2734
label_941:
  br label %label_938
label_938:
  %t2735 = getelementptr inbounds [4 x i8], ptr @.str.s342, i64 0, i64 0
  ret ptr %t2735
label_935:
  %t2736 = getelementptr inbounds [1 x i8], ptr @.str.s343, i64 0, i64 0
  ret ptr %t2736
}

define ptr @type_sem_key__Struct_TypeInfo(ptr %p_t) {
  %t = alloca ptr
  store ptr %p_t, ptr %t
  %t2738 = load ptr, ptr %t
  %t2739 = getelementptr inbounds %TypeInfo, ptr %t2738, i32 0, i32 0
  %t2740 = load i32, ptr %t2739
  %t2741 = icmp eq i32 %t2740, 1
  br i1 %t2741, label %label_942, label %label_944
label_942:
  %t2742 = getelementptr inbounds [5 x i8], ptr @.str.s344, i64 0, i64 0
  ret ptr %t2742
label_944:
  %t2743 = load ptr, ptr %t
  %t2744 = getelementptr inbounds %TypeInfo, ptr %t2743, i32 0, i32 0
  %t2745 = load i32, ptr %t2744
  %t2746 = icmp eq i32 %t2745, 2
  br i1 %t2746, label %label_945, label %label_947
label_945:
  %t2747 = load ptr, ptr %t
  %t2748 = getelementptr inbounds %TypeInfo, ptr %t2747, i32 0, i32 1
  %t2749 = load ptr, ptr %t2748
  ret ptr %t2749
label_947:
  %t2750 = load ptr, ptr %t
  %t2751 = getelementptr inbounds %TypeInfo, ptr %t2750, i32 0, i32 0
  %t2752 = load i32, ptr %t2751
  %t2753 = icmp eq i32 %t2752, 3
  br i1 %t2753, label %label_948, label %label_950
label_948:
  %t2754 = getelementptr inbounds [6 x i8], ptr @.str.s345, i64 0, i64 0
  ret ptr %t2754
label_950:
  %t2755 = load ptr, ptr %t
  %t2756 = getelementptr inbounds %TypeInfo, ptr %t2755, i32 0, i32 0
  %t2757 = load i32, ptr %t2756
  %t2758 = icmp eq i32 %t2757, 4
  br i1 %t2758, label %label_951, label %label_953
label_951:
  %t2759 = getelementptr inbounds [5 x i8], ptr @.str.s346, i64 0, i64 0
  ret ptr %t2759
label_953:
  %t2760 = load ptr, ptr %t
  %t2761 = getelementptr inbounds %TypeInfo, ptr %t2760, i32 0, i32 0
  %t2762 = load i32, ptr %t2761
  %t2763 = icmp eq i32 %t2762, 5
  br i1 %t2763, label %label_954, label %label_956
label_954:
  %t2764 = getelementptr inbounds [5 x i8], ptr @.str.s347, i64 0, i64 0
  ret ptr %t2764
label_956:
  %t2765 = load ptr, ptr %t
  %t2766 = getelementptr inbounds %TypeInfo, ptr %t2765, i32 0, i32 0
  %t2767 = load i32, ptr %t2766
  %t2768 = icmp eq i32 %t2767, 6
  br i1 %t2768, label %label_957, label %label_959
label_957:
  %t2769 = getelementptr inbounds [7 x i8], ptr @.str.s348, i64 0, i64 0
  ret ptr %t2769
label_959:
  %t2770 = load ptr, ptr %t
  %t2771 = getelementptr inbounds %TypeInfo, ptr %t2770, i32 0, i32 0
  %t2772 = load i32, ptr %t2771
  %t2773 = icmp eq i32 %t2772, 7
  br i1 %t2773, label %label_960, label %label_962
label_960:
  %t2774 = getelementptr inbounds [4 x i8], ptr @.str.s349, i64 0, i64 0
  ret ptr %t2774
label_962:
  %t2775 = load ptr, ptr %t
  %t2776 = getelementptr inbounds %TypeInfo, ptr %t2775, i32 0, i32 0
  %t2777 = load i32, ptr %t2776
  %t2778 = icmp eq i32 %t2777, 8
  br i1 %t2778, label %label_963, label %label_965
label_963:
  %t2779 = getelementptr inbounds [8 x i8], ptr @.str.s350, i64 0, i64 0
  %t2780 = load ptr, ptr %t
  %t2781 = getelementptr inbounds %TypeInfo, ptr %t2780, i32 0, i32 1
  %t2782 = load ptr, ptr %t2781
  %t2783 = call ptr @str_concat(ptr %t2779, ptr %t2782)
  ret ptr %t2783
label_965:
  %t2784 = load ptr, ptr %t
  %t2785 = getelementptr inbounds %TypeInfo, ptr %t2784, i32 0, i32 0
  %t2786 = load i32, ptr %t2785
  %t2787 = icmp eq i32 %t2786, 9
  br i1 %t2787, label %label_966, label %label_968
label_966:
  %t2788 = getelementptr inbounds [6 x i8], ptr @.str.s351, i64 0, i64 0
  %t2789 = load ptr, ptr %t
  %t2790 = getelementptr inbounds %TypeInfo, ptr %t2789, i32 0, i32 1
  %t2791 = load ptr, ptr %t2790
  %t2792 = call ptr @str_concat(ptr %t2788, ptr %t2791)
  ret ptr %t2792
label_968:
  %t2793 = load ptr, ptr %t
  %t2794 = getelementptr inbounds %TypeInfo, ptr %t2793, i32 0, i32 0
  %t2795 = load i32, ptr %t2794
  %t2796 = icmp eq i32 %t2795, 10
  br i1 %t2796, label %label_969, label %label_971
label_969:
  %t2797 = load ptr, ptr %t
  %t2798 = getelementptr inbounds %TypeInfo, ptr %t2797, i32 0, i32 3
  %t2799 = load ptr, ptr %t2798
  %t2800 = getelementptr inbounds [1 x i8], ptr @.str.s352, i64 0, i64 0
  %t2801 = call i32 @str_equals(ptr %t2799, ptr %t2800)
  %t2802 = icmp eq i32 %t2801, 0
  br i1 %t2802, label %label_972, label %label_974
label_972:
  %t2803 = getelementptr inbounds [7 x i8], ptr @.str.s353, i64 0, i64 0
  %t2804 = load ptr, ptr %t
  %t2805 = getelementptr inbounds %TypeInfo, ptr %t2804, i32 0, i32 3
  %t2806 = load ptr, ptr %t2805
  %t2807 = call ptr @ptr_to_type(ptr %t2806)
  %t2808 = call ptr @type_sem_key__Struct_TypeInfo(ptr %t2807)
  %t2809 = call ptr @str_concat(ptr %t2803, ptr %t2808)
  ret ptr %t2809
label_974:
  %t2810 = getelementptr inbounds [14 x i8], ptr @.str.s354, i64 0, i64 0
  ret ptr %t2810
label_971:
  %t2811 = load ptr, ptr %t
  %t2812 = getelementptr inbounds %TypeInfo, ptr %t2811, i32 0, i32 0
  %t2813 = load i32, ptr %t2812
  %t2814 = icmp eq i32 %t2813, 11
  br i1 %t2814, label %label_975, label %label_977
label_975:
  %t2815 = load ptr, ptr %t
  %t2816 = getelementptr inbounds %TypeInfo, ptr %t2815, i32 0, i32 3
  %t2817 = load ptr, ptr %t2816
  %t2818 = getelementptr inbounds [1 x i8], ptr @.str.s355, i64 0, i64 0
  %t2819 = call i32 @str_equals(ptr %t2817, ptr %t2818)
  %t2820 = icmp eq i32 %t2819, 0
  br i1 %t2820, label %label_978, label %label_980
label_978:
  %t2821 = getelementptr inbounds [6 x i8], ptr @.str.s356, i64 0, i64 0
  %t2822 = load ptr, ptr %t
  %t2823 = getelementptr inbounds %TypeInfo, ptr %t2822, i32 0, i32 3
  %t2824 = load ptr, ptr %t2823
  %t2825 = call ptr @ptr_to_type(ptr %t2824)
  %t2826 = call ptr @type_sem_key__Struct_TypeInfo(ptr %t2825)
  %t2827 = call ptr @str_concat(ptr %t2821, ptr %t2826)
  ret ptr %t2827
label_980:
  %t2828 = getelementptr inbounds [13 x i8], ptr @.str.s357, i64 0, i64 0
  ret ptr %t2828
label_977:
  %t2829 = getelementptr inbounds [8 x i8], ptr @.str.s358, i64 0, i64 0
  ret ptr %t2829
}

define ptr @type_storage_key__Struct_TypeInfo(ptr %p_t) {
  %t = alloca ptr
  %key = alloca ptr
  store ptr %p_t, ptr %t
  %t2832 = load ptr, ptr %t
  %t2833 = call ptr @type_ir_key__Struct_TypeInfo(ptr %t2832)
  store ptr %t2833, ptr %key
  %t2834 = load ptr, ptr %key
  %t2835 = getelementptr inbounds [7 x i8], ptr @.str.s359, i64 0, i64 0
  %t2836 = call i32 @str_equals(ptr %t2834, ptr %t2835)
  %t2837 = icmp eq i32 %t2836, 1
  br i1 %t2837, label %label_981, label %label_983
label_981:
  %t2838 = getelementptr inbounds [4 x i8], ptr @.str.s360, i64 0, i64 0
  ret ptr %t2838
label_983:
  %t2839 = load ptr, ptr %key
  %t2840 = getelementptr inbounds [8 x i8], ptr @.str.s361, i64 0, i64 0
  %t2841 = call i32 @str_starts_with(ptr %t2839, ptr %t2840)
  %t2842 = icmp eq i32 %t2841, 1
  br i1 %t2842, label %label_984, label %label_986
label_984:
  %t2843 = getelementptr inbounds [4 x i8], ptr @.str.s362, i64 0, i64 0
  ret ptr %t2843
label_986:
  %t2844 = load ptr, ptr %key
  ret ptr %t2844
}

define ptr @type_from_annotation__Struct_ASTNode(ptr %p_tn) {
  %tn = alloca ptr
  store ptr %p_tn, ptr %tn
  %t2846 = load ptr, ptr %tn
  %t2847 = getelementptr inbounds %ASTNode, ptr %t2846, i32 0, i32 3
  %t2848 = load i32, ptr %t2847
  %t2849 = icmp eq i32 %t2848, 1
  br i1 %t2849, label %label_987, label %label_989
label_987:
  %t2850 = load ptr, ptr %tn
  %t2851 = getelementptr inbounds %ASTNode, ptr %t2850, i32 0, i32 5
  %t2852 = load ptr, ptr %t2851
  %t2853 = getelementptr inbounds [1 x i8], ptr @.str.s363, i64 0, i64 0
  %t2854 = call i32 @str_equals(ptr %t2852, ptr %t2853)
  %t2855 = icmp eq i32 %t2854, 0
  br i1 %t2855, label %label_990, label %label_992
label_990:
  %t2856 = load ptr, ptr %tn
  %t2857 = getelementptr inbounds %ASTNode, ptr %t2856, i32 0, i32 5
  %t2858 = load ptr, ptr %t2857
  %t2859 = call ptr @ptr_to_node(ptr %t2858)
  %t2860 = call ptr @type_from_annotation__Struct_ASTNode(ptr %t2859)
  %t2861 = call ptr @type_array__Struct_TypeInfo(ptr %t2860)
  ret ptr %t2861
label_992:
  %t2862 = call ptr @type_invalid__Void()
  %t2863 = call ptr @type_array__Struct_TypeInfo(ptr %t2862)
  ret ptr %t2863
label_989:
  %t2864 = load ptr, ptr %tn
  %t2865 = getelementptr inbounds %ASTNode, ptr %t2864, i32 0, i32 1
  %t2866 = load ptr, ptr %t2865
  %t2867 = getelementptr inbounds [4 x i8], ptr @.str.s364, i64 0, i64 0
  %t2868 = call i32 @str_equals(ptr %t2866, ptr %t2867)
  %t2869 = icmp eq i32 %t2868, 1
  br i1 %t2869, label %label_993, label %label_995
label_993:
  %t2870 = call ptr @type_int__Void()
  ret ptr %t2870
label_995:
  %t2871 = load ptr, ptr %tn
  %t2872 = getelementptr inbounds %ASTNode, ptr %t2871, i32 0, i32 1
  %t2873 = load ptr, ptr %t2872
  %t2874 = getelementptr inbounds [6 x i8], ptr @.str.s365, i64 0, i64 0
  %t2875 = call i32 @str_equals(ptr %t2873, ptr %t2874)
  %t2876 = icmp eq i32 %t2875, 1
  br i1 %t2876, label %label_996, label %label_998
label_996:
  %t2877 = call ptr @type_float__Void()
  ret ptr %t2877
label_998:
  %t2878 = load ptr, ptr %tn
  %t2879 = getelementptr inbounds %ASTNode, ptr %t2878, i32 0, i32 1
  %t2880 = load ptr, ptr %t2879
  %t2881 = getelementptr inbounds [5 x i8], ptr @.str.s366, i64 0, i64 0
  %t2882 = call i32 @str_equals(ptr %t2880, ptr %t2881)
  %t2883 = icmp eq i32 %t2882, 1
  br i1 %t2883, label %label_999, label %label_1001
label_999:
  %t2884 = call ptr @type_bool__Void()
  ret ptr %t2884
label_1001:
  %t2885 = load ptr, ptr %tn
  %t2886 = getelementptr inbounds %ASTNode, ptr %t2885, i32 0, i32 1
  %t2887 = load ptr, ptr %t2886
  %t2888 = getelementptr inbounds [7 x i8], ptr @.str.s367, i64 0, i64 0
  %t2889 = call i32 @str_equals(ptr %t2887, ptr %t2888)
  %t2890 = icmp eq i32 %t2889, 1
  br i1 %t2890, label %label_1002, label %label_1004
label_1002:
  %t2891 = call ptr @type_string__Void()
  ret ptr %t2891
label_1004:
  %t2892 = load ptr, ptr %tn
  %t2893 = getelementptr inbounds %ASTNode, ptr %t2892, i32 0, i32 1
  %t2894 = load ptr, ptr %t2893
  %t2895 = getelementptr inbounds [5 x i8], ptr @.str.s368, i64 0, i64 0
  %t2896 = call i32 @str_equals(ptr %t2894, ptr %t2895)
  %t2897 = icmp eq i32 %t2896, 1
  br i1 %t2897, label %label_1005, label %label_1007
label_1005:
  %t2898 = call ptr @type_char__Void()
  ret ptr %t2898
label_1007:
  %t2899 = load ptr, ptr %tn
  %t2900 = getelementptr inbounds %ASTNode, ptr %t2899, i32 0, i32 1
  %t2901 = load ptr, ptr %t2900
  %t2902 = getelementptr inbounds [3 x i8], ptr @.str.s369, i64 0, i64 0
  %t2903 = call i32 @str_equals(ptr %t2901, ptr %t2902)
  %t2904 = icmp eq i32 %t2903, 1
  br i1 %t2904, label %label_1008, label %label_1010
label_1008:
  %t2905 = call ptr @type_i8__Void()
  ret ptr %t2905
label_1010:
  %t2906 = load ptr, ptr %tn
  %t2907 = getelementptr inbounds %ASTNode, ptr %t2906, i32 0, i32 1
  %t2908 = load ptr, ptr %t2907
  %t2909 = getelementptr inbounds [4 x i8], ptr @.str.s370, i64 0, i64 0
  %t2910 = call i32 @str_equals(ptr %t2908, ptr %t2909)
  %t2911 = icmp eq i32 %t2910, 1
  br i1 %t2911, label %label_1011, label %label_1013
label_1011:
  %t2912 = call ptr @type_i16__Void()
  ret ptr %t2912
label_1013:
  %t2913 = load ptr, ptr %tn
  %t2914 = getelementptr inbounds %ASTNode, ptr %t2913, i32 0, i32 1
  %t2915 = load ptr, ptr %t2914
  %t2916 = getelementptr inbounds [4 x i8], ptr @.str.s371, i64 0, i64 0
  %t2917 = call i32 @str_equals(ptr %t2915, ptr %t2916)
  %t2918 = icmp eq i32 %t2917, 1
  br i1 %t2918, label %label_1014, label %label_1016
label_1014:
  %t2919 = call ptr @type_i64__Void()
  ret ptr %t2919
label_1016:
  %t2920 = load ptr, ptr %tn
  %t2921 = getelementptr inbounds %ASTNode, ptr %t2920, i32 0, i32 1
  %t2922 = load ptr, ptr %t2921
  %t2923 = getelementptr inbounds [6 x i8], ptr @.str.s372, i64 0, i64 0
  %t2924 = call i32 @str_equals(ptr %t2922, ptr %t2923)
  %t2925 = icmp eq i32 %t2924, 1
  br i1 %t2925, label %label_1017, label %label_1019
label_1017:
  %t2926 = call ptr @type_isize__Void()
  ret ptr %t2926
label_1019:
  %t2927 = load ptr, ptr %tn
  %t2928 = getelementptr inbounds %ASTNode, ptr %t2927, i32 0, i32 1
  %t2929 = load ptr, ptr %t2928
  %t2930 = getelementptr inbounds [3 x i8], ptr @.str.s373, i64 0, i64 0
  %t2931 = call i32 @str_equals(ptr %t2929, ptr %t2930)
  %t2932 = icmp eq i32 %t2931, 1
  br i1 %t2932, label %label_1020, label %label_1022
label_1020:
  %t2933 = call ptr @type_u8__Void()
  ret ptr %t2933
label_1022:
  %t2934 = load ptr, ptr %tn
  %t2935 = getelementptr inbounds %ASTNode, ptr %t2934, i32 0, i32 1
  %t2936 = load ptr, ptr %t2935
  %t2937 = getelementptr inbounds [4 x i8], ptr @.str.s374, i64 0, i64 0
  %t2938 = call i32 @str_equals(ptr %t2936, ptr %t2937)
  %t2939 = icmp eq i32 %t2938, 1
  br i1 %t2939, label %label_1023, label %label_1025
label_1023:
  %t2940 = call ptr @type_u16__Void()
  ret ptr %t2940
label_1025:
  %t2941 = load ptr, ptr %tn
  %t2942 = getelementptr inbounds %ASTNode, ptr %t2941, i32 0, i32 1
  %t2943 = load ptr, ptr %t2942
  %t2944 = getelementptr inbounds [4 x i8], ptr @.str.s375, i64 0, i64 0
  %t2945 = call i32 @str_equals(ptr %t2943, ptr %t2944)
  %t2946 = icmp eq i32 %t2945, 1
  br i1 %t2946, label %label_1026, label %label_1028
label_1026:
  %t2947 = call ptr @type_u32__Void()
  ret ptr %t2947
label_1028:
  %t2948 = load ptr, ptr %tn
  %t2949 = getelementptr inbounds %ASTNode, ptr %t2948, i32 0, i32 1
  %t2950 = load ptr, ptr %t2949
  %t2951 = getelementptr inbounds [4 x i8], ptr @.str.s376, i64 0, i64 0
  %t2952 = call i32 @str_equals(ptr %t2950, ptr %t2951)
  %t2953 = icmp eq i32 %t2952, 1
  br i1 %t2953, label %label_1029, label %label_1031
label_1029:
  %t2954 = call ptr @type_u64__Void()
  ret ptr %t2954
label_1031:
  %t2955 = load ptr, ptr %tn
  %t2956 = getelementptr inbounds %ASTNode, ptr %t2955, i32 0, i32 1
  %t2957 = load ptr, ptr %t2956
  %t2958 = getelementptr inbounds [6 x i8], ptr @.str.s377, i64 0, i64 0
  %t2959 = call i32 @str_equals(ptr %t2957, ptr %t2958)
  %t2960 = icmp eq i32 %t2959, 1
  br i1 %t2960, label %label_1032, label %label_1034
label_1032:
  %t2961 = call ptr @type_usize__Void()
  ret ptr %t2961
label_1034:
  %t2962 = load ptr, ptr %tn
  %t2963 = getelementptr inbounds %ASTNode, ptr %t2962, i32 0, i32 1
  %t2964 = load ptr, ptr %t2963
  %t2965 = getelementptr inbounds [1 x i8], ptr @.str.s378, i64 0, i64 0
  %t2966 = call i32 @str_equals(ptr %t2964, ptr %t2965)
  %t2967 = icmp eq i32 %t2966, 1
  br i1 %t2967, label %label_1035, label %label_1037
label_1035:
  %t2968 = call ptr @type_void__Void()
  ret ptr %t2968
label_1037:
  %t2969 = load ptr, ptr %tn
  %t2970 = getelementptr inbounds %ASTNode, ptr %t2969, i32 0, i32 1
  %t2971 = load ptr, ptr %t2970
  %t2972 = call ptr @type_struct__String(ptr %t2971)
  ret ptr %t2972
}

define ptr @type_from_ir_key__String(ptr %p_key) {
  %key = alloca ptr
  store ptr %p_key, ptr %key
  %t2974 = load ptr, ptr %key
  %t2975 = getelementptr inbounds [4 x i8], ptr @.str.s379, i64 0, i64 0
  %t2976 = call i32 @str_equals(ptr %t2974, ptr %t2975)
  %t2977 = icmp eq i32 %t2976, 1
  br i1 %t2977, label %label_1038, label %label_1040
label_1038:
  %t2978 = call ptr @type_int__Void()
  ret ptr %t2978
label_1040:
  %t2979 = load ptr, ptr %key
  %t2980 = getelementptr inbounds [7 x i8], ptr @.str.s380, i64 0, i64 0
  %t2981 = call i32 @str_equals(ptr %t2979, ptr %t2980)
  %t2982 = icmp eq i32 %t2981, 1
  br i1 %t2982, label %label_1041, label %label_1043
label_1041:
  %t2983 = call ptr @type_float__Void()
  ret ptr %t2983
label_1043:
  %t2984 = load ptr, ptr %key
  %t2985 = getelementptr inbounds [3 x i8], ptr @.str.s381, i64 0, i64 0
  %t2986 = call i32 @str_equals(ptr %t2984, ptr %t2985)
  %t2987 = icmp eq i32 %t2986, 1
  br i1 %t2987, label %label_1044, label %label_1046
label_1044:
  %t2988 = call ptr @type_bool__Void()
  ret ptr %t2988
label_1046:
  %t2989 = load ptr, ptr %key
  %t2990 = getelementptr inbounds [3 x i8], ptr @.str.s382, i64 0, i64 0
  %t2991 = call i32 @str_equals(ptr %t2989, ptr %t2990)
  %t2992 = icmp eq i32 %t2991, 1
  br i1 %t2992, label %label_1047, label %label_1049
label_1047:
  %t2993 = call ptr @type_char__Void()
  ret ptr %t2993
label_1049:
  %t2994 = load ptr, ptr %key
  %t2995 = getelementptr inbounds [4 x i8], ptr @.str.s383, i64 0, i64 0
  %t2996 = call i32 @str_equals(ptr %t2994, ptr %t2995)
  %t2997 = icmp eq i32 %t2996, 1
  br i1 %t2997, label %label_1050, label %label_1052
label_1050:
  %t2998 = call ptr @type_ptr__Void()
  ret ptr %t2998
label_1052:
  %t2999 = load ptr, ptr %key
  %t3000 = getelementptr inbounds [5 x i8], ptr @.str.s384, i64 0, i64 0
  %t3001 = call i32 @str_equals(ptr %t2999, ptr %t3000)
  %t3002 = icmp eq i32 %t3001, 1
  br i1 %t3002, label %label_1053, label %label_1055
label_1053:
  %t3003 = call ptr @type_void__Void()
  ret ptr %t3003
label_1055:
  %t3004 = load ptr, ptr %key
  %t3005 = getelementptr inbounds [8 x i8], ptr @.str.s385, i64 0, i64 0
  %t3006 = call i32 @str_starts_with(ptr %t3004, ptr %t3005)
  %t3007 = icmp eq i32 %t3006, 1
  br i1 %t3007, label %label_1056, label %label_1058
label_1056:
  %t3008 = load ptr, ptr %key
  %t3009 = load ptr, ptr %key
  %t3010 = call i32 @str_length(ptr %t3009)
  %t3011 = sub i32 %t3010, 7
  %t3012 = call ptr @str_substring(ptr %t3008, i32 7, i32 %t3011)
  %t3013 = call ptr @type_struct__String(ptr %t3012)
  ret ptr %t3013
label_1058:
  %t3014 = call ptr @type_invalid__Void()
  ret ptr %t3014
}

define ptr @type_from_sem_key__String(ptr %p_key) {
  %key = alloca ptr
  store ptr %p_key, ptr %key
  %t3016 = load ptr, ptr %key
  %t3017 = getelementptr inbounds [4 x i8], ptr @.str.s386, i64 0, i64 0
  %t3018 = call i32 @str_equals(ptr %t3016, ptr %t3017)
  %t3019 = icmp eq i32 %t3018, 1
  br i1 %t3019, label %label_1059, label %label_1061
label_1059:
  %t3020 = call ptr @type_int__Void()
  ret ptr %t3020
label_1061:
  %t3021 = load ptr, ptr %key
  %t3022 = getelementptr inbounds [6 x i8], ptr @.str.s387, i64 0, i64 0
  %t3023 = call i32 @str_equals(ptr %t3021, ptr %t3022)
  %t3024 = icmp eq i32 %t3023, 1
  br i1 %t3024, label %label_1062, label %label_1064
label_1062:
  %t3025 = call ptr @type_float__Void()
  ret ptr %t3025
label_1064:
  %t3026 = load ptr, ptr %key
  %t3027 = getelementptr inbounds [5 x i8], ptr @.str.s388, i64 0, i64 0
  %t3028 = call i32 @str_equals(ptr %t3026, ptr %t3027)
  %t3029 = icmp eq i32 %t3028, 1
  br i1 %t3029, label %label_1065, label %label_1067
label_1065:
  %t3030 = call ptr @type_bool__Void()
  ret ptr %t3030
label_1067:
  %t3031 = load ptr, ptr %key
  %t3032 = getelementptr inbounds [5 x i8], ptr @.str.s389, i64 0, i64 0
  %t3033 = call i32 @str_equals(ptr %t3031, ptr %t3032)
  %t3034 = icmp eq i32 %t3033, 1
  br i1 %t3034, label %label_1068, label %label_1070
label_1068:
  %t3035 = call ptr @type_char__Void()
  ret ptr %t3035
label_1070:
  %t3036 = load ptr, ptr %key
  %t3037 = getelementptr inbounds [7 x i8], ptr @.str.s390, i64 0, i64 0
  %t3038 = call i32 @str_equals(ptr %t3036, ptr %t3037)
  %t3039 = icmp eq i32 %t3038, 1
  br i1 %t3039, label %label_1071, label %label_1073
label_1071:
  %t3040 = call ptr @type_string__Void()
  ret ptr %t3040
label_1073:
  %t3041 = load ptr, ptr %key
  %t3042 = getelementptr inbounds [4 x i8], ptr @.str.s391, i64 0, i64 0
  %t3043 = call i32 @str_equals(ptr %t3041, ptr %t3042)
  %t3044 = icmp eq i32 %t3043, 1
  br i1 %t3044, label %label_1074, label %label_1076
label_1074:
  %t3045 = call ptr @type_ptr__Void()
  ret ptr %t3045
label_1076:
  %t3046 = load ptr, ptr %key
  %t3047 = getelementptr inbounds [5 x i8], ptr @.str.s392, i64 0, i64 0
  %t3048 = call i32 @str_equals(ptr %t3046, ptr %t3047)
  %t3049 = icmp eq i32 %t3048, 1
  br i1 %t3049, label %label_1077, label %label_1079
label_1077:
  %t3050 = call ptr @type_void__Void()
  ret ptr %t3050
label_1079:
  %t3051 = load ptr, ptr %key
  %t3052 = getelementptr inbounds [3 x i8], ptr @.str.s393, i64 0, i64 0
  %t3053 = call i32 @str_equals(ptr %t3051, ptr %t3052)
  %t3054 = icmp eq i32 %t3053, 1
  br i1 %t3054, label %label_1080, label %label_1082
label_1080:
  %t3055 = call ptr @type_i8__Void()
  ret ptr %t3055
label_1082:
  %t3056 = load ptr, ptr %key
  %t3057 = getelementptr inbounds [4 x i8], ptr @.str.s394, i64 0, i64 0
  %t3058 = call i32 @str_equals(ptr %t3056, ptr %t3057)
  %t3059 = icmp eq i32 %t3058, 1
  br i1 %t3059, label %label_1083, label %label_1085
label_1083:
  %t3060 = call ptr @type_i16__Void()
  ret ptr %t3060
label_1085:
  %t3061 = load ptr, ptr %key
  %t3062 = getelementptr inbounds [4 x i8], ptr @.str.s395, i64 0, i64 0
  %t3063 = call i32 @str_equals(ptr %t3061, ptr %t3062)
  %t3064 = icmp eq i32 %t3063, 1
  br i1 %t3064, label %label_1086, label %label_1088
label_1086:
  %t3065 = call ptr @type_i64__Void()
  ret ptr %t3065
label_1088:
  %t3066 = load ptr, ptr %key
  %t3067 = getelementptr inbounds [6 x i8], ptr @.str.s396, i64 0, i64 0
  %t3068 = call i32 @str_equals(ptr %t3066, ptr %t3067)
  %t3069 = icmp eq i32 %t3068, 1
  br i1 %t3069, label %label_1089, label %label_1091
label_1089:
  %t3070 = call ptr @type_isize__Void()
  ret ptr %t3070
label_1091:
  %t3071 = load ptr, ptr %key
  %t3072 = getelementptr inbounds [3 x i8], ptr @.str.s397, i64 0, i64 0
  %t3073 = call i32 @str_equals(ptr %t3071, ptr %t3072)
  %t3074 = icmp eq i32 %t3073, 1
  br i1 %t3074, label %label_1092, label %label_1094
label_1092:
  %t3075 = call ptr @type_u8__Void()
  ret ptr %t3075
label_1094:
  %t3076 = load ptr, ptr %key
  %t3077 = getelementptr inbounds [4 x i8], ptr @.str.s398, i64 0, i64 0
  %t3078 = call i32 @str_equals(ptr %t3076, ptr %t3077)
  %t3079 = icmp eq i32 %t3078, 1
  br i1 %t3079, label %label_1095, label %label_1097
label_1095:
  %t3080 = call ptr @type_u16__Void()
  ret ptr %t3080
label_1097:
  %t3081 = load ptr, ptr %key
  %t3082 = getelementptr inbounds [4 x i8], ptr @.str.s399, i64 0, i64 0
  %t3083 = call i32 @str_equals(ptr %t3081, ptr %t3082)
  %t3084 = icmp eq i32 %t3083, 1
  br i1 %t3084, label %label_1098, label %label_1100
label_1098:
  %t3085 = call ptr @type_u32__Void()
  ret ptr %t3085
label_1100:
  %t3086 = load ptr, ptr %key
  %t3087 = getelementptr inbounds [4 x i8], ptr @.str.s400, i64 0, i64 0
  %t3088 = call i32 @str_equals(ptr %t3086, ptr %t3087)
  %t3089 = icmp eq i32 %t3088, 1
  br i1 %t3089, label %label_1101, label %label_1103
label_1101:
  %t3090 = call ptr @type_u64__Void()
  ret ptr %t3090
label_1103:
  %t3091 = load ptr, ptr %key
  %t3092 = getelementptr inbounds [6 x i8], ptr @.str.s401, i64 0, i64 0
  %t3093 = call i32 @str_equals(ptr %t3091, ptr %t3092)
  %t3094 = icmp eq i32 %t3093, 1
  br i1 %t3094, label %label_1104, label %label_1106
label_1104:
  %t3095 = call ptr @type_usize__Void()
  ret ptr %t3095
label_1106:
  %t3096 = load ptr, ptr %key
  %t3097 = getelementptr inbounds [8 x i8], ptr @.str.s402, i64 0, i64 0
  %t3098 = call i32 @str_starts_with(ptr %t3096, ptr %t3097)
  %t3099 = icmp eq i32 %t3098, 1
  br i1 %t3099, label %label_1107, label %label_1109
label_1107:
  %t3100 = load ptr, ptr %key
  %t3101 = load ptr, ptr %key
  %t3102 = call i32 @str_length(ptr %t3101)
  %t3103 = sub i32 %t3102, 7
  %t3104 = call ptr @str_substring(ptr %t3100, i32 7, i32 %t3103)
  %t3105 = call ptr @type_struct__String(ptr %t3104)
  ret ptr %t3105
label_1109:
  %t3106 = load ptr, ptr %key
  %t3107 = getelementptr inbounds [6 x i8], ptr @.str.s403, i64 0, i64 0
  %t3108 = call i32 @str_starts_with(ptr %t3106, ptr %t3107)
  %t3109 = icmp eq i32 %t3108, 1
  br i1 %t3109, label %label_1110, label %label_1112
label_1110:
  %t3110 = load ptr, ptr %key
  %t3111 = load ptr, ptr %key
  %t3112 = call i32 @str_length(ptr %t3111)
  %t3113 = sub i32 %t3112, 5
  %t3114 = call ptr @str_substring(ptr %t3110, i32 5, i32 %t3113)
  %t3115 = call ptr @type_enum__String(ptr %t3114)
  ret ptr %t3115
label_1112:
  %t3116 = load ptr, ptr %key
  %t3117 = getelementptr inbounds [7 x i8], ptr @.str.s404, i64 0, i64 0
  %t3118 = call i32 @str_starts_with(ptr %t3116, ptr %t3117)
  %t3119 = icmp eq i32 %t3118, 1
  br i1 %t3119, label %label_1113, label %label_1115
label_1113:
  %t3120 = load ptr, ptr %key
  %t3121 = load ptr, ptr %key
  %t3122 = call i32 @str_length(ptr %t3121)
  %t3123 = sub i32 %t3122, 6
  %t3124 = call ptr @str_substring(ptr %t3120, i32 6, i32 %t3123)
  %t3125 = call ptr @type_from_sem_key__String(ptr %t3124)
  %t3126 = call ptr @type_array__Struct_TypeInfo(ptr %t3125)
  ret ptr %t3126
label_1115:
  %t3127 = load ptr, ptr %key
  %t3128 = getelementptr inbounds [6 x i8], ptr @.str.s405, i64 0, i64 0
  %t3129 = call i32 @str_starts_with(ptr %t3127, ptr %t3128)
  %t3130 = icmp eq i32 %t3129, 1
  br i1 %t3130, label %label_1116, label %label_1118
label_1116:
  %t3131 = load ptr, ptr %key
  %t3132 = load ptr, ptr %key
  %t3133 = call i32 @str_length(ptr %t3132)
  %t3134 = sub i32 %t3133, 5
  %t3135 = call ptr @str_substring(ptr %t3131, i32 5, i32 %t3134)
  %t3136 = call ptr @type_from_sem_key__String(ptr %t3135)
  %t3137 = call ptr @type_list__Struct_TypeInfo(ptr %t3136)
  ret ptr %t3137
label_1118:
  %t3138 = call ptr @type_invalid__Void()
  ret ptr %t3138
}

define void @node_set_type__Struct_ASTNode_Struct_TypeInfo(ptr %p_node, ptr %p_t) {
  %node = alloca ptr
  %t = alloca ptr
  store ptr %p_node, ptr %node
  store ptr %p_t, ptr %t
  %t3141 = load ptr, ptr %node
  %t3142 = load ptr, ptr %t
  %t3143 = call ptr @type_to_ptr(ptr %t3142)
  %t3144 = getelementptr inbounds %ASTNode, ptr %t3141, i32 0, i32 9
  store ptr %t3143, ptr %t3144
  ret void
}

define i1 @node_has_type__Struct_ASTNode(ptr %p_node) {
  %node = alloca ptr
  store ptr %p_node, ptr %node
  %t3146 = load ptr, ptr %node
  %t3147 = getelementptr inbounds %ASTNode, ptr %t3146, i32 0, i32 9
  %t3148 = load ptr, ptr %t3147
  %t3149 = getelementptr inbounds [1 x i8], ptr @.str.s406, i64 0, i64 0
  %t3150 = call i32 @str_equals(ptr %t3148, ptr %t3149)
  %t3151 = icmp eq i32 %t3150, 0
  ret i1 %t3151
}

define ptr @node_get_type__Struct_ASTNode(ptr %p_node) {
  %node = alloca ptr
  store ptr %p_node, ptr %node
  %t3153 = load ptr, ptr %node
  %t3154 = call i1 @node_has_type__Struct_ASTNode(ptr %t3153)
  br i1 %t3154, label %label_1119, label %label_1121
label_1119:
  %t3155 = load ptr, ptr %node
  %t3156 = getelementptr inbounds %ASTNode, ptr %t3155, i32 0, i32 9
  %t3157 = load ptr, ptr %t3156
  %t3158 = call ptr @ptr_to_type(ptr %t3157)
  ret ptr %t3158
label_1121:
  %t3159 = call ptr @type_invalid__Void()
  ret ptr %t3159
}

define void @ir_set_target_wasm__Bool(i1 %p_enabled) {
  %enabled = alloca i1
  store i1 %p_enabled, ptr %enabled
  %t3161 = load i1, ptr %enabled
  store i1 %t3161, ptr @ir_target_wasm
  ret void
}

define ptr @ir_ptr_int_type__Void() {
  %t3162 = load i1, ptr @ir_target_wasm
  br i1 %t3162, label %label_1122, label %label_1124
label_1122:
  %t3163 = getelementptr inbounds [4 x i8], ptr @.str.s407, i64 0, i64 0
  ret ptr %t3163
label_1124:
  %t3164 = getelementptr inbounds [4 x i8], ptr @.str.s408, i64 0, i64 0
  ret ptr %t3164
}

define ptr @map_type__String(ptr %p_t) {
  %t = alloca ptr
  store ptr %p_t, ptr %t
  %t3166 = load ptr, ptr %t
  %t3167 = getelementptr inbounds [4 x i8], ptr @.str.s409, i64 0, i64 0
  %t3168 = call i32 @str_equals(ptr %t3166, ptr %t3167)
  %t3169 = icmp eq i32 %t3168, 1
  br i1 %t3169, label %label_1125, label %label_1127
label_1125:
  %t3170 = getelementptr inbounds [4 x i8], ptr @.str.s410, i64 0, i64 0
  ret ptr %t3170
label_1127:
  %t3171 = load ptr, ptr %t
  %t3172 = getelementptr inbounds [6 x i8], ptr @.str.s411, i64 0, i64 0
  %t3173 = call i32 @str_equals(ptr %t3171, ptr %t3172)
  %t3174 = icmp eq i32 %t3173, 1
  br i1 %t3174, label %label_1128, label %label_1130
label_1128:
  %t3175 = getelementptr inbounds [7 x i8], ptr @.str.s412, i64 0, i64 0
  ret ptr %t3175
label_1130:
  %t3176 = load ptr, ptr %t
  %t3177 = getelementptr inbounds [5 x i8], ptr @.str.s413, i64 0, i64 0
  %t3178 = call i32 @str_equals(ptr %t3176, ptr %t3177)
  %t3179 = icmp eq i32 %t3178, 1
  br i1 %t3179, label %label_1131, label %label_1133
label_1131:
  %t3180 = getelementptr inbounds [3 x i8], ptr @.str.s414, i64 0, i64 0
  ret ptr %t3180
label_1133:
  %t3181 = load ptr, ptr %t
  %t3182 = getelementptr inbounds [7 x i8], ptr @.str.s415, i64 0, i64 0
  %t3183 = call i32 @str_equals(ptr %t3181, ptr %t3182)
  %t3184 = icmp eq i32 %t3183, 1
  br i1 %t3184, label %label_1134, label %label_1136
label_1134:
  %t3185 = getelementptr inbounds [4 x i8], ptr @.str.s416, i64 0, i64 0
  ret ptr %t3185
label_1136:
  %t3186 = load ptr, ptr %t
  %t3187 = getelementptr inbounds [5 x i8], ptr @.str.s417, i64 0, i64 0
  %t3188 = call i32 @str_equals(ptr %t3186, ptr %t3187)
  %t3189 = icmp eq i32 %t3188, 1
  br i1 %t3189, label %label_1137, label %label_1139
label_1137:
  %t3190 = getelementptr inbounds [3 x i8], ptr @.str.s418, i64 0, i64 0
  ret ptr %t3190
label_1139:
  %t3191 = load ptr, ptr %t
  %t3192 = getelementptr inbounds [3 x i8], ptr @.str.s419, i64 0, i64 0
  %t3193 = call i32 @str_equals(ptr %t3191, ptr %t3192)
  %t3194 = icmp eq i32 %t3193, 1
  br i1 %t3194, label %label_1140, label %label_1142
label_1140:
  %t3195 = getelementptr inbounds [3 x i8], ptr @.str.s420, i64 0, i64 0
  ret ptr %t3195
label_1142:
  %t3196 = load ptr, ptr %t
  %t3197 = getelementptr inbounds [4 x i8], ptr @.str.s421, i64 0, i64 0
  %t3198 = call i32 @str_equals(ptr %t3196, ptr %t3197)
  %t3199 = icmp eq i32 %t3198, 1
  br i1 %t3199, label %label_1143, label %label_1145
label_1143:
  %t3200 = getelementptr inbounds [4 x i8], ptr @.str.s422, i64 0, i64 0
  ret ptr %t3200
label_1145:
  %t3201 = load ptr, ptr %t
  %t3202 = getelementptr inbounds [4 x i8], ptr @.str.s423, i64 0, i64 0
  %t3203 = call i32 @str_equals(ptr %t3201, ptr %t3202)
  %t3204 = icmp eq i32 %t3203, 1
  br i1 %t3204, label %label_1146, label %label_1148
label_1146:
  %t3205 = getelementptr inbounds [4 x i8], ptr @.str.s424, i64 0, i64 0
  ret ptr %t3205
label_1148:
  %t3206 = load ptr, ptr %t
  %t3207 = getelementptr inbounds [6 x i8], ptr @.str.s425, i64 0, i64 0
  %t3208 = call i32 @str_equals(ptr %t3206, ptr %t3207)
  %t3209 = icmp eq i32 %t3208, 1
  br i1 %t3209, label %label_1149, label %label_1151
label_1149:
  %t3210 = call ptr @ir_ptr_int_type__Void()
  ret ptr %t3210
label_1151:
  %t3211 = load ptr, ptr %t
  %t3212 = getelementptr inbounds [3 x i8], ptr @.str.s426, i64 0, i64 0
  %t3213 = call i32 @str_equals(ptr %t3211, ptr %t3212)
  %t3214 = icmp eq i32 %t3213, 1
  br i1 %t3214, label %label_1152, label %label_1154
label_1152:
  %t3215 = getelementptr inbounds [3 x i8], ptr @.str.s427, i64 0, i64 0
  ret ptr %t3215
label_1154:
  %t3216 = load ptr, ptr %t
  %t3217 = getelementptr inbounds [4 x i8], ptr @.str.s428, i64 0, i64 0
  %t3218 = call i32 @str_equals(ptr %t3216, ptr %t3217)
  %t3219 = icmp eq i32 %t3218, 1
  br i1 %t3219, label %label_1155, label %label_1157
label_1155:
  %t3220 = getelementptr inbounds [4 x i8], ptr @.str.s429, i64 0, i64 0
  ret ptr %t3220
label_1157:
  %t3221 = load ptr, ptr %t
  %t3222 = getelementptr inbounds [4 x i8], ptr @.str.s430, i64 0, i64 0
  %t3223 = call i32 @str_equals(ptr %t3221, ptr %t3222)
  %t3224 = icmp eq i32 %t3223, 1
  br i1 %t3224, label %label_1158, label %label_1160
label_1158:
  %t3225 = getelementptr inbounds [4 x i8], ptr @.str.s431, i64 0, i64 0
  ret ptr %t3225
label_1160:
  %t3226 = load ptr, ptr %t
  %t3227 = getelementptr inbounds [4 x i8], ptr @.str.s432, i64 0, i64 0
  %t3228 = call i32 @str_equals(ptr %t3226, ptr %t3227)
  %t3229 = icmp eq i32 %t3228, 1
  br i1 %t3229, label %label_1161, label %label_1163
label_1161:
  %t3230 = getelementptr inbounds [4 x i8], ptr @.str.s433, i64 0, i64 0
  ret ptr %t3230
label_1163:
  %t3231 = load ptr, ptr %t
  %t3232 = getelementptr inbounds [6 x i8], ptr @.str.s434, i64 0, i64 0
  %t3233 = call i32 @str_equals(ptr %t3231, ptr %t3232)
  %t3234 = icmp eq i32 %t3233, 1
  br i1 %t3234, label %label_1164, label %label_1166
label_1164:
  %t3235 = call ptr @ir_ptr_int_type__Void()
  ret ptr %t3235
label_1166:
  %t3236 = load ptr, ptr %t
  %t3237 = getelementptr inbounds [1 x i8], ptr @.str.s435, i64 0, i64 0
  %t3238 = call i32 @str_equals(ptr %t3236, ptr %t3237)
  %t3239 = icmp eq i32 %t3238, 1
  br i1 %t3239, label %label_1167, label %label_1169
label_1167:
  %t3240 = getelementptr inbounds [5 x i8], ptr @.str.s436, i64 0, i64 0
  ret ptr %t3240
label_1169:
  %t3241 = getelementptr inbounds [4 x i8], ptr @.str.s437, i64 0, i64 0
  ret ptr %t3241
}

define ptr @struct_type_key__String(ptr %p_name) {
  %name = alloca ptr
  store ptr %p_name, ptr %name
  %t3243 = getelementptr inbounds [8 x i8], ptr @.str.s438, i64 0, i64 0
  %t3244 = load ptr, ptr %name
  %t3245 = call ptr @str_concat(ptr %t3243, ptr %t3244)
  ret ptr %t3245
}

define i1 @is_struct_type_key__String(ptr %p_t) {
  %t = alloca ptr
  store ptr %p_t, ptr %t
  %t3247 = load ptr, ptr %t
  %t3248 = getelementptr inbounds [8 x i8], ptr @.str.s439, i64 0, i64 0
  %t3249 = call i32 @str_starts_with(ptr %t3247, ptr %t3248)
  %t3250 = icmp eq i32 %t3249, 1
  ret i1 %t3250
}

define ptr @struct_type_name__String(ptr %p_t) {
  %t = alloca ptr
  store ptr %p_t, ptr %t
  %t3252 = load ptr, ptr %t
  %t3253 = load ptr, ptr %t
  %t3254 = call i32 @str_length(ptr %t3253)
  %t3255 = sub i32 %t3254, 7
  %t3256 = call ptr @str_substring(ptr %t3252, i32 7, i32 %t3255)
  ret ptr %t3256
}

define ptr @llvm_type_name__String(ptr %p_t) {
  %t = alloca ptr
  store ptr %p_t, ptr %t
  %t3258 = load ptr, ptr %t
  %t3259 = call i1 @is_struct_type_key__String(ptr %t3258)
  br i1 %t3259, label %label_1170, label %label_1172
label_1170:
  %t3260 = getelementptr inbounds [2 x i8], ptr @.str.s440, i64 0, i64 0
  %t3261 = load ptr, ptr %t
  %t3262 = call ptr @struct_type_name__String(ptr %t3261)
  %t3263 = call ptr @str_concat(ptr %t3260, ptr %t3262)
  ret ptr %t3263
label_1172:
  %t3264 = load ptr, ptr %t
  ret ptr %t3264
}

define ptr @map_type_node__Struct_ASTNode(ptr %p_tn) {
  %tn = alloca ptr
  %elem = alloca ptr
  store ptr %p_tn, ptr %tn
  %t3267 = load ptr, ptr %tn
  %t3268 = getelementptr inbounds %ASTNode, ptr %t3267, i32 0, i32 4
  %t3269 = load i32, ptr %t3268
  %t3270 = icmp eq i32 %t3269, 1
  br i1 %t3270, label %label_1173, label %label_1175
label_1173:
  %t3271 = getelementptr inbounds [4 x i8], ptr @.str.s441, i64 0, i64 0
  ret ptr %t3271
label_1175:
  %t3272 = load ptr, ptr %tn
  %t3273 = getelementptr inbounds %ASTNode, ptr %t3272, i32 0, i32 3
  %t3274 = load i32, ptr %t3273
  %t3275 = icmp eq i32 %t3274, 1
  br i1 %t3275, label %label_1176, label %label_1178
label_1176:
  %t3276 = load ptr, ptr %tn
  %t3277 = getelementptr inbounds %ASTNode, ptr %t3276, i32 0, i32 5
  %t3278 = load ptr, ptr %t3277
  %t3279 = getelementptr inbounds [1 x i8], ptr @.str.s442, i64 0, i64 0
  %t3280 = call i32 @str_equals(ptr %t3278, ptr %t3279)
  %t3281 = icmp eq i32 %t3280, 0
  br i1 %t3281, label %label_1179, label %label_1181
label_1179:
  %t3282 = load ptr, ptr %tn
  %t3283 = getelementptr inbounds %ASTNode, ptr %t3282, i32 0, i32 5
  %t3284 = load ptr, ptr %t3283
  %t3285 = call ptr @ptr_to_node(ptr %t3284)
  store ptr %t3285, ptr %elem
  %t3286 = load ptr, ptr %elem
  %t3287 = getelementptr inbounds %ASTNode, ptr %t3286, i32 0, i32 3
  %t3288 = load i32, ptr %t3287
  %t3289 = icmp eq i32 %t3288, 1
  br i1 %t3289, label %label_1182, label %label_1184
label_1182:
  %t3290 = getelementptr inbounds [7 x i8], ptr @.str.s443, i64 0, i64 0
  ret ptr %t3290
label_1184:
  br label %label_1181
label_1181:
  %t3291 = getelementptr inbounds [4 x i8], ptr @.str.s444, i64 0, i64 0
  ret ptr %t3291
label_1178:
  %t3292 = load ptr, ptr %tn
  %t3293 = getelementptr inbounds %ASTNode, ptr %t3292, i32 0, i32 1
  %t3294 = load ptr, ptr %t3293
  %t3295 = call i32 @ir_is_struct_type_name(ptr %t3294)
  %t3296 = icmp eq i32 %t3295, 1
  br i1 %t3296, label %label_1185, label %label_1187
label_1185:
  %t3297 = load ptr, ptr %tn
  %t3298 = getelementptr inbounds %ASTNode, ptr %t3297, i32 0, i32 1
  %t3299 = load ptr, ptr %t3298
  %t3300 = call ptr @struct_type_key__String(ptr %t3299)
  ret ptr %t3300
label_1187:
  %t3301 = load ptr, ptr %tn
  %t3302 = getelementptr inbounds %ASTNode, ptr %t3301, i32 0, i32 1
  %t3303 = load ptr, ptr %t3302
  %t3304 = call ptr @map_type__String(ptr %t3303)
  ret ptr %t3304
}

define ptr @storage_type__String(ptr %p_t) {
  %t = alloca ptr
  store ptr %p_t, ptr %t
  %t3306 = load ptr, ptr %t
  %t3307 = getelementptr inbounds [7 x i8], ptr @.str.s445, i64 0, i64 0
  %t3308 = call i32 @str_equals(ptr %t3306, ptr %t3307)
  %t3309 = icmp eq i32 %t3308, 1
  br i1 %t3309, label %label_1188, label %label_1190
label_1188:
  %t3310 = getelementptr inbounds [4 x i8], ptr @.str.s446, i64 0, i64 0
  ret ptr %t3310
label_1190:
  %t3311 = load ptr, ptr %t
  %t3312 = call i1 @is_struct_type_key__String(ptr %t3311)
  br i1 %t3312, label %label_1191, label %label_1193
label_1191:
  %t3313 = getelementptr inbounds [4 x i8], ptr @.str.s447, i64 0, i64 0
  ret ptr %t3313
label_1193:
  %t3314 = load ptr, ptr %t
  ret ptr %t3314
}

define i32 @count_list_nodes__String(ptr %p_first_ptr) {
  %first_ptr = alloca ptr
  %count = alloca i32
  %curr = alloca ptr
  %node = alloca ptr
  store ptr %p_first_ptr, ptr %first_ptr
  store i32 0, ptr %count
  %t3319 = load ptr, ptr %first_ptr
  store ptr %t3319, ptr %curr
  br label %label_1194
label_1194:
  %t3320 = load ptr, ptr %curr
  %t3321 = getelementptr inbounds [1 x i8], ptr @.str.s448, i64 0, i64 0
  %t3322 = call i32 @str_equals(ptr %t3320, ptr %t3321)
  %t3323 = icmp eq i32 %t3322, 0
  br i1 %t3323, label %label_1195, label %label_1196
label_1195:
  %t3324 = load ptr, ptr %curr
  %t3325 = call ptr @ptr_to_node(ptr %t3324)
  store ptr %t3325, ptr %node
  %t3326 = load i32, ptr %count
  %t3327 = add i32 %t3326, 1
  store i32 %t3327, ptr %count
  %t3328 = load ptr, ptr %node
  %t3329 = getelementptr inbounds %ASTNode, ptr %t3328, i32 0, i32 8
  %t3330 = load ptr, ptr %t3329
  store ptr %t3330, ptr %curr
  br label %label_1194
label_1196:
  %t3331 = load i32, ptr %count
  ret i32 %t3331
}

define ptr @fn_key__String(ptr %p_name) {
  %name = alloca ptr
  store ptr %p_name, ptr %name
  %t3333 = getelementptr inbounds [5 x i8], ptr @.str.s449, i64 0, i64 0
  %t3334 = load ptr, ptr %name
  %t3335 = call ptr @str_concat(ptr %t3333, ptr %t3334)
  ret ptr %t3335
}

define ptr @function_symbol_name__Struct_ASTNode(ptr %p_func) {
  %func = alloca ptr
  store ptr %p_func, ptr %func
  %t3337 = load ptr, ptr %func
  %t3338 = getelementptr inbounds %ASTNode, ptr %t3337, i32 0, i32 2
  %t3339 = load ptr, ptr %t3338
  %t3340 = getelementptr inbounds [1 x i8], ptr @.str.s450, i64 0, i64 0
  %t3341 = call i32 @str_equals(ptr %t3339, ptr %t3340)
  %t3342 = icmp eq i32 %t3341, 0
  br i1 %t3342, label %label_1197, label %label_1199
label_1197:
  %t3343 = load ptr, ptr %func
  %t3344 = getelementptr inbounds %ASTNode, ptr %t3343, i32 0, i32 2
  %t3345 = load ptr, ptr %t3344
  ret ptr %t3345
label_1199:
  %t3346 = load ptr, ptr %func
  %t3347 = getelementptr inbounds %ASTNode, ptr %t3346, i32 0, i32 1
  %t3348 = load ptr, ptr %t3347
  ret ptr %t3348
}

define ptr @get_declared_return_type__Struct_ASTNode_String(ptr %p_node, ptr %p_ret_child) {
  %node = alloca ptr
  %ret_child = alloca ptr
  %ret_node = alloca ptr
  store ptr %p_node, ptr %node
  store ptr %p_ret_child, ptr %ret_child
  %t3352 = load ptr, ptr %ret_child
  %t3353 = getelementptr inbounds [1 x i8], ptr @.str.s451, i64 0, i64 0
  %t3354 = call i32 @str_equals(ptr %t3352, ptr %t3353)
  %t3355 = icmp eq i32 %t3354, 0
  br i1 %t3355, label %label_1200, label %label_1202
label_1200:
  %t3356 = load ptr, ptr %ret_child
  %t3357 = call ptr @ptr_to_node(ptr %t3356)
  store ptr %t3357, ptr %ret_node
  %t3358 = load ptr, ptr %ret_node
  %t3359 = call ptr @map_type_node__Struct_ASTNode(ptr %t3358)
  ret ptr %t3359
label_1202:
  %t3360 = getelementptr inbounds [5 x i8], ptr @.str.s452, i64 0, i64 0
  ret ptr %t3360
}

define ptr @get_expr_type__Struct_ASTNode(ptr %p_expr) {
  %expr = alloca ptr
  %op = alloca ptr
  %callee = alloca ptr
  %func_name = alloca ptr
  %obj_type = alloca ptr
  %object_node = alloca ptr
  %enum_val = alloca i32
  %object_type = alloca ptr
  store ptr %p_expr, ptr %expr
  %t3369 = load ptr, ptr %expr
  %t3370 = call i1 @node_has_type__Struct_ASTNode(ptr %t3369)
  br i1 %t3370, label %label_1203, label %label_1205
label_1203:
  %t3371 = load ptr, ptr %expr
  %t3372 = call ptr @node_get_type__Struct_ASTNode(ptr %t3371)
  %t3373 = call ptr @type_ir_key__Struct_TypeInfo(ptr %t3372)
  ret ptr %t3373
label_1205:
  %t3374 = load ptr, ptr %expr
  %t3375 = getelementptr inbounds %ASTNode, ptr %t3374, i32 0, i32 0
  %t3376 = load i32, ptr %t3375
  %t3377 = icmp eq i32 %t3376, 22
  br i1 %t3377, label %label_1206, label %label_1208
label_1206:
  %t3378 = load ptr, ptr %expr
  %t3379 = getelementptr inbounds %ASTNode, ptr %t3378, i32 0, i32 3
  %t3380 = load i32, ptr %t3379
  %t3381 = icmp eq i32 %t3380, 2
  br i1 %t3381, label %label_1209, label %label_1211
label_1209:
  %t3382 = getelementptr inbounds [4 x i8], ptr @.str.s453, i64 0, i64 0
  ret ptr %t3382
label_1211:
  %t3383 = load ptr, ptr %expr
  %t3384 = getelementptr inbounds %ASTNode, ptr %t3383, i32 0, i32 3
  %t3385 = load i32, ptr %t3384
  %t3386 = icmp eq i32 %t3385, 3
  br i1 %t3386, label %label_1212, label %label_1214
label_1212:
  %t3387 = getelementptr inbounds [7 x i8], ptr @.str.s454, i64 0, i64 0
  ret ptr %t3387
label_1214:
  %t3388 = load ptr, ptr %expr
  %t3389 = getelementptr inbounds %ASTNode, ptr %t3388, i32 0, i32 3
  %t3390 = load i32, ptr %t3389
  %t3391 = icmp eq i32 %t3390, 4
  br i1 %t3391, label %label_1215, label %label_1217
label_1215:
  %t3392 = getelementptr inbounds [3 x i8], ptr @.str.s455, i64 0, i64 0
  ret ptr %t3392
label_1217:
  %t3393 = load ptr, ptr %expr
  %t3394 = getelementptr inbounds %ASTNode, ptr %t3393, i32 0, i32 3
  %t3395 = load i32, ptr %t3394
  %t3396 = icmp eq i32 %t3395, 1
  br i1 %t3396, label %label_1218, label %label_1220
label_1218:
  %t3397 = getelementptr inbounds [3 x i8], ptr @.str.s456, i64 0, i64 0
  ret ptr %t3397
label_1220:
  %t3398 = load ptr, ptr %expr
  %t3399 = getelementptr inbounds %ASTNode, ptr %t3398, i32 0, i32 3
  %t3400 = load i32, ptr %t3399
  %t3401 = icmp eq i32 %t3400, 0
  br i1 %t3401, label %label_1221, label %label_1223
label_1221:
  %t3402 = getelementptr inbounds [4 x i8], ptr @.str.s457, i64 0, i64 0
  ret ptr %t3402
label_1223:
  br label %label_1208
label_1208:
  %t3403 = load ptr, ptr %expr
  %t3404 = getelementptr inbounds %ASTNode, ptr %t3403, i32 0, i32 0
  %t3405 = load i32, ptr %t3404
  %t3406 = icmp eq i32 %t3405, 23
  br i1 %t3406, label %label_1224, label %label_1226
label_1224:
  %t3407 = load ptr, ptr %expr
  %t3408 = getelementptr inbounds %ASTNode, ptr %t3407, i32 0, i32 1
  %t3409 = load ptr, ptr %t3408
  %t3410 = call ptr @ir_get_var_type(ptr %t3409)
  ret ptr %t3410
label_1226:
  %t3411 = load ptr, ptr %expr
  %t3412 = getelementptr inbounds %ASTNode, ptr %t3411, i32 0, i32 0
  %t3413 = load i32, ptr %t3412
  %t3414 = icmp eq i32 %t3413, 20
  br i1 %t3414, label %label_1227, label %label_1229
label_1227:
  %t3415 = load ptr, ptr %expr
  %t3416 = getelementptr inbounds %ASTNode, ptr %t3415, i32 0, i32 1
  %t3417 = load ptr, ptr %t3416
  store ptr %t3417, ptr %op
  %t3418 = load ptr, ptr %op
  %t3419 = getelementptr inbounds [3 x i8], ptr @.str.s458, i64 0, i64 0
  %t3420 = call i32 @str_equals(ptr %t3418, ptr %t3419)
  %t3421 = icmp eq i32 %t3420, 1
  %t3422 = load ptr, ptr %op
  %t3423 = getelementptr inbounds [3 x i8], ptr @.str.s459, i64 0, i64 0
  %t3424 = call i32 @str_equals(ptr %t3422, ptr %t3423)
  %t3425 = icmp eq i32 %t3424, 1
  %t3426 = or i1 %t3421, %t3425
  br i1 %t3426, label %label_1230, label %label_1232
label_1230:
  %t3427 = getelementptr inbounds [3 x i8], ptr @.str.s460, i64 0, i64 0
  ret ptr %t3427
label_1232:
  %t3428 = load ptr, ptr %op
  %t3429 = getelementptr inbounds [2 x i8], ptr @.str.s461, i64 0, i64 0
  %t3430 = call i32 @str_equals(ptr %t3428, ptr %t3429)
  %t3431 = icmp eq i32 %t3430, 1
  %t3432 = load ptr, ptr %op
  %t3433 = getelementptr inbounds [3 x i8], ptr @.str.s462, i64 0, i64 0
  %t3434 = call i32 @str_equals(ptr %t3432, ptr %t3433)
  %t3435 = icmp eq i32 %t3434, 1
  %t3436 = or i1 %t3431, %t3435
  br i1 %t3436, label %label_1233, label %label_1235
label_1233:
  %t3437 = getelementptr inbounds [3 x i8], ptr @.str.s463, i64 0, i64 0
  ret ptr %t3437
label_1235:
  %t3438 = load ptr, ptr %op
  %t3439 = getelementptr inbounds [2 x i8], ptr @.str.s464, i64 0, i64 0
  %t3440 = call i32 @str_equals(ptr %t3438, ptr %t3439)
  %t3441 = icmp eq i32 %t3440, 1
  %t3442 = load ptr, ptr %op
  %t3443 = getelementptr inbounds [3 x i8], ptr @.str.s465, i64 0, i64 0
  %t3444 = call i32 @str_equals(ptr %t3442, ptr %t3443)
  %t3445 = icmp eq i32 %t3444, 1
  %t3446 = or i1 %t3441, %t3445
  br i1 %t3446, label %label_1236, label %label_1238
label_1236:
  %t3447 = getelementptr inbounds [3 x i8], ptr @.str.s466, i64 0, i64 0
  ret ptr %t3447
label_1238:
  %t3448 = load ptr, ptr %op
  %t3449 = getelementptr inbounds [4 x i8], ptr @.str.s467, i64 0, i64 0
  %t3450 = call i32 @str_equals(ptr %t3448, ptr %t3449)
  %t3451 = icmp eq i32 %t3450, 1
  %t3452 = load ptr, ptr %op
  %t3453 = getelementptr inbounds [3 x i8], ptr @.str.s468, i64 0, i64 0
  %t3454 = call i32 @str_equals(ptr %t3452, ptr %t3453)
  %t3455 = icmp eq i32 %t3454, 1
  %t3456 = or i1 %t3451, %t3455
  br i1 %t3456, label %label_1239, label %label_1241
label_1239:
  %t3457 = getelementptr inbounds [3 x i8], ptr @.str.s469, i64 0, i64 0
  ret ptr %t3457
label_1241:
  %t3458 = load ptr, ptr %expr
  %t3459 = getelementptr inbounds %ASTNode, ptr %t3458, i32 0, i32 5
  %t3460 = load ptr, ptr %t3459
  %t3461 = call ptr @ptr_to_node(ptr %t3460)
  %t3462 = call ptr @get_expr_type__Struct_ASTNode(ptr %t3461)
  ret ptr %t3462
label_1229:
  %t3463 = load ptr, ptr %expr
  %t3464 = getelementptr inbounds %ASTNode, ptr %t3463, i32 0, i32 0
  %t3465 = load i32, ptr %t3464
  %t3466 = icmp eq i32 %t3465, 24
  br i1 %t3466, label %label_1242, label %label_1244
label_1242:
  %t3467 = load ptr, ptr %expr
  %t3468 = getelementptr inbounds %ASTNode, ptr %t3467, i32 0, i32 5
  %t3469 = load ptr, ptr %t3468
  %t3470 = call ptr @ptr_to_node(ptr %t3469)
  store ptr %t3470, ptr %callee
  %t3471 = load ptr, ptr %callee
  %t3472 = getelementptr inbounds %ASTNode, ptr %t3471, i32 0, i32 1
  %t3473 = load ptr, ptr %t3472
  store ptr %t3473, ptr %func_name
  %t3474 = load ptr, ptr %func_name
  %t3475 = getelementptr inbounds [6 x i8], ptr @.str.s470, i64 0, i64 0
  %t3476 = call i32 @str_equals(ptr %t3474, ptr %t3475)
  %t3477 = icmp eq i32 %t3476, 1
  %t3478 = load ptr, ptr %func_name
  %t3479 = getelementptr inbounds [8 x i8], ptr @.str.s471, i64 0, i64 0
  %t3480 = call i32 @str_equals(ptr %t3478, ptr %t3479)
  %t3481 = icmp eq i32 %t3480, 1
  %t3482 = or i1 %t3477, %t3481
  br i1 %t3482, label %label_1245, label %label_1247
label_1245:
  %t3483 = getelementptr inbounds [5 x i8], ptr @.str.s472, i64 0, i64 0
  ret ptr %t3483
label_1247:
  %t3484 = load ptr, ptr %func_name
  %t3485 = getelementptr inbounds [10 x i8], ptr @.str.s473, i64 0, i64 0
  %t3486 = call i32 @str_equals(ptr %t3484, ptr %t3485)
  %t3487 = icmp eq i32 %t3486, 1
  %t3488 = load ptr, ptr %func_name
  %t3489 = getelementptr inbounds [12 x i8], ptr @.str.s474, i64 0, i64 0
  %t3490 = call i32 @str_equals(ptr %t3488, ptr %t3489)
  %t3491 = icmp eq i32 %t3490, 1
  %t3492 = or i1 %t3487, %t3491
  br i1 %t3492, label %label_1248, label %label_1250
label_1248:
  %t3493 = getelementptr inbounds [5 x i8], ptr @.str.s475, i64 0, i64 0
  ret ptr %t3493
label_1250:
  %t3494 = load ptr, ptr %func_name
  %t3495 = getelementptr inbounds [12 x i8], ptr @.str.s476, i64 0, i64 0
  %t3496 = call i32 @str_equals(ptr %t3494, ptr %t3495)
  %t3497 = icmp eq i32 %t3496, 1
  %t3498 = load ptr, ptr %func_name
  %t3499 = getelementptr inbounds [14 x i8], ptr @.str.s477, i64 0, i64 0
  %t3500 = call i32 @str_equals(ptr %t3498, ptr %t3499)
  %t3501 = icmp eq i32 %t3500, 1
  %t3502 = or i1 %t3497, %t3501
  br i1 %t3502, label %label_1251, label %label_1253
label_1251:
  %t3503 = getelementptr inbounds [5 x i8], ptr @.str.s478, i64 0, i64 0
  ret ptr %t3503
label_1253:
  %t3504 = load ptr, ptr %func_name
  %t3505 = getelementptr inbounds [13 x i8], ptr @.str.s479, i64 0, i64 0
  %t3506 = call i32 @str_equals(ptr %t3504, ptr %t3505)
  %t3507 = icmp eq i32 %t3506, 1
  %t3508 = load ptr, ptr %func_name
  %t3509 = getelementptr inbounds [11 x i8], ptr @.str.s480, i64 0, i64 0
  %t3510 = call i32 @str_equals(ptr %t3508, ptr %t3509)
  %t3511 = icmp eq i32 %t3510, 1
  %t3512 = or i1 %t3507, %t3511
  br i1 %t3512, label %label_1254, label %label_1256
label_1254:
  %t3513 = getelementptr inbounds [5 x i8], ptr @.str.s481, i64 0, i64 0
  ret ptr %t3513
label_1256:
  %t3514 = load ptr, ptr %func_name
  %t3515 = getelementptr inbounds [13 x i8], ptr @.str.s482, i64 0, i64 0
  %t3516 = call i32 @str_equals(ptr %t3514, ptr %t3515)
  %t3517 = icmp eq i32 %t3516, 1
  %t3518 = load ptr, ptr %func_name
  %t3519 = getelementptr inbounds [11 x i8], ptr @.str.s483, i64 0, i64 0
  %t3520 = call i32 @str_equals(ptr %t3518, ptr %t3519)
  %t3521 = icmp eq i32 %t3520, 1
  %t3522 = or i1 %t3517, %t3521
  br i1 %t3522, label %label_1257, label %label_1259
label_1257:
  %t3523 = getelementptr inbounds [5 x i8], ptr @.str.s484, i64 0, i64 0
  ret ptr %t3523
label_1259:
  %t3524 = load ptr, ptr %expr
  %t3525 = getelementptr inbounds %ASTNode, ptr %t3524, i32 0, i32 2
  %t3526 = load ptr, ptr %t3525
  %t3527 = getelementptr inbounds [1 x i8], ptr @.str.s485, i64 0, i64 0
  %t3528 = call i32 @str_equals(ptr %t3526, ptr %t3527)
  %t3529 = icmp eq i32 %t3528, 0
  br i1 %t3529, label %label_1260, label %label_1262
label_1260:
  %t3530 = load ptr, ptr %expr
  %t3531 = getelementptr inbounds %ASTNode, ptr %t3530, i32 0, i32 2
  %t3532 = load ptr, ptr %t3531
  %t3533 = call ptr @fn_key__String(ptr %t3532)
  %t3534 = call ptr @ir_get_var_type(ptr %t3533)
  ret ptr %t3534
label_1262:
  %t3535 = load ptr, ptr %func_name
  %t3536 = call ptr @fn_key__String(ptr %t3535)
  %t3537 = call ptr @ir_get_var_type(ptr %t3536)
  ret ptr %t3537
label_1244:
  %t3538 = load ptr, ptr %expr
  %t3539 = getelementptr inbounds %ASTNode, ptr %t3538, i32 0, i32 0
  %t3540 = load i32, ptr %t3539
  %t3541 = icmp eq i32 %t3540, 26
  br i1 %t3541, label %label_1263, label %label_1265
label_1263:
  %t3542 = load ptr, ptr %expr
  %t3543 = getelementptr inbounds %ASTNode, ptr %t3542, i32 0, i32 5
  %t3544 = load ptr, ptr %t3543
  %t3545 = call ptr @ptr_to_node(ptr %t3544)
  %t3546 = call ptr @get_expr_type__Struct_ASTNode(ptr %t3545)
  store ptr %t3546, ptr %obj_type
  %t3547 = load ptr, ptr %obj_type
  %t3548 = getelementptr inbounds [7 x i8], ptr @.str.s486, i64 0, i64 0
  %t3549 = call i32 @str_equals(ptr %t3547, ptr %t3548)
  %t3550 = icmp eq i32 %t3549, 1
  br i1 %t3550, label %label_1266, label %label_1268
label_1266:
  %t3551 = getelementptr inbounds [4 x i8], ptr @.str.s487, i64 0, i64 0
  ret ptr %t3551
label_1268:
  %t3552 = getelementptr inbounds [4 x i8], ptr @.str.s488, i64 0, i64 0
  ret ptr %t3552
label_1265:
  %t3553 = load ptr, ptr %expr
  %t3554 = getelementptr inbounds %ASTNode, ptr %t3553, i32 0, i32 0
  %t3555 = load i32, ptr %t3554
  %t3556 = icmp eq i32 %t3555, 25
  br i1 %t3556, label %label_1269, label %label_1271
label_1269:
  %t3557 = load ptr, ptr %expr
  %t3558 = getelementptr inbounds %ASTNode, ptr %t3557, i32 0, i32 5
  %t3559 = load ptr, ptr %t3558
  %t3560 = call ptr @ptr_to_node(ptr %t3559)
  store ptr %t3560, ptr %object_node
  %t3561 = load ptr, ptr %object_node
  %t3562 = getelementptr inbounds %ASTNode, ptr %t3561, i32 0, i32 0
  %t3563 = load i32, ptr %t3562
  %t3564 = icmp eq i32 %t3563, 23
  br i1 %t3564, label %label_1272, label %label_1274
label_1272:
  %t3565 = load ptr, ptr %object_node
  %t3566 = getelementptr inbounds %ASTNode, ptr %t3565, i32 0, i32 1
  %t3567 = load ptr, ptr %t3566
  %t3568 = load ptr, ptr %expr
  %t3569 = getelementptr inbounds %ASTNode, ptr %t3568, i32 0, i32 1
  %t3570 = load ptr, ptr %t3569
  %t3571 = call i32 @ir_get_enum_variant(ptr %t3567, ptr %t3570)
  store i32 %t3571, ptr %enum_val
  %t3572 = load i32, ptr %enum_val
  %t3573 = icmp sge i32 %t3572, 0
  br i1 %t3573, label %label_1275, label %label_1277
label_1275:
  %t3574 = getelementptr inbounds [4 x i8], ptr @.str.s489, i64 0, i64 0
  ret ptr %t3574
label_1277:
  br label %label_1274
label_1274:
  %t3575 = load ptr, ptr %object_node
  %t3576 = call ptr @get_expr_type__Struct_ASTNode(ptr %t3575)
  store ptr %t3576, ptr %object_type
  %t3577 = load ptr, ptr %object_type
  %t3578 = call i1 @is_struct_type_key__String(ptr %t3577)
  br i1 %t3578, label %label_1278, label %label_1280
label_1278:
  %t3579 = load ptr, ptr %object_type
  %t3580 = call ptr @struct_type_name__String(ptr %t3579)
  %t3581 = load ptr, ptr %expr
  %t3582 = getelementptr inbounds %ASTNode, ptr %t3581, i32 0, i32 1
  %t3583 = load ptr, ptr %t3582
  %t3584 = call ptr @ir_get_struct_field_type(ptr %t3580, ptr %t3583)
  ret ptr %t3584
label_1280:
  %t3585 = getelementptr inbounds [4 x i8], ptr @.str.s490, i64 0, i64 0
  ret ptr %t3585
label_1271:
  %t3586 = load ptr, ptr %expr
  %t3587 = getelementptr inbounds %ASTNode, ptr %t3586, i32 0, i32 0
  %t3588 = load i32, ptr %t3587
  %t3589 = icmp eq i32 %t3588, 27
  br i1 %t3589, label %label_1281, label %label_1283
label_1281:
  %t3590 = getelementptr inbounds [4 x i8], ptr @.str.s491, i64 0, i64 0
  ret ptr %t3590
label_1283:
  %t3591 = load ptr, ptr %expr
  %t3592 = getelementptr inbounds %ASTNode, ptr %t3591, i32 0, i32 0
  %t3593 = load i32, ptr %t3592
  %t3594 = icmp eq i32 %t3593, 28
  br i1 %t3594, label %label_1284, label %label_1286
label_1284:
  %t3595 = load ptr, ptr %expr
  %t3596 = getelementptr inbounds %ASTNode, ptr %t3595, i32 0, i32 1
  %t3597 = load ptr, ptr %t3596
  %t3598 = call ptr @struct_type_key__String(ptr %t3597)
  ret ptr %t3598
label_1286:
  %t3599 = getelementptr inbounds [4 x i8], ptr @.str.s492, i64 0, i64 0
  ret ptr %t3599
}

define ptr @generate_expression__Struct_ASTNode(ptr %p_expr) {
  %expr = alloca ptr
  %str_name = alloca ptr
  %str_len = alloca i32
  %len_plus_one = alloca i32
  %temp = alloca i32
  %tname = alloca ptr
  %struct_name = alloca ptr
  %size_ptr_temp = alloca i32
  %size_ptr_name = alloca ptr
  %size_temp = alloca i32
  %size_name = alloca ptr
  %mem_temp = alloca i32
  %mem_name = alloca ptr
  %field_ptr = alloca ptr
  %field = alloca ptr
  %field_val = alloca ptr
  %field_type = alloca ptr
  %field_index = alloca i32
  %gep_temp = alloca i32
  %gep_name = alloca ptr
  %val_type = alloca ptr
  %load_type = alloca ptr
  %temp_id = alloca i32
  %object_node = alloca ptr
  %enum_val = alloca i32
  %object_val = alloca ptr
  %object_type = alloca ptr
  %load_temp = alloca i32
  %load_name = alloca ptr
  %elem_count = alloca i32
  %first_elem = alloca ptr
  %is_nested = alloca i32
  %arr_temp = alloca i32
  %arr_name = alloca ptr
  %elem_ptr = alloca ptr
  %elem_index = alloca i32
  %elem_node = alloca ptr
  %inner_ptr = alloca ptr
  %slot_temp = alloca i32
  %slot_name = alloca ptr
  %ret_temp = alloca i32
  %ret_name = alloca ptr
  %arr_temp2 = alloca i32
  %arr_name2 = alloca ptr
  %elem_ptr2 = alloca ptr
  %elem_index2 = alloca i32
  %elem_node2 = alloca ptr
  %elem_val = alloca ptr
  %elem_slot_temp = alloca i32
  %elem_slot_name = alloca ptr
  %ret_temp2 = alloca i32
  %ret_name2 = alloca ptr
  %array_val = alloca ptr
  %index_val = alloca ptr
  %obj_type = alloca ptr
  %elem_type = alloca ptr
  %ptr_temp = alloca i32
  %ptr_name = alloca ptr
  %left_val = alloca ptr
  %right_val = alloca ptr
  %op = alloca ptr
  %left_node = alloca ptr
  %op_type = alloca ptr
  %is_unsigned = alloca i1
  %callee = alloca ptr
  %func_name = alloca ptr
  %drop_arg = alloca ptr
  %drop_val = alloca ptr
  %is_print = alloca i32
  %arg_ptr = alloca ptr
  %arg_node = alloca ptr
  %arg_val = alloca ptr
  %arg_type = alloca ptr
  %call_name = alloca ptr
  %ret_type = alloca ptr
  store ptr %p_expr, ptr %expr
  %t3675 = load ptr, ptr %expr
  %t3676 = getelementptr inbounds %ASTNode, ptr %t3675, i32 0, i32 0
  %t3677 = load i32, ptr %t3676
  %t3678 = icmp eq i32 %t3677, 22
  br i1 %t3678, label %label_1287, label %label_1289
label_1287:
  %t3679 = load ptr, ptr %expr
  %t3680 = getelementptr inbounds %ASTNode, ptr %t3679, i32 0, i32 3
  %t3681 = load i32, ptr %t3680
  %t3682 = icmp eq i32 %t3681, 2
  br i1 %t3682, label %label_1290, label %label_1292
label_1290:
  %t3683 = load ptr, ptr %expr
  %t3684 = getelementptr inbounds %ASTNode, ptr %t3683, i32 0, i32 1
  %t3685 = load ptr, ptr %t3684
  ret ptr %t3685
label_1292:
  %t3686 = load ptr, ptr %expr
  %t3687 = getelementptr inbounds %ASTNode, ptr %t3686, i32 0, i32 3
  %t3688 = load i32, ptr %t3687
  %t3689 = icmp eq i32 %t3688, 3
  br i1 %t3689, label %label_1293, label %label_1295
label_1293:
  %t3690 = load ptr, ptr %expr
  %t3691 = getelementptr inbounds %ASTNode, ptr %t3690, i32 0, i32 1
  %t3692 = load ptr, ptr %t3691
  ret ptr %t3692
label_1295:
  %t3693 = load ptr, ptr %expr
  %t3694 = getelementptr inbounds %ASTNode, ptr %t3693, i32 0, i32 3
  %t3695 = load i32, ptr %t3694
  %t3696 = icmp eq i32 %t3695, 4
  br i1 %t3696, label %label_1296, label %label_1298
label_1296:
  %t3697 = load ptr, ptr %expr
  %t3698 = getelementptr inbounds %ASTNode, ptr %t3697, i32 0, i32 1
  %t3699 = load ptr, ptr %t3698
  %t3700 = getelementptr inbounds [5 x i8], ptr @.str.s493, i64 0, i64 0
  %t3701 = call i32 @str_equals(ptr %t3699, ptr %t3700)
  %t3702 = icmp eq i32 %t3701, 1
  br i1 %t3702, label %label_1299, label %label_1301
label_1299:
  %t3703 = getelementptr inbounds [2 x i8], ptr @.str.s494, i64 0, i64 0
  ret ptr %t3703
label_1301:
  %t3704 = getelementptr inbounds [2 x i8], ptr @.str.s495, i64 0, i64 0
  ret ptr %t3704
label_1298:
  %t3705 = load ptr, ptr %expr
  %t3706 = getelementptr inbounds %ASTNode, ptr %t3705, i32 0, i32 3
  %t3707 = load i32, ptr %t3706
  %t3708 = icmp eq i32 %t3707, 1
  br i1 %t3708, label %label_1302, label %label_1304
label_1302:
  %t3709 = load ptr, ptr %expr
  %t3710 = getelementptr inbounds %ASTNode, ptr %t3709, i32 0, i32 1
  %t3711 = load ptr, ptr %t3710
  ret ptr %t3711
label_1304:
  %t3712 = load ptr, ptr %expr
  %t3713 = getelementptr inbounds %ASTNode, ptr %t3712, i32 0, i32 3
  %t3714 = load i32, ptr %t3713
  %t3715 = icmp eq i32 %t3714, 0
  br i1 %t3715, label %label_1305, label %label_1307
label_1305:
  %t3716 = load ptr, ptr %expr
  %t3717 = getelementptr inbounds %ASTNode, ptr %t3716, i32 0, i32 2
  %t3718 = load ptr, ptr %t3717
  store ptr %t3718, ptr %str_name
  %t3719 = load ptr, ptr %expr
  %t3720 = getelementptr inbounds %ASTNode, ptr %t3719, i32 0, i32 1
  %t3721 = load ptr, ptr %t3720
  %t3722 = call i32 @str_length(ptr %t3721)
  store i32 %t3722, ptr %str_len
  %t3723 = load i32, ptr %str_len
  %t3724 = add i32 %t3723, 1
  store i32 %t3724, ptr %len_plus_one
  %t3725 = call i32 @ir_get_temp()
  store i32 %t3725, ptr %temp
  %t3726 = load i32, ptr %temp
  %t3727 = call ptr @ir_get_temp_name(i32 %t3726)
  store ptr %t3727, ptr %tname
  %t3728 = getelementptr inbounds [3 x i8], ptr @.str.s496, i64 0, i64 0
  call void @ir_append(ptr %t3728)
  %t3729 = load ptr, ptr %tname
  call void @ir_append(ptr %t3729)
  %t3730 = getelementptr inbounds [28 x i8], ptr @.str.s497, i64 0, i64 0
  call void @ir_append(ptr %t3730)
  %t3731 = load i32, ptr %len_plus_one
  %t3732 = call ptr @int_to_str(i32 %t3731)
  call void @ir_append(ptr %t3732)
  %t3733 = getelementptr inbounds [14 x i8], ptr @.str.s498, i64 0, i64 0
  call void @ir_append(ptr %t3733)
  %t3734 = load ptr, ptr %str_name
  call void @ir_append(ptr %t3734)
  %t3735 = getelementptr inbounds [3 x i8], ptr @.str.s499, i64 0, i64 0
  call void @ir_append(ptr %t3735)
  %t3736 = call ptr @ir_ptr_int_type__Void()
  call void @ir_append(ptr %t3736)
  %t3737 = getelementptr inbounds [5 x i8], ptr @.str.s500, i64 0, i64 0
  call void @ir_append(ptr %t3737)
  %t3738 = call ptr @ir_ptr_int_type__Void()
  call void @ir_append(ptr %t3738)
  %t3739 = getelementptr inbounds [3 x i8], ptr @.str.s501, i64 0, i64 0
  call void @ir_append_line(ptr %t3739)
  %t3740 = load ptr, ptr %tname
  ret ptr %t3740
label_1307:
  br label %label_1289
label_1289:
  %t3741 = load ptr, ptr %expr
  %t3742 = getelementptr inbounds %ASTNode, ptr %t3741, i32 0, i32 0
  %t3743 = load i32, ptr %t3742
  %t3744 = icmp eq i32 %t3743, 28
  br i1 %t3744, label %label_1308, label %label_1310
label_1308:
  %t3745 = load ptr, ptr %expr
  %t3746 = getelementptr inbounds %ASTNode, ptr %t3745, i32 0, i32 1
  %t3747 = load ptr, ptr %t3746
  store ptr %t3747, ptr %struct_name
  %t3748 = call i32 @ir_get_temp()
  store i32 %t3748, ptr %size_ptr_temp
  %t3749 = load i32, ptr %size_ptr_temp
  %t3750 = call ptr @ir_get_temp_name(i32 %t3749)
  store ptr %t3750, ptr %size_ptr_name
  %t3751 = getelementptr inbounds [3 x i8], ptr @.str.s502, i64 0, i64 0
  call void @ir_append(ptr %t3751)
  %t3752 = load ptr, ptr %size_ptr_name
  call void @ir_append(ptr %t3752)
  %t3753 = getelementptr inbounds [18 x i8], ptr @.str.s503, i64 0, i64 0
  call void @ir_append(ptr %t3753)
  %t3754 = getelementptr inbounds [2 x i8], ptr @.str.s504, i64 0, i64 0
  %t3755 = load ptr, ptr %struct_name
  %t3756 = call ptr @str_concat(ptr %t3754, ptr %t3755)
  call void @ir_append(ptr %t3756)
  %t3757 = getelementptr inbounds [18 x i8], ptr @.str.s505, i64 0, i64 0
  call void @ir_append_line(ptr %t3757)
  %t3758 = call i32 @ir_get_temp()
  store i32 %t3758, ptr %size_temp
  %t3759 = load i32, ptr %size_temp
  %t3760 = call ptr @ir_get_temp_name(i32 %t3759)
  store ptr %t3760, ptr %size_name
  %t3761 = getelementptr inbounds [3 x i8], ptr @.str.s506, i64 0, i64 0
  call void @ir_append(ptr %t3761)
  %t3762 = load ptr, ptr %size_name
  call void @ir_append(ptr %t3762)
  %t3763 = getelementptr inbounds [17 x i8], ptr @.str.s507, i64 0, i64 0
  call void @ir_append(ptr %t3763)
  %t3764 = load ptr, ptr %size_ptr_name
  call void @ir_append(ptr %t3764)
  %t3765 = getelementptr inbounds [5 x i8], ptr @.str.s508, i64 0, i64 0
  call void @ir_append(ptr %t3765)
  %t3766 = call ptr @ir_ptr_int_type__Void()
  call void @ir_append_line(ptr %t3766)
  %t3767 = call i32 @ir_get_temp()
  store i32 %t3767, ptr %mem_temp
  %t3768 = load i32, ptr %mem_temp
  %t3769 = call ptr @ir_get_temp_name(i32 %t3768)
  store ptr %t3769, ptr %mem_name
  %t3770 = getelementptr inbounds [3 x i8], ptr @.str.s509, i64 0, i64 0
  call void @ir_append(ptr %t3770)
  %t3771 = load ptr, ptr %mem_name
  call void @ir_append(ptr %t3771)
  %t3772 = getelementptr inbounds [21 x i8], ptr @.str.s510, i64 0, i64 0
  call void @ir_append(ptr %t3772)
  %t3773 = call ptr @ir_ptr_int_type__Void()
  call void @ir_append(ptr %t3773)
  %t3774 = getelementptr inbounds [2 x i8], ptr @.str.s511, i64 0, i64 0
  call void @ir_append(ptr %t3774)
  %t3775 = load ptr, ptr %size_name
  call void @ir_append(ptr %t3775)
  %t3776 = getelementptr inbounds [2 x i8], ptr @.str.s512, i64 0, i64 0
  call void @ir_append_line(ptr %t3776)
  %t3777 = load ptr, ptr %expr
  %t3778 = getelementptr inbounds %ASTNode, ptr %t3777, i32 0, i32 5
  %t3779 = load ptr, ptr %t3778
  store ptr %t3779, ptr %field_ptr
  br label %label_1311
label_1311:
  %t3780 = load ptr, ptr %field_ptr
  %t3781 = getelementptr inbounds [1 x i8], ptr @.str.s513, i64 0, i64 0
  %t3782 = call i32 @str_equals(ptr %t3780, ptr %t3781)
  %t3783 = icmp eq i32 %t3782, 0
  br i1 %t3783, label %label_1312, label %label_1313
label_1312:
  %t3784 = load ptr, ptr %field_ptr
  %t3785 = call ptr @ptr_to_node(ptr %t3784)
  store ptr %t3785, ptr %field
  %t3786 = load ptr, ptr %field
  %t3787 = getelementptr inbounds %ASTNode, ptr %t3786, i32 0, i32 5
  %t3788 = load ptr, ptr %t3787
  %t3789 = call ptr @ptr_to_node(ptr %t3788)
  %t3790 = call ptr @generate_expression__Struct_ASTNode(ptr %t3789)
  store ptr %t3790, ptr %field_val
  %t3791 = load ptr, ptr %struct_name
  %t3792 = load ptr, ptr %field
  %t3793 = getelementptr inbounds %ASTNode, ptr %t3792, i32 0, i32 1
  %t3794 = load ptr, ptr %t3793
  %t3795 = call ptr @ir_get_struct_field_type(ptr %t3791, ptr %t3794)
  %t3796 = call ptr @storage_type__String(ptr %t3795)
  store ptr %t3796, ptr %field_type
  %t3797 = load ptr, ptr %struct_name
  %t3798 = load ptr, ptr %field
  %t3799 = getelementptr inbounds %ASTNode, ptr %t3798, i32 0, i32 1
  %t3800 = load ptr, ptr %t3799
  %t3801 = call i32 @ir_get_struct_field_index(ptr %t3797, ptr %t3800)
  store i32 %t3801, ptr %field_index
  %t3802 = call i32 @ir_get_temp()
  store i32 %t3802, ptr %gep_temp
  %t3803 = load i32, ptr %gep_temp
  %t3804 = call ptr @ir_get_temp_name(i32 %t3803)
  store ptr %t3804, ptr %gep_name
  %t3805 = getelementptr inbounds [3 x i8], ptr @.str.s514, i64 0, i64 0
  call void @ir_append(ptr %t3805)
  %t3806 = load ptr, ptr %gep_name
  call void @ir_append(ptr %t3806)
  %t3807 = getelementptr inbounds [27 x i8], ptr @.str.s515, i64 0, i64 0
  call void @ir_append(ptr %t3807)
  %t3808 = getelementptr inbounds [2 x i8], ptr @.str.s516, i64 0, i64 0
  %t3809 = load ptr, ptr %struct_name
  %t3810 = call ptr @str_concat(ptr %t3808, ptr %t3809)
  call void @ir_append(ptr %t3810)
  %t3811 = getelementptr inbounds [7 x i8], ptr @.str.s517, i64 0, i64 0
  call void @ir_append(ptr %t3811)
  %t3812 = load ptr, ptr %mem_name
  call void @ir_append(ptr %t3812)
  %t3813 = getelementptr inbounds [14 x i8], ptr @.str.s518, i64 0, i64 0
  call void @ir_append(ptr %t3813)
  %t3814 = load i32, ptr %field_index
  %t3815 = call ptr @int_to_str(i32 %t3814)
  call void @ir_append_line(ptr %t3815)
  %t3816 = getelementptr inbounds [9 x i8], ptr @.str.s519, i64 0, i64 0
  call void @ir_append(ptr %t3816)
  %t3817 = load ptr, ptr %field_type
  call void @ir_append(ptr %t3817)
  %t3818 = getelementptr inbounds [2 x i8], ptr @.str.s520, i64 0, i64 0
  call void @ir_append(ptr %t3818)
  %t3819 = load ptr, ptr %field_val
  call void @ir_append(ptr %t3819)
  %t3820 = getelementptr inbounds [7 x i8], ptr @.str.s521, i64 0, i64 0
  call void @ir_append(ptr %t3820)
  %t3821 = load ptr, ptr %gep_name
  call void @ir_append_line(ptr %t3821)
  %t3822 = load ptr, ptr %field
  %t3823 = getelementptr inbounds %ASTNode, ptr %t3822, i32 0, i32 8
  %t3824 = load ptr, ptr %t3823
  store ptr %t3824, ptr %field_ptr
  br label %label_1311
label_1313:
  %t3825 = load ptr, ptr %mem_name
  ret ptr %t3825
label_1310:
  %t3826 = load ptr, ptr %expr
  %t3827 = getelementptr inbounds %ASTNode, ptr %t3826, i32 0, i32 0
  %t3828 = load i32, ptr %t3827
  %t3829 = icmp eq i32 %t3828, 23
  br i1 %t3829, label %label_1314, label %label_1316
label_1314:
  %t3830 = load ptr, ptr %expr
  %t3831 = getelementptr inbounds %ASTNode, ptr %t3830, i32 0, i32 1
  %t3832 = load ptr, ptr %t3831
  %t3833 = call ptr @ir_get_var_type(ptr %t3832)
  store ptr %t3833, ptr %val_type
  %t3834 = load ptr, ptr %val_type
  %t3835 = call ptr @storage_type__String(ptr %t3834)
  store ptr %t3835, ptr %load_type
  %t3836 = load ptr, ptr %expr
  %t3837 = getelementptr inbounds %ASTNode, ptr %t3836, i32 0, i32 1
  %t3838 = load ptr, ptr %t3837
  %t3839 = call i32 @ir_is_global_name(ptr %t3838)
  %t3840 = icmp eq i32 %t3839, 1
  br i1 %t3840, label %label_1317, label %label_1318
label_1317:
  %t3841 = load ptr, ptr %load_type
  %t3842 = load ptr, ptr %expr
  %t3843 = getelementptr inbounds %ASTNode, ptr %t3842, i32 0, i32 1
  %t3844 = load ptr, ptr %t3843
  %t3845 = call i32 @ir_load_global(ptr %t3841, ptr %t3844)
  store i32 %t3845, ptr %temp_id
  %t3846 = load i32, ptr %temp_id
  %t3847 = call ptr @ir_get_temp_name(i32 %t3846)
  ret ptr %t3847
label_1318:
  %t3848 = load ptr, ptr %load_type
  %t3849 = load ptr, ptr %expr
  %t3850 = getelementptr inbounds %ASTNode, ptr %t3849, i32 0, i32 1
  %t3851 = load ptr, ptr %t3850
  %t3852 = call i32 @ir_load(ptr %t3848, ptr %t3851)
  store i32 %t3852, ptr %temp_id
  %t3853 = load i32, ptr %temp_id
  %t3854 = call ptr @ir_get_temp_name(i32 %t3853)
  ret ptr %t3854
label_1319:
  br label %label_1316
label_1316:
  %t3855 = load ptr, ptr %expr
  %t3856 = getelementptr inbounds %ASTNode, ptr %t3855, i32 0, i32 0
  %t3857 = load i32, ptr %t3856
  %t3858 = icmp eq i32 %t3857, 25
  br i1 %t3858, label %label_1320, label %label_1322
label_1320:
  %t3859 = load ptr, ptr %expr
  %t3860 = getelementptr inbounds %ASTNode, ptr %t3859, i32 0, i32 5
  %t3861 = load ptr, ptr %t3860
  %t3862 = call ptr @ptr_to_node(ptr %t3861)
  store ptr %t3862, ptr %object_node
  %t3863 = load ptr, ptr %object_node
  %t3864 = getelementptr inbounds %ASTNode, ptr %t3863, i32 0, i32 0
  %t3865 = load i32, ptr %t3864
  %t3866 = icmp eq i32 %t3865, 23
  br i1 %t3866, label %label_1323, label %label_1325
label_1323:
  %t3867 = load ptr, ptr %object_node
  %t3868 = getelementptr inbounds %ASTNode, ptr %t3867, i32 0, i32 1
  %t3869 = load ptr, ptr %t3868
  %t3870 = load ptr, ptr %expr
  %t3871 = getelementptr inbounds %ASTNode, ptr %t3870, i32 0, i32 1
  %t3872 = load ptr, ptr %t3871
  %t3873 = call i32 @ir_get_enum_variant(ptr %t3869, ptr %t3872)
  store i32 %t3873, ptr %enum_val
  %t3874 = load i32, ptr %enum_val
  %t3875 = icmp sge i32 %t3874, 0
  br i1 %t3875, label %label_1326, label %label_1328
label_1326:
  %t3876 = load i32, ptr %enum_val
  %t3877 = call ptr @int_to_str(i32 %t3876)
  ret ptr %t3877
label_1328:
  br label %label_1325
label_1325:
  %t3878 = load ptr, ptr %object_node
  %t3879 = call ptr @generate_expression__Struct_ASTNode(ptr %t3878)
  store ptr %t3879, ptr %object_val
  %t3880 = load ptr, ptr %object_node
  %t3881 = call ptr @get_expr_type__Struct_ASTNode(ptr %t3880)
  store ptr %t3881, ptr %object_type
  %t3882 = load ptr, ptr %object_type
  %t3883 = call ptr @struct_type_name__String(ptr %t3882)
  store ptr %t3883, ptr %struct_name
  %t3884 = load ptr, ptr %struct_name
  %t3885 = load ptr, ptr %expr
  %t3886 = getelementptr inbounds %ASTNode, ptr %t3885, i32 0, i32 1
  %t3887 = load ptr, ptr %t3886
  %t3888 = call i32 @ir_get_struct_field_index(ptr %t3884, ptr %t3887)
  store i32 %t3888, ptr %field_index
  %t3889 = load ptr, ptr %struct_name
  %t3890 = load ptr, ptr %expr
  %t3891 = getelementptr inbounds %ASTNode, ptr %t3890, i32 0, i32 1
  %t3892 = load ptr, ptr %t3891
  %t3893 = call ptr @ir_get_struct_field_type(ptr %t3889, ptr %t3892)
  %t3894 = call ptr @storage_type__String(ptr %t3893)
  store ptr %t3894, ptr %field_type
  %t3895 = call i32 @ir_get_temp()
  store i32 %t3895, ptr %gep_temp
  %t3896 = load i32, ptr %gep_temp
  %t3897 = call ptr @ir_get_temp_name(i32 %t3896)
  store ptr %t3897, ptr %gep_name
  %t3898 = getelementptr inbounds [3 x i8], ptr @.str.s522, i64 0, i64 0
  call void @ir_append(ptr %t3898)
  %t3899 = load ptr, ptr %gep_name
  call void @ir_append(ptr %t3899)
  %t3900 = getelementptr inbounds [27 x i8], ptr @.str.s523, i64 0, i64 0
  call void @ir_append(ptr %t3900)
  %t3901 = getelementptr inbounds [2 x i8], ptr @.str.s524, i64 0, i64 0
  %t3902 = load ptr, ptr %struct_name
  %t3903 = call ptr @str_concat(ptr %t3901, ptr %t3902)
  call void @ir_append(ptr %t3903)
  %t3904 = getelementptr inbounds [7 x i8], ptr @.str.s525, i64 0, i64 0
  call void @ir_append(ptr %t3904)
  %t3905 = load ptr, ptr %object_val
  call void @ir_append(ptr %t3905)
  %t3906 = getelementptr inbounds [14 x i8], ptr @.str.s526, i64 0, i64 0
  call void @ir_append(ptr %t3906)
  %t3907 = load i32, ptr %field_index
  %t3908 = call ptr @int_to_str(i32 %t3907)
  call void @ir_append_line(ptr %t3908)
  %t3909 = call i32 @ir_get_temp()
  store i32 %t3909, ptr %load_temp
  %t3910 = load i32, ptr %load_temp
  %t3911 = call ptr @ir_get_temp_name(i32 %t3910)
  store ptr %t3911, ptr %load_name
  %t3912 = getelementptr inbounds [3 x i8], ptr @.str.s527, i64 0, i64 0
  call void @ir_append(ptr %t3912)
  %t3913 = load ptr, ptr %load_name
  call void @ir_append(ptr %t3913)
  %t3914 = getelementptr inbounds [9 x i8], ptr @.str.s528, i64 0, i64 0
  call void @ir_append(ptr %t3914)
  %t3915 = load ptr, ptr %field_type
  call void @ir_append(ptr %t3915)
  %t3916 = getelementptr inbounds [7 x i8], ptr @.str.s529, i64 0, i64 0
  call void @ir_append(ptr %t3916)
  %t3917 = load ptr, ptr %gep_name
  call void @ir_append_line(ptr %t3917)
  %t3918 = load ptr, ptr %load_name
  ret ptr %t3918
label_1322:
  %t3919 = load ptr, ptr %expr
  %t3920 = getelementptr inbounds %ASTNode, ptr %t3919, i32 0, i32 0
  %t3921 = load i32, ptr %t3920
  %t3922 = icmp eq i32 %t3921, 27
  br i1 %t3922, label %label_1329, label %label_1331
label_1329:
  %t3923 = load ptr, ptr %expr
  %t3924 = getelementptr inbounds %ASTNode, ptr %t3923, i32 0, i32 5
  %t3925 = load ptr, ptr %t3924
  %t3926 = call i32 @count_list_nodes__String(ptr %t3925)
  store i32 %t3926, ptr %elem_count
  %t3927 = load ptr, ptr %expr
  %t3928 = getelementptr inbounds %ASTNode, ptr %t3927, i32 0, i32 5
  %t3929 = load ptr, ptr %t3928
  %t3930 = call ptr @ptr_to_node(ptr %t3929)
  store ptr %t3930, ptr %first_elem
  store i32 0, ptr %is_nested
  %t3931 = load ptr, ptr %first_elem
  %t3932 = getelementptr inbounds %ASTNode, ptr %t3931, i32 0, i32 0
  %t3933 = load i32, ptr %t3932
  %t3934 = icmp eq i32 %t3933, 27
  br i1 %t3934, label %label_1332, label %label_1334
label_1332:
  store i32 1, ptr %is_nested
  br label %label_1334
label_1334:
  %t3935 = load i32, ptr %is_nested
  %t3936 = icmp eq i32 %t3935, 1
  br i1 %t3936, label %label_1335, label %label_1337
label_1335:
  %t3937 = call i32 @ir_get_temp()
  store i32 %t3937, ptr %arr_temp
  %t3938 = load i32, ptr %arr_temp
  %t3939 = call ptr @ir_get_temp_name(i32 %t3938)
  store ptr %t3939, ptr %arr_name
  %t3940 = getelementptr inbounds [3 x i8], ptr @.str.s530, i64 0, i64 0
  call void @ir_append(ptr %t3940)
  %t3941 = load ptr, ptr %arr_name
  call void @ir_append(ptr %t3941)
  %t3942 = getelementptr inbounds [12 x i8], ptr @.str.s531, i64 0, i64 0
  call void @ir_append(ptr %t3942)
  %t3943 = load i32, ptr %elem_count
  %t3944 = call ptr @int_to_str(i32 %t3943)
  call void @ir_append(ptr %t3944)
  %t3945 = getelementptr inbounds [8 x i8], ptr @.str.s532, i64 0, i64 0
  call void @ir_append_line(ptr %t3945)
  %t3946 = load ptr, ptr %expr
  %t3947 = getelementptr inbounds %ASTNode, ptr %t3946, i32 0, i32 5
  %t3948 = load ptr, ptr %t3947
  store ptr %t3948, ptr %elem_ptr
  store i32 0, ptr %elem_index
  br label %label_1338
label_1338:
  %t3949 = load ptr, ptr %elem_ptr
  %t3950 = getelementptr inbounds [1 x i8], ptr @.str.s533, i64 0, i64 0
  %t3951 = call i32 @str_equals(ptr %t3949, ptr %t3950)
  %t3952 = icmp eq i32 %t3951, 0
  br i1 %t3952, label %label_1339, label %label_1340
label_1339:
  %t3953 = load ptr, ptr %elem_ptr
  %t3954 = call ptr @ptr_to_node(ptr %t3953)
  store ptr %t3954, ptr %elem_node
  %t3955 = load ptr, ptr %elem_node
  %t3956 = call ptr @generate_expression__Struct_ASTNode(ptr %t3955)
  store ptr %t3956, ptr %inner_ptr
  %t3957 = call i32 @ir_get_temp()
  store i32 %t3957, ptr %slot_temp
  %t3958 = load i32, ptr %slot_temp
  %t3959 = call ptr @ir_get_temp_name(i32 %t3958)
  store ptr %t3959, ptr %slot_name
  %t3960 = getelementptr inbounds [3 x i8], ptr @.str.s534, i64 0, i64 0
  call void @ir_append(ptr %t3960)
  %t3961 = load ptr, ptr %slot_name
  call void @ir_append(ptr %t3961)
  %t3962 = getelementptr inbounds [28 x i8], ptr @.str.s535, i64 0, i64 0
  call void @ir_append(ptr %t3962)
  %t3963 = load i32, ptr %elem_count
  %t3964 = call ptr @int_to_str(i32 %t3963)
  call void @ir_append(ptr %t3964)
  %t3965 = getelementptr inbounds [14 x i8], ptr @.str.s536, i64 0, i64 0
  call void @ir_append(ptr %t3965)
  %t3966 = load ptr, ptr %arr_name
  call void @ir_append(ptr %t3966)
  %t3967 = getelementptr inbounds [3 x i8], ptr @.str.s537, i64 0, i64 0
  call void @ir_append(ptr %t3967)
  %t3968 = call ptr @ir_ptr_int_type__Void()
  call void @ir_append(ptr %t3968)
  %t3969 = getelementptr inbounds [5 x i8], ptr @.str.s538, i64 0, i64 0
  call void @ir_append(ptr %t3969)
  %t3970 = call ptr @ir_ptr_int_type__Void()
  call void @ir_append(ptr %t3970)
  %t3971 = getelementptr inbounds [2 x i8], ptr @.str.s539, i64 0, i64 0
  call void @ir_append(ptr %t3971)
  %t3972 = load i32, ptr %elem_index
  %t3973 = call ptr @int_to_str(i32 %t3972)
  call void @ir_append_line(ptr %t3973)
  %t3974 = getelementptr inbounds [13 x i8], ptr @.str.s540, i64 0, i64 0
  call void @ir_append(ptr %t3974)
  %t3975 = load ptr, ptr %inner_ptr
  call void @ir_append(ptr %t3975)
  %t3976 = getelementptr inbounds [7 x i8], ptr @.str.s541, i64 0, i64 0
  call void @ir_append(ptr %t3976)
  %t3977 = load ptr, ptr %slot_name
  call void @ir_append_line(ptr %t3977)
  %t3978 = load i32, ptr %elem_index
  %t3979 = add i32 %t3978, 1
  store i32 %t3979, ptr %elem_index
  %t3980 = load ptr, ptr %elem_node
  %t3981 = getelementptr inbounds %ASTNode, ptr %t3980, i32 0, i32 8
  %t3982 = load ptr, ptr %t3981
  store ptr %t3982, ptr %elem_ptr
  br label %label_1338
label_1340:
  %t3983 = call i32 @ir_get_temp()
  store i32 %t3983, ptr %ret_temp
  %t3984 = load i32, ptr %ret_temp
  %t3985 = call ptr @ir_get_temp_name(i32 %t3984)
  store ptr %t3985, ptr %ret_name
  %t3986 = getelementptr inbounds [3 x i8], ptr @.str.s542, i64 0, i64 0
  call void @ir_append(ptr %t3986)
  %t3987 = load ptr, ptr %ret_name
  call void @ir_append(ptr %t3987)
  %t3988 = getelementptr inbounds [28 x i8], ptr @.str.s543, i64 0, i64 0
  call void @ir_append(ptr %t3988)
  %t3989 = load i32, ptr %elem_count
  %t3990 = call ptr @int_to_str(i32 %t3989)
  call void @ir_append(ptr %t3990)
  %t3991 = getelementptr inbounds [14 x i8], ptr @.str.s544, i64 0, i64 0
  call void @ir_append(ptr %t3991)
  %t3992 = load ptr, ptr %arr_name
  call void @ir_append(ptr %t3992)
  %t3993 = getelementptr inbounds [3 x i8], ptr @.str.s545, i64 0, i64 0
  call void @ir_append(ptr %t3993)
  %t3994 = call ptr @ir_ptr_int_type__Void()
  call void @ir_append(ptr %t3994)
  %t3995 = getelementptr inbounds [5 x i8], ptr @.str.s546, i64 0, i64 0
  call void @ir_append(ptr %t3995)
  %t3996 = call ptr @ir_ptr_int_type__Void()
  call void @ir_append(ptr %t3996)
  %t3997 = getelementptr inbounds [3 x i8], ptr @.str.s547, i64 0, i64 0
  call void @ir_append_line(ptr %t3997)
  %t3998 = load ptr, ptr %ret_name
  ret ptr %t3998
label_1337:
  %t3999 = call i32 @ir_get_temp()
  store i32 %t3999, ptr %arr_temp2
  %t4000 = load i32, ptr %arr_temp2
  %t4001 = call ptr @ir_get_temp_name(i32 %t4000)
  store ptr %t4001, ptr %arr_name2
  %t4002 = getelementptr inbounds [3 x i8], ptr @.str.s548, i64 0, i64 0
  call void @ir_append(ptr %t4002)
  %t4003 = load ptr, ptr %arr_name2
  call void @ir_append(ptr %t4003)
  %t4004 = getelementptr inbounds [12 x i8], ptr @.str.s549, i64 0, i64 0
  call void @ir_append(ptr %t4004)
  %t4005 = load i32, ptr %elem_count
  %t4006 = call ptr @int_to_str(i32 %t4005)
  call void @ir_append(ptr %t4006)
  %t4007 = getelementptr inbounds [8 x i8], ptr @.str.s550, i64 0, i64 0
  call void @ir_append_line(ptr %t4007)
  %t4008 = load ptr, ptr %expr
  %t4009 = getelementptr inbounds %ASTNode, ptr %t4008, i32 0, i32 5
  %t4010 = load ptr, ptr %t4009
  store ptr %t4010, ptr %elem_ptr2
  store i32 0, ptr %elem_index2
  br label %label_1341
label_1341:
  %t4011 = load ptr, ptr %elem_ptr2
  %t4012 = getelementptr inbounds [1 x i8], ptr @.str.s551, i64 0, i64 0
  %t4013 = call i32 @str_equals(ptr %t4011, ptr %t4012)
  %t4014 = icmp eq i32 %t4013, 0
  br i1 %t4014, label %label_1342, label %label_1343
label_1342:
  %t4015 = load ptr, ptr %elem_ptr2
  %t4016 = call ptr @ptr_to_node(ptr %t4015)
  store ptr %t4016, ptr %elem_node2
  %t4017 = load ptr, ptr %elem_node2
  %t4018 = call ptr @generate_expression__Struct_ASTNode(ptr %t4017)
  store ptr %t4018, ptr %elem_val
  %t4019 = call i32 @ir_get_temp()
  store i32 %t4019, ptr %elem_slot_temp
  %t4020 = load i32, ptr %elem_slot_temp
  %t4021 = call ptr @ir_get_temp_name(i32 %t4020)
  store ptr %t4021, ptr %elem_slot_name
  %t4022 = getelementptr inbounds [3 x i8], ptr @.str.s552, i64 0, i64 0
  call void @ir_append(ptr %t4022)
  %t4023 = load ptr, ptr %elem_slot_name
  call void @ir_append(ptr %t4023)
  %t4024 = getelementptr inbounds [28 x i8], ptr @.str.s553, i64 0, i64 0
  call void @ir_append(ptr %t4024)
  %t4025 = load i32, ptr %elem_count
  %t4026 = call ptr @int_to_str(i32 %t4025)
  call void @ir_append(ptr %t4026)
  %t4027 = getelementptr inbounds [14 x i8], ptr @.str.s554, i64 0, i64 0
  call void @ir_append(ptr %t4027)
  %t4028 = load ptr, ptr %arr_name2
  call void @ir_append(ptr %t4028)
  %t4029 = getelementptr inbounds [3 x i8], ptr @.str.s555, i64 0, i64 0
  call void @ir_append(ptr %t4029)
  %t4030 = call ptr @ir_ptr_int_type__Void()
  call void @ir_append(ptr %t4030)
  %t4031 = getelementptr inbounds [5 x i8], ptr @.str.s556, i64 0, i64 0
  call void @ir_append(ptr %t4031)
  %t4032 = call ptr @ir_ptr_int_type__Void()
  call void @ir_append(ptr %t4032)
  %t4033 = getelementptr inbounds [2 x i8], ptr @.str.s557, i64 0, i64 0
  call void @ir_append(ptr %t4033)
  %t4034 = load i32, ptr %elem_index2
  %t4035 = call ptr @int_to_str(i32 %t4034)
  call void @ir_append_line(ptr %t4035)
  %t4036 = getelementptr inbounds [13 x i8], ptr @.str.s558, i64 0, i64 0
  call void @ir_append(ptr %t4036)
  %t4037 = load ptr, ptr %elem_val
  call void @ir_append(ptr %t4037)
  %t4038 = getelementptr inbounds [7 x i8], ptr @.str.s559, i64 0, i64 0
  call void @ir_append(ptr %t4038)
  %t4039 = load ptr, ptr %elem_slot_name
  call void @ir_append_line(ptr %t4039)
  %t4040 = load i32, ptr %elem_index2
  %t4041 = add i32 %t4040, 1
  store i32 %t4041, ptr %elem_index2
  %t4042 = load ptr, ptr %elem_node2
  %t4043 = getelementptr inbounds %ASTNode, ptr %t4042, i32 0, i32 8
  %t4044 = load ptr, ptr %t4043
  store ptr %t4044, ptr %elem_ptr2
  br label %label_1341
label_1343:
  %t4045 = call i32 @ir_get_temp()
  store i32 %t4045, ptr %ret_temp2
  %t4046 = load i32, ptr %ret_temp2
  %t4047 = call ptr @ir_get_temp_name(i32 %t4046)
  store ptr %t4047, ptr %ret_name2
  %t4048 = getelementptr inbounds [3 x i8], ptr @.str.s560, i64 0, i64 0
  call void @ir_append(ptr %t4048)
  %t4049 = load ptr, ptr %ret_name2
  call void @ir_append(ptr %t4049)
  %t4050 = getelementptr inbounds [28 x i8], ptr @.str.s561, i64 0, i64 0
  call void @ir_append(ptr %t4050)
  %t4051 = load i32, ptr %elem_count
  %t4052 = call ptr @int_to_str(i32 %t4051)
  call void @ir_append(ptr %t4052)
  %t4053 = getelementptr inbounds [14 x i8], ptr @.str.s562, i64 0, i64 0
  call void @ir_append(ptr %t4053)
  %t4054 = load ptr, ptr %arr_name2
  call void @ir_append(ptr %t4054)
  %t4055 = getelementptr inbounds [3 x i8], ptr @.str.s563, i64 0, i64 0
  call void @ir_append(ptr %t4055)
  %t4056 = call ptr @ir_ptr_int_type__Void()
  call void @ir_append(ptr %t4056)
  %t4057 = getelementptr inbounds [5 x i8], ptr @.str.s564, i64 0, i64 0
  call void @ir_append(ptr %t4057)
  %t4058 = call ptr @ir_ptr_int_type__Void()
  call void @ir_append(ptr %t4058)
  %t4059 = getelementptr inbounds [3 x i8], ptr @.str.s565, i64 0, i64 0
  call void @ir_append_line(ptr %t4059)
  %t4060 = load ptr, ptr %ret_name2
  ret ptr %t4060
label_1331:
  %t4061 = load ptr, ptr %expr
  %t4062 = getelementptr inbounds %ASTNode, ptr %t4061, i32 0, i32 0
  %t4063 = load i32, ptr %t4062
  %t4064 = icmp eq i32 %t4063, 26
  br i1 %t4064, label %label_1344, label %label_1346
label_1344:
  %t4065 = load ptr, ptr %expr
  %t4066 = getelementptr inbounds %ASTNode, ptr %t4065, i32 0, i32 5
  %t4067 = load ptr, ptr %t4066
  %t4068 = call ptr @ptr_to_node(ptr %t4067)
  %t4069 = call ptr @generate_expression__Struct_ASTNode(ptr %t4068)
  store ptr %t4069, ptr %array_val
  %t4070 = load ptr, ptr %expr
  %t4071 = getelementptr inbounds %ASTNode, ptr %t4070, i32 0, i32 6
  %t4072 = load ptr, ptr %t4071
  %t4073 = call ptr @ptr_to_node(ptr %t4072)
  %t4074 = call ptr @generate_expression__Struct_ASTNode(ptr %t4073)
  store ptr %t4074, ptr %index_val
  %t4075 = load ptr, ptr %expr
  %t4076 = getelementptr inbounds %ASTNode, ptr %t4075, i32 0, i32 5
  %t4077 = load ptr, ptr %t4076
  %t4078 = call ptr @ptr_to_node(ptr %t4077)
  %t4079 = call ptr @get_expr_type__Struct_ASTNode(ptr %t4078)
  store ptr %t4079, ptr %obj_type
  %t4080 = getelementptr inbounds [4 x i8], ptr @.str.s566, i64 0, i64 0
  store ptr %t4080, ptr %elem_type
  %t4081 = load ptr, ptr %obj_type
  %t4082 = getelementptr inbounds [7 x i8], ptr @.str.s567, i64 0, i64 0
  %t4083 = call i32 @str_equals(ptr %t4081, ptr %t4082)
  %t4084 = icmp eq i32 %t4083, 1
  br i1 %t4084, label %label_1347, label %label_1349
label_1347:
  %t4085 = getelementptr inbounds [4 x i8], ptr @.str.s568, i64 0, i64 0
  store ptr %t4085, ptr %elem_type
  br label %label_1349
label_1349:
  %t4086 = call i32 @ir_get_temp()
  store i32 %t4086, ptr %ptr_temp
  %t4087 = load i32, ptr %ptr_temp
  %t4088 = call ptr @ir_get_temp_name(i32 %t4087)
  store ptr %t4088, ptr %ptr_name
  %t4089 = getelementptr inbounds [3 x i8], ptr @.str.s569, i64 0, i64 0
  call void @ir_append(ptr %t4089)
  %t4090 = load ptr, ptr %ptr_name
  call void @ir_append(ptr %t4090)
  %t4091 = getelementptr inbounds [27 x i8], ptr @.str.s570, i64 0, i64 0
  call void @ir_append(ptr %t4091)
  %t4092 = load ptr, ptr %elem_type
  call void @ir_append(ptr %t4092)
  %t4093 = getelementptr inbounds [7 x i8], ptr @.str.s571, i64 0, i64 0
  call void @ir_append(ptr %t4093)
  %t4094 = load ptr, ptr %array_val
  call void @ir_append(ptr %t4094)
  %t4095 = getelementptr inbounds [7 x i8], ptr @.str.s572, i64 0, i64 0
  call void @ir_append(ptr %t4095)
  %t4096 = load ptr, ptr %index_val
  call void @ir_append_line(ptr %t4096)
  %t4097 = call i32 @ir_get_temp()
  store i32 %t4097, ptr %load_temp
  %t4098 = load i32, ptr %load_temp
  %t4099 = call ptr @ir_get_temp_name(i32 %t4098)
  store ptr %t4099, ptr %load_name
  %t4100 = getelementptr inbounds [3 x i8], ptr @.str.s573, i64 0, i64 0
  call void @ir_append(ptr %t4100)
  %t4101 = load ptr, ptr %load_name
  call void @ir_append(ptr %t4101)
  %t4102 = getelementptr inbounds [9 x i8], ptr @.str.s574, i64 0, i64 0
  call void @ir_append(ptr %t4102)
  %t4103 = load ptr, ptr %elem_type
  call void @ir_append(ptr %t4103)
  %t4104 = getelementptr inbounds [7 x i8], ptr @.str.s575, i64 0, i64 0
  call void @ir_append(ptr %t4104)
  %t4105 = load ptr, ptr %ptr_name
  call void @ir_append_line(ptr %t4105)
  %t4106 = load ptr, ptr %load_name
  ret ptr %t4106
label_1346:
  %t4107 = load ptr, ptr %expr
  %t4108 = getelementptr inbounds %ASTNode, ptr %t4107, i32 0, i32 0
  %t4109 = load i32, ptr %t4108
  %t4110 = icmp eq i32 %t4109, 20
  br i1 %t4110, label %label_1350, label %label_1352
label_1350:
  %t4111 = load ptr, ptr %expr
  %t4112 = getelementptr inbounds %ASTNode, ptr %t4111, i32 0, i32 5
  %t4113 = load ptr, ptr %t4112
  %t4114 = call ptr @ptr_to_node(ptr %t4113)
  %t4115 = call ptr @generate_expression__Struct_ASTNode(ptr %t4114)
  store ptr %t4115, ptr %left_val
  %t4116 = load ptr, ptr %expr
  %t4117 = getelementptr inbounds %ASTNode, ptr %t4116, i32 0, i32 6
  %t4118 = load ptr, ptr %t4117
  %t4119 = call ptr @ptr_to_node(ptr %t4118)
  %t4120 = call ptr @generate_expression__Struct_ASTNode(ptr %t4119)
  store ptr %t4120, ptr %right_val
  %t4121 = load ptr, ptr %expr
  %t4122 = getelementptr inbounds %ASTNode, ptr %t4121, i32 0, i32 1
  %t4123 = load ptr, ptr %t4122
  store ptr %t4123, ptr %op
  store i32 0, ptr %temp_id
  %t4124 = load ptr, ptr %expr
  %t4125 = getelementptr inbounds %ASTNode, ptr %t4124, i32 0, i32 5
  %t4126 = load ptr, ptr %t4125
  %t4127 = call ptr @ptr_to_node(ptr %t4126)
  store ptr %t4127, ptr %left_node
  %t4128 = load ptr, ptr %left_node
  %t4129 = call ptr @get_expr_type__Struct_ASTNode(ptr %t4128)
  store ptr %t4129, ptr %op_type
  store i1 0, ptr %is_unsigned
  %t4130 = load ptr, ptr %left_node
  %t4131 = call i1 @node_has_type__Struct_ASTNode(ptr %t4130)
  br i1 %t4131, label %label_1353, label %label_1355
label_1353:
  %t4132 = load ptr, ptr %left_node
  %t4133 = call ptr @node_get_type__Struct_ASTNode(ptr %t4132)
  %t4134 = call i1 @type_int_is_unsigned__Struct_TypeInfo(ptr %t4133)
  store i1 %t4134, ptr %is_unsigned
  br label %label_1355
label_1355:
  %t4135 = load ptr, ptr %op_type
  %t4136 = getelementptr inbounds [7 x i8], ptr @.str.s576, i64 0, i64 0
  %t4137 = call i32 @str_equals(ptr %t4135, ptr %t4136)
  %t4138 = icmp eq i32 %t4137, 1
  br i1 %t4138, label %label_1356, label %label_1357
label_1356:
  %t4139 = load ptr, ptr %op
  %t4140 = getelementptr inbounds [2 x i8], ptr @.str.s577, i64 0, i64 0
  %t4141 = call i32 @str_equals(ptr %t4139, ptr %t4140)
  %t4142 = icmp eq i32 %t4141, 1
  br i1 %t4142, label %label_1359, label %label_1361
label_1359:
  %t4143 = load ptr, ptr %op_type
  %t4144 = load ptr, ptr %left_val
  %t4145 = load ptr, ptr %right_val
  %t4146 = call i32 @ir_fadd(ptr %t4143, ptr %t4144, ptr %t4145)
  store i32 %t4146, ptr %temp_id
  br label %label_1361
label_1361:
  %t4147 = load ptr, ptr %op
  %t4148 = getelementptr inbounds [2 x i8], ptr @.str.s578, i64 0, i64 0
  %t4149 = call i32 @str_equals(ptr %t4147, ptr %t4148)
  %t4150 = icmp eq i32 %t4149, 1
  br i1 %t4150, label %label_1362, label %label_1364
label_1362:
  %t4151 = load ptr, ptr %op_type
  %t4152 = load ptr, ptr %left_val
  %t4153 = load ptr, ptr %right_val
  %t4154 = call i32 @ir_fsub(ptr %t4151, ptr %t4152, ptr %t4153)
  store i32 %t4154, ptr %temp_id
  br label %label_1364
label_1364:
  %t4155 = load ptr, ptr %op
  %t4156 = getelementptr inbounds [2 x i8], ptr @.str.s579, i64 0, i64 0
  %t4157 = call i32 @str_equals(ptr %t4155, ptr %t4156)
  %t4158 = icmp eq i32 %t4157, 1
  br i1 %t4158, label %label_1365, label %label_1367
label_1365:
  %t4159 = load ptr, ptr %op_type
  %t4160 = load ptr, ptr %left_val
  %t4161 = load ptr, ptr %right_val
  %t4162 = call i32 @ir_fmul(ptr %t4159, ptr %t4160, ptr %t4161)
  store i32 %t4162, ptr %temp_id
  br label %label_1367
label_1367:
  %t4163 = load ptr, ptr %op
  %t4164 = getelementptr inbounds [2 x i8], ptr @.str.s580, i64 0, i64 0
  %t4165 = call i32 @str_equals(ptr %t4163, ptr %t4164)
  %t4166 = icmp eq i32 %t4165, 1
  br i1 %t4166, label %label_1368, label %label_1370
label_1368:
  %t4167 = load ptr, ptr %op_type
  %t4168 = load ptr, ptr %left_val
  %t4169 = load ptr, ptr %right_val
  %t4170 = call i32 @ir_fdiv(ptr %t4167, ptr %t4168, ptr %t4169)
  store i32 %t4170, ptr %temp_id
  br label %label_1370
label_1370:
  %t4171 = load ptr, ptr %op
  %t4172 = getelementptr inbounds [3 x i8], ptr @.str.s581, i64 0, i64 0
  %t4173 = call i32 @str_equals(ptr %t4171, ptr %t4172)
  %t4174 = icmp eq i32 %t4173, 1
  br i1 %t4174, label %label_1371, label %label_1373
label_1371:
  %t4175 = load ptr, ptr %op_type
  %t4176 = load ptr, ptr %left_val
  %t4177 = load ptr, ptr %right_val
  %t4178 = call i32 @ir_fcmp_oeq(ptr %t4175, ptr %t4176, ptr %t4177)
  store i32 %t4178, ptr %temp_id
  br label %label_1373
label_1373:
  %t4179 = load ptr, ptr %op
  %t4180 = getelementptr inbounds [3 x i8], ptr @.str.s582, i64 0, i64 0
  %t4181 = call i32 @str_equals(ptr %t4179, ptr %t4180)
  %t4182 = icmp eq i32 %t4181, 1
  br i1 %t4182, label %label_1374, label %label_1376
label_1374:
  %t4183 = load ptr, ptr %op_type
  %t4184 = load ptr, ptr %left_val
  %t4185 = load ptr, ptr %right_val
  %t4186 = call i32 @ir_fcmp_one(ptr %t4183, ptr %t4184, ptr %t4185)
  store i32 %t4186, ptr %temp_id
  br label %label_1376
label_1376:
  %t4187 = load ptr, ptr %op
  %t4188 = getelementptr inbounds [2 x i8], ptr @.str.s583, i64 0, i64 0
  %t4189 = call i32 @str_equals(ptr %t4187, ptr %t4188)
  %t4190 = icmp eq i32 %t4189, 1
  br i1 %t4190, label %label_1377, label %label_1379
label_1377:
  %t4191 = load ptr, ptr %op_type
  %t4192 = load ptr, ptr %left_val
  %t4193 = load ptr, ptr %right_val
  %t4194 = call i32 @ir_fcmp_olt(ptr %t4191, ptr %t4192, ptr %t4193)
  store i32 %t4194, ptr %temp_id
  br label %label_1379
label_1379:
  %t4195 = load ptr, ptr %op
  %t4196 = getelementptr inbounds [3 x i8], ptr @.str.s584, i64 0, i64 0
  %t4197 = call i32 @str_equals(ptr %t4195, ptr %t4196)
  %t4198 = icmp eq i32 %t4197, 1
  br i1 %t4198, label %label_1380, label %label_1382
label_1380:
  %t4199 = load ptr, ptr %op_type
  %t4200 = load ptr, ptr %left_val
  %t4201 = load ptr, ptr %right_val
  %t4202 = call i32 @ir_fcmp_ole(ptr %t4199, ptr %t4200, ptr %t4201)
  store i32 %t4202, ptr %temp_id
  br label %label_1382
label_1382:
  %t4203 = load ptr, ptr %op
  %t4204 = getelementptr inbounds [2 x i8], ptr @.str.s585, i64 0, i64 0
  %t4205 = call i32 @str_equals(ptr %t4203, ptr %t4204)
  %t4206 = icmp eq i32 %t4205, 1
  br i1 %t4206, label %label_1383, label %label_1385
label_1383:
  %t4207 = load ptr, ptr %op_type
  %t4208 = load ptr, ptr %left_val
  %t4209 = load ptr, ptr %right_val
  %t4210 = call i32 @ir_fcmp_ogt(ptr %t4207, ptr %t4208, ptr %t4209)
  store i32 %t4210, ptr %temp_id
  br label %label_1385
label_1385:
  %t4211 = load ptr, ptr %op
  %t4212 = getelementptr inbounds [3 x i8], ptr @.str.s586, i64 0, i64 0
  %t4213 = call i32 @str_equals(ptr %t4211, ptr %t4212)
  %t4214 = icmp eq i32 %t4213, 1
  br i1 %t4214, label %label_1386, label %label_1388
label_1386:
  %t4215 = load ptr, ptr %op_type
  %t4216 = load ptr, ptr %left_val
  %t4217 = load ptr, ptr %right_val
  %t4218 = call i32 @ir_fcmp_oge(ptr %t4215, ptr %t4216, ptr %t4217)
  store i32 %t4218, ptr %temp_id
  br label %label_1388
label_1388:
  br label %label_1358
label_1357:
  %t4219 = load ptr, ptr %op
  %t4220 = getelementptr inbounds [2 x i8], ptr @.str.s587, i64 0, i64 0
  %t4221 = call i32 @str_equals(ptr %t4219, ptr %t4220)
  %t4222 = icmp eq i32 %t4221, 1
  br i1 %t4222, label %label_1389, label %label_1391
label_1389:
  %t4223 = load ptr, ptr %op_type
  %t4224 = load ptr, ptr %left_val
  %t4225 = load ptr, ptr %right_val
  %t4226 = call i32 @ir_add(ptr %t4223, ptr %t4224, ptr %t4225)
  store i32 %t4226, ptr %temp_id
  br label %label_1391
label_1391:
  %t4227 = load ptr, ptr %op
  %t4228 = getelementptr inbounds [2 x i8], ptr @.str.s588, i64 0, i64 0
  %t4229 = call i32 @str_equals(ptr %t4227, ptr %t4228)
  %t4230 = icmp eq i32 %t4229, 1
  br i1 %t4230, label %label_1392, label %label_1394
label_1392:
  %t4231 = load ptr, ptr %op_type
  %t4232 = load ptr, ptr %left_val
  %t4233 = load ptr, ptr %right_val
  %t4234 = call i32 @ir_sub(ptr %t4231, ptr %t4232, ptr %t4233)
  store i32 %t4234, ptr %temp_id
  br label %label_1394
label_1394:
  %t4235 = load ptr, ptr %op
  %t4236 = getelementptr inbounds [2 x i8], ptr @.str.s589, i64 0, i64 0
  %t4237 = call i32 @str_equals(ptr %t4235, ptr %t4236)
  %t4238 = icmp eq i32 %t4237, 1
  br i1 %t4238, label %label_1395, label %label_1397
label_1395:
  %t4239 = load ptr, ptr %op_type
  %t4240 = load ptr, ptr %left_val
  %t4241 = load ptr, ptr %right_val
  %t4242 = call i32 @ir_mul(ptr %t4239, ptr %t4240, ptr %t4241)
  store i32 %t4242, ptr %temp_id
  br label %label_1397
label_1397:
  %t4243 = load ptr, ptr %op
  %t4244 = getelementptr inbounds [3 x i8], ptr @.str.s590, i64 0, i64 0
  %t4245 = call i32 @str_equals(ptr %t4243, ptr %t4244)
  %t4246 = icmp eq i32 %t4245, 1
  br i1 %t4246, label %label_1398, label %label_1400
label_1398:
  %t4247 = load ptr, ptr %op_type
  %t4248 = load ptr, ptr %left_val
  %t4249 = load ptr, ptr %right_val
  %t4250 = call i32 @ir_icmp_eq(ptr %t4247, ptr %t4248, ptr %t4249)
  store i32 %t4250, ptr %temp_id
  br label %label_1400
label_1400:
  %t4251 = load ptr, ptr %op
  %t4252 = getelementptr inbounds [3 x i8], ptr @.str.s591, i64 0, i64 0
  %t4253 = call i32 @str_equals(ptr %t4251, ptr %t4252)
  %t4254 = icmp eq i32 %t4253, 1
  br i1 %t4254, label %label_1401, label %label_1403
label_1401:
  %t4255 = load ptr, ptr %op_type
  %t4256 = load ptr, ptr %left_val
  %t4257 = load ptr, ptr %right_val
  %t4258 = call i32 @ir_icmp_ne(ptr %t4255, ptr %t4256, ptr %t4257)
  store i32 %t4258, ptr %temp_id
  br label %label_1403
label_1403:
  %t4259 = load i1, ptr %is_unsigned
  br i1 %t4259, label %label_1404, label %label_1405
label_1404:
  %t4260 = load ptr, ptr %op
  %t4261 = getelementptr inbounds [2 x i8], ptr @.str.s592, i64 0, i64 0
  %t4262 = call i32 @str_equals(ptr %t4260, ptr %t4261)
  %t4263 = icmp eq i32 %t4262, 1
  br i1 %t4263, label %label_1407, label %label_1409
label_1407:
  %t4264 = load ptr, ptr %op_type
  %t4265 = load ptr, ptr %left_val
  %t4266 = load ptr, ptr %right_val
  %t4267 = call i32 @ir_udiv(ptr %t4264, ptr %t4265, ptr %t4266)
  store i32 %t4267, ptr %temp_id
  br label %label_1409
label_1409:
  %t4268 = load ptr, ptr %op
  %t4269 = getelementptr inbounds [2 x i8], ptr @.str.s593, i64 0, i64 0
  %t4270 = call i32 @str_equals(ptr %t4268, ptr %t4269)
  %t4271 = icmp eq i32 %t4270, 1
  br i1 %t4271, label %label_1410, label %label_1412
label_1410:
  %t4272 = load ptr, ptr %op_type
  %t4273 = load ptr, ptr %left_val
  %t4274 = load ptr, ptr %right_val
  %t4275 = call i32 @ir_icmp_ult(ptr %t4272, ptr %t4273, ptr %t4274)
  store i32 %t4275, ptr %temp_id
  br label %label_1412
label_1412:
  %t4276 = load ptr, ptr %op
  %t4277 = getelementptr inbounds [3 x i8], ptr @.str.s594, i64 0, i64 0
  %t4278 = call i32 @str_equals(ptr %t4276, ptr %t4277)
  %t4279 = icmp eq i32 %t4278, 1
  br i1 %t4279, label %label_1413, label %label_1415
label_1413:
  %t4280 = load ptr, ptr %op_type
  %t4281 = load ptr, ptr %left_val
  %t4282 = load ptr, ptr %right_val
  %t4283 = call i32 @ir_icmp_ule(ptr %t4280, ptr %t4281, ptr %t4282)
  store i32 %t4283, ptr %temp_id
  br label %label_1415
label_1415:
  %t4284 = load ptr, ptr %op
  %t4285 = getelementptr inbounds [2 x i8], ptr @.str.s595, i64 0, i64 0
  %t4286 = call i32 @str_equals(ptr %t4284, ptr %t4285)
  %t4287 = icmp eq i32 %t4286, 1
  br i1 %t4287, label %label_1416, label %label_1418
label_1416:
  %t4288 = load ptr, ptr %op_type
  %t4289 = load ptr, ptr %left_val
  %t4290 = load ptr, ptr %right_val
  %t4291 = call i32 @ir_icmp_ugt(ptr %t4288, ptr %t4289, ptr %t4290)
  store i32 %t4291, ptr %temp_id
  br label %label_1418
label_1418:
  %t4292 = load ptr, ptr %op
  %t4293 = getelementptr inbounds [3 x i8], ptr @.str.s596, i64 0, i64 0
  %t4294 = call i32 @str_equals(ptr %t4292, ptr %t4293)
  %t4295 = icmp eq i32 %t4294, 1
  br i1 %t4295, label %label_1419, label %label_1421
label_1419:
  %t4296 = load ptr, ptr %op_type
  %t4297 = load ptr, ptr %left_val
  %t4298 = load ptr, ptr %right_val
  %t4299 = call i32 @ir_icmp_uge(ptr %t4296, ptr %t4297, ptr %t4298)
  store i32 %t4299, ptr %temp_id
  br label %label_1421
label_1421:
  br label %label_1406
label_1405:
  %t4300 = load ptr, ptr %op
  %t4301 = getelementptr inbounds [2 x i8], ptr @.str.s597, i64 0, i64 0
  %t4302 = call i32 @str_equals(ptr %t4300, ptr %t4301)
  %t4303 = icmp eq i32 %t4302, 1
  br i1 %t4303, label %label_1422, label %label_1424
label_1422:
  %t4304 = load ptr, ptr %op_type
  %t4305 = load ptr, ptr %left_val
  %t4306 = load ptr, ptr %right_val
  %t4307 = call i32 @ir_sdiv(ptr %t4304, ptr %t4305, ptr %t4306)
  store i32 %t4307, ptr %temp_id
  br label %label_1424
label_1424:
  %t4308 = load ptr, ptr %op
  %t4309 = getelementptr inbounds [2 x i8], ptr @.str.s598, i64 0, i64 0
  %t4310 = call i32 @str_equals(ptr %t4308, ptr %t4309)
  %t4311 = icmp eq i32 %t4310, 1
  br i1 %t4311, label %label_1425, label %label_1427
label_1425:
  %t4312 = load ptr, ptr %op_type
  %t4313 = load ptr, ptr %left_val
  %t4314 = load ptr, ptr %right_val
  %t4315 = call i32 @ir_icmp_slt(ptr %t4312, ptr %t4313, ptr %t4314)
  store i32 %t4315, ptr %temp_id
  br label %label_1427
label_1427:
  %t4316 = load ptr, ptr %op
  %t4317 = getelementptr inbounds [3 x i8], ptr @.str.s599, i64 0, i64 0
  %t4318 = call i32 @str_equals(ptr %t4316, ptr %t4317)
  %t4319 = icmp eq i32 %t4318, 1
  br i1 %t4319, label %label_1428, label %label_1430
label_1428:
  %t4320 = load ptr, ptr %op_type
  %t4321 = load ptr, ptr %left_val
  %t4322 = load ptr, ptr %right_val
  %t4323 = call i32 @ir_icmp_sle(ptr %t4320, ptr %t4321, ptr %t4322)
  store i32 %t4323, ptr %temp_id
  br label %label_1430
label_1430:
  %t4324 = load ptr, ptr %op
  %t4325 = getelementptr inbounds [2 x i8], ptr @.str.s600, i64 0, i64 0
  %t4326 = call i32 @str_equals(ptr %t4324, ptr %t4325)
  %t4327 = icmp eq i32 %t4326, 1
  br i1 %t4327, label %label_1431, label %label_1433
label_1431:
  %t4328 = load ptr, ptr %op_type
  %t4329 = load ptr, ptr %left_val
  %t4330 = load ptr, ptr %right_val
  %t4331 = call i32 @ir_icmp_sgt(ptr %t4328, ptr %t4329, ptr %t4330)
  store i32 %t4331, ptr %temp_id
  br label %label_1433
label_1433:
  %t4332 = load ptr, ptr %op
  %t4333 = getelementptr inbounds [3 x i8], ptr @.str.s601, i64 0, i64 0
  %t4334 = call i32 @str_equals(ptr %t4332, ptr %t4333)
  %t4335 = icmp eq i32 %t4334, 1
  br i1 %t4335, label %label_1434, label %label_1436
label_1434:
  %t4336 = load ptr, ptr %op_type
  %t4337 = load ptr, ptr %left_val
  %t4338 = load ptr, ptr %right_val
  %t4339 = call i32 @ir_icmp_sge(ptr %t4336, ptr %t4337, ptr %t4338)
  store i32 %t4339, ptr %temp_id
  br label %label_1436
label_1436:
  br label %label_1406
label_1406:
  br label %label_1358
label_1358:
  %t4340 = load ptr, ptr %op
  %t4341 = getelementptr inbounds [2 x i8], ptr @.str.s602, i64 0, i64 0
  %t4342 = call i32 @str_equals(ptr %t4340, ptr %t4341)
  %t4343 = icmp eq i32 %t4342, 1
  br i1 %t4343, label %label_1437, label %label_1439
label_1437:
  %t4344 = load i1, ptr %is_unsigned
  br i1 %t4344, label %label_1440, label %label_1441
label_1440:
  %t4345 = load ptr, ptr %op_type
  %t4346 = load ptr, ptr %left_val
  %t4347 = load ptr, ptr %right_val
  %t4348 = call i32 @ir_urem(ptr %t4345, ptr %t4346, ptr %t4347)
  store i32 %t4348, ptr %temp_id
  br label %label_1442
label_1441:
  %t4349 = load ptr, ptr %op_type
  %t4350 = load ptr, ptr %left_val
  %t4351 = load ptr, ptr %right_val
  %t4352 = call i32 @ir_srem(ptr %t4349, ptr %t4350, ptr %t4351)
  store i32 %t4352, ptr %temp_id
  br label %label_1442
label_1442:
  br label %label_1439
label_1439:
  %t4353 = load ptr, ptr %op
  %t4354 = getelementptr inbounds [4 x i8], ptr @.str.s603, i64 0, i64 0
  %t4355 = call i32 @str_equals(ptr %t4353, ptr %t4354)
  %t4356 = icmp eq i32 %t4355, 1
  br i1 %t4356, label %label_1443, label %label_1445
label_1443:
  %t4357 = getelementptr inbounds [3 x i8], ptr @.str.s604, i64 0, i64 0
  %t4358 = load ptr, ptr %left_val
  %t4359 = load ptr, ptr %right_val
  %t4360 = call i32 @ir_and(ptr %t4357, ptr %t4358, ptr %t4359)
  store i32 %t4360, ptr %temp_id
  br label %label_1445
label_1445:
  %t4361 = load ptr, ptr %op
  %t4362 = getelementptr inbounds [3 x i8], ptr @.str.s605, i64 0, i64 0
  %t4363 = call i32 @str_equals(ptr %t4361, ptr %t4362)
  %t4364 = icmp eq i32 %t4363, 1
  br i1 %t4364, label %label_1446, label %label_1448
label_1446:
  %t4365 = getelementptr inbounds [3 x i8], ptr @.str.s606, i64 0, i64 0
  %t4366 = load ptr, ptr %left_val
  %t4367 = load ptr, ptr %right_val
  %t4368 = call i32 @ir_or(ptr %t4365, ptr %t4366, ptr %t4367)
  store i32 %t4368, ptr %temp_id
  br label %label_1448
label_1448:
  %t4369 = load i32, ptr %temp_id
  %t4370 = call ptr @ir_get_temp_name(i32 %t4369)
  ret ptr %t4370
label_1352:
  %t4371 = load ptr, ptr %expr
  %t4372 = getelementptr inbounds %ASTNode, ptr %t4371, i32 0, i32 0
  %t4373 = load i32, ptr %t4372
  %t4374 = icmp eq i32 %t4373, 24
  br i1 %t4374, label %label_1449, label %label_1451
label_1449:
  %t4375 = load ptr, ptr %expr
  %t4376 = getelementptr inbounds %ASTNode, ptr %t4375, i32 0, i32 5
  %t4377 = load ptr, ptr %t4376
  %t4378 = call ptr @ptr_to_node(ptr %t4377)
  store ptr %t4378, ptr %callee
  %t4379 = load ptr, ptr %callee
  %t4380 = getelementptr inbounds %ASTNode, ptr %t4379, i32 0, i32 1
  %t4381 = load ptr, ptr %t4380
  store ptr %t4381, ptr %func_name
  %t4382 = load ptr, ptr %func_name
  %t4383 = getelementptr inbounds [5 x i8], ptr @.str.s607, i64 0, i64 0
  %t4384 = call i32 @str_equals(ptr %t4382, ptr %t4383)
  %t4385 = icmp eq i32 %t4384, 1
  br i1 %t4385, label %label_1452, label %label_1454
label_1452:
  %t4386 = load ptr, ptr %expr
  %t4387 = getelementptr inbounds %ASTNode, ptr %t4386, i32 0, i32 6
  %t4388 = load ptr, ptr %t4387
  store ptr %t4388, ptr %drop_arg
  %t4389 = load ptr, ptr %drop_arg
  %t4390 = getelementptr inbounds [1 x i8], ptr @.str.s608, i64 0, i64 0
  %t4391 = call i32 @str_equals(ptr %t4389, ptr %t4390)
  %t4392 = icmp eq i32 %t4391, 0
  br i1 %t4392, label %label_1455, label %label_1457
label_1455:
  %t4393 = load ptr, ptr %drop_arg
  %t4394 = call ptr @ptr_to_node(ptr %t4393)
  %t4395 = call ptr @generate_expression__Struct_ASTNode(ptr %t4394)
  store ptr %t4395, ptr %drop_val
  call void @ir_call_begin()
  %t4396 = getelementptr inbounds [4 x i8], ptr @.str.s609, i64 0, i64 0
  %t4397 = load ptr, ptr %drop_val
  call void @ir_call_arg(ptr %t4396, ptr %t4397)
  %t4398 = getelementptr inbounds [5 x i8], ptr @.str.s610, i64 0, i64 0
  %t4399 = getelementptr inbounds [5 x i8], ptr @.str.s611, i64 0, i64 0
  %t4400 = call i32 @ir_call_end(ptr %t4398, ptr %t4399)
  br label %label_1457
label_1457:
  %t4401 = getelementptr inbounds [1 x i8], ptr @.str.s612, i64 0, i64 0
  ret ptr %t4401
label_1454:
  store i32 0, ptr %is_print
  %t4402 = load ptr, ptr %func_name
  %t4403 = getelementptr inbounds [6 x i8], ptr @.str.s613, i64 0, i64 0
  %t4404 = call i32 @str_equals(ptr %t4402, ptr %t4403)
  %t4405 = icmp eq i32 %t4404, 1
  br i1 %t4405, label %label_1458, label %label_1460
label_1458:
  store i32 1, ptr %is_print
  br label %label_1460
label_1460:
  %t4406 = load ptr, ptr %func_name
  %t4407 = getelementptr inbounds [8 x i8], ptr @.str.s614, i64 0, i64 0
  %t4408 = call i32 @str_equals(ptr %t4406, ptr %t4407)
  %t4409 = icmp eq i32 %t4408, 1
  br i1 %t4409, label %label_1461, label %label_1463
label_1461:
  store i32 2, ptr %is_print
  br label %label_1463
label_1463:
  %t4410 = load i32, ptr %is_print
  %t4411 = icmp sgt i32 %t4410, 0
  br i1 %t4411, label %label_1464, label %label_1466
label_1464:
  %t4412 = load ptr, ptr %expr
  %t4413 = getelementptr inbounds %ASTNode, ptr %t4412, i32 0, i32 6
  %t4414 = load ptr, ptr %t4413
  store ptr %t4414, ptr %arg_ptr
  %t4415 = load ptr, ptr %arg_ptr
  %t4416 = getelementptr inbounds [1 x i8], ptr @.str.s615, i64 0, i64 0
  %t4417 = call i32 @str_equals(ptr %t4415, ptr %t4416)
  %t4418 = icmp eq i32 %t4417, 0
  br i1 %t4418, label %label_1467, label %label_1469
label_1467:
  %t4419 = load ptr, ptr %arg_ptr
  %t4420 = call ptr @ptr_to_node(ptr %t4419)
  store ptr %t4420, ptr %arg_node
  %t4421 = load ptr, ptr %arg_node
  %t4422 = call ptr @generate_expression__Struct_ASTNode(ptr %t4421)
  store ptr %t4422, ptr %arg_val
  %t4423 = load ptr, ptr %arg_node
  %t4424 = call ptr @get_expr_type__Struct_ASTNode(ptr %t4423)
  store ptr %t4424, ptr %arg_type
  call void @ir_call_begin()
  %t4425 = load ptr, ptr %arg_type
  %t4426 = getelementptr inbounds [4 x i8], ptr @.str.s616, i64 0, i64 0
  %t4427 = call i32 @str_equals(ptr %t4425, ptr %t4426)
  %t4428 = icmp eq i32 %t4427, 1
  br i1 %t4428, label %label_1470, label %label_1471
label_1470:
  %t4429 = getelementptr inbounds [4 x i8], ptr @.str.s617, i64 0, i64 0
  %t4430 = load ptr, ptr %arg_val
  call void @ir_call_arg(ptr %t4429, ptr %t4430)
  %t4431 = load i32, ptr %is_print
  %t4432 = icmp eq i32 %t4431, 1
  br i1 %t4432, label %label_1473, label %label_1474
label_1473:
  %t4433 = getelementptr inbounds [5 x i8], ptr @.str.s618, i64 0, i64 0
  %t4434 = getelementptr inbounds [6 x i8], ptr @.str.s619, i64 0, i64 0
  %t4435 = call i32 @ir_call_end(ptr %t4433, ptr %t4434)
  br label %label_1475
label_1474:
  %t4436 = getelementptr inbounds [5 x i8], ptr @.str.s620, i64 0, i64 0
  %t4437 = getelementptr inbounds [8 x i8], ptr @.str.s621, i64 0, i64 0
  %t4438 = call i32 @ir_call_end(ptr %t4436, ptr %t4437)
  br label %label_1475
label_1475:
  br label %label_1472
label_1471:
  %t4439 = load ptr, ptr %arg_type
  %t4440 = getelementptr inbounds [7 x i8], ptr @.str.s622, i64 0, i64 0
  %t4441 = call i32 @str_equals(ptr %t4439, ptr %t4440)
  %t4442 = icmp eq i32 %t4441, 1
  br i1 %t4442, label %label_1476, label %label_1477
label_1476:
  %t4443 = getelementptr inbounds [7 x i8], ptr @.str.s623, i64 0, i64 0
  %t4444 = load ptr, ptr %arg_val
  call void @ir_call_arg(ptr %t4443, ptr %t4444)
  %t4445 = load i32, ptr %is_print
  %t4446 = icmp eq i32 %t4445, 1
  br i1 %t4446, label %label_1479, label %label_1480
label_1479:
  %t4447 = getelementptr inbounds [5 x i8], ptr @.str.s624, i64 0, i64 0
  %t4448 = getelementptr inbounds [12 x i8], ptr @.str.s625, i64 0, i64 0
  %t4449 = call i32 @ir_call_end(ptr %t4447, ptr %t4448)
  br label %label_1481
label_1480:
  %t4450 = getelementptr inbounds [5 x i8], ptr @.str.s626, i64 0, i64 0
  %t4451 = getelementptr inbounds [14 x i8], ptr @.str.s627, i64 0, i64 0
  %t4452 = call i32 @ir_call_end(ptr %t4450, ptr %t4451)
  br label %label_1481
label_1481:
  br label %label_1478
label_1477:
  %t4453 = load ptr, ptr %arg_type
  %t4454 = call ptr @storage_type__String(ptr %t4453)
  %t4455 = load ptr, ptr %arg_val
  call void @ir_call_arg(ptr %t4454, ptr %t4455)
  %t4456 = load i32, ptr %is_print
  %t4457 = icmp eq i32 %t4456, 1
  br i1 %t4457, label %label_1482, label %label_1483
label_1482:
  %t4458 = getelementptr inbounds [5 x i8], ptr @.str.s628, i64 0, i64 0
  %t4459 = getelementptr inbounds [10 x i8], ptr @.str.s629, i64 0, i64 0
  %t4460 = call i32 @ir_call_end(ptr %t4458, ptr %t4459)
  br label %label_1484
label_1483:
  %t4461 = getelementptr inbounds [5 x i8], ptr @.str.s630, i64 0, i64 0
  %t4462 = getelementptr inbounds [12 x i8], ptr @.str.s631, i64 0, i64 0
  %t4463 = call i32 @ir_call_end(ptr %t4461, ptr %t4462)
  br label %label_1484
label_1484:
  br label %label_1478
label_1478:
  br label %label_1472
label_1472:
  br label %label_1469
label_1469:
  %t4464 = getelementptr inbounds [1 x i8], ptr @.str.s632, i64 0, i64 0
  ret ptr %t4464
label_1466:
  call void @ir_call_begin()
  %t4465 = load ptr, ptr %expr
  %t4466 = getelementptr inbounds %ASTNode, ptr %t4465, i32 0, i32 6
  %t4467 = load ptr, ptr %t4466
  store ptr %t4467, ptr %arg_ptr
  br label %label_1485
label_1485:
  %t4468 = load ptr, ptr %arg_ptr
  %t4469 = getelementptr inbounds [1 x i8], ptr @.str.s633, i64 0, i64 0
  %t4470 = call i32 @str_equals(ptr %t4468, ptr %t4469)
  %t4471 = icmp eq i32 %t4470, 0
  br i1 %t4471, label %label_1486, label %label_1487
label_1486:
  %t4472 = load ptr, ptr %arg_ptr
  %t4473 = call ptr @ptr_to_node(ptr %t4472)
  store ptr %t4473, ptr %arg_node
  %t4474 = load ptr, ptr %arg_node
  %t4475 = call ptr @generate_expression__Struct_ASTNode(ptr %t4474)
  store ptr %t4475, ptr %arg_val
  %t4476 = load ptr, ptr %arg_node
  %t4477 = call ptr @get_expr_type__Struct_ASTNode(ptr %t4476)
  %t4478 = call ptr @storage_type__String(ptr %t4477)
  %t4479 = load ptr, ptr %arg_val
  call void @ir_call_arg(ptr %t4478, ptr %t4479)
  %t4480 = load ptr, ptr %arg_node
  %t4481 = getelementptr inbounds %ASTNode, ptr %t4480, i32 0, i32 8
  %t4482 = load ptr, ptr %t4481
  store ptr %t4482, ptr %arg_ptr
  br label %label_1485
label_1487:
  %t4483 = load ptr, ptr %func_name
  store ptr %t4483, ptr %call_name
  %t4484 = load ptr, ptr %expr
  %t4485 = getelementptr inbounds %ASTNode, ptr %t4484, i32 0, i32 2
  %t4486 = load ptr, ptr %t4485
  %t4487 = getelementptr inbounds [1 x i8], ptr @.str.s634, i64 0, i64 0
  %t4488 = call i32 @str_equals(ptr %t4486, ptr %t4487)
  %t4489 = icmp eq i32 %t4488, 0
  br i1 %t4489, label %label_1488, label %label_1490
label_1488:
  %t4490 = load ptr, ptr %expr
  %t4491 = getelementptr inbounds %ASTNode, ptr %t4490, i32 0, i32 2
  %t4492 = load ptr, ptr %t4491
  store ptr %t4492, ptr %call_name
  br label %label_1490
label_1490:
  %t4493 = load ptr, ptr %expr
  %t4494 = call ptr @get_expr_type__Struct_ASTNode(ptr %t4493)
  %t4495 = call ptr @storage_type__String(ptr %t4494)
  store ptr %t4495, ptr %ret_type
  %t4496 = load ptr, ptr %ret_type
  %t4497 = getelementptr inbounds [5 x i8], ptr @.str.s635, i64 0, i64 0
  %t4498 = call i32 @str_equals(ptr %t4496, ptr %t4497)
  %t4499 = icmp eq i32 %t4498, 1
  br i1 %t4499, label %label_1491, label %label_1493
label_1491:
  %t4500 = getelementptr inbounds [5 x i8], ptr @.str.s636, i64 0, i64 0
  %t4501 = load ptr, ptr %call_name
  %t4502 = call i32 @ir_call_end(ptr %t4500, ptr %t4501)
  %t4503 = getelementptr inbounds [1 x i8], ptr @.str.s637, i64 0, i64 0
  ret ptr %t4503
label_1493:
  %t4504 = load ptr, ptr %ret_type
  %t4505 = load ptr, ptr %call_name
  %t4506 = call i32 @ir_call_end(ptr %t4504, ptr %t4505)
  store i32 %t4506, ptr %temp_id
  %t4507 = load i32, ptr %temp_id
  %t4508 = call ptr @ir_get_temp_name(i32 %t4507)
  ret ptr %t4508
label_1451:
  %t4509 = getelementptr inbounds [2 x i8], ptr @.str.s638, i64 0, i64 0
  ret ptr %t4509
}

define void @generate_statement__Struct_ASTNode(ptr %p_stmt) {
  %stmt = alloca ptr
  %var_name = alloca ptr
  %var_type = alloca ptr
  %type_node = alloca ptr
  %store_type = alloca ptr
  %init_val = alloca ptr
  %target_node = alloca ptr
  %val = alloca ptr
  %object_node = alloca ptr
  %object_val = alloca ptr
  %object_type = alloca ptr
  %struct_name = alloca ptr
  %field_index = alloca i32
  %field_type = alloca ptr
  %gep_temp = alloca i32
  %gep_name = alloca ptr
  %ret_val = alloca ptr
  %cond_val = alloca ptr
  %then_label = alloca i32
  %else_label = alloca i32
  %end_label = alloca i32
  %else_node = alloca ptr
  %cond_label = alloca i32
  %body_label = alloca i32
  %loop_var = alloca ptr
  %start_val = alloca ptr
  %incr_label = alloca i32
  %iv = alloca i32
  %end_val = alloca ptr
  %cmp = alloca i32
  %iv2 = alloca i32
  %next = alloca i32
  %target = alloca i32
  %scrut_val = alloca ptr
  %scrut_type = alloca ptr
  %needs_final_br = alloca i1
  %arm_ptr = alloca ptr
  %arm = alloca ptr
  %pat_val = alloca ptr
  %arm_label = alloca i32
  %next_label = alloca i32
  store ptr %p_stmt, ptr %stmt
  %t4551 = load ptr, ptr %stmt
  %t4552 = getelementptr inbounds %ASTNode, ptr %t4551, i32 0, i32 0
  %t4553 = load i32, ptr %t4552
  %t4554 = icmp eq i32 %t4553, 3
  br i1 %t4554, label %label_1494, label %label_1496
label_1494:
  %t4555 = load ptr, ptr %stmt
  %t4556 = getelementptr inbounds %ASTNode, ptr %t4555, i32 0, i32 1
  %t4557 = load ptr, ptr %t4556
  store ptr %t4557, ptr %var_name
  %t4558 = getelementptr inbounds [4 x i8], ptr @.str.s639, i64 0, i64 0
  store ptr %t4558, ptr %var_type
  %t4559 = load ptr, ptr %stmt
  %t4560 = getelementptr inbounds %ASTNode, ptr %t4559, i32 0, i32 5
  %t4561 = load ptr, ptr %t4560
  %t4562 = getelementptr inbounds [1 x i8], ptr @.str.s640, i64 0, i64 0
  %t4563 = call i32 @str_equals(ptr %t4561, ptr %t4562)
  %t4564 = icmp eq i32 %t4563, 0
  br i1 %t4564, label %label_1497, label %label_1498
label_1497:
  %t4565 = load ptr, ptr %stmt
  %t4566 = getelementptr inbounds %ASTNode, ptr %t4565, i32 0, i32 5
  %t4567 = load ptr, ptr %t4566
  %t4568 = call ptr @ptr_to_node(ptr %t4567)
  store ptr %t4568, ptr %type_node
  %t4569 = load ptr, ptr %type_node
  %t4570 = call ptr @map_type_node__Struct_ASTNode(ptr %t4569)
  store ptr %t4570, ptr %var_type
  br label %label_1499
label_1498:
  %t4571 = load ptr, ptr %stmt
  %t4572 = getelementptr inbounds %ASTNode, ptr %t4571, i32 0, i32 6
  %t4573 = load ptr, ptr %t4572
  %t4574 = getelementptr inbounds [1 x i8], ptr @.str.s641, i64 0, i64 0
  %t4575 = call i32 @str_equals(ptr %t4573, ptr %t4574)
  %t4576 = icmp eq i32 %t4575, 0
  br i1 %t4576, label %label_1500, label %label_1502
label_1500:
  %t4577 = load ptr, ptr %stmt
  %t4578 = getelementptr inbounds %ASTNode, ptr %t4577, i32 0, i32 6
  %t4579 = load ptr, ptr %t4578
  %t4580 = call ptr @ptr_to_node(ptr %t4579)
  %t4581 = call ptr @get_expr_type__Struct_ASTNode(ptr %t4580)
  store ptr %t4581, ptr %var_type
  br label %label_1502
label_1502:
  br label %label_1499
label_1499:
  %t4582 = load ptr, ptr %var_name
  %t4583 = load ptr, ptr %var_type
  call void @ir_set_var_type(ptr %t4582, ptr %t4583)
  %t4584 = load ptr, ptr %var_type
  %t4585 = call ptr @storage_type__String(ptr %t4584)
  store ptr %t4585, ptr %store_type
  %t4586 = load ptr, ptr %store_type
  %t4587 = load ptr, ptr %var_name
  %t4588 = call i32 @ir_alloca(ptr %t4586, ptr %t4587)
  %t4589 = load ptr, ptr %stmt
  %t4590 = getelementptr inbounds %ASTNode, ptr %t4589, i32 0, i32 6
  %t4591 = load ptr, ptr %t4590
  %t4592 = getelementptr inbounds [1 x i8], ptr @.str.s642, i64 0, i64 0
  %t4593 = call i32 @str_equals(ptr %t4591, ptr %t4592)
  %t4594 = icmp eq i32 %t4593, 0
  br i1 %t4594, label %label_1503, label %label_1505
label_1503:
  %t4595 = load ptr, ptr %stmt
  %t4596 = getelementptr inbounds %ASTNode, ptr %t4595, i32 0, i32 6
  %t4597 = load ptr, ptr %t4596
  %t4598 = call ptr @ptr_to_node(ptr %t4597)
  %t4599 = call ptr @generate_expression__Struct_ASTNode(ptr %t4598)
  store ptr %t4599, ptr %init_val
  %t4600 = load ptr, ptr %store_type
  %t4601 = load ptr, ptr %init_val
  %t4602 = load ptr, ptr %var_name
  call void @ir_store(ptr %t4600, ptr %t4601, ptr %t4602)
  br label %label_1505
label_1505:
  br label %label_1496
label_1496:
  %t4603 = load ptr, ptr %stmt
  %t4604 = getelementptr inbounds %ASTNode, ptr %t4603, i32 0, i32 0
  %t4605 = load i32, ptr %t4604
  %t4606 = icmp eq i32 %t4605, 16
  br i1 %t4606, label %label_1506, label %label_1508
label_1506:
  %t4607 = load ptr, ptr %stmt
  %t4608 = getelementptr inbounds %ASTNode, ptr %t4607, i32 0, i32 5
  %t4609 = load ptr, ptr %t4608
  %t4610 = call ptr @ptr_to_node(ptr %t4609)
  store ptr %t4610, ptr %target_node
  %t4611 = load ptr, ptr %target_node
  %t4612 = getelementptr inbounds %ASTNode, ptr %t4611, i32 0, i32 0
  %t4613 = load i32, ptr %t4612
  %t4614 = icmp eq i32 %t4613, 23
  br i1 %t4614, label %label_1509, label %label_1511
label_1509:
  %t4615 = load ptr, ptr %target_node
  %t4616 = getelementptr inbounds %ASTNode, ptr %t4615, i32 0, i32 1
  %t4617 = load ptr, ptr %t4616
  store ptr %t4617, ptr %var_name
  %t4618 = load ptr, ptr %var_name
  %t4619 = call ptr @ir_get_var_type(ptr %t4618)
  store ptr %t4619, ptr %var_type
  %t4620 = load ptr, ptr %var_type
  %t4621 = call ptr @storage_type__String(ptr %t4620)
  store ptr %t4621, ptr %store_type
  %t4622 = load ptr, ptr %stmt
  %t4623 = getelementptr inbounds %ASTNode, ptr %t4622, i32 0, i32 6
  %t4624 = load ptr, ptr %t4623
  %t4625 = call ptr @ptr_to_node(ptr %t4624)
  %t4626 = call ptr @generate_expression__Struct_ASTNode(ptr %t4625)
  store ptr %t4626, ptr %val
  %t4627 = load ptr, ptr %var_name
  %t4628 = call i32 @ir_is_global_name(ptr %t4627)
  %t4629 = icmp eq i32 %t4628, 1
  br i1 %t4629, label %label_1512, label %label_1513
label_1512:
  %t4630 = load ptr, ptr %store_type
  %t4631 = load ptr, ptr %val
  %t4632 = load ptr, ptr %var_name
  call void @ir_store_global(ptr %t4630, ptr %t4631, ptr %t4632)
  br label %label_1514
label_1513:
  %t4633 = load ptr, ptr %store_type
  %t4634 = load ptr, ptr %val
  %t4635 = load ptr, ptr %var_name
  call void @ir_store(ptr %t4633, ptr %t4634, ptr %t4635)
  br label %label_1514
label_1514:
  br label %label_1511
label_1511:
  %t4636 = load ptr, ptr %target_node
  %t4637 = getelementptr inbounds %ASTNode, ptr %t4636, i32 0, i32 0
  %t4638 = load i32, ptr %t4637
  %t4639 = icmp eq i32 %t4638, 25
  br i1 %t4639, label %label_1515, label %label_1517
label_1515:
  %t4640 = load ptr, ptr %target_node
  %t4641 = getelementptr inbounds %ASTNode, ptr %t4640, i32 0, i32 5
  %t4642 = load ptr, ptr %t4641
  %t4643 = call ptr @ptr_to_node(ptr %t4642)
  store ptr %t4643, ptr %object_node
  %t4644 = load ptr, ptr %object_node
  %t4645 = call ptr @generate_expression__Struct_ASTNode(ptr %t4644)
  store ptr %t4645, ptr %object_val
  %t4646 = load ptr, ptr %object_node
  %t4647 = call ptr @get_expr_type__Struct_ASTNode(ptr %t4646)
  store ptr %t4647, ptr %object_type
  %t4648 = load ptr, ptr %object_type
  %t4649 = call ptr @struct_type_name__String(ptr %t4648)
  store ptr %t4649, ptr %struct_name
  %t4650 = load ptr, ptr %struct_name
  %t4651 = load ptr, ptr %target_node
  %t4652 = getelementptr inbounds %ASTNode, ptr %t4651, i32 0, i32 1
  %t4653 = load ptr, ptr %t4652
  %t4654 = call i32 @ir_get_struct_field_index(ptr %t4650, ptr %t4653)
  store i32 %t4654, ptr %field_index
  %t4655 = load ptr, ptr %struct_name
  %t4656 = load ptr, ptr %target_node
  %t4657 = getelementptr inbounds %ASTNode, ptr %t4656, i32 0, i32 1
  %t4658 = load ptr, ptr %t4657
  %t4659 = call ptr @ir_get_struct_field_type(ptr %t4655, ptr %t4658)
  %t4660 = call ptr @storage_type__String(ptr %t4659)
  store ptr %t4660, ptr %field_type
  %t4661 = load ptr, ptr %stmt
  %t4662 = getelementptr inbounds %ASTNode, ptr %t4661, i32 0, i32 6
  %t4663 = load ptr, ptr %t4662
  %t4664 = call ptr @ptr_to_node(ptr %t4663)
  %t4665 = call ptr @generate_expression__Struct_ASTNode(ptr %t4664)
  store ptr %t4665, ptr %val
  %t4666 = call i32 @ir_get_temp()
  store i32 %t4666, ptr %gep_temp
  %t4667 = load i32, ptr %gep_temp
  %t4668 = call ptr @ir_get_temp_name(i32 %t4667)
  store ptr %t4668, ptr %gep_name
  %t4669 = getelementptr inbounds [3 x i8], ptr @.str.s643, i64 0, i64 0
  call void @ir_append(ptr %t4669)
  %t4670 = load ptr, ptr %gep_name
  call void @ir_append(ptr %t4670)
  %t4671 = getelementptr inbounds [27 x i8], ptr @.str.s644, i64 0, i64 0
  call void @ir_append(ptr %t4671)
  %t4672 = getelementptr inbounds [2 x i8], ptr @.str.s645, i64 0, i64 0
  %t4673 = load ptr, ptr %struct_name
  %t4674 = call ptr @str_concat(ptr %t4672, ptr %t4673)
  call void @ir_append(ptr %t4674)
  %t4675 = getelementptr inbounds [7 x i8], ptr @.str.s646, i64 0, i64 0
  call void @ir_append(ptr %t4675)
  %t4676 = load ptr, ptr %object_val
  call void @ir_append(ptr %t4676)
  %t4677 = getelementptr inbounds [14 x i8], ptr @.str.s647, i64 0, i64 0
  call void @ir_append(ptr %t4677)
  %t4678 = load i32, ptr %field_index
  %t4679 = call ptr @int_to_str(i32 %t4678)
  call void @ir_append_line(ptr %t4679)
  %t4680 = getelementptr inbounds [9 x i8], ptr @.str.s648, i64 0, i64 0
  call void @ir_append(ptr %t4680)
  %t4681 = load ptr, ptr %field_type
  call void @ir_append(ptr %t4681)
  %t4682 = getelementptr inbounds [2 x i8], ptr @.str.s649, i64 0, i64 0
  call void @ir_append(ptr %t4682)
  %t4683 = load ptr, ptr %val
  call void @ir_append(ptr %t4683)
  %t4684 = getelementptr inbounds [7 x i8], ptr @.str.s650, i64 0, i64 0
  call void @ir_append(ptr %t4684)
  %t4685 = load ptr, ptr %gep_name
  call void @ir_append_line(ptr %t4685)
  br label %label_1517
label_1517:
  br label %label_1508
label_1508:
  %t4686 = load ptr, ptr %stmt
  %t4687 = getelementptr inbounds %ASTNode, ptr %t4686, i32 0, i32 0
  %t4688 = load i32, ptr %t4687
  %t4689 = icmp eq i32 %t4688, 15
  br i1 %t4689, label %label_1518, label %label_1520
label_1518:
  %t4690 = load ptr, ptr %stmt
  %t4691 = getelementptr inbounds %ASTNode, ptr %t4690, i32 0, i32 5
  %t4692 = load ptr, ptr %t4691
  %t4693 = getelementptr inbounds [1 x i8], ptr @.str.s651, i64 0, i64 0
  %t4694 = call i32 @str_equals(ptr %t4692, ptr %t4693)
  %t4695 = icmp eq i32 %t4694, 0
  br i1 %t4695, label %label_1521, label %label_1522
label_1521:
  %t4696 = load ptr, ptr %stmt
  %t4697 = getelementptr inbounds %ASTNode, ptr %t4696, i32 0, i32 5
  %t4698 = load ptr, ptr %t4697
  %t4699 = call ptr @ptr_to_node(ptr %t4698)
  %t4700 = call ptr @generate_expression__Struct_ASTNode(ptr %t4699)
  store ptr %t4700, ptr %ret_val
  %t4701 = load ptr, ptr %stmt
  %t4702 = getelementptr inbounds %ASTNode, ptr %t4701, i32 0, i32 5
  %t4703 = load ptr, ptr %t4702
  %t4704 = call ptr @ptr_to_node(ptr %t4703)
  %t4705 = call ptr @get_expr_type__Struct_ASTNode(ptr %t4704)
  %t4706 = call ptr @storage_type__String(ptr %t4705)
  %t4707 = load ptr, ptr %ret_val
  call void @ir_ret(ptr %t4706, ptr %t4707)
  br label %label_1523
label_1522:
  call void @ir_ret_void()
  br label %label_1523
label_1523:
  call void @ir_set_returned()
  br label %label_1520
label_1520:
  %t4708 = load ptr, ptr %stmt
  %t4709 = getelementptr inbounds %ASTNode, ptr %t4708, i32 0, i32 0
  %t4710 = load i32, ptr %t4709
  %t4711 = icmp eq i32 %t4710, 17
  br i1 %t4711, label %label_1524, label %label_1526
label_1524:
  %t4712 = load ptr, ptr %stmt
  %t4713 = getelementptr inbounds %ASTNode, ptr %t4712, i32 0, i32 5
  %t4714 = load ptr, ptr %t4713
  %t4715 = getelementptr inbounds [1 x i8], ptr @.str.s652, i64 0, i64 0
  %t4716 = call i32 @str_equals(ptr %t4714, ptr %t4715)
  %t4717 = icmp eq i32 %t4716, 0
  br i1 %t4717, label %label_1527, label %label_1529
label_1527:
  %t4718 = load ptr, ptr %stmt
  %t4719 = getelementptr inbounds %ASTNode, ptr %t4718, i32 0, i32 5
  %t4720 = load ptr, ptr %t4719
  %t4721 = call ptr @ptr_to_node(ptr %t4720)
  %t4722 = call ptr @generate_expression__Struct_ASTNode(ptr %t4721)
  br label %label_1529
label_1529:
  br label %label_1526
label_1526:
  %t4723 = load ptr, ptr %stmt
  %t4724 = getelementptr inbounds %ASTNode, ptr %t4723, i32 0, i32 0
  %t4725 = load i32, ptr %t4724
  %t4726 = icmp eq i32 %t4725, 10
  br i1 %t4726, label %label_1530, label %label_1532
label_1530:
  %t4727 = load ptr, ptr %stmt
  %t4728 = getelementptr inbounds %ASTNode, ptr %t4727, i32 0, i32 5
  %t4729 = load ptr, ptr %t4728
  %t4730 = call ptr @ptr_to_node(ptr %t4729)
  %t4731 = call ptr @generate_expression__Struct_ASTNode(ptr %t4730)
  store ptr %t4731, ptr %cond_val
  %t4732 = call i32 @ir_get_label()
  store i32 %t4732, ptr %then_label
  %t4733 = call i32 @ir_get_label()
  store i32 %t4733, ptr %else_label
  %t4734 = call i32 @ir_get_label()
  store i32 %t4734, ptr %end_label
  %t4735 = load ptr, ptr %stmt
  %t4736 = getelementptr inbounds %ASTNode, ptr %t4735, i32 0, i32 7
  %t4737 = load ptr, ptr %t4736
  %t4738 = getelementptr inbounds [1 x i8], ptr @.str.s653, i64 0, i64 0
  %t4739 = call i32 @str_equals(ptr %t4737, ptr %t4738)
  %t4740 = icmp eq i32 %t4739, 0
  br i1 %t4740, label %label_1533, label %label_1534
label_1533:
  %t4741 = load ptr, ptr %cond_val
  %t4742 = load i32, ptr %then_label
  %t4743 = load i32, ptr %else_label
  call void @ir_cond_br_numbered(ptr %t4741, i32 %t4742, i32 %t4743)
  br label %label_1535
label_1534:
  %t4744 = load ptr, ptr %cond_val
  %t4745 = load i32, ptr %then_label
  %t4746 = load i32, ptr %end_label
  call void @ir_cond_br_numbered(ptr %t4744, i32 %t4745, i32 %t4746)
  br label %label_1535
label_1535:
  %t4747 = load i32, ptr %then_label
  call void @ir_label_numbered(i32 %t4747)
  %t4748 = load ptr, ptr %stmt
  %t4749 = getelementptr inbounds %ASTNode, ptr %t4748, i32 0, i32 6
  %t4750 = load ptr, ptr %t4749
  %t4751 = call ptr @ptr_to_node(ptr %t4750)
  call void @generate_block__Struct_ASTNode(ptr %t4751)
  %t4752 = call i32 @ir_has_returned()
  %t4753 = icmp eq i32 %t4752, 0
  br i1 %t4753, label %label_1536, label %label_1538
label_1536:
  %t4754 = load i32, ptr %end_label
  call void @ir_br_numbered(i32 %t4754)
  br label %label_1538
label_1538:
  call void @ir_clear_returned()
  %t4755 = load ptr, ptr %stmt
  %t4756 = getelementptr inbounds %ASTNode, ptr %t4755, i32 0, i32 7
  %t4757 = load ptr, ptr %t4756
  %t4758 = getelementptr inbounds [1 x i8], ptr @.str.s654, i64 0, i64 0
  %t4759 = call i32 @str_equals(ptr %t4757, ptr %t4758)
  %t4760 = icmp eq i32 %t4759, 0
  br i1 %t4760, label %label_1539, label %label_1541
label_1539:
  %t4761 = load i32, ptr %else_label
  call void @ir_label_numbered(i32 %t4761)
  %t4762 = load ptr, ptr %stmt
  %t4763 = getelementptr inbounds %ASTNode, ptr %t4762, i32 0, i32 7
  %t4764 = load ptr, ptr %t4763
  %t4765 = call ptr @ptr_to_node(ptr %t4764)
  store ptr %t4765, ptr %else_node
  %t4766 = load ptr, ptr %else_node
  %t4767 = getelementptr inbounds %ASTNode, ptr %t4766, i32 0, i32 0
  %t4768 = load i32, ptr %t4767
  %t4769 = icmp eq i32 %t4768, 10
  br i1 %t4769, label %label_1542, label %label_1543
label_1542:
  %t4770 = load ptr, ptr %else_node
  call void @generate_statement__Struct_ASTNode(ptr %t4770)
  br label %label_1544
label_1543:
  %t4771 = load ptr, ptr %else_node
  call void @generate_block__Struct_ASTNode(ptr %t4771)
  br label %label_1544
label_1544:
  %t4772 = call i32 @ir_has_returned()
  %t4773 = icmp eq i32 %t4772, 0
  br i1 %t4773, label %label_1545, label %label_1547
label_1545:
  %t4774 = load i32, ptr %end_label
  call void @ir_br_numbered(i32 %t4774)
  br label %label_1547
label_1547:
  call void @ir_clear_returned()
  br label %label_1541
label_1541:
  %t4775 = load i32, ptr %end_label
  call void @ir_label_numbered(i32 %t4775)
  br label %label_1532
label_1532:
  %t4776 = load ptr, ptr %stmt
  %t4777 = getelementptr inbounds %ASTNode, ptr %t4776, i32 0, i32 0
  %t4778 = load i32, ptr %t4777
  %t4779 = icmp eq i32 %t4778, 13
  br i1 %t4779, label %label_1548, label %label_1550
label_1548:
  %t4780 = call i32 @ir_get_label()
  store i32 %t4780, ptr %cond_label
  %t4781 = call i32 @ir_get_label()
  store i32 %t4781, ptr %body_label
  %t4782 = call i32 @ir_get_label()
  store i32 %t4782, ptr %end_label
  %t4783 = load i32, ptr %cond_label
  call void @ir_br_numbered(i32 %t4783)
  %t4784 = load i32, ptr %cond_label
  call void @ir_label_numbered(i32 %t4784)
  %t4785 = load ptr, ptr %stmt
  %t4786 = getelementptr inbounds %ASTNode, ptr %t4785, i32 0, i32 5
  %t4787 = load ptr, ptr %t4786
  %t4788 = call ptr @ptr_to_node(ptr %t4787)
  %t4789 = call ptr @generate_expression__Struct_ASTNode(ptr %t4788)
  store ptr %t4789, ptr %cond_val
  %t4790 = load ptr, ptr %cond_val
  %t4791 = load i32, ptr %body_label
  %t4792 = load i32, ptr %end_label
  call void @ir_cond_br_numbered(ptr %t4790, i32 %t4791, i32 %t4792)
  %t4793 = load i32, ptr %body_label
  call void @ir_label_numbered(i32 %t4793)
  %t4794 = load i32, ptr %cond_label
  %t4795 = load i32, ptr %end_label
  call void @ir_loop_push(i32 %t4794, i32 %t4795)
  %t4796 = load ptr, ptr %stmt
  %t4797 = getelementptr inbounds %ASTNode, ptr %t4796, i32 0, i32 6
  %t4798 = load ptr, ptr %t4797
  %t4799 = call ptr @ptr_to_node(ptr %t4798)
  call void @generate_block__Struct_ASTNode(ptr %t4799)
  call void @ir_loop_pop()
  %t4800 = call i32 @ir_has_returned()
  %t4801 = icmp eq i32 %t4800, 0
  br i1 %t4801, label %label_1551, label %label_1553
label_1551:
  %t4802 = load i32, ptr %cond_label
  call void @ir_br_numbered(i32 %t4802)
  br label %label_1553
label_1553:
  call void @ir_clear_returned()
  %t4803 = load i32, ptr %end_label
  call void @ir_label_numbered(i32 %t4803)
  br label %label_1550
label_1550:
  %t4804 = load ptr, ptr %stmt
  %t4805 = getelementptr inbounds %ASTNode, ptr %t4804, i32 0, i32 0
  %t4806 = load i32, ptr %t4805
  %t4807 = icmp eq i32 %t4806, 14
  br i1 %t4807, label %label_1554, label %label_1556
label_1554:
  %t4808 = call i32 @ir_get_label()
  store i32 %t4808, ptr %body_label
  %t4809 = call i32 @ir_get_label()
  store i32 %t4809, ptr %end_label
  %t4810 = load i32, ptr %body_label
  call void @ir_br_numbered(i32 %t4810)
  %t4811 = load i32, ptr %body_label
  call void @ir_label_numbered(i32 %t4811)
  %t4812 = load i32, ptr %body_label
  %t4813 = load i32, ptr %end_label
  call void @ir_loop_push(i32 %t4812, i32 %t4813)
  %t4814 = load ptr, ptr %stmt
  %t4815 = getelementptr inbounds %ASTNode, ptr %t4814, i32 0, i32 5
  %t4816 = load ptr, ptr %t4815
  %t4817 = call ptr @ptr_to_node(ptr %t4816)
  call void @generate_block__Struct_ASTNode(ptr %t4817)
  call void @ir_loop_pop()
  %t4818 = call i32 @ir_has_returned()
  %t4819 = icmp eq i32 %t4818, 0
  br i1 %t4819, label %label_1557, label %label_1559
label_1557:
  %t4820 = load i32, ptr %body_label
  call void @ir_br_numbered(i32 %t4820)
  br label %label_1559
label_1559:
  call void @ir_clear_returned()
  %t4821 = load i32, ptr %end_label
  call void @ir_label_numbered(i32 %t4821)
  br label %label_1556
label_1556:
  %t4822 = load ptr, ptr %stmt
  %t4823 = getelementptr inbounds %ASTNode, ptr %t4822, i32 0, i32 0
  %t4824 = load i32, ptr %t4823
  %t4825 = icmp eq i32 %t4824, 12
  br i1 %t4825, label %label_1560, label %label_1562
label_1560:
  %t4826 = load ptr, ptr %stmt
  %t4827 = getelementptr inbounds %ASTNode, ptr %t4826, i32 0, i32 1
  %t4828 = load ptr, ptr %t4827
  store ptr %t4828, ptr %loop_var
  %t4829 = load ptr, ptr %stmt
  %t4830 = getelementptr inbounds %ASTNode, ptr %t4829, i32 0, i32 5
  %t4831 = load ptr, ptr %t4830
  %t4832 = call ptr @ptr_to_node(ptr %t4831)
  %t4833 = call ptr @generate_expression__Struct_ASTNode(ptr %t4832)
  store ptr %t4833, ptr %start_val
  %t4834 = getelementptr inbounds [4 x i8], ptr @.str.s655, i64 0, i64 0
  %t4835 = load ptr, ptr %start_val
  %t4836 = load ptr, ptr %loop_var
  call void @ir_store(ptr %t4834, ptr %t4835, ptr %t4836)
  %t4837 = call i32 @ir_get_label()
  store i32 %t4837, ptr %cond_label
  %t4838 = call i32 @ir_get_label()
  store i32 %t4838, ptr %body_label
  %t4839 = call i32 @ir_get_label()
  store i32 %t4839, ptr %incr_label
  %t4840 = call i32 @ir_get_label()
  store i32 %t4840, ptr %end_label
  %t4841 = load i32, ptr %cond_label
  call void @ir_br_numbered(i32 %t4841)
  %t4842 = load i32, ptr %cond_label
  call void @ir_label_numbered(i32 %t4842)
  %t4843 = getelementptr inbounds [4 x i8], ptr @.str.s656, i64 0, i64 0
  %t4844 = load ptr, ptr %loop_var
  %t4845 = call i32 @ir_load(ptr %t4843, ptr %t4844)
  store i32 %t4845, ptr %iv
  %t4846 = load ptr, ptr %stmt
  %t4847 = getelementptr inbounds %ASTNode, ptr %t4846, i32 0, i32 6
  %t4848 = load ptr, ptr %t4847
  %t4849 = call ptr @ptr_to_node(ptr %t4848)
  %t4850 = call ptr @generate_expression__Struct_ASTNode(ptr %t4849)
  store ptr %t4850, ptr %end_val
  %t4851 = getelementptr inbounds [4 x i8], ptr @.str.s657, i64 0, i64 0
  %t4852 = load i32, ptr %iv
  %t4853 = call ptr @ir_get_temp_name(i32 %t4852)
  %t4854 = load ptr, ptr %end_val
  %t4855 = call i32 @ir_icmp_slt(ptr %t4851, ptr %t4853, ptr %t4854)
  store i32 %t4855, ptr %cmp
  %t4856 = load i32, ptr %cmp
  %t4857 = call ptr @ir_get_temp_name(i32 %t4856)
  %t4858 = load i32, ptr %body_label
  %t4859 = load i32, ptr %end_label
  call void @ir_cond_br_numbered(ptr %t4857, i32 %t4858, i32 %t4859)
  %t4860 = load i32, ptr %body_label
  call void @ir_label_numbered(i32 %t4860)
  %t4861 = load i32, ptr %incr_label
  %t4862 = load i32, ptr %end_label
  call void @ir_loop_push(i32 %t4861, i32 %t4862)
  %t4863 = load ptr, ptr %stmt
  %t4864 = getelementptr inbounds %ASTNode, ptr %t4863, i32 0, i32 7
  %t4865 = load ptr, ptr %t4864
  %t4866 = call ptr @ptr_to_node(ptr %t4865)
  call void @generate_block__Struct_ASTNode(ptr %t4866)
  call void @ir_loop_pop()
  %t4867 = call i32 @ir_has_returned()
  %t4868 = icmp eq i32 %t4867, 0
  br i1 %t4868, label %label_1563, label %label_1565
label_1563:
  %t4869 = load i32, ptr %incr_label
  call void @ir_br_numbered(i32 %t4869)
  br label %label_1565
label_1565:
  call void @ir_clear_returned()
  %t4870 = load i32, ptr %incr_label
  call void @ir_label_numbered(i32 %t4870)
  %t4871 = getelementptr inbounds [4 x i8], ptr @.str.s658, i64 0, i64 0
  %t4872 = load ptr, ptr %loop_var
  %t4873 = call i32 @ir_load(ptr %t4871, ptr %t4872)
  store i32 %t4873, ptr %iv2
  %t4874 = getelementptr inbounds [4 x i8], ptr @.str.s659, i64 0, i64 0
  %t4875 = load i32, ptr %iv2
  %t4876 = call ptr @ir_get_temp_name(i32 %t4875)
  %t4877 = getelementptr inbounds [2 x i8], ptr @.str.s660, i64 0, i64 0
  %t4878 = call i32 @ir_add(ptr %t4874, ptr %t4876, ptr %t4877)
  store i32 %t4878, ptr %next
  %t4879 = getelementptr inbounds [4 x i8], ptr @.str.s661, i64 0, i64 0
  %t4880 = load i32, ptr %next
  %t4881 = call ptr @ir_get_temp_name(i32 %t4880)
  %t4882 = load ptr, ptr %loop_var
  call void @ir_store(ptr %t4879, ptr %t4881, ptr %t4882)
  %t4883 = load i32, ptr %cond_label
  call void @ir_br_numbered(i32 %t4883)
  %t4884 = load i32, ptr %end_label
  call void @ir_label_numbered(i32 %t4884)
  br label %label_1562
label_1562:
  %t4885 = load ptr, ptr %stmt
  %t4886 = getelementptr inbounds %ASTNode, ptr %t4885, i32 0, i32 0
  %t4887 = load i32, ptr %t4886
  %t4888 = icmp eq i32 %t4887, 18
  br i1 %t4888, label %label_1566, label %label_1568
label_1566:
  %t4889 = call i32 @ir_loop_break_label()
  store i32 %t4889, ptr %target
  %t4890 = load i32, ptr %target
  %t4891 = icmp sge i32 %t4890, 0
  br i1 %t4891, label %label_1569, label %label_1571
label_1569:
  %t4892 = load i32, ptr %target
  call void @ir_br_numbered(i32 %t4892)
  call void @ir_set_returned()
  br label %label_1571
label_1571:
  br label %label_1568
label_1568:
  %t4893 = load ptr, ptr %stmt
  %t4894 = getelementptr inbounds %ASTNode, ptr %t4893, i32 0, i32 0
  %t4895 = load i32, ptr %t4894
  %t4896 = icmp eq i32 %t4895, 19
  br i1 %t4896, label %label_1572, label %label_1574
label_1572:
  %t4897 = call i32 @ir_loop_continue_label()
  store i32 %t4897, ptr %target
  %t4898 = load i32, ptr %target
  %t4899 = icmp sge i32 %t4898, 0
  br i1 %t4899, label %label_1575, label %label_1577
label_1575:
  %t4900 = load i32, ptr %target
  call void @ir_br_numbered(i32 %t4900)
  call void @ir_set_returned()
  br label %label_1577
label_1577:
  br label %label_1574
label_1574:
  %t4901 = load ptr, ptr %stmt
  %t4902 = getelementptr inbounds %ASTNode, ptr %t4901, i32 0, i32 0
  %t4903 = load i32, ptr %t4902
  %t4904 = icmp eq i32 %t4903, 11
  br i1 %t4904, label %label_1578, label %label_1580
label_1578:
  %t4905 = load ptr, ptr %stmt
  %t4906 = getelementptr inbounds %ASTNode, ptr %t4905, i32 0, i32 5
  %t4907 = load ptr, ptr %t4906
  %t4908 = call ptr @ptr_to_node(ptr %t4907)
  %t4909 = call ptr @generate_expression__Struct_ASTNode(ptr %t4908)
  store ptr %t4909, ptr %scrut_val
  %t4910 = load ptr, ptr %stmt
  %t4911 = getelementptr inbounds %ASTNode, ptr %t4910, i32 0, i32 5
  %t4912 = load ptr, ptr %t4911
  %t4913 = call ptr @ptr_to_node(ptr %t4912)
  %t4914 = call ptr @get_expr_type__Struct_ASTNode(ptr %t4913)
  store ptr %t4914, ptr %scrut_type
  %t4915 = call i32 @ir_get_label()
  store i32 %t4915, ptr %end_label
  store i1 1, ptr %needs_final_br
  %t4916 = load ptr, ptr %stmt
  %t4917 = getelementptr inbounds %ASTNode, ptr %t4916, i32 0, i32 6
  %t4918 = load ptr, ptr %t4917
  store ptr %t4918, ptr %arm_ptr
  br label %label_1581
label_1581:
  %t4919 = load ptr, ptr %arm_ptr
  %t4920 = getelementptr inbounds [1 x i8], ptr @.str.s662, i64 0, i64 0
  %t4921 = call i32 @str_equals(ptr %t4919, ptr %t4920)
  %t4922 = icmp eq i32 %t4921, 0
  br i1 %t4922, label %label_1582, label %label_1583
label_1582:
  %t4923 = load ptr, ptr %arm_ptr
  %t4924 = call ptr @ptr_to_node(ptr %t4923)
  store ptr %t4924, ptr %arm
  %t4925 = load ptr, ptr %arm
  %t4926 = getelementptr inbounds %ASTNode, ptr %t4925, i32 0, i32 1
  %t4927 = load ptr, ptr %t4926
  %t4928 = getelementptr inbounds [2 x i8], ptr @.str.s663, i64 0, i64 0
  %t4929 = call i32 @str_equals(ptr %t4927, ptr %t4928)
  %t4930 = icmp eq i32 %t4929, 1
  br i1 %t4930, label %label_1584, label %label_1585
label_1584:
  %t4931 = load ptr, ptr %arm
  %t4932 = getelementptr inbounds %ASTNode, ptr %t4931, i32 0, i32 6
  %t4933 = load ptr, ptr %t4932
  %t4934 = call ptr @ptr_to_node(ptr %t4933)
  call void @generate_block__Struct_ASTNode(ptr %t4934)
  %t4935 = call i32 @ir_has_returned()
  %t4936 = icmp eq i32 %t4935, 0
  br i1 %t4936, label %label_1587, label %label_1589
label_1587:
  %t4937 = load i32, ptr %end_label
  call void @ir_br_numbered(i32 %t4937)
  br label %label_1589
label_1589:
  call void @ir_clear_returned()
  store i1 0, ptr %needs_final_br
  br label %label_1586
label_1585:
  %t4938 = load ptr, ptr %arm
  %t4939 = getelementptr inbounds %ASTNode, ptr %t4938, i32 0, i32 5
  %t4940 = load ptr, ptr %t4939
  %t4941 = call ptr @ptr_to_node(ptr %t4940)
  %t4942 = call ptr @generate_expression__Struct_ASTNode(ptr %t4941)
  store ptr %t4942, ptr %pat_val
  %t4943 = load ptr, ptr %scrut_type
  %t4944 = load ptr, ptr %scrut_val
  %t4945 = load ptr, ptr %pat_val
  %t4946 = call i32 @ir_icmp_eq(ptr %t4943, ptr %t4944, ptr %t4945)
  store i32 %t4946, ptr %cmp
  %t4947 = call i32 @ir_get_label()
  store i32 %t4947, ptr %arm_label
  %t4948 = call i32 @ir_get_label()
  store i32 %t4948, ptr %next_label
  %t4949 = load i32, ptr %cmp
  %t4950 = call ptr @ir_get_temp_name(i32 %t4949)
  %t4951 = load i32, ptr %arm_label
  %t4952 = load i32, ptr %next_label
  call void @ir_cond_br_numbered(ptr %t4950, i32 %t4951, i32 %t4952)
  %t4953 = load i32, ptr %arm_label
  call void @ir_label_numbered(i32 %t4953)
  %t4954 = load ptr, ptr %arm
  %t4955 = getelementptr inbounds %ASTNode, ptr %t4954, i32 0, i32 6
  %t4956 = load ptr, ptr %t4955
  %t4957 = call ptr @ptr_to_node(ptr %t4956)
  call void @generate_block__Struct_ASTNode(ptr %t4957)
  %t4958 = call i32 @ir_has_returned()
  %t4959 = icmp eq i32 %t4958, 0
  br i1 %t4959, label %label_1590, label %label_1592
label_1590:
  %t4960 = load i32, ptr %end_label
  call void @ir_br_numbered(i32 %t4960)
  br label %label_1592
label_1592:
  call void @ir_clear_returned()
  %t4961 = load i32, ptr %next_label
  call void @ir_label_numbered(i32 %t4961)
  store i1 1, ptr %needs_final_br
  br label %label_1586
label_1586:
  %t4962 = load ptr, ptr %arm
  %t4963 = getelementptr inbounds %ASTNode, ptr %t4962, i32 0, i32 8
  %t4964 = load ptr, ptr %t4963
  store ptr %t4964, ptr %arm_ptr
  br label %label_1581
label_1583:
  %t4965 = load i1, ptr %needs_final_br
  br i1 %t4965, label %label_1593, label %label_1595
label_1593:
  %t4966 = load i32, ptr %end_label
  call void @ir_br_numbered(i32 %t4966)
  br label %label_1595
label_1595:
  %t4967 = load i32, ptr %end_label
  call void @ir_label_numbered(i32 %t4967)
  br label %label_1580
label_1580:
  ret void
}

define void @generate_block__Struct_ASTNode(ptr %p_block) {
  %block = alloca ptr
  %stmt_ptr = alloca ptr
  %stmt = alloca ptr
  store ptr %p_block, ptr %block
  %t4971 = load ptr, ptr %block
  %t4972 = getelementptr inbounds %ASTNode, ptr %t4971, i32 0, i32 5
  %t4973 = load ptr, ptr %t4972
  store ptr %t4973, ptr %stmt_ptr
  br label %label_1596
label_1596:
  %t4974 = load ptr, ptr %stmt_ptr
  %t4975 = getelementptr inbounds [1 x i8], ptr @.str.s664, i64 0, i64 0
  %t4976 = call i32 @str_equals(ptr %t4974, ptr %t4975)
  %t4977 = icmp eq i32 %t4976, 0
  br i1 %t4977, label %label_1597, label %label_1598
label_1597:
  %t4978 = load ptr, ptr %stmt_ptr
  %t4979 = call ptr @ptr_to_node(ptr %t4978)
  store ptr %t4979, ptr %stmt
  %t4980 = load ptr, ptr %stmt
  call void @generate_statement__Struct_ASTNode(ptr %t4980)
  %t4981 = load ptr, ptr %stmt
  %t4982 = getelementptr inbounds %ASTNode, ptr %t4981, i32 0, i32 8
  %t4983 = load ptr, ptr %t4982
  store ptr %t4983, ptr %stmt_ptr
  br label %label_1596
label_1598:
  ret void
}

define ptr @get_variable_decl_type__Struct_ASTNode(ptr %p_stmt) {
  %stmt = alloca ptr
  %var_type = alloca ptr
  %type_node = alloca ptr
  store ptr %p_stmt, ptr %stmt
  %t4987 = getelementptr inbounds [4 x i8], ptr @.str.s665, i64 0, i64 0
  store ptr %t4987, ptr %var_type
  %t4988 = load ptr, ptr %stmt
  %t4989 = getelementptr inbounds %ASTNode, ptr %t4988, i32 0, i32 5
  %t4990 = load ptr, ptr %t4989
  %t4991 = getelementptr inbounds [1 x i8], ptr @.str.s666, i64 0, i64 0
  %t4992 = call i32 @str_equals(ptr %t4990, ptr %t4991)
  %t4993 = icmp eq i32 %t4992, 0
  br i1 %t4993, label %label_1599, label %label_1600
label_1599:
  %t4994 = load ptr, ptr %stmt
  %t4995 = getelementptr inbounds %ASTNode, ptr %t4994, i32 0, i32 5
  %t4996 = load ptr, ptr %t4995
  %t4997 = call ptr @ptr_to_node(ptr %t4996)
  store ptr %t4997, ptr %type_node
  %t4998 = load ptr, ptr %type_node
  %t4999 = call ptr @map_type_node__Struct_ASTNode(ptr %t4998)
  store ptr %t4999, ptr %var_type
  br label %label_1601
label_1600:
  %t5000 = load ptr, ptr %stmt
  %t5001 = getelementptr inbounds %ASTNode, ptr %t5000, i32 0, i32 6
  %t5002 = load ptr, ptr %t5001
  %t5003 = getelementptr inbounds [1 x i8], ptr @.str.s667, i64 0, i64 0
  %t5004 = call i32 @str_equals(ptr %t5002, ptr %t5003)
  %t5005 = icmp eq i32 %t5004, 0
  br i1 %t5005, label %label_1602, label %label_1604
label_1602:
  %t5006 = load ptr, ptr %stmt
  %t5007 = getelementptr inbounds %ASTNode, ptr %t5006, i32 0, i32 6
  %t5008 = load ptr, ptr %t5007
  %t5009 = call ptr @ptr_to_node(ptr %t5008)
  %t5010 = call ptr @get_expr_type__Struct_ASTNode(ptr %t5009)
  store ptr %t5010, ptr %var_type
  br label %label_1604
label_1604:
  br label %label_1601
label_1601:
  %t5011 = load ptr, ptr %var_type
  ret ptr %t5011
}

define void @predeclare_locals_stmt__Struct_ASTNode(ptr %p_stmt) {
  %stmt = alloca ptr
  %var_type = alloca ptr
  %else_node = alloca ptr
  %arm_ptr = alloca ptr
  %arm = alloca ptr
  store ptr %p_stmt, ptr %stmt
  %t5017 = load ptr, ptr %stmt
  %t5018 = getelementptr inbounds %ASTNode, ptr %t5017, i32 0, i32 0
  %t5019 = load i32, ptr %t5018
  %t5020 = icmp eq i32 %t5019, 3
  br i1 %t5020, label %label_1605, label %label_1607
label_1605:
  %t5021 = load ptr, ptr %stmt
  %t5022 = call ptr @get_variable_decl_type__Struct_ASTNode(ptr %t5021)
  store ptr %t5022, ptr %var_type
  %t5023 = load ptr, ptr %stmt
  %t5024 = getelementptr inbounds %ASTNode, ptr %t5023, i32 0, i32 1
  %t5025 = load ptr, ptr %t5024
  %t5026 = load ptr, ptr %var_type
  call void @ir_set_var_type(ptr %t5025, ptr %t5026)
  %t5027 = load ptr, ptr %var_type
  %t5028 = call ptr @storage_type__String(ptr %t5027)
  %t5029 = load ptr, ptr %stmt
  %t5030 = getelementptr inbounds %ASTNode, ptr %t5029, i32 0, i32 1
  %t5031 = load ptr, ptr %t5030
  %t5032 = call i32 @ir_alloca(ptr %t5028, ptr %t5031)
  br label %label_1607
label_1607:
  %t5033 = load ptr, ptr %stmt
  %t5034 = getelementptr inbounds %ASTNode, ptr %t5033, i32 0, i32 0
  %t5035 = load i32, ptr %t5034
  %t5036 = icmp eq i32 %t5035, 10
  br i1 %t5036, label %label_1608, label %label_1610
label_1608:
  %t5037 = load ptr, ptr %stmt
  %t5038 = getelementptr inbounds %ASTNode, ptr %t5037, i32 0, i32 6
  %t5039 = load ptr, ptr %t5038
  %t5040 = getelementptr inbounds [1 x i8], ptr @.str.s668, i64 0, i64 0
  %t5041 = call i32 @str_equals(ptr %t5039, ptr %t5040)
  %t5042 = icmp eq i32 %t5041, 0
  br i1 %t5042, label %label_1611, label %label_1613
label_1611:
  %t5043 = load ptr, ptr %stmt
  %t5044 = getelementptr inbounds %ASTNode, ptr %t5043, i32 0, i32 6
  %t5045 = load ptr, ptr %t5044
  %t5046 = call ptr @ptr_to_node(ptr %t5045)
  call void @predeclare_locals_block__Struct_ASTNode(ptr %t5046)
  br label %label_1613
label_1613:
  %t5047 = load ptr, ptr %stmt
  %t5048 = getelementptr inbounds %ASTNode, ptr %t5047, i32 0, i32 7
  %t5049 = load ptr, ptr %t5048
  %t5050 = getelementptr inbounds [1 x i8], ptr @.str.s669, i64 0, i64 0
  %t5051 = call i32 @str_equals(ptr %t5049, ptr %t5050)
  %t5052 = icmp eq i32 %t5051, 0
  br i1 %t5052, label %label_1614, label %label_1616
label_1614:
  %t5053 = load ptr, ptr %stmt
  %t5054 = getelementptr inbounds %ASTNode, ptr %t5053, i32 0, i32 7
  %t5055 = load ptr, ptr %t5054
  %t5056 = call ptr @ptr_to_node(ptr %t5055)
  store ptr %t5056, ptr %else_node
  %t5057 = load ptr, ptr %else_node
  %t5058 = getelementptr inbounds %ASTNode, ptr %t5057, i32 0, i32 0
  %t5059 = load i32, ptr %t5058
  %t5060 = icmp eq i32 %t5059, 9
  br i1 %t5060, label %label_1617, label %label_1618
label_1617:
  %t5061 = load ptr, ptr %else_node
  call void @predeclare_locals_block__Struct_ASTNode(ptr %t5061)
  br label %label_1619
label_1618:
  %t5062 = load ptr, ptr %else_node
  call void @predeclare_locals_stmt__Struct_ASTNode(ptr %t5062)
  br label %label_1619
label_1619:
  br label %label_1616
label_1616:
  br label %label_1610
label_1610:
  %t5063 = load ptr, ptr %stmt
  %t5064 = getelementptr inbounds %ASTNode, ptr %t5063, i32 0, i32 0
  %t5065 = load i32, ptr %t5064
  %t5066 = icmp eq i32 %t5065, 13
  br i1 %t5066, label %label_1620, label %label_1622
label_1620:
  %t5067 = load ptr, ptr %stmt
  %t5068 = getelementptr inbounds %ASTNode, ptr %t5067, i32 0, i32 6
  %t5069 = load ptr, ptr %t5068
  %t5070 = getelementptr inbounds [1 x i8], ptr @.str.s670, i64 0, i64 0
  %t5071 = call i32 @str_equals(ptr %t5069, ptr %t5070)
  %t5072 = icmp eq i32 %t5071, 0
  br i1 %t5072, label %label_1623, label %label_1625
label_1623:
  %t5073 = load ptr, ptr %stmt
  %t5074 = getelementptr inbounds %ASTNode, ptr %t5073, i32 0, i32 6
  %t5075 = load ptr, ptr %t5074
  %t5076 = call ptr @ptr_to_node(ptr %t5075)
  call void @predeclare_locals_block__Struct_ASTNode(ptr %t5076)
  br label %label_1625
label_1625:
  br label %label_1622
label_1622:
  %t5077 = load ptr, ptr %stmt
  %t5078 = getelementptr inbounds %ASTNode, ptr %t5077, i32 0, i32 0
  %t5079 = load i32, ptr %t5078
  %t5080 = icmp eq i32 %t5079, 14
  br i1 %t5080, label %label_1626, label %label_1628
label_1626:
  %t5081 = load ptr, ptr %stmt
  %t5082 = getelementptr inbounds %ASTNode, ptr %t5081, i32 0, i32 5
  %t5083 = load ptr, ptr %t5082
  %t5084 = getelementptr inbounds [1 x i8], ptr @.str.s671, i64 0, i64 0
  %t5085 = call i32 @str_equals(ptr %t5083, ptr %t5084)
  %t5086 = icmp eq i32 %t5085, 0
  br i1 %t5086, label %label_1629, label %label_1631
label_1629:
  %t5087 = load ptr, ptr %stmt
  %t5088 = getelementptr inbounds %ASTNode, ptr %t5087, i32 0, i32 5
  %t5089 = load ptr, ptr %t5088
  %t5090 = call ptr @ptr_to_node(ptr %t5089)
  call void @predeclare_locals_block__Struct_ASTNode(ptr %t5090)
  br label %label_1631
label_1631:
  br label %label_1628
label_1628:
  %t5091 = load ptr, ptr %stmt
  %t5092 = getelementptr inbounds %ASTNode, ptr %t5091, i32 0, i32 0
  %t5093 = load i32, ptr %t5092
  %t5094 = icmp eq i32 %t5093, 12
  br i1 %t5094, label %label_1632, label %label_1634
label_1632:
  %t5095 = load ptr, ptr %stmt
  %t5096 = getelementptr inbounds %ASTNode, ptr %t5095, i32 0, i32 1
  %t5097 = load ptr, ptr %t5096
  %t5098 = getelementptr inbounds [4 x i8], ptr @.str.s672, i64 0, i64 0
  call void @ir_set_var_type(ptr %t5097, ptr %t5098)
  %t5099 = getelementptr inbounds [4 x i8], ptr @.str.s673, i64 0, i64 0
  %t5100 = load ptr, ptr %stmt
  %t5101 = getelementptr inbounds %ASTNode, ptr %t5100, i32 0, i32 1
  %t5102 = load ptr, ptr %t5101
  %t5103 = call i32 @ir_alloca(ptr %t5099, ptr %t5102)
  %t5104 = load ptr, ptr %stmt
  %t5105 = getelementptr inbounds %ASTNode, ptr %t5104, i32 0, i32 7
  %t5106 = load ptr, ptr %t5105
  %t5107 = getelementptr inbounds [1 x i8], ptr @.str.s674, i64 0, i64 0
  %t5108 = call i32 @str_equals(ptr %t5106, ptr %t5107)
  %t5109 = icmp eq i32 %t5108, 0
  br i1 %t5109, label %label_1635, label %label_1637
label_1635:
  %t5110 = load ptr, ptr %stmt
  %t5111 = getelementptr inbounds %ASTNode, ptr %t5110, i32 0, i32 7
  %t5112 = load ptr, ptr %t5111
  %t5113 = call ptr @ptr_to_node(ptr %t5112)
  call void @predeclare_locals_block__Struct_ASTNode(ptr %t5113)
  br label %label_1637
label_1637:
  br label %label_1634
label_1634:
  %t5114 = load ptr, ptr %stmt
  %t5115 = getelementptr inbounds %ASTNode, ptr %t5114, i32 0, i32 0
  %t5116 = load i32, ptr %t5115
  %t5117 = icmp eq i32 %t5116, 11
  br i1 %t5117, label %label_1638, label %label_1640
label_1638:
  %t5118 = load ptr, ptr %stmt
  %t5119 = getelementptr inbounds %ASTNode, ptr %t5118, i32 0, i32 6
  %t5120 = load ptr, ptr %t5119
  store ptr %t5120, ptr %arm_ptr
  br label %label_1641
label_1641:
  %t5121 = load ptr, ptr %arm_ptr
  %t5122 = getelementptr inbounds [1 x i8], ptr @.str.s675, i64 0, i64 0
  %t5123 = call i32 @str_equals(ptr %t5121, ptr %t5122)
  %t5124 = icmp eq i32 %t5123, 0
  br i1 %t5124, label %label_1642, label %label_1643
label_1642:
  %t5125 = load ptr, ptr %arm_ptr
  %t5126 = call ptr @ptr_to_node(ptr %t5125)
  store ptr %t5126, ptr %arm
  %t5127 = load ptr, ptr %arm
  %t5128 = getelementptr inbounds %ASTNode, ptr %t5127, i32 0, i32 6
  %t5129 = load ptr, ptr %t5128
  %t5130 = getelementptr inbounds [1 x i8], ptr @.str.s676, i64 0, i64 0
  %t5131 = call i32 @str_equals(ptr %t5129, ptr %t5130)
  %t5132 = icmp eq i32 %t5131, 0
  br i1 %t5132, label %label_1644, label %label_1646
label_1644:
  %t5133 = load ptr, ptr %arm
  %t5134 = getelementptr inbounds %ASTNode, ptr %t5133, i32 0, i32 6
  %t5135 = load ptr, ptr %t5134
  %t5136 = call ptr @ptr_to_node(ptr %t5135)
  call void @predeclare_locals_block__Struct_ASTNode(ptr %t5136)
  br label %label_1646
label_1646:
  %t5137 = load ptr, ptr %arm
  %t5138 = getelementptr inbounds %ASTNode, ptr %t5137, i32 0, i32 8
  %t5139 = load ptr, ptr %t5138
  store ptr %t5139, ptr %arm_ptr
  br label %label_1641
label_1643:
  br label %label_1640
label_1640:
  ret void
}

define void @predeclare_locals_block__Struct_ASTNode(ptr %p_block) {
  %block = alloca ptr
  %stmt_ptr = alloca ptr
  %stmt = alloca ptr
  store ptr %p_block, ptr %block
  %t5143 = load ptr, ptr %block
  %t5144 = getelementptr inbounds %ASTNode, ptr %t5143, i32 0, i32 5
  %t5145 = load ptr, ptr %t5144
  store ptr %t5145, ptr %stmt_ptr
  br label %label_1647
label_1647:
  %t5146 = load ptr, ptr %stmt_ptr
  %t5147 = getelementptr inbounds [1 x i8], ptr @.str.s677, i64 0, i64 0
  %t5148 = call i32 @str_equals(ptr %t5146, ptr %t5147)
  %t5149 = icmp eq i32 %t5148, 0
  br i1 %t5149, label %label_1648, label %label_1649
label_1648:
  %t5150 = load ptr, ptr %stmt_ptr
  %t5151 = call ptr @ptr_to_node(ptr %t5150)
  store ptr %t5151, ptr %stmt
  %t5152 = load ptr, ptr %stmt
  call void @predeclare_locals_stmt__Struct_ASTNode(ptr %t5152)
  %t5153 = load ptr, ptr %stmt
  %t5154 = getelementptr inbounds %ASTNode, ptr %t5153, i32 0, i32 8
  %t5155 = load ptr, ptr %t5154
  store ptr %t5155, ptr %stmt_ptr
  br label %label_1647
label_1649:
  ret void
}

define void @generate_function__Struct_ASTNode(ptr %p_func) {
  %func = alloca ptr
  %func_name = alloca ptr
  %emitted_name = alloca ptr
  %ret_type = alloca ptr
  %ret_node = alloca ptr
  %is_main = alloca i32
  %ret_sig_type = alloca ptr
  %param_ptr = alloca ptr
  %param_node = alloca ptr
  %p_type_node = alloca ptr
  %param_ptr2 = alloca ptr
  %p_type_str = alloca ptr
  %p_store_type = alloca ptr
  store ptr %p_func, ptr %func
  %t5169 = load ptr, ptr %func
  %t5170 = getelementptr inbounds %ASTNode, ptr %t5169, i32 0, i32 1
  %t5171 = load ptr, ptr %t5170
  store ptr %t5171, ptr %func_name
  %t5172 = load ptr, ptr %func
  %t5173 = call ptr @function_symbol_name__Struct_ASTNode(ptr %t5172)
  store ptr %t5173, ptr %emitted_name
  %t5174 = getelementptr inbounds [5 x i8], ptr @.str.s678, i64 0, i64 0
  store ptr %t5174, ptr %ret_type
  %t5175 = load ptr, ptr %func
  %t5176 = getelementptr inbounds %ASTNode, ptr %t5175, i32 0, i32 7
  %t5177 = load ptr, ptr %t5176
  %t5178 = getelementptr inbounds [1 x i8], ptr @.str.s679, i64 0, i64 0
  %t5179 = call i32 @str_equals(ptr %t5177, ptr %t5178)
  %t5180 = icmp eq i32 %t5179, 0
  br i1 %t5180, label %label_1650, label %label_1652
label_1650:
  %t5181 = load ptr, ptr %func
  %t5182 = getelementptr inbounds %ASTNode, ptr %t5181, i32 0, i32 7
  %t5183 = load ptr, ptr %t5182
  %t5184 = call ptr @ptr_to_node(ptr %t5183)
  store ptr %t5184, ptr %ret_node
  %t5185 = load ptr, ptr %ret_node
  %t5186 = call ptr @map_type_node__Struct_ASTNode(ptr %t5185)
  store ptr %t5186, ptr %ret_type
  br label %label_1652
label_1652:
  store i32 0, ptr %is_main
  %t5187 = load ptr, ptr %func_name
  %t5188 = getelementptr inbounds [5 x i8], ptr @.str.s680, i64 0, i64 0
  %t5189 = call i32 @str_equals(ptr %t5187, ptr %t5188)
  %t5190 = icmp eq i32 %t5189, 1
  br i1 %t5190, label %label_1653, label %label_1655
label_1653:
  %t5191 = getelementptr inbounds [4 x i8], ptr @.str.s681, i64 0, i64 0
  store ptr %t5191, ptr %ret_type
  store i32 1, ptr %is_main
  br label %label_1655
label_1655:
  %t5192 = load ptr, ptr %ret_type
  %t5193 = call ptr @storage_type__String(ptr %t5192)
  store ptr %t5193, ptr %ret_sig_type
  %t5194 = load ptr, ptr %emitted_name
  %t5195 = load ptr, ptr %ret_sig_type
  call void @ir_function_begin(ptr %t5194, ptr %t5195)
  %t5196 = load i32, ptr %is_main
  %t5197 = icmp eq i32 %t5196, 1
  br i1 %t5197, label %label_1656, label %label_1658
label_1656:
  %t5198 = getelementptr inbounds [4 x i8], ptr @.str.s682, i64 0, i64 0
  %t5199 = getelementptr inbounds [7 x i8], ptr @.str.s683, i64 0, i64 0
  call void @ir_function_param(ptr %t5198, ptr %t5199)
  %t5200 = getelementptr inbounds [4 x i8], ptr @.str.s684, i64 0, i64 0
  %t5201 = getelementptr inbounds [7 x i8], ptr @.str.s685, i64 0, i64 0
  call void @ir_function_param(ptr %t5200, ptr %t5201)
  br label %label_1658
label_1658:
  %t5202 = load ptr, ptr %func
  %t5203 = getelementptr inbounds %ASTNode, ptr %t5202, i32 0, i32 5
  %t5204 = load ptr, ptr %t5203
  store ptr %t5204, ptr %param_ptr
  br label %label_1659
label_1659:
  %t5205 = load ptr, ptr %param_ptr
  %t5206 = getelementptr inbounds [1 x i8], ptr @.str.s686, i64 0, i64 0
  %t5207 = call i32 @str_equals(ptr %t5205, ptr %t5206)
  %t5208 = icmp eq i32 %t5207, 0
  br i1 %t5208, label %label_1660, label %label_1661
label_1660:
  %t5209 = load ptr, ptr %param_ptr
  %t5210 = call ptr @ptr_to_node(ptr %t5209)
  store ptr %t5210, ptr %param_node
  %t5211 = load ptr, ptr %param_node
  %t5212 = getelementptr inbounds %ASTNode, ptr %t5211, i32 0, i32 5
  %t5213 = load ptr, ptr %t5212
  %t5214 = call ptr @ptr_to_node(ptr %t5213)
  store ptr %t5214, ptr %p_type_node
  %t5215 = load ptr, ptr %p_type_node
  %t5216 = call ptr @map_type_node__Struct_ASTNode(ptr %t5215)
  %t5217 = call ptr @storage_type__String(ptr %t5216)
  %t5218 = getelementptr inbounds [3 x i8], ptr @.str.s687, i64 0, i64 0
  %t5219 = load ptr, ptr %param_node
  %t5220 = getelementptr inbounds %ASTNode, ptr %t5219, i32 0, i32 1
  %t5221 = load ptr, ptr %t5220
  %t5222 = call ptr @str_concat(ptr %t5218, ptr %t5221)
  call void @ir_function_param(ptr %t5217, ptr %t5222)
  %t5223 = load ptr, ptr %param_node
  %t5224 = getelementptr inbounds %ASTNode, ptr %t5223, i32 0, i32 8
  %t5225 = load ptr, ptr %t5224
  store ptr %t5225, ptr %param_ptr
  br label %label_1659
label_1661:
  call void @ir_function_body_start()
  call void @ir_clear_local_var_types()
  call void @ir_clear_returned()
  %t5226 = load i32, ptr %is_main
  %t5227 = icmp eq i32 %t5226, 1
  br i1 %t5227, label %label_1662, label %label_1664
label_1662:
  %t5228 = getelementptr inbounds [4 x i8], ptr @.str.s688, i64 0, i64 0
  %t5229 = getelementptr inbounds [8 x i8], ptr @.str.s689, i64 0, i64 0
  %t5230 = getelementptr inbounds [13 x i8], ptr @.str.s690, i64 0, i64 0
  call void @ir_store_global(ptr %t5228, ptr %t5229, ptr %t5230)
  %t5231 = getelementptr inbounds [4 x i8], ptr @.str.s691, i64 0, i64 0
  %t5232 = getelementptr inbounds [8 x i8], ptr @.str.s692, i64 0, i64 0
  %t5233 = getelementptr inbounds [13 x i8], ptr @.str.s693, i64 0, i64 0
  call void @ir_store_global(ptr %t5231, ptr %t5232, ptr %t5233)
  br label %label_1664
label_1664:
  %t5234 = load ptr, ptr %func
  %t5235 = getelementptr inbounds %ASTNode, ptr %t5234, i32 0, i32 5
  %t5236 = load ptr, ptr %t5235
  store ptr %t5236, ptr %param_ptr2
  br label %label_1665
label_1665:
  %t5237 = load ptr, ptr %param_ptr2
  %t5238 = getelementptr inbounds [1 x i8], ptr @.str.s694, i64 0, i64 0
  %t5239 = call i32 @str_equals(ptr %t5237, ptr %t5238)
  %t5240 = icmp eq i32 %t5239, 0
  br i1 %t5240, label %label_1666, label %label_1667
label_1666:
  %t5241 = load ptr, ptr %param_ptr2
  %t5242 = call ptr @ptr_to_node(ptr %t5241)
  store ptr %t5242, ptr %param_node
  %t5243 = load ptr, ptr %param_node
  %t5244 = getelementptr inbounds %ASTNode, ptr %t5243, i32 0, i32 5
  %t5245 = load ptr, ptr %t5244
  %t5246 = call ptr @ptr_to_node(ptr %t5245)
  store ptr %t5246, ptr %p_type_node
  %t5247 = load ptr, ptr %p_type_node
  %t5248 = call ptr @map_type_node__Struct_ASTNode(ptr %t5247)
  store ptr %t5248, ptr %p_type_str
  %t5249 = load ptr, ptr %p_type_str
  %t5250 = call ptr @storage_type__String(ptr %t5249)
  store ptr %t5250, ptr %p_store_type
  %t5251 = load ptr, ptr %param_node
  %t5252 = getelementptr inbounds %ASTNode, ptr %t5251, i32 0, i32 1
  %t5253 = load ptr, ptr %t5252
  %t5254 = load ptr, ptr %p_type_str
  call void @ir_set_var_type(ptr %t5253, ptr %t5254)
  %t5255 = load ptr, ptr %p_store_type
  %t5256 = load ptr, ptr %param_node
  %t5257 = getelementptr inbounds %ASTNode, ptr %t5256, i32 0, i32 1
  %t5258 = load ptr, ptr %t5257
  %t5259 = call i32 @ir_alloca(ptr %t5255, ptr %t5258)
  %t5260 = load ptr, ptr %p_store_type
  %t5261 = getelementptr inbounds [4 x i8], ptr @.str.s695, i64 0, i64 0
  %t5262 = load ptr, ptr %param_node
  %t5263 = getelementptr inbounds %ASTNode, ptr %t5262, i32 0, i32 1
  %t5264 = load ptr, ptr %t5263
  %t5265 = call ptr @str_concat(ptr %t5261, ptr %t5264)
  %t5266 = load ptr, ptr %param_node
  %t5267 = getelementptr inbounds %ASTNode, ptr %t5266, i32 0, i32 1
  %t5268 = load ptr, ptr %t5267
  call void @ir_store(ptr %t5260, ptr %t5265, ptr %t5268)
  %t5269 = load ptr, ptr %param_node
  %t5270 = getelementptr inbounds %ASTNode, ptr %t5269, i32 0, i32 8
  %t5271 = load ptr, ptr %t5270
  store ptr %t5271, ptr %param_ptr2
  br label %label_1665
label_1667:
  %t5272 = load ptr, ptr %func
  %t5273 = getelementptr inbounds %ASTNode, ptr %t5272, i32 0, i32 6
  %t5274 = load ptr, ptr %t5273
  %t5275 = getelementptr inbounds [1 x i8], ptr @.str.s696, i64 0, i64 0
  %t5276 = call i32 @str_equals(ptr %t5274, ptr %t5275)
  %t5277 = icmp eq i32 %t5276, 0
  br i1 %t5277, label %label_1668, label %label_1670
label_1668:
  %t5278 = load ptr, ptr %func
  %t5279 = getelementptr inbounds %ASTNode, ptr %t5278, i32 0, i32 6
  %t5280 = load ptr, ptr %t5279
  %t5281 = call ptr @ptr_to_node(ptr %t5280)
  call void @predeclare_locals_block__Struct_ASTNode(ptr %t5281)
  br label %label_1670
label_1670:
  %t5282 = load ptr, ptr %func
  %t5283 = getelementptr inbounds %ASTNode, ptr %t5282, i32 0, i32 6
  %t5284 = load ptr, ptr %t5283
  %t5285 = getelementptr inbounds [1 x i8], ptr @.str.s697, i64 0, i64 0
  %t5286 = call i32 @str_equals(ptr %t5284, ptr %t5285)
  %t5287 = icmp eq i32 %t5286, 0
  br i1 %t5287, label %label_1671, label %label_1673
label_1671:
  %t5288 = load ptr, ptr %func
  %t5289 = getelementptr inbounds %ASTNode, ptr %t5288, i32 0, i32 6
  %t5290 = load ptr, ptr %t5289
  %t5291 = call ptr @ptr_to_node(ptr %t5290)
  call void @generate_block__Struct_ASTNode(ptr %t5291)
  br label %label_1673
label_1673:
  %t5292 = call i32 @ir_has_returned()
  %t5293 = icmp eq i32 %t5292, 0
  br i1 %t5293, label %label_1674, label %label_1676
label_1674:
  %t5294 = load ptr, ptr %ret_sig_type
  %t5295 = getelementptr inbounds [5 x i8], ptr @.str.s698, i64 0, i64 0
  %t5296 = call i32 @str_equals(ptr %t5294, ptr %t5295)
  %t5297 = icmp eq i32 %t5296, 1
  br i1 %t5297, label %label_1677, label %label_1678
label_1677:
  call void @ir_ret_void()
  br label %label_1679
label_1678:
  %t5298 = load i32, ptr %is_main
  %t5299 = icmp eq i32 %t5298, 1
  br i1 %t5299, label %label_1680, label %label_1681
label_1680:
  %t5300 = getelementptr inbounds [4 x i8], ptr @.str.s699, i64 0, i64 0
  %t5301 = getelementptr inbounds [2 x i8], ptr @.str.s700, i64 0, i64 0
  call void @ir_ret(ptr %t5300, ptr %t5301)
  br label %label_1682
label_1681:
  %t5302 = load ptr, ptr %ret_sig_type
  %t5303 = getelementptr inbounds [2 x i8], ptr @.str.s701, i64 0, i64 0
  call void @ir_ret(ptr %t5302, ptr %t5303)
  br label %label_1682
label_1682:
  br label %label_1679
label_1679:
  br label %label_1676
label_1676:
  call void @ir_function_end()
  ret void
}

define void @collect_strings_expr__Struct_ASTNode(ptr %p_expr) {
  %expr = alloca ptr
  %str_name = alloca ptr
  %arg_ptr = alloca ptr
  %arg_node = alloca ptr
  %elem_ptr = alloca ptr
  %elem_node = alloca ptr
  %field_ptr = alloca ptr
  %field = alloca ptr
  store ptr %p_expr, ptr %expr
  %t5312 = load ptr, ptr %expr
  %t5313 = getelementptr inbounds %ASTNode, ptr %t5312, i32 0, i32 0
  %t5314 = load i32, ptr %t5313
  %t5315 = icmp eq i32 %t5314, 22
  br i1 %t5315, label %label_1683, label %label_1685
label_1683:
  %t5316 = load ptr, ptr %expr
  %t5317 = getelementptr inbounds %ASTNode, ptr %t5316, i32 0, i32 3
  %t5318 = load i32, ptr %t5317
  %t5319 = icmp eq i32 %t5318, 0
  br i1 %t5319, label %label_1686, label %label_1688
label_1686:
  %t5320 = getelementptr inbounds [7 x i8], ptr @.str.s702, i64 0, i64 0
  %t5321 = load i32, ptr @ir_string_counter
  %t5322 = call ptr @int_to_str(i32 %t5321)
  %t5323 = call ptr @str_concat(ptr %t5320, ptr %t5322)
  store ptr %t5323, ptr %str_name
  %t5324 = load i32, ptr @ir_string_counter
  %t5325 = add i32 %t5324, 1
  store i32 %t5325, ptr @ir_string_counter
  %t5326 = load ptr, ptr %str_name
  %t5327 = load ptr, ptr %expr
  %t5328 = getelementptr inbounds %ASTNode, ptr %t5327, i32 0, i32 1
  %t5329 = load ptr, ptr %t5328
  call void @ir_global_string(ptr %t5326, ptr %t5329)
  %t5330 = load ptr, ptr %expr
  %t5331 = load ptr, ptr %str_name
  %t5332 = getelementptr inbounds %ASTNode, ptr %t5330, i32 0, i32 2
  store ptr %t5331, ptr %t5332
  br label %label_1688
label_1688:
  br label %label_1685
label_1685:
  %t5333 = load ptr, ptr %expr
  %t5334 = getelementptr inbounds %ASTNode, ptr %t5333, i32 0, i32 0
  %t5335 = load i32, ptr %t5334
  %t5336 = icmp eq i32 %t5335, 20
  br i1 %t5336, label %label_1689, label %label_1691
label_1689:
  %t5337 = load ptr, ptr %expr
  %t5338 = getelementptr inbounds %ASTNode, ptr %t5337, i32 0, i32 5
  %t5339 = load ptr, ptr %t5338
  %t5340 = getelementptr inbounds [1 x i8], ptr @.str.s703, i64 0, i64 0
  %t5341 = call i32 @str_equals(ptr %t5339, ptr %t5340)
  %t5342 = icmp eq i32 %t5341, 0
  br i1 %t5342, label %label_1692, label %label_1694
label_1692:
  %t5343 = load ptr, ptr %expr
  %t5344 = getelementptr inbounds %ASTNode, ptr %t5343, i32 0, i32 5
  %t5345 = load ptr, ptr %t5344
  %t5346 = call ptr @ptr_to_node(ptr %t5345)
  call void @collect_strings_expr__Struct_ASTNode(ptr %t5346)
  br label %label_1694
label_1694:
  %t5347 = load ptr, ptr %expr
  %t5348 = getelementptr inbounds %ASTNode, ptr %t5347, i32 0, i32 6
  %t5349 = load ptr, ptr %t5348
  %t5350 = getelementptr inbounds [1 x i8], ptr @.str.s704, i64 0, i64 0
  %t5351 = call i32 @str_equals(ptr %t5349, ptr %t5350)
  %t5352 = icmp eq i32 %t5351, 0
  br i1 %t5352, label %label_1695, label %label_1697
label_1695:
  %t5353 = load ptr, ptr %expr
  %t5354 = getelementptr inbounds %ASTNode, ptr %t5353, i32 0, i32 6
  %t5355 = load ptr, ptr %t5354
  %t5356 = call ptr @ptr_to_node(ptr %t5355)
  call void @collect_strings_expr__Struct_ASTNode(ptr %t5356)
  br label %label_1697
label_1697:
  br label %label_1691
label_1691:
  %t5357 = load ptr, ptr %expr
  %t5358 = getelementptr inbounds %ASTNode, ptr %t5357, i32 0, i32 0
  %t5359 = load i32, ptr %t5358
  %t5360 = icmp eq i32 %t5359, 24
  br i1 %t5360, label %label_1698, label %label_1700
label_1698:
  %t5361 = load ptr, ptr %expr
  %t5362 = getelementptr inbounds %ASTNode, ptr %t5361, i32 0, i32 6
  %t5363 = load ptr, ptr %t5362
  store ptr %t5363, ptr %arg_ptr
  br label %label_1701
label_1701:
  %t5364 = load ptr, ptr %arg_ptr
  %t5365 = getelementptr inbounds [1 x i8], ptr @.str.s705, i64 0, i64 0
  %t5366 = call i32 @str_equals(ptr %t5364, ptr %t5365)
  %t5367 = icmp eq i32 %t5366, 0
  br i1 %t5367, label %label_1702, label %label_1703
label_1702:
  %t5368 = load ptr, ptr %arg_ptr
  %t5369 = call ptr @ptr_to_node(ptr %t5368)
  store ptr %t5369, ptr %arg_node
  %t5370 = load ptr, ptr %arg_node
  call void @collect_strings_expr__Struct_ASTNode(ptr %t5370)
  %t5371 = load ptr, ptr %arg_node
  %t5372 = getelementptr inbounds %ASTNode, ptr %t5371, i32 0, i32 8
  %t5373 = load ptr, ptr %t5372
  store ptr %t5373, ptr %arg_ptr
  br label %label_1701
label_1703:
  br label %label_1700
label_1700:
  %t5374 = load ptr, ptr %expr
  %t5375 = getelementptr inbounds %ASTNode, ptr %t5374, i32 0, i32 0
  %t5376 = load i32, ptr %t5375
  %t5377 = icmp eq i32 %t5376, 27
  br i1 %t5377, label %label_1704, label %label_1706
label_1704:
  %t5378 = load ptr, ptr %expr
  %t5379 = getelementptr inbounds %ASTNode, ptr %t5378, i32 0, i32 5
  %t5380 = load ptr, ptr %t5379
  store ptr %t5380, ptr %elem_ptr
  br label %label_1707
label_1707:
  %t5381 = load ptr, ptr %elem_ptr
  %t5382 = getelementptr inbounds [1 x i8], ptr @.str.s706, i64 0, i64 0
  %t5383 = call i32 @str_equals(ptr %t5381, ptr %t5382)
  %t5384 = icmp eq i32 %t5383, 0
  br i1 %t5384, label %label_1708, label %label_1709
label_1708:
  %t5385 = load ptr, ptr %elem_ptr
  %t5386 = call ptr @ptr_to_node(ptr %t5385)
  store ptr %t5386, ptr %elem_node
  %t5387 = load ptr, ptr %elem_node
  call void @collect_strings_expr__Struct_ASTNode(ptr %t5387)
  %t5388 = load ptr, ptr %elem_node
  %t5389 = getelementptr inbounds %ASTNode, ptr %t5388, i32 0, i32 8
  %t5390 = load ptr, ptr %t5389
  store ptr %t5390, ptr %elem_ptr
  br label %label_1707
label_1709:
  br label %label_1706
label_1706:
  %t5391 = load ptr, ptr %expr
  %t5392 = getelementptr inbounds %ASTNode, ptr %t5391, i32 0, i32 0
  %t5393 = load i32, ptr %t5392
  %t5394 = icmp eq i32 %t5393, 26
  br i1 %t5394, label %label_1710, label %label_1712
label_1710:
  %t5395 = load ptr, ptr %expr
  %t5396 = getelementptr inbounds %ASTNode, ptr %t5395, i32 0, i32 5
  %t5397 = load ptr, ptr %t5396
  %t5398 = getelementptr inbounds [1 x i8], ptr @.str.s707, i64 0, i64 0
  %t5399 = call i32 @str_equals(ptr %t5397, ptr %t5398)
  %t5400 = icmp eq i32 %t5399, 0
  br i1 %t5400, label %label_1713, label %label_1715
label_1713:
  %t5401 = load ptr, ptr %expr
  %t5402 = getelementptr inbounds %ASTNode, ptr %t5401, i32 0, i32 5
  %t5403 = load ptr, ptr %t5402
  %t5404 = call ptr @ptr_to_node(ptr %t5403)
  call void @collect_strings_expr__Struct_ASTNode(ptr %t5404)
  br label %label_1715
label_1715:
  %t5405 = load ptr, ptr %expr
  %t5406 = getelementptr inbounds %ASTNode, ptr %t5405, i32 0, i32 6
  %t5407 = load ptr, ptr %t5406
  %t5408 = getelementptr inbounds [1 x i8], ptr @.str.s708, i64 0, i64 0
  %t5409 = call i32 @str_equals(ptr %t5407, ptr %t5408)
  %t5410 = icmp eq i32 %t5409, 0
  br i1 %t5410, label %label_1716, label %label_1718
label_1716:
  %t5411 = load ptr, ptr %expr
  %t5412 = getelementptr inbounds %ASTNode, ptr %t5411, i32 0, i32 6
  %t5413 = load ptr, ptr %t5412
  %t5414 = call ptr @ptr_to_node(ptr %t5413)
  call void @collect_strings_expr__Struct_ASTNode(ptr %t5414)
  br label %label_1718
label_1718:
  br label %label_1712
label_1712:
  %t5415 = load ptr, ptr %expr
  %t5416 = getelementptr inbounds %ASTNode, ptr %t5415, i32 0, i32 0
  %t5417 = load i32, ptr %t5416
  %t5418 = icmp eq i32 %t5417, 25
  br i1 %t5418, label %label_1719, label %label_1721
label_1719:
  %t5419 = load ptr, ptr %expr
  %t5420 = getelementptr inbounds %ASTNode, ptr %t5419, i32 0, i32 5
  %t5421 = load ptr, ptr %t5420
  %t5422 = getelementptr inbounds [1 x i8], ptr @.str.s709, i64 0, i64 0
  %t5423 = call i32 @str_equals(ptr %t5421, ptr %t5422)
  %t5424 = icmp eq i32 %t5423, 0
  br i1 %t5424, label %label_1722, label %label_1724
label_1722:
  %t5425 = load ptr, ptr %expr
  %t5426 = getelementptr inbounds %ASTNode, ptr %t5425, i32 0, i32 5
  %t5427 = load ptr, ptr %t5426
  %t5428 = call ptr @ptr_to_node(ptr %t5427)
  call void @collect_strings_expr__Struct_ASTNode(ptr %t5428)
  br label %label_1724
label_1724:
  br label %label_1721
label_1721:
  %t5429 = load ptr, ptr %expr
  %t5430 = getelementptr inbounds %ASTNode, ptr %t5429, i32 0, i32 0
  %t5431 = load i32, ptr %t5430
  %t5432 = icmp eq i32 %t5431, 28
  br i1 %t5432, label %label_1725, label %label_1727
label_1725:
  %t5433 = load ptr, ptr %expr
  %t5434 = getelementptr inbounds %ASTNode, ptr %t5433, i32 0, i32 5
  %t5435 = load ptr, ptr %t5434
  store ptr %t5435, ptr %field_ptr
  br label %label_1728
label_1728:
  %t5436 = load ptr, ptr %field_ptr
  %t5437 = getelementptr inbounds [1 x i8], ptr @.str.s710, i64 0, i64 0
  %t5438 = call i32 @str_equals(ptr %t5436, ptr %t5437)
  %t5439 = icmp eq i32 %t5438, 0
  br i1 %t5439, label %label_1729, label %label_1730
label_1729:
  %t5440 = load ptr, ptr %field_ptr
  %t5441 = call ptr @ptr_to_node(ptr %t5440)
  store ptr %t5441, ptr %field
  %t5442 = load ptr, ptr %field
  %t5443 = getelementptr inbounds %ASTNode, ptr %t5442, i32 0, i32 5
  %t5444 = load ptr, ptr %t5443
  %t5445 = getelementptr inbounds [1 x i8], ptr @.str.s711, i64 0, i64 0
  %t5446 = call i32 @str_equals(ptr %t5444, ptr %t5445)
  %t5447 = icmp eq i32 %t5446, 0
  br i1 %t5447, label %label_1731, label %label_1733
label_1731:
  %t5448 = load ptr, ptr %field
  %t5449 = getelementptr inbounds %ASTNode, ptr %t5448, i32 0, i32 5
  %t5450 = load ptr, ptr %t5449
  %t5451 = call ptr @ptr_to_node(ptr %t5450)
  call void @collect_strings_expr__Struct_ASTNode(ptr %t5451)
  br label %label_1733
label_1733:
  %t5452 = load ptr, ptr %field
  %t5453 = getelementptr inbounds %ASTNode, ptr %t5452, i32 0, i32 8
  %t5454 = load ptr, ptr %t5453
  store ptr %t5454, ptr %field_ptr
  br label %label_1728
label_1730:
  br label %label_1727
label_1727:
  ret void
}

define void @declare_extern_function__Struct_ASTNode(ptr %p_ext) {
  %ext = alloca ptr
  %ret_type = alloca ptr
  %param_ptr = alloca ptr
  %param_node = alloca ptr
  %p_type_node = alloca ptr
  store ptr %p_ext, ptr %ext
  %t5460 = load ptr, ptr %ext
  %t5461 = load ptr, ptr %ext
  %t5462 = getelementptr inbounds %ASTNode, ptr %t5461, i32 0, i32 6
  %t5463 = load ptr, ptr %t5462
  %t5464 = call ptr @get_declared_return_type__Struct_ASTNode_String(ptr %t5460, ptr %t5463)
  store ptr %t5464, ptr %ret_type
  %t5465 = load ptr, ptr %ext
  %t5466 = call ptr @function_symbol_name__Struct_ASTNode(ptr %t5465)
  %t5467 = call ptr @fn_key__String(ptr %t5466)
  %t5468 = load ptr, ptr %ret_type
  call void @ir_set_var_type(ptr %t5467, ptr %t5468)
  %t5469 = load ptr, ptr %ext
  %t5470 = call ptr @function_symbol_name__Struct_ASTNode(ptr %t5469)
  %t5471 = load ptr, ptr %ret_type
  %t5472 = call ptr @storage_type__String(ptr %t5471)
  call void @ir_declare_function_begin(ptr %t5470, ptr %t5472)
  %t5473 = load ptr, ptr %ext
  %t5474 = getelementptr inbounds %ASTNode, ptr %t5473, i32 0, i32 5
  %t5475 = load ptr, ptr %t5474
  store ptr %t5475, ptr %param_ptr
  br label %label_1734
label_1734:
  %t5476 = load ptr, ptr %param_ptr
  %t5477 = getelementptr inbounds [1 x i8], ptr @.str.s712, i64 0, i64 0
  %t5478 = call i32 @str_equals(ptr %t5476, ptr %t5477)
  %t5479 = icmp eq i32 %t5478, 0
  br i1 %t5479, label %label_1735, label %label_1736
label_1735:
  %t5480 = load ptr, ptr %param_ptr
  %t5481 = call ptr @ptr_to_node(ptr %t5480)
  store ptr %t5481, ptr %param_node
  %t5482 = load ptr, ptr %param_node
  %t5483 = getelementptr inbounds %ASTNode, ptr %t5482, i32 0, i32 5
  %t5484 = load ptr, ptr %t5483
  %t5485 = call ptr @ptr_to_node(ptr %t5484)
  store ptr %t5485, ptr %p_type_node
  %t5486 = load ptr, ptr %p_type_node
  %t5487 = call ptr @map_type_node__Struct_ASTNode(ptr %t5486)
  %t5488 = call ptr @storage_type__String(ptr %t5487)
  call void @ir_declare_function_param(ptr %t5488)
  %t5489 = load ptr, ptr %param_node
  %t5490 = getelementptr inbounds %ASTNode, ptr %t5489, i32 0, i32 8
  %t5491 = load ptr, ptr %t5490
  store ptr %t5491, ptr %param_ptr
  br label %label_1734
label_1736:
  call void @ir_declare_function_end()
  ret void
}

define i1 @module_has_function__Struct_ASTNode_String(ptr %p_module, ptr %p_name) {
  %module = alloca ptr
  %name = alloca ptr
  %stmt_ptr = alloca ptr
  %stmt = alloca ptr
  store ptr %p_module, ptr %module
  store ptr %p_name, ptr %name
  %t5496 = load ptr, ptr %module
  %t5497 = getelementptr inbounds %ASTNode, ptr %t5496, i32 0, i32 5
  %t5498 = load ptr, ptr %t5497
  store ptr %t5498, ptr %stmt_ptr
  br label %label_1737
label_1737:
  %t5499 = load ptr, ptr %stmt_ptr
  %t5500 = getelementptr inbounds [1 x i8], ptr @.str.s713, i64 0, i64 0
  %t5501 = call i32 @str_equals(ptr %t5499, ptr %t5500)
  %t5502 = icmp eq i32 %t5501, 0
  br i1 %t5502, label %label_1738, label %label_1739
label_1738:
  %t5503 = load ptr, ptr %stmt_ptr
  %t5504 = call ptr @ptr_to_node(ptr %t5503)
  store ptr %t5504, ptr %stmt
  %t5505 = load ptr, ptr %stmt
  %t5506 = getelementptr inbounds %ASTNode, ptr %t5505, i32 0, i32 0
  %t5507 = load i32, ptr %t5506
  %t5508 = icmp eq i32 %t5507, 4
  %t5509 = load ptr, ptr %stmt
  %t5510 = getelementptr inbounds %ASTNode, ptr %t5509, i32 0, i32 1
  %t5511 = load ptr, ptr %t5510
  %t5512 = load ptr, ptr %name
  %t5513 = call i32 @str_equals(ptr %t5511, ptr %t5512)
  %t5514 = icmp eq i32 %t5513, 1
  %t5515 = and i1 %t5508, %t5514
  br i1 %t5515, label %label_1740, label %label_1742
label_1740:
  ret i1 1
label_1742:
  %t5516 = load ptr, ptr %stmt
  %t5517 = getelementptr inbounds %ASTNode, ptr %t5516, i32 0, i32 8
  %t5518 = load ptr, ptr %t5517
  store ptr %t5518, ptr %stmt_ptr
  br label %label_1737
label_1739:
  ret i1 0
}

define void @register_enum_decl__Struct_ASTNode(ptr %p_enum_node) {
  %enum_node = alloca ptr
  %variant_ptr = alloca ptr
  %value = alloca i32
  %variant = alloca ptr
  store ptr %p_enum_node, ptr %enum_node
  %t5523 = load ptr, ptr %enum_node
  %t5524 = getelementptr inbounds %ASTNode, ptr %t5523, i32 0, i32 5
  %t5525 = load ptr, ptr %t5524
  store ptr %t5525, ptr %variant_ptr
  store i32 0, ptr %value
  br label %label_1743
label_1743:
  %t5526 = load ptr, ptr %variant_ptr
  %t5527 = getelementptr inbounds [1 x i8], ptr @.str.s714, i64 0, i64 0
  %t5528 = call i32 @str_equals(ptr %t5526, ptr %t5527)
  %t5529 = icmp eq i32 %t5528, 0
  br i1 %t5529, label %label_1744, label %label_1745
label_1744:
  %t5530 = load ptr, ptr %variant_ptr
  %t5531 = call ptr @ptr_to_node(ptr %t5530)
  store ptr %t5531, ptr %variant
  %t5532 = load ptr, ptr %enum_node
  %t5533 = getelementptr inbounds %ASTNode, ptr %t5532, i32 0, i32 1
  %t5534 = load ptr, ptr %t5533
  %t5535 = load ptr, ptr %variant
  %t5536 = getelementptr inbounds %ASTNode, ptr %t5535, i32 0, i32 1
  %t5537 = load ptr, ptr %t5536
  %t5538 = load i32, ptr %value
  call void @ir_register_enum_variant(ptr %t5534, ptr %t5537, i32 %t5538)
  %t5539 = load i32, ptr %value
  %t5540 = add i32 %t5539, 1
  store i32 %t5540, ptr %value
  %t5541 = load ptr, ptr %variant
  %t5542 = getelementptr inbounds %ASTNode, ptr %t5541, i32 0, i32 8
  %t5543 = load ptr, ptr %t5542
  store ptr %t5543, ptr %variant_ptr
  br label %label_1743
label_1745:
  ret void
}

define void @register_struct_name__Struct_ASTNode(ptr %p_struct_node) {
  %struct_node = alloca ptr
  store ptr %p_struct_node, ptr %struct_node
  %t5545 = load ptr, ptr %struct_node
  %t5546 = getelementptr inbounds %ASTNode, ptr %t5545, i32 0, i32 1
  %t5547 = load ptr, ptr %t5546
  call void @ir_register_struct(ptr %t5547)
  ret void
}

define void @generate_struct_decl__Struct_ASTNode(ptr %p_struct_node) {
  %struct_node = alloca ptr
  %first_field_ptr = alloca ptr
  %first_field = alloca ptr
  %field_ptr = alloca ptr
  %field_count = alloca i32
  %field = alloca ptr
  %type_node = alloca ptr
  %field_type = alloca ptr
  store ptr %p_struct_node, ptr %struct_node
  %t5556 = load ptr, ptr %struct_node
  %t5557 = getelementptr inbounds %ASTNode, ptr %t5556, i32 0, i32 5
  %t5558 = load ptr, ptr %t5557
  store ptr %t5558, ptr %first_field_ptr
  %t5559 = load ptr, ptr %first_field_ptr
  %t5560 = getelementptr inbounds [1 x i8], ptr @.str.s715, i64 0, i64 0
  %t5561 = call i32 @str_equals(ptr %t5559, ptr %t5560)
  %t5562 = icmp eq i32 %t5561, 0
  br i1 %t5562, label %label_1746, label %label_1748
label_1746:
  %t5563 = load ptr, ptr %first_field_ptr
  %t5564 = call ptr @ptr_to_node(ptr %t5563)
  store ptr %t5564, ptr %first_field
  %t5565 = load ptr, ptr %struct_node
  %t5566 = getelementptr inbounds %ASTNode, ptr %t5565, i32 0, i32 1
  %t5567 = load ptr, ptr %t5566
  %t5568 = load ptr, ptr %first_field
  %t5569 = getelementptr inbounds %ASTNode, ptr %t5568, i32 0, i32 1
  %t5570 = load ptr, ptr %t5569
  %t5571 = call i32 @ir_get_struct_field_index(ptr %t5567, ptr %t5570)
  %t5572 = icmp sge i32 %t5571, 0
  br i1 %t5572, label %label_1749, label %label_1751
label_1749:
  ret void
label_1751:
  br label %label_1748
label_1748:
  %t5573 = getelementptr inbounds [2 x i8], ptr @.str.s716, i64 0, i64 0
  call void @ir_append(ptr %t5573)
  %t5574 = load ptr, ptr %struct_node
  %t5575 = getelementptr inbounds %ASTNode, ptr %t5574, i32 0, i32 1
  %t5576 = load ptr, ptr %t5575
  call void @ir_append(ptr %t5576)
  %t5577 = getelementptr inbounds [11 x i8], ptr @.str.s717, i64 0, i64 0
  call void @ir_append(ptr %t5577)
  %t5578 = load ptr, ptr %struct_node
  %t5579 = getelementptr inbounds %ASTNode, ptr %t5578, i32 0, i32 5
  %t5580 = load ptr, ptr %t5579
  store ptr %t5580, ptr %field_ptr
  store i32 0, ptr %field_count
  br label %label_1752
label_1752:
  %t5581 = load ptr, ptr %field_ptr
  %t5582 = getelementptr inbounds [1 x i8], ptr @.str.s718, i64 0, i64 0
  %t5583 = call i32 @str_equals(ptr %t5581, ptr %t5582)
  %t5584 = icmp eq i32 %t5583, 0
  br i1 %t5584, label %label_1753, label %label_1754
label_1753:
  %t5585 = load ptr, ptr %field_ptr
  %t5586 = call ptr @ptr_to_node(ptr %t5585)
  store ptr %t5586, ptr %field
  %t5587 = load ptr, ptr %field
  %t5588 = getelementptr inbounds %ASTNode, ptr %t5587, i32 0, i32 5
  %t5589 = load ptr, ptr %t5588
  %t5590 = call ptr @ptr_to_node(ptr %t5589)
  store ptr %t5590, ptr %type_node
  %t5591 = load ptr, ptr %type_node
  %t5592 = call ptr @map_type_node__Struct_ASTNode(ptr %t5591)
  %t5593 = call ptr @storage_type__String(ptr %t5592)
  store ptr %t5593, ptr %field_type
  %t5594 = load ptr, ptr %struct_node
  %t5595 = getelementptr inbounds %ASTNode, ptr %t5594, i32 0, i32 1
  %t5596 = load ptr, ptr %t5595
  %t5597 = load ptr, ptr %field
  %t5598 = getelementptr inbounds %ASTNode, ptr %t5597, i32 0, i32 1
  %t5599 = load ptr, ptr %t5598
  %t5600 = load ptr, ptr %field_type
  call void @ir_register_struct_field(ptr %t5596, ptr %t5599, ptr %t5600)
  %t5601 = load i32, ptr %field_count
  %t5602 = icmp sgt i32 %t5601, 0
  br i1 %t5602, label %label_1755, label %label_1757
label_1755:
  %t5603 = getelementptr inbounds [3 x i8], ptr @.str.s719, i64 0, i64 0
  call void @ir_append(ptr %t5603)
  br label %label_1757
label_1757:
  %t5604 = load ptr, ptr %field_type
  call void @ir_append(ptr %t5604)
  %t5605 = load i32, ptr %field_count
  %t5606 = add i32 %t5605, 1
  store i32 %t5606, ptr %field_count
  %t5607 = load ptr, ptr %field
  %t5608 = getelementptr inbounds %ASTNode, ptr %t5607, i32 0, i32 8
  %t5609 = load ptr, ptr %t5608
  store ptr %t5609, ptr %field_ptr
  br label %label_1752
label_1754:
  %t5610 = getelementptr inbounds [3 x i8], ptr @.str.s720, i64 0, i64 0
  call void @ir_append_line(ptr %t5610)
  ret void
}

define void @collect_strings_stmt__Struct_ASTNode(ptr %p_stmt) {
  %stmt = alloca ptr
  %else_node = alloca ptr
  store ptr %p_stmt, ptr %stmt
  %t5613 = load ptr, ptr %stmt
  %t5614 = getelementptr inbounds %ASTNode, ptr %t5613, i32 0, i32 0
  %t5615 = load i32, ptr %t5614
  %t5616 = icmp eq i32 %t5615, 3
  br i1 %t5616, label %label_1758, label %label_1760
label_1758:
  %t5617 = load ptr, ptr %stmt
  %t5618 = getelementptr inbounds %ASTNode, ptr %t5617, i32 0, i32 6
  %t5619 = load ptr, ptr %t5618
  %t5620 = getelementptr inbounds [1 x i8], ptr @.str.s721, i64 0, i64 0
  %t5621 = call i32 @str_equals(ptr %t5619, ptr %t5620)
  %t5622 = icmp eq i32 %t5621, 0
  br i1 %t5622, label %label_1761, label %label_1763
label_1761:
  %t5623 = load ptr, ptr %stmt
  %t5624 = getelementptr inbounds %ASTNode, ptr %t5623, i32 0, i32 6
  %t5625 = load ptr, ptr %t5624
  %t5626 = call ptr @ptr_to_node(ptr %t5625)
  call void @collect_strings_expr__Struct_ASTNode(ptr %t5626)
  br label %label_1763
label_1763:
  br label %label_1760
label_1760:
  %t5627 = load ptr, ptr %stmt
  %t5628 = getelementptr inbounds %ASTNode, ptr %t5627, i32 0, i32 0
  %t5629 = load i32, ptr %t5628
  %t5630 = icmp eq i32 %t5629, 17
  br i1 %t5630, label %label_1764, label %label_1766
label_1764:
  %t5631 = load ptr, ptr %stmt
  %t5632 = getelementptr inbounds %ASTNode, ptr %t5631, i32 0, i32 5
  %t5633 = load ptr, ptr %t5632
  %t5634 = getelementptr inbounds [1 x i8], ptr @.str.s722, i64 0, i64 0
  %t5635 = call i32 @str_equals(ptr %t5633, ptr %t5634)
  %t5636 = icmp eq i32 %t5635, 0
  br i1 %t5636, label %label_1767, label %label_1769
label_1767:
  %t5637 = load ptr, ptr %stmt
  %t5638 = getelementptr inbounds %ASTNode, ptr %t5637, i32 0, i32 5
  %t5639 = load ptr, ptr %t5638
  %t5640 = call ptr @ptr_to_node(ptr %t5639)
  call void @collect_strings_expr__Struct_ASTNode(ptr %t5640)
  br label %label_1769
label_1769:
  br label %label_1766
label_1766:
  %t5641 = load ptr, ptr %stmt
  %t5642 = getelementptr inbounds %ASTNode, ptr %t5641, i32 0, i32 0
  %t5643 = load i32, ptr %t5642
  %t5644 = icmp eq i32 %t5643, 15
  br i1 %t5644, label %label_1770, label %label_1772
label_1770:
  %t5645 = load ptr, ptr %stmt
  %t5646 = getelementptr inbounds %ASTNode, ptr %t5645, i32 0, i32 5
  %t5647 = load ptr, ptr %t5646
  %t5648 = getelementptr inbounds [1 x i8], ptr @.str.s723, i64 0, i64 0
  %t5649 = call i32 @str_equals(ptr %t5647, ptr %t5648)
  %t5650 = icmp eq i32 %t5649, 0
  br i1 %t5650, label %label_1773, label %label_1775
label_1773:
  %t5651 = load ptr, ptr %stmt
  %t5652 = getelementptr inbounds %ASTNode, ptr %t5651, i32 0, i32 5
  %t5653 = load ptr, ptr %t5652
  %t5654 = call ptr @ptr_to_node(ptr %t5653)
  call void @collect_strings_expr__Struct_ASTNode(ptr %t5654)
  br label %label_1775
label_1775:
  br label %label_1772
label_1772:
  %t5655 = load ptr, ptr %stmt
  %t5656 = getelementptr inbounds %ASTNode, ptr %t5655, i32 0, i32 0
  %t5657 = load i32, ptr %t5656
  %t5658 = icmp eq i32 %t5657, 16
  br i1 %t5658, label %label_1776, label %label_1778
label_1776:
  %t5659 = load ptr, ptr %stmt
  %t5660 = getelementptr inbounds %ASTNode, ptr %t5659, i32 0, i32 6
  %t5661 = load ptr, ptr %t5660
  %t5662 = getelementptr inbounds [1 x i8], ptr @.str.s724, i64 0, i64 0
  %t5663 = call i32 @str_equals(ptr %t5661, ptr %t5662)
  %t5664 = icmp eq i32 %t5663, 0
  br i1 %t5664, label %label_1779, label %label_1781
label_1779:
  %t5665 = load ptr, ptr %stmt
  %t5666 = getelementptr inbounds %ASTNode, ptr %t5665, i32 0, i32 6
  %t5667 = load ptr, ptr %t5666
  %t5668 = call ptr @ptr_to_node(ptr %t5667)
  call void @collect_strings_expr__Struct_ASTNode(ptr %t5668)
  br label %label_1781
label_1781:
  br label %label_1778
label_1778:
  %t5669 = load ptr, ptr %stmt
  %t5670 = getelementptr inbounds %ASTNode, ptr %t5669, i32 0, i32 0
  %t5671 = load i32, ptr %t5670
  %t5672 = icmp eq i32 %t5671, 10
  br i1 %t5672, label %label_1782, label %label_1784
label_1782:
  %t5673 = load ptr, ptr %stmt
  %t5674 = getelementptr inbounds %ASTNode, ptr %t5673, i32 0, i32 5
  %t5675 = load ptr, ptr %t5674
  %t5676 = call ptr @ptr_to_node(ptr %t5675)
  call void @collect_strings_expr__Struct_ASTNode(ptr %t5676)
  %t5677 = load ptr, ptr %stmt
  %t5678 = getelementptr inbounds %ASTNode, ptr %t5677, i32 0, i32 6
  %t5679 = load ptr, ptr %t5678
  %t5680 = call ptr @ptr_to_node(ptr %t5679)
  call void @collect_strings_block__Struct_ASTNode(ptr %t5680)
  %t5681 = load ptr, ptr %stmt
  %t5682 = getelementptr inbounds %ASTNode, ptr %t5681, i32 0, i32 7
  %t5683 = load ptr, ptr %t5682
  %t5684 = getelementptr inbounds [1 x i8], ptr @.str.s725, i64 0, i64 0
  %t5685 = call i32 @str_equals(ptr %t5683, ptr %t5684)
  %t5686 = icmp eq i32 %t5685, 0
  br i1 %t5686, label %label_1785, label %label_1787
label_1785:
  %t5687 = load ptr, ptr %stmt
  %t5688 = getelementptr inbounds %ASTNode, ptr %t5687, i32 0, i32 7
  %t5689 = load ptr, ptr %t5688
  %t5690 = call ptr @ptr_to_node(ptr %t5689)
  store ptr %t5690, ptr %else_node
  %t5691 = load ptr, ptr %else_node
  %t5692 = getelementptr inbounds %ASTNode, ptr %t5691, i32 0, i32 0
  %t5693 = load i32, ptr %t5692
  %t5694 = icmp eq i32 %t5693, 10
  br i1 %t5694, label %label_1788, label %label_1789
label_1788:
  %t5695 = load ptr, ptr %else_node
  call void @collect_strings_stmt__Struct_ASTNode(ptr %t5695)
  br label %label_1790
label_1789:
  %t5696 = load ptr, ptr %else_node
  call void @collect_strings_block__Struct_ASTNode(ptr %t5696)
  br label %label_1790
label_1790:
  br label %label_1787
label_1787:
  br label %label_1784
label_1784:
  %t5697 = load ptr, ptr %stmt
  %t5698 = getelementptr inbounds %ASTNode, ptr %t5697, i32 0, i32 0
  %t5699 = load i32, ptr %t5698
  %t5700 = icmp eq i32 %t5699, 13
  br i1 %t5700, label %label_1791, label %label_1793
label_1791:
  %t5701 = load ptr, ptr %stmt
  %t5702 = getelementptr inbounds %ASTNode, ptr %t5701, i32 0, i32 5
  %t5703 = load ptr, ptr %t5702
  %t5704 = call ptr @ptr_to_node(ptr %t5703)
  call void @collect_strings_expr__Struct_ASTNode(ptr %t5704)
  %t5705 = load ptr, ptr %stmt
  %t5706 = getelementptr inbounds %ASTNode, ptr %t5705, i32 0, i32 6
  %t5707 = load ptr, ptr %t5706
  %t5708 = call ptr @ptr_to_node(ptr %t5707)
  call void @collect_strings_block__Struct_ASTNode(ptr %t5708)
  br label %label_1793
label_1793:
  ret void
}

define void @collect_strings_block__Struct_ASTNode(ptr %p_block) {
  %block = alloca ptr
  %s_ptr = alloca ptr
  %s = alloca ptr
  store ptr %p_block, ptr %block
  %t5712 = load ptr, ptr %block
  %t5713 = getelementptr inbounds %ASTNode, ptr %t5712, i32 0, i32 5
  %t5714 = load ptr, ptr %t5713
  store ptr %t5714, ptr %s_ptr
  br label %label_1794
label_1794:
  %t5715 = load ptr, ptr %s_ptr
  %t5716 = getelementptr inbounds [1 x i8], ptr @.str.s726, i64 0, i64 0
  %t5717 = call i32 @str_equals(ptr %t5715, ptr %t5716)
  %t5718 = icmp eq i32 %t5717, 0
  br i1 %t5718, label %label_1795, label %label_1796
label_1795:
  %t5719 = load ptr, ptr %s_ptr
  %t5720 = call ptr @ptr_to_node(ptr %t5719)
  store ptr %t5720, ptr %s
  %t5721 = load ptr, ptr %s
  call void @collect_strings_stmt__Struct_ASTNode(ptr %t5721)
  %t5722 = load ptr, ptr %s
  %t5723 = getelementptr inbounds %ASTNode, ptr %t5722, i32 0, i32 8
  %t5724 = load ptr, ptr %t5723
  store ptr %t5724, ptr %s_ptr
  br label %label_1794
label_1796:
  ret void
}

define void @collect_strings_function__Struct_ASTNode(ptr %p_func) {
  %func = alloca ptr
  store ptr %p_func, ptr %func
  %t5726 = load ptr, ptr %func
  %t5727 = getelementptr inbounds %ASTNode, ptr %t5726, i32 0, i32 6
  %t5728 = load ptr, ptr %t5727
  %t5729 = getelementptr inbounds [1 x i8], ptr @.str.s727, i64 0, i64 0
  %t5730 = call i32 @str_equals(ptr %t5728, ptr %t5729)
  %t5731 = icmp eq i32 %t5730, 0
  br i1 %t5731, label %label_1797, label %label_1799
label_1797:
  %t5732 = load ptr, ptr %func
  %t5733 = getelementptr inbounds %ASTNode, ptr %t5732, i32 0, i32 6
  %t5734 = load ptr, ptr %t5733
  %t5735 = call ptr @ptr_to_node(ptr %t5734)
  call void @collect_strings_block__Struct_ASTNode(ptr %t5735)
  br label %label_1799
label_1799:
  ret void
}

define void @generate_module__Struct_ASTNode(ptr %p_module) {
  %module = alloca ptr
  %type_stmt_ptr = alloca ptr
  %type_stmt = alloca ptr
  %struct_stmt_ptr = alloca ptr
  %struct_stmt = alloca ptr
  %stmt_ptr = alloca ptr
  %stmt = alloca ptr
  %init_val = alloca ptr
  %var_type = alloca ptr
  %type_node = alloca ptr
  %init_node = alloca ptr
  %ret_type = alloca ptr
  %stmt_ptr2 = alloca ptr
  %stmt2 = alloca ptr
  store ptr %p_module, ptr %module
  call void @ir_reset_globals()
  call void @ir_reset_types()
  call void @ir_clear_var_types()
  %t5750 = load i1, ptr @ir_target_wasm
  br i1 %t5750, label %label_1800, label %label_1801
label_1800:
  %t5751 = getelementptr inbounds [19 x i8], ptr @.str.s728, i64 0, i64 0
  call void @ir_module_start_wasm(ptr %t5751)
  br label %label_1802
label_1801:
  %t5752 = getelementptr inbounds [19 x i8], ptr @.str.s729, i64 0, i64 0
  call void @ir_module_start(ptr %t5752)
  br label %label_1802
label_1802:
  %t5753 = load ptr, ptr %module
  %t5754 = getelementptr inbounds %ASTNode, ptr %t5753, i32 0, i32 5
  %t5755 = load ptr, ptr %t5754
  store ptr %t5755, ptr %type_stmt_ptr
  br label %label_1803
label_1803:
  %t5756 = load ptr, ptr %type_stmt_ptr
  %t5757 = getelementptr inbounds [1 x i8], ptr @.str.s730, i64 0, i64 0
  %t5758 = call i32 @str_equals(ptr %t5756, ptr %t5757)
  %t5759 = icmp eq i32 %t5758, 0
  br i1 %t5759, label %label_1804, label %label_1805
label_1804:
  %t5760 = load ptr, ptr %type_stmt_ptr
  %t5761 = call ptr @ptr_to_node(ptr %t5760)
  store ptr %t5761, ptr %type_stmt
  %t5762 = load ptr, ptr %type_stmt
  %t5763 = getelementptr inbounds %ASTNode, ptr %t5762, i32 0, i32 0
  %t5764 = load i32, ptr %t5763
  %t5765 = icmp eq i32 %t5764, 6
  br i1 %t5765, label %label_1806, label %label_1808
label_1806:
  %t5766 = load ptr, ptr %type_stmt
  call void @register_enum_decl__Struct_ASTNode(ptr %t5766)
  br label %label_1808
label_1808:
  %t5767 = load ptr, ptr %type_stmt
  %t5768 = getelementptr inbounds %ASTNode, ptr %t5767, i32 0, i32 0
  %t5769 = load i32, ptr %t5768
  %t5770 = icmp eq i32 %t5769, 5
  br i1 %t5770, label %label_1809, label %label_1811
label_1809:
  %t5771 = load ptr, ptr %type_stmt
  call void @register_struct_name__Struct_ASTNode(ptr %t5771)
  br label %label_1811
label_1811:
  %t5772 = load ptr, ptr %type_stmt
  %t5773 = getelementptr inbounds %ASTNode, ptr %t5772, i32 0, i32 8
  %t5774 = load ptr, ptr %t5773
  store ptr %t5774, ptr %type_stmt_ptr
  br label %label_1803
label_1805:
  %t5775 = load ptr, ptr %module
  %t5776 = getelementptr inbounds %ASTNode, ptr %t5775, i32 0, i32 5
  %t5777 = load ptr, ptr %t5776
  store ptr %t5777, ptr %struct_stmt_ptr
  br label %label_1812
label_1812:
  %t5778 = load ptr, ptr %struct_stmt_ptr
  %t5779 = getelementptr inbounds [1 x i8], ptr @.str.s731, i64 0, i64 0
  %t5780 = call i32 @str_equals(ptr %t5778, ptr %t5779)
  %t5781 = icmp eq i32 %t5780, 0
  br i1 %t5781, label %label_1813, label %label_1814
label_1813:
  %t5782 = load ptr, ptr %struct_stmt_ptr
  %t5783 = call ptr @ptr_to_node(ptr %t5782)
  store ptr %t5783, ptr %struct_stmt
  %t5784 = load ptr, ptr %struct_stmt
  %t5785 = getelementptr inbounds %ASTNode, ptr %t5784, i32 0, i32 0
  %t5786 = load i32, ptr %t5785
  %t5787 = icmp eq i32 %t5786, 5
  br i1 %t5787, label %label_1815, label %label_1817
label_1815:
  %t5788 = load ptr, ptr %struct_stmt
  call void @generate_struct_decl__Struct_ASTNode(ptr %t5788)
  br label %label_1817
label_1817:
  %t5789 = load ptr, ptr %struct_stmt
  %t5790 = getelementptr inbounds %ASTNode, ptr %t5789, i32 0, i32 8
  %t5791 = load ptr, ptr %t5790
  store ptr %t5791, ptr %struct_stmt_ptr
  br label %label_1812
label_1814:
  call void @ir_blank_line()
  %t5792 = getelementptr inbounds [13 x i8], ptr @.str.s732, i64 0, i64 0
  %t5793 = getelementptr inbounds [4 x i8], ptr @.str.s733, i64 0, i64 0
  %t5794 = getelementptr inbounds [2 x i8], ptr @.str.s734, i64 0, i64 0
  call void @ir_global_var(ptr %t5792, ptr %t5793, ptr %t5794, i32 0)
  %t5795 = getelementptr inbounds [13 x i8], ptr @.str.s735, i64 0, i64 0
  %t5796 = getelementptr inbounds [4 x i8], ptr @.str.s736, i64 0, i64 0
  %t5797 = getelementptr inbounds [5 x i8], ptr @.str.s737, i64 0, i64 0
  call void @ir_global_var(ptr %t5795, ptr %t5796, ptr %t5797, i32 0)
  %t5798 = getelementptr inbounds [7 x i8], ptr @.str.s738, i64 0, i64 0
  %t5799 = getelementptr inbounds [4 x i8], ptr @.str.s739, i64 0, i64 0
  call void @ir_declare_function_begin(ptr %t5798, ptr %t5799)
  %t5800 = call ptr @ir_ptr_int_type__Void()
  call void @ir_declare_function_param(ptr %t5800)
  call void @ir_declare_function_end()
  %t5801 = getelementptr inbounds [5 x i8], ptr @.str.s740, i64 0, i64 0
  %t5802 = getelementptr inbounds [5 x i8], ptr @.str.s741, i64 0, i64 0
  call void @ir_declare_function_begin(ptr %t5801, ptr %t5802)
  %t5803 = getelementptr inbounds [4 x i8], ptr @.str.s742, i64 0, i64 0
  call void @ir_declare_function_param(ptr %t5803)
  call void @ir_declare_function_end()
  %t5804 = getelementptr inbounds [9 x i8], ptr @.str.s743, i64 0, i64 0
  %t5805 = getelementptr inbounds [4 x i8], ptr @.str.s744, i64 0, i64 0
  call void @ir_declare_function_begin(ptr %t5804, ptr %t5805)
  call void @ir_declare_function_end()
  %t5806 = getelementptr inbounds [10 x i8], ptr @.str.s745, i64 0, i64 0
  %t5807 = getelementptr inbounds [5 x i8], ptr @.str.s746, i64 0, i64 0
  call void @ir_declare_function_begin(ptr %t5806, ptr %t5807)
  %t5808 = getelementptr inbounds [4 x i8], ptr @.str.s747, i64 0, i64 0
  call void @ir_declare_function_param(ptr %t5808)
  %t5809 = getelementptr inbounds [4 x i8], ptr @.str.s748, i64 0, i64 0
  call void @ir_declare_function_param(ptr %t5809)
  call void @ir_declare_function_end()
  %t5810 = getelementptr inbounds [9 x i8], ptr @.str.s749, i64 0, i64 0
  %t5811 = getelementptr inbounds [4 x i8], ptr @.str.s750, i64 0, i64 0
  call void @ir_declare_function_begin(ptr %t5810, ptr %t5811)
  %t5812 = getelementptr inbounds [4 x i8], ptr @.str.s751, i64 0, i64 0
  call void @ir_declare_function_param(ptr %t5812)
  %t5813 = getelementptr inbounds [4 x i8], ptr @.str.s752, i64 0, i64 0
  call void @ir_declare_function_param(ptr %t5813)
  call void @ir_declare_function_end()
  %t5814 = getelementptr inbounds [9 x i8], ptr @.str.s753, i64 0, i64 0
  %t5815 = getelementptr inbounds [5 x i8], ptr @.str.s754, i64 0, i64 0
  call void @ir_declare_function_begin(ptr %t5814, ptr %t5815)
  %t5816 = getelementptr inbounds [4 x i8], ptr @.str.s755, i64 0, i64 0
  call void @ir_declare_function_param(ptr %t5816)
  %t5817 = getelementptr inbounds [4 x i8], ptr @.str.s756, i64 0, i64 0
  call void @ir_declare_function_param(ptr %t5817)
  %t5818 = getelementptr inbounds [4 x i8], ptr @.str.s757, i64 0, i64 0
  call void @ir_declare_function_param(ptr %t5818)
  call void @ir_declare_function_end()
  %t5819 = getelementptr inbounds [9 x i8], ptr @.str.s758, i64 0, i64 0
  %t5820 = getelementptr inbounds [4 x i8], ptr @.str.s759, i64 0, i64 0
  call void @ir_declare_function_begin(ptr %t5819, ptr %t5820)
  %t5821 = getelementptr inbounds [4 x i8], ptr @.str.s760, i64 0, i64 0
  call void @ir_declare_function_param(ptr %t5821)
  call void @ir_declare_function_end()
  %t5822 = getelementptr inbounds [8 x i8], ptr @.str.s761, i64 0, i64 0
  %t5823 = getelementptr inbounds [5 x i8], ptr @.str.s762, i64 0, i64 0
  call void @ir_declare_function_begin(ptr %t5822, ptr %t5823)
  %t5824 = getelementptr inbounds [4 x i8], ptr @.str.s763, i64 0, i64 0
  call void @ir_declare_function_param(ptr %t5824)
  call void @ir_declare_function_end()
  %t5825 = getelementptr inbounds [6 x i8], ptr @.str.s764, i64 0, i64 0
  %t5826 = getelementptr inbounds [5 x i8], ptr @.str.s765, i64 0, i64 0
  call void @ir_declare_function_begin(ptr %t5825, ptr %t5826)
  %t5827 = getelementptr inbounds [4 x i8], ptr @.str.s766, i64 0, i64 0
  call void @ir_declare_function_param(ptr %t5827)
  call void @ir_declare_function_end()
  %t5828 = getelementptr inbounds [12 x i8], ptr @.str.s767, i64 0, i64 0
  %t5829 = getelementptr inbounds [5 x i8], ptr @.str.s768, i64 0, i64 0
  call void @ir_declare_function_begin(ptr %t5828, ptr %t5829)
  %t5830 = getelementptr inbounds [4 x i8], ptr @.str.s769, i64 0, i64 0
  call void @ir_declare_function_param(ptr %t5830)
  call void @ir_declare_function_end()
  %t5831 = getelementptr inbounds [10 x i8], ptr @.str.s770, i64 0, i64 0
  %t5832 = getelementptr inbounds [5 x i8], ptr @.str.s771, i64 0, i64 0
  call void @ir_declare_function_begin(ptr %t5831, ptr %t5832)
  %t5833 = getelementptr inbounds [4 x i8], ptr @.str.s772, i64 0, i64 0
  call void @ir_declare_function_param(ptr %t5833)
  call void @ir_declare_function_end()
  %t5834 = getelementptr inbounds [14 x i8], ptr @.str.s773, i64 0, i64 0
  %t5835 = getelementptr inbounds [5 x i8], ptr @.str.s774, i64 0, i64 0
  call void @ir_declare_function_begin(ptr %t5834, ptr %t5835)
  %t5836 = getelementptr inbounds [7 x i8], ptr @.str.s775, i64 0, i64 0
  call void @ir_declare_function_param(ptr %t5836)
  call void @ir_declare_function_end()
  %t5837 = getelementptr inbounds [12 x i8], ptr @.str.s776, i64 0, i64 0
  %t5838 = getelementptr inbounds [5 x i8], ptr @.str.s777, i64 0, i64 0
  call void @ir_declare_function_begin(ptr %t5837, ptr %t5838)
  %t5839 = getelementptr inbounds [7 x i8], ptr @.str.s778, i64 0, i64 0
  call void @ir_declare_function_param(ptr %t5839)
  call void @ir_declare_function_end()
  %t5840 = getelementptr inbounds [13 x i8], ptr @.str.s779, i64 0, i64 0
  %t5841 = getelementptr inbounds [5 x i8], ptr @.str.s780, i64 0, i64 0
  call void @ir_declare_function_begin(ptr %t5840, ptr %t5841)
  %t5842 = getelementptr inbounds [4 x i8], ptr @.str.s781, i64 0, i64 0
  call void @ir_declare_function_param(ptr %t5842)
  call void @ir_declare_function_end()
  %t5843 = getelementptr inbounds [11 x i8], ptr @.str.s782, i64 0, i64 0
  %t5844 = getelementptr inbounds [5 x i8], ptr @.str.s783, i64 0, i64 0
  call void @ir_declare_function_begin(ptr %t5843, ptr %t5844)
  %t5845 = getelementptr inbounds [4 x i8], ptr @.str.s784, i64 0, i64 0
  call void @ir_declare_function_param(ptr %t5845)
  call void @ir_declare_function_end()
  %t5846 = getelementptr inbounds [13 x i8], ptr @.str.s785, i64 0, i64 0
  %t5847 = getelementptr inbounds [5 x i8], ptr @.str.s786, i64 0, i64 0
  call void @ir_declare_function_begin(ptr %t5846, ptr %t5847)
  %t5848 = getelementptr inbounds [3 x i8], ptr @.str.s787, i64 0, i64 0
  call void @ir_declare_function_param(ptr %t5848)
  call void @ir_declare_function_end()
  %t5849 = getelementptr inbounds [11 x i8], ptr @.str.s788, i64 0, i64 0
  %t5850 = getelementptr inbounds [5 x i8], ptr @.str.s789, i64 0, i64 0
  call void @ir_declare_function_begin(ptr %t5849, ptr %t5850)
  %t5851 = getelementptr inbounds [3 x i8], ptr @.str.s790, i64 0, i64 0
  call void @ir_declare_function_param(ptr %t5851)
  call void @ir_declare_function_end()
  call void @ir_blank_line()
  %t5852 = load ptr, ptr %module
  %t5853 = getelementptr inbounds %ASTNode, ptr %t5852, i32 0, i32 5
  %t5854 = load ptr, ptr %t5853
  store ptr %t5854, ptr %stmt_ptr
  br label %label_1818
label_1818:
  %t5855 = load ptr, ptr %stmt_ptr
  %t5856 = getelementptr inbounds [1 x i8], ptr @.str.s791, i64 0, i64 0
  %t5857 = call i32 @str_equals(ptr %t5855, ptr %t5856)
  %t5858 = icmp eq i32 %t5857, 0
  br i1 %t5858, label %label_1819, label %label_1820
label_1819:
  %t5859 = load ptr, ptr %stmt_ptr
  %t5860 = call ptr @ptr_to_node(ptr %t5859)
  store ptr %t5860, ptr %stmt
  %t5861 = load ptr, ptr %stmt
  %t5862 = getelementptr inbounds %ASTNode, ptr %t5861, i32 0, i32 0
  %t5863 = load i32, ptr %t5862
  %t5864 = icmp eq i32 %t5863, 2
  br i1 %t5864, label %label_1821, label %label_1823
label_1821:
  %t5865 = load ptr, ptr %module
  %t5866 = load ptr, ptr %stmt
  %t5867 = getelementptr inbounds %ASTNode, ptr %t5866, i32 0, i32 1
  %t5868 = load ptr, ptr %t5867
  %t5869 = call i1 @module_has_function__Struct_ASTNode_String(ptr %t5865, ptr %t5868)
  %t5870 = icmp eq i1 %t5869, 0
  br i1 %t5870, label %label_1824, label %label_1826
label_1824:
  %t5871 = load ptr, ptr %stmt
  call void @declare_extern_function__Struct_ASTNode(ptr %t5871)
  br label %label_1826
label_1826:
  br label %label_1823
label_1823:
  %t5872 = load ptr, ptr %stmt
  %t5873 = getelementptr inbounds %ASTNode, ptr %t5872, i32 0, i32 0
  %t5874 = load i32, ptr %t5873
  %t5875 = icmp eq i32 %t5874, 3
  br i1 %t5875, label %label_1827, label %label_1829
label_1827:
  %t5876 = getelementptr inbounds [2 x i8], ptr @.str.s792, i64 0, i64 0
  store ptr %t5876, ptr %init_val
  %t5877 = getelementptr inbounds [4 x i8], ptr @.str.s793, i64 0, i64 0
  store ptr %t5877, ptr %var_type
  %t5878 = load ptr, ptr %stmt
  %t5879 = getelementptr inbounds %ASTNode, ptr %t5878, i32 0, i32 5
  %t5880 = load ptr, ptr %t5879
  %t5881 = getelementptr inbounds [1 x i8], ptr @.str.s794, i64 0, i64 0
  %t5882 = call i32 @str_equals(ptr %t5880, ptr %t5881)
  %t5883 = icmp eq i32 %t5882, 0
  br i1 %t5883, label %label_1830, label %label_1832
label_1830:
  %t5884 = load ptr, ptr %stmt
  %t5885 = getelementptr inbounds %ASTNode, ptr %t5884, i32 0, i32 5
  %t5886 = load ptr, ptr %t5885
  %t5887 = call ptr @ptr_to_node(ptr %t5886)
  store ptr %t5887, ptr %type_node
  %t5888 = load ptr, ptr %type_node
  %t5889 = call ptr @map_type_node__Struct_ASTNode(ptr %t5888)
  store ptr %t5889, ptr %var_type
  br label %label_1832
label_1832:
  %t5890 = load ptr, ptr %stmt
  %t5891 = getelementptr inbounds %ASTNode, ptr %t5890, i32 0, i32 6
  %t5892 = load ptr, ptr %t5891
  %t5893 = getelementptr inbounds [1 x i8], ptr @.str.s795, i64 0, i64 0
  %t5894 = call i32 @str_equals(ptr %t5892, ptr %t5893)
  %t5895 = icmp eq i32 %t5894, 0
  br i1 %t5895, label %label_1833, label %label_1835
label_1833:
  %t5896 = load ptr, ptr %stmt
  %t5897 = getelementptr inbounds %ASTNode, ptr %t5896, i32 0, i32 6
  %t5898 = load ptr, ptr %t5897
  %t5899 = call ptr @ptr_to_node(ptr %t5898)
  store ptr %t5899, ptr %init_node
  %t5900 = load ptr, ptr %init_node
  %t5901 = call ptr @get_expr_type__Struct_ASTNode(ptr %t5900)
  store ptr %t5901, ptr %var_type
  %t5902 = load ptr, ptr %init_node
  %t5903 = getelementptr inbounds %ASTNode, ptr %t5902, i32 0, i32 0
  %t5904 = load i32, ptr %t5903
  %t5905 = icmp eq i32 %t5904, 22
  br i1 %t5905, label %label_1836, label %label_1838
label_1836:
  %t5906 = load ptr, ptr %init_node
  %t5907 = getelementptr inbounds %ASTNode, ptr %t5906, i32 0, i32 1
  %t5908 = load ptr, ptr %t5907
  store ptr %t5908, ptr %init_val
  br label %label_1838
label_1838:
  br label %label_1835
label_1835:
  %t5909 = load ptr, ptr %stmt
  %t5910 = getelementptr inbounds %ASTNode, ptr %t5909, i32 0, i32 1
  %t5911 = load ptr, ptr %t5910
  %t5912 = load ptr, ptr %var_type
  %t5913 = call ptr @storage_type__String(ptr %t5912)
  %t5914 = load ptr, ptr %init_val
  call void @ir_global_var(ptr %t5911, ptr %t5913, ptr %t5914, i32 0)
  %t5915 = load ptr, ptr %stmt
  %t5916 = getelementptr inbounds %ASTNode, ptr %t5915, i32 0, i32 1
  %t5917 = load ptr, ptr %t5916
  call void @ir_register_global_name(ptr %t5917)
  %t5918 = load ptr, ptr %stmt
  %t5919 = getelementptr inbounds %ASTNode, ptr %t5918, i32 0, i32 1
  %t5920 = load ptr, ptr %t5919
  %t5921 = load ptr, ptr %var_type
  call void @ir_set_var_type(ptr %t5920, ptr %t5921)
  br label %label_1829
label_1829:
  %t5922 = load ptr, ptr %stmt
  %t5923 = getelementptr inbounds %ASTNode, ptr %t5922, i32 0, i32 0
  %t5924 = load i32, ptr %t5923
  %t5925 = icmp eq i32 %t5924, 4
  br i1 %t5925, label %label_1839, label %label_1841
label_1839:
  %t5926 = load ptr, ptr %stmt
  %t5927 = load ptr, ptr %stmt
  %t5928 = getelementptr inbounds %ASTNode, ptr %t5927, i32 0, i32 7
  %t5929 = load ptr, ptr %t5928
  %t5930 = call ptr @get_declared_return_type__Struct_ASTNode_String(ptr %t5926, ptr %t5929)
  store ptr %t5930, ptr %ret_type
  %t5931 = load ptr, ptr %stmt
  %t5932 = getelementptr inbounds %ASTNode, ptr %t5931, i32 0, i32 1
  %t5933 = load ptr, ptr %t5932
  %t5934 = getelementptr inbounds [5 x i8], ptr @.str.s796, i64 0, i64 0
  %t5935 = call i32 @str_equals(ptr %t5933, ptr %t5934)
  %t5936 = icmp eq i32 %t5935, 1
  br i1 %t5936, label %label_1842, label %label_1844
label_1842:
  %t5937 = getelementptr inbounds [4 x i8], ptr @.str.s797, i64 0, i64 0
  store ptr %t5937, ptr %ret_type
  br label %label_1844
label_1844:
  %t5938 = load ptr, ptr %stmt
  %t5939 = call ptr @function_symbol_name__Struct_ASTNode(ptr %t5938)
  %t5940 = call ptr @fn_key__String(ptr %t5939)
  %t5941 = load ptr, ptr %ret_type
  call void @ir_set_var_type(ptr %t5940, ptr %t5941)
  %t5942 = load ptr, ptr %stmt
  call void @collect_strings_function__Struct_ASTNode(ptr %t5942)
  br label %label_1841
label_1841:
  %t5943 = load ptr, ptr %stmt
  %t5944 = getelementptr inbounds %ASTNode, ptr %t5943, i32 0, i32 8
  %t5945 = load ptr, ptr %t5944
  store ptr %t5945, ptr %stmt_ptr
  br label %label_1818
label_1820:
  call void @ir_blank_line()
  %t5946 = load ptr, ptr %module
  %t5947 = getelementptr inbounds %ASTNode, ptr %t5946, i32 0, i32 5
  %t5948 = load ptr, ptr %t5947
  store ptr %t5948, ptr %stmt_ptr2
  br label %label_1845
label_1845:
  %t5949 = load ptr, ptr %stmt_ptr2
  %t5950 = getelementptr inbounds [1 x i8], ptr @.str.s798, i64 0, i64 0
  %t5951 = call i32 @str_equals(ptr %t5949, ptr %t5950)
  %t5952 = icmp eq i32 %t5951, 0
  br i1 %t5952, label %label_1846, label %label_1847
label_1846:
  %t5953 = load ptr, ptr %stmt_ptr2
  %t5954 = call ptr @ptr_to_node(ptr %t5953)
  store ptr %t5954, ptr %stmt2
  %t5955 = load ptr, ptr %stmt2
  %t5956 = getelementptr inbounds %ASTNode, ptr %t5955, i32 0, i32 0
  %t5957 = load i32, ptr %t5956
  %t5958 = icmp eq i32 %t5957, 4
  br i1 %t5958, label %label_1848, label %label_1850
label_1848:
  %t5959 = load ptr, ptr %stmt2
  call void @generate_function__Struct_ASTNode(ptr %t5959)
  br label %label_1850
label_1850:
  %t5960 = load ptr, ptr %stmt2
  %t5961 = getelementptr inbounds %ASTNode, ptr %t5960, i32 0, i32 8
  %t5962 = load ptr, ptr %t5961
  store ptr %t5962, ptr %stmt_ptr2
  br label %label_1845
label_1847:
  call void @ir_module_end()
  ret void
}

define ptr @sema_fn_key__String(ptr %p_name) {
  %name = alloca ptr
  store ptr %p_name, ptr %name
  %t5964 = getelementptr inbounds [5 x i8], ptr @.str.s799, i64 0, i64 0
  %t5965 = load ptr, ptr %name
  %t5966 = call ptr @str_concat(ptr %t5964, ptr %t5965)
  ret ptr %t5966
}

define ptr @sema_mangle_type__Struct_TypeInfo(ptr %p_t) {
  %t = alloca ptr
  store ptr %p_t, ptr %t
  %t5968 = load ptr, ptr %t
  %t5969 = getelementptr inbounds %TypeInfo, ptr %t5968, i32 0, i32 0
  %t5970 = load i32, ptr %t5969
  %t5971 = icmp eq i32 %t5970, 1
  br i1 %t5971, label %label_1851, label %label_1853
label_1851:
  %t5972 = getelementptr inbounds [5 x i8], ptr @.str.s800, i64 0, i64 0
  ret ptr %t5972
label_1853:
  %t5973 = load ptr, ptr %t
  %t5974 = getelementptr inbounds %TypeInfo, ptr %t5973, i32 0, i32 0
  %t5975 = load i32, ptr %t5974
  %t5976 = icmp eq i32 %t5975, 2
  br i1 %t5976, label %label_1854, label %label_1856
label_1854:
  %t5977 = load ptr, ptr %t
  %t5978 = getelementptr inbounds %TypeInfo, ptr %t5977, i32 0, i32 1
  %t5979 = load ptr, ptr %t5978
  ret ptr %t5979
label_1856:
  %t5980 = load ptr, ptr %t
  %t5981 = getelementptr inbounds %TypeInfo, ptr %t5980, i32 0, i32 0
  %t5982 = load i32, ptr %t5981
  %t5983 = icmp eq i32 %t5982, 3
  br i1 %t5983, label %label_1857, label %label_1859
label_1857:
  %t5984 = getelementptr inbounds [6 x i8], ptr @.str.s801, i64 0, i64 0
  ret ptr %t5984
label_1859:
  %t5985 = load ptr, ptr %t
  %t5986 = getelementptr inbounds %TypeInfo, ptr %t5985, i32 0, i32 0
  %t5987 = load i32, ptr %t5986
  %t5988 = icmp eq i32 %t5987, 4
  br i1 %t5988, label %label_1860, label %label_1862
label_1860:
  %t5989 = getelementptr inbounds [5 x i8], ptr @.str.s802, i64 0, i64 0
  ret ptr %t5989
label_1862:
  %t5990 = load ptr, ptr %t
  %t5991 = getelementptr inbounds %TypeInfo, ptr %t5990, i32 0, i32 0
  %t5992 = load i32, ptr %t5991
  %t5993 = icmp eq i32 %t5992, 5
  br i1 %t5993, label %label_1863, label %label_1865
label_1863:
  %t5994 = getelementptr inbounds [5 x i8], ptr @.str.s803, i64 0, i64 0
  ret ptr %t5994
label_1865:
  %t5995 = load ptr, ptr %t
  %t5996 = getelementptr inbounds %TypeInfo, ptr %t5995, i32 0, i32 0
  %t5997 = load i32, ptr %t5996
  %t5998 = icmp eq i32 %t5997, 6
  br i1 %t5998, label %label_1866, label %label_1868
label_1866:
  %t5999 = getelementptr inbounds [7 x i8], ptr @.str.s804, i64 0, i64 0
  ret ptr %t5999
label_1868:
  %t6000 = load ptr, ptr %t
  %t6001 = getelementptr inbounds %TypeInfo, ptr %t6000, i32 0, i32 0
  %t6002 = load i32, ptr %t6001
  %t6003 = icmp eq i32 %t6002, 7
  br i1 %t6003, label %label_1869, label %label_1871
label_1869:
  %t6004 = getelementptr inbounds [4 x i8], ptr @.str.s805, i64 0, i64 0
  ret ptr %t6004
label_1871:
  %t6005 = load ptr, ptr %t
  %t6006 = getelementptr inbounds %TypeInfo, ptr %t6005, i32 0, i32 0
  %t6007 = load i32, ptr %t6006
  %t6008 = icmp eq i32 %t6007, 8
  br i1 %t6008, label %label_1872, label %label_1874
label_1872:
  %t6009 = getelementptr inbounds [8 x i8], ptr @.str.s806, i64 0, i64 0
  %t6010 = load ptr, ptr %t
  %t6011 = getelementptr inbounds %TypeInfo, ptr %t6010, i32 0, i32 1
  %t6012 = load ptr, ptr %t6011
  %t6013 = call ptr @str_concat(ptr %t6009, ptr %t6012)
  ret ptr %t6013
label_1874:
  %t6014 = load ptr, ptr %t
  %t6015 = getelementptr inbounds %TypeInfo, ptr %t6014, i32 0, i32 0
  %t6016 = load i32, ptr %t6015
  %t6017 = icmp eq i32 %t6016, 9
  br i1 %t6017, label %label_1875, label %label_1877
label_1875:
  %t6018 = getelementptr inbounds [6 x i8], ptr @.str.s807, i64 0, i64 0
  %t6019 = load ptr, ptr %t
  %t6020 = getelementptr inbounds %TypeInfo, ptr %t6019, i32 0, i32 1
  %t6021 = load ptr, ptr %t6020
  %t6022 = call ptr @str_concat(ptr %t6018, ptr %t6021)
  ret ptr %t6022
label_1877:
  %t6023 = load ptr, ptr %t
  %t6024 = getelementptr inbounds %TypeInfo, ptr %t6023, i32 0, i32 0
  %t6025 = load i32, ptr %t6024
  %t6026 = icmp eq i32 %t6025, 10
  br i1 %t6026, label %label_1878, label %label_1880
label_1878:
  %t6027 = load ptr, ptr %t
  %t6028 = getelementptr inbounds %TypeInfo, ptr %t6027, i32 0, i32 3
  %t6029 = load ptr, ptr %t6028
  %t6030 = getelementptr inbounds [1 x i8], ptr @.str.s808, i64 0, i64 0
  %t6031 = call i32 @str_equals(ptr %t6029, ptr %t6030)
  %t6032 = icmp eq i32 %t6031, 0
  br i1 %t6032, label %label_1881, label %label_1883
label_1881:
  %t6033 = getelementptr inbounds [7 x i8], ptr @.str.s809, i64 0, i64 0
  %t6034 = load ptr, ptr %t
  %t6035 = getelementptr inbounds %TypeInfo, ptr %t6034, i32 0, i32 3
  %t6036 = load ptr, ptr %t6035
  %t6037 = call ptr @ptr_to_type(ptr %t6036)
  %t6038 = call ptr @sema_mangle_type__Struct_TypeInfo(ptr %t6037)
  %t6039 = call ptr @str_concat(ptr %t6033, ptr %t6038)
  ret ptr %t6039
label_1883:
  %t6040 = getelementptr inbounds [14 x i8], ptr @.str.s810, i64 0, i64 0
  ret ptr %t6040
label_1880:
  %t6041 = load ptr, ptr %t
  %t6042 = getelementptr inbounds %TypeInfo, ptr %t6041, i32 0, i32 0
  %t6043 = load i32, ptr %t6042
  %t6044 = icmp eq i32 %t6043, 11
  br i1 %t6044, label %label_1884, label %label_1886
label_1884:
  %t6045 = load ptr, ptr %t
  %t6046 = getelementptr inbounds %TypeInfo, ptr %t6045, i32 0, i32 3
  %t6047 = load ptr, ptr %t6046
  %t6048 = getelementptr inbounds [1 x i8], ptr @.str.s811, i64 0, i64 0
  %t6049 = call i32 @str_equals(ptr %t6047, ptr %t6048)
  %t6050 = icmp eq i32 %t6049, 0
  br i1 %t6050, label %label_1887, label %label_1889
label_1887:
  %t6051 = getelementptr inbounds [6 x i8], ptr @.str.s812, i64 0, i64 0
  %t6052 = load ptr, ptr %t
  %t6053 = getelementptr inbounds %TypeInfo, ptr %t6052, i32 0, i32 3
  %t6054 = load ptr, ptr %t6053
  %t6055 = call ptr @ptr_to_type(ptr %t6054)
  %t6056 = call ptr @sema_mangle_type__Struct_TypeInfo(ptr %t6055)
  %t6057 = call ptr @str_concat(ptr %t6051, ptr %t6056)
  ret ptr %t6057
label_1889:
  %t6058 = getelementptr inbounds [13 x i8], ptr @.str.s813, i64 0, i64 0
  ret ptr %t6058
label_1886:
  %t6059 = getelementptr inbounds [8 x i8], ptr @.str.s814, i64 0, i64 0
  ret ptr %t6059
}

define ptr @sema_param_signature__Struct_ASTNode_String(ptr %p_module, ptr %p_param_ptr) {
  %module = alloca ptr
  %param_ptr = alloca ptr
  %sig = alloca ptr
  %curr = alloca ptr
  %param = alloca ptr
  %param_t = alloca ptr
  store ptr %p_module, ptr %module
  store ptr %p_param_ptr, ptr %param_ptr
  %t6066 = getelementptr inbounds [1 x i8], ptr @.str.s815, i64 0, i64 0
  store ptr %t6066, ptr %sig
  %t6067 = load ptr, ptr %param_ptr
  store ptr %t6067, ptr %curr
  br label %label_1890
label_1890:
  %t6068 = load ptr, ptr %curr
  %t6069 = getelementptr inbounds [1 x i8], ptr @.str.s816, i64 0, i64 0
  %t6070 = call i32 @str_equals(ptr %t6068, ptr %t6069)
  %t6071 = icmp eq i32 %t6070, 0
  br i1 %t6071, label %label_1891, label %label_1892
label_1891:
  %t6072 = load ptr, ptr %curr
  %t6073 = call ptr @ptr_to_node(ptr %t6072)
  store ptr %t6073, ptr %param
  %t6074 = load ptr, ptr %module
  %t6075 = load ptr, ptr %param
  %t6076 = getelementptr inbounds %ASTNode, ptr %t6075, i32 0, i32 5
  %t6077 = load ptr, ptr %t6076
  %t6078 = call ptr @ptr_to_node(ptr %t6077)
  %t6079 = call ptr @sema_annotation_type__Struct_ASTNode_Struct_ASTNode(ptr %t6074, ptr %t6078)
  store ptr %t6079, ptr %param_t
  %t6080 = load ptr, ptr %sig
  %t6081 = getelementptr inbounds [1 x i8], ptr @.str.s817, i64 0, i64 0
  %t6082 = call i32 @str_equals(ptr %t6080, ptr %t6081)
  %t6083 = icmp eq i32 %t6082, 1
  br i1 %t6083, label %label_1893, label %label_1894
label_1893:
  %t6084 = load ptr, ptr %param_t
  %t6085 = call ptr @sema_mangle_type__Struct_TypeInfo(ptr %t6084)
  store ptr %t6085, ptr %sig
  br label %label_1895
label_1894:
  %t6086 = load ptr, ptr %sig
  %t6087 = getelementptr inbounds [2 x i8], ptr @.str.s818, i64 0, i64 0
  %t6088 = call ptr @str_concat(ptr %t6086, ptr %t6087)
  %t6089 = load ptr, ptr %param_t
  %t6090 = call ptr @sema_mangle_type__Struct_TypeInfo(ptr %t6089)
  %t6091 = call ptr @str_concat(ptr %t6088, ptr %t6090)
  store ptr %t6091, ptr %sig
  br label %label_1895
label_1895:
  %t6092 = load ptr, ptr %param
  %t6093 = getelementptr inbounds %ASTNode, ptr %t6092, i32 0, i32 8
  %t6094 = load ptr, ptr %t6093
  store ptr %t6094, ptr %curr
  br label %label_1890
label_1892:
  %t6095 = load ptr, ptr %sig
  %t6096 = getelementptr inbounds [1 x i8], ptr @.str.s819, i64 0, i64 0
  %t6097 = call i32 @str_equals(ptr %t6095, ptr %t6096)
  %t6098 = icmp eq i32 %t6097, 1
  br i1 %t6098, label %label_1896, label %label_1898
label_1896:
  %t6099 = getelementptr inbounds [5 x i8], ptr @.str.s820, i64 0, i64 0
  ret ptr %t6099
label_1898:
  %t6100 = load ptr, ptr %sig
  ret ptr %t6100
}

define ptr @sema_function_symbol__Struct_ASTNode_Struct_ASTNode(ptr %p_module, ptr %p_fn_node) {
  %module = alloca ptr
  %fn_node = alloca ptr
  store ptr %p_module, ptr %module
  store ptr %p_fn_node, ptr %fn_node
  %t6103 = load ptr, ptr %fn_node
  %t6104 = getelementptr inbounds %ASTNode, ptr %t6103, i32 0, i32 0
  %t6105 = load i32, ptr %t6104
  %t6106 = icmp eq i32 %t6105, 2
  br i1 %t6106, label %label_1899, label %label_1901
label_1899:
  %t6107 = load ptr, ptr %fn_node
  %t6108 = getelementptr inbounds %ASTNode, ptr %t6107, i32 0, i32 1
  %t6109 = load ptr, ptr %t6108
  ret ptr %t6109
label_1901:
  %t6110 = load ptr, ptr %fn_node
  %t6111 = getelementptr inbounds %ASTNode, ptr %t6110, i32 0, i32 1
  %t6112 = load ptr, ptr %t6111
  %t6113 = getelementptr inbounds [5 x i8], ptr @.str.s821, i64 0, i64 0
  %t6114 = call i32 @str_equals(ptr %t6112, ptr %t6113)
  %t6115 = icmp eq i32 %t6114, 1
  br i1 %t6115, label %label_1902, label %label_1904
label_1902:
  %t6116 = getelementptr inbounds [5 x i8], ptr @.str.s822, i64 0, i64 0
  ret ptr %t6116
label_1904:
  %t6117 = load ptr, ptr %fn_node
  %t6118 = getelementptr inbounds %ASTNode, ptr %t6117, i32 0, i32 1
  %t6119 = load ptr, ptr %t6118
  %t6120 = getelementptr inbounds [3 x i8], ptr @.str.s823, i64 0, i64 0
  %t6121 = call ptr @str_concat(ptr %t6119, ptr %t6120)
  %t6122 = load ptr, ptr %module
  %t6123 = load ptr, ptr %fn_node
  %t6124 = getelementptr inbounds %ASTNode, ptr %t6123, i32 0, i32 5
  %t6125 = load ptr, ptr %t6124
  %t6126 = call ptr @sema_param_signature__Struct_ASTNode_String(ptr %t6122, ptr %t6125)
  %t6127 = call ptr @str_concat(ptr %t6121, ptr %t6126)
  ret ptr %t6127
}

define i32 @sema_function_symbol_count__Struct_ASTNode_String(ptr %p_module, ptr %p_symbol) {
  %module = alloca ptr
  %symbol = alloca ptr
  %count = alloca i32
  %stmt_ptr = alloca ptr
  %stmt = alloca ptr
  store ptr %p_module, ptr %module
  store ptr %p_symbol, ptr %symbol
  store i32 0, ptr %count
  %t6133 = load ptr, ptr %module
  %t6134 = getelementptr inbounds %ASTNode, ptr %t6133, i32 0, i32 5
  %t6135 = load ptr, ptr %t6134
  store ptr %t6135, ptr %stmt_ptr
  br label %label_1905
label_1905:
  %t6136 = load ptr, ptr %stmt_ptr
  %t6137 = getelementptr inbounds [1 x i8], ptr @.str.s824, i64 0, i64 0
  %t6138 = call i32 @str_equals(ptr %t6136, ptr %t6137)
  %t6139 = icmp eq i32 %t6138, 0
  br i1 %t6139, label %label_1906, label %label_1907
label_1906:
  %t6140 = load ptr, ptr %stmt_ptr
  %t6141 = call ptr @ptr_to_node(ptr %t6140)
  store ptr %t6141, ptr %stmt
  %t6142 = load ptr, ptr %stmt
  %t6143 = getelementptr inbounds %ASTNode, ptr %t6142, i32 0, i32 0
  %t6144 = load i32, ptr %t6143
  %t6145 = icmp eq i32 %t6144, 4
  %t6146 = load ptr, ptr %stmt
  %t6147 = getelementptr inbounds %ASTNode, ptr %t6146, i32 0, i32 0
  %t6148 = load i32, ptr %t6147
  %t6149 = icmp eq i32 %t6148, 2
  %t6150 = or i1 %t6145, %t6149
  br i1 %t6150, label %label_1908, label %label_1910
label_1908:
  %t6151 = load ptr, ptr %module
  %t6152 = load ptr, ptr %stmt
  %t6153 = call ptr @sema_function_symbol__Struct_ASTNode_Struct_ASTNode(ptr %t6151, ptr %t6152)
  %t6154 = load ptr, ptr %symbol
  %t6155 = call i32 @str_equals(ptr %t6153, ptr %t6154)
  %t6156 = icmp eq i32 %t6155, 1
  br i1 %t6156, label %label_1911, label %label_1913
label_1911:
  %t6157 = load i32, ptr %count
  %t6158 = add i32 %t6157, 1
  store i32 %t6158, ptr %count
  br label %label_1913
label_1913:
  br label %label_1910
label_1910:
  %t6159 = load ptr, ptr %stmt
  %t6160 = getelementptr inbounds %ASTNode, ptr %t6159, i32 0, i32 8
  %t6161 = load ptr, ptr %t6160
  store ptr %t6161, ptr %stmt_ptr
  br label %label_1905
label_1907:
  %t6162 = load i32, ptr %count
  ret i32 %t6162
}

define ptr @sema_overload_key__Struct_ASTNode_Struct_ASTNode(ptr %p_module, ptr %p_fn_node) {
  %module = alloca ptr
  %fn_node = alloca ptr
  store ptr %p_module, ptr %module
  store ptr %p_fn_node, ptr %fn_node
  %t6165 = load ptr, ptr %module
  %t6166 = load ptr, ptr %fn_node
  %t6167 = call ptr @sema_function_symbol__Struct_ASTNode_Struct_ASTNode(ptr %t6165, ptr %t6166)
  %t6168 = call ptr @sema_fn_key__String(ptr %t6167)
  ret ptr %t6168
}

define void @sema_error__String(ptr %p_message) {
  %message = alloca ptr
  store ptr %p_message, ptr %message
  %t6170 = getelementptr inbounds [13 x i8], ptr @.str.s825, i64 0, i64 0
  call void @print(ptr %t6170)
  %t6171 = load ptr, ptr %message
  call void @println(ptr %t6171)
  call void @exit(i32 1)
  ret void
}

define void @sema_type_error__String_Struct_TypeInfo_Struct_TypeInfo(ptr %p_context, ptr %p_expected, ptr %p_actual) {
  %context = alloca ptr
  %expected = alloca ptr
  %actual = alloca ptr
  store ptr %p_context, ptr %context
  store ptr %p_expected, ptr %expected
  store ptr %p_actual, ptr %actual
  %t6175 = getelementptr inbounds [13 x i8], ptr @.str.s826, i64 0, i64 0
  call void @print(ptr %t6175)
  %t6176 = load ptr, ptr %context
  call void @print(ptr %t6176)
  %t6177 = getelementptr inbounds [12 x i8], ptr @.str.s827, i64 0, i64 0
  call void @print(ptr %t6177)
  %t6178 = load ptr, ptr %expected
  %t6179 = call ptr @type_display__Struct_TypeInfo(ptr %t6178)
  call void @print(ptr %t6179)
  %t6180 = getelementptr inbounds [7 x i8], ptr @.str.s828, i64 0, i64 0
  call void @print(ptr %t6180)
  %t6181 = load ptr, ptr %actual
  %t6182 = call ptr @type_display__Struct_TypeInfo(ptr %t6181)
  call void @println(ptr %t6182)
  call void @exit(i32 1)
  ret void
}

define i1 @sema_has_struct__Struct_ASTNode_String(ptr %p_module, ptr %p_name) {
  %module = alloca ptr
  %name = alloca ptr
  %stmt_ptr = alloca ptr
  %stmt = alloca ptr
  store ptr %p_module, ptr %module
  store ptr %p_name, ptr %name
  %t6187 = load ptr, ptr %module
  %t6188 = getelementptr inbounds %ASTNode, ptr %t6187, i32 0, i32 5
  %t6189 = load ptr, ptr %t6188
  store ptr %t6189, ptr %stmt_ptr
  br label %label_1914
label_1914:
  %t6190 = load ptr, ptr %stmt_ptr
  %t6191 = getelementptr inbounds [1 x i8], ptr @.str.s829, i64 0, i64 0
  %t6192 = call i32 @str_equals(ptr %t6190, ptr %t6191)
  %t6193 = icmp eq i32 %t6192, 0
  br i1 %t6193, label %label_1915, label %label_1916
label_1915:
  %t6194 = load ptr, ptr %stmt_ptr
  %t6195 = call ptr @ptr_to_node(ptr %t6194)
  store ptr %t6195, ptr %stmt
  %t6196 = load ptr, ptr %stmt
  %t6197 = getelementptr inbounds %ASTNode, ptr %t6196, i32 0, i32 0
  %t6198 = load i32, ptr %t6197
  %t6199 = icmp eq i32 %t6198, 5
  %t6200 = load ptr, ptr %stmt
  %t6201 = getelementptr inbounds %ASTNode, ptr %t6200, i32 0, i32 1
  %t6202 = load ptr, ptr %t6201
  %t6203 = load ptr, ptr %name
  %t6204 = call i32 @str_equals(ptr %t6202, ptr %t6203)
  %t6205 = icmp eq i32 %t6204, 1
  %t6206 = and i1 %t6199, %t6205
  br i1 %t6206, label %label_1917, label %label_1919
label_1917:
  ret i1 1
label_1919:
  %t6207 = load ptr, ptr %stmt
  %t6208 = getelementptr inbounds %ASTNode, ptr %t6207, i32 0, i32 8
  %t6209 = load ptr, ptr %t6208
  store ptr %t6209, ptr %stmt_ptr
  br label %label_1914
label_1916:
  ret i1 0
}

define i1 @sema_has_enum__Struct_ASTNode_String(ptr %p_module, ptr %p_name) {
  %module = alloca ptr
  %name = alloca ptr
  %stmt_ptr = alloca ptr
  %stmt = alloca ptr
  store ptr %p_module, ptr %module
  store ptr %p_name, ptr %name
  %t6214 = load ptr, ptr %module
  %t6215 = getelementptr inbounds %ASTNode, ptr %t6214, i32 0, i32 5
  %t6216 = load ptr, ptr %t6215
  store ptr %t6216, ptr %stmt_ptr
  br label %label_1920
label_1920:
  %t6217 = load ptr, ptr %stmt_ptr
  %t6218 = getelementptr inbounds [1 x i8], ptr @.str.s830, i64 0, i64 0
  %t6219 = call i32 @str_equals(ptr %t6217, ptr %t6218)
  %t6220 = icmp eq i32 %t6219, 0
  br i1 %t6220, label %label_1921, label %label_1922
label_1921:
  %t6221 = load ptr, ptr %stmt_ptr
  %t6222 = call ptr @ptr_to_node(ptr %t6221)
  store ptr %t6222, ptr %stmt
  %t6223 = load ptr, ptr %stmt
  %t6224 = getelementptr inbounds %ASTNode, ptr %t6223, i32 0, i32 0
  %t6225 = load i32, ptr %t6224
  %t6226 = icmp eq i32 %t6225, 6
  %t6227 = load ptr, ptr %stmt
  %t6228 = getelementptr inbounds %ASTNode, ptr %t6227, i32 0, i32 1
  %t6229 = load ptr, ptr %t6228
  %t6230 = load ptr, ptr %name
  %t6231 = call i32 @str_equals(ptr %t6229, ptr %t6230)
  %t6232 = icmp eq i32 %t6231, 1
  %t6233 = and i1 %t6226, %t6232
  br i1 %t6233, label %label_1923, label %label_1925
label_1923:
  ret i1 1
label_1925:
  %t6234 = load ptr, ptr %stmt
  %t6235 = getelementptr inbounds %ASTNode, ptr %t6234, i32 0, i32 8
  %t6236 = load ptr, ptr %t6235
  store ptr %t6236, ptr %stmt_ptr
  br label %label_1920
label_1922:
  ret i1 0
}

define ptr @sema_annotation_type__Struct_ASTNode_Struct_ASTNode(ptr %p_module, ptr %p_tn) {
  %module = alloca ptr
  %tn = alloca ptr
  store ptr %p_module, ptr %module
  store ptr %p_tn, ptr %tn
  %t6239 = load ptr, ptr %tn
  %t6240 = getelementptr inbounds %ASTNode, ptr %t6239, i32 0, i32 3
  %t6241 = load i32, ptr %t6240
  %t6242 = icmp eq i32 %t6241, 1
  br i1 %t6242, label %label_1926, label %label_1928
label_1926:
  %t6243 = load ptr, ptr %tn
  %t6244 = getelementptr inbounds %ASTNode, ptr %t6243, i32 0, i32 5
  %t6245 = load ptr, ptr %t6244
  %t6246 = getelementptr inbounds [1 x i8], ptr @.str.s831, i64 0, i64 0
  %t6247 = call i32 @str_equals(ptr %t6245, ptr %t6246)
  %t6248 = icmp eq i32 %t6247, 0
  br i1 %t6248, label %label_1929, label %label_1931
label_1929:
  %t6249 = load ptr, ptr %module
  %t6250 = load ptr, ptr %tn
  %t6251 = getelementptr inbounds %ASTNode, ptr %t6250, i32 0, i32 5
  %t6252 = load ptr, ptr %t6251
  %t6253 = call ptr @ptr_to_node(ptr %t6252)
  %t6254 = call ptr @sema_annotation_type__Struct_ASTNode_Struct_ASTNode(ptr %t6249, ptr %t6253)
  %t6255 = call ptr @type_array__Struct_TypeInfo(ptr %t6254)
  ret ptr %t6255
label_1931:
  %t6256 = call ptr @type_invalid__Void()
  %t6257 = call ptr @type_array__Struct_TypeInfo(ptr %t6256)
  ret ptr %t6257
label_1928:
  %t6258 = load ptr, ptr %tn
  %t6259 = getelementptr inbounds %ASTNode, ptr %t6258, i32 0, i32 4
  %t6260 = load i32, ptr %t6259
  %t6261 = icmp eq i32 %t6260, 1
  br i1 %t6261, label %label_1932, label %label_1934
label_1932:
  %t6262 = load ptr, ptr %tn
  %t6263 = getelementptr inbounds %ASTNode, ptr %t6262, i32 0, i32 5
  %t6264 = load ptr, ptr %t6263
  %t6265 = getelementptr inbounds [1 x i8], ptr @.str.s832, i64 0, i64 0
  %t6266 = call i32 @str_equals(ptr %t6264, ptr %t6265)
  %t6267 = icmp eq i32 %t6266, 0
  br i1 %t6267, label %label_1935, label %label_1937
label_1935:
  %t6268 = load ptr, ptr %module
  %t6269 = load ptr, ptr %tn
  %t6270 = getelementptr inbounds %ASTNode, ptr %t6269, i32 0, i32 5
  %t6271 = load ptr, ptr %t6270
  %t6272 = call ptr @ptr_to_node(ptr %t6271)
  %t6273 = call ptr @sema_annotation_type__Struct_ASTNode_Struct_ASTNode(ptr %t6268, ptr %t6272)
  %t6274 = call ptr @type_list__Struct_TypeInfo(ptr %t6273)
  ret ptr %t6274
label_1937:
  %t6275 = call ptr @type_invalid__Void()
  %t6276 = call ptr @type_list__Struct_TypeInfo(ptr %t6275)
  ret ptr %t6276
label_1934:
  %t6277 = load ptr, ptr %tn
  %t6278 = getelementptr inbounds %ASTNode, ptr %t6277, i32 0, i32 1
  %t6279 = load ptr, ptr %t6278
  %t6280 = getelementptr inbounds [4 x i8], ptr @.str.s833, i64 0, i64 0
  %t6281 = call i32 @str_equals(ptr %t6279, ptr %t6280)
  %t6282 = icmp eq i32 %t6281, 1
  br i1 %t6282, label %label_1938, label %label_1940
label_1938:
  %t6283 = call ptr @type_int__Void()
  ret ptr %t6283
label_1940:
  %t6284 = load ptr, ptr %tn
  %t6285 = getelementptr inbounds %ASTNode, ptr %t6284, i32 0, i32 1
  %t6286 = load ptr, ptr %t6285
  %t6287 = getelementptr inbounds [6 x i8], ptr @.str.s834, i64 0, i64 0
  %t6288 = call i32 @str_equals(ptr %t6286, ptr %t6287)
  %t6289 = icmp eq i32 %t6288, 1
  br i1 %t6289, label %label_1941, label %label_1943
label_1941:
  %t6290 = call ptr @type_float__Void()
  ret ptr %t6290
label_1943:
  %t6291 = load ptr, ptr %tn
  %t6292 = getelementptr inbounds %ASTNode, ptr %t6291, i32 0, i32 1
  %t6293 = load ptr, ptr %t6292
  %t6294 = getelementptr inbounds [5 x i8], ptr @.str.s835, i64 0, i64 0
  %t6295 = call i32 @str_equals(ptr %t6293, ptr %t6294)
  %t6296 = icmp eq i32 %t6295, 1
  br i1 %t6296, label %label_1944, label %label_1946
label_1944:
  %t6297 = call ptr @type_bool__Void()
  ret ptr %t6297
label_1946:
  %t6298 = load ptr, ptr %tn
  %t6299 = getelementptr inbounds %ASTNode, ptr %t6298, i32 0, i32 1
  %t6300 = load ptr, ptr %t6299
  %t6301 = getelementptr inbounds [7 x i8], ptr @.str.s836, i64 0, i64 0
  %t6302 = call i32 @str_equals(ptr %t6300, ptr %t6301)
  %t6303 = icmp eq i32 %t6302, 1
  br i1 %t6303, label %label_1947, label %label_1949
label_1947:
  %t6304 = call ptr @type_string__Void()
  ret ptr %t6304
label_1949:
  %t6305 = load ptr, ptr %tn
  %t6306 = getelementptr inbounds %ASTNode, ptr %t6305, i32 0, i32 1
  %t6307 = load ptr, ptr %t6306
  %t6308 = getelementptr inbounds [5 x i8], ptr @.str.s837, i64 0, i64 0
  %t6309 = call i32 @str_equals(ptr %t6307, ptr %t6308)
  %t6310 = icmp eq i32 %t6309, 1
  br i1 %t6310, label %label_1950, label %label_1952
label_1950:
  %t6311 = call ptr @type_char__Void()
  ret ptr %t6311
label_1952:
  %t6312 = load ptr, ptr %tn
  %t6313 = getelementptr inbounds %ASTNode, ptr %t6312, i32 0, i32 1
  %t6314 = load ptr, ptr %t6313
  %t6315 = getelementptr inbounds [3 x i8], ptr @.str.s838, i64 0, i64 0
  %t6316 = call i32 @str_equals(ptr %t6314, ptr %t6315)
  %t6317 = icmp eq i32 %t6316, 1
  br i1 %t6317, label %label_1953, label %label_1955
label_1953:
  %t6318 = call ptr @type_i8__Void()
  ret ptr %t6318
label_1955:
  %t6319 = load ptr, ptr %tn
  %t6320 = getelementptr inbounds %ASTNode, ptr %t6319, i32 0, i32 1
  %t6321 = load ptr, ptr %t6320
  %t6322 = getelementptr inbounds [4 x i8], ptr @.str.s839, i64 0, i64 0
  %t6323 = call i32 @str_equals(ptr %t6321, ptr %t6322)
  %t6324 = icmp eq i32 %t6323, 1
  br i1 %t6324, label %label_1956, label %label_1958
label_1956:
  %t6325 = call ptr @type_i16__Void()
  ret ptr %t6325
label_1958:
  %t6326 = load ptr, ptr %tn
  %t6327 = getelementptr inbounds %ASTNode, ptr %t6326, i32 0, i32 1
  %t6328 = load ptr, ptr %t6327
  %t6329 = getelementptr inbounds [4 x i8], ptr @.str.s840, i64 0, i64 0
  %t6330 = call i32 @str_equals(ptr %t6328, ptr %t6329)
  %t6331 = icmp eq i32 %t6330, 1
  br i1 %t6331, label %label_1959, label %label_1961
label_1959:
  %t6332 = call ptr @type_i64__Void()
  ret ptr %t6332
label_1961:
  %t6333 = load ptr, ptr %tn
  %t6334 = getelementptr inbounds %ASTNode, ptr %t6333, i32 0, i32 1
  %t6335 = load ptr, ptr %t6334
  %t6336 = getelementptr inbounds [6 x i8], ptr @.str.s841, i64 0, i64 0
  %t6337 = call i32 @str_equals(ptr %t6335, ptr %t6336)
  %t6338 = icmp eq i32 %t6337, 1
  br i1 %t6338, label %label_1962, label %label_1964
label_1962:
  %t6339 = call ptr @type_isize__Void()
  ret ptr %t6339
label_1964:
  %t6340 = load ptr, ptr %tn
  %t6341 = getelementptr inbounds %ASTNode, ptr %t6340, i32 0, i32 1
  %t6342 = load ptr, ptr %t6341
  %t6343 = getelementptr inbounds [3 x i8], ptr @.str.s842, i64 0, i64 0
  %t6344 = call i32 @str_equals(ptr %t6342, ptr %t6343)
  %t6345 = icmp eq i32 %t6344, 1
  br i1 %t6345, label %label_1965, label %label_1967
label_1965:
  %t6346 = call ptr @type_u8__Void()
  ret ptr %t6346
label_1967:
  %t6347 = load ptr, ptr %tn
  %t6348 = getelementptr inbounds %ASTNode, ptr %t6347, i32 0, i32 1
  %t6349 = load ptr, ptr %t6348
  %t6350 = getelementptr inbounds [4 x i8], ptr @.str.s843, i64 0, i64 0
  %t6351 = call i32 @str_equals(ptr %t6349, ptr %t6350)
  %t6352 = icmp eq i32 %t6351, 1
  br i1 %t6352, label %label_1968, label %label_1970
label_1968:
  %t6353 = call ptr @type_u16__Void()
  ret ptr %t6353
label_1970:
  %t6354 = load ptr, ptr %tn
  %t6355 = getelementptr inbounds %ASTNode, ptr %t6354, i32 0, i32 1
  %t6356 = load ptr, ptr %t6355
  %t6357 = getelementptr inbounds [4 x i8], ptr @.str.s844, i64 0, i64 0
  %t6358 = call i32 @str_equals(ptr %t6356, ptr %t6357)
  %t6359 = icmp eq i32 %t6358, 1
  br i1 %t6359, label %label_1971, label %label_1973
label_1971:
  %t6360 = call ptr @type_u32__Void()
  ret ptr %t6360
label_1973:
  %t6361 = load ptr, ptr %tn
  %t6362 = getelementptr inbounds %ASTNode, ptr %t6361, i32 0, i32 1
  %t6363 = load ptr, ptr %t6362
  %t6364 = getelementptr inbounds [4 x i8], ptr @.str.s845, i64 0, i64 0
  %t6365 = call i32 @str_equals(ptr %t6363, ptr %t6364)
  %t6366 = icmp eq i32 %t6365, 1
  br i1 %t6366, label %label_1974, label %label_1976
label_1974:
  %t6367 = call ptr @type_u64__Void()
  ret ptr %t6367
label_1976:
  %t6368 = load ptr, ptr %tn
  %t6369 = getelementptr inbounds %ASTNode, ptr %t6368, i32 0, i32 1
  %t6370 = load ptr, ptr %t6369
  %t6371 = getelementptr inbounds [6 x i8], ptr @.str.s846, i64 0, i64 0
  %t6372 = call i32 @str_equals(ptr %t6370, ptr %t6371)
  %t6373 = icmp eq i32 %t6372, 1
  br i1 %t6373, label %label_1977, label %label_1979
label_1977:
  %t6374 = call ptr @type_usize__Void()
  ret ptr %t6374
label_1979:
  %t6375 = load ptr, ptr %tn
  %t6376 = getelementptr inbounds %ASTNode, ptr %t6375, i32 0, i32 1
  %t6377 = load ptr, ptr %t6376
  %t6378 = getelementptr inbounds [1 x i8], ptr @.str.s847, i64 0, i64 0
  %t6379 = call i32 @str_equals(ptr %t6377, ptr %t6378)
  %t6380 = icmp eq i32 %t6379, 1
  br i1 %t6380, label %label_1980, label %label_1982
label_1980:
  %t6381 = call ptr @type_void__Void()
  ret ptr %t6381
label_1982:
  %t6382 = load ptr, ptr %module
  %t6383 = load ptr, ptr %tn
  %t6384 = getelementptr inbounds %ASTNode, ptr %t6383, i32 0, i32 1
  %t6385 = load ptr, ptr %t6384
  %t6386 = call i1 @sema_has_enum__Struct_ASTNode_String(ptr %t6382, ptr %t6385)
  br i1 %t6386, label %label_1983, label %label_1985
label_1983:
  %t6387 = load ptr, ptr %tn
  %t6388 = getelementptr inbounds %ASTNode, ptr %t6387, i32 0, i32 1
  %t6389 = load ptr, ptr %t6388
  %t6390 = call ptr @type_enum__String(ptr %t6389)
  ret ptr %t6390
label_1985:
  %t6391 = load ptr, ptr %module
  %t6392 = load ptr, ptr %tn
  %t6393 = getelementptr inbounds %ASTNode, ptr %t6392, i32 0, i32 1
  %t6394 = load ptr, ptr %t6393
  %t6395 = call i1 @sema_has_struct__Struct_ASTNode_String(ptr %t6391, ptr %t6394)
  br i1 %t6395, label %label_1986, label %label_1988
label_1986:
  %t6396 = load ptr, ptr %tn
  %t6397 = getelementptr inbounds %ASTNode, ptr %t6396, i32 0, i32 1
  %t6398 = load ptr, ptr %t6397
  %t6399 = call ptr @type_struct__String(ptr %t6398)
  ret ptr %t6399
label_1988:
  %t6400 = getelementptr inbounds [14 x i8], ptr @.str.s848, i64 0, i64 0
  %t6401 = load ptr, ptr %tn
  %t6402 = getelementptr inbounds %ASTNode, ptr %t6401, i32 0, i32 1
  %t6403 = load ptr, ptr %t6402
  %t6404 = call ptr @str_concat(ptr %t6400, ptr %t6403)
  call void @sema_error__String(ptr %t6404)
  %t6405 = call ptr @type_invalid__Void()
  ret ptr %t6405
}

define ptr @sema_declared_return_type__Struct_ASTNode_String(ptr %p_module, ptr %p_ret_child) {
  %module = alloca ptr
  %ret_child = alloca ptr
  store ptr %p_module, ptr %module
  store ptr %p_ret_child, ptr %ret_child
  %t6408 = load ptr, ptr %ret_child
  %t6409 = getelementptr inbounds [1 x i8], ptr @.str.s849, i64 0, i64 0
  %t6410 = call i32 @str_equals(ptr %t6408, ptr %t6409)
  %t6411 = icmp eq i32 %t6410, 0
  br i1 %t6411, label %label_1989, label %label_1991
label_1989:
  %t6412 = load ptr, ptr %module
  %t6413 = load ptr, ptr %ret_child
  %t6414 = call ptr @ptr_to_node(ptr %t6413)
  %t6415 = call ptr @sema_annotation_type__Struct_ASTNode_Struct_ASTNode(ptr %t6412, ptr %t6414)
  ret ptr %t6415
label_1991:
  %t6416 = call ptr @type_void__Void()
  ret ptr %t6416
}

define i1 @sema_enum_matches_int__Struct_TypeInfo_Struct_TypeInfo(ptr %p_a, ptr %p_b) {
  %a = alloca ptr
  %b = alloca ptr
  store ptr %p_a, ptr %a
  store ptr %p_b, ptr %b
  %t6419 = load ptr, ptr %a
  %t6420 = getelementptr inbounds %TypeInfo, ptr %t6419, i32 0, i32 0
  %t6421 = load i32, ptr %t6420
  %t6422 = icmp ne i32 %t6421, 9
  br i1 %t6422, label %label_1992, label %label_1994
label_1992:
  ret i1 0
label_1994:
  %t6423 = load ptr, ptr %b
  %t6424 = getelementptr inbounds %TypeInfo, ptr %t6423, i32 0, i32 0
  %t6425 = load i32, ptr %t6424
  %t6426 = icmp ne i32 %t6425, 2
  br i1 %t6426, label %label_1995, label %label_1997
label_1995:
  ret i1 0
label_1997:
  %t6427 = load ptr, ptr %b
  %t6428 = getelementptr inbounds %TypeInfo, ptr %t6427, i32 0, i32 1
  %t6429 = load ptr, ptr %t6428
  %t6430 = getelementptr inbounds [4 x i8], ptr @.str.s850, i64 0, i64 0
  %t6431 = call i32 @str_equals(ptr %t6429, ptr %t6430)
  %t6432 = icmp eq i32 %t6431, 1
  ret i1 %t6432
}

define i1 @sema_types_match__Struct_TypeInfo_Struct_TypeInfo(ptr %p_expected, ptr %p_actual) {
  %expected = alloca ptr
  %actual = alloca ptr
  store ptr %p_expected, ptr %expected
  store ptr %p_actual, ptr %actual
  %t6435 = load ptr, ptr %expected
  %t6436 = load ptr, ptr %actual
  %t6437 = call i1 @type_equals__Struct_TypeInfo_Struct_TypeInfo(ptr %t6435, ptr %t6436)
  br i1 %t6437, label %label_1998, label %label_2000
label_1998:
  ret i1 1
label_2000:
  %t6438 = load ptr, ptr %expected
  %t6439 = load ptr, ptr %actual
  %t6440 = call i1 @sema_enum_matches_int__Struct_TypeInfo_Struct_TypeInfo(ptr %t6438, ptr %t6439)
  br i1 %t6440, label %label_2001, label %label_2003
label_2001:
  ret i1 1
label_2003:
  %t6441 = load ptr, ptr %actual
  %t6442 = load ptr, ptr %expected
  %t6443 = call i1 @sema_enum_matches_int__Struct_TypeInfo_Struct_TypeInfo(ptr %t6441, ptr %t6442)
  br i1 %t6443, label %label_2004, label %label_2006
label_2004:
  ret i1 1
label_2006:
  ret i1 0
}

define void @sema_expect_assignable__String_Struct_TypeInfo_Struct_TypeInfo(ptr %p_context, ptr %p_expected, ptr %p_actual) {
  %context = alloca ptr
  %expected = alloca ptr
  %actual = alloca ptr
  store ptr %p_context, ptr %context
  store ptr %p_expected, ptr %expected
  store ptr %p_actual, ptr %actual
  %t6447 = load ptr, ptr %expected
  %t6448 = load ptr, ptr %actual
  %t6449 = call i1 @sema_types_match__Struct_TypeInfo_Struct_TypeInfo(ptr %t6447, ptr %t6448)
  %t6450 = icmp eq i1 %t6449, 0
  br i1 %t6450, label %label_2007, label %label_2009
label_2007:
  %t6451 = load ptr, ptr %context
  %t6452 = load ptr, ptr %expected
  %t6453 = load ptr, ptr %actual
  call void @sema_type_error__String_Struct_TypeInfo_Struct_TypeInfo(ptr %t6451, ptr %t6452, ptr %t6453)
  br label %label_2009
label_2009:
  ret void
}

define i1 @sema_is_int_literal__Struct_ASTNode(ptr %p_e) {
  %e = alloca ptr
  store ptr %p_e, ptr %e
  %t6455 = load ptr, ptr %e
  %t6456 = getelementptr inbounds %ASTNode, ptr %t6455, i32 0, i32 0
  %t6457 = load i32, ptr %t6456
  %t6458 = icmp eq i32 %t6457, 22
  %t6459 = load ptr, ptr %e
  %t6460 = getelementptr inbounds %ASTNode, ptr %t6459, i32 0, i32 3
  %t6461 = load i32, ptr %t6460
  %t6462 = icmp eq i32 %t6461, 2
  %t6463 = and i1 %t6458, %t6462
  ret i1 %t6463
}

define void @sema_move_operand__Struct_ASTNode(ptr %p_node) {
  %node = alloca ptr
  store ptr %p_node, ptr %node
  %t6465 = load ptr, ptr %node
  %t6466 = getelementptr inbounds %ASTNode, ptr %t6465, i32 0, i32 0
  %t6467 = load i32, ptr %t6466
  %t6468 = icmp eq i32 %t6467, 23
  br i1 %t6468, label %label_2010, label %label_2012
label_2010:
  %t6469 = load ptr, ptr %node
  %t6470 = call ptr @node_get_type__Struct_ASTNode(ptr %t6469)
  %t6471 = call i1 @type_is_move_only__Struct_TypeInfo(ptr %t6470)
  br i1 %t6471, label %label_2013, label %label_2015
label_2013:
  %t6472 = load ptr, ptr %node
  %t6473 = getelementptr inbounds %ASTNode, ptr %t6472, i32 0, i32 1
  %t6474 = load ptr, ptr %t6473
  %t6475 = call i32 @ir_is_borrowed(ptr %t6474)
  %t6476 = icmp eq i32 %t6475, 1
  br i1 %t6476, label %label_2016, label %label_2018
label_2016:
  %t6477 = getelementptr inbounds [36 x i8], ptr @.str.s851, i64 0, i64 0
  %t6478 = load ptr, ptr %node
  %t6479 = getelementptr inbounds %ASTNode, ptr %t6478, i32 0, i32 1
  %t6480 = load ptr, ptr %t6479
  %t6481 = call ptr @str_concat(ptr %t6477, ptr %t6480)
  call void @sema_error__String(ptr %t6481)
  br label %label_2018
label_2018:
  %t6482 = load ptr, ptr %node
  %t6483 = getelementptr inbounds %ASTNode, ptr %t6482, i32 0, i32 1
  %t6484 = load ptr, ptr %t6483
  call void @ir_mark_moved(ptr %t6484)
  br label %label_2015
label_2015:
  br label %label_2012
label_2012:
  ret void
}

define ptr @sema_check_value__Struct_ASTNode_Struct_ASTNode_Struct_TypeInfo_String(ptr %p_module, ptr %p_val_node, ptr %p_expected, ptr %p_context) {
  %module = alloca ptr
  %val_node = alloca ptr
  %expected = alloca ptr
  %context = alloca ptr
  %actual = alloca ptr
  store ptr %p_module, ptr %module
  store ptr %p_val_node, ptr %val_node
  store ptr %p_expected, ptr %expected
  store ptr %p_context, ptr %context
  %t6490 = load ptr, ptr %expected
  %t6491 = call i1 @type_is_valid__Struct_TypeInfo(ptr %t6490)
  %t6492 = load ptr, ptr %expected
  %t6493 = getelementptr inbounds %TypeInfo, ptr %t6492, i32 0, i32 0
  %t6494 = load i32, ptr %t6493
  %t6495 = icmp eq i32 %t6494, 2
  %t6496 = and i1 %t6491, %t6495
  %t6497 = load ptr, ptr %val_node
  %t6498 = call i1 @sema_is_int_literal__Struct_ASTNode(ptr %t6497)
  %t6499 = and i1 %t6496, %t6498
  br i1 %t6499, label %label_2019, label %label_2021
label_2019:
  %t6500 = load ptr, ptr %val_node
  %t6501 = load ptr, ptr %expected
  call void @node_set_type__Struct_ASTNode_Struct_TypeInfo(ptr %t6500, ptr %t6501)
  %t6502 = load ptr, ptr %expected
  ret ptr %t6502
label_2021:
  %t6503 = load ptr, ptr %module
  %t6504 = load ptr, ptr %val_node
  %t6505 = call ptr @sema_expr__Struct_ASTNode_Struct_ASTNode(ptr %t6503, ptr %t6504)
  store ptr %t6505, ptr %actual
  %t6506 = load ptr, ptr %context
  %t6507 = load ptr, ptr %expected
  %t6508 = load ptr, ptr %actual
  call void @sema_expect_assignable__String_Struct_TypeInfo_Struct_TypeInfo(ptr %t6506, ptr %t6507, ptr %t6508)
  %t6509 = load ptr, ptr %actual
  ret ptr %t6509
}

define ptr @sema_find_function__Struct_ASTNode_String(ptr %p_module, ptr %p_name) {
  %module = alloca ptr
  %name = alloca ptr
  %stmt_ptr = alloca ptr
  %stmt = alloca ptr
  store ptr %p_module, ptr %module
  store ptr %p_name, ptr %name
  %t6514 = load ptr, ptr %module
  %t6515 = getelementptr inbounds %ASTNode, ptr %t6514, i32 0, i32 5
  %t6516 = load ptr, ptr %t6515
  store ptr %t6516, ptr %stmt_ptr
  br label %label_2022
label_2022:
  %t6517 = load ptr, ptr %stmt_ptr
  %t6518 = getelementptr inbounds [1 x i8], ptr @.str.s852, i64 0, i64 0
  %t6519 = call i32 @str_equals(ptr %t6517, ptr %t6518)
  %t6520 = icmp eq i32 %t6519, 0
  br i1 %t6520, label %label_2023, label %label_2024
label_2023:
  %t6521 = load ptr, ptr %stmt_ptr
  %t6522 = call ptr @ptr_to_node(ptr %t6521)
  store ptr %t6522, ptr %stmt
  %t6523 = load ptr, ptr %stmt
  %t6524 = getelementptr inbounds %ASTNode, ptr %t6523, i32 0, i32 0
  %t6525 = load i32, ptr %t6524
  %t6526 = icmp eq i32 %t6525, 4
  %t6527 = load ptr, ptr %stmt
  %t6528 = getelementptr inbounds %ASTNode, ptr %t6527, i32 0, i32 0
  %t6529 = load i32, ptr %t6528
  %t6530 = icmp eq i32 %t6529, 2
  %t6531 = or i1 %t6526, %t6530
  %t6532 = load ptr, ptr %stmt
  %t6533 = getelementptr inbounds %ASTNode, ptr %t6532, i32 0, i32 1
  %t6534 = load ptr, ptr %t6533
  %t6535 = load ptr, ptr %name
  %t6536 = call i32 @str_equals(ptr %t6534, ptr %t6535)
  %t6537 = icmp eq i32 %t6536, 1
  %t6538 = and i1 %t6531, %t6537
  br i1 %t6538, label %label_2025, label %label_2027
label_2025:
  %t6539 = load ptr, ptr %stmt
  ret ptr %t6539
label_2027:
  %t6540 = load ptr, ptr %stmt
  %t6541 = getelementptr inbounds %ASTNode, ptr %t6540, i32 0, i32 8
  %t6542 = load ptr, ptr %t6541
  store ptr %t6542, ptr %stmt_ptr
  br label %label_2022
label_2024:
  %t6543 = call ptr @create_node__Enum_NodeKind(i32 0)
  ret ptr %t6543
}

define i1 @sema_arg_matches_type__Struct_ASTNode_Struct_ASTNode_Struct_TypeInfo(ptr %p_module, ptr %p_arg_node, ptr %p_expected) {
  %module = alloca ptr
  %arg_node = alloca ptr
  %expected = alloca ptr
  %actual = alloca ptr
  store ptr %p_module, ptr %module
  store ptr %p_arg_node, ptr %arg_node
  store ptr %p_expected, ptr %expected
  %t6548 = load ptr, ptr %expected
  %t6549 = call i1 @type_is_valid__Struct_TypeInfo(ptr %t6548)
  %t6550 = load ptr, ptr %expected
  %t6551 = getelementptr inbounds %TypeInfo, ptr %t6550, i32 0, i32 0
  %t6552 = load i32, ptr %t6551
  %t6553 = icmp eq i32 %t6552, 2
  %t6554 = and i1 %t6549, %t6553
  %t6555 = load ptr, ptr %arg_node
  %t6556 = call i1 @sema_is_int_literal__Struct_ASTNode(ptr %t6555)
  %t6557 = and i1 %t6554, %t6556
  br i1 %t6557, label %label_2028, label %label_2030
label_2028:
  ret i1 1
label_2030:
  %t6558 = load ptr, ptr %module
  %t6559 = load ptr, ptr %arg_node
  %t6560 = call ptr @sema_expr__Struct_ASTNode_Struct_ASTNode(ptr %t6558, ptr %t6559)
  store ptr %t6560, ptr %actual
  %t6561 = load ptr, ptr %expected
  %t6562 = load ptr, ptr %actual
  %t6563 = call i1 @sema_types_match__Struct_TypeInfo_Struct_TypeInfo(ptr %t6561, ptr %t6562)
  ret i1 %t6563
}

define i1 @sema_signature_matches_call__Struct_ASTNode_Struct_ASTNode_String(ptr %p_module, ptr %p_fn_node, ptr %p_arg_ptr) {
  %module = alloca ptr
  %fn_node = alloca ptr
  %arg_ptr = alloca ptr
  %arg = alloca ptr
  %param = alloca ptr
  %arg_node = alloca ptr
  %param_node = alloca ptr
  %param_t = alloca ptr
  store ptr %p_module, ptr %module
  store ptr %p_fn_node, ptr %fn_node
  store ptr %p_arg_ptr, ptr %arg_ptr
  %t6572 = load ptr, ptr %arg_ptr
  store ptr %t6572, ptr %arg
  %t6573 = load ptr, ptr %fn_node
  %t6574 = getelementptr inbounds %ASTNode, ptr %t6573, i32 0, i32 5
  %t6575 = load ptr, ptr %t6574
  store ptr %t6575, ptr %param
  br label %label_2031
label_2031:
  %t6576 = load ptr, ptr %arg
  %t6577 = getelementptr inbounds [1 x i8], ptr @.str.s853, i64 0, i64 0
  %t6578 = call i32 @str_equals(ptr %t6576, ptr %t6577)
  %t6579 = icmp eq i32 %t6578, 0
  %t6580 = load ptr, ptr %param
  %t6581 = getelementptr inbounds [1 x i8], ptr @.str.s854, i64 0, i64 0
  %t6582 = call i32 @str_equals(ptr %t6580, ptr %t6581)
  %t6583 = icmp eq i32 %t6582, 0
  %t6584 = and i1 %t6579, %t6583
  br i1 %t6584, label %label_2032, label %label_2033
label_2032:
  %t6585 = load ptr, ptr %arg
  %t6586 = call ptr @ptr_to_node(ptr %t6585)
  store ptr %t6586, ptr %arg_node
  %t6587 = load ptr, ptr %param
  %t6588 = call ptr @ptr_to_node(ptr %t6587)
  store ptr %t6588, ptr %param_node
  %t6589 = load ptr, ptr %module
  %t6590 = load ptr, ptr %param_node
  %t6591 = getelementptr inbounds %ASTNode, ptr %t6590, i32 0, i32 5
  %t6592 = load ptr, ptr %t6591
  %t6593 = call ptr @ptr_to_node(ptr %t6592)
  %t6594 = call ptr @sema_annotation_type__Struct_ASTNode_Struct_ASTNode(ptr %t6589, ptr %t6593)
  store ptr %t6594, ptr %param_t
  %t6595 = load ptr, ptr %module
  %t6596 = load ptr, ptr %arg_node
  %t6597 = load ptr, ptr %param_t
  %t6598 = call i1 @sema_arg_matches_type__Struct_ASTNode_Struct_ASTNode_Struct_TypeInfo(ptr %t6595, ptr %t6596, ptr %t6597)
  %t6599 = icmp eq i1 %t6598, 0
  br i1 %t6599, label %label_2034, label %label_2036
label_2034:
  ret i1 0
label_2036:
  %t6600 = load ptr, ptr %arg_node
  %t6601 = getelementptr inbounds %ASTNode, ptr %t6600, i32 0, i32 8
  %t6602 = load ptr, ptr %t6601
  store ptr %t6602, ptr %arg
  %t6603 = load ptr, ptr %param_node
  %t6604 = getelementptr inbounds %ASTNode, ptr %t6603, i32 0, i32 8
  %t6605 = load ptr, ptr %t6604
  store ptr %t6605, ptr %param
  br label %label_2031
label_2033:
  %t6606 = load ptr, ptr %arg
  %t6607 = getelementptr inbounds [1 x i8], ptr @.str.s855, i64 0, i64 0
  %t6608 = call i32 @str_equals(ptr %t6606, ptr %t6607)
  %t6609 = icmp eq i32 %t6608, 1
  %t6610 = load ptr, ptr %param
  %t6611 = getelementptr inbounds [1 x i8], ptr @.str.s856, i64 0, i64 0
  %t6612 = call i32 @str_equals(ptr %t6610, ptr %t6611)
  %t6613 = icmp eq i32 %t6612, 1
  %t6614 = and i1 %t6609, %t6613
  ret i1 %t6614
}

define i1 @sema_has_function_definition__Struct_ASTNode_String(ptr %p_module, ptr %p_name) {
  %module = alloca ptr
  %name = alloca ptr
  %scan_ptr = alloca ptr
  %scan = alloca ptr
  store ptr %p_module, ptr %module
  store ptr %p_name, ptr %name
  %t6619 = load ptr, ptr %module
  %t6620 = getelementptr inbounds %ASTNode, ptr %t6619, i32 0, i32 5
  %t6621 = load ptr, ptr %t6620
  store ptr %t6621, ptr %scan_ptr
  br label %label_2037
label_2037:
  %t6622 = load ptr, ptr %scan_ptr
  %t6623 = getelementptr inbounds [1 x i8], ptr @.str.s857, i64 0, i64 0
  %t6624 = call i32 @str_equals(ptr %t6622, ptr %t6623)
  %t6625 = icmp eq i32 %t6624, 0
  br i1 %t6625, label %label_2038, label %label_2039
label_2038:
  %t6626 = load ptr, ptr %scan_ptr
  %t6627 = call ptr @ptr_to_node(ptr %t6626)
  store ptr %t6627, ptr %scan
  %t6628 = load ptr, ptr %scan
  %t6629 = getelementptr inbounds %ASTNode, ptr %t6628, i32 0, i32 0
  %t6630 = load i32, ptr %t6629
  %t6631 = icmp eq i32 %t6630, 4
  %t6632 = load ptr, ptr %scan
  %t6633 = getelementptr inbounds %ASTNode, ptr %t6632, i32 0, i32 1
  %t6634 = load ptr, ptr %t6633
  %t6635 = load ptr, ptr %name
  %t6636 = call i32 @str_equals(ptr %t6634, ptr %t6635)
  %t6637 = icmp eq i32 %t6636, 1
  %t6638 = and i1 %t6631, %t6637
  br i1 %t6638, label %label_2040, label %label_2042
label_2040:
  ret i1 1
label_2042:
  %t6639 = load ptr, ptr %scan
  %t6640 = getelementptr inbounds %ASTNode, ptr %t6639, i32 0, i32 8
  %t6641 = load ptr, ptr %t6640
  store ptr %t6641, ptr %scan_ptr
  br label %label_2037
label_2039:
  ret i1 0
}

define ptr @sema_find_function_overload__Struct_ASTNode_String_String(ptr %p_module, ptr %p_name, ptr %p_arg_ptr) {
  %module = alloca ptr
  %name = alloca ptr
  %arg_ptr = alloca ptr
  %best_ptr = alloca ptr
  %match_count = alloca i32
  %name_seen = alloca i1
  %definition_exists = alloca i1
  %stmt_ptr = alloca ptr
  %stmt = alloca ptr
  %is_candidate = alloca i1
  store ptr %p_module, ptr %module
  store ptr %p_name, ptr %name
  store ptr %p_arg_ptr, ptr %arg_ptr
  %t6652 = getelementptr inbounds [1 x i8], ptr @.str.s858, i64 0, i64 0
  store ptr %t6652, ptr %best_ptr
  store i32 0, ptr %match_count
  store i1 0, ptr %name_seen
  %t6653 = load ptr, ptr %module
  %t6654 = load ptr, ptr %name
  %t6655 = call i1 @sema_has_function_definition__Struct_ASTNode_String(ptr %t6653, ptr %t6654)
  store i1 %t6655, ptr %definition_exists
  %t6656 = load ptr, ptr %module
  %t6657 = getelementptr inbounds %ASTNode, ptr %t6656, i32 0, i32 5
  %t6658 = load ptr, ptr %t6657
  store ptr %t6658, ptr %stmt_ptr
  br label %label_2043
label_2043:
  %t6659 = load ptr, ptr %stmt_ptr
  %t6660 = getelementptr inbounds [1 x i8], ptr @.str.s859, i64 0, i64 0
  %t6661 = call i32 @str_equals(ptr %t6659, ptr %t6660)
  %t6662 = icmp eq i32 %t6661, 0
  br i1 %t6662, label %label_2044, label %label_2045
label_2044:
  %t6663 = load ptr, ptr %stmt_ptr
  %t6664 = call ptr @ptr_to_node(ptr %t6663)
  store ptr %t6664, ptr %stmt
  %t6665 = load ptr, ptr %stmt
  %t6666 = getelementptr inbounds %ASTNode, ptr %t6665, i32 0, i32 0
  %t6667 = load i32, ptr %t6666
  %t6668 = icmp eq i32 %t6667, 4
  store i1 %t6668, ptr %is_candidate
  %t6669 = load ptr, ptr %stmt
  %t6670 = getelementptr inbounds %ASTNode, ptr %t6669, i32 0, i32 0
  %t6671 = load i32, ptr %t6670
  %t6672 = icmp eq i32 %t6671, 2
  %t6673 = load i1, ptr %definition_exists
  %t6674 = icmp eq i1 %t6673, 0
  %t6675 = and i1 %t6672, %t6674
  br i1 %t6675, label %label_2046, label %label_2048
label_2046:
  store i1 1, ptr %is_candidate
  br label %label_2048
label_2048:
  %t6676 = load i1, ptr %is_candidate
  %t6677 = load ptr, ptr %stmt
  %t6678 = getelementptr inbounds %ASTNode, ptr %t6677, i32 0, i32 1
  %t6679 = load ptr, ptr %t6678
  %t6680 = load ptr, ptr %name
  %t6681 = call i32 @str_equals(ptr %t6679, ptr %t6680)
  %t6682 = icmp eq i32 %t6681, 1
  %t6683 = and i1 %t6676, %t6682
  br i1 %t6683, label %label_2049, label %label_2051
label_2049:
  store i1 1, ptr %name_seen
  %t6684 = load ptr, ptr %module
  %t6685 = load ptr, ptr %stmt
  %t6686 = load ptr, ptr %arg_ptr
  %t6687 = call i1 @sema_signature_matches_call__Struct_ASTNode_Struct_ASTNode_String(ptr %t6684, ptr %t6685, ptr %t6686)
  br i1 %t6687, label %label_2052, label %label_2054
label_2052:
  %t6688 = load ptr, ptr %stmt_ptr
  store ptr %t6688, ptr %best_ptr
  %t6689 = load i32, ptr %match_count
  %t6690 = add i32 %t6689, 1
  store i32 %t6690, ptr %match_count
  br label %label_2054
label_2054:
  br label %label_2051
label_2051:
  %t6691 = load ptr, ptr %stmt
  %t6692 = getelementptr inbounds %ASTNode, ptr %t6691, i32 0, i32 8
  %t6693 = load ptr, ptr %t6692
  store ptr %t6693, ptr %stmt_ptr
  br label %label_2043
label_2045:
  %t6694 = load i32, ptr %match_count
  %t6695 = icmp sgt i32 %t6694, 1
  br i1 %t6695, label %label_2055, label %label_2057
label_2055:
  %t6696 = getelementptr inbounds [30 x i8], ptr @.str.s860, i64 0, i64 0
  %t6697 = load ptr, ptr %name
  %t6698 = call ptr @str_concat(ptr %t6696, ptr %t6697)
  call void @sema_error__String(ptr %t6698)
  br label %label_2057
label_2057:
  %t6699 = load i32, ptr %match_count
  %t6700 = icmp eq i32 %t6699, 1
  br i1 %t6700, label %label_2058, label %label_2060
label_2058:
  %t6701 = load ptr, ptr %best_ptr
  %t6702 = call ptr @ptr_to_node(ptr %t6701)
  ret ptr %t6702
label_2060:
  %t6703 = load i1, ptr %name_seen
  br i1 %t6703, label %label_2061, label %label_2063
label_2061:
  %t6704 = getelementptr inbounds [26 x i8], ptr @.str.s861, i64 0, i64 0
  %t6705 = load ptr, ptr %name
  %t6706 = call ptr @str_concat(ptr %t6704, ptr %t6705)
  call void @sema_error__String(ptr %t6706)
  br label %label_2063
label_2063:
  %t6707 = getelementptr inbounds [18 x i8], ptr @.str.s862, i64 0, i64 0
  %t6708 = load ptr, ptr %name
  %t6709 = call ptr @str_concat(ptr %t6707, ptr %t6708)
  call void @sema_error__String(ptr %t6709)
  %t6710 = call ptr @create_node__Enum_NodeKind(i32 0)
  ret ptr %t6710
}

define ptr @sema_find_struct_field_type__Struct_ASTNode_String_String(ptr %p_module, ptr %p_struct_name, ptr %p_field_name) {
  %module = alloca ptr
  %struct_name = alloca ptr
  %field_name = alloca ptr
  %stmt_ptr = alloca ptr
  %stmt = alloca ptr
  %field_ptr = alloca ptr
  %field = alloca ptr
  store ptr %p_module, ptr %module
  store ptr %p_struct_name, ptr %struct_name
  store ptr %p_field_name, ptr %field_name
  %t6718 = load ptr, ptr %module
  %t6719 = getelementptr inbounds %ASTNode, ptr %t6718, i32 0, i32 5
  %t6720 = load ptr, ptr %t6719
  store ptr %t6720, ptr %stmt_ptr
  br label %label_2064
label_2064:
  %t6721 = load ptr, ptr %stmt_ptr
  %t6722 = getelementptr inbounds [1 x i8], ptr @.str.s863, i64 0, i64 0
  %t6723 = call i32 @str_equals(ptr %t6721, ptr %t6722)
  %t6724 = icmp eq i32 %t6723, 0
  br i1 %t6724, label %label_2065, label %label_2066
label_2065:
  %t6725 = load ptr, ptr %stmt_ptr
  %t6726 = call ptr @ptr_to_node(ptr %t6725)
  store ptr %t6726, ptr %stmt
  %t6727 = load ptr, ptr %stmt
  %t6728 = getelementptr inbounds %ASTNode, ptr %t6727, i32 0, i32 0
  %t6729 = load i32, ptr %t6728
  %t6730 = icmp eq i32 %t6729, 5
  %t6731 = load ptr, ptr %stmt
  %t6732 = getelementptr inbounds %ASTNode, ptr %t6731, i32 0, i32 1
  %t6733 = load ptr, ptr %t6732
  %t6734 = load ptr, ptr %struct_name
  %t6735 = call i32 @str_equals(ptr %t6733, ptr %t6734)
  %t6736 = icmp eq i32 %t6735, 1
  %t6737 = and i1 %t6730, %t6736
  br i1 %t6737, label %label_2067, label %label_2069
label_2067:
  %t6738 = load ptr, ptr %stmt
  %t6739 = getelementptr inbounds %ASTNode, ptr %t6738, i32 0, i32 5
  %t6740 = load ptr, ptr %t6739
  store ptr %t6740, ptr %field_ptr
  br label %label_2070
label_2070:
  %t6741 = load ptr, ptr %field_ptr
  %t6742 = getelementptr inbounds [1 x i8], ptr @.str.s864, i64 0, i64 0
  %t6743 = call i32 @str_equals(ptr %t6741, ptr %t6742)
  %t6744 = icmp eq i32 %t6743, 0
  br i1 %t6744, label %label_2071, label %label_2072
label_2071:
  %t6745 = load ptr, ptr %field_ptr
  %t6746 = call ptr @ptr_to_node(ptr %t6745)
  store ptr %t6746, ptr %field
  %t6747 = load ptr, ptr %field
  %t6748 = getelementptr inbounds %ASTNode, ptr %t6747, i32 0, i32 1
  %t6749 = load ptr, ptr %t6748
  %t6750 = load ptr, ptr %field_name
  %t6751 = call i32 @str_equals(ptr %t6749, ptr %t6750)
  %t6752 = icmp eq i32 %t6751, 1
  br i1 %t6752, label %label_2073, label %label_2075
label_2073:
  %t6753 = load ptr, ptr %module
  %t6754 = load ptr, ptr %field
  %t6755 = getelementptr inbounds %ASTNode, ptr %t6754, i32 0, i32 5
  %t6756 = load ptr, ptr %t6755
  %t6757 = call ptr @ptr_to_node(ptr %t6756)
  %t6758 = call ptr @sema_annotation_type__Struct_ASTNode_Struct_ASTNode(ptr %t6753, ptr %t6757)
  ret ptr %t6758
label_2075:
  %t6759 = load ptr, ptr %field
  %t6760 = getelementptr inbounds %ASTNode, ptr %t6759, i32 0, i32 8
  %t6761 = load ptr, ptr %t6760
  store ptr %t6761, ptr %field_ptr
  br label %label_2070
label_2072:
  br label %label_2069
label_2069:
  %t6762 = load ptr, ptr %stmt
  %t6763 = getelementptr inbounds %ASTNode, ptr %t6762, i32 0, i32 8
  %t6764 = load ptr, ptr %t6763
  store ptr %t6764, ptr %stmt_ptr
  br label %label_2064
label_2066:
  %t6765 = getelementptr inbounds [15 x i8], ptr @.str.s865, i64 0, i64 0
  %t6766 = load ptr, ptr %field_name
  %t6767 = call ptr @str_concat(ptr %t6765, ptr %t6766)
  %t6768 = getelementptr inbounds [5 x i8], ptr @.str.s866, i64 0, i64 0
  %t6769 = load ptr, ptr %struct_name
  %t6770 = call ptr @str_concat(ptr %t6768, ptr %t6769)
  %t6771 = call ptr @str_concat(ptr %t6767, ptr %t6770)
  call void @sema_error__String(ptr %t6771)
  %t6772 = call ptr @type_invalid__Void()
  ret ptr %t6772
}

define i1 @sema_enum_has_variant__Struct_ASTNode_String_String(ptr %p_module, ptr %p_enum_name, ptr %p_variant_name) {
  %module = alloca ptr
  %enum_name = alloca ptr
  %variant_name = alloca ptr
  %stmt_ptr = alloca ptr
  %stmt = alloca ptr
  %variant_ptr = alloca ptr
  %variant = alloca ptr
  store ptr %p_module, ptr %module
  store ptr %p_enum_name, ptr %enum_name
  store ptr %p_variant_name, ptr %variant_name
  %t6780 = load ptr, ptr %module
  %t6781 = getelementptr inbounds %ASTNode, ptr %t6780, i32 0, i32 5
  %t6782 = load ptr, ptr %t6781
  store ptr %t6782, ptr %stmt_ptr
  br label %label_2076
label_2076:
  %t6783 = load ptr, ptr %stmt_ptr
  %t6784 = getelementptr inbounds [1 x i8], ptr @.str.s867, i64 0, i64 0
  %t6785 = call i32 @str_equals(ptr %t6783, ptr %t6784)
  %t6786 = icmp eq i32 %t6785, 0
  br i1 %t6786, label %label_2077, label %label_2078
label_2077:
  %t6787 = load ptr, ptr %stmt_ptr
  %t6788 = call ptr @ptr_to_node(ptr %t6787)
  store ptr %t6788, ptr %stmt
  %t6789 = load ptr, ptr %stmt
  %t6790 = getelementptr inbounds %ASTNode, ptr %t6789, i32 0, i32 0
  %t6791 = load i32, ptr %t6790
  %t6792 = icmp eq i32 %t6791, 6
  %t6793 = load ptr, ptr %stmt
  %t6794 = getelementptr inbounds %ASTNode, ptr %t6793, i32 0, i32 1
  %t6795 = load ptr, ptr %t6794
  %t6796 = load ptr, ptr %enum_name
  %t6797 = call i32 @str_equals(ptr %t6795, ptr %t6796)
  %t6798 = icmp eq i32 %t6797, 1
  %t6799 = and i1 %t6792, %t6798
  br i1 %t6799, label %label_2079, label %label_2081
label_2079:
  %t6800 = load ptr, ptr %stmt
  %t6801 = getelementptr inbounds %ASTNode, ptr %t6800, i32 0, i32 5
  %t6802 = load ptr, ptr %t6801
  store ptr %t6802, ptr %variant_ptr
  br label %label_2082
label_2082:
  %t6803 = load ptr, ptr %variant_ptr
  %t6804 = getelementptr inbounds [1 x i8], ptr @.str.s868, i64 0, i64 0
  %t6805 = call i32 @str_equals(ptr %t6803, ptr %t6804)
  %t6806 = icmp eq i32 %t6805, 0
  br i1 %t6806, label %label_2083, label %label_2084
label_2083:
  %t6807 = load ptr, ptr %variant_ptr
  %t6808 = call ptr @ptr_to_node(ptr %t6807)
  store ptr %t6808, ptr %variant
  %t6809 = load ptr, ptr %variant
  %t6810 = getelementptr inbounds %ASTNode, ptr %t6809, i32 0, i32 1
  %t6811 = load ptr, ptr %t6810
  %t6812 = load ptr, ptr %variant_name
  %t6813 = call i32 @str_equals(ptr %t6811, ptr %t6812)
  %t6814 = icmp eq i32 %t6813, 1
  br i1 %t6814, label %label_2085, label %label_2087
label_2085:
  ret i1 1
label_2087:
  %t6815 = load ptr, ptr %variant
  %t6816 = getelementptr inbounds %ASTNode, ptr %t6815, i32 0, i32 8
  %t6817 = load ptr, ptr %t6816
  store ptr %t6817, ptr %variant_ptr
  br label %label_2082
label_2084:
  br label %label_2081
label_2081:
  %t6818 = load ptr, ptr %stmt
  %t6819 = getelementptr inbounds %ASTNode, ptr %t6818, i32 0, i32 8
  %t6820 = load ptr, ptr %t6819
  store ptr %t6820, ptr %stmt_ptr
  br label %label_2076
label_2078:
  ret i1 0
}

define ptr @sema_builtin_call_type__String_String(ptr %p_name, ptr %p_arg_ptr) {
  %name = alloca ptr
  %arg_ptr = alloca ptr
  %lt = alloca ptr
  store ptr %p_name, ptr %name
  store ptr %p_arg_ptr, ptr %arg_ptr
  %t6824 = load ptr, ptr %name
  %t6825 = getelementptr inbounds [6 x i8], ptr @.str.s869, i64 0, i64 0
  %t6826 = call i32 @str_equals(ptr %t6824, ptr %t6825)
  %t6827 = icmp eq i32 %t6826, 1
  %t6828 = load ptr, ptr %name
  %t6829 = getelementptr inbounds [8 x i8], ptr @.str.s870, i64 0, i64 0
  %t6830 = call i32 @str_equals(ptr %t6828, ptr %t6829)
  %t6831 = icmp eq i32 %t6830, 1
  %t6832 = or i1 %t6827, %t6831
  br i1 %t6832, label %label_2088, label %label_2090
label_2088:
  %t6833 = load ptr, ptr %arg_ptr
  %t6834 = getelementptr inbounds [1 x i8], ptr @.str.s871, i64 0, i64 0
  %t6835 = call i32 @str_equals(ptr %t6833, ptr %t6834)
  %t6836 = icmp eq i32 %t6835, 1
  br i1 %t6836, label %label_2091, label %label_2093
label_2091:
  %t6837 = load ptr, ptr %name
  %t6838 = getelementptr inbounds [22 x i8], ptr @.str.s872, i64 0, i64 0
  %t6839 = call ptr @str_concat(ptr %t6837, ptr %t6838)
  call void @sema_error__String(ptr %t6839)
  br label %label_2093
label_2093:
  %t6840 = call ptr @type_void__Void()
  ret ptr %t6840
label_2090:
  %t6841 = load ptr, ptr %name
  %t6842 = getelementptr inbounds [10 x i8], ptr @.str.s873, i64 0, i64 0
  %t6843 = call i32 @str_equals(ptr %t6841, ptr %t6842)
  %t6844 = icmp eq i32 %t6843, 1
  %t6845 = load ptr, ptr %name
  %t6846 = getelementptr inbounds [12 x i8], ptr @.str.s874, i64 0, i64 0
  %t6847 = call i32 @str_equals(ptr %t6845, ptr %t6846)
  %t6848 = icmp eq i32 %t6847, 1
  %t6849 = or i1 %t6844, %t6848
  br i1 %t6849, label %label_2094, label %label_2096
label_2094:
  %t6850 = call ptr @type_void__Void()
  ret ptr %t6850
label_2096:
  %t6851 = load ptr, ptr %name
  %t6852 = getelementptr inbounds [12 x i8], ptr @.str.s875, i64 0, i64 0
  %t6853 = call i32 @str_equals(ptr %t6851, ptr %t6852)
  %t6854 = icmp eq i32 %t6853, 1
  %t6855 = load ptr, ptr %name
  %t6856 = getelementptr inbounds [14 x i8], ptr @.str.s876, i64 0, i64 0
  %t6857 = call i32 @str_equals(ptr %t6855, ptr %t6856)
  %t6858 = icmp eq i32 %t6857, 1
  %t6859 = or i1 %t6854, %t6858
  br i1 %t6859, label %label_2097, label %label_2099
label_2097:
  %t6860 = call ptr @type_void__Void()
  ret ptr %t6860
label_2099:
  %t6861 = load ptr, ptr %name
  %t6862 = getelementptr inbounds [11 x i8], ptr @.str.s877, i64 0, i64 0
  %t6863 = call i32 @str_equals(ptr %t6861, ptr %t6862)
  %t6864 = icmp eq i32 %t6863, 1
  %t6865 = load ptr, ptr %name
  %t6866 = getelementptr inbounds [13 x i8], ptr @.str.s878, i64 0, i64 0
  %t6867 = call i32 @str_equals(ptr %t6865, ptr %t6866)
  %t6868 = icmp eq i32 %t6867, 1
  %t6869 = or i1 %t6864, %t6868
  br i1 %t6869, label %label_2100, label %label_2102
label_2100:
  %t6870 = call ptr @type_void__Void()
  ret ptr %t6870
label_2102:
  %t6871 = load ptr, ptr %name
  %t6872 = getelementptr inbounds [11 x i8], ptr @.str.s879, i64 0, i64 0
  %t6873 = call i32 @str_equals(ptr %t6871, ptr %t6872)
  %t6874 = icmp eq i32 %t6873, 1
  %t6875 = load ptr, ptr %name
  %t6876 = getelementptr inbounds [13 x i8], ptr @.str.s880, i64 0, i64 0
  %t6877 = call i32 @str_equals(ptr %t6875, ptr %t6876)
  %t6878 = icmp eq i32 %t6877, 1
  %t6879 = or i1 %t6874, %t6878
  br i1 %t6879, label %label_2103, label %label_2105
label_2103:
  %t6880 = call ptr @type_void__Void()
  ret ptr %t6880
label_2105:
  %t6881 = load ptr, ptr %name
  %t6882 = getelementptr inbounds [5 x i8], ptr @.str.s881, i64 0, i64 0
  %t6883 = call i32 @str_equals(ptr %t6881, ptr %t6882)
  %t6884 = icmp eq i32 %t6883, 1
  br i1 %t6884, label %label_2106, label %label_2108
label_2106:
  %t6885 = call ptr @type_void__Void()
  ret ptr %t6885
label_2108:
  %t6886 = load ptr, ptr %name
  %t6887 = getelementptr inbounds [9 x i8], ptr @.str.s882, i64 0, i64 0
  %t6888 = call i32 @str_equals(ptr %t6886, ptr %t6887)
  %t6889 = icmp eq i32 %t6888, 1
  br i1 %t6889, label %label_2109, label %label_2111
label_2109:
  %t6890 = call ptr @type_invalid__Void()
  %t6891 = call ptr @type_list__Struct_TypeInfo(ptr %t6890)
  ret ptr %t6891
label_2111:
  %t6892 = load ptr, ptr %name
  %t6893 = getelementptr inbounds [9 x i8], ptr @.str.s883, i64 0, i64 0
  %t6894 = call i32 @str_equals(ptr %t6892, ptr %t6893)
  %t6895 = icmp eq i32 %t6894, 1
  br i1 %t6895, label %label_2112, label %label_2114
label_2112:
  %t6896 = call ptr @type_int__Void()
  ret ptr %t6896
label_2114:
  %t6897 = load ptr, ptr %name
  %t6898 = getelementptr inbounds [10 x i8], ptr @.str.s884, i64 0, i64 0
  %t6899 = call i32 @str_equals(ptr %t6897, ptr %t6898)
  %t6900 = icmp eq i32 %t6899, 1
  br i1 %t6900, label %label_2115, label %label_2117
label_2115:
  %t6901 = call ptr @type_void__Void()
  ret ptr %t6901
label_2117:
  %t6902 = load ptr, ptr %name
  %t6903 = getelementptr inbounds [9 x i8], ptr @.str.s885, i64 0, i64 0
  %t6904 = call i32 @str_equals(ptr %t6902, ptr %t6903)
  %t6905 = icmp eq i32 %t6904, 1
  br i1 %t6905, label %label_2118, label %label_2120
label_2118:
  %t6906 = call ptr @type_void__Void()
  ret ptr %t6906
label_2120:
  %t6907 = load ptr, ptr %name
  %t6908 = getelementptr inbounds [9 x i8], ptr @.str.s886, i64 0, i64 0
  %t6909 = call i32 @str_equals(ptr %t6907, ptr %t6908)
  %t6910 = icmp eq i32 %t6909, 1
  br i1 %t6910, label %label_2121, label %label_2123
label_2121:
  %t6911 = load ptr, ptr %arg_ptr
  %t6912 = getelementptr inbounds [1 x i8], ptr @.str.s887, i64 0, i64 0
  %t6913 = call i32 @str_equals(ptr %t6911, ptr %t6912)
  %t6914 = icmp eq i32 %t6913, 0
  br i1 %t6914, label %label_2124, label %label_2126
label_2124:
  %t6915 = load ptr, ptr %arg_ptr
  %t6916 = call ptr @ptr_to_node(ptr %t6915)
  %t6917 = call ptr @node_get_type__Struct_ASTNode(ptr %t6916)
  store ptr %t6917, ptr %lt
  %t6918 = load ptr, ptr %lt
  %t6919 = getelementptr inbounds %TypeInfo, ptr %t6918, i32 0, i32 0
  %t6920 = load i32, ptr %t6919
  %t6921 = icmp eq i32 %t6920, 11
  %t6922 = load ptr, ptr %lt
  %t6923 = getelementptr inbounds %TypeInfo, ptr %t6922, i32 0, i32 3
  %t6924 = load ptr, ptr %t6923
  %t6925 = getelementptr inbounds [1 x i8], ptr @.str.s888, i64 0, i64 0
  %t6926 = call i32 @str_equals(ptr %t6924, ptr %t6925)
  %t6927 = icmp eq i32 %t6926, 0
  %t6928 = and i1 %t6921, %t6927
  br i1 %t6928, label %label_2127, label %label_2129
label_2127:
  %t6929 = load ptr, ptr %lt
  %t6930 = getelementptr inbounds %TypeInfo, ptr %t6929, i32 0, i32 3
  %t6931 = load ptr, ptr %t6930
  %t6932 = call ptr @ptr_to_type(ptr %t6931)
  ret ptr %t6932
label_2129:
  br label %label_2126
label_2126:
  %t6933 = call ptr @type_invalid__Void()
  ret ptr %t6933
label_2123:
  %t6934 = call ptr @type_invalid__Void()
  ret ptr %t6934
}

define i1 @sema_check_builtin_call__Struct_ASTNode_String_String(ptr %p_module, ptr %p_name, ptr %p_arg_ptr) {
  %module = alloca ptr
  %name = alloca ptr
  %arg_ptr = alloca ptr
  %arg = alloca ptr
  %t = alloca ptr
  %lt = alloca ptr
  %a0 = alloca ptr
  %a1 = alloca ptr
  %expected = alloca ptr
  %actual = alloca ptr
  store ptr %p_module, ptr %module
  store ptr %p_name, ptr %name
  store ptr %p_arg_ptr, ptr %arg_ptr
  %t6945 = load ptr, ptr %name
  %t6946 = getelementptr inbounds [6 x i8], ptr @.str.s889, i64 0, i64 0
  %t6947 = call i32 @str_equals(ptr %t6945, ptr %t6946)
  %t6948 = icmp eq i32 %t6947, 1
  %t6949 = load ptr, ptr %name
  %t6950 = getelementptr inbounds [8 x i8], ptr @.str.s890, i64 0, i64 0
  %t6951 = call i32 @str_equals(ptr %t6949, ptr %t6950)
  %t6952 = icmp eq i32 %t6951, 1
  %t6953 = or i1 %t6948, %t6952
  br i1 %t6953, label %label_2130, label %label_2132
label_2130:
  %t6954 = load ptr, ptr %arg_ptr
  %t6955 = getelementptr inbounds [1 x i8], ptr @.str.s891, i64 0, i64 0
  %t6956 = call i32 @str_equals(ptr %t6954, ptr %t6955)
  %t6957 = icmp eq i32 %t6956, 1
  %t6958 = load ptr, ptr %arg_ptr
  %t6959 = call ptr @ptr_to_node(ptr %t6958)
  %t6960 = getelementptr inbounds %ASTNode, ptr %t6959, i32 0, i32 8
  %t6961 = load ptr, ptr %t6960
  %t6962 = getelementptr inbounds [1 x i8], ptr @.str.s892, i64 0, i64 0
  %t6963 = call i32 @str_equals(ptr %t6961, ptr %t6962)
  %t6964 = icmp eq i32 %t6963, 0
  %t6965 = or i1 %t6957, %t6964
  br i1 %t6965, label %label_2133, label %label_2135
label_2133:
  %t6966 = load ptr, ptr %name
  %t6967 = getelementptr inbounds [22 x i8], ptr @.str.s893, i64 0, i64 0
  %t6968 = call ptr @str_concat(ptr %t6966, ptr %t6967)
  call void @sema_error__String(ptr %t6968)
  br label %label_2135
label_2135:
  %t6969 = load ptr, ptr %module
  %t6970 = load ptr, ptr %arg_ptr
  %t6971 = call ptr @ptr_to_node(ptr %t6970)
  %t6972 = call ptr @sema_expr__Struct_ASTNode_Struct_ASTNode(ptr %t6969, ptr %t6971)
  ret i1 1
label_2132:
  %t6973 = load ptr, ptr %name
  %t6974 = getelementptr inbounds [5 x i8], ptr @.str.s894, i64 0, i64 0
  %t6975 = call i32 @str_equals(ptr %t6973, ptr %t6974)
  %t6976 = icmp eq i32 %t6975, 1
  br i1 %t6976, label %label_2136, label %label_2138
label_2136:
  %t6977 = load ptr, ptr %arg_ptr
  %t6978 = getelementptr inbounds [1 x i8], ptr @.str.s895, i64 0, i64 0
  %t6979 = call i32 @str_equals(ptr %t6977, ptr %t6978)
  %t6980 = icmp eq i32 %t6979, 1
  %t6981 = load ptr, ptr %arg_ptr
  %t6982 = call ptr @ptr_to_node(ptr %t6981)
  %t6983 = getelementptr inbounds %ASTNode, ptr %t6982, i32 0, i32 8
  %t6984 = load ptr, ptr %t6983
  %t6985 = getelementptr inbounds [1 x i8], ptr @.str.s896, i64 0, i64 0
  %t6986 = call i32 @str_equals(ptr %t6984, ptr %t6985)
  %t6987 = icmp eq i32 %t6986, 0
  %t6988 = or i1 %t6980, %t6987
  br i1 %t6988, label %label_2139, label %label_2141
label_2139:
  %t6989 = getelementptr inbounds [26 x i8], ptr @.str.s897, i64 0, i64 0
  call void @sema_error__String(ptr %t6989)
  br label %label_2141
label_2141:
  %t6990 = load ptr, ptr %arg_ptr
  %t6991 = call ptr @ptr_to_node(ptr %t6990)
  store ptr %t6991, ptr %arg
  %t6992 = load ptr, ptr %module
  %t6993 = load ptr, ptr %arg
  %t6994 = call ptr @sema_expr__Struct_ASTNode_Struct_ASTNode(ptr %t6992, ptr %t6993)
  store ptr %t6994, ptr %t
  %t6995 = load ptr, ptr %t
  %t6996 = call i1 @type_is_move_only__Struct_TypeInfo(ptr %t6995)
  %t6997 = icmp eq i1 %t6996, 0
  br i1 %t6997, label %label_2142, label %label_2144
label_2142:
  %t6998 = getelementptr inbounds [41 x i8], ptr @.str.s898, i64 0, i64 0
  call void @sema_error__String(ptr %t6998)
  br label %label_2144
label_2144:
  %t6999 = load ptr, ptr %arg
  call void @sema_move_operand__Struct_ASTNode(ptr %t6999)
  ret i1 1
label_2138:
  %t7000 = load ptr, ptr %name
  %t7001 = getelementptr inbounds [9 x i8], ptr @.str.s899, i64 0, i64 0
  %t7002 = call i32 @str_equals(ptr %t7000, ptr %t7001)
  %t7003 = icmp eq i32 %t7002, 1
  br i1 %t7003, label %label_2145, label %label_2147
label_2145:
  %t7004 = load ptr, ptr %arg_ptr
  %t7005 = getelementptr inbounds [1 x i8], ptr @.str.s900, i64 0, i64 0
  %t7006 = call i32 @str_equals(ptr %t7004, ptr %t7005)
  %t7007 = icmp eq i32 %t7006, 0
  br i1 %t7007, label %label_2148, label %label_2150
label_2148:
  %t7008 = getelementptr inbounds [28 x i8], ptr @.str.s901, i64 0, i64 0
  call void @sema_error__String(ptr %t7008)
  br label %label_2150
label_2150:
  ret i1 1
label_2147:
  %t7009 = load ptr, ptr %name
  %t7010 = getelementptr inbounds [9 x i8], ptr @.str.s902, i64 0, i64 0
  %t7011 = call i32 @str_equals(ptr %t7009, ptr %t7010)
  %t7012 = icmp eq i32 %t7011, 1
  br i1 %t7012, label %label_2151, label %label_2153
label_2151:
  %t7013 = load ptr, ptr %arg_ptr
  %t7014 = getelementptr inbounds [1 x i8], ptr @.str.s903, i64 0, i64 0
  %t7015 = call i32 @str_equals(ptr %t7013, ptr %t7014)
  %t7016 = icmp eq i32 %t7015, 1
  br i1 %t7016, label %label_2154, label %label_2156
label_2154:
  %t7017 = getelementptr inbounds [24 x i8], ptr @.str.s904, i64 0, i64 0
  call void @sema_error__String(ptr %t7017)
  br label %label_2156
label_2156:
  %t7018 = load ptr, ptr %module
  %t7019 = load ptr, ptr %arg_ptr
  %t7020 = call ptr @ptr_to_node(ptr %t7019)
  %t7021 = call ptr @sema_expr__Struct_ASTNode_Struct_ASTNode(ptr %t7018, ptr %t7020)
  store ptr %t7021, ptr %lt
  %t7022 = load ptr, ptr %lt
  %t7023 = getelementptr inbounds %TypeInfo, ptr %t7022, i32 0, i32 0
  %t7024 = load i32, ptr %t7023
  %t7025 = icmp ne i32 %t7024, 11
  br i1 %t7025, label %label_2157, label %label_2159
label_2157:
  %t7026 = getelementptr inbounds [24 x i8], ptr @.str.s905, i64 0, i64 0
  call void @sema_error__String(ptr %t7026)
  br label %label_2159
label_2159:
  ret i1 1
label_2153:
  %t7027 = load ptr, ptr %name
  %t7028 = getelementptr inbounds [9 x i8], ptr @.str.s906, i64 0, i64 0
  %t7029 = call i32 @str_equals(ptr %t7027, ptr %t7028)
  %t7030 = icmp eq i32 %t7029, 1
  br i1 %t7030, label %label_2160, label %label_2162
label_2160:
  %t7031 = load ptr, ptr %arg_ptr
  %t7032 = call ptr @ptr_to_node(ptr %t7031)
  store ptr %t7032, ptr %a0
  %t7033 = load ptr, ptr %module
  %t7034 = load ptr, ptr %a0
  %t7035 = call ptr @sema_expr__Struct_ASTNode_Struct_ASTNode(ptr %t7033, ptr %t7034)
  store ptr %t7035, ptr %lt
  %t7036 = load ptr, ptr %lt
  %t7037 = getelementptr inbounds %TypeInfo, ptr %t7036, i32 0, i32 0
  %t7038 = load i32, ptr %t7037
  %t7039 = icmp ne i32 %t7038, 11
  br i1 %t7039, label %label_2163, label %label_2165
label_2163:
  %t7040 = getelementptr inbounds [24 x i8], ptr @.str.s907, i64 0, i64 0
  call void @sema_error__String(ptr %t7040)
  br label %label_2165
label_2165:
  %t7041 = load ptr, ptr %module
  %t7042 = load ptr, ptr %a0
  %t7043 = getelementptr inbounds %ASTNode, ptr %t7042, i32 0, i32 8
  %t7044 = load ptr, ptr %t7043
  %t7045 = call ptr @ptr_to_node(ptr %t7044)
  %t7046 = call ptr @type_int__Void()
  %t7047 = getelementptr inbounds [15 x i8], ptr @.str.s908, i64 0, i64 0
  %t7048 = call ptr @sema_check_value__Struct_ASTNode_Struct_ASTNode_Struct_TypeInfo_String(ptr %t7041, ptr %t7045, ptr %t7046, ptr %t7047)
  ret i1 1
label_2162:
  %t7049 = load ptr, ptr %name
  %t7050 = getelementptr inbounds [10 x i8], ptr @.str.s909, i64 0, i64 0
  %t7051 = call i32 @str_equals(ptr %t7049, ptr %t7050)
  %t7052 = icmp eq i32 %t7051, 1
  br i1 %t7052, label %label_2166, label %label_2168
label_2166:
  %t7053 = load ptr, ptr %arg_ptr
  %t7054 = call ptr @ptr_to_node(ptr %t7053)
  store ptr %t7054, ptr %a0
  %t7055 = load ptr, ptr %module
  %t7056 = load ptr, ptr %a0
  %t7057 = call ptr @sema_expr__Struct_ASTNode_Struct_ASTNode(ptr %t7055, ptr %t7056)
  store ptr %t7057, ptr %lt
  %t7058 = load ptr, ptr %lt
  %t7059 = getelementptr inbounds %TypeInfo, ptr %t7058, i32 0, i32 0
  %t7060 = load i32, ptr %t7059
  %t7061 = icmp ne i32 %t7060, 11
  br i1 %t7061, label %label_2169, label %label_2171
label_2169:
  %t7062 = getelementptr inbounds [25 x i8], ptr @.str.s910, i64 0, i64 0
  call void @sema_error__String(ptr %t7062)
  br label %label_2171
label_2171:
  %t7063 = load ptr, ptr %module
  %t7064 = load ptr, ptr %a0
  %t7065 = getelementptr inbounds %ASTNode, ptr %t7064, i32 0, i32 8
  %t7066 = load ptr, ptr %t7065
  %t7067 = call ptr @ptr_to_node(ptr %t7066)
  %t7068 = load ptr, ptr %lt
  %t7069 = getelementptr inbounds %TypeInfo, ptr %t7068, i32 0, i32 3
  %t7070 = load ptr, ptr %t7069
  %t7071 = call ptr @ptr_to_type(ptr %t7070)
  %t7072 = getelementptr inbounds [16 x i8], ptr @.str.s911, i64 0, i64 0
  %t7073 = call ptr @sema_check_value__Struct_ASTNode_Struct_ASTNode_Struct_TypeInfo_String(ptr %t7063, ptr %t7067, ptr %t7071, ptr %t7072)
  ret i1 1
label_2168:
  %t7074 = load ptr, ptr %name
  %t7075 = getelementptr inbounds [9 x i8], ptr @.str.s912, i64 0, i64 0
  %t7076 = call i32 @str_equals(ptr %t7074, ptr %t7075)
  %t7077 = icmp eq i32 %t7076, 1
  br i1 %t7077, label %label_2172, label %label_2174
label_2172:
  %t7078 = load ptr, ptr %arg_ptr
  %t7079 = call ptr @ptr_to_node(ptr %t7078)
  store ptr %t7079, ptr %a0
  %t7080 = load ptr, ptr %module
  %t7081 = load ptr, ptr %a0
  %t7082 = call ptr @sema_expr__Struct_ASTNode_Struct_ASTNode(ptr %t7080, ptr %t7081)
  store ptr %t7082, ptr %lt
  %t7083 = load ptr, ptr %lt
  %t7084 = getelementptr inbounds %TypeInfo, ptr %t7083, i32 0, i32 0
  %t7085 = load i32, ptr %t7084
  %t7086 = icmp ne i32 %t7085, 11
  br i1 %t7086, label %label_2175, label %label_2177
label_2175:
  %t7087 = getelementptr inbounds [24 x i8], ptr @.str.s913, i64 0, i64 0
  call void @sema_error__String(ptr %t7087)
  br label %label_2177
label_2177:
  %t7088 = load ptr, ptr %a0
  %t7089 = getelementptr inbounds %ASTNode, ptr %t7088, i32 0, i32 8
  %t7090 = load ptr, ptr %t7089
  %t7091 = call ptr @ptr_to_node(ptr %t7090)
  store ptr %t7091, ptr %a1
  %t7092 = load ptr, ptr %module
  %t7093 = load ptr, ptr %a1
  %t7094 = call ptr @type_int__Void()
  %t7095 = getelementptr inbounds [15 x i8], ptr @.str.s914, i64 0, i64 0
  %t7096 = call ptr @sema_check_value__Struct_ASTNode_Struct_ASTNode_Struct_TypeInfo_String(ptr %t7092, ptr %t7093, ptr %t7094, ptr %t7095)
  %t7097 = load ptr, ptr %module
  %t7098 = load ptr, ptr %a1
  %t7099 = getelementptr inbounds %ASTNode, ptr %t7098, i32 0, i32 8
  %t7100 = load ptr, ptr %t7099
  %t7101 = call ptr @ptr_to_node(ptr %t7100)
  %t7102 = load ptr, ptr %lt
  %t7103 = getelementptr inbounds %TypeInfo, ptr %t7102, i32 0, i32 3
  %t7104 = load ptr, ptr %t7103
  %t7105 = call ptr @ptr_to_type(ptr %t7104)
  %t7106 = getelementptr inbounds [15 x i8], ptr @.str.s915, i64 0, i64 0
  %t7107 = call ptr @sema_check_value__Struct_ASTNode_Struct_ASTNode_Struct_TypeInfo_String(ptr %t7097, ptr %t7101, ptr %t7105, ptr %t7106)
  ret i1 1
label_2174:
  %t7108 = call ptr @type_invalid__Void()
  store ptr %t7108, ptr %expected
  %t7109 = load ptr, ptr %name
  %t7110 = getelementptr inbounds [10 x i8], ptr @.str.s916, i64 0, i64 0
  %t7111 = call i32 @str_equals(ptr %t7109, ptr %t7110)
  %t7112 = icmp eq i32 %t7111, 1
  %t7113 = load ptr, ptr %name
  %t7114 = getelementptr inbounds [12 x i8], ptr @.str.s917, i64 0, i64 0
  %t7115 = call i32 @str_equals(ptr %t7113, ptr %t7114)
  %t7116 = icmp eq i32 %t7115, 1
  %t7117 = or i1 %t7112, %t7116
  br i1 %t7117, label %label_2178, label %label_2180
label_2178:
  %t7118 = call ptr @type_int__Void()
  store ptr %t7118, ptr %expected
  br label %label_2180
label_2180:
  %t7119 = load ptr, ptr %name
  %t7120 = getelementptr inbounds [12 x i8], ptr @.str.s918, i64 0, i64 0
  %t7121 = call i32 @str_equals(ptr %t7119, ptr %t7120)
  %t7122 = icmp eq i32 %t7121, 1
  %t7123 = load ptr, ptr %name
  %t7124 = getelementptr inbounds [14 x i8], ptr @.str.s919, i64 0, i64 0
  %t7125 = call i32 @str_equals(ptr %t7123, ptr %t7124)
  %t7126 = icmp eq i32 %t7125, 1
  %t7127 = or i1 %t7122, %t7126
  br i1 %t7127, label %label_2181, label %label_2183
label_2181:
  %t7128 = call ptr @type_float__Void()
  store ptr %t7128, ptr %expected
  br label %label_2183
label_2183:
  %t7129 = load ptr, ptr %name
  %t7130 = getelementptr inbounds [11 x i8], ptr @.str.s920, i64 0, i64 0
  %t7131 = call i32 @str_equals(ptr %t7129, ptr %t7130)
  %t7132 = icmp eq i32 %t7131, 1
  %t7133 = load ptr, ptr %name
  %t7134 = getelementptr inbounds [13 x i8], ptr @.str.s921, i64 0, i64 0
  %t7135 = call i32 @str_equals(ptr %t7133, ptr %t7134)
  %t7136 = icmp eq i32 %t7135, 1
  %t7137 = or i1 %t7132, %t7136
  br i1 %t7137, label %label_2184, label %label_2186
label_2184:
  %t7138 = call ptr @type_bool__Void()
  store ptr %t7138, ptr %expected
  br label %label_2186
label_2186:
  %t7139 = load ptr, ptr %name
  %t7140 = getelementptr inbounds [11 x i8], ptr @.str.s922, i64 0, i64 0
  %t7141 = call i32 @str_equals(ptr %t7139, ptr %t7140)
  %t7142 = icmp eq i32 %t7141, 1
  %t7143 = load ptr, ptr %name
  %t7144 = getelementptr inbounds [13 x i8], ptr @.str.s923, i64 0, i64 0
  %t7145 = call i32 @str_equals(ptr %t7143, ptr %t7144)
  %t7146 = icmp eq i32 %t7145, 1
  %t7147 = or i1 %t7142, %t7146
  br i1 %t7147, label %label_2187, label %label_2189
label_2187:
  %t7148 = call ptr @type_char__Void()
  store ptr %t7148, ptr %expected
  br label %label_2189
label_2189:
  %t7149 = load ptr, ptr %expected
  %t7150 = call i1 @type_is_valid__Struct_TypeInfo(ptr %t7149)
  br i1 %t7150, label %label_2190, label %label_2192
label_2190:
  %t7151 = load ptr, ptr %arg_ptr
  %t7152 = getelementptr inbounds [1 x i8], ptr @.str.s924, i64 0, i64 0
  %t7153 = call i32 @str_equals(ptr %t7151, ptr %t7152)
  %t7154 = icmp eq i32 %t7153, 1
  %t7155 = load ptr, ptr %arg_ptr
  %t7156 = call ptr @ptr_to_node(ptr %t7155)
  %t7157 = getelementptr inbounds %ASTNode, ptr %t7156, i32 0, i32 8
  %t7158 = load ptr, ptr %t7157
  %t7159 = getelementptr inbounds [1 x i8], ptr @.str.s925, i64 0, i64 0
  %t7160 = call i32 @str_equals(ptr %t7158, ptr %t7159)
  %t7161 = icmp eq i32 %t7160, 0
  %t7162 = or i1 %t7154, %t7161
  br i1 %t7162, label %label_2193, label %label_2195
label_2193:
  %t7163 = load ptr, ptr %name
  %t7164 = getelementptr inbounds [22 x i8], ptr @.str.s926, i64 0, i64 0
  %t7165 = call ptr @str_concat(ptr %t7163, ptr %t7164)
  call void @sema_error__String(ptr %t7165)
  br label %label_2195
label_2195:
  %t7166 = load ptr, ptr %module
  %t7167 = load ptr, ptr %arg_ptr
  %t7168 = call ptr @ptr_to_node(ptr %t7167)
  %t7169 = call ptr @sema_expr__Struct_ASTNode_Struct_ASTNode(ptr %t7166, ptr %t7168)
  store ptr %t7169, ptr %actual
  %t7170 = load ptr, ptr %name
  %t7171 = getelementptr inbounds [10 x i8], ptr @.str.s927, i64 0, i64 0
  %t7172 = call ptr @str_concat(ptr %t7170, ptr %t7171)
  %t7173 = load ptr, ptr %expected
  %t7174 = load ptr, ptr %actual
  call void @sema_expect_assignable__String_Struct_TypeInfo_Struct_TypeInfo(ptr %t7172, ptr %t7173, ptr %t7174)
  ret i1 1
label_2192:
  ret i1 0
}

define ptr @sema_expr__Struct_ASTNode_Struct_ASTNode(ptr %p_module, ptr %p_expr) {
  %module = alloca ptr
  %expr = alloca ptr
  %t = alloca ptr
  %left_node = alloca ptr
  %right_node = alloca ptr
  %left_t = alloca ptr
  %right_t = alloca ptr
  %op = alloca ptr
  %callee = alloca ptr
  %name = alloca ptr
  %builtin_t = alloca ptr
  %fn_node = alloca ptr
  %arg_ptr = alloca ptr
  %param_ptr = alloca ptr
  %arg_node = alloca ptr
  %param_node = alloca ptr
  %param_t = alloca ptr
  %ret_t = alloca ptr
  %object_node = alloca ptr
  %object_t = alloca ptr
  %field_t = alloca ptr
  %elem_ptr = alloca ptr
  %arr_t = alloca ptr
  %first_t = alloca ptr
  %elem = alloca ptr
  %elem_t = alloca ptr
  %arr_t2 = alloca ptr
  %array_t = alloca ptr
  %index_t = alloca ptr
  %field_ptr = alloca ptr
  %field = alloca ptr
  %expected = alloca ptr
  %struct_t = alloca ptr
  store ptr %p_module, ptr %module
  store ptr %p_expr, ptr %expr
  %t7208 = load ptr, ptr %expr
  %t7209 = call i1 @node_has_type__Struct_ASTNode(ptr %t7208)
  br i1 %t7209, label %label_2196, label %label_2198
label_2196:
  %t7210 = load ptr, ptr %expr
  %t7211 = call ptr @node_get_type__Struct_ASTNode(ptr %t7210)
  ret ptr %t7211
label_2198:
  %t7212 = load ptr, ptr %expr
  %t7213 = getelementptr inbounds %ASTNode, ptr %t7212, i32 0, i32 0
  %t7214 = load i32, ptr %t7213
  %t7215 = icmp eq i32 %t7214, 22
  br i1 %t7215, label %label_2199, label %label_2201
label_2199:
  %t7216 = call ptr @type_invalid__Void()
  store ptr %t7216, ptr %t
  %t7217 = load ptr, ptr %expr
  %t7218 = getelementptr inbounds %ASTNode, ptr %t7217, i32 0, i32 3
  %t7219 = load i32, ptr %t7218
  %t7220 = icmp eq i32 %t7219, 2
  br i1 %t7220, label %label_2202, label %label_2204
label_2202:
  %t7221 = call ptr @type_int__Void()
  store ptr %t7221, ptr %t
  br label %label_2204
label_2204:
  %t7222 = load ptr, ptr %expr
  %t7223 = getelementptr inbounds %ASTNode, ptr %t7222, i32 0, i32 3
  %t7224 = load i32, ptr %t7223
  %t7225 = icmp eq i32 %t7224, 3
  br i1 %t7225, label %label_2205, label %label_2207
label_2205:
  %t7226 = call ptr @type_float__Void()
  store ptr %t7226, ptr %t
  br label %label_2207
label_2207:
  %t7227 = load ptr, ptr %expr
  %t7228 = getelementptr inbounds %ASTNode, ptr %t7227, i32 0, i32 3
  %t7229 = load i32, ptr %t7228
  %t7230 = icmp eq i32 %t7229, 4
  br i1 %t7230, label %label_2208, label %label_2210
label_2208:
  %t7231 = call ptr @type_bool__Void()
  store ptr %t7231, ptr %t
  br label %label_2210
label_2210:
  %t7232 = load ptr, ptr %expr
  %t7233 = getelementptr inbounds %ASTNode, ptr %t7232, i32 0, i32 3
  %t7234 = load i32, ptr %t7233
  %t7235 = icmp eq i32 %t7234, 1
  br i1 %t7235, label %label_2211, label %label_2213
label_2211:
  %t7236 = call ptr @type_char__Void()
  store ptr %t7236, ptr %t
  br label %label_2213
label_2213:
  %t7237 = load ptr, ptr %expr
  %t7238 = getelementptr inbounds %ASTNode, ptr %t7237, i32 0, i32 3
  %t7239 = load i32, ptr %t7238
  %t7240 = icmp eq i32 %t7239, 0
  br i1 %t7240, label %label_2214, label %label_2216
label_2214:
  %t7241 = call ptr @type_string__Void()
  store ptr %t7241, ptr %t
  br label %label_2216
label_2216:
  %t7242 = load ptr, ptr %expr
  %t7243 = load ptr, ptr %t
  call void @node_set_type__Struct_ASTNode_Struct_TypeInfo(ptr %t7242, ptr %t7243)
  %t7244 = load ptr, ptr %t
  ret ptr %t7244
label_2201:
  %t7245 = load ptr, ptr %expr
  %t7246 = getelementptr inbounds %ASTNode, ptr %t7245, i32 0, i32 0
  %t7247 = load i32, ptr %t7246
  %t7248 = icmp eq i32 %t7247, 23
  br i1 %t7248, label %label_2217, label %label_2219
label_2217:
  %t7249 = load ptr, ptr %expr
  %t7250 = getelementptr inbounds %ASTNode, ptr %t7249, i32 0, i32 1
  %t7251 = load ptr, ptr %t7250
  %t7252 = call i32 @ir_has_var_type(ptr %t7251)
  %t7253 = icmp eq i32 %t7252, 0
  br i1 %t7253, label %label_2220, label %label_2222
label_2220:
  %t7254 = getelementptr inbounds [20 x i8], ptr @.str.s928, i64 0, i64 0
  %t7255 = load ptr, ptr %expr
  %t7256 = getelementptr inbounds %ASTNode, ptr %t7255, i32 0, i32 1
  %t7257 = load ptr, ptr %t7256
  %t7258 = call ptr @str_concat(ptr %t7254, ptr %t7257)
  call void @sema_error__String(ptr %t7258)
  br label %label_2222
label_2222:
  %t7259 = load ptr, ptr %expr
  %t7260 = getelementptr inbounds %ASTNode, ptr %t7259, i32 0, i32 1
  %t7261 = load ptr, ptr %t7260
  %t7262 = call i32 @ir_is_moved(ptr %t7261)
  %t7263 = icmp eq i32 %t7262, 1
  br i1 %t7263, label %label_2223, label %label_2225
label_2223:
  %t7264 = getelementptr inbounds [21 x i8], ptr @.str.s929, i64 0, i64 0
  %t7265 = load ptr, ptr %expr
  %t7266 = getelementptr inbounds %ASTNode, ptr %t7265, i32 0, i32 1
  %t7267 = load ptr, ptr %t7266
  %t7268 = call ptr @str_concat(ptr %t7264, ptr %t7267)
  call void @sema_error__String(ptr %t7268)
  br label %label_2225
label_2225:
  %t7269 = load ptr, ptr %expr
  %t7270 = getelementptr inbounds %ASTNode, ptr %t7269, i32 0, i32 1
  %t7271 = load ptr, ptr %t7270
  %t7272 = call ptr @ir_get_var_type(ptr %t7271)
  %t7273 = call ptr @type_from_sem_key__String(ptr %t7272)
  store ptr %t7273, ptr %t
  %t7274 = load ptr, ptr %expr
  %t7275 = load ptr, ptr %t
  call void @node_set_type__Struct_ASTNode_Struct_TypeInfo(ptr %t7274, ptr %t7275)
  %t7276 = load ptr, ptr %t
  ret ptr %t7276
label_2219:
  %t7277 = load ptr, ptr %expr
  %t7278 = getelementptr inbounds %ASTNode, ptr %t7277, i32 0, i32 0
  %t7279 = load i32, ptr %t7278
  %t7280 = icmp eq i32 %t7279, 20
  br i1 %t7280, label %label_2226, label %label_2228
label_2226:
  %t7281 = load ptr, ptr %expr
  %t7282 = getelementptr inbounds %ASTNode, ptr %t7281, i32 0, i32 5
  %t7283 = load ptr, ptr %t7282
  %t7284 = call ptr @ptr_to_node(ptr %t7283)
  store ptr %t7284, ptr %left_node
  %t7285 = load ptr, ptr %expr
  %t7286 = getelementptr inbounds %ASTNode, ptr %t7285, i32 0, i32 6
  %t7287 = load ptr, ptr %t7286
  %t7288 = call ptr @ptr_to_node(ptr %t7287)
  store ptr %t7288, ptr %right_node
  %t7289 = load ptr, ptr %module
  %t7290 = load ptr, ptr %left_node
  %t7291 = call ptr @sema_expr__Struct_ASTNode_Struct_ASTNode(ptr %t7289, ptr %t7290)
  store ptr %t7291, ptr %left_t
  %t7292 = load ptr, ptr %module
  %t7293 = load ptr, ptr %right_node
  %t7294 = call ptr @sema_expr__Struct_ASTNode_Struct_ASTNode(ptr %t7292, ptr %t7293)
  store ptr %t7294, ptr %right_t
  %t7295 = load ptr, ptr %left_t
  %t7296 = getelementptr inbounds %TypeInfo, ptr %t7295, i32 0, i32 0
  %t7297 = load i32, ptr %t7296
  %t7298 = icmp eq i32 %t7297, 2
  %t7299 = load ptr, ptr %right_t
  %t7300 = getelementptr inbounds %TypeInfo, ptr %t7299, i32 0, i32 0
  %t7301 = load i32, ptr %t7300
  %t7302 = icmp eq i32 %t7301, 2
  %t7303 = and i1 %t7298, %t7302
  %t7304 = load ptr, ptr %left_t
  %t7305 = load ptr, ptr %right_t
  %t7306 = call i1 @type_equals__Struct_TypeInfo_Struct_TypeInfo(ptr %t7304, ptr %t7305)
  %t7307 = icmp eq i1 %t7306, 0
  %t7308 = and i1 %t7303, %t7307
  br i1 %t7308, label %label_2229, label %label_2231
label_2229:
  %t7309 = load ptr, ptr %right_node
  %t7310 = call i1 @sema_is_int_literal__Struct_ASTNode(ptr %t7309)
  br i1 %t7310, label %label_2232, label %label_2233
label_2232:
  %t7311 = load ptr, ptr %right_node
  %t7312 = load ptr, ptr %left_t
  call void @node_set_type__Struct_ASTNode_Struct_TypeInfo(ptr %t7311, ptr %t7312)
  %t7313 = load ptr, ptr %left_t
  %t7314 = call ptr @type_copy__Struct_TypeInfo(ptr %t7313)
  store ptr %t7314, ptr %right_t
  br label %label_2234
label_2233:
  %t7315 = load ptr, ptr %left_node
  %t7316 = call i1 @sema_is_int_literal__Struct_ASTNode(ptr %t7315)
  br i1 %t7316, label %label_2235, label %label_2237
label_2235:
  %t7317 = load ptr, ptr %left_node
  %t7318 = load ptr, ptr %right_t
  call void @node_set_type__Struct_ASTNode_Struct_TypeInfo(ptr %t7317, ptr %t7318)
  %t7319 = load ptr, ptr %right_t
  %t7320 = call ptr @type_copy__Struct_TypeInfo(ptr %t7319)
  store ptr %t7320, ptr %left_t
  br label %label_2237
label_2237:
  br label %label_2234
label_2234:
  br label %label_2231
label_2231:
  %t7321 = load ptr, ptr %expr
  %t7322 = getelementptr inbounds %ASTNode, ptr %t7321, i32 0, i32 1
  %t7323 = load ptr, ptr %t7322
  store ptr %t7323, ptr %op
  %t7324 = load ptr, ptr %op
  %t7325 = getelementptr inbounds [4 x i8], ptr @.str.s930, i64 0, i64 0
  %t7326 = call i32 @str_equals(ptr %t7324, ptr %t7325)
  %t7327 = icmp eq i32 %t7326, 1
  %t7328 = load ptr, ptr %op
  %t7329 = getelementptr inbounds [3 x i8], ptr @.str.s931, i64 0, i64 0
  %t7330 = call i32 @str_equals(ptr %t7328, ptr %t7329)
  %t7331 = icmp eq i32 %t7330, 1
  %t7332 = or i1 %t7327, %t7331
  br i1 %t7332, label %label_2238, label %label_2240
label_2238:
  %t7333 = getelementptr inbounds [30 x i8], ptr @.str.s932, i64 0, i64 0
  %t7334 = call ptr @type_bool__Void()
  %t7335 = load ptr, ptr %left_t
  call void @sema_expect_assignable__String_Struct_TypeInfo_Struct_TypeInfo(ptr %t7333, ptr %t7334, ptr %t7335)
  %t7336 = getelementptr inbounds [31 x i8], ptr @.str.s933, i64 0, i64 0
  %t7337 = call ptr @type_bool__Void()
  %t7338 = load ptr, ptr %right_t
  call void @sema_expect_assignable__String_Struct_TypeInfo_Struct_TypeInfo(ptr %t7336, ptr %t7337, ptr %t7338)
  %t7339 = load ptr, ptr %expr
  %t7340 = call ptr @type_bool__Void()
  call void @node_set_type__Struct_ASTNode_Struct_TypeInfo(ptr %t7339, ptr %t7340)
  %t7341 = call ptr @type_bool__Void()
  ret ptr %t7341
label_2240:
  %t7342 = load ptr, ptr %op
  %t7343 = getelementptr inbounds [2 x i8], ptr @.str.s934, i64 0, i64 0
  %t7344 = call i32 @str_equals(ptr %t7342, ptr %t7343)
  %t7345 = icmp eq i32 %t7344, 1
  %t7346 = load ptr, ptr %op
  %t7347 = getelementptr inbounds [2 x i8], ptr @.str.s935, i64 0, i64 0
  %t7348 = call i32 @str_equals(ptr %t7346, ptr %t7347)
  %t7349 = icmp eq i32 %t7348, 1
  %t7350 = or i1 %t7345, %t7349
  %t7351 = load ptr, ptr %op
  %t7352 = getelementptr inbounds [2 x i8], ptr @.str.s936, i64 0, i64 0
  %t7353 = call i32 @str_equals(ptr %t7351, ptr %t7352)
  %t7354 = icmp eq i32 %t7353, 1
  %t7355 = or i1 %t7350, %t7354
  %t7356 = load ptr, ptr %op
  %t7357 = getelementptr inbounds [2 x i8], ptr @.str.s937, i64 0, i64 0
  %t7358 = call i32 @str_equals(ptr %t7356, ptr %t7357)
  %t7359 = icmp eq i32 %t7358, 1
  %t7360 = or i1 %t7355, %t7359
  br i1 %t7360, label %label_2241, label %label_2243
label_2241:
  %t7361 = load ptr, ptr %left_t
  %t7362 = call i1 @type_is_numeric__Struct_TypeInfo(ptr %t7361)
  %t7363 = icmp eq i1 %t7362, 0
  br i1 %t7363, label %label_2244, label %label_2246
label_2244:
  %t7364 = getelementptr inbounds [37 x i8], ptr @.str.s938, i64 0, i64 0
  %t7365 = load ptr, ptr %op
  %t7366 = call ptr @str_concat(ptr %t7364, ptr %t7365)
  call void @sema_error__String(ptr %t7366)
  br label %label_2246
label_2246:
  %t7367 = getelementptr inbounds [10 x i8], ptr @.str.s939, i64 0, i64 0
  %t7368 = load ptr, ptr %op
  %t7369 = call ptr @str_concat(ptr %t7367, ptr %t7368)
  %t7370 = load ptr, ptr %left_t
  %t7371 = load ptr, ptr %right_t
  call void @sema_expect_assignable__String_Struct_TypeInfo_Struct_TypeInfo(ptr %t7369, ptr %t7370, ptr %t7371)
  %t7372 = load ptr, ptr %expr
  %t7373 = load ptr, ptr %left_t
  call void @node_set_type__Struct_ASTNode_Struct_TypeInfo(ptr %t7372, ptr %t7373)
  %t7374 = load ptr, ptr %left_t
  ret ptr %t7374
label_2243:
  %t7375 = load ptr, ptr %op
  %t7376 = getelementptr inbounds [2 x i8], ptr @.str.s940, i64 0, i64 0
  %t7377 = call i32 @str_equals(ptr %t7375, ptr %t7376)
  %t7378 = icmp eq i32 %t7377, 1
  br i1 %t7378, label %label_2247, label %label_2249
label_2247:
  %t7379 = getelementptr inbounds [20 x i8], ptr @.str.s941, i64 0, i64 0
  %t7380 = call ptr @type_int__Void()
  %t7381 = load ptr, ptr %left_t
  call void @sema_expect_assignable__String_Struct_TypeInfo_Struct_TypeInfo(ptr %t7379, ptr %t7380, ptr %t7381)
  %t7382 = getelementptr inbounds [21 x i8], ptr @.str.s942, i64 0, i64 0
  %t7383 = call ptr @type_int__Void()
  %t7384 = load ptr, ptr %right_t
  call void @sema_expect_assignable__String_Struct_TypeInfo_Struct_TypeInfo(ptr %t7382, ptr %t7383, ptr %t7384)
  %t7385 = load ptr, ptr %expr
  %t7386 = call ptr @type_int__Void()
  call void @node_set_type__Struct_ASTNode_Struct_TypeInfo(ptr %t7385, ptr %t7386)
  %t7387 = call ptr @type_int__Void()
  ret ptr %t7387
label_2249:
  %t7388 = load ptr, ptr %op
  %t7389 = getelementptr inbounds [3 x i8], ptr @.str.s943, i64 0, i64 0
  %t7390 = call i32 @str_equals(ptr %t7388, ptr %t7389)
  %t7391 = icmp eq i32 %t7390, 1
  %t7392 = load ptr, ptr %op
  %t7393 = getelementptr inbounds [3 x i8], ptr @.str.s944, i64 0, i64 0
  %t7394 = call i32 @str_equals(ptr %t7392, ptr %t7393)
  %t7395 = icmp eq i32 %t7394, 1
  %t7396 = or i1 %t7391, %t7395
  %t7397 = load ptr, ptr %op
  %t7398 = getelementptr inbounds [2 x i8], ptr @.str.s945, i64 0, i64 0
  %t7399 = call i32 @str_equals(ptr %t7397, ptr %t7398)
  %t7400 = icmp eq i32 %t7399, 1
  %t7401 = or i1 %t7396, %t7400
  %t7402 = load ptr, ptr %op
  %t7403 = getelementptr inbounds [3 x i8], ptr @.str.s946, i64 0, i64 0
  %t7404 = call i32 @str_equals(ptr %t7402, ptr %t7403)
  %t7405 = icmp eq i32 %t7404, 1
  %t7406 = or i1 %t7401, %t7405
  %t7407 = load ptr, ptr %op
  %t7408 = getelementptr inbounds [2 x i8], ptr @.str.s947, i64 0, i64 0
  %t7409 = call i32 @str_equals(ptr %t7407, ptr %t7408)
  %t7410 = icmp eq i32 %t7409, 1
  %t7411 = or i1 %t7406, %t7410
  %t7412 = load ptr, ptr %op
  %t7413 = getelementptr inbounds [3 x i8], ptr @.str.s948, i64 0, i64 0
  %t7414 = call i32 @str_equals(ptr %t7412, ptr %t7413)
  %t7415 = icmp eq i32 %t7414, 1
  %t7416 = or i1 %t7411, %t7415
  br i1 %t7416, label %label_2250, label %label_2252
label_2250:
  %t7417 = getelementptr inbounds [12 x i8], ptr @.str.s949, i64 0, i64 0
  %t7418 = load ptr, ptr %op
  %t7419 = call ptr @str_concat(ptr %t7417, ptr %t7418)
  %t7420 = load ptr, ptr %left_t
  %t7421 = load ptr, ptr %right_t
  call void @sema_expect_assignable__String_Struct_TypeInfo_Struct_TypeInfo(ptr %t7419, ptr %t7420, ptr %t7421)
  %t7422 = load ptr, ptr %expr
  %t7423 = call ptr @type_bool__Void()
  call void @node_set_type__Struct_ASTNode_Struct_TypeInfo(ptr %t7422, ptr %t7423)
  %t7424 = call ptr @type_bool__Void()
  ret ptr %t7424
label_2252:
  %t7425 = getelementptr inbounds [18 x i8], ptr @.str.s950, i64 0, i64 0
  %t7426 = load ptr, ptr %op
  %t7427 = call ptr @str_concat(ptr %t7425, ptr %t7426)
  call void @sema_error__String(ptr %t7427)
  br label %label_2228
label_2228:
  %t7428 = load ptr, ptr %expr
  %t7429 = getelementptr inbounds %ASTNode, ptr %t7428, i32 0, i32 0
  %t7430 = load i32, ptr %t7429
  %t7431 = icmp eq i32 %t7430, 24
  br i1 %t7431, label %label_2253, label %label_2255
label_2253:
  %t7432 = load ptr, ptr %expr
  %t7433 = getelementptr inbounds %ASTNode, ptr %t7432, i32 0, i32 5
  %t7434 = load ptr, ptr %t7433
  %t7435 = call ptr @ptr_to_node(ptr %t7434)
  store ptr %t7435, ptr %callee
  %t7436 = load ptr, ptr %callee
  %t7437 = getelementptr inbounds %ASTNode, ptr %t7436, i32 0, i32 1
  %t7438 = load ptr, ptr %t7437
  store ptr %t7438, ptr %name
  %t7439 = load ptr, ptr %module
  %t7440 = load ptr, ptr %name
  %t7441 = load ptr, ptr %expr
  %t7442 = getelementptr inbounds %ASTNode, ptr %t7441, i32 0, i32 6
  %t7443 = load ptr, ptr %t7442
  %t7444 = call i1 @sema_check_builtin_call__Struct_ASTNode_String_String(ptr %t7439, ptr %t7440, ptr %t7443)
  br i1 %t7444, label %label_2256, label %label_2258
label_2256:
  %t7445 = load ptr, ptr %name
  %t7446 = load ptr, ptr %expr
  %t7447 = getelementptr inbounds %ASTNode, ptr %t7446, i32 0, i32 6
  %t7448 = load ptr, ptr %t7447
  %t7449 = call ptr @sema_builtin_call_type__String_String(ptr %t7445, ptr %t7448)
  store ptr %t7449, ptr %builtin_t
  %t7450 = load ptr, ptr %expr
  %t7451 = load ptr, ptr %builtin_t
  call void @node_set_type__Struct_ASTNode_Struct_TypeInfo(ptr %t7450, ptr %t7451)
  %t7452 = load ptr, ptr %builtin_t
  ret ptr %t7452
label_2258:
  %t7453 = load ptr, ptr %module
  %t7454 = load ptr, ptr %name
  %t7455 = load ptr, ptr %expr
  %t7456 = getelementptr inbounds %ASTNode, ptr %t7455, i32 0, i32 6
  %t7457 = load ptr, ptr %t7456
  %t7458 = call ptr @sema_find_function_overload__Struct_ASTNode_String_String(ptr %t7453, ptr %t7454, ptr %t7457)
  store ptr %t7458, ptr %fn_node
  %t7459 = load ptr, ptr %expr
  %t7460 = getelementptr inbounds %ASTNode, ptr %t7459, i32 0, i32 6
  %t7461 = load ptr, ptr %t7460
  store ptr %t7461, ptr %arg_ptr
  %t7462 = load ptr, ptr %fn_node
  %t7463 = getelementptr inbounds %ASTNode, ptr %t7462, i32 0, i32 5
  %t7464 = load ptr, ptr %t7463
  store ptr %t7464, ptr %param_ptr
  br label %label_2259
label_2259:
  %t7465 = load ptr, ptr %arg_ptr
  %t7466 = getelementptr inbounds [1 x i8], ptr @.str.s951, i64 0, i64 0
  %t7467 = call i32 @str_equals(ptr %t7465, ptr %t7466)
  %t7468 = icmp eq i32 %t7467, 0
  %t7469 = load ptr, ptr %param_ptr
  %t7470 = getelementptr inbounds [1 x i8], ptr @.str.s952, i64 0, i64 0
  %t7471 = call i32 @str_equals(ptr %t7469, ptr %t7470)
  %t7472 = icmp eq i32 %t7471, 0
  %t7473 = and i1 %t7468, %t7472
  br i1 %t7473, label %label_2260, label %label_2261
label_2260:
  %t7474 = load ptr, ptr %arg_ptr
  %t7475 = call ptr @ptr_to_node(ptr %t7474)
  store ptr %t7475, ptr %arg_node
  %t7476 = load ptr, ptr %param_ptr
  %t7477 = call ptr @ptr_to_node(ptr %t7476)
  store ptr %t7477, ptr %param_node
  %t7478 = load ptr, ptr %module
  %t7479 = load ptr, ptr %param_node
  %t7480 = getelementptr inbounds %ASTNode, ptr %t7479, i32 0, i32 5
  %t7481 = load ptr, ptr %t7480
  %t7482 = call ptr @ptr_to_node(ptr %t7481)
  %t7483 = call ptr @sema_annotation_type__Struct_ASTNode_Struct_ASTNode(ptr %t7478, ptr %t7482)
  store ptr %t7483, ptr %param_t
  %t7484 = load ptr, ptr %module
  %t7485 = load ptr, ptr %arg_node
  %t7486 = load ptr, ptr %param_t
  %t7487 = load ptr, ptr %name
  %t7488 = getelementptr inbounds [10 x i8], ptr @.str.s953, i64 0, i64 0
  %t7489 = call ptr @str_concat(ptr %t7487, ptr %t7488)
  %t7490 = call ptr @sema_check_value__Struct_ASTNode_Struct_ASTNode_Struct_TypeInfo_String(ptr %t7484, ptr %t7485, ptr %t7486, ptr %t7489)
  %t7491 = load ptr, ptr %param_node
  %t7492 = getelementptr inbounds %ASTNode, ptr %t7491, i32 0, i32 2
  %t7493 = load ptr, ptr %t7492
  %t7494 = getelementptr inbounds [5 x i8], ptr @.str.s954, i64 0, i64 0
  %t7495 = call i32 @str_equals(ptr %t7493, ptr %t7494)
  %t7496 = icmp eq i32 %t7495, 1
  br i1 %t7496, label %label_2262, label %label_2264
label_2262:
  %t7497 = load ptr, ptr %arg_node
  call void @sema_move_operand__Struct_ASTNode(ptr %t7497)
  br label %label_2264
label_2264:
  %t7498 = load ptr, ptr %arg_node
  %t7499 = getelementptr inbounds %ASTNode, ptr %t7498, i32 0, i32 8
  %t7500 = load ptr, ptr %t7499
  store ptr %t7500, ptr %arg_ptr
  %t7501 = load ptr, ptr %param_node
  %t7502 = getelementptr inbounds %ASTNode, ptr %t7501, i32 0, i32 8
  %t7503 = load ptr, ptr %t7502
  store ptr %t7503, ptr %param_ptr
  br label %label_2259
label_2261:
  %t7504 = call ptr @type_void__Void()
  store ptr %t7504, ptr %ret_t
  %t7505 = load ptr, ptr %fn_node
  %t7506 = getelementptr inbounds %ASTNode, ptr %t7505, i32 0, i32 0
  %t7507 = load i32, ptr %t7506
  %t7508 = icmp eq i32 %t7507, 4
  br i1 %t7508, label %label_2265, label %label_2266
label_2265:
  %t7509 = load ptr, ptr %module
  %t7510 = load ptr, ptr %fn_node
  %t7511 = getelementptr inbounds %ASTNode, ptr %t7510, i32 0, i32 7
  %t7512 = load ptr, ptr %t7511
  %t7513 = call ptr @sema_declared_return_type__Struct_ASTNode_String(ptr %t7509, ptr %t7512)
  store ptr %t7513, ptr %ret_t
  %t7514 = load ptr, ptr %name
  %t7515 = getelementptr inbounds [5 x i8], ptr @.str.s955, i64 0, i64 0
  %t7516 = call i32 @str_equals(ptr %t7514, ptr %t7515)
  %t7517 = icmp eq i32 %t7516, 1
  br i1 %t7517, label %label_2268, label %label_2270
label_2268:
  %t7518 = call ptr @type_int__Void()
  store ptr %t7518, ptr %ret_t
  br label %label_2270
label_2270:
  br label %label_2267
label_2266:
  %t7519 = load ptr, ptr %module
  %t7520 = load ptr, ptr %fn_node
  %t7521 = getelementptr inbounds %ASTNode, ptr %t7520, i32 0, i32 6
  %t7522 = load ptr, ptr %t7521
  %t7523 = call ptr @sema_declared_return_type__Struct_ASTNode_String(ptr %t7519, ptr %t7522)
  store ptr %t7523, ptr %ret_t
  br label %label_2267
label_2267:
  %t7524 = load ptr, ptr %expr
  %t7525 = load ptr, ptr %module
  %t7526 = load ptr, ptr %fn_node
  %t7527 = call ptr @sema_function_symbol__Struct_ASTNode_Struct_ASTNode(ptr %t7525, ptr %t7526)
  %t7528 = getelementptr inbounds %ASTNode, ptr %t7524, i32 0, i32 2
  store ptr %t7527, ptr %t7528
  %t7529 = load ptr, ptr %expr
  %t7530 = load ptr, ptr %ret_t
  call void @node_set_type__Struct_ASTNode_Struct_TypeInfo(ptr %t7529, ptr %t7530)
  %t7531 = load ptr, ptr %ret_t
  ret ptr %t7531
label_2255:
  %t7532 = load ptr, ptr %expr
  %t7533 = getelementptr inbounds %ASTNode, ptr %t7532, i32 0, i32 0
  %t7534 = load i32, ptr %t7533
  %t7535 = icmp eq i32 %t7534, 25
  br i1 %t7535, label %label_2271, label %label_2273
label_2271:
  %t7536 = load ptr, ptr %expr
  %t7537 = getelementptr inbounds %ASTNode, ptr %t7536, i32 0, i32 5
  %t7538 = load ptr, ptr %t7537
  %t7539 = call ptr @ptr_to_node(ptr %t7538)
  store ptr %t7539, ptr %object_node
  %t7540 = load ptr, ptr %object_node
  %t7541 = getelementptr inbounds %ASTNode, ptr %t7540, i32 0, i32 0
  %t7542 = load i32, ptr %t7541
  %t7543 = icmp eq i32 %t7542, 23
  %t7544 = load ptr, ptr %module
  %t7545 = load ptr, ptr %object_node
  %t7546 = getelementptr inbounds %ASTNode, ptr %t7545, i32 0, i32 1
  %t7547 = load ptr, ptr %t7546
  %t7548 = load ptr, ptr %expr
  %t7549 = getelementptr inbounds %ASTNode, ptr %t7548, i32 0, i32 1
  %t7550 = load ptr, ptr %t7549
  %t7551 = call i1 @sema_enum_has_variant__Struct_ASTNode_String_String(ptr %t7544, ptr %t7547, ptr %t7550)
  %t7552 = and i1 %t7543, %t7551
  br i1 %t7552, label %label_2274, label %label_2276
label_2274:
  %t7553 = load ptr, ptr %expr
  %t7554 = call ptr @type_int__Void()
  call void @node_set_type__Struct_ASTNode_Struct_TypeInfo(ptr %t7553, ptr %t7554)
  %t7555 = call ptr @type_int__Void()
  ret ptr %t7555
label_2276:
  %t7556 = load ptr, ptr %module
  %t7557 = load ptr, ptr %object_node
  %t7558 = call ptr @sema_expr__Struct_ASTNode_Struct_ASTNode(ptr %t7556, ptr %t7557)
  store ptr %t7558, ptr %object_t
  %t7559 = load ptr, ptr %object_t
  %t7560 = getelementptr inbounds %TypeInfo, ptr %t7559, i32 0, i32 0
  %t7561 = load i32, ptr %t7560
  %t7562 = icmp ne i32 %t7561, 8
  br i1 %t7562, label %label_2277, label %label_2279
label_2277:
  %t7563 = getelementptr inbounds [38 x i8], ptr @.str.s956, i64 0, i64 0
  call void @sema_error__String(ptr %t7563)
  br label %label_2279
label_2279:
  %t7564 = load ptr, ptr %module
  %t7565 = load ptr, ptr %object_t
  %t7566 = getelementptr inbounds %TypeInfo, ptr %t7565, i32 0, i32 1
  %t7567 = load ptr, ptr %t7566
  %t7568 = load ptr, ptr %expr
  %t7569 = getelementptr inbounds %ASTNode, ptr %t7568, i32 0, i32 1
  %t7570 = load ptr, ptr %t7569
  %t7571 = call ptr @sema_find_struct_field_type__Struct_ASTNode_String_String(ptr %t7564, ptr %t7567, ptr %t7570)
  store ptr %t7571, ptr %field_t
  %t7572 = load ptr, ptr %expr
  %t7573 = load ptr, ptr %field_t
  call void @node_set_type__Struct_ASTNode_Struct_TypeInfo(ptr %t7572, ptr %t7573)
  %t7574 = load ptr, ptr %field_t
  ret ptr %t7574
label_2273:
  %t7575 = load ptr, ptr %expr
  %t7576 = getelementptr inbounds %ASTNode, ptr %t7575, i32 0, i32 0
  %t7577 = load i32, ptr %t7576
  %t7578 = icmp eq i32 %t7577, 27
  br i1 %t7578, label %label_2280, label %label_2282
label_2280:
  %t7579 = load ptr, ptr %expr
  %t7580 = getelementptr inbounds %ASTNode, ptr %t7579, i32 0, i32 5
  %t7581 = load ptr, ptr %t7580
  store ptr %t7581, ptr %elem_ptr
  %t7582 = load ptr, ptr %elem_ptr
  %t7583 = getelementptr inbounds [1 x i8], ptr @.str.s957, i64 0, i64 0
  %t7584 = call i32 @str_equals(ptr %t7582, ptr %t7583)
  %t7585 = icmp eq i32 %t7584, 1
  br i1 %t7585, label %label_2283, label %label_2285
label_2283:
  %t7586 = call ptr @type_invalid__Void()
  %t7587 = call ptr @type_array__Struct_TypeInfo(ptr %t7586)
  store ptr %t7587, ptr %arr_t
  %t7588 = load ptr, ptr %expr
  %t7589 = load ptr, ptr %arr_t
  call void @node_set_type__Struct_ASTNode_Struct_TypeInfo(ptr %t7588, ptr %t7589)
  %t7590 = load ptr, ptr %arr_t
  ret ptr %t7590
label_2285:
  %t7591 = load ptr, ptr %module
  %t7592 = load ptr, ptr %elem_ptr
  %t7593 = call ptr @ptr_to_node(ptr %t7592)
  %t7594 = call ptr @sema_expr__Struct_ASTNode_Struct_ASTNode(ptr %t7591, ptr %t7593)
  store ptr %t7594, ptr %first_t
  %t7595 = load ptr, ptr %elem_ptr
  %t7596 = call ptr @ptr_to_node(ptr %t7595)
  %t7597 = getelementptr inbounds %ASTNode, ptr %t7596, i32 0, i32 8
  %t7598 = load ptr, ptr %t7597
  store ptr %t7598, ptr %elem_ptr
  br label %label_2286
label_2286:
  %t7599 = load ptr, ptr %elem_ptr
  %t7600 = getelementptr inbounds [1 x i8], ptr @.str.s958, i64 0, i64 0
  %t7601 = call i32 @str_equals(ptr %t7599, ptr %t7600)
  %t7602 = icmp eq i32 %t7601, 0
  br i1 %t7602, label %label_2287, label %label_2288
label_2287:
  %t7603 = load ptr, ptr %elem_ptr
  %t7604 = call ptr @ptr_to_node(ptr %t7603)
  store ptr %t7604, ptr %elem
  %t7605 = load ptr, ptr %module
  %t7606 = load ptr, ptr %elem
  %t7607 = call ptr @sema_expr__Struct_ASTNode_Struct_ASTNode(ptr %t7605, ptr %t7606)
  store ptr %t7607, ptr %elem_t
  %t7608 = getelementptr inbounds [22 x i8], ptr @.str.s959, i64 0, i64 0
  %t7609 = load ptr, ptr %first_t
  %t7610 = load ptr, ptr %elem_t
  call void @sema_expect_assignable__String_Struct_TypeInfo_Struct_TypeInfo(ptr %t7608, ptr %t7609, ptr %t7610)
  %t7611 = load ptr, ptr %elem
  %t7612 = getelementptr inbounds %ASTNode, ptr %t7611, i32 0, i32 8
  %t7613 = load ptr, ptr %t7612
  store ptr %t7613, ptr %elem_ptr
  br label %label_2286
label_2288:
  %t7614 = load ptr, ptr %first_t
  %t7615 = call ptr @type_array__Struct_TypeInfo(ptr %t7614)
  store ptr %t7615, ptr %arr_t2
  %t7616 = load ptr, ptr %expr
  %t7617 = load ptr, ptr %arr_t2
  call void @node_set_type__Struct_ASTNode_Struct_TypeInfo(ptr %t7616, ptr %t7617)
  %t7618 = load ptr, ptr %arr_t2
  ret ptr %t7618
label_2282:
  %t7619 = load ptr, ptr %expr
  %t7620 = getelementptr inbounds %ASTNode, ptr %t7619, i32 0, i32 0
  %t7621 = load i32, ptr %t7620
  %t7622 = icmp eq i32 %t7621, 26
  br i1 %t7622, label %label_2289, label %label_2291
label_2289:
  %t7623 = load ptr, ptr %module
  %t7624 = load ptr, ptr %expr
  %t7625 = getelementptr inbounds %ASTNode, ptr %t7624, i32 0, i32 5
  %t7626 = load ptr, ptr %t7625
  %t7627 = call ptr @ptr_to_node(ptr %t7626)
  %t7628 = call ptr @sema_expr__Struct_ASTNode_Struct_ASTNode(ptr %t7623, ptr %t7627)
  store ptr %t7628, ptr %array_t
  %t7629 = load ptr, ptr %module
  %t7630 = load ptr, ptr %expr
  %t7631 = getelementptr inbounds %ASTNode, ptr %t7630, i32 0, i32 6
  %t7632 = load ptr, ptr %t7631
  %t7633 = call ptr @ptr_to_node(ptr %t7632)
  %t7634 = call ptr @sema_expr__Struct_ASTNode_Struct_ASTNode(ptr %t7629, ptr %t7633)
  store ptr %t7634, ptr %index_t
  %t7635 = getelementptr inbounds [12 x i8], ptr @.str.s960, i64 0, i64 0
  %t7636 = call ptr @type_int__Void()
  %t7637 = load ptr, ptr %index_t
  call void @sema_expect_assignable__String_Struct_TypeInfo_Struct_TypeInfo(ptr %t7635, ptr %t7636, ptr %t7637)
  %t7638 = load ptr, ptr %array_t
  %t7639 = getelementptr inbounds %TypeInfo, ptr %t7638, i32 0, i32 0
  %t7640 = load i32, ptr %t7639
  %t7641 = icmp ne i32 %t7640, 10
  br i1 %t7641, label %label_2292, label %label_2294
label_2292:
  %t7642 = getelementptr inbounds [27 x i8], ptr @.str.s961, i64 0, i64 0
  call void @sema_error__String(ptr %t7642)
  br label %label_2294
label_2294:
  %t7643 = load ptr, ptr %array_t
  %t7644 = getelementptr inbounds %TypeInfo, ptr %t7643, i32 0, i32 3
  %t7645 = load ptr, ptr %t7644
  %t7646 = call ptr @ptr_to_type(ptr %t7645)
  store ptr %t7646, ptr %elem_t
  %t7647 = load ptr, ptr %expr
  %t7648 = load ptr, ptr %elem_t
  call void @node_set_type__Struct_ASTNode_Struct_TypeInfo(ptr %t7647, ptr %t7648)
  %t7649 = load ptr, ptr %elem_t
  ret ptr %t7649
label_2291:
  %t7650 = load ptr, ptr %expr
  %t7651 = getelementptr inbounds %ASTNode, ptr %t7650, i32 0, i32 0
  %t7652 = load i32, ptr %t7651
  %t7653 = icmp eq i32 %t7652, 28
  br i1 %t7653, label %label_2295, label %label_2297
label_2295:
  %t7654 = load ptr, ptr %module
  %t7655 = load ptr, ptr %expr
  %t7656 = getelementptr inbounds %ASTNode, ptr %t7655, i32 0, i32 1
  %t7657 = load ptr, ptr %t7656
  %t7658 = call i1 @sema_has_struct__Struct_ASTNode_String(ptr %t7654, ptr %t7657)
  %t7659 = icmp eq i1 %t7658, 0
  br i1 %t7659, label %label_2298, label %label_2300
label_2298:
  %t7660 = getelementptr inbounds [16 x i8], ptr @.str.s962, i64 0, i64 0
  %t7661 = load ptr, ptr %expr
  %t7662 = getelementptr inbounds %ASTNode, ptr %t7661, i32 0, i32 1
  %t7663 = load ptr, ptr %t7662
  %t7664 = call ptr @str_concat(ptr %t7660, ptr %t7663)
  call void @sema_error__String(ptr %t7664)
  br label %label_2300
label_2300:
  %t7665 = load ptr, ptr %expr
  %t7666 = getelementptr inbounds %ASTNode, ptr %t7665, i32 0, i32 5
  %t7667 = load ptr, ptr %t7666
  store ptr %t7667, ptr %field_ptr
  br label %label_2301
label_2301:
  %t7668 = load ptr, ptr %field_ptr
  %t7669 = getelementptr inbounds [1 x i8], ptr @.str.s963, i64 0, i64 0
  %t7670 = call i32 @str_equals(ptr %t7668, ptr %t7669)
  %t7671 = icmp eq i32 %t7670, 0
  br i1 %t7671, label %label_2302, label %label_2303
label_2302:
  %t7672 = load ptr, ptr %field_ptr
  %t7673 = call ptr @ptr_to_node(ptr %t7672)
  store ptr %t7673, ptr %field
  %t7674 = load ptr, ptr %module
  %t7675 = load ptr, ptr %expr
  %t7676 = getelementptr inbounds %ASTNode, ptr %t7675, i32 0, i32 1
  %t7677 = load ptr, ptr %t7676
  %t7678 = load ptr, ptr %field
  %t7679 = getelementptr inbounds %ASTNode, ptr %t7678, i32 0, i32 1
  %t7680 = load ptr, ptr %t7679
  %t7681 = call ptr @sema_find_struct_field_type__Struct_ASTNode_String_String(ptr %t7674, ptr %t7677, ptr %t7680)
  store ptr %t7681, ptr %expected
  %t7682 = load ptr, ptr %module
  %t7683 = load ptr, ptr %field
  %t7684 = getelementptr inbounds %ASTNode, ptr %t7683, i32 0, i32 5
  %t7685 = load ptr, ptr %t7684
  %t7686 = call ptr @ptr_to_node(ptr %t7685)
  %t7687 = load ptr, ptr %expected
  %t7688 = getelementptr inbounds [14 x i8], ptr @.str.s964, i64 0, i64 0
  %t7689 = load ptr, ptr %field
  %t7690 = getelementptr inbounds %ASTNode, ptr %t7689, i32 0, i32 1
  %t7691 = load ptr, ptr %t7690
  %t7692 = call ptr @str_concat(ptr %t7688, ptr %t7691)
  %t7693 = call ptr @sema_check_value__Struct_ASTNode_Struct_ASTNode_Struct_TypeInfo_String(ptr %t7682, ptr %t7686, ptr %t7687, ptr %t7692)
  %t7694 = load ptr, ptr %field
  %t7695 = getelementptr inbounds %ASTNode, ptr %t7694, i32 0, i32 5
  %t7696 = load ptr, ptr %t7695
  %t7697 = call ptr @ptr_to_node(ptr %t7696)
  call void @sema_move_operand__Struct_ASTNode(ptr %t7697)
  %t7698 = load ptr, ptr %field
  %t7699 = getelementptr inbounds %ASTNode, ptr %t7698, i32 0, i32 8
  %t7700 = load ptr, ptr %t7699
  store ptr %t7700, ptr %field_ptr
  br label %label_2301
label_2303:
  %t7701 = load ptr, ptr %expr
  %t7702 = getelementptr inbounds %ASTNode, ptr %t7701, i32 0, i32 1
  %t7703 = load ptr, ptr %t7702
  %t7704 = call ptr @type_struct__String(ptr %t7703)
  store ptr %t7704, ptr %struct_t
  %t7705 = load ptr, ptr %expr
  %t7706 = load ptr, ptr %struct_t
  call void @node_set_type__Struct_ASTNode_Struct_TypeInfo(ptr %t7705, ptr %t7706)
  %t7707 = load ptr, ptr %struct_t
  ret ptr %t7707
label_2297:
  %t7708 = getelementptr inbounds [23 x i8], ptr @.str.s965, i64 0, i64 0
  call void @sema_error__String(ptr %t7708)
  %t7709 = call ptr @type_invalid__Void()
  ret ptr %t7709
}

define void @sema_statement__Struct_ASTNode_Struct_ASTNode_Struct_TypeInfo(ptr %p_module, ptr %p_stmt, ptr %p_expected_return) {
  %module = alloca ptr
  %stmt = alloca ptr
  %expected_return = alloca ptr
  %var_t = alloca ptr
  %has_annotation = alloca i1
  %has_init = alloca i1
  %target = alloca ptr
  %target_t = alloca ptr
  %value_t = alloca ptr
  %cond_t = alloca ptr
  %else_node = alloca ptr
  %cond_t2 = alloca ptr
  %start_t = alloca ptr
  %end_t = alloca ptr
  %scrut_t = alloca ptr
  %pat_expected = alloca ptr
  %arm_ptr = alloca ptr
  %arm = alloca ptr
  store ptr %p_module, ptr %module
  store ptr %p_stmt, ptr %stmt
  store ptr %p_expected_return, ptr %expected_return
  %t7728 = load ptr, ptr %stmt
  %t7729 = getelementptr inbounds %ASTNode, ptr %t7728, i32 0, i32 0
  %t7730 = load i32, ptr %t7729
  %t7731 = icmp eq i32 %t7730, 3
  br i1 %t7731, label %label_2304, label %label_2306
label_2304:
  %t7732 = call ptr @type_invalid__Void()
  store ptr %t7732, ptr %var_t
  %t7733 = load ptr, ptr %stmt
  %t7734 = getelementptr inbounds %ASTNode, ptr %t7733, i32 0, i32 5
  %t7735 = load ptr, ptr %t7734
  %t7736 = getelementptr inbounds [1 x i8], ptr @.str.s966, i64 0, i64 0
  %t7737 = call i32 @str_equals(ptr %t7735, ptr %t7736)
  %t7738 = icmp eq i32 %t7737, 0
  store i1 %t7738, ptr %has_annotation
  %t7739 = load ptr, ptr %stmt
  %t7740 = getelementptr inbounds %ASTNode, ptr %t7739, i32 0, i32 6
  %t7741 = load ptr, ptr %t7740
  %t7742 = getelementptr inbounds [1 x i8], ptr @.str.s967, i64 0, i64 0
  %t7743 = call i32 @str_equals(ptr %t7741, ptr %t7742)
  %t7744 = icmp eq i32 %t7743, 0
  store i1 %t7744, ptr %has_init
  %t7745 = load i1, ptr %has_annotation
  br i1 %t7745, label %label_2307, label %label_2309
label_2307:
  %t7746 = load ptr, ptr %module
  %t7747 = load ptr, ptr %stmt
  %t7748 = getelementptr inbounds %ASTNode, ptr %t7747, i32 0, i32 5
  %t7749 = load ptr, ptr %t7748
  %t7750 = call ptr @ptr_to_node(ptr %t7749)
  %t7751 = call ptr @sema_annotation_type__Struct_ASTNode_Struct_ASTNode(ptr %t7746, ptr %t7750)
  store ptr %t7751, ptr %var_t
  br label %label_2309
label_2309:
  %t7752 = load i1, ptr %has_init
  br i1 %t7752, label %label_2310, label %label_2312
label_2310:
  %t7753 = load i1, ptr %has_annotation
  br i1 %t7753, label %label_2313, label %label_2314
label_2313:
  %t7754 = load ptr, ptr %module
  %t7755 = load ptr, ptr %stmt
  %t7756 = getelementptr inbounds %ASTNode, ptr %t7755, i32 0, i32 6
  %t7757 = load ptr, ptr %t7756
  %t7758 = call ptr @ptr_to_node(ptr %t7757)
  %t7759 = load ptr, ptr %var_t
  %t7760 = getelementptr inbounds [17 x i8], ptr @.str.s968, i64 0, i64 0
  %t7761 = load ptr, ptr %stmt
  %t7762 = getelementptr inbounds %ASTNode, ptr %t7761, i32 0, i32 1
  %t7763 = load ptr, ptr %t7762
  %t7764 = call ptr @str_concat(ptr %t7760, ptr %t7763)
  %t7765 = call ptr @sema_check_value__Struct_ASTNode_Struct_ASTNode_Struct_TypeInfo_String(ptr %t7754, ptr %t7758, ptr %t7759, ptr %t7764)
  br label %label_2315
label_2314:
  %t7766 = load ptr, ptr %module
  %t7767 = load ptr, ptr %stmt
  %t7768 = getelementptr inbounds %ASTNode, ptr %t7767, i32 0, i32 6
  %t7769 = load ptr, ptr %t7768
  %t7770 = call ptr @ptr_to_node(ptr %t7769)
  %t7771 = call ptr @sema_expr__Struct_ASTNode_Struct_ASTNode(ptr %t7766, ptr %t7770)
  store ptr %t7771, ptr %var_t
  br label %label_2315
label_2315:
  %t7772 = load ptr, ptr %stmt
  %t7773 = getelementptr inbounds %ASTNode, ptr %t7772, i32 0, i32 6
  %t7774 = load ptr, ptr %t7773
  %t7775 = call ptr @ptr_to_node(ptr %t7774)
  call void @sema_move_operand__Struct_ASTNode(ptr %t7775)
  br label %label_2312
label_2312:
  %t7776 = load ptr, ptr %var_t
  %t7777 = call i1 @type_is_valid__Struct_TypeInfo(ptr %t7776)
  %t7778 = icmp eq i1 %t7777, 0
  br i1 %t7778, label %label_2316, label %label_2318
label_2316:
  %t7779 = getelementptr inbounds [23 x i8], ptr @.str.s969, i64 0, i64 0
  %t7780 = load ptr, ptr %stmt
  %t7781 = getelementptr inbounds %ASTNode, ptr %t7780, i32 0, i32 1
  %t7782 = load ptr, ptr %t7781
  %t7783 = call ptr @str_concat(ptr %t7779, ptr %t7782)
  call void @sema_error__String(ptr %t7783)
  br label %label_2318
label_2318:
  %t7784 = load ptr, ptr %stmt
  %t7785 = getelementptr inbounds %ASTNode, ptr %t7784, i32 0, i32 1
  %t7786 = load ptr, ptr %t7785
  call void @ir_unmark_moved(ptr %t7786)
  %t7787 = load ptr, ptr %stmt
  %t7788 = getelementptr inbounds %ASTNode, ptr %t7787, i32 0, i32 1
  %t7789 = load ptr, ptr %t7788
  %t7790 = load ptr, ptr %var_t
  %t7791 = call ptr @type_sem_key__Struct_TypeInfo(ptr %t7790)
  call void @ir_set_var_type(ptr %t7789, ptr %t7791)
  %t7792 = load ptr, ptr %stmt
  %t7793 = load ptr, ptr %var_t
  call void @node_set_type__Struct_ASTNode_Struct_TypeInfo(ptr %t7792, ptr %t7793)
  br label %label_2306
label_2306:
  %t7794 = load ptr, ptr %stmt
  %t7795 = getelementptr inbounds %ASTNode, ptr %t7794, i32 0, i32 0
  %t7796 = load i32, ptr %t7795
  %t7797 = icmp eq i32 %t7796, 16
  br i1 %t7797, label %label_2319, label %label_2321
label_2319:
  %t7798 = load ptr, ptr %stmt
  %t7799 = getelementptr inbounds %ASTNode, ptr %t7798, i32 0, i32 5
  %t7800 = load ptr, ptr %t7799
  %t7801 = call ptr @ptr_to_node(ptr %t7800)
  store ptr %t7801, ptr %target
  %t7802 = load ptr, ptr %module
  %t7803 = load ptr, ptr %target
  %t7804 = call ptr @sema_expr__Struct_ASTNode_Struct_ASTNode(ptr %t7802, ptr %t7803)
  store ptr %t7804, ptr %target_t
  %t7805 = load ptr, ptr %module
  %t7806 = load ptr, ptr %stmt
  %t7807 = getelementptr inbounds %ASTNode, ptr %t7806, i32 0, i32 6
  %t7808 = load ptr, ptr %t7807
  %t7809 = call ptr @ptr_to_node(ptr %t7808)
  %t7810 = call ptr @sema_expr__Struct_ASTNode_Struct_ASTNode(ptr %t7805, ptr %t7809)
  store ptr %t7810, ptr %value_t
  %t7811 = getelementptr inbounds [11 x i8], ptr @.str.s970, i64 0, i64 0
  %t7812 = load ptr, ptr %target_t
  %t7813 = load ptr, ptr %value_t
  call void @sema_expect_assignable__String_Struct_TypeInfo_Struct_TypeInfo(ptr %t7811, ptr %t7812, ptr %t7813)
  %t7814 = load ptr, ptr %stmt
  %t7815 = getelementptr inbounds %ASTNode, ptr %t7814, i32 0, i32 6
  %t7816 = load ptr, ptr %t7815
  %t7817 = call ptr @ptr_to_node(ptr %t7816)
  call void @sema_move_operand__Struct_ASTNode(ptr %t7817)
  br label %label_2321
label_2321:
  %t7818 = load ptr, ptr %stmt
  %t7819 = getelementptr inbounds %ASTNode, ptr %t7818, i32 0, i32 0
  %t7820 = load i32, ptr %t7819
  %t7821 = icmp eq i32 %t7820, 15
  br i1 %t7821, label %label_2322, label %label_2324
label_2322:
  %t7822 = load ptr, ptr %stmt
  %t7823 = getelementptr inbounds %ASTNode, ptr %t7822, i32 0, i32 5
  %t7824 = load ptr, ptr %t7823
  %t7825 = getelementptr inbounds [1 x i8], ptr @.str.s971, i64 0, i64 0
  %t7826 = call i32 @str_equals(ptr %t7824, ptr %t7825)
  %t7827 = icmp eq i32 %t7826, 0
  br i1 %t7827, label %label_2325, label %label_2326
label_2325:
  %t7828 = load ptr, ptr %module
  %t7829 = load ptr, ptr %stmt
  %t7830 = getelementptr inbounds %ASTNode, ptr %t7829, i32 0, i32 5
  %t7831 = load ptr, ptr %t7830
  %t7832 = call ptr @ptr_to_node(ptr %t7831)
  %t7833 = load ptr, ptr %expected_return
  %t7834 = getelementptr inbounds [7 x i8], ptr @.str.s972, i64 0, i64 0
  %t7835 = call ptr @sema_check_value__Struct_ASTNode_Struct_ASTNode_Struct_TypeInfo_String(ptr %t7828, ptr %t7832, ptr %t7833, ptr %t7834)
  br label %label_2327
label_2326:
  %t7836 = getelementptr inbounds [7 x i8], ptr @.str.s973, i64 0, i64 0
  %t7837 = load ptr, ptr %expected_return
  %t7838 = call ptr @type_void__Void()
  call void @sema_expect_assignable__String_Struct_TypeInfo_Struct_TypeInfo(ptr %t7836, ptr %t7837, ptr %t7838)
  br label %label_2327
label_2327:
  br label %label_2324
label_2324:
  %t7839 = load ptr, ptr %stmt
  %t7840 = getelementptr inbounds %ASTNode, ptr %t7839, i32 0, i32 0
  %t7841 = load i32, ptr %t7840
  %t7842 = icmp eq i32 %t7841, 17
  br i1 %t7842, label %label_2328, label %label_2330
label_2328:
  %t7843 = load ptr, ptr %stmt
  %t7844 = getelementptr inbounds %ASTNode, ptr %t7843, i32 0, i32 5
  %t7845 = load ptr, ptr %t7844
  %t7846 = getelementptr inbounds [1 x i8], ptr @.str.s974, i64 0, i64 0
  %t7847 = call i32 @str_equals(ptr %t7845, ptr %t7846)
  %t7848 = icmp eq i32 %t7847, 0
  br i1 %t7848, label %label_2331, label %label_2333
label_2331:
  %t7849 = load ptr, ptr %module
  %t7850 = load ptr, ptr %stmt
  %t7851 = getelementptr inbounds %ASTNode, ptr %t7850, i32 0, i32 5
  %t7852 = load ptr, ptr %t7851
  %t7853 = call ptr @ptr_to_node(ptr %t7852)
  %t7854 = call ptr @sema_expr__Struct_ASTNode_Struct_ASTNode(ptr %t7849, ptr %t7853)
  br label %label_2333
label_2333:
  br label %label_2330
label_2330:
  %t7855 = load ptr, ptr %stmt
  %t7856 = getelementptr inbounds %ASTNode, ptr %t7855, i32 0, i32 0
  %t7857 = load i32, ptr %t7856
  %t7858 = icmp eq i32 %t7857, 10
  br i1 %t7858, label %label_2334, label %label_2336
label_2334:
  %t7859 = load ptr, ptr %module
  %t7860 = load ptr, ptr %stmt
  %t7861 = getelementptr inbounds %ASTNode, ptr %t7860, i32 0, i32 5
  %t7862 = load ptr, ptr %t7861
  %t7863 = call ptr @ptr_to_node(ptr %t7862)
  %t7864 = call ptr @sema_expr__Struct_ASTNode_Struct_ASTNode(ptr %t7859, ptr %t7863)
  store ptr %t7864, ptr %cond_t
  %t7865 = getelementptr inbounds [13 x i8], ptr @.str.s975, i64 0, i64 0
  %t7866 = call ptr @type_bool__Void()
  %t7867 = load ptr, ptr %cond_t
  call void @sema_expect_assignable__String_Struct_TypeInfo_Struct_TypeInfo(ptr %t7865, ptr %t7866, ptr %t7867)
  %t7868 = load ptr, ptr %module
  %t7869 = load ptr, ptr %stmt
  %t7870 = getelementptr inbounds %ASTNode, ptr %t7869, i32 0, i32 6
  %t7871 = load ptr, ptr %t7870
  %t7872 = call ptr @ptr_to_node(ptr %t7871)
  %t7873 = load ptr, ptr %expected_return
  call void @sema_block__Struct_ASTNode_Struct_ASTNode_Struct_TypeInfo(ptr %t7868, ptr %t7872, ptr %t7873)
  %t7874 = load ptr, ptr %stmt
  %t7875 = getelementptr inbounds %ASTNode, ptr %t7874, i32 0, i32 7
  %t7876 = load ptr, ptr %t7875
  %t7877 = getelementptr inbounds [1 x i8], ptr @.str.s976, i64 0, i64 0
  %t7878 = call i32 @str_equals(ptr %t7876, ptr %t7877)
  %t7879 = icmp eq i32 %t7878, 0
  br i1 %t7879, label %label_2337, label %label_2339
label_2337:
  %t7880 = load ptr, ptr %stmt
  %t7881 = getelementptr inbounds %ASTNode, ptr %t7880, i32 0, i32 7
  %t7882 = load ptr, ptr %t7881
  %t7883 = call ptr @ptr_to_node(ptr %t7882)
  store ptr %t7883, ptr %else_node
  %t7884 = load ptr, ptr %else_node
  %t7885 = getelementptr inbounds %ASTNode, ptr %t7884, i32 0, i32 0
  %t7886 = load i32, ptr %t7885
  %t7887 = icmp eq i32 %t7886, 10
  br i1 %t7887, label %label_2340, label %label_2341
label_2340:
  %t7888 = load ptr, ptr %module
  %t7889 = load ptr, ptr %else_node
  %t7890 = load ptr, ptr %expected_return
  call void @sema_statement__Struct_ASTNode_Struct_ASTNode_Struct_TypeInfo(ptr %t7888, ptr %t7889, ptr %t7890)
  br label %label_2342
label_2341:
  %t7891 = load ptr, ptr %module
  %t7892 = load ptr, ptr %else_node
  %t7893 = load ptr, ptr %expected_return
  call void @sema_block__Struct_ASTNode_Struct_ASTNode_Struct_TypeInfo(ptr %t7891, ptr %t7892, ptr %t7893)
  br label %label_2342
label_2342:
  br label %label_2339
label_2339:
  br label %label_2336
label_2336:
  %t7894 = load ptr, ptr %stmt
  %t7895 = getelementptr inbounds %ASTNode, ptr %t7894, i32 0, i32 0
  %t7896 = load i32, ptr %t7895
  %t7897 = icmp eq i32 %t7896, 13
  br i1 %t7897, label %label_2343, label %label_2345
label_2343:
  %t7898 = load ptr, ptr %module
  %t7899 = load ptr, ptr %stmt
  %t7900 = getelementptr inbounds %ASTNode, ptr %t7899, i32 0, i32 5
  %t7901 = load ptr, ptr %t7900
  %t7902 = call ptr @ptr_to_node(ptr %t7901)
  %t7903 = call ptr @sema_expr__Struct_ASTNode_Struct_ASTNode(ptr %t7898, ptr %t7902)
  store ptr %t7903, ptr %cond_t2
  %t7904 = getelementptr inbounds [16 x i8], ptr @.str.s977, i64 0, i64 0
  %t7905 = call ptr @type_bool__Void()
  %t7906 = load ptr, ptr %cond_t2
  call void @sema_expect_assignable__String_Struct_TypeInfo_Struct_TypeInfo(ptr %t7904, ptr %t7905, ptr %t7906)
  %t7907 = load ptr, ptr %module
  %t7908 = load ptr, ptr %stmt
  %t7909 = getelementptr inbounds %ASTNode, ptr %t7908, i32 0, i32 6
  %t7910 = load ptr, ptr %t7909
  %t7911 = call ptr @ptr_to_node(ptr %t7910)
  %t7912 = load ptr, ptr %expected_return
  call void @sema_block__Struct_ASTNode_Struct_ASTNode_Struct_TypeInfo(ptr %t7907, ptr %t7911, ptr %t7912)
  br label %label_2345
label_2345:
  %t7913 = load ptr, ptr %stmt
  %t7914 = getelementptr inbounds %ASTNode, ptr %t7913, i32 0, i32 0
  %t7915 = load i32, ptr %t7914
  %t7916 = icmp eq i32 %t7915, 14
  br i1 %t7916, label %label_2346, label %label_2348
label_2346:
  %t7917 = load ptr, ptr %module
  %t7918 = load ptr, ptr %stmt
  %t7919 = getelementptr inbounds %ASTNode, ptr %t7918, i32 0, i32 5
  %t7920 = load ptr, ptr %t7919
  %t7921 = call ptr @ptr_to_node(ptr %t7920)
  %t7922 = load ptr, ptr %expected_return
  call void @sema_block__Struct_ASTNode_Struct_ASTNode_Struct_TypeInfo(ptr %t7917, ptr %t7921, ptr %t7922)
  br label %label_2348
label_2348:
  %t7923 = load ptr, ptr %stmt
  %t7924 = getelementptr inbounds %ASTNode, ptr %t7923, i32 0, i32 0
  %t7925 = load i32, ptr %t7924
  %t7926 = icmp eq i32 %t7925, 12
  br i1 %t7926, label %label_2349, label %label_2351
label_2349:
  %t7927 = load ptr, ptr %module
  %t7928 = load ptr, ptr %stmt
  %t7929 = getelementptr inbounds %ASTNode, ptr %t7928, i32 0, i32 5
  %t7930 = load ptr, ptr %t7929
  %t7931 = call ptr @ptr_to_node(ptr %t7930)
  %t7932 = call ptr @sema_expr__Struct_ASTNode_Struct_ASTNode(ptr %t7927, ptr %t7931)
  store ptr %t7932, ptr %start_t
  %t7933 = getelementptr inbounds [16 x i8], ptr @.str.s978, i64 0, i64 0
  %t7934 = call ptr @type_int__Void()
  %t7935 = load ptr, ptr %start_t
  call void @sema_expect_assignable__String_Struct_TypeInfo_Struct_TypeInfo(ptr %t7933, ptr %t7934, ptr %t7935)
  %t7936 = load ptr, ptr %module
  %t7937 = load ptr, ptr %stmt
  %t7938 = getelementptr inbounds %ASTNode, ptr %t7937, i32 0, i32 6
  %t7939 = load ptr, ptr %t7938
  %t7940 = call ptr @ptr_to_node(ptr %t7939)
  %t7941 = call ptr @sema_expr__Struct_ASTNode_Struct_ASTNode(ptr %t7936, ptr %t7940)
  store ptr %t7941, ptr %end_t
  %t7942 = getelementptr inbounds [14 x i8], ptr @.str.s979, i64 0, i64 0
  %t7943 = call ptr @type_int__Void()
  %t7944 = load ptr, ptr %end_t
  call void @sema_expect_assignable__String_Struct_TypeInfo_Struct_TypeInfo(ptr %t7942, ptr %t7943, ptr %t7944)
  %t7945 = load ptr, ptr %stmt
  %t7946 = getelementptr inbounds %ASTNode, ptr %t7945, i32 0, i32 1
  %t7947 = load ptr, ptr %t7946
  %t7948 = call ptr @type_int__Void()
  %t7949 = call ptr @type_sem_key__Struct_TypeInfo(ptr %t7948)
  call void @ir_set_var_type(ptr %t7947, ptr %t7949)
  %t7950 = load ptr, ptr %module
  %t7951 = load ptr, ptr %stmt
  %t7952 = getelementptr inbounds %ASTNode, ptr %t7951, i32 0, i32 7
  %t7953 = load ptr, ptr %t7952
  %t7954 = call ptr @ptr_to_node(ptr %t7953)
  %t7955 = load ptr, ptr %expected_return
  call void @sema_block__Struct_ASTNode_Struct_ASTNode_Struct_TypeInfo(ptr %t7950, ptr %t7954, ptr %t7955)
  br label %label_2351
label_2351:
  %t7956 = load ptr, ptr %stmt
  %t7957 = getelementptr inbounds %ASTNode, ptr %t7956, i32 0, i32 0
  %t7958 = load i32, ptr %t7957
  %t7959 = icmp eq i32 %t7958, 11
  br i1 %t7959, label %label_2352, label %label_2354
label_2352:
  %t7960 = load ptr, ptr %module
  %t7961 = load ptr, ptr %stmt
  %t7962 = getelementptr inbounds %ASTNode, ptr %t7961, i32 0, i32 5
  %t7963 = load ptr, ptr %t7962
  %t7964 = call ptr @ptr_to_node(ptr %t7963)
  %t7965 = call ptr @sema_expr__Struct_ASTNode_Struct_ASTNode(ptr %t7960, ptr %t7964)
  store ptr %t7965, ptr %scrut_t
  %t7966 = load ptr, ptr %scrut_t
  %t7967 = getelementptr inbounds %TypeInfo, ptr %t7966, i32 0, i32 0
  %t7968 = load i32, ptr %t7967
  %t7969 = icmp ne i32 %t7968, 2
  %t7970 = load ptr, ptr %scrut_t
  %t7971 = getelementptr inbounds %TypeInfo, ptr %t7970, i32 0, i32 0
  %t7972 = load i32, ptr %t7971
  %t7973 = icmp ne i32 %t7972, 9
  %t7974 = and i1 %t7969, %t7973
  br i1 %t7974, label %label_2355, label %label_2357
label_2355:
  %t7975 = getelementptr inbounds [49 x i8], ptr @.str.s980, i64 0, i64 0
  call void @sema_error__String(ptr %t7975)
  br label %label_2357
label_2357:
  %t7976 = load ptr, ptr %scrut_t
  %t7977 = call ptr @type_copy__Struct_TypeInfo(ptr %t7976)
  store ptr %t7977, ptr %pat_expected
  %t7978 = load ptr, ptr %scrut_t
  %t7979 = getelementptr inbounds %TypeInfo, ptr %t7978, i32 0, i32 0
  %t7980 = load i32, ptr %t7979
  %t7981 = icmp eq i32 %t7980, 9
  br i1 %t7981, label %label_2358, label %label_2360
label_2358:
  %t7982 = call ptr @type_int__Void()
  store ptr %t7982, ptr %pat_expected
  br label %label_2360
label_2360:
  %t7983 = load ptr, ptr %stmt
  %t7984 = getelementptr inbounds %ASTNode, ptr %t7983, i32 0, i32 6
  %t7985 = load ptr, ptr %t7984
  store ptr %t7985, ptr %arm_ptr
  br label %label_2361
label_2361:
  %t7986 = load ptr, ptr %arm_ptr
  %t7987 = getelementptr inbounds [1 x i8], ptr @.str.s981, i64 0, i64 0
  %t7988 = call i32 @str_equals(ptr %t7986, ptr %t7987)
  %t7989 = icmp eq i32 %t7988, 0
  br i1 %t7989, label %label_2362, label %label_2363
label_2362:
  %t7990 = load ptr, ptr %arm_ptr
  %t7991 = call ptr @ptr_to_node(ptr %t7990)
  store ptr %t7991, ptr %arm
  %t7992 = load ptr, ptr %arm
  %t7993 = getelementptr inbounds %ASTNode, ptr %t7992, i32 0, i32 1
  %t7994 = load ptr, ptr %t7993
  %t7995 = getelementptr inbounds [2 x i8], ptr @.str.s982, i64 0, i64 0
  %t7996 = call i32 @str_equals(ptr %t7994, ptr %t7995)
  %t7997 = icmp eq i32 %t7996, 0
  br i1 %t7997, label %label_2364, label %label_2366
label_2364:
  %t7998 = load ptr, ptr %module
  %t7999 = load ptr, ptr %arm
  %t8000 = getelementptr inbounds %ASTNode, ptr %t7999, i32 0, i32 5
  %t8001 = load ptr, ptr %t8000
  %t8002 = call ptr @ptr_to_node(ptr %t8001)
  %t8003 = load ptr, ptr %pat_expected
  %t8004 = getelementptr inbounds [14 x i8], ptr @.str.s983, i64 0, i64 0
  %t8005 = call ptr @sema_check_value__Struct_ASTNode_Struct_ASTNode_Struct_TypeInfo_String(ptr %t7998, ptr %t8002, ptr %t8003, ptr %t8004)
  br label %label_2366
label_2366:
  %t8006 = load ptr, ptr %module
  %t8007 = load ptr, ptr %arm
  %t8008 = getelementptr inbounds %ASTNode, ptr %t8007, i32 0, i32 6
  %t8009 = load ptr, ptr %t8008
  %t8010 = call ptr @ptr_to_node(ptr %t8009)
  %t8011 = load ptr, ptr %expected_return
  call void @sema_block__Struct_ASTNode_Struct_ASTNode_Struct_TypeInfo(ptr %t8006, ptr %t8010, ptr %t8011)
  %t8012 = load ptr, ptr %arm
  %t8013 = getelementptr inbounds %ASTNode, ptr %t8012, i32 0, i32 8
  %t8014 = load ptr, ptr %t8013
  store ptr %t8014, ptr %arm_ptr
  br label %label_2361
label_2363:
  br label %label_2354
label_2354:
  ret void
}

define void @sema_block__Struct_ASTNode_Struct_ASTNode_Struct_TypeInfo(ptr %p_module, ptr %p_block, ptr %p_expected_return) {
  %module = alloca ptr
  %block = alloca ptr
  %expected_return = alloca ptr
  %stmt_ptr = alloca ptr
  %stmt = alloca ptr
  store ptr %p_module, ptr %module
  store ptr %p_block, ptr %block
  store ptr %p_expected_return, ptr %expected_return
  %t8020 = load ptr, ptr %block
  %t8021 = getelementptr inbounds %ASTNode, ptr %t8020, i32 0, i32 5
  %t8022 = load ptr, ptr %t8021
  store ptr %t8022, ptr %stmt_ptr
  br label %label_2367
label_2367:
  %t8023 = load ptr, ptr %stmt_ptr
  %t8024 = getelementptr inbounds [1 x i8], ptr @.str.s984, i64 0, i64 0
  %t8025 = call i32 @str_equals(ptr %t8023, ptr %t8024)
  %t8026 = icmp eq i32 %t8025, 0
  br i1 %t8026, label %label_2368, label %label_2369
label_2368:
  %t8027 = load ptr, ptr %stmt_ptr
  %t8028 = call ptr @ptr_to_node(ptr %t8027)
  store ptr %t8028, ptr %stmt
  %t8029 = load ptr, ptr %module
  %t8030 = load ptr, ptr %stmt
  %t8031 = load ptr, ptr %expected_return
  call void @sema_statement__Struct_ASTNode_Struct_ASTNode_Struct_TypeInfo(ptr %t8029, ptr %t8030, ptr %t8031)
  %t8032 = load ptr, ptr %stmt
  %t8033 = getelementptr inbounds %ASTNode, ptr %t8032, i32 0, i32 8
  %t8034 = load ptr, ptr %t8033
  store ptr %t8034, ptr %stmt_ptr
  br label %label_2367
label_2369:
  ret void
}

define void @sema_predeclare_function__Struct_ASTNode_Struct_ASTNode(ptr %p_module, ptr %p_fn_node) {
  %module = alloca ptr
  %fn_node = alloca ptr
  %ret_t = alloca ptr
  %symbol = alloca ptr
  %overload_key = alloca ptr
  store ptr %p_module, ptr %module
  store ptr %p_fn_node, ptr %fn_node
  %t8040 = call ptr @type_void__Void()
  store ptr %t8040, ptr %ret_t
  %t8041 = load ptr, ptr %fn_node
  %t8042 = getelementptr inbounds %ASTNode, ptr %t8041, i32 0, i32 0
  %t8043 = load i32, ptr %t8042
  %t8044 = icmp eq i32 %t8043, 4
  br i1 %t8044, label %label_2370, label %label_2371
label_2370:
  %t8045 = load ptr, ptr %module
  %t8046 = load ptr, ptr %fn_node
  %t8047 = getelementptr inbounds %ASTNode, ptr %t8046, i32 0, i32 7
  %t8048 = load ptr, ptr %t8047
  %t8049 = call ptr @sema_declared_return_type__Struct_ASTNode_String(ptr %t8045, ptr %t8048)
  store ptr %t8049, ptr %ret_t
  %t8050 = load ptr, ptr %fn_node
  %t8051 = getelementptr inbounds %ASTNode, ptr %t8050, i32 0, i32 1
  %t8052 = load ptr, ptr %t8051
  %t8053 = getelementptr inbounds [5 x i8], ptr @.str.s985, i64 0, i64 0
  %t8054 = call i32 @str_equals(ptr %t8052, ptr %t8053)
  %t8055 = icmp eq i32 %t8054, 1
  br i1 %t8055, label %label_2373, label %label_2375
label_2373:
  %t8056 = call ptr @type_int__Void()
  store ptr %t8056, ptr %ret_t
  br label %label_2375
label_2375:
  br label %label_2372
label_2371:
  %t8057 = load ptr, ptr %module
  %t8058 = load ptr, ptr %fn_node
  %t8059 = getelementptr inbounds %ASTNode, ptr %t8058, i32 0, i32 6
  %t8060 = load ptr, ptr %t8059
  %t8061 = call ptr @sema_declared_return_type__Struct_ASTNode_String(ptr %t8057, ptr %t8060)
  store ptr %t8061, ptr %ret_t
  br label %label_2372
label_2372:
  %t8062 = load ptr, ptr %module
  %t8063 = load ptr, ptr %fn_node
  %t8064 = call ptr @sema_function_symbol__Struct_ASTNode_Struct_ASTNode(ptr %t8062, ptr %t8063)
  store ptr %t8064, ptr %symbol
  %t8065 = load ptr, ptr %fn_node
  %t8066 = load ptr, ptr %symbol
  %t8067 = getelementptr inbounds %ASTNode, ptr %t8065, i32 0, i32 2
  store ptr %t8066, ptr %t8067
  %t8068 = load ptr, ptr %symbol
  %t8069 = call ptr @sema_fn_key__String(ptr %t8068)
  store ptr %t8069, ptr %overload_key
  %t8070 = load ptr, ptr %module
  %t8071 = load ptr, ptr %symbol
  %t8072 = call i32 @sema_function_symbol_count__Struct_ASTNode_String(ptr %t8070, ptr %t8071)
  %t8073 = icmp sgt i32 %t8072, 1
  br i1 %t8073, label %label_2376, label %label_2378
label_2376:
  %t8074 = getelementptr inbounds [29 x i8], ptr @.str.s986, i64 0, i64 0
  %t8075 = load ptr, ptr %fn_node
  %t8076 = getelementptr inbounds %ASTNode, ptr %t8075, i32 0, i32 1
  %t8077 = load ptr, ptr %t8076
  %t8078 = call ptr @str_concat(ptr %t8074, ptr %t8077)
  call void @sema_error__String(ptr %t8078)
  br label %label_2378
label_2378:
  %t8079 = load ptr, ptr %overload_key
  %t8080 = load ptr, ptr %ret_t
  %t8081 = call ptr @type_sem_key__Struct_TypeInfo(ptr %t8080)
  call void @ir_set_var_type(ptr %t8079, ptr %t8081)
  ret void
}

define void @sema_predeclare_global__Struct_ASTNode_Struct_ASTNode(ptr %p_module, ptr %p_var_node) {
  %module = alloca ptr
  %var_node = alloca ptr
  %var_t = alloca ptr
  store ptr %p_module, ptr %module
  store ptr %p_var_node, ptr %var_node
  %t8085 = call ptr @type_invalid__Void()
  store ptr %t8085, ptr %var_t
  %t8086 = load ptr, ptr %var_node
  %t8087 = getelementptr inbounds %ASTNode, ptr %t8086, i32 0, i32 5
  %t8088 = load ptr, ptr %t8087
  %t8089 = getelementptr inbounds [1 x i8], ptr @.str.s987, i64 0, i64 0
  %t8090 = call i32 @str_equals(ptr %t8088, ptr %t8089)
  %t8091 = icmp eq i32 %t8090, 0
  br i1 %t8091, label %label_2379, label %label_2381
label_2379:
  %t8092 = load ptr, ptr %module
  %t8093 = load ptr, ptr %var_node
  %t8094 = getelementptr inbounds %ASTNode, ptr %t8093, i32 0, i32 5
  %t8095 = load ptr, ptr %t8094
  %t8096 = call ptr @ptr_to_node(ptr %t8095)
  %t8097 = call ptr @sema_annotation_type__Struct_ASTNode_Struct_ASTNode(ptr %t8092, ptr %t8096)
  store ptr %t8097, ptr %var_t
  br label %label_2381
label_2381:
  %t8098 = load ptr, ptr %var_node
  %t8099 = getelementptr inbounds %ASTNode, ptr %t8098, i32 0, i32 6
  %t8100 = load ptr, ptr %t8099
  %t8101 = getelementptr inbounds [1 x i8], ptr @.str.s988, i64 0, i64 0
  %t8102 = call i32 @str_equals(ptr %t8100, ptr %t8101)
  %t8103 = icmp eq i32 %t8102, 0
  br i1 %t8103, label %label_2382, label %label_2384
label_2382:
  %t8104 = load ptr, ptr %var_t
  %t8105 = call i1 @type_is_valid__Struct_TypeInfo(ptr %t8104)
  br i1 %t8105, label %label_2385, label %label_2386
label_2385:
  %t8106 = load ptr, ptr %module
  %t8107 = load ptr, ptr %var_node
  %t8108 = getelementptr inbounds %ASTNode, ptr %t8107, i32 0, i32 6
  %t8109 = load ptr, ptr %t8108
  %t8110 = call ptr @ptr_to_node(ptr %t8109)
  %t8111 = load ptr, ptr %var_t
  %t8112 = getelementptr inbounds [24 x i8], ptr @.str.s989, i64 0, i64 0
  %t8113 = load ptr, ptr %var_node
  %t8114 = getelementptr inbounds %ASTNode, ptr %t8113, i32 0, i32 1
  %t8115 = load ptr, ptr %t8114
  %t8116 = call ptr @str_concat(ptr %t8112, ptr %t8115)
  %t8117 = call ptr @sema_check_value__Struct_ASTNode_Struct_ASTNode_Struct_TypeInfo_String(ptr %t8106, ptr %t8110, ptr %t8111, ptr %t8116)
  br label %label_2387
label_2386:
  %t8118 = load ptr, ptr %module
  %t8119 = load ptr, ptr %var_node
  %t8120 = getelementptr inbounds %ASTNode, ptr %t8119, i32 0, i32 6
  %t8121 = load ptr, ptr %t8120
  %t8122 = call ptr @ptr_to_node(ptr %t8121)
  %t8123 = call ptr @sema_expr__Struct_ASTNode_Struct_ASTNode(ptr %t8118, ptr %t8122)
  store ptr %t8123, ptr %var_t
  br label %label_2387
label_2387:
  br label %label_2384
label_2384:
  %t8124 = load ptr, ptr %var_t
  %t8125 = call i1 @type_is_valid__Struct_TypeInfo(ptr %t8124)
  %t8126 = icmp eq i1 %t8125, 0
  br i1 %t8126, label %label_2388, label %label_2390
label_2388:
  %t8127 = getelementptr inbounds [30 x i8], ptr @.str.s990, i64 0, i64 0
  %t8128 = load ptr, ptr %var_node
  %t8129 = getelementptr inbounds %ASTNode, ptr %t8128, i32 0, i32 1
  %t8130 = load ptr, ptr %t8129
  %t8131 = call ptr @str_concat(ptr %t8127, ptr %t8130)
  call void @sema_error__String(ptr %t8131)
  br label %label_2390
label_2390:
  %t8132 = load ptr, ptr %var_node
  %t8133 = getelementptr inbounds %ASTNode, ptr %t8132, i32 0, i32 1
  %t8134 = load ptr, ptr %t8133
  call void @ir_register_global_name(ptr %t8134)
  %t8135 = load ptr, ptr %var_node
  %t8136 = getelementptr inbounds %ASTNode, ptr %t8135, i32 0, i32 1
  %t8137 = load ptr, ptr %t8136
  %t8138 = load ptr, ptr %var_t
  %t8139 = call ptr @type_sem_key__Struct_TypeInfo(ptr %t8138)
  call void @ir_set_var_type(ptr %t8137, ptr %t8139)
  %t8140 = load ptr, ptr %var_node
  %t8141 = load ptr, ptr %var_t
  call void @node_set_type__Struct_ASTNode_Struct_TypeInfo(ptr %t8140, ptr %t8141)
  ret void
}

define void @sema_function__Struct_ASTNode_Struct_ASTNode(ptr %p_module, ptr %p_fn_node) {
  %module = alloca ptr
  %fn_node = alloca ptr
  %expected_return = alloca ptr
  %param_ptr = alloca ptr
  %param = alloca ptr
  %param_t = alloca ptr
  store ptr %p_module, ptr %module
  store ptr %p_fn_node, ptr %fn_node
  call void @ir_clear_local_var_types()
  call void @ir_clear_moved()
  call void @ir_clear_borrowed()
  %t8148 = load ptr, ptr %module
  %t8149 = load ptr, ptr %fn_node
  %t8150 = getelementptr inbounds %ASTNode, ptr %t8149, i32 0, i32 7
  %t8151 = load ptr, ptr %t8150
  %t8152 = call ptr @sema_declared_return_type__Struct_ASTNode_String(ptr %t8148, ptr %t8151)
  store ptr %t8152, ptr %expected_return
  %t8153 = load ptr, ptr %fn_node
  %t8154 = getelementptr inbounds %ASTNode, ptr %t8153, i32 0, i32 1
  %t8155 = load ptr, ptr %t8154
  %t8156 = getelementptr inbounds [5 x i8], ptr @.str.s991, i64 0, i64 0
  %t8157 = call i32 @str_equals(ptr %t8155, ptr %t8156)
  %t8158 = icmp eq i32 %t8157, 1
  br i1 %t8158, label %label_2391, label %label_2393
label_2391:
  %t8159 = call ptr @type_int__Void()
  store ptr %t8159, ptr %expected_return
  br label %label_2393
label_2393:
  %t8160 = load ptr, ptr %fn_node
  %t8161 = getelementptr inbounds %ASTNode, ptr %t8160, i32 0, i32 5
  %t8162 = load ptr, ptr %t8161
  store ptr %t8162, ptr %param_ptr
  br label %label_2394
label_2394:
  %t8163 = load ptr, ptr %param_ptr
  %t8164 = getelementptr inbounds [1 x i8], ptr @.str.s992, i64 0, i64 0
  %t8165 = call i32 @str_equals(ptr %t8163, ptr %t8164)
  %t8166 = icmp eq i32 %t8165, 0
  br i1 %t8166, label %label_2395, label %label_2396
label_2395:
  %t8167 = load ptr, ptr %param_ptr
  %t8168 = call ptr @ptr_to_node(ptr %t8167)
  store ptr %t8168, ptr %param
  %t8169 = load ptr, ptr %module
  %t8170 = load ptr, ptr %param
  %t8171 = getelementptr inbounds %ASTNode, ptr %t8170, i32 0, i32 5
  %t8172 = load ptr, ptr %t8171
  %t8173 = call ptr @ptr_to_node(ptr %t8172)
  %t8174 = call ptr @sema_annotation_type__Struct_ASTNode_Struct_ASTNode(ptr %t8169, ptr %t8173)
  store ptr %t8174, ptr %param_t
  %t8175 = load ptr, ptr %param
  %t8176 = getelementptr inbounds %ASTNode, ptr %t8175, i32 0, i32 2
  %t8177 = load ptr, ptr %t8176
  %t8178 = getelementptr inbounds [6 x i8], ptr @.str.s993, i64 0, i64 0
  %t8179 = call i32 @str_equals(ptr %t8177, ptr %t8178)
  %t8180 = icmp eq i32 %t8179, 1
  %t8181 = load ptr, ptr %param_t
  %t8182 = call i1 @type_is_move_only__Struct_TypeInfo(ptr %t8181)
  %t8183 = icmp eq i1 %t8182, 0
  %t8184 = and i1 %t8180, %t8183
  br i1 %t8184, label %label_2397, label %label_2399
label_2397:
  %t8185 = getelementptr inbounds [52 x i8], ptr @.str.s994, i64 0, i64 0
  %t8186 = load ptr, ptr %param
  %t8187 = getelementptr inbounds %ASTNode, ptr %t8186, i32 0, i32 1
  %t8188 = load ptr, ptr %t8187
  %t8189 = call ptr @str_concat(ptr %t8185, ptr %t8188)
  call void @sema_error__String(ptr %t8189)
  br label %label_2399
label_2399:
  %t8190 = load ptr, ptr %param
  %t8191 = getelementptr inbounds %ASTNode, ptr %t8190, i32 0, i32 2
  %t8192 = load ptr, ptr %t8191
  %t8193 = getelementptr inbounds [5 x i8], ptr @.str.s995, i64 0, i64 0
  %t8194 = call i32 @str_equals(ptr %t8192, ptr %t8193)
  %t8195 = icmp eq i32 %t8194, 0
  br i1 %t8195, label %label_2400, label %label_2402
label_2400:
  %t8196 = load ptr, ptr %param
  %t8197 = getelementptr inbounds %ASTNode, ptr %t8196, i32 0, i32 1
  %t8198 = load ptr, ptr %t8197
  call void @ir_mark_borrowed(ptr %t8198)
  br label %label_2402
label_2402:
  %t8199 = load ptr, ptr %param
  %t8200 = getelementptr inbounds %ASTNode, ptr %t8199, i32 0, i32 1
  %t8201 = load ptr, ptr %t8200
  %t8202 = load ptr, ptr %param_t
  %t8203 = call ptr @type_sem_key__Struct_TypeInfo(ptr %t8202)
  call void @ir_set_var_type(ptr %t8201, ptr %t8203)
  %t8204 = load ptr, ptr %param
  %t8205 = load ptr, ptr %param_t
  call void @node_set_type__Struct_ASTNode_Struct_TypeInfo(ptr %t8204, ptr %t8205)
  %t8206 = load ptr, ptr %param
  %t8207 = getelementptr inbounds %ASTNode, ptr %t8206, i32 0, i32 8
  %t8208 = load ptr, ptr %t8207
  store ptr %t8208, ptr %param_ptr
  br label %label_2394
label_2396:
  %t8209 = load ptr, ptr %fn_node
  %t8210 = getelementptr inbounds %ASTNode, ptr %t8209, i32 0, i32 6
  %t8211 = load ptr, ptr %t8210
  %t8212 = getelementptr inbounds [1 x i8], ptr @.str.s996, i64 0, i64 0
  %t8213 = call i32 @str_equals(ptr %t8211, ptr %t8212)
  %t8214 = icmp eq i32 %t8213, 0
  br i1 %t8214, label %label_2403, label %label_2405
label_2403:
  %t8215 = load ptr, ptr %module
  %t8216 = load ptr, ptr %fn_node
  %t8217 = getelementptr inbounds %ASTNode, ptr %t8216, i32 0, i32 6
  %t8218 = load ptr, ptr %t8217
  %t8219 = call ptr @ptr_to_node(ptr %t8218)
  %t8220 = load ptr, ptr %expected_return
  call void @sema_block__Struct_ASTNode_Struct_ASTNode_Struct_TypeInfo(ptr %t8215, ptr %t8219, ptr %t8220)
  br label %label_2405
label_2405:
  ret void
}

define void @analyze_module__Struct_ASTNode(ptr %p_module) {
  %module = alloca ptr
  %fn_ptr = alloca ptr
  %stmt = alloca ptr
  %global_ptr = alloca ptr
  %stmt2 = alloca ptr
  %stmt_ptr = alloca ptr
  %stmt3 = alloca ptr
  store ptr %p_module, ptr %module
  call void @ir_clear_var_types()
  call void @ir_reset_globals()
  %t8228 = load ptr, ptr %module
  %t8229 = getelementptr inbounds %ASTNode, ptr %t8228, i32 0, i32 5
  %t8230 = load ptr, ptr %t8229
  store ptr %t8230, ptr %fn_ptr
  br label %label_2406
label_2406:
  %t8231 = load ptr, ptr %fn_ptr
  %t8232 = getelementptr inbounds [1 x i8], ptr @.str.s997, i64 0, i64 0
  %t8233 = call i32 @str_equals(ptr %t8231, ptr %t8232)
  %t8234 = icmp eq i32 %t8233, 0
  br i1 %t8234, label %label_2407, label %label_2408
label_2407:
  %t8235 = load ptr, ptr %fn_ptr
  %t8236 = call ptr @ptr_to_node(ptr %t8235)
  store ptr %t8236, ptr %stmt
  %t8237 = load ptr, ptr %stmt
  %t8238 = getelementptr inbounds %ASTNode, ptr %t8237, i32 0, i32 0
  %t8239 = load i32, ptr %t8238
  %t8240 = icmp eq i32 %t8239, 4
  %t8241 = load ptr, ptr %stmt
  %t8242 = getelementptr inbounds %ASTNode, ptr %t8241, i32 0, i32 0
  %t8243 = load i32, ptr %t8242
  %t8244 = icmp eq i32 %t8243, 2
  %t8245 = or i1 %t8240, %t8244
  br i1 %t8245, label %label_2409, label %label_2411
label_2409:
  %t8246 = load ptr, ptr %module
  %t8247 = load ptr, ptr %stmt
  call void @sema_predeclare_function__Struct_ASTNode_Struct_ASTNode(ptr %t8246, ptr %t8247)
  br label %label_2411
label_2411:
  %t8248 = load ptr, ptr %stmt
  %t8249 = getelementptr inbounds %ASTNode, ptr %t8248, i32 0, i32 8
  %t8250 = load ptr, ptr %t8249
  store ptr %t8250, ptr %fn_ptr
  br label %label_2406
label_2408:
  %t8251 = load ptr, ptr %module
  %t8252 = getelementptr inbounds %ASTNode, ptr %t8251, i32 0, i32 5
  %t8253 = load ptr, ptr %t8252
  store ptr %t8253, ptr %global_ptr
  br label %label_2412
label_2412:
  %t8254 = load ptr, ptr %global_ptr
  %t8255 = getelementptr inbounds [1 x i8], ptr @.str.s998, i64 0, i64 0
  %t8256 = call i32 @str_equals(ptr %t8254, ptr %t8255)
  %t8257 = icmp eq i32 %t8256, 0
  br i1 %t8257, label %label_2413, label %label_2414
label_2413:
  %t8258 = load ptr, ptr %global_ptr
  %t8259 = call ptr @ptr_to_node(ptr %t8258)
  store ptr %t8259, ptr %stmt2
  %t8260 = load ptr, ptr %stmt2
  %t8261 = getelementptr inbounds %ASTNode, ptr %t8260, i32 0, i32 0
  %t8262 = load i32, ptr %t8261
  %t8263 = icmp eq i32 %t8262, 3
  br i1 %t8263, label %label_2415, label %label_2417
label_2415:
  %t8264 = load ptr, ptr %module
  %t8265 = load ptr, ptr %stmt2
  call void @sema_predeclare_global__Struct_ASTNode_Struct_ASTNode(ptr %t8264, ptr %t8265)
  br label %label_2417
label_2417:
  %t8266 = load ptr, ptr %stmt2
  %t8267 = getelementptr inbounds %ASTNode, ptr %t8266, i32 0, i32 8
  %t8268 = load ptr, ptr %t8267
  store ptr %t8268, ptr %global_ptr
  br label %label_2412
label_2414:
  %t8269 = load ptr, ptr %module
  %t8270 = getelementptr inbounds %ASTNode, ptr %t8269, i32 0, i32 5
  %t8271 = load ptr, ptr %t8270
  store ptr %t8271, ptr %stmt_ptr
  br label %label_2418
label_2418:
  %t8272 = load ptr, ptr %stmt_ptr
  %t8273 = getelementptr inbounds [1 x i8], ptr @.str.s999, i64 0, i64 0
  %t8274 = call i32 @str_equals(ptr %t8272, ptr %t8273)
  %t8275 = icmp eq i32 %t8274, 0
  br i1 %t8275, label %label_2419, label %label_2420
label_2419:
  %t8276 = load ptr, ptr %stmt_ptr
  %t8277 = call ptr @ptr_to_node(ptr %t8276)
  store ptr %t8277, ptr %stmt3
  %t8278 = load ptr, ptr %stmt3
  %t8279 = getelementptr inbounds %ASTNode, ptr %t8278, i32 0, i32 0
  %t8280 = load i32, ptr %t8279
  %t8281 = icmp eq i32 %t8280, 4
  br i1 %t8281, label %label_2421, label %label_2423
label_2421:
  %t8282 = load ptr, ptr %module
  %t8283 = load ptr, ptr %stmt3
  call void @sema_function__Struct_ASTNode_Struct_ASTNode(ptr %t8282, ptr %t8283)
  br label %label_2423
label_2423:
  %t8284 = load ptr, ptr %stmt3
  %t8285 = getelementptr inbounds %ASTNode, ptr %t8284, i32 0, i32 8
  %t8286 = load ptr, ptr %t8285
  store ptr %t8286, ptr %stmt_ptr
  br label %label_2418
label_2420:
  ret void
}

define i1 @is_named_top_level__Struct_ASTNode(ptr %p_stmt) {
  %stmt = alloca ptr
  store ptr %p_stmt, ptr %stmt
  %t8288 = load ptr, ptr %stmt
  %t8289 = getelementptr inbounds %ASTNode, ptr %t8288, i32 0, i32 0
  %t8290 = load i32, ptr %t8289
  %t8291 = icmp eq i32 %t8290, 2
  br i1 %t8291, label %label_2424, label %label_2426
label_2424:
  ret i1 1
label_2426:
  %t8292 = load ptr, ptr %stmt
  %t8293 = getelementptr inbounds %ASTNode, ptr %t8292, i32 0, i32 0
  %t8294 = load i32, ptr %t8293
  %t8295 = icmp eq i32 %t8294, 3
  br i1 %t8295, label %label_2427, label %label_2429
label_2427:
  ret i1 1
label_2429:
  %t8296 = load ptr, ptr %stmt
  %t8297 = getelementptr inbounds %ASTNode, ptr %t8296, i32 0, i32 0
  %t8298 = load i32, ptr %t8297
  %t8299 = icmp eq i32 %t8298, 4
  br i1 %t8299, label %label_2430, label %label_2432
label_2430:
  ret i1 1
label_2432:
  %t8300 = load ptr, ptr %stmt
  %t8301 = getelementptr inbounds %ASTNode, ptr %t8300, i32 0, i32 0
  %t8302 = load i32, ptr %t8301
  %t8303 = icmp eq i32 %t8302, 5
  br i1 %t8303, label %label_2433, label %label_2435
label_2433:
  ret i1 1
label_2435:
  %t8304 = load ptr, ptr %stmt
  %t8305 = getelementptr inbounds %ASTNode, ptr %t8304, i32 0, i32 0
  %t8306 = load i32, ptr %t8305
  %t8307 = icmp eq i32 %t8306, 6
  br i1 %t8307, label %label_2436, label %label_2438
label_2436:
  ret i1 1
label_2438:
  ret i1 0
}

define i1 @same_top_level_name__Struct_ASTNode_Struct_ASTNode(ptr %p_a, ptr %p_b) {
  %a = alloca ptr
  %b = alloca ptr
  store ptr %p_a, ptr %a
  store ptr %p_b, ptr %b
  %t8310 = load ptr, ptr %a
  %t8311 = getelementptr inbounds %ASTNode, ptr %t8310, i32 0, i32 0
  %t8312 = load i32, ptr %t8311
  %t8313 = load ptr, ptr %b
  %t8314 = getelementptr inbounds %ASTNode, ptr %t8313, i32 0, i32 0
  %t8315 = load i32, ptr %t8314
  %t8316 = icmp ne i32 %t8312, %t8315
  br i1 %t8316, label %label_2439, label %label_2441
label_2439:
  ret i1 0
label_2441:
  %t8317 = load ptr, ptr %a
  %t8318 = getelementptr inbounds %ASTNode, ptr %t8317, i32 0, i32 1
  %t8319 = load ptr, ptr %t8318
  %t8320 = load ptr, ptr %b
  %t8321 = getelementptr inbounds %ASTNode, ptr %t8320, i32 0, i32 1
  %t8322 = load ptr, ptr %t8321
  %t8323 = call i32 @str_equals(ptr %t8319, ptr %t8322)
  %t8324 = icmp eq i32 %t8323, 0
  br i1 %t8324, label %label_2442, label %label_2444
label_2442:
  ret i1 0
label_2444:
  %t8325 = load ptr, ptr %a
  %t8326 = getelementptr inbounds %ASTNode, ptr %t8325, i32 0, i32 0
  %t8327 = load i32, ptr %t8326
  %t8328 = icmp eq i32 %t8327, 4
  br i1 %t8328, label %label_2445, label %label_2447
label_2445:
  ret i1 0
label_2447:
  ret i1 1
}

define i1 @has_named_top_level__Struct_ASTNode_Struct_ASTNode(ptr %p_module, ptr %p_stmt) {
  %module = alloca ptr
  %stmt = alloca ptr
  %scan_ptr = alloca ptr
  %scan = alloca ptr
  store ptr %p_module, ptr %module
  store ptr %p_stmt, ptr %stmt
  %t8333 = load ptr, ptr %stmt
  %t8334 = call i1 @is_named_top_level__Struct_ASTNode(ptr %t8333)
  %t8335 = icmp eq i1 %t8334, 0
  br i1 %t8335, label %label_2448, label %label_2450
label_2448:
  ret i1 0
label_2450:
  %t8336 = load ptr, ptr %module
  %t8337 = getelementptr inbounds %ASTNode, ptr %t8336, i32 0, i32 5
  %t8338 = load ptr, ptr %t8337
  store ptr %t8338, ptr %scan_ptr
  br label %label_2451
label_2451:
  %t8339 = load ptr, ptr %scan_ptr
  %t8340 = getelementptr inbounds [1 x i8], ptr @.str.s1000, i64 0, i64 0
  %t8341 = call i32 @str_equals(ptr %t8339, ptr %t8340)
  %t8342 = icmp eq i32 %t8341, 0
  br i1 %t8342, label %label_2452, label %label_2453
label_2452:
  %t8343 = load ptr, ptr %scan_ptr
  %t8344 = call ptr @ptr_to_node(ptr %t8343)
  store ptr %t8344, ptr %scan
  %t8345 = load ptr, ptr %scan
  %t8346 = load ptr, ptr %stmt
  %t8347 = call i1 @same_top_level_name__Struct_ASTNode_Struct_ASTNode(ptr %t8345, ptr %t8346)
  br i1 %t8347, label %label_2454, label %label_2456
label_2454:
  ret i1 1
label_2456:
  %t8348 = load ptr, ptr %scan
  %t8349 = getelementptr inbounds %ASTNode, ptr %t8348, i32 0, i32 8
  %t8350 = load ptr, ptr %t8349
  store ptr %t8350, ptr %scan_ptr
  br label %label_2451
label_2453:
  ret i1 0
}

define ptr @parse_source__String(ptr %p_content) {
  %content = alloca ptr
  %lex = alloca ptr
  %head_token = alloca ptr
  %p = alloca ptr
  store ptr %p_content, ptr %content
  %t8355 = load ptr, ptr %content
  %t8356 = call ptr @create_lexer__String(ptr %t8355)
  store ptr %t8356, ptr %lex
  %t8357 = load ptr, ptr %lex
  %t8358 = call ptr @lex_all_tokens__Struct_Lexer(ptr %t8357)
  store ptr %t8358, ptr %head_token
  %t8359 = load ptr, ptr %head_token
  %t8360 = call ptr @parser_create__Struct_Token(ptr %t8359)
  store ptr %t8360, ptr %p
  %t8361 = load ptr, ptr %p
  %t8362 = call ptr @parse_module__Struct_Parser(ptr %t8361)
  ret ptr %t8362
}

define void @append_statement__Struct_ASTNode_Struct_ASTNode(ptr %p_module, ptr %p_stmt) {
  %module = alloca ptr
  %stmt = alloca ptr
  %tail_ptr = alloca ptr
  %searching = alloca i1
  %tail = alloca ptr
  store ptr %p_module, ptr %module
  store ptr %p_stmt, ptr %stmt
  %t8368 = load ptr, ptr %module
  %t8369 = load ptr, ptr %stmt
  %t8370 = call i1 @has_named_top_level__Struct_ASTNode_Struct_ASTNode(ptr %t8368, ptr %t8369)
  br i1 %t8370, label %label_2457, label %label_2459
label_2457:
  ret void
label_2459:
  %t8371 = load ptr, ptr %module
  %t8372 = getelementptr inbounds %ASTNode, ptr %t8371, i32 0, i32 5
  %t8373 = load ptr, ptr %t8372
  %t8374 = getelementptr inbounds [1 x i8], ptr @.str.s1001, i64 0, i64 0
  %t8375 = call i32 @str_equals(ptr %t8373, ptr %t8374)
  %t8376 = icmp eq i32 %t8375, 1
  br i1 %t8376, label %label_2460, label %label_2462
label_2460:
  %t8377 = load ptr, ptr %module
  %t8378 = load ptr, ptr %stmt
  %t8379 = call ptr @node_to_ptr(ptr %t8378)
  %t8380 = getelementptr inbounds %ASTNode, ptr %t8377, i32 0, i32 5
  store ptr %t8379, ptr %t8380
  ret void
label_2462:
  %t8381 = load ptr, ptr %module
  %t8382 = getelementptr inbounds %ASTNode, ptr %t8381, i32 0, i32 5
  %t8383 = load ptr, ptr %t8382
  store ptr %t8383, ptr %tail_ptr
  store i1 1, ptr %searching
  br label %label_2463
label_2463:
  %t8384 = load i1, ptr %searching
  br i1 %t8384, label %label_2464, label %label_2465
label_2464:
  %t8385 = load ptr, ptr %tail_ptr
  %t8386 = call ptr @ptr_to_node(ptr %t8385)
  store ptr %t8386, ptr %tail
  %t8387 = load ptr, ptr %tail
  %t8388 = getelementptr inbounds %ASTNode, ptr %t8387, i32 0, i32 8
  %t8389 = load ptr, ptr %t8388
  %t8390 = getelementptr inbounds [1 x i8], ptr @.str.s1002, i64 0, i64 0
  %t8391 = call i32 @str_equals(ptr %t8389, ptr %t8390)
  %t8392 = icmp eq i32 %t8391, 1
  br i1 %t8392, label %label_2466, label %label_2467
label_2466:
  %t8393 = load ptr, ptr %tail
  %t8394 = load ptr, ptr %stmt
  %t8395 = call ptr @node_to_ptr(ptr %t8394)
  %t8396 = getelementptr inbounds %ASTNode, ptr %t8393, i32 0, i32 8
  store ptr %t8395, ptr %t8396
  store i1 0, ptr %searching
  br label %label_2468
label_2467:
  %t8397 = load ptr, ptr %tail
  %t8398 = getelementptr inbounds %ASTNode, ptr %t8397, i32 0, i32 8
  %t8399 = load ptr, ptr %t8398
  store ptr %t8399, ptr %tail_ptr
  br label %label_2468
label_2468:
  br label %label_2463
label_2465:
  ret void
}

define ptr @join_import_path__String_String(ptr %p_base_dir, ptr %p_module_name) {
  %base_dir = alloca ptr
  %module_name = alloca ptr
  %module_file = alloca ptr
  store ptr %p_base_dir, ptr %base_dir
  store ptr %p_module_name, ptr %module_name
  %t8403 = load ptr, ptr %module_name
  %t8404 = getelementptr inbounds [5 x i8], ptr @.str.s1003, i64 0, i64 0
  %t8405 = call ptr @str_concat(ptr %t8403, ptr %t8404)
  store ptr %t8405, ptr %module_file
  %t8406 = load ptr, ptr %base_dir
  %t8407 = getelementptr inbounds [2 x i8], ptr @.str.s1004, i64 0, i64 0
  %t8408 = call i32 @str_equals(ptr %t8406, ptr %t8407)
  %t8409 = icmp eq i32 %t8408, 1
  br i1 %t8409, label %label_2469, label %label_2471
label_2469:
  %t8410 = load ptr, ptr %module_file
  ret ptr %t8410
label_2471:
  %t8411 = load ptr, ptr %base_dir
  %t8412 = load ptr, ptr %module_file
  %t8413 = call ptr @join_path(ptr %t8411, ptr %t8412)
  ret ptr %t8413
}

define ptr @import_memo_key__String(ptr %p_import_path) {
  %import_path = alloca ptr
  store ptr %p_import_path, ptr %import_path
  %t8415 = getelementptr inbounds [2 x i8], ptr @.str.s1005, i64 0, i64 0
  %t8416 = load ptr, ptr %import_path
  %t8417 = call ptr @str_concat(ptr %t8415, ptr %t8416)
  %t8418 = getelementptr inbounds [2 x i8], ptr @.str.s1006, i64 0, i64 0
  %t8419 = call ptr @str_concat(ptr %t8417, ptr %t8418)
  ret ptr %t8419
}

define ptr @merge_module_imports__Struct_ASTNode_Struct_ASTNode_String_String(ptr %p_merged, ptr %p_module, ptr %p_base_dir, ptr %p_visited) {
  %merged = alloca ptr
  %module = alloca ptr
  %base_dir = alloca ptr
  %visited = alloca ptr
  %seen = alloca ptr
  %stmt_ptr = alloca ptr
  %stmt = alloca ptr
  %next_stmt = alloca ptr
  %import_path = alloca ptr
  %key = alloca ptr
  %import_content = alloca ptr
  %imported_module = alloca ptr
  store ptr %p_merged, ptr %merged
  store ptr %p_module, ptr %module
  store ptr %p_base_dir, ptr %base_dir
  store ptr %p_visited, ptr %visited
  %t8432 = load ptr, ptr %visited
  store ptr %t8432, ptr %seen
  %t8433 = load ptr, ptr %module
  %t8434 = getelementptr inbounds %ASTNode, ptr %t8433, i32 0, i32 5
  %t8435 = load ptr, ptr %t8434
  store ptr %t8435, ptr %stmt_ptr
  br label %label_2472
label_2472:
  %t8436 = load ptr, ptr %stmt_ptr
  %t8437 = getelementptr inbounds [1 x i8], ptr @.str.s1007, i64 0, i64 0
  %t8438 = call i32 @str_equals(ptr %t8436, ptr %t8437)
  %t8439 = icmp eq i32 %t8438, 0
  br i1 %t8439, label %label_2473, label %label_2474
label_2473:
  %t8440 = load ptr, ptr %stmt_ptr
  %t8441 = call ptr @ptr_to_node(ptr %t8440)
  store ptr %t8441, ptr %stmt
  %t8442 = load ptr, ptr %stmt
  %t8443 = getelementptr inbounds %ASTNode, ptr %t8442, i32 0, i32 8
  %t8444 = load ptr, ptr %t8443
  store ptr %t8444, ptr %next_stmt
  %t8445 = load ptr, ptr %stmt
  %t8446 = getelementptr inbounds [1 x i8], ptr @.str.s1008, i64 0, i64 0
  %t8447 = getelementptr inbounds %ASTNode, ptr %t8445, i32 0, i32 8
  store ptr %t8446, ptr %t8447
  %t8448 = load ptr, ptr %stmt
  %t8449 = getelementptr inbounds %ASTNode, ptr %t8448, i32 0, i32 0
  %t8450 = load i32, ptr %t8449
  %t8451 = icmp eq i32 %t8450, 1
  br i1 %t8451, label %label_2475, label %label_2476
label_2475:
  %t8452 = load ptr, ptr %base_dir
  %t8453 = load ptr, ptr %stmt
  %t8454 = getelementptr inbounds %ASTNode, ptr %t8453, i32 0, i32 1
  %t8455 = load ptr, ptr %t8454
  %t8456 = call ptr @join_import_path__String_String(ptr %t8452, ptr %t8455)
  store ptr %t8456, ptr %import_path
  %t8457 = load ptr, ptr %import_path
  %t8458 = call ptr @import_memo_key__String(ptr %t8457)
  store ptr %t8458, ptr %key
  %t8459 = load ptr, ptr %seen
  %t8460 = load ptr, ptr %key
  %t8461 = call i32 @str_contains(ptr %t8459, ptr %t8460)
  %t8462 = icmp eq i32 %t8461, 0
  br i1 %t8462, label %label_2478, label %label_2480
label_2478:
  %t8463 = load ptr, ptr %seen
  %t8464 = load ptr, ptr %key
  %t8465 = call ptr @str_concat(ptr %t8463, ptr %t8464)
  store ptr %t8465, ptr %seen
  %t8466 = load ptr, ptr %import_path
  %t8467 = call ptr @read_file(ptr %t8466)
  store ptr %t8467, ptr %import_content
  %t8468 = load ptr, ptr %import_content
  %t8469 = getelementptr inbounds [1 x i8], ptr @.str.s1009, i64 0, i64 0
  %t8470 = call i32 @str_equals(ptr %t8468, ptr %t8469)
  %t8471 = icmp eq i32 %t8470, 1
  br i1 %t8471, label %label_2481, label %label_2483
label_2481:
  %t8472 = getelementptr inbounds [25 x i8], ptr @.str.s1010, i64 0, i64 0
  call void @print(ptr %t8472)
  %t8473 = load ptr, ptr %import_path
  call void @println(ptr %t8473)
  call void @exit(i32 1)
  br label %label_2483
label_2483:
  %t8474 = load ptr, ptr %import_content
  %t8475 = call ptr @parse_source__String(ptr %t8474)
  store ptr %t8475, ptr %imported_module
  %t8476 = load ptr, ptr %merged
  %t8477 = load ptr, ptr %imported_module
  %t8478 = load ptr, ptr %base_dir
  %t8479 = load ptr, ptr %seen
  %t8480 = call ptr @merge_module_imports__Struct_ASTNode_Struct_ASTNode_String_String(ptr %t8476, ptr %t8477, ptr %t8478, ptr %t8479)
  store ptr %t8480, ptr %seen
  br label %label_2480
label_2480:
  br label %label_2477
label_2476:
  %t8481 = load ptr, ptr %merged
  %t8482 = load ptr, ptr %stmt
  call void @append_statement__Struct_ASTNode_Struct_ASTNode(ptr %t8481, ptr %t8482)
  br label %label_2477
label_2477:
  %t8483 = load ptr, ptr %next_stmt
  store ptr %t8483, ptr %stmt_ptr
  br label %label_2472
label_2474:
  %t8484 = load ptr, ptr %seen
  ret ptr %t8484
}

define ptr @resolve_imports__Struct_ASTNode_String(ptr %p_module, ptr %p_base_dir) {
  %module = alloca ptr
  %base_dir = alloca ptr
  %merged = alloca ptr
  store ptr %p_module, ptr %module
  store ptr %p_base_dir, ptr %base_dir
  %t8488 = call ptr @create_node__Enum_NodeKind(i32 0)
  store ptr %t8488, ptr %merged
  %t8489 = load ptr, ptr %merged
  %t8490 = load ptr, ptr %module
  %t8491 = load ptr, ptr %base_dir
  %t8492 = getelementptr inbounds [1 x i8], ptr @.str.s1011, i64 0, i64 0
  %t8493 = call ptr @merge_module_imports__Struct_ASTNode_Struct_ASTNode_String_String(ptr %t8489, ptr %t8490, ptr %t8491, ptr %t8492)
  %t8494 = load ptr, ptr %merged
  ret ptr %t8494
}

define void @print_usage__Void() {
  %t8495 = getelementptr inbounds [7 x i8], ptr @.str.s1012, i64 0, i64 0
  call void @println(ptr %t8495)
  %t8496 = getelementptr inbounds [45 x i8], ptr @.str.s1013, i64 0, i64 0
  call void @println(ptr %t8496)
  %t8497 = getelementptr inbounds [43 x i8], ptr @.str.s1014, i64 0, i64 0
  call void @println(ptr %t8497)
  %t8498 = getelementptr inbounds [49 x i8], ptr @.str.s1015, i64 0, i64 0
  call void @println(ptr %t8498)
  %t8499 = getelementptr inbounds [23 x i8], ptr @.str.s1016, i64 0, i64 0
  call void @println(ptr %t8499)
  %t8500 = getelementptr inbounds [1 x i8], ptr @.str.s1017, i64 0, i64 0
  call void @println(ptr %t8500)
  %t8501 = getelementptr inbounds [59 x i8], ptr @.str.s1018, i64 0, i64 0
  call void @println(ptr %t8501)
  %t8502 = getelementptr inbounds [66 x i8], ptr @.str.s1019, i64 0, i64 0
  call void @println(ptr %t8502)
  %t8503 = getelementptr inbounds [71 x i8], ptr @.str.s1020, i64 0, i64 0
  call void @println(ptr %t8503)
  ret void
}

define void @check_runtime_freshness__Void() {
  %installed = alloca ptr
  %current = alloca ptr
  %t8506 = call ptr @compiler_installed_runtime_hash()
  store ptr %t8506, ptr %installed
  %t8507 = load ptr, ptr %installed
  %t8508 = getelementptr inbounds [1 x i8], ptr @.str.s1021, i64 0, i64 0
  %t8509 = call i32 @str_equals(ptr %t8507, ptr %t8508)
  %t8510 = icmp eq i32 %t8509, 1
  br i1 %t8510, label %label_2484, label %label_2486
label_2484:
  ret void
label_2486:
  %t8511 = call ptr @compiler_runtime_source_hash()
  store ptr %t8511, ptr %current
  %t8512 = load ptr, ptr %current
  %t8513 = getelementptr inbounds [1 x i8], ptr @.str.s1022, i64 0, i64 0
  %t8514 = call i32 @str_equals(ptr %t8512, ptr %t8513)
  %t8515 = icmp eq i32 %t8514, 1
  br i1 %t8515, label %label_2487, label %label_2489
label_2487:
  ret void
label_2489:
  %t8516 = load ptr, ptr %installed
  %t8517 = load ptr, ptr %current
  %t8518 = call i32 @str_equals(ptr %t8516, ptr %t8517)
  %t8519 = icmp eq i32 %t8518, 1
  br i1 %t8519, label %label_2490, label %label_2492
label_2490:
  ret void
label_2492:
  %t8520 = getelementptr inbounds [55 x i8], ptr @.str.s1023, i64 0, i64 0
  call void @println(ptr %t8520)
  %t8521 = getelementptr inbounds [50 x i8], ptr @.str.s1024, i64 0, i64 0
  call void @print(ptr %t8521)
  %t8522 = load ptr, ptr %installed
  call void @println(ptr %t8522)
  %t8523 = getelementptr inbounds [40 x i8], ptr @.str.s1025, i64 0, i64 0
  call void @print(ptr %t8523)
  %t8524 = load ptr, ptr %current
  call void @println(ptr %t8524)
  %t8525 = getelementptr inbounds [73 x i8], ptr @.str.s1026, i64 0, i64 0
  call void @println(ptr %t8525)
  %t8526 = getelementptr inbounds [72 x i8], ptr @.str.s1027, i64 0, i64 0
  call void @println(ptr %t8526)
  call void @exit(i32 1)
  ret void
}

define i32 @compile_source__String_String_Bool_Bool(ptr %p_path, ptr %p_output_file, i1 %p_run_after_build, i1 %p_bootstrap_mode) {
  %path = alloca ptr
  %output_file = alloca ptr
  %run_after_build = alloca i1
  %bootstrap_mode = alloca i1
  %out_file = alloca ptr
  %emit_ir_only = alloca i1
  %content = alloca ptr
  %lex = alloca ptr
  %head_token = alloca ptr
  %p = alloca ptr
  %ast_root = alloca ptr
  %base_dir = alloca ptr
  %merged_ast = alloca ptr
  %build_failed = alloca i32
  store ptr %p_path, ptr %path
  store ptr %p_output_file, ptr %output_file
  store i1 %p_run_after_build, ptr %run_after_build
  store i1 %p_bootstrap_mode, ptr %bootstrap_mode
  %t8541 = getelementptr inbounds [1 x i8], ptr @.str.s1028, i64 0, i64 0
  store ptr %t8541, ptr %out_file
  store i1 0, ptr %emit_ir_only
  %t8542 = load i1, ptr %bootstrap_mode
  %t8543 = icmp eq i1 %t8542, 0
  br i1 %t8543, label %label_2493, label %label_2495
label_2493:
  call void @check_runtime_freshness__Void()
  br label %label_2495
label_2495:
  %t8544 = load ptr, ptr %output_file
  %t8545 = getelementptr inbounds [4 x i8], ptr @.str.s1029, i64 0, i64 0
  %t8546 = call i32 @str_ends_with(ptr %t8544, ptr %t8545)
  %t8547 = icmp eq i32 %t8546, 1
  br i1 %t8547, label %label_2496, label %label_2497
label_2496:
  %t8548 = load ptr, ptr %output_file
  store ptr %t8548, ptr %out_file
  store i1 1, ptr %emit_ir_only
  br label %label_2498
label_2497:
  %t8549 = load ptr, ptr %path
  %t8550 = call ptr @compiler_temp_ir_path(ptr %t8549)
  store ptr %t8550, ptr %out_file
  br label %label_2498
label_2498:
  %t8551 = load ptr, ptr %path
  %t8552 = call ptr @read_file(ptr %t8551)
  store ptr %t8552, ptr %content
  %t8553 = load ptr, ptr %content
  %t8554 = getelementptr inbounds [1 x i8], ptr @.str.s1030, i64 0, i64 0
  %t8555 = call i32 @str_equals(ptr %t8553, ptr %t8554)
  %t8556 = icmp eq i32 %t8555, 1
  br i1 %t8556, label %label_2499, label %label_2501
label_2499:
  %t8557 = getelementptr inbounds [23 x i8], ptr @.str.s1031, i64 0, i64 0
  call void @print(ptr %t8557)
  %t8558 = load ptr, ptr %path
  call void @println(ptr %t8558)
  %t8559 = load i1, ptr %bootstrap_mode
  br i1 %t8559, label %label_2502, label %label_2504
label_2502:
  %t8560 = getelementptr inbounds [66 x i8], ptr @.str.s1032, i64 0, i64 0
  call void @println(ptr %t8560)
  %t8561 = getelementptr inbounds [71 x i8], ptr @.str.s1033, i64 0, i64 0
  call void @println(ptr %t8561)
  %t8562 = getelementptr inbounds [45 x i8], ptr @.str.s1034, i64 0, i64 0
  call void @println(ptr %t8562)
  br label %label_2504
label_2504:
  ret i32 1
label_2501:
  %t8563 = load ptr, ptr %content
  %t8564 = call ptr @create_lexer__String(ptr %t8563)
  store ptr %t8564, ptr %lex
  %t8565 = load ptr, ptr %lex
  %t8566 = call ptr @lex_all_tokens__Struct_Lexer(ptr %t8565)
  store ptr %t8566, ptr %head_token
  %t8567 = load ptr, ptr %head_token
  %t8568 = call ptr @parser_create__Struct_Token(ptr %t8567)
  store ptr %t8568, ptr %p
  %t8569 = load ptr, ptr %p
  %t8570 = call ptr @parse_module__Struct_Parser(ptr %t8569)
  store ptr %t8570, ptr %ast_root
  %t8571 = load ptr, ptr %path
  %t8572 = call ptr @get_directory(ptr %t8571)
  store ptr %t8572, ptr %base_dir
  %t8573 = load ptr, ptr %ast_root
  %t8574 = load ptr, ptr %base_dir
  %t8575 = call ptr @resolve_imports__Struct_ASTNode_String(ptr %t8573, ptr %t8574)
  store ptr %t8575, ptr %merged_ast
  %t8576 = load ptr, ptr %merged_ast
  call void @analyze_module__Struct_ASTNode(ptr %t8576)
  call void @ir_reset()
  %t8577 = load ptr, ptr %merged_ast
  call void @generate_module__Struct_ASTNode(ptr %t8577)
  %t8578 = load ptr, ptr %out_file
  %t8579 = call i32 @ir_write_file(ptr %t8578)
  %t8580 = icmp ne i32 %t8579, 0
  br i1 %t8580, label %label_2505, label %label_2507
label_2505:
  %t8581 = getelementptr inbounds [31 x i8], ptr @.str.s1035, i64 0, i64 0
  call void @println(ptr %t8581)
  ret i32 1
label_2507:
  %t8582 = load i1, ptr %emit_ir_only
  br i1 %t8582, label %label_2508, label %label_2510
label_2508:
  %t8583 = getelementptr inbounds [16 x i8], ptr @.str.s1036, i64 0, i64 0
  call void @print(ptr %t8583)
  %t8584 = load ptr, ptr %out_file
  call void @println(ptr %t8584)
  ret i32 0
label_2510:
  store i32 0, ptr %build_failed
  %t8585 = load i1, ptr %bootstrap_mode
  br i1 %t8585, label %label_2511, label %label_2512
label_2511:
  %t8586 = load ptr, ptr %out_file
  %t8587 = load ptr, ptr %output_file
  %t8588 = call i32 @compiler_bootstrap_executable(ptr %t8586, ptr %t8587)
  store i32 %t8588, ptr %build_failed
  br label %label_2513
label_2512:
  %t8589 = load ptr, ptr %out_file
  %t8590 = load ptr, ptr %output_file
  %t8591 = call i32 @compiler_build_executable(ptr %t8589, ptr %t8590)
  store i32 %t8591, ptr %build_failed
  br label %label_2513
label_2513:
  %t8592 = load i32, ptr %build_failed
  %t8593 = icmp ne i32 %t8592, 0
  br i1 %t8593, label %label_2514, label %label_2516
label_2514:
  %t8594 = load ptr, ptr %out_file
  %t8595 = call i32 @delete_file(ptr %t8594)
  %t8596 = getelementptr inbounds [27 x i8], ptr @.str.s1037, i64 0, i64 0
  call void @println(ptr %t8596)
  ret i32 1
label_2516:
  %t8597 = load ptr, ptr %out_file
  %t8598 = call i32 @delete_file(ptr %t8597)
  %t8599 = getelementptr inbounds [7 x i8], ptr @.str.s1038, i64 0, i64 0
  call void @print(ptr %t8599)
  %t8600 = load ptr, ptr %output_file
  call void @println(ptr %t8600)
  %t8601 = load i1, ptr %run_after_build
  br i1 %t8601, label %label_2517, label %label_2519
label_2517:
  %t8602 = load ptr, ptr %output_file
  %t8603 = call i32 @compiler_run_executable(ptr %t8602)
  %t8604 = icmp ne i32 %t8603, 0
  br i1 %t8604, label %label_2520, label %label_2522
label_2520:
  %t8605 = getelementptr inbounds [35 x i8], ptr @.str.s1039, i64 0, i64 0
  call void @println(ptr %t8605)
  ret i32 1
label_2522:
  br label %label_2519
label_2519:
  ret i32 0
}

define i32 @main(i32 %p_argc, ptr %p_argv) {
  %path = alloca ptr
  %output_file = alloca ptr
  %command = alloca ptr
  %run_after_build = alloca i1
  %bootstrap_mode = alloca i1
  %arg_index = alloca i32
  %first = alloca ptr
  %source_hash = alloca ptr
  %candidate = alloca ptr
  %barg = alloca ptr
  %arg = alloca ptr
  store i32 %p_argc, ptr @prismio_argc
  store ptr %p_argv, ptr @prismio_argv
  %t8617 = getelementptr inbounds [1 x i8], ptr @.str.s1040, i64 0, i64 0
  store ptr %t8617, ptr %path
  %t8618 = getelementptr inbounds [1 x i8], ptr @.str.s1041, i64 0, i64 0
  store ptr %t8618, ptr %output_file
  %t8619 = getelementptr inbounds [1 x i8], ptr @.str.s1042, i64 0, i64 0
  store ptr %t8619, ptr %command
  store i1 0, ptr %run_after_build
  store i1 0, ptr %bootstrap_mode
  store i32 0, ptr %arg_index
  %t8620 = call i32 @cli_arg_count()
  %t8621 = icmp sle i32 %t8620, 1
  br i1 %t8621, label %label_2523, label %label_2525
label_2523:
  call void @print_usage__Void()
  ret i32 1
label_2525:
  %t8622 = call ptr @cli_arg(i32 1)
  store ptr %t8622, ptr %first
  %t8623 = load ptr, ptr %first
  %t8624 = getelementptr inbounds [13 x i8], ptr @.str.s1043, i64 0, i64 0
  %t8625 = call i32 @str_equals(ptr %t8623, ptr %t8624)
  %t8626 = icmp eq i32 %t8625, 1
  br i1 %t8626, label %label_2526, label %label_2528
label_2526:
  %t8627 = call ptr @compiler_runtime_source_hash()
  store ptr %t8627, ptr %source_hash
  %t8628 = load ptr, ptr %source_hash
  %t8629 = getelementptr inbounds [1 x i8], ptr @.str.s1044, i64 0, i64 0
  %t8630 = call i32 @str_equals(ptr %t8628, ptr %t8629)
  %t8631 = icmp eq i32 %t8630, 1
  br i1 %t8631, label %label_2529, label %label_2531
label_2529:
  %t8632 = getelementptr inbounds [58 x i8], ptr @.str.s1045, i64 0, i64 0
  call void @println(ptr %t8632)
  ret i32 1
label_2531:
  %t8633 = load ptr, ptr %source_hash
  call void @println(ptr %t8633)
  ret i32 0
label_2528:
  %t8634 = load ptr, ptr %first
  %t8635 = getelementptr inbounds [10 x i8], ptr @.str.s1046, i64 0, i64 0
  %t8636 = call i32 @str_equals(ptr %t8634, ptr %t8635)
  %t8637 = icmp eq i32 %t8636, 1
  br i1 %t8637, label %label_2532, label %label_2534
label_2532:
  %t8638 = getelementptr inbounds [10 x i8], ptr @.str.s1047, i64 0, i64 0
  store ptr %t8638, ptr %command
  store i1 1, ptr %bootstrap_mode
  store i1 0, ptr %run_after_build
  %t8639 = getelementptr inbounds [13 x i8], ptr @.str.s1048, i64 0, i64 0
  store ptr %t8639, ptr %path
  store i32 2, ptr %arg_index
  %t8640 = call i32 @cli_arg_count()
  %t8641 = icmp sgt i32 %t8640, 2
  br i1 %t8641, label %label_2535, label %label_2537
label_2535:
  %t8642 = call ptr @cli_arg(i32 2)
  store ptr %t8642, ptr %candidate
  %t8643 = load ptr, ptr %candidate
  %t8644 = getelementptr inbounds [3 x i8], ptr @.str.s1049, i64 0, i64 0
  %t8645 = call i32 @str_equals(ptr %t8643, ptr %t8644)
  %t8646 = icmp eq i32 %t8645, 0
  %t8647 = load ptr, ptr %candidate
  %t8648 = getelementptr inbounds [9 x i8], ptr @.str.s1050, i64 0, i64 0
  %t8649 = call i32 @str_equals(ptr %t8647, ptr %t8648)
  %t8650 = icmp eq i32 %t8649, 0
  %t8651 = and i1 %t8646, %t8650
  br i1 %t8651, label %label_2538, label %label_2540
label_2538:
  %t8652 = load ptr, ptr %candidate
  store ptr %t8652, ptr %path
  store i32 3, ptr %arg_index
  br label %label_2540
label_2540:
  br label %label_2537
label_2537:
  %t8653 = load ptr, ptr %path
  %t8654 = call ptr @compiler_default_exe_path(ptr %t8653)
  store ptr %t8654, ptr %output_file
  br label %label_2541
label_2541:
  %t8655 = load i32, ptr %arg_index
  %t8656 = call i32 @cli_arg_count()
  %t8657 = icmp slt i32 %t8655, %t8656
  br i1 %t8657, label %label_2542, label %label_2543
label_2542:
  %t8658 = load i32, ptr %arg_index
  %t8659 = call ptr @cli_arg(i32 %t8658)
  store ptr %t8659, ptr %barg
  %t8660 = load ptr, ptr %barg
  %t8661 = getelementptr inbounds [3 x i8], ptr @.str.s1051, i64 0, i64 0
  %t8662 = call i32 @str_equals(ptr %t8660, ptr %t8661)
  %t8663 = icmp eq i32 %t8662, 1
  br i1 %t8663, label %label_2544, label %label_2545
label_2544:
  %t8664 = load i32, ptr %arg_index
  %t8665 = add i32 %t8664, 1
  %t8666 = call i32 @cli_arg_count()
  %t8667 = icmp sge i32 %t8665, %t8666
  br i1 %t8667, label %label_2547, label %label_2549
label_2547:
  %t8668 = getelementptr inbounds [34 x i8], ptr @.str.s1052, i64 0, i64 0
  call void @println(ptr %t8668)
  ret i32 1
label_2549:
  %t8669 = load i32, ptr %arg_index
  %t8670 = add i32 %t8669, 1
  %t8671 = call ptr @cli_arg(i32 %t8670)
  store ptr %t8671, ptr %output_file
  %t8672 = load i32, ptr %arg_index
  %t8673 = add i32 %t8672, 2
  store i32 %t8673, ptr %arg_index
  br label %label_2546
label_2545:
  %t8674 = getelementptr inbounds [25 x i8], ptr @.str.s1053, i64 0, i64 0
  call void @print(ptr %t8674)
  %t8675 = load ptr, ptr %barg
  call void @println(ptr %t8675)
  call void @print_usage__Void()
  ret i32 1
label_2546:
  br label %label_2541
label_2543:
  %t8676 = load ptr, ptr %path
  %t8677 = load ptr, ptr %output_file
  %t8678 = load i1, ptr %run_after_build
  %t8679 = load i1, ptr %bootstrap_mode
  %t8680 = call i32 @compile_source__String_String_Bool_Bool(ptr %t8676, ptr %t8677, i1 %t8678, i1 %t8679)
  ret i32 %t8680
label_2534:
  %t8681 = load ptr, ptr %first
  %t8682 = getelementptr inbounds [6 x i8], ptr @.str.s1054, i64 0, i64 0
  %t8683 = call i32 @str_equals(ptr %t8681, ptr %t8682)
  %t8684 = icmp eq i32 %t8683, 1
  br i1 %t8684, label %label_2550, label %label_2551
label_2550:
  %t8685 = getelementptr inbounds [6 x i8], ptr @.str.s1055, i64 0, i64 0
  store ptr %t8685, ptr %command
  store i1 0, ptr %run_after_build
  store i32 3, ptr %arg_index
  %t8686 = call i32 @cli_arg_count()
  %t8687 = icmp sle i32 %t8686, 2
  br i1 %t8687, label %label_2553, label %label_2555
label_2553:
  %t8688 = getelementptr inbounds [27 x i8], ptr @.str.s1056, i64 0, i64 0
  call void @println(ptr %t8688)
  call void @print_usage__Void()
  ret i32 1
label_2555:
  %t8689 = call ptr @cli_arg(i32 2)
  store ptr %t8689, ptr %path
  %t8690 = load ptr, ptr %path
  %t8691 = getelementptr inbounds [4 x i8], ptr @.str.s1057, i64 0, i64 0
  %t8692 = call i32 @str_equals(ptr %t8690, ptr %t8691)
  %t8693 = icmp eq i32 %t8692, 1
  %t8694 = load ptr, ptr %path
  %t8695 = getelementptr inbounds [6 x i8], ptr @.str.s1058, i64 0, i64 0
  %t8696 = call i32 @str_equals(ptr %t8694, ptr %t8695)
  %t8697 = icmp eq i32 %t8696, 1
  %t8698 = or i1 %t8693, %t8697
  br i1 %t8698, label %label_2556, label %label_2558
label_2556:
  %t8699 = getelementptr inbounds [45 x i8], ptr @.str.s1059, i64 0, i64 0
  call void @println(ptr %t8699)
  ret i32 1
label_2558:
  br label %label_2552
label_2551:
  %t8700 = load ptr, ptr %first
  %t8701 = getelementptr inbounds [4 x i8], ptr @.str.s1060, i64 0, i64 0
  %t8702 = call i32 @str_equals(ptr %t8700, ptr %t8701)
  %t8703 = icmp eq i32 %t8702, 1
  br i1 %t8703, label %label_2559, label %label_2560
label_2559:
  %t8704 = getelementptr inbounds [4 x i8], ptr @.str.s1061, i64 0, i64 0
  store ptr %t8704, ptr %command
  store i1 1, ptr %run_after_build
  store i32 3, ptr %arg_index
  %t8705 = call i32 @cli_arg_count()
  %t8706 = icmp sle i32 %t8705, 2
  br i1 %t8706, label %label_2562, label %label_2564
label_2562:
  %t8707 = getelementptr inbounds [27 x i8], ptr @.str.s1062, i64 0, i64 0
  call void @println(ptr %t8707)
  call void @print_usage__Void()
  ret i32 1
label_2564:
  %t8708 = call ptr @cli_arg(i32 2)
  store ptr %t8708, ptr %path
  %t8709 = load ptr, ptr %path
  %t8710 = getelementptr inbounds [4 x i8], ptr @.str.s1063, i64 0, i64 0
  %t8711 = call i32 @str_equals(ptr %t8709, ptr %t8710)
  %t8712 = icmp eq i32 %t8711, 1
  %t8713 = load ptr, ptr %path
  %t8714 = getelementptr inbounds [6 x i8], ptr @.str.s1064, i64 0, i64 0
  %t8715 = call i32 @str_equals(ptr %t8713, ptr %t8714)
  %t8716 = icmp eq i32 %t8715, 1
  %t8717 = or i1 %t8712, %t8716
  br i1 %t8717, label %label_2565, label %label_2567
label_2565:
  %t8718 = getelementptr inbounds [45 x i8], ptr @.str.s1065, i64 0, i64 0
  call void @println(ptr %t8718)
  ret i32 1
label_2567:
  br label %label_2561
label_2560:
  %t8719 = getelementptr inbounds [6 x i8], ptr @.str.s1066, i64 0, i64 0
  store ptr %t8719, ptr %command
  store i1 0, ptr %run_after_build
  %t8720 = load ptr, ptr %first
  store ptr %t8720, ptr %path
  store i32 2, ptr %arg_index
  br label %label_2561
label_2561:
  br label %label_2552
label_2552:
  %t8721 = load ptr, ptr %path
  %t8722 = call ptr @compiler_default_exe_path(ptr %t8721)
  store ptr %t8722, ptr %output_file
  br label %label_2568
label_2568:
  %t8723 = load i32, ptr %arg_index
  %t8724 = call i32 @cli_arg_count()
  %t8725 = icmp slt i32 %t8723, %t8724
  br i1 %t8725, label %label_2569, label %label_2570
label_2569:
  %t8726 = load i32, ptr %arg_index
  %t8727 = call ptr @cli_arg(i32 %t8726)
  store ptr %t8727, ptr %arg
  %t8728 = load ptr, ptr %arg
  %t8729 = getelementptr inbounds [3 x i8], ptr @.str.s1067, i64 0, i64 0
  %t8730 = call i32 @str_equals(ptr %t8728, ptr %t8729)
  %t8731 = icmp eq i32 %t8730, 1
  br i1 %t8731, label %label_2571, label %label_2572
label_2571:
  %t8732 = load i32, ptr %arg_index
  %t8733 = add i32 %t8732, 1
  %t8734 = call i32 @cli_arg_count()
  %t8735 = icmp sge i32 %t8733, %t8734
  br i1 %t8735, label %label_2574, label %label_2576
label_2574:
  %t8736 = getelementptr inbounds [34 x i8], ptr @.str.s1068, i64 0, i64 0
  call void @println(ptr %t8736)
  ret i32 1
label_2576:
  %t8737 = load i32, ptr %arg_index
  %t8738 = add i32 %t8737, 1
  %t8739 = call ptr @cli_arg(i32 %t8738)
  store ptr %t8739, ptr %output_file
  %t8740 = load i32, ptr %arg_index
  %t8741 = add i32 %t8740, 2
  store i32 %t8741, ptr %arg_index
  br label %label_2573
label_2572:
  %t8742 = load ptr, ptr %arg
  %t8743 = getelementptr inbounds [9 x i8], ptr @.str.s1069, i64 0, i64 0
  %t8744 = call i32 @str_equals(ptr %t8742, ptr %t8743)
  %t8745 = icmp eq i32 %t8744, 1
  br i1 %t8745, label %label_2577, label %label_2578
label_2577:
  %t8746 = load i32, ptr %arg_index
  %t8747 = add i32 %t8746, 1
  %t8748 = call i32 @cli_arg_count()
  %t8749 = icmp sge i32 %t8747, %t8748
  br i1 %t8749, label %label_2580, label %label_2582
label_2580:
  %t8750 = getelementptr inbounds [47 x i8], ptr @.str.s1070, i64 0, i64 0
  call void @println(ptr %t8750)
  ret i32 1
label_2582:
  %t8751 = load i32, ptr %arg_index
  %t8752 = add i32 %t8751, 1
  %t8753 = call ptr @cli_arg(i32 %t8752)
  %t8754 = getelementptr inbounds [7 x i8], ptr @.str.s1071, i64 0, i64 0
  %t8755 = call i32 @str_equals(ptr %t8753, ptr %t8754)
  %t8756 = icmp eq i32 %t8755, 1
  br i1 %t8756, label %label_2583, label %label_2585
label_2583:
  call void @ir_set_target_wasm__Bool(i1 1)
  br label %label_2585
label_2585:
  %t8757 = load i32, ptr %arg_index
  %t8758 = add i32 %t8757, 2
  store i32 %t8758, ptr %arg_index
  br label %label_2579
label_2578:
  %t8759 = load ptr, ptr %arg
  %t8760 = getelementptr inbounds [6 x i8], ptr @.str.s1072, i64 0, i64 0
  %t8761 = call i32 @str_equals(ptr %t8759, ptr %t8760)
  %t8762 = icmp eq i32 %t8761, 1
  %t8763 = load ptr, ptr %arg
  %t8764 = getelementptr inbounds [4 x i8], ptr @.str.s1073, i64 0, i64 0
  %t8765 = call i32 @str_equals(ptr %t8763, ptr %t8764)
  %t8766 = icmp eq i32 %t8765, 1
  %t8767 = or i1 %t8762, %t8766
  br i1 %t8767, label %label_2586, label %label_2588
label_2586:
  %t8768 = getelementptr inbounds [45 x i8], ptr @.str.s1074, i64 0, i64 0
  call void @println(ptr %t8768)
  ret i32 1
label_2588:
  %t8769 = load ptr, ptr %command
  %t8770 = getelementptr inbounds [6 x i8], ptr @.str.s1075, i64 0, i64 0
  %t8771 = call i32 @str_equals(ptr %t8769, ptr %t8770)
  %t8772 = icmp eq i32 %t8771, 1
  %t8773 = load i32, ptr %arg_index
  %t8774 = icmp eq i32 %t8773, 2
  %t8775 = and i1 %t8772, %t8774
  br i1 %t8775, label %label_2589, label %label_2590
label_2589:
  %t8776 = load ptr, ptr %arg
  store ptr %t8776, ptr %output_file
  %t8777 = load i32, ptr %arg_index
  %t8778 = add i32 %t8777, 1
  store i32 %t8778, ptr %arg_index
  br label %label_2591
label_2590:
  %t8779 = getelementptr inbounds [25 x i8], ptr @.str.s1076, i64 0, i64 0
  call void @print(ptr %t8779)
  %t8780 = load ptr, ptr %arg
  call void @println(ptr %t8780)
  call void @print_usage__Void()
  ret i32 1
label_2591:
  br label %label_2579
label_2579:
  br label %label_2573
label_2573:
  br label %label_2568
label_2570:
  %t8781 = load ptr, ptr %path
  %t8782 = load ptr, ptr %output_file
  %t8783 = load i1, ptr %run_after_build
  %t8784 = load i1, ptr %bootstrap_mode
  %t8785 = call i32 @compile_source__String_String_Bool_Bool(ptr %t8781, ptr %t8782, i1 %t8783, i1 %t8784)
  ret i32 %t8785
}

