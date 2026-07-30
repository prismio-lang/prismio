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

%Lexer = type { ptr, i32, i32, i32 }
%Token = type { i32, ptr, i32, ptr }
%ASTNode = type { i32, ptr, ptr, i32, i32, ptr, ptr, ptr, ptr, ptr }
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
@.str.s43 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s44 = private unnamed_addr constant [13 x i8] c"error: line \00"
@.str.s45 = private unnamed_addr constant [83 x i8] c": a NUL escape cannot appear in a string literal, because String is NUL-terminated\00"
@.str.s46 = private unnamed_addr constant [13 x i8] c"error: line \00"
@.str.s47 = private unnamed_addr constant [27 x i8] c": unknown escape sequence \00"
@.str.s48 = private unnamed_addr constant [4 x i8] c"EOF\00"
@.str.s49 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s50 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s51 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s52 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s53 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s54 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s55 = private unnamed_addr constant [13 x i8] c"error: line \00"
@.str.s56 = private unnamed_addr constant [30 x i8] c": unterminated string literal\00"
@.str.s57 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s58 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s59 = private unnamed_addr constant [3 x i8] c"==\00"
@.str.s60 = private unnamed_addr constant [3 x i8] c"!=\00"
@.str.s61 = private unnamed_addr constant [3 x i8] c"<=\00"
@.str.s62 = private unnamed_addr constant [3 x i8] c">=\00"
@.str.s63 = private unnamed_addr constant [3 x i8] c"->\00"
@.str.s64 = private unnamed_addr constant [3 x i8] c"=>\00"
@.str.s65 = private unnamed_addr constant [3 x i8] c"=>\00"
@.str.s66 = private unnamed_addr constant [3 x i8] c"!=\00"
@.str.s67 = private unnamed_addr constant [3 x i8] c"<=\00"
@.str.s68 = private unnamed_addr constant [3 x i8] c">=\00"
@.str.s69 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s70 = private unnamed_addr constant [3 x i8] c"..\00"
@.str.s71 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s72 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s73 = private unnamed_addr constant [2 x i8] c"?\00"
@.str.s74 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s75 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s76 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s77 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s78 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s79 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s80 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s81 = private unnamed_addr constant [1 x i8] zeroinitializer
@parser_allow_struct_lit = global i32 1
@.str.s82 = private unnamed_addr constant [10 x i8] c"Error in \00"
@.str.s83 = private unnamed_addr constant [23 x i8] c": Expected token type \00"
@.str.s84 = private unnamed_addr constant [10 x i8] c"Error in \00"
@.str.s85 = private unnamed_addr constant [19 x i8] c": Expected token '\00"
@.str.s86 = private unnamed_addr constant [2 x i8] c"'\00"
@.str.s87 = private unnamed_addr constant [7 x i8] c"import\00"
@.str.s88 = private unnamed_addr constant [17 x i8] c"import statement\00"
@.str.s89 = private unnamed_addr constant [21 x i8] c"Expected module name\00"
@.str.s90 = private unnamed_addr constant [7 x i8] c"import\00"
@.str.s91 = private unnamed_addr constant [4 x i8] c"let\00"
@.str.s92 = private unnamed_addr constant [7 x i8] c"extern\00"
@.str.s93 = private unnamed_addr constant [3 x i8] c"fn\00"
@.str.s94 = private unnamed_addr constant [7 x i8] c"struct\00"
@.str.s95 = private unnamed_addr constant [5 x i8] c"enum\00"
@.str.s96 = private unnamed_addr constant [20 x i8] c"Unknown declaration\00"
@.str.s97 = private unnamed_addr constant [2 x i8] c"[\00"
@.str.s98 = private unnamed_addr constant [2 x i8] c"]\00"
@.str.s99 = private unnamed_addr constant [11 x i8] c"array type\00"
@.str.s100 = private unnamed_addr constant [19 x i8] c"Expected type name\00"
@.str.s101 = private unnamed_addr constant [5 x i8] c"List\00"
@.str.s102 = private unnamed_addr constant [2 x i8] c"<\00"
@.str.s103 = private unnamed_addr constant [19 x i8] c"list type argument\00"
@.str.s104 = private unnamed_addr constant [3 x i8] c">>\00"
@.str.s105 = private unnamed_addr constant [2 x i8] c">\00"
@.str.s106 = private unnamed_addr constant [2 x i8] c">\00"
@.str.s107 = private unnamed_addr constant [4 x i8] c"let\00"
@.str.s108 = private unnamed_addr constant [21 x i8] c"variable declaration\00"
@.str.s109 = private unnamed_addr constant [4 x i8] c"mut\00"
@.str.s110 = private unnamed_addr constant [14 x i8] c"variable name\00"
@.str.s111 = private unnamed_addr constant [2 x i8] c":\00"
@.str.s112 = private unnamed_addr constant [2 x i8] c"=\00"
@.str.s113 = private unnamed_addr constant [7 x i8] c"extern\00"
@.str.s114 = private unnamed_addr constant [10 x i8] c"extern fn\00"
@.str.s115 = private unnamed_addr constant [3 x i8] c"fn\00"
@.str.s116 = private unnamed_addr constant [10 x i8] c"extern fn\00"
@.str.s117 = private unnamed_addr constant [14 x i8] c"function name\00"
@.str.s118 = private unnamed_addr constant [2 x i8] c"(\00"
@.str.s119 = private unnamed_addr constant [7 x i8] c"params\00"
@.str.s120 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s121 = private unnamed_addr constant [2 x i8] c")\00"
@.str.s122 = private unnamed_addr constant [15 x i8] c"parameter name\00"
@.str.s123 = private unnamed_addr constant [2 x i8] c":\00"
@.str.s124 = private unnamed_addr constant [15 x i8] c"parameter type\00"
@.str.s125 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s126 = private unnamed_addr constant [2 x i8] c",\00"
@.str.s127 = private unnamed_addr constant [2 x i8] c")\00"
@.str.s128 = private unnamed_addr constant [7 x i8] c"params\00"
@.str.s129 = private unnamed_addr constant [3 x i8] c"->\00"
@.str.s130 = private unnamed_addr constant [3 x i8] c"fn\00"
@.str.s131 = private unnamed_addr constant [9 x i8] c"function\00"
@.str.s132 = private unnamed_addr constant [14 x i8] c"function name\00"
@.str.s133 = private unnamed_addr constant [2 x i8] c"(\00"
@.str.s134 = private unnamed_addr constant [7 x i8] c"params\00"
@.str.s135 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s136 = private unnamed_addr constant [2 x i8] c")\00"
@.str.s137 = private unnamed_addr constant [5 x i8] c"sink\00"
@.str.s138 = private unnamed_addr constant [5 x i8] c"sink\00"
@.str.s139 = private unnamed_addr constant [6 x i8] c"inout\00"
@.str.s140 = private unnamed_addr constant [6 x i8] c"inout\00"
@.str.s141 = private unnamed_addr constant [15 x i8] c"parameter name\00"
@.str.s142 = private unnamed_addr constant [2 x i8] c":\00"
@.str.s143 = private unnamed_addr constant [15 x i8] c"parameter type\00"
@.str.s144 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s145 = private unnamed_addr constant [2 x i8] c",\00"
@.str.s146 = private unnamed_addr constant [2 x i8] c")\00"
@.str.s147 = private unnamed_addr constant [7 x i8] c"params\00"
@.str.s148 = private unnamed_addr constant [3 x i8] c"->\00"
@.str.s149 = private unnamed_addr constant [7 x i8] c"struct\00"
@.str.s150 = private unnamed_addr constant [7 x i8] c"struct\00"
@.str.s151 = private unnamed_addr constant [12 x i8] c"struct name\00"
@.str.s152 = private unnamed_addr constant [2 x i8] c"{\00"
@.str.s153 = private unnamed_addr constant [12 x i8] c"struct body\00"
@.str.s154 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s155 = private unnamed_addr constant [2 x i8] c"}\00"
@.str.s156 = private unnamed_addr constant [11 x i8] c"field name\00"
@.str.s157 = private unnamed_addr constant [2 x i8] c":\00"
@.str.s158 = private unnamed_addr constant [11 x i8] c"field type\00"
@.str.s159 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s160 = private unnamed_addr constant [2 x i8] c",\00"
@.str.s161 = private unnamed_addr constant [2 x i8] c"}\00"
@.str.s162 = private unnamed_addr constant [12 x i8] c"struct body\00"
@.str.s163 = private unnamed_addr constant [5 x i8] c"enum\00"
@.str.s164 = private unnamed_addr constant [5 x i8] c"enum\00"
@.str.s165 = private unnamed_addr constant [10 x i8] c"enum name\00"
@.str.s166 = private unnamed_addr constant [2 x i8] c"{\00"
@.str.s167 = private unnamed_addr constant [10 x i8] c"enum body\00"
@.str.s168 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s169 = private unnamed_addr constant [2 x i8] c"}\00"
@.str.s170 = private unnamed_addr constant [13 x i8] c"variant name\00"
@.str.s171 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s172 = private unnamed_addr constant [2 x i8] c",\00"
@.str.s173 = private unnamed_addr constant [2 x i8] c"}\00"
@.str.s174 = private unnamed_addr constant [10 x i8] c"enum body\00"
@.str.s175 = private unnamed_addr constant [2 x i8] c"{\00"
@.str.s176 = private unnamed_addr constant [6 x i8] c"block\00"
@.str.s177 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s178 = private unnamed_addr constant [2 x i8] c"}\00"
@.str.s179 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s180 = private unnamed_addr constant [2 x i8] c"}\00"
@.str.s181 = private unnamed_addr constant [6 x i8] c"block\00"
@.str.s182 = private unnamed_addr constant [3 x i8] c"if\00"
@.str.s183 = private unnamed_addr constant [13 x i8] c"if statement\00"
@.str.s184 = private unnamed_addr constant [2 x i8] c"(\00"
@.str.s185 = private unnamed_addr constant [13 x i8] c"if condition\00"
@.str.s186 = private unnamed_addr constant [2 x i8] c")\00"
@.str.s187 = private unnamed_addr constant [13 x i8] c"if condition\00"
@.str.s188 = private unnamed_addr constant [5 x i8] c"else\00"
@.str.s189 = private unnamed_addr constant [3 x i8] c"if\00"
@.str.s190 = private unnamed_addr constant [6 x i8] c"while\00"
@.str.s191 = private unnamed_addr constant [16 x i8] c"while statement\00"
@.str.s192 = private unnamed_addr constant [2 x i8] c"(\00"
@.str.s193 = private unnamed_addr constant [16 x i8] c"while condition\00"
@.str.s194 = private unnamed_addr constant [2 x i8] c")\00"
@.str.s195 = private unnamed_addr constant [16 x i8] c"while condition\00"
@.str.s196 = private unnamed_addr constant [5 x i8] c"loop\00"
@.str.s197 = private unnamed_addr constant [15 x i8] c"loop statement\00"
@.str.s198 = private unnamed_addr constant [4 x i8] c"for\00"
@.str.s199 = private unnamed_addr constant [14 x i8] c"for statement\00"
@.str.s200 = private unnamed_addr constant [18 x i8] c"for loop variable\00"
@.str.s201 = private unnamed_addr constant [3 x i8] c"in\00"
@.str.s202 = private unnamed_addr constant [11 x i8] c"for ... in\00"
@.str.s203 = private unnamed_addr constant [3 x i8] c"..\00"
@.str.s204 = private unnamed_addr constant [10 x i8] c"for range\00"
@.str.s205 = private unnamed_addr constant [2 x i8] c"_\00"
@.str.s206 = private unnamed_addr constant [2 x i8] c"_\00"
@.str.s207 = private unnamed_addr constant [3 x i8] c"=>\00"
@.str.s208 = private unnamed_addr constant [10 x i8] c"match arm\00"
@.str.s209 = private unnamed_addr constant [6 x i8] c"match\00"
@.str.s210 = private unnamed_addr constant [16 x i8] c"match statement\00"
@.str.s211 = private unnamed_addr constant [2 x i8] c"(\00"
@.str.s212 = private unnamed_addr constant [16 x i8] c"match scrutinee\00"
@.str.s213 = private unnamed_addr constant [2 x i8] c")\00"
@.str.s214 = private unnamed_addr constant [16 x i8] c"match scrutinee\00"
@.str.s215 = private unnamed_addr constant [2 x i8] c"{\00"
@.str.s216 = private unnamed_addr constant [11 x i8] c"match body\00"
@.str.s217 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s218 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s219 = private unnamed_addr constant [2 x i8] c"}\00"
@.str.s220 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s221 = private unnamed_addr constant [2 x i8] c",\00"
@.str.s222 = private unnamed_addr constant [2 x i8] c"}\00"
@.str.s223 = private unnamed_addr constant [11 x i8] c"match body\00"
@.str.s224 = private unnamed_addr constant [3 x i8] c"if\00"
@.str.s225 = private unnamed_addr constant [6 x i8] c"while\00"
@.str.s226 = private unnamed_addr constant [5 x i8] c"loop\00"
@.str.s227 = private unnamed_addr constant [6 x i8] c"match\00"
@.str.s228 = private unnamed_addr constant [4 x i8] c"for\00"
@.str.s229 = private unnamed_addr constant [6 x i8] c"break\00"
@.str.s230 = private unnamed_addr constant [9 x i8] c"continue\00"
@.str.s231 = private unnamed_addr constant [7 x i8] c"return\00"
@.str.s232 = private unnamed_addr constant [2 x i8] c"}\00"
@.str.s233 = private unnamed_addr constant [4 x i8] c"let\00"
@.str.s234 = private unnamed_addr constant [2 x i8] c"=\00"
@.str.s235 = private unnamed_addr constant [29 x i8] c"Error: compound assignment (\00"
@.str.s236 = private unnamed_addr constant [40 x i8] c") requires a plain variable on the left\00"
@.str.s237 = private unnamed_addr constant [43 x i8] c"  write the assignment out in full instead\00"
@.str.s238 = private unnamed_addr constant [3 x i8] c"or\00"
@.str.s239 = private unnamed_addr constant [4 x i8] c"and\00"
@.str.s240 = private unnamed_addr constant [3 x i8] c"==\00"
@.str.s241 = private unnamed_addr constant [3 x i8] c"!=\00"
@.str.s242 = private unnamed_addr constant [2 x i8] c"<\00"
@.str.s243 = private unnamed_addr constant [2 x i8] c">\00"
@.str.s244 = private unnamed_addr constant [3 x i8] c"<=\00"
@.str.s245 = private unnamed_addr constant [3 x i8] c">=\00"
@.str.s246 = private unnamed_addr constant [2 x i8] c"|\00"
@.str.s247 = private unnamed_addr constant [2 x i8] c"^\00"
@.str.s248 = private unnamed_addr constant [2 x i8] c"&\00"
@.str.s249 = private unnamed_addr constant [3 x i8] c"<<\00"
@.str.s250 = private unnamed_addr constant [3 x i8] c">>\00"
@.str.s251 = private unnamed_addr constant [2 x i8] c"+\00"
@.str.s252 = private unnamed_addr constant [2 x i8] c"-\00"
@.str.s253 = private unnamed_addr constant [2 x i8] c"*\00"
@.str.s254 = private unnamed_addr constant [2 x i8] c"/\00"
@.str.s255 = private unnamed_addr constant [2 x i8] c"%\00"
@.str.s256 = private unnamed_addr constant [2 x i8] c"-\00"
@.str.s257 = private unnamed_addr constant [2 x i8] c"!\00"
@.str.s258 = private unnamed_addr constant [2 x i8] c"~\00"
@.str.s259 = private unnamed_addr constant [2 x i8] c"-\00"
@.str.s260 = private unnamed_addr constant [2 x i8] c"-\00"
@.str.s261 = private unnamed_addr constant [2 x i8] c"-\00"
@.str.s262 = private unnamed_addr constant [3 x i8] c"as\00"
@.str.s263 = private unnamed_addr constant [4 x i8] c"and\00"
@.str.s264 = private unnamed_addr constant [3 x i8] c"or\00"
@.str.s265 = private unnamed_addr constant [2 x i8] c"{\00"
@.str.s266 = private unnamed_addr constant [2 x i8] c"{\00"
@.str.s267 = private unnamed_addr constant [15 x i8] c"struct literal\00"
@.str.s268 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s269 = private unnamed_addr constant [2 x i8] c"}\00"
@.str.s270 = private unnamed_addr constant [21 x i8] c"struct literal field\00"
@.str.s271 = private unnamed_addr constant [2 x i8] c":\00"
@.str.s272 = private unnamed_addr constant [15 x i8] c"struct literal\00"
@.str.s273 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s274 = private unnamed_addr constant [2 x i8] c",\00"
@.str.s275 = private unnamed_addr constant [2 x i8] c"}\00"
@.str.s276 = private unnamed_addr constant [15 x i8] c"struct literal\00"
@.str.s277 = private unnamed_addr constant [2 x i8] c"(\00"
@.str.s278 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s279 = private unnamed_addr constant [2 x i8] c")\00"
@.str.s280 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s281 = private unnamed_addr constant [2 x i8] c",\00"
@.str.s282 = private unnamed_addr constant [2 x i8] c")\00"
@.str.s283 = private unnamed_addr constant [14 x i8] c"function call\00"
@.str.s284 = private unnamed_addr constant [2 x i8] c"[\00"
@.str.s285 = private unnamed_addr constant [2 x i8] c"]\00"
@.str.s286 = private unnamed_addr constant [12 x i8] c"array index\00"
@.str.s287 = private unnamed_addr constant [2 x i8] c".\00"
@.str.s288 = private unnamed_addr constant [12 x i8] c"member name\00"
@.str.s289 = private unnamed_addr constant [2 x i8] c"(\00"
@.str.s290 = private unnamed_addr constant [2 x i8] c")\00"
@.str.s291 = private unnamed_addr constant [25 x i8] c"parenthesized expression\00"
@.str.s292 = private unnamed_addr constant [2 x i8] c"[\00"
@.str.s293 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s294 = private unnamed_addr constant [2 x i8] c"]\00"
@.str.s295 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s296 = private unnamed_addr constant [2 x i8] c",\00"
@.str.s297 = private unnamed_addr constant [2 x i8] c"]\00"
@.str.s298 = private unnamed_addr constant [14 x i8] c"array literal\00"
@.str.s299 = private unnamed_addr constant [33 x i8] c"Unexpected token in expression: \00"
@.str.s300 = private unnamed_addr constant [3 x i8] c" '\00"
@.str.s301 = private unnamed_addr constant [2 x i8] c"'\00"
@.str.s302 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s303 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s304 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s305 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s306 = private unnamed_addr constant [8 x i8] c"Invalid\00"
@.str.s307 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s308 = private unnamed_addr constant [5 x i8] c"Void\00"
@.str.s309 = private unnamed_addr constant [5 x i8] c"void\00"
@.str.s310 = private unnamed_addr constant [4 x i8] c"Int\00"
@.str.s311 = private unnamed_addr constant [4 x i8] c"i32\00"
@.str.s312 = private unnamed_addr constant [6 x i8] c"Float\00"
@.str.s313 = private unnamed_addr constant [7 x i8] c"double\00"
@.str.s314 = private unnamed_addr constant [5 x i8] c"Bool\00"
@.str.s315 = private unnamed_addr constant [3 x i8] c"i1\00"
@.str.s316 = private unnamed_addr constant [5 x i8] c"Char\00"
@.str.s317 = private unnamed_addr constant [3 x i8] c"i8\00"
@.str.s318 = private unnamed_addr constant [7 x i8] c"String\00"
@.str.s319 = private unnamed_addr constant [4 x i8] c"ptr\00"
@.str.s320 = private unnamed_addr constant [4 x i8] c"Ptr\00"
@.str.s321 = private unnamed_addr constant [4 x i8] c"ptr\00"
@.str.s322 = private unnamed_addr constant [3 x i8] c"I8\00"
@.str.s323 = private unnamed_addr constant [3 x i8] c"i8\00"
@.str.s324 = private unnamed_addr constant [4 x i8] c"I16\00"
@.str.s325 = private unnamed_addr constant [4 x i8] c"i16\00"
@.str.s326 = private unnamed_addr constant [4 x i8] c"I64\00"
@.str.s327 = private unnamed_addr constant [4 x i8] c"i64\00"
@.str.s328 = private unnamed_addr constant [6 x i8] c"Isize\00"
@.str.s329 = private unnamed_addr constant [4 x i8] c"i64\00"
@.str.s330 = private unnamed_addr constant [3 x i8] c"U8\00"
@.str.s331 = private unnamed_addr constant [3 x i8] c"i8\00"
@.str.s332 = private unnamed_addr constant [4 x i8] c"U16\00"
@.str.s333 = private unnamed_addr constant [4 x i8] c"i16\00"
@.str.s334 = private unnamed_addr constant [4 x i8] c"U32\00"
@.str.s335 = private unnamed_addr constant [4 x i8] c"i32\00"
@.str.s336 = private unnamed_addr constant [4 x i8] c"U64\00"
@.str.s337 = private unnamed_addr constant [4 x i8] c"i64\00"
@.str.s338 = private unnamed_addr constant [6 x i8] c"Usize\00"
@.str.s339 = private unnamed_addr constant [4 x i8] c"i64\00"
@.str.s340 = private unnamed_addr constant [3 x i8] c"i1\00"
@.str.s341 = private unnamed_addr constant [3 x i8] c"i8\00"
@.str.s342 = private unnamed_addr constant [4 x i8] c"i16\00"
@.str.s343 = private unnamed_addr constant [4 x i8] c"i32\00"
@.str.s344 = private unnamed_addr constant [4 x i8] c"i64\00"
@.str.s345 = private unnamed_addr constant [2 x i8] c"U\00"
@.str.s346 = private unnamed_addr constant [4 x i8] c"ptr\00"
@.str.s347 = private unnamed_addr constant [4 x i8] c"i32\00"
@.str.s348 = private unnamed_addr constant [6 x i8] c"Array\00"
@.str.s349 = private unnamed_addr constant [4 x i8] c"ptr\00"
@.str.s350 = private unnamed_addr constant [5 x i8] c"List\00"
@.str.s351 = private unnamed_addr constant [4 x i8] c"ptr\00"
@.str.s352 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s353 = private unnamed_addr constant [2 x i8] c"[\00"
@.str.s354 = private unnamed_addr constant [2 x i8] c"]\00"
@.str.s355 = private unnamed_addr constant [10 x i8] c"[Invalid]\00"
@.str.s356 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s357 = private unnamed_addr constant [6 x i8] c"List<\00"
@.str.s358 = private unnamed_addr constant [2 x i8] c">\00"
@.str.s359 = private unnamed_addr constant [5 x i8] c"List\00"
@.str.s360 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s361 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s362 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s363 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s364 = private unnamed_addr constant [5 x i8] c"void\00"
@.str.s365 = private unnamed_addr constant [7 x i8] c"double\00"
@.str.s366 = private unnamed_addr constant [3 x i8] c"i1\00"
@.str.s367 = private unnamed_addr constant [3 x i8] c"i8\00"
@.str.s368 = private unnamed_addr constant [4 x i8] c"ptr\00"
@.str.s369 = private unnamed_addr constant [4 x i8] c"ptr\00"
@.str.s370 = private unnamed_addr constant [4 x i8] c"i32\00"
@.str.s371 = private unnamed_addr constant [8 x i8] c"struct:\00"
@.str.s372 = private unnamed_addr constant [4 x i8] c"ptr\00"
@.str.s373 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s374 = private unnamed_addr constant [7 x i8] c"ptrptr\00"
@.str.s375 = private unnamed_addr constant [4 x i8] c"ptr\00"
@.str.s376 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s377 = private unnamed_addr constant [5 x i8] c"Void\00"
@.str.s378 = private unnamed_addr constant [6 x i8] c"Float\00"
@.str.s379 = private unnamed_addr constant [5 x i8] c"Bool\00"
@.str.s380 = private unnamed_addr constant [5 x i8] c"Char\00"
@.str.s381 = private unnamed_addr constant [7 x i8] c"String\00"
@.str.s382 = private unnamed_addr constant [4 x i8] c"Ptr\00"
@.str.s383 = private unnamed_addr constant [8 x i8] c"struct:\00"
@.str.s384 = private unnamed_addr constant [6 x i8] c"enum:\00"
@.str.s385 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s386 = private unnamed_addr constant [7 x i8] c"array:\00"
@.str.s387 = private unnamed_addr constant [14 x i8] c"array:Invalid\00"
@.str.s388 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s389 = private unnamed_addr constant [6 x i8] c"list:\00"
@.str.s390 = private unnamed_addr constant [13 x i8] c"list:Invalid\00"
@.str.s391 = private unnamed_addr constant [8 x i8] c"Invalid\00"
@.str.s392 = private unnamed_addr constant [7 x i8] c"ptrptr\00"
@.str.s393 = private unnamed_addr constant [4 x i8] c"ptr\00"
@.str.s394 = private unnamed_addr constant [8 x i8] c"struct:\00"
@.str.s395 = private unnamed_addr constant [4 x i8] c"ptr\00"
@.str.s396 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s397 = private unnamed_addr constant [4 x i8] c"Int\00"
@.str.s398 = private unnamed_addr constant [6 x i8] c"Float\00"
@.str.s399 = private unnamed_addr constant [5 x i8] c"Bool\00"
@.str.s400 = private unnamed_addr constant [7 x i8] c"String\00"
@.str.s401 = private unnamed_addr constant [5 x i8] c"Char\00"
@.str.s402 = private unnamed_addr constant [3 x i8] c"I8\00"
@.str.s403 = private unnamed_addr constant [4 x i8] c"I16\00"
@.str.s404 = private unnamed_addr constant [4 x i8] c"I64\00"
@.str.s405 = private unnamed_addr constant [6 x i8] c"Isize\00"
@.str.s406 = private unnamed_addr constant [3 x i8] c"U8\00"
@.str.s407 = private unnamed_addr constant [4 x i8] c"U16\00"
@.str.s408 = private unnamed_addr constant [4 x i8] c"U32\00"
@.str.s409 = private unnamed_addr constant [4 x i8] c"U64\00"
@.str.s410 = private unnamed_addr constant [6 x i8] c"Usize\00"
@.str.s411 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s412 = private unnamed_addr constant [4 x i8] c"i32\00"
@.str.s413 = private unnamed_addr constant [7 x i8] c"double\00"
@.str.s414 = private unnamed_addr constant [3 x i8] c"i1\00"
@.str.s415 = private unnamed_addr constant [3 x i8] c"i8\00"
@.str.s416 = private unnamed_addr constant [4 x i8] c"ptr\00"
@.str.s417 = private unnamed_addr constant [5 x i8] c"void\00"
@.str.s418 = private unnamed_addr constant [8 x i8] c"struct:\00"
@.str.s419 = private unnamed_addr constant [4 x i8] c"Int\00"
@.str.s420 = private unnamed_addr constant [6 x i8] c"Float\00"
@.str.s421 = private unnamed_addr constant [5 x i8] c"Bool\00"
@.str.s422 = private unnamed_addr constant [5 x i8] c"Char\00"
@.str.s423 = private unnamed_addr constant [7 x i8] c"String\00"
@.str.s424 = private unnamed_addr constant [4 x i8] c"Ptr\00"
@.str.s425 = private unnamed_addr constant [5 x i8] c"Void\00"
@.str.s426 = private unnamed_addr constant [3 x i8] c"I8\00"
@.str.s427 = private unnamed_addr constant [4 x i8] c"I16\00"
@.str.s428 = private unnamed_addr constant [4 x i8] c"I64\00"
@.str.s429 = private unnamed_addr constant [6 x i8] c"Isize\00"
@.str.s430 = private unnamed_addr constant [3 x i8] c"U8\00"
@.str.s431 = private unnamed_addr constant [4 x i8] c"U16\00"
@.str.s432 = private unnamed_addr constant [4 x i8] c"U32\00"
@.str.s433 = private unnamed_addr constant [4 x i8] c"U64\00"
@.str.s434 = private unnamed_addr constant [6 x i8] c"Usize\00"
@.str.s435 = private unnamed_addr constant [8 x i8] c"struct:\00"
@.str.s436 = private unnamed_addr constant [6 x i8] c"enum:\00"
@.str.s437 = private unnamed_addr constant [7 x i8] c"array:\00"
@.str.s438 = private unnamed_addr constant [6 x i8] c"list:\00"
@.str.s439 = private unnamed_addr constant [1 x i8] zeroinitializer
@ir_string_counter = global i32 0
@ir_target_wasm = global i1 false
@ir_short_circuit_counter = global i32 0
@.str.s440 = private unnamed_addr constant [4 x i8] c"i32\00"
@.str.s441 = private unnamed_addr constant [4 x i8] c"i64\00"
@.str.s442 = private unnamed_addr constant [4 x i8] c"Int\00"
@.str.s443 = private unnamed_addr constant [4 x i8] c"i32\00"
@.str.s444 = private unnamed_addr constant [6 x i8] c"Float\00"
@.str.s445 = private unnamed_addr constant [7 x i8] c"double\00"
@.str.s446 = private unnamed_addr constant [5 x i8] c"Bool\00"
@.str.s447 = private unnamed_addr constant [3 x i8] c"i1\00"
@.str.s448 = private unnamed_addr constant [7 x i8] c"String\00"
@.str.s449 = private unnamed_addr constant [4 x i8] c"ptr\00"
@.str.s450 = private unnamed_addr constant [5 x i8] c"Char\00"
@.str.s451 = private unnamed_addr constant [3 x i8] c"i8\00"
@.str.s452 = private unnamed_addr constant [3 x i8] c"I8\00"
@.str.s453 = private unnamed_addr constant [3 x i8] c"i8\00"
@.str.s454 = private unnamed_addr constant [4 x i8] c"I16\00"
@.str.s455 = private unnamed_addr constant [4 x i8] c"i16\00"
@.str.s456 = private unnamed_addr constant [4 x i8] c"I64\00"
@.str.s457 = private unnamed_addr constant [4 x i8] c"i64\00"
@.str.s458 = private unnamed_addr constant [6 x i8] c"Isize\00"
@.str.s459 = private unnamed_addr constant [3 x i8] c"U8\00"
@.str.s460 = private unnamed_addr constant [3 x i8] c"i8\00"
@.str.s461 = private unnamed_addr constant [4 x i8] c"U16\00"
@.str.s462 = private unnamed_addr constant [4 x i8] c"i16\00"
@.str.s463 = private unnamed_addr constant [4 x i8] c"U32\00"
@.str.s464 = private unnamed_addr constant [4 x i8] c"i32\00"
@.str.s465 = private unnamed_addr constant [4 x i8] c"U64\00"
@.str.s466 = private unnamed_addr constant [4 x i8] c"i64\00"
@.str.s467 = private unnamed_addr constant [6 x i8] c"Usize\00"
@.str.s468 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s469 = private unnamed_addr constant [5 x i8] c"void\00"
@.str.s470 = private unnamed_addr constant [4 x i8] c"i32\00"
@.str.s471 = private unnamed_addr constant [8 x i8] c"struct:\00"
@.str.s472 = private unnamed_addr constant [8 x i8] c"struct:\00"
@.str.s473 = private unnamed_addr constant [2 x i8] c"%\00"
@.str.s474 = private unnamed_addr constant [4 x i8] c"ptr\00"
@.str.s475 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s476 = private unnamed_addr constant [7 x i8] c"ptrptr\00"
@.str.s477 = private unnamed_addr constant [4 x i8] c"ptr\00"
@.str.s478 = private unnamed_addr constant [7 x i8] c"ptrptr\00"
@.str.s479 = private unnamed_addr constant [4 x i8] c"ptr\00"
@.str.s480 = private unnamed_addr constant [4 x i8] c"ptr\00"
@.str.s481 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s482 = private unnamed_addr constant [5 x i8] c"$fn$\00"
@.str.s483 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s484 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s485 = private unnamed_addr constant [5 x i8] c"void\00"
@.str.s486 = private unnamed_addr constant [4 x i8] c"i32\00"
@.str.s487 = private unnamed_addr constant [7 x i8] c"double\00"
@.str.s488 = private unnamed_addr constant [3 x i8] c"i1\00"
@.str.s489 = private unnamed_addr constant [3 x i8] c"i8\00"
@.str.s490 = private unnamed_addr constant [4 x i8] c"ptr\00"
@.str.s491 = private unnamed_addr constant [2 x i8] c"!\00"
@.str.s492 = private unnamed_addr constant [3 x i8] c"i1\00"
@.str.s493 = private unnamed_addr constant [3 x i8] c"==\00"
@.str.s494 = private unnamed_addr constant [3 x i8] c"!=\00"
@.str.s495 = private unnamed_addr constant [3 x i8] c"i1\00"
@.str.s496 = private unnamed_addr constant [2 x i8] c"<\00"
@.str.s497 = private unnamed_addr constant [3 x i8] c"<=\00"
@.str.s498 = private unnamed_addr constant [3 x i8] c"i1\00"
@.str.s499 = private unnamed_addr constant [2 x i8] c">\00"
@.str.s500 = private unnamed_addr constant [3 x i8] c">=\00"
@.str.s501 = private unnamed_addr constant [3 x i8] c"i1\00"
@.str.s502 = private unnamed_addr constant [4 x i8] c"and\00"
@.str.s503 = private unnamed_addr constant [3 x i8] c"or\00"
@.str.s504 = private unnamed_addr constant [3 x i8] c"i1\00"
@.str.s505 = private unnamed_addr constant [6 x i8] c"print\00"
@.str.s506 = private unnamed_addr constant [8 x i8] c"println\00"
@.str.s507 = private unnamed_addr constant [5 x i8] c"void\00"
@.str.s508 = private unnamed_addr constant [10 x i8] c"print_int\00"
@.str.s509 = private unnamed_addr constant [12 x i8] c"println_int\00"
@.str.s510 = private unnamed_addr constant [5 x i8] c"void\00"
@.str.s511 = private unnamed_addr constant [12 x i8] c"print_float\00"
@.str.s512 = private unnamed_addr constant [14 x i8] c"println_float\00"
@.str.s513 = private unnamed_addr constant [5 x i8] c"void\00"
@.str.s514 = private unnamed_addr constant [13 x i8] c"println_char\00"
@.str.s515 = private unnamed_addr constant [11 x i8] c"print_char\00"
@.str.s516 = private unnamed_addr constant [5 x i8] c"void\00"
@.str.s517 = private unnamed_addr constant [13 x i8] c"println_bool\00"
@.str.s518 = private unnamed_addr constant [11 x i8] c"print_bool\00"
@.str.s519 = private unnamed_addr constant [5 x i8] c"void\00"
@.str.s520 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s521 = private unnamed_addr constant [7 x i8] c"ptrptr\00"
@.str.s522 = private unnamed_addr constant [4 x i8] c"ptr\00"
@.str.s523 = private unnamed_addr constant [4 x i8] c"i32\00"
@.str.s524 = private unnamed_addr constant [4 x i8] c"i32\00"
@.str.s525 = private unnamed_addr constant [4 x i8] c"i32\00"
@.str.s526 = private unnamed_addr constant [4 x i8] c"ptr\00"
@.str.s527 = private unnamed_addr constant [4 x i8] c"i32\00"
@.str.s528 = private unnamed_addr constant [4 x i8] c"and\00"
@.str.s529 = private unnamed_addr constant [4 x i8] c"sc.\00"
@.str.s530 = private unnamed_addr constant [3 x i8] c"i1\00"
@.str.s531 = private unnamed_addr constant [3 x i8] c"i1\00"
@.str.s532 = private unnamed_addr constant [3 x i8] c"i1\00"
@.str.s533 = private unnamed_addr constant [3 x i8] c"i1\00"
@.str.s534 = private unnamed_addr constant [5 x i8] c"true\00"
@.str.s535 = private unnamed_addr constant [2 x i8] c"1\00"
@.str.s536 = private unnamed_addr constant [2 x i8] c"0\00"
@.str.s537 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s538 = private unnamed_addr constant [4 x i8] c"i32\00"
@.str.s539 = private unnamed_addr constant [4 x i8] c"ptr\00"
@.str.s540 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s541 = private unnamed_addr constant [4 x i8] c"i32\00"
@.str.s542 = private unnamed_addr constant [7 x i8] c"ptrptr\00"
@.str.s543 = private unnamed_addr constant [4 x i8] c"ptr\00"
@.str.s544 = private unnamed_addr constant [7 x i8] c"double\00"
@.str.s545 = private unnamed_addr constant [7 x i8] c"double\00"
@.str.s546 = private unnamed_addr constant [2 x i8] c"!\00"
@.str.s547 = private unnamed_addr constant [3 x i8] c"i1\00"
@.str.s548 = private unnamed_addr constant [2 x i8] c"0\00"
@.str.s549 = private unnamed_addr constant [2 x i8] c"~\00"
@.str.s550 = private unnamed_addr constant [2 x i8] c"-\00"
@.str.s551 = private unnamed_addr constant [7 x i8] c"double\00"
@.str.s552 = private unnamed_addr constant [7 x i8] c"double\00"
@.str.s553 = private unnamed_addr constant [4 x i8] c"0.0\00"
@.str.s554 = private unnamed_addr constant [4 x i8] c"and\00"
@.str.s555 = private unnamed_addr constant [3 x i8] c"or\00"
@.str.s556 = private unnamed_addr constant [7 x i8] c"double\00"
@.str.s557 = private unnamed_addr constant [2 x i8] c"+\00"
@.str.s558 = private unnamed_addr constant [2 x i8] c"-\00"
@.str.s559 = private unnamed_addr constant [2 x i8] c"*\00"
@.str.s560 = private unnamed_addr constant [2 x i8] c"/\00"
@.str.s561 = private unnamed_addr constant [3 x i8] c"==\00"
@.str.s562 = private unnamed_addr constant [3 x i8] c"!=\00"
@.str.s563 = private unnamed_addr constant [2 x i8] c"<\00"
@.str.s564 = private unnamed_addr constant [3 x i8] c"<=\00"
@.str.s565 = private unnamed_addr constant [2 x i8] c">\00"
@.str.s566 = private unnamed_addr constant [3 x i8] c">=\00"
@.str.s567 = private unnamed_addr constant [2 x i8] c"+\00"
@.str.s568 = private unnamed_addr constant [2 x i8] c"-\00"
@.str.s569 = private unnamed_addr constant [2 x i8] c"*\00"
@.str.s570 = private unnamed_addr constant [3 x i8] c"==\00"
@.str.s571 = private unnamed_addr constant [3 x i8] c"!=\00"
@.str.s572 = private unnamed_addr constant [2 x i8] c"/\00"
@.str.s573 = private unnamed_addr constant [2 x i8] c"<\00"
@.str.s574 = private unnamed_addr constant [3 x i8] c"<=\00"
@.str.s575 = private unnamed_addr constant [2 x i8] c">\00"
@.str.s576 = private unnamed_addr constant [3 x i8] c">=\00"
@.str.s577 = private unnamed_addr constant [2 x i8] c"/\00"
@.str.s578 = private unnamed_addr constant [2 x i8] c"<\00"
@.str.s579 = private unnamed_addr constant [3 x i8] c"<=\00"
@.str.s580 = private unnamed_addr constant [2 x i8] c">\00"
@.str.s581 = private unnamed_addr constant [3 x i8] c">=\00"
@.str.s582 = private unnamed_addr constant [2 x i8] c"%\00"
@.str.s583 = private unnamed_addr constant [2 x i8] c"&\00"
@.str.s584 = private unnamed_addr constant [2 x i8] c"|\00"
@.str.s585 = private unnamed_addr constant [2 x i8] c"^\00"
@.str.s586 = private unnamed_addr constant [3 x i8] c"<<\00"
@.str.s587 = private unnamed_addr constant [3 x i8] c">>\00"
@.str.s588 = private unnamed_addr constant [5 x i8] c"drop\00"
@.str.s589 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s590 = private unnamed_addr constant [4 x i8] c"ptr\00"
@.str.s591 = private unnamed_addr constant [5 x i8] c"void\00"
@.str.s592 = private unnamed_addr constant [5 x i8] c"free\00"
@.str.s593 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s594 = private unnamed_addr constant [11 x i8] c"print_bool\00"
@.str.s595 = private unnamed_addr constant [13 x i8] c"println_bool\00"
@.str.s596 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s597 = private unnamed_addr constant [3 x i8] c"i1\00"
@.str.s598 = private unnamed_addr constant [4 x i8] c"i32\00"
@.str.s599 = private unnamed_addr constant [4 x i8] c"i32\00"
@.str.s600 = private unnamed_addr constant [5 x i8] c"void\00"
@.str.s601 = private unnamed_addr constant [11 x i8] c"print_bool\00"
@.str.s602 = private unnamed_addr constant [5 x i8] c"void\00"
@.str.s603 = private unnamed_addr constant [13 x i8] c"println_bool\00"
@.str.s604 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s605 = private unnamed_addr constant [6 x i8] c"print\00"
@.str.s606 = private unnamed_addr constant [8 x i8] c"println\00"
@.str.s607 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s608 = private unnamed_addr constant [4 x i8] c"ptr\00"
@.str.s609 = private unnamed_addr constant [4 x i8] c"ptr\00"
@.str.s610 = private unnamed_addr constant [5 x i8] c"void\00"
@.str.s611 = private unnamed_addr constant [6 x i8] c"print\00"
@.str.s612 = private unnamed_addr constant [5 x i8] c"void\00"
@.str.s613 = private unnamed_addr constant [8 x i8] c"println\00"
@.str.s614 = private unnamed_addr constant [7 x i8] c"double\00"
@.str.s615 = private unnamed_addr constant [7 x i8] c"double\00"
@.str.s616 = private unnamed_addr constant [5 x i8] c"void\00"
@.str.s617 = private unnamed_addr constant [12 x i8] c"print_float\00"
@.str.s618 = private unnamed_addr constant [5 x i8] c"void\00"
@.str.s619 = private unnamed_addr constant [14 x i8] c"println_float\00"
@.str.s620 = private unnamed_addr constant [5 x i8] c"void\00"
@.str.s621 = private unnamed_addr constant [10 x i8] c"print_int\00"
@.str.s622 = private unnamed_addr constant [5 x i8] c"void\00"
@.str.s623 = private unnamed_addr constant [12 x i8] c"println_int\00"
@.str.s624 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s625 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s626 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s627 = private unnamed_addr constant [5 x i8] c"void\00"
@.str.s628 = private unnamed_addr constant [5 x i8] c"void\00"
@.str.s629 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s630 = private unnamed_addr constant [2 x i8] c"0\00"
@.str.s631 = private unnamed_addr constant [4 x i8] c"i32\00"
@.str.s632 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s633 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s634 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s635 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s636 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s637 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s638 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s639 = private unnamed_addr constant [4 x i8] c"i32\00"
@.str.s640 = private unnamed_addr constant [4 x i8] c"i32\00"
@.str.s641 = private unnamed_addr constant [4 x i8] c"i32\00"
@.str.s642 = private unnamed_addr constant [4 x i8] c"i32\00"
@.str.s643 = private unnamed_addr constant [4 x i8] c"i32\00"
@.str.s644 = private unnamed_addr constant [2 x i8] c"1\00"
@.str.s645 = private unnamed_addr constant [4 x i8] c"i32\00"
@.str.s646 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s647 = private unnamed_addr constant [2 x i8] c"_\00"
@.str.s648 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s649 = private unnamed_addr constant [4 x i8] c"i32\00"
@.str.s650 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s651 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s652 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s653 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s654 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s655 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s656 = private unnamed_addr constant [4 x i8] c"i32\00"
@.str.s657 = private unnamed_addr constant [4 x i8] c"i32\00"
@.str.s658 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s659 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s660 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s661 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s662 = private unnamed_addr constant [5 x i8] c"void\00"
@.str.s663 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s664 = private unnamed_addr constant [5 x i8] c"main\00"
@.str.s665 = private unnamed_addr constant [4 x i8] c"i32\00"
@.str.s666 = private unnamed_addr constant [4 x i8] c"i32\00"
@.str.s667 = private unnamed_addr constant [7 x i8] c"p_argc\00"
@.str.s668 = private unnamed_addr constant [4 x i8] c"ptr\00"
@.str.s669 = private unnamed_addr constant [7 x i8] c"p_argv\00"
@.str.s670 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s671 = private unnamed_addr constant [3 x i8] c"p_\00"
@.str.s672 = private unnamed_addr constant [4 x i8] c"i32\00"
@.str.s673 = private unnamed_addr constant [8 x i8] c"%p_argc\00"
@.str.s674 = private unnamed_addr constant [13 x i8] c"prismio_argc\00"
@.str.s675 = private unnamed_addr constant [4 x i8] c"ptr\00"
@.str.s676 = private unnamed_addr constant [8 x i8] c"%p_argv\00"
@.str.s677 = private unnamed_addr constant [13 x i8] c"prismio_argv\00"
@.str.s678 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s679 = private unnamed_addr constant [4 x i8] c"%p_\00"
@.str.s680 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s681 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s682 = private unnamed_addr constant [5 x i8] c"void\00"
@.str.s683 = private unnamed_addr constant [4 x i8] c"i32\00"
@.str.s684 = private unnamed_addr constant [2 x i8] c"0\00"
@.str.s685 = private unnamed_addr constant [2 x i8] c"0\00"
@.str.s686 = private unnamed_addr constant [7 x i8] c".str.s\00"
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
@.str.s706 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s707 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s708 = private unnamed_addr constant [19 x i8] c"self_hosted_module\00"
@.str.s709 = private unnamed_addr constant [19 x i8] c"self_hosted_module\00"
@.str.s710 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s711 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s712 = private unnamed_addr constant [13 x i8] c"prismio_argc\00"
@.str.s713 = private unnamed_addr constant [4 x i8] c"i32\00"
@.str.s714 = private unnamed_addr constant [2 x i8] c"0\00"
@.str.s715 = private unnamed_addr constant [13 x i8] c"prismio_argv\00"
@.str.s716 = private unnamed_addr constant [4 x i8] c"ptr\00"
@.str.s717 = private unnamed_addr constant [5 x i8] c"null\00"
@.str.s718 = private unnamed_addr constant [7 x i8] c"malloc\00"
@.str.s719 = private unnamed_addr constant [4 x i8] c"ptr\00"
@.str.s720 = private unnamed_addr constant [5 x i8] c"free\00"
@.str.s721 = private unnamed_addr constant [5 x i8] c"void\00"
@.str.s722 = private unnamed_addr constant [4 x i8] c"ptr\00"
@.str.s723 = private unnamed_addr constant [9 x i8] c"list_new\00"
@.str.s724 = private unnamed_addr constant [4 x i8] c"ptr\00"
@.str.s725 = private unnamed_addr constant [10 x i8] c"list_push\00"
@.str.s726 = private unnamed_addr constant [5 x i8] c"void\00"
@.str.s727 = private unnamed_addr constant [4 x i8] c"ptr\00"
@.str.s728 = private unnamed_addr constant [4 x i8] c"ptr\00"
@.str.s729 = private unnamed_addr constant [9 x i8] c"list_get\00"
@.str.s730 = private unnamed_addr constant [4 x i8] c"ptr\00"
@.str.s731 = private unnamed_addr constant [4 x i8] c"ptr\00"
@.str.s732 = private unnamed_addr constant [4 x i8] c"i32\00"
@.str.s733 = private unnamed_addr constant [9 x i8] c"list_set\00"
@.str.s734 = private unnamed_addr constant [5 x i8] c"void\00"
@.str.s735 = private unnamed_addr constant [4 x i8] c"ptr\00"
@.str.s736 = private unnamed_addr constant [4 x i8] c"i32\00"
@.str.s737 = private unnamed_addr constant [4 x i8] c"ptr\00"
@.str.s738 = private unnamed_addr constant [9 x i8] c"list_len\00"
@.str.s739 = private unnamed_addr constant [4 x i8] c"i32\00"
@.str.s740 = private unnamed_addr constant [4 x i8] c"ptr\00"
@.str.s741 = private unnamed_addr constant [8 x i8] c"println\00"
@.str.s742 = private unnamed_addr constant [5 x i8] c"void\00"
@.str.s743 = private unnamed_addr constant [4 x i8] c"ptr\00"
@.str.s744 = private unnamed_addr constant [6 x i8] c"print\00"
@.str.s745 = private unnamed_addr constant [5 x i8] c"void\00"
@.str.s746 = private unnamed_addr constant [4 x i8] c"ptr\00"
@.str.s747 = private unnamed_addr constant [12 x i8] c"println_int\00"
@.str.s748 = private unnamed_addr constant [5 x i8] c"void\00"
@.str.s749 = private unnamed_addr constant [4 x i8] c"i32\00"
@.str.s750 = private unnamed_addr constant [10 x i8] c"print_int\00"
@.str.s751 = private unnamed_addr constant [5 x i8] c"void\00"
@.str.s752 = private unnamed_addr constant [4 x i8] c"i32\00"
@.str.s753 = private unnamed_addr constant [14 x i8] c"println_float\00"
@.str.s754 = private unnamed_addr constant [5 x i8] c"void\00"
@.str.s755 = private unnamed_addr constant [7 x i8] c"double\00"
@.str.s756 = private unnamed_addr constant [12 x i8] c"print_float\00"
@.str.s757 = private unnamed_addr constant [5 x i8] c"void\00"
@.str.s758 = private unnamed_addr constant [7 x i8] c"double\00"
@.str.s759 = private unnamed_addr constant [13 x i8] c"println_bool\00"
@.str.s760 = private unnamed_addr constant [5 x i8] c"void\00"
@.str.s761 = private unnamed_addr constant [4 x i8] c"i32\00"
@.str.s762 = private unnamed_addr constant [11 x i8] c"print_bool\00"
@.str.s763 = private unnamed_addr constant [5 x i8] c"void\00"
@.str.s764 = private unnamed_addr constant [4 x i8] c"i32\00"
@.str.s765 = private unnamed_addr constant [13 x i8] c"println_char\00"
@.str.s766 = private unnamed_addr constant [5 x i8] c"void\00"
@.str.s767 = private unnamed_addr constant [3 x i8] c"i8\00"
@.str.s768 = private unnamed_addr constant [11 x i8] c"print_char\00"
@.str.s769 = private unnamed_addr constant [5 x i8] c"void\00"
@.str.s770 = private unnamed_addr constant [3 x i8] c"i8\00"
@.str.s771 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s772 = private unnamed_addr constant [2 x i8] c"0\00"
@.str.s773 = private unnamed_addr constant [4 x i8] c"i32\00"
@.str.s774 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s775 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s776 = private unnamed_addr constant [2 x i8] c"@\00"
@.str.s777 = private unnamed_addr constant [15 x i8] c"error: global \00"
@.str.s778 = private unnamed_addr constant [33 x i8] c" requires a constant initializer\00"
@.str.s779 = private unnamed_addr constant [5 x i8] c"main\00"
@.str.s780 = private unnamed_addr constant [4 x i8] c"i32\00"
@.str.s781 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s782 = private unnamed_addr constant [5 x i8] c"$fn$\00"
@.str.s783 = private unnamed_addr constant [5 x i8] c"Void\00"
@.str.s784 = private unnamed_addr constant [6 x i8] c"Float\00"
@.str.s785 = private unnamed_addr constant [5 x i8] c"Bool\00"
@.str.s786 = private unnamed_addr constant [5 x i8] c"Char\00"
@.str.s787 = private unnamed_addr constant [7 x i8] c"String\00"
@.str.s788 = private unnamed_addr constant [4 x i8] c"Ptr\00"
@.str.s789 = private unnamed_addr constant [8 x i8] c"Struct_\00"
@.str.s790 = private unnamed_addr constant [6 x i8] c"Enum_\00"
@.str.s791 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s792 = private unnamed_addr constant [7 x i8] c"Array_\00"
@.str.s793 = private unnamed_addr constant [14 x i8] c"Array_Invalid\00"
@.str.s794 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s795 = private unnamed_addr constant [6 x i8] c"List_\00"
@.str.s796 = private unnamed_addr constant [13 x i8] c"List_Invalid\00"
@.str.s797 = private unnamed_addr constant [8 x i8] c"Invalid\00"
@.str.s798 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s799 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s800 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s801 = private unnamed_addr constant [2 x i8] c"_\00"
@.str.s802 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s803 = private unnamed_addr constant [5 x i8] c"Void\00"
@.str.s804 = private unnamed_addr constant [5 x i8] c"main\00"
@.str.s805 = private unnamed_addr constant [5 x i8] c"main\00"
@.str.s806 = private unnamed_addr constant [3 x i8] c"__\00"
@.str.s807 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s808 = private unnamed_addr constant [13 x i8] c"type error: \00"
@.str.s809 = private unnamed_addr constant [13 x i8] c"type error: \00"
@.str.s810 = private unnamed_addr constant [12 x i8] c": expected \00"
@.str.s811 = private unnamed_addr constant [7 x i8] c", got \00"
@.str.s812 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s813 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s814 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s815 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s816 = private unnamed_addr constant [4 x i8] c"Int\00"
@.str.s817 = private unnamed_addr constant [6 x i8] c"Float\00"
@.str.s818 = private unnamed_addr constant [5 x i8] c"Bool\00"
@.str.s819 = private unnamed_addr constant [7 x i8] c"String\00"
@.str.s820 = private unnamed_addr constant [5 x i8] c"Char\00"
@.str.s821 = private unnamed_addr constant [3 x i8] c"I8\00"
@.str.s822 = private unnamed_addr constant [4 x i8] c"I16\00"
@.str.s823 = private unnamed_addr constant [4 x i8] c"I64\00"
@.str.s824 = private unnamed_addr constant [6 x i8] c"Isize\00"
@.str.s825 = private unnamed_addr constant [3 x i8] c"U8\00"
@.str.s826 = private unnamed_addr constant [4 x i8] c"U16\00"
@.str.s827 = private unnamed_addr constant [4 x i8] c"U32\00"
@.str.s828 = private unnamed_addr constant [4 x i8] c"U64\00"
@.str.s829 = private unnamed_addr constant [6 x i8] c"Usize\00"
@.str.s830 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s831 = private unnamed_addr constant [14 x i8] c"unknown type \00"
@.str.s832 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s833 = private unnamed_addr constant [4 x i8] c"Int\00"
@.str.s834 = private unnamed_addr constant [36 x i8] c"cannot move out of borrowed value: \00"
@.str.s835 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s836 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s837 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s838 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s839 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s840 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s841 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s842 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s843 = private unnamed_addr constant [30 x i8] c"ambiguous overloaded call to \00"
@.str.s844 = private unnamed_addr constant [26 x i8] c"no matching overload for \00"
@.str.s845 = private unnamed_addr constant [18 x i8] c"unknown function \00"
@.str.s846 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s847 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s848 = private unnamed_addr constant [15 x i8] c"unknown field \00"
@.str.s849 = private unnamed_addr constant [5 x i8] c" on \00"
@.str.s850 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s851 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s852 = private unnamed_addr constant [6 x i8] c"print\00"
@.str.s853 = private unnamed_addr constant [8 x i8] c"println\00"
@.str.s854 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s855 = private unnamed_addr constant [22 x i8] c" expects one argument\00"
@.str.s856 = private unnamed_addr constant [10 x i8] c"print_int\00"
@.str.s857 = private unnamed_addr constant [12 x i8] c"println_int\00"
@.str.s858 = private unnamed_addr constant [12 x i8] c"print_float\00"
@.str.s859 = private unnamed_addr constant [14 x i8] c"println_float\00"
@.str.s860 = private unnamed_addr constant [11 x i8] c"print_bool\00"
@.str.s861 = private unnamed_addr constant [13 x i8] c"println_bool\00"
@.str.s862 = private unnamed_addr constant [11 x i8] c"print_char\00"
@.str.s863 = private unnamed_addr constant [13 x i8] c"println_char\00"
@.str.s864 = private unnamed_addr constant [5 x i8] c"drop\00"
@.str.s865 = private unnamed_addr constant [9 x i8] c"list_new\00"
@.str.s866 = private unnamed_addr constant [9 x i8] c"list_len\00"
@.str.s867 = private unnamed_addr constant [10 x i8] c"list_push\00"
@.str.s868 = private unnamed_addr constant [9 x i8] c"list_set\00"
@.str.s869 = private unnamed_addr constant [9 x i8] c"list_get\00"
@.str.s870 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s871 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s872 = private unnamed_addr constant [6 x i8] c"print\00"
@.str.s873 = private unnamed_addr constant [8 x i8] c"println\00"
@.str.s874 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s875 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s876 = private unnamed_addr constant [22 x i8] c" expects one argument\00"
@.str.s877 = private unnamed_addr constant [5 x i8] c"drop\00"
@.str.s878 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s879 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s880 = private unnamed_addr constant [26 x i8] c"drop expects one argument\00"
@.str.s881 = private unnamed_addr constant [41 x i8] c"drop requires an owned (move-only) value\00"
@.str.s882 = private unnamed_addr constant [9 x i8] c"list_new\00"
@.str.s883 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s884 = private unnamed_addr constant [28 x i8] c"list_new takes no arguments\00"
@.str.s885 = private unnamed_addr constant [9 x i8] c"list_len\00"
@.str.s886 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s887 = private unnamed_addr constant [24 x i8] c"list_len expects a List\00"
@.str.s888 = private unnamed_addr constant [24 x i8] c"list_len expects a List\00"
@.str.s889 = private unnamed_addr constant [9 x i8] c"list_get\00"
@.str.s890 = private unnamed_addr constant [24 x i8] c"list_get expects a List\00"
@.str.s891 = private unnamed_addr constant [15 x i8] c"list_get index\00"
@.str.s892 = private unnamed_addr constant [10 x i8] c"list_push\00"
@.str.s893 = private unnamed_addr constant [25 x i8] c"list_push expects a List\00"
@.str.s894 = private unnamed_addr constant [16 x i8] c"list_push value\00"
@.str.s895 = private unnamed_addr constant [9 x i8] c"list_set\00"
@.str.s896 = private unnamed_addr constant [24 x i8] c"list_set expects a List\00"
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
@.str.s907 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s908 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s909 = private unnamed_addr constant [22 x i8] c" expects one argument\00"
@.str.s910 = private unnamed_addr constant [10 x i8] c" argument\00"
@.str.s911 = private unnamed_addr constant [20 x i8] c"unknown identifier \00"
@.str.s912 = private unnamed_addr constant [21 x i8] c"use of moved value: \00"
@.str.s913 = private unnamed_addr constant [62 x i8] c"cannot cast to Bool; compare explicitly instead, as in x != 0\00"
@.str.s914 = private unnamed_addr constant [5 x i8] c"cast\00"
@.str.s915 = private unnamed_addr constant [2 x i8] c"!\00"
@.str.s916 = private unnamed_addr constant [11 x i8] c"operator !\00"
@.str.s917 = private unnamed_addr constant [2 x i8] c"~\00"
@.str.s918 = private unnamed_addr constant [36 x i8] c"unary ~ requires an integer operand\00"
@.str.s919 = private unnamed_addr constant [2 x i8] c"-\00"
@.str.s920 = private unnamed_addr constant [35 x i8] c"unary - requires a numeric operand\00"
@.str.s921 = private unnamed_addr constant [39 x i8] c"cannot apply unary - to unsigned type \00"
@.str.s922 = private unnamed_addr constant [24 x i8] c"unknown unary operator \00"
@.str.s923 = private unnamed_addr constant [4 x i8] c"and\00"
@.str.s924 = private unnamed_addr constant [3 x i8] c"or\00"
@.str.s925 = private unnamed_addr constant [30 x i8] c"boolean operator left operand\00"
@.str.s926 = private unnamed_addr constant [31 x i8] c"boolean operator right operand\00"
@.str.s927 = private unnamed_addr constant [2 x i8] c"+\00"
@.str.s928 = private unnamed_addr constant [2 x i8] c"-\00"
@.str.s929 = private unnamed_addr constant [2 x i8] c"*\00"
@.str.s930 = private unnamed_addr constant [2 x i8] c"/\00"
@.str.s931 = private unnamed_addr constant [37 x i8] c"operator requires numeric operands: \00"
@.str.s932 = private unnamed_addr constant [10 x i8] c"operator \00"
@.str.s933 = private unnamed_addr constant [2 x i8] c"%\00"
@.str.s934 = private unnamed_addr constant [33 x i8] c"modulo requires integer operands\00"
@.str.s935 = private unnamed_addr constant [11 x i8] c"operator %\00"
@.str.s936 = private unnamed_addr constant [2 x i8] c"&\00"
@.str.s937 = private unnamed_addr constant [2 x i8] c"|\00"
@.str.s938 = private unnamed_addr constant [2 x i8] c"^\00"
@.str.s939 = private unnamed_addr constant [45 x i8] c"bitwise operator requires integer operands: \00"
@.str.s940 = private unnamed_addr constant [10 x i8] c"operator \00"
@.str.s941 = private unnamed_addr constant [3 x i8] c"<<\00"
@.str.s942 = private unnamed_addr constant [3 x i8] c">>\00"
@.str.s943 = private unnamed_addr constant [41 x i8] c"shift requires an integer left operand: \00"
@.str.s944 = private unnamed_addr constant [34 x i8] c"shift amount must be an integer: \00"
@.str.s945 = private unnamed_addr constant [3 x i8] c"==\00"
@.str.s946 = private unnamed_addr constant [3 x i8] c"!=\00"
@.str.s947 = private unnamed_addr constant [2 x i8] c"<\00"
@.str.s948 = private unnamed_addr constant [3 x i8] c"<=\00"
@.str.s949 = private unnamed_addr constant [2 x i8] c">\00"
@.str.s950 = private unnamed_addr constant [3 x i8] c">=\00"
@.str.s951 = private unnamed_addr constant [12 x i8] c"comparison \00"
@.str.s952 = private unnamed_addr constant [18 x i8] c"unknown operator \00"
@.str.s953 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s954 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s955 = private unnamed_addr constant [10 x i8] c" argument\00"
@.str.s956 = private unnamed_addr constant [5 x i8] c"sink\00"
@.str.s957 = private unnamed_addr constant [5 x i8] c"main\00"
@.str.s958 = private unnamed_addr constant [38 x i8] c"member access requires a struct value\00"
@.str.s959 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s960 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s961 = private unnamed_addr constant [22 x i8] c"array literal element\00"
@.str.s962 = private unnamed_addr constant [12 x i8] c"array index\00"
@.str.s963 = private unnamed_addr constant [27 x i8] c"indexing requires an array\00"
@.str.s964 = private unnamed_addr constant [16 x i8] c"unknown struct \00"
@.str.s965 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s966 = private unnamed_addr constant [14 x i8] c"struct field \00"
@.str.s967 = private unnamed_addr constant [23 x i8] c"unsupported expression\00"
@.str.s968 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s969 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s970 = private unnamed_addr constant [17 x i8] c"initializer for \00"
@.str.s971 = private unnamed_addr constant [23 x i8] c"cannot infer type for \00"
@.str.s972 = private unnamed_addr constant [11 x i8] c"assignment\00"
@.str.s973 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s974 = private unnamed_addr constant [7 x i8] c"return\00"
@.str.s975 = private unnamed_addr constant [7 x i8] c"return\00"
@.str.s976 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s977 = private unnamed_addr constant [13 x i8] c"if condition\00"
@.str.s978 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s979 = private unnamed_addr constant [16 x i8] c"while condition\00"
@.str.s980 = private unnamed_addr constant [16 x i8] c"for range start\00"
@.str.s981 = private unnamed_addr constant [14 x i8] c"for range end\00"
@.str.s982 = private unnamed_addr constant [49 x i8] c"match scrutinee must be an integer or enum value\00"
@.str.s983 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s984 = private unnamed_addr constant [2 x i8] c"_\00"
@.str.s985 = private unnamed_addr constant [14 x i8] c"match pattern\00"
@.str.s986 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s987 = private unnamed_addr constant [5 x i8] c"main\00"
@.str.s988 = private unnamed_addr constant [29 x i8] c"duplicate function overload \00"
@.str.s989 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s990 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s991 = private unnamed_addr constant [24 x i8] c"initializer for global \00"
@.str.s992 = private unnamed_addr constant [30 x i8] c"cannot infer type for global \00"
@.str.s993 = private unnamed_addr constant [5 x i8] c"main\00"
@.str.s994 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s995 = private unnamed_addr constant [6 x i8] c"inout\00"
@.str.s996 = private unnamed_addr constant [52 x i8] c"inout parameter must be a struct (reference) type: \00"
@.str.s997 = private unnamed_addr constant [5 x i8] c"sink\00"
@.str.s998 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s999 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s1000 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s1001 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s1002 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s1003 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s1004 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s1005 = private unnamed_addr constant [5 x i8] c".psm\00"
@.str.s1006 = private unnamed_addr constant [2 x i8] c".\00"
@.str.s1007 = private unnamed_addr constant [2 x i8] c"|\00"
@.str.s1008 = private unnamed_addr constant [2 x i8] c"|\00"
@.str.s1009 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s1010 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s1011 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s1012 = private unnamed_addr constant [25 x i8] c"ERROR: Could not import \00"
@.str.s1013 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s1014 = private unnamed_addr constant [7 x i8] c"Usage:\00"
@.str.s1015 = private unnamed_addr constant [45 x i8] c"  prismio build <source.psm> [-o output.exe]\00"
@.str.s1016 = private unnamed_addr constant [43 x i8] c"  prismio run <source.psm> [-o output.exe]\00"
@.str.s1017 = private unnamed_addr constant [49 x i8] c"  prismio bootstrap [source.psm] [-o output.exe]\00"
@.str.s1018 = private unnamed_addr constant [23 x i8] c"  prismio runtime-hash\00"
@.str.s1019 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s1020 = private unnamed_addr constant [59 x i8] c"build/run link against the installed Prismio runtime only.\00"
@.str.s1021 = private unnamed_addr constant [66 x i8] c"bootstrap builds the compiler itself from the repository sources,\00"
@.str.s1022 = private unnamed_addr constant [71 x i8] c"linking the compiler backend as well and ignoring installed libraries.\00"
@.str.s1023 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s1024 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s1025 = private unnamed_addr constant [55 x i8] c"ERROR: the installed Prismio runtime library is stale.\00"
@.str.s1026 = private unnamed_addr constant [50 x i8] c"  runtime library was built from sources hashing \00"
@.str.s1027 = private unnamed_addr constant [40 x i8] c"  the runtime sources on disk now hash \00"
@.str.s1028 = private unnamed_addr constant [73 x i8] c"  Re-package the toolchain (tools/package.ps1) so lib/ matches runtime/,\00"
@.str.s1029 = private unnamed_addr constant [72 x i8] c"  or move away from the source tree to use the installed runtime as-is.\00"
@.str.s1030 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s1031 = private unnamed_addr constant [4 x i8] c".ll\00"
@.str.s1032 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s1033 = private unnamed_addr constant [23 x i8] c"ERROR: Could not read \00"
@.str.s1034 = private unnamed_addr constant [66 x i8] c"  bootstrap compiles the Prismio compiler from a source checkout.\00"
@.str.s1035 = private unnamed_addr constant [71 x i8] c"  Run it from the repository root, or give the source path explicitly:\00"
@.str.s1036 = private unnamed_addr constant [45 x i8] c"      prismio bootstrap path/to/src/main.psm\00"
@.str.s1037 = private unnamed_addr constant [31 x i8] c"ERROR: Could not write LLVM IR\00"
@.str.s1038 = private unnamed_addr constant [16 x i8] c"Wrote LLVM IR: \00"
@.str.s1039 = private unnamed_addr constant [27 x i8] c"ERROR: Native build failed\00"
@.str.s1040 = private unnamed_addr constant [7 x i8] c"Built \00"
@.str.s1041 = private unnamed_addr constant [35 x i8] c"ERROR: Program exited with failure\00"
@.str.s1042 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s1043 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s1044 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s1045 = private unnamed_addr constant [13 x i8] c"runtime-hash\00"
@.str.s1046 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s1047 = private unnamed_addr constant [58 x i8] c"ERROR: could not find the Prismio runtime sources to hash\00"
@.str.s1048 = private unnamed_addr constant [10 x i8] c"bootstrap\00"
@.str.s1049 = private unnamed_addr constant [10 x i8] c"bootstrap\00"
@.str.s1050 = private unnamed_addr constant [13 x i8] c"src/main.psm\00"
@.str.s1051 = private unnamed_addr constant [3 x i8] c"-o\00"
@.str.s1052 = private unnamed_addr constant [9 x i8] c"--target\00"
@.str.s1053 = private unnamed_addr constant [3 x i8] c"-o\00"
@.str.s1054 = private unnamed_addr constant [34 x i8] c"ERROR: -o requires an output path\00"
@.str.s1055 = private unnamed_addr constant [25 x i8] c"ERROR: Unknown argument \00"
@.str.s1056 = private unnamed_addr constant [6 x i8] c"build\00"
@.str.s1057 = private unnamed_addr constant [6 x i8] c"build\00"
@.str.s1058 = private unnamed_addr constant [27 x i8] c"ERROR: Missing source file\00"
@.str.s1059 = private unnamed_addr constant [4 x i8] c"run\00"
@.str.s1060 = private unnamed_addr constant [6 x i8] c"build\00"
@.str.s1061 = private unnamed_addr constant [45 x i8] c"ERROR: Use either 'build' or 'run', not both\00"
@.str.s1062 = private unnamed_addr constant [4 x i8] c"run\00"
@.str.s1063 = private unnamed_addr constant [4 x i8] c"run\00"
@.str.s1064 = private unnamed_addr constant [27 x i8] c"ERROR: Missing source file\00"
@.str.s1065 = private unnamed_addr constant [4 x i8] c"run\00"
@.str.s1066 = private unnamed_addr constant [6 x i8] c"build\00"
@.str.s1067 = private unnamed_addr constant [45 x i8] c"ERROR: Use either 'build' or 'run', not both\00"
@.str.s1068 = private unnamed_addr constant [6 x i8] c"build\00"
@.str.s1069 = private unnamed_addr constant [3 x i8] c"-o\00"
@.str.s1070 = private unnamed_addr constant [34 x i8] c"ERROR: -o requires an output path\00"
@.str.s1071 = private unnamed_addr constant [9 x i8] c"--target\00"
@.str.s1072 = private unnamed_addr constant [47 x i8] c"ERROR: --target requires a value (e.g. wasm32)\00"
@.str.s1073 = private unnamed_addr constant [7 x i8] c"wasm32\00"
@.str.s1074 = private unnamed_addr constant [6 x i8] c"build\00"
@.str.s1075 = private unnamed_addr constant [4 x i8] c"run\00"
@.str.s1076 = private unnamed_addr constant [45 x i8] c"ERROR: Use either 'build' or 'run', not both\00"
@.str.s1077 = private unnamed_addr constant [6 x i8] c"build\00"
@.str.s1078 = private unnamed_addr constant [25 x i8] c"ERROR: Unknown argument \00"

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

declare void @exit(i32)

declare ptr @str_from_char(i8)

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

define ptr @type_to_string__Enum_TokenType(i32 %0) {
entry:
  %t = alloca i32, align 4
  store i32 %0, ptr %t, align 4
  %1 = load i32, ptr %t, align 4
  %2 = icmp eq i32 %1, 0
  br i1 %2, label %label_0, label %label_2

label_2:                                          ; preds = %entry
  %3 = load i32, ptr %t, align 4
  %4 = icmp eq i32 %3, 1
  br i1 %4, label %label_3, label %label_5

label_0:                                          ; preds = %entry
  ret ptr @.str.s0

label_5:                                          ; preds = %label_2
  %5 = load i32, ptr %t, align 4
  %6 = icmp eq i32 %5, 2
  br i1 %6, label %label_6, label %label_8

label_3:                                          ; preds = %label_2
  ret ptr @.str.s1

label_8:                                          ; preds = %label_5
  %7 = load i32, ptr %t, align 4
  %8 = icmp eq i32 %7, 3
  br i1 %8, label %label_9, label %label_11

label_6:                                          ; preds = %label_5
  ret ptr @.str.s2

label_11:                                         ; preds = %label_8
  %9 = load i32, ptr %t, align 4
  %10 = icmp eq i32 %9, 4
  br i1 %10, label %label_12, label %label_14

label_9:                                          ; preds = %label_8
  ret ptr @.str.s3

label_14:                                         ; preds = %label_11
  %11 = load i32, ptr %t, align 4
  %12 = icmp eq i32 %11, 5
  br i1 %12, label %label_15, label %label_17

label_12:                                         ; preds = %label_11
  ret ptr @.str.s4

label_17:                                         ; preds = %label_14
  %13 = load i32, ptr %t, align 4
  %14 = icmp eq i32 %13, 18
  br i1 %14, label %label_18, label %label_20

label_15:                                         ; preds = %label_14
  ret ptr @.str.s5

label_20:                                         ; preds = %label_17
  %15 = load i32, ptr %t, align 4
  %16 = icmp eq i32 %15, 6
  br i1 %16, label %label_21, label %label_23

label_18:                                         ; preds = %label_17
  ret ptr @.str.s6

label_23:                                         ; preds = %label_20
  %17 = load i32, ptr %t, align 4
  %18 = icmp eq i32 %17, 8
  br i1 %18, label %label_24, label %label_26

label_21:                                         ; preds = %label_20
  ret ptr @.str.s7

label_26:                                         ; preds = %label_23
  %19 = load i32, ptr %t, align 4
  %20 = icmp eq i32 %19, 9
  br i1 %20, label %label_27, label %label_29

label_24:                                         ; preds = %label_23
  ret ptr @.str.s8

label_29:                                         ; preds = %label_26
  %21 = load i32, ptr %t, align 4
  %22 = icmp eq i32 %21, 12
  br i1 %22, label %label_30, label %label_32

label_27:                                         ; preds = %label_26
  ret ptr @.str.s9

label_32:                                         ; preds = %label_29
  %23 = load i32, ptr %t, align 4
  %24 = icmp eq i32 %23, 15
  br i1 %24, label %label_33, label %label_35

label_30:                                         ; preds = %label_29
  ret ptr @.str.s10

label_35:                                         ; preds = %label_32
  %25 = load i32, ptr %t, align 4
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
  %c = alloca i8, align 1
  store i8 %0, ptr %c, align 1
  %sc.0 = alloca i1, align 1
  %1 = load i8, ptr %c, align 1
  %2 = icmp sge i8 %1, 48
  store i1 %2, ptr %sc.0, align 1
  br i1 %2, label %label_39, label %label_40

label_40:                                         ; preds = %label_39, %entry
  %3 = load i1, ptr %sc.0, align 1
  ret i1 %3

label_39:                                         ; preds = %entry
  %4 = load i8, ptr %c, align 1
  %5 = icmp sle i8 %4, 57
  store i1 %5, ptr %sc.0, align 1
  br label %label_40
}

define i1 @is_alpha__Char(i8 %0) {
entry:
  %c = alloca i8, align 1
  store i8 %0, ptr %c, align 1
  %sc.1 = alloca i1, align 1
  %sc.2 = alloca i1, align 1
  %sc.3 = alloca i1, align 1
  %1 = load i8, ptr %c, align 1
  %2 = icmp sge i8 %1, 97
  store i1 %2, ptr %sc.3, align 1
  br i1 %2, label %label_45, label %label_46

label_46:                                         ; preds = %label_45, %entry
  %3 = load i1, ptr %sc.3, align 1
  store i1 %3, ptr %sc.2, align 1
  br i1 %3, label %label_44, label %label_43

label_45:                                         ; preds = %entry
  %4 = load i8, ptr %c, align 1
  %5 = icmp sle i8 %4, 122
  store i1 %5, ptr %sc.3, align 1
  br label %label_46

label_43:                                         ; preds = %label_46
  %sc.4 = alloca i1, align 1
  %6 = load i8, ptr %c, align 1
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
  %10 = load i8, ptr %c, align 1
  %11 = icmp sle i8 %10, 90
  store i1 %11, ptr %sc.4, align 1
  br label %label_48

label_41:                                         ; preds = %label_44
  %12 = load i8, ptr %c, align 1
  %13 = icmp eq i8 %12, 95
  store i1 %13, ptr %sc.1, align 1
  br label %label_42

label_42:                                         ; preds = %label_41, %label_44
  %14 = load i1, ptr %sc.1, align 1
  ret i1 %14
}

define i1 @is_alnum__Char(i8 %0) {
entry:
  %c = alloca i8, align 1
  store i8 %0, ptr %c, align 1
  %sc.5 = alloca i1, align 1
  %1 = load i8, ptr %c, align 1
  %2 = call i1 @is_alpha__Char(i8 %1)
  store i1 %2, ptr %sc.5, align 1
  br i1 %2, label %label_50, label %label_49

label_49:                                         ; preds = %entry
  %3 = load i8, ptr %c, align 1
  %4 = call i1 @is_digit__Char(i8 %3)
  store i1 %4, ptr %sc.5, align 1
  br label %label_50

label_50:                                         ; preds = %label_49, %entry
  %5 = load i1, ptr %sc.5, align 1
  ret i1 %5
}

define i1 @is_space__Char(i8 %0) {
entry:
  %c = alloca i8, align 1
  store i8 %0, ptr %c, align 1
  %sc.6 = alloca i1, align 1
  %sc.7 = alloca i1, align 1
  %sc.8 = alloca i1, align 1
  %1 = load i8, ptr %c, align 1
  %2 = icmp eq i8 %1, 32
  store i1 %2, ptr %sc.8, align 1
  br i1 %2, label %label_56, label %label_55

label_55:                                         ; preds = %entry
  %3 = load i8, ptr %c, align 1
  %4 = icmp eq i8 %3, 9
  store i1 %4, ptr %sc.8, align 1
  br label %label_56

label_56:                                         ; preds = %label_55, %entry
  %5 = load i1, ptr %sc.8, align 1
  store i1 %5, ptr %sc.7, align 1
  br i1 %5, label %label_54, label %label_53

label_53:                                         ; preds = %label_56
  %6 = load i8, ptr %c, align 1
  %7 = icmp eq i8 %6, 10
  store i1 %7, ptr %sc.7, align 1
  br label %label_54

label_54:                                         ; preds = %label_53, %label_56
  %8 = load i1, ptr %sc.7, align 1
  store i1 %8, ptr %sc.6, align 1
  br i1 %8, label %label_52, label %label_51

label_51:                                         ; preds = %label_54
  %9 = load i8, ptr %c, align 1
  %10 = icmp eq i8 %9, 13
  store i1 %10, ptr %sc.6, align 1
  br label %label_52

label_52:                                         ; preds = %label_51, %label_54
  %11 = load i1, ptr %sc.6, align 1
  ret i1 %11
}

define i1 @is_separator__Char(i8 %0) {
entry:
  %c = alloca i8, align 1
  store i8 %0, ptr %c, align 1
  %1 = load i8, ptr %c, align 1
  %2 = icmp eq i8 %1, 40
  br i1 %2, label %label_57, label %label_59

label_59:                                         ; preds = %entry
  %3 = load i8, ptr %c, align 1
  %4 = icmp eq i8 %3, 41
  br i1 %4, label %label_60, label %label_62

label_57:                                         ; preds = %entry
  ret i1 true

label_62:                                         ; preds = %label_59
  %5 = load i8, ptr %c, align 1
  %6 = icmp eq i8 %5, 123
  br i1 %6, label %label_63, label %label_65

label_60:                                         ; preds = %label_59
  ret i1 true

label_65:                                         ; preds = %label_62
  %7 = load i8, ptr %c, align 1
  %8 = icmp eq i8 %7, 125
  br i1 %8, label %label_66, label %label_68

label_63:                                         ; preds = %label_62
  ret i1 true

label_68:                                         ; preds = %label_65
  %9 = load i8, ptr %c, align 1
  %10 = icmp eq i8 %9, 91
  br i1 %10, label %label_69, label %label_71

label_66:                                         ; preds = %label_65
  ret i1 true

label_71:                                         ; preds = %label_68
  %11 = load i8, ptr %c, align 1
  %12 = icmp eq i8 %11, 93
  br i1 %12, label %label_72, label %label_74

label_69:                                         ; preds = %label_68
  ret i1 true

label_74:                                         ; preds = %label_71
  %13 = load i8, ptr %c, align 1
  %14 = icmp eq i8 %13, 44
  br i1 %14, label %label_75, label %label_77

label_72:                                         ; preds = %label_71
  ret i1 true

label_77:                                         ; preds = %label_74
  %15 = load i8, ptr %c, align 1
  %16 = icmp eq i8 %15, 46
  br i1 %16, label %label_78, label %label_80

label_75:                                         ; preds = %label_74
  ret i1 true

label_80:                                         ; preds = %label_77
  %17 = load i8, ptr %c, align 1
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
  %c = alloca i8, align 1
  store i8 %0, ptr %c, align 1
  %1 = load i8, ptr %c, align 1
  %2 = icmp eq i8 %1, 43
  br i1 %2, label %label_84, label %label_86

label_86:                                         ; preds = %entry
  %3 = load i8, ptr %c, align 1
  %4 = icmp eq i8 %3, 45
  br i1 %4, label %label_87, label %label_89

label_84:                                         ; preds = %entry
  ret i1 true

label_89:                                         ; preds = %label_86
  %5 = load i8, ptr %c, align 1
  %6 = icmp eq i8 %5, 42
  br i1 %6, label %label_90, label %label_92

label_87:                                         ; preds = %label_86
  ret i1 true

label_92:                                         ; preds = %label_89
  %7 = load i8, ptr %c, align 1
  %8 = icmp eq i8 %7, 47
  br i1 %8, label %label_93, label %label_95

label_90:                                         ; preds = %label_89
  ret i1 true

label_95:                                         ; preds = %label_92
  %9 = load i8, ptr %c, align 1
  %10 = icmp eq i8 %9, 37
  br i1 %10, label %label_96, label %label_98

label_93:                                         ; preds = %label_92
  ret i1 true

label_98:                                         ; preds = %label_95
  %11 = load i8, ptr %c, align 1
  %12 = icmp eq i8 %11, 60
  br i1 %12, label %label_99, label %label_101

label_96:                                         ; preds = %label_95
  ret i1 true

label_101:                                        ; preds = %label_98
  %13 = load i8, ptr %c, align 1
  %14 = icmp eq i8 %13, 62
  br i1 %14, label %label_102, label %label_104

label_99:                                         ; preds = %label_98
  ret i1 true

label_104:                                        ; preds = %label_101
  %15 = load i8, ptr %c, align 1
  %16 = icmp eq i8 %15, 33
  br i1 %16, label %label_105, label %label_107

label_102:                                        ; preds = %label_101
  ret i1 true

label_107:                                        ; preds = %label_104
  %17 = load i8, ptr %c, align 1
  %18 = icmp eq i8 %17, 38
  br i1 %18, label %label_108, label %label_110

label_105:                                        ; preds = %label_104
  ret i1 true

label_110:                                        ; preds = %label_107
  %19 = load i8, ptr %c, align 1
  %20 = icmp eq i8 %19, 124
  br i1 %20, label %label_111, label %label_113

label_108:                                        ; preds = %label_107
  ret i1 true

label_113:                                        ; preds = %label_110
  %21 = load i8, ptr %c, align 1
  %22 = icmp eq i8 %21, 94
  br i1 %22, label %label_114, label %label_116

label_111:                                        ; preds = %label_110
  ret i1 true

label_116:                                        ; preds = %label_113
  %23 = load i8, ptr %c, align 1
  %24 = icmp eq i8 %23, 126
  br i1 %24, label %label_117, label %label_119

label_114:                                        ; preds = %label_113
  ret i1 true

label_119:                                        ; preds = %label_116
  %25 = load i8, ptr %c, align 1
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
  %c = alloca i8, align 1
  store i8 %0, ptr %c, align 1
  %1 = load i8, ptr %c, align 1
  %2 = zext i8 %1 to i32
  ret i32 %2
}

define i1 @is_keyword__String(ptr %0) {
entry:
  %s = alloca ptr, align 8
  store ptr %0, ptr %s, align 8
  %1 = load ptr, ptr %s, align 8
  %2 = call i32 @str_equals(ptr %1, ptr @.str.s14)
  %3 = icmp eq i32 %2, 1
  br i1 %3, label %label_123, label %label_125

label_125:                                        ; preds = %entry
  %4 = load ptr, ptr %s, align 8
  %5 = call i32 @str_equals(ptr %4, ptr @.str.s15)
  %6 = icmp eq i32 %5, 1
  br i1 %6, label %label_126, label %label_128

label_123:                                        ; preds = %entry
  ret i1 true

label_128:                                        ; preds = %label_125
  %7 = load ptr, ptr %s, align 8
  %8 = call i32 @str_equals(ptr %7, ptr @.str.s16)
  %9 = icmp eq i32 %8, 1
  br i1 %9, label %label_129, label %label_131

label_126:                                        ; preds = %label_125
  ret i1 true

label_131:                                        ; preds = %label_128
  %10 = load ptr, ptr %s, align 8
  %11 = call i32 @str_equals(ptr %10, ptr @.str.s17)
  %12 = icmp eq i32 %11, 1
  br i1 %12, label %label_132, label %label_134

label_129:                                        ; preds = %label_128
  ret i1 true

label_134:                                        ; preds = %label_131
  %13 = load ptr, ptr %s, align 8
  %14 = call i32 @str_equals(ptr %13, ptr @.str.s18)
  %15 = icmp eq i32 %14, 1
  br i1 %15, label %label_135, label %label_137

label_132:                                        ; preds = %label_131
  ret i1 true

label_137:                                        ; preds = %label_134
  %16 = load ptr, ptr %s, align 8
  %17 = call i32 @str_equals(ptr %16, ptr @.str.s19)
  %18 = icmp eq i32 %17, 1
  br i1 %18, label %label_138, label %label_140

label_135:                                        ; preds = %label_134
  ret i1 true

label_140:                                        ; preds = %label_137
  %19 = load ptr, ptr %s, align 8
  %20 = call i32 @str_equals(ptr %19, ptr @.str.s20)
  %21 = icmp eq i32 %20, 1
  br i1 %21, label %label_141, label %label_143

label_138:                                        ; preds = %label_137
  ret i1 true

label_143:                                        ; preds = %label_140
  %22 = load ptr, ptr %s, align 8
  %23 = call i32 @str_equals(ptr %22, ptr @.str.s21)
  %24 = icmp eq i32 %23, 1
  br i1 %24, label %label_144, label %label_146

label_141:                                        ; preds = %label_140
  ret i1 true

label_146:                                        ; preds = %label_143
  %25 = load ptr, ptr %s, align 8
  %26 = call i32 @str_equals(ptr %25, ptr @.str.s22)
  %27 = icmp eq i32 %26, 1
  br i1 %27, label %label_147, label %label_149

label_144:                                        ; preds = %label_143
  ret i1 true

label_149:                                        ; preds = %label_146
  %28 = load ptr, ptr %s, align 8
  %29 = call i32 @str_equals(ptr %28, ptr @.str.s23)
  %30 = icmp eq i32 %29, 1
  br i1 %30, label %label_150, label %label_152

label_147:                                        ; preds = %label_146
  ret i1 true

label_152:                                        ; preds = %label_149
  %31 = load ptr, ptr %s, align 8
  %32 = call i32 @str_equals(ptr %31, ptr @.str.s24)
  %33 = icmp eq i32 %32, 1
  br i1 %33, label %label_153, label %label_155

label_150:                                        ; preds = %label_149
  ret i1 true

label_155:                                        ; preds = %label_152
  %34 = load ptr, ptr %s, align 8
  %35 = call i32 @str_equals(ptr %34, ptr @.str.s25)
  %36 = icmp eq i32 %35, 1
  br i1 %36, label %label_156, label %label_158

label_153:                                        ; preds = %label_152
  ret i1 true

label_158:                                        ; preds = %label_155
  %37 = load ptr, ptr %s, align 8
  %38 = call i32 @str_equals(ptr %37, ptr @.str.s26)
  %39 = icmp eq i32 %38, 1
  br i1 %39, label %label_159, label %label_161

label_156:                                        ; preds = %label_155
  ret i1 true

label_161:                                        ; preds = %label_158
  %40 = load ptr, ptr %s, align 8
  %41 = call i32 @str_equals(ptr %40, ptr @.str.s27)
  %42 = icmp eq i32 %41, 1
  br i1 %42, label %label_162, label %label_164

label_159:                                        ; preds = %label_158
  ret i1 true

label_164:                                        ; preds = %label_161
  %43 = load ptr, ptr %s, align 8
  %44 = call i32 @str_equals(ptr %43, ptr @.str.s28)
  %45 = icmp eq i32 %44, 1
  br i1 %45, label %label_165, label %label_167

label_162:                                        ; preds = %label_161
  ret i1 true

label_167:                                        ; preds = %label_164
  %46 = load ptr, ptr %s, align 8
  %47 = call i32 @str_equals(ptr %46, ptr @.str.s29)
  %48 = icmp eq i32 %47, 1
  br i1 %48, label %label_168, label %label_170

label_165:                                        ; preds = %label_164
  ret i1 true

label_170:                                        ; preds = %label_167
  %49 = load ptr, ptr %s, align 8
  %50 = call i32 @str_equals(ptr %49, ptr @.str.s30)
  %51 = icmp eq i32 %50, 1
  br i1 %51, label %label_171, label %label_173

label_168:                                        ; preds = %label_167
  ret i1 true

label_173:                                        ; preds = %label_170
  %52 = load ptr, ptr %s, align 8
  %53 = call i32 @str_equals(ptr %52, ptr @.str.s31)
  %54 = icmp eq i32 %53, 1
  br i1 %54, label %label_174, label %label_176

label_171:                                        ; preds = %label_170
  ret i1 true

label_176:                                        ; preds = %label_173
  %55 = load ptr, ptr %s, align 8
  %56 = call i32 @str_equals(ptr %55, ptr @.str.s32)
  %57 = icmp eq i32 %56, 1
  br i1 %57, label %label_177, label %label_179

label_174:                                        ; preds = %label_173
  ret i1 true

label_179:                                        ; preds = %label_176
  %58 = load ptr, ptr %s, align 8
  %59 = call i32 @str_equals(ptr %58, ptr @.str.s33)
  %60 = icmp eq i32 %59, 1
  br i1 %60, label %label_180, label %label_182

label_177:                                        ; preds = %label_176
  ret i1 true

label_182:                                        ; preds = %label_179
  %61 = load ptr, ptr %s, align 8
  %62 = call i32 @str_equals(ptr %61, ptr @.str.s34)
  %63 = icmp eq i32 %62, 1
  br i1 %63, label %label_183, label %label_185

label_180:                                        ; preds = %label_179
  ret i1 true

label_185:                                        ; preds = %label_182
  %64 = load ptr, ptr %s, align 8
  %65 = call i32 @str_equals(ptr %64, ptr @.str.s35)
  %66 = icmp eq i32 %65, 1
  br i1 %66, label %label_186, label %label_188

label_183:                                        ; preds = %label_182
  ret i1 true

label_188:                                        ; preds = %label_185
  %67 = load ptr, ptr %s, align 8
  %68 = call i32 @str_equals(ptr %67, ptr @.str.s36)
  %69 = icmp eq i32 %68, 1
  br i1 %69, label %label_189, label %label_191

label_186:                                        ; preds = %label_185
  ret i1 true

label_191:                                        ; preds = %label_188
  %70 = load ptr, ptr %s, align 8
  %71 = call i32 @str_equals(ptr %70, ptr @.str.s37)
  %72 = icmp eq i32 %71, 1
  br i1 %72, label %label_192, label %label_194

label_189:                                        ; preds = %label_188
  ret i1 true

label_194:                                        ; preds = %label_191
  %73 = load ptr, ptr %s, align 8
  %74 = call i32 @str_equals(ptr %73, ptr @.str.s38)
  %75 = icmp eq i32 %74, 1
  br i1 %75, label %label_195, label %label_197

label_192:                                        ; preds = %label_191
  ret i1 true

label_197:                                        ; preds = %label_194
  %76 = load ptr, ptr %s, align 8
  %77 = call i32 @str_equals(ptr %76, ptr @.str.s39)
  %78 = icmp eq i32 %77, 1
  br i1 %78, label %label_198, label %label_200

label_195:                                        ; preds = %label_194
  ret i1 true

label_200:                                        ; preds = %label_197
  %79 = load ptr, ptr %s, align 8
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
  %s = alloca ptr, align 8
  store ptr %0, ptr %s, align 8
  %1 = load ptr, ptr %s, align 8
  %2 = call i32 @str_equals(ptr %1, ptr @.str.s41)
  %3 = icmp eq i32 %2, 1
  br i1 %3, label %label_204, label %label_206

label_206:                                        ; preds = %entry
  %4 = load ptr, ptr %s, align 8
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

define ptr @create_lexer__String(ptr %0) {
entry:
  %input = alloca ptr, align 8
  store ptr %0, ptr %input, align 8
  %1 = call ptr @malloc(i64 ptrtoint (ptr getelementptr (%Lexer, ptr null, i32 1) to i64))
  %2 = load ptr, ptr %input, align 8
  %3 = getelementptr inbounds nuw %Lexer, ptr %1, i32 0, i32 0
  store ptr %2, ptr %3, align 8
  %4 = getelementptr inbounds nuw %Lexer, ptr %1, i32 0, i32 1
  store i32 0, ptr %4, align 4
  %5 = getelementptr inbounds nuw %Lexer, ptr %1, i32 0, i32 2
  store i32 1, ptr %5, align 4
  %6 = getelementptr inbounds nuw %Lexer, ptr %1, i32 0, i32 3
  store i32 1, ptr %6, align 4
  ret ptr %1
}

define i8 @lexer_peek__Struct_Lexer_Int(ptr %0, i32 %1) {
entry:
  %lex = alloca ptr, align 8
  store ptr %0, ptr %lex, align 8
  %offset = alloca i32, align 4
  store i32 %1, ptr %offset, align 4
  %2 = load ptr, ptr %lex, align 8
  %3 = getelementptr inbounds nuw %Lexer, ptr %2, i32 0, i32 0
  %4 = load ptr, ptr %3, align 8
  %5 = load ptr, ptr %lex, align 8
  %6 = getelementptr inbounds nuw %Lexer, ptr %5, i32 0, i32 1
  %7 = load i32, ptr %6, align 4
  %8 = load i32, ptr %offset, align 4
  %9 = add i32 %7, %8
  %10 = call i8 @str_char_at(ptr %4, i32 %9)
  ret i8 %10
}

define i8 @lexer_current__Struct_Lexer(ptr %0) {
entry:
  %lex = alloca ptr, align 8
  store ptr %0, ptr %lex, align 8
  %1 = load ptr, ptr %lex, align 8
  %2 = getelementptr inbounds nuw %Lexer, ptr %1, i32 0, i32 0
  %3 = load ptr, ptr %2, align 8
  %4 = load ptr, ptr %lex, align 8
  %5 = getelementptr inbounds nuw %Lexer, ptr %4, i32 0, i32 1
  %6 = load i32, ptr %5, align 4
  %7 = call i8 @str_char_at(ptr %3, i32 %6)
  ret i8 %7
}

define void @lexer_advance__Struct_Lexer(ptr %0) {
entry:
  %lex = alloca ptr, align 8
  store ptr %0, ptr %lex, align 8
  %1 = load ptr, ptr %lex, align 8
  %2 = load ptr, ptr %lex, align 8
  %3 = getelementptr inbounds nuw %Lexer, ptr %2, i32 0, i32 1
  %4 = load i32, ptr %3, align 4
  %5 = add i32 %4, 1
  %6 = getelementptr inbounds nuw %Lexer, ptr %1, i32 0, i32 1
  store i32 %5, ptr %6, align 4
  %7 = load ptr, ptr %lex, align 8
  %8 = load ptr, ptr %lex, align 8
  %9 = getelementptr inbounds nuw %Lexer, ptr %8, i32 0, i32 3
  %10 = load i32, ptr %9, align 4
  %11 = add i32 %10, 1
  %12 = getelementptr inbounds nuw %Lexer, ptr %7, i32 0, i32 3
  store i32 %11, ptr %12, align 4
  ret void
}

define void @lexer_skip_whitespace__Struct_Lexer(ptr %0) {
entry:
  %lex = alloca ptr, align 8
  store ptr %0, ptr %lex, align 8
  %is_looping = alloca i1, align 1
  store i1 true, ptr %is_looping, align 1
  br label %label_210

label_210:                                        ; preds = %label_215, %entry
  %1 = load i1, ptr %is_looping, align 1
  br i1 %1, label %label_211, label %label_212

label_212:                                        ; preds = %label_210
  ret void

label_211:                                        ; preds = %label_210
  %2 = load ptr, ptr %lex, align 8
  %3 = call i8 @lexer_current__Struct_Lexer(ptr %2)
  %4 = call i1 @is_space__Char(i8 %3)
  br i1 %4, label %label_213, label %label_214

label_214:                                        ; preds = %label_211
  %sc.9 = alloca i1, align 1
  %5 = load ptr, ptr %lex, align 8
  %6 = call i8 @lexer_current__Struct_Lexer(ptr %5)
  %7 = icmp eq i8 %6, 47
  store i1 %7, ptr %sc.9, align 1
  br i1 %7, label %label_219, label %label_220

label_213:                                        ; preds = %label_211
  %8 = load ptr, ptr %lex, align 8
  %9 = call i8 @lexer_current__Struct_Lexer(ptr %8)
  %10 = icmp eq i8 %9, 10
  br i1 %10, label %label_216, label %label_218

label_218:                                        ; preds = %label_216, %label_213
  %11 = load ptr, ptr %lex, align 8
  call void @lexer_advance__Struct_Lexer(ptr %11)
  br label %label_215

label_216:                                        ; preds = %label_213
  %12 = load ptr, ptr %lex, align 8
  %13 = load ptr, ptr %lex, align 8
  %14 = getelementptr inbounds nuw %Lexer, ptr %13, i32 0, i32 2
  %15 = load i32, ptr %14, align 4
  %16 = add i32 %15, 1
  %17 = getelementptr inbounds nuw %Lexer, ptr %12, i32 0, i32 2
  store i32 %16, ptr %17, align 4
  %18 = load ptr, ptr %lex, align 8
  %19 = getelementptr inbounds nuw %Lexer, ptr %18, i32 0, i32 3
  store i32 0, ptr %19, align 4
  br label %label_218

label_215:                                        ; preds = %label_223, %label_218
  br label %label_210

label_220:                                        ; preds = %label_219, %label_214
  %20 = load i1, ptr %sc.9, align 1
  br i1 %20, label %label_221, label %label_222

label_219:                                        ; preds = %label_214
  %21 = load ptr, ptr %lex, align 8
  %22 = call i8 @lexer_peek__Struct_Lexer_Int(ptr %21, i32 1)
  %23 = icmp eq i8 %22, 47
  store i1 %23, ptr %sc.9, align 1
  br label %label_220

label_222:                                        ; preds = %label_220
  store i1 false, ptr %is_looping, align 1
  br label %label_223

label_221:                                        ; preds = %label_220
  br label %label_224

label_224:                                        ; preds = %label_225, %label_221
  %sc.10 = alloca i1, align 1
  %24 = load ptr, ptr %lex, align 8
  %25 = call i8 @lexer_current__Struct_Lexer(ptr %24)
  %26 = icmp ne i8 %25, 10
  store i1 %26, ptr %sc.10, align 1
  br i1 %26, label %label_227, label %label_228

label_228:                                        ; preds = %label_227, %label_224
  %27 = load i1, ptr %sc.10, align 1
  br i1 %27, label %label_225, label %label_226

label_227:                                        ; preds = %label_224
  %28 = load ptr, ptr %lex, align 8
  %29 = call i8 @lexer_current__Struct_Lexer(ptr %28)
  %30 = icmp ne i8 %29, 0
  store i1 %30, ptr %sc.10, align 1
  br label %label_228

label_226:                                        ; preds = %label_228
  br label %label_223

label_225:                                        ; preds = %label_228
  %31 = load ptr, ptr %lex, align 8
  call void @lexer_advance__Struct_Lexer(ptr %31)
  br label %label_224

label_223:                                        ; preds = %label_222, %label_226
  br label %label_215
}

define ptr @lexer_decode_escapes__String_Int(ptr %0, i32 %1) {
entry:
  %raw = alloca ptr, align 8
  store ptr %0, ptr %raw, align 8
  %line = alloca i32, align 4
  store i32 %1, ptr %line, align 4
  %out = alloca ptr, align 8
  %i = alloca i32, align 4
  %n = alloca i32, align 4
  %ch = alloca i8, align 1
  %esc = alloca i8, align 1
  %decoded = alloca i8, align 1
  %known = alloca i1, align 1
  store ptr @.str.s43, ptr %out, align 8
  store i32 0, ptr %i, align 4
  %2 = load ptr, ptr %raw, align 8
  %3 = call i32 @str_length(ptr %2)
  store i32 %3, ptr %n, align 4
  br label %label_229

label_229:                                        ; preds = %label_236, %entry
  %4 = load i32, ptr %i, align 4
  %5 = load i32, ptr %n, align 4
  %6 = icmp slt i32 %4, %5
  br i1 %6, label %label_230, label %label_231

label_231:                                        ; preds = %label_229
  %7 = load ptr, ptr %out, align 8
  ret ptr %7

label_230:                                        ; preds = %label_229
  %8 = load ptr, ptr %raw, align 8
  %9 = load i32, ptr %i, align 4
  %10 = call i8 @str_char_at(ptr %8, i32 %9)
  store i8 %10, ptr %ch, align 1
  %sc.11 = alloca i1, align 1
  %11 = load i8, ptr %ch, align 1
  %12 = icmp eq i8 %11, 92
  store i1 %12, ptr %sc.11, align 1
  br i1 %12, label %label_232, label %label_233

label_233:                                        ; preds = %label_232, %label_230
  %13 = load i1, ptr %sc.11, align 1
  br i1 %13, label %label_234, label %label_235

label_232:                                        ; preds = %label_230
  %14 = load i32, ptr %i, align 4
  %15 = add i32 %14, 1
  %16 = load i32, ptr %n, align 4
  %17 = icmp slt i32 %15, %16
  store i1 %17, ptr %sc.11, align 1
  br label %label_233

label_235:                                        ; preds = %label_233
  %18 = load ptr, ptr %out, align 8
  %19 = load i8, ptr %ch, align 1
  %20 = call ptr @str_from_char(i8 %19)
  %21 = call ptr @str_concat(ptr %18, ptr %20)
  store ptr %21, ptr %out, align 8
  %22 = load i32, ptr %i, align 4
  %23 = add i32 %22, 1
  store i32 %23, ptr %i, align 4
  br label %label_236

label_234:                                        ; preds = %label_233
  %24 = load ptr, ptr %raw, align 8
  %25 = load i32, ptr %i, align 4
  %26 = add i32 %25, 1
  %27 = call i8 @str_char_at(ptr %24, i32 %26)
  store i8 %27, ptr %esc, align 1
  %28 = load i8, ptr %esc, align 1
  store i8 %28, ptr %decoded, align 1
  store i1 true, ptr %known, align 1
  %29 = load i8, ptr %esc, align 1
  %30 = icmp eq i8 %29, 110
  br i1 %30, label %label_237, label %label_238

label_238:                                        ; preds = %label_234
  %31 = load i8, ptr %esc, align 1
  %32 = icmp eq i8 %31, 116
  br i1 %32, label %label_240, label %label_241

label_237:                                        ; preds = %label_234
  store i8 10, ptr %decoded, align 1
  br label %label_239

label_239:                                        ; preds = %label_242, %label_237
  %33 = load i1, ptr %known, align 1
  %34 = icmp eq i1 %33, false
  br i1 %34, label %label_258, label %label_260

label_241:                                        ; preds = %label_238
  %35 = load i8, ptr %esc, align 1
  %36 = icmp eq i8 %35, 114
  br i1 %36, label %label_243, label %label_244

label_240:                                        ; preds = %label_238
  store i8 9, ptr %decoded, align 1
  br label %label_242

label_242:                                        ; preds = %label_245, %label_240
  br label %label_239

label_244:                                        ; preds = %label_241
  %37 = load i8, ptr %esc, align 1
  %38 = icmp eq i8 %37, 92
  br i1 %38, label %label_246, label %label_247

label_243:                                        ; preds = %label_241
  store i8 13, ptr %decoded, align 1
  br label %label_245

label_245:                                        ; preds = %label_248, %label_243
  br label %label_242

label_247:                                        ; preds = %label_244
  %39 = load i8, ptr %esc, align 1
  %40 = icmp eq i8 %39, 34
  br i1 %40, label %label_249, label %label_250

label_246:                                        ; preds = %label_244
  store i8 92, ptr %decoded, align 1
  br label %label_248

label_248:                                        ; preds = %label_251, %label_246
  br label %label_245

label_250:                                        ; preds = %label_247
  %41 = load i8, ptr %esc, align 1
  %42 = icmp eq i8 %41, 39
  br i1 %42, label %label_252, label %label_253

label_249:                                        ; preds = %label_247
  store i8 34, ptr %decoded, align 1
  br label %label_251

label_251:                                        ; preds = %label_254, %label_249
  br label %label_248

label_253:                                        ; preds = %label_250
  %43 = load i8, ptr %esc, align 1
  %44 = icmp eq i8 %43, 48
  br i1 %44, label %label_255, label %label_256

label_252:                                        ; preds = %label_250
  store i8 39, ptr %decoded, align 1
  br label %label_254

label_254:                                        ; preds = %label_257, %label_252
  br label %label_251

label_256:                                        ; preds = %label_253
  store i1 false, ptr %known, align 1
  br label %label_257

label_255:                                        ; preds = %label_253
  call void @print(ptr @.str.s44)
  %45 = load i32, ptr %line, align 4
  call void @print_int(i32 %45)
  call void @println(ptr @.str.s45)
  call void @exit(i32 1)
  br label %label_257

label_257:                                        ; preds = %label_256, %label_255
  br label %label_254

label_260:                                        ; preds = %label_258, %label_239
  %46 = load ptr, ptr %out, align 8
  %47 = load i8, ptr %decoded, align 1
  %48 = call ptr @str_from_char(i8 %47)
  %49 = call ptr @str_concat(ptr %46, ptr %48)
  store ptr %49, ptr %out, align 8
  %50 = load i32, ptr %i, align 4
  %51 = add i32 %50, 2
  store i32 %51, ptr %i, align 4
  br label %label_236

label_258:                                        ; preds = %label_239
  call void @print(ptr @.str.s46)
  %52 = load i32, ptr %line, align 4
  call void @print_int(i32 %52)
  call void @print(ptr @.str.s47)
  call void @print_char(i8 92)
  %53 = load i8, ptr %esc, align 1
  call void @println_char(i8 %53)
  call void @exit(i32 1)
  br label %label_260

label_236:                                        ; preds = %label_235, %label_260
  br label %label_229
}

define ptr @lexer_next_token__Struct_Lexer(ptr %0) {
entry:
  %lex = alloca ptr, align 8
  store ptr %0, ptr %lex, align 8
  %c = alloca i8, align 1
  %start = alloca i32, align 4
  %length = alloca i32, align 4
  %value = alloca ptr, align 8
  %is_float = alloca i32, align 4
  %has_escape = alloca i1, align 1
  %raw = alloca ptr, align 8
  %value_char = alloca i8, align 1
  %esc = alloca i8, align 1
  %next = alloca i8, align 1
  %type = alloca i32, align 4
  %val = alloca ptr, align 8
  %1 = load ptr, ptr %lex, align 8
  call void @lexer_skip_whitespace__Struct_Lexer(ptr %1)
  %2 = load ptr, ptr %lex, align 8
  %3 = getelementptr inbounds nuw %Lexer, ptr %2, i32 0, i32 1
  %4 = load i32, ptr %3, align 4
  %5 = load ptr, ptr %lex, align 8
  %6 = getelementptr inbounds nuw %Lexer, ptr %5, i32 0, i32 0
  %7 = load ptr, ptr %6, align 8
  %8 = call i32 @str_length(ptr %7)
  %9 = icmp sge i32 %4, %8
  br i1 %9, label %label_261, label %label_263

label_263:                                        ; preds = %entry
  %10 = load ptr, ptr %lex, align 8
  %11 = call i8 @lexer_current__Struct_Lexer(ptr %10)
  store i8 %11, ptr %c, align 1
  %12 = load i8, ptr %c, align 1
  %13 = call i1 @is_alpha__Char(i8 %12)
  br i1 %13, label %label_264, label %label_266

label_261:                                        ; preds = %entry
  %14 = call ptr @malloc(i64 ptrtoint (ptr getelementptr (%Token, ptr null, i32 1) to i64))
  %15 = getelementptr inbounds nuw %Token, ptr %14, i32 0, i32 0
  store i32 20, ptr %15, align 4
  %16 = getelementptr inbounds nuw %Token, ptr %14, i32 0, i32 1
  store ptr @.str.s48, ptr %16, align 8
  %17 = load ptr, ptr %lex, align 8
  %18 = getelementptr inbounds nuw %Lexer, ptr %17, i32 0, i32 2
  %19 = load i32, ptr %18, align 4
  %20 = getelementptr inbounds nuw %Token, ptr %14, i32 0, i32 2
  store i32 %19, ptr %20, align 4
  %21 = getelementptr inbounds nuw %Token, ptr %14, i32 0, i32 3
  store ptr @.str.s49, ptr %21, align 8
  ret ptr %14

label_266:                                        ; preds = %label_263
  %22 = load i8, ptr %c, align 1
  %23 = call i1 @is_digit__Char(i8 %22)
  br i1 %23, label %label_276, label %label_278

label_264:                                        ; preds = %label_263
  %24 = load ptr, ptr %lex, align 8
  %25 = getelementptr inbounds nuw %Lexer, ptr %24, i32 0, i32 1
  %26 = load i32, ptr %25, align 4
  store i32 %26, ptr %start, align 4
  br label %label_267

label_267:                                        ; preds = %label_268, %label_264
  %27 = load ptr, ptr %lex, align 8
  %28 = call i8 @lexer_current__Struct_Lexer(ptr %27)
  %29 = call i1 @is_alnum__Char(i8 %28)
  br i1 %29, label %label_268, label %label_269

label_269:                                        ; preds = %label_267
  %30 = load ptr, ptr %lex, align 8
  %31 = getelementptr inbounds nuw %Lexer, ptr %30, i32 0, i32 1
  %32 = load i32, ptr %31, align 4
  %33 = load i32, ptr %start, align 4
  %34 = sub i32 %32, %33
  store i32 %34, ptr %length, align 4
  %35 = load ptr, ptr %lex, align 8
  %36 = getelementptr inbounds nuw %Lexer, ptr %35, i32 0, i32 0
  %37 = load ptr, ptr %36, align 8
  %38 = load i32, ptr %start, align 4
  %39 = load i32, ptr %length, align 4
  %40 = call ptr @str_substring(ptr %37, i32 %38, i32 %39)
  store ptr %40, ptr %value, align 8
  %41 = load ptr, ptr %value, align 8
  %42 = call i1 @is_keyword__String(ptr %41)
  br i1 %42, label %label_270, label %label_272

label_268:                                        ; preds = %label_267
  %43 = load ptr, ptr %lex, align 8
  call void @lexer_advance__Struct_Lexer(ptr %43)
  br label %label_267

label_272:                                        ; preds = %label_269
  %44 = call ptr @malloc(i64 ptrtoint (ptr getelementptr (%Token, ptr null, i32 1) to i64))
  %45 = getelementptr inbounds nuw %Token, ptr %44, i32 0, i32 0
  store i32 5, ptr %45, align 4
  %46 = load ptr, ptr %value, align 8
  %47 = getelementptr inbounds nuw %Token, ptr %44, i32 0, i32 1
  store ptr %46, ptr %47, align 8
  %48 = load ptr, ptr %lex, align 8
  %49 = getelementptr inbounds nuw %Lexer, ptr %48, i32 0, i32 2
  %50 = load i32, ptr %49, align 4
  %51 = getelementptr inbounds nuw %Token, ptr %44, i32 0, i32 2
  store i32 %50, ptr %51, align 4
  %52 = getelementptr inbounds nuw %Token, ptr %44, i32 0, i32 3
  store ptr @.str.s52, ptr %52, align 8
  ret ptr %44

label_270:                                        ; preds = %label_269
  %53 = load ptr, ptr %value, align 8
  %54 = call i1 @is_boolean__String(ptr %53)
  br i1 %54, label %label_273, label %label_275

label_275:                                        ; preds = %label_270
  %55 = call ptr @malloc(i64 ptrtoint (ptr getelementptr (%Token, ptr null, i32 1) to i64))
  %56 = getelementptr inbounds nuw %Token, ptr %55, i32 0, i32 0
  store i32 18, ptr %56, align 4
  %57 = load ptr, ptr %value, align 8
  %58 = getelementptr inbounds nuw %Token, ptr %55, i32 0, i32 1
  store ptr %57, ptr %58, align 8
  %59 = load ptr, ptr %lex, align 8
  %60 = getelementptr inbounds nuw %Lexer, ptr %59, i32 0, i32 2
  %61 = load i32, ptr %60, align 4
  %62 = getelementptr inbounds nuw %Token, ptr %55, i32 0, i32 2
  store i32 %61, ptr %62, align 4
  %63 = getelementptr inbounds nuw %Token, ptr %55, i32 0, i32 3
  store ptr @.str.s51, ptr %63, align 8
  ret ptr %55

label_273:                                        ; preds = %label_270
  %64 = call ptr @malloc(i64 ptrtoint (ptr getelementptr (%Token, ptr null, i32 1) to i64))
  %65 = getelementptr inbounds nuw %Token, ptr %64, i32 0, i32 0
  store i32 4, ptr %65, align 4
  %66 = load ptr, ptr %value, align 8
  %67 = getelementptr inbounds nuw %Token, ptr %64, i32 0, i32 1
  store ptr %66, ptr %67, align 8
  %68 = load ptr, ptr %lex, align 8
  %69 = getelementptr inbounds nuw %Lexer, ptr %68, i32 0, i32 2
  %70 = load i32, ptr %69, align 4
  %71 = getelementptr inbounds nuw %Token, ptr %64, i32 0, i32 2
  store i32 %70, ptr %71, align 4
  %72 = getelementptr inbounds nuw %Token, ptr %64, i32 0, i32 3
  store ptr @.str.s50, ptr %72, align 8
  ret ptr %64

label_278:                                        ; preds = %label_266
  %73 = load i8, ptr %c, align 1
  %74 = icmp eq i8 %73, 34
  br i1 %74, label %label_293, label %label_295

label_276:                                        ; preds = %label_266
  %75 = load ptr, ptr %lex, align 8
  %76 = getelementptr inbounds nuw %Lexer, ptr %75, i32 0, i32 1
  %77 = load i32, ptr %76, align 4
  store i32 %77, ptr %start, align 4
  store i32 0, ptr %is_float, align 4
  br label %label_279

label_279:                                        ; preds = %label_280, %label_276
  %78 = load ptr, ptr %lex, align 8
  %79 = call i8 @lexer_current__Struct_Lexer(ptr %78)
  %80 = call i1 @is_digit__Char(i8 %79)
  br i1 %80, label %label_280, label %label_281

label_281:                                        ; preds = %label_279
  %sc.12 = alloca i1, align 1
  %81 = load ptr, ptr %lex, align 8
  %82 = call i8 @lexer_current__Struct_Lexer(ptr %81)
  %83 = icmp eq i8 %82, 46
  store i1 %83, ptr %sc.12, align 1
  br i1 %83, label %label_282, label %label_283

label_280:                                        ; preds = %label_279
  %84 = load ptr, ptr %lex, align 8
  call void @lexer_advance__Struct_Lexer(ptr %84)
  br label %label_279

label_283:                                        ; preds = %label_282, %label_281
  %85 = load i1, ptr %sc.12, align 1
  br i1 %85, label %label_284, label %label_286

label_282:                                        ; preds = %label_281
  %86 = load ptr, ptr %lex, align 8
  %87 = call i8 @lexer_peek__Struct_Lexer_Int(ptr %86, i32 1)
  %88 = call i1 @is_digit__Char(i8 %87)
  store i1 %88, ptr %sc.12, align 1
  br label %label_283

label_286:                                        ; preds = %label_289, %label_283
  %89 = load ptr, ptr %lex, align 8
  %90 = getelementptr inbounds nuw %Lexer, ptr %89, i32 0, i32 1
  %91 = load i32, ptr %90, align 4
  %92 = load i32, ptr %start, align 4
  %93 = sub i32 %91, %92
  store i32 %93, ptr %length, align 4
  %94 = load ptr, ptr %lex, align 8
  %95 = getelementptr inbounds nuw %Lexer, ptr %94, i32 0, i32 0
  %96 = load ptr, ptr %95, align 8
  %97 = load i32, ptr %start, align 4
  %98 = load i32, ptr %length, align 4
  %99 = call ptr @str_substring(ptr %96, i32 %97, i32 %98)
  store ptr %99, ptr %value, align 8
  %100 = load i32, ptr %is_float, align 4
  %101 = icmp eq i32 %100, 1
  br i1 %101, label %label_290, label %label_292

label_284:                                        ; preds = %label_283
  store i32 1, ptr %is_float, align 4
  %102 = load ptr, ptr %lex, align 8
  call void @lexer_advance__Struct_Lexer(ptr %102)
  br label %label_287

label_287:                                        ; preds = %label_288, %label_284
  %103 = load ptr, ptr %lex, align 8
  %104 = call i8 @lexer_current__Struct_Lexer(ptr %103)
  %105 = call i1 @is_digit__Char(i8 %104)
  br i1 %105, label %label_288, label %label_289

label_289:                                        ; preds = %label_287
  br label %label_286

label_288:                                        ; preds = %label_287
  %106 = load ptr, ptr %lex, align 8
  call void @lexer_advance__Struct_Lexer(ptr %106)
  br label %label_287

label_292:                                        ; preds = %label_286
  %107 = call ptr @malloc(i64 ptrtoint (ptr getelementptr (%Token, ptr null, i32 1) to i64))
  %108 = getelementptr inbounds nuw %Token, ptr %107, i32 0, i32 0
  store i32 2, ptr %108, align 4
  %109 = load ptr, ptr %value, align 8
  %110 = getelementptr inbounds nuw %Token, ptr %107, i32 0, i32 1
  store ptr %109, ptr %110, align 8
  %111 = load ptr, ptr %lex, align 8
  %112 = getelementptr inbounds nuw %Lexer, ptr %111, i32 0, i32 2
  %113 = load i32, ptr %112, align 4
  %114 = getelementptr inbounds nuw %Token, ptr %107, i32 0, i32 2
  store i32 %113, ptr %114, align 4
  %115 = getelementptr inbounds nuw %Token, ptr %107, i32 0, i32 3
  store ptr @.str.s54, ptr %115, align 8
  ret ptr %107

label_290:                                        ; preds = %label_286
  %116 = call ptr @malloc(i64 ptrtoint (ptr getelementptr (%Token, ptr null, i32 1) to i64))
  %117 = getelementptr inbounds nuw %Token, ptr %116, i32 0, i32 0
  store i32 3, ptr %117, align 4
  %118 = load ptr, ptr %value, align 8
  %119 = getelementptr inbounds nuw %Token, ptr %116, i32 0, i32 1
  store ptr %118, ptr %119, align 8
  %120 = load ptr, ptr %lex, align 8
  %121 = getelementptr inbounds nuw %Lexer, ptr %120, i32 0, i32 2
  %122 = load i32, ptr %121, align 4
  %123 = getelementptr inbounds nuw %Token, ptr %116, i32 0, i32 2
  store i32 %122, ptr %123, align 4
  %124 = getelementptr inbounds nuw %Token, ptr %116, i32 0, i32 3
  store ptr @.str.s53, ptr %124, align 8
  ret ptr %116

label_295:                                        ; preds = %label_278
  %125 = load i8, ptr %c, align 1
  %126 = icmp eq i8 %125, 39
  br i1 %126, label %label_310, label %label_312

label_293:                                        ; preds = %label_278
  %127 = load ptr, ptr %lex, align 8
  call void @lexer_advance__Struct_Lexer(ptr %127)
  %128 = load ptr, ptr %lex, align 8
  %129 = getelementptr inbounds nuw %Lexer, ptr %128, i32 0, i32 1
  %130 = load i32, ptr %129, align 4
  store i32 %130, ptr %start, align 4
  store i1 false, ptr %has_escape, align 1
  br label %label_296

label_296:                                        ; preds = %label_303, %label_293
  %sc.13 = alloca i1, align 1
  %131 = load ptr, ptr %lex, align 8
  %132 = call i8 @lexer_current__Struct_Lexer(ptr %131)
  %133 = icmp ne i8 %132, 34
  store i1 %133, ptr %sc.13, align 1
  br i1 %133, label %label_299, label %label_300

label_300:                                        ; preds = %label_299, %label_296
  %134 = load i1, ptr %sc.13, align 1
  br i1 %134, label %label_297, label %label_298

label_299:                                        ; preds = %label_296
  %135 = load ptr, ptr %lex, align 8
  %136 = getelementptr inbounds nuw %Lexer, ptr %135, i32 0, i32 1
  %137 = load i32, ptr %136, align 4
  %138 = load ptr, ptr %lex, align 8
  %139 = getelementptr inbounds nuw %Lexer, ptr %138, i32 0, i32 0
  %140 = load ptr, ptr %139, align 8
  %141 = call i32 @str_length(ptr %140)
  %142 = icmp slt i32 %137, %141
  store i1 %142, ptr %sc.13, align 1
  br label %label_300

label_298:                                        ; preds = %label_300
  %143 = load ptr, ptr %lex, align 8
  %144 = getelementptr inbounds nuw %Lexer, ptr %143, i32 0, i32 1
  %145 = load i32, ptr %144, align 4
  %146 = load i32, ptr %start, align 4
  %147 = sub i32 %145, %146
  store i32 %147, ptr %length, align 4
  %148 = load ptr, ptr %lex, align 8
  %149 = getelementptr inbounds nuw %Lexer, ptr %148, i32 0, i32 0
  %150 = load ptr, ptr %149, align 8
  %151 = load i32, ptr %start, align 4
  %152 = load i32, ptr %length, align 4
  %153 = call ptr @str_substring(ptr %150, i32 %151, i32 %152)
  store ptr %153, ptr %raw, align 8
  %154 = load ptr, ptr %lex, align 8
  %155 = call i8 @lexer_current__Struct_Lexer(ptr %154)
  %156 = icmp eq i8 %155, 34
  br i1 %156, label %label_304, label %label_305

label_297:                                        ; preds = %label_300
  %157 = load ptr, ptr %lex, align 8
  %158 = call i8 @lexer_current__Struct_Lexer(ptr %157)
  %159 = icmp eq i8 %158, 92
  br i1 %159, label %label_301, label %label_303

label_303:                                        ; preds = %label_301, %label_297
  %160 = load ptr, ptr %lex, align 8
  call void @lexer_advance__Struct_Lexer(ptr %160)
  br label %label_296

label_301:                                        ; preds = %label_297
  store i1 true, ptr %has_escape, align 1
  %161 = load ptr, ptr %lex, align 8
  call void @lexer_advance__Struct_Lexer(ptr %161)
  br label %label_303

label_305:                                        ; preds = %label_298
  call void @print(ptr @.str.s55)
  %162 = load ptr, ptr %lex, align 8
  %163 = getelementptr inbounds nuw %Lexer, ptr %162, i32 0, i32 2
  %164 = load i32, ptr %163, align 4
  call void @print_int(i32 %164)
  call void @println(ptr @.str.s56)
  call void @exit(i32 1)
  br label %label_306

label_304:                                        ; preds = %label_298
  %165 = load ptr, ptr %lex, align 8
  call void @lexer_advance__Struct_Lexer(ptr %165)
  br label %label_306

label_306:                                        ; preds = %label_305, %label_304
  %166 = load ptr, ptr %raw, align 8
  store ptr %166, ptr %value, align 8
  %167 = load i1, ptr %has_escape, align 1
  br i1 %167, label %label_307, label %label_309

label_309:                                        ; preds = %label_307, %label_306
  %168 = call ptr @malloc(i64 ptrtoint (ptr getelementptr (%Token, ptr null, i32 1) to i64))
  %169 = getelementptr inbounds nuw %Token, ptr %168, i32 0, i32 0
  store i32 0, ptr %169, align 4
  %170 = load ptr, ptr %value, align 8
  %171 = getelementptr inbounds nuw %Token, ptr %168, i32 0, i32 1
  store ptr %170, ptr %171, align 8
  %172 = load ptr, ptr %lex, align 8
  %173 = getelementptr inbounds nuw %Lexer, ptr %172, i32 0, i32 2
  %174 = load i32, ptr %173, align 4
  %175 = getelementptr inbounds nuw %Token, ptr %168, i32 0, i32 2
  store i32 %174, ptr %175, align 4
  %176 = getelementptr inbounds nuw %Token, ptr %168, i32 0, i32 3
  store ptr @.str.s57, ptr %176, align 8
  ret ptr %168

label_307:                                        ; preds = %label_306
  %177 = load ptr, ptr %raw, align 8
  %178 = load ptr, ptr %lex, align 8
  %179 = getelementptr inbounds nuw %Lexer, ptr %178, i32 0, i32 2
  %180 = load i32, ptr %179, align 4
  %181 = call ptr @lexer_decode_escapes__String_Int(ptr %177, i32 %180)
  store ptr %181, ptr %value, align 8
  br label %label_309

label_312:                                        ; preds = %label_295
  %182 = load i8, ptr %c, align 1
  %183 = call i1 @is_operator__Char(i8 %182)
  br i1 %183, label %label_340, label %label_342

label_310:                                        ; preds = %label_295
  %184 = load ptr, ptr %lex, align 8
  call void @lexer_advance__Struct_Lexer(ptr %184)
  %185 = load ptr, ptr %lex, align 8
  %186 = call i8 @lexer_current__Struct_Lexer(ptr %185)
  store i8 %186, ptr %value_char, align 1
  %187 = load i8, ptr %value_char, align 1
  %188 = icmp eq i8 %187, 92
  br i1 %188, label %label_313, label %label_315

label_315:                                        ; preds = %label_336, %label_310
  %189 = load ptr, ptr %lex, align 8
  call void @lexer_advance__Struct_Lexer(ptr %189)
  %190 = load ptr, ptr %lex, align 8
  %191 = call i8 @lexer_current__Struct_Lexer(ptr %190)
  %192 = icmp eq i8 %191, 39
  br i1 %192, label %label_337, label %label_339

label_313:                                        ; preds = %label_310
  %193 = load ptr, ptr %lex, align 8
  call void @lexer_advance__Struct_Lexer(ptr %193)
  %194 = load ptr, ptr %lex, align 8
  %195 = call i8 @lexer_current__Struct_Lexer(ptr %194)
  store i8 %195, ptr %esc, align 1
  %196 = load i8, ptr %esc, align 1
  %197 = icmp eq i8 %196, 110
  br i1 %197, label %label_316, label %label_318

label_318:                                        ; preds = %label_316, %label_313
  %198 = load i8, ptr %esc, align 1
  %199 = icmp eq i8 %198, 116
  br i1 %199, label %label_319, label %label_321

label_316:                                        ; preds = %label_313
  store i8 10, ptr %value_char, align 1
  br label %label_318

label_321:                                        ; preds = %label_319, %label_318
  %200 = load i8, ptr %esc, align 1
  %201 = icmp eq i8 %200, 114
  br i1 %201, label %label_322, label %label_324

label_319:                                        ; preds = %label_318
  store i8 9, ptr %value_char, align 1
  br label %label_321

label_324:                                        ; preds = %label_322, %label_321
  %202 = load i8, ptr %esc, align 1
  %203 = icmp eq i8 %202, 48
  br i1 %203, label %label_325, label %label_327

label_322:                                        ; preds = %label_321
  store i8 13, ptr %value_char, align 1
  br label %label_324

label_327:                                        ; preds = %label_325, %label_324
  %204 = load i8, ptr %esc, align 1
  %205 = icmp eq i8 %204, 92
  br i1 %205, label %label_328, label %label_330

label_325:                                        ; preds = %label_324
  store i8 0, ptr %value_char, align 1
  br label %label_327

label_330:                                        ; preds = %label_328, %label_327
  %206 = load i8, ptr %esc, align 1
  %207 = icmp eq i8 %206, 39
  br i1 %207, label %label_331, label %label_333

label_328:                                        ; preds = %label_327
  store i8 92, ptr %value_char, align 1
  br label %label_330

label_333:                                        ; preds = %label_331, %label_330
  %208 = load i8, ptr %esc, align 1
  %209 = icmp eq i8 %208, 34
  br i1 %209, label %label_334, label %label_336

label_331:                                        ; preds = %label_330
  store i8 39, ptr %value_char, align 1
  br label %label_333

label_336:                                        ; preds = %label_334, %label_333
  br label %label_315

label_334:                                        ; preds = %label_333
  store i8 34, ptr %value_char, align 1
  br label %label_336

label_339:                                        ; preds = %label_337, %label_315
  %210 = call ptr @malloc(i64 ptrtoint (ptr getelementptr (%Token, ptr null, i32 1) to i64))
  %211 = getelementptr inbounds nuw %Token, ptr %210, i32 0, i32 0
  store i32 1, ptr %211, align 4
  %212 = load i8, ptr %value_char, align 1
  %213 = call i32 @char_code__Char(i8 %212)
  %214 = call ptr @int_to_str(i32 %213)
  %215 = getelementptr inbounds nuw %Token, ptr %210, i32 0, i32 1
  store ptr %214, ptr %215, align 8
  %216 = load ptr, ptr %lex, align 8
  %217 = getelementptr inbounds nuw %Lexer, ptr %216, i32 0, i32 2
  %218 = load i32, ptr %217, align 4
  %219 = getelementptr inbounds nuw %Token, ptr %210, i32 0, i32 2
  store i32 %218, ptr %219, align 4
  %220 = getelementptr inbounds nuw %Token, ptr %210, i32 0, i32 3
  store ptr @.str.s58, ptr %220, align 8
  ret ptr %210

label_337:                                        ; preds = %label_315
  %221 = load ptr, ptr %lex, align 8
  call void @lexer_advance__Struct_Lexer(ptr %221)
  br label %label_339

label_342:                                        ; preds = %label_312
  %sc.38 = alloca i1, align 1
  %222 = load i8, ptr %c, align 1
  %223 = icmp eq i8 %222, 46
  store i1 %223, ptr %sc.38, align 1
  br i1 %223, label %label_457, label %label_458

label_340:                                        ; preds = %label_312
  %224 = load ptr, ptr %lex, align 8
  %225 = getelementptr inbounds nuw %Lexer, ptr %224, i32 0, i32 1
  %226 = load i32, ptr %225, align 4
  store i32 %226, ptr %start, align 4
  %227 = load ptr, ptr %lex, align 8
  call void @lexer_advance__Struct_Lexer(ptr %227)
  %228 = load ptr, ptr %lex, align 8
  %229 = call i8 @lexer_current__Struct_Lexer(ptr %228)
  store i8 %229, ptr %next, align 1
  %sc.14 = alloca i1, align 1
  %230 = load i8, ptr %c, align 1
  %231 = icmp eq i8 %230, 61
  store i1 %231, ptr %sc.14, align 1
  br i1 %231, label %label_343, label %label_344

label_344:                                        ; preds = %label_343, %label_340
  %232 = load i1, ptr %sc.14, align 1
  br i1 %232, label %label_345, label %label_347

label_343:                                        ; preds = %label_340
  %233 = load i8, ptr %next, align 1
  %234 = icmp eq i8 %233, 61
  store i1 %234, ptr %sc.14, align 1
  br label %label_344

label_347:                                        ; preds = %label_345, %label_344
  %sc.15 = alloca i1, align 1
  %235 = load i8, ptr %c, align 1
  %236 = icmp eq i8 %235, 33
  store i1 %236, ptr %sc.15, align 1
  br i1 %236, label %label_348, label %label_349

label_345:                                        ; preds = %label_344
  %237 = load ptr, ptr %lex, align 8
  call void @lexer_advance__Struct_Lexer(ptr %237)
  br label %label_347

label_349:                                        ; preds = %label_348, %label_347
  %238 = load i1, ptr %sc.15, align 1
  br i1 %238, label %label_350, label %label_352

label_348:                                        ; preds = %label_347
  %239 = load i8, ptr %next, align 1
  %240 = icmp eq i8 %239, 61
  store i1 %240, ptr %sc.15, align 1
  br label %label_349

label_352:                                        ; preds = %label_350, %label_349
  %sc.16 = alloca i1, align 1
  %241 = load i8, ptr %c, align 1
  %242 = icmp eq i8 %241, 60
  store i1 %242, ptr %sc.16, align 1
  br i1 %242, label %label_353, label %label_354

label_350:                                        ; preds = %label_349
  %243 = load ptr, ptr %lex, align 8
  call void @lexer_advance__Struct_Lexer(ptr %243)
  br label %label_352

label_354:                                        ; preds = %label_353, %label_352
  %244 = load i1, ptr %sc.16, align 1
  br i1 %244, label %label_355, label %label_357

label_353:                                        ; preds = %label_352
  %245 = load i8, ptr %next, align 1
  %246 = icmp eq i8 %245, 61
  store i1 %246, ptr %sc.16, align 1
  br label %label_354

label_357:                                        ; preds = %label_355, %label_354
  %sc.17 = alloca i1, align 1
  %247 = load i8, ptr %c, align 1
  %248 = icmp eq i8 %247, 62
  store i1 %248, ptr %sc.17, align 1
  br i1 %248, label %label_358, label %label_359

label_355:                                        ; preds = %label_354
  %249 = load ptr, ptr %lex, align 8
  call void @lexer_advance__Struct_Lexer(ptr %249)
  br label %label_357

label_359:                                        ; preds = %label_358, %label_357
  %250 = load i1, ptr %sc.17, align 1
  br i1 %250, label %label_360, label %label_362

label_358:                                        ; preds = %label_357
  %251 = load i8, ptr %next, align 1
  %252 = icmp eq i8 %251, 61
  store i1 %252, ptr %sc.17, align 1
  br label %label_359

label_362:                                        ; preds = %label_360, %label_359
  %sc.18 = alloca i1, align 1
  %253 = load i8, ptr %c, align 1
  %254 = icmp eq i8 %253, 38
  store i1 %254, ptr %sc.18, align 1
  br i1 %254, label %label_363, label %label_364

label_360:                                        ; preds = %label_359
  %255 = load ptr, ptr %lex, align 8
  call void @lexer_advance__Struct_Lexer(ptr %255)
  br label %label_362

label_364:                                        ; preds = %label_363, %label_362
  %256 = load i1, ptr %sc.18, align 1
  br i1 %256, label %label_365, label %label_367

label_363:                                        ; preds = %label_362
  %257 = load i8, ptr %next, align 1
  %258 = icmp eq i8 %257, 38
  store i1 %258, ptr %sc.18, align 1
  br label %label_364

label_367:                                        ; preds = %label_365, %label_364
  %sc.19 = alloca i1, align 1
  %259 = load i8, ptr %c, align 1
  %260 = icmp eq i8 %259, 124
  store i1 %260, ptr %sc.19, align 1
  br i1 %260, label %label_368, label %label_369

label_365:                                        ; preds = %label_364
  %261 = load ptr, ptr %lex, align 8
  call void @lexer_advance__Struct_Lexer(ptr %261)
  br label %label_367

label_369:                                        ; preds = %label_368, %label_367
  %262 = load i1, ptr %sc.19, align 1
  br i1 %262, label %label_370, label %label_372

label_368:                                        ; preds = %label_367
  %263 = load i8, ptr %next, align 1
  %264 = icmp eq i8 %263, 124
  store i1 %264, ptr %sc.19, align 1
  br label %label_369

label_372:                                        ; preds = %label_370, %label_369
  %sc.20 = alloca i1, align 1
  %265 = load i8, ptr %c, align 1
  %266 = icmp eq i8 %265, 45
  store i1 %266, ptr %sc.20, align 1
  br i1 %266, label %label_373, label %label_374

label_370:                                        ; preds = %label_369
  %267 = load ptr, ptr %lex, align 8
  call void @lexer_advance__Struct_Lexer(ptr %267)
  br label %label_372

label_374:                                        ; preds = %label_373, %label_372
  %268 = load i1, ptr %sc.20, align 1
  br i1 %268, label %label_375, label %label_377

label_373:                                        ; preds = %label_372
  %269 = load i8, ptr %next, align 1
  %270 = icmp eq i8 %269, 62
  store i1 %270, ptr %sc.20, align 1
  br label %label_374

label_377:                                        ; preds = %label_375, %label_374
  %sc.21 = alloca i1, align 1
  %271 = load i8, ptr %c, align 1
  %272 = icmp eq i8 %271, 61
  store i1 %272, ptr %sc.21, align 1
  br i1 %272, label %label_378, label %label_379

label_375:                                        ; preds = %label_374
  %273 = load ptr, ptr %lex, align 8
  call void @lexer_advance__Struct_Lexer(ptr %273)
  br label %label_377

label_379:                                        ; preds = %label_378, %label_377
  %274 = load i1, ptr %sc.21, align 1
  br i1 %274, label %label_380, label %label_382

label_378:                                        ; preds = %label_377
  %275 = load i8, ptr %next, align 1
  %276 = icmp eq i8 %275, 62
  store i1 %276, ptr %sc.21, align 1
  br label %label_379

label_382:                                        ; preds = %label_380, %label_379
  %sc.22 = alloca i1, align 1
  %277 = load i8, ptr %c, align 1
  %278 = icmp eq i8 %277, 60
  store i1 %278, ptr %sc.22, align 1
  br i1 %278, label %label_383, label %label_384

label_380:                                        ; preds = %label_379
  %279 = load ptr, ptr %lex, align 8
  call void @lexer_advance__Struct_Lexer(ptr %279)
  br label %label_382

label_384:                                        ; preds = %label_383, %label_382
  %280 = load i1, ptr %sc.22, align 1
  br i1 %280, label %label_385, label %label_387

label_383:                                        ; preds = %label_382
  %281 = load i8, ptr %next, align 1
  %282 = icmp eq i8 %281, 60
  store i1 %282, ptr %sc.22, align 1
  br label %label_384

label_387:                                        ; preds = %label_385, %label_384
  %sc.23 = alloca i1, align 1
  %283 = load i8, ptr %c, align 1
  %284 = icmp eq i8 %283, 62
  store i1 %284, ptr %sc.23, align 1
  br i1 %284, label %label_388, label %label_389

label_385:                                        ; preds = %label_384
  %285 = load ptr, ptr %lex, align 8
  call void @lexer_advance__Struct_Lexer(ptr %285)
  br label %label_387

label_389:                                        ; preds = %label_388, %label_387
  %286 = load i1, ptr %sc.23, align 1
  br i1 %286, label %label_390, label %label_392

label_388:                                        ; preds = %label_387
  %287 = load i8, ptr %next, align 1
  %288 = icmp eq i8 %287, 62
  store i1 %288, ptr %sc.23, align 1
  br label %label_389

label_392:                                        ; preds = %label_390, %label_389
  %289 = load i8, ptr %next, align 1
  %290 = icmp eq i8 %289, 61
  br i1 %290, label %label_393, label %label_395

label_390:                                        ; preds = %label_389
  %291 = load ptr, ptr %lex, align 8
  call void @lexer_advance__Struct_Lexer(ptr %291)
  br label %label_392

label_395:                                        ; preds = %label_413, %label_392
  %292 = load ptr, ptr %lex, align 8
  %293 = getelementptr inbounds nuw %Lexer, ptr %292, i32 0, i32 1
  %294 = load i32, ptr %293, align 4
  %295 = load i32, ptr %start, align 4
  %296 = sub i32 %294, %295
  store i32 %296, ptr %length, align 4
  %297 = load ptr, ptr %lex, align 8
  %298 = getelementptr inbounds nuw %Lexer, ptr %297, i32 0, i32 0
  %299 = load ptr, ptr %298, align 8
  %300 = load i32, ptr %start, align 4
  %301 = load i32, ptr %length, align 4
  %302 = call ptr @str_substring(ptr %299, i32 %300, i32 %301)
  store ptr %302, ptr %value, align 8
  store i32 8, ptr %type, align 4
  %303 = load i32, ptr %length, align 4
  %304 = icmp eq i32 %303, 2
  br i1 %304, label %label_414, label %label_415

label_393:                                        ; preds = %label_392
  %sc.24 = alloca i1, align 1
  %sc.25 = alloca i1, align 1
  %sc.26 = alloca i1, align 1
  %sc.27 = alloca i1, align 1
  %305 = load i8, ptr %c, align 1
  %306 = icmp eq i8 %305, 43
  store i1 %306, ptr %sc.27, align 1
  br i1 %306, label %label_403, label %label_402

label_402:                                        ; preds = %label_393
  %307 = load i8, ptr %c, align 1
  %308 = icmp eq i8 %307, 45
  store i1 %308, ptr %sc.27, align 1
  br label %label_403

label_403:                                        ; preds = %label_402, %label_393
  %309 = load i1, ptr %sc.27, align 1
  store i1 %309, ptr %sc.26, align 1
  br i1 %309, label %label_401, label %label_400

label_400:                                        ; preds = %label_403
  %310 = load i8, ptr %c, align 1
  %311 = icmp eq i8 %310, 42
  store i1 %311, ptr %sc.26, align 1
  br label %label_401

label_401:                                        ; preds = %label_400, %label_403
  %312 = load i1, ptr %sc.26, align 1
  store i1 %312, ptr %sc.25, align 1
  br i1 %312, label %label_399, label %label_398

label_398:                                        ; preds = %label_401
  %313 = load i8, ptr %c, align 1
  %314 = icmp eq i8 %313, 47
  store i1 %314, ptr %sc.25, align 1
  br label %label_399

label_399:                                        ; preds = %label_398, %label_401
  %315 = load i1, ptr %sc.25, align 1
  store i1 %315, ptr %sc.24, align 1
  br i1 %315, label %label_397, label %label_396

label_396:                                        ; preds = %label_399
  %316 = load i8, ptr %c, align 1
  %317 = icmp eq i8 %316, 37
  store i1 %317, ptr %sc.24, align 1
  br label %label_397

label_397:                                        ; preds = %label_396, %label_399
  %318 = load i1, ptr %sc.24, align 1
  br i1 %318, label %label_404, label %label_406

label_406:                                        ; preds = %label_404, %label_397
  %sc.28 = alloca i1, align 1
  %sc.29 = alloca i1, align 1
  %319 = load i8, ptr %c, align 1
  %320 = icmp eq i8 %319, 38
  store i1 %320, ptr %sc.29, align 1
  br i1 %320, label %label_410, label %label_409

label_404:                                        ; preds = %label_397
  %321 = load ptr, ptr %lex, align 8
  call void @lexer_advance__Struct_Lexer(ptr %321)
  br label %label_406

label_409:                                        ; preds = %label_406
  %322 = load i8, ptr %c, align 1
  %323 = icmp eq i8 %322, 124
  store i1 %323, ptr %sc.29, align 1
  br label %label_410

label_410:                                        ; preds = %label_409, %label_406
  %324 = load i1, ptr %sc.29, align 1
  store i1 %324, ptr %sc.28, align 1
  br i1 %324, label %label_408, label %label_407

label_407:                                        ; preds = %label_410
  %325 = load i8, ptr %c, align 1
  %326 = icmp eq i8 %325, 94
  store i1 %326, ptr %sc.28, align 1
  br label %label_408

label_408:                                        ; preds = %label_407, %label_410
  %327 = load i1, ptr %sc.28, align 1
  br i1 %327, label %label_411, label %label_413

label_413:                                        ; preds = %label_411, %label_408
  br label %label_395

label_411:                                        ; preds = %label_408
  %328 = load ptr, ptr %lex, align 8
  call void @lexer_advance__Struct_Lexer(ptr %328)
  br label %label_413

label_415:                                        ; preds = %label_395
  %sc.37 = alloca i1, align 1
  %329 = load i8, ptr %c, align 1
  %330 = icmp eq i8 %329, 60
  store i1 %330, ptr %sc.37, align 1
  br i1 %330, label %label_447, label %label_446

label_414:                                        ; preds = %label_395
  %sc.30 = alloca i1, align 1
  %sc.31 = alloca i1, align 1
  %sc.32 = alloca i1, align 1
  %331 = load ptr, ptr %value, align 8
  %332 = call i32 @str_equals(ptr %331, ptr @.str.s59)
  %333 = icmp eq i32 %332, 1
  store i1 %333, ptr %sc.32, align 1
  br i1 %333, label %label_422, label %label_421

label_421:                                        ; preds = %label_414
  %334 = load ptr, ptr %value, align 8
  %335 = call i32 @str_equals(ptr %334, ptr @.str.s60)
  %336 = icmp eq i32 %335, 1
  store i1 %336, ptr %sc.32, align 1
  br label %label_422

label_422:                                        ; preds = %label_421, %label_414
  %337 = load i1, ptr %sc.32, align 1
  store i1 %337, ptr %sc.31, align 1
  br i1 %337, label %label_420, label %label_419

label_419:                                        ; preds = %label_422
  %338 = load ptr, ptr %value, align 8
  %339 = call i32 @str_equals(ptr %338, ptr @.str.s61)
  %340 = icmp eq i32 %339, 1
  store i1 %340, ptr %sc.31, align 1
  br label %label_420

label_420:                                        ; preds = %label_419, %label_422
  %341 = load i1, ptr %sc.31, align 1
  store i1 %341, ptr %sc.30, align 1
  br i1 %341, label %label_418, label %label_417

label_417:                                        ; preds = %label_420
  %342 = load ptr, ptr %value, align 8
  %343 = call i32 @str_equals(ptr %342, ptr @.str.s62)
  %344 = icmp eq i32 %343, 1
  store i1 %344, ptr %sc.30, align 1
  br label %label_418

label_418:                                        ; preds = %label_417, %label_420
  %345 = load i1, ptr %sc.30, align 1
  br i1 %345, label %label_423, label %label_425

label_425:                                        ; preds = %label_423, %label_418
  %sc.33 = alloca i1, align 1
  %346 = load ptr, ptr %value, align 8
  %347 = call i32 @str_equals(ptr %346, ptr @.str.s63)
  %348 = icmp eq i32 %347, 1
  store i1 %348, ptr %sc.33, align 1
  br i1 %348, label %label_427, label %label_426

label_423:                                        ; preds = %label_418
  store i32 9, ptr %type, align 4
  br label %label_425

label_426:                                        ; preds = %label_425
  %349 = load ptr, ptr %value, align 8
  %350 = call i32 @str_equals(ptr %349, ptr @.str.s64)
  %351 = icmp eq i32 %350, 1
  store i1 %351, ptr %sc.33, align 1
  br label %label_427

label_427:                                        ; preds = %label_426, %label_425
  %352 = load i1, ptr %sc.33, align 1
  br i1 %352, label %label_428, label %label_430

label_430:                                        ; preds = %label_433, %label_427
  %sc.34 = alloca i1, align 1
  %353 = load ptr, ptr %value, align 8
  %354 = call i8 @str_char_at(ptr %353, i32 1)
  %355 = icmp eq i8 %354, 61
  store i1 %355, ptr %sc.34, align 1
  br i1 %355, label %label_434, label %label_435

label_428:                                        ; preds = %label_427
  store i32 15, ptr %type, align 4
  %356 = load ptr, ptr %value, align 8
  %357 = call i32 @str_equals(ptr %356, ptr @.str.s65)
  %358 = icmp eq i32 %357, 1
  br i1 %358, label %label_431, label %label_433

label_433:                                        ; preds = %label_431, %label_428
  br label %label_430

label_431:                                        ; preds = %label_428
  store i32 16, ptr %type, align 4
  br label %label_433

label_435:                                        ; preds = %label_434, %label_430
  %359 = load i1, ptr %sc.34, align 1
  br i1 %359, label %label_436, label %label_438

label_434:                                        ; preds = %label_430
  %360 = load ptr, ptr %value, align 8
  %361 = call i8 @str_char_at(ptr %360, i32 0)
  %362 = icmp ne i8 %361, 61
  store i1 %362, ptr %sc.34, align 1
  br label %label_435

label_438:                                        ; preds = %label_445, %label_435
  br label %label_416

label_436:                                        ; preds = %label_435
  %sc.35 = alloca i1, align 1
  %sc.36 = alloca i1, align 1
  %363 = load ptr, ptr %value, align 8
  %364 = call i32 @str_equals(ptr %363, ptr @.str.s66)
  %365 = icmp eq i32 %364, 0
  store i1 %365, ptr %sc.36, align 1
  br i1 %365, label %label_441, label %label_442

label_442:                                        ; preds = %label_441, %label_436
  %366 = load i1, ptr %sc.36, align 1
  store i1 %366, ptr %sc.35, align 1
  br i1 %366, label %label_439, label %label_440

label_441:                                        ; preds = %label_436
  %367 = load ptr, ptr %value, align 8
  %368 = call i32 @str_equals(ptr %367, ptr @.str.s67)
  %369 = icmp eq i32 %368, 0
  store i1 %369, ptr %sc.36, align 1
  br label %label_442

label_440:                                        ; preds = %label_439, %label_442
  %370 = load i1, ptr %sc.35, align 1
  br i1 %370, label %label_443, label %label_445

label_439:                                        ; preds = %label_442
  %371 = load ptr, ptr %value, align 8
  %372 = call i32 @str_equals(ptr %371, ptr @.str.s68)
  %373 = icmp eq i32 %372, 0
  store i1 %373, ptr %sc.35, align 1
  br label %label_440

label_445:                                        ; preds = %label_443, %label_440
  br label %label_438

label_443:                                        ; preds = %label_440
  store i32 12, ptr %type, align 4
  br label %label_445

label_416:                                        ; preds = %label_456, %label_438
  %374 = call ptr @malloc(i64 ptrtoint (ptr getelementptr (%Token, ptr null, i32 1) to i64))
  %375 = load i32, ptr %type, align 4
  %376 = getelementptr inbounds nuw %Token, ptr %374, i32 0, i32 0
  store i32 %375, ptr %376, align 4
  %377 = load ptr, ptr %value, align 8
  %378 = getelementptr inbounds nuw %Token, ptr %374, i32 0, i32 1
  store ptr %377, ptr %378, align 8
  %379 = load ptr, ptr %lex, align 8
  %380 = getelementptr inbounds nuw %Lexer, ptr %379, i32 0, i32 2
  %381 = load i32, ptr %380, align 4
  %382 = getelementptr inbounds nuw %Token, ptr %374, i32 0, i32 2
  store i32 %381, ptr %382, align 4
  %383 = getelementptr inbounds nuw %Token, ptr %374, i32 0, i32 3
  store ptr @.str.s69, ptr %383, align 8
  ret ptr %374

label_446:                                        ; preds = %label_415
  %384 = load i8, ptr %c, align 1
  %385 = icmp eq i8 %384, 62
  store i1 %385, ptr %sc.37, align 1
  br label %label_447

label_447:                                        ; preds = %label_446, %label_415
  %386 = load i1, ptr %sc.37, align 1
  br i1 %386, label %label_448, label %label_450

label_450:                                        ; preds = %label_448, %label_447
  %387 = load i8, ptr %c, align 1
  %388 = icmp eq i8 %387, 61
  br i1 %388, label %label_451, label %label_453

label_448:                                        ; preds = %label_447
  store i32 9, ptr %type, align 4
  br label %label_450

label_453:                                        ; preds = %label_451, %label_450
  %389 = load i8, ptr %c, align 1
  %390 = icmp eq i8 %389, 33
  br i1 %390, label %label_454, label %label_456

label_451:                                        ; preds = %label_450
  store i32 12, ptr %type, align 4
  br label %label_453

label_456:                                        ; preds = %label_454, %label_453
  br label %label_416

label_454:                                        ; preds = %label_453
  store i32 10, ptr %type, align 4
  br label %label_456

label_458:                                        ; preds = %label_457, %label_342
  %391 = load i1, ptr %sc.38, align 1
  br i1 %391, label %label_459, label %label_461

label_457:                                        ; preds = %label_342
  %392 = load ptr, ptr %lex, align 8
  %393 = call i8 @lexer_peek__Struct_Lexer_Int(ptr %392, i32 1)
  %394 = icmp eq i8 %393, 46
  store i1 %394, ptr %sc.38, align 1
  br label %label_458

label_461:                                        ; preds = %label_458
  %395 = load i8, ptr %c, align 1
  %396 = call i1 @is_separator__Char(i8 %395)
  br i1 %396, label %label_462, label %label_464

label_459:                                        ; preds = %label_458
  %397 = load ptr, ptr %lex, align 8
  call void @lexer_advance__Struct_Lexer(ptr %397)
  %398 = load ptr, ptr %lex, align 8
  call void @lexer_advance__Struct_Lexer(ptr %398)
  %399 = call ptr @malloc(i64 ptrtoint (ptr getelementptr (%Token, ptr null, i32 1) to i64))
  %400 = getelementptr inbounds nuw %Token, ptr %399, i32 0, i32 0
  store i32 17, ptr %400, align 4
  %401 = getelementptr inbounds nuw %Token, ptr %399, i32 0, i32 1
  store ptr @.str.s70, ptr %401, align 8
  %402 = load ptr, ptr %lex, align 8
  %403 = getelementptr inbounds nuw %Lexer, ptr %402, i32 0, i32 2
  %404 = load i32, ptr %403, align 4
  %405 = getelementptr inbounds nuw %Token, ptr %399, i32 0, i32 2
  store i32 %404, ptr %405, align 4
  %406 = getelementptr inbounds nuw %Token, ptr %399, i32 0, i32 3
  store ptr @.str.s71, ptr %406, align 8
  ret ptr %399

label_464:                                        ; preds = %label_461
  %407 = load ptr, ptr %lex, align 8
  call void @lexer_advance__Struct_Lexer(ptr %407)
  %408 = call ptr @malloc(i64 ptrtoint (ptr getelementptr (%Token, ptr null, i32 1) to i64))
  %409 = getelementptr inbounds nuw %Token, ptr %408, i32 0, i32 0
  store i32 19, ptr %409, align 4
  %410 = getelementptr inbounds nuw %Token, ptr %408, i32 0, i32 1
  store ptr @.str.s73, ptr %410, align 8
  %411 = load ptr, ptr %lex, align 8
  %412 = getelementptr inbounds nuw %Lexer, ptr %411, i32 0, i32 2
  %413 = load i32, ptr %412, align 4
  %414 = getelementptr inbounds nuw %Token, ptr %408, i32 0, i32 2
  store i32 %413, ptr %414, align 4
  %415 = getelementptr inbounds nuw %Token, ptr %408, i32 0, i32 3
  store ptr @.str.s74, ptr %415, align 8
  ret ptr %408

label_462:                                        ; preds = %label_461
  %416 = load ptr, ptr %lex, align 8
  %417 = getelementptr inbounds nuw %Lexer, ptr %416, i32 0, i32 0
  %418 = load ptr, ptr %417, align 8
  %419 = load ptr, ptr %lex, align 8
  %420 = getelementptr inbounds nuw %Lexer, ptr %419, i32 0, i32 1
  %421 = load i32, ptr %420, align 4
  %422 = call ptr @str_substring(ptr %418, i32 %421, i32 1)
  store ptr %422, ptr %val, align 8
  %423 = load ptr, ptr %lex, align 8
  call void @lexer_advance__Struct_Lexer(ptr %423)
  %424 = call ptr @malloc(i64 ptrtoint (ptr getelementptr (%Token, ptr null, i32 1) to i64))
  %425 = getelementptr inbounds nuw %Token, ptr %424, i32 0, i32 0
  store i32 6, ptr %425, align 4
  %426 = load ptr, ptr %val, align 8
  %427 = getelementptr inbounds nuw %Token, ptr %424, i32 0, i32 1
  store ptr %426, ptr %427, align 8
  %428 = load ptr, ptr %lex, align 8
  %429 = getelementptr inbounds nuw %Lexer, ptr %428, i32 0, i32 2
  %430 = load i32, ptr %429, align 4
  %431 = getelementptr inbounds nuw %Token, ptr %424, i32 0, i32 2
  store i32 %430, ptr %431, align 4
  %432 = getelementptr inbounds nuw %Token, ptr %424, i32 0, i32 3
  store ptr @.str.s72, ptr %432, align 8
  ret ptr %424
}

define ptr @lex_all_tokens__Struct_Lexer(ptr %0) {
entry:
  %lex = alloca ptr, align 8
  store ptr %0, ptr %lex, align 8
  %head_ptr = alloca ptr, align 8
  %current_ptr = alloca ptr, align 8
  %scanning = alloca i1, align 1
  %current = alloca ptr, align 8
  %next_ptr = alloca ptr, align 8
  %1 = load ptr, ptr %lex, align 8
  %2 = call ptr @lexer_next_token__Struct_Lexer(ptr %1)
  %3 = call ptr @token_to_ptr(ptr %2)
  store ptr %3, ptr %head_ptr, align 8
  %4 = load ptr, ptr %head_ptr, align 8
  store ptr %4, ptr %current_ptr, align 8
  store i1 true, ptr %scanning, align 1
  br label %label_465

label_465:                                        ; preds = %label_470, %entry
  %5 = load i1, ptr %scanning, align 1
  br i1 %5, label %label_466, label %label_467

label_467:                                        ; preds = %label_465
  %6 = load ptr, ptr %head_ptr, align 8
  %7 = call ptr @ptr_to_token(ptr %6)
  ret ptr %7

label_466:                                        ; preds = %label_465
  %8 = load ptr, ptr %current_ptr, align 8
  %9 = call ptr @ptr_to_token(ptr %8)
  store ptr %9, ptr %current, align 8
  %10 = load ptr, ptr %current, align 8
  %11 = getelementptr inbounds nuw %Token, ptr %10, i32 0, i32 0
  %12 = load i32, ptr %11, align 4
  %13 = icmp eq i32 %12, 20
  br i1 %13, label %label_468, label %label_469

label_469:                                        ; preds = %label_466
  %14 = load ptr, ptr %lex, align 8
  %15 = call ptr @lexer_next_token__Struct_Lexer(ptr %14)
  %16 = call ptr @token_to_ptr(ptr %15)
  store ptr %16, ptr %next_ptr, align 8
  %17 = load ptr, ptr %current, align 8
  %18 = load ptr, ptr %next_ptr, align 8
  %19 = getelementptr inbounds nuw %Token, ptr %17, i32 0, i32 3
  store ptr %18, ptr %19, align 8
  %20 = load ptr, ptr %next_ptr, align 8
  store ptr %20, ptr %current_ptr, align 8
  br label %label_470

label_468:                                        ; preds = %label_466
  store i1 false, ptr %scanning, align 1
  br label %label_470

label_470:                                        ; preds = %label_469, %label_468
  br label %label_465
}

define ptr @create_node__Enum_NodeKind(i32 %0) {
entry:
  %kind = alloca i32, align 4
  store i32 %0, ptr %kind, align 4
  %1 = call ptr @malloc(i64 ptrtoint (ptr getelementptr (%ASTNode, ptr null, i32 1) to i64))
  %2 = load i32, ptr %kind, align 4
  %3 = getelementptr inbounds nuw %ASTNode, ptr %1, i32 0, i32 0
  store i32 %2, ptr %3, align 4
  %4 = getelementptr inbounds nuw %ASTNode, ptr %1, i32 0, i32 1
  store ptr @.str.s75, ptr %4, align 8
  %5 = getelementptr inbounds nuw %ASTNode, ptr %1, i32 0, i32 2
  store ptr @.str.s76, ptr %5, align 8
  %6 = getelementptr inbounds nuw %ASTNode, ptr %1, i32 0, i32 3
  store i32 0, ptr %6, align 4
  %7 = getelementptr inbounds nuw %ASTNode, ptr %1, i32 0, i32 4
  store i32 0, ptr %7, align 4
  %8 = getelementptr inbounds nuw %ASTNode, ptr %1, i32 0, i32 5
  store ptr @.str.s77, ptr %8, align 8
  %9 = getelementptr inbounds nuw %ASTNode, ptr %1, i32 0, i32 6
  store ptr @.str.s78, ptr %9, align 8
  %10 = getelementptr inbounds nuw %ASTNode, ptr %1, i32 0, i32 7
  store ptr @.str.s79, ptr %10, align 8
  %11 = getelementptr inbounds nuw %ASTNode, ptr %1, i32 0, i32 8
  store ptr @.str.s80, ptr %11, align 8
  %12 = getelementptr inbounds nuw %ASTNode, ptr %1, i32 0, i32 9
  store ptr @.str.s81, ptr %12, align 8
  ret ptr %1
}

define ptr @parser_create__Struct_Token(ptr %0) {
entry:
  %tokens = alloca ptr, align 8
  store ptr %0, ptr %tokens, align 8
  %1 = call ptr @malloc(i64 ptrtoint (ptr getelementptr (%Parser, ptr null, i32 1) to i64))
  %2 = load ptr, ptr %tokens, align 8
  %3 = call ptr @token_to_ptr(ptr %2)
  %4 = getelementptr inbounds nuw %Parser, ptr %1, i32 0, i32 0
  store ptr %3, ptr %4, align 8
  ret ptr %1
}

define ptr @parser_current__Struct_Parser(ptr %0) {
entry:
  %p = alloca ptr, align 8
  store ptr %0, ptr %p, align 8
  %1 = load ptr, ptr %p, align 8
  %2 = getelementptr inbounds nuw %Parser, ptr %1, i32 0, i32 0
  %3 = load ptr, ptr %2, align 8
  %4 = call ptr @ptr_to_token(ptr %3)
  ret ptr %4
}

define ptr @parser_peek__Struct_Parser(ptr %0) {
entry:
  %p = alloca ptr, align 8
  store ptr %0, ptr %p, align 8
  %curr = alloca ptr, align 8
  %1 = load ptr, ptr %p, align 8
  %2 = getelementptr inbounds nuw %Parser, ptr %1, i32 0, i32 0
  %3 = load ptr, ptr %2, align 8
  %4 = call ptr @ptr_to_token(ptr %3)
  store ptr %4, ptr %curr, align 8
  %5 = load ptr, ptr %curr, align 8
  %6 = getelementptr inbounds nuw %Token, ptr %5, i32 0, i32 3
  %7 = load ptr, ptr %6, align 8
  %8 = call ptr @ptr_to_token(ptr %7)
  ret ptr %8
}

define void @parser_advance__Struct_Parser(ptr %0) {
entry:
  %p = alloca ptr, align 8
  store ptr %0, ptr %p, align 8
  %curr = alloca ptr, align 8
  %1 = load ptr, ptr %p, align 8
  %2 = getelementptr inbounds nuw %Parser, ptr %1, i32 0, i32 0
  %3 = load ptr, ptr %2, align 8
  %4 = call ptr @ptr_to_token(ptr %3)
  store ptr %4, ptr %curr, align 8
  %5 = load ptr, ptr %curr, align 8
  %6 = getelementptr inbounds nuw %Token, ptr %5, i32 0, i32 0
  %7 = load i32, ptr %6, align 4
  %8 = icmp ne i32 %7, 20
  br i1 %8, label %label_471, label %label_473

label_473:                                        ; preds = %label_471, %entry
  ret void

label_471:                                        ; preds = %entry
  %9 = load ptr, ptr %p, align 8
  %10 = load ptr, ptr %curr, align 8
  %11 = getelementptr inbounds nuw %Token, ptr %10, i32 0, i32 3
  %12 = load ptr, ptr %11, align 8
  %13 = getelementptr inbounds nuw %Parser, ptr %9, i32 0, i32 0
  store ptr %12, ptr %13, align 8
  br label %label_473
}

define i1 @parser_check__Struct_Parser_Enum_TokenType(ptr %0, i32 %1) {
entry:
  %p = alloca ptr, align 8
  store ptr %0, ptr %p, align 8
  %t = alloca i32, align 4
  store i32 %1, ptr %t, align 4
  %curr = alloca ptr, align 8
  %2 = load ptr, ptr %p, align 8
  %3 = call ptr @parser_current__Struct_Parser(ptr %2)
  store ptr %3, ptr %curr, align 8
  %4 = load ptr, ptr %curr, align 8
  %5 = getelementptr inbounds nuw %Token, ptr %4, i32 0, i32 0
  %6 = load i32, ptr %5, align 4
  %7 = load i32, ptr %t, align 4
  %8 = icmp eq i32 %6, %7
  ret i1 %8
}

define i1 @parser_check_val__Struct_Parser_Enum_TokenType_String(ptr %0, i32 %1, ptr %2) {
entry:
  %p = alloca ptr, align 8
  store ptr %0, ptr %p, align 8
  %t = alloca i32, align 4
  store i32 %1, ptr %t, align 4
  %val = alloca ptr, align 8
  store ptr %2, ptr %val, align 8
  %curr = alloca ptr, align 8
  %3 = load ptr, ptr %p, align 8
  %4 = call ptr @parser_current__Struct_Parser(ptr %3)
  store ptr %4, ptr %curr, align 8
  %sc.39 = alloca i1, align 1
  %5 = load ptr, ptr %curr, align 8
  %6 = getelementptr inbounds nuw %Token, ptr %5, i32 0, i32 0
  %7 = load i32, ptr %6, align 4
  %8 = load i32, ptr %t, align 4
  %9 = icmp eq i32 %7, %8
  store i1 %9, ptr %sc.39, align 1
  br i1 %9, label %label_474, label %label_475

label_475:                                        ; preds = %label_474, %entry
  %10 = load i1, ptr %sc.39, align 1
  ret i1 %10

label_474:                                        ; preds = %entry
  %11 = load ptr, ptr %curr, align 8
  %12 = getelementptr inbounds nuw %Token, ptr %11, i32 0, i32 1
  %13 = load ptr, ptr %12, align 8
  %14 = load ptr, ptr %val, align 8
  %15 = call i32 @str_equals(ptr %13, ptr %14)
  %16 = icmp eq i32 %15, 1
  store i1 %16, ptr %sc.39, align 1
  br label %label_475
}

define i1 @parser_match__Struct_Parser_Enum_TokenType(ptr %0, i32 %1) {
entry:
  %p = alloca ptr, align 8
  store ptr %0, ptr %p, align 8
  %t = alloca i32, align 4
  store i32 %1, ptr %t, align 4
  %2 = load ptr, ptr %p, align 8
  %3 = load i32, ptr %t, align 4
  %4 = call i1 @parser_check__Struct_Parser_Enum_TokenType(ptr %2, i32 %3)
  br i1 %4, label %label_476, label %label_478

label_478:                                        ; preds = %entry
  ret i1 false

label_476:                                        ; preds = %entry
  %5 = load ptr, ptr %p, align 8
  call void @parser_advance__Struct_Parser(ptr %5)
  ret i1 true
}

define i1 @parser_match_val__Struct_Parser_Enum_TokenType_String(ptr %0, i32 %1, ptr %2) {
entry:
  %p = alloca ptr, align 8
  store ptr %0, ptr %p, align 8
  %t = alloca i32, align 4
  store i32 %1, ptr %t, align 4
  %val = alloca ptr, align 8
  store ptr %2, ptr %val, align 8
  %3 = load ptr, ptr %p, align 8
  %4 = load i32, ptr %t, align 4
  %5 = load ptr, ptr %val, align 8
  %6 = call i1 @parser_check_val__Struct_Parser_Enum_TokenType_String(ptr %3, i32 %4, ptr %5)
  br i1 %6, label %label_479, label %label_481

label_481:                                        ; preds = %entry
  ret i1 false

label_479:                                        ; preds = %entry
  %7 = load ptr, ptr %p, align 8
  call void @parser_advance__Struct_Parser(ptr %7)
  ret i1 true
}

define void @parser_expect__Struct_Parser_Enum_TokenType_String(ptr %0, i32 %1, ptr %2) {
entry:
  %p = alloca ptr, align 8
  store ptr %0, ptr %p, align 8
  %t = alloca i32, align 4
  store i32 %1, ptr %t, align 4
  %context = alloca ptr, align 8
  store ptr %2, ptr %context, align 8
  %3 = load ptr, ptr %p, align 8
  %4 = load i32, ptr %t, align 4
  %5 = call i1 @parser_check__Struct_Parser_Enum_TokenType(ptr %3, i32 %4)
  %6 = icmp eq i1 %5, false
  br i1 %6, label %label_482, label %label_484

label_484:                                        ; preds = %label_482, %entry
  %7 = load ptr, ptr %p, align 8
  call void @parser_advance__Struct_Parser(ptr %7)
  ret void

label_482:                                        ; preds = %entry
  call void @print(ptr @.str.s82)
  %8 = load ptr, ptr %context, align 8
  call void @print(ptr %8)
  call void @print(ptr @.str.s83)
  %9 = load i32, ptr %t, align 4
  call void @println_int(i32 %9)
  call void @exit(i32 1)
  br label %label_484
}

define void @parser_expect_val__Struct_Parser_Enum_TokenType_String_String(ptr %0, i32 %1, ptr %2, ptr %3) {
entry:
  %p = alloca ptr, align 8
  store ptr %0, ptr %p, align 8
  %t = alloca i32, align 4
  store i32 %1, ptr %t, align 4
  %val = alloca ptr, align 8
  store ptr %2, ptr %val, align 8
  %context = alloca ptr, align 8
  store ptr %3, ptr %context, align 8
  %4 = load ptr, ptr %p, align 8
  %5 = load i32, ptr %t, align 4
  %6 = load ptr, ptr %val, align 8
  %7 = call i1 @parser_check_val__Struct_Parser_Enum_TokenType_String(ptr %4, i32 %5, ptr %6)
  %8 = icmp eq i1 %7, false
  br i1 %8, label %label_485, label %label_487

label_487:                                        ; preds = %label_485, %entry
  %9 = load ptr, ptr %p, align 8
  call void @parser_advance__Struct_Parser(ptr %9)
  ret void

label_485:                                        ; preds = %entry
  call void @print(ptr @.str.s84)
  %10 = load ptr, ptr %context, align 8
  call void @print(ptr %10)
  call void @print(ptr @.str.s85)
  %11 = load ptr, ptr %val, align 8
  call void @print(ptr %11)
  call void @println(ptr @.str.s86)
  call void @exit(i32 1)
  br label %label_487
}

define ptr @parse_import_statement__Struct_Parser(ptr %0) {
entry:
  %p = alloca ptr, align 8
  store ptr %0, ptr %p, align 8
  %import_node = alloca ptr, align 8
  %curr = alloca ptr, align 8
  %1 = load ptr, ptr %p, align 8
  call void @parser_expect_val__Struct_Parser_Enum_TokenType_String_String(ptr %1, i32 18, ptr @.str.s87, ptr @.str.s88)
  %2 = call ptr @create_node__Enum_NodeKind(i32 1)
  store ptr %2, ptr %import_node, align 8
  %3 = load ptr, ptr %p, align 8
  %4 = call ptr @parser_current__Struct_Parser(ptr %3)
  store ptr %4, ptr %curr, align 8
  %5 = load ptr, ptr %import_node, align 8
  %6 = load ptr, ptr %curr, align 8
  %7 = getelementptr inbounds nuw %Token, ptr %6, i32 0, i32 1
  %8 = load ptr, ptr %7, align 8
  %9 = getelementptr inbounds nuw %ASTNode, ptr %5, i32 0, i32 1
  store ptr %8, ptr %9, align 8
  %sc.40 = alloca i1, align 1
  %10 = load ptr, ptr %curr, align 8
  %11 = getelementptr inbounds nuw %Token, ptr %10, i32 0, i32 0
  %12 = load i32, ptr %11, align 4
  %13 = icmp eq i32 %12, 5
  store i1 %13, ptr %sc.40, align 1
  br i1 %13, label %label_489, label %label_488

label_488:                                        ; preds = %entry
  %14 = load ptr, ptr %curr, align 8
  %15 = getelementptr inbounds nuw %Token, ptr %14, i32 0, i32 0
  %16 = load i32, ptr %15, align 4
  %17 = icmp eq i32 %16, 18
  store i1 %17, ptr %sc.40, align 1
  br label %label_489

label_489:                                        ; preds = %label_488, %entry
  %18 = load i1, ptr %sc.40, align 1
  br i1 %18, label %label_490, label %label_491

label_491:                                        ; preds = %label_489
  call void @println(ptr @.str.s89)
  call void @exit(i32 1)
  br label %label_492

label_490:                                        ; preds = %label_489
  %19 = load ptr, ptr %p, align 8
  call void @parser_advance__Struct_Parser(ptr %19)
  br label %label_492

label_492:                                        ; preds = %label_491, %label_490
  %20 = load ptr, ptr %import_node, align 8
  ret ptr %20
}

define ptr @parse_declaration__Struct_Parser(ptr %0) {
entry:
  %p = alloca ptr, align 8
  store ptr %0, ptr %p, align 8
  %1 = load ptr, ptr %p, align 8
  %2 = call i1 @parser_check_val__Struct_Parser_Enum_TokenType_String(ptr %1, i32 18, ptr @.str.s90)
  br i1 %2, label %label_493, label %label_495

label_495:                                        ; preds = %entry
  %3 = load ptr, ptr %p, align 8
  %4 = call i1 @parser_check_val__Struct_Parser_Enum_TokenType_String(ptr %3, i32 18, ptr @.str.s91)
  br i1 %4, label %label_496, label %label_498

label_493:                                        ; preds = %entry
  %5 = load ptr, ptr %p, align 8
  %6 = call ptr @parse_import_statement__Struct_Parser(ptr %5)
  ret ptr %6

label_498:                                        ; preds = %label_495
  %7 = load ptr, ptr %p, align 8
  %8 = call i1 @parser_check_val__Struct_Parser_Enum_TokenType_String(ptr %7, i32 18, ptr @.str.s92)
  br i1 %8, label %label_499, label %label_501

label_496:                                        ; preds = %label_495
  %9 = load ptr, ptr %p, align 8
  %10 = call ptr @parse_variable_decl__Struct_Parser(ptr %9)
  ret ptr %10

label_501:                                        ; preds = %label_498
  %11 = load ptr, ptr %p, align 8
  %12 = call i1 @parser_check_val__Struct_Parser_Enum_TokenType_String(ptr %11, i32 18, ptr @.str.s93)
  br i1 %12, label %label_502, label %label_504

label_499:                                        ; preds = %label_498
  %13 = load ptr, ptr %p, align 8
  %14 = call ptr @parse_extern_fn_decl__Struct_Parser(ptr %13)
  ret ptr %14

label_504:                                        ; preds = %label_501
  %15 = load ptr, ptr %p, align 8
  %16 = call i1 @parser_check_val__Struct_Parser_Enum_TokenType_String(ptr %15, i32 18, ptr @.str.s94)
  br i1 %16, label %label_505, label %label_507

label_502:                                        ; preds = %label_501
  %17 = load ptr, ptr %p, align 8
  %18 = call ptr @parse_function_decl__Struct_Parser(ptr %17)
  ret ptr %18

label_507:                                        ; preds = %label_504
  %19 = load ptr, ptr %p, align 8
  %20 = call i1 @parser_check_val__Struct_Parser_Enum_TokenType_String(ptr %19, i32 18, ptr @.str.s95)
  br i1 %20, label %label_508, label %label_510

label_505:                                        ; preds = %label_504
  %21 = load ptr, ptr %p, align 8
  %22 = call ptr @parse_struct_decl__Struct_Parser(ptr %21)
  ret ptr %22

label_510:                                        ; preds = %label_507
  call void @println(ptr @.str.s96)
  call void @exit(i32 1)
  %23 = call ptr @create_node__Enum_NodeKind(i32 0)
  ret ptr %23

label_508:                                        ; preds = %label_507
  %24 = load ptr, ptr %p, align 8
  %25 = call ptr @parse_enum_decl__Struct_Parser(ptr %24)
  ret ptr %25
}

define ptr @parse_variable_decl__Struct_Parser(ptr %0) {
entry:
  %p = alloca ptr, align 8
  store ptr %0, ptr %p, align 8
  %var_node = alloca ptr, align 8
  %curr = alloca ptr, align 8
  %1 = load ptr, ptr %p, align 8
  call void @parser_expect_val__Struct_Parser_Enum_TokenType_String_String(ptr %1, i32 18, ptr @.str.s107, ptr @.str.s108)
  %2 = call ptr @create_node__Enum_NodeKind(i32 3)
  store ptr %2, ptr %var_node, align 8
  %3 = load ptr, ptr %p, align 8
  %4 = call i1 @parser_match_val__Struct_Parser_Enum_TokenType_String(ptr %3, i32 18, ptr @.str.s109)
  br i1 %4, label %label_527, label %label_529

label_529:                                        ; preds = %label_527, %entry
  %5 = load ptr, ptr %p, align 8
  %6 = call ptr @parser_current__Struct_Parser(ptr %5)
  store ptr %6, ptr %curr, align 8
  %7 = load ptr, ptr %var_node, align 8
  %8 = load ptr, ptr %curr, align 8
  %9 = getelementptr inbounds nuw %Token, ptr %8, i32 0, i32 1
  %10 = load ptr, ptr %9, align 8
  %11 = getelementptr inbounds nuw %ASTNode, ptr %7, i32 0, i32 1
  store ptr %10, ptr %11, align 8
  %12 = load ptr, ptr %p, align 8
  call void @parser_expect__Struct_Parser_Enum_TokenType_String(ptr %12, i32 5, ptr @.str.s110)
  %13 = load ptr, ptr %p, align 8
  %14 = call i1 @parser_match_val__Struct_Parser_Enum_TokenType_String(ptr %13, i32 6, ptr @.str.s111)
  br i1 %14, label %label_530, label %label_532

label_527:                                        ; preds = %entry
  %15 = load ptr, ptr %var_node, align 8
  %16 = getelementptr inbounds nuw %ASTNode, ptr %15, i32 0, i32 3
  store i32 1, ptr %16, align 4
  br label %label_529

label_532:                                        ; preds = %label_530, %label_529
  %17 = load ptr, ptr %p, align 8
  %18 = call i1 @parser_match_val__Struct_Parser_Enum_TokenType_String(ptr %17, i32 12, ptr @.str.s112)
  br i1 %18, label %label_533, label %label_535

label_530:                                        ; preds = %label_529
  %19 = load ptr, ptr %var_node, align 8
  %20 = load ptr, ptr %p, align 8
  %21 = call ptr @parse_type_annotation__Struct_Parser(ptr %20)
  %22 = call ptr @node_to_ptr(ptr %21)
  %23 = getelementptr inbounds nuw %ASTNode, ptr %19, i32 0, i32 5
  store ptr %22, ptr %23, align 8
  br label %label_532

label_535:                                        ; preds = %label_533, %label_532
  %24 = load ptr, ptr %var_node, align 8
  ret ptr %24

label_533:                                        ; preds = %label_532
  %25 = load ptr, ptr %var_node, align 8
  %26 = load ptr, ptr %p, align 8
  %27 = call ptr @parse_expression__Struct_Parser_Int(ptr %26, i32 0)
  %28 = call ptr @node_to_ptr(ptr %27)
  %29 = getelementptr inbounds nuw %ASTNode, ptr %25, i32 0, i32 6
  store ptr %28, ptr %29, align 8
  br label %label_535
}

define ptr @parse_extern_fn_decl__Struct_Parser(ptr %0) {
entry:
  %p = alloca ptr, align 8
  store ptr %0, ptr %p, align 8
  %ext_node = alloca ptr, align 8
  %curr = alloca ptr, align 8
  %last_param = alloca ptr, align 8
  %is_looping = alloca i1, align 1
  %param = alloca ptr, align 8
  %last = alloca ptr, align 8
  %1 = load ptr, ptr %p, align 8
  call void @parser_expect_val__Struct_Parser_Enum_TokenType_String_String(ptr %1, i32 18, ptr @.str.s113, ptr @.str.s114)
  %2 = load ptr, ptr %p, align 8
  call void @parser_expect_val__Struct_Parser_Enum_TokenType_String_String(ptr %2, i32 18, ptr @.str.s115, ptr @.str.s116)
  %3 = call ptr @create_node__Enum_NodeKind(i32 2)
  store ptr %3, ptr %ext_node, align 8
  %4 = load ptr, ptr %p, align 8
  %5 = call ptr @parser_current__Struct_Parser(ptr %4)
  store ptr %5, ptr %curr, align 8
  %6 = load ptr, ptr %ext_node, align 8
  %7 = load ptr, ptr %curr, align 8
  %8 = getelementptr inbounds nuw %Token, ptr %7, i32 0, i32 1
  %9 = load ptr, ptr %8, align 8
  %10 = getelementptr inbounds nuw %ASTNode, ptr %6, i32 0, i32 1
  store ptr %9, ptr %10, align 8
  %11 = load ptr, ptr %p, align 8
  call void @parser_expect__Struct_Parser_Enum_TokenType_String(ptr %11, i32 5, ptr @.str.s117)
  %12 = load ptr, ptr %p, align 8
  call void @parser_expect_val__Struct_Parser_Enum_TokenType_String_String(ptr %12, i32 6, ptr @.str.s118, ptr @.str.s119)
  store ptr @.str.s120, ptr %last_param, align 8
  %13 = load ptr, ptr %p, align 8
  %14 = call i1 @parser_check_val__Struct_Parser_Enum_TokenType_String(ptr %13, i32 6, ptr @.str.s121)
  %15 = icmp eq i1 %14, false
  br i1 %15, label %label_536, label %label_538

label_538:                                        ; preds = %label_541, %entry
  %16 = load ptr, ptr %p, align 8
  call void @parser_expect_val__Struct_Parser_Enum_TokenType_String_String(ptr %16, i32 6, ptr @.str.s127, ptr @.str.s128)
  %17 = load ptr, ptr %p, align 8
  %18 = call i1 @parser_match_val__Struct_Parser_Enum_TokenType_String(ptr %17, i32 15, ptr @.str.s129)
  br i1 %18, label %label_548, label %label_550

label_536:                                        ; preds = %entry
  store i1 true, ptr %is_looping, align 1
  br label %label_539

label_539:                                        ; preds = %label_547, %label_536
  %19 = load i1, ptr %is_looping, align 1
  br i1 %19, label %label_540, label %label_541

label_541:                                        ; preds = %label_539
  br label %label_538

label_540:                                        ; preds = %label_539
  %20 = call ptr @create_node__Enum_NodeKind(i32 30)
  store ptr %20, ptr %param, align 8
  %21 = load ptr, ptr %p, align 8
  %22 = call ptr @parser_current__Struct_Parser(ptr %21)
  store ptr %22, ptr %curr, align 8
  %23 = load ptr, ptr %param, align 8
  %24 = load ptr, ptr %curr, align 8
  %25 = getelementptr inbounds nuw %Token, ptr %24, i32 0, i32 1
  %26 = load ptr, ptr %25, align 8
  %27 = getelementptr inbounds nuw %ASTNode, ptr %23, i32 0, i32 1
  store ptr %26, ptr %27, align 8
  %28 = load ptr, ptr %p, align 8
  call void @parser_expect__Struct_Parser_Enum_TokenType_String(ptr %28, i32 5, ptr @.str.s122)
  %29 = load ptr, ptr %p, align 8
  call void @parser_expect_val__Struct_Parser_Enum_TokenType_String_String(ptr %29, i32 6, ptr @.str.s123, ptr @.str.s124)
  %30 = load ptr, ptr %param, align 8
  %31 = load ptr, ptr %p, align 8
  %32 = call ptr @parse_type_annotation__Struct_Parser(ptr %31)
  %33 = call ptr @node_to_ptr(ptr %32)
  %34 = getelementptr inbounds nuw %ASTNode, ptr %30, i32 0, i32 5
  store ptr %33, ptr %34, align 8
  %35 = load ptr, ptr %ext_node, align 8
  %36 = getelementptr inbounds nuw %ASTNode, ptr %35, i32 0, i32 5
  %37 = load ptr, ptr %36, align 8
  %38 = call i32 @str_equals(ptr %37, ptr @.str.s125)
  %39 = icmp eq i32 %38, 1
  br i1 %39, label %label_542, label %label_543

label_543:                                        ; preds = %label_540
  %40 = load ptr, ptr %last_param, align 8
  %41 = call ptr @ptr_to_node(ptr %40)
  store ptr %41, ptr %last, align 8
  %42 = load ptr, ptr %last, align 8
  %43 = load ptr, ptr %param, align 8
  %44 = call ptr @node_to_ptr(ptr %43)
  %45 = getelementptr inbounds nuw %ASTNode, ptr %42, i32 0, i32 8
  store ptr %44, ptr %45, align 8
  br label %label_544

label_542:                                        ; preds = %label_540
  %46 = load ptr, ptr %ext_node, align 8
  %47 = load ptr, ptr %param, align 8
  %48 = call ptr @node_to_ptr(ptr %47)
  %49 = getelementptr inbounds nuw %ASTNode, ptr %46, i32 0, i32 5
  store ptr %48, ptr %49, align 8
  br label %label_544

label_544:                                        ; preds = %label_543, %label_542
  %50 = load ptr, ptr %param, align 8
  %51 = call ptr @node_to_ptr(ptr %50)
  store ptr %51, ptr %last_param, align 8
  %52 = load ptr, ptr %p, align 8
  %53 = call i1 @parser_match_val__Struct_Parser_Enum_TokenType_String(ptr %52, i32 6, ptr @.str.s126)
  %54 = icmp eq i1 %53, false
  br i1 %54, label %label_545, label %label_547

label_547:                                        ; preds = %label_545, %label_544
  br label %label_539

label_545:                                        ; preds = %label_544
  store i1 false, ptr %is_looping, align 1
  br label %label_547

label_550:                                        ; preds = %label_548, %label_538
  %55 = load ptr, ptr %ext_node, align 8
  ret ptr %55

label_548:                                        ; preds = %label_538
  %56 = load ptr, ptr %ext_node, align 8
  %57 = load ptr, ptr %p, align 8
  %58 = call ptr @parse_type_annotation__Struct_Parser(ptr %57)
  %59 = call ptr @node_to_ptr(ptr %58)
  %60 = getelementptr inbounds nuw %ASTNode, ptr %56, i32 0, i32 6
  store ptr %59, ptr %60, align 8
  br label %label_550
}

define ptr @parse_function_decl__Struct_Parser(ptr %0) {
entry:
  %p = alloca ptr, align 8
  store ptr %0, ptr %p, align 8
  %fn_node = alloca ptr, align 8
  %curr = alloca ptr, align 8
  %last_param = alloca ptr, align 8
  %is_looping = alloca i1, align 1
  %param = alloca ptr, align 8
  %last = alloca ptr, align 8
  %1 = load ptr, ptr %p, align 8
  call void @parser_expect_val__Struct_Parser_Enum_TokenType_String_String(ptr %1, i32 18, ptr @.str.s130, ptr @.str.s131)
  %2 = call ptr @create_node__Enum_NodeKind(i32 4)
  store ptr %2, ptr %fn_node, align 8
  %3 = load ptr, ptr %p, align 8
  %4 = call ptr @parser_current__Struct_Parser(ptr %3)
  store ptr %4, ptr %curr, align 8
  %5 = load ptr, ptr %fn_node, align 8
  %6 = load ptr, ptr %curr, align 8
  %7 = getelementptr inbounds nuw %Token, ptr %6, i32 0, i32 1
  %8 = load ptr, ptr %7, align 8
  %9 = getelementptr inbounds nuw %ASTNode, ptr %5, i32 0, i32 1
  store ptr %8, ptr %9, align 8
  %10 = load ptr, ptr %p, align 8
  call void @parser_expect__Struct_Parser_Enum_TokenType_String(ptr %10, i32 5, ptr @.str.s132)
  %11 = load ptr, ptr %p, align 8
  call void @parser_expect_val__Struct_Parser_Enum_TokenType_String_String(ptr %11, i32 6, ptr @.str.s133, ptr @.str.s134)
  store ptr @.str.s135, ptr %last_param, align 8
  %12 = load ptr, ptr %p, align 8
  %13 = call i1 @parser_check_val__Struct_Parser_Enum_TokenType_String(ptr %12, i32 6, ptr @.str.s136)
  %14 = icmp eq i1 %13, false
  br i1 %14, label %label_551, label %label_553

label_553:                                        ; preds = %label_556, %entry
  %15 = load ptr, ptr %p, align 8
  call void @parser_expect_val__Struct_Parser_Enum_TokenType_String_String(ptr %15, i32 6, ptr @.str.s146, ptr @.str.s147)
  %16 = load ptr, ptr %p, align 8
  %17 = call i1 @parser_match_val__Struct_Parser_Enum_TokenType_String(ptr %16, i32 15, ptr @.str.s148)
  br i1 %17, label %label_569, label %label_571

label_551:                                        ; preds = %entry
  store i1 true, ptr %is_looping, align 1
  br label %label_554

label_554:                                        ; preds = %label_568, %label_551
  %18 = load i1, ptr %is_looping, align 1
  br i1 %18, label %label_555, label %label_556

label_556:                                        ; preds = %label_554
  br label %label_553

label_555:                                        ; preds = %label_554
  %19 = call ptr @create_node__Enum_NodeKind(i32 30)
  store ptr %19, ptr %param, align 8
  %20 = load ptr, ptr %p, align 8
  %21 = call i1 @parser_match_val__Struct_Parser_Enum_TokenType_String(ptr %20, i32 18, ptr @.str.s137)
  br i1 %21, label %label_557, label %label_558

label_558:                                        ; preds = %label_555
  %22 = load ptr, ptr %p, align 8
  %23 = call i1 @parser_match_val__Struct_Parser_Enum_TokenType_String(ptr %22, i32 18, ptr @.str.s139)
  br i1 %23, label %label_560, label %label_562

label_557:                                        ; preds = %label_555
  %24 = load ptr, ptr %param, align 8
  %25 = getelementptr inbounds nuw %ASTNode, ptr %24, i32 0, i32 2
  store ptr @.str.s138, ptr %25, align 8
  br label %label_559

label_559:                                        ; preds = %label_562, %label_557
  %26 = load ptr, ptr %p, align 8
  %27 = call ptr @parser_current__Struct_Parser(ptr %26)
  store ptr %27, ptr %curr, align 8
  %28 = load ptr, ptr %param, align 8
  %29 = load ptr, ptr %curr, align 8
  %30 = getelementptr inbounds nuw %Token, ptr %29, i32 0, i32 1
  %31 = load ptr, ptr %30, align 8
  %32 = getelementptr inbounds nuw %ASTNode, ptr %28, i32 0, i32 1
  store ptr %31, ptr %32, align 8
  %33 = load ptr, ptr %p, align 8
  call void @parser_expect__Struct_Parser_Enum_TokenType_String(ptr %33, i32 5, ptr @.str.s141)
  %34 = load ptr, ptr %p, align 8
  call void @parser_expect_val__Struct_Parser_Enum_TokenType_String_String(ptr %34, i32 6, ptr @.str.s142, ptr @.str.s143)
  %35 = load ptr, ptr %param, align 8
  %36 = load ptr, ptr %p, align 8
  %37 = call ptr @parse_type_annotation__Struct_Parser(ptr %36)
  %38 = call ptr @node_to_ptr(ptr %37)
  %39 = getelementptr inbounds nuw %ASTNode, ptr %35, i32 0, i32 5
  store ptr %38, ptr %39, align 8
  %40 = load ptr, ptr %fn_node, align 8
  %41 = getelementptr inbounds nuw %ASTNode, ptr %40, i32 0, i32 5
  %42 = load ptr, ptr %41, align 8
  %43 = call i32 @str_equals(ptr %42, ptr @.str.s144)
  %44 = icmp eq i32 %43, 1
  br i1 %44, label %label_563, label %label_564

label_562:                                        ; preds = %label_560, %label_558
  br label %label_559

label_560:                                        ; preds = %label_558
  %45 = load ptr, ptr %param, align 8
  %46 = getelementptr inbounds nuw %ASTNode, ptr %45, i32 0, i32 2
  store ptr @.str.s140, ptr %46, align 8
  br label %label_562

label_564:                                        ; preds = %label_559
  %47 = load ptr, ptr %last_param, align 8
  %48 = call ptr @ptr_to_node(ptr %47)
  store ptr %48, ptr %last, align 8
  %49 = load ptr, ptr %last, align 8
  %50 = load ptr, ptr %param, align 8
  %51 = call ptr @node_to_ptr(ptr %50)
  %52 = getelementptr inbounds nuw %ASTNode, ptr %49, i32 0, i32 8
  store ptr %51, ptr %52, align 8
  br label %label_565

label_563:                                        ; preds = %label_559
  %53 = load ptr, ptr %fn_node, align 8
  %54 = load ptr, ptr %param, align 8
  %55 = call ptr @node_to_ptr(ptr %54)
  %56 = getelementptr inbounds nuw %ASTNode, ptr %53, i32 0, i32 5
  store ptr %55, ptr %56, align 8
  br label %label_565

label_565:                                        ; preds = %label_564, %label_563
  %57 = load ptr, ptr %param, align 8
  %58 = call ptr @node_to_ptr(ptr %57)
  store ptr %58, ptr %last_param, align 8
  %59 = load ptr, ptr %p, align 8
  %60 = call i1 @parser_match_val__Struct_Parser_Enum_TokenType_String(ptr %59, i32 6, ptr @.str.s145)
  %61 = icmp eq i1 %60, false
  br i1 %61, label %label_566, label %label_568

label_568:                                        ; preds = %label_566, %label_565
  br label %label_554

label_566:                                        ; preds = %label_565
  store i1 false, ptr %is_looping, align 1
  br label %label_568

label_571:                                        ; preds = %label_569, %label_553
  %62 = load ptr, ptr %fn_node, align 8
  %63 = load ptr, ptr %p, align 8
  %64 = call ptr @parse_block__Struct_Parser(ptr %63)
  %65 = call ptr @node_to_ptr(ptr %64)
  %66 = getelementptr inbounds nuw %ASTNode, ptr %62, i32 0, i32 6
  store ptr %65, ptr %66, align 8
  %67 = load ptr, ptr %fn_node, align 8
  ret ptr %67

label_569:                                        ; preds = %label_553
  %68 = load ptr, ptr %fn_node, align 8
  %69 = load ptr, ptr %p, align 8
  %70 = call ptr @parse_type_annotation__Struct_Parser(ptr %69)
  %71 = call ptr @node_to_ptr(ptr %70)
  %72 = getelementptr inbounds nuw %ASTNode, ptr %68, i32 0, i32 7
  store ptr %71, ptr %72, align 8
  br label %label_571
}

define ptr @parse_struct_decl__Struct_Parser(ptr %0) {
entry:
  %p = alloca ptr, align 8
  store ptr %0, ptr %p, align 8
  %struct_node = alloca ptr, align 8
  %curr = alloca ptr, align 8
  %last_field = alloca ptr, align 8
  %field = alloca ptr, align 8
  %last = alloca ptr, align 8
  %1 = load ptr, ptr %p, align 8
  call void @parser_expect_val__Struct_Parser_Enum_TokenType_String_String(ptr %1, i32 18, ptr @.str.s149, ptr @.str.s150)
  %2 = call ptr @create_node__Enum_NodeKind(i32 5)
  store ptr %2, ptr %struct_node, align 8
  %3 = load ptr, ptr %p, align 8
  %4 = call ptr @parser_current__Struct_Parser(ptr %3)
  store ptr %4, ptr %curr, align 8
  %5 = load ptr, ptr %struct_node, align 8
  %6 = load ptr, ptr %curr, align 8
  %7 = getelementptr inbounds nuw %Token, ptr %6, i32 0, i32 1
  %8 = load ptr, ptr %7, align 8
  %9 = getelementptr inbounds nuw %ASTNode, ptr %5, i32 0, i32 1
  store ptr %8, ptr %9, align 8
  %10 = load ptr, ptr %p, align 8
  call void @parser_expect__Struct_Parser_Enum_TokenType_String(ptr %10, i32 5, ptr @.str.s151)
  %11 = load ptr, ptr %p, align 8
  call void @parser_expect_val__Struct_Parser_Enum_TokenType_String_String(ptr %11, i32 6, ptr @.str.s152, ptr @.str.s153)
  store ptr @.str.s154, ptr %last_field, align 8
  br label %label_572

label_572:                                        ; preds = %label_577, %entry
  %12 = load ptr, ptr %p, align 8
  %13 = call i1 @parser_check_val__Struct_Parser_Enum_TokenType_String(ptr %12, i32 6, ptr @.str.s155)
  %14 = icmp eq i1 %13, false
  br i1 %14, label %label_573, label %label_574

label_574:                                        ; preds = %label_572
  %15 = load ptr, ptr %p, align 8
  call void @parser_expect_val__Struct_Parser_Enum_TokenType_String_String(ptr %15, i32 6, ptr @.str.s161, ptr @.str.s162)
  %16 = load ptr, ptr %struct_node, align 8
  ret ptr %16

label_573:                                        ; preds = %label_572
  %17 = call ptr @create_node__Enum_NodeKind(i32 32)
  store ptr %17, ptr %field, align 8
  %18 = load ptr, ptr %p, align 8
  %19 = call ptr @parser_current__Struct_Parser(ptr %18)
  store ptr %19, ptr %curr, align 8
  %20 = load ptr, ptr %field, align 8
  %21 = load ptr, ptr %curr, align 8
  %22 = getelementptr inbounds nuw %Token, ptr %21, i32 0, i32 1
  %23 = load ptr, ptr %22, align 8
  %24 = getelementptr inbounds nuw %ASTNode, ptr %20, i32 0, i32 1
  store ptr %23, ptr %24, align 8
  %25 = load ptr, ptr %p, align 8
  call void @parser_expect__Struct_Parser_Enum_TokenType_String(ptr %25, i32 5, ptr @.str.s156)
  %26 = load ptr, ptr %p, align 8
  call void @parser_expect_val__Struct_Parser_Enum_TokenType_String_String(ptr %26, i32 6, ptr @.str.s157, ptr @.str.s158)
  %27 = load ptr, ptr %field, align 8
  %28 = load ptr, ptr %p, align 8
  %29 = call ptr @parse_type_annotation__Struct_Parser(ptr %28)
  %30 = call ptr @node_to_ptr(ptr %29)
  %31 = getelementptr inbounds nuw %ASTNode, ptr %27, i32 0, i32 5
  store ptr %30, ptr %31, align 8
  %32 = load ptr, ptr %struct_node, align 8
  %33 = getelementptr inbounds nuw %ASTNode, ptr %32, i32 0, i32 5
  %34 = load ptr, ptr %33, align 8
  %35 = call i32 @str_equals(ptr %34, ptr @.str.s159)
  %36 = icmp eq i32 %35, 1
  br i1 %36, label %label_575, label %label_576

label_576:                                        ; preds = %label_573
  %37 = load ptr, ptr %last_field, align 8
  %38 = call ptr @ptr_to_node(ptr %37)
  store ptr %38, ptr %last, align 8
  %39 = load ptr, ptr %last, align 8
  %40 = load ptr, ptr %field, align 8
  %41 = call ptr @node_to_ptr(ptr %40)
  %42 = getelementptr inbounds nuw %ASTNode, ptr %39, i32 0, i32 8
  store ptr %41, ptr %42, align 8
  br label %label_577

label_575:                                        ; preds = %label_573
  %43 = load ptr, ptr %struct_node, align 8
  %44 = load ptr, ptr %field, align 8
  %45 = call ptr @node_to_ptr(ptr %44)
  %46 = getelementptr inbounds nuw %ASTNode, ptr %43, i32 0, i32 5
  store ptr %45, ptr %46, align 8
  br label %label_577

label_577:                                        ; preds = %label_576, %label_575
  %47 = load ptr, ptr %field, align 8
  %48 = call ptr @node_to_ptr(ptr %47)
  store ptr %48, ptr %last_field, align 8
  %49 = load ptr, ptr %p, align 8
  %50 = call i1 @parser_match_val__Struct_Parser_Enum_TokenType_String(ptr %49, i32 6, ptr @.str.s160)
  br label %label_572
}

define ptr @parse_enum_decl__Struct_Parser(ptr %0) {
entry:
  %p = alloca ptr, align 8
  store ptr %0, ptr %p, align 8
  %enum_node = alloca ptr, align 8
  %curr = alloca ptr, align 8
  %last_var = alloca ptr, align 8
  %variant = alloca ptr, align 8
  %last = alloca ptr, align 8
  %1 = load ptr, ptr %p, align 8
  call void @parser_expect_val__Struct_Parser_Enum_TokenType_String_String(ptr %1, i32 18, ptr @.str.s163, ptr @.str.s164)
  %2 = call ptr @create_node__Enum_NodeKind(i32 6)
  store ptr %2, ptr %enum_node, align 8
  %3 = load ptr, ptr %p, align 8
  %4 = call ptr @parser_current__Struct_Parser(ptr %3)
  store ptr %4, ptr %curr, align 8
  %5 = load ptr, ptr %enum_node, align 8
  %6 = load ptr, ptr %curr, align 8
  %7 = getelementptr inbounds nuw %Token, ptr %6, i32 0, i32 1
  %8 = load ptr, ptr %7, align 8
  %9 = getelementptr inbounds nuw %ASTNode, ptr %5, i32 0, i32 1
  store ptr %8, ptr %9, align 8
  %10 = load ptr, ptr %p, align 8
  call void @parser_expect__Struct_Parser_Enum_TokenType_String(ptr %10, i32 5, ptr @.str.s165)
  %11 = load ptr, ptr %p, align 8
  call void @parser_expect_val__Struct_Parser_Enum_TokenType_String_String(ptr %11, i32 6, ptr @.str.s166, ptr @.str.s167)
  store ptr @.str.s168, ptr %last_var, align 8
  br label %label_578

label_578:                                        ; preds = %label_583, %entry
  %12 = load ptr, ptr %p, align 8
  %13 = call i1 @parser_check_val__Struct_Parser_Enum_TokenType_String(ptr %12, i32 6, ptr @.str.s169)
  %14 = icmp eq i1 %13, false
  br i1 %14, label %label_579, label %label_580

label_580:                                        ; preds = %label_578
  %15 = load ptr, ptr %p, align 8
  call void @parser_expect_val__Struct_Parser_Enum_TokenType_String_String(ptr %15, i32 6, ptr @.str.s173, ptr @.str.s174)
  %16 = load ptr, ptr %enum_node, align 8
  ret ptr %16

label_579:                                        ; preds = %label_578
  %17 = call ptr @create_node__Enum_NodeKind(i32 33)
  store ptr %17, ptr %variant, align 8
  %18 = load ptr, ptr %p, align 8
  %19 = call ptr @parser_current__Struct_Parser(ptr %18)
  store ptr %19, ptr %curr, align 8
  %20 = load ptr, ptr %variant, align 8
  %21 = load ptr, ptr %curr, align 8
  %22 = getelementptr inbounds nuw %Token, ptr %21, i32 0, i32 1
  %23 = load ptr, ptr %22, align 8
  %24 = getelementptr inbounds nuw %ASTNode, ptr %20, i32 0, i32 1
  store ptr %23, ptr %24, align 8
  %25 = load ptr, ptr %p, align 8
  call void @parser_expect__Struct_Parser_Enum_TokenType_String(ptr %25, i32 5, ptr @.str.s170)
  %26 = load ptr, ptr %enum_node, align 8
  %27 = getelementptr inbounds nuw %ASTNode, ptr %26, i32 0, i32 5
  %28 = load ptr, ptr %27, align 8
  %29 = call i32 @str_equals(ptr %28, ptr @.str.s171)
  %30 = icmp eq i32 %29, 1
  br i1 %30, label %label_581, label %label_582

label_582:                                        ; preds = %label_579
  %31 = load ptr, ptr %last_var, align 8
  %32 = call ptr @ptr_to_node(ptr %31)
  store ptr %32, ptr %last, align 8
  %33 = load ptr, ptr %last, align 8
  %34 = load ptr, ptr %variant, align 8
  %35 = call ptr @node_to_ptr(ptr %34)
  %36 = getelementptr inbounds nuw %ASTNode, ptr %33, i32 0, i32 8
  store ptr %35, ptr %36, align 8
  br label %label_583

label_581:                                        ; preds = %label_579
  %37 = load ptr, ptr %enum_node, align 8
  %38 = load ptr, ptr %variant, align 8
  %39 = call ptr @node_to_ptr(ptr %38)
  %40 = getelementptr inbounds nuw %ASTNode, ptr %37, i32 0, i32 5
  store ptr %39, ptr %40, align 8
  br label %label_583

label_583:                                        ; preds = %label_582, %label_581
  %41 = load ptr, ptr %variant, align 8
  %42 = call ptr @node_to_ptr(ptr %41)
  store ptr %42, ptr %last_var, align 8
  %43 = load ptr, ptr %p, align 8
  %44 = call i1 @parser_match_val__Struct_Parser_Enum_TokenType_String(ptr %43, i32 6, ptr @.str.s172)
  br label %label_578
}

define ptr @parse_type_annotation__Struct_Parser(ptr %0) {
entry:
  %p = alloca ptr, align 8
  store ptr %0, ptr %p, align 8
  %type_node = alloca ptr, align 8
  %curr = alloca ptr, align 8
  %1 = call ptr @create_node__Enum_NodeKind(i32 31)
  store ptr %1, ptr %type_node, align 8
  %2 = load ptr, ptr %p, align 8
  %3 = call i1 @parser_match_val__Struct_Parser_Enum_TokenType_String(ptr %2, i32 6, ptr @.str.s97)
  br i1 %3, label %label_511, label %label_513

label_513:                                        ; preds = %entry
  %4 = load ptr, ptr %p, align 8
  %5 = call ptr @parser_current__Struct_Parser(ptr %4)
  store ptr %5, ptr %curr, align 8
  %sc.41 = alloca i1, align 1
  %6 = load ptr, ptr %curr, align 8
  %7 = getelementptr inbounds nuw %Token, ptr %6, i32 0, i32 0
  %8 = load i32, ptr %7, align 4
  %9 = icmp eq i32 %8, 5
  store i1 %9, ptr %sc.41, align 1
  br i1 %9, label %label_515, label %label_514

label_511:                                        ; preds = %entry
  %10 = load ptr, ptr %type_node, align 8
  %11 = getelementptr inbounds nuw %ASTNode, ptr %10, i32 0, i32 3
  store i32 1, ptr %11, align 4
  %12 = load ptr, ptr %type_node, align 8
  %13 = load ptr, ptr %p, align 8
  %14 = call ptr @parse_type_annotation__Struct_Parser(ptr %13)
  %15 = call ptr @node_to_ptr(ptr %14)
  %16 = getelementptr inbounds nuw %ASTNode, ptr %12, i32 0, i32 5
  store ptr %15, ptr %16, align 8
  %17 = load ptr, ptr %p, align 8
  call void @parser_expect_val__Struct_Parser_Enum_TokenType_String_String(ptr %17, i32 6, ptr @.str.s98, ptr @.str.s99)
  %18 = load ptr, ptr %type_node, align 8
  ret ptr %18

label_514:                                        ; preds = %label_513
  %19 = load ptr, ptr %curr, align 8
  %20 = getelementptr inbounds nuw %Token, ptr %19, i32 0, i32 0
  %21 = load i32, ptr %20, align 4
  %22 = icmp eq i32 %21, 18
  store i1 %22, ptr %sc.41, align 1
  br label %label_515

label_515:                                        ; preds = %label_514, %label_513
  %23 = load i1, ptr %sc.41, align 1
  br i1 %23, label %label_516, label %label_517

label_517:                                        ; preds = %label_515
  call void @println(ptr @.str.s100)
  call void @exit(i32 1)
  br label %label_518

label_516:                                        ; preds = %label_515
  %24 = load ptr, ptr %type_node, align 8
  %25 = load ptr, ptr %curr, align 8
  %26 = getelementptr inbounds nuw %Token, ptr %25, i32 0, i32 1
  %27 = load ptr, ptr %26, align 8
  %28 = getelementptr inbounds nuw %ASTNode, ptr %24, i32 0, i32 1
  store ptr %27, ptr %28, align 8
  %29 = load ptr, ptr %p, align 8
  call void @parser_advance__Struct_Parser(ptr %29)
  br label %label_518

label_518:                                        ; preds = %label_517, %label_516
  %sc.42 = alloca i1, align 1
  %30 = load ptr, ptr %type_node, align 8
  %31 = getelementptr inbounds nuw %ASTNode, ptr %30, i32 0, i32 1
  %32 = load ptr, ptr %31, align 8
  %33 = call i32 @str_equals(ptr %32, ptr @.str.s101)
  %34 = icmp eq i32 %33, 1
  store i1 %34, ptr %sc.42, align 1
  br i1 %34, label %label_519, label %label_520

label_520:                                        ; preds = %label_519, %label_518
  %35 = load i1, ptr %sc.42, align 1
  br i1 %35, label %label_521, label %label_523

label_519:                                        ; preds = %label_518
  %36 = load ptr, ptr %p, align 8
  %37 = call i1 @parser_match_val__Struct_Parser_Enum_TokenType_String(ptr %36, i32 9, ptr @.str.s102)
  store i1 %37, ptr %sc.42, align 1
  br label %label_520

label_523:                                        ; preds = %label_521, %label_520
  %38 = load ptr, ptr %type_node, align 8
  ret ptr %38

label_521:                                        ; preds = %label_520
  %39 = load ptr, ptr %type_node, align 8
  %40 = getelementptr inbounds nuw %ASTNode, ptr %39, i32 0, i32 4
  store i32 1, ptr %40, align 4
  %41 = load ptr, ptr %type_node, align 8
  %42 = load ptr, ptr %p, align 8
  %43 = call ptr @parse_type_annotation__Struct_Parser(ptr %42)
  %44 = call ptr @node_to_ptr(ptr %43)
  %45 = getelementptr inbounds nuw %ASTNode, ptr %41, i32 0, i32 5
  store ptr %44, ptr %45, align 8
  %46 = load ptr, ptr %p, align 8
  call void @parser_expect_close_angle__Struct_Parser_String(ptr %46, ptr @.str.s103)
  br label %label_523
}

define void @parser_expect_close_angle__Struct_Parser_String(ptr %0, ptr %1) {
entry:
  %p = alloca ptr, align 8
  store ptr %0, ptr %p, align 8
  %context = alloca ptr, align 8
  store ptr %1, ptr %context, align 8
  %curr = alloca ptr, align 8
  %2 = load ptr, ptr %p, align 8
  %3 = call ptr @parser_current__Struct_Parser(ptr %2)
  store ptr %3, ptr %curr, align 8
  %4 = load ptr, ptr %curr, align 8
  %5 = getelementptr inbounds nuw %Token, ptr %4, i32 0, i32 1
  %6 = load ptr, ptr %5, align 8
  %7 = call i32 @str_equals(ptr %6, ptr @.str.s104)
  %8 = icmp eq i32 %7, 1
  br i1 %8, label %label_524, label %label_526

label_526:                                        ; preds = %entry
  %9 = load ptr, ptr %p, align 8
  %10 = load ptr, ptr %context, align 8
  call void @parser_expect_val__Struct_Parser_Enum_TokenType_String_String(ptr %9, i32 9, ptr @.str.s106, ptr %10)
  ret void

label_524:                                        ; preds = %entry
  %11 = load ptr, ptr %curr, align 8
  %12 = getelementptr inbounds nuw %Token, ptr %11, i32 0, i32 1
  store ptr @.str.s105, ptr %12, align 8
  ret void
}

define ptr @parse_expression__Struct_Parser_Int(ptr %0, i32 %1) {
entry:
  %p = alloca ptr, align 8
  store ptr %0, ptr %p, align 8
  %precedence = alloca i32, align 4
  store i32 %1, ptr %precedence, align 4
  %left = alloca ptr, align 8
  %is_looping = alloca i1, align 1
  %curr = alloca ptr, align 8
  %is_operator = alloca i1, align 1
  %current_precedence = alloca i32, align 4
  %op = alloca ptr, align 8
  %right = alloca ptr, align 8
  %bin_expr = alloca ptr, align 8
  %2 = load ptr, ptr %p, align 8
  %3 = call ptr @parse_unary__Struct_Parser(ptr %2)
  store ptr %3, ptr %left, align 8
  store i1 true, ptr %is_looping, align 1
  br label %label_728

label_728:                                        ; preds = %label_739, %entry
  %4 = load i1, ptr %is_looping, align 1
  br i1 %4, label %label_729, label %label_730

label_730:                                        ; preds = %label_728
  %5 = load ptr, ptr %left, align 8
  ret ptr %5

label_729:                                        ; preds = %label_728
  %6 = load ptr, ptr %p, align 8
  %7 = call ptr @parser_current__Struct_Parser(ptr %6)
  store ptr %7, ptr %curr, align 8
  %sc.61 = alloca i1, align 1
  %sc.62 = alloca i1, align 1
  %sc.63 = alloca i1, align 1
  %8 = load ptr, ptr %curr, align 8
  %9 = getelementptr inbounds nuw %Token, ptr %8, i32 0, i32 0
  %10 = load i32, ptr %9, align 4
  %11 = icmp eq i32 %10, 8
  store i1 %11, ptr %sc.63, align 1
  br i1 %11, label %label_736, label %label_735

label_735:                                        ; preds = %label_729
  %12 = load ptr, ptr %curr, align 8
  %13 = getelementptr inbounds nuw %Token, ptr %12, i32 0, i32 0
  %14 = load i32, ptr %13, align 4
  %15 = icmp eq i32 %14, 9
  store i1 %15, ptr %sc.63, align 1
  br label %label_736

label_736:                                        ; preds = %label_735, %label_729
  %16 = load i1, ptr %sc.63, align 1
  store i1 %16, ptr %sc.62, align 1
  br i1 %16, label %label_734, label %label_733

label_733:                                        ; preds = %label_736
  %17 = load ptr, ptr %curr, align 8
  %18 = getelementptr inbounds nuw %Token, ptr %17, i32 0, i32 1
  %19 = load ptr, ptr %18, align 8
  %20 = call i32 @str_equals(ptr %19, ptr @.str.s263)
  %21 = icmp eq i32 %20, 1
  store i1 %21, ptr %sc.62, align 1
  br label %label_734

label_734:                                        ; preds = %label_733, %label_736
  %22 = load i1, ptr %sc.62, align 1
  store i1 %22, ptr %sc.61, align 1
  br i1 %22, label %label_732, label %label_731

label_731:                                        ; preds = %label_734
  %23 = load ptr, ptr %curr, align 8
  %24 = getelementptr inbounds nuw %Token, ptr %23, i32 0, i32 1
  %25 = load ptr, ptr %24, align 8
  %26 = call i32 @str_equals(ptr %25, ptr @.str.s264)
  %27 = icmp eq i32 %26, 1
  store i1 %27, ptr %sc.61, align 1
  br label %label_732

label_732:                                        ; preds = %label_731, %label_734
  %28 = load i1, ptr %sc.61, align 1
  store i1 %28, ptr %is_operator, align 1
  %29 = load i1, ptr %is_operator, align 1
  %30 = icmp eq i1 %29, false
  br i1 %30, label %label_737, label %label_738

label_738:                                        ; preds = %label_732
  %31 = load ptr, ptr %curr, align 8
  %32 = call i32 @get_operator_precedence__Struct_Token(ptr %31)
  store i32 %32, ptr %current_precedence, align 4
  %sc.64 = alloca i1, align 1
  %33 = load i32, ptr %current_precedence, align 4
  %34 = icmp eq i32 %33, 0
  store i1 %34, ptr %sc.64, align 1
  br i1 %34, label %label_741, label %label_740

label_737:                                        ; preds = %label_732
  store i1 false, ptr %is_looping, align 1
  br label %label_739

label_739:                                        ; preds = %label_744, %label_737
  br label %label_728

label_740:                                        ; preds = %label_738
  %35 = load i32, ptr %current_precedence, align 4
  %36 = load i32, ptr %precedence, align 4
  %37 = icmp slt i32 %35, %36
  store i1 %37, ptr %sc.64, align 1
  br label %label_741

label_741:                                        ; preds = %label_740, %label_738
  %38 = load i1, ptr %sc.64, align 1
  br i1 %38, label %label_742, label %label_743

label_743:                                        ; preds = %label_741
  %39 = load ptr, ptr %curr, align 8
  %40 = getelementptr inbounds nuw %Token, ptr %39, i32 0, i32 1
  %41 = load ptr, ptr %40, align 8
  store ptr %41, ptr %op, align 8
  %42 = load ptr, ptr %p, align 8
  call void @parser_advance__Struct_Parser(ptr %42)
  %43 = load ptr, ptr %p, align 8
  %44 = load i32, ptr %current_precedence, align 4
  %45 = add i32 %44, 1
  %46 = call ptr @parse_expression__Struct_Parser_Int(ptr %43, i32 %45)
  store ptr %46, ptr %right, align 8
  %47 = call ptr @create_node__Enum_NodeKind(i32 20)
  store ptr %47, ptr %bin_expr, align 8
  %48 = load ptr, ptr %bin_expr, align 8
  %49 = load ptr, ptr %op, align 8
  %50 = getelementptr inbounds nuw %ASTNode, ptr %48, i32 0, i32 1
  store ptr %49, ptr %50, align 8
  %51 = load ptr, ptr %bin_expr, align 8
  %52 = load ptr, ptr %left, align 8
  %53 = call ptr @node_to_ptr(ptr %52)
  %54 = getelementptr inbounds nuw %ASTNode, ptr %51, i32 0, i32 5
  store ptr %53, ptr %54, align 8
  %55 = load ptr, ptr %bin_expr, align 8
  %56 = load ptr, ptr %right, align 8
  %57 = call ptr @node_to_ptr(ptr %56)
  %58 = getelementptr inbounds nuw %ASTNode, ptr %55, i32 0, i32 6
  store ptr %57, ptr %58, align 8
  %59 = load ptr, ptr %bin_expr, align 8
  store ptr %59, ptr %left, align 8
  br label %label_744

label_742:                                        ; preds = %label_741
  store i1 false, ptr %is_looping, align 1
  br label %label_744

label_744:                                        ; preds = %label_743, %label_742
  br label %label_739
}

define ptr @parse_block__Struct_Parser(ptr %0) {
entry:
  %p = alloca ptr, align 8
  store ptr %0, ptr %p, align 8
  %block_node = alloca ptr, align 8
  %last_stmt = alloca ptr, align 8
  %stmt = alloca ptr, align 8
  %last = alloca ptr, align 8
  %1 = load ptr, ptr %p, align 8
  call void @parser_expect_val__Struct_Parser_Enum_TokenType_String_String(ptr %1, i32 6, ptr @.str.s175, ptr @.str.s176)
  %2 = call ptr @create_node__Enum_NodeKind(i32 9)
  store ptr %2, ptr %block_node, align 8
  store ptr @.str.s177, ptr %last_stmt, align 8
  br label %label_584

label_584:                                        ; preds = %label_589, %entry
  %3 = load ptr, ptr %p, align 8
  %4 = call i1 @parser_check_val__Struct_Parser_Enum_TokenType_String(ptr %3, i32 6, ptr @.str.s178)
  %5 = icmp eq i1 %4, false
  br i1 %5, label %label_585, label %label_586

label_586:                                        ; preds = %label_584
  %6 = load ptr, ptr %p, align 8
  call void @parser_expect_val__Struct_Parser_Enum_TokenType_String_String(ptr %6, i32 6, ptr @.str.s180, ptr @.str.s181)
  %7 = load ptr, ptr %block_node, align 8
  ret ptr %7

label_585:                                        ; preds = %label_584
  %8 = load ptr, ptr %p, align 8
  %9 = call ptr @parse_statement__Struct_Parser(ptr %8)
  store ptr %9, ptr %stmt, align 8
  %10 = load ptr, ptr %block_node, align 8
  %11 = getelementptr inbounds nuw %ASTNode, ptr %10, i32 0, i32 5
  %12 = load ptr, ptr %11, align 8
  %13 = call i32 @str_equals(ptr %12, ptr @.str.s179)
  %14 = icmp eq i32 %13, 1
  br i1 %14, label %label_587, label %label_588

label_588:                                        ; preds = %label_585
  %15 = load ptr, ptr %last_stmt, align 8
  %16 = call ptr @ptr_to_node(ptr %15)
  store ptr %16, ptr %last, align 8
  %17 = load ptr, ptr %last, align 8
  %18 = load ptr, ptr %stmt, align 8
  %19 = call ptr @node_to_ptr(ptr %18)
  %20 = getelementptr inbounds nuw %ASTNode, ptr %17, i32 0, i32 8
  store ptr %19, ptr %20, align 8
  br label %label_589

label_587:                                        ; preds = %label_585
  %21 = load ptr, ptr %block_node, align 8
  %22 = load ptr, ptr %stmt, align 8
  %23 = call ptr @node_to_ptr(ptr %22)
  %24 = getelementptr inbounds nuw %ASTNode, ptr %21, i32 0, i32 5
  store ptr %23, ptr %24, align 8
  br label %label_589

label_589:                                        ; preds = %label_588, %label_587
  %25 = load ptr, ptr %stmt, align 8
  %26 = call ptr @node_to_ptr(ptr %25)
  store ptr %26, ptr %last_stmt, align 8
  br label %label_584
}

define ptr @parse_statement__Struct_Parser(ptr %0) {
entry:
  %p = alloca ptr, align 8
  store ptr %0, ptr %p, align 8
  %ret_node = alloca ptr, align 8
  %curr = alloca ptr, align 8
  %expr = alloca ptr, align 8
  %assign_stmt = alloca ptr, align 8
  %assign_tok = alloca ptr, align 8
  %op = alloca ptr, align 8
  %combined = alloca ptr, align 8
  %compound = alloca ptr, align 8
  %stmt = alloca ptr, align 8
  %1 = load ptr, ptr %p, align 8
  %2 = call i1 @parser_check_val__Struct_Parser_Enum_TokenType_String(ptr %1, i32 18, ptr @.str.s224)
  br i1 %2, label %label_605, label %label_607

label_607:                                        ; preds = %entry
  %3 = load ptr, ptr %p, align 8
  %4 = call i1 @parser_check_val__Struct_Parser_Enum_TokenType_String(ptr %3, i32 18, ptr @.str.s225)
  br i1 %4, label %label_608, label %label_610

label_605:                                        ; preds = %entry
  %5 = load ptr, ptr %p, align 8
  %6 = call ptr @parse_if_statement__Struct_Parser(ptr %5)
  ret ptr %6

label_610:                                        ; preds = %label_607
  %7 = load ptr, ptr %p, align 8
  %8 = call i1 @parser_check_val__Struct_Parser_Enum_TokenType_String(ptr %7, i32 18, ptr @.str.s226)
  br i1 %8, label %label_611, label %label_613

label_608:                                        ; preds = %label_607
  %9 = load ptr, ptr %p, align 8
  %10 = call ptr @parse_while_statement__Struct_Parser(ptr %9)
  ret ptr %10

label_613:                                        ; preds = %label_610
  %11 = load ptr, ptr %p, align 8
  %12 = call i1 @parser_check_val__Struct_Parser_Enum_TokenType_String(ptr %11, i32 18, ptr @.str.s227)
  br i1 %12, label %label_614, label %label_616

label_611:                                        ; preds = %label_610
  %13 = load ptr, ptr %p, align 8
  %14 = call ptr @parse_loop_statement__Struct_Parser(ptr %13)
  ret ptr %14

label_616:                                        ; preds = %label_613
  %15 = load ptr, ptr %p, align 8
  %16 = call i1 @parser_check_val__Struct_Parser_Enum_TokenType_String(ptr %15, i32 18, ptr @.str.s228)
  br i1 %16, label %label_617, label %label_619

label_614:                                        ; preds = %label_613
  %17 = load ptr, ptr %p, align 8
  %18 = call ptr @parse_match_statement__Struct_Parser(ptr %17)
  ret ptr %18

label_619:                                        ; preds = %label_616
  %19 = load ptr, ptr %p, align 8
  %20 = call i1 @parser_match_val__Struct_Parser_Enum_TokenType_String(ptr %19, i32 18, ptr @.str.s229)
  br i1 %20, label %label_620, label %label_622

label_617:                                        ; preds = %label_616
  %21 = load ptr, ptr %p, align 8
  %22 = call ptr @parse_for_statement__Struct_Parser(ptr %21)
  ret ptr %22

label_622:                                        ; preds = %label_619
  %23 = load ptr, ptr %p, align 8
  %24 = call i1 @parser_match_val__Struct_Parser_Enum_TokenType_String(ptr %23, i32 18, ptr @.str.s230)
  br i1 %24, label %label_623, label %label_625

label_620:                                        ; preds = %label_619
  %25 = call ptr @create_node__Enum_NodeKind(i32 18)
  ret ptr %25

label_625:                                        ; preds = %label_622
  %26 = load ptr, ptr %p, align 8
  %27 = call i1 @parser_match_val__Struct_Parser_Enum_TokenType_String(ptr %26, i32 18, ptr @.str.s231)
  br i1 %27, label %label_626, label %label_628

label_623:                                        ; preds = %label_622
  %28 = call ptr @create_node__Enum_NodeKind(i32 19)
  ret ptr %28

label_628:                                        ; preds = %label_625
  %29 = load ptr, ptr %p, align 8
  %30 = call i1 @parser_check_val__Struct_Parser_Enum_TokenType_String(ptr %29, i32 18, ptr @.str.s233)
  br i1 %30, label %label_634, label %label_636

label_626:                                        ; preds = %label_625
  %31 = call ptr @create_node__Enum_NodeKind(i32 15)
  store ptr %31, ptr %ret_node, align 8
  %32 = load ptr, ptr %p, align 8
  %33 = call ptr @parser_current__Struct_Parser(ptr %32)
  store ptr %33, ptr %curr, align 8
  %sc.43 = alloca i1, align 1
  %34 = load ptr, ptr %curr, align 8
  %35 = getelementptr inbounds nuw %Token, ptr %34, i32 0, i32 0
  %36 = load i32, ptr %35, align 4
  %37 = icmp ne i32 %36, 6
  store i1 %37, ptr %sc.43, align 1
  br i1 %37, label %label_630, label %label_629

label_629:                                        ; preds = %label_626
  %38 = load ptr, ptr %curr, align 8
  %39 = getelementptr inbounds nuw %Token, ptr %38, i32 0, i32 1
  %40 = load ptr, ptr %39, align 8
  %41 = call i32 @str_equals(ptr %40, ptr @.str.s232)
  %42 = icmp eq i32 %41, 0
  store i1 %42, ptr %sc.43, align 1
  br label %label_630

label_630:                                        ; preds = %label_629, %label_626
  %43 = load i1, ptr %sc.43, align 1
  br i1 %43, label %label_631, label %label_633

label_633:                                        ; preds = %label_631, %label_630
  %44 = load ptr, ptr %ret_node, align 8
  ret ptr %44

label_631:                                        ; preds = %label_630
  %45 = load ptr, ptr %ret_node, align 8
  %46 = load ptr, ptr %p, align 8
  %47 = call ptr @parse_expression__Struct_Parser_Int(ptr %46, i32 0)
  %48 = call ptr @node_to_ptr(ptr %47)
  %49 = getelementptr inbounds nuw %ASTNode, ptr %45, i32 0, i32 5
  store ptr %48, ptr %49, align 8
  br label %label_633

label_636:                                        ; preds = %label_628
  %50 = load ptr, ptr %p, align 8
  %51 = call ptr @parse_expression__Struct_Parser_Int(ptr %50, i32 0)
  store ptr %51, ptr %expr, align 8
  %52 = load ptr, ptr %p, align 8
  %53 = call i1 @parser_match_val__Struct_Parser_Enum_TokenType_String(ptr %52, i32 12, ptr @.str.s234)
  br i1 %53, label %label_637, label %label_639

label_634:                                        ; preds = %label_628
  %54 = load ptr, ptr %p, align 8
  %55 = call ptr @parse_variable_decl__Struct_Parser(ptr %54)
  ret ptr %55

label_639:                                        ; preds = %label_636
  %56 = load ptr, ptr %p, align 8
  %57 = call ptr @parser_current__Struct_Parser(ptr %56)
  store ptr %57, ptr %assign_tok, align 8
  %sc.44 = alloca i1, align 1
  %58 = load ptr, ptr %assign_tok, align 8
  %59 = getelementptr inbounds nuw %Token, ptr %58, i32 0, i32 0
  %60 = load i32, ptr %59, align 4
  %61 = icmp eq i32 %60, 12
  store i1 %61, ptr %sc.44, align 1
  br i1 %61, label %label_640, label %label_641

label_637:                                        ; preds = %label_636
  %62 = call ptr @create_node__Enum_NodeKind(i32 16)
  store ptr %62, ptr %assign_stmt, align 8
  %63 = load ptr, ptr %assign_stmt, align 8
  %64 = load ptr, ptr %expr, align 8
  %65 = call ptr @node_to_ptr(ptr %64)
  %66 = getelementptr inbounds nuw %ASTNode, ptr %63, i32 0, i32 5
  store ptr %65, ptr %66, align 8
  %67 = load ptr, ptr %assign_stmt, align 8
  %68 = load ptr, ptr %p, align 8
  %69 = call ptr @parse_expression__Struct_Parser_Int(ptr %68, i32 0)
  %70 = call ptr @node_to_ptr(ptr %69)
  %71 = getelementptr inbounds nuw %ASTNode, ptr %67, i32 0, i32 6
  store ptr %70, ptr %71, align 8
  %72 = load ptr, ptr %assign_stmt, align 8
  ret ptr %72

label_641:                                        ; preds = %label_640, %label_639
  %73 = load i1, ptr %sc.44, align 1
  br i1 %73, label %label_642, label %label_644

label_640:                                        ; preds = %label_639
  %74 = load ptr, ptr %assign_tok, align 8
  %75 = getelementptr inbounds nuw %Token, ptr %74, i32 0, i32 1
  %76 = load ptr, ptr %75, align 8
  %77 = call i32 @str_length(ptr %76)
  %78 = icmp eq i32 %77, 2
  store i1 %78, ptr %sc.44, align 1
  br label %label_641

label_644:                                        ; preds = %label_641
  %79 = call ptr @create_node__Enum_NodeKind(i32 17)
  store ptr %79, ptr %stmt, align 8
  %80 = load ptr, ptr %stmt, align 8
  %81 = load ptr, ptr %expr, align 8
  %82 = call ptr @node_to_ptr(ptr %81)
  %83 = getelementptr inbounds nuw %ASTNode, ptr %80, i32 0, i32 5
  store ptr %82, ptr %83, align 8
  %84 = load ptr, ptr %stmt, align 8
  ret ptr %84

label_642:                                        ; preds = %label_641
  %85 = load ptr, ptr %assign_tok, align 8
  %86 = getelementptr inbounds nuw %Token, ptr %85, i32 0, i32 1
  %87 = load ptr, ptr %86, align 8
  %88 = call ptr @str_substring(ptr %87, i32 0, i32 1)
  store ptr %88, ptr %op, align 8
  %89 = load ptr, ptr %p, align 8
  call void @parser_advance__Struct_Parser(ptr %89)
  %90 = load ptr, ptr %expr, align 8
  %91 = getelementptr inbounds nuw %ASTNode, ptr %90, i32 0, i32 0
  %92 = load i32, ptr %91, align 4
  %93 = icmp ne i32 %92, 23
  br i1 %93, label %label_645, label %label_647

label_647:                                        ; preds = %label_645, %label_642
  %94 = call ptr @create_node__Enum_NodeKind(i32 20)
  store ptr %94, ptr %combined, align 8
  %95 = load ptr, ptr %combined, align 8
  %96 = load ptr, ptr %op, align 8
  %97 = getelementptr inbounds nuw %ASTNode, ptr %95, i32 0, i32 1
  store ptr %96, ptr %97, align 8
  %98 = load ptr, ptr %combined, align 8
  %99 = load ptr, ptr %expr, align 8
  %100 = call ptr @node_to_ptr(ptr %99)
  %101 = getelementptr inbounds nuw %ASTNode, ptr %98, i32 0, i32 5
  store ptr %100, ptr %101, align 8
  %102 = load ptr, ptr %combined, align 8
  %103 = load ptr, ptr %p, align 8
  %104 = call ptr @parse_expression__Struct_Parser_Int(ptr %103, i32 0)
  %105 = call ptr @node_to_ptr(ptr %104)
  %106 = getelementptr inbounds nuw %ASTNode, ptr %102, i32 0, i32 6
  store ptr %105, ptr %106, align 8
  %107 = call ptr @create_node__Enum_NodeKind(i32 16)
  store ptr %107, ptr %compound, align 8
  %108 = load ptr, ptr %compound, align 8
  %109 = load ptr, ptr %expr, align 8
  %110 = call ptr @node_to_ptr(ptr %109)
  %111 = getelementptr inbounds nuw %ASTNode, ptr %108, i32 0, i32 5
  store ptr %110, ptr %111, align 8
  %112 = load ptr, ptr %compound, align 8
  %113 = load ptr, ptr %combined, align 8
  %114 = call ptr @node_to_ptr(ptr %113)
  %115 = getelementptr inbounds nuw %ASTNode, ptr %112, i32 0, i32 6
  store ptr %114, ptr %115, align 8
  %116 = load ptr, ptr %compound, align 8
  ret ptr %116

label_645:                                        ; preds = %label_642
  call void @print(ptr @.str.s235)
  %117 = load ptr, ptr %assign_tok, align 8
  %118 = getelementptr inbounds nuw %Token, ptr %117, i32 0, i32 1
  %119 = load ptr, ptr %118, align 8
  call void @print(ptr %119)
  call void @println(ptr @.str.s236)
  call void @println(ptr @.str.s237)
  call void @exit(i32 1)
  br label %label_647
}

define ptr @parse_if_statement__Struct_Parser(ptr %0) {
entry:
  %p = alloca ptr, align 8
  store ptr %0, ptr %p, align 8
  %if_node = alloca ptr, align 8
  %1 = load ptr, ptr %p, align 8
  call void @parser_expect_val__Struct_Parser_Enum_TokenType_String_String(ptr %1, i32 18, ptr @.str.s182, ptr @.str.s183)
  %2 = call ptr @create_node__Enum_NodeKind(i32 10)
  store ptr %2, ptr %if_node, align 8
  %3 = load ptr, ptr %p, align 8
  call void @parser_expect_val__Struct_Parser_Enum_TokenType_String_String(ptr %3, i32 6, ptr @.str.s184, ptr @.str.s185)
  %4 = load ptr, ptr %if_node, align 8
  %5 = load ptr, ptr %p, align 8
  %6 = call ptr @parse_expression__Struct_Parser_Int(ptr %5, i32 0)
  %7 = call ptr @node_to_ptr(ptr %6)
  %8 = getelementptr inbounds nuw %ASTNode, ptr %4, i32 0, i32 5
  store ptr %7, ptr %8, align 8
  %9 = load ptr, ptr %p, align 8
  call void @parser_expect_val__Struct_Parser_Enum_TokenType_String_String(ptr %9, i32 6, ptr @.str.s186, ptr @.str.s187)
  %10 = load ptr, ptr %if_node, align 8
  %11 = load ptr, ptr %p, align 8
  %12 = call ptr @parse_block__Struct_Parser(ptr %11)
  %13 = call ptr @node_to_ptr(ptr %12)
  %14 = getelementptr inbounds nuw %ASTNode, ptr %10, i32 0, i32 6
  store ptr %13, ptr %14, align 8
  %15 = load ptr, ptr %p, align 8
  %16 = call i1 @parser_match_val__Struct_Parser_Enum_TokenType_String(ptr %15, i32 18, ptr @.str.s188)
  br i1 %16, label %label_590, label %label_592

label_592:                                        ; preds = %label_595, %entry
  %17 = load ptr, ptr %if_node, align 8
  ret ptr %17

label_590:                                        ; preds = %entry
  %18 = load ptr, ptr %p, align 8
  %19 = call i1 @parser_check_val__Struct_Parser_Enum_TokenType_String(ptr %18, i32 18, ptr @.str.s189)
  br i1 %19, label %label_593, label %label_594

label_594:                                        ; preds = %label_590
  %20 = load ptr, ptr %if_node, align 8
  %21 = load ptr, ptr %p, align 8
  %22 = call ptr @parse_block__Struct_Parser(ptr %21)
  %23 = call ptr @node_to_ptr(ptr %22)
  %24 = getelementptr inbounds nuw %ASTNode, ptr %20, i32 0, i32 7
  store ptr %23, ptr %24, align 8
  br label %label_595

label_593:                                        ; preds = %label_590
  %25 = load ptr, ptr %if_node, align 8
  %26 = load ptr, ptr %p, align 8
  %27 = call ptr @parse_if_statement__Struct_Parser(ptr %26)
  %28 = call ptr @node_to_ptr(ptr %27)
  %29 = getelementptr inbounds nuw %ASTNode, ptr %25, i32 0, i32 7
  store ptr %28, ptr %29, align 8
  br label %label_595

label_595:                                        ; preds = %label_594, %label_593
  br label %label_592
}

define ptr @parse_while_statement__Struct_Parser(ptr %0) {
entry:
  %p = alloca ptr, align 8
  store ptr %0, ptr %p, align 8
  %while_node = alloca ptr, align 8
  %1 = load ptr, ptr %p, align 8
  call void @parser_expect_val__Struct_Parser_Enum_TokenType_String_String(ptr %1, i32 18, ptr @.str.s190, ptr @.str.s191)
  %2 = call ptr @create_node__Enum_NodeKind(i32 13)
  store ptr %2, ptr %while_node, align 8
  %3 = load ptr, ptr %p, align 8
  call void @parser_expect_val__Struct_Parser_Enum_TokenType_String_String(ptr %3, i32 6, ptr @.str.s192, ptr @.str.s193)
  %4 = load ptr, ptr %while_node, align 8
  %5 = load ptr, ptr %p, align 8
  %6 = call ptr @parse_expression__Struct_Parser_Int(ptr %5, i32 0)
  %7 = call ptr @node_to_ptr(ptr %6)
  %8 = getelementptr inbounds nuw %ASTNode, ptr %4, i32 0, i32 5
  store ptr %7, ptr %8, align 8
  %9 = load ptr, ptr %p, align 8
  call void @parser_expect_val__Struct_Parser_Enum_TokenType_String_String(ptr %9, i32 6, ptr @.str.s194, ptr @.str.s195)
  %10 = load ptr, ptr %while_node, align 8
  %11 = load ptr, ptr %p, align 8
  %12 = call ptr @parse_block__Struct_Parser(ptr %11)
  %13 = call ptr @node_to_ptr(ptr %12)
  %14 = getelementptr inbounds nuw %ASTNode, ptr %10, i32 0, i32 6
  store ptr %13, ptr %14, align 8
  %15 = load ptr, ptr %while_node, align 8
  ret ptr %15
}

define ptr @parse_loop_statement__Struct_Parser(ptr %0) {
entry:
  %p = alloca ptr, align 8
  store ptr %0, ptr %p, align 8
  %loop_node = alloca ptr, align 8
  %1 = load ptr, ptr %p, align 8
  call void @parser_expect_val__Struct_Parser_Enum_TokenType_String_String(ptr %1, i32 18, ptr @.str.s196, ptr @.str.s197)
  %2 = call ptr @create_node__Enum_NodeKind(i32 14)
  store ptr %2, ptr %loop_node, align 8
  %3 = load ptr, ptr %loop_node, align 8
  %4 = load ptr, ptr %p, align 8
  %5 = call ptr @parse_block__Struct_Parser(ptr %4)
  %6 = call ptr @node_to_ptr(ptr %5)
  %7 = getelementptr inbounds nuw %ASTNode, ptr %3, i32 0, i32 5
  store ptr %6, ptr %7, align 8
  %8 = load ptr, ptr %loop_node, align 8
  ret ptr %8
}

define ptr @parse_for_statement__Struct_Parser(ptr %0) {
entry:
  %p = alloca ptr, align 8
  store ptr %0, ptr %p, align 8
  %for_node = alloca ptr, align 8
  %curr = alloca ptr, align 8
  %1 = load ptr, ptr %p, align 8
  call void @parser_expect_val__Struct_Parser_Enum_TokenType_String_String(ptr %1, i32 18, ptr @.str.s198, ptr @.str.s199)
  %2 = call ptr @create_node__Enum_NodeKind(i32 12)
  store ptr %2, ptr %for_node, align 8
  %3 = load ptr, ptr %p, align 8
  %4 = call ptr @parser_current__Struct_Parser(ptr %3)
  store ptr %4, ptr %curr, align 8
  %5 = load ptr, ptr %for_node, align 8
  %6 = load ptr, ptr %curr, align 8
  %7 = getelementptr inbounds nuw %Token, ptr %6, i32 0, i32 1
  %8 = load ptr, ptr %7, align 8
  %9 = getelementptr inbounds nuw %ASTNode, ptr %5, i32 0, i32 1
  store ptr %8, ptr %9, align 8
  %10 = load ptr, ptr %p, align 8
  call void @parser_expect__Struct_Parser_Enum_TokenType_String(ptr %10, i32 5, ptr @.str.s200)
  %11 = load ptr, ptr %p, align 8
  call void @parser_expect_val__Struct_Parser_Enum_TokenType_String_String(ptr %11, i32 18, ptr @.str.s201, ptr @.str.s202)
  store i32 0, ptr @parser_allow_struct_lit, align 4
  %12 = load ptr, ptr %for_node, align 8
  %13 = load ptr, ptr %p, align 8
  %14 = call ptr @parse_expression__Struct_Parser_Int(ptr %13, i32 0)
  %15 = call ptr @node_to_ptr(ptr %14)
  %16 = getelementptr inbounds nuw %ASTNode, ptr %12, i32 0, i32 5
  store ptr %15, ptr %16, align 8
  %17 = load ptr, ptr %p, align 8
  call void @parser_expect_val__Struct_Parser_Enum_TokenType_String_String(ptr %17, i32 17, ptr @.str.s203, ptr @.str.s204)
  %18 = load ptr, ptr %for_node, align 8
  %19 = load ptr, ptr %p, align 8
  %20 = call ptr @parse_expression__Struct_Parser_Int(ptr %19, i32 0)
  %21 = call ptr @node_to_ptr(ptr %20)
  %22 = getelementptr inbounds nuw %ASTNode, ptr %18, i32 0, i32 6
  store ptr %21, ptr %22, align 8
  store i32 1, ptr @parser_allow_struct_lit, align 4
  %23 = load ptr, ptr %for_node, align 8
  %24 = load ptr, ptr %p, align 8
  %25 = call ptr @parse_block__Struct_Parser(ptr %24)
  %26 = call ptr @node_to_ptr(ptr %25)
  %27 = getelementptr inbounds nuw %ASTNode, ptr %23, i32 0, i32 7
  store ptr %26, ptr %27, align 8
  %28 = load ptr, ptr %for_node, align 8
  ret ptr %28
}

define ptr @parse_match_arm__Struct_Parser(ptr %0) {
entry:
  %p = alloca ptr, align 8
  store ptr %0, ptr %p, align 8
  %arm = alloca ptr, align 8
  %1 = call ptr @create_node__Enum_NodeKind(i32 34)
  store ptr %1, ptr %arm, align 8
  %2 = load ptr, ptr %p, align 8
  %3 = call i1 @parser_match_val__Struct_Parser_Enum_TokenType_String(ptr %2, i32 5, ptr @.str.s205)
  br i1 %3, label %label_596, label %label_597

label_597:                                        ; preds = %entry
  %4 = load ptr, ptr %arm, align 8
  %5 = load ptr, ptr %p, align 8
  %6 = call ptr @parse_expression__Struct_Parser_Int(ptr %5, i32 0)
  %7 = call ptr @node_to_ptr(ptr %6)
  %8 = getelementptr inbounds nuw %ASTNode, ptr %4, i32 0, i32 5
  store ptr %7, ptr %8, align 8
  br label %label_598

label_596:                                        ; preds = %entry
  %9 = load ptr, ptr %arm, align 8
  %10 = getelementptr inbounds nuw %ASTNode, ptr %9, i32 0, i32 1
  store ptr @.str.s206, ptr %10, align 8
  br label %label_598

label_598:                                        ; preds = %label_597, %label_596
  %11 = load ptr, ptr %p, align 8
  call void @parser_expect_val__Struct_Parser_Enum_TokenType_String_String(ptr %11, i32 16, ptr @.str.s207, ptr @.str.s208)
  %12 = load ptr, ptr %arm, align 8
  %13 = load ptr, ptr %p, align 8
  %14 = call ptr @parse_block__Struct_Parser(ptr %13)
  %15 = call ptr @node_to_ptr(ptr %14)
  %16 = getelementptr inbounds nuw %ASTNode, ptr %12, i32 0, i32 6
  store ptr %15, ptr %16, align 8
  %17 = load ptr, ptr %arm, align 8
  ret ptr %17
}

define ptr @parse_match_statement__Struct_Parser(ptr %0) {
entry:
  %p = alloca ptr, align 8
  store ptr %0, ptr %p, align 8
  %match_node = alloca ptr, align 8
  %head = alloca ptr, align 8
  %tail_ptr = alloca ptr, align 8
  %arm = alloca ptr, align 8
  %tail = alloca ptr, align 8
  %1 = load ptr, ptr %p, align 8
  call void @parser_expect_val__Struct_Parser_Enum_TokenType_String_String(ptr %1, i32 18, ptr @.str.s209, ptr @.str.s210)
  %2 = call ptr @create_node__Enum_NodeKind(i32 11)
  store ptr %2, ptr %match_node, align 8
  %3 = load ptr, ptr %p, align 8
  call void @parser_expect_val__Struct_Parser_Enum_TokenType_String_String(ptr %3, i32 6, ptr @.str.s211, ptr @.str.s212)
  %4 = load ptr, ptr %match_node, align 8
  %5 = load ptr, ptr %p, align 8
  %6 = call ptr @parse_expression__Struct_Parser_Int(ptr %5, i32 0)
  %7 = call ptr @node_to_ptr(ptr %6)
  %8 = getelementptr inbounds nuw %ASTNode, ptr %4, i32 0, i32 5
  store ptr %7, ptr %8, align 8
  %9 = load ptr, ptr %p, align 8
  call void @parser_expect_val__Struct_Parser_Enum_TokenType_String_String(ptr %9, i32 6, ptr @.str.s213, ptr @.str.s214)
  %10 = load ptr, ptr %p, align 8
  call void @parser_expect_val__Struct_Parser_Enum_TokenType_String_String(ptr %10, i32 6, ptr @.str.s215, ptr @.str.s216)
  store ptr @.str.s217, ptr %head, align 8
  store ptr @.str.s218, ptr %tail_ptr, align 8
  br label %label_599

label_599:                                        ; preds = %label_604, %entry
  %11 = load ptr, ptr %p, align 8
  %12 = call i1 @parser_check_val__Struct_Parser_Enum_TokenType_String(ptr %11, i32 6, ptr @.str.s219)
  %13 = icmp eq i1 %12, false
  br i1 %13, label %label_600, label %label_601

label_601:                                        ; preds = %label_599
  %14 = load ptr, ptr %p, align 8
  call void @parser_expect_val__Struct_Parser_Enum_TokenType_String_String(ptr %14, i32 6, ptr @.str.s222, ptr @.str.s223)
  %15 = load ptr, ptr %match_node, align 8
  %16 = load ptr, ptr %head, align 8
  %17 = getelementptr inbounds nuw %ASTNode, ptr %15, i32 0, i32 6
  store ptr %16, ptr %17, align 8
  %18 = load ptr, ptr %match_node, align 8
  ret ptr %18

label_600:                                        ; preds = %label_599
  %19 = load ptr, ptr %p, align 8
  %20 = call ptr @parse_match_arm__Struct_Parser(ptr %19)
  store ptr %20, ptr %arm, align 8
  %21 = load ptr, ptr %head, align 8
  %22 = call i32 @str_equals(ptr %21, ptr @.str.s220)
  %23 = icmp eq i32 %22, 1
  br i1 %23, label %label_602, label %label_603

label_603:                                        ; preds = %label_600
  %24 = load ptr, ptr %tail_ptr, align 8
  %25 = call ptr @ptr_to_node(ptr %24)
  store ptr %25, ptr %tail, align 8
  %26 = load ptr, ptr %tail, align 8
  %27 = load ptr, ptr %arm, align 8
  %28 = call ptr @node_to_ptr(ptr %27)
  %29 = getelementptr inbounds nuw %ASTNode, ptr %26, i32 0, i32 8
  store ptr %28, ptr %29, align 8
  %30 = load ptr, ptr %tail, align 8
  %31 = getelementptr inbounds nuw %ASTNode, ptr %30, i32 0, i32 8
  %32 = load ptr, ptr %31, align 8
  store ptr %32, ptr %tail_ptr, align 8
  br label %label_604

label_602:                                        ; preds = %label_600
  %33 = load ptr, ptr %arm, align 8
  %34 = call ptr @node_to_ptr(ptr %33)
  store ptr %34, ptr %head, align 8
  %35 = load ptr, ptr %head, align 8
  store ptr %35, ptr %tail_ptr, align 8
  br label %label_604

label_604:                                        ; preds = %label_603, %label_602
  %36 = load ptr, ptr %p, align 8
  %37 = call i1 @parser_match_val__Struct_Parser_Enum_TokenType_String(ptr %36, i32 6, ptr @.str.s221)
  br label %label_599
}

define i32 @get_operator_precedence__Struct_Token(ptr %0) {
entry:
  %t = alloca ptr, align 8
  store ptr %0, ptr %t, align 8
  %1 = load ptr, ptr %t, align 8
  %2 = getelementptr inbounds nuw %Token, ptr %1, i32 0, i32 1
  %3 = load ptr, ptr %2, align 8
  %4 = call i32 @str_equals(ptr %3, ptr @.str.s238)
  %5 = icmp eq i32 %4, 1
  br i1 %5, label %label_648, label %label_650

label_650:                                        ; preds = %entry
  %6 = load ptr, ptr %t, align 8
  %7 = getelementptr inbounds nuw %Token, ptr %6, i32 0, i32 1
  %8 = load ptr, ptr %7, align 8
  %9 = call i32 @str_equals(ptr %8, ptr @.str.s239)
  %10 = icmp eq i32 %9, 1
  br i1 %10, label %label_651, label %label_653

label_648:                                        ; preds = %entry
  ret i32 1

label_653:                                        ; preds = %label_650
  %11 = load ptr, ptr %t, align 8
  %12 = getelementptr inbounds nuw %Token, ptr %11, i32 0, i32 0
  %13 = load i32, ptr %12, align 4
  %14 = icmp eq i32 %13, 18
  br i1 %14, label %label_654, label %label_656

label_651:                                        ; preds = %label_650
  ret i32 2

label_656:                                        ; preds = %label_653
  %sc.45 = alloca i1, align 1
  %15 = load ptr, ptr %t, align 8
  %16 = getelementptr inbounds nuw %Token, ptr %15, i32 0, i32 1
  %17 = load ptr, ptr %16, align 8
  %18 = call i32 @str_equals(ptr %17, ptr @.str.s240)
  %19 = icmp eq i32 %18, 1
  store i1 %19, ptr %sc.45, align 1
  br i1 %19, label %label_658, label %label_657

label_654:                                        ; preds = %label_653
  ret i32 0

label_657:                                        ; preds = %label_656
  %20 = load ptr, ptr %t, align 8
  %21 = getelementptr inbounds nuw %Token, ptr %20, i32 0, i32 1
  %22 = load ptr, ptr %21, align 8
  %23 = call i32 @str_equals(ptr %22, ptr @.str.s241)
  %24 = icmp eq i32 %23, 1
  store i1 %24, ptr %sc.45, align 1
  br label %label_658

label_658:                                        ; preds = %label_657, %label_656
  %25 = load i1, ptr %sc.45, align 1
  br i1 %25, label %label_659, label %label_661

label_661:                                        ; preds = %label_658
  %sc.46 = alloca i1, align 1
  %sc.47 = alloca i1, align 1
  %sc.48 = alloca i1, align 1
  %26 = load ptr, ptr %t, align 8
  %27 = getelementptr inbounds nuw %Token, ptr %26, i32 0, i32 1
  %28 = load ptr, ptr %27, align 8
  %29 = call i32 @str_equals(ptr %28, ptr @.str.s242)
  %30 = icmp eq i32 %29, 1
  store i1 %30, ptr %sc.48, align 1
  br i1 %30, label %label_667, label %label_666

label_659:                                        ; preds = %label_658
  ret i32 3

label_666:                                        ; preds = %label_661
  %31 = load ptr, ptr %t, align 8
  %32 = getelementptr inbounds nuw %Token, ptr %31, i32 0, i32 1
  %33 = load ptr, ptr %32, align 8
  %34 = call i32 @str_equals(ptr %33, ptr @.str.s243)
  %35 = icmp eq i32 %34, 1
  store i1 %35, ptr %sc.48, align 1
  br label %label_667

label_667:                                        ; preds = %label_666, %label_661
  %36 = load i1, ptr %sc.48, align 1
  store i1 %36, ptr %sc.47, align 1
  br i1 %36, label %label_665, label %label_664

label_664:                                        ; preds = %label_667
  %37 = load ptr, ptr %t, align 8
  %38 = getelementptr inbounds nuw %Token, ptr %37, i32 0, i32 1
  %39 = load ptr, ptr %38, align 8
  %40 = call i32 @str_equals(ptr %39, ptr @.str.s244)
  %41 = icmp eq i32 %40, 1
  store i1 %41, ptr %sc.47, align 1
  br label %label_665

label_665:                                        ; preds = %label_664, %label_667
  %42 = load i1, ptr %sc.47, align 1
  store i1 %42, ptr %sc.46, align 1
  br i1 %42, label %label_663, label %label_662

label_662:                                        ; preds = %label_665
  %43 = load ptr, ptr %t, align 8
  %44 = getelementptr inbounds nuw %Token, ptr %43, i32 0, i32 1
  %45 = load ptr, ptr %44, align 8
  %46 = call i32 @str_equals(ptr %45, ptr @.str.s245)
  %47 = icmp eq i32 %46, 1
  store i1 %47, ptr %sc.46, align 1
  br label %label_663

label_663:                                        ; preds = %label_662, %label_665
  %48 = load i1, ptr %sc.46, align 1
  br i1 %48, label %label_668, label %label_670

label_670:                                        ; preds = %label_663
  %49 = load ptr, ptr %t, align 8
  %50 = getelementptr inbounds nuw %Token, ptr %49, i32 0, i32 1
  %51 = load ptr, ptr %50, align 8
  %52 = call i32 @str_equals(ptr %51, ptr @.str.s246)
  %53 = icmp eq i32 %52, 1
  br i1 %53, label %label_671, label %label_673

label_668:                                        ; preds = %label_663
  ret i32 4

label_673:                                        ; preds = %label_670
  %54 = load ptr, ptr %t, align 8
  %55 = getelementptr inbounds nuw %Token, ptr %54, i32 0, i32 1
  %56 = load ptr, ptr %55, align 8
  %57 = call i32 @str_equals(ptr %56, ptr @.str.s247)
  %58 = icmp eq i32 %57, 1
  br i1 %58, label %label_674, label %label_676

label_671:                                        ; preds = %label_670
  ret i32 5

label_676:                                        ; preds = %label_673
  %59 = load ptr, ptr %t, align 8
  %60 = getelementptr inbounds nuw %Token, ptr %59, i32 0, i32 1
  %61 = load ptr, ptr %60, align 8
  %62 = call i32 @str_equals(ptr %61, ptr @.str.s248)
  %63 = icmp eq i32 %62, 1
  br i1 %63, label %label_677, label %label_679

label_674:                                        ; preds = %label_673
  ret i32 6

label_679:                                        ; preds = %label_676
  %sc.49 = alloca i1, align 1
  %64 = load ptr, ptr %t, align 8
  %65 = getelementptr inbounds nuw %Token, ptr %64, i32 0, i32 1
  %66 = load ptr, ptr %65, align 8
  %67 = call i32 @str_equals(ptr %66, ptr @.str.s249)
  %68 = icmp eq i32 %67, 1
  store i1 %68, ptr %sc.49, align 1
  br i1 %68, label %label_681, label %label_680

label_677:                                        ; preds = %label_676
  ret i32 7

label_680:                                        ; preds = %label_679
  %69 = load ptr, ptr %t, align 8
  %70 = getelementptr inbounds nuw %Token, ptr %69, i32 0, i32 1
  %71 = load ptr, ptr %70, align 8
  %72 = call i32 @str_equals(ptr %71, ptr @.str.s250)
  %73 = icmp eq i32 %72, 1
  store i1 %73, ptr %sc.49, align 1
  br label %label_681

label_681:                                        ; preds = %label_680, %label_679
  %74 = load i1, ptr %sc.49, align 1
  br i1 %74, label %label_682, label %label_684

label_684:                                        ; preds = %label_681
  %sc.50 = alloca i1, align 1
  %75 = load ptr, ptr %t, align 8
  %76 = getelementptr inbounds nuw %Token, ptr %75, i32 0, i32 1
  %77 = load ptr, ptr %76, align 8
  %78 = call i32 @str_equals(ptr %77, ptr @.str.s251)
  %79 = icmp eq i32 %78, 1
  store i1 %79, ptr %sc.50, align 1
  br i1 %79, label %label_686, label %label_685

label_682:                                        ; preds = %label_681
  ret i32 8

label_685:                                        ; preds = %label_684
  %80 = load ptr, ptr %t, align 8
  %81 = getelementptr inbounds nuw %Token, ptr %80, i32 0, i32 1
  %82 = load ptr, ptr %81, align 8
  %83 = call i32 @str_equals(ptr %82, ptr @.str.s252)
  %84 = icmp eq i32 %83, 1
  store i1 %84, ptr %sc.50, align 1
  br label %label_686

label_686:                                        ; preds = %label_685, %label_684
  %85 = load i1, ptr %sc.50, align 1
  br i1 %85, label %label_687, label %label_689

label_689:                                        ; preds = %label_686
  %sc.51 = alloca i1, align 1
  %sc.52 = alloca i1, align 1
  %86 = load ptr, ptr %t, align 8
  %87 = getelementptr inbounds nuw %Token, ptr %86, i32 0, i32 1
  %88 = load ptr, ptr %87, align 8
  %89 = call i32 @str_equals(ptr %88, ptr @.str.s253)
  %90 = icmp eq i32 %89, 1
  store i1 %90, ptr %sc.52, align 1
  br i1 %90, label %label_693, label %label_692

label_687:                                        ; preds = %label_686
  ret i32 9

label_692:                                        ; preds = %label_689
  %91 = load ptr, ptr %t, align 8
  %92 = getelementptr inbounds nuw %Token, ptr %91, i32 0, i32 1
  %93 = load ptr, ptr %92, align 8
  %94 = call i32 @str_equals(ptr %93, ptr @.str.s254)
  %95 = icmp eq i32 %94, 1
  store i1 %95, ptr %sc.52, align 1
  br label %label_693

label_693:                                        ; preds = %label_692, %label_689
  %96 = load i1, ptr %sc.52, align 1
  store i1 %96, ptr %sc.51, align 1
  br i1 %96, label %label_691, label %label_690

label_690:                                        ; preds = %label_693
  %97 = load ptr, ptr %t, align 8
  %98 = getelementptr inbounds nuw %Token, ptr %97, i32 0, i32 1
  %99 = load ptr, ptr %98, align 8
  %100 = call i32 @str_equals(ptr %99, ptr @.str.s255)
  %101 = icmp eq i32 %100, 1
  store i1 %101, ptr %sc.51, align 1
  br label %label_691

label_691:                                        ; preds = %label_690, %label_693
  %102 = load i1, ptr %sc.51, align 1
  br i1 %102, label %label_694, label %label_696

label_696:                                        ; preds = %label_691
  ret i32 0

label_694:                                        ; preds = %label_691
  ret i32 10
}

define ptr @parse_unary__Struct_Parser(ptr %0) {
entry:
  %p = alloca ptr, align 8
  store ptr %0, ptr %p, align 8
  %curr = alloca ptr, align 8
  %is_neg = alloca i1, align 1
  %is_not = alloca i1, align 1
  %is_bnot = alloca i1, align 1
  %op = alloca ptr, align 8
  %operand = alloca ptr, align 8
  %is_number = alloca i1, align 1
  %unary = alloca ptr, align 8
  %1 = load ptr, ptr %p, align 8
  %2 = call ptr @parser_current__Struct_Parser(ptr %1)
  store ptr %2, ptr %curr, align 8
  %sc.53 = alloca i1, align 1
  %3 = load ptr, ptr %curr, align 8
  %4 = getelementptr inbounds nuw %Token, ptr %3, i32 0, i32 0
  %5 = load i32, ptr %4, align 4
  %6 = icmp eq i32 %5, 8
  store i1 %6, ptr %sc.53, align 1
  br i1 %6, label %label_697, label %label_698

label_698:                                        ; preds = %label_697, %entry
  %7 = load i1, ptr %sc.53, align 1
  store i1 %7, ptr %is_neg, align 1
  %sc.54 = alloca i1, align 1
  %8 = load ptr, ptr %curr, align 8
  %9 = getelementptr inbounds nuw %Token, ptr %8, i32 0, i32 0
  %10 = load i32, ptr %9, align 4
  %11 = icmp eq i32 %10, 10
  store i1 %11, ptr %sc.54, align 1
  br i1 %11, label %label_699, label %label_700

label_697:                                        ; preds = %entry
  %12 = load ptr, ptr %curr, align 8
  %13 = getelementptr inbounds nuw %Token, ptr %12, i32 0, i32 1
  %14 = load ptr, ptr %13, align 8
  %15 = call i32 @str_equals(ptr %14, ptr @.str.s256)
  %16 = icmp eq i32 %15, 1
  store i1 %16, ptr %sc.53, align 1
  br label %label_698

label_700:                                        ; preds = %label_699, %label_698
  %17 = load i1, ptr %sc.54, align 1
  store i1 %17, ptr %is_not, align 1
  %sc.55 = alloca i1, align 1
  %18 = load ptr, ptr %curr, align 8
  %19 = getelementptr inbounds nuw %Token, ptr %18, i32 0, i32 0
  %20 = load i32, ptr %19, align 4
  %21 = icmp eq i32 %20, 8
  store i1 %21, ptr %sc.55, align 1
  br i1 %21, label %label_701, label %label_702

label_699:                                        ; preds = %label_698
  %22 = load ptr, ptr %curr, align 8
  %23 = getelementptr inbounds nuw %Token, ptr %22, i32 0, i32 1
  %24 = load ptr, ptr %23, align 8
  %25 = call i32 @str_equals(ptr %24, ptr @.str.s257)
  %26 = icmp eq i32 %25, 1
  store i1 %26, ptr %sc.54, align 1
  br label %label_700

label_702:                                        ; preds = %label_701, %label_700
  %27 = load i1, ptr %sc.55, align 1
  store i1 %27, ptr %is_bnot, align 1
  %sc.56 = alloca i1, align 1
  %sc.57 = alloca i1, align 1
  %28 = load i1, ptr %is_neg, align 1
  store i1 %28, ptr %sc.57, align 1
  br i1 %28, label %label_706, label %label_705

label_701:                                        ; preds = %label_700
  %29 = load ptr, ptr %curr, align 8
  %30 = getelementptr inbounds nuw %Token, ptr %29, i32 0, i32 1
  %31 = load ptr, ptr %30, align 8
  %32 = call i32 @str_equals(ptr %31, ptr @.str.s258)
  %33 = icmp eq i32 %32, 1
  store i1 %33, ptr %sc.55, align 1
  br label %label_702

label_705:                                        ; preds = %label_702
  %34 = load i1, ptr %is_not, align 1
  store i1 %34, ptr %sc.57, align 1
  br label %label_706

label_706:                                        ; preds = %label_705, %label_702
  %35 = load i1, ptr %sc.57, align 1
  store i1 %35, ptr %sc.56, align 1
  br i1 %35, label %label_704, label %label_703

label_703:                                        ; preds = %label_706
  %36 = load i1, ptr %is_bnot, align 1
  store i1 %36, ptr %sc.56, align 1
  br label %label_704

label_704:                                        ; preds = %label_703, %label_706
  %37 = load i1, ptr %sc.56, align 1
  br i1 %37, label %label_707, label %label_709

label_709:                                        ; preds = %label_704
  %38 = load ptr, ptr %p, align 8
  %39 = call ptr @parse_postfix__Struct_Parser(ptr %38)
  ret ptr %39

label_707:                                        ; preds = %label_704
  %40 = load ptr, ptr %curr, align 8
  %41 = getelementptr inbounds nuw %Token, ptr %40, i32 0, i32 1
  %42 = load ptr, ptr %41, align 8
  store ptr %42, ptr %op, align 8
  %43 = load ptr, ptr %p, align 8
  call void @parser_advance__Struct_Parser(ptr %43)
  %44 = load ptr, ptr %p, align 8
  %45 = call ptr @parse_unary__Struct_Parser(ptr %44)
  store ptr %45, ptr %operand, align 8
  %sc.58 = alloca i1, align 1
  %46 = load ptr, ptr %op, align 8
  %47 = call i32 @str_equals(ptr %46, ptr @.str.s259)
  %48 = icmp eq i32 %47, 1
  store i1 %48, ptr %sc.58, align 1
  br i1 %48, label %label_710, label %label_711

label_711:                                        ; preds = %label_710, %label_707
  %49 = load i1, ptr %sc.58, align 1
  br i1 %49, label %label_712, label %label_714

label_710:                                        ; preds = %label_707
  %50 = load ptr, ptr %operand, align 8
  %51 = getelementptr inbounds nuw %ASTNode, ptr %50, i32 0, i32 0
  %52 = load i32, ptr %51, align 4
  %53 = icmp eq i32 %52, 22
  store i1 %53, ptr %sc.58, align 1
  br label %label_711

label_714:                                        ; preds = %label_721, %label_711
  %54 = call ptr @create_node__Enum_NodeKind(i32 21)
  store ptr %54, ptr %unary, align 8
  %55 = load ptr, ptr %unary, align 8
  %56 = load ptr, ptr %op, align 8
  %57 = getelementptr inbounds nuw %ASTNode, ptr %55, i32 0, i32 1
  store ptr %56, ptr %57, align 8
  %58 = load ptr, ptr %unary, align 8
  %59 = load ptr, ptr %operand, align 8
  %60 = call ptr @node_to_ptr(ptr %59)
  %61 = getelementptr inbounds nuw %ASTNode, ptr %58, i32 0, i32 5
  store ptr %60, ptr %61, align 8
  %62 = load ptr, ptr %unary, align 8
  ret ptr %62

label_712:                                        ; preds = %label_711
  %sc.59 = alloca i1, align 1
  %63 = load ptr, ptr %operand, align 8
  %64 = getelementptr inbounds nuw %ASTNode, ptr %63, i32 0, i32 3
  %65 = load i32, ptr %64, align 4
  %66 = icmp eq i32 %65, 2
  store i1 %66, ptr %sc.59, align 1
  br i1 %66, label %label_716, label %label_715

label_715:                                        ; preds = %label_712
  %67 = load ptr, ptr %operand, align 8
  %68 = getelementptr inbounds nuw %ASTNode, ptr %67, i32 0, i32 3
  %69 = load i32, ptr %68, align 4
  %70 = icmp eq i32 %69, 3
  store i1 %70, ptr %sc.59, align 1
  br label %label_716

label_716:                                        ; preds = %label_715, %label_712
  %71 = load i1, ptr %sc.59, align 1
  store i1 %71, ptr %is_number, align 1
  %sc.60 = alloca i1, align 1
  %72 = load i1, ptr %is_number, align 1
  store i1 %72, ptr %sc.60, align 1
  br i1 %72, label %label_717, label %label_718

label_718:                                        ; preds = %label_717, %label_716
  %73 = load i1, ptr %sc.60, align 1
  br i1 %73, label %label_719, label %label_721

label_717:                                        ; preds = %label_716
  %74 = load ptr, ptr %operand, align 8
  %75 = getelementptr inbounds nuw %ASTNode, ptr %74, i32 0, i32 1
  %76 = load ptr, ptr %75, align 8
  %77 = call i32 @str_starts_with(ptr %76, ptr @.str.s260)
  %78 = icmp eq i32 %77, 0
  store i1 %78, ptr %sc.60, align 1
  br label %label_718

label_721:                                        ; preds = %label_718
  br label %label_714

label_719:                                        ; preds = %label_718
  %79 = load ptr, ptr %operand, align 8
  %80 = load ptr, ptr %operand, align 8
  %81 = getelementptr inbounds nuw %ASTNode, ptr %80, i32 0, i32 1
  %82 = load ptr, ptr %81, align 8
  %83 = call ptr @str_concat(ptr @.str.s261, ptr %82)
  %84 = getelementptr inbounds nuw %ASTNode, ptr %79, i32 0, i32 1
  store ptr %83, ptr %84, align 8
  %85 = load ptr, ptr %operand, align 8
  ret ptr %85
}

define ptr @parse_postfix__Struct_Parser(ptr %0) {
entry:
  %p = alloca ptr, align 8
  store ptr %0, ptr %p, align 8
  %expr = alloca ptr, align 8
  %casting = alloca i1, align 1
  %cast = alloca ptr, align 8
  %1 = load ptr, ptr %p, align 8
  %2 = call ptr @parse_primary__Struct_Parser(ptr %1)
  store ptr %2, ptr %expr, align 8
  store i1 true, ptr %casting, align 1
  br label %label_722

label_722:                                        ; preds = %label_727, %entry
  %3 = load i1, ptr %casting, align 1
  br i1 %3, label %label_723, label %label_724

label_724:                                        ; preds = %label_722
  %4 = load ptr, ptr %expr, align 8
  ret ptr %4

label_723:                                        ; preds = %label_722
  %5 = load ptr, ptr %p, align 8
  %6 = call i1 @parser_match_val__Struct_Parser_Enum_TokenType_String(ptr %5, i32 18, ptr @.str.s262)
  br i1 %6, label %label_725, label %label_726

label_726:                                        ; preds = %label_723
  store i1 false, ptr %casting, align 1
  br label %label_727

label_725:                                        ; preds = %label_723
  %7 = call ptr @create_node__Enum_NodeKind(i32 29)
  store ptr %7, ptr %cast, align 8
  %8 = load ptr, ptr %cast, align 8
  %9 = load ptr, ptr %expr, align 8
  %10 = call ptr @node_to_ptr(ptr %9)
  %11 = getelementptr inbounds nuw %ASTNode, ptr %8, i32 0, i32 5
  store ptr %10, ptr %11, align 8
  %12 = load ptr, ptr %cast, align 8
  %13 = load ptr, ptr %p, align 8
  %14 = call ptr @parse_type_annotation__Struct_Parser(ptr %13)
  %15 = call ptr @node_to_ptr(ptr %14)
  %16 = getelementptr inbounds nuw %ASTNode, ptr %12, i32 0, i32 6
  store ptr %15, ptr %16, align 8
  %17 = load ptr, ptr %cast, align 8
  store ptr %17, ptr %expr, align 8
  br label %label_727

label_727:                                        ; preds = %label_726, %label_725
  br label %label_722
}

define ptr @parse_primary__Struct_Parser(ptr %0) {
entry:
  %p = alloca ptr, align 8
  store ptr %0, ptr %p, align 8
  %curr = alloca ptr, align 8
  %lit = alloca ptr, align 8
  %next_tok = alloca ptr, align 8
  %struct_lit = alloca ptr, align 8
  %last_field = alloca ptr, align 8
  %field = alloca ptr, align 8
  %field_tok = alloca ptr, align 8
  %last = alloca ptr, align 8
  %ident = alloca ptr, align 8
  %expr = alloca ptr, align 8
  %is_looping = alloca i1, align 1
  %call = alloca ptr, align 8
  %last_arg = alloca ptr, align 8
  %is_arg_looping = alloca i1, align 1
  %arg = alloca ptr, align 8
  %index_node = alloca ptr, align 8
  %member_node = alloca ptr, align 8
  %curr_mem = alloca ptr, align 8
  %expr_inner = alloca ptr, align 8
  %array_lit = alloca ptr, align 8
  %last_elem = alloca ptr, align 8
  %elem = alloca ptr, align 8
  %1 = load ptr, ptr %p, align 8
  %2 = call ptr @parser_current__Struct_Parser(ptr %1)
  store ptr %2, ptr %curr, align 8
  %sc.65 = alloca i1, align 1
  %sc.66 = alloca i1, align 1
  %sc.67 = alloca i1, align 1
  %sc.68 = alloca i1, align 1
  %3 = load ptr, ptr %curr, align 8
  %4 = getelementptr inbounds nuw %Token, ptr %3, i32 0, i32 0
  %5 = load i32, ptr %4, align 4
  %6 = icmp eq i32 %5, 2
  store i1 %6, ptr %sc.68, align 1
  br i1 %6, label %label_752, label %label_751

label_751:                                        ; preds = %entry
  %7 = load ptr, ptr %curr, align 8
  %8 = getelementptr inbounds nuw %Token, ptr %7, i32 0, i32 0
  %9 = load i32, ptr %8, align 4
  %10 = icmp eq i32 %9, 3
  store i1 %10, ptr %sc.68, align 1
  br label %label_752

label_752:                                        ; preds = %label_751, %entry
  %11 = load i1, ptr %sc.68, align 1
  store i1 %11, ptr %sc.67, align 1
  br i1 %11, label %label_750, label %label_749

label_749:                                        ; preds = %label_752
  %12 = load ptr, ptr %curr, align 8
  %13 = getelementptr inbounds nuw %Token, ptr %12, i32 0, i32 0
  %14 = load i32, ptr %13, align 4
  %15 = icmp eq i32 %14, 0
  store i1 %15, ptr %sc.67, align 1
  br label %label_750

label_750:                                        ; preds = %label_749, %label_752
  %16 = load i1, ptr %sc.67, align 1
  store i1 %16, ptr %sc.66, align 1
  br i1 %16, label %label_748, label %label_747

label_747:                                        ; preds = %label_750
  %17 = load ptr, ptr %curr, align 8
  %18 = getelementptr inbounds nuw %Token, ptr %17, i32 0, i32 0
  %19 = load i32, ptr %18, align 4
  %20 = icmp eq i32 %19, 4
  store i1 %20, ptr %sc.66, align 1
  br label %label_748

label_748:                                        ; preds = %label_747, %label_750
  %21 = load i1, ptr %sc.66, align 1
  store i1 %21, ptr %sc.65, align 1
  br i1 %21, label %label_746, label %label_745

label_745:                                        ; preds = %label_748
  %22 = load ptr, ptr %curr, align 8
  %23 = getelementptr inbounds nuw %Token, ptr %22, i32 0, i32 0
  %24 = load i32, ptr %23, align 4
  %25 = icmp eq i32 %24, 1
  store i1 %25, ptr %sc.65, align 1
  br label %label_746

label_746:                                        ; preds = %label_745, %label_748
  %26 = load i1, ptr %sc.65, align 1
  br i1 %26, label %label_753, label %label_755

label_755:                                        ; preds = %label_746
  %27 = load ptr, ptr %curr, align 8
  %28 = getelementptr inbounds nuw %Token, ptr %27, i32 0, i32 0
  %29 = load i32, ptr %28, align 4
  %30 = icmp eq i32 %29, 5
  br i1 %30, label %label_756, label %label_758

label_753:                                        ; preds = %label_746
  %31 = call ptr @create_node__Enum_NodeKind(i32 22)
  store ptr %31, ptr %lit, align 8
  %32 = load ptr, ptr %lit, align 8
  %33 = load ptr, ptr %curr, align 8
  %34 = getelementptr inbounds nuw %Token, ptr %33, i32 0, i32 0
  %35 = load i32, ptr %34, align 4
  %36 = getelementptr inbounds nuw %ASTNode, ptr %32, i32 0, i32 3
  store i32 %35, ptr %36, align 4
  %37 = load ptr, ptr %lit, align 8
  %38 = load ptr, ptr %curr, align 8
  %39 = getelementptr inbounds nuw %Token, ptr %38, i32 0, i32 1
  %40 = load ptr, ptr %39, align 8
  %41 = getelementptr inbounds nuw %ASTNode, ptr %37, i32 0, i32 1
  store ptr %40, ptr %41, align 8
  %42 = load ptr, ptr %p, align 8
  call void @parser_advance__Struct_Parser(ptr %42)
  %43 = load ptr, ptr %lit, align 8
  ret ptr %43

label_758:                                        ; preds = %label_765, %label_755
  %44 = load ptr, ptr %curr, align 8
  %45 = getelementptr inbounds nuw %Token, ptr %44, i32 0, i32 0
  %46 = load i32, ptr %45, align 4
  %47 = icmp eq i32 %46, 5
  br i1 %47, label %label_772, label %label_774

label_756:                                        ; preds = %label_755
  %48 = load ptr, ptr %p, align 8
  %49 = call ptr @parser_peek__Struct_Parser(ptr %48)
  store ptr %49, ptr %next_tok, align 8
  %sc.69 = alloca i1, align 1
  %sc.70 = alloca i1, align 1
  %50 = load ptr, ptr %next_tok, align 8
  %51 = getelementptr inbounds nuw %Token, ptr %50, i32 0, i32 0
  %52 = load i32, ptr %51, align 4
  %53 = icmp eq i32 %52, 6
  store i1 %53, ptr %sc.70, align 1
  br i1 %53, label %label_761, label %label_762

label_762:                                        ; preds = %label_761, %label_756
  %54 = load i1, ptr %sc.70, align 1
  store i1 %54, ptr %sc.69, align 1
  br i1 %54, label %label_759, label %label_760

label_761:                                        ; preds = %label_756
  %55 = load ptr, ptr %next_tok, align 8
  %56 = getelementptr inbounds nuw %Token, ptr %55, i32 0, i32 1
  %57 = load ptr, ptr %56, align 8
  %58 = call i32 @str_equals(ptr %57, ptr @.str.s265)
  %59 = icmp eq i32 %58, 1
  store i1 %59, ptr %sc.70, align 1
  br label %label_762

label_760:                                        ; preds = %label_759, %label_762
  %60 = load i1, ptr %sc.69, align 1
  br i1 %60, label %label_763, label %label_765

label_759:                                        ; preds = %label_762
  %61 = load i32, ptr @parser_allow_struct_lit, align 4
  %62 = icmp eq i32 %61, 1
  store i1 %62, ptr %sc.69, align 1
  br label %label_760

label_765:                                        ; preds = %label_760
  br label %label_758

label_763:                                        ; preds = %label_760
  %63 = call ptr @create_node__Enum_NodeKind(i32 28)
  store ptr %63, ptr %struct_lit, align 8
  %64 = load ptr, ptr %struct_lit, align 8
  %65 = load ptr, ptr %curr, align 8
  %66 = getelementptr inbounds nuw %Token, ptr %65, i32 0, i32 1
  %67 = load ptr, ptr %66, align 8
  %68 = getelementptr inbounds nuw %ASTNode, ptr %64, i32 0, i32 1
  store ptr %67, ptr %68, align 8
  %69 = load ptr, ptr %p, align 8
  call void @parser_advance__Struct_Parser(ptr %69)
  %70 = load ptr, ptr %p, align 8
  call void @parser_expect_val__Struct_Parser_Enum_TokenType_String_String(ptr %70, i32 6, ptr @.str.s266, ptr @.str.s267)
  store ptr @.str.s268, ptr %last_field, align 8
  br label %label_766

label_766:                                        ; preds = %label_771, %label_763
  %71 = load ptr, ptr %p, align 8
  %72 = call i1 @parser_check_val__Struct_Parser_Enum_TokenType_String(ptr %71, i32 6, ptr @.str.s269)
  %73 = icmp eq i1 %72, false
  br i1 %73, label %label_767, label %label_768

label_768:                                        ; preds = %label_766
  %74 = load ptr, ptr %p, align 8
  call void @parser_expect_val__Struct_Parser_Enum_TokenType_String_String(ptr %74, i32 6, ptr @.str.s275, ptr @.str.s276)
  %75 = load ptr, ptr %struct_lit, align 8
  ret ptr %75

label_767:                                        ; preds = %label_766
  %76 = call ptr @create_node__Enum_NodeKind(i32 32)
  store ptr %76, ptr %field, align 8
  %77 = load ptr, ptr %p, align 8
  %78 = call ptr @parser_current__Struct_Parser(ptr %77)
  store ptr %78, ptr %field_tok, align 8
  %79 = load ptr, ptr %field, align 8
  %80 = load ptr, ptr %field_tok, align 8
  %81 = getelementptr inbounds nuw %Token, ptr %80, i32 0, i32 1
  %82 = load ptr, ptr %81, align 8
  %83 = getelementptr inbounds nuw %ASTNode, ptr %79, i32 0, i32 1
  store ptr %82, ptr %83, align 8
  %84 = load ptr, ptr %p, align 8
  call void @parser_expect__Struct_Parser_Enum_TokenType_String(ptr %84, i32 5, ptr @.str.s270)
  %85 = load ptr, ptr %p, align 8
  call void @parser_expect_val__Struct_Parser_Enum_TokenType_String_String(ptr %85, i32 6, ptr @.str.s271, ptr @.str.s272)
  %86 = load ptr, ptr %field, align 8
  %87 = load ptr, ptr %p, align 8
  %88 = call ptr @parse_expression__Struct_Parser_Int(ptr %87, i32 0)
  %89 = call ptr @node_to_ptr(ptr %88)
  %90 = getelementptr inbounds nuw %ASTNode, ptr %86, i32 0, i32 5
  store ptr %89, ptr %90, align 8
  %91 = load ptr, ptr %struct_lit, align 8
  %92 = getelementptr inbounds nuw %ASTNode, ptr %91, i32 0, i32 5
  %93 = load ptr, ptr %92, align 8
  %94 = call i32 @str_equals(ptr %93, ptr @.str.s273)
  %95 = icmp eq i32 %94, 1
  br i1 %95, label %label_769, label %label_770

label_770:                                        ; preds = %label_767
  %96 = load ptr, ptr %last_field, align 8
  %97 = call ptr @ptr_to_node(ptr %96)
  store ptr %97, ptr %last, align 8
  %98 = load ptr, ptr %last, align 8
  %99 = load ptr, ptr %field, align 8
  %100 = call ptr @node_to_ptr(ptr %99)
  %101 = getelementptr inbounds nuw %ASTNode, ptr %98, i32 0, i32 8
  store ptr %100, ptr %101, align 8
  br label %label_771

label_769:                                        ; preds = %label_767
  %102 = load ptr, ptr %struct_lit, align 8
  %103 = load ptr, ptr %field, align 8
  %104 = call ptr @node_to_ptr(ptr %103)
  %105 = getelementptr inbounds nuw %ASTNode, ptr %102, i32 0, i32 5
  store ptr %104, ptr %105, align 8
  br label %label_771

label_771:                                        ; preds = %label_770, %label_769
  %106 = load ptr, ptr %field, align 8
  %107 = call ptr @node_to_ptr(ptr %106)
  store ptr %107, ptr %last_field, align 8
  %108 = load ptr, ptr %p, align 8
  %109 = call i1 @parser_match_val__Struct_Parser_Enum_TokenType_String(ptr %108, i32 6, ptr @.str.s274)
  br label %label_766

label_774:                                        ; preds = %label_758
  %110 = load ptr, ptr %p, align 8
  %111 = call i1 @parser_match_val__Struct_Parser_Enum_TokenType_String(ptr %110, i32 6, ptr @.str.s289)
  br i1 %111, label %label_799, label %label_801

label_772:                                        ; preds = %label_758
  %112 = call ptr @create_node__Enum_NodeKind(i32 23)
  store ptr %112, ptr %ident, align 8
  %113 = load ptr, ptr %ident, align 8
  %114 = load ptr, ptr %curr, align 8
  %115 = getelementptr inbounds nuw %Token, ptr %114, i32 0, i32 1
  %116 = load ptr, ptr %115, align 8
  %117 = getelementptr inbounds nuw %ASTNode, ptr %113, i32 0, i32 1
  store ptr %116, ptr %117, align 8
  %118 = load ptr, ptr %p, align 8
  call void @parser_advance__Struct_Parser(ptr %118)
  %119 = load ptr, ptr %ident, align 8
  store ptr %119, ptr %expr, align 8
  store i1 true, ptr %is_looping, align 1
  br label %label_775

label_775:                                        ; preds = %label_780, %label_772
  %120 = load i1, ptr %is_looping, align 1
  br i1 %120, label %label_776, label %label_777

label_777:                                        ; preds = %label_775
  %121 = load ptr, ptr %expr, align 8
  ret ptr %121

label_776:                                        ; preds = %label_775
  %122 = load ptr, ptr %p, align 8
  %123 = call i1 @parser_match_val__Struct_Parser_Enum_TokenType_String(ptr %122, i32 6, ptr @.str.s277)
  br i1 %123, label %label_778, label %label_779

label_779:                                        ; preds = %label_776
  %124 = load ptr, ptr %p, align 8
  %125 = call i1 @parser_match_val__Struct_Parser_Enum_TokenType_String(ptr %124, i32 6, ptr @.str.s284)
  br i1 %125, label %label_793, label %label_794

label_778:                                        ; preds = %label_776
  %126 = call ptr @create_node__Enum_NodeKind(i32 24)
  store ptr %126, ptr %call, align 8
  %127 = load ptr, ptr %call, align 8
  %128 = load ptr, ptr %expr, align 8
  %129 = call ptr @node_to_ptr(ptr %128)
  %130 = getelementptr inbounds nuw %ASTNode, ptr %127, i32 0, i32 5
  store ptr %129, ptr %130, align 8
  store ptr @.str.s278, ptr %last_arg, align 8
  %131 = load ptr, ptr %p, align 8
  %132 = call i1 @parser_check_val__Struct_Parser_Enum_TokenType_String(ptr %131, i32 6, ptr @.str.s279)
  %133 = icmp eq i1 %132, false
  br i1 %133, label %label_781, label %label_783

label_783:                                        ; preds = %label_786, %label_778
  %134 = load ptr, ptr %p, align 8
  call void @parser_expect_val__Struct_Parser_Enum_TokenType_String_String(ptr %134, i32 6, ptr @.str.s282, ptr @.str.s283)
  %135 = load ptr, ptr %call, align 8
  store ptr %135, ptr %expr, align 8
  br label %label_780

label_781:                                        ; preds = %label_778
  store i1 true, ptr %is_arg_looping, align 1
  br label %label_784

label_784:                                        ; preds = %label_792, %label_781
  %136 = load i1, ptr %is_arg_looping, align 1
  br i1 %136, label %label_785, label %label_786

label_786:                                        ; preds = %label_784
  br label %label_783

label_785:                                        ; preds = %label_784
  %137 = load ptr, ptr %p, align 8
  %138 = call ptr @parse_expression__Struct_Parser_Int(ptr %137, i32 0)
  store ptr %138, ptr %arg, align 8
  %139 = load ptr, ptr %call, align 8
  %140 = getelementptr inbounds nuw %ASTNode, ptr %139, i32 0, i32 6
  %141 = load ptr, ptr %140, align 8
  %142 = call i32 @str_equals(ptr %141, ptr @.str.s280)
  %143 = icmp eq i32 %142, 1
  br i1 %143, label %label_787, label %label_788

label_788:                                        ; preds = %label_785
  %144 = load ptr, ptr %last_arg, align 8
  %145 = call ptr @ptr_to_node(ptr %144)
  store ptr %145, ptr %last, align 8
  %146 = load ptr, ptr %last, align 8
  %147 = load ptr, ptr %arg, align 8
  %148 = call ptr @node_to_ptr(ptr %147)
  %149 = getelementptr inbounds nuw %ASTNode, ptr %146, i32 0, i32 8
  store ptr %148, ptr %149, align 8
  br label %label_789

label_787:                                        ; preds = %label_785
  %150 = load ptr, ptr %call, align 8
  %151 = load ptr, ptr %arg, align 8
  %152 = call ptr @node_to_ptr(ptr %151)
  %153 = getelementptr inbounds nuw %ASTNode, ptr %150, i32 0, i32 6
  store ptr %152, ptr %153, align 8
  br label %label_789

label_789:                                        ; preds = %label_788, %label_787
  %154 = load ptr, ptr %arg, align 8
  %155 = call ptr @node_to_ptr(ptr %154)
  store ptr %155, ptr %last_arg, align 8
  %156 = load ptr, ptr %p, align 8
  %157 = call i1 @parser_match_val__Struct_Parser_Enum_TokenType_String(ptr %156, i32 6, ptr @.str.s281)
  %158 = icmp eq i1 %157, false
  br i1 %158, label %label_790, label %label_792

label_792:                                        ; preds = %label_790, %label_789
  br label %label_784

label_790:                                        ; preds = %label_789
  store i1 false, ptr %is_arg_looping, align 1
  br label %label_792

label_780:                                        ; preds = %label_795, %label_783
  br label %label_775

label_794:                                        ; preds = %label_779
  %159 = load ptr, ptr %p, align 8
  %160 = call i1 @parser_match_val__Struct_Parser_Enum_TokenType_String(ptr %159, i32 6, ptr @.str.s287)
  br i1 %160, label %label_796, label %label_797

label_793:                                        ; preds = %label_779
  %161 = call ptr @create_node__Enum_NodeKind(i32 26)
  store ptr %161, ptr %index_node, align 8
  %162 = load ptr, ptr %index_node, align 8
  %163 = load ptr, ptr %expr, align 8
  %164 = call ptr @node_to_ptr(ptr %163)
  %165 = getelementptr inbounds nuw %ASTNode, ptr %162, i32 0, i32 5
  store ptr %164, ptr %165, align 8
  %166 = load ptr, ptr %index_node, align 8
  %167 = load ptr, ptr %p, align 8
  %168 = call ptr @parse_expression__Struct_Parser_Int(ptr %167, i32 0)
  %169 = call ptr @node_to_ptr(ptr %168)
  %170 = getelementptr inbounds nuw %ASTNode, ptr %166, i32 0, i32 6
  store ptr %169, ptr %170, align 8
  %171 = load ptr, ptr %p, align 8
  call void @parser_expect_val__Struct_Parser_Enum_TokenType_String_String(ptr %171, i32 6, ptr @.str.s285, ptr @.str.s286)
  %172 = load ptr, ptr %index_node, align 8
  store ptr %172, ptr %expr, align 8
  br label %label_795

label_795:                                        ; preds = %label_798, %label_793
  br label %label_780

label_797:                                        ; preds = %label_794
  store i1 false, ptr %is_looping, align 1
  br label %label_798

label_796:                                        ; preds = %label_794
  %173 = call ptr @create_node__Enum_NodeKind(i32 25)
  store ptr %173, ptr %member_node, align 8
  %174 = load ptr, ptr %member_node, align 8
  %175 = load ptr, ptr %expr, align 8
  %176 = call ptr @node_to_ptr(ptr %175)
  %177 = getelementptr inbounds nuw %ASTNode, ptr %174, i32 0, i32 5
  store ptr %176, ptr %177, align 8
  %178 = load ptr, ptr %p, align 8
  %179 = call ptr @parser_current__Struct_Parser(ptr %178)
  store ptr %179, ptr %curr_mem, align 8
  %180 = load ptr, ptr %member_node, align 8
  %181 = load ptr, ptr %curr_mem, align 8
  %182 = getelementptr inbounds nuw %Token, ptr %181, i32 0, i32 1
  %183 = load ptr, ptr %182, align 8
  %184 = getelementptr inbounds nuw %ASTNode, ptr %180, i32 0, i32 1
  store ptr %183, ptr %184, align 8
  %185 = load ptr, ptr %p, align 8
  call void @parser_expect__Struct_Parser_Enum_TokenType_String(ptr %185, i32 5, ptr @.str.s288)
  %186 = load ptr, ptr %member_node, align 8
  store ptr %186, ptr %expr, align 8
  br label %label_798

label_798:                                        ; preds = %label_797, %label_796
  br label %label_795

label_801:                                        ; preds = %label_774
  %187 = load ptr, ptr %p, align 8
  %188 = call i1 @parser_match_val__Struct_Parser_Enum_TokenType_String(ptr %187, i32 6, ptr @.str.s292)
  br i1 %188, label %label_802, label %label_804

label_799:                                        ; preds = %label_774
  %189 = load ptr, ptr %p, align 8
  %190 = call ptr @parse_expression__Struct_Parser_Int(ptr %189, i32 0)
  store ptr %190, ptr %expr_inner, align 8
  %191 = load ptr, ptr %p, align 8
  call void @parser_expect_val__Struct_Parser_Enum_TokenType_String_String(ptr %191, i32 6, ptr @.str.s290, ptr @.str.s291)
  %192 = load ptr, ptr %expr_inner, align 8
  ret ptr %192

label_804:                                        ; preds = %label_801
  call void @print(ptr @.str.s299)
  %193 = load ptr, ptr %curr, align 8
  %194 = getelementptr inbounds nuw %Token, ptr %193, i32 0, i32 0
  %195 = load i32, ptr %194, align 4
  %196 = call ptr @type_to_string__Enum_TokenType(i32 %195)
  call void @print(ptr %196)
  call void @print(ptr @.str.s300)
  %197 = load ptr, ptr %curr, align 8
  %198 = getelementptr inbounds nuw %Token, ptr %197, i32 0, i32 1
  %199 = load ptr, ptr %198, align 8
  call void @print(ptr %199)
  call void @println(ptr @.str.s301)
  call void @exit(i32 1)
  %200 = call ptr @create_node__Enum_NodeKind(i32 0)
  ret ptr %200

label_802:                                        ; preds = %label_801
  %201 = call ptr @create_node__Enum_NodeKind(i32 27)
  store ptr %201, ptr %array_lit, align 8
  store ptr @.str.s293, ptr %last_elem, align 8
  %202 = load ptr, ptr %p, align 8
  %203 = call i1 @parser_check_val__Struct_Parser_Enum_TokenType_String(ptr %202, i32 6, ptr @.str.s294)
  %204 = icmp eq i1 %203, false
  br i1 %204, label %label_805, label %label_807

label_807:                                        ; preds = %label_810, %label_802
  %205 = load ptr, ptr %p, align 8
  call void @parser_expect_val__Struct_Parser_Enum_TokenType_String_String(ptr %205, i32 6, ptr @.str.s297, ptr @.str.s298)
  %206 = load ptr, ptr %array_lit, align 8
  ret ptr %206

label_805:                                        ; preds = %label_802
  store i1 true, ptr %is_looping, align 1
  br label %label_808

label_808:                                        ; preds = %label_816, %label_805
  %207 = load i1, ptr %is_looping, align 1
  br i1 %207, label %label_809, label %label_810

label_810:                                        ; preds = %label_808
  br label %label_807

label_809:                                        ; preds = %label_808
  %208 = load ptr, ptr %p, align 8
  %209 = call ptr @parse_expression__Struct_Parser_Int(ptr %208, i32 0)
  store ptr %209, ptr %elem, align 8
  %210 = load ptr, ptr %array_lit, align 8
  %211 = getelementptr inbounds nuw %ASTNode, ptr %210, i32 0, i32 5
  %212 = load ptr, ptr %211, align 8
  %213 = call i32 @str_equals(ptr %212, ptr @.str.s295)
  %214 = icmp eq i32 %213, 1
  br i1 %214, label %label_811, label %label_812

label_812:                                        ; preds = %label_809
  %215 = load ptr, ptr %last_elem, align 8
  %216 = call ptr @ptr_to_node(ptr %215)
  store ptr %216, ptr %last, align 8
  %217 = load ptr, ptr %last, align 8
  %218 = load ptr, ptr %elem, align 8
  %219 = call ptr @node_to_ptr(ptr %218)
  %220 = getelementptr inbounds nuw %ASTNode, ptr %217, i32 0, i32 8
  store ptr %219, ptr %220, align 8
  br label %label_813

label_811:                                        ; preds = %label_809
  %221 = load ptr, ptr %array_lit, align 8
  %222 = load ptr, ptr %elem, align 8
  %223 = call ptr @node_to_ptr(ptr %222)
  %224 = getelementptr inbounds nuw %ASTNode, ptr %221, i32 0, i32 5
  store ptr %223, ptr %224, align 8
  br label %label_813

label_813:                                        ; preds = %label_812, %label_811
  %225 = load ptr, ptr %elem, align 8
  %226 = call ptr @node_to_ptr(ptr %225)
  store ptr %226, ptr %last_elem, align 8
  %227 = load ptr, ptr %p, align 8
  %228 = call i1 @parser_match_val__Struct_Parser_Enum_TokenType_String(ptr %227, i32 6, ptr @.str.s296)
  %229 = icmp eq i1 %228, false
  br i1 %229, label %label_814, label %label_816

label_816:                                        ; preds = %label_814, %label_813
  br label %label_808

label_814:                                        ; preds = %label_813
  store i1 false, ptr %is_looping, align 1
  br label %label_816
}

define ptr @parse_module__Struct_Parser(ptr %0) {
entry:
  %p = alloca ptr, align 8
  store ptr %0, ptr %p, align 8
  %module = alloca ptr, align 8
  %last_stmt = alloca ptr, align 8
  %is_looping = alloca i1, align 1
  %curr = alloca ptr, align 8
  %stmt = alloca ptr, align 8
  %last = alloca ptr, align 8
  %1 = call ptr @create_node__Enum_NodeKind(i32 0)
  store ptr %1, ptr %module, align 8
  store ptr @.str.s302, ptr %last_stmt, align 8
  store i1 true, ptr %is_looping, align 1
  br label %label_817

label_817:                                        ; preds = %label_822, %entry
  %2 = load i1, ptr %is_looping, align 1
  br i1 %2, label %label_818, label %label_819

label_819:                                        ; preds = %label_817
  %3 = load ptr, ptr %module, align 8
  ret ptr %3

label_818:                                        ; preds = %label_817
  %4 = load ptr, ptr %p, align 8
  %5 = call ptr @parser_current__Struct_Parser(ptr %4)
  store ptr %5, ptr %curr, align 8
  %6 = load ptr, ptr %curr, align 8
  %7 = getelementptr inbounds nuw %Token, ptr %6, i32 0, i32 0
  %8 = load i32, ptr %7, align 4
  %9 = icmp eq i32 %8, 20
  br i1 %9, label %label_820, label %label_821

label_821:                                        ; preds = %label_818
  %10 = load ptr, ptr %p, align 8
  %11 = call ptr @parse_declaration__Struct_Parser(ptr %10)
  store ptr %11, ptr %stmt, align 8
  %12 = load ptr, ptr %module, align 8
  %13 = getelementptr inbounds nuw %ASTNode, ptr %12, i32 0, i32 5
  %14 = load ptr, ptr %13, align 8
  %15 = call i32 @str_equals(ptr %14, ptr @.str.s303)
  %16 = icmp eq i32 %15, 1
  br i1 %16, label %label_823, label %label_824

label_820:                                        ; preds = %label_818
  store i1 false, ptr %is_looping, align 1
  br label %label_822

label_822:                                        ; preds = %label_825, %label_820
  br label %label_817

label_824:                                        ; preds = %label_821
  %17 = load ptr, ptr %last_stmt, align 8
  %18 = call ptr @ptr_to_node(ptr %17)
  store ptr %18, ptr %last, align 8
  %19 = load ptr, ptr %last, align 8
  %20 = load ptr, ptr %stmt, align 8
  %21 = call ptr @node_to_ptr(ptr %20)
  %22 = getelementptr inbounds nuw %ASTNode, ptr %19, i32 0, i32 8
  store ptr %21, ptr %22, align 8
  br label %label_825

label_823:                                        ; preds = %label_821
  %23 = load ptr, ptr %module, align 8
  %24 = load ptr, ptr %stmt, align 8
  %25 = call ptr @node_to_ptr(ptr %24)
  %26 = getelementptr inbounds nuw %ASTNode, ptr %23, i32 0, i32 5
  store ptr %25, ptr %26, align 8
  br label %label_825

label_825:                                        ; preds = %label_824, %label_823
  %27 = load ptr, ptr %stmt, align 8
  %28 = call ptr @node_to_ptr(ptr %27)
  store ptr %28, ptr %last_stmt, align 8
  br label %label_822
}

define ptr @type_make__Enum_TypeKind_String_String(i32 %0, ptr %1, ptr %2) {
entry:
  %kind = alloca i32, align 4
  store i32 %0, ptr %kind, align 4
  %name = alloca ptr, align 8
  store ptr %1, ptr %name, align 8
  %llvm = alloca ptr, align 8
  store ptr %2, ptr %llvm, align 8
  %3 = call ptr @malloc(i64 ptrtoint (ptr getelementptr (%TypeInfo, ptr null, i32 1) to i64))
  %4 = load i32, ptr %kind, align 4
  %5 = getelementptr inbounds nuw %TypeInfo, ptr %3, i32 0, i32 0
  store i32 %4, ptr %5, align 4
  %6 = load ptr, ptr %name, align 8
  %7 = getelementptr inbounds nuw %TypeInfo, ptr %3, i32 0, i32 1
  store ptr %6, ptr %7, align 8
  %8 = load ptr, ptr %llvm, align 8
  %9 = getelementptr inbounds nuw %TypeInfo, ptr %3, i32 0, i32 2
  store ptr %8, ptr %9, align 8
  %10 = getelementptr inbounds nuw %TypeInfo, ptr %3, i32 0, i32 3
  store ptr @.str.s304, ptr %10, align 8
  %11 = getelementptr inbounds nuw %TypeInfo, ptr %3, i32 0, i32 4
  store ptr @.str.s305, ptr %11, align 8
  ret ptr %3
}

define ptr @type_copy__Struct_TypeInfo(ptr %0) {
entry:
  %t = alloca ptr, align 8
  store ptr %0, ptr %t, align 8
  %dup = alloca ptr, align 8
  %1 = load ptr, ptr %t, align 8
  %2 = getelementptr inbounds nuw %TypeInfo, ptr %1, i32 0, i32 0
  %3 = load i32, ptr %2, align 4
  %4 = load ptr, ptr %t, align 8
  %5 = getelementptr inbounds nuw %TypeInfo, ptr %4, i32 0, i32 1
  %6 = load ptr, ptr %5, align 8
  %7 = load ptr, ptr %t, align 8
  %8 = getelementptr inbounds nuw %TypeInfo, ptr %7, i32 0, i32 2
  %9 = load ptr, ptr %8, align 8
  %10 = call ptr @type_make__Enum_TypeKind_String_String(i32 %3, ptr %6, ptr %9)
  store ptr %10, ptr %dup, align 8
  %11 = load ptr, ptr %dup, align 8
  %12 = load ptr, ptr %t, align 8
  %13 = getelementptr inbounds nuw %TypeInfo, ptr %12, i32 0, i32 3
  %14 = load ptr, ptr %13, align 8
  %15 = getelementptr inbounds nuw %TypeInfo, ptr %11, i32 0, i32 3
  store ptr %14, ptr %15, align 8
  %16 = load ptr, ptr %dup, align 8
  %17 = load ptr, ptr %t, align 8
  %18 = getelementptr inbounds nuw %TypeInfo, ptr %17, i32 0, i32 4
  %19 = load ptr, ptr %18, align 8
  %20 = getelementptr inbounds nuw %TypeInfo, ptr %16, i32 0, i32 4
  store ptr %19, ptr %20, align 8
  %21 = load ptr, ptr %dup, align 8
  ret ptr %21
}

define ptr @type_invalid__Void() {
entry:
  %0 = call ptr @type_make__Enum_TypeKind_String_String(i32 0, ptr @.str.s306, ptr @.str.s307)
  ret ptr %0
}

define ptr @type_void__Void() {
entry:
  %0 = call ptr @type_make__Enum_TypeKind_String_String(i32 1, ptr @.str.s308, ptr @.str.s309)
  ret ptr %0
}

define ptr @type_int__Void() {
entry:
  %0 = call ptr @type_make__Enum_TypeKind_String_String(i32 2, ptr @.str.s310, ptr @.str.s311)
  ret ptr %0
}

define ptr @type_float__Void() {
entry:
  %0 = call ptr @type_make__Enum_TypeKind_String_String(i32 3, ptr @.str.s312, ptr @.str.s313)
  ret ptr %0
}

define ptr @type_bool__Void() {
entry:
  %0 = call ptr @type_make__Enum_TypeKind_String_String(i32 4, ptr @.str.s314, ptr @.str.s315)
  ret ptr %0
}

define ptr @type_char__Void() {
entry:
  %0 = call ptr @type_make__Enum_TypeKind_String_String(i32 5, ptr @.str.s316, ptr @.str.s317)
  ret ptr %0
}

define ptr @type_string__Void() {
entry:
  %0 = call ptr @type_make__Enum_TypeKind_String_String(i32 6, ptr @.str.s318, ptr @.str.s319)
  ret ptr %0
}

define ptr @type_ptr__Void() {
entry:
  %0 = call ptr @type_make__Enum_TypeKind_String_String(i32 7, ptr @.str.s320, ptr @.str.s321)
  ret ptr %0
}

define ptr @type_i8__Void() {
entry:
  %0 = call ptr @type_make__Enum_TypeKind_String_String(i32 2, ptr @.str.s322, ptr @.str.s323)
  ret ptr %0
}

define ptr @type_i16__Void() {
entry:
  %0 = call ptr @type_make__Enum_TypeKind_String_String(i32 2, ptr @.str.s324, ptr @.str.s325)
  ret ptr %0
}

define ptr @type_i64__Void() {
entry:
  %0 = call ptr @type_make__Enum_TypeKind_String_String(i32 2, ptr @.str.s326, ptr @.str.s327)
  ret ptr %0
}

define ptr @type_isize__Void() {
entry:
  %0 = call ptr @type_make__Enum_TypeKind_String_String(i32 2, ptr @.str.s328, ptr @.str.s329)
  ret ptr %0
}

define ptr @type_u8__Void() {
entry:
  %0 = call ptr @type_make__Enum_TypeKind_String_String(i32 2, ptr @.str.s330, ptr @.str.s331)
  ret ptr %0
}

define ptr @type_u16__Void() {
entry:
  %0 = call ptr @type_make__Enum_TypeKind_String_String(i32 2, ptr @.str.s332, ptr @.str.s333)
  ret ptr %0
}

define ptr @type_u32__Void() {
entry:
  %0 = call ptr @type_make__Enum_TypeKind_String_String(i32 2, ptr @.str.s334, ptr @.str.s335)
  ret ptr %0
}

define ptr @type_u64__Void() {
entry:
  %0 = call ptr @type_make__Enum_TypeKind_String_String(i32 2, ptr @.str.s336, ptr @.str.s337)
  ret ptr %0
}

define ptr @type_usize__Void() {
entry:
  %0 = call ptr @type_make__Enum_TypeKind_String_String(i32 2, ptr @.str.s338, ptr @.str.s339)
  ret ptr %0
}

define i32 @type_int_bits__Struct_TypeInfo(ptr %0) {
entry:
  %t = alloca ptr, align 8
  store ptr %0, ptr %t, align 8
  %1 = load ptr, ptr %t, align 8
  %2 = getelementptr inbounds nuw %TypeInfo, ptr %1, i32 0, i32 2
  %3 = load ptr, ptr %2, align 8
  %4 = call i32 @str_equals(ptr %3, ptr @.str.s340)
  %5 = icmp eq i32 %4, 1
  br i1 %5, label %label_826, label %label_828

label_828:                                        ; preds = %entry
  %6 = load ptr, ptr %t, align 8
  %7 = getelementptr inbounds nuw %TypeInfo, ptr %6, i32 0, i32 2
  %8 = load ptr, ptr %7, align 8
  %9 = call i32 @str_equals(ptr %8, ptr @.str.s341)
  %10 = icmp eq i32 %9, 1
  br i1 %10, label %label_829, label %label_831

label_826:                                        ; preds = %entry
  ret i32 1

label_831:                                        ; preds = %label_828
  %11 = load ptr, ptr %t, align 8
  %12 = getelementptr inbounds nuw %TypeInfo, ptr %11, i32 0, i32 2
  %13 = load ptr, ptr %12, align 8
  %14 = call i32 @str_equals(ptr %13, ptr @.str.s342)
  %15 = icmp eq i32 %14, 1
  br i1 %15, label %label_832, label %label_834

label_829:                                        ; preds = %label_828
  ret i32 8

label_834:                                        ; preds = %label_831
  %16 = load ptr, ptr %t, align 8
  %17 = getelementptr inbounds nuw %TypeInfo, ptr %16, i32 0, i32 2
  %18 = load ptr, ptr %17, align 8
  %19 = call i32 @str_equals(ptr %18, ptr @.str.s343)
  %20 = icmp eq i32 %19, 1
  br i1 %20, label %label_835, label %label_837

label_832:                                        ; preds = %label_831
  ret i32 16

label_837:                                        ; preds = %label_834
  %21 = load ptr, ptr %t, align 8
  %22 = getelementptr inbounds nuw %TypeInfo, ptr %21, i32 0, i32 2
  %23 = load ptr, ptr %22, align 8
  %24 = call i32 @str_equals(ptr %23, ptr @.str.s344)
  %25 = icmp eq i32 %24, 1
  br i1 %25, label %label_838, label %label_840

label_835:                                        ; preds = %label_834
  ret i32 32

label_840:                                        ; preds = %label_837
  ret i32 0

label_838:                                        ; preds = %label_837
  ret i32 64
}

define i1 @type_int_is_unsigned__Struct_TypeInfo(ptr %0) {
entry:
  %t = alloca ptr, align 8
  store ptr %0, ptr %t, align 8
  %1 = load ptr, ptr %t, align 8
  %2 = getelementptr inbounds nuw %TypeInfo, ptr %1, i32 0, i32 0
  %3 = load i32, ptr %2, align 4
  %4 = icmp ne i32 %3, 2
  br i1 %4, label %label_841, label %label_843

label_843:                                        ; preds = %entry
  %5 = load ptr, ptr %t, align 8
  %6 = getelementptr inbounds nuw %TypeInfo, ptr %5, i32 0, i32 1
  %7 = load ptr, ptr %6, align 8
  %8 = call i32 @str_starts_with(ptr %7, ptr @.str.s345)
  %9 = icmp eq i32 %8, 1
  ret i1 %9

label_841:                                        ; preds = %entry
  ret i1 false
}

define i1 @type_is_move_only__Struct_TypeInfo(ptr %0) {
entry:
  %t = alloca ptr, align 8
  store ptr %0, ptr %t, align 8
  %1 = load ptr, ptr %t, align 8
  %2 = getelementptr inbounds nuw %TypeInfo, ptr %1, i32 0, i32 0
  %3 = load i32, ptr %2, align 4
  %4 = icmp eq i32 %3, 8
  ret i1 %4
}

define ptr @type_struct__String(ptr %0) {
entry:
  %name = alloca ptr, align 8
  store ptr %0, ptr %name, align 8
  %1 = load ptr, ptr %name, align 8
  %2 = call ptr @type_make__Enum_TypeKind_String_String(i32 8, ptr %1, ptr @.str.s346)
  ret ptr %2
}

define ptr @type_enum__String(ptr %0) {
entry:
  %name = alloca ptr, align 8
  store ptr %0, ptr %name, align 8
  %1 = load ptr, ptr %name, align 8
  %2 = call ptr @type_make__Enum_TypeKind_String_String(i32 9, ptr %1, ptr @.str.s347)
  ret ptr %2
}

define ptr @type_array__Struct_TypeInfo(ptr %0) {
entry:
  %elem = alloca ptr, align 8
  store ptr %0, ptr %elem, align 8
  %t = alloca ptr, align 8
  %1 = call ptr @type_make__Enum_TypeKind_String_String(i32 10, ptr @.str.s348, ptr @.str.s349)
  store ptr %1, ptr %t, align 8
  %2 = load ptr, ptr %t, align 8
  %3 = load ptr, ptr %elem, align 8
  %4 = call ptr @type_to_ptr(ptr %3)
  %5 = getelementptr inbounds nuw %TypeInfo, ptr %2, i32 0, i32 3
  store ptr %4, ptr %5, align 8
  %6 = load ptr, ptr %t, align 8
  ret ptr %6
}

define ptr @type_list__Struct_TypeInfo(ptr %0) {
entry:
  %elem = alloca ptr, align 8
  store ptr %0, ptr %elem, align 8
  %t = alloca ptr, align 8
  %1 = call ptr @type_make__Enum_TypeKind_String_String(i32 11, ptr @.str.s350, ptr @.str.s351)
  store ptr %1, ptr %t, align 8
  %2 = load ptr, ptr %t, align 8
  %3 = load ptr, ptr %elem, align 8
  %4 = call ptr @type_to_ptr(ptr %3)
  %5 = getelementptr inbounds nuw %TypeInfo, ptr %2, i32 0, i32 3
  store ptr %4, ptr %5, align 8
  %6 = load ptr, ptr %t, align 8
  ret ptr %6
}

define i1 @type_is_valid__Struct_TypeInfo(ptr %0) {
entry:
  %t = alloca ptr, align 8
  store ptr %0, ptr %t, align 8
  %1 = load ptr, ptr %t, align 8
  %2 = getelementptr inbounds nuw %TypeInfo, ptr %1, i32 0, i32 0
  %3 = load i32, ptr %2, align 4
  %4 = icmp ne i32 %3, 0
  ret i1 %4
}

define ptr @type_display__Struct_TypeInfo(ptr %0) {
entry:
  %t = alloca ptr, align 8
  store ptr %0, ptr %t, align 8
  %1 = load ptr, ptr %t, align 8
  %2 = getelementptr inbounds nuw %TypeInfo, ptr %1, i32 0, i32 0
  %3 = load i32, ptr %2, align 4
  %4 = icmp eq i32 %3, 8
  br i1 %4, label %label_844, label %label_846

label_846:                                        ; preds = %entry
  %5 = load ptr, ptr %t, align 8
  %6 = getelementptr inbounds nuw %TypeInfo, ptr %5, i32 0, i32 0
  %7 = load i32, ptr %6, align 4
  %8 = icmp eq i32 %7, 9
  br i1 %8, label %label_847, label %label_849

label_844:                                        ; preds = %entry
  %9 = load ptr, ptr %t, align 8
  %10 = getelementptr inbounds nuw %TypeInfo, ptr %9, i32 0, i32 1
  %11 = load ptr, ptr %10, align 8
  ret ptr %11

label_849:                                        ; preds = %label_846
  %12 = load ptr, ptr %t, align 8
  %13 = getelementptr inbounds nuw %TypeInfo, ptr %12, i32 0, i32 0
  %14 = load i32, ptr %13, align 4
  %15 = icmp eq i32 %14, 10
  br i1 %15, label %label_850, label %label_852

label_847:                                        ; preds = %label_846
  %16 = load ptr, ptr %t, align 8
  %17 = getelementptr inbounds nuw %TypeInfo, ptr %16, i32 0, i32 1
  %18 = load ptr, ptr %17, align 8
  ret ptr %18

label_852:                                        ; preds = %label_849
  %19 = load ptr, ptr %t, align 8
  %20 = getelementptr inbounds nuw %TypeInfo, ptr %19, i32 0, i32 0
  %21 = load i32, ptr %20, align 4
  %22 = icmp eq i32 %21, 11
  br i1 %22, label %label_856, label %label_858

label_850:                                        ; preds = %label_849
  %23 = load ptr, ptr %t, align 8
  %24 = getelementptr inbounds nuw %TypeInfo, ptr %23, i32 0, i32 3
  %25 = load ptr, ptr %24, align 8
  %26 = call i32 @str_equals(ptr %25, ptr @.str.s352)
  %27 = icmp eq i32 %26, 0
  br i1 %27, label %label_853, label %label_855

label_855:                                        ; preds = %label_850
  ret ptr @.str.s355

label_853:                                        ; preds = %label_850
  %28 = load ptr, ptr %t, align 8
  %29 = getelementptr inbounds nuw %TypeInfo, ptr %28, i32 0, i32 3
  %30 = load ptr, ptr %29, align 8
  %31 = call ptr @ptr_to_type(ptr %30)
  %32 = call ptr @type_display__Struct_TypeInfo(ptr %31)
  %33 = call ptr @str_concat(ptr @.str.s353, ptr %32)
  %34 = call ptr @str_concat(ptr %33, ptr @.str.s354)
  ret ptr %34

label_858:                                        ; preds = %label_852
  %35 = load ptr, ptr %t, align 8
  %36 = getelementptr inbounds nuw %TypeInfo, ptr %35, i32 0, i32 1
  %37 = load ptr, ptr %36, align 8
  ret ptr %37

label_856:                                        ; preds = %label_852
  %38 = load ptr, ptr %t, align 8
  %39 = getelementptr inbounds nuw %TypeInfo, ptr %38, i32 0, i32 3
  %40 = load ptr, ptr %39, align 8
  %41 = call i32 @str_equals(ptr %40, ptr @.str.s356)
  %42 = icmp eq i32 %41, 0
  br i1 %42, label %label_859, label %label_861

label_861:                                        ; preds = %label_856
  ret ptr @.str.s359

label_859:                                        ; preds = %label_856
  %43 = load ptr, ptr %t, align 8
  %44 = getelementptr inbounds nuw %TypeInfo, ptr %43, i32 0, i32 3
  %45 = load ptr, ptr %44, align 8
  %46 = call ptr @ptr_to_type(ptr %45)
  %47 = call ptr @type_display__Struct_TypeInfo(ptr %46)
  %48 = call ptr @str_concat(ptr @.str.s357, ptr %47)
  %49 = call ptr @str_concat(ptr %48, ptr @.str.s358)
  ret ptr %49
}

define i1 @type_equals__Struct_TypeInfo_Struct_TypeInfo(ptr %0, ptr %1) {
entry:
  %a = alloca ptr, align 8
  store ptr %0, ptr %a, align 8
  %b = alloca ptr, align 8
  store ptr %1, ptr %b, align 8
  %ac = alloca ptr, align 8
  %bc = alloca ptr, align 8
  %2 = load ptr, ptr %a, align 8
  %3 = getelementptr inbounds nuw %TypeInfo, ptr %2, i32 0, i32 0
  %4 = load i32, ptr %3, align 4
  %5 = load ptr, ptr %b, align 8
  %6 = getelementptr inbounds nuw %TypeInfo, ptr %5, i32 0, i32 0
  %7 = load i32, ptr %6, align 4
  %8 = icmp ne i32 %4, %7
  br i1 %8, label %label_862, label %label_864

label_864:                                        ; preds = %entry
  %sc.71 = alloca i1, align 1
  %9 = load ptr, ptr %a, align 8
  %10 = getelementptr inbounds nuw %TypeInfo, ptr %9, i32 0, i32 0
  %11 = load i32, ptr %10, align 4
  %12 = icmp eq i32 %11, 8
  store i1 %12, ptr %sc.71, align 1
  br i1 %12, label %label_866, label %label_865

label_862:                                        ; preds = %entry
  ret i1 false

label_865:                                        ; preds = %label_864
  %13 = load ptr, ptr %a, align 8
  %14 = getelementptr inbounds nuw %TypeInfo, ptr %13, i32 0, i32 0
  %15 = load i32, ptr %14, align 4
  %16 = icmp eq i32 %15, 9
  store i1 %16, ptr %sc.71, align 1
  br label %label_866

label_866:                                        ; preds = %label_865, %label_864
  %17 = load i1, ptr %sc.71, align 1
  br i1 %17, label %label_867, label %label_869

label_869:                                        ; preds = %label_866
  %18 = load ptr, ptr %a, align 8
  %19 = getelementptr inbounds nuw %TypeInfo, ptr %18, i32 0, i32 0
  %20 = load i32, ptr %19, align 4
  %21 = icmp eq i32 %20, 2
  br i1 %21, label %label_870, label %label_872

label_867:                                        ; preds = %label_866
  %22 = load ptr, ptr %a, align 8
  %23 = getelementptr inbounds nuw %TypeInfo, ptr %22, i32 0, i32 1
  %24 = load ptr, ptr %23, align 8
  %25 = load ptr, ptr %b, align 8
  %26 = getelementptr inbounds nuw %TypeInfo, ptr %25, i32 0, i32 1
  %27 = load ptr, ptr %26, align 8
  %28 = call i32 @str_equals(ptr %24, ptr %27)
  %29 = icmp eq i32 %28, 1
  ret i1 %29

label_872:                                        ; preds = %label_869
  %30 = load ptr, ptr %a, align 8
  %31 = getelementptr inbounds nuw %TypeInfo, ptr %30, i32 0, i32 0
  %32 = load i32, ptr %31, align 4
  %33 = icmp eq i32 %32, 10
  br i1 %33, label %label_873, label %label_875

label_870:                                        ; preds = %label_869
  %34 = load ptr, ptr %a, align 8
  %35 = getelementptr inbounds nuw %TypeInfo, ptr %34, i32 0, i32 1
  %36 = load ptr, ptr %35, align 8
  %37 = load ptr, ptr %b, align 8
  %38 = getelementptr inbounds nuw %TypeInfo, ptr %37, i32 0, i32 1
  %39 = load ptr, ptr %38, align 8
  %40 = call i32 @str_equals(ptr %36, ptr %39)
  %41 = icmp eq i32 %40, 1
  ret i1 %41

label_875:                                        ; preds = %label_872
  %42 = load ptr, ptr %a, align 8
  %43 = getelementptr inbounds nuw %TypeInfo, ptr %42, i32 0, i32 0
  %44 = load i32, ptr %43, align 4
  %45 = icmp eq i32 %44, 11
  br i1 %45, label %label_881, label %label_883

label_873:                                        ; preds = %label_872
  %sc.72 = alloca i1, align 1
  %46 = load ptr, ptr %a, align 8
  %47 = getelementptr inbounds nuw %TypeInfo, ptr %46, i32 0, i32 3
  %48 = load ptr, ptr %47, align 8
  %49 = call i32 @str_equals(ptr %48, ptr @.str.s360)
  %50 = icmp eq i32 %49, 1
  store i1 %50, ptr %sc.72, align 1
  br i1 %50, label %label_877, label %label_876

label_876:                                        ; preds = %label_873
  %51 = load ptr, ptr %b, align 8
  %52 = getelementptr inbounds nuw %TypeInfo, ptr %51, i32 0, i32 3
  %53 = load ptr, ptr %52, align 8
  %54 = call i32 @str_equals(ptr %53, ptr @.str.s361)
  %55 = icmp eq i32 %54, 1
  store i1 %55, ptr %sc.72, align 1
  br label %label_877

label_877:                                        ; preds = %label_876, %label_873
  %56 = load i1, ptr %sc.72, align 1
  br i1 %56, label %label_878, label %label_880

label_880:                                        ; preds = %label_877
  %57 = load ptr, ptr %a, align 8
  %58 = getelementptr inbounds nuw %TypeInfo, ptr %57, i32 0, i32 3
  %59 = load ptr, ptr %58, align 8
  %60 = call ptr @ptr_to_type(ptr %59)
  %61 = load ptr, ptr %b, align 8
  %62 = getelementptr inbounds nuw %TypeInfo, ptr %61, i32 0, i32 3
  %63 = load ptr, ptr %62, align 8
  %64 = call ptr @ptr_to_type(ptr %63)
  %65 = call i1 @type_equals__Struct_TypeInfo_Struct_TypeInfo(ptr %60, ptr %64)
  ret i1 %65

label_878:                                        ; preds = %label_877
  %66 = load ptr, ptr %a, align 8
  %67 = getelementptr inbounds nuw %TypeInfo, ptr %66, i32 0, i32 3
  %68 = load ptr, ptr %67, align 8
  %69 = load ptr, ptr %b, align 8
  %70 = getelementptr inbounds nuw %TypeInfo, ptr %69, i32 0, i32 3
  %71 = load ptr, ptr %70, align 8
  %72 = call i32 @str_equals(ptr %68, ptr %71)
  %73 = icmp eq i32 %72, 1
  ret i1 %73

label_883:                                        ; preds = %label_875
  ret i1 true

label_881:                                        ; preds = %label_875
  %sc.73 = alloca i1, align 1
  %74 = load ptr, ptr %a, align 8
  %75 = getelementptr inbounds nuw %TypeInfo, ptr %74, i32 0, i32 3
  %76 = load ptr, ptr %75, align 8
  %77 = call i32 @str_equals(ptr %76, ptr @.str.s362)
  %78 = icmp eq i32 %77, 1
  store i1 %78, ptr %sc.73, align 1
  br i1 %78, label %label_885, label %label_884

label_884:                                        ; preds = %label_881
  %79 = load ptr, ptr %b, align 8
  %80 = getelementptr inbounds nuw %TypeInfo, ptr %79, i32 0, i32 3
  %81 = load ptr, ptr %80, align 8
  %82 = call i32 @str_equals(ptr %81, ptr @.str.s363)
  %83 = icmp eq i32 %82, 1
  store i1 %83, ptr %sc.73, align 1
  br label %label_885

label_885:                                        ; preds = %label_884, %label_881
  %84 = load i1, ptr %sc.73, align 1
  br i1 %84, label %label_886, label %label_888

label_888:                                        ; preds = %label_885
  %85 = load ptr, ptr %a, align 8
  %86 = getelementptr inbounds nuw %TypeInfo, ptr %85, i32 0, i32 3
  %87 = load ptr, ptr %86, align 8
  %88 = call ptr @ptr_to_type(ptr %87)
  store ptr %88, ptr %ac, align 8
  %89 = load ptr, ptr %b, align 8
  %90 = getelementptr inbounds nuw %TypeInfo, ptr %89, i32 0, i32 3
  %91 = load ptr, ptr %90, align 8
  %92 = call ptr @ptr_to_type(ptr %91)
  store ptr %92, ptr %bc, align 8
  %sc.74 = alloca i1, align 1
  %93 = load ptr, ptr %ac, align 8
  %94 = call i1 @type_is_valid__Struct_TypeInfo(ptr %93)
  %95 = icmp eq i1 %94, false
  store i1 %95, ptr %sc.74, align 1
  br i1 %95, label %label_890, label %label_889

label_886:                                        ; preds = %label_885
  ret i1 true

label_889:                                        ; preds = %label_888
  %96 = load ptr, ptr %bc, align 8
  %97 = call i1 @type_is_valid__Struct_TypeInfo(ptr %96)
  %98 = icmp eq i1 %97, false
  store i1 %98, ptr %sc.74, align 1
  br label %label_890

label_890:                                        ; preds = %label_889, %label_888
  %99 = load i1, ptr %sc.74, align 1
  br i1 %99, label %label_891, label %label_893

label_893:                                        ; preds = %label_890
  %100 = load ptr, ptr %ac, align 8
  %101 = load ptr, ptr %bc, align 8
  %102 = call i1 @type_equals__Struct_TypeInfo_Struct_TypeInfo(ptr %100, ptr %101)
  ret i1 %102

label_891:                                        ; preds = %label_890
  ret i1 true
}

define i1 @type_is_numeric__Struct_TypeInfo(ptr %0) {
entry:
  %t = alloca ptr, align 8
  store ptr %0, ptr %t, align 8
  %sc.75 = alloca i1, align 1
  %1 = load ptr, ptr %t, align 8
  %2 = getelementptr inbounds nuw %TypeInfo, ptr %1, i32 0, i32 0
  %3 = load i32, ptr %2, align 4
  %4 = icmp eq i32 %3, 2
  store i1 %4, ptr %sc.75, align 1
  br i1 %4, label %label_895, label %label_894

label_894:                                        ; preds = %entry
  %5 = load ptr, ptr %t, align 8
  %6 = getelementptr inbounds nuw %TypeInfo, ptr %5, i32 0, i32 0
  %7 = load i32, ptr %6, align 4
  %8 = icmp eq i32 %7, 3
  store i1 %8, ptr %sc.75, align 1
  br label %label_895

label_895:                                        ; preds = %label_894, %entry
  %9 = load i1, ptr %sc.75, align 1
  ret i1 %9
}

define ptr @type_ir_key__Struct_TypeInfo(ptr %0) {
entry:
  %t = alloca ptr, align 8
  store ptr %0, ptr %t, align 8
  %elem = alloca ptr, align 8
  %1 = load ptr, ptr %t, align 8
  %2 = getelementptr inbounds nuw %TypeInfo, ptr %1, i32 0, i32 0
  %3 = load i32, ptr %2, align 4
  %4 = icmp eq i32 %3, 1
  br i1 %4, label %label_896, label %label_898

label_898:                                        ; preds = %entry
  %5 = load ptr, ptr %t, align 8
  %6 = getelementptr inbounds nuw %TypeInfo, ptr %5, i32 0, i32 0
  %7 = load i32, ptr %6, align 4
  %8 = icmp eq i32 %7, 2
  br i1 %8, label %label_899, label %label_901

label_896:                                        ; preds = %entry
  ret ptr @.str.s364

label_901:                                        ; preds = %label_898
  %9 = load ptr, ptr %t, align 8
  %10 = getelementptr inbounds nuw %TypeInfo, ptr %9, i32 0, i32 0
  %11 = load i32, ptr %10, align 4
  %12 = icmp eq i32 %11, 3
  br i1 %12, label %label_902, label %label_904

label_899:                                        ; preds = %label_898
  %13 = load ptr, ptr %t, align 8
  %14 = getelementptr inbounds nuw %TypeInfo, ptr %13, i32 0, i32 2
  %15 = load ptr, ptr %14, align 8
  ret ptr %15

label_904:                                        ; preds = %label_901
  %16 = load ptr, ptr %t, align 8
  %17 = getelementptr inbounds nuw %TypeInfo, ptr %16, i32 0, i32 0
  %18 = load i32, ptr %17, align 4
  %19 = icmp eq i32 %18, 4
  br i1 %19, label %label_905, label %label_907

label_902:                                        ; preds = %label_901
  ret ptr @.str.s365

label_907:                                        ; preds = %label_904
  %20 = load ptr, ptr %t, align 8
  %21 = getelementptr inbounds nuw %TypeInfo, ptr %20, i32 0, i32 0
  %22 = load i32, ptr %21, align 4
  %23 = icmp eq i32 %22, 5
  br i1 %23, label %label_908, label %label_910

label_905:                                        ; preds = %label_904
  ret ptr @.str.s366

label_910:                                        ; preds = %label_907
  %24 = load ptr, ptr %t, align 8
  %25 = getelementptr inbounds nuw %TypeInfo, ptr %24, i32 0, i32 0
  %26 = load i32, ptr %25, align 4
  %27 = icmp eq i32 %26, 6
  br i1 %27, label %label_911, label %label_913

label_908:                                        ; preds = %label_907
  ret ptr @.str.s367

label_913:                                        ; preds = %label_910
  %28 = load ptr, ptr %t, align 8
  %29 = getelementptr inbounds nuw %TypeInfo, ptr %28, i32 0, i32 0
  %30 = load i32, ptr %29, align 4
  %31 = icmp eq i32 %30, 7
  br i1 %31, label %label_914, label %label_916

label_911:                                        ; preds = %label_910
  ret ptr @.str.s368

label_916:                                        ; preds = %label_913
  %32 = load ptr, ptr %t, align 8
  %33 = getelementptr inbounds nuw %TypeInfo, ptr %32, i32 0, i32 0
  %34 = load i32, ptr %33, align 4
  %35 = icmp eq i32 %34, 9
  br i1 %35, label %label_917, label %label_919

label_914:                                        ; preds = %label_913
  ret ptr @.str.s369

label_919:                                        ; preds = %label_916
  %36 = load ptr, ptr %t, align 8
  %37 = getelementptr inbounds nuw %TypeInfo, ptr %36, i32 0, i32 0
  %38 = load i32, ptr %37, align 4
  %39 = icmp eq i32 %38, 8
  br i1 %39, label %label_920, label %label_922

label_917:                                        ; preds = %label_916
  ret ptr @.str.s370

label_922:                                        ; preds = %label_919
  %40 = load ptr, ptr %t, align 8
  %41 = getelementptr inbounds nuw %TypeInfo, ptr %40, i32 0, i32 0
  %42 = load i32, ptr %41, align 4
  %43 = icmp eq i32 %42, 11
  br i1 %43, label %label_923, label %label_925

label_920:                                        ; preds = %label_919
  %44 = load ptr, ptr %t, align 8
  %45 = getelementptr inbounds nuw %TypeInfo, ptr %44, i32 0, i32 1
  %46 = load ptr, ptr %45, align 8
  %47 = call ptr @str_concat(ptr @.str.s371, ptr %46)
  ret ptr %47

label_925:                                        ; preds = %label_922
  %48 = load ptr, ptr %t, align 8
  %49 = getelementptr inbounds nuw %TypeInfo, ptr %48, i32 0, i32 0
  %50 = load i32, ptr %49, align 4
  %51 = icmp eq i32 %50, 10
  br i1 %51, label %label_926, label %label_928

label_923:                                        ; preds = %label_922
  ret ptr @.str.s372

label_928:                                        ; preds = %label_925
  ret ptr @.str.s376

label_926:                                        ; preds = %label_925
  %52 = load ptr, ptr %t, align 8
  %53 = getelementptr inbounds nuw %TypeInfo, ptr %52, i32 0, i32 3
  %54 = load ptr, ptr %53, align 8
  %55 = call i32 @str_equals(ptr %54, ptr @.str.s373)
  %56 = icmp eq i32 %55, 0
  br i1 %56, label %label_929, label %label_931

label_931:                                        ; preds = %label_934, %label_926
  ret ptr @.str.s375

label_929:                                        ; preds = %label_926
  %57 = load ptr, ptr %t, align 8
  %58 = getelementptr inbounds nuw %TypeInfo, ptr %57, i32 0, i32 3
  %59 = load ptr, ptr %58, align 8
  %60 = call ptr @ptr_to_type(ptr %59)
  store ptr %60, ptr %elem, align 8
  %61 = load ptr, ptr %elem, align 8
  %62 = getelementptr inbounds nuw %TypeInfo, ptr %61, i32 0, i32 0
  %63 = load i32, ptr %62, align 4
  %64 = icmp eq i32 %63, 10
  br i1 %64, label %label_932, label %label_934

label_934:                                        ; preds = %label_929
  br label %label_931

label_932:                                        ; preds = %label_929
  ret ptr @.str.s374
}

define ptr @type_sem_key__Struct_TypeInfo(ptr %0) {
entry:
  %t = alloca ptr, align 8
  store ptr %0, ptr %t, align 8
  %1 = load ptr, ptr %t, align 8
  %2 = getelementptr inbounds nuw %TypeInfo, ptr %1, i32 0, i32 0
  %3 = load i32, ptr %2, align 4
  %4 = icmp eq i32 %3, 1
  br i1 %4, label %label_935, label %label_937

label_937:                                        ; preds = %entry
  %5 = load ptr, ptr %t, align 8
  %6 = getelementptr inbounds nuw %TypeInfo, ptr %5, i32 0, i32 0
  %7 = load i32, ptr %6, align 4
  %8 = icmp eq i32 %7, 2
  br i1 %8, label %label_938, label %label_940

label_935:                                        ; preds = %entry
  ret ptr @.str.s377

label_940:                                        ; preds = %label_937
  %9 = load ptr, ptr %t, align 8
  %10 = getelementptr inbounds nuw %TypeInfo, ptr %9, i32 0, i32 0
  %11 = load i32, ptr %10, align 4
  %12 = icmp eq i32 %11, 3
  br i1 %12, label %label_941, label %label_943

label_938:                                        ; preds = %label_937
  %13 = load ptr, ptr %t, align 8
  %14 = getelementptr inbounds nuw %TypeInfo, ptr %13, i32 0, i32 1
  %15 = load ptr, ptr %14, align 8
  ret ptr %15

label_943:                                        ; preds = %label_940
  %16 = load ptr, ptr %t, align 8
  %17 = getelementptr inbounds nuw %TypeInfo, ptr %16, i32 0, i32 0
  %18 = load i32, ptr %17, align 4
  %19 = icmp eq i32 %18, 4
  br i1 %19, label %label_944, label %label_946

label_941:                                        ; preds = %label_940
  ret ptr @.str.s378

label_946:                                        ; preds = %label_943
  %20 = load ptr, ptr %t, align 8
  %21 = getelementptr inbounds nuw %TypeInfo, ptr %20, i32 0, i32 0
  %22 = load i32, ptr %21, align 4
  %23 = icmp eq i32 %22, 5
  br i1 %23, label %label_947, label %label_949

label_944:                                        ; preds = %label_943
  ret ptr @.str.s379

label_949:                                        ; preds = %label_946
  %24 = load ptr, ptr %t, align 8
  %25 = getelementptr inbounds nuw %TypeInfo, ptr %24, i32 0, i32 0
  %26 = load i32, ptr %25, align 4
  %27 = icmp eq i32 %26, 6
  br i1 %27, label %label_950, label %label_952

label_947:                                        ; preds = %label_946
  ret ptr @.str.s380

label_952:                                        ; preds = %label_949
  %28 = load ptr, ptr %t, align 8
  %29 = getelementptr inbounds nuw %TypeInfo, ptr %28, i32 0, i32 0
  %30 = load i32, ptr %29, align 4
  %31 = icmp eq i32 %30, 7
  br i1 %31, label %label_953, label %label_955

label_950:                                        ; preds = %label_949
  ret ptr @.str.s381

label_955:                                        ; preds = %label_952
  %32 = load ptr, ptr %t, align 8
  %33 = getelementptr inbounds nuw %TypeInfo, ptr %32, i32 0, i32 0
  %34 = load i32, ptr %33, align 4
  %35 = icmp eq i32 %34, 8
  br i1 %35, label %label_956, label %label_958

label_953:                                        ; preds = %label_952
  ret ptr @.str.s382

label_958:                                        ; preds = %label_955
  %36 = load ptr, ptr %t, align 8
  %37 = getelementptr inbounds nuw %TypeInfo, ptr %36, i32 0, i32 0
  %38 = load i32, ptr %37, align 4
  %39 = icmp eq i32 %38, 9
  br i1 %39, label %label_959, label %label_961

label_956:                                        ; preds = %label_955
  %40 = load ptr, ptr %t, align 8
  %41 = getelementptr inbounds nuw %TypeInfo, ptr %40, i32 0, i32 1
  %42 = load ptr, ptr %41, align 8
  %43 = call ptr @str_concat(ptr @.str.s383, ptr %42)
  ret ptr %43

label_961:                                        ; preds = %label_958
  %44 = load ptr, ptr %t, align 8
  %45 = getelementptr inbounds nuw %TypeInfo, ptr %44, i32 0, i32 0
  %46 = load i32, ptr %45, align 4
  %47 = icmp eq i32 %46, 10
  br i1 %47, label %label_962, label %label_964

label_959:                                        ; preds = %label_958
  %48 = load ptr, ptr %t, align 8
  %49 = getelementptr inbounds nuw %TypeInfo, ptr %48, i32 0, i32 1
  %50 = load ptr, ptr %49, align 8
  %51 = call ptr @str_concat(ptr @.str.s384, ptr %50)
  ret ptr %51

label_964:                                        ; preds = %label_961
  %52 = load ptr, ptr %t, align 8
  %53 = getelementptr inbounds nuw %TypeInfo, ptr %52, i32 0, i32 0
  %54 = load i32, ptr %53, align 4
  %55 = icmp eq i32 %54, 11
  br i1 %55, label %label_968, label %label_970

label_962:                                        ; preds = %label_961
  %56 = load ptr, ptr %t, align 8
  %57 = getelementptr inbounds nuw %TypeInfo, ptr %56, i32 0, i32 3
  %58 = load ptr, ptr %57, align 8
  %59 = call i32 @str_equals(ptr %58, ptr @.str.s385)
  %60 = icmp eq i32 %59, 0
  br i1 %60, label %label_965, label %label_967

label_967:                                        ; preds = %label_962
  ret ptr @.str.s387

label_965:                                        ; preds = %label_962
  %61 = load ptr, ptr %t, align 8
  %62 = getelementptr inbounds nuw %TypeInfo, ptr %61, i32 0, i32 3
  %63 = load ptr, ptr %62, align 8
  %64 = call ptr @ptr_to_type(ptr %63)
  %65 = call ptr @type_sem_key__Struct_TypeInfo(ptr %64)
  %66 = call ptr @str_concat(ptr @.str.s386, ptr %65)
  ret ptr %66

label_970:                                        ; preds = %label_964
  ret ptr @.str.s391

label_968:                                        ; preds = %label_964
  %67 = load ptr, ptr %t, align 8
  %68 = getelementptr inbounds nuw %TypeInfo, ptr %67, i32 0, i32 3
  %69 = load ptr, ptr %68, align 8
  %70 = call i32 @str_equals(ptr %69, ptr @.str.s388)
  %71 = icmp eq i32 %70, 0
  br i1 %71, label %label_971, label %label_973

label_973:                                        ; preds = %label_968
  ret ptr @.str.s390

label_971:                                        ; preds = %label_968
  %72 = load ptr, ptr %t, align 8
  %73 = getelementptr inbounds nuw %TypeInfo, ptr %72, i32 0, i32 3
  %74 = load ptr, ptr %73, align 8
  %75 = call ptr @ptr_to_type(ptr %74)
  %76 = call ptr @type_sem_key__Struct_TypeInfo(ptr %75)
  %77 = call ptr @str_concat(ptr @.str.s389, ptr %76)
  ret ptr %77
}

define ptr @type_storage_key__Struct_TypeInfo(ptr %0) {
entry:
  %t = alloca ptr, align 8
  store ptr %0, ptr %t, align 8
  %key = alloca ptr, align 8
  %1 = load ptr, ptr %t, align 8
  %2 = call ptr @type_ir_key__Struct_TypeInfo(ptr %1)
  store ptr %2, ptr %key, align 8
  %3 = load ptr, ptr %key, align 8
  %4 = call i32 @str_equals(ptr %3, ptr @.str.s392)
  %5 = icmp eq i32 %4, 1
  br i1 %5, label %label_974, label %label_976

label_976:                                        ; preds = %entry
  %6 = load ptr, ptr %key, align 8
  %7 = call i32 @str_starts_with(ptr %6, ptr @.str.s394)
  %8 = icmp eq i32 %7, 1
  br i1 %8, label %label_977, label %label_979

label_974:                                        ; preds = %entry
  ret ptr @.str.s393

label_979:                                        ; preds = %label_976
  %9 = load ptr, ptr %key, align 8
  ret ptr %9

label_977:                                        ; preds = %label_976
  ret ptr @.str.s395
}

define ptr @type_from_annotation__Struct_ASTNode(ptr %0) {
entry:
  %tn = alloca ptr, align 8
  store ptr %0, ptr %tn, align 8
  %1 = load ptr, ptr %tn, align 8
  %2 = getelementptr inbounds nuw %ASTNode, ptr %1, i32 0, i32 3
  %3 = load i32, ptr %2, align 4
  %4 = icmp eq i32 %3, 1
  br i1 %4, label %label_980, label %label_982

label_982:                                        ; preds = %entry
  %5 = load ptr, ptr %tn, align 8
  %6 = getelementptr inbounds nuw %ASTNode, ptr %5, i32 0, i32 1
  %7 = load ptr, ptr %6, align 8
  %8 = call i32 @str_equals(ptr %7, ptr @.str.s397)
  %9 = icmp eq i32 %8, 1
  br i1 %9, label %label_986, label %label_988

label_980:                                        ; preds = %entry
  %10 = load ptr, ptr %tn, align 8
  %11 = getelementptr inbounds nuw %ASTNode, ptr %10, i32 0, i32 5
  %12 = load ptr, ptr %11, align 8
  %13 = call i32 @str_equals(ptr %12, ptr @.str.s396)
  %14 = icmp eq i32 %13, 0
  br i1 %14, label %label_983, label %label_985

label_985:                                        ; preds = %label_980
  %15 = call ptr @type_invalid__Void()
  %16 = call ptr @type_array__Struct_TypeInfo(ptr %15)
  ret ptr %16

label_983:                                        ; preds = %label_980
  %17 = load ptr, ptr %tn, align 8
  %18 = getelementptr inbounds nuw %ASTNode, ptr %17, i32 0, i32 5
  %19 = load ptr, ptr %18, align 8
  %20 = call ptr @ptr_to_node(ptr %19)
  %21 = call ptr @type_from_annotation__Struct_ASTNode(ptr %20)
  %22 = call ptr @type_array__Struct_TypeInfo(ptr %21)
  ret ptr %22

label_988:                                        ; preds = %label_982
  %23 = load ptr, ptr %tn, align 8
  %24 = getelementptr inbounds nuw %ASTNode, ptr %23, i32 0, i32 1
  %25 = load ptr, ptr %24, align 8
  %26 = call i32 @str_equals(ptr %25, ptr @.str.s398)
  %27 = icmp eq i32 %26, 1
  br i1 %27, label %label_989, label %label_991

label_986:                                        ; preds = %label_982
  %28 = call ptr @type_int__Void()
  ret ptr %28

label_991:                                        ; preds = %label_988
  %29 = load ptr, ptr %tn, align 8
  %30 = getelementptr inbounds nuw %ASTNode, ptr %29, i32 0, i32 1
  %31 = load ptr, ptr %30, align 8
  %32 = call i32 @str_equals(ptr %31, ptr @.str.s399)
  %33 = icmp eq i32 %32, 1
  br i1 %33, label %label_992, label %label_994

label_989:                                        ; preds = %label_988
  %34 = call ptr @type_float__Void()
  ret ptr %34

label_994:                                        ; preds = %label_991
  %35 = load ptr, ptr %tn, align 8
  %36 = getelementptr inbounds nuw %ASTNode, ptr %35, i32 0, i32 1
  %37 = load ptr, ptr %36, align 8
  %38 = call i32 @str_equals(ptr %37, ptr @.str.s400)
  %39 = icmp eq i32 %38, 1
  br i1 %39, label %label_995, label %label_997

label_992:                                        ; preds = %label_991
  %40 = call ptr @type_bool__Void()
  ret ptr %40

label_997:                                        ; preds = %label_994
  %41 = load ptr, ptr %tn, align 8
  %42 = getelementptr inbounds nuw %ASTNode, ptr %41, i32 0, i32 1
  %43 = load ptr, ptr %42, align 8
  %44 = call i32 @str_equals(ptr %43, ptr @.str.s401)
  %45 = icmp eq i32 %44, 1
  br i1 %45, label %label_998, label %label_1000

label_995:                                        ; preds = %label_994
  %46 = call ptr @type_string__Void()
  ret ptr %46

label_1000:                                       ; preds = %label_997
  %47 = load ptr, ptr %tn, align 8
  %48 = getelementptr inbounds nuw %ASTNode, ptr %47, i32 0, i32 1
  %49 = load ptr, ptr %48, align 8
  %50 = call i32 @str_equals(ptr %49, ptr @.str.s402)
  %51 = icmp eq i32 %50, 1
  br i1 %51, label %label_1001, label %label_1003

label_998:                                        ; preds = %label_997
  %52 = call ptr @type_char__Void()
  ret ptr %52

label_1003:                                       ; preds = %label_1000
  %53 = load ptr, ptr %tn, align 8
  %54 = getelementptr inbounds nuw %ASTNode, ptr %53, i32 0, i32 1
  %55 = load ptr, ptr %54, align 8
  %56 = call i32 @str_equals(ptr %55, ptr @.str.s403)
  %57 = icmp eq i32 %56, 1
  br i1 %57, label %label_1004, label %label_1006

label_1001:                                       ; preds = %label_1000
  %58 = call ptr @type_i8__Void()
  ret ptr %58

label_1006:                                       ; preds = %label_1003
  %59 = load ptr, ptr %tn, align 8
  %60 = getelementptr inbounds nuw %ASTNode, ptr %59, i32 0, i32 1
  %61 = load ptr, ptr %60, align 8
  %62 = call i32 @str_equals(ptr %61, ptr @.str.s404)
  %63 = icmp eq i32 %62, 1
  br i1 %63, label %label_1007, label %label_1009

label_1004:                                       ; preds = %label_1003
  %64 = call ptr @type_i16__Void()
  ret ptr %64

label_1009:                                       ; preds = %label_1006
  %65 = load ptr, ptr %tn, align 8
  %66 = getelementptr inbounds nuw %ASTNode, ptr %65, i32 0, i32 1
  %67 = load ptr, ptr %66, align 8
  %68 = call i32 @str_equals(ptr %67, ptr @.str.s405)
  %69 = icmp eq i32 %68, 1
  br i1 %69, label %label_1010, label %label_1012

label_1007:                                       ; preds = %label_1006
  %70 = call ptr @type_i64__Void()
  ret ptr %70

label_1012:                                       ; preds = %label_1009
  %71 = load ptr, ptr %tn, align 8
  %72 = getelementptr inbounds nuw %ASTNode, ptr %71, i32 0, i32 1
  %73 = load ptr, ptr %72, align 8
  %74 = call i32 @str_equals(ptr %73, ptr @.str.s406)
  %75 = icmp eq i32 %74, 1
  br i1 %75, label %label_1013, label %label_1015

label_1010:                                       ; preds = %label_1009
  %76 = call ptr @type_isize__Void()
  ret ptr %76

label_1015:                                       ; preds = %label_1012
  %77 = load ptr, ptr %tn, align 8
  %78 = getelementptr inbounds nuw %ASTNode, ptr %77, i32 0, i32 1
  %79 = load ptr, ptr %78, align 8
  %80 = call i32 @str_equals(ptr %79, ptr @.str.s407)
  %81 = icmp eq i32 %80, 1
  br i1 %81, label %label_1016, label %label_1018

label_1013:                                       ; preds = %label_1012
  %82 = call ptr @type_u8__Void()
  ret ptr %82

label_1018:                                       ; preds = %label_1015
  %83 = load ptr, ptr %tn, align 8
  %84 = getelementptr inbounds nuw %ASTNode, ptr %83, i32 0, i32 1
  %85 = load ptr, ptr %84, align 8
  %86 = call i32 @str_equals(ptr %85, ptr @.str.s408)
  %87 = icmp eq i32 %86, 1
  br i1 %87, label %label_1019, label %label_1021

label_1016:                                       ; preds = %label_1015
  %88 = call ptr @type_u16__Void()
  ret ptr %88

label_1021:                                       ; preds = %label_1018
  %89 = load ptr, ptr %tn, align 8
  %90 = getelementptr inbounds nuw %ASTNode, ptr %89, i32 0, i32 1
  %91 = load ptr, ptr %90, align 8
  %92 = call i32 @str_equals(ptr %91, ptr @.str.s409)
  %93 = icmp eq i32 %92, 1
  br i1 %93, label %label_1022, label %label_1024

label_1019:                                       ; preds = %label_1018
  %94 = call ptr @type_u32__Void()
  ret ptr %94

label_1024:                                       ; preds = %label_1021
  %95 = load ptr, ptr %tn, align 8
  %96 = getelementptr inbounds nuw %ASTNode, ptr %95, i32 0, i32 1
  %97 = load ptr, ptr %96, align 8
  %98 = call i32 @str_equals(ptr %97, ptr @.str.s410)
  %99 = icmp eq i32 %98, 1
  br i1 %99, label %label_1025, label %label_1027

label_1022:                                       ; preds = %label_1021
  %100 = call ptr @type_u64__Void()
  ret ptr %100

label_1027:                                       ; preds = %label_1024
  %101 = load ptr, ptr %tn, align 8
  %102 = getelementptr inbounds nuw %ASTNode, ptr %101, i32 0, i32 1
  %103 = load ptr, ptr %102, align 8
  %104 = call i32 @str_equals(ptr %103, ptr @.str.s411)
  %105 = icmp eq i32 %104, 1
  br i1 %105, label %label_1028, label %label_1030

label_1025:                                       ; preds = %label_1024
  %106 = call ptr @type_usize__Void()
  ret ptr %106

label_1030:                                       ; preds = %label_1027
  %107 = load ptr, ptr %tn, align 8
  %108 = getelementptr inbounds nuw %ASTNode, ptr %107, i32 0, i32 1
  %109 = load ptr, ptr %108, align 8
  %110 = call ptr @type_struct__String(ptr %109)
  ret ptr %110

label_1028:                                       ; preds = %label_1027
  %111 = call ptr @type_void__Void()
  ret ptr %111
}

define ptr @type_from_ir_key__String(ptr %0) {
entry:
  %key = alloca ptr, align 8
  store ptr %0, ptr %key, align 8
  %1 = load ptr, ptr %key, align 8
  %2 = call i32 @str_equals(ptr %1, ptr @.str.s412)
  %3 = icmp eq i32 %2, 1
  br i1 %3, label %label_1031, label %label_1033

label_1033:                                       ; preds = %entry
  %4 = load ptr, ptr %key, align 8
  %5 = call i32 @str_equals(ptr %4, ptr @.str.s413)
  %6 = icmp eq i32 %5, 1
  br i1 %6, label %label_1034, label %label_1036

label_1031:                                       ; preds = %entry
  %7 = call ptr @type_int__Void()
  ret ptr %7

label_1036:                                       ; preds = %label_1033
  %8 = load ptr, ptr %key, align 8
  %9 = call i32 @str_equals(ptr %8, ptr @.str.s414)
  %10 = icmp eq i32 %9, 1
  br i1 %10, label %label_1037, label %label_1039

label_1034:                                       ; preds = %label_1033
  %11 = call ptr @type_float__Void()
  ret ptr %11

label_1039:                                       ; preds = %label_1036
  %12 = load ptr, ptr %key, align 8
  %13 = call i32 @str_equals(ptr %12, ptr @.str.s415)
  %14 = icmp eq i32 %13, 1
  br i1 %14, label %label_1040, label %label_1042

label_1037:                                       ; preds = %label_1036
  %15 = call ptr @type_bool__Void()
  ret ptr %15

label_1042:                                       ; preds = %label_1039
  %16 = load ptr, ptr %key, align 8
  %17 = call i32 @str_equals(ptr %16, ptr @.str.s416)
  %18 = icmp eq i32 %17, 1
  br i1 %18, label %label_1043, label %label_1045

label_1040:                                       ; preds = %label_1039
  %19 = call ptr @type_char__Void()
  ret ptr %19

label_1045:                                       ; preds = %label_1042
  %20 = load ptr, ptr %key, align 8
  %21 = call i32 @str_equals(ptr %20, ptr @.str.s417)
  %22 = icmp eq i32 %21, 1
  br i1 %22, label %label_1046, label %label_1048

label_1043:                                       ; preds = %label_1042
  %23 = call ptr @type_ptr__Void()
  ret ptr %23

label_1048:                                       ; preds = %label_1045
  %24 = load ptr, ptr %key, align 8
  %25 = call i32 @str_starts_with(ptr %24, ptr @.str.s418)
  %26 = icmp eq i32 %25, 1
  br i1 %26, label %label_1049, label %label_1051

label_1046:                                       ; preds = %label_1045
  %27 = call ptr @type_void__Void()
  ret ptr %27

label_1051:                                       ; preds = %label_1048
  %28 = call ptr @type_invalid__Void()
  ret ptr %28

label_1049:                                       ; preds = %label_1048
  %29 = load ptr, ptr %key, align 8
  %30 = load ptr, ptr %key, align 8
  %31 = call i32 @str_length(ptr %30)
  %32 = sub i32 %31, 7
  %33 = call ptr @str_substring(ptr %29, i32 7, i32 %32)
  %34 = call ptr @type_struct__String(ptr %33)
  ret ptr %34
}

define ptr @type_from_sem_key__String(ptr %0) {
entry:
  %key = alloca ptr, align 8
  store ptr %0, ptr %key, align 8
  %1 = load ptr, ptr %key, align 8
  %2 = call i32 @str_equals(ptr %1, ptr @.str.s419)
  %3 = icmp eq i32 %2, 1
  br i1 %3, label %label_1052, label %label_1054

label_1054:                                       ; preds = %entry
  %4 = load ptr, ptr %key, align 8
  %5 = call i32 @str_equals(ptr %4, ptr @.str.s420)
  %6 = icmp eq i32 %5, 1
  br i1 %6, label %label_1055, label %label_1057

label_1052:                                       ; preds = %entry
  %7 = call ptr @type_int__Void()
  ret ptr %7

label_1057:                                       ; preds = %label_1054
  %8 = load ptr, ptr %key, align 8
  %9 = call i32 @str_equals(ptr %8, ptr @.str.s421)
  %10 = icmp eq i32 %9, 1
  br i1 %10, label %label_1058, label %label_1060

label_1055:                                       ; preds = %label_1054
  %11 = call ptr @type_float__Void()
  ret ptr %11

label_1060:                                       ; preds = %label_1057
  %12 = load ptr, ptr %key, align 8
  %13 = call i32 @str_equals(ptr %12, ptr @.str.s422)
  %14 = icmp eq i32 %13, 1
  br i1 %14, label %label_1061, label %label_1063

label_1058:                                       ; preds = %label_1057
  %15 = call ptr @type_bool__Void()
  ret ptr %15

label_1063:                                       ; preds = %label_1060
  %16 = load ptr, ptr %key, align 8
  %17 = call i32 @str_equals(ptr %16, ptr @.str.s423)
  %18 = icmp eq i32 %17, 1
  br i1 %18, label %label_1064, label %label_1066

label_1061:                                       ; preds = %label_1060
  %19 = call ptr @type_char__Void()
  ret ptr %19

label_1066:                                       ; preds = %label_1063
  %20 = load ptr, ptr %key, align 8
  %21 = call i32 @str_equals(ptr %20, ptr @.str.s424)
  %22 = icmp eq i32 %21, 1
  br i1 %22, label %label_1067, label %label_1069

label_1064:                                       ; preds = %label_1063
  %23 = call ptr @type_string__Void()
  ret ptr %23

label_1069:                                       ; preds = %label_1066
  %24 = load ptr, ptr %key, align 8
  %25 = call i32 @str_equals(ptr %24, ptr @.str.s425)
  %26 = icmp eq i32 %25, 1
  br i1 %26, label %label_1070, label %label_1072

label_1067:                                       ; preds = %label_1066
  %27 = call ptr @type_ptr__Void()
  ret ptr %27

label_1072:                                       ; preds = %label_1069
  %28 = load ptr, ptr %key, align 8
  %29 = call i32 @str_equals(ptr %28, ptr @.str.s426)
  %30 = icmp eq i32 %29, 1
  br i1 %30, label %label_1073, label %label_1075

label_1070:                                       ; preds = %label_1069
  %31 = call ptr @type_void__Void()
  ret ptr %31

label_1075:                                       ; preds = %label_1072
  %32 = load ptr, ptr %key, align 8
  %33 = call i32 @str_equals(ptr %32, ptr @.str.s427)
  %34 = icmp eq i32 %33, 1
  br i1 %34, label %label_1076, label %label_1078

label_1073:                                       ; preds = %label_1072
  %35 = call ptr @type_i8__Void()
  ret ptr %35

label_1078:                                       ; preds = %label_1075
  %36 = load ptr, ptr %key, align 8
  %37 = call i32 @str_equals(ptr %36, ptr @.str.s428)
  %38 = icmp eq i32 %37, 1
  br i1 %38, label %label_1079, label %label_1081

label_1076:                                       ; preds = %label_1075
  %39 = call ptr @type_i16__Void()
  ret ptr %39

label_1081:                                       ; preds = %label_1078
  %40 = load ptr, ptr %key, align 8
  %41 = call i32 @str_equals(ptr %40, ptr @.str.s429)
  %42 = icmp eq i32 %41, 1
  br i1 %42, label %label_1082, label %label_1084

label_1079:                                       ; preds = %label_1078
  %43 = call ptr @type_i64__Void()
  ret ptr %43

label_1084:                                       ; preds = %label_1081
  %44 = load ptr, ptr %key, align 8
  %45 = call i32 @str_equals(ptr %44, ptr @.str.s430)
  %46 = icmp eq i32 %45, 1
  br i1 %46, label %label_1085, label %label_1087

label_1082:                                       ; preds = %label_1081
  %47 = call ptr @type_isize__Void()
  ret ptr %47

label_1087:                                       ; preds = %label_1084
  %48 = load ptr, ptr %key, align 8
  %49 = call i32 @str_equals(ptr %48, ptr @.str.s431)
  %50 = icmp eq i32 %49, 1
  br i1 %50, label %label_1088, label %label_1090

label_1085:                                       ; preds = %label_1084
  %51 = call ptr @type_u8__Void()
  ret ptr %51

label_1090:                                       ; preds = %label_1087
  %52 = load ptr, ptr %key, align 8
  %53 = call i32 @str_equals(ptr %52, ptr @.str.s432)
  %54 = icmp eq i32 %53, 1
  br i1 %54, label %label_1091, label %label_1093

label_1088:                                       ; preds = %label_1087
  %55 = call ptr @type_u16__Void()
  ret ptr %55

label_1093:                                       ; preds = %label_1090
  %56 = load ptr, ptr %key, align 8
  %57 = call i32 @str_equals(ptr %56, ptr @.str.s433)
  %58 = icmp eq i32 %57, 1
  br i1 %58, label %label_1094, label %label_1096

label_1091:                                       ; preds = %label_1090
  %59 = call ptr @type_u32__Void()
  ret ptr %59

label_1096:                                       ; preds = %label_1093
  %60 = load ptr, ptr %key, align 8
  %61 = call i32 @str_equals(ptr %60, ptr @.str.s434)
  %62 = icmp eq i32 %61, 1
  br i1 %62, label %label_1097, label %label_1099

label_1094:                                       ; preds = %label_1093
  %63 = call ptr @type_u64__Void()
  ret ptr %63

label_1099:                                       ; preds = %label_1096
  %64 = load ptr, ptr %key, align 8
  %65 = call i32 @str_starts_with(ptr %64, ptr @.str.s435)
  %66 = icmp eq i32 %65, 1
  br i1 %66, label %label_1100, label %label_1102

label_1097:                                       ; preds = %label_1096
  %67 = call ptr @type_usize__Void()
  ret ptr %67

label_1102:                                       ; preds = %label_1099
  %68 = load ptr, ptr %key, align 8
  %69 = call i32 @str_starts_with(ptr %68, ptr @.str.s436)
  %70 = icmp eq i32 %69, 1
  br i1 %70, label %label_1103, label %label_1105

label_1100:                                       ; preds = %label_1099
  %71 = load ptr, ptr %key, align 8
  %72 = load ptr, ptr %key, align 8
  %73 = call i32 @str_length(ptr %72)
  %74 = sub i32 %73, 7
  %75 = call ptr @str_substring(ptr %71, i32 7, i32 %74)
  %76 = call ptr @type_struct__String(ptr %75)
  ret ptr %76

label_1105:                                       ; preds = %label_1102
  %77 = load ptr, ptr %key, align 8
  %78 = call i32 @str_starts_with(ptr %77, ptr @.str.s437)
  %79 = icmp eq i32 %78, 1
  br i1 %79, label %label_1106, label %label_1108

label_1103:                                       ; preds = %label_1102
  %80 = load ptr, ptr %key, align 8
  %81 = load ptr, ptr %key, align 8
  %82 = call i32 @str_length(ptr %81)
  %83 = sub i32 %82, 5
  %84 = call ptr @str_substring(ptr %80, i32 5, i32 %83)
  %85 = call ptr @type_enum__String(ptr %84)
  ret ptr %85

label_1108:                                       ; preds = %label_1105
  %86 = load ptr, ptr %key, align 8
  %87 = call i32 @str_starts_with(ptr %86, ptr @.str.s438)
  %88 = icmp eq i32 %87, 1
  br i1 %88, label %label_1109, label %label_1111

label_1106:                                       ; preds = %label_1105
  %89 = load ptr, ptr %key, align 8
  %90 = load ptr, ptr %key, align 8
  %91 = call i32 @str_length(ptr %90)
  %92 = sub i32 %91, 6
  %93 = call ptr @str_substring(ptr %89, i32 6, i32 %92)
  %94 = call ptr @type_from_sem_key__String(ptr %93)
  %95 = call ptr @type_array__Struct_TypeInfo(ptr %94)
  ret ptr %95

label_1111:                                       ; preds = %label_1108
  %96 = call ptr @type_invalid__Void()
  ret ptr %96

label_1109:                                       ; preds = %label_1108
  %97 = load ptr, ptr %key, align 8
  %98 = load ptr, ptr %key, align 8
  %99 = call i32 @str_length(ptr %98)
  %100 = sub i32 %99, 5
  %101 = call ptr @str_substring(ptr %97, i32 5, i32 %100)
  %102 = call ptr @type_from_sem_key__String(ptr %101)
  %103 = call ptr @type_list__Struct_TypeInfo(ptr %102)
  ret ptr %103
}

define void @node_set_type__Struct_ASTNode_Struct_TypeInfo(ptr %0, ptr %1) {
entry:
  %node = alloca ptr, align 8
  store ptr %0, ptr %node, align 8
  %t = alloca ptr, align 8
  store ptr %1, ptr %t, align 8
  %2 = load ptr, ptr %node, align 8
  %3 = load ptr, ptr %t, align 8
  %4 = call ptr @type_to_ptr(ptr %3)
  %5 = getelementptr inbounds nuw %ASTNode, ptr %2, i32 0, i32 9
  store ptr %4, ptr %5, align 8
  ret void
}

define i1 @node_has_type__Struct_ASTNode(ptr %0) {
entry:
  %node = alloca ptr, align 8
  store ptr %0, ptr %node, align 8
  %1 = load ptr, ptr %node, align 8
  %2 = getelementptr inbounds nuw %ASTNode, ptr %1, i32 0, i32 9
  %3 = load ptr, ptr %2, align 8
  %4 = call i32 @str_equals(ptr %3, ptr @.str.s439)
  %5 = icmp eq i32 %4, 0
  ret i1 %5
}

define ptr @node_get_type__Struct_ASTNode(ptr %0) {
entry:
  %node = alloca ptr, align 8
  store ptr %0, ptr %node, align 8
  %1 = load ptr, ptr %node, align 8
  %2 = call i1 @node_has_type__Struct_ASTNode(ptr %1)
  br i1 %2, label %label_1112, label %label_1114

label_1114:                                       ; preds = %entry
  %3 = call ptr @type_invalid__Void()
  ret ptr %3

label_1112:                                       ; preds = %entry
  %4 = load ptr, ptr %node, align 8
  %5 = getelementptr inbounds nuw %ASTNode, ptr %4, i32 0, i32 9
  %6 = load ptr, ptr %5, align 8
  %7 = call ptr @ptr_to_type(ptr %6)
  ret ptr %7
}

define void @ir_set_target_wasm__Bool(i1 %0) {
entry:
  %enabled = alloca i1, align 1
  store i1 %0, ptr %enabled, align 1
  %1 = load i1, ptr %enabled, align 1
  store i1 %1, ptr @ir_target_wasm, align 1
  ret void
}

define ptr @ir_ptr_int_type__Void() {
entry:
  %0 = load i1, ptr @ir_target_wasm, align 1
  br i1 %0, label %label_1115, label %label_1117

label_1117:                                       ; preds = %entry
  ret ptr @.str.s441

label_1115:                                       ; preds = %entry
  ret ptr @.str.s440
}

define ptr @map_type__String(ptr %0) {
entry:
  %t = alloca ptr, align 8
  store ptr %0, ptr %t, align 8
  %1 = load ptr, ptr %t, align 8
  %2 = call i32 @str_equals(ptr %1, ptr @.str.s442)
  %3 = icmp eq i32 %2, 1
  br i1 %3, label %label_1118, label %label_1120

label_1120:                                       ; preds = %entry
  %4 = load ptr, ptr %t, align 8
  %5 = call i32 @str_equals(ptr %4, ptr @.str.s444)
  %6 = icmp eq i32 %5, 1
  br i1 %6, label %label_1121, label %label_1123

label_1118:                                       ; preds = %entry
  ret ptr @.str.s443

label_1123:                                       ; preds = %label_1120
  %7 = load ptr, ptr %t, align 8
  %8 = call i32 @str_equals(ptr %7, ptr @.str.s446)
  %9 = icmp eq i32 %8, 1
  br i1 %9, label %label_1124, label %label_1126

label_1121:                                       ; preds = %label_1120
  ret ptr @.str.s445

label_1126:                                       ; preds = %label_1123
  %10 = load ptr, ptr %t, align 8
  %11 = call i32 @str_equals(ptr %10, ptr @.str.s448)
  %12 = icmp eq i32 %11, 1
  br i1 %12, label %label_1127, label %label_1129

label_1124:                                       ; preds = %label_1123
  ret ptr @.str.s447

label_1129:                                       ; preds = %label_1126
  %13 = load ptr, ptr %t, align 8
  %14 = call i32 @str_equals(ptr %13, ptr @.str.s450)
  %15 = icmp eq i32 %14, 1
  br i1 %15, label %label_1130, label %label_1132

label_1127:                                       ; preds = %label_1126
  ret ptr @.str.s449

label_1132:                                       ; preds = %label_1129
  %16 = load ptr, ptr %t, align 8
  %17 = call i32 @str_equals(ptr %16, ptr @.str.s452)
  %18 = icmp eq i32 %17, 1
  br i1 %18, label %label_1133, label %label_1135

label_1130:                                       ; preds = %label_1129
  ret ptr @.str.s451

label_1135:                                       ; preds = %label_1132
  %19 = load ptr, ptr %t, align 8
  %20 = call i32 @str_equals(ptr %19, ptr @.str.s454)
  %21 = icmp eq i32 %20, 1
  br i1 %21, label %label_1136, label %label_1138

label_1133:                                       ; preds = %label_1132
  ret ptr @.str.s453

label_1138:                                       ; preds = %label_1135
  %22 = load ptr, ptr %t, align 8
  %23 = call i32 @str_equals(ptr %22, ptr @.str.s456)
  %24 = icmp eq i32 %23, 1
  br i1 %24, label %label_1139, label %label_1141

label_1136:                                       ; preds = %label_1135
  ret ptr @.str.s455

label_1141:                                       ; preds = %label_1138
  %25 = load ptr, ptr %t, align 8
  %26 = call i32 @str_equals(ptr %25, ptr @.str.s458)
  %27 = icmp eq i32 %26, 1
  br i1 %27, label %label_1142, label %label_1144

label_1139:                                       ; preds = %label_1138
  ret ptr @.str.s457

label_1144:                                       ; preds = %label_1141
  %28 = load ptr, ptr %t, align 8
  %29 = call i32 @str_equals(ptr %28, ptr @.str.s459)
  %30 = icmp eq i32 %29, 1
  br i1 %30, label %label_1145, label %label_1147

label_1142:                                       ; preds = %label_1141
  %31 = call ptr @ir_ptr_int_type__Void()
  ret ptr %31

label_1147:                                       ; preds = %label_1144
  %32 = load ptr, ptr %t, align 8
  %33 = call i32 @str_equals(ptr %32, ptr @.str.s461)
  %34 = icmp eq i32 %33, 1
  br i1 %34, label %label_1148, label %label_1150

label_1145:                                       ; preds = %label_1144
  ret ptr @.str.s460

label_1150:                                       ; preds = %label_1147
  %35 = load ptr, ptr %t, align 8
  %36 = call i32 @str_equals(ptr %35, ptr @.str.s463)
  %37 = icmp eq i32 %36, 1
  br i1 %37, label %label_1151, label %label_1153

label_1148:                                       ; preds = %label_1147
  ret ptr @.str.s462

label_1153:                                       ; preds = %label_1150
  %38 = load ptr, ptr %t, align 8
  %39 = call i32 @str_equals(ptr %38, ptr @.str.s465)
  %40 = icmp eq i32 %39, 1
  br i1 %40, label %label_1154, label %label_1156

label_1151:                                       ; preds = %label_1150
  ret ptr @.str.s464

label_1156:                                       ; preds = %label_1153
  %41 = load ptr, ptr %t, align 8
  %42 = call i32 @str_equals(ptr %41, ptr @.str.s467)
  %43 = icmp eq i32 %42, 1
  br i1 %43, label %label_1157, label %label_1159

label_1154:                                       ; preds = %label_1153
  ret ptr @.str.s466

label_1159:                                       ; preds = %label_1156
  %44 = load ptr, ptr %t, align 8
  %45 = call i32 @str_equals(ptr %44, ptr @.str.s468)
  %46 = icmp eq i32 %45, 1
  br i1 %46, label %label_1160, label %label_1162

label_1157:                                       ; preds = %label_1156
  %47 = call ptr @ir_ptr_int_type__Void()
  ret ptr %47

label_1162:                                       ; preds = %label_1159
  ret ptr @.str.s470

label_1160:                                       ; preds = %label_1159
  ret ptr @.str.s469
}

define ptr @struct_type_key__String(ptr %0) {
entry:
  %name = alloca ptr, align 8
  store ptr %0, ptr %name, align 8
  %1 = load ptr, ptr %name, align 8
  %2 = call ptr @str_concat(ptr @.str.s471, ptr %1)
  ret ptr %2
}

define i1 @is_struct_type_key__String(ptr %0) {
entry:
  %t = alloca ptr, align 8
  store ptr %0, ptr %t, align 8
  %1 = load ptr, ptr %t, align 8
  %2 = call i32 @str_starts_with(ptr %1, ptr @.str.s472)
  %3 = icmp eq i32 %2, 1
  ret i1 %3
}

define ptr @struct_type_name__String(ptr %0) {
entry:
  %t = alloca ptr, align 8
  store ptr %0, ptr %t, align 8
  %1 = load ptr, ptr %t, align 8
  %2 = load ptr, ptr %t, align 8
  %3 = call i32 @str_length(ptr %2)
  %4 = sub i32 %3, 7
  %5 = call ptr @str_substring(ptr %1, i32 7, i32 %4)
  ret ptr %5
}

define ptr @llvm_type_name__String(ptr %0) {
entry:
  %t = alloca ptr, align 8
  store ptr %0, ptr %t, align 8
  %1 = load ptr, ptr %t, align 8
  %2 = call i1 @is_struct_type_key__String(ptr %1)
  br i1 %2, label %label_1163, label %label_1165

label_1165:                                       ; preds = %entry
  %3 = load ptr, ptr %t, align 8
  ret ptr %3

label_1163:                                       ; preds = %entry
  %4 = load ptr, ptr %t, align 8
  %5 = call ptr @struct_type_name__String(ptr %4)
  %6 = call ptr @str_concat(ptr @.str.s473, ptr %5)
  ret ptr %6
}

define ptr @map_type_node__Struct_ASTNode(ptr %0) {
entry:
  %tn = alloca ptr, align 8
  store ptr %0, ptr %tn, align 8
  %elem = alloca ptr, align 8
  %1 = load ptr, ptr %tn, align 8
  %2 = getelementptr inbounds nuw %ASTNode, ptr %1, i32 0, i32 4
  %3 = load i32, ptr %2, align 4
  %4 = icmp eq i32 %3, 1
  br i1 %4, label %label_1166, label %label_1168

label_1168:                                       ; preds = %entry
  %5 = load ptr, ptr %tn, align 8
  %6 = getelementptr inbounds nuw %ASTNode, ptr %5, i32 0, i32 3
  %7 = load i32, ptr %6, align 4
  %8 = icmp eq i32 %7, 1
  br i1 %8, label %label_1169, label %label_1171

label_1166:                                       ; preds = %entry
  ret ptr @.str.s474

label_1171:                                       ; preds = %label_1168
  %9 = load ptr, ptr %tn, align 8
  %10 = getelementptr inbounds nuw %ASTNode, ptr %9, i32 0, i32 1
  %11 = load ptr, ptr %10, align 8
  %12 = call i32 @ir_is_struct_type_name(ptr %11)
  %13 = icmp eq i32 %12, 1
  br i1 %13, label %label_1178, label %label_1180

label_1169:                                       ; preds = %label_1168
  %14 = load ptr, ptr %tn, align 8
  %15 = getelementptr inbounds nuw %ASTNode, ptr %14, i32 0, i32 5
  %16 = load ptr, ptr %15, align 8
  %17 = call i32 @str_equals(ptr %16, ptr @.str.s475)
  %18 = icmp eq i32 %17, 0
  br i1 %18, label %label_1172, label %label_1174

label_1174:                                       ; preds = %label_1177, %label_1169
  ret ptr @.str.s477

label_1172:                                       ; preds = %label_1169
  %19 = load ptr, ptr %tn, align 8
  %20 = getelementptr inbounds nuw %ASTNode, ptr %19, i32 0, i32 5
  %21 = load ptr, ptr %20, align 8
  %22 = call ptr @ptr_to_node(ptr %21)
  store ptr %22, ptr %elem, align 8
  %23 = load ptr, ptr %elem, align 8
  %24 = getelementptr inbounds nuw %ASTNode, ptr %23, i32 0, i32 3
  %25 = load i32, ptr %24, align 4
  %26 = icmp eq i32 %25, 1
  br i1 %26, label %label_1175, label %label_1177

label_1177:                                       ; preds = %label_1172
  br label %label_1174

label_1175:                                       ; preds = %label_1172
  ret ptr @.str.s476

label_1180:                                       ; preds = %label_1171
  %27 = load ptr, ptr %tn, align 8
  %28 = getelementptr inbounds nuw %ASTNode, ptr %27, i32 0, i32 1
  %29 = load ptr, ptr %28, align 8
  %30 = call ptr @map_type__String(ptr %29)
  ret ptr %30

label_1178:                                       ; preds = %label_1171
  %31 = load ptr, ptr %tn, align 8
  %32 = getelementptr inbounds nuw %ASTNode, ptr %31, i32 0, i32 1
  %33 = load ptr, ptr %32, align 8
  %34 = call ptr @struct_type_key__String(ptr %33)
  ret ptr %34
}

define ptr @storage_type__String(ptr %0) {
entry:
  %t = alloca ptr, align 8
  store ptr %0, ptr %t, align 8
  %1 = load ptr, ptr %t, align 8
  %2 = call i32 @str_equals(ptr %1, ptr @.str.s478)
  %3 = icmp eq i32 %2, 1
  br i1 %3, label %label_1181, label %label_1183

label_1183:                                       ; preds = %entry
  %4 = load ptr, ptr %t, align 8
  %5 = call i1 @is_struct_type_key__String(ptr %4)
  br i1 %5, label %label_1184, label %label_1186

label_1181:                                       ; preds = %entry
  ret ptr @.str.s479

label_1186:                                       ; preds = %label_1183
  %6 = load ptr, ptr %t, align 8
  ret ptr %6

label_1184:                                       ; preds = %label_1183
  ret ptr @.str.s480
}

define i32 @count_list_nodes__String(ptr %0) {
entry:
  %first_ptr = alloca ptr, align 8
  store ptr %0, ptr %first_ptr, align 8
  %count = alloca i32, align 4
  %curr = alloca ptr, align 8
  %node = alloca ptr, align 8
  store i32 0, ptr %count, align 4
  %1 = load ptr, ptr %first_ptr, align 8
  store ptr %1, ptr %curr, align 8
  br label %label_1187

label_1187:                                       ; preds = %label_1188, %entry
  %2 = load ptr, ptr %curr, align 8
  %3 = call i32 @str_equals(ptr %2, ptr @.str.s481)
  %4 = icmp eq i32 %3, 0
  br i1 %4, label %label_1188, label %label_1189

label_1189:                                       ; preds = %label_1187
  %5 = load i32, ptr %count, align 4
  ret i32 %5

label_1188:                                       ; preds = %label_1187
  %6 = load ptr, ptr %curr, align 8
  %7 = call ptr @ptr_to_node(ptr %6)
  store ptr %7, ptr %node, align 8
  %8 = load i32, ptr %count, align 4
  %9 = add i32 %8, 1
  store i32 %9, ptr %count, align 4
  %10 = load ptr, ptr %node, align 8
  %11 = getelementptr inbounds nuw %ASTNode, ptr %10, i32 0, i32 8
  %12 = load ptr, ptr %11, align 8
  store ptr %12, ptr %curr, align 8
  br label %label_1187
}

define ptr @fn_key__String(ptr %0) {
entry:
  %name = alloca ptr, align 8
  store ptr %0, ptr %name, align 8
  %1 = load ptr, ptr %name, align 8
  %2 = call ptr @str_concat(ptr @.str.s482, ptr %1)
  ret ptr %2
}

define ptr @function_symbol_name__Struct_ASTNode(ptr %0) {
entry:
  %func = alloca ptr, align 8
  store ptr %0, ptr %func, align 8
  %1 = load ptr, ptr %func, align 8
  %2 = getelementptr inbounds nuw %ASTNode, ptr %1, i32 0, i32 2
  %3 = load ptr, ptr %2, align 8
  %4 = call i32 @str_equals(ptr %3, ptr @.str.s483)
  %5 = icmp eq i32 %4, 0
  br i1 %5, label %label_1190, label %label_1192

label_1192:                                       ; preds = %entry
  %6 = load ptr, ptr %func, align 8
  %7 = getelementptr inbounds nuw %ASTNode, ptr %6, i32 0, i32 1
  %8 = load ptr, ptr %7, align 8
  ret ptr %8

label_1190:                                       ; preds = %entry
  %9 = load ptr, ptr %func, align 8
  %10 = getelementptr inbounds nuw %ASTNode, ptr %9, i32 0, i32 2
  %11 = load ptr, ptr %10, align 8
  ret ptr %11
}

define ptr @get_declared_return_type__Struct_ASTNode_String(ptr %0, ptr %1) {
entry:
  %node = alloca ptr, align 8
  store ptr %0, ptr %node, align 8
  %ret_child = alloca ptr, align 8
  store ptr %1, ptr %ret_child, align 8
  %ret_node = alloca ptr, align 8
  %2 = load ptr, ptr %ret_child, align 8
  %3 = call i32 @str_equals(ptr %2, ptr @.str.s484)
  %4 = icmp eq i32 %3, 0
  br i1 %4, label %label_1193, label %label_1195

label_1195:                                       ; preds = %entry
  ret ptr @.str.s485

label_1193:                                       ; preds = %entry
  %5 = load ptr, ptr %ret_child, align 8
  %6 = call ptr @ptr_to_node(ptr %5)
  store ptr %6, ptr %ret_node, align 8
  %7 = load ptr, ptr %ret_node, align 8
  %8 = call ptr @map_type_node__Struct_ASTNode(ptr %7)
  ret ptr %8
}

define ptr @get_expr_type__Struct_ASTNode(ptr %0) {
entry:
  %expr = alloca ptr, align 8
  store ptr %0, ptr %expr, align 8
  %op = alloca ptr, align 8
  %callee = alloca ptr, align 8
  %func_name = alloca ptr, align 8
  %obj_type = alloca ptr, align 8
  %object_node = alloca ptr, align 8
  %enum_val = alloca i32, align 4
  %object_type = alloca ptr, align 8
  %1 = load ptr, ptr %expr, align 8
  %2 = call i1 @node_has_type__Struct_ASTNode(ptr %1)
  br i1 %2, label %label_1196, label %label_1198

label_1198:                                       ; preds = %entry
  %3 = load ptr, ptr %expr, align 8
  %4 = getelementptr inbounds nuw %ASTNode, ptr %3, i32 0, i32 0
  %5 = load i32, ptr %4, align 4
  %6 = icmp eq i32 %5, 22
  br i1 %6, label %label_1199, label %label_1201

label_1196:                                       ; preds = %entry
  %7 = load ptr, ptr %expr, align 8
  %8 = call ptr @node_get_type__Struct_ASTNode(ptr %7)
  %9 = call ptr @type_ir_key__Struct_TypeInfo(ptr %8)
  ret ptr %9

label_1201:                                       ; preds = %label_1216, %label_1198
  %10 = load ptr, ptr %expr, align 8
  %11 = getelementptr inbounds nuw %ASTNode, ptr %10, i32 0, i32 0
  %12 = load i32, ptr %11, align 4
  %13 = icmp eq i32 %12, 23
  br i1 %13, label %label_1217, label %label_1219

label_1199:                                       ; preds = %label_1198
  %14 = load ptr, ptr %expr, align 8
  %15 = getelementptr inbounds nuw %ASTNode, ptr %14, i32 0, i32 3
  %16 = load i32, ptr %15, align 4
  %17 = icmp eq i32 %16, 2
  br i1 %17, label %label_1202, label %label_1204

label_1204:                                       ; preds = %label_1199
  %18 = load ptr, ptr %expr, align 8
  %19 = getelementptr inbounds nuw %ASTNode, ptr %18, i32 0, i32 3
  %20 = load i32, ptr %19, align 4
  %21 = icmp eq i32 %20, 3
  br i1 %21, label %label_1205, label %label_1207

label_1202:                                       ; preds = %label_1199
  ret ptr @.str.s486

label_1207:                                       ; preds = %label_1204
  %22 = load ptr, ptr %expr, align 8
  %23 = getelementptr inbounds nuw %ASTNode, ptr %22, i32 0, i32 3
  %24 = load i32, ptr %23, align 4
  %25 = icmp eq i32 %24, 4
  br i1 %25, label %label_1208, label %label_1210

label_1205:                                       ; preds = %label_1204
  ret ptr @.str.s487

label_1210:                                       ; preds = %label_1207
  %26 = load ptr, ptr %expr, align 8
  %27 = getelementptr inbounds nuw %ASTNode, ptr %26, i32 0, i32 3
  %28 = load i32, ptr %27, align 4
  %29 = icmp eq i32 %28, 1
  br i1 %29, label %label_1211, label %label_1213

label_1208:                                       ; preds = %label_1207
  ret ptr @.str.s488

label_1213:                                       ; preds = %label_1210
  %30 = load ptr, ptr %expr, align 8
  %31 = getelementptr inbounds nuw %ASTNode, ptr %30, i32 0, i32 3
  %32 = load i32, ptr %31, align 4
  %33 = icmp eq i32 %32, 0
  br i1 %33, label %label_1214, label %label_1216

label_1211:                                       ; preds = %label_1210
  ret ptr @.str.s489

label_1216:                                       ; preds = %label_1213
  br label %label_1201

label_1214:                                       ; preds = %label_1213
  ret ptr @.str.s490

label_1219:                                       ; preds = %label_1201
  %34 = load ptr, ptr %expr, align 8
  %35 = getelementptr inbounds nuw %ASTNode, ptr %34, i32 0, i32 0
  %36 = load i32, ptr %35, align 4
  %37 = icmp eq i32 %36, 21
  br i1 %37, label %label_1220, label %label_1222

label_1217:                                       ; preds = %label_1201
  %38 = load ptr, ptr %expr, align 8
  %39 = getelementptr inbounds nuw %ASTNode, ptr %38, i32 0, i32 1
  %40 = load ptr, ptr %39, align 8
  %41 = call ptr @ir_get_var_type(ptr %40)
  ret ptr %41

label_1222:                                       ; preds = %label_1219
  %42 = load ptr, ptr %expr, align 8
  %43 = getelementptr inbounds nuw %ASTNode, ptr %42, i32 0, i32 0
  %44 = load i32, ptr %43, align 4
  %45 = icmp eq i32 %44, 29
  br i1 %45, label %label_1226, label %label_1228

label_1220:                                       ; preds = %label_1219
  %46 = load ptr, ptr %expr, align 8
  %47 = getelementptr inbounds nuw %ASTNode, ptr %46, i32 0, i32 1
  %48 = load ptr, ptr %47, align 8
  %49 = call i32 @str_equals(ptr %48, ptr @.str.s491)
  %50 = icmp eq i32 %49, 1
  br i1 %50, label %label_1223, label %label_1225

label_1225:                                       ; preds = %label_1220
  %51 = load ptr, ptr %expr, align 8
  %52 = getelementptr inbounds nuw %ASTNode, ptr %51, i32 0, i32 5
  %53 = load ptr, ptr %52, align 8
  %54 = call ptr @ptr_to_node(ptr %53)
  %55 = call ptr @get_expr_type__Struct_ASTNode(ptr %54)
  ret ptr %55

label_1223:                                       ; preds = %label_1220
  ret ptr @.str.s492

label_1228:                                       ; preds = %label_1222
  %56 = load ptr, ptr %expr, align 8
  %57 = getelementptr inbounds nuw %ASTNode, ptr %56, i32 0, i32 0
  %58 = load i32, ptr %57, align 4
  %59 = icmp eq i32 %58, 20
  br i1 %59, label %label_1229, label %label_1231

label_1226:                                       ; preds = %label_1222
  %60 = load ptr, ptr %expr, align 8
  %61 = getelementptr inbounds nuw %ASTNode, ptr %60, i32 0, i32 6
  %62 = load ptr, ptr %61, align 8
  %63 = call ptr @ptr_to_node(ptr %62)
  %64 = call ptr @map_type_node__Struct_ASTNode(ptr %63)
  ret ptr %64

label_1231:                                       ; preds = %label_1228
  %65 = load ptr, ptr %expr, align 8
  %66 = getelementptr inbounds nuw %ASTNode, ptr %65, i32 0, i32 0
  %67 = load i32, ptr %66, align 4
  %68 = icmp eq i32 %67, 24
  br i1 %68, label %label_1252, label %label_1254

label_1229:                                       ; preds = %label_1228
  %69 = load ptr, ptr %expr, align 8
  %70 = getelementptr inbounds nuw %ASTNode, ptr %69, i32 0, i32 1
  %71 = load ptr, ptr %70, align 8
  store ptr %71, ptr %op, align 8
  %sc.76 = alloca i1, align 1
  %72 = load ptr, ptr %op, align 8
  %73 = call i32 @str_equals(ptr %72, ptr @.str.s493)
  %74 = icmp eq i32 %73, 1
  store i1 %74, ptr %sc.76, align 1
  br i1 %74, label %label_1233, label %label_1232

label_1232:                                       ; preds = %label_1229
  %75 = load ptr, ptr %op, align 8
  %76 = call i32 @str_equals(ptr %75, ptr @.str.s494)
  %77 = icmp eq i32 %76, 1
  store i1 %77, ptr %sc.76, align 1
  br label %label_1233

label_1233:                                       ; preds = %label_1232, %label_1229
  %78 = load i1, ptr %sc.76, align 1
  br i1 %78, label %label_1234, label %label_1236

label_1236:                                       ; preds = %label_1233
  %sc.77 = alloca i1, align 1
  %79 = load ptr, ptr %op, align 8
  %80 = call i32 @str_equals(ptr %79, ptr @.str.s496)
  %81 = icmp eq i32 %80, 1
  store i1 %81, ptr %sc.77, align 1
  br i1 %81, label %label_1238, label %label_1237

label_1234:                                       ; preds = %label_1233
  ret ptr @.str.s495

label_1237:                                       ; preds = %label_1236
  %82 = load ptr, ptr %op, align 8
  %83 = call i32 @str_equals(ptr %82, ptr @.str.s497)
  %84 = icmp eq i32 %83, 1
  store i1 %84, ptr %sc.77, align 1
  br label %label_1238

label_1238:                                       ; preds = %label_1237, %label_1236
  %85 = load i1, ptr %sc.77, align 1
  br i1 %85, label %label_1239, label %label_1241

label_1241:                                       ; preds = %label_1238
  %sc.78 = alloca i1, align 1
  %86 = load ptr, ptr %op, align 8
  %87 = call i32 @str_equals(ptr %86, ptr @.str.s499)
  %88 = icmp eq i32 %87, 1
  store i1 %88, ptr %sc.78, align 1
  br i1 %88, label %label_1243, label %label_1242

label_1239:                                       ; preds = %label_1238
  ret ptr @.str.s498

label_1242:                                       ; preds = %label_1241
  %89 = load ptr, ptr %op, align 8
  %90 = call i32 @str_equals(ptr %89, ptr @.str.s500)
  %91 = icmp eq i32 %90, 1
  store i1 %91, ptr %sc.78, align 1
  br label %label_1243

label_1243:                                       ; preds = %label_1242, %label_1241
  %92 = load i1, ptr %sc.78, align 1
  br i1 %92, label %label_1244, label %label_1246

label_1246:                                       ; preds = %label_1243
  %sc.79 = alloca i1, align 1
  %93 = load ptr, ptr %op, align 8
  %94 = call i32 @str_equals(ptr %93, ptr @.str.s502)
  %95 = icmp eq i32 %94, 1
  store i1 %95, ptr %sc.79, align 1
  br i1 %95, label %label_1248, label %label_1247

label_1244:                                       ; preds = %label_1243
  ret ptr @.str.s501

label_1247:                                       ; preds = %label_1246
  %96 = load ptr, ptr %op, align 8
  %97 = call i32 @str_equals(ptr %96, ptr @.str.s503)
  %98 = icmp eq i32 %97, 1
  store i1 %98, ptr %sc.79, align 1
  br label %label_1248

label_1248:                                       ; preds = %label_1247, %label_1246
  %99 = load i1, ptr %sc.79, align 1
  br i1 %99, label %label_1249, label %label_1251

label_1251:                                       ; preds = %label_1248
  %100 = load ptr, ptr %expr, align 8
  %101 = getelementptr inbounds nuw %ASTNode, ptr %100, i32 0, i32 5
  %102 = load ptr, ptr %101, align 8
  %103 = call ptr @ptr_to_node(ptr %102)
  %104 = call ptr @get_expr_type__Struct_ASTNode(ptr %103)
  ret ptr %104

label_1249:                                       ; preds = %label_1248
  ret ptr @.str.s504

label_1254:                                       ; preds = %label_1231
  %105 = load ptr, ptr %expr, align 8
  %106 = getelementptr inbounds nuw %ASTNode, ptr %105, i32 0, i32 0
  %107 = load i32, ptr %106, align 4
  %108 = icmp eq i32 %107, 26
  br i1 %108, label %label_1283, label %label_1285

label_1252:                                       ; preds = %label_1231
  %109 = load ptr, ptr %expr, align 8
  %110 = getelementptr inbounds nuw %ASTNode, ptr %109, i32 0, i32 5
  %111 = load ptr, ptr %110, align 8
  %112 = call ptr @ptr_to_node(ptr %111)
  store ptr %112, ptr %callee, align 8
  %113 = load ptr, ptr %callee, align 8
  %114 = getelementptr inbounds nuw %ASTNode, ptr %113, i32 0, i32 1
  %115 = load ptr, ptr %114, align 8
  store ptr %115, ptr %func_name, align 8
  %sc.80 = alloca i1, align 1
  %116 = load ptr, ptr %func_name, align 8
  %117 = call i32 @str_equals(ptr %116, ptr @.str.s505)
  %118 = icmp eq i32 %117, 1
  store i1 %118, ptr %sc.80, align 1
  br i1 %118, label %label_1256, label %label_1255

label_1255:                                       ; preds = %label_1252
  %119 = load ptr, ptr %func_name, align 8
  %120 = call i32 @str_equals(ptr %119, ptr @.str.s506)
  %121 = icmp eq i32 %120, 1
  store i1 %121, ptr %sc.80, align 1
  br label %label_1256

label_1256:                                       ; preds = %label_1255, %label_1252
  %122 = load i1, ptr %sc.80, align 1
  br i1 %122, label %label_1257, label %label_1259

label_1259:                                       ; preds = %label_1256
  %sc.81 = alloca i1, align 1
  %123 = load ptr, ptr %func_name, align 8
  %124 = call i32 @str_equals(ptr %123, ptr @.str.s508)
  %125 = icmp eq i32 %124, 1
  store i1 %125, ptr %sc.81, align 1
  br i1 %125, label %label_1261, label %label_1260

label_1257:                                       ; preds = %label_1256
  ret ptr @.str.s507

label_1260:                                       ; preds = %label_1259
  %126 = load ptr, ptr %func_name, align 8
  %127 = call i32 @str_equals(ptr %126, ptr @.str.s509)
  %128 = icmp eq i32 %127, 1
  store i1 %128, ptr %sc.81, align 1
  br label %label_1261

label_1261:                                       ; preds = %label_1260, %label_1259
  %129 = load i1, ptr %sc.81, align 1
  br i1 %129, label %label_1262, label %label_1264

label_1264:                                       ; preds = %label_1261
  %sc.82 = alloca i1, align 1
  %130 = load ptr, ptr %func_name, align 8
  %131 = call i32 @str_equals(ptr %130, ptr @.str.s511)
  %132 = icmp eq i32 %131, 1
  store i1 %132, ptr %sc.82, align 1
  br i1 %132, label %label_1266, label %label_1265

label_1262:                                       ; preds = %label_1261
  ret ptr @.str.s510

label_1265:                                       ; preds = %label_1264
  %133 = load ptr, ptr %func_name, align 8
  %134 = call i32 @str_equals(ptr %133, ptr @.str.s512)
  %135 = icmp eq i32 %134, 1
  store i1 %135, ptr %sc.82, align 1
  br label %label_1266

label_1266:                                       ; preds = %label_1265, %label_1264
  %136 = load i1, ptr %sc.82, align 1
  br i1 %136, label %label_1267, label %label_1269

label_1269:                                       ; preds = %label_1266
  %sc.83 = alloca i1, align 1
  %137 = load ptr, ptr %func_name, align 8
  %138 = call i32 @str_equals(ptr %137, ptr @.str.s514)
  %139 = icmp eq i32 %138, 1
  store i1 %139, ptr %sc.83, align 1
  br i1 %139, label %label_1271, label %label_1270

label_1267:                                       ; preds = %label_1266
  ret ptr @.str.s513

label_1270:                                       ; preds = %label_1269
  %140 = load ptr, ptr %func_name, align 8
  %141 = call i32 @str_equals(ptr %140, ptr @.str.s515)
  %142 = icmp eq i32 %141, 1
  store i1 %142, ptr %sc.83, align 1
  br label %label_1271

label_1271:                                       ; preds = %label_1270, %label_1269
  %143 = load i1, ptr %sc.83, align 1
  br i1 %143, label %label_1272, label %label_1274

label_1274:                                       ; preds = %label_1271
  %sc.84 = alloca i1, align 1
  %144 = load ptr, ptr %func_name, align 8
  %145 = call i32 @str_equals(ptr %144, ptr @.str.s517)
  %146 = icmp eq i32 %145, 1
  store i1 %146, ptr %sc.84, align 1
  br i1 %146, label %label_1276, label %label_1275

label_1272:                                       ; preds = %label_1271
  ret ptr @.str.s516

label_1275:                                       ; preds = %label_1274
  %147 = load ptr, ptr %func_name, align 8
  %148 = call i32 @str_equals(ptr %147, ptr @.str.s518)
  %149 = icmp eq i32 %148, 1
  store i1 %149, ptr %sc.84, align 1
  br label %label_1276

label_1276:                                       ; preds = %label_1275, %label_1274
  %150 = load i1, ptr %sc.84, align 1
  br i1 %150, label %label_1277, label %label_1279

label_1279:                                       ; preds = %label_1276
  %151 = load ptr, ptr %expr, align 8
  %152 = getelementptr inbounds nuw %ASTNode, ptr %151, i32 0, i32 2
  %153 = load ptr, ptr %152, align 8
  %154 = call i32 @str_equals(ptr %153, ptr @.str.s520)
  %155 = icmp eq i32 %154, 0
  br i1 %155, label %label_1280, label %label_1282

label_1277:                                       ; preds = %label_1276
  ret ptr @.str.s519

label_1282:                                       ; preds = %label_1279
  %156 = load ptr, ptr %func_name, align 8
  %157 = call ptr @fn_key__String(ptr %156)
  %158 = call ptr @ir_get_var_type(ptr %157)
  ret ptr %158

label_1280:                                       ; preds = %label_1279
  %159 = load ptr, ptr %expr, align 8
  %160 = getelementptr inbounds nuw %ASTNode, ptr %159, i32 0, i32 2
  %161 = load ptr, ptr %160, align 8
  %162 = call ptr @fn_key__String(ptr %161)
  %163 = call ptr @ir_get_var_type(ptr %162)
  ret ptr %163

label_1285:                                       ; preds = %label_1254
  %164 = load ptr, ptr %expr, align 8
  %165 = getelementptr inbounds nuw %ASTNode, ptr %164, i32 0, i32 0
  %166 = load i32, ptr %165, align 4
  %167 = icmp eq i32 %166, 25
  br i1 %167, label %label_1289, label %label_1291

label_1283:                                       ; preds = %label_1254
  %168 = load ptr, ptr %expr, align 8
  %169 = getelementptr inbounds nuw %ASTNode, ptr %168, i32 0, i32 5
  %170 = load ptr, ptr %169, align 8
  %171 = call ptr @ptr_to_node(ptr %170)
  %172 = call ptr @get_expr_type__Struct_ASTNode(ptr %171)
  store ptr %172, ptr %obj_type, align 8
  %173 = load ptr, ptr %obj_type, align 8
  %174 = call i32 @str_equals(ptr %173, ptr @.str.s521)
  %175 = icmp eq i32 %174, 1
  br i1 %175, label %label_1286, label %label_1288

label_1288:                                       ; preds = %label_1283
  ret ptr @.str.s523

label_1286:                                       ; preds = %label_1283
  ret ptr @.str.s522

label_1291:                                       ; preds = %label_1285
  %176 = load ptr, ptr %expr, align 8
  %177 = getelementptr inbounds nuw %ASTNode, ptr %176, i32 0, i32 0
  %178 = load i32, ptr %177, align 4
  %179 = icmp eq i32 %178, 27
  br i1 %179, label %label_1301, label %label_1303

label_1289:                                       ; preds = %label_1285
  %180 = load ptr, ptr %expr, align 8
  %181 = getelementptr inbounds nuw %ASTNode, ptr %180, i32 0, i32 5
  %182 = load ptr, ptr %181, align 8
  %183 = call ptr @ptr_to_node(ptr %182)
  store ptr %183, ptr %object_node, align 8
  %184 = load ptr, ptr %object_node, align 8
  %185 = getelementptr inbounds nuw %ASTNode, ptr %184, i32 0, i32 0
  %186 = load i32, ptr %185, align 4
  %187 = icmp eq i32 %186, 23
  br i1 %187, label %label_1292, label %label_1294

label_1294:                                       ; preds = %label_1297, %label_1289
  %188 = load ptr, ptr %object_node, align 8
  %189 = call ptr @get_expr_type__Struct_ASTNode(ptr %188)
  store ptr %189, ptr %object_type, align 8
  %190 = load ptr, ptr %object_type, align 8
  %191 = call i1 @is_struct_type_key__String(ptr %190)
  br i1 %191, label %label_1298, label %label_1300

label_1292:                                       ; preds = %label_1289
  %192 = load ptr, ptr %object_node, align 8
  %193 = getelementptr inbounds nuw %ASTNode, ptr %192, i32 0, i32 1
  %194 = load ptr, ptr %193, align 8
  %195 = load ptr, ptr %expr, align 8
  %196 = getelementptr inbounds nuw %ASTNode, ptr %195, i32 0, i32 1
  %197 = load ptr, ptr %196, align 8
  %198 = call i32 @ir_get_enum_variant(ptr %194, ptr %197)
  store i32 %198, ptr %enum_val, align 4
  %199 = load i32, ptr %enum_val, align 4
  %200 = icmp sge i32 %199, 0
  br i1 %200, label %label_1295, label %label_1297

label_1297:                                       ; preds = %label_1292
  br label %label_1294

label_1295:                                       ; preds = %label_1292
  ret ptr @.str.s524

label_1300:                                       ; preds = %label_1294
  ret ptr @.str.s525

label_1298:                                       ; preds = %label_1294
  %201 = load ptr, ptr %object_type, align 8
  %202 = call ptr @struct_type_name__String(ptr %201)
  %203 = load ptr, ptr %expr, align 8
  %204 = getelementptr inbounds nuw %ASTNode, ptr %203, i32 0, i32 1
  %205 = load ptr, ptr %204, align 8
  %206 = call ptr @ir_get_struct_field_type(ptr %202, ptr %205)
  ret ptr %206

label_1303:                                       ; preds = %label_1291
  %207 = load ptr, ptr %expr, align 8
  %208 = getelementptr inbounds nuw %ASTNode, ptr %207, i32 0, i32 0
  %209 = load i32, ptr %208, align 4
  %210 = icmp eq i32 %209, 28
  br i1 %210, label %label_1304, label %label_1306

label_1301:                                       ; preds = %label_1291
  ret ptr @.str.s526

label_1306:                                       ; preds = %label_1303
  ret ptr @.str.s527

label_1304:                                       ; preds = %label_1303
  %211 = load ptr, ptr %expr, align 8
  %212 = getelementptr inbounds nuw %ASTNode, ptr %211, i32 0, i32 1
  %213 = load ptr, ptr %212, align 8
  %214 = call ptr @struct_type_key__String(ptr %213)
  ret ptr %214
}

define ptr @generate_short_circuit__Struct_ASTNode(ptr %0) {
entry:
  %expr = alloca ptr, align 8
  store ptr %0, ptr %expr, align 8
  %is_and = alloca i1, align 1
  %slot = alloca ptr, align 8
  %rhs_label = alloca i32, align 4
  %done_label = alloca i32, align 4
  %left_val = alloca ptr, align 8
  %right_val = alloca ptr, align 8
  %result_id = alloca i32, align 4
  %1 = load ptr, ptr %expr, align 8
  %2 = getelementptr inbounds nuw %ASTNode, ptr %1, i32 0, i32 1
  %3 = load ptr, ptr %2, align 8
  %4 = call i32 @str_equals(ptr %3, ptr @.str.s528)
  %5 = icmp eq i32 %4, 1
  store i1 %5, ptr %is_and, align 1
  %6 = load i32, ptr @ir_short_circuit_counter, align 4
  %7 = call ptr @int_to_str(i32 %6)
  %8 = call ptr @str_concat(ptr @.str.s529, ptr %7)
  store ptr %8, ptr %slot, align 8
  %9 = load i32, ptr @ir_short_circuit_counter, align 4
  %10 = add i32 %9, 1
  store i32 %10, ptr @ir_short_circuit_counter, align 4
  %11 = load ptr, ptr %slot, align 8
  %12 = call i32 @ir_alloca(ptr @.str.s530, ptr %11)
  %13 = call i32 @ir_get_label()
  store i32 %13, ptr %rhs_label, align 4
  %14 = call i32 @ir_get_label()
  store i32 %14, ptr %done_label, align 4
  %15 = load ptr, ptr %expr, align 8
  %16 = getelementptr inbounds nuw %ASTNode, ptr %15, i32 0, i32 5
  %17 = load ptr, ptr %16, align 8
  %18 = call ptr @ptr_to_node(ptr %17)
  %19 = call ptr @generate_expression__Struct_ASTNode(ptr %18)
  store ptr %19, ptr %left_val, align 8
  %20 = load ptr, ptr %left_val, align 8
  %21 = load ptr, ptr %slot, align 8
  call void @ir_store(ptr @.str.s531, ptr %20, ptr %21)
  %22 = load i1, ptr %is_and, align 1
  br i1 %22, label %label_1307, label %label_1308

label_1308:                                       ; preds = %entry
  %23 = load ptr, ptr %left_val, align 8
  %24 = load i32, ptr %done_label, align 4
  %25 = load i32, ptr %rhs_label, align 4
  call void @ir_cond_br_numbered(ptr %23, i32 %24, i32 %25)
  br label %label_1309

label_1307:                                       ; preds = %entry
  %26 = load ptr, ptr %left_val, align 8
  %27 = load i32, ptr %rhs_label, align 4
  %28 = load i32, ptr %done_label, align 4
  call void @ir_cond_br_numbered(ptr %26, i32 %27, i32 %28)
  br label %label_1309

label_1309:                                       ; preds = %label_1308, %label_1307
  %29 = load i32, ptr %rhs_label, align 4
  call void @ir_label_numbered(i32 %29)
  %30 = load ptr, ptr %expr, align 8
  %31 = getelementptr inbounds nuw %ASTNode, ptr %30, i32 0, i32 6
  %32 = load ptr, ptr %31, align 8
  %33 = call ptr @ptr_to_node(ptr %32)
  %34 = call ptr @generate_expression__Struct_ASTNode(ptr %33)
  store ptr %34, ptr %right_val, align 8
  %35 = load ptr, ptr %right_val, align 8
  %36 = load ptr, ptr %slot, align 8
  call void @ir_store(ptr @.str.s532, ptr %35, ptr %36)
  %37 = load i32, ptr %done_label, align 4
  call void @ir_br_numbered(i32 %37)
  %38 = load i32, ptr %done_label, align 4
  call void @ir_label_numbered(i32 %38)
  %39 = load ptr, ptr %slot, align 8
  %40 = call i32 @ir_load(ptr @.str.s533, ptr %39)
  store i32 %40, ptr %result_id, align 4
  %41 = load i32, ptr %result_id, align 4
  %42 = call ptr @ir_get_temp_name(i32 %41)
  ret ptr %42
}

define ptr @generate_expression__Struct_ASTNode(ptr %0) {
entry:
  %expr = alloca ptr, align 8
  store ptr %0, ptr %expr, align 8
  %struct_name = alloca ptr, align 8
  %mem_name = alloca ptr, align 8
  %field_ptr = alloca ptr, align 8
  %field = alloca ptr, align 8
  %field_val = alloca ptr, align 8
  %field_type = alloca ptr, align 8
  %field_index = alloca i32, align 4
  %slot = alloca i32, align 4
  %val_type = alloca ptr, align 8
  %load_type = alloca ptr, align 8
  %temp_id = alloca i32, align 4
  %object_node = alloca ptr, align 8
  %enum_val = alloca i32, align 4
  %object_val = alloca ptr, align 8
  %object_type = alloca ptr, align 8
  %elem_count = alloca i32, align 4
  %first_elem = alloca ptr, align 8
  %elem_type = alloca ptr, align 8
  %base = alloca ptr, align 8
  %elem_ptr = alloca ptr, align 8
  %elem_index = alloca i32, align 4
  %elem_node = alloca ptr, align 8
  %elem_val = alloca ptr, align 8
  %array_val = alloca ptr, align 8
  %index_val = alloca ptr, align 8
  %obj_type = alloca ptr, align 8
  %source = alloca ptr, align 8
  %val = alloca ptr, align 8
  %from_t = alloca ptr, align 8
  %to_t = alloca ptr, align 8
  %from_key = alloca ptr, align 8
  %to_key = alloca ptr, align 8
  %zero_extend = alloca i1, align 1
  %operand_node = alloca ptr, align 8
  %operand_val = alloca ptr, align 8
  %uop = alloca ptr, align 8
  %not_id = alloca i32, align 4
  %int_type = alloca ptr, align 8
  %operand_type = alloca ptr, align 8
  %fneg_id = alloca i32, align 4
  %neg_id = alloca i32, align 4
  %left_val = alloca ptr, align 8
  %right_val = alloca ptr, align 8
  %op = alloca ptr, align 8
  %left_node = alloca ptr, align 8
  %op_type = alloca ptr, align 8
  %is_unsigned = alloca i1, align 1
  %callee = alloca ptr, align 8
  %func_name = alloca ptr, align 8
  %drop_arg = alloca ptr, align 8
  %drop_val = alloca ptr, align 8
  %is_print_bool = alloca i32, align 4
  %bool_arg_ptr = alloca ptr, align 8
  %bool_arg = alloca ptr, align 8
  %bool_val = alloca ptr, align 8
  %widened = alloca i32, align 4
  %is_print = alloca i32, align 4
  %arg_ptr = alloca ptr, align 8
  %arg_node = alloca ptr, align 8
  %arg_val = alloca ptr, align 8
  %arg_type = alloca ptr, align 8
  %call_name = alloca ptr, align 8
  %ret_type = alloca ptr, align 8
  %1 = load ptr, ptr %expr, align 8
  %2 = getelementptr inbounds nuw %ASTNode, ptr %1, i32 0, i32 0
  %3 = load i32, ptr %2, align 4
  %4 = icmp eq i32 %3, 22
  br i1 %4, label %label_1310, label %label_1312

label_1312:                                       ; preds = %label_1330, %entry
  %5 = load ptr, ptr %expr, align 8
  %6 = getelementptr inbounds nuw %ASTNode, ptr %5, i32 0, i32 0
  %7 = load i32, ptr %6, align 4
  %8 = icmp eq i32 %7, 28
  br i1 %8, label %label_1331, label %label_1333

label_1310:                                       ; preds = %entry
  %9 = load ptr, ptr %expr, align 8
  %10 = getelementptr inbounds nuw %ASTNode, ptr %9, i32 0, i32 3
  %11 = load i32, ptr %10, align 4
  %12 = icmp eq i32 %11, 2
  br i1 %12, label %label_1313, label %label_1315

label_1315:                                       ; preds = %label_1310
  %13 = load ptr, ptr %expr, align 8
  %14 = getelementptr inbounds nuw %ASTNode, ptr %13, i32 0, i32 3
  %15 = load i32, ptr %14, align 4
  %16 = icmp eq i32 %15, 3
  br i1 %16, label %label_1316, label %label_1318

label_1313:                                       ; preds = %label_1310
  %17 = load ptr, ptr %expr, align 8
  %18 = getelementptr inbounds nuw %ASTNode, ptr %17, i32 0, i32 1
  %19 = load ptr, ptr %18, align 8
  ret ptr %19

label_1318:                                       ; preds = %label_1315
  %20 = load ptr, ptr %expr, align 8
  %21 = getelementptr inbounds nuw %ASTNode, ptr %20, i32 0, i32 3
  %22 = load i32, ptr %21, align 4
  %23 = icmp eq i32 %22, 4
  br i1 %23, label %label_1319, label %label_1321

label_1316:                                       ; preds = %label_1315
  %24 = load ptr, ptr %expr, align 8
  %25 = getelementptr inbounds nuw %ASTNode, ptr %24, i32 0, i32 1
  %26 = load ptr, ptr %25, align 8
  ret ptr %26

label_1321:                                       ; preds = %label_1318
  %27 = load ptr, ptr %expr, align 8
  %28 = getelementptr inbounds nuw %ASTNode, ptr %27, i32 0, i32 3
  %29 = load i32, ptr %28, align 4
  %30 = icmp eq i32 %29, 1
  br i1 %30, label %label_1325, label %label_1327

label_1319:                                       ; preds = %label_1318
  %31 = load ptr, ptr %expr, align 8
  %32 = getelementptr inbounds nuw %ASTNode, ptr %31, i32 0, i32 1
  %33 = load ptr, ptr %32, align 8
  %34 = call i32 @str_equals(ptr %33, ptr @.str.s534)
  %35 = icmp eq i32 %34, 1
  br i1 %35, label %label_1322, label %label_1324

label_1324:                                       ; preds = %label_1319
  ret ptr @.str.s536

label_1322:                                       ; preds = %label_1319
  ret ptr @.str.s535

label_1327:                                       ; preds = %label_1321
  %36 = load ptr, ptr %expr, align 8
  %37 = getelementptr inbounds nuw %ASTNode, ptr %36, i32 0, i32 3
  %38 = load i32, ptr %37, align 4
  %39 = icmp eq i32 %38, 0
  br i1 %39, label %label_1328, label %label_1330

label_1325:                                       ; preds = %label_1321
  %40 = load ptr, ptr %expr, align 8
  %41 = getelementptr inbounds nuw %ASTNode, ptr %40, i32 0, i32 1
  %42 = load ptr, ptr %41, align 8
  ret ptr %42

label_1330:                                       ; preds = %label_1327
  br label %label_1312

label_1328:                                       ; preds = %label_1327
  %43 = load ptr, ptr %expr, align 8
  %44 = getelementptr inbounds nuw %ASTNode, ptr %43, i32 0, i32 2
  %45 = load ptr, ptr %44, align 8
  %46 = call i32 @ir_string_ptr(ptr %45)
  %47 = call ptr @ir_get_temp_name(i32 %46)
  ret ptr %47

label_1333:                                       ; preds = %label_1312
  %48 = load ptr, ptr %expr, align 8
  %49 = getelementptr inbounds nuw %ASTNode, ptr %48, i32 0, i32 0
  %50 = load i32, ptr %49, align 4
  %51 = icmp eq i32 %50, 23
  br i1 %51, label %label_1337, label %label_1339

label_1331:                                       ; preds = %label_1312
  %52 = load ptr, ptr %expr, align 8
  %53 = getelementptr inbounds nuw %ASTNode, ptr %52, i32 0, i32 1
  %54 = load ptr, ptr %53, align 8
  store ptr %54, ptr %struct_name, align 8
  %55 = load ptr, ptr %struct_name, align 8
  %56 = call i32 @ir_alloc_object(ptr %55)
  %57 = call ptr @ir_get_temp_name(i32 %56)
  store ptr %57, ptr %mem_name, align 8
  %58 = load ptr, ptr %expr, align 8
  %59 = getelementptr inbounds nuw %ASTNode, ptr %58, i32 0, i32 5
  %60 = load ptr, ptr %59, align 8
  store ptr %60, ptr %field_ptr, align 8
  br label %label_1334

label_1334:                                       ; preds = %label_1335, %label_1331
  %61 = load ptr, ptr %field_ptr, align 8
  %62 = call i32 @str_equals(ptr %61, ptr @.str.s537)
  %63 = icmp eq i32 %62, 0
  br i1 %63, label %label_1335, label %label_1336

label_1336:                                       ; preds = %label_1334
  %64 = load ptr, ptr %mem_name, align 8
  ret ptr %64

label_1335:                                       ; preds = %label_1334
  %65 = load ptr, ptr %field_ptr, align 8
  %66 = call ptr @ptr_to_node(ptr %65)
  store ptr %66, ptr %field, align 8
  %67 = load ptr, ptr %field, align 8
  %68 = getelementptr inbounds nuw %ASTNode, ptr %67, i32 0, i32 5
  %69 = load ptr, ptr %68, align 8
  %70 = call ptr @ptr_to_node(ptr %69)
  %71 = call ptr @generate_expression__Struct_ASTNode(ptr %70)
  store ptr %71, ptr %field_val, align 8
  %72 = load ptr, ptr %struct_name, align 8
  %73 = load ptr, ptr %field, align 8
  %74 = getelementptr inbounds nuw %ASTNode, ptr %73, i32 0, i32 1
  %75 = load ptr, ptr %74, align 8
  %76 = call ptr @ir_get_struct_field_type(ptr %72, ptr %75)
  %77 = call ptr @storage_type__String(ptr %76)
  store ptr %77, ptr %field_type, align 8
  %78 = load ptr, ptr %struct_name, align 8
  %79 = load ptr, ptr %field, align 8
  %80 = getelementptr inbounds nuw %ASTNode, ptr %79, i32 0, i32 1
  %81 = load ptr, ptr %80, align 8
  %82 = call i32 @ir_get_struct_field_index(ptr %78, ptr %81)
  store i32 %82, ptr %field_index, align 4
  %83 = load ptr, ptr %struct_name, align 8
  %84 = load ptr, ptr %mem_name, align 8
  %85 = load i32, ptr %field_index, align 4
  %86 = call i32 @ir_struct_field_ptr(ptr %83, ptr %84, i32 %85)
  store i32 %86, ptr %slot, align 4
  %87 = load ptr, ptr %field_type, align 8
  %88 = load ptr, ptr %field_val, align 8
  %89 = load i32, ptr %slot, align 4
  %90 = call ptr @ir_get_temp_name(i32 %89)
  call void @ir_store_ptr(ptr %87, ptr %88, ptr %90)
  %91 = load ptr, ptr %field, align 8
  %92 = getelementptr inbounds nuw %ASTNode, ptr %91, i32 0, i32 8
  %93 = load ptr, ptr %92, align 8
  store ptr %93, ptr %field_ptr, align 8
  br label %label_1334

label_1339:                                       ; preds = %label_1342, %label_1333
  %94 = load ptr, ptr %expr, align 8
  %95 = getelementptr inbounds nuw %ASTNode, ptr %94, i32 0, i32 0
  %96 = load i32, ptr %95, align 4
  %97 = icmp eq i32 %96, 25
  br i1 %97, label %label_1343, label %label_1345

label_1337:                                       ; preds = %label_1333
  %98 = load ptr, ptr %expr, align 8
  %99 = getelementptr inbounds nuw %ASTNode, ptr %98, i32 0, i32 1
  %100 = load ptr, ptr %99, align 8
  %101 = call ptr @ir_get_var_type(ptr %100)
  store ptr %101, ptr %val_type, align 8
  %102 = load ptr, ptr %val_type, align 8
  %103 = call ptr @storage_type__String(ptr %102)
  store ptr %103, ptr %load_type, align 8
  %104 = load ptr, ptr %expr, align 8
  %105 = getelementptr inbounds nuw %ASTNode, ptr %104, i32 0, i32 1
  %106 = load ptr, ptr %105, align 8
  %107 = call i32 @ir_is_global_name(ptr %106)
  %108 = icmp eq i32 %107, 1
  br i1 %108, label %label_1340, label %label_1341

label_1341:                                       ; preds = %label_1337
  %109 = load ptr, ptr %load_type, align 8
  %110 = load ptr, ptr %expr, align 8
  %111 = getelementptr inbounds nuw %ASTNode, ptr %110, i32 0, i32 1
  %112 = load ptr, ptr %111, align 8
  %113 = call i32 @ir_load(ptr %109, ptr %112)
  store i32 %113, ptr %temp_id, align 4
  %114 = load i32, ptr %temp_id, align 4
  %115 = call ptr @ir_get_temp_name(i32 %114)
  ret ptr %115

label_1340:                                       ; preds = %label_1337
  %116 = load ptr, ptr %load_type, align 8
  %117 = load ptr, ptr %expr, align 8
  %118 = getelementptr inbounds nuw %ASTNode, ptr %117, i32 0, i32 1
  %119 = load ptr, ptr %118, align 8
  %120 = call i32 @ir_load_global(ptr %116, ptr %119)
  store i32 %120, ptr %temp_id, align 4
  %121 = load i32, ptr %temp_id, align 4
  %122 = call ptr @ir_get_temp_name(i32 %121)
  ret ptr %122

label_1342:                                       ; No predecessors!
  br label %label_1339

label_1345:                                       ; preds = %label_1339
  %123 = load ptr, ptr %expr, align 8
  %124 = getelementptr inbounds nuw %ASTNode, ptr %123, i32 0, i32 0
  %125 = load i32, ptr %124, align 4
  %126 = icmp eq i32 %125, 27
  br i1 %126, label %label_1352, label %label_1354

label_1343:                                       ; preds = %label_1339
  %127 = load ptr, ptr %expr, align 8
  %128 = getelementptr inbounds nuw %ASTNode, ptr %127, i32 0, i32 5
  %129 = load ptr, ptr %128, align 8
  %130 = call ptr @ptr_to_node(ptr %129)
  store ptr %130, ptr %object_node, align 8
  %131 = load ptr, ptr %object_node, align 8
  %132 = getelementptr inbounds nuw %ASTNode, ptr %131, i32 0, i32 0
  %133 = load i32, ptr %132, align 4
  %134 = icmp eq i32 %133, 23
  br i1 %134, label %label_1346, label %label_1348

label_1348:                                       ; preds = %label_1351, %label_1343
  %135 = load ptr, ptr %object_node, align 8
  %136 = call ptr @generate_expression__Struct_ASTNode(ptr %135)
  store ptr %136, ptr %object_val, align 8
  %137 = load ptr, ptr %object_node, align 8
  %138 = call ptr @get_expr_type__Struct_ASTNode(ptr %137)
  store ptr %138, ptr %object_type, align 8
  %139 = load ptr, ptr %object_type, align 8
  %140 = call ptr @struct_type_name__String(ptr %139)
  store ptr %140, ptr %struct_name, align 8
  %141 = load ptr, ptr %struct_name, align 8
  %142 = load ptr, ptr %expr, align 8
  %143 = getelementptr inbounds nuw %ASTNode, ptr %142, i32 0, i32 1
  %144 = load ptr, ptr %143, align 8
  %145 = call i32 @ir_get_struct_field_index(ptr %141, ptr %144)
  store i32 %145, ptr %field_index, align 4
  %146 = load ptr, ptr %struct_name, align 8
  %147 = load ptr, ptr %expr, align 8
  %148 = getelementptr inbounds nuw %ASTNode, ptr %147, i32 0, i32 1
  %149 = load ptr, ptr %148, align 8
  %150 = call ptr @ir_get_struct_field_type(ptr %146, ptr %149)
  %151 = call ptr @storage_type__String(ptr %150)
  store ptr %151, ptr %field_type, align 8
  %152 = load ptr, ptr %struct_name, align 8
  %153 = load ptr, ptr %object_val, align 8
  %154 = load i32, ptr %field_index, align 4
  %155 = call i32 @ir_struct_field_ptr(ptr %152, ptr %153, i32 %154)
  store i32 %155, ptr %slot, align 4
  %156 = load ptr, ptr %field_type, align 8
  %157 = load i32, ptr %slot, align 4
  %158 = call ptr @ir_get_temp_name(i32 %157)
  %159 = call i32 @ir_load_ptr(ptr %156, ptr %158)
  %160 = call ptr @ir_get_temp_name(i32 %159)
  ret ptr %160

label_1346:                                       ; preds = %label_1343
  %161 = load ptr, ptr %object_node, align 8
  %162 = getelementptr inbounds nuw %ASTNode, ptr %161, i32 0, i32 1
  %163 = load ptr, ptr %162, align 8
  %164 = load ptr, ptr %expr, align 8
  %165 = getelementptr inbounds nuw %ASTNode, ptr %164, i32 0, i32 1
  %166 = load ptr, ptr %165, align 8
  %167 = call i32 @ir_get_enum_variant(ptr %163, ptr %166)
  store i32 %167, ptr %enum_val, align 4
  %168 = load i32, ptr %enum_val, align 4
  %169 = icmp sge i32 %168, 0
  br i1 %169, label %label_1349, label %label_1351

label_1351:                                       ; preds = %label_1346
  br label %label_1348

label_1349:                                       ; preds = %label_1346
  %170 = load i32, ptr %enum_val, align 4
  %171 = call ptr @int_to_str(i32 %170)
  ret ptr %171

label_1354:                                       ; preds = %label_1345
  %172 = load ptr, ptr %expr, align 8
  %173 = getelementptr inbounds nuw %ASTNode, ptr %172, i32 0, i32 0
  %174 = load i32, ptr %173, align 4
  %175 = icmp eq i32 %174, 26
  br i1 %175, label %label_1361, label %label_1363

label_1352:                                       ; preds = %label_1345
  %176 = load ptr, ptr %expr, align 8
  %177 = getelementptr inbounds nuw %ASTNode, ptr %176, i32 0, i32 5
  %178 = load ptr, ptr %177, align 8
  %179 = call i32 @count_list_nodes__String(ptr %178)
  store i32 %179, ptr %elem_count, align 4
  %180 = load ptr, ptr %expr, align 8
  %181 = getelementptr inbounds nuw %ASTNode, ptr %180, i32 0, i32 5
  %182 = load ptr, ptr %181, align 8
  %183 = call ptr @ptr_to_node(ptr %182)
  store ptr %183, ptr %first_elem, align 8
  store ptr @.str.s538, ptr %elem_type, align 8
  %184 = load ptr, ptr %first_elem, align 8
  %185 = getelementptr inbounds nuw %ASTNode, ptr %184, i32 0, i32 0
  %186 = load i32, ptr %185, align 4
  %187 = icmp eq i32 %186, 27
  br i1 %187, label %label_1355, label %label_1357

label_1357:                                       ; preds = %label_1355, %label_1352
  %188 = load ptr, ptr %elem_type, align 8
  %189 = load i32, ptr %elem_count, align 4
  %190 = call i32 @ir_array_alloca(ptr %188, i32 %189)
  %191 = call ptr @ir_get_temp_name(i32 %190)
  store ptr %191, ptr %base, align 8
  %192 = load ptr, ptr %expr, align 8
  %193 = getelementptr inbounds nuw %ASTNode, ptr %192, i32 0, i32 5
  %194 = load ptr, ptr %193, align 8
  store ptr %194, ptr %elem_ptr, align 8
  store i32 0, ptr %elem_index, align 4
  br label %label_1358

label_1355:                                       ; preds = %label_1352
  store ptr @.str.s539, ptr %elem_type, align 8
  br label %label_1357

label_1358:                                       ; preds = %label_1359, %label_1357
  %195 = load ptr, ptr %elem_ptr, align 8
  %196 = call i32 @str_equals(ptr %195, ptr @.str.s540)
  %197 = icmp eq i32 %196, 0
  br i1 %197, label %label_1359, label %label_1360

label_1360:                                       ; preds = %label_1358
  %198 = load ptr, ptr %base, align 8
  ret ptr %198

label_1359:                                       ; preds = %label_1358
  %199 = load ptr, ptr %elem_ptr, align 8
  %200 = call ptr @ptr_to_node(ptr %199)
  store ptr %200, ptr %elem_node, align 8
  %201 = load ptr, ptr %elem_node, align 8
  %202 = call ptr @generate_expression__Struct_ASTNode(ptr %201)
  store ptr %202, ptr %elem_val, align 8
  %203 = load ptr, ptr %elem_type, align 8
  %204 = load ptr, ptr %base, align 8
  %205 = load i32, ptr %elem_index, align 4
  %206 = call ptr @int_to_str(i32 %205)
  %207 = call i32 @ir_elem_ptr(ptr %203, ptr %204, ptr %206)
  store i32 %207, ptr %slot, align 4
  %208 = load ptr, ptr %elem_type, align 8
  %209 = load ptr, ptr %elem_val, align 8
  %210 = load i32, ptr %slot, align 4
  %211 = call ptr @ir_get_temp_name(i32 %210)
  call void @ir_store_ptr(ptr %208, ptr %209, ptr %211)
  %212 = load i32, ptr %elem_index, align 4
  %213 = add i32 %212, 1
  store i32 %213, ptr %elem_index, align 4
  %214 = load ptr, ptr %elem_node, align 8
  %215 = getelementptr inbounds nuw %ASTNode, ptr %214, i32 0, i32 8
  %216 = load ptr, ptr %215, align 8
  store ptr %216, ptr %elem_ptr, align 8
  br label %label_1358

label_1363:                                       ; preds = %label_1354
  %217 = load ptr, ptr %expr, align 8
  %218 = getelementptr inbounds nuw %ASTNode, ptr %217, i32 0, i32 0
  %219 = load i32, ptr %218, align 4
  %220 = icmp eq i32 %219, 29
  br i1 %220, label %label_1367, label %label_1369

label_1361:                                       ; preds = %label_1354
  %221 = load ptr, ptr %expr, align 8
  %222 = getelementptr inbounds nuw %ASTNode, ptr %221, i32 0, i32 5
  %223 = load ptr, ptr %222, align 8
  %224 = call ptr @ptr_to_node(ptr %223)
  %225 = call ptr @generate_expression__Struct_ASTNode(ptr %224)
  store ptr %225, ptr %array_val, align 8
  %226 = load ptr, ptr %expr, align 8
  %227 = getelementptr inbounds nuw %ASTNode, ptr %226, i32 0, i32 6
  %228 = load ptr, ptr %227, align 8
  %229 = call ptr @ptr_to_node(ptr %228)
  %230 = call ptr @generate_expression__Struct_ASTNode(ptr %229)
  store ptr %230, ptr %index_val, align 8
  %231 = load ptr, ptr %expr, align 8
  %232 = getelementptr inbounds nuw %ASTNode, ptr %231, i32 0, i32 5
  %233 = load ptr, ptr %232, align 8
  %234 = call ptr @ptr_to_node(ptr %233)
  %235 = call ptr @get_expr_type__Struct_ASTNode(ptr %234)
  store ptr %235, ptr %obj_type, align 8
  store ptr @.str.s541, ptr %elem_type, align 8
  %236 = load ptr, ptr %obj_type, align 8
  %237 = call i32 @str_equals(ptr %236, ptr @.str.s542)
  %238 = icmp eq i32 %237, 1
  br i1 %238, label %label_1364, label %label_1366

label_1366:                                       ; preds = %label_1364, %label_1361
  %239 = load ptr, ptr %elem_type, align 8
  %240 = load ptr, ptr %array_val, align 8
  %241 = load ptr, ptr %index_val, align 8
  %242 = call i32 @ir_elem_ptr(ptr %239, ptr %240, ptr %241)
  store i32 %242, ptr %slot, align 4
  %243 = load ptr, ptr %elem_type, align 8
  %244 = load i32, ptr %slot, align 4
  %245 = call ptr @ir_get_temp_name(i32 %244)
  %246 = call i32 @ir_load_ptr(ptr %243, ptr %245)
  %247 = call ptr @ir_get_temp_name(i32 %246)
  ret ptr %247

label_1364:                                       ; preds = %label_1361
  store ptr @.str.s543, ptr %elem_type, align 8
  br label %label_1366

label_1369:                                       ; preds = %label_1363
  %248 = load ptr, ptr %expr, align 8
  %249 = getelementptr inbounds nuw %ASTNode, ptr %248, i32 0, i32 0
  %250 = load i32, ptr %249, align 4
  %251 = icmp eq i32 %250, 21
  br i1 %251, label %label_1395, label %label_1397

label_1367:                                       ; preds = %label_1363
  %252 = load ptr, ptr %expr, align 8
  %253 = getelementptr inbounds nuw %ASTNode, ptr %252, i32 0, i32 5
  %254 = load ptr, ptr %253, align 8
  %255 = call ptr @ptr_to_node(ptr %254)
  store ptr %255, ptr %source, align 8
  %256 = load ptr, ptr %source, align 8
  %257 = call ptr @generate_expression__Struct_ASTNode(ptr %256)
  store ptr %257, ptr %val, align 8
  %258 = load ptr, ptr %source, align 8
  %259 = call ptr @node_get_type__Struct_ASTNode(ptr %258)
  store ptr %259, ptr %from_t, align 8
  %260 = load ptr, ptr %expr, align 8
  %261 = call ptr @node_get_type__Struct_ASTNode(ptr %260)
  store ptr %261, ptr %to_t, align 8
  %262 = load ptr, ptr %from_t, align 8
  %263 = call ptr @type_ir_key__Struct_TypeInfo(ptr %262)
  store ptr %263, ptr %from_key, align 8
  %264 = load ptr, ptr %to_t, align 8
  %265 = call ptr @type_ir_key__Struct_TypeInfo(ptr %264)
  store ptr %265, ptr %to_key, align 8
  %266 = load ptr, ptr %from_key, align 8
  %267 = load ptr, ptr %to_key, align 8
  %268 = call i32 @str_equals(ptr %266, ptr %267)
  %269 = icmp eq i32 %268, 1
  br i1 %269, label %label_1370, label %label_1372

label_1372:                                       ; preds = %label_1367
  %270 = load ptr, ptr %to_key, align 8
  %271 = call i32 @str_equals(ptr %270, ptr @.str.s544)
  %272 = icmp eq i32 %271, 1
  br i1 %272, label %label_1373, label %label_1375

label_1370:                                       ; preds = %label_1367
  %273 = load ptr, ptr %val, align 8
  ret ptr %273

label_1375:                                       ; preds = %label_1372
  %274 = load ptr, ptr %from_key, align 8
  %275 = call i32 @str_equals(ptr %274, ptr @.str.s545)
  %276 = icmp eq i32 %275, 1
  br i1 %276, label %label_1379, label %label_1381

label_1373:                                       ; preds = %label_1372
  %277 = load ptr, ptr %from_t, align 8
  %278 = call i1 @type_int_is_unsigned__Struct_TypeInfo(ptr %277)
  br i1 %278, label %label_1376, label %label_1378

label_1378:                                       ; preds = %label_1373
  %279 = load ptr, ptr %from_key, align 8
  %280 = load ptr, ptr %val, align 8
  %281 = load ptr, ptr %to_key, align 8
  %282 = call i32 @ir_sitofp(ptr %279, ptr %280, ptr %281)
  %283 = call ptr @ir_get_temp_name(i32 %282)
  ret ptr %283

label_1376:                                       ; preds = %label_1373
  %284 = load ptr, ptr %from_key, align 8
  %285 = load ptr, ptr %val, align 8
  %286 = load ptr, ptr %to_key, align 8
  %287 = call i32 @ir_uitofp(ptr %284, ptr %285, ptr %286)
  %288 = call ptr @ir_get_temp_name(i32 %287)
  ret ptr %288

label_1381:                                       ; preds = %label_1375
  %289 = load ptr, ptr %from_t, align 8
  %290 = call i32 @type_int_bits__Struct_TypeInfo(ptr %289)
  %291 = load ptr, ptr %to_t, align 8
  %292 = call i32 @type_int_bits__Struct_TypeInfo(ptr %291)
  %293 = icmp sgt i32 %290, %292
  br i1 %293, label %label_1385, label %label_1387

label_1379:                                       ; preds = %label_1375
  %294 = load ptr, ptr %to_t, align 8
  %295 = call i1 @type_int_is_unsigned__Struct_TypeInfo(ptr %294)
  br i1 %295, label %label_1382, label %label_1384

label_1384:                                       ; preds = %label_1379
  %296 = load ptr, ptr %from_key, align 8
  %297 = load ptr, ptr %val, align 8
  %298 = load ptr, ptr %to_key, align 8
  %299 = call i32 @ir_fptosi(ptr %296, ptr %297, ptr %298)
  %300 = call ptr @ir_get_temp_name(i32 %299)
  ret ptr %300

label_1382:                                       ; preds = %label_1379
  %301 = load ptr, ptr %from_key, align 8
  %302 = load ptr, ptr %val, align 8
  %303 = load ptr, ptr %to_key, align 8
  %304 = call i32 @ir_fptoui(ptr %301, ptr %302, ptr %303)
  %305 = call ptr @ir_get_temp_name(i32 %304)
  ret ptr %305

label_1387:                                       ; preds = %label_1381
  %sc.85 = alloca i1, align 1
  %sc.86 = alloca i1, align 1
  %306 = load ptr, ptr %from_t, align 8
  %307 = call i1 @type_int_is_unsigned__Struct_TypeInfo(ptr %306)
  store i1 %307, ptr %sc.86, align 1
  br i1 %307, label %label_1391, label %label_1390

label_1385:                                       ; preds = %label_1381
  %308 = load ptr, ptr %from_key, align 8
  %309 = load ptr, ptr %val, align 8
  %310 = load ptr, ptr %to_key, align 8
  %311 = call i32 @ir_trunc(ptr %308, ptr %309, ptr %310)
  %312 = call ptr @ir_get_temp_name(i32 %311)
  ret ptr %312

label_1390:                                       ; preds = %label_1387
  %313 = load ptr, ptr %from_t, align 8
  %314 = getelementptr inbounds nuw %TypeInfo, ptr %313, i32 0, i32 0
  %315 = load i32, ptr %314, align 4
  %316 = icmp eq i32 %315, 5
  store i1 %316, ptr %sc.86, align 1
  br label %label_1391

label_1391:                                       ; preds = %label_1390, %label_1387
  %317 = load i1, ptr %sc.86, align 1
  store i1 %317, ptr %sc.85, align 1
  br i1 %317, label %label_1389, label %label_1388

label_1388:                                       ; preds = %label_1391
  %318 = load ptr, ptr %from_t, align 8
  %319 = getelementptr inbounds nuw %TypeInfo, ptr %318, i32 0, i32 0
  %320 = load i32, ptr %319, align 4
  %321 = icmp eq i32 %320, 4
  store i1 %321, ptr %sc.85, align 1
  br label %label_1389

label_1389:                                       ; preds = %label_1388, %label_1391
  %322 = load i1, ptr %sc.85, align 1
  store i1 %322, ptr %zero_extend, align 1
  %323 = load i1, ptr %zero_extend, align 1
  br i1 %323, label %label_1392, label %label_1394

label_1394:                                       ; preds = %label_1389
  %324 = load ptr, ptr %from_key, align 8
  %325 = load ptr, ptr %val, align 8
  %326 = load ptr, ptr %to_key, align 8
  %327 = call i32 @ir_sext(ptr %324, ptr %325, ptr %326)
  %328 = call ptr @ir_get_temp_name(i32 %327)
  ret ptr %328

label_1392:                                       ; preds = %label_1389
  %329 = load ptr, ptr %from_key, align 8
  %330 = load ptr, ptr %val, align 8
  %331 = load ptr, ptr %to_key, align 8
  %332 = call i32 @ir_zext(ptr %329, ptr %330, ptr %331)
  %333 = call ptr @ir_get_temp_name(i32 %332)
  ret ptr %333

label_1397:                                       ; preds = %label_1406, %label_1369
  %334 = load ptr, ptr %expr, align 8
  %335 = getelementptr inbounds nuw %ASTNode, ptr %334, i32 0, i32 0
  %336 = load i32, ptr %335, align 4
  %337 = icmp eq i32 %336, 20
  br i1 %337, label %label_1410, label %label_1412

label_1395:                                       ; preds = %label_1369
  %338 = load ptr, ptr %expr, align 8
  %339 = getelementptr inbounds nuw %ASTNode, ptr %338, i32 0, i32 5
  %340 = load ptr, ptr %339, align 8
  %341 = call ptr @ptr_to_node(ptr %340)
  store ptr %341, ptr %operand_node, align 8
  %342 = load ptr, ptr %operand_node, align 8
  %343 = call ptr @generate_expression__Struct_ASTNode(ptr %342)
  store ptr %343, ptr %operand_val, align 8
  %344 = load ptr, ptr %expr, align 8
  %345 = getelementptr inbounds nuw %ASTNode, ptr %344, i32 0, i32 1
  %346 = load ptr, ptr %345, align 8
  store ptr %346, ptr %uop, align 8
  %347 = load ptr, ptr %uop, align 8
  %348 = call i32 @str_equals(ptr %347, ptr @.str.s546)
  %349 = icmp eq i32 %348, 1
  br i1 %349, label %label_1398, label %label_1400

label_1400:                                       ; preds = %label_1395
  %350 = load ptr, ptr %uop, align 8
  %351 = call i32 @str_equals(ptr %350, ptr @.str.s549)
  %352 = icmp eq i32 %351, 1
  br i1 %352, label %label_1401, label %label_1403

label_1398:                                       ; preds = %label_1395
  %353 = load ptr, ptr %operand_val, align 8
  %354 = call i32 @ir_icmp_eq(ptr @.str.s547, ptr %353, ptr @.str.s548)
  store i32 %354, ptr %not_id, align 4
  %355 = load i32, ptr %not_id, align 4
  %356 = call ptr @ir_get_temp_name(i32 %355)
  ret ptr %356

label_1403:                                       ; preds = %label_1400
  %357 = load ptr, ptr %uop, align 8
  %358 = call i32 @str_equals(ptr %357, ptr @.str.s550)
  %359 = icmp eq i32 %358, 1
  br i1 %359, label %label_1404, label %label_1406

label_1401:                                       ; preds = %label_1400
  %360 = load ptr, ptr %operand_node, align 8
  %361 = call ptr @get_expr_type__Struct_ASTNode(ptr %360)
  store ptr %361, ptr %int_type, align 8
  %362 = load ptr, ptr %int_type, align 8
  %363 = load ptr, ptr %operand_val, align 8
  %364 = call i32 @ir_not(ptr %362, ptr %363)
  %365 = call ptr @ir_get_temp_name(i32 %364)
  ret ptr %365

label_1406:                                       ; preds = %label_1403
  br label %label_1397

label_1404:                                       ; preds = %label_1403
  %366 = load ptr, ptr %operand_node, align 8
  %367 = call ptr @get_expr_type__Struct_ASTNode(ptr %366)
  store ptr %367, ptr %operand_type, align 8
  %368 = load ptr, ptr %operand_type, align 8
  %369 = call i32 @str_equals(ptr %368, ptr @.str.s551)
  %370 = icmp eq i32 %369, 1
  br i1 %370, label %label_1407, label %label_1409

label_1409:                                       ; preds = %label_1404
  %371 = load ptr, ptr %operand_type, align 8
  %372 = load ptr, ptr %operand_val, align 8
  %373 = call i32 @ir_neg(ptr %371, ptr %372)
  store i32 %373, ptr %neg_id, align 4
  %374 = load i32, ptr %neg_id, align 4
  %375 = call ptr @ir_get_temp_name(i32 %374)
  ret ptr %375

label_1407:                                       ; preds = %label_1404
  %376 = load ptr, ptr %operand_val, align 8
  %377 = call i32 @ir_fsub(ptr @.str.s552, ptr @.str.s553, ptr %376)
  store i32 %377, ptr %fneg_id, align 4
  %378 = load i32, ptr %fneg_id, align 4
  %379 = call ptr @ir_get_temp_name(i32 %378)
  ret ptr %379

label_1412:                                       ; preds = %label_1397
  %380 = load ptr, ptr %expr, align 8
  %381 = getelementptr inbounds nuw %ASTNode, ptr %380, i32 0, i32 0
  %382 = load i32, ptr %381, align 4
  %383 = icmp eq i32 %382, 24
  br i1 %383, label %label_1526, label %label_1528

label_1410:                                       ; preds = %label_1397
  %sc.87 = alloca i1, align 1
  %384 = load ptr, ptr %expr, align 8
  %385 = getelementptr inbounds nuw %ASTNode, ptr %384, i32 0, i32 1
  %386 = load ptr, ptr %385, align 8
  %387 = call i32 @str_equals(ptr %386, ptr @.str.s554)
  %388 = icmp eq i32 %387, 1
  store i1 %388, ptr %sc.87, align 1
  br i1 %388, label %label_1414, label %label_1413

label_1413:                                       ; preds = %label_1410
  %389 = load ptr, ptr %expr, align 8
  %390 = getelementptr inbounds nuw %ASTNode, ptr %389, i32 0, i32 1
  %391 = load ptr, ptr %390, align 8
  %392 = call i32 @str_equals(ptr %391, ptr @.str.s555)
  %393 = icmp eq i32 %392, 1
  store i1 %393, ptr %sc.87, align 1
  br label %label_1414

label_1414:                                       ; preds = %label_1413, %label_1410
  %394 = load i1, ptr %sc.87, align 1
  br i1 %394, label %label_1415, label %label_1417

label_1417:                                       ; preds = %label_1414
  %395 = load ptr, ptr %expr, align 8
  %396 = getelementptr inbounds nuw %ASTNode, ptr %395, i32 0, i32 5
  %397 = load ptr, ptr %396, align 8
  %398 = call ptr @ptr_to_node(ptr %397)
  %399 = call ptr @generate_expression__Struct_ASTNode(ptr %398)
  store ptr %399, ptr %left_val, align 8
  %400 = load ptr, ptr %expr, align 8
  %401 = getelementptr inbounds nuw %ASTNode, ptr %400, i32 0, i32 6
  %402 = load ptr, ptr %401, align 8
  %403 = call ptr @ptr_to_node(ptr %402)
  %404 = call ptr @generate_expression__Struct_ASTNode(ptr %403)
  store ptr %404, ptr %right_val, align 8
  %405 = load ptr, ptr %expr, align 8
  %406 = getelementptr inbounds nuw %ASTNode, ptr %405, i32 0, i32 1
  %407 = load ptr, ptr %406, align 8
  store ptr %407, ptr %op, align 8
  store i32 0, ptr %temp_id, align 4
  %408 = load ptr, ptr %expr, align 8
  %409 = getelementptr inbounds nuw %ASTNode, ptr %408, i32 0, i32 5
  %410 = load ptr, ptr %409, align 8
  %411 = call ptr @ptr_to_node(ptr %410)
  store ptr %411, ptr %left_node, align 8
  %412 = load ptr, ptr %left_node, align 8
  %413 = call ptr @get_expr_type__Struct_ASTNode(ptr %412)
  store ptr %413, ptr %op_type, align 8
  store i1 false, ptr %is_unsigned, align 1
  %414 = load ptr, ptr %left_node, align 8
  %415 = call i1 @node_has_type__Struct_ASTNode(ptr %414)
  br i1 %415, label %label_1418, label %label_1420

label_1415:                                       ; preds = %label_1414
  %416 = load ptr, ptr %expr, align 8
  %417 = call ptr @generate_short_circuit__Struct_ASTNode(ptr %416)
  ret ptr %417

label_1420:                                       ; preds = %label_1418, %label_1417
  %418 = load ptr, ptr %op_type, align 8
  %419 = call i32 @str_equals(ptr %418, ptr @.str.s556)
  %420 = icmp eq i32 %419, 1
  br i1 %420, label %label_1421, label %label_1422

label_1418:                                       ; preds = %label_1417
  %421 = load ptr, ptr %left_node, align 8
  %422 = call ptr @node_get_type__Struct_ASTNode(ptr %421)
  %423 = call i1 @type_int_is_unsigned__Struct_TypeInfo(ptr %422)
  store i1 %423, ptr %is_unsigned, align 1
  br label %label_1420

label_1422:                                       ; preds = %label_1420
  %424 = load ptr, ptr %op, align 8
  %425 = call i32 @str_equals(ptr %424, ptr @.str.s567)
  %426 = icmp eq i32 %425, 1
  br i1 %426, label %label_1454, label %label_1456

label_1421:                                       ; preds = %label_1420
  %427 = load ptr, ptr %op, align 8
  %428 = call i32 @str_equals(ptr %427, ptr @.str.s557)
  %429 = icmp eq i32 %428, 1
  br i1 %429, label %label_1424, label %label_1426

label_1426:                                       ; preds = %label_1424, %label_1421
  %430 = load ptr, ptr %op, align 8
  %431 = call i32 @str_equals(ptr %430, ptr @.str.s558)
  %432 = icmp eq i32 %431, 1
  br i1 %432, label %label_1427, label %label_1429

label_1424:                                       ; preds = %label_1421
  %433 = load ptr, ptr %op_type, align 8
  %434 = load ptr, ptr %left_val, align 8
  %435 = load ptr, ptr %right_val, align 8
  %436 = call i32 @ir_fadd(ptr %433, ptr %434, ptr %435)
  store i32 %436, ptr %temp_id, align 4
  br label %label_1426

label_1429:                                       ; preds = %label_1427, %label_1426
  %437 = load ptr, ptr %op, align 8
  %438 = call i32 @str_equals(ptr %437, ptr @.str.s559)
  %439 = icmp eq i32 %438, 1
  br i1 %439, label %label_1430, label %label_1432

label_1427:                                       ; preds = %label_1426
  %440 = load ptr, ptr %op_type, align 8
  %441 = load ptr, ptr %left_val, align 8
  %442 = load ptr, ptr %right_val, align 8
  %443 = call i32 @ir_fsub(ptr %440, ptr %441, ptr %442)
  store i32 %443, ptr %temp_id, align 4
  br label %label_1429

label_1432:                                       ; preds = %label_1430, %label_1429
  %444 = load ptr, ptr %op, align 8
  %445 = call i32 @str_equals(ptr %444, ptr @.str.s560)
  %446 = icmp eq i32 %445, 1
  br i1 %446, label %label_1433, label %label_1435

label_1430:                                       ; preds = %label_1429
  %447 = load ptr, ptr %op_type, align 8
  %448 = load ptr, ptr %left_val, align 8
  %449 = load ptr, ptr %right_val, align 8
  %450 = call i32 @ir_fmul(ptr %447, ptr %448, ptr %449)
  store i32 %450, ptr %temp_id, align 4
  br label %label_1432

label_1435:                                       ; preds = %label_1433, %label_1432
  %451 = load ptr, ptr %op, align 8
  %452 = call i32 @str_equals(ptr %451, ptr @.str.s561)
  %453 = icmp eq i32 %452, 1
  br i1 %453, label %label_1436, label %label_1438

label_1433:                                       ; preds = %label_1432
  %454 = load ptr, ptr %op_type, align 8
  %455 = load ptr, ptr %left_val, align 8
  %456 = load ptr, ptr %right_val, align 8
  %457 = call i32 @ir_fdiv(ptr %454, ptr %455, ptr %456)
  store i32 %457, ptr %temp_id, align 4
  br label %label_1435

label_1438:                                       ; preds = %label_1436, %label_1435
  %458 = load ptr, ptr %op, align 8
  %459 = call i32 @str_equals(ptr %458, ptr @.str.s562)
  %460 = icmp eq i32 %459, 1
  br i1 %460, label %label_1439, label %label_1441

label_1436:                                       ; preds = %label_1435
  %461 = load ptr, ptr %op_type, align 8
  %462 = load ptr, ptr %left_val, align 8
  %463 = load ptr, ptr %right_val, align 8
  %464 = call i32 @ir_fcmp_oeq(ptr %461, ptr %462, ptr %463)
  store i32 %464, ptr %temp_id, align 4
  br label %label_1438

label_1441:                                       ; preds = %label_1439, %label_1438
  %465 = load ptr, ptr %op, align 8
  %466 = call i32 @str_equals(ptr %465, ptr @.str.s563)
  %467 = icmp eq i32 %466, 1
  br i1 %467, label %label_1442, label %label_1444

label_1439:                                       ; preds = %label_1438
  %468 = load ptr, ptr %op_type, align 8
  %469 = load ptr, ptr %left_val, align 8
  %470 = load ptr, ptr %right_val, align 8
  %471 = call i32 @ir_fcmp_one(ptr %468, ptr %469, ptr %470)
  store i32 %471, ptr %temp_id, align 4
  br label %label_1441

label_1444:                                       ; preds = %label_1442, %label_1441
  %472 = load ptr, ptr %op, align 8
  %473 = call i32 @str_equals(ptr %472, ptr @.str.s564)
  %474 = icmp eq i32 %473, 1
  br i1 %474, label %label_1445, label %label_1447

label_1442:                                       ; preds = %label_1441
  %475 = load ptr, ptr %op_type, align 8
  %476 = load ptr, ptr %left_val, align 8
  %477 = load ptr, ptr %right_val, align 8
  %478 = call i32 @ir_fcmp_olt(ptr %475, ptr %476, ptr %477)
  store i32 %478, ptr %temp_id, align 4
  br label %label_1444

label_1447:                                       ; preds = %label_1445, %label_1444
  %479 = load ptr, ptr %op, align 8
  %480 = call i32 @str_equals(ptr %479, ptr @.str.s565)
  %481 = icmp eq i32 %480, 1
  br i1 %481, label %label_1448, label %label_1450

label_1445:                                       ; preds = %label_1444
  %482 = load ptr, ptr %op_type, align 8
  %483 = load ptr, ptr %left_val, align 8
  %484 = load ptr, ptr %right_val, align 8
  %485 = call i32 @ir_fcmp_ole(ptr %482, ptr %483, ptr %484)
  store i32 %485, ptr %temp_id, align 4
  br label %label_1447

label_1450:                                       ; preds = %label_1448, %label_1447
  %486 = load ptr, ptr %op, align 8
  %487 = call i32 @str_equals(ptr %486, ptr @.str.s566)
  %488 = icmp eq i32 %487, 1
  br i1 %488, label %label_1451, label %label_1453

label_1448:                                       ; preds = %label_1447
  %489 = load ptr, ptr %op_type, align 8
  %490 = load ptr, ptr %left_val, align 8
  %491 = load ptr, ptr %right_val, align 8
  %492 = call i32 @ir_fcmp_ogt(ptr %489, ptr %490, ptr %491)
  store i32 %492, ptr %temp_id, align 4
  br label %label_1450

label_1453:                                       ; preds = %label_1451, %label_1450
  br label %label_1423

label_1451:                                       ; preds = %label_1450
  %493 = load ptr, ptr %op_type, align 8
  %494 = load ptr, ptr %left_val, align 8
  %495 = load ptr, ptr %right_val, align 8
  %496 = call i32 @ir_fcmp_oge(ptr %493, ptr %494, ptr %495)
  store i32 %496, ptr %temp_id, align 4
  br label %label_1453

label_1423:                                       ; preds = %label_1471, %label_1453
  %497 = load ptr, ptr %op, align 8
  %498 = call i32 @str_equals(ptr %497, ptr @.str.s582)
  %499 = icmp eq i32 %498, 1
  br i1 %499, label %label_1502, label %label_1504

label_1456:                                       ; preds = %label_1454, %label_1422
  %500 = load ptr, ptr %op, align 8
  %501 = call i32 @str_equals(ptr %500, ptr @.str.s568)
  %502 = icmp eq i32 %501, 1
  br i1 %502, label %label_1457, label %label_1459

label_1454:                                       ; preds = %label_1422
  %503 = load ptr, ptr %op_type, align 8
  %504 = load ptr, ptr %left_val, align 8
  %505 = load ptr, ptr %right_val, align 8
  %506 = call i32 @ir_add(ptr %503, ptr %504, ptr %505)
  store i32 %506, ptr %temp_id, align 4
  br label %label_1456

label_1459:                                       ; preds = %label_1457, %label_1456
  %507 = load ptr, ptr %op, align 8
  %508 = call i32 @str_equals(ptr %507, ptr @.str.s569)
  %509 = icmp eq i32 %508, 1
  br i1 %509, label %label_1460, label %label_1462

label_1457:                                       ; preds = %label_1456
  %510 = load ptr, ptr %op_type, align 8
  %511 = load ptr, ptr %left_val, align 8
  %512 = load ptr, ptr %right_val, align 8
  %513 = call i32 @ir_sub(ptr %510, ptr %511, ptr %512)
  store i32 %513, ptr %temp_id, align 4
  br label %label_1459

label_1462:                                       ; preds = %label_1460, %label_1459
  %514 = load ptr, ptr %op, align 8
  %515 = call i32 @str_equals(ptr %514, ptr @.str.s570)
  %516 = icmp eq i32 %515, 1
  br i1 %516, label %label_1463, label %label_1465

label_1460:                                       ; preds = %label_1459
  %517 = load ptr, ptr %op_type, align 8
  %518 = load ptr, ptr %left_val, align 8
  %519 = load ptr, ptr %right_val, align 8
  %520 = call i32 @ir_mul(ptr %517, ptr %518, ptr %519)
  store i32 %520, ptr %temp_id, align 4
  br label %label_1462

label_1465:                                       ; preds = %label_1463, %label_1462
  %521 = load ptr, ptr %op, align 8
  %522 = call i32 @str_equals(ptr %521, ptr @.str.s571)
  %523 = icmp eq i32 %522, 1
  br i1 %523, label %label_1466, label %label_1468

label_1463:                                       ; preds = %label_1462
  %524 = load ptr, ptr %op_type, align 8
  %525 = load ptr, ptr %left_val, align 8
  %526 = load ptr, ptr %right_val, align 8
  %527 = call i32 @ir_icmp_eq(ptr %524, ptr %525, ptr %526)
  store i32 %527, ptr %temp_id, align 4
  br label %label_1465

label_1468:                                       ; preds = %label_1466, %label_1465
  %528 = load i1, ptr %is_unsigned, align 1
  br i1 %528, label %label_1469, label %label_1470

label_1466:                                       ; preds = %label_1465
  %529 = load ptr, ptr %op_type, align 8
  %530 = load ptr, ptr %left_val, align 8
  %531 = load ptr, ptr %right_val, align 8
  %532 = call i32 @ir_icmp_ne(ptr %529, ptr %530, ptr %531)
  store i32 %532, ptr %temp_id, align 4
  br label %label_1468

label_1470:                                       ; preds = %label_1468
  %533 = load ptr, ptr %op, align 8
  %534 = call i32 @str_equals(ptr %533, ptr @.str.s577)
  %535 = icmp eq i32 %534, 1
  br i1 %535, label %label_1487, label %label_1489

label_1469:                                       ; preds = %label_1468
  %536 = load ptr, ptr %op, align 8
  %537 = call i32 @str_equals(ptr %536, ptr @.str.s572)
  %538 = icmp eq i32 %537, 1
  br i1 %538, label %label_1472, label %label_1474

label_1474:                                       ; preds = %label_1472, %label_1469
  %539 = load ptr, ptr %op, align 8
  %540 = call i32 @str_equals(ptr %539, ptr @.str.s573)
  %541 = icmp eq i32 %540, 1
  br i1 %541, label %label_1475, label %label_1477

label_1472:                                       ; preds = %label_1469
  %542 = load ptr, ptr %op_type, align 8
  %543 = load ptr, ptr %left_val, align 8
  %544 = load ptr, ptr %right_val, align 8
  %545 = call i32 @ir_udiv(ptr %542, ptr %543, ptr %544)
  store i32 %545, ptr %temp_id, align 4
  br label %label_1474

label_1477:                                       ; preds = %label_1475, %label_1474
  %546 = load ptr, ptr %op, align 8
  %547 = call i32 @str_equals(ptr %546, ptr @.str.s574)
  %548 = icmp eq i32 %547, 1
  br i1 %548, label %label_1478, label %label_1480

label_1475:                                       ; preds = %label_1474
  %549 = load ptr, ptr %op_type, align 8
  %550 = load ptr, ptr %left_val, align 8
  %551 = load ptr, ptr %right_val, align 8
  %552 = call i32 @ir_icmp_ult(ptr %549, ptr %550, ptr %551)
  store i32 %552, ptr %temp_id, align 4
  br label %label_1477

label_1480:                                       ; preds = %label_1478, %label_1477
  %553 = load ptr, ptr %op, align 8
  %554 = call i32 @str_equals(ptr %553, ptr @.str.s575)
  %555 = icmp eq i32 %554, 1
  br i1 %555, label %label_1481, label %label_1483

label_1478:                                       ; preds = %label_1477
  %556 = load ptr, ptr %op_type, align 8
  %557 = load ptr, ptr %left_val, align 8
  %558 = load ptr, ptr %right_val, align 8
  %559 = call i32 @ir_icmp_ule(ptr %556, ptr %557, ptr %558)
  store i32 %559, ptr %temp_id, align 4
  br label %label_1480

label_1483:                                       ; preds = %label_1481, %label_1480
  %560 = load ptr, ptr %op, align 8
  %561 = call i32 @str_equals(ptr %560, ptr @.str.s576)
  %562 = icmp eq i32 %561, 1
  br i1 %562, label %label_1484, label %label_1486

label_1481:                                       ; preds = %label_1480
  %563 = load ptr, ptr %op_type, align 8
  %564 = load ptr, ptr %left_val, align 8
  %565 = load ptr, ptr %right_val, align 8
  %566 = call i32 @ir_icmp_ugt(ptr %563, ptr %564, ptr %565)
  store i32 %566, ptr %temp_id, align 4
  br label %label_1483

label_1486:                                       ; preds = %label_1484, %label_1483
  br label %label_1471

label_1484:                                       ; preds = %label_1483
  %567 = load ptr, ptr %op_type, align 8
  %568 = load ptr, ptr %left_val, align 8
  %569 = load ptr, ptr %right_val, align 8
  %570 = call i32 @ir_icmp_uge(ptr %567, ptr %568, ptr %569)
  store i32 %570, ptr %temp_id, align 4
  br label %label_1486

label_1471:                                       ; preds = %label_1501, %label_1486
  br label %label_1423

label_1489:                                       ; preds = %label_1487, %label_1470
  %571 = load ptr, ptr %op, align 8
  %572 = call i32 @str_equals(ptr %571, ptr @.str.s578)
  %573 = icmp eq i32 %572, 1
  br i1 %573, label %label_1490, label %label_1492

label_1487:                                       ; preds = %label_1470
  %574 = load ptr, ptr %op_type, align 8
  %575 = load ptr, ptr %left_val, align 8
  %576 = load ptr, ptr %right_val, align 8
  %577 = call i32 @ir_sdiv(ptr %574, ptr %575, ptr %576)
  store i32 %577, ptr %temp_id, align 4
  br label %label_1489

label_1492:                                       ; preds = %label_1490, %label_1489
  %578 = load ptr, ptr %op, align 8
  %579 = call i32 @str_equals(ptr %578, ptr @.str.s579)
  %580 = icmp eq i32 %579, 1
  br i1 %580, label %label_1493, label %label_1495

label_1490:                                       ; preds = %label_1489
  %581 = load ptr, ptr %op_type, align 8
  %582 = load ptr, ptr %left_val, align 8
  %583 = load ptr, ptr %right_val, align 8
  %584 = call i32 @ir_icmp_slt(ptr %581, ptr %582, ptr %583)
  store i32 %584, ptr %temp_id, align 4
  br label %label_1492

label_1495:                                       ; preds = %label_1493, %label_1492
  %585 = load ptr, ptr %op, align 8
  %586 = call i32 @str_equals(ptr %585, ptr @.str.s580)
  %587 = icmp eq i32 %586, 1
  br i1 %587, label %label_1496, label %label_1498

label_1493:                                       ; preds = %label_1492
  %588 = load ptr, ptr %op_type, align 8
  %589 = load ptr, ptr %left_val, align 8
  %590 = load ptr, ptr %right_val, align 8
  %591 = call i32 @ir_icmp_sle(ptr %588, ptr %589, ptr %590)
  store i32 %591, ptr %temp_id, align 4
  br label %label_1495

label_1498:                                       ; preds = %label_1496, %label_1495
  %592 = load ptr, ptr %op, align 8
  %593 = call i32 @str_equals(ptr %592, ptr @.str.s581)
  %594 = icmp eq i32 %593, 1
  br i1 %594, label %label_1499, label %label_1501

label_1496:                                       ; preds = %label_1495
  %595 = load ptr, ptr %op_type, align 8
  %596 = load ptr, ptr %left_val, align 8
  %597 = load ptr, ptr %right_val, align 8
  %598 = call i32 @ir_icmp_sgt(ptr %595, ptr %596, ptr %597)
  store i32 %598, ptr %temp_id, align 4
  br label %label_1498

label_1501:                                       ; preds = %label_1499, %label_1498
  br label %label_1471

label_1499:                                       ; preds = %label_1498
  %599 = load ptr, ptr %op_type, align 8
  %600 = load ptr, ptr %left_val, align 8
  %601 = load ptr, ptr %right_val, align 8
  %602 = call i32 @ir_icmp_sge(ptr %599, ptr %600, ptr %601)
  store i32 %602, ptr %temp_id, align 4
  br label %label_1501

label_1504:                                       ; preds = %label_1507, %label_1423
  %603 = load ptr, ptr %op, align 8
  %604 = call i32 @str_equals(ptr %603, ptr @.str.s583)
  %605 = icmp eq i32 %604, 1
  br i1 %605, label %label_1508, label %label_1510

label_1502:                                       ; preds = %label_1423
  %606 = load i1, ptr %is_unsigned, align 1
  br i1 %606, label %label_1505, label %label_1506

label_1506:                                       ; preds = %label_1502
  %607 = load ptr, ptr %op_type, align 8
  %608 = load ptr, ptr %left_val, align 8
  %609 = load ptr, ptr %right_val, align 8
  %610 = call i32 @ir_srem(ptr %607, ptr %608, ptr %609)
  store i32 %610, ptr %temp_id, align 4
  br label %label_1507

label_1505:                                       ; preds = %label_1502
  %611 = load ptr, ptr %op_type, align 8
  %612 = load ptr, ptr %left_val, align 8
  %613 = load ptr, ptr %right_val, align 8
  %614 = call i32 @ir_urem(ptr %611, ptr %612, ptr %613)
  store i32 %614, ptr %temp_id, align 4
  br label %label_1507

label_1507:                                       ; preds = %label_1506, %label_1505
  br label %label_1504

label_1510:                                       ; preds = %label_1508, %label_1504
  %615 = load ptr, ptr %op, align 8
  %616 = call i32 @str_equals(ptr %615, ptr @.str.s584)
  %617 = icmp eq i32 %616, 1
  br i1 %617, label %label_1511, label %label_1513

label_1508:                                       ; preds = %label_1504
  %618 = load ptr, ptr %op_type, align 8
  %619 = load ptr, ptr %left_val, align 8
  %620 = load ptr, ptr %right_val, align 8
  %621 = call i32 @ir_and(ptr %618, ptr %619, ptr %620)
  store i32 %621, ptr %temp_id, align 4
  br label %label_1510

label_1513:                                       ; preds = %label_1511, %label_1510
  %622 = load ptr, ptr %op, align 8
  %623 = call i32 @str_equals(ptr %622, ptr @.str.s585)
  %624 = icmp eq i32 %623, 1
  br i1 %624, label %label_1514, label %label_1516

label_1511:                                       ; preds = %label_1510
  %625 = load ptr, ptr %op_type, align 8
  %626 = load ptr, ptr %left_val, align 8
  %627 = load ptr, ptr %right_val, align 8
  %628 = call i32 @ir_or(ptr %625, ptr %626, ptr %627)
  store i32 %628, ptr %temp_id, align 4
  br label %label_1513

label_1516:                                       ; preds = %label_1514, %label_1513
  %629 = load ptr, ptr %op, align 8
  %630 = call i32 @str_equals(ptr %629, ptr @.str.s586)
  %631 = icmp eq i32 %630, 1
  br i1 %631, label %label_1517, label %label_1519

label_1514:                                       ; preds = %label_1513
  %632 = load ptr, ptr %op_type, align 8
  %633 = load ptr, ptr %left_val, align 8
  %634 = load ptr, ptr %right_val, align 8
  %635 = call i32 @ir_xor(ptr %632, ptr %633, ptr %634)
  store i32 %635, ptr %temp_id, align 4
  br label %label_1516

label_1519:                                       ; preds = %label_1517, %label_1516
  %636 = load ptr, ptr %op, align 8
  %637 = call i32 @str_equals(ptr %636, ptr @.str.s587)
  %638 = icmp eq i32 %637, 1
  br i1 %638, label %label_1520, label %label_1522

label_1517:                                       ; preds = %label_1516
  %639 = load ptr, ptr %op_type, align 8
  %640 = load ptr, ptr %left_val, align 8
  %641 = load ptr, ptr %right_val, align 8
  %642 = call i32 @ir_shl(ptr %639, ptr %640, ptr %641)
  store i32 %642, ptr %temp_id, align 4
  br label %label_1519

label_1522:                                       ; preds = %label_1525, %label_1519
  %643 = load i32, ptr %temp_id, align 4
  %644 = call ptr @ir_get_temp_name(i32 %643)
  ret ptr %644

label_1520:                                       ; preds = %label_1519
  %645 = load i1, ptr %is_unsigned, align 1
  br i1 %645, label %label_1523, label %label_1524

label_1524:                                       ; preds = %label_1520
  %646 = load ptr, ptr %op_type, align 8
  %647 = load ptr, ptr %left_val, align 8
  %648 = load ptr, ptr %right_val, align 8
  %649 = call i32 @ir_ashr(ptr %646, ptr %647, ptr %648)
  store i32 %649, ptr %temp_id, align 4
  br label %label_1525

label_1523:                                       ; preds = %label_1520
  %650 = load ptr, ptr %op_type, align 8
  %651 = load ptr, ptr %left_val, align 8
  %652 = load ptr, ptr %right_val, align 8
  %653 = call i32 @ir_lshr(ptr %650, ptr %651, ptr %652)
  store i32 %653, ptr %temp_id, align 4
  br label %label_1525

label_1525:                                       ; preds = %label_1524, %label_1523
  br label %label_1522

label_1528:                                       ; preds = %label_1412
  ret ptr @.str.s630

label_1526:                                       ; preds = %label_1412
  %654 = load ptr, ptr %expr, align 8
  %655 = getelementptr inbounds nuw %ASTNode, ptr %654, i32 0, i32 5
  %656 = load ptr, ptr %655, align 8
  %657 = call ptr @ptr_to_node(ptr %656)
  store ptr %657, ptr %callee, align 8
  %658 = load ptr, ptr %callee, align 8
  %659 = getelementptr inbounds nuw %ASTNode, ptr %658, i32 0, i32 1
  %660 = load ptr, ptr %659, align 8
  store ptr %660, ptr %func_name, align 8
  %661 = load ptr, ptr %func_name, align 8
  %662 = call i32 @str_equals(ptr %661, ptr @.str.s588)
  %663 = icmp eq i32 %662, 1
  br i1 %663, label %label_1529, label %label_1531

label_1531:                                       ; preds = %label_1526
  store i32 0, ptr %is_print_bool, align 4
  %664 = load ptr, ptr %func_name, align 8
  %665 = call i32 @str_equals(ptr %664, ptr @.str.s594)
  %666 = icmp eq i32 %665, 1
  br i1 %666, label %label_1535, label %label_1537

label_1529:                                       ; preds = %label_1526
  %667 = load ptr, ptr %expr, align 8
  %668 = getelementptr inbounds nuw %ASTNode, ptr %667, i32 0, i32 6
  %669 = load ptr, ptr %668, align 8
  store ptr %669, ptr %drop_arg, align 8
  %670 = load ptr, ptr %drop_arg, align 8
  %671 = call i32 @str_equals(ptr %670, ptr @.str.s589)
  %672 = icmp eq i32 %671, 0
  br i1 %672, label %label_1532, label %label_1534

label_1534:                                       ; preds = %label_1532, %label_1529
  ret ptr @.str.s593

label_1532:                                       ; preds = %label_1529
  %673 = load ptr, ptr %drop_arg, align 8
  %674 = call ptr @ptr_to_node(ptr %673)
  %675 = call ptr @generate_expression__Struct_ASTNode(ptr %674)
  store ptr %675, ptr %drop_val, align 8
  call void @ir_call_begin()
  %676 = load ptr, ptr %drop_val, align 8
  call void @ir_call_arg(ptr @.str.s590, ptr %676)
  %677 = call i32 @ir_call_end(ptr @.str.s591, ptr @.str.s592)
  br label %label_1534

label_1537:                                       ; preds = %label_1535, %label_1531
  %678 = load ptr, ptr %func_name, align 8
  %679 = call i32 @str_equals(ptr %678, ptr @.str.s595)
  %680 = icmp eq i32 %679, 1
  br i1 %680, label %label_1538, label %label_1540

label_1535:                                       ; preds = %label_1531
  store i32 1, ptr %is_print_bool, align 4
  br label %label_1537

label_1540:                                       ; preds = %label_1538, %label_1537
  %681 = load i32, ptr %is_print_bool, align 4
  %682 = icmp sgt i32 %681, 0
  br i1 %682, label %label_1541, label %label_1543

label_1538:                                       ; preds = %label_1537
  store i32 2, ptr %is_print_bool, align 4
  br label %label_1540

label_1543:                                       ; preds = %label_1540
  store i32 0, ptr %is_print, align 4
  %683 = load ptr, ptr %func_name, align 8
  %684 = call i32 @str_equals(ptr %683, ptr @.str.s605)
  %685 = icmp eq i32 %684, 1
  br i1 %685, label %label_1550, label %label_1552

label_1541:                                       ; preds = %label_1540
  %686 = load ptr, ptr %expr, align 8
  %687 = getelementptr inbounds nuw %ASTNode, ptr %686, i32 0, i32 6
  %688 = load ptr, ptr %687, align 8
  store ptr %688, ptr %bool_arg_ptr, align 8
  %689 = load ptr, ptr %bool_arg_ptr, align 8
  %690 = call i32 @str_equals(ptr %689, ptr @.str.s596)
  %691 = icmp eq i32 %690, 0
  br i1 %691, label %label_1544, label %label_1546

label_1546:                                       ; preds = %label_1549, %label_1541
  ret ptr @.str.s604

label_1544:                                       ; preds = %label_1541
  %692 = load ptr, ptr %bool_arg_ptr, align 8
  %693 = call ptr @ptr_to_node(ptr %692)
  store ptr %693, ptr %bool_arg, align 8
  %694 = load ptr, ptr %bool_arg, align 8
  %695 = call ptr @generate_expression__Struct_ASTNode(ptr %694)
  store ptr %695, ptr %bool_val, align 8
  %696 = load ptr, ptr %bool_val, align 8
  %697 = call i32 @ir_zext(ptr @.str.s597, ptr %696, ptr @.str.s598)
  store i32 %697, ptr %widened, align 4
  call void @ir_call_begin()
  %698 = load i32, ptr %widened, align 4
  %699 = call ptr @ir_get_temp_name(i32 %698)
  call void @ir_call_arg(ptr @.str.s599, ptr %699)
  %700 = load i32, ptr %is_print_bool, align 4
  %701 = icmp eq i32 %700, 1
  br i1 %701, label %label_1547, label %label_1548

label_1548:                                       ; preds = %label_1544
  %702 = call i32 @ir_call_end(ptr @.str.s602, ptr @.str.s603)
  br label %label_1549

label_1547:                                       ; preds = %label_1544
  %703 = call i32 @ir_call_end(ptr @.str.s600, ptr @.str.s601)
  br label %label_1549

label_1549:                                       ; preds = %label_1548, %label_1547
  br label %label_1546

label_1552:                                       ; preds = %label_1550, %label_1543
  %704 = load ptr, ptr %func_name, align 8
  %705 = call i32 @str_equals(ptr %704, ptr @.str.s606)
  %706 = icmp eq i32 %705, 1
  br i1 %706, label %label_1553, label %label_1555

label_1550:                                       ; preds = %label_1543
  store i32 1, ptr %is_print, align 4
  br label %label_1552

label_1555:                                       ; preds = %label_1553, %label_1552
  %707 = load i32, ptr %is_print, align 4
  %708 = icmp sgt i32 %707, 0
  br i1 %708, label %label_1556, label %label_1558

label_1553:                                       ; preds = %label_1552
  store i32 2, ptr %is_print, align 4
  br label %label_1555

label_1558:                                       ; preds = %label_1555
  call void @ir_call_begin()
  %709 = load ptr, ptr %expr, align 8
  %710 = getelementptr inbounds nuw %ASTNode, ptr %709, i32 0, i32 6
  %711 = load ptr, ptr %710, align 8
  store ptr %711, ptr %arg_ptr, align 8
  br label %label_1577

label_1556:                                       ; preds = %label_1555
  %712 = load ptr, ptr %expr, align 8
  %713 = getelementptr inbounds nuw %ASTNode, ptr %712, i32 0, i32 6
  %714 = load ptr, ptr %713, align 8
  store ptr %714, ptr %arg_ptr, align 8
  %715 = load ptr, ptr %arg_ptr, align 8
  %716 = call i32 @str_equals(ptr %715, ptr @.str.s607)
  %717 = icmp eq i32 %716, 0
  br i1 %717, label %label_1559, label %label_1561

label_1561:                                       ; preds = %label_1564, %label_1556
  ret ptr @.str.s624

label_1559:                                       ; preds = %label_1556
  %718 = load ptr, ptr %arg_ptr, align 8
  %719 = call ptr @ptr_to_node(ptr %718)
  store ptr %719, ptr %arg_node, align 8
  %720 = load ptr, ptr %arg_node, align 8
  %721 = call ptr @generate_expression__Struct_ASTNode(ptr %720)
  store ptr %721, ptr %arg_val, align 8
  %722 = load ptr, ptr %arg_node, align 8
  %723 = call ptr @get_expr_type__Struct_ASTNode(ptr %722)
  store ptr %723, ptr %arg_type, align 8
  call void @ir_call_begin()
  %724 = load ptr, ptr %arg_type, align 8
  %725 = call i32 @str_equals(ptr %724, ptr @.str.s608)
  %726 = icmp eq i32 %725, 1
  br i1 %726, label %label_1562, label %label_1563

label_1563:                                       ; preds = %label_1559
  %727 = load ptr, ptr %arg_type, align 8
  %728 = call i32 @str_equals(ptr %727, ptr @.str.s614)
  %729 = icmp eq i32 %728, 1
  br i1 %729, label %label_1568, label %label_1569

label_1562:                                       ; preds = %label_1559
  %730 = load ptr, ptr %arg_val, align 8
  call void @ir_call_arg(ptr @.str.s609, ptr %730)
  %731 = load i32, ptr %is_print, align 4
  %732 = icmp eq i32 %731, 1
  br i1 %732, label %label_1565, label %label_1566

label_1566:                                       ; preds = %label_1562
  %733 = call i32 @ir_call_end(ptr @.str.s612, ptr @.str.s613)
  br label %label_1567

label_1565:                                       ; preds = %label_1562
  %734 = call i32 @ir_call_end(ptr @.str.s610, ptr @.str.s611)
  br label %label_1567

label_1567:                                       ; preds = %label_1566, %label_1565
  br label %label_1564

label_1564:                                       ; preds = %label_1570, %label_1567
  br label %label_1561

label_1569:                                       ; preds = %label_1563
  %735 = load ptr, ptr %arg_type, align 8
  %736 = call ptr @storage_type__String(ptr %735)
  %737 = load ptr, ptr %arg_val, align 8
  call void @ir_call_arg(ptr %736, ptr %737)
  %738 = load i32, ptr %is_print, align 4
  %739 = icmp eq i32 %738, 1
  br i1 %739, label %label_1574, label %label_1575

label_1568:                                       ; preds = %label_1563
  %740 = load ptr, ptr %arg_val, align 8
  call void @ir_call_arg(ptr @.str.s615, ptr %740)
  %741 = load i32, ptr %is_print, align 4
  %742 = icmp eq i32 %741, 1
  br i1 %742, label %label_1571, label %label_1572

label_1572:                                       ; preds = %label_1568
  %743 = call i32 @ir_call_end(ptr @.str.s618, ptr @.str.s619)
  br label %label_1573

label_1571:                                       ; preds = %label_1568
  %744 = call i32 @ir_call_end(ptr @.str.s616, ptr @.str.s617)
  br label %label_1573

label_1573:                                       ; preds = %label_1572, %label_1571
  br label %label_1570

label_1570:                                       ; preds = %label_1576, %label_1573
  br label %label_1564

label_1575:                                       ; preds = %label_1569
  %745 = call i32 @ir_call_end(ptr @.str.s622, ptr @.str.s623)
  br label %label_1576

label_1574:                                       ; preds = %label_1569
  %746 = call i32 @ir_call_end(ptr @.str.s620, ptr @.str.s621)
  br label %label_1576

label_1576:                                       ; preds = %label_1575, %label_1574
  br label %label_1570

label_1577:                                       ; preds = %label_1578, %label_1558
  %747 = load ptr, ptr %arg_ptr, align 8
  %748 = call i32 @str_equals(ptr %747, ptr @.str.s625)
  %749 = icmp eq i32 %748, 0
  br i1 %749, label %label_1578, label %label_1579

label_1579:                                       ; preds = %label_1577
  %750 = load ptr, ptr %func_name, align 8
  store ptr %750, ptr %call_name, align 8
  %751 = load ptr, ptr %expr, align 8
  %752 = getelementptr inbounds nuw %ASTNode, ptr %751, i32 0, i32 2
  %753 = load ptr, ptr %752, align 8
  %754 = call i32 @str_equals(ptr %753, ptr @.str.s626)
  %755 = icmp eq i32 %754, 0
  br i1 %755, label %label_1580, label %label_1582

label_1578:                                       ; preds = %label_1577
  %756 = load ptr, ptr %arg_ptr, align 8
  %757 = call ptr @ptr_to_node(ptr %756)
  store ptr %757, ptr %arg_node, align 8
  %758 = load ptr, ptr %arg_node, align 8
  %759 = call ptr @generate_expression__Struct_ASTNode(ptr %758)
  store ptr %759, ptr %arg_val, align 8
  %760 = load ptr, ptr %arg_node, align 8
  %761 = call ptr @get_expr_type__Struct_ASTNode(ptr %760)
  %762 = call ptr @storage_type__String(ptr %761)
  %763 = load ptr, ptr %arg_val, align 8
  call void @ir_call_arg(ptr %762, ptr %763)
  %764 = load ptr, ptr %arg_node, align 8
  %765 = getelementptr inbounds nuw %ASTNode, ptr %764, i32 0, i32 8
  %766 = load ptr, ptr %765, align 8
  store ptr %766, ptr %arg_ptr, align 8
  br label %label_1577

label_1582:                                       ; preds = %label_1580, %label_1579
  %767 = load ptr, ptr %expr, align 8
  %768 = call ptr @get_expr_type__Struct_ASTNode(ptr %767)
  %769 = call ptr @storage_type__String(ptr %768)
  store ptr %769, ptr %ret_type, align 8
  %770 = load ptr, ptr %ret_type, align 8
  %771 = call i32 @str_equals(ptr %770, ptr @.str.s627)
  %772 = icmp eq i32 %771, 1
  br i1 %772, label %label_1583, label %label_1585

label_1580:                                       ; preds = %label_1579
  %773 = load ptr, ptr %expr, align 8
  %774 = getelementptr inbounds nuw %ASTNode, ptr %773, i32 0, i32 2
  %775 = load ptr, ptr %774, align 8
  store ptr %775, ptr %call_name, align 8
  br label %label_1582

label_1585:                                       ; preds = %label_1582
  %776 = load ptr, ptr %ret_type, align 8
  %777 = load ptr, ptr %call_name, align 8
  %778 = call i32 @ir_call_end(ptr %776, ptr %777)
  store i32 %778, ptr %temp_id, align 4
  %779 = load i32, ptr %temp_id, align 4
  %780 = call ptr @ir_get_temp_name(i32 %779)
  ret ptr %780

label_1583:                                       ; preds = %label_1582
  %781 = load ptr, ptr %call_name, align 8
  %782 = call i32 @ir_call_end(ptr @.str.s628, ptr %781)
  ret ptr @.str.s629
}

define void @generate_statement__Struct_ASTNode(ptr %0) {
entry:
  %stmt = alloca ptr, align 8
  store ptr %0, ptr %stmt, align 8
  %var_name = alloca ptr, align 8
  %var_type = alloca ptr, align 8
  %type_node = alloca ptr, align 8
  %store_type = alloca ptr, align 8
  %init_val = alloca ptr, align 8
  %target_node = alloca ptr, align 8
  %val = alloca ptr, align 8
  %object_node = alloca ptr, align 8
  %object_val = alloca ptr, align 8
  %object_type = alloca ptr, align 8
  %struct_name = alloca ptr, align 8
  %field_index = alloca i32, align 4
  %field_type = alloca ptr, align 8
  %slot = alloca i32, align 4
  %ret_val = alloca ptr, align 8
  %cond_val = alloca ptr, align 8
  %then_label = alloca i32, align 4
  %else_label = alloca i32, align 4
  %end_label = alloca i32, align 4
  %else_node = alloca ptr, align 8
  %cond_label = alloca i32, align 4
  %body_label = alloca i32, align 4
  %loop_var = alloca ptr, align 8
  %start_val = alloca ptr, align 8
  %incr_label = alloca i32, align 4
  %iv = alloca i32, align 4
  %end_val = alloca ptr, align 8
  %cmp = alloca i32, align 4
  %iv2 = alloca i32, align 4
  %next = alloca i32, align 4
  %target = alloca i32, align 4
  %scrut_val = alloca ptr, align 8
  %scrut_type = alloca ptr, align 8
  %needs_final_br = alloca i1, align 1
  %arm_ptr = alloca ptr, align 8
  %arm = alloca ptr, align 8
  %pat_val = alloca ptr, align 8
  %arm_label = alloca i32, align 4
  %next_label = alloca i32, align 4
  %1 = load ptr, ptr %stmt, align 8
  %2 = getelementptr inbounds nuw %ASTNode, ptr %1, i32 0, i32 0
  %3 = load i32, ptr %2, align 4
  %4 = icmp eq i32 %3, 3
  br i1 %4, label %label_1586, label %label_1588

label_1588:                                       ; preds = %label_1597, %entry
  %5 = load ptr, ptr %stmt, align 8
  %6 = getelementptr inbounds nuw %ASTNode, ptr %5, i32 0, i32 0
  %7 = load i32, ptr %6, align 4
  %8 = icmp eq i32 %7, 16
  br i1 %8, label %label_1598, label %label_1600

label_1586:                                       ; preds = %entry
  %9 = load ptr, ptr %stmt, align 8
  %10 = getelementptr inbounds nuw %ASTNode, ptr %9, i32 0, i32 1
  %11 = load ptr, ptr %10, align 8
  store ptr %11, ptr %var_name, align 8
  store ptr @.str.s631, ptr %var_type, align 8
  %12 = load ptr, ptr %stmt, align 8
  %13 = getelementptr inbounds nuw %ASTNode, ptr %12, i32 0, i32 5
  %14 = load ptr, ptr %13, align 8
  %15 = call i32 @str_equals(ptr %14, ptr @.str.s632)
  %16 = icmp eq i32 %15, 0
  br i1 %16, label %label_1589, label %label_1590

label_1590:                                       ; preds = %label_1586
  %17 = load ptr, ptr %stmt, align 8
  %18 = getelementptr inbounds nuw %ASTNode, ptr %17, i32 0, i32 6
  %19 = load ptr, ptr %18, align 8
  %20 = call i32 @str_equals(ptr %19, ptr @.str.s633)
  %21 = icmp eq i32 %20, 0
  br i1 %21, label %label_1592, label %label_1594

label_1589:                                       ; preds = %label_1586
  %22 = load ptr, ptr %stmt, align 8
  %23 = getelementptr inbounds nuw %ASTNode, ptr %22, i32 0, i32 5
  %24 = load ptr, ptr %23, align 8
  %25 = call ptr @ptr_to_node(ptr %24)
  store ptr %25, ptr %type_node, align 8
  %26 = load ptr, ptr %type_node, align 8
  %27 = call ptr @map_type_node__Struct_ASTNode(ptr %26)
  store ptr %27, ptr %var_type, align 8
  br label %label_1591

label_1591:                                       ; preds = %label_1594, %label_1589
  %28 = load ptr, ptr %var_name, align 8
  %29 = load ptr, ptr %var_type, align 8
  call void @ir_set_var_type(ptr %28, ptr %29)
  %30 = load ptr, ptr %var_type, align 8
  %31 = call ptr @storage_type__String(ptr %30)
  store ptr %31, ptr %store_type, align 8
  %32 = load ptr, ptr %store_type, align 8
  %33 = load ptr, ptr %var_name, align 8
  %34 = call i32 @ir_alloca(ptr %32, ptr %33)
  %35 = load ptr, ptr %stmt, align 8
  %36 = getelementptr inbounds nuw %ASTNode, ptr %35, i32 0, i32 6
  %37 = load ptr, ptr %36, align 8
  %38 = call i32 @str_equals(ptr %37, ptr @.str.s634)
  %39 = icmp eq i32 %38, 0
  br i1 %39, label %label_1595, label %label_1597

label_1594:                                       ; preds = %label_1592, %label_1590
  br label %label_1591

label_1592:                                       ; preds = %label_1590
  %40 = load ptr, ptr %stmt, align 8
  %41 = getelementptr inbounds nuw %ASTNode, ptr %40, i32 0, i32 6
  %42 = load ptr, ptr %41, align 8
  %43 = call ptr @ptr_to_node(ptr %42)
  %44 = call ptr @get_expr_type__Struct_ASTNode(ptr %43)
  store ptr %44, ptr %var_type, align 8
  br label %label_1594

label_1597:                                       ; preds = %label_1595, %label_1591
  br label %label_1588

label_1595:                                       ; preds = %label_1591
  %45 = load ptr, ptr %stmt, align 8
  %46 = getelementptr inbounds nuw %ASTNode, ptr %45, i32 0, i32 6
  %47 = load ptr, ptr %46, align 8
  %48 = call ptr @ptr_to_node(ptr %47)
  %49 = call ptr @generate_expression__Struct_ASTNode(ptr %48)
  store ptr %49, ptr %init_val, align 8
  %50 = load ptr, ptr %store_type, align 8
  %51 = load ptr, ptr %init_val, align 8
  %52 = load ptr, ptr %var_name, align 8
  call void @ir_store(ptr %50, ptr %51, ptr %52)
  br label %label_1597

label_1600:                                       ; preds = %label_1609, %label_1588
  %53 = load ptr, ptr %stmt, align 8
  %54 = getelementptr inbounds nuw %ASTNode, ptr %53, i32 0, i32 0
  %55 = load i32, ptr %54, align 4
  %56 = icmp eq i32 %55, 15
  br i1 %56, label %label_1610, label %label_1612

label_1598:                                       ; preds = %label_1588
  %57 = load ptr, ptr %stmt, align 8
  %58 = getelementptr inbounds nuw %ASTNode, ptr %57, i32 0, i32 5
  %59 = load ptr, ptr %58, align 8
  %60 = call ptr @ptr_to_node(ptr %59)
  store ptr %60, ptr %target_node, align 8
  %61 = load ptr, ptr %target_node, align 8
  %62 = getelementptr inbounds nuw %ASTNode, ptr %61, i32 0, i32 0
  %63 = load i32, ptr %62, align 4
  %64 = icmp eq i32 %63, 23
  br i1 %64, label %label_1601, label %label_1603

label_1603:                                       ; preds = %label_1606, %label_1598
  %65 = load ptr, ptr %target_node, align 8
  %66 = getelementptr inbounds nuw %ASTNode, ptr %65, i32 0, i32 0
  %67 = load i32, ptr %66, align 4
  %68 = icmp eq i32 %67, 25
  br i1 %68, label %label_1607, label %label_1609

label_1601:                                       ; preds = %label_1598
  %69 = load ptr, ptr %target_node, align 8
  %70 = getelementptr inbounds nuw %ASTNode, ptr %69, i32 0, i32 1
  %71 = load ptr, ptr %70, align 8
  store ptr %71, ptr %var_name, align 8
  %72 = load ptr, ptr %var_name, align 8
  %73 = call ptr @ir_get_var_type(ptr %72)
  store ptr %73, ptr %var_type, align 8
  %74 = load ptr, ptr %var_type, align 8
  %75 = call ptr @storage_type__String(ptr %74)
  store ptr %75, ptr %store_type, align 8
  %76 = load ptr, ptr %stmt, align 8
  %77 = getelementptr inbounds nuw %ASTNode, ptr %76, i32 0, i32 6
  %78 = load ptr, ptr %77, align 8
  %79 = call ptr @ptr_to_node(ptr %78)
  %80 = call ptr @generate_expression__Struct_ASTNode(ptr %79)
  store ptr %80, ptr %val, align 8
  %81 = load ptr, ptr %var_name, align 8
  %82 = call i32 @ir_is_global_name(ptr %81)
  %83 = icmp eq i32 %82, 1
  br i1 %83, label %label_1604, label %label_1605

label_1605:                                       ; preds = %label_1601
  %84 = load ptr, ptr %store_type, align 8
  %85 = load ptr, ptr %val, align 8
  %86 = load ptr, ptr %var_name, align 8
  call void @ir_store(ptr %84, ptr %85, ptr %86)
  br label %label_1606

label_1604:                                       ; preds = %label_1601
  %87 = load ptr, ptr %store_type, align 8
  %88 = load ptr, ptr %val, align 8
  %89 = load ptr, ptr %var_name, align 8
  call void @ir_store_global(ptr %87, ptr %88, ptr %89)
  br label %label_1606

label_1606:                                       ; preds = %label_1605, %label_1604
  br label %label_1603

label_1609:                                       ; preds = %label_1607, %label_1603
  br label %label_1600

label_1607:                                       ; preds = %label_1603
  %90 = load ptr, ptr %target_node, align 8
  %91 = getelementptr inbounds nuw %ASTNode, ptr %90, i32 0, i32 5
  %92 = load ptr, ptr %91, align 8
  %93 = call ptr @ptr_to_node(ptr %92)
  store ptr %93, ptr %object_node, align 8
  %94 = load ptr, ptr %object_node, align 8
  %95 = call ptr @generate_expression__Struct_ASTNode(ptr %94)
  store ptr %95, ptr %object_val, align 8
  %96 = load ptr, ptr %object_node, align 8
  %97 = call ptr @get_expr_type__Struct_ASTNode(ptr %96)
  store ptr %97, ptr %object_type, align 8
  %98 = load ptr, ptr %object_type, align 8
  %99 = call ptr @struct_type_name__String(ptr %98)
  store ptr %99, ptr %struct_name, align 8
  %100 = load ptr, ptr %struct_name, align 8
  %101 = load ptr, ptr %target_node, align 8
  %102 = getelementptr inbounds nuw %ASTNode, ptr %101, i32 0, i32 1
  %103 = load ptr, ptr %102, align 8
  %104 = call i32 @ir_get_struct_field_index(ptr %100, ptr %103)
  store i32 %104, ptr %field_index, align 4
  %105 = load ptr, ptr %struct_name, align 8
  %106 = load ptr, ptr %target_node, align 8
  %107 = getelementptr inbounds nuw %ASTNode, ptr %106, i32 0, i32 1
  %108 = load ptr, ptr %107, align 8
  %109 = call ptr @ir_get_struct_field_type(ptr %105, ptr %108)
  %110 = call ptr @storage_type__String(ptr %109)
  store ptr %110, ptr %field_type, align 8
  %111 = load ptr, ptr %stmt, align 8
  %112 = getelementptr inbounds nuw %ASTNode, ptr %111, i32 0, i32 6
  %113 = load ptr, ptr %112, align 8
  %114 = call ptr @ptr_to_node(ptr %113)
  %115 = call ptr @generate_expression__Struct_ASTNode(ptr %114)
  store ptr %115, ptr %val, align 8
  %116 = load ptr, ptr %struct_name, align 8
  %117 = load ptr, ptr %object_val, align 8
  %118 = load i32, ptr %field_index, align 4
  %119 = call i32 @ir_struct_field_ptr(ptr %116, ptr %117, i32 %118)
  store i32 %119, ptr %slot, align 4
  %120 = load ptr, ptr %field_type, align 8
  %121 = load ptr, ptr %val, align 8
  %122 = load i32, ptr %slot, align 4
  %123 = call ptr @ir_get_temp_name(i32 %122)
  call void @ir_store_ptr(ptr %120, ptr %121, ptr %123)
  br label %label_1609

label_1612:                                       ; preds = %label_1615, %label_1600
  %124 = load ptr, ptr %stmt, align 8
  %125 = getelementptr inbounds nuw %ASTNode, ptr %124, i32 0, i32 0
  %126 = load i32, ptr %125, align 4
  %127 = icmp eq i32 %126, 17
  br i1 %127, label %label_1616, label %label_1618

label_1610:                                       ; preds = %label_1600
  %128 = load ptr, ptr %stmt, align 8
  %129 = getelementptr inbounds nuw %ASTNode, ptr %128, i32 0, i32 5
  %130 = load ptr, ptr %129, align 8
  %131 = call i32 @str_equals(ptr %130, ptr @.str.s635)
  %132 = icmp eq i32 %131, 0
  br i1 %132, label %label_1613, label %label_1614

label_1614:                                       ; preds = %label_1610
  call void @ir_ret_void()
  br label %label_1615

label_1613:                                       ; preds = %label_1610
  %133 = load ptr, ptr %stmt, align 8
  %134 = getelementptr inbounds nuw %ASTNode, ptr %133, i32 0, i32 5
  %135 = load ptr, ptr %134, align 8
  %136 = call ptr @ptr_to_node(ptr %135)
  %137 = call ptr @generate_expression__Struct_ASTNode(ptr %136)
  store ptr %137, ptr %ret_val, align 8
  %138 = load ptr, ptr %stmt, align 8
  %139 = getelementptr inbounds nuw %ASTNode, ptr %138, i32 0, i32 5
  %140 = load ptr, ptr %139, align 8
  %141 = call ptr @ptr_to_node(ptr %140)
  %142 = call ptr @get_expr_type__Struct_ASTNode(ptr %141)
  %143 = call ptr @storage_type__String(ptr %142)
  %144 = load ptr, ptr %ret_val, align 8
  call void @ir_ret(ptr %143, ptr %144)
  br label %label_1615

label_1615:                                       ; preds = %label_1614, %label_1613
  call void @ir_set_returned()
  br label %label_1612

label_1618:                                       ; preds = %label_1621, %label_1612
  %145 = load ptr, ptr %stmt, align 8
  %146 = getelementptr inbounds nuw %ASTNode, ptr %145, i32 0, i32 0
  %147 = load i32, ptr %146, align 4
  %148 = icmp eq i32 %147, 10
  br i1 %148, label %label_1622, label %label_1624

label_1616:                                       ; preds = %label_1612
  %149 = load ptr, ptr %stmt, align 8
  %150 = getelementptr inbounds nuw %ASTNode, ptr %149, i32 0, i32 5
  %151 = load ptr, ptr %150, align 8
  %152 = call i32 @str_equals(ptr %151, ptr @.str.s636)
  %153 = icmp eq i32 %152, 0
  br i1 %153, label %label_1619, label %label_1621

label_1621:                                       ; preds = %label_1619, %label_1616
  br label %label_1618

label_1619:                                       ; preds = %label_1616
  %154 = load ptr, ptr %stmt, align 8
  %155 = getelementptr inbounds nuw %ASTNode, ptr %154, i32 0, i32 5
  %156 = load ptr, ptr %155, align 8
  %157 = call ptr @ptr_to_node(ptr %156)
  %158 = call ptr @generate_expression__Struct_ASTNode(ptr %157)
  br label %label_1621

label_1624:                                       ; preds = %label_1633, %label_1618
  %159 = load ptr, ptr %stmt, align 8
  %160 = getelementptr inbounds nuw %ASTNode, ptr %159, i32 0, i32 0
  %161 = load i32, ptr %160, align 4
  %162 = icmp eq i32 %161, 13
  br i1 %162, label %label_1640, label %label_1642

label_1622:                                       ; preds = %label_1618
  %163 = load ptr, ptr %stmt, align 8
  %164 = getelementptr inbounds nuw %ASTNode, ptr %163, i32 0, i32 5
  %165 = load ptr, ptr %164, align 8
  %166 = call ptr @ptr_to_node(ptr %165)
  %167 = call ptr @generate_expression__Struct_ASTNode(ptr %166)
  store ptr %167, ptr %cond_val, align 8
  %168 = call i32 @ir_get_label()
  store i32 %168, ptr %then_label, align 4
  %169 = call i32 @ir_get_label()
  store i32 %169, ptr %else_label, align 4
  %170 = call i32 @ir_get_label()
  store i32 %170, ptr %end_label, align 4
  %171 = load ptr, ptr %stmt, align 8
  %172 = getelementptr inbounds nuw %ASTNode, ptr %171, i32 0, i32 7
  %173 = load ptr, ptr %172, align 8
  %174 = call i32 @str_equals(ptr %173, ptr @.str.s637)
  %175 = icmp eq i32 %174, 0
  br i1 %175, label %label_1625, label %label_1626

label_1626:                                       ; preds = %label_1622
  %176 = load ptr, ptr %cond_val, align 8
  %177 = load i32, ptr %then_label, align 4
  %178 = load i32, ptr %end_label, align 4
  call void @ir_cond_br_numbered(ptr %176, i32 %177, i32 %178)
  br label %label_1627

label_1625:                                       ; preds = %label_1622
  %179 = load ptr, ptr %cond_val, align 8
  %180 = load i32, ptr %then_label, align 4
  %181 = load i32, ptr %else_label, align 4
  call void @ir_cond_br_numbered(ptr %179, i32 %180, i32 %181)
  br label %label_1627

label_1627:                                       ; preds = %label_1626, %label_1625
  %182 = load i32, ptr %then_label, align 4
  call void @ir_label_numbered(i32 %182)
  %183 = load ptr, ptr %stmt, align 8
  %184 = getelementptr inbounds nuw %ASTNode, ptr %183, i32 0, i32 6
  %185 = load ptr, ptr %184, align 8
  %186 = call ptr @ptr_to_node(ptr %185)
  call void @generate_block__Struct_ASTNode(ptr %186)
  %187 = call i32 @ir_has_returned()
  %188 = icmp eq i32 %187, 0
  br i1 %188, label %label_1628, label %label_1630

label_1630:                                       ; preds = %label_1628, %label_1627
  call void @ir_clear_returned()
  %189 = load ptr, ptr %stmt, align 8
  %190 = getelementptr inbounds nuw %ASTNode, ptr %189, i32 0, i32 7
  %191 = load ptr, ptr %190, align 8
  %192 = call i32 @str_equals(ptr %191, ptr @.str.s638)
  %193 = icmp eq i32 %192, 0
  br i1 %193, label %label_1631, label %label_1633

label_1628:                                       ; preds = %label_1627
  %194 = load i32, ptr %end_label, align 4
  call void @ir_br_numbered(i32 %194)
  br label %label_1630

label_1633:                                       ; preds = %label_1639, %label_1630
  %195 = load i32, ptr %end_label, align 4
  call void @ir_label_numbered(i32 %195)
  br label %label_1624

label_1631:                                       ; preds = %label_1630
  %196 = load i32, ptr %else_label, align 4
  call void @ir_label_numbered(i32 %196)
  %197 = load ptr, ptr %stmt, align 8
  %198 = getelementptr inbounds nuw %ASTNode, ptr %197, i32 0, i32 7
  %199 = load ptr, ptr %198, align 8
  %200 = call ptr @ptr_to_node(ptr %199)
  store ptr %200, ptr %else_node, align 8
  %201 = load ptr, ptr %else_node, align 8
  %202 = getelementptr inbounds nuw %ASTNode, ptr %201, i32 0, i32 0
  %203 = load i32, ptr %202, align 4
  %204 = icmp eq i32 %203, 10
  br i1 %204, label %label_1634, label %label_1635

label_1635:                                       ; preds = %label_1631
  %205 = load ptr, ptr %else_node, align 8
  call void @generate_block__Struct_ASTNode(ptr %205)
  br label %label_1636

label_1634:                                       ; preds = %label_1631
  %206 = load ptr, ptr %else_node, align 8
  call void @generate_statement__Struct_ASTNode(ptr %206)
  br label %label_1636

label_1636:                                       ; preds = %label_1635, %label_1634
  %207 = call i32 @ir_has_returned()
  %208 = icmp eq i32 %207, 0
  br i1 %208, label %label_1637, label %label_1639

label_1639:                                       ; preds = %label_1637, %label_1636
  call void @ir_clear_returned()
  br label %label_1633

label_1637:                                       ; preds = %label_1636
  %209 = load i32, ptr %end_label, align 4
  call void @ir_br_numbered(i32 %209)
  br label %label_1639

label_1642:                                       ; preds = %label_1645, %label_1624
  %210 = load ptr, ptr %stmt, align 8
  %211 = getelementptr inbounds nuw %ASTNode, ptr %210, i32 0, i32 0
  %212 = load i32, ptr %211, align 4
  %213 = icmp eq i32 %212, 14
  br i1 %213, label %label_1646, label %label_1648

label_1640:                                       ; preds = %label_1624
  %214 = call i32 @ir_get_label()
  store i32 %214, ptr %cond_label, align 4
  %215 = call i32 @ir_get_label()
  store i32 %215, ptr %body_label, align 4
  %216 = call i32 @ir_get_label()
  store i32 %216, ptr %end_label, align 4
  %217 = load i32, ptr %cond_label, align 4
  call void @ir_br_numbered(i32 %217)
  %218 = load i32, ptr %cond_label, align 4
  call void @ir_label_numbered(i32 %218)
  %219 = load ptr, ptr %stmt, align 8
  %220 = getelementptr inbounds nuw %ASTNode, ptr %219, i32 0, i32 5
  %221 = load ptr, ptr %220, align 8
  %222 = call ptr @ptr_to_node(ptr %221)
  %223 = call ptr @generate_expression__Struct_ASTNode(ptr %222)
  store ptr %223, ptr %cond_val, align 8
  %224 = load ptr, ptr %cond_val, align 8
  %225 = load i32, ptr %body_label, align 4
  %226 = load i32, ptr %end_label, align 4
  call void @ir_cond_br_numbered(ptr %224, i32 %225, i32 %226)
  %227 = load i32, ptr %body_label, align 4
  call void @ir_label_numbered(i32 %227)
  %228 = load i32, ptr %cond_label, align 4
  %229 = load i32, ptr %end_label, align 4
  call void @ir_loop_push(i32 %228, i32 %229)
  %230 = load ptr, ptr %stmt, align 8
  %231 = getelementptr inbounds nuw %ASTNode, ptr %230, i32 0, i32 6
  %232 = load ptr, ptr %231, align 8
  %233 = call ptr @ptr_to_node(ptr %232)
  call void @generate_block__Struct_ASTNode(ptr %233)
  call void @ir_loop_pop()
  %234 = call i32 @ir_has_returned()
  %235 = icmp eq i32 %234, 0
  br i1 %235, label %label_1643, label %label_1645

label_1645:                                       ; preds = %label_1643, %label_1640
  call void @ir_clear_returned()
  %236 = load i32, ptr %end_label, align 4
  call void @ir_label_numbered(i32 %236)
  br label %label_1642

label_1643:                                       ; preds = %label_1640
  %237 = load i32, ptr %cond_label, align 4
  call void @ir_br_numbered(i32 %237)
  br label %label_1645

label_1648:                                       ; preds = %label_1651, %label_1642
  %238 = load ptr, ptr %stmt, align 8
  %239 = getelementptr inbounds nuw %ASTNode, ptr %238, i32 0, i32 0
  %240 = load i32, ptr %239, align 4
  %241 = icmp eq i32 %240, 12
  br i1 %241, label %label_1652, label %label_1654

label_1646:                                       ; preds = %label_1642
  %242 = call i32 @ir_get_label()
  store i32 %242, ptr %body_label, align 4
  %243 = call i32 @ir_get_label()
  store i32 %243, ptr %end_label, align 4
  %244 = load i32, ptr %body_label, align 4
  call void @ir_br_numbered(i32 %244)
  %245 = load i32, ptr %body_label, align 4
  call void @ir_label_numbered(i32 %245)
  %246 = load i32, ptr %body_label, align 4
  %247 = load i32, ptr %end_label, align 4
  call void @ir_loop_push(i32 %246, i32 %247)
  %248 = load ptr, ptr %stmt, align 8
  %249 = getelementptr inbounds nuw %ASTNode, ptr %248, i32 0, i32 5
  %250 = load ptr, ptr %249, align 8
  %251 = call ptr @ptr_to_node(ptr %250)
  call void @generate_block__Struct_ASTNode(ptr %251)
  call void @ir_loop_pop()
  %252 = call i32 @ir_has_returned()
  %253 = icmp eq i32 %252, 0
  br i1 %253, label %label_1649, label %label_1651

label_1651:                                       ; preds = %label_1649, %label_1646
  call void @ir_clear_returned()
  %254 = load i32, ptr %end_label, align 4
  call void @ir_label_numbered(i32 %254)
  br label %label_1648

label_1649:                                       ; preds = %label_1646
  %255 = load i32, ptr %body_label, align 4
  call void @ir_br_numbered(i32 %255)
  br label %label_1651

label_1654:                                       ; preds = %label_1657, %label_1648
  %256 = load ptr, ptr %stmt, align 8
  %257 = getelementptr inbounds nuw %ASTNode, ptr %256, i32 0, i32 0
  %258 = load i32, ptr %257, align 4
  %259 = icmp eq i32 %258, 18
  br i1 %259, label %label_1658, label %label_1660

label_1652:                                       ; preds = %label_1648
  %260 = load ptr, ptr %stmt, align 8
  %261 = getelementptr inbounds nuw %ASTNode, ptr %260, i32 0, i32 1
  %262 = load ptr, ptr %261, align 8
  store ptr %262, ptr %loop_var, align 8
  %263 = load ptr, ptr %stmt, align 8
  %264 = getelementptr inbounds nuw %ASTNode, ptr %263, i32 0, i32 5
  %265 = load ptr, ptr %264, align 8
  %266 = call ptr @ptr_to_node(ptr %265)
  %267 = call ptr @generate_expression__Struct_ASTNode(ptr %266)
  store ptr %267, ptr %start_val, align 8
  %268 = load ptr, ptr %start_val, align 8
  %269 = load ptr, ptr %loop_var, align 8
  call void @ir_store(ptr @.str.s639, ptr %268, ptr %269)
  %270 = call i32 @ir_get_label()
  store i32 %270, ptr %cond_label, align 4
  %271 = call i32 @ir_get_label()
  store i32 %271, ptr %body_label, align 4
  %272 = call i32 @ir_get_label()
  store i32 %272, ptr %incr_label, align 4
  %273 = call i32 @ir_get_label()
  store i32 %273, ptr %end_label, align 4
  %274 = load i32, ptr %cond_label, align 4
  call void @ir_br_numbered(i32 %274)
  %275 = load i32, ptr %cond_label, align 4
  call void @ir_label_numbered(i32 %275)
  %276 = load ptr, ptr %loop_var, align 8
  %277 = call i32 @ir_load(ptr @.str.s640, ptr %276)
  store i32 %277, ptr %iv, align 4
  %278 = load ptr, ptr %stmt, align 8
  %279 = getelementptr inbounds nuw %ASTNode, ptr %278, i32 0, i32 6
  %280 = load ptr, ptr %279, align 8
  %281 = call ptr @ptr_to_node(ptr %280)
  %282 = call ptr @generate_expression__Struct_ASTNode(ptr %281)
  store ptr %282, ptr %end_val, align 8
  %283 = load i32, ptr %iv, align 4
  %284 = call ptr @ir_get_temp_name(i32 %283)
  %285 = load ptr, ptr %end_val, align 8
  %286 = call i32 @ir_icmp_slt(ptr @.str.s641, ptr %284, ptr %285)
  store i32 %286, ptr %cmp, align 4
  %287 = load i32, ptr %cmp, align 4
  %288 = call ptr @ir_get_temp_name(i32 %287)
  %289 = load i32, ptr %body_label, align 4
  %290 = load i32, ptr %end_label, align 4
  call void @ir_cond_br_numbered(ptr %288, i32 %289, i32 %290)
  %291 = load i32, ptr %body_label, align 4
  call void @ir_label_numbered(i32 %291)
  %292 = load i32, ptr %incr_label, align 4
  %293 = load i32, ptr %end_label, align 4
  call void @ir_loop_push(i32 %292, i32 %293)
  %294 = load ptr, ptr %stmt, align 8
  %295 = getelementptr inbounds nuw %ASTNode, ptr %294, i32 0, i32 7
  %296 = load ptr, ptr %295, align 8
  %297 = call ptr @ptr_to_node(ptr %296)
  call void @generate_block__Struct_ASTNode(ptr %297)
  call void @ir_loop_pop()
  %298 = call i32 @ir_has_returned()
  %299 = icmp eq i32 %298, 0
  br i1 %299, label %label_1655, label %label_1657

label_1657:                                       ; preds = %label_1655, %label_1652
  call void @ir_clear_returned()
  %300 = load i32, ptr %incr_label, align 4
  call void @ir_label_numbered(i32 %300)
  %301 = load ptr, ptr %loop_var, align 8
  %302 = call i32 @ir_load(ptr @.str.s642, ptr %301)
  store i32 %302, ptr %iv2, align 4
  %303 = load i32, ptr %iv2, align 4
  %304 = call ptr @ir_get_temp_name(i32 %303)
  %305 = call i32 @ir_add(ptr @.str.s643, ptr %304, ptr @.str.s644)
  store i32 %305, ptr %next, align 4
  %306 = load i32, ptr %next, align 4
  %307 = call ptr @ir_get_temp_name(i32 %306)
  %308 = load ptr, ptr %loop_var, align 8
  call void @ir_store(ptr @.str.s645, ptr %307, ptr %308)
  %309 = load i32, ptr %cond_label, align 4
  call void @ir_br_numbered(i32 %309)
  %310 = load i32, ptr %end_label, align 4
  call void @ir_label_numbered(i32 %310)
  br label %label_1654

label_1655:                                       ; preds = %label_1652
  %311 = load i32, ptr %incr_label, align 4
  call void @ir_br_numbered(i32 %311)
  br label %label_1657

label_1660:                                       ; preds = %label_1663, %label_1654
  %312 = load ptr, ptr %stmt, align 8
  %313 = getelementptr inbounds nuw %ASTNode, ptr %312, i32 0, i32 0
  %314 = load i32, ptr %313, align 4
  %315 = icmp eq i32 %314, 19
  br i1 %315, label %label_1664, label %label_1666

label_1658:                                       ; preds = %label_1654
  %316 = call i32 @ir_loop_break_label()
  store i32 %316, ptr %target, align 4
  %317 = load i32, ptr %target, align 4
  %318 = icmp sge i32 %317, 0
  br i1 %318, label %label_1661, label %label_1663

label_1663:                                       ; preds = %label_1661, %label_1658
  br label %label_1660

label_1661:                                       ; preds = %label_1658
  %319 = load i32, ptr %target, align 4
  call void @ir_br_numbered(i32 %319)
  call void @ir_set_returned()
  br label %label_1663

label_1666:                                       ; preds = %label_1669, %label_1660
  %320 = load ptr, ptr %stmt, align 8
  %321 = getelementptr inbounds nuw %ASTNode, ptr %320, i32 0, i32 0
  %322 = load i32, ptr %321, align 4
  %323 = icmp eq i32 %322, 11
  br i1 %323, label %label_1670, label %label_1672

label_1664:                                       ; preds = %label_1660
  %324 = call i32 @ir_loop_continue_label()
  store i32 %324, ptr %target, align 4
  %325 = load i32, ptr %target, align 4
  %326 = icmp sge i32 %325, 0
  br i1 %326, label %label_1667, label %label_1669

label_1669:                                       ; preds = %label_1667, %label_1664
  br label %label_1666

label_1667:                                       ; preds = %label_1664
  %327 = load i32, ptr %target, align 4
  call void @ir_br_numbered(i32 %327)
  call void @ir_set_returned()
  br label %label_1669

label_1672:                                       ; preds = %label_1687, %label_1666
  ret void

label_1670:                                       ; preds = %label_1666
  %328 = load ptr, ptr %stmt, align 8
  %329 = getelementptr inbounds nuw %ASTNode, ptr %328, i32 0, i32 5
  %330 = load ptr, ptr %329, align 8
  %331 = call ptr @ptr_to_node(ptr %330)
  %332 = call ptr @generate_expression__Struct_ASTNode(ptr %331)
  store ptr %332, ptr %scrut_val, align 8
  %333 = load ptr, ptr %stmt, align 8
  %334 = getelementptr inbounds nuw %ASTNode, ptr %333, i32 0, i32 5
  %335 = load ptr, ptr %334, align 8
  %336 = call ptr @ptr_to_node(ptr %335)
  %337 = call ptr @get_expr_type__Struct_ASTNode(ptr %336)
  store ptr %337, ptr %scrut_type, align 8
  %338 = call i32 @ir_get_label()
  store i32 %338, ptr %end_label, align 4
  store i1 true, ptr %needs_final_br, align 1
  %339 = load ptr, ptr %stmt, align 8
  %340 = getelementptr inbounds nuw %ASTNode, ptr %339, i32 0, i32 6
  %341 = load ptr, ptr %340, align 8
  store ptr %341, ptr %arm_ptr, align 8
  br label %label_1673

label_1673:                                       ; preds = %label_1678, %label_1670
  %342 = load ptr, ptr %arm_ptr, align 8
  %343 = call i32 @str_equals(ptr %342, ptr @.str.s646)
  %344 = icmp eq i32 %343, 0
  br i1 %344, label %label_1674, label %label_1675

label_1675:                                       ; preds = %label_1673
  %345 = load i1, ptr %needs_final_br, align 1
  br i1 %345, label %label_1685, label %label_1687

label_1674:                                       ; preds = %label_1673
  %346 = load ptr, ptr %arm_ptr, align 8
  %347 = call ptr @ptr_to_node(ptr %346)
  store ptr %347, ptr %arm, align 8
  %348 = load ptr, ptr %arm, align 8
  %349 = getelementptr inbounds nuw %ASTNode, ptr %348, i32 0, i32 1
  %350 = load ptr, ptr %349, align 8
  %351 = call i32 @str_equals(ptr %350, ptr @.str.s647)
  %352 = icmp eq i32 %351, 1
  br i1 %352, label %label_1676, label %label_1677

label_1677:                                       ; preds = %label_1674
  %353 = load ptr, ptr %arm, align 8
  %354 = getelementptr inbounds nuw %ASTNode, ptr %353, i32 0, i32 5
  %355 = load ptr, ptr %354, align 8
  %356 = call ptr @ptr_to_node(ptr %355)
  %357 = call ptr @generate_expression__Struct_ASTNode(ptr %356)
  store ptr %357, ptr %pat_val, align 8
  %358 = load ptr, ptr %scrut_type, align 8
  %359 = load ptr, ptr %scrut_val, align 8
  %360 = load ptr, ptr %pat_val, align 8
  %361 = call i32 @ir_icmp_eq(ptr %358, ptr %359, ptr %360)
  store i32 %361, ptr %cmp, align 4
  %362 = call i32 @ir_get_label()
  store i32 %362, ptr %arm_label, align 4
  %363 = call i32 @ir_get_label()
  store i32 %363, ptr %next_label, align 4
  %364 = load i32, ptr %cmp, align 4
  %365 = call ptr @ir_get_temp_name(i32 %364)
  %366 = load i32, ptr %arm_label, align 4
  %367 = load i32, ptr %next_label, align 4
  call void @ir_cond_br_numbered(ptr %365, i32 %366, i32 %367)
  %368 = load i32, ptr %arm_label, align 4
  call void @ir_label_numbered(i32 %368)
  %369 = load ptr, ptr %arm, align 8
  %370 = getelementptr inbounds nuw %ASTNode, ptr %369, i32 0, i32 6
  %371 = load ptr, ptr %370, align 8
  %372 = call ptr @ptr_to_node(ptr %371)
  call void @generate_block__Struct_ASTNode(ptr %372)
  %373 = call i32 @ir_has_returned()
  %374 = icmp eq i32 %373, 0
  br i1 %374, label %label_1682, label %label_1684

label_1676:                                       ; preds = %label_1674
  %375 = load ptr, ptr %arm, align 8
  %376 = getelementptr inbounds nuw %ASTNode, ptr %375, i32 0, i32 6
  %377 = load ptr, ptr %376, align 8
  %378 = call ptr @ptr_to_node(ptr %377)
  call void @generate_block__Struct_ASTNode(ptr %378)
  %379 = call i32 @ir_has_returned()
  %380 = icmp eq i32 %379, 0
  br i1 %380, label %label_1679, label %label_1681

label_1681:                                       ; preds = %label_1679, %label_1676
  call void @ir_clear_returned()
  store i1 false, ptr %needs_final_br, align 1
  br label %label_1678

label_1679:                                       ; preds = %label_1676
  %381 = load i32, ptr %end_label, align 4
  call void @ir_br_numbered(i32 %381)
  br label %label_1681

label_1678:                                       ; preds = %label_1684, %label_1681
  %382 = load ptr, ptr %arm, align 8
  %383 = getelementptr inbounds nuw %ASTNode, ptr %382, i32 0, i32 8
  %384 = load ptr, ptr %383, align 8
  store ptr %384, ptr %arm_ptr, align 8
  br label %label_1673

label_1684:                                       ; preds = %label_1682, %label_1677
  call void @ir_clear_returned()
  %385 = load i32, ptr %next_label, align 4
  call void @ir_label_numbered(i32 %385)
  store i1 true, ptr %needs_final_br, align 1
  br label %label_1678

label_1682:                                       ; preds = %label_1677
  %386 = load i32, ptr %end_label, align 4
  call void @ir_br_numbered(i32 %386)
  br label %label_1684

label_1687:                                       ; preds = %label_1685, %label_1675
  %387 = load i32, ptr %end_label, align 4
  call void @ir_label_numbered(i32 %387)
  br label %label_1672

label_1685:                                       ; preds = %label_1675
  %388 = load i32, ptr %end_label, align 4
  call void @ir_br_numbered(i32 %388)
  br label %label_1687
}

define void @generate_block__Struct_ASTNode(ptr %0) {
entry:
  %block = alloca ptr, align 8
  store ptr %0, ptr %block, align 8
  %stmt_ptr = alloca ptr, align 8
  %stmt = alloca ptr, align 8
  %1 = load ptr, ptr %block, align 8
  %2 = getelementptr inbounds nuw %ASTNode, ptr %1, i32 0, i32 5
  %3 = load ptr, ptr %2, align 8
  store ptr %3, ptr %stmt_ptr, align 8
  br label %label_1688

label_1688:                                       ; preds = %label_1689, %entry
  %4 = load ptr, ptr %stmt_ptr, align 8
  %5 = call i32 @str_equals(ptr %4, ptr @.str.s648)
  %6 = icmp eq i32 %5, 0
  br i1 %6, label %label_1689, label %label_1690

label_1690:                                       ; preds = %label_1688
  ret void

label_1689:                                       ; preds = %label_1688
  %7 = load ptr, ptr %stmt_ptr, align 8
  %8 = call ptr @ptr_to_node(ptr %7)
  store ptr %8, ptr %stmt, align 8
  %9 = load ptr, ptr %stmt, align 8
  call void @generate_statement__Struct_ASTNode(ptr %9)
  %10 = load ptr, ptr %stmt, align 8
  %11 = getelementptr inbounds nuw %ASTNode, ptr %10, i32 0, i32 8
  %12 = load ptr, ptr %11, align 8
  store ptr %12, ptr %stmt_ptr, align 8
  br label %label_1688
}

define ptr @get_variable_decl_type__Struct_ASTNode(ptr %0) {
entry:
  %stmt = alloca ptr, align 8
  store ptr %0, ptr %stmt, align 8
  %var_type = alloca ptr, align 8
  %type_node = alloca ptr, align 8
  store ptr @.str.s649, ptr %var_type, align 8
  %1 = load ptr, ptr %stmt, align 8
  %2 = getelementptr inbounds nuw %ASTNode, ptr %1, i32 0, i32 5
  %3 = load ptr, ptr %2, align 8
  %4 = call i32 @str_equals(ptr %3, ptr @.str.s650)
  %5 = icmp eq i32 %4, 0
  br i1 %5, label %label_1691, label %label_1692

label_1692:                                       ; preds = %entry
  %6 = load ptr, ptr %stmt, align 8
  %7 = getelementptr inbounds nuw %ASTNode, ptr %6, i32 0, i32 6
  %8 = load ptr, ptr %7, align 8
  %9 = call i32 @str_equals(ptr %8, ptr @.str.s651)
  %10 = icmp eq i32 %9, 0
  br i1 %10, label %label_1694, label %label_1696

label_1691:                                       ; preds = %entry
  %11 = load ptr, ptr %stmt, align 8
  %12 = getelementptr inbounds nuw %ASTNode, ptr %11, i32 0, i32 5
  %13 = load ptr, ptr %12, align 8
  %14 = call ptr @ptr_to_node(ptr %13)
  store ptr %14, ptr %type_node, align 8
  %15 = load ptr, ptr %type_node, align 8
  %16 = call ptr @map_type_node__Struct_ASTNode(ptr %15)
  store ptr %16, ptr %var_type, align 8
  br label %label_1693

label_1693:                                       ; preds = %label_1696, %label_1691
  %17 = load ptr, ptr %var_type, align 8
  ret ptr %17

label_1696:                                       ; preds = %label_1694, %label_1692
  br label %label_1693

label_1694:                                       ; preds = %label_1692
  %18 = load ptr, ptr %stmt, align 8
  %19 = getelementptr inbounds nuw %ASTNode, ptr %18, i32 0, i32 6
  %20 = load ptr, ptr %19, align 8
  %21 = call ptr @ptr_to_node(ptr %20)
  %22 = call ptr @get_expr_type__Struct_ASTNode(ptr %21)
  store ptr %22, ptr %var_type, align 8
  br label %label_1696
}

define void @predeclare_locals_stmt__Struct_ASTNode(ptr %0) {
entry:
  %stmt = alloca ptr, align 8
  store ptr %0, ptr %stmt, align 8
  %var_type = alloca ptr, align 8
  %else_node = alloca ptr, align 8
  %arm_ptr = alloca ptr, align 8
  %arm = alloca ptr, align 8
  %1 = load ptr, ptr %stmt, align 8
  %2 = getelementptr inbounds nuw %ASTNode, ptr %1, i32 0, i32 0
  %3 = load i32, ptr %2, align 4
  %4 = icmp eq i32 %3, 3
  br i1 %4, label %label_1697, label %label_1699

label_1699:                                       ; preds = %label_1697, %entry
  %5 = load ptr, ptr %stmt, align 8
  %6 = getelementptr inbounds nuw %ASTNode, ptr %5, i32 0, i32 0
  %7 = load i32, ptr %6, align 4
  %8 = icmp eq i32 %7, 10
  br i1 %8, label %label_1700, label %label_1702

label_1697:                                       ; preds = %entry
  %9 = load ptr, ptr %stmt, align 8
  %10 = call ptr @get_variable_decl_type__Struct_ASTNode(ptr %9)
  store ptr %10, ptr %var_type, align 8
  %11 = load ptr, ptr %stmt, align 8
  %12 = getelementptr inbounds nuw %ASTNode, ptr %11, i32 0, i32 1
  %13 = load ptr, ptr %12, align 8
  %14 = load ptr, ptr %var_type, align 8
  call void @ir_set_var_type(ptr %13, ptr %14)
  %15 = load ptr, ptr %var_type, align 8
  %16 = call ptr @storage_type__String(ptr %15)
  %17 = load ptr, ptr %stmt, align 8
  %18 = getelementptr inbounds nuw %ASTNode, ptr %17, i32 0, i32 1
  %19 = load ptr, ptr %18, align 8
  %20 = call i32 @ir_alloca(ptr %16, ptr %19)
  br label %label_1699

label_1702:                                       ; preds = %label_1708, %label_1699
  %21 = load ptr, ptr %stmt, align 8
  %22 = getelementptr inbounds nuw %ASTNode, ptr %21, i32 0, i32 0
  %23 = load i32, ptr %22, align 4
  %24 = icmp eq i32 %23, 13
  br i1 %24, label %label_1712, label %label_1714

label_1700:                                       ; preds = %label_1699
  %25 = load ptr, ptr %stmt, align 8
  %26 = getelementptr inbounds nuw %ASTNode, ptr %25, i32 0, i32 6
  %27 = load ptr, ptr %26, align 8
  %28 = call i32 @str_equals(ptr %27, ptr @.str.s652)
  %29 = icmp eq i32 %28, 0
  br i1 %29, label %label_1703, label %label_1705

label_1705:                                       ; preds = %label_1703, %label_1700
  %30 = load ptr, ptr %stmt, align 8
  %31 = getelementptr inbounds nuw %ASTNode, ptr %30, i32 0, i32 7
  %32 = load ptr, ptr %31, align 8
  %33 = call i32 @str_equals(ptr %32, ptr @.str.s653)
  %34 = icmp eq i32 %33, 0
  br i1 %34, label %label_1706, label %label_1708

label_1703:                                       ; preds = %label_1700
  %35 = load ptr, ptr %stmt, align 8
  %36 = getelementptr inbounds nuw %ASTNode, ptr %35, i32 0, i32 6
  %37 = load ptr, ptr %36, align 8
  %38 = call ptr @ptr_to_node(ptr %37)
  call void @predeclare_locals_block__Struct_ASTNode(ptr %38)
  br label %label_1705

label_1708:                                       ; preds = %label_1711, %label_1705
  br label %label_1702

label_1706:                                       ; preds = %label_1705
  %39 = load ptr, ptr %stmt, align 8
  %40 = getelementptr inbounds nuw %ASTNode, ptr %39, i32 0, i32 7
  %41 = load ptr, ptr %40, align 8
  %42 = call ptr @ptr_to_node(ptr %41)
  store ptr %42, ptr %else_node, align 8
  %43 = load ptr, ptr %else_node, align 8
  %44 = getelementptr inbounds nuw %ASTNode, ptr %43, i32 0, i32 0
  %45 = load i32, ptr %44, align 4
  %46 = icmp eq i32 %45, 9
  br i1 %46, label %label_1709, label %label_1710

label_1710:                                       ; preds = %label_1706
  %47 = load ptr, ptr %else_node, align 8
  call void @predeclare_locals_stmt__Struct_ASTNode(ptr %47)
  br label %label_1711

label_1709:                                       ; preds = %label_1706
  %48 = load ptr, ptr %else_node, align 8
  call void @predeclare_locals_block__Struct_ASTNode(ptr %48)
  br label %label_1711

label_1711:                                       ; preds = %label_1710, %label_1709
  br label %label_1708

label_1714:                                       ; preds = %label_1717, %label_1702
  %49 = load ptr, ptr %stmt, align 8
  %50 = getelementptr inbounds nuw %ASTNode, ptr %49, i32 0, i32 0
  %51 = load i32, ptr %50, align 4
  %52 = icmp eq i32 %51, 14
  br i1 %52, label %label_1718, label %label_1720

label_1712:                                       ; preds = %label_1702
  %53 = load ptr, ptr %stmt, align 8
  %54 = getelementptr inbounds nuw %ASTNode, ptr %53, i32 0, i32 6
  %55 = load ptr, ptr %54, align 8
  %56 = call i32 @str_equals(ptr %55, ptr @.str.s654)
  %57 = icmp eq i32 %56, 0
  br i1 %57, label %label_1715, label %label_1717

label_1717:                                       ; preds = %label_1715, %label_1712
  br label %label_1714

label_1715:                                       ; preds = %label_1712
  %58 = load ptr, ptr %stmt, align 8
  %59 = getelementptr inbounds nuw %ASTNode, ptr %58, i32 0, i32 6
  %60 = load ptr, ptr %59, align 8
  %61 = call ptr @ptr_to_node(ptr %60)
  call void @predeclare_locals_block__Struct_ASTNode(ptr %61)
  br label %label_1717

label_1720:                                       ; preds = %label_1723, %label_1714
  %62 = load ptr, ptr %stmt, align 8
  %63 = getelementptr inbounds nuw %ASTNode, ptr %62, i32 0, i32 0
  %64 = load i32, ptr %63, align 4
  %65 = icmp eq i32 %64, 12
  br i1 %65, label %label_1724, label %label_1726

label_1718:                                       ; preds = %label_1714
  %66 = load ptr, ptr %stmt, align 8
  %67 = getelementptr inbounds nuw %ASTNode, ptr %66, i32 0, i32 5
  %68 = load ptr, ptr %67, align 8
  %69 = call i32 @str_equals(ptr %68, ptr @.str.s655)
  %70 = icmp eq i32 %69, 0
  br i1 %70, label %label_1721, label %label_1723

label_1723:                                       ; preds = %label_1721, %label_1718
  br label %label_1720

label_1721:                                       ; preds = %label_1718
  %71 = load ptr, ptr %stmt, align 8
  %72 = getelementptr inbounds nuw %ASTNode, ptr %71, i32 0, i32 5
  %73 = load ptr, ptr %72, align 8
  %74 = call ptr @ptr_to_node(ptr %73)
  call void @predeclare_locals_block__Struct_ASTNode(ptr %74)
  br label %label_1723

label_1726:                                       ; preds = %label_1729, %label_1720
  %75 = load ptr, ptr %stmt, align 8
  %76 = getelementptr inbounds nuw %ASTNode, ptr %75, i32 0, i32 0
  %77 = load i32, ptr %76, align 4
  %78 = icmp eq i32 %77, 11
  br i1 %78, label %label_1730, label %label_1732

label_1724:                                       ; preds = %label_1720
  %79 = load ptr, ptr %stmt, align 8
  %80 = getelementptr inbounds nuw %ASTNode, ptr %79, i32 0, i32 1
  %81 = load ptr, ptr %80, align 8
  call void @ir_set_var_type(ptr %81, ptr @.str.s656)
  %82 = load ptr, ptr %stmt, align 8
  %83 = getelementptr inbounds nuw %ASTNode, ptr %82, i32 0, i32 1
  %84 = load ptr, ptr %83, align 8
  %85 = call i32 @ir_alloca(ptr @.str.s657, ptr %84)
  %86 = load ptr, ptr %stmt, align 8
  %87 = getelementptr inbounds nuw %ASTNode, ptr %86, i32 0, i32 7
  %88 = load ptr, ptr %87, align 8
  %89 = call i32 @str_equals(ptr %88, ptr @.str.s658)
  %90 = icmp eq i32 %89, 0
  br i1 %90, label %label_1727, label %label_1729

label_1729:                                       ; preds = %label_1727, %label_1724
  br label %label_1726

label_1727:                                       ; preds = %label_1724
  %91 = load ptr, ptr %stmt, align 8
  %92 = getelementptr inbounds nuw %ASTNode, ptr %91, i32 0, i32 7
  %93 = load ptr, ptr %92, align 8
  %94 = call ptr @ptr_to_node(ptr %93)
  call void @predeclare_locals_block__Struct_ASTNode(ptr %94)
  br label %label_1729

label_1732:                                       ; preds = %label_1735, %label_1726
  ret void

label_1730:                                       ; preds = %label_1726
  %95 = load ptr, ptr %stmt, align 8
  %96 = getelementptr inbounds nuw %ASTNode, ptr %95, i32 0, i32 6
  %97 = load ptr, ptr %96, align 8
  store ptr %97, ptr %arm_ptr, align 8
  br label %label_1733

label_1733:                                       ; preds = %label_1738, %label_1730
  %98 = load ptr, ptr %arm_ptr, align 8
  %99 = call i32 @str_equals(ptr %98, ptr @.str.s659)
  %100 = icmp eq i32 %99, 0
  br i1 %100, label %label_1734, label %label_1735

label_1735:                                       ; preds = %label_1733
  br label %label_1732

label_1734:                                       ; preds = %label_1733
  %101 = load ptr, ptr %arm_ptr, align 8
  %102 = call ptr @ptr_to_node(ptr %101)
  store ptr %102, ptr %arm, align 8
  %103 = load ptr, ptr %arm, align 8
  %104 = getelementptr inbounds nuw %ASTNode, ptr %103, i32 0, i32 6
  %105 = load ptr, ptr %104, align 8
  %106 = call i32 @str_equals(ptr %105, ptr @.str.s660)
  %107 = icmp eq i32 %106, 0
  br i1 %107, label %label_1736, label %label_1738

label_1738:                                       ; preds = %label_1736, %label_1734
  %108 = load ptr, ptr %arm, align 8
  %109 = getelementptr inbounds nuw %ASTNode, ptr %108, i32 0, i32 8
  %110 = load ptr, ptr %109, align 8
  store ptr %110, ptr %arm_ptr, align 8
  br label %label_1733

label_1736:                                       ; preds = %label_1734
  %111 = load ptr, ptr %arm, align 8
  %112 = getelementptr inbounds nuw %ASTNode, ptr %111, i32 0, i32 6
  %113 = load ptr, ptr %112, align 8
  %114 = call ptr @ptr_to_node(ptr %113)
  call void @predeclare_locals_block__Struct_ASTNode(ptr %114)
  br label %label_1738
}

define void @predeclare_locals_block__Struct_ASTNode(ptr %0) {
entry:
  %block = alloca ptr, align 8
  store ptr %0, ptr %block, align 8
  %stmt_ptr = alloca ptr, align 8
  %stmt = alloca ptr, align 8
  %1 = load ptr, ptr %block, align 8
  %2 = getelementptr inbounds nuw %ASTNode, ptr %1, i32 0, i32 5
  %3 = load ptr, ptr %2, align 8
  store ptr %3, ptr %stmt_ptr, align 8
  br label %label_1739

label_1739:                                       ; preds = %label_1740, %entry
  %4 = load ptr, ptr %stmt_ptr, align 8
  %5 = call i32 @str_equals(ptr %4, ptr @.str.s661)
  %6 = icmp eq i32 %5, 0
  br i1 %6, label %label_1740, label %label_1741

label_1741:                                       ; preds = %label_1739
  ret void

label_1740:                                       ; preds = %label_1739
  %7 = load ptr, ptr %stmt_ptr, align 8
  %8 = call ptr @ptr_to_node(ptr %7)
  store ptr %8, ptr %stmt, align 8
  %9 = load ptr, ptr %stmt, align 8
  call void @predeclare_locals_stmt__Struct_ASTNode(ptr %9)
  %10 = load ptr, ptr %stmt, align 8
  %11 = getelementptr inbounds nuw %ASTNode, ptr %10, i32 0, i32 8
  %12 = load ptr, ptr %11, align 8
  store ptr %12, ptr %stmt_ptr, align 8
  br label %label_1739
}

define void @generate_function__Struct_ASTNode(ptr %0) {
entry:
  %func = alloca ptr, align 8
  store ptr %0, ptr %func, align 8
  %func_name = alloca ptr, align 8
  %emitted_name = alloca ptr, align 8
  %ret_type = alloca ptr, align 8
  %ret_node = alloca ptr, align 8
  %is_main = alloca i32, align 4
  %ret_sig_type = alloca ptr, align 8
  %param_ptr = alloca ptr, align 8
  %param_node = alloca ptr, align 8
  %p_type_node = alloca ptr, align 8
  %param_ptr2 = alloca ptr, align 8
  %p_type_str = alloca ptr, align 8
  %p_store_type = alloca ptr, align 8
  %1 = load ptr, ptr %func, align 8
  %2 = getelementptr inbounds nuw %ASTNode, ptr %1, i32 0, i32 1
  %3 = load ptr, ptr %2, align 8
  store ptr %3, ptr %func_name, align 8
  %4 = load ptr, ptr %func, align 8
  %5 = call ptr @function_symbol_name__Struct_ASTNode(ptr %4)
  store ptr %5, ptr %emitted_name, align 8
  store ptr @.str.s662, ptr %ret_type, align 8
  %6 = load ptr, ptr %func, align 8
  %7 = getelementptr inbounds nuw %ASTNode, ptr %6, i32 0, i32 7
  %8 = load ptr, ptr %7, align 8
  %9 = call i32 @str_equals(ptr %8, ptr @.str.s663)
  %10 = icmp eq i32 %9, 0
  br i1 %10, label %label_1742, label %label_1744

label_1744:                                       ; preds = %label_1742, %entry
  store i32 0, ptr %is_main, align 4
  %11 = load ptr, ptr %func_name, align 8
  %12 = call i32 @str_equals(ptr %11, ptr @.str.s664)
  %13 = icmp eq i32 %12, 1
  br i1 %13, label %label_1745, label %label_1747

label_1742:                                       ; preds = %entry
  %14 = load ptr, ptr %func, align 8
  %15 = getelementptr inbounds nuw %ASTNode, ptr %14, i32 0, i32 7
  %16 = load ptr, ptr %15, align 8
  %17 = call ptr @ptr_to_node(ptr %16)
  store ptr %17, ptr %ret_node, align 8
  %18 = load ptr, ptr %ret_node, align 8
  %19 = call ptr @map_type_node__Struct_ASTNode(ptr %18)
  store ptr %19, ptr %ret_type, align 8
  br label %label_1744

label_1747:                                       ; preds = %label_1745, %label_1744
  %20 = load ptr, ptr %ret_type, align 8
  %21 = call ptr @storage_type__String(ptr %20)
  store ptr %21, ptr %ret_sig_type, align 8
  %22 = load ptr, ptr %emitted_name, align 8
  %23 = load ptr, ptr %ret_sig_type, align 8
  call void @ir_function_begin(ptr %22, ptr %23)
  %24 = load i32, ptr %is_main, align 4
  %25 = icmp eq i32 %24, 1
  br i1 %25, label %label_1748, label %label_1750

label_1745:                                       ; preds = %label_1744
  store ptr @.str.s665, ptr %ret_type, align 8
  store i32 1, ptr %is_main, align 4
  br label %label_1747

label_1750:                                       ; preds = %label_1748, %label_1747
  %26 = load ptr, ptr %func, align 8
  %27 = getelementptr inbounds nuw %ASTNode, ptr %26, i32 0, i32 5
  %28 = load ptr, ptr %27, align 8
  store ptr %28, ptr %param_ptr, align 8
  br label %label_1751

label_1748:                                       ; preds = %label_1747
  call void @ir_function_param(ptr @.str.s666, ptr @.str.s667)
  call void @ir_function_param(ptr @.str.s668, ptr @.str.s669)
  br label %label_1750

label_1751:                                       ; preds = %label_1752, %label_1750
  %29 = load ptr, ptr %param_ptr, align 8
  %30 = call i32 @str_equals(ptr %29, ptr @.str.s670)
  %31 = icmp eq i32 %30, 0
  br i1 %31, label %label_1752, label %label_1753

label_1753:                                       ; preds = %label_1751
  call void @ir_function_body_start()
  call void @ir_clear_local_var_types()
  call void @ir_clear_returned()
  %32 = load i32, ptr %is_main, align 4
  %33 = icmp eq i32 %32, 1
  br i1 %33, label %label_1754, label %label_1756

label_1752:                                       ; preds = %label_1751
  %34 = load ptr, ptr %param_ptr, align 8
  %35 = call ptr @ptr_to_node(ptr %34)
  store ptr %35, ptr %param_node, align 8
  %36 = load ptr, ptr %param_node, align 8
  %37 = getelementptr inbounds nuw %ASTNode, ptr %36, i32 0, i32 5
  %38 = load ptr, ptr %37, align 8
  %39 = call ptr @ptr_to_node(ptr %38)
  store ptr %39, ptr %p_type_node, align 8
  %40 = load ptr, ptr %p_type_node, align 8
  %41 = call ptr @map_type_node__Struct_ASTNode(ptr %40)
  %42 = call ptr @storage_type__String(ptr %41)
  %43 = load ptr, ptr %param_node, align 8
  %44 = getelementptr inbounds nuw %ASTNode, ptr %43, i32 0, i32 1
  %45 = load ptr, ptr %44, align 8
  %46 = call ptr @str_concat(ptr @.str.s671, ptr %45)
  call void @ir_function_param(ptr %42, ptr %46)
  %47 = load ptr, ptr %param_node, align 8
  %48 = getelementptr inbounds nuw %ASTNode, ptr %47, i32 0, i32 8
  %49 = load ptr, ptr %48, align 8
  store ptr %49, ptr %param_ptr, align 8
  br label %label_1751

label_1756:                                       ; preds = %label_1754, %label_1753
  %50 = load ptr, ptr %func, align 8
  %51 = getelementptr inbounds nuw %ASTNode, ptr %50, i32 0, i32 5
  %52 = load ptr, ptr %51, align 8
  store ptr %52, ptr %param_ptr2, align 8
  br label %label_1757

label_1754:                                       ; preds = %label_1753
  call void @ir_store_global(ptr @.str.s672, ptr @.str.s673, ptr @.str.s674)
  call void @ir_store_global(ptr @.str.s675, ptr @.str.s676, ptr @.str.s677)
  br label %label_1756

label_1757:                                       ; preds = %label_1758, %label_1756
  %53 = load ptr, ptr %param_ptr2, align 8
  %54 = call i32 @str_equals(ptr %53, ptr @.str.s678)
  %55 = icmp eq i32 %54, 0
  br i1 %55, label %label_1758, label %label_1759

label_1759:                                       ; preds = %label_1757
  %56 = load ptr, ptr %func, align 8
  %57 = getelementptr inbounds nuw %ASTNode, ptr %56, i32 0, i32 6
  %58 = load ptr, ptr %57, align 8
  %59 = call i32 @str_equals(ptr %58, ptr @.str.s680)
  %60 = icmp eq i32 %59, 0
  br i1 %60, label %label_1760, label %label_1762

label_1758:                                       ; preds = %label_1757
  %61 = load ptr, ptr %param_ptr2, align 8
  %62 = call ptr @ptr_to_node(ptr %61)
  store ptr %62, ptr %param_node, align 8
  %63 = load ptr, ptr %param_node, align 8
  %64 = getelementptr inbounds nuw %ASTNode, ptr %63, i32 0, i32 5
  %65 = load ptr, ptr %64, align 8
  %66 = call ptr @ptr_to_node(ptr %65)
  store ptr %66, ptr %p_type_node, align 8
  %67 = load ptr, ptr %p_type_node, align 8
  %68 = call ptr @map_type_node__Struct_ASTNode(ptr %67)
  store ptr %68, ptr %p_type_str, align 8
  %69 = load ptr, ptr %p_type_str, align 8
  %70 = call ptr @storage_type__String(ptr %69)
  store ptr %70, ptr %p_store_type, align 8
  %71 = load ptr, ptr %param_node, align 8
  %72 = getelementptr inbounds nuw %ASTNode, ptr %71, i32 0, i32 1
  %73 = load ptr, ptr %72, align 8
  %74 = load ptr, ptr %p_type_str, align 8
  call void @ir_set_var_type(ptr %73, ptr %74)
  %75 = load ptr, ptr %p_store_type, align 8
  %76 = load ptr, ptr %param_node, align 8
  %77 = getelementptr inbounds nuw %ASTNode, ptr %76, i32 0, i32 1
  %78 = load ptr, ptr %77, align 8
  %79 = call i32 @ir_alloca(ptr %75, ptr %78)
  %80 = load ptr, ptr %p_store_type, align 8
  %81 = load ptr, ptr %param_node, align 8
  %82 = getelementptr inbounds nuw %ASTNode, ptr %81, i32 0, i32 1
  %83 = load ptr, ptr %82, align 8
  %84 = call ptr @str_concat(ptr @.str.s679, ptr %83)
  %85 = load ptr, ptr %param_node, align 8
  %86 = getelementptr inbounds nuw %ASTNode, ptr %85, i32 0, i32 1
  %87 = load ptr, ptr %86, align 8
  call void @ir_store(ptr %80, ptr %84, ptr %87)
  %88 = load ptr, ptr %param_node, align 8
  %89 = getelementptr inbounds nuw %ASTNode, ptr %88, i32 0, i32 8
  %90 = load ptr, ptr %89, align 8
  store ptr %90, ptr %param_ptr2, align 8
  br label %label_1757

label_1762:                                       ; preds = %label_1760, %label_1759
  %91 = load ptr, ptr %func, align 8
  %92 = getelementptr inbounds nuw %ASTNode, ptr %91, i32 0, i32 6
  %93 = load ptr, ptr %92, align 8
  %94 = call i32 @str_equals(ptr %93, ptr @.str.s681)
  %95 = icmp eq i32 %94, 0
  br i1 %95, label %label_1763, label %label_1765

label_1760:                                       ; preds = %label_1759
  %96 = load ptr, ptr %func, align 8
  %97 = getelementptr inbounds nuw %ASTNode, ptr %96, i32 0, i32 6
  %98 = load ptr, ptr %97, align 8
  %99 = call ptr @ptr_to_node(ptr %98)
  call void @predeclare_locals_block__Struct_ASTNode(ptr %99)
  br label %label_1762

label_1765:                                       ; preds = %label_1763, %label_1762
  %100 = call i32 @ir_has_returned()
  %101 = icmp eq i32 %100, 0
  br i1 %101, label %label_1766, label %label_1768

label_1763:                                       ; preds = %label_1762
  %102 = load ptr, ptr %func, align 8
  %103 = getelementptr inbounds nuw %ASTNode, ptr %102, i32 0, i32 6
  %104 = load ptr, ptr %103, align 8
  %105 = call ptr @ptr_to_node(ptr %104)
  call void @generate_block__Struct_ASTNode(ptr %105)
  br label %label_1765

label_1768:                                       ; preds = %label_1771, %label_1765
  call void @ir_function_end()
  ret void

label_1766:                                       ; preds = %label_1765
  %106 = load ptr, ptr %ret_sig_type, align 8
  %107 = call i32 @str_equals(ptr %106, ptr @.str.s682)
  %108 = icmp eq i32 %107, 1
  br i1 %108, label %label_1769, label %label_1770

label_1770:                                       ; preds = %label_1766
  %109 = load i32, ptr %is_main, align 4
  %110 = icmp eq i32 %109, 1
  br i1 %110, label %label_1772, label %label_1773

label_1769:                                       ; preds = %label_1766
  call void @ir_ret_void()
  br label %label_1771

label_1771:                                       ; preds = %label_1774, %label_1769
  br label %label_1768

label_1773:                                       ; preds = %label_1770
  %111 = load ptr, ptr %ret_sig_type, align 8
  call void @ir_ret(ptr %111, ptr @.str.s685)
  br label %label_1774

label_1772:                                       ; preds = %label_1770
  call void @ir_ret(ptr @.str.s683, ptr @.str.s684)
  br label %label_1774

label_1774:                                       ; preds = %label_1773, %label_1772
  br label %label_1771
}

define void @collect_strings_expr__Struct_ASTNode(ptr %0) {
entry:
  %expr = alloca ptr, align 8
  store ptr %0, ptr %expr, align 8
  %str_name = alloca ptr, align 8
  %arg_ptr = alloca ptr, align 8
  %arg_node = alloca ptr, align 8
  %elem_ptr = alloca ptr, align 8
  %elem_node = alloca ptr, align 8
  %field_ptr = alloca ptr, align 8
  %field = alloca ptr, align 8
  %1 = load ptr, ptr %expr, align 8
  %2 = getelementptr inbounds nuw %ASTNode, ptr %1, i32 0, i32 0
  %3 = load i32, ptr %2, align 4
  %4 = icmp eq i32 %3, 22
  br i1 %4, label %label_1775, label %label_1777

label_1777:                                       ; preds = %label_1780, %entry
  %sc.88 = alloca i1, align 1
  %5 = load ptr, ptr %expr, align 8
  %6 = getelementptr inbounds nuw %ASTNode, ptr %5, i32 0, i32 0
  %7 = load i32, ptr %6, align 4
  %8 = icmp eq i32 %7, 21
  store i1 %8, ptr %sc.88, align 1
  br i1 %8, label %label_1782, label %label_1781

label_1775:                                       ; preds = %entry
  %9 = load ptr, ptr %expr, align 8
  %10 = getelementptr inbounds nuw %ASTNode, ptr %9, i32 0, i32 3
  %11 = load i32, ptr %10, align 4
  %12 = icmp eq i32 %11, 0
  br i1 %12, label %label_1778, label %label_1780

label_1780:                                       ; preds = %label_1778, %label_1775
  br label %label_1777

label_1778:                                       ; preds = %label_1775
  %13 = load i32, ptr @ir_string_counter, align 4
  %14 = call ptr @int_to_str(i32 %13)
  %15 = call ptr @str_concat(ptr @.str.s686, ptr %14)
  store ptr %15, ptr %str_name, align 8
  %16 = load i32, ptr @ir_string_counter, align 4
  %17 = add i32 %16, 1
  store i32 %17, ptr @ir_string_counter, align 4
  %18 = load ptr, ptr %str_name, align 8
  %19 = load ptr, ptr %expr, align 8
  %20 = getelementptr inbounds nuw %ASTNode, ptr %19, i32 0, i32 1
  %21 = load ptr, ptr %20, align 8
  call void @ir_global_string(ptr %18, ptr %21)
  %22 = load ptr, ptr %expr, align 8
  %23 = load ptr, ptr %str_name, align 8
  %24 = getelementptr inbounds nuw %ASTNode, ptr %22, i32 0, i32 2
  store ptr %23, ptr %24, align 8
  br label %label_1780

label_1781:                                       ; preds = %label_1777
  %25 = load ptr, ptr %expr, align 8
  %26 = getelementptr inbounds nuw %ASTNode, ptr %25, i32 0, i32 0
  %27 = load i32, ptr %26, align 4
  %28 = icmp eq i32 %27, 29
  store i1 %28, ptr %sc.88, align 1
  br label %label_1782

label_1782:                                       ; preds = %label_1781, %label_1777
  %29 = load i1, ptr %sc.88, align 1
  br i1 %29, label %label_1783, label %label_1785

label_1785:                                       ; preds = %label_1788, %label_1782
  %30 = load ptr, ptr %expr, align 8
  %31 = getelementptr inbounds nuw %ASTNode, ptr %30, i32 0, i32 0
  %32 = load i32, ptr %31, align 4
  %33 = icmp eq i32 %32, 20
  br i1 %33, label %label_1789, label %label_1791

label_1783:                                       ; preds = %label_1782
  %34 = load ptr, ptr %expr, align 8
  %35 = getelementptr inbounds nuw %ASTNode, ptr %34, i32 0, i32 5
  %36 = load ptr, ptr %35, align 8
  %37 = call i32 @str_equals(ptr %36, ptr @.str.s687)
  %38 = icmp eq i32 %37, 0
  br i1 %38, label %label_1786, label %label_1788

label_1788:                                       ; preds = %label_1786, %label_1783
  br label %label_1785

label_1786:                                       ; preds = %label_1783
  %39 = load ptr, ptr %expr, align 8
  %40 = getelementptr inbounds nuw %ASTNode, ptr %39, i32 0, i32 5
  %41 = load ptr, ptr %40, align 8
  %42 = call ptr @ptr_to_node(ptr %41)
  call void @collect_strings_expr__Struct_ASTNode(ptr %42)
  br label %label_1788

label_1791:                                       ; preds = %label_1797, %label_1785
  %43 = load ptr, ptr %expr, align 8
  %44 = getelementptr inbounds nuw %ASTNode, ptr %43, i32 0, i32 0
  %45 = load i32, ptr %44, align 4
  %46 = icmp eq i32 %45, 24
  br i1 %46, label %label_1798, label %label_1800

label_1789:                                       ; preds = %label_1785
  %47 = load ptr, ptr %expr, align 8
  %48 = getelementptr inbounds nuw %ASTNode, ptr %47, i32 0, i32 5
  %49 = load ptr, ptr %48, align 8
  %50 = call i32 @str_equals(ptr %49, ptr @.str.s688)
  %51 = icmp eq i32 %50, 0
  br i1 %51, label %label_1792, label %label_1794

label_1794:                                       ; preds = %label_1792, %label_1789
  %52 = load ptr, ptr %expr, align 8
  %53 = getelementptr inbounds nuw %ASTNode, ptr %52, i32 0, i32 6
  %54 = load ptr, ptr %53, align 8
  %55 = call i32 @str_equals(ptr %54, ptr @.str.s689)
  %56 = icmp eq i32 %55, 0
  br i1 %56, label %label_1795, label %label_1797

label_1792:                                       ; preds = %label_1789
  %57 = load ptr, ptr %expr, align 8
  %58 = getelementptr inbounds nuw %ASTNode, ptr %57, i32 0, i32 5
  %59 = load ptr, ptr %58, align 8
  %60 = call ptr @ptr_to_node(ptr %59)
  call void @collect_strings_expr__Struct_ASTNode(ptr %60)
  br label %label_1794

label_1797:                                       ; preds = %label_1795, %label_1794
  br label %label_1791

label_1795:                                       ; preds = %label_1794
  %61 = load ptr, ptr %expr, align 8
  %62 = getelementptr inbounds nuw %ASTNode, ptr %61, i32 0, i32 6
  %63 = load ptr, ptr %62, align 8
  %64 = call ptr @ptr_to_node(ptr %63)
  call void @collect_strings_expr__Struct_ASTNode(ptr %64)
  br label %label_1797

label_1800:                                       ; preds = %label_1803, %label_1791
  %65 = load ptr, ptr %expr, align 8
  %66 = getelementptr inbounds nuw %ASTNode, ptr %65, i32 0, i32 0
  %67 = load i32, ptr %66, align 4
  %68 = icmp eq i32 %67, 27
  br i1 %68, label %label_1804, label %label_1806

label_1798:                                       ; preds = %label_1791
  %69 = load ptr, ptr %expr, align 8
  %70 = getelementptr inbounds nuw %ASTNode, ptr %69, i32 0, i32 6
  %71 = load ptr, ptr %70, align 8
  store ptr %71, ptr %arg_ptr, align 8
  br label %label_1801

label_1801:                                       ; preds = %label_1802, %label_1798
  %72 = load ptr, ptr %arg_ptr, align 8
  %73 = call i32 @str_equals(ptr %72, ptr @.str.s690)
  %74 = icmp eq i32 %73, 0
  br i1 %74, label %label_1802, label %label_1803

label_1803:                                       ; preds = %label_1801
  br label %label_1800

label_1802:                                       ; preds = %label_1801
  %75 = load ptr, ptr %arg_ptr, align 8
  %76 = call ptr @ptr_to_node(ptr %75)
  store ptr %76, ptr %arg_node, align 8
  %77 = load ptr, ptr %arg_node, align 8
  call void @collect_strings_expr__Struct_ASTNode(ptr %77)
  %78 = load ptr, ptr %arg_node, align 8
  %79 = getelementptr inbounds nuw %ASTNode, ptr %78, i32 0, i32 8
  %80 = load ptr, ptr %79, align 8
  store ptr %80, ptr %arg_ptr, align 8
  br label %label_1801

label_1806:                                       ; preds = %label_1809, %label_1800
  %81 = load ptr, ptr %expr, align 8
  %82 = getelementptr inbounds nuw %ASTNode, ptr %81, i32 0, i32 0
  %83 = load i32, ptr %82, align 4
  %84 = icmp eq i32 %83, 26
  br i1 %84, label %label_1810, label %label_1812

label_1804:                                       ; preds = %label_1800
  %85 = load ptr, ptr %expr, align 8
  %86 = getelementptr inbounds nuw %ASTNode, ptr %85, i32 0, i32 5
  %87 = load ptr, ptr %86, align 8
  store ptr %87, ptr %elem_ptr, align 8
  br label %label_1807

label_1807:                                       ; preds = %label_1808, %label_1804
  %88 = load ptr, ptr %elem_ptr, align 8
  %89 = call i32 @str_equals(ptr %88, ptr @.str.s691)
  %90 = icmp eq i32 %89, 0
  br i1 %90, label %label_1808, label %label_1809

label_1809:                                       ; preds = %label_1807
  br label %label_1806

label_1808:                                       ; preds = %label_1807
  %91 = load ptr, ptr %elem_ptr, align 8
  %92 = call ptr @ptr_to_node(ptr %91)
  store ptr %92, ptr %elem_node, align 8
  %93 = load ptr, ptr %elem_node, align 8
  call void @collect_strings_expr__Struct_ASTNode(ptr %93)
  %94 = load ptr, ptr %elem_node, align 8
  %95 = getelementptr inbounds nuw %ASTNode, ptr %94, i32 0, i32 8
  %96 = load ptr, ptr %95, align 8
  store ptr %96, ptr %elem_ptr, align 8
  br label %label_1807

label_1812:                                       ; preds = %label_1818, %label_1806
  %97 = load ptr, ptr %expr, align 8
  %98 = getelementptr inbounds nuw %ASTNode, ptr %97, i32 0, i32 0
  %99 = load i32, ptr %98, align 4
  %100 = icmp eq i32 %99, 25
  br i1 %100, label %label_1819, label %label_1821

label_1810:                                       ; preds = %label_1806
  %101 = load ptr, ptr %expr, align 8
  %102 = getelementptr inbounds nuw %ASTNode, ptr %101, i32 0, i32 5
  %103 = load ptr, ptr %102, align 8
  %104 = call i32 @str_equals(ptr %103, ptr @.str.s692)
  %105 = icmp eq i32 %104, 0
  br i1 %105, label %label_1813, label %label_1815

label_1815:                                       ; preds = %label_1813, %label_1810
  %106 = load ptr, ptr %expr, align 8
  %107 = getelementptr inbounds nuw %ASTNode, ptr %106, i32 0, i32 6
  %108 = load ptr, ptr %107, align 8
  %109 = call i32 @str_equals(ptr %108, ptr @.str.s693)
  %110 = icmp eq i32 %109, 0
  br i1 %110, label %label_1816, label %label_1818

label_1813:                                       ; preds = %label_1810
  %111 = load ptr, ptr %expr, align 8
  %112 = getelementptr inbounds nuw %ASTNode, ptr %111, i32 0, i32 5
  %113 = load ptr, ptr %112, align 8
  %114 = call ptr @ptr_to_node(ptr %113)
  call void @collect_strings_expr__Struct_ASTNode(ptr %114)
  br label %label_1815

label_1818:                                       ; preds = %label_1816, %label_1815
  br label %label_1812

label_1816:                                       ; preds = %label_1815
  %115 = load ptr, ptr %expr, align 8
  %116 = getelementptr inbounds nuw %ASTNode, ptr %115, i32 0, i32 6
  %117 = load ptr, ptr %116, align 8
  %118 = call ptr @ptr_to_node(ptr %117)
  call void @collect_strings_expr__Struct_ASTNode(ptr %118)
  br label %label_1818

label_1821:                                       ; preds = %label_1824, %label_1812
  %119 = load ptr, ptr %expr, align 8
  %120 = getelementptr inbounds nuw %ASTNode, ptr %119, i32 0, i32 0
  %121 = load i32, ptr %120, align 4
  %122 = icmp eq i32 %121, 28
  br i1 %122, label %label_1825, label %label_1827

label_1819:                                       ; preds = %label_1812
  %123 = load ptr, ptr %expr, align 8
  %124 = getelementptr inbounds nuw %ASTNode, ptr %123, i32 0, i32 5
  %125 = load ptr, ptr %124, align 8
  %126 = call i32 @str_equals(ptr %125, ptr @.str.s694)
  %127 = icmp eq i32 %126, 0
  br i1 %127, label %label_1822, label %label_1824

label_1824:                                       ; preds = %label_1822, %label_1819
  br label %label_1821

label_1822:                                       ; preds = %label_1819
  %128 = load ptr, ptr %expr, align 8
  %129 = getelementptr inbounds nuw %ASTNode, ptr %128, i32 0, i32 5
  %130 = load ptr, ptr %129, align 8
  %131 = call ptr @ptr_to_node(ptr %130)
  call void @collect_strings_expr__Struct_ASTNode(ptr %131)
  br label %label_1824

label_1827:                                       ; preds = %label_1830, %label_1821
  ret void

label_1825:                                       ; preds = %label_1821
  %132 = load ptr, ptr %expr, align 8
  %133 = getelementptr inbounds nuw %ASTNode, ptr %132, i32 0, i32 5
  %134 = load ptr, ptr %133, align 8
  store ptr %134, ptr %field_ptr, align 8
  br label %label_1828

label_1828:                                       ; preds = %label_1833, %label_1825
  %135 = load ptr, ptr %field_ptr, align 8
  %136 = call i32 @str_equals(ptr %135, ptr @.str.s695)
  %137 = icmp eq i32 %136, 0
  br i1 %137, label %label_1829, label %label_1830

label_1830:                                       ; preds = %label_1828
  br label %label_1827

label_1829:                                       ; preds = %label_1828
  %138 = load ptr, ptr %field_ptr, align 8
  %139 = call ptr @ptr_to_node(ptr %138)
  store ptr %139, ptr %field, align 8
  %140 = load ptr, ptr %field, align 8
  %141 = getelementptr inbounds nuw %ASTNode, ptr %140, i32 0, i32 5
  %142 = load ptr, ptr %141, align 8
  %143 = call i32 @str_equals(ptr %142, ptr @.str.s696)
  %144 = icmp eq i32 %143, 0
  br i1 %144, label %label_1831, label %label_1833

label_1833:                                       ; preds = %label_1831, %label_1829
  %145 = load ptr, ptr %field, align 8
  %146 = getelementptr inbounds nuw %ASTNode, ptr %145, i32 0, i32 8
  %147 = load ptr, ptr %146, align 8
  store ptr %147, ptr %field_ptr, align 8
  br label %label_1828

label_1831:                                       ; preds = %label_1829
  %148 = load ptr, ptr %field, align 8
  %149 = getelementptr inbounds nuw %ASTNode, ptr %148, i32 0, i32 5
  %150 = load ptr, ptr %149, align 8
  %151 = call ptr @ptr_to_node(ptr %150)
  call void @collect_strings_expr__Struct_ASTNode(ptr %151)
  br label %label_1833
}

define void @declare_extern_function__Struct_ASTNode(ptr %0) {
entry:
  %ext = alloca ptr, align 8
  store ptr %0, ptr %ext, align 8
  %ret_type = alloca ptr, align 8
  %param_ptr = alloca ptr, align 8
  %param_node = alloca ptr, align 8
  %p_type_node = alloca ptr, align 8
  %1 = load ptr, ptr %ext, align 8
  %2 = load ptr, ptr %ext, align 8
  %3 = getelementptr inbounds nuw %ASTNode, ptr %2, i32 0, i32 6
  %4 = load ptr, ptr %3, align 8
  %5 = call ptr @get_declared_return_type__Struct_ASTNode_String(ptr %1, ptr %4)
  store ptr %5, ptr %ret_type, align 8
  %6 = load ptr, ptr %ext, align 8
  %7 = call ptr @function_symbol_name__Struct_ASTNode(ptr %6)
  %8 = call ptr @fn_key__String(ptr %7)
  %9 = load ptr, ptr %ret_type, align 8
  call void @ir_set_var_type(ptr %8, ptr %9)
  %10 = load ptr, ptr %ext, align 8
  %11 = call ptr @function_symbol_name__Struct_ASTNode(ptr %10)
  %12 = load ptr, ptr %ret_type, align 8
  %13 = call ptr @storage_type__String(ptr %12)
  call void @ir_declare_function_begin(ptr %11, ptr %13)
  %14 = load ptr, ptr %ext, align 8
  %15 = getelementptr inbounds nuw %ASTNode, ptr %14, i32 0, i32 5
  %16 = load ptr, ptr %15, align 8
  store ptr %16, ptr %param_ptr, align 8
  br label %label_1834

label_1834:                                       ; preds = %label_1835, %entry
  %17 = load ptr, ptr %param_ptr, align 8
  %18 = call i32 @str_equals(ptr %17, ptr @.str.s697)
  %19 = icmp eq i32 %18, 0
  br i1 %19, label %label_1835, label %label_1836

label_1836:                                       ; preds = %label_1834
  call void @ir_declare_function_end()
  ret void

label_1835:                                       ; preds = %label_1834
  %20 = load ptr, ptr %param_ptr, align 8
  %21 = call ptr @ptr_to_node(ptr %20)
  store ptr %21, ptr %param_node, align 8
  %22 = load ptr, ptr %param_node, align 8
  %23 = getelementptr inbounds nuw %ASTNode, ptr %22, i32 0, i32 5
  %24 = load ptr, ptr %23, align 8
  %25 = call ptr @ptr_to_node(ptr %24)
  store ptr %25, ptr %p_type_node, align 8
  %26 = load ptr, ptr %p_type_node, align 8
  %27 = call ptr @map_type_node__Struct_ASTNode(ptr %26)
  %28 = call ptr @storage_type__String(ptr %27)
  call void @ir_declare_function_param(ptr %28)
  %29 = load ptr, ptr %param_node, align 8
  %30 = getelementptr inbounds nuw %ASTNode, ptr %29, i32 0, i32 8
  %31 = load ptr, ptr %30, align 8
  store ptr %31, ptr %param_ptr, align 8
  br label %label_1834
}

define i1 @module_has_function__Struct_ASTNode_String(ptr %0, ptr %1) {
entry:
  %module = alloca ptr, align 8
  store ptr %0, ptr %module, align 8
  %name = alloca ptr, align 8
  store ptr %1, ptr %name, align 8
  %stmt_ptr = alloca ptr, align 8
  %stmt = alloca ptr, align 8
  %2 = load ptr, ptr %module, align 8
  %3 = getelementptr inbounds nuw %ASTNode, ptr %2, i32 0, i32 5
  %4 = load ptr, ptr %3, align 8
  store ptr %4, ptr %stmt_ptr, align 8
  br label %label_1837

label_1837:                                       ; preds = %label_1844, %entry
  %5 = load ptr, ptr %stmt_ptr, align 8
  %6 = call i32 @str_equals(ptr %5, ptr @.str.s698)
  %7 = icmp eq i32 %6, 0
  br i1 %7, label %label_1838, label %label_1839

label_1839:                                       ; preds = %label_1837
  ret i1 false

label_1838:                                       ; preds = %label_1837
  %8 = load ptr, ptr %stmt_ptr, align 8
  %9 = call ptr @ptr_to_node(ptr %8)
  store ptr %9, ptr %stmt, align 8
  %sc.89 = alloca i1, align 1
  %10 = load ptr, ptr %stmt, align 8
  %11 = getelementptr inbounds nuw %ASTNode, ptr %10, i32 0, i32 0
  %12 = load i32, ptr %11, align 4
  %13 = icmp eq i32 %12, 4
  store i1 %13, ptr %sc.89, align 1
  br i1 %13, label %label_1840, label %label_1841

label_1841:                                       ; preds = %label_1840, %label_1838
  %14 = load i1, ptr %sc.89, align 1
  br i1 %14, label %label_1842, label %label_1844

label_1840:                                       ; preds = %label_1838
  %15 = load ptr, ptr %stmt, align 8
  %16 = getelementptr inbounds nuw %ASTNode, ptr %15, i32 0, i32 1
  %17 = load ptr, ptr %16, align 8
  %18 = load ptr, ptr %name, align 8
  %19 = call i32 @str_equals(ptr %17, ptr %18)
  %20 = icmp eq i32 %19, 1
  store i1 %20, ptr %sc.89, align 1
  br label %label_1841

label_1844:                                       ; preds = %label_1841
  %21 = load ptr, ptr %stmt, align 8
  %22 = getelementptr inbounds nuw %ASTNode, ptr %21, i32 0, i32 8
  %23 = load ptr, ptr %22, align 8
  store ptr %23, ptr %stmt_ptr, align 8
  br label %label_1837

label_1842:                                       ; preds = %label_1841
  ret i1 true
}

define void @register_enum_decl__Struct_ASTNode(ptr %0) {
entry:
  %enum_node = alloca ptr, align 8
  store ptr %0, ptr %enum_node, align 8
  %variant_ptr = alloca ptr, align 8
  %value = alloca i32, align 4
  %variant = alloca ptr, align 8
  %1 = load ptr, ptr %enum_node, align 8
  %2 = getelementptr inbounds nuw %ASTNode, ptr %1, i32 0, i32 5
  %3 = load ptr, ptr %2, align 8
  store ptr %3, ptr %variant_ptr, align 8
  store i32 0, ptr %value, align 4
  br label %label_1845

label_1845:                                       ; preds = %label_1846, %entry
  %4 = load ptr, ptr %variant_ptr, align 8
  %5 = call i32 @str_equals(ptr %4, ptr @.str.s699)
  %6 = icmp eq i32 %5, 0
  br i1 %6, label %label_1846, label %label_1847

label_1847:                                       ; preds = %label_1845
  ret void

label_1846:                                       ; preds = %label_1845
  %7 = load ptr, ptr %variant_ptr, align 8
  %8 = call ptr @ptr_to_node(ptr %7)
  store ptr %8, ptr %variant, align 8
  %9 = load ptr, ptr %enum_node, align 8
  %10 = getelementptr inbounds nuw %ASTNode, ptr %9, i32 0, i32 1
  %11 = load ptr, ptr %10, align 8
  %12 = load ptr, ptr %variant, align 8
  %13 = getelementptr inbounds nuw %ASTNode, ptr %12, i32 0, i32 1
  %14 = load ptr, ptr %13, align 8
  %15 = load i32, ptr %value, align 4
  call void @ir_register_enum_variant(ptr %11, ptr %14, i32 %15)
  %16 = load i32, ptr %value, align 4
  %17 = add i32 %16, 1
  store i32 %17, ptr %value, align 4
  %18 = load ptr, ptr %variant, align 8
  %19 = getelementptr inbounds nuw %ASTNode, ptr %18, i32 0, i32 8
  %20 = load ptr, ptr %19, align 8
  store ptr %20, ptr %variant_ptr, align 8
  br label %label_1845
}

define void @register_struct_name__Struct_ASTNode(ptr %0) {
entry:
  %struct_node = alloca ptr, align 8
  store ptr %0, ptr %struct_node, align 8
  %1 = load ptr, ptr %struct_node, align 8
  %2 = getelementptr inbounds nuw %ASTNode, ptr %1, i32 0, i32 1
  %3 = load ptr, ptr %2, align 8
  call void @ir_register_struct(ptr %3)
  ret void
}

define void @generate_struct_decl__Struct_ASTNode(ptr %0) {
entry:
  %struct_node = alloca ptr, align 8
  store ptr %0, ptr %struct_node, align 8
  %first_field_ptr = alloca ptr, align 8
  %first_field = alloca ptr, align 8
  %field_ptr = alloca ptr, align 8
  %field = alloca ptr, align 8
  %type_node = alloca ptr, align 8
  %field_type = alloca ptr, align 8
  %1 = load ptr, ptr %struct_node, align 8
  %2 = getelementptr inbounds nuw %ASTNode, ptr %1, i32 0, i32 5
  %3 = load ptr, ptr %2, align 8
  store ptr %3, ptr %first_field_ptr, align 8
  %4 = load ptr, ptr %first_field_ptr, align 8
  %5 = call i32 @str_equals(ptr %4, ptr @.str.s700)
  %6 = icmp eq i32 %5, 0
  br i1 %6, label %label_1848, label %label_1850

label_1850:                                       ; preds = %label_1853, %entry
  %7 = load ptr, ptr %struct_node, align 8
  %8 = getelementptr inbounds nuw %ASTNode, ptr %7, i32 0, i32 1
  %9 = load ptr, ptr %8, align 8
  call void @ir_struct_type_begin(ptr %9)
  %10 = load ptr, ptr %struct_node, align 8
  %11 = getelementptr inbounds nuw %ASTNode, ptr %10, i32 0, i32 5
  %12 = load ptr, ptr %11, align 8
  store ptr %12, ptr %field_ptr, align 8
  br label %label_1854

label_1848:                                       ; preds = %entry
  %13 = load ptr, ptr %first_field_ptr, align 8
  %14 = call ptr @ptr_to_node(ptr %13)
  store ptr %14, ptr %first_field, align 8
  %15 = load ptr, ptr %struct_node, align 8
  %16 = getelementptr inbounds nuw %ASTNode, ptr %15, i32 0, i32 1
  %17 = load ptr, ptr %16, align 8
  %18 = load ptr, ptr %first_field, align 8
  %19 = getelementptr inbounds nuw %ASTNode, ptr %18, i32 0, i32 1
  %20 = load ptr, ptr %19, align 8
  %21 = call i32 @ir_get_struct_field_index(ptr %17, ptr %20)
  %22 = icmp sge i32 %21, 0
  br i1 %22, label %label_1851, label %label_1853

label_1853:                                       ; preds = %label_1848
  br label %label_1850

label_1851:                                       ; preds = %label_1848
  ret void

label_1854:                                       ; preds = %label_1855, %label_1850
  %23 = load ptr, ptr %field_ptr, align 8
  %24 = call i32 @str_equals(ptr %23, ptr @.str.s701)
  %25 = icmp eq i32 %24, 0
  br i1 %25, label %label_1855, label %label_1856

label_1856:                                       ; preds = %label_1854
  call void @ir_struct_type_end()
  ret void

label_1855:                                       ; preds = %label_1854
  %26 = load ptr, ptr %field_ptr, align 8
  %27 = call ptr @ptr_to_node(ptr %26)
  store ptr %27, ptr %field, align 8
  %28 = load ptr, ptr %field, align 8
  %29 = getelementptr inbounds nuw %ASTNode, ptr %28, i32 0, i32 5
  %30 = load ptr, ptr %29, align 8
  %31 = call ptr @ptr_to_node(ptr %30)
  store ptr %31, ptr %type_node, align 8
  %32 = load ptr, ptr %type_node, align 8
  %33 = call ptr @map_type_node__Struct_ASTNode(ptr %32)
  %34 = call ptr @storage_type__String(ptr %33)
  store ptr %34, ptr %field_type, align 8
  %35 = load ptr, ptr %struct_node, align 8
  %36 = getelementptr inbounds nuw %ASTNode, ptr %35, i32 0, i32 1
  %37 = load ptr, ptr %36, align 8
  %38 = load ptr, ptr %field, align 8
  %39 = getelementptr inbounds nuw %ASTNode, ptr %38, i32 0, i32 1
  %40 = load ptr, ptr %39, align 8
  %41 = load ptr, ptr %field_type, align 8
  call void @ir_register_struct_field(ptr %37, ptr %40, ptr %41)
  %42 = load ptr, ptr %field_type, align 8
  call void @ir_struct_type_field(ptr %42)
  %43 = load ptr, ptr %field, align 8
  %44 = getelementptr inbounds nuw %ASTNode, ptr %43, i32 0, i32 8
  %45 = load ptr, ptr %44, align 8
  store ptr %45, ptr %field_ptr, align 8
  br label %label_1854
}

define void @collect_strings_child_expr__String(ptr %0) {
entry:
  %child = alloca ptr, align 8
  store ptr %0, ptr %child, align 8
  %1 = load ptr, ptr %child, align 8
  %2 = call i32 @str_equals(ptr %1, ptr @.str.s702)
  %3 = icmp eq i32 %2, 0
  br i1 %3, label %label_1857, label %label_1859

label_1859:                                       ; preds = %label_1857, %entry
  ret void

label_1857:                                       ; preds = %entry
  %4 = load ptr, ptr %child, align 8
  %5 = call ptr @ptr_to_node(ptr %4)
  call void @collect_strings_expr__Struct_ASTNode(ptr %5)
  br label %label_1859
}

define void @collect_strings_child_block__String(ptr %0) {
entry:
  %child = alloca ptr, align 8
  store ptr %0, ptr %child, align 8
  %1 = load ptr, ptr %child, align 8
  %2 = call i32 @str_equals(ptr %1, ptr @.str.s703)
  %3 = icmp eq i32 %2, 0
  br i1 %3, label %label_1860, label %label_1862

label_1862:                                       ; preds = %label_1860, %entry
  ret void

label_1860:                                       ; preds = %entry
  %4 = load ptr, ptr %child, align 8
  %5 = call ptr @ptr_to_node(ptr %4)
  call void @collect_strings_block__Struct_ASTNode(ptr %5)
  br label %label_1862
}

define void @collect_strings_block__Struct_ASTNode(ptr %0) {
entry:
  %block = alloca ptr, align 8
  store ptr %0, ptr %block, align 8
  %s_ptr = alloca ptr, align 8
  %s = alloca ptr, align 8
  %1 = load ptr, ptr %block, align 8
  %2 = getelementptr inbounds nuw %ASTNode, ptr %1, i32 0, i32 5
  %3 = load ptr, ptr %2, align 8
  store ptr %3, ptr %s_ptr, align 8
  br label %label_1899

label_1899:                                       ; preds = %label_1900, %entry
  %4 = load ptr, ptr %s_ptr, align 8
  %5 = call i32 @str_equals(ptr %4, ptr @.str.s706)
  %6 = icmp eq i32 %5, 0
  br i1 %6, label %label_1900, label %label_1901

label_1901:                                       ; preds = %label_1899
  ret void

label_1900:                                       ; preds = %label_1899
  %7 = load ptr, ptr %s_ptr, align 8
  %8 = call ptr @ptr_to_node(ptr %7)
  store ptr %8, ptr %s, align 8
  %9 = load ptr, ptr %s, align 8
  call void @collect_strings_stmt__Struct_ASTNode(ptr %9)
  %10 = load ptr, ptr %s, align 8
  %11 = getelementptr inbounds nuw %ASTNode, ptr %10, i32 0, i32 8
  %12 = load ptr, ptr %11, align 8
  store ptr %12, ptr %s_ptr, align 8
  br label %label_1899
}

define void @collect_strings_stmt__Struct_ASTNode(ptr %0) {
entry:
  %stmt = alloca ptr, align 8
  store ptr %0, ptr %stmt, align 8
  %else_node = alloca ptr, align 8
  %arm_ptr = alloca ptr, align 8
  %arm = alloca ptr, align 8
  %1 = load ptr, ptr %stmt, align 8
  %2 = getelementptr inbounds nuw %ASTNode, ptr %1, i32 0, i32 0
  %3 = load i32, ptr %2, align 4
  %4 = icmp eq i32 %3, 3
  br i1 %4, label %label_1863, label %label_1865

label_1865:                                       ; preds = %label_1863, %entry
  %5 = load ptr, ptr %stmt, align 8
  %6 = getelementptr inbounds nuw %ASTNode, ptr %5, i32 0, i32 0
  %7 = load i32, ptr %6, align 4
  %8 = icmp eq i32 %7, 17
  br i1 %8, label %label_1866, label %label_1868

label_1863:                                       ; preds = %entry
  %9 = load ptr, ptr %stmt, align 8
  %10 = getelementptr inbounds nuw %ASTNode, ptr %9, i32 0, i32 6
  %11 = load ptr, ptr %10, align 8
  call void @collect_strings_child_expr__String(ptr %11)
  br label %label_1865

label_1868:                                       ; preds = %label_1866, %label_1865
  %12 = load ptr, ptr %stmt, align 8
  %13 = getelementptr inbounds nuw %ASTNode, ptr %12, i32 0, i32 0
  %14 = load i32, ptr %13, align 4
  %15 = icmp eq i32 %14, 15
  br i1 %15, label %label_1869, label %label_1871

label_1866:                                       ; preds = %label_1865
  %16 = load ptr, ptr %stmt, align 8
  %17 = getelementptr inbounds nuw %ASTNode, ptr %16, i32 0, i32 5
  %18 = load ptr, ptr %17, align 8
  call void @collect_strings_child_expr__String(ptr %18)
  br label %label_1868

label_1871:                                       ; preds = %label_1869, %label_1868
  %19 = load ptr, ptr %stmt, align 8
  %20 = getelementptr inbounds nuw %ASTNode, ptr %19, i32 0, i32 0
  %21 = load i32, ptr %20, align 4
  %22 = icmp eq i32 %21, 16
  br i1 %22, label %label_1872, label %label_1874

label_1869:                                       ; preds = %label_1868
  %23 = load ptr, ptr %stmt, align 8
  %24 = getelementptr inbounds nuw %ASTNode, ptr %23, i32 0, i32 5
  %25 = load ptr, ptr %24, align 8
  call void @collect_strings_child_expr__String(ptr %25)
  br label %label_1871

label_1874:                                       ; preds = %label_1872, %label_1871
  %26 = load ptr, ptr %stmt, align 8
  %27 = getelementptr inbounds nuw %ASTNode, ptr %26, i32 0, i32 0
  %28 = load i32, ptr %27, align 4
  %29 = icmp eq i32 %28, 10
  br i1 %29, label %label_1875, label %label_1877

label_1872:                                       ; preds = %label_1871
  %30 = load ptr, ptr %stmt, align 8
  %31 = getelementptr inbounds nuw %ASTNode, ptr %30, i32 0, i32 5
  %32 = load ptr, ptr %31, align 8
  call void @collect_strings_child_expr__String(ptr %32)
  %33 = load ptr, ptr %stmt, align 8
  %34 = getelementptr inbounds nuw %ASTNode, ptr %33, i32 0, i32 6
  %35 = load ptr, ptr %34, align 8
  call void @collect_strings_child_expr__String(ptr %35)
  br label %label_1874

label_1877:                                       ; preds = %label_1880, %label_1874
  %36 = load ptr, ptr %stmt, align 8
  %37 = getelementptr inbounds nuw %ASTNode, ptr %36, i32 0, i32 0
  %38 = load i32, ptr %37, align 4
  %39 = icmp eq i32 %38, 13
  br i1 %39, label %label_1884, label %label_1886

label_1875:                                       ; preds = %label_1874
  %40 = load ptr, ptr %stmt, align 8
  %41 = getelementptr inbounds nuw %ASTNode, ptr %40, i32 0, i32 5
  %42 = load ptr, ptr %41, align 8
  call void @collect_strings_child_expr__String(ptr %42)
  %43 = load ptr, ptr %stmt, align 8
  %44 = getelementptr inbounds nuw %ASTNode, ptr %43, i32 0, i32 6
  %45 = load ptr, ptr %44, align 8
  call void @collect_strings_child_block__String(ptr %45)
  %46 = load ptr, ptr %stmt, align 8
  %47 = getelementptr inbounds nuw %ASTNode, ptr %46, i32 0, i32 7
  %48 = load ptr, ptr %47, align 8
  %49 = call i32 @str_equals(ptr %48, ptr @.str.s704)
  %50 = icmp eq i32 %49, 0
  br i1 %50, label %label_1878, label %label_1880

label_1880:                                       ; preds = %label_1883, %label_1875
  br label %label_1877

label_1878:                                       ; preds = %label_1875
  %51 = load ptr, ptr %stmt, align 8
  %52 = getelementptr inbounds nuw %ASTNode, ptr %51, i32 0, i32 7
  %53 = load ptr, ptr %52, align 8
  %54 = call ptr @ptr_to_node(ptr %53)
  store ptr %54, ptr %else_node, align 8
  %55 = load ptr, ptr %else_node, align 8
  %56 = getelementptr inbounds nuw %ASTNode, ptr %55, i32 0, i32 0
  %57 = load i32, ptr %56, align 4
  %58 = icmp eq i32 %57, 10
  br i1 %58, label %label_1881, label %label_1882

label_1882:                                       ; preds = %label_1878
  %59 = load ptr, ptr %else_node, align 8
  call void @collect_strings_block__Struct_ASTNode(ptr %59)
  br label %label_1883

label_1881:                                       ; preds = %label_1878
  %60 = load ptr, ptr %else_node, align 8
  call void @collect_strings_stmt__Struct_ASTNode(ptr %60)
  br label %label_1883

label_1883:                                       ; preds = %label_1882, %label_1881
  br label %label_1880

label_1886:                                       ; preds = %label_1884, %label_1877
  %61 = load ptr, ptr %stmt, align 8
  %62 = getelementptr inbounds nuw %ASTNode, ptr %61, i32 0, i32 0
  %63 = load i32, ptr %62, align 4
  %64 = icmp eq i32 %63, 14
  br i1 %64, label %label_1887, label %label_1889

label_1884:                                       ; preds = %label_1877
  %65 = load ptr, ptr %stmt, align 8
  %66 = getelementptr inbounds nuw %ASTNode, ptr %65, i32 0, i32 5
  %67 = load ptr, ptr %66, align 8
  call void @collect_strings_child_expr__String(ptr %67)
  %68 = load ptr, ptr %stmt, align 8
  %69 = getelementptr inbounds nuw %ASTNode, ptr %68, i32 0, i32 6
  %70 = load ptr, ptr %69, align 8
  call void @collect_strings_child_block__String(ptr %70)
  br label %label_1886

label_1889:                                       ; preds = %label_1887, %label_1886
  %71 = load ptr, ptr %stmt, align 8
  %72 = getelementptr inbounds nuw %ASTNode, ptr %71, i32 0, i32 0
  %73 = load i32, ptr %72, align 4
  %74 = icmp eq i32 %73, 12
  br i1 %74, label %label_1890, label %label_1892

label_1887:                                       ; preds = %label_1886
  %75 = load ptr, ptr %stmt, align 8
  %76 = getelementptr inbounds nuw %ASTNode, ptr %75, i32 0, i32 5
  %77 = load ptr, ptr %76, align 8
  call void @collect_strings_child_block__String(ptr %77)
  br label %label_1889

label_1892:                                       ; preds = %label_1890, %label_1889
  %78 = load ptr, ptr %stmt, align 8
  %79 = getelementptr inbounds nuw %ASTNode, ptr %78, i32 0, i32 0
  %80 = load i32, ptr %79, align 4
  %81 = icmp eq i32 %80, 11
  br i1 %81, label %label_1893, label %label_1895

label_1890:                                       ; preds = %label_1889
  %82 = load ptr, ptr %stmt, align 8
  %83 = getelementptr inbounds nuw %ASTNode, ptr %82, i32 0, i32 5
  %84 = load ptr, ptr %83, align 8
  call void @collect_strings_child_expr__String(ptr %84)
  %85 = load ptr, ptr %stmt, align 8
  %86 = getelementptr inbounds nuw %ASTNode, ptr %85, i32 0, i32 6
  %87 = load ptr, ptr %86, align 8
  call void @collect_strings_child_expr__String(ptr %87)
  %88 = load ptr, ptr %stmt, align 8
  %89 = getelementptr inbounds nuw %ASTNode, ptr %88, i32 0, i32 7
  %90 = load ptr, ptr %89, align 8
  call void @collect_strings_child_block__String(ptr %90)
  br label %label_1892

label_1895:                                       ; preds = %label_1898, %label_1892
  ret void

label_1893:                                       ; preds = %label_1892
  %91 = load ptr, ptr %stmt, align 8
  %92 = getelementptr inbounds nuw %ASTNode, ptr %91, i32 0, i32 5
  %93 = load ptr, ptr %92, align 8
  call void @collect_strings_child_expr__String(ptr %93)
  %94 = load ptr, ptr %stmt, align 8
  %95 = getelementptr inbounds nuw %ASTNode, ptr %94, i32 0, i32 6
  %96 = load ptr, ptr %95, align 8
  store ptr %96, ptr %arm_ptr, align 8
  br label %label_1896

label_1896:                                       ; preds = %label_1897, %label_1893
  %97 = load ptr, ptr %arm_ptr, align 8
  %98 = call i32 @str_equals(ptr %97, ptr @.str.s705)
  %99 = icmp eq i32 %98, 0
  br i1 %99, label %label_1897, label %label_1898

label_1898:                                       ; preds = %label_1896
  br label %label_1895

label_1897:                                       ; preds = %label_1896
  %100 = load ptr, ptr %arm_ptr, align 8
  %101 = call ptr @ptr_to_node(ptr %100)
  store ptr %101, ptr %arm, align 8
  %102 = load ptr, ptr %arm, align 8
  %103 = getelementptr inbounds nuw %ASTNode, ptr %102, i32 0, i32 5
  %104 = load ptr, ptr %103, align 8
  call void @collect_strings_child_expr__String(ptr %104)
  %105 = load ptr, ptr %arm, align 8
  %106 = getelementptr inbounds nuw %ASTNode, ptr %105, i32 0, i32 6
  %107 = load ptr, ptr %106, align 8
  call void @collect_strings_child_block__String(ptr %107)
  %108 = load ptr, ptr %arm, align 8
  %109 = getelementptr inbounds nuw %ASTNode, ptr %108, i32 0, i32 8
  %110 = load ptr, ptr %109, align 8
  store ptr %110, ptr %arm_ptr, align 8
  br label %label_1896
}

define void @collect_strings_function__Struct_ASTNode(ptr %0) {
entry:
  %func = alloca ptr, align 8
  store ptr %0, ptr %func, align 8
  %1 = load ptr, ptr %func, align 8
  %2 = getelementptr inbounds nuw %ASTNode, ptr %1, i32 0, i32 6
  %3 = load ptr, ptr %2, align 8
  %4 = call i32 @str_equals(ptr %3, ptr @.str.s707)
  %5 = icmp eq i32 %4, 0
  br i1 %5, label %label_1902, label %label_1904

label_1904:                                       ; preds = %label_1902, %entry
  ret void

label_1902:                                       ; preds = %entry
  %6 = load ptr, ptr %func, align 8
  %7 = getelementptr inbounds nuw %ASTNode, ptr %6, i32 0, i32 6
  %8 = load ptr, ptr %7, align 8
  %9 = call ptr @ptr_to_node(ptr %8)
  call void @collect_strings_block__Struct_ASTNode(ptr %9)
  br label %label_1904
}

define void @generate_module__Struct_ASTNode(ptr %0) {
entry:
  %module = alloca ptr, align 8
  store ptr %0, ptr %module, align 8
  %type_stmt_ptr = alloca ptr, align 8
  %type_stmt = alloca ptr, align 8
  %struct_stmt_ptr = alloca ptr, align 8
  %struct_stmt = alloca ptr, align 8
  %stmt_ptr = alloca ptr, align 8
  %stmt = alloca ptr, align 8
  %init_val = alloca ptr, align 8
  %var_type = alloca ptr, align 8
  %has_annotation = alloca i1, align 1
  %type_node = alloca ptr, align 8
  %init_node = alloca ptr, align 8
  %ret_type = alloca ptr, align 8
  %stmt_ptr2 = alloca ptr, align 8
  %stmt2 = alloca ptr, align 8
  call void @ir_reset_globals()
  call void @ir_reset_types()
  call void @ir_clear_var_types()
  %1 = call ptr @ir_ptr_int_type__Void()
  call void @ir_set_pointer_int_type(ptr %1)
  %2 = load i1, ptr @ir_target_wasm, align 1
  br i1 %2, label %label_1905, label %label_1906

label_1906:                                       ; preds = %entry
  call void @ir_module_start(ptr @.str.s709)
  br label %label_1907

label_1905:                                       ; preds = %entry
  call void @ir_module_start_wasm(ptr @.str.s708)
  br label %label_1907

label_1907:                                       ; preds = %label_1906, %label_1905
  %3 = load ptr, ptr %module, align 8
  %4 = getelementptr inbounds nuw %ASTNode, ptr %3, i32 0, i32 5
  %5 = load ptr, ptr %4, align 8
  store ptr %5, ptr %type_stmt_ptr, align 8
  br label %label_1908

label_1908:                                       ; preds = %label_1916, %label_1907
  %6 = load ptr, ptr %type_stmt_ptr, align 8
  %7 = call i32 @str_equals(ptr %6, ptr @.str.s710)
  %8 = icmp eq i32 %7, 0
  br i1 %8, label %label_1909, label %label_1910

label_1910:                                       ; preds = %label_1908
  %9 = load ptr, ptr %module, align 8
  %10 = getelementptr inbounds nuw %ASTNode, ptr %9, i32 0, i32 5
  %11 = load ptr, ptr %10, align 8
  store ptr %11, ptr %struct_stmt_ptr, align 8
  br label %label_1917

label_1909:                                       ; preds = %label_1908
  %12 = load ptr, ptr %type_stmt_ptr, align 8
  %13 = call ptr @ptr_to_node(ptr %12)
  store ptr %13, ptr %type_stmt, align 8
  %14 = load ptr, ptr %type_stmt, align 8
  %15 = getelementptr inbounds nuw %ASTNode, ptr %14, i32 0, i32 0
  %16 = load i32, ptr %15, align 4
  %17 = icmp eq i32 %16, 6
  br i1 %17, label %label_1911, label %label_1913

label_1913:                                       ; preds = %label_1911, %label_1909
  %18 = load ptr, ptr %type_stmt, align 8
  %19 = getelementptr inbounds nuw %ASTNode, ptr %18, i32 0, i32 0
  %20 = load i32, ptr %19, align 4
  %21 = icmp eq i32 %20, 5
  br i1 %21, label %label_1914, label %label_1916

label_1911:                                       ; preds = %label_1909
  %22 = load ptr, ptr %type_stmt, align 8
  call void @register_enum_decl__Struct_ASTNode(ptr %22)
  br label %label_1913

label_1916:                                       ; preds = %label_1914, %label_1913
  %23 = load ptr, ptr %type_stmt, align 8
  %24 = getelementptr inbounds nuw %ASTNode, ptr %23, i32 0, i32 8
  %25 = load ptr, ptr %24, align 8
  store ptr %25, ptr %type_stmt_ptr, align 8
  br label %label_1908

label_1914:                                       ; preds = %label_1913
  %26 = load ptr, ptr %type_stmt, align 8
  call void @register_struct_name__Struct_ASTNode(ptr %26)
  br label %label_1916

label_1917:                                       ; preds = %label_1922, %label_1910
  %27 = load ptr, ptr %struct_stmt_ptr, align 8
  %28 = call i32 @str_equals(ptr %27, ptr @.str.s711)
  %29 = icmp eq i32 %28, 0
  br i1 %29, label %label_1918, label %label_1919

label_1919:                                       ; preds = %label_1917
  call void @ir_blank_line()
  call void @ir_global_var(ptr @.str.s712, ptr @.str.s713, ptr @.str.s714, i32 0)
  call void @ir_global_var(ptr @.str.s715, ptr @.str.s716, ptr @.str.s717, i32 0)
  call void @ir_declare_function_begin(ptr @.str.s718, ptr @.str.s719)
  %30 = call ptr @ir_ptr_int_type__Void()
  call void @ir_declare_function_param(ptr %30)
  call void @ir_declare_function_end()
  call void @ir_declare_function_begin(ptr @.str.s720, ptr @.str.s721)
  call void @ir_declare_function_param(ptr @.str.s722)
  call void @ir_declare_function_end()
  call void @ir_declare_function_begin(ptr @.str.s723, ptr @.str.s724)
  call void @ir_declare_function_end()
  call void @ir_declare_function_begin(ptr @.str.s725, ptr @.str.s726)
  call void @ir_declare_function_param(ptr @.str.s727)
  call void @ir_declare_function_param(ptr @.str.s728)
  call void @ir_declare_function_end()
  call void @ir_declare_function_begin(ptr @.str.s729, ptr @.str.s730)
  call void @ir_declare_function_param(ptr @.str.s731)
  call void @ir_declare_function_param(ptr @.str.s732)
  call void @ir_declare_function_end()
  call void @ir_declare_function_begin(ptr @.str.s733, ptr @.str.s734)
  call void @ir_declare_function_param(ptr @.str.s735)
  call void @ir_declare_function_param(ptr @.str.s736)
  call void @ir_declare_function_param(ptr @.str.s737)
  call void @ir_declare_function_end()
  call void @ir_declare_function_begin(ptr @.str.s738, ptr @.str.s739)
  call void @ir_declare_function_param(ptr @.str.s740)
  call void @ir_declare_function_end()
  call void @ir_declare_function_begin(ptr @.str.s741, ptr @.str.s742)
  call void @ir_declare_function_param(ptr @.str.s743)
  call void @ir_declare_function_end()
  call void @ir_declare_function_begin(ptr @.str.s744, ptr @.str.s745)
  call void @ir_declare_function_param(ptr @.str.s746)
  call void @ir_declare_function_end()
  call void @ir_declare_function_begin(ptr @.str.s747, ptr @.str.s748)
  call void @ir_declare_function_param(ptr @.str.s749)
  call void @ir_declare_function_end()
  call void @ir_declare_function_begin(ptr @.str.s750, ptr @.str.s751)
  call void @ir_declare_function_param(ptr @.str.s752)
  call void @ir_declare_function_end()
  call void @ir_declare_function_begin(ptr @.str.s753, ptr @.str.s754)
  call void @ir_declare_function_param(ptr @.str.s755)
  call void @ir_declare_function_end()
  call void @ir_declare_function_begin(ptr @.str.s756, ptr @.str.s757)
  call void @ir_declare_function_param(ptr @.str.s758)
  call void @ir_declare_function_end()
  call void @ir_declare_function_begin(ptr @.str.s759, ptr @.str.s760)
  call void @ir_declare_function_param(ptr @.str.s761)
  call void @ir_declare_function_end()
  call void @ir_declare_function_begin(ptr @.str.s762, ptr @.str.s763)
  call void @ir_declare_function_param(ptr @.str.s764)
  call void @ir_declare_function_end()
  call void @ir_declare_function_begin(ptr @.str.s765, ptr @.str.s766)
  call void @ir_declare_function_param(ptr @.str.s767)
  call void @ir_declare_function_end()
  call void @ir_declare_function_begin(ptr @.str.s768, ptr @.str.s769)
  call void @ir_declare_function_param(ptr @.str.s770)
  call void @ir_declare_function_end()
  call void @ir_blank_line()
  %31 = load ptr, ptr %module, align 8
  %32 = getelementptr inbounds nuw %ASTNode, ptr %31, i32 0, i32 5
  %33 = load ptr, ptr %32, align 8
  store ptr %33, ptr %stmt_ptr, align 8
  br label %label_1923

label_1918:                                       ; preds = %label_1917
  %34 = load ptr, ptr %struct_stmt_ptr, align 8
  %35 = call ptr @ptr_to_node(ptr %34)
  store ptr %35, ptr %struct_stmt, align 8
  %36 = load ptr, ptr %struct_stmt, align 8
  %37 = getelementptr inbounds nuw %ASTNode, ptr %36, i32 0, i32 0
  %38 = load i32, ptr %37, align 4
  %39 = icmp eq i32 %38, 5
  br i1 %39, label %label_1920, label %label_1922

label_1922:                                       ; preds = %label_1920, %label_1918
  %40 = load ptr, ptr %struct_stmt, align 8
  %41 = getelementptr inbounds nuw %ASTNode, ptr %40, i32 0, i32 8
  %42 = load ptr, ptr %41, align 8
  store ptr %42, ptr %struct_stmt_ptr, align 8
  br label %label_1917

label_1920:                                       ; preds = %label_1918
  %43 = load ptr, ptr %struct_stmt, align 8
  call void @generate_struct_decl__Struct_ASTNode(ptr %43)
  br label %label_1922

label_1923:                                       ; preds = %label_1952, %label_1919
  %44 = load ptr, ptr %stmt_ptr, align 8
  %45 = call i32 @str_equals(ptr %44, ptr @.str.s771)
  %46 = icmp eq i32 %45, 0
  br i1 %46, label %label_1924, label %label_1925

label_1925:                                       ; preds = %label_1923
  call void @ir_blank_line()
  %47 = load ptr, ptr %module, align 8
  %48 = getelementptr inbounds nuw %ASTNode, ptr %47, i32 0, i32 5
  %49 = load ptr, ptr %48, align 8
  store ptr %49, ptr %stmt_ptr2, align 8
  br label %label_1956

label_1924:                                       ; preds = %label_1923
  %50 = load ptr, ptr %stmt_ptr, align 8
  %51 = call ptr @ptr_to_node(ptr %50)
  store ptr %51, ptr %stmt, align 8
  %52 = load ptr, ptr %stmt, align 8
  %53 = getelementptr inbounds nuw %ASTNode, ptr %52, i32 0, i32 0
  %54 = load i32, ptr %53, align 4
  %55 = icmp eq i32 %54, 2
  br i1 %55, label %label_1926, label %label_1928

label_1928:                                       ; preds = %label_1931, %label_1924
  %56 = load ptr, ptr %stmt, align 8
  %57 = getelementptr inbounds nuw %ASTNode, ptr %56, i32 0, i32 0
  %58 = load i32, ptr %57, align 4
  %59 = icmp eq i32 %58, 3
  br i1 %59, label %label_1932, label %label_1934

label_1926:                                       ; preds = %label_1924
  %60 = load ptr, ptr %module, align 8
  %61 = load ptr, ptr %stmt, align 8
  %62 = getelementptr inbounds nuw %ASTNode, ptr %61, i32 0, i32 1
  %63 = load ptr, ptr %62, align 8
  %64 = call i1 @module_has_function__Struct_ASTNode_String(ptr %60, ptr %63)
  %65 = icmp eq i1 %64, false
  br i1 %65, label %label_1929, label %label_1931

label_1931:                                       ; preds = %label_1929, %label_1926
  br label %label_1928

label_1929:                                       ; preds = %label_1926
  %66 = load ptr, ptr %stmt, align 8
  call void @declare_extern_function__Struct_ASTNode(ptr %66)
  br label %label_1931

label_1934:                                       ; preds = %label_1940, %label_1928
  %67 = load ptr, ptr %stmt, align 8
  %68 = getelementptr inbounds nuw %ASTNode, ptr %67, i32 0, i32 0
  %69 = load i32, ptr %68, align 4
  %70 = icmp eq i32 %69, 4
  br i1 %70, label %label_1950, label %label_1952

label_1932:                                       ; preds = %label_1928
  store ptr @.str.s772, ptr %init_val, align 8
  store ptr @.str.s773, ptr %var_type, align 8
  %71 = load ptr, ptr %stmt, align 8
  %72 = getelementptr inbounds nuw %ASTNode, ptr %71, i32 0, i32 5
  %73 = load ptr, ptr %72, align 8
  %74 = call i32 @str_equals(ptr %73, ptr @.str.s774)
  %75 = icmp eq i32 %74, 0
  store i1 %75, ptr %has_annotation, align 1
  %76 = load i1, ptr %has_annotation, align 1
  br i1 %76, label %label_1935, label %label_1937

label_1937:                                       ; preds = %label_1935, %label_1932
  %77 = load ptr, ptr %stmt, align 8
  %78 = getelementptr inbounds nuw %ASTNode, ptr %77, i32 0, i32 6
  %79 = load ptr, ptr %78, align 8
  %80 = call i32 @str_equals(ptr %79, ptr @.str.s775)
  %81 = icmp eq i32 %80, 0
  br i1 %81, label %label_1938, label %label_1940

label_1935:                                       ; preds = %label_1932
  %82 = load ptr, ptr %stmt, align 8
  %83 = getelementptr inbounds nuw %ASTNode, ptr %82, i32 0, i32 5
  %84 = load ptr, ptr %83, align 8
  %85 = call ptr @ptr_to_node(ptr %84)
  store ptr %85, ptr %type_node, align 8
  %86 = load ptr, ptr %type_node, align 8
  %87 = call ptr @map_type_node__Struct_ASTNode(ptr %86)
  store ptr %87, ptr %var_type, align 8
  br label %label_1937

label_1940:                                       ; preds = %label_1946, %label_1937
  %88 = load ptr, ptr %stmt, align 8
  %89 = getelementptr inbounds nuw %ASTNode, ptr %88, i32 0, i32 1
  %90 = load ptr, ptr %89, align 8
  %91 = load ptr, ptr %var_type, align 8
  %92 = call ptr @storage_type__String(ptr %91)
  %93 = load ptr, ptr %init_val, align 8
  call void @ir_global_var(ptr %90, ptr %92, ptr %93, i32 0)
  %94 = load ptr, ptr %stmt, align 8
  %95 = getelementptr inbounds nuw %ASTNode, ptr %94, i32 0, i32 1
  %96 = load ptr, ptr %95, align 8
  call void @ir_register_global_name(ptr %96)
  %97 = load ptr, ptr %stmt, align 8
  %98 = getelementptr inbounds nuw %ASTNode, ptr %97, i32 0, i32 1
  %99 = load ptr, ptr %98, align 8
  %100 = load ptr, ptr %var_type, align 8
  call void @ir_set_var_type(ptr %99, ptr %100)
  br label %label_1934

label_1938:                                       ; preds = %label_1937
  %101 = load ptr, ptr %stmt, align 8
  %102 = getelementptr inbounds nuw %ASTNode, ptr %101, i32 0, i32 6
  %103 = load ptr, ptr %102, align 8
  %104 = call ptr @ptr_to_node(ptr %103)
  store ptr %104, ptr %init_node, align 8
  %105 = load i1, ptr %has_annotation, align 1
  %106 = icmp eq i1 %105, false
  br i1 %106, label %label_1941, label %label_1943

label_1943:                                       ; preds = %label_1941, %label_1938
  %107 = load ptr, ptr %init_node, align 8
  %108 = getelementptr inbounds nuw %ASTNode, ptr %107, i32 0, i32 0
  %109 = load i32, ptr %108, align 4
  %110 = icmp eq i32 %109, 22
  br i1 %110, label %label_1944, label %label_1945

label_1941:                                       ; preds = %label_1938
  %111 = load ptr, ptr %init_node, align 8
  %112 = call ptr @get_expr_type__Struct_ASTNode(ptr %111)
  store ptr %112, ptr %var_type, align 8
  br label %label_1943

label_1945:                                       ; preds = %label_1943
  call void @print(ptr @.str.s777)
  %113 = load ptr, ptr %stmt, align 8
  %114 = getelementptr inbounds nuw %ASTNode, ptr %113, i32 0, i32 1
  %115 = load ptr, ptr %114, align 8
  call void @print(ptr %115)
  call void @println(ptr @.str.s778)
  call void @exit(i32 1)
  br label %label_1946

label_1944:                                       ; preds = %label_1943
  %116 = load ptr, ptr %init_node, align 8
  %117 = getelementptr inbounds nuw %ASTNode, ptr %116, i32 0, i32 3
  %118 = load i32, ptr %117, align 4
  %119 = icmp eq i32 %118, 0
  br i1 %119, label %label_1947, label %label_1948

label_1948:                                       ; preds = %label_1944
  %120 = load ptr, ptr %init_node, align 8
  %121 = getelementptr inbounds nuw %ASTNode, ptr %120, i32 0, i32 1
  %122 = load ptr, ptr %121, align 8
  store ptr %122, ptr %init_val, align 8
  br label %label_1949

label_1947:                                       ; preds = %label_1944
  %123 = load ptr, ptr %init_node, align 8
  call void @collect_strings_expr__Struct_ASTNode(ptr %123)
  %124 = load ptr, ptr %init_node, align 8
  %125 = getelementptr inbounds nuw %ASTNode, ptr %124, i32 0, i32 2
  %126 = load ptr, ptr %125, align 8
  %127 = call ptr @str_concat(ptr @.str.s776, ptr %126)
  store ptr %127, ptr %init_val, align 8
  br label %label_1949

label_1949:                                       ; preds = %label_1948, %label_1947
  br label %label_1946

label_1946:                                       ; preds = %label_1945, %label_1949
  br label %label_1940

label_1952:                                       ; preds = %label_1955, %label_1934
  %128 = load ptr, ptr %stmt, align 8
  %129 = getelementptr inbounds nuw %ASTNode, ptr %128, i32 0, i32 8
  %130 = load ptr, ptr %129, align 8
  store ptr %130, ptr %stmt_ptr, align 8
  br label %label_1923

label_1950:                                       ; preds = %label_1934
  %131 = load ptr, ptr %stmt, align 8
  %132 = load ptr, ptr %stmt, align 8
  %133 = getelementptr inbounds nuw %ASTNode, ptr %132, i32 0, i32 7
  %134 = load ptr, ptr %133, align 8
  %135 = call ptr @get_declared_return_type__Struct_ASTNode_String(ptr %131, ptr %134)
  store ptr %135, ptr %ret_type, align 8
  %136 = load ptr, ptr %stmt, align 8
  %137 = getelementptr inbounds nuw %ASTNode, ptr %136, i32 0, i32 1
  %138 = load ptr, ptr %137, align 8
  %139 = call i32 @str_equals(ptr %138, ptr @.str.s779)
  %140 = icmp eq i32 %139, 1
  br i1 %140, label %label_1953, label %label_1955

label_1955:                                       ; preds = %label_1953, %label_1950
  %141 = load ptr, ptr %stmt, align 8
  %142 = call ptr @function_symbol_name__Struct_ASTNode(ptr %141)
  %143 = call ptr @fn_key__String(ptr %142)
  %144 = load ptr, ptr %ret_type, align 8
  call void @ir_set_var_type(ptr %143, ptr %144)
  %145 = load ptr, ptr %stmt, align 8
  call void @collect_strings_function__Struct_ASTNode(ptr %145)
  br label %label_1952

label_1953:                                       ; preds = %label_1950
  store ptr @.str.s780, ptr %ret_type, align 8
  br label %label_1955

label_1956:                                       ; preds = %label_1961, %label_1925
  %146 = load ptr, ptr %stmt_ptr2, align 8
  %147 = call i32 @str_equals(ptr %146, ptr @.str.s781)
  %148 = icmp eq i32 %147, 0
  br i1 %148, label %label_1957, label %label_1958

label_1958:                                       ; preds = %label_1956
  call void @ir_module_end()
  ret void

label_1957:                                       ; preds = %label_1956
  %149 = load ptr, ptr %stmt_ptr2, align 8
  %150 = call ptr @ptr_to_node(ptr %149)
  store ptr %150, ptr %stmt2, align 8
  %151 = load ptr, ptr %stmt2, align 8
  %152 = getelementptr inbounds nuw %ASTNode, ptr %151, i32 0, i32 0
  %153 = load i32, ptr %152, align 4
  %154 = icmp eq i32 %153, 4
  br i1 %154, label %label_1959, label %label_1961

label_1961:                                       ; preds = %label_1959, %label_1957
  %155 = load ptr, ptr %stmt2, align 8
  %156 = getelementptr inbounds nuw %ASTNode, ptr %155, i32 0, i32 8
  %157 = load ptr, ptr %156, align 8
  store ptr %157, ptr %stmt_ptr2, align 8
  br label %label_1956

label_1959:                                       ; preds = %label_1957
  %158 = load ptr, ptr %stmt2, align 8
  call void @generate_function__Struct_ASTNode(ptr %158)
  br label %label_1961
}

define ptr @sema_fn_key__String(ptr %0) {
entry:
  %name = alloca ptr, align 8
  store ptr %0, ptr %name, align 8
  %1 = load ptr, ptr %name, align 8
  %2 = call ptr @str_concat(ptr @.str.s782, ptr %1)
  ret ptr %2
}

define ptr @sema_mangle_type__Struct_TypeInfo(ptr %0) {
entry:
  %t = alloca ptr, align 8
  store ptr %0, ptr %t, align 8
  %1 = load ptr, ptr %t, align 8
  %2 = getelementptr inbounds nuw %TypeInfo, ptr %1, i32 0, i32 0
  %3 = load i32, ptr %2, align 4
  %4 = icmp eq i32 %3, 1
  br i1 %4, label %label_1962, label %label_1964

label_1964:                                       ; preds = %entry
  %5 = load ptr, ptr %t, align 8
  %6 = getelementptr inbounds nuw %TypeInfo, ptr %5, i32 0, i32 0
  %7 = load i32, ptr %6, align 4
  %8 = icmp eq i32 %7, 2
  br i1 %8, label %label_1965, label %label_1967

label_1962:                                       ; preds = %entry
  ret ptr @.str.s783

label_1967:                                       ; preds = %label_1964
  %9 = load ptr, ptr %t, align 8
  %10 = getelementptr inbounds nuw %TypeInfo, ptr %9, i32 0, i32 0
  %11 = load i32, ptr %10, align 4
  %12 = icmp eq i32 %11, 3
  br i1 %12, label %label_1968, label %label_1970

label_1965:                                       ; preds = %label_1964
  %13 = load ptr, ptr %t, align 8
  %14 = getelementptr inbounds nuw %TypeInfo, ptr %13, i32 0, i32 1
  %15 = load ptr, ptr %14, align 8
  ret ptr %15

label_1970:                                       ; preds = %label_1967
  %16 = load ptr, ptr %t, align 8
  %17 = getelementptr inbounds nuw %TypeInfo, ptr %16, i32 0, i32 0
  %18 = load i32, ptr %17, align 4
  %19 = icmp eq i32 %18, 4
  br i1 %19, label %label_1971, label %label_1973

label_1968:                                       ; preds = %label_1967
  ret ptr @.str.s784

label_1973:                                       ; preds = %label_1970
  %20 = load ptr, ptr %t, align 8
  %21 = getelementptr inbounds nuw %TypeInfo, ptr %20, i32 0, i32 0
  %22 = load i32, ptr %21, align 4
  %23 = icmp eq i32 %22, 5
  br i1 %23, label %label_1974, label %label_1976

label_1971:                                       ; preds = %label_1970
  ret ptr @.str.s785

label_1976:                                       ; preds = %label_1973
  %24 = load ptr, ptr %t, align 8
  %25 = getelementptr inbounds nuw %TypeInfo, ptr %24, i32 0, i32 0
  %26 = load i32, ptr %25, align 4
  %27 = icmp eq i32 %26, 6
  br i1 %27, label %label_1977, label %label_1979

label_1974:                                       ; preds = %label_1973
  ret ptr @.str.s786

label_1979:                                       ; preds = %label_1976
  %28 = load ptr, ptr %t, align 8
  %29 = getelementptr inbounds nuw %TypeInfo, ptr %28, i32 0, i32 0
  %30 = load i32, ptr %29, align 4
  %31 = icmp eq i32 %30, 7
  br i1 %31, label %label_1980, label %label_1982

label_1977:                                       ; preds = %label_1976
  ret ptr @.str.s787

label_1982:                                       ; preds = %label_1979
  %32 = load ptr, ptr %t, align 8
  %33 = getelementptr inbounds nuw %TypeInfo, ptr %32, i32 0, i32 0
  %34 = load i32, ptr %33, align 4
  %35 = icmp eq i32 %34, 8
  br i1 %35, label %label_1983, label %label_1985

label_1980:                                       ; preds = %label_1979
  ret ptr @.str.s788

label_1985:                                       ; preds = %label_1982
  %36 = load ptr, ptr %t, align 8
  %37 = getelementptr inbounds nuw %TypeInfo, ptr %36, i32 0, i32 0
  %38 = load i32, ptr %37, align 4
  %39 = icmp eq i32 %38, 9
  br i1 %39, label %label_1986, label %label_1988

label_1983:                                       ; preds = %label_1982
  %40 = load ptr, ptr %t, align 8
  %41 = getelementptr inbounds nuw %TypeInfo, ptr %40, i32 0, i32 1
  %42 = load ptr, ptr %41, align 8
  %43 = call ptr @str_concat(ptr @.str.s789, ptr %42)
  ret ptr %43

label_1988:                                       ; preds = %label_1985
  %44 = load ptr, ptr %t, align 8
  %45 = getelementptr inbounds nuw %TypeInfo, ptr %44, i32 0, i32 0
  %46 = load i32, ptr %45, align 4
  %47 = icmp eq i32 %46, 10
  br i1 %47, label %label_1989, label %label_1991

label_1986:                                       ; preds = %label_1985
  %48 = load ptr, ptr %t, align 8
  %49 = getelementptr inbounds nuw %TypeInfo, ptr %48, i32 0, i32 1
  %50 = load ptr, ptr %49, align 8
  %51 = call ptr @str_concat(ptr @.str.s790, ptr %50)
  ret ptr %51

label_1991:                                       ; preds = %label_1988
  %52 = load ptr, ptr %t, align 8
  %53 = getelementptr inbounds nuw %TypeInfo, ptr %52, i32 0, i32 0
  %54 = load i32, ptr %53, align 4
  %55 = icmp eq i32 %54, 11
  br i1 %55, label %label_1995, label %label_1997

label_1989:                                       ; preds = %label_1988
  %56 = load ptr, ptr %t, align 8
  %57 = getelementptr inbounds nuw %TypeInfo, ptr %56, i32 0, i32 3
  %58 = load ptr, ptr %57, align 8
  %59 = call i32 @str_equals(ptr %58, ptr @.str.s791)
  %60 = icmp eq i32 %59, 0
  br i1 %60, label %label_1992, label %label_1994

label_1994:                                       ; preds = %label_1989
  ret ptr @.str.s793

label_1992:                                       ; preds = %label_1989
  %61 = load ptr, ptr %t, align 8
  %62 = getelementptr inbounds nuw %TypeInfo, ptr %61, i32 0, i32 3
  %63 = load ptr, ptr %62, align 8
  %64 = call ptr @ptr_to_type(ptr %63)
  %65 = call ptr @sema_mangle_type__Struct_TypeInfo(ptr %64)
  %66 = call ptr @str_concat(ptr @.str.s792, ptr %65)
  ret ptr %66

label_1997:                                       ; preds = %label_1991
  ret ptr @.str.s797

label_1995:                                       ; preds = %label_1991
  %67 = load ptr, ptr %t, align 8
  %68 = getelementptr inbounds nuw %TypeInfo, ptr %67, i32 0, i32 3
  %69 = load ptr, ptr %68, align 8
  %70 = call i32 @str_equals(ptr %69, ptr @.str.s794)
  %71 = icmp eq i32 %70, 0
  br i1 %71, label %label_1998, label %label_2000

label_2000:                                       ; preds = %label_1995
  ret ptr @.str.s796

label_1998:                                       ; preds = %label_1995
  %72 = load ptr, ptr %t, align 8
  %73 = getelementptr inbounds nuw %TypeInfo, ptr %72, i32 0, i32 3
  %74 = load ptr, ptr %73, align 8
  %75 = call ptr @ptr_to_type(ptr %74)
  %76 = call ptr @sema_mangle_type__Struct_TypeInfo(ptr %75)
  %77 = call ptr @str_concat(ptr @.str.s795, ptr %76)
  ret ptr %77
}

define ptr @sema_param_signature__Struct_ASTNode_String(ptr %0, ptr %1) {
entry:
  %module = alloca ptr, align 8
  store ptr %0, ptr %module, align 8
  %param_ptr = alloca ptr, align 8
  store ptr %1, ptr %param_ptr, align 8
  %sig = alloca ptr, align 8
  %curr = alloca ptr, align 8
  %param = alloca ptr, align 8
  %param_t = alloca ptr, align 8
  store ptr @.str.s798, ptr %sig, align 8
  %2 = load ptr, ptr %param_ptr, align 8
  store ptr %2, ptr %curr, align 8
  br label %label_2001

label_2001:                                       ; preds = %label_2006, %entry
  %3 = load ptr, ptr %curr, align 8
  %4 = call i32 @str_equals(ptr %3, ptr @.str.s799)
  %5 = icmp eq i32 %4, 0
  br i1 %5, label %label_2002, label %label_2003

label_2003:                                       ; preds = %label_2001
  %6 = load ptr, ptr %sig, align 8
  %7 = call i32 @str_equals(ptr %6, ptr @.str.s802)
  %8 = icmp eq i32 %7, 1
  br i1 %8, label %label_2007, label %label_2009

label_2002:                                       ; preds = %label_2001
  %9 = load ptr, ptr %curr, align 8
  %10 = call ptr @ptr_to_node(ptr %9)
  store ptr %10, ptr %param, align 8
  %11 = load ptr, ptr %module, align 8
  %12 = load ptr, ptr %param, align 8
  %13 = getelementptr inbounds nuw %ASTNode, ptr %12, i32 0, i32 5
  %14 = load ptr, ptr %13, align 8
  %15 = call ptr @ptr_to_node(ptr %14)
  %16 = call ptr @sema_annotation_type__Struct_ASTNode_Struct_ASTNode(ptr %11, ptr %15)
  store ptr %16, ptr %param_t, align 8
  %17 = load ptr, ptr %sig, align 8
  %18 = call i32 @str_equals(ptr %17, ptr @.str.s800)
  %19 = icmp eq i32 %18, 1
  br i1 %19, label %label_2004, label %label_2005

label_2005:                                       ; preds = %label_2002
  %20 = load ptr, ptr %sig, align 8
  %21 = call ptr @str_concat(ptr %20, ptr @.str.s801)
  %22 = load ptr, ptr %param_t, align 8
  %23 = call ptr @sema_mangle_type__Struct_TypeInfo(ptr %22)
  %24 = call ptr @str_concat(ptr %21, ptr %23)
  store ptr %24, ptr %sig, align 8
  br label %label_2006

label_2004:                                       ; preds = %label_2002
  %25 = load ptr, ptr %param_t, align 8
  %26 = call ptr @sema_mangle_type__Struct_TypeInfo(ptr %25)
  store ptr %26, ptr %sig, align 8
  br label %label_2006

label_2006:                                       ; preds = %label_2005, %label_2004
  %27 = load ptr, ptr %param, align 8
  %28 = getelementptr inbounds nuw %ASTNode, ptr %27, i32 0, i32 8
  %29 = load ptr, ptr %28, align 8
  store ptr %29, ptr %curr, align 8
  br label %label_2001

label_2009:                                       ; preds = %label_2003
  %30 = load ptr, ptr %sig, align 8
  ret ptr %30

label_2007:                                       ; preds = %label_2003
  ret ptr @.str.s803
}

define ptr @sema_annotation_type__Struct_ASTNode_Struct_ASTNode(ptr %0, ptr %1) {
entry:
  %module = alloca ptr, align 8
  store ptr %0, ptr %module, align 8
  %tn = alloca ptr, align 8
  store ptr %1, ptr %tn, align 8
  %2 = load ptr, ptr %tn, align 8
  %3 = getelementptr inbounds nuw %ASTNode, ptr %2, i32 0, i32 3
  %4 = load i32, ptr %3, align 4
  %5 = icmp eq i32 %4, 1
  br i1 %5, label %label_2043, label %label_2045

label_2045:                                       ; preds = %entry
  %6 = load ptr, ptr %tn, align 8
  %7 = getelementptr inbounds nuw %ASTNode, ptr %6, i32 0, i32 4
  %8 = load i32, ptr %7, align 4
  %9 = icmp eq i32 %8, 1
  br i1 %9, label %label_2049, label %label_2051

label_2043:                                       ; preds = %entry
  %10 = load ptr, ptr %tn, align 8
  %11 = getelementptr inbounds nuw %ASTNode, ptr %10, i32 0, i32 5
  %12 = load ptr, ptr %11, align 8
  %13 = call i32 @str_equals(ptr %12, ptr @.str.s814)
  %14 = icmp eq i32 %13, 0
  br i1 %14, label %label_2046, label %label_2048

label_2048:                                       ; preds = %label_2043
  %15 = call ptr @type_invalid__Void()
  %16 = call ptr @type_array__Struct_TypeInfo(ptr %15)
  ret ptr %16

label_2046:                                       ; preds = %label_2043
  %17 = load ptr, ptr %module, align 8
  %18 = load ptr, ptr %tn, align 8
  %19 = getelementptr inbounds nuw %ASTNode, ptr %18, i32 0, i32 5
  %20 = load ptr, ptr %19, align 8
  %21 = call ptr @ptr_to_node(ptr %20)
  %22 = call ptr @sema_annotation_type__Struct_ASTNode_Struct_ASTNode(ptr %17, ptr %21)
  %23 = call ptr @type_array__Struct_TypeInfo(ptr %22)
  ret ptr %23

label_2051:                                       ; preds = %label_2045
  %24 = load ptr, ptr %tn, align 8
  %25 = getelementptr inbounds nuw %ASTNode, ptr %24, i32 0, i32 1
  %26 = load ptr, ptr %25, align 8
  %27 = call i32 @str_equals(ptr %26, ptr @.str.s816)
  %28 = icmp eq i32 %27, 1
  br i1 %28, label %label_2055, label %label_2057

label_2049:                                       ; preds = %label_2045
  %29 = load ptr, ptr %tn, align 8
  %30 = getelementptr inbounds nuw %ASTNode, ptr %29, i32 0, i32 5
  %31 = load ptr, ptr %30, align 8
  %32 = call i32 @str_equals(ptr %31, ptr @.str.s815)
  %33 = icmp eq i32 %32, 0
  br i1 %33, label %label_2052, label %label_2054

label_2054:                                       ; preds = %label_2049
  %34 = call ptr @type_invalid__Void()
  %35 = call ptr @type_list__Struct_TypeInfo(ptr %34)
  ret ptr %35

label_2052:                                       ; preds = %label_2049
  %36 = load ptr, ptr %module, align 8
  %37 = load ptr, ptr %tn, align 8
  %38 = getelementptr inbounds nuw %ASTNode, ptr %37, i32 0, i32 5
  %39 = load ptr, ptr %38, align 8
  %40 = call ptr @ptr_to_node(ptr %39)
  %41 = call ptr @sema_annotation_type__Struct_ASTNode_Struct_ASTNode(ptr %36, ptr %40)
  %42 = call ptr @type_list__Struct_TypeInfo(ptr %41)
  ret ptr %42

label_2057:                                       ; preds = %label_2051
  %43 = load ptr, ptr %tn, align 8
  %44 = getelementptr inbounds nuw %ASTNode, ptr %43, i32 0, i32 1
  %45 = load ptr, ptr %44, align 8
  %46 = call i32 @str_equals(ptr %45, ptr @.str.s817)
  %47 = icmp eq i32 %46, 1
  br i1 %47, label %label_2058, label %label_2060

label_2055:                                       ; preds = %label_2051
  %48 = call ptr @type_int__Void()
  ret ptr %48

label_2060:                                       ; preds = %label_2057
  %49 = load ptr, ptr %tn, align 8
  %50 = getelementptr inbounds nuw %ASTNode, ptr %49, i32 0, i32 1
  %51 = load ptr, ptr %50, align 8
  %52 = call i32 @str_equals(ptr %51, ptr @.str.s818)
  %53 = icmp eq i32 %52, 1
  br i1 %53, label %label_2061, label %label_2063

label_2058:                                       ; preds = %label_2057
  %54 = call ptr @type_float__Void()
  ret ptr %54

label_2063:                                       ; preds = %label_2060
  %55 = load ptr, ptr %tn, align 8
  %56 = getelementptr inbounds nuw %ASTNode, ptr %55, i32 0, i32 1
  %57 = load ptr, ptr %56, align 8
  %58 = call i32 @str_equals(ptr %57, ptr @.str.s819)
  %59 = icmp eq i32 %58, 1
  br i1 %59, label %label_2064, label %label_2066

label_2061:                                       ; preds = %label_2060
  %60 = call ptr @type_bool__Void()
  ret ptr %60

label_2066:                                       ; preds = %label_2063
  %61 = load ptr, ptr %tn, align 8
  %62 = getelementptr inbounds nuw %ASTNode, ptr %61, i32 0, i32 1
  %63 = load ptr, ptr %62, align 8
  %64 = call i32 @str_equals(ptr %63, ptr @.str.s820)
  %65 = icmp eq i32 %64, 1
  br i1 %65, label %label_2067, label %label_2069

label_2064:                                       ; preds = %label_2063
  %66 = call ptr @type_string__Void()
  ret ptr %66

label_2069:                                       ; preds = %label_2066
  %67 = load ptr, ptr %tn, align 8
  %68 = getelementptr inbounds nuw %ASTNode, ptr %67, i32 0, i32 1
  %69 = load ptr, ptr %68, align 8
  %70 = call i32 @str_equals(ptr %69, ptr @.str.s821)
  %71 = icmp eq i32 %70, 1
  br i1 %71, label %label_2070, label %label_2072

label_2067:                                       ; preds = %label_2066
  %72 = call ptr @type_char__Void()
  ret ptr %72

label_2072:                                       ; preds = %label_2069
  %73 = load ptr, ptr %tn, align 8
  %74 = getelementptr inbounds nuw %ASTNode, ptr %73, i32 0, i32 1
  %75 = load ptr, ptr %74, align 8
  %76 = call i32 @str_equals(ptr %75, ptr @.str.s822)
  %77 = icmp eq i32 %76, 1
  br i1 %77, label %label_2073, label %label_2075

label_2070:                                       ; preds = %label_2069
  %78 = call ptr @type_i8__Void()
  ret ptr %78

label_2075:                                       ; preds = %label_2072
  %79 = load ptr, ptr %tn, align 8
  %80 = getelementptr inbounds nuw %ASTNode, ptr %79, i32 0, i32 1
  %81 = load ptr, ptr %80, align 8
  %82 = call i32 @str_equals(ptr %81, ptr @.str.s823)
  %83 = icmp eq i32 %82, 1
  br i1 %83, label %label_2076, label %label_2078

label_2073:                                       ; preds = %label_2072
  %84 = call ptr @type_i16__Void()
  ret ptr %84

label_2078:                                       ; preds = %label_2075
  %85 = load ptr, ptr %tn, align 8
  %86 = getelementptr inbounds nuw %ASTNode, ptr %85, i32 0, i32 1
  %87 = load ptr, ptr %86, align 8
  %88 = call i32 @str_equals(ptr %87, ptr @.str.s824)
  %89 = icmp eq i32 %88, 1
  br i1 %89, label %label_2079, label %label_2081

label_2076:                                       ; preds = %label_2075
  %90 = call ptr @type_i64__Void()
  ret ptr %90

label_2081:                                       ; preds = %label_2078
  %91 = load ptr, ptr %tn, align 8
  %92 = getelementptr inbounds nuw %ASTNode, ptr %91, i32 0, i32 1
  %93 = load ptr, ptr %92, align 8
  %94 = call i32 @str_equals(ptr %93, ptr @.str.s825)
  %95 = icmp eq i32 %94, 1
  br i1 %95, label %label_2082, label %label_2084

label_2079:                                       ; preds = %label_2078
  %96 = call ptr @type_isize__Void()
  ret ptr %96

label_2084:                                       ; preds = %label_2081
  %97 = load ptr, ptr %tn, align 8
  %98 = getelementptr inbounds nuw %ASTNode, ptr %97, i32 0, i32 1
  %99 = load ptr, ptr %98, align 8
  %100 = call i32 @str_equals(ptr %99, ptr @.str.s826)
  %101 = icmp eq i32 %100, 1
  br i1 %101, label %label_2085, label %label_2087

label_2082:                                       ; preds = %label_2081
  %102 = call ptr @type_u8__Void()
  ret ptr %102

label_2087:                                       ; preds = %label_2084
  %103 = load ptr, ptr %tn, align 8
  %104 = getelementptr inbounds nuw %ASTNode, ptr %103, i32 0, i32 1
  %105 = load ptr, ptr %104, align 8
  %106 = call i32 @str_equals(ptr %105, ptr @.str.s827)
  %107 = icmp eq i32 %106, 1
  br i1 %107, label %label_2088, label %label_2090

label_2085:                                       ; preds = %label_2084
  %108 = call ptr @type_u16__Void()
  ret ptr %108

label_2090:                                       ; preds = %label_2087
  %109 = load ptr, ptr %tn, align 8
  %110 = getelementptr inbounds nuw %ASTNode, ptr %109, i32 0, i32 1
  %111 = load ptr, ptr %110, align 8
  %112 = call i32 @str_equals(ptr %111, ptr @.str.s828)
  %113 = icmp eq i32 %112, 1
  br i1 %113, label %label_2091, label %label_2093

label_2088:                                       ; preds = %label_2087
  %114 = call ptr @type_u32__Void()
  ret ptr %114

label_2093:                                       ; preds = %label_2090
  %115 = load ptr, ptr %tn, align 8
  %116 = getelementptr inbounds nuw %ASTNode, ptr %115, i32 0, i32 1
  %117 = load ptr, ptr %116, align 8
  %118 = call i32 @str_equals(ptr %117, ptr @.str.s829)
  %119 = icmp eq i32 %118, 1
  br i1 %119, label %label_2094, label %label_2096

label_2091:                                       ; preds = %label_2090
  %120 = call ptr @type_u64__Void()
  ret ptr %120

label_2096:                                       ; preds = %label_2093
  %121 = load ptr, ptr %tn, align 8
  %122 = getelementptr inbounds nuw %ASTNode, ptr %121, i32 0, i32 1
  %123 = load ptr, ptr %122, align 8
  %124 = call i32 @str_equals(ptr %123, ptr @.str.s830)
  %125 = icmp eq i32 %124, 1
  br i1 %125, label %label_2097, label %label_2099

label_2094:                                       ; preds = %label_2093
  %126 = call ptr @type_usize__Void()
  ret ptr %126

label_2099:                                       ; preds = %label_2096
  %127 = load ptr, ptr %module, align 8
  %128 = load ptr, ptr %tn, align 8
  %129 = getelementptr inbounds nuw %ASTNode, ptr %128, i32 0, i32 1
  %130 = load ptr, ptr %129, align 8
  %131 = call i1 @sema_has_enum__Struct_ASTNode_String(ptr %127, ptr %130)
  br i1 %131, label %label_2100, label %label_2102

label_2097:                                       ; preds = %label_2096
  %132 = call ptr @type_void__Void()
  ret ptr %132

label_2102:                                       ; preds = %label_2099
  %133 = load ptr, ptr %module, align 8
  %134 = load ptr, ptr %tn, align 8
  %135 = getelementptr inbounds nuw %ASTNode, ptr %134, i32 0, i32 1
  %136 = load ptr, ptr %135, align 8
  %137 = call i1 @sema_has_struct__Struct_ASTNode_String(ptr %133, ptr %136)
  br i1 %137, label %label_2103, label %label_2105

label_2100:                                       ; preds = %label_2099
  %138 = load ptr, ptr %tn, align 8
  %139 = getelementptr inbounds nuw %ASTNode, ptr %138, i32 0, i32 1
  %140 = load ptr, ptr %139, align 8
  %141 = call ptr @type_enum__String(ptr %140)
  ret ptr %141

label_2105:                                       ; preds = %label_2102
  %142 = load ptr, ptr %tn, align 8
  %143 = getelementptr inbounds nuw %ASTNode, ptr %142, i32 0, i32 1
  %144 = load ptr, ptr %143, align 8
  %145 = call ptr @str_concat(ptr @.str.s831, ptr %144)
  call void @sema_error__String(ptr %145)
  %146 = call ptr @type_invalid__Void()
  ret ptr %146

label_2103:                                       ; preds = %label_2102
  %147 = load ptr, ptr %tn, align 8
  %148 = getelementptr inbounds nuw %ASTNode, ptr %147, i32 0, i32 1
  %149 = load ptr, ptr %148, align 8
  %150 = call ptr @type_struct__String(ptr %149)
  ret ptr %150
}

define ptr @sema_function_symbol__Struct_ASTNode_Struct_ASTNode(ptr %0, ptr %1) {
entry:
  %module = alloca ptr, align 8
  store ptr %0, ptr %module, align 8
  %fn_node = alloca ptr, align 8
  store ptr %1, ptr %fn_node, align 8
  %2 = load ptr, ptr %fn_node, align 8
  %3 = getelementptr inbounds nuw %ASTNode, ptr %2, i32 0, i32 0
  %4 = load i32, ptr %3, align 4
  %5 = icmp eq i32 %4, 2
  br i1 %5, label %label_2010, label %label_2012

label_2012:                                       ; preds = %entry
  %6 = load ptr, ptr %fn_node, align 8
  %7 = getelementptr inbounds nuw %ASTNode, ptr %6, i32 0, i32 1
  %8 = load ptr, ptr %7, align 8
  %9 = call i32 @str_equals(ptr %8, ptr @.str.s804)
  %10 = icmp eq i32 %9, 1
  br i1 %10, label %label_2013, label %label_2015

label_2010:                                       ; preds = %entry
  %11 = load ptr, ptr %fn_node, align 8
  %12 = getelementptr inbounds nuw %ASTNode, ptr %11, i32 0, i32 1
  %13 = load ptr, ptr %12, align 8
  ret ptr %13

label_2015:                                       ; preds = %label_2012
  %14 = load ptr, ptr %fn_node, align 8
  %15 = getelementptr inbounds nuw %ASTNode, ptr %14, i32 0, i32 1
  %16 = load ptr, ptr %15, align 8
  %17 = call ptr @str_concat(ptr %16, ptr @.str.s806)
  %18 = load ptr, ptr %module, align 8
  %19 = load ptr, ptr %fn_node, align 8
  %20 = getelementptr inbounds nuw %ASTNode, ptr %19, i32 0, i32 5
  %21 = load ptr, ptr %20, align 8
  %22 = call ptr @sema_param_signature__Struct_ASTNode_String(ptr %18, ptr %21)
  %23 = call ptr @str_concat(ptr %17, ptr %22)
  ret ptr %23

label_2013:                                       ; preds = %label_2012
  ret ptr @.str.s805
}

define i32 @sema_function_symbol_count__Struct_ASTNode_String(ptr %0, ptr %1) {
entry:
  %module = alloca ptr, align 8
  store ptr %0, ptr %module, align 8
  %symbol = alloca ptr, align 8
  store ptr %1, ptr %symbol, align 8
  %count = alloca i32, align 4
  %stmt_ptr = alloca ptr, align 8
  %stmt = alloca ptr, align 8
  store i32 0, ptr %count, align 4
  %2 = load ptr, ptr %module, align 8
  %3 = getelementptr inbounds nuw %ASTNode, ptr %2, i32 0, i32 5
  %4 = load ptr, ptr %3, align 8
  store ptr %4, ptr %stmt_ptr, align 8
  br label %label_2016

label_2016:                                       ; preds = %label_2023, %entry
  %5 = load ptr, ptr %stmt_ptr, align 8
  %6 = call i32 @str_equals(ptr %5, ptr @.str.s807)
  %7 = icmp eq i32 %6, 0
  br i1 %7, label %label_2017, label %label_2018

label_2018:                                       ; preds = %label_2016
  %8 = load i32, ptr %count, align 4
  ret i32 %8

label_2017:                                       ; preds = %label_2016
  %9 = load ptr, ptr %stmt_ptr, align 8
  %10 = call ptr @ptr_to_node(ptr %9)
  store ptr %10, ptr %stmt, align 8
  %sc.90 = alloca i1, align 1
  %11 = load ptr, ptr %stmt, align 8
  %12 = getelementptr inbounds nuw %ASTNode, ptr %11, i32 0, i32 0
  %13 = load i32, ptr %12, align 4
  %14 = icmp eq i32 %13, 4
  store i1 %14, ptr %sc.90, align 1
  br i1 %14, label %label_2020, label %label_2019

label_2019:                                       ; preds = %label_2017
  %15 = load ptr, ptr %stmt, align 8
  %16 = getelementptr inbounds nuw %ASTNode, ptr %15, i32 0, i32 0
  %17 = load i32, ptr %16, align 4
  %18 = icmp eq i32 %17, 2
  store i1 %18, ptr %sc.90, align 1
  br label %label_2020

label_2020:                                       ; preds = %label_2019, %label_2017
  %19 = load i1, ptr %sc.90, align 1
  br i1 %19, label %label_2021, label %label_2023

label_2023:                                       ; preds = %label_2026, %label_2020
  %20 = load ptr, ptr %stmt, align 8
  %21 = getelementptr inbounds nuw %ASTNode, ptr %20, i32 0, i32 8
  %22 = load ptr, ptr %21, align 8
  store ptr %22, ptr %stmt_ptr, align 8
  br label %label_2016

label_2021:                                       ; preds = %label_2020
  %23 = load ptr, ptr %module, align 8
  %24 = load ptr, ptr %stmt, align 8
  %25 = call ptr @sema_function_symbol__Struct_ASTNode_Struct_ASTNode(ptr %23, ptr %24)
  %26 = load ptr, ptr %symbol, align 8
  %27 = call i32 @str_equals(ptr %25, ptr %26)
  %28 = icmp eq i32 %27, 1
  br i1 %28, label %label_2024, label %label_2026

label_2026:                                       ; preds = %label_2024, %label_2021
  br label %label_2023

label_2024:                                       ; preds = %label_2021
  %29 = load i32, ptr %count, align 4
  %30 = add i32 %29, 1
  store i32 %30, ptr %count, align 4
  br label %label_2026
}

define ptr @sema_overload_key__Struct_ASTNode_Struct_ASTNode(ptr %0, ptr %1) {
entry:
  %module = alloca ptr, align 8
  store ptr %0, ptr %module, align 8
  %fn_node = alloca ptr, align 8
  store ptr %1, ptr %fn_node, align 8
  %2 = load ptr, ptr %module, align 8
  %3 = load ptr, ptr %fn_node, align 8
  %4 = call ptr @sema_function_symbol__Struct_ASTNode_Struct_ASTNode(ptr %2, ptr %3)
  %5 = call ptr @sema_fn_key__String(ptr %4)
  ret ptr %5
}

define void @sema_error__String(ptr %0) {
entry:
  %message = alloca ptr, align 8
  store ptr %0, ptr %message, align 8
  call void @print(ptr @.str.s808)
  %1 = load ptr, ptr %message, align 8
  call void @println(ptr %1)
  call void @exit(i32 1)
  ret void
}

define void @sema_type_error__String_Struct_TypeInfo_Struct_TypeInfo(ptr %0, ptr %1, ptr %2) {
entry:
  %context = alloca ptr, align 8
  store ptr %0, ptr %context, align 8
  %expected = alloca ptr, align 8
  store ptr %1, ptr %expected, align 8
  %actual = alloca ptr, align 8
  store ptr %2, ptr %actual, align 8
  call void @print(ptr @.str.s809)
  %3 = load ptr, ptr %context, align 8
  call void @print(ptr %3)
  call void @print(ptr @.str.s810)
  %4 = load ptr, ptr %expected, align 8
  %5 = call ptr @type_display__Struct_TypeInfo(ptr %4)
  call void @print(ptr %5)
  call void @print(ptr @.str.s811)
  %6 = load ptr, ptr %actual, align 8
  %7 = call ptr @type_display__Struct_TypeInfo(ptr %6)
  call void @println(ptr %7)
  call void @exit(i32 1)
  ret void
}

define i1 @sema_has_struct__Struct_ASTNode_String(ptr %0, ptr %1) {
entry:
  %module = alloca ptr, align 8
  store ptr %0, ptr %module, align 8
  %name = alloca ptr, align 8
  store ptr %1, ptr %name, align 8
  %stmt_ptr = alloca ptr, align 8
  %stmt = alloca ptr, align 8
  %2 = load ptr, ptr %module, align 8
  %3 = getelementptr inbounds nuw %ASTNode, ptr %2, i32 0, i32 5
  %4 = load ptr, ptr %3, align 8
  store ptr %4, ptr %stmt_ptr, align 8
  br label %label_2027

label_2027:                                       ; preds = %label_2034, %entry
  %5 = load ptr, ptr %stmt_ptr, align 8
  %6 = call i32 @str_equals(ptr %5, ptr @.str.s812)
  %7 = icmp eq i32 %6, 0
  br i1 %7, label %label_2028, label %label_2029

label_2029:                                       ; preds = %label_2027
  ret i1 false

label_2028:                                       ; preds = %label_2027
  %8 = load ptr, ptr %stmt_ptr, align 8
  %9 = call ptr @ptr_to_node(ptr %8)
  store ptr %9, ptr %stmt, align 8
  %sc.91 = alloca i1, align 1
  %10 = load ptr, ptr %stmt, align 8
  %11 = getelementptr inbounds nuw %ASTNode, ptr %10, i32 0, i32 0
  %12 = load i32, ptr %11, align 4
  %13 = icmp eq i32 %12, 5
  store i1 %13, ptr %sc.91, align 1
  br i1 %13, label %label_2030, label %label_2031

label_2031:                                       ; preds = %label_2030, %label_2028
  %14 = load i1, ptr %sc.91, align 1
  br i1 %14, label %label_2032, label %label_2034

label_2030:                                       ; preds = %label_2028
  %15 = load ptr, ptr %stmt, align 8
  %16 = getelementptr inbounds nuw %ASTNode, ptr %15, i32 0, i32 1
  %17 = load ptr, ptr %16, align 8
  %18 = load ptr, ptr %name, align 8
  %19 = call i32 @str_equals(ptr %17, ptr %18)
  %20 = icmp eq i32 %19, 1
  store i1 %20, ptr %sc.91, align 1
  br label %label_2031

label_2034:                                       ; preds = %label_2031
  %21 = load ptr, ptr %stmt, align 8
  %22 = getelementptr inbounds nuw %ASTNode, ptr %21, i32 0, i32 8
  %23 = load ptr, ptr %22, align 8
  store ptr %23, ptr %stmt_ptr, align 8
  br label %label_2027

label_2032:                                       ; preds = %label_2031
  ret i1 true
}

define i1 @sema_has_enum__Struct_ASTNode_String(ptr %0, ptr %1) {
entry:
  %module = alloca ptr, align 8
  store ptr %0, ptr %module, align 8
  %name = alloca ptr, align 8
  store ptr %1, ptr %name, align 8
  %stmt_ptr = alloca ptr, align 8
  %stmt = alloca ptr, align 8
  %2 = load ptr, ptr %module, align 8
  %3 = getelementptr inbounds nuw %ASTNode, ptr %2, i32 0, i32 5
  %4 = load ptr, ptr %3, align 8
  store ptr %4, ptr %stmt_ptr, align 8
  br label %label_2035

label_2035:                                       ; preds = %label_2042, %entry
  %5 = load ptr, ptr %stmt_ptr, align 8
  %6 = call i32 @str_equals(ptr %5, ptr @.str.s813)
  %7 = icmp eq i32 %6, 0
  br i1 %7, label %label_2036, label %label_2037

label_2037:                                       ; preds = %label_2035
  ret i1 false

label_2036:                                       ; preds = %label_2035
  %8 = load ptr, ptr %stmt_ptr, align 8
  %9 = call ptr @ptr_to_node(ptr %8)
  store ptr %9, ptr %stmt, align 8
  %sc.92 = alloca i1, align 1
  %10 = load ptr, ptr %stmt, align 8
  %11 = getelementptr inbounds nuw %ASTNode, ptr %10, i32 0, i32 0
  %12 = load i32, ptr %11, align 4
  %13 = icmp eq i32 %12, 6
  store i1 %13, ptr %sc.92, align 1
  br i1 %13, label %label_2038, label %label_2039

label_2039:                                       ; preds = %label_2038, %label_2036
  %14 = load i1, ptr %sc.92, align 1
  br i1 %14, label %label_2040, label %label_2042

label_2038:                                       ; preds = %label_2036
  %15 = load ptr, ptr %stmt, align 8
  %16 = getelementptr inbounds nuw %ASTNode, ptr %15, i32 0, i32 1
  %17 = load ptr, ptr %16, align 8
  %18 = load ptr, ptr %name, align 8
  %19 = call i32 @str_equals(ptr %17, ptr %18)
  %20 = icmp eq i32 %19, 1
  store i1 %20, ptr %sc.92, align 1
  br label %label_2039

label_2042:                                       ; preds = %label_2039
  %21 = load ptr, ptr %stmt, align 8
  %22 = getelementptr inbounds nuw %ASTNode, ptr %21, i32 0, i32 8
  %23 = load ptr, ptr %22, align 8
  store ptr %23, ptr %stmt_ptr, align 8
  br label %label_2035

label_2040:                                       ; preds = %label_2039
  ret i1 true
}

define ptr @sema_declared_return_type__Struct_ASTNode_String(ptr %0, ptr %1) {
entry:
  %module = alloca ptr, align 8
  store ptr %0, ptr %module, align 8
  %ret_child = alloca ptr, align 8
  store ptr %1, ptr %ret_child, align 8
  %2 = load ptr, ptr %ret_child, align 8
  %3 = call i32 @str_equals(ptr %2, ptr @.str.s832)
  %4 = icmp eq i32 %3, 0
  br i1 %4, label %label_2106, label %label_2108

label_2108:                                       ; preds = %entry
  %5 = call ptr @type_void__Void()
  ret ptr %5

label_2106:                                       ; preds = %entry
  %6 = load ptr, ptr %module, align 8
  %7 = load ptr, ptr %ret_child, align 8
  %8 = call ptr @ptr_to_node(ptr %7)
  %9 = call ptr @sema_annotation_type__Struct_ASTNode_Struct_ASTNode(ptr %6, ptr %8)
  ret ptr %9
}

define i1 @sema_enum_matches_int__Struct_TypeInfo_Struct_TypeInfo(ptr %0, ptr %1) {
entry:
  %a = alloca ptr, align 8
  store ptr %0, ptr %a, align 8
  %b = alloca ptr, align 8
  store ptr %1, ptr %b, align 8
  %2 = load ptr, ptr %a, align 8
  %3 = getelementptr inbounds nuw %TypeInfo, ptr %2, i32 0, i32 0
  %4 = load i32, ptr %3, align 4
  %5 = icmp ne i32 %4, 9
  br i1 %5, label %label_2109, label %label_2111

label_2111:                                       ; preds = %entry
  %6 = load ptr, ptr %b, align 8
  %7 = getelementptr inbounds nuw %TypeInfo, ptr %6, i32 0, i32 0
  %8 = load i32, ptr %7, align 4
  %9 = icmp ne i32 %8, 2
  br i1 %9, label %label_2112, label %label_2114

label_2109:                                       ; preds = %entry
  ret i1 false

label_2114:                                       ; preds = %label_2111
  %10 = load ptr, ptr %b, align 8
  %11 = getelementptr inbounds nuw %TypeInfo, ptr %10, i32 0, i32 1
  %12 = load ptr, ptr %11, align 8
  %13 = call i32 @str_equals(ptr %12, ptr @.str.s833)
  %14 = icmp eq i32 %13, 1
  ret i1 %14

label_2112:                                       ; preds = %label_2111
  ret i1 false
}

define i1 @sema_types_match__Struct_TypeInfo_Struct_TypeInfo(ptr %0, ptr %1) {
entry:
  %expected = alloca ptr, align 8
  store ptr %0, ptr %expected, align 8
  %actual = alloca ptr, align 8
  store ptr %1, ptr %actual, align 8
  %2 = load ptr, ptr %expected, align 8
  %3 = load ptr, ptr %actual, align 8
  %4 = call i1 @type_equals__Struct_TypeInfo_Struct_TypeInfo(ptr %2, ptr %3)
  br i1 %4, label %label_2115, label %label_2117

label_2117:                                       ; preds = %entry
  %5 = load ptr, ptr %expected, align 8
  %6 = load ptr, ptr %actual, align 8
  %7 = call i1 @sema_enum_matches_int__Struct_TypeInfo_Struct_TypeInfo(ptr %5, ptr %6)
  br i1 %7, label %label_2118, label %label_2120

label_2115:                                       ; preds = %entry
  ret i1 true

label_2120:                                       ; preds = %label_2117
  %8 = load ptr, ptr %actual, align 8
  %9 = load ptr, ptr %expected, align 8
  %10 = call i1 @sema_enum_matches_int__Struct_TypeInfo_Struct_TypeInfo(ptr %8, ptr %9)
  br i1 %10, label %label_2121, label %label_2123

label_2118:                                       ; preds = %label_2117
  ret i1 true

label_2123:                                       ; preds = %label_2120
  ret i1 false

label_2121:                                       ; preds = %label_2120
  ret i1 true
}

define void @sema_expect_assignable__String_Struct_TypeInfo_Struct_TypeInfo(ptr %0, ptr %1, ptr %2) {
entry:
  %context = alloca ptr, align 8
  store ptr %0, ptr %context, align 8
  %expected = alloca ptr, align 8
  store ptr %1, ptr %expected, align 8
  %actual = alloca ptr, align 8
  store ptr %2, ptr %actual, align 8
  %3 = load ptr, ptr %expected, align 8
  %4 = load ptr, ptr %actual, align 8
  %5 = call i1 @sema_types_match__Struct_TypeInfo_Struct_TypeInfo(ptr %3, ptr %4)
  %6 = icmp eq i1 %5, false
  br i1 %6, label %label_2124, label %label_2126

label_2126:                                       ; preds = %label_2124, %entry
  ret void

label_2124:                                       ; preds = %entry
  %7 = load ptr, ptr %context, align 8
  %8 = load ptr, ptr %expected, align 8
  %9 = load ptr, ptr %actual, align 8
  call void @sema_type_error__String_Struct_TypeInfo_Struct_TypeInfo(ptr %7, ptr %8, ptr %9)
  br label %label_2126
}

define i1 @sema_is_int_literal__Struct_ASTNode(ptr %0) {
entry:
  %e = alloca ptr, align 8
  store ptr %0, ptr %e, align 8
  %sc.93 = alloca i1, align 1
  %1 = load ptr, ptr %e, align 8
  %2 = getelementptr inbounds nuw %ASTNode, ptr %1, i32 0, i32 0
  %3 = load i32, ptr %2, align 4
  %4 = icmp eq i32 %3, 22
  store i1 %4, ptr %sc.93, align 1
  br i1 %4, label %label_2127, label %label_2128

label_2128:                                       ; preds = %label_2127, %entry
  %5 = load i1, ptr %sc.93, align 1
  ret i1 %5

label_2127:                                       ; preds = %entry
  %6 = load ptr, ptr %e, align 8
  %7 = getelementptr inbounds nuw %ASTNode, ptr %6, i32 0, i32 3
  %8 = load i32, ptr %7, align 4
  %9 = icmp eq i32 %8, 2
  store i1 %9, ptr %sc.93, align 1
  br label %label_2128
}

define void @sema_move_operand__Struct_ASTNode(ptr %0) {
entry:
  %node = alloca ptr, align 8
  store ptr %0, ptr %node, align 8
  %1 = load ptr, ptr %node, align 8
  %2 = getelementptr inbounds nuw %ASTNode, ptr %1, i32 0, i32 0
  %3 = load i32, ptr %2, align 4
  %4 = icmp eq i32 %3, 23
  br i1 %4, label %label_2129, label %label_2131

label_2131:                                       ; preds = %label_2134, %entry
  ret void

label_2129:                                       ; preds = %entry
  %5 = load ptr, ptr %node, align 8
  %6 = call ptr @node_get_type__Struct_ASTNode(ptr %5)
  %7 = call i1 @type_is_move_only__Struct_TypeInfo(ptr %6)
  br i1 %7, label %label_2132, label %label_2134

label_2134:                                       ; preds = %label_2137, %label_2129
  br label %label_2131

label_2132:                                       ; preds = %label_2129
  %8 = load ptr, ptr %node, align 8
  %9 = getelementptr inbounds nuw %ASTNode, ptr %8, i32 0, i32 1
  %10 = load ptr, ptr %9, align 8
  %11 = call i32 @ir_is_borrowed(ptr %10)
  %12 = icmp eq i32 %11, 1
  br i1 %12, label %label_2135, label %label_2137

label_2137:                                       ; preds = %label_2135, %label_2132
  %13 = load ptr, ptr %node, align 8
  %14 = getelementptr inbounds nuw %ASTNode, ptr %13, i32 0, i32 1
  %15 = load ptr, ptr %14, align 8
  call void @ir_mark_moved(ptr %15)
  br label %label_2134

label_2135:                                       ; preds = %label_2132
  %16 = load ptr, ptr %node, align 8
  %17 = getelementptr inbounds nuw %ASTNode, ptr %16, i32 0, i32 1
  %18 = load ptr, ptr %17, align 8
  %19 = call ptr @str_concat(ptr @.str.s834, ptr %18)
  call void @sema_error__String(ptr %19)
  br label %label_2137
}

define ptr @sema_check_value__Struct_ASTNode_Struct_ASTNode_Struct_TypeInfo_String(ptr %0, ptr %1, ptr %2, ptr %3) {
entry:
  %module = alloca ptr, align 8
  store ptr %0, ptr %module, align 8
  %val_node = alloca ptr, align 8
  store ptr %1, ptr %val_node, align 8
  %expected = alloca ptr, align 8
  store ptr %2, ptr %expected, align 8
  %context = alloca ptr, align 8
  store ptr %3, ptr %context, align 8
  %actual = alloca ptr, align 8
  %sc.94 = alloca i1, align 1
  %sc.95 = alloca i1, align 1
  %4 = load ptr, ptr %expected, align 8
  %5 = call i1 @type_is_valid__Struct_TypeInfo(ptr %4)
  store i1 %5, ptr %sc.95, align 1
  br i1 %5, label %label_2140, label %label_2141

label_2141:                                       ; preds = %label_2140, %entry
  %6 = load i1, ptr %sc.95, align 1
  store i1 %6, ptr %sc.94, align 1
  br i1 %6, label %label_2138, label %label_2139

label_2140:                                       ; preds = %entry
  %7 = load ptr, ptr %expected, align 8
  %8 = getelementptr inbounds nuw %TypeInfo, ptr %7, i32 0, i32 0
  %9 = load i32, ptr %8, align 4
  %10 = icmp eq i32 %9, 2
  store i1 %10, ptr %sc.95, align 1
  br label %label_2141

label_2139:                                       ; preds = %label_2138, %label_2141
  %11 = load i1, ptr %sc.94, align 1
  br i1 %11, label %label_2142, label %label_2144

label_2138:                                       ; preds = %label_2141
  %12 = load ptr, ptr %val_node, align 8
  %13 = call i1 @sema_is_int_literal__Struct_ASTNode(ptr %12)
  store i1 %13, ptr %sc.94, align 1
  br label %label_2139

label_2144:                                       ; preds = %label_2139
  %14 = load ptr, ptr %module, align 8
  %15 = load ptr, ptr %val_node, align 8
  %16 = call ptr @sema_expr__Struct_ASTNode_Struct_ASTNode(ptr %14, ptr %15)
  store ptr %16, ptr %actual, align 8
  %17 = load ptr, ptr %context, align 8
  %18 = load ptr, ptr %expected, align 8
  %19 = load ptr, ptr %actual, align 8
  call void @sema_expect_assignable__String_Struct_TypeInfo_Struct_TypeInfo(ptr %17, ptr %18, ptr %19)
  %20 = load ptr, ptr %actual, align 8
  ret ptr %20

label_2142:                                       ; preds = %label_2139
  %21 = load ptr, ptr %val_node, align 8
  %22 = load ptr, ptr %expected, align 8
  call void @node_set_type__Struct_ASTNode_Struct_TypeInfo(ptr %21, ptr %22)
  %23 = load ptr, ptr %expected, align 8
  ret ptr %23
}

define ptr @sema_expr__Struct_ASTNode_Struct_ASTNode(ptr %0, ptr %1) {
entry:
  %module = alloca ptr, align 8
  store ptr %0, ptr %module, align 8
  %expr = alloca ptr, align 8
  store ptr %1, ptr %expr, align 8
  %t = alloca ptr, align 8
  %source = alloca ptr, align 8
  %from_t = alloca ptr, align 8
  %to_t = alloca ptr, align 8
  %from_scalar = alloca i1, align 1
  %to_scalar = alloca i1, align 1
  %operand = alloca ptr, align 8
  %operand_t = alloca ptr, align 8
  %uop = alloca ptr, align 8
  %left_node = alloca ptr, align 8
  %right_node = alloca ptr, align 8
  %left_t = alloca ptr, align 8
  %right_t = alloca ptr, align 8
  %op = alloca ptr, align 8
  %callee = alloca ptr, align 8
  %name = alloca ptr, align 8
  %builtin_t = alloca ptr, align 8
  %fn_node = alloca ptr, align 8
  %arg_ptr = alloca ptr, align 8
  %param_ptr = alloca ptr, align 8
  %arg_node = alloca ptr, align 8
  %param_node = alloca ptr, align 8
  %param_t = alloca ptr, align 8
  %ret_t = alloca ptr, align 8
  %object_node = alloca ptr, align 8
  %object_t = alloca ptr, align 8
  %field_t = alloca ptr, align 8
  %elem_ptr = alloca ptr, align 8
  %arr_t = alloca ptr, align 8
  %first_t = alloca ptr, align 8
  %elem = alloca ptr, align 8
  %elem_t = alloca ptr, align 8
  %arr_t2 = alloca ptr, align 8
  %array_t = alloca ptr, align 8
  %index_t = alloca ptr, align 8
  %field_ptr = alloca ptr, align 8
  %field = alloca ptr, align 8
  %expected = alloca ptr, align 8
  %struct_t = alloca ptr, align 8
  %2 = load ptr, ptr %expr, align 8
  %3 = call i1 @node_has_type__Struct_ASTNode(ptr %2)
  br i1 %3, label %label_2369, label %label_2371

label_2371:                                       ; preds = %entry
  %4 = load ptr, ptr %expr, align 8
  %5 = getelementptr inbounds nuw %ASTNode, ptr %4, i32 0, i32 0
  %6 = load i32, ptr %5, align 4
  %7 = icmp eq i32 %6, 22
  br i1 %7, label %label_2372, label %label_2374

label_2369:                                       ; preds = %entry
  %8 = load ptr, ptr %expr, align 8
  %9 = call ptr @node_get_type__Struct_ASTNode(ptr %8)
  ret ptr %9

label_2374:                                       ; preds = %label_2371
  %10 = load ptr, ptr %expr, align 8
  %11 = getelementptr inbounds nuw %ASTNode, ptr %10, i32 0, i32 0
  %12 = load i32, ptr %11, align 4
  %13 = icmp eq i32 %12, 23
  br i1 %13, label %label_2390, label %label_2392

label_2372:                                       ; preds = %label_2371
  %14 = call ptr @type_invalid__Void()
  store ptr %14, ptr %t, align 8
  %15 = load ptr, ptr %expr, align 8
  %16 = getelementptr inbounds nuw %ASTNode, ptr %15, i32 0, i32 3
  %17 = load i32, ptr %16, align 4
  %18 = icmp eq i32 %17, 2
  br i1 %18, label %label_2375, label %label_2377

label_2377:                                       ; preds = %label_2375, %label_2372
  %19 = load ptr, ptr %expr, align 8
  %20 = getelementptr inbounds nuw %ASTNode, ptr %19, i32 0, i32 3
  %21 = load i32, ptr %20, align 4
  %22 = icmp eq i32 %21, 3
  br i1 %22, label %label_2378, label %label_2380

label_2375:                                       ; preds = %label_2372
  %23 = call ptr @type_int__Void()
  store ptr %23, ptr %t, align 8
  br label %label_2377

label_2380:                                       ; preds = %label_2378, %label_2377
  %24 = load ptr, ptr %expr, align 8
  %25 = getelementptr inbounds nuw %ASTNode, ptr %24, i32 0, i32 3
  %26 = load i32, ptr %25, align 4
  %27 = icmp eq i32 %26, 4
  br i1 %27, label %label_2381, label %label_2383

label_2378:                                       ; preds = %label_2377
  %28 = call ptr @type_float__Void()
  store ptr %28, ptr %t, align 8
  br label %label_2380

label_2383:                                       ; preds = %label_2381, %label_2380
  %29 = load ptr, ptr %expr, align 8
  %30 = getelementptr inbounds nuw %ASTNode, ptr %29, i32 0, i32 3
  %31 = load i32, ptr %30, align 4
  %32 = icmp eq i32 %31, 1
  br i1 %32, label %label_2384, label %label_2386

label_2381:                                       ; preds = %label_2380
  %33 = call ptr @type_bool__Void()
  store ptr %33, ptr %t, align 8
  br label %label_2383

label_2386:                                       ; preds = %label_2384, %label_2383
  %34 = load ptr, ptr %expr, align 8
  %35 = getelementptr inbounds nuw %ASTNode, ptr %34, i32 0, i32 3
  %36 = load i32, ptr %35, align 4
  %37 = icmp eq i32 %36, 0
  br i1 %37, label %label_2387, label %label_2389

label_2384:                                       ; preds = %label_2383
  %38 = call ptr @type_char__Void()
  store ptr %38, ptr %t, align 8
  br label %label_2386

label_2389:                                       ; preds = %label_2387, %label_2386
  %39 = load ptr, ptr %expr, align 8
  %40 = load ptr, ptr %t, align 8
  call void @node_set_type__Struct_ASTNode_Struct_TypeInfo(ptr %39, ptr %40)
  %41 = load ptr, ptr %t, align 8
  ret ptr %41

label_2387:                                       ; preds = %label_2386
  %42 = call ptr @type_string__Void()
  store ptr %42, ptr %t, align 8
  br label %label_2389

label_2392:                                       ; preds = %label_2374
  %43 = load ptr, ptr %expr, align 8
  %44 = getelementptr inbounds nuw %ASTNode, ptr %43, i32 0, i32 0
  %45 = load i32, ptr %44, align 4
  %46 = icmp eq i32 %45, 29
  br i1 %46, label %label_2399, label %label_2401

label_2390:                                       ; preds = %label_2374
  %47 = load ptr, ptr %expr, align 8
  %48 = getelementptr inbounds nuw %ASTNode, ptr %47, i32 0, i32 1
  %49 = load ptr, ptr %48, align 8
  %50 = call i32 @ir_has_var_type(ptr %49)
  %51 = icmp eq i32 %50, 0
  br i1 %51, label %label_2393, label %label_2395

label_2395:                                       ; preds = %label_2393, %label_2390
  %52 = load ptr, ptr %expr, align 8
  %53 = getelementptr inbounds nuw %ASTNode, ptr %52, i32 0, i32 1
  %54 = load ptr, ptr %53, align 8
  %55 = call i32 @ir_is_moved(ptr %54)
  %56 = icmp eq i32 %55, 1
  br i1 %56, label %label_2396, label %label_2398

label_2393:                                       ; preds = %label_2390
  %57 = load ptr, ptr %expr, align 8
  %58 = getelementptr inbounds nuw %ASTNode, ptr %57, i32 0, i32 1
  %59 = load ptr, ptr %58, align 8
  %60 = call ptr @str_concat(ptr @.str.s911, ptr %59)
  call void @sema_error__String(ptr %60)
  br label %label_2395

label_2398:                                       ; preds = %label_2396, %label_2395
  %61 = load ptr, ptr %expr, align 8
  %62 = getelementptr inbounds nuw %ASTNode, ptr %61, i32 0, i32 1
  %63 = load ptr, ptr %62, align 8
  %64 = call ptr @ir_get_var_type(ptr %63)
  %65 = call ptr @type_from_sem_key__String(ptr %64)
  store ptr %65, ptr %t, align 8
  %66 = load ptr, ptr %expr, align 8
  %67 = load ptr, ptr %t, align 8
  call void @node_set_type__Struct_ASTNode_Struct_TypeInfo(ptr %66, ptr %67)
  %68 = load ptr, ptr %t, align 8
  ret ptr %68

label_2396:                                       ; preds = %label_2395
  %69 = load ptr, ptr %expr, align 8
  %70 = getelementptr inbounds nuw %ASTNode, ptr %69, i32 0, i32 1
  %71 = load ptr, ptr %70, align 8
  %72 = call ptr @str_concat(ptr @.str.s912, ptr %71)
  call void @sema_error__String(ptr %72)
  br label %label_2398

label_2401:                                       ; preds = %label_2392
  %73 = load ptr, ptr %expr, align 8
  %74 = getelementptr inbounds nuw %ASTNode, ptr %73, i32 0, i32 0
  %75 = load i32, ptr %74, align 4
  %76 = icmp eq i32 %75, 21
  br i1 %76, label %label_2426, label %label_2428

label_2399:                                       ; preds = %label_2392
  %77 = load ptr, ptr %expr, align 8
  %78 = getelementptr inbounds nuw %ASTNode, ptr %77, i32 0, i32 5
  %79 = load ptr, ptr %78, align 8
  %80 = call ptr @ptr_to_node(ptr %79)
  store ptr %80, ptr %source, align 8
  %81 = load ptr, ptr %module, align 8
  %82 = load ptr, ptr %source, align 8
  %83 = call ptr @sema_expr__Struct_ASTNode_Struct_ASTNode(ptr %81, ptr %82)
  store ptr %83, ptr %from_t, align 8
  %84 = load ptr, ptr %module, align 8
  %85 = load ptr, ptr %expr, align 8
  %86 = getelementptr inbounds nuw %ASTNode, ptr %85, i32 0, i32 6
  %87 = load ptr, ptr %86, align 8
  %88 = call ptr @ptr_to_node(ptr %87)
  %89 = call ptr @sema_annotation_type__Struct_ASTNode_Struct_ASTNode(ptr %84, ptr %88)
  store ptr %89, ptr %to_t, align 8
  %sc.121 = alloca i1, align 1
  %sc.122 = alloca i1, align 1
  %sc.123 = alloca i1, align 1
  %sc.124 = alloca i1, align 1
  %90 = load ptr, ptr %from_t, align 8
  %91 = getelementptr inbounds nuw %TypeInfo, ptr %90, i32 0, i32 0
  %92 = load i32, ptr %91, align 4
  %93 = icmp eq i32 %92, 2
  store i1 %93, ptr %sc.124, align 1
  br i1 %93, label %label_2409, label %label_2408

label_2408:                                       ; preds = %label_2399
  %94 = load ptr, ptr %from_t, align 8
  %95 = getelementptr inbounds nuw %TypeInfo, ptr %94, i32 0, i32 0
  %96 = load i32, ptr %95, align 4
  %97 = icmp eq i32 %96, 3
  store i1 %97, ptr %sc.124, align 1
  br label %label_2409

label_2409:                                       ; preds = %label_2408, %label_2399
  %98 = load i1, ptr %sc.124, align 1
  store i1 %98, ptr %sc.123, align 1
  br i1 %98, label %label_2407, label %label_2406

label_2406:                                       ; preds = %label_2409
  %99 = load ptr, ptr %from_t, align 8
  %100 = getelementptr inbounds nuw %TypeInfo, ptr %99, i32 0, i32 0
  %101 = load i32, ptr %100, align 4
  %102 = icmp eq i32 %101, 5
  store i1 %102, ptr %sc.123, align 1
  br label %label_2407

label_2407:                                       ; preds = %label_2406, %label_2409
  %103 = load i1, ptr %sc.123, align 1
  store i1 %103, ptr %sc.122, align 1
  br i1 %103, label %label_2405, label %label_2404

label_2404:                                       ; preds = %label_2407
  %104 = load ptr, ptr %from_t, align 8
  %105 = getelementptr inbounds nuw %TypeInfo, ptr %104, i32 0, i32 0
  %106 = load i32, ptr %105, align 4
  %107 = icmp eq i32 %106, 4
  store i1 %107, ptr %sc.122, align 1
  br label %label_2405

label_2405:                                       ; preds = %label_2404, %label_2407
  %108 = load i1, ptr %sc.122, align 1
  store i1 %108, ptr %sc.121, align 1
  br i1 %108, label %label_2403, label %label_2402

label_2402:                                       ; preds = %label_2405
  %109 = load ptr, ptr %from_t, align 8
  %110 = getelementptr inbounds nuw %TypeInfo, ptr %109, i32 0, i32 0
  %111 = load i32, ptr %110, align 4
  %112 = icmp eq i32 %111, 9
  store i1 %112, ptr %sc.121, align 1
  br label %label_2403

label_2403:                                       ; preds = %label_2402, %label_2405
  %113 = load i1, ptr %sc.121, align 1
  store i1 %113, ptr %from_scalar, align 1
  %sc.125 = alloca i1, align 1
  %sc.126 = alloca i1, align 1
  %sc.127 = alloca i1, align 1
  %sc.128 = alloca i1, align 1
  %114 = load ptr, ptr %to_t, align 8
  %115 = getelementptr inbounds nuw %TypeInfo, ptr %114, i32 0, i32 0
  %116 = load i32, ptr %115, align 4
  %117 = icmp eq i32 %116, 2
  store i1 %117, ptr %sc.128, align 1
  br i1 %117, label %label_2417, label %label_2416

label_2416:                                       ; preds = %label_2403
  %118 = load ptr, ptr %to_t, align 8
  %119 = getelementptr inbounds nuw %TypeInfo, ptr %118, i32 0, i32 0
  %120 = load i32, ptr %119, align 4
  %121 = icmp eq i32 %120, 3
  store i1 %121, ptr %sc.128, align 1
  br label %label_2417

label_2417:                                       ; preds = %label_2416, %label_2403
  %122 = load i1, ptr %sc.128, align 1
  store i1 %122, ptr %sc.127, align 1
  br i1 %122, label %label_2415, label %label_2414

label_2414:                                       ; preds = %label_2417
  %123 = load ptr, ptr %to_t, align 8
  %124 = getelementptr inbounds nuw %TypeInfo, ptr %123, i32 0, i32 0
  %125 = load i32, ptr %124, align 4
  %126 = icmp eq i32 %125, 5
  store i1 %126, ptr %sc.127, align 1
  br label %label_2415

label_2415:                                       ; preds = %label_2414, %label_2417
  %127 = load i1, ptr %sc.127, align 1
  store i1 %127, ptr %sc.126, align 1
  br i1 %127, label %label_2413, label %label_2412

label_2412:                                       ; preds = %label_2415
  %128 = load ptr, ptr %to_t, align 8
  %129 = getelementptr inbounds nuw %TypeInfo, ptr %128, i32 0, i32 0
  %130 = load i32, ptr %129, align 4
  %131 = icmp eq i32 %130, 9
  store i1 %131, ptr %sc.126, align 1
  br label %label_2413

label_2413:                                       ; preds = %label_2412, %label_2415
  %132 = load i1, ptr %sc.126, align 1
  store i1 %132, ptr %sc.125, align 1
  br i1 %132, label %label_2411, label %label_2410

label_2410:                                       ; preds = %label_2413
  %133 = load ptr, ptr %to_t, align 8
  %134 = getelementptr inbounds nuw %TypeInfo, ptr %133, i32 0, i32 0
  %135 = load i32, ptr %134, align 4
  %136 = icmp eq i32 %135, 4
  store i1 %136, ptr %sc.125, align 1
  br label %label_2411

label_2411:                                       ; preds = %label_2410, %label_2413
  %137 = load i1, ptr %sc.125, align 1
  store i1 %137, ptr %to_scalar, align 1
  %138 = load ptr, ptr %to_t, align 8
  %139 = getelementptr inbounds nuw %TypeInfo, ptr %138, i32 0, i32 0
  %140 = load i32, ptr %139, align 4
  %141 = icmp eq i32 %140, 4
  br i1 %141, label %label_2418, label %label_2420

label_2420:                                       ; preds = %label_2418, %label_2411
  %sc.129 = alloca i1, align 1
  %142 = load i1, ptr %from_scalar, align 1
  %143 = icmp eq i1 %142, false
  store i1 %143, ptr %sc.129, align 1
  br i1 %143, label %label_2422, label %label_2421

label_2418:                                       ; preds = %label_2411
  call void @sema_error__String(ptr @.str.s913)
  br label %label_2420

label_2421:                                       ; preds = %label_2420
  %144 = load i1, ptr %to_scalar, align 1
  %145 = icmp eq i1 %144, false
  store i1 %145, ptr %sc.129, align 1
  br label %label_2422

label_2422:                                       ; preds = %label_2421, %label_2420
  %146 = load i1, ptr %sc.129, align 1
  br i1 %146, label %label_2423, label %label_2425

label_2425:                                       ; preds = %label_2423, %label_2422
  %147 = load ptr, ptr %expr, align 8
  %148 = load ptr, ptr %to_t, align 8
  call void @node_set_type__Struct_ASTNode_Struct_TypeInfo(ptr %147, ptr %148)
  %149 = load ptr, ptr %to_t, align 8
  ret ptr %149

label_2423:                                       ; preds = %label_2422
  %150 = load ptr, ptr %to_t, align 8
  %151 = load ptr, ptr %from_t, align 8
  call void @sema_type_error__String_Struct_TypeInfo_Struct_TypeInfo(ptr @.str.s914, ptr %150, ptr %151)
  br label %label_2425

label_2428:                                       ; preds = %label_2442, %label_2401
  %152 = load ptr, ptr %expr, align 8
  %153 = getelementptr inbounds nuw %ASTNode, ptr %152, i32 0, i32 0
  %154 = load i32, ptr %153, align 4
  %155 = icmp eq i32 %154, 20
  br i1 %155, label %label_2449, label %label_2451

label_2426:                                       ; preds = %label_2401
  %156 = load ptr, ptr %expr, align 8
  %157 = getelementptr inbounds nuw %ASTNode, ptr %156, i32 0, i32 5
  %158 = load ptr, ptr %157, align 8
  %159 = call ptr @ptr_to_node(ptr %158)
  store ptr %159, ptr %operand, align 8
  %160 = load ptr, ptr %module, align 8
  %161 = load ptr, ptr %operand, align 8
  %162 = call ptr @sema_expr__Struct_ASTNode_Struct_ASTNode(ptr %160, ptr %161)
  store ptr %162, ptr %operand_t, align 8
  %163 = load ptr, ptr %expr, align 8
  %164 = getelementptr inbounds nuw %ASTNode, ptr %163, i32 0, i32 1
  %165 = load ptr, ptr %164, align 8
  store ptr %165, ptr %uop, align 8
  %166 = load ptr, ptr %uop, align 8
  %167 = call i32 @str_equals(ptr %166, ptr @.str.s915)
  %168 = icmp eq i32 %167, 1
  br i1 %168, label %label_2429, label %label_2431

label_2431:                                       ; preds = %label_2426
  %169 = load ptr, ptr %uop, align 8
  %170 = call i32 @str_equals(ptr %169, ptr @.str.s917)
  %171 = icmp eq i32 %170, 1
  br i1 %171, label %label_2432, label %label_2434

label_2429:                                       ; preds = %label_2426
  %172 = call ptr @type_bool__Void()
  %173 = load ptr, ptr %operand_t, align 8
  call void @sema_expect_assignable__String_Struct_TypeInfo_Struct_TypeInfo(ptr @.str.s916, ptr %172, ptr %173)
  %174 = load ptr, ptr %expr, align 8
  %175 = call ptr @type_bool__Void()
  call void @node_set_type__Struct_ASTNode_Struct_TypeInfo(ptr %174, ptr %175)
  %176 = call ptr @type_bool__Void()
  ret ptr %176

label_2434:                                       ; preds = %label_2431
  %177 = load ptr, ptr %uop, align 8
  %178 = call i32 @str_equals(ptr %177, ptr @.str.s919)
  %179 = icmp eq i32 %178, 1
  br i1 %179, label %label_2440, label %label_2442

label_2432:                                       ; preds = %label_2431
  %sc.130 = alloca i1, align 1
  %180 = load ptr, ptr %operand_t, align 8
  %181 = getelementptr inbounds nuw %TypeInfo, ptr %180, i32 0, i32 0
  %182 = load i32, ptr %181, align 4
  %183 = icmp ne i32 %182, 2
  store i1 %183, ptr %sc.130, align 1
  br i1 %183, label %label_2435, label %label_2436

label_2436:                                       ; preds = %label_2435, %label_2432
  %184 = load i1, ptr %sc.130, align 1
  br i1 %184, label %label_2437, label %label_2439

label_2435:                                       ; preds = %label_2432
  %185 = load ptr, ptr %operand_t, align 8
  %186 = getelementptr inbounds nuw %TypeInfo, ptr %185, i32 0, i32 0
  %187 = load i32, ptr %186, align 4
  %188 = icmp ne i32 %187, 5
  store i1 %188, ptr %sc.130, align 1
  br label %label_2436

label_2439:                                       ; preds = %label_2437, %label_2436
  %189 = load ptr, ptr %expr, align 8
  %190 = load ptr, ptr %operand_t, align 8
  call void @node_set_type__Struct_ASTNode_Struct_TypeInfo(ptr %189, ptr %190)
  %191 = load ptr, ptr %operand_t, align 8
  ret ptr %191

label_2437:                                       ; preds = %label_2436
  call void @sema_error__String(ptr @.str.s918)
  br label %label_2439

label_2442:                                       ; preds = %label_2434
  %192 = load ptr, ptr %uop, align 8
  %193 = call ptr @str_concat(ptr @.str.s922, ptr %192)
  call void @sema_error__String(ptr %193)
  br label %label_2428

label_2440:                                       ; preds = %label_2434
  %194 = load ptr, ptr %operand_t, align 8
  %195 = call i1 @type_is_numeric__Struct_TypeInfo(ptr %194)
  %196 = icmp eq i1 %195, false
  br i1 %196, label %label_2443, label %label_2445

label_2445:                                       ; preds = %label_2443, %label_2440
  %197 = load ptr, ptr %operand_t, align 8
  %198 = call i1 @type_int_is_unsigned__Struct_TypeInfo(ptr %197)
  br i1 %198, label %label_2446, label %label_2448

label_2443:                                       ; preds = %label_2440
  call void @sema_error__String(ptr @.str.s920)
  br label %label_2445

label_2448:                                       ; preds = %label_2446, %label_2445
  %199 = load ptr, ptr %expr, align 8
  %200 = load ptr, ptr %operand_t, align 8
  call void @node_set_type__Struct_ASTNode_Struct_TypeInfo(ptr %199, ptr %200)
  %201 = load ptr, ptr %operand_t, align 8
  ret ptr %201

label_2446:                                       ; preds = %label_2445
  %202 = load ptr, ptr %operand_t, align 8
  %203 = call ptr @type_display__Struct_TypeInfo(ptr %202)
  %204 = call ptr @str_concat(ptr @.str.s921, ptr %203)
  call void @sema_error__String(ptr %204)
  br label %label_2448

label_2451:                                       ; preds = %label_2529, %label_2428
  %205 = load ptr, ptr %expr, align 8
  %206 = getelementptr inbounds nuw %ASTNode, ptr %205, i32 0, i32 0
  %207 = load i32, ptr %206, align 4
  %208 = icmp eq i32 %207, 24
  br i1 %208, label %label_2530, label %label_2532

label_2449:                                       ; preds = %label_2428
  %209 = load ptr, ptr %expr, align 8
  %210 = getelementptr inbounds nuw %ASTNode, ptr %209, i32 0, i32 5
  %211 = load ptr, ptr %210, align 8
  %212 = call ptr @ptr_to_node(ptr %211)
  store ptr %212, ptr %left_node, align 8
  %213 = load ptr, ptr %expr, align 8
  %214 = getelementptr inbounds nuw %ASTNode, ptr %213, i32 0, i32 6
  %215 = load ptr, ptr %214, align 8
  %216 = call ptr @ptr_to_node(ptr %215)
  store ptr %216, ptr %right_node, align 8
  %217 = load ptr, ptr %module, align 8
  %218 = load ptr, ptr %left_node, align 8
  %219 = call ptr @sema_expr__Struct_ASTNode_Struct_ASTNode(ptr %217, ptr %218)
  store ptr %219, ptr %left_t, align 8
  %220 = load ptr, ptr %module, align 8
  %221 = load ptr, ptr %right_node, align 8
  %222 = call ptr @sema_expr__Struct_ASTNode_Struct_ASTNode(ptr %220, ptr %221)
  store ptr %222, ptr %right_t, align 8
  %sc.131 = alloca i1, align 1
  %sc.132 = alloca i1, align 1
  %223 = load ptr, ptr %left_t, align 8
  %224 = getelementptr inbounds nuw %TypeInfo, ptr %223, i32 0, i32 0
  %225 = load i32, ptr %224, align 4
  %226 = icmp eq i32 %225, 2
  store i1 %226, ptr %sc.132, align 1
  br i1 %226, label %label_2454, label %label_2455

label_2455:                                       ; preds = %label_2454, %label_2449
  %227 = load i1, ptr %sc.132, align 1
  store i1 %227, ptr %sc.131, align 1
  br i1 %227, label %label_2452, label %label_2453

label_2454:                                       ; preds = %label_2449
  %228 = load ptr, ptr %right_t, align 8
  %229 = getelementptr inbounds nuw %TypeInfo, ptr %228, i32 0, i32 0
  %230 = load i32, ptr %229, align 4
  %231 = icmp eq i32 %230, 2
  store i1 %231, ptr %sc.132, align 1
  br label %label_2455

label_2453:                                       ; preds = %label_2452, %label_2455
  %232 = load i1, ptr %sc.131, align 1
  br i1 %232, label %label_2456, label %label_2458

label_2452:                                       ; preds = %label_2455
  %233 = load ptr, ptr %left_t, align 8
  %234 = load ptr, ptr %right_t, align 8
  %235 = call i1 @type_equals__Struct_TypeInfo_Struct_TypeInfo(ptr %233, ptr %234)
  %236 = icmp eq i1 %235, false
  store i1 %236, ptr %sc.131, align 1
  br label %label_2453

label_2458:                                       ; preds = %label_2461, %label_2453
  %237 = load ptr, ptr %expr, align 8
  %238 = getelementptr inbounds nuw %ASTNode, ptr %237, i32 0, i32 1
  %239 = load ptr, ptr %238, align 8
  store ptr %239, ptr %op, align 8
  %sc.133 = alloca i1, align 1
  %240 = load ptr, ptr %op, align 8
  %241 = call i32 @str_equals(ptr %240, ptr @.str.s923)
  %242 = icmp eq i32 %241, 1
  store i1 %242, ptr %sc.133, align 1
  br i1 %242, label %label_2466, label %label_2465

label_2456:                                       ; preds = %label_2453
  %243 = load ptr, ptr %right_node, align 8
  %244 = call i1 @sema_is_int_literal__Struct_ASTNode(ptr %243)
  br i1 %244, label %label_2459, label %label_2460

label_2460:                                       ; preds = %label_2456
  %245 = load ptr, ptr %left_node, align 8
  %246 = call i1 @sema_is_int_literal__Struct_ASTNode(ptr %245)
  br i1 %246, label %label_2462, label %label_2464

label_2459:                                       ; preds = %label_2456
  %247 = load ptr, ptr %right_node, align 8
  %248 = load ptr, ptr %left_t, align 8
  call void @node_set_type__Struct_ASTNode_Struct_TypeInfo(ptr %247, ptr %248)
  %249 = load ptr, ptr %left_t, align 8
  %250 = call ptr @type_copy__Struct_TypeInfo(ptr %249)
  store ptr %250, ptr %right_t, align 8
  br label %label_2461

label_2461:                                       ; preds = %label_2464, %label_2459
  br label %label_2458

label_2464:                                       ; preds = %label_2462, %label_2460
  br label %label_2461

label_2462:                                       ; preds = %label_2460
  %251 = load ptr, ptr %left_node, align 8
  %252 = load ptr, ptr %right_t, align 8
  call void @node_set_type__Struct_ASTNode_Struct_TypeInfo(ptr %251, ptr %252)
  %253 = load ptr, ptr %right_t, align 8
  %254 = call ptr @type_copy__Struct_TypeInfo(ptr %253)
  store ptr %254, ptr %left_t, align 8
  br label %label_2464

label_2465:                                       ; preds = %label_2458
  %255 = load ptr, ptr %op, align 8
  %256 = call i32 @str_equals(ptr %255, ptr @.str.s924)
  %257 = icmp eq i32 %256, 1
  store i1 %257, ptr %sc.133, align 1
  br label %label_2466

label_2466:                                       ; preds = %label_2465, %label_2458
  %258 = load i1, ptr %sc.133, align 1
  br i1 %258, label %label_2467, label %label_2469

label_2469:                                       ; preds = %label_2466
  %sc.134 = alloca i1, align 1
  %sc.135 = alloca i1, align 1
  %sc.136 = alloca i1, align 1
  %259 = load ptr, ptr %op, align 8
  %260 = call i32 @str_equals(ptr %259, ptr @.str.s927)
  %261 = icmp eq i32 %260, 1
  store i1 %261, ptr %sc.136, align 1
  br i1 %261, label %label_2475, label %label_2474

label_2467:                                       ; preds = %label_2466
  %262 = call ptr @type_bool__Void()
  %263 = load ptr, ptr %left_t, align 8
  call void @sema_expect_assignable__String_Struct_TypeInfo_Struct_TypeInfo(ptr @.str.s925, ptr %262, ptr %263)
  %264 = call ptr @type_bool__Void()
  %265 = load ptr, ptr %right_t, align 8
  call void @sema_expect_assignable__String_Struct_TypeInfo_Struct_TypeInfo(ptr @.str.s926, ptr %264, ptr %265)
  %266 = load ptr, ptr %expr, align 8
  %267 = call ptr @type_bool__Void()
  call void @node_set_type__Struct_ASTNode_Struct_TypeInfo(ptr %266, ptr %267)
  %268 = call ptr @type_bool__Void()
  ret ptr %268

label_2474:                                       ; preds = %label_2469
  %269 = load ptr, ptr %op, align 8
  %270 = call i32 @str_equals(ptr %269, ptr @.str.s928)
  %271 = icmp eq i32 %270, 1
  store i1 %271, ptr %sc.136, align 1
  br label %label_2475

label_2475:                                       ; preds = %label_2474, %label_2469
  %272 = load i1, ptr %sc.136, align 1
  store i1 %272, ptr %sc.135, align 1
  br i1 %272, label %label_2473, label %label_2472

label_2472:                                       ; preds = %label_2475
  %273 = load ptr, ptr %op, align 8
  %274 = call i32 @str_equals(ptr %273, ptr @.str.s929)
  %275 = icmp eq i32 %274, 1
  store i1 %275, ptr %sc.135, align 1
  br label %label_2473

label_2473:                                       ; preds = %label_2472, %label_2475
  %276 = load i1, ptr %sc.135, align 1
  store i1 %276, ptr %sc.134, align 1
  br i1 %276, label %label_2471, label %label_2470

label_2470:                                       ; preds = %label_2473
  %277 = load ptr, ptr %op, align 8
  %278 = call i32 @str_equals(ptr %277, ptr @.str.s930)
  %279 = icmp eq i32 %278, 1
  store i1 %279, ptr %sc.134, align 1
  br label %label_2471

label_2471:                                       ; preds = %label_2470, %label_2473
  %280 = load i1, ptr %sc.134, align 1
  br i1 %280, label %label_2476, label %label_2478

label_2478:                                       ; preds = %label_2471
  %281 = load ptr, ptr %op, align 8
  %282 = call i32 @str_equals(ptr %281, ptr @.str.s933)
  %283 = icmp eq i32 %282, 1
  br i1 %283, label %label_2482, label %label_2484

label_2476:                                       ; preds = %label_2471
  %284 = load ptr, ptr %left_t, align 8
  %285 = call i1 @type_is_numeric__Struct_TypeInfo(ptr %284)
  %286 = icmp eq i1 %285, false
  br i1 %286, label %label_2479, label %label_2481

label_2481:                                       ; preds = %label_2479, %label_2476
  %287 = load ptr, ptr %op, align 8
  %288 = call ptr @str_concat(ptr @.str.s932, ptr %287)
  %289 = load ptr, ptr %left_t, align 8
  %290 = load ptr, ptr %right_t, align 8
  call void @sema_expect_assignable__String_Struct_TypeInfo_Struct_TypeInfo(ptr %288, ptr %289, ptr %290)
  %291 = load ptr, ptr %expr, align 8
  %292 = load ptr, ptr %left_t, align 8
  call void @node_set_type__Struct_ASTNode_Struct_TypeInfo(ptr %291, ptr %292)
  %293 = load ptr, ptr %left_t, align 8
  ret ptr %293

label_2479:                                       ; preds = %label_2476
  %294 = load ptr, ptr %op, align 8
  %295 = call ptr @str_concat(ptr @.str.s931, ptr %294)
  call void @sema_error__String(ptr %295)
  br label %label_2481

label_2484:                                       ; preds = %label_2478
  %sc.138 = alloca i1, align 1
  %sc.139 = alloca i1, align 1
  %296 = load ptr, ptr %op, align 8
  %297 = call i32 @str_equals(ptr %296, ptr @.str.s936)
  %298 = icmp eq i32 %297, 1
  store i1 %298, ptr %sc.139, align 1
  br i1 %298, label %label_2493, label %label_2492

label_2482:                                       ; preds = %label_2478
  %sc.137 = alloca i1, align 1
  %299 = load ptr, ptr %left_t, align 8
  %300 = getelementptr inbounds nuw %TypeInfo, ptr %299, i32 0, i32 0
  %301 = load i32, ptr %300, align 4
  %302 = icmp ne i32 %301, 2
  store i1 %302, ptr %sc.137, align 1
  br i1 %302, label %label_2485, label %label_2486

label_2486:                                       ; preds = %label_2485, %label_2482
  %303 = load i1, ptr %sc.137, align 1
  br i1 %303, label %label_2487, label %label_2489

label_2485:                                       ; preds = %label_2482
  %304 = load ptr, ptr %left_t, align 8
  %305 = getelementptr inbounds nuw %TypeInfo, ptr %304, i32 0, i32 0
  %306 = load i32, ptr %305, align 4
  %307 = icmp ne i32 %306, 9
  store i1 %307, ptr %sc.137, align 1
  br label %label_2486

label_2489:                                       ; preds = %label_2487, %label_2486
  %308 = load ptr, ptr %left_t, align 8
  %309 = load ptr, ptr %right_t, align 8
  call void @sema_expect_assignable__String_Struct_TypeInfo_Struct_TypeInfo(ptr @.str.s935, ptr %308, ptr %309)
  %310 = load ptr, ptr %expr, align 8
  %311 = load ptr, ptr %left_t, align 8
  call void @node_set_type__Struct_ASTNode_Struct_TypeInfo(ptr %310, ptr %311)
  %312 = load ptr, ptr %left_t, align 8
  ret ptr %312

label_2487:                                       ; preds = %label_2486
  call void @sema_error__String(ptr @.str.s934)
  br label %label_2489

label_2492:                                       ; preds = %label_2484
  %313 = load ptr, ptr %op, align 8
  %314 = call i32 @str_equals(ptr %313, ptr @.str.s937)
  %315 = icmp eq i32 %314, 1
  store i1 %315, ptr %sc.139, align 1
  br label %label_2493

label_2493:                                       ; preds = %label_2492, %label_2484
  %316 = load i1, ptr %sc.139, align 1
  store i1 %316, ptr %sc.138, align 1
  br i1 %316, label %label_2491, label %label_2490

label_2490:                                       ; preds = %label_2493
  %317 = load ptr, ptr %op, align 8
  %318 = call i32 @str_equals(ptr %317, ptr @.str.s938)
  %319 = icmp eq i32 %318, 1
  store i1 %319, ptr %sc.138, align 1
  br label %label_2491

label_2491:                                       ; preds = %label_2490, %label_2493
  %320 = load i1, ptr %sc.138, align 1
  br i1 %320, label %label_2494, label %label_2496

label_2496:                                       ; preds = %label_2491
  %sc.142 = alloca i1, align 1
  %321 = load ptr, ptr %op, align 8
  %322 = call i32 @str_equals(ptr %321, ptr @.str.s941)
  %323 = icmp eq i32 %322, 1
  store i1 %323, ptr %sc.142, align 1
  br i1 %323, label %label_2505, label %label_2504

label_2494:                                       ; preds = %label_2491
  %sc.140 = alloca i1, align 1
  %sc.141 = alloca i1, align 1
  %324 = load ptr, ptr %left_t, align 8
  %325 = getelementptr inbounds nuw %TypeInfo, ptr %324, i32 0, i32 0
  %326 = load i32, ptr %325, align 4
  %327 = icmp ne i32 %326, 2
  store i1 %327, ptr %sc.141, align 1
  br i1 %327, label %label_2499, label %label_2500

label_2500:                                       ; preds = %label_2499, %label_2494
  %328 = load i1, ptr %sc.141, align 1
  store i1 %328, ptr %sc.140, align 1
  br i1 %328, label %label_2497, label %label_2498

label_2499:                                       ; preds = %label_2494
  %329 = load ptr, ptr %left_t, align 8
  %330 = getelementptr inbounds nuw %TypeInfo, ptr %329, i32 0, i32 0
  %331 = load i32, ptr %330, align 4
  %332 = icmp ne i32 %331, 9
  store i1 %332, ptr %sc.141, align 1
  br label %label_2500

label_2498:                                       ; preds = %label_2497, %label_2500
  %333 = load i1, ptr %sc.140, align 1
  br i1 %333, label %label_2501, label %label_2503

label_2497:                                       ; preds = %label_2500
  %334 = load ptr, ptr %left_t, align 8
  %335 = getelementptr inbounds nuw %TypeInfo, ptr %334, i32 0, i32 0
  %336 = load i32, ptr %335, align 4
  %337 = icmp ne i32 %336, 5
  store i1 %337, ptr %sc.140, align 1
  br label %label_2498

label_2503:                                       ; preds = %label_2501, %label_2498
  %338 = load ptr, ptr %op, align 8
  %339 = call ptr @str_concat(ptr @.str.s940, ptr %338)
  %340 = load ptr, ptr %left_t, align 8
  %341 = load ptr, ptr %right_t, align 8
  call void @sema_expect_assignable__String_Struct_TypeInfo_Struct_TypeInfo(ptr %339, ptr %340, ptr %341)
  %342 = load ptr, ptr %expr, align 8
  %343 = load ptr, ptr %left_t, align 8
  call void @node_set_type__Struct_ASTNode_Struct_TypeInfo(ptr %342, ptr %343)
  %344 = load ptr, ptr %left_t, align 8
  ret ptr %344

label_2501:                                       ; preds = %label_2498
  %345 = load ptr, ptr %op, align 8
  %346 = call ptr @str_concat(ptr @.str.s939, ptr %345)
  call void @sema_error__String(ptr %346)
  br label %label_2503

label_2504:                                       ; preds = %label_2496
  %347 = load ptr, ptr %op, align 8
  %348 = call i32 @str_equals(ptr %347, ptr @.str.s942)
  %349 = icmp eq i32 %348, 1
  store i1 %349, ptr %sc.142, align 1
  br label %label_2505

label_2505:                                       ; preds = %label_2504, %label_2496
  %350 = load i1, ptr %sc.142, align 1
  br i1 %350, label %label_2506, label %label_2508

label_2508:                                       ; preds = %label_2505
  %sc.144 = alloca i1, align 1
  %sc.145 = alloca i1, align 1
  %sc.146 = alloca i1, align 1
  %sc.147 = alloca i1, align 1
  %sc.148 = alloca i1, align 1
  %351 = load ptr, ptr %op, align 8
  %352 = call i32 @str_equals(ptr %351, ptr @.str.s945)
  %353 = icmp eq i32 %352, 1
  store i1 %353, ptr %sc.148, align 1
  br i1 %353, label %label_2526, label %label_2525

label_2506:                                       ; preds = %label_2505
  %sc.143 = alloca i1, align 1
  %354 = load ptr, ptr %left_t, align 8
  %355 = getelementptr inbounds nuw %TypeInfo, ptr %354, i32 0, i32 0
  %356 = load i32, ptr %355, align 4
  %357 = icmp ne i32 %356, 2
  store i1 %357, ptr %sc.143, align 1
  br i1 %357, label %label_2509, label %label_2510

label_2510:                                       ; preds = %label_2509, %label_2506
  %358 = load i1, ptr %sc.143, align 1
  br i1 %358, label %label_2511, label %label_2513

label_2509:                                       ; preds = %label_2506
  %359 = load ptr, ptr %left_t, align 8
  %360 = getelementptr inbounds nuw %TypeInfo, ptr %359, i32 0, i32 0
  %361 = load i32, ptr %360, align 4
  %362 = icmp ne i32 %361, 5
  store i1 %362, ptr %sc.143, align 1
  br label %label_2510

label_2513:                                       ; preds = %label_2511, %label_2510
  %363 = load ptr, ptr %right_t, align 8
  %364 = getelementptr inbounds nuw %TypeInfo, ptr %363, i32 0, i32 0
  %365 = load i32, ptr %364, align 4
  %366 = icmp ne i32 %365, 2
  br i1 %366, label %label_2514, label %label_2516

label_2511:                                       ; preds = %label_2510
  %367 = load ptr, ptr %op, align 8
  %368 = call ptr @str_concat(ptr @.str.s943, ptr %367)
  call void @sema_error__String(ptr %368)
  br label %label_2513

label_2516:                                       ; preds = %label_2514, %label_2513
  %369 = load ptr, ptr %expr, align 8
  %370 = load ptr, ptr %left_t, align 8
  call void @node_set_type__Struct_ASTNode_Struct_TypeInfo(ptr %369, ptr %370)
  %371 = load ptr, ptr %left_t, align 8
  ret ptr %371

label_2514:                                       ; preds = %label_2513
  %372 = load ptr, ptr %op, align 8
  %373 = call ptr @str_concat(ptr @.str.s944, ptr %372)
  call void @sema_error__String(ptr %373)
  br label %label_2516

label_2525:                                       ; preds = %label_2508
  %374 = load ptr, ptr %op, align 8
  %375 = call i32 @str_equals(ptr %374, ptr @.str.s946)
  %376 = icmp eq i32 %375, 1
  store i1 %376, ptr %sc.148, align 1
  br label %label_2526

label_2526:                                       ; preds = %label_2525, %label_2508
  %377 = load i1, ptr %sc.148, align 1
  store i1 %377, ptr %sc.147, align 1
  br i1 %377, label %label_2524, label %label_2523

label_2523:                                       ; preds = %label_2526
  %378 = load ptr, ptr %op, align 8
  %379 = call i32 @str_equals(ptr %378, ptr @.str.s947)
  %380 = icmp eq i32 %379, 1
  store i1 %380, ptr %sc.147, align 1
  br label %label_2524

label_2524:                                       ; preds = %label_2523, %label_2526
  %381 = load i1, ptr %sc.147, align 1
  store i1 %381, ptr %sc.146, align 1
  br i1 %381, label %label_2522, label %label_2521

label_2521:                                       ; preds = %label_2524
  %382 = load ptr, ptr %op, align 8
  %383 = call i32 @str_equals(ptr %382, ptr @.str.s948)
  %384 = icmp eq i32 %383, 1
  store i1 %384, ptr %sc.146, align 1
  br label %label_2522

label_2522:                                       ; preds = %label_2521, %label_2524
  %385 = load i1, ptr %sc.146, align 1
  store i1 %385, ptr %sc.145, align 1
  br i1 %385, label %label_2520, label %label_2519

label_2519:                                       ; preds = %label_2522
  %386 = load ptr, ptr %op, align 8
  %387 = call i32 @str_equals(ptr %386, ptr @.str.s949)
  %388 = icmp eq i32 %387, 1
  store i1 %388, ptr %sc.145, align 1
  br label %label_2520

label_2520:                                       ; preds = %label_2519, %label_2522
  %389 = load i1, ptr %sc.145, align 1
  store i1 %389, ptr %sc.144, align 1
  br i1 %389, label %label_2518, label %label_2517

label_2517:                                       ; preds = %label_2520
  %390 = load ptr, ptr %op, align 8
  %391 = call i32 @str_equals(ptr %390, ptr @.str.s950)
  %392 = icmp eq i32 %391, 1
  store i1 %392, ptr %sc.144, align 1
  br label %label_2518

label_2518:                                       ; preds = %label_2517, %label_2520
  %393 = load i1, ptr %sc.144, align 1
  br i1 %393, label %label_2527, label %label_2529

label_2529:                                       ; preds = %label_2518
  %394 = load ptr, ptr %op, align 8
  %395 = call ptr @str_concat(ptr @.str.s952, ptr %394)
  call void @sema_error__String(ptr %395)
  br label %label_2451

label_2527:                                       ; preds = %label_2518
  %396 = load ptr, ptr %op, align 8
  %397 = call ptr @str_concat(ptr @.str.s951, ptr %396)
  %398 = load ptr, ptr %left_t, align 8
  %399 = load ptr, ptr %right_t, align 8
  call void @sema_expect_assignable__String_Struct_TypeInfo_Struct_TypeInfo(ptr %397, ptr %398, ptr %399)
  %400 = load ptr, ptr %expr, align 8
  %401 = call ptr @type_bool__Void()
  call void @node_set_type__Struct_ASTNode_Struct_TypeInfo(ptr %400, ptr %401)
  %402 = call ptr @type_bool__Void()
  ret ptr %402

label_2532:                                       ; preds = %label_2451
  %403 = load ptr, ptr %expr, align 8
  %404 = getelementptr inbounds nuw %ASTNode, ptr %403, i32 0, i32 0
  %405 = load i32, ptr %404, align 4
  %406 = icmp eq i32 %405, 25
  br i1 %406, label %label_2550, label %label_2552

label_2530:                                       ; preds = %label_2451
  %407 = load ptr, ptr %expr, align 8
  %408 = getelementptr inbounds nuw %ASTNode, ptr %407, i32 0, i32 5
  %409 = load ptr, ptr %408, align 8
  %410 = call ptr @ptr_to_node(ptr %409)
  store ptr %410, ptr %callee, align 8
  %411 = load ptr, ptr %callee, align 8
  %412 = getelementptr inbounds nuw %ASTNode, ptr %411, i32 0, i32 1
  %413 = load ptr, ptr %412, align 8
  store ptr %413, ptr %name, align 8
  %414 = load ptr, ptr %module, align 8
  %415 = load ptr, ptr %name, align 8
  %416 = load ptr, ptr %expr, align 8
  %417 = getelementptr inbounds nuw %ASTNode, ptr %416, i32 0, i32 6
  %418 = load ptr, ptr %417, align 8
  %419 = call i1 @sema_check_builtin_call__Struct_ASTNode_String_String(ptr %414, ptr %415, ptr %418)
  br i1 %419, label %label_2533, label %label_2535

label_2535:                                       ; preds = %label_2530
  %420 = load ptr, ptr %module, align 8
  %421 = load ptr, ptr %name, align 8
  %422 = load ptr, ptr %expr, align 8
  %423 = getelementptr inbounds nuw %ASTNode, ptr %422, i32 0, i32 6
  %424 = load ptr, ptr %423, align 8
  %425 = call ptr @sema_find_function_overload__Struct_ASTNode_String_String(ptr %420, ptr %421, ptr %424)
  store ptr %425, ptr %fn_node, align 8
  %426 = load ptr, ptr %expr, align 8
  %427 = getelementptr inbounds nuw %ASTNode, ptr %426, i32 0, i32 6
  %428 = load ptr, ptr %427, align 8
  store ptr %428, ptr %arg_ptr, align 8
  %429 = load ptr, ptr %fn_node, align 8
  %430 = getelementptr inbounds nuw %ASTNode, ptr %429, i32 0, i32 5
  %431 = load ptr, ptr %430, align 8
  store ptr %431, ptr %param_ptr, align 8
  br label %label_2536

label_2533:                                       ; preds = %label_2530
  %432 = load ptr, ptr %name, align 8
  %433 = load ptr, ptr %expr, align 8
  %434 = getelementptr inbounds nuw %ASTNode, ptr %433, i32 0, i32 6
  %435 = load ptr, ptr %434, align 8
  %436 = call ptr @sema_builtin_call_type__String_String(ptr %432, ptr %435)
  store ptr %436, ptr %builtin_t, align 8
  %437 = load ptr, ptr %expr, align 8
  %438 = load ptr, ptr %builtin_t, align 8
  call void @node_set_type__Struct_ASTNode_Struct_TypeInfo(ptr %437, ptr %438)
  %439 = load ptr, ptr %builtin_t, align 8
  ret ptr %439

label_2536:                                       ; preds = %label_2543, %label_2535
  %sc.149 = alloca i1, align 1
  %440 = load ptr, ptr %arg_ptr, align 8
  %441 = call i32 @str_equals(ptr %440, ptr @.str.s953)
  %442 = icmp eq i32 %441, 0
  store i1 %442, ptr %sc.149, align 1
  br i1 %442, label %label_2539, label %label_2540

label_2540:                                       ; preds = %label_2539, %label_2536
  %443 = load i1, ptr %sc.149, align 1
  br i1 %443, label %label_2537, label %label_2538

label_2539:                                       ; preds = %label_2536
  %444 = load ptr, ptr %param_ptr, align 8
  %445 = call i32 @str_equals(ptr %444, ptr @.str.s954)
  %446 = icmp eq i32 %445, 0
  store i1 %446, ptr %sc.149, align 1
  br label %label_2540

label_2538:                                       ; preds = %label_2540
  %447 = call ptr @type_void__Void()
  store ptr %447, ptr %ret_t, align 8
  %448 = load ptr, ptr %fn_node, align 8
  %449 = getelementptr inbounds nuw %ASTNode, ptr %448, i32 0, i32 0
  %450 = load i32, ptr %449, align 4
  %451 = icmp eq i32 %450, 4
  br i1 %451, label %label_2544, label %label_2545

label_2537:                                       ; preds = %label_2540
  %452 = load ptr, ptr %arg_ptr, align 8
  %453 = call ptr @ptr_to_node(ptr %452)
  store ptr %453, ptr %arg_node, align 8
  %454 = load ptr, ptr %param_ptr, align 8
  %455 = call ptr @ptr_to_node(ptr %454)
  store ptr %455, ptr %param_node, align 8
  %456 = load ptr, ptr %module, align 8
  %457 = load ptr, ptr %param_node, align 8
  %458 = getelementptr inbounds nuw %ASTNode, ptr %457, i32 0, i32 5
  %459 = load ptr, ptr %458, align 8
  %460 = call ptr @ptr_to_node(ptr %459)
  %461 = call ptr @sema_annotation_type__Struct_ASTNode_Struct_ASTNode(ptr %456, ptr %460)
  store ptr %461, ptr %param_t, align 8
  %462 = load ptr, ptr %module, align 8
  %463 = load ptr, ptr %arg_node, align 8
  %464 = load ptr, ptr %param_t, align 8
  %465 = load ptr, ptr %name, align 8
  %466 = call ptr @str_concat(ptr %465, ptr @.str.s955)
  %467 = call ptr @sema_check_value__Struct_ASTNode_Struct_ASTNode_Struct_TypeInfo_String(ptr %462, ptr %463, ptr %464, ptr %466)
  %468 = load ptr, ptr %param_node, align 8
  %469 = getelementptr inbounds nuw %ASTNode, ptr %468, i32 0, i32 2
  %470 = load ptr, ptr %469, align 8
  %471 = call i32 @str_equals(ptr %470, ptr @.str.s956)
  %472 = icmp eq i32 %471, 1
  br i1 %472, label %label_2541, label %label_2543

label_2543:                                       ; preds = %label_2541, %label_2537
  %473 = load ptr, ptr %arg_node, align 8
  %474 = getelementptr inbounds nuw %ASTNode, ptr %473, i32 0, i32 8
  %475 = load ptr, ptr %474, align 8
  store ptr %475, ptr %arg_ptr, align 8
  %476 = load ptr, ptr %param_node, align 8
  %477 = getelementptr inbounds nuw %ASTNode, ptr %476, i32 0, i32 8
  %478 = load ptr, ptr %477, align 8
  store ptr %478, ptr %param_ptr, align 8
  br label %label_2536

label_2541:                                       ; preds = %label_2537
  %479 = load ptr, ptr %arg_node, align 8
  call void @sema_move_operand__Struct_ASTNode(ptr %479)
  br label %label_2543

label_2545:                                       ; preds = %label_2538
  %480 = load ptr, ptr %module, align 8
  %481 = load ptr, ptr %fn_node, align 8
  %482 = getelementptr inbounds nuw %ASTNode, ptr %481, i32 0, i32 6
  %483 = load ptr, ptr %482, align 8
  %484 = call ptr @sema_declared_return_type__Struct_ASTNode_String(ptr %480, ptr %483)
  store ptr %484, ptr %ret_t, align 8
  br label %label_2546

label_2544:                                       ; preds = %label_2538
  %485 = load ptr, ptr %module, align 8
  %486 = load ptr, ptr %fn_node, align 8
  %487 = getelementptr inbounds nuw %ASTNode, ptr %486, i32 0, i32 7
  %488 = load ptr, ptr %487, align 8
  %489 = call ptr @sema_declared_return_type__Struct_ASTNode_String(ptr %485, ptr %488)
  store ptr %489, ptr %ret_t, align 8
  %490 = load ptr, ptr %name, align 8
  %491 = call i32 @str_equals(ptr %490, ptr @.str.s957)
  %492 = icmp eq i32 %491, 1
  br i1 %492, label %label_2547, label %label_2549

label_2549:                                       ; preds = %label_2547, %label_2544
  br label %label_2546

label_2547:                                       ; preds = %label_2544
  %493 = call ptr @type_int__Void()
  store ptr %493, ptr %ret_t, align 8
  br label %label_2549

label_2546:                                       ; preds = %label_2545, %label_2549
  %494 = load ptr, ptr %expr, align 8
  %495 = load ptr, ptr %module, align 8
  %496 = load ptr, ptr %fn_node, align 8
  %497 = call ptr @sema_function_symbol__Struct_ASTNode_Struct_ASTNode(ptr %495, ptr %496)
  %498 = getelementptr inbounds nuw %ASTNode, ptr %494, i32 0, i32 2
  store ptr %497, ptr %498, align 8
  %499 = load ptr, ptr %expr, align 8
  %500 = load ptr, ptr %ret_t, align 8
  call void @node_set_type__Struct_ASTNode_Struct_TypeInfo(ptr %499, ptr %500)
  %501 = load ptr, ptr %ret_t, align 8
  ret ptr %501

label_2552:                                       ; preds = %label_2532
  %502 = load ptr, ptr %expr, align 8
  %503 = getelementptr inbounds nuw %ASTNode, ptr %502, i32 0, i32 0
  %504 = load i32, ptr %503, align 4
  %505 = icmp eq i32 %504, 27
  br i1 %505, label %label_2561, label %label_2563

label_2550:                                       ; preds = %label_2532
  %506 = load ptr, ptr %expr, align 8
  %507 = getelementptr inbounds nuw %ASTNode, ptr %506, i32 0, i32 5
  %508 = load ptr, ptr %507, align 8
  %509 = call ptr @ptr_to_node(ptr %508)
  store ptr %509, ptr %object_node, align 8
  %sc.150 = alloca i1, align 1
  %510 = load ptr, ptr %object_node, align 8
  %511 = getelementptr inbounds nuw %ASTNode, ptr %510, i32 0, i32 0
  %512 = load i32, ptr %511, align 4
  %513 = icmp eq i32 %512, 23
  store i1 %513, ptr %sc.150, align 1
  br i1 %513, label %label_2553, label %label_2554

label_2554:                                       ; preds = %label_2553, %label_2550
  %514 = load i1, ptr %sc.150, align 1
  br i1 %514, label %label_2555, label %label_2557

label_2553:                                       ; preds = %label_2550
  %515 = load ptr, ptr %module, align 8
  %516 = load ptr, ptr %object_node, align 8
  %517 = getelementptr inbounds nuw %ASTNode, ptr %516, i32 0, i32 1
  %518 = load ptr, ptr %517, align 8
  %519 = load ptr, ptr %expr, align 8
  %520 = getelementptr inbounds nuw %ASTNode, ptr %519, i32 0, i32 1
  %521 = load ptr, ptr %520, align 8
  %522 = call i1 @sema_enum_has_variant__Struct_ASTNode_String_String(ptr %515, ptr %518, ptr %521)
  store i1 %522, ptr %sc.150, align 1
  br label %label_2554

label_2557:                                       ; preds = %label_2554
  %523 = load ptr, ptr %module, align 8
  %524 = load ptr, ptr %object_node, align 8
  %525 = call ptr @sema_expr__Struct_ASTNode_Struct_ASTNode(ptr %523, ptr %524)
  store ptr %525, ptr %object_t, align 8
  %526 = load ptr, ptr %object_t, align 8
  %527 = getelementptr inbounds nuw %TypeInfo, ptr %526, i32 0, i32 0
  %528 = load i32, ptr %527, align 4
  %529 = icmp ne i32 %528, 8
  br i1 %529, label %label_2558, label %label_2560

label_2555:                                       ; preds = %label_2554
  %530 = load ptr, ptr %expr, align 8
  %531 = call ptr @type_int__Void()
  call void @node_set_type__Struct_ASTNode_Struct_TypeInfo(ptr %530, ptr %531)
  %532 = call ptr @type_int__Void()
  ret ptr %532

label_2560:                                       ; preds = %label_2558, %label_2557
  %533 = load ptr, ptr %module, align 8
  %534 = load ptr, ptr %object_t, align 8
  %535 = getelementptr inbounds nuw %TypeInfo, ptr %534, i32 0, i32 1
  %536 = load ptr, ptr %535, align 8
  %537 = load ptr, ptr %expr, align 8
  %538 = getelementptr inbounds nuw %ASTNode, ptr %537, i32 0, i32 1
  %539 = load ptr, ptr %538, align 8
  %540 = call ptr @sema_find_struct_field_type__Struct_ASTNode_String_String(ptr %533, ptr %536, ptr %539)
  store ptr %540, ptr %field_t, align 8
  %541 = load ptr, ptr %expr, align 8
  %542 = load ptr, ptr %field_t, align 8
  call void @node_set_type__Struct_ASTNode_Struct_TypeInfo(ptr %541, ptr %542)
  %543 = load ptr, ptr %field_t, align 8
  ret ptr %543

label_2558:                                       ; preds = %label_2557
  call void @sema_error__String(ptr @.str.s958)
  br label %label_2560

label_2563:                                       ; preds = %label_2552
  %544 = load ptr, ptr %expr, align 8
  %545 = getelementptr inbounds nuw %ASTNode, ptr %544, i32 0, i32 0
  %546 = load i32, ptr %545, align 4
  %547 = icmp eq i32 %546, 26
  br i1 %547, label %label_2570, label %label_2572

label_2561:                                       ; preds = %label_2552
  %548 = load ptr, ptr %expr, align 8
  %549 = getelementptr inbounds nuw %ASTNode, ptr %548, i32 0, i32 5
  %550 = load ptr, ptr %549, align 8
  store ptr %550, ptr %elem_ptr, align 8
  %551 = load ptr, ptr %elem_ptr, align 8
  %552 = call i32 @str_equals(ptr %551, ptr @.str.s959)
  %553 = icmp eq i32 %552, 1
  br i1 %553, label %label_2564, label %label_2566

label_2566:                                       ; preds = %label_2561
  %554 = load ptr, ptr %module, align 8
  %555 = load ptr, ptr %elem_ptr, align 8
  %556 = call ptr @ptr_to_node(ptr %555)
  %557 = call ptr @sema_expr__Struct_ASTNode_Struct_ASTNode(ptr %554, ptr %556)
  store ptr %557, ptr %first_t, align 8
  %558 = load ptr, ptr %elem_ptr, align 8
  %559 = call ptr @ptr_to_node(ptr %558)
  %560 = getelementptr inbounds nuw %ASTNode, ptr %559, i32 0, i32 8
  %561 = load ptr, ptr %560, align 8
  store ptr %561, ptr %elem_ptr, align 8
  br label %label_2567

label_2564:                                       ; preds = %label_2561
  %562 = call ptr @type_invalid__Void()
  %563 = call ptr @type_array__Struct_TypeInfo(ptr %562)
  store ptr %563, ptr %arr_t, align 8
  %564 = load ptr, ptr %expr, align 8
  %565 = load ptr, ptr %arr_t, align 8
  call void @node_set_type__Struct_ASTNode_Struct_TypeInfo(ptr %564, ptr %565)
  %566 = load ptr, ptr %arr_t, align 8
  ret ptr %566

label_2567:                                       ; preds = %label_2568, %label_2566
  %567 = load ptr, ptr %elem_ptr, align 8
  %568 = call i32 @str_equals(ptr %567, ptr @.str.s960)
  %569 = icmp eq i32 %568, 0
  br i1 %569, label %label_2568, label %label_2569

label_2569:                                       ; preds = %label_2567
  %570 = load ptr, ptr %first_t, align 8
  %571 = call ptr @type_array__Struct_TypeInfo(ptr %570)
  store ptr %571, ptr %arr_t2, align 8
  %572 = load ptr, ptr %expr, align 8
  %573 = load ptr, ptr %arr_t2, align 8
  call void @node_set_type__Struct_ASTNode_Struct_TypeInfo(ptr %572, ptr %573)
  %574 = load ptr, ptr %arr_t2, align 8
  ret ptr %574

label_2568:                                       ; preds = %label_2567
  %575 = load ptr, ptr %elem_ptr, align 8
  %576 = call ptr @ptr_to_node(ptr %575)
  store ptr %576, ptr %elem, align 8
  %577 = load ptr, ptr %module, align 8
  %578 = load ptr, ptr %elem, align 8
  %579 = call ptr @sema_expr__Struct_ASTNode_Struct_ASTNode(ptr %577, ptr %578)
  store ptr %579, ptr %elem_t, align 8
  %580 = load ptr, ptr %first_t, align 8
  %581 = load ptr, ptr %elem_t, align 8
  call void @sema_expect_assignable__String_Struct_TypeInfo_Struct_TypeInfo(ptr @.str.s961, ptr %580, ptr %581)
  %582 = load ptr, ptr %elem, align 8
  %583 = getelementptr inbounds nuw %ASTNode, ptr %582, i32 0, i32 8
  %584 = load ptr, ptr %583, align 8
  store ptr %584, ptr %elem_ptr, align 8
  br label %label_2567

label_2572:                                       ; preds = %label_2563
  %585 = load ptr, ptr %expr, align 8
  %586 = getelementptr inbounds nuw %ASTNode, ptr %585, i32 0, i32 0
  %587 = load i32, ptr %586, align 4
  %588 = icmp eq i32 %587, 28
  br i1 %588, label %label_2576, label %label_2578

label_2570:                                       ; preds = %label_2563
  %589 = load ptr, ptr %module, align 8
  %590 = load ptr, ptr %expr, align 8
  %591 = getelementptr inbounds nuw %ASTNode, ptr %590, i32 0, i32 5
  %592 = load ptr, ptr %591, align 8
  %593 = call ptr @ptr_to_node(ptr %592)
  %594 = call ptr @sema_expr__Struct_ASTNode_Struct_ASTNode(ptr %589, ptr %593)
  store ptr %594, ptr %array_t, align 8
  %595 = load ptr, ptr %module, align 8
  %596 = load ptr, ptr %expr, align 8
  %597 = getelementptr inbounds nuw %ASTNode, ptr %596, i32 0, i32 6
  %598 = load ptr, ptr %597, align 8
  %599 = call ptr @ptr_to_node(ptr %598)
  %600 = call ptr @sema_expr__Struct_ASTNode_Struct_ASTNode(ptr %595, ptr %599)
  store ptr %600, ptr %index_t, align 8
  %601 = call ptr @type_int__Void()
  %602 = load ptr, ptr %index_t, align 8
  call void @sema_expect_assignable__String_Struct_TypeInfo_Struct_TypeInfo(ptr @.str.s962, ptr %601, ptr %602)
  %603 = load ptr, ptr %array_t, align 8
  %604 = getelementptr inbounds nuw %TypeInfo, ptr %603, i32 0, i32 0
  %605 = load i32, ptr %604, align 4
  %606 = icmp ne i32 %605, 10
  br i1 %606, label %label_2573, label %label_2575

label_2575:                                       ; preds = %label_2573, %label_2570
  %607 = load ptr, ptr %array_t, align 8
  %608 = getelementptr inbounds nuw %TypeInfo, ptr %607, i32 0, i32 3
  %609 = load ptr, ptr %608, align 8
  %610 = call ptr @ptr_to_type(ptr %609)
  store ptr %610, ptr %elem_t, align 8
  %611 = load ptr, ptr %expr, align 8
  %612 = load ptr, ptr %elem_t, align 8
  call void @node_set_type__Struct_ASTNode_Struct_TypeInfo(ptr %611, ptr %612)
  %613 = load ptr, ptr %elem_t, align 8
  ret ptr %613

label_2573:                                       ; preds = %label_2570
  call void @sema_error__String(ptr @.str.s963)
  br label %label_2575

label_2578:                                       ; preds = %label_2572
  call void @sema_error__String(ptr @.str.s967)
  %614 = call ptr @type_invalid__Void()
  ret ptr %614

label_2576:                                       ; preds = %label_2572
  %615 = load ptr, ptr %module, align 8
  %616 = load ptr, ptr %expr, align 8
  %617 = getelementptr inbounds nuw %ASTNode, ptr %616, i32 0, i32 1
  %618 = load ptr, ptr %617, align 8
  %619 = call i1 @sema_has_struct__Struct_ASTNode_String(ptr %615, ptr %618)
  %620 = icmp eq i1 %619, false
  br i1 %620, label %label_2579, label %label_2581

label_2581:                                       ; preds = %label_2579, %label_2576
  %621 = load ptr, ptr %expr, align 8
  %622 = getelementptr inbounds nuw %ASTNode, ptr %621, i32 0, i32 5
  %623 = load ptr, ptr %622, align 8
  store ptr %623, ptr %field_ptr, align 8
  br label %label_2582

label_2579:                                       ; preds = %label_2576
  %624 = load ptr, ptr %expr, align 8
  %625 = getelementptr inbounds nuw %ASTNode, ptr %624, i32 0, i32 1
  %626 = load ptr, ptr %625, align 8
  %627 = call ptr @str_concat(ptr @.str.s964, ptr %626)
  call void @sema_error__String(ptr %627)
  br label %label_2581

label_2582:                                       ; preds = %label_2583, %label_2581
  %628 = load ptr, ptr %field_ptr, align 8
  %629 = call i32 @str_equals(ptr %628, ptr @.str.s965)
  %630 = icmp eq i32 %629, 0
  br i1 %630, label %label_2583, label %label_2584

label_2584:                                       ; preds = %label_2582
  %631 = load ptr, ptr %expr, align 8
  %632 = getelementptr inbounds nuw %ASTNode, ptr %631, i32 0, i32 1
  %633 = load ptr, ptr %632, align 8
  %634 = call ptr @type_struct__String(ptr %633)
  store ptr %634, ptr %struct_t, align 8
  %635 = load ptr, ptr %expr, align 8
  %636 = load ptr, ptr %struct_t, align 8
  call void @node_set_type__Struct_ASTNode_Struct_TypeInfo(ptr %635, ptr %636)
  %637 = load ptr, ptr %struct_t, align 8
  ret ptr %637

label_2583:                                       ; preds = %label_2582
  %638 = load ptr, ptr %field_ptr, align 8
  %639 = call ptr @ptr_to_node(ptr %638)
  store ptr %639, ptr %field, align 8
  %640 = load ptr, ptr %module, align 8
  %641 = load ptr, ptr %expr, align 8
  %642 = getelementptr inbounds nuw %ASTNode, ptr %641, i32 0, i32 1
  %643 = load ptr, ptr %642, align 8
  %644 = load ptr, ptr %field, align 8
  %645 = getelementptr inbounds nuw %ASTNode, ptr %644, i32 0, i32 1
  %646 = load ptr, ptr %645, align 8
  %647 = call ptr @sema_find_struct_field_type__Struct_ASTNode_String_String(ptr %640, ptr %643, ptr %646)
  store ptr %647, ptr %expected, align 8
  %648 = load ptr, ptr %module, align 8
  %649 = load ptr, ptr %field, align 8
  %650 = getelementptr inbounds nuw %ASTNode, ptr %649, i32 0, i32 5
  %651 = load ptr, ptr %650, align 8
  %652 = call ptr @ptr_to_node(ptr %651)
  %653 = load ptr, ptr %expected, align 8
  %654 = load ptr, ptr %field, align 8
  %655 = getelementptr inbounds nuw %ASTNode, ptr %654, i32 0, i32 1
  %656 = load ptr, ptr %655, align 8
  %657 = call ptr @str_concat(ptr @.str.s966, ptr %656)
  %658 = call ptr @sema_check_value__Struct_ASTNode_Struct_ASTNode_Struct_TypeInfo_String(ptr %648, ptr %652, ptr %653, ptr %657)
  %659 = load ptr, ptr %field, align 8
  %660 = getelementptr inbounds nuw %ASTNode, ptr %659, i32 0, i32 5
  %661 = load ptr, ptr %660, align 8
  %662 = call ptr @ptr_to_node(ptr %661)
  call void @sema_move_operand__Struct_ASTNode(ptr %662)
  %663 = load ptr, ptr %field, align 8
  %664 = getelementptr inbounds nuw %ASTNode, ptr %663, i32 0, i32 8
  %665 = load ptr, ptr %664, align 8
  store ptr %665, ptr %field_ptr, align 8
  br label %label_2582
}

define ptr @sema_find_function__Struct_ASTNode_String(ptr %0, ptr %1) {
entry:
  %module = alloca ptr, align 8
  store ptr %0, ptr %module, align 8
  %name = alloca ptr, align 8
  store ptr %1, ptr %name, align 8
  %stmt_ptr = alloca ptr, align 8
  %stmt = alloca ptr, align 8
  %2 = load ptr, ptr %module, align 8
  %3 = getelementptr inbounds nuw %ASTNode, ptr %2, i32 0, i32 5
  %4 = load ptr, ptr %3, align 8
  store ptr %4, ptr %stmt_ptr, align 8
  br label %label_2145

label_2145:                                       ; preds = %label_2154, %entry
  %5 = load ptr, ptr %stmt_ptr, align 8
  %6 = call i32 @str_equals(ptr %5, ptr @.str.s835)
  %7 = icmp eq i32 %6, 0
  br i1 %7, label %label_2146, label %label_2147

label_2147:                                       ; preds = %label_2145
  %8 = call ptr @create_node__Enum_NodeKind(i32 0)
  ret ptr %8

label_2146:                                       ; preds = %label_2145
  %9 = load ptr, ptr %stmt_ptr, align 8
  %10 = call ptr @ptr_to_node(ptr %9)
  store ptr %10, ptr %stmt, align 8
  %sc.96 = alloca i1, align 1
  %sc.97 = alloca i1, align 1
  %11 = load ptr, ptr %stmt, align 8
  %12 = getelementptr inbounds nuw %ASTNode, ptr %11, i32 0, i32 0
  %13 = load i32, ptr %12, align 4
  %14 = icmp eq i32 %13, 4
  store i1 %14, ptr %sc.97, align 1
  br i1 %14, label %label_2151, label %label_2150

label_2150:                                       ; preds = %label_2146
  %15 = load ptr, ptr %stmt, align 8
  %16 = getelementptr inbounds nuw %ASTNode, ptr %15, i32 0, i32 0
  %17 = load i32, ptr %16, align 4
  %18 = icmp eq i32 %17, 2
  store i1 %18, ptr %sc.97, align 1
  br label %label_2151

label_2151:                                       ; preds = %label_2150, %label_2146
  %19 = load i1, ptr %sc.97, align 1
  store i1 %19, ptr %sc.96, align 1
  br i1 %19, label %label_2148, label %label_2149

label_2149:                                       ; preds = %label_2148, %label_2151
  %20 = load i1, ptr %sc.96, align 1
  br i1 %20, label %label_2152, label %label_2154

label_2148:                                       ; preds = %label_2151
  %21 = load ptr, ptr %stmt, align 8
  %22 = getelementptr inbounds nuw %ASTNode, ptr %21, i32 0, i32 1
  %23 = load ptr, ptr %22, align 8
  %24 = load ptr, ptr %name, align 8
  %25 = call i32 @str_equals(ptr %23, ptr %24)
  %26 = icmp eq i32 %25, 1
  store i1 %26, ptr %sc.96, align 1
  br label %label_2149

label_2154:                                       ; preds = %label_2149
  %27 = load ptr, ptr %stmt, align 8
  %28 = getelementptr inbounds nuw %ASTNode, ptr %27, i32 0, i32 8
  %29 = load ptr, ptr %28, align 8
  store ptr %29, ptr %stmt_ptr, align 8
  br label %label_2145

label_2152:                                       ; preds = %label_2149
  %30 = load ptr, ptr %stmt, align 8
  ret ptr %30
}

define i1 @sema_arg_matches_type__Struct_ASTNode_Struct_ASTNode_Struct_TypeInfo(ptr %0, ptr %1, ptr %2) {
entry:
  %module = alloca ptr, align 8
  store ptr %0, ptr %module, align 8
  %arg_node = alloca ptr, align 8
  store ptr %1, ptr %arg_node, align 8
  %expected = alloca ptr, align 8
  store ptr %2, ptr %expected, align 8
  %actual = alloca ptr, align 8
  %sc.98 = alloca i1, align 1
  %sc.99 = alloca i1, align 1
  %3 = load ptr, ptr %expected, align 8
  %4 = call i1 @type_is_valid__Struct_TypeInfo(ptr %3)
  store i1 %4, ptr %sc.99, align 1
  br i1 %4, label %label_2157, label %label_2158

label_2158:                                       ; preds = %label_2157, %entry
  %5 = load i1, ptr %sc.99, align 1
  store i1 %5, ptr %sc.98, align 1
  br i1 %5, label %label_2155, label %label_2156

label_2157:                                       ; preds = %entry
  %6 = load ptr, ptr %expected, align 8
  %7 = getelementptr inbounds nuw %TypeInfo, ptr %6, i32 0, i32 0
  %8 = load i32, ptr %7, align 4
  %9 = icmp eq i32 %8, 2
  store i1 %9, ptr %sc.99, align 1
  br label %label_2158

label_2156:                                       ; preds = %label_2155, %label_2158
  %10 = load i1, ptr %sc.98, align 1
  br i1 %10, label %label_2159, label %label_2161

label_2155:                                       ; preds = %label_2158
  %11 = load ptr, ptr %arg_node, align 8
  %12 = call i1 @sema_is_int_literal__Struct_ASTNode(ptr %11)
  store i1 %12, ptr %sc.98, align 1
  br label %label_2156

label_2161:                                       ; preds = %label_2156
  %13 = load ptr, ptr %module, align 8
  %14 = load ptr, ptr %arg_node, align 8
  %15 = call ptr @sema_expr__Struct_ASTNode_Struct_ASTNode(ptr %13, ptr %14)
  store ptr %15, ptr %actual, align 8
  %16 = load ptr, ptr %expected, align 8
  %17 = load ptr, ptr %actual, align 8
  %18 = call i1 @sema_types_match__Struct_TypeInfo_Struct_TypeInfo(ptr %16, ptr %17)
  ret i1 %18

label_2159:                                       ; preds = %label_2156
  ret i1 true
}

define i1 @sema_signature_matches_call__Struct_ASTNode_Struct_ASTNode_String(ptr %0, ptr %1, ptr %2) {
entry:
  %module = alloca ptr, align 8
  store ptr %0, ptr %module, align 8
  %fn_node = alloca ptr, align 8
  store ptr %1, ptr %fn_node, align 8
  %arg_ptr = alloca ptr, align 8
  store ptr %2, ptr %arg_ptr, align 8
  %arg = alloca ptr, align 8
  %param = alloca ptr, align 8
  %arg_node = alloca ptr, align 8
  %param_node = alloca ptr, align 8
  %param_t = alloca ptr, align 8
  %3 = load ptr, ptr %arg_ptr, align 8
  store ptr %3, ptr %arg, align 8
  %4 = load ptr, ptr %fn_node, align 8
  %5 = getelementptr inbounds nuw %ASTNode, ptr %4, i32 0, i32 5
  %6 = load ptr, ptr %5, align 8
  store ptr %6, ptr %param, align 8
  br label %label_2162

label_2162:                                       ; preds = %label_2169, %entry
  %sc.100 = alloca i1, align 1
  %7 = load ptr, ptr %arg, align 8
  %8 = call i32 @str_equals(ptr %7, ptr @.str.s836)
  %9 = icmp eq i32 %8, 0
  store i1 %9, ptr %sc.100, align 1
  br i1 %9, label %label_2165, label %label_2166

label_2166:                                       ; preds = %label_2165, %label_2162
  %10 = load i1, ptr %sc.100, align 1
  br i1 %10, label %label_2163, label %label_2164

label_2165:                                       ; preds = %label_2162
  %11 = load ptr, ptr %param, align 8
  %12 = call i32 @str_equals(ptr %11, ptr @.str.s837)
  %13 = icmp eq i32 %12, 0
  store i1 %13, ptr %sc.100, align 1
  br label %label_2166

label_2164:                                       ; preds = %label_2166
  %sc.101 = alloca i1, align 1
  %14 = load ptr, ptr %arg, align 8
  %15 = call i32 @str_equals(ptr %14, ptr @.str.s838)
  %16 = icmp eq i32 %15, 1
  store i1 %16, ptr %sc.101, align 1
  br i1 %16, label %label_2170, label %label_2171

label_2163:                                       ; preds = %label_2166
  %17 = load ptr, ptr %arg, align 8
  %18 = call ptr @ptr_to_node(ptr %17)
  store ptr %18, ptr %arg_node, align 8
  %19 = load ptr, ptr %param, align 8
  %20 = call ptr @ptr_to_node(ptr %19)
  store ptr %20, ptr %param_node, align 8
  %21 = load ptr, ptr %module, align 8
  %22 = load ptr, ptr %param_node, align 8
  %23 = getelementptr inbounds nuw %ASTNode, ptr %22, i32 0, i32 5
  %24 = load ptr, ptr %23, align 8
  %25 = call ptr @ptr_to_node(ptr %24)
  %26 = call ptr @sema_annotation_type__Struct_ASTNode_Struct_ASTNode(ptr %21, ptr %25)
  store ptr %26, ptr %param_t, align 8
  %27 = load ptr, ptr %module, align 8
  %28 = load ptr, ptr %arg_node, align 8
  %29 = load ptr, ptr %param_t, align 8
  %30 = call i1 @sema_arg_matches_type__Struct_ASTNode_Struct_ASTNode_Struct_TypeInfo(ptr %27, ptr %28, ptr %29)
  %31 = icmp eq i1 %30, false
  br i1 %31, label %label_2167, label %label_2169

label_2169:                                       ; preds = %label_2163
  %32 = load ptr, ptr %arg_node, align 8
  %33 = getelementptr inbounds nuw %ASTNode, ptr %32, i32 0, i32 8
  %34 = load ptr, ptr %33, align 8
  store ptr %34, ptr %arg, align 8
  %35 = load ptr, ptr %param_node, align 8
  %36 = getelementptr inbounds nuw %ASTNode, ptr %35, i32 0, i32 8
  %37 = load ptr, ptr %36, align 8
  store ptr %37, ptr %param, align 8
  br label %label_2162

label_2167:                                       ; preds = %label_2163
  ret i1 false

label_2171:                                       ; preds = %label_2170, %label_2164
  %38 = load i1, ptr %sc.101, align 1
  ret i1 %38

label_2170:                                       ; preds = %label_2164
  %39 = load ptr, ptr %param, align 8
  %40 = call i32 @str_equals(ptr %39, ptr @.str.s839)
  %41 = icmp eq i32 %40, 1
  store i1 %41, ptr %sc.101, align 1
  br label %label_2171
}

define i1 @sema_has_function_definition__Struct_ASTNode_String(ptr %0, ptr %1) {
entry:
  %module = alloca ptr, align 8
  store ptr %0, ptr %module, align 8
  %name = alloca ptr, align 8
  store ptr %1, ptr %name, align 8
  %scan_ptr = alloca ptr, align 8
  %scan = alloca ptr, align 8
  %2 = load ptr, ptr %module, align 8
  %3 = getelementptr inbounds nuw %ASTNode, ptr %2, i32 0, i32 5
  %4 = load ptr, ptr %3, align 8
  store ptr %4, ptr %scan_ptr, align 8
  br label %label_2172

label_2172:                                       ; preds = %label_2179, %entry
  %5 = load ptr, ptr %scan_ptr, align 8
  %6 = call i32 @str_equals(ptr %5, ptr @.str.s840)
  %7 = icmp eq i32 %6, 0
  br i1 %7, label %label_2173, label %label_2174

label_2174:                                       ; preds = %label_2172
  ret i1 false

label_2173:                                       ; preds = %label_2172
  %8 = load ptr, ptr %scan_ptr, align 8
  %9 = call ptr @ptr_to_node(ptr %8)
  store ptr %9, ptr %scan, align 8
  %sc.102 = alloca i1, align 1
  %10 = load ptr, ptr %scan, align 8
  %11 = getelementptr inbounds nuw %ASTNode, ptr %10, i32 0, i32 0
  %12 = load i32, ptr %11, align 4
  %13 = icmp eq i32 %12, 4
  store i1 %13, ptr %sc.102, align 1
  br i1 %13, label %label_2175, label %label_2176

label_2176:                                       ; preds = %label_2175, %label_2173
  %14 = load i1, ptr %sc.102, align 1
  br i1 %14, label %label_2177, label %label_2179

label_2175:                                       ; preds = %label_2173
  %15 = load ptr, ptr %scan, align 8
  %16 = getelementptr inbounds nuw %ASTNode, ptr %15, i32 0, i32 1
  %17 = load ptr, ptr %16, align 8
  %18 = load ptr, ptr %name, align 8
  %19 = call i32 @str_equals(ptr %17, ptr %18)
  %20 = icmp eq i32 %19, 1
  store i1 %20, ptr %sc.102, align 1
  br label %label_2176

label_2179:                                       ; preds = %label_2176
  %21 = load ptr, ptr %scan, align 8
  %22 = getelementptr inbounds nuw %ASTNode, ptr %21, i32 0, i32 8
  %23 = load ptr, ptr %22, align 8
  store ptr %23, ptr %scan_ptr, align 8
  br label %label_2172

label_2177:                                       ; preds = %label_2176
  ret i1 true
}

define ptr @sema_find_function_overload__Struct_ASTNode_String_String(ptr %0, ptr %1, ptr %2) {
entry:
  %module = alloca ptr, align 8
  store ptr %0, ptr %module, align 8
  %name = alloca ptr, align 8
  store ptr %1, ptr %name, align 8
  %arg_ptr = alloca ptr, align 8
  store ptr %2, ptr %arg_ptr, align 8
  %best_ptr = alloca ptr, align 8
  %match_count = alloca i32, align 4
  %name_seen = alloca i1, align 1
  %definition_exists = alloca i1, align 1
  %stmt_ptr = alloca ptr, align 8
  %stmt = alloca ptr, align 8
  %is_candidate = alloca i1, align 1
  store ptr @.str.s841, ptr %best_ptr, align 8
  store i32 0, ptr %match_count, align 4
  store i1 false, ptr %name_seen, align 1
  %3 = load ptr, ptr %module, align 8
  %4 = load ptr, ptr %name, align 8
  %5 = call i1 @sema_has_function_definition__Struct_ASTNode_String(ptr %3, ptr %4)
  store i1 %5, ptr %definition_exists, align 1
  %6 = load ptr, ptr %module, align 8
  %7 = getelementptr inbounds nuw %ASTNode, ptr %6, i32 0, i32 5
  %8 = load ptr, ptr %7, align 8
  store ptr %8, ptr %stmt_ptr, align 8
  br label %label_2180

label_2180:                                       ; preds = %label_2192, %entry
  %9 = load ptr, ptr %stmt_ptr, align 8
  %10 = call i32 @str_equals(ptr %9, ptr @.str.s842)
  %11 = icmp eq i32 %10, 0
  br i1 %11, label %label_2181, label %label_2182

label_2182:                                       ; preds = %label_2180
  %12 = load i32, ptr %match_count, align 4
  %13 = icmp sgt i32 %12, 1
  br i1 %13, label %label_2196, label %label_2198

label_2181:                                       ; preds = %label_2180
  %14 = load ptr, ptr %stmt_ptr, align 8
  %15 = call ptr @ptr_to_node(ptr %14)
  store ptr %15, ptr %stmt, align 8
  %16 = load ptr, ptr %stmt, align 8
  %17 = getelementptr inbounds nuw %ASTNode, ptr %16, i32 0, i32 0
  %18 = load i32, ptr %17, align 4
  %19 = icmp eq i32 %18, 4
  store i1 %19, ptr %is_candidate, align 1
  %sc.103 = alloca i1, align 1
  %20 = load ptr, ptr %stmt, align 8
  %21 = getelementptr inbounds nuw %ASTNode, ptr %20, i32 0, i32 0
  %22 = load i32, ptr %21, align 4
  %23 = icmp eq i32 %22, 2
  store i1 %23, ptr %sc.103, align 1
  br i1 %23, label %label_2183, label %label_2184

label_2184:                                       ; preds = %label_2183, %label_2181
  %24 = load i1, ptr %sc.103, align 1
  br i1 %24, label %label_2185, label %label_2187

label_2183:                                       ; preds = %label_2181
  %25 = load i1, ptr %definition_exists, align 1
  %26 = icmp eq i1 %25, false
  store i1 %26, ptr %sc.103, align 1
  br label %label_2184

label_2187:                                       ; preds = %label_2185, %label_2184
  %sc.104 = alloca i1, align 1
  %27 = load i1, ptr %is_candidate, align 1
  store i1 %27, ptr %sc.104, align 1
  br i1 %27, label %label_2188, label %label_2189

label_2185:                                       ; preds = %label_2184
  store i1 true, ptr %is_candidate, align 1
  br label %label_2187

label_2189:                                       ; preds = %label_2188, %label_2187
  %28 = load i1, ptr %sc.104, align 1
  br i1 %28, label %label_2190, label %label_2192

label_2188:                                       ; preds = %label_2187
  %29 = load ptr, ptr %stmt, align 8
  %30 = getelementptr inbounds nuw %ASTNode, ptr %29, i32 0, i32 1
  %31 = load ptr, ptr %30, align 8
  %32 = load ptr, ptr %name, align 8
  %33 = call i32 @str_equals(ptr %31, ptr %32)
  %34 = icmp eq i32 %33, 1
  store i1 %34, ptr %sc.104, align 1
  br label %label_2189

label_2192:                                       ; preds = %label_2195, %label_2189
  %35 = load ptr, ptr %stmt, align 8
  %36 = getelementptr inbounds nuw %ASTNode, ptr %35, i32 0, i32 8
  %37 = load ptr, ptr %36, align 8
  store ptr %37, ptr %stmt_ptr, align 8
  br label %label_2180

label_2190:                                       ; preds = %label_2189
  store i1 true, ptr %name_seen, align 1
  %38 = load ptr, ptr %module, align 8
  %39 = load ptr, ptr %stmt, align 8
  %40 = load ptr, ptr %arg_ptr, align 8
  %41 = call i1 @sema_signature_matches_call__Struct_ASTNode_Struct_ASTNode_String(ptr %38, ptr %39, ptr %40)
  br i1 %41, label %label_2193, label %label_2195

label_2195:                                       ; preds = %label_2193, %label_2190
  br label %label_2192

label_2193:                                       ; preds = %label_2190
  %42 = load ptr, ptr %stmt_ptr, align 8
  store ptr %42, ptr %best_ptr, align 8
  %43 = load i32, ptr %match_count, align 4
  %44 = add i32 %43, 1
  store i32 %44, ptr %match_count, align 4
  br label %label_2195

label_2198:                                       ; preds = %label_2196, %label_2182
  %45 = load i32, ptr %match_count, align 4
  %46 = icmp eq i32 %45, 1
  br i1 %46, label %label_2199, label %label_2201

label_2196:                                       ; preds = %label_2182
  %47 = load ptr, ptr %name, align 8
  %48 = call ptr @str_concat(ptr @.str.s843, ptr %47)
  call void @sema_error__String(ptr %48)
  br label %label_2198

label_2201:                                       ; preds = %label_2198
  %49 = load i1, ptr %name_seen, align 1
  br i1 %49, label %label_2202, label %label_2204

label_2199:                                       ; preds = %label_2198
  %50 = load ptr, ptr %best_ptr, align 8
  %51 = call ptr @ptr_to_node(ptr %50)
  ret ptr %51

label_2204:                                       ; preds = %label_2202, %label_2201
  %52 = load ptr, ptr %name, align 8
  %53 = call ptr @str_concat(ptr @.str.s845, ptr %52)
  call void @sema_error__String(ptr %53)
  %54 = call ptr @create_node__Enum_NodeKind(i32 0)
  ret ptr %54

label_2202:                                       ; preds = %label_2201
  %55 = load ptr, ptr %name, align 8
  %56 = call ptr @str_concat(ptr @.str.s844, ptr %55)
  call void @sema_error__String(ptr %56)
  br label %label_2204
}

define ptr @sema_find_struct_field_type__Struct_ASTNode_String_String(ptr %0, ptr %1, ptr %2) {
entry:
  %module = alloca ptr, align 8
  store ptr %0, ptr %module, align 8
  %struct_name = alloca ptr, align 8
  store ptr %1, ptr %struct_name, align 8
  %field_name = alloca ptr, align 8
  store ptr %2, ptr %field_name, align 8
  %stmt_ptr = alloca ptr, align 8
  %stmt = alloca ptr, align 8
  %field_ptr = alloca ptr, align 8
  %field = alloca ptr, align 8
  %3 = load ptr, ptr %module, align 8
  %4 = getelementptr inbounds nuw %ASTNode, ptr %3, i32 0, i32 5
  %5 = load ptr, ptr %4, align 8
  store ptr %5, ptr %stmt_ptr, align 8
  br label %label_2205

label_2205:                                       ; preds = %label_2212, %entry
  %6 = load ptr, ptr %stmt_ptr, align 8
  %7 = call i32 @str_equals(ptr %6, ptr @.str.s846)
  %8 = icmp eq i32 %7, 0
  br i1 %8, label %label_2206, label %label_2207

label_2207:                                       ; preds = %label_2205
  %9 = load ptr, ptr %field_name, align 8
  %10 = call ptr @str_concat(ptr @.str.s848, ptr %9)
  %11 = load ptr, ptr %struct_name, align 8
  %12 = call ptr @str_concat(ptr @.str.s849, ptr %11)
  %13 = call ptr @str_concat(ptr %10, ptr %12)
  call void @sema_error__String(ptr %13)
  %14 = call ptr @type_invalid__Void()
  ret ptr %14

label_2206:                                       ; preds = %label_2205
  %15 = load ptr, ptr %stmt_ptr, align 8
  %16 = call ptr @ptr_to_node(ptr %15)
  store ptr %16, ptr %stmt, align 8
  %sc.105 = alloca i1, align 1
  %17 = load ptr, ptr %stmt, align 8
  %18 = getelementptr inbounds nuw %ASTNode, ptr %17, i32 0, i32 0
  %19 = load i32, ptr %18, align 4
  %20 = icmp eq i32 %19, 5
  store i1 %20, ptr %sc.105, align 1
  br i1 %20, label %label_2208, label %label_2209

label_2209:                                       ; preds = %label_2208, %label_2206
  %21 = load i1, ptr %sc.105, align 1
  br i1 %21, label %label_2210, label %label_2212

label_2208:                                       ; preds = %label_2206
  %22 = load ptr, ptr %stmt, align 8
  %23 = getelementptr inbounds nuw %ASTNode, ptr %22, i32 0, i32 1
  %24 = load ptr, ptr %23, align 8
  %25 = load ptr, ptr %struct_name, align 8
  %26 = call i32 @str_equals(ptr %24, ptr %25)
  %27 = icmp eq i32 %26, 1
  store i1 %27, ptr %sc.105, align 1
  br label %label_2209

label_2212:                                       ; preds = %label_2215, %label_2209
  %28 = load ptr, ptr %stmt, align 8
  %29 = getelementptr inbounds nuw %ASTNode, ptr %28, i32 0, i32 8
  %30 = load ptr, ptr %29, align 8
  store ptr %30, ptr %stmt_ptr, align 8
  br label %label_2205

label_2210:                                       ; preds = %label_2209
  %31 = load ptr, ptr %stmt, align 8
  %32 = getelementptr inbounds nuw %ASTNode, ptr %31, i32 0, i32 5
  %33 = load ptr, ptr %32, align 8
  store ptr %33, ptr %field_ptr, align 8
  br label %label_2213

label_2213:                                       ; preds = %label_2218, %label_2210
  %34 = load ptr, ptr %field_ptr, align 8
  %35 = call i32 @str_equals(ptr %34, ptr @.str.s847)
  %36 = icmp eq i32 %35, 0
  br i1 %36, label %label_2214, label %label_2215

label_2215:                                       ; preds = %label_2213
  br label %label_2212

label_2214:                                       ; preds = %label_2213
  %37 = load ptr, ptr %field_ptr, align 8
  %38 = call ptr @ptr_to_node(ptr %37)
  store ptr %38, ptr %field, align 8
  %39 = load ptr, ptr %field, align 8
  %40 = getelementptr inbounds nuw %ASTNode, ptr %39, i32 0, i32 1
  %41 = load ptr, ptr %40, align 8
  %42 = load ptr, ptr %field_name, align 8
  %43 = call i32 @str_equals(ptr %41, ptr %42)
  %44 = icmp eq i32 %43, 1
  br i1 %44, label %label_2216, label %label_2218

label_2218:                                       ; preds = %label_2214
  %45 = load ptr, ptr %field, align 8
  %46 = getelementptr inbounds nuw %ASTNode, ptr %45, i32 0, i32 8
  %47 = load ptr, ptr %46, align 8
  store ptr %47, ptr %field_ptr, align 8
  br label %label_2213

label_2216:                                       ; preds = %label_2214
  %48 = load ptr, ptr %module, align 8
  %49 = load ptr, ptr %field, align 8
  %50 = getelementptr inbounds nuw %ASTNode, ptr %49, i32 0, i32 5
  %51 = load ptr, ptr %50, align 8
  %52 = call ptr @ptr_to_node(ptr %51)
  %53 = call ptr @sema_annotation_type__Struct_ASTNode_Struct_ASTNode(ptr %48, ptr %52)
  ret ptr %53
}

define i1 @sema_enum_has_variant__Struct_ASTNode_String_String(ptr %0, ptr %1, ptr %2) {
entry:
  %module = alloca ptr, align 8
  store ptr %0, ptr %module, align 8
  %enum_name = alloca ptr, align 8
  store ptr %1, ptr %enum_name, align 8
  %variant_name = alloca ptr, align 8
  store ptr %2, ptr %variant_name, align 8
  %stmt_ptr = alloca ptr, align 8
  %stmt = alloca ptr, align 8
  %variant_ptr = alloca ptr, align 8
  %variant = alloca ptr, align 8
  %3 = load ptr, ptr %module, align 8
  %4 = getelementptr inbounds nuw %ASTNode, ptr %3, i32 0, i32 5
  %5 = load ptr, ptr %4, align 8
  store ptr %5, ptr %stmt_ptr, align 8
  br label %label_2219

label_2219:                                       ; preds = %label_2226, %entry
  %6 = load ptr, ptr %stmt_ptr, align 8
  %7 = call i32 @str_equals(ptr %6, ptr @.str.s850)
  %8 = icmp eq i32 %7, 0
  br i1 %8, label %label_2220, label %label_2221

label_2221:                                       ; preds = %label_2219
  ret i1 false

label_2220:                                       ; preds = %label_2219
  %9 = load ptr, ptr %stmt_ptr, align 8
  %10 = call ptr @ptr_to_node(ptr %9)
  store ptr %10, ptr %stmt, align 8
  %sc.106 = alloca i1, align 1
  %11 = load ptr, ptr %stmt, align 8
  %12 = getelementptr inbounds nuw %ASTNode, ptr %11, i32 0, i32 0
  %13 = load i32, ptr %12, align 4
  %14 = icmp eq i32 %13, 6
  store i1 %14, ptr %sc.106, align 1
  br i1 %14, label %label_2222, label %label_2223

label_2223:                                       ; preds = %label_2222, %label_2220
  %15 = load i1, ptr %sc.106, align 1
  br i1 %15, label %label_2224, label %label_2226

label_2222:                                       ; preds = %label_2220
  %16 = load ptr, ptr %stmt, align 8
  %17 = getelementptr inbounds nuw %ASTNode, ptr %16, i32 0, i32 1
  %18 = load ptr, ptr %17, align 8
  %19 = load ptr, ptr %enum_name, align 8
  %20 = call i32 @str_equals(ptr %18, ptr %19)
  %21 = icmp eq i32 %20, 1
  store i1 %21, ptr %sc.106, align 1
  br label %label_2223

label_2226:                                       ; preds = %label_2229, %label_2223
  %22 = load ptr, ptr %stmt, align 8
  %23 = getelementptr inbounds nuw %ASTNode, ptr %22, i32 0, i32 8
  %24 = load ptr, ptr %23, align 8
  store ptr %24, ptr %stmt_ptr, align 8
  br label %label_2219

label_2224:                                       ; preds = %label_2223
  %25 = load ptr, ptr %stmt, align 8
  %26 = getelementptr inbounds nuw %ASTNode, ptr %25, i32 0, i32 5
  %27 = load ptr, ptr %26, align 8
  store ptr %27, ptr %variant_ptr, align 8
  br label %label_2227

label_2227:                                       ; preds = %label_2232, %label_2224
  %28 = load ptr, ptr %variant_ptr, align 8
  %29 = call i32 @str_equals(ptr %28, ptr @.str.s851)
  %30 = icmp eq i32 %29, 0
  br i1 %30, label %label_2228, label %label_2229

label_2229:                                       ; preds = %label_2227
  br label %label_2226

label_2228:                                       ; preds = %label_2227
  %31 = load ptr, ptr %variant_ptr, align 8
  %32 = call ptr @ptr_to_node(ptr %31)
  store ptr %32, ptr %variant, align 8
  %33 = load ptr, ptr %variant, align 8
  %34 = getelementptr inbounds nuw %ASTNode, ptr %33, i32 0, i32 1
  %35 = load ptr, ptr %34, align 8
  %36 = load ptr, ptr %variant_name, align 8
  %37 = call i32 @str_equals(ptr %35, ptr %36)
  %38 = icmp eq i32 %37, 1
  br i1 %38, label %label_2230, label %label_2232

label_2232:                                       ; preds = %label_2228
  %39 = load ptr, ptr %variant, align 8
  %40 = getelementptr inbounds nuw %ASTNode, ptr %39, i32 0, i32 8
  %41 = load ptr, ptr %40, align 8
  store ptr %41, ptr %variant_ptr, align 8
  br label %label_2227

label_2230:                                       ; preds = %label_2228
  ret i1 true
}

define ptr @sema_builtin_call_type__String_String(ptr %0, ptr %1) {
entry:
  %name = alloca ptr, align 8
  store ptr %0, ptr %name, align 8
  %arg_ptr = alloca ptr, align 8
  store ptr %1, ptr %arg_ptr, align 8
  %lt = alloca ptr, align 8
  %sc.107 = alloca i1, align 1
  %2 = load ptr, ptr %name, align 8
  %3 = call i32 @str_equals(ptr %2, ptr @.str.s852)
  %4 = icmp eq i32 %3, 1
  store i1 %4, ptr %sc.107, align 1
  br i1 %4, label %label_2234, label %label_2233

label_2233:                                       ; preds = %entry
  %5 = load ptr, ptr %name, align 8
  %6 = call i32 @str_equals(ptr %5, ptr @.str.s853)
  %7 = icmp eq i32 %6, 1
  store i1 %7, ptr %sc.107, align 1
  br label %label_2234

label_2234:                                       ; preds = %label_2233, %entry
  %8 = load i1, ptr %sc.107, align 1
  br i1 %8, label %label_2235, label %label_2237

label_2237:                                       ; preds = %label_2234
  %sc.108 = alloca i1, align 1
  %9 = load ptr, ptr %name, align 8
  %10 = call i32 @str_equals(ptr %9, ptr @.str.s856)
  %11 = icmp eq i32 %10, 1
  store i1 %11, ptr %sc.108, align 1
  br i1 %11, label %label_2242, label %label_2241

label_2235:                                       ; preds = %label_2234
  %12 = load ptr, ptr %arg_ptr, align 8
  %13 = call i32 @str_equals(ptr %12, ptr @.str.s854)
  %14 = icmp eq i32 %13, 1
  br i1 %14, label %label_2238, label %label_2240

label_2240:                                       ; preds = %label_2238, %label_2235
  %15 = call ptr @type_void__Void()
  ret ptr %15

label_2238:                                       ; preds = %label_2235
  %16 = load ptr, ptr %name, align 8
  %17 = call ptr @str_concat(ptr %16, ptr @.str.s855)
  call void @sema_error__String(ptr %17)
  br label %label_2240

label_2241:                                       ; preds = %label_2237
  %18 = load ptr, ptr %name, align 8
  %19 = call i32 @str_equals(ptr %18, ptr @.str.s857)
  %20 = icmp eq i32 %19, 1
  store i1 %20, ptr %sc.108, align 1
  br label %label_2242

label_2242:                                       ; preds = %label_2241, %label_2237
  %21 = load i1, ptr %sc.108, align 1
  br i1 %21, label %label_2243, label %label_2245

label_2245:                                       ; preds = %label_2242
  %sc.109 = alloca i1, align 1
  %22 = load ptr, ptr %name, align 8
  %23 = call i32 @str_equals(ptr %22, ptr @.str.s858)
  %24 = icmp eq i32 %23, 1
  store i1 %24, ptr %sc.109, align 1
  br i1 %24, label %label_2247, label %label_2246

label_2243:                                       ; preds = %label_2242
  %25 = call ptr @type_void__Void()
  ret ptr %25

label_2246:                                       ; preds = %label_2245
  %26 = load ptr, ptr %name, align 8
  %27 = call i32 @str_equals(ptr %26, ptr @.str.s859)
  %28 = icmp eq i32 %27, 1
  store i1 %28, ptr %sc.109, align 1
  br label %label_2247

label_2247:                                       ; preds = %label_2246, %label_2245
  %29 = load i1, ptr %sc.109, align 1
  br i1 %29, label %label_2248, label %label_2250

label_2250:                                       ; preds = %label_2247
  %sc.110 = alloca i1, align 1
  %30 = load ptr, ptr %name, align 8
  %31 = call i32 @str_equals(ptr %30, ptr @.str.s860)
  %32 = icmp eq i32 %31, 1
  store i1 %32, ptr %sc.110, align 1
  br i1 %32, label %label_2252, label %label_2251

label_2248:                                       ; preds = %label_2247
  %33 = call ptr @type_void__Void()
  ret ptr %33

label_2251:                                       ; preds = %label_2250
  %34 = load ptr, ptr %name, align 8
  %35 = call i32 @str_equals(ptr %34, ptr @.str.s861)
  %36 = icmp eq i32 %35, 1
  store i1 %36, ptr %sc.110, align 1
  br label %label_2252

label_2252:                                       ; preds = %label_2251, %label_2250
  %37 = load i1, ptr %sc.110, align 1
  br i1 %37, label %label_2253, label %label_2255

label_2255:                                       ; preds = %label_2252
  %sc.111 = alloca i1, align 1
  %38 = load ptr, ptr %name, align 8
  %39 = call i32 @str_equals(ptr %38, ptr @.str.s862)
  %40 = icmp eq i32 %39, 1
  store i1 %40, ptr %sc.111, align 1
  br i1 %40, label %label_2257, label %label_2256

label_2253:                                       ; preds = %label_2252
  %41 = call ptr @type_void__Void()
  ret ptr %41

label_2256:                                       ; preds = %label_2255
  %42 = load ptr, ptr %name, align 8
  %43 = call i32 @str_equals(ptr %42, ptr @.str.s863)
  %44 = icmp eq i32 %43, 1
  store i1 %44, ptr %sc.111, align 1
  br label %label_2257

label_2257:                                       ; preds = %label_2256, %label_2255
  %45 = load i1, ptr %sc.111, align 1
  br i1 %45, label %label_2258, label %label_2260

label_2260:                                       ; preds = %label_2257
  %46 = load ptr, ptr %name, align 8
  %47 = call i32 @str_equals(ptr %46, ptr @.str.s864)
  %48 = icmp eq i32 %47, 1
  br i1 %48, label %label_2261, label %label_2263

label_2258:                                       ; preds = %label_2257
  %49 = call ptr @type_void__Void()
  ret ptr %49

label_2263:                                       ; preds = %label_2260
  %50 = load ptr, ptr %name, align 8
  %51 = call i32 @str_equals(ptr %50, ptr @.str.s865)
  %52 = icmp eq i32 %51, 1
  br i1 %52, label %label_2264, label %label_2266

label_2261:                                       ; preds = %label_2260
  %53 = call ptr @type_void__Void()
  ret ptr %53

label_2266:                                       ; preds = %label_2263
  %54 = load ptr, ptr %name, align 8
  %55 = call i32 @str_equals(ptr %54, ptr @.str.s866)
  %56 = icmp eq i32 %55, 1
  br i1 %56, label %label_2267, label %label_2269

label_2264:                                       ; preds = %label_2263
  %57 = call ptr @type_invalid__Void()
  %58 = call ptr @type_list__Struct_TypeInfo(ptr %57)
  ret ptr %58

label_2269:                                       ; preds = %label_2266
  %59 = load ptr, ptr %name, align 8
  %60 = call i32 @str_equals(ptr %59, ptr @.str.s867)
  %61 = icmp eq i32 %60, 1
  br i1 %61, label %label_2270, label %label_2272

label_2267:                                       ; preds = %label_2266
  %62 = call ptr @type_int__Void()
  ret ptr %62

label_2272:                                       ; preds = %label_2269
  %63 = load ptr, ptr %name, align 8
  %64 = call i32 @str_equals(ptr %63, ptr @.str.s868)
  %65 = icmp eq i32 %64, 1
  br i1 %65, label %label_2273, label %label_2275

label_2270:                                       ; preds = %label_2269
  %66 = call ptr @type_void__Void()
  ret ptr %66

label_2275:                                       ; preds = %label_2272
  %67 = load ptr, ptr %name, align 8
  %68 = call i32 @str_equals(ptr %67, ptr @.str.s869)
  %69 = icmp eq i32 %68, 1
  br i1 %69, label %label_2276, label %label_2278

label_2273:                                       ; preds = %label_2272
  %70 = call ptr @type_void__Void()
  ret ptr %70

label_2278:                                       ; preds = %label_2275
  %71 = call ptr @type_invalid__Void()
  ret ptr %71

label_2276:                                       ; preds = %label_2275
  %72 = load ptr, ptr %arg_ptr, align 8
  %73 = call i32 @str_equals(ptr %72, ptr @.str.s870)
  %74 = icmp eq i32 %73, 0
  br i1 %74, label %label_2279, label %label_2281

label_2281:                                       ; preds = %label_2286, %label_2276
  %75 = call ptr @type_invalid__Void()
  ret ptr %75

label_2279:                                       ; preds = %label_2276
  %76 = load ptr, ptr %arg_ptr, align 8
  %77 = call ptr @ptr_to_node(ptr %76)
  %78 = call ptr @node_get_type__Struct_ASTNode(ptr %77)
  store ptr %78, ptr %lt, align 8
  %sc.112 = alloca i1, align 1
  %79 = load ptr, ptr %lt, align 8
  %80 = getelementptr inbounds nuw %TypeInfo, ptr %79, i32 0, i32 0
  %81 = load i32, ptr %80, align 4
  %82 = icmp eq i32 %81, 11
  store i1 %82, ptr %sc.112, align 1
  br i1 %82, label %label_2282, label %label_2283

label_2283:                                       ; preds = %label_2282, %label_2279
  %83 = load i1, ptr %sc.112, align 1
  br i1 %83, label %label_2284, label %label_2286

label_2282:                                       ; preds = %label_2279
  %84 = load ptr, ptr %lt, align 8
  %85 = getelementptr inbounds nuw %TypeInfo, ptr %84, i32 0, i32 3
  %86 = load ptr, ptr %85, align 8
  %87 = call i32 @str_equals(ptr %86, ptr @.str.s871)
  %88 = icmp eq i32 %87, 0
  store i1 %88, ptr %sc.112, align 1
  br label %label_2283

label_2286:                                       ; preds = %label_2283
  br label %label_2281

label_2284:                                       ; preds = %label_2283
  %89 = load ptr, ptr %lt, align 8
  %90 = getelementptr inbounds nuw %TypeInfo, ptr %89, i32 0, i32 3
  %91 = load ptr, ptr %90, align 8
  %92 = call ptr @ptr_to_type(ptr %91)
  ret ptr %92
}

define i1 @sema_check_builtin_call__Struct_ASTNode_String_String(ptr %0, ptr %1, ptr %2) {
entry:
  %module = alloca ptr, align 8
  store ptr %0, ptr %module, align 8
  %name = alloca ptr, align 8
  store ptr %1, ptr %name, align 8
  %arg_ptr = alloca ptr, align 8
  store ptr %2, ptr %arg_ptr, align 8
  %arg = alloca ptr, align 8
  %t = alloca ptr, align 8
  %lt = alloca ptr, align 8
  %a0 = alloca ptr, align 8
  %a1 = alloca ptr, align 8
  %expected = alloca ptr, align 8
  %actual = alloca ptr, align 8
  %sc.113 = alloca i1, align 1
  %3 = load ptr, ptr %name, align 8
  %4 = call i32 @str_equals(ptr %3, ptr @.str.s872)
  %5 = icmp eq i32 %4, 1
  store i1 %5, ptr %sc.113, align 1
  br i1 %5, label %label_2288, label %label_2287

label_2287:                                       ; preds = %entry
  %6 = load ptr, ptr %name, align 8
  %7 = call i32 @str_equals(ptr %6, ptr @.str.s873)
  %8 = icmp eq i32 %7, 1
  store i1 %8, ptr %sc.113, align 1
  br label %label_2288

label_2288:                                       ; preds = %label_2287, %entry
  %9 = load i1, ptr %sc.113, align 1
  br i1 %9, label %label_2289, label %label_2291

label_2291:                                       ; preds = %label_2288
  %10 = load ptr, ptr %name, align 8
  %11 = call i32 @str_equals(ptr %10, ptr @.str.s877)
  %12 = icmp eq i32 %11, 1
  br i1 %12, label %label_2297, label %label_2299

label_2289:                                       ; preds = %label_2288
  %sc.114 = alloca i1, align 1
  %13 = load ptr, ptr %arg_ptr, align 8
  %14 = call i32 @str_equals(ptr %13, ptr @.str.s874)
  %15 = icmp eq i32 %14, 1
  store i1 %15, ptr %sc.114, align 1
  br i1 %15, label %label_2293, label %label_2292

label_2292:                                       ; preds = %label_2289
  %16 = load ptr, ptr %arg_ptr, align 8
  %17 = call ptr @ptr_to_node(ptr %16)
  %18 = getelementptr inbounds nuw %ASTNode, ptr %17, i32 0, i32 8
  %19 = load ptr, ptr %18, align 8
  %20 = call i32 @str_equals(ptr %19, ptr @.str.s875)
  %21 = icmp eq i32 %20, 0
  store i1 %21, ptr %sc.114, align 1
  br label %label_2293

label_2293:                                       ; preds = %label_2292, %label_2289
  %22 = load i1, ptr %sc.114, align 1
  br i1 %22, label %label_2294, label %label_2296

label_2296:                                       ; preds = %label_2294, %label_2293
  %23 = load ptr, ptr %module, align 8
  %24 = load ptr, ptr %arg_ptr, align 8
  %25 = call ptr @ptr_to_node(ptr %24)
  %26 = call ptr @sema_expr__Struct_ASTNode_Struct_ASTNode(ptr %23, ptr %25)
  ret i1 true

label_2294:                                       ; preds = %label_2293
  %27 = load ptr, ptr %name, align 8
  %28 = call ptr @str_concat(ptr %27, ptr @.str.s876)
  call void @sema_error__String(ptr %28)
  br label %label_2296

label_2299:                                       ; preds = %label_2291
  %29 = load ptr, ptr %name, align 8
  %30 = call i32 @str_equals(ptr %29, ptr @.str.s882)
  %31 = icmp eq i32 %30, 1
  br i1 %31, label %label_2308, label %label_2310

label_2297:                                       ; preds = %label_2291
  %sc.115 = alloca i1, align 1
  %32 = load ptr, ptr %arg_ptr, align 8
  %33 = call i32 @str_equals(ptr %32, ptr @.str.s878)
  %34 = icmp eq i32 %33, 1
  store i1 %34, ptr %sc.115, align 1
  br i1 %34, label %label_2301, label %label_2300

label_2300:                                       ; preds = %label_2297
  %35 = load ptr, ptr %arg_ptr, align 8
  %36 = call ptr @ptr_to_node(ptr %35)
  %37 = getelementptr inbounds nuw %ASTNode, ptr %36, i32 0, i32 8
  %38 = load ptr, ptr %37, align 8
  %39 = call i32 @str_equals(ptr %38, ptr @.str.s879)
  %40 = icmp eq i32 %39, 0
  store i1 %40, ptr %sc.115, align 1
  br label %label_2301

label_2301:                                       ; preds = %label_2300, %label_2297
  %41 = load i1, ptr %sc.115, align 1
  br i1 %41, label %label_2302, label %label_2304

label_2304:                                       ; preds = %label_2302, %label_2301
  %42 = load ptr, ptr %arg_ptr, align 8
  %43 = call ptr @ptr_to_node(ptr %42)
  store ptr %43, ptr %arg, align 8
  %44 = load ptr, ptr %module, align 8
  %45 = load ptr, ptr %arg, align 8
  %46 = call ptr @sema_expr__Struct_ASTNode_Struct_ASTNode(ptr %44, ptr %45)
  store ptr %46, ptr %t, align 8
  %47 = load ptr, ptr %t, align 8
  %48 = call i1 @type_is_move_only__Struct_TypeInfo(ptr %47)
  %49 = icmp eq i1 %48, false
  br i1 %49, label %label_2305, label %label_2307

label_2302:                                       ; preds = %label_2301
  call void @sema_error__String(ptr @.str.s880)
  br label %label_2304

label_2307:                                       ; preds = %label_2305, %label_2304
  %50 = load ptr, ptr %arg, align 8
  call void @sema_move_operand__Struct_ASTNode(ptr %50)
  ret i1 true

label_2305:                                       ; preds = %label_2304
  call void @sema_error__String(ptr @.str.s881)
  br label %label_2307

label_2310:                                       ; preds = %label_2299
  %51 = load ptr, ptr %name, align 8
  %52 = call i32 @str_equals(ptr %51, ptr @.str.s885)
  %53 = icmp eq i32 %52, 1
  br i1 %53, label %label_2314, label %label_2316

label_2308:                                       ; preds = %label_2299
  %54 = load ptr, ptr %arg_ptr, align 8
  %55 = call i32 @str_equals(ptr %54, ptr @.str.s883)
  %56 = icmp eq i32 %55, 0
  br i1 %56, label %label_2311, label %label_2313

label_2313:                                       ; preds = %label_2311, %label_2308
  ret i1 true

label_2311:                                       ; preds = %label_2308
  call void @sema_error__String(ptr @.str.s884)
  br label %label_2313

label_2316:                                       ; preds = %label_2310
  %57 = load ptr, ptr %name, align 8
  %58 = call i32 @str_equals(ptr %57, ptr @.str.s889)
  %59 = icmp eq i32 %58, 1
  br i1 %59, label %label_2323, label %label_2325

label_2314:                                       ; preds = %label_2310
  %60 = load ptr, ptr %arg_ptr, align 8
  %61 = call i32 @str_equals(ptr %60, ptr @.str.s886)
  %62 = icmp eq i32 %61, 1
  br i1 %62, label %label_2317, label %label_2319

label_2319:                                       ; preds = %label_2317, %label_2314
  %63 = load ptr, ptr %module, align 8
  %64 = load ptr, ptr %arg_ptr, align 8
  %65 = call ptr @ptr_to_node(ptr %64)
  %66 = call ptr @sema_expr__Struct_ASTNode_Struct_ASTNode(ptr %63, ptr %65)
  store ptr %66, ptr %lt, align 8
  %67 = load ptr, ptr %lt, align 8
  %68 = getelementptr inbounds nuw %TypeInfo, ptr %67, i32 0, i32 0
  %69 = load i32, ptr %68, align 4
  %70 = icmp ne i32 %69, 11
  br i1 %70, label %label_2320, label %label_2322

label_2317:                                       ; preds = %label_2314
  call void @sema_error__String(ptr @.str.s887)
  br label %label_2319

label_2322:                                       ; preds = %label_2320, %label_2319
  ret i1 true

label_2320:                                       ; preds = %label_2319
  call void @sema_error__String(ptr @.str.s888)
  br label %label_2322

label_2325:                                       ; preds = %label_2316
  %71 = load ptr, ptr %name, align 8
  %72 = call i32 @str_equals(ptr %71, ptr @.str.s892)
  %73 = icmp eq i32 %72, 1
  br i1 %73, label %label_2329, label %label_2331

label_2323:                                       ; preds = %label_2316
  %74 = load ptr, ptr %arg_ptr, align 8
  %75 = call ptr @ptr_to_node(ptr %74)
  store ptr %75, ptr %a0, align 8
  %76 = load ptr, ptr %module, align 8
  %77 = load ptr, ptr %a0, align 8
  %78 = call ptr @sema_expr__Struct_ASTNode_Struct_ASTNode(ptr %76, ptr %77)
  store ptr %78, ptr %lt, align 8
  %79 = load ptr, ptr %lt, align 8
  %80 = getelementptr inbounds nuw %TypeInfo, ptr %79, i32 0, i32 0
  %81 = load i32, ptr %80, align 4
  %82 = icmp ne i32 %81, 11
  br i1 %82, label %label_2326, label %label_2328

label_2328:                                       ; preds = %label_2326, %label_2323
  %83 = load ptr, ptr %module, align 8
  %84 = load ptr, ptr %a0, align 8
  %85 = getelementptr inbounds nuw %ASTNode, ptr %84, i32 0, i32 8
  %86 = load ptr, ptr %85, align 8
  %87 = call ptr @ptr_to_node(ptr %86)
  %88 = call ptr @type_int__Void()
  %89 = call ptr @sema_check_value__Struct_ASTNode_Struct_ASTNode_Struct_TypeInfo_String(ptr %83, ptr %87, ptr %88, ptr @.str.s891)
  ret i1 true

label_2326:                                       ; preds = %label_2323
  call void @sema_error__String(ptr @.str.s890)
  br label %label_2328

label_2331:                                       ; preds = %label_2325
  %90 = load ptr, ptr %name, align 8
  %91 = call i32 @str_equals(ptr %90, ptr @.str.s895)
  %92 = icmp eq i32 %91, 1
  br i1 %92, label %label_2335, label %label_2337

label_2329:                                       ; preds = %label_2325
  %93 = load ptr, ptr %arg_ptr, align 8
  %94 = call ptr @ptr_to_node(ptr %93)
  store ptr %94, ptr %a0, align 8
  %95 = load ptr, ptr %module, align 8
  %96 = load ptr, ptr %a0, align 8
  %97 = call ptr @sema_expr__Struct_ASTNode_Struct_ASTNode(ptr %95, ptr %96)
  store ptr %97, ptr %lt, align 8
  %98 = load ptr, ptr %lt, align 8
  %99 = getelementptr inbounds nuw %TypeInfo, ptr %98, i32 0, i32 0
  %100 = load i32, ptr %99, align 4
  %101 = icmp ne i32 %100, 11
  br i1 %101, label %label_2332, label %label_2334

label_2334:                                       ; preds = %label_2332, %label_2329
  %102 = load ptr, ptr %module, align 8
  %103 = load ptr, ptr %a0, align 8
  %104 = getelementptr inbounds nuw %ASTNode, ptr %103, i32 0, i32 8
  %105 = load ptr, ptr %104, align 8
  %106 = call ptr @ptr_to_node(ptr %105)
  %107 = load ptr, ptr %lt, align 8
  %108 = getelementptr inbounds nuw %TypeInfo, ptr %107, i32 0, i32 3
  %109 = load ptr, ptr %108, align 8
  %110 = call ptr @ptr_to_type(ptr %109)
  %111 = call ptr @sema_check_value__Struct_ASTNode_Struct_ASTNode_Struct_TypeInfo_String(ptr %102, ptr %106, ptr %110, ptr @.str.s894)
  ret i1 true

label_2332:                                       ; preds = %label_2329
  call void @sema_error__String(ptr @.str.s893)
  br label %label_2334

label_2337:                                       ; preds = %label_2331
  %112 = call ptr @type_invalid__Void()
  store ptr %112, ptr %expected, align 8
  %sc.116 = alloca i1, align 1
  %113 = load ptr, ptr %name, align 8
  %114 = call i32 @str_equals(ptr %113, ptr @.str.s899)
  %115 = icmp eq i32 %114, 1
  store i1 %115, ptr %sc.116, align 1
  br i1 %115, label %label_2342, label %label_2341

label_2335:                                       ; preds = %label_2331
  %116 = load ptr, ptr %arg_ptr, align 8
  %117 = call ptr @ptr_to_node(ptr %116)
  store ptr %117, ptr %a0, align 8
  %118 = load ptr, ptr %module, align 8
  %119 = load ptr, ptr %a0, align 8
  %120 = call ptr @sema_expr__Struct_ASTNode_Struct_ASTNode(ptr %118, ptr %119)
  store ptr %120, ptr %lt, align 8
  %121 = load ptr, ptr %lt, align 8
  %122 = getelementptr inbounds nuw %TypeInfo, ptr %121, i32 0, i32 0
  %123 = load i32, ptr %122, align 4
  %124 = icmp ne i32 %123, 11
  br i1 %124, label %label_2338, label %label_2340

label_2340:                                       ; preds = %label_2338, %label_2335
  %125 = load ptr, ptr %a0, align 8
  %126 = getelementptr inbounds nuw %ASTNode, ptr %125, i32 0, i32 8
  %127 = load ptr, ptr %126, align 8
  %128 = call ptr @ptr_to_node(ptr %127)
  store ptr %128, ptr %a1, align 8
  %129 = load ptr, ptr %module, align 8
  %130 = load ptr, ptr %a1, align 8
  %131 = call ptr @type_int__Void()
  %132 = call ptr @sema_check_value__Struct_ASTNode_Struct_ASTNode_Struct_TypeInfo_String(ptr %129, ptr %130, ptr %131, ptr @.str.s897)
  %133 = load ptr, ptr %module, align 8
  %134 = load ptr, ptr %a1, align 8
  %135 = getelementptr inbounds nuw %ASTNode, ptr %134, i32 0, i32 8
  %136 = load ptr, ptr %135, align 8
  %137 = call ptr @ptr_to_node(ptr %136)
  %138 = load ptr, ptr %lt, align 8
  %139 = getelementptr inbounds nuw %TypeInfo, ptr %138, i32 0, i32 3
  %140 = load ptr, ptr %139, align 8
  %141 = call ptr @ptr_to_type(ptr %140)
  %142 = call ptr @sema_check_value__Struct_ASTNode_Struct_ASTNode_Struct_TypeInfo_String(ptr %133, ptr %137, ptr %141, ptr @.str.s898)
  ret i1 true

label_2338:                                       ; preds = %label_2335
  call void @sema_error__String(ptr @.str.s896)
  br label %label_2340

label_2341:                                       ; preds = %label_2337
  %143 = load ptr, ptr %name, align 8
  %144 = call i32 @str_equals(ptr %143, ptr @.str.s900)
  %145 = icmp eq i32 %144, 1
  store i1 %145, ptr %sc.116, align 1
  br label %label_2342

label_2342:                                       ; preds = %label_2341, %label_2337
  %146 = load i1, ptr %sc.116, align 1
  br i1 %146, label %label_2343, label %label_2345

label_2345:                                       ; preds = %label_2343, %label_2342
  %sc.117 = alloca i1, align 1
  %147 = load ptr, ptr %name, align 8
  %148 = call i32 @str_equals(ptr %147, ptr @.str.s901)
  %149 = icmp eq i32 %148, 1
  store i1 %149, ptr %sc.117, align 1
  br i1 %149, label %label_2347, label %label_2346

label_2343:                                       ; preds = %label_2342
  %150 = call ptr @type_int__Void()
  store ptr %150, ptr %expected, align 8
  br label %label_2345

label_2346:                                       ; preds = %label_2345
  %151 = load ptr, ptr %name, align 8
  %152 = call i32 @str_equals(ptr %151, ptr @.str.s902)
  %153 = icmp eq i32 %152, 1
  store i1 %153, ptr %sc.117, align 1
  br label %label_2347

label_2347:                                       ; preds = %label_2346, %label_2345
  %154 = load i1, ptr %sc.117, align 1
  br i1 %154, label %label_2348, label %label_2350

label_2350:                                       ; preds = %label_2348, %label_2347
  %sc.118 = alloca i1, align 1
  %155 = load ptr, ptr %name, align 8
  %156 = call i32 @str_equals(ptr %155, ptr @.str.s903)
  %157 = icmp eq i32 %156, 1
  store i1 %157, ptr %sc.118, align 1
  br i1 %157, label %label_2352, label %label_2351

label_2348:                                       ; preds = %label_2347
  %158 = call ptr @type_float__Void()
  store ptr %158, ptr %expected, align 8
  br label %label_2350

label_2351:                                       ; preds = %label_2350
  %159 = load ptr, ptr %name, align 8
  %160 = call i32 @str_equals(ptr %159, ptr @.str.s904)
  %161 = icmp eq i32 %160, 1
  store i1 %161, ptr %sc.118, align 1
  br label %label_2352

label_2352:                                       ; preds = %label_2351, %label_2350
  %162 = load i1, ptr %sc.118, align 1
  br i1 %162, label %label_2353, label %label_2355

label_2355:                                       ; preds = %label_2353, %label_2352
  %sc.119 = alloca i1, align 1
  %163 = load ptr, ptr %name, align 8
  %164 = call i32 @str_equals(ptr %163, ptr @.str.s905)
  %165 = icmp eq i32 %164, 1
  store i1 %165, ptr %sc.119, align 1
  br i1 %165, label %label_2357, label %label_2356

label_2353:                                       ; preds = %label_2352
  %166 = call ptr @type_bool__Void()
  store ptr %166, ptr %expected, align 8
  br label %label_2355

label_2356:                                       ; preds = %label_2355
  %167 = load ptr, ptr %name, align 8
  %168 = call i32 @str_equals(ptr %167, ptr @.str.s906)
  %169 = icmp eq i32 %168, 1
  store i1 %169, ptr %sc.119, align 1
  br label %label_2357

label_2357:                                       ; preds = %label_2356, %label_2355
  %170 = load i1, ptr %sc.119, align 1
  br i1 %170, label %label_2358, label %label_2360

label_2360:                                       ; preds = %label_2358, %label_2357
  %171 = load ptr, ptr %expected, align 8
  %172 = call i1 @type_is_valid__Struct_TypeInfo(ptr %171)
  br i1 %172, label %label_2361, label %label_2363

label_2358:                                       ; preds = %label_2357
  %173 = call ptr @type_char__Void()
  store ptr %173, ptr %expected, align 8
  br label %label_2360

label_2363:                                       ; preds = %label_2360
  ret i1 false

label_2361:                                       ; preds = %label_2360
  %sc.120 = alloca i1, align 1
  %174 = load ptr, ptr %arg_ptr, align 8
  %175 = call i32 @str_equals(ptr %174, ptr @.str.s907)
  %176 = icmp eq i32 %175, 1
  store i1 %176, ptr %sc.120, align 1
  br i1 %176, label %label_2365, label %label_2364

label_2364:                                       ; preds = %label_2361
  %177 = load ptr, ptr %arg_ptr, align 8
  %178 = call ptr @ptr_to_node(ptr %177)
  %179 = getelementptr inbounds nuw %ASTNode, ptr %178, i32 0, i32 8
  %180 = load ptr, ptr %179, align 8
  %181 = call i32 @str_equals(ptr %180, ptr @.str.s908)
  %182 = icmp eq i32 %181, 0
  store i1 %182, ptr %sc.120, align 1
  br label %label_2365

label_2365:                                       ; preds = %label_2364, %label_2361
  %183 = load i1, ptr %sc.120, align 1
  br i1 %183, label %label_2366, label %label_2368

label_2368:                                       ; preds = %label_2366, %label_2365
  %184 = load ptr, ptr %module, align 8
  %185 = load ptr, ptr %arg_ptr, align 8
  %186 = call ptr @ptr_to_node(ptr %185)
  %187 = call ptr @sema_expr__Struct_ASTNode_Struct_ASTNode(ptr %184, ptr %186)
  store ptr %187, ptr %actual, align 8
  %188 = load ptr, ptr %name, align 8
  %189 = call ptr @str_concat(ptr %188, ptr @.str.s910)
  %190 = load ptr, ptr %expected, align 8
  %191 = load ptr, ptr %actual, align 8
  call void @sema_expect_assignable__String_Struct_TypeInfo_Struct_TypeInfo(ptr %189, ptr %190, ptr %191)
  ret i1 true

label_2366:                                       ; preds = %label_2365
  %192 = load ptr, ptr %name, align 8
  %193 = call ptr @str_concat(ptr %192, ptr @.str.s909)
  call void @sema_error__String(ptr %193)
  br label %label_2368
}

define void @sema_statement__Struct_ASTNode_Struct_ASTNode_Struct_TypeInfo(ptr %0, ptr %1, ptr %2) {
entry:
  %module = alloca ptr, align 8
  store ptr %0, ptr %module, align 8
  %stmt = alloca ptr, align 8
  store ptr %1, ptr %stmt, align 8
  %expected_return = alloca ptr, align 8
  store ptr %2, ptr %expected_return, align 8
  %var_t = alloca ptr, align 8
  %has_annotation = alloca i1, align 1
  %has_init = alloca i1, align 1
  %target = alloca ptr, align 8
  %target_t = alloca ptr, align 8
  %value_t = alloca ptr, align 8
  %cond_t = alloca ptr, align 8
  %else_node = alloca ptr, align 8
  %cond_t2 = alloca ptr, align 8
  %start_t = alloca ptr, align 8
  %end_t = alloca ptr, align 8
  %scrut_t = alloca ptr, align 8
  %pat_expected = alloca ptr, align 8
  %arm_ptr = alloca ptr, align 8
  %arm = alloca ptr, align 8
  %3 = load ptr, ptr %stmt, align 8
  %4 = getelementptr inbounds nuw %ASTNode, ptr %3, i32 0, i32 0
  %5 = load i32, ptr %4, align 4
  %6 = icmp eq i32 %5, 3
  br i1 %6, label %label_2585, label %label_2587

label_2587:                                       ; preds = %label_2599, %entry
  %7 = load ptr, ptr %stmt, align 8
  %8 = getelementptr inbounds nuw %ASTNode, ptr %7, i32 0, i32 0
  %9 = load i32, ptr %8, align 4
  %10 = icmp eq i32 %9, 16
  br i1 %10, label %label_2600, label %label_2602

label_2585:                                       ; preds = %entry
  %11 = call ptr @type_invalid__Void()
  store ptr %11, ptr %var_t, align 8
  %12 = load ptr, ptr %stmt, align 8
  %13 = getelementptr inbounds nuw %ASTNode, ptr %12, i32 0, i32 5
  %14 = load ptr, ptr %13, align 8
  %15 = call i32 @str_equals(ptr %14, ptr @.str.s968)
  %16 = icmp eq i32 %15, 0
  store i1 %16, ptr %has_annotation, align 1
  %17 = load ptr, ptr %stmt, align 8
  %18 = getelementptr inbounds nuw %ASTNode, ptr %17, i32 0, i32 6
  %19 = load ptr, ptr %18, align 8
  %20 = call i32 @str_equals(ptr %19, ptr @.str.s969)
  %21 = icmp eq i32 %20, 0
  store i1 %21, ptr %has_init, align 1
  %22 = load i1, ptr %has_annotation, align 1
  br i1 %22, label %label_2588, label %label_2590

label_2590:                                       ; preds = %label_2588, %label_2585
  %23 = load i1, ptr %has_init, align 1
  br i1 %23, label %label_2591, label %label_2593

label_2588:                                       ; preds = %label_2585
  %24 = load ptr, ptr %module, align 8
  %25 = load ptr, ptr %stmt, align 8
  %26 = getelementptr inbounds nuw %ASTNode, ptr %25, i32 0, i32 5
  %27 = load ptr, ptr %26, align 8
  %28 = call ptr @ptr_to_node(ptr %27)
  %29 = call ptr @sema_annotation_type__Struct_ASTNode_Struct_ASTNode(ptr %24, ptr %28)
  store ptr %29, ptr %var_t, align 8
  br label %label_2590

label_2593:                                       ; preds = %label_2596, %label_2590
  %30 = load ptr, ptr %var_t, align 8
  %31 = call i1 @type_is_valid__Struct_TypeInfo(ptr %30)
  %32 = icmp eq i1 %31, false
  br i1 %32, label %label_2597, label %label_2599

label_2591:                                       ; preds = %label_2590
  %33 = load i1, ptr %has_annotation, align 1
  br i1 %33, label %label_2594, label %label_2595

label_2595:                                       ; preds = %label_2591
  %34 = load ptr, ptr %module, align 8
  %35 = load ptr, ptr %stmt, align 8
  %36 = getelementptr inbounds nuw %ASTNode, ptr %35, i32 0, i32 6
  %37 = load ptr, ptr %36, align 8
  %38 = call ptr @ptr_to_node(ptr %37)
  %39 = call ptr @sema_expr__Struct_ASTNode_Struct_ASTNode(ptr %34, ptr %38)
  store ptr %39, ptr %var_t, align 8
  br label %label_2596

label_2594:                                       ; preds = %label_2591
  %40 = load ptr, ptr %module, align 8
  %41 = load ptr, ptr %stmt, align 8
  %42 = getelementptr inbounds nuw %ASTNode, ptr %41, i32 0, i32 6
  %43 = load ptr, ptr %42, align 8
  %44 = call ptr @ptr_to_node(ptr %43)
  %45 = load ptr, ptr %var_t, align 8
  %46 = load ptr, ptr %stmt, align 8
  %47 = getelementptr inbounds nuw %ASTNode, ptr %46, i32 0, i32 1
  %48 = load ptr, ptr %47, align 8
  %49 = call ptr @str_concat(ptr @.str.s970, ptr %48)
  %50 = call ptr @sema_check_value__Struct_ASTNode_Struct_ASTNode_Struct_TypeInfo_String(ptr %40, ptr %44, ptr %45, ptr %49)
  br label %label_2596

label_2596:                                       ; preds = %label_2595, %label_2594
  %51 = load ptr, ptr %stmt, align 8
  %52 = getelementptr inbounds nuw %ASTNode, ptr %51, i32 0, i32 6
  %53 = load ptr, ptr %52, align 8
  %54 = call ptr @ptr_to_node(ptr %53)
  call void @sema_move_operand__Struct_ASTNode(ptr %54)
  br label %label_2593

label_2599:                                       ; preds = %label_2597, %label_2593
  %55 = load ptr, ptr %stmt, align 8
  %56 = getelementptr inbounds nuw %ASTNode, ptr %55, i32 0, i32 1
  %57 = load ptr, ptr %56, align 8
  call void @ir_unmark_moved(ptr %57)
  %58 = load ptr, ptr %stmt, align 8
  %59 = getelementptr inbounds nuw %ASTNode, ptr %58, i32 0, i32 1
  %60 = load ptr, ptr %59, align 8
  %61 = load ptr, ptr %var_t, align 8
  %62 = call ptr @type_sem_key__Struct_TypeInfo(ptr %61)
  call void @ir_set_var_type(ptr %60, ptr %62)
  %63 = load ptr, ptr %stmt, align 8
  %64 = load ptr, ptr %var_t, align 8
  call void @node_set_type__Struct_ASTNode_Struct_TypeInfo(ptr %63, ptr %64)
  br label %label_2587

label_2597:                                       ; preds = %label_2593
  %65 = load ptr, ptr %stmt, align 8
  %66 = getelementptr inbounds nuw %ASTNode, ptr %65, i32 0, i32 1
  %67 = load ptr, ptr %66, align 8
  %68 = call ptr @str_concat(ptr @.str.s971, ptr %67)
  call void @sema_error__String(ptr %68)
  br label %label_2599

label_2602:                                       ; preds = %label_2600, %label_2587
  %69 = load ptr, ptr %stmt, align 8
  %70 = getelementptr inbounds nuw %ASTNode, ptr %69, i32 0, i32 0
  %71 = load i32, ptr %70, align 4
  %72 = icmp eq i32 %71, 15
  br i1 %72, label %label_2603, label %label_2605

label_2600:                                       ; preds = %label_2587
  %73 = load ptr, ptr %stmt, align 8
  %74 = getelementptr inbounds nuw %ASTNode, ptr %73, i32 0, i32 5
  %75 = load ptr, ptr %74, align 8
  %76 = call ptr @ptr_to_node(ptr %75)
  store ptr %76, ptr %target, align 8
  %77 = load ptr, ptr %module, align 8
  %78 = load ptr, ptr %target, align 8
  %79 = call ptr @sema_expr__Struct_ASTNode_Struct_ASTNode(ptr %77, ptr %78)
  store ptr %79, ptr %target_t, align 8
  %80 = load ptr, ptr %module, align 8
  %81 = load ptr, ptr %stmt, align 8
  %82 = getelementptr inbounds nuw %ASTNode, ptr %81, i32 0, i32 6
  %83 = load ptr, ptr %82, align 8
  %84 = call ptr @ptr_to_node(ptr %83)
  %85 = call ptr @sema_expr__Struct_ASTNode_Struct_ASTNode(ptr %80, ptr %84)
  store ptr %85, ptr %value_t, align 8
  %86 = load ptr, ptr %target_t, align 8
  %87 = load ptr, ptr %value_t, align 8
  call void @sema_expect_assignable__String_Struct_TypeInfo_Struct_TypeInfo(ptr @.str.s972, ptr %86, ptr %87)
  %88 = load ptr, ptr %stmt, align 8
  %89 = getelementptr inbounds nuw %ASTNode, ptr %88, i32 0, i32 6
  %90 = load ptr, ptr %89, align 8
  %91 = call ptr @ptr_to_node(ptr %90)
  call void @sema_move_operand__Struct_ASTNode(ptr %91)
  br label %label_2602

label_2605:                                       ; preds = %label_2608, %label_2602
  %92 = load ptr, ptr %stmt, align 8
  %93 = getelementptr inbounds nuw %ASTNode, ptr %92, i32 0, i32 0
  %94 = load i32, ptr %93, align 4
  %95 = icmp eq i32 %94, 17
  br i1 %95, label %label_2609, label %label_2611

label_2603:                                       ; preds = %label_2602
  %96 = load ptr, ptr %stmt, align 8
  %97 = getelementptr inbounds nuw %ASTNode, ptr %96, i32 0, i32 5
  %98 = load ptr, ptr %97, align 8
  %99 = call i32 @str_equals(ptr %98, ptr @.str.s973)
  %100 = icmp eq i32 %99, 0
  br i1 %100, label %label_2606, label %label_2607

label_2607:                                       ; preds = %label_2603
  %101 = load ptr, ptr %expected_return, align 8
  %102 = call ptr @type_void__Void()
  call void @sema_expect_assignable__String_Struct_TypeInfo_Struct_TypeInfo(ptr @.str.s975, ptr %101, ptr %102)
  br label %label_2608

label_2606:                                       ; preds = %label_2603
  %103 = load ptr, ptr %module, align 8
  %104 = load ptr, ptr %stmt, align 8
  %105 = getelementptr inbounds nuw %ASTNode, ptr %104, i32 0, i32 5
  %106 = load ptr, ptr %105, align 8
  %107 = call ptr @ptr_to_node(ptr %106)
  %108 = load ptr, ptr %expected_return, align 8
  %109 = call ptr @sema_check_value__Struct_ASTNode_Struct_ASTNode_Struct_TypeInfo_String(ptr %103, ptr %107, ptr %108, ptr @.str.s974)
  br label %label_2608

label_2608:                                       ; preds = %label_2607, %label_2606
  br label %label_2605

label_2611:                                       ; preds = %label_2614, %label_2605
  %110 = load ptr, ptr %stmt, align 8
  %111 = getelementptr inbounds nuw %ASTNode, ptr %110, i32 0, i32 0
  %112 = load i32, ptr %111, align 4
  %113 = icmp eq i32 %112, 10
  br i1 %113, label %label_2615, label %label_2617

label_2609:                                       ; preds = %label_2605
  %114 = load ptr, ptr %stmt, align 8
  %115 = getelementptr inbounds nuw %ASTNode, ptr %114, i32 0, i32 5
  %116 = load ptr, ptr %115, align 8
  %117 = call i32 @str_equals(ptr %116, ptr @.str.s976)
  %118 = icmp eq i32 %117, 0
  br i1 %118, label %label_2612, label %label_2614

label_2614:                                       ; preds = %label_2612, %label_2609
  br label %label_2611

label_2612:                                       ; preds = %label_2609
  %119 = load ptr, ptr %module, align 8
  %120 = load ptr, ptr %stmt, align 8
  %121 = getelementptr inbounds nuw %ASTNode, ptr %120, i32 0, i32 5
  %122 = load ptr, ptr %121, align 8
  %123 = call ptr @ptr_to_node(ptr %122)
  %124 = call ptr @sema_expr__Struct_ASTNode_Struct_ASTNode(ptr %119, ptr %123)
  br label %label_2614

label_2617:                                       ; preds = %label_2620, %label_2611
  %125 = load ptr, ptr %stmt, align 8
  %126 = getelementptr inbounds nuw %ASTNode, ptr %125, i32 0, i32 0
  %127 = load i32, ptr %126, align 4
  %128 = icmp eq i32 %127, 13
  br i1 %128, label %label_2624, label %label_2626

label_2615:                                       ; preds = %label_2611
  %129 = load ptr, ptr %module, align 8
  %130 = load ptr, ptr %stmt, align 8
  %131 = getelementptr inbounds nuw %ASTNode, ptr %130, i32 0, i32 5
  %132 = load ptr, ptr %131, align 8
  %133 = call ptr @ptr_to_node(ptr %132)
  %134 = call ptr @sema_expr__Struct_ASTNode_Struct_ASTNode(ptr %129, ptr %133)
  store ptr %134, ptr %cond_t, align 8
  %135 = call ptr @type_bool__Void()
  %136 = load ptr, ptr %cond_t, align 8
  call void @sema_expect_assignable__String_Struct_TypeInfo_Struct_TypeInfo(ptr @.str.s977, ptr %135, ptr %136)
  %137 = load ptr, ptr %module, align 8
  %138 = load ptr, ptr %stmt, align 8
  %139 = getelementptr inbounds nuw %ASTNode, ptr %138, i32 0, i32 6
  %140 = load ptr, ptr %139, align 8
  %141 = call ptr @ptr_to_node(ptr %140)
  %142 = load ptr, ptr %expected_return, align 8
  call void @sema_block__Struct_ASTNode_Struct_ASTNode_Struct_TypeInfo(ptr %137, ptr %141, ptr %142)
  %143 = load ptr, ptr %stmt, align 8
  %144 = getelementptr inbounds nuw %ASTNode, ptr %143, i32 0, i32 7
  %145 = load ptr, ptr %144, align 8
  %146 = call i32 @str_equals(ptr %145, ptr @.str.s978)
  %147 = icmp eq i32 %146, 0
  br i1 %147, label %label_2618, label %label_2620

label_2620:                                       ; preds = %label_2623, %label_2615
  br label %label_2617

label_2618:                                       ; preds = %label_2615
  %148 = load ptr, ptr %stmt, align 8
  %149 = getelementptr inbounds nuw %ASTNode, ptr %148, i32 0, i32 7
  %150 = load ptr, ptr %149, align 8
  %151 = call ptr @ptr_to_node(ptr %150)
  store ptr %151, ptr %else_node, align 8
  %152 = load ptr, ptr %else_node, align 8
  %153 = getelementptr inbounds nuw %ASTNode, ptr %152, i32 0, i32 0
  %154 = load i32, ptr %153, align 4
  %155 = icmp eq i32 %154, 10
  br i1 %155, label %label_2621, label %label_2622

label_2622:                                       ; preds = %label_2618
  %156 = load ptr, ptr %module, align 8
  %157 = load ptr, ptr %else_node, align 8
  %158 = load ptr, ptr %expected_return, align 8
  call void @sema_block__Struct_ASTNode_Struct_ASTNode_Struct_TypeInfo(ptr %156, ptr %157, ptr %158)
  br label %label_2623

label_2621:                                       ; preds = %label_2618
  %159 = load ptr, ptr %module, align 8
  %160 = load ptr, ptr %else_node, align 8
  %161 = load ptr, ptr %expected_return, align 8
  call void @sema_statement__Struct_ASTNode_Struct_ASTNode_Struct_TypeInfo(ptr %159, ptr %160, ptr %161)
  br label %label_2623

label_2623:                                       ; preds = %label_2622, %label_2621
  br label %label_2620

label_2626:                                       ; preds = %label_2624, %label_2617
  %162 = load ptr, ptr %stmt, align 8
  %163 = getelementptr inbounds nuw %ASTNode, ptr %162, i32 0, i32 0
  %164 = load i32, ptr %163, align 4
  %165 = icmp eq i32 %164, 14
  br i1 %165, label %label_2627, label %label_2629

label_2624:                                       ; preds = %label_2617
  %166 = load ptr, ptr %module, align 8
  %167 = load ptr, ptr %stmt, align 8
  %168 = getelementptr inbounds nuw %ASTNode, ptr %167, i32 0, i32 5
  %169 = load ptr, ptr %168, align 8
  %170 = call ptr @ptr_to_node(ptr %169)
  %171 = call ptr @sema_expr__Struct_ASTNode_Struct_ASTNode(ptr %166, ptr %170)
  store ptr %171, ptr %cond_t2, align 8
  %172 = call ptr @type_bool__Void()
  %173 = load ptr, ptr %cond_t2, align 8
  call void @sema_expect_assignable__String_Struct_TypeInfo_Struct_TypeInfo(ptr @.str.s979, ptr %172, ptr %173)
  %174 = load ptr, ptr %module, align 8
  %175 = load ptr, ptr %stmt, align 8
  %176 = getelementptr inbounds nuw %ASTNode, ptr %175, i32 0, i32 6
  %177 = load ptr, ptr %176, align 8
  %178 = call ptr @ptr_to_node(ptr %177)
  %179 = load ptr, ptr %expected_return, align 8
  call void @sema_block__Struct_ASTNode_Struct_ASTNode_Struct_TypeInfo(ptr %174, ptr %178, ptr %179)
  br label %label_2626

label_2629:                                       ; preds = %label_2627, %label_2626
  %180 = load ptr, ptr %stmt, align 8
  %181 = getelementptr inbounds nuw %ASTNode, ptr %180, i32 0, i32 0
  %182 = load i32, ptr %181, align 4
  %183 = icmp eq i32 %182, 12
  br i1 %183, label %label_2630, label %label_2632

label_2627:                                       ; preds = %label_2626
  %184 = load ptr, ptr %module, align 8
  %185 = load ptr, ptr %stmt, align 8
  %186 = getelementptr inbounds nuw %ASTNode, ptr %185, i32 0, i32 5
  %187 = load ptr, ptr %186, align 8
  %188 = call ptr @ptr_to_node(ptr %187)
  %189 = load ptr, ptr %expected_return, align 8
  call void @sema_block__Struct_ASTNode_Struct_ASTNode_Struct_TypeInfo(ptr %184, ptr %188, ptr %189)
  br label %label_2629

label_2632:                                       ; preds = %label_2630, %label_2629
  %190 = load ptr, ptr %stmt, align 8
  %191 = getelementptr inbounds nuw %ASTNode, ptr %190, i32 0, i32 0
  %192 = load i32, ptr %191, align 4
  %193 = icmp eq i32 %192, 11
  br i1 %193, label %label_2633, label %label_2635

label_2630:                                       ; preds = %label_2629
  %194 = load ptr, ptr %module, align 8
  %195 = load ptr, ptr %stmt, align 8
  %196 = getelementptr inbounds nuw %ASTNode, ptr %195, i32 0, i32 5
  %197 = load ptr, ptr %196, align 8
  %198 = call ptr @ptr_to_node(ptr %197)
  %199 = call ptr @sema_expr__Struct_ASTNode_Struct_ASTNode(ptr %194, ptr %198)
  store ptr %199, ptr %start_t, align 8
  %200 = call ptr @type_int__Void()
  %201 = load ptr, ptr %start_t, align 8
  call void @sema_expect_assignable__String_Struct_TypeInfo_Struct_TypeInfo(ptr @.str.s980, ptr %200, ptr %201)
  %202 = load ptr, ptr %module, align 8
  %203 = load ptr, ptr %stmt, align 8
  %204 = getelementptr inbounds nuw %ASTNode, ptr %203, i32 0, i32 6
  %205 = load ptr, ptr %204, align 8
  %206 = call ptr @ptr_to_node(ptr %205)
  %207 = call ptr @sema_expr__Struct_ASTNode_Struct_ASTNode(ptr %202, ptr %206)
  store ptr %207, ptr %end_t, align 8
  %208 = call ptr @type_int__Void()
  %209 = load ptr, ptr %end_t, align 8
  call void @sema_expect_assignable__String_Struct_TypeInfo_Struct_TypeInfo(ptr @.str.s981, ptr %208, ptr %209)
  %210 = load ptr, ptr %stmt, align 8
  %211 = getelementptr inbounds nuw %ASTNode, ptr %210, i32 0, i32 1
  %212 = load ptr, ptr %211, align 8
  %213 = call ptr @type_int__Void()
  %214 = call ptr @type_sem_key__Struct_TypeInfo(ptr %213)
  call void @ir_set_var_type(ptr %212, ptr %214)
  %215 = load ptr, ptr %module, align 8
  %216 = load ptr, ptr %stmt, align 8
  %217 = getelementptr inbounds nuw %ASTNode, ptr %216, i32 0, i32 7
  %218 = load ptr, ptr %217, align 8
  %219 = call ptr @ptr_to_node(ptr %218)
  %220 = load ptr, ptr %expected_return, align 8
  call void @sema_block__Struct_ASTNode_Struct_ASTNode_Struct_TypeInfo(ptr %215, ptr %219, ptr %220)
  br label %label_2632

label_2635:                                       ; preds = %label_2646, %label_2632
  ret void

label_2633:                                       ; preds = %label_2632
  %221 = load ptr, ptr %module, align 8
  %222 = load ptr, ptr %stmt, align 8
  %223 = getelementptr inbounds nuw %ASTNode, ptr %222, i32 0, i32 5
  %224 = load ptr, ptr %223, align 8
  %225 = call ptr @ptr_to_node(ptr %224)
  %226 = call ptr @sema_expr__Struct_ASTNode_Struct_ASTNode(ptr %221, ptr %225)
  store ptr %226, ptr %scrut_t, align 8
  %sc.151 = alloca i1, align 1
  %227 = load ptr, ptr %scrut_t, align 8
  %228 = getelementptr inbounds nuw %TypeInfo, ptr %227, i32 0, i32 0
  %229 = load i32, ptr %228, align 4
  %230 = icmp ne i32 %229, 2
  store i1 %230, ptr %sc.151, align 1
  br i1 %230, label %label_2636, label %label_2637

label_2637:                                       ; preds = %label_2636, %label_2633
  %231 = load i1, ptr %sc.151, align 1
  br i1 %231, label %label_2638, label %label_2640

label_2636:                                       ; preds = %label_2633
  %232 = load ptr, ptr %scrut_t, align 8
  %233 = getelementptr inbounds nuw %TypeInfo, ptr %232, i32 0, i32 0
  %234 = load i32, ptr %233, align 4
  %235 = icmp ne i32 %234, 9
  store i1 %235, ptr %sc.151, align 1
  br label %label_2637

label_2640:                                       ; preds = %label_2638, %label_2637
  %236 = load ptr, ptr %scrut_t, align 8
  %237 = call ptr @type_copy__Struct_TypeInfo(ptr %236)
  store ptr %237, ptr %pat_expected, align 8
  %238 = load ptr, ptr %scrut_t, align 8
  %239 = getelementptr inbounds nuw %TypeInfo, ptr %238, i32 0, i32 0
  %240 = load i32, ptr %239, align 4
  %241 = icmp eq i32 %240, 9
  br i1 %241, label %label_2641, label %label_2643

label_2638:                                       ; preds = %label_2637
  call void @sema_error__String(ptr @.str.s982)
  br label %label_2640

label_2643:                                       ; preds = %label_2641, %label_2640
  %242 = load ptr, ptr %stmt, align 8
  %243 = getelementptr inbounds nuw %ASTNode, ptr %242, i32 0, i32 6
  %244 = load ptr, ptr %243, align 8
  store ptr %244, ptr %arm_ptr, align 8
  br label %label_2644

label_2641:                                       ; preds = %label_2640
  %245 = call ptr @type_int__Void()
  store ptr %245, ptr %pat_expected, align 8
  br label %label_2643

label_2644:                                       ; preds = %label_2649, %label_2643
  %246 = load ptr, ptr %arm_ptr, align 8
  %247 = call i32 @str_equals(ptr %246, ptr @.str.s983)
  %248 = icmp eq i32 %247, 0
  br i1 %248, label %label_2645, label %label_2646

label_2646:                                       ; preds = %label_2644
  br label %label_2635

label_2645:                                       ; preds = %label_2644
  %249 = load ptr, ptr %arm_ptr, align 8
  %250 = call ptr @ptr_to_node(ptr %249)
  store ptr %250, ptr %arm, align 8
  %251 = load ptr, ptr %arm, align 8
  %252 = getelementptr inbounds nuw %ASTNode, ptr %251, i32 0, i32 1
  %253 = load ptr, ptr %252, align 8
  %254 = call i32 @str_equals(ptr %253, ptr @.str.s984)
  %255 = icmp eq i32 %254, 0
  br i1 %255, label %label_2647, label %label_2649

label_2649:                                       ; preds = %label_2647, %label_2645
  %256 = load ptr, ptr %module, align 8
  %257 = load ptr, ptr %arm, align 8
  %258 = getelementptr inbounds nuw %ASTNode, ptr %257, i32 0, i32 6
  %259 = load ptr, ptr %258, align 8
  %260 = call ptr @ptr_to_node(ptr %259)
  %261 = load ptr, ptr %expected_return, align 8
  call void @sema_block__Struct_ASTNode_Struct_ASTNode_Struct_TypeInfo(ptr %256, ptr %260, ptr %261)
  %262 = load ptr, ptr %arm, align 8
  %263 = getelementptr inbounds nuw %ASTNode, ptr %262, i32 0, i32 8
  %264 = load ptr, ptr %263, align 8
  store ptr %264, ptr %arm_ptr, align 8
  br label %label_2644

label_2647:                                       ; preds = %label_2645
  %265 = load ptr, ptr %module, align 8
  %266 = load ptr, ptr %arm, align 8
  %267 = getelementptr inbounds nuw %ASTNode, ptr %266, i32 0, i32 5
  %268 = load ptr, ptr %267, align 8
  %269 = call ptr @ptr_to_node(ptr %268)
  %270 = load ptr, ptr %pat_expected, align 8
  %271 = call ptr @sema_check_value__Struct_ASTNode_Struct_ASTNode_Struct_TypeInfo_String(ptr %265, ptr %269, ptr %270, ptr @.str.s985)
  br label %label_2649
}

define void @sema_block__Struct_ASTNode_Struct_ASTNode_Struct_TypeInfo(ptr %0, ptr %1, ptr %2) {
entry:
  %module = alloca ptr, align 8
  store ptr %0, ptr %module, align 8
  %block = alloca ptr, align 8
  store ptr %1, ptr %block, align 8
  %expected_return = alloca ptr, align 8
  store ptr %2, ptr %expected_return, align 8
  %stmt_ptr = alloca ptr, align 8
  %stmt = alloca ptr, align 8
  %3 = load ptr, ptr %block, align 8
  %4 = getelementptr inbounds nuw %ASTNode, ptr %3, i32 0, i32 5
  %5 = load ptr, ptr %4, align 8
  store ptr %5, ptr %stmt_ptr, align 8
  br label %label_2650

label_2650:                                       ; preds = %label_2651, %entry
  %6 = load ptr, ptr %stmt_ptr, align 8
  %7 = call i32 @str_equals(ptr %6, ptr @.str.s986)
  %8 = icmp eq i32 %7, 0
  br i1 %8, label %label_2651, label %label_2652

label_2652:                                       ; preds = %label_2650
  ret void

label_2651:                                       ; preds = %label_2650
  %9 = load ptr, ptr %stmt_ptr, align 8
  %10 = call ptr @ptr_to_node(ptr %9)
  store ptr %10, ptr %stmt, align 8
  %11 = load ptr, ptr %module, align 8
  %12 = load ptr, ptr %stmt, align 8
  %13 = load ptr, ptr %expected_return, align 8
  call void @sema_statement__Struct_ASTNode_Struct_ASTNode_Struct_TypeInfo(ptr %11, ptr %12, ptr %13)
  %14 = load ptr, ptr %stmt, align 8
  %15 = getelementptr inbounds nuw %ASTNode, ptr %14, i32 0, i32 8
  %16 = load ptr, ptr %15, align 8
  store ptr %16, ptr %stmt_ptr, align 8
  br label %label_2650
}

define void @sema_predeclare_function__Struct_ASTNode_Struct_ASTNode(ptr %0, ptr %1) {
entry:
  %module = alloca ptr, align 8
  store ptr %0, ptr %module, align 8
  %fn_node = alloca ptr, align 8
  store ptr %1, ptr %fn_node, align 8
  %ret_t = alloca ptr, align 8
  %symbol = alloca ptr, align 8
  %overload_key = alloca ptr, align 8
  %2 = call ptr @type_void__Void()
  store ptr %2, ptr %ret_t, align 8
  %3 = load ptr, ptr %fn_node, align 8
  %4 = getelementptr inbounds nuw %ASTNode, ptr %3, i32 0, i32 0
  %5 = load i32, ptr %4, align 4
  %6 = icmp eq i32 %5, 4
  br i1 %6, label %label_2653, label %label_2654

label_2654:                                       ; preds = %entry
  %7 = load ptr, ptr %module, align 8
  %8 = load ptr, ptr %fn_node, align 8
  %9 = getelementptr inbounds nuw %ASTNode, ptr %8, i32 0, i32 6
  %10 = load ptr, ptr %9, align 8
  %11 = call ptr @sema_declared_return_type__Struct_ASTNode_String(ptr %7, ptr %10)
  store ptr %11, ptr %ret_t, align 8
  br label %label_2655

label_2653:                                       ; preds = %entry
  %12 = load ptr, ptr %module, align 8
  %13 = load ptr, ptr %fn_node, align 8
  %14 = getelementptr inbounds nuw %ASTNode, ptr %13, i32 0, i32 7
  %15 = load ptr, ptr %14, align 8
  %16 = call ptr @sema_declared_return_type__Struct_ASTNode_String(ptr %12, ptr %15)
  store ptr %16, ptr %ret_t, align 8
  %17 = load ptr, ptr %fn_node, align 8
  %18 = getelementptr inbounds nuw %ASTNode, ptr %17, i32 0, i32 1
  %19 = load ptr, ptr %18, align 8
  %20 = call i32 @str_equals(ptr %19, ptr @.str.s987)
  %21 = icmp eq i32 %20, 1
  br i1 %21, label %label_2656, label %label_2658

label_2658:                                       ; preds = %label_2656, %label_2653
  br label %label_2655

label_2656:                                       ; preds = %label_2653
  %22 = call ptr @type_int__Void()
  store ptr %22, ptr %ret_t, align 8
  br label %label_2658

label_2655:                                       ; preds = %label_2654, %label_2658
  %23 = load ptr, ptr %module, align 8
  %24 = load ptr, ptr %fn_node, align 8
  %25 = call ptr @sema_function_symbol__Struct_ASTNode_Struct_ASTNode(ptr %23, ptr %24)
  store ptr %25, ptr %symbol, align 8
  %26 = load ptr, ptr %fn_node, align 8
  %27 = load ptr, ptr %symbol, align 8
  %28 = getelementptr inbounds nuw %ASTNode, ptr %26, i32 0, i32 2
  store ptr %27, ptr %28, align 8
  %29 = load ptr, ptr %symbol, align 8
  %30 = call ptr @sema_fn_key__String(ptr %29)
  store ptr %30, ptr %overload_key, align 8
  %31 = load ptr, ptr %module, align 8
  %32 = load ptr, ptr %symbol, align 8
  %33 = call i32 @sema_function_symbol_count__Struct_ASTNode_String(ptr %31, ptr %32)
  %34 = icmp sgt i32 %33, 1
  br i1 %34, label %label_2659, label %label_2661

label_2661:                                       ; preds = %label_2659, %label_2655
  %35 = load ptr, ptr %overload_key, align 8
  %36 = load ptr, ptr %ret_t, align 8
  %37 = call ptr @type_sem_key__Struct_TypeInfo(ptr %36)
  call void @ir_set_var_type(ptr %35, ptr %37)
  ret void

label_2659:                                       ; preds = %label_2655
  %38 = load ptr, ptr %fn_node, align 8
  %39 = getelementptr inbounds nuw %ASTNode, ptr %38, i32 0, i32 1
  %40 = load ptr, ptr %39, align 8
  %41 = call ptr @str_concat(ptr @.str.s988, ptr %40)
  call void @sema_error__String(ptr %41)
  br label %label_2661
}

define void @sema_predeclare_global__Struct_ASTNode_Struct_ASTNode(ptr %0, ptr %1) {
entry:
  %module = alloca ptr, align 8
  store ptr %0, ptr %module, align 8
  %var_node = alloca ptr, align 8
  store ptr %1, ptr %var_node, align 8
  %var_t = alloca ptr, align 8
  %2 = call ptr @type_invalid__Void()
  store ptr %2, ptr %var_t, align 8
  %3 = load ptr, ptr %var_node, align 8
  %4 = getelementptr inbounds nuw %ASTNode, ptr %3, i32 0, i32 5
  %5 = load ptr, ptr %4, align 8
  %6 = call i32 @str_equals(ptr %5, ptr @.str.s989)
  %7 = icmp eq i32 %6, 0
  br i1 %7, label %label_2662, label %label_2664

label_2664:                                       ; preds = %label_2662, %entry
  %8 = load ptr, ptr %var_node, align 8
  %9 = getelementptr inbounds nuw %ASTNode, ptr %8, i32 0, i32 6
  %10 = load ptr, ptr %9, align 8
  %11 = call i32 @str_equals(ptr %10, ptr @.str.s990)
  %12 = icmp eq i32 %11, 0
  br i1 %12, label %label_2665, label %label_2667

label_2662:                                       ; preds = %entry
  %13 = load ptr, ptr %module, align 8
  %14 = load ptr, ptr %var_node, align 8
  %15 = getelementptr inbounds nuw %ASTNode, ptr %14, i32 0, i32 5
  %16 = load ptr, ptr %15, align 8
  %17 = call ptr @ptr_to_node(ptr %16)
  %18 = call ptr @sema_annotation_type__Struct_ASTNode_Struct_ASTNode(ptr %13, ptr %17)
  store ptr %18, ptr %var_t, align 8
  br label %label_2664

label_2667:                                       ; preds = %label_2670, %label_2664
  %19 = load ptr, ptr %var_t, align 8
  %20 = call i1 @type_is_valid__Struct_TypeInfo(ptr %19)
  %21 = icmp eq i1 %20, false
  br i1 %21, label %label_2671, label %label_2673

label_2665:                                       ; preds = %label_2664
  %22 = load ptr, ptr %var_t, align 8
  %23 = call i1 @type_is_valid__Struct_TypeInfo(ptr %22)
  br i1 %23, label %label_2668, label %label_2669

label_2669:                                       ; preds = %label_2665
  %24 = load ptr, ptr %module, align 8
  %25 = load ptr, ptr %var_node, align 8
  %26 = getelementptr inbounds nuw %ASTNode, ptr %25, i32 0, i32 6
  %27 = load ptr, ptr %26, align 8
  %28 = call ptr @ptr_to_node(ptr %27)
  %29 = call ptr @sema_expr__Struct_ASTNode_Struct_ASTNode(ptr %24, ptr %28)
  store ptr %29, ptr %var_t, align 8
  br label %label_2670

label_2668:                                       ; preds = %label_2665
  %30 = load ptr, ptr %module, align 8
  %31 = load ptr, ptr %var_node, align 8
  %32 = getelementptr inbounds nuw %ASTNode, ptr %31, i32 0, i32 6
  %33 = load ptr, ptr %32, align 8
  %34 = call ptr @ptr_to_node(ptr %33)
  %35 = load ptr, ptr %var_t, align 8
  %36 = load ptr, ptr %var_node, align 8
  %37 = getelementptr inbounds nuw %ASTNode, ptr %36, i32 0, i32 1
  %38 = load ptr, ptr %37, align 8
  %39 = call ptr @str_concat(ptr @.str.s991, ptr %38)
  %40 = call ptr @sema_check_value__Struct_ASTNode_Struct_ASTNode_Struct_TypeInfo_String(ptr %30, ptr %34, ptr %35, ptr %39)
  br label %label_2670

label_2670:                                       ; preds = %label_2669, %label_2668
  br label %label_2667

label_2673:                                       ; preds = %label_2671, %label_2667
  %41 = load ptr, ptr %var_node, align 8
  %42 = getelementptr inbounds nuw %ASTNode, ptr %41, i32 0, i32 1
  %43 = load ptr, ptr %42, align 8
  call void @ir_register_global_name(ptr %43)
  %44 = load ptr, ptr %var_node, align 8
  %45 = getelementptr inbounds nuw %ASTNode, ptr %44, i32 0, i32 1
  %46 = load ptr, ptr %45, align 8
  %47 = load ptr, ptr %var_t, align 8
  %48 = call ptr @type_sem_key__Struct_TypeInfo(ptr %47)
  call void @ir_set_var_type(ptr %46, ptr %48)
  %49 = load ptr, ptr %var_node, align 8
  %50 = load ptr, ptr %var_t, align 8
  call void @node_set_type__Struct_ASTNode_Struct_TypeInfo(ptr %49, ptr %50)
  ret void

label_2671:                                       ; preds = %label_2667
  %51 = load ptr, ptr %var_node, align 8
  %52 = getelementptr inbounds nuw %ASTNode, ptr %51, i32 0, i32 1
  %53 = load ptr, ptr %52, align 8
  %54 = call ptr @str_concat(ptr @.str.s992, ptr %53)
  call void @sema_error__String(ptr %54)
  br label %label_2673
}

define void @sema_function__Struct_ASTNode_Struct_ASTNode(ptr %0, ptr %1) {
entry:
  %module = alloca ptr, align 8
  store ptr %0, ptr %module, align 8
  %fn_node = alloca ptr, align 8
  store ptr %1, ptr %fn_node, align 8
  %expected_return = alloca ptr, align 8
  %param_ptr = alloca ptr, align 8
  %param = alloca ptr, align 8
  %param_t = alloca ptr, align 8
  call void @ir_clear_local_var_types()
  call void @ir_clear_moved()
  call void @ir_clear_borrowed()
  %2 = load ptr, ptr %module, align 8
  %3 = load ptr, ptr %fn_node, align 8
  %4 = getelementptr inbounds nuw %ASTNode, ptr %3, i32 0, i32 7
  %5 = load ptr, ptr %4, align 8
  %6 = call ptr @sema_declared_return_type__Struct_ASTNode_String(ptr %2, ptr %5)
  store ptr %6, ptr %expected_return, align 8
  %7 = load ptr, ptr %fn_node, align 8
  %8 = getelementptr inbounds nuw %ASTNode, ptr %7, i32 0, i32 1
  %9 = load ptr, ptr %8, align 8
  %10 = call i32 @str_equals(ptr %9, ptr @.str.s993)
  %11 = icmp eq i32 %10, 1
  br i1 %11, label %label_2674, label %label_2676

label_2676:                                       ; preds = %label_2674, %entry
  %12 = load ptr, ptr %fn_node, align 8
  %13 = getelementptr inbounds nuw %ASTNode, ptr %12, i32 0, i32 5
  %14 = load ptr, ptr %13, align 8
  store ptr %14, ptr %param_ptr, align 8
  br label %label_2677

label_2674:                                       ; preds = %entry
  %15 = call ptr @type_int__Void()
  store ptr %15, ptr %expected_return, align 8
  br label %label_2676

label_2677:                                       ; preds = %label_2687, %label_2676
  %16 = load ptr, ptr %param_ptr, align 8
  %17 = call i32 @str_equals(ptr %16, ptr @.str.s994)
  %18 = icmp eq i32 %17, 0
  br i1 %18, label %label_2678, label %label_2679

label_2679:                                       ; preds = %label_2677
  %19 = load ptr, ptr %fn_node, align 8
  %20 = getelementptr inbounds nuw %ASTNode, ptr %19, i32 0, i32 6
  %21 = load ptr, ptr %20, align 8
  %22 = call i32 @str_equals(ptr %21, ptr @.str.s998)
  %23 = icmp eq i32 %22, 0
  br i1 %23, label %label_2688, label %label_2690

label_2678:                                       ; preds = %label_2677
  %24 = load ptr, ptr %param_ptr, align 8
  %25 = call ptr @ptr_to_node(ptr %24)
  store ptr %25, ptr %param, align 8
  %26 = load ptr, ptr %module, align 8
  %27 = load ptr, ptr %param, align 8
  %28 = getelementptr inbounds nuw %ASTNode, ptr %27, i32 0, i32 5
  %29 = load ptr, ptr %28, align 8
  %30 = call ptr @ptr_to_node(ptr %29)
  %31 = call ptr @sema_annotation_type__Struct_ASTNode_Struct_ASTNode(ptr %26, ptr %30)
  store ptr %31, ptr %param_t, align 8
  %sc.152 = alloca i1, align 1
  %32 = load ptr, ptr %param, align 8
  %33 = getelementptr inbounds nuw %ASTNode, ptr %32, i32 0, i32 2
  %34 = load ptr, ptr %33, align 8
  %35 = call i32 @str_equals(ptr %34, ptr @.str.s995)
  %36 = icmp eq i32 %35, 1
  store i1 %36, ptr %sc.152, align 1
  br i1 %36, label %label_2680, label %label_2681

label_2681:                                       ; preds = %label_2680, %label_2678
  %37 = load i1, ptr %sc.152, align 1
  br i1 %37, label %label_2682, label %label_2684

label_2680:                                       ; preds = %label_2678
  %38 = load ptr, ptr %param_t, align 8
  %39 = call i1 @type_is_move_only__Struct_TypeInfo(ptr %38)
  %40 = icmp eq i1 %39, false
  store i1 %40, ptr %sc.152, align 1
  br label %label_2681

label_2684:                                       ; preds = %label_2682, %label_2681
  %41 = load ptr, ptr %param, align 8
  %42 = getelementptr inbounds nuw %ASTNode, ptr %41, i32 0, i32 2
  %43 = load ptr, ptr %42, align 8
  %44 = call i32 @str_equals(ptr %43, ptr @.str.s997)
  %45 = icmp eq i32 %44, 0
  br i1 %45, label %label_2685, label %label_2687

label_2682:                                       ; preds = %label_2681
  %46 = load ptr, ptr %param, align 8
  %47 = getelementptr inbounds nuw %ASTNode, ptr %46, i32 0, i32 1
  %48 = load ptr, ptr %47, align 8
  %49 = call ptr @str_concat(ptr @.str.s996, ptr %48)
  call void @sema_error__String(ptr %49)
  br label %label_2684

label_2687:                                       ; preds = %label_2685, %label_2684
  %50 = load ptr, ptr %param, align 8
  %51 = getelementptr inbounds nuw %ASTNode, ptr %50, i32 0, i32 1
  %52 = load ptr, ptr %51, align 8
  %53 = load ptr, ptr %param_t, align 8
  %54 = call ptr @type_sem_key__Struct_TypeInfo(ptr %53)
  call void @ir_set_var_type(ptr %52, ptr %54)
  %55 = load ptr, ptr %param, align 8
  %56 = load ptr, ptr %param_t, align 8
  call void @node_set_type__Struct_ASTNode_Struct_TypeInfo(ptr %55, ptr %56)
  %57 = load ptr, ptr %param, align 8
  %58 = getelementptr inbounds nuw %ASTNode, ptr %57, i32 0, i32 8
  %59 = load ptr, ptr %58, align 8
  store ptr %59, ptr %param_ptr, align 8
  br label %label_2677

label_2685:                                       ; preds = %label_2684
  %60 = load ptr, ptr %param, align 8
  %61 = getelementptr inbounds nuw %ASTNode, ptr %60, i32 0, i32 1
  %62 = load ptr, ptr %61, align 8
  call void @ir_mark_borrowed(ptr %62)
  br label %label_2687

label_2690:                                       ; preds = %label_2688, %label_2679
  ret void

label_2688:                                       ; preds = %label_2679
  %63 = load ptr, ptr %module, align 8
  %64 = load ptr, ptr %fn_node, align 8
  %65 = getelementptr inbounds nuw %ASTNode, ptr %64, i32 0, i32 6
  %66 = load ptr, ptr %65, align 8
  %67 = call ptr @ptr_to_node(ptr %66)
  %68 = load ptr, ptr %expected_return, align 8
  call void @sema_block__Struct_ASTNode_Struct_ASTNode_Struct_TypeInfo(ptr %63, ptr %67, ptr %68)
  br label %label_2690
}

define void @analyze_module__Struct_ASTNode(ptr %0) {
entry:
  %module = alloca ptr, align 8
  store ptr %0, ptr %module, align 8
  %fn_ptr = alloca ptr, align 8
  %stmt = alloca ptr, align 8
  %global_ptr = alloca ptr, align 8
  %stmt2 = alloca ptr, align 8
  %stmt_ptr = alloca ptr, align 8
  %stmt3 = alloca ptr, align 8
  call void @ir_clear_var_types()
  call void @ir_reset_globals()
  %1 = load ptr, ptr %module, align 8
  %2 = getelementptr inbounds nuw %ASTNode, ptr %1, i32 0, i32 5
  %3 = load ptr, ptr %2, align 8
  store ptr %3, ptr %fn_ptr, align 8
  br label %label_2691

label_2691:                                       ; preds = %label_2698, %entry
  %4 = load ptr, ptr %fn_ptr, align 8
  %5 = call i32 @str_equals(ptr %4, ptr @.str.s999)
  %6 = icmp eq i32 %5, 0
  br i1 %6, label %label_2692, label %label_2693

label_2693:                                       ; preds = %label_2691
  %7 = load ptr, ptr %module, align 8
  %8 = getelementptr inbounds nuw %ASTNode, ptr %7, i32 0, i32 5
  %9 = load ptr, ptr %8, align 8
  store ptr %9, ptr %global_ptr, align 8
  br label %label_2699

label_2692:                                       ; preds = %label_2691
  %10 = load ptr, ptr %fn_ptr, align 8
  %11 = call ptr @ptr_to_node(ptr %10)
  store ptr %11, ptr %stmt, align 8
  %sc.153 = alloca i1, align 1
  %12 = load ptr, ptr %stmt, align 8
  %13 = getelementptr inbounds nuw %ASTNode, ptr %12, i32 0, i32 0
  %14 = load i32, ptr %13, align 4
  %15 = icmp eq i32 %14, 4
  store i1 %15, ptr %sc.153, align 1
  br i1 %15, label %label_2695, label %label_2694

label_2694:                                       ; preds = %label_2692
  %16 = load ptr, ptr %stmt, align 8
  %17 = getelementptr inbounds nuw %ASTNode, ptr %16, i32 0, i32 0
  %18 = load i32, ptr %17, align 4
  %19 = icmp eq i32 %18, 2
  store i1 %19, ptr %sc.153, align 1
  br label %label_2695

label_2695:                                       ; preds = %label_2694, %label_2692
  %20 = load i1, ptr %sc.153, align 1
  br i1 %20, label %label_2696, label %label_2698

label_2698:                                       ; preds = %label_2696, %label_2695
  %21 = load ptr, ptr %stmt, align 8
  %22 = getelementptr inbounds nuw %ASTNode, ptr %21, i32 0, i32 8
  %23 = load ptr, ptr %22, align 8
  store ptr %23, ptr %fn_ptr, align 8
  br label %label_2691

label_2696:                                       ; preds = %label_2695
  %24 = load ptr, ptr %module, align 8
  %25 = load ptr, ptr %stmt, align 8
  call void @sema_predeclare_function__Struct_ASTNode_Struct_ASTNode(ptr %24, ptr %25)
  br label %label_2698

label_2699:                                       ; preds = %label_2704, %label_2693
  %26 = load ptr, ptr %global_ptr, align 8
  %27 = call i32 @str_equals(ptr %26, ptr @.str.s1000)
  %28 = icmp eq i32 %27, 0
  br i1 %28, label %label_2700, label %label_2701

label_2701:                                       ; preds = %label_2699
  %29 = load ptr, ptr %module, align 8
  %30 = getelementptr inbounds nuw %ASTNode, ptr %29, i32 0, i32 5
  %31 = load ptr, ptr %30, align 8
  store ptr %31, ptr %stmt_ptr, align 8
  br label %label_2705

label_2700:                                       ; preds = %label_2699
  %32 = load ptr, ptr %global_ptr, align 8
  %33 = call ptr @ptr_to_node(ptr %32)
  store ptr %33, ptr %stmt2, align 8
  %34 = load ptr, ptr %stmt2, align 8
  %35 = getelementptr inbounds nuw %ASTNode, ptr %34, i32 0, i32 0
  %36 = load i32, ptr %35, align 4
  %37 = icmp eq i32 %36, 3
  br i1 %37, label %label_2702, label %label_2704

label_2704:                                       ; preds = %label_2702, %label_2700
  %38 = load ptr, ptr %stmt2, align 8
  %39 = getelementptr inbounds nuw %ASTNode, ptr %38, i32 0, i32 8
  %40 = load ptr, ptr %39, align 8
  store ptr %40, ptr %global_ptr, align 8
  br label %label_2699

label_2702:                                       ; preds = %label_2700
  %41 = load ptr, ptr %module, align 8
  %42 = load ptr, ptr %stmt2, align 8
  call void @sema_predeclare_global__Struct_ASTNode_Struct_ASTNode(ptr %41, ptr %42)
  br label %label_2704

label_2705:                                       ; preds = %label_2710, %label_2701
  %43 = load ptr, ptr %stmt_ptr, align 8
  %44 = call i32 @str_equals(ptr %43, ptr @.str.s1001)
  %45 = icmp eq i32 %44, 0
  br i1 %45, label %label_2706, label %label_2707

label_2707:                                       ; preds = %label_2705
  ret void

label_2706:                                       ; preds = %label_2705
  %46 = load ptr, ptr %stmt_ptr, align 8
  %47 = call ptr @ptr_to_node(ptr %46)
  store ptr %47, ptr %stmt3, align 8
  %48 = load ptr, ptr %stmt3, align 8
  %49 = getelementptr inbounds nuw %ASTNode, ptr %48, i32 0, i32 0
  %50 = load i32, ptr %49, align 4
  %51 = icmp eq i32 %50, 4
  br i1 %51, label %label_2708, label %label_2710

label_2710:                                       ; preds = %label_2708, %label_2706
  %52 = load ptr, ptr %stmt3, align 8
  %53 = getelementptr inbounds nuw %ASTNode, ptr %52, i32 0, i32 8
  %54 = load ptr, ptr %53, align 8
  store ptr %54, ptr %stmt_ptr, align 8
  br label %label_2705

label_2708:                                       ; preds = %label_2706
  %55 = load ptr, ptr %module, align 8
  %56 = load ptr, ptr %stmt3, align 8
  call void @sema_function__Struct_ASTNode_Struct_ASTNode(ptr %55, ptr %56)
  br label %label_2710
}

define i1 @is_named_top_level__Struct_ASTNode(ptr %0) {
entry:
  %stmt = alloca ptr, align 8
  store ptr %0, ptr %stmt, align 8
  %1 = load ptr, ptr %stmt, align 8
  %2 = getelementptr inbounds nuw %ASTNode, ptr %1, i32 0, i32 0
  %3 = load i32, ptr %2, align 4
  %4 = icmp eq i32 %3, 2
  br i1 %4, label %label_2711, label %label_2713

label_2713:                                       ; preds = %entry
  %5 = load ptr, ptr %stmt, align 8
  %6 = getelementptr inbounds nuw %ASTNode, ptr %5, i32 0, i32 0
  %7 = load i32, ptr %6, align 4
  %8 = icmp eq i32 %7, 3
  br i1 %8, label %label_2714, label %label_2716

label_2711:                                       ; preds = %entry
  ret i1 true

label_2716:                                       ; preds = %label_2713
  %9 = load ptr, ptr %stmt, align 8
  %10 = getelementptr inbounds nuw %ASTNode, ptr %9, i32 0, i32 0
  %11 = load i32, ptr %10, align 4
  %12 = icmp eq i32 %11, 4
  br i1 %12, label %label_2717, label %label_2719

label_2714:                                       ; preds = %label_2713
  ret i1 true

label_2719:                                       ; preds = %label_2716
  %13 = load ptr, ptr %stmt, align 8
  %14 = getelementptr inbounds nuw %ASTNode, ptr %13, i32 0, i32 0
  %15 = load i32, ptr %14, align 4
  %16 = icmp eq i32 %15, 5
  br i1 %16, label %label_2720, label %label_2722

label_2717:                                       ; preds = %label_2716
  ret i1 true

label_2722:                                       ; preds = %label_2719
  %17 = load ptr, ptr %stmt, align 8
  %18 = getelementptr inbounds nuw %ASTNode, ptr %17, i32 0, i32 0
  %19 = load i32, ptr %18, align 4
  %20 = icmp eq i32 %19, 6
  br i1 %20, label %label_2723, label %label_2725

label_2720:                                       ; preds = %label_2719
  ret i1 true

label_2725:                                       ; preds = %label_2722
  ret i1 false

label_2723:                                       ; preds = %label_2722
  ret i1 true
}

define i1 @same_top_level_name__Struct_ASTNode_Struct_ASTNode(ptr %0, ptr %1) {
entry:
  %a = alloca ptr, align 8
  store ptr %0, ptr %a, align 8
  %b = alloca ptr, align 8
  store ptr %1, ptr %b, align 8
  %2 = load ptr, ptr %a, align 8
  %3 = getelementptr inbounds nuw %ASTNode, ptr %2, i32 0, i32 0
  %4 = load i32, ptr %3, align 4
  %5 = load ptr, ptr %b, align 8
  %6 = getelementptr inbounds nuw %ASTNode, ptr %5, i32 0, i32 0
  %7 = load i32, ptr %6, align 4
  %8 = icmp ne i32 %4, %7
  br i1 %8, label %label_2726, label %label_2728

label_2728:                                       ; preds = %entry
  %9 = load ptr, ptr %a, align 8
  %10 = getelementptr inbounds nuw %ASTNode, ptr %9, i32 0, i32 1
  %11 = load ptr, ptr %10, align 8
  %12 = load ptr, ptr %b, align 8
  %13 = getelementptr inbounds nuw %ASTNode, ptr %12, i32 0, i32 1
  %14 = load ptr, ptr %13, align 8
  %15 = call i32 @str_equals(ptr %11, ptr %14)
  %16 = icmp eq i32 %15, 0
  br i1 %16, label %label_2729, label %label_2731

label_2726:                                       ; preds = %entry
  ret i1 false

label_2731:                                       ; preds = %label_2728
  %17 = load ptr, ptr %a, align 8
  %18 = getelementptr inbounds nuw %ASTNode, ptr %17, i32 0, i32 0
  %19 = load i32, ptr %18, align 4
  %20 = icmp eq i32 %19, 4
  br i1 %20, label %label_2732, label %label_2734

label_2729:                                       ; preds = %label_2728
  ret i1 false

label_2734:                                       ; preds = %label_2731
  ret i1 true

label_2732:                                       ; preds = %label_2731
  ret i1 false
}

define i1 @has_named_top_level__Struct_ASTNode_Struct_ASTNode(ptr %0, ptr %1) {
entry:
  %module = alloca ptr, align 8
  store ptr %0, ptr %module, align 8
  %stmt = alloca ptr, align 8
  store ptr %1, ptr %stmt, align 8
  %scan_ptr = alloca ptr, align 8
  %scan = alloca ptr, align 8
  %2 = load ptr, ptr %stmt, align 8
  %3 = call i1 @is_named_top_level__Struct_ASTNode(ptr %2)
  %4 = icmp eq i1 %3, false
  br i1 %4, label %label_2735, label %label_2737

label_2737:                                       ; preds = %entry
  %5 = load ptr, ptr %module, align 8
  %6 = getelementptr inbounds nuw %ASTNode, ptr %5, i32 0, i32 5
  %7 = load ptr, ptr %6, align 8
  store ptr %7, ptr %scan_ptr, align 8
  br label %label_2738

label_2735:                                       ; preds = %entry
  ret i1 false

label_2738:                                       ; preds = %label_2743, %label_2737
  %8 = load ptr, ptr %scan_ptr, align 8
  %9 = call i32 @str_equals(ptr %8, ptr @.str.s1002)
  %10 = icmp eq i32 %9, 0
  br i1 %10, label %label_2739, label %label_2740

label_2740:                                       ; preds = %label_2738
  ret i1 false

label_2739:                                       ; preds = %label_2738
  %11 = load ptr, ptr %scan_ptr, align 8
  %12 = call ptr @ptr_to_node(ptr %11)
  store ptr %12, ptr %scan, align 8
  %13 = load ptr, ptr %scan, align 8
  %14 = load ptr, ptr %stmt, align 8
  %15 = call i1 @same_top_level_name__Struct_ASTNode_Struct_ASTNode(ptr %13, ptr %14)
  br i1 %15, label %label_2741, label %label_2743

label_2743:                                       ; preds = %label_2739
  %16 = load ptr, ptr %scan, align 8
  %17 = getelementptr inbounds nuw %ASTNode, ptr %16, i32 0, i32 8
  %18 = load ptr, ptr %17, align 8
  store ptr %18, ptr %scan_ptr, align 8
  br label %label_2738

label_2741:                                       ; preds = %label_2739
  ret i1 true
}

define ptr @parse_source__String(ptr %0) {
entry:
  %content = alloca ptr, align 8
  store ptr %0, ptr %content, align 8
  %lex = alloca ptr, align 8
  %head_token = alloca ptr, align 8
  %p = alloca ptr, align 8
  %1 = load ptr, ptr %content, align 8
  %2 = call ptr @create_lexer__String(ptr %1)
  store ptr %2, ptr %lex, align 8
  %3 = load ptr, ptr %lex, align 8
  %4 = call ptr @lex_all_tokens__Struct_Lexer(ptr %3)
  store ptr %4, ptr %head_token, align 8
  %5 = load ptr, ptr %head_token, align 8
  %6 = call ptr @parser_create__Struct_Token(ptr %5)
  store ptr %6, ptr %p, align 8
  %7 = load ptr, ptr %p, align 8
  %8 = call ptr @parse_module__Struct_Parser(ptr %7)
  ret ptr %8
}

define void @append_statement__Struct_ASTNode_Struct_ASTNode(ptr %0, ptr %1) {
entry:
  %module = alloca ptr, align 8
  store ptr %0, ptr %module, align 8
  %stmt = alloca ptr, align 8
  store ptr %1, ptr %stmt, align 8
  %tail_ptr = alloca ptr, align 8
  %searching = alloca i1, align 1
  %tail = alloca ptr, align 8
  %2 = load ptr, ptr %module, align 8
  %3 = load ptr, ptr %stmt, align 8
  %4 = call i1 @has_named_top_level__Struct_ASTNode_Struct_ASTNode(ptr %2, ptr %3)
  br i1 %4, label %label_2744, label %label_2746

label_2746:                                       ; preds = %entry
  %5 = load ptr, ptr %module, align 8
  %6 = getelementptr inbounds nuw %ASTNode, ptr %5, i32 0, i32 5
  %7 = load ptr, ptr %6, align 8
  %8 = call i32 @str_equals(ptr %7, ptr @.str.s1003)
  %9 = icmp eq i32 %8, 1
  br i1 %9, label %label_2747, label %label_2749

label_2744:                                       ; preds = %entry
  ret void

label_2749:                                       ; preds = %label_2746
  %10 = load ptr, ptr %module, align 8
  %11 = getelementptr inbounds nuw %ASTNode, ptr %10, i32 0, i32 5
  %12 = load ptr, ptr %11, align 8
  store ptr %12, ptr %tail_ptr, align 8
  store i1 true, ptr %searching, align 1
  br label %label_2750

label_2747:                                       ; preds = %label_2746
  %13 = load ptr, ptr %module, align 8
  %14 = load ptr, ptr %stmt, align 8
  %15 = call ptr @node_to_ptr(ptr %14)
  %16 = getelementptr inbounds nuw %ASTNode, ptr %13, i32 0, i32 5
  store ptr %15, ptr %16, align 8
  ret void

label_2750:                                       ; preds = %label_2755, %label_2749
  %17 = load i1, ptr %searching, align 1
  br i1 %17, label %label_2751, label %label_2752

label_2752:                                       ; preds = %label_2750
  ret void

label_2751:                                       ; preds = %label_2750
  %18 = load ptr, ptr %tail_ptr, align 8
  %19 = call ptr @ptr_to_node(ptr %18)
  store ptr %19, ptr %tail, align 8
  %20 = load ptr, ptr %tail, align 8
  %21 = getelementptr inbounds nuw %ASTNode, ptr %20, i32 0, i32 8
  %22 = load ptr, ptr %21, align 8
  %23 = call i32 @str_equals(ptr %22, ptr @.str.s1004)
  %24 = icmp eq i32 %23, 1
  br i1 %24, label %label_2753, label %label_2754

label_2754:                                       ; preds = %label_2751
  %25 = load ptr, ptr %tail, align 8
  %26 = getelementptr inbounds nuw %ASTNode, ptr %25, i32 0, i32 8
  %27 = load ptr, ptr %26, align 8
  store ptr %27, ptr %tail_ptr, align 8
  br label %label_2755

label_2753:                                       ; preds = %label_2751
  %28 = load ptr, ptr %tail, align 8
  %29 = load ptr, ptr %stmt, align 8
  %30 = call ptr @node_to_ptr(ptr %29)
  %31 = getelementptr inbounds nuw %ASTNode, ptr %28, i32 0, i32 8
  store ptr %30, ptr %31, align 8
  store i1 false, ptr %searching, align 1
  br label %label_2755

label_2755:                                       ; preds = %label_2754, %label_2753
  br label %label_2750
}

define ptr @join_import_path__String_String(ptr %0, ptr %1) {
entry:
  %base_dir = alloca ptr, align 8
  store ptr %0, ptr %base_dir, align 8
  %module_name = alloca ptr, align 8
  store ptr %1, ptr %module_name, align 8
  %module_file = alloca ptr, align 8
  %2 = load ptr, ptr %module_name, align 8
  %3 = call ptr @str_concat(ptr %2, ptr @.str.s1005)
  store ptr %3, ptr %module_file, align 8
  %4 = load ptr, ptr %base_dir, align 8
  %5 = call i32 @str_equals(ptr %4, ptr @.str.s1006)
  %6 = icmp eq i32 %5, 1
  br i1 %6, label %label_2756, label %label_2758

label_2758:                                       ; preds = %entry
  %7 = load ptr, ptr %base_dir, align 8
  %8 = load ptr, ptr %module_file, align 8
  %9 = call ptr @join_path(ptr %7, ptr %8)
  ret ptr %9

label_2756:                                       ; preds = %entry
  %10 = load ptr, ptr %module_file, align 8
  ret ptr %10
}

define ptr @import_memo_key__String(ptr %0) {
entry:
  %import_path = alloca ptr, align 8
  store ptr %0, ptr %import_path, align 8
  %1 = load ptr, ptr %import_path, align 8
  %2 = call ptr @str_concat(ptr @.str.s1007, ptr %1)
  %3 = call ptr @str_concat(ptr %2, ptr @.str.s1008)
  ret ptr %3
}

define ptr @merge_module_imports__Struct_ASTNode_Struct_ASTNode_String_String(ptr %0, ptr %1, ptr %2, ptr %3) {
entry:
  %merged = alloca ptr, align 8
  store ptr %0, ptr %merged, align 8
  %module = alloca ptr, align 8
  store ptr %1, ptr %module, align 8
  %base_dir = alloca ptr, align 8
  store ptr %2, ptr %base_dir, align 8
  %visited = alloca ptr, align 8
  store ptr %3, ptr %visited, align 8
  %seen = alloca ptr, align 8
  %stmt_ptr = alloca ptr, align 8
  %stmt = alloca ptr, align 8
  %next_stmt = alloca ptr, align 8
  %import_path = alloca ptr, align 8
  %key = alloca ptr, align 8
  %import_content = alloca ptr, align 8
  %imported_module = alloca ptr, align 8
  %4 = load ptr, ptr %visited, align 8
  store ptr %4, ptr %seen, align 8
  %5 = load ptr, ptr %module, align 8
  %6 = getelementptr inbounds nuw %ASTNode, ptr %5, i32 0, i32 5
  %7 = load ptr, ptr %6, align 8
  store ptr %7, ptr %stmt_ptr, align 8
  br label %label_2759

label_2759:                                       ; preds = %label_2764, %entry
  %8 = load ptr, ptr %stmt_ptr, align 8
  %9 = call i32 @str_equals(ptr %8, ptr @.str.s1009)
  %10 = icmp eq i32 %9, 0
  br i1 %10, label %label_2760, label %label_2761

label_2761:                                       ; preds = %label_2759
  %11 = load ptr, ptr %seen, align 8
  ret ptr %11

label_2760:                                       ; preds = %label_2759
  %12 = load ptr, ptr %stmt_ptr, align 8
  %13 = call ptr @ptr_to_node(ptr %12)
  store ptr %13, ptr %stmt, align 8
  %14 = load ptr, ptr %stmt, align 8
  %15 = getelementptr inbounds nuw %ASTNode, ptr %14, i32 0, i32 8
  %16 = load ptr, ptr %15, align 8
  store ptr %16, ptr %next_stmt, align 8
  %17 = load ptr, ptr %stmt, align 8
  %18 = getelementptr inbounds nuw %ASTNode, ptr %17, i32 0, i32 8
  store ptr @.str.s1010, ptr %18, align 8
  %19 = load ptr, ptr %stmt, align 8
  %20 = getelementptr inbounds nuw %ASTNode, ptr %19, i32 0, i32 0
  %21 = load i32, ptr %20, align 4
  %22 = icmp eq i32 %21, 1
  br i1 %22, label %label_2762, label %label_2763

label_2763:                                       ; preds = %label_2760
  %23 = load ptr, ptr %merged, align 8
  %24 = load ptr, ptr %stmt, align 8
  call void @append_statement__Struct_ASTNode_Struct_ASTNode(ptr %23, ptr %24)
  br label %label_2764

label_2762:                                       ; preds = %label_2760
  %25 = load ptr, ptr %base_dir, align 8
  %26 = load ptr, ptr %stmt, align 8
  %27 = getelementptr inbounds nuw %ASTNode, ptr %26, i32 0, i32 1
  %28 = load ptr, ptr %27, align 8
  %29 = call ptr @join_import_path__String_String(ptr %25, ptr %28)
  store ptr %29, ptr %import_path, align 8
  %30 = load ptr, ptr %import_path, align 8
  %31 = call ptr @import_memo_key__String(ptr %30)
  store ptr %31, ptr %key, align 8
  %32 = load ptr, ptr %seen, align 8
  %33 = load ptr, ptr %key, align 8
  %34 = call i32 @str_contains(ptr %32, ptr %33)
  %35 = icmp eq i32 %34, 0
  br i1 %35, label %label_2765, label %label_2767

label_2767:                                       ; preds = %label_2770, %label_2762
  br label %label_2764

label_2765:                                       ; preds = %label_2762
  %36 = load ptr, ptr %seen, align 8
  %37 = load ptr, ptr %key, align 8
  %38 = call ptr @str_concat(ptr %36, ptr %37)
  store ptr %38, ptr %seen, align 8
  %39 = load ptr, ptr %import_path, align 8
  %40 = call ptr @read_file(ptr %39)
  store ptr %40, ptr %import_content, align 8
  %41 = load ptr, ptr %import_content, align 8
  %42 = call i32 @str_equals(ptr %41, ptr @.str.s1011)
  %43 = icmp eq i32 %42, 1
  br i1 %43, label %label_2768, label %label_2770

label_2770:                                       ; preds = %label_2768, %label_2765
  %44 = load ptr, ptr %import_content, align 8
  %45 = call ptr @parse_source__String(ptr %44)
  store ptr %45, ptr %imported_module, align 8
  %46 = load ptr, ptr %merged, align 8
  %47 = load ptr, ptr %imported_module, align 8
  %48 = load ptr, ptr %base_dir, align 8
  %49 = load ptr, ptr %seen, align 8
  %50 = call ptr @merge_module_imports__Struct_ASTNode_Struct_ASTNode_String_String(ptr %46, ptr %47, ptr %48, ptr %49)
  store ptr %50, ptr %seen, align 8
  br label %label_2767

label_2768:                                       ; preds = %label_2765
  call void @print(ptr @.str.s1012)
  %51 = load ptr, ptr %import_path, align 8
  call void @println(ptr %51)
  call void @exit(i32 1)
  br label %label_2770

label_2764:                                       ; preds = %label_2763, %label_2767
  %52 = load ptr, ptr %next_stmt, align 8
  store ptr %52, ptr %stmt_ptr, align 8
  br label %label_2759
}

define ptr @resolve_imports__Struct_ASTNode_String(ptr %0, ptr %1) {
entry:
  %module = alloca ptr, align 8
  store ptr %0, ptr %module, align 8
  %base_dir = alloca ptr, align 8
  store ptr %1, ptr %base_dir, align 8
  %merged = alloca ptr, align 8
  %2 = call ptr @create_node__Enum_NodeKind(i32 0)
  store ptr %2, ptr %merged, align 8
  %3 = load ptr, ptr %merged, align 8
  %4 = load ptr, ptr %module, align 8
  %5 = load ptr, ptr %base_dir, align 8
  %6 = call ptr @merge_module_imports__Struct_ASTNode_Struct_ASTNode_String_String(ptr %3, ptr %4, ptr %5, ptr @.str.s1013)
  %7 = load ptr, ptr %merged, align 8
  ret ptr %7
}

define void @print_usage__Void() {
entry:
  call void @println(ptr @.str.s1014)
  call void @println(ptr @.str.s1015)
  call void @println(ptr @.str.s1016)
  call void @println(ptr @.str.s1017)
  call void @println(ptr @.str.s1018)
  call void @println(ptr @.str.s1019)
  call void @println(ptr @.str.s1020)
  call void @println(ptr @.str.s1021)
  call void @println(ptr @.str.s1022)
  ret void
}

define void @check_runtime_freshness__Void() {
entry:
  %installed = alloca ptr, align 8
  %current = alloca ptr, align 8
  %0 = call ptr @compiler_installed_runtime_hash()
  store ptr %0, ptr %installed, align 8
  %1 = load ptr, ptr %installed, align 8
  %2 = call i32 @str_equals(ptr %1, ptr @.str.s1023)
  %3 = icmp eq i32 %2, 1
  br i1 %3, label %label_2771, label %label_2773

label_2773:                                       ; preds = %entry
  %4 = call ptr @compiler_runtime_source_hash()
  store ptr %4, ptr %current, align 8
  %5 = load ptr, ptr %current, align 8
  %6 = call i32 @str_equals(ptr %5, ptr @.str.s1024)
  %7 = icmp eq i32 %6, 1
  br i1 %7, label %label_2774, label %label_2776

label_2771:                                       ; preds = %entry
  ret void

label_2776:                                       ; preds = %label_2773
  %8 = load ptr, ptr %installed, align 8
  %9 = load ptr, ptr %current, align 8
  %10 = call i32 @str_equals(ptr %8, ptr %9)
  %11 = icmp eq i32 %10, 1
  br i1 %11, label %label_2777, label %label_2779

label_2774:                                       ; preds = %label_2773
  ret void

label_2779:                                       ; preds = %label_2776
  call void @println(ptr @.str.s1025)
  call void @print(ptr @.str.s1026)
  %12 = load ptr, ptr %installed, align 8
  call void @println(ptr %12)
  call void @print(ptr @.str.s1027)
  %13 = load ptr, ptr %current, align 8
  call void @println(ptr %13)
  call void @println(ptr @.str.s1028)
  call void @println(ptr @.str.s1029)
  call void @exit(i32 1)
  ret void

label_2777:                                       ; preds = %label_2776
  ret void
}

define i32 @compile_source__String_String_Bool_Bool(ptr %0, ptr %1, i1 %2, i1 %3) {
entry:
  %path = alloca ptr, align 8
  store ptr %0, ptr %path, align 8
  %output_file = alloca ptr, align 8
  store ptr %1, ptr %output_file, align 8
  %run_after_build = alloca i1, align 1
  store i1 %2, ptr %run_after_build, align 1
  %bootstrap_mode = alloca i1, align 1
  store i1 %3, ptr %bootstrap_mode, align 1
  %out_file = alloca ptr, align 8
  %emit_ir_only = alloca i1, align 1
  %content = alloca ptr, align 8
  %lex = alloca ptr, align 8
  %head_token = alloca ptr, align 8
  %p = alloca ptr, align 8
  %ast_root = alloca ptr, align 8
  %base_dir = alloca ptr, align 8
  %merged_ast = alloca ptr, align 8
  %build_failed = alloca i32, align 4
  store ptr @.str.s1030, ptr %out_file, align 8
  store i1 false, ptr %emit_ir_only, align 1
  %4 = load i1, ptr %bootstrap_mode, align 1
  %5 = icmp eq i1 %4, false
  br i1 %5, label %label_2780, label %label_2782

label_2782:                                       ; preds = %label_2780, %entry
  %6 = load ptr, ptr %output_file, align 8
  %7 = call i32 @str_ends_with(ptr %6, ptr @.str.s1031)
  %8 = icmp eq i32 %7, 1
  br i1 %8, label %label_2783, label %label_2784

label_2780:                                       ; preds = %entry
  call void @check_runtime_freshness__Void()
  br label %label_2782

label_2784:                                       ; preds = %label_2782
  %9 = load ptr, ptr %path, align 8
  %10 = call ptr @compiler_temp_ir_path(ptr %9)
  store ptr %10, ptr %out_file, align 8
  br label %label_2785

label_2783:                                       ; preds = %label_2782
  %11 = load ptr, ptr %output_file, align 8
  store ptr %11, ptr %out_file, align 8
  store i1 true, ptr %emit_ir_only, align 1
  br label %label_2785

label_2785:                                       ; preds = %label_2784, %label_2783
  %12 = load ptr, ptr %path, align 8
  %13 = call ptr @read_file(ptr %12)
  store ptr %13, ptr %content, align 8
  %14 = load ptr, ptr %content, align 8
  %15 = call i32 @str_equals(ptr %14, ptr @.str.s1032)
  %16 = icmp eq i32 %15, 1
  br i1 %16, label %label_2786, label %label_2788

label_2788:                                       ; preds = %label_2785
  %17 = load ptr, ptr %content, align 8
  %18 = call ptr @create_lexer__String(ptr %17)
  store ptr %18, ptr %lex, align 8
  %19 = load ptr, ptr %lex, align 8
  %20 = call ptr @lex_all_tokens__Struct_Lexer(ptr %19)
  store ptr %20, ptr %head_token, align 8
  %21 = load ptr, ptr %head_token, align 8
  %22 = call ptr @parser_create__Struct_Token(ptr %21)
  store ptr %22, ptr %p, align 8
  %23 = load ptr, ptr %p, align 8
  %24 = call ptr @parse_module__Struct_Parser(ptr %23)
  store ptr %24, ptr %ast_root, align 8
  %25 = load ptr, ptr %path, align 8
  %26 = call ptr @get_directory(ptr %25)
  store ptr %26, ptr %base_dir, align 8
  %27 = load ptr, ptr %ast_root, align 8
  %28 = load ptr, ptr %base_dir, align 8
  %29 = call ptr @resolve_imports__Struct_ASTNode_String(ptr %27, ptr %28)
  store ptr %29, ptr %merged_ast, align 8
  %30 = load ptr, ptr %merged_ast, align 8
  call void @analyze_module__Struct_ASTNode(ptr %30)
  call void @ir_reset()
  %31 = load ptr, ptr %merged_ast, align 8
  call void @generate_module__Struct_ASTNode(ptr %31)
  %32 = load ptr, ptr %out_file, align 8
  %33 = call i32 @ir_write_file(ptr %32)
  %34 = icmp ne i32 %33, 0
  br i1 %34, label %label_2792, label %label_2794

label_2786:                                       ; preds = %label_2785
  call void @print(ptr @.str.s1033)
  %35 = load ptr, ptr %path, align 8
  call void @println(ptr %35)
  %36 = load i1, ptr %bootstrap_mode, align 1
  br i1 %36, label %label_2789, label %label_2791

label_2791:                                       ; preds = %label_2789, %label_2786
  ret i32 1

label_2789:                                       ; preds = %label_2786
  call void @println(ptr @.str.s1034)
  call void @println(ptr @.str.s1035)
  call void @println(ptr @.str.s1036)
  br label %label_2791

label_2794:                                       ; preds = %label_2788
  %37 = load i1, ptr %emit_ir_only, align 1
  br i1 %37, label %label_2795, label %label_2797

label_2792:                                       ; preds = %label_2788
  call void @println(ptr @.str.s1037)
  ret i32 1

label_2797:                                       ; preds = %label_2794
  store i32 0, ptr %build_failed, align 4
  %38 = load i1, ptr %bootstrap_mode, align 1
  br i1 %38, label %label_2798, label %label_2799

label_2795:                                       ; preds = %label_2794
  call void @print(ptr @.str.s1038)
  %39 = load ptr, ptr %out_file, align 8
  call void @println(ptr %39)
  ret i32 0

label_2799:                                       ; preds = %label_2797
  %40 = load ptr, ptr %out_file, align 8
  %41 = load ptr, ptr %output_file, align 8
  %42 = call i32 @compiler_build_executable(ptr %40, ptr %41)
  store i32 %42, ptr %build_failed, align 4
  br label %label_2800

label_2798:                                       ; preds = %label_2797
  %43 = load ptr, ptr %out_file, align 8
  %44 = load ptr, ptr %output_file, align 8
  %45 = call i32 @compiler_bootstrap_executable(ptr %43, ptr %44)
  store i32 %45, ptr %build_failed, align 4
  br label %label_2800

label_2800:                                       ; preds = %label_2799, %label_2798
  %46 = load i32, ptr %build_failed, align 4
  %47 = icmp ne i32 %46, 0
  br i1 %47, label %label_2801, label %label_2803

label_2803:                                       ; preds = %label_2800
  %48 = load ptr, ptr %out_file, align 8
  %49 = call i32 @delete_file(ptr %48)
  call void @print(ptr @.str.s1040)
  %50 = load ptr, ptr %output_file, align 8
  call void @println(ptr %50)
  %51 = load i1, ptr %run_after_build, align 1
  br i1 %51, label %label_2804, label %label_2806

label_2801:                                       ; preds = %label_2800
  %52 = load ptr, ptr %out_file, align 8
  %53 = call i32 @delete_file(ptr %52)
  call void @println(ptr @.str.s1039)
  ret i32 1

label_2806:                                       ; preds = %label_2809, %label_2803
  ret i32 0

label_2804:                                       ; preds = %label_2803
  %54 = load ptr, ptr %output_file, align 8
  %55 = call i32 @compiler_run_executable(ptr %54)
  %56 = icmp ne i32 %55, 0
  br i1 %56, label %label_2807, label %label_2809

label_2809:                                       ; preds = %label_2804
  br label %label_2806

label_2807:                                       ; preds = %label_2804
  call void @println(ptr @.str.s1041)
  ret i32 1
}

define i32 @main(i32 %0, ptr %1) {
entry:
  store i32 %0, ptr @prismio_argc, align 4
  store ptr %1, ptr @prismio_argv, align 8
  %path = alloca ptr, align 8
  %output_file = alloca ptr, align 8
  %command = alloca ptr, align 8
  %run_after_build = alloca i1, align 1
  %bootstrap_mode = alloca i1, align 1
  %arg_index = alloca i32, align 4
  %first = alloca ptr, align 8
  %source_hash = alloca ptr, align 8
  %candidate = alloca ptr, align 8
  %barg = alloca ptr, align 8
  %arg = alloca ptr, align 8
  store ptr @.str.s1042, ptr %path, align 8
  store ptr @.str.s1043, ptr %output_file, align 8
  store ptr @.str.s1044, ptr %command, align 8
  store i1 false, ptr %run_after_build, align 1
  store i1 false, ptr %bootstrap_mode, align 1
  store i32 0, ptr %arg_index, align 4
  %2 = call i32 @cli_arg_count()
  %3 = icmp sle i32 %2, 1
  br i1 %3, label %label_2810, label %label_2812

label_2812:                                       ; preds = %entry
  %4 = call ptr @cli_arg(i32 1)
  store ptr %4, ptr %first, align 8
  %5 = load ptr, ptr %first, align 8
  %6 = call i32 @str_equals(ptr %5, ptr @.str.s1045)
  %7 = icmp eq i32 %6, 1
  br i1 %7, label %label_2813, label %label_2815

label_2810:                                       ; preds = %entry
  call void @print_usage__Void()
  ret i32 1

label_2815:                                       ; preds = %label_2812
  %8 = load ptr, ptr %first, align 8
  %9 = call i32 @str_equals(ptr %8, ptr @.str.s1048)
  %10 = icmp eq i32 %9, 1
  br i1 %10, label %label_2819, label %label_2821

label_2813:                                       ; preds = %label_2812
  %11 = call ptr @compiler_runtime_source_hash()
  store ptr %11, ptr %source_hash, align 8
  %12 = load ptr, ptr %source_hash, align 8
  %13 = call i32 @str_equals(ptr %12, ptr @.str.s1046)
  %14 = icmp eq i32 %13, 1
  br i1 %14, label %label_2816, label %label_2818

label_2818:                                       ; preds = %label_2813
  %15 = load ptr, ptr %source_hash, align 8
  call void @println(ptr %15)
  ret i32 0

label_2816:                                       ; preds = %label_2813
  call void @println(ptr @.str.s1047)
  ret i32 1

label_2821:                                       ; preds = %label_2815
  %16 = load ptr, ptr %first, align 8
  %17 = call i32 @str_equals(ptr %16, ptr @.str.s1056)
  %18 = icmp eq i32 %17, 1
  br i1 %18, label %label_2839, label %label_2840

label_2819:                                       ; preds = %label_2815
  store ptr @.str.s1049, ptr %command, align 8
  store i1 true, ptr %bootstrap_mode, align 1
  store i1 false, ptr %run_after_build, align 1
  store ptr @.str.s1050, ptr %path, align 8
  store i32 2, ptr %arg_index, align 4
  %19 = call i32 @cli_arg_count()
  %20 = icmp sgt i32 %19, 2
  br i1 %20, label %label_2822, label %label_2824

label_2824:                                       ; preds = %label_2829, %label_2819
  %21 = load ptr, ptr %path, align 8
  %22 = call ptr @compiler_default_exe_path(ptr %21)
  store ptr %22, ptr %output_file, align 8
  br label %label_2830

label_2822:                                       ; preds = %label_2819
  %23 = call ptr @cli_arg(i32 2)
  store ptr %23, ptr %candidate, align 8
  %sc.154 = alloca i1, align 1
  %24 = load ptr, ptr %candidate, align 8
  %25 = call i32 @str_equals(ptr %24, ptr @.str.s1051)
  %26 = icmp eq i32 %25, 0
  store i1 %26, ptr %sc.154, align 1
  br i1 %26, label %label_2825, label %label_2826

label_2826:                                       ; preds = %label_2825, %label_2822
  %27 = load i1, ptr %sc.154, align 1
  br i1 %27, label %label_2827, label %label_2829

label_2825:                                       ; preds = %label_2822
  %28 = load ptr, ptr %candidate, align 8
  %29 = call i32 @str_equals(ptr %28, ptr @.str.s1052)
  %30 = icmp eq i32 %29, 0
  store i1 %30, ptr %sc.154, align 1
  br label %label_2826

label_2829:                                       ; preds = %label_2827, %label_2826
  br label %label_2824

label_2827:                                       ; preds = %label_2826
  %31 = load ptr, ptr %candidate, align 8
  store ptr %31, ptr %path, align 8
  store i32 3, ptr %arg_index, align 4
  br label %label_2829

label_2830:                                       ; preds = %label_2835, %label_2824
  %32 = load i32, ptr %arg_index, align 4
  %33 = call i32 @cli_arg_count()
  %34 = icmp slt i32 %32, %33
  br i1 %34, label %label_2831, label %label_2832

label_2832:                                       ; preds = %label_2830
  %35 = load ptr, ptr %path, align 8
  %36 = load ptr, ptr %output_file, align 8
  %37 = load i1, ptr %run_after_build, align 1
  %38 = load i1, ptr %bootstrap_mode, align 1
  %39 = call i32 @compile_source__String_String_Bool_Bool(ptr %35, ptr %36, i1 %37, i1 %38)
  ret i32 %39

label_2831:                                       ; preds = %label_2830
  %40 = load i32, ptr %arg_index, align 4
  %41 = call ptr @cli_arg(i32 %40)
  store ptr %41, ptr %barg, align 8
  %42 = load ptr, ptr %barg, align 8
  %43 = call i32 @str_equals(ptr %42, ptr @.str.s1053)
  %44 = icmp eq i32 %43, 1
  br i1 %44, label %label_2833, label %label_2834

label_2834:                                       ; preds = %label_2831
  call void @print(ptr @.str.s1055)
  %45 = load ptr, ptr %barg, align 8
  call void @println(ptr %45)
  call void @print_usage__Void()
  ret i32 1

label_2833:                                       ; preds = %label_2831
  %46 = load i32, ptr %arg_index, align 4
  %47 = add i32 %46, 1
  %48 = call i32 @cli_arg_count()
  %49 = icmp sge i32 %47, %48
  br i1 %49, label %label_2836, label %label_2838

label_2838:                                       ; preds = %label_2833
  %50 = load i32, ptr %arg_index, align 4
  %51 = add i32 %50, 1
  %52 = call ptr @cli_arg(i32 %51)
  store ptr %52, ptr %output_file, align 8
  %53 = load i32, ptr %arg_index, align 4
  %54 = add i32 %53, 2
  store i32 %54, ptr %arg_index, align 4
  br label %label_2835

label_2836:                                       ; preds = %label_2833
  call void @println(ptr @.str.s1054)
  ret i32 1

label_2835:                                       ; preds = %label_2838
  br label %label_2830

label_2840:                                       ; preds = %label_2821
  %55 = load ptr, ptr %first, align 8
  %56 = call i32 @str_equals(ptr %55, ptr @.str.s1062)
  %57 = icmp eq i32 %56, 1
  br i1 %57, label %label_2850, label %label_2851

label_2839:                                       ; preds = %label_2821
  store ptr @.str.s1057, ptr %command, align 8
  store i1 false, ptr %run_after_build, align 1
  store i32 3, ptr %arg_index, align 4
  %58 = call i32 @cli_arg_count()
  %59 = icmp sle i32 %58, 2
  br i1 %59, label %label_2842, label %label_2844

label_2844:                                       ; preds = %label_2839
  %60 = call ptr @cli_arg(i32 2)
  store ptr %60, ptr %path, align 8
  %sc.155 = alloca i1, align 1
  %61 = load ptr, ptr %path, align 8
  %62 = call i32 @str_equals(ptr %61, ptr @.str.s1059)
  %63 = icmp eq i32 %62, 1
  store i1 %63, ptr %sc.155, align 1
  br i1 %63, label %label_2846, label %label_2845

label_2842:                                       ; preds = %label_2839
  call void @println(ptr @.str.s1058)
  call void @print_usage__Void()
  ret i32 1

label_2845:                                       ; preds = %label_2844
  %64 = load ptr, ptr %path, align 8
  %65 = call i32 @str_equals(ptr %64, ptr @.str.s1060)
  %66 = icmp eq i32 %65, 1
  store i1 %66, ptr %sc.155, align 1
  br label %label_2846

label_2846:                                       ; preds = %label_2845, %label_2844
  %67 = load i1, ptr %sc.155, align 1
  br i1 %67, label %label_2847, label %label_2849

label_2849:                                       ; preds = %label_2846
  br label %label_2841

label_2847:                                       ; preds = %label_2846
  call void @println(ptr @.str.s1061)
  ret i32 1

label_2841:                                       ; preds = %label_2852, %label_2849
  %68 = load ptr, ptr %path, align 8
  %69 = call ptr @compiler_default_exe_path(ptr %68)
  store ptr %69, ptr %output_file, align 8
  br label %label_2861

label_2851:                                       ; preds = %label_2840
  store ptr @.str.s1068, ptr %command, align 8
  store i1 false, ptr %run_after_build, align 1
  %70 = load ptr, ptr %first, align 8
  store ptr %70, ptr %path, align 8
  store i32 2, ptr %arg_index, align 4
  br label %label_2852

label_2850:                                       ; preds = %label_2840
  store ptr @.str.s1063, ptr %command, align 8
  store i1 true, ptr %run_after_build, align 1
  store i32 3, ptr %arg_index, align 4
  %71 = call i32 @cli_arg_count()
  %72 = icmp sle i32 %71, 2
  br i1 %72, label %label_2853, label %label_2855

label_2855:                                       ; preds = %label_2850
  %73 = call ptr @cli_arg(i32 2)
  store ptr %73, ptr %path, align 8
  %sc.156 = alloca i1, align 1
  %74 = load ptr, ptr %path, align 8
  %75 = call i32 @str_equals(ptr %74, ptr @.str.s1065)
  %76 = icmp eq i32 %75, 1
  store i1 %76, ptr %sc.156, align 1
  br i1 %76, label %label_2857, label %label_2856

label_2853:                                       ; preds = %label_2850
  call void @println(ptr @.str.s1064)
  call void @print_usage__Void()
  ret i32 1

label_2856:                                       ; preds = %label_2855
  %77 = load ptr, ptr %path, align 8
  %78 = call i32 @str_equals(ptr %77, ptr @.str.s1066)
  %79 = icmp eq i32 %78, 1
  store i1 %79, ptr %sc.156, align 1
  br label %label_2857

label_2857:                                       ; preds = %label_2856, %label_2855
  %80 = load i1, ptr %sc.156, align 1
  br i1 %80, label %label_2858, label %label_2860

label_2860:                                       ; preds = %label_2857
  br label %label_2852

label_2858:                                       ; preds = %label_2857
  call void @println(ptr @.str.s1067)
  ret i32 1

label_2852:                                       ; preds = %label_2851, %label_2860
  br label %label_2841

label_2861:                                       ; preds = %label_2866, %label_2841
  %81 = load i32, ptr %arg_index, align 4
  %82 = call i32 @cli_arg_count()
  %83 = icmp slt i32 %81, %82
  br i1 %83, label %label_2862, label %label_2863

label_2863:                                       ; preds = %label_2861
  %84 = load ptr, ptr %path, align 8
  %85 = load ptr, ptr %output_file, align 8
  %86 = load i1, ptr %run_after_build, align 1
  %87 = load i1, ptr %bootstrap_mode, align 1
  %88 = call i32 @compile_source__String_String_Bool_Bool(ptr %84, ptr %85, i1 %86, i1 %87)
  ret i32 %88

label_2862:                                       ; preds = %label_2861
  %89 = load i32, ptr %arg_index, align 4
  %90 = call ptr @cli_arg(i32 %89)
  store ptr %90, ptr %arg, align 8
  %91 = load ptr, ptr %arg, align 8
  %92 = call i32 @str_equals(ptr %91, ptr @.str.s1069)
  %93 = icmp eq i32 %92, 1
  br i1 %93, label %label_2864, label %label_2865

label_2865:                                       ; preds = %label_2862
  %94 = load ptr, ptr %arg, align 8
  %95 = call i32 @str_equals(ptr %94, ptr @.str.s1071)
  %96 = icmp eq i32 %95, 1
  br i1 %96, label %label_2870, label %label_2871

label_2864:                                       ; preds = %label_2862
  %97 = load i32, ptr %arg_index, align 4
  %98 = add i32 %97, 1
  %99 = call i32 @cli_arg_count()
  %100 = icmp sge i32 %98, %99
  br i1 %100, label %label_2867, label %label_2869

label_2869:                                       ; preds = %label_2864
  %101 = load i32, ptr %arg_index, align 4
  %102 = add i32 %101, 1
  %103 = call ptr @cli_arg(i32 %102)
  store ptr %103, ptr %output_file, align 8
  %104 = load i32, ptr %arg_index, align 4
  %105 = add i32 %104, 2
  store i32 %105, ptr %arg_index, align 4
  br label %label_2866

label_2867:                                       ; preds = %label_2864
  call void @println(ptr @.str.s1070)
  ret i32 1

label_2866:                                       ; preds = %label_2872, %label_2869
  br label %label_2861

label_2871:                                       ; preds = %label_2865
  %sc.157 = alloca i1, align 1
  %106 = load ptr, ptr %arg, align 8
  %107 = call i32 @str_equals(ptr %106, ptr @.str.s1074)
  %108 = icmp eq i32 %107, 1
  store i1 %108, ptr %sc.157, align 1
  br i1 %108, label %label_2880, label %label_2879

label_2870:                                       ; preds = %label_2865
  %109 = load i32, ptr %arg_index, align 4
  %110 = add i32 %109, 1
  %111 = call i32 @cli_arg_count()
  %112 = icmp sge i32 %110, %111
  br i1 %112, label %label_2873, label %label_2875

label_2875:                                       ; preds = %label_2870
  %113 = load i32, ptr %arg_index, align 4
  %114 = add i32 %113, 1
  %115 = call ptr @cli_arg(i32 %114)
  %116 = call i32 @str_equals(ptr %115, ptr @.str.s1073)
  %117 = icmp eq i32 %116, 1
  br i1 %117, label %label_2876, label %label_2878

label_2873:                                       ; preds = %label_2870
  call void @println(ptr @.str.s1072)
  ret i32 1

label_2878:                                       ; preds = %label_2876, %label_2875
  %118 = load i32, ptr %arg_index, align 4
  %119 = add i32 %118, 2
  store i32 %119, ptr %arg_index, align 4
  br label %label_2872

label_2876:                                       ; preds = %label_2875
  call void @ir_set_target_wasm__Bool(i1 true)
  br label %label_2878

label_2872:                                       ; preds = %label_2888, %label_2878
  br label %label_2866

label_2879:                                       ; preds = %label_2871
  %120 = load ptr, ptr %arg, align 8
  %121 = call i32 @str_equals(ptr %120, ptr @.str.s1075)
  %122 = icmp eq i32 %121, 1
  store i1 %122, ptr %sc.157, align 1
  br label %label_2880

label_2880:                                       ; preds = %label_2879, %label_2871
  %123 = load i1, ptr %sc.157, align 1
  br i1 %123, label %label_2881, label %label_2883

label_2883:                                       ; preds = %label_2880
  %sc.158 = alloca i1, align 1
  %124 = load ptr, ptr %command, align 8
  %125 = call i32 @str_equals(ptr %124, ptr @.str.s1077)
  %126 = icmp eq i32 %125, 1
  store i1 %126, ptr %sc.158, align 1
  br i1 %126, label %label_2884, label %label_2885

label_2881:                                       ; preds = %label_2880
  call void @println(ptr @.str.s1076)
  ret i32 1

label_2885:                                       ; preds = %label_2884, %label_2883
  %127 = load i1, ptr %sc.158, align 1
  br i1 %127, label %label_2886, label %label_2887

label_2884:                                       ; preds = %label_2883
  %128 = load i32, ptr %arg_index, align 4
  %129 = icmp eq i32 %128, 2
  store i1 %129, ptr %sc.158, align 1
  br label %label_2885

label_2887:                                       ; preds = %label_2885
  call void @print(ptr @.str.s1078)
  %130 = load ptr, ptr %arg, align 8
  call void @println(ptr %130)
  call void @print_usage__Void()
  ret i32 1

label_2886:                                       ; preds = %label_2885
  %131 = load ptr, ptr %arg, align 8
  store ptr %131, ptr %output_file, align 8
  %132 = load i32, ptr %arg_index, align 4
  %133 = add i32 %132, 1
  store i32 %133, ptr %arg_index, align 4
  br label %label_2888

label_2888:                                       ; preds = %label_2886
  br label %label_2872
}
