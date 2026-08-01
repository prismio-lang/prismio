; Prismio bootstrap seed -- LLVM IR for the Prismio compiler (src/main.psm).
;
; Committed because a new platform has no prismio binary to compile src/main.psm
; with, and this is the smallest artifact that breaks that cycle. Produced by a
; compiler that had reached a byte-identical gen1/gen2 fixed point.
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

%Lexer = type { ptr, i32, i32, i32, i32, i32 }
%Token = type { i32, ptr, i32, i32, i32, i32, ptr }
%ASTNode = type { i32, ptr, ptr, i32, i32, ptr, ptr, ptr, ptr, ptr, i32, i32, i32, i32 }
%Parser = type { ptr }
%TypeInfo = type { i32, ptr, ptr, ptr, ptr }

@prismio_argc = global i32 0
@prismio_argv = global ptr null
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
@.str.s38 = private unnamed_addr constant [3 x i8] c"as\00"
@.str.s39 = private unnamed_addr constant [6 x i8] c"inout\00"
@.str.s40 = private unnamed_addr constant [5 x i8] c"sink\00"
@.str.s41 = private unnamed_addr constant [5 x i8] c"true\00"
@.str.s42 = private unnamed_addr constant [6 x i8] c"false\00"
@.str.s43 = private unnamed_addr constant [2 x i8] c"`\00"
@.str.s44 = private unnamed_addr constant [2 x i8] c"`\00"
@.str.s45 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s46 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s47 = private unnamed_addr constant [81 x i8] c"a NUL escape cannot appear in a string literal, because String is NUL-terminated\00"
@.str.s48 = private unnamed_addr constant [26 x i8] c"unknown escape sequence \\\00"
@.str.s49 = private unnamed_addr constant [4 x i8] c"EOF\00"
@.str.s50 = private unnamed_addr constant [28 x i8] c"unterminated string literal\00"
@.str.s51 = private unnamed_addr constant [68 x i8] c"unterminated character literal (a Char holds exactly one character)\00"
@.str.s52 = private unnamed_addr constant [3 x i8] c"==\00"
@.str.s53 = private unnamed_addr constant [3 x i8] c"!=\00"
@.str.s54 = private unnamed_addr constant [3 x i8] c"<=\00"
@.str.s55 = private unnamed_addr constant [3 x i8] c">=\00"
@.str.s56 = private unnamed_addr constant [3 x i8] c"->\00"
@.str.s57 = private unnamed_addr constant [3 x i8] c"=>\00"
@.str.s58 = private unnamed_addr constant [3 x i8] c"=>\00"
@.str.s59 = private unnamed_addr constant [3 x i8] c"!=\00"
@.str.s60 = private unnamed_addr constant [3 x i8] c"<=\00"
@.str.s61 = private unnamed_addr constant [3 x i8] c">=\00"
@.str.s62 = private unnamed_addr constant [3 x i8] c"..\00"
@.str.s63 = private unnamed_addr constant [22 x i8] c"unexpected character \00"
@.str.s64 = private unnamed_addr constant [2 x i8] c"?\00"
@.str.s65 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s66 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s67 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s68 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s69 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s70 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s71 = private unnamed_addr constant [1 x i8] zeroinitializer
@parser_allow_struct_lit = global i32 1
@.str.s72 = private unnamed_addr constant [12 x i8] c"end of file\00"
@.str.s73 = private unnamed_addr constant [2 x i8] c"}\00"
@.str.s74 = private unnamed_addr constant [3 x i8] c"fn\00"
@.str.s75 = private unnamed_addr constant [4 x i8] c"let\00"
@.str.s76 = private unnamed_addr constant [7 x i8] c"struct\00"
@.str.s77 = private unnamed_addr constant [5 x i8] c"enum\00"
@.str.s78 = private unnamed_addr constant [7 x i8] c"extern\00"
@.str.s79 = private unnamed_addr constant [7 x i8] c"import\00"
@.str.s80 = private unnamed_addr constant [5 x i8] c"impl\00"
@.str.s81 = private unnamed_addr constant [6 x i8] c"trait\00"
@.str.s82 = private unnamed_addr constant [3 x i8] c"if\00"
@.str.s83 = private unnamed_addr constant [6 x i8] c"while\00"
@.str.s84 = private unnamed_addr constant [4 x i8] c"for\00"
@.str.s85 = private unnamed_addr constant [5 x i8] c"loop\00"
@.str.s86 = private unnamed_addr constant [6 x i8] c"match\00"
@.str.s87 = private unnamed_addr constant [7 x i8] c"return\00"
@.str.s88 = private unnamed_addr constant [10 x i8] c"expected \00"
@.str.s89 = private unnamed_addr constant [5 x i8] c" in \00"
@.str.s90 = private unnamed_addr constant [9 x i8] c", found \00"
@.str.s91 = private unnamed_addr constant [10 x i8] c"expected \00"
@.str.s92 = private unnamed_addr constant [5 x i8] c" in \00"
@.str.s93 = private unnamed_addr constant [9 x i8] c", found \00"
@.str.s94 = private unnamed_addr constant [7 x i8] c"import\00"
@.str.s95 = private unnamed_addr constant [17 x i8] c"import statement\00"
@.str.s96 = private unnamed_addr constant [46 x i8] c"expected a module name after `import`, found \00"
@.str.s97 = private unnamed_addr constant [7 x i8] c"import\00"
@.str.s98 = private unnamed_addr constant [4 x i8] c"let\00"
@.str.s99 = private unnamed_addr constant [7 x i8] c"extern\00"
@.str.s100 = private unnamed_addr constant [3 x i8] c"fn\00"
@.str.s101 = private unnamed_addr constant [7 x i8] c"struct\00"
@.str.s102 = private unnamed_addr constant [5 x i8] c"enum\00"
@.str.s103 = private unnamed_addr constant [31 x i8] c"expected a declaration, found \00"
@.str.s104 = private unnamed_addr constant [69 x i8] c" (expected one of `import`, `let`, `fn`, `extern`, `struct`, `enum`)\00"
@.str.s105 = private unnamed_addr constant [2 x i8] c"[\00"
@.str.s106 = private unnamed_addr constant [2 x i8] c"]\00"
@.str.s107 = private unnamed_addr constant [11 x i8] c"array type\00"
@.str.s108 = private unnamed_addr constant [29 x i8] c"expected a type name, found \00"
@.str.s109 = private unnamed_addr constant [5 x i8] c"List\00"
@.str.s110 = private unnamed_addr constant [2 x i8] c"<\00"
@.str.s111 = private unnamed_addr constant [19 x i8] c"list type argument\00"
@.str.s112 = private unnamed_addr constant [3 x i8] c">>\00"
@.str.s113 = private unnamed_addr constant [2 x i8] c">\00"
@.str.s114 = private unnamed_addr constant [2 x i8] c">\00"
@.str.s115 = private unnamed_addr constant [4 x i8] c"let\00"
@.str.s116 = private unnamed_addr constant [21 x i8] c"variable declaration\00"
@.str.s117 = private unnamed_addr constant [4 x i8] c"mut\00"
@.str.s118 = private unnamed_addr constant [14 x i8] c"variable name\00"
@.str.s119 = private unnamed_addr constant [2 x i8] c":\00"
@.str.s120 = private unnamed_addr constant [2 x i8] c"=\00"
@.str.s121 = private unnamed_addr constant [7 x i8] c"extern\00"
@.str.s122 = private unnamed_addr constant [10 x i8] c"extern fn\00"
@.str.s123 = private unnamed_addr constant [3 x i8] c"fn\00"
@.str.s124 = private unnamed_addr constant [10 x i8] c"extern fn\00"
@.str.s125 = private unnamed_addr constant [14 x i8] c"function name\00"
@.str.s126 = private unnamed_addr constant [2 x i8] c"(\00"
@.str.s127 = private unnamed_addr constant [7 x i8] c"params\00"
@.str.s128 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s129 = private unnamed_addr constant [2 x i8] c")\00"
@.str.s130 = private unnamed_addr constant [15 x i8] c"parameter name\00"
@.str.s131 = private unnamed_addr constant [2 x i8] c":\00"
@.str.s132 = private unnamed_addr constant [15 x i8] c"parameter type\00"
@.str.s133 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s134 = private unnamed_addr constant [2 x i8] c",\00"
@.str.s135 = private unnamed_addr constant [2 x i8] c")\00"
@.str.s136 = private unnamed_addr constant [7 x i8] c"params\00"
@.str.s137 = private unnamed_addr constant [3 x i8] c"->\00"
@.str.s138 = private unnamed_addr constant [3 x i8] c"fn\00"
@.str.s139 = private unnamed_addr constant [9 x i8] c"function\00"
@.str.s140 = private unnamed_addr constant [14 x i8] c"function name\00"
@.str.s141 = private unnamed_addr constant [2 x i8] c"(\00"
@.str.s142 = private unnamed_addr constant [7 x i8] c"params\00"
@.str.s143 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s144 = private unnamed_addr constant [2 x i8] c")\00"
@.str.s145 = private unnamed_addr constant [5 x i8] c"sink\00"
@.str.s146 = private unnamed_addr constant [5 x i8] c"sink\00"
@.str.s147 = private unnamed_addr constant [6 x i8] c"inout\00"
@.str.s148 = private unnamed_addr constant [6 x i8] c"inout\00"
@.str.s149 = private unnamed_addr constant [15 x i8] c"parameter name\00"
@.str.s150 = private unnamed_addr constant [2 x i8] c":\00"
@.str.s151 = private unnamed_addr constant [15 x i8] c"parameter type\00"
@.str.s152 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s153 = private unnamed_addr constant [2 x i8] c",\00"
@.str.s154 = private unnamed_addr constant [2 x i8] c")\00"
@.str.s155 = private unnamed_addr constant [7 x i8] c"params\00"
@.str.s156 = private unnamed_addr constant [3 x i8] c"->\00"
@.str.s157 = private unnamed_addr constant [7 x i8] c"struct\00"
@.str.s158 = private unnamed_addr constant [7 x i8] c"struct\00"
@.str.s159 = private unnamed_addr constant [12 x i8] c"struct name\00"
@.str.s160 = private unnamed_addr constant [2 x i8] c"{\00"
@.str.s161 = private unnamed_addr constant [12 x i8] c"struct body\00"
@.str.s162 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s163 = private unnamed_addr constant [2 x i8] c"}\00"
@.str.s164 = private unnamed_addr constant [11 x i8] c"field name\00"
@.str.s165 = private unnamed_addr constant [2 x i8] c":\00"
@.str.s166 = private unnamed_addr constant [11 x i8] c"field type\00"
@.str.s167 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s168 = private unnamed_addr constant [2 x i8] c",\00"
@.str.s169 = private unnamed_addr constant [2 x i8] c"}\00"
@.str.s170 = private unnamed_addr constant [12 x i8] c"struct body\00"
@.str.s171 = private unnamed_addr constant [5 x i8] c"enum\00"
@.str.s172 = private unnamed_addr constant [5 x i8] c"enum\00"
@.str.s173 = private unnamed_addr constant [10 x i8] c"enum name\00"
@.str.s174 = private unnamed_addr constant [2 x i8] c"{\00"
@.str.s175 = private unnamed_addr constant [10 x i8] c"enum body\00"
@.str.s176 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s177 = private unnamed_addr constant [2 x i8] c"}\00"
@.str.s178 = private unnamed_addr constant [13 x i8] c"variant name\00"
@.str.s179 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s180 = private unnamed_addr constant [2 x i8] c",\00"
@.str.s181 = private unnamed_addr constant [2 x i8] c"}\00"
@.str.s182 = private unnamed_addr constant [10 x i8] c"enum body\00"
@.str.s183 = private unnamed_addr constant [2 x i8] c"{\00"
@.str.s184 = private unnamed_addr constant [6 x i8] c"block\00"
@.str.s185 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s186 = private unnamed_addr constant [2 x i8] c"}\00"
@.str.s187 = private unnamed_addr constant [64 x i8] c"this block is never closed; reached end of file looking for `}`\00"
@.str.s188 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s189 = private unnamed_addr constant [2 x i8] c"}\00"
@.str.s190 = private unnamed_addr constant [6 x i8] c"block\00"
@.str.s191 = private unnamed_addr constant [3 x i8] c"if\00"
@.str.s192 = private unnamed_addr constant [13 x i8] c"if statement\00"
@.str.s193 = private unnamed_addr constant [2 x i8] c"(\00"
@.str.s194 = private unnamed_addr constant [13 x i8] c"if condition\00"
@.str.s195 = private unnamed_addr constant [2 x i8] c")\00"
@.str.s196 = private unnamed_addr constant [13 x i8] c"if condition\00"
@.str.s197 = private unnamed_addr constant [5 x i8] c"else\00"
@.str.s198 = private unnamed_addr constant [3 x i8] c"if\00"
@.str.s199 = private unnamed_addr constant [6 x i8] c"while\00"
@.str.s200 = private unnamed_addr constant [16 x i8] c"while statement\00"
@.str.s201 = private unnamed_addr constant [2 x i8] c"(\00"
@.str.s202 = private unnamed_addr constant [16 x i8] c"while condition\00"
@.str.s203 = private unnamed_addr constant [2 x i8] c")\00"
@.str.s204 = private unnamed_addr constant [16 x i8] c"while condition\00"
@.str.s205 = private unnamed_addr constant [5 x i8] c"loop\00"
@.str.s206 = private unnamed_addr constant [15 x i8] c"loop statement\00"
@.str.s207 = private unnamed_addr constant [4 x i8] c"for\00"
@.str.s208 = private unnamed_addr constant [14 x i8] c"for statement\00"
@.str.s209 = private unnamed_addr constant [18 x i8] c"for loop variable\00"
@.str.s210 = private unnamed_addr constant [3 x i8] c"in\00"
@.str.s211 = private unnamed_addr constant [11 x i8] c"for ... in\00"
@.str.s212 = private unnamed_addr constant [3 x i8] c"..\00"
@.str.s213 = private unnamed_addr constant [10 x i8] c"for range\00"
@.str.s214 = private unnamed_addr constant [2 x i8] c"_\00"
@.str.s215 = private unnamed_addr constant [2 x i8] c"_\00"
@.str.s216 = private unnamed_addr constant [3 x i8] c"=>\00"
@.str.s217 = private unnamed_addr constant [10 x i8] c"match arm\00"
@.str.s218 = private unnamed_addr constant [6 x i8] c"match\00"
@.str.s219 = private unnamed_addr constant [16 x i8] c"match statement\00"
@.str.s220 = private unnamed_addr constant [2 x i8] c"(\00"
@.str.s221 = private unnamed_addr constant [16 x i8] c"match scrutinee\00"
@.str.s222 = private unnamed_addr constant [2 x i8] c")\00"
@.str.s223 = private unnamed_addr constant [16 x i8] c"match scrutinee\00"
@.str.s224 = private unnamed_addr constant [2 x i8] c"{\00"
@.str.s225 = private unnamed_addr constant [11 x i8] c"match body\00"
@.str.s226 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s227 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s228 = private unnamed_addr constant [2 x i8] c"}\00"
@.str.s229 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s230 = private unnamed_addr constant [2 x i8] c",\00"
@.str.s231 = private unnamed_addr constant [2 x i8] c"}\00"
@.str.s232 = private unnamed_addr constant [11 x i8] c"match body\00"
@.str.s233 = private unnamed_addr constant [3 x i8] c"if\00"
@.str.s234 = private unnamed_addr constant [6 x i8] c"while\00"
@.str.s235 = private unnamed_addr constant [5 x i8] c"loop\00"
@.str.s236 = private unnamed_addr constant [6 x i8] c"match\00"
@.str.s237 = private unnamed_addr constant [4 x i8] c"for\00"
@.str.s238 = private unnamed_addr constant [6 x i8] c"break\00"
@.str.s239 = private unnamed_addr constant [9 x i8] c"continue\00"
@.str.s240 = private unnamed_addr constant [7 x i8] c"return\00"
@.str.s241 = private unnamed_addr constant [2 x i8] c"}\00"
@.str.s242 = private unnamed_addr constant [4 x i8] c"let\00"
@.str.s243 = private unnamed_addr constant [2 x i8] c"=\00"
@.str.s244 = private unnamed_addr constant [21 x i8] c"compound assignment \00"
@.str.s245 = private unnamed_addr constant [39 x i8] c" requires a plain variable on the left\00"
@.str.s246 = private unnamed_addr constant [130 x i8] c"the desugaring names the target twice, so a subexpression here would be evaluated twice; write the assignment out in full instead\00"
@.str.s247 = private unnamed_addr constant [3 x i8] c"or\00"
@.str.s248 = private unnamed_addr constant [4 x i8] c"and\00"
@.str.s249 = private unnamed_addr constant [3 x i8] c"==\00"
@.str.s250 = private unnamed_addr constant [3 x i8] c"!=\00"
@.str.s251 = private unnamed_addr constant [2 x i8] c"<\00"
@.str.s252 = private unnamed_addr constant [2 x i8] c">\00"
@.str.s253 = private unnamed_addr constant [3 x i8] c"<=\00"
@.str.s254 = private unnamed_addr constant [3 x i8] c">=\00"
@.str.s255 = private unnamed_addr constant [2 x i8] c"|\00"
@.str.s256 = private unnamed_addr constant [2 x i8] c"^\00"
@.str.s257 = private unnamed_addr constant [2 x i8] c"&\00"
@.str.s258 = private unnamed_addr constant [3 x i8] c"<<\00"
@.str.s259 = private unnamed_addr constant [3 x i8] c">>\00"
@.str.s260 = private unnamed_addr constant [2 x i8] c"+\00"
@.str.s261 = private unnamed_addr constant [2 x i8] c"-\00"
@.str.s262 = private unnamed_addr constant [2 x i8] c"*\00"
@.str.s263 = private unnamed_addr constant [2 x i8] c"/\00"
@.str.s264 = private unnamed_addr constant [2 x i8] c"%\00"
@.str.s265 = private unnamed_addr constant [2 x i8] c"-\00"
@.str.s266 = private unnamed_addr constant [2 x i8] c"!\00"
@.str.s267 = private unnamed_addr constant [2 x i8] c"~\00"
@.str.s268 = private unnamed_addr constant [2 x i8] c"-\00"
@.str.s269 = private unnamed_addr constant [2 x i8] c"-\00"
@.str.s270 = private unnamed_addr constant [2 x i8] c"-\00"
@.str.s271 = private unnamed_addr constant [3 x i8] c"as\00"
@.str.s272 = private unnamed_addr constant [4 x i8] c"and\00"
@.str.s273 = private unnamed_addr constant [3 x i8] c"or\00"
@.str.s274 = private unnamed_addr constant [2 x i8] c"{\00"
@.str.s275 = private unnamed_addr constant [2 x i8] c"{\00"
@.str.s276 = private unnamed_addr constant [15 x i8] c"struct literal\00"
@.str.s277 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s278 = private unnamed_addr constant [2 x i8] c"}\00"
@.str.s279 = private unnamed_addr constant [21 x i8] c"struct literal field\00"
@.str.s280 = private unnamed_addr constant [2 x i8] c":\00"
@.str.s281 = private unnamed_addr constant [15 x i8] c"struct literal\00"
@.str.s282 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s283 = private unnamed_addr constant [2 x i8] c",\00"
@.str.s284 = private unnamed_addr constant [2 x i8] c"}\00"
@.str.s285 = private unnamed_addr constant [15 x i8] c"struct literal\00"
@.str.s286 = private unnamed_addr constant [2 x i8] c"(\00"
@.str.s287 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s288 = private unnamed_addr constant [2 x i8] c")\00"
@.str.s289 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s290 = private unnamed_addr constant [2 x i8] c",\00"
@.str.s291 = private unnamed_addr constant [2 x i8] c")\00"
@.str.s292 = private unnamed_addr constant [14 x i8] c"function call\00"
@.str.s293 = private unnamed_addr constant [2 x i8] c"[\00"
@.str.s294 = private unnamed_addr constant [2 x i8] c"]\00"
@.str.s295 = private unnamed_addr constant [12 x i8] c"array index\00"
@.str.s296 = private unnamed_addr constant [2 x i8] c".\00"
@.str.s297 = private unnamed_addr constant [12 x i8] c"member name\00"
@.str.s298 = private unnamed_addr constant [2 x i8] c"(\00"
@.str.s299 = private unnamed_addr constant [2 x i8] c")\00"
@.str.s300 = private unnamed_addr constant [25 x i8] c"parenthesized expression\00"
@.str.s301 = private unnamed_addr constant [2 x i8] c"[\00"
@.str.s302 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s303 = private unnamed_addr constant [2 x i8] c"]\00"
@.str.s304 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s305 = private unnamed_addr constant [2 x i8] c",\00"
@.str.s306 = private unnamed_addr constant [2 x i8] c"]\00"
@.str.s307 = private unnamed_addr constant [14 x i8] c"array literal\00"
@.str.s308 = private unnamed_addr constant [31 x i8] c"expected an expression, found \00"
@.str.s309 = private unnamed_addr constant [5 x i8] c" (a \00"
@.str.s310 = private unnamed_addr constant [2 x i8] c")\00"
@.str.s311 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s312 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s313 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s314 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s315 = private unnamed_addr constant [8 x i8] c"Invalid\00"
@.str.s316 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s317 = private unnamed_addr constant [5 x i8] c"Void\00"
@.str.s318 = private unnamed_addr constant [5 x i8] c"void\00"
@.str.s319 = private unnamed_addr constant [4 x i8] c"Int\00"
@.str.s320 = private unnamed_addr constant [4 x i8] c"i32\00"
@.str.s321 = private unnamed_addr constant [6 x i8] c"Float\00"
@.str.s322 = private unnamed_addr constant [7 x i8] c"double\00"
@.str.s323 = private unnamed_addr constant [5 x i8] c"Bool\00"
@.str.s324 = private unnamed_addr constant [3 x i8] c"i1\00"
@.str.s325 = private unnamed_addr constant [5 x i8] c"Char\00"
@.str.s326 = private unnamed_addr constant [3 x i8] c"i8\00"
@.str.s327 = private unnamed_addr constant [7 x i8] c"String\00"
@.str.s328 = private unnamed_addr constant [4 x i8] c"ptr\00"
@.str.s329 = private unnamed_addr constant [4 x i8] c"Ptr\00"
@.str.s330 = private unnamed_addr constant [4 x i8] c"ptr\00"
@.str.s331 = private unnamed_addr constant [3 x i8] c"I8\00"
@.str.s332 = private unnamed_addr constant [3 x i8] c"i8\00"
@.str.s333 = private unnamed_addr constant [4 x i8] c"I16\00"
@.str.s334 = private unnamed_addr constant [4 x i8] c"i16\00"
@.str.s335 = private unnamed_addr constant [4 x i8] c"I64\00"
@.str.s336 = private unnamed_addr constant [4 x i8] c"i64\00"
@.str.s337 = private unnamed_addr constant [6 x i8] c"Isize\00"
@.str.s338 = private unnamed_addr constant [4 x i8] c"i64\00"
@.str.s339 = private unnamed_addr constant [3 x i8] c"U8\00"
@.str.s340 = private unnamed_addr constant [3 x i8] c"i8\00"
@.str.s341 = private unnamed_addr constant [4 x i8] c"U16\00"
@.str.s342 = private unnamed_addr constant [4 x i8] c"i16\00"
@.str.s343 = private unnamed_addr constant [4 x i8] c"U32\00"
@.str.s344 = private unnamed_addr constant [4 x i8] c"i32\00"
@.str.s345 = private unnamed_addr constant [4 x i8] c"U64\00"
@.str.s346 = private unnamed_addr constant [4 x i8] c"i64\00"
@.str.s347 = private unnamed_addr constant [6 x i8] c"Usize\00"
@.str.s348 = private unnamed_addr constant [4 x i8] c"i64\00"
@.str.s349 = private unnamed_addr constant [3 x i8] c"i1\00"
@.str.s350 = private unnamed_addr constant [3 x i8] c"i8\00"
@.str.s351 = private unnamed_addr constant [4 x i8] c"i16\00"
@.str.s352 = private unnamed_addr constant [4 x i8] c"i32\00"
@.str.s353 = private unnamed_addr constant [4 x i8] c"i64\00"
@.str.s354 = private unnamed_addr constant [2 x i8] c"U\00"
@.str.s355 = private unnamed_addr constant [4 x i8] c"ptr\00"
@.str.s356 = private unnamed_addr constant [4 x i8] c"i32\00"
@.str.s357 = private unnamed_addr constant [6 x i8] c"Array\00"
@.str.s358 = private unnamed_addr constant [4 x i8] c"ptr\00"
@.str.s359 = private unnamed_addr constant [5 x i8] c"List\00"
@.str.s360 = private unnamed_addr constant [4 x i8] c"ptr\00"
@.str.s361 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s362 = private unnamed_addr constant [2 x i8] c"[\00"
@.str.s363 = private unnamed_addr constant [2 x i8] c"]\00"
@.str.s364 = private unnamed_addr constant [10 x i8] c"[Invalid]\00"
@.str.s365 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s366 = private unnamed_addr constant [6 x i8] c"List<\00"
@.str.s367 = private unnamed_addr constant [2 x i8] c">\00"
@.str.s368 = private unnamed_addr constant [5 x i8] c"List\00"
@.str.s369 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s370 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s371 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s372 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s373 = private unnamed_addr constant [5 x i8] c"void\00"
@.str.s374 = private unnamed_addr constant [7 x i8] c"double\00"
@.str.s375 = private unnamed_addr constant [3 x i8] c"i1\00"
@.str.s376 = private unnamed_addr constant [3 x i8] c"i8\00"
@.str.s377 = private unnamed_addr constant [4 x i8] c"ptr\00"
@.str.s378 = private unnamed_addr constant [4 x i8] c"ptr\00"
@.str.s379 = private unnamed_addr constant [4 x i8] c"i32\00"
@.str.s380 = private unnamed_addr constant [8 x i8] c"struct:\00"
@.str.s381 = private unnamed_addr constant [4 x i8] c"ptr\00"
@.str.s382 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s383 = private unnamed_addr constant [7 x i8] c"ptrptr\00"
@.str.s384 = private unnamed_addr constant [4 x i8] c"ptr\00"
@.str.s385 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s386 = private unnamed_addr constant [5 x i8] c"Void\00"
@.str.s387 = private unnamed_addr constant [6 x i8] c"Float\00"
@.str.s388 = private unnamed_addr constant [5 x i8] c"Bool\00"
@.str.s389 = private unnamed_addr constant [5 x i8] c"Char\00"
@.str.s390 = private unnamed_addr constant [7 x i8] c"String\00"
@.str.s391 = private unnamed_addr constant [4 x i8] c"Ptr\00"
@.str.s392 = private unnamed_addr constant [8 x i8] c"struct:\00"
@.str.s393 = private unnamed_addr constant [6 x i8] c"enum:\00"
@.str.s394 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s395 = private unnamed_addr constant [7 x i8] c"array:\00"
@.str.s396 = private unnamed_addr constant [14 x i8] c"array:Invalid\00"
@.str.s397 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s398 = private unnamed_addr constant [6 x i8] c"list:\00"
@.str.s399 = private unnamed_addr constant [13 x i8] c"list:Invalid\00"
@.str.s400 = private unnamed_addr constant [8 x i8] c"Invalid\00"
@.str.s401 = private unnamed_addr constant [7 x i8] c"ptrptr\00"
@.str.s402 = private unnamed_addr constant [4 x i8] c"ptr\00"
@.str.s403 = private unnamed_addr constant [8 x i8] c"struct:\00"
@.str.s404 = private unnamed_addr constant [4 x i8] c"ptr\00"
@.str.s405 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s406 = private unnamed_addr constant [4 x i8] c"Int\00"
@.str.s407 = private unnamed_addr constant [6 x i8] c"Float\00"
@.str.s408 = private unnamed_addr constant [5 x i8] c"Bool\00"
@.str.s409 = private unnamed_addr constant [7 x i8] c"String\00"
@.str.s410 = private unnamed_addr constant [5 x i8] c"Char\00"
@.str.s411 = private unnamed_addr constant [3 x i8] c"I8\00"
@.str.s412 = private unnamed_addr constant [4 x i8] c"I16\00"
@.str.s413 = private unnamed_addr constant [4 x i8] c"I64\00"
@.str.s414 = private unnamed_addr constant [6 x i8] c"Isize\00"
@.str.s415 = private unnamed_addr constant [3 x i8] c"U8\00"
@.str.s416 = private unnamed_addr constant [4 x i8] c"U16\00"
@.str.s417 = private unnamed_addr constant [4 x i8] c"U32\00"
@.str.s418 = private unnamed_addr constant [4 x i8] c"U64\00"
@.str.s419 = private unnamed_addr constant [6 x i8] c"Usize\00"
@.str.s420 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s421 = private unnamed_addr constant [4 x i8] c"i32\00"
@.str.s422 = private unnamed_addr constant [7 x i8] c"double\00"
@.str.s423 = private unnamed_addr constant [3 x i8] c"i1\00"
@.str.s424 = private unnamed_addr constant [3 x i8] c"i8\00"
@.str.s425 = private unnamed_addr constant [4 x i8] c"ptr\00"
@.str.s426 = private unnamed_addr constant [5 x i8] c"void\00"
@.str.s427 = private unnamed_addr constant [8 x i8] c"struct:\00"
@.str.s428 = private unnamed_addr constant [4 x i8] c"Int\00"
@.str.s429 = private unnamed_addr constant [6 x i8] c"Float\00"
@.str.s430 = private unnamed_addr constant [5 x i8] c"Bool\00"
@.str.s431 = private unnamed_addr constant [5 x i8] c"Char\00"
@.str.s432 = private unnamed_addr constant [7 x i8] c"String\00"
@.str.s433 = private unnamed_addr constant [4 x i8] c"Ptr\00"
@.str.s434 = private unnamed_addr constant [5 x i8] c"Void\00"
@.str.s435 = private unnamed_addr constant [3 x i8] c"I8\00"
@.str.s436 = private unnamed_addr constant [4 x i8] c"I16\00"
@.str.s437 = private unnamed_addr constant [4 x i8] c"I64\00"
@.str.s438 = private unnamed_addr constant [6 x i8] c"Isize\00"
@.str.s439 = private unnamed_addr constant [3 x i8] c"U8\00"
@.str.s440 = private unnamed_addr constant [4 x i8] c"U16\00"
@.str.s441 = private unnamed_addr constant [4 x i8] c"U32\00"
@.str.s442 = private unnamed_addr constant [4 x i8] c"U64\00"
@.str.s443 = private unnamed_addr constant [6 x i8] c"Usize\00"
@.str.s444 = private unnamed_addr constant [8 x i8] c"struct:\00"
@.str.s445 = private unnamed_addr constant [6 x i8] c"enum:\00"
@.str.s446 = private unnamed_addr constant [7 x i8] c"array:\00"
@.str.s447 = private unnamed_addr constant [6 x i8] c"list:\00"
@.str.s448 = private unnamed_addr constant [1 x i8] zeroinitializer
@ir_string_counter = global i32 0
@ir_target_wasm = global i1 false
@ir_short_circuit_counter = global i32 0
@.str.s449 = private unnamed_addr constant [4 x i8] c"i32\00"
@.str.s450 = private unnamed_addr constant [4 x i8] c"i64\00"
@.str.s451 = private unnamed_addr constant [4 x i8] c"Int\00"
@.str.s452 = private unnamed_addr constant [4 x i8] c"i32\00"
@.str.s453 = private unnamed_addr constant [6 x i8] c"Float\00"
@.str.s454 = private unnamed_addr constant [7 x i8] c"double\00"
@.str.s455 = private unnamed_addr constant [5 x i8] c"Bool\00"
@.str.s456 = private unnamed_addr constant [3 x i8] c"i1\00"
@.str.s457 = private unnamed_addr constant [7 x i8] c"String\00"
@.str.s458 = private unnamed_addr constant [4 x i8] c"ptr\00"
@.str.s459 = private unnamed_addr constant [5 x i8] c"Char\00"
@.str.s460 = private unnamed_addr constant [3 x i8] c"i8\00"
@.str.s461 = private unnamed_addr constant [3 x i8] c"I8\00"
@.str.s462 = private unnamed_addr constant [3 x i8] c"i8\00"
@.str.s463 = private unnamed_addr constant [4 x i8] c"I16\00"
@.str.s464 = private unnamed_addr constant [4 x i8] c"i16\00"
@.str.s465 = private unnamed_addr constant [4 x i8] c"I64\00"
@.str.s466 = private unnamed_addr constant [4 x i8] c"i64\00"
@.str.s467 = private unnamed_addr constant [6 x i8] c"Isize\00"
@.str.s468 = private unnamed_addr constant [3 x i8] c"U8\00"
@.str.s469 = private unnamed_addr constant [3 x i8] c"i8\00"
@.str.s470 = private unnamed_addr constant [4 x i8] c"U16\00"
@.str.s471 = private unnamed_addr constant [4 x i8] c"i16\00"
@.str.s472 = private unnamed_addr constant [4 x i8] c"U32\00"
@.str.s473 = private unnamed_addr constant [4 x i8] c"i32\00"
@.str.s474 = private unnamed_addr constant [4 x i8] c"U64\00"
@.str.s475 = private unnamed_addr constant [4 x i8] c"i64\00"
@.str.s476 = private unnamed_addr constant [6 x i8] c"Usize\00"
@.str.s477 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s478 = private unnamed_addr constant [5 x i8] c"void\00"
@.str.s479 = private unnamed_addr constant [4 x i8] c"i32\00"
@.str.s480 = private unnamed_addr constant [8 x i8] c"struct:\00"
@.str.s481 = private unnamed_addr constant [8 x i8] c"struct:\00"
@.str.s482 = private unnamed_addr constant [2 x i8] c"%\00"
@.str.s483 = private unnamed_addr constant [4 x i8] c"ptr\00"
@.str.s484 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s485 = private unnamed_addr constant [7 x i8] c"ptrptr\00"
@.str.s486 = private unnamed_addr constant [4 x i8] c"ptr\00"
@.str.s487 = private unnamed_addr constant [7 x i8] c"ptrptr\00"
@.str.s488 = private unnamed_addr constant [4 x i8] c"ptr\00"
@.str.s489 = private unnamed_addr constant [4 x i8] c"ptr\00"
@.str.s490 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s491 = private unnamed_addr constant [5 x i8] c"$fn$\00"
@.str.s492 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s493 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s494 = private unnamed_addr constant [5 x i8] c"void\00"
@.str.s495 = private unnamed_addr constant [4 x i8] c"i32\00"
@.str.s496 = private unnamed_addr constant [7 x i8] c"double\00"
@.str.s497 = private unnamed_addr constant [3 x i8] c"i1\00"
@.str.s498 = private unnamed_addr constant [3 x i8] c"i8\00"
@.str.s499 = private unnamed_addr constant [4 x i8] c"ptr\00"
@.str.s500 = private unnamed_addr constant [2 x i8] c"!\00"
@.str.s501 = private unnamed_addr constant [3 x i8] c"i1\00"
@.str.s502 = private unnamed_addr constant [3 x i8] c"==\00"
@.str.s503 = private unnamed_addr constant [3 x i8] c"!=\00"
@.str.s504 = private unnamed_addr constant [3 x i8] c"i1\00"
@.str.s505 = private unnamed_addr constant [2 x i8] c"<\00"
@.str.s506 = private unnamed_addr constant [3 x i8] c"<=\00"
@.str.s507 = private unnamed_addr constant [3 x i8] c"i1\00"
@.str.s508 = private unnamed_addr constant [2 x i8] c">\00"
@.str.s509 = private unnamed_addr constant [3 x i8] c">=\00"
@.str.s510 = private unnamed_addr constant [3 x i8] c"i1\00"
@.str.s511 = private unnamed_addr constant [4 x i8] c"and\00"
@.str.s512 = private unnamed_addr constant [3 x i8] c"or\00"
@.str.s513 = private unnamed_addr constant [3 x i8] c"i1\00"
@.str.s514 = private unnamed_addr constant [6 x i8] c"print\00"
@.str.s515 = private unnamed_addr constant [8 x i8] c"println\00"
@.str.s516 = private unnamed_addr constant [5 x i8] c"void\00"
@.str.s517 = private unnamed_addr constant [10 x i8] c"print_int\00"
@.str.s518 = private unnamed_addr constant [12 x i8] c"println_int\00"
@.str.s519 = private unnamed_addr constant [5 x i8] c"void\00"
@.str.s520 = private unnamed_addr constant [12 x i8] c"print_float\00"
@.str.s521 = private unnamed_addr constant [14 x i8] c"println_float\00"
@.str.s522 = private unnamed_addr constant [5 x i8] c"void\00"
@.str.s523 = private unnamed_addr constant [13 x i8] c"println_char\00"
@.str.s524 = private unnamed_addr constant [11 x i8] c"print_char\00"
@.str.s525 = private unnamed_addr constant [5 x i8] c"void\00"
@.str.s526 = private unnamed_addr constant [13 x i8] c"println_bool\00"
@.str.s527 = private unnamed_addr constant [11 x i8] c"print_bool\00"
@.str.s528 = private unnamed_addr constant [5 x i8] c"void\00"
@.str.s529 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s530 = private unnamed_addr constant [7 x i8] c"ptrptr\00"
@.str.s531 = private unnamed_addr constant [4 x i8] c"ptr\00"
@.str.s532 = private unnamed_addr constant [4 x i8] c"i32\00"
@.str.s533 = private unnamed_addr constant [4 x i8] c"i32\00"
@.str.s534 = private unnamed_addr constant [4 x i8] c"i32\00"
@.str.s535 = private unnamed_addr constant [4 x i8] c"ptr\00"
@.str.s536 = private unnamed_addr constant [4 x i8] c"i32\00"
@.str.s537 = private unnamed_addr constant [4 x i8] c"and\00"
@.str.s538 = private unnamed_addr constant [4 x i8] c"sc.\00"
@.str.s539 = private unnamed_addr constant [3 x i8] c"i1\00"
@.str.s540 = private unnamed_addr constant [3 x i8] c"i1\00"
@.str.s541 = private unnamed_addr constant [3 x i8] c"i1\00"
@.str.s542 = private unnamed_addr constant [3 x i8] c"i1\00"
@.str.s543 = private unnamed_addr constant [5 x i8] c"true\00"
@.str.s544 = private unnamed_addr constant [2 x i8] c"1\00"
@.str.s545 = private unnamed_addr constant [2 x i8] c"0\00"
@.str.s546 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s547 = private unnamed_addr constant [4 x i8] c"i32\00"
@.str.s548 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s549 = private unnamed_addr constant [4 x i8] c"ptr\00"
@.str.s550 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s551 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s552 = private unnamed_addr constant [4 x i8] c"i32\00"
@.str.s553 = private unnamed_addr constant [7 x i8] c"double\00"
@.str.s554 = private unnamed_addr constant [7 x i8] c"double\00"
@.str.s555 = private unnamed_addr constant [2 x i8] c"!\00"
@.str.s556 = private unnamed_addr constant [3 x i8] c"i1\00"
@.str.s557 = private unnamed_addr constant [2 x i8] c"0\00"
@.str.s558 = private unnamed_addr constant [2 x i8] c"~\00"
@.str.s559 = private unnamed_addr constant [2 x i8] c"-\00"
@.str.s560 = private unnamed_addr constant [7 x i8] c"double\00"
@.str.s561 = private unnamed_addr constant [7 x i8] c"double\00"
@.str.s562 = private unnamed_addr constant [4 x i8] c"0.0\00"
@.str.s563 = private unnamed_addr constant [4 x i8] c"and\00"
@.str.s564 = private unnamed_addr constant [3 x i8] c"or\00"
@.str.s565 = private unnamed_addr constant [7 x i8] c"double\00"
@.str.s566 = private unnamed_addr constant [2 x i8] c"+\00"
@.str.s567 = private unnamed_addr constant [2 x i8] c"-\00"
@.str.s568 = private unnamed_addr constant [2 x i8] c"*\00"
@.str.s569 = private unnamed_addr constant [2 x i8] c"/\00"
@.str.s570 = private unnamed_addr constant [3 x i8] c"==\00"
@.str.s571 = private unnamed_addr constant [3 x i8] c"!=\00"
@.str.s572 = private unnamed_addr constant [2 x i8] c"<\00"
@.str.s573 = private unnamed_addr constant [3 x i8] c"<=\00"
@.str.s574 = private unnamed_addr constant [2 x i8] c">\00"
@.str.s575 = private unnamed_addr constant [3 x i8] c">=\00"
@.str.s576 = private unnamed_addr constant [2 x i8] c"+\00"
@.str.s577 = private unnamed_addr constant [2 x i8] c"-\00"
@.str.s578 = private unnamed_addr constant [2 x i8] c"*\00"
@.str.s579 = private unnamed_addr constant [3 x i8] c"==\00"
@.str.s580 = private unnamed_addr constant [3 x i8] c"!=\00"
@.str.s581 = private unnamed_addr constant [2 x i8] c"/\00"
@.str.s582 = private unnamed_addr constant [2 x i8] c"<\00"
@.str.s583 = private unnamed_addr constant [3 x i8] c"<=\00"
@.str.s584 = private unnamed_addr constant [2 x i8] c">\00"
@.str.s585 = private unnamed_addr constant [3 x i8] c">=\00"
@.str.s586 = private unnamed_addr constant [2 x i8] c"/\00"
@.str.s587 = private unnamed_addr constant [2 x i8] c"<\00"
@.str.s588 = private unnamed_addr constant [3 x i8] c"<=\00"
@.str.s589 = private unnamed_addr constant [2 x i8] c">\00"
@.str.s590 = private unnamed_addr constant [3 x i8] c">=\00"
@.str.s591 = private unnamed_addr constant [2 x i8] c"%\00"
@.str.s592 = private unnamed_addr constant [2 x i8] c"&\00"
@.str.s593 = private unnamed_addr constant [2 x i8] c"|\00"
@.str.s594 = private unnamed_addr constant [2 x i8] c"^\00"
@.str.s595 = private unnamed_addr constant [3 x i8] c"<<\00"
@.str.s596 = private unnamed_addr constant [3 x i8] c">>\00"
@.str.s597 = private unnamed_addr constant [5 x i8] c"drop\00"
@.str.s598 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s599 = private unnamed_addr constant [4 x i8] c"ptr\00"
@.str.s600 = private unnamed_addr constant [5 x i8] c"void\00"
@.str.s601 = private unnamed_addr constant [5 x i8] c"free\00"
@.str.s602 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s603 = private unnamed_addr constant [11 x i8] c"print_bool\00"
@.str.s604 = private unnamed_addr constant [13 x i8] c"println_bool\00"
@.str.s605 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s606 = private unnamed_addr constant [3 x i8] c"i1\00"
@.str.s607 = private unnamed_addr constant [4 x i8] c"i32\00"
@.str.s608 = private unnamed_addr constant [4 x i8] c"i32\00"
@.str.s609 = private unnamed_addr constant [5 x i8] c"void\00"
@.str.s610 = private unnamed_addr constant [11 x i8] c"print_bool\00"
@.str.s611 = private unnamed_addr constant [5 x i8] c"void\00"
@.str.s612 = private unnamed_addr constant [13 x i8] c"println_bool\00"
@.str.s613 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s614 = private unnamed_addr constant [6 x i8] c"print\00"
@.str.s615 = private unnamed_addr constant [8 x i8] c"println\00"
@.str.s616 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s617 = private unnamed_addr constant [4 x i8] c"ptr\00"
@.str.s618 = private unnamed_addr constant [4 x i8] c"ptr\00"
@.str.s619 = private unnamed_addr constant [5 x i8] c"void\00"
@.str.s620 = private unnamed_addr constant [6 x i8] c"print\00"
@.str.s621 = private unnamed_addr constant [5 x i8] c"void\00"
@.str.s622 = private unnamed_addr constant [8 x i8] c"println\00"
@.str.s623 = private unnamed_addr constant [7 x i8] c"double\00"
@.str.s624 = private unnamed_addr constant [7 x i8] c"double\00"
@.str.s625 = private unnamed_addr constant [5 x i8] c"void\00"
@.str.s626 = private unnamed_addr constant [12 x i8] c"print_float\00"
@.str.s627 = private unnamed_addr constant [5 x i8] c"void\00"
@.str.s628 = private unnamed_addr constant [14 x i8] c"println_float\00"
@.str.s629 = private unnamed_addr constant [5 x i8] c"void\00"
@.str.s630 = private unnamed_addr constant [10 x i8] c"print_int\00"
@.str.s631 = private unnamed_addr constant [5 x i8] c"void\00"
@.str.s632 = private unnamed_addr constant [12 x i8] c"println_int\00"
@.str.s633 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s634 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s635 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s636 = private unnamed_addr constant [5 x i8] c"void\00"
@.str.s637 = private unnamed_addr constant [5 x i8] c"void\00"
@.str.s638 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s639 = private unnamed_addr constant [2 x i8] c"0\00"
@.str.s640 = private unnamed_addr constant [4 x i8] c"i32\00"
@.str.s641 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s642 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s643 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s644 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s645 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s646 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s647 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s648 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s649 = private unnamed_addr constant [4 x i8] c"i32\00"
@.str.s650 = private unnamed_addr constant [4 x i8] c"i32\00"
@.str.s651 = private unnamed_addr constant [4 x i8] c"i32\00"
@.str.s652 = private unnamed_addr constant [4 x i8] c"i32\00"
@.str.s653 = private unnamed_addr constant [4 x i8] c"i32\00"
@.str.s654 = private unnamed_addr constant [4 x i8] c"i32\00"
@.str.s655 = private unnamed_addr constant [4 x i8] c"i32\00"
@.str.s656 = private unnamed_addr constant [2 x i8] c"1\00"
@.str.s657 = private unnamed_addr constant [4 x i8] c"i32\00"
@.str.s658 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s659 = private unnamed_addr constant [2 x i8] c"_\00"
@.str.s660 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s661 = private unnamed_addr constant [5 x i8] c"void\00"
@.str.s662 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s663 = private unnamed_addr constant [5 x i8] c"main\00"
@.str.s664 = private unnamed_addr constant [4 x i8] c"i32\00"
@.str.s665 = private unnamed_addr constant [4 x i8] c"i32\00"
@.str.s666 = private unnamed_addr constant [7 x i8] c"p_argc\00"
@.str.s667 = private unnamed_addr constant [4 x i8] c"ptr\00"
@.str.s668 = private unnamed_addr constant [7 x i8] c"p_argv\00"
@.str.s669 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s670 = private unnamed_addr constant [3 x i8] c"p_\00"
@.str.s671 = private unnamed_addr constant [4 x i8] c"i32\00"
@.str.s672 = private unnamed_addr constant [8 x i8] c"%p_argc\00"
@.str.s673 = private unnamed_addr constant [13 x i8] c"prismio_argc\00"
@.str.s674 = private unnamed_addr constant [4 x i8] c"ptr\00"
@.str.s675 = private unnamed_addr constant [8 x i8] c"%p_argv\00"
@.str.s676 = private unnamed_addr constant [13 x i8] c"prismio_argv\00"
@.str.s677 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s678 = private unnamed_addr constant [4 x i8] c"%p_\00"
@.str.s679 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s680 = private unnamed_addr constant [5 x i8] c"void\00"
@.str.s681 = private unnamed_addr constant [4 x i8] c"i32\00"
@.str.s682 = private unnamed_addr constant [2 x i8] c"0\00"
@.str.s683 = private unnamed_addr constant [2 x i8] c"0\00"
@.str.s684 = private unnamed_addr constant [7 x i8] c".str.s\00"
@.str.s685 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s686 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s687 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s688 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s689 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s690 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s691 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s692 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s693 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s694 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s695 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s696 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s697 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s698 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s699 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s700 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s701 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s702 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s703 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s704 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s705 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s706 = private unnamed_addr constant [19 x i8] c"self_hosted_module\00"
@.str.s707 = private unnamed_addr constant [19 x i8] c"self_hosted_module\00"
@.str.s708 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s709 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s710 = private unnamed_addr constant [13 x i8] c"prismio_argc\00"
@.str.s711 = private unnamed_addr constant [4 x i8] c"i32\00"
@.str.s712 = private unnamed_addr constant [2 x i8] c"0\00"
@.str.s713 = private unnamed_addr constant [13 x i8] c"prismio_argv\00"
@.str.s714 = private unnamed_addr constant [4 x i8] c"ptr\00"
@.str.s715 = private unnamed_addr constant [5 x i8] c"null\00"
@.str.s716 = private unnamed_addr constant [7 x i8] c"malloc\00"
@.str.s717 = private unnamed_addr constant [4 x i8] c"ptr\00"
@.str.s718 = private unnamed_addr constant [5 x i8] c"free\00"
@.str.s719 = private unnamed_addr constant [5 x i8] c"void\00"
@.str.s720 = private unnamed_addr constant [4 x i8] c"ptr\00"
@.str.s721 = private unnamed_addr constant [9 x i8] c"list_new\00"
@.str.s722 = private unnamed_addr constant [4 x i8] c"ptr\00"
@.str.s723 = private unnamed_addr constant [10 x i8] c"list_push\00"
@.str.s724 = private unnamed_addr constant [5 x i8] c"void\00"
@.str.s725 = private unnamed_addr constant [4 x i8] c"ptr\00"
@.str.s726 = private unnamed_addr constant [4 x i8] c"ptr\00"
@.str.s727 = private unnamed_addr constant [9 x i8] c"list_get\00"
@.str.s728 = private unnamed_addr constant [4 x i8] c"ptr\00"
@.str.s729 = private unnamed_addr constant [4 x i8] c"ptr\00"
@.str.s730 = private unnamed_addr constant [4 x i8] c"i32\00"
@.str.s731 = private unnamed_addr constant [9 x i8] c"list_set\00"
@.str.s732 = private unnamed_addr constant [5 x i8] c"void\00"
@.str.s733 = private unnamed_addr constant [4 x i8] c"ptr\00"
@.str.s734 = private unnamed_addr constant [4 x i8] c"i32\00"
@.str.s735 = private unnamed_addr constant [4 x i8] c"ptr\00"
@.str.s736 = private unnamed_addr constant [9 x i8] c"list_len\00"
@.str.s737 = private unnamed_addr constant [4 x i8] c"i32\00"
@.str.s738 = private unnamed_addr constant [4 x i8] c"ptr\00"
@.str.s739 = private unnamed_addr constant [8 x i8] c"println\00"
@.str.s740 = private unnamed_addr constant [5 x i8] c"void\00"
@.str.s741 = private unnamed_addr constant [4 x i8] c"ptr\00"
@.str.s742 = private unnamed_addr constant [6 x i8] c"print\00"
@.str.s743 = private unnamed_addr constant [5 x i8] c"void\00"
@.str.s744 = private unnamed_addr constant [4 x i8] c"ptr\00"
@.str.s745 = private unnamed_addr constant [12 x i8] c"println_int\00"
@.str.s746 = private unnamed_addr constant [5 x i8] c"void\00"
@.str.s747 = private unnamed_addr constant [4 x i8] c"i32\00"
@.str.s748 = private unnamed_addr constant [10 x i8] c"print_int\00"
@.str.s749 = private unnamed_addr constant [5 x i8] c"void\00"
@.str.s750 = private unnamed_addr constant [4 x i8] c"i32\00"
@.str.s751 = private unnamed_addr constant [14 x i8] c"println_float\00"
@.str.s752 = private unnamed_addr constant [5 x i8] c"void\00"
@.str.s753 = private unnamed_addr constant [7 x i8] c"double\00"
@.str.s754 = private unnamed_addr constant [12 x i8] c"print_float\00"
@.str.s755 = private unnamed_addr constant [5 x i8] c"void\00"
@.str.s756 = private unnamed_addr constant [7 x i8] c"double\00"
@.str.s757 = private unnamed_addr constant [13 x i8] c"println_bool\00"
@.str.s758 = private unnamed_addr constant [5 x i8] c"void\00"
@.str.s759 = private unnamed_addr constant [4 x i8] c"i32\00"
@.str.s760 = private unnamed_addr constant [11 x i8] c"print_bool\00"
@.str.s761 = private unnamed_addr constant [5 x i8] c"void\00"
@.str.s762 = private unnamed_addr constant [4 x i8] c"i32\00"
@.str.s763 = private unnamed_addr constant [13 x i8] c"println_char\00"
@.str.s764 = private unnamed_addr constant [5 x i8] c"void\00"
@.str.s765 = private unnamed_addr constant [3 x i8] c"i8\00"
@.str.s766 = private unnamed_addr constant [11 x i8] c"print_char\00"
@.str.s767 = private unnamed_addr constant [5 x i8] c"void\00"
@.str.s768 = private unnamed_addr constant [3 x i8] c"i8\00"
@.str.s769 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s770 = private unnamed_addr constant [2 x i8] c"0\00"
@.str.s771 = private unnamed_addr constant [4 x i8] c"i32\00"
@.str.s772 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s773 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s774 = private unnamed_addr constant [2 x i8] c"@\00"
@.str.s775 = private unnamed_addr constant [64 x i8] c"internal error: non-constant global initializer reached codegen\00"
@.str.s776 = private unnamed_addr constant [5 x i8] c"main\00"
@.str.s777 = private unnamed_addr constant [4 x i8] c"i32\00"
@.str.s778 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s779 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s780 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s781 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s782 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s783 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s784 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s785 = private unnamed_addr constant [5 x i8] c"$fn$\00"
@.str.s786 = private unnamed_addr constant [5 x i8] c"Void\00"
@.str.s787 = private unnamed_addr constant [6 x i8] c"Float\00"
@.str.s788 = private unnamed_addr constant [5 x i8] c"Bool\00"
@.str.s789 = private unnamed_addr constant [5 x i8] c"Char\00"
@.str.s790 = private unnamed_addr constant [7 x i8] c"String\00"
@.str.s791 = private unnamed_addr constant [4 x i8] c"Ptr\00"
@.str.s792 = private unnamed_addr constant [8 x i8] c"Struct_\00"
@.str.s793 = private unnamed_addr constant [6 x i8] c"Enum_\00"
@.str.s794 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s795 = private unnamed_addr constant [7 x i8] c"Array_\00"
@.str.s796 = private unnamed_addr constant [14 x i8] c"Array_Invalid\00"
@.str.s797 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s798 = private unnamed_addr constant [6 x i8] c"List_\00"
@.str.s799 = private unnamed_addr constant [13 x i8] c"List_Invalid\00"
@.str.s800 = private unnamed_addr constant [8 x i8] c"Invalid\00"
@.str.s801 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s802 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s803 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s804 = private unnamed_addr constant [2 x i8] c"_\00"
@.str.s805 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s806 = private unnamed_addr constant [5 x i8] c"Void\00"
@.str.s807 = private unnamed_addr constant [5 x i8] c"main\00"
@.str.s808 = private unnamed_addr constant [5 x i8] c"main\00"
@.str.s809 = private unnamed_addr constant [3 x i8] c"__\00"
@.str.s810 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s811 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s812 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s813 = private unnamed_addr constant [12 x i8] c": expected \00"
@.str.s814 = private unnamed_addr constant [9 x i8] c", found \00"
@.str.s815 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s816 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s817 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s818 = private unnamed_addr constant [4 x i8] c"Int\00"
@.str.s819 = private unnamed_addr constant [6 x i8] c"Float\00"
@.str.s820 = private unnamed_addr constant [5 x i8] c"Bool\00"
@.str.s821 = private unnamed_addr constant [7 x i8] c"String\00"
@.str.s822 = private unnamed_addr constant [5 x i8] c"Char\00"
@.str.s823 = private unnamed_addr constant [3 x i8] c"I8\00"
@.str.s824 = private unnamed_addr constant [4 x i8] c"I16\00"
@.str.s825 = private unnamed_addr constant [4 x i8] c"I64\00"
@.str.s826 = private unnamed_addr constant [6 x i8] c"Isize\00"
@.str.s827 = private unnamed_addr constant [3 x i8] c"U8\00"
@.str.s828 = private unnamed_addr constant [4 x i8] c"U16\00"
@.str.s829 = private unnamed_addr constant [4 x i8] c"U32\00"
@.str.s830 = private unnamed_addr constant [4 x i8] c"U64\00"
@.str.s831 = private unnamed_addr constant [6 x i8] c"Usize\00"
@.str.s832 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s833 = private unnamed_addr constant [14 x i8] c"unknown type \00"
@.str.s834 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s835 = private unnamed_addr constant [4 x i8] c"Int\00"
@.str.s836 = private unnamed_addr constant [35 x i8] c"cannot move out of borrowed value \00"
@.str.s837 = private unnamed_addr constant [72 x i8] c" is moved inside a loop, so the move would repeat on the next iteration\00"
@.str.s838 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s839 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s840 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s841 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s842 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s843 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s844 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s845 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s846 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s847 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s848 = private unnamed_addr constant [19 x i8] c"ambiguous call to \00"
@.str.s849 = private unnamed_addr constant [49 x i8] c": more than one overload matches these arguments\00"
@.str.s850 = private unnamed_addr constant [16 x i8] c"no overload of \00"
@.str.s851 = private unnamed_addr constant [30 x i8] c" accepts these argument types\00"
@.str.s852 = private unnamed_addr constant [18 x i8] c"unknown function \00"
@.str.s853 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s854 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s855 = private unnamed_addr constant [8 x i8] c"struct \00"
@.str.s856 = private unnamed_addr constant [15 x i8] c" has no field \00"
@.str.s857 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s858 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s859 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s860 = private unnamed_addr constant [19 x i8] c" arguments, found \00"
@.str.s861 = private unnamed_addr constant [18 x i8] c" argument, found \00"
@.str.s862 = private unnamed_addr constant [10 x i8] c" expects \00"
@.str.s863 = private unnamed_addr constant [6 x i8] c"print\00"
@.str.s864 = private unnamed_addr constant [8 x i8] c"println\00"
@.str.s865 = private unnamed_addr constant [10 x i8] c"print_int\00"
@.str.s866 = private unnamed_addr constant [12 x i8] c"println_int\00"
@.str.s867 = private unnamed_addr constant [12 x i8] c"print_float\00"
@.str.s868 = private unnamed_addr constant [14 x i8] c"println_float\00"
@.str.s869 = private unnamed_addr constant [11 x i8] c"print_bool\00"
@.str.s870 = private unnamed_addr constant [13 x i8] c"println_bool\00"
@.str.s871 = private unnamed_addr constant [11 x i8] c"print_char\00"
@.str.s872 = private unnamed_addr constant [13 x i8] c"println_char\00"
@.str.s873 = private unnamed_addr constant [5 x i8] c"drop\00"
@.str.s874 = private unnamed_addr constant [9 x i8] c"list_new\00"
@.str.s875 = private unnamed_addr constant [9 x i8] c"list_len\00"
@.str.s876 = private unnamed_addr constant [10 x i8] c"list_push\00"
@.str.s877 = private unnamed_addr constant [9 x i8] c"list_set\00"
@.str.s878 = private unnamed_addr constant [9 x i8] c"list_get\00"
@.str.s879 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s880 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s881 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s882 = private unnamed_addr constant [6 x i8] c"print\00"
@.str.s883 = private unnamed_addr constant [8 x i8] c"println\00"
@.str.s884 = private unnamed_addr constant [5 x i8] c"drop\00"
@.str.s885 = private unnamed_addr constant [49 x i8] c"drop requires an owned (move-only) value, found \00"
@.str.s886 = private unnamed_addr constant [9 x i8] c"list_new\00"
@.str.s887 = private unnamed_addr constant [9 x i8] c"list_len\00"
@.str.s888 = private unnamed_addr constant [32 x i8] c"list_len expects a List, found \00"
@.str.s889 = private unnamed_addr constant [9 x i8] c"list_get\00"
@.str.s890 = private unnamed_addr constant [32 x i8] c"list_get expects a List, found \00"
@.str.s891 = private unnamed_addr constant [15 x i8] c"list_get index\00"
@.str.s892 = private unnamed_addr constant [10 x i8] c"list_push\00"
@.str.s893 = private unnamed_addr constant [33 x i8] c"list_push expects a List, found \00"
@.str.s894 = private unnamed_addr constant [16 x i8] c"list_push value\00"
@.str.s895 = private unnamed_addr constant [9 x i8] c"list_set\00"
@.str.s896 = private unnamed_addr constant [32 x i8] c"list_set expects a List, found \00"
@.str.s897 = private unnamed_addr constant [15 x i8] c"list_set index\00"
@.str.s898 = private unnamed_addr constant [15 x i8] c"list_set value\00"
@.str.s899 = private unnamed_addr constant [10 x i8] c"print_int\00"
@.str.s900 = private unnamed_addr constant [12 x i8] c"println_int\00"
@.str.s901 = private unnamed_addr constant [12 x i8] c"print_float\00"
@.str.s902 = private unnamed_addr constant [14 x i8] c"println_float\00"
@.str.s903 = private unnamed_addr constant [11 x i8] c"print_bool\00"
@.str.s904 = private unnamed_addr constant [13 x i8] c"println_bool\00"
@.str.s905 = private unnamed_addr constant [11 x i8] c"print_char\00"
@.str.s906 = private unnamed_addr constant [13 x i8] c"println_char\00"
@.str.s907 = private unnamed_addr constant [10 x i8] c" argument\00"
@.str.s908 = private unnamed_addr constant [20 x i8] c"unknown identifier \00"
@.str.s909 = private unnamed_addr constant [20 x i8] c"use of moved value \00"
@.str.s910 = private unnamed_addr constant [64 x i8] c"cannot cast to Bool; compare explicitly instead, as in `x != 0`\00"
@.str.s911 = private unnamed_addr constant [5 x i8] c"cast\00"
@.str.s912 = private unnamed_addr constant [2 x i8] c"!\00"
@.str.s913 = private unnamed_addr constant [13 x i8] c"operator `!`\00"
@.str.s914 = private unnamed_addr constant [2 x i8] c"~\00"
@.str.s915 = private unnamed_addr constant [38 x i8] c"unary `~` requires an integer operand\00"
@.str.s916 = private unnamed_addr constant [2 x i8] c"-\00"
@.str.s917 = private unnamed_addr constant [37 x i8] c"unary `-` requires a numeric operand\00"
@.str.s918 = private unnamed_addr constant [41 x i8] c"cannot apply unary `-` to unsigned type \00"
@.str.s919 = private unnamed_addr constant [24 x i8] c"unknown unary operator \00"
@.str.s920 = private unnamed_addr constant [4 x i8] c"and\00"
@.str.s921 = private unnamed_addr constant [3 x i8] c"or\00"
@.str.s922 = private unnamed_addr constant [30 x i8] c"boolean operator left operand\00"
@.str.s923 = private unnamed_addr constant [31 x i8] c"boolean operator right operand\00"
@.str.s924 = private unnamed_addr constant [2 x i8] c"+\00"
@.str.s925 = private unnamed_addr constant [2 x i8] c"-\00"
@.str.s926 = private unnamed_addr constant [2 x i8] c"*\00"
@.str.s927 = private unnamed_addr constant [2 x i8] c"/\00"
@.str.s928 = private unnamed_addr constant [10 x i8] c"operator \00"
@.str.s929 = private unnamed_addr constant [27 x i8] c" requires numeric operands\00"
@.str.s930 = private unnamed_addr constant [10 x i8] c"operator \00"
@.str.s931 = private unnamed_addr constant [2 x i8] c"%\00"
@.str.s932 = private unnamed_addr constant [39 x i8] c"operator `%` requires integer operands\00"
@.str.s933 = private unnamed_addr constant [13 x i8] c"operator `%`\00"
@.str.s934 = private unnamed_addr constant [2 x i8] c"&\00"
@.str.s935 = private unnamed_addr constant [2 x i8] c"|\00"
@.str.s936 = private unnamed_addr constant [2 x i8] c"^\00"
@.str.s937 = private unnamed_addr constant [18 x i8] c"bitwise operator \00"
@.str.s938 = private unnamed_addr constant [27 x i8] c" requires integer operands\00"
@.str.s939 = private unnamed_addr constant [10 x i8] c"operator \00"
@.str.s940 = private unnamed_addr constant [3 x i8] c"<<\00"
@.str.s941 = private unnamed_addr constant [3 x i8] c">>\00"
@.str.s942 = private unnamed_addr constant [7 x i8] c"shift \00"
@.str.s943 = private unnamed_addr constant [34 x i8] c" requires an integer left operand\00"
@.str.s944 = private unnamed_addr constant [21 x i8] c"the shift amount of \00"
@.str.s945 = private unnamed_addr constant [20 x i8] c" must be an integer\00"
@.str.s946 = private unnamed_addr constant [3 x i8] c"==\00"
@.str.s947 = private unnamed_addr constant [3 x i8] c"!=\00"
@.str.s948 = private unnamed_addr constant [2 x i8] c"<\00"
@.str.s949 = private unnamed_addr constant [3 x i8] c"<=\00"
@.str.s950 = private unnamed_addr constant [2 x i8] c">\00"
@.str.s951 = private unnamed_addr constant [3 x i8] c">=\00"
@.str.s952 = private unnamed_addr constant [67 x i8] c"cannot compare String values directly; use `str_equals(a, b) == 1`\00"
@.str.s953 = private unnamed_addr constant [60 x i8] c"cannot compare struct values directly; compare their fields\00"
@.str.s954 = private unnamed_addr constant [12 x i8] c"comparison \00"
@.str.s955 = private unnamed_addr constant [18 x i8] c"unknown operator \00"
@.str.s956 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s957 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s958 = private unnamed_addr constant [10 x i8] c" argument\00"
@.str.s959 = private unnamed_addr constant [5 x i8] c"sink\00"
@.str.s960 = private unnamed_addr constant [5 x i8] c"main\00"
@.str.s961 = private unnamed_addr constant [46 x i8] c"member access requires a struct value, found \00"
@.str.s962 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s963 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s964 = private unnamed_addr constant [22 x i8] c"array literal element\00"
@.str.s965 = private unnamed_addr constant [12 x i8] c"array index\00"
@.str.s966 = private unnamed_addr constant [35 x i8] c"indexing requires an array, found \00"
@.str.s967 = private unnamed_addr constant [16 x i8] c"unknown struct \00"
@.str.s968 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s969 = private unnamed_addr constant [14 x i8] c"struct field \00"
@.str.s970 = private unnamed_addr constant [23 x i8] c"unsupported expression\00"
@.str.s971 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s972 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s973 = private unnamed_addr constant [17 x i8] c"initializer for \00"
@.str.s974 = private unnamed_addr constant [25 x i8] c"cannot infer a type for \00"
@.str.s975 = private unnamed_addr constant [42 x i8] c"; add a type annotation or an initializer\00"
@.str.s976 = private unnamed_addr constant [18 x i8] c"cannot assign to \00"
@.str.s977 = private unnamed_addr constant [30 x i8] c", which is not declared `mut`\00"
@.str.s978 = private unnamed_addr constant [36 x i8] c"change its declaration to `let mut`\00"
@.str.s979 = private unnamed_addr constant [11 x i8] c"assignment\00"
@.str.s980 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s981 = private unnamed_addr constant [7 x i8] c"return\00"
@.str.s982 = private unnamed_addr constant [107 x i8] c"cannot return an array created in this function; it lives on the stack frame that is about to be discarded\00"
@.str.s983 = private unnamed_addr constant [74 x i8] c"return an array that was passed in, or write into one the caller provides\00"
@.str.s984 = private unnamed_addr constant [7 x i8] c"return\00"
@.str.s985 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s986 = private unnamed_addr constant [13 x i8] c"if condition\00"
@.str.s987 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s988 = private unnamed_addr constant [16 x i8] c"while condition\00"
@.str.s989 = private unnamed_addr constant [16 x i8] c"for range start\00"
@.str.s990 = private unnamed_addr constant [14 x i8] c"for range end\00"
@.str.s991 = private unnamed_addr constant [57 x i8] c"match scrutinee must be an integer or enum value, found \00"
@.str.s992 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s993 = private unnamed_addr constant [2 x i8] c"_\00"
@.str.s994 = private unnamed_addr constant [14 x i8] c"match pattern\00"
@.str.s995 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s996 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s997 = private unnamed_addr constant [70 x i8] c"unreachable code: control cannot continue past the previous statement\00"
@.str.s998 = private unnamed_addr constant [5 x i8] c"main\00"
@.str.s999 = private unnamed_addr constant [25 x i8] c"duplicate definition of \00"
@.str.s1000 = private unnamed_addr constant [31 x i8] c" with the same parameter types\00"
@.str.s1001 = private unnamed_addr constant [29 x i8] c"the first definition is here\00"
@.str.s1002 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s1003 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s1004 = private unnamed_addr constant [24 x i8] c"initializer for global \00"
@.str.s1005 = private unnamed_addr constant [8 x i8] c"global \00"
@.str.s1006 = private unnamed_addr constant [30 x i8] c" needs a constant initializer\00"
@.str.s1007 = private unnamed_addr constant [115 x i8] c"nothing runs before main, so a global cannot be initialized by an expression; move the computation into a function\00"
@.str.s1008 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s1009 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s1010 = private unnamed_addr constant [32 x i8] c"cannot infer a type for global \00"
@.str.s1011 = private unnamed_addr constant [42 x i8] c"; add a type annotation or an initializer\00"
@.str.s1012 = private unnamed_addr constant [5 x i8] c"main\00"
@.str.s1013 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s1014 = private unnamed_addr constant [6 x i8] c"inout\00"
@.str.s1015 = private unnamed_addr constant [17 x i8] c"inout parameter \00"
@.str.s1016 = private unnamed_addr constant [35 x i8] c" must be a struct (reference) type\00"
@.str.s1017 = private unnamed_addr constant [5 x i8] c"sink\00"
@.str.s1018 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s1019 = private unnamed_addr constant [10 x i8] c"function \00"
@.str.s1020 = private unnamed_addr constant [14 x i8] c" must return \00"
@.str.s1021 = private unnamed_addr constant [56 x i8] c" on every path, but control can reach its closing brace\00"
@.str.s1022 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s1023 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s1024 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s1025 = private unnamed_addr constant [6 x i8] c"0.1.0\00"
@PRISMIO_VERSION = global ptr @.str.s1025
@.str.s1026 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s1027 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s1028 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s1029 = private unnamed_addr constant [5 x i8] c".psm\00"
@.str.s1030 = private unnamed_addr constant [2 x i8] c".\00"
@.str.s1031 = private unnamed_addr constant [2 x i8] c"|\00"
@.str.s1032 = private unnamed_addr constant [2 x i8] c"|\00"
@.str.s1033 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s1034 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s1035 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s1036 = private unnamed_addr constant [29 x i8] c"cannot read imported module \00"
@.str.s1037 = private unnamed_addr constant [16 x i8] c": no such file \00"
@.str.s1038 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s1039 = private unnamed_addr constant [7 x i8] c"Usage:\00"
@.str.s1040 = private unnamed_addr constant [45 x i8] c"  prismio build <source.psm> [-o output.exe]\00"
@.str.s1041 = private unnamed_addr constant [43 x i8] c"  prismio run <source.psm> [-o output.exe]\00"
@.str.s1042 = private unnamed_addr constant [49 x i8] c"  prismio bootstrap [source.psm] [-o output.exe]\00"
@.str.s1043 = private unnamed_addr constant [23 x i8] c"  prismio runtime-hash\00"
@.str.s1044 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s1045 = private unnamed_addr constant [59 x i8] c"build/run link against the installed Prismio runtime only.\00"
@.str.s1046 = private unnamed_addr constant [66 x i8] c"bootstrap builds the compiler itself from the repository sources,\00"
@.str.s1047 = private unnamed_addr constant [71 x i8] c"linking the compiler backend as well and ignoring installed libraries.\00"
@.str.s1048 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s1049 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s1050 = private unnamed_addr constant [47 x i8] c"the installed Prismio runtime library is stale\00"
@.str.s1051 = private unnamed_addr constant [50 x i8] c"  runtime library was built from sources hashing \00"
@.str.s1052 = private unnamed_addr constant [40 x i8] c"  the runtime sources on disk now hash \00"
@.str.s1053 = private unnamed_addr constant [73 x i8] c"  Re-package the toolchain (tools/package.ps1) so lib/ matches runtime/,\00"
@.str.s1054 = private unnamed_addr constant [72 x i8] c"  or move away from the source tree to use the installed runtime as-is.\00"
@.str.s1055 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s1056 = private unnamed_addr constant [4 x i8] c".ll\00"
@.str.s1057 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s1058 = private unnamed_addr constant [13 x i8] c"cannot read \00"
@.str.s1059 = private unnamed_addr constant [66 x i8] c"  bootstrap compiles the Prismio compiler from a source checkout.\00"
@.str.s1060 = private unnamed_addr constant [71 x i8] c"  Run it from the repository root, or give the source path explicitly:\00"
@.str.s1061 = private unnamed_addr constant [45 x i8] c"      prismio bootstrap path/to/src/main.psm\00"
@.str.s1062 = private unnamed_addr constant [25 x i8] c"cannot write LLVM IR to \00"
@.str.s1063 = private unnamed_addr constant [16 x i8] c"Wrote LLVM IR: \00"
@.str.s1064 = private unnamed_addr constant [63 x i8] c"the native build step failed (llc/clang); see the output above\00"
@.str.s1065 = private unnamed_addr constant [7 x i8] c"Built \00"
@.str.s1066 = private unnamed_addr constant [30 x i8] c" exited with a failure status\00"
@.str.s1067 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s1068 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s1069 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s1070 = private unnamed_addr constant [7 x i8] c"--help\00"
@.str.s1071 = private unnamed_addr constant [3 x i8] c"-h\00"
@.str.s1072 = private unnamed_addr constant [10 x i8] c"--version\00"
@.str.s1073 = private unnamed_addr constant [3 x i8] c"-V\00"
@.str.s1074 = private unnamed_addr constant [9 x i8] c"prismio \00"
@.str.s1075 = private unnamed_addr constant [6 x i8] c"llvm \00"
@.str.s1076 = private unnamed_addr constant [13 x i8] c"runtime-hash\00"
@.str.s1077 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s1078 = private unnamed_addr constant [48 x i8] c"cannot find the Prismio runtime sources to hash\00"
@.str.s1079 = private unnamed_addr constant [10 x i8] c"bootstrap\00"
@.str.s1080 = private unnamed_addr constant [10 x i8] c"bootstrap\00"
@.str.s1081 = private unnamed_addr constant [13 x i8] c"src/main.psm\00"
@.str.s1082 = private unnamed_addr constant [3 x i8] c"-o\00"
@.str.s1083 = private unnamed_addr constant [9 x i8] c"--target\00"
@.str.s1084 = private unnamed_addr constant [3 x i8] c"-o\00"
@.str.s1085 = private unnamed_addr constant [29 x i8] c"`-o` requires an output path\00"
@.str.s1086 = private unnamed_addr constant [18 x i8] c"unknown argument \00"
@.str.s1087 = private unnamed_addr constant [6 x i8] c"build\00"
@.str.s1088 = private unnamed_addr constant [6 x i8] c"build\00"
@.str.s1089 = private unnamed_addr constant [20 x i8] c"missing source file\00"
@.str.s1090 = private unnamed_addr constant [4 x i8] c"run\00"
@.str.s1091 = private unnamed_addr constant [6 x i8] c"build\00"
@.str.s1092 = private unnamed_addr constant [38 x i8] c"use either `build` or `run`, not both\00"
@.str.s1093 = private unnamed_addr constant [4 x i8] c"run\00"
@.str.s1094 = private unnamed_addr constant [4 x i8] c"run\00"
@.str.s1095 = private unnamed_addr constant [20 x i8] c"missing source file\00"
@.str.s1096 = private unnamed_addr constant [4 x i8] c"run\00"
@.str.s1097 = private unnamed_addr constant [6 x i8] c"build\00"
@.str.s1098 = private unnamed_addr constant [38 x i8] c"use either `build` or `run`, not both\00"
@.str.s1099 = private unnamed_addr constant [6 x i8] c"build\00"
@.str.s1100 = private unnamed_addr constant [3 x i8] c"-o\00"
@.str.s1101 = private unnamed_addr constant [29 x i8] c"`-o` requires an output path\00"
@.str.s1102 = private unnamed_addr constant [3 x i8] c"-O\00"
@.str.s1103 = private unnamed_addr constant [28 x i8] c"unknown optimization level \00"
@.str.s1104 = private unnamed_addr constant [9 x i8] c"--target\00"
@.str.s1105 = private unnamed_addr constant [42 x i8] c"`--target` requires a value (e.g. wasm32)\00"
@.str.s1106 = private unnamed_addr constant [7 x i8] c"wasm32\00"
@.str.s1107 = private unnamed_addr constant [6 x i8] c"build\00"
@.str.s1108 = private unnamed_addr constant [4 x i8] c"run\00"
@.str.s1109 = private unnamed_addr constant [38 x i8] c"use either `build` or `run`, not both\00"
@.str.s1110 = private unnamed_addr constant [6 x i8] c"build\00"
@.str.s1111 = private unnamed_addr constant [18 x i8] c"unknown argument \00"

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

declare i32 @diag_add_file(ptr, ptr)

declare ptr @diag_file_path(i32)

declare void @diag_error_at(i32, i32, i32, i32, ptr)

declare void @diag_warning_at(i32, i32, i32, i32, ptr)

declare void @diag_note_at(i32, i32, i32, i32, ptr)

declare void @diag_error(ptr)

declare void @diag_note(ptr)

declare i32 @diag_error_count()

declare i32 @diag_warning_count()

declare void @diag_finish()

declare void @diag_reset()

declare void @exit(i32)

declare ptr @str_from_char(i8)

declare i8 @str_byte_at(ptr, i32)

declare ptr @ptr_to_token(ptr)

declare ptr @token_to_ptr(ptr)

declare ptr @ptr_to_node(ptr)

declare ptr @node_to_ptr(ptr)

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

declare i32 @ir_zext(ptr, ptr, ptr)

declare i32 @ir_sext(ptr, ptr, ptr)

declare i32 @ir_trunc(ptr, ptr, ptr)

declare i32 @ir_sitofp(ptr, ptr, ptr)

declare i32 @ir_uitofp(ptr, ptr, ptr)

declare i32 @ir_fptosi(ptr, ptr, ptr)

declare i32 @ir_fptoui(ptr, ptr, ptr)

declare i32 @ir_and(ptr, ptr, ptr)

declare i32 @ir_or(ptr, ptr, ptr)

declare i32 @ir_xor(ptr, ptr, ptr)

declare i32 @ir_not(ptr, ptr)

declare i32 @ir_shl(ptr, ptr, ptr)

declare i32 @ir_lshr(ptr, ptr, ptr)

declare i32 @ir_ashr(ptr, ptr, ptr)

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

declare void @ir_set_pointer_int_type(ptr)

declare void @ir_set_opt_level(i32)

declare void @ir_set_alloc_function(ptr)

declare void @ir_set_free_function(ptr)

declare ptr @ir_get_alloc_function()

declare ptr @ir_get_free_function()

declare void @ir_struct_type_begin(ptr)

declare void @ir_struct_type_field(ptr)

declare void @ir_struct_type_end()

declare i32 @ir_alloc_object(ptr)

declare void @ir_free_object(ptr)

declare i32 @ir_struct_field_ptr(ptr, ptr, i32)

declare i32 @ir_elem_ptr(ptr, ptr, ptr)

declare i32 @ir_array_alloca(ptr, i32)

declare i32 @ir_string_ptr(ptr)

declare i32 @ir_load_ptr(ptr, ptr)

declare void @ir_store_ptr(ptr, ptr, ptr)

declare ptr @ir_get_temp_name(i32)

declare ptr @ir_get_label_name(i32)

declare void @ir_register_global_name(ptr)

declare i32 @ir_is_global_name(ptr)

declare void @ir_reset_globals()

declare void @ir_reset_types()

declare void @ir_declare_named_type(ptr, i32)

declare i32 @ir_named_type_kind(ptr)

declare void @ir_reset_named_types()

declare void @ir_register_struct(ptr)

declare void @ir_register_struct_field(ptr, ptr, ptr)

declare i32 @ir_is_struct_type_name(ptr)

declare i32 @ir_get_struct_field_index(ptr, ptr)

declare ptr @ir_get_struct_field_type(ptr, ptr)

declare void @ir_register_enum_variant(ptr, ptr, i32)

declare i32 @ir_get_enum_variant(ptr, ptr)

declare void @ir_set_var_type(ptr, ptr)

declare void @ir_set_global_var_type(ptr, ptr)

declare ptr @ir_get_var_type(ptr)

declare i32 @ir_has_var_type(ptr)

declare void @ir_scope_push()

declare void @ir_scope_pop()

declare void @ir_loop_barrier_push()

declare void @ir_loop_barrier_pop()

declare i32 @ir_binding_predates_loop(ptr)

declare ptr @ir_get_var_slot(ptr)

declare i32 @ir_var_is_global(ptr)

declare void @ir_mark_mutable(ptr)

declare i32 @ir_var_is_mutable(ptr)

declare void @ir_clear_var_types()

declare void @ir_clear_local_var_types()

declare void @ir_set_returned()

declare i32 @ir_has_returned()

declare void @ir_clear_returned()

declare void @ir_comment(ptr)

declare void @ir_blank_line()

declare ptr @ptr_to_type(ptr)

declare ptr @type_to_ptr(ptr)

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

declare ptr @ir_llvm_version()

define ptr @type_to_string__Enum_TokenType(i32 %0) {
entry:
  %t.382 = alloca i32, align 4
  store i32 %0, ptr %t.382, align 4
  %1 = load i32, ptr %t.382, align 4
  %2 = icmp eq i32 %1, 0
  br i1 %2, label %label_0, label %label_2

label_2:                                          ; preds = %entry
  %3 = load i32, ptr %t.382, align 4
  %4 = icmp eq i32 %3, 1
  br i1 %4, label %label_3, label %label_5

label_0:                                          ; preds = %entry
  ret ptr @.str.s0

label_5:                                          ; preds = %label_2
  %5 = load i32, ptr %t.382, align 4
  %6 = icmp eq i32 %5, 2
  br i1 %6, label %label_6, label %label_8

label_3:                                          ; preds = %label_2
  ret ptr @.str.s1

label_8:                                          ; preds = %label_5
  %7 = load i32, ptr %t.382, align 4
  %8 = icmp eq i32 %7, 3
  br i1 %8, label %label_9, label %label_11

label_6:                                          ; preds = %label_5
  ret ptr @.str.s2

label_11:                                         ; preds = %label_8
  %9 = load i32, ptr %t.382, align 4
  %10 = icmp eq i32 %9, 4
  br i1 %10, label %label_12, label %label_14

label_9:                                          ; preds = %label_8
  ret ptr @.str.s3

label_14:                                         ; preds = %label_11
  %11 = load i32, ptr %t.382, align 4
  %12 = icmp eq i32 %11, 5
  br i1 %12, label %label_15, label %label_17

label_12:                                         ; preds = %label_11
  ret ptr @.str.s4

label_17:                                         ; preds = %label_14
  %13 = load i32, ptr %t.382, align 4
  %14 = icmp eq i32 %13, 18
  br i1 %14, label %label_18, label %label_20

label_15:                                         ; preds = %label_14
  ret ptr @.str.s5

label_20:                                         ; preds = %label_17
  %15 = load i32, ptr %t.382, align 4
  %16 = icmp eq i32 %15, 6
  br i1 %16, label %label_21, label %label_23

label_18:                                         ; preds = %label_17
  ret ptr @.str.s6

label_23:                                         ; preds = %label_20
  %17 = load i32, ptr %t.382, align 4
  %18 = icmp eq i32 %17, 8
  br i1 %18, label %label_24, label %label_26

label_21:                                         ; preds = %label_20
  ret ptr @.str.s7

label_26:                                         ; preds = %label_23
  %19 = load i32, ptr %t.382, align 4
  %20 = icmp eq i32 %19, 9
  br i1 %20, label %label_27, label %label_29

label_24:                                         ; preds = %label_23
  ret ptr @.str.s8

label_29:                                         ; preds = %label_26
  %21 = load i32, ptr %t.382, align 4
  %22 = icmp eq i32 %21, 12
  br i1 %22, label %label_30, label %label_32

label_27:                                         ; preds = %label_26
  ret ptr @.str.s9

label_32:                                         ; preds = %label_29
  %23 = load i32, ptr %t.382, align 4
  %24 = icmp eq i32 %23, 15
  br i1 %24, label %label_33, label %label_35

label_30:                                         ; preds = %label_29
  ret ptr @.str.s10

label_35:                                         ; preds = %label_32
  %25 = load i32, ptr %t.382, align 4
  %26 = icmp eq i32 %25, 20
  br i1 %26, label %label_36, label %label_38

label_33:                                         ; preds = %label_32
  ret ptr @.str.s11

label_38:                                         ; preds = %label_35
  ret ptr @.str.s13

label_36:                                         ; preds = %label_35
  ret ptr @.str.s12
}

define i1 @is_digit__Char(i8 %0) {
entry:
  %c.383 = alloca i8, align 1
  store i8 %0, ptr %c.383, align 1
  %sc.0 = alloca i1, align 1
  %1 = load i8, ptr %c.383, align 1
  %2 = icmp sge i8 %1, 48
  store i1 %2, ptr %sc.0, align 1
  br i1 %2, label %label_39, label %label_40

label_40:                                         ; preds = %label_39, %entry
  %3 = load i1, ptr %sc.0, align 1
  ret i1 %3

label_39:                                         ; preds = %entry
  %4 = load i8, ptr %c.383, align 1
  %5 = icmp sle i8 %4, 57
  store i1 %5, ptr %sc.0, align 1
  br label %label_40
}

define i1 @is_alpha__Char(i8 %0) {
entry:
  %c.384 = alloca i8, align 1
  store i8 %0, ptr %c.384, align 1
  %sc.1 = alloca i1, align 1
  %sc.2 = alloca i1, align 1
  %sc.3 = alloca i1, align 1
  %1 = load i8, ptr %c.384, align 1
  %2 = icmp sge i8 %1, 97
  store i1 %2, ptr %sc.3, align 1
  %sc.4 = alloca i1, align 1
  br i1 %2, label %label_45, label %label_46

label_46:                                         ; preds = %label_45, %entry
  %3 = load i1, ptr %sc.3, align 1
  store i1 %3, ptr %sc.2, align 1
  br i1 %3, label %label_44, label %label_43

label_45:                                         ; preds = %entry
  %4 = load i8, ptr %c.384, align 1
  %5 = icmp sle i8 %4, 122
  store i1 %5, ptr %sc.3, align 1
  br label %label_46

label_43:                                         ; preds = %label_46
  %6 = load i8, ptr %c.384, align 1
  %7 = icmp sge i8 %6, 65
  store i1 %7, ptr %sc.4, align 1
  br i1 %7, label %label_47, label %label_48

label_44:                                         ; preds = %label_48, %label_46
  %8 = load i1, ptr %sc.2, align 1
  store i1 %8, ptr %sc.1, align 1
  br i1 %8, label %label_42, label %label_41

label_48:                                         ; preds = %label_47, %label_43
  %9 = load i1, ptr %sc.4, align 1
  store i1 %9, ptr %sc.2, align 1
  br label %label_44

label_47:                                         ; preds = %label_43
  %10 = load i8, ptr %c.384, align 1
  %11 = icmp sle i8 %10, 90
  store i1 %11, ptr %sc.4, align 1
  br label %label_48

label_41:                                         ; preds = %label_44
  %12 = load i8, ptr %c.384, align 1
  %13 = icmp eq i8 %12, 95
  store i1 %13, ptr %sc.1, align 1
  br label %label_42

label_42:                                         ; preds = %label_41, %label_44
  %14 = load i1, ptr %sc.1, align 1
  ret i1 %14
}

define i1 @is_alnum__Char(i8 %0) {
entry:
  %c.385 = alloca i8, align 1
  store i8 %0, ptr %c.385, align 1
  %sc.5 = alloca i1, align 1
  %1 = load i8, ptr %c.385, align 1
  %2 = call i1 @is_alpha__Char(i8 %1)
  store i1 %2, ptr %sc.5, align 1
  br i1 %2, label %label_50, label %label_49

label_49:                                         ; preds = %entry
  %3 = load i8, ptr %c.385, align 1
  %4 = call i1 @is_digit__Char(i8 %3)
  store i1 %4, ptr %sc.5, align 1
  br label %label_50

label_50:                                         ; preds = %label_49, %entry
  %5 = load i1, ptr %sc.5, align 1
  ret i1 %5
}

define i1 @is_space__Char(i8 %0) {
entry:
  %c.386 = alloca i8, align 1
  store i8 %0, ptr %c.386, align 1
  %sc.6 = alloca i1, align 1
  %sc.7 = alloca i1, align 1
  %sc.8 = alloca i1, align 1
  %1 = load i8, ptr %c.386, align 1
  %2 = icmp eq i8 %1, 32
  store i1 %2, ptr %sc.8, align 1
  br i1 %2, label %label_56, label %label_55

label_55:                                         ; preds = %entry
  %3 = load i8, ptr %c.386, align 1
  %4 = icmp eq i8 %3, 9
  store i1 %4, ptr %sc.8, align 1
  br label %label_56

label_56:                                         ; preds = %label_55, %entry
  %5 = load i1, ptr %sc.8, align 1
  store i1 %5, ptr %sc.7, align 1
  br i1 %5, label %label_54, label %label_53

label_53:                                         ; preds = %label_56
  %6 = load i8, ptr %c.386, align 1
  %7 = icmp eq i8 %6, 10
  store i1 %7, ptr %sc.7, align 1
  br label %label_54

label_54:                                         ; preds = %label_53, %label_56
  %8 = load i1, ptr %sc.7, align 1
  store i1 %8, ptr %sc.6, align 1
  br i1 %8, label %label_52, label %label_51

label_51:                                         ; preds = %label_54
  %9 = load i8, ptr %c.386, align 1
  %10 = icmp eq i8 %9, 13
  store i1 %10, ptr %sc.6, align 1
  br label %label_52

label_52:                                         ; preds = %label_51, %label_54
  %11 = load i1, ptr %sc.6, align 1
  ret i1 %11
}

define i1 @is_separator__Char(i8 %0) {
entry:
  %c.387 = alloca i8, align 1
  store i8 %0, ptr %c.387, align 1
  %1 = load i8, ptr %c.387, align 1
  %2 = icmp eq i8 %1, 40
  br i1 %2, label %label_57, label %label_59

label_59:                                         ; preds = %entry
  %3 = load i8, ptr %c.387, align 1
  %4 = icmp eq i8 %3, 41
  br i1 %4, label %label_60, label %label_62

label_57:                                         ; preds = %entry
  ret i1 true

label_62:                                         ; preds = %label_59
  %5 = load i8, ptr %c.387, align 1
  %6 = icmp eq i8 %5, 123
  br i1 %6, label %label_63, label %label_65

label_60:                                         ; preds = %label_59
  ret i1 true

label_65:                                         ; preds = %label_62
  %7 = load i8, ptr %c.387, align 1
  %8 = icmp eq i8 %7, 125
  br i1 %8, label %label_66, label %label_68

label_63:                                         ; preds = %label_62
  ret i1 true

label_68:                                         ; preds = %label_65
  %9 = load i8, ptr %c.387, align 1
  %10 = icmp eq i8 %9, 91
  br i1 %10, label %label_69, label %label_71

label_66:                                         ; preds = %label_65
  ret i1 true

label_71:                                         ; preds = %label_68
  %11 = load i8, ptr %c.387, align 1
  %12 = icmp eq i8 %11, 93
  br i1 %12, label %label_72, label %label_74

label_69:                                         ; preds = %label_68
  ret i1 true

label_74:                                         ; preds = %label_71
  %13 = load i8, ptr %c.387, align 1
  %14 = icmp eq i8 %13, 44
  br i1 %14, label %label_75, label %label_77

label_72:                                         ; preds = %label_71
  ret i1 true

label_77:                                         ; preds = %label_74
  %15 = load i8, ptr %c.387, align 1
  %16 = icmp eq i8 %15, 46
  br i1 %16, label %label_78, label %label_80

label_75:                                         ; preds = %label_74
  ret i1 true

label_80:                                         ; preds = %label_77
  %17 = load i8, ptr %c.387, align 1
  %18 = icmp eq i8 %17, 58
  br i1 %18, label %label_81, label %label_83

label_78:                                         ; preds = %label_77
  ret i1 true

label_83:                                         ; preds = %label_80
  ret i1 false

label_81:                                         ; preds = %label_80
  ret i1 true
}

define i1 @is_operator__Char(i8 %0) {
entry:
  %c.388 = alloca i8, align 1
  store i8 %0, ptr %c.388, align 1
  %1 = load i8, ptr %c.388, align 1
  %2 = icmp eq i8 %1, 43
  br i1 %2, label %label_84, label %label_86

label_86:                                         ; preds = %entry
  %3 = load i8, ptr %c.388, align 1
  %4 = icmp eq i8 %3, 45
  br i1 %4, label %label_87, label %label_89

label_84:                                         ; preds = %entry
  ret i1 true

label_89:                                         ; preds = %label_86
  %5 = load i8, ptr %c.388, align 1
  %6 = icmp eq i8 %5, 42
  br i1 %6, label %label_90, label %label_92

label_87:                                         ; preds = %label_86
  ret i1 true

label_92:                                         ; preds = %label_89
  %7 = load i8, ptr %c.388, align 1
  %8 = icmp eq i8 %7, 47
  br i1 %8, label %label_93, label %label_95

label_90:                                         ; preds = %label_89
  ret i1 true

label_95:                                         ; preds = %label_92
  %9 = load i8, ptr %c.388, align 1
  %10 = icmp eq i8 %9, 37
  br i1 %10, label %label_96, label %label_98

label_93:                                         ; preds = %label_92
  ret i1 true

label_98:                                         ; preds = %label_95
  %11 = load i8, ptr %c.388, align 1
  %12 = icmp eq i8 %11, 60
  br i1 %12, label %label_99, label %label_101

label_96:                                         ; preds = %label_95
  ret i1 true

label_101:                                        ; preds = %label_98
  %13 = load i8, ptr %c.388, align 1
  %14 = icmp eq i8 %13, 62
  br i1 %14, label %label_102, label %label_104

label_99:                                         ; preds = %label_98
  ret i1 true

label_104:                                        ; preds = %label_101
  %15 = load i8, ptr %c.388, align 1
  %16 = icmp eq i8 %15, 33
  br i1 %16, label %label_105, label %label_107

label_102:                                        ; preds = %label_101
  ret i1 true

label_107:                                        ; preds = %label_104
  %17 = load i8, ptr %c.388, align 1
  %18 = icmp eq i8 %17, 38
  br i1 %18, label %label_108, label %label_110

label_105:                                        ; preds = %label_104
  ret i1 true

label_110:                                        ; preds = %label_107
  %19 = load i8, ptr %c.388, align 1
  %20 = icmp eq i8 %19, 124
  br i1 %20, label %label_111, label %label_113

label_108:                                        ; preds = %label_107
  ret i1 true

label_113:                                        ; preds = %label_110
  %21 = load i8, ptr %c.388, align 1
  %22 = icmp eq i8 %21, 94
  br i1 %22, label %label_114, label %label_116

label_111:                                        ; preds = %label_110
  ret i1 true

label_116:                                        ; preds = %label_113
  %23 = load i8, ptr %c.388, align 1
  %24 = icmp eq i8 %23, 126
  br i1 %24, label %label_117, label %label_119

label_114:                                        ; preds = %label_113
  ret i1 true

label_119:                                        ; preds = %label_116
  %25 = load i8, ptr %c.388, align 1
  %26 = icmp eq i8 %25, 61
  br i1 %26, label %label_120, label %label_122

label_117:                                        ; preds = %label_116
  ret i1 true

label_122:                                        ; preds = %label_119
  ret i1 false

label_120:                                        ; preds = %label_119
  ret i1 true
}

define i32 @char_code__Char(i8 %0) {
entry:
  %c.389 = alloca i8, align 1
  store i8 %0, ptr %c.389, align 1
  %1 = load i8, ptr %c.389, align 1
  %2 = zext i8 %1 to i32
  ret i32 %2
}

define i1 @is_keyword__String(ptr %0) {
entry:
  %s.390 = alloca ptr, align 8
  store ptr %0, ptr %s.390, align 8
  %1 = load ptr, ptr %s.390, align 8
  %2 = call i32 @str_equals(ptr %1, ptr @.str.s14)
  %3 = icmp eq i32 %2, 1
  br i1 %3, label %label_123, label %label_125

label_125:                                        ; preds = %entry
  %4 = load ptr, ptr %s.390, align 8
  %5 = call i32 @str_equals(ptr %4, ptr @.str.s15)
  %6 = icmp eq i32 %5, 1
  br i1 %6, label %label_126, label %label_128

label_123:                                        ; preds = %entry
  ret i1 true

label_128:                                        ; preds = %label_125
  %7 = load ptr, ptr %s.390, align 8
  %8 = call i32 @str_equals(ptr %7, ptr @.str.s16)
  %9 = icmp eq i32 %8, 1
  br i1 %9, label %label_129, label %label_131

label_126:                                        ; preds = %label_125
  ret i1 true

label_131:                                        ; preds = %label_128
  %10 = load ptr, ptr %s.390, align 8
  %11 = call i32 @str_equals(ptr %10, ptr @.str.s17)
  %12 = icmp eq i32 %11, 1
  br i1 %12, label %label_132, label %label_134

label_129:                                        ; preds = %label_128
  ret i1 true

label_134:                                        ; preds = %label_131
  %13 = load ptr, ptr %s.390, align 8
  %14 = call i32 @str_equals(ptr %13, ptr @.str.s18)
  %15 = icmp eq i32 %14, 1
  br i1 %15, label %label_135, label %label_137

label_132:                                        ; preds = %label_131
  ret i1 true

label_137:                                        ; preds = %label_134
  %16 = load ptr, ptr %s.390, align 8
  %17 = call i32 @str_equals(ptr %16, ptr @.str.s19)
  %18 = icmp eq i32 %17, 1
  br i1 %18, label %label_138, label %label_140

label_135:                                        ; preds = %label_134
  ret i1 true

label_140:                                        ; preds = %label_137
  %19 = load ptr, ptr %s.390, align 8
  %20 = call i32 @str_equals(ptr %19, ptr @.str.s20)
  %21 = icmp eq i32 %20, 1
  br i1 %21, label %label_141, label %label_143

label_138:                                        ; preds = %label_137
  ret i1 true

label_143:                                        ; preds = %label_140
  %22 = load ptr, ptr %s.390, align 8
  %23 = call i32 @str_equals(ptr %22, ptr @.str.s21)
  %24 = icmp eq i32 %23, 1
  br i1 %24, label %label_144, label %label_146

label_141:                                        ; preds = %label_140
  ret i1 true

label_146:                                        ; preds = %label_143
  %25 = load ptr, ptr %s.390, align 8
  %26 = call i32 @str_equals(ptr %25, ptr @.str.s22)
  %27 = icmp eq i32 %26, 1
  br i1 %27, label %label_147, label %label_149

label_144:                                        ; preds = %label_143
  ret i1 true

label_149:                                        ; preds = %label_146
  %28 = load ptr, ptr %s.390, align 8
  %29 = call i32 @str_equals(ptr %28, ptr @.str.s23)
  %30 = icmp eq i32 %29, 1
  br i1 %30, label %label_150, label %label_152

label_147:                                        ; preds = %label_146
  ret i1 true

label_152:                                        ; preds = %label_149
  %31 = load ptr, ptr %s.390, align 8
  %32 = call i32 @str_equals(ptr %31, ptr @.str.s24)
  %33 = icmp eq i32 %32, 1
  br i1 %33, label %label_153, label %label_155

label_150:                                        ; preds = %label_149
  ret i1 true

label_155:                                        ; preds = %label_152
  %34 = load ptr, ptr %s.390, align 8
  %35 = call i32 @str_equals(ptr %34, ptr @.str.s25)
  %36 = icmp eq i32 %35, 1
  br i1 %36, label %label_156, label %label_158

label_153:                                        ; preds = %label_152
  ret i1 true

label_158:                                        ; preds = %label_155
  %37 = load ptr, ptr %s.390, align 8
  %38 = call i32 @str_equals(ptr %37, ptr @.str.s26)
  %39 = icmp eq i32 %38, 1
  br i1 %39, label %label_159, label %label_161

label_156:                                        ; preds = %label_155
  ret i1 true

label_161:                                        ; preds = %label_158
  %40 = load ptr, ptr %s.390, align 8
  %41 = call i32 @str_equals(ptr %40, ptr @.str.s27)
  %42 = icmp eq i32 %41, 1
  br i1 %42, label %label_162, label %label_164

label_159:                                        ; preds = %label_158
  ret i1 true

label_164:                                        ; preds = %label_161
  %43 = load ptr, ptr %s.390, align 8
  %44 = call i32 @str_equals(ptr %43, ptr @.str.s28)
  %45 = icmp eq i32 %44, 1
  br i1 %45, label %label_165, label %label_167

label_162:                                        ; preds = %label_161
  ret i1 true

label_167:                                        ; preds = %label_164
  %46 = load ptr, ptr %s.390, align 8
  %47 = call i32 @str_equals(ptr %46, ptr @.str.s29)
  %48 = icmp eq i32 %47, 1
  br i1 %48, label %label_168, label %label_170

label_165:                                        ; preds = %label_164
  ret i1 true

label_170:                                        ; preds = %label_167
  %49 = load ptr, ptr %s.390, align 8
  %50 = call i32 @str_equals(ptr %49, ptr @.str.s30)
  %51 = icmp eq i32 %50, 1
  br i1 %51, label %label_171, label %label_173

label_168:                                        ; preds = %label_167
  ret i1 true

label_173:                                        ; preds = %label_170
  %52 = load ptr, ptr %s.390, align 8
  %53 = call i32 @str_equals(ptr %52, ptr @.str.s31)
  %54 = icmp eq i32 %53, 1
  br i1 %54, label %label_174, label %label_176

label_171:                                        ; preds = %label_170
  ret i1 true

label_176:                                        ; preds = %label_173
  %55 = load ptr, ptr %s.390, align 8
  %56 = call i32 @str_equals(ptr %55, ptr @.str.s32)
  %57 = icmp eq i32 %56, 1
  br i1 %57, label %label_177, label %label_179

label_174:                                        ; preds = %label_173
  ret i1 true

label_179:                                        ; preds = %label_176
  %58 = load ptr, ptr %s.390, align 8
  %59 = call i32 @str_equals(ptr %58, ptr @.str.s33)
  %60 = icmp eq i32 %59, 1
  br i1 %60, label %label_180, label %label_182

label_177:                                        ; preds = %label_176
  ret i1 true

label_182:                                        ; preds = %label_179
  %61 = load ptr, ptr %s.390, align 8
  %62 = call i32 @str_equals(ptr %61, ptr @.str.s34)
  %63 = icmp eq i32 %62, 1
  br i1 %63, label %label_183, label %label_185

label_180:                                        ; preds = %label_179
  ret i1 true

label_185:                                        ; preds = %label_182
  %64 = load ptr, ptr %s.390, align 8
  %65 = call i32 @str_equals(ptr %64, ptr @.str.s35)
  %66 = icmp eq i32 %65, 1
  br i1 %66, label %label_186, label %label_188

label_183:                                        ; preds = %label_182
  ret i1 true

label_188:                                        ; preds = %label_185
  %67 = load ptr, ptr %s.390, align 8
  %68 = call i32 @str_equals(ptr %67, ptr @.str.s36)
  %69 = icmp eq i32 %68, 1
  br i1 %69, label %label_189, label %label_191

label_186:                                        ; preds = %label_185
  ret i1 true

label_191:                                        ; preds = %label_188
  %70 = load ptr, ptr %s.390, align 8
  %71 = call i32 @str_equals(ptr %70, ptr @.str.s37)
  %72 = icmp eq i32 %71, 1
  br i1 %72, label %label_192, label %label_194

label_189:                                        ; preds = %label_188
  ret i1 true

label_194:                                        ; preds = %label_191
  %73 = load ptr, ptr %s.390, align 8
  %74 = call i32 @str_equals(ptr %73, ptr @.str.s38)
  %75 = icmp eq i32 %74, 1
  br i1 %75, label %label_195, label %label_197

label_192:                                        ; preds = %label_191
  ret i1 true

label_197:                                        ; preds = %label_194
  %76 = load ptr, ptr %s.390, align 8
  %77 = call i32 @str_equals(ptr %76, ptr @.str.s39)
  %78 = icmp eq i32 %77, 1
  br i1 %78, label %label_198, label %label_200

label_195:                                        ; preds = %label_194
  ret i1 true

label_200:                                        ; preds = %label_197
  %79 = load ptr, ptr %s.390, align 8
  %80 = call i32 @str_equals(ptr %79, ptr @.str.s40)
  %81 = icmp eq i32 %80, 1
  br i1 %81, label %label_201, label %label_203

label_198:                                        ; preds = %label_197
  ret i1 true

label_203:                                        ; preds = %label_200
  ret i1 false

label_201:                                        ; preds = %label_200
  ret i1 true
}

define i1 @is_boolean__String(ptr %0) {
entry:
  %s.391 = alloca ptr, align 8
  store ptr %0, ptr %s.391, align 8
  %1 = load ptr, ptr %s.391, align 8
  %2 = call i32 @str_equals(ptr %1, ptr @.str.s41)
  %3 = icmp eq i32 %2, 1
  br i1 %3, label %label_204, label %label_206

label_206:                                        ; preds = %entry
  %4 = load ptr, ptr %s.391, align 8
  %5 = call i32 @str_equals(ptr %4, ptr @.str.s42)
  %6 = icmp eq i32 %5, 1
  br i1 %6, label %label_207, label %label_209

label_204:                                        ; preds = %entry
  ret i1 true

label_209:                                        ; preds = %label_206
  ret i1 false

label_207:                                        ; preds = %label_206
  ret i1 true
}

define ptr @diag_quote__String(ptr %0) {
entry:
  %name.392 = alloca ptr, align 8
  store ptr %0, ptr %name.392, align 8
  %1 = load ptr, ptr %name.392, align 8
  %2 = call ptr @str_concat(ptr @.str.s43, ptr %1)
  %3 = call ptr @str_concat(ptr %2, ptr @.str.s44)
  ret ptr %3
}

define ptr @create_lexer__String_Int(ptr %0, i32 %1) {
entry:
  %input.393 = alloca ptr, align 8
  store ptr %0, ptr %input.393, align 8
  %file.394 = alloca i32, align 4
  store i32 %1, ptr %file.394, align 4
  %start.395 = alloca i32, align 4
  store i32 0, ptr %start.395, align 4
  %2 = load ptr, ptr %input.393, align 8
  %3 = call i8 @str_char_at(ptr %2, i32 0)
  %4 = call i32 @char_code__Char(i8 %3)
  %5 = icmp eq i32 %4, 239
  %sc.9 = alloca i1, align 1
  br i1 %5, label %label_210, label %label_212

label_212:                                        ; preds = %label_217, %entry
  %6 = call ptr @malloc(i64 ptrtoint (ptr getelementptr (%Lexer, ptr null, i32 1) to i64))
  %7 = load ptr, ptr %input.393, align 8
  %8 = getelementptr inbounds nuw %Lexer, ptr %6, i32 0, i32 0
  store ptr %7, ptr %8, align 8
  %9 = load i32, ptr %start.395, align 4
  %10 = getelementptr inbounds nuw %Lexer, ptr %6, i32 0, i32 1
  store i32 %9, ptr %10, align 4
  %11 = getelementptr inbounds nuw %Lexer, ptr %6, i32 0, i32 2
  store i32 1, ptr %11, align 4
  %12 = getelementptr inbounds nuw %Lexer, ptr %6, i32 0, i32 3
  store i32 1, ptr %12, align 4
  %13 = load i32, ptr %file.394, align 4
  %14 = getelementptr inbounds nuw %Lexer, ptr %6, i32 0, i32 4
  store i32 %13, ptr %14, align 4
  %15 = load ptr, ptr %input.393, align 8
  %16 = call i32 @str_length(ptr %15)
  %17 = getelementptr inbounds nuw %Lexer, ptr %6, i32 0, i32 5
  store i32 %16, ptr %17, align 4
  ret ptr %6

label_210:                                        ; preds = %entry
  %18 = load ptr, ptr %input.393, align 8
  %19 = call i8 @str_char_at(ptr %18, i32 1)
  %20 = call i32 @char_code__Char(i8 %19)
  %21 = icmp eq i32 %20, 187
  store i1 %21, ptr %sc.9, align 1
  br i1 %21, label %label_213, label %label_214

label_214:                                        ; preds = %label_213, %label_210
  %22 = load i1, ptr %sc.9, align 1
  br i1 %22, label %label_215, label %label_217

label_213:                                        ; preds = %label_210
  %23 = load ptr, ptr %input.393, align 8
  %24 = call i8 @str_char_at(ptr %23, i32 2)
  %25 = call i32 @char_code__Char(i8 %24)
  %26 = icmp eq i32 %25, 191
  store i1 %26, ptr %sc.9, align 1
  br label %label_214

label_217:                                        ; preds = %label_215, %label_214
  br label %label_212

label_215:                                        ; preds = %label_214
  store i32 3, ptr %start.395, align 4
  br label %label_217
}

define ptr @lexer_token__Struct_Lexer_Enum_TokenType_String_Int_Int_Int(ptr %0, i32 %1, ptr %2, i32 %3, i32 %4, i32 %5) {
entry:
  %lex.396 = alloca ptr, align 8
  store ptr %0, ptr %lex.396, align 8
  %t.397 = alloca i32, align 4
  store i32 %1, ptr %t.397, align 4
  %value.398 = alloca ptr, align 8
  store ptr %2, ptr %value.398, align 8
  %start_line.399 = alloca i32, align 4
  store i32 %3, ptr %start_line.399, align 4
  %start_col.400 = alloca i32, align 4
  store i32 %4, ptr %start_col.400, align 4
  %start_pos.401 = alloca i32, align 4
  store i32 %5, ptr %start_pos.401, align 4
  %6 = call ptr @malloc(i64 ptrtoint (ptr getelementptr (%Token, ptr null, i32 1) to i64))
  %7 = load i32, ptr %t.397, align 4
  %8 = getelementptr inbounds nuw %Token, ptr %6, i32 0, i32 0
  store i32 %7, ptr %8, align 4
  %9 = load ptr, ptr %value.398, align 8
  %10 = getelementptr inbounds nuw %Token, ptr %6, i32 0, i32 1
  store ptr %9, ptr %10, align 8
  %11 = load i32, ptr %start_line.399, align 4
  %12 = getelementptr inbounds nuw %Token, ptr %6, i32 0, i32 2
  store i32 %11, ptr %12, align 4
  %13 = load i32, ptr %start_col.400, align 4
  %14 = getelementptr inbounds nuw %Token, ptr %6, i32 0, i32 3
  store i32 %13, ptr %14, align 4
  %15 = load ptr, ptr %lex.396, align 8
  %16 = getelementptr inbounds nuw %Lexer, ptr %15, i32 0, i32 1
  %17 = load i32, ptr %16, align 4
  %18 = load i32, ptr %start_pos.401, align 4
  %19 = sub i32 %17, %18
  %20 = getelementptr inbounds nuw %Token, ptr %6, i32 0, i32 4
  store i32 %19, ptr %20, align 4
  %21 = load ptr, ptr %lex.396, align 8
  %22 = getelementptr inbounds nuw %Lexer, ptr %21, i32 0, i32 4
  %23 = load i32, ptr %22, align 4
  %24 = getelementptr inbounds nuw %Token, ptr %6, i32 0, i32 5
  store i32 %23, ptr %24, align 4
  %25 = getelementptr inbounds nuw %Token, ptr %6, i32 0, i32 6
  store ptr @.str.s45, ptr %25, align 8
  ret ptr %6
}

define void @lexer_fatal__Struct_Lexer_Int_Int_String(ptr %0, i32 %1, i32 %2, ptr %3) {
entry:
  %lex.402 = alloca ptr, align 8
  store ptr %0, ptr %lex.402, align 8
  %line.403 = alloca i32, align 4
  store i32 %1, ptr %line.403, align 4
  %col.404 = alloca i32, align 4
  store i32 %2, ptr %col.404, align 4
  %message.405 = alloca ptr, align 8
  store ptr %3, ptr %message.405, align 8
  %4 = load ptr, ptr %lex.402, align 8
  %5 = getelementptr inbounds nuw %Lexer, ptr %4, i32 0, i32 4
  %6 = load i32, ptr %5, align 4
  %7 = load i32, ptr %line.403, align 4
  %8 = load i32, ptr %col.404, align 4
  %9 = load ptr, ptr %message.405, align 8
  call void @diag_error_at(i32 %6, i32 %7, i32 %8, i32 1, ptr %9)
  call void @diag_finish()
  call void @exit(i32 1)
  ret void
}

define i8 @lexer_peek__Struct_Lexer_Int(ptr %0, i32 %1) {
entry:
  %lex.406 = alloca ptr, align 8
  store ptr %0, ptr %lex.406, align 8
  %offset.407 = alloca i32, align 4
  store i32 %1, ptr %offset.407, align 4
  %2 = load ptr, ptr %lex.406, align 8
  %3 = getelementptr inbounds nuw %Lexer, ptr %2, i32 0, i32 1
  %4 = load i32, ptr %3, align 4
  %5 = load i32, ptr %offset.407, align 4
  %6 = add i32 %4, %5
  %at.408 = alloca i32, align 4
  store i32 %6, ptr %at.408, align 4
  %sc.10 = alloca i1, align 1
  %7 = load i32, ptr %at.408, align 4
  %8 = icmp slt i32 %7, 0
  store i1 %8, ptr %sc.10, align 1
  br i1 %8, label %label_219, label %label_218

label_218:                                        ; preds = %entry
  %9 = load i32, ptr %at.408, align 4
  %10 = load ptr, ptr %lex.406, align 8
  %11 = getelementptr inbounds nuw %Lexer, ptr %10, i32 0, i32 5
  %12 = load i32, ptr %11, align 4
  %13 = icmp sgt i32 %9, %12
  store i1 %13, ptr %sc.10, align 1
  br label %label_219

label_219:                                        ; preds = %label_218, %entry
  %14 = load i1, ptr %sc.10, align 1
  br i1 %14, label %label_220, label %label_222

label_222:                                        ; preds = %label_219
  %15 = load ptr, ptr %lex.406, align 8
  %16 = getelementptr inbounds nuw %Lexer, ptr %15, i32 0, i32 0
  %17 = load ptr, ptr %16, align 8
  %18 = load i32, ptr %at.408, align 4
  %19 = call i8 @str_byte_at(ptr %17, i32 %18)
  ret i8 %19

label_220:                                        ; preds = %label_219
  ret i8 0
}

define i8 @lexer_current__Struct_Lexer(ptr %0) {
entry:
  %lex.409 = alloca ptr, align 8
  store ptr %0, ptr %lex.409, align 8
  %sc.11 = alloca i1, align 1
  %1 = load ptr, ptr %lex.409, align 8
  %2 = getelementptr inbounds nuw %Lexer, ptr %1, i32 0, i32 1
  %3 = load i32, ptr %2, align 4
  %4 = icmp slt i32 %3, 0
  store i1 %4, ptr %sc.11, align 1
  br i1 %4, label %label_224, label %label_223

label_223:                                        ; preds = %entry
  %5 = load ptr, ptr %lex.409, align 8
  %6 = getelementptr inbounds nuw %Lexer, ptr %5, i32 0, i32 1
  %7 = load i32, ptr %6, align 4
  %8 = load ptr, ptr %lex.409, align 8
  %9 = getelementptr inbounds nuw %Lexer, ptr %8, i32 0, i32 5
  %10 = load i32, ptr %9, align 4
  %11 = icmp sgt i32 %7, %10
  store i1 %11, ptr %sc.11, align 1
  br label %label_224

label_224:                                        ; preds = %label_223, %entry
  %12 = load i1, ptr %sc.11, align 1
  br i1 %12, label %label_225, label %label_227

label_227:                                        ; preds = %label_224
  %13 = load ptr, ptr %lex.409, align 8
  %14 = getelementptr inbounds nuw %Lexer, ptr %13, i32 0, i32 0
  %15 = load ptr, ptr %14, align 8
  %16 = load ptr, ptr %lex.409, align 8
  %17 = getelementptr inbounds nuw %Lexer, ptr %16, i32 0, i32 1
  %18 = load i32, ptr %17, align 4
  %19 = call i8 @str_byte_at(ptr %15, i32 %18)
  ret i8 %19

label_225:                                        ; preds = %label_224
  ret i8 0
}

define void @lexer_advance__Struct_Lexer(ptr %0) {
entry:
  %lex.410 = alloca ptr, align 8
  store ptr %0, ptr %lex.410, align 8
  %1 = load ptr, ptr %lex.410, align 8
  %2 = load ptr, ptr %lex.410, align 8
  %3 = getelementptr inbounds nuw %Lexer, ptr %2, i32 0, i32 1
  %4 = load i32, ptr %3, align 4
  %5 = add i32 %4, 1
  %6 = getelementptr inbounds nuw %Lexer, ptr %1, i32 0, i32 1
  store i32 %5, ptr %6, align 4
  %7 = load ptr, ptr %lex.410, align 8
  %8 = load ptr, ptr %lex.410, align 8
  %9 = getelementptr inbounds nuw %Lexer, ptr %8, i32 0, i32 3
  %10 = load i32, ptr %9, align 4
  %11 = add i32 %10, 1
  %12 = getelementptr inbounds nuw %Lexer, ptr %7, i32 0, i32 3
  store i32 %11, ptr %12, align 4
  ret void
}

define void @lexer_skip_whitespace__Struct_Lexer(ptr %0) {
entry:
  %lex.411 = alloca ptr, align 8
  store ptr %0, ptr %lex.411, align 8
  %is_looping.412 = alloca i1, align 1
  store i1 true, ptr %is_looping.412, align 1
  %sc.12 = alloca i1, align 1
  %sc.13 = alloca i1, align 1
  br label %label_228

label_228:                                        ; preds = %label_233, %entry
  %1 = load i1, ptr %is_looping.412, align 1
  br i1 %1, label %label_229, label %label_230

label_230:                                        ; preds = %label_228
  ret void

label_229:                                        ; preds = %label_228
  %2 = load ptr, ptr %lex.411, align 8
  %3 = call i8 @lexer_current__Struct_Lexer(ptr %2)
  %4 = call i1 @is_space__Char(i8 %3)
  br i1 %4, label %label_231, label %label_232

label_232:                                        ; preds = %label_229
  %5 = load ptr, ptr %lex.411, align 8
  %6 = call i8 @lexer_current__Struct_Lexer(ptr %5)
  %7 = icmp eq i8 %6, 47
  store i1 %7, ptr %sc.12, align 1
  br i1 %7, label %label_237, label %label_238

label_231:                                        ; preds = %label_229
  %8 = load ptr, ptr %lex.411, align 8
  %9 = call i8 @lexer_current__Struct_Lexer(ptr %8)
  %10 = icmp eq i8 %9, 10
  br i1 %10, label %label_234, label %label_236

label_236:                                        ; preds = %label_234, %label_231
  %11 = load ptr, ptr %lex.411, align 8
  call void @lexer_advance__Struct_Lexer(ptr %11)
  br label %label_233

label_234:                                        ; preds = %label_231
  %12 = load ptr, ptr %lex.411, align 8
  %13 = load ptr, ptr %lex.411, align 8
  %14 = getelementptr inbounds nuw %Lexer, ptr %13, i32 0, i32 2
  %15 = load i32, ptr %14, align 4
  %16 = add i32 %15, 1
  %17 = getelementptr inbounds nuw %Lexer, ptr %12, i32 0, i32 2
  store i32 %16, ptr %17, align 4
  %18 = load ptr, ptr %lex.411, align 8
  %19 = getelementptr inbounds nuw %Lexer, ptr %18, i32 0, i32 3
  store i32 0, ptr %19, align 4
  br label %label_236

label_233:                                        ; preds = %label_241, %label_236
  br label %label_228

label_238:                                        ; preds = %label_237, %label_232
  %20 = load i1, ptr %sc.12, align 1
  br i1 %20, label %label_239, label %label_240

label_237:                                        ; preds = %label_232
  %21 = load ptr, ptr %lex.411, align 8
  %22 = call i8 @lexer_peek__Struct_Lexer_Int(ptr %21, i32 1)
  %23 = icmp eq i8 %22, 47
  store i1 %23, ptr %sc.12, align 1
  br label %label_238

label_240:                                        ; preds = %label_238
  store i1 false, ptr %is_looping.412, align 1
  br label %label_241

label_239:                                        ; preds = %label_238
  br label %label_242

label_242:                                        ; preds = %label_243, %label_239
  %24 = load ptr, ptr %lex.411, align 8
  %25 = call i8 @lexer_current__Struct_Lexer(ptr %24)
  %26 = icmp ne i8 %25, 10
  store i1 %26, ptr %sc.13, align 1
  br i1 %26, label %label_245, label %label_246

label_246:                                        ; preds = %label_245, %label_242
  %27 = load i1, ptr %sc.13, align 1
  br i1 %27, label %label_243, label %label_244

label_245:                                        ; preds = %label_242
  %28 = load ptr, ptr %lex.411, align 8
  %29 = call i8 @lexer_current__Struct_Lexer(ptr %28)
  %30 = icmp ne i8 %29, 0
  store i1 %30, ptr %sc.13, align 1
  br label %label_246

label_244:                                        ; preds = %label_246
  br label %label_241

label_243:                                        ; preds = %label_246
  %31 = load ptr, ptr %lex.411, align 8
  call void @lexer_advance__Struct_Lexer(ptr %31)
  br label %label_242

label_241:                                        ; preds = %label_240, %label_244
  br label %label_233
}

define ptr @lexer_decode_escapes__Struct_Lexer_String_Int_Int(ptr %0, ptr %1, i32 %2, i32 %3) {
entry:
  %lex.413 = alloca ptr, align 8
  store ptr %0, ptr %lex.413, align 8
  %raw.414 = alloca ptr, align 8
  store ptr %1, ptr %raw.414, align 8
  %line.415 = alloca i32, align 4
  store i32 %2, ptr %line.415, align 4
  %base_col.416 = alloca i32, align 4
  store i32 %3, ptr %base_col.416, align 4
  %out.417 = alloca ptr, align 8
  store ptr @.str.s46, ptr %out.417, align 8
  %i.418 = alloca i32, align 4
  store i32 0, ptr %i.418, align 4
  %4 = load ptr, ptr %raw.414, align 8
  %5 = call i32 @str_length(ptr %4)
  %n.419 = alloca i32, align 4
  store i32 %5, ptr %n.419, align 4
  %ch.420 = alloca i8, align 1
  %sc.14 = alloca i1, align 1
  %esc.421 = alloca i8, align 1
  %decoded.422 = alloca i8, align 1
  %known.423 = alloca i1, align 1
  br label %label_247

label_247:                                        ; preds = %label_254, %entry
  %6 = load i32, ptr %i.418, align 4
  %7 = load i32, ptr %n.419, align 4
  %8 = icmp slt i32 %6, %7
  br i1 %8, label %label_248, label %label_249

label_249:                                        ; preds = %label_247
  %9 = load ptr, ptr %out.417, align 8
  ret ptr %9

label_248:                                        ; preds = %label_247
  %10 = load ptr, ptr %raw.414, align 8
  %11 = load i32, ptr %i.418, align 4
  %12 = call i8 @str_char_at(ptr %10, i32 %11)
  store i8 %12, ptr %ch.420, align 1
  %13 = load i8, ptr %ch.420, align 1
  %14 = icmp eq i8 %13, 92
  store i1 %14, ptr %sc.14, align 1
  br i1 %14, label %label_250, label %label_251

label_251:                                        ; preds = %label_250, %label_248
  %15 = load i1, ptr %sc.14, align 1
  br i1 %15, label %label_252, label %label_253

label_250:                                        ; preds = %label_248
  %16 = load i32, ptr %i.418, align 4
  %17 = add i32 %16, 1
  %18 = load i32, ptr %n.419, align 4
  %19 = icmp slt i32 %17, %18
  store i1 %19, ptr %sc.14, align 1
  br label %label_251

label_253:                                        ; preds = %label_251
  %20 = load ptr, ptr %out.417, align 8
  %21 = load i8, ptr %ch.420, align 1
  %22 = call ptr @str_from_char(i8 %21)
  %23 = call ptr @str_concat(ptr %20, ptr %22)
  store ptr %23, ptr %out.417, align 8
  %24 = load i32, ptr %i.418, align 4
  %25 = add i32 %24, 1
  store i32 %25, ptr %i.418, align 4
  br label %label_254

label_252:                                        ; preds = %label_251
  %26 = load ptr, ptr %raw.414, align 8
  %27 = load i32, ptr %i.418, align 4
  %28 = add i32 %27, 1
  %29 = call i8 @str_char_at(ptr %26, i32 %28)
  store i8 %29, ptr %esc.421, align 1
  %30 = load i8, ptr %esc.421, align 1
  store i8 %30, ptr %decoded.422, align 1
  store i1 true, ptr %known.423, align 1
  %31 = load i8, ptr %esc.421, align 1
  %32 = icmp eq i8 %31, 110
  br i1 %32, label %label_255, label %label_256

label_256:                                        ; preds = %label_252
  %33 = load i8, ptr %esc.421, align 1
  %34 = icmp eq i8 %33, 116
  br i1 %34, label %label_258, label %label_259

label_255:                                        ; preds = %label_252
  store i8 10, ptr %decoded.422, align 1
  br label %label_257

label_257:                                        ; preds = %label_260, %label_255
  %35 = load i1, ptr %known.423, align 1
  %36 = icmp eq i1 %35, false
  br i1 %36, label %label_276, label %label_278

label_259:                                        ; preds = %label_256
  %37 = load i8, ptr %esc.421, align 1
  %38 = icmp eq i8 %37, 114
  br i1 %38, label %label_261, label %label_262

label_258:                                        ; preds = %label_256
  store i8 9, ptr %decoded.422, align 1
  br label %label_260

label_260:                                        ; preds = %label_263, %label_258
  br label %label_257

label_262:                                        ; preds = %label_259
  %39 = load i8, ptr %esc.421, align 1
  %40 = icmp eq i8 %39, 92
  br i1 %40, label %label_264, label %label_265

label_261:                                        ; preds = %label_259
  store i8 13, ptr %decoded.422, align 1
  br label %label_263

label_263:                                        ; preds = %label_266, %label_261
  br label %label_260

label_265:                                        ; preds = %label_262
  %41 = load i8, ptr %esc.421, align 1
  %42 = icmp eq i8 %41, 34
  br i1 %42, label %label_267, label %label_268

label_264:                                        ; preds = %label_262
  store i8 92, ptr %decoded.422, align 1
  br label %label_266

label_266:                                        ; preds = %label_269, %label_264
  br label %label_263

label_268:                                        ; preds = %label_265
  %43 = load i8, ptr %esc.421, align 1
  %44 = icmp eq i8 %43, 39
  br i1 %44, label %label_270, label %label_271

label_267:                                        ; preds = %label_265
  store i8 34, ptr %decoded.422, align 1
  br label %label_269

label_269:                                        ; preds = %label_272, %label_267
  br label %label_266

label_271:                                        ; preds = %label_268
  %45 = load i8, ptr %esc.421, align 1
  %46 = icmp eq i8 %45, 48
  br i1 %46, label %label_273, label %label_274

label_270:                                        ; preds = %label_268
  store i8 39, ptr %decoded.422, align 1
  br label %label_272

label_272:                                        ; preds = %label_275, %label_270
  br label %label_269

label_274:                                        ; preds = %label_271
  store i1 false, ptr %known.423, align 1
  br label %label_275

label_273:                                        ; preds = %label_271
  %47 = load ptr, ptr %lex.413, align 8
  %48 = load i32, ptr %line.415, align 4
  %49 = load i32, ptr %base_col.416, align 4
  %50 = load i32, ptr %i.418, align 4
  %51 = add i32 %49, %50
  call void @lexer_fatal__Struct_Lexer_Int_Int_String(ptr %47, i32 %48, i32 %51, ptr @.str.s47)
  br label %label_275

label_275:                                        ; preds = %label_274, %label_273
  br label %label_272

label_278:                                        ; preds = %label_276, %label_257
  %52 = load ptr, ptr %out.417, align 8
  %53 = load i8, ptr %decoded.422, align 1
  %54 = call ptr @str_from_char(i8 %53)
  %55 = call ptr @str_concat(ptr %52, ptr %54)
  store ptr %55, ptr %out.417, align 8
  %56 = load i32, ptr %i.418, align 4
  %57 = add i32 %56, 2
  store i32 %57, ptr %i.418, align 4
  br label %label_254

label_276:                                        ; preds = %label_257
  %58 = load ptr, ptr %lex.413, align 8
  %59 = load i32, ptr %line.415, align 4
  %60 = load i32, ptr %base_col.416, align 4
  %61 = load i32, ptr %i.418, align 4
  %62 = add i32 %60, %61
  %63 = load i8, ptr %esc.421, align 1
  %64 = call ptr @str_from_char(i8 %63)
  %65 = call ptr @str_concat(ptr @.str.s48, ptr %64)
  call void @lexer_fatal__Struct_Lexer_Int_Int_String(ptr %58, i32 %59, i32 %62, ptr %65)
  br label %label_278

label_254:                                        ; preds = %label_253, %label_278
  br label %label_247
}

define ptr @lexer_next_token__Struct_Lexer(ptr %0) {
entry:
  %lex.424 = alloca ptr, align 8
  store ptr %0, ptr %lex.424, align 8
  %1 = load ptr, ptr %lex.424, align 8
  call void @lexer_skip_whitespace__Struct_Lexer(ptr %1)
  %2 = load ptr, ptr %lex.424, align 8
  %3 = getelementptr inbounds nuw %Lexer, ptr %2, i32 0, i32 2
  %4 = load i32, ptr %3, align 4
  %start_line.425 = alloca i32, align 4
  store i32 %4, ptr %start_line.425, align 4
  %5 = load ptr, ptr %lex.424, align 8
  %6 = getelementptr inbounds nuw %Lexer, ptr %5, i32 0, i32 3
  %7 = load i32, ptr %6, align 4
  %start_col.426 = alloca i32, align 4
  store i32 %7, ptr %start_col.426, align 4
  %8 = load ptr, ptr %lex.424, align 8
  %9 = getelementptr inbounds nuw %Lexer, ptr %8, i32 0, i32 1
  %10 = load i32, ptr %9, align 4
  %start_pos.427 = alloca i32, align 4
  store i32 %10, ptr %start_pos.427, align 4
  %11 = load ptr, ptr %lex.424, align 8
  %12 = getelementptr inbounds nuw %Lexer, ptr %11, i32 0, i32 1
  %13 = load i32, ptr %12, align 4
  %14 = load ptr, ptr %lex.424, align 8
  %15 = getelementptr inbounds nuw %Lexer, ptr %14, i32 0, i32 5
  %16 = load i32, ptr %15, align 4
  %17 = icmp sge i32 %13, %16
  %c.428 = alloca i8, align 1
  %start.429 = alloca i32, align 4
  %length.430 = alloca i32, align 4
  %value.431 = alloca ptr, align 8
  %start.432 = alloca i32, align 4
  %is_float.433 = alloca i32, align 4
  %sc.15 = alloca i1, align 1
  %length.434 = alloca i32, align 4
  %value.435 = alloca ptr, align 8
  %start.436 = alloca i32, align 4
  %body_col.437 = alloca i32, align 4
  %has_escape.438 = alloca i1, align 1
  %sc.16 = alloca i1, align 1
  %length.439 = alloca i32, align 4
  %raw.440 = alloca ptr, align 8
  %value.441 = alloca ptr, align 8
  %value_char.442 = alloca i8, align 1
  %esc.443 = alloca i8, align 1
  %start.444 = alloca i32, align 4
  %next.445 = alloca i8, align 1
  %sc.17 = alloca i1, align 1
  %sc.18 = alloca i1, align 1
  %sc.19 = alloca i1, align 1
  %sc.20 = alloca i1, align 1
  %sc.21 = alloca i1, align 1
  %sc.22 = alloca i1, align 1
  %sc.23 = alloca i1, align 1
  %sc.24 = alloca i1, align 1
  %sc.25 = alloca i1, align 1
  %sc.26 = alloca i1, align 1
  %sc.27 = alloca i1, align 1
  %sc.28 = alloca i1, align 1
  %sc.29 = alloca i1, align 1
  %sc.30 = alloca i1, align 1
  %sc.31 = alloca i1, align 1
  %sc.32 = alloca i1, align 1
  %length.446 = alloca i32, align 4
  %value.447 = alloca ptr, align 8
  %type.448 = alloca i32, align 4
  %sc.33 = alloca i1, align 1
  %sc.34 = alloca i1, align 1
  %sc.35 = alloca i1, align 1
  %sc.36 = alloca i1, align 1
  %sc.37 = alloca i1, align 1
  %sc.38 = alloca i1, align 1
  %sc.39 = alloca i1, align 1
  %sc.40 = alloca i1, align 1
  %sc.41 = alloca i1, align 1
  %val.449 = alloca ptr, align 8
  br i1 %17, label %label_279, label %label_281

label_281:                                        ; preds = %entry
  %18 = load ptr, ptr %lex.424, align 8
  %19 = call i8 @lexer_current__Struct_Lexer(ptr %18)
  store i8 %19, ptr %c.428, align 1
  %20 = load i8, ptr %c.428, align 1
  %21 = call i1 @is_alpha__Char(i8 %20)
  br i1 %21, label %label_282, label %label_284

label_279:                                        ; preds = %entry
  %22 = load ptr, ptr %lex.424, align 8
  %23 = load i32, ptr %start_line.425, align 4
  %24 = load i32, ptr %start_col.426, align 4
  %25 = load i32, ptr %start_pos.427, align 4
  %26 = call ptr @lexer_token__Struct_Lexer_Enum_TokenType_String_Int_Int_Int(ptr %22, i32 20, ptr @.str.s49, i32 %23, i32 %24, i32 %25)
  ret ptr %26

label_284:                                        ; preds = %label_281
  %27 = load i8, ptr %c.428, align 1
  %28 = call i1 @is_digit__Char(i8 %27)
  br i1 %28, label %label_294, label %label_296

label_282:                                        ; preds = %label_281
  %29 = load ptr, ptr %lex.424, align 8
  %30 = getelementptr inbounds nuw %Lexer, ptr %29, i32 0, i32 1
  %31 = load i32, ptr %30, align 4
  store i32 %31, ptr %start.429, align 4
  br label %label_285

label_285:                                        ; preds = %label_286, %label_282
  %32 = load ptr, ptr %lex.424, align 8
  %33 = call i8 @lexer_current__Struct_Lexer(ptr %32)
  %34 = call i1 @is_alnum__Char(i8 %33)
  br i1 %34, label %label_286, label %label_287

label_287:                                        ; preds = %label_285
  %35 = load ptr, ptr %lex.424, align 8
  %36 = getelementptr inbounds nuw %Lexer, ptr %35, i32 0, i32 1
  %37 = load i32, ptr %36, align 4
  %38 = load i32, ptr %start.429, align 4
  %39 = sub i32 %37, %38
  store i32 %39, ptr %length.430, align 4
  %40 = load ptr, ptr %lex.424, align 8
  %41 = getelementptr inbounds nuw %Lexer, ptr %40, i32 0, i32 0
  %42 = load ptr, ptr %41, align 8
  %43 = load i32, ptr %start.429, align 4
  %44 = load i32, ptr %length.430, align 4
  %45 = call ptr @str_substring(ptr %42, i32 %43, i32 %44)
  store ptr %45, ptr %value.431, align 8
  %46 = load ptr, ptr %value.431, align 8
  %47 = call i1 @is_keyword__String(ptr %46)
  br i1 %47, label %label_288, label %label_290

label_286:                                        ; preds = %label_285
  %48 = load ptr, ptr %lex.424, align 8
  call void @lexer_advance__Struct_Lexer(ptr %48)
  br label %label_285

label_290:                                        ; preds = %label_287
  %49 = load ptr, ptr %lex.424, align 8
  %50 = load ptr, ptr %value.431, align 8
  %51 = load i32, ptr %start_line.425, align 4
  %52 = load i32, ptr %start_col.426, align 4
  %53 = load i32, ptr %start_pos.427, align 4
  %54 = call ptr @lexer_token__Struct_Lexer_Enum_TokenType_String_Int_Int_Int(ptr %49, i32 5, ptr %50, i32 %51, i32 %52, i32 %53)
  ret ptr %54

label_288:                                        ; preds = %label_287
  %55 = load ptr, ptr %value.431, align 8
  %56 = call i1 @is_boolean__String(ptr %55)
  br i1 %56, label %label_291, label %label_293

label_293:                                        ; preds = %label_288
  %57 = load ptr, ptr %lex.424, align 8
  %58 = load ptr, ptr %value.431, align 8
  %59 = load i32, ptr %start_line.425, align 4
  %60 = load i32, ptr %start_col.426, align 4
  %61 = load i32, ptr %start_pos.427, align 4
  %62 = call ptr @lexer_token__Struct_Lexer_Enum_TokenType_String_Int_Int_Int(ptr %57, i32 18, ptr %58, i32 %59, i32 %60, i32 %61)
  ret ptr %62

label_291:                                        ; preds = %label_288
  %63 = load ptr, ptr %lex.424, align 8
  %64 = load ptr, ptr %value.431, align 8
  %65 = load i32, ptr %start_line.425, align 4
  %66 = load i32, ptr %start_col.426, align 4
  %67 = load i32, ptr %start_pos.427, align 4
  %68 = call ptr @lexer_token__Struct_Lexer_Enum_TokenType_String_Int_Int_Int(ptr %63, i32 4, ptr %64, i32 %65, i32 %66, i32 %67)
  ret ptr %68

label_296:                                        ; preds = %label_284
  %69 = load i8, ptr %c.428, align 1
  %70 = icmp eq i8 %69, 34
  br i1 %70, label %label_311, label %label_313

label_294:                                        ; preds = %label_284
  %71 = load ptr, ptr %lex.424, align 8
  %72 = getelementptr inbounds nuw %Lexer, ptr %71, i32 0, i32 1
  %73 = load i32, ptr %72, align 4
  store i32 %73, ptr %start.432, align 4
  store i32 0, ptr %is_float.433, align 4
  br label %label_297

label_297:                                        ; preds = %label_298, %label_294
  %74 = load ptr, ptr %lex.424, align 8
  %75 = call i8 @lexer_current__Struct_Lexer(ptr %74)
  %76 = call i1 @is_digit__Char(i8 %75)
  br i1 %76, label %label_298, label %label_299

label_299:                                        ; preds = %label_297
  %77 = load ptr, ptr %lex.424, align 8
  %78 = call i8 @lexer_current__Struct_Lexer(ptr %77)
  %79 = icmp eq i8 %78, 46
  store i1 %79, ptr %sc.15, align 1
  br i1 %79, label %label_300, label %label_301

label_298:                                        ; preds = %label_297
  %80 = load ptr, ptr %lex.424, align 8
  call void @lexer_advance__Struct_Lexer(ptr %80)
  br label %label_297

label_301:                                        ; preds = %label_300, %label_299
  %81 = load i1, ptr %sc.15, align 1
  br i1 %81, label %label_302, label %label_304

label_300:                                        ; preds = %label_299
  %82 = load ptr, ptr %lex.424, align 8
  %83 = call i8 @lexer_peek__Struct_Lexer_Int(ptr %82, i32 1)
  %84 = call i1 @is_digit__Char(i8 %83)
  store i1 %84, ptr %sc.15, align 1
  br label %label_301

label_304:                                        ; preds = %label_307, %label_301
  %85 = load ptr, ptr %lex.424, align 8
  %86 = getelementptr inbounds nuw %Lexer, ptr %85, i32 0, i32 1
  %87 = load i32, ptr %86, align 4
  %88 = load i32, ptr %start.432, align 4
  %89 = sub i32 %87, %88
  store i32 %89, ptr %length.434, align 4
  %90 = load ptr, ptr %lex.424, align 8
  %91 = getelementptr inbounds nuw %Lexer, ptr %90, i32 0, i32 0
  %92 = load ptr, ptr %91, align 8
  %93 = load i32, ptr %start.432, align 4
  %94 = load i32, ptr %length.434, align 4
  %95 = call ptr @str_substring(ptr %92, i32 %93, i32 %94)
  store ptr %95, ptr %value.435, align 8
  %96 = load i32, ptr %is_float.433, align 4
  %97 = icmp eq i32 %96, 1
  br i1 %97, label %label_308, label %label_310

label_302:                                        ; preds = %label_301
  store i32 1, ptr %is_float.433, align 4
  %98 = load ptr, ptr %lex.424, align 8
  call void @lexer_advance__Struct_Lexer(ptr %98)
  br label %label_305

label_305:                                        ; preds = %label_306, %label_302
  %99 = load ptr, ptr %lex.424, align 8
  %100 = call i8 @lexer_current__Struct_Lexer(ptr %99)
  %101 = call i1 @is_digit__Char(i8 %100)
  br i1 %101, label %label_306, label %label_307

label_307:                                        ; preds = %label_305
  br label %label_304

label_306:                                        ; preds = %label_305
  %102 = load ptr, ptr %lex.424, align 8
  call void @lexer_advance__Struct_Lexer(ptr %102)
  br label %label_305

label_310:                                        ; preds = %label_304
  %103 = load ptr, ptr %lex.424, align 8
  %104 = load ptr, ptr %value.435, align 8
  %105 = load i32, ptr %start_line.425, align 4
  %106 = load i32, ptr %start_col.426, align 4
  %107 = load i32, ptr %start_pos.427, align 4
  %108 = call ptr @lexer_token__Struct_Lexer_Enum_TokenType_String_Int_Int_Int(ptr %103, i32 2, ptr %104, i32 %105, i32 %106, i32 %107)
  ret ptr %108

label_308:                                        ; preds = %label_304
  %109 = load ptr, ptr %lex.424, align 8
  %110 = load ptr, ptr %value.435, align 8
  %111 = load i32, ptr %start_line.425, align 4
  %112 = load i32, ptr %start_col.426, align 4
  %113 = load i32, ptr %start_pos.427, align 4
  %114 = call ptr @lexer_token__Struct_Lexer_Enum_TokenType_String_Int_Int_Int(ptr %109, i32 3, ptr %110, i32 %111, i32 %112, i32 %113)
  ret ptr %114

label_313:                                        ; preds = %label_296
  %115 = load i8, ptr %c.428, align 1
  %116 = icmp eq i8 %115, 39
  br i1 %116, label %label_331, label %label_333

label_311:                                        ; preds = %label_296
  %117 = load ptr, ptr %lex.424, align 8
  call void @lexer_advance__Struct_Lexer(ptr %117)
  %118 = load ptr, ptr %lex.424, align 8
  %119 = getelementptr inbounds nuw %Lexer, ptr %118, i32 0, i32 1
  %120 = load i32, ptr %119, align 4
  store i32 %120, ptr %start.436, align 4
  %121 = load ptr, ptr %lex.424, align 8
  %122 = getelementptr inbounds nuw %Lexer, ptr %121, i32 0, i32 3
  %123 = load i32, ptr %122, align 4
  store i32 %123, ptr %body_col.437, align 4
  store i1 false, ptr %has_escape.438, align 1
  br label %label_314

label_314:                                        ; preds = %label_324, %label_311
  %124 = load ptr, ptr %lex.424, align 8
  %125 = call i8 @lexer_current__Struct_Lexer(ptr %124)
  %126 = icmp ne i8 %125, 34
  store i1 %126, ptr %sc.16, align 1
  br i1 %126, label %label_317, label %label_318

label_318:                                        ; preds = %label_317, %label_314
  %127 = load i1, ptr %sc.16, align 1
  br i1 %127, label %label_315, label %label_316

label_317:                                        ; preds = %label_314
  %128 = load ptr, ptr %lex.424, align 8
  %129 = getelementptr inbounds nuw %Lexer, ptr %128, i32 0, i32 1
  %130 = load i32, ptr %129, align 4
  %131 = load ptr, ptr %lex.424, align 8
  %132 = getelementptr inbounds nuw %Lexer, ptr %131, i32 0, i32 5
  %133 = load i32, ptr %132, align 4
  %134 = icmp slt i32 %130, %133
  store i1 %134, ptr %sc.16, align 1
  br label %label_318

label_316:                                        ; preds = %label_318
  %135 = load ptr, ptr %lex.424, align 8
  %136 = getelementptr inbounds nuw %Lexer, ptr %135, i32 0, i32 1
  %137 = load i32, ptr %136, align 4
  %138 = load i32, ptr %start.436, align 4
  %139 = sub i32 %137, %138
  store i32 %139, ptr %length.439, align 4
  %140 = load ptr, ptr %lex.424, align 8
  %141 = getelementptr inbounds nuw %Lexer, ptr %140, i32 0, i32 0
  %142 = load ptr, ptr %141, align 8
  %143 = load i32, ptr %start.436, align 4
  %144 = load i32, ptr %length.439, align 4
  %145 = call ptr @str_substring(ptr %142, i32 %143, i32 %144)
  store ptr %145, ptr %raw.440, align 8
  %146 = load ptr, ptr %lex.424, align 8
  %147 = call i8 @lexer_current__Struct_Lexer(ptr %146)
  %148 = icmp eq i8 %147, 34
  br i1 %148, label %label_325, label %label_326

label_315:                                        ; preds = %label_318
  %149 = load ptr, ptr %lex.424, align 8
  %150 = call i8 @lexer_current__Struct_Lexer(ptr %149)
  %151 = icmp eq i8 %150, 92
  br i1 %151, label %label_319, label %label_321

label_321:                                        ; preds = %label_319, %label_315
  %152 = load ptr, ptr %lex.424, align 8
  %153 = call i8 @lexer_current__Struct_Lexer(ptr %152)
  %154 = icmp eq i8 %153, 10
  br i1 %154, label %label_322, label %label_324

label_319:                                        ; preds = %label_315
  store i1 true, ptr %has_escape.438, align 1
  %155 = load ptr, ptr %lex.424, align 8
  call void @lexer_advance__Struct_Lexer(ptr %155)
  br label %label_321

label_324:                                        ; preds = %label_322, %label_321
  %156 = load ptr, ptr %lex.424, align 8
  call void @lexer_advance__Struct_Lexer(ptr %156)
  br label %label_314

label_322:                                        ; preds = %label_321
  %157 = load ptr, ptr %lex.424, align 8
  %158 = load ptr, ptr %lex.424, align 8
  %159 = getelementptr inbounds nuw %Lexer, ptr %158, i32 0, i32 2
  %160 = load i32, ptr %159, align 4
  %161 = add i32 %160, 1
  %162 = getelementptr inbounds nuw %Lexer, ptr %157, i32 0, i32 2
  store i32 %161, ptr %162, align 4
  %163 = load ptr, ptr %lex.424, align 8
  %164 = getelementptr inbounds nuw %Lexer, ptr %163, i32 0, i32 3
  store i32 0, ptr %164, align 4
  br label %label_324

label_326:                                        ; preds = %label_316
  %165 = load ptr, ptr %lex.424, align 8
  %166 = load i32, ptr %start_line.425, align 4
  %167 = load i32, ptr %start_col.426, align 4
  call void @lexer_fatal__Struct_Lexer_Int_Int_String(ptr %165, i32 %166, i32 %167, ptr @.str.s50)
  br label %label_327

label_325:                                        ; preds = %label_316
  %168 = load ptr, ptr %lex.424, align 8
  call void @lexer_advance__Struct_Lexer(ptr %168)
  br label %label_327

label_327:                                        ; preds = %label_326, %label_325
  %169 = load ptr, ptr %raw.440, align 8
  store ptr %169, ptr %value.441, align 8
  %170 = load i1, ptr %has_escape.438, align 1
  br i1 %170, label %label_328, label %label_330

label_330:                                        ; preds = %label_328, %label_327
  %171 = load ptr, ptr %lex.424, align 8
  %172 = load ptr, ptr %value.441, align 8
  %173 = load i32, ptr %start_line.425, align 4
  %174 = load i32, ptr %start_col.426, align 4
  %175 = load i32, ptr %start_pos.427, align 4
  %176 = call ptr @lexer_token__Struct_Lexer_Enum_TokenType_String_Int_Int_Int(ptr %171, i32 0, ptr %172, i32 %173, i32 %174, i32 %175)
  ret ptr %176

label_328:                                        ; preds = %label_327
  %177 = load ptr, ptr %lex.424, align 8
  %178 = load ptr, ptr %raw.440, align 8
  %179 = load i32, ptr %start_line.425, align 4
  %180 = load i32, ptr %body_col.437, align 4
  %181 = call ptr @lexer_decode_escapes__Struct_Lexer_String_Int_Int(ptr %177, ptr %178, i32 %179, i32 %180)
  store ptr %181, ptr %value.441, align 8
  br label %label_330

label_333:                                        ; preds = %label_313
  %182 = load i8, ptr %c.428, align 1
  %183 = call i1 @is_operator__Char(i8 %182)
  br i1 %183, label %label_361, label %label_363

label_331:                                        ; preds = %label_313
  %184 = load ptr, ptr %lex.424, align 8
  call void @lexer_advance__Struct_Lexer(ptr %184)
  %185 = load ptr, ptr %lex.424, align 8
  %186 = call i8 @lexer_current__Struct_Lexer(ptr %185)
  store i8 %186, ptr %value_char.442, align 1
  %187 = load i8, ptr %value_char.442, align 1
  %188 = icmp eq i8 %187, 92
  br i1 %188, label %label_334, label %label_336

label_336:                                        ; preds = %label_357, %label_331
  %189 = load ptr, ptr %lex.424, align 8
  call void @lexer_advance__Struct_Lexer(ptr %189)
  %190 = load ptr, ptr %lex.424, align 8
  %191 = call i8 @lexer_current__Struct_Lexer(ptr %190)
  %192 = icmp eq i8 %191, 39
  br i1 %192, label %label_358, label %label_359

label_334:                                        ; preds = %label_331
  %193 = load ptr, ptr %lex.424, align 8
  call void @lexer_advance__Struct_Lexer(ptr %193)
  %194 = load ptr, ptr %lex.424, align 8
  %195 = call i8 @lexer_current__Struct_Lexer(ptr %194)
  store i8 %195, ptr %esc.443, align 1
  %196 = load i8, ptr %esc.443, align 1
  %197 = icmp eq i8 %196, 110
  br i1 %197, label %label_337, label %label_339

label_339:                                        ; preds = %label_337, %label_334
  %198 = load i8, ptr %esc.443, align 1
  %199 = icmp eq i8 %198, 116
  br i1 %199, label %label_340, label %label_342

label_337:                                        ; preds = %label_334
  store i8 10, ptr %value_char.442, align 1
  br label %label_339

label_342:                                        ; preds = %label_340, %label_339
  %200 = load i8, ptr %esc.443, align 1
  %201 = icmp eq i8 %200, 114
  br i1 %201, label %label_343, label %label_345

label_340:                                        ; preds = %label_339
  store i8 9, ptr %value_char.442, align 1
  br label %label_342

label_345:                                        ; preds = %label_343, %label_342
  %202 = load i8, ptr %esc.443, align 1
  %203 = icmp eq i8 %202, 48
  br i1 %203, label %label_346, label %label_348

label_343:                                        ; preds = %label_342
  store i8 13, ptr %value_char.442, align 1
  br label %label_345

label_348:                                        ; preds = %label_346, %label_345
  %204 = load i8, ptr %esc.443, align 1
  %205 = icmp eq i8 %204, 92
  br i1 %205, label %label_349, label %label_351

label_346:                                        ; preds = %label_345
  store i8 0, ptr %value_char.442, align 1
  br label %label_348

label_351:                                        ; preds = %label_349, %label_348
  %206 = load i8, ptr %esc.443, align 1
  %207 = icmp eq i8 %206, 39
  br i1 %207, label %label_352, label %label_354

label_349:                                        ; preds = %label_348
  store i8 92, ptr %value_char.442, align 1
  br label %label_351

label_354:                                        ; preds = %label_352, %label_351
  %208 = load i8, ptr %esc.443, align 1
  %209 = icmp eq i8 %208, 34
  br i1 %209, label %label_355, label %label_357

label_352:                                        ; preds = %label_351
  store i8 39, ptr %value_char.442, align 1
  br label %label_354

label_357:                                        ; preds = %label_355, %label_354
  br label %label_336

label_355:                                        ; preds = %label_354
  store i8 34, ptr %value_char.442, align 1
  br label %label_357

label_359:                                        ; preds = %label_336
  %210 = load ptr, ptr %lex.424, align 8
  %211 = load i32, ptr %start_line.425, align 4
  %212 = load i32, ptr %start_col.426, align 4
  call void @lexer_fatal__Struct_Lexer_Int_Int_String(ptr %210, i32 %211, i32 %212, ptr @.str.s51)
  br label %label_360

label_358:                                        ; preds = %label_336
  %213 = load ptr, ptr %lex.424, align 8
  call void @lexer_advance__Struct_Lexer(ptr %213)
  br label %label_360

label_360:                                        ; preds = %label_359, %label_358
  %214 = load ptr, ptr %lex.424, align 8
  %215 = load i8, ptr %value_char.442, align 1
  %216 = call i32 @char_code__Char(i8 %215)
  %217 = call ptr @int_to_str(i32 %216)
  %218 = load i32, ptr %start_line.425, align 4
  %219 = load i32, ptr %start_col.426, align 4
  %220 = load i32, ptr %start_pos.427, align 4
  %221 = call ptr @lexer_token__Struct_Lexer_Enum_TokenType_String_Int_Int_Int(ptr %214, i32 1, ptr %217, i32 %218, i32 %219, i32 %220)
  ret ptr %221

label_363:                                        ; preds = %label_333
  %222 = load i8, ptr %c.428, align 1
  %223 = icmp eq i8 %222, 46
  store i1 %223, ptr %sc.41, align 1
  br i1 %223, label %label_478, label %label_479

label_361:                                        ; preds = %label_333
  %224 = load ptr, ptr %lex.424, align 8
  %225 = getelementptr inbounds nuw %Lexer, ptr %224, i32 0, i32 1
  %226 = load i32, ptr %225, align 4
  store i32 %226, ptr %start.444, align 4
  %227 = load ptr, ptr %lex.424, align 8
  call void @lexer_advance__Struct_Lexer(ptr %227)
  %228 = load ptr, ptr %lex.424, align 8
  %229 = call i8 @lexer_current__Struct_Lexer(ptr %228)
  store i8 %229, ptr %next.445, align 1
  %230 = load i8, ptr %c.428, align 1
  %231 = icmp eq i8 %230, 61
  store i1 %231, ptr %sc.17, align 1
  br i1 %231, label %label_364, label %label_365

label_365:                                        ; preds = %label_364, %label_361
  %232 = load i1, ptr %sc.17, align 1
  br i1 %232, label %label_366, label %label_368

label_364:                                        ; preds = %label_361
  %233 = load i8, ptr %next.445, align 1
  %234 = icmp eq i8 %233, 61
  store i1 %234, ptr %sc.17, align 1
  br label %label_365

label_368:                                        ; preds = %label_366, %label_365
  %235 = load i8, ptr %c.428, align 1
  %236 = icmp eq i8 %235, 33
  store i1 %236, ptr %sc.18, align 1
  br i1 %236, label %label_369, label %label_370

label_366:                                        ; preds = %label_365
  %237 = load ptr, ptr %lex.424, align 8
  call void @lexer_advance__Struct_Lexer(ptr %237)
  br label %label_368

label_370:                                        ; preds = %label_369, %label_368
  %238 = load i1, ptr %sc.18, align 1
  br i1 %238, label %label_371, label %label_373

label_369:                                        ; preds = %label_368
  %239 = load i8, ptr %next.445, align 1
  %240 = icmp eq i8 %239, 61
  store i1 %240, ptr %sc.18, align 1
  br label %label_370

label_373:                                        ; preds = %label_371, %label_370
  %241 = load i8, ptr %c.428, align 1
  %242 = icmp eq i8 %241, 60
  store i1 %242, ptr %sc.19, align 1
  br i1 %242, label %label_374, label %label_375

label_371:                                        ; preds = %label_370
  %243 = load ptr, ptr %lex.424, align 8
  call void @lexer_advance__Struct_Lexer(ptr %243)
  br label %label_373

label_375:                                        ; preds = %label_374, %label_373
  %244 = load i1, ptr %sc.19, align 1
  br i1 %244, label %label_376, label %label_378

label_374:                                        ; preds = %label_373
  %245 = load i8, ptr %next.445, align 1
  %246 = icmp eq i8 %245, 61
  store i1 %246, ptr %sc.19, align 1
  br label %label_375

label_378:                                        ; preds = %label_376, %label_375
  %247 = load i8, ptr %c.428, align 1
  %248 = icmp eq i8 %247, 62
  store i1 %248, ptr %sc.20, align 1
  br i1 %248, label %label_379, label %label_380

label_376:                                        ; preds = %label_375
  %249 = load ptr, ptr %lex.424, align 8
  call void @lexer_advance__Struct_Lexer(ptr %249)
  br label %label_378

label_380:                                        ; preds = %label_379, %label_378
  %250 = load i1, ptr %sc.20, align 1
  br i1 %250, label %label_381, label %label_383

label_379:                                        ; preds = %label_378
  %251 = load i8, ptr %next.445, align 1
  %252 = icmp eq i8 %251, 61
  store i1 %252, ptr %sc.20, align 1
  br label %label_380

label_383:                                        ; preds = %label_381, %label_380
  %253 = load i8, ptr %c.428, align 1
  %254 = icmp eq i8 %253, 38
  store i1 %254, ptr %sc.21, align 1
  br i1 %254, label %label_384, label %label_385

label_381:                                        ; preds = %label_380
  %255 = load ptr, ptr %lex.424, align 8
  call void @lexer_advance__Struct_Lexer(ptr %255)
  br label %label_383

label_385:                                        ; preds = %label_384, %label_383
  %256 = load i1, ptr %sc.21, align 1
  br i1 %256, label %label_386, label %label_388

label_384:                                        ; preds = %label_383
  %257 = load i8, ptr %next.445, align 1
  %258 = icmp eq i8 %257, 38
  store i1 %258, ptr %sc.21, align 1
  br label %label_385

label_388:                                        ; preds = %label_386, %label_385
  %259 = load i8, ptr %c.428, align 1
  %260 = icmp eq i8 %259, 124
  store i1 %260, ptr %sc.22, align 1
  br i1 %260, label %label_389, label %label_390

label_386:                                        ; preds = %label_385
  %261 = load ptr, ptr %lex.424, align 8
  call void @lexer_advance__Struct_Lexer(ptr %261)
  br label %label_388

label_390:                                        ; preds = %label_389, %label_388
  %262 = load i1, ptr %sc.22, align 1
  br i1 %262, label %label_391, label %label_393

label_389:                                        ; preds = %label_388
  %263 = load i8, ptr %next.445, align 1
  %264 = icmp eq i8 %263, 124
  store i1 %264, ptr %sc.22, align 1
  br label %label_390

label_393:                                        ; preds = %label_391, %label_390
  %265 = load i8, ptr %c.428, align 1
  %266 = icmp eq i8 %265, 45
  store i1 %266, ptr %sc.23, align 1
  br i1 %266, label %label_394, label %label_395

label_391:                                        ; preds = %label_390
  %267 = load ptr, ptr %lex.424, align 8
  call void @lexer_advance__Struct_Lexer(ptr %267)
  br label %label_393

label_395:                                        ; preds = %label_394, %label_393
  %268 = load i1, ptr %sc.23, align 1
  br i1 %268, label %label_396, label %label_398

label_394:                                        ; preds = %label_393
  %269 = load i8, ptr %next.445, align 1
  %270 = icmp eq i8 %269, 62
  store i1 %270, ptr %sc.23, align 1
  br label %label_395

label_398:                                        ; preds = %label_396, %label_395
  %271 = load i8, ptr %c.428, align 1
  %272 = icmp eq i8 %271, 61
  store i1 %272, ptr %sc.24, align 1
  br i1 %272, label %label_399, label %label_400

label_396:                                        ; preds = %label_395
  %273 = load ptr, ptr %lex.424, align 8
  call void @lexer_advance__Struct_Lexer(ptr %273)
  br label %label_398

label_400:                                        ; preds = %label_399, %label_398
  %274 = load i1, ptr %sc.24, align 1
  br i1 %274, label %label_401, label %label_403

label_399:                                        ; preds = %label_398
  %275 = load i8, ptr %next.445, align 1
  %276 = icmp eq i8 %275, 62
  store i1 %276, ptr %sc.24, align 1
  br label %label_400

label_403:                                        ; preds = %label_401, %label_400
  %277 = load i8, ptr %c.428, align 1
  %278 = icmp eq i8 %277, 60
  store i1 %278, ptr %sc.25, align 1
  br i1 %278, label %label_404, label %label_405

label_401:                                        ; preds = %label_400
  %279 = load ptr, ptr %lex.424, align 8
  call void @lexer_advance__Struct_Lexer(ptr %279)
  br label %label_403

label_405:                                        ; preds = %label_404, %label_403
  %280 = load i1, ptr %sc.25, align 1
  br i1 %280, label %label_406, label %label_408

label_404:                                        ; preds = %label_403
  %281 = load i8, ptr %next.445, align 1
  %282 = icmp eq i8 %281, 60
  store i1 %282, ptr %sc.25, align 1
  br label %label_405

label_408:                                        ; preds = %label_406, %label_405
  %283 = load i8, ptr %c.428, align 1
  %284 = icmp eq i8 %283, 62
  store i1 %284, ptr %sc.26, align 1
  br i1 %284, label %label_409, label %label_410

label_406:                                        ; preds = %label_405
  %285 = load ptr, ptr %lex.424, align 8
  call void @lexer_advance__Struct_Lexer(ptr %285)
  br label %label_408

label_410:                                        ; preds = %label_409, %label_408
  %286 = load i1, ptr %sc.26, align 1
  br i1 %286, label %label_411, label %label_413

label_409:                                        ; preds = %label_408
  %287 = load i8, ptr %next.445, align 1
  %288 = icmp eq i8 %287, 62
  store i1 %288, ptr %sc.26, align 1
  br label %label_410

label_413:                                        ; preds = %label_411, %label_410
  %289 = load i8, ptr %next.445, align 1
  %290 = icmp eq i8 %289, 61
  br i1 %290, label %label_414, label %label_416

label_411:                                        ; preds = %label_410
  %291 = load ptr, ptr %lex.424, align 8
  call void @lexer_advance__Struct_Lexer(ptr %291)
  br label %label_413

label_416:                                        ; preds = %label_434, %label_413
  %292 = load ptr, ptr %lex.424, align 8
  %293 = getelementptr inbounds nuw %Lexer, ptr %292, i32 0, i32 1
  %294 = load i32, ptr %293, align 4
  %295 = load i32, ptr %start.444, align 4
  %296 = sub i32 %294, %295
  store i32 %296, ptr %length.446, align 4
  %297 = load ptr, ptr %lex.424, align 8
  %298 = getelementptr inbounds nuw %Lexer, ptr %297, i32 0, i32 0
  %299 = load ptr, ptr %298, align 8
  %300 = load i32, ptr %start.444, align 4
  %301 = load i32, ptr %length.446, align 4
  %302 = call ptr @str_substring(ptr %299, i32 %300, i32 %301)
  store ptr %302, ptr %value.447, align 8
  store i32 8, ptr %type.448, align 4
  %303 = load i32, ptr %length.446, align 4
  %304 = icmp eq i32 %303, 2
  br i1 %304, label %label_435, label %label_436

label_414:                                        ; preds = %label_413
  %305 = load i8, ptr %c.428, align 1
  %306 = icmp eq i8 %305, 43
  store i1 %306, ptr %sc.30, align 1
  br i1 %306, label %label_424, label %label_423

label_423:                                        ; preds = %label_414
  %307 = load i8, ptr %c.428, align 1
  %308 = icmp eq i8 %307, 45
  store i1 %308, ptr %sc.30, align 1
  br label %label_424

label_424:                                        ; preds = %label_423, %label_414
  %309 = load i1, ptr %sc.30, align 1
  store i1 %309, ptr %sc.29, align 1
  br i1 %309, label %label_422, label %label_421

label_421:                                        ; preds = %label_424
  %310 = load i8, ptr %c.428, align 1
  %311 = icmp eq i8 %310, 42
  store i1 %311, ptr %sc.29, align 1
  br label %label_422

label_422:                                        ; preds = %label_421, %label_424
  %312 = load i1, ptr %sc.29, align 1
  store i1 %312, ptr %sc.28, align 1
  br i1 %312, label %label_420, label %label_419

label_419:                                        ; preds = %label_422
  %313 = load i8, ptr %c.428, align 1
  %314 = icmp eq i8 %313, 47
  store i1 %314, ptr %sc.28, align 1
  br label %label_420

label_420:                                        ; preds = %label_419, %label_422
  %315 = load i1, ptr %sc.28, align 1
  store i1 %315, ptr %sc.27, align 1
  br i1 %315, label %label_418, label %label_417

label_417:                                        ; preds = %label_420
  %316 = load i8, ptr %c.428, align 1
  %317 = icmp eq i8 %316, 37
  store i1 %317, ptr %sc.27, align 1
  br label %label_418

label_418:                                        ; preds = %label_417, %label_420
  %318 = load i1, ptr %sc.27, align 1
  br i1 %318, label %label_425, label %label_427

label_427:                                        ; preds = %label_425, %label_418
  %319 = load i8, ptr %c.428, align 1
  %320 = icmp eq i8 %319, 38
  store i1 %320, ptr %sc.32, align 1
  br i1 %320, label %label_431, label %label_430

label_425:                                        ; preds = %label_418
  %321 = load ptr, ptr %lex.424, align 8
  call void @lexer_advance__Struct_Lexer(ptr %321)
  br label %label_427

label_430:                                        ; preds = %label_427
  %322 = load i8, ptr %c.428, align 1
  %323 = icmp eq i8 %322, 124
  store i1 %323, ptr %sc.32, align 1
  br label %label_431

label_431:                                        ; preds = %label_430, %label_427
  %324 = load i1, ptr %sc.32, align 1
  store i1 %324, ptr %sc.31, align 1
  br i1 %324, label %label_429, label %label_428

label_428:                                        ; preds = %label_431
  %325 = load i8, ptr %c.428, align 1
  %326 = icmp eq i8 %325, 94
  store i1 %326, ptr %sc.31, align 1
  br label %label_429

label_429:                                        ; preds = %label_428, %label_431
  %327 = load i1, ptr %sc.31, align 1
  br i1 %327, label %label_432, label %label_434

label_434:                                        ; preds = %label_432, %label_429
  br label %label_416

label_432:                                        ; preds = %label_429
  %328 = load ptr, ptr %lex.424, align 8
  call void @lexer_advance__Struct_Lexer(ptr %328)
  br label %label_434

label_436:                                        ; preds = %label_416
  %329 = load i8, ptr %c.428, align 1
  %330 = icmp eq i8 %329, 60
  store i1 %330, ptr %sc.40, align 1
  br i1 %330, label %label_468, label %label_467

label_435:                                        ; preds = %label_416
  %331 = load ptr, ptr %value.447, align 8
  %332 = call i32 @str_equals(ptr %331, ptr @.str.s52)
  %333 = icmp eq i32 %332, 1
  store i1 %333, ptr %sc.35, align 1
  br i1 %333, label %label_443, label %label_442

label_442:                                        ; preds = %label_435
  %334 = load ptr, ptr %value.447, align 8
  %335 = call i32 @str_equals(ptr %334, ptr @.str.s53)
  %336 = icmp eq i32 %335, 1
  store i1 %336, ptr %sc.35, align 1
  br label %label_443

label_443:                                        ; preds = %label_442, %label_435
  %337 = load i1, ptr %sc.35, align 1
  store i1 %337, ptr %sc.34, align 1
  br i1 %337, label %label_441, label %label_440

label_440:                                        ; preds = %label_443
  %338 = load ptr, ptr %value.447, align 8
  %339 = call i32 @str_equals(ptr %338, ptr @.str.s54)
  %340 = icmp eq i32 %339, 1
  store i1 %340, ptr %sc.34, align 1
  br label %label_441

label_441:                                        ; preds = %label_440, %label_443
  %341 = load i1, ptr %sc.34, align 1
  store i1 %341, ptr %sc.33, align 1
  br i1 %341, label %label_439, label %label_438

label_438:                                        ; preds = %label_441
  %342 = load ptr, ptr %value.447, align 8
  %343 = call i32 @str_equals(ptr %342, ptr @.str.s55)
  %344 = icmp eq i32 %343, 1
  store i1 %344, ptr %sc.33, align 1
  br label %label_439

label_439:                                        ; preds = %label_438, %label_441
  %345 = load i1, ptr %sc.33, align 1
  br i1 %345, label %label_444, label %label_446

label_446:                                        ; preds = %label_444, %label_439
  %346 = load ptr, ptr %value.447, align 8
  %347 = call i32 @str_equals(ptr %346, ptr @.str.s56)
  %348 = icmp eq i32 %347, 1
  store i1 %348, ptr %sc.36, align 1
  br i1 %348, label %label_448, label %label_447

label_444:                                        ; preds = %label_439
  store i32 9, ptr %type.448, align 4
  br label %label_446

label_447:                                        ; preds = %label_446
  %349 = load ptr, ptr %value.447, align 8
  %350 = call i32 @str_equals(ptr %349, ptr @.str.s57)
  %351 = icmp eq i32 %350, 1
  store i1 %351, ptr %sc.36, align 1
  br label %label_448

label_448:                                        ; preds = %label_447, %label_446
  %352 = load i1, ptr %sc.36, align 1
  br i1 %352, label %label_449, label %label_451

label_451:                                        ; preds = %label_454, %label_448
  %353 = load ptr, ptr %value.447, align 8
  %354 = call i8 @str_char_at(ptr %353, i32 1)
  %355 = icmp eq i8 %354, 61
  store i1 %355, ptr %sc.37, align 1
  br i1 %355, label %label_455, label %label_456

label_449:                                        ; preds = %label_448
  store i32 15, ptr %type.448, align 4
  %356 = load ptr, ptr %value.447, align 8
  %357 = call i32 @str_equals(ptr %356, ptr @.str.s58)
  %358 = icmp eq i32 %357, 1
  br i1 %358, label %label_452, label %label_454

label_454:                                        ; preds = %label_452, %label_449
  br label %label_451

label_452:                                        ; preds = %label_449
  store i32 16, ptr %type.448, align 4
  br label %label_454

label_456:                                        ; preds = %label_455, %label_451
  %359 = load i1, ptr %sc.37, align 1
  br i1 %359, label %label_457, label %label_459

label_455:                                        ; preds = %label_451
  %360 = load ptr, ptr %value.447, align 8
  %361 = call i8 @str_char_at(ptr %360, i32 0)
  %362 = icmp ne i8 %361, 61
  store i1 %362, ptr %sc.37, align 1
  br label %label_456

label_459:                                        ; preds = %label_466, %label_456
  br label %label_437

label_457:                                        ; preds = %label_456
  %363 = load ptr, ptr %value.447, align 8
  %364 = call i32 @str_equals(ptr %363, ptr @.str.s59)
  %365 = icmp eq i32 %364, 0
  store i1 %365, ptr %sc.39, align 1
  br i1 %365, label %label_462, label %label_463

label_463:                                        ; preds = %label_462, %label_457
  %366 = load i1, ptr %sc.39, align 1
  store i1 %366, ptr %sc.38, align 1
  br i1 %366, label %label_460, label %label_461

label_462:                                        ; preds = %label_457
  %367 = load ptr, ptr %value.447, align 8
  %368 = call i32 @str_equals(ptr %367, ptr @.str.s60)
  %369 = icmp eq i32 %368, 0
  store i1 %369, ptr %sc.39, align 1
  br label %label_463

label_461:                                        ; preds = %label_460, %label_463
  %370 = load i1, ptr %sc.38, align 1
  br i1 %370, label %label_464, label %label_466

label_460:                                        ; preds = %label_463
  %371 = load ptr, ptr %value.447, align 8
  %372 = call i32 @str_equals(ptr %371, ptr @.str.s61)
  %373 = icmp eq i32 %372, 0
  store i1 %373, ptr %sc.38, align 1
  br label %label_461

label_466:                                        ; preds = %label_464, %label_461
  br label %label_459

label_464:                                        ; preds = %label_461
  store i32 12, ptr %type.448, align 4
  br label %label_466

label_437:                                        ; preds = %label_477, %label_459
  %374 = load ptr, ptr %lex.424, align 8
  %375 = load i32, ptr %type.448, align 4
  %376 = load ptr, ptr %value.447, align 8
  %377 = load i32, ptr %start_line.425, align 4
  %378 = load i32, ptr %start_col.426, align 4
  %379 = load i32, ptr %start_pos.427, align 4
  %380 = call ptr @lexer_token__Struct_Lexer_Enum_TokenType_String_Int_Int_Int(ptr %374, i32 %375, ptr %376, i32 %377, i32 %378, i32 %379)
  ret ptr %380

label_467:                                        ; preds = %label_436
  %381 = load i8, ptr %c.428, align 1
  %382 = icmp eq i8 %381, 62
  store i1 %382, ptr %sc.40, align 1
  br label %label_468

label_468:                                        ; preds = %label_467, %label_436
  %383 = load i1, ptr %sc.40, align 1
  br i1 %383, label %label_469, label %label_471

label_471:                                        ; preds = %label_469, %label_468
  %384 = load i8, ptr %c.428, align 1
  %385 = icmp eq i8 %384, 61
  br i1 %385, label %label_472, label %label_474

label_469:                                        ; preds = %label_468
  store i32 9, ptr %type.448, align 4
  br label %label_471

label_474:                                        ; preds = %label_472, %label_471
  %386 = load i8, ptr %c.428, align 1
  %387 = icmp eq i8 %386, 33
  br i1 %387, label %label_475, label %label_477

label_472:                                        ; preds = %label_471
  store i32 12, ptr %type.448, align 4
  br label %label_474

label_477:                                        ; preds = %label_475, %label_474
  br label %label_437

label_475:                                        ; preds = %label_474
  store i32 10, ptr %type.448, align 4
  br label %label_477

label_479:                                        ; preds = %label_478, %label_363
  %388 = load i1, ptr %sc.41, align 1
  br i1 %388, label %label_480, label %label_482

label_478:                                        ; preds = %label_363
  %389 = load ptr, ptr %lex.424, align 8
  %390 = call i8 @lexer_peek__Struct_Lexer_Int(ptr %389, i32 1)
  %391 = icmp eq i8 %390, 46
  store i1 %391, ptr %sc.41, align 1
  br label %label_479

label_482:                                        ; preds = %label_479
  %392 = load i8, ptr %c.428, align 1
  %393 = call i1 @is_separator__Char(i8 %392)
  br i1 %393, label %label_483, label %label_485

label_480:                                        ; preds = %label_479
  %394 = load ptr, ptr %lex.424, align 8
  call void @lexer_advance__Struct_Lexer(ptr %394)
  %395 = load ptr, ptr %lex.424, align 8
  call void @lexer_advance__Struct_Lexer(ptr %395)
  %396 = load ptr, ptr %lex.424, align 8
  %397 = load i32, ptr %start_line.425, align 4
  %398 = load i32, ptr %start_col.426, align 4
  %399 = load i32, ptr %start_pos.427, align 4
  %400 = call ptr @lexer_token__Struct_Lexer_Enum_TokenType_String_Int_Int_Int(ptr %396, i32 17, ptr @.str.s62, i32 %397, i32 %398, i32 %399)
  ret ptr %400

label_485:                                        ; preds = %label_482
  %401 = load ptr, ptr %lex.424, align 8
  call void @lexer_advance__Struct_Lexer(ptr %401)
  %402 = load ptr, ptr %lex.424, align 8
  %403 = load i32, ptr %start_line.425, align 4
  %404 = load i32, ptr %start_col.426, align 4
  %405 = load i8, ptr %c.428, align 1
  %406 = call ptr @str_from_char(i8 %405)
  %407 = call ptr @diag_quote__String(ptr %406)
  %408 = call ptr @str_concat(ptr @.str.s63, ptr %407)
  call void @lexer_fatal__Struct_Lexer_Int_Int_String(ptr %402, i32 %403, i32 %404, ptr %408)
  %409 = load ptr, ptr %lex.424, align 8
  %410 = load i32, ptr %start_line.425, align 4
  %411 = load i32, ptr %start_col.426, align 4
  %412 = load i32, ptr %start_pos.427, align 4
  %413 = call ptr @lexer_token__Struct_Lexer_Enum_TokenType_String_Int_Int_Int(ptr %409, i32 19, ptr @.str.s64, i32 %410, i32 %411, i32 %412)
  ret ptr %413

label_483:                                        ; preds = %label_482
  %414 = load ptr, ptr %lex.424, align 8
  %415 = getelementptr inbounds nuw %Lexer, ptr %414, i32 0, i32 0
  %416 = load ptr, ptr %415, align 8
  %417 = load ptr, ptr %lex.424, align 8
  %418 = getelementptr inbounds nuw %Lexer, ptr %417, i32 0, i32 1
  %419 = load i32, ptr %418, align 4
  %420 = call ptr @str_substring(ptr %416, i32 %419, i32 1)
  store ptr %420, ptr %val.449, align 8
  %421 = load ptr, ptr %lex.424, align 8
  call void @lexer_advance__Struct_Lexer(ptr %421)
  %422 = load ptr, ptr %lex.424, align 8
  %423 = load ptr, ptr %val.449, align 8
  %424 = load i32, ptr %start_line.425, align 4
  %425 = load i32, ptr %start_col.426, align 4
  %426 = load i32, ptr %start_pos.427, align 4
  %427 = call ptr @lexer_token__Struct_Lexer_Enum_TokenType_String_Int_Int_Int(ptr %422, i32 6, ptr %423, i32 %424, i32 %425, i32 %426)
  ret ptr %427
}

define ptr @lex_all_tokens__Struct_Lexer(ptr %0) {
entry:
  %lex.450 = alloca ptr, align 8
  store ptr %0, ptr %lex.450, align 8
  %1 = load ptr, ptr %lex.450, align 8
  %2 = call ptr @lexer_next_token__Struct_Lexer(ptr %1)
  %3 = call ptr @token_to_ptr(ptr %2)
  %head_ptr.451 = alloca ptr, align 8
  store ptr %3, ptr %head_ptr.451, align 8
  %4 = load ptr, ptr %head_ptr.451, align 8
  %current_ptr.452 = alloca ptr, align 8
  store ptr %4, ptr %current_ptr.452, align 8
  %scanning.453 = alloca i1, align 1
  store i1 true, ptr %scanning.453, align 1
  %current.454 = alloca ptr, align 8
  %next_ptr.455 = alloca ptr, align 8
  br label %label_486

label_486:                                        ; preds = %label_491, %entry
  %5 = load i1, ptr %scanning.453, align 1
  br i1 %5, label %label_487, label %label_488

label_488:                                        ; preds = %label_486
  %6 = load ptr, ptr %head_ptr.451, align 8
  %7 = call ptr @ptr_to_token(ptr %6)
  ret ptr %7

label_487:                                        ; preds = %label_486
  %8 = load ptr, ptr %current_ptr.452, align 8
  %9 = call ptr @ptr_to_token(ptr %8)
  store ptr %9, ptr %current.454, align 8
  %10 = load ptr, ptr %current.454, align 8
  %11 = getelementptr inbounds nuw %Token, ptr %10, i32 0, i32 0
  %12 = load i32, ptr %11, align 4
  %13 = icmp eq i32 %12, 20
  br i1 %13, label %label_489, label %label_490

label_490:                                        ; preds = %label_487
  %14 = load ptr, ptr %lex.450, align 8
  %15 = call ptr @lexer_next_token__Struct_Lexer(ptr %14)
  %16 = call ptr @token_to_ptr(ptr %15)
  store ptr %16, ptr %next_ptr.455, align 8
  %17 = load ptr, ptr %current.454, align 8
  %18 = load ptr, ptr %next_ptr.455, align 8
  %19 = getelementptr inbounds nuw %Token, ptr %17, i32 0, i32 6
  store ptr %18, ptr %19, align 8
  %20 = load ptr, ptr %next_ptr.455, align 8
  store ptr %20, ptr %current_ptr.452, align 8
  br label %label_491

label_489:                                        ; preds = %label_487
  store i1 false, ptr %scanning.453, align 1
  br label %label_491

label_491:                                        ; preds = %label_490, %label_489
  br label %label_486
}

define ptr @create_node__Enum_NodeKind(i32 %0) {
entry:
  %kind.456 = alloca i32, align 4
  store i32 %0, ptr %kind.456, align 4
  %1 = call ptr @malloc(i64 ptrtoint (ptr getelementptr (%ASTNode, ptr null, i32 1) to i64))
  %2 = load i32, ptr %kind.456, align 4
  %3 = getelementptr inbounds nuw %ASTNode, ptr %1, i32 0, i32 0
  store i32 %2, ptr %3, align 4
  %4 = getelementptr inbounds nuw %ASTNode, ptr %1, i32 0, i32 1
  store ptr @.str.s65, ptr %4, align 8
  %5 = getelementptr inbounds nuw %ASTNode, ptr %1, i32 0, i32 2
  store ptr @.str.s66, ptr %5, align 8
  %6 = getelementptr inbounds nuw %ASTNode, ptr %1, i32 0, i32 3
  store i32 0, ptr %6, align 4
  %7 = getelementptr inbounds nuw %ASTNode, ptr %1, i32 0, i32 4
  store i32 0, ptr %7, align 4
  %8 = getelementptr inbounds nuw %ASTNode, ptr %1, i32 0, i32 5
  store ptr @.str.s67, ptr %8, align 8
  %9 = getelementptr inbounds nuw %ASTNode, ptr %1, i32 0, i32 6
  store ptr @.str.s68, ptr %9, align 8
  %10 = getelementptr inbounds nuw %ASTNode, ptr %1, i32 0, i32 7
  store ptr @.str.s69, ptr %10, align 8
  %11 = getelementptr inbounds nuw %ASTNode, ptr %1, i32 0, i32 8
  store ptr @.str.s70, ptr %11, align 8
  %12 = getelementptr inbounds nuw %ASTNode, ptr %1, i32 0, i32 9
  store ptr @.str.s71, ptr %12, align 8
  %13 = getelementptr inbounds nuw %ASTNode, ptr %1, i32 0, i32 10
  store i32 0, ptr %13, align 4
  %14 = getelementptr inbounds nuw %ASTNode, ptr %1, i32 0, i32 11
  store i32 0, ptr %14, align 4
  %15 = getelementptr inbounds nuw %ASTNode, ptr %1, i32 0, i32 12
  store i32 0, ptr %15, align 4
  %16 = getelementptr inbounds nuw %ASTNode, ptr %1, i32 0, i32 13
  store i32 0, ptr %16, align 4
  ret ptr %1
}

define void @node_span_from__Struct_ASTNode_Struct_ASTNode(ptr %0, ptr %1) {
entry:
  %target.457 = alloca ptr, align 8
  store ptr %0, ptr %target.457, align 8
  %source.458 = alloca ptr, align 8
  store ptr %1, ptr %source.458, align 8
  %2 = load ptr, ptr %target.457, align 8
  %3 = load ptr, ptr %source.458, align 8
  %4 = getelementptr inbounds nuw %ASTNode, ptr %3, i32 0, i32 10
  %5 = load i32, ptr %4, align 4
  %6 = getelementptr inbounds nuw %ASTNode, ptr %2, i32 0, i32 10
  store i32 %5, ptr %6, align 4
  %7 = load ptr, ptr %target.457, align 8
  %8 = load ptr, ptr %source.458, align 8
  %9 = getelementptr inbounds nuw %ASTNode, ptr %8, i32 0, i32 11
  %10 = load i32, ptr %9, align 4
  %11 = getelementptr inbounds nuw %ASTNode, ptr %7, i32 0, i32 11
  store i32 %10, ptr %11, align 4
  %12 = load ptr, ptr %target.457, align 8
  %13 = load ptr, ptr %source.458, align 8
  %14 = getelementptr inbounds nuw %ASTNode, ptr %13, i32 0, i32 12
  %15 = load i32, ptr %14, align 4
  %16 = getelementptr inbounds nuw %ASTNode, ptr %12, i32 0, i32 12
  store i32 %15, ptr %16, align 4
  %17 = load ptr, ptr %target.457, align 8
  %18 = load ptr, ptr %source.458, align 8
  %19 = getelementptr inbounds nuw %ASTNode, ptr %18, i32 0, i32 13
  %20 = load i32, ptr %19, align 4
  %21 = getelementptr inbounds nuw %ASTNode, ptr %17, i32 0, i32 13
  store i32 %20, ptr %21, align 4
  ret void
}

define ptr @parser_create__Struct_Token(ptr %0) {
entry:
  %tokens.459 = alloca ptr, align 8
  store ptr %0, ptr %tokens.459, align 8
  %1 = call ptr @malloc(i64 ptrtoint (ptr getelementptr (%Parser, ptr null, i32 1) to i64))
  %2 = load ptr, ptr %tokens.459, align 8
  %3 = call ptr @token_to_ptr(ptr %2)
  %4 = getelementptr inbounds nuw %Parser, ptr %1, i32 0, i32 0
  store ptr %3, ptr %4, align 8
  ret ptr %1
}

define ptr @parser_current__Struct_Parser(ptr %0) {
entry:
  %p.460 = alloca ptr, align 8
  store ptr %0, ptr %p.460, align 8
  %1 = load ptr, ptr %p.460, align 8
  %2 = getelementptr inbounds nuw %Parser, ptr %1, i32 0, i32 0
  %3 = load ptr, ptr %2, align 8
  %4 = call ptr @ptr_to_token(ptr %3)
  ret ptr %4
}

define ptr @parser_peek__Struct_Parser(ptr %0) {
entry:
  %p.461 = alloca ptr, align 8
  store ptr %0, ptr %p.461, align 8
  %1 = load ptr, ptr %p.461, align 8
  %2 = getelementptr inbounds nuw %Parser, ptr %1, i32 0, i32 0
  %3 = load ptr, ptr %2, align 8
  %4 = call ptr @ptr_to_token(ptr %3)
  %curr.462 = alloca ptr, align 8
  store ptr %4, ptr %curr.462, align 8
  %5 = load ptr, ptr %curr.462, align 8
  %6 = getelementptr inbounds nuw %Token, ptr %5, i32 0, i32 6
  %7 = load ptr, ptr %6, align 8
  %8 = call ptr @ptr_to_token(ptr %7)
  ret ptr %8
}

define void @parser_advance__Struct_Parser(ptr %0) {
entry:
  %p.463 = alloca ptr, align 8
  store ptr %0, ptr %p.463, align 8
  %1 = load ptr, ptr %p.463, align 8
  %2 = getelementptr inbounds nuw %Parser, ptr %1, i32 0, i32 0
  %3 = load ptr, ptr %2, align 8
  %4 = call ptr @ptr_to_token(ptr %3)
  %curr.464 = alloca ptr, align 8
  store ptr %4, ptr %curr.464, align 8
  %5 = load ptr, ptr %curr.464, align 8
  %6 = getelementptr inbounds nuw %Token, ptr %5, i32 0, i32 0
  %7 = load i32, ptr %6, align 4
  %8 = icmp ne i32 %7, 20
  br i1 %8, label %label_492, label %label_494

label_494:                                        ; preds = %label_492, %entry
  ret void

label_492:                                        ; preds = %entry
  %9 = load ptr, ptr %p.463, align 8
  %10 = load ptr, ptr %curr.464, align 8
  %11 = getelementptr inbounds nuw %Token, ptr %10, i32 0, i32 6
  %12 = load ptr, ptr %11, align 8
  %13 = getelementptr inbounds nuw %Parser, ptr %9, i32 0, i32 0
  store ptr %12, ptr %13, align 8
  br label %label_494
}

define i1 @parser_check__Struct_Parser_Enum_TokenType(ptr %0, i32 %1) {
entry:
  %p.465 = alloca ptr, align 8
  store ptr %0, ptr %p.465, align 8
  %t.466 = alloca i32, align 4
  store i32 %1, ptr %t.466, align 4
  %2 = load ptr, ptr %p.465, align 8
  %3 = call ptr @parser_current__Struct_Parser(ptr %2)
  %curr.467 = alloca ptr, align 8
  store ptr %3, ptr %curr.467, align 8
  %4 = load ptr, ptr %curr.467, align 8
  %5 = getelementptr inbounds nuw %Token, ptr %4, i32 0, i32 0
  %6 = load i32, ptr %5, align 4
  %7 = load i32, ptr %t.466, align 4
  %8 = icmp eq i32 %6, %7
  ret i1 %8
}

define i1 @parser_check_val__Struct_Parser_Enum_TokenType_String(ptr %0, i32 %1, ptr %2) {
entry:
  %p.468 = alloca ptr, align 8
  store ptr %0, ptr %p.468, align 8
  %t.469 = alloca i32, align 4
  store i32 %1, ptr %t.469, align 4
  %val.470 = alloca ptr, align 8
  store ptr %2, ptr %val.470, align 8
  %3 = load ptr, ptr %p.468, align 8
  %4 = call ptr @parser_current__Struct_Parser(ptr %3)
  %curr.471 = alloca ptr, align 8
  store ptr %4, ptr %curr.471, align 8
  %sc.42 = alloca i1, align 1
  %5 = load ptr, ptr %curr.471, align 8
  %6 = getelementptr inbounds nuw %Token, ptr %5, i32 0, i32 0
  %7 = load i32, ptr %6, align 4
  %8 = load i32, ptr %t.469, align 4
  %9 = icmp eq i32 %7, %8
  store i1 %9, ptr %sc.42, align 1
  br i1 %9, label %label_495, label %label_496

label_496:                                        ; preds = %label_495, %entry
  %10 = load i1, ptr %sc.42, align 1
  ret i1 %10

label_495:                                        ; preds = %entry
  %11 = load ptr, ptr %curr.471, align 8
  %12 = getelementptr inbounds nuw %Token, ptr %11, i32 0, i32 1
  %13 = load ptr, ptr %12, align 8
  %14 = load ptr, ptr %val.470, align 8
  %15 = call i32 @str_equals(ptr %13, ptr %14)
  %16 = icmp eq i32 %15, 1
  store i1 %16, ptr %sc.42, align 1
  br label %label_496
}

define i1 @parser_match__Struct_Parser_Enum_TokenType(ptr %0, i32 %1) {
entry:
  %p.472 = alloca ptr, align 8
  store ptr %0, ptr %p.472, align 8
  %t.473 = alloca i32, align 4
  store i32 %1, ptr %t.473, align 4
  %2 = load ptr, ptr %p.472, align 8
  %3 = load i32, ptr %t.473, align 4
  %4 = call i1 @parser_check__Struct_Parser_Enum_TokenType(ptr %2, i32 %3)
  br i1 %4, label %label_497, label %label_499

label_499:                                        ; preds = %entry
  ret i1 false

label_497:                                        ; preds = %entry
  %5 = load ptr, ptr %p.472, align 8
  call void @parser_advance__Struct_Parser(ptr %5)
  ret i1 true
}

define i1 @parser_match_val__Struct_Parser_Enum_TokenType_String(ptr %0, i32 %1, ptr %2) {
entry:
  %p.474 = alloca ptr, align 8
  store ptr %0, ptr %p.474, align 8
  %t.475 = alloca i32, align 4
  store i32 %1, ptr %t.475, align 4
  %val.476 = alloca ptr, align 8
  store ptr %2, ptr %val.476, align 8
  %3 = load ptr, ptr %p.474, align 8
  %4 = load i32, ptr %t.475, align 4
  %5 = load ptr, ptr %val.476, align 8
  %6 = call i1 @parser_check_val__Struct_Parser_Enum_TokenType_String(ptr %3, i32 %4, ptr %5)
  br i1 %6, label %label_500, label %label_502

label_502:                                        ; preds = %entry
  ret i1 false

label_500:                                        ; preds = %entry
  %7 = load ptr, ptr %p.474, align 8
  call void @parser_advance__Struct_Parser(ptr %7)
  ret i1 true
}

define ptr @parser_node__Struct_Parser_Enum_NodeKind(ptr %0, i32 %1) {
entry:
  %p.477 = alloca ptr, align 8
  store ptr %0, ptr %p.477, align 8
  %kind.478 = alloca i32, align 4
  store i32 %1, ptr %kind.478, align 4
  %2 = load i32, ptr %kind.478, align 4
  %3 = call ptr @create_node__Enum_NodeKind(i32 %2)
  %node.479 = alloca ptr, align 8
  store ptr %3, ptr %node.479, align 8
  %4 = load ptr, ptr %p.477, align 8
  %5 = call ptr @parser_current__Struct_Parser(ptr %4)
  %tok.480 = alloca ptr, align 8
  store ptr %5, ptr %tok.480, align 8
  %6 = load ptr, ptr %node.479, align 8
  %7 = load ptr, ptr %tok.480, align 8
  %8 = getelementptr inbounds nuw %Token, ptr %7, i32 0, i32 2
  %9 = load i32, ptr %8, align 4
  %10 = getelementptr inbounds nuw %ASTNode, ptr %6, i32 0, i32 10
  store i32 %9, ptr %10, align 4
  %11 = load ptr, ptr %node.479, align 8
  %12 = load ptr, ptr %tok.480, align 8
  %13 = getelementptr inbounds nuw %Token, ptr %12, i32 0, i32 3
  %14 = load i32, ptr %13, align 4
  %15 = getelementptr inbounds nuw %ASTNode, ptr %11, i32 0, i32 11
  store i32 %14, ptr %15, align 4
  %16 = load ptr, ptr %node.479, align 8
  %17 = load ptr, ptr %tok.480, align 8
  %18 = getelementptr inbounds nuw %Token, ptr %17, i32 0, i32 4
  %19 = load i32, ptr %18, align 4
  %20 = getelementptr inbounds nuw %ASTNode, ptr %16, i32 0, i32 12
  store i32 %19, ptr %20, align 4
  %21 = load ptr, ptr %node.479, align 8
  %22 = load ptr, ptr %tok.480, align 8
  %23 = getelementptr inbounds nuw %Token, ptr %22, i32 0, i32 5
  %24 = load i32, ptr %23, align 4
  %25 = getelementptr inbounds nuw %ASTNode, ptr %21, i32 0, i32 13
  store i32 %24, ptr %25, align 4
  %26 = load ptr, ptr %node.479, align 8
  ret ptr %26
}

define void @parser_error__Struct_Parser_String(ptr %0, ptr %1) {
entry:
  %p.481 = alloca ptr, align 8
  store ptr %0, ptr %p.481, align 8
  %message.482 = alloca ptr, align 8
  store ptr %1, ptr %message.482, align 8
  %2 = load ptr, ptr %p.481, align 8
  %3 = call ptr @parser_current__Struct_Parser(ptr %2)
  %tok.483 = alloca ptr, align 8
  store ptr %3, ptr %tok.483, align 8
  %4 = load ptr, ptr %tok.483, align 8
  %5 = getelementptr inbounds nuw %Token, ptr %4, i32 0, i32 5
  %6 = load i32, ptr %5, align 4
  %7 = load ptr, ptr %tok.483, align 8
  %8 = getelementptr inbounds nuw %Token, ptr %7, i32 0, i32 2
  %9 = load i32, ptr %8, align 4
  %10 = load ptr, ptr %tok.483, align 8
  %11 = getelementptr inbounds nuw %Token, ptr %10, i32 0, i32 3
  %12 = load i32, ptr %11, align 4
  %13 = load ptr, ptr %tok.483, align 8
  %14 = getelementptr inbounds nuw %Token, ptr %13, i32 0, i32 4
  %15 = load i32, ptr %14, align 4
  %16 = load ptr, ptr %message.482, align 8
  call void @diag_error_at(i32 %6, i32 %9, i32 %12, i32 %15, ptr %16)
  ret void
}

define ptr @parser_describe__Struct_Token(ptr %0) {
entry:
  %tok.484 = alloca ptr, align 8
  store ptr %0, ptr %tok.484, align 8
  %1 = load ptr, ptr %tok.484, align 8
  %2 = getelementptr inbounds nuw %Token, ptr %1, i32 0, i32 0
  %3 = load i32, ptr %2, align 4
  %4 = icmp eq i32 %3, 20
  br i1 %4, label %label_503, label %label_505

label_505:                                        ; preds = %entry
  %5 = load ptr, ptr %tok.484, align 8
  %6 = getelementptr inbounds nuw %Token, ptr %5, i32 0, i32 1
  %7 = load ptr, ptr %6, align 8
  %8 = call ptr @diag_quote__String(ptr %7)
  ret ptr %8

label_503:                                        ; preds = %entry
  ret ptr @.str.s72
}

define void @parser_synchronize__Struct_Parser(ptr %0) {
entry:
  %p.485 = alloca ptr, align 8
  store ptr %0, ptr %p.485, align 8
  %1 = load ptr, ptr %p.485, align 8
  call void @parser_advance__Struct_Parser(ptr %1)
  %scanning.486 = alloca i1, align 1
  store i1 true, ptr %scanning.486, align 1
  %tok.487 = alloca ptr, align 8
  %sc.43 = alloca i1, align 1
  %sc.44 = alloca i1, align 1
  %sc.45 = alloca i1, align 1
  %sc.46 = alloca i1, align 1
  %sc.47 = alloca i1, align 1
  %sc.48 = alloca i1, align 1
  %sc.49 = alloca i1, align 1
  %sc.50 = alloca i1, align 1
  %sc.51 = alloca i1, align 1
  %sc.52 = alloca i1, align 1
  %sc.53 = alloca i1, align 1
  %sc.54 = alloca i1, align 1
  %sc.55 = alloca i1, align 1
  %sc.56 = alloca i1, align 1
  br label %label_506

label_506:                                        ; preds = %label_511, %entry
  %2 = load i1, ptr %scanning.486, align 1
  br i1 %2, label %label_507, label %label_508

label_508:                                        ; preds = %label_506
  ret void

label_507:                                        ; preds = %label_506
  %3 = load ptr, ptr %p.485, align 8
  %4 = call ptr @parser_current__Struct_Parser(ptr %3)
  store ptr %4, ptr %tok.487, align 8
  %5 = load ptr, ptr %tok.487, align 8
  %6 = getelementptr inbounds nuw %Token, ptr %5, i32 0, i32 0
  %7 = load i32, ptr %6, align 4
  %8 = icmp eq i32 %7, 20
  br i1 %8, label %label_509, label %label_510

label_510:                                        ; preds = %label_507
  %9 = load ptr, ptr %tok.487, align 8
  %10 = getelementptr inbounds nuw %Token, ptr %9, i32 0, i32 0
  %11 = load i32, ptr %10, align 4
  %12 = icmp eq i32 %11, 6
  store i1 %12, ptr %sc.43, align 1
  br i1 %12, label %label_512, label %label_513

label_509:                                        ; preds = %label_507
  store i1 false, ptr %scanning.486, align 1
  br label %label_511

label_511:                                        ; preds = %label_516, %label_509
  br label %label_506

label_513:                                        ; preds = %label_512, %label_510
  %13 = load i1, ptr %sc.43, align 1
  br i1 %13, label %label_514, label %label_515

label_512:                                        ; preds = %label_510
  %14 = load ptr, ptr %tok.487, align 8
  %15 = getelementptr inbounds nuw %Token, ptr %14, i32 0, i32 1
  %16 = load ptr, ptr %15, align 8
  %17 = call i32 @str_equals(ptr %16, ptr @.str.s73)
  %18 = icmp eq i32 %17, 1
  store i1 %18, ptr %sc.43, align 1
  br label %label_513

label_515:                                        ; preds = %label_513
  %19 = load ptr, ptr %tok.487, align 8
  %20 = getelementptr inbounds nuw %Token, ptr %19, i32 0, i32 0
  %21 = load i32, ptr %20, align 4
  %22 = icmp eq i32 %21, 18
  br i1 %22, label %label_517, label %label_518

label_514:                                        ; preds = %label_513
  store i1 false, ptr %scanning.486, align 1
  br label %label_516

label_516:                                        ; preds = %label_519, %label_514
  br label %label_511

label_518:                                        ; preds = %label_515
  %23 = load ptr, ptr %p.485, align 8
  call void @parser_advance__Struct_Parser(ptr %23)
  br label %label_519

label_517:                                        ; preds = %label_515
  %24 = load ptr, ptr %tok.487, align 8
  %25 = getelementptr inbounds nuw %Token, ptr %24, i32 0, i32 1
  %26 = load ptr, ptr %25, align 8
  %27 = call i32 @str_equals(ptr %26, ptr @.str.s74)
  %28 = icmp eq i32 %27, 1
  store i1 %28, ptr %sc.56, align 1
  br i1 %28, label %label_545, label %label_544

label_544:                                        ; preds = %label_517
  %29 = load ptr, ptr %tok.487, align 8
  %30 = getelementptr inbounds nuw %Token, ptr %29, i32 0, i32 1
  %31 = load ptr, ptr %30, align 8
  %32 = call i32 @str_equals(ptr %31, ptr @.str.s75)
  %33 = icmp eq i32 %32, 1
  store i1 %33, ptr %sc.56, align 1
  br label %label_545

label_545:                                        ; preds = %label_544, %label_517
  %34 = load i1, ptr %sc.56, align 1
  store i1 %34, ptr %sc.55, align 1
  br i1 %34, label %label_543, label %label_542

label_542:                                        ; preds = %label_545
  %35 = load ptr, ptr %tok.487, align 8
  %36 = getelementptr inbounds nuw %Token, ptr %35, i32 0, i32 1
  %37 = load ptr, ptr %36, align 8
  %38 = call i32 @str_equals(ptr %37, ptr @.str.s76)
  %39 = icmp eq i32 %38, 1
  store i1 %39, ptr %sc.55, align 1
  br label %label_543

label_543:                                        ; preds = %label_542, %label_545
  %40 = load i1, ptr %sc.55, align 1
  store i1 %40, ptr %sc.54, align 1
  br i1 %40, label %label_541, label %label_540

label_540:                                        ; preds = %label_543
  %41 = load ptr, ptr %tok.487, align 8
  %42 = getelementptr inbounds nuw %Token, ptr %41, i32 0, i32 1
  %43 = load ptr, ptr %42, align 8
  %44 = call i32 @str_equals(ptr %43, ptr @.str.s77)
  %45 = icmp eq i32 %44, 1
  store i1 %45, ptr %sc.54, align 1
  br label %label_541

label_541:                                        ; preds = %label_540, %label_543
  %46 = load i1, ptr %sc.54, align 1
  store i1 %46, ptr %sc.53, align 1
  br i1 %46, label %label_539, label %label_538

label_538:                                        ; preds = %label_541
  %47 = load ptr, ptr %tok.487, align 8
  %48 = getelementptr inbounds nuw %Token, ptr %47, i32 0, i32 1
  %49 = load ptr, ptr %48, align 8
  %50 = call i32 @str_equals(ptr %49, ptr @.str.s78)
  %51 = icmp eq i32 %50, 1
  store i1 %51, ptr %sc.53, align 1
  br label %label_539

label_539:                                        ; preds = %label_538, %label_541
  %52 = load i1, ptr %sc.53, align 1
  store i1 %52, ptr %sc.52, align 1
  br i1 %52, label %label_537, label %label_536

label_536:                                        ; preds = %label_539
  %53 = load ptr, ptr %tok.487, align 8
  %54 = getelementptr inbounds nuw %Token, ptr %53, i32 0, i32 1
  %55 = load ptr, ptr %54, align 8
  %56 = call i32 @str_equals(ptr %55, ptr @.str.s79)
  %57 = icmp eq i32 %56, 1
  store i1 %57, ptr %sc.52, align 1
  br label %label_537

label_537:                                        ; preds = %label_536, %label_539
  %58 = load i1, ptr %sc.52, align 1
  store i1 %58, ptr %sc.51, align 1
  br i1 %58, label %label_535, label %label_534

label_534:                                        ; preds = %label_537
  %59 = load ptr, ptr %tok.487, align 8
  %60 = getelementptr inbounds nuw %Token, ptr %59, i32 0, i32 1
  %61 = load ptr, ptr %60, align 8
  %62 = call i32 @str_equals(ptr %61, ptr @.str.s80)
  %63 = icmp eq i32 %62, 1
  store i1 %63, ptr %sc.51, align 1
  br label %label_535

label_535:                                        ; preds = %label_534, %label_537
  %64 = load i1, ptr %sc.51, align 1
  store i1 %64, ptr %sc.50, align 1
  br i1 %64, label %label_533, label %label_532

label_532:                                        ; preds = %label_535
  %65 = load ptr, ptr %tok.487, align 8
  %66 = getelementptr inbounds nuw %Token, ptr %65, i32 0, i32 1
  %67 = load ptr, ptr %66, align 8
  %68 = call i32 @str_equals(ptr %67, ptr @.str.s81)
  %69 = icmp eq i32 %68, 1
  store i1 %69, ptr %sc.50, align 1
  br label %label_533

label_533:                                        ; preds = %label_532, %label_535
  %70 = load i1, ptr %sc.50, align 1
  store i1 %70, ptr %sc.49, align 1
  br i1 %70, label %label_531, label %label_530

label_530:                                        ; preds = %label_533
  %71 = load ptr, ptr %tok.487, align 8
  %72 = getelementptr inbounds nuw %Token, ptr %71, i32 0, i32 1
  %73 = load ptr, ptr %72, align 8
  %74 = call i32 @str_equals(ptr %73, ptr @.str.s82)
  %75 = icmp eq i32 %74, 1
  store i1 %75, ptr %sc.49, align 1
  br label %label_531

label_531:                                        ; preds = %label_530, %label_533
  %76 = load i1, ptr %sc.49, align 1
  store i1 %76, ptr %sc.48, align 1
  br i1 %76, label %label_529, label %label_528

label_528:                                        ; preds = %label_531
  %77 = load ptr, ptr %tok.487, align 8
  %78 = getelementptr inbounds nuw %Token, ptr %77, i32 0, i32 1
  %79 = load ptr, ptr %78, align 8
  %80 = call i32 @str_equals(ptr %79, ptr @.str.s83)
  %81 = icmp eq i32 %80, 1
  store i1 %81, ptr %sc.48, align 1
  br label %label_529

label_529:                                        ; preds = %label_528, %label_531
  %82 = load i1, ptr %sc.48, align 1
  store i1 %82, ptr %sc.47, align 1
  br i1 %82, label %label_527, label %label_526

label_526:                                        ; preds = %label_529
  %83 = load ptr, ptr %tok.487, align 8
  %84 = getelementptr inbounds nuw %Token, ptr %83, i32 0, i32 1
  %85 = load ptr, ptr %84, align 8
  %86 = call i32 @str_equals(ptr %85, ptr @.str.s84)
  %87 = icmp eq i32 %86, 1
  store i1 %87, ptr %sc.47, align 1
  br label %label_527

label_527:                                        ; preds = %label_526, %label_529
  %88 = load i1, ptr %sc.47, align 1
  store i1 %88, ptr %sc.46, align 1
  br i1 %88, label %label_525, label %label_524

label_524:                                        ; preds = %label_527
  %89 = load ptr, ptr %tok.487, align 8
  %90 = getelementptr inbounds nuw %Token, ptr %89, i32 0, i32 1
  %91 = load ptr, ptr %90, align 8
  %92 = call i32 @str_equals(ptr %91, ptr @.str.s85)
  %93 = icmp eq i32 %92, 1
  store i1 %93, ptr %sc.46, align 1
  br label %label_525

label_525:                                        ; preds = %label_524, %label_527
  %94 = load i1, ptr %sc.46, align 1
  store i1 %94, ptr %sc.45, align 1
  br i1 %94, label %label_523, label %label_522

label_522:                                        ; preds = %label_525
  %95 = load ptr, ptr %tok.487, align 8
  %96 = getelementptr inbounds nuw %Token, ptr %95, i32 0, i32 1
  %97 = load ptr, ptr %96, align 8
  %98 = call i32 @str_equals(ptr %97, ptr @.str.s86)
  %99 = icmp eq i32 %98, 1
  store i1 %99, ptr %sc.45, align 1
  br label %label_523

label_523:                                        ; preds = %label_522, %label_525
  %100 = load i1, ptr %sc.45, align 1
  store i1 %100, ptr %sc.44, align 1
  br i1 %100, label %label_521, label %label_520

label_520:                                        ; preds = %label_523
  %101 = load ptr, ptr %tok.487, align 8
  %102 = getelementptr inbounds nuw %Token, ptr %101, i32 0, i32 1
  %103 = load ptr, ptr %102, align 8
  %104 = call i32 @str_equals(ptr %103, ptr @.str.s87)
  %105 = icmp eq i32 %104, 1
  store i1 %105, ptr %sc.44, align 1
  br label %label_521

label_521:                                        ; preds = %label_520, %label_523
  %106 = load i1, ptr %sc.44, align 1
  br i1 %106, label %label_546, label %label_547

label_547:                                        ; preds = %label_521
  %107 = load ptr, ptr %p.485, align 8
  call void @parser_advance__Struct_Parser(ptr %107)
  br label %label_548

label_546:                                        ; preds = %label_521
  store i1 false, ptr %scanning.486, align 1
  br label %label_548

label_548:                                        ; preds = %label_547, %label_546
  br label %label_519

label_519:                                        ; preds = %label_518, %label_548
  br label %label_516
}

define void @parser_fatal__Struct_Parser_String(ptr %0, ptr %1) {
entry:
  %p.488 = alloca ptr, align 8
  store ptr %0, ptr %p.488, align 8
  %message.489 = alloca ptr, align 8
  store ptr %1, ptr %message.489, align 8
  %2 = load ptr, ptr %p.488, align 8
  %3 = load ptr, ptr %message.489, align 8
  call void @parser_error__Struct_Parser_String(ptr %2, ptr %3)
  call void @diag_finish()
  call void @exit(i32 1)
  ret void
}

define void @parser_expect__Struct_Parser_Enum_TokenType_String(ptr %0, i32 %1, ptr %2) {
entry:
  %p.490 = alloca ptr, align 8
  store ptr %0, ptr %p.490, align 8
  %t.491 = alloca i32, align 4
  store i32 %1, ptr %t.491, align 4
  %context.492 = alloca ptr, align 8
  store ptr %2, ptr %context.492, align 8
  %3 = load ptr, ptr %p.490, align 8
  %4 = load i32, ptr %t.491, align 4
  %5 = call i1 @parser_check__Struct_Parser_Enum_TokenType(ptr %3, i32 %4)
  %6 = icmp eq i1 %5, false
  %tok.493 = alloca ptr, align 8
  br i1 %6, label %label_549, label %label_551

label_551:                                        ; preds = %label_549, %entry
  %7 = load ptr, ptr %p.490, align 8
  call void @parser_advance__Struct_Parser(ptr %7)
  ret void

label_549:                                        ; preds = %entry
  %8 = load ptr, ptr %p.490, align 8
  %9 = call ptr @parser_current__Struct_Parser(ptr %8)
  store ptr %9, ptr %tok.493, align 8
  %10 = load ptr, ptr %p.490, align 8
  %11 = load i32, ptr %t.491, align 4
  %12 = call ptr @type_to_string__Enum_TokenType(i32 %11)
  %13 = call ptr @str_concat(ptr @.str.s88, ptr %12)
  %14 = load ptr, ptr %context.492, align 8
  %15 = call ptr @str_concat(ptr @.str.s89, ptr %14)
  %16 = call ptr @str_concat(ptr %13, ptr %15)
  %17 = load ptr, ptr %tok.493, align 8
  %18 = call ptr @parser_describe__Struct_Token(ptr %17)
  %19 = call ptr @str_concat(ptr @.str.s90, ptr %18)
  %20 = call ptr @str_concat(ptr %16, ptr %19)
  call void @parser_fatal__Struct_Parser_String(ptr %10, ptr %20)
  br label %label_551
}

define void @parser_expect_val__Struct_Parser_Enum_TokenType_String_String(ptr %0, i32 %1, ptr %2, ptr %3) {
entry:
  %p.494 = alloca ptr, align 8
  store ptr %0, ptr %p.494, align 8
  %t.495 = alloca i32, align 4
  store i32 %1, ptr %t.495, align 4
  %val.496 = alloca ptr, align 8
  store ptr %2, ptr %val.496, align 8
  %context.497 = alloca ptr, align 8
  store ptr %3, ptr %context.497, align 8
  %4 = load ptr, ptr %p.494, align 8
  %5 = load i32, ptr %t.495, align 4
  %6 = load ptr, ptr %val.496, align 8
  %7 = call i1 @parser_check_val__Struct_Parser_Enum_TokenType_String(ptr %4, i32 %5, ptr %6)
  %8 = icmp eq i1 %7, false
  %tok.498 = alloca ptr, align 8
  br i1 %8, label %label_552, label %label_554

label_554:                                        ; preds = %label_552, %entry
  %9 = load ptr, ptr %p.494, align 8
  call void @parser_advance__Struct_Parser(ptr %9)
  ret void

label_552:                                        ; preds = %entry
  %10 = load ptr, ptr %p.494, align 8
  %11 = call ptr @parser_current__Struct_Parser(ptr %10)
  store ptr %11, ptr %tok.498, align 8
  %12 = load ptr, ptr %p.494, align 8
  %13 = load ptr, ptr %val.496, align 8
  %14 = call ptr @diag_quote__String(ptr %13)
  %15 = call ptr @str_concat(ptr @.str.s91, ptr %14)
  %16 = load ptr, ptr %context.497, align 8
  %17 = call ptr @str_concat(ptr @.str.s92, ptr %16)
  %18 = call ptr @str_concat(ptr %15, ptr %17)
  %19 = load ptr, ptr %tok.498, align 8
  %20 = call ptr @parser_describe__Struct_Token(ptr %19)
  %21 = call ptr @str_concat(ptr @.str.s93, ptr %20)
  %22 = call ptr @str_concat(ptr %18, ptr %21)
  call void @parser_fatal__Struct_Parser_String(ptr %12, ptr %22)
  br label %label_554
}

define ptr @parse_import_statement__Struct_Parser(ptr %0) {
entry:
  %p.499 = alloca ptr, align 8
  store ptr %0, ptr %p.499, align 8
  %1 = load ptr, ptr %p.499, align 8
  call void @parser_expect_val__Struct_Parser_Enum_TokenType_String_String(ptr %1, i32 18, ptr @.str.s94, ptr @.str.s95)
  %2 = load ptr, ptr %p.499, align 8
  %3 = call ptr @parser_node__Struct_Parser_Enum_NodeKind(ptr %2, i32 1)
  %import_node.500 = alloca ptr, align 8
  store ptr %3, ptr %import_node.500, align 8
  %4 = load ptr, ptr %p.499, align 8
  %5 = call ptr @parser_current__Struct_Parser(ptr %4)
  %curr.501 = alloca ptr, align 8
  store ptr %5, ptr %curr.501, align 8
  %6 = load ptr, ptr %import_node.500, align 8
  %7 = load ptr, ptr %curr.501, align 8
  %8 = getelementptr inbounds nuw %Token, ptr %7, i32 0, i32 1
  %9 = load ptr, ptr %8, align 8
  %10 = getelementptr inbounds nuw %ASTNode, ptr %6, i32 0, i32 1
  store ptr %9, ptr %10, align 8
  %sc.57 = alloca i1, align 1
  %11 = load ptr, ptr %curr.501, align 8
  %12 = getelementptr inbounds nuw %Token, ptr %11, i32 0, i32 0
  %13 = load i32, ptr %12, align 4
  %14 = icmp eq i32 %13, 5
  store i1 %14, ptr %sc.57, align 1
  br i1 %14, label %label_556, label %label_555

label_555:                                        ; preds = %entry
  %15 = load ptr, ptr %curr.501, align 8
  %16 = getelementptr inbounds nuw %Token, ptr %15, i32 0, i32 0
  %17 = load i32, ptr %16, align 4
  %18 = icmp eq i32 %17, 18
  store i1 %18, ptr %sc.57, align 1
  br label %label_556

label_556:                                        ; preds = %label_555, %entry
  %19 = load i1, ptr %sc.57, align 1
  br i1 %19, label %label_557, label %label_558

label_558:                                        ; preds = %label_556
  %20 = load ptr, ptr %p.499, align 8
  %21 = load ptr, ptr %curr.501, align 8
  %22 = call ptr @parser_describe__Struct_Token(ptr %21)
  %23 = call ptr @str_concat(ptr @.str.s96, ptr %22)
  call void @parser_fatal__Struct_Parser_String(ptr %20, ptr %23)
  br label %label_559

label_557:                                        ; preds = %label_556
  %24 = load ptr, ptr %p.499, align 8
  call void @parser_advance__Struct_Parser(ptr %24)
  br label %label_559

label_559:                                        ; preds = %label_558, %label_557
  %25 = load ptr, ptr %import_node.500, align 8
  ret ptr %25
}

define ptr @parse_declaration__Struct_Parser(ptr %0) {
entry:
  %p.502 = alloca ptr, align 8
  store ptr %0, ptr %p.502, align 8
  %1 = load ptr, ptr %p.502, align 8
  %2 = call i1 @parser_check_val__Struct_Parser_Enum_TokenType_String(ptr %1, i32 18, ptr @.str.s97)
  %bad.503 = alloca ptr, align 8
  %curr.504 = alloca ptr, align 8
  br i1 %2, label %label_560, label %label_562

label_562:                                        ; preds = %entry
  %3 = load ptr, ptr %p.502, align 8
  %4 = call i1 @parser_check_val__Struct_Parser_Enum_TokenType_String(ptr %3, i32 18, ptr @.str.s98)
  br i1 %4, label %label_563, label %label_565

label_560:                                        ; preds = %entry
  %5 = load ptr, ptr %p.502, align 8
  %6 = call ptr @parse_import_statement__Struct_Parser(ptr %5)
  ret ptr %6

label_565:                                        ; preds = %label_562
  %7 = load ptr, ptr %p.502, align 8
  %8 = call i1 @parser_check_val__Struct_Parser_Enum_TokenType_String(ptr %7, i32 18, ptr @.str.s99)
  br i1 %8, label %label_566, label %label_568

label_563:                                        ; preds = %label_562
  %9 = load ptr, ptr %p.502, align 8
  %10 = call ptr @parse_variable_decl__Struct_Parser(ptr %9)
  ret ptr %10

label_568:                                        ; preds = %label_565
  %11 = load ptr, ptr %p.502, align 8
  %12 = call i1 @parser_check_val__Struct_Parser_Enum_TokenType_String(ptr %11, i32 18, ptr @.str.s100)
  br i1 %12, label %label_569, label %label_571

label_566:                                        ; preds = %label_565
  %13 = load ptr, ptr %p.502, align 8
  %14 = call ptr @parse_extern_fn_decl__Struct_Parser(ptr %13)
  ret ptr %14

label_571:                                        ; preds = %label_568
  %15 = load ptr, ptr %p.502, align 8
  %16 = call i1 @parser_check_val__Struct_Parser_Enum_TokenType_String(ptr %15, i32 18, ptr @.str.s101)
  br i1 %16, label %label_572, label %label_574

label_569:                                        ; preds = %label_568
  %17 = load ptr, ptr %p.502, align 8
  %18 = call ptr @parse_function_decl__Struct_Parser(ptr %17)
  ret ptr %18

label_574:                                        ; preds = %label_571
  %19 = load ptr, ptr %p.502, align 8
  %20 = call i1 @parser_check_val__Struct_Parser_Enum_TokenType_String(ptr %19, i32 18, ptr @.str.s102)
  br i1 %20, label %label_575, label %label_577

label_572:                                        ; preds = %label_571
  %21 = load ptr, ptr %p.502, align 8
  %22 = call ptr @parse_struct_decl__Struct_Parser(ptr %21)
  ret ptr %22

label_577:                                        ; preds = %label_574
  %23 = load ptr, ptr %p.502, align 8
  %24 = call ptr @parser_node__Struct_Parser_Enum_NodeKind(ptr %23, i32 35)
  store ptr %24, ptr %bad.503, align 8
  %25 = load ptr, ptr %p.502, align 8
  %26 = call ptr @parser_current__Struct_Parser(ptr %25)
  store ptr %26, ptr %curr.504, align 8
  %27 = load ptr, ptr %p.502, align 8
  %28 = load ptr, ptr %curr.504, align 8
  %29 = call ptr @parser_describe__Struct_Token(ptr %28)
  %30 = call ptr @str_concat(ptr @.str.s103, ptr %29)
  %31 = call ptr @str_concat(ptr %30, ptr @.str.s104)
  call void @parser_error__Struct_Parser_String(ptr %27, ptr %31)
  %32 = load ptr, ptr %p.502, align 8
  call void @parser_synchronize__Struct_Parser(ptr %32)
  %33 = load ptr, ptr %bad.503, align 8
  ret ptr %33

label_575:                                        ; preds = %label_574
  %34 = load ptr, ptr %p.502, align 8
  %35 = call ptr @parse_enum_decl__Struct_Parser(ptr %34)
  ret ptr %35
}

define ptr @parse_variable_decl__Struct_Parser(ptr %0) {
entry:
  %p.511 = alloca ptr, align 8
  store ptr %0, ptr %p.511, align 8
  %1 = load ptr, ptr %p.511, align 8
  call void @parser_expect_val__Struct_Parser_Enum_TokenType_String_String(ptr %1, i32 18, ptr @.str.s115, ptr @.str.s116)
  %2 = load ptr, ptr %p.511, align 8
  %3 = call ptr @parser_node__Struct_Parser_Enum_NodeKind(ptr %2, i32 3)
  %var_node.512 = alloca ptr, align 8
  store ptr %3, ptr %var_node.512, align 8
  %4 = load ptr, ptr %p.511, align 8
  %5 = call i1 @parser_match_val__Struct_Parser_Enum_TokenType_String(ptr %4, i32 18, ptr @.str.s117)
  %curr.513 = alloca ptr, align 8
  br i1 %5, label %label_594, label %label_596

label_596:                                        ; preds = %label_594, %entry
  %6 = load ptr, ptr %p.511, align 8
  %7 = call ptr @parser_current__Struct_Parser(ptr %6)
  store ptr %7, ptr %curr.513, align 8
  %8 = load ptr, ptr %var_node.512, align 8
  %9 = load ptr, ptr %curr.513, align 8
  %10 = getelementptr inbounds nuw %Token, ptr %9, i32 0, i32 1
  %11 = load ptr, ptr %10, align 8
  %12 = getelementptr inbounds nuw %ASTNode, ptr %8, i32 0, i32 1
  store ptr %11, ptr %12, align 8
  %13 = load ptr, ptr %p.511, align 8
  call void @parser_expect__Struct_Parser_Enum_TokenType_String(ptr %13, i32 5, ptr @.str.s118)
  %14 = load ptr, ptr %p.511, align 8
  %15 = call i1 @parser_match_val__Struct_Parser_Enum_TokenType_String(ptr %14, i32 6, ptr @.str.s119)
  br i1 %15, label %label_597, label %label_599

label_594:                                        ; preds = %entry
  %16 = load ptr, ptr %var_node.512, align 8
  %17 = getelementptr inbounds nuw %ASTNode, ptr %16, i32 0, i32 3
  store i32 1, ptr %17, align 4
  br label %label_596

label_599:                                        ; preds = %label_597, %label_596
  %18 = load ptr, ptr %p.511, align 8
  %19 = call i1 @parser_match_val__Struct_Parser_Enum_TokenType_String(ptr %18, i32 12, ptr @.str.s120)
  br i1 %19, label %label_600, label %label_602

label_597:                                        ; preds = %label_596
  %20 = load ptr, ptr %var_node.512, align 8
  %21 = load ptr, ptr %p.511, align 8
  %22 = call ptr @parse_type_annotation__Struct_Parser(ptr %21)
  %23 = call ptr @node_to_ptr(ptr %22)
  %24 = getelementptr inbounds nuw %ASTNode, ptr %20, i32 0, i32 5
  store ptr %23, ptr %24, align 8
  br label %label_599

label_602:                                        ; preds = %label_600, %label_599
  %25 = load ptr, ptr %var_node.512, align 8
  ret ptr %25

label_600:                                        ; preds = %label_599
  %26 = load ptr, ptr %var_node.512, align 8
  %27 = load ptr, ptr %p.511, align 8
  %28 = call ptr @parse_expression__Struct_Parser_Int(ptr %27, i32 0)
  %29 = call ptr @node_to_ptr(ptr %28)
  %30 = getelementptr inbounds nuw %ASTNode, ptr %26, i32 0, i32 6
  store ptr %29, ptr %30, align 8
  br label %label_602
}

define ptr @parse_extern_fn_decl__Struct_Parser(ptr %0) {
entry:
  %p.514 = alloca ptr, align 8
  store ptr %0, ptr %p.514, align 8
  %1 = load ptr, ptr %p.514, align 8
  call void @parser_expect_val__Struct_Parser_Enum_TokenType_String_String(ptr %1, i32 18, ptr @.str.s121, ptr @.str.s122)
  %2 = load ptr, ptr %p.514, align 8
  call void @parser_expect_val__Struct_Parser_Enum_TokenType_String_String(ptr %2, i32 18, ptr @.str.s123, ptr @.str.s124)
  %3 = load ptr, ptr %p.514, align 8
  %4 = call ptr @parser_node__Struct_Parser_Enum_NodeKind(ptr %3, i32 2)
  %ext_node.515 = alloca ptr, align 8
  store ptr %4, ptr %ext_node.515, align 8
  %5 = load ptr, ptr %p.514, align 8
  %6 = call ptr @parser_current__Struct_Parser(ptr %5)
  %curr.516 = alloca ptr, align 8
  store ptr %6, ptr %curr.516, align 8
  %7 = load ptr, ptr %ext_node.515, align 8
  %8 = load ptr, ptr %curr.516, align 8
  %9 = getelementptr inbounds nuw %Token, ptr %8, i32 0, i32 1
  %10 = load ptr, ptr %9, align 8
  %11 = getelementptr inbounds nuw %ASTNode, ptr %7, i32 0, i32 1
  store ptr %10, ptr %11, align 8
  %12 = load ptr, ptr %p.514, align 8
  call void @parser_expect__Struct_Parser_Enum_TokenType_String(ptr %12, i32 5, ptr @.str.s125)
  %13 = load ptr, ptr %p.514, align 8
  call void @parser_expect_val__Struct_Parser_Enum_TokenType_String_String(ptr %13, i32 6, ptr @.str.s126, ptr @.str.s127)
  %last_param.517 = alloca ptr, align 8
  store ptr @.str.s128, ptr %last_param.517, align 8
  %14 = load ptr, ptr %p.514, align 8
  %15 = call i1 @parser_check_val__Struct_Parser_Enum_TokenType_String(ptr %14, i32 6, ptr @.str.s129)
  %16 = icmp eq i1 %15, false
  %is_looping.518 = alloca i1, align 1
  %param.519 = alloca ptr, align 8
  %curr.520 = alloca ptr, align 8
  %last.521 = alloca ptr, align 8
  br i1 %16, label %label_603, label %label_605

label_605:                                        ; preds = %label_608, %entry
  %17 = load ptr, ptr %p.514, align 8
  call void @parser_expect_val__Struct_Parser_Enum_TokenType_String_String(ptr %17, i32 6, ptr @.str.s135, ptr @.str.s136)
  %18 = load ptr, ptr %p.514, align 8
  %19 = call i1 @parser_match_val__Struct_Parser_Enum_TokenType_String(ptr %18, i32 15, ptr @.str.s137)
  br i1 %19, label %label_615, label %label_617

label_603:                                        ; preds = %entry
  store i1 true, ptr %is_looping.518, align 1
  br label %label_606

label_606:                                        ; preds = %label_614, %label_603
  %20 = load i1, ptr %is_looping.518, align 1
  br i1 %20, label %label_607, label %label_608

label_608:                                        ; preds = %label_606
  br label %label_605

label_607:                                        ; preds = %label_606
  %21 = load ptr, ptr %p.514, align 8
  %22 = call ptr @parser_node__Struct_Parser_Enum_NodeKind(ptr %21, i32 30)
  store ptr %22, ptr %param.519, align 8
  %23 = load ptr, ptr %p.514, align 8
  %24 = call ptr @parser_current__Struct_Parser(ptr %23)
  store ptr %24, ptr %curr.520, align 8
  %25 = load ptr, ptr %param.519, align 8
  %26 = load ptr, ptr %curr.520, align 8
  %27 = getelementptr inbounds nuw %Token, ptr %26, i32 0, i32 1
  %28 = load ptr, ptr %27, align 8
  %29 = getelementptr inbounds nuw %ASTNode, ptr %25, i32 0, i32 1
  store ptr %28, ptr %29, align 8
  %30 = load ptr, ptr %p.514, align 8
  call void @parser_expect__Struct_Parser_Enum_TokenType_String(ptr %30, i32 5, ptr @.str.s130)
  %31 = load ptr, ptr %p.514, align 8
  call void @parser_expect_val__Struct_Parser_Enum_TokenType_String_String(ptr %31, i32 6, ptr @.str.s131, ptr @.str.s132)
  %32 = load ptr, ptr %param.519, align 8
  %33 = load ptr, ptr %p.514, align 8
  %34 = call ptr @parse_type_annotation__Struct_Parser(ptr %33)
  %35 = call ptr @node_to_ptr(ptr %34)
  %36 = getelementptr inbounds nuw %ASTNode, ptr %32, i32 0, i32 5
  store ptr %35, ptr %36, align 8
  %37 = load ptr, ptr %ext_node.515, align 8
  %38 = getelementptr inbounds nuw %ASTNode, ptr %37, i32 0, i32 5
  %39 = load ptr, ptr %38, align 8
  %40 = call i32 @str_equals(ptr %39, ptr @.str.s133)
  %41 = icmp eq i32 %40, 1
  br i1 %41, label %label_609, label %label_610

label_610:                                        ; preds = %label_607
  %42 = load ptr, ptr %last_param.517, align 8
  %43 = call ptr @ptr_to_node(ptr %42)
  store ptr %43, ptr %last.521, align 8
  %44 = load ptr, ptr %last.521, align 8
  %45 = load ptr, ptr %param.519, align 8
  %46 = call ptr @node_to_ptr(ptr %45)
  %47 = getelementptr inbounds nuw %ASTNode, ptr %44, i32 0, i32 8
  store ptr %46, ptr %47, align 8
  br label %label_611

label_609:                                        ; preds = %label_607
  %48 = load ptr, ptr %ext_node.515, align 8
  %49 = load ptr, ptr %param.519, align 8
  %50 = call ptr @node_to_ptr(ptr %49)
  %51 = getelementptr inbounds nuw %ASTNode, ptr %48, i32 0, i32 5
  store ptr %50, ptr %51, align 8
  br label %label_611

label_611:                                        ; preds = %label_610, %label_609
  %52 = load ptr, ptr %param.519, align 8
  %53 = call ptr @node_to_ptr(ptr %52)
  store ptr %53, ptr %last_param.517, align 8
  %54 = load ptr, ptr %p.514, align 8
  %55 = call i1 @parser_match_val__Struct_Parser_Enum_TokenType_String(ptr %54, i32 6, ptr @.str.s134)
  %56 = icmp eq i1 %55, false
  br i1 %56, label %label_612, label %label_614

label_614:                                        ; preds = %label_612, %label_611
  br label %label_606

label_612:                                        ; preds = %label_611
  store i1 false, ptr %is_looping.518, align 1
  br label %label_614

label_617:                                        ; preds = %label_615, %label_605
  %57 = load ptr, ptr %ext_node.515, align 8
  ret ptr %57

label_615:                                        ; preds = %label_605
  %58 = load ptr, ptr %ext_node.515, align 8
  %59 = load ptr, ptr %p.514, align 8
  %60 = call ptr @parse_type_annotation__Struct_Parser(ptr %59)
  %61 = call ptr @node_to_ptr(ptr %60)
  %62 = getelementptr inbounds nuw %ASTNode, ptr %58, i32 0, i32 6
  store ptr %61, ptr %62, align 8
  br label %label_617
}

define ptr @parse_function_decl__Struct_Parser(ptr %0) {
entry:
  %p.522 = alloca ptr, align 8
  store ptr %0, ptr %p.522, align 8
  %1 = load ptr, ptr %p.522, align 8
  call void @parser_expect_val__Struct_Parser_Enum_TokenType_String_String(ptr %1, i32 18, ptr @.str.s138, ptr @.str.s139)
  %2 = load ptr, ptr %p.522, align 8
  %3 = call ptr @parser_node__Struct_Parser_Enum_NodeKind(ptr %2, i32 4)
  %fn_node.523 = alloca ptr, align 8
  store ptr %3, ptr %fn_node.523, align 8
  %4 = load ptr, ptr %p.522, align 8
  %5 = call ptr @parser_current__Struct_Parser(ptr %4)
  %curr.524 = alloca ptr, align 8
  store ptr %5, ptr %curr.524, align 8
  %6 = load ptr, ptr %fn_node.523, align 8
  %7 = load ptr, ptr %curr.524, align 8
  %8 = getelementptr inbounds nuw %Token, ptr %7, i32 0, i32 1
  %9 = load ptr, ptr %8, align 8
  %10 = getelementptr inbounds nuw %ASTNode, ptr %6, i32 0, i32 1
  store ptr %9, ptr %10, align 8
  %11 = load ptr, ptr %p.522, align 8
  call void @parser_expect__Struct_Parser_Enum_TokenType_String(ptr %11, i32 5, ptr @.str.s140)
  %12 = load ptr, ptr %p.522, align 8
  call void @parser_expect_val__Struct_Parser_Enum_TokenType_String_String(ptr %12, i32 6, ptr @.str.s141, ptr @.str.s142)
  %last_param.525 = alloca ptr, align 8
  store ptr @.str.s143, ptr %last_param.525, align 8
  %13 = load ptr, ptr %p.522, align 8
  %14 = call i1 @parser_check_val__Struct_Parser_Enum_TokenType_String(ptr %13, i32 6, ptr @.str.s144)
  %15 = icmp eq i1 %14, false
  %is_looping.526 = alloca i1, align 1
  %param.527 = alloca ptr, align 8
  %curr.528 = alloca ptr, align 8
  %last.529 = alloca ptr, align 8
  br i1 %15, label %label_618, label %label_620

label_620:                                        ; preds = %label_623, %entry
  %16 = load ptr, ptr %p.522, align 8
  call void @parser_expect_val__Struct_Parser_Enum_TokenType_String_String(ptr %16, i32 6, ptr @.str.s154, ptr @.str.s155)
  %17 = load ptr, ptr %p.522, align 8
  %18 = call i1 @parser_match_val__Struct_Parser_Enum_TokenType_String(ptr %17, i32 15, ptr @.str.s156)
  br i1 %18, label %label_636, label %label_638

label_618:                                        ; preds = %entry
  store i1 true, ptr %is_looping.526, align 1
  br label %label_621

label_621:                                        ; preds = %label_635, %label_618
  %19 = load i1, ptr %is_looping.526, align 1
  br i1 %19, label %label_622, label %label_623

label_623:                                        ; preds = %label_621
  br label %label_620

label_622:                                        ; preds = %label_621
  %20 = load ptr, ptr %p.522, align 8
  %21 = call ptr @parser_node__Struct_Parser_Enum_NodeKind(ptr %20, i32 30)
  store ptr %21, ptr %param.527, align 8
  %22 = load ptr, ptr %p.522, align 8
  %23 = call i1 @parser_match_val__Struct_Parser_Enum_TokenType_String(ptr %22, i32 18, ptr @.str.s145)
  br i1 %23, label %label_624, label %label_625

label_625:                                        ; preds = %label_622
  %24 = load ptr, ptr %p.522, align 8
  %25 = call i1 @parser_match_val__Struct_Parser_Enum_TokenType_String(ptr %24, i32 18, ptr @.str.s147)
  br i1 %25, label %label_627, label %label_629

label_624:                                        ; preds = %label_622
  %26 = load ptr, ptr %param.527, align 8
  %27 = getelementptr inbounds nuw %ASTNode, ptr %26, i32 0, i32 2
  store ptr @.str.s146, ptr %27, align 8
  br label %label_626

label_626:                                        ; preds = %label_629, %label_624
  %28 = load ptr, ptr %p.522, align 8
  %29 = call ptr @parser_current__Struct_Parser(ptr %28)
  store ptr %29, ptr %curr.528, align 8
  %30 = load ptr, ptr %param.527, align 8
  %31 = load ptr, ptr %curr.528, align 8
  %32 = getelementptr inbounds nuw %Token, ptr %31, i32 0, i32 1
  %33 = load ptr, ptr %32, align 8
  %34 = getelementptr inbounds nuw %ASTNode, ptr %30, i32 0, i32 1
  store ptr %33, ptr %34, align 8
  %35 = load ptr, ptr %p.522, align 8
  call void @parser_expect__Struct_Parser_Enum_TokenType_String(ptr %35, i32 5, ptr @.str.s149)
  %36 = load ptr, ptr %p.522, align 8
  call void @parser_expect_val__Struct_Parser_Enum_TokenType_String_String(ptr %36, i32 6, ptr @.str.s150, ptr @.str.s151)
  %37 = load ptr, ptr %param.527, align 8
  %38 = load ptr, ptr %p.522, align 8
  %39 = call ptr @parse_type_annotation__Struct_Parser(ptr %38)
  %40 = call ptr @node_to_ptr(ptr %39)
  %41 = getelementptr inbounds nuw %ASTNode, ptr %37, i32 0, i32 5
  store ptr %40, ptr %41, align 8
  %42 = load ptr, ptr %fn_node.523, align 8
  %43 = getelementptr inbounds nuw %ASTNode, ptr %42, i32 0, i32 5
  %44 = load ptr, ptr %43, align 8
  %45 = call i32 @str_equals(ptr %44, ptr @.str.s152)
  %46 = icmp eq i32 %45, 1
  br i1 %46, label %label_630, label %label_631

label_629:                                        ; preds = %label_627, %label_625
  br label %label_626

label_627:                                        ; preds = %label_625
  %47 = load ptr, ptr %param.527, align 8
  %48 = getelementptr inbounds nuw %ASTNode, ptr %47, i32 0, i32 2
  store ptr @.str.s148, ptr %48, align 8
  br label %label_629

label_631:                                        ; preds = %label_626
  %49 = load ptr, ptr %last_param.525, align 8
  %50 = call ptr @ptr_to_node(ptr %49)
  store ptr %50, ptr %last.529, align 8
  %51 = load ptr, ptr %last.529, align 8
  %52 = load ptr, ptr %param.527, align 8
  %53 = call ptr @node_to_ptr(ptr %52)
  %54 = getelementptr inbounds nuw %ASTNode, ptr %51, i32 0, i32 8
  store ptr %53, ptr %54, align 8
  br label %label_632

label_630:                                        ; preds = %label_626
  %55 = load ptr, ptr %fn_node.523, align 8
  %56 = load ptr, ptr %param.527, align 8
  %57 = call ptr @node_to_ptr(ptr %56)
  %58 = getelementptr inbounds nuw %ASTNode, ptr %55, i32 0, i32 5
  store ptr %57, ptr %58, align 8
  br label %label_632

label_632:                                        ; preds = %label_631, %label_630
  %59 = load ptr, ptr %param.527, align 8
  %60 = call ptr @node_to_ptr(ptr %59)
  store ptr %60, ptr %last_param.525, align 8
  %61 = load ptr, ptr %p.522, align 8
  %62 = call i1 @parser_match_val__Struct_Parser_Enum_TokenType_String(ptr %61, i32 6, ptr @.str.s153)
  %63 = icmp eq i1 %62, false
  br i1 %63, label %label_633, label %label_635

label_635:                                        ; preds = %label_633, %label_632
  br label %label_621

label_633:                                        ; preds = %label_632
  store i1 false, ptr %is_looping.526, align 1
  br label %label_635

label_638:                                        ; preds = %label_636, %label_620
  %64 = load ptr, ptr %fn_node.523, align 8
  %65 = load ptr, ptr %p.522, align 8
  %66 = call ptr @parse_block__Struct_Parser(ptr %65)
  %67 = call ptr @node_to_ptr(ptr %66)
  %68 = getelementptr inbounds nuw %ASTNode, ptr %64, i32 0, i32 6
  store ptr %67, ptr %68, align 8
  %69 = load ptr, ptr %fn_node.523, align 8
  ret ptr %69

label_636:                                        ; preds = %label_620
  %70 = load ptr, ptr %fn_node.523, align 8
  %71 = load ptr, ptr %p.522, align 8
  %72 = call ptr @parse_type_annotation__Struct_Parser(ptr %71)
  %73 = call ptr @node_to_ptr(ptr %72)
  %74 = getelementptr inbounds nuw %ASTNode, ptr %70, i32 0, i32 7
  store ptr %73, ptr %74, align 8
  br label %label_638
}

define ptr @parse_struct_decl__Struct_Parser(ptr %0) {
entry:
  %p.530 = alloca ptr, align 8
  store ptr %0, ptr %p.530, align 8
  %1 = load ptr, ptr %p.530, align 8
  call void @parser_expect_val__Struct_Parser_Enum_TokenType_String_String(ptr %1, i32 18, ptr @.str.s157, ptr @.str.s158)
  %2 = load ptr, ptr %p.530, align 8
  %3 = call ptr @parser_node__Struct_Parser_Enum_NodeKind(ptr %2, i32 5)
  %struct_node.531 = alloca ptr, align 8
  store ptr %3, ptr %struct_node.531, align 8
  %4 = load ptr, ptr %p.530, align 8
  %5 = call ptr @parser_current__Struct_Parser(ptr %4)
  %curr.532 = alloca ptr, align 8
  store ptr %5, ptr %curr.532, align 8
  %6 = load ptr, ptr %struct_node.531, align 8
  %7 = load ptr, ptr %curr.532, align 8
  %8 = getelementptr inbounds nuw %Token, ptr %7, i32 0, i32 1
  %9 = load ptr, ptr %8, align 8
  %10 = getelementptr inbounds nuw %ASTNode, ptr %6, i32 0, i32 1
  store ptr %9, ptr %10, align 8
  %11 = load ptr, ptr %p.530, align 8
  call void @parser_expect__Struct_Parser_Enum_TokenType_String(ptr %11, i32 5, ptr @.str.s159)
  %12 = load ptr, ptr %p.530, align 8
  call void @parser_expect_val__Struct_Parser_Enum_TokenType_String_String(ptr %12, i32 6, ptr @.str.s160, ptr @.str.s161)
  %last_field.533 = alloca ptr, align 8
  store ptr @.str.s162, ptr %last_field.533, align 8
  %field.534 = alloca ptr, align 8
  %curr.535 = alloca ptr, align 8
  %last.536 = alloca ptr, align 8
  br label %label_639

label_639:                                        ; preds = %label_644, %entry
  %13 = load ptr, ptr %p.530, align 8
  %14 = call i1 @parser_check_val__Struct_Parser_Enum_TokenType_String(ptr %13, i32 6, ptr @.str.s163)
  %15 = icmp eq i1 %14, false
  br i1 %15, label %label_640, label %label_641

label_641:                                        ; preds = %label_639
  %16 = load ptr, ptr %p.530, align 8
  call void @parser_expect_val__Struct_Parser_Enum_TokenType_String_String(ptr %16, i32 6, ptr @.str.s169, ptr @.str.s170)
  %17 = load ptr, ptr %struct_node.531, align 8
  ret ptr %17

label_640:                                        ; preds = %label_639
  %18 = load ptr, ptr %p.530, align 8
  %19 = call ptr @parser_node__Struct_Parser_Enum_NodeKind(ptr %18, i32 32)
  store ptr %19, ptr %field.534, align 8
  %20 = load ptr, ptr %p.530, align 8
  %21 = call ptr @parser_current__Struct_Parser(ptr %20)
  store ptr %21, ptr %curr.535, align 8
  %22 = load ptr, ptr %field.534, align 8
  %23 = load ptr, ptr %curr.535, align 8
  %24 = getelementptr inbounds nuw %Token, ptr %23, i32 0, i32 1
  %25 = load ptr, ptr %24, align 8
  %26 = getelementptr inbounds nuw %ASTNode, ptr %22, i32 0, i32 1
  store ptr %25, ptr %26, align 8
  %27 = load ptr, ptr %p.530, align 8
  call void @parser_expect__Struct_Parser_Enum_TokenType_String(ptr %27, i32 5, ptr @.str.s164)
  %28 = load ptr, ptr %p.530, align 8
  call void @parser_expect_val__Struct_Parser_Enum_TokenType_String_String(ptr %28, i32 6, ptr @.str.s165, ptr @.str.s166)
  %29 = load ptr, ptr %field.534, align 8
  %30 = load ptr, ptr %p.530, align 8
  %31 = call ptr @parse_type_annotation__Struct_Parser(ptr %30)
  %32 = call ptr @node_to_ptr(ptr %31)
  %33 = getelementptr inbounds nuw %ASTNode, ptr %29, i32 0, i32 5
  store ptr %32, ptr %33, align 8
  %34 = load ptr, ptr %struct_node.531, align 8
  %35 = getelementptr inbounds nuw %ASTNode, ptr %34, i32 0, i32 5
  %36 = load ptr, ptr %35, align 8
  %37 = call i32 @str_equals(ptr %36, ptr @.str.s167)
  %38 = icmp eq i32 %37, 1
  br i1 %38, label %label_642, label %label_643

label_643:                                        ; preds = %label_640
  %39 = load ptr, ptr %last_field.533, align 8
  %40 = call ptr @ptr_to_node(ptr %39)
  store ptr %40, ptr %last.536, align 8
  %41 = load ptr, ptr %last.536, align 8
  %42 = load ptr, ptr %field.534, align 8
  %43 = call ptr @node_to_ptr(ptr %42)
  %44 = getelementptr inbounds nuw %ASTNode, ptr %41, i32 0, i32 8
  store ptr %43, ptr %44, align 8
  br label %label_644

label_642:                                        ; preds = %label_640
  %45 = load ptr, ptr %struct_node.531, align 8
  %46 = load ptr, ptr %field.534, align 8
  %47 = call ptr @node_to_ptr(ptr %46)
  %48 = getelementptr inbounds nuw %ASTNode, ptr %45, i32 0, i32 5
  store ptr %47, ptr %48, align 8
  br label %label_644

label_644:                                        ; preds = %label_643, %label_642
  %49 = load ptr, ptr %field.534, align 8
  %50 = call ptr @node_to_ptr(ptr %49)
  store ptr %50, ptr %last_field.533, align 8
  %51 = load ptr, ptr %p.530, align 8
  %52 = call i1 @parser_match_val__Struct_Parser_Enum_TokenType_String(ptr %51, i32 6, ptr @.str.s168)
  br label %label_639
}

define ptr @parse_enum_decl__Struct_Parser(ptr %0) {
entry:
  %p.537 = alloca ptr, align 8
  store ptr %0, ptr %p.537, align 8
  %1 = load ptr, ptr %p.537, align 8
  call void @parser_expect_val__Struct_Parser_Enum_TokenType_String_String(ptr %1, i32 18, ptr @.str.s171, ptr @.str.s172)
  %2 = load ptr, ptr %p.537, align 8
  %3 = call ptr @parser_node__Struct_Parser_Enum_NodeKind(ptr %2, i32 6)
  %enum_node.538 = alloca ptr, align 8
  store ptr %3, ptr %enum_node.538, align 8
  %4 = load ptr, ptr %p.537, align 8
  %5 = call ptr @parser_current__Struct_Parser(ptr %4)
  %curr.539 = alloca ptr, align 8
  store ptr %5, ptr %curr.539, align 8
  %6 = load ptr, ptr %enum_node.538, align 8
  %7 = load ptr, ptr %curr.539, align 8
  %8 = getelementptr inbounds nuw %Token, ptr %7, i32 0, i32 1
  %9 = load ptr, ptr %8, align 8
  %10 = getelementptr inbounds nuw %ASTNode, ptr %6, i32 0, i32 1
  store ptr %9, ptr %10, align 8
  %11 = load ptr, ptr %p.537, align 8
  call void @parser_expect__Struct_Parser_Enum_TokenType_String(ptr %11, i32 5, ptr @.str.s173)
  %12 = load ptr, ptr %p.537, align 8
  call void @parser_expect_val__Struct_Parser_Enum_TokenType_String_String(ptr %12, i32 6, ptr @.str.s174, ptr @.str.s175)
  %last_var.540 = alloca ptr, align 8
  store ptr @.str.s176, ptr %last_var.540, align 8
  %variant.541 = alloca ptr, align 8
  %curr.542 = alloca ptr, align 8
  %last.543 = alloca ptr, align 8
  br label %label_645

label_645:                                        ; preds = %label_650, %entry
  %13 = load ptr, ptr %p.537, align 8
  %14 = call i1 @parser_check_val__Struct_Parser_Enum_TokenType_String(ptr %13, i32 6, ptr @.str.s177)
  %15 = icmp eq i1 %14, false
  br i1 %15, label %label_646, label %label_647

label_647:                                        ; preds = %label_645
  %16 = load ptr, ptr %p.537, align 8
  call void @parser_expect_val__Struct_Parser_Enum_TokenType_String_String(ptr %16, i32 6, ptr @.str.s181, ptr @.str.s182)
  %17 = load ptr, ptr %enum_node.538, align 8
  ret ptr %17

label_646:                                        ; preds = %label_645
  %18 = load ptr, ptr %p.537, align 8
  %19 = call ptr @parser_node__Struct_Parser_Enum_NodeKind(ptr %18, i32 33)
  store ptr %19, ptr %variant.541, align 8
  %20 = load ptr, ptr %p.537, align 8
  %21 = call ptr @parser_current__Struct_Parser(ptr %20)
  store ptr %21, ptr %curr.542, align 8
  %22 = load ptr, ptr %variant.541, align 8
  %23 = load ptr, ptr %curr.542, align 8
  %24 = getelementptr inbounds nuw %Token, ptr %23, i32 0, i32 1
  %25 = load ptr, ptr %24, align 8
  %26 = getelementptr inbounds nuw %ASTNode, ptr %22, i32 0, i32 1
  store ptr %25, ptr %26, align 8
  %27 = load ptr, ptr %p.537, align 8
  call void @parser_expect__Struct_Parser_Enum_TokenType_String(ptr %27, i32 5, ptr @.str.s178)
  %28 = load ptr, ptr %enum_node.538, align 8
  %29 = getelementptr inbounds nuw %ASTNode, ptr %28, i32 0, i32 5
  %30 = load ptr, ptr %29, align 8
  %31 = call i32 @str_equals(ptr %30, ptr @.str.s179)
  %32 = icmp eq i32 %31, 1
  br i1 %32, label %label_648, label %label_649

label_649:                                        ; preds = %label_646
  %33 = load ptr, ptr %last_var.540, align 8
  %34 = call ptr @ptr_to_node(ptr %33)
  store ptr %34, ptr %last.543, align 8
  %35 = load ptr, ptr %last.543, align 8
  %36 = load ptr, ptr %variant.541, align 8
  %37 = call ptr @node_to_ptr(ptr %36)
  %38 = getelementptr inbounds nuw %ASTNode, ptr %35, i32 0, i32 8
  store ptr %37, ptr %38, align 8
  br label %label_650

label_648:                                        ; preds = %label_646
  %39 = load ptr, ptr %enum_node.538, align 8
  %40 = load ptr, ptr %variant.541, align 8
  %41 = call ptr @node_to_ptr(ptr %40)
  %42 = getelementptr inbounds nuw %ASTNode, ptr %39, i32 0, i32 5
  store ptr %41, ptr %42, align 8
  br label %label_650

label_650:                                        ; preds = %label_649, %label_648
  %43 = load ptr, ptr %variant.541, align 8
  %44 = call ptr @node_to_ptr(ptr %43)
  store ptr %44, ptr %last_var.540, align 8
  %45 = load ptr, ptr %p.537, align 8
  %46 = call i1 @parser_match_val__Struct_Parser_Enum_TokenType_String(ptr %45, i32 6, ptr @.str.s180)
  br label %label_645
}

define ptr @parse_type_annotation__Struct_Parser(ptr %0) {
entry:
  %p.505 = alloca ptr, align 8
  store ptr %0, ptr %p.505, align 8
  %1 = load ptr, ptr %p.505, align 8
  %2 = call ptr @parser_node__Struct_Parser_Enum_NodeKind(ptr %1, i32 31)
  %type_node.506 = alloca ptr, align 8
  store ptr %2, ptr %type_node.506, align 8
  %3 = load ptr, ptr %p.505, align 8
  %4 = call i1 @parser_match_val__Struct_Parser_Enum_TokenType_String(ptr %3, i32 6, ptr @.str.s105)
  %curr.507 = alloca ptr, align 8
  %sc.58 = alloca i1, align 1
  %sc.59 = alloca i1, align 1
  br i1 %4, label %label_578, label %label_580

label_580:                                        ; preds = %entry
  %5 = load ptr, ptr %p.505, align 8
  %6 = call ptr @parser_current__Struct_Parser(ptr %5)
  store ptr %6, ptr %curr.507, align 8
  %7 = load ptr, ptr %curr.507, align 8
  %8 = getelementptr inbounds nuw %Token, ptr %7, i32 0, i32 0
  %9 = load i32, ptr %8, align 4
  %10 = icmp eq i32 %9, 5
  store i1 %10, ptr %sc.58, align 1
  br i1 %10, label %label_582, label %label_581

label_578:                                        ; preds = %entry
  %11 = load ptr, ptr %type_node.506, align 8
  %12 = getelementptr inbounds nuw %ASTNode, ptr %11, i32 0, i32 3
  store i32 1, ptr %12, align 4
  %13 = load ptr, ptr %type_node.506, align 8
  %14 = load ptr, ptr %p.505, align 8
  %15 = call ptr @parse_type_annotation__Struct_Parser(ptr %14)
  %16 = call ptr @node_to_ptr(ptr %15)
  %17 = getelementptr inbounds nuw %ASTNode, ptr %13, i32 0, i32 5
  store ptr %16, ptr %17, align 8
  %18 = load ptr, ptr %p.505, align 8
  call void @parser_expect_val__Struct_Parser_Enum_TokenType_String_String(ptr %18, i32 6, ptr @.str.s106, ptr @.str.s107)
  %19 = load ptr, ptr %type_node.506, align 8
  ret ptr %19

label_581:                                        ; preds = %label_580
  %20 = load ptr, ptr %curr.507, align 8
  %21 = getelementptr inbounds nuw %Token, ptr %20, i32 0, i32 0
  %22 = load i32, ptr %21, align 4
  %23 = icmp eq i32 %22, 18
  store i1 %23, ptr %sc.58, align 1
  br label %label_582

label_582:                                        ; preds = %label_581, %label_580
  %24 = load i1, ptr %sc.58, align 1
  br i1 %24, label %label_583, label %label_584

label_584:                                        ; preds = %label_582
  %25 = load ptr, ptr %p.505, align 8
  %26 = load ptr, ptr %curr.507, align 8
  %27 = call ptr @parser_describe__Struct_Token(ptr %26)
  %28 = call ptr @str_concat(ptr @.str.s108, ptr %27)
  call void @parser_fatal__Struct_Parser_String(ptr %25, ptr %28)
  br label %label_585

label_583:                                        ; preds = %label_582
  %29 = load ptr, ptr %type_node.506, align 8
  %30 = load ptr, ptr %curr.507, align 8
  %31 = getelementptr inbounds nuw %Token, ptr %30, i32 0, i32 1
  %32 = load ptr, ptr %31, align 8
  %33 = getelementptr inbounds nuw %ASTNode, ptr %29, i32 0, i32 1
  store ptr %32, ptr %33, align 8
  %34 = load ptr, ptr %p.505, align 8
  call void @parser_advance__Struct_Parser(ptr %34)
  br label %label_585

label_585:                                        ; preds = %label_584, %label_583
  %35 = load ptr, ptr %type_node.506, align 8
  %36 = getelementptr inbounds nuw %ASTNode, ptr %35, i32 0, i32 1
  %37 = load ptr, ptr %36, align 8
  %38 = call i32 @str_equals(ptr %37, ptr @.str.s109)
  %39 = icmp eq i32 %38, 1
  store i1 %39, ptr %sc.59, align 1
  br i1 %39, label %label_586, label %label_587

label_587:                                        ; preds = %label_586, %label_585
  %40 = load i1, ptr %sc.59, align 1
  br i1 %40, label %label_588, label %label_590

label_586:                                        ; preds = %label_585
  %41 = load ptr, ptr %p.505, align 8
  %42 = call i1 @parser_match_val__Struct_Parser_Enum_TokenType_String(ptr %41, i32 9, ptr @.str.s110)
  store i1 %42, ptr %sc.59, align 1
  br label %label_587

label_590:                                        ; preds = %label_588, %label_587
  %43 = load ptr, ptr %type_node.506, align 8
  ret ptr %43

label_588:                                        ; preds = %label_587
  %44 = load ptr, ptr %type_node.506, align 8
  %45 = getelementptr inbounds nuw %ASTNode, ptr %44, i32 0, i32 4
  store i32 1, ptr %45, align 4
  %46 = load ptr, ptr %type_node.506, align 8
  %47 = load ptr, ptr %p.505, align 8
  %48 = call ptr @parse_type_annotation__Struct_Parser(ptr %47)
  %49 = call ptr @node_to_ptr(ptr %48)
  %50 = getelementptr inbounds nuw %ASTNode, ptr %46, i32 0, i32 5
  store ptr %49, ptr %50, align 8
  %51 = load ptr, ptr %p.505, align 8
  call void @parser_expect_close_angle__Struct_Parser_String(ptr %51, ptr @.str.s111)
  br label %label_590
}

define void @parser_expect_close_angle__Struct_Parser_String(ptr %0, ptr %1) {
entry:
  %p.508 = alloca ptr, align 8
  store ptr %0, ptr %p.508, align 8
  %context.509 = alloca ptr, align 8
  store ptr %1, ptr %context.509, align 8
  %2 = load ptr, ptr %p.508, align 8
  %3 = call ptr @parser_current__Struct_Parser(ptr %2)
  %curr.510 = alloca ptr, align 8
  store ptr %3, ptr %curr.510, align 8
  %4 = load ptr, ptr %curr.510, align 8
  %5 = getelementptr inbounds nuw %Token, ptr %4, i32 0, i32 1
  %6 = load ptr, ptr %5, align 8
  %7 = call i32 @str_equals(ptr %6, ptr @.str.s112)
  %8 = icmp eq i32 %7, 1
  br i1 %8, label %label_591, label %label_593

label_593:                                        ; preds = %entry
  %9 = load ptr, ptr %p.508, align 8
  %10 = load ptr, ptr %context.509, align 8
  call void @parser_expect_val__Struct_Parser_Enum_TokenType_String_String(ptr %9, i32 9, ptr @.str.s114, ptr %10)
  ret void

label_591:                                        ; preds = %entry
  %11 = load ptr, ptr %curr.510, align 8
  %12 = getelementptr inbounds nuw %Token, ptr %11, i32 0, i32 1
  store ptr @.str.s113, ptr %12, align 8
  ret void
}

define ptr @parse_expression__Struct_Parser_Int(ptr %0, i32 %1) {
entry:
  %p.591 = alloca ptr, align 8
  store ptr %0, ptr %p.591, align 8
  %precedence.592 = alloca i32, align 4
  store i32 %1, ptr %precedence.592, align 4
  %2 = load ptr, ptr %p.591, align 8
  %3 = call ptr @parse_unary__Struct_Parser(ptr %2)
  %left.593 = alloca ptr, align 8
  store ptr %3, ptr %left.593, align 8
  %is_looping.594 = alloca i1, align 1
  store i1 true, ptr %is_looping.594, align 1
  %curr.595 = alloca ptr, align 8
  %sc.78 = alloca i1, align 1
  %sc.79 = alloca i1, align 1
  %sc.80 = alloca i1, align 1
  %is_operator.596 = alloca i1, align 1
  %current_precedence.597 = alloca i32, align 4
  %sc.81 = alloca i1, align 1
  %op.598 = alloca ptr, align 8
  %right.599 = alloca ptr, align 8
  %bin_expr.600 = alloca ptr, align 8
  br label %label_798

label_798:                                        ; preds = %label_809, %entry
  %4 = load i1, ptr %is_looping.594, align 1
  br i1 %4, label %label_799, label %label_800

label_800:                                        ; preds = %label_798
  %5 = load ptr, ptr %left.593, align 8
  ret ptr %5

label_799:                                        ; preds = %label_798
  %6 = load ptr, ptr %p.591, align 8
  %7 = call ptr @parser_current__Struct_Parser(ptr %6)
  store ptr %7, ptr %curr.595, align 8
  %8 = load ptr, ptr %curr.595, align 8
  %9 = getelementptr inbounds nuw %Token, ptr %8, i32 0, i32 0
  %10 = load i32, ptr %9, align 4
  %11 = icmp eq i32 %10, 8
  store i1 %11, ptr %sc.80, align 1
  br i1 %11, label %label_806, label %label_805

label_805:                                        ; preds = %label_799
  %12 = load ptr, ptr %curr.595, align 8
  %13 = getelementptr inbounds nuw %Token, ptr %12, i32 0, i32 0
  %14 = load i32, ptr %13, align 4
  %15 = icmp eq i32 %14, 9
  store i1 %15, ptr %sc.80, align 1
  br label %label_806

label_806:                                        ; preds = %label_805, %label_799
  %16 = load i1, ptr %sc.80, align 1
  store i1 %16, ptr %sc.79, align 1
  br i1 %16, label %label_804, label %label_803

label_803:                                        ; preds = %label_806
  %17 = load ptr, ptr %curr.595, align 8
  %18 = getelementptr inbounds nuw %Token, ptr %17, i32 0, i32 1
  %19 = load ptr, ptr %18, align 8
  %20 = call i32 @str_equals(ptr %19, ptr @.str.s272)
  %21 = icmp eq i32 %20, 1
  store i1 %21, ptr %sc.79, align 1
  br label %label_804

label_804:                                        ; preds = %label_803, %label_806
  %22 = load i1, ptr %sc.79, align 1
  store i1 %22, ptr %sc.78, align 1
  br i1 %22, label %label_802, label %label_801

label_801:                                        ; preds = %label_804
  %23 = load ptr, ptr %curr.595, align 8
  %24 = getelementptr inbounds nuw %Token, ptr %23, i32 0, i32 1
  %25 = load ptr, ptr %24, align 8
  %26 = call i32 @str_equals(ptr %25, ptr @.str.s273)
  %27 = icmp eq i32 %26, 1
  store i1 %27, ptr %sc.78, align 1
  br label %label_802

label_802:                                        ; preds = %label_801, %label_804
  %28 = load i1, ptr %sc.78, align 1
  store i1 %28, ptr %is_operator.596, align 1
  %29 = load i1, ptr %is_operator.596, align 1
  %30 = icmp eq i1 %29, false
  br i1 %30, label %label_807, label %label_808

label_808:                                        ; preds = %label_802
  %31 = load ptr, ptr %curr.595, align 8
  %32 = call i32 @get_operator_precedence__Struct_Token(ptr %31)
  store i32 %32, ptr %current_precedence.597, align 4
  %33 = load i32, ptr %current_precedence.597, align 4
  %34 = icmp eq i32 %33, 0
  store i1 %34, ptr %sc.81, align 1
  br i1 %34, label %label_811, label %label_810

label_807:                                        ; preds = %label_802
  store i1 false, ptr %is_looping.594, align 1
  br label %label_809

label_809:                                        ; preds = %label_814, %label_807
  br label %label_798

label_810:                                        ; preds = %label_808
  %35 = load i32, ptr %current_precedence.597, align 4
  %36 = load i32, ptr %precedence.592, align 4
  %37 = icmp slt i32 %35, %36
  store i1 %37, ptr %sc.81, align 1
  br label %label_811

label_811:                                        ; preds = %label_810, %label_808
  %38 = load i1, ptr %sc.81, align 1
  br i1 %38, label %label_812, label %label_813

label_813:                                        ; preds = %label_811
  %39 = load ptr, ptr %curr.595, align 8
  %40 = getelementptr inbounds nuw %Token, ptr %39, i32 0, i32 1
  %41 = load ptr, ptr %40, align 8
  store ptr %41, ptr %op.598, align 8
  %42 = load ptr, ptr %p.591, align 8
  call void @parser_advance__Struct_Parser(ptr %42)
  %43 = load ptr, ptr %p.591, align 8
  %44 = load i32, ptr %current_precedence.597, align 4
  %45 = add i32 %44, 1
  %46 = call ptr @parse_expression__Struct_Parser_Int(ptr %43, i32 %45)
  store ptr %46, ptr %right.599, align 8
  %47 = load ptr, ptr %p.591, align 8
  %48 = call ptr @parser_node__Struct_Parser_Enum_NodeKind(ptr %47, i32 20)
  store ptr %48, ptr %bin_expr.600, align 8
  %49 = load ptr, ptr %bin_expr.600, align 8
  %50 = load ptr, ptr %op.598, align 8
  %51 = getelementptr inbounds nuw %ASTNode, ptr %49, i32 0, i32 1
  store ptr %50, ptr %51, align 8
  %52 = load ptr, ptr %bin_expr.600, align 8
  %53 = load ptr, ptr %left.593, align 8
  %54 = call ptr @node_to_ptr(ptr %53)
  %55 = getelementptr inbounds nuw %ASTNode, ptr %52, i32 0, i32 5
  store ptr %54, ptr %55, align 8
  %56 = load ptr, ptr %bin_expr.600, align 8
  %57 = load ptr, ptr %right.599, align 8
  %58 = call ptr @node_to_ptr(ptr %57)
  %59 = getelementptr inbounds nuw %ASTNode, ptr %56, i32 0, i32 6
  store ptr %58, ptr %59, align 8
  %60 = load ptr, ptr %bin_expr.600, align 8
  store ptr %60, ptr %left.593, align 8
  br label %label_814

label_812:                                        ; preds = %label_811
  store i1 false, ptr %is_looping.594, align 1
  br label %label_814

label_814:                                        ; preds = %label_813, %label_812
  br label %label_809
}

define ptr @parse_block__Struct_Parser(ptr %0) {
entry:
  %p.544 = alloca ptr, align 8
  store ptr %0, ptr %p.544, align 8
  %1 = load ptr, ptr %p.544, align 8
  %2 = call ptr @parser_current__Struct_Parser(ptr %1)
  %open.545 = alloca ptr, align 8
  store ptr %2, ptr %open.545, align 8
  %3 = load ptr, ptr %p.544, align 8
  call void @parser_expect_val__Struct_Parser_Enum_TokenType_String_String(ptr %3, i32 6, ptr @.str.s183, ptr @.str.s184)
  %4 = load ptr, ptr %p.544, align 8
  %5 = call ptr @parser_node__Struct_Parser_Enum_NodeKind(ptr %4, i32 9)
  %block_node.546 = alloca ptr, align 8
  store ptr %5, ptr %block_node.546, align 8
  %last_stmt.547 = alloca ptr, align 8
  store ptr @.str.s185, ptr %last_stmt.547, align 8
  %stmt.548 = alloca ptr, align 8
  %last.549 = alloca ptr, align 8
  br label %label_651

label_651:                                        ; preds = %label_659, %entry
  %6 = load ptr, ptr %p.544, align 8
  %7 = call i1 @parser_check_val__Struct_Parser_Enum_TokenType_String(ptr %6, i32 6, ptr @.str.s186)
  %8 = icmp eq i1 %7, false
  br i1 %8, label %label_652, label %label_653

label_653:                                        ; preds = %label_651
  %9 = load ptr, ptr %p.544, align 8
  call void @parser_expect_val__Struct_Parser_Enum_TokenType_String_String(ptr %9, i32 6, ptr @.str.s189, ptr @.str.s190)
  %10 = load ptr, ptr %block_node.546, align 8
  ret ptr %10

label_652:                                        ; preds = %label_651
  %11 = load ptr, ptr %p.544, align 8
  %12 = call i1 @parser_check__Struct_Parser_Enum_TokenType(ptr %11, i32 20)
  br i1 %12, label %label_654, label %label_656

label_656:                                        ; preds = %label_654, %label_652
  %13 = load ptr, ptr %p.544, align 8
  %14 = call ptr @parse_statement__Struct_Parser(ptr %13)
  store ptr %14, ptr %stmt.548, align 8
  %15 = load ptr, ptr %block_node.546, align 8
  %16 = getelementptr inbounds nuw %ASTNode, ptr %15, i32 0, i32 5
  %17 = load ptr, ptr %16, align 8
  %18 = call i32 @str_equals(ptr %17, ptr @.str.s188)
  %19 = icmp eq i32 %18, 1
  br i1 %19, label %label_657, label %label_658

label_654:                                        ; preds = %label_652
  %20 = load ptr, ptr %open.545, align 8
  %21 = getelementptr inbounds nuw %Token, ptr %20, i32 0, i32 5
  %22 = load i32, ptr %21, align 4
  %23 = load ptr, ptr %open.545, align 8
  %24 = getelementptr inbounds nuw %Token, ptr %23, i32 0, i32 2
  %25 = load i32, ptr %24, align 4
  %26 = load ptr, ptr %open.545, align 8
  %27 = getelementptr inbounds nuw %Token, ptr %26, i32 0, i32 3
  %28 = load i32, ptr %27, align 4
  %29 = load ptr, ptr %open.545, align 8
  %30 = getelementptr inbounds nuw %Token, ptr %29, i32 0, i32 4
  %31 = load i32, ptr %30, align 4
  call void @diag_error_at(i32 %22, i32 %25, i32 %28, i32 %31, ptr @.str.s187)
  call void @diag_finish()
  call void @exit(i32 1)
  br label %label_656

label_658:                                        ; preds = %label_656
  %32 = load ptr, ptr %last_stmt.547, align 8
  %33 = call ptr @ptr_to_node(ptr %32)
  store ptr %33, ptr %last.549, align 8
  %34 = load ptr, ptr %last.549, align 8
  %35 = load ptr, ptr %stmt.548, align 8
  %36 = call ptr @node_to_ptr(ptr %35)
  %37 = getelementptr inbounds nuw %ASTNode, ptr %34, i32 0, i32 8
  store ptr %36, ptr %37, align 8
  br label %label_659

label_657:                                        ; preds = %label_656
  %38 = load ptr, ptr %block_node.546, align 8
  %39 = load ptr, ptr %stmt.548, align 8
  %40 = call ptr @node_to_ptr(ptr %39)
  %41 = getelementptr inbounds nuw %ASTNode, ptr %38, i32 0, i32 5
  store ptr %40, ptr %41, align 8
  br label %label_659

label_659:                                        ; preds = %label_658, %label_657
  %42 = load ptr, ptr %stmt.548, align 8
  %43 = call ptr @node_to_ptr(ptr %42)
  store ptr %43, ptr %last_stmt.547, align 8
  br label %label_651
}

define ptr @parse_statement__Struct_Parser(ptr %0) {
entry:
  %p.567 = alloca ptr, align 8
  store ptr %0, ptr %p.567, align 8
  %1 = load ptr, ptr %p.567, align 8
  %2 = call i1 @parser_check_val__Struct_Parser_Enum_TokenType_String(ptr %1, i32 18, ptr @.str.s233)
  %ret_node.568 = alloca ptr, align 8
  %curr.569 = alloca ptr, align 8
  %sc.60 = alloca i1, align 1
  %expr.570 = alloca ptr, align 8
  %assign_stmt.571 = alloca ptr, align 8
  %assign_tok.572 = alloca ptr, align 8
  %sc.61 = alloca i1, align 1
  %op.573 = alloca ptr, align 8
  %combined.574 = alloca ptr, align 8
  %compound.575 = alloca ptr, align 8
  %stmt.576 = alloca ptr, align 8
  br i1 %2, label %label_675, label %label_677

label_677:                                        ; preds = %entry
  %3 = load ptr, ptr %p.567, align 8
  %4 = call i1 @parser_check_val__Struct_Parser_Enum_TokenType_String(ptr %3, i32 18, ptr @.str.s234)
  br i1 %4, label %label_678, label %label_680

label_675:                                        ; preds = %entry
  %5 = load ptr, ptr %p.567, align 8
  %6 = call ptr @parse_if_statement__Struct_Parser(ptr %5)
  ret ptr %6

label_680:                                        ; preds = %label_677
  %7 = load ptr, ptr %p.567, align 8
  %8 = call i1 @parser_check_val__Struct_Parser_Enum_TokenType_String(ptr %7, i32 18, ptr @.str.s235)
  br i1 %8, label %label_681, label %label_683

label_678:                                        ; preds = %label_677
  %9 = load ptr, ptr %p.567, align 8
  %10 = call ptr @parse_while_statement__Struct_Parser(ptr %9)
  ret ptr %10

label_683:                                        ; preds = %label_680
  %11 = load ptr, ptr %p.567, align 8
  %12 = call i1 @parser_check_val__Struct_Parser_Enum_TokenType_String(ptr %11, i32 18, ptr @.str.s236)
  br i1 %12, label %label_684, label %label_686

label_681:                                        ; preds = %label_680
  %13 = load ptr, ptr %p.567, align 8
  %14 = call ptr @parse_loop_statement__Struct_Parser(ptr %13)
  ret ptr %14

label_686:                                        ; preds = %label_683
  %15 = load ptr, ptr %p.567, align 8
  %16 = call i1 @parser_check_val__Struct_Parser_Enum_TokenType_String(ptr %15, i32 18, ptr @.str.s237)
  br i1 %16, label %label_687, label %label_689

label_684:                                        ; preds = %label_683
  %17 = load ptr, ptr %p.567, align 8
  %18 = call ptr @parse_match_statement__Struct_Parser(ptr %17)
  ret ptr %18

label_689:                                        ; preds = %label_686
  %19 = load ptr, ptr %p.567, align 8
  %20 = call i1 @parser_match_val__Struct_Parser_Enum_TokenType_String(ptr %19, i32 18, ptr @.str.s238)
  br i1 %20, label %label_690, label %label_692

label_687:                                        ; preds = %label_686
  %21 = load ptr, ptr %p.567, align 8
  %22 = call ptr @parse_for_statement__Struct_Parser(ptr %21)
  ret ptr %22

label_692:                                        ; preds = %label_689
  %23 = load ptr, ptr %p.567, align 8
  %24 = call i1 @parser_match_val__Struct_Parser_Enum_TokenType_String(ptr %23, i32 18, ptr @.str.s239)
  br i1 %24, label %label_693, label %label_695

label_690:                                        ; preds = %label_689
  %25 = load ptr, ptr %p.567, align 8
  %26 = call ptr @parser_node__Struct_Parser_Enum_NodeKind(ptr %25, i32 18)
  ret ptr %26

label_695:                                        ; preds = %label_692
  %27 = load ptr, ptr %p.567, align 8
  %28 = call i1 @parser_match_val__Struct_Parser_Enum_TokenType_String(ptr %27, i32 18, ptr @.str.s240)
  br i1 %28, label %label_696, label %label_698

label_693:                                        ; preds = %label_692
  %29 = load ptr, ptr %p.567, align 8
  %30 = call ptr @parser_node__Struct_Parser_Enum_NodeKind(ptr %29, i32 19)
  ret ptr %30

label_698:                                        ; preds = %label_695
  %31 = load ptr, ptr %p.567, align 8
  %32 = call i1 @parser_check_val__Struct_Parser_Enum_TokenType_String(ptr %31, i32 18, ptr @.str.s242)
  br i1 %32, label %label_704, label %label_706

label_696:                                        ; preds = %label_695
  %33 = load ptr, ptr %p.567, align 8
  %34 = call ptr @parser_node__Struct_Parser_Enum_NodeKind(ptr %33, i32 15)
  store ptr %34, ptr %ret_node.568, align 8
  %35 = load ptr, ptr %p.567, align 8
  %36 = call ptr @parser_current__Struct_Parser(ptr %35)
  store ptr %36, ptr %curr.569, align 8
  %37 = load ptr, ptr %curr.569, align 8
  %38 = getelementptr inbounds nuw %Token, ptr %37, i32 0, i32 0
  %39 = load i32, ptr %38, align 4
  %40 = icmp ne i32 %39, 6
  store i1 %40, ptr %sc.60, align 1
  br i1 %40, label %label_700, label %label_699

label_699:                                        ; preds = %label_696
  %41 = load ptr, ptr %curr.569, align 8
  %42 = getelementptr inbounds nuw %Token, ptr %41, i32 0, i32 1
  %43 = load ptr, ptr %42, align 8
  %44 = call i32 @str_equals(ptr %43, ptr @.str.s241)
  %45 = icmp eq i32 %44, 0
  store i1 %45, ptr %sc.60, align 1
  br label %label_700

label_700:                                        ; preds = %label_699, %label_696
  %46 = load i1, ptr %sc.60, align 1
  br i1 %46, label %label_701, label %label_703

label_703:                                        ; preds = %label_701, %label_700
  %47 = load ptr, ptr %ret_node.568, align 8
  ret ptr %47

label_701:                                        ; preds = %label_700
  %48 = load ptr, ptr %ret_node.568, align 8
  %49 = load ptr, ptr %p.567, align 8
  %50 = call ptr @parse_expression__Struct_Parser_Int(ptr %49, i32 0)
  %51 = call ptr @node_to_ptr(ptr %50)
  %52 = getelementptr inbounds nuw %ASTNode, ptr %48, i32 0, i32 5
  store ptr %51, ptr %52, align 8
  br label %label_703

label_706:                                        ; preds = %label_698
  %53 = load ptr, ptr %p.567, align 8
  %54 = call ptr @parse_expression__Struct_Parser_Int(ptr %53, i32 0)
  store ptr %54, ptr %expr.570, align 8
  %55 = load ptr, ptr %p.567, align 8
  %56 = call i1 @parser_match_val__Struct_Parser_Enum_TokenType_String(ptr %55, i32 12, ptr @.str.s243)
  br i1 %56, label %label_707, label %label_709

label_704:                                        ; preds = %label_698
  %57 = load ptr, ptr %p.567, align 8
  %58 = call ptr @parse_variable_decl__Struct_Parser(ptr %57)
  ret ptr %58

label_709:                                        ; preds = %label_706
  %59 = load ptr, ptr %p.567, align 8
  %60 = call ptr @parser_current__Struct_Parser(ptr %59)
  store ptr %60, ptr %assign_tok.572, align 8
  %61 = load ptr, ptr %assign_tok.572, align 8
  %62 = getelementptr inbounds nuw %Token, ptr %61, i32 0, i32 0
  %63 = load i32, ptr %62, align 4
  %64 = icmp eq i32 %63, 12
  store i1 %64, ptr %sc.61, align 1
  br i1 %64, label %label_710, label %label_711

label_707:                                        ; preds = %label_706
  %65 = load ptr, ptr %p.567, align 8
  %66 = call ptr @parser_node__Struct_Parser_Enum_NodeKind(ptr %65, i32 16)
  store ptr %66, ptr %assign_stmt.571, align 8
  %67 = load ptr, ptr %assign_stmt.571, align 8
  %68 = load ptr, ptr %expr.570, align 8
  %69 = call ptr @node_to_ptr(ptr %68)
  %70 = getelementptr inbounds nuw %ASTNode, ptr %67, i32 0, i32 5
  store ptr %69, ptr %70, align 8
  %71 = load ptr, ptr %assign_stmt.571, align 8
  %72 = load ptr, ptr %p.567, align 8
  %73 = call ptr @parse_expression__Struct_Parser_Int(ptr %72, i32 0)
  %74 = call ptr @node_to_ptr(ptr %73)
  %75 = getelementptr inbounds nuw %ASTNode, ptr %71, i32 0, i32 6
  store ptr %74, ptr %75, align 8
  %76 = load ptr, ptr %assign_stmt.571, align 8
  ret ptr %76

label_711:                                        ; preds = %label_710, %label_709
  %77 = load i1, ptr %sc.61, align 1
  br i1 %77, label %label_712, label %label_714

label_710:                                        ; preds = %label_709
  %78 = load ptr, ptr %assign_tok.572, align 8
  %79 = getelementptr inbounds nuw %Token, ptr %78, i32 0, i32 1
  %80 = load ptr, ptr %79, align 8
  %81 = call i32 @str_length(ptr %80)
  %82 = icmp eq i32 %81, 2
  store i1 %82, ptr %sc.61, align 1
  br label %label_711

label_714:                                        ; preds = %label_711
  %83 = load ptr, ptr %p.567, align 8
  %84 = call ptr @parser_node__Struct_Parser_Enum_NodeKind(ptr %83, i32 17)
  store ptr %84, ptr %stmt.576, align 8
  %85 = load ptr, ptr %stmt.576, align 8
  %86 = load ptr, ptr %expr.570, align 8
  %87 = call ptr @node_to_ptr(ptr %86)
  %88 = getelementptr inbounds nuw %ASTNode, ptr %85, i32 0, i32 5
  store ptr %87, ptr %88, align 8
  %89 = load ptr, ptr %stmt.576, align 8
  ret ptr %89

label_712:                                        ; preds = %label_711
  %90 = load ptr, ptr %assign_tok.572, align 8
  %91 = getelementptr inbounds nuw %Token, ptr %90, i32 0, i32 1
  %92 = load ptr, ptr %91, align 8
  %93 = call ptr @str_substring(ptr %92, i32 0, i32 1)
  store ptr %93, ptr %op.573, align 8
  %94 = load ptr, ptr %p.567, align 8
  call void @parser_advance__Struct_Parser(ptr %94)
  %95 = load ptr, ptr %expr.570, align 8
  %96 = getelementptr inbounds nuw %ASTNode, ptr %95, i32 0, i32 0
  %97 = load i32, ptr %96, align 4
  %98 = icmp ne i32 %97, 23
  br i1 %98, label %label_715, label %label_717

label_717:                                        ; preds = %label_715, %label_712
  %99 = load ptr, ptr %p.567, align 8
  %100 = call ptr @parser_node__Struct_Parser_Enum_NodeKind(ptr %99, i32 20)
  store ptr %100, ptr %combined.574, align 8
  %101 = load ptr, ptr %combined.574, align 8
  %102 = load ptr, ptr %op.573, align 8
  %103 = getelementptr inbounds nuw %ASTNode, ptr %101, i32 0, i32 1
  store ptr %102, ptr %103, align 8
  %104 = load ptr, ptr %combined.574, align 8
  %105 = load ptr, ptr %expr.570, align 8
  %106 = call ptr @node_to_ptr(ptr %105)
  %107 = getelementptr inbounds nuw %ASTNode, ptr %104, i32 0, i32 5
  store ptr %106, ptr %107, align 8
  %108 = load ptr, ptr %combined.574, align 8
  %109 = load ptr, ptr %p.567, align 8
  %110 = call ptr @parse_expression__Struct_Parser_Int(ptr %109, i32 0)
  %111 = call ptr @node_to_ptr(ptr %110)
  %112 = getelementptr inbounds nuw %ASTNode, ptr %108, i32 0, i32 6
  store ptr %111, ptr %112, align 8
  %113 = load ptr, ptr %p.567, align 8
  %114 = call ptr @parser_node__Struct_Parser_Enum_NodeKind(ptr %113, i32 16)
  store ptr %114, ptr %compound.575, align 8
  %115 = load ptr, ptr %compound.575, align 8
  %116 = load ptr, ptr %expr.570, align 8
  %117 = call ptr @node_to_ptr(ptr %116)
  %118 = getelementptr inbounds nuw %ASTNode, ptr %115, i32 0, i32 5
  store ptr %117, ptr %118, align 8
  %119 = load ptr, ptr %compound.575, align 8
  %120 = load ptr, ptr %combined.574, align 8
  %121 = call ptr @node_to_ptr(ptr %120)
  %122 = getelementptr inbounds nuw %ASTNode, ptr %119, i32 0, i32 6
  store ptr %121, ptr %122, align 8
  %123 = load ptr, ptr %compound.575, align 8
  ret ptr %123

label_715:                                        ; preds = %label_712
  %124 = load ptr, ptr %expr.570, align 8
  %125 = getelementptr inbounds nuw %ASTNode, ptr %124, i32 0, i32 13
  %126 = load i32, ptr %125, align 4
  %127 = load ptr, ptr %expr.570, align 8
  %128 = getelementptr inbounds nuw %ASTNode, ptr %127, i32 0, i32 10
  %129 = load i32, ptr %128, align 4
  %130 = load ptr, ptr %expr.570, align 8
  %131 = getelementptr inbounds nuw %ASTNode, ptr %130, i32 0, i32 11
  %132 = load i32, ptr %131, align 4
  %133 = load ptr, ptr %expr.570, align 8
  %134 = getelementptr inbounds nuw %ASTNode, ptr %133, i32 0, i32 12
  %135 = load i32, ptr %134, align 4
  %136 = load ptr, ptr %assign_tok.572, align 8
  %137 = getelementptr inbounds nuw %Token, ptr %136, i32 0, i32 1
  %138 = load ptr, ptr %137, align 8
  %139 = call ptr @diag_quote__String(ptr %138)
  %140 = call ptr @str_concat(ptr @.str.s244, ptr %139)
  %141 = call ptr @str_concat(ptr %140, ptr @.str.s245)
  call void @diag_error_at(i32 %126, i32 %129, i32 %132, i32 %135, ptr %141)
  call void @diag_note(ptr @.str.s246)
  call void @diag_finish()
  call void @exit(i32 1)
  br label %label_717
}

define ptr @parse_if_statement__Struct_Parser(ptr %0) {
entry:
  %p.550 = alloca ptr, align 8
  store ptr %0, ptr %p.550, align 8
  %1 = load ptr, ptr %p.550, align 8
  call void @parser_expect_val__Struct_Parser_Enum_TokenType_String_String(ptr %1, i32 18, ptr @.str.s191, ptr @.str.s192)
  %2 = load ptr, ptr %p.550, align 8
  %3 = call ptr @parser_node__Struct_Parser_Enum_NodeKind(ptr %2, i32 10)
  %if_node.551 = alloca ptr, align 8
  store ptr %3, ptr %if_node.551, align 8
  %4 = load ptr, ptr %p.550, align 8
  call void @parser_expect_val__Struct_Parser_Enum_TokenType_String_String(ptr %4, i32 6, ptr @.str.s193, ptr @.str.s194)
  %5 = load ptr, ptr %if_node.551, align 8
  %6 = load ptr, ptr %p.550, align 8
  %7 = call ptr @parse_expression__Struct_Parser_Int(ptr %6, i32 0)
  %8 = call ptr @node_to_ptr(ptr %7)
  %9 = getelementptr inbounds nuw %ASTNode, ptr %5, i32 0, i32 5
  store ptr %8, ptr %9, align 8
  %10 = load ptr, ptr %p.550, align 8
  call void @parser_expect_val__Struct_Parser_Enum_TokenType_String_String(ptr %10, i32 6, ptr @.str.s195, ptr @.str.s196)
  %11 = load ptr, ptr %if_node.551, align 8
  %12 = load ptr, ptr %p.550, align 8
  %13 = call ptr @parse_block__Struct_Parser(ptr %12)
  %14 = call ptr @node_to_ptr(ptr %13)
  %15 = getelementptr inbounds nuw %ASTNode, ptr %11, i32 0, i32 6
  store ptr %14, ptr %15, align 8
  %16 = load ptr, ptr %p.550, align 8
  %17 = call i1 @parser_match_val__Struct_Parser_Enum_TokenType_String(ptr %16, i32 18, ptr @.str.s197)
  br i1 %17, label %label_660, label %label_662

label_662:                                        ; preds = %label_665, %entry
  %18 = load ptr, ptr %if_node.551, align 8
  ret ptr %18

label_660:                                        ; preds = %entry
  %19 = load ptr, ptr %p.550, align 8
  %20 = call i1 @parser_check_val__Struct_Parser_Enum_TokenType_String(ptr %19, i32 18, ptr @.str.s198)
  br i1 %20, label %label_663, label %label_664

label_664:                                        ; preds = %label_660
  %21 = load ptr, ptr %if_node.551, align 8
  %22 = load ptr, ptr %p.550, align 8
  %23 = call ptr @parse_block__Struct_Parser(ptr %22)
  %24 = call ptr @node_to_ptr(ptr %23)
  %25 = getelementptr inbounds nuw %ASTNode, ptr %21, i32 0, i32 7
  store ptr %24, ptr %25, align 8
  br label %label_665

label_663:                                        ; preds = %label_660
  %26 = load ptr, ptr %if_node.551, align 8
  %27 = load ptr, ptr %p.550, align 8
  %28 = call ptr @parse_if_statement__Struct_Parser(ptr %27)
  %29 = call ptr @node_to_ptr(ptr %28)
  %30 = getelementptr inbounds nuw %ASTNode, ptr %26, i32 0, i32 7
  store ptr %29, ptr %30, align 8
  br label %label_665

label_665:                                        ; preds = %label_664, %label_663
  br label %label_662
}

define ptr @parse_while_statement__Struct_Parser(ptr %0) {
entry:
  %p.552 = alloca ptr, align 8
  store ptr %0, ptr %p.552, align 8
  %1 = load ptr, ptr %p.552, align 8
  call void @parser_expect_val__Struct_Parser_Enum_TokenType_String_String(ptr %1, i32 18, ptr @.str.s199, ptr @.str.s200)
  %2 = load ptr, ptr %p.552, align 8
  %3 = call ptr @parser_node__Struct_Parser_Enum_NodeKind(ptr %2, i32 13)
  %while_node.553 = alloca ptr, align 8
  store ptr %3, ptr %while_node.553, align 8
  %4 = load ptr, ptr %p.552, align 8
  call void @parser_expect_val__Struct_Parser_Enum_TokenType_String_String(ptr %4, i32 6, ptr @.str.s201, ptr @.str.s202)
  %5 = load ptr, ptr %while_node.553, align 8
  %6 = load ptr, ptr %p.552, align 8
  %7 = call ptr @parse_expression__Struct_Parser_Int(ptr %6, i32 0)
  %8 = call ptr @node_to_ptr(ptr %7)
  %9 = getelementptr inbounds nuw %ASTNode, ptr %5, i32 0, i32 5
  store ptr %8, ptr %9, align 8
  %10 = load ptr, ptr %p.552, align 8
  call void @parser_expect_val__Struct_Parser_Enum_TokenType_String_String(ptr %10, i32 6, ptr @.str.s203, ptr @.str.s204)
  %11 = load ptr, ptr %while_node.553, align 8
  %12 = load ptr, ptr %p.552, align 8
  %13 = call ptr @parse_block__Struct_Parser(ptr %12)
  %14 = call ptr @node_to_ptr(ptr %13)
  %15 = getelementptr inbounds nuw %ASTNode, ptr %11, i32 0, i32 6
  store ptr %14, ptr %15, align 8
  %16 = load ptr, ptr %while_node.553, align 8
  ret ptr %16
}

define ptr @parse_loop_statement__Struct_Parser(ptr %0) {
entry:
  %p.554 = alloca ptr, align 8
  store ptr %0, ptr %p.554, align 8
  %1 = load ptr, ptr %p.554, align 8
  call void @parser_expect_val__Struct_Parser_Enum_TokenType_String_String(ptr %1, i32 18, ptr @.str.s205, ptr @.str.s206)
  %2 = load ptr, ptr %p.554, align 8
  %3 = call ptr @parser_node__Struct_Parser_Enum_NodeKind(ptr %2, i32 14)
  %loop_node.555 = alloca ptr, align 8
  store ptr %3, ptr %loop_node.555, align 8
  %4 = load ptr, ptr %loop_node.555, align 8
  %5 = load ptr, ptr %p.554, align 8
  %6 = call ptr @parse_block__Struct_Parser(ptr %5)
  %7 = call ptr @node_to_ptr(ptr %6)
  %8 = getelementptr inbounds nuw %ASTNode, ptr %4, i32 0, i32 5
  store ptr %7, ptr %8, align 8
  %9 = load ptr, ptr %loop_node.555, align 8
  ret ptr %9
}

define ptr @parse_for_statement__Struct_Parser(ptr %0) {
entry:
  %p.556 = alloca ptr, align 8
  store ptr %0, ptr %p.556, align 8
  %1 = load ptr, ptr %p.556, align 8
  call void @parser_expect_val__Struct_Parser_Enum_TokenType_String_String(ptr %1, i32 18, ptr @.str.s207, ptr @.str.s208)
  %2 = load ptr, ptr %p.556, align 8
  %3 = call ptr @parser_node__Struct_Parser_Enum_NodeKind(ptr %2, i32 12)
  %for_node.557 = alloca ptr, align 8
  store ptr %3, ptr %for_node.557, align 8
  %4 = load ptr, ptr %p.556, align 8
  %5 = call ptr @parser_current__Struct_Parser(ptr %4)
  %curr.558 = alloca ptr, align 8
  store ptr %5, ptr %curr.558, align 8
  %6 = load ptr, ptr %for_node.557, align 8
  %7 = load ptr, ptr %curr.558, align 8
  %8 = getelementptr inbounds nuw %Token, ptr %7, i32 0, i32 1
  %9 = load ptr, ptr %8, align 8
  %10 = getelementptr inbounds nuw %ASTNode, ptr %6, i32 0, i32 1
  store ptr %9, ptr %10, align 8
  %11 = load ptr, ptr %p.556, align 8
  call void @parser_expect__Struct_Parser_Enum_TokenType_String(ptr %11, i32 5, ptr @.str.s209)
  %12 = load ptr, ptr %p.556, align 8
  call void @parser_expect_val__Struct_Parser_Enum_TokenType_String_String(ptr %12, i32 18, ptr @.str.s210, ptr @.str.s211)
  store i32 0, ptr @parser_allow_struct_lit, align 4
  %13 = load ptr, ptr %for_node.557, align 8
  %14 = load ptr, ptr %p.556, align 8
  %15 = call ptr @parse_expression__Struct_Parser_Int(ptr %14, i32 0)
  %16 = call ptr @node_to_ptr(ptr %15)
  %17 = getelementptr inbounds nuw %ASTNode, ptr %13, i32 0, i32 5
  store ptr %16, ptr %17, align 8
  %18 = load ptr, ptr %p.556, align 8
  call void @parser_expect_val__Struct_Parser_Enum_TokenType_String_String(ptr %18, i32 17, ptr @.str.s212, ptr @.str.s213)
  %19 = load ptr, ptr %for_node.557, align 8
  %20 = load ptr, ptr %p.556, align 8
  %21 = call ptr @parse_expression__Struct_Parser_Int(ptr %20, i32 0)
  %22 = call ptr @node_to_ptr(ptr %21)
  %23 = getelementptr inbounds nuw %ASTNode, ptr %19, i32 0, i32 6
  store ptr %22, ptr %23, align 8
  store i32 1, ptr @parser_allow_struct_lit, align 4
  %24 = load ptr, ptr %for_node.557, align 8
  %25 = load ptr, ptr %p.556, align 8
  %26 = call ptr @parse_block__Struct_Parser(ptr %25)
  %27 = call ptr @node_to_ptr(ptr %26)
  %28 = getelementptr inbounds nuw %ASTNode, ptr %24, i32 0, i32 7
  store ptr %27, ptr %28, align 8
  %29 = load ptr, ptr %for_node.557, align 8
  ret ptr %29
}

define ptr @parse_match_arm__Struct_Parser(ptr %0) {
entry:
  %p.559 = alloca ptr, align 8
  store ptr %0, ptr %p.559, align 8
  %1 = load ptr, ptr %p.559, align 8
  %2 = call ptr @parser_node__Struct_Parser_Enum_NodeKind(ptr %1, i32 34)
  %arm.560 = alloca ptr, align 8
  store ptr %2, ptr %arm.560, align 8
  %3 = load ptr, ptr %p.559, align 8
  %4 = call i1 @parser_match_val__Struct_Parser_Enum_TokenType_String(ptr %3, i32 5, ptr @.str.s214)
  br i1 %4, label %label_666, label %label_667

label_667:                                        ; preds = %entry
  %5 = load ptr, ptr %arm.560, align 8
  %6 = load ptr, ptr %p.559, align 8
  %7 = call ptr @parse_expression__Struct_Parser_Int(ptr %6, i32 0)
  %8 = call ptr @node_to_ptr(ptr %7)
  %9 = getelementptr inbounds nuw %ASTNode, ptr %5, i32 0, i32 5
  store ptr %8, ptr %9, align 8
  br label %label_668

label_666:                                        ; preds = %entry
  %10 = load ptr, ptr %arm.560, align 8
  %11 = getelementptr inbounds nuw %ASTNode, ptr %10, i32 0, i32 1
  store ptr @.str.s215, ptr %11, align 8
  br label %label_668

label_668:                                        ; preds = %label_667, %label_666
  %12 = load ptr, ptr %p.559, align 8
  call void @parser_expect_val__Struct_Parser_Enum_TokenType_String_String(ptr %12, i32 16, ptr @.str.s216, ptr @.str.s217)
  %13 = load ptr, ptr %arm.560, align 8
  %14 = load ptr, ptr %p.559, align 8
  %15 = call ptr @parse_block__Struct_Parser(ptr %14)
  %16 = call ptr @node_to_ptr(ptr %15)
  %17 = getelementptr inbounds nuw %ASTNode, ptr %13, i32 0, i32 6
  store ptr %16, ptr %17, align 8
  %18 = load ptr, ptr %arm.560, align 8
  ret ptr %18
}

define ptr @parse_match_statement__Struct_Parser(ptr %0) {
entry:
  %p.561 = alloca ptr, align 8
  store ptr %0, ptr %p.561, align 8
  %1 = load ptr, ptr %p.561, align 8
  call void @parser_expect_val__Struct_Parser_Enum_TokenType_String_String(ptr %1, i32 18, ptr @.str.s218, ptr @.str.s219)
  %2 = load ptr, ptr %p.561, align 8
  %3 = call ptr @parser_node__Struct_Parser_Enum_NodeKind(ptr %2, i32 11)
  %match_node.562 = alloca ptr, align 8
  store ptr %3, ptr %match_node.562, align 8
  %4 = load ptr, ptr %p.561, align 8
  call void @parser_expect_val__Struct_Parser_Enum_TokenType_String_String(ptr %4, i32 6, ptr @.str.s220, ptr @.str.s221)
  %5 = load ptr, ptr %match_node.562, align 8
  %6 = load ptr, ptr %p.561, align 8
  %7 = call ptr @parse_expression__Struct_Parser_Int(ptr %6, i32 0)
  %8 = call ptr @node_to_ptr(ptr %7)
  %9 = getelementptr inbounds nuw %ASTNode, ptr %5, i32 0, i32 5
  store ptr %8, ptr %9, align 8
  %10 = load ptr, ptr %p.561, align 8
  call void @parser_expect_val__Struct_Parser_Enum_TokenType_String_String(ptr %10, i32 6, ptr @.str.s222, ptr @.str.s223)
  %11 = load ptr, ptr %p.561, align 8
  call void @parser_expect_val__Struct_Parser_Enum_TokenType_String_String(ptr %11, i32 6, ptr @.str.s224, ptr @.str.s225)
  %head.563 = alloca ptr, align 8
  store ptr @.str.s226, ptr %head.563, align 8
  %tail_ptr.564 = alloca ptr, align 8
  store ptr @.str.s227, ptr %tail_ptr.564, align 8
  %arm.565 = alloca ptr, align 8
  %tail.566 = alloca ptr, align 8
  br label %label_669

label_669:                                        ; preds = %label_674, %entry
  %12 = load ptr, ptr %p.561, align 8
  %13 = call i1 @parser_check_val__Struct_Parser_Enum_TokenType_String(ptr %12, i32 6, ptr @.str.s228)
  %14 = icmp eq i1 %13, false
  br i1 %14, label %label_670, label %label_671

label_671:                                        ; preds = %label_669
  %15 = load ptr, ptr %p.561, align 8
  call void @parser_expect_val__Struct_Parser_Enum_TokenType_String_String(ptr %15, i32 6, ptr @.str.s231, ptr @.str.s232)
  %16 = load ptr, ptr %match_node.562, align 8
  %17 = load ptr, ptr %head.563, align 8
  %18 = getelementptr inbounds nuw %ASTNode, ptr %16, i32 0, i32 6
  store ptr %17, ptr %18, align 8
  %19 = load ptr, ptr %match_node.562, align 8
  ret ptr %19

label_670:                                        ; preds = %label_669
  %20 = load ptr, ptr %p.561, align 8
  %21 = call ptr @parse_match_arm__Struct_Parser(ptr %20)
  store ptr %21, ptr %arm.565, align 8
  %22 = load ptr, ptr %head.563, align 8
  %23 = call i32 @str_equals(ptr %22, ptr @.str.s229)
  %24 = icmp eq i32 %23, 1
  br i1 %24, label %label_672, label %label_673

label_673:                                        ; preds = %label_670
  %25 = load ptr, ptr %tail_ptr.564, align 8
  %26 = call ptr @ptr_to_node(ptr %25)
  store ptr %26, ptr %tail.566, align 8
  %27 = load ptr, ptr %tail.566, align 8
  %28 = load ptr, ptr %arm.565, align 8
  %29 = call ptr @node_to_ptr(ptr %28)
  %30 = getelementptr inbounds nuw %ASTNode, ptr %27, i32 0, i32 8
  store ptr %29, ptr %30, align 8
  %31 = load ptr, ptr %tail.566, align 8
  %32 = getelementptr inbounds nuw %ASTNode, ptr %31, i32 0, i32 8
  %33 = load ptr, ptr %32, align 8
  store ptr %33, ptr %tail_ptr.564, align 8
  br label %label_674

label_672:                                        ; preds = %label_670
  %34 = load ptr, ptr %arm.565, align 8
  %35 = call ptr @node_to_ptr(ptr %34)
  store ptr %35, ptr %head.563, align 8
  %36 = load ptr, ptr %head.563, align 8
  store ptr %36, ptr %tail_ptr.564, align 8
  br label %label_674

label_674:                                        ; preds = %label_673, %label_672
  %37 = load ptr, ptr %p.561, align 8
  %38 = call i1 @parser_match_val__Struct_Parser_Enum_TokenType_String(ptr %37, i32 6, ptr @.str.s230)
  br label %label_669
}

define i32 @get_operator_precedence__Struct_Token(ptr %0) {
entry:
  %t.577 = alloca ptr, align 8
  store ptr %0, ptr %t.577, align 8
  %1 = load ptr, ptr %t.577, align 8
  %2 = getelementptr inbounds nuw %Token, ptr %1, i32 0, i32 1
  %3 = load ptr, ptr %2, align 8
  %4 = call i32 @str_equals(ptr %3, ptr @.str.s247)
  %5 = icmp eq i32 %4, 1
  %sc.62 = alloca i1, align 1
  %sc.63 = alloca i1, align 1
  %sc.64 = alloca i1, align 1
  %sc.65 = alloca i1, align 1
  %sc.66 = alloca i1, align 1
  %sc.67 = alloca i1, align 1
  %sc.68 = alloca i1, align 1
  %sc.69 = alloca i1, align 1
  br i1 %5, label %label_718, label %label_720

label_720:                                        ; preds = %entry
  %6 = load ptr, ptr %t.577, align 8
  %7 = getelementptr inbounds nuw %Token, ptr %6, i32 0, i32 1
  %8 = load ptr, ptr %7, align 8
  %9 = call i32 @str_equals(ptr %8, ptr @.str.s248)
  %10 = icmp eq i32 %9, 1
  br i1 %10, label %label_721, label %label_723

label_718:                                        ; preds = %entry
  ret i32 1

label_723:                                        ; preds = %label_720
  %11 = load ptr, ptr %t.577, align 8
  %12 = getelementptr inbounds nuw %Token, ptr %11, i32 0, i32 0
  %13 = load i32, ptr %12, align 4
  %14 = icmp eq i32 %13, 18
  br i1 %14, label %label_724, label %label_726

label_721:                                        ; preds = %label_720
  ret i32 2

label_726:                                        ; preds = %label_723
  %15 = load ptr, ptr %t.577, align 8
  %16 = getelementptr inbounds nuw %Token, ptr %15, i32 0, i32 1
  %17 = load ptr, ptr %16, align 8
  %18 = call i32 @str_equals(ptr %17, ptr @.str.s249)
  %19 = icmp eq i32 %18, 1
  store i1 %19, ptr %sc.62, align 1
  br i1 %19, label %label_728, label %label_727

label_724:                                        ; preds = %label_723
  ret i32 0

label_727:                                        ; preds = %label_726
  %20 = load ptr, ptr %t.577, align 8
  %21 = getelementptr inbounds nuw %Token, ptr %20, i32 0, i32 1
  %22 = load ptr, ptr %21, align 8
  %23 = call i32 @str_equals(ptr %22, ptr @.str.s250)
  %24 = icmp eq i32 %23, 1
  store i1 %24, ptr %sc.62, align 1
  br label %label_728

label_728:                                        ; preds = %label_727, %label_726
  %25 = load i1, ptr %sc.62, align 1
  br i1 %25, label %label_729, label %label_731

label_731:                                        ; preds = %label_728
  %26 = load ptr, ptr %t.577, align 8
  %27 = getelementptr inbounds nuw %Token, ptr %26, i32 0, i32 1
  %28 = load ptr, ptr %27, align 8
  %29 = call i32 @str_equals(ptr %28, ptr @.str.s251)
  %30 = icmp eq i32 %29, 1
  store i1 %30, ptr %sc.65, align 1
  br i1 %30, label %label_737, label %label_736

label_729:                                        ; preds = %label_728
  ret i32 3

label_736:                                        ; preds = %label_731
  %31 = load ptr, ptr %t.577, align 8
  %32 = getelementptr inbounds nuw %Token, ptr %31, i32 0, i32 1
  %33 = load ptr, ptr %32, align 8
  %34 = call i32 @str_equals(ptr %33, ptr @.str.s252)
  %35 = icmp eq i32 %34, 1
  store i1 %35, ptr %sc.65, align 1
  br label %label_737

label_737:                                        ; preds = %label_736, %label_731
  %36 = load i1, ptr %sc.65, align 1
  store i1 %36, ptr %sc.64, align 1
  br i1 %36, label %label_735, label %label_734

label_734:                                        ; preds = %label_737
  %37 = load ptr, ptr %t.577, align 8
  %38 = getelementptr inbounds nuw %Token, ptr %37, i32 0, i32 1
  %39 = load ptr, ptr %38, align 8
  %40 = call i32 @str_equals(ptr %39, ptr @.str.s253)
  %41 = icmp eq i32 %40, 1
  store i1 %41, ptr %sc.64, align 1
  br label %label_735

label_735:                                        ; preds = %label_734, %label_737
  %42 = load i1, ptr %sc.64, align 1
  store i1 %42, ptr %sc.63, align 1
  br i1 %42, label %label_733, label %label_732

label_732:                                        ; preds = %label_735
  %43 = load ptr, ptr %t.577, align 8
  %44 = getelementptr inbounds nuw %Token, ptr %43, i32 0, i32 1
  %45 = load ptr, ptr %44, align 8
  %46 = call i32 @str_equals(ptr %45, ptr @.str.s254)
  %47 = icmp eq i32 %46, 1
  store i1 %47, ptr %sc.63, align 1
  br label %label_733

label_733:                                        ; preds = %label_732, %label_735
  %48 = load i1, ptr %sc.63, align 1
  br i1 %48, label %label_738, label %label_740

label_740:                                        ; preds = %label_733
  %49 = load ptr, ptr %t.577, align 8
  %50 = getelementptr inbounds nuw %Token, ptr %49, i32 0, i32 1
  %51 = load ptr, ptr %50, align 8
  %52 = call i32 @str_equals(ptr %51, ptr @.str.s255)
  %53 = icmp eq i32 %52, 1
  br i1 %53, label %label_741, label %label_743

label_738:                                        ; preds = %label_733
  ret i32 4

label_743:                                        ; preds = %label_740
  %54 = load ptr, ptr %t.577, align 8
  %55 = getelementptr inbounds nuw %Token, ptr %54, i32 0, i32 1
  %56 = load ptr, ptr %55, align 8
  %57 = call i32 @str_equals(ptr %56, ptr @.str.s256)
  %58 = icmp eq i32 %57, 1
  br i1 %58, label %label_744, label %label_746

label_741:                                        ; preds = %label_740
  ret i32 5

label_746:                                        ; preds = %label_743
  %59 = load ptr, ptr %t.577, align 8
  %60 = getelementptr inbounds nuw %Token, ptr %59, i32 0, i32 1
  %61 = load ptr, ptr %60, align 8
  %62 = call i32 @str_equals(ptr %61, ptr @.str.s257)
  %63 = icmp eq i32 %62, 1
  br i1 %63, label %label_747, label %label_749

label_744:                                        ; preds = %label_743
  ret i32 6

label_749:                                        ; preds = %label_746
  %64 = load ptr, ptr %t.577, align 8
  %65 = getelementptr inbounds nuw %Token, ptr %64, i32 0, i32 1
  %66 = load ptr, ptr %65, align 8
  %67 = call i32 @str_equals(ptr %66, ptr @.str.s258)
  %68 = icmp eq i32 %67, 1
  store i1 %68, ptr %sc.66, align 1
  br i1 %68, label %label_751, label %label_750

label_747:                                        ; preds = %label_746
  ret i32 7

label_750:                                        ; preds = %label_749
  %69 = load ptr, ptr %t.577, align 8
  %70 = getelementptr inbounds nuw %Token, ptr %69, i32 0, i32 1
  %71 = load ptr, ptr %70, align 8
  %72 = call i32 @str_equals(ptr %71, ptr @.str.s259)
  %73 = icmp eq i32 %72, 1
  store i1 %73, ptr %sc.66, align 1
  br label %label_751

label_751:                                        ; preds = %label_750, %label_749
  %74 = load i1, ptr %sc.66, align 1
  br i1 %74, label %label_752, label %label_754

label_754:                                        ; preds = %label_751
  %75 = load ptr, ptr %t.577, align 8
  %76 = getelementptr inbounds nuw %Token, ptr %75, i32 0, i32 1
  %77 = load ptr, ptr %76, align 8
  %78 = call i32 @str_equals(ptr %77, ptr @.str.s260)
  %79 = icmp eq i32 %78, 1
  store i1 %79, ptr %sc.67, align 1
  br i1 %79, label %label_756, label %label_755

label_752:                                        ; preds = %label_751
  ret i32 8

label_755:                                        ; preds = %label_754
  %80 = load ptr, ptr %t.577, align 8
  %81 = getelementptr inbounds nuw %Token, ptr %80, i32 0, i32 1
  %82 = load ptr, ptr %81, align 8
  %83 = call i32 @str_equals(ptr %82, ptr @.str.s261)
  %84 = icmp eq i32 %83, 1
  store i1 %84, ptr %sc.67, align 1
  br label %label_756

label_756:                                        ; preds = %label_755, %label_754
  %85 = load i1, ptr %sc.67, align 1
  br i1 %85, label %label_757, label %label_759

label_759:                                        ; preds = %label_756
  %86 = load ptr, ptr %t.577, align 8
  %87 = getelementptr inbounds nuw %Token, ptr %86, i32 0, i32 1
  %88 = load ptr, ptr %87, align 8
  %89 = call i32 @str_equals(ptr %88, ptr @.str.s262)
  %90 = icmp eq i32 %89, 1
  store i1 %90, ptr %sc.69, align 1
  br i1 %90, label %label_763, label %label_762

label_757:                                        ; preds = %label_756
  ret i32 9

label_762:                                        ; preds = %label_759
  %91 = load ptr, ptr %t.577, align 8
  %92 = getelementptr inbounds nuw %Token, ptr %91, i32 0, i32 1
  %93 = load ptr, ptr %92, align 8
  %94 = call i32 @str_equals(ptr %93, ptr @.str.s263)
  %95 = icmp eq i32 %94, 1
  store i1 %95, ptr %sc.69, align 1
  br label %label_763

label_763:                                        ; preds = %label_762, %label_759
  %96 = load i1, ptr %sc.69, align 1
  store i1 %96, ptr %sc.68, align 1
  br i1 %96, label %label_761, label %label_760

label_760:                                        ; preds = %label_763
  %97 = load ptr, ptr %t.577, align 8
  %98 = getelementptr inbounds nuw %Token, ptr %97, i32 0, i32 1
  %99 = load ptr, ptr %98, align 8
  %100 = call i32 @str_equals(ptr %99, ptr @.str.s264)
  %101 = icmp eq i32 %100, 1
  store i1 %101, ptr %sc.68, align 1
  br label %label_761

label_761:                                        ; preds = %label_760, %label_763
  %102 = load i1, ptr %sc.68, align 1
  br i1 %102, label %label_764, label %label_766

label_766:                                        ; preds = %label_761
  ret i32 0

label_764:                                        ; preds = %label_761
  ret i32 10
}

define ptr @parse_unary__Struct_Parser(ptr %0) {
entry:
  %p.578 = alloca ptr, align 8
  store ptr %0, ptr %p.578, align 8
  %1 = load ptr, ptr %p.578, align 8
  %2 = call ptr @parser_current__Struct_Parser(ptr %1)
  %curr.579 = alloca ptr, align 8
  store ptr %2, ptr %curr.579, align 8
  %sc.70 = alloca i1, align 1
  %3 = load ptr, ptr %curr.579, align 8
  %4 = getelementptr inbounds nuw %Token, ptr %3, i32 0, i32 0
  %5 = load i32, ptr %4, align 4
  %6 = icmp eq i32 %5, 8
  store i1 %6, ptr %sc.70, align 1
  %is_neg.580 = alloca i1, align 1
  %sc.71 = alloca i1, align 1
  %is_not.581 = alloca i1, align 1
  %sc.72 = alloca i1, align 1
  %is_bnot.582 = alloca i1, align 1
  %sc.73 = alloca i1, align 1
  %sc.74 = alloca i1, align 1
  %op.583 = alloca ptr, align 8
  %operand.584 = alloca ptr, align 8
  %sc.75 = alloca i1, align 1
  %sc.76 = alloca i1, align 1
  %is_number.585 = alloca i1, align 1
  %sc.77 = alloca i1, align 1
  %unary.586 = alloca ptr, align 8
  br i1 %6, label %label_767, label %label_768

label_768:                                        ; preds = %label_767, %entry
  %7 = load i1, ptr %sc.70, align 1
  store i1 %7, ptr %is_neg.580, align 1
  %8 = load ptr, ptr %curr.579, align 8
  %9 = getelementptr inbounds nuw %Token, ptr %8, i32 0, i32 0
  %10 = load i32, ptr %9, align 4
  %11 = icmp eq i32 %10, 10
  store i1 %11, ptr %sc.71, align 1
  br i1 %11, label %label_769, label %label_770

label_767:                                        ; preds = %entry
  %12 = load ptr, ptr %curr.579, align 8
  %13 = getelementptr inbounds nuw %Token, ptr %12, i32 0, i32 1
  %14 = load ptr, ptr %13, align 8
  %15 = call i32 @str_equals(ptr %14, ptr @.str.s265)
  %16 = icmp eq i32 %15, 1
  store i1 %16, ptr %sc.70, align 1
  br label %label_768

label_770:                                        ; preds = %label_769, %label_768
  %17 = load i1, ptr %sc.71, align 1
  store i1 %17, ptr %is_not.581, align 1
  %18 = load ptr, ptr %curr.579, align 8
  %19 = getelementptr inbounds nuw %Token, ptr %18, i32 0, i32 0
  %20 = load i32, ptr %19, align 4
  %21 = icmp eq i32 %20, 8
  store i1 %21, ptr %sc.72, align 1
  br i1 %21, label %label_771, label %label_772

label_769:                                        ; preds = %label_768
  %22 = load ptr, ptr %curr.579, align 8
  %23 = getelementptr inbounds nuw %Token, ptr %22, i32 0, i32 1
  %24 = load ptr, ptr %23, align 8
  %25 = call i32 @str_equals(ptr %24, ptr @.str.s266)
  %26 = icmp eq i32 %25, 1
  store i1 %26, ptr %sc.71, align 1
  br label %label_770

label_772:                                        ; preds = %label_771, %label_770
  %27 = load i1, ptr %sc.72, align 1
  store i1 %27, ptr %is_bnot.582, align 1
  %28 = load i1, ptr %is_neg.580, align 1
  store i1 %28, ptr %sc.74, align 1
  br i1 %28, label %label_776, label %label_775

label_771:                                        ; preds = %label_770
  %29 = load ptr, ptr %curr.579, align 8
  %30 = getelementptr inbounds nuw %Token, ptr %29, i32 0, i32 1
  %31 = load ptr, ptr %30, align 8
  %32 = call i32 @str_equals(ptr %31, ptr @.str.s267)
  %33 = icmp eq i32 %32, 1
  store i1 %33, ptr %sc.72, align 1
  br label %label_772

label_775:                                        ; preds = %label_772
  %34 = load i1, ptr %is_not.581, align 1
  store i1 %34, ptr %sc.74, align 1
  br label %label_776

label_776:                                        ; preds = %label_775, %label_772
  %35 = load i1, ptr %sc.74, align 1
  store i1 %35, ptr %sc.73, align 1
  br i1 %35, label %label_774, label %label_773

label_773:                                        ; preds = %label_776
  %36 = load i1, ptr %is_bnot.582, align 1
  store i1 %36, ptr %sc.73, align 1
  br label %label_774

label_774:                                        ; preds = %label_773, %label_776
  %37 = load i1, ptr %sc.73, align 1
  br i1 %37, label %label_777, label %label_779

label_779:                                        ; preds = %label_774
  %38 = load ptr, ptr %p.578, align 8
  %39 = call ptr @parse_postfix__Struct_Parser(ptr %38)
  ret ptr %39

label_777:                                        ; preds = %label_774
  %40 = load ptr, ptr %curr.579, align 8
  %41 = getelementptr inbounds nuw %Token, ptr %40, i32 0, i32 1
  %42 = load ptr, ptr %41, align 8
  store ptr %42, ptr %op.583, align 8
  %43 = load ptr, ptr %p.578, align 8
  call void @parser_advance__Struct_Parser(ptr %43)
  %44 = load ptr, ptr %p.578, align 8
  %45 = call ptr @parse_unary__Struct_Parser(ptr %44)
  store ptr %45, ptr %operand.584, align 8
  %46 = load ptr, ptr %op.583, align 8
  %47 = call i32 @str_equals(ptr %46, ptr @.str.s268)
  %48 = icmp eq i32 %47, 1
  store i1 %48, ptr %sc.75, align 1
  br i1 %48, label %label_780, label %label_781

label_781:                                        ; preds = %label_780, %label_777
  %49 = load i1, ptr %sc.75, align 1
  br i1 %49, label %label_782, label %label_784

label_780:                                        ; preds = %label_777
  %50 = load ptr, ptr %operand.584, align 8
  %51 = getelementptr inbounds nuw %ASTNode, ptr %50, i32 0, i32 0
  %52 = load i32, ptr %51, align 4
  %53 = icmp eq i32 %52, 22
  store i1 %53, ptr %sc.75, align 1
  br label %label_781

label_784:                                        ; preds = %label_791, %label_781
  %54 = load ptr, ptr %p.578, align 8
  %55 = call ptr @parser_node__Struct_Parser_Enum_NodeKind(ptr %54, i32 21)
  store ptr %55, ptr %unary.586, align 8
  %56 = load ptr, ptr %unary.586, align 8
  %57 = load ptr, ptr %op.583, align 8
  %58 = getelementptr inbounds nuw %ASTNode, ptr %56, i32 0, i32 1
  store ptr %57, ptr %58, align 8
  %59 = load ptr, ptr %unary.586, align 8
  %60 = load ptr, ptr %operand.584, align 8
  %61 = call ptr @node_to_ptr(ptr %60)
  %62 = getelementptr inbounds nuw %ASTNode, ptr %59, i32 0, i32 5
  store ptr %61, ptr %62, align 8
  %63 = load ptr, ptr %unary.586, align 8
  ret ptr %63

label_782:                                        ; preds = %label_781
  %64 = load ptr, ptr %operand.584, align 8
  %65 = getelementptr inbounds nuw %ASTNode, ptr %64, i32 0, i32 3
  %66 = load i32, ptr %65, align 4
  %67 = icmp eq i32 %66, 2
  store i1 %67, ptr %sc.76, align 1
  br i1 %67, label %label_786, label %label_785

label_785:                                        ; preds = %label_782
  %68 = load ptr, ptr %operand.584, align 8
  %69 = getelementptr inbounds nuw %ASTNode, ptr %68, i32 0, i32 3
  %70 = load i32, ptr %69, align 4
  %71 = icmp eq i32 %70, 3
  store i1 %71, ptr %sc.76, align 1
  br label %label_786

label_786:                                        ; preds = %label_785, %label_782
  %72 = load i1, ptr %sc.76, align 1
  store i1 %72, ptr %is_number.585, align 1
  %73 = load i1, ptr %is_number.585, align 1
  store i1 %73, ptr %sc.77, align 1
  br i1 %73, label %label_787, label %label_788

label_788:                                        ; preds = %label_787, %label_786
  %74 = load i1, ptr %sc.77, align 1
  br i1 %74, label %label_789, label %label_791

label_787:                                        ; preds = %label_786
  %75 = load ptr, ptr %operand.584, align 8
  %76 = getelementptr inbounds nuw %ASTNode, ptr %75, i32 0, i32 1
  %77 = load ptr, ptr %76, align 8
  %78 = call i32 @str_starts_with(ptr %77, ptr @.str.s269)
  %79 = icmp eq i32 %78, 0
  store i1 %79, ptr %sc.77, align 1
  br label %label_788

label_791:                                        ; preds = %label_788
  br label %label_784

label_789:                                        ; preds = %label_788
  %80 = load ptr, ptr %operand.584, align 8
  %81 = load ptr, ptr %operand.584, align 8
  %82 = getelementptr inbounds nuw %ASTNode, ptr %81, i32 0, i32 1
  %83 = load ptr, ptr %82, align 8
  %84 = call ptr @str_concat(ptr @.str.s270, ptr %83)
  %85 = getelementptr inbounds nuw %ASTNode, ptr %80, i32 0, i32 1
  store ptr %84, ptr %85, align 8
  %86 = load ptr, ptr %operand.584, align 8
  %87 = load ptr, ptr %curr.579, align 8
  %88 = getelementptr inbounds nuw %Token, ptr %87, i32 0, i32 2
  %89 = load i32, ptr %88, align 4
  %90 = getelementptr inbounds nuw %ASTNode, ptr %86, i32 0, i32 10
  store i32 %89, ptr %90, align 4
  %91 = load ptr, ptr %operand.584, align 8
  %92 = load ptr, ptr %curr.579, align 8
  %93 = getelementptr inbounds nuw %Token, ptr %92, i32 0, i32 3
  %94 = load i32, ptr %93, align 4
  %95 = getelementptr inbounds nuw %ASTNode, ptr %91, i32 0, i32 11
  store i32 %94, ptr %95, align 4
  %96 = load ptr, ptr %operand.584, align 8
  %97 = load ptr, ptr %operand.584, align 8
  %98 = getelementptr inbounds nuw %ASTNode, ptr %97, i32 0, i32 12
  %99 = load i32, ptr %98, align 4
  %100 = add i32 %99, 1
  %101 = getelementptr inbounds nuw %ASTNode, ptr %96, i32 0, i32 12
  store i32 %100, ptr %101, align 4
  %102 = load ptr, ptr %operand.584, align 8
  ret ptr %102
}

define ptr @parse_postfix__Struct_Parser(ptr %0) {
entry:
  %p.587 = alloca ptr, align 8
  store ptr %0, ptr %p.587, align 8
  %1 = load ptr, ptr %p.587, align 8
  %2 = call ptr @parse_primary__Struct_Parser(ptr %1)
  %expr.588 = alloca ptr, align 8
  store ptr %2, ptr %expr.588, align 8
  %casting.589 = alloca i1, align 1
  store i1 true, ptr %casting.589, align 1
  %cast.590 = alloca ptr, align 8
  br label %label_792

label_792:                                        ; preds = %label_797, %entry
  %3 = load i1, ptr %casting.589, align 1
  br i1 %3, label %label_793, label %label_794

label_794:                                        ; preds = %label_792
  %4 = load ptr, ptr %expr.588, align 8
  ret ptr %4

label_793:                                        ; preds = %label_792
  %5 = load ptr, ptr %p.587, align 8
  %6 = call i1 @parser_match_val__Struct_Parser_Enum_TokenType_String(ptr %5, i32 18, ptr @.str.s271)
  br i1 %6, label %label_795, label %label_796

label_796:                                        ; preds = %label_793
  store i1 false, ptr %casting.589, align 1
  br label %label_797

label_795:                                        ; preds = %label_793
  %7 = load ptr, ptr %p.587, align 8
  %8 = call ptr @parser_node__Struct_Parser_Enum_NodeKind(ptr %7, i32 29)
  store ptr %8, ptr %cast.590, align 8
  %9 = load ptr, ptr %cast.590, align 8
  %10 = load ptr, ptr %expr.588, align 8
  %11 = call ptr @node_to_ptr(ptr %10)
  %12 = getelementptr inbounds nuw %ASTNode, ptr %9, i32 0, i32 5
  store ptr %11, ptr %12, align 8
  %13 = load ptr, ptr %cast.590, align 8
  %14 = load ptr, ptr %p.587, align 8
  %15 = call ptr @parse_type_annotation__Struct_Parser(ptr %14)
  %16 = call ptr @node_to_ptr(ptr %15)
  %17 = getelementptr inbounds nuw %ASTNode, ptr %13, i32 0, i32 6
  store ptr %16, ptr %17, align 8
  %18 = load ptr, ptr %cast.590, align 8
  store ptr %18, ptr %expr.588, align 8
  br label %label_797

label_797:                                        ; preds = %label_796, %label_795
  br label %label_792
}

define ptr @parse_primary__Struct_Parser(ptr %0) {
entry:
  %p.601 = alloca ptr, align 8
  store ptr %0, ptr %p.601, align 8
  %1 = load ptr, ptr %p.601, align 8
  %2 = call ptr @parser_current__Struct_Parser(ptr %1)
  %curr.602 = alloca ptr, align 8
  store ptr %2, ptr %curr.602, align 8
  %sc.82 = alloca i1, align 1
  %sc.83 = alloca i1, align 1
  %sc.84 = alloca i1, align 1
  %sc.85 = alloca i1, align 1
  %3 = load ptr, ptr %curr.602, align 8
  %4 = getelementptr inbounds nuw %Token, ptr %3, i32 0, i32 0
  %5 = load i32, ptr %4, align 4
  %6 = icmp eq i32 %5, 2
  store i1 %6, ptr %sc.85, align 1
  %lit.603 = alloca ptr, align 8
  %next_tok.604 = alloca ptr, align 8
  %sc.86 = alloca i1, align 1
  %sc.87 = alloca i1, align 1
  %struct_lit.605 = alloca ptr, align 8
  %last_field.606 = alloca ptr, align 8
  %field.607 = alloca ptr, align 8
  %field_tok.608 = alloca ptr, align 8
  %last.609 = alloca ptr, align 8
  %ident.610 = alloca ptr, align 8
  %expr.611 = alloca ptr, align 8
  %is_looping.612 = alloca i1, align 1
  %call.613 = alloca ptr, align 8
  %last_arg.614 = alloca ptr, align 8
  %is_arg_looping.615 = alloca i1, align 1
  %arg.616 = alloca ptr, align 8
  %last.617 = alloca ptr, align 8
  %index_node.618 = alloca ptr, align 8
  %member_node.619 = alloca ptr, align 8
  %curr_mem.620 = alloca ptr, align 8
  %expr_inner.621 = alloca ptr, align 8
  %array_lit.622 = alloca ptr, align 8
  %last_elem.623 = alloca ptr, align 8
  %is_looping.624 = alloca i1, align 1
  %elem.625 = alloca ptr, align 8
  %last.626 = alloca ptr, align 8
  br i1 %6, label %label_822, label %label_821

label_821:                                        ; preds = %entry
  %7 = load ptr, ptr %curr.602, align 8
  %8 = getelementptr inbounds nuw %Token, ptr %7, i32 0, i32 0
  %9 = load i32, ptr %8, align 4
  %10 = icmp eq i32 %9, 3
  store i1 %10, ptr %sc.85, align 1
  br label %label_822

label_822:                                        ; preds = %label_821, %entry
  %11 = load i1, ptr %sc.85, align 1
  store i1 %11, ptr %sc.84, align 1
  br i1 %11, label %label_820, label %label_819

label_819:                                        ; preds = %label_822
  %12 = load ptr, ptr %curr.602, align 8
  %13 = getelementptr inbounds nuw %Token, ptr %12, i32 0, i32 0
  %14 = load i32, ptr %13, align 4
  %15 = icmp eq i32 %14, 0
  store i1 %15, ptr %sc.84, align 1
  br label %label_820

label_820:                                        ; preds = %label_819, %label_822
  %16 = load i1, ptr %sc.84, align 1
  store i1 %16, ptr %sc.83, align 1
  br i1 %16, label %label_818, label %label_817

label_817:                                        ; preds = %label_820
  %17 = load ptr, ptr %curr.602, align 8
  %18 = getelementptr inbounds nuw %Token, ptr %17, i32 0, i32 0
  %19 = load i32, ptr %18, align 4
  %20 = icmp eq i32 %19, 4
  store i1 %20, ptr %sc.83, align 1
  br label %label_818

label_818:                                        ; preds = %label_817, %label_820
  %21 = load i1, ptr %sc.83, align 1
  store i1 %21, ptr %sc.82, align 1
  br i1 %21, label %label_816, label %label_815

label_815:                                        ; preds = %label_818
  %22 = load ptr, ptr %curr.602, align 8
  %23 = getelementptr inbounds nuw %Token, ptr %22, i32 0, i32 0
  %24 = load i32, ptr %23, align 4
  %25 = icmp eq i32 %24, 1
  store i1 %25, ptr %sc.82, align 1
  br label %label_816

label_816:                                        ; preds = %label_815, %label_818
  %26 = load i1, ptr %sc.82, align 1
  br i1 %26, label %label_823, label %label_825

label_825:                                        ; preds = %label_816
  %27 = load ptr, ptr %curr.602, align 8
  %28 = getelementptr inbounds nuw %Token, ptr %27, i32 0, i32 0
  %29 = load i32, ptr %28, align 4
  %30 = icmp eq i32 %29, 5
  br i1 %30, label %label_826, label %label_828

label_823:                                        ; preds = %label_816
  %31 = load ptr, ptr %p.601, align 8
  %32 = call ptr @parser_node__Struct_Parser_Enum_NodeKind(ptr %31, i32 22)
  store ptr %32, ptr %lit.603, align 8
  %33 = load ptr, ptr %lit.603, align 8
  %34 = load ptr, ptr %curr.602, align 8
  %35 = getelementptr inbounds nuw %Token, ptr %34, i32 0, i32 0
  %36 = load i32, ptr %35, align 4
  %37 = getelementptr inbounds nuw %ASTNode, ptr %33, i32 0, i32 3
  store i32 %36, ptr %37, align 4
  %38 = load ptr, ptr %lit.603, align 8
  %39 = load ptr, ptr %curr.602, align 8
  %40 = getelementptr inbounds nuw %Token, ptr %39, i32 0, i32 1
  %41 = load ptr, ptr %40, align 8
  %42 = getelementptr inbounds nuw %ASTNode, ptr %38, i32 0, i32 1
  store ptr %41, ptr %42, align 8
  %43 = load ptr, ptr %p.601, align 8
  call void @parser_advance__Struct_Parser(ptr %43)
  %44 = load ptr, ptr %lit.603, align 8
  ret ptr %44

label_828:                                        ; preds = %label_835, %label_825
  %45 = load ptr, ptr %curr.602, align 8
  %46 = getelementptr inbounds nuw %Token, ptr %45, i32 0, i32 0
  %47 = load i32, ptr %46, align 4
  %48 = icmp eq i32 %47, 5
  br i1 %48, label %label_842, label %label_844

label_826:                                        ; preds = %label_825
  %49 = load ptr, ptr %p.601, align 8
  %50 = call ptr @parser_peek__Struct_Parser(ptr %49)
  store ptr %50, ptr %next_tok.604, align 8
  %51 = load ptr, ptr %next_tok.604, align 8
  %52 = getelementptr inbounds nuw %Token, ptr %51, i32 0, i32 0
  %53 = load i32, ptr %52, align 4
  %54 = icmp eq i32 %53, 6
  store i1 %54, ptr %sc.87, align 1
  br i1 %54, label %label_831, label %label_832

label_832:                                        ; preds = %label_831, %label_826
  %55 = load i1, ptr %sc.87, align 1
  store i1 %55, ptr %sc.86, align 1
  br i1 %55, label %label_829, label %label_830

label_831:                                        ; preds = %label_826
  %56 = load ptr, ptr %next_tok.604, align 8
  %57 = getelementptr inbounds nuw %Token, ptr %56, i32 0, i32 1
  %58 = load ptr, ptr %57, align 8
  %59 = call i32 @str_equals(ptr %58, ptr @.str.s274)
  %60 = icmp eq i32 %59, 1
  store i1 %60, ptr %sc.87, align 1
  br label %label_832

label_830:                                        ; preds = %label_829, %label_832
  %61 = load i1, ptr %sc.86, align 1
  br i1 %61, label %label_833, label %label_835

label_829:                                        ; preds = %label_832
  %62 = load i32, ptr @parser_allow_struct_lit, align 4
  %63 = icmp eq i32 %62, 1
  store i1 %63, ptr %sc.86, align 1
  br label %label_830

label_835:                                        ; preds = %label_830
  br label %label_828

label_833:                                        ; preds = %label_830
  %64 = load ptr, ptr %p.601, align 8
  %65 = call ptr @parser_node__Struct_Parser_Enum_NodeKind(ptr %64, i32 28)
  store ptr %65, ptr %struct_lit.605, align 8
  %66 = load ptr, ptr %struct_lit.605, align 8
  %67 = load ptr, ptr %curr.602, align 8
  %68 = getelementptr inbounds nuw %Token, ptr %67, i32 0, i32 1
  %69 = load ptr, ptr %68, align 8
  %70 = getelementptr inbounds nuw %ASTNode, ptr %66, i32 0, i32 1
  store ptr %69, ptr %70, align 8
  %71 = load ptr, ptr %p.601, align 8
  call void @parser_advance__Struct_Parser(ptr %71)
  %72 = load ptr, ptr %p.601, align 8
  call void @parser_expect_val__Struct_Parser_Enum_TokenType_String_String(ptr %72, i32 6, ptr @.str.s275, ptr @.str.s276)
  store ptr @.str.s277, ptr %last_field.606, align 8
  br label %label_836

label_836:                                        ; preds = %label_841, %label_833
  %73 = load ptr, ptr %p.601, align 8
  %74 = call i1 @parser_check_val__Struct_Parser_Enum_TokenType_String(ptr %73, i32 6, ptr @.str.s278)
  %75 = icmp eq i1 %74, false
  br i1 %75, label %label_837, label %label_838

label_838:                                        ; preds = %label_836
  %76 = load ptr, ptr %p.601, align 8
  call void @parser_expect_val__Struct_Parser_Enum_TokenType_String_String(ptr %76, i32 6, ptr @.str.s284, ptr @.str.s285)
  %77 = load ptr, ptr %struct_lit.605, align 8
  ret ptr %77

label_837:                                        ; preds = %label_836
  %78 = load ptr, ptr %p.601, align 8
  %79 = call ptr @parser_node__Struct_Parser_Enum_NodeKind(ptr %78, i32 32)
  store ptr %79, ptr %field.607, align 8
  %80 = load ptr, ptr %p.601, align 8
  %81 = call ptr @parser_current__Struct_Parser(ptr %80)
  store ptr %81, ptr %field_tok.608, align 8
  %82 = load ptr, ptr %field.607, align 8
  %83 = load ptr, ptr %field_tok.608, align 8
  %84 = getelementptr inbounds nuw %Token, ptr %83, i32 0, i32 1
  %85 = load ptr, ptr %84, align 8
  %86 = getelementptr inbounds nuw %ASTNode, ptr %82, i32 0, i32 1
  store ptr %85, ptr %86, align 8
  %87 = load ptr, ptr %p.601, align 8
  call void @parser_expect__Struct_Parser_Enum_TokenType_String(ptr %87, i32 5, ptr @.str.s279)
  %88 = load ptr, ptr %p.601, align 8
  call void @parser_expect_val__Struct_Parser_Enum_TokenType_String_String(ptr %88, i32 6, ptr @.str.s280, ptr @.str.s281)
  %89 = load ptr, ptr %field.607, align 8
  %90 = load ptr, ptr %p.601, align 8
  %91 = call ptr @parse_expression__Struct_Parser_Int(ptr %90, i32 0)
  %92 = call ptr @node_to_ptr(ptr %91)
  %93 = getelementptr inbounds nuw %ASTNode, ptr %89, i32 0, i32 5
  store ptr %92, ptr %93, align 8
  %94 = load ptr, ptr %struct_lit.605, align 8
  %95 = getelementptr inbounds nuw %ASTNode, ptr %94, i32 0, i32 5
  %96 = load ptr, ptr %95, align 8
  %97 = call i32 @str_equals(ptr %96, ptr @.str.s282)
  %98 = icmp eq i32 %97, 1
  br i1 %98, label %label_839, label %label_840

label_840:                                        ; preds = %label_837
  %99 = load ptr, ptr %last_field.606, align 8
  %100 = call ptr @ptr_to_node(ptr %99)
  store ptr %100, ptr %last.609, align 8
  %101 = load ptr, ptr %last.609, align 8
  %102 = load ptr, ptr %field.607, align 8
  %103 = call ptr @node_to_ptr(ptr %102)
  %104 = getelementptr inbounds nuw %ASTNode, ptr %101, i32 0, i32 8
  store ptr %103, ptr %104, align 8
  br label %label_841

label_839:                                        ; preds = %label_837
  %105 = load ptr, ptr %struct_lit.605, align 8
  %106 = load ptr, ptr %field.607, align 8
  %107 = call ptr @node_to_ptr(ptr %106)
  %108 = getelementptr inbounds nuw %ASTNode, ptr %105, i32 0, i32 5
  store ptr %107, ptr %108, align 8
  br label %label_841

label_841:                                        ; preds = %label_840, %label_839
  %109 = load ptr, ptr %field.607, align 8
  %110 = call ptr @node_to_ptr(ptr %109)
  store ptr %110, ptr %last_field.606, align 8
  %111 = load ptr, ptr %p.601, align 8
  %112 = call i1 @parser_match_val__Struct_Parser_Enum_TokenType_String(ptr %111, i32 6, ptr @.str.s283)
  br label %label_836

label_844:                                        ; preds = %label_828
  %113 = load ptr, ptr %p.601, align 8
  %114 = call i1 @parser_match_val__Struct_Parser_Enum_TokenType_String(ptr %113, i32 6, ptr @.str.s298)
  br i1 %114, label %label_869, label %label_871

label_842:                                        ; preds = %label_828
  %115 = load ptr, ptr %p.601, align 8
  %116 = call ptr @parser_node__Struct_Parser_Enum_NodeKind(ptr %115, i32 23)
  store ptr %116, ptr %ident.610, align 8
  %117 = load ptr, ptr %ident.610, align 8
  %118 = load ptr, ptr %curr.602, align 8
  %119 = getelementptr inbounds nuw %Token, ptr %118, i32 0, i32 1
  %120 = load ptr, ptr %119, align 8
  %121 = getelementptr inbounds nuw %ASTNode, ptr %117, i32 0, i32 1
  store ptr %120, ptr %121, align 8
  %122 = load ptr, ptr %p.601, align 8
  call void @parser_advance__Struct_Parser(ptr %122)
  %123 = load ptr, ptr %ident.610, align 8
  store ptr %123, ptr %expr.611, align 8
  store i1 true, ptr %is_looping.612, align 1
  br label %label_845

label_845:                                        ; preds = %label_850, %label_842
  %124 = load i1, ptr %is_looping.612, align 1
  br i1 %124, label %label_846, label %label_847

label_847:                                        ; preds = %label_845
  %125 = load ptr, ptr %expr.611, align 8
  ret ptr %125

label_846:                                        ; preds = %label_845
  %126 = load ptr, ptr %p.601, align 8
  %127 = call i1 @parser_match_val__Struct_Parser_Enum_TokenType_String(ptr %126, i32 6, ptr @.str.s286)
  br i1 %127, label %label_848, label %label_849

label_849:                                        ; preds = %label_846
  %128 = load ptr, ptr %p.601, align 8
  %129 = call i1 @parser_match_val__Struct_Parser_Enum_TokenType_String(ptr %128, i32 6, ptr @.str.s293)
  br i1 %129, label %label_863, label %label_864

label_848:                                        ; preds = %label_846
  %130 = load ptr, ptr %p.601, align 8
  %131 = call ptr @parser_node__Struct_Parser_Enum_NodeKind(ptr %130, i32 24)
  store ptr %131, ptr %call.613, align 8
  %132 = load ptr, ptr %call.613, align 8
  %133 = load ptr, ptr %expr.611, align 8
  call void @node_span_from__Struct_ASTNode_Struct_ASTNode(ptr %132, ptr %133)
  %134 = load ptr, ptr %call.613, align 8
  %135 = load ptr, ptr %expr.611, align 8
  %136 = call ptr @node_to_ptr(ptr %135)
  %137 = getelementptr inbounds nuw %ASTNode, ptr %134, i32 0, i32 5
  store ptr %136, ptr %137, align 8
  store ptr @.str.s287, ptr %last_arg.614, align 8
  %138 = load ptr, ptr %p.601, align 8
  %139 = call i1 @parser_check_val__Struct_Parser_Enum_TokenType_String(ptr %138, i32 6, ptr @.str.s288)
  %140 = icmp eq i1 %139, false
  br i1 %140, label %label_851, label %label_853

label_853:                                        ; preds = %label_856, %label_848
  %141 = load ptr, ptr %p.601, align 8
  call void @parser_expect_val__Struct_Parser_Enum_TokenType_String_String(ptr %141, i32 6, ptr @.str.s291, ptr @.str.s292)
  %142 = load ptr, ptr %call.613, align 8
  store ptr %142, ptr %expr.611, align 8
  br label %label_850

label_851:                                        ; preds = %label_848
  store i1 true, ptr %is_arg_looping.615, align 1
  br label %label_854

label_854:                                        ; preds = %label_862, %label_851
  %143 = load i1, ptr %is_arg_looping.615, align 1
  br i1 %143, label %label_855, label %label_856

label_856:                                        ; preds = %label_854
  br label %label_853

label_855:                                        ; preds = %label_854
  %144 = load ptr, ptr %p.601, align 8
  %145 = call ptr @parse_expression__Struct_Parser_Int(ptr %144, i32 0)
  store ptr %145, ptr %arg.616, align 8
  %146 = load ptr, ptr %call.613, align 8
  %147 = getelementptr inbounds nuw %ASTNode, ptr %146, i32 0, i32 6
  %148 = load ptr, ptr %147, align 8
  %149 = call i32 @str_equals(ptr %148, ptr @.str.s289)
  %150 = icmp eq i32 %149, 1
  br i1 %150, label %label_857, label %label_858

label_858:                                        ; preds = %label_855
  %151 = load ptr, ptr %last_arg.614, align 8
  %152 = call ptr @ptr_to_node(ptr %151)
  store ptr %152, ptr %last.617, align 8
  %153 = load ptr, ptr %last.617, align 8
  %154 = load ptr, ptr %arg.616, align 8
  %155 = call ptr @node_to_ptr(ptr %154)
  %156 = getelementptr inbounds nuw %ASTNode, ptr %153, i32 0, i32 8
  store ptr %155, ptr %156, align 8
  br label %label_859

label_857:                                        ; preds = %label_855
  %157 = load ptr, ptr %call.613, align 8
  %158 = load ptr, ptr %arg.616, align 8
  %159 = call ptr @node_to_ptr(ptr %158)
  %160 = getelementptr inbounds nuw %ASTNode, ptr %157, i32 0, i32 6
  store ptr %159, ptr %160, align 8
  br label %label_859

label_859:                                        ; preds = %label_858, %label_857
  %161 = load ptr, ptr %arg.616, align 8
  %162 = call ptr @node_to_ptr(ptr %161)
  store ptr %162, ptr %last_arg.614, align 8
  %163 = load ptr, ptr %p.601, align 8
  %164 = call i1 @parser_match_val__Struct_Parser_Enum_TokenType_String(ptr %163, i32 6, ptr @.str.s290)
  %165 = icmp eq i1 %164, false
  br i1 %165, label %label_860, label %label_862

label_862:                                        ; preds = %label_860, %label_859
  br label %label_854

label_860:                                        ; preds = %label_859
  store i1 false, ptr %is_arg_looping.615, align 1
  br label %label_862

label_850:                                        ; preds = %label_865, %label_853
  br label %label_845

label_864:                                        ; preds = %label_849
  %166 = load ptr, ptr %p.601, align 8
  %167 = call i1 @parser_match_val__Struct_Parser_Enum_TokenType_String(ptr %166, i32 6, ptr @.str.s296)
  br i1 %167, label %label_866, label %label_867

label_863:                                        ; preds = %label_849
  %168 = load ptr, ptr %p.601, align 8
  %169 = call ptr @parser_node__Struct_Parser_Enum_NodeKind(ptr %168, i32 26)
  store ptr %169, ptr %index_node.618, align 8
  %170 = load ptr, ptr %index_node.618, align 8
  %171 = load ptr, ptr %expr.611, align 8
  %172 = call ptr @node_to_ptr(ptr %171)
  %173 = getelementptr inbounds nuw %ASTNode, ptr %170, i32 0, i32 5
  store ptr %172, ptr %173, align 8
  %174 = load ptr, ptr %index_node.618, align 8
  %175 = load ptr, ptr %p.601, align 8
  %176 = call ptr @parse_expression__Struct_Parser_Int(ptr %175, i32 0)
  %177 = call ptr @node_to_ptr(ptr %176)
  %178 = getelementptr inbounds nuw %ASTNode, ptr %174, i32 0, i32 6
  store ptr %177, ptr %178, align 8
  %179 = load ptr, ptr %p.601, align 8
  call void @parser_expect_val__Struct_Parser_Enum_TokenType_String_String(ptr %179, i32 6, ptr @.str.s294, ptr @.str.s295)
  %180 = load ptr, ptr %index_node.618, align 8
  store ptr %180, ptr %expr.611, align 8
  br label %label_865

label_865:                                        ; preds = %label_868, %label_863
  br label %label_850

label_867:                                        ; preds = %label_864
  store i1 false, ptr %is_looping.612, align 1
  br label %label_868

label_866:                                        ; preds = %label_864
  %181 = load ptr, ptr %p.601, align 8
  %182 = call ptr @parser_node__Struct_Parser_Enum_NodeKind(ptr %181, i32 25)
  store ptr %182, ptr %member_node.619, align 8
  %183 = load ptr, ptr %member_node.619, align 8
  %184 = load ptr, ptr %expr.611, align 8
  %185 = call ptr @node_to_ptr(ptr %184)
  %186 = getelementptr inbounds nuw %ASTNode, ptr %183, i32 0, i32 5
  store ptr %185, ptr %186, align 8
  %187 = load ptr, ptr %p.601, align 8
  %188 = call ptr @parser_current__Struct_Parser(ptr %187)
  store ptr %188, ptr %curr_mem.620, align 8
  %189 = load ptr, ptr %member_node.619, align 8
  %190 = load ptr, ptr %curr_mem.620, align 8
  %191 = getelementptr inbounds nuw %Token, ptr %190, i32 0, i32 1
  %192 = load ptr, ptr %191, align 8
  %193 = getelementptr inbounds nuw %ASTNode, ptr %189, i32 0, i32 1
  store ptr %192, ptr %193, align 8
  %194 = load ptr, ptr %p.601, align 8
  call void @parser_expect__Struct_Parser_Enum_TokenType_String(ptr %194, i32 5, ptr @.str.s297)
  %195 = load ptr, ptr %member_node.619, align 8
  store ptr %195, ptr %expr.611, align 8
  br label %label_868

label_868:                                        ; preds = %label_867, %label_866
  br label %label_865

label_871:                                        ; preds = %label_844
  %196 = load ptr, ptr %p.601, align 8
  %197 = call i1 @parser_match_val__Struct_Parser_Enum_TokenType_String(ptr %196, i32 6, ptr @.str.s301)
  br i1 %197, label %label_872, label %label_874

label_869:                                        ; preds = %label_844
  %198 = load ptr, ptr %p.601, align 8
  %199 = call ptr @parse_expression__Struct_Parser_Int(ptr %198, i32 0)
  store ptr %199, ptr %expr_inner.621, align 8
  %200 = load ptr, ptr %p.601, align 8
  call void @parser_expect_val__Struct_Parser_Enum_TokenType_String_String(ptr %200, i32 6, ptr @.str.s299, ptr @.str.s300)
  %201 = load ptr, ptr %expr_inner.621, align 8
  ret ptr %201

label_874:                                        ; preds = %label_871
  %202 = load ptr, ptr %p.601, align 8
  %203 = load ptr, ptr %curr.602, align 8
  %204 = call ptr @parser_describe__Struct_Token(ptr %203)
  %205 = call ptr @str_concat(ptr @.str.s308, ptr %204)
  %206 = load ptr, ptr %curr.602, align 8
  %207 = getelementptr inbounds nuw %Token, ptr %206, i32 0, i32 0
  %208 = load i32, ptr %207, align 4
  %209 = call ptr @type_to_string__Enum_TokenType(i32 %208)
  %210 = call ptr @str_concat(ptr %209, ptr @.str.s310)
  %211 = call ptr @str_concat(ptr @.str.s309, ptr %210)
  %212 = call ptr @str_concat(ptr %205, ptr %211)
  call void @parser_fatal__Struct_Parser_String(ptr %202, ptr %212)
  %213 = load ptr, ptr %p.601, align 8
  %214 = call ptr @parser_node__Struct_Parser_Enum_NodeKind(ptr %213, i32 35)
  ret ptr %214

label_872:                                        ; preds = %label_871
  %215 = load ptr, ptr %p.601, align 8
  %216 = call ptr @parser_node__Struct_Parser_Enum_NodeKind(ptr %215, i32 27)
  store ptr %216, ptr %array_lit.622, align 8
  store ptr @.str.s302, ptr %last_elem.623, align 8
  %217 = load ptr, ptr %p.601, align 8
  %218 = call i1 @parser_check_val__Struct_Parser_Enum_TokenType_String(ptr %217, i32 6, ptr @.str.s303)
  %219 = icmp eq i1 %218, false
  br i1 %219, label %label_875, label %label_877

label_877:                                        ; preds = %label_880, %label_872
  %220 = load ptr, ptr %p.601, align 8
  call void @parser_expect_val__Struct_Parser_Enum_TokenType_String_String(ptr %220, i32 6, ptr @.str.s306, ptr @.str.s307)
  %221 = load ptr, ptr %array_lit.622, align 8
  ret ptr %221

label_875:                                        ; preds = %label_872
  store i1 true, ptr %is_looping.624, align 1
  br label %label_878

label_878:                                        ; preds = %label_886, %label_875
  %222 = load i1, ptr %is_looping.624, align 1
  br i1 %222, label %label_879, label %label_880

label_880:                                        ; preds = %label_878
  br label %label_877

label_879:                                        ; preds = %label_878
  %223 = load ptr, ptr %p.601, align 8
  %224 = call ptr @parse_expression__Struct_Parser_Int(ptr %223, i32 0)
  store ptr %224, ptr %elem.625, align 8
  %225 = load ptr, ptr %array_lit.622, align 8
  %226 = getelementptr inbounds nuw %ASTNode, ptr %225, i32 0, i32 5
  %227 = load ptr, ptr %226, align 8
  %228 = call i32 @str_equals(ptr %227, ptr @.str.s304)
  %229 = icmp eq i32 %228, 1
  br i1 %229, label %label_881, label %label_882

label_882:                                        ; preds = %label_879
  %230 = load ptr, ptr %last_elem.623, align 8
  %231 = call ptr @ptr_to_node(ptr %230)
  store ptr %231, ptr %last.626, align 8
  %232 = load ptr, ptr %last.626, align 8
  %233 = load ptr, ptr %elem.625, align 8
  %234 = call ptr @node_to_ptr(ptr %233)
  %235 = getelementptr inbounds nuw %ASTNode, ptr %232, i32 0, i32 8
  store ptr %234, ptr %235, align 8
  br label %label_883

label_881:                                        ; preds = %label_879
  %236 = load ptr, ptr %array_lit.622, align 8
  %237 = load ptr, ptr %elem.625, align 8
  %238 = call ptr @node_to_ptr(ptr %237)
  %239 = getelementptr inbounds nuw %ASTNode, ptr %236, i32 0, i32 5
  store ptr %238, ptr %239, align 8
  br label %label_883

label_883:                                        ; preds = %label_882, %label_881
  %240 = load ptr, ptr %elem.625, align 8
  %241 = call ptr @node_to_ptr(ptr %240)
  store ptr %241, ptr %last_elem.623, align 8
  %242 = load ptr, ptr %p.601, align 8
  %243 = call i1 @parser_match_val__Struct_Parser_Enum_TokenType_String(ptr %242, i32 6, ptr @.str.s305)
  %244 = icmp eq i1 %243, false
  br i1 %244, label %label_884, label %label_886

label_886:                                        ; preds = %label_884, %label_883
  br label %label_878

label_884:                                        ; preds = %label_883
  store i1 false, ptr %is_looping.624, align 1
  br label %label_886
}

define ptr @parse_module__Struct_Parser(ptr %0) {
entry:
  %p.627 = alloca ptr, align 8
  store ptr %0, ptr %p.627, align 8
  %1 = load ptr, ptr %p.627, align 8
  %2 = call ptr @parser_node__Struct_Parser_Enum_NodeKind(ptr %1, i32 0)
  %module.628 = alloca ptr, align 8
  store ptr %2, ptr %module.628, align 8
  %last_stmt.629 = alloca ptr, align 8
  store ptr @.str.s311, ptr %last_stmt.629, align 8
  %is_looping.630 = alloca i1, align 1
  store i1 true, ptr %is_looping.630, align 1
  %curr.631 = alloca ptr, align 8
  %stmt.632 = alloca ptr, align 8
  %last.633 = alloca ptr, align 8
  br label %label_887

label_887:                                        ; preds = %label_892, %entry
  %3 = load i1, ptr %is_looping.630, align 1
  br i1 %3, label %label_888, label %label_889

label_889:                                        ; preds = %label_887
  %4 = load ptr, ptr %module.628, align 8
  ret ptr %4

label_888:                                        ; preds = %label_887
  %5 = load ptr, ptr %p.627, align 8
  %6 = call ptr @parser_current__Struct_Parser(ptr %5)
  store ptr %6, ptr %curr.631, align 8
  %7 = load ptr, ptr %curr.631, align 8
  %8 = getelementptr inbounds nuw %Token, ptr %7, i32 0, i32 0
  %9 = load i32, ptr %8, align 4
  %10 = icmp eq i32 %9, 20
  br i1 %10, label %label_890, label %label_891

label_891:                                        ; preds = %label_888
  %11 = load ptr, ptr %p.627, align 8
  %12 = call ptr @parse_declaration__Struct_Parser(ptr %11)
  store ptr %12, ptr %stmt.632, align 8
  %13 = load ptr, ptr %stmt.632, align 8
  %14 = getelementptr inbounds nuw %ASTNode, ptr %13, i32 0, i32 0
  %15 = load i32, ptr %14, align 4
  %16 = icmp ne i32 %15, 35
  br i1 %16, label %label_893, label %label_895

label_890:                                        ; preds = %label_888
  store i1 false, ptr %is_looping.630, align 1
  br label %label_892

label_892:                                        ; preds = %label_895, %label_890
  br label %label_887

label_895:                                        ; preds = %label_898, %label_891
  br label %label_892

label_893:                                        ; preds = %label_891
  %17 = load ptr, ptr %module.628, align 8
  %18 = getelementptr inbounds nuw %ASTNode, ptr %17, i32 0, i32 5
  %19 = load ptr, ptr %18, align 8
  %20 = call i32 @str_equals(ptr %19, ptr @.str.s312)
  %21 = icmp eq i32 %20, 1
  br i1 %21, label %label_896, label %label_897

label_897:                                        ; preds = %label_893
  %22 = load ptr, ptr %last_stmt.629, align 8
  %23 = call ptr @ptr_to_node(ptr %22)
  store ptr %23, ptr %last.633, align 8
  %24 = load ptr, ptr %last.633, align 8
  %25 = load ptr, ptr %stmt.632, align 8
  %26 = call ptr @node_to_ptr(ptr %25)
  %27 = getelementptr inbounds nuw %ASTNode, ptr %24, i32 0, i32 8
  store ptr %26, ptr %27, align 8
  br label %label_898

label_896:                                        ; preds = %label_893
  %28 = load ptr, ptr %module.628, align 8
  %29 = load ptr, ptr %stmt.632, align 8
  %30 = call ptr @node_to_ptr(ptr %29)
  %31 = getelementptr inbounds nuw %ASTNode, ptr %28, i32 0, i32 5
  store ptr %30, ptr %31, align 8
  br label %label_898

label_898:                                        ; preds = %label_897, %label_896
  %32 = load ptr, ptr %stmt.632, align 8
  %33 = call ptr @node_to_ptr(ptr %32)
  store ptr %33, ptr %last_stmt.629, align 8
  br label %label_895
}

define ptr @type_make__Enum_TypeKind_String_String(i32 %0, ptr %1, ptr %2) {
entry:
  %kind.634 = alloca i32, align 4
  store i32 %0, ptr %kind.634, align 4
  %name.635 = alloca ptr, align 8
  store ptr %1, ptr %name.635, align 8
  %llvm.636 = alloca ptr, align 8
  store ptr %2, ptr %llvm.636, align 8
  %3 = call ptr @malloc(i64 ptrtoint (ptr getelementptr (%TypeInfo, ptr null, i32 1) to i64))
  %4 = load i32, ptr %kind.634, align 4
  %5 = getelementptr inbounds nuw %TypeInfo, ptr %3, i32 0, i32 0
  store i32 %4, ptr %5, align 4
  %6 = load ptr, ptr %name.635, align 8
  %7 = getelementptr inbounds nuw %TypeInfo, ptr %3, i32 0, i32 1
  store ptr %6, ptr %7, align 8
  %8 = load ptr, ptr %llvm.636, align 8
  %9 = getelementptr inbounds nuw %TypeInfo, ptr %3, i32 0, i32 2
  store ptr %8, ptr %9, align 8
  %10 = getelementptr inbounds nuw %TypeInfo, ptr %3, i32 0, i32 3
  store ptr @.str.s313, ptr %10, align 8
  %11 = getelementptr inbounds nuw %TypeInfo, ptr %3, i32 0, i32 4
  store ptr @.str.s314, ptr %11, align 8
  ret ptr %3
}

define ptr @type_copy__Struct_TypeInfo(ptr %0) {
entry:
  %t.637 = alloca ptr, align 8
  store ptr %0, ptr %t.637, align 8
  %1 = load ptr, ptr %t.637, align 8
  %2 = getelementptr inbounds nuw %TypeInfo, ptr %1, i32 0, i32 0
  %3 = load i32, ptr %2, align 4
  %4 = load ptr, ptr %t.637, align 8
  %5 = getelementptr inbounds nuw %TypeInfo, ptr %4, i32 0, i32 1
  %6 = load ptr, ptr %5, align 8
  %7 = load ptr, ptr %t.637, align 8
  %8 = getelementptr inbounds nuw %TypeInfo, ptr %7, i32 0, i32 2
  %9 = load ptr, ptr %8, align 8
  %10 = call ptr @type_make__Enum_TypeKind_String_String(i32 %3, ptr %6, ptr %9)
  %dup.638 = alloca ptr, align 8
  store ptr %10, ptr %dup.638, align 8
  %11 = load ptr, ptr %dup.638, align 8
  %12 = load ptr, ptr %t.637, align 8
  %13 = getelementptr inbounds nuw %TypeInfo, ptr %12, i32 0, i32 3
  %14 = load ptr, ptr %13, align 8
  %15 = getelementptr inbounds nuw %TypeInfo, ptr %11, i32 0, i32 3
  store ptr %14, ptr %15, align 8
  %16 = load ptr, ptr %dup.638, align 8
  %17 = load ptr, ptr %t.637, align 8
  %18 = getelementptr inbounds nuw %TypeInfo, ptr %17, i32 0, i32 4
  %19 = load ptr, ptr %18, align 8
  %20 = getelementptr inbounds nuw %TypeInfo, ptr %16, i32 0, i32 4
  store ptr %19, ptr %20, align 8
  %21 = load ptr, ptr %dup.638, align 8
  ret ptr %21
}

define ptr @type_invalid__Void() {
entry:
  %0 = call ptr @type_make__Enum_TypeKind_String_String(i32 0, ptr @.str.s315, ptr @.str.s316)
  ret ptr %0
}

define ptr @type_void__Void() {
entry:
  %0 = call ptr @type_make__Enum_TypeKind_String_String(i32 1, ptr @.str.s317, ptr @.str.s318)
  ret ptr %0
}

define ptr @type_int__Void() {
entry:
  %0 = call ptr @type_make__Enum_TypeKind_String_String(i32 2, ptr @.str.s319, ptr @.str.s320)
  ret ptr %0
}

define ptr @type_float__Void() {
entry:
  %0 = call ptr @type_make__Enum_TypeKind_String_String(i32 3, ptr @.str.s321, ptr @.str.s322)
  ret ptr %0
}

define ptr @type_bool__Void() {
entry:
  %0 = call ptr @type_make__Enum_TypeKind_String_String(i32 4, ptr @.str.s323, ptr @.str.s324)
  ret ptr %0
}

define ptr @type_char__Void() {
entry:
  %0 = call ptr @type_make__Enum_TypeKind_String_String(i32 5, ptr @.str.s325, ptr @.str.s326)
  ret ptr %0
}

define ptr @type_string__Void() {
entry:
  %0 = call ptr @type_make__Enum_TypeKind_String_String(i32 6, ptr @.str.s327, ptr @.str.s328)
  ret ptr %0
}

define ptr @type_ptr__Void() {
entry:
  %0 = call ptr @type_make__Enum_TypeKind_String_String(i32 7, ptr @.str.s329, ptr @.str.s330)
  ret ptr %0
}

define ptr @type_i8__Void() {
entry:
  %0 = call ptr @type_make__Enum_TypeKind_String_String(i32 2, ptr @.str.s331, ptr @.str.s332)
  ret ptr %0
}

define ptr @type_i16__Void() {
entry:
  %0 = call ptr @type_make__Enum_TypeKind_String_String(i32 2, ptr @.str.s333, ptr @.str.s334)
  ret ptr %0
}

define ptr @type_i64__Void() {
entry:
  %0 = call ptr @type_make__Enum_TypeKind_String_String(i32 2, ptr @.str.s335, ptr @.str.s336)
  ret ptr %0
}

define ptr @type_isize__Void() {
entry:
  %0 = call ptr @type_make__Enum_TypeKind_String_String(i32 2, ptr @.str.s337, ptr @.str.s338)
  ret ptr %0
}

define ptr @type_u8__Void() {
entry:
  %0 = call ptr @type_make__Enum_TypeKind_String_String(i32 2, ptr @.str.s339, ptr @.str.s340)
  ret ptr %0
}

define ptr @type_u16__Void() {
entry:
  %0 = call ptr @type_make__Enum_TypeKind_String_String(i32 2, ptr @.str.s341, ptr @.str.s342)
  ret ptr %0
}

define ptr @type_u32__Void() {
entry:
  %0 = call ptr @type_make__Enum_TypeKind_String_String(i32 2, ptr @.str.s343, ptr @.str.s344)
  ret ptr %0
}

define ptr @type_u64__Void() {
entry:
  %0 = call ptr @type_make__Enum_TypeKind_String_String(i32 2, ptr @.str.s345, ptr @.str.s346)
  ret ptr %0
}

define ptr @type_usize__Void() {
entry:
  %0 = call ptr @type_make__Enum_TypeKind_String_String(i32 2, ptr @.str.s347, ptr @.str.s348)
  ret ptr %0
}

define i32 @type_int_bits__Struct_TypeInfo(ptr %0) {
entry:
  %t.639 = alloca ptr, align 8
  store ptr %0, ptr %t.639, align 8
  %1 = load ptr, ptr %t.639, align 8
  %2 = getelementptr inbounds nuw %TypeInfo, ptr %1, i32 0, i32 2
  %3 = load ptr, ptr %2, align 8
  %4 = call i32 @str_equals(ptr %3, ptr @.str.s349)
  %5 = icmp eq i32 %4, 1
  br i1 %5, label %label_899, label %label_901

label_901:                                        ; preds = %entry
  %6 = load ptr, ptr %t.639, align 8
  %7 = getelementptr inbounds nuw %TypeInfo, ptr %6, i32 0, i32 2
  %8 = load ptr, ptr %7, align 8
  %9 = call i32 @str_equals(ptr %8, ptr @.str.s350)
  %10 = icmp eq i32 %9, 1
  br i1 %10, label %label_902, label %label_904

label_899:                                        ; preds = %entry
  ret i32 1

label_904:                                        ; preds = %label_901
  %11 = load ptr, ptr %t.639, align 8
  %12 = getelementptr inbounds nuw %TypeInfo, ptr %11, i32 0, i32 2
  %13 = load ptr, ptr %12, align 8
  %14 = call i32 @str_equals(ptr %13, ptr @.str.s351)
  %15 = icmp eq i32 %14, 1
  br i1 %15, label %label_905, label %label_907

label_902:                                        ; preds = %label_901
  ret i32 8

label_907:                                        ; preds = %label_904
  %16 = load ptr, ptr %t.639, align 8
  %17 = getelementptr inbounds nuw %TypeInfo, ptr %16, i32 0, i32 2
  %18 = load ptr, ptr %17, align 8
  %19 = call i32 @str_equals(ptr %18, ptr @.str.s352)
  %20 = icmp eq i32 %19, 1
  br i1 %20, label %label_908, label %label_910

label_905:                                        ; preds = %label_904
  ret i32 16

label_910:                                        ; preds = %label_907
  %21 = load ptr, ptr %t.639, align 8
  %22 = getelementptr inbounds nuw %TypeInfo, ptr %21, i32 0, i32 2
  %23 = load ptr, ptr %22, align 8
  %24 = call i32 @str_equals(ptr %23, ptr @.str.s353)
  %25 = icmp eq i32 %24, 1
  br i1 %25, label %label_911, label %label_913

label_908:                                        ; preds = %label_907
  ret i32 32

label_913:                                        ; preds = %label_910
  ret i32 0

label_911:                                        ; preds = %label_910
  ret i32 64
}

define i1 @type_int_is_unsigned__Struct_TypeInfo(ptr %0) {
entry:
  %t.640 = alloca ptr, align 8
  store ptr %0, ptr %t.640, align 8
  %1 = load ptr, ptr %t.640, align 8
  %2 = getelementptr inbounds nuw %TypeInfo, ptr %1, i32 0, i32 0
  %3 = load i32, ptr %2, align 4
  %4 = icmp ne i32 %3, 2
  br i1 %4, label %label_914, label %label_916

label_916:                                        ; preds = %entry
  %5 = load ptr, ptr %t.640, align 8
  %6 = getelementptr inbounds nuw %TypeInfo, ptr %5, i32 0, i32 1
  %7 = load ptr, ptr %6, align 8
  %8 = call i32 @str_starts_with(ptr %7, ptr @.str.s354)
  %9 = icmp eq i32 %8, 1
  ret i1 %9

label_914:                                        ; preds = %entry
  ret i1 false
}

define i1 @type_is_move_only__Struct_TypeInfo(ptr %0) {
entry:
  %t.641 = alloca ptr, align 8
  store ptr %0, ptr %t.641, align 8
  %1 = load ptr, ptr %t.641, align 8
  %2 = getelementptr inbounds nuw %TypeInfo, ptr %1, i32 0, i32 0
  %3 = load i32, ptr %2, align 4
  %4 = icmp eq i32 %3, 8
  ret i1 %4
}

define ptr @type_struct__String(ptr %0) {
entry:
  %name.642 = alloca ptr, align 8
  store ptr %0, ptr %name.642, align 8
  %1 = load ptr, ptr %name.642, align 8
  %2 = call ptr @type_make__Enum_TypeKind_String_String(i32 8, ptr %1, ptr @.str.s355)
  ret ptr %2
}

define ptr @type_enum__String(ptr %0) {
entry:
  %name.643 = alloca ptr, align 8
  store ptr %0, ptr %name.643, align 8
  %1 = load ptr, ptr %name.643, align 8
  %2 = call ptr @type_make__Enum_TypeKind_String_String(i32 9, ptr %1, ptr @.str.s356)
  ret ptr %2
}

define ptr @type_array__Struct_TypeInfo(ptr %0) {
entry:
  %elem.644 = alloca ptr, align 8
  store ptr %0, ptr %elem.644, align 8
  %1 = call ptr @type_make__Enum_TypeKind_String_String(i32 10, ptr @.str.s357, ptr @.str.s358)
  %t.645 = alloca ptr, align 8
  store ptr %1, ptr %t.645, align 8
  %2 = load ptr, ptr %t.645, align 8
  %3 = load ptr, ptr %elem.644, align 8
  %4 = call ptr @type_to_ptr(ptr %3)
  %5 = getelementptr inbounds nuw %TypeInfo, ptr %2, i32 0, i32 3
  store ptr %4, ptr %5, align 8
  %6 = load ptr, ptr %t.645, align 8
  ret ptr %6
}

define ptr @type_list__Struct_TypeInfo(ptr %0) {
entry:
  %elem.646 = alloca ptr, align 8
  store ptr %0, ptr %elem.646, align 8
  %1 = call ptr @type_make__Enum_TypeKind_String_String(i32 11, ptr @.str.s359, ptr @.str.s360)
  %t.647 = alloca ptr, align 8
  store ptr %1, ptr %t.647, align 8
  %2 = load ptr, ptr %t.647, align 8
  %3 = load ptr, ptr %elem.646, align 8
  %4 = call ptr @type_to_ptr(ptr %3)
  %5 = getelementptr inbounds nuw %TypeInfo, ptr %2, i32 0, i32 3
  store ptr %4, ptr %5, align 8
  %6 = load ptr, ptr %t.647, align 8
  ret ptr %6
}

define i1 @type_is_valid__Struct_TypeInfo(ptr %0) {
entry:
  %t.648 = alloca ptr, align 8
  store ptr %0, ptr %t.648, align 8
  %1 = load ptr, ptr %t.648, align 8
  %2 = getelementptr inbounds nuw %TypeInfo, ptr %1, i32 0, i32 0
  %3 = load i32, ptr %2, align 4
  %4 = icmp ne i32 %3, 0
  ret i1 %4
}

define ptr @type_display__Struct_TypeInfo(ptr %0) {
entry:
  %t.649 = alloca ptr, align 8
  store ptr %0, ptr %t.649, align 8
  %1 = load ptr, ptr %t.649, align 8
  %2 = getelementptr inbounds nuw %TypeInfo, ptr %1, i32 0, i32 0
  %3 = load i32, ptr %2, align 4
  %4 = icmp eq i32 %3, 8
  br i1 %4, label %label_917, label %label_919

label_919:                                        ; preds = %entry
  %5 = load ptr, ptr %t.649, align 8
  %6 = getelementptr inbounds nuw %TypeInfo, ptr %5, i32 0, i32 0
  %7 = load i32, ptr %6, align 4
  %8 = icmp eq i32 %7, 9
  br i1 %8, label %label_920, label %label_922

label_917:                                        ; preds = %entry
  %9 = load ptr, ptr %t.649, align 8
  %10 = getelementptr inbounds nuw %TypeInfo, ptr %9, i32 0, i32 1
  %11 = load ptr, ptr %10, align 8
  ret ptr %11

label_922:                                        ; preds = %label_919
  %12 = load ptr, ptr %t.649, align 8
  %13 = getelementptr inbounds nuw %TypeInfo, ptr %12, i32 0, i32 0
  %14 = load i32, ptr %13, align 4
  %15 = icmp eq i32 %14, 10
  br i1 %15, label %label_923, label %label_925

label_920:                                        ; preds = %label_919
  %16 = load ptr, ptr %t.649, align 8
  %17 = getelementptr inbounds nuw %TypeInfo, ptr %16, i32 0, i32 1
  %18 = load ptr, ptr %17, align 8
  ret ptr %18

label_925:                                        ; preds = %label_922
  %19 = load ptr, ptr %t.649, align 8
  %20 = getelementptr inbounds nuw %TypeInfo, ptr %19, i32 0, i32 0
  %21 = load i32, ptr %20, align 4
  %22 = icmp eq i32 %21, 11
  br i1 %22, label %label_929, label %label_931

label_923:                                        ; preds = %label_922
  %23 = load ptr, ptr %t.649, align 8
  %24 = getelementptr inbounds nuw %TypeInfo, ptr %23, i32 0, i32 3
  %25 = load ptr, ptr %24, align 8
  %26 = call i32 @str_equals(ptr %25, ptr @.str.s361)
  %27 = icmp eq i32 %26, 0
  br i1 %27, label %label_926, label %label_928

label_928:                                        ; preds = %label_923
  ret ptr @.str.s364

label_926:                                        ; preds = %label_923
  %28 = load ptr, ptr %t.649, align 8
  %29 = getelementptr inbounds nuw %TypeInfo, ptr %28, i32 0, i32 3
  %30 = load ptr, ptr %29, align 8
  %31 = call ptr @ptr_to_type(ptr %30)
  %32 = call ptr @type_display__Struct_TypeInfo(ptr %31)
  %33 = call ptr @str_concat(ptr @.str.s362, ptr %32)
  %34 = call ptr @str_concat(ptr %33, ptr @.str.s363)
  ret ptr %34

label_931:                                        ; preds = %label_925
  %35 = load ptr, ptr %t.649, align 8
  %36 = getelementptr inbounds nuw %TypeInfo, ptr %35, i32 0, i32 1
  %37 = load ptr, ptr %36, align 8
  ret ptr %37

label_929:                                        ; preds = %label_925
  %38 = load ptr, ptr %t.649, align 8
  %39 = getelementptr inbounds nuw %TypeInfo, ptr %38, i32 0, i32 3
  %40 = load ptr, ptr %39, align 8
  %41 = call i32 @str_equals(ptr %40, ptr @.str.s365)
  %42 = icmp eq i32 %41, 0
  br i1 %42, label %label_932, label %label_934

label_934:                                        ; preds = %label_929
  ret ptr @.str.s368

label_932:                                        ; preds = %label_929
  %43 = load ptr, ptr %t.649, align 8
  %44 = getelementptr inbounds nuw %TypeInfo, ptr %43, i32 0, i32 3
  %45 = load ptr, ptr %44, align 8
  %46 = call ptr @ptr_to_type(ptr %45)
  %47 = call ptr @type_display__Struct_TypeInfo(ptr %46)
  %48 = call ptr @str_concat(ptr @.str.s366, ptr %47)
  %49 = call ptr @str_concat(ptr %48, ptr @.str.s367)
  ret ptr %49
}

define i1 @type_equals__Struct_TypeInfo_Struct_TypeInfo(ptr %0, ptr %1) {
entry:
  %a.650 = alloca ptr, align 8
  store ptr %0, ptr %a.650, align 8
  %b.651 = alloca ptr, align 8
  store ptr %1, ptr %b.651, align 8
  %2 = load ptr, ptr %a.650, align 8
  %3 = getelementptr inbounds nuw %TypeInfo, ptr %2, i32 0, i32 0
  %4 = load i32, ptr %3, align 4
  %5 = load ptr, ptr %b.651, align 8
  %6 = getelementptr inbounds nuw %TypeInfo, ptr %5, i32 0, i32 0
  %7 = load i32, ptr %6, align 4
  %8 = icmp ne i32 %4, %7
  %sc.88 = alloca i1, align 1
  %sc.89 = alloca i1, align 1
  %sc.90 = alloca i1, align 1
  %ac.652 = alloca ptr, align 8
  %bc.653 = alloca ptr, align 8
  %sc.91 = alloca i1, align 1
  br i1 %8, label %label_935, label %label_937

label_937:                                        ; preds = %entry
  %9 = load ptr, ptr %a.650, align 8
  %10 = getelementptr inbounds nuw %TypeInfo, ptr %9, i32 0, i32 0
  %11 = load i32, ptr %10, align 4
  %12 = icmp eq i32 %11, 8
  store i1 %12, ptr %sc.88, align 1
  br i1 %12, label %label_939, label %label_938

label_935:                                        ; preds = %entry
  ret i1 false

label_938:                                        ; preds = %label_937
  %13 = load ptr, ptr %a.650, align 8
  %14 = getelementptr inbounds nuw %TypeInfo, ptr %13, i32 0, i32 0
  %15 = load i32, ptr %14, align 4
  %16 = icmp eq i32 %15, 9
  store i1 %16, ptr %sc.88, align 1
  br label %label_939

label_939:                                        ; preds = %label_938, %label_937
  %17 = load i1, ptr %sc.88, align 1
  br i1 %17, label %label_940, label %label_942

label_942:                                        ; preds = %label_939
  %18 = load ptr, ptr %a.650, align 8
  %19 = getelementptr inbounds nuw %TypeInfo, ptr %18, i32 0, i32 0
  %20 = load i32, ptr %19, align 4
  %21 = icmp eq i32 %20, 2
  br i1 %21, label %label_943, label %label_945

label_940:                                        ; preds = %label_939
  %22 = load ptr, ptr %a.650, align 8
  %23 = getelementptr inbounds nuw %TypeInfo, ptr %22, i32 0, i32 1
  %24 = load ptr, ptr %23, align 8
  %25 = load ptr, ptr %b.651, align 8
  %26 = getelementptr inbounds nuw %TypeInfo, ptr %25, i32 0, i32 1
  %27 = load ptr, ptr %26, align 8
  %28 = call i32 @str_equals(ptr %24, ptr %27)
  %29 = icmp eq i32 %28, 1
  ret i1 %29

label_945:                                        ; preds = %label_942
  %30 = load ptr, ptr %a.650, align 8
  %31 = getelementptr inbounds nuw %TypeInfo, ptr %30, i32 0, i32 0
  %32 = load i32, ptr %31, align 4
  %33 = icmp eq i32 %32, 10
  br i1 %33, label %label_946, label %label_948

label_943:                                        ; preds = %label_942
  %34 = load ptr, ptr %a.650, align 8
  %35 = getelementptr inbounds nuw %TypeInfo, ptr %34, i32 0, i32 1
  %36 = load ptr, ptr %35, align 8
  %37 = load ptr, ptr %b.651, align 8
  %38 = getelementptr inbounds nuw %TypeInfo, ptr %37, i32 0, i32 1
  %39 = load ptr, ptr %38, align 8
  %40 = call i32 @str_equals(ptr %36, ptr %39)
  %41 = icmp eq i32 %40, 1
  ret i1 %41

label_948:                                        ; preds = %label_945
  %42 = load ptr, ptr %a.650, align 8
  %43 = getelementptr inbounds nuw %TypeInfo, ptr %42, i32 0, i32 0
  %44 = load i32, ptr %43, align 4
  %45 = icmp eq i32 %44, 11
  br i1 %45, label %label_954, label %label_956

label_946:                                        ; preds = %label_945
  %46 = load ptr, ptr %a.650, align 8
  %47 = getelementptr inbounds nuw %TypeInfo, ptr %46, i32 0, i32 3
  %48 = load ptr, ptr %47, align 8
  %49 = call i32 @str_equals(ptr %48, ptr @.str.s369)
  %50 = icmp eq i32 %49, 1
  store i1 %50, ptr %sc.89, align 1
  br i1 %50, label %label_950, label %label_949

label_949:                                        ; preds = %label_946
  %51 = load ptr, ptr %b.651, align 8
  %52 = getelementptr inbounds nuw %TypeInfo, ptr %51, i32 0, i32 3
  %53 = load ptr, ptr %52, align 8
  %54 = call i32 @str_equals(ptr %53, ptr @.str.s370)
  %55 = icmp eq i32 %54, 1
  store i1 %55, ptr %sc.89, align 1
  br label %label_950

label_950:                                        ; preds = %label_949, %label_946
  %56 = load i1, ptr %sc.89, align 1
  br i1 %56, label %label_951, label %label_953

label_953:                                        ; preds = %label_950
  %57 = load ptr, ptr %a.650, align 8
  %58 = getelementptr inbounds nuw %TypeInfo, ptr %57, i32 0, i32 3
  %59 = load ptr, ptr %58, align 8
  %60 = call ptr @ptr_to_type(ptr %59)
  %61 = load ptr, ptr %b.651, align 8
  %62 = getelementptr inbounds nuw %TypeInfo, ptr %61, i32 0, i32 3
  %63 = load ptr, ptr %62, align 8
  %64 = call ptr @ptr_to_type(ptr %63)
  %65 = call i1 @type_equals__Struct_TypeInfo_Struct_TypeInfo(ptr %60, ptr %64)
  ret i1 %65

label_951:                                        ; preds = %label_950
  %66 = load ptr, ptr %a.650, align 8
  %67 = getelementptr inbounds nuw %TypeInfo, ptr %66, i32 0, i32 3
  %68 = load ptr, ptr %67, align 8
  %69 = load ptr, ptr %b.651, align 8
  %70 = getelementptr inbounds nuw %TypeInfo, ptr %69, i32 0, i32 3
  %71 = load ptr, ptr %70, align 8
  %72 = call i32 @str_equals(ptr %68, ptr %71)
  %73 = icmp eq i32 %72, 1
  ret i1 %73

label_956:                                        ; preds = %label_948
  ret i1 true

label_954:                                        ; preds = %label_948
  %74 = load ptr, ptr %a.650, align 8
  %75 = getelementptr inbounds nuw %TypeInfo, ptr %74, i32 0, i32 3
  %76 = load ptr, ptr %75, align 8
  %77 = call i32 @str_equals(ptr %76, ptr @.str.s371)
  %78 = icmp eq i32 %77, 1
  store i1 %78, ptr %sc.90, align 1
  br i1 %78, label %label_958, label %label_957

label_957:                                        ; preds = %label_954
  %79 = load ptr, ptr %b.651, align 8
  %80 = getelementptr inbounds nuw %TypeInfo, ptr %79, i32 0, i32 3
  %81 = load ptr, ptr %80, align 8
  %82 = call i32 @str_equals(ptr %81, ptr @.str.s372)
  %83 = icmp eq i32 %82, 1
  store i1 %83, ptr %sc.90, align 1
  br label %label_958

label_958:                                        ; preds = %label_957, %label_954
  %84 = load i1, ptr %sc.90, align 1
  br i1 %84, label %label_959, label %label_961

label_961:                                        ; preds = %label_958
  %85 = load ptr, ptr %a.650, align 8
  %86 = getelementptr inbounds nuw %TypeInfo, ptr %85, i32 0, i32 3
  %87 = load ptr, ptr %86, align 8
  %88 = call ptr @ptr_to_type(ptr %87)
  store ptr %88, ptr %ac.652, align 8
  %89 = load ptr, ptr %b.651, align 8
  %90 = getelementptr inbounds nuw %TypeInfo, ptr %89, i32 0, i32 3
  %91 = load ptr, ptr %90, align 8
  %92 = call ptr @ptr_to_type(ptr %91)
  store ptr %92, ptr %bc.653, align 8
  %93 = load ptr, ptr %ac.652, align 8
  %94 = call i1 @type_is_valid__Struct_TypeInfo(ptr %93)
  %95 = icmp eq i1 %94, false
  store i1 %95, ptr %sc.91, align 1
  br i1 %95, label %label_963, label %label_962

label_959:                                        ; preds = %label_958
  ret i1 true

label_962:                                        ; preds = %label_961
  %96 = load ptr, ptr %bc.653, align 8
  %97 = call i1 @type_is_valid__Struct_TypeInfo(ptr %96)
  %98 = icmp eq i1 %97, false
  store i1 %98, ptr %sc.91, align 1
  br label %label_963

label_963:                                        ; preds = %label_962, %label_961
  %99 = load i1, ptr %sc.91, align 1
  br i1 %99, label %label_964, label %label_966

label_966:                                        ; preds = %label_963
  %100 = load ptr, ptr %ac.652, align 8
  %101 = load ptr, ptr %bc.653, align 8
  %102 = call i1 @type_equals__Struct_TypeInfo_Struct_TypeInfo(ptr %100, ptr %101)
  ret i1 %102

label_964:                                        ; preds = %label_963
  ret i1 true
}

define i1 @type_is_numeric__Struct_TypeInfo(ptr %0) {
entry:
  %t.654 = alloca ptr, align 8
  store ptr %0, ptr %t.654, align 8
  %sc.92 = alloca i1, align 1
  %1 = load ptr, ptr %t.654, align 8
  %2 = getelementptr inbounds nuw %TypeInfo, ptr %1, i32 0, i32 0
  %3 = load i32, ptr %2, align 4
  %4 = icmp eq i32 %3, 2
  store i1 %4, ptr %sc.92, align 1
  br i1 %4, label %label_968, label %label_967

label_967:                                        ; preds = %entry
  %5 = load ptr, ptr %t.654, align 8
  %6 = getelementptr inbounds nuw %TypeInfo, ptr %5, i32 0, i32 0
  %7 = load i32, ptr %6, align 4
  %8 = icmp eq i32 %7, 3
  store i1 %8, ptr %sc.92, align 1
  br label %label_968

label_968:                                        ; preds = %label_967, %entry
  %9 = load i1, ptr %sc.92, align 1
  ret i1 %9
}

define ptr @type_ir_key__Struct_TypeInfo(ptr %0) {
entry:
  %t.655 = alloca ptr, align 8
  store ptr %0, ptr %t.655, align 8
  %1 = load ptr, ptr %t.655, align 8
  %2 = getelementptr inbounds nuw %TypeInfo, ptr %1, i32 0, i32 0
  %3 = load i32, ptr %2, align 4
  %4 = icmp eq i32 %3, 1
  %elem.656 = alloca ptr, align 8
  br i1 %4, label %label_969, label %label_971

label_971:                                        ; preds = %entry
  %5 = load ptr, ptr %t.655, align 8
  %6 = getelementptr inbounds nuw %TypeInfo, ptr %5, i32 0, i32 0
  %7 = load i32, ptr %6, align 4
  %8 = icmp eq i32 %7, 2
  br i1 %8, label %label_972, label %label_974

label_969:                                        ; preds = %entry
  ret ptr @.str.s373

label_974:                                        ; preds = %label_971
  %9 = load ptr, ptr %t.655, align 8
  %10 = getelementptr inbounds nuw %TypeInfo, ptr %9, i32 0, i32 0
  %11 = load i32, ptr %10, align 4
  %12 = icmp eq i32 %11, 3
  br i1 %12, label %label_975, label %label_977

label_972:                                        ; preds = %label_971
  %13 = load ptr, ptr %t.655, align 8
  %14 = getelementptr inbounds nuw %TypeInfo, ptr %13, i32 0, i32 2
  %15 = load ptr, ptr %14, align 8
  ret ptr %15

label_977:                                        ; preds = %label_974
  %16 = load ptr, ptr %t.655, align 8
  %17 = getelementptr inbounds nuw %TypeInfo, ptr %16, i32 0, i32 0
  %18 = load i32, ptr %17, align 4
  %19 = icmp eq i32 %18, 4
  br i1 %19, label %label_978, label %label_980

label_975:                                        ; preds = %label_974
  ret ptr @.str.s374

label_980:                                        ; preds = %label_977
  %20 = load ptr, ptr %t.655, align 8
  %21 = getelementptr inbounds nuw %TypeInfo, ptr %20, i32 0, i32 0
  %22 = load i32, ptr %21, align 4
  %23 = icmp eq i32 %22, 5
  br i1 %23, label %label_981, label %label_983

label_978:                                        ; preds = %label_977
  ret ptr @.str.s375

label_983:                                        ; preds = %label_980
  %24 = load ptr, ptr %t.655, align 8
  %25 = getelementptr inbounds nuw %TypeInfo, ptr %24, i32 0, i32 0
  %26 = load i32, ptr %25, align 4
  %27 = icmp eq i32 %26, 6
  br i1 %27, label %label_984, label %label_986

label_981:                                        ; preds = %label_980
  ret ptr @.str.s376

label_986:                                        ; preds = %label_983
  %28 = load ptr, ptr %t.655, align 8
  %29 = getelementptr inbounds nuw %TypeInfo, ptr %28, i32 0, i32 0
  %30 = load i32, ptr %29, align 4
  %31 = icmp eq i32 %30, 7
  br i1 %31, label %label_987, label %label_989

label_984:                                        ; preds = %label_983
  ret ptr @.str.s377

label_989:                                        ; preds = %label_986
  %32 = load ptr, ptr %t.655, align 8
  %33 = getelementptr inbounds nuw %TypeInfo, ptr %32, i32 0, i32 0
  %34 = load i32, ptr %33, align 4
  %35 = icmp eq i32 %34, 9
  br i1 %35, label %label_990, label %label_992

label_987:                                        ; preds = %label_986
  ret ptr @.str.s378

label_992:                                        ; preds = %label_989
  %36 = load ptr, ptr %t.655, align 8
  %37 = getelementptr inbounds nuw %TypeInfo, ptr %36, i32 0, i32 0
  %38 = load i32, ptr %37, align 4
  %39 = icmp eq i32 %38, 8
  br i1 %39, label %label_993, label %label_995

label_990:                                        ; preds = %label_989
  ret ptr @.str.s379

label_995:                                        ; preds = %label_992
  %40 = load ptr, ptr %t.655, align 8
  %41 = getelementptr inbounds nuw %TypeInfo, ptr %40, i32 0, i32 0
  %42 = load i32, ptr %41, align 4
  %43 = icmp eq i32 %42, 11
  br i1 %43, label %label_996, label %label_998

label_993:                                        ; preds = %label_992
  %44 = load ptr, ptr %t.655, align 8
  %45 = getelementptr inbounds nuw %TypeInfo, ptr %44, i32 0, i32 1
  %46 = load ptr, ptr %45, align 8
  %47 = call ptr @str_concat(ptr @.str.s380, ptr %46)
  ret ptr %47

label_998:                                        ; preds = %label_995
  %48 = load ptr, ptr %t.655, align 8
  %49 = getelementptr inbounds nuw %TypeInfo, ptr %48, i32 0, i32 0
  %50 = load i32, ptr %49, align 4
  %51 = icmp eq i32 %50, 10
  br i1 %51, label %label_999, label %label_1001

label_996:                                        ; preds = %label_995
  ret ptr @.str.s381

label_1001:                                       ; preds = %label_998
  ret ptr @.str.s385

label_999:                                        ; preds = %label_998
  %52 = load ptr, ptr %t.655, align 8
  %53 = getelementptr inbounds nuw %TypeInfo, ptr %52, i32 0, i32 3
  %54 = load ptr, ptr %53, align 8
  %55 = call i32 @str_equals(ptr %54, ptr @.str.s382)
  %56 = icmp eq i32 %55, 0
  br i1 %56, label %label_1002, label %label_1004

label_1004:                                       ; preds = %label_1007, %label_999
  ret ptr @.str.s384

label_1002:                                       ; preds = %label_999
  %57 = load ptr, ptr %t.655, align 8
  %58 = getelementptr inbounds nuw %TypeInfo, ptr %57, i32 0, i32 3
  %59 = load ptr, ptr %58, align 8
  %60 = call ptr @ptr_to_type(ptr %59)
  store ptr %60, ptr %elem.656, align 8
  %61 = load ptr, ptr %elem.656, align 8
  %62 = getelementptr inbounds nuw %TypeInfo, ptr %61, i32 0, i32 0
  %63 = load i32, ptr %62, align 4
  %64 = icmp eq i32 %63, 10
  br i1 %64, label %label_1005, label %label_1007

label_1007:                                       ; preds = %label_1002
  br label %label_1004

label_1005:                                       ; preds = %label_1002
  ret ptr @.str.s383
}

define ptr @type_sem_key__Struct_TypeInfo(ptr %0) {
entry:
  %t.657 = alloca ptr, align 8
  store ptr %0, ptr %t.657, align 8
  %1 = load ptr, ptr %t.657, align 8
  %2 = getelementptr inbounds nuw %TypeInfo, ptr %1, i32 0, i32 0
  %3 = load i32, ptr %2, align 4
  %4 = icmp eq i32 %3, 1
  br i1 %4, label %label_1008, label %label_1010

label_1010:                                       ; preds = %entry
  %5 = load ptr, ptr %t.657, align 8
  %6 = getelementptr inbounds nuw %TypeInfo, ptr %5, i32 0, i32 0
  %7 = load i32, ptr %6, align 4
  %8 = icmp eq i32 %7, 2
  br i1 %8, label %label_1011, label %label_1013

label_1008:                                       ; preds = %entry
  ret ptr @.str.s386

label_1013:                                       ; preds = %label_1010
  %9 = load ptr, ptr %t.657, align 8
  %10 = getelementptr inbounds nuw %TypeInfo, ptr %9, i32 0, i32 0
  %11 = load i32, ptr %10, align 4
  %12 = icmp eq i32 %11, 3
  br i1 %12, label %label_1014, label %label_1016

label_1011:                                       ; preds = %label_1010
  %13 = load ptr, ptr %t.657, align 8
  %14 = getelementptr inbounds nuw %TypeInfo, ptr %13, i32 0, i32 1
  %15 = load ptr, ptr %14, align 8
  ret ptr %15

label_1016:                                       ; preds = %label_1013
  %16 = load ptr, ptr %t.657, align 8
  %17 = getelementptr inbounds nuw %TypeInfo, ptr %16, i32 0, i32 0
  %18 = load i32, ptr %17, align 4
  %19 = icmp eq i32 %18, 4
  br i1 %19, label %label_1017, label %label_1019

label_1014:                                       ; preds = %label_1013
  ret ptr @.str.s387

label_1019:                                       ; preds = %label_1016
  %20 = load ptr, ptr %t.657, align 8
  %21 = getelementptr inbounds nuw %TypeInfo, ptr %20, i32 0, i32 0
  %22 = load i32, ptr %21, align 4
  %23 = icmp eq i32 %22, 5
  br i1 %23, label %label_1020, label %label_1022

label_1017:                                       ; preds = %label_1016
  ret ptr @.str.s388

label_1022:                                       ; preds = %label_1019
  %24 = load ptr, ptr %t.657, align 8
  %25 = getelementptr inbounds nuw %TypeInfo, ptr %24, i32 0, i32 0
  %26 = load i32, ptr %25, align 4
  %27 = icmp eq i32 %26, 6
  br i1 %27, label %label_1023, label %label_1025

label_1020:                                       ; preds = %label_1019
  ret ptr @.str.s389

label_1025:                                       ; preds = %label_1022
  %28 = load ptr, ptr %t.657, align 8
  %29 = getelementptr inbounds nuw %TypeInfo, ptr %28, i32 0, i32 0
  %30 = load i32, ptr %29, align 4
  %31 = icmp eq i32 %30, 7
  br i1 %31, label %label_1026, label %label_1028

label_1023:                                       ; preds = %label_1022
  ret ptr @.str.s390

label_1028:                                       ; preds = %label_1025
  %32 = load ptr, ptr %t.657, align 8
  %33 = getelementptr inbounds nuw %TypeInfo, ptr %32, i32 0, i32 0
  %34 = load i32, ptr %33, align 4
  %35 = icmp eq i32 %34, 8
  br i1 %35, label %label_1029, label %label_1031

label_1026:                                       ; preds = %label_1025
  ret ptr @.str.s391

label_1031:                                       ; preds = %label_1028
  %36 = load ptr, ptr %t.657, align 8
  %37 = getelementptr inbounds nuw %TypeInfo, ptr %36, i32 0, i32 0
  %38 = load i32, ptr %37, align 4
  %39 = icmp eq i32 %38, 9
  br i1 %39, label %label_1032, label %label_1034

label_1029:                                       ; preds = %label_1028
  %40 = load ptr, ptr %t.657, align 8
  %41 = getelementptr inbounds nuw %TypeInfo, ptr %40, i32 0, i32 1
  %42 = load ptr, ptr %41, align 8
  %43 = call ptr @str_concat(ptr @.str.s392, ptr %42)
  ret ptr %43

label_1034:                                       ; preds = %label_1031
  %44 = load ptr, ptr %t.657, align 8
  %45 = getelementptr inbounds nuw %TypeInfo, ptr %44, i32 0, i32 0
  %46 = load i32, ptr %45, align 4
  %47 = icmp eq i32 %46, 10
  br i1 %47, label %label_1035, label %label_1037

label_1032:                                       ; preds = %label_1031
  %48 = load ptr, ptr %t.657, align 8
  %49 = getelementptr inbounds nuw %TypeInfo, ptr %48, i32 0, i32 1
  %50 = load ptr, ptr %49, align 8
  %51 = call ptr @str_concat(ptr @.str.s393, ptr %50)
  ret ptr %51

label_1037:                                       ; preds = %label_1034
  %52 = load ptr, ptr %t.657, align 8
  %53 = getelementptr inbounds nuw %TypeInfo, ptr %52, i32 0, i32 0
  %54 = load i32, ptr %53, align 4
  %55 = icmp eq i32 %54, 11
  br i1 %55, label %label_1041, label %label_1043

label_1035:                                       ; preds = %label_1034
  %56 = load ptr, ptr %t.657, align 8
  %57 = getelementptr inbounds nuw %TypeInfo, ptr %56, i32 0, i32 3
  %58 = load ptr, ptr %57, align 8
  %59 = call i32 @str_equals(ptr %58, ptr @.str.s394)
  %60 = icmp eq i32 %59, 0
  br i1 %60, label %label_1038, label %label_1040

label_1040:                                       ; preds = %label_1035
  ret ptr @.str.s396

label_1038:                                       ; preds = %label_1035
  %61 = load ptr, ptr %t.657, align 8
  %62 = getelementptr inbounds nuw %TypeInfo, ptr %61, i32 0, i32 3
  %63 = load ptr, ptr %62, align 8
  %64 = call ptr @ptr_to_type(ptr %63)
  %65 = call ptr @type_sem_key__Struct_TypeInfo(ptr %64)
  %66 = call ptr @str_concat(ptr @.str.s395, ptr %65)
  ret ptr %66

label_1043:                                       ; preds = %label_1037
  ret ptr @.str.s400

label_1041:                                       ; preds = %label_1037
  %67 = load ptr, ptr %t.657, align 8
  %68 = getelementptr inbounds nuw %TypeInfo, ptr %67, i32 0, i32 3
  %69 = load ptr, ptr %68, align 8
  %70 = call i32 @str_equals(ptr %69, ptr @.str.s397)
  %71 = icmp eq i32 %70, 0
  br i1 %71, label %label_1044, label %label_1046

label_1046:                                       ; preds = %label_1041
  ret ptr @.str.s399

label_1044:                                       ; preds = %label_1041
  %72 = load ptr, ptr %t.657, align 8
  %73 = getelementptr inbounds nuw %TypeInfo, ptr %72, i32 0, i32 3
  %74 = load ptr, ptr %73, align 8
  %75 = call ptr @ptr_to_type(ptr %74)
  %76 = call ptr @type_sem_key__Struct_TypeInfo(ptr %75)
  %77 = call ptr @str_concat(ptr @.str.s398, ptr %76)
  ret ptr %77
}

define ptr @type_storage_key__Struct_TypeInfo(ptr %0) {
entry:
  %t.658 = alloca ptr, align 8
  store ptr %0, ptr %t.658, align 8
  %1 = load ptr, ptr %t.658, align 8
  %2 = call ptr @type_ir_key__Struct_TypeInfo(ptr %1)
  %key.659 = alloca ptr, align 8
  store ptr %2, ptr %key.659, align 8
  %3 = load ptr, ptr %key.659, align 8
  %4 = call i32 @str_equals(ptr %3, ptr @.str.s401)
  %5 = icmp eq i32 %4, 1
  br i1 %5, label %label_1047, label %label_1049

label_1049:                                       ; preds = %entry
  %6 = load ptr, ptr %key.659, align 8
  %7 = call i32 @str_starts_with(ptr %6, ptr @.str.s403)
  %8 = icmp eq i32 %7, 1
  br i1 %8, label %label_1050, label %label_1052

label_1047:                                       ; preds = %entry
  ret ptr @.str.s402

label_1052:                                       ; preds = %label_1049
  %9 = load ptr, ptr %key.659, align 8
  ret ptr %9

label_1050:                                       ; preds = %label_1049
  ret ptr @.str.s404
}

define ptr @type_from_annotation__Struct_ASTNode(ptr %0) {
entry:
  %tn.660 = alloca ptr, align 8
  store ptr %0, ptr %tn.660, align 8
  %1 = load ptr, ptr %tn.660, align 8
  %2 = getelementptr inbounds nuw %ASTNode, ptr %1, i32 0, i32 3
  %3 = load i32, ptr %2, align 4
  %4 = icmp eq i32 %3, 1
  br i1 %4, label %label_1053, label %label_1055

label_1055:                                       ; preds = %entry
  %5 = load ptr, ptr %tn.660, align 8
  %6 = getelementptr inbounds nuw %ASTNode, ptr %5, i32 0, i32 1
  %7 = load ptr, ptr %6, align 8
  %8 = call i32 @str_equals(ptr %7, ptr @.str.s406)
  %9 = icmp eq i32 %8, 1
  br i1 %9, label %label_1059, label %label_1061

label_1053:                                       ; preds = %entry
  %10 = load ptr, ptr %tn.660, align 8
  %11 = getelementptr inbounds nuw %ASTNode, ptr %10, i32 0, i32 5
  %12 = load ptr, ptr %11, align 8
  %13 = call i32 @str_equals(ptr %12, ptr @.str.s405)
  %14 = icmp eq i32 %13, 0
  br i1 %14, label %label_1056, label %label_1058

label_1058:                                       ; preds = %label_1053
  %15 = call ptr @type_invalid__Void()
  %16 = call ptr @type_array__Struct_TypeInfo(ptr %15)
  ret ptr %16

label_1056:                                       ; preds = %label_1053
  %17 = load ptr, ptr %tn.660, align 8
  %18 = getelementptr inbounds nuw %ASTNode, ptr %17, i32 0, i32 5
  %19 = load ptr, ptr %18, align 8
  %20 = call ptr @ptr_to_node(ptr %19)
  %21 = call ptr @type_from_annotation__Struct_ASTNode(ptr %20)
  %22 = call ptr @type_array__Struct_TypeInfo(ptr %21)
  ret ptr %22

label_1061:                                       ; preds = %label_1055
  %23 = load ptr, ptr %tn.660, align 8
  %24 = getelementptr inbounds nuw %ASTNode, ptr %23, i32 0, i32 1
  %25 = load ptr, ptr %24, align 8
  %26 = call i32 @str_equals(ptr %25, ptr @.str.s407)
  %27 = icmp eq i32 %26, 1
  br i1 %27, label %label_1062, label %label_1064

label_1059:                                       ; preds = %label_1055
  %28 = call ptr @type_int__Void()
  ret ptr %28

label_1064:                                       ; preds = %label_1061
  %29 = load ptr, ptr %tn.660, align 8
  %30 = getelementptr inbounds nuw %ASTNode, ptr %29, i32 0, i32 1
  %31 = load ptr, ptr %30, align 8
  %32 = call i32 @str_equals(ptr %31, ptr @.str.s408)
  %33 = icmp eq i32 %32, 1
  br i1 %33, label %label_1065, label %label_1067

label_1062:                                       ; preds = %label_1061
  %34 = call ptr @type_float__Void()
  ret ptr %34

label_1067:                                       ; preds = %label_1064
  %35 = load ptr, ptr %tn.660, align 8
  %36 = getelementptr inbounds nuw %ASTNode, ptr %35, i32 0, i32 1
  %37 = load ptr, ptr %36, align 8
  %38 = call i32 @str_equals(ptr %37, ptr @.str.s409)
  %39 = icmp eq i32 %38, 1
  br i1 %39, label %label_1068, label %label_1070

label_1065:                                       ; preds = %label_1064
  %40 = call ptr @type_bool__Void()
  ret ptr %40

label_1070:                                       ; preds = %label_1067
  %41 = load ptr, ptr %tn.660, align 8
  %42 = getelementptr inbounds nuw %ASTNode, ptr %41, i32 0, i32 1
  %43 = load ptr, ptr %42, align 8
  %44 = call i32 @str_equals(ptr %43, ptr @.str.s410)
  %45 = icmp eq i32 %44, 1
  br i1 %45, label %label_1071, label %label_1073

label_1068:                                       ; preds = %label_1067
  %46 = call ptr @type_string__Void()
  ret ptr %46

label_1073:                                       ; preds = %label_1070
  %47 = load ptr, ptr %tn.660, align 8
  %48 = getelementptr inbounds nuw %ASTNode, ptr %47, i32 0, i32 1
  %49 = load ptr, ptr %48, align 8
  %50 = call i32 @str_equals(ptr %49, ptr @.str.s411)
  %51 = icmp eq i32 %50, 1
  br i1 %51, label %label_1074, label %label_1076

label_1071:                                       ; preds = %label_1070
  %52 = call ptr @type_char__Void()
  ret ptr %52

label_1076:                                       ; preds = %label_1073
  %53 = load ptr, ptr %tn.660, align 8
  %54 = getelementptr inbounds nuw %ASTNode, ptr %53, i32 0, i32 1
  %55 = load ptr, ptr %54, align 8
  %56 = call i32 @str_equals(ptr %55, ptr @.str.s412)
  %57 = icmp eq i32 %56, 1
  br i1 %57, label %label_1077, label %label_1079

label_1074:                                       ; preds = %label_1073
  %58 = call ptr @type_i8__Void()
  ret ptr %58

label_1079:                                       ; preds = %label_1076
  %59 = load ptr, ptr %tn.660, align 8
  %60 = getelementptr inbounds nuw %ASTNode, ptr %59, i32 0, i32 1
  %61 = load ptr, ptr %60, align 8
  %62 = call i32 @str_equals(ptr %61, ptr @.str.s413)
  %63 = icmp eq i32 %62, 1
  br i1 %63, label %label_1080, label %label_1082

label_1077:                                       ; preds = %label_1076
  %64 = call ptr @type_i16__Void()
  ret ptr %64

label_1082:                                       ; preds = %label_1079
  %65 = load ptr, ptr %tn.660, align 8
  %66 = getelementptr inbounds nuw %ASTNode, ptr %65, i32 0, i32 1
  %67 = load ptr, ptr %66, align 8
  %68 = call i32 @str_equals(ptr %67, ptr @.str.s414)
  %69 = icmp eq i32 %68, 1
  br i1 %69, label %label_1083, label %label_1085

label_1080:                                       ; preds = %label_1079
  %70 = call ptr @type_i64__Void()
  ret ptr %70

label_1085:                                       ; preds = %label_1082
  %71 = load ptr, ptr %tn.660, align 8
  %72 = getelementptr inbounds nuw %ASTNode, ptr %71, i32 0, i32 1
  %73 = load ptr, ptr %72, align 8
  %74 = call i32 @str_equals(ptr %73, ptr @.str.s415)
  %75 = icmp eq i32 %74, 1
  br i1 %75, label %label_1086, label %label_1088

label_1083:                                       ; preds = %label_1082
  %76 = call ptr @type_isize__Void()
  ret ptr %76

label_1088:                                       ; preds = %label_1085
  %77 = load ptr, ptr %tn.660, align 8
  %78 = getelementptr inbounds nuw %ASTNode, ptr %77, i32 0, i32 1
  %79 = load ptr, ptr %78, align 8
  %80 = call i32 @str_equals(ptr %79, ptr @.str.s416)
  %81 = icmp eq i32 %80, 1
  br i1 %81, label %label_1089, label %label_1091

label_1086:                                       ; preds = %label_1085
  %82 = call ptr @type_u8__Void()
  ret ptr %82

label_1091:                                       ; preds = %label_1088
  %83 = load ptr, ptr %tn.660, align 8
  %84 = getelementptr inbounds nuw %ASTNode, ptr %83, i32 0, i32 1
  %85 = load ptr, ptr %84, align 8
  %86 = call i32 @str_equals(ptr %85, ptr @.str.s417)
  %87 = icmp eq i32 %86, 1
  br i1 %87, label %label_1092, label %label_1094

label_1089:                                       ; preds = %label_1088
  %88 = call ptr @type_u16__Void()
  ret ptr %88

label_1094:                                       ; preds = %label_1091
  %89 = load ptr, ptr %tn.660, align 8
  %90 = getelementptr inbounds nuw %ASTNode, ptr %89, i32 0, i32 1
  %91 = load ptr, ptr %90, align 8
  %92 = call i32 @str_equals(ptr %91, ptr @.str.s418)
  %93 = icmp eq i32 %92, 1
  br i1 %93, label %label_1095, label %label_1097

label_1092:                                       ; preds = %label_1091
  %94 = call ptr @type_u32__Void()
  ret ptr %94

label_1097:                                       ; preds = %label_1094
  %95 = load ptr, ptr %tn.660, align 8
  %96 = getelementptr inbounds nuw %ASTNode, ptr %95, i32 0, i32 1
  %97 = load ptr, ptr %96, align 8
  %98 = call i32 @str_equals(ptr %97, ptr @.str.s419)
  %99 = icmp eq i32 %98, 1
  br i1 %99, label %label_1098, label %label_1100

label_1095:                                       ; preds = %label_1094
  %100 = call ptr @type_u64__Void()
  ret ptr %100

label_1100:                                       ; preds = %label_1097
  %101 = load ptr, ptr %tn.660, align 8
  %102 = getelementptr inbounds nuw %ASTNode, ptr %101, i32 0, i32 1
  %103 = load ptr, ptr %102, align 8
  %104 = call i32 @str_equals(ptr %103, ptr @.str.s420)
  %105 = icmp eq i32 %104, 1
  br i1 %105, label %label_1101, label %label_1103

label_1098:                                       ; preds = %label_1097
  %106 = call ptr @type_usize__Void()
  ret ptr %106

label_1103:                                       ; preds = %label_1100
  %107 = load ptr, ptr %tn.660, align 8
  %108 = getelementptr inbounds nuw %ASTNode, ptr %107, i32 0, i32 1
  %109 = load ptr, ptr %108, align 8
  %110 = call ptr @type_struct__String(ptr %109)
  ret ptr %110

label_1101:                                       ; preds = %label_1100
  %111 = call ptr @type_void__Void()
  ret ptr %111
}

define ptr @type_from_ir_key__String(ptr %0) {
entry:
  %key.661 = alloca ptr, align 8
  store ptr %0, ptr %key.661, align 8
  %1 = load ptr, ptr %key.661, align 8
  %2 = call i32 @str_equals(ptr %1, ptr @.str.s421)
  %3 = icmp eq i32 %2, 1
  br i1 %3, label %label_1104, label %label_1106

label_1106:                                       ; preds = %entry
  %4 = load ptr, ptr %key.661, align 8
  %5 = call i32 @str_equals(ptr %4, ptr @.str.s422)
  %6 = icmp eq i32 %5, 1
  br i1 %6, label %label_1107, label %label_1109

label_1104:                                       ; preds = %entry
  %7 = call ptr @type_int__Void()
  ret ptr %7

label_1109:                                       ; preds = %label_1106
  %8 = load ptr, ptr %key.661, align 8
  %9 = call i32 @str_equals(ptr %8, ptr @.str.s423)
  %10 = icmp eq i32 %9, 1
  br i1 %10, label %label_1110, label %label_1112

label_1107:                                       ; preds = %label_1106
  %11 = call ptr @type_float__Void()
  ret ptr %11

label_1112:                                       ; preds = %label_1109
  %12 = load ptr, ptr %key.661, align 8
  %13 = call i32 @str_equals(ptr %12, ptr @.str.s424)
  %14 = icmp eq i32 %13, 1
  br i1 %14, label %label_1113, label %label_1115

label_1110:                                       ; preds = %label_1109
  %15 = call ptr @type_bool__Void()
  ret ptr %15

label_1115:                                       ; preds = %label_1112
  %16 = load ptr, ptr %key.661, align 8
  %17 = call i32 @str_equals(ptr %16, ptr @.str.s425)
  %18 = icmp eq i32 %17, 1
  br i1 %18, label %label_1116, label %label_1118

label_1113:                                       ; preds = %label_1112
  %19 = call ptr @type_char__Void()
  ret ptr %19

label_1118:                                       ; preds = %label_1115
  %20 = load ptr, ptr %key.661, align 8
  %21 = call i32 @str_equals(ptr %20, ptr @.str.s426)
  %22 = icmp eq i32 %21, 1
  br i1 %22, label %label_1119, label %label_1121

label_1116:                                       ; preds = %label_1115
  %23 = call ptr @type_ptr__Void()
  ret ptr %23

label_1121:                                       ; preds = %label_1118
  %24 = load ptr, ptr %key.661, align 8
  %25 = call i32 @str_starts_with(ptr %24, ptr @.str.s427)
  %26 = icmp eq i32 %25, 1
  br i1 %26, label %label_1122, label %label_1124

label_1119:                                       ; preds = %label_1118
  %27 = call ptr @type_void__Void()
  ret ptr %27

label_1124:                                       ; preds = %label_1121
  %28 = call ptr @type_invalid__Void()
  ret ptr %28

label_1122:                                       ; preds = %label_1121
  %29 = load ptr, ptr %key.661, align 8
  %30 = load ptr, ptr %key.661, align 8
  %31 = call i32 @str_length(ptr %30)
  %32 = sub i32 %31, 7
  %33 = call ptr @str_substring(ptr %29, i32 7, i32 %32)
  %34 = call ptr @type_struct__String(ptr %33)
  ret ptr %34
}

define ptr @type_from_sem_key__String(ptr %0) {
entry:
  %key.662 = alloca ptr, align 8
  store ptr %0, ptr %key.662, align 8
  %1 = load ptr, ptr %key.662, align 8
  %2 = call i32 @str_equals(ptr %1, ptr @.str.s428)
  %3 = icmp eq i32 %2, 1
  br i1 %3, label %label_1125, label %label_1127

label_1127:                                       ; preds = %entry
  %4 = load ptr, ptr %key.662, align 8
  %5 = call i32 @str_equals(ptr %4, ptr @.str.s429)
  %6 = icmp eq i32 %5, 1
  br i1 %6, label %label_1128, label %label_1130

label_1125:                                       ; preds = %entry
  %7 = call ptr @type_int__Void()
  ret ptr %7

label_1130:                                       ; preds = %label_1127
  %8 = load ptr, ptr %key.662, align 8
  %9 = call i32 @str_equals(ptr %8, ptr @.str.s430)
  %10 = icmp eq i32 %9, 1
  br i1 %10, label %label_1131, label %label_1133

label_1128:                                       ; preds = %label_1127
  %11 = call ptr @type_float__Void()
  ret ptr %11

label_1133:                                       ; preds = %label_1130
  %12 = load ptr, ptr %key.662, align 8
  %13 = call i32 @str_equals(ptr %12, ptr @.str.s431)
  %14 = icmp eq i32 %13, 1
  br i1 %14, label %label_1134, label %label_1136

label_1131:                                       ; preds = %label_1130
  %15 = call ptr @type_bool__Void()
  ret ptr %15

label_1136:                                       ; preds = %label_1133
  %16 = load ptr, ptr %key.662, align 8
  %17 = call i32 @str_equals(ptr %16, ptr @.str.s432)
  %18 = icmp eq i32 %17, 1
  br i1 %18, label %label_1137, label %label_1139

label_1134:                                       ; preds = %label_1133
  %19 = call ptr @type_char__Void()
  ret ptr %19

label_1139:                                       ; preds = %label_1136
  %20 = load ptr, ptr %key.662, align 8
  %21 = call i32 @str_equals(ptr %20, ptr @.str.s433)
  %22 = icmp eq i32 %21, 1
  br i1 %22, label %label_1140, label %label_1142

label_1137:                                       ; preds = %label_1136
  %23 = call ptr @type_string__Void()
  ret ptr %23

label_1142:                                       ; preds = %label_1139
  %24 = load ptr, ptr %key.662, align 8
  %25 = call i32 @str_equals(ptr %24, ptr @.str.s434)
  %26 = icmp eq i32 %25, 1
  br i1 %26, label %label_1143, label %label_1145

label_1140:                                       ; preds = %label_1139
  %27 = call ptr @type_ptr__Void()
  ret ptr %27

label_1145:                                       ; preds = %label_1142
  %28 = load ptr, ptr %key.662, align 8
  %29 = call i32 @str_equals(ptr %28, ptr @.str.s435)
  %30 = icmp eq i32 %29, 1
  br i1 %30, label %label_1146, label %label_1148

label_1143:                                       ; preds = %label_1142
  %31 = call ptr @type_void__Void()
  ret ptr %31

label_1148:                                       ; preds = %label_1145
  %32 = load ptr, ptr %key.662, align 8
  %33 = call i32 @str_equals(ptr %32, ptr @.str.s436)
  %34 = icmp eq i32 %33, 1
  br i1 %34, label %label_1149, label %label_1151

label_1146:                                       ; preds = %label_1145
  %35 = call ptr @type_i8__Void()
  ret ptr %35

label_1151:                                       ; preds = %label_1148
  %36 = load ptr, ptr %key.662, align 8
  %37 = call i32 @str_equals(ptr %36, ptr @.str.s437)
  %38 = icmp eq i32 %37, 1
  br i1 %38, label %label_1152, label %label_1154

label_1149:                                       ; preds = %label_1148
  %39 = call ptr @type_i16__Void()
  ret ptr %39

label_1154:                                       ; preds = %label_1151
  %40 = load ptr, ptr %key.662, align 8
  %41 = call i32 @str_equals(ptr %40, ptr @.str.s438)
  %42 = icmp eq i32 %41, 1
  br i1 %42, label %label_1155, label %label_1157

label_1152:                                       ; preds = %label_1151
  %43 = call ptr @type_i64__Void()
  ret ptr %43

label_1157:                                       ; preds = %label_1154
  %44 = load ptr, ptr %key.662, align 8
  %45 = call i32 @str_equals(ptr %44, ptr @.str.s439)
  %46 = icmp eq i32 %45, 1
  br i1 %46, label %label_1158, label %label_1160

label_1155:                                       ; preds = %label_1154
  %47 = call ptr @type_isize__Void()
  ret ptr %47

label_1160:                                       ; preds = %label_1157
  %48 = load ptr, ptr %key.662, align 8
  %49 = call i32 @str_equals(ptr %48, ptr @.str.s440)
  %50 = icmp eq i32 %49, 1
  br i1 %50, label %label_1161, label %label_1163

label_1158:                                       ; preds = %label_1157
  %51 = call ptr @type_u8__Void()
  ret ptr %51

label_1163:                                       ; preds = %label_1160
  %52 = load ptr, ptr %key.662, align 8
  %53 = call i32 @str_equals(ptr %52, ptr @.str.s441)
  %54 = icmp eq i32 %53, 1
  br i1 %54, label %label_1164, label %label_1166

label_1161:                                       ; preds = %label_1160
  %55 = call ptr @type_u16__Void()
  ret ptr %55

label_1166:                                       ; preds = %label_1163
  %56 = load ptr, ptr %key.662, align 8
  %57 = call i32 @str_equals(ptr %56, ptr @.str.s442)
  %58 = icmp eq i32 %57, 1
  br i1 %58, label %label_1167, label %label_1169

label_1164:                                       ; preds = %label_1163
  %59 = call ptr @type_u32__Void()
  ret ptr %59

label_1169:                                       ; preds = %label_1166
  %60 = load ptr, ptr %key.662, align 8
  %61 = call i32 @str_equals(ptr %60, ptr @.str.s443)
  %62 = icmp eq i32 %61, 1
  br i1 %62, label %label_1170, label %label_1172

label_1167:                                       ; preds = %label_1166
  %63 = call ptr @type_u64__Void()
  ret ptr %63

label_1172:                                       ; preds = %label_1169
  %64 = load ptr, ptr %key.662, align 8
  %65 = call i32 @str_starts_with(ptr %64, ptr @.str.s444)
  %66 = icmp eq i32 %65, 1
  br i1 %66, label %label_1173, label %label_1175

label_1170:                                       ; preds = %label_1169
  %67 = call ptr @type_usize__Void()
  ret ptr %67

label_1175:                                       ; preds = %label_1172
  %68 = load ptr, ptr %key.662, align 8
  %69 = call i32 @str_starts_with(ptr %68, ptr @.str.s445)
  %70 = icmp eq i32 %69, 1
  br i1 %70, label %label_1176, label %label_1178

label_1173:                                       ; preds = %label_1172
  %71 = load ptr, ptr %key.662, align 8
  %72 = load ptr, ptr %key.662, align 8
  %73 = call i32 @str_length(ptr %72)
  %74 = sub i32 %73, 7
  %75 = call ptr @str_substring(ptr %71, i32 7, i32 %74)
  %76 = call ptr @type_struct__String(ptr %75)
  ret ptr %76

label_1178:                                       ; preds = %label_1175
  %77 = load ptr, ptr %key.662, align 8
  %78 = call i32 @str_starts_with(ptr %77, ptr @.str.s446)
  %79 = icmp eq i32 %78, 1
  br i1 %79, label %label_1179, label %label_1181

label_1176:                                       ; preds = %label_1175
  %80 = load ptr, ptr %key.662, align 8
  %81 = load ptr, ptr %key.662, align 8
  %82 = call i32 @str_length(ptr %81)
  %83 = sub i32 %82, 5
  %84 = call ptr @str_substring(ptr %80, i32 5, i32 %83)
  %85 = call ptr @type_enum__String(ptr %84)
  ret ptr %85

label_1181:                                       ; preds = %label_1178
  %86 = load ptr, ptr %key.662, align 8
  %87 = call i32 @str_starts_with(ptr %86, ptr @.str.s447)
  %88 = icmp eq i32 %87, 1
  br i1 %88, label %label_1182, label %label_1184

label_1179:                                       ; preds = %label_1178
  %89 = load ptr, ptr %key.662, align 8
  %90 = load ptr, ptr %key.662, align 8
  %91 = call i32 @str_length(ptr %90)
  %92 = sub i32 %91, 6
  %93 = call ptr @str_substring(ptr %89, i32 6, i32 %92)
  %94 = call ptr @type_from_sem_key__String(ptr %93)
  %95 = call ptr @type_array__Struct_TypeInfo(ptr %94)
  ret ptr %95

label_1184:                                       ; preds = %label_1181
  %96 = call ptr @type_invalid__Void()
  ret ptr %96

label_1182:                                       ; preds = %label_1181
  %97 = load ptr, ptr %key.662, align 8
  %98 = load ptr, ptr %key.662, align 8
  %99 = call i32 @str_length(ptr %98)
  %100 = sub i32 %99, 5
  %101 = call ptr @str_substring(ptr %97, i32 5, i32 %100)
  %102 = call ptr @type_from_sem_key__String(ptr %101)
  %103 = call ptr @type_list__Struct_TypeInfo(ptr %102)
  ret ptr %103
}

define void @node_set_type__Struct_ASTNode_Struct_TypeInfo(ptr %0, ptr %1) {
entry:
  %node.663 = alloca ptr, align 8
  store ptr %0, ptr %node.663, align 8
  %t.664 = alloca ptr, align 8
  store ptr %1, ptr %t.664, align 8
  %2 = load ptr, ptr %node.663, align 8
  %3 = load ptr, ptr %t.664, align 8
  %4 = call ptr @type_to_ptr(ptr %3)
  %5 = getelementptr inbounds nuw %ASTNode, ptr %2, i32 0, i32 9
  store ptr %4, ptr %5, align 8
  ret void
}

define i1 @node_has_type__Struct_ASTNode(ptr %0) {
entry:
  %node.665 = alloca ptr, align 8
  store ptr %0, ptr %node.665, align 8
  %1 = load ptr, ptr %node.665, align 8
  %2 = getelementptr inbounds nuw %ASTNode, ptr %1, i32 0, i32 9
  %3 = load ptr, ptr %2, align 8
  %4 = call i32 @str_equals(ptr %3, ptr @.str.s448)
  %5 = icmp eq i32 %4, 0
  ret i1 %5
}

define ptr @node_get_type__Struct_ASTNode(ptr %0) {
entry:
  %node.666 = alloca ptr, align 8
  store ptr %0, ptr %node.666, align 8
  %1 = load ptr, ptr %node.666, align 8
  %2 = call i1 @node_has_type__Struct_ASTNode(ptr %1)
  br i1 %2, label %label_1185, label %label_1187

label_1187:                                       ; preds = %entry
  %3 = call ptr @type_invalid__Void()
  ret ptr %3

label_1185:                                       ; preds = %entry
  %4 = load ptr, ptr %node.666, align 8
  %5 = getelementptr inbounds nuw %ASTNode, ptr %4, i32 0, i32 9
  %6 = load ptr, ptr %5, align 8
  %7 = call ptr @ptr_to_type(ptr %6)
  ret ptr %7
}

define void @ir_set_target_wasm__Bool(i1 %0) {
entry:
  %enabled.667 = alloca i1, align 1
  store i1 %0, ptr %enabled.667, align 1
  %1 = load i1, ptr %enabled.667, align 1
  store i1 %1, ptr @ir_target_wasm, align 1
  ret void
}

define ptr @ir_ptr_int_type__Void() {
entry:
  %0 = load i1, ptr @ir_target_wasm, align 1
  br i1 %0, label %label_1188, label %label_1190

label_1190:                                       ; preds = %entry
  ret ptr @.str.s450

label_1188:                                       ; preds = %entry
  ret ptr @.str.s449
}

define ptr @map_type__String(ptr %0) {
entry:
  %t.668 = alloca ptr, align 8
  store ptr %0, ptr %t.668, align 8
  %1 = load ptr, ptr %t.668, align 8
  %2 = call i32 @str_equals(ptr %1, ptr @.str.s451)
  %3 = icmp eq i32 %2, 1
  br i1 %3, label %label_1191, label %label_1193

label_1193:                                       ; preds = %entry
  %4 = load ptr, ptr %t.668, align 8
  %5 = call i32 @str_equals(ptr %4, ptr @.str.s453)
  %6 = icmp eq i32 %5, 1
  br i1 %6, label %label_1194, label %label_1196

label_1191:                                       ; preds = %entry
  ret ptr @.str.s452

label_1196:                                       ; preds = %label_1193
  %7 = load ptr, ptr %t.668, align 8
  %8 = call i32 @str_equals(ptr %7, ptr @.str.s455)
  %9 = icmp eq i32 %8, 1
  br i1 %9, label %label_1197, label %label_1199

label_1194:                                       ; preds = %label_1193
  ret ptr @.str.s454

label_1199:                                       ; preds = %label_1196
  %10 = load ptr, ptr %t.668, align 8
  %11 = call i32 @str_equals(ptr %10, ptr @.str.s457)
  %12 = icmp eq i32 %11, 1
  br i1 %12, label %label_1200, label %label_1202

label_1197:                                       ; preds = %label_1196
  ret ptr @.str.s456

label_1202:                                       ; preds = %label_1199
  %13 = load ptr, ptr %t.668, align 8
  %14 = call i32 @str_equals(ptr %13, ptr @.str.s459)
  %15 = icmp eq i32 %14, 1
  br i1 %15, label %label_1203, label %label_1205

label_1200:                                       ; preds = %label_1199
  ret ptr @.str.s458

label_1205:                                       ; preds = %label_1202
  %16 = load ptr, ptr %t.668, align 8
  %17 = call i32 @str_equals(ptr %16, ptr @.str.s461)
  %18 = icmp eq i32 %17, 1
  br i1 %18, label %label_1206, label %label_1208

label_1203:                                       ; preds = %label_1202
  ret ptr @.str.s460

label_1208:                                       ; preds = %label_1205
  %19 = load ptr, ptr %t.668, align 8
  %20 = call i32 @str_equals(ptr %19, ptr @.str.s463)
  %21 = icmp eq i32 %20, 1
  br i1 %21, label %label_1209, label %label_1211

label_1206:                                       ; preds = %label_1205
  ret ptr @.str.s462

label_1211:                                       ; preds = %label_1208
  %22 = load ptr, ptr %t.668, align 8
  %23 = call i32 @str_equals(ptr %22, ptr @.str.s465)
  %24 = icmp eq i32 %23, 1
  br i1 %24, label %label_1212, label %label_1214

label_1209:                                       ; preds = %label_1208
  ret ptr @.str.s464

label_1214:                                       ; preds = %label_1211
  %25 = load ptr, ptr %t.668, align 8
  %26 = call i32 @str_equals(ptr %25, ptr @.str.s467)
  %27 = icmp eq i32 %26, 1
  br i1 %27, label %label_1215, label %label_1217

label_1212:                                       ; preds = %label_1211
  ret ptr @.str.s466

label_1217:                                       ; preds = %label_1214
  %28 = load ptr, ptr %t.668, align 8
  %29 = call i32 @str_equals(ptr %28, ptr @.str.s468)
  %30 = icmp eq i32 %29, 1
  br i1 %30, label %label_1218, label %label_1220

label_1215:                                       ; preds = %label_1214
  %31 = call ptr @ir_ptr_int_type__Void()
  ret ptr %31

label_1220:                                       ; preds = %label_1217
  %32 = load ptr, ptr %t.668, align 8
  %33 = call i32 @str_equals(ptr %32, ptr @.str.s470)
  %34 = icmp eq i32 %33, 1
  br i1 %34, label %label_1221, label %label_1223

label_1218:                                       ; preds = %label_1217
  ret ptr @.str.s469

label_1223:                                       ; preds = %label_1220
  %35 = load ptr, ptr %t.668, align 8
  %36 = call i32 @str_equals(ptr %35, ptr @.str.s472)
  %37 = icmp eq i32 %36, 1
  br i1 %37, label %label_1224, label %label_1226

label_1221:                                       ; preds = %label_1220
  ret ptr @.str.s471

label_1226:                                       ; preds = %label_1223
  %38 = load ptr, ptr %t.668, align 8
  %39 = call i32 @str_equals(ptr %38, ptr @.str.s474)
  %40 = icmp eq i32 %39, 1
  br i1 %40, label %label_1227, label %label_1229

label_1224:                                       ; preds = %label_1223
  ret ptr @.str.s473

label_1229:                                       ; preds = %label_1226
  %41 = load ptr, ptr %t.668, align 8
  %42 = call i32 @str_equals(ptr %41, ptr @.str.s476)
  %43 = icmp eq i32 %42, 1
  br i1 %43, label %label_1230, label %label_1232

label_1227:                                       ; preds = %label_1226
  ret ptr @.str.s475

label_1232:                                       ; preds = %label_1229
  %44 = load ptr, ptr %t.668, align 8
  %45 = call i32 @str_equals(ptr %44, ptr @.str.s477)
  %46 = icmp eq i32 %45, 1
  br i1 %46, label %label_1233, label %label_1235

label_1230:                                       ; preds = %label_1229
  %47 = call ptr @ir_ptr_int_type__Void()
  ret ptr %47

label_1235:                                       ; preds = %label_1232
  ret ptr @.str.s479

label_1233:                                       ; preds = %label_1232
  ret ptr @.str.s478
}

define ptr @struct_type_key__String(ptr %0) {
entry:
  %name.669 = alloca ptr, align 8
  store ptr %0, ptr %name.669, align 8
  %1 = load ptr, ptr %name.669, align 8
  %2 = call ptr @str_concat(ptr @.str.s480, ptr %1)
  ret ptr %2
}

define i1 @is_struct_type_key__String(ptr %0) {
entry:
  %t.670 = alloca ptr, align 8
  store ptr %0, ptr %t.670, align 8
  %1 = load ptr, ptr %t.670, align 8
  %2 = call i32 @str_starts_with(ptr %1, ptr @.str.s481)
  %3 = icmp eq i32 %2, 1
  ret i1 %3
}

define ptr @struct_type_name__String(ptr %0) {
entry:
  %t.671 = alloca ptr, align 8
  store ptr %0, ptr %t.671, align 8
  %1 = load ptr, ptr %t.671, align 8
  %2 = load ptr, ptr %t.671, align 8
  %3 = call i32 @str_length(ptr %2)
  %4 = sub i32 %3, 7
  %5 = call ptr @str_substring(ptr %1, i32 7, i32 %4)
  ret ptr %5
}

define ptr @llvm_type_name__String(ptr %0) {
entry:
  %t.672 = alloca ptr, align 8
  store ptr %0, ptr %t.672, align 8
  %1 = load ptr, ptr %t.672, align 8
  %2 = call i1 @is_struct_type_key__String(ptr %1)
  br i1 %2, label %label_1236, label %label_1238

label_1238:                                       ; preds = %entry
  %3 = load ptr, ptr %t.672, align 8
  ret ptr %3

label_1236:                                       ; preds = %entry
  %4 = load ptr, ptr %t.672, align 8
  %5 = call ptr @struct_type_name__String(ptr %4)
  %6 = call ptr @str_concat(ptr @.str.s482, ptr %5)
  ret ptr %6
}

define ptr @map_type_node__Struct_ASTNode(ptr %0) {
entry:
  %tn.673 = alloca ptr, align 8
  store ptr %0, ptr %tn.673, align 8
  %1 = load ptr, ptr %tn.673, align 8
  %2 = getelementptr inbounds nuw %ASTNode, ptr %1, i32 0, i32 4
  %3 = load i32, ptr %2, align 4
  %4 = icmp eq i32 %3, 1
  %elem.674 = alloca ptr, align 8
  br i1 %4, label %label_1239, label %label_1241

label_1241:                                       ; preds = %entry
  %5 = load ptr, ptr %tn.673, align 8
  %6 = getelementptr inbounds nuw %ASTNode, ptr %5, i32 0, i32 3
  %7 = load i32, ptr %6, align 4
  %8 = icmp eq i32 %7, 1
  br i1 %8, label %label_1242, label %label_1244

label_1239:                                       ; preds = %entry
  ret ptr @.str.s483

label_1244:                                       ; preds = %label_1241
  %9 = load ptr, ptr %tn.673, align 8
  %10 = getelementptr inbounds nuw %ASTNode, ptr %9, i32 0, i32 1
  %11 = load ptr, ptr %10, align 8
  %12 = call i32 @ir_is_struct_type_name(ptr %11)
  %13 = icmp eq i32 %12, 1
  br i1 %13, label %label_1251, label %label_1253

label_1242:                                       ; preds = %label_1241
  %14 = load ptr, ptr %tn.673, align 8
  %15 = getelementptr inbounds nuw %ASTNode, ptr %14, i32 0, i32 5
  %16 = load ptr, ptr %15, align 8
  %17 = call i32 @str_equals(ptr %16, ptr @.str.s484)
  %18 = icmp eq i32 %17, 0
  br i1 %18, label %label_1245, label %label_1247

label_1247:                                       ; preds = %label_1250, %label_1242
  ret ptr @.str.s486

label_1245:                                       ; preds = %label_1242
  %19 = load ptr, ptr %tn.673, align 8
  %20 = getelementptr inbounds nuw %ASTNode, ptr %19, i32 0, i32 5
  %21 = load ptr, ptr %20, align 8
  %22 = call ptr @ptr_to_node(ptr %21)
  store ptr %22, ptr %elem.674, align 8
  %23 = load ptr, ptr %elem.674, align 8
  %24 = getelementptr inbounds nuw %ASTNode, ptr %23, i32 0, i32 3
  %25 = load i32, ptr %24, align 4
  %26 = icmp eq i32 %25, 1
  br i1 %26, label %label_1248, label %label_1250

label_1250:                                       ; preds = %label_1245
  br label %label_1247

label_1248:                                       ; preds = %label_1245
  ret ptr @.str.s485

label_1253:                                       ; preds = %label_1244
  %27 = load ptr, ptr %tn.673, align 8
  %28 = getelementptr inbounds nuw %ASTNode, ptr %27, i32 0, i32 1
  %29 = load ptr, ptr %28, align 8
  %30 = call ptr @map_type__String(ptr %29)
  ret ptr %30

label_1251:                                       ; preds = %label_1244
  %31 = load ptr, ptr %tn.673, align 8
  %32 = getelementptr inbounds nuw %ASTNode, ptr %31, i32 0, i32 1
  %33 = load ptr, ptr %32, align 8
  %34 = call ptr @struct_type_key__String(ptr %33)
  ret ptr %34
}

define ptr @storage_type__String(ptr %0) {
entry:
  %t.675 = alloca ptr, align 8
  store ptr %0, ptr %t.675, align 8
  %1 = load ptr, ptr %t.675, align 8
  %2 = call i32 @str_equals(ptr %1, ptr @.str.s487)
  %3 = icmp eq i32 %2, 1
  br i1 %3, label %label_1254, label %label_1256

label_1256:                                       ; preds = %entry
  %4 = load ptr, ptr %t.675, align 8
  %5 = call i1 @is_struct_type_key__String(ptr %4)
  br i1 %5, label %label_1257, label %label_1259

label_1254:                                       ; preds = %entry
  ret ptr @.str.s488

label_1259:                                       ; preds = %label_1256
  %6 = load ptr, ptr %t.675, align 8
  ret ptr %6

label_1257:                                       ; preds = %label_1256
  ret ptr @.str.s489
}

define i32 @count_list_nodes__String(ptr %0) {
entry:
  %first_ptr.676 = alloca ptr, align 8
  store ptr %0, ptr %first_ptr.676, align 8
  %count.677 = alloca i32, align 4
  store i32 0, ptr %count.677, align 4
  %1 = load ptr, ptr %first_ptr.676, align 8
  %curr.678 = alloca ptr, align 8
  store ptr %1, ptr %curr.678, align 8
  %node.679 = alloca ptr, align 8
  br label %label_1260

label_1260:                                       ; preds = %label_1261, %entry
  %2 = load ptr, ptr %curr.678, align 8
  %3 = call i32 @str_equals(ptr %2, ptr @.str.s490)
  %4 = icmp eq i32 %3, 0
  br i1 %4, label %label_1261, label %label_1262

label_1262:                                       ; preds = %label_1260
  %5 = load i32, ptr %count.677, align 4
  ret i32 %5

label_1261:                                       ; preds = %label_1260
  %6 = load ptr, ptr %curr.678, align 8
  %7 = call ptr @ptr_to_node(ptr %6)
  store ptr %7, ptr %node.679, align 8
  %8 = load i32, ptr %count.677, align 4
  %9 = add i32 %8, 1
  store i32 %9, ptr %count.677, align 4
  %10 = load ptr, ptr %node.679, align 8
  %11 = getelementptr inbounds nuw %ASTNode, ptr %10, i32 0, i32 8
  %12 = load ptr, ptr %11, align 8
  store ptr %12, ptr %curr.678, align 8
  br label %label_1260
}

define ptr @fn_key__String(ptr %0) {
entry:
  %name.680 = alloca ptr, align 8
  store ptr %0, ptr %name.680, align 8
  %1 = load ptr, ptr %name.680, align 8
  %2 = call ptr @str_concat(ptr @.str.s491, ptr %1)
  ret ptr %2
}

define ptr @function_symbol_name__Struct_ASTNode(ptr %0) {
entry:
  %func.681 = alloca ptr, align 8
  store ptr %0, ptr %func.681, align 8
  %1 = load ptr, ptr %func.681, align 8
  %2 = getelementptr inbounds nuw %ASTNode, ptr %1, i32 0, i32 2
  %3 = load ptr, ptr %2, align 8
  %4 = call i32 @str_equals(ptr %3, ptr @.str.s492)
  %5 = icmp eq i32 %4, 0
  br i1 %5, label %label_1263, label %label_1265

label_1265:                                       ; preds = %entry
  %6 = load ptr, ptr %func.681, align 8
  %7 = getelementptr inbounds nuw %ASTNode, ptr %6, i32 0, i32 1
  %8 = load ptr, ptr %7, align 8
  ret ptr %8

label_1263:                                       ; preds = %entry
  %9 = load ptr, ptr %func.681, align 8
  %10 = getelementptr inbounds nuw %ASTNode, ptr %9, i32 0, i32 2
  %11 = load ptr, ptr %10, align 8
  ret ptr %11
}

define ptr @get_declared_return_type__Struct_ASTNode_String(ptr %0, ptr %1) {
entry:
  %node.682 = alloca ptr, align 8
  store ptr %0, ptr %node.682, align 8
  %ret_child.683 = alloca ptr, align 8
  store ptr %1, ptr %ret_child.683, align 8
  %2 = load ptr, ptr %ret_child.683, align 8
  %3 = call i32 @str_equals(ptr %2, ptr @.str.s493)
  %4 = icmp eq i32 %3, 0
  %ret_node.684 = alloca ptr, align 8
  br i1 %4, label %label_1266, label %label_1268

label_1268:                                       ; preds = %entry
  ret ptr @.str.s494

label_1266:                                       ; preds = %entry
  %5 = load ptr, ptr %ret_child.683, align 8
  %6 = call ptr @ptr_to_node(ptr %5)
  store ptr %6, ptr %ret_node.684, align 8
  %7 = load ptr, ptr %ret_node.684, align 8
  %8 = call ptr @map_type_node__Struct_ASTNode(ptr %7)
  ret ptr %8
}

define ptr @get_expr_type__Struct_ASTNode(ptr %0) {
entry:
  %expr.685 = alloca ptr, align 8
  store ptr %0, ptr %expr.685, align 8
  %1 = load ptr, ptr %expr.685, align 8
  %2 = call i1 @node_has_type__Struct_ASTNode(ptr %1)
  %op.686 = alloca ptr, align 8
  %sc.93 = alloca i1, align 1
  %sc.94 = alloca i1, align 1
  %sc.95 = alloca i1, align 1
  %sc.96 = alloca i1, align 1
  %callee.687 = alloca ptr, align 8
  %func_name.688 = alloca ptr, align 8
  %sc.97 = alloca i1, align 1
  %sc.98 = alloca i1, align 1
  %sc.99 = alloca i1, align 1
  %sc.100 = alloca i1, align 1
  %sc.101 = alloca i1, align 1
  %obj_type.689 = alloca ptr, align 8
  %object_node.690 = alloca ptr, align 8
  %enum_val.691 = alloca i32, align 4
  %object_type.692 = alloca ptr, align 8
  br i1 %2, label %label_1269, label %label_1271

label_1271:                                       ; preds = %entry
  %3 = load ptr, ptr %expr.685, align 8
  %4 = getelementptr inbounds nuw %ASTNode, ptr %3, i32 0, i32 0
  %5 = load i32, ptr %4, align 4
  %6 = icmp eq i32 %5, 22
  br i1 %6, label %label_1272, label %label_1274

label_1269:                                       ; preds = %entry
  %7 = load ptr, ptr %expr.685, align 8
  %8 = call ptr @node_get_type__Struct_ASTNode(ptr %7)
  %9 = call ptr @type_ir_key__Struct_TypeInfo(ptr %8)
  ret ptr %9

label_1274:                                       ; preds = %label_1289, %label_1271
  %10 = load ptr, ptr %expr.685, align 8
  %11 = getelementptr inbounds nuw %ASTNode, ptr %10, i32 0, i32 0
  %12 = load i32, ptr %11, align 4
  %13 = icmp eq i32 %12, 23
  br i1 %13, label %label_1290, label %label_1292

label_1272:                                       ; preds = %label_1271
  %14 = load ptr, ptr %expr.685, align 8
  %15 = getelementptr inbounds nuw %ASTNode, ptr %14, i32 0, i32 3
  %16 = load i32, ptr %15, align 4
  %17 = icmp eq i32 %16, 2
  br i1 %17, label %label_1275, label %label_1277

label_1277:                                       ; preds = %label_1272
  %18 = load ptr, ptr %expr.685, align 8
  %19 = getelementptr inbounds nuw %ASTNode, ptr %18, i32 0, i32 3
  %20 = load i32, ptr %19, align 4
  %21 = icmp eq i32 %20, 3
  br i1 %21, label %label_1278, label %label_1280

label_1275:                                       ; preds = %label_1272
  ret ptr @.str.s495

label_1280:                                       ; preds = %label_1277
  %22 = load ptr, ptr %expr.685, align 8
  %23 = getelementptr inbounds nuw %ASTNode, ptr %22, i32 0, i32 3
  %24 = load i32, ptr %23, align 4
  %25 = icmp eq i32 %24, 4
  br i1 %25, label %label_1281, label %label_1283

label_1278:                                       ; preds = %label_1277
  ret ptr @.str.s496

label_1283:                                       ; preds = %label_1280
  %26 = load ptr, ptr %expr.685, align 8
  %27 = getelementptr inbounds nuw %ASTNode, ptr %26, i32 0, i32 3
  %28 = load i32, ptr %27, align 4
  %29 = icmp eq i32 %28, 1
  br i1 %29, label %label_1284, label %label_1286

label_1281:                                       ; preds = %label_1280
  ret ptr @.str.s497

label_1286:                                       ; preds = %label_1283
  %30 = load ptr, ptr %expr.685, align 8
  %31 = getelementptr inbounds nuw %ASTNode, ptr %30, i32 0, i32 3
  %32 = load i32, ptr %31, align 4
  %33 = icmp eq i32 %32, 0
  br i1 %33, label %label_1287, label %label_1289

label_1284:                                       ; preds = %label_1283
  ret ptr @.str.s498

label_1289:                                       ; preds = %label_1286
  br label %label_1274

label_1287:                                       ; preds = %label_1286
  ret ptr @.str.s499

label_1292:                                       ; preds = %label_1274
  %34 = load ptr, ptr %expr.685, align 8
  %35 = getelementptr inbounds nuw %ASTNode, ptr %34, i32 0, i32 0
  %36 = load i32, ptr %35, align 4
  %37 = icmp eq i32 %36, 21
  br i1 %37, label %label_1293, label %label_1295

label_1290:                                       ; preds = %label_1274
  %38 = load ptr, ptr %expr.685, align 8
  %39 = getelementptr inbounds nuw %ASTNode, ptr %38, i32 0, i32 1
  %40 = load ptr, ptr %39, align 8
  %41 = call ptr @ir_get_var_type(ptr %40)
  ret ptr %41

label_1295:                                       ; preds = %label_1292
  %42 = load ptr, ptr %expr.685, align 8
  %43 = getelementptr inbounds nuw %ASTNode, ptr %42, i32 0, i32 0
  %44 = load i32, ptr %43, align 4
  %45 = icmp eq i32 %44, 29
  br i1 %45, label %label_1299, label %label_1301

label_1293:                                       ; preds = %label_1292
  %46 = load ptr, ptr %expr.685, align 8
  %47 = getelementptr inbounds nuw %ASTNode, ptr %46, i32 0, i32 1
  %48 = load ptr, ptr %47, align 8
  %49 = call i32 @str_equals(ptr %48, ptr @.str.s500)
  %50 = icmp eq i32 %49, 1
  br i1 %50, label %label_1296, label %label_1298

label_1298:                                       ; preds = %label_1293
  %51 = load ptr, ptr %expr.685, align 8
  %52 = getelementptr inbounds nuw %ASTNode, ptr %51, i32 0, i32 5
  %53 = load ptr, ptr %52, align 8
  %54 = call ptr @ptr_to_node(ptr %53)
  %55 = call ptr @get_expr_type__Struct_ASTNode(ptr %54)
  ret ptr %55

label_1296:                                       ; preds = %label_1293
  ret ptr @.str.s501

label_1301:                                       ; preds = %label_1295
  %56 = load ptr, ptr %expr.685, align 8
  %57 = getelementptr inbounds nuw %ASTNode, ptr %56, i32 0, i32 0
  %58 = load i32, ptr %57, align 4
  %59 = icmp eq i32 %58, 20
  br i1 %59, label %label_1302, label %label_1304

label_1299:                                       ; preds = %label_1295
  %60 = load ptr, ptr %expr.685, align 8
  %61 = getelementptr inbounds nuw %ASTNode, ptr %60, i32 0, i32 6
  %62 = load ptr, ptr %61, align 8
  %63 = call ptr @ptr_to_node(ptr %62)
  %64 = call ptr @map_type_node__Struct_ASTNode(ptr %63)
  ret ptr %64

label_1304:                                       ; preds = %label_1301
  %65 = load ptr, ptr %expr.685, align 8
  %66 = getelementptr inbounds nuw %ASTNode, ptr %65, i32 0, i32 0
  %67 = load i32, ptr %66, align 4
  %68 = icmp eq i32 %67, 24
  br i1 %68, label %label_1325, label %label_1327

label_1302:                                       ; preds = %label_1301
  %69 = load ptr, ptr %expr.685, align 8
  %70 = getelementptr inbounds nuw %ASTNode, ptr %69, i32 0, i32 1
  %71 = load ptr, ptr %70, align 8
  store ptr %71, ptr %op.686, align 8
  %72 = load ptr, ptr %op.686, align 8
  %73 = call i32 @str_equals(ptr %72, ptr @.str.s502)
  %74 = icmp eq i32 %73, 1
  store i1 %74, ptr %sc.93, align 1
  br i1 %74, label %label_1306, label %label_1305

label_1305:                                       ; preds = %label_1302
  %75 = load ptr, ptr %op.686, align 8
  %76 = call i32 @str_equals(ptr %75, ptr @.str.s503)
  %77 = icmp eq i32 %76, 1
  store i1 %77, ptr %sc.93, align 1
  br label %label_1306

label_1306:                                       ; preds = %label_1305, %label_1302
  %78 = load i1, ptr %sc.93, align 1
  br i1 %78, label %label_1307, label %label_1309

label_1309:                                       ; preds = %label_1306
  %79 = load ptr, ptr %op.686, align 8
  %80 = call i32 @str_equals(ptr %79, ptr @.str.s505)
  %81 = icmp eq i32 %80, 1
  store i1 %81, ptr %sc.94, align 1
  br i1 %81, label %label_1311, label %label_1310

label_1307:                                       ; preds = %label_1306
  ret ptr @.str.s504

label_1310:                                       ; preds = %label_1309
  %82 = load ptr, ptr %op.686, align 8
  %83 = call i32 @str_equals(ptr %82, ptr @.str.s506)
  %84 = icmp eq i32 %83, 1
  store i1 %84, ptr %sc.94, align 1
  br label %label_1311

label_1311:                                       ; preds = %label_1310, %label_1309
  %85 = load i1, ptr %sc.94, align 1
  br i1 %85, label %label_1312, label %label_1314

label_1314:                                       ; preds = %label_1311
  %86 = load ptr, ptr %op.686, align 8
  %87 = call i32 @str_equals(ptr %86, ptr @.str.s508)
  %88 = icmp eq i32 %87, 1
  store i1 %88, ptr %sc.95, align 1
  br i1 %88, label %label_1316, label %label_1315

label_1312:                                       ; preds = %label_1311
  ret ptr @.str.s507

label_1315:                                       ; preds = %label_1314
  %89 = load ptr, ptr %op.686, align 8
  %90 = call i32 @str_equals(ptr %89, ptr @.str.s509)
  %91 = icmp eq i32 %90, 1
  store i1 %91, ptr %sc.95, align 1
  br label %label_1316

label_1316:                                       ; preds = %label_1315, %label_1314
  %92 = load i1, ptr %sc.95, align 1
  br i1 %92, label %label_1317, label %label_1319

label_1319:                                       ; preds = %label_1316
  %93 = load ptr, ptr %op.686, align 8
  %94 = call i32 @str_equals(ptr %93, ptr @.str.s511)
  %95 = icmp eq i32 %94, 1
  store i1 %95, ptr %sc.96, align 1
  br i1 %95, label %label_1321, label %label_1320

label_1317:                                       ; preds = %label_1316
  ret ptr @.str.s510

label_1320:                                       ; preds = %label_1319
  %96 = load ptr, ptr %op.686, align 8
  %97 = call i32 @str_equals(ptr %96, ptr @.str.s512)
  %98 = icmp eq i32 %97, 1
  store i1 %98, ptr %sc.96, align 1
  br label %label_1321

label_1321:                                       ; preds = %label_1320, %label_1319
  %99 = load i1, ptr %sc.96, align 1
  br i1 %99, label %label_1322, label %label_1324

label_1324:                                       ; preds = %label_1321
  %100 = load ptr, ptr %expr.685, align 8
  %101 = getelementptr inbounds nuw %ASTNode, ptr %100, i32 0, i32 5
  %102 = load ptr, ptr %101, align 8
  %103 = call ptr @ptr_to_node(ptr %102)
  %104 = call ptr @get_expr_type__Struct_ASTNode(ptr %103)
  ret ptr %104

label_1322:                                       ; preds = %label_1321
  ret ptr @.str.s513

label_1327:                                       ; preds = %label_1304
  %105 = load ptr, ptr %expr.685, align 8
  %106 = getelementptr inbounds nuw %ASTNode, ptr %105, i32 0, i32 0
  %107 = load i32, ptr %106, align 4
  %108 = icmp eq i32 %107, 26
  br i1 %108, label %label_1356, label %label_1358

label_1325:                                       ; preds = %label_1304
  %109 = load ptr, ptr %expr.685, align 8
  %110 = getelementptr inbounds nuw %ASTNode, ptr %109, i32 0, i32 5
  %111 = load ptr, ptr %110, align 8
  %112 = call ptr @ptr_to_node(ptr %111)
  store ptr %112, ptr %callee.687, align 8
  %113 = load ptr, ptr %callee.687, align 8
  %114 = getelementptr inbounds nuw %ASTNode, ptr %113, i32 0, i32 1
  %115 = load ptr, ptr %114, align 8
  store ptr %115, ptr %func_name.688, align 8
  %116 = load ptr, ptr %func_name.688, align 8
  %117 = call i32 @str_equals(ptr %116, ptr @.str.s514)
  %118 = icmp eq i32 %117, 1
  store i1 %118, ptr %sc.97, align 1
  br i1 %118, label %label_1329, label %label_1328

label_1328:                                       ; preds = %label_1325
  %119 = load ptr, ptr %func_name.688, align 8
  %120 = call i32 @str_equals(ptr %119, ptr @.str.s515)
  %121 = icmp eq i32 %120, 1
  store i1 %121, ptr %sc.97, align 1
  br label %label_1329

label_1329:                                       ; preds = %label_1328, %label_1325
  %122 = load i1, ptr %sc.97, align 1
  br i1 %122, label %label_1330, label %label_1332

label_1332:                                       ; preds = %label_1329
  %123 = load ptr, ptr %func_name.688, align 8
  %124 = call i32 @str_equals(ptr %123, ptr @.str.s517)
  %125 = icmp eq i32 %124, 1
  store i1 %125, ptr %sc.98, align 1
  br i1 %125, label %label_1334, label %label_1333

label_1330:                                       ; preds = %label_1329
  ret ptr @.str.s516

label_1333:                                       ; preds = %label_1332
  %126 = load ptr, ptr %func_name.688, align 8
  %127 = call i32 @str_equals(ptr %126, ptr @.str.s518)
  %128 = icmp eq i32 %127, 1
  store i1 %128, ptr %sc.98, align 1
  br label %label_1334

label_1334:                                       ; preds = %label_1333, %label_1332
  %129 = load i1, ptr %sc.98, align 1
  br i1 %129, label %label_1335, label %label_1337

label_1337:                                       ; preds = %label_1334
  %130 = load ptr, ptr %func_name.688, align 8
  %131 = call i32 @str_equals(ptr %130, ptr @.str.s520)
  %132 = icmp eq i32 %131, 1
  store i1 %132, ptr %sc.99, align 1
  br i1 %132, label %label_1339, label %label_1338

label_1335:                                       ; preds = %label_1334
  ret ptr @.str.s519

label_1338:                                       ; preds = %label_1337
  %133 = load ptr, ptr %func_name.688, align 8
  %134 = call i32 @str_equals(ptr %133, ptr @.str.s521)
  %135 = icmp eq i32 %134, 1
  store i1 %135, ptr %sc.99, align 1
  br label %label_1339

label_1339:                                       ; preds = %label_1338, %label_1337
  %136 = load i1, ptr %sc.99, align 1
  br i1 %136, label %label_1340, label %label_1342

label_1342:                                       ; preds = %label_1339
  %137 = load ptr, ptr %func_name.688, align 8
  %138 = call i32 @str_equals(ptr %137, ptr @.str.s523)
  %139 = icmp eq i32 %138, 1
  store i1 %139, ptr %sc.100, align 1
  br i1 %139, label %label_1344, label %label_1343

label_1340:                                       ; preds = %label_1339
  ret ptr @.str.s522

label_1343:                                       ; preds = %label_1342
  %140 = load ptr, ptr %func_name.688, align 8
  %141 = call i32 @str_equals(ptr %140, ptr @.str.s524)
  %142 = icmp eq i32 %141, 1
  store i1 %142, ptr %sc.100, align 1
  br label %label_1344

label_1344:                                       ; preds = %label_1343, %label_1342
  %143 = load i1, ptr %sc.100, align 1
  br i1 %143, label %label_1345, label %label_1347

label_1347:                                       ; preds = %label_1344
  %144 = load ptr, ptr %func_name.688, align 8
  %145 = call i32 @str_equals(ptr %144, ptr @.str.s526)
  %146 = icmp eq i32 %145, 1
  store i1 %146, ptr %sc.101, align 1
  br i1 %146, label %label_1349, label %label_1348

label_1345:                                       ; preds = %label_1344
  ret ptr @.str.s525

label_1348:                                       ; preds = %label_1347
  %147 = load ptr, ptr %func_name.688, align 8
  %148 = call i32 @str_equals(ptr %147, ptr @.str.s527)
  %149 = icmp eq i32 %148, 1
  store i1 %149, ptr %sc.101, align 1
  br label %label_1349

label_1349:                                       ; preds = %label_1348, %label_1347
  %150 = load i1, ptr %sc.101, align 1
  br i1 %150, label %label_1350, label %label_1352

label_1352:                                       ; preds = %label_1349
  %151 = load ptr, ptr %expr.685, align 8
  %152 = getelementptr inbounds nuw %ASTNode, ptr %151, i32 0, i32 2
  %153 = load ptr, ptr %152, align 8
  %154 = call i32 @str_equals(ptr %153, ptr @.str.s529)
  %155 = icmp eq i32 %154, 0
  br i1 %155, label %label_1353, label %label_1355

label_1350:                                       ; preds = %label_1349
  ret ptr @.str.s528

label_1355:                                       ; preds = %label_1352
  %156 = load ptr, ptr %func_name.688, align 8
  %157 = call ptr @fn_key__String(ptr %156)
  %158 = call ptr @ir_get_var_type(ptr %157)
  ret ptr %158

label_1353:                                       ; preds = %label_1352
  %159 = load ptr, ptr %expr.685, align 8
  %160 = getelementptr inbounds nuw %ASTNode, ptr %159, i32 0, i32 2
  %161 = load ptr, ptr %160, align 8
  %162 = call ptr @fn_key__String(ptr %161)
  %163 = call ptr @ir_get_var_type(ptr %162)
  ret ptr %163

label_1358:                                       ; preds = %label_1327
  %164 = load ptr, ptr %expr.685, align 8
  %165 = getelementptr inbounds nuw %ASTNode, ptr %164, i32 0, i32 0
  %166 = load i32, ptr %165, align 4
  %167 = icmp eq i32 %166, 25
  br i1 %167, label %label_1362, label %label_1364

label_1356:                                       ; preds = %label_1327
  %168 = load ptr, ptr %expr.685, align 8
  %169 = getelementptr inbounds nuw %ASTNode, ptr %168, i32 0, i32 5
  %170 = load ptr, ptr %169, align 8
  %171 = call ptr @ptr_to_node(ptr %170)
  %172 = call ptr @get_expr_type__Struct_ASTNode(ptr %171)
  store ptr %172, ptr %obj_type.689, align 8
  %173 = load ptr, ptr %obj_type.689, align 8
  %174 = call i32 @str_equals(ptr %173, ptr @.str.s530)
  %175 = icmp eq i32 %174, 1
  br i1 %175, label %label_1359, label %label_1361

label_1361:                                       ; preds = %label_1356
  ret ptr @.str.s532

label_1359:                                       ; preds = %label_1356
  ret ptr @.str.s531

label_1364:                                       ; preds = %label_1358
  %176 = load ptr, ptr %expr.685, align 8
  %177 = getelementptr inbounds nuw %ASTNode, ptr %176, i32 0, i32 0
  %178 = load i32, ptr %177, align 4
  %179 = icmp eq i32 %178, 27
  br i1 %179, label %label_1374, label %label_1376

label_1362:                                       ; preds = %label_1358
  %180 = load ptr, ptr %expr.685, align 8
  %181 = getelementptr inbounds nuw %ASTNode, ptr %180, i32 0, i32 5
  %182 = load ptr, ptr %181, align 8
  %183 = call ptr @ptr_to_node(ptr %182)
  store ptr %183, ptr %object_node.690, align 8
  %184 = load ptr, ptr %object_node.690, align 8
  %185 = getelementptr inbounds nuw %ASTNode, ptr %184, i32 0, i32 0
  %186 = load i32, ptr %185, align 4
  %187 = icmp eq i32 %186, 23
  br i1 %187, label %label_1365, label %label_1367

label_1367:                                       ; preds = %label_1370, %label_1362
  %188 = load ptr, ptr %object_node.690, align 8
  %189 = call ptr @get_expr_type__Struct_ASTNode(ptr %188)
  store ptr %189, ptr %object_type.692, align 8
  %190 = load ptr, ptr %object_type.692, align 8
  %191 = call i1 @is_struct_type_key__String(ptr %190)
  br i1 %191, label %label_1371, label %label_1373

label_1365:                                       ; preds = %label_1362
  %192 = load ptr, ptr %object_node.690, align 8
  %193 = getelementptr inbounds nuw %ASTNode, ptr %192, i32 0, i32 1
  %194 = load ptr, ptr %193, align 8
  %195 = load ptr, ptr %expr.685, align 8
  %196 = getelementptr inbounds nuw %ASTNode, ptr %195, i32 0, i32 1
  %197 = load ptr, ptr %196, align 8
  %198 = call i32 @ir_get_enum_variant(ptr %194, ptr %197)
  store i32 %198, ptr %enum_val.691, align 4
  %199 = load i32, ptr %enum_val.691, align 4
  %200 = icmp sge i32 %199, 0
  br i1 %200, label %label_1368, label %label_1370

label_1370:                                       ; preds = %label_1365
  br label %label_1367

label_1368:                                       ; preds = %label_1365
  ret ptr @.str.s533

label_1373:                                       ; preds = %label_1367
  ret ptr @.str.s534

label_1371:                                       ; preds = %label_1367
  %201 = load ptr, ptr %object_type.692, align 8
  %202 = call ptr @struct_type_name__String(ptr %201)
  %203 = load ptr, ptr %expr.685, align 8
  %204 = getelementptr inbounds nuw %ASTNode, ptr %203, i32 0, i32 1
  %205 = load ptr, ptr %204, align 8
  %206 = call ptr @ir_get_struct_field_type(ptr %202, ptr %205)
  ret ptr %206

label_1376:                                       ; preds = %label_1364
  %207 = load ptr, ptr %expr.685, align 8
  %208 = getelementptr inbounds nuw %ASTNode, ptr %207, i32 0, i32 0
  %209 = load i32, ptr %208, align 4
  %210 = icmp eq i32 %209, 28
  br i1 %210, label %label_1377, label %label_1379

label_1374:                                       ; preds = %label_1364
  ret ptr @.str.s535

label_1379:                                       ; preds = %label_1376
  ret ptr @.str.s536

label_1377:                                       ; preds = %label_1376
  %211 = load ptr, ptr %expr.685, align 8
  %212 = getelementptr inbounds nuw %ASTNode, ptr %211, i32 0, i32 1
  %213 = load ptr, ptr %212, align 8
  %214 = call ptr @struct_type_key__String(ptr %213)
  ret ptr %214
}

define ptr @generate_short_circuit__Struct_ASTNode(ptr %0) {
entry:
  %expr.693 = alloca ptr, align 8
  store ptr %0, ptr %expr.693, align 8
  %1 = load ptr, ptr %expr.693, align 8
  %2 = getelementptr inbounds nuw %ASTNode, ptr %1, i32 0, i32 1
  %3 = load ptr, ptr %2, align 8
  %4 = call i32 @str_equals(ptr %3, ptr @.str.s537)
  %5 = icmp eq i32 %4, 1
  %is_and.694 = alloca i1, align 1
  store i1 %5, ptr %is_and.694, align 1
  %6 = load i32, ptr @ir_short_circuit_counter, align 4
  %7 = call ptr @int_to_str(i32 %6)
  %8 = call ptr @str_concat(ptr @.str.s538, ptr %7)
  %slot.695 = alloca ptr, align 8
  store ptr %8, ptr %slot.695, align 8
  %9 = load i32, ptr @ir_short_circuit_counter, align 4
  %10 = add i32 %9, 1
  store i32 %10, ptr @ir_short_circuit_counter, align 4
  %11 = load ptr, ptr %slot.695, align 8
  %12 = call i32 @ir_alloca(ptr @.str.s539, ptr %11)
  %13 = call i32 @ir_get_label()
  %rhs_label.696 = alloca i32, align 4
  store i32 %13, ptr %rhs_label.696, align 4
  %14 = call i32 @ir_get_label()
  %done_label.697 = alloca i32, align 4
  store i32 %14, ptr %done_label.697, align 4
  %15 = load ptr, ptr %expr.693, align 8
  %16 = getelementptr inbounds nuw %ASTNode, ptr %15, i32 0, i32 5
  %17 = load ptr, ptr %16, align 8
  %18 = call ptr @ptr_to_node(ptr %17)
  %19 = call ptr @generate_expression__Struct_ASTNode(ptr %18)
  %left_val.698 = alloca ptr, align 8
  store ptr %19, ptr %left_val.698, align 8
  %20 = load ptr, ptr %left_val.698, align 8
  %21 = load ptr, ptr %slot.695, align 8
  call void @ir_store(ptr @.str.s540, ptr %20, ptr %21)
  %22 = load i1, ptr %is_and.694, align 1
  %right_val.699 = alloca ptr, align 8
  %result_id.700 = alloca i32, align 4
  br i1 %22, label %label_1380, label %label_1381

label_1381:                                       ; preds = %entry
  %23 = load ptr, ptr %left_val.698, align 8
  %24 = load i32, ptr %done_label.697, align 4
  %25 = load i32, ptr %rhs_label.696, align 4
  call void @ir_cond_br_numbered(ptr %23, i32 %24, i32 %25)
  br label %label_1382

label_1380:                                       ; preds = %entry
  %26 = load ptr, ptr %left_val.698, align 8
  %27 = load i32, ptr %rhs_label.696, align 4
  %28 = load i32, ptr %done_label.697, align 4
  call void @ir_cond_br_numbered(ptr %26, i32 %27, i32 %28)
  br label %label_1382

label_1382:                                       ; preds = %label_1381, %label_1380
  %29 = load i32, ptr %rhs_label.696, align 4
  call void @ir_label_numbered(i32 %29)
  %30 = load ptr, ptr %expr.693, align 8
  %31 = getelementptr inbounds nuw %ASTNode, ptr %30, i32 0, i32 6
  %32 = load ptr, ptr %31, align 8
  %33 = call ptr @ptr_to_node(ptr %32)
  %34 = call ptr @generate_expression__Struct_ASTNode(ptr %33)
  store ptr %34, ptr %right_val.699, align 8
  %35 = load ptr, ptr %right_val.699, align 8
  %36 = load ptr, ptr %slot.695, align 8
  call void @ir_store(ptr @.str.s541, ptr %35, ptr %36)
  %37 = load i32, ptr %done_label.697, align 4
  call void @ir_br_numbered(i32 %37)
  %38 = load i32, ptr %done_label.697, align 4
  call void @ir_label_numbered(i32 %38)
  %39 = load ptr, ptr %slot.695, align 8
  %40 = call i32 @ir_load(ptr @.str.s542, ptr %39)
  store i32 %40, ptr %result_id.700, align 4
  %41 = load i32, ptr %result_id.700, align 4
  %42 = call ptr @ir_get_temp_name(i32 %41)
  ret ptr %42
}

define ptr @generate_expression__Struct_ASTNode(ptr %0) {
entry:
  %expr.701 = alloca ptr, align 8
  store ptr %0, ptr %expr.701, align 8
  %1 = load ptr, ptr %expr.701, align 8
  %2 = getelementptr inbounds nuw %ASTNode, ptr %1, i32 0, i32 0
  %3 = load i32, ptr %2, align 4
  %4 = icmp eq i32 %3, 22
  %struct_name.702 = alloca ptr, align 8
  %mem_name.703 = alloca ptr, align 8
  %field_ptr.704 = alloca ptr, align 8
  %field.705 = alloca ptr, align 8
  %field_val.706 = alloca ptr, align 8
  %field_type.707 = alloca ptr, align 8
  %field_index.708 = alloca i32, align 4
  %slot.709 = alloca i32, align 4
  %val_type.710 = alloca ptr, align 8
  %load_type.711 = alloca ptr, align 8
  %object_node.712 = alloca ptr, align 8
  %enum_val.713 = alloca i32, align 4
  %object_val.714 = alloca ptr, align 8
  %object_type.715 = alloca ptr, align 8
  %struct_name.716 = alloca ptr, align 8
  %field_index.717 = alloca i32, align 4
  %field_type.718 = alloca ptr, align 8
  %slot.719 = alloca i32, align 4
  %elem_count.720 = alloca i32, align 4
  %first_elem.721 = alloca ptr, align 8
  %arr_t.722 = alloca ptr, align 8
  %elem_type.723 = alloca ptr, align 8
  %base.724 = alloca ptr, align 8
  %elem_ptr.725 = alloca ptr, align 8
  %elem_index.726 = alloca i32, align 4
  %elem_node.727 = alloca ptr, align 8
  %elem_val.728 = alloca ptr, align 8
  %slot.729 = alloca i32, align 4
  %array_val.730 = alloca ptr, align 8
  %index_val.731 = alloca ptr, align 8
  %elem_type.732 = alloca ptr, align 8
  %slot.733 = alloca i32, align 4
  %source.734 = alloca ptr, align 8
  %val.735 = alloca ptr, align 8
  %from_t.736 = alloca ptr, align 8
  %to_t.737 = alloca ptr, align 8
  %from_key.738 = alloca ptr, align 8
  %to_key.739 = alloca ptr, align 8
  %sc.102 = alloca i1, align 1
  %sc.103 = alloca i1, align 1
  %zero_extend.740 = alloca i1, align 1
  %operand_node.741 = alloca ptr, align 8
  %operand_val.742 = alloca ptr, align 8
  %uop.743 = alloca ptr, align 8
  %not_id.744 = alloca i32, align 4
  %int_type.745 = alloca ptr, align 8
  %operand_type.746 = alloca ptr, align 8
  %fneg_id.747 = alloca i32, align 4
  %neg_id.748 = alloca i32, align 4
  %sc.104 = alloca i1, align 1
  %left_val.749 = alloca ptr, align 8
  %right_val.750 = alloca ptr, align 8
  %op.751 = alloca ptr, align 8
  %temp_id.752 = alloca i32, align 4
  %left_node.753 = alloca ptr, align 8
  %op_type.754 = alloca ptr, align 8
  %is_unsigned.755 = alloca i1, align 1
  %callee.756 = alloca ptr, align 8
  %func_name.757 = alloca ptr, align 8
  %drop_arg.758 = alloca ptr, align 8
  %drop_val.759 = alloca ptr, align 8
  %is_print_bool.760 = alloca i32, align 4
  %bool_arg_ptr.761 = alloca ptr, align 8
  %bool_arg.762 = alloca ptr, align 8
  %bool_val.763 = alloca ptr, align 8
  %widened.764 = alloca i32, align 4
  %is_print.765 = alloca i32, align 4
  %arg_ptr.766 = alloca ptr, align 8
  %arg_node.767 = alloca ptr, align 8
  %arg_val.768 = alloca ptr, align 8
  %arg_type.769 = alloca ptr, align 8
  %arg_ptr.770 = alloca ptr, align 8
  %arg_node.771 = alloca ptr, align 8
  %arg_val.772 = alloca ptr, align 8
  %call_name.773 = alloca ptr, align 8
  %ret_type.774 = alloca ptr, align 8
  %temp_id.775 = alloca i32, align 4
  br i1 %4, label %label_1383, label %label_1385

label_1385:                                       ; preds = %label_1403, %entry
  %5 = load ptr, ptr %expr.701, align 8
  %6 = getelementptr inbounds nuw %ASTNode, ptr %5, i32 0, i32 0
  %7 = load i32, ptr %6, align 4
  %8 = icmp eq i32 %7, 28
  br i1 %8, label %label_1404, label %label_1406

label_1383:                                       ; preds = %entry
  %9 = load ptr, ptr %expr.701, align 8
  %10 = getelementptr inbounds nuw %ASTNode, ptr %9, i32 0, i32 3
  %11 = load i32, ptr %10, align 4
  %12 = icmp eq i32 %11, 2
  br i1 %12, label %label_1386, label %label_1388

label_1388:                                       ; preds = %label_1383
  %13 = load ptr, ptr %expr.701, align 8
  %14 = getelementptr inbounds nuw %ASTNode, ptr %13, i32 0, i32 3
  %15 = load i32, ptr %14, align 4
  %16 = icmp eq i32 %15, 3
  br i1 %16, label %label_1389, label %label_1391

label_1386:                                       ; preds = %label_1383
  %17 = load ptr, ptr %expr.701, align 8
  %18 = getelementptr inbounds nuw %ASTNode, ptr %17, i32 0, i32 1
  %19 = load ptr, ptr %18, align 8
  ret ptr %19

label_1391:                                       ; preds = %label_1388
  %20 = load ptr, ptr %expr.701, align 8
  %21 = getelementptr inbounds nuw %ASTNode, ptr %20, i32 0, i32 3
  %22 = load i32, ptr %21, align 4
  %23 = icmp eq i32 %22, 4
  br i1 %23, label %label_1392, label %label_1394

label_1389:                                       ; preds = %label_1388
  %24 = load ptr, ptr %expr.701, align 8
  %25 = getelementptr inbounds nuw %ASTNode, ptr %24, i32 0, i32 1
  %26 = load ptr, ptr %25, align 8
  ret ptr %26

label_1394:                                       ; preds = %label_1391
  %27 = load ptr, ptr %expr.701, align 8
  %28 = getelementptr inbounds nuw %ASTNode, ptr %27, i32 0, i32 3
  %29 = load i32, ptr %28, align 4
  %30 = icmp eq i32 %29, 1
  br i1 %30, label %label_1398, label %label_1400

label_1392:                                       ; preds = %label_1391
  %31 = load ptr, ptr %expr.701, align 8
  %32 = getelementptr inbounds nuw %ASTNode, ptr %31, i32 0, i32 1
  %33 = load ptr, ptr %32, align 8
  %34 = call i32 @str_equals(ptr %33, ptr @.str.s543)
  %35 = icmp eq i32 %34, 1
  br i1 %35, label %label_1395, label %label_1397

label_1397:                                       ; preds = %label_1392
  ret ptr @.str.s545

label_1395:                                       ; preds = %label_1392
  ret ptr @.str.s544

label_1400:                                       ; preds = %label_1394
  %36 = load ptr, ptr %expr.701, align 8
  %37 = getelementptr inbounds nuw %ASTNode, ptr %36, i32 0, i32 3
  %38 = load i32, ptr %37, align 4
  %39 = icmp eq i32 %38, 0
  br i1 %39, label %label_1401, label %label_1403

label_1398:                                       ; preds = %label_1394
  %40 = load ptr, ptr %expr.701, align 8
  %41 = getelementptr inbounds nuw %ASTNode, ptr %40, i32 0, i32 1
  %42 = load ptr, ptr %41, align 8
  ret ptr %42

label_1403:                                       ; preds = %label_1400
  br label %label_1385

label_1401:                                       ; preds = %label_1400
  %43 = load ptr, ptr %expr.701, align 8
  %44 = getelementptr inbounds nuw %ASTNode, ptr %43, i32 0, i32 2
  %45 = load ptr, ptr %44, align 8
  %46 = call i32 @ir_string_ptr(ptr %45)
  %47 = call ptr @ir_get_temp_name(i32 %46)
  ret ptr %47

label_1406:                                       ; preds = %label_1385
  %48 = load ptr, ptr %expr.701, align 8
  %49 = getelementptr inbounds nuw %ASTNode, ptr %48, i32 0, i32 0
  %50 = load i32, ptr %49, align 4
  %51 = icmp eq i32 %50, 23
  br i1 %51, label %label_1410, label %label_1412

label_1404:                                       ; preds = %label_1385
  %52 = load ptr, ptr %expr.701, align 8
  %53 = getelementptr inbounds nuw %ASTNode, ptr %52, i32 0, i32 1
  %54 = load ptr, ptr %53, align 8
  store ptr %54, ptr %struct_name.702, align 8
  %55 = load ptr, ptr %struct_name.702, align 8
  %56 = call i32 @ir_alloc_object(ptr %55)
  %57 = call ptr @ir_get_temp_name(i32 %56)
  store ptr %57, ptr %mem_name.703, align 8
  %58 = load ptr, ptr %expr.701, align 8
  %59 = getelementptr inbounds nuw %ASTNode, ptr %58, i32 0, i32 5
  %60 = load ptr, ptr %59, align 8
  store ptr %60, ptr %field_ptr.704, align 8
  br label %label_1407

label_1407:                                       ; preds = %label_1408, %label_1404
  %61 = load ptr, ptr %field_ptr.704, align 8
  %62 = call i32 @str_equals(ptr %61, ptr @.str.s546)
  %63 = icmp eq i32 %62, 0
  br i1 %63, label %label_1408, label %label_1409

label_1409:                                       ; preds = %label_1407
  %64 = load ptr, ptr %mem_name.703, align 8
  ret ptr %64

label_1408:                                       ; preds = %label_1407
  %65 = load ptr, ptr %field_ptr.704, align 8
  %66 = call ptr @ptr_to_node(ptr %65)
  store ptr %66, ptr %field.705, align 8
  %67 = load ptr, ptr %field.705, align 8
  %68 = getelementptr inbounds nuw %ASTNode, ptr %67, i32 0, i32 5
  %69 = load ptr, ptr %68, align 8
  %70 = call ptr @ptr_to_node(ptr %69)
  %71 = call ptr @generate_expression__Struct_ASTNode(ptr %70)
  store ptr %71, ptr %field_val.706, align 8
  %72 = load ptr, ptr %struct_name.702, align 8
  %73 = load ptr, ptr %field.705, align 8
  %74 = getelementptr inbounds nuw %ASTNode, ptr %73, i32 0, i32 1
  %75 = load ptr, ptr %74, align 8
  %76 = call ptr @ir_get_struct_field_type(ptr %72, ptr %75)
  %77 = call ptr @storage_type__String(ptr %76)
  store ptr %77, ptr %field_type.707, align 8
  %78 = load ptr, ptr %struct_name.702, align 8
  %79 = load ptr, ptr %field.705, align 8
  %80 = getelementptr inbounds nuw %ASTNode, ptr %79, i32 0, i32 1
  %81 = load ptr, ptr %80, align 8
  %82 = call i32 @ir_get_struct_field_index(ptr %78, ptr %81)
  store i32 %82, ptr %field_index.708, align 4
  %83 = load ptr, ptr %struct_name.702, align 8
  %84 = load ptr, ptr %mem_name.703, align 8
  %85 = load i32, ptr %field_index.708, align 4
  %86 = call i32 @ir_struct_field_ptr(ptr %83, ptr %84, i32 %85)
  store i32 %86, ptr %slot.709, align 4
  %87 = load ptr, ptr %field_type.707, align 8
  %88 = load ptr, ptr %field_val.706, align 8
  %89 = load i32, ptr %slot.709, align 4
  %90 = call ptr @ir_get_temp_name(i32 %89)
  call void @ir_store_ptr(ptr %87, ptr %88, ptr %90)
  %91 = load ptr, ptr %field.705, align 8
  %92 = getelementptr inbounds nuw %ASTNode, ptr %91, i32 0, i32 8
  %93 = load ptr, ptr %92, align 8
  store ptr %93, ptr %field_ptr.704, align 8
  br label %label_1407

label_1412:                                       ; preds = %label_1406
  %94 = load ptr, ptr %expr.701, align 8
  %95 = getelementptr inbounds nuw %ASTNode, ptr %94, i32 0, i32 0
  %96 = load i32, ptr %95, align 4
  %97 = icmp eq i32 %96, 25
  br i1 %97, label %label_1416, label %label_1418

label_1410:                                       ; preds = %label_1406
  %98 = load ptr, ptr %expr.701, align 8
  %99 = getelementptr inbounds nuw %ASTNode, ptr %98, i32 0, i32 1
  %100 = load ptr, ptr %99, align 8
  %101 = call ptr @ir_get_var_type(ptr %100)
  store ptr %101, ptr %val_type.710, align 8
  %102 = load ptr, ptr %val_type.710, align 8
  %103 = call ptr @storage_type__String(ptr %102)
  store ptr %103, ptr %load_type.711, align 8
  %104 = load ptr, ptr %expr.701, align 8
  %105 = getelementptr inbounds nuw %ASTNode, ptr %104, i32 0, i32 1
  %106 = load ptr, ptr %105, align 8
  %107 = call i32 @ir_var_is_global(ptr %106)
  %108 = icmp eq i32 %107, 1
  br i1 %108, label %label_1413, label %label_1415

label_1415:                                       ; preds = %label_1410
  %109 = load ptr, ptr %load_type.711, align 8
  %110 = load ptr, ptr %expr.701, align 8
  %111 = getelementptr inbounds nuw %ASTNode, ptr %110, i32 0, i32 1
  %112 = load ptr, ptr %111, align 8
  %113 = call ptr @ir_get_var_slot(ptr %112)
  %114 = call i32 @ir_load(ptr %109, ptr %113)
  %115 = call ptr @ir_get_temp_name(i32 %114)
  ret ptr %115

label_1413:                                       ; preds = %label_1410
  %116 = load ptr, ptr %load_type.711, align 8
  %117 = load ptr, ptr %expr.701, align 8
  %118 = getelementptr inbounds nuw %ASTNode, ptr %117, i32 0, i32 1
  %119 = load ptr, ptr %118, align 8
  %120 = call i32 @ir_load_global(ptr %116, ptr %119)
  %121 = call ptr @ir_get_temp_name(i32 %120)
  ret ptr %121

label_1418:                                       ; preds = %label_1412
  %122 = load ptr, ptr %expr.701, align 8
  %123 = getelementptr inbounds nuw %ASTNode, ptr %122, i32 0, i32 0
  %124 = load i32, ptr %123, align 4
  %125 = icmp eq i32 %124, 27
  br i1 %125, label %label_1425, label %label_1427

label_1416:                                       ; preds = %label_1412
  %126 = load ptr, ptr %expr.701, align 8
  %127 = getelementptr inbounds nuw %ASTNode, ptr %126, i32 0, i32 5
  %128 = load ptr, ptr %127, align 8
  %129 = call ptr @ptr_to_node(ptr %128)
  store ptr %129, ptr %object_node.712, align 8
  %130 = load ptr, ptr %object_node.712, align 8
  %131 = getelementptr inbounds nuw %ASTNode, ptr %130, i32 0, i32 0
  %132 = load i32, ptr %131, align 4
  %133 = icmp eq i32 %132, 23
  br i1 %133, label %label_1419, label %label_1421

label_1421:                                       ; preds = %label_1424, %label_1416
  %134 = load ptr, ptr %object_node.712, align 8
  %135 = call ptr @generate_expression__Struct_ASTNode(ptr %134)
  store ptr %135, ptr %object_val.714, align 8
  %136 = load ptr, ptr %object_node.712, align 8
  %137 = call ptr @get_expr_type__Struct_ASTNode(ptr %136)
  store ptr %137, ptr %object_type.715, align 8
  %138 = load ptr, ptr %object_type.715, align 8
  %139 = call ptr @struct_type_name__String(ptr %138)
  store ptr %139, ptr %struct_name.716, align 8
  %140 = load ptr, ptr %struct_name.716, align 8
  %141 = load ptr, ptr %expr.701, align 8
  %142 = getelementptr inbounds nuw %ASTNode, ptr %141, i32 0, i32 1
  %143 = load ptr, ptr %142, align 8
  %144 = call i32 @ir_get_struct_field_index(ptr %140, ptr %143)
  store i32 %144, ptr %field_index.717, align 4
  %145 = load ptr, ptr %struct_name.716, align 8
  %146 = load ptr, ptr %expr.701, align 8
  %147 = getelementptr inbounds nuw %ASTNode, ptr %146, i32 0, i32 1
  %148 = load ptr, ptr %147, align 8
  %149 = call ptr @ir_get_struct_field_type(ptr %145, ptr %148)
  %150 = call ptr @storage_type__String(ptr %149)
  store ptr %150, ptr %field_type.718, align 8
  %151 = load ptr, ptr %struct_name.716, align 8
  %152 = load ptr, ptr %object_val.714, align 8
  %153 = load i32, ptr %field_index.717, align 4
  %154 = call i32 @ir_struct_field_ptr(ptr %151, ptr %152, i32 %153)
  store i32 %154, ptr %slot.719, align 4
  %155 = load ptr, ptr %field_type.718, align 8
  %156 = load i32, ptr %slot.719, align 4
  %157 = call ptr @ir_get_temp_name(i32 %156)
  %158 = call i32 @ir_load_ptr(ptr %155, ptr %157)
  %159 = call ptr @ir_get_temp_name(i32 %158)
  ret ptr %159

label_1419:                                       ; preds = %label_1416
  %160 = load ptr, ptr %object_node.712, align 8
  %161 = getelementptr inbounds nuw %ASTNode, ptr %160, i32 0, i32 1
  %162 = load ptr, ptr %161, align 8
  %163 = load ptr, ptr %expr.701, align 8
  %164 = getelementptr inbounds nuw %ASTNode, ptr %163, i32 0, i32 1
  %165 = load ptr, ptr %164, align 8
  %166 = call i32 @ir_get_enum_variant(ptr %162, ptr %165)
  store i32 %166, ptr %enum_val.713, align 4
  %167 = load i32, ptr %enum_val.713, align 4
  %168 = icmp sge i32 %167, 0
  br i1 %168, label %label_1422, label %label_1424

label_1424:                                       ; preds = %label_1419
  br label %label_1421

label_1422:                                       ; preds = %label_1419
  %169 = load i32, ptr %enum_val.713, align 4
  %170 = call ptr @int_to_str(i32 %169)
  ret ptr %170

label_1427:                                       ; preds = %label_1418
  %171 = load ptr, ptr %expr.701, align 8
  %172 = getelementptr inbounds nuw %ASTNode, ptr %171, i32 0, i32 0
  %173 = load i32, ptr %172, align 4
  %174 = icmp eq i32 %173, 26
  br i1 %174, label %label_1437, label %label_1439

label_1425:                                       ; preds = %label_1418
  %175 = load ptr, ptr %expr.701, align 8
  %176 = getelementptr inbounds nuw %ASTNode, ptr %175, i32 0, i32 5
  %177 = load ptr, ptr %176, align 8
  %178 = call i32 @count_list_nodes__String(ptr %177)
  store i32 %178, ptr %elem_count.720, align 4
  %179 = load ptr, ptr %expr.701, align 8
  %180 = getelementptr inbounds nuw %ASTNode, ptr %179, i32 0, i32 5
  %181 = load ptr, ptr %180, align 8
  %182 = call ptr @ptr_to_node(ptr %181)
  store ptr %182, ptr %first_elem.721, align 8
  %183 = load ptr, ptr %expr.701, align 8
  %184 = call ptr @node_get_type__Struct_ASTNode(ptr %183)
  store ptr %184, ptr %arr_t.722, align 8
  store ptr @.str.s547, ptr %elem_type.723, align 8
  %185 = load ptr, ptr %arr_t.722, align 8
  %186 = getelementptr inbounds nuw %TypeInfo, ptr %185, i32 0, i32 3
  %187 = load ptr, ptr %186, align 8
  %188 = call i32 @str_equals(ptr %187, ptr @.str.s548)
  %189 = icmp eq i32 %188, 0
  br i1 %189, label %label_1428, label %label_1429

label_1429:                                       ; preds = %label_1425
  %190 = load ptr, ptr %first_elem.721, align 8
  %191 = getelementptr inbounds nuw %ASTNode, ptr %190, i32 0, i32 0
  %192 = load i32, ptr %191, align 4
  %193 = icmp eq i32 %192, 27
  br i1 %193, label %label_1431, label %label_1433

label_1428:                                       ; preds = %label_1425
  %194 = load ptr, ptr %arr_t.722, align 8
  %195 = getelementptr inbounds nuw %TypeInfo, ptr %194, i32 0, i32 3
  %196 = load ptr, ptr %195, align 8
  %197 = call ptr @ptr_to_type(ptr %196)
  %198 = call ptr @type_ir_key__Struct_TypeInfo(ptr %197)
  %199 = call ptr @storage_type__String(ptr %198)
  store ptr %199, ptr %elem_type.723, align 8
  br label %label_1430

label_1430:                                       ; preds = %label_1433, %label_1428
  %200 = load ptr, ptr %elem_type.723, align 8
  %201 = load i32, ptr %elem_count.720, align 4
  %202 = call i32 @ir_array_alloca(ptr %200, i32 %201)
  %203 = call ptr @ir_get_temp_name(i32 %202)
  store ptr %203, ptr %base.724, align 8
  %204 = load ptr, ptr %expr.701, align 8
  %205 = getelementptr inbounds nuw %ASTNode, ptr %204, i32 0, i32 5
  %206 = load ptr, ptr %205, align 8
  store ptr %206, ptr %elem_ptr.725, align 8
  store i32 0, ptr %elem_index.726, align 4
  br label %label_1434

label_1433:                                       ; preds = %label_1431, %label_1429
  br label %label_1430

label_1431:                                       ; preds = %label_1429
  store ptr @.str.s549, ptr %elem_type.723, align 8
  br label %label_1433

label_1434:                                       ; preds = %label_1435, %label_1430
  %207 = load ptr, ptr %elem_ptr.725, align 8
  %208 = call i32 @str_equals(ptr %207, ptr @.str.s550)
  %209 = icmp eq i32 %208, 0
  br i1 %209, label %label_1435, label %label_1436

label_1436:                                       ; preds = %label_1434
  %210 = load ptr, ptr %base.724, align 8
  ret ptr %210

label_1435:                                       ; preds = %label_1434
  %211 = load ptr, ptr %elem_ptr.725, align 8
  %212 = call ptr @ptr_to_node(ptr %211)
  store ptr %212, ptr %elem_node.727, align 8
  %213 = load ptr, ptr %elem_node.727, align 8
  %214 = call ptr @generate_expression__Struct_ASTNode(ptr %213)
  store ptr %214, ptr %elem_val.728, align 8
  %215 = load ptr, ptr %elem_type.723, align 8
  %216 = load ptr, ptr %base.724, align 8
  %217 = load i32, ptr %elem_index.726, align 4
  %218 = call ptr @int_to_str(i32 %217)
  %219 = call i32 @ir_elem_ptr(ptr %215, ptr %216, ptr %218)
  store i32 %219, ptr %slot.729, align 4
  %220 = load ptr, ptr %elem_type.723, align 8
  %221 = load ptr, ptr %elem_val.728, align 8
  %222 = load i32, ptr %slot.729, align 4
  %223 = call ptr @ir_get_temp_name(i32 %222)
  call void @ir_store_ptr(ptr %220, ptr %221, ptr %223)
  %224 = load i32, ptr %elem_index.726, align 4
  %225 = add i32 %224, 1
  store i32 %225, ptr %elem_index.726, align 4
  %226 = load ptr, ptr %elem_node.727, align 8
  %227 = getelementptr inbounds nuw %ASTNode, ptr %226, i32 0, i32 8
  %228 = load ptr, ptr %227, align 8
  store ptr %228, ptr %elem_ptr.725, align 8
  br label %label_1434

label_1439:                                       ; preds = %label_1427
  %229 = load ptr, ptr %expr.701, align 8
  %230 = getelementptr inbounds nuw %ASTNode, ptr %229, i32 0, i32 0
  %231 = load i32, ptr %230, align 4
  %232 = icmp eq i32 %231, 29
  br i1 %232, label %label_1443, label %label_1445

label_1437:                                       ; preds = %label_1427
  %233 = load ptr, ptr %expr.701, align 8
  %234 = getelementptr inbounds nuw %ASTNode, ptr %233, i32 0, i32 5
  %235 = load ptr, ptr %234, align 8
  %236 = call ptr @ptr_to_node(ptr %235)
  %237 = call ptr @generate_expression__Struct_ASTNode(ptr %236)
  store ptr %237, ptr %array_val.730, align 8
  %238 = load ptr, ptr %expr.701, align 8
  %239 = getelementptr inbounds nuw %ASTNode, ptr %238, i32 0, i32 6
  %240 = load ptr, ptr %239, align 8
  %241 = call ptr @ptr_to_node(ptr %240)
  %242 = call ptr @generate_expression__Struct_ASTNode(ptr %241)
  store ptr %242, ptr %index_val.731, align 8
  %243 = load ptr, ptr %expr.701, align 8
  %244 = call ptr @get_expr_type__Struct_ASTNode(ptr %243)
  %245 = call ptr @storage_type__String(ptr %244)
  store ptr %245, ptr %elem_type.732, align 8
  %246 = load ptr, ptr %elem_type.732, align 8
  %247 = call i32 @str_equals(ptr %246, ptr @.str.s551)
  %248 = icmp eq i32 %247, 1
  br i1 %248, label %label_1440, label %label_1442

label_1442:                                       ; preds = %label_1440, %label_1437
  %249 = load ptr, ptr %elem_type.732, align 8
  %250 = load ptr, ptr %array_val.730, align 8
  %251 = load ptr, ptr %index_val.731, align 8
  %252 = call i32 @ir_elem_ptr(ptr %249, ptr %250, ptr %251)
  store i32 %252, ptr %slot.733, align 4
  %253 = load ptr, ptr %elem_type.732, align 8
  %254 = load i32, ptr %slot.733, align 4
  %255 = call ptr @ir_get_temp_name(i32 %254)
  %256 = call i32 @ir_load_ptr(ptr %253, ptr %255)
  %257 = call ptr @ir_get_temp_name(i32 %256)
  ret ptr %257

label_1440:                                       ; preds = %label_1437
  store ptr @.str.s552, ptr %elem_type.732, align 8
  br label %label_1442

label_1445:                                       ; preds = %label_1439
  %258 = load ptr, ptr %expr.701, align 8
  %259 = getelementptr inbounds nuw %ASTNode, ptr %258, i32 0, i32 0
  %260 = load i32, ptr %259, align 4
  %261 = icmp eq i32 %260, 21
  br i1 %261, label %label_1471, label %label_1473

label_1443:                                       ; preds = %label_1439
  %262 = load ptr, ptr %expr.701, align 8
  %263 = getelementptr inbounds nuw %ASTNode, ptr %262, i32 0, i32 5
  %264 = load ptr, ptr %263, align 8
  %265 = call ptr @ptr_to_node(ptr %264)
  store ptr %265, ptr %source.734, align 8
  %266 = load ptr, ptr %source.734, align 8
  %267 = call ptr @generate_expression__Struct_ASTNode(ptr %266)
  store ptr %267, ptr %val.735, align 8
  %268 = load ptr, ptr %source.734, align 8
  %269 = call ptr @node_get_type__Struct_ASTNode(ptr %268)
  store ptr %269, ptr %from_t.736, align 8
  %270 = load ptr, ptr %expr.701, align 8
  %271 = call ptr @node_get_type__Struct_ASTNode(ptr %270)
  store ptr %271, ptr %to_t.737, align 8
  %272 = load ptr, ptr %from_t.736, align 8
  %273 = call ptr @type_ir_key__Struct_TypeInfo(ptr %272)
  store ptr %273, ptr %from_key.738, align 8
  %274 = load ptr, ptr %to_t.737, align 8
  %275 = call ptr @type_ir_key__Struct_TypeInfo(ptr %274)
  store ptr %275, ptr %to_key.739, align 8
  %276 = load ptr, ptr %from_key.738, align 8
  %277 = load ptr, ptr %to_key.739, align 8
  %278 = call i32 @str_equals(ptr %276, ptr %277)
  %279 = icmp eq i32 %278, 1
  br i1 %279, label %label_1446, label %label_1448

label_1448:                                       ; preds = %label_1443
  %280 = load ptr, ptr %to_key.739, align 8
  %281 = call i32 @str_equals(ptr %280, ptr @.str.s553)
  %282 = icmp eq i32 %281, 1
  br i1 %282, label %label_1449, label %label_1451

label_1446:                                       ; preds = %label_1443
  %283 = load ptr, ptr %val.735, align 8
  ret ptr %283

label_1451:                                       ; preds = %label_1448
  %284 = load ptr, ptr %from_key.738, align 8
  %285 = call i32 @str_equals(ptr %284, ptr @.str.s554)
  %286 = icmp eq i32 %285, 1
  br i1 %286, label %label_1455, label %label_1457

label_1449:                                       ; preds = %label_1448
  %287 = load ptr, ptr %from_t.736, align 8
  %288 = call i1 @type_int_is_unsigned__Struct_TypeInfo(ptr %287)
  br i1 %288, label %label_1452, label %label_1454

label_1454:                                       ; preds = %label_1449
  %289 = load ptr, ptr %from_key.738, align 8
  %290 = load ptr, ptr %val.735, align 8
  %291 = load ptr, ptr %to_key.739, align 8
  %292 = call i32 @ir_sitofp(ptr %289, ptr %290, ptr %291)
  %293 = call ptr @ir_get_temp_name(i32 %292)
  ret ptr %293

label_1452:                                       ; preds = %label_1449
  %294 = load ptr, ptr %from_key.738, align 8
  %295 = load ptr, ptr %val.735, align 8
  %296 = load ptr, ptr %to_key.739, align 8
  %297 = call i32 @ir_uitofp(ptr %294, ptr %295, ptr %296)
  %298 = call ptr @ir_get_temp_name(i32 %297)
  ret ptr %298

label_1457:                                       ; preds = %label_1451
  %299 = load ptr, ptr %from_t.736, align 8
  %300 = call i32 @type_int_bits__Struct_TypeInfo(ptr %299)
  %301 = load ptr, ptr %to_t.737, align 8
  %302 = call i32 @type_int_bits__Struct_TypeInfo(ptr %301)
  %303 = icmp sgt i32 %300, %302
  br i1 %303, label %label_1461, label %label_1463

label_1455:                                       ; preds = %label_1451
  %304 = load ptr, ptr %to_t.737, align 8
  %305 = call i1 @type_int_is_unsigned__Struct_TypeInfo(ptr %304)
  br i1 %305, label %label_1458, label %label_1460

label_1460:                                       ; preds = %label_1455
  %306 = load ptr, ptr %from_key.738, align 8
  %307 = load ptr, ptr %val.735, align 8
  %308 = load ptr, ptr %to_key.739, align 8
  %309 = call i32 @ir_fptosi(ptr %306, ptr %307, ptr %308)
  %310 = call ptr @ir_get_temp_name(i32 %309)
  ret ptr %310

label_1458:                                       ; preds = %label_1455
  %311 = load ptr, ptr %from_key.738, align 8
  %312 = load ptr, ptr %val.735, align 8
  %313 = load ptr, ptr %to_key.739, align 8
  %314 = call i32 @ir_fptoui(ptr %311, ptr %312, ptr %313)
  %315 = call ptr @ir_get_temp_name(i32 %314)
  ret ptr %315

label_1463:                                       ; preds = %label_1457
  %316 = load ptr, ptr %from_t.736, align 8
  %317 = call i1 @type_int_is_unsigned__Struct_TypeInfo(ptr %316)
  store i1 %317, ptr %sc.103, align 1
  br i1 %317, label %label_1467, label %label_1466

label_1461:                                       ; preds = %label_1457
  %318 = load ptr, ptr %from_key.738, align 8
  %319 = load ptr, ptr %val.735, align 8
  %320 = load ptr, ptr %to_key.739, align 8
  %321 = call i32 @ir_trunc(ptr %318, ptr %319, ptr %320)
  %322 = call ptr @ir_get_temp_name(i32 %321)
  ret ptr %322

label_1466:                                       ; preds = %label_1463
  %323 = load ptr, ptr %from_t.736, align 8
  %324 = getelementptr inbounds nuw %TypeInfo, ptr %323, i32 0, i32 0
  %325 = load i32, ptr %324, align 4
  %326 = icmp eq i32 %325, 5
  store i1 %326, ptr %sc.103, align 1
  br label %label_1467

label_1467:                                       ; preds = %label_1466, %label_1463
  %327 = load i1, ptr %sc.103, align 1
  store i1 %327, ptr %sc.102, align 1
  br i1 %327, label %label_1465, label %label_1464

label_1464:                                       ; preds = %label_1467
  %328 = load ptr, ptr %from_t.736, align 8
  %329 = getelementptr inbounds nuw %TypeInfo, ptr %328, i32 0, i32 0
  %330 = load i32, ptr %329, align 4
  %331 = icmp eq i32 %330, 4
  store i1 %331, ptr %sc.102, align 1
  br label %label_1465

label_1465:                                       ; preds = %label_1464, %label_1467
  %332 = load i1, ptr %sc.102, align 1
  store i1 %332, ptr %zero_extend.740, align 1
  %333 = load i1, ptr %zero_extend.740, align 1
  br i1 %333, label %label_1468, label %label_1470

label_1470:                                       ; preds = %label_1465
  %334 = load ptr, ptr %from_key.738, align 8
  %335 = load ptr, ptr %val.735, align 8
  %336 = load ptr, ptr %to_key.739, align 8
  %337 = call i32 @ir_sext(ptr %334, ptr %335, ptr %336)
  %338 = call ptr @ir_get_temp_name(i32 %337)
  ret ptr %338

label_1468:                                       ; preds = %label_1465
  %339 = load ptr, ptr %from_key.738, align 8
  %340 = load ptr, ptr %val.735, align 8
  %341 = load ptr, ptr %to_key.739, align 8
  %342 = call i32 @ir_zext(ptr %339, ptr %340, ptr %341)
  %343 = call ptr @ir_get_temp_name(i32 %342)
  ret ptr %343

label_1473:                                       ; preds = %label_1482, %label_1445
  %344 = load ptr, ptr %expr.701, align 8
  %345 = getelementptr inbounds nuw %ASTNode, ptr %344, i32 0, i32 0
  %346 = load i32, ptr %345, align 4
  %347 = icmp eq i32 %346, 20
  br i1 %347, label %label_1486, label %label_1488

label_1471:                                       ; preds = %label_1445
  %348 = load ptr, ptr %expr.701, align 8
  %349 = getelementptr inbounds nuw %ASTNode, ptr %348, i32 0, i32 5
  %350 = load ptr, ptr %349, align 8
  %351 = call ptr @ptr_to_node(ptr %350)
  store ptr %351, ptr %operand_node.741, align 8
  %352 = load ptr, ptr %operand_node.741, align 8
  %353 = call ptr @generate_expression__Struct_ASTNode(ptr %352)
  store ptr %353, ptr %operand_val.742, align 8
  %354 = load ptr, ptr %expr.701, align 8
  %355 = getelementptr inbounds nuw %ASTNode, ptr %354, i32 0, i32 1
  %356 = load ptr, ptr %355, align 8
  store ptr %356, ptr %uop.743, align 8
  %357 = load ptr, ptr %uop.743, align 8
  %358 = call i32 @str_equals(ptr %357, ptr @.str.s555)
  %359 = icmp eq i32 %358, 1
  br i1 %359, label %label_1474, label %label_1476

label_1476:                                       ; preds = %label_1471
  %360 = load ptr, ptr %uop.743, align 8
  %361 = call i32 @str_equals(ptr %360, ptr @.str.s558)
  %362 = icmp eq i32 %361, 1
  br i1 %362, label %label_1477, label %label_1479

label_1474:                                       ; preds = %label_1471
  %363 = load ptr, ptr %operand_val.742, align 8
  %364 = call i32 @ir_icmp_eq(ptr @.str.s556, ptr %363, ptr @.str.s557)
  store i32 %364, ptr %not_id.744, align 4
  %365 = load i32, ptr %not_id.744, align 4
  %366 = call ptr @ir_get_temp_name(i32 %365)
  ret ptr %366

label_1479:                                       ; preds = %label_1476
  %367 = load ptr, ptr %uop.743, align 8
  %368 = call i32 @str_equals(ptr %367, ptr @.str.s559)
  %369 = icmp eq i32 %368, 1
  br i1 %369, label %label_1480, label %label_1482

label_1477:                                       ; preds = %label_1476
  %370 = load ptr, ptr %operand_node.741, align 8
  %371 = call ptr @get_expr_type__Struct_ASTNode(ptr %370)
  store ptr %371, ptr %int_type.745, align 8
  %372 = load ptr, ptr %int_type.745, align 8
  %373 = load ptr, ptr %operand_val.742, align 8
  %374 = call i32 @ir_not(ptr %372, ptr %373)
  %375 = call ptr @ir_get_temp_name(i32 %374)
  ret ptr %375

label_1482:                                       ; preds = %label_1479
  br label %label_1473

label_1480:                                       ; preds = %label_1479
  %376 = load ptr, ptr %operand_node.741, align 8
  %377 = call ptr @get_expr_type__Struct_ASTNode(ptr %376)
  store ptr %377, ptr %operand_type.746, align 8
  %378 = load ptr, ptr %operand_type.746, align 8
  %379 = call i32 @str_equals(ptr %378, ptr @.str.s560)
  %380 = icmp eq i32 %379, 1
  br i1 %380, label %label_1483, label %label_1485

label_1485:                                       ; preds = %label_1480
  %381 = load ptr, ptr %operand_type.746, align 8
  %382 = load ptr, ptr %operand_val.742, align 8
  %383 = call i32 @ir_neg(ptr %381, ptr %382)
  store i32 %383, ptr %neg_id.748, align 4
  %384 = load i32, ptr %neg_id.748, align 4
  %385 = call ptr @ir_get_temp_name(i32 %384)
  ret ptr %385

label_1483:                                       ; preds = %label_1480
  %386 = load ptr, ptr %operand_val.742, align 8
  %387 = call i32 @ir_fsub(ptr @.str.s561, ptr @.str.s562, ptr %386)
  store i32 %387, ptr %fneg_id.747, align 4
  %388 = load i32, ptr %fneg_id.747, align 4
  %389 = call ptr @ir_get_temp_name(i32 %388)
  ret ptr %389

label_1488:                                       ; preds = %label_1473
  %390 = load ptr, ptr %expr.701, align 8
  %391 = getelementptr inbounds nuw %ASTNode, ptr %390, i32 0, i32 0
  %392 = load i32, ptr %391, align 4
  %393 = icmp eq i32 %392, 24
  br i1 %393, label %label_1602, label %label_1604

label_1486:                                       ; preds = %label_1473
  %394 = load ptr, ptr %expr.701, align 8
  %395 = getelementptr inbounds nuw %ASTNode, ptr %394, i32 0, i32 1
  %396 = load ptr, ptr %395, align 8
  %397 = call i32 @str_equals(ptr %396, ptr @.str.s563)
  %398 = icmp eq i32 %397, 1
  store i1 %398, ptr %sc.104, align 1
  br i1 %398, label %label_1490, label %label_1489

label_1489:                                       ; preds = %label_1486
  %399 = load ptr, ptr %expr.701, align 8
  %400 = getelementptr inbounds nuw %ASTNode, ptr %399, i32 0, i32 1
  %401 = load ptr, ptr %400, align 8
  %402 = call i32 @str_equals(ptr %401, ptr @.str.s564)
  %403 = icmp eq i32 %402, 1
  store i1 %403, ptr %sc.104, align 1
  br label %label_1490

label_1490:                                       ; preds = %label_1489, %label_1486
  %404 = load i1, ptr %sc.104, align 1
  br i1 %404, label %label_1491, label %label_1493

label_1493:                                       ; preds = %label_1490
  %405 = load ptr, ptr %expr.701, align 8
  %406 = getelementptr inbounds nuw %ASTNode, ptr %405, i32 0, i32 5
  %407 = load ptr, ptr %406, align 8
  %408 = call ptr @ptr_to_node(ptr %407)
  %409 = call ptr @generate_expression__Struct_ASTNode(ptr %408)
  store ptr %409, ptr %left_val.749, align 8
  %410 = load ptr, ptr %expr.701, align 8
  %411 = getelementptr inbounds nuw %ASTNode, ptr %410, i32 0, i32 6
  %412 = load ptr, ptr %411, align 8
  %413 = call ptr @ptr_to_node(ptr %412)
  %414 = call ptr @generate_expression__Struct_ASTNode(ptr %413)
  store ptr %414, ptr %right_val.750, align 8
  %415 = load ptr, ptr %expr.701, align 8
  %416 = getelementptr inbounds nuw %ASTNode, ptr %415, i32 0, i32 1
  %417 = load ptr, ptr %416, align 8
  store ptr %417, ptr %op.751, align 8
  store i32 0, ptr %temp_id.752, align 4
  %418 = load ptr, ptr %expr.701, align 8
  %419 = getelementptr inbounds nuw %ASTNode, ptr %418, i32 0, i32 5
  %420 = load ptr, ptr %419, align 8
  %421 = call ptr @ptr_to_node(ptr %420)
  store ptr %421, ptr %left_node.753, align 8
  %422 = load ptr, ptr %left_node.753, align 8
  %423 = call ptr @get_expr_type__Struct_ASTNode(ptr %422)
  store ptr %423, ptr %op_type.754, align 8
  store i1 false, ptr %is_unsigned.755, align 1
  %424 = load ptr, ptr %left_node.753, align 8
  %425 = call i1 @node_has_type__Struct_ASTNode(ptr %424)
  br i1 %425, label %label_1494, label %label_1496

label_1491:                                       ; preds = %label_1490
  %426 = load ptr, ptr %expr.701, align 8
  %427 = call ptr @generate_short_circuit__Struct_ASTNode(ptr %426)
  ret ptr %427

label_1496:                                       ; preds = %label_1494, %label_1493
  %428 = load ptr, ptr %op_type.754, align 8
  %429 = call i32 @str_equals(ptr %428, ptr @.str.s565)
  %430 = icmp eq i32 %429, 1
  br i1 %430, label %label_1497, label %label_1498

label_1494:                                       ; preds = %label_1493
  %431 = load ptr, ptr %left_node.753, align 8
  %432 = call ptr @node_get_type__Struct_ASTNode(ptr %431)
  %433 = call i1 @type_int_is_unsigned__Struct_TypeInfo(ptr %432)
  store i1 %433, ptr %is_unsigned.755, align 1
  br label %label_1496

label_1498:                                       ; preds = %label_1496
  %434 = load ptr, ptr %op.751, align 8
  %435 = call i32 @str_equals(ptr %434, ptr @.str.s576)
  %436 = icmp eq i32 %435, 1
  br i1 %436, label %label_1530, label %label_1532

label_1497:                                       ; preds = %label_1496
  %437 = load ptr, ptr %op.751, align 8
  %438 = call i32 @str_equals(ptr %437, ptr @.str.s566)
  %439 = icmp eq i32 %438, 1
  br i1 %439, label %label_1500, label %label_1502

label_1502:                                       ; preds = %label_1500, %label_1497
  %440 = load ptr, ptr %op.751, align 8
  %441 = call i32 @str_equals(ptr %440, ptr @.str.s567)
  %442 = icmp eq i32 %441, 1
  br i1 %442, label %label_1503, label %label_1505

label_1500:                                       ; preds = %label_1497
  %443 = load ptr, ptr %op_type.754, align 8
  %444 = load ptr, ptr %left_val.749, align 8
  %445 = load ptr, ptr %right_val.750, align 8
  %446 = call i32 @ir_fadd(ptr %443, ptr %444, ptr %445)
  store i32 %446, ptr %temp_id.752, align 4
  br label %label_1502

label_1505:                                       ; preds = %label_1503, %label_1502
  %447 = load ptr, ptr %op.751, align 8
  %448 = call i32 @str_equals(ptr %447, ptr @.str.s568)
  %449 = icmp eq i32 %448, 1
  br i1 %449, label %label_1506, label %label_1508

label_1503:                                       ; preds = %label_1502
  %450 = load ptr, ptr %op_type.754, align 8
  %451 = load ptr, ptr %left_val.749, align 8
  %452 = load ptr, ptr %right_val.750, align 8
  %453 = call i32 @ir_fsub(ptr %450, ptr %451, ptr %452)
  store i32 %453, ptr %temp_id.752, align 4
  br label %label_1505

label_1508:                                       ; preds = %label_1506, %label_1505
  %454 = load ptr, ptr %op.751, align 8
  %455 = call i32 @str_equals(ptr %454, ptr @.str.s569)
  %456 = icmp eq i32 %455, 1
  br i1 %456, label %label_1509, label %label_1511

label_1506:                                       ; preds = %label_1505
  %457 = load ptr, ptr %op_type.754, align 8
  %458 = load ptr, ptr %left_val.749, align 8
  %459 = load ptr, ptr %right_val.750, align 8
  %460 = call i32 @ir_fmul(ptr %457, ptr %458, ptr %459)
  store i32 %460, ptr %temp_id.752, align 4
  br label %label_1508

label_1511:                                       ; preds = %label_1509, %label_1508
  %461 = load ptr, ptr %op.751, align 8
  %462 = call i32 @str_equals(ptr %461, ptr @.str.s570)
  %463 = icmp eq i32 %462, 1
  br i1 %463, label %label_1512, label %label_1514

label_1509:                                       ; preds = %label_1508
  %464 = load ptr, ptr %op_type.754, align 8
  %465 = load ptr, ptr %left_val.749, align 8
  %466 = load ptr, ptr %right_val.750, align 8
  %467 = call i32 @ir_fdiv(ptr %464, ptr %465, ptr %466)
  store i32 %467, ptr %temp_id.752, align 4
  br label %label_1511

label_1514:                                       ; preds = %label_1512, %label_1511
  %468 = load ptr, ptr %op.751, align 8
  %469 = call i32 @str_equals(ptr %468, ptr @.str.s571)
  %470 = icmp eq i32 %469, 1
  br i1 %470, label %label_1515, label %label_1517

label_1512:                                       ; preds = %label_1511
  %471 = load ptr, ptr %op_type.754, align 8
  %472 = load ptr, ptr %left_val.749, align 8
  %473 = load ptr, ptr %right_val.750, align 8
  %474 = call i32 @ir_fcmp_oeq(ptr %471, ptr %472, ptr %473)
  store i32 %474, ptr %temp_id.752, align 4
  br label %label_1514

label_1517:                                       ; preds = %label_1515, %label_1514
  %475 = load ptr, ptr %op.751, align 8
  %476 = call i32 @str_equals(ptr %475, ptr @.str.s572)
  %477 = icmp eq i32 %476, 1
  br i1 %477, label %label_1518, label %label_1520

label_1515:                                       ; preds = %label_1514
  %478 = load ptr, ptr %op_type.754, align 8
  %479 = load ptr, ptr %left_val.749, align 8
  %480 = load ptr, ptr %right_val.750, align 8
  %481 = call i32 @ir_fcmp_one(ptr %478, ptr %479, ptr %480)
  store i32 %481, ptr %temp_id.752, align 4
  br label %label_1517

label_1520:                                       ; preds = %label_1518, %label_1517
  %482 = load ptr, ptr %op.751, align 8
  %483 = call i32 @str_equals(ptr %482, ptr @.str.s573)
  %484 = icmp eq i32 %483, 1
  br i1 %484, label %label_1521, label %label_1523

label_1518:                                       ; preds = %label_1517
  %485 = load ptr, ptr %op_type.754, align 8
  %486 = load ptr, ptr %left_val.749, align 8
  %487 = load ptr, ptr %right_val.750, align 8
  %488 = call i32 @ir_fcmp_olt(ptr %485, ptr %486, ptr %487)
  store i32 %488, ptr %temp_id.752, align 4
  br label %label_1520

label_1523:                                       ; preds = %label_1521, %label_1520
  %489 = load ptr, ptr %op.751, align 8
  %490 = call i32 @str_equals(ptr %489, ptr @.str.s574)
  %491 = icmp eq i32 %490, 1
  br i1 %491, label %label_1524, label %label_1526

label_1521:                                       ; preds = %label_1520
  %492 = load ptr, ptr %op_type.754, align 8
  %493 = load ptr, ptr %left_val.749, align 8
  %494 = load ptr, ptr %right_val.750, align 8
  %495 = call i32 @ir_fcmp_ole(ptr %492, ptr %493, ptr %494)
  store i32 %495, ptr %temp_id.752, align 4
  br label %label_1523

label_1526:                                       ; preds = %label_1524, %label_1523
  %496 = load ptr, ptr %op.751, align 8
  %497 = call i32 @str_equals(ptr %496, ptr @.str.s575)
  %498 = icmp eq i32 %497, 1
  br i1 %498, label %label_1527, label %label_1529

label_1524:                                       ; preds = %label_1523
  %499 = load ptr, ptr %op_type.754, align 8
  %500 = load ptr, ptr %left_val.749, align 8
  %501 = load ptr, ptr %right_val.750, align 8
  %502 = call i32 @ir_fcmp_ogt(ptr %499, ptr %500, ptr %501)
  store i32 %502, ptr %temp_id.752, align 4
  br label %label_1526

label_1529:                                       ; preds = %label_1527, %label_1526
  br label %label_1499

label_1527:                                       ; preds = %label_1526
  %503 = load ptr, ptr %op_type.754, align 8
  %504 = load ptr, ptr %left_val.749, align 8
  %505 = load ptr, ptr %right_val.750, align 8
  %506 = call i32 @ir_fcmp_oge(ptr %503, ptr %504, ptr %505)
  store i32 %506, ptr %temp_id.752, align 4
  br label %label_1529

label_1499:                                       ; preds = %label_1547, %label_1529
  %507 = load ptr, ptr %op.751, align 8
  %508 = call i32 @str_equals(ptr %507, ptr @.str.s591)
  %509 = icmp eq i32 %508, 1
  br i1 %509, label %label_1578, label %label_1580

label_1532:                                       ; preds = %label_1530, %label_1498
  %510 = load ptr, ptr %op.751, align 8
  %511 = call i32 @str_equals(ptr %510, ptr @.str.s577)
  %512 = icmp eq i32 %511, 1
  br i1 %512, label %label_1533, label %label_1535

label_1530:                                       ; preds = %label_1498
  %513 = load ptr, ptr %op_type.754, align 8
  %514 = load ptr, ptr %left_val.749, align 8
  %515 = load ptr, ptr %right_val.750, align 8
  %516 = call i32 @ir_add(ptr %513, ptr %514, ptr %515)
  store i32 %516, ptr %temp_id.752, align 4
  br label %label_1532

label_1535:                                       ; preds = %label_1533, %label_1532
  %517 = load ptr, ptr %op.751, align 8
  %518 = call i32 @str_equals(ptr %517, ptr @.str.s578)
  %519 = icmp eq i32 %518, 1
  br i1 %519, label %label_1536, label %label_1538

label_1533:                                       ; preds = %label_1532
  %520 = load ptr, ptr %op_type.754, align 8
  %521 = load ptr, ptr %left_val.749, align 8
  %522 = load ptr, ptr %right_val.750, align 8
  %523 = call i32 @ir_sub(ptr %520, ptr %521, ptr %522)
  store i32 %523, ptr %temp_id.752, align 4
  br label %label_1535

label_1538:                                       ; preds = %label_1536, %label_1535
  %524 = load ptr, ptr %op.751, align 8
  %525 = call i32 @str_equals(ptr %524, ptr @.str.s579)
  %526 = icmp eq i32 %525, 1
  br i1 %526, label %label_1539, label %label_1541

label_1536:                                       ; preds = %label_1535
  %527 = load ptr, ptr %op_type.754, align 8
  %528 = load ptr, ptr %left_val.749, align 8
  %529 = load ptr, ptr %right_val.750, align 8
  %530 = call i32 @ir_mul(ptr %527, ptr %528, ptr %529)
  store i32 %530, ptr %temp_id.752, align 4
  br label %label_1538

label_1541:                                       ; preds = %label_1539, %label_1538
  %531 = load ptr, ptr %op.751, align 8
  %532 = call i32 @str_equals(ptr %531, ptr @.str.s580)
  %533 = icmp eq i32 %532, 1
  br i1 %533, label %label_1542, label %label_1544

label_1539:                                       ; preds = %label_1538
  %534 = load ptr, ptr %op_type.754, align 8
  %535 = load ptr, ptr %left_val.749, align 8
  %536 = load ptr, ptr %right_val.750, align 8
  %537 = call i32 @ir_icmp_eq(ptr %534, ptr %535, ptr %536)
  store i32 %537, ptr %temp_id.752, align 4
  br label %label_1541

label_1544:                                       ; preds = %label_1542, %label_1541
  %538 = load i1, ptr %is_unsigned.755, align 1
  br i1 %538, label %label_1545, label %label_1546

label_1542:                                       ; preds = %label_1541
  %539 = load ptr, ptr %op_type.754, align 8
  %540 = load ptr, ptr %left_val.749, align 8
  %541 = load ptr, ptr %right_val.750, align 8
  %542 = call i32 @ir_icmp_ne(ptr %539, ptr %540, ptr %541)
  store i32 %542, ptr %temp_id.752, align 4
  br label %label_1544

label_1546:                                       ; preds = %label_1544
  %543 = load ptr, ptr %op.751, align 8
  %544 = call i32 @str_equals(ptr %543, ptr @.str.s586)
  %545 = icmp eq i32 %544, 1
  br i1 %545, label %label_1563, label %label_1565

label_1545:                                       ; preds = %label_1544
  %546 = load ptr, ptr %op.751, align 8
  %547 = call i32 @str_equals(ptr %546, ptr @.str.s581)
  %548 = icmp eq i32 %547, 1
  br i1 %548, label %label_1548, label %label_1550

label_1550:                                       ; preds = %label_1548, %label_1545
  %549 = load ptr, ptr %op.751, align 8
  %550 = call i32 @str_equals(ptr %549, ptr @.str.s582)
  %551 = icmp eq i32 %550, 1
  br i1 %551, label %label_1551, label %label_1553

label_1548:                                       ; preds = %label_1545
  %552 = load ptr, ptr %op_type.754, align 8
  %553 = load ptr, ptr %left_val.749, align 8
  %554 = load ptr, ptr %right_val.750, align 8
  %555 = call i32 @ir_udiv(ptr %552, ptr %553, ptr %554)
  store i32 %555, ptr %temp_id.752, align 4
  br label %label_1550

label_1553:                                       ; preds = %label_1551, %label_1550
  %556 = load ptr, ptr %op.751, align 8
  %557 = call i32 @str_equals(ptr %556, ptr @.str.s583)
  %558 = icmp eq i32 %557, 1
  br i1 %558, label %label_1554, label %label_1556

label_1551:                                       ; preds = %label_1550
  %559 = load ptr, ptr %op_type.754, align 8
  %560 = load ptr, ptr %left_val.749, align 8
  %561 = load ptr, ptr %right_val.750, align 8
  %562 = call i32 @ir_icmp_ult(ptr %559, ptr %560, ptr %561)
  store i32 %562, ptr %temp_id.752, align 4
  br label %label_1553

label_1556:                                       ; preds = %label_1554, %label_1553
  %563 = load ptr, ptr %op.751, align 8
  %564 = call i32 @str_equals(ptr %563, ptr @.str.s584)
  %565 = icmp eq i32 %564, 1
  br i1 %565, label %label_1557, label %label_1559

label_1554:                                       ; preds = %label_1553
  %566 = load ptr, ptr %op_type.754, align 8
  %567 = load ptr, ptr %left_val.749, align 8
  %568 = load ptr, ptr %right_val.750, align 8
  %569 = call i32 @ir_icmp_ule(ptr %566, ptr %567, ptr %568)
  store i32 %569, ptr %temp_id.752, align 4
  br label %label_1556

label_1559:                                       ; preds = %label_1557, %label_1556
  %570 = load ptr, ptr %op.751, align 8
  %571 = call i32 @str_equals(ptr %570, ptr @.str.s585)
  %572 = icmp eq i32 %571, 1
  br i1 %572, label %label_1560, label %label_1562

label_1557:                                       ; preds = %label_1556
  %573 = load ptr, ptr %op_type.754, align 8
  %574 = load ptr, ptr %left_val.749, align 8
  %575 = load ptr, ptr %right_val.750, align 8
  %576 = call i32 @ir_icmp_ugt(ptr %573, ptr %574, ptr %575)
  store i32 %576, ptr %temp_id.752, align 4
  br label %label_1559

label_1562:                                       ; preds = %label_1560, %label_1559
  br label %label_1547

label_1560:                                       ; preds = %label_1559
  %577 = load ptr, ptr %op_type.754, align 8
  %578 = load ptr, ptr %left_val.749, align 8
  %579 = load ptr, ptr %right_val.750, align 8
  %580 = call i32 @ir_icmp_uge(ptr %577, ptr %578, ptr %579)
  store i32 %580, ptr %temp_id.752, align 4
  br label %label_1562

label_1547:                                       ; preds = %label_1577, %label_1562
  br label %label_1499

label_1565:                                       ; preds = %label_1563, %label_1546
  %581 = load ptr, ptr %op.751, align 8
  %582 = call i32 @str_equals(ptr %581, ptr @.str.s587)
  %583 = icmp eq i32 %582, 1
  br i1 %583, label %label_1566, label %label_1568

label_1563:                                       ; preds = %label_1546
  %584 = load ptr, ptr %op_type.754, align 8
  %585 = load ptr, ptr %left_val.749, align 8
  %586 = load ptr, ptr %right_val.750, align 8
  %587 = call i32 @ir_sdiv(ptr %584, ptr %585, ptr %586)
  store i32 %587, ptr %temp_id.752, align 4
  br label %label_1565

label_1568:                                       ; preds = %label_1566, %label_1565
  %588 = load ptr, ptr %op.751, align 8
  %589 = call i32 @str_equals(ptr %588, ptr @.str.s588)
  %590 = icmp eq i32 %589, 1
  br i1 %590, label %label_1569, label %label_1571

label_1566:                                       ; preds = %label_1565
  %591 = load ptr, ptr %op_type.754, align 8
  %592 = load ptr, ptr %left_val.749, align 8
  %593 = load ptr, ptr %right_val.750, align 8
  %594 = call i32 @ir_icmp_slt(ptr %591, ptr %592, ptr %593)
  store i32 %594, ptr %temp_id.752, align 4
  br label %label_1568

label_1571:                                       ; preds = %label_1569, %label_1568
  %595 = load ptr, ptr %op.751, align 8
  %596 = call i32 @str_equals(ptr %595, ptr @.str.s589)
  %597 = icmp eq i32 %596, 1
  br i1 %597, label %label_1572, label %label_1574

label_1569:                                       ; preds = %label_1568
  %598 = load ptr, ptr %op_type.754, align 8
  %599 = load ptr, ptr %left_val.749, align 8
  %600 = load ptr, ptr %right_val.750, align 8
  %601 = call i32 @ir_icmp_sle(ptr %598, ptr %599, ptr %600)
  store i32 %601, ptr %temp_id.752, align 4
  br label %label_1571

label_1574:                                       ; preds = %label_1572, %label_1571
  %602 = load ptr, ptr %op.751, align 8
  %603 = call i32 @str_equals(ptr %602, ptr @.str.s590)
  %604 = icmp eq i32 %603, 1
  br i1 %604, label %label_1575, label %label_1577

label_1572:                                       ; preds = %label_1571
  %605 = load ptr, ptr %op_type.754, align 8
  %606 = load ptr, ptr %left_val.749, align 8
  %607 = load ptr, ptr %right_val.750, align 8
  %608 = call i32 @ir_icmp_sgt(ptr %605, ptr %606, ptr %607)
  store i32 %608, ptr %temp_id.752, align 4
  br label %label_1574

label_1577:                                       ; preds = %label_1575, %label_1574
  br label %label_1547

label_1575:                                       ; preds = %label_1574
  %609 = load ptr, ptr %op_type.754, align 8
  %610 = load ptr, ptr %left_val.749, align 8
  %611 = load ptr, ptr %right_val.750, align 8
  %612 = call i32 @ir_icmp_sge(ptr %609, ptr %610, ptr %611)
  store i32 %612, ptr %temp_id.752, align 4
  br label %label_1577

label_1580:                                       ; preds = %label_1583, %label_1499
  %613 = load ptr, ptr %op.751, align 8
  %614 = call i32 @str_equals(ptr %613, ptr @.str.s592)
  %615 = icmp eq i32 %614, 1
  br i1 %615, label %label_1584, label %label_1586

label_1578:                                       ; preds = %label_1499
  %616 = load i1, ptr %is_unsigned.755, align 1
  br i1 %616, label %label_1581, label %label_1582

label_1582:                                       ; preds = %label_1578
  %617 = load ptr, ptr %op_type.754, align 8
  %618 = load ptr, ptr %left_val.749, align 8
  %619 = load ptr, ptr %right_val.750, align 8
  %620 = call i32 @ir_srem(ptr %617, ptr %618, ptr %619)
  store i32 %620, ptr %temp_id.752, align 4
  br label %label_1583

label_1581:                                       ; preds = %label_1578
  %621 = load ptr, ptr %op_type.754, align 8
  %622 = load ptr, ptr %left_val.749, align 8
  %623 = load ptr, ptr %right_val.750, align 8
  %624 = call i32 @ir_urem(ptr %621, ptr %622, ptr %623)
  store i32 %624, ptr %temp_id.752, align 4
  br label %label_1583

label_1583:                                       ; preds = %label_1582, %label_1581
  br label %label_1580

label_1586:                                       ; preds = %label_1584, %label_1580
  %625 = load ptr, ptr %op.751, align 8
  %626 = call i32 @str_equals(ptr %625, ptr @.str.s593)
  %627 = icmp eq i32 %626, 1
  br i1 %627, label %label_1587, label %label_1589

label_1584:                                       ; preds = %label_1580
  %628 = load ptr, ptr %op_type.754, align 8
  %629 = load ptr, ptr %left_val.749, align 8
  %630 = load ptr, ptr %right_val.750, align 8
  %631 = call i32 @ir_and(ptr %628, ptr %629, ptr %630)
  store i32 %631, ptr %temp_id.752, align 4
  br label %label_1586

label_1589:                                       ; preds = %label_1587, %label_1586
  %632 = load ptr, ptr %op.751, align 8
  %633 = call i32 @str_equals(ptr %632, ptr @.str.s594)
  %634 = icmp eq i32 %633, 1
  br i1 %634, label %label_1590, label %label_1592

label_1587:                                       ; preds = %label_1586
  %635 = load ptr, ptr %op_type.754, align 8
  %636 = load ptr, ptr %left_val.749, align 8
  %637 = load ptr, ptr %right_val.750, align 8
  %638 = call i32 @ir_or(ptr %635, ptr %636, ptr %637)
  store i32 %638, ptr %temp_id.752, align 4
  br label %label_1589

label_1592:                                       ; preds = %label_1590, %label_1589
  %639 = load ptr, ptr %op.751, align 8
  %640 = call i32 @str_equals(ptr %639, ptr @.str.s595)
  %641 = icmp eq i32 %640, 1
  br i1 %641, label %label_1593, label %label_1595

label_1590:                                       ; preds = %label_1589
  %642 = load ptr, ptr %op_type.754, align 8
  %643 = load ptr, ptr %left_val.749, align 8
  %644 = load ptr, ptr %right_val.750, align 8
  %645 = call i32 @ir_xor(ptr %642, ptr %643, ptr %644)
  store i32 %645, ptr %temp_id.752, align 4
  br label %label_1592

label_1595:                                       ; preds = %label_1593, %label_1592
  %646 = load ptr, ptr %op.751, align 8
  %647 = call i32 @str_equals(ptr %646, ptr @.str.s596)
  %648 = icmp eq i32 %647, 1
  br i1 %648, label %label_1596, label %label_1598

label_1593:                                       ; preds = %label_1592
  %649 = load ptr, ptr %op_type.754, align 8
  %650 = load ptr, ptr %left_val.749, align 8
  %651 = load ptr, ptr %right_val.750, align 8
  %652 = call i32 @ir_shl(ptr %649, ptr %650, ptr %651)
  store i32 %652, ptr %temp_id.752, align 4
  br label %label_1595

label_1598:                                       ; preds = %label_1601, %label_1595
  %653 = load i32, ptr %temp_id.752, align 4
  %654 = call ptr @ir_get_temp_name(i32 %653)
  ret ptr %654

label_1596:                                       ; preds = %label_1595
  %655 = load i1, ptr %is_unsigned.755, align 1
  br i1 %655, label %label_1599, label %label_1600

label_1600:                                       ; preds = %label_1596
  %656 = load ptr, ptr %op_type.754, align 8
  %657 = load ptr, ptr %left_val.749, align 8
  %658 = load ptr, ptr %right_val.750, align 8
  %659 = call i32 @ir_ashr(ptr %656, ptr %657, ptr %658)
  store i32 %659, ptr %temp_id.752, align 4
  br label %label_1601

label_1599:                                       ; preds = %label_1596
  %660 = load ptr, ptr %op_type.754, align 8
  %661 = load ptr, ptr %left_val.749, align 8
  %662 = load ptr, ptr %right_val.750, align 8
  %663 = call i32 @ir_lshr(ptr %660, ptr %661, ptr %662)
  store i32 %663, ptr %temp_id.752, align 4
  br label %label_1601

label_1601:                                       ; preds = %label_1600, %label_1599
  br label %label_1598

label_1604:                                       ; preds = %label_1488
  ret ptr @.str.s639

label_1602:                                       ; preds = %label_1488
  %664 = load ptr, ptr %expr.701, align 8
  %665 = getelementptr inbounds nuw %ASTNode, ptr %664, i32 0, i32 5
  %666 = load ptr, ptr %665, align 8
  %667 = call ptr @ptr_to_node(ptr %666)
  store ptr %667, ptr %callee.756, align 8
  %668 = load ptr, ptr %callee.756, align 8
  %669 = getelementptr inbounds nuw %ASTNode, ptr %668, i32 0, i32 1
  %670 = load ptr, ptr %669, align 8
  store ptr %670, ptr %func_name.757, align 8
  %671 = load ptr, ptr %func_name.757, align 8
  %672 = call i32 @str_equals(ptr %671, ptr @.str.s597)
  %673 = icmp eq i32 %672, 1
  br i1 %673, label %label_1605, label %label_1607

label_1607:                                       ; preds = %label_1602
  store i32 0, ptr %is_print_bool.760, align 4
  %674 = load ptr, ptr %func_name.757, align 8
  %675 = call i32 @str_equals(ptr %674, ptr @.str.s603)
  %676 = icmp eq i32 %675, 1
  br i1 %676, label %label_1611, label %label_1613

label_1605:                                       ; preds = %label_1602
  %677 = load ptr, ptr %expr.701, align 8
  %678 = getelementptr inbounds nuw %ASTNode, ptr %677, i32 0, i32 6
  %679 = load ptr, ptr %678, align 8
  store ptr %679, ptr %drop_arg.758, align 8
  %680 = load ptr, ptr %drop_arg.758, align 8
  %681 = call i32 @str_equals(ptr %680, ptr @.str.s598)
  %682 = icmp eq i32 %681, 0
  br i1 %682, label %label_1608, label %label_1610

label_1610:                                       ; preds = %label_1608, %label_1605
  ret ptr @.str.s602

label_1608:                                       ; preds = %label_1605
  %683 = load ptr, ptr %drop_arg.758, align 8
  %684 = call ptr @ptr_to_node(ptr %683)
  %685 = call ptr @generate_expression__Struct_ASTNode(ptr %684)
  store ptr %685, ptr %drop_val.759, align 8
  call void @ir_call_begin()
  %686 = load ptr, ptr %drop_val.759, align 8
  call void @ir_call_arg(ptr @.str.s599, ptr %686)
  %687 = call i32 @ir_call_end(ptr @.str.s600, ptr @.str.s601)
  br label %label_1610

label_1613:                                       ; preds = %label_1611, %label_1607
  %688 = load ptr, ptr %func_name.757, align 8
  %689 = call i32 @str_equals(ptr %688, ptr @.str.s604)
  %690 = icmp eq i32 %689, 1
  br i1 %690, label %label_1614, label %label_1616

label_1611:                                       ; preds = %label_1607
  store i32 1, ptr %is_print_bool.760, align 4
  br label %label_1613

label_1616:                                       ; preds = %label_1614, %label_1613
  %691 = load i32, ptr %is_print_bool.760, align 4
  %692 = icmp sgt i32 %691, 0
  br i1 %692, label %label_1617, label %label_1619

label_1614:                                       ; preds = %label_1613
  store i32 2, ptr %is_print_bool.760, align 4
  br label %label_1616

label_1619:                                       ; preds = %label_1616
  store i32 0, ptr %is_print.765, align 4
  %693 = load ptr, ptr %func_name.757, align 8
  %694 = call i32 @str_equals(ptr %693, ptr @.str.s614)
  %695 = icmp eq i32 %694, 1
  br i1 %695, label %label_1626, label %label_1628

label_1617:                                       ; preds = %label_1616
  %696 = load ptr, ptr %expr.701, align 8
  %697 = getelementptr inbounds nuw %ASTNode, ptr %696, i32 0, i32 6
  %698 = load ptr, ptr %697, align 8
  store ptr %698, ptr %bool_arg_ptr.761, align 8
  %699 = load ptr, ptr %bool_arg_ptr.761, align 8
  %700 = call i32 @str_equals(ptr %699, ptr @.str.s605)
  %701 = icmp eq i32 %700, 0
  br i1 %701, label %label_1620, label %label_1622

label_1622:                                       ; preds = %label_1625, %label_1617
  ret ptr @.str.s613

label_1620:                                       ; preds = %label_1617
  %702 = load ptr, ptr %bool_arg_ptr.761, align 8
  %703 = call ptr @ptr_to_node(ptr %702)
  store ptr %703, ptr %bool_arg.762, align 8
  %704 = load ptr, ptr %bool_arg.762, align 8
  %705 = call ptr @generate_expression__Struct_ASTNode(ptr %704)
  store ptr %705, ptr %bool_val.763, align 8
  %706 = load ptr, ptr %bool_val.763, align 8
  %707 = call i32 @ir_zext(ptr @.str.s606, ptr %706, ptr @.str.s607)
  store i32 %707, ptr %widened.764, align 4
  call void @ir_call_begin()
  %708 = load i32, ptr %widened.764, align 4
  %709 = call ptr @ir_get_temp_name(i32 %708)
  call void @ir_call_arg(ptr @.str.s608, ptr %709)
  %710 = load i32, ptr %is_print_bool.760, align 4
  %711 = icmp eq i32 %710, 1
  br i1 %711, label %label_1623, label %label_1624

label_1624:                                       ; preds = %label_1620
  %712 = call i32 @ir_call_end(ptr @.str.s611, ptr @.str.s612)
  br label %label_1625

label_1623:                                       ; preds = %label_1620
  %713 = call i32 @ir_call_end(ptr @.str.s609, ptr @.str.s610)
  br label %label_1625

label_1625:                                       ; preds = %label_1624, %label_1623
  br label %label_1622

label_1628:                                       ; preds = %label_1626, %label_1619
  %714 = load ptr, ptr %func_name.757, align 8
  %715 = call i32 @str_equals(ptr %714, ptr @.str.s615)
  %716 = icmp eq i32 %715, 1
  br i1 %716, label %label_1629, label %label_1631

label_1626:                                       ; preds = %label_1619
  store i32 1, ptr %is_print.765, align 4
  br label %label_1628

label_1631:                                       ; preds = %label_1629, %label_1628
  %717 = load i32, ptr %is_print.765, align 4
  %718 = icmp sgt i32 %717, 0
  br i1 %718, label %label_1632, label %label_1634

label_1629:                                       ; preds = %label_1628
  store i32 2, ptr %is_print.765, align 4
  br label %label_1631

label_1634:                                       ; preds = %label_1631
  call void @ir_call_begin()
  %719 = load ptr, ptr %expr.701, align 8
  %720 = getelementptr inbounds nuw %ASTNode, ptr %719, i32 0, i32 6
  %721 = load ptr, ptr %720, align 8
  store ptr %721, ptr %arg_ptr.770, align 8
  br label %label_1653

label_1632:                                       ; preds = %label_1631
  %722 = load ptr, ptr %expr.701, align 8
  %723 = getelementptr inbounds nuw %ASTNode, ptr %722, i32 0, i32 6
  %724 = load ptr, ptr %723, align 8
  store ptr %724, ptr %arg_ptr.766, align 8
  %725 = load ptr, ptr %arg_ptr.766, align 8
  %726 = call i32 @str_equals(ptr %725, ptr @.str.s616)
  %727 = icmp eq i32 %726, 0
  br i1 %727, label %label_1635, label %label_1637

label_1637:                                       ; preds = %label_1640, %label_1632
  ret ptr @.str.s633

label_1635:                                       ; preds = %label_1632
  %728 = load ptr, ptr %arg_ptr.766, align 8
  %729 = call ptr @ptr_to_node(ptr %728)
  store ptr %729, ptr %arg_node.767, align 8
  %730 = load ptr, ptr %arg_node.767, align 8
  %731 = call ptr @generate_expression__Struct_ASTNode(ptr %730)
  store ptr %731, ptr %arg_val.768, align 8
  %732 = load ptr, ptr %arg_node.767, align 8
  %733 = call ptr @get_expr_type__Struct_ASTNode(ptr %732)
  store ptr %733, ptr %arg_type.769, align 8
  call void @ir_call_begin()
  %734 = load ptr, ptr %arg_type.769, align 8
  %735 = call i32 @str_equals(ptr %734, ptr @.str.s617)
  %736 = icmp eq i32 %735, 1
  br i1 %736, label %label_1638, label %label_1639

label_1639:                                       ; preds = %label_1635
  %737 = load ptr, ptr %arg_type.769, align 8
  %738 = call i32 @str_equals(ptr %737, ptr @.str.s623)
  %739 = icmp eq i32 %738, 1
  br i1 %739, label %label_1644, label %label_1645

label_1638:                                       ; preds = %label_1635
  %740 = load ptr, ptr %arg_val.768, align 8
  call void @ir_call_arg(ptr @.str.s618, ptr %740)
  %741 = load i32, ptr %is_print.765, align 4
  %742 = icmp eq i32 %741, 1
  br i1 %742, label %label_1641, label %label_1642

label_1642:                                       ; preds = %label_1638
  %743 = call i32 @ir_call_end(ptr @.str.s621, ptr @.str.s622)
  br label %label_1643

label_1641:                                       ; preds = %label_1638
  %744 = call i32 @ir_call_end(ptr @.str.s619, ptr @.str.s620)
  br label %label_1643

label_1643:                                       ; preds = %label_1642, %label_1641
  br label %label_1640

label_1640:                                       ; preds = %label_1646, %label_1643
  br label %label_1637

label_1645:                                       ; preds = %label_1639
  %745 = load ptr, ptr %arg_type.769, align 8
  %746 = call ptr @storage_type__String(ptr %745)
  %747 = load ptr, ptr %arg_val.768, align 8
  call void @ir_call_arg(ptr %746, ptr %747)
  %748 = load i32, ptr %is_print.765, align 4
  %749 = icmp eq i32 %748, 1
  br i1 %749, label %label_1650, label %label_1651

label_1644:                                       ; preds = %label_1639
  %750 = load ptr, ptr %arg_val.768, align 8
  call void @ir_call_arg(ptr @.str.s624, ptr %750)
  %751 = load i32, ptr %is_print.765, align 4
  %752 = icmp eq i32 %751, 1
  br i1 %752, label %label_1647, label %label_1648

label_1648:                                       ; preds = %label_1644
  %753 = call i32 @ir_call_end(ptr @.str.s627, ptr @.str.s628)
  br label %label_1649

label_1647:                                       ; preds = %label_1644
  %754 = call i32 @ir_call_end(ptr @.str.s625, ptr @.str.s626)
  br label %label_1649

label_1649:                                       ; preds = %label_1648, %label_1647
  br label %label_1646

label_1646:                                       ; preds = %label_1652, %label_1649
  br label %label_1640

label_1651:                                       ; preds = %label_1645
  %755 = call i32 @ir_call_end(ptr @.str.s631, ptr @.str.s632)
  br label %label_1652

label_1650:                                       ; preds = %label_1645
  %756 = call i32 @ir_call_end(ptr @.str.s629, ptr @.str.s630)
  br label %label_1652

label_1652:                                       ; preds = %label_1651, %label_1650
  br label %label_1646

label_1653:                                       ; preds = %label_1654, %label_1634
  %757 = load ptr, ptr %arg_ptr.770, align 8
  %758 = call i32 @str_equals(ptr %757, ptr @.str.s634)
  %759 = icmp eq i32 %758, 0
  br i1 %759, label %label_1654, label %label_1655

label_1655:                                       ; preds = %label_1653
  %760 = load ptr, ptr %func_name.757, align 8
  store ptr %760, ptr %call_name.773, align 8
  %761 = load ptr, ptr %expr.701, align 8
  %762 = getelementptr inbounds nuw %ASTNode, ptr %761, i32 0, i32 2
  %763 = load ptr, ptr %762, align 8
  %764 = call i32 @str_equals(ptr %763, ptr @.str.s635)
  %765 = icmp eq i32 %764, 0
  br i1 %765, label %label_1656, label %label_1658

label_1654:                                       ; preds = %label_1653
  %766 = load ptr, ptr %arg_ptr.770, align 8
  %767 = call ptr @ptr_to_node(ptr %766)
  store ptr %767, ptr %arg_node.771, align 8
  %768 = load ptr, ptr %arg_node.771, align 8
  %769 = call ptr @generate_expression__Struct_ASTNode(ptr %768)
  store ptr %769, ptr %arg_val.772, align 8
  %770 = load ptr, ptr %arg_node.771, align 8
  %771 = call ptr @get_expr_type__Struct_ASTNode(ptr %770)
  %772 = call ptr @storage_type__String(ptr %771)
  %773 = load ptr, ptr %arg_val.772, align 8
  call void @ir_call_arg(ptr %772, ptr %773)
  %774 = load ptr, ptr %arg_node.771, align 8
  %775 = getelementptr inbounds nuw %ASTNode, ptr %774, i32 0, i32 8
  %776 = load ptr, ptr %775, align 8
  store ptr %776, ptr %arg_ptr.770, align 8
  br label %label_1653

label_1658:                                       ; preds = %label_1656, %label_1655
  %777 = load ptr, ptr %expr.701, align 8
  %778 = call ptr @get_expr_type__Struct_ASTNode(ptr %777)
  %779 = call ptr @storage_type__String(ptr %778)
  store ptr %779, ptr %ret_type.774, align 8
  %780 = load ptr, ptr %ret_type.774, align 8
  %781 = call i32 @str_equals(ptr %780, ptr @.str.s636)
  %782 = icmp eq i32 %781, 1
  br i1 %782, label %label_1659, label %label_1661

label_1656:                                       ; preds = %label_1655
  %783 = load ptr, ptr %expr.701, align 8
  %784 = getelementptr inbounds nuw %ASTNode, ptr %783, i32 0, i32 2
  %785 = load ptr, ptr %784, align 8
  store ptr %785, ptr %call_name.773, align 8
  br label %label_1658

label_1661:                                       ; preds = %label_1658
  %786 = load ptr, ptr %ret_type.774, align 8
  %787 = load ptr, ptr %call_name.773, align 8
  %788 = call i32 @ir_call_end(ptr %786, ptr %787)
  store i32 %788, ptr %temp_id.775, align 4
  %789 = load i32, ptr %temp_id.775, align 4
  %790 = call ptr @ir_get_temp_name(i32 %789)
  ret ptr %790

label_1659:                                       ; preds = %label_1658
  %791 = load ptr, ptr %call_name.773, align 8
  %792 = call i32 @ir_call_end(ptr @.str.s637, ptr %791)
  ret ptr @.str.s638
}

define void @generate_statement__Struct_ASTNode(ptr %0) {
entry:
  %stmt.776 = alloca ptr, align 8
  store ptr %0, ptr %stmt.776, align 8
  %1 = load ptr, ptr %stmt.776, align 8
  %2 = getelementptr inbounds nuw %ASTNode, ptr %1, i32 0, i32 0
  %3 = load i32, ptr %2, align 4
  %4 = icmp eq i32 %3, 3
  %var_name.777 = alloca ptr, align 8
  %var_type.778 = alloca ptr, align 8
  %type_node.779 = alloca ptr, align 8
  %init_val.780 = alloca ptr, align 8
  %has_init.781 = alloca i1, align 1
  %slot.782 = alloca ptr, align 8
  %store_type.783 = alloca ptr, align 8
  %target_node.784 = alloca ptr, align 8
  %var_name.785 = alloca ptr, align 8
  %var_type.786 = alloca ptr, align 8
  %store_type.787 = alloca ptr, align 8
  %val.788 = alloca ptr, align 8
  %object_node.789 = alloca ptr, align 8
  %object_val.790 = alloca ptr, align 8
  %object_type.791 = alloca ptr, align 8
  %struct_name.792 = alloca ptr, align 8
  %field_index.793 = alloca i32, align 4
  %field_type.794 = alloca ptr, align 8
  %val.795 = alloca ptr, align 8
  %slot.796 = alloca i32, align 4
  %ret_val.797 = alloca ptr, align 8
  %cond_val.798 = alloca ptr, align 8
  %then_label.799 = alloca i32, align 4
  %else_label.800 = alloca i32, align 4
  %end_label.801 = alloca i32, align 4
  %else_node.802 = alloca ptr, align 8
  %cond_label.803 = alloca i32, align 4
  %body_label.804 = alloca i32, align 4
  %end_label.805 = alloca i32, align 4
  %cond_val.806 = alloca ptr, align 8
  %body_label.807 = alloca i32, align 4
  %end_label.808 = alloca i32, align 4
  %loop_var.809 = alloca ptr, align 8
  %start_val.810 = alloca ptr, align 8
  %cond_label.811 = alloca i32, align 4
  %body_label.812 = alloca i32, align 4
  %incr_label.813 = alloca i32, align 4
  %end_label.814 = alloca i32, align 4
  %iv.815 = alloca i32, align 4
  %end_val.816 = alloca ptr, align 8
  %cmp.817 = alloca i32, align 4
  %iv2.818 = alloca i32, align 4
  %next.819 = alloca i32, align 4
  %target.820 = alloca i32, align 4
  %target.821 = alloca i32, align 4
  %scrut_val.822 = alloca ptr, align 8
  %scrut_type.823 = alloca ptr, align 8
  %end_label.824 = alloca i32, align 4
  %needs_final_br.825 = alloca i1, align 1
  %arm_ptr.826 = alloca ptr, align 8
  %arm.827 = alloca ptr, align 8
  %pat_val.828 = alloca ptr, align 8
  %cmp.829 = alloca i32, align 4
  %arm_label.830 = alloca i32, align 4
  %next_label.831 = alloca i32, align 4
  br i1 %4, label %label_1662, label %label_1664

label_1664:                                       ; preds = %label_1676, %entry
  %5 = load ptr, ptr %stmt.776, align 8
  %6 = getelementptr inbounds nuw %ASTNode, ptr %5, i32 0, i32 0
  %7 = load i32, ptr %6, align 4
  %8 = icmp eq i32 %7, 16
  br i1 %8, label %label_1677, label %label_1679

label_1662:                                       ; preds = %entry
  %9 = load ptr, ptr %stmt.776, align 8
  %10 = getelementptr inbounds nuw %ASTNode, ptr %9, i32 0, i32 1
  %11 = load ptr, ptr %10, align 8
  store ptr %11, ptr %var_name.777, align 8
  store ptr @.str.s640, ptr %var_type.778, align 8
  %12 = load ptr, ptr %stmt.776, align 8
  %13 = getelementptr inbounds nuw %ASTNode, ptr %12, i32 0, i32 5
  %14 = load ptr, ptr %13, align 8
  %15 = call i32 @str_equals(ptr %14, ptr @.str.s641)
  %16 = icmp eq i32 %15, 0
  br i1 %16, label %label_1665, label %label_1666

label_1666:                                       ; preds = %label_1662
  %17 = load ptr, ptr %stmt.776, align 8
  %18 = getelementptr inbounds nuw %ASTNode, ptr %17, i32 0, i32 6
  %19 = load ptr, ptr %18, align 8
  %20 = call i32 @str_equals(ptr %19, ptr @.str.s642)
  %21 = icmp eq i32 %20, 0
  br i1 %21, label %label_1668, label %label_1670

label_1665:                                       ; preds = %label_1662
  %22 = load ptr, ptr %stmt.776, align 8
  %23 = getelementptr inbounds nuw %ASTNode, ptr %22, i32 0, i32 5
  %24 = load ptr, ptr %23, align 8
  %25 = call ptr @ptr_to_node(ptr %24)
  store ptr %25, ptr %type_node.779, align 8
  %26 = load ptr, ptr %type_node.779, align 8
  %27 = call ptr @map_type_node__Struct_ASTNode(ptr %26)
  store ptr %27, ptr %var_type.778, align 8
  br label %label_1667

label_1667:                                       ; preds = %label_1670, %label_1665
  store ptr @.str.s643, ptr %init_val.780, align 8
  %28 = load ptr, ptr %stmt.776, align 8
  %29 = getelementptr inbounds nuw %ASTNode, ptr %28, i32 0, i32 6
  %30 = load ptr, ptr %29, align 8
  %31 = call i32 @str_equals(ptr %30, ptr @.str.s644)
  %32 = icmp eq i32 %31, 0
  store i1 %32, ptr %has_init.781, align 1
  %33 = load i1, ptr %has_init.781, align 1
  br i1 %33, label %label_1671, label %label_1673

label_1670:                                       ; preds = %label_1668, %label_1666
  br label %label_1667

label_1668:                                       ; preds = %label_1666
  %34 = load ptr, ptr %stmt.776, align 8
  %35 = getelementptr inbounds nuw %ASTNode, ptr %34, i32 0, i32 6
  %36 = load ptr, ptr %35, align 8
  %37 = call ptr @ptr_to_node(ptr %36)
  %38 = call ptr @get_expr_type__Struct_ASTNode(ptr %37)
  store ptr %38, ptr %var_type.778, align 8
  br label %label_1670

label_1673:                                       ; preds = %label_1671, %label_1667
  %39 = load ptr, ptr %var_name.777, align 8
  %40 = load ptr, ptr %var_type.778, align 8
  call void @ir_set_var_type(ptr %39, ptr %40)
  %41 = load ptr, ptr %var_name.777, align 8
  %42 = call ptr @ir_get_var_slot(ptr %41)
  store ptr %42, ptr %slot.782, align 8
  %43 = load ptr, ptr %var_type.778, align 8
  %44 = call ptr @storage_type__String(ptr %43)
  store ptr %44, ptr %store_type.783, align 8
  %45 = load ptr, ptr %store_type.783, align 8
  %46 = load ptr, ptr %slot.782, align 8
  %47 = call i32 @ir_alloca(ptr %45, ptr %46)
  %48 = load i1, ptr %has_init.781, align 1
  br i1 %48, label %label_1674, label %label_1676

label_1671:                                       ; preds = %label_1667
  %49 = load ptr, ptr %stmt.776, align 8
  %50 = getelementptr inbounds nuw %ASTNode, ptr %49, i32 0, i32 6
  %51 = load ptr, ptr %50, align 8
  %52 = call ptr @ptr_to_node(ptr %51)
  %53 = call ptr @generate_expression__Struct_ASTNode(ptr %52)
  store ptr %53, ptr %init_val.780, align 8
  br label %label_1673

label_1676:                                       ; preds = %label_1674, %label_1673
  br label %label_1664

label_1674:                                       ; preds = %label_1673
  %54 = load ptr, ptr %store_type.783, align 8
  %55 = load ptr, ptr %init_val.780, align 8
  %56 = load ptr, ptr %slot.782, align 8
  call void @ir_store(ptr %54, ptr %55, ptr %56)
  br label %label_1676

label_1679:                                       ; preds = %label_1688, %label_1664
  %57 = load ptr, ptr %stmt.776, align 8
  %58 = getelementptr inbounds nuw %ASTNode, ptr %57, i32 0, i32 0
  %59 = load i32, ptr %58, align 4
  %60 = icmp eq i32 %59, 15
  br i1 %60, label %label_1689, label %label_1691

label_1677:                                       ; preds = %label_1664
  %61 = load ptr, ptr %stmt.776, align 8
  %62 = getelementptr inbounds nuw %ASTNode, ptr %61, i32 0, i32 5
  %63 = load ptr, ptr %62, align 8
  %64 = call ptr @ptr_to_node(ptr %63)
  store ptr %64, ptr %target_node.784, align 8
  %65 = load ptr, ptr %target_node.784, align 8
  %66 = getelementptr inbounds nuw %ASTNode, ptr %65, i32 0, i32 0
  %67 = load i32, ptr %66, align 4
  %68 = icmp eq i32 %67, 23
  br i1 %68, label %label_1680, label %label_1682

label_1682:                                       ; preds = %label_1685, %label_1677
  %69 = load ptr, ptr %target_node.784, align 8
  %70 = getelementptr inbounds nuw %ASTNode, ptr %69, i32 0, i32 0
  %71 = load i32, ptr %70, align 4
  %72 = icmp eq i32 %71, 25
  br i1 %72, label %label_1686, label %label_1688

label_1680:                                       ; preds = %label_1677
  %73 = load ptr, ptr %target_node.784, align 8
  %74 = getelementptr inbounds nuw %ASTNode, ptr %73, i32 0, i32 1
  %75 = load ptr, ptr %74, align 8
  store ptr %75, ptr %var_name.785, align 8
  %76 = load ptr, ptr %var_name.785, align 8
  %77 = call ptr @ir_get_var_type(ptr %76)
  store ptr %77, ptr %var_type.786, align 8
  %78 = load ptr, ptr %var_type.786, align 8
  %79 = call ptr @storage_type__String(ptr %78)
  store ptr %79, ptr %store_type.787, align 8
  %80 = load ptr, ptr %stmt.776, align 8
  %81 = getelementptr inbounds nuw %ASTNode, ptr %80, i32 0, i32 6
  %82 = load ptr, ptr %81, align 8
  %83 = call ptr @ptr_to_node(ptr %82)
  %84 = call ptr @generate_expression__Struct_ASTNode(ptr %83)
  store ptr %84, ptr %val.788, align 8
  %85 = load ptr, ptr %var_name.785, align 8
  %86 = call i32 @ir_var_is_global(ptr %85)
  %87 = icmp eq i32 %86, 1
  br i1 %87, label %label_1683, label %label_1684

label_1684:                                       ; preds = %label_1680
  %88 = load ptr, ptr %store_type.787, align 8
  %89 = load ptr, ptr %val.788, align 8
  %90 = load ptr, ptr %var_name.785, align 8
  %91 = call ptr @ir_get_var_slot(ptr %90)
  call void @ir_store(ptr %88, ptr %89, ptr %91)
  br label %label_1685

label_1683:                                       ; preds = %label_1680
  %92 = load ptr, ptr %store_type.787, align 8
  %93 = load ptr, ptr %val.788, align 8
  %94 = load ptr, ptr %var_name.785, align 8
  call void @ir_store_global(ptr %92, ptr %93, ptr %94)
  br label %label_1685

label_1685:                                       ; preds = %label_1684, %label_1683
  br label %label_1682

label_1688:                                       ; preds = %label_1686, %label_1682
  br label %label_1679

label_1686:                                       ; preds = %label_1682
  %95 = load ptr, ptr %target_node.784, align 8
  %96 = getelementptr inbounds nuw %ASTNode, ptr %95, i32 0, i32 5
  %97 = load ptr, ptr %96, align 8
  %98 = call ptr @ptr_to_node(ptr %97)
  store ptr %98, ptr %object_node.789, align 8
  %99 = load ptr, ptr %object_node.789, align 8
  %100 = call ptr @generate_expression__Struct_ASTNode(ptr %99)
  store ptr %100, ptr %object_val.790, align 8
  %101 = load ptr, ptr %object_node.789, align 8
  %102 = call ptr @get_expr_type__Struct_ASTNode(ptr %101)
  store ptr %102, ptr %object_type.791, align 8
  %103 = load ptr, ptr %object_type.791, align 8
  %104 = call ptr @struct_type_name__String(ptr %103)
  store ptr %104, ptr %struct_name.792, align 8
  %105 = load ptr, ptr %struct_name.792, align 8
  %106 = load ptr, ptr %target_node.784, align 8
  %107 = getelementptr inbounds nuw %ASTNode, ptr %106, i32 0, i32 1
  %108 = load ptr, ptr %107, align 8
  %109 = call i32 @ir_get_struct_field_index(ptr %105, ptr %108)
  store i32 %109, ptr %field_index.793, align 4
  %110 = load ptr, ptr %struct_name.792, align 8
  %111 = load ptr, ptr %target_node.784, align 8
  %112 = getelementptr inbounds nuw %ASTNode, ptr %111, i32 0, i32 1
  %113 = load ptr, ptr %112, align 8
  %114 = call ptr @ir_get_struct_field_type(ptr %110, ptr %113)
  %115 = call ptr @storage_type__String(ptr %114)
  store ptr %115, ptr %field_type.794, align 8
  %116 = load ptr, ptr %stmt.776, align 8
  %117 = getelementptr inbounds nuw %ASTNode, ptr %116, i32 0, i32 6
  %118 = load ptr, ptr %117, align 8
  %119 = call ptr @ptr_to_node(ptr %118)
  %120 = call ptr @generate_expression__Struct_ASTNode(ptr %119)
  store ptr %120, ptr %val.795, align 8
  %121 = load ptr, ptr %struct_name.792, align 8
  %122 = load ptr, ptr %object_val.790, align 8
  %123 = load i32, ptr %field_index.793, align 4
  %124 = call i32 @ir_struct_field_ptr(ptr %121, ptr %122, i32 %123)
  store i32 %124, ptr %slot.796, align 4
  %125 = load ptr, ptr %field_type.794, align 8
  %126 = load ptr, ptr %val.795, align 8
  %127 = load i32, ptr %slot.796, align 4
  %128 = call ptr @ir_get_temp_name(i32 %127)
  call void @ir_store_ptr(ptr %125, ptr %126, ptr %128)
  br label %label_1688

label_1691:                                       ; preds = %label_1694, %label_1679
  %129 = load ptr, ptr %stmt.776, align 8
  %130 = getelementptr inbounds nuw %ASTNode, ptr %129, i32 0, i32 0
  %131 = load i32, ptr %130, align 4
  %132 = icmp eq i32 %131, 17
  br i1 %132, label %label_1695, label %label_1697

label_1689:                                       ; preds = %label_1679
  %133 = load ptr, ptr %stmt.776, align 8
  %134 = getelementptr inbounds nuw %ASTNode, ptr %133, i32 0, i32 5
  %135 = load ptr, ptr %134, align 8
  %136 = call i32 @str_equals(ptr %135, ptr @.str.s645)
  %137 = icmp eq i32 %136, 0
  br i1 %137, label %label_1692, label %label_1693

label_1693:                                       ; preds = %label_1689
  call void @ir_ret_void()
  br label %label_1694

label_1692:                                       ; preds = %label_1689
  %138 = load ptr, ptr %stmt.776, align 8
  %139 = getelementptr inbounds nuw %ASTNode, ptr %138, i32 0, i32 5
  %140 = load ptr, ptr %139, align 8
  %141 = call ptr @ptr_to_node(ptr %140)
  %142 = call ptr @generate_expression__Struct_ASTNode(ptr %141)
  store ptr %142, ptr %ret_val.797, align 8
  %143 = load ptr, ptr %stmt.776, align 8
  %144 = getelementptr inbounds nuw %ASTNode, ptr %143, i32 0, i32 5
  %145 = load ptr, ptr %144, align 8
  %146 = call ptr @ptr_to_node(ptr %145)
  %147 = call ptr @get_expr_type__Struct_ASTNode(ptr %146)
  %148 = call ptr @storage_type__String(ptr %147)
  %149 = load ptr, ptr %ret_val.797, align 8
  call void @ir_ret(ptr %148, ptr %149)
  br label %label_1694

label_1694:                                       ; preds = %label_1693, %label_1692
  call void @ir_set_returned()
  br label %label_1691

label_1697:                                       ; preds = %label_1700, %label_1691
  %150 = load ptr, ptr %stmt.776, align 8
  %151 = getelementptr inbounds nuw %ASTNode, ptr %150, i32 0, i32 0
  %152 = load i32, ptr %151, align 4
  %153 = icmp eq i32 %152, 10
  br i1 %153, label %label_1701, label %label_1703

label_1695:                                       ; preds = %label_1691
  %154 = load ptr, ptr %stmt.776, align 8
  %155 = getelementptr inbounds nuw %ASTNode, ptr %154, i32 0, i32 5
  %156 = load ptr, ptr %155, align 8
  %157 = call i32 @str_equals(ptr %156, ptr @.str.s646)
  %158 = icmp eq i32 %157, 0
  br i1 %158, label %label_1698, label %label_1700

label_1700:                                       ; preds = %label_1698, %label_1695
  br label %label_1697

label_1698:                                       ; preds = %label_1695
  %159 = load ptr, ptr %stmt.776, align 8
  %160 = getelementptr inbounds nuw %ASTNode, ptr %159, i32 0, i32 5
  %161 = load ptr, ptr %160, align 8
  %162 = call ptr @ptr_to_node(ptr %161)
  %163 = call ptr @generate_expression__Struct_ASTNode(ptr %162)
  br label %label_1700

label_1703:                                       ; preds = %label_1712, %label_1697
  %164 = load ptr, ptr %stmt.776, align 8
  %165 = getelementptr inbounds nuw %ASTNode, ptr %164, i32 0, i32 0
  %166 = load i32, ptr %165, align 4
  %167 = icmp eq i32 %166, 13
  br i1 %167, label %label_1719, label %label_1721

label_1701:                                       ; preds = %label_1697
  %168 = load ptr, ptr %stmt.776, align 8
  %169 = getelementptr inbounds nuw %ASTNode, ptr %168, i32 0, i32 5
  %170 = load ptr, ptr %169, align 8
  %171 = call ptr @ptr_to_node(ptr %170)
  %172 = call ptr @generate_expression__Struct_ASTNode(ptr %171)
  store ptr %172, ptr %cond_val.798, align 8
  %173 = call i32 @ir_get_label()
  store i32 %173, ptr %then_label.799, align 4
  %174 = call i32 @ir_get_label()
  store i32 %174, ptr %else_label.800, align 4
  %175 = call i32 @ir_get_label()
  store i32 %175, ptr %end_label.801, align 4
  %176 = load ptr, ptr %stmt.776, align 8
  %177 = getelementptr inbounds nuw %ASTNode, ptr %176, i32 0, i32 7
  %178 = load ptr, ptr %177, align 8
  %179 = call i32 @str_equals(ptr %178, ptr @.str.s647)
  %180 = icmp eq i32 %179, 0
  br i1 %180, label %label_1704, label %label_1705

label_1705:                                       ; preds = %label_1701
  %181 = load ptr, ptr %cond_val.798, align 8
  %182 = load i32, ptr %then_label.799, align 4
  %183 = load i32, ptr %end_label.801, align 4
  call void @ir_cond_br_numbered(ptr %181, i32 %182, i32 %183)
  br label %label_1706

label_1704:                                       ; preds = %label_1701
  %184 = load ptr, ptr %cond_val.798, align 8
  %185 = load i32, ptr %then_label.799, align 4
  %186 = load i32, ptr %else_label.800, align 4
  call void @ir_cond_br_numbered(ptr %184, i32 %185, i32 %186)
  br label %label_1706

label_1706:                                       ; preds = %label_1705, %label_1704
  %187 = load i32, ptr %then_label.799, align 4
  call void @ir_label_numbered(i32 %187)
  %188 = load ptr, ptr %stmt.776, align 8
  %189 = getelementptr inbounds nuw %ASTNode, ptr %188, i32 0, i32 6
  %190 = load ptr, ptr %189, align 8
  %191 = call ptr @ptr_to_node(ptr %190)
  call void @generate_block__Struct_ASTNode(ptr %191)
  %192 = call i32 @ir_has_returned()
  %193 = icmp eq i32 %192, 0
  br i1 %193, label %label_1707, label %label_1709

label_1709:                                       ; preds = %label_1707, %label_1706
  call void @ir_clear_returned()
  %194 = load ptr, ptr %stmt.776, align 8
  %195 = getelementptr inbounds nuw %ASTNode, ptr %194, i32 0, i32 7
  %196 = load ptr, ptr %195, align 8
  %197 = call i32 @str_equals(ptr %196, ptr @.str.s648)
  %198 = icmp eq i32 %197, 0
  br i1 %198, label %label_1710, label %label_1712

label_1707:                                       ; preds = %label_1706
  %199 = load i32, ptr %end_label.801, align 4
  call void @ir_br_numbered(i32 %199)
  br label %label_1709

label_1712:                                       ; preds = %label_1718, %label_1709
  %200 = load i32, ptr %end_label.801, align 4
  call void @ir_label_numbered(i32 %200)
  br label %label_1703

label_1710:                                       ; preds = %label_1709
  %201 = load i32, ptr %else_label.800, align 4
  call void @ir_label_numbered(i32 %201)
  %202 = load ptr, ptr %stmt.776, align 8
  %203 = getelementptr inbounds nuw %ASTNode, ptr %202, i32 0, i32 7
  %204 = load ptr, ptr %203, align 8
  %205 = call ptr @ptr_to_node(ptr %204)
  store ptr %205, ptr %else_node.802, align 8
  %206 = load ptr, ptr %else_node.802, align 8
  %207 = getelementptr inbounds nuw %ASTNode, ptr %206, i32 0, i32 0
  %208 = load i32, ptr %207, align 4
  %209 = icmp eq i32 %208, 10
  br i1 %209, label %label_1713, label %label_1714

label_1714:                                       ; preds = %label_1710
  %210 = load ptr, ptr %else_node.802, align 8
  call void @generate_block__Struct_ASTNode(ptr %210)
  br label %label_1715

label_1713:                                       ; preds = %label_1710
  %211 = load ptr, ptr %else_node.802, align 8
  call void @generate_statement__Struct_ASTNode(ptr %211)
  br label %label_1715

label_1715:                                       ; preds = %label_1714, %label_1713
  %212 = call i32 @ir_has_returned()
  %213 = icmp eq i32 %212, 0
  br i1 %213, label %label_1716, label %label_1718

label_1718:                                       ; preds = %label_1716, %label_1715
  call void @ir_clear_returned()
  br label %label_1712

label_1716:                                       ; preds = %label_1715
  %214 = load i32, ptr %end_label.801, align 4
  call void @ir_br_numbered(i32 %214)
  br label %label_1718

label_1721:                                       ; preds = %label_1724, %label_1703
  %215 = load ptr, ptr %stmt.776, align 8
  %216 = getelementptr inbounds nuw %ASTNode, ptr %215, i32 0, i32 0
  %217 = load i32, ptr %216, align 4
  %218 = icmp eq i32 %217, 14
  br i1 %218, label %label_1725, label %label_1727

label_1719:                                       ; preds = %label_1703
  %219 = call i32 @ir_get_label()
  store i32 %219, ptr %cond_label.803, align 4
  %220 = call i32 @ir_get_label()
  store i32 %220, ptr %body_label.804, align 4
  %221 = call i32 @ir_get_label()
  store i32 %221, ptr %end_label.805, align 4
  %222 = load i32, ptr %cond_label.803, align 4
  call void @ir_br_numbered(i32 %222)
  %223 = load i32, ptr %cond_label.803, align 4
  call void @ir_label_numbered(i32 %223)
  %224 = load ptr, ptr %stmt.776, align 8
  %225 = getelementptr inbounds nuw %ASTNode, ptr %224, i32 0, i32 5
  %226 = load ptr, ptr %225, align 8
  %227 = call ptr @ptr_to_node(ptr %226)
  %228 = call ptr @generate_expression__Struct_ASTNode(ptr %227)
  store ptr %228, ptr %cond_val.806, align 8
  %229 = load ptr, ptr %cond_val.806, align 8
  %230 = load i32, ptr %body_label.804, align 4
  %231 = load i32, ptr %end_label.805, align 4
  call void @ir_cond_br_numbered(ptr %229, i32 %230, i32 %231)
  %232 = load i32, ptr %body_label.804, align 4
  call void @ir_label_numbered(i32 %232)
  %233 = load i32, ptr %cond_label.803, align 4
  %234 = load i32, ptr %end_label.805, align 4
  call void @ir_loop_push(i32 %233, i32 %234)
  %235 = load ptr, ptr %stmt.776, align 8
  %236 = getelementptr inbounds nuw %ASTNode, ptr %235, i32 0, i32 6
  %237 = load ptr, ptr %236, align 8
  %238 = call ptr @ptr_to_node(ptr %237)
  call void @generate_block__Struct_ASTNode(ptr %238)
  call void @ir_loop_pop()
  %239 = call i32 @ir_has_returned()
  %240 = icmp eq i32 %239, 0
  br i1 %240, label %label_1722, label %label_1724

label_1724:                                       ; preds = %label_1722, %label_1719
  call void @ir_clear_returned()
  %241 = load i32, ptr %end_label.805, align 4
  call void @ir_label_numbered(i32 %241)
  br label %label_1721

label_1722:                                       ; preds = %label_1719
  %242 = load i32, ptr %cond_label.803, align 4
  call void @ir_br_numbered(i32 %242)
  br label %label_1724

label_1727:                                       ; preds = %label_1730, %label_1721
  %243 = load ptr, ptr %stmt.776, align 8
  %244 = getelementptr inbounds nuw %ASTNode, ptr %243, i32 0, i32 0
  %245 = load i32, ptr %244, align 4
  %246 = icmp eq i32 %245, 12
  br i1 %246, label %label_1731, label %label_1733

label_1725:                                       ; preds = %label_1721
  %247 = call i32 @ir_get_label()
  store i32 %247, ptr %body_label.807, align 4
  %248 = call i32 @ir_get_label()
  store i32 %248, ptr %end_label.808, align 4
  %249 = load i32, ptr %body_label.807, align 4
  call void @ir_br_numbered(i32 %249)
  %250 = load i32, ptr %body_label.807, align 4
  call void @ir_label_numbered(i32 %250)
  %251 = load i32, ptr %body_label.807, align 4
  %252 = load i32, ptr %end_label.808, align 4
  call void @ir_loop_push(i32 %251, i32 %252)
  %253 = load ptr, ptr %stmt.776, align 8
  %254 = getelementptr inbounds nuw %ASTNode, ptr %253, i32 0, i32 5
  %255 = load ptr, ptr %254, align 8
  %256 = call ptr @ptr_to_node(ptr %255)
  call void @generate_block__Struct_ASTNode(ptr %256)
  call void @ir_loop_pop()
  %257 = call i32 @ir_has_returned()
  %258 = icmp eq i32 %257, 0
  br i1 %258, label %label_1728, label %label_1730

label_1730:                                       ; preds = %label_1728, %label_1725
  call void @ir_clear_returned()
  %259 = load i32, ptr %end_label.808, align 4
  call void @ir_label_numbered(i32 %259)
  br label %label_1727

label_1728:                                       ; preds = %label_1725
  %260 = load i32, ptr %body_label.807, align 4
  call void @ir_br_numbered(i32 %260)
  br label %label_1730

label_1733:                                       ; preds = %label_1736, %label_1727
  %261 = load ptr, ptr %stmt.776, align 8
  %262 = getelementptr inbounds nuw %ASTNode, ptr %261, i32 0, i32 0
  %263 = load i32, ptr %262, align 4
  %264 = icmp eq i32 %263, 18
  br i1 %264, label %label_1737, label %label_1739

label_1731:                                       ; preds = %label_1727
  call void @ir_scope_push()
  %265 = load ptr, ptr %stmt.776, align 8
  %266 = getelementptr inbounds nuw %ASTNode, ptr %265, i32 0, i32 1
  %267 = load ptr, ptr %266, align 8
  call void @ir_set_var_type(ptr %267, ptr @.str.s649)
  %268 = load ptr, ptr %stmt.776, align 8
  %269 = getelementptr inbounds nuw %ASTNode, ptr %268, i32 0, i32 1
  %270 = load ptr, ptr %269, align 8
  %271 = call ptr @ir_get_var_slot(ptr %270)
  store ptr %271, ptr %loop_var.809, align 8
  %272 = load ptr, ptr %loop_var.809, align 8
  %273 = call i32 @ir_alloca(ptr @.str.s650, ptr %272)
  %274 = load ptr, ptr %stmt.776, align 8
  %275 = getelementptr inbounds nuw %ASTNode, ptr %274, i32 0, i32 5
  %276 = load ptr, ptr %275, align 8
  %277 = call ptr @ptr_to_node(ptr %276)
  %278 = call ptr @generate_expression__Struct_ASTNode(ptr %277)
  store ptr %278, ptr %start_val.810, align 8
  %279 = load ptr, ptr %start_val.810, align 8
  %280 = load ptr, ptr %loop_var.809, align 8
  call void @ir_store(ptr @.str.s651, ptr %279, ptr %280)
  %281 = call i32 @ir_get_label()
  store i32 %281, ptr %cond_label.811, align 4
  %282 = call i32 @ir_get_label()
  store i32 %282, ptr %body_label.812, align 4
  %283 = call i32 @ir_get_label()
  store i32 %283, ptr %incr_label.813, align 4
  %284 = call i32 @ir_get_label()
  store i32 %284, ptr %end_label.814, align 4
  %285 = load i32, ptr %cond_label.811, align 4
  call void @ir_br_numbered(i32 %285)
  %286 = load i32, ptr %cond_label.811, align 4
  call void @ir_label_numbered(i32 %286)
  %287 = load ptr, ptr %loop_var.809, align 8
  %288 = call i32 @ir_load(ptr @.str.s652, ptr %287)
  store i32 %288, ptr %iv.815, align 4
  %289 = load ptr, ptr %stmt.776, align 8
  %290 = getelementptr inbounds nuw %ASTNode, ptr %289, i32 0, i32 6
  %291 = load ptr, ptr %290, align 8
  %292 = call ptr @ptr_to_node(ptr %291)
  %293 = call ptr @generate_expression__Struct_ASTNode(ptr %292)
  store ptr %293, ptr %end_val.816, align 8
  %294 = load i32, ptr %iv.815, align 4
  %295 = call ptr @ir_get_temp_name(i32 %294)
  %296 = load ptr, ptr %end_val.816, align 8
  %297 = call i32 @ir_icmp_slt(ptr @.str.s653, ptr %295, ptr %296)
  store i32 %297, ptr %cmp.817, align 4
  %298 = load i32, ptr %cmp.817, align 4
  %299 = call ptr @ir_get_temp_name(i32 %298)
  %300 = load i32, ptr %body_label.812, align 4
  %301 = load i32, ptr %end_label.814, align 4
  call void @ir_cond_br_numbered(ptr %299, i32 %300, i32 %301)
  %302 = load i32, ptr %body_label.812, align 4
  call void @ir_label_numbered(i32 %302)
  %303 = load i32, ptr %incr_label.813, align 4
  %304 = load i32, ptr %end_label.814, align 4
  call void @ir_loop_push(i32 %303, i32 %304)
  %305 = load ptr, ptr %stmt.776, align 8
  %306 = getelementptr inbounds nuw %ASTNode, ptr %305, i32 0, i32 7
  %307 = load ptr, ptr %306, align 8
  %308 = call ptr @ptr_to_node(ptr %307)
  call void @generate_block__Struct_ASTNode(ptr %308)
  call void @ir_loop_pop()
  %309 = call i32 @ir_has_returned()
  %310 = icmp eq i32 %309, 0
  br i1 %310, label %label_1734, label %label_1736

label_1736:                                       ; preds = %label_1734, %label_1731
  call void @ir_clear_returned()
  %311 = load i32, ptr %incr_label.813, align 4
  call void @ir_label_numbered(i32 %311)
  %312 = load ptr, ptr %loop_var.809, align 8
  %313 = call i32 @ir_load(ptr @.str.s654, ptr %312)
  store i32 %313, ptr %iv2.818, align 4
  %314 = load i32, ptr %iv2.818, align 4
  %315 = call ptr @ir_get_temp_name(i32 %314)
  %316 = call i32 @ir_add(ptr @.str.s655, ptr %315, ptr @.str.s656)
  store i32 %316, ptr %next.819, align 4
  %317 = load i32, ptr %next.819, align 4
  %318 = call ptr @ir_get_temp_name(i32 %317)
  %319 = load ptr, ptr %loop_var.809, align 8
  call void @ir_store(ptr @.str.s657, ptr %318, ptr %319)
  %320 = load i32, ptr %cond_label.811, align 4
  call void @ir_br_numbered(i32 %320)
  %321 = load i32, ptr %end_label.814, align 4
  call void @ir_label_numbered(i32 %321)
  call void @ir_scope_pop()
  br label %label_1733

label_1734:                                       ; preds = %label_1731
  %322 = load i32, ptr %incr_label.813, align 4
  call void @ir_br_numbered(i32 %322)
  br label %label_1736

label_1739:                                       ; preds = %label_1742, %label_1733
  %323 = load ptr, ptr %stmt.776, align 8
  %324 = getelementptr inbounds nuw %ASTNode, ptr %323, i32 0, i32 0
  %325 = load i32, ptr %324, align 4
  %326 = icmp eq i32 %325, 19
  br i1 %326, label %label_1743, label %label_1745

label_1737:                                       ; preds = %label_1733
  %327 = call i32 @ir_loop_break_label()
  store i32 %327, ptr %target.820, align 4
  %328 = load i32, ptr %target.820, align 4
  %329 = icmp sge i32 %328, 0
  br i1 %329, label %label_1740, label %label_1742

label_1742:                                       ; preds = %label_1740, %label_1737
  br label %label_1739

label_1740:                                       ; preds = %label_1737
  %330 = load i32, ptr %target.820, align 4
  call void @ir_br_numbered(i32 %330)
  call void @ir_set_returned()
  br label %label_1742

label_1745:                                       ; preds = %label_1748, %label_1739
  %331 = load ptr, ptr %stmt.776, align 8
  %332 = getelementptr inbounds nuw %ASTNode, ptr %331, i32 0, i32 0
  %333 = load i32, ptr %332, align 4
  %334 = icmp eq i32 %333, 11
  br i1 %334, label %label_1749, label %label_1751

label_1743:                                       ; preds = %label_1739
  %335 = call i32 @ir_loop_continue_label()
  store i32 %335, ptr %target.821, align 4
  %336 = load i32, ptr %target.821, align 4
  %337 = icmp sge i32 %336, 0
  br i1 %337, label %label_1746, label %label_1748

label_1748:                                       ; preds = %label_1746, %label_1743
  br label %label_1745

label_1746:                                       ; preds = %label_1743
  %338 = load i32, ptr %target.821, align 4
  call void @ir_br_numbered(i32 %338)
  call void @ir_set_returned()
  br label %label_1748

label_1751:                                       ; preds = %label_1766, %label_1745
  ret void

label_1749:                                       ; preds = %label_1745
  %339 = load ptr, ptr %stmt.776, align 8
  %340 = getelementptr inbounds nuw %ASTNode, ptr %339, i32 0, i32 5
  %341 = load ptr, ptr %340, align 8
  %342 = call ptr @ptr_to_node(ptr %341)
  %343 = call ptr @generate_expression__Struct_ASTNode(ptr %342)
  store ptr %343, ptr %scrut_val.822, align 8
  %344 = load ptr, ptr %stmt.776, align 8
  %345 = getelementptr inbounds nuw %ASTNode, ptr %344, i32 0, i32 5
  %346 = load ptr, ptr %345, align 8
  %347 = call ptr @ptr_to_node(ptr %346)
  %348 = call ptr @get_expr_type__Struct_ASTNode(ptr %347)
  store ptr %348, ptr %scrut_type.823, align 8
  %349 = call i32 @ir_get_label()
  store i32 %349, ptr %end_label.824, align 4
  store i1 true, ptr %needs_final_br.825, align 1
  %350 = load ptr, ptr %stmt.776, align 8
  %351 = getelementptr inbounds nuw %ASTNode, ptr %350, i32 0, i32 6
  %352 = load ptr, ptr %351, align 8
  store ptr %352, ptr %arm_ptr.826, align 8
  br label %label_1752

label_1752:                                       ; preds = %label_1757, %label_1749
  %353 = load ptr, ptr %arm_ptr.826, align 8
  %354 = call i32 @str_equals(ptr %353, ptr @.str.s658)
  %355 = icmp eq i32 %354, 0
  br i1 %355, label %label_1753, label %label_1754

label_1754:                                       ; preds = %label_1752
  %356 = load i1, ptr %needs_final_br.825, align 1
  br i1 %356, label %label_1764, label %label_1766

label_1753:                                       ; preds = %label_1752
  %357 = load ptr, ptr %arm_ptr.826, align 8
  %358 = call ptr @ptr_to_node(ptr %357)
  store ptr %358, ptr %arm.827, align 8
  %359 = load ptr, ptr %arm.827, align 8
  %360 = getelementptr inbounds nuw %ASTNode, ptr %359, i32 0, i32 1
  %361 = load ptr, ptr %360, align 8
  %362 = call i32 @str_equals(ptr %361, ptr @.str.s659)
  %363 = icmp eq i32 %362, 1
  br i1 %363, label %label_1755, label %label_1756

label_1756:                                       ; preds = %label_1753
  %364 = load ptr, ptr %arm.827, align 8
  %365 = getelementptr inbounds nuw %ASTNode, ptr %364, i32 0, i32 5
  %366 = load ptr, ptr %365, align 8
  %367 = call ptr @ptr_to_node(ptr %366)
  %368 = call ptr @generate_expression__Struct_ASTNode(ptr %367)
  store ptr %368, ptr %pat_val.828, align 8
  %369 = load ptr, ptr %scrut_type.823, align 8
  %370 = load ptr, ptr %scrut_val.822, align 8
  %371 = load ptr, ptr %pat_val.828, align 8
  %372 = call i32 @ir_icmp_eq(ptr %369, ptr %370, ptr %371)
  store i32 %372, ptr %cmp.829, align 4
  %373 = call i32 @ir_get_label()
  store i32 %373, ptr %arm_label.830, align 4
  %374 = call i32 @ir_get_label()
  store i32 %374, ptr %next_label.831, align 4
  %375 = load i32, ptr %cmp.829, align 4
  %376 = call ptr @ir_get_temp_name(i32 %375)
  %377 = load i32, ptr %arm_label.830, align 4
  %378 = load i32, ptr %next_label.831, align 4
  call void @ir_cond_br_numbered(ptr %376, i32 %377, i32 %378)
  %379 = load i32, ptr %arm_label.830, align 4
  call void @ir_label_numbered(i32 %379)
  %380 = load ptr, ptr %arm.827, align 8
  %381 = getelementptr inbounds nuw %ASTNode, ptr %380, i32 0, i32 6
  %382 = load ptr, ptr %381, align 8
  %383 = call ptr @ptr_to_node(ptr %382)
  call void @generate_block__Struct_ASTNode(ptr %383)
  %384 = call i32 @ir_has_returned()
  %385 = icmp eq i32 %384, 0
  br i1 %385, label %label_1761, label %label_1763

label_1755:                                       ; preds = %label_1753
  %386 = load ptr, ptr %arm.827, align 8
  %387 = getelementptr inbounds nuw %ASTNode, ptr %386, i32 0, i32 6
  %388 = load ptr, ptr %387, align 8
  %389 = call ptr @ptr_to_node(ptr %388)
  call void @generate_block__Struct_ASTNode(ptr %389)
  %390 = call i32 @ir_has_returned()
  %391 = icmp eq i32 %390, 0
  br i1 %391, label %label_1758, label %label_1760

label_1760:                                       ; preds = %label_1758, %label_1755
  call void @ir_clear_returned()
  store i1 false, ptr %needs_final_br.825, align 1
  br label %label_1757

label_1758:                                       ; preds = %label_1755
  %392 = load i32, ptr %end_label.824, align 4
  call void @ir_br_numbered(i32 %392)
  br label %label_1760

label_1757:                                       ; preds = %label_1763, %label_1760
  %393 = load ptr, ptr %arm.827, align 8
  %394 = getelementptr inbounds nuw %ASTNode, ptr %393, i32 0, i32 8
  %395 = load ptr, ptr %394, align 8
  store ptr %395, ptr %arm_ptr.826, align 8
  br label %label_1752

label_1763:                                       ; preds = %label_1761, %label_1756
  call void @ir_clear_returned()
  %396 = load i32, ptr %next_label.831, align 4
  call void @ir_label_numbered(i32 %396)
  store i1 true, ptr %needs_final_br.825, align 1
  br label %label_1757

label_1761:                                       ; preds = %label_1756
  %397 = load i32, ptr %end_label.824, align 4
  call void @ir_br_numbered(i32 %397)
  br label %label_1763

label_1766:                                       ; preds = %label_1764, %label_1754
  %398 = load i32, ptr %end_label.824, align 4
  call void @ir_label_numbered(i32 %398)
  br label %label_1751

label_1764:                                       ; preds = %label_1754
  %399 = load i32, ptr %end_label.824, align 4
  call void @ir_br_numbered(i32 %399)
  br label %label_1766
}

define void @generate_block__Struct_ASTNode(ptr %0) {
entry:
  %block.832 = alloca ptr, align 8
  store ptr %0, ptr %block.832, align 8
  call void @ir_scope_push()
  %1 = load ptr, ptr %block.832, align 8
  %2 = getelementptr inbounds nuw %ASTNode, ptr %1, i32 0, i32 5
  %3 = load ptr, ptr %2, align 8
  %stmt_ptr.833 = alloca ptr, align 8
  store ptr %3, ptr %stmt_ptr.833, align 8
  %stmt.834 = alloca ptr, align 8
  br label %label_1767

label_1767:                                       ; preds = %label_1768, %entry
  %4 = load ptr, ptr %stmt_ptr.833, align 8
  %5 = call i32 @str_equals(ptr %4, ptr @.str.s660)
  %6 = icmp eq i32 %5, 0
  br i1 %6, label %label_1768, label %label_1769

label_1769:                                       ; preds = %label_1767
  call void @ir_scope_pop()
  ret void

label_1768:                                       ; preds = %label_1767
  %7 = load ptr, ptr %stmt_ptr.833, align 8
  %8 = call ptr @ptr_to_node(ptr %7)
  store ptr %8, ptr %stmt.834, align 8
  %9 = load ptr, ptr %stmt.834, align 8
  call void @generate_statement__Struct_ASTNode(ptr %9)
  %10 = load ptr, ptr %stmt.834, align 8
  %11 = getelementptr inbounds nuw %ASTNode, ptr %10, i32 0, i32 8
  %12 = load ptr, ptr %11, align 8
  store ptr %12, ptr %stmt_ptr.833, align 8
  br label %label_1767
}

define void @generate_function__Struct_ASTNode(ptr %0) {
entry:
  %func.835 = alloca ptr, align 8
  store ptr %0, ptr %func.835, align 8
  %1 = load ptr, ptr %func.835, align 8
  %2 = getelementptr inbounds nuw %ASTNode, ptr %1, i32 0, i32 1
  %3 = load ptr, ptr %2, align 8
  %func_name.836 = alloca ptr, align 8
  store ptr %3, ptr %func_name.836, align 8
  %4 = load ptr, ptr %func.835, align 8
  %5 = call ptr @function_symbol_name__Struct_ASTNode(ptr %4)
  %emitted_name.837 = alloca ptr, align 8
  store ptr %5, ptr %emitted_name.837, align 8
  %ret_type.838 = alloca ptr, align 8
  store ptr @.str.s661, ptr %ret_type.838, align 8
  %6 = load ptr, ptr %func.835, align 8
  %7 = getelementptr inbounds nuw %ASTNode, ptr %6, i32 0, i32 7
  %8 = load ptr, ptr %7, align 8
  %9 = call i32 @str_equals(ptr %8, ptr @.str.s662)
  %10 = icmp eq i32 %9, 0
  %ret_node.839 = alloca ptr, align 8
  %is_main.840 = alloca i32, align 4
  %ret_sig_type.841 = alloca ptr, align 8
  %param_ptr.842 = alloca ptr, align 8
  %param_node.843 = alloca ptr, align 8
  %p_type_node.844 = alloca ptr, align 8
  %param_ptr2.845 = alloca ptr, align 8
  %param_node.846 = alloca ptr, align 8
  %p_type_node.847 = alloca ptr, align 8
  %p_type_str.848 = alloca ptr, align 8
  %p_store_type.849 = alloca ptr, align 8
  %p_slot.850 = alloca ptr, align 8
  br i1 %10, label %label_1770, label %label_1772

label_1772:                                       ; preds = %label_1770, %entry
  store i32 0, ptr %is_main.840, align 4
  %11 = load ptr, ptr %func_name.836, align 8
  %12 = call i32 @str_equals(ptr %11, ptr @.str.s663)
  %13 = icmp eq i32 %12, 1
  br i1 %13, label %label_1773, label %label_1775

label_1770:                                       ; preds = %entry
  %14 = load ptr, ptr %func.835, align 8
  %15 = getelementptr inbounds nuw %ASTNode, ptr %14, i32 0, i32 7
  %16 = load ptr, ptr %15, align 8
  %17 = call ptr @ptr_to_node(ptr %16)
  store ptr %17, ptr %ret_node.839, align 8
  %18 = load ptr, ptr %ret_node.839, align 8
  %19 = call ptr @map_type_node__Struct_ASTNode(ptr %18)
  store ptr %19, ptr %ret_type.838, align 8
  br label %label_1772

label_1775:                                       ; preds = %label_1773, %label_1772
  %20 = load ptr, ptr %ret_type.838, align 8
  %21 = call ptr @storage_type__String(ptr %20)
  store ptr %21, ptr %ret_sig_type.841, align 8
  %22 = load ptr, ptr %emitted_name.837, align 8
  %23 = load ptr, ptr %ret_sig_type.841, align 8
  call void @ir_function_begin(ptr %22, ptr %23)
  %24 = load i32, ptr %is_main.840, align 4
  %25 = icmp eq i32 %24, 1
  br i1 %25, label %label_1776, label %label_1778

label_1773:                                       ; preds = %label_1772
  store ptr @.str.s664, ptr %ret_type.838, align 8
  store i32 1, ptr %is_main.840, align 4
  br label %label_1775

label_1778:                                       ; preds = %label_1776, %label_1775
  %26 = load ptr, ptr %func.835, align 8
  %27 = getelementptr inbounds nuw %ASTNode, ptr %26, i32 0, i32 5
  %28 = load ptr, ptr %27, align 8
  store ptr %28, ptr %param_ptr.842, align 8
  br label %label_1779

label_1776:                                       ; preds = %label_1775
  call void @ir_function_param(ptr @.str.s665, ptr @.str.s666)
  call void @ir_function_param(ptr @.str.s667, ptr @.str.s668)
  br label %label_1778

label_1779:                                       ; preds = %label_1780, %label_1778
  %29 = load ptr, ptr %param_ptr.842, align 8
  %30 = call i32 @str_equals(ptr %29, ptr @.str.s669)
  %31 = icmp eq i32 %30, 0
  br i1 %31, label %label_1780, label %label_1781

label_1781:                                       ; preds = %label_1779
  call void @ir_function_body_start()
  call void @ir_clear_local_var_types()
  call void @ir_clear_returned()
  %32 = load i32, ptr %is_main.840, align 4
  %33 = icmp eq i32 %32, 1
  br i1 %33, label %label_1782, label %label_1784

label_1780:                                       ; preds = %label_1779
  %34 = load ptr, ptr %param_ptr.842, align 8
  %35 = call ptr @ptr_to_node(ptr %34)
  store ptr %35, ptr %param_node.843, align 8
  %36 = load ptr, ptr %param_node.843, align 8
  %37 = getelementptr inbounds nuw %ASTNode, ptr %36, i32 0, i32 5
  %38 = load ptr, ptr %37, align 8
  %39 = call ptr @ptr_to_node(ptr %38)
  store ptr %39, ptr %p_type_node.844, align 8
  %40 = load ptr, ptr %p_type_node.844, align 8
  %41 = call ptr @map_type_node__Struct_ASTNode(ptr %40)
  %42 = call ptr @storage_type__String(ptr %41)
  %43 = load ptr, ptr %param_node.843, align 8
  %44 = getelementptr inbounds nuw %ASTNode, ptr %43, i32 0, i32 1
  %45 = load ptr, ptr %44, align 8
  %46 = call ptr @str_concat(ptr @.str.s670, ptr %45)
  call void @ir_function_param(ptr %42, ptr %46)
  %47 = load ptr, ptr %param_node.843, align 8
  %48 = getelementptr inbounds nuw %ASTNode, ptr %47, i32 0, i32 8
  %49 = load ptr, ptr %48, align 8
  store ptr %49, ptr %param_ptr.842, align 8
  br label %label_1779

label_1784:                                       ; preds = %label_1782, %label_1781
  call void @ir_scope_push()
  %50 = load ptr, ptr %func.835, align 8
  %51 = getelementptr inbounds nuw %ASTNode, ptr %50, i32 0, i32 5
  %52 = load ptr, ptr %51, align 8
  store ptr %52, ptr %param_ptr2.845, align 8
  br label %label_1785

label_1782:                                       ; preds = %label_1781
  call void @ir_store_global(ptr @.str.s671, ptr @.str.s672, ptr @.str.s673)
  call void @ir_store_global(ptr @.str.s674, ptr @.str.s675, ptr @.str.s676)
  br label %label_1784

label_1785:                                       ; preds = %label_1786, %label_1784
  %53 = load ptr, ptr %param_ptr2.845, align 8
  %54 = call i32 @str_equals(ptr %53, ptr @.str.s677)
  %55 = icmp eq i32 %54, 0
  br i1 %55, label %label_1786, label %label_1787

label_1787:                                       ; preds = %label_1785
  %56 = load ptr, ptr %func.835, align 8
  %57 = getelementptr inbounds nuw %ASTNode, ptr %56, i32 0, i32 6
  %58 = load ptr, ptr %57, align 8
  %59 = call i32 @str_equals(ptr %58, ptr @.str.s679)
  %60 = icmp eq i32 %59, 0
  br i1 %60, label %label_1788, label %label_1790

label_1786:                                       ; preds = %label_1785
  %61 = load ptr, ptr %param_ptr2.845, align 8
  %62 = call ptr @ptr_to_node(ptr %61)
  store ptr %62, ptr %param_node.846, align 8
  %63 = load ptr, ptr %param_node.846, align 8
  %64 = getelementptr inbounds nuw %ASTNode, ptr %63, i32 0, i32 5
  %65 = load ptr, ptr %64, align 8
  %66 = call ptr @ptr_to_node(ptr %65)
  store ptr %66, ptr %p_type_node.847, align 8
  %67 = load ptr, ptr %p_type_node.847, align 8
  %68 = call ptr @map_type_node__Struct_ASTNode(ptr %67)
  store ptr %68, ptr %p_type_str.848, align 8
  %69 = load ptr, ptr %p_type_str.848, align 8
  %70 = call ptr @storage_type__String(ptr %69)
  store ptr %70, ptr %p_store_type.849, align 8
  %71 = load ptr, ptr %param_node.846, align 8
  %72 = getelementptr inbounds nuw %ASTNode, ptr %71, i32 0, i32 1
  %73 = load ptr, ptr %72, align 8
  %74 = load ptr, ptr %p_type_str.848, align 8
  call void @ir_set_var_type(ptr %73, ptr %74)
  %75 = load ptr, ptr %param_node.846, align 8
  %76 = getelementptr inbounds nuw %ASTNode, ptr %75, i32 0, i32 1
  %77 = load ptr, ptr %76, align 8
  %78 = call ptr @ir_get_var_slot(ptr %77)
  store ptr %78, ptr %p_slot.850, align 8
  %79 = load ptr, ptr %p_store_type.849, align 8
  %80 = load ptr, ptr %p_slot.850, align 8
  %81 = call i32 @ir_alloca(ptr %79, ptr %80)
  %82 = load ptr, ptr %p_store_type.849, align 8
  %83 = load ptr, ptr %param_node.846, align 8
  %84 = getelementptr inbounds nuw %ASTNode, ptr %83, i32 0, i32 1
  %85 = load ptr, ptr %84, align 8
  %86 = call ptr @str_concat(ptr @.str.s678, ptr %85)
  %87 = load ptr, ptr %p_slot.850, align 8
  call void @ir_store(ptr %82, ptr %86, ptr %87)
  %88 = load ptr, ptr %param_node.846, align 8
  %89 = getelementptr inbounds nuw %ASTNode, ptr %88, i32 0, i32 8
  %90 = load ptr, ptr %89, align 8
  store ptr %90, ptr %param_ptr2.845, align 8
  br label %label_1785

label_1790:                                       ; preds = %label_1788, %label_1787
  call void @ir_scope_pop()
  %91 = call i32 @ir_has_returned()
  %92 = icmp eq i32 %91, 0
  br i1 %92, label %label_1791, label %label_1793

label_1788:                                       ; preds = %label_1787
  %93 = load ptr, ptr %func.835, align 8
  %94 = getelementptr inbounds nuw %ASTNode, ptr %93, i32 0, i32 6
  %95 = load ptr, ptr %94, align 8
  %96 = call ptr @ptr_to_node(ptr %95)
  call void @generate_block__Struct_ASTNode(ptr %96)
  br label %label_1790

label_1793:                                       ; preds = %label_1796, %label_1790
  call void @ir_function_end()
  ret void

label_1791:                                       ; preds = %label_1790
  %97 = load ptr, ptr %ret_sig_type.841, align 8
  %98 = call i32 @str_equals(ptr %97, ptr @.str.s680)
  %99 = icmp eq i32 %98, 1
  br i1 %99, label %label_1794, label %label_1795

label_1795:                                       ; preds = %label_1791
  %100 = load i32, ptr %is_main.840, align 4
  %101 = icmp eq i32 %100, 1
  br i1 %101, label %label_1797, label %label_1798

label_1794:                                       ; preds = %label_1791
  call void @ir_ret_void()
  br label %label_1796

label_1796:                                       ; preds = %label_1799, %label_1794
  br label %label_1793

label_1798:                                       ; preds = %label_1795
  %102 = load ptr, ptr %ret_sig_type.841, align 8
  call void @ir_ret(ptr %102, ptr @.str.s683)
  br label %label_1799

label_1797:                                       ; preds = %label_1795
  call void @ir_ret(ptr @.str.s681, ptr @.str.s682)
  br label %label_1799

label_1799:                                       ; preds = %label_1798, %label_1797
  br label %label_1796
}

define void @collect_strings_expr__Struct_ASTNode(ptr %0) {
entry:
  %expr.851 = alloca ptr, align 8
  store ptr %0, ptr %expr.851, align 8
  %1 = load ptr, ptr %expr.851, align 8
  %2 = getelementptr inbounds nuw %ASTNode, ptr %1, i32 0, i32 0
  %3 = load i32, ptr %2, align 4
  %4 = icmp eq i32 %3, 22
  %str_name.852 = alloca ptr, align 8
  %sc.105 = alloca i1, align 1
  %arg_ptr.853 = alloca ptr, align 8
  %arg_node.854 = alloca ptr, align 8
  %elem_ptr.855 = alloca ptr, align 8
  %elem_node.856 = alloca ptr, align 8
  %field_ptr.857 = alloca ptr, align 8
  %field.858 = alloca ptr, align 8
  br i1 %4, label %label_1800, label %label_1802

label_1802:                                       ; preds = %label_1805, %entry
  %5 = load ptr, ptr %expr.851, align 8
  %6 = getelementptr inbounds nuw %ASTNode, ptr %5, i32 0, i32 0
  %7 = load i32, ptr %6, align 4
  %8 = icmp eq i32 %7, 21
  store i1 %8, ptr %sc.105, align 1
  br i1 %8, label %label_1807, label %label_1806

label_1800:                                       ; preds = %entry
  %9 = load ptr, ptr %expr.851, align 8
  %10 = getelementptr inbounds nuw %ASTNode, ptr %9, i32 0, i32 3
  %11 = load i32, ptr %10, align 4
  %12 = icmp eq i32 %11, 0
  br i1 %12, label %label_1803, label %label_1805

label_1805:                                       ; preds = %label_1803, %label_1800
  br label %label_1802

label_1803:                                       ; preds = %label_1800
  %13 = load i32, ptr @ir_string_counter, align 4
  %14 = call ptr @int_to_str(i32 %13)
  %15 = call ptr @str_concat(ptr @.str.s684, ptr %14)
  store ptr %15, ptr %str_name.852, align 8
  %16 = load i32, ptr @ir_string_counter, align 4
  %17 = add i32 %16, 1
  store i32 %17, ptr @ir_string_counter, align 4
  %18 = load ptr, ptr %str_name.852, align 8
  %19 = load ptr, ptr %expr.851, align 8
  %20 = getelementptr inbounds nuw %ASTNode, ptr %19, i32 0, i32 1
  %21 = load ptr, ptr %20, align 8
  call void @ir_global_string(ptr %18, ptr %21)
  %22 = load ptr, ptr %expr.851, align 8
  %23 = load ptr, ptr %str_name.852, align 8
  %24 = getelementptr inbounds nuw %ASTNode, ptr %22, i32 0, i32 2
  store ptr %23, ptr %24, align 8
  br label %label_1805

label_1806:                                       ; preds = %label_1802
  %25 = load ptr, ptr %expr.851, align 8
  %26 = getelementptr inbounds nuw %ASTNode, ptr %25, i32 0, i32 0
  %27 = load i32, ptr %26, align 4
  %28 = icmp eq i32 %27, 29
  store i1 %28, ptr %sc.105, align 1
  br label %label_1807

label_1807:                                       ; preds = %label_1806, %label_1802
  %29 = load i1, ptr %sc.105, align 1
  br i1 %29, label %label_1808, label %label_1810

label_1810:                                       ; preds = %label_1813, %label_1807
  %30 = load ptr, ptr %expr.851, align 8
  %31 = getelementptr inbounds nuw %ASTNode, ptr %30, i32 0, i32 0
  %32 = load i32, ptr %31, align 4
  %33 = icmp eq i32 %32, 20
  br i1 %33, label %label_1814, label %label_1816

label_1808:                                       ; preds = %label_1807
  %34 = load ptr, ptr %expr.851, align 8
  %35 = getelementptr inbounds nuw %ASTNode, ptr %34, i32 0, i32 5
  %36 = load ptr, ptr %35, align 8
  %37 = call i32 @str_equals(ptr %36, ptr @.str.s685)
  %38 = icmp eq i32 %37, 0
  br i1 %38, label %label_1811, label %label_1813

label_1813:                                       ; preds = %label_1811, %label_1808
  br label %label_1810

label_1811:                                       ; preds = %label_1808
  %39 = load ptr, ptr %expr.851, align 8
  %40 = getelementptr inbounds nuw %ASTNode, ptr %39, i32 0, i32 5
  %41 = load ptr, ptr %40, align 8
  %42 = call ptr @ptr_to_node(ptr %41)
  call void @collect_strings_expr__Struct_ASTNode(ptr %42)
  br label %label_1813

label_1816:                                       ; preds = %label_1822, %label_1810
  %43 = load ptr, ptr %expr.851, align 8
  %44 = getelementptr inbounds nuw %ASTNode, ptr %43, i32 0, i32 0
  %45 = load i32, ptr %44, align 4
  %46 = icmp eq i32 %45, 24
  br i1 %46, label %label_1823, label %label_1825

label_1814:                                       ; preds = %label_1810
  %47 = load ptr, ptr %expr.851, align 8
  %48 = getelementptr inbounds nuw %ASTNode, ptr %47, i32 0, i32 5
  %49 = load ptr, ptr %48, align 8
  %50 = call i32 @str_equals(ptr %49, ptr @.str.s686)
  %51 = icmp eq i32 %50, 0
  br i1 %51, label %label_1817, label %label_1819

label_1819:                                       ; preds = %label_1817, %label_1814
  %52 = load ptr, ptr %expr.851, align 8
  %53 = getelementptr inbounds nuw %ASTNode, ptr %52, i32 0, i32 6
  %54 = load ptr, ptr %53, align 8
  %55 = call i32 @str_equals(ptr %54, ptr @.str.s687)
  %56 = icmp eq i32 %55, 0
  br i1 %56, label %label_1820, label %label_1822

label_1817:                                       ; preds = %label_1814
  %57 = load ptr, ptr %expr.851, align 8
  %58 = getelementptr inbounds nuw %ASTNode, ptr %57, i32 0, i32 5
  %59 = load ptr, ptr %58, align 8
  %60 = call ptr @ptr_to_node(ptr %59)
  call void @collect_strings_expr__Struct_ASTNode(ptr %60)
  br label %label_1819

label_1822:                                       ; preds = %label_1820, %label_1819
  br label %label_1816

label_1820:                                       ; preds = %label_1819
  %61 = load ptr, ptr %expr.851, align 8
  %62 = getelementptr inbounds nuw %ASTNode, ptr %61, i32 0, i32 6
  %63 = load ptr, ptr %62, align 8
  %64 = call ptr @ptr_to_node(ptr %63)
  call void @collect_strings_expr__Struct_ASTNode(ptr %64)
  br label %label_1822

label_1825:                                       ; preds = %label_1828, %label_1816
  %65 = load ptr, ptr %expr.851, align 8
  %66 = getelementptr inbounds nuw %ASTNode, ptr %65, i32 0, i32 0
  %67 = load i32, ptr %66, align 4
  %68 = icmp eq i32 %67, 27
  br i1 %68, label %label_1829, label %label_1831

label_1823:                                       ; preds = %label_1816
  %69 = load ptr, ptr %expr.851, align 8
  %70 = getelementptr inbounds nuw %ASTNode, ptr %69, i32 0, i32 6
  %71 = load ptr, ptr %70, align 8
  store ptr %71, ptr %arg_ptr.853, align 8
  br label %label_1826

label_1826:                                       ; preds = %label_1827, %label_1823
  %72 = load ptr, ptr %arg_ptr.853, align 8
  %73 = call i32 @str_equals(ptr %72, ptr @.str.s688)
  %74 = icmp eq i32 %73, 0
  br i1 %74, label %label_1827, label %label_1828

label_1828:                                       ; preds = %label_1826
  br label %label_1825

label_1827:                                       ; preds = %label_1826
  %75 = load ptr, ptr %arg_ptr.853, align 8
  %76 = call ptr @ptr_to_node(ptr %75)
  store ptr %76, ptr %arg_node.854, align 8
  %77 = load ptr, ptr %arg_node.854, align 8
  call void @collect_strings_expr__Struct_ASTNode(ptr %77)
  %78 = load ptr, ptr %arg_node.854, align 8
  %79 = getelementptr inbounds nuw %ASTNode, ptr %78, i32 0, i32 8
  %80 = load ptr, ptr %79, align 8
  store ptr %80, ptr %arg_ptr.853, align 8
  br label %label_1826

label_1831:                                       ; preds = %label_1834, %label_1825
  %81 = load ptr, ptr %expr.851, align 8
  %82 = getelementptr inbounds nuw %ASTNode, ptr %81, i32 0, i32 0
  %83 = load i32, ptr %82, align 4
  %84 = icmp eq i32 %83, 26
  br i1 %84, label %label_1835, label %label_1837

label_1829:                                       ; preds = %label_1825
  %85 = load ptr, ptr %expr.851, align 8
  %86 = getelementptr inbounds nuw %ASTNode, ptr %85, i32 0, i32 5
  %87 = load ptr, ptr %86, align 8
  store ptr %87, ptr %elem_ptr.855, align 8
  br label %label_1832

label_1832:                                       ; preds = %label_1833, %label_1829
  %88 = load ptr, ptr %elem_ptr.855, align 8
  %89 = call i32 @str_equals(ptr %88, ptr @.str.s689)
  %90 = icmp eq i32 %89, 0
  br i1 %90, label %label_1833, label %label_1834

label_1834:                                       ; preds = %label_1832
  br label %label_1831

label_1833:                                       ; preds = %label_1832
  %91 = load ptr, ptr %elem_ptr.855, align 8
  %92 = call ptr @ptr_to_node(ptr %91)
  store ptr %92, ptr %elem_node.856, align 8
  %93 = load ptr, ptr %elem_node.856, align 8
  call void @collect_strings_expr__Struct_ASTNode(ptr %93)
  %94 = load ptr, ptr %elem_node.856, align 8
  %95 = getelementptr inbounds nuw %ASTNode, ptr %94, i32 0, i32 8
  %96 = load ptr, ptr %95, align 8
  store ptr %96, ptr %elem_ptr.855, align 8
  br label %label_1832

label_1837:                                       ; preds = %label_1843, %label_1831
  %97 = load ptr, ptr %expr.851, align 8
  %98 = getelementptr inbounds nuw %ASTNode, ptr %97, i32 0, i32 0
  %99 = load i32, ptr %98, align 4
  %100 = icmp eq i32 %99, 25
  br i1 %100, label %label_1844, label %label_1846

label_1835:                                       ; preds = %label_1831
  %101 = load ptr, ptr %expr.851, align 8
  %102 = getelementptr inbounds nuw %ASTNode, ptr %101, i32 0, i32 5
  %103 = load ptr, ptr %102, align 8
  %104 = call i32 @str_equals(ptr %103, ptr @.str.s690)
  %105 = icmp eq i32 %104, 0
  br i1 %105, label %label_1838, label %label_1840

label_1840:                                       ; preds = %label_1838, %label_1835
  %106 = load ptr, ptr %expr.851, align 8
  %107 = getelementptr inbounds nuw %ASTNode, ptr %106, i32 0, i32 6
  %108 = load ptr, ptr %107, align 8
  %109 = call i32 @str_equals(ptr %108, ptr @.str.s691)
  %110 = icmp eq i32 %109, 0
  br i1 %110, label %label_1841, label %label_1843

label_1838:                                       ; preds = %label_1835
  %111 = load ptr, ptr %expr.851, align 8
  %112 = getelementptr inbounds nuw %ASTNode, ptr %111, i32 0, i32 5
  %113 = load ptr, ptr %112, align 8
  %114 = call ptr @ptr_to_node(ptr %113)
  call void @collect_strings_expr__Struct_ASTNode(ptr %114)
  br label %label_1840

label_1843:                                       ; preds = %label_1841, %label_1840
  br label %label_1837

label_1841:                                       ; preds = %label_1840
  %115 = load ptr, ptr %expr.851, align 8
  %116 = getelementptr inbounds nuw %ASTNode, ptr %115, i32 0, i32 6
  %117 = load ptr, ptr %116, align 8
  %118 = call ptr @ptr_to_node(ptr %117)
  call void @collect_strings_expr__Struct_ASTNode(ptr %118)
  br label %label_1843

label_1846:                                       ; preds = %label_1849, %label_1837
  %119 = load ptr, ptr %expr.851, align 8
  %120 = getelementptr inbounds nuw %ASTNode, ptr %119, i32 0, i32 0
  %121 = load i32, ptr %120, align 4
  %122 = icmp eq i32 %121, 28
  br i1 %122, label %label_1850, label %label_1852

label_1844:                                       ; preds = %label_1837
  %123 = load ptr, ptr %expr.851, align 8
  %124 = getelementptr inbounds nuw %ASTNode, ptr %123, i32 0, i32 5
  %125 = load ptr, ptr %124, align 8
  %126 = call i32 @str_equals(ptr %125, ptr @.str.s692)
  %127 = icmp eq i32 %126, 0
  br i1 %127, label %label_1847, label %label_1849

label_1849:                                       ; preds = %label_1847, %label_1844
  br label %label_1846

label_1847:                                       ; preds = %label_1844
  %128 = load ptr, ptr %expr.851, align 8
  %129 = getelementptr inbounds nuw %ASTNode, ptr %128, i32 0, i32 5
  %130 = load ptr, ptr %129, align 8
  %131 = call ptr @ptr_to_node(ptr %130)
  call void @collect_strings_expr__Struct_ASTNode(ptr %131)
  br label %label_1849

label_1852:                                       ; preds = %label_1855, %label_1846
  ret void

label_1850:                                       ; preds = %label_1846
  %132 = load ptr, ptr %expr.851, align 8
  %133 = getelementptr inbounds nuw %ASTNode, ptr %132, i32 0, i32 5
  %134 = load ptr, ptr %133, align 8
  store ptr %134, ptr %field_ptr.857, align 8
  br label %label_1853

label_1853:                                       ; preds = %label_1858, %label_1850
  %135 = load ptr, ptr %field_ptr.857, align 8
  %136 = call i32 @str_equals(ptr %135, ptr @.str.s693)
  %137 = icmp eq i32 %136, 0
  br i1 %137, label %label_1854, label %label_1855

label_1855:                                       ; preds = %label_1853
  br label %label_1852

label_1854:                                       ; preds = %label_1853
  %138 = load ptr, ptr %field_ptr.857, align 8
  %139 = call ptr @ptr_to_node(ptr %138)
  store ptr %139, ptr %field.858, align 8
  %140 = load ptr, ptr %field.858, align 8
  %141 = getelementptr inbounds nuw %ASTNode, ptr %140, i32 0, i32 5
  %142 = load ptr, ptr %141, align 8
  %143 = call i32 @str_equals(ptr %142, ptr @.str.s694)
  %144 = icmp eq i32 %143, 0
  br i1 %144, label %label_1856, label %label_1858

label_1858:                                       ; preds = %label_1856, %label_1854
  %145 = load ptr, ptr %field.858, align 8
  %146 = getelementptr inbounds nuw %ASTNode, ptr %145, i32 0, i32 8
  %147 = load ptr, ptr %146, align 8
  store ptr %147, ptr %field_ptr.857, align 8
  br label %label_1853

label_1856:                                       ; preds = %label_1854
  %148 = load ptr, ptr %field.858, align 8
  %149 = getelementptr inbounds nuw %ASTNode, ptr %148, i32 0, i32 5
  %150 = load ptr, ptr %149, align 8
  %151 = call ptr @ptr_to_node(ptr %150)
  call void @collect_strings_expr__Struct_ASTNode(ptr %151)
  br label %label_1858
}

define void @declare_extern_function__Struct_ASTNode(ptr %0) {
entry:
  %ext.859 = alloca ptr, align 8
  store ptr %0, ptr %ext.859, align 8
  %1 = load ptr, ptr %ext.859, align 8
  %2 = load ptr, ptr %ext.859, align 8
  %3 = getelementptr inbounds nuw %ASTNode, ptr %2, i32 0, i32 6
  %4 = load ptr, ptr %3, align 8
  %5 = call ptr @get_declared_return_type__Struct_ASTNode_String(ptr %1, ptr %4)
  %ret_type.860 = alloca ptr, align 8
  store ptr %5, ptr %ret_type.860, align 8
  %6 = load ptr, ptr %ext.859, align 8
  %7 = call ptr @function_symbol_name__Struct_ASTNode(ptr %6)
  %8 = call ptr @fn_key__String(ptr %7)
  %9 = load ptr, ptr %ret_type.860, align 8
  call void @ir_set_var_type(ptr %8, ptr %9)
  %10 = load ptr, ptr %ext.859, align 8
  %11 = call ptr @function_symbol_name__Struct_ASTNode(ptr %10)
  %12 = load ptr, ptr %ret_type.860, align 8
  %13 = call ptr @storage_type__String(ptr %12)
  call void @ir_declare_function_begin(ptr %11, ptr %13)
  %14 = load ptr, ptr %ext.859, align 8
  %15 = getelementptr inbounds nuw %ASTNode, ptr %14, i32 0, i32 5
  %16 = load ptr, ptr %15, align 8
  %param_ptr.861 = alloca ptr, align 8
  store ptr %16, ptr %param_ptr.861, align 8
  %param_node.862 = alloca ptr, align 8
  %p_type_node.863 = alloca ptr, align 8
  br label %label_1859

label_1859:                                       ; preds = %label_1860, %entry
  %17 = load ptr, ptr %param_ptr.861, align 8
  %18 = call i32 @str_equals(ptr %17, ptr @.str.s695)
  %19 = icmp eq i32 %18, 0
  br i1 %19, label %label_1860, label %label_1861

label_1861:                                       ; preds = %label_1859
  call void @ir_declare_function_end()
  ret void

label_1860:                                       ; preds = %label_1859
  %20 = load ptr, ptr %param_ptr.861, align 8
  %21 = call ptr @ptr_to_node(ptr %20)
  store ptr %21, ptr %param_node.862, align 8
  %22 = load ptr, ptr %param_node.862, align 8
  %23 = getelementptr inbounds nuw %ASTNode, ptr %22, i32 0, i32 5
  %24 = load ptr, ptr %23, align 8
  %25 = call ptr @ptr_to_node(ptr %24)
  store ptr %25, ptr %p_type_node.863, align 8
  %26 = load ptr, ptr %p_type_node.863, align 8
  %27 = call ptr @map_type_node__Struct_ASTNode(ptr %26)
  %28 = call ptr @storage_type__String(ptr %27)
  call void @ir_declare_function_param(ptr %28)
  %29 = load ptr, ptr %param_node.862, align 8
  %30 = getelementptr inbounds nuw %ASTNode, ptr %29, i32 0, i32 8
  %31 = load ptr, ptr %30, align 8
  store ptr %31, ptr %param_ptr.861, align 8
  br label %label_1859
}

define i1 @module_has_function__Struct_ASTNode_String(ptr %0, ptr %1) {
entry:
  %module.864 = alloca ptr, align 8
  store ptr %0, ptr %module.864, align 8
  %name.865 = alloca ptr, align 8
  store ptr %1, ptr %name.865, align 8
  %2 = load ptr, ptr %module.864, align 8
  %3 = getelementptr inbounds nuw %ASTNode, ptr %2, i32 0, i32 5
  %4 = load ptr, ptr %3, align 8
  %stmt_ptr.866 = alloca ptr, align 8
  store ptr %4, ptr %stmt_ptr.866, align 8
  %stmt.867 = alloca ptr, align 8
  %sc.106 = alloca i1, align 1
  br label %label_1862

label_1862:                                       ; preds = %label_1869, %entry
  %5 = load ptr, ptr %stmt_ptr.866, align 8
  %6 = call i32 @str_equals(ptr %5, ptr @.str.s696)
  %7 = icmp eq i32 %6, 0
  br i1 %7, label %label_1863, label %label_1864

label_1864:                                       ; preds = %label_1862
  ret i1 false

label_1863:                                       ; preds = %label_1862
  %8 = load ptr, ptr %stmt_ptr.866, align 8
  %9 = call ptr @ptr_to_node(ptr %8)
  store ptr %9, ptr %stmt.867, align 8
  %10 = load ptr, ptr %stmt.867, align 8
  %11 = getelementptr inbounds nuw %ASTNode, ptr %10, i32 0, i32 0
  %12 = load i32, ptr %11, align 4
  %13 = icmp eq i32 %12, 4
  store i1 %13, ptr %sc.106, align 1
  br i1 %13, label %label_1865, label %label_1866

label_1866:                                       ; preds = %label_1865, %label_1863
  %14 = load i1, ptr %sc.106, align 1
  br i1 %14, label %label_1867, label %label_1869

label_1865:                                       ; preds = %label_1863
  %15 = load ptr, ptr %stmt.867, align 8
  %16 = getelementptr inbounds nuw %ASTNode, ptr %15, i32 0, i32 1
  %17 = load ptr, ptr %16, align 8
  %18 = load ptr, ptr %name.865, align 8
  %19 = call i32 @str_equals(ptr %17, ptr %18)
  %20 = icmp eq i32 %19, 1
  store i1 %20, ptr %sc.106, align 1
  br label %label_1866

label_1869:                                       ; preds = %label_1866
  %21 = load ptr, ptr %stmt.867, align 8
  %22 = getelementptr inbounds nuw %ASTNode, ptr %21, i32 0, i32 8
  %23 = load ptr, ptr %22, align 8
  store ptr %23, ptr %stmt_ptr.866, align 8
  br label %label_1862

label_1867:                                       ; preds = %label_1866
  ret i1 true
}

define void @register_enum_decl__Struct_ASTNode(ptr %0) {
entry:
  %enum_node.868 = alloca ptr, align 8
  store ptr %0, ptr %enum_node.868, align 8
  %1 = load ptr, ptr %enum_node.868, align 8
  %2 = getelementptr inbounds nuw %ASTNode, ptr %1, i32 0, i32 5
  %3 = load ptr, ptr %2, align 8
  %variant_ptr.869 = alloca ptr, align 8
  store ptr %3, ptr %variant_ptr.869, align 8
  %value.870 = alloca i32, align 4
  store i32 0, ptr %value.870, align 4
  %variant.871 = alloca ptr, align 8
  br label %label_1870

label_1870:                                       ; preds = %label_1871, %entry
  %4 = load ptr, ptr %variant_ptr.869, align 8
  %5 = call i32 @str_equals(ptr %4, ptr @.str.s697)
  %6 = icmp eq i32 %5, 0
  br i1 %6, label %label_1871, label %label_1872

label_1872:                                       ; preds = %label_1870
  ret void

label_1871:                                       ; preds = %label_1870
  %7 = load ptr, ptr %variant_ptr.869, align 8
  %8 = call ptr @ptr_to_node(ptr %7)
  store ptr %8, ptr %variant.871, align 8
  %9 = load ptr, ptr %enum_node.868, align 8
  %10 = getelementptr inbounds nuw %ASTNode, ptr %9, i32 0, i32 1
  %11 = load ptr, ptr %10, align 8
  %12 = load ptr, ptr %variant.871, align 8
  %13 = getelementptr inbounds nuw %ASTNode, ptr %12, i32 0, i32 1
  %14 = load ptr, ptr %13, align 8
  %15 = load i32, ptr %value.870, align 4
  call void @ir_register_enum_variant(ptr %11, ptr %14, i32 %15)
  %16 = load i32, ptr %value.870, align 4
  %17 = add i32 %16, 1
  store i32 %17, ptr %value.870, align 4
  %18 = load ptr, ptr %variant.871, align 8
  %19 = getelementptr inbounds nuw %ASTNode, ptr %18, i32 0, i32 8
  %20 = load ptr, ptr %19, align 8
  store ptr %20, ptr %variant_ptr.869, align 8
  br label %label_1870
}

define void @register_struct_name__Struct_ASTNode(ptr %0) {
entry:
  %struct_node.872 = alloca ptr, align 8
  store ptr %0, ptr %struct_node.872, align 8
  %1 = load ptr, ptr %struct_node.872, align 8
  %2 = getelementptr inbounds nuw %ASTNode, ptr %1, i32 0, i32 1
  %3 = load ptr, ptr %2, align 8
  call void @ir_register_struct(ptr %3)
  ret void
}

define void @generate_struct_decl__Struct_ASTNode(ptr %0) {
entry:
  %struct_node.873 = alloca ptr, align 8
  store ptr %0, ptr %struct_node.873, align 8
  %1 = load ptr, ptr %struct_node.873, align 8
  %2 = getelementptr inbounds nuw %ASTNode, ptr %1, i32 0, i32 5
  %3 = load ptr, ptr %2, align 8
  %first_field_ptr.874 = alloca ptr, align 8
  store ptr %3, ptr %first_field_ptr.874, align 8
  %4 = load ptr, ptr %first_field_ptr.874, align 8
  %5 = call i32 @str_equals(ptr %4, ptr @.str.s698)
  %6 = icmp eq i32 %5, 0
  %first_field.875 = alloca ptr, align 8
  %field_ptr.876 = alloca ptr, align 8
  %field.877 = alloca ptr, align 8
  %type_node.878 = alloca ptr, align 8
  %field_type.879 = alloca ptr, align 8
  br i1 %6, label %label_1873, label %label_1875

label_1875:                                       ; preds = %label_1878, %entry
  %7 = load ptr, ptr %struct_node.873, align 8
  %8 = getelementptr inbounds nuw %ASTNode, ptr %7, i32 0, i32 1
  %9 = load ptr, ptr %8, align 8
  call void @ir_struct_type_begin(ptr %9)
  %10 = load ptr, ptr %struct_node.873, align 8
  %11 = getelementptr inbounds nuw %ASTNode, ptr %10, i32 0, i32 5
  %12 = load ptr, ptr %11, align 8
  store ptr %12, ptr %field_ptr.876, align 8
  br label %label_1879

label_1873:                                       ; preds = %entry
  %13 = load ptr, ptr %first_field_ptr.874, align 8
  %14 = call ptr @ptr_to_node(ptr %13)
  store ptr %14, ptr %first_field.875, align 8
  %15 = load ptr, ptr %struct_node.873, align 8
  %16 = getelementptr inbounds nuw %ASTNode, ptr %15, i32 0, i32 1
  %17 = load ptr, ptr %16, align 8
  %18 = load ptr, ptr %first_field.875, align 8
  %19 = getelementptr inbounds nuw %ASTNode, ptr %18, i32 0, i32 1
  %20 = load ptr, ptr %19, align 8
  %21 = call i32 @ir_get_struct_field_index(ptr %17, ptr %20)
  %22 = icmp sge i32 %21, 0
  br i1 %22, label %label_1876, label %label_1878

label_1878:                                       ; preds = %label_1873
  br label %label_1875

label_1876:                                       ; preds = %label_1873
  ret void

label_1879:                                       ; preds = %label_1880, %label_1875
  %23 = load ptr, ptr %field_ptr.876, align 8
  %24 = call i32 @str_equals(ptr %23, ptr @.str.s699)
  %25 = icmp eq i32 %24, 0
  br i1 %25, label %label_1880, label %label_1881

label_1881:                                       ; preds = %label_1879
  call void @ir_struct_type_end()
  ret void

label_1880:                                       ; preds = %label_1879
  %26 = load ptr, ptr %field_ptr.876, align 8
  %27 = call ptr @ptr_to_node(ptr %26)
  store ptr %27, ptr %field.877, align 8
  %28 = load ptr, ptr %field.877, align 8
  %29 = getelementptr inbounds nuw %ASTNode, ptr %28, i32 0, i32 5
  %30 = load ptr, ptr %29, align 8
  %31 = call ptr @ptr_to_node(ptr %30)
  store ptr %31, ptr %type_node.878, align 8
  %32 = load ptr, ptr %type_node.878, align 8
  %33 = call ptr @map_type_node__Struct_ASTNode(ptr %32)
  %34 = call ptr @storage_type__String(ptr %33)
  store ptr %34, ptr %field_type.879, align 8
  %35 = load ptr, ptr %struct_node.873, align 8
  %36 = getelementptr inbounds nuw %ASTNode, ptr %35, i32 0, i32 1
  %37 = load ptr, ptr %36, align 8
  %38 = load ptr, ptr %field.877, align 8
  %39 = getelementptr inbounds nuw %ASTNode, ptr %38, i32 0, i32 1
  %40 = load ptr, ptr %39, align 8
  %41 = load ptr, ptr %field_type.879, align 8
  call void @ir_register_struct_field(ptr %37, ptr %40, ptr %41)
  %42 = load ptr, ptr %field_type.879, align 8
  call void @ir_struct_type_field(ptr %42)
  %43 = load ptr, ptr %field.877, align 8
  %44 = getelementptr inbounds nuw %ASTNode, ptr %43, i32 0, i32 8
  %45 = load ptr, ptr %44, align 8
  store ptr %45, ptr %field_ptr.876, align 8
  br label %label_1879
}

define void @collect_strings_child_expr__String(ptr %0) {
entry:
  %child.880 = alloca ptr, align 8
  store ptr %0, ptr %child.880, align 8
  %1 = load ptr, ptr %child.880, align 8
  %2 = call i32 @str_equals(ptr %1, ptr @.str.s700)
  %3 = icmp eq i32 %2, 0
  br i1 %3, label %label_1882, label %label_1884

label_1884:                                       ; preds = %label_1882, %entry
  ret void

label_1882:                                       ; preds = %entry
  %4 = load ptr, ptr %child.880, align 8
  %5 = call ptr @ptr_to_node(ptr %4)
  call void @collect_strings_expr__Struct_ASTNode(ptr %5)
  br label %label_1884
}

define void @collect_strings_child_block__String(ptr %0) {
entry:
  %child.881 = alloca ptr, align 8
  store ptr %0, ptr %child.881, align 8
  %1 = load ptr, ptr %child.881, align 8
  %2 = call i32 @str_equals(ptr %1, ptr @.str.s701)
  %3 = icmp eq i32 %2, 0
  br i1 %3, label %label_1885, label %label_1887

label_1887:                                       ; preds = %label_1885, %entry
  ret void

label_1885:                                       ; preds = %entry
  %4 = load ptr, ptr %child.881, align 8
  %5 = call ptr @ptr_to_node(ptr %4)
  call void @collect_strings_block__Struct_ASTNode(ptr %5)
  br label %label_1887
}

define void @collect_strings_block__Struct_ASTNode(ptr %0) {
entry:
  %block.886 = alloca ptr, align 8
  store ptr %0, ptr %block.886, align 8
  %1 = load ptr, ptr %block.886, align 8
  %2 = getelementptr inbounds nuw %ASTNode, ptr %1, i32 0, i32 5
  %3 = load ptr, ptr %2, align 8
  %s_ptr.887 = alloca ptr, align 8
  store ptr %3, ptr %s_ptr.887, align 8
  %s.888 = alloca ptr, align 8
  br label %label_1924

label_1924:                                       ; preds = %label_1925, %entry
  %4 = load ptr, ptr %s_ptr.887, align 8
  %5 = call i32 @str_equals(ptr %4, ptr @.str.s704)
  %6 = icmp eq i32 %5, 0
  br i1 %6, label %label_1925, label %label_1926

label_1926:                                       ; preds = %label_1924
  ret void

label_1925:                                       ; preds = %label_1924
  %7 = load ptr, ptr %s_ptr.887, align 8
  %8 = call ptr @ptr_to_node(ptr %7)
  store ptr %8, ptr %s.888, align 8
  %9 = load ptr, ptr %s.888, align 8
  call void @collect_strings_stmt__Struct_ASTNode(ptr %9)
  %10 = load ptr, ptr %s.888, align 8
  %11 = getelementptr inbounds nuw %ASTNode, ptr %10, i32 0, i32 8
  %12 = load ptr, ptr %11, align 8
  store ptr %12, ptr %s_ptr.887, align 8
  br label %label_1924
}

define void @collect_strings_stmt__Struct_ASTNode(ptr %0) {
entry:
  %stmt.882 = alloca ptr, align 8
  store ptr %0, ptr %stmt.882, align 8
  %1 = load ptr, ptr %stmt.882, align 8
  %2 = getelementptr inbounds nuw %ASTNode, ptr %1, i32 0, i32 0
  %3 = load i32, ptr %2, align 4
  %4 = icmp eq i32 %3, 3
  %else_node.883 = alloca ptr, align 8
  %arm_ptr.884 = alloca ptr, align 8
  %arm.885 = alloca ptr, align 8
  br i1 %4, label %label_1888, label %label_1890

label_1890:                                       ; preds = %label_1888, %entry
  %5 = load ptr, ptr %stmt.882, align 8
  %6 = getelementptr inbounds nuw %ASTNode, ptr %5, i32 0, i32 0
  %7 = load i32, ptr %6, align 4
  %8 = icmp eq i32 %7, 17
  br i1 %8, label %label_1891, label %label_1893

label_1888:                                       ; preds = %entry
  %9 = load ptr, ptr %stmt.882, align 8
  %10 = getelementptr inbounds nuw %ASTNode, ptr %9, i32 0, i32 6
  %11 = load ptr, ptr %10, align 8
  call void @collect_strings_child_expr__String(ptr %11)
  br label %label_1890

label_1893:                                       ; preds = %label_1891, %label_1890
  %12 = load ptr, ptr %stmt.882, align 8
  %13 = getelementptr inbounds nuw %ASTNode, ptr %12, i32 0, i32 0
  %14 = load i32, ptr %13, align 4
  %15 = icmp eq i32 %14, 15
  br i1 %15, label %label_1894, label %label_1896

label_1891:                                       ; preds = %label_1890
  %16 = load ptr, ptr %stmt.882, align 8
  %17 = getelementptr inbounds nuw %ASTNode, ptr %16, i32 0, i32 5
  %18 = load ptr, ptr %17, align 8
  call void @collect_strings_child_expr__String(ptr %18)
  br label %label_1893

label_1896:                                       ; preds = %label_1894, %label_1893
  %19 = load ptr, ptr %stmt.882, align 8
  %20 = getelementptr inbounds nuw %ASTNode, ptr %19, i32 0, i32 0
  %21 = load i32, ptr %20, align 4
  %22 = icmp eq i32 %21, 16
  br i1 %22, label %label_1897, label %label_1899

label_1894:                                       ; preds = %label_1893
  %23 = load ptr, ptr %stmt.882, align 8
  %24 = getelementptr inbounds nuw %ASTNode, ptr %23, i32 0, i32 5
  %25 = load ptr, ptr %24, align 8
  call void @collect_strings_child_expr__String(ptr %25)
  br label %label_1896

label_1899:                                       ; preds = %label_1897, %label_1896
  %26 = load ptr, ptr %stmt.882, align 8
  %27 = getelementptr inbounds nuw %ASTNode, ptr %26, i32 0, i32 0
  %28 = load i32, ptr %27, align 4
  %29 = icmp eq i32 %28, 10
  br i1 %29, label %label_1900, label %label_1902

label_1897:                                       ; preds = %label_1896
  %30 = load ptr, ptr %stmt.882, align 8
  %31 = getelementptr inbounds nuw %ASTNode, ptr %30, i32 0, i32 5
  %32 = load ptr, ptr %31, align 8
  call void @collect_strings_child_expr__String(ptr %32)
  %33 = load ptr, ptr %stmt.882, align 8
  %34 = getelementptr inbounds nuw %ASTNode, ptr %33, i32 0, i32 6
  %35 = load ptr, ptr %34, align 8
  call void @collect_strings_child_expr__String(ptr %35)
  br label %label_1899

label_1902:                                       ; preds = %label_1905, %label_1899
  %36 = load ptr, ptr %stmt.882, align 8
  %37 = getelementptr inbounds nuw %ASTNode, ptr %36, i32 0, i32 0
  %38 = load i32, ptr %37, align 4
  %39 = icmp eq i32 %38, 13
  br i1 %39, label %label_1909, label %label_1911

label_1900:                                       ; preds = %label_1899
  %40 = load ptr, ptr %stmt.882, align 8
  %41 = getelementptr inbounds nuw %ASTNode, ptr %40, i32 0, i32 5
  %42 = load ptr, ptr %41, align 8
  call void @collect_strings_child_expr__String(ptr %42)
  %43 = load ptr, ptr %stmt.882, align 8
  %44 = getelementptr inbounds nuw %ASTNode, ptr %43, i32 0, i32 6
  %45 = load ptr, ptr %44, align 8
  call void @collect_strings_child_block__String(ptr %45)
  %46 = load ptr, ptr %stmt.882, align 8
  %47 = getelementptr inbounds nuw %ASTNode, ptr %46, i32 0, i32 7
  %48 = load ptr, ptr %47, align 8
  %49 = call i32 @str_equals(ptr %48, ptr @.str.s702)
  %50 = icmp eq i32 %49, 0
  br i1 %50, label %label_1903, label %label_1905

label_1905:                                       ; preds = %label_1908, %label_1900
  br label %label_1902

label_1903:                                       ; preds = %label_1900
  %51 = load ptr, ptr %stmt.882, align 8
  %52 = getelementptr inbounds nuw %ASTNode, ptr %51, i32 0, i32 7
  %53 = load ptr, ptr %52, align 8
  %54 = call ptr @ptr_to_node(ptr %53)
  store ptr %54, ptr %else_node.883, align 8
  %55 = load ptr, ptr %else_node.883, align 8
  %56 = getelementptr inbounds nuw %ASTNode, ptr %55, i32 0, i32 0
  %57 = load i32, ptr %56, align 4
  %58 = icmp eq i32 %57, 10
  br i1 %58, label %label_1906, label %label_1907

label_1907:                                       ; preds = %label_1903
  %59 = load ptr, ptr %else_node.883, align 8
  call void @collect_strings_block__Struct_ASTNode(ptr %59)
  br label %label_1908

label_1906:                                       ; preds = %label_1903
  %60 = load ptr, ptr %else_node.883, align 8
  call void @collect_strings_stmt__Struct_ASTNode(ptr %60)
  br label %label_1908

label_1908:                                       ; preds = %label_1907, %label_1906
  br label %label_1905

label_1911:                                       ; preds = %label_1909, %label_1902
  %61 = load ptr, ptr %stmt.882, align 8
  %62 = getelementptr inbounds nuw %ASTNode, ptr %61, i32 0, i32 0
  %63 = load i32, ptr %62, align 4
  %64 = icmp eq i32 %63, 14
  br i1 %64, label %label_1912, label %label_1914

label_1909:                                       ; preds = %label_1902
  %65 = load ptr, ptr %stmt.882, align 8
  %66 = getelementptr inbounds nuw %ASTNode, ptr %65, i32 0, i32 5
  %67 = load ptr, ptr %66, align 8
  call void @collect_strings_child_expr__String(ptr %67)
  %68 = load ptr, ptr %stmt.882, align 8
  %69 = getelementptr inbounds nuw %ASTNode, ptr %68, i32 0, i32 6
  %70 = load ptr, ptr %69, align 8
  call void @collect_strings_child_block__String(ptr %70)
  br label %label_1911

label_1914:                                       ; preds = %label_1912, %label_1911
  %71 = load ptr, ptr %stmt.882, align 8
  %72 = getelementptr inbounds nuw %ASTNode, ptr %71, i32 0, i32 0
  %73 = load i32, ptr %72, align 4
  %74 = icmp eq i32 %73, 12
  br i1 %74, label %label_1915, label %label_1917

label_1912:                                       ; preds = %label_1911
  %75 = load ptr, ptr %stmt.882, align 8
  %76 = getelementptr inbounds nuw %ASTNode, ptr %75, i32 0, i32 5
  %77 = load ptr, ptr %76, align 8
  call void @collect_strings_child_block__String(ptr %77)
  br label %label_1914

label_1917:                                       ; preds = %label_1915, %label_1914
  %78 = load ptr, ptr %stmt.882, align 8
  %79 = getelementptr inbounds nuw %ASTNode, ptr %78, i32 0, i32 0
  %80 = load i32, ptr %79, align 4
  %81 = icmp eq i32 %80, 11
  br i1 %81, label %label_1918, label %label_1920

label_1915:                                       ; preds = %label_1914
  %82 = load ptr, ptr %stmt.882, align 8
  %83 = getelementptr inbounds nuw %ASTNode, ptr %82, i32 0, i32 5
  %84 = load ptr, ptr %83, align 8
  call void @collect_strings_child_expr__String(ptr %84)
  %85 = load ptr, ptr %stmt.882, align 8
  %86 = getelementptr inbounds nuw %ASTNode, ptr %85, i32 0, i32 6
  %87 = load ptr, ptr %86, align 8
  call void @collect_strings_child_expr__String(ptr %87)
  %88 = load ptr, ptr %stmt.882, align 8
  %89 = getelementptr inbounds nuw %ASTNode, ptr %88, i32 0, i32 7
  %90 = load ptr, ptr %89, align 8
  call void @collect_strings_child_block__String(ptr %90)
  br label %label_1917

label_1920:                                       ; preds = %label_1923, %label_1917
  ret void

label_1918:                                       ; preds = %label_1917
  %91 = load ptr, ptr %stmt.882, align 8
  %92 = getelementptr inbounds nuw %ASTNode, ptr %91, i32 0, i32 5
  %93 = load ptr, ptr %92, align 8
  call void @collect_strings_child_expr__String(ptr %93)
  %94 = load ptr, ptr %stmt.882, align 8
  %95 = getelementptr inbounds nuw %ASTNode, ptr %94, i32 0, i32 6
  %96 = load ptr, ptr %95, align 8
  store ptr %96, ptr %arm_ptr.884, align 8
  br label %label_1921

label_1921:                                       ; preds = %label_1922, %label_1918
  %97 = load ptr, ptr %arm_ptr.884, align 8
  %98 = call i32 @str_equals(ptr %97, ptr @.str.s703)
  %99 = icmp eq i32 %98, 0
  br i1 %99, label %label_1922, label %label_1923

label_1923:                                       ; preds = %label_1921
  br label %label_1920

label_1922:                                       ; preds = %label_1921
  %100 = load ptr, ptr %arm_ptr.884, align 8
  %101 = call ptr @ptr_to_node(ptr %100)
  store ptr %101, ptr %arm.885, align 8
  %102 = load ptr, ptr %arm.885, align 8
  %103 = getelementptr inbounds nuw %ASTNode, ptr %102, i32 0, i32 5
  %104 = load ptr, ptr %103, align 8
  call void @collect_strings_child_expr__String(ptr %104)
  %105 = load ptr, ptr %arm.885, align 8
  %106 = getelementptr inbounds nuw %ASTNode, ptr %105, i32 0, i32 6
  %107 = load ptr, ptr %106, align 8
  call void @collect_strings_child_block__String(ptr %107)
  %108 = load ptr, ptr %arm.885, align 8
  %109 = getelementptr inbounds nuw %ASTNode, ptr %108, i32 0, i32 8
  %110 = load ptr, ptr %109, align 8
  store ptr %110, ptr %arm_ptr.884, align 8
  br label %label_1921
}

define void @collect_strings_function__Struct_ASTNode(ptr %0) {
entry:
  %func.889 = alloca ptr, align 8
  store ptr %0, ptr %func.889, align 8
  %1 = load ptr, ptr %func.889, align 8
  %2 = getelementptr inbounds nuw %ASTNode, ptr %1, i32 0, i32 6
  %3 = load ptr, ptr %2, align 8
  %4 = call i32 @str_equals(ptr %3, ptr @.str.s705)
  %5 = icmp eq i32 %4, 0
  br i1 %5, label %label_1927, label %label_1929

label_1929:                                       ; preds = %label_1927, %entry
  ret void

label_1927:                                       ; preds = %entry
  %6 = load ptr, ptr %func.889, align 8
  %7 = getelementptr inbounds nuw %ASTNode, ptr %6, i32 0, i32 6
  %8 = load ptr, ptr %7, align 8
  %9 = call ptr @ptr_to_node(ptr %8)
  call void @collect_strings_block__Struct_ASTNode(ptr %9)
  br label %label_1929
}

define void @generate_module__Struct_ASTNode(ptr %0) {
entry:
  %module.890 = alloca ptr, align 8
  store ptr %0, ptr %module.890, align 8
  call void @ir_reset_globals()
  call void @ir_reset_types()
  call void @ir_clear_var_types()
  %1 = call ptr @ir_ptr_int_type__Void()
  call void @ir_set_pointer_int_type(ptr %1)
  %2 = load i1, ptr @ir_target_wasm, align 1
  %type_stmt_ptr.891 = alloca ptr, align 8
  %type_stmt.892 = alloca ptr, align 8
  %struct_stmt_ptr.893 = alloca ptr, align 8
  %struct_stmt.894 = alloca ptr, align 8
  %stmt_ptr.895 = alloca ptr, align 8
  %stmt.896 = alloca ptr, align 8
  %init_val.897 = alloca ptr, align 8
  %var_type.898 = alloca ptr, align 8
  %has_annotation.899 = alloca i1, align 1
  %type_node.900 = alloca ptr, align 8
  %init_node.901 = alloca ptr, align 8
  %ret_type.902 = alloca ptr, align 8
  %stmt_ptr2.903 = alloca ptr, align 8
  %stmt2.904 = alloca ptr, align 8
  br i1 %2, label %label_1930, label %label_1931

label_1931:                                       ; preds = %entry
  call void @ir_module_start(ptr @.str.s707)
  br label %label_1932

label_1930:                                       ; preds = %entry
  call void @ir_module_start_wasm(ptr @.str.s706)
  br label %label_1932

label_1932:                                       ; preds = %label_1931, %label_1930
  %3 = load ptr, ptr %module.890, align 8
  %4 = getelementptr inbounds nuw %ASTNode, ptr %3, i32 0, i32 5
  %5 = load ptr, ptr %4, align 8
  store ptr %5, ptr %type_stmt_ptr.891, align 8
  br label %label_1933

label_1933:                                       ; preds = %label_1941, %label_1932
  %6 = load ptr, ptr %type_stmt_ptr.891, align 8
  %7 = call i32 @str_equals(ptr %6, ptr @.str.s708)
  %8 = icmp eq i32 %7, 0
  br i1 %8, label %label_1934, label %label_1935

label_1935:                                       ; preds = %label_1933
  %9 = load ptr, ptr %module.890, align 8
  %10 = getelementptr inbounds nuw %ASTNode, ptr %9, i32 0, i32 5
  %11 = load ptr, ptr %10, align 8
  store ptr %11, ptr %struct_stmt_ptr.893, align 8
  br label %label_1942

label_1934:                                       ; preds = %label_1933
  %12 = load ptr, ptr %type_stmt_ptr.891, align 8
  %13 = call ptr @ptr_to_node(ptr %12)
  store ptr %13, ptr %type_stmt.892, align 8
  %14 = load ptr, ptr %type_stmt.892, align 8
  %15 = getelementptr inbounds nuw %ASTNode, ptr %14, i32 0, i32 0
  %16 = load i32, ptr %15, align 4
  %17 = icmp eq i32 %16, 6
  br i1 %17, label %label_1936, label %label_1938

label_1938:                                       ; preds = %label_1936, %label_1934
  %18 = load ptr, ptr %type_stmt.892, align 8
  %19 = getelementptr inbounds nuw %ASTNode, ptr %18, i32 0, i32 0
  %20 = load i32, ptr %19, align 4
  %21 = icmp eq i32 %20, 5
  br i1 %21, label %label_1939, label %label_1941

label_1936:                                       ; preds = %label_1934
  %22 = load ptr, ptr %type_stmt.892, align 8
  call void @register_enum_decl__Struct_ASTNode(ptr %22)
  br label %label_1938

label_1941:                                       ; preds = %label_1939, %label_1938
  %23 = load ptr, ptr %type_stmt.892, align 8
  %24 = getelementptr inbounds nuw %ASTNode, ptr %23, i32 0, i32 8
  %25 = load ptr, ptr %24, align 8
  store ptr %25, ptr %type_stmt_ptr.891, align 8
  br label %label_1933

label_1939:                                       ; preds = %label_1938
  %26 = load ptr, ptr %type_stmt.892, align 8
  call void @register_struct_name__Struct_ASTNode(ptr %26)
  br label %label_1941

label_1942:                                       ; preds = %label_1947, %label_1935
  %27 = load ptr, ptr %struct_stmt_ptr.893, align 8
  %28 = call i32 @str_equals(ptr %27, ptr @.str.s709)
  %29 = icmp eq i32 %28, 0
  br i1 %29, label %label_1943, label %label_1944

label_1944:                                       ; preds = %label_1942
  call void @ir_blank_line()
  call void @ir_global_var(ptr @.str.s710, ptr @.str.s711, ptr @.str.s712, i32 0)
  call void @ir_global_var(ptr @.str.s713, ptr @.str.s714, ptr @.str.s715, i32 0)
  call void @ir_declare_function_begin(ptr @.str.s716, ptr @.str.s717)
  %30 = call ptr @ir_ptr_int_type__Void()
  call void @ir_declare_function_param(ptr %30)
  call void @ir_declare_function_end()
  call void @ir_declare_function_begin(ptr @.str.s718, ptr @.str.s719)
  call void @ir_declare_function_param(ptr @.str.s720)
  call void @ir_declare_function_end()
  call void @ir_declare_function_begin(ptr @.str.s721, ptr @.str.s722)
  call void @ir_declare_function_end()
  call void @ir_declare_function_begin(ptr @.str.s723, ptr @.str.s724)
  call void @ir_declare_function_param(ptr @.str.s725)
  call void @ir_declare_function_param(ptr @.str.s726)
  call void @ir_declare_function_end()
  call void @ir_declare_function_begin(ptr @.str.s727, ptr @.str.s728)
  call void @ir_declare_function_param(ptr @.str.s729)
  call void @ir_declare_function_param(ptr @.str.s730)
  call void @ir_declare_function_end()
  call void @ir_declare_function_begin(ptr @.str.s731, ptr @.str.s732)
  call void @ir_declare_function_param(ptr @.str.s733)
  call void @ir_declare_function_param(ptr @.str.s734)
  call void @ir_declare_function_param(ptr @.str.s735)
  call void @ir_declare_function_end()
  call void @ir_declare_function_begin(ptr @.str.s736, ptr @.str.s737)
  call void @ir_declare_function_param(ptr @.str.s738)
  call void @ir_declare_function_end()
  call void @ir_declare_function_begin(ptr @.str.s739, ptr @.str.s740)
  call void @ir_declare_function_param(ptr @.str.s741)
  call void @ir_declare_function_end()
  call void @ir_declare_function_begin(ptr @.str.s742, ptr @.str.s743)
  call void @ir_declare_function_param(ptr @.str.s744)
  call void @ir_declare_function_end()
  call void @ir_declare_function_begin(ptr @.str.s745, ptr @.str.s746)
  call void @ir_declare_function_param(ptr @.str.s747)
  call void @ir_declare_function_end()
  call void @ir_declare_function_begin(ptr @.str.s748, ptr @.str.s749)
  call void @ir_declare_function_param(ptr @.str.s750)
  call void @ir_declare_function_end()
  call void @ir_declare_function_begin(ptr @.str.s751, ptr @.str.s752)
  call void @ir_declare_function_param(ptr @.str.s753)
  call void @ir_declare_function_end()
  call void @ir_declare_function_begin(ptr @.str.s754, ptr @.str.s755)
  call void @ir_declare_function_param(ptr @.str.s756)
  call void @ir_declare_function_end()
  call void @ir_declare_function_begin(ptr @.str.s757, ptr @.str.s758)
  call void @ir_declare_function_param(ptr @.str.s759)
  call void @ir_declare_function_end()
  call void @ir_declare_function_begin(ptr @.str.s760, ptr @.str.s761)
  call void @ir_declare_function_param(ptr @.str.s762)
  call void @ir_declare_function_end()
  call void @ir_declare_function_begin(ptr @.str.s763, ptr @.str.s764)
  call void @ir_declare_function_param(ptr @.str.s765)
  call void @ir_declare_function_end()
  call void @ir_declare_function_begin(ptr @.str.s766, ptr @.str.s767)
  call void @ir_declare_function_param(ptr @.str.s768)
  call void @ir_declare_function_end()
  call void @ir_blank_line()
  %31 = load ptr, ptr %module.890, align 8
  %32 = getelementptr inbounds nuw %ASTNode, ptr %31, i32 0, i32 5
  %33 = load ptr, ptr %32, align 8
  store ptr %33, ptr %stmt_ptr.895, align 8
  br label %label_1948

label_1943:                                       ; preds = %label_1942
  %34 = load ptr, ptr %struct_stmt_ptr.893, align 8
  %35 = call ptr @ptr_to_node(ptr %34)
  store ptr %35, ptr %struct_stmt.894, align 8
  %36 = load ptr, ptr %struct_stmt.894, align 8
  %37 = getelementptr inbounds nuw %ASTNode, ptr %36, i32 0, i32 0
  %38 = load i32, ptr %37, align 4
  %39 = icmp eq i32 %38, 5
  br i1 %39, label %label_1945, label %label_1947

label_1947:                                       ; preds = %label_1945, %label_1943
  %40 = load ptr, ptr %struct_stmt.894, align 8
  %41 = getelementptr inbounds nuw %ASTNode, ptr %40, i32 0, i32 8
  %42 = load ptr, ptr %41, align 8
  store ptr %42, ptr %struct_stmt_ptr.893, align 8
  br label %label_1942

label_1945:                                       ; preds = %label_1943
  %43 = load ptr, ptr %struct_stmt.894, align 8
  call void @generate_struct_decl__Struct_ASTNode(ptr %43)
  br label %label_1947

label_1948:                                       ; preds = %label_1977, %label_1944
  %44 = load ptr, ptr %stmt_ptr.895, align 8
  %45 = call i32 @str_equals(ptr %44, ptr @.str.s769)
  %46 = icmp eq i32 %45, 0
  br i1 %46, label %label_1949, label %label_1950

label_1950:                                       ; preds = %label_1948
  call void @ir_blank_line()
  %47 = load ptr, ptr %module.890, align 8
  %48 = getelementptr inbounds nuw %ASTNode, ptr %47, i32 0, i32 5
  %49 = load ptr, ptr %48, align 8
  store ptr %49, ptr %stmt_ptr2.903, align 8
  br label %label_1981

label_1949:                                       ; preds = %label_1948
  %50 = load ptr, ptr %stmt_ptr.895, align 8
  %51 = call ptr @ptr_to_node(ptr %50)
  store ptr %51, ptr %stmt.896, align 8
  %52 = load ptr, ptr %stmt.896, align 8
  %53 = getelementptr inbounds nuw %ASTNode, ptr %52, i32 0, i32 0
  %54 = load i32, ptr %53, align 4
  %55 = icmp eq i32 %54, 2
  br i1 %55, label %label_1951, label %label_1953

label_1953:                                       ; preds = %label_1956, %label_1949
  %56 = load ptr, ptr %stmt.896, align 8
  %57 = getelementptr inbounds nuw %ASTNode, ptr %56, i32 0, i32 0
  %58 = load i32, ptr %57, align 4
  %59 = icmp eq i32 %58, 3
  br i1 %59, label %label_1957, label %label_1959

label_1951:                                       ; preds = %label_1949
  %60 = load ptr, ptr %module.890, align 8
  %61 = load ptr, ptr %stmt.896, align 8
  %62 = getelementptr inbounds nuw %ASTNode, ptr %61, i32 0, i32 1
  %63 = load ptr, ptr %62, align 8
  %64 = call i1 @module_has_function__Struct_ASTNode_String(ptr %60, ptr %63)
  %65 = icmp eq i1 %64, false
  br i1 %65, label %label_1954, label %label_1956

label_1956:                                       ; preds = %label_1954, %label_1951
  br label %label_1953

label_1954:                                       ; preds = %label_1951
  %66 = load ptr, ptr %stmt.896, align 8
  call void @declare_extern_function__Struct_ASTNode(ptr %66)
  br label %label_1956

label_1959:                                       ; preds = %label_1965, %label_1953
  %67 = load ptr, ptr %stmt.896, align 8
  %68 = getelementptr inbounds nuw %ASTNode, ptr %67, i32 0, i32 0
  %69 = load i32, ptr %68, align 4
  %70 = icmp eq i32 %69, 4
  br i1 %70, label %label_1975, label %label_1977

label_1957:                                       ; preds = %label_1953
  store ptr @.str.s770, ptr %init_val.897, align 8
  store ptr @.str.s771, ptr %var_type.898, align 8
  %71 = load ptr, ptr %stmt.896, align 8
  %72 = getelementptr inbounds nuw %ASTNode, ptr %71, i32 0, i32 5
  %73 = load ptr, ptr %72, align 8
  %74 = call i32 @str_equals(ptr %73, ptr @.str.s772)
  %75 = icmp eq i32 %74, 0
  store i1 %75, ptr %has_annotation.899, align 1
  %76 = load i1, ptr %has_annotation.899, align 1
  br i1 %76, label %label_1960, label %label_1962

label_1962:                                       ; preds = %label_1960, %label_1957
  %77 = load ptr, ptr %stmt.896, align 8
  %78 = getelementptr inbounds nuw %ASTNode, ptr %77, i32 0, i32 6
  %79 = load ptr, ptr %78, align 8
  %80 = call i32 @str_equals(ptr %79, ptr @.str.s773)
  %81 = icmp eq i32 %80, 0
  br i1 %81, label %label_1963, label %label_1965

label_1960:                                       ; preds = %label_1957
  %82 = load ptr, ptr %stmt.896, align 8
  %83 = getelementptr inbounds nuw %ASTNode, ptr %82, i32 0, i32 5
  %84 = load ptr, ptr %83, align 8
  %85 = call ptr @ptr_to_node(ptr %84)
  store ptr %85, ptr %type_node.900, align 8
  %86 = load ptr, ptr %type_node.900, align 8
  %87 = call ptr @map_type_node__Struct_ASTNode(ptr %86)
  store ptr %87, ptr %var_type.898, align 8
  br label %label_1962

label_1965:                                       ; preds = %label_1971, %label_1962
  %88 = load ptr, ptr %stmt.896, align 8
  %89 = getelementptr inbounds nuw %ASTNode, ptr %88, i32 0, i32 1
  %90 = load ptr, ptr %89, align 8
  %91 = load ptr, ptr %var_type.898, align 8
  %92 = call ptr @storage_type__String(ptr %91)
  %93 = load ptr, ptr %init_val.897, align 8
  call void @ir_global_var(ptr %90, ptr %92, ptr %93, i32 0)
  %94 = load ptr, ptr %stmt.896, align 8
  %95 = getelementptr inbounds nuw %ASTNode, ptr %94, i32 0, i32 1
  %96 = load ptr, ptr %95, align 8
  call void @ir_register_global_name(ptr %96)
  %97 = load ptr, ptr %stmt.896, align 8
  %98 = getelementptr inbounds nuw %ASTNode, ptr %97, i32 0, i32 1
  %99 = load ptr, ptr %98, align 8
  %100 = load ptr, ptr %var_type.898, align 8
  call void @ir_set_global_var_type(ptr %99, ptr %100)
  br label %label_1959

label_1963:                                       ; preds = %label_1962
  %101 = load ptr, ptr %stmt.896, align 8
  %102 = getelementptr inbounds nuw %ASTNode, ptr %101, i32 0, i32 6
  %103 = load ptr, ptr %102, align 8
  %104 = call ptr @ptr_to_node(ptr %103)
  store ptr %104, ptr %init_node.901, align 8
  %105 = load i1, ptr %has_annotation.899, align 1
  %106 = icmp eq i1 %105, false
  br i1 %106, label %label_1966, label %label_1968

label_1968:                                       ; preds = %label_1966, %label_1963
  %107 = load ptr, ptr %init_node.901, align 8
  %108 = getelementptr inbounds nuw %ASTNode, ptr %107, i32 0, i32 0
  %109 = load i32, ptr %108, align 4
  %110 = icmp eq i32 %109, 22
  br i1 %110, label %label_1969, label %label_1970

label_1966:                                       ; preds = %label_1963
  %111 = load ptr, ptr %init_node.901, align 8
  %112 = call ptr @get_expr_type__Struct_ASTNode(ptr %111)
  store ptr %112, ptr %var_type.898, align 8
  br label %label_1968

label_1970:                                       ; preds = %label_1968
  call void @println(ptr @.str.s775)
  call void @exit(i32 1)
  br label %label_1971

label_1969:                                       ; preds = %label_1968
  %113 = load ptr, ptr %init_node.901, align 8
  %114 = getelementptr inbounds nuw %ASTNode, ptr %113, i32 0, i32 3
  %115 = load i32, ptr %114, align 4
  %116 = icmp eq i32 %115, 0
  br i1 %116, label %label_1972, label %label_1973

label_1973:                                       ; preds = %label_1969
  %117 = load ptr, ptr %init_node.901, align 8
  %118 = getelementptr inbounds nuw %ASTNode, ptr %117, i32 0, i32 1
  %119 = load ptr, ptr %118, align 8
  store ptr %119, ptr %init_val.897, align 8
  br label %label_1974

label_1972:                                       ; preds = %label_1969
  %120 = load ptr, ptr %init_node.901, align 8
  call void @collect_strings_expr__Struct_ASTNode(ptr %120)
  %121 = load ptr, ptr %init_node.901, align 8
  %122 = getelementptr inbounds nuw %ASTNode, ptr %121, i32 0, i32 2
  %123 = load ptr, ptr %122, align 8
  %124 = call ptr @str_concat(ptr @.str.s774, ptr %123)
  store ptr %124, ptr %init_val.897, align 8
  br label %label_1974

label_1974:                                       ; preds = %label_1973, %label_1972
  br label %label_1971

label_1971:                                       ; preds = %label_1970, %label_1974
  br label %label_1965

label_1977:                                       ; preds = %label_1980, %label_1959
  %125 = load ptr, ptr %stmt.896, align 8
  %126 = getelementptr inbounds nuw %ASTNode, ptr %125, i32 0, i32 8
  %127 = load ptr, ptr %126, align 8
  store ptr %127, ptr %stmt_ptr.895, align 8
  br label %label_1948

label_1975:                                       ; preds = %label_1959
  %128 = load ptr, ptr %stmt.896, align 8
  %129 = load ptr, ptr %stmt.896, align 8
  %130 = getelementptr inbounds nuw %ASTNode, ptr %129, i32 0, i32 7
  %131 = load ptr, ptr %130, align 8
  %132 = call ptr @get_declared_return_type__Struct_ASTNode_String(ptr %128, ptr %131)
  store ptr %132, ptr %ret_type.902, align 8
  %133 = load ptr, ptr %stmt.896, align 8
  %134 = getelementptr inbounds nuw %ASTNode, ptr %133, i32 0, i32 1
  %135 = load ptr, ptr %134, align 8
  %136 = call i32 @str_equals(ptr %135, ptr @.str.s776)
  %137 = icmp eq i32 %136, 1
  br i1 %137, label %label_1978, label %label_1980

label_1980:                                       ; preds = %label_1978, %label_1975
  %138 = load ptr, ptr %stmt.896, align 8
  %139 = call ptr @function_symbol_name__Struct_ASTNode(ptr %138)
  %140 = call ptr @fn_key__String(ptr %139)
  %141 = load ptr, ptr %ret_type.902, align 8
  call void @ir_set_var_type(ptr %140, ptr %141)
  %142 = load ptr, ptr %stmt.896, align 8
  call void @collect_strings_function__Struct_ASTNode(ptr %142)
  br label %label_1977

label_1978:                                       ; preds = %label_1975
  store ptr @.str.s777, ptr %ret_type.902, align 8
  br label %label_1980

label_1981:                                       ; preds = %label_1986, %label_1950
  %143 = load ptr, ptr %stmt_ptr2.903, align 8
  %144 = call i32 @str_equals(ptr %143, ptr @.str.s778)
  %145 = icmp eq i32 %144, 0
  br i1 %145, label %label_1982, label %label_1983

label_1983:                                       ; preds = %label_1981
  call void @ir_module_end()
  ret void

label_1982:                                       ; preds = %label_1981
  %146 = load ptr, ptr %stmt_ptr2.903, align 8
  %147 = call ptr @ptr_to_node(ptr %146)
  store ptr %147, ptr %stmt2.904, align 8
  %148 = load ptr, ptr %stmt2.904, align 8
  %149 = getelementptr inbounds nuw %ASTNode, ptr %148, i32 0, i32 0
  %150 = load i32, ptr %149, align 4
  %151 = icmp eq i32 %150, 4
  br i1 %151, label %label_1984, label %label_1986

label_1986:                                       ; preds = %label_1984, %label_1982
  %152 = load ptr, ptr %stmt2.904, align 8
  %153 = getelementptr inbounds nuw %ASTNode, ptr %152, i32 0, i32 8
  %154 = load ptr, ptr %153, align 8
  store ptr %154, ptr %stmt_ptr2.903, align 8
  br label %label_1981

label_1984:                                       ; preds = %label_1982
  %155 = load ptr, ptr %stmt2.904, align 8
  call void @generate_function__Struct_ASTNode(ptr %155)
  br label %label_1986
}

define i1 @sema_block_has_break__Struct_ASTNode(ptr %0) {
entry:
  %block.905 = alloca ptr, align 8
  store ptr %0, ptr %block.905, align 8
  %1 = load ptr, ptr %block.905, align 8
  %2 = getelementptr inbounds nuw %ASTNode, ptr %1, i32 0, i32 5
  %3 = load ptr, ptr %2, align 8
  %stmt_ptr.906 = alloca ptr, align 8
  store ptr %3, ptr %stmt_ptr.906, align 8
  %stmt.907 = alloca ptr, align 8
  %else_node.908 = alloca ptr, align 8
  %sc.107 = alloca i1, align 1
  %body.909 = alloca ptr, align 8
  %arm_ptr.910 = alloca ptr, align 8
  %arm.911 = alloca ptr, align 8
  br label %label_1987

label_1987:                                       ; preds = %label_2030, %entry
  %4 = load ptr, ptr %stmt_ptr.906, align 8
  %5 = call i32 @str_equals(ptr %4, ptr @.str.s779)
  %6 = icmp eq i32 %5, 0
  br i1 %6, label %label_1988, label %label_1989

label_1989:                                       ; preds = %label_1987
  ret i1 false

label_1988:                                       ; preds = %label_1987
  %7 = load ptr, ptr %stmt_ptr.906, align 8
  %8 = call ptr @ptr_to_node(ptr %7)
  store ptr %8, ptr %stmt.907, align 8
  %9 = load ptr, ptr %stmt.907, align 8
  %10 = getelementptr inbounds nuw %ASTNode, ptr %9, i32 0, i32 0
  %11 = load i32, ptr %10, align 4
  %12 = icmp eq i32 %11, 18
  br i1 %12, label %label_1990, label %label_1992

label_1992:                                       ; preds = %label_1988
  %13 = load ptr, ptr %stmt.907, align 8
  %14 = getelementptr inbounds nuw %ASTNode, ptr %13, i32 0, i32 0
  %15 = load i32, ptr %14, align 4
  %16 = icmp eq i32 %15, 10
  br i1 %16, label %label_1993, label %label_1995

label_1990:                                       ; preds = %label_1988
  ret i1 true

label_1995:                                       ; preds = %label_2001, %label_1992
  %17 = load ptr, ptr %stmt.907, align 8
  %18 = getelementptr inbounds nuw %ASTNode, ptr %17, i32 0, i32 0
  %19 = load i32, ptr %18, align 4
  %20 = icmp eq i32 %19, 13
  store i1 %20, ptr %sc.107, align 1
  br i1 %20, label %label_2012, label %label_2011

label_1993:                                       ; preds = %label_1992
  %21 = load ptr, ptr %stmt.907, align 8
  %22 = getelementptr inbounds nuw %ASTNode, ptr %21, i32 0, i32 6
  %23 = load ptr, ptr %22, align 8
  %24 = call ptr @ptr_to_node(ptr %23)
  %25 = call i1 @sema_block_has_break__Struct_ASTNode(ptr %24)
  br i1 %25, label %label_1996, label %label_1998

label_1998:                                       ; preds = %label_1993
  %26 = load ptr, ptr %stmt.907, align 8
  %27 = getelementptr inbounds nuw %ASTNode, ptr %26, i32 0, i32 7
  %28 = load ptr, ptr %27, align 8
  %29 = call i32 @str_equals(ptr %28, ptr @.str.s780)
  %30 = icmp eq i32 %29, 0
  br i1 %30, label %label_1999, label %label_2001

label_1996:                                       ; preds = %label_1993
  ret i1 true

label_2001:                                       ; preds = %label_2004, %label_1998
  br label %label_1995

label_1999:                                       ; preds = %label_1998
  %31 = load ptr, ptr %stmt.907, align 8
  %32 = getelementptr inbounds nuw %ASTNode, ptr %31, i32 0, i32 7
  %33 = load ptr, ptr %32, align 8
  %34 = call ptr @ptr_to_node(ptr %33)
  store ptr %34, ptr %else_node.908, align 8
  %35 = load ptr, ptr %else_node.908, align 8
  %36 = getelementptr inbounds nuw %ASTNode, ptr %35, i32 0, i32 0
  %37 = load i32, ptr %36, align 4
  %38 = icmp eq i32 %37, 10
  br i1 %38, label %label_2002, label %label_2003

label_2003:                                       ; preds = %label_1999
  %39 = load ptr, ptr %else_node.908, align 8
  %40 = call i1 @sema_block_has_break__Struct_ASTNode(ptr %39)
  br i1 %40, label %label_2008, label %label_2010

label_2002:                                       ; preds = %label_1999
  %41 = load ptr, ptr %else_node.908, align 8
  %42 = call i1 @sema_stmt_has_break_wrapper__Struct_ASTNode(ptr %41)
  br i1 %42, label %label_2005, label %label_2007

label_2007:                                       ; preds = %label_2002
  br label %label_2004

label_2005:                                       ; preds = %label_2002
  ret i1 true

label_2004:                                       ; preds = %label_2010, %label_2007
  br label %label_2001

label_2010:                                       ; preds = %label_2003
  br label %label_2004

label_2008:                                       ; preds = %label_2003
  ret i1 true

label_2011:                                       ; preds = %label_1995
  %43 = load ptr, ptr %stmt.907, align 8
  %44 = getelementptr inbounds nuw %ASTNode, ptr %43, i32 0, i32 0
  %45 = load i32, ptr %44, align 4
  %46 = icmp eq i32 %45, 14
  store i1 %46, ptr %sc.107, align 1
  br label %label_2012

label_2012:                                       ; preds = %label_2011, %label_1995
  %47 = load i1, ptr %sc.107, align 1
  br i1 %47, label %label_2013, label %label_2015

label_2015:                                       ; preds = %label_2021, %label_2012
  %48 = load ptr, ptr %stmt.907, align 8
  %49 = getelementptr inbounds nuw %ASTNode, ptr %48, i32 0, i32 0
  %50 = load i32, ptr %49, align 4
  %51 = icmp eq i32 %50, 12
  br i1 %51, label %label_2022, label %label_2024

label_2013:                                       ; preds = %label_2012
  %52 = load ptr, ptr %stmt.907, align 8
  %53 = getelementptr inbounds nuw %ASTNode, ptr %52, i32 0, i32 5
  %54 = load ptr, ptr %53, align 8
  %55 = call ptr @ptr_to_node(ptr %54)
  store ptr %55, ptr %body.909, align 8
  %56 = load ptr, ptr %stmt.907, align 8
  %57 = getelementptr inbounds nuw %ASTNode, ptr %56, i32 0, i32 0
  %58 = load i32, ptr %57, align 4
  %59 = icmp eq i32 %58, 13
  br i1 %59, label %label_2016, label %label_2018

label_2018:                                       ; preds = %label_2016, %label_2013
  %60 = load ptr, ptr %body.909, align 8
  %61 = call i1 @sema_block_has_break__Struct_ASTNode(ptr %60)
  br i1 %61, label %label_2019, label %label_2021

label_2016:                                       ; preds = %label_2013
  %62 = load ptr, ptr %stmt.907, align 8
  %63 = getelementptr inbounds nuw %ASTNode, ptr %62, i32 0, i32 6
  %64 = load ptr, ptr %63, align 8
  %65 = call ptr @ptr_to_node(ptr %64)
  store ptr %65, ptr %body.909, align 8
  br label %label_2018

label_2021:                                       ; preds = %label_2018
  br label %label_2015

label_2019:                                       ; preds = %label_2018
  ret i1 true

label_2024:                                       ; preds = %label_2027, %label_2015
  %66 = load ptr, ptr %stmt.907, align 8
  %67 = getelementptr inbounds nuw %ASTNode, ptr %66, i32 0, i32 0
  %68 = load i32, ptr %67, align 4
  %69 = icmp eq i32 %68, 11
  br i1 %69, label %label_2028, label %label_2030

label_2022:                                       ; preds = %label_2015
  %70 = load ptr, ptr %stmt.907, align 8
  %71 = getelementptr inbounds nuw %ASTNode, ptr %70, i32 0, i32 7
  %72 = load ptr, ptr %71, align 8
  %73 = call ptr @ptr_to_node(ptr %72)
  %74 = call i1 @sema_block_has_break__Struct_ASTNode(ptr %73)
  br i1 %74, label %label_2025, label %label_2027

label_2027:                                       ; preds = %label_2022
  br label %label_2024

label_2025:                                       ; preds = %label_2022
  ret i1 true

label_2030:                                       ; preds = %label_2033, %label_2024
  %75 = load ptr, ptr %stmt.907, align 8
  %76 = getelementptr inbounds nuw %ASTNode, ptr %75, i32 0, i32 8
  %77 = load ptr, ptr %76, align 8
  store ptr %77, ptr %stmt_ptr.906, align 8
  br label %label_1987

label_2028:                                       ; preds = %label_2024
  %78 = load ptr, ptr %stmt.907, align 8
  %79 = getelementptr inbounds nuw %ASTNode, ptr %78, i32 0, i32 6
  %80 = load ptr, ptr %79, align 8
  store ptr %80, ptr %arm_ptr.910, align 8
  br label %label_2031

label_2031:                                       ; preds = %label_2036, %label_2028
  %81 = load ptr, ptr %arm_ptr.910, align 8
  %82 = call i32 @str_equals(ptr %81, ptr @.str.s781)
  %83 = icmp eq i32 %82, 0
  br i1 %83, label %label_2032, label %label_2033

label_2033:                                       ; preds = %label_2031
  br label %label_2030

label_2032:                                       ; preds = %label_2031
  %84 = load ptr, ptr %arm_ptr.910, align 8
  %85 = call ptr @ptr_to_node(ptr %84)
  store ptr %85, ptr %arm.911, align 8
  %86 = load ptr, ptr %arm.911, align 8
  %87 = getelementptr inbounds nuw %ASTNode, ptr %86, i32 0, i32 6
  %88 = load ptr, ptr %87, align 8
  %89 = call ptr @ptr_to_node(ptr %88)
  %90 = call i1 @sema_block_has_break__Struct_ASTNode(ptr %89)
  br i1 %90, label %label_2034, label %label_2036

label_2036:                                       ; preds = %label_2032
  %91 = load ptr, ptr %arm.911, align 8
  %92 = getelementptr inbounds nuw %ASTNode, ptr %91, i32 0, i32 8
  %93 = load ptr, ptr %92, align 8
  store ptr %93, ptr %arm_ptr.910, align 8
  br label %label_2031

label_2034:                                       ; preds = %label_2032
  ret i1 true
}

define i1 @sema_stmt_has_break_wrapper__Struct_ASTNode(ptr %0) {
entry:
  %stmt.912 = alloca ptr, align 8
  store ptr %0, ptr %stmt.912, align 8
  %1 = load ptr, ptr %stmt.912, align 8
  %2 = getelementptr inbounds nuw %ASTNode, ptr %1, i32 0, i32 6
  %3 = load ptr, ptr %2, align 8
  %4 = call ptr @ptr_to_node(ptr %3)
  %5 = call i1 @sema_block_has_break__Struct_ASTNode(ptr %4)
  %else_node.913 = alloca ptr, align 8
  br i1 %5, label %label_2037, label %label_2039

label_2039:                                       ; preds = %entry
  %6 = load ptr, ptr %stmt.912, align 8
  %7 = getelementptr inbounds nuw %ASTNode, ptr %6, i32 0, i32 7
  %8 = load ptr, ptr %7, align 8
  %9 = call i32 @str_equals(ptr %8, ptr @.str.s782)
  %10 = icmp eq i32 %9, 0
  br i1 %10, label %label_2040, label %label_2042

label_2037:                                       ; preds = %entry
  ret i1 true

label_2042:                                       ; preds = %label_2039
  ret i1 false

label_2040:                                       ; preds = %label_2039
  %11 = load ptr, ptr %stmt.912, align 8
  %12 = getelementptr inbounds nuw %ASTNode, ptr %11, i32 0, i32 7
  %13 = load ptr, ptr %12, align 8
  %14 = call ptr @ptr_to_node(ptr %13)
  store ptr %14, ptr %else_node.913, align 8
  %15 = load ptr, ptr %else_node.913, align 8
  %16 = getelementptr inbounds nuw %ASTNode, ptr %15, i32 0, i32 0
  %17 = load i32, ptr %16, align 4
  %18 = icmp eq i32 %17, 10
  br i1 %18, label %label_2043, label %label_2045

label_2045:                                       ; preds = %label_2040
  %19 = load ptr, ptr %else_node.913, align 8
  %20 = call i1 @sema_block_has_break__Struct_ASTNode(ptr %19)
  ret i1 %20

label_2043:                                       ; preds = %label_2040
  %21 = load ptr, ptr %else_node.913, align 8
  %22 = call i1 @sema_stmt_has_break_wrapper__Struct_ASTNode(ptr %21)
  ret i1 %22
}

define i1 @sema_stmt_diverges__Struct_ASTNode(ptr %0) {
entry:
  %stmt.914 = alloca ptr, align 8
  store ptr %0, ptr %stmt.914, align 8
  %1 = load ptr, ptr %stmt.914, align 8
  %2 = getelementptr inbounds nuw %ASTNode, ptr %1, i32 0, i32 0
  %3 = load i32, ptr %2, align 4
  %4 = icmp eq i32 %3, 15
  %else_node.915 = alloca ptr, align 8
  %else_diverges.916 = alloca i1, align 1
  %sc.108 = alloca i1, align 1
  br i1 %4, label %label_2046, label %label_2048

label_2048:                                       ; preds = %entry
  %5 = load ptr, ptr %stmt.914, align 8
  %6 = getelementptr inbounds nuw %ASTNode, ptr %5, i32 0, i32 0
  %7 = load i32, ptr %6, align 4
  %8 = icmp eq i32 %7, 18
  br i1 %8, label %label_2049, label %label_2051

label_2046:                                       ; preds = %entry
  ret i1 true

label_2051:                                       ; preds = %label_2048
  %9 = load ptr, ptr %stmt.914, align 8
  %10 = getelementptr inbounds nuw %ASTNode, ptr %9, i32 0, i32 0
  %11 = load i32, ptr %10, align 4
  %12 = icmp eq i32 %11, 19
  br i1 %12, label %label_2052, label %label_2054

label_2049:                                       ; preds = %label_2048
  ret i1 true

label_2054:                                       ; preds = %label_2051
  %13 = load ptr, ptr %stmt.914, align 8
  %14 = getelementptr inbounds nuw %ASTNode, ptr %13, i32 0, i32 0
  %15 = load i32, ptr %14, align 4
  %16 = icmp eq i32 %15, 10
  br i1 %16, label %label_2055, label %label_2057

label_2052:                                       ; preds = %label_2051
  ret i1 true

label_2057:                                       ; preds = %label_2054
  %17 = load ptr, ptr %stmt.914, align 8
  %18 = getelementptr inbounds nuw %ASTNode, ptr %17, i32 0, i32 0
  %19 = load i32, ptr %18, align 4
  %20 = icmp eq i32 %19, 14
  br i1 %20, label %label_2066, label %label_2068

label_2055:                                       ; preds = %label_2054
  %21 = load ptr, ptr %stmt.914, align 8
  %22 = getelementptr inbounds nuw %ASTNode, ptr %21, i32 0, i32 7
  %23 = load ptr, ptr %22, align 8
  %24 = call i32 @str_equals(ptr %23, ptr @.str.s783)
  %25 = icmp eq i32 %24, 1
  br i1 %25, label %label_2058, label %label_2060

label_2060:                                       ; preds = %label_2055
  %26 = load ptr, ptr %stmt.914, align 8
  %27 = getelementptr inbounds nuw %ASTNode, ptr %26, i32 0, i32 7
  %28 = load ptr, ptr %27, align 8
  %29 = call ptr @ptr_to_node(ptr %28)
  store ptr %29, ptr %else_node.915, align 8
  store i1 false, ptr %else_diverges.916, align 1
  %30 = load ptr, ptr %else_node.915, align 8
  %31 = getelementptr inbounds nuw %ASTNode, ptr %30, i32 0, i32 0
  %32 = load i32, ptr %31, align 4
  %33 = icmp eq i32 %32, 10
  br i1 %33, label %label_2061, label %label_2062

label_2058:                                       ; preds = %label_2055
  ret i1 false

label_2062:                                       ; preds = %label_2060
  %34 = load ptr, ptr %else_node.915, align 8
  %35 = call i1 @sema_block_diverges__Struct_ASTNode(ptr %34)
  store i1 %35, ptr %else_diverges.916, align 1
  br label %label_2063

label_2061:                                       ; preds = %label_2060
  %36 = load ptr, ptr %else_node.915, align 8
  %37 = call i1 @sema_stmt_diverges__Struct_ASTNode(ptr %36)
  store i1 %37, ptr %else_diverges.916, align 1
  br label %label_2063

label_2063:                                       ; preds = %label_2062, %label_2061
  %38 = load ptr, ptr %stmt.914, align 8
  %39 = getelementptr inbounds nuw %ASTNode, ptr %38, i32 0, i32 6
  %40 = load ptr, ptr %39, align 8
  %41 = call ptr @ptr_to_node(ptr %40)
  %42 = call i1 @sema_block_diverges__Struct_ASTNode(ptr %41)
  store i1 %42, ptr %sc.108, align 1
  br i1 %42, label %label_2064, label %label_2065

label_2065:                                       ; preds = %label_2064, %label_2063
  %43 = load i1, ptr %sc.108, align 1
  ret i1 %43

label_2064:                                       ; preds = %label_2063
  %44 = load i1, ptr %else_diverges.916, align 1
  store i1 %44, ptr %sc.108, align 1
  br label %label_2065

label_2068:                                       ; preds = %label_2057
  ret i1 false

label_2066:                                       ; preds = %label_2057
  %45 = load ptr, ptr %stmt.914, align 8
  %46 = getelementptr inbounds nuw %ASTNode, ptr %45, i32 0, i32 5
  %47 = load ptr, ptr %46, align 8
  %48 = call ptr @ptr_to_node(ptr %47)
  %49 = call i1 @sema_block_has_break__Struct_ASTNode(ptr %48)
  %50 = icmp eq i1 %49, false
  ret i1 %50
}

define i1 @sema_block_diverges__Struct_ASTNode(ptr %0) {
entry:
  %block.917 = alloca ptr, align 8
  store ptr %0, ptr %block.917, align 8
  %1 = load ptr, ptr %block.917, align 8
  %2 = getelementptr inbounds nuw %ASTNode, ptr %1, i32 0, i32 5
  %3 = load ptr, ptr %2, align 8
  %stmt_ptr.918 = alloca ptr, align 8
  store ptr %3, ptr %stmt_ptr.918, align 8
  %stmt.919 = alloca ptr, align 8
  br label %label_2069

label_2069:                                       ; preds = %label_2074, %entry
  %4 = load ptr, ptr %stmt_ptr.918, align 8
  %5 = call i32 @str_equals(ptr %4, ptr @.str.s784)
  %6 = icmp eq i32 %5, 0
  br i1 %6, label %label_2070, label %label_2071

label_2071:                                       ; preds = %label_2069
  ret i1 false

label_2070:                                       ; preds = %label_2069
  %7 = load ptr, ptr %stmt_ptr.918, align 8
  %8 = call ptr @ptr_to_node(ptr %7)
  store ptr %8, ptr %stmt.919, align 8
  %9 = load ptr, ptr %stmt.919, align 8
  %10 = call i1 @sema_stmt_diverges__Struct_ASTNode(ptr %9)
  br i1 %10, label %label_2072, label %label_2074

label_2074:                                       ; preds = %label_2070
  %11 = load ptr, ptr %stmt.919, align 8
  %12 = getelementptr inbounds nuw %ASTNode, ptr %11, i32 0, i32 8
  %13 = load ptr, ptr %12, align 8
  store ptr %13, ptr %stmt_ptr.918, align 8
  br label %label_2069

label_2072:                                       ; preds = %label_2070
  ret i1 true
}

define ptr @sema_fn_key__String(ptr %0) {
entry:
  %name.920 = alloca ptr, align 8
  store ptr %0, ptr %name.920, align 8
  %1 = load ptr, ptr %name.920, align 8
  %2 = call ptr @str_concat(ptr @.str.s785, ptr %1)
  ret ptr %2
}

define ptr @sema_mangle_type__Struct_TypeInfo(ptr %0) {
entry:
  %t.921 = alloca ptr, align 8
  store ptr %0, ptr %t.921, align 8
  %1 = load ptr, ptr %t.921, align 8
  %2 = getelementptr inbounds nuw %TypeInfo, ptr %1, i32 0, i32 0
  %3 = load i32, ptr %2, align 4
  %4 = icmp eq i32 %3, 1
  br i1 %4, label %label_2075, label %label_2077

label_2077:                                       ; preds = %entry
  %5 = load ptr, ptr %t.921, align 8
  %6 = getelementptr inbounds nuw %TypeInfo, ptr %5, i32 0, i32 0
  %7 = load i32, ptr %6, align 4
  %8 = icmp eq i32 %7, 2
  br i1 %8, label %label_2078, label %label_2080

label_2075:                                       ; preds = %entry
  ret ptr @.str.s786

label_2080:                                       ; preds = %label_2077
  %9 = load ptr, ptr %t.921, align 8
  %10 = getelementptr inbounds nuw %TypeInfo, ptr %9, i32 0, i32 0
  %11 = load i32, ptr %10, align 4
  %12 = icmp eq i32 %11, 3
  br i1 %12, label %label_2081, label %label_2083

label_2078:                                       ; preds = %label_2077
  %13 = load ptr, ptr %t.921, align 8
  %14 = getelementptr inbounds nuw %TypeInfo, ptr %13, i32 0, i32 1
  %15 = load ptr, ptr %14, align 8
  ret ptr %15

label_2083:                                       ; preds = %label_2080
  %16 = load ptr, ptr %t.921, align 8
  %17 = getelementptr inbounds nuw %TypeInfo, ptr %16, i32 0, i32 0
  %18 = load i32, ptr %17, align 4
  %19 = icmp eq i32 %18, 4
  br i1 %19, label %label_2084, label %label_2086

label_2081:                                       ; preds = %label_2080
  ret ptr @.str.s787

label_2086:                                       ; preds = %label_2083
  %20 = load ptr, ptr %t.921, align 8
  %21 = getelementptr inbounds nuw %TypeInfo, ptr %20, i32 0, i32 0
  %22 = load i32, ptr %21, align 4
  %23 = icmp eq i32 %22, 5
  br i1 %23, label %label_2087, label %label_2089

label_2084:                                       ; preds = %label_2083
  ret ptr @.str.s788

label_2089:                                       ; preds = %label_2086
  %24 = load ptr, ptr %t.921, align 8
  %25 = getelementptr inbounds nuw %TypeInfo, ptr %24, i32 0, i32 0
  %26 = load i32, ptr %25, align 4
  %27 = icmp eq i32 %26, 6
  br i1 %27, label %label_2090, label %label_2092

label_2087:                                       ; preds = %label_2086
  ret ptr @.str.s789

label_2092:                                       ; preds = %label_2089
  %28 = load ptr, ptr %t.921, align 8
  %29 = getelementptr inbounds nuw %TypeInfo, ptr %28, i32 0, i32 0
  %30 = load i32, ptr %29, align 4
  %31 = icmp eq i32 %30, 7
  br i1 %31, label %label_2093, label %label_2095

label_2090:                                       ; preds = %label_2089
  ret ptr @.str.s790

label_2095:                                       ; preds = %label_2092
  %32 = load ptr, ptr %t.921, align 8
  %33 = getelementptr inbounds nuw %TypeInfo, ptr %32, i32 0, i32 0
  %34 = load i32, ptr %33, align 4
  %35 = icmp eq i32 %34, 8
  br i1 %35, label %label_2096, label %label_2098

label_2093:                                       ; preds = %label_2092
  ret ptr @.str.s791

label_2098:                                       ; preds = %label_2095
  %36 = load ptr, ptr %t.921, align 8
  %37 = getelementptr inbounds nuw %TypeInfo, ptr %36, i32 0, i32 0
  %38 = load i32, ptr %37, align 4
  %39 = icmp eq i32 %38, 9
  br i1 %39, label %label_2099, label %label_2101

label_2096:                                       ; preds = %label_2095
  %40 = load ptr, ptr %t.921, align 8
  %41 = getelementptr inbounds nuw %TypeInfo, ptr %40, i32 0, i32 1
  %42 = load ptr, ptr %41, align 8
  %43 = call ptr @str_concat(ptr @.str.s792, ptr %42)
  ret ptr %43

label_2101:                                       ; preds = %label_2098
  %44 = load ptr, ptr %t.921, align 8
  %45 = getelementptr inbounds nuw %TypeInfo, ptr %44, i32 0, i32 0
  %46 = load i32, ptr %45, align 4
  %47 = icmp eq i32 %46, 10
  br i1 %47, label %label_2102, label %label_2104

label_2099:                                       ; preds = %label_2098
  %48 = load ptr, ptr %t.921, align 8
  %49 = getelementptr inbounds nuw %TypeInfo, ptr %48, i32 0, i32 1
  %50 = load ptr, ptr %49, align 8
  %51 = call ptr @str_concat(ptr @.str.s793, ptr %50)
  ret ptr %51

label_2104:                                       ; preds = %label_2101
  %52 = load ptr, ptr %t.921, align 8
  %53 = getelementptr inbounds nuw %TypeInfo, ptr %52, i32 0, i32 0
  %54 = load i32, ptr %53, align 4
  %55 = icmp eq i32 %54, 11
  br i1 %55, label %label_2108, label %label_2110

label_2102:                                       ; preds = %label_2101
  %56 = load ptr, ptr %t.921, align 8
  %57 = getelementptr inbounds nuw %TypeInfo, ptr %56, i32 0, i32 3
  %58 = load ptr, ptr %57, align 8
  %59 = call i32 @str_equals(ptr %58, ptr @.str.s794)
  %60 = icmp eq i32 %59, 0
  br i1 %60, label %label_2105, label %label_2107

label_2107:                                       ; preds = %label_2102
  ret ptr @.str.s796

label_2105:                                       ; preds = %label_2102
  %61 = load ptr, ptr %t.921, align 8
  %62 = getelementptr inbounds nuw %TypeInfo, ptr %61, i32 0, i32 3
  %63 = load ptr, ptr %62, align 8
  %64 = call ptr @ptr_to_type(ptr %63)
  %65 = call ptr @sema_mangle_type__Struct_TypeInfo(ptr %64)
  %66 = call ptr @str_concat(ptr @.str.s795, ptr %65)
  ret ptr %66

label_2110:                                       ; preds = %label_2104
  ret ptr @.str.s800

label_2108:                                       ; preds = %label_2104
  %67 = load ptr, ptr %t.921, align 8
  %68 = getelementptr inbounds nuw %TypeInfo, ptr %67, i32 0, i32 3
  %69 = load ptr, ptr %68, align 8
  %70 = call i32 @str_equals(ptr %69, ptr @.str.s797)
  %71 = icmp eq i32 %70, 0
  br i1 %71, label %label_2111, label %label_2113

label_2113:                                       ; preds = %label_2108
  ret ptr @.str.s799

label_2111:                                       ; preds = %label_2108
  %72 = load ptr, ptr %t.921, align 8
  %73 = getelementptr inbounds nuw %TypeInfo, ptr %72, i32 0, i32 3
  %74 = load ptr, ptr %73, align 8
  %75 = call ptr @ptr_to_type(ptr %74)
  %76 = call ptr @sema_mangle_type__Struct_TypeInfo(ptr %75)
  %77 = call ptr @str_concat(ptr @.str.s798, ptr %76)
  ret ptr %77
}

define ptr @sema_param_signature__Struct_ASTNode_String(ptr %0, ptr %1) {
entry:
  %module.922 = alloca ptr, align 8
  store ptr %0, ptr %module.922, align 8
  %param_ptr.923 = alloca ptr, align 8
  store ptr %1, ptr %param_ptr.923, align 8
  %sig.924 = alloca ptr, align 8
  store ptr @.str.s801, ptr %sig.924, align 8
  %2 = load ptr, ptr %param_ptr.923, align 8
  %curr.925 = alloca ptr, align 8
  store ptr %2, ptr %curr.925, align 8
  %param.926 = alloca ptr, align 8
  %param_t.927 = alloca ptr, align 8
  br label %label_2114

label_2114:                                       ; preds = %label_2119, %entry
  %3 = load ptr, ptr %curr.925, align 8
  %4 = call i32 @str_equals(ptr %3, ptr @.str.s802)
  %5 = icmp eq i32 %4, 0
  br i1 %5, label %label_2115, label %label_2116

label_2116:                                       ; preds = %label_2114
  %6 = load ptr, ptr %sig.924, align 8
  %7 = call i32 @str_equals(ptr %6, ptr @.str.s805)
  %8 = icmp eq i32 %7, 1
  br i1 %8, label %label_2120, label %label_2122

label_2115:                                       ; preds = %label_2114
  %9 = load ptr, ptr %curr.925, align 8
  %10 = call ptr @ptr_to_node(ptr %9)
  store ptr %10, ptr %param.926, align 8
  %11 = load ptr, ptr %module.922, align 8
  %12 = load ptr, ptr %param.926, align 8
  %13 = getelementptr inbounds nuw %ASTNode, ptr %12, i32 0, i32 5
  %14 = load ptr, ptr %13, align 8
  %15 = call ptr @ptr_to_node(ptr %14)
  %16 = call ptr @sema_annotation_type__Struct_ASTNode_Struct_ASTNode(ptr %11, ptr %15)
  store ptr %16, ptr %param_t.927, align 8
  %17 = load ptr, ptr %sig.924, align 8
  %18 = call i32 @str_equals(ptr %17, ptr @.str.s803)
  %19 = icmp eq i32 %18, 1
  br i1 %19, label %label_2117, label %label_2118

label_2118:                                       ; preds = %label_2115
  %20 = load ptr, ptr %sig.924, align 8
  %21 = call ptr @str_concat(ptr %20, ptr @.str.s804)
  %22 = load ptr, ptr %param_t.927, align 8
  %23 = call ptr @sema_mangle_type__Struct_TypeInfo(ptr %22)
  %24 = call ptr @str_concat(ptr %21, ptr %23)
  store ptr %24, ptr %sig.924, align 8
  br label %label_2119

label_2117:                                       ; preds = %label_2115
  %25 = load ptr, ptr %param_t.927, align 8
  %26 = call ptr @sema_mangle_type__Struct_TypeInfo(ptr %25)
  store ptr %26, ptr %sig.924, align 8
  br label %label_2119

label_2119:                                       ; preds = %label_2118, %label_2117
  %27 = load ptr, ptr %param.926, align 8
  %28 = getelementptr inbounds nuw %ASTNode, ptr %27, i32 0, i32 8
  %29 = load ptr, ptr %28, align 8
  store ptr %29, ptr %curr.925, align 8
  br label %label_2114

label_2122:                                       ; preds = %label_2116
  %30 = load ptr, ptr %sig.924, align 8
  ret ptr %30

label_2120:                                       ; preds = %label_2116
  ret ptr @.str.s806
}

define ptr @sema_annotation_type__Struct_ASTNode_Struct_ASTNode(ptr %0, ptr %1) {
entry:
  %module.960 = alloca ptr, align 8
  store ptr %0, ptr %module.960, align 8
  %tn.961 = alloca ptr, align 8
  store ptr %1, ptr %tn.961, align 8
  %2 = load ptr, ptr %tn.961, align 8
  %3 = getelementptr inbounds nuw %ASTNode, ptr %2, i32 0, i32 3
  %4 = load i32, ptr %3, align 4
  %5 = icmp eq i32 %4, 1
  br i1 %5, label %label_2172, label %label_2174

label_2174:                                       ; preds = %entry
  %6 = load ptr, ptr %tn.961, align 8
  %7 = getelementptr inbounds nuw %ASTNode, ptr %6, i32 0, i32 4
  %8 = load i32, ptr %7, align 4
  %9 = icmp eq i32 %8, 1
  br i1 %9, label %label_2178, label %label_2180

label_2172:                                       ; preds = %entry
  %10 = load ptr, ptr %tn.961, align 8
  %11 = getelementptr inbounds nuw %ASTNode, ptr %10, i32 0, i32 5
  %12 = load ptr, ptr %11, align 8
  %13 = call i32 @str_equals(ptr %12, ptr @.str.s816)
  %14 = icmp eq i32 %13, 0
  br i1 %14, label %label_2175, label %label_2177

label_2177:                                       ; preds = %label_2172
  %15 = call ptr @type_invalid__Void()
  %16 = call ptr @type_array__Struct_TypeInfo(ptr %15)
  ret ptr %16

label_2175:                                       ; preds = %label_2172
  %17 = load ptr, ptr %module.960, align 8
  %18 = load ptr, ptr %tn.961, align 8
  %19 = getelementptr inbounds nuw %ASTNode, ptr %18, i32 0, i32 5
  %20 = load ptr, ptr %19, align 8
  %21 = call ptr @ptr_to_node(ptr %20)
  %22 = call ptr @sema_annotation_type__Struct_ASTNode_Struct_ASTNode(ptr %17, ptr %21)
  %23 = call ptr @type_array__Struct_TypeInfo(ptr %22)
  ret ptr %23

label_2180:                                       ; preds = %label_2174
  %24 = load ptr, ptr %tn.961, align 8
  %25 = getelementptr inbounds nuw %ASTNode, ptr %24, i32 0, i32 1
  %26 = load ptr, ptr %25, align 8
  %27 = call i32 @str_equals(ptr %26, ptr @.str.s818)
  %28 = icmp eq i32 %27, 1
  br i1 %28, label %label_2184, label %label_2186

label_2178:                                       ; preds = %label_2174
  %29 = load ptr, ptr %tn.961, align 8
  %30 = getelementptr inbounds nuw %ASTNode, ptr %29, i32 0, i32 5
  %31 = load ptr, ptr %30, align 8
  %32 = call i32 @str_equals(ptr %31, ptr @.str.s817)
  %33 = icmp eq i32 %32, 0
  br i1 %33, label %label_2181, label %label_2183

label_2183:                                       ; preds = %label_2178
  %34 = call ptr @type_invalid__Void()
  %35 = call ptr @type_list__Struct_TypeInfo(ptr %34)
  ret ptr %35

label_2181:                                       ; preds = %label_2178
  %36 = load ptr, ptr %module.960, align 8
  %37 = load ptr, ptr %tn.961, align 8
  %38 = getelementptr inbounds nuw %ASTNode, ptr %37, i32 0, i32 5
  %39 = load ptr, ptr %38, align 8
  %40 = call ptr @ptr_to_node(ptr %39)
  %41 = call ptr @sema_annotation_type__Struct_ASTNode_Struct_ASTNode(ptr %36, ptr %40)
  %42 = call ptr @type_list__Struct_TypeInfo(ptr %41)
  ret ptr %42

label_2186:                                       ; preds = %label_2180
  %43 = load ptr, ptr %tn.961, align 8
  %44 = getelementptr inbounds nuw %ASTNode, ptr %43, i32 0, i32 1
  %45 = load ptr, ptr %44, align 8
  %46 = call i32 @str_equals(ptr %45, ptr @.str.s819)
  %47 = icmp eq i32 %46, 1
  br i1 %47, label %label_2187, label %label_2189

label_2184:                                       ; preds = %label_2180
  %48 = call ptr @type_int__Void()
  ret ptr %48

label_2189:                                       ; preds = %label_2186
  %49 = load ptr, ptr %tn.961, align 8
  %50 = getelementptr inbounds nuw %ASTNode, ptr %49, i32 0, i32 1
  %51 = load ptr, ptr %50, align 8
  %52 = call i32 @str_equals(ptr %51, ptr @.str.s820)
  %53 = icmp eq i32 %52, 1
  br i1 %53, label %label_2190, label %label_2192

label_2187:                                       ; preds = %label_2186
  %54 = call ptr @type_float__Void()
  ret ptr %54

label_2192:                                       ; preds = %label_2189
  %55 = load ptr, ptr %tn.961, align 8
  %56 = getelementptr inbounds nuw %ASTNode, ptr %55, i32 0, i32 1
  %57 = load ptr, ptr %56, align 8
  %58 = call i32 @str_equals(ptr %57, ptr @.str.s821)
  %59 = icmp eq i32 %58, 1
  br i1 %59, label %label_2193, label %label_2195

label_2190:                                       ; preds = %label_2189
  %60 = call ptr @type_bool__Void()
  ret ptr %60

label_2195:                                       ; preds = %label_2192
  %61 = load ptr, ptr %tn.961, align 8
  %62 = getelementptr inbounds nuw %ASTNode, ptr %61, i32 0, i32 1
  %63 = load ptr, ptr %62, align 8
  %64 = call i32 @str_equals(ptr %63, ptr @.str.s822)
  %65 = icmp eq i32 %64, 1
  br i1 %65, label %label_2196, label %label_2198

label_2193:                                       ; preds = %label_2192
  %66 = call ptr @type_string__Void()
  ret ptr %66

label_2198:                                       ; preds = %label_2195
  %67 = load ptr, ptr %tn.961, align 8
  %68 = getelementptr inbounds nuw %ASTNode, ptr %67, i32 0, i32 1
  %69 = load ptr, ptr %68, align 8
  %70 = call i32 @str_equals(ptr %69, ptr @.str.s823)
  %71 = icmp eq i32 %70, 1
  br i1 %71, label %label_2199, label %label_2201

label_2196:                                       ; preds = %label_2195
  %72 = call ptr @type_char__Void()
  ret ptr %72

label_2201:                                       ; preds = %label_2198
  %73 = load ptr, ptr %tn.961, align 8
  %74 = getelementptr inbounds nuw %ASTNode, ptr %73, i32 0, i32 1
  %75 = load ptr, ptr %74, align 8
  %76 = call i32 @str_equals(ptr %75, ptr @.str.s824)
  %77 = icmp eq i32 %76, 1
  br i1 %77, label %label_2202, label %label_2204

label_2199:                                       ; preds = %label_2198
  %78 = call ptr @type_i8__Void()
  ret ptr %78

label_2204:                                       ; preds = %label_2201
  %79 = load ptr, ptr %tn.961, align 8
  %80 = getelementptr inbounds nuw %ASTNode, ptr %79, i32 0, i32 1
  %81 = load ptr, ptr %80, align 8
  %82 = call i32 @str_equals(ptr %81, ptr @.str.s825)
  %83 = icmp eq i32 %82, 1
  br i1 %83, label %label_2205, label %label_2207

label_2202:                                       ; preds = %label_2201
  %84 = call ptr @type_i16__Void()
  ret ptr %84

label_2207:                                       ; preds = %label_2204
  %85 = load ptr, ptr %tn.961, align 8
  %86 = getelementptr inbounds nuw %ASTNode, ptr %85, i32 0, i32 1
  %87 = load ptr, ptr %86, align 8
  %88 = call i32 @str_equals(ptr %87, ptr @.str.s826)
  %89 = icmp eq i32 %88, 1
  br i1 %89, label %label_2208, label %label_2210

label_2205:                                       ; preds = %label_2204
  %90 = call ptr @type_i64__Void()
  ret ptr %90

label_2210:                                       ; preds = %label_2207
  %91 = load ptr, ptr %tn.961, align 8
  %92 = getelementptr inbounds nuw %ASTNode, ptr %91, i32 0, i32 1
  %93 = load ptr, ptr %92, align 8
  %94 = call i32 @str_equals(ptr %93, ptr @.str.s827)
  %95 = icmp eq i32 %94, 1
  br i1 %95, label %label_2211, label %label_2213

label_2208:                                       ; preds = %label_2207
  %96 = call ptr @type_isize__Void()
  ret ptr %96

label_2213:                                       ; preds = %label_2210
  %97 = load ptr, ptr %tn.961, align 8
  %98 = getelementptr inbounds nuw %ASTNode, ptr %97, i32 0, i32 1
  %99 = load ptr, ptr %98, align 8
  %100 = call i32 @str_equals(ptr %99, ptr @.str.s828)
  %101 = icmp eq i32 %100, 1
  br i1 %101, label %label_2214, label %label_2216

label_2211:                                       ; preds = %label_2210
  %102 = call ptr @type_u8__Void()
  ret ptr %102

label_2216:                                       ; preds = %label_2213
  %103 = load ptr, ptr %tn.961, align 8
  %104 = getelementptr inbounds nuw %ASTNode, ptr %103, i32 0, i32 1
  %105 = load ptr, ptr %104, align 8
  %106 = call i32 @str_equals(ptr %105, ptr @.str.s829)
  %107 = icmp eq i32 %106, 1
  br i1 %107, label %label_2217, label %label_2219

label_2214:                                       ; preds = %label_2213
  %108 = call ptr @type_u16__Void()
  ret ptr %108

label_2219:                                       ; preds = %label_2216
  %109 = load ptr, ptr %tn.961, align 8
  %110 = getelementptr inbounds nuw %ASTNode, ptr %109, i32 0, i32 1
  %111 = load ptr, ptr %110, align 8
  %112 = call i32 @str_equals(ptr %111, ptr @.str.s830)
  %113 = icmp eq i32 %112, 1
  br i1 %113, label %label_2220, label %label_2222

label_2217:                                       ; preds = %label_2216
  %114 = call ptr @type_u32__Void()
  ret ptr %114

label_2222:                                       ; preds = %label_2219
  %115 = load ptr, ptr %tn.961, align 8
  %116 = getelementptr inbounds nuw %ASTNode, ptr %115, i32 0, i32 1
  %117 = load ptr, ptr %116, align 8
  %118 = call i32 @str_equals(ptr %117, ptr @.str.s831)
  %119 = icmp eq i32 %118, 1
  br i1 %119, label %label_2223, label %label_2225

label_2220:                                       ; preds = %label_2219
  %120 = call ptr @type_u64__Void()
  ret ptr %120

label_2225:                                       ; preds = %label_2222
  %121 = load ptr, ptr %tn.961, align 8
  %122 = getelementptr inbounds nuw %ASTNode, ptr %121, i32 0, i32 1
  %123 = load ptr, ptr %122, align 8
  %124 = call i32 @str_equals(ptr %123, ptr @.str.s832)
  %125 = icmp eq i32 %124, 1
  br i1 %125, label %label_2226, label %label_2228

label_2223:                                       ; preds = %label_2222
  %126 = call ptr @type_usize__Void()
  ret ptr %126

label_2228:                                       ; preds = %label_2225
  %127 = load ptr, ptr %module.960, align 8
  %128 = load ptr, ptr %tn.961, align 8
  %129 = getelementptr inbounds nuw %ASTNode, ptr %128, i32 0, i32 1
  %130 = load ptr, ptr %129, align 8
  %131 = call i1 @sema_has_enum__Struct_ASTNode_String(ptr %127, ptr %130)
  br i1 %131, label %label_2229, label %label_2231

label_2226:                                       ; preds = %label_2225
  %132 = call ptr @type_void__Void()
  ret ptr %132

label_2231:                                       ; preds = %label_2228
  %133 = load ptr, ptr %module.960, align 8
  %134 = load ptr, ptr %tn.961, align 8
  %135 = getelementptr inbounds nuw %ASTNode, ptr %134, i32 0, i32 1
  %136 = load ptr, ptr %135, align 8
  %137 = call i1 @sema_has_struct__Struct_ASTNode_String(ptr %133, ptr %136)
  br i1 %137, label %label_2232, label %label_2234

label_2229:                                       ; preds = %label_2228
  %138 = load ptr, ptr %tn.961, align 8
  %139 = getelementptr inbounds nuw %ASTNode, ptr %138, i32 0, i32 1
  %140 = load ptr, ptr %139, align 8
  %141 = call ptr @type_enum__String(ptr %140)
  ret ptr %141

label_2234:                                       ; preds = %label_2231
  %142 = load ptr, ptr %tn.961, align 8
  %143 = load ptr, ptr %tn.961, align 8
  %144 = getelementptr inbounds nuw %ASTNode, ptr %143, i32 0, i32 1
  %145 = load ptr, ptr %144, align 8
  %146 = call ptr @diag_quote__String(ptr %145)
  %147 = call ptr @str_concat(ptr @.str.s833, ptr %146)
  call void @sema_error_at__Struct_ASTNode_String(ptr %142, ptr %147)
  %148 = call ptr @type_invalid__Void()
  ret ptr %148

label_2232:                                       ; preds = %label_2231
  %149 = load ptr, ptr %tn.961, align 8
  %150 = getelementptr inbounds nuw %ASTNode, ptr %149, i32 0, i32 1
  %151 = load ptr, ptr %150, align 8
  %152 = call ptr @type_struct__String(ptr %151)
  ret ptr %152
}

define ptr @sema_function_symbol__Struct_ASTNode_Struct_ASTNode(ptr %0, ptr %1) {
entry:
  %module.928 = alloca ptr, align 8
  store ptr %0, ptr %module.928, align 8
  %fn_node.929 = alloca ptr, align 8
  store ptr %1, ptr %fn_node.929, align 8
  %2 = load ptr, ptr %fn_node.929, align 8
  %3 = getelementptr inbounds nuw %ASTNode, ptr %2, i32 0, i32 0
  %4 = load i32, ptr %3, align 4
  %5 = icmp eq i32 %4, 2
  br i1 %5, label %label_2123, label %label_2125

label_2125:                                       ; preds = %entry
  %6 = load ptr, ptr %fn_node.929, align 8
  %7 = getelementptr inbounds nuw %ASTNode, ptr %6, i32 0, i32 1
  %8 = load ptr, ptr %7, align 8
  %9 = call i32 @str_equals(ptr %8, ptr @.str.s807)
  %10 = icmp eq i32 %9, 1
  br i1 %10, label %label_2126, label %label_2128

label_2123:                                       ; preds = %entry
  %11 = load ptr, ptr %fn_node.929, align 8
  %12 = getelementptr inbounds nuw %ASTNode, ptr %11, i32 0, i32 1
  %13 = load ptr, ptr %12, align 8
  ret ptr %13

label_2128:                                       ; preds = %label_2125
  %14 = load ptr, ptr %fn_node.929, align 8
  %15 = getelementptr inbounds nuw %ASTNode, ptr %14, i32 0, i32 1
  %16 = load ptr, ptr %15, align 8
  %17 = call ptr @str_concat(ptr %16, ptr @.str.s809)
  %18 = load ptr, ptr %module.928, align 8
  %19 = load ptr, ptr %fn_node.929, align 8
  %20 = getelementptr inbounds nuw %ASTNode, ptr %19, i32 0, i32 5
  %21 = load ptr, ptr %20, align 8
  %22 = call ptr @sema_param_signature__Struct_ASTNode_String(ptr %18, ptr %21)
  %23 = call ptr @str_concat(ptr %17, ptr %22)
  ret ptr %23

label_2126:                                       ; preds = %label_2125
  ret ptr @.str.s808
}

define i32 @sema_function_symbol_count__Struct_ASTNode_String(ptr %0, ptr %1) {
entry:
  %module.930 = alloca ptr, align 8
  store ptr %0, ptr %module.930, align 8
  %symbol.931 = alloca ptr, align 8
  store ptr %1, ptr %symbol.931, align 8
  %count.932 = alloca i32, align 4
  store i32 0, ptr %count.932, align 4
  %2 = load ptr, ptr %module.930, align 8
  %3 = getelementptr inbounds nuw %ASTNode, ptr %2, i32 0, i32 5
  %4 = load ptr, ptr %3, align 8
  %stmt_ptr.933 = alloca ptr, align 8
  store ptr %4, ptr %stmt_ptr.933, align 8
  %stmt.934 = alloca ptr, align 8
  %sc.109 = alloca i1, align 1
  br label %label_2129

label_2129:                                       ; preds = %label_2136, %entry
  %5 = load ptr, ptr %stmt_ptr.933, align 8
  %6 = call i32 @str_equals(ptr %5, ptr @.str.s810)
  %7 = icmp eq i32 %6, 0
  br i1 %7, label %label_2130, label %label_2131

label_2131:                                       ; preds = %label_2129
  %8 = load i32, ptr %count.932, align 4
  ret i32 %8

label_2130:                                       ; preds = %label_2129
  %9 = load ptr, ptr %stmt_ptr.933, align 8
  %10 = call ptr @ptr_to_node(ptr %9)
  store ptr %10, ptr %stmt.934, align 8
  %11 = load ptr, ptr %stmt.934, align 8
  %12 = getelementptr inbounds nuw %ASTNode, ptr %11, i32 0, i32 0
  %13 = load i32, ptr %12, align 4
  %14 = icmp eq i32 %13, 4
  store i1 %14, ptr %sc.109, align 1
  br i1 %14, label %label_2133, label %label_2132

label_2132:                                       ; preds = %label_2130
  %15 = load ptr, ptr %stmt.934, align 8
  %16 = getelementptr inbounds nuw %ASTNode, ptr %15, i32 0, i32 0
  %17 = load i32, ptr %16, align 4
  %18 = icmp eq i32 %17, 2
  store i1 %18, ptr %sc.109, align 1
  br label %label_2133

label_2133:                                       ; preds = %label_2132, %label_2130
  %19 = load i1, ptr %sc.109, align 1
  br i1 %19, label %label_2134, label %label_2136

label_2136:                                       ; preds = %label_2139, %label_2133
  %20 = load ptr, ptr %stmt.934, align 8
  %21 = getelementptr inbounds nuw %ASTNode, ptr %20, i32 0, i32 8
  %22 = load ptr, ptr %21, align 8
  store ptr %22, ptr %stmt_ptr.933, align 8
  br label %label_2129

label_2134:                                       ; preds = %label_2133
  %23 = load ptr, ptr %stmt.934, align 8
  %24 = getelementptr inbounds nuw %ASTNode, ptr %23, i32 0, i32 2
  %25 = load ptr, ptr %24, align 8
  %26 = load ptr, ptr %symbol.931, align 8
  %27 = call i32 @str_equals(ptr %25, ptr %26)
  %28 = icmp eq i32 %27, 1
  br i1 %28, label %label_2137, label %label_2139

label_2139:                                       ; preds = %label_2137, %label_2134
  br label %label_2136

label_2137:                                       ; preds = %label_2134
  %29 = load i32, ptr %count.932, align 4
  %30 = add i32 %29, 1
  store i32 %30, ptr %count.932, align 4
  br label %label_2139
}

define void @sema_cache_function_symbols__Struct_ASTNode(ptr %0) {
entry:
  %module.935 = alloca ptr, align 8
  store ptr %0, ptr %module.935, align 8
  %1 = load ptr, ptr %module.935, align 8
  %2 = getelementptr inbounds nuw %ASTNode, ptr %1, i32 0, i32 5
  %3 = load ptr, ptr %2, align 8
  %stmt_ptr.936 = alloca ptr, align 8
  store ptr %3, ptr %stmt_ptr.936, align 8
  %stmt.937 = alloca ptr, align 8
  %sc.110 = alloca i1, align 1
  br label %label_2140

label_2140:                                       ; preds = %label_2147, %entry
  %4 = load ptr, ptr %stmt_ptr.936, align 8
  %5 = call i32 @str_equals(ptr %4, ptr @.str.s811)
  %6 = icmp eq i32 %5, 0
  br i1 %6, label %label_2141, label %label_2142

label_2142:                                       ; preds = %label_2140
  ret void

label_2141:                                       ; preds = %label_2140
  %7 = load ptr, ptr %stmt_ptr.936, align 8
  %8 = call ptr @ptr_to_node(ptr %7)
  store ptr %8, ptr %stmt.937, align 8
  %9 = load ptr, ptr %stmt.937, align 8
  %10 = getelementptr inbounds nuw %ASTNode, ptr %9, i32 0, i32 0
  %11 = load i32, ptr %10, align 4
  %12 = icmp eq i32 %11, 4
  store i1 %12, ptr %sc.110, align 1
  br i1 %12, label %label_2144, label %label_2143

label_2143:                                       ; preds = %label_2141
  %13 = load ptr, ptr %stmt.937, align 8
  %14 = getelementptr inbounds nuw %ASTNode, ptr %13, i32 0, i32 0
  %15 = load i32, ptr %14, align 4
  %16 = icmp eq i32 %15, 2
  store i1 %16, ptr %sc.110, align 1
  br label %label_2144

label_2144:                                       ; preds = %label_2143, %label_2141
  %17 = load i1, ptr %sc.110, align 1
  br i1 %17, label %label_2145, label %label_2147

label_2147:                                       ; preds = %label_2145, %label_2144
  %18 = load ptr, ptr %stmt.937, align 8
  %19 = getelementptr inbounds nuw %ASTNode, ptr %18, i32 0, i32 8
  %20 = load ptr, ptr %19, align 8
  store ptr %20, ptr %stmt_ptr.936, align 8
  br label %label_2140

label_2145:                                       ; preds = %label_2144
  %21 = load ptr, ptr %stmt.937, align 8
  %22 = load ptr, ptr %module.935, align 8
  %23 = load ptr, ptr %stmt.937, align 8
  %24 = call ptr @sema_function_symbol__Struct_ASTNode_Struct_ASTNode(ptr %22, ptr %23)
  %25 = getelementptr inbounds nuw %ASTNode, ptr %21, i32 0, i32 2
  store ptr %24, ptr %25, align 8
  br label %label_2147
}

define ptr @sema_overload_key__Struct_ASTNode_Struct_ASTNode(ptr %0, ptr %1) {
entry:
  %module.938 = alloca ptr, align 8
  store ptr %0, ptr %module.938, align 8
  %fn_node.939 = alloca ptr, align 8
  store ptr %1, ptr %fn_node.939, align 8
  %2 = load ptr, ptr %module.938, align 8
  %3 = load ptr, ptr %fn_node.939, align 8
  %4 = call ptr @sema_function_symbol__Struct_ASTNode_Struct_ASTNode(ptr %2, ptr %3)
  %5 = call ptr @sema_fn_key__String(ptr %4)
  ret ptr %5
}

define i1 @sema_same_position__Struct_ASTNode_Struct_ASTNode(ptr %0, ptr %1) {
entry:
  %a.940 = alloca ptr, align 8
  store ptr %0, ptr %a.940, align 8
  %b.941 = alloca ptr, align 8
  store ptr %1, ptr %b.941, align 8
  %sc.111 = alloca i1, align 1
  %sc.112 = alloca i1, align 1
  %2 = load ptr, ptr %a.940, align 8
  %3 = getelementptr inbounds nuw %ASTNode, ptr %2, i32 0, i32 13
  %4 = load i32, ptr %3, align 4
  %5 = load ptr, ptr %b.941, align 8
  %6 = getelementptr inbounds nuw %ASTNode, ptr %5, i32 0, i32 13
  %7 = load i32, ptr %6, align 4
  %8 = icmp eq i32 %4, %7
  store i1 %8, ptr %sc.112, align 1
  br i1 %8, label %label_2150, label %label_2151

label_2151:                                       ; preds = %label_2150, %entry
  %9 = load i1, ptr %sc.112, align 1
  store i1 %9, ptr %sc.111, align 1
  br i1 %9, label %label_2148, label %label_2149

label_2150:                                       ; preds = %entry
  %10 = load ptr, ptr %a.940, align 8
  %11 = getelementptr inbounds nuw %ASTNode, ptr %10, i32 0, i32 10
  %12 = load i32, ptr %11, align 4
  %13 = load ptr, ptr %b.941, align 8
  %14 = getelementptr inbounds nuw %ASTNode, ptr %13, i32 0, i32 10
  %15 = load i32, ptr %14, align 4
  %16 = icmp eq i32 %12, %15
  store i1 %16, ptr %sc.112, align 1
  br label %label_2151

label_2149:                                       ; preds = %label_2148, %label_2151
  %17 = load i1, ptr %sc.111, align 1
  ret i1 %17

label_2148:                                       ; preds = %label_2151
  %18 = load ptr, ptr %a.940, align 8
  %19 = getelementptr inbounds nuw %ASTNode, ptr %18, i32 0, i32 11
  %20 = load i32, ptr %19, align 4
  %21 = load ptr, ptr %b.941, align 8
  %22 = getelementptr inbounds nuw %ASTNode, ptr %21, i32 0, i32 11
  %23 = load i32, ptr %22, align 4
  %24 = icmp eq i32 %20, %23
  store i1 %24, ptr %sc.111, align 1
  br label %label_2149
}

define ptr @sema_first_function_with_symbol__Struct_ASTNode_String(ptr %0, ptr %1) {
entry:
  %module.942 = alloca ptr, align 8
  store ptr %0, ptr %module.942, align 8
  %symbol.943 = alloca ptr, align 8
  store ptr %1, ptr %symbol.943, align 8
  %2 = load ptr, ptr %module.942, align 8
  %3 = getelementptr inbounds nuw %ASTNode, ptr %2, i32 0, i32 5
  %4 = load ptr, ptr %3, align 8
  %stmt_ptr.944 = alloca ptr, align 8
  store ptr %4, ptr %stmt_ptr.944, align 8
  %stmt.945 = alloca ptr, align 8
  %sc.113 = alloca i1, align 1
  br label %label_2152

label_2152:                                       ; preds = %label_2159, %entry
  %5 = load ptr, ptr %stmt_ptr.944, align 8
  %6 = call i32 @str_equals(ptr %5, ptr @.str.s812)
  %7 = icmp eq i32 %6, 0
  br i1 %7, label %label_2153, label %label_2154

label_2154:                                       ; preds = %label_2152
  %8 = call ptr @create_node__Enum_NodeKind(i32 0)
  ret ptr %8

label_2153:                                       ; preds = %label_2152
  %9 = load ptr, ptr %stmt_ptr.944, align 8
  %10 = call ptr @ptr_to_node(ptr %9)
  store ptr %10, ptr %stmt.945, align 8
  %11 = load ptr, ptr %stmt.945, align 8
  %12 = getelementptr inbounds nuw %ASTNode, ptr %11, i32 0, i32 0
  %13 = load i32, ptr %12, align 4
  %14 = icmp eq i32 %13, 4
  store i1 %14, ptr %sc.113, align 1
  br i1 %14, label %label_2156, label %label_2155

label_2155:                                       ; preds = %label_2153
  %15 = load ptr, ptr %stmt.945, align 8
  %16 = getelementptr inbounds nuw %ASTNode, ptr %15, i32 0, i32 0
  %17 = load i32, ptr %16, align 4
  %18 = icmp eq i32 %17, 2
  store i1 %18, ptr %sc.113, align 1
  br label %label_2156

label_2156:                                       ; preds = %label_2155, %label_2153
  %19 = load i1, ptr %sc.113, align 1
  br i1 %19, label %label_2157, label %label_2159

label_2159:                                       ; preds = %label_2162, %label_2156
  %20 = load ptr, ptr %stmt.945, align 8
  %21 = getelementptr inbounds nuw %ASTNode, ptr %20, i32 0, i32 8
  %22 = load ptr, ptr %21, align 8
  store ptr %22, ptr %stmt_ptr.944, align 8
  br label %label_2152

label_2157:                                       ; preds = %label_2156
  %23 = load ptr, ptr %stmt.945, align 8
  %24 = getelementptr inbounds nuw %ASTNode, ptr %23, i32 0, i32 2
  %25 = load ptr, ptr %24, align 8
  %26 = load ptr, ptr %symbol.943, align 8
  %27 = call i32 @str_equals(ptr %25, ptr %26)
  %28 = icmp eq i32 %27, 1
  br i1 %28, label %label_2160, label %label_2162

label_2162:                                       ; preds = %label_2157
  br label %label_2159

label_2160:                                       ; preds = %label_2157
  %29 = load ptr, ptr %stmt.945, align 8
  ret ptr %29
}

define void @sema_error_at__Struct_ASTNode_String(ptr %0, ptr %1) {
entry:
  %node.946 = alloca ptr, align 8
  store ptr %0, ptr %node.946, align 8
  %message.947 = alloca ptr, align 8
  store ptr %1, ptr %message.947, align 8
  %2 = load ptr, ptr %node.946, align 8
  %3 = getelementptr inbounds nuw %ASTNode, ptr %2, i32 0, i32 13
  %4 = load i32, ptr %3, align 4
  %5 = load ptr, ptr %node.946, align 8
  %6 = getelementptr inbounds nuw %ASTNode, ptr %5, i32 0, i32 10
  %7 = load i32, ptr %6, align 4
  %8 = load ptr, ptr %node.946, align 8
  %9 = getelementptr inbounds nuw %ASTNode, ptr %8, i32 0, i32 11
  %10 = load i32, ptr %9, align 4
  %11 = load ptr, ptr %node.946, align 8
  %12 = getelementptr inbounds nuw %ASTNode, ptr %11, i32 0, i32 12
  %13 = load i32, ptr %12, align 4
  %14 = load ptr, ptr %message.947, align 8
  call void @diag_error_at(i32 %4, i32 %7, i32 %10, i32 %13, ptr %14)
  ret void
}

define void @sema_error__String(ptr %0) {
entry:
  %message.948 = alloca ptr, align 8
  store ptr %0, ptr %message.948, align 8
  %1 = load ptr, ptr %message.948, align 8
  call void @diag_error(ptr %1)
  ret void
}

define void @sema_type_error_at__Struct_ASTNode_String_Struct_TypeInfo_Struct_TypeInfo(ptr %0, ptr %1, ptr %2, ptr %3) {
entry:
  %node.949 = alloca ptr, align 8
  store ptr %0, ptr %node.949, align 8
  %context.950 = alloca ptr, align 8
  store ptr %1, ptr %context.950, align 8
  %expected.951 = alloca ptr, align 8
  store ptr %2, ptr %expected.951, align 8
  %actual.952 = alloca ptr, align 8
  store ptr %3, ptr %actual.952, align 8
  %4 = load ptr, ptr %node.949, align 8
  %5 = load ptr, ptr %context.950, align 8
  %6 = call ptr @str_concat(ptr %5, ptr @.str.s813)
  %7 = load ptr, ptr %expected.951, align 8
  %8 = call ptr @type_display__Struct_TypeInfo(ptr %7)
  %9 = load ptr, ptr %actual.952, align 8
  %10 = call ptr @type_display__Struct_TypeInfo(ptr %9)
  %11 = call ptr @str_concat(ptr @.str.s814, ptr %10)
  %12 = call ptr @str_concat(ptr %8, ptr %11)
  %13 = call ptr @str_concat(ptr %6, ptr %12)
  call void @sema_error_at__Struct_ASTNode_String(ptr %4, ptr %13)
  ret void
}

define i1 @sema_has_struct__Struct_ASTNode_String(ptr %0, ptr %1) {
entry:
  %module.953 = alloca ptr, align 8
  store ptr %0, ptr %module.953, align 8
  %name.954 = alloca ptr, align 8
  store ptr %1, ptr %name.954, align 8
  %2 = load ptr, ptr %name.954, align 8
  %3 = call i32 @ir_named_type_kind(ptr %2)
  %4 = icmp eq i32 %3, 1
  ret i1 %4
}

define i1 @sema_has_enum__Struct_ASTNode_String(ptr %0, ptr %1) {
entry:
  %module.955 = alloca ptr, align 8
  store ptr %0, ptr %module.955, align 8
  %name.956 = alloca ptr, align 8
  store ptr %1, ptr %name.956, align 8
  %2 = load ptr, ptr %name.956, align 8
  %3 = call i32 @ir_named_type_kind(ptr %2)
  %4 = icmp eq i32 %3, 2
  ret i1 %4
}

define void @sema_register_named_types__Struct_ASTNode(ptr %0) {
entry:
  %module.957 = alloca ptr, align 8
  store ptr %0, ptr %module.957, align 8
  call void @ir_reset_named_types()
  %1 = load ptr, ptr %module.957, align 8
  %2 = getelementptr inbounds nuw %ASTNode, ptr %1, i32 0, i32 5
  %3 = load ptr, ptr %2, align 8
  %stmt_ptr.958 = alloca ptr, align 8
  store ptr %3, ptr %stmt_ptr.958, align 8
  %stmt.959 = alloca ptr, align 8
  br label %label_2163

label_2163:                                       ; preds = %label_2171, %entry
  %4 = load ptr, ptr %stmt_ptr.958, align 8
  %5 = call i32 @str_equals(ptr %4, ptr @.str.s815)
  %6 = icmp eq i32 %5, 0
  br i1 %6, label %label_2164, label %label_2165

label_2165:                                       ; preds = %label_2163
  ret void

label_2164:                                       ; preds = %label_2163
  %7 = load ptr, ptr %stmt_ptr.958, align 8
  %8 = call ptr @ptr_to_node(ptr %7)
  store ptr %8, ptr %stmt.959, align 8
  %9 = load ptr, ptr %stmt.959, align 8
  %10 = getelementptr inbounds nuw %ASTNode, ptr %9, i32 0, i32 0
  %11 = load i32, ptr %10, align 4
  %12 = icmp eq i32 %11, 5
  br i1 %12, label %label_2166, label %label_2168

label_2168:                                       ; preds = %label_2166, %label_2164
  %13 = load ptr, ptr %stmt.959, align 8
  %14 = getelementptr inbounds nuw %ASTNode, ptr %13, i32 0, i32 0
  %15 = load i32, ptr %14, align 4
  %16 = icmp eq i32 %15, 6
  br i1 %16, label %label_2169, label %label_2171

label_2166:                                       ; preds = %label_2164
  %17 = load ptr, ptr %stmt.959, align 8
  %18 = getelementptr inbounds nuw %ASTNode, ptr %17, i32 0, i32 1
  %19 = load ptr, ptr %18, align 8
  call void @ir_declare_named_type(ptr %19, i32 1)
  br label %label_2168

label_2171:                                       ; preds = %label_2169, %label_2168
  %20 = load ptr, ptr %stmt.959, align 8
  %21 = getelementptr inbounds nuw %ASTNode, ptr %20, i32 0, i32 8
  %22 = load ptr, ptr %21, align 8
  store ptr %22, ptr %stmt_ptr.958, align 8
  br label %label_2163

label_2169:                                       ; preds = %label_2168
  %23 = load ptr, ptr %stmt.959, align 8
  %24 = getelementptr inbounds nuw %ASTNode, ptr %23, i32 0, i32 1
  %25 = load ptr, ptr %24, align 8
  call void @ir_declare_named_type(ptr %25, i32 2)
  br label %label_2171
}

define ptr @sema_declared_return_type__Struct_ASTNode_String(ptr %0, ptr %1) {
entry:
  %module.962 = alloca ptr, align 8
  store ptr %0, ptr %module.962, align 8
  %ret_child.963 = alloca ptr, align 8
  store ptr %1, ptr %ret_child.963, align 8
  %2 = load ptr, ptr %ret_child.963, align 8
  %3 = call i32 @str_equals(ptr %2, ptr @.str.s834)
  %4 = icmp eq i32 %3, 0
  br i1 %4, label %label_2235, label %label_2237

label_2237:                                       ; preds = %entry
  %5 = call ptr @type_void__Void()
  ret ptr %5

label_2235:                                       ; preds = %entry
  %6 = load ptr, ptr %module.962, align 8
  %7 = load ptr, ptr %ret_child.963, align 8
  %8 = call ptr @ptr_to_node(ptr %7)
  %9 = call ptr @sema_annotation_type__Struct_ASTNode_Struct_ASTNode(ptr %6, ptr %8)
  ret ptr %9
}

define i1 @sema_enum_matches_int__Struct_TypeInfo_Struct_TypeInfo(ptr %0, ptr %1) {
entry:
  %a.964 = alloca ptr, align 8
  store ptr %0, ptr %a.964, align 8
  %b.965 = alloca ptr, align 8
  store ptr %1, ptr %b.965, align 8
  %2 = load ptr, ptr %a.964, align 8
  %3 = getelementptr inbounds nuw %TypeInfo, ptr %2, i32 0, i32 0
  %4 = load i32, ptr %3, align 4
  %5 = icmp ne i32 %4, 9
  br i1 %5, label %label_2238, label %label_2240

label_2240:                                       ; preds = %entry
  %6 = load ptr, ptr %b.965, align 8
  %7 = getelementptr inbounds nuw %TypeInfo, ptr %6, i32 0, i32 0
  %8 = load i32, ptr %7, align 4
  %9 = icmp ne i32 %8, 2
  br i1 %9, label %label_2241, label %label_2243

label_2238:                                       ; preds = %entry
  ret i1 false

label_2243:                                       ; preds = %label_2240
  %10 = load ptr, ptr %b.965, align 8
  %11 = getelementptr inbounds nuw %TypeInfo, ptr %10, i32 0, i32 1
  %12 = load ptr, ptr %11, align 8
  %13 = call i32 @str_equals(ptr %12, ptr @.str.s835)
  %14 = icmp eq i32 %13, 1
  ret i1 %14

label_2241:                                       ; preds = %label_2240
  ret i1 false
}

define i1 @sema_types_match__Struct_TypeInfo_Struct_TypeInfo(ptr %0, ptr %1) {
entry:
  %expected.966 = alloca ptr, align 8
  store ptr %0, ptr %expected.966, align 8
  %actual.967 = alloca ptr, align 8
  store ptr %1, ptr %actual.967, align 8
  %2 = load ptr, ptr %expected.966, align 8
  %3 = load ptr, ptr %actual.967, align 8
  %4 = call i1 @type_equals__Struct_TypeInfo_Struct_TypeInfo(ptr %2, ptr %3)
  br i1 %4, label %label_2244, label %label_2246

label_2246:                                       ; preds = %entry
  %5 = load ptr, ptr %expected.966, align 8
  %6 = load ptr, ptr %actual.967, align 8
  %7 = call i1 @sema_enum_matches_int__Struct_TypeInfo_Struct_TypeInfo(ptr %5, ptr %6)
  br i1 %7, label %label_2247, label %label_2249

label_2244:                                       ; preds = %entry
  ret i1 true

label_2249:                                       ; preds = %label_2246
  %8 = load ptr, ptr %actual.967, align 8
  %9 = load ptr, ptr %expected.966, align 8
  %10 = call i1 @sema_enum_matches_int__Struct_TypeInfo_Struct_TypeInfo(ptr %8, ptr %9)
  br i1 %10, label %label_2250, label %label_2252

label_2247:                                       ; preds = %label_2246
  ret i1 true

label_2252:                                       ; preds = %label_2249
  ret i1 false

label_2250:                                       ; preds = %label_2249
  ret i1 true
}

define void @sema_expect_assignable__Struct_ASTNode_String_Struct_TypeInfo_Struct_TypeInfo(ptr %0, ptr %1, ptr %2, ptr %3) {
entry:
  %node.968 = alloca ptr, align 8
  store ptr %0, ptr %node.968, align 8
  %context.969 = alloca ptr, align 8
  store ptr %1, ptr %context.969, align 8
  %expected.970 = alloca ptr, align 8
  store ptr %2, ptr %expected.970, align 8
  %actual.971 = alloca ptr, align 8
  store ptr %3, ptr %actual.971, align 8
  %sc.114 = alloca i1, align 1
  %4 = load ptr, ptr %expected.970, align 8
  %5 = call i1 @type_is_valid__Struct_TypeInfo(ptr %4)
  %6 = icmp eq i1 %5, false
  store i1 %6, ptr %sc.114, align 1
  br i1 %6, label %label_2254, label %label_2253

label_2253:                                       ; preds = %entry
  %7 = load ptr, ptr %actual.971, align 8
  %8 = call i1 @type_is_valid__Struct_TypeInfo(ptr %7)
  %9 = icmp eq i1 %8, false
  store i1 %9, ptr %sc.114, align 1
  br label %label_2254

label_2254:                                       ; preds = %label_2253, %entry
  %10 = load i1, ptr %sc.114, align 1
  br i1 %10, label %label_2255, label %label_2257

label_2257:                                       ; preds = %label_2254
  %11 = load ptr, ptr %expected.970, align 8
  %12 = load ptr, ptr %actual.971, align 8
  %13 = call i1 @sema_types_match__Struct_TypeInfo_Struct_TypeInfo(ptr %11, ptr %12)
  %14 = icmp eq i1 %13, false
  br i1 %14, label %label_2258, label %label_2260

label_2255:                                       ; preds = %label_2254
  ret void

label_2260:                                       ; preds = %label_2258, %label_2257
  ret void

label_2258:                                       ; preds = %label_2257
  %15 = load ptr, ptr %node.968, align 8
  %16 = load ptr, ptr %context.969, align 8
  %17 = load ptr, ptr %expected.970, align 8
  %18 = load ptr, ptr %actual.971, align 8
  call void @sema_type_error_at__Struct_ASTNode_String_Struct_TypeInfo_Struct_TypeInfo(ptr %15, ptr %16, ptr %17, ptr %18)
  br label %label_2260
}

define i1 @sema_is_int_literal__Struct_ASTNode(ptr %0) {
entry:
  %e.972 = alloca ptr, align 8
  store ptr %0, ptr %e.972, align 8
  %sc.115 = alloca i1, align 1
  %1 = load ptr, ptr %e.972, align 8
  %2 = getelementptr inbounds nuw %ASTNode, ptr %1, i32 0, i32 0
  %3 = load i32, ptr %2, align 4
  %4 = icmp eq i32 %3, 22
  store i1 %4, ptr %sc.115, align 1
  br i1 %4, label %label_2261, label %label_2262

label_2262:                                       ; preds = %label_2261, %entry
  %5 = load i1, ptr %sc.115, align 1
  ret i1 %5

label_2261:                                       ; preds = %entry
  %6 = load ptr, ptr %e.972, align 8
  %7 = getelementptr inbounds nuw %ASTNode, ptr %6, i32 0, i32 3
  %8 = load i32, ptr %7, align 4
  %9 = icmp eq i32 %8, 2
  store i1 %9, ptr %sc.115, align 1
  br label %label_2262
}

define void @sema_move_operand__Struct_ASTNode(ptr %0) {
entry:
  %node.973 = alloca ptr, align 8
  store ptr %0, ptr %node.973, align 8
  %1 = load ptr, ptr %node.973, align 8
  %2 = getelementptr inbounds nuw %ASTNode, ptr %1, i32 0, i32 0
  %3 = load i32, ptr %2, align 4
  %4 = icmp eq i32 %3, 23
  br i1 %4, label %label_2263, label %label_2265

label_2265:                                       ; preds = %label_2268, %entry
  ret void

label_2263:                                       ; preds = %entry
  %5 = load ptr, ptr %node.973, align 8
  %6 = call ptr @node_get_type__Struct_ASTNode(ptr %5)
  %7 = call i1 @type_is_move_only__Struct_TypeInfo(ptr %6)
  br i1 %7, label %label_2266, label %label_2268

label_2268:                                       ; preds = %label_2274, %label_2263
  br label %label_2265

label_2266:                                       ; preds = %label_2263
  %8 = load ptr, ptr %node.973, align 8
  %9 = getelementptr inbounds nuw %ASTNode, ptr %8, i32 0, i32 1
  %10 = load ptr, ptr %9, align 8
  %11 = call i32 @ir_is_borrowed(ptr %10)
  %12 = icmp eq i32 %11, 1
  br i1 %12, label %label_2269, label %label_2271

label_2271:                                       ; preds = %label_2269, %label_2266
  %13 = load ptr, ptr %node.973, align 8
  %14 = getelementptr inbounds nuw %ASTNode, ptr %13, i32 0, i32 1
  %15 = load ptr, ptr %14, align 8
  %16 = call i32 @ir_binding_predates_loop(ptr %15)
  %17 = icmp eq i32 %16, 1
  br i1 %17, label %label_2272, label %label_2274

label_2269:                                       ; preds = %label_2266
  %18 = load ptr, ptr %node.973, align 8
  %19 = load ptr, ptr %node.973, align 8
  %20 = getelementptr inbounds nuw %ASTNode, ptr %19, i32 0, i32 1
  %21 = load ptr, ptr %20, align 8
  %22 = call ptr @diag_quote__String(ptr %21)
  %23 = call ptr @str_concat(ptr @.str.s836, ptr %22)
  call void @sema_error_at__Struct_ASTNode_String(ptr %18, ptr %23)
  br label %label_2271

label_2274:                                       ; preds = %label_2272, %label_2271
  %24 = load ptr, ptr %node.973, align 8
  %25 = getelementptr inbounds nuw %ASTNode, ptr %24, i32 0, i32 1
  %26 = load ptr, ptr %25, align 8
  call void @ir_mark_moved(ptr %26)
  br label %label_2268

label_2272:                                       ; preds = %label_2271
  %27 = load ptr, ptr %node.973, align 8
  %28 = load ptr, ptr %node.973, align 8
  %29 = getelementptr inbounds nuw %ASTNode, ptr %28, i32 0, i32 1
  %30 = load ptr, ptr %29, align 8
  %31 = call ptr @diag_quote__String(ptr %30)
  %32 = call ptr @str_concat(ptr %31, ptr @.str.s837)
  call void @sema_error_at__Struct_ASTNode_String(ptr %27, ptr %32)
  br label %label_2274
}

define ptr @sema_check_value__Struct_ASTNode_Struct_ASTNode_Struct_TypeInfo_String(ptr %0, ptr %1, ptr %2, ptr %3) {
entry:
  %module.974 = alloca ptr, align 8
  store ptr %0, ptr %module.974, align 8
  %val_node.975 = alloca ptr, align 8
  store ptr %1, ptr %val_node.975, align 8
  %expected.976 = alloca ptr, align 8
  store ptr %2, ptr %expected.976, align 8
  %context.977 = alloca ptr, align 8
  store ptr %3, ptr %context.977, align 8
  %sc.116 = alloca i1, align 1
  %sc.117 = alloca i1, align 1
  %4 = load ptr, ptr %expected.976, align 8
  %5 = call i1 @type_is_valid__Struct_TypeInfo(ptr %4)
  store i1 %5, ptr %sc.117, align 1
  %sc.118 = alloca i1, align 1
  %sc.119 = alloca i1, align 1
  %sc.120 = alloca i1, align 1
  %elem_expected.978 = alloca ptr, align 8
  %elem_ptr.979 = alloca ptr, align 8
  %elem.980 = alloca ptr, align 8
  %actual.981 = alloca ptr, align 8
  br i1 %5, label %label_2277, label %label_2278

label_2278:                                       ; preds = %label_2277, %entry
  %6 = load i1, ptr %sc.117, align 1
  store i1 %6, ptr %sc.116, align 1
  br i1 %6, label %label_2275, label %label_2276

label_2277:                                       ; preds = %entry
  %7 = load ptr, ptr %expected.976, align 8
  %8 = getelementptr inbounds nuw %TypeInfo, ptr %7, i32 0, i32 0
  %9 = load i32, ptr %8, align 4
  %10 = icmp eq i32 %9, 2
  store i1 %10, ptr %sc.117, align 1
  br label %label_2278

label_2276:                                       ; preds = %label_2275, %label_2278
  %11 = load i1, ptr %sc.116, align 1
  br i1 %11, label %label_2279, label %label_2281

label_2275:                                       ; preds = %label_2278
  %12 = load ptr, ptr %val_node.975, align 8
  %13 = call i1 @sema_is_int_literal__Struct_ASTNode(ptr %12)
  store i1 %13, ptr %sc.116, align 1
  br label %label_2276

label_2281:                                       ; preds = %label_2276
  %14 = load ptr, ptr %expected.976, align 8
  %15 = call i1 @type_is_valid__Struct_TypeInfo(ptr %14)
  store i1 %15, ptr %sc.120, align 1
  br i1 %15, label %label_2286, label %label_2287

label_2279:                                       ; preds = %label_2276
  %16 = load ptr, ptr %val_node.975, align 8
  %17 = load ptr, ptr %expected.976, align 8
  call void @node_set_type__Struct_ASTNode_Struct_TypeInfo(ptr %16, ptr %17)
  %18 = load ptr, ptr %expected.976, align 8
  ret ptr %18

label_2287:                                       ; preds = %label_2286, %label_2281
  %19 = load i1, ptr %sc.120, align 1
  store i1 %19, ptr %sc.119, align 1
  br i1 %19, label %label_2284, label %label_2285

label_2286:                                       ; preds = %label_2281
  %20 = load ptr, ptr %expected.976, align 8
  %21 = getelementptr inbounds nuw %TypeInfo, ptr %20, i32 0, i32 0
  %22 = load i32, ptr %21, align 4
  %23 = icmp eq i32 %22, 10
  store i1 %23, ptr %sc.120, align 1
  br label %label_2287

label_2285:                                       ; preds = %label_2284, %label_2287
  %24 = load i1, ptr %sc.119, align 1
  store i1 %24, ptr %sc.118, align 1
  br i1 %24, label %label_2282, label %label_2283

label_2284:                                       ; preds = %label_2287
  %25 = load ptr, ptr %val_node.975, align 8
  %26 = getelementptr inbounds nuw %ASTNode, ptr %25, i32 0, i32 0
  %27 = load i32, ptr %26, align 4
  %28 = icmp eq i32 %27, 27
  store i1 %28, ptr %sc.119, align 1
  br label %label_2285

label_2283:                                       ; preds = %label_2282, %label_2285
  %29 = load i1, ptr %sc.118, align 1
  br i1 %29, label %label_2288, label %label_2290

label_2282:                                       ; preds = %label_2285
  %30 = load ptr, ptr %expected.976, align 8
  %31 = getelementptr inbounds nuw %TypeInfo, ptr %30, i32 0, i32 3
  %32 = load ptr, ptr %31, align 8
  %33 = call i32 @str_equals(ptr %32, ptr @.str.s838)
  %34 = icmp eq i32 %33, 0
  store i1 %34, ptr %sc.118, align 1
  br label %label_2283

label_2290:                                       ; preds = %label_2283
  %35 = load ptr, ptr %module.974, align 8
  %36 = load ptr, ptr %val_node.975, align 8
  %37 = call ptr @sema_expr__Struct_ASTNode_Struct_ASTNode(ptr %35, ptr %36)
  store ptr %37, ptr %actual.981, align 8
  %38 = load ptr, ptr %val_node.975, align 8
  %39 = load ptr, ptr %context.977, align 8
  %40 = load ptr, ptr %expected.976, align 8
  %41 = load ptr, ptr %actual.981, align 8
  call void @sema_expect_assignable__Struct_ASTNode_String_Struct_TypeInfo_Struct_TypeInfo(ptr %38, ptr %39, ptr %40, ptr %41)
  %42 = load ptr, ptr %actual.981, align 8
  ret ptr %42

label_2288:                                       ; preds = %label_2283
  %43 = load ptr, ptr %expected.976, align 8
  %44 = getelementptr inbounds nuw %TypeInfo, ptr %43, i32 0, i32 3
  %45 = load ptr, ptr %44, align 8
  %46 = call ptr @ptr_to_type(ptr %45)
  store ptr %46, ptr %elem_expected.978, align 8
  %47 = load ptr, ptr %val_node.975, align 8
  %48 = getelementptr inbounds nuw %ASTNode, ptr %47, i32 0, i32 5
  %49 = load ptr, ptr %48, align 8
  store ptr %49, ptr %elem_ptr.979, align 8
  br label %label_2291

label_2291:                                       ; preds = %label_2292, %label_2288
  %50 = load ptr, ptr %elem_ptr.979, align 8
  %51 = call i32 @str_equals(ptr %50, ptr @.str.s839)
  %52 = icmp eq i32 %51, 0
  br i1 %52, label %label_2292, label %label_2293

label_2293:                                       ; preds = %label_2291
  %53 = load ptr, ptr %val_node.975, align 8
  %54 = load ptr, ptr %expected.976, align 8
  call void @node_set_type__Struct_ASTNode_Struct_TypeInfo(ptr %53, ptr %54)
  %55 = load ptr, ptr %expected.976, align 8
  ret ptr %55

label_2292:                                       ; preds = %label_2291
  %56 = load ptr, ptr %elem_ptr.979, align 8
  %57 = call ptr @ptr_to_node(ptr %56)
  store ptr %57, ptr %elem.980, align 8
  %58 = load ptr, ptr %module.974, align 8
  %59 = load ptr, ptr %elem.980, align 8
  %60 = load ptr, ptr %elem_expected.978, align 8
  %61 = load ptr, ptr %context.977, align 8
  %62 = call ptr @sema_check_value__Struct_ASTNode_Struct_ASTNode_Struct_TypeInfo_String(ptr %58, ptr %59, ptr %60, ptr %61)
  %63 = load ptr, ptr %elem.980, align 8
  %64 = getelementptr inbounds nuw %ASTNode, ptr %63, i32 0, i32 8
  %65 = load ptr, ptr %64, align 8
  store ptr %65, ptr %elem_ptr.979, align 8
  br label %label_2291
}

define ptr @sema_expr__Struct_ASTNode_Struct_ASTNode(ptr %0, ptr %1) {
entry:
  %module.1058 = alloca ptr, align 8
  store ptr %0, ptr %module.1058, align 8
  %expr.1059 = alloca ptr, align 8
  store ptr %1, ptr %expr.1059, align 8
  %2 = load ptr, ptr %expr.1059, align 8
  %3 = call i1 @node_has_type__Struct_ASTNode(ptr %2)
  %t.1060 = alloca ptr, align 8
  %t.1061 = alloca ptr, align 8
  %source.1062 = alloca ptr, align 8
  %from_t.1063 = alloca ptr, align 8
  %to_t.1064 = alloca ptr, align 8
  %sc.144 = alloca i1, align 1
  %sc.145 = alloca i1, align 1
  %sc.146 = alloca i1, align 1
  %sc.147 = alloca i1, align 1
  %from_scalar.1065 = alloca i1, align 1
  %sc.148 = alloca i1, align 1
  %sc.149 = alloca i1, align 1
  %sc.150 = alloca i1, align 1
  %sc.151 = alloca i1, align 1
  %to_scalar.1066 = alloca i1, align 1
  %sc.152 = alloca i1, align 1
  %operand.1067 = alloca ptr, align 8
  %operand_t.1068 = alloca ptr, align 8
  %uop.1069 = alloca ptr, align 8
  %sc.153 = alloca i1, align 1
  %left_node.1070 = alloca ptr, align 8
  %right_node.1071 = alloca ptr, align 8
  %left_t.1072 = alloca ptr, align 8
  %right_t.1073 = alloca ptr, align 8
  %sc.154 = alloca i1, align 1
  %sc.155 = alloca i1, align 1
  %op.1074 = alloca ptr, align 8
  %sc.156 = alloca i1, align 1
  %sc.157 = alloca i1, align 1
  %sc.158 = alloca i1, align 1
  %sc.159 = alloca i1, align 1
  %sc.160 = alloca i1, align 1
  %sc.161 = alloca i1, align 1
  %sc.162 = alloca i1, align 1
  %sc.163 = alloca i1, align 1
  %sc.164 = alloca i1, align 1
  %sc.165 = alloca i1, align 1
  %sc.166 = alloca i1, align 1
  %sc.167 = alloca i1, align 1
  %sc.168 = alloca i1, align 1
  %sc.169 = alloca i1, align 1
  %sc.170 = alloca i1, align 1
  %sc.171 = alloca i1, align 1
  %sc.172 = alloca i1, align 1
  %sc.173 = alloca i1, align 1
  %callee.1075 = alloca ptr, align 8
  %name.1076 = alloca ptr, align 8
  %builtin_t.1077 = alloca ptr, align 8
  %fn_node.1078 = alloca ptr, align 8
  %arg_ptr.1079 = alloca ptr, align 8
  %param_ptr.1080 = alloca ptr, align 8
  %sc.174 = alloca i1, align 1
  %arg_node.1081 = alloca ptr, align 8
  %param_node.1082 = alloca ptr, align 8
  %param_t.1083 = alloca ptr, align 8
  %ret_t.1084 = alloca ptr, align 8
  %object_node.1085 = alloca ptr, align 8
  %sc.175 = alloca i1, align 1
  %object_t.1086 = alloca ptr, align 8
  %field_t.1087 = alloca ptr, align 8
  %elem_ptr.1088 = alloca ptr, align 8
  %arr_t.1089 = alloca ptr, align 8
  %first_t.1090 = alloca ptr, align 8
  %elem.1091 = alloca ptr, align 8
  %elem_t.1092 = alloca ptr, align 8
  %arr_t2.1093 = alloca ptr, align 8
  %array_t.1094 = alloca ptr, align 8
  %index_t.1095 = alloca ptr, align 8
  %elem_t.1096 = alloca ptr, align 8
  %field_ptr.1097 = alloca ptr, align 8
  %field.1098 = alloca ptr, align 8
  %expected.1099 = alloca ptr, align 8
  %struct_t.1100 = alloca ptr, align 8
  br i1 %3, label %label_2529, label %label_2531

label_2531:                                       ; preds = %entry
  %4 = load ptr, ptr %expr.1059, align 8
  %5 = getelementptr inbounds nuw %ASTNode, ptr %4, i32 0, i32 0
  %6 = load i32, ptr %5, align 4
  %7 = icmp eq i32 %6, 22
  br i1 %7, label %label_2532, label %label_2534

label_2529:                                       ; preds = %entry
  %8 = load ptr, ptr %expr.1059, align 8
  %9 = call ptr @node_get_type__Struct_ASTNode(ptr %8)
  ret ptr %9

label_2534:                                       ; preds = %label_2531
  %10 = load ptr, ptr %expr.1059, align 8
  %11 = getelementptr inbounds nuw %ASTNode, ptr %10, i32 0, i32 0
  %12 = load i32, ptr %11, align 4
  %13 = icmp eq i32 %12, 23
  br i1 %13, label %label_2550, label %label_2552

label_2532:                                       ; preds = %label_2531
  %14 = call ptr @type_invalid__Void()
  store ptr %14, ptr %t.1060, align 8
  %15 = load ptr, ptr %expr.1059, align 8
  %16 = getelementptr inbounds nuw %ASTNode, ptr %15, i32 0, i32 3
  %17 = load i32, ptr %16, align 4
  %18 = icmp eq i32 %17, 2
  br i1 %18, label %label_2535, label %label_2537

label_2537:                                       ; preds = %label_2535, %label_2532
  %19 = load ptr, ptr %expr.1059, align 8
  %20 = getelementptr inbounds nuw %ASTNode, ptr %19, i32 0, i32 3
  %21 = load i32, ptr %20, align 4
  %22 = icmp eq i32 %21, 3
  br i1 %22, label %label_2538, label %label_2540

label_2535:                                       ; preds = %label_2532
  %23 = call ptr @type_int__Void()
  store ptr %23, ptr %t.1060, align 8
  br label %label_2537

label_2540:                                       ; preds = %label_2538, %label_2537
  %24 = load ptr, ptr %expr.1059, align 8
  %25 = getelementptr inbounds nuw %ASTNode, ptr %24, i32 0, i32 3
  %26 = load i32, ptr %25, align 4
  %27 = icmp eq i32 %26, 4
  br i1 %27, label %label_2541, label %label_2543

label_2538:                                       ; preds = %label_2537
  %28 = call ptr @type_float__Void()
  store ptr %28, ptr %t.1060, align 8
  br label %label_2540

label_2543:                                       ; preds = %label_2541, %label_2540
  %29 = load ptr, ptr %expr.1059, align 8
  %30 = getelementptr inbounds nuw %ASTNode, ptr %29, i32 0, i32 3
  %31 = load i32, ptr %30, align 4
  %32 = icmp eq i32 %31, 1
  br i1 %32, label %label_2544, label %label_2546

label_2541:                                       ; preds = %label_2540
  %33 = call ptr @type_bool__Void()
  store ptr %33, ptr %t.1060, align 8
  br label %label_2543

label_2546:                                       ; preds = %label_2544, %label_2543
  %34 = load ptr, ptr %expr.1059, align 8
  %35 = getelementptr inbounds nuw %ASTNode, ptr %34, i32 0, i32 3
  %36 = load i32, ptr %35, align 4
  %37 = icmp eq i32 %36, 0
  br i1 %37, label %label_2547, label %label_2549

label_2544:                                       ; preds = %label_2543
  %38 = call ptr @type_char__Void()
  store ptr %38, ptr %t.1060, align 8
  br label %label_2546

label_2549:                                       ; preds = %label_2547, %label_2546
  %39 = load ptr, ptr %expr.1059, align 8
  %40 = load ptr, ptr %t.1060, align 8
  call void @node_set_type__Struct_ASTNode_Struct_TypeInfo(ptr %39, ptr %40)
  %41 = load ptr, ptr %t.1060, align 8
  ret ptr %41

label_2547:                                       ; preds = %label_2546
  %42 = call ptr @type_string__Void()
  store ptr %42, ptr %t.1060, align 8
  br label %label_2549

label_2552:                                       ; preds = %label_2534
  %43 = load ptr, ptr %expr.1059, align 8
  %44 = getelementptr inbounds nuw %ASTNode, ptr %43, i32 0, i32 0
  %45 = load i32, ptr %44, align 4
  %46 = icmp eq i32 %45, 29
  br i1 %46, label %label_2559, label %label_2561

label_2550:                                       ; preds = %label_2534
  %47 = load ptr, ptr %expr.1059, align 8
  %48 = getelementptr inbounds nuw %ASTNode, ptr %47, i32 0, i32 1
  %49 = load ptr, ptr %48, align 8
  %50 = call i32 @ir_has_var_type(ptr %49)
  %51 = icmp eq i32 %50, 0
  br i1 %51, label %label_2553, label %label_2555

label_2555:                                       ; preds = %label_2550
  %52 = load ptr, ptr %expr.1059, align 8
  %53 = getelementptr inbounds nuw %ASTNode, ptr %52, i32 0, i32 1
  %54 = load ptr, ptr %53, align 8
  %55 = call i32 @ir_is_moved(ptr %54)
  %56 = icmp eq i32 %55, 1
  br i1 %56, label %label_2556, label %label_2558

label_2553:                                       ; preds = %label_2550
  %57 = load ptr, ptr %expr.1059, align 8
  %58 = load ptr, ptr %expr.1059, align 8
  %59 = getelementptr inbounds nuw %ASTNode, ptr %58, i32 0, i32 1
  %60 = load ptr, ptr %59, align 8
  %61 = call ptr @diag_quote__String(ptr %60)
  %62 = call ptr @str_concat(ptr @.str.s908, ptr %61)
  call void @sema_error_at__Struct_ASTNode_String(ptr %57, ptr %62)
  %63 = load ptr, ptr %expr.1059, align 8
  %64 = call ptr @type_invalid__Void()
  call void @node_set_type__Struct_ASTNode_Struct_TypeInfo(ptr %63, ptr %64)
  %65 = call ptr @type_invalid__Void()
  ret ptr %65

label_2558:                                       ; preds = %label_2556, %label_2555
  %66 = load ptr, ptr %expr.1059, align 8
  %67 = getelementptr inbounds nuw %ASTNode, ptr %66, i32 0, i32 1
  %68 = load ptr, ptr %67, align 8
  %69 = call ptr @ir_get_var_type(ptr %68)
  %70 = call ptr @type_from_sem_key__String(ptr %69)
  store ptr %70, ptr %t.1061, align 8
  %71 = load ptr, ptr %expr.1059, align 8
  %72 = load ptr, ptr %t.1061, align 8
  call void @node_set_type__Struct_ASTNode_Struct_TypeInfo(ptr %71, ptr %72)
  %73 = load ptr, ptr %t.1061, align 8
  ret ptr %73

label_2556:                                       ; preds = %label_2555
  %74 = load ptr, ptr %expr.1059, align 8
  %75 = load ptr, ptr %expr.1059, align 8
  %76 = getelementptr inbounds nuw %ASTNode, ptr %75, i32 0, i32 1
  %77 = load ptr, ptr %76, align 8
  %78 = call ptr @diag_quote__String(ptr %77)
  %79 = call ptr @str_concat(ptr @.str.s909, ptr %78)
  call void @sema_error_at__Struct_ASTNode_String(ptr %74, ptr %79)
  br label %label_2558

label_2561:                                       ; preds = %label_2552
  %80 = load ptr, ptr %expr.1059, align 8
  %81 = getelementptr inbounds nuw %ASTNode, ptr %80, i32 0, i32 0
  %82 = load i32, ptr %81, align 4
  %83 = icmp eq i32 %82, 21
  br i1 %83, label %label_2586, label %label_2588

label_2559:                                       ; preds = %label_2552
  %84 = load ptr, ptr %expr.1059, align 8
  %85 = getelementptr inbounds nuw %ASTNode, ptr %84, i32 0, i32 5
  %86 = load ptr, ptr %85, align 8
  %87 = call ptr @ptr_to_node(ptr %86)
  store ptr %87, ptr %source.1062, align 8
  %88 = load ptr, ptr %module.1058, align 8
  %89 = load ptr, ptr %source.1062, align 8
  %90 = call ptr @sema_expr__Struct_ASTNode_Struct_ASTNode(ptr %88, ptr %89)
  store ptr %90, ptr %from_t.1063, align 8
  %91 = load ptr, ptr %module.1058, align 8
  %92 = load ptr, ptr %expr.1059, align 8
  %93 = getelementptr inbounds nuw %ASTNode, ptr %92, i32 0, i32 6
  %94 = load ptr, ptr %93, align 8
  %95 = call ptr @ptr_to_node(ptr %94)
  %96 = call ptr @sema_annotation_type__Struct_ASTNode_Struct_ASTNode(ptr %91, ptr %95)
  store ptr %96, ptr %to_t.1064, align 8
  %97 = load ptr, ptr %from_t.1063, align 8
  %98 = getelementptr inbounds nuw %TypeInfo, ptr %97, i32 0, i32 0
  %99 = load i32, ptr %98, align 4
  %100 = icmp eq i32 %99, 2
  store i1 %100, ptr %sc.147, align 1
  br i1 %100, label %label_2569, label %label_2568

label_2568:                                       ; preds = %label_2559
  %101 = load ptr, ptr %from_t.1063, align 8
  %102 = getelementptr inbounds nuw %TypeInfo, ptr %101, i32 0, i32 0
  %103 = load i32, ptr %102, align 4
  %104 = icmp eq i32 %103, 3
  store i1 %104, ptr %sc.147, align 1
  br label %label_2569

label_2569:                                       ; preds = %label_2568, %label_2559
  %105 = load i1, ptr %sc.147, align 1
  store i1 %105, ptr %sc.146, align 1
  br i1 %105, label %label_2567, label %label_2566

label_2566:                                       ; preds = %label_2569
  %106 = load ptr, ptr %from_t.1063, align 8
  %107 = getelementptr inbounds nuw %TypeInfo, ptr %106, i32 0, i32 0
  %108 = load i32, ptr %107, align 4
  %109 = icmp eq i32 %108, 5
  store i1 %109, ptr %sc.146, align 1
  br label %label_2567

label_2567:                                       ; preds = %label_2566, %label_2569
  %110 = load i1, ptr %sc.146, align 1
  store i1 %110, ptr %sc.145, align 1
  br i1 %110, label %label_2565, label %label_2564

label_2564:                                       ; preds = %label_2567
  %111 = load ptr, ptr %from_t.1063, align 8
  %112 = getelementptr inbounds nuw %TypeInfo, ptr %111, i32 0, i32 0
  %113 = load i32, ptr %112, align 4
  %114 = icmp eq i32 %113, 4
  store i1 %114, ptr %sc.145, align 1
  br label %label_2565

label_2565:                                       ; preds = %label_2564, %label_2567
  %115 = load i1, ptr %sc.145, align 1
  store i1 %115, ptr %sc.144, align 1
  br i1 %115, label %label_2563, label %label_2562

label_2562:                                       ; preds = %label_2565
  %116 = load ptr, ptr %from_t.1063, align 8
  %117 = getelementptr inbounds nuw %TypeInfo, ptr %116, i32 0, i32 0
  %118 = load i32, ptr %117, align 4
  %119 = icmp eq i32 %118, 9
  store i1 %119, ptr %sc.144, align 1
  br label %label_2563

label_2563:                                       ; preds = %label_2562, %label_2565
  %120 = load i1, ptr %sc.144, align 1
  store i1 %120, ptr %from_scalar.1065, align 1
  %121 = load ptr, ptr %to_t.1064, align 8
  %122 = getelementptr inbounds nuw %TypeInfo, ptr %121, i32 0, i32 0
  %123 = load i32, ptr %122, align 4
  %124 = icmp eq i32 %123, 2
  store i1 %124, ptr %sc.151, align 1
  br i1 %124, label %label_2577, label %label_2576

label_2576:                                       ; preds = %label_2563
  %125 = load ptr, ptr %to_t.1064, align 8
  %126 = getelementptr inbounds nuw %TypeInfo, ptr %125, i32 0, i32 0
  %127 = load i32, ptr %126, align 4
  %128 = icmp eq i32 %127, 3
  store i1 %128, ptr %sc.151, align 1
  br label %label_2577

label_2577:                                       ; preds = %label_2576, %label_2563
  %129 = load i1, ptr %sc.151, align 1
  store i1 %129, ptr %sc.150, align 1
  br i1 %129, label %label_2575, label %label_2574

label_2574:                                       ; preds = %label_2577
  %130 = load ptr, ptr %to_t.1064, align 8
  %131 = getelementptr inbounds nuw %TypeInfo, ptr %130, i32 0, i32 0
  %132 = load i32, ptr %131, align 4
  %133 = icmp eq i32 %132, 5
  store i1 %133, ptr %sc.150, align 1
  br label %label_2575

label_2575:                                       ; preds = %label_2574, %label_2577
  %134 = load i1, ptr %sc.150, align 1
  store i1 %134, ptr %sc.149, align 1
  br i1 %134, label %label_2573, label %label_2572

label_2572:                                       ; preds = %label_2575
  %135 = load ptr, ptr %to_t.1064, align 8
  %136 = getelementptr inbounds nuw %TypeInfo, ptr %135, i32 0, i32 0
  %137 = load i32, ptr %136, align 4
  %138 = icmp eq i32 %137, 9
  store i1 %138, ptr %sc.149, align 1
  br label %label_2573

label_2573:                                       ; preds = %label_2572, %label_2575
  %139 = load i1, ptr %sc.149, align 1
  store i1 %139, ptr %sc.148, align 1
  br i1 %139, label %label_2571, label %label_2570

label_2570:                                       ; preds = %label_2573
  %140 = load ptr, ptr %to_t.1064, align 8
  %141 = getelementptr inbounds nuw %TypeInfo, ptr %140, i32 0, i32 0
  %142 = load i32, ptr %141, align 4
  %143 = icmp eq i32 %142, 4
  store i1 %143, ptr %sc.148, align 1
  br label %label_2571

label_2571:                                       ; preds = %label_2570, %label_2573
  %144 = load i1, ptr %sc.148, align 1
  store i1 %144, ptr %to_scalar.1066, align 1
  %145 = load ptr, ptr %to_t.1064, align 8
  %146 = getelementptr inbounds nuw %TypeInfo, ptr %145, i32 0, i32 0
  %147 = load i32, ptr %146, align 4
  %148 = icmp eq i32 %147, 4
  br i1 %148, label %label_2578, label %label_2580

label_2580:                                       ; preds = %label_2571
  %149 = load i1, ptr %from_scalar.1065, align 1
  %150 = icmp eq i1 %149, false
  store i1 %150, ptr %sc.152, align 1
  br i1 %150, label %label_2582, label %label_2581

label_2578:                                       ; preds = %label_2571
  %151 = load ptr, ptr %expr.1059, align 8
  call void @sema_error_at__Struct_ASTNode_String(ptr %151, ptr @.str.s910)
  %152 = load ptr, ptr %expr.1059, align 8
  %153 = load ptr, ptr %to_t.1064, align 8
  call void @node_set_type__Struct_ASTNode_Struct_TypeInfo(ptr %152, ptr %153)
  %154 = load ptr, ptr %to_t.1064, align 8
  ret ptr %154

label_2581:                                       ; preds = %label_2580
  %155 = load i1, ptr %to_scalar.1066, align 1
  %156 = icmp eq i1 %155, false
  store i1 %156, ptr %sc.152, align 1
  br label %label_2582

label_2582:                                       ; preds = %label_2581, %label_2580
  %157 = load i1, ptr %sc.152, align 1
  br i1 %157, label %label_2583, label %label_2585

label_2585:                                       ; preds = %label_2583, %label_2582
  %158 = load ptr, ptr %expr.1059, align 8
  %159 = load ptr, ptr %to_t.1064, align 8
  call void @node_set_type__Struct_ASTNode_Struct_TypeInfo(ptr %158, ptr %159)
  %160 = load ptr, ptr %to_t.1064, align 8
  ret ptr %160

label_2583:                                       ; preds = %label_2582
  %161 = load ptr, ptr %expr.1059, align 8
  %162 = load ptr, ptr %to_t.1064, align 8
  %163 = load ptr, ptr %from_t.1063, align 8
  call void @sema_type_error_at__Struct_ASTNode_String_Struct_TypeInfo_Struct_TypeInfo(ptr %161, ptr @.str.s911, ptr %162, ptr %163)
  br label %label_2585

label_2588:                                       ; preds = %label_2561
  %164 = load ptr, ptr %expr.1059, align 8
  %165 = getelementptr inbounds nuw %ASTNode, ptr %164, i32 0, i32 0
  %166 = load i32, ptr %165, align 4
  %167 = icmp eq i32 %166, 20
  br i1 %167, label %label_2609, label %label_2611

label_2586:                                       ; preds = %label_2561
  %168 = load ptr, ptr %expr.1059, align 8
  %169 = getelementptr inbounds nuw %ASTNode, ptr %168, i32 0, i32 5
  %170 = load ptr, ptr %169, align 8
  %171 = call ptr @ptr_to_node(ptr %170)
  store ptr %171, ptr %operand.1067, align 8
  %172 = load ptr, ptr %module.1058, align 8
  %173 = load ptr, ptr %operand.1067, align 8
  %174 = call ptr @sema_expr__Struct_ASTNode_Struct_ASTNode(ptr %172, ptr %173)
  store ptr %174, ptr %operand_t.1068, align 8
  %175 = load ptr, ptr %expr.1059, align 8
  %176 = getelementptr inbounds nuw %ASTNode, ptr %175, i32 0, i32 1
  %177 = load ptr, ptr %176, align 8
  store ptr %177, ptr %uop.1069, align 8
  %178 = load ptr, ptr %uop.1069, align 8
  %179 = call i32 @str_equals(ptr %178, ptr @.str.s912)
  %180 = icmp eq i32 %179, 1
  br i1 %180, label %label_2589, label %label_2591

label_2591:                                       ; preds = %label_2586
  %181 = load ptr, ptr %uop.1069, align 8
  %182 = call i32 @str_equals(ptr %181, ptr @.str.s914)
  %183 = icmp eq i32 %182, 1
  br i1 %183, label %label_2592, label %label_2594

label_2589:                                       ; preds = %label_2586
  %184 = load ptr, ptr %operand.1067, align 8
  %185 = call ptr @type_bool__Void()
  %186 = load ptr, ptr %operand_t.1068, align 8
  call void @sema_expect_assignable__Struct_ASTNode_String_Struct_TypeInfo_Struct_TypeInfo(ptr %184, ptr @.str.s913, ptr %185, ptr %186)
  %187 = load ptr, ptr %expr.1059, align 8
  %188 = call ptr @type_bool__Void()
  call void @node_set_type__Struct_ASTNode_Struct_TypeInfo(ptr %187, ptr %188)
  %189 = call ptr @type_bool__Void()
  ret ptr %189

label_2594:                                       ; preds = %label_2591
  %190 = load ptr, ptr %uop.1069, align 8
  %191 = call i32 @str_equals(ptr %190, ptr @.str.s916)
  %192 = icmp eq i32 %191, 1
  br i1 %192, label %label_2600, label %label_2602

label_2592:                                       ; preds = %label_2591
  %193 = load ptr, ptr %operand_t.1068, align 8
  %194 = getelementptr inbounds nuw %TypeInfo, ptr %193, i32 0, i32 0
  %195 = load i32, ptr %194, align 4
  %196 = icmp ne i32 %195, 2
  store i1 %196, ptr %sc.153, align 1
  br i1 %196, label %label_2595, label %label_2596

label_2596:                                       ; preds = %label_2595, %label_2592
  %197 = load i1, ptr %sc.153, align 1
  br i1 %197, label %label_2597, label %label_2599

label_2595:                                       ; preds = %label_2592
  %198 = load ptr, ptr %operand_t.1068, align 8
  %199 = getelementptr inbounds nuw %TypeInfo, ptr %198, i32 0, i32 0
  %200 = load i32, ptr %199, align 4
  %201 = icmp ne i32 %200, 5
  store i1 %201, ptr %sc.153, align 1
  br label %label_2596

label_2599:                                       ; preds = %label_2597, %label_2596
  %202 = load ptr, ptr %expr.1059, align 8
  %203 = load ptr, ptr %operand_t.1068, align 8
  call void @node_set_type__Struct_ASTNode_Struct_TypeInfo(ptr %202, ptr %203)
  %204 = load ptr, ptr %operand_t.1068, align 8
  ret ptr %204

label_2597:                                       ; preds = %label_2596
  %205 = load ptr, ptr %operand.1067, align 8
  call void @sema_error_at__Struct_ASTNode_String(ptr %205, ptr @.str.s915)
  br label %label_2599

label_2602:                                       ; preds = %label_2594
  %206 = load ptr, ptr %expr.1059, align 8
  %207 = load ptr, ptr %uop.1069, align 8
  %208 = call ptr @diag_quote__String(ptr %207)
  %209 = call ptr @str_concat(ptr @.str.s919, ptr %208)
  call void @sema_error_at__Struct_ASTNode_String(ptr %206, ptr %209)
  %210 = load ptr, ptr %expr.1059, align 8
  %211 = call ptr @type_invalid__Void()
  call void @node_set_type__Struct_ASTNode_Struct_TypeInfo(ptr %210, ptr %211)
  %212 = call ptr @type_invalid__Void()
  ret ptr %212

label_2600:                                       ; preds = %label_2594
  %213 = load ptr, ptr %operand_t.1068, align 8
  %214 = call i1 @type_is_numeric__Struct_TypeInfo(ptr %213)
  %215 = icmp eq i1 %214, false
  br i1 %215, label %label_2603, label %label_2605

label_2605:                                       ; preds = %label_2603, %label_2600
  %216 = load ptr, ptr %operand_t.1068, align 8
  %217 = call i1 @type_int_is_unsigned__Struct_TypeInfo(ptr %216)
  br i1 %217, label %label_2606, label %label_2608

label_2603:                                       ; preds = %label_2600
  %218 = load ptr, ptr %operand.1067, align 8
  call void @sema_error_at__Struct_ASTNode_String(ptr %218, ptr @.str.s917)
  br label %label_2605

label_2608:                                       ; preds = %label_2606, %label_2605
  %219 = load ptr, ptr %expr.1059, align 8
  %220 = load ptr, ptr %operand_t.1068, align 8
  call void @node_set_type__Struct_ASTNode_Struct_TypeInfo(ptr %219, ptr %220)
  %221 = load ptr, ptr %operand_t.1068, align 8
  ret ptr %221

label_2606:                                       ; preds = %label_2605
  %222 = load ptr, ptr %operand.1067, align 8
  %223 = load ptr, ptr %operand_t.1068, align 8
  %224 = call ptr @type_display__Struct_TypeInfo(ptr %223)
  %225 = call ptr @str_concat(ptr @.str.s918, ptr %224)
  call void @sema_error_at__Struct_ASTNode_String(ptr %222, ptr %225)
  br label %label_2608

label_2611:                                       ; preds = %label_2588
  %226 = load ptr, ptr %expr.1059, align 8
  %227 = getelementptr inbounds nuw %ASTNode, ptr %226, i32 0, i32 0
  %228 = load i32, ptr %227, align 4
  %229 = icmp eq i32 %228, 24
  br i1 %229, label %label_2700, label %label_2702

label_2609:                                       ; preds = %label_2588
  %230 = load ptr, ptr %expr.1059, align 8
  %231 = getelementptr inbounds nuw %ASTNode, ptr %230, i32 0, i32 5
  %232 = load ptr, ptr %231, align 8
  %233 = call ptr @ptr_to_node(ptr %232)
  store ptr %233, ptr %left_node.1070, align 8
  %234 = load ptr, ptr %expr.1059, align 8
  %235 = getelementptr inbounds nuw %ASTNode, ptr %234, i32 0, i32 6
  %236 = load ptr, ptr %235, align 8
  %237 = call ptr @ptr_to_node(ptr %236)
  store ptr %237, ptr %right_node.1071, align 8
  %238 = load ptr, ptr %module.1058, align 8
  %239 = load ptr, ptr %left_node.1070, align 8
  %240 = call ptr @sema_expr__Struct_ASTNode_Struct_ASTNode(ptr %238, ptr %239)
  store ptr %240, ptr %left_t.1072, align 8
  %241 = load ptr, ptr %module.1058, align 8
  %242 = load ptr, ptr %right_node.1071, align 8
  %243 = call ptr @sema_expr__Struct_ASTNode_Struct_ASTNode(ptr %241, ptr %242)
  store ptr %243, ptr %right_t.1073, align 8
  %244 = load ptr, ptr %left_t.1072, align 8
  %245 = getelementptr inbounds nuw %TypeInfo, ptr %244, i32 0, i32 0
  %246 = load i32, ptr %245, align 4
  %247 = icmp eq i32 %246, 2
  store i1 %247, ptr %sc.155, align 1
  br i1 %247, label %label_2614, label %label_2615

label_2615:                                       ; preds = %label_2614, %label_2609
  %248 = load i1, ptr %sc.155, align 1
  store i1 %248, ptr %sc.154, align 1
  br i1 %248, label %label_2612, label %label_2613

label_2614:                                       ; preds = %label_2609
  %249 = load ptr, ptr %right_t.1073, align 8
  %250 = getelementptr inbounds nuw %TypeInfo, ptr %249, i32 0, i32 0
  %251 = load i32, ptr %250, align 4
  %252 = icmp eq i32 %251, 2
  store i1 %252, ptr %sc.155, align 1
  br label %label_2615

label_2613:                                       ; preds = %label_2612, %label_2615
  %253 = load i1, ptr %sc.154, align 1
  br i1 %253, label %label_2616, label %label_2618

label_2612:                                       ; preds = %label_2615
  %254 = load ptr, ptr %left_t.1072, align 8
  %255 = load ptr, ptr %right_t.1073, align 8
  %256 = call i1 @type_equals__Struct_TypeInfo_Struct_TypeInfo(ptr %254, ptr %255)
  %257 = icmp eq i1 %256, false
  store i1 %257, ptr %sc.154, align 1
  br label %label_2613

label_2618:                                       ; preds = %label_2621, %label_2613
  %258 = load ptr, ptr %expr.1059, align 8
  %259 = getelementptr inbounds nuw %ASTNode, ptr %258, i32 0, i32 1
  %260 = load ptr, ptr %259, align 8
  store ptr %260, ptr %op.1074, align 8
  %261 = load ptr, ptr %op.1074, align 8
  %262 = call i32 @str_equals(ptr %261, ptr @.str.s920)
  %263 = icmp eq i32 %262, 1
  store i1 %263, ptr %sc.156, align 1
  br i1 %263, label %label_2626, label %label_2625

label_2616:                                       ; preds = %label_2613
  %264 = load ptr, ptr %right_node.1071, align 8
  %265 = call i1 @sema_is_int_literal__Struct_ASTNode(ptr %264)
  br i1 %265, label %label_2619, label %label_2620

label_2620:                                       ; preds = %label_2616
  %266 = load ptr, ptr %left_node.1070, align 8
  %267 = call i1 @sema_is_int_literal__Struct_ASTNode(ptr %266)
  br i1 %267, label %label_2622, label %label_2624

label_2619:                                       ; preds = %label_2616
  %268 = load ptr, ptr %right_node.1071, align 8
  %269 = load ptr, ptr %left_t.1072, align 8
  call void @node_set_type__Struct_ASTNode_Struct_TypeInfo(ptr %268, ptr %269)
  %270 = load ptr, ptr %left_t.1072, align 8
  %271 = call ptr @type_copy__Struct_TypeInfo(ptr %270)
  store ptr %271, ptr %right_t.1073, align 8
  br label %label_2621

label_2621:                                       ; preds = %label_2624, %label_2619
  br label %label_2618

label_2624:                                       ; preds = %label_2622, %label_2620
  br label %label_2621

label_2622:                                       ; preds = %label_2620
  %272 = load ptr, ptr %left_node.1070, align 8
  %273 = load ptr, ptr %right_t.1073, align 8
  call void @node_set_type__Struct_ASTNode_Struct_TypeInfo(ptr %272, ptr %273)
  %274 = load ptr, ptr %right_t.1073, align 8
  %275 = call ptr @type_copy__Struct_TypeInfo(ptr %274)
  store ptr %275, ptr %left_t.1072, align 8
  br label %label_2624

label_2625:                                       ; preds = %label_2618
  %276 = load ptr, ptr %op.1074, align 8
  %277 = call i32 @str_equals(ptr %276, ptr @.str.s921)
  %278 = icmp eq i32 %277, 1
  store i1 %278, ptr %sc.156, align 1
  br label %label_2626

label_2626:                                       ; preds = %label_2625, %label_2618
  %279 = load i1, ptr %sc.156, align 1
  br i1 %279, label %label_2627, label %label_2629

label_2629:                                       ; preds = %label_2626
  %280 = load ptr, ptr %op.1074, align 8
  %281 = call i32 @str_equals(ptr %280, ptr @.str.s924)
  %282 = icmp eq i32 %281, 1
  store i1 %282, ptr %sc.159, align 1
  br i1 %282, label %label_2635, label %label_2634

label_2627:                                       ; preds = %label_2626
  %283 = load ptr, ptr %left_node.1070, align 8
  %284 = call ptr @type_bool__Void()
  %285 = load ptr, ptr %left_t.1072, align 8
  call void @sema_expect_assignable__Struct_ASTNode_String_Struct_TypeInfo_Struct_TypeInfo(ptr %283, ptr @.str.s922, ptr %284, ptr %285)
  %286 = load ptr, ptr %right_node.1071, align 8
  %287 = call ptr @type_bool__Void()
  %288 = load ptr, ptr %right_t.1073, align 8
  call void @sema_expect_assignable__Struct_ASTNode_String_Struct_TypeInfo_Struct_TypeInfo(ptr %286, ptr @.str.s923, ptr %287, ptr %288)
  %289 = load ptr, ptr %expr.1059, align 8
  %290 = call ptr @type_bool__Void()
  call void @node_set_type__Struct_ASTNode_Struct_TypeInfo(ptr %289, ptr %290)
  %291 = call ptr @type_bool__Void()
  ret ptr %291

label_2634:                                       ; preds = %label_2629
  %292 = load ptr, ptr %op.1074, align 8
  %293 = call i32 @str_equals(ptr %292, ptr @.str.s925)
  %294 = icmp eq i32 %293, 1
  store i1 %294, ptr %sc.159, align 1
  br label %label_2635

label_2635:                                       ; preds = %label_2634, %label_2629
  %295 = load i1, ptr %sc.159, align 1
  store i1 %295, ptr %sc.158, align 1
  br i1 %295, label %label_2633, label %label_2632

label_2632:                                       ; preds = %label_2635
  %296 = load ptr, ptr %op.1074, align 8
  %297 = call i32 @str_equals(ptr %296, ptr @.str.s926)
  %298 = icmp eq i32 %297, 1
  store i1 %298, ptr %sc.158, align 1
  br label %label_2633

label_2633:                                       ; preds = %label_2632, %label_2635
  %299 = load i1, ptr %sc.158, align 1
  store i1 %299, ptr %sc.157, align 1
  br i1 %299, label %label_2631, label %label_2630

label_2630:                                       ; preds = %label_2633
  %300 = load ptr, ptr %op.1074, align 8
  %301 = call i32 @str_equals(ptr %300, ptr @.str.s927)
  %302 = icmp eq i32 %301, 1
  store i1 %302, ptr %sc.157, align 1
  br label %label_2631

label_2631:                                       ; preds = %label_2630, %label_2633
  %303 = load i1, ptr %sc.157, align 1
  br i1 %303, label %label_2636, label %label_2638

label_2638:                                       ; preds = %label_2631
  %304 = load ptr, ptr %op.1074, align 8
  %305 = call i32 @str_equals(ptr %304, ptr @.str.s931)
  %306 = icmp eq i32 %305, 1
  br i1 %306, label %label_2642, label %label_2644

label_2636:                                       ; preds = %label_2631
  %307 = load ptr, ptr %left_t.1072, align 8
  %308 = call i1 @type_is_numeric__Struct_TypeInfo(ptr %307)
  %309 = icmp eq i1 %308, false
  br i1 %309, label %label_2639, label %label_2641

label_2641:                                       ; preds = %label_2639, %label_2636
  %310 = load ptr, ptr %right_node.1071, align 8
  %311 = load ptr, ptr %op.1074, align 8
  %312 = call ptr @diag_quote__String(ptr %311)
  %313 = call ptr @str_concat(ptr @.str.s930, ptr %312)
  %314 = load ptr, ptr %left_t.1072, align 8
  %315 = load ptr, ptr %right_t.1073, align 8
  call void @sema_expect_assignable__Struct_ASTNode_String_Struct_TypeInfo_Struct_TypeInfo(ptr %310, ptr %313, ptr %314, ptr %315)
  %316 = load ptr, ptr %expr.1059, align 8
  %317 = load ptr, ptr %left_t.1072, align 8
  call void @node_set_type__Struct_ASTNode_Struct_TypeInfo(ptr %316, ptr %317)
  %318 = load ptr, ptr %left_t.1072, align 8
  ret ptr %318

label_2639:                                       ; preds = %label_2636
  %319 = load ptr, ptr %left_node.1070, align 8
  %320 = load ptr, ptr %op.1074, align 8
  %321 = call ptr @diag_quote__String(ptr %320)
  %322 = call ptr @str_concat(ptr @.str.s928, ptr %321)
  %323 = call ptr @str_concat(ptr %322, ptr @.str.s929)
  call void @sema_error_at__Struct_ASTNode_String(ptr %319, ptr %323)
  br label %label_2641

label_2644:                                       ; preds = %label_2638
  %324 = load ptr, ptr %op.1074, align 8
  %325 = call i32 @str_equals(ptr %324, ptr @.str.s934)
  %326 = icmp eq i32 %325, 1
  store i1 %326, ptr %sc.162, align 1
  br i1 %326, label %label_2653, label %label_2652

label_2642:                                       ; preds = %label_2638
  %327 = load ptr, ptr %left_t.1072, align 8
  %328 = getelementptr inbounds nuw %TypeInfo, ptr %327, i32 0, i32 0
  %329 = load i32, ptr %328, align 4
  %330 = icmp ne i32 %329, 2
  store i1 %330, ptr %sc.160, align 1
  br i1 %330, label %label_2645, label %label_2646

label_2646:                                       ; preds = %label_2645, %label_2642
  %331 = load i1, ptr %sc.160, align 1
  br i1 %331, label %label_2647, label %label_2649

label_2645:                                       ; preds = %label_2642
  %332 = load ptr, ptr %left_t.1072, align 8
  %333 = getelementptr inbounds nuw %TypeInfo, ptr %332, i32 0, i32 0
  %334 = load i32, ptr %333, align 4
  %335 = icmp ne i32 %334, 9
  store i1 %335, ptr %sc.160, align 1
  br label %label_2646

label_2649:                                       ; preds = %label_2647, %label_2646
  %336 = load ptr, ptr %right_node.1071, align 8
  %337 = load ptr, ptr %left_t.1072, align 8
  %338 = load ptr, ptr %right_t.1073, align 8
  call void @sema_expect_assignable__Struct_ASTNode_String_Struct_TypeInfo_Struct_TypeInfo(ptr %336, ptr @.str.s933, ptr %337, ptr %338)
  %339 = load ptr, ptr %expr.1059, align 8
  %340 = load ptr, ptr %left_t.1072, align 8
  call void @node_set_type__Struct_ASTNode_Struct_TypeInfo(ptr %339, ptr %340)
  %341 = load ptr, ptr %left_t.1072, align 8
  ret ptr %341

label_2647:                                       ; preds = %label_2646
  %342 = load ptr, ptr %left_node.1070, align 8
  call void @sema_error_at__Struct_ASTNode_String(ptr %342, ptr @.str.s932)
  br label %label_2649

label_2652:                                       ; preds = %label_2644
  %343 = load ptr, ptr %op.1074, align 8
  %344 = call i32 @str_equals(ptr %343, ptr @.str.s935)
  %345 = icmp eq i32 %344, 1
  store i1 %345, ptr %sc.162, align 1
  br label %label_2653

label_2653:                                       ; preds = %label_2652, %label_2644
  %346 = load i1, ptr %sc.162, align 1
  store i1 %346, ptr %sc.161, align 1
  br i1 %346, label %label_2651, label %label_2650

label_2650:                                       ; preds = %label_2653
  %347 = load ptr, ptr %op.1074, align 8
  %348 = call i32 @str_equals(ptr %347, ptr @.str.s936)
  %349 = icmp eq i32 %348, 1
  store i1 %349, ptr %sc.161, align 1
  br label %label_2651

label_2651:                                       ; preds = %label_2650, %label_2653
  %350 = load i1, ptr %sc.161, align 1
  br i1 %350, label %label_2654, label %label_2656

label_2656:                                       ; preds = %label_2651
  %351 = load ptr, ptr %op.1074, align 8
  %352 = call i32 @str_equals(ptr %351, ptr @.str.s940)
  %353 = icmp eq i32 %352, 1
  store i1 %353, ptr %sc.165, align 1
  br i1 %353, label %label_2665, label %label_2664

label_2654:                                       ; preds = %label_2651
  %354 = load ptr, ptr %left_t.1072, align 8
  %355 = getelementptr inbounds nuw %TypeInfo, ptr %354, i32 0, i32 0
  %356 = load i32, ptr %355, align 4
  %357 = icmp ne i32 %356, 2
  store i1 %357, ptr %sc.164, align 1
  br i1 %357, label %label_2659, label %label_2660

label_2660:                                       ; preds = %label_2659, %label_2654
  %358 = load i1, ptr %sc.164, align 1
  store i1 %358, ptr %sc.163, align 1
  br i1 %358, label %label_2657, label %label_2658

label_2659:                                       ; preds = %label_2654
  %359 = load ptr, ptr %left_t.1072, align 8
  %360 = getelementptr inbounds nuw %TypeInfo, ptr %359, i32 0, i32 0
  %361 = load i32, ptr %360, align 4
  %362 = icmp ne i32 %361, 9
  store i1 %362, ptr %sc.164, align 1
  br label %label_2660

label_2658:                                       ; preds = %label_2657, %label_2660
  %363 = load i1, ptr %sc.163, align 1
  br i1 %363, label %label_2661, label %label_2663

label_2657:                                       ; preds = %label_2660
  %364 = load ptr, ptr %left_t.1072, align 8
  %365 = getelementptr inbounds nuw %TypeInfo, ptr %364, i32 0, i32 0
  %366 = load i32, ptr %365, align 4
  %367 = icmp ne i32 %366, 5
  store i1 %367, ptr %sc.163, align 1
  br label %label_2658

label_2663:                                       ; preds = %label_2661, %label_2658
  %368 = load ptr, ptr %right_node.1071, align 8
  %369 = load ptr, ptr %op.1074, align 8
  %370 = call ptr @diag_quote__String(ptr %369)
  %371 = call ptr @str_concat(ptr @.str.s939, ptr %370)
  %372 = load ptr, ptr %left_t.1072, align 8
  %373 = load ptr, ptr %right_t.1073, align 8
  call void @sema_expect_assignable__Struct_ASTNode_String_Struct_TypeInfo_Struct_TypeInfo(ptr %368, ptr %371, ptr %372, ptr %373)
  %374 = load ptr, ptr %expr.1059, align 8
  %375 = load ptr, ptr %left_t.1072, align 8
  call void @node_set_type__Struct_ASTNode_Struct_TypeInfo(ptr %374, ptr %375)
  %376 = load ptr, ptr %left_t.1072, align 8
  ret ptr %376

label_2661:                                       ; preds = %label_2658
  %377 = load ptr, ptr %left_node.1070, align 8
  %378 = load ptr, ptr %op.1074, align 8
  %379 = call ptr @diag_quote__String(ptr %378)
  %380 = call ptr @str_concat(ptr @.str.s937, ptr %379)
  %381 = call ptr @str_concat(ptr %380, ptr @.str.s938)
  call void @sema_error_at__Struct_ASTNode_String(ptr %377, ptr %381)
  br label %label_2663

label_2664:                                       ; preds = %label_2656
  %382 = load ptr, ptr %op.1074, align 8
  %383 = call i32 @str_equals(ptr %382, ptr @.str.s941)
  %384 = icmp eq i32 %383, 1
  store i1 %384, ptr %sc.165, align 1
  br label %label_2665

label_2665:                                       ; preds = %label_2664, %label_2656
  %385 = load i1, ptr %sc.165, align 1
  br i1 %385, label %label_2666, label %label_2668

label_2668:                                       ; preds = %label_2665
  %386 = load ptr, ptr %op.1074, align 8
  %387 = call i32 @str_equals(ptr %386, ptr @.str.s946)
  %388 = icmp eq i32 %387, 1
  store i1 %388, ptr %sc.171, align 1
  br i1 %388, label %label_2686, label %label_2685

label_2666:                                       ; preds = %label_2665
  %389 = load ptr, ptr %left_t.1072, align 8
  %390 = getelementptr inbounds nuw %TypeInfo, ptr %389, i32 0, i32 0
  %391 = load i32, ptr %390, align 4
  %392 = icmp ne i32 %391, 2
  store i1 %392, ptr %sc.166, align 1
  br i1 %392, label %label_2669, label %label_2670

label_2670:                                       ; preds = %label_2669, %label_2666
  %393 = load i1, ptr %sc.166, align 1
  br i1 %393, label %label_2671, label %label_2673

label_2669:                                       ; preds = %label_2666
  %394 = load ptr, ptr %left_t.1072, align 8
  %395 = getelementptr inbounds nuw %TypeInfo, ptr %394, i32 0, i32 0
  %396 = load i32, ptr %395, align 4
  %397 = icmp ne i32 %396, 5
  store i1 %397, ptr %sc.166, align 1
  br label %label_2670

label_2673:                                       ; preds = %label_2671, %label_2670
  %398 = load ptr, ptr %right_t.1073, align 8
  %399 = getelementptr inbounds nuw %TypeInfo, ptr %398, i32 0, i32 0
  %400 = load i32, ptr %399, align 4
  %401 = icmp ne i32 %400, 2
  br i1 %401, label %label_2674, label %label_2676

label_2671:                                       ; preds = %label_2670
  %402 = load ptr, ptr %left_node.1070, align 8
  %403 = load ptr, ptr %op.1074, align 8
  %404 = call ptr @diag_quote__String(ptr %403)
  %405 = call ptr @str_concat(ptr @.str.s942, ptr %404)
  %406 = call ptr @str_concat(ptr %405, ptr @.str.s943)
  call void @sema_error_at__Struct_ASTNode_String(ptr %402, ptr %406)
  br label %label_2673

label_2676:                                       ; preds = %label_2674, %label_2673
  %407 = load ptr, ptr %expr.1059, align 8
  %408 = load ptr, ptr %left_t.1072, align 8
  call void @node_set_type__Struct_ASTNode_Struct_TypeInfo(ptr %407, ptr %408)
  %409 = load ptr, ptr %left_t.1072, align 8
  ret ptr %409

label_2674:                                       ; preds = %label_2673
  %410 = load ptr, ptr %right_node.1071, align 8
  %411 = load ptr, ptr %op.1074, align 8
  %412 = call ptr @diag_quote__String(ptr %411)
  %413 = call ptr @str_concat(ptr @.str.s944, ptr %412)
  %414 = call ptr @str_concat(ptr %413, ptr @.str.s945)
  call void @sema_error_at__Struct_ASTNode_String(ptr %410, ptr %414)
  br label %label_2676

label_2685:                                       ; preds = %label_2668
  %415 = load ptr, ptr %op.1074, align 8
  %416 = call i32 @str_equals(ptr %415, ptr @.str.s947)
  %417 = icmp eq i32 %416, 1
  store i1 %417, ptr %sc.171, align 1
  br label %label_2686

label_2686:                                       ; preds = %label_2685, %label_2668
  %418 = load i1, ptr %sc.171, align 1
  store i1 %418, ptr %sc.170, align 1
  br i1 %418, label %label_2684, label %label_2683

label_2683:                                       ; preds = %label_2686
  %419 = load ptr, ptr %op.1074, align 8
  %420 = call i32 @str_equals(ptr %419, ptr @.str.s948)
  %421 = icmp eq i32 %420, 1
  store i1 %421, ptr %sc.170, align 1
  br label %label_2684

label_2684:                                       ; preds = %label_2683, %label_2686
  %422 = load i1, ptr %sc.170, align 1
  store i1 %422, ptr %sc.169, align 1
  br i1 %422, label %label_2682, label %label_2681

label_2681:                                       ; preds = %label_2684
  %423 = load ptr, ptr %op.1074, align 8
  %424 = call i32 @str_equals(ptr %423, ptr @.str.s949)
  %425 = icmp eq i32 %424, 1
  store i1 %425, ptr %sc.169, align 1
  br label %label_2682

label_2682:                                       ; preds = %label_2681, %label_2684
  %426 = load i1, ptr %sc.169, align 1
  store i1 %426, ptr %sc.168, align 1
  br i1 %426, label %label_2680, label %label_2679

label_2679:                                       ; preds = %label_2682
  %427 = load ptr, ptr %op.1074, align 8
  %428 = call i32 @str_equals(ptr %427, ptr @.str.s950)
  %429 = icmp eq i32 %428, 1
  store i1 %429, ptr %sc.168, align 1
  br label %label_2680

label_2680:                                       ; preds = %label_2679, %label_2682
  %430 = load i1, ptr %sc.168, align 1
  store i1 %430, ptr %sc.167, align 1
  br i1 %430, label %label_2678, label %label_2677

label_2677:                                       ; preds = %label_2680
  %431 = load ptr, ptr %op.1074, align 8
  %432 = call i32 @str_equals(ptr %431, ptr @.str.s951)
  %433 = icmp eq i32 %432, 1
  store i1 %433, ptr %sc.167, align 1
  br label %label_2678

label_2678:                                       ; preds = %label_2677, %label_2680
  %434 = load i1, ptr %sc.167, align 1
  br i1 %434, label %label_2687, label %label_2689

label_2689:                                       ; preds = %label_2678
  %435 = load ptr, ptr %expr.1059, align 8
  %436 = load ptr, ptr %op.1074, align 8
  %437 = call ptr @diag_quote__String(ptr %436)
  %438 = call ptr @str_concat(ptr @.str.s955, ptr %437)
  call void @sema_error_at__Struct_ASTNode_String(ptr %435, ptr %438)
  %439 = load ptr, ptr %expr.1059, align 8
  %440 = call ptr @type_invalid__Void()
  call void @node_set_type__Struct_ASTNode_Struct_TypeInfo(ptr %439, ptr %440)
  %441 = call ptr @type_invalid__Void()
  ret ptr %441

label_2687:                                       ; preds = %label_2678
  %442 = load ptr, ptr %left_t.1072, align 8
  %443 = getelementptr inbounds nuw %TypeInfo, ptr %442, i32 0, i32 0
  %444 = load i32, ptr %443, align 4
  %445 = icmp eq i32 %444, 6
  store i1 %445, ptr %sc.172, align 1
  br i1 %445, label %label_2691, label %label_2690

label_2690:                                       ; preds = %label_2687
  %446 = load ptr, ptr %right_t.1073, align 8
  %447 = getelementptr inbounds nuw %TypeInfo, ptr %446, i32 0, i32 0
  %448 = load i32, ptr %447, align 4
  %449 = icmp eq i32 %448, 6
  store i1 %449, ptr %sc.172, align 1
  br label %label_2691

label_2691:                                       ; preds = %label_2690, %label_2687
  %450 = load i1, ptr %sc.172, align 1
  br i1 %450, label %label_2692, label %label_2694

label_2694:                                       ; preds = %label_2691
  %451 = load ptr, ptr %left_t.1072, align 8
  %452 = getelementptr inbounds nuw %TypeInfo, ptr %451, i32 0, i32 0
  %453 = load i32, ptr %452, align 4
  %454 = icmp eq i32 %453, 8
  store i1 %454, ptr %sc.173, align 1
  br i1 %454, label %label_2696, label %label_2695

label_2692:                                       ; preds = %label_2691
  %455 = load ptr, ptr %expr.1059, align 8
  call void @sema_error_at__Struct_ASTNode_String(ptr %455, ptr @.str.s952)
  %456 = load ptr, ptr %expr.1059, align 8
  %457 = call ptr @type_bool__Void()
  call void @node_set_type__Struct_ASTNode_Struct_TypeInfo(ptr %456, ptr %457)
  %458 = call ptr @type_bool__Void()
  ret ptr %458

label_2695:                                       ; preds = %label_2694
  %459 = load ptr, ptr %right_t.1073, align 8
  %460 = getelementptr inbounds nuw %TypeInfo, ptr %459, i32 0, i32 0
  %461 = load i32, ptr %460, align 4
  %462 = icmp eq i32 %461, 8
  store i1 %462, ptr %sc.173, align 1
  br label %label_2696

label_2696:                                       ; preds = %label_2695, %label_2694
  %463 = load i1, ptr %sc.173, align 1
  br i1 %463, label %label_2697, label %label_2699

label_2699:                                       ; preds = %label_2696
  %464 = load ptr, ptr %right_node.1071, align 8
  %465 = load ptr, ptr %op.1074, align 8
  %466 = call ptr @diag_quote__String(ptr %465)
  %467 = call ptr @str_concat(ptr @.str.s954, ptr %466)
  %468 = load ptr, ptr %left_t.1072, align 8
  %469 = load ptr, ptr %right_t.1073, align 8
  call void @sema_expect_assignable__Struct_ASTNode_String_Struct_TypeInfo_Struct_TypeInfo(ptr %464, ptr %467, ptr %468, ptr %469)
  %470 = load ptr, ptr %expr.1059, align 8
  %471 = call ptr @type_bool__Void()
  call void @node_set_type__Struct_ASTNode_Struct_TypeInfo(ptr %470, ptr %471)
  %472 = call ptr @type_bool__Void()
  ret ptr %472

label_2697:                                       ; preds = %label_2696
  %473 = load ptr, ptr %expr.1059, align 8
  call void @sema_error_at__Struct_ASTNode_String(ptr %473, ptr @.str.s953)
  %474 = load ptr, ptr %expr.1059, align 8
  %475 = call ptr @type_bool__Void()
  call void @node_set_type__Struct_ASTNode_Struct_TypeInfo(ptr %474, ptr %475)
  %476 = call ptr @type_bool__Void()
  ret ptr %476

label_2702:                                       ; preds = %label_2611
  %477 = load ptr, ptr %expr.1059, align 8
  %478 = getelementptr inbounds nuw %ASTNode, ptr %477, i32 0, i32 0
  %479 = load i32, ptr %478, align 4
  %480 = icmp eq i32 %479, 25
  br i1 %480, label %label_2720, label %label_2722

label_2700:                                       ; preds = %label_2611
  %481 = load ptr, ptr %expr.1059, align 8
  %482 = getelementptr inbounds nuw %ASTNode, ptr %481, i32 0, i32 5
  %483 = load ptr, ptr %482, align 8
  %484 = call ptr @ptr_to_node(ptr %483)
  store ptr %484, ptr %callee.1075, align 8
  %485 = load ptr, ptr %callee.1075, align 8
  %486 = getelementptr inbounds nuw %ASTNode, ptr %485, i32 0, i32 1
  %487 = load ptr, ptr %486, align 8
  store ptr %487, ptr %name.1076, align 8
  %488 = load ptr, ptr %module.1058, align 8
  %489 = load ptr, ptr %expr.1059, align 8
  %490 = load ptr, ptr %name.1076, align 8
  %491 = load ptr, ptr %expr.1059, align 8
  %492 = getelementptr inbounds nuw %ASTNode, ptr %491, i32 0, i32 6
  %493 = load ptr, ptr %492, align 8
  %494 = call i1 @sema_check_builtin_call__Struct_ASTNode_Struct_ASTNode_String_String(ptr %488, ptr %489, ptr %490, ptr %493)
  br i1 %494, label %label_2703, label %label_2705

label_2705:                                       ; preds = %label_2700
  %495 = load ptr, ptr %module.1058, align 8
  %496 = load ptr, ptr %expr.1059, align 8
  %497 = load ptr, ptr %name.1076, align 8
  %498 = load ptr, ptr %expr.1059, align 8
  %499 = getelementptr inbounds nuw %ASTNode, ptr %498, i32 0, i32 6
  %500 = load ptr, ptr %499, align 8
  %501 = call ptr @sema_find_function_overload__Struct_ASTNode_Struct_ASTNode_String_String(ptr %495, ptr %496, ptr %497, ptr %500)
  store ptr %501, ptr %fn_node.1078, align 8
  %502 = load ptr, ptr %expr.1059, align 8
  %503 = getelementptr inbounds nuw %ASTNode, ptr %502, i32 0, i32 6
  %504 = load ptr, ptr %503, align 8
  store ptr %504, ptr %arg_ptr.1079, align 8
  %505 = load ptr, ptr %fn_node.1078, align 8
  %506 = getelementptr inbounds nuw %ASTNode, ptr %505, i32 0, i32 5
  %507 = load ptr, ptr %506, align 8
  store ptr %507, ptr %param_ptr.1080, align 8
  br label %label_2706

label_2703:                                       ; preds = %label_2700
  %508 = load ptr, ptr %name.1076, align 8
  %509 = load ptr, ptr %expr.1059, align 8
  %510 = getelementptr inbounds nuw %ASTNode, ptr %509, i32 0, i32 6
  %511 = load ptr, ptr %510, align 8
  %512 = call ptr @sema_builtin_call_type__String_String(ptr %508, ptr %511)
  store ptr %512, ptr %builtin_t.1077, align 8
  %513 = load ptr, ptr %expr.1059, align 8
  %514 = load ptr, ptr %builtin_t.1077, align 8
  call void @node_set_type__Struct_ASTNode_Struct_TypeInfo(ptr %513, ptr %514)
  %515 = load ptr, ptr %builtin_t.1077, align 8
  ret ptr %515

label_2706:                                       ; preds = %label_2713, %label_2705
  %516 = load ptr, ptr %arg_ptr.1079, align 8
  %517 = call i32 @str_equals(ptr %516, ptr @.str.s956)
  %518 = icmp eq i32 %517, 0
  store i1 %518, ptr %sc.174, align 1
  br i1 %518, label %label_2709, label %label_2710

label_2710:                                       ; preds = %label_2709, %label_2706
  %519 = load i1, ptr %sc.174, align 1
  br i1 %519, label %label_2707, label %label_2708

label_2709:                                       ; preds = %label_2706
  %520 = load ptr, ptr %param_ptr.1080, align 8
  %521 = call i32 @str_equals(ptr %520, ptr @.str.s957)
  %522 = icmp eq i32 %521, 0
  store i1 %522, ptr %sc.174, align 1
  br label %label_2710

label_2708:                                       ; preds = %label_2710
  %523 = call ptr @type_void__Void()
  store ptr %523, ptr %ret_t.1084, align 8
  %524 = load ptr, ptr %fn_node.1078, align 8
  %525 = getelementptr inbounds nuw %ASTNode, ptr %524, i32 0, i32 0
  %526 = load i32, ptr %525, align 4
  %527 = icmp eq i32 %526, 4
  br i1 %527, label %label_2714, label %label_2715

label_2707:                                       ; preds = %label_2710
  %528 = load ptr, ptr %arg_ptr.1079, align 8
  %529 = call ptr @ptr_to_node(ptr %528)
  store ptr %529, ptr %arg_node.1081, align 8
  %530 = load ptr, ptr %param_ptr.1080, align 8
  %531 = call ptr @ptr_to_node(ptr %530)
  store ptr %531, ptr %param_node.1082, align 8
  %532 = load ptr, ptr %module.1058, align 8
  %533 = load ptr, ptr %param_node.1082, align 8
  %534 = getelementptr inbounds nuw %ASTNode, ptr %533, i32 0, i32 5
  %535 = load ptr, ptr %534, align 8
  %536 = call ptr @ptr_to_node(ptr %535)
  %537 = call ptr @sema_annotation_type__Struct_ASTNode_Struct_ASTNode(ptr %532, ptr %536)
  store ptr %537, ptr %param_t.1083, align 8
  %538 = load ptr, ptr %module.1058, align 8
  %539 = load ptr, ptr %arg_node.1081, align 8
  %540 = load ptr, ptr %param_t.1083, align 8
  %541 = load ptr, ptr %name.1076, align 8
  %542 = call ptr @diag_quote__String(ptr %541)
  %543 = call ptr @str_concat(ptr %542, ptr @.str.s958)
  %544 = call ptr @sema_check_value__Struct_ASTNode_Struct_ASTNode_Struct_TypeInfo_String(ptr %538, ptr %539, ptr %540, ptr %543)
  %545 = load ptr, ptr %param_node.1082, align 8
  %546 = getelementptr inbounds nuw %ASTNode, ptr %545, i32 0, i32 2
  %547 = load ptr, ptr %546, align 8
  %548 = call i32 @str_equals(ptr %547, ptr @.str.s959)
  %549 = icmp eq i32 %548, 1
  br i1 %549, label %label_2711, label %label_2713

label_2713:                                       ; preds = %label_2711, %label_2707
  %550 = load ptr, ptr %arg_node.1081, align 8
  %551 = getelementptr inbounds nuw %ASTNode, ptr %550, i32 0, i32 8
  %552 = load ptr, ptr %551, align 8
  store ptr %552, ptr %arg_ptr.1079, align 8
  %553 = load ptr, ptr %param_node.1082, align 8
  %554 = getelementptr inbounds nuw %ASTNode, ptr %553, i32 0, i32 8
  %555 = load ptr, ptr %554, align 8
  store ptr %555, ptr %param_ptr.1080, align 8
  br label %label_2706

label_2711:                                       ; preds = %label_2707
  %556 = load ptr, ptr %arg_node.1081, align 8
  call void @sema_move_operand__Struct_ASTNode(ptr %556)
  br label %label_2713

label_2715:                                       ; preds = %label_2708
  %557 = load ptr, ptr %module.1058, align 8
  %558 = load ptr, ptr %fn_node.1078, align 8
  %559 = getelementptr inbounds nuw %ASTNode, ptr %558, i32 0, i32 6
  %560 = load ptr, ptr %559, align 8
  %561 = call ptr @sema_declared_return_type__Struct_ASTNode_String(ptr %557, ptr %560)
  store ptr %561, ptr %ret_t.1084, align 8
  br label %label_2716

label_2714:                                       ; preds = %label_2708
  %562 = load ptr, ptr %module.1058, align 8
  %563 = load ptr, ptr %fn_node.1078, align 8
  %564 = getelementptr inbounds nuw %ASTNode, ptr %563, i32 0, i32 7
  %565 = load ptr, ptr %564, align 8
  %566 = call ptr @sema_declared_return_type__Struct_ASTNode_String(ptr %562, ptr %565)
  store ptr %566, ptr %ret_t.1084, align 8
  %567 = load ptr, ptr %name.1076, align 8
  %568 = call i32 @str_equals(ptr %567, ptr @.str.s960)
  %569 = icmp eq i32 %568, 1
  br i1 %569, label %label_2717, label %label_2719

label_2719:                                       ; preds = %label_2717, %label_2714
  br label %label_2716

label_2717:                                       ; preds = %label_2714
  %570 = call ptr @type_int__Void()
  store ptr %570, ptr %ret_t.1084, align 8
  br label %label_2719

label_2716:                                       ; preds = %label_2715, %label_2719
  %571 = load ptr, ptr %expr.1059, align 8
  %572 = load ptr, ptr %module.1058, align 8
  %573 = load ptr, ptr %fn_node.1078, align 8
  %574 = call ptr @sema_function_symbol__Struct_ASTNode_Struct_ASTNode(ptr %572, ptr %573)
  %575 = getelementptr inbounds nuw %ASTNode, ptr %571, i32 0, i32 2
  store ptr %574, ptr %575, align 8
  %576 = load ptr, ptr %expr.1059, align 8
  %577 = load ptr, ptr %ret_t.1084, align 8
  call void @node_set_type__Struct_ASTNode_Struct_TypeInfo(ptr %576, ptr %577)
  %578 = load ptr, ptr %ret_t.1084, align 8
  ret ptr %578

label_2722:                                       ; preds = %label_2702
  %579 = load ptr, ptr %expr.1059, align 8
  %580 = getelementptr inbounds nuw %ASTNode, ptr %579, i32 0, i32 0
  %581 = load i32, ptr %580, align 4
  %582 = icmp eq i32 %581, 27
  br i1 %582, label %label_2731, label %label_2733

label_2720:                                       ; preds = %label_2702
  %583 = load ptr, ptr %expr.1059, align 8
  %584 = getelementptr inbounds nuw %ASTNode, ptr %583, i32 0, i32 5
  %585 = load ptr, ptr %584, align 8
  %586 = call ptr @ptr_to_node(ptr %585)
  store ptr %586, ptr %object_node.1085, align 8
  %587 = load ptr, ptr %object_node.1085, align 8
  %588 = getelementptr inbounds nuw %ASTNode, ptr %587, i32 0, i32 0
  %589 = load i32, ptr %588, align 4
  %590 = icmp eq i32 %589, 23
  store i1 %590, ptr %sc.175, align 1
  br i1 %590, label %label_2723, label %label_2724

label_2724:                                       ; preds = %label_2723, %label_2720
  %591 = load i1, ptr %sc.175, align 1
  br i1 %591, label %label_2725, label %label_2727

label_2723:                                       ; preds = %label_2720
  %592 = load ptr, ptr %module.1058, align 8
  %593 = load ptr, ptr %object_node.1085, align 8
  %594 = getelementptr inbounds nuw %ASTNode, ptr %593, i32 0, i32 1
  %595 = load ptr, ptr %594, align 8
  %596 = load ptr, ptr %expr.1059, align 8
  %597 = getelementptr inbounds nuw %ASTNode, ptr %596, i32 0, i32 1
  %598 = load ptr, ptr %597, align 8
  %599 = call i1 @sema_enum_has_variant__Struct_ASTNode_String_String(ptr %592, ptr %595, ptr %598)
  store i1 %599, ptr %sc.175, align 1
  br label %label_2724

label_2727:                                       ; preds = %label_2724
  %600 = load ptr, ptr %module.1058, align 8
  %601 = load ptr, ptr %object_node.1085, align 8
  %602 = call ptr @sema_expr__Struct_ASTNode_Struct_ASTNode(ptr %600, ptr %601)
  store ptr %602, ptr %object_t.1086, align 8
  %603 = load ptr, ptr %object_t.1086, align 8
  %604 = getelementptr inbounds nuw %TypeInfo, ptr %603, i32 0, i32 0
  %605 = load i32, ptr %604, align 4
  %606 = icmp ne i32 %605, 8
  br i1 %606, label %label_2728, label %label_2730

label_2725:                                       ; preds = %label_2724
  %607 = load ptr, ptr %expr.1059, align 8
  %608 = call ptr @type_int__Void()
  call void @node_set_type__Struct_ASTNode_Struct_TypeInfo(ptr %607, ptr %608)
  %609 = call ptr @type_int__Void()
  ret ptr %609

label_2730:                                       ; preds = %label_2727
  %610 = load ptr, ptr %module.1058, align 8
  %611 = load ptr, ptr %expr.1059, align 8
  %612 = load ptr, ptr %object_t.1086, align 8
  %613 = getelementptr inbounds nuw %TypeInfo, ptr %612, i32 0, i32 1
  %614 = load ptr, ptr %613, align 8
  %615 = load ptr, ptr %expr.1059, align 8
  %616 = getelementptr inbounds nuw %ASTNode, ptr %615, i32 0, i32 1
  %617 = load ptr, ptr %616, align 8
  %618 = call ptr @sema_find_struct_field_type__Struct_ASTNode_Struct_ASTNode_String_String(ptr %610, ptr %611, ptr %614, ptr %617)
  store ptr %618, ptr %field_t.1087, align 8
  %619 = load ptr, ptr %expr.1059, align 8
  %620 = load ptr, ptr %field_t.1087, align 8
  call void @node_set_type__Struct_ASTNode_Struct_TypeInfo(ptr %619, ptr %620)
  %621 = load ptr, ptr %field_t.1087, align 8
  ret ptr %621

label_2728:                                       ; preds = %label_2727
  %622 = load ptr, ptr %object_node.1085, align 8
  %623 = load ptr, ptr %object_t.1086, align 8
  %624 = call ptr @type_display__Struct_TypeInfo(ptr %623)
  %625 = call ptr @str_concat(ptr @.str.s961, ptr %624)
  call void @sema_error_at__Struct_ASTNode_String(ptr %622, ptr %625)
  %626 = load ptr, ptr %expr.1059, align 8
  %627 = call ptr @type_invalid__Void()
  call void @node_set_type__Struct_ASTNode_Struct_TypeInfo(ptr %626, ptr %627)
  %628 = call ptr @type_invalid__Void()
  ret ptr %628

label_2733:                                       ; preds = %label_2722
  %629 = load ptr, ptr %expr.1059, align 8
  %630 = getelementptr inbounds nuw %ASTNode, ptr %629, i32 0, i32 0
  %631 = load i32, ptr %630, align 4
  %632 = icmp eq i32 %631, 26
  br i1 %632, label %label_2740, label %label_2742

label_2731:                                       ; preds = %label_2722
  %633 = load ptr, ptr %expr.1059, align 8
  %634 = getelementptr inbounds nuw %ASTNode, ptr %633, i32 0, i32 5
  %635 = load ptr, ptr %634, align 8
  store ptr %635, ptr %elem_ptr.1088, align 8
  %636 = load ptr, ptr %elem_ptr.1088, align 8
  %637 = call i32 @str_equals(ptr %636, ptr @.str.s962)
  %638 = icmp eq i32 %637, 1
  br i1 %638, label %label_2734, label %label_2736

label_2736:                                       ; preds = %label_2731
  %639 = load ptr, ptr %module.1058, align 8
  %640 = load ptr, ptr %elem_ptr.1088, align 8
  %641 = call ptr @ptr_to_node(ptr %640)
  %642 = call ptr @sema_expr__Struct_ASTNode_Struct_ASTNode(ptr %639, ptr %641)
  store ptr %642, ptr %first_t.1090, align 8
  %643 = load ptr, ptr %elem_ptr.1088, align 8
  %644 = call ptr @ptr_to_node(ptr %643)
  %645 = getelementptr inbounds nuw %ASTNode, ptr %644, i32 0, i32 8
  %646 = load ptr, ptr %645, align 8
  store ptr %646, ptr %elem_ptr.1088, align 8
  br label %label_2737

label_2734:                                       ; preds = %label_2731
  %647 = call ptr @type_invalid__Void()
  %648 = call ptr @type_array__Struct_TypeInfo(ptr %647)
  store ptr %648, ptr %arr_t.1089, align 8
  %649 = load ptr, ptr %expr.1059, align 8
  %650 = load ptr, ptr %arr_t.1089, align 8
  call void @node_set_type__Struct_ASTNode_Struct_TypeInfo(ptr %649, ptr %650)
  %651 = load ptr, ptr %arr_t.1089, align 8
  ret ptr %651

label_2737:                                       ; preds = %label_2738, %label_2736
  %652 = load ptr, ptr %elem_ptr.1088, align 8
  %653 = call i32 @str_equals(ptr %652, ptr @.str.s963)
  %654 = icmp eq i32 %653, 0
  br i1 %654, label %label_2738, label %label_2739

label_2739:                                       ; preds = %label_2737
  %655 = load ptr, ptr %first_t.1090, align 8
  %656 = call ptr @type_array__Struct_TypeInfo(ptr %655)
  store ptr %656, ptr %arr_t2.1093, align 8
  %657 = load ptr, ptr %expr.1059, align 8
  %658 = load ptr, ptr %arr_t2.1093, align 8
  call void @node_set_type__Struct_ASTNode_Struct_TypeInfo(ptr %657, ptr %658)
  %659 = load ptr, ptr %arr_t2.1093, align 8
  ret ptr %659

label_2738:                                       ; preds = %label_2737
  %660 = load ptr, ptr %elem_ptr.1088, align 8
  %661 = call ptr @ptr_to_node(ptr %660)
  store ptr %661, ptr %elem.1091, align 8
  %662 = load ptr, ptr %module.1058, align 8
  %663 = load ptr, ptr %elem.1091, align 8
  %664 = call ptr @sema_expr__Struct_ASTNode_Struct_ASTNode(ptr %662, ptr %663)
  store ptr %664, ptr %elem_t.1092, align 8
  %665 = load ptr, ptr %elem.1091, align 8
  %666 = load ptr, ptr %first_t.1090, align 8
  %667 = load ptr, ptr %elem_t.1092, align 8
  call void @sema_expect_assignable__Struct_ASTNode_String_Struct_TypeInfo_Struct_TypeInfo(ptr %665, ptr @.str.s964, ptr %666, ptr %667)
  %668 = load ptr, ptr %elem.1091, align 8
  %669 = getelementptr inbounds nuw %ASTNode, ptr %668, i32 0, i32 8
  %670 = load ptr, ptr %669, align 8
  store ptr %670, ptr %elem_ptr.1088, align 8
  br label %label_2737

label_2742:                                       ; preds = %label_2733
  %671 = load ptr, ptr %expr.1059, align 8
  %672 = getelementptr inbounds nuw %ASTNode, ptr %671, i32 0, i32 0
  %673 = load i32, ptr %672, align 4
  %674 = icmp eq i32 %673, 28
  br i1 %674, label %label_2746, label %label_2748

label_2740:                                       ; preds = %label_2733
  %675 = load ptr, ptr %module.1058, align 8
  %676 = load ptr, ptr %expr.1059, align 8
  %677 = getelementptr inbounds nuw %ASTNode, ptr %676, i32 0, i32 5
  %678 = load ptr, ptr %677, align 8
  %679 = call ptr @ptr_to_node(ptr %678)
  %680 = call ptr @sema_expr__Struct_ASTNode_Struct_ASTNode(ptr %675, ptr %679)
  store ptr %680, ptr %array_t.1094, align 8
  %681 = load ptr, ptr %module.1058, align 8
  %682 = load ptr, ptr %expr.1059, align 8
  %683 = getelementptr inbounds nuw %ASTNode, ptr %682, i32 0, i32 6
  %684 = load ptr, ptr %683, align 8
  %685 = call ptr @ptr_to_node(ptr %684)
  %686 = call ptr @sema_expr__Struct_ASTNode_Struct_ASTNode(ptr %681, ptr %685)
  store ptr %686, ptr %index_t.1095, align 8
  %687 = load ptr, ptr %expr.1059, align 8
  %688 = getelementptr inbounds nuw %ASTNode, ptr %687, i32 0, i32 6
  %689 = load ptr, ptr %688, align 8
  %690 = call ptr @ptr_to_node(ptr %689)
  %691 = call ptr @type_int__Void()
  %692 = load ptr, ptr %index_t.1095, align 8
  call void @sema_expect_assignable__Struct_ASTNode_String_Struct_TypeInfo_Struct_TypeInfo(ptr %690, ptr @.str.s965, ptr %691, ptr %692)
  %693 = load ptr, ptr %array_t.1094, align 8
  %694 = getelementptr inbounds nuw %TypeInfo, ptr %693, i32 0, i32 0
  %695 = load i32, ptr %694, align 4
  %696 = icmp ne i32 %695, 10
  br i1 %696, label %label_2743, label %label_2745

label_2745:                                       ; preds = %label_2740
  %697 = load ptr, ptr %array_t.1094, align 8
  %698 = getelementptr inbounds nuw %TypeInfo, ptr %697, i32 0, i32 3
  %699 = load ptr, ptr %698, align 8
  %700 = call ptr @ptr_to_type(ptr %699)
  store ptr %700, ptr %elem_t.1096, align 8
  %701 = load ptr, ptr %expr.1059, align 8
  %702 = load ptr, ptr %elem_t.1096, align 8
  call void @node_set_type__Struct_ASTNode_Struct_TypeInfo(ptr %701, ptr %702)
  %703 = load ptr, ptr %elem_t.1096, align 8
  ret ptr %703

label_2743:                                       ; preds = %label_2740
  %704 = load ptr, ptr %expr.1059, align 8
  %705 = load ptr, ptr %array_t.1094, align 8
  %706 = call ptr @type_display__Struct_TypeInfo(ptr %705)
  %707 = call ptr @str_concat(ptr @.str.s966, ptr %706)
  call void @sema_error_at__Struct_ASTNode_String(ptr %704, ptr %707)
  %708 = load ptr, ptr %expr.1059, align 8
  %709 = call ptr @type_invalid__Void()
  call void @node_set_type__Struct_ASTNode_Struct_TypeInfo(ptr %708, ptr %709)
  %710 = call ptr @type_invalid__Void()
  ret ptr %710

label_2748:                                       ; preds = %label_2742
  %711 = load ptr, ptr %expr.1059, align 8
  call void @sema_error_at__Struct_ASTNode_String(ptr %711, ptr @.str.s970)
  %712 = call ptr @type_invalid__Void()
  ret ptr %712

label_2746:                                       ; preds = %label_2742
  %713 = load ptr, ptr %module.1058, align 8
  %714 = load ptr, ptr %expr.1059, align 8
  %715 = getelementptr inbounds nuw %ASTNode, ptr %714, i32 0, i32 1
  %716 = load ptr, ptr %715, align 8
  %717 = call i1 @sema_has_struct__Struct_ASTNode_String(ptr %713, ptr %716)
  %718 = icmp eq i1 %717, false
  br i1 %718, label %label_2749, label %label_2751

label_2751:                                       ; preds = %label_2746
  %719 = load ptr, ptr %expr.1059, align 8
  %720 = getelementptr inbounds nuw %ASTNode, ptr %719, i32 0, i32 5
  %721 = load ptr, ptr %720, align 8
  store ptr %721, ptr %field_ptr.1097, align 8
  br label %label_2752

label_2749:                                       ; preds = %label_2746
  %722 = load ptr, ptr %expr.1059, align 8
  %723 = load ptr, ptr %expr.1059, align 8
  %724 = getelementptr inbounds nuw %ASTNode, ptr %723, i32 0, i32 1
  %725 = load ptr, ptr %724, align 8
  %726 = call ptr @diag_quote__String(ptr %725)
  %727 = call ptr @str_concat(ptr @.str.s967, ptr %726)
  call void @sema_error_at__Struct_ASTNode_String(ptr %722, ptr %727)
  %728 = load ptr, ptr %expr.1059, align 8
  %729 = call ptr @type_invalid__Void()
  call void @node_set_type__Struct_ASTNode_Struct_TypeInfo(ptr %728, ptr %729)
  %730 = call ptr @type_invalid__Void()
  ret ptr %730

label_2752:                                       ; preds = %label_2753, %label_2751
  %731 = load ptr, ptr %field_ptr.1097, align 8
  %732 = call i32 @str_equals(ptr %731, ptr @.str.s968)
  %733 = icmp eq i32 %732, 0
  br i1 %733, label %label_2753, label %label_2754

label_2754:                                       ; preds = %label_2752
  %734 = load ptr, ptr %expr.1059, align 8
  %735 = getelementptr inbounds nuw %ASTNode, ptr %734, i32 0, i32 1
  %736 = load ptr, ptr %735, align 8
  %737 = call ptr @type_struct__String(ptr %736)
  store ptr %737, ptr %struct_t.1100, align 8
  %738 = load ptr, ptr %expr.1059, align 8
  %739 = load ptr, ptr %struct_t.1100, align 8
  call void @node_set_type__Struct_ASTNode_Struct_TypeInfo(ptr %738, ptr %739)
  %740 = load ptr, ptr %struct_t.1100, align 8
  ret ptr %740

label_2753:                                       ; preds = %label_2752
  %741 = load ptr, ptr %field_ptr.1097, align 8
  %742 = call ptr @ptr_to_node(ptr %741)
  store ptr %742, ptr %field.1098, align 8
  %743 = load ptr, ptr %module.1058, align 8
  %744 = load ptr, ptr %field.1098, align 8
  %745 = load ptr, ptr %expr.1059, align 8
  %746 = getelementptr inbounds nuw %ASTNode, ptr %745, i32 0, i32 1
  %747 = load ptr, ptr %746, align 8
  %748 = load ptr, ptr %field.1098, align 8
  %749 = getelementptr inbounds nuw %ASTNode, ptr %748, i32 0, i32 1
  %750 = load ptr, ptr %749, align 8
  %751 = call ptr @sema_find_struct_field_type__Struct_ASTNode_Struct_ASTNode_String_String(ptr %743, ptr %744, ptr %747, ptr %750)
  store ptr %751, ptr %expected.1099, align 8
  %752 = load ptr, ptr %module.1058, align 8
  %753 = load ptr, ptr %field.1098, align 8
  %754 = getelementptr inbounds nuw %ASTNode, ptr %753, i32 0, i32 5
  %755 = load ptr, ptr %754, align 8
  %756 = call ptr @ptr_to_node(ptr %755)
  %757 = load ptr, ptr %expected.1099, align 8
  %758 = load ptr, ptr %field.1098, align 8
  %759 = getelementptr inbounds nuw %ASTNode, ptr %758, i32 0, i32 1
  %760 = load ptr, ptr %759, align 8
  %761 = call ptr @diag_quote__String(ptr %760)
  %762 = call ptr @str_concat(ptr @.str.s969, ptr %761)
  %763 = call ptr @sema_check_value__Struct_ASTNode_Struct_ASTNode_Struct_TypeInfo_String(ptr %752, ptr %756, ptr %757, ptr %762)
  %764 = load ptr, ptr %field.1098, align 8
  %765 = getelementptr inbounds nuw %ASTNode, ptr %764, i32 0, i32 5
  %766 = load ptr, ptr %765, align 8
  %767 = call ptr @ptr_to_node(ptr %766)
  call void @sema_move_operand__Struct_ASTNode(ptr %767)
  %768 = load ptr, ptr %field.1098, align 8
  %769 = getelementptr inbounds nuw %ASTNode, ptr %768, i32 0, i32 8
  %770 = load ptr, ptr %769, align 8
  store ptr %770, ptr %field_ptr.1097, align 8
  br label %label_2752
}

define ptr @sema_find_function__Struct_ASTNode_String(ptr %0, ptr %1) {
entry:
  %module.982 = alloca ptr, align 8
  store ptr %0, ptr %module.982, align 8
  %name.983 = alloca ptr, align 8
  store ptr %1, ptr %name.983, align 8
  %2 = load ptr, ptr %module.982, align 8
  %3 = getelementptr inbounds nuw %ASTNode, ptr %2, i32 0, i32 5
  %4 = load ptr, ptr %3, align 8
  %stmt_ptr.984 = alloca ptr, align 8
  store ptr %4, ptr %stmt_ptr.984, align 8
  %stmt.985 = alloca ptr, align 8
  %sc.121 = alloca i1, align 1
  %sc.122 = alloca i1, align 1
  br label %label_2294

label_2294:                                       ; preds = %label_2303, %entry
  %5 = load ptr, ptr %stmt_ptr.984, align 8
  %6 = call i32 @str_equals(ptr %5, ptr @.str.s840)
  %7 = icmp eq i32 %6, 0
  br i1 %7, label %label_2295, label %label_2296

label_2296:                                       ; preds = %label_2294
  %8 = call ptr @create_node__Enum_NodeKind(i32 0)
  ret ptr %8

label_2295:                                       ; preds = %label_2294
  %9 = load ptr, ptr %stmt_ptr.984, align 8
  %10 = call ptr @ptr_to_node(ptr %9)
  store ptr %10, ptr %stmt.985, align 8
  %11 = load ptr, ptr %stmt.985, align 8
  %12 = getelementptr inbounds nuw %ASTNode, ptr %11, i32 0, i32 0
  %13 = load i32, ptr %12, align 4
  %14 = icmp eq i32 %13, 4
  store i1 %14, ptr %sc.122, align 1
  br i1 %14, label %label_2300, label %label_2299

label_2299:                                       ; preds = %label_2295
  %15 = load ptr, ptr %stmt.985, align 8
  %16 = getelementptr inbounds nuw %ASTNode, ptr %15, i32 0, i32 0
  %17 = load i32, ptr %16, align 4
  %18 = icmp eq i32 %17, 2
  store i1 %18, ptr %sc.122, align 1
  br label %label_2300

label_2300:                                       ; preds = %label_2299, %label_2295
  %19 = load i1, ptr %sc.122, align 1
  store i1 %19, ptr %sc.121, align 1
  br i1 %19, label %label_2297, label %label_2298

label_2298:                                       ; preds = %label_2297, %label_2300
  %20 = load i1, ptr %sc.121, align 1
  br i1 %20, label %label_2301, label %label_2303

label_2297:                                       ; preds = %label_2300
  %21 = load ptr, ptr %stmt.985, align 8
  %22 = getelementptr inbounds nuw %ASTNode, ptr %21, i32 0, i32 1
  %23 = load ptr, ptr %22, align 8
  %24 = load ptr, ptr %name.983, align 8
  %25 = call i32 @str_equals(ptr %23, ptr %24)
  %26 = icmp eq i32 %25, 1
  store i1 %26, ptr %sc.121, align 1
  br label %label_2298

label_2303:                                       ; preds = %label_2298
  %27 = load ptr, ptr %stmt.985, align 8
  %28 = getelementptr inbounds nuw %ASTNode, ptr %27, i32 0, i32 8
  %29 = load ptr, ptr %28, align 8
  store ptr %29, ptr %stmt_ptr.984, align 8
  br label %label_2294

label_2301:                                       ; preds = %label_2298
  %30 = load ptr, ptr %stmt.985, align 8
  ret ptr %30
}

define i1 @sema_arg_matches_type__Struct_ASTNode_Struct_ASTNode_Struct_TypeInfo(ptr %0, ptr %1, ptr %2) {
entry:
  %module.986 = alloca ptr, align 8
  store ptr %0, ptr %module.986, align 8
  %arg_node.987 = alloca ptr, align 8
  store ptr %1, ptr %arg_node.987, align 8
  %expected.988 = alloca ptr, align 8
  store ptr %2, ptr %expected.988, align 8
  %sc.123 = alloca i1, align 1
  %sc.124 = alloca i1, align 1
  %3 = load ptr, ptr %expected.988, align 8
  %4 = call i1 @type_is_valid__Struct_TypeInfo(ptr %3)
  store i1 %4, ptr %sc.124, align 1
  %actual.989 = alloca ptr, align 8
  br i1 %4, label %label_2306, label %label_2307

label_2307:                                       ; preds = %label_2306, %entry
  %5 = load i1, ptr %sc.124, align 1
  store i1 %5, ptr %sc.123, align 1
  br i1 %5, label %label_2304, label %label_2305

label_2306:                                       ; preds = %entry
  %6 = load ptr, ptr %expected.988, align 8
  %7 = getelementptr inbounds nuw %TypeInfo, ptr %6, i32 0, i32 0
  %8 = load i32, ptr %7, align 4
  %9 = icmp eq i32 %8, 2
  store i1 %9, ptr %sc.124, align 1
  br label %label_2307

label_2305:                                       ; preds = %label_2304, %label_2307
  %10 = load i1, ptr %sc.123, align 1
  br i1 %10, label %label_2308, label %label_2310

label_2304:                                       ; preds = %label_2307
  %11 = load ptr, ptr %arg_node.987, align 8
  %12 = call i1 @sema_is_int_literal__Struct_ASTNode(ptr %11)
  store i1 %12, ptr %sc.123, align 1
  br label %label_2305

label_2310:                                       ; preds = %label_2305
  %13 = load ptr, ptr %module.986, align 8
  %14 = load ptr, ptr %arg_node.987, align 8
  %15 = call ptr @sema_expr__Struct_ASTNode_Struct_ASTNode(ptr %13, ptr %14)
  store ptr %15, ptr %actual.989, align 8
  %16 = load ptr, ptr %expected.988, align 8
  %17 = load ptr, ptr %actual.989, align 8
  %18 = call i1 @sema_types_match__Struct_TypeInfo_Struct_TypeInfo(ptr %16, ptr %17)
  ret i1 %18

label_2308:                                       ; preds = %label_2305
  ret i1 true
}

define i1 @sema_signature_matches_call__Struct_ASTNode_Struct_ASTNode_String(ptr %0, ptr %1, ptr %2) {
entry:
  %module.990 = alloca ptr, align 8
  store ptr %0, ptr %module.990, align 8
  %fn_node.991 = alloca ptr, align 8
  store ptr %1, ptr %fn_node.991, align 8
  %arg_ptr.992 = alloca ptr, align 8
  store ptr %2, ptr %arg_ptr.992, align 8
  %3 = load ptr, ptr %arg_ptr.992, align 8
  %arg.993 = alloca ptr, align 8
  store ptr %3, ptr %arg.993, align 8
  %4 = load ptr, ptr %fn_node.991, align 8
  %5 = getelementptr inbounds nuw %ASTNode, ptr %4, i32 0, i32 5
  %6 = load ptr, ptr %5, align 8
  %param.994 = alloca ptr, align 8
  store ptr %6, ptr %param.994, align 8
  %sc.125 = alloca i1, align 1
  %arg_node.995 = alloca ptr, align 8
  %param_node.996 = alloca ptr, align 8
  %param_t.997 = alloca ptr, align 8
  %sc.126 = alloca i1, align 1
  br label %label_2311

label_2311:                                       ; preds = %label_2318, %entry
  %7 = load ptr, ptr %arg.993, align 8
  %8 = call i32 @str_equals(ptr %7, ptr @.str.s841)
  %9 = icmp eq i32 %8, 0
  store i1 %9, ptr %sc.125, align 1
  br i1 %9, label %label_2314, label %label_2315

label_2315:                                       ; preds = %label_2314, %label_2311
  %10 = load i1, ptr %sc.125, align 1
  br i1 %10, label %label_2312, label %label_2313

label_2314:                                       ; preds = %label_2311
  %11 = load ptr, ptr %param.994, align 8
  %12 = call i32 @str_equals(ptr %11, ptr @.str.s842)
  %13 = icmp eq i32 %12, 0
  store i1 %13, ptr %sc.125, align 1
  br label %label_2315

label_2313:                                       ; preds = %label_2315
  %14 = load ptr, ptr %arg.993, align 8
  %15 = call i32 @str_equals(ptr %14, ptr @.str.s843)
  %16 = icmp eq i32 %15, 1
  store i1 %16, ptr %sc.126, align 1
  br i1 %16, label %label_2319, label %label_2320

label_2312:                                       ; preds = %label_2315
  %17 = load ptr, ptr %arg.993, align 8
  %18 = call ptr @ptr_to_node(ptr %17)
  store ptr %18, ptr %arg_node.995, align 8
  %19 = load ptr, ptr %param.994, align 8
  %20 = call ptr @ptr_to_node(ptr %19)
  store ptr %20, ptr %param_node.996, align 8
  %21 = load ptr, ptr %module.990, align 8
  %22 = load ptr, ptr %param_node.996, align 8
  %23 = getelementptr inbounds nuw %ASTNode, ptr %22, i32 0, i32 5
  %24 = load ptr, ptr %23, align 8
  %25 = call ptr @ptr_to_node(ptr %24)
  %26 = call ptr @sema_annotation_type__Struct_ASTNode_Struct_ASTNode(ptr %21, ptr %25)
  store ptr %26, ptr %param_t.997, align 8
  %27 = load ptr, ptr %module.990, align 8
  %28 = load ptr, ptr %arg_node.995, align 8
  %29 = load ptr, ptr %param_t.997, align 8
  %30 = call i1 @sema_arg_matches_type__Struct_ASTNode_Struct_ASTNode_Struct_TypeInfo(ptr %27, ptr %28, ptr %29)
  %31 = icmp eq i1 %30, false
  br i1 %31, label %label_2316, label %label_2318

label_2318:                                       ; preds = %label_2312
  %32 = load ptr, ptr %arg_node.995, align 8
  %33 = getelementptr inbounds nuw %ASTNode, ptr %32, i32 0, i32 8
  %34 = load ptr, ptr %33, align 8
  store ptr %34, ptr %arg.993, align 8
  %35 = load ptr, ptr %param_node.996, align 8
  %36 = getelementptr inbounds nuw %ASTNode, ptr %35, i32 0, i32 8
  %37 = load ptr, ptr %36, align 8
  store ptr %37, ptr %param.994, align 8
  br label %label_2311

label_2316:                                       ; preds = %label_2312
  ret i1 false

label_2320:                                       ; preds = %label_2319, %label_2313
  %38 = load i1, ptr %sc.126, align 1
  ret i1 %38

label_2319:                                       ; preds = %label_2313
  %39 = load ptr, ptr %param.994, align 8
  %40 = call i32 @str_equals(ptr %39, ptr @.str.s844)
  %41 = icmp eq i32 %40, 1
  store i1 %41, ptr %sc.126, align 1
  br label %label_2320
}

define i1 @sema_has_function_definition__Struct_ASTNode_String(ptr %0, ptr %1) {
entry:
  %module.998 = alloca ptr, align 8
  store ptr %0, ptr %module.998, align 8
  %name.999 = alloca ptr, align 8
  store ptr %1, ptr %name.999, align 8
  %2 = load ptr, ptr %module.998, align 8
  %3 = getelementptr inbounds nuw %ASTNode, ptr %2, i32 0, i32 5
  %4 = load ptr, ptr %3, align 8
  %scan_ptr.1000 = alloca ptr, align 8
  store ptr %4, ptr %scan_ptr.1000, align 8
  %scan.1001 = alloca ptr, align 8
  %sc.127 = alloca i1, align 1
  br label %label_2321

label_2321:                                       ; preds = %label_2328, %entry
  %5 = load ptr, ptr %scan_ptr.1000, align 8
  %6 = call i32 @str_equals(ptr %5, ptr @.str.s845)
  %7 = icmp eq i32 %6, 0
  br i1 %7, label %label_2322, label %label_2323

label_2323:                                       ; preds = %label_2321
  ret i1 false

label_2322:                                       ; preds = %label_2321
  %8 = load ptr, ptr %scan_ptr.1000, align 8
  %9 = call ptr @ptr_to_node(ptr %8)
  store ptr %9, ptr %scan.1001, align 8
  %10 = load ptr, ptr %scan.1001, align 8
  %11 = getelementptr inbounds nuw %ASTNode, ptr %10, i32 0, i32 0
  %12 = load i32, ptr %11, align 4
  %13 = icmp eq i32 %12, 4
  store i1 %13, ptr %sc.127, align 1
  br i1 %13, label %label_2324, label %label_2325

label_2325:                                       ; preds = %label_2324, %label_2322
  %14 = load i1, ptr %sc.127, align 1
  br i1 %14, label %label_2326, label %label_2328

label_2324:                                       ; preds = %label_2322
  %15 = load ptr, ptr %scan.1001, align 8
  %16 = getelementptr inbounds nuw %ASTNode, ptr %15, i32 0, i32 1
  %17 = load ptr, ptr %16, align 8
  %18 = load ptr, ptr %name.999, align 8
  %19 = call i32 @str_equals(ptr %17, ptr %18)
  %20 = icmp eq i32 %19, 1
  store i1 %20, ptr %sc.127, align 1
  br label %label_2325

label_2328:                                       ; preds = %label_2325
  %21 = load ptr, ptr %scan.1001, align 8
  %22 = getelementptr inbounds nuw %ASTNode, ptr %21, i32 0, i32 8
  %23 = load ptr, ptr %22, align 8
  store ptr %23, ptr %scan_ptr.1000, align 8
  br label %label_2321

label_2326:                                       ; preds = %label_2325
  ret i1 true
}

define ptr @sema_find_function_overload__Struct_ASTNode_Struct_ASTNode_String_String(ptr %0, ptr %1, ptr %2, ptr %3) {
entry:
  %module.1002 = alloca ptr, align 8
  store ptr %0, ptr %module.1002, align 8
  %call.1003 = alloca ptr, align 8
  store ptr %1, ptr %call.1003, align 8
  %name.1004 = alloca ptr, align 8
  store ptr %2, ptr %name.1004, align 8
  %arg_ptr.1005 = alloca ptr, align 8
  store ptr %3, ptr %arg_ptr.1005, align 8
  %best_ptr.1006 = alloca ptr, align 8
  store ptr @.str.s846, ptr %best_ptr.1006, align 8
  %match_count.1007 = alloca i32, align 4
  store i32 0, ptr %match_count.1007, align 4
  %name_seen.1008 = alloca i1, align 1
  store i1 false, ptr %name_seen.1008, align 1
  %4 = load ptr, ptr %module.1002, align 8
  %5 = load ptr, ptr %name.1004, align 8
  %6 = call i1 @sema_has_function_definition__Struct_ASTNode_String(ptr %4, ptr %5)
  %definition_exists.1009 = alloca i1, align 1
  store i1 %6, ptr %definition_exists.1009, align 1
  %7 = load ptr, ptr %module.1002, align 8
  %8 = getelementptr inbounds nuw %ASTNode, ptr %7, i32 0, i32 5
  %9 = load ptr, ptr %8, align 8
  %stmt_ptr.1010 = alloca ptr, align 8
  store ptr %9, ptr %stmt_ptr.1010, align 8
  %stmt.1011 = alloca ptr, align 8
  %is_candidate.1012 = alloca i1, align 1
  %sc.128 = alloca i1, align 1
  %sc.129 = alloca i1, align 1
  br label %label_2329

label_2329:                                       ; preds = %label_2341, %entry
  %10 = load ptr, ptr %stmt_ptr.1010, align 8
  %11 = call i32 @str_equals(ptr %10, ptr @.str.s847)
  %12 = icmp eq i32 %11, 0
  br i1 %12, label %label_2330, label %label_2331

label_2331:                                       ; preds = %label_2329
  %13 = load i32, ptr %match_count.1007, align 4
  %14 = icmp sgt i32 %13, 1
  br i1 %14, label %label_2345, label %label_2347

label_2330:                                       ; preds = %label_2329
  %15 = load ptr, ptr %stmt_ptr.1010, align 8
  %16 = call ptr @ptr_to_node(ptr %15)
  store ptr %16, ptr %stmt.1011, align 8
  %17 = load ptr, ptr %stmt.1011, align 8
  %18 = getelementptr inbounds nuw %ASTNode, ptr %17, i32 0, i32 0
  %19 = load i32, ptr %18, align 4
  %20 = icmp eq i32 %19, 4
  store i1 %20, ptr %is_candidate.1012, align 1
  %21 = load ptr, ptr %stmt.1011, align 8
  %22 = getelementptr inbounds nuw %ASTNode, ptr %21, i32 0, i32 0
  %23 = load i32, ptr %22, align 4
  %24 = icmp eq i32 %23, 2
  store i1 %24, ptr %sc.128, align 1
  br i1 %24, label %label_2332, label %label_2333

label_2333:                                       ; preds = %label_2332, %label_2330
  %25 = load i1, ptr %sc.128, align 1
  br i1 %25, label %label_2334, label %label_2336

label_2332:                                       ; preds = %label_2330
  %26 = load i1, ptr %definition_exists.1009, align 1
  %27 = icmp eq i1 %26, false
  store i1 %27, ptr %sc.128, align 1
  br label %label_2333

label_2336:                                       ; preds = %label_2334, %label_2333
  %28 = load i1, ptr %is_candidate.1012, align 1
  store i1 %28, ptr %sc.129, align 1
  br i1 %28, label %label_2337, label %label_2338

label_2334:                                       ; preds = %label_2333
  store i1 true, ptr %is_candidate.1012, align 1
  br label %label_2336

label_2338:                                       ; preds = %label_2337, %label_2336
  %29 = load i1, ptr %sc.129, align 1
  br i1 %29, label %label_2339, label %label_2341

label_2337:                                       ; preds = %label_2336
  %30 = load ptr, ptr %stmt.1011, align 8
  %31 = getelementptr inbounds nuw %ASTNode, ptr %30, i32 0, i32 1
  %32 = load ptr, ptr %31, align 8
  %33 = load ptr, ptr %name.1004, align 8
  %34 = call i32 @str_equals(ptr %32, ptr %33)
  %35 = icmp eq i32 %34, 1
  store i1 %35, ptr %sc.129, align 1
  br label %label_2338

label_2341:                                       ; preds = %label_2344, %label_2338
  %36 = load ptr, ptr %stmt.1011, align 8
  %37 = getelementptr inbounds nuw %ASTNode, ptr %36, i32 0, i32 8
  %38 = load ptr, ptr %37, align 8
  store ptr %38, ptr %stmt_ptr.1010, align 8
  br label %label_2329

label_2339:                                       ; preds = %label_2338
  store i1 true, ptr %name_seen.1008, align 1
  %39 = load ptr, ptr %module.1002, align 8
  %40 = load ptr, ptr %stmt.1011, align 8
  %41 = load ptr, ptr %arg_ptr.1005, align 8
  %42 = call i1 @sema_signature_matches_call__Struct_ASTNode_Struct_ASTNode_String(ptr %39, ptr %40, ptr %41)
  br i1 %42, label %label_2342, label %label_2344

label_2344:                                       ; preds = %label_2342, %label_2339
  br label %label_2341

label_2342:                                       ; preds = %label_2339
  %43 = load ptr, ptr %stmt_ptr.1010, align 8
  store ptr %43, ptr %best_ptr.1006, align 8
  %44 = load i32, ptr %match_count.1007, align 4
  %45 = add i32 %44, 1
  store i32 %45, ptr %match_count.1007, align 4
  br label %label_2344

label_2347:                                       ; preds = %label_2331
  %46 = load i32, ptr %match_count.1007, align 4
  %47 = icmp eq i32 %46, 1
  br i1 %47, label %label_2348, label %label_2350

label_2345:                                       ; preds = %label_2331
  %48 = load ptr, ptr %call.1003, align 8
  %49 = load ptr, ptr %name.1004, align 8
  %50 = call ptr @diag_quote__String(ptr %49)
  %51 = call ptr @str_concat(ptr @.str.s848, ptr %50)
  %52 = call ptr @str_concat(ptr %51, ptr @.str.s849)
  call void @sema_error_at__Struct_ASTNode_String(ptr %48, ptr %52)
  %53 = load ptr, ptr %best_ptr.1006, align 8
  %54 = call ptr @ptr_to_node(ptr %53)
  ret ptr %54

label_2350:                                       ; preds = %label_2347
  %55 = load i1, ptr %name_seen.1008, align 1
  br i1 %55, label %label_2351, label %label_2353

label_2348:                                       ; preds = %label_2347
  %56 = load ptr, ptr %best_ptr.1006, align 8
  %57 = call ptr @ptr_to_node(ptr %56)
  ret ptr %57

label_2353:                                       ; preds = %label_2350
  %58 = load ptr, ptr %call.1003, align 8
  %59 = load ptr, ptr %name.1004, align 8
  %60 = call ptr @diag_quote__String(ptr %59)
  %61 = call ptr @str_concat(ptr @.str.s852, ptr %60)
  call void @sema_error_at__Struct_ASTNode_String(ptr %58, ptr %61)
  %62 = call ptr @create_node__Enum_NodeKind(i32 0)
  ret ptr %62

label_2351:                                       ; preds = %label_2350
  %63 = load ptr, ptr %call.1003, align 8
  %64 = load ptr, ptr %name.1004, align 8
  %65 = call ptr @diag_quote__String(ptr %64)
  %66 = call ptr @str_concat(ptr @.str.s850, ptr %65)
  %67 = call ptr @str_concat(ptr %66, ptr @.str.s851)
  call void @sema_error_at__Struct_ASTNode_String(ptr %63, ptr %67)
  %68 = call ptr @create_node__Enum_NodeKind(i32 0)
  ret ptr %68
}

define ptr @sema_find_struct_field_type__Struct_ASTNode_Struct_ASTNode_String_String(ptr %0, ptr %1, ptr %2, ptr %3) {
entry:
  %module.1013 = alloca ptr, align 8
  store ptr %0, ptr %module.1013, align 8
  %at.1014 = alloca ptr, align 8
  store ptr %1, ptr %at.1014, align 8
  %struct_name.1015 = alloca ptr, align 8
  store ptr %2, ptr %struct_name.1015, align 8
  %field_name.1016 = alloca ptr, align 8
  store ptr %3, ptr %field_name.1016, align 8
  %4 = load ptr, ptr %module.1013, align 8
  %5 = getelementptr inbounds nuw %ASTNode, ptr %4, i32 0, i32 5
  %6 = load ptr, ptr %5, align 8
  %stmt_ptr.1017 = alloca ptr, align 8
  store ptr %6, ptr %stmt_ptr.1017, align 8
  %stmt.1018 = alloca ptr, align 8
  %sc.130 = alloca i1, align 1
  %field_ptr.1019 = alloca ptr, align 8
  %field.1020 = alloca ptr, align 8
  br label %label_2354

label_2354:                                       ; preds = %label_2361, %entry
  %7 = load ptr, ptr %stmt_ptr.1017, align 8
  %8 = call i32 @str_equals(ptr %7, ptr @.str.s853)
  %9 = icmp eq i32 %8, 0
  br i1 %9, label %label_2355, label %label_2356

label_2356:                                       ; preds = %label_2354
  %10 = load ptr, ptr %at.1014, align 8
  %11 = load ptr, ptr %struct_name.1015, align 8
  %12 = call ptr @diag_quote__String(ptr %11)
  %13 = call ptr @str_concat(ptr @.str.s855, ptr %12)
  %14 = load ptr, ptr %field_name.1016, align 8
  %15 = call ptr @diag_quote__String(ptr %14)
  %16 = call ptr @str_concat(ptr @.str.s856, ptr %15)
  %17 = call ptr @str_concat(ptr %13, ptr %16)
  call void @sema_error_at__Struct_ASTNode_String(ptr %10, ptr %17)
  %18 = call ptr @type_invalid__Void()
  ret ptr %18

label_2355:                                       ; preds = %label_2354
  %19 = load ptr, ptr %stmt_ptr.1017, align 8
  %20 = call ptr @ptr_to_node(ptr %19)
  store ptr %20, ptr %stmt.1018, align 8
  %21 = load ptr, ptr %stmt.1018, align 8
  %22 = getelementptr inbounds nuw %ASTNode, ptr %21, i32 0, i32 0
  %23 = load i32, ptr %22, align 4
  %24 = icmp eq i32 %23, 5
  store i1 %24, ptr %sc.130, align 1
  br i1 %24, label %label_2357, label %label_2358

label_2358:                                       ; preds = %label_2357, %label_2355
  %25 = load i1, ptr %sc.130, align 1
  br i1 %25, label %label_2359, label %label_2361

label_2357:                                       ; preds = %label_2355
  %26 = load ptr, ptr %stmt.1018, align 8
  %27 = getelementptr inbounds nuw %ASTNode, ptr %26, i32 0, i32 1
  %28 = load ptr, ptr %27, align 8
  %29 = load ptr, ptr %struct_name.1015, align 8
  %30 = call i32 @str_equals(ptr %28, ptr %29)
  %31 = icmp eq i32 %30, 1
  store i1 %31, ptr %sc.130, align 1
  br label %label_2358

label_2361:                                       ; preds = %label_2364, %label_2358
  %32 = load ptr, ptr %stmt.1018, align 8
  %33 = getelementptr inbounds nuw %ASTNode, ptr %32, i32 0, i32 8
  %34 = load ptr, ptr %33, align 8
  store ptr %34, ptr %stmt_ptr.1017, align 8
  br label %label_2354

label_2359:                                       ; preds = %label_2358
  %35 = load ptr, ptr %stmt.1018, align 8
  %36 = getelementptr inbounds nuw %ASTNode, ptr %35, i32 0, i32 5
  %37 = load ptr, ptr %36, align 8
  store ptr %37, ptr %field_ptr.1019, align 8
  br label %label_2362

label_2362:                                       ; preds = %label_2367, %label_2359
  %38 = load ptr, ptr %field_ptr.1019, align 8
  %39 = call i32 @str_equals(ptr %38, ptr @.str.s854)
  %40 = icmp eq i32 %39, 0
  br i1 %40, label %label_2363, label %label_2364

label_2364:                                       ; preds = %label_2362
  br label %label_2361

label_2363:                                       ; preds = %label_2362
  %41 = load ptr, ptr %field_ptr.1019, align 8
  %42 = call ptr @ptr_to_node(ptr %41)
  store ptr %42, ptr %field.1020, align 8
  %43 = load ptr, ptr %field.1020, align 8
  %44 = getelementptr inbounds nuw %ASTNode, ptr %43, i32 0, i32 1
  %45 = load ptr, ptr %44, align 8
  %46 = load ptr, ptr %field_name.1016, align 8
  %47 = call i32 @str_equals(ptr %45, ptr %46)
  %48 = icmp eq i32 %47, 1
  br i1 %48, label %label_2365, label %label_2367

label_2367:                                       ; preds = %label_2363
  %49 = load ptr, ptr %field.1020, align 8
  %50 = getelementptr inbounds nuw %ASTNode, ptr %49, i32 0, i32 8
  %51 = load ptr, ptr %50, align 8
  store ptr %51, ptr %field_ptr.1019, align 8
  br label %label_2362

label_2365:                                       ; preds = %label_2363
  %52 = load ptr, ptr %module.1013, align 8
  %53 = load ptr, ptr %field.1020, align 8
  %54 = getelementptr inbounds nuw %ASTNode, ptr %53, i32 0, i32 5
  %55 = load ptr, ptr %54, align 8
  %56 = call ptr @ptr_to_node(ptr %55)
  %57 = call ptr @sema_annotation_type__Struct_ASTNode_Struct_ASTNode(ptr %52, ptr %56)
  ret ptr %57
}

define i1 @sema_enum_has_variant__Struct_ASTNode_String_String(ptr %0, ptr %1, ptr %2) {
entry:
  %module.1021 = alloca ptr, align 8
  store ptr %0, ptr %module.1021, align 8
  %enum_name.1022 = alloca ptr, align 8
  store ptr %1, ptr %enum_name.1022, align 8
  %variant_name.1023 = alloca ptr, align 8
  store ptr %2, ptr %variant_name.1023, align 8
  %3 = load ptr, ptr %module.1021, align 8
  %4 = getelementptr inbounds nuw %ASTNode, ptr %3, i32 0, i32 5
  %5 = load ptr, ptr %4, align 8
  %stmt_ptr.1024 = alloca ptr, align 8
  store ptr %5, ptr %stmt_ptr.1024, align 8
  %stmt.1025 = alloca ptr, align 8
  %sc.131 = alloca i1, align 1
  %variant_ptr.1026 = alloca ptr, align 8
  %variant.1027 = alloca ptr, align 8
  br label %label_2368

label_2368:                                       ; preds = %label_2375, %entry
  %6 = load ptr, ptr %stmt_ptr.1024, align 8
  %7 = call i32 @str_equals(ptr %6, ptr @.str.s857)
  %8 = icmp eq i32 %7, 0
  br i1 %8, label %label_2369, label %label_2370

label_2370:                                       ; preds = %label_2368
  ret i1 false

label_2369:                                       ; preds = %label_2368
  %9 = load ptr, ptr %stmt_ptr.1024, align 8
  %10 = call ptr @ptr_to_node(ptr %9)
  store ptr %10, ptr %stmt.1025, align 8
  %11 = load ptr, ptr %stmt.1025, align 8
  %12 = getelementptr inbounds nuw %ASTNode, ptr %11, i32 0, i32 0
  %13 = load i32, ptr %12, align 4
  %14 = icmp eq i32 %13, 6
  store i1 %14, ptr %sc.131, align 1
  br i1 %14, label %label_2371, label %label_2372

label_2372:                                       ; preds = %label_2371, %label_2369
  %15 = load i1, ptr %sc.131, align 1
  br i1 %15, label %label_2373, label %label_2375

label_2371:                                       ; preds = %label_2369
  %16 = load ptr, ptr %stmt.1025, align 8
  %17 = getelementptr inbounds nuw %ASTNode, ptr %16, i32 0, i32 1
  %18 = load ptr, ptr %17, align 8
  %19 = load ptr, ptr %enum_name.1022, align 8
  %20 = call i32 @str_equals(ptr %18, ptr %19)
  %21 = icmp eq i32 %20, 1
  store i1 %21, ptr %sc.131, align 1
  br label %label_2372

label_2375:                                       ; preds = %label_2378, %label_2372
  %22 = load ptr, ptr %stmt.1025, align 8
  %23 = getelementptr inbounds nuw %ASTNode, ptr %22, i32 0, i32 8
  %24 = load ptr, ptr %23, align 8
  store ptr %24, ptr %stmt_ptr.1024, align 8
  br label %label_2368

label_2373:                                       ; preds = %label_2372
  %25 = load ptr, ptr %stmt.1025, align 8
  %26 = getelementptr inbounds nuw %ASTNode, ptr %25, i32 0, i32 5
  %27 = load ptr, ptr %26, align 8
  store ptr %27, ptr %variant_ptr.1026, align 8
  br label %label_2376

label_2376:                                       ; preds = %label_2381, %label_2373
  %28 = load ptr, ptr %variant_ptr.1026, align 8
  %29 = call i32 @str_equals(ptr %28, ptr @.str.s858)
  %30 = icmp eq i32 %29, 0
  br i1 %30, label %label_2377, label %label_2378

label_2378:                                       ; preds = %label_2376
  br label %label_2375

label_2377:                                       ; preds = %label_2376
  %31 = load ptr, ptr %variant_ptr.1026, align 8
  %32 = call ptr @ptr_to_node(ptr %31)
  store ptr %32, ptr %variant.1027, align 8
  %33 = load ptr, ptr %variant.1027, align 8
  %34 = getelementptr inbounds nuw %ASTNode, ptr %33, i32 0, i32 1
  %35 = load ptr, ptr %34, align 8
  %36 = load ptr, ptr %variant_name.1023, align 8
  %37 = call i32 @str_equals(ptr %35, ptr %36)
  %38 = icmp eq i32 %37, 1
  br i1 %38, label %label_2379, label %label_2381

label_2381:                                       ; preds = %label_2377
  %39 = load ptr, ptr %variant.1027, align 8
  %40 = getelementptr inbounds nuw %ASTNode, ptr %39, i32 0, i32 8
  %41 = load ptr, ptr %40, align 8
  store ptr %41, ptr %variant_ptr.1026, align 8
  br label %label_2376

label_2379:                                       ; preds = %label_2377
  ret i1 true
}

define i32 @sema_arg_count__String(ptr %0) {
entry:
  %arg_ptr.1028 = alloca ptr, align 8
  store ptr %0, ptr %arg_ptr.1028, align 8
  %count.1029 = alloca i32, align 4
  store i32 0, ptr %count.1029, align 4
  %1 = load ptr, ptr %arg_ptr.1028, align 8
  %curr.1030 = alloca ptr, align 8
  store ptr %1, ptr %curr.1030, align 8
  br label %label_2382

label_2382:                                       ; preds = %label_2383, %entry
  %2 = load ptr, ptr %curr.1030, align 8
  %3 = call i32 @str_equals(ptr %2, ptr @.str.s859)
  %4 = icmp eq i32 %3, 0
  br i1 %4, label %label_2383, label %label_2384

label_2384:                                       ; preds = %label_2382
  %5 = load i32, ptr %count.1029, align 4
  ret i32 %5

label_2383:                                       ; preds = %label_2382
  %6 = load i32, ptr %count.1029, align 4
  %7 = add i32 %6, 1
  store i32 %7, ptr %count.1029, align 4
  %8 = load ptr, ptr %curr.1030, align 8
  %9 = call ptr @ptr_to_node(ptr %8)
  %10 = getelementptr inbounds nuw %ASTNode, ptr %9, i32 0, i32 8
  %11 = load ptr, ptr %10, align 8
  store ptr %11, ptr %curr.1030, align 8
  br label %label_2382
}

define i1 @sema_check_arity__Struct_ASTNode_String_String_Int(ptr %0, ptr %1, ptr %2, i32 %3) {
entry:
  %call.1031 = alloca ptr, align 8
  store ptr %0, ptr %call.1031, align 8
  %name.1032 = alloca ptr, align 8
  store ptr %1, ptr %name.1032, align 8
  %arg_ptr.1033 = alloca ptr, align 8
  store ptr %2, ptr %arg_ptr.1033, align 8
  %expected.1034 = alloca i32, align 4
  store i32 %3, ptr %expected.1034, align 4
  %4 = load ptr, ptr %arg_ptr.1033, align 8
  %5 = call i32 @sema_arg_count__String(ptr %4)
  %actual.1035 = alloca i32, align 4
  store i32 %5, ptr %actual.1035, align 4
  %6 = load i32, ptr %actual.1035, align 4
  %7 = load i32, ptr %expected.1034, align 4
  %8 = icmp eq i32 %6, %7
  %noun.1036 = alloca ptr, align 8
  br i1 %8, label %label_2385, label %label_2387

label_2387:                                       ; preds = %entry
  store ptr @.str.s860, ptr %noun.1036, align 8
  %9 = load i32, ptr %expected.1034, align 4
  %10 = icmp eq i32 %9, 1
  br i1 %10, label %label_2388, label %label_2390

label_2385:                                       ; preds = %entry
  ret i1 true

label_2390:                                       ; preds = %label_2388, %label_2387
  %11 = load ptr, ptr %call.1031, align 8
  %12 = load ptr, ptr %name.1032, align 8
  %13 = call ptr @diag_quote__String(ptr %12)
  %14 = call ptr @str_concat(ptr %13, ptr @.str.s862)
  %15 = load i32, ptr %expected.1034, align 4
  %16 = call ptr @int_to_str(i32 %15)
  %17 = load ptr, ptr %noun.1036, align 8
  %18 = load i32, ptr %actual.1035, align 4
  %19 = call ptr @int_to_str(i32 %18)
  %20 = call ptr @str_concat(ptr %17, ptr %19)
  %21 = call ptr @str_concat(ptr %16, ptr %20)
  %22 = call ptr @str_concat(ptr %14, ptr %21)
  call void @sema_error_at__Struct_ASTNode_String(ptr %11, ptr %22)
  ret i1 false

label_2388:                                       ; preds = %label_2387
  store ptr @.str.s861, ptr %noun.1036, align 8
  br label %label_2390
}

define ptr @sema_builtin_call_type__String_String(ptr %0, ptr %1) {
entry:
  %name.1037 = alloca ptr, align 8
  store ptr %0, ptr %name.1037, align 8
  %arg_ptr.1038 = alloca ptr, align 8
  store ptr %1, ptr %arg_ptr.1038, align 8
  %sc.132 = alloca i1, align 1
  %2 = load ptr, ptr %name.1037, align 8
  %3 = call i32 @str_equals(ptr %2, ptr @.str.s863)
  %4 = icmp eq i32 %3, 1
  store i1 %4, ptr %sc.132, align 1
  %sc.133 = alloca i1, align 1
  %sc.134 = alloca i1, align 1
  %sc.135 = alloca i1, align 1
  %sc.136 = alloca i1, align 1
  %lt.1039 = alloca ptr, align 8
  %sc.137 = alloca i1, align 1
  br i1 %4, label %label_2392, label %label_2391

label_2391:                                       ; preds = %entry
  %5 = load ptr, ptr %name.1037, align 8
  %6 = call i32 @str_equals(ptr %5, ptr @.str.s864)
  %7 = icmp eq i32 %6, 1
  store i1 %7, ptr %sc.132, align 1
  br label %label_2392

label_2392:                                       ; preds = %label_2391, %entry
  %8 = load i1, ptr %sc.132, align 1
  br i1 %8, label %label_2393, label %label_2395

label_2395:                                       ; preds = %label_2392
  %9 = load ptr, ptr %name.1037, align 8
  %10 = call i32 @str_equals(ptr %9, ptr @.str.s865)
  %11 = icmp eq i32 %10, 1
  store i1 %11, ptr %sc.133, align 1
  br i1 %11, label %label_2397, label %label_2396

label_2393:                                       ; preds = %label_2392
  %12 = call ptr @type_void__Void()
  ret ptr %12

label_2396:                                       ; preds = %label_2395
  %13 = load ptr, ptr %name.1037, align 8
  %14 = call i32 @str_equals(ptr %13, ptr @.str.s866)
  %15 = icmp eq i32 %14, 1
  store i1 %15, ptr %sc.133, align 1
  br label %label_2397

label_2397:                                       ; preds = %label_2396, %label_2395
  %16 = load i1, ptr %sc.133, align 1
  br i1 %16, label %label_2398, label %label_2400

label_2400:                                       ; preds = %label_2397
  %17 = load ptr, ptr %name.1037, align 8
  %18 = call i32 @str_equals(ptr %17, ptr @.str.s867)
  %19 = icmp eq i32 %18, 1
  store i1 %19, ptr %sc.134, align 1
  br i1 %19, label %label_2402, label %label_2401

label_2398:                                       ; preds = %label_2397
  %20 = call ptr @type_void__Void()
  ret ptr %20

label_2401:                                       ; preds = %label_2400
  %21 = load ptr, ptr %name.1037, align 8
  %22 = call i32 @str_equals(ptr %21, ptr @.str.s868)
  %23 = icmp eq i32 %22, 1
  store i1 %23, ptr %sc.134, align 1
  br label %label_2402

label_2402:                                       ; preds = %label_2401, %label_2400
  %24 = load i1, ptr %sc.134, align 1
  br i1 %24, label %label_2403, label %label_2405

label_2405:                                       ; preds = %label_2402
  %25 = load ptr, ptr %name.1037, align 8
  %26 = call i32 @str_equals(ptr %25, ptr @.str.s869)
  %27 = icmp eq i32 %26, 1
  store i1 %27, ptr %sc.135, align 1
  br i1 %27, label %label_2407, label %label_2406

label_2403:                                       ; preds = %label_2402
  %28 = call ptr @type_void__Void()
  ret ptr %28

label_2406:                                       ; preds = %label_2405
  %29 = load ptr, ptr %name.1037, align 8
  %30 = call i32 @str_equals(ptr %29, ptr @.str.s870)
  %31 = icmp eq i32 %30, 1
  store i1 %31, ptr %sc.135, align 1
  br label %label_2407

label_2407:                                       ; preds = %label_2406, %label_2405
  %32 = load i1, ptr %sc.135, align 1
  br i1 %32, label %label_2408, label %label_2410

label_2410:                                       ; preds = %label_2407
  %33 = load ptr, ptr %name.1037, align 8
  %34 = call i32 @str_equals(ptr %33, ptr @.str.s871)
  %35 = icmp eq i32 %34, 1
  store i1 %35, ptr %sc.136, align 1
  br i1 %35, label %label_2412, label %label_2411

label_2408:                                       ; preds = %label_2407
  %36 = call ptr @type_void__Void()
  ret ptr %36

label_2411:                                       ; preds = %label_2410
  %37 = load ptr, ptr %name.1037, align 8
  %38 = call i32 @str_equals(ptr %37, ptr @.str.s872)
  %39 = icmp eq i32 %38, 1
  store i1 %39, ptr %sc.136, align 1
  br label %label_2412

label_2412:                                       ; preds = %label_2411, %label_2410
  %40 = load i1, ptr %sc.136, align 1
  br i1 %40, label %label_2413, label %label_2415

label_2415:                                       ; preds = %label_2412
  %41 = load ptr, ptr %name.1037, align 8
  %42 = call i32 @str_equals(ptr %41, ptr @.str.s873)
  %43 = icmp eq i32 %42, 1
  br i1 %43, label %label_2416, label %label_2418

label_2413:                                       ; preds = %label_2412
  %44 = call ptr @type_void__Void()
  ret ptr %44

label_2418:                                       ; preds = %label_2415
  %45 = load ptr, ptr %name.1037, align 8
  %46 = call i32 @str_equals(ptr %45, ptr @.str.s874)
  %47 = icmp eq i32 %46, 1
  br i1 %47, label %label_2419, label %label_2421

label_2416:                                       ; preds = %label_2415
  %48 = call ptr @type_void__Void()
  ret ptr %48

label_2421:                                       ; preds = %label_2418
  %49 = load ptr, ptr %name.1037, align 8
  %50 = call i32 @str_equals(ptr %49, ptr @.str.s875)
  %51 = icmp eq i32 %50, 1
  br i1 %51, label %label_2422, label %label_2424

label_2419:                                       ; preds = %label_2418
  %52 = call ptr @type_invalid__Void()
  %53 = call ptr @type_list__Struct_TypeInfo(ptr %52)
  ret ptr %53

label_2424:                                       ; preds = %label_2421
  %54 = load ptr, ptr %name.1037, align 8
  %55 = call i32 @str_equals(ptr %54, ptr @.str.s876)
  %56 = icmp eq i32 %55, 1
  br i1 %56, label %label_2425, label %label_2427

label_2422:                                       ; preds = %label_2421
  %57 = call ptr @type_int__Void()
  ret ptr %57

label_2427:                                       ; preds = %label_2424
  %58 = load ptr, ptr %name.1037, align 8
  %59 = call i32 @str_equals(ptr %58, ptr @.str.s877)
  %60 = icmp eq i32 %59, 1
  br i1 %60, label %label_2428, label %label_2430

label_2425:                                       ; preds = %label_2424
  %61 = call ptr @type_void__Void()
  ret ptr %61

label_2430:                                       ; preds = %label_2427
  %62 = load ptr, ptr %name.1037, align 8
  %63 = call i32 @str_equals(ptr %62, ptr @.str.s878)
  %64 = icmp eq i32 %63, 1
  br i1 %64, label %label_2431, label %label_2433

label_2428:                                       ; preds = %label_2427
  %65 = call ptr @type_void__Void()
  ret ptr %65

label_2433:                                       ; preds = %label_2430
  %66 = call ptr @type_invalid__Void()
  ret ptr %66

label_2431:                                       ; preds = %label_2430
  %67 = load ptr, ptr %arg_ptr.1038, align 8
  %68 = call i32 @str_equals(ptr %67, ptr @.str.s879)
  %69 = icmp eq i32 %68, 0
  br i1 %69, label %label_2434, label %label_2436

label_2436:                                       ; preds = %label_2441, %label_2431
  %70 = call ptr @type_invalid__Void()
  ret ptr %70

label_2434:                                       ; preds = %label_2431
  %71 = load ptr, ptr %arg_ptr.1038, align 8
  %72 = call ptr @ptr_to_node(ptr %71)
  %73 = call ptr @node_get_type__Struct_ASTNode(ptr %72)
  store ptr %73, ptr %lt.1039, align 8
  %74 = load ptr, ptr %lt.1039, align 8
  %75 = getelementptr inbounds nuw %TypeInfo, ptr %74, i32 0, i32 0
  %76 = load i32, ptr %75, align 4
  %77 = icmp eq i32 %76, 11
  store i1 %77, ptr %sc.137, align 1
  br i1 %77, label %label_2437, label %label_2438

label_2438:                                       ; preds = %label_2437, %label_2434
  %78 = load i1, ptr %sc.137, align 1
  br i1 %78, label %label_2439, label %label_2441

label_2437:                                       ; preds = %label_2434
  %79 = load ptr, ptr %lt.1039, align 8
  %80 = getelementptr inbounds nuw %TypeInfo, ptr %79, i32 0, i32 3
  %81 = load ptr, ptr %80, align 8
  %82 = call i32 @str_equals(ptr %81, ptr @.str.s880)
  %83 = icmp eq i32 %82, 0
  store i1 %83, ptr %sc.137, align 1
  br label %label_2438

label_2441:                                       ; preds = %label_2438
  br label %label_2436

label_2439:                                       ; preds = %label_2438
  %84 = load ptr, ptr %lt.1039, align 8
  %85 = getelementptr inbounds nuw %TypeInfo, ptr %84, i32 0, i32 3
  %86 = load ptr, ptr %85, align 8
  %87 = call ptr @ptr_to_type(ptr %86)
  ret ptr %87
}

define ptr @sema_list_element_type__Struct_TypeInfo(ptr %0) {
entry:
  %lt.1040 = alloca ptr, align 8
  store ptr %0, ptr %lt.1040, align 8
  %sc.138 = alloca i1, align 1
  %1 = load ptr, ptr %lt.1040, align 8
  %2 = getelementptr inbounds nuw %TypeInfo, ptr %1, i32 0, i32 0
  %3 = load i32, ptr %2, align 4
  %4 = icmp eq i32 %3, 11
  store i1 %4, ptr %sc.138, align 1
  br i1 %4, label %label_2442, label %label_2443

label_2443:                                       ; preds = %label_2442, %entry
  %5 = load i1, ptr %sc.138, align 1
  br i1 %5, label %label_2444, label %label_2446

label_2442:                                       ; preds = %entry
  %6 = load ptr, ptr %lt.1040, align 8
  %7 = getelementptr inbounds nuw %TypeInfo, ptr %6, i32 0, i32 3
  %8 = load ptr, ptr %7, align 8
  %9 = call i32 @str_equals(ptr %8, ptr @.str.s881)
  %10 = icmp eq i32 %9, 0
  store i1 %10, ptr %sc.138, align 1
  br label %label_2443

label_2446:                                       ; preds = %label_2443
  %11 = call ptr @type_invalid__Void()
  ret ptr %11

label_2444:                                       ; preds = %label_2443
  %12 = load ptr, ptr %lt.1040, align 8
  %13 = getelementptr inbounds nuw %TypeInfo, ptr %12, i32 0, i32 3
  %14 = load ptr, ptr %13, align 8
  %15 = call ptr @ptr_to_type(ptr %14)
  ret ptr %15
}

define i1 @sema_check_builtin_call__Struct_ASTNode_Struct_ASTNode_String_String(ptr %0, ptr %1, ptr %2, ptr %3) {
entry:
  %module.1041 = alloca ptr, align 8
  store ptr %0, ptr %module.1041, align 8
  %call.1042 = alloca ptr, align 8
  store ptr %1, ptr %call.1042, align 8
  %name.1043 = alloca ptr, align 8
  store ptr %2, ptr %name.1043, align 8
  %arg_ptr.1044 = alloca ptr, align 8
  store ptr %3, ptr %arg_ptr.1044, align 8
  %sc.139 = alloca i1, align 1
  %4 = load ptr, ptr %name.1043, align 8
  %5 = call i32 @str_equals(ptr %4, ptr @.str.s882)
  %6 = icmp eq i32 %5, 1
  store i1 %6, ptr %sc.139, align 1
  %arg.1045 = alloca ptr, align 8
  %t.1046 = alloca ptr, align 8
  %a0.1047 = alloca ptr, align 8
  %lt.1048 = alloca ptr, align 8
  %a0.1049 = alloca ptr, align 8
  %lt.1050 = alloca ptr, align 8
  %a0.1051 = alloca ptr, align 8
  %lt.1052 = alloca ptr, align 8
  %a0.1053 = alloca ptr, align 8
  %lt.1054 = alloca ptr, align 8
  %a1.1055 = alloca ptr, align 8
  %expected.1056 = alloca ptr, align 8
  %sc.140 = alloca i1, align 1
  %sc.141 = alloca i1, align 1
  %sc.142 = alloca i1, align 1
  %sc.143 = alloca i1, align 1
  %actual.1057 = alloca ptr, align 8
  br i1 %6, label %label_2448, label %label_2447

label_2447:                                       ; preds = %entry
  %7 = load ptr, ptr %name.1043, align 8
  %8 = call i32 @str_equals(ptr %7, ptr @.str.s883)
  %9 = icmp eq i32 %8, 1
  store i1 %9, ptr %sc.139, align 1
  br label %label_2448

label_2448:                                       ; preds = %label_2447, %entry
  %10 = load i1, ptr %sc.139, align 1
  br i1 %10, label %label_2449, label %label_2451

label_2451:                                       ; preds = %label_2448
  %11 = load ptr, ptr %name.1043, align 8
  %12 = call i32 @str_equals(ptr %11, ptr @.str.s884)
  %13 = icmp eq i32 %12, 1
  br i1 %13, label %label_2455, label %label_2457

label_2449:                                       ; preds = %label_2448
  %14 = load ptr, ptr %call.1042, align 8
  %15 = load ptr, ptr %name.1043, align 8
  %16 = load ptr, ptr %arg_ptr.1044, align 8
  %17 = call i1 @sema_check_arity__Struct_ASTNode_String_String_Int(ptr %14, ptr %15, ptr %16, i32 1)
  %18 = icmp eq i1 %17, false
  br i1 %18, label %label_2452, label %label_2454

label_2454:                                       ; preds = %label_2449
  %19 = load ptr, ptr %module.1041, align 8
  %20 = load ptr, ptr %arg_ptr.1044, align 8
  %21 = call ptr @ptr_to_node(ptr %20)
  %22 = call ptr @sema_expr__Struct_ASTNode_Struct_ASTNode(ptr %19, ptr %21)
  ret i1 true

label_2452:                                       ; preds = %label_2449
  ret i1 true

label_2457:                                       ; preds = %label_2451
  %23 = load ptr, ptr %name.1043, align 8
  %24 = call i32 @str_equals(ptr %23, ptr @.str.s886)
  %25 = icmp eq i32 %24, 1
  br i1 %25, label %label_2464, label %label_2466

label_2455:                                       ; preds = %label_2451
  %26 = load ptr, ptr %call.1042, align 8
  %27 = load ptr, ptr %name.1043, align 8
  %28 = load ptr, ptr %arg_ptr.1044, align 8
  %29 = call i1 @sema_check_arity__Struct_ASTNode_String_String_Int(ptr %26, ptr %27, ptr %28, i32 1)
  %30 = icmp eq i1 %29, false
  br i1 %30, label %label_2458, label %label_2460

label_2460:                                       ; preds = %label_2455
  %31 = load ptr, ptr %arg_ptr.1044, align 8
  %32 = call ptr @ptr_to_node(ptr %31)
  store ptr %32, ptr %arg.1045, align 8
  %33 = load ptr, ptr %module.1041, align 8
  %34 = load ptr, ptr %arg.1045, align 8
  %35 = call ptr @sema_expr__Struct_ASTNode_Struct_ASTNode(ptr %33, ptr %34)
  store ptr %35, ptr %t.1046, align 8
  %36 = load ptr, ptr %t.1046, align 8
  %37 = call i1 @type_is_move_only__Struct_TypeInfo(ptr %36)
  %38 = icmp eq i1 %37, false
  br i1 %38, label %label_2461, label %label_2463

label_2458:                                       ; preds = %label_2455
  ret i1 true

label_2463:                                       ; preds = %label_2460
  %39 = load ptr, ptr %arg.1045, align 8
  call void @sema_move_operand__Struct_ASTNode(ptr %39)
  ret i1 true

label_2461:                                       ; preds = %label_2460
  %40 = load ptr, ptr %arg.1045, align 8
  %41 = load ptr, ptr %t.1046, align 8
  %42 = call ptr @type_display__Struct_TypeInfo(ptr %41)
  %43 = call ptr @str_concat(ptr @.str.s885, ptr %42)
  call void @sema_error_at__Struct_ASTNode_String(ptr %40, ptr %43)
  ret i1 true

label_2466:                                       ; preds = %label_2457
  %44 = load ptr, ptr %name.1043, align 8
  %45 = call i32 @str_equals(ptr %44, ptr @.str.s887)
  %46 = icmp eq i32 %45, 1
  br i1 %46, label %label_2467, label %label_2469

label_2464:                                       ; preds = %label_2457
  %47 = load ptr, ptr %call.1042, align 8
  %48 = load ptr, ptr %name.1043, align 8
  %49 = load ptr, ptr %arg_ptr.1044, align 8
  %50 = call i1 @sema_check_arity__Struct_ASTNode_String_String_Int(ptr %47, ptr %48, ptr %49, i32 0)
  ret i1 true

label_2469:                                       ; preds = %label_2466
  %51 = load ptr, ptr %name.1043, align 8
  %52 = call i32 @str_equals(ptr %51, ptr @.str.s889)
  %53 = icmp eq i32 %52, 1
  br i1 %53, label %label_2476, label %label_2478

label_2467:                                       ; preds = %label_2466
  %54 = load ptr, ptr %call.1042, align 8
  %55 = load ptr, ptr %name.1043, align 8
  %56 = load ptr, ptr %arg_ptr.1044, align 8
  %57 = call i1 @sema_check_arity__Struct_ASTNode_String_String_Int(ptr %54, ptr %55, ptr %56, i32 1)
  %58 = icmp eq i1 %57, false
  br i1 %58, label %label_2470, label %label_2472

label_2472:                                       ; preds = %label_2467
  %59 = load ptr, ptr %arg_ptr.1044, align 8
  %60 = call ptr @ptr_to_node(ptr %59)
  store ptr %60, ptr %a0.1047, align 8
  %61 = load ptr, ptr %module.1041, align 8
  %62 = load ptr, ptr %a0.1047, align 8
  %63 = call ptr @sema_expr__Struct_ASTNode_Struct_ASTNode(ptr %61, ptr %62)
  store ptr %63, ptr %lt.1048, align 8
  %64 = load ptr, ptr %lt.1048, align 8
  %65 = getelementptr inbounds nuw %TypeInfo, ptr %64, i32 0, i32 0
  %66 = load i32, ptr %65, align 4
  %67 = icmp ne i32 %66, 11
  br i1 %67, label %label_2473, label %label_2475

label_2470:                                       ; preds = %label_2467
  ret i1 true

label_2475:                                       ; preds = %label_2473, %label_2472
  ret i1 true

label_2473:                                       ; preds = %label_2472
  %68 = load ptr, ptr %a0.1047, align 8
  %69 = load ptr, ptr %lt.1048, align 8
  %70 = call ptr @type_display__Struct_TypeInfo(ptr %69)
  %71 = call ptr @str_concat(ptr @.str.s888, ptr %70)
  call void @sema_error_at__Struct_ASTNode_String(ptr %68, ptr %71)
  br label %label_2475

label_2478:                                       ; preds = %label_2469
  %72 = load ptr, ptr %name.1043, align 8
  %73 = call i32 @str_equals(ptr %72, ptr @.str.s892)
  %74 = icmp eq i32 %73, 1
  br i1 %74, label %label_2485, label %label_2487

label_2476:                                       ; preds = %label_2469
  %75 = load ptr, ptr %call.1042, align 8
  %76 = load ptr, ptr %name.1043, align 8
  %77 = load ptr, ptr %arg_ptr.1044, align 8
  %78 = call i1 @sema_check_arity__Struct_ASTNode_String_String_Int(ptr %75, ptr %76, ptr %77, i32 2)
  %79 = icmp eq i1 %78, false
  br i1 %79, label %label_2479, label %label_2481

label_2481:                                       ; preds = %label_2476
  %80 = load ptr, ptr %arg_ptr.1044, align 8
  %81 = call ptr @ptr_to_node(ptr %80)
  store ptr %81, ptr %a0.1049, align 8
  %82 = load ptr, ptr %module.1041, align 8
  %83 = load ptr, ptr %a0.1049, align 8
  %84 = call ptr @sema_expr__Struct_ASTNode_Struct_ASTNode(ptr %82, ptr %83)
  store ptr %84, ptr %lt.1050, align 8
  %85 = load ptr, ptr %lt.1050, align 8
  %86 = getelementptr inbounds nuw %TypeInfo, ptr %85, i32 0, i32 0
  %87 = load i32, ptr %86, align 4
  %88 = icmp ne i32 %87, 11
  br i1 %88, label %label_2482, label %label_2484

label_2479:                                       ; preds = %label_2476
  ret i1 true

label_2484:                                       ; preds = %label_2481
  %89 = load ptr, ptr %module.1041, align 8
  %90 = load ptr, ptr %a0.1049, align 8
  %91 = getelementptr inbounds nuw %ASTNode, ptr %90, i32 0, i32 8
  %92 = load ptr, ptr %91, align 8
  %93 = call ptr @ptr_to_node(ptr %92)
  %94 = call ptr @type_int__Void()
  %95 = call ptr @sema_check_value__Struct_ASTNode_Struct_ASTNode_Struct_TypeInfo_String(ptr %89, ptr %93, ptr %94, ptr @.str.s891)
  ret i1 true

label_2482:                                       ; preds = %label_2481
  %96 = load ptr, ptr %a0.1049, align 8
  %97 = load ptr, ptr %lt.1050, align 8
  %98 = call ptr @type_display__Struct_TypeInfo(ptr %97)
  %99 = call ptr @str_concat(ptr @.str.s890, ptr %98)
  call void @sema_error_at__Struct_ASTNode_String(ptr %96, ptr %99)
  ret i1 true

label_2487:                                       ; preds = %label_2478
  %100 = load ptr, ptr %name.1043, align 8
  %101 = call i32 @str_equals(ptr %100, ptr @.str.s895)
  %102 = icmp eq i32 %101, 1
  br i1 %102, label %label_2494, label %label_2496

label_2485:                                       ; preds = %label_2478
  %103 = load ptr, ptr %call.1042, align 8
  %104 = load ptr, ptr %name.1043, align 8
  %105 = load ptr, ptr %arg_ptr.1044, align 8
  %106 = call i1 @sema_check_arity__Struct_ASTNode_String_String_Int(ptr %103, ptr %104, ptr %105, i32 2)
  %107 = icmp eq i1 %106, false
  br i1 %107, label %label_2488, label %label_2490

label_2490:                                       ; preds = %label_2485
  %108 = load ptr, ptr %arg_ptr.1044, align 8
  %109 = call ptr @ptr_to_node(ptr %108)
  store ptr %109, ptr %a0.1051, align 8
  %110 = load ptr, ptr %module.1041, align 8
  %111 = load ptr, ptr %a0.1051, align 8
  %112 = call ptr @sema_expr__Struct_ASTNode_Struct_ASTNode(ptr %110, ptr %111)
  store ptr %112, ptr %lt.1052, align 8
  %113 = load ptr, ptr %lt.1052, align 8
  %114 = getelementptr inbounds nuw %TypeInfo, ptr %113, i32 0, i32 0
  %115 = load i32, ptr %114, align 4
  %116 = icmp ne i32 %115, 11
  br i1 %116, label %label_2491, label %label_2493

label_2488:                                       ; preds = %label_2485
  ret i1 true

label_2493:                                       ; preds = %label_2490
  %117 = load ptr, ptr %module.1041, align 8
  %118 = load ptr, ptr %a0.1051, align 8
  %119 = getelementptr inbounds nuw %ASTNode, ptr %118, i32 0, i32 8
  %120 = load ptr, ptr %119, align 8
  %121 = call ptr @ptr_to_node(ptr %120)
  %122 = load ptr, ptr %lt.1052, align 8
  %123 = call ptr @sema_list_element_type__Struct_TypeInfo(ptr %122)
  %124 = call ptr @sema_check_value__Struct_ASTNode_Struct_ASTNode_Struct_TypeInfo_String(ptr %117, ptr %121, ptr %123, ptr @.str.s894)
  ret i1 true

label_2491:                                       ; preds = %label_2490
  %125 = load ptr, ptr %a0.1051, align 8
  %126 = load ptr, ptr %lt.1052, align 8
  %127 = call ptr @type_display__Struct_TypeInfo(ptr %126)
  %128 = call ptr @str_concat(ptr @.str.s893, ptr %127)
  call void @sema_error_at__Struct_ASTNode_String(ptr %125, ptr %128)
  ret i1 true

label_2496:                                       ; preds = %label_2487
  %129 = call ptr @type_invalid__Void()
  store ptr %129, ptr %expected.1056, align 8
  %130 = load ptr, ptr %name.1043, align 8
  %131 = call i32 @str_equals(ptr %130, ptr @.str.s899)
  %132 = icmp eq i32 %131, 1
  store i1 %132, ptr %sc.140, align 1
  br i1 %132, label %label_2504, label %label_2503

label_2494:                                       ; preds = %label_2487
  %133 = load ptr, ptr %call.1042, align 8
  %134 = load ptr, ptr %name.1043, align 8
  %135 = load ptr, ptr %arg_ptr.1044, align 8
  %136 = call i1 @sema_check_arity__Struct_ASTNode_String_String_Int(ptr %133, ptr %134, ptr %135, i32 3)
  %137 = icmp eq i1 %136, false
  br i1 %137, label %label_2497, label %label_2499

label_2499:                                       ; preds = %label_2494
  %138 = load ptr, ptr %arg_ptr.1044, align 8
  %139 = call ptr @ptr_to_node(ptr %138)
  store ptr %139, ptr %a0.1053, align 8
  %140 = load ptr, ptr %module.1041, align 8
  %141 = load ptr, ptr %a0.1053, align 8
  %142 = call ptr @sema_expr__Struct_ASTNode_Struct_ASTNode(ptr %140, ptr %141)
  store ptr %142, ptr %lt.1054, align 8
  %143 = load ptr, ptr %lt.1054, align 8
  %144 = getelementptr inbounds nuw %TypeInfo, ptr %143, i32 0, i32 0
  %145 = load i32, ptr %144, align 4
  %146 = icmp ne i32 %145, 11
  br i1 %146, label %label_2500, label %label_2502

label_2497:                                       ; preds = %label_2494
  ret i1 true

label_2502:                                       ; preds = %label_2499
  %147 = load ptr, ptr %a0.1053, align 8
  %148 = getelementptr inbounds nuw %ASTNode, ptr %147, i32 0, i32 8
  %149 = load ptr, ptr %148, align 8
  %150 = call ptr @ptr_to_node(ptr %149)
  store ptr %150, ptr %a1.1055, align 8
  %151 = load ptr, ptr %module.1041, align 8
  %152 = load ptr, ptr %a1.1055, align 8
  %153 = call ptr @type_int__Void()
  %154 = call ptr @sema_check_value__Struct_ASTNode_Struct_ASTNode_Struct_TypeInfo_String(ptr %151, ptr %152, ptr %153, ptr @.str.s897)
  %155 = load ptr, ptr %module.1041, align 8
  %156 = load ptr, ptr %a1.1055, align 8
  %157 = getelementptr inbounds nuw %ASTNode, ptr %156, i32 0, i32 8
  %158 = load ptr, ptr %157, align 8
  %159 = call ptr @ptr_to_node(ptr %158)
  %160 = load ptr, ptr %lt.1054, align 8
  %161 = call ptr @sema_list_element_type__Struct_TypeInfo(ptr %160)
  %162 = call ptr @sema_check_value__Struct_ASTNode_Struct_ASTNode_Struct_TypeInfo_String(ptr %155, ptr %159, ptr %161, ptr @.str.s898)
  ret i1 true

label_2500:                                       ; preds = %label_2499
  %163 = load ptr, ptr %a0.1053, align 8
  %164 = load ptr, ptr %lt.1054, align 8
  %165 = call ptr @type_display__Struct_TypeInfo(ptr %164)
  %166 = call ptr @str_concat(ptr @.str.s896, ptr %165)
  call void @sema_error_at__Struct_ASTNode_String(ptr %163, ptr %166)
  ret i1 true

label_2503:                                       ; preds = %label_2496
  %167 = load ptr, ptr %name.1043, align 8
  %168 = call i32 @str_equals(ptr %167, ptr @.str.s900)
  %169 = icmp eq i32 %168, 1
  store i1 %169, ptr %sc.140, align 1
  br label %label_2504

label_2504:                                       ; preds = %label_2503, %label_2496
  %170 = load i1, ptr %sc.140, align 1
  br i1 %170, label %label_2505, label %label_2507

label_2507:                                       ; preds = %label_2505, %label_2504
  %171 = load ptr, ptr %name.1043, align 8
  %172 = call i32 @str_equals(ptr %171, ptr @.str.s901)
  %173 = icmp eq i32 %172, 1
  store i1 %173, ptr %sc.141, align 1
  br i1 %173, label %label_2509, label %label_2508

label_2505:                                       ; preds = %label_2504
  %174 = call ptr @type_int__Void()
  store ptr %174, ptr %expected.1056, align 8
  br label %label_2507

label_2508:                                       ; preds = %label_2507
  %175 = load ptr, ptr %name.1043, align 8
  %176 = call i32 @str_equals(ptr %175, ptr @.str.s902)
  %177 = icmp eq i32 %176, 1
  store i1 %177, ptr %sc.141, align 1
  br label %label_2509

label_2509:                                       ; preds = %label_2508, %label_2507
  %178 = load i1, ptr %sc.141, align 1
  br i1 %178, label %label_2510, label %label_2512

label_2512:                                       ; preds = %label_2510, %label_2509
  %179 = load ptr, ptr %name.1043, align 8
  %180 = call i32 @str_equals(ptr %179, ptr @.str.s903)
  %181 = icmp eq i32 %180, 1
  store i1 %181, ptr %sc.142, align 1
  br i1 %181, label %label_2514, label %label_2513

label_2510:                                       ; preds = %label_2509
  %182 = call ptr @type_float__Void()
  store ptr %182, ptr %expected.1056, align 8
  br label %label_2512

label_2513:                                       ; preds = %label_2512
  %183 = load ptr, ptr %name.1043, align 8
  %184 = call i32 @str_equals(ptr %183, ptr @.str.s904)
  %185 = icmp eq i32 %184, 1
  store i1 %185, ptr %sc.142, align 1
  br label %label_2514

label_2514:                                       ; preds = %label_2513, %label_2512
  %186 = load i1, ptr %sc.142, align 1
  br i1 %186, label %label_2515, label %label_2517

label_2517:                                       ; preds = %label_2515, %label_2514
  %187 = load ptr, ptr %name.1043, align 8
  %188 = call i32 @str_equals(ptr %187, ptr @.str.s905)
  %189 = icmp eq i32 %188, 1
  store i1 %189, ptr %sc.143, align 1
  br i1 %189, label %label_2519, label %label_2518

label_2515:                                       ; preds = %label_2514
  %190 = call ptr @type_bool__Void()
  store ptr %190, ptr %expected.1056, align 8
  br label %label_2517

label_2518:                                       ; preds = %label_2517
  %191 = load ptr, ptr %name.1043, align 8
  %192 = call i32 @str_equals(ptr %191, ptr @.str.s906)
  %193 = icmp eq i32 %192, 1
  store i1 %193, ptr %sc.143, align 1
  br label %label_2519

label_2519:                                       ; preds = %label_2518, %label_2517
  %194 = load i1, ptr %sc.143, align 1
  br i1 %194, label %label_2520, label %label_2522

label_2522:                                       ; preds = %label_2520, %label_2519
  %195 = load ptr, ptr %expected.1056, align 8
  %196 = call i1 @type_is_valid__Struct_TypeInfo(ptr %195)
  br i1 %196, label %label_2523, label %label_2525

label_2520:                                       ; preds = %label_2519
  %197 = call ptr @type_char__Void()
  store ptr %197, ptr %expected.1056, align 8
  br label %label_2522

label_2525:                                       ; preds = %label_2522
  ret i1 false

label_2523:                                       ; preds = %label_2522
  %198 = load ptr, ptr %call.1042, align 8
  %199 = load ptr, ptr %name.1043, align 8
  %200 = load ptr, ptr %arg_ptr.1044, align 8
  %201 = call i1 @sema_check_arity__Struct_ASTNode_String_String_Int(ptr %198, ptr %199, ptr %200, i32 1)
  %202 = icmp eq i1 %201, false
  br i1 %202, label %label_2526, label %label_2528

label_2528:                                       ; preds = %label_2523
  %203 = load ptr, ptr %module.1041, align 8
  %204 = load ptr, ptr %arg_ptr.1044, align 8
  %205 = call ptr @ptr_to_node(ptr %204)
  %206 = call ptr @sema_expr__Struct_ASTNode_Struct_ASTNode(ptr %203, ptr %205)
  store ptr %206, ptr %actual.1057, align 8
  %207 = load ptr, ptr %arg_ptr.1044, align 8
  %208 = call ptr @ptr_to_node(ptr %207)
  %209 = load ptr, ptr %name.1043, align 8
  %210 = call ptr @diag_quote__String(ptr %209)
  %211 = call ptr @str_concat(ptr %210, ptr @.str.s907)
  %212 = load ptr, ptr %expected.1056, align 8
  %213 = load ptr, ptr %actual.1057, align 8
  call void @sema_expect_assignable__Struct_ASTNode_String_Struct_TypeInfo_Struct_TypeInfo(ptr %208, ptr %211, ptr %212, ptr %213)
  ret i1 true

label_2526:                                       ; preds = %label_2523
  ret i1 true
}

define void @sema_statement__Struct_ASTNode_Struct_ASTNode_Struct_TypeInfo(ptr %0, ptr %1, ptr %2) {
entry:
  %module.1101 = alloca ptr, align 8
  store ptr %0, ptr %module.1101, align 8
  %stmt.1102 = alloca ptr, align 8
  store ptr %1, ptr %stmt.1102, align 8
  %expected_return.1103 = alloca ptr, align 8
  store ptr %2, ptr %expected_return.1103, align 8
  %3 = load ptr, ptr %stmt.1102, align 8
  %4 = getelementptr inbounds nuw %ASTNode, ptr %3, i32 0, i32 0
  %5 = load i32, ptr %4, align 4
  %6 = icmp eq i32 %5, 3
  %var_t.1104 = alloca ptr, align 8
  %has_annotation.1105 = alloca i1, align 1
  %has_init.1106 = alloca i1, align 1
  %sc.176 = alloca i1, align 1
  %target.1107 = alloca ptr, align 8
  %target_t.1108 = alloca ptr, align 8
  %value_t.1109 = alloca ptr, align 8
  %returned.1110 = alloca ptr, align 8
  %is_borrowed_param.1111 = alloca i1, align 1
  %cond_t.1112 = alloca ptr, align 8
  %else_node.1113 = alloca ptr, align 8
  %cond_t2.1114 = alloca ptr, align 8
  %start_t.1115 = alloca ptr, align 8
  %end_t.1116 = alloca ptr, align 8
  %scrut_t.1117 = alloca ptr, align 8
  %sc.177 = alloca i1, align 1
  %pat_expected.1118 = alloca ptr, align 8
  %arm_ptr.1119 = alloca ptr, align 8
  %arm.1120 = alloca ptr, align 8
  br i1 %6, label %label_2755, label %label_2757

label_2757:                                       ; preds = %label_2777, %entry
  %7 = load ptr, ptr %stmt.1102, align 8
  %8 = getelementptr inbounds nuw %ASTNode, ptr %7, i32 0, i32 0
  %9 = load i32, ptr %8, align 4
  %10 = icmp eq i32 %9, 16
  br i1 %10, label %label_2778, label %label_2780

label_2755:                                       ; preds = %entry
  %11 = call ptr @type_invalid__Void()
  store ptr %11, ptr %var_t.1104, align 8
  %12 = load ptr, ptr %stmt.1102, align 8
  %13 = getelementptr inbounds nuw %ASTNode, ptr %12, i32 0, i32 5
  %14 = load ptr, ptr %13, align 8
  %15 = call i32 @str_equals(ptr %14, ptr @.str.s971)
  %16 = icmp eq i32 %15, 0
  store i1 %16, ptr %has_annotation.1105, align 1
  %17 = load ptr, ptr %stmt.1102, align 8
  %18 = getelementptr inbounds nuw %ASTNode, ptr %17, i32 0, i32 6
  %19 = load ptr, ptr %18, align 8
  %20 = call i32 @str_equals(ptr %19, ptr @.str.s972)
  %21 = icmp eq i32 %20, 0
  store i1 %21, ptr %has_init.1106, align 1
  %22 = load i1, ptr %has_annotation.1105, align 1
  br i1 %22, label %label_2758, label %label_2760

label_2760:                                       ; preds = %label_2758, %label_2755
  %23 = load i1, ptr %has_init.1106, align 1
  br i1 %23, label %label_2761, label %label_2763

label_2758:                                       ; preds = %label_2755
  %24 = load ptr, ptr %module.1101, align 8
  %25 = load ptr, ptr %stmt.1102, align 8
  %26 = getelementptr inbounds nuw %ASTNode, ptr %25, i32 0, i32 5
  %27 = load ptr, ptr %26, align 8
  %28 = call ptr @ptr_to_node(ptr %27)
  %29 = call ptr @sema_annotation_type__Struct_ASTNode_Struct_ASTNode(ptr %24, ptr %28)
  store ptr %29, ptr %var_t.1104, align 8
  br label %label_2760

label_2763:                                       ; preds = %label_2766, %label_2760
  %30 = load ptr, ptr %var_t.1104, align 8
  %31 = call i1 @type_is_valid__Struct_TypeInfo(ptr %30)
  %32 = icmp eq i1 %31, false
  br i1 %32, label %label_2767, label %label_2769

label_2761:                                       ; preds = %label_2760
  %33 = load i1, ptr %has_annotation.1105, align 1
  br i1 %33, label %label_2764, label %label_2765

label_2765:                                       ; preds = %label_2761
  %34 = load ptr, ptr %module.1101, align 8
  %35 = load ptr, ptr %stmt.1102, align 8
  %36 = getelementptr inbounds nuw %ASTNode, ptr %35, i32 0, i32 6
  %37 = load ptr, ptr %36, align 8
  %38 = call ptr @ptr_to_node(ptr %37)
  %39 = call ptr @sema_expr__Struct_ASTNode_Struct_ASTNode(ptr %34, ptr %38)
  store ptr %39, ptr %var_t.1104, align 8
  br label %label_2766

label_2764:                                       ; preds = %label_2761
  %40 = load ptr, ptr %module.1101, align 8
  %41 = load ptr, ptr %stmt.1102, align 8
  %42 = getelementptr inbounds nuw %ASTNode, ptr %41, i32 0, i32 6
  %43 = load ptr, ptr %42, align 8
  %44 = call ptr @ptr_to_node(ptr %43)
  %45 = load ptr, ptr %var_t.1104, align 8
  %46 = load ptr, ptr %stmt.1102, align 8
  %47 = getelementptr inbounds nuw %ASTNode, ptr %46, i32 0, i32 1
  %48 = load ptr, ptr %47, align 8
  %49 = call ptr @diag_quote__String(ptr %48)
  %50 = call ptr @str_concat(ptr @.str.s973, ptr %49)
  %51 = call ptr @sema_check_value__Struct_ASTNode_Struct_ASTNode_Struct_TypeInfo_String(ptr %40, ptr %44, ptr %45, ptr %50)
  br label %label_2766

label_2766:                                       ; preds = %label_2765, %label_2764
  %52 = load ptr, ptr %stmt.1102, align 8
  %53 = getelementptr inbounds nuw %ASTNode, ptr %52, i32 0, i32 6
  %54 = load ptr, ptr %53, align 8
  %55 = call ptr @ptr_to_node(ptr %54)
  call void @sema_move_operand__Struct_ASTNode(ptr %55)
  br label %label_2763

label_2769:                                       ; preds = %label_2774, %label_2763
  %56 = load ptr, ptr %stmt.1102, align 8
  %57 = getelementptr inbounds nuw %ASTNode, ptr %56, i32 0, i32 1
  %58 = load ptr, ptr %57, align 8
  call void @ir_unmark_moved(ptr %58)
  %59 = load ptr, ptr %stmt.1102, align 8
  %60 = getelementptr inbounds nuw %ASTNode, ptr %59, i32 0, i32 1
  %61 = load ptr, ptr %60, align 8
  %62 = load ptr, ptr %var_t.1104, align 8
  %63 = call ptr @type_sem_key__Struct_TypeInfo(ptr %62)
  call void @ir_set_var_type(ptr %61, ptr %63)
  %64 = load ptr, ptr %stmt.1102, align 8
  %65 = getelementptr inbounds nuw %ASTNode, ptr %64, i32 0, i32 3
  %66 = load i32, ptr %65, align 4
  %67 = icmp eq i32 %66, 1
  br i1 %67, label %label_2775, label %label_2777

label_2767:                                       ; preds = %label_2763
  %68 = load i1, ptr %has_annotation.1105, align 1
  %69 = icmp eq i1 %68, false
  store i1 %69, ptr %sc.176, align 1
  br i1 %69, label %label_2770, label %label_2771

label_2771:                                       ; preds = %label_2770, %label_2767
  %70 = load i1, ptr %sc.176, align 1
  br i1 %70, label %label_2772, label %label_2774

label_2770:                                       ; preds = %label_2767
  %71 = load i1, ptr %has_init.1106, align 1
  %72 = icmp eq i1 %71, false
  store i1 %72, ptr %sc.176, align 1
  br label %label_2771

label_2774:                                       ; preds = %label_2772, %label_2771
  br label %label_2769

label_2772:                                       ; preds = %label_2771
  %73 = load ptr, ptr %stmt.1102, align 8
  %74 = load ptr, ptr %stmt.1102, align 8
  %75 = getelementptr inbounds nuw %ASTNode, ptr %74, i32 0, i32 1
  %76 = load ptr, ptr %75, align 8
  %77 = call ptr @diag_quote__String(ptr %76)
  %78 = call ptr @str_concat(ptr @.str.s974, ptr %77)
  %79 = call ptr @str_concat(ptr %78, ptr @.str.s975)
  call void @sema_error_at__Struct_ASTNode_String(ptr %73, ptr %79)
  br label %label_2774

label_2777:                                       ; preds = %label_2775, %label_2769
  %80 = load ptr, ptr %stmt.1102, align 8
  %81 = load ptr, ptr %var_t.1104, align 8
  call void @node_set_type__Struct_ASTNode_Struct_TypeInfo(ptr %80, ptr %81)
  br label %label_2757

label_2775:                                       ; preds = %label_2769
  %82 = load ptr, ptr %stmt.1102, align 8
  %83 = getelementptr inbounds nuw %ASTNode, ptr %82, i32 0, i32 1
  %84 = load ptr, ptr %83, align 8
  call void @ir_mark_mutable(ptr %84)
  br label %label_2777

label_2780:                                       ; preds = %label_2783, %label_2757
  %85 = load ptr, ptr %stmt.1102, align 8
  %86 = getelementptr inbounds nuw %ASTNode, ptr %85, i32 0, i32 0
  %87 = load i32, ptr %86, align 4
  %88 = icmp eq i32 %87, 15
  br i1 %88, label %label_2787, label %label_2789

label_2778:                                       ; preds = %label_2757
  %89 = load ptr, ptr %stmt.1102, align 8
  %90 = getelementptr inbounds nuw %ASTNode, ptr %89, i32 0, i32 5
  %91 = load ptr, ptr %90, align 8
  %92 = call ptr @ptr_to_node(ptr %91)
  store ptr %92, ptr %target.1107, align 8
  %93 = load ptr, ptr %target.1107, align 8
  %94 = getelementptr inbounds nuw %ASTNode, ptr %93, i32 0, i32 0
  %95 = load i32, ptr %94, align 4
  %96 = icmp eq i32 %95, 23
  br i1 %96, label %label_2781, label %label_2783

label_2783:                                       ; preds = %label_2786, %label_2778
  %97 = load ptr, ptr %module.1101, align 8
  %98 = load ptr, ptr %target.1107, align 8
  %99 = call ptr @sema_expr__Struct_ASTNode_Struct_ASTNode(ptr %97, ptr %98)
  store ptr %99, ptr %target_t.1108, align 8
  %100 = load ptr, ptr %module.1101, align 8
  %101 = load ptr, ptr %stmt.1102, align 8
  %102 = getelementptr inbounds nuw %ASTNode, ptr %101, i32 0, i32 6
  %103 = load ptr, ptr %102, align 8
  %104 = call ptr @ptr_to_node(ptr %103)
  %105 = call ptr @sema_expr__Struct_ASTNode_Struct_ASTNode(ptr %100, ptr %104)
  store ptr %105, ptr %value_t.1109, align 8
  %106 = load ptr, ptr %stmt.1102, align 8
  %107 = getelementptr inbounds nuw %ASTNode, ptr %106, i32 0, i32 6
  %108 = load ptr, ptr %107, align 8
  %109 = call ptr @ptr_to_node(ptr %108)
  %110 = load ptr, ptr %target_t.1108, align 8
  %111 = load ptr, ptr %value_t.1109, align 8
  call void @sema_expect_assignable__Struct_ASTNode_String_Struct_TypeInfo_Struct_TypeInfo(ptr %109, ptr @.str.s979, ptr %110, ptr %111)
  %112 = load ptr, ptr %stmt.1102, align 8
  %113 = getelementptr inbounds nuw %ASTNode, ptr %112, i32 0, i32 6
  %114 = load ptr, ptr %113, align 8
  %115 = call ptr @ptr_to_node(ptr %114)
  call void @sema_move_operand__Struct_ASTNode(ptr %115)
  br label %label_2780

label_2781:                                       ; preds = %label_2778
  %116 = load ptr, ptr %target.1107, align 8
  %117 = getelementptr inbounds nuw %ASTNode, ptr %116, i32 0, i32 1
  %118 = load ptr, ptr %117, align 8
  %119 = call i32 @ir_var_is_mutable(ptr %118)
  %120 = icmp eq i32 %119, 0
  br i1 %120, label %label_2784, label %label_2786

label_2786:                                       ; preds = %label_2784, %label_2781
  br label %label_2783

label_2784:                                       ; preds = %label_2781
  %121 = load ptr, ptr %target.1107, align 8
  %122 = load ptr, ptr %target.1107, align 8
  %123 = getelementptr inbounds nuw %ASTNode, ptr %122, i32 0, i32 1
  %124 = load ptr, ptr %123, align 8
  %125 = call ptr @diag_quote__String(ptr %124)
  %126 = call ptr @str_concat(ptr @.str.s976, ptr %125)
  %127 = call ptr @str_concat(ptr %126, ptr @.str.s977)
  call void @sema_error_at__Struct_ASTNode_String(ptr %121, ptr %127)
  call void @diag_note(ptr @.str.s978)
  br label %label_2786

label_2789:                                       ; preds = %label_2792, %label_2780
  %128 = load ptr, ptr %stmt.1102, align 8
  %129 = getelementptr inbounds nuw %ASTNode, ptr %128, i32 0, i32 0
  %130 = load i32, ptr %129, align 4
  %131 = icmp eq i32 %130, 17
  br i1 %131, label %label_2802, label %label_2804

label_2787:                                       ; preds = %label_2780
  %132 = load ptr, ptr %stmt.1102, align 8
  %133 = getelementptr inbounds nuw %ASTNode, ptr %132, i32 0, i32 5
  %134 = load ptr, ptr %133, align 8
  %135 = call i32 @str_equals(ptr %134, ptr @.str.s980)
  %136 = icmp eq i32 %135, 0
  br i1 %136, label %label_2790, label %label_2791

label_2791:                                       ; preds = %label_2787
  %137 = load ptr, ptr %stmt.1102, align 8
  %138 = load ptr, ptr %expected_return.1103, align 8
  %139 = call ptr @type_void__Void()
  call void @sema_expect_assignable__Struct_ASTNode_String_Struct_TypeInfo_Struct_TypeInfo(ptr %137, ptr @.str.s984, ptr %138, ptr %139)
  br label %label_2792

label_2790:                                       ; preds = %label_2787
  %140 = load ptr, ptr %module.1101, align 8
  %141 = load ptr, ptr %stmt.1102, align 8
  %142 = getelementptr inbounds nuw %ASTNode, ptr %141, i32 0, i32 5
  %143 = load ptr, ptr %142, align 8
  %144 = call ptr @ptr_to_node(ptr %143)
  %145 = load ptr, ptr %expected_return.1103, align 8
  %146 = call ptr @sema_check_value__Struct_ASTNode_Struct_ASTNode_Struct_TypeInfo_String(ptr %140, ptr %144, ptr %145, ptr @.str.s981)
  %147 = load ptr, ptr %expected_return.1103, align 8
  %148 = getelementptr inbounds nuw %TypeInfo, ptr %147, i32 0, i32 0
  %149 = load i32, ptr %148, align 4
  %150 = icmp eq i32 %149, 10
  br i1 %150, label %label_2793, label %label_2795

label_2795:                                       ; preds = %label_2801, %label_2790
  br label %label_2792

label_2793:                                       ; preds = %label_2790
  %151 = load ptr, ptr %stmt.1102, align 8
  %152 = getelementptr inbounds nuw %ASTNode, ptr %151, i32 0, i32 5
  %153 = load ptr, ptr %152, align 8
  %154 = call ptr @ptr_to_node(ptr %153)
  store ptr %154, ptr %returned.1110, align 8
  store i1 false, ptr %is_borrowed_param.1111, align 1
  %155 = load ptr, ptr %returned.1110, align 8
  %156 = getelementptr inbounds nuw %ASTNode, ptr %155, i32 0, i32 0
  %157 = load i32, ptr %156, align 4
  %158 = icmp eq i32 %157, 23
  br i1 %158, label %label_2796, label %label_2798

label_2798:                                       ; preds = %label_2796, %label_2793
  %159 = load i1, ptr %is_borrowed_param.1111, align 1
  %160 = icmp eq i1 %159, false
  br i1 %160, label %label_2799, label %label_2801

label_2796:                                       ; preds = %label_2793
  %161 = load ptr, ptr %returned.1110, align 8
  %162 = getelementptr inbounds nuw %ASTNode, ptr %161, i32 0, i32 1
  %163 = load ptr, ptr %162, align 8
  %164 = call i32 @ir_is_borrowed(ptr %163)
  %165 = icmp eq i32 %164, 1
  store i1 %165, ptr %is_borrowed_param.1111, align 1
  br label %label_2798

label_2801:                                       ; preds = %label_2799, %label_2798
  br label %label_2795

label_2799:                                       ; preds = %label_2798
  %166 = load ptr, ptr %returned.1110, align 8
  call void @sema_error_at__Struct_ASTNode_String(ptr %166, ptr @.str.s982)
  call void @diag_note(ptr @.str.s983)
  br label %label_2801

label_2792:                                       ; preds = %label_2791, %label_2795
  br label %label_2789

label_2804:                                       ; preds = %label_2807, %label_2789
  %167 = load ptr, ptr %stmt.1102, align 8
  %168 = getelementptr inbounds nuw %ASTNode, ptr %167, i32 0, i32 0
  %169 = load i32, ptr %168, align 4
  %170 = icmp eq i32 %169, 10
  br i1 %170, label %label_2808, label %label_2810

label_2802:                                       ; preds = %label_2789
  %171 = load ptr, ptr %stmt.1102, align 8
  %172 = getelementptr inbounds nuw %ASTNode, ptr %171, i32 0, i32 5
  %173 = load ptr, ptr %172, align 8
  %174 = call i32 @str_equals(ptr %173, ptr @.str.s985)
  %175 = icmp eq i32 %174, 0
  br i1 %175, label %label_2805, label %label_2807

label_2807:                                       ; preds = %label_2805, %label_2802
  br label %label_2804

label_2805:                                       ; preds = %label_2802
  %176 = load ptr, ptr %module.1101, align 8
  %177 = load ptr, ptr %stmt.1102, align 8
  %178 = getelementptr inbounds nuw %ASTNode, ptr %177, i32 0, i32 5
  %179 = load ptr, ptr %178, align 8
  %180 = call ptr @ptr_to_node(ptr %179)
  %181 = call ptr @sema_expr__Struct_ASTNode_Struct_ASTNode(ptr %176, ptr %180)
  br label %label_2807

label_2810:                                       ; preds = %label_2813, %label_2804
  %182 = load ptr, ptr %stmt.1102, align 8
  %183 = getelementptr inbounds nuw %ASTNode, ptr %182, i32 0, i32 0
  %184 = load i32, ptr %183, align 4
  %185 = icmp eq i32 %184, 13
  br i1 %185, label %label_2817, label %label_2819

label_2808:                                       ; preds = %label_2804
  %186 = load ptr, ptr %module.1101, align 8
  %187 = load ptr, ptr %stmt.1102, align 8
  %188 = getelementptr inbounds nuw %ASTNode, ptr %187, i32 0, i32 5
  %189 = load ptr, ptr %188, align 8
  %190 = call ptr @ptr_to_node(ptr %189)
  %191 = call ptr @sema_expr__Struct_ASTNode_Struct_ASTNode(ptr %186, ptr %190)
  store ptr %191, ptr %cond_t.1112, align 8
  %192 = load ptr, ptr %stmt.1102, align 8
  %193 = getelementptr inbounds nuw %ASTNode, ptr %192, i32 0, i32 5
  %194 = load ptr, ptr %193, align 8
  %195 = call ptr @ptr_to_node(ptr %194)
  %196 = call ptr @type_bool__Void()
  %197 = load ptr, ptr %cond_t.1112, align 8
  call void @sema_expect_assignable__Struct_ASTNode_String_Struct_TypeInfo_Struct_TypeInfo(ptr %195, ptr @.str.s986, ptr %196, ptr %197)
  %198 = load ptr, ptr %module.1101, align 8
  %199 = load ptr, ptr %stmt.1102, align 8
  %200 = getelementptr inbounds nuw %ASTNode, ptr %199, i32 0, i32 6
  %201 = load ptr, ptr %200, align 8
  %202 = call ptr @ptr_to_node(ptr %201)
  %203 = load ptr, ptr %expected_return.1103, align 8
  call void @sema_block__Struct_ASTNode_Struct_ASTNode_Struct_TypeInfo(ptr %198, ptr %202, ptr %203)
  %204 = load ptr, ptr %stmt.1102, align 8
  %205 = getelementptr inbounds nuw %ASTNode, ptr %204, i32 0, i32 7
  %206 = load ptr, ptr %205, align 8
  %207 = call i32 @str_equals(ptr %206, ptr @.str.s987)
  %208 = icmp eq i32 %207, 0
  br i1 %208, label %label_2811, label %label_2813

label_2813:                                       ; preds = %label_2816, %label_2808
  br label %label_2810

label_2811:                                       ; preds = %label_2808
  %209 = load ptr, ptr %stmt.1102, align 8
  %210 = getelementptr inbounds nuw %ASTNode, ptr %209, i32 0, i32 7
  %211 = load ptr, ptr %210, align 8
  %212 = call ptr @ptr_to_node(ptr %211)
  store ptr %212, ptr %else_node.1113, align 8
  %213 = load ptr, ptr %else_node.1113, align 8
  %214 = getelementptr inbounds nuw %ASTNode, ptr %213, i32 0, i32 0
  %215 = load i32, ptr %214, align 4
  %216 = icmp eq i32 %215, 10
  br i1 %216, label %label_2814, label %label_2815

label_2815:                                       ; preds = %label_2811
  %217 = load ptr, ptr %module.1101, align 8
  %218 = load ptr, ptr %else_node.1113, align 8
  %219 = load ptr, ptr %expected_return.1103, align 8
  call void @sema_block__Struct_ASTNode_Struct_ASTNode_Struct_TypeInfo(ptr %217, ptr %218, ptr %219)
  br label %label_2816

label_2814:                                       ; preds = %label_2811
  %220 = load ptr, ptr %module.1101, align 8
  %221 = load ptr, ptr %else_node.1113, align 8
  %222 = load ptr, ptr %expected_return.1103, align 8
  call void @sema_statement__Struct_ASTNode_Struct_ASTNode_Struct_TypeInfo(ptr %220, ptr %221, ptr %222)
  br label %label_2816

label_2816:                                       ; preds = %label_2815, %label_2814
  br label %label_2813

label_2819:                                       ; preds = %label_2817, %label_2810
  %223 = load ptr, ptr %stmt.1102, align 8
  %224 = getelementptr inbounds nuw %ASTNode, ptr %223, i32 0, i32 0
  %225 = load i32, ptr %224, align 4
  %226 = icmp eq i32 %225, 14
  br i1 %226, label %label_2820, label %label_2822

label_2817:                                       ; preds = %label_2810
  %227 = load ptr, ptr %module.1101, align 8
  %228 = load ptr, ptr %stmt.1102, align 8
  %229 = getelementptr inbounds nuw %ASTNode, ptr %228, i32 0, i32 5
  %230 = load ptr, ptr %229, align 8
  %231 = call ptr @ptr_to_node(ptr %230)
  %232 = call ptr @sema_expr__Struct_ASTNode_Struct_ASTNode(ptr %227, ptr %231)
  store ptr %232, ptr %cond_t2.1114, align 8
  %233 = load ptr, ptr %stmt.1102, align 8
  %234 = getelementptr inbounds nuw %ASTNode, ptr %233, i32 0, i32 5
  %235 = load ptr, ptr %234, align 8
  %236 = call ptr @ptr_to_node(ptr %235)
  %237 = call ptr @type_bool__Void()
  %238 = load ptr, ptr %cond_t2.1114, align 8
  call void @sema_expect_assignable__Struct_ASTNode_String_Struct_TypeInfo_Struct_TypeInfo(ptr %236, ptr @.str.s988, ptr %237, ptr %238)
  call void @ir_loop_barrier_push()
  %239 = load ptr, ptr %module.1101, align 8
  %240 = load ptr, ptr %stmt.1102, align 8
  %241 = getelementptr inbounds nuw %ASTNode, ptr %240, i32 0, i32 6
  %242 = load ptr, ptr %241, align 8
  %243 = call ptr @ptr_to_node(ptr %242)
  %244 = load ptr, ptr %expected_return.1103, align 8
  call void @sema_block__Struct_ASTNode_Struct_ASTNode_Struct_TypeInfo(ptr %239, ptr %243, ptr %244)
  call void @ir_loop_barrier_pop()
  br label %label_2819

label_2822:                                       ; preds = %label_2820, %label_2819
  %245 = load ptr, ptr %stmt.1102, align 8
  %246 = getelementptr inbounds nuw %ASTNode, ptr %245, i32 0, i32 0
  %247 = load i32, ptr %246, align 4
  %248 = icmp eq i32 %247, 12
  br i1 %248, label %label_2823, label %label_2825

label_2820:                                       ; preds = %label_2819
  call void @ir_loop_barrier_push()
  %249 = load ptr, ptr %module.1101, align 8
  %250 = load ptr, ptr %stmt.1102, align 8
  %251 = getelementptr inbounds nuw %ASTNode, ptr %250, i32 0, i32 5
  %252 = load ptr, ptr %251, align 8
  %253 = call ptr @ptr_to_node(ptr %252)
  %254 = load ptr, ptr %expected_return.1103, align 8
  call void @sema_block__Struct_ASTNode_Struct_ASTNode_Struct_TypeInfo(ptr %249, ptr %253, ptr %254)
  call void @ir_loop_barrier_pop()
  br label %label_2822

label_2825:                                       ; preds = %label_2823, %label_2822
  %255 = load ptr, ptr %stmt.1102, align 8
  %256 = getelementptr inbounds nuw %ASTNode, ptr %255, i32 0, i32 0
  %257 = load i32, ptr %256, align 4
  %258 = icmp eq i32 %257, 11
  br i1 %258, label %label_2826, label %label_2828

label_2823:                                       ; preds = %label_2822
  %259 = load ptr, ptr %module.1101, align 8
  %260 = load ptr, ptr %stmt.1102, align 8
  %261 = getelementptr inbounds nuw %ASTNode, ptr %260, i32 0, i32 5
  %262 = load ptr, ptr %261, align 8
  %263 = call ptr @ptr_to_node(ptr %262)
  %264 = call ptr @sema_expr__Struct_ASTNode_Struct_ASTNode(ptr %259, ptr %263)
  store ptr %264, ptr %start_t.1115, align 8
  %265 = load ptr, ptr %stmt.1102, align 8
  %266 = getelementptr inbounds nuw %ASTNode, ptr %265, i32 0, i32 5
  %267 = load ptr, ptr %266, align 8
  %268 = call ptr @ptr_to_node(ptr %267)
  %269 = call ptr @type_int__Void()
  %270 = load ptr, ptr %start_t.1115, align 8
  call void @sema_expect_assignable__Struct_ASTNode_String_Struct_TypeInfo_Struct_TypeInfo(ptr %268, ptr @.str.s989, ptr %269, ptr %270)
  %271 = load ptr, ptr %module.1101, align 8
  %272 = load ptr, ptr %stmt.1102, align 8
  %273 = getelementptr inbounds nuw %ASTNode, ptr %272, i32 0, i32 6
  %274 = load ptr, ptr %273, align 8
  %275 = call ptr @ptr_to_node(ptr %274)
  %276 = call ptr @sema_expr__Struct_ASTNode_Struct_ASTNode(ptr %271, ptr %275)
  store ptr %276, ptr %end_t.1116, align 8
  %277 = load ptr, ptr %stmt.1102, align 8
  %278 = getelementptr inbounds nuw %ASTNode, ptr %277, i32 0, i32 6
  %279 = load ptr, ptr %278, align 8
  %280 = call ptr @ptr_to_node(ptr %279)
  %281 = call ptr @type_int__Void()
  %282 = load ptr, ptr %end_t.1116, align 8
  call void @sema_expect_assignable__Struct_ASTNode_String_Struct_TypeInfo_Struct_TypeInfo(ptr %280, ptr @.str.s990, ptr %281, ptr %282)
  call void @ir_scope_push()
  %283 = load ptr, ptr %stmt.1102, align 8
  %284 = getelementptr inbounds nuw %ASTNode, ptr %283, i32 0, i32 1
  %285 = load ptr, ptr %284, align 8
  %286 = call ptr @type_int__Void()
  %287 = call ptr @type_sem_key__Struct_TypeInfo(ptr %286)
  call void @ir_set_var_type(ptr %285, ptr %287)
  call void @ir_loop_barrier_push()
  %288 = load ptr, ptr %module.1101, align 8
  %289 = load ptr, ptr %stmt.1102, align 8
  %290 = getelementptr inbounds nuw %ASTNode, ptr %289, i32 0, i32 7
  %291 = load ptr, ptr %290, align 8
  %292 = call ptr @ptr_to_node(ptr %291)
  %293 = load ptr, ptr %expected_return.1103, align 8
  call void @sema_block__Struct_ASTNode_Struct_ASTNode_Struct_TypeInfo(ptr %288, ptr %292, ptr %293)
  call void @ir_loop_barrier_pop()
  call void @ir_scope_pop()
  br label %label_2825

label_2828:                                       ; preds = %label_2839, %label_2825
  ret void

label_2826:                                       ; preds = %label_2825
  %294 = load ptr, ptr %module.1101, align 8
  %295 = load ptr, ptr %stmt.1102, align 8
  %296 = getelementptr inbounds nuw %ASTNode, ptr %295, i32 0, i32 5
  %297 = load ptr, ptr %296, align 8
  %298 = call ptr @ptr_to_node(ptr %297)
  %299 = call ptr @sema_expr__Struct_ASTNode_Struct_ASTNode(ptr %294, ptr %298)
  store ptr %299, ptr %scrut_t.1117, align 8
  %300 = load ptr, ptr %scrut_t.1117, align 8
  %301 = getelementptr inbounds nuw %TypeInfo, ptr %300, i32 0, i32 0
  %302 = load i32, ptr %301, align 4
  %303 = icmp ne i32 %302, 2
  store i1 %303, ptr %sc.177, align 1
  br i1 %303, label %label_2829, label %label_2830

label_2830:                                       ; preds = %label_2829, %label_2826
  %304 = load i1, ptr %sc.177, align 1
  br i1 %304, label %label_2831, label %label_2833

label_2829:                                       ; preds = %label_2826
  %305 = load ptr, ptr %scrut_t.1117, align 8
  %306 = getelementptr inbounds nuw %TypeInfo, ptr %305, i32 0, i32 0
  %307 = load i32, ptr %306, align 4
  %308 = icmp ne i32 %307, 9
  store i1 %308, ptr %sc.177, align 1
  br label %label_2830

label_2833:                                       ; preds = %label_2831, %label_2830
  %309 = load ptr, ptr %scrut_t.1117, align 8
  %310 = call ptr @type_copy__Struct_TypeInfo(ptr %309)
  store ptr %310, ptr %pat_expected.1118, align 8
  %311 = load ptr, ptr %scrut_t.1117, align 8
  %312 = getelementptr inbounds nuw %TypeInfo, ptr %311, i32 0, i32 0
  %313 = load i32, ptr %312, align 4
  %314 = icmp eq i32 %313, 9
  br i1 %314, label %label_2834, label %label_2836

label_2831:                                       ; preds = %label_2830
  %315 = load ptr, ptr %stmt.1102, align 8
  %316 = getelementptr inbounds nuw %ASTNode, ptr %315, i32 0, i32 5
  %317 = load ptr, ptr %316, align 8
  %318 = call ptr @ptr_to_node(ptr %317)
  %319 = load ptr, ptr %scrut_t.1117, align 8
  %320 = call ptr @type_display__Struct_TypeInfo(ptr %319)
  %321 = call ptr @str_concat(ptr @.str.s991, ptr %320)
  call void @sema_error_at__Struct_ASTNode_String(ptr %318, ptr %321)
  br label %label_2833

label_2836:                                       ; preds = %label_2834, %label_2833
  %322 = load ptr, ptr %stmt.1102, align 8
  %323 = getelementptr inbounds nuw %ASTNode, ptr %322, i32 0, i32 6
  %324 = load ptr, ptr %323, align 8
  store ptr %324, ptr %arm_ptr.1119, align 8
  br label %label_2837

label_2834:                                       ; preds = %label_2833
  %325 = call ptr @type_int__Void()
  store ptr %325, ptr %pat_expected.1118, align 8
  br label %label_2836

label_2837:                                       ; preds = %label_2842, %label_2836
  %326 = load ptr, ptr %arm_ptr.1119, align 8
  %327 = call i32 @str_equals(ptr %326, ptr @.str.s992)
  %328 = icmp eq i32 %327, 0
  br i1 %328, label %label_2838, label %label_2839

label_2839:                                       ; preds = %label_2837
  br label %label_2828

label_2838:                                       ; preds = %label_2837
  %329 = load ptr, ptr %arm_ptr.1119, align 8
  %330 = call ptr @ptr_to_node(ptr %329)
  store ptr %330, ptr %arm.1120, align 8
  %331 = load ptr, ptr %arm.1120, align 8
  %332 = getelementptr inbounds nuw %ASTNode, ptr %331, i32 0, i32 1
  %333 = load ptr, ptr %332, align 8
  %334 = call i32 @str_equals(ptr %333, ptr @.str.s993)
  %335 = icmp eq i32 %334, 0
  br i1 %335, label %label_2840, label %label_2842

label_2842:                                       ; preds = %label_2840, %label_2838
  %336 = load ptr, ptr %module.1101, align 8
  %337 = load ptr, ptr %arm.1120, align 8
  %338 = getelementptr inbounds nuw %ASTNode, ptr %337, i32 0, i32 6
  %339 = load ptr, ptr %338, align 8
  %340 = call ptr @ptr_to_node(ptr %339)
  %341 = load ptr, ptr %expected_return.1103, align 8
  call void @sema_block__Struct_ASTNode_Struct_ASTNode_Struct_TypeInfo(ptr %336, ptr %340, ptr %341)
  %342 = load ptr, ptr %arm.1120, align 8
  %343 = getelementptr inbounds nuw %ASTNode, ptr %342, i32 0, i32 8
  %344 = load ptr, ptr %343, align 8
  store ptr %344, ptr %arm_ptr.1119, align 8
  br label %label_2837

label_2840:                                       ; preds = %label_2838
  %345 = load ptr, ptr %module.1101, align 8
  %346 = load ptr, ptr %arm.1120, align 8
  %347 = getelementptr inbounds nuw %ASTNode, ptr %346, i32 0, i32 5
  %348 = load ptr, ptr %347, align 8
  %349 = call ptr @ptr_to_node(ptr %348)
  %350 = load ptr, ptr %pat_expected.1118, align 8
  %351 = call ptr @sema_check_value__Struct_ASTNode_Struct_ASTNode_Struct_TypeInfo_String(ptr %345, ptr %349, ptr %350, ptr @.str.s994)
  br label %label_2842
}

define void @sema_block__Struct_ASTNode_Struct_ASTNode_Struct_TypeInfo(ptr %0, ptr %1, ptr %2) {
entry:
  %module.1121 = alloca ptr, align 8
  store ptr %0, ptr %module.1121, align 8
  %block.1122 = alloca ptr, align 8
  store ptr %1, ptr %block.1122, align 8
  %expected_return.1123 = alloca ptr, align 8
  store ptr %2, ptr %expected_return.1123, align 8
  call void @ir_scope_push()
  %3 = load ptr, ptr %block.1122, align 8
  %4 = getelementptr inbounds nuw %ASTNode, ptr %3, i32 0, i32 5
  %5 = load ptr, ptr %4, align 8
  %stmt_ptr.1124 = alloca ptr, align 8
  store ptr %5, ptr %stmt_ptr.1124, align 8
  %stmt.1125 = alloca ptr, align 8
  %sc.178 = alloca i1, align 1
  br label %label_2843

label_2843:                                       ; preds = %label_2850, %entry
  %6 = load ptr, ptr %stmt_ptr.1124, align 8
  %7 = call i32 @str_equals(ptr %6, ptr @.str.s995)
  %8 = icmp eq i32 %7, 0
  br i1 %8, label %label_2844, label %label_2845

label_2845:                                       ; preds = %label_2843
  call void @ir_scope_pop()
  ret void

label_2844:                                       ; preds = %label_2843
  %9 = load ptr, ptr %stmt_ptr.1124, align 8
  %10 = call ptr @ptr_to_node(ptr %9)
  store ptr %10, ptr %stmt.1125, align 8
  %11 = load ptr, ptr %module.1121, align 8
  %12 = load ptr, ptr %stmt.1125, align 8
  %13 = load ptr, ptr %expected_return.1123, align 8
  call void @sema_statement__Struct_ASTNode_Struct_ASTNode_Struct_TypeInfo(ptr %11, ptr %12, ptr %13)
  %14 = load ptr, ptr %stmt.1125, align 8
  %15 = call i1 @sema_stmt_diverges__Struct_ASTNode(ptr %14)
  store i1 %15, ptr %sc.178, align 1
  br i1 %15, label %label_2846, label %label_2847

label_2847:                                       ; preds = %label_2846, %label_2844
  %16 = load i1, ptr %sc.178, align 1
  br i1 %16, label %label_2848, label %label_2850

label_2846:                                       ; preds = %label_2844
  %17 = load ptr, ptr %stmt.1125, align 8
  %18 = getelementptr inbounds nuw %ASTNode, ptr %17, i32 0, i32 8
  %19 = load ptr, ptr %18, align 8
  %20 = call i32 @str_equals(ptr %19, ptr @.str.s996)
  %21 = icmp eq i32 %20, 0
  store i1 %21, ptr %sc.178, align 1
  br label %label_2847

label_2850:                                       ; preds = %label_2848, %label_2847
  %22 = load ptr, ptr %stmt.1125, align 8
  %23 = getelementptr inbounds nuw %ASTNode, ptr %22, i32 0, i32 8
  %24 = load ptr, ptr %23, align 8
  store ptr %24, ptr %stmt_ptr.1124, align 8
  br label %label_2843

label_2848:                                       ; preds = %label_2847
  %25 = load ptr, ptr %stmt.1125, align 8
  %26 = getelementptr inbounds nuw %ASTNode, ptr %25, i32 0, i32 8
  %27 = load ptr, ptr %26, align 8
  %28 = call ptr @ptr_to_node(ptr %27)
  call void @sema_error_at__Struct_ASTNode_String(ptr %28, ptr @.str.s997)
  br label %label_2850
}

define void @sema_predeclare_function__Struct_ASTNode_Struct_ASTNode(ptr %0, ptr %1) {
entry:
  %module.1126 = alloca ptr, align 8
  store ptr %0, ptr %module.1126, align 8
  %fn_node.1127 = alloca ptr, align 8
  store ptr %1, ptr %fn_node.1127, align 8
  %2 = call ptr @type_void__Void()
  %ret_t.1128 = alloca ptr, align 8
  store ptr %2, ptr %ret_t.1128, align 8
  %3 = load ptr, ptr %fn_node.1127, align 8
  %4 = getelementptr inbounds nuw %ASTNode, ptr %3, i32 0, i32 0
  %5 = load i32, ptr %4, align 4
  %6 = icmp eq i32 %5, 4
  %symbol.1129 = alloca ptr, align 8
  %overload_key.1130 = alloca ptr, align 8
  %first.1131 = alloca ptr, align 8
  br i1 %6, label %label_2851, label %label_2852

label_2852:                                       ; preds = %entry
  %7 = load ptr, ptr %module.1126, align 8
  %8 = load ptr, ptr %fn_node.1127, align 8
  %9 = getelementptr inbounds nuw %ASTNode, ptr %8, i32 0, i32 6
  %10 = load ptr, ptr %9, align 8
  %11 = call ptr @sema_declared_return_type__Struct_ASTNode_String(ptr %7, ptr %10)
  store ptr %11, ptr %ret_t.1128, align 8
  br label %label_2853

label_2851:                                       ; preds = %entry
  %12 = load ptr, ptr %module.1126, align 8
  %13 = load ptr, ptr %fn_node.1127, align 8
  %14 = getelementptr inbounds nuw %ASTNode, ptr %13, i32 0, i32 7
  %15 = load ptr, ptr %14, align 8
  %16 = call ptr @sema_declared_return_type__Struct_ASTNode_String(ptr %12, ptr %15)
  store ptr %16, ptr %ret_t.1128, align 8
  %17 = load ptr, ptr %fn_node.1127, align 8
  %18 = getelementptr inbounds nuw %ASTNode, ptr %17, i32 0, i32 1
  %19 = load ptr, ptr %18, align 8
  %20 = call i32 @str_equals(ptr %19, ptr @.str.s998)
  %21 = icmp eq i32 %20, 1
  br i1 %21, label %label_2854, label %label_2856

label_2856:                                       ; preds = %label_2854, %label_2851
  br label %label_2853

label_2854:                                       ; preds = %label_2851
  %22 = call ptr @type_int__Void()
  store ptr %22, ptr %ret_t.1128, align 8
  br label %label_2856

label_2853:                                       ; preds = %label_2852, %label_2856
  %23 = load ptr, ptr %fn_node.1127, align 8
  %24 = getelementptr inbounds nuw %ASTNode, ptr %23, i32 0, i32 2
  %25 = load ptr, ptr %24, align 8
  store ptr %25, ptr %symbol.1129, align 8
  %26 = load ptr, ptr %symbol.1129, align 8
  %27 = call ptr @sema_fn_key__String(ptr %26)
  store ptr %27, ptr %overload_key.1130, align 8
  %28 = load ptr, ptr %module.1126, align 8
  %29 = load ptr, ptr %symbol.1129, align 8
  %30 = call i32 @sema_function_symbol_count__Struct_ASTNode_String(ptr %28, ptr %29)
  %31 = icmp sgt i32 %30, 1
  br i1 %31, label %label_2857, label %label_2859

label_2859:                                       ; preds = %label_2862, %label_2853
  %32 = load ptr, ptr %overload_key.1130, align 8
  %33 = load ptr, ptr %ret_t.1128, align 8
  %34 = call ptr @type_sem_key__Struct_TypeInfo(ptr %33)
  call void @ir_set_var_type(ptr %32, ptr %34)
  ret void

label_2857:                                       ; preds = %label_2853
  %35 = load ptr, ptr %module.1126, align 8
  %36 = load ptr, ptr %symbol.1129, align 8
  %37 = call ptr @sema_first_function_with_symbol__Struct_ASTNode_String(ptr %35, ptr %36)
  store ptr %37, ptr %first.1131, align 8
  %38 = load ptr, ptr %first.1131, align 8
  %39 = load ptr, ptr %fn_node.1127, align 8
  %40 = call i1 @sema_same_position__Struct_ASTNode_Struct_ASTNode(ptr %38, ptr %39)
  %41 = icmp eq i1 %40, false
  br i1 %41, label %label_2860, label %label_2862

label_2862:                                       ; preds = %label_2860, %label_2857
  br label %label_2859

label_2860:                                       ; preds = %label_2857
  %42 = load ptr, ptr %fn_node.1127, align 8
  %43 = load ptr, ptr %fn_node.1127, align 8
  %44 = getelementptr inbounds nuw %ASTNode, ptr %43, i32 0, i32 1
  %45 = load ptr, ptr %44, align 8
  %46 = call ptr @diag_quote__String(ptr %45)
  %47 = call ptr @str_concat(ptr @.str.s999, ptr %46)
  %48 = call ptr @str_concat(ptr %47, ptr @.str.s1000)
  call void @sema_error_at__Struct_ASTNode_String(ptr %42, ptr %48)
  %49 = load ptr, ptr %first.1131, align 8
  %50 = getelementptr inbounds nuw %ASTNode, ptr %49, i32 0, i32 13
  %51 = load i32, ptr %50, align 4
  %52 = load ptr, ptr %first.1131, align 8
  %53 = getelementptr inbounds nuw %ASTNode, ptr %52, i32 0, i32 10
  %54 = load i32, ptr %53, align 4
  %55 = load ptr, ptr %first.1131, align 8
  %56 = getelementptr inbounds nuw %ASTNode, ptr %55, i32 0, i32 11
  %57 = load i32, ptr %56, align 4
  %58 = load ptr, ptr %first.1131, align 8
  %59 = getelementptr inbounds nuw %ASTNode, ptr %58, i32 0, i32 12
  %60 = load i32, ptr %59, align 4
  call void @diag_note_at(i32 %51, i32 %54, i32 %57, i32 %60, ptr @.str.s1001)
  br label %label_2862
}

define void @sema_predeclare_global__Struct_ASTNode_Struct_ASTNode(ptr %0, ptr %1) {
entry:
  %module.1132 = alloca ptr, align 8
  store ptr %0, ptr %module.1132, align 8
  %var_node.1133 = alloca ptr, align 8
  store ptr %1, ptr %var_node.1133, align 8
  %2 = call ptr @type_invalid__Void()
  %var_t.1134 = alloca ptr, align 8
  store ptr %2, ptr %var_t.1134, align 8
  %3 = load ptr, ptr %var_node.1133, align 8
  %4 = getelementptr inbounds nuw %ASTNode, ptr %3, i32 0, i32 5
  %5 = load ptr, ptr %4, align 8
  %6 = call i32 @str_equals(ptr %5, ptr @.str.s1002)
  %7 = icmp eq i32 %6, 0
  %init.1135 = alloca ptr, align 8
  %sc.179 = alloca i1, align 1
  br i1 %7, label %label_2863, label %label_2865

label_2865:                                       ; preds = %label_2863, %entry
  %8 = load ptr, ptr %var_node.1133, align 8
  %9 = getelementptr inbounds nuw %ASTNode, ptr %8, i32 0, i32 6
  %10 = load ptr, ptr %9, align 8
  %11 = call i32 @str_equals(ptr %10, ptr @.str.s1003)
  %12 = icmp eq i32 %11, 0
  br i1 %12, label %label_2866, label %label_2868

label_2863:                                       ; preds = %entry
  %13 = load ptr, ptr %module.1132, align 8
  %14 = load ptr, ptr %var_node.1133, align 8
  %15 = getelementptr inbounds nuw %ASTNode, ptr %14, i32 0, i32 5
  %16 = load ptr, ptr %15, align 8
  %17 = call ptr @ptr_to_node(ptr %16)
  %18 = call ptr @sema_annotation_type__Struct_ASTNode_Struct_ASTNode(ptr %13, ptr %17)
  store ptr %18, ptr %var_t.1134, align 8
  br label %label_2865

label_2868:                                       ; preds = %label_2874, %label_2865
  %19 = load ptr, ptr %var_t.1134, align 8
  %20 = call i1 @type_is_valid__Struct_TypeInfo(ptr %19)
  %21 = icmp eq i1 %20, false
  br i1 %21, label %label_2875, label %label_2877

label_2866:                                       ; preds = %label_2865
  %22 = load ptr, ptr %var_t.1134, align 8
  %23 = call i1 @type_is_valid__Struct_TypeInfo(ptr %22)
  br i1 %23, label %label_2869, label %label_2870

label_2870:                                       ; preds = %label_2866
  %24 = load ptr, ptr %module.1132, align 8
  %25 = load ptr, ptr %var_node.1133, align 8
  %26 = getelementptr inbounds nuw %ASTNode, ptr %25, i32 0, i32 6
  %27 = load ptr, ptr %26, align 8
  %28 = call ptr @ptr_to_node(ptr %27)
  %29 = call ptr @sema_expr__Struct_ASTNode_Struct_ASTNode(ptr %24, ptr %28)
  store ptr %29, ptr %var_t.1134, align 8
  br label %label_2871

label_2869:                                       ; preds = %label_2866
  %30 = load ptr, ptr %module.1132, align 8
  %31 = load ptr, ptr %var_node.1133, align 8
  %32 = getelementptr inbounds nuw %ASTNode, ptr %31, i32 0, i32 6
  %33 = load ptr, ptr %32, align 8
  %34 = call ptr @ptr_to_node(ptr %33)
  %35 = load ptr, ptr %var_t.1134, align 8
  %36 = load ptr, ptr %var_node.1133, align 8
  %37 = getelementptr inbounds nuw %ASTNode, ptr %36, i32 0, i32 1
  %38 = load ptr, ptr %37, align 8
  %39 = call ptr @diag_quote__String(ptr %38)
  %40 = call ptr @str_concat(ptr @.str.s1004, ptr %39)
  %41 = call ptr @sema_check_value__Struct_ASTNode_Struct_ASTNode_Struct_TypeInfo_String(ptr %30, ptr %34, ptr %35, ptr %40)
  br label %label_2871

label_2871:                                       ; preds = %label_2870, %label_2869
  %42 = load ptr, ptr %var_node.1133, align 8
  %43 = getelementptr inbounds nuw %ASTNode, ptr %42, i32 0, i32 6
  %44 = load ptr, ptr %43, align 8
  %45 = call ptr @ptr_to_node(ptr %44)
  store ptr %45, ptr %init.1135, align 8
  %46 = load ptr, ptr %init.1135, align 8
  %47 = getelementptr inbounds nuw %ASTNode, ptr %46, i32 0, i32 0
  %48 = load i32, ptr %47, align 4
  %49 = icmp ne i32 %48, 22
  br i1 %49, label %label_2872, label %label_2874

label_2874:                                       ; preds = %label_2872, %label_2871
  br label %label_2868

label_2872:                                       ; preds = %label_2871
  %50 = load ptr, ptr %init.1135, align 8
  %51 = load ptr, ptr %var_node.1133, align 8
  %52 = getelementptr inbounds nuw %ASTNode, ptr %51, i32 0, i32 1
  %53 = load ptr, ptr %52, align 8
  %54 = call ptr @diag_quote__String(ptr %53)
  %55 = call ptr @str_concat(ptr @.str.s1005, ptr %54)
  %56 = call ptr @str_concat(ptr %55, ptr @.str.s1006)
  call void @sema_error_at__Struct_ASTNode_String(ptr %50, ptr %56)
  call void @diag_note(ptr @.str.s1007)
  br label %label_2874

label_2877:                                       ; preds = %label_2882, %label_2868
  %57 = load ptr, ptr %var_node.1133, align 8
  %58 = getelementptr inbounds nuw %ASTNode, ptr %57, i32 0, i32 1
  %59 = load ptr, ptr %58, align 8
  call void @ir_register_global_name(ptr %59)
  %60 = load ptr, ptr %var_node.1133, align 8
  %61 = getelementptr inbounds nuw %ASTNode, ptr %60, i32 0, i32 1
  %62 = load ptr, ptr %61, align 8
  %63 = load ptr, ptr %var_t.1134, align 8
  %64 = call ptr @type_sem_key__Struct_TypeInfo(ptr %63)
  call void @ir_set_global_var_type(ptr %62, ptr %64)
  %65 = load ptr, ptr %var_node.1133, align 8
  %66 = getelementptr inbounds nuw %ASTNode, ptr %65, i32 0, i32 3
  %67 = load i32, ptr %66, align 4
  %68 = icmp eq i32 %67, 1
  br i1 %68, label %label_2883, label %label_2885

label_2875:                                       ; preds = %label_2868
  %69 = load ptr, ptr %var_node.1133, align 8
  %70 = getelementptr inbounds nuw %ASTNode, ptr %69, i32 0, i32 5
  %71 = load ptr, ptr %70, align 8
  %72 = call i32 @str_equals(ptr %71, ptr @.str.s1008)
  %73 = icmp eq i32 %72, 1
  store i1 %73, ptr %sc.179, align 1
  br i1 %73, label %label_2878, label %label_2879

label_2879:                                       ; preds = %label_2878, %label_2875
  %74 = load i1, ptr %sc.179, align 1
  br i1 %74, label %label_2880, label %label_2882

label_2878:                                       ; preds = %label_2875
  %75 = load ptr, ptr %var_node.1133, align 8
  %76 = getelementptr inbounds nuw %ASTNode, ptr %75, i32 0, i32 6
  %77 = load ptr, ptr %76, align 8
  %78 = call i32 @str_equals(ptr %77, ptr @.str.s1009)
  %79 = icmp eq i32 %78, 1
  store i1 %79, ptr %sc.179, align 1
  br label %label_2879

label_2882:                                       ; preds = %label_2880, %label_2879
  br label %label_2877

label_2880:                                       ; preds = %label_2879
  %80 = load ptr, ptr %var_node.1133, align 8
  %81 = load ptr, ptr %var_node.1133, align 8
  %82 = getelementptr inbounds nuw %ASTNode, ptr %81, i32 0, i32 1
  %83 = load ptr, ptr %82, align 8
  %84 = call ptr @diag_quote__String(ptr %83)
  %85 = call ptr @str_concat(ptr @.str.s1010, ptr %84)
  %86 = call ptr @str_concat(ptr %85, ptr @.str.s1011)
  call void @sema_error_at__Struct_ASTNode_String(ptr %80, ptr %86)
  br label %label_2882

label_2885:                                       ; preds = %label_2883, %label_2877
  %87 = load ptr, ptr %var_node.1133, align 8
  %88 = load ptr, ptr %var_t.1134, align 8
  call void @node_set_type__Struct_ASTNode_Struct_TypeInfo(ptr %87, ptr %88)
  ret void

label_2883:                                       ; preds = %label_2877
  %89 = load ptr, ptr %var_node.1133, align 8
  %90 = getelementptr inbounds nuw %ASTNode, ptr %89, i32 0, i32 1
  %91 = load ptr, ptr %90, align 8
  call void @ir_mark_mutable(ptr %91)
  br label %label_2885
}

define void @sema_function__Struct_ASTNode_Struct_ASTNode(ptr %0, ptr %1) {
entry:
  %module.1136 = alloca ptr, align 8
  store ptr %0, ptr %module.1136, align 8
  %fn_node.1137 = alloca ptr, align 8
  store ptr %1, ptr %fn_node.1137, align 8
  call void @ir_clear_local_var_types()
  call void @ir_clear_moved()
  call void @ir_clear_borrowed()
  call void @ir_scope_push()
  %2 = load ptr, ptr %module.1136, align 8
  %3 = load ptr, ptr %fn_node.1137, align 8
  %4 = getelementptr inbounds nuw %ASTNode, ptr %3, i32 0, i32 7
  %5 = load ptr, ptr %4, align 8
  %6 = call ptr @sema_declared_return_type__Struct_ASTNode_String(ptr %2, ptr %5)
  %expected_return.1138 = alloca ptr, align 8
  store ptr %6, ptr %expected_return.1138, align 8
  %7 = load ptr, ptr %fn_node.1137, align 8
  %8 = getelementptr inbounds nuw %ASTNode, ptr %7, i32 0, i32 1
  %9 = load ptr, ptr %8, align 8
  %10 = call i32 @str_equals(ptr %9, ptr @.str.s1012)
  %11 = icmp eq i32 %10, 1
  %param_ptr.1139 = alloca ptr, align 8
  %param.1140 = alloca ptr, align 8
  %param_t.1141 = alloca ptr, align 8
  %sc.180 = alloca i1, align 1
  %body.1142 = alloca ptr, align 8
  br i1 %11, label %label_2886, label %label_2888

label_2888:                                       ; preds = %label_2886, %entry
  %12 = load ptr, ptr %fn_node.1137, align 8
  %13 = getelementptr inbounds nuw %ASTNode, ptr %12, i32 0, i32 5
  %14 = load ptr, ptr %13, align 8
  store ptr %14, ptr %param_ptr.1139, align 8
  br label %label_2889

label_2886:                                       ; preds = %entry
  %15 = call ptr @type_int__Void()
  store ptr %15, ptr %expected_return.1138, align 8
  br label %label_2888

label_2889:                                       ; preds = %label_2899, %label_2888
  %16 = load ptr, ptr %param_ptr.1139, align 8
  %17 = call i32 @str_equals(ptr %16, ptr @.str.s1013)
  %18 = icmp eq i32 %17, 0
  br i1 %18, label %label_2890, label %label_2891

label_2891:                                       ; preds = %label_2889
  %19 = load ptr, ptr %fn_node.1137, align 8
  %20 = getelementptr inbounds nuw %ASTNode, ptr %19, i32 0, i32 6
  %21 = load ptr, ptr %20, align 8
  %22 = call i32 @str_equals(ptr %21, ptr @.str.s1018)
  %23 = icmp eq i32 %22, 0
  br i1 %23, label %label_2900, label %label_2902

label_2890:                                       ; preds = %label_2889
  %24 = load ptr, ptr %param_ptr.1139, align 8
  %25 = call ptr @ptr_to_node(ptr %24)
  store ptr %25, ptr %param.1140, align 8
  %26 = load ptr, ptr %module.1136, align 8
  %27 = load ptr, ptr %param.1140, align 8
  %28 = getelementptr inbounds nuw %ASTNode, ptr %27, i32 0, i32 5
  %29 = load ptr, ptr %28, align 8
  %30 = call ptr @ptr_to_node(ptr %29)
  %31 = call ptr @sema_annotation_type__Struct_ASTNode_Struct_ASTNode(ptr %26, ptr %30)
  store ptr %31, ptr %param_t.1141, align 8
  %32 = load ptr, ptr %param.1140, align 8
  %33 = getelementptr inbounds nuw %ASTNode, ptr %32, i32 0, i32 2
  %34 = load ptr, ptr %33, align 8
  %35 = call i32 @str_equals(ptr %34, ptr @.str.s1014)
  %36 = icmp eq i32 %35, 1
  store i1 %36, ptr %sc.180, align 1
  br i1 %36, label %label_2892, label %label_2893

label_2893:                                       ; preds = %label_2892, %label_2890
  %37 = load i1, ptr %sc.180, align 1
  br i1 %37, label %label_2894, label %label_2896

label_2892:                                       ; preds = %label_2890
  %38 = load ptr, ptr %param_t.1141, align 8
  %39 = call i1 @type_is_move_only__Struct_TypeInfo(ptr %38)
  %40 = icmp eq i1 %39, false
  store i1 %40, ptr %sc.180, align 1
  br label %label_2893

label_2896:                                       ; preds = %label_2894, %label_2893
  %41 = load ptr, ptr %param.1140, align 8
  %42 = getelementptr inbounds nuw %ASTNode, ptr %41, i32 0, i32 2
  %43 = load ptr, ptr %42, align 8
  %44 = call i32 @str_equals(ptr %43, ptr @.str.s1017)
  %45 = icmp eq i32 %44, 0
  br i1 %45, label %label_2897, label %label_2899

label_2894:                                       ; preds = %label_2893
  %46 = load ptr, ptr %param.1140, align 8
  %47 = load ptr, ptr %param.1140, align 8
  %48 = getelementptr inbounds nuw %ASTNode, ptr %47, i32 0, i32 1
  %49 = load ptr, ptr %48, align 8
  %50 = call ptr @diag_quote__String(ptr %49)
  %51 = call ptr @str_concat(ptr @.str.s1015, ptr %50)
  %52 = call ptr @str_concat(ptr %51, ptr @.str.s1016)
  call void @sema_error_at__Struct_ASTNode_String(ptr %46, ptr %52)
  br label %label_2896

label_2899:                                       ; preds = %label_2897, %label_2896
  %53 = load ptr, ptr %param.1140, align 8
  %54 = getelementptr inbounds nuw %ASTNode, ptr %53, i32 0, i32 1
  %55 = load ptr, ptr %54, align 8
  %56 = load ptr, ptr %param_t.1141, align 8
  %57 = call ptr @type_sem_key__Struct_TypeInfo(ptr %56)
  call void @ir_set_var_type(ptr %55, ptr %57)
  %58 = load ptr, ptr %param.1140, align 8
  %59 = load ptr, ptr %param_t.1141, align 8
  call void @node_set_type__Struct_ASTNode_Struct_TypeInfo(ptr %58, ptr %59)
  %60 = load ptr, ptr %param.1140, align 8
  %61 = getelementptr inbounds nuw %ASTNode, ptr %60, i32 0, i32 8
  %62 = load ptr, ptr %61, align 8
  store ptr %62, ptr %param_ptr.1139, align 8
  br label %label_2889

label_2897:                                       ; preds = %label_2896
  %63 = load ptr, ptr %param.1140, align 8
  %64 = getelementptr inbounds nuw %ASTNode, ptr %63, i32 0, i32 1
  %65 = load ptr, ptr %64, align 8
  call void @ir_mark_borrowed(ptr %65)
  br label %label_2899

label_2902:                                       ; preds = %label_2905, %label_2891
  call void @ir_scope_pop()
  ret void

label_2900:                                       ; preds = %label_2891
  %66 = load ptr, ptr %fn_node.1137, align 8
  %67 = getelementptr inbounds nuw %ASTNode, ptr %66, i32 0, i32 6
  %68 = load ptr, ptr %67, align 8
  %69 = call ptr @ptr_to_node(ptr %68)
  store ptr %69, ptr %body.1142, align 8
  %70 = load ptr, ptr %module.1136, align 8
  %71 = load ptr, ptr %body.1142, align 8
  %72 = load ptr, ptr %expected_return.1138, align 8
  call void @sema_block__Struct_ASTNode_Struct_ASTNode_Struct_TypeInfo(ptr %70, ptr %71, ptr %72)
  %73 = load ptr, ptr %expected_return.1138, align 8
  %74 = getelementptr inbounds nuw %TypeInfo, ptr %73, i32 0, i32 0
  %75 = load i32, ptr %74, align 4
  %76 = icmp ne i32 %75, 1
  br i1 %76, label %label_2903, label %label_2905

label_2905:                                       ; preds = %label_2908, %label_2900
  br label %label_2902

label_2903:                                       ; preds = %label_2900
  %77 = load ptr, ptr %body.1142, align 8
  %78 = call i1 @sema_block_diverges__Struct_ASTNode(ptr %77)
  %79 = icmp eq i1 %78, false
  br i1 %79, label %label_2906, label %label_2908

label_2908:                                       ; preds = %label_2906, %label_2903
  br label %label_2905

label_2906:                                       ; preds = %label_2903
  %80 = load ptr, ptr %fn_node.1137, align 8
  %81 = load ptr, ptr %fn_node.1137, align 8
  %82 = getelementptr inbounds nuw %ASTNode, ptr %81, i32 0, i32 1
  %83 = load ptr, ptr %82, align 8
  %84 = call ptr @diag_quote__String(ptr %83)
  %85 = call ptr @str_concat(ptr @.str.s1019, ptr %84)
  %86 = load ptr, ptr %expected_return.1138, align 8
  %87 = call ptr @type_display__Struct_TypeInfo(ptr %86)
  %88 = call ptr @str_concat(ptr @.str.s1020, ptr %87)
  %89 = call ptr @str_concat(ptr %88, ptr @.str.s1021)
  %90 = call ptr @str_concat(ptr %85, ptr %89)
  call void @sema_error_at__Struct_ASTNode_String(ptr %80, ptr %90)
  br label %label_2908
}

define void @analyze_module__Struct_ASTNode(ptr %0) {
entry:
  %module.1143 = alloca ptr, align 8
  store ptr %0, ptr %module.1143, align 8
  call void @ir_clear_var_types()
  call void @ir_reset_globals()
  %1 = load ptr, ptr %module.1143, align 8
  call void @sema_register_named_types__Struct_ASTNode(ptr %1)
  %2 = load ptr, ptr %module.1143, align 8
  call void @sema_cache_function_symbols__Struct_ASTNode(ptr %2)
  %3 = load ptr, ptr %module.1143, align 8
  %4 = getelementptr inbounds nuw %ASTNode, ptr %3, i32 0, i32 5
  %5 = load ptr, ptr %4, align 8
  %fn_ptr.1144 = alloca ptr, align 8
  store ptr %5, ptr %fn_ptr.1144, align 8
  %stmt.1145 = alloca ptr, align 8
  %sc.181 = alloca i1, align 1
  %global_ptr.1146 = alloca ptr, align 8
  %stmt2.1147 = alloca ptr, align 8
  %stmt_ptr.1148 = alloca ptr, align 8
  %stmt3.1149 = alloca ptr, align 8
  br label %label_2909

label_2909:                                       ; preds = %label_2916, %entry
  %6 = load ptr, ptr %fn_ptr.1144, align 8
  %7 = call i32 @str_equals(ptr %6, ptr @.str.s1022)
  %8 = icmp eq i32 %7, 0
  br i1 %8, label %label_2910, label %label_2911

label_2911:                                       ; preds = %label_2909
  %9 = load ptr, ptr %module.1143, align 8
  %10 = getelementptr inbounds nuw %ASTNode, ptr %9, i32 0, i32 5
  %11 = load ptr, ptr %10, align 8
  store ptr %11, ptr %global_ptr.1146, align 8
  br label %label_2917

label_2910:                                       ; preds = %label_2909
  %12 = load ptr, ptr %fn_ptr.1144, align 8
  %13 = call ptr @ptr_to_node(ptr %12)
  store ptr %13, ptr %stmt.1145, align 8
  %14 = load ptr, ptr %stmt.1145, align 8
  %15 = getelementptr inbounds nuw %ASTNode, ptr %14, i32 0, i32 0
  %16 = load i32, ptr %15, align 4
  %17 = icmp eq i32 %16, 4
  store i1 %17, ptr %sc.181, align 1
  br i1 %17, label %label_2913, label %label_2912

label_2912:                                       ; preds = %label_2910
  %18 = load ptr, ptr %stmt.1145, align 8
  %19 = getelementptr inbounds nuw %ASTNode, ptr %18, i32 0, i32 0
  %20 = load i32, ptr %19, align 4
  %21 = icmp eq i32 %20, 2
  store i1 %21, ptr %sc.181, align 1
  br label %label_2913

label_2913:                                       ; preds = %label_2912, %label_2910
  %22 = load i1, ptr %sc.181, align 1
  br i1 %22, label %label_2914, label %label_2916

label_2916:                                       ; preds = %label_2914, %label_2913
  %23 = load ptr, ptr %stmt.1145, align 8
  %24 = getelementptr inbounds nuw %ASTNode, ptr %23, i32 0, i32 8
  %25 = load ptr, ptr %24, align 8
  store ptr %25, ptr %fn_ptr.1144, align 8
  br label %label_2909

label_2914:                                       ; preds = %label_2913
  %26 = load ptr, ptr %module.1143, align 8
  %27 = load ptr, ptr %stmt.1145, align 8
  call void @sema_predeclare_function__Struct_ASTNode_Struct_ASTNode(ptr %26, ptr %27)
  br label %label_2916

label_2917:                                       ; preds = %label_2922, %label_2911
  %28 = load ptr, ptr %global_ptr.1146, align 8
  %29 = call i32 @str_equals(ptr %28, ptr @.str.s1023)
  %30 = icmp eq i32 %29, 0
  br i1 %30, label %label_2918, label %label_2919

label_2919:                                       ; preds = %label_2917
  %31 = load ptr, ptr %module.1143, align 8
  %32 = getelementptr inbounds nuw %ASTNode, ptr %31, i32 0, i32 5
  %33 = load ptr, ptr %32, align 8
  store ptr %33, ptr %stmt_ptr.1148, align 8
  br label %label_2923

label_2918:                                       ; preds = %label_2917
  %34 = load ptr, ptr %global_ptr.1146, align 8
  %35 = call ptr @ptr_to_node(ptr %34)
  store ptr %35, ptr %stmt2.1147, align 8
  %36 = load ptr, ptr %stmt2.1147, align 8
  %37 = getelementptr inbounds nuw %ASTNode, ptr %36, i32 0, i32 0
  %38 = load i32, ptr %37, align 4
  %39 = icmp eq i32 %38, 3
  br i1 %39, label %label_2920, label %label_2922

label_2922:                                       ; preds = %label_2920, %label_2918
  %40 = load ptr, ptr %stmt2.1147, align 8
  %41 = getelementptr inbounds nuw %ASTNode, ptr %40, i32 0, i32 8
  %42 = load ptr, ptr %41, align 8
  store ptr %42, ptr %global_ptr.1146, align 8
  br label %label_2917

label_2920:                                       ; preds = %label_2918
  %43 = load ptr, ptr %module.1143, align 8
  %44 = load ptr, ptr %stmt2.1147, align 8
  call void @sema_predeclare_global__Struct_ASTNode_Struct_ASTNode(ptr %43, ptr %44)
  br label %label_2922

label_2923:                                       ; preds = %label_2928, %label_2919
  %45 = load ptr, ptr %stmt_ptr.1148, align 8
  %46 = call i32 @str_equals(ptr %45, ptr @.str.s1024)
  %47 = icmp eq i32 %46, 0
  br i1 %47, label %label_2924, label %label_2925

label_2925:                                       ; preds = %label_2923
  ret void

label_2924:                                       ; preds = %label_2923
  %48 = load ptr, ptr %stmt_ptr.1148, align 8
  %49 = call ptr @ptr_to_node(ptr %48)
  store ptr %49, ptr %stmt3.1149, align 8
  %50 = load ptr, ptr %stmt3.1149, align 8
  %51 = getelementptr inbounds nuw %ASTNode, ptr %50, i32 0, i32 0
  %52 = load i32, ptr %51, align 4
  %53 = icmp eq i32 %52, 4
  br i1 %53, label %label_2926, label %label_2928

label_2928:                                       ; preds = %label_2926, %label_2924
  %54 = load ptr, ptr %stmt3.1149, align 8
  %55 = getelementptr inbounds nuw %ASTNode, ptr %54, i32 0, i32 8
  %56 = load ptr, ptr %55, align 8
  store ptr %56, ptr %stmt_ptr.1148, align 8
  br label %label_2923

label_2926:                                       ; preds = %label_2924
  %57 = load ptr, ptr %module.1143, align 8
  %58 = load ptr, ptr %stmt3.1149, align 8
  call void @sema_function__Struct_ASTNode_Struct_ASTNode(ptr %57, ptr %58)
  br label %label_2928
}

define i1 @is_named_top_level__Struct_ASTNode(ptr %0) {
entry:
  %stmt.1150 = alloca ptr, align 8
  store ptr %0, ptr %stmt.1150, align 8
  %1 = load ptr, ptr %stmt.1150, align 8
  %2 = getelementptr inbounds nuw %ASTNode, ptr %1, i32 0, i32 0
  %3 = load i32, ptr %2, align 4
  %4 = icmp eq i32 %3, 2
  br i1 %4, label %label_2929, label %label_2931

label_2931:                                       ; preds = %entry
  %5 = load ptr, ptr %stmt.1150, align 8
  %6 = getelementptr inbounds nuw %ASTNode, ptr %5, i32 0, i32 0
  %7 = load i32, ptr %6, align 4
  %8 = icmp eq i32 %7, 3
  br i1 %8, label %label_2932, label %label_2934

label_2929:                                       ; preds = %entry
  ret i1 true

label_2934:                                       ; preds = %label_2931
  %9 = load ptr, ptr %stmt.1150, align 8
  %10 = getelementptr inbounds nuw %ASTNode, ptr %9, i32 0, i32 0
  %11 = load i32, ptr %10, align 4
  %12 = icmp eq i32 %11, 4
  br i1 %12, label %label_2935, label %label_2937

label_2932:                                       ; preds = %label_2931
  ret i1 true

label_2937:                                       ; preds = %label_2934
  %13 = load ptr, ptr %stmt.1150, align 8
  %14 = getelementptr inbounds nuw %ASTNode, ptr %13, i32 0, i32 0
  %15 = load i32, ptr %14, align 4
  %16 = icmp eq i32 %15, 5
  br i1 %16, label %label_2938, label %label_2940

label_2935:                                       ; preds = %label_2934
  ret i1 true

label_2940:                                       ; preds = %label_2937
  %17 = load ptr, ptr %stmt.1150, align 8
  %18 = getelementptr inbounds nuw %ASTNode, ptr %17, i32 0, i32 0
  %19 = load i32, ptr %18, align 4
  %20 = icmp eq i32 %19, 6
  br i1 %20, label %label_2941, label %label_2943

label_2938:                                       ; preds = %label_2937
  ret i1 true

label_2943:                                       ; preds = %label_2940
  ret i1 false

label_2941:                                       ; preds = %label_2940
  ret i1 true
}

define i1 @same_top_level_name__Struct_ASTNode_Struct_ASTNode(ptr %0, ptr %1) {
entry:
  %a.1151 = alloca ptr, align 8
  store ptr %0, ptr %a.1151, align 8
  %b.1152 = alloca ptr, align 8
  store ptr %1, ptr %b.1152, align 8
  %2 = load ptr, ptr %a.1151, align 8
  %3 = getelementptr inbounds nuw %ASTNode, ptr %2, i32 0, i32 0
  %4 = load i32, ptr %3, align 4
  %5 = load ptr, ptr %b.1152, align 8
  %6 = getelementptr inbounds nuw %ASTNode, ptr %5, i32 0, i32 0
  %7 = load i32, ptr %6, align 4
  %8 = icmp ne i32 %4, %7
  br i1 %8, label %label_2944, label %label_2946

label_2946:                                       ; preds = %entry
  %9 = load ptr, ptr %a.1151, align 8
  %10 = getelementptr inbounds nuw %ASTNode, ptr %9, i32 0, i32 1
  %11 = load ptr, ptr %10, align 8
  %12 = load ptr, ptr %b.1152, align 8
  %13 = getelementptr inbounds nuw %ASTNode, ptr %12, i32 0, i32 1
  %14 = load ptr, ptr %13, align 8
  %15 = call i32 @str_equals(ptr %11, ptr %14)
  %16 = icmp eq i32 %15, 0
  br i1 %16, label %label_2947, label %label_2949

label_2944:                                       ; preds = %entry
  ret i1 false

label_2949:                                       ; preds = %label_2946
  %17 = load ptr, ptr %a.1151, align 8
  %18 = getelementptr inbounds nuw %ASTNode, ptr %17, i32 0, i32 0
  %19 = load i32, ptr %18, align 4
  %20 = icmp eq i32 %19, 4
  br i1 %20, label %label_2950, label %label_2952

label_2947:                                       ; preds = %label_2946
  ret i1 false

label_2952:                                       ; preds = %label_2949
  ret i1 true

label_2950:                                       ; preds = %label_2949
  ret i1 false
}

define i1 @has_named_top_level__Struct_ASTNode_Struct_ASTNode(ptr %0, ptr %1) {
entry:
  %module.1153 = alloca ptr, align 8
  store ptr %0, ptr %module.1153, align 8
  %stmt.1154 = alloca ptr, align 8
  store ptr %1, ptr %stmt.1154, align 8
  %2 = load ptr, ptr %stmt.1154, align 8
  %3 = call i1 @is_named_top_level__Struct_ASTNode(ptr %2)
  %4 = icmp eq i1 %3, false
  %scan_ptr.1155 = alloca ptr, align 8
  %scan.1156 = alloca ptr, align 8
  br i1 %4, label %label_2953, label %label_2955

label_2955:                                       ; preds = %entry
  %5 = load ptr, ptr %module.1153, align 8
  %6 = getelementptr inbounds nuw %ASTNode, ptr %5, i32 0, i32 5
  %7 = load ptr, ptr %6, align 8
  store ptr %7, ptr %scan_ptr.1155, align 8
  br label %label_2956

label_2953:                                       ; preds = %entry
  ret i1 false

label_2956:                                       ; preds = %label_2961, %label_2955
  %8 = load ptr, ptr %scan_ptr.1155, align 8
  %9 = call i32 @str_equals(ptr %8, ptr @.str.s1026)
  %10 = icmp eq i32 %9, 0
  br i1 %10, label %label_2957, label %label_2958

label_2958:                                       ; preds = %label_2956
  ret i1 false

label_2957:                                       ; preds = %label_2956
  %11 = load ptr, ptr %scan_ptr.1155, align 8
  %12 = call ptr @ptr_to_node(ptr %11)
  store ptr %12, ptr %scan.1156, align 8
  %13 = load ptr, ptr %scan.1156, align 8
  %14 = load ptr, ptr %stmt.1154, align 8
  %15 = call i1 @same_top_level_name__Struct_ASTNode_Struct_ASTNode(ptr %13, ptr %14)
  br i1 %15, label %label_2959, label %label_2961

label_2961:                                       ; preds = %label_2957
  %16 = load ptr, ptr %scan.1156, align 8
  %17 = getelementptr inbounds nuw %ASTNode, ptr %16, i32 0, i32 8
  %18 = load ptr, ptr %17, align 8
  store ptr %18, ptr %scan_ptr.1155, align 8
  br label %label_2956

label_2959:                                       ; preds = %label_2957
  ret i1 true
}

define ptr @parse_source__String_Int(ptr %0, i32 %1) {
entry:
  %content.1157 = alloca ptr, align 8
  store ptr %0, ptr %content.1157, align 8
  %file.1158 = alloca i32, align 4
  store i32 %1, ptr %file.1158, align 4
  %2 = load ptr, ptr %content.1157, align 8
  %3 = load i32, ptr %file.1158, align 4
  %4 = call ptr @create_lexer__String_Int(ptr %2, i32 %3)
  %lex.1159 = alloca ptr, align 8
  store ptr %4, ptr %lex.1159, align 8
  %5 = load ptr, ptr %lex.1159, align 8
  %6 = call ptr @lex_all_tokens__Struct_Lexer(ptr %5)
  %head_token.1160 = alloca ptr, align 8
  store ptr %6, ptr %head_token.1160, align 8
  %7 = load ptr, ptr %head_token.1160, align 8
  %8 = call ptr @parser_create__Struct_Token(ptr %7)
  %p.1161 = alloca ptr, align 8
  store ptr %8, ptr %p.1161, align 8
  %9 = load ptr, ptr %p.1161, align 8
  %10 = call ptr @parse_module__Struct_Parser(ptr %9)
  ret ptr %10
}

define void @append_statement__Struct_ASTNode_Struct_ASTNode(ptr %0, ptr %1) {
entry:
  %module.1162 = alloca ptr, align 8
  store ptr %0, ptr %module.1162, align 8
  %stmt.1163 = alloca ptr, align 8
  store ptr %1, ptr %stmt.1163, align 8
  %2 = load ptr, ptr %module.1162, align 8
  %3 = load ptr, ptr %stmt.1163, align 8
  %4 = call i1 @has_named_top_level__Struct_ASTNode_Struct_ASTNode(ptr %2, ptr %3)
  %tail_ptr.1164 = alloca ptr, align 8
  %searching.1165 = alloca i1, align 1
  %tail.1166 = alloca ptr, align 8
  br i1 %4, label %label_2962, label %label_2964

label_2964:                                       ; preds = %entry
  %5 = load ptr, ptr %module.1162, align 8
  %6 = getelementptr inbounds nuw %ASTNode, ptr %5, i32 0, i32 5
  %7 = load ptr, ptr %6, align 8
  %8 = call i32 @str_equals(ptr %7, ptr @.str.s1027)
  %9 = icmp eq i32 %8, 1
  br i1 %9, label %label_2965, label %label_2967

label_2962:                                       ; preds = %entry
  ret void

label_2967:                                       ; preds = %label_2964
  %10 = load ptr, ptr %module.1162, align 8
  %11 = getelementptr inbounds nuw %ASTNode, ptr %10, i32 0, i32 5
  %12 = load ptr, ptr %11, align 8
  store ptr %12, ptr %tail_ptr.1164, align 8
  store i1 true, ptr %searching.1165, align 1
  br label %label_2968

label_2965:                                       ; preds = %label_2964
  %13 = load ptr, ptr %module.1162, align 8
  %14 = load ptr, ptr %stmt.1163, align 8
  %15 = call ptr @node_to_ptr(ptr %14)
  %16 = getelementptr inbounds nuw %ASTNode, ptr %13, i32 0, i32 5
  store ptr %15, ptr %16, align 8
  ret void

label_2968:                                       ; preds = %label_2973, %label_2967
  %17 = load i1, ptr %searching.1165, align 1
  br i1 %17, label %label_2969, label %label_2970

label_2970:                                       ; preds = %label_2968
  ret void

label_2969:                                       ; preds = %label_2968
  %18 = load ptr, ptr %tail_ptr.1164, align 8
  %19 = call ptr @ptr_to_node(ptr %18)
  store ptr %19, ptr %tail.1166, align 8
  %20 = load ptr, ptr %tail.1166, align 8
  %21 = getelementptr inbounds nuw %ASTNode, ptr %20, i32 0, i32 8
  %22 = load ptr, ptr %21, align 8
  %23 = call i32 @str_equals(ptr %22, ptr @.str.s1028)
  %24 = icmp eq i32 %23, 1
  br i1 %24, label %label_2971, label %label_2972

label_2972:                                       ; preds = %label_2969
  %25 = load ptr, ptr %tail.1166, align 8
  %26 = getelementptr inbounds nuw %ASTNode, ptr %25, i32 0, i32 8
  %27 = load ptr, ptr %26, align 8
  store ptr %27, ptr %tail_ptr.1164, align 8
  br label %label_2973

label_2971:                                       ; preds = %label_2969
  %28 = load ptr, ptr %tail.1166, align 8
  %29 = load ptr, ptr %stmt.1163, align 8
  %30 = call ptr @node_to_ptr(ptr %29)
  %31 = getelementptr inbounds nuw %ASTNode, ptr %28, i32 0, i32 8
  store ptr %30, ptr %31, align 8
  store i1 false, ptr %searching.1165, align 1
  br label %label_2973

label_2973:                                       ; preds = %label_2972, %label_2971
  br label %label_2968
}

define ptr @join_import_path__String_String(ptr %0, ptr %1) {
entry:
  %base_dir.1167 = alloca ptr, align 8
  store ptr %0, ptr %base_dir.1167, align 8
  %module_name.1168 = alloca ptr, align 8
  store ptr %1, ptr %module_name.1168, align 8
  %2 = load ptr, ptr %module_name.1168, align 8
  %3 = call ptr @str_concat(ptr %2, ptr @.str.s1029)
  %module_file.1169 = alloca ptr, align 8
  store ptr %3, ptr %module_file.1169, align 8
  %4 = load ptr, ptr %base_dir.1167, align 8
  %5 = call i32 @str_equals(ptr %4, ptr @.str.s1030)
  %6 = icmp eq i32 %5, 1
  br i1 %6, label %label_2974, label %label_2976

label_2976:                                       ; preds = %entry
  %7 = load ptr, ptr %base_dir.1167, align 8
  %8 = load ptr, ptr %module_file.1169, align 8
  %9 = call ptr @join_path(ptr %7, ptr %8)
  ret ptr %9

label_2974:                                       ; preds = %entry
  %10 = load ptr, ptr %module_file.1169, align 8
  ret ptr %10
}

define ptr @import_memo_key__String(ptr %0) {
entry:
  %import_path.1170 = alloca ptr, align 8
  store ptr %0, ptr %import_path.1170, align 8
  %1 = load ptr, ptr %import_path.1170, align 8
  %2 = call ptr @str_concat(ptr @.str.s1031, ptr %1)
  %3 = call ptr @str_concat(ptr %2, ptr @.str.s1032)
  ret ptr %3
}

define ptr @merge_module_imports__Struct_ASTNode_Struct_ASTNode_String_String(ptr %0, ptr %1, ptr %2, ptr %3) {
entry:
  %merged.1171 = alloca ptr, align 8
  store ptr %0, ptr %merged.1171, align 8
  %module.1172 = alloca ptr, align 8
  store ptr %1, ptr %module.1172, align 8
  %base_dir.1173 = alloca ptr, align 8
  store ptr %2, ptr %base_dir.1173, align 8
  %visited.1174 = alloca ptr, align 8
  store ptr %3, ptr %visited.1174, align 8
  %4 = load ptr, ptr %visited.1174, align 8
  %seen.1175 = alloca ptr, align 8
  store ptr %4, ptr %seen.1175, align 8
  %5 = load ptr, ptr %module.1172, align 8
  %6 = getelementptr inbounds nuw %ASTNode, ptr %5, i32 0, i32 5
  %7 = load ptr, ptr %6, align 8
  %stmt_ptr.1176 = alloca ptr, align 8
  store ptr %7, ptr %stmt_ptr.1176, align 8
  %stmt.1177 = alloca ptr, align 8
  %next_stmt.1178 = alloca ptr, align 8
  %import_path.1179 = alloca ptr, align 8
  %key.1180 = alloca ptr, align 8
  %import_content.1181 = alloca ptr, align 8
  %import_file.1182 = alloca i32, align 4
  %imported_module.1183 = alloca ptr, align 8
  br label %label_2977

label_2977:                                       ; preds = %label_2982, %entry
  %8 = load ptr, ptr %stmt_ptr.1176, align 8
  %9 = call i32 @str_equals(ptr %8, ptr @.str.s1033)
  %10 = icmp eq i32 %9, 0
  br i1 %10, label %label_2978, label %label_2979

label_2979:                                       ; preds = %label_2977
  %11 = load ptr, ptr %seen.1175, align 8
  ret ptr %11

label_2978:                                       ; preds = %label_2977
  %12 = load ptr, ptr %stmt_ptr.1176, align 8
  %13 = call ptr @ptr_to_node(ptr %12)
  store ptr %13, ptr %stmt.1177, align 8
  %14 = load ptr, ptr %stmt.1177, align 8
  %15 = getelementptr inbounds nuw %ASTNode, ptr %14, i32 0, i32 8
  %16 = load ptr, ptr %15, align 8
  store ptr %16, ptr %next_stmt.1178, align 8
  %17 = load ptr, ptr %stmt.1177, align 8
  %18 = getelementptr inbounds nuw %ASTNode, ptr %17, i32 0, i32 8
  store ptr @.str.s1034, ptr %18, align 8
  %19 = load ptr, ptr %stmt.1177, align 8
  %20 = getelementptr inbounds nuw %ASTNode, ptr %19, i32 0, i32 0
  %21 = load i32, ptr %20, align 4
  %22 = icmp eq i32 %21, 1
  br i1 %22, label %label_2980, label %label_2981

label_2981:                                       ; preds = %label_2978
  %23 = load ptr, ptr %merged.1171, align 8
  %24 = load ptr, ptr %stmt.1177, align 8
  call void @append_statement__Struct_ASTNode_Struct_ASTNode(ptr %23, ptr %24)
  br label %label_2982

label_2980:                                       ; preds = %label_2978
  %25 = load ptr, ptr %base_dir.1173, align 8
  %26 = load ptr, ptr %stmt.1177, align 8
  %27 = getelementptr inbounds nuw %ASTNode, ptr %26, i32 0, i32 1
  %28 = load ptr, ptr %27, align 8
  %29 = call ptr @join_import_path__String_String(ptr %25, ptr %28)
  store ptr %29, ptr %import_path.1179, align 8
  %30 = load ptr, ptr %import_path.1179, align 8
  %31 = call ptr @import_memo_key__String(ptr %30)
  store ptr %31, ptr %key.1180, align 8
  %32 = load ptr, ptr %seen.1175, align 8
  %33 = load ptr, ptr %key.1180, align 8
  %34 = call i32 @str_contains(ptr %32, ptr %33)
  %35 = icmp eq i32 %34, 0
  br i1 %35, label %label_2983, label %label_2985

label_2985:                                       ; preds = %label_2988, %label_2980
  br label %label_2982

label_2983:                                       ; preds = %label_2980
  %36 = load ptr, ptr %seen.1175, align 8
  %37 = load ptr, ptr %key.1180, align 8
  %38 = call ptr @str_concat(ptr %36, ptr %37)
  store ptr %38, ptr %seen.1175, align 8
  %39 = load ptr, ptr %import_path.1179, align 8
  %40 = call ptr @read_file(ptr %39)
  store ptr %40, ptr %import_content.1181, align 8
  %41 = load ptr, ptr %import_content.1181, align 8
  %42 = call i32 @str_equals(ptr %41, ptr @.str.s1035)
  %43 = icmp eq i32 %42, 1
  br i1 %43, label %label_2986, label %label_2988

label_2988:                                       ; preds = %label_2986, %label_2983
  %44 = load ptr, ptr %import_path.1179, align 8
  %45 = load ptr, ptr %import_content.1181, align 8
  %46 = call i32 @diag_add_file(ptr %44, ptr %45)
  store i32 %46, ptr %import_file.1182, align 4
  %47 = load ptr, ptr %import_content.1181, align 8
  %48 = load i32, ptr %import_file.1182, align 4
  %49 = call ptr @parse_source__String_Int(ptr %47, i32 %48)
  store ptr %49, ptr %imported_module.1183, align 8
  %50 = load ptr, ptr %merged.1171, align 8
  %51 = load ptr, ptr %imported_module.1183, align 8
  %52 = load ptr, ptr %base_dir.1173, align 8
  %53 = load ptr, ptr %seen.1175, align 8
  %54 = call ptr @merge_module_imports__Struct_ASTNode_Struct_ASTNode_String_String(ptr %50, ptr %51, ptr %52, ptr %53)
  store ptr %54, ptr %seen.1175, align 8
  br label %label_2985

label_2986:                                       ; preds = %label_2983
  %55 = load ptr, ptr %stmt.1177, align 8
  %56 = getelementptr inbounds nuw %ASTNode, ptr %55, i32 0, i32 13
  %57 = load i32, ptr %56, align 4
  %58 = load ptr, ptr %stmt.1177, align 8
  %59 = getelementptr inbounds nuw %ASTNode, ptr %58, i32 0, i32 10
  %60 = load i32, ptr %59, align 4
  %61 = load ptr, ptr %stmt.1177, align 8
  %62 = getelementptr inbounds nuw %ASTNode, ptr %61, i32 0, i32 11
  %63 = load i32, ptr %62, align 4
  %64 = load ptr, ptr %stmt.1177, align 8
  %65 = getelementptr inbounds nuw %ASTNode, ptr %64, i32 0, i32 12
  %66 = load i32, ptr %65, align 4
  %67 = load ptr, ptr %stmt.1177, align 8
  %68 = getelementptr inbounds nuw %ASTNode, ptr %67, i32 0, i32 1
  %69 = load ptr, ptr %68, align 8
  %70 = call ptr @diag_quote__String(ptr %69)
  %71 = call ptr @str_concat(ptr @.str.s1036, ptr %70)
  %72 = load ptr, ptr %import_path.1179, align 8
  %73 = call ptr @str_concat(ptr @.str.s1037, ptr %72)
  %74 = call ptr @str_concat(ptr %71, ptr %73)
  call void @diag_error_at(i32 %57, i32 %60, i32 %63, i32 %66, ptr %74)
  call void @diag_finish()
  call void @exit(i32 1)
  br label %label_2988

label_2982:                                       ; preds = %label_2981, %label_2985
  %75 = load ptr, ptr %next_stmt.1178, align 8
  store ptr %75, ptr %stmt_ptr.1176, align 8
  br label %label_2977
}

define ptr @resolve_imports__Struct_ASTNode_String(ptr %0, ptr %1) {
entry:
  %module.1184 = alloca ptr, align 8
  store ptr %0, ptr %module.1184, align 8
  %base_dir.1185 = alloca ptr, align 8
  store ptr %1, ptr %base_dir.1185, align 8
  %2 = call ptr @create_node__Enum_NodeKind(i32 0)
  %merged.1186 = alloca ptr, align 8
  store ptr %2, ptr %merged.1186, align 8
  %3 = load ptr, ptr %merged.1186, align 8
  %4 = load ptr, ptr %module.1184, align 8
  %5 = load ptr, ptr %base_dir.1185, align 8
  %6 = call ptr @merge_module_imports__Struct_ASTNode_Struct_ASTNode_String_String(ptr %3, ptr %4, ptr %5, ptr @.str.s1038)
  %7 = load ptr, ptr %merged.1186, align 8
  ret ptr %7
}

define void @print_usage__Void() {
entry:
  call void @println(ptr @.str.s1039)
  call void @println(ptr @.str.s1040)
  call void @println(ptr @.str.s1041)
  call void @println(ptr @.str.s1042)
  call void @println(ptr @.str.s1043)
  call void @println(ptr @.str.s1044)
  call void @println(ptr @.str.s1045)
  call void @println(ptr @.str.s1046)
  call void @println(ptr @.str.s1047)
  ret void
}

define void @check_runtime_freshness__Void() {
entry:
  %0 = call ptr @compiler_installed_runtime_hash()
  %installed.1187 = alloca ptr, align 8
  store ptr %0, ptr %installed.1187, align 8
  %1 = load ptr, ptr %installed.1187, align 8
  %2 = call i32 @str_equals(ptr %1, ptr @.str.s1048)
  %3 = icmp eq i32 %2, 1
  %current.1188 = alloca ptr, align 8
  br i1 %3, label %label_2989, label %label_2991

label_2991:                                       ; preds = %entry
  %4 = call ptr @compiler_runtime_source_hash()
  store ptr %4, ptr %current.1188, align 8
  %5 = load ptr, ptr %current.1188, align 8
  %6 = call i32 @str_equals(ptr %5, ptr @.str.s1049)
  %7 = icmp eq i32 %6, 1
  br i1 %7, label %label_2992, label %label_2994

label_2989:                                       ; preds = %entry
  ret void

label_2994:                                       ; preds = %label_2991
  %8 = load ptr, ptr %installed.1187, align 8
  %9 = load ptr, ptr %current.1188, align 8
  %10 = call i32 @str_equals(ptr %8, ptr %9)
  %11 = icmp eq i32 %10, 1
  br i1 %11, label %label_2995, label %label_2997

label_2992:                                       ; preds = %label_2991
  ret void

label_2997:                                       ; preds = %label_2994
  call void @diag_error(ptr @.str.s1050)
  call void @print(ptr @.str.s1051)
  %12 = load ptr, ptr %installed.1187, align 8
  call void @println(ptr %12)
  call void @print(ptr @.str.s1052)
  %13 = load ptr, ptr %current.1188, align 8
  call void @println(ptr %13)
  call void @println(ptr @.str.s1053)
  call void @println(ptr @.str.s1054)
  call void @exit(i32 1)
  ret void

label_2995:                                       ; preds = %label_2994
  ret void
}

define i32 @compile_source__String_String_Bool_Bool(ptr %0, ptr %1, i1 %2, i1 %3) {
entry:
  %path.1189 = alloca ptr, align 8
  store ptr %0, ptr %path.1189, align 8
  %output_file.1190 = alloca ptr, align 8
  store ptr %1, ptr %output_file.1190, align 8
  %run_after_build.1191 = alloca i1, align 1
  store i1 %2, ptr %run_after_build.1191, align 1
  %bootstrap_mode.1192 = alloca i1, align 1
  store i1 %3, ptr %bootstrap_mode.1192, align 1
  %out_file.1193 = alloca ptr, align 8
  store ptr @.str.s1055, ptr %out_file.1193, align 8
  %emit_ir_only.1194 = alloca i1, align 1
  store i1 false, ptr %emit_ir_only.1194, align 1
  %4 = load i1, ptr %bootstrap_mode.1192, align 1
  %5 = icmp eq i1 %4, false
  %content.1195 = alloca ptr, align 8
  %root_file.1196 = alloca i32, align 4
  %lex.1197 = alloca ptr, align 8
  %head_token.1198 = alloca ptr, align 8
  %p.1199 = alloca ptr, align 8
  %ast_root.1200 = alloca ptr, align 8
  %base_dir.1201 = alloca ptr, align 8
  %merged_ast.1202 = alloca ptr, align 8
  %build_failed.1203 = alloca i32, align 4
  br i1 %5, label %label_2998, label %label_3000

label_3000:                                       ; preds = %label_2998, %entry
  %6 = load ptr, ptr %output_file.1190, align 8
  %7 = call i32 @str_ends_with(ptr %6, ptr @.str.s1056)
  %8 = icmp eq i32 %7, 1
  br i1 %8, label %label_3001, label %label_3002

label_2998:                                       ; preds = %entry
  call void @check_runtime_freshness__Void()
  br label %label_3000

label_3002:                                       ; preds = %label_3000
  %9 = load ptr, ptr %path.1189, align 8
  %10 = call ptr @compiler_temp_ir_path(ptr %9)
  store ptr %10, ptr %out_file.1193, align 8
  br label %label_3003

label_3001:                                       ; preds = %label_3000
  %11 = load ptr, ptr %output_file.1190, align 8
  store ptr %11, ptr %out_file.1193, align 8
  store i1 true, ptr %emit_ir_only.1194, align 1
  br label %label_3003

label_3003:                                       ; preds = %label_3002, %label_3001
  %12 = load ptr, ptr %path.1189, align 8
  %13 = call ptr @read_file(ptr %12)
  store ptr %13, ptr %content.1195, align 8
  %14 = load ptr, ptr %content.1195, align 8
  %15 = call i32 @str_equals(ptr %14, ptr @.str.s1057)
  %16 = icmp eq i32 %15, 1
  br i1 %16, label %label_3004, label %label_3006

label_3006:                                       ; preds = %label_3003
  %17 = load ptr, ptr %path.1189, align 8
  %18 = load ptr, ptr %content.1195, align 8
  %19 = call i32 @diag_add_file(ptr %17, ptr %18)
  store i32 %19, ptr %root_file.1196, align 4
  %20 = load ptr, ptr %content.1195, align 8
  %21 = load i32, ptr %root_file.1196, align 4
  %22 = call ptr @create_lexer__String_Int(ptr %20, i32 %21)
  store ptr %22, ptr %lex.1197, align 8
  %23 = load ptr, ptr %lex.1197, align 8
  %24 = call ptr @lex_all_tokens__Struct_Lexer(ptr %23)
  store ptr %24, ptr %head_token.1198, align 8
  %25 = load ptr, ptr %head_token.1198, align 8
  %26 = call ptr @parser_create__Struct_Token(ptr %25)
  store ptr %26, ptr %p.1199, align 8
  %27 = load ptr, ptr %p.1199, align 8
  %28 = call ptr @parse_module__Struct_Parser(ptr %27)
  store ptr %28, ptr %ast_root.1200, align 8
  %29 = load ptr, ptr %path.1189, align 8
  %30 = call ptr @get_directory(ptr %29)
  store ptr %30, ptr %base_dir.1201, align 8
  %31 = load ptr, ptr %ast_root.1200, align 8
  %32 = load ptr, ptr %base_dir.1201, align 8
  %33 = call ptr @resolve_imports__Struct_ASTNode_String(ptr %31, ptr %32)
  store ptr %33, ptr %merged_ast.1202, align 8
  %34 = call i32 @diag_error_count()
  %35 = icmp sgt i32 %34, 0
  br i1 %35, label %label_3010, label %label_3012

label_3004:                                       ; preds = %label_3003
  %36 = load ptr, ptr %path.1189, align 8
  %37 = call ptr @str_concat(ptr @.str.s1058, ptr %36)
  call void @diag_error(ptr %37)
  %38 = load i1, ptr %bootstrap_mode.1192, align 1
  br i1 %38, label %label_3007, label %label_3009

label_3009:                                       ; preds = %label_3007, %label_3004
  ret i32 1

label_3007:                                       ; preds = %label_3004
  call void @println(ptr @.str.s1059)
  call void @println(ptr @.str.s1060)
  call void @println(ptr @.str.s1061)
  br label %label_3009

label_3012:                                       ; preds = %label_3006
  %39 = load ptr, ptr %merged_ast.1202, align 8
  call void @analyze_module__Struct_ASTNode(ptr %39)
  %40 = call i32 @diag_error_count()
  %41 = icmp sgt i32 %40, 0
  br i1 %41, label %label_3013, label %label_3015

label_3010:                                       ; preds = %label_3006
  call void @diag_finish()
  ret i32 1

label_3015:                                       ; preds = %label_3012
  call void @ir_reset()
  %42 = load ptr, ptr %merged_ast.1202, align 8
  call void @generate_module__Struct_ASTNode(ptr %42)
  %43 = load ptr, ptr %out_file.1193, align 8
  %44 = call i32 @ir_write_file(ptr %43)
  %45 = icmp ne i32 %44, 0
  br i1 %45, label %label_3016, label %label_3018

label_3013:                                       ; preds = %label_3012
  call void @diag_finish()
  ret i32 1

label_3018:                                       ; preds = %label_3015
  %46 = load i1, ptr %emit_ir_only.1194, align 1
  br i1 %46, label %label_3019, label %label_3021

label_3016:                                       ; preds = %label_3015
  %47 = load ptr, ptr %out_file.1193, align 8
  %48 = call ptr @str_concat(ptr @.str.s1062, ptr %47)
  call void @diag_error(ptr %48)
  ret i32 1

label_3021:                                       ; preds = %label_3018
  store i32 0, ptr %build_failed.1203, align 4
  %49 = load i1, ptr %bootstrap_mode.1192, align 1
  br i1 %49, label %label_3022, label %label_3023

label_3019:                                       ; preds = %label_3018
  call void @print(ptr @.str.s1063)
  %50 = load ptr, ptr %out_file.1193, align 8
  call void @println(ptr %50)
  ret i32 0

label_3023:                                       ; preds = %label_3021
  %51 = load ptr, ptr %out_file.1193, align 8
  %52 = load ptr, ptr %output_file.1190, align 8
  %53 = call i32 @compiler_build_executable(ptr %51, ptr %52)
  store i32 %53, ptr %build_failed.1203, align 4
  br label %label_3024

label_3022:                                       ; preds = %label_3021
  %54 = load ptr, ptr %out_file.1193, align 8
  %55 = load ptr, ptr %output_file.1190, align 8
  %56 = call i32 @compiler_bootstrap_executable(ptr %54, ptr %55)
  store i32 %56, ptr %build_failed.1203, align 4
  br label %label_3024

label_3024:                                       ; preds = %label_3023, %label_3022
  %57 = load i32, ptr %build_failed.1203, align 4
  %58 = icmp ne i32 %57, 0
  br i1 %58, label %label_3025, label %label_3027

label_3027:                                       ; preds = %label_3024
  %59 = load ptr, ptr %out_file.1193, align 8
  %60 = call i32 @delete_file(ptr %59)
  call void @print(ptr @.str.s1065)
  %61 = load ptr, ptr %output_file.1190, align 8
  call void @println(ptr %61)
  %62 = load i1, ptr %run_after_build.1191, align 1
  br i1 %62, label %label_3028, label %label_3030

label_3025:                                       ; preds = %label_3024
  %63 = load ptr, ptr %out_file.1193, align 8
  %64 = call i32 @delete_file(ptr %63)
  call void @diag_error(ptr @.str.s1064)
  ret i32 1

label_3030:                                       ; preds = %label_3033, %label_3027
  ret i32 0

label_3028:                                       ; preds = %label_3027
  %65 = load ptr, ptr %output_file.1190, align 8
  %66 = call i32 @compiler_run_executable(ptr %65)
  %67 = icmp ne i32 %66, 0
  br i1 %67, label %label_3031, label %label_3033

label_3033:                                       ; preds = %label_3028
  br label %label_3030

label_3031:                                       ; preds = %label_3028
  %68 = load ptr, ptr %output_file.1190, align 8
  %69 = call ptr @str_concat(ptr %68, ptr @.str.s1066)
  call void @diag_error(ptr %69)
  ret i32 1
}

define i32 @main(i32 %0, ptr %1) {
entry:
  store i32 %0, ptr @prismio_argc, align 4
  store ptr %1, ptr @prismio_argv, align 8
  %path.1204 = alloca ptr, align 8
  store ptr @.str.s1067, ptr %path.1204, align 8
  %output_file.1205 = alloca ptr, align 8
  store ptr @.str.s1068, ptr %output_file.1205, align 8
  %command.1206 = alloca ptr, align 8
  store ptr @.str.s1069, ptr %command.1206, align 8
  %run_after_build.1207 = alloca i1, align 1
  store i1 false, ptr %run_after_build.1207, align 1
  %bootstrap_mode.1208 = alloca i1, align 1
  store i1 false, ptr %bootstrap_mode.1208, align 1
  %arg_index.1209 = alloca i32, align 4
  store i32 0, ptr %arg_index.1209, align 4
  %2 = call i32 @cli_arg_count()
  %3 = icmp sle i32 %2, 1
  %first.1210 = alloca ptr, align 8
  %sc.182 = alloca i1, align 1
  %sc.183 = alloca i1, align 1
  %source_hash.1211 = alloca ptr, align 8
  %candidate.1212 = alloca ptr, align 8
  %sc.184 = alloca i1, align 1
  %barg.1213 = alloca ptr, align 8
  %sc.185 = alloca i1, align 1
  %sc.186 = alloca i1, align 1
  %arg.1214 = alloca ptr, align 8
  %sc.187 = alloca i1, align 1
  %level.1215 = alloca i32, align 4
  %sc.188 = alloca i1, align 1
  %sc.189 = alloca i1, align 1
  %sc.190 = alloca i1, align 1
  br i1 %3, label %label_3034, label %label_3036

label_3036:                                       ; preds = %entry
  %4 = call ptr @cli_arg(i32 1)
  store ptr %4, ptr %first.1210, align 8
  %5 = load ptr, ptr %first.1210, align 8
  %6 = call i32 @str_equals(ptr %5, ptr @.str.s1070)
  %7 = icmp eq i32 %6, 1
  store i1 %7, ptr %sc.182, align 1
  br i1 %7, label %label_3038, label %label_3037

label_3034:                                       ; preds = %entry
  call void @print_usage__Void()
  ret i32 1

label_3037:                                       ; preds = %label_3036
  %8 = load ptr, ptr %first.1210, align 8
  %9 = call i32 @str_equals(ptr %8, ptr @.str.s1071)
  %10 = icmp eq i32 %9, 1
  store i1 %10, ptr %sc.182, align 1
  br label %label_3038

label_3038:                                       ; preds = %label_3037, %label_3036
  %11 = load i1, ptr %sc.182, align 1
  br i1 %11, label %label_3039, label %label_3041

label_3041:                                       ; preds = %label_3038
  %12 = load ptr, ptr %first.1210, align 8
  %13 = call i32 @str_equals(ptr %12, ptr @.str.s1072)
  %14 = icmp eq i32 %13, 1
  store i1 %14, ptr %sc.183, align 1
  br i1 %14, label %label_3043, label %label_3042

label_3039:                                       ; preds = %label_3038
  call void @print_usage__Void()
  ret i32 0

label_3042:                                       ; preds = %label_3041
  %15 = load ptr, ptr %first.1210, align 8
  %16 = call i32 @str_equals(ptr %15, ptr @.str.s1073)
  %17 = icmp eq i32 %16, 1
  store i1 %17, ptr %sc.183, align 1
  br label %label_3043

label_3043:                                       ; preds = %label_3042, %label_3041
  %18 = load i1, ptr %sc.183, align 1
  br i1 %18, label %label_3044, label %label_3046

label_3046:                                       ; preds = %label_3043
  %19 = load ptr, ptr %first.1210, align 8
  %20 = call i32 @str_equals(ptr %19, ptr @.str.s1076)
  %21 = icmp eq i32 %20, 1
  br i1 %21, label %label_3047, label %label_3049

label_3044:                                       ; preds = %label_3043
  call void @print(ptr @.str.s1074)
  %22 = load ptr, ptr @PRISMIO_VERSION, align 8
  call void @println(ptr %22)
  call void @print(ptr @.str.s1075)
  %23 = call ptr @ir_llvm_version()
  call void @println(ptr %23)
  ret i32 0

label_3049:                                       ; preds = %label_3046
  %24 = load ptr, ptr %first.1210, align 8
  %25 = call i32 @str_equals(ptr %24, ptr @.str.s1079)
  %26 = icmp eq i32 %25, 1
  br i1 %26, label %label_3053, label %label_3055

label_3047:                                       ; preds = %label_3046
  %27 = call ptr @compiler_runtime_source_hash()
  store ptr %27, ptr %source_hash.1211, align 8
  %28 = load ptr, ptr %source_hash.1211, align 8
  %29 = call i32 @str_equals(ptr %28, ptr @.str.s1077)
  %30 = icmp eq i32 %29, 1
  br i1 %30, label %label_3050, label %label_3052

label_3052:                                       ; preds = %label_3047
  %31 = load ptr, ptr %source_hash.1211, align 8
  call void @println(ptr %31)
  ret i32 0

label_3050:                                       ; preds = %label_3047
  call void @diag_error(ptr @.str.s1078)
  ret i32 1

label_3055:                                       ; preds = %label_3049
  %32 = load ptr, ptr %first.1210, align 8
  %33 = call i32 @str_equals(ptr %32, ptr @.str.s1087)
  %34 = icmp eq i32 %33, 1
  br i1 %34, label %label_3073, label %label_3074

label_3053:                                       ; preds = %label_3049
  store ptr @.str.s1080, ptr %command.1206, align 8
  store i1 true, ptr %bootstrap_mode.1208, align 1
  store i1 false, ptr %run_after_build.1207, align 1
  store ptr @.str.s1081, ptr %path.1204, align 8
  store i32 2, ptr %arg_index.1209, align 4
  %35 = call i32 @cli_arg_count()
  %36 = icmp sgt i32 %35, 2
  br i1 %36, label %label_3056, label %label_3058

label_3058:                                       ; preds = %label_3063, %label_3053
  %37 = load ptr, ptr %path.1204, align 8
  %38 = call ptr @compiler_default_exe_path(ptr %37)
  store ptr %38, ptr %output_file.1205, align 8
  br label %label_3064

label_3056:                                       ; preds = %label_3053
  %39 = call ptr @cli_arg(i32 2)
  store ptr %39, ptr %candidate.1212, align 8
  %40 = load ptr, ptr %candidate.1212, align 8
  %41 = call i32 @str_equals(ptr %40, ptr @.str.s1082)
  %42 = icmp eq i32 %41, 0
  store i1 %42, ptr %sc.184, align 1
  br i1 %42, label %label_3059, label %label_3060

label_3060:                                       ; preds = %label_3059, %label_3056
  %43 = load i1, ptr %sc.184, align 1
  br i1 %43, label %label_3061, label %label_3063

label_3059:                                       ; preds = %label_3056
  %44 = load ptr, ptr %candidate.1212, align 8
  %45 = call i32 @str_equals(ptr %44, ptr @.str.s1083)
  %46 = icmp eq i32 %45, 0
  store i1 %46, ptr %sc.184, align 1
  br label %label_3060

label_3063:                                       ; preds = %label_3061, %label_3060
  br label %label_3058

label_3061:                                       ; preds = %label_3060
  %47 = load ptr, ptr %candidate.1212, align 8
  store ptr %47, ptr %path.1204, align 8
  store i32 3, ptr %arg_index.1209, align 4
  br label %label_3063

label_3064:                                       ; preds = %label_3069, %label_3058
  %48 = load i32, ptr %arg_index.1209, align 4
  %49 = call i32 @cli_arg_count()
  %50 = icmp slt i32 %48, %49
  br i1 %50, label %label_3065, label %label_3066

label_3066:                                       ; preds = %label_3064
  %51 = load ptr, ptr %path.1204, align 8
  %52 = load ptr, ptr %output_file.1205, align 8
  %53 = load i1, ptr %run_after_build.1207, align 1
  %54 = load i1, ptr %bootstrap_mode.1208, align 1
  %55 = call i32 @compile_source__String_String_Bool_Bool(ptr %51, ptr %52, i1 %53, i1 %54)
  ret i32 %55

label_3065:                                       ; preds = %label_3064
  %56 = load i32, ptr %arg_index.1209, align 4
  %57 = call ptr @cli_arg(i32 %56)
  store ptr %57, ptr %barg.1213, align 8
  %58 = load ptr, ptr %barg.1213, align 8
  %59 = call i32 @str_equals(ptr %58, ptr @.str.s1084)
  %60 = icmp eq i32 %59, 1
  br i1 %60, label %label_3067, label %label_3068

label_3068:                                       ; preds = %label_3065
  %61 = load ptr, ptr %barg.1213, align 8
  %62 = call ptr @diag_quote__String(ptr %61)
  %63 = call ptr @str_concat(ptr @.str.s1086, ptr %62)
  call void @diag_error(ptr %63)
  call void @print_usage__Void()
  ret i32 1

label_3067:                                       ; preds = %label_3065
  %64 = load i32, ptr %arg_index.1209, align 4
  %65 = add i32 %64, 1
  %66 = call i32 @cli_arg_count()
  %67 = icmp sge i32 %65, %66
  br i1 %67, label %label_3070, label %label_3072

label_3072:                                       ; preds = %label_3067
  %68 = load i32, ptr %arg_index.1209, align 4
  %69 = add i32 %68, 1
  %70 = call ptr @cli_arg(i32 %69)
  store ptr %70, ptr %output_file.1205, align 8
  %71 = load i32, ptr %arg_index.1209, align 4
  %72 = add i32 %71, 2
  store i32 %72, ptr %arg_index.1209, align 4
  br label %label_3069

label_3070:                                       ; preds = %label_3067
  call void @diag_error(ptr @.str.s1085)
  ret i32 1

label_3069:                                       ; preds = %label_3072
  br label %label_3064

label_3074:                                       ; preds = %label_3055
  %73 = load ptr, ptr %first.1210, align 8
  %74 = call i32 @str_equals(ptr %73, ptr @.str.s1093)
  %75 = icmp eq i32 %74, 1
  br i1 %75, label %label_3084, label %label_3085

label_3073:                                       ; preds = %label_3055
  store ptr @.str.s1088, ptr %command.1206, align 8
  store i1 false, ptr %run_after_build.1207, align 1
  store i32 3, ptr %arg_index.1209, align 4
  %76 = call i32 @cli_arg_count()
  %77 = icmp sle i32 %76, 2
  br i1 %77, label %label_3076, label %label_3078

label_3078:                                       ; preds = %label_3073
  %78 = call ptr @cli_arg(i32 2)
  store ptr %78, ptr %path.1204, align 8
  %79 = load ptr, ptr %path.1204, align 8
  %80 = call i32 @str_equals(ptr %79, ptr @.str.s1090)
  %81 = icmp eq i32 %80, 1
  store i1 %81, ptr %sc.185, align 1
  br i1 %81, label %label_3080, label %label_3079

label_3076:                                       ; preds = %label_3073
  call void @diag_error(ptr @.str.s1089)
  call void @print_usage__Void()
  ret i32 1

label_3079:                                       ; preds = %label_3078
  %82 = load ptr, ptr %path.1204, align 8
  %83 = call i32 @str_equals(ptr %82, ptr @.str.s1091)
  %84 = icmp eq i32 %83, 1
  store i1 %84, ptr %sc.185, align 1
  br label %label_3080

label_3080:                                       ; preds = %label_3079, %label_3078
  %85 = load i1, ptr %sc.185, align 1
  br i1 %85, label %label_3081, label %label_3083

label_3083:                                       ; preds = %label_3080
  br label %label_3075

label_3081:                                       ; preds = %label_3080
  call void @diag_error(ptr @.str.s1092)
  ret i32 1

label_3075:                                       ; preds = %label_3086, %label_3083
  %86 = load ptr, ptr %path.1204, align 8
  %87 = call ptr @compiler_default_exe_path(ptr %86)
  store ptr %87, ptr %output_file.1205, align 8
  br label %label_3095

label_3085:                                       ; preds = %label_3074
  store ptr @.str.s1099, ptr %command.1206, align 8
  store i1 false, ptr %run_after_build.1207, align 1
  %88 = load ptr, ptr %first.1210, align 8
  store ptr %88, ptr %path.1204, align 8
  store i32 2, ptr %arg_index.1209, align 4
  br label %label_3086

label_3084:                                       ; preds = %label_3074
  store ptr @.str.s1094, ptr %command.1206, align 8
  store i1 true, ptr %run_after_build.1207, align 1
  store i32 3, ptr %arg_index.1209, align 4
  %89 = call i32 @cli_arg_count()
  %90 = icmp sle i32 %89, 2
  br i1 %90, label %label_3087, label %label_3089

label_3089:                                       ; preds = %label_3084
  %91 = call ptr @cli_arg(i32 2)
  store ptr %91, ptr %path.1204, align 8
  %92 = load ptr, ptr %path.1204, align 8
  %93 = call i32 @str_equals(ptr %92, ptr @.str.s1096)
  %94 = icmp eq i32 %93, 1
  store i1 %94, ptr %sc.186, align 1
  br i1 %94, label %label_3091, label %label_3090

label_3087:                                       ; preds = %label_3084
  call void @diag_error(ptr @.str.s1095)
  call void @print_usage__Void()
  ret i32 1

label_3090:                                       ; preds = %label_3089
  %95 = load ptr, ptr %path.1204, align 8
  %96 = call i32 @str_equals(ptr %95, ptr @.str.s1097)
  %97 = icmp eq i32 %96, 1
  store i1 %97, ptr %sc.186, align 1
  br label %label_3091

label_3091:                                       ; preds = %label_3090, %label_3089
  %98 = load i1, ptr %sc.186, align 1
  br i1 %98, label %label_3092, label %label_3094

label_3094:                                       ; preds = %label_3091
  br label %label_3086

label_3092:                                       ; preds = %label_3091
  call void @diag_error(ptr @.str.s1098)
  ret i32 1

label_3086:                                       ; preds = %label_3085, %label_3094
  br label %label_3075

label_3095:                                       ; preds = %label_3100, %label_3075
  %99 = load i32, ptr %arg_index.1209, align 4
  %100 = call i32 @cli_arg_count()
  %101 = icmp slt i32 %99, %100
  br i1 %101, label %label_3096, label %label_3097

label_3097:                                       ; preds = %label_3095
  %102 = load ptr, ptr %path.1204, align 8
  %103 = load ptr, ptr %output_file.1205, align 8
  %104 = load i1, ptr %run_after_build.1207, align 1
  %105 = load i1, ptr %bootstrap_mode.1208, align 1
  %106 = call i32 @compile_source__String_String_Bool_Bool(ptr %102, ptr %103, i1 %104, i1 %105)
  ret i32 %106

label_3096:                                       ; preds = %label_3095
  %107 = load i32, ptr %arg_index.1209, align 4
  %108 = call ptr @cli_arg(i32 %107)
  store ptr %108, ptr %arg.1214, align 8
  %109 = load ptr, ptr %arg.1214, align 8
  %110 = call i32 @str_equals(ptr %109, ptr @.str.s1100)
  %111 = icmp eq i32 %110, 1
  br i1 %111, label %label_3098, label %label_3099

label_3099:                                       ; preds = %label_3096
  %112 = load ptr, ptr %arg.1214, align 8
  %113 = call i32 @str_starts_with(ptr %112, ptr @.str.s1102)
  %114 = icmp eq i32 %113, 1
  store i1 %114, ptr %sc.187, align 1
  br i1 %114, label %label_3104, label %label_3105

label_3098:                                       ; preds = %label_3096
  %115 = load i32, ptr %arg_index.1209, align 4
  %116 = add i32 %115, 1
  %117 = call i32 @cli_arg_count()
  %118 = icmp sge i32 %116, %117
  br i1 %118, label %label_3101, label %label_3103

label_3103:                                       ; preds = %label_3098
  %119 = load i32, ptr %arg_index.1209, align 4
  %120 = add i32 %119, 1
  %121 = call ptr @cli_arg(i32 %120)
  store ptr %121, ptr %output_file.1205, align 8
  %122 = load i32, ptr %arg_index.1209, align 4
  %123 = add i32 %122, 2
  store i32 %123, ptr %arg_index.1209, align 4
  br label %label_3100

label_3101:                                       ; preds = %label_3098
  call void @diag_error(ptr @.str.s1101)
  ret i32 1

label_3100:                                       ; preds = %label_3108, %label_3103
  br label %label_3095

label_3105:                                       ; preds = %label_3104, %label_3099
  %124 = load i1, ptr %sc.187, align 1
  br i1 %124, label %label_3106, label %label_3107

label_3104:                                       ; preds = %label_3099
  %125 = load ptr, ptr %arg.1214, align 8
  %126 = call i32 @str_length(ptr %125)
  %127 = icmp eq i32 %126, 3
  store i1 %127, ptr %sc.187, align 1
  br label %label_3105

label_3107:                                       ; preds = %label_3105
  %128 = load ptr, ptr %arg.1214, align 8
  %129 = call i32 @str_equals(ptr %128, ptr @.str.s1104)
  %130 = icmp eq i32 %129, 1
  br i1 %130, label %label_3114, label %label_3115

label_3106:                                       ; preds = %label_3105
  %131 = load ptr, ptr %arg.1214, align 8
  %132 = call ptr @str_substring(ptr %131, i32 2, i32 1)
  %133 = call i32 @str_to_int(ptr %132)
  store i32 %133, ptr %level.1215, align 4
  %134 = load i32, ptr %level.1215, align 4
  %135 = icmp slt i32 %134, 0
  store i1 %135, ptr %sc.188, align 1
  br i1 %135, label %label_3110, label %label_3109

label_3109:                                       ; preds = %label_3106
  %136 = load i32, ptr %level.1215, align 4
  %137 = icmp sgt i32 %136, 3
  store i1 %137, ptr %sc.188, align 1
  br label %label_3110

label_3110:                                       ; preds = %label_3109, %label_3106
  %138 = load i1, ptr %sc.188, align 1
  br i1 %138, label %label_3111, label %label_3113

label_3113:                                       ; preds = %label_3110
  %139 = load i32, ptr %level.1215, align 4
  call void @ir_set_opt_level(i32 %139)
  %140 = load i32, ptr %arg_index.1209, align 4
  %141 = add i32 %140, 1
  store i32 %141, ptr %arg_index.1209, align 4
  br label %label_3108

label_3111:                                       ; preds = %label_3110
  %142 = load ptr, ptr %arg.1214, align 8
  %143 = call ptr @diag_quote__String(ptr %142)
  %144 = call ptr @str_concat(ptr @.str.s1103, ptr %143)
  call void @diag_error(ptr %144)
  ret i32 1

label_3108:                                       ; preds = %label_3116, %label_3113
  br label %label_3100

label_3115:                                       ; preds = %label_3107
  %145 = load ptr, ptr %arg.1214, align 8
  %146 = call i32 @str_equals(ptr %145, ptr @.str.s1107)
  %147 = icmp eq i32 %146, 1
  store i1 %147, ptr %sc.189, align 1
  br i1 %147, label %label_3124, label %label_3123

label_3114:                                       ; preds = %label_3107
  %148 = load i32, ptr %arg_index.1209, align 4
  %149 = add i32 %148, 1
  %150 = call i32 @cli_arg_count()
  %151 = icmp sge i32 %149, %150
  br i1 %151, label %label_3117, label %label_3119

label_3119:                                       ; preds = %label_3114
  %152 = load i32, ptr %arg_index.1209, align 4
  %153 = add i32 %152, 1
  %154 = call ptr @cli_arg(i32 %153)
  %155 = call i32 @str_equals(ptr %154, ptr @.str.s1106)
  %156 = icmp eq i32 %155, 1
  br i1 %156, label %label_3120, label %label_3122

label_3117:                                       ; preds = %label_3114
  call void @diag_error(ptr @.str.s1105)
  ret i32 1

label_3122:                                       ; preds = %label_3120, %label_3119
  %157 = load i32, ptr %arg_index.1209, align 4
  %158 = add i32 %157, 2
  store i32 %158, ptr %arg_index.1209, align 4
  br label %label_3116

label_3120:                                       ; preds = %label_3119
  call void @ir_set_target_wasm__Bool(i1 true)
  br label %label_3122

label_3116:                                       ; preds = %label_3132, %label_3122
  br label %label_3108

label_3123:                                       ; preds = %label_3115
  %159 = load ptr, ptr %arg.1214, align 8
  %160 = call i32 @str_equals(ptr %159, ptr @.str.s1108)
  %161 = icmp eq i32 %160, 1
  store i1 %161, ptr %sc.189, align 1
  br label %label_3124

label_3124:                                       ; preds = %label_3123, %label_3115
  %162 = load i1, ptr %sc.189, align 1
  br i1 %162, label %label_3125, label %label_3127

label_3127:                                       ; preds = %label_3124
  %163 = load ptr, ptr %command.1206, align 8
  %164 = call i32 @str_equals(ptr %163, ptr @.str.s1110)
  %165 = icmp eq i32 %164, 1
  store i1 %165, ptr %sc.190, align 1
  br i1 %165, label %label_3128, label %label_3129

label_3125:                                       ; preds = %label_3124
  call void @diag_error(ptr @.str.s1109)
  ret i32 1

label_3129:                                       ; preds = %label_3128, %label_3127
  %166 = load i1, ptr %sc.190, align 1
  br i1 %166, label %label_3130, label %label_3131

label_3128:                                       ; preds = %label_3127
  %167 = load i32, ptr %arg_index.1209, align 4
  %168 = icmp eq i32 %167, 2
  store i1 %168, ptr %sc.190, align 1
  br label %label_3129

label_3131:                                       ; preds = %label_3129
  %169 = load ptr, ptr %arg.1214, align 8
  %170 = call ptr @diag_quote__String(ptr %169)
  %171 = call ptr @str_concat(ptr @.str.s1111, ptr %170)
  call void @diag_error(ptr %171)
  call void @print_usage__Void()
  ret i32 1

label_3130:                                       ; preds = %label_3129
  %172 = load ptr, ptr %arg.1214, align 8
  store ptr %172, ptr %output_file.1205, align 8
  %173 = load i32, ptr %arg_index.1209, align 4
  %174 = add i32 %173, 1
  store i32 %174, ptr %arg_index.1209, align 4
  br label %label_3132

label_3132:                                       ; preds = %label_3130
  br label %label_3116
}
