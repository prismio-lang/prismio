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
@.str.s539 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s540 = private unnamed_addr constant [4 x i8] c"ptr\00"
@.str.s541 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s542 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s543 = private unnamed_addr constant [4 x i8] c"i32\00"
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
@.str.s639 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s640 = private unnamed_addr constant [4 x i8] c"i32\00"
@.str.s641 = private unnamed_addr constant [4 x i8] c"i32\00"
@.str.s642 = private unnamed_addr constant [4 x i8] c"i32\00"
@.str.s643 = private unnamed_addr constant [4 x i8] c"i32\00"
@.str.s644 = private unnamed_addr constant [4 x i8] c"i32\00"
@.str.s645 = private unnamed_addr constant [4 x i8] c"i32\00"
@.str.s646 = private unnamed_addr constant [4 x i8] c"i32\00"
@.str.s647 = private unnamed_addr constant [2 x i8] c"1\00"
@.str.s648 = private unnamed_addr constant [4 x i8] c"i32\00"
@.str.s649 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s650 = private unnamed_addr constant [2 x i8] c"_\00"
@.str.s651 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s652 = private unnamed_addr constant [5 x i8] c"void\00"
@.str.s653 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s654 = private unnamed_addr constant [5 x i8] c"main\00"
@.str.s655 = private unnamed_addr constant [4 x i8] c"i32\00"
@.str.s656 = private unnamed_addr constant [4 x i8] c"i32\00"
@.str.s657 = private unnamed_addr constant [7 x i8] c"p_argc\00"
@.str.s658 = private unnamed_addr constant [4 x i8] c"ptr\00"
@.str.s659 = private unnamed_addr constant [7 x i8] c"p_argv\00"
@.str.s660 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s661 = private unnamed_addr constant [3 x i8] c"p_\00"
@.str.s662 = private unnamed_addr constant [4 x i8] c"i32\00"
@.str.s663 = private unnamed_addr constant [8 x i8] c"%p_argc\00"
@.str.s664 = private unnamed_addr constant [13 x i8] c"prismio_argc\00"
@.str.s665 = private unnamed_addr constant [4 x i8] c"ptr\00"
@.str.s666 = private unnamed_addr constant [8 x i8] c"%p_argv\00"
@.str.s667 = private unnamed_addr constant [13 x i8] c"prismio_argv\00"
@.str.s668 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s669 = private unnamed_addr constant [4 x i8] c"%p_\00"
@.str.s670 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s671 = private unnamed_addr constant [5 x i8] c"void\00"
@.str.s672 = private unnamed_addr constant [4 x i8] c"i32\00"
@.str.s673 = private unnamed_addr constant [2 x i8] c"0\00"
@.str.s674 = private unnamed_addr constant [2 x i8] c"0\00"
@.str.s675 = private unnamed_addr constant [7 x i8] c".str.s\00"
@.str.s676 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s677 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s678 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s679 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s680 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s681 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s682 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s683 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s684 = private unnamed_addr constant [1 x i8] zeroinitializer
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
@.str.s697 = private unnamed_addr constant [19 x i8] c"self_hosted_module\00"
@.str.s698 = private unnamed_addr constant [19 x i8] c"self_hosted_module\00"
@.str.s699 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s700 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s701 = private unnamed_addr constant [13 x i8] c"prismio_argc\00"
@.str.s702 = private unnamed_addr constant [4 x i8] c"i32\00"
@.str.s703 = private unnamed_addr constant [2 x i8] c"0\00"
@.str.s704 = private unnamed_addr constant [13 x i8] c"prismio_argv\00"
@.str.s705 = private unnamed_addr constant [4 x i8] c"ptr\00"
@.str.s706 = private unnamed_addr constant [5 x i8] c"null\00"
@.str.s707 = private unnamed_addr constant [7 x i8] c"malloc\00"
@.str.s708 = private unnamed_addr constant [4 x i8] c"ptr\00"
@.str.s709 = private unnamed_addr constant [5 x i8] c"free\00"
@.str.s710 = private unnamed_addr constant [5 x i8] c"void\00"
@.str.s711 = private unnamed_addr constant [4 x i8] c"ptr\00"
@.str.s712 = private unnamed_addr constant [9 x i8] c"list_new\00"
@.str.s713 = private unnamed_addr constant [4 x i8] c"ptr\00"
@.str.s714 = private unnamed_addr constant [10 x i8] c"list_push\00"
@.str.s715 = private unnamed_addr constant [5 x i8] c"void\00"
@.str.s716 = private unnamed_addr constant [4 x i8] c"ptr\00"
@.str.s717 = private unnamed_addr constant [4 x i8] c"ptr\00"
@.str.s718 = private unnamed_addr constant [9 x i8] c"list_get\00"
@.str.s719 = private unnamed_addr constant [4 x i8] c"ptr\00"
@.str.s720 = private unnamed_addr constant [4 x i8] c"ptr\00"
@.str.s721 = private unnamed_addr constant [4 x i8] c"i32\00"
@.str.s722 = private unnamed_addr constant [9 x i8] c"list_set\00"
@.str.s723 = private unnamed_addr constant [5 x i8] c"void\00"
@.str.s724 = private unnamed_addr constant [4 x i8] c"ptr\00"
@.str.s725 = private unnamed_addr constant [4 x i8] c"i32\00"
@.str.s726 = private unnamed_addr constant [4 x i8] c"ptr\00"
@.str.s727 = private unnamed_addr constant [9 x i8] c"list_len\00"
@.str.s728 = private unnamed_addr constant [4 x i8] c"i32\00"
@.str.s729 = private unnamed_addr constant [4 x i8] c"ptr\00"
@.str.s730 = private unnamed_addr constant [8 x i8] c"println\00"
@.str.s731 = private unnamed_addr constant [5 x i8] c"void\00"
@.str.s732 = private unnamed_addr constant [4 x i8] c"ptr\00"
@.str.s733 = private unnamed_addr constant [6 x i8] c"print\00"
@.str.s734 = private unnamed_addr constant [5 x i8] c"void\00"
@.str.s735 = private unnamed_addr constant [4 x i8] c"ptr\00"
@.str.s736 = private unnamed_addr constant [12 x i8] c"println_int\00"
@.str.s737 = private unnamed_addr constant [5 x i8] c"void\00"
@.str.s738 = private unnamed_addr constant [4 x i8] c"i32\00"
@.str.s739 = private unnamed_addr constant [10 x i8] c"print_int\00"
@.str.s740 = private unnamed_addr constant [5 x i8] c"void\00"
@.str.s741 = private unnamed_addr constant [4 x i8] c"i32\00"
@.str.s742 = private unnamed_addr constant [14 x i8] c"println_float\00"
@.str.s743 = private unnamed_addr constant [5 x i8] c"void\00"
@.str.s744 = private unnamed_addr constant [7 x i8] c"double\00"
@.str.s745 = private unnamed_addr constant [12 x i8] c"print_float\00"
@.str.s746 = private unnamed_addr constant [5 x i8] c"void\00"
@.str.s747 = private unnamed_addr constant [7 x i8] c"double\00"
@.str.s748 = private unnamed_addr constant [13 x i8] c"println_bool\00"
@.str.s749 = private unnamed_addr constant [5 x i8] c"void\00"
@.str.s750 = private unnamed_addr constant [4 x i8] c"i32\00"
@.str.s751 = private unnamed_addr constant [11 x i8] c"print_bool\00"
@.str.s752 = private unnamed_addr constant [5 x i8] c"void\00"
@.str.s753 = private unnamed_addr constant [4 x i8] c"i32\00"
@.str.s754 = private unnamed_addr constant [13 x i8] c"println_char\00"
@.str.s755 = private unnamed_addr constant [5 x i8] c"void\00"
@.str.s756 = private unnamed_addr constant [3 x i8] c"i8\00"
@.str.s757 = private unnamed_addr constant [11 x i8] c"print_char\00"
@.str.s758 = private unnamed_addr constant [5 x i8] c"void\00"
@.str.s759 = private unnamed_addr constant [3 x i8] c"i8\00"
@.str.s760 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s761 = private unnamed_addr constant [2 x i8] c"0\00"
@.str.s762 = private unnamed_addr constant [4 x i8] c"i32\00"
@.str.s763 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s764 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s765 = private unnamed_addr constant [2 x i8] c"@\00"
@.str.s766 = private unnamed_addr constant [15 x i8] c"error: global \00"
@.str.s767 = private unnamed_addr constant [33 x i8] c" requires a constant initializer\00"
@.str.s768 = private unnamed_addr constant [5 x i8] c"main\00"
@.str.s769 = private unnamed_addr constant [4 x i8] c"i32\00"
@.str.s770 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s771 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s772 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s773 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s774 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s775 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s776 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s777 = private unnamed_addr constant [5 x i8] c"$fn$\00"
@.str.s778 = private unnamed_addr constant [5 x i8] c"Void\00"
@.str.s779 = private unnamed_addr constant [6 x i8] c"Float\00"
@.str.s780 = private unnamed_addr constant [5 x i8] c"Bool\00"
@.str.s781 = private unnamed_addr constant [5 x i8] c"Char\00"
@.str.s782 = private unnamed_addr constant [7 x i8] c"String\00"
@.str.s783 = private unnamed_addr constant [4 x i8] c"Ptr\00"
@.str.s784 = private unnamed_addr constant [8 x i8] c"Struct_\00"
@.str.s785 = private unnamed_addr constant [6 x i8] c"Enum_\00"
@.str.s786 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s787 = private unnamed_addr constant [7 x i8] c"Array_\00"
@.str.s788 = private unnamed_addr constant [14 x i8] c"Array_Invalid\00"
@.str.s789 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s790 = private unnamed_addr constant [6 x i8] c"List_\00"
@.str.s791 = private unnamed_addr constant [13 x i8] c"List_Invalid\00"
@.str.s792 = private unnamed_addr constant [8 x i8] c"Invalid\00"
@.str.s793 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s794 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s795 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s796 = private unnamed_addr constant [2 x i8] c"_\00"
@.str.s797 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s798 = private unnamed_addr constant [5 x i8] c"Void\00"
@.str.s799 = private unnamed_addr constant [5 x i8] c"main\00"
@.str.s800 = private unnamed_addr constant [5 x i8] c"main\00"
@.str.s801 = private unnamed_addr constant [3 x i8] c"__\00"
@.str.s802 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s803 = private unnamed_addr constant [13 x i8] c"type error: \00"
@.str.s804 = private unnamed_addr constant [13 x i8] c"type error: \00"
@.str.s805 = private unnamed_addr constant [12 x i8] c": expected \00"
@.str.s806 = private unnamed_addr constant [7 x i8] c", got \00"
@.str.s807 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s808 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s809 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s810 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s811 = private unnamed_addr constant [4 x i8] c"Int\00"
@.str.s812 = private unnamed_addr constant [6 x i8] c"Float\00"
@.str.s813 = private unnamed_addr constant [5 x i8] c"Bool\00"
@.str.s814 = private unnamed_addr constant [7 x i8] c"String\00"
@.str.s815 = private unnamed_addr constant [5 x i8] c"Char\00"
@.str.s816 = private unnamed_addr constant [3 x i8] c"I8\00"
@.str.s817 = private unnamed_addr constant [4 x i8] c"I16\00"
@.str.s818 = private unnamed_addr constant [4 x i8] c"I64\00"
@.str.s819 = private unnamed_addr constant [6 x i8] c"Isize\00"
@.str.s820 = private unnamed_addr constant [3 x i8] c"U8\00"
@.str.s821 = private unnamed_addr constant [4 x i8] c"U16\00"
@.str.s822 = private unnamed_addr constant [4 x i8] c"U32\00"
@.str.s823 = private unnamed_addr constant [4 x i8] c"U64\00"
@.str.s824 = private unnamed_addr constant [6 x i8] c"Usize\00"
@.str.s825 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s826 = private unnamed_addr constant [14 x i8] c"unknown type \00"
@.str.s827 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s828 = private unnamed_addr constant [4 x i8] c"Int\00"
@.str.s829 = private unnamed_addr constant [36 x i8] c"cannot move out of borrowed value: \00"
@.str.s830 = private unnamed_addr constant [54 x i8] c"value moved inside a loop, so the move would repeat: \00"
@.str.s831 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s832 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s833 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s834 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s835 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s836 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s837 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s838 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s839 = private unnamed_addr constant [30 x i8] c"ambiguous overloaded call to \00"
@.str.s840 = private unnamed_addr constant [26 x i8] c"no matching overload for \00"
@.str.s841 = private unnamed_addr constant [18 x i8] c"unknown function \00"
@.str.s842 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s843 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s844 = private unnamed_addr constant [15 x i8] c"unknown field \00"
@.str.s845 = private unnamed_addr constant [5 x i8] c" on \00"
@.str.s846 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s847 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s848 = private unnamed_addr constant [6 x i8] c"print\00"
@.str.s849 = private unnamed_addr constant [8 x i8] c"println\00"
@.str.s850 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s851 = private unnamed_addr constant [22 x i8] c" expects one argument\00"
@.str.s852 = private unnamed_addr constant [10 x i8] c"print_int\00"
@.str.s853 = private unnamed_addr constant [12 x i8] c"println_int\00"
@.str.s854 = private unnamed_addr constant [12 x i8] c"print_float\00"
@.str.s855 = private unnamed_addr constant [14 x i8] c"println_float\00"
@.str.s856 = private unnamed_addr constant [11 x i8] c"print_bool\00"
@.str.s857 = private unnamed_addr constant [13 x i8] c"println_bool\00"
@.str.s858 = private unnamed_addr constant [11 x i8] c"print_char\00"
@.str.s859 = private unnamed_addr constant [13 x i8] c"println_char\00"
@.str.s860 = private unnamed_addr constant [5 x i8] c"drop\00"
@.str.s861 = private unnamed_addr constant [9 x i8] c"list_new\00"
@.str.s862 = private unnamed_addr constant [9 x i8] c"list_len\00"
@.str.s863 = private unnamed_addr constant [10 x i8] c"list_push\00"
@.str.s864 = private unnamed_addr constant [9 x i8] c"list_set\00"
@.str.s865 = private unnamed_addr constant [9 x i8] c"list_get\00"
@.str.s866 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s867 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s868 = private unnamed_addr constant [6 x i8] c"print\00"
@.str.s869 = private unnamed_addr constant [8 x i8] c"println\00"
@.str.s870 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s871 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s872 = private unnamed_addr constant [22 x i8] c" expects one argument\00"
@.str.s873 = private unnamed_addr constant [5 x i8] c"drop\00"
@.str.s874 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s875 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s876 = private unnamed_addr constant [26 x i8] c"drop expects one argument\00"
@.str.s877 = private unnamed_addr constant [41 x i8] c"drop requires an owned (move-only) value\00"
@.str.s878 = private unnamed_addr constant [9 x i8] c"list_new\00"
@.str.s879 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s880 = private unnamed_addr constant [28 x i8] c"list_new takes no arguments\00"
@.str.s881 = private unnamed_addr constant [9 x i8] c"list_len\00"
@.str.s882 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s883 = private unnamed_addr constant [24 x i8] c"list_len expects a List\00"
@.str.s884 = private unnamed_addr constant [24 x i8] c"list_len expects a List\00"
@.str.s885 = private unnamed_addr constant [9 x i8] c"list_get\00"
@.str.s886 = private unnamed_addr constant [24 x i8] c"list_get expects a List\00"
@.str.s887 = private unnamed_addr constant [15 x i8] c"list_get index\00"
@.str.s888 = private unnamed_addr constant [10 x i8] c"list_push\00"
@.str.s889 = private unnamed_addr constant [25 x i8] c"list_push expects a List\00"
@.str.s890 = private unnamed_addr constant [16 x i8] c"list_push value\00"
@.str.s891 = private unnamed_addr constant [9 x i8] c"list_set\00"
@.str.s892 = private unnamed_addr constant [24 x i8] c"list_set expects a List\00"
@.str.s893 = private unnamed_addr constant [15 x i8] c"list_set index\00"
@.str.s894 = private unnamed_addr constant [15 x i8] c"list_set value\00"
@.str.s895 = private unnamed_addr constant [10 x i8] c"print_int\00"
@.str.s896 = private unnamed_addr constant [12 x i8] c"println_int\00"
@.str.s897 = private unnamed_addr constant [12 x i8] c"print_float\00"
@.str.s898 = private unnamed_addr constant [14 x i8] c"println_float\00"
@.str.s899 = private unnamed_addr constant [11 x i8] c"print_bool\00"
@.str.s900 = private unnamed_addr constant [13 x i8] c"println_bool\00"
@.str.s901 = private unnamed_addr constant [11 x i8] c"print_char\00"
@.str.s902 = private unnamed_addr constant [13 x i8] c"println_char\00"
@.str.s903 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s904 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s905 = private unnamed_addr constant [22 x i8] c" expects one argument\00"
@.str.s906 = private unnamed_addr constant [10 x i8] c" argument\00"
@.str.s907 = private unnamed_addr constant [20 x i8] c"unknown identifier \00"
@.str.s908 = private unnamed_addr constant [21 x i8] c"use of moved value: \00"
@.str.s909 = private unnamed_addr constant [62 x i8] c"cannot cast to Bool; compare explicitly instead, as in x != 0\00"
@.str.s910 = private unnamed_addr constant [5 x i8] c"cast\00"
@.str.s911 = private unnamed_addr constant [2 x i8] c"!\00"
@.str.s912 = private unnamed_addr constant [11 x i8] c"operator !\00"
@.str.s913 = private unnamed_addr constant [2 x i8] c"~\00"
@.str.s914 = private unnamed_addr constant [36 x i8] c"unary ~ requires an integer operand\00"
@.str.s915 = private unnamed_addr constant [2 x i8] c"-\00"
@.str.s916 = private unnamed_addr constant [35 x i8] c"unary - requires a numeric operand\00"
@.str.s917 = private unnamed_addr constant [39 x i8] c"cannot apply unary - to unsigned type \00"
@.str.s918 = private unnamed_addr constant [24 x i8] c"unknown unary operator \00"
@.str.s919 = private unnamed_addr constant [4 x i8] c"and\00"
@.str.s920 = private unnamed_addr constant [3 x i8] c"or\00"
@.str.s921 = private unnamed_addr constant [30 x i8] c"boolean operator left operand\00"
@.str.s922 = private unnamed_addr constant [31 x i8] c"boolean operator right operand\00"
@.str.s923 = private unnamed_addr constant [2 x i8] c"+\00"
@.str.s924 = private unnamed_addr constant [2 x i8] c"-\00"
@.str.s925 = private unnamed_addr constant [2 x i8] c"*\00"
@.str.s926 = private unnamed_addr constant [2 x i8] c"/\00"
@.str.s927 = private unnamed_addr constant [37 x i8] c"operator requires numeric operands: \00"
@.str.s928 = private unnamed_addr constant [10 x i8] c"operator \00"
@.str.s929 = private unnamed_addr constant [2 x i8] c"%\00"
@.str.s930 = private unnamed_addr constant [33 x i8] c"modulo requires integer operands\00"
@.str.s931 = private unnamed_addr constant [11 x i8] c"operator %\00"
@.str.s932 = private unnamed_addr constant [2 x i8] c"&\00"
@.str.s933 = private unnamed_addr constant [2 x i8] c"|\00"
@.str.s934 = private unnamed_addr constant [2 x i8] c"^\00"
@.str.s935 = private unnamed_addr constant [45 x i8] c"bitwise operator requires integer operands: \00"
@.str.s936 = private unnamed_addr constant [10 x i8] c"operator \00"
@.str.s937 = private unnamed_addr constant [3 x i8] c"<<\00"
@.str.s938 = private unnamed_addr constant [3 x i8] c">>\00"
@.str.s939 = private unnamed_addr constant [41 x i8] c"shift requires an integer left operand: \00"
@.str.s940 = private unnamed_addr constant [34 x i8] c"shift amount must be an integer: \00"
@.str.s941 = private unnamed_addr constant [3 x i8] c"==\00"
@.str.s942 = private unnamed_addr constant [3 x i8] c"!=\00"
@.str.s943 = private unnamed_addr constant [2 x i8] c"<\00"
@.str.s944 = private unnamed_addr constant [3 x i8] c"<=\00"
@.str.s945 = private unnamed_addr constant [2 x i8] c">\00"
@.str.s946 = private unnamed_addr constant [3 x i8] c">=\00"
@.str.s947 = private unnamed_addr constant [65 x i8] c"cannot compare String values directly; use str_equals(a, b) == 1\00"
@.str.s948 = private unnamed_addr constant [60 x i8] c"cannot compare struct values directly; compare their fields\00"
@.str.s949 = private unnamed_addr constant [12 x i8] c"comparison \00"
@.str.s950 = private unnamed_addr constant [18 x i8] c"unknown operator \00"
@.str.s951 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s952 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s953 = private unnamed_addr constant [10 x i8] c" argument\00"
@.str.s954 = private unnamed_addr constant [5 x i8] c"sink\00"
@.str.s955 = private unnamed_addr constant [5 x i8] c"main\00"
@.str.s956 = private unnamed_addr constant [38 x i8] c"member access requires a struct value\00"
@.str.s957 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s958 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s959 = private unnamed_addr constant [22 x i8] c"array literal element\00"
@.str.s960 = private unnamed_addr constant [12 x i8] c"array index\00"
@.str.s961 = private unnamed_addr constant [27 x i8] c"indexing requires an array\00"
@.str.s962 = private unnamed_addr constant [16 x i8] c"unknown struct \00"
@.str.s963 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s964 = private unnamed_addr constant [14 x i8] c"struct field \00"
@.str.s965 = private unnamed_addr constant [23 x i8] c"unsupported expression\00"
@.str.s966 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s967 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s968 = private unnamed_addr constant [17 x i8] c"initializer for \00"
@.str.s969 = private unnamed_addr constant [23 x i8] c"cannot infer type for \00"
@.str.s970 = private unnamed_addr constant [37 x i8] c"cannot assign to immutable binding: \00"
@.str.s971 = private unnamed_addr constant [28 x i8] c"; declare it with `let mut`\00"
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
@.str.s987 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s988 = private unnamed_addr constant [70 x i8] c"unreachable code: control cannot continue past the previous statement\00"
@.str.s989 = private unnamed_addr constant [5 x i8] c"main\00"
@.str.s990 = private unnamed_addr constant [29 x i8] c"duplicate function overload \00"
@.str.s991 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s992 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s993 = private unnamed_addr constant [24 x i8] c"initializer for global \00"
@.str.s994 = private unnamed_addr constant [30 x i8] c"cannot infer type for global \00"
@.str.s995 = private unnamed_addr constant [5 x i8] c"main\00"
@.str.s996 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s997 = private unnamed_addr constant [6 x i8] c"inout\00"
@.str.s998 = private unnamed_addr constant [52 x i8] c"inout parameter must be a struct (reference) type: \00"
@.str.s999 = private unnamed_addr constant [5 x i8] c"sink\00"
@.str.s1000 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s1001 = private unnamed_addr constant [22 x i8] c"type error: function \00"
@.str.s1002 = private unnamed_addr constant [14 x i8] c" must return \00"
@.str.s1003 = private unnamed_addr constant [15 x i8] c" on every path\00"
@.str.s1004 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s1005 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s1006 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s1007 = private unnamed_addr constant [6 x i8] c"0.1.0\00"
@PRISMIO_VERSION = global ptr @.str.s1007
@.str.s1008 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s1009 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s1010 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s1011 = private unnamed_addr constant [5 x i8] c".psm\00"
@.str.s1012 = private unnamed_addr constant [2 x i8] c".\00"
@.str.s1013 = private unnamed_addr constant [2 x i8] c"|\00"
@.str.s1014 = private unnamed_addr constant [2 x i8] c"|\00"
@.str.s1015 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s1016 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s1017 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s1018 = private unnamed_addr constant [25 x i8] c"ERROR: Could not import \00"
@.str.s1019 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s1020 = private unnamed_addr constant [7 x i8] c"Usage:\00"
@.str.s1021 = private unnamed_addr constant [45 x i8] c"  prismio build <source.psm> [-o output.exe]\00"
@.str.s1022 = private unnamed_addr constant [43 x i8] c"  prismio run <source.psm> [-o output.exe]\00"
@.str.s1023 = private unnamed_addr constant [49 x i8] c"  prismio bootstrap [source.psm] [-o output.exe]\00"
@.str.s1024 = private unnamed_addr constant [23 x i8] c"  prismio runtime-hash\00"
@.str.s1025 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s1026 = private unnamed_addr constant [59 x i8] c"build/run link against the installed Prismio runtime only.\00"
@.str.s1027 = private unnamed_addr constant [66 x i8] c"bootstrap builds the compiler itself from the repository sources,\00"
@.str.s1028 = private unnamed_addr constant [71 x i8] c"linking the compiler backend as well and ignoring installed libraries.\00"
@.str.s1029 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s1030 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s1031 = private unnamed_addr constant [55 x i8] c"ERROR: the installed Prismio runtime library is stale.\00"
@.str.s1032 = private unnamed_addr constant [50 x i8] c"  runtime library was built from sources hashing \00"
@.str.s1033 = private unnamed_addr constant [40 x i8] c"  the runtime sources on disk now hash \00"
@.str.s1034 = private unnamed_addr constant [73 x i8] c"  Re-package the toolchain (tools/package.ps1) so lib/ matches runtime/,\00"
@.str.s1035 = private unnamed_addr constant [72 x i8] c"  or move away from the source tree to use the installed runtime as-is.\00"
@.str.s1036 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s1037 = private unnamed_addr constant [4 x i8] c".ll\00"
@.str.s1038 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s1039 = private unnamed_addr constant [23 x i8] c"ERROR: Could not read \00"
@.str.s1040 = private unnamed_addr constant [66 x i8] c"  bootstrap compiles the Prismio compiler from a source checkout.\00"
@.str.s1041 = private unnamed_addr constant [71 x i8] c"  Run it from the repository root, or give the source path explicitly:\00"
@.str.s1042 = private unnamed_addr constant [45 x i8] c"      prismio bootstrap path/to/src/main.psm\00"
@.str.s1043 = private unnamed_addr constant [31 x i8] c"ERROR: Could not write LLVM IR\00"
@.str.s1044 = private unnamed_addr constant [16 x i8] c"Wrote LLVM IR: \00"
@.str.s1045 = private unnamed_addr constant [27 x i8] c"ERROR: Native build failed\00"
@.str.s1046 = private unnamed_addr constant [7 x i8] c"Built \00"
@.str.s1047 = private unnamed_addr constant [35 x i8] c"ERROR: Program exited with failure\00"
@.str.s1048 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s1049 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s1050 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s1051 = private unnamed_addr constant [7 x i8] c"--help\00"
@.str.s1052 = private unnamed_addr constant [3 x i8] c"-h\00"
@.str.s1053 = private unnamed_addr constant [10 x i8] c"--version\00"
@.str.s1054 = private unnamed_addr constant [3 x i8] c"-V\00"
@.str.s1055 = private unnamed_addr constant [9 x i8] c"prismio \00"
@.str.s1056 = private unnamed_addr constant [6 x i8] c"llvm \00"
@.str.s1057 = private unnamed_addr constant [13 x i8] c"runtime-hash\00"
@.str.s1058 = private unnamed_addr constant [1 x i8] zeroinitializer
@.str.s1059 = private unnamed_addr constant [58 x i8] c"ERROR: could not find the Prismio runtime sources to hash\00"
@.str.s1060 = private unnamed_addr constant [10 x i8] c"bootstrap\00"
@.str.s1061 = private unnamed_addr constant [10 x i8] c"bootstrap\00"
@.str.s1062 = private unnamed_addr constant [13 x i8] c"src/main.psm\00"
@.str.s1063 = private unnamed_addr constant [3 x i8] c"-o\00"
@.str.s1064 = private unnamed_addr constant [9 x i8] c"--target\00"
@.str.s1065 = private unnamed_addr constant [3 x i8] c"-o\00"
@.str.s1066 = private unnamed_addr constant [34 x i8] c"ERROR: -o requires an output path\00"
@.str.s1067 = private unnamed_addr constant [25 x i8] c"ERROR: Unknown argument \00"
@.str.s1068 = private unnamed_addr constant [6 x i8] c"build\00"
@.str.s1069 = private unnamed_addr constant [6 x i8] c"build\00"
@.str.s1070 = private unnamed_addr constant [27 x i8] c"ERROR: Missing source file\00"
@.str.s1071 = private unnamed_addr constant [4 x i8] c"run\00"
@.str.s1072 = private unnamed_addr constant [6 x i8] c"build\00"
@.str.s1073 = private unnamed_addr constant [45 x i8] c"ERROR: Use either 'build' or 'run', not both\00"
@.str.s1074 = private unnamed_addr constant [4 x i8] c"run\00"
@.str.s1075 = private unnamed_addr constant [4 x i8] c"run\00"
@.str.s1076 = private unnamed_addr constant [27 x i8] c"ERROR: Missing source file\00"
@.str.s1077 = private unnamed_addr constant [4 x i8] c"run\00"
@.str.s1078 = private unnamed_addr constant [6 x i8] c"build\00"
@.str.s1079 = private unnamed_addr constant [45 x i8] c"ERROR: Use either 'build' or 'run', not both\00"
@.str.s1080 = private unnamed_addr constant [6 x i8] c"build\00"
@.str.s1081 = private unnamed_addr constant [3 x i8] c"-o\00"
@.str.s1082 = private unnamed_addr constant [34 x i8] c"ERROR: -o requires an output path\00"
@.str.s1083 = private unnamed_addr constant [3 x i8] c"-O\00"
@.str.s1084 = private unnamed_addr constant [35 x i8] c"ERROR: unknown optimization level \00"
@.str.s1085 = private unnamed_addr constant [9 x i8] c"--target\00"
@.str.s1086 = private unnamed_addr constant [47 x i8] c"ERROR: --target requires a value (e.g. wasm32)\00"
@.str.s1087 = private unnamed_addr constant [7 x i8] c"wasm32\00"
@.str.s1088 = private unnamed_addr constant [6 x i8] c"build\00"
@.str.s1089 = private unnamed_addr constant [4 x i8] c"run\00"
@.str.s1090 = private unnamed_addr constant [45 x i8] c"ERROR: Use either 'build' or 'run', not both\00"
@.str.s1091 = private unnamed_addr constant [6 x i8] c"build\00"
@.str.s1092 = private unnamed_addr constant [25 x i8] c"ERROR: Unknown argument \00"

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

declare void @ir_set_opt_level(i32)

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
  %t.346 = alloca i32, align 4
  store i32 %0, ptr %t.346, align 4
  %1 = load i32, ptr %t.346, align 4
  %2 = icmp eq i32 %1, 0
  br i1 %2, label %label_0, label %label_2

label_2:                                          ; preds = %entry
  %3 = load i32, ptr %t.346, align 4
  %4 = icmp eq i32 %3, 1
  br i1 %4, label %label_3, label %label_5

label_0:                                          ; preds = %entry
  ret ptr @.str.s0

label_5:                                          ; preds = %label_2
  %5 = load i32, ptr %t.346, align 4
  %6 = icmp eq i32 %5, 2
  br i1 %6, label %label_6, label %label_8

label_3:                                          ; preds = %label_2
  ret ptr @.str.s1

label_8:                                          ; preds = %label_5
  %7 = load i32, ptr %t.346, align 4
  %8 = icmp eq i32 %7, 3
  br i1 %8, label %label_9, label %label_11

label_6:                                          ; preds = %label_5
  ret ptr @.str.s2

label_11:                                         ; preds = %label_8
  %9 = load i32, ptr %t.346, align 4
  %10 = icmp eq i32 %9, 4
  br i1 %10, label %label_12, label %label_14

label_9:                                          ; preds = %label_8
  ret ptr @.str.s3

label_14:                                         ; preds = %label_11
  %11 = load i32, ptr %t.346, align 4
  %12 = icmp eq i32 %11, 5
  br i1 %12, label %label_15, label %label_17

label_12:                                         ; preds = %label_11
  ret ptr @.str.s4

label_17:                                         ; preds = %label_14
  %13 = load i32, ptr %t.346, align 4
  %14 = icmp eq i32 %13, 18
  br i1 %14, label %label_18, label %label_20

label_15:                                         ; preds = %label_14
  ret ptr @.str.s5

label_20:                                         ; preds = %label_17
  %15 = load i32, ptr %t.346, align 4
  %16 = icmp eq i32 %15, 6
  br i1 %16, label %label_21, label %label_23

label_18:                                         ; preds = %label_17
  ret ptr @.str.s6

label_23:                                         ; preds = %label_20
  %17 = load i32, ptr %t.346, align 4
  %18 = icmp eq i32 %17, 8
  br i1 %18, label %label_24, label %label_26

label_21:                                         ; preds = %label_20
  ret ptr @.str.s7

label_26:                                         ; preds = %label_23
  %19 = load i32, ptr %t.346, align 4
  %20 = icmp eq i32 %19, 9
  br i1 %20, label %label_27, label %label_29

label_24:                                         ; preds = %label_23
  ret ptr @.str.s8

label_29:                                         ; preds = %label_26
  %21 = load i32, ptr %t.346, align 4
  %22 = icmp eq i32 %21, 12
  br i1 %22, label %label_30, label %label_32

label_27:                                         ; preds = %label_26
  ret ptr @.str.s9

label_32:                                         ; preds = %label_29
  %23 = load i32, ptr %t.346, align 4
  %24 = icmp eq i32 %23, 15
  br i1 %24, label %label_33, label %label_35

label_30:                                         ; preds = %label_29
  ret ptr @.str.s10

label_35:                                         ; preds = %label_32
  %25 = load i32, ptr %t.346, align 4
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
  %c.347 = alloca i8, align 1
  store i8 %0, ptr %c.347, align 1
  %sc.0 = alloca i1, align 1
  %1 = load i8, ptr %c.347, align 1
  %2 = icmp sge i8 %1, 48
  store i1 %2, ptr %sc.0, align 1
  br i1 %2, label %label_39, label %label_40

label_40:                                         ; preds = %label_39, %entry
  %3 = load i1, ptr %sc.0, align 1
  ret i1 %3

label_39:                                         ; preds = %entry
  %4 = load i8, ptr %c.347, align 1
  %5 = icmp sle i8 %4, 57
  store i1 %5, ptr %sc.0, align 1
  br label %label_40
}

define i1 @is_alpha__Char(i8 %0) {
entry:
  %c.348 = alloca i8, align 1
  store i8 %0, ptr %c.348, align 1
  %sc.1 = alloca i1, align 1
  %sc.2 = alloca i1, align 1
  %sc.3 = alloca i1, align 1
  %1 = load i8, ptr %c.348, align 1
  %2 = icmp sge i8 %1, 97
  store i1 %2, ptr %sc.3, align 1
  %sc.4 = alloca i1, align 1
  br i1 %2, label %label_45, label %label_46

label_46:                                         ; preds = %label_45, %entry
  %3 = load i1, ptr %sc.3, align 1
  store i1 %3, ptr %sc.2, align 1
  br i1 %3, label %label_44, label %label_43

label_45:                                         ; preds = %entry
  %4 = load i8, ptr %c.348, align 1
  %5 = icmp sle i8 %4, 122
  store i1 %5, ptr %sc.3, align 1
  br label %label_46

label_43:                                         ; preds = %label_46
  %6 = load i8, ptr %c.348, align 1
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
  %10 = load i8, ptr %c.348, align 1
  %11 = icmp sle i8 %10, 90
  store i1 %11, ptr %sc.4, align 1
  br label %label_48

label_41:                                         ; preds = %label_44
  %12 = load i8, ptr %c.348, align 1
  %13 = icmp eq i8 %12, 95
  store i1 %13, ptr %sc.1, align 1
  br label %label_42

label_42:                                         ; preds = %label_41, %label_44
  %14 = load i1, ptr %sc.1, align 1
  ret i1 %14
}

define i1 @is_alnum__Char(i8 %0) {
entry:
  %c.349 = alloca i8, align 1
  store i8 %0, ptr %c.349, align 1
  %sc.5 = alloca i1, align 1
  %1 = load i8, ptr %c.349, align 1
  %2 = call i1 @is_alpha__Char(i8 %1)
  store i1 %2, ptr %sc.5, align 1
  br i1 %2, label %label_50, label %label_49

label_49:                                         ; preds = %entry
  %3 = load i8, ptr %c.349, align 1
  %4 = call i1 @is_digit__Char(i8 %3)
  store i1 %4, ptr %sc.5, align 1
  br label %label_50

label_50:                                         ; preds = %label_49, %entry
  %5 = load i1, ptr %sc.5, align 1
  ret i1 %5
}

define i1 @is_space__Char(i8 %0) {
entry:
  %c.350 = alloca i8, align 1
  store i8 %0, ptr %c.350, align 1
  %sc.6 = alloca i1, align 1
  %sc.7 = alloca i1, align 1
  %sc.8 = alloca i1, align 1
  %1 = load i8, ptr %c.350, align 1
  %2 = icmp eq i8 %1, 32
  store i1 %2, ptr %sc.8, align 1
  br i1 %2, label %label_56, label %label_55

label_55:                                         ; preds = %entry
  %3 = load i8, ptr %c.350, align 1
  %4 = icmp eq i8 %3, 9
  store i1 %4, ptr %sc.8, align 1
  br label %label_56

label_56:                                         ; preds = %label_55, %entry
  %5 = load i1, ptr %sc.8, align 1
  store i1 %5, ptr %sc.7, align 1
  br i1 %5, label %label_54, label %label_53

label_53:                                         ; preds = %label_56
  %6 = load i8, ptr %c.350, align 1
  %7 = icmp eq i8 %6, 10
  store i1 %7, ptr %sc.7, align 1
  br label %label_54

label_54:                                         ; preds = %label_53, %label_56
  %8 = load i1, ptr %sc.7, align 1
  store i1 %8, ptr %sc.6, align 1
  br i1 %8, label %label_52, label %label_51

label_51:                                         ; preds = %label_54
  %9 = load i8, ptr %c.350, align 1
  %10 = icmp eq i8 %9, 13
  store i1 %10, ptr %sc.6, align 1
  br label %label_52

label_52:                                         ; preds = %label_51, %label_54
  %11 = load i1, ptr %sc.6, align 1
  ret i1 %11
}

define i1 @is_separator__Char(i8 %0) {
entry:
  %c.351 = alloca i8, align 1
  store i8 %0, ptr %c.351, align 1
  %1 = load i8, ptr %c.351, align 1
  %2 = icmp eq i8 %1, 40
  br i1 %2, label %label_57, label %label_59

label_59:                                         ; preds = %entry
  %3 = load i8, ptr %c.351, align 1
  %4 = icmp eq i8 %3, 41
  br i1 %4, label %label_60, label %label_62

label_57:                                         ; preds = %entry
  ret i1 true

label_62:                                         ; preds = %label_59
  %5 = load i8, ptr %c.351, align 1
  %6 = icmp eq i8 %5, 123
  br i1 %6, label %label_63, label %label_65

label_60:                                         ; preds = %label_59
  ret i1 true

label_65:                                         ; preds = %label_62
  %7 = load i8, ptr %c.351, align 1
  %8 = icmp eq i8 %7, 125
  br i1 %8, label %label_66, label %label_68

label_63:                                         ; preds = %label_62
  ret i1 true

label_68:                                         ; preds = %label_65
  %9 = load i8, ptr %c.351, align 1
  %10 = icmp eq i8 %9, 91
  br i1 %10, label %label_69, label %label_71

label_66:                                         ; preds = %label_65
  ret i1 true

label_71:                                         ; preds = %label_68
  %11 = load i8, ptr %c.351, align 1
  %12 = icmp eq i8 %11, 93
  br i1 %12, label %label_72, label %label_74

label_69:                                         ; preds = %label_68
  ret i1 true

label_74:                                         ; preds = %label_71
  %13 = load i8, ptr %c.351, align 1
  %14 = icmp eq i8 %13, 44
  br i1 %14, label %label_75, label %label_77

label_72:                                         ; preds = %label_71
  ret i1 true

label_77:                                         ; preds = %label_74
  %15 = load i8, ptr %c.351, align 1
  %16 = icmp eq i8 %15, 46
  br i1 %16, label %label_78, label %label_80

label_75:                                         ; preds = %label_74
  ret i1 true

label_80:                                         ; preds = %label_77
  %17 = load i8, ptr %c.351, align 1
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
  %c.352 = alloca i8, align 1
  store i8 %0, ptr %c.352, align 1
  %1 = load i8, ptr %c.352, align 1
  %2 = icmp eq i8 %1, 43
  br i1 %2, label %label_84, label %label_86

label_86:                                         ; preds = %entry
  %3 = load i8, ptr %c.352, align 1
  %4 = icmp eq i8 %3, 45
  br i1 %4, label %label_87, label %label_89

label_84:                                         ; preds = %entry
  ret i1 true

label_89:                                         ; preds = %label_86
  %5 = load i8, ptr %c.352, align 1
  %6 = icmp eq i8 %5, 42
  br i1 %6, label %label_90, label %label_92

label_87:                                         ; preds = %label_86
  ret i1 true

label_92:                                         ; preds = %label_89
  %7 = load i8, ptr %c.352, align 1
  %8 = icmp eq i8 %7, 47
  br i1 %8, label %label_93, label %label_95

label_90:                                         ; preds = %label_89
  ret i1 true

label_95:                                         ; preds = %label_92
  %9 = load i8, ptr %c.352, align 1
  %10 = icmp eq i8 %9, 37
  br i1 %10, label %label_96, label %label_98

label_93:                                         ; preds = %label_92
  ret i1 true

label_98:                                         ; preds = %label_95
  %11 = load i8, ptr %c.352, align 1
  %12 = icmp eq i8 %11, 60
  br i1 %12, label %label_99, label %label_101

label_96:                                         ; preds = %label_95
  ret i1 true

label_101:                                        ; preds = %label_98
  %13 = load i8, ptr %c.352, align 1
  %14 = icmp eq i8 %13, 62
  br i1 %14, label %label_102, label %label_104

label_99:                                         ; preds = %label_98
  ret i1 true

label_104:                                        ; preds = %label_101
  %15 = load i8, ptr %c.352, align 1
  %16 = icmp eq i8 %15, 33
  br i1 %16, label %label_105, label %label_107

label_102:                                        ; preds = %label_101
  ret i1 true

label_107:                                        ; preds = %label_104
  %17 = load i8, ptr %c.352, align 1
  %18 = icmp eq i8 %17, 38
  br i1 %18, label %label_108, label %label_110

label_105:                                        ; preds = %label_104
  ret i1 true

label_110:                                        ; preds = %label_107
  %19 = load i8, ptr %c.352, align 1
  %20 = icmp eq i8 %19, 124
  br i1 %20, label %label_111, label %label_113

label_108:                                        ; preds = %label_107
  ret i1 true

label_113:                                        ; preds = %label_110
  %21 = load i8, ptr %c.352, align 1
  %22 = icmp eq i8 %21, 94
  br i1 %22, label %label_114, label %label_116

label_111:                                        ; preds = %label_110
  ret i1 true

label_116:                                        ; preds = %label_113
  %23 = load i8, ptr %c.352, align 1
  %24 = icmp eq i8 %23, 126
  br i1 %24, label %label_117, label %label_119

label_114:                                        ; preds = %label_113
  ret i1 true

label_119:                                        ; preds = %label_116
  %25 = load i8, ptr %c.352, align 1
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
  %c.353 = alloca i8, align 1
  store i8 %0, ptr %c.353, align 1
  %1 = load i8, ptr %c.353, align 1
  %2 = zext i8 %1 to i32
  ret i32 %2
}

define i1 @is_keyword__String(ptr %0) {
entry:
  %s.354 = alloca ptr, align 8
  store ptr %0, ptr %s.354, align 8
  %1 = load ptr, ptr %s.354, align 8
  %2 = call i32 @str_equals(ptr %1, ptr @.str.s14)
  %3 = icmp eq i32 %2, 1
  br i1 %3, label %label_123, label %label_125

label_125:                                        ; preds = %entry
  %4 = load ptr, ptr %s.354, align 8
  %5 = call i32 @str_equals(ptr %4, ptr @.str.s15)
  %6 = icmp eq i32 %5, 1
  br i1 %6, label %label_126, label %label_128

label_123:                                        ; preds = %entry
  ret i1 true

label_128:                                        ; preds = %label_125
  %7 = load ptr, ptr %s.354, align 8
  %8 = call i32 @str_equals(ptr %7, ptr @.str.s16)
  %9 = icmp eq i32 %8, 1
  br i1 %9, label %label_129, label %label_131

label_126:                                        ; preds = %label_125
  ret i1 true

label_131:                                        ; preds = %label_128
  %10 = load ptr, ptr %s.354, align 8
  %11 = call i32 @str_equals(ptr %10, ptr @.str.s17)
  %12 = icmp eq i32 %11, 1
  br i1 %12, label %label_132, label %label_134

label_129:                                        ; preds = %label_128
  ret i1 true

label_134:                                        ; preds = %label_131
  %13 = load ptr, ptr %s.354, align 8
  %14 = call i32 @str_equals(ptr %13, ptr @.str.s18)
  %15 = icmp eq i32 %14, 1
  br i1 %15, label %label_135, label %label_137

label_132:                                        ; preds = %label_131
  ret i1 true

label_137:                                        ; preds = %label_134
  %16 = load ptr, ptr %s.354, align 8
  %17 = call i32 @str_equals(ptr %16, ptr @.str.s19)
  %18 = icmp eq i32 %17, 1
  br i1 %18, label %label_138, label %label_140

label_135:                                        ; preds = %label_134
  ret i1 true

label_140:                                        ; preds = %label_137
  %19 = load ptr, ptr %s.354, align 8
  %20 = call i32 @str_equals(ptr %19, ptr @.str.s20)
  %21 = icmp eq i32 %20, 1
  br i1 %21, label %label_141, label %label_143

label_138:                                        ; preds = %label_137
  ret i1 true

label_143:                                        ; preds = %label_140
  %22 = load ptr, ptr %s.354, align 8
  %23 = call i32 @str_equals(ptr %22, ptr @.str.s21)
  %24 = icmp eq i32 %23, 1
  br i1 %24, label %label_144, label %label_146

label_141:                                        ; preds = %label_140
  ret i1 true

label_146:                                        ; preds = %label_143
  %25 = load ptr, ptr %s.354, align 8
  %26 = call i32 @str_equals(ptr %25, ptr @.str.s22)
  %27 = icmp eq i32 %26, 1
  br i1 %27, label %label_147, label %label_149

label_144:                                        ; preds = %label_143
  ret i1 true

label_149:                                        ; preds = %label_146
  %28 = load ptr, ptr %s.354, align 8
  %29 = call i32 @str_equals(ptr %28, ptr @.str.s23)
  %30 = icmp eq i32 %29, 1
  br i1 %30, label %label_150, label %label_152

label_147:                                        ; preds = %label_146
  ret i1 true

label_152:                                        ; preds = %label_149
  %31 = load ptr, ptr %s.354, align 8
  %32 = call i32 @str_equals(ptr %31, ptr @.str.s24)
  %33 = icmp eq i32 %32, 1
  br i1 %33, label %label_153, label %label_155

label_150:                                        ; preds = %label_149
  ret i1 true

label_155:                                        ; preds = %label_152
  %34 = load ptr, ptr %s.354, align 8
  %35 = call i32 @str_equals(ptr %34, ptr @.str.s25)
  %36 = icmp eq i32 %35, 1
  br i1 %36, label %label_156, label %label_158

label_153:                                        ; preds = %label_152
  ret i1 true

label_158:                                        ; preds = %label_155
  %37 = load ptr, ptr %s.354, align 8
  %38 = call i32 @str_equals(ptr %37, ptr @.str.s26)
  %39 = icmp eq i32 %38, 1
  br i1 %39, label %label_159, label %label_161

label_156:                                        ; preds = %label_155
  ret i1 true

label_161:                                        ; preds = %label_158
  %40 = load ptr, ptr %s.354, align 8
  %41 = call i32 @str_equals(ptr %40, ptr @.str.s27)
  %42 = icmp eq i32 %41, 1
  br i1 %42, label %label_162, label %label_164

label_159:                                        ; preds = %label_158
  ret i1 true

label_164:                                        ; preds = %label_161
  %43 = load ptr, ptr %s.354, align 8
  %44 = call i32 @str_equals(ptr %43, ptr @.str.s28)
  %45 = icmp eq i32 %44, 1
  br i1 %45, label %label_165, label %label_167

label_162:                                        ; preds = %label_161
  ret i1 true

label_167:                                        ; preds = %label_164
  %46 = load ptr, ptr %s.354, align 8
  %47 = call i32 @str_equals(ptr %46, ptr @.str.s29)
  %48 = icmp eq i32 %47, 1
  br i1 %48, label %label_168, label %label_170

label_165:                                        ; preds = %label_164
  ret i1 true

label_170:                                        ; preds = %label_167
  %49 = load ptr, ptr %s.354, align 8
  %50 = call i32 @str_equals(ptr %49, ptr @.str.s30)
  %51 = icmp eq i32 %50, 1
  br i1 %51, label %label_171, label %label_173

label_168:                                        ; preds = %label_167
  ret i1 true

label_173:                                        ; preds = %label_170
  %52 = load ptr, ptr %s.354, align 8
  %53 = call i32 @str_equals(ptr %52, ptr @.str.s31)
  %54 = icmp eq i32 %53, 1
  br i1 %54, label %label_174, label %label_176

label_171:                                        ; preds = %label_170
  ret i1 true

label_176:                                        ; preds = %label_173
  %55 = load ptr, ptr %s.354, align 8
  %56 = call i32 @str_equals(ptr %55, ptr @.str.s32)
  %57 = icmp eq i32 %56, 1
  br i1 %57, label %label_177, label %label_179

label_174:                                        ; preds = %label_173
  ret i1 true

label_179:                                        ; preds = %label_176
  %58 = load ptr, ptr %s.354, align 8
  %59 = call i32 @str_equals(ptr %58, ptr @.str.s33)
  %60 = icmp eq i32 %59, 1
  br i1 %60, label %label_180, label %label_182

label_177:                                        ; preds = %label_176
  ret i1 true

label_182:                                        ; preds = %label_179
  %61 = load ptr, ptr %s.354, align 8
  %62 = call i32 @str_equals(ptr %61, ptr @.str.s34)
  %63 = icmp eq i32 %62, 1
  br i1 %63, label %label_183, label %label_185

label_180:                                        ; preds = %label_179
  ret i1 true

label_185:                                        ; preds = %label_182
  %64 = load ptr, ptr %s.354, align 8
  %65 = call i32 @str_equals(ptr %64, ptr @.str.s35)
  %66 = icmp eq i32 %65, 1
  br i1 %66, label %label_186, label %label_188

label_183:                                        ; preds = %label_182
  ret i1 true

label_188:                                        ; preds = %label_185
  %67 = load ptr, ptr %s.354, align 8
  %68 = call i32 @str_equals(ptr %67, ptr @.str.s36)
  %69 = icmp eq i32 %68, 1
  br i1 %69, label %label_189, label %label_191

label_186:                                        ; preds = %label_185
  ret i1 true

label_191:                                        ; preds = %label_188
  %70 = load ptr, ptr %s.354, align 8
  %71 = call i32 @str_equals(ptr %70, ptr @.str.s37)
  %72 = icmp eq i32 %71, 1
  br i1 %72, label %label_192, label %label_194

label_189:                                        ; preds = %label_188
  ret i1 true

label_194:                                        ; preds = %label_191
  %73 = load ptr, ptr %s.354, align 8
  %74 = call i32 @str_equals(ptr %73, ptr @.str.s38)
  %75 = icmp eq i32 %74, 1
  br i1 %75, label %label_195, label %label_197

label_192:                                        ; preds = %label_191
  ret i1 true

label_197:                                        ; preds = %label_194
  %76 = load ptr, ptr %s.354, align 8
  %77 = call i32 @str_equals(ptr %76, ptr @.str.s39)
  %78 = icmp eq i32 %77, 1
  br i1 %78, label %label_198, label %label_200

label_195:                                        ; preds = %label_194
  ret i1 true

label_200:                                        ; preds = %label_197
  %79 = load ptr, ptr %s.354, align 8
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
  %s.355 = alloca ptr, align 8
  store ptr %0, ptr %s.355, align 8
  %1 = load ptr, ptr %s.355, align 8
  %2 = call i32 @str_equals(ptr %1, ptr @.str.s41)
  %3 = icmp eq i32 %2, 1
  br i1 %3, label %label_204, label %label_206

label_206:                                        ; preds = %entry
  %4 = load ptr, ptr %s.355, align 8
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
  %input.356 = alloca ptr, align 8
  store ptr %0, ptr %input.356, align 8
  %start.357 = alloca i32, align 4
  store i32 0, ptr %start.357, align 4
  %1 = load ptr, ptr %input.356, align 8
  %2 = call i8 @str_char_at(ptr %1, i32 0)
  %3 = call i32 @char_code__Char(i8 %2)
  %4 = icmp eq i32 %3, 239
  %sc.9 = alloca i1, align 1
  br i1 %4, label %label_210, label %label_212

label_212:                                        ; preds = %label_217, %entry
  %5 = call ptr @malloc(i64 ptrtoint (ptr getelementptr (%Lexer, ptr null, i32 1) to i64))
  %6 = load ptr, ptr %input.356, align 8
  %7 = getelementptr inbounds nuw %Lexer, ptr %5, i32 0, i32 0
  store ptr %6, ptr %7, align 8
  %8 = load i32, ptr %start.357, align 4
  %9 = getelementptr inbounds nuw %Lexer, ptr %5, i32 0, i32 1
  store i32 %8, ptr %9, align 4
  %10 = getelementptr inbounds nuw %Lexer, ptr %5, i32 0, i32 2
  store i32 1, ptr %10, align 4
  %11 = getelementptr inbounds nuw %Lexer, ptr %5, i32 0, i32 3
  store i32 1, ptr %11, align 4
  ret ptr %5

label_210:                                        ; preds = %entry
  %12 = load ptr, ptr %input.356, align 8
  %13 = call i8 @str_char_at(ptr %12, i32 1)
  %14 = call i32 @char_code__Char(i8 %13)
  %15 = icmp eq i32 %14, 187
  store i1 %15, ptr %sc.9, align 1
  br i1 %15, label %label_213, label %label_214

label_214:                                        ; preds = %label_213, %label_210
  %16 = load i1, ptr %sc.9, align 1
  br i1 %16, label %label_215, label %label_217

label_213:                                        ; preds = %label_210
  %17 = load ptr, ptr %input.356, align 8
  %18 = call i8 @str_char_at(ptr %17, i32 2)
  %19 = call i32 @char_code__Char(i8 %18)
  %20 = icmp eq i32 %19, 191
  store i1 %20, ptr %sc.9, align 1
  br label %label_214

label_217:                                        ; preds = %label_215, %label_214
  br label %label_212

label_215:                                        ; preds = %label_214
  store i32 3, ptr %start.357, align 4
  br label %label_217
}

define i8 @lexer_peek__Struct_Lexer_Int(ptr %0, i32 %1) {
entry:
  %lex.358 = alloca ptr, align 8
  store ptr %0, ptr %lex.358, align 8
  %offset.359 = alloca i32, align 4
  store i32 %1, ptr %offset.359, align 4
  %2 = load ptr, ptr %lex.358, align 8
  %3 = getelementptr inbounds nuw %Lexer, ptr %2, i32 0, i32 0
  %4 = load ptr, ptr %3, align 8
  %5 = load ptr, ptr %lex.358, align 8
  %6 = getelementptr inbounds nuw %Lexer, ptr %5, i32 0, i32 1
  %7 = load i32, ptr %6, align 4
  %8 = load i32, ptr %offset.359, align 4
  %9 = add i32 %7, %8
  %10 = call i8 @str_char_at(ptr %4, i32 %9)
  ret i8 %10
}

define i8 @lexer_current__Struct_Lexer(ptr %0) {
entry:
  %lex.360 = alloca ptr, align 8
  store ptr %0, ptr %lex.360, align 8
  %1 = load ptr, ptr %lex.360, align 8
  %2 = getelementptr inbounds nuw %Lexer, ptr %1, i32 0, i32 0
  %3 = load ptr, ptr %2, align 8
  %4 = load ptr, ptr %lex.360, align 8
  %5 = getelementptr inbounds nuw %Lexer, ptr %4, i32 0, i32 1
  %6 = load i32, ptr %5, align 4
  %7 = call i8 @str_char_at(ptr %3, i32 %6)
  ret i8 %7
}

define void @lexer_advance__Struct_Lexer(ptr %0) {
entry:
  %lex.361 = alloca ptr, align 8
  store ptr %0, ptr %lex.361, align 8
  %1 = load ptr, ptr %lex.361, align 8
  %2 = load ptr, ptr %lex.361, align 8
  %3 = getelementptr inbounds nuw %Lexer, ptr %2, i32 0, i32 1
  %4 = load i32, ptr %3, align 4
  %5 = add i32 %4, 1
  %6 = getelementptr inbounds nuw %Lexer, ptr %1, i32 0, i32 1
  store i32 %5, ptr %6, align 4
  %7 = load ptr, ptr %lex.361, align 8
  %8 = load ptr, ptr %lex.361, align 8
  %9 = getelementptr inbounds nuw %Lexer, ptr %8, i32 0, i32 3
  %10 = load i32, ptr %9, align 4
  %11 = add i32 %10, 1
  %12 = getelementptr inbounds nuw %Lexer, ptr %7, i32 0, i32 3
  store i32 %11, ptr %12, align 4
  ret void
}

define void @lexer_skip_whitespace__Struct_Lexer(ptr %0) {
entry:
  %lex.362 = alloca ptr, align 8
  store ptr %0, ptr %lex.362, align 8
  %is_looping.363 = alloca i1, align 1
  store i1 true, ptr %is_looping.363, align 1
  %sc.10 = alloca i1, align 1
  %sc.11 = alloca i1, align 1
  br label %label_218

label_218:                                        ; preds = %label_223, %entry
  %1 = load i1, ptr %is_looping.363, align 1
  br i1 %1, label %label_219, label %label_220

label_220:                                        ; preds = %label_218
  ret void

label_219:                                        ; preds = %label_218
  %2 = load ptr, ptr %lex.362, align 8
  %3 = call i8 @lexer_current__Struct_Lexer(ptr %2)
  %4 = call i1 @is_space__Char(i8 %3)
  br i1 %4, label %label_221, label %label_222

label_222:                                        ; preds = %label_219
  %5 = load ptr, ptr %lex.362, align 8
  %6 = call i8 @lexer_current__Struct_Lexer(ptr %5)
  %7 = icmp eq i8 %6, 47
  store i1 %7, ptr %sc.10, align 1
  br i1 %7, label %label_227, label %label_228

label_221:                                        ; preds = %label_219
  %8 = load ptr, ptr %lex.362, align 8
  %9 = call i8 @lexer_current__Struct_Lexer(ptr %8)
  %10 = icmp eq i8 %9, 10
  br i1 %10, label %label_224, label %label_226

label_226:                                        ; preds = %label_224, %label_221
  %11 = load ptr, ptr %lex.362, align 8
  call void @lexer_advance__Struct_Lexer(ptr %11)
  br label %label_223

label_224:                                        ; preds = %label_221
  %12 = load ptr, ptr %lex.362, align 8
  %13 = load ptr, ptr %lex.362, align 8
  %14 = getelementptr inbounds nuw %Lexer, ptr %13, i32 0, i32 2
  %15 = load i32, ptr %14, align 4
  %16 = add i32 %15, 1
  %17 = getelementptr inbounds nuw %Lexer, ptr %12, i32 0, i32 2
  store i32 %16, ptr %17, align 4
  %18 = load ptr, ptr %lex.362, align 8
  %19 = getelementptr inbounds nuw %Lexer, ptr %18, i32 0, i32 3
  store i32 0, ptr %19, align 4
  br label %label_226

label_223:                                        ; preds = %label_231, %label_226
  br label %label_218

label_228:                                        ; preds = %label_227, %label_222
  %20 = load i1, ptr %sc.10, align 1
  br i1 %20, label %label_229, label %label_230

label_227:                                        ; preds = %label_222
  %21 = load ptr, ptr %lex.362, align 8
  %22 = call i8 @lexer_peek__Struct_Lexer_Int(ptr %21, i32 1)
  %23 = icmp eq i8 %22, 47
  store i1 %23, ptr %sc.10, align 1
  br label %label_228

label_230:                                        ; preds = %label_228
  store i1 false, ptr %is_looping.363, align 1
  br label %label_231

label_229:                                        ; preds = %label_228
  br label %label_232

label_232:                                        ; preds = %label_233, %label_229
  %24 = load ptr, ptr %lex.362, align 8
  %25 = call i8 @lexer_current__Struct_Lexer(ptr %24)
  %26 = icmp ne i8 %25, 10
  store i1 %26, ptr %sc.11, align 1
  br i1 %26, label %label_235, label %label_236

label_236:                                        ; preds = %label_235, %label_232
  %27 = load i1, ptr %sc.11, align 1
  br i1 %27, label %label_233, label %label_234

label_235:                                        ; preds = %label_232
  %28 = load ptr, ptr %lex.362, align 8
  %29 = call i8 @lexer_current__Struct_Lexer(ptr %28)
  %30 = icmp ne i8 %29, 0
  store i1 %30, ptr %sc.11, align 1
  br label %label_236

label_234:                                        ; preds = %label_236
  br label %label_231

label_233:                                        ; preds = %label_236
  %31 = load ptr, ptr %lex.362, align 8
  call void @lexer_advance__Struct_Lexer(ptr %31)
  br label %label_232

label_231:                                        ; preds = %label_230, %label_234
  br label %label_223
}

define ptr @lexer_decode_escapes__String_Int(ptr %0, i32 %1) {
entry:
  %raw.364 = alloca ptr, align 8
  store ptr %0, ptr %raw.364, align 8
  %line.365 = alloca i32, align 4
  store i32 %1, ptr %line.365, align 4
  %out.366 = alloca ptr, align 8
  store ptr @.str.s43, ptr %out.366, align 8
  %i.367 = alloca i32, align 4
  store i32 0, ptr %i.367, align 4
  %2 = load ptr, ptr %raw.364, align 8
  %3 = call i32 @str_length(ptr %2)
  %n.368 = alloca i32, align 4
  store i32 %3, ptr %n.368, align 4
  %ch.369 = alloca i8, align 1
  %sc.12 = alloca i1, align 1
  %esc.370 = alloca i8, align 1
  %decoded.371 = alloca i8, align 1
  %known.372 = alloca i1, align 1
  br label %label_237

label_237:                                        ; preds = %label_244, %entry
  %4 = load i32, ptr %i.367, align 4
  %5 = load i32, ptr %n.368, align 4
  %6 = icmp slt i32 %4, %5
  br i1 %6, label %label_238, label %label_239

label_239:                                        ; preds = %label_237
  %7 = load ptr, ptr %out.366, align 8
  ret ptr %7

label_238:                                        ; preds = %label_237
  %8 = load ptr, ptr %raw.364, align 8
  %9 = load i32, ptr %i.367, align 4
  %10 = call i8 @str_char_at(ptr %8, i32 %9)
  store i8 %10, ptr %ch.369, align 1
  %11 = load i8, ptr %ch.369, align 1
  %12 = icmp eq i8 %11, 92
  store i1 %12, ptr %sc.12, align 1
  br i1 %12, label %label_240, label %label_241

label_241:                                        ; preds = %label_240, %label_238
  %13 = load i1, ptr %sc.12, align 1
  br i1 %13, label %label_242, label %label_243

label_240:                                        ; preds = %label_238
  %14 = load i32, ptr %i.367, align 4
  %15 = add i32 %14, 1
  %16 = load i32, ptr %n.368, align 4
  %17 = icmp slt i32 %15, %16
  store i1 %17, ptr %sc.12, align 1
  br label %label_241

label_243:                                        ; preds = %label_241
  %18 = load ptr, ptr %out.366, align 8
  %19 = load i8, ptr %ch.369, align 1
  %20 = call ptr @str_from_char(i8 %19)
  %21 = call ptr @str_concat(ptr %18, ptr %20)
  store ptr %21, ptr %out.366, align 8
  %22 = load i32, ptr %i.367, align 4
  %23 = add i32 %22, 1
  store i32 %23, ptr %i.367, align 4
  br label %label_244

label_242:                                        ; preds = %label_241
  %24 = load ptr, ptr %raw.364, align 8
  %25 = load i32, ptr %i.367, align 4
  %26 = add i32 %25, 1
  %27 = call i8 @str_char_at(ptr %24, i32 %26)
  store i8 %27, ptr %esc.370, align 1
  %28 = load i8, ptr %esc.370, align 1
  store i8 %28, ptr %decoded.371, align 1
  store i1 true, ptr %known.372, align 1
  %29 = load i8, ptr %esc.370, align 1
  %30 = icmp eq i8 %29, 110
  br i1 %30, label %label_245, label %label_246

label_246:                                        ; preds = %label_242
  %31 = load i8, ptr %esc.370, align 1
  %32 = icmp eq i8 %31, 116
  br i1 %32, label %label_248, label %label_249

label_245:                                        ; preds = %label_242
  store i8 10, ptr %decoded.371, align 1
  br label %label_247

label_247:                                        ; preds = %label_250, %label_245
  %33 = load i1, ptr %known.372, align 1
  %34 = icmp eq i1 %33, false
  br i1 %34, label %label_266, label %label_268

label_249:                                        ; preds = %label_246
  %35 = load i8, ptr %esc.370, align 1
  %36 = icmp eq i8 %35, 114
  br i1 %36, label %label_251, label %label_252

label_248:                                        ; preds = %label_246
  store i8 9, ptr %decoded.371, align 1
  br label %label_250

label_250:                                        ; preds = %label_253, %label_248
  br label %label_247

label_252:                                        ; preds = %label_249
  %37 = load i8, ptr %esc.370, align 1
  %38 = icmp eq i8 %37, 92
  br i1 %38, label %label_254, label %label_255

label_251:                                        ; preds = %label_249
  store i8 13, ptr %decoded.371, align 1
  br label %label_253

label_253:                                        ; preds = %label_256, %label_251
  br label %label_250

label_255:                                        ; preds = %label_252
  %39 = load i8, ptr %esc.370, align 1
  %40 = icmp eq i8 %39, 34
  br i1 %40, label %label_257, label %label_258

label_254:                                        ; preds = %label_252
  store i8 92, ptr %decoded.371, align 1
  br label %label_256

label_256:                                        ; preds = %label_259, %label_254
  br label %label_253

label_258:                                        ; preds = %label_255
  %41 = load i8, ptr %esc.370, align 1
  %42 = icmp eq i8 %41, 39
  br i1 %42, label %label_260, label %label_261

label_257:                                        ; preds = %label_255
  store i8 34, ptr %decoded.371, align 1
  br label %label_259

label_259:                                        ; preds = %label_262, %label_257
  br label %label_256

label_261:                                        ; preds = %label_258
  %43 = load i8, ptr %esc.370, align 1
  %44 = icmp eq i8 %43, 48
  br i1 %44, label %label_263, label %label_264

label_260:                                        ; preds = %label_258
  store i8 39, ptr %decoded.371, align 1
  br label %label_262

label_262:                                        ; preds = %label_265, %label_260
  br label %label_259

label_264:                                        ; preds = %label_261
  store i1 false, ptr %known.372, align 1
  br label %label_265

label_263:                                        ; preds = %label_261
  call void @print(ptr @.str.s44)
  %45 = load i32, ptr %line.365, align 4
  call void @print_int(i32 %45)
  call void @println(ptr @.str.s45)
  call void @exit(i32 1)
  br label %label_265

label_265:                                        ; preds = %label_264, %label_263
  br label %label_262

label_268:                                        ; preds = %label_266, %label_247
  %46 = load ptr, ptr %out.366, align 8
  %47 = load i8, ptr %decoded.371, align 1
  %48 = call ptr @str_from_char(i8 %47)
  %49 = call ptr @str_concat(ptr %46, ptr %48)
  store ptr %49, ptr %out.366, align 8
  %50 = load i32, ptr %i.367, align 4
  %51 = add i32 %50, 2
  store i32 %51, ptr %i.367, align 4
  br label %label_244

label_266:                                        ; preds = %label_247
  call void @print(ptr @.str.s46)
  %52 = load i32, ptr %line.365, align 4
  call void @print_int(i32 %52)
  call void @print(ptr @.str.s47)
  call void @print_char(i8 92)
  %53 = load i8, ptr %esc.370, align 1
  call void @println_char(i8 %53)
  call void @exit(i32 1)
  br label %label_268

label_244:                                        ; preds = %label_243, %label_268
  br label %label_237
}

define ptr @lexer_next_token__Struct_Lexer(ptr %0) {
entry:
  %lex.373 = alloca ptr, align 8
  store ptr %0, ptr %lex.373, align 8
  %1 = load ptr, ptr %lex.373, align 8
  call void @lexer_skip_whitespace__Struct_Lexer(ptr %1)
  %2 = load ptr, ptr %lex.373, align 8
  %3 = getelementptr inbounds nuw %Lexer, ptr %2, i32 0, i32 1
  %4 = load i32, ptr %3, align 4
  %5 = load ptr, ptr %lex.373, align 8
  %6 = getelementptr inbounds nuw %Lexer, ptr %5, i32 0, i32 0
  %7 = load ptr, ptr %6, align 8
  %8 = call i32 @str_length(ptr %7)
  %9 = icmp sge i32 %4, %8
  %c.374 = alloca i8, align 1
  %start.375 = alloca i32, align 4
  %length.376 = alloca i32, align 4
  %value.377 = alloca ptr, align 8
  %start.378 = alloca i32, align 4
  %is_float.379 = alloca i32, align 4
  %sc.13 = alloca i1, align 1
  %length.380 = alloca i32, align 4
  %value.381 = alloca ptr, align 8
  %start.382 = alloca i32, align 4
  %has_escape.383 = alloca i1, align 1
  %sc.14 = alloca i1, align 1
  %length.384 = alloca i32, align 4
  %raw.385 = alloca ptr, align 8
  %value.386 = alloca ptr, align 8
  %value_char.387 = alloca i8, align 1
  %esc.388 = alloca i8, align 1
  %start.389 = alloca i32, align 4
  %next.390 = alloca i8, align 1
  %sc.15 = alloca i1, align 1
  %sc.16 = alloca i1, align 1
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
  %length.391 = alloca i32, align 4
  %value.392 = alloca ptr, align 8
  %type.393 = alloca i32, align 4
  %sc.31 = alloca i1, align 1
  %sc.32 = alloca i1, align 1
  %sc.33 = alloca i1, align 1
  %sc.34 = alloca i1, align 1
  %sc.35 = alloca i1, align 1
  %sc.36 = alloca i1, align 1
  %sc.37 = alloca i1, align 1
  %sc.38 = alloca i1, align 1
  %sc.39 = alloca i1, align 1
  %val.394 = alloca ptr, align 8
  br i1 %9, label %label_269, label %label_271

label_271:                                        ; preds = %entry
  %10 = load ptr, ptr %lex.373, align 8
  %11 = call i8 @lexer_current__Struct_Lexer(ptr %10)
  store i8 %11, ptr %c.374, align 1
  %12 = load i8, ptr %c.374, align 1
  %13 = call i1 @is_alpha__Char(i8 %12)
  br i1 %13, label %label_272, label %label_274

label_269:                                        ; preds = %entry
  %14 = call ptr @malloc(i64 ptrtoint (ptr getelementptr (%Token, ptr null, i32 1) to i64))
  %15 = getelementptr inbounds nuw %Token, ptr %14, i32 0, i32 0
  store i32 20, ptr %15, align 4
  %16 = getelementptr inbounds nuw %Token, ptr %14, i32 0, i32 1
  store ptr @.str.s48, ptr %16, align 8
  %17 = load ptr, ptr %lex.373, align 8
  %18 = getelementptr inbounds nuw %Lexer, ptr %17, i32 0, i32 2
  %19 = load i32, ptr %18, align 4
  %20 = getelementptr inbounds nuw %Token, ptr %14, i32 0, i32 2
  store i32 %19, ptr %20, align 4
  %21 = getelementptr inbounds nuw %Token, ptr %14, i32 0, i32 3
  store ptr @.str.s49, ptr %21, align 8
  ret ptr %14

label_274:                                        ; preds = %label_271
  %22 = load i8, ptr %c.374, align 1
  %23 = call i1 @is_digit__Char(i8 %22)
  br i1 %23, label %label_284, label %label_286

label_272:                                        ; preds = %label_271
  %24 = load ptr, ptr %lex.373, align 8
  %25 = getelementptr inbounds nuw %Lexer, ptr %24, i32 0, i32 1
  %26 = load i32, ptr %25, align 4
  store i32 %26, ptr %start.375, align 4
  br label %label_275

label_275:                                        ; preds = %label_276, %label_272
  %27 = load ptr, ptr %lex.373, align 8
  %28 = call i8 @lexer_current__Struct_Lexer(ptr %27)
  %29 = call i1 @is_alnum__Char(i8 %28)
  br i1 %29, label %label_276, label %label_277

label_277:                                        ; preds = %label_275
  %30 = load ptr, ptr %lex.373, align 8
  %31 = getelementptr inbounds nuw %Lexer, ptr %30, i32 0, i32 1
  %32 = load i32, ptr %31, align 4
  %33 = load i32, ptr %start.375, align 4
  %34 = sub i32 %32, %33
  store i32 %34, ptr %length.376, align 4
  %35 = load ptr, ptr %lex.373, align 8
  %36 = getelementptr inbounds nuw %Lexer, ptr %35, i32 0, i32 0
  %37 = load ptr, ptr %36, align 8
  %38 = load i32, ptr %start.375, align 4
  %39 = load i32, ptr %length.376, align 4
  %40 = call ptr @str_substring(ptr %37, i32 %38, i32 %39)
  store ptr %40, ptr %value.377, align 8
  %41 = load ptr, ptr %value.377, align 8
  %42 = call i1 @is_keyword__String(ptr %41)
  br i1 %42, label %label_278, label %label_280

label_276:                                        ; preds = %label_275
  %43 = load ptr, ptr %lex.373, align 8
  call void @lexer_advance__Struct_Lexer(ptr %43)
  br label %label_275

label_280:                                        ; preds = %label_277
  %44 = call ptr @malloc(i64 ptrtoint (ptr getelementptr (%Token, ptr null, i32 1) to i64))
  %45 = getelementptr inbounds nuw %Token, ptr %44, i32 0, i32 0
  store i32 5, ptr %45, align 4
  %46 = load ptr, ptr %value.377, align 8
  %47 = getelementptr inbounds nuw %Token, ptr %44, i32 0, i32 1
  store ptr %46, ptr %47, align 8
  %48 = load ptr, ptr %lex.373, align 8
  %49 = getelementptr inbounds nuw %Lexer, ptr %48, i32 0, i32 2
  %50 = load i32, ptr %49, align 4
  %51 = getelementptr inbounds nuw %Token, ptr %44, i32 0, i32 2
  store i32 %50, ptr %51, align 4
  %52 = getelementptr inbounds nuw %Token, ptr %44, i32 0, i32 3
  store ptr @.str.s52, ptr %52, align 8
  ret ptr %44

label_278:                                        ; preds = %label_277
  %53 = load ptr, ptr %value.377, align 8
  %54 = call i1 @is_boolean__String(ptr %53)
  br i1 %54, label %label_281, label %label_283

label_283:                                        ; preds = %label_278
  %55 = call ptr @malloc(i64 ptrtoint (ptr getelementptr (%Token, ptr null, i32 1) to i64))
  %56 = getelementptr inbounds nuw %Token, ptr %55, i32 0, i32 0
  store i32 18, ptr %56, align 4
  %57 = load ptr, ptr %value.377, align 8
  %58 = getelementptr inbounds nuw %Token, ptr %55, i32 0, i32 1
  store ptr %57, ptr %58, align 8
  %59 = load ptr, ptr %lex.373, align 8
  %60 = getelementptr inbounds nuw %Lexer, ptr %59, i32 0, i32 2
  %61 = load i32, ptr %60, align 4
  %62 = getelementptr inbounds nuw %Token, ptr %55, i32 0, i32 2
  store i32 %61, ptr %62, align 4
  %63 = getelementptr inbounds nuw %Token, ptr %55, i32 0, i32 3
  store ptr @.str.s51, ptr %63, align 8
  ret ptr %55

label_281:                                        ; preds = %label_278
  %64 = call ptr @malloc(i64 ptrtoint (ptr getelementptr (%Token, ptr null, i32 1) to i64))
  %65 = getelementptr inbounds nuw %Token, ptr %64, i32 0, i32 0
  store i32 4, ptr %65, align 4
  %66 = load ptr, ptr %value.377, align 8
  %67 = getelementptr inbounds nuw %Token, ptr %64, i32 0, i32 1
  store ptr %66, ptr %67, align 8
  %68 = load ptr, ptr %lex.373, align 8
  %69 = getelementptr inbounds nuw %Lexer, ptr %68, i32 0, i32 2
  %70 = load i32, ptr %69, align 4
  %71 = getelementptr inbounds nuw %Token, ptr %64, i32 0, i32 2
  store i32 %70, ptr %71, align 4
  %72 = getelementptr inbounds nuw %Token, ptr %64, i32 0, i32 3
  store ptr @.str.s50, ptr %72, align 8
  ret ptr %64

label_286:                                        ; preds = %label_274
  %73 = load i8, ptr %c.374, align 1
  %74 = icmp eq i8 %73, 34
  br i1 %74, label %label_301, label %label_303

label_284:                                        ; preds = %label_274
  %75 = load ptr, ptr %lex.373, align 8
  %76 = getelementptr inbounds nuw %Lexer, ptr %75, i32 0, i32 1
  %77 = load i32, ptr %76, align 4
  store i32 %77, ptr %start.378, align 4
  store i32 0, ptr %is_float.379, align 4
  br label %label_287

label_287:                                        ; preds = %label_288, %label_284
  %78 = load ptr, ptr %lex.373, align 8
  %79 = call i8 @lexer_current__Struct_Lexer(ptr %78)
  %80 = call i1 @is_digit__Char(i8 %79)
  br i1 %80, label %label_288, label %label_289

label_289:                                        ; preds = %label_287
  %81 = load ptr, ptr %lex.373, align 8
  %82 = call i8 @lexer_current__Struct_Lexer(ptr %81)
  %83 = icmp eq i8 %82, 46
  store i1 %83, ptr %sc.13, align 1
  br i1 %83, label %label_290, label %label_291

label_288:                                        ; preds = %label_287
  %84 = load ptr, ptr %lex.373, align 8
  call void @lexer_advance__Struct_Lexer(ptr %84)
  br label %label_287

label_291:                                        ; preds = %label_290, %label_289
  %85 = load i1, ptr %sc.13, align 1
  br i1 %85, label %label_292, label %label_294

label_290:                                        ; preds = %label_289
  %86 = load ptr, ptr %lex.373, align 8
  %87 = call i8 @lexer_peek__Struct_Lexer_Int(ptr %86, i32 1)
  %88 = call i1 @is_digit__Char(i8 %87)
  store i1 %88, ptr %sc.13, align 1
  br label %label_291

label_294:                                        ; preds = %label_297, %label_291
  %89 = load ptr, ptr %lex.373, align 8
  %90 = getelementptr inbounds nuw %Lexer, ptr %89, i32 0, i32 1
  %91 = load i32, ptr %90, align 4
  %92 = load i32, ptr %start.378, align 4
  %93 = sub i32 %91, %92
  store i32 %93, ptr %length.380, align 4
  %94 = load ptr, ptr %lex.373, align 8
  %95 = getelementptr inbounds nuw %Lexer, ptr %94, i32 0, i32 0
  %96 = load ptr, ptr %95, align 8
  %97 = load i32, ptr %start.378, align 4
  %98 = load i32, ptr %length.380, align 4
  %99 = call ptr @str_substring(ptr %96, i32 %97, i32 %98)
  store ptr %99, ptr %value.381, align 8
  %100 = load i32, ptr %is_float.379, align 4
  %101 = icmp eq i32 %100, 1
  br i1 %101, label %label_298, label %label_300

label_292:                                        ; preds = %label_291
  store i32 1, ptr %is_float.379, align 4
  %102 = load ptr, ptr %lex.373, align 8
  call void @lexer_advance__Struct_Lexer(ptr %102)
  br label %label_295

label_295:                                        ; preds = %label_296, %label_292
  %103 = load ptr, ptr %lex.373, align 8
  %104 = call i8 @lexer_current__Struct_Lexer(ptr %103)
  %105 = call i1 @is_digit__Char(i8 %104)
  br i1 %105, label %label_296, label %label_297

label_297:                                        ; preds = %label_295
  br label %label_294

label_296:                                        ; preds = %label_295
  %106 = load ptr, ptr %lex.373, align 8
  call void @lexer_advance__Struct_Lexer(ptr %106)
  br label %label_295

label_300:                                        ; preds = %label_294
  %107 = call ptr @malloc(i64 ptrtoint (ptr getelementptr (%Token, ptr null, i32 1) to i64))
  %108 = getelementptr inbounds nuw %Token, ptr %107, i32 0, i32 0
  store i32 2, ptr %108, align 4
  %109 = load ptr, ptr %value.381, align 8
  %110 = getelementptr inbounds nuw %Token, ptr %107, i32 0, i32 1
  store ptr %109, ptr %110, align 8
  %111 = load ptr, ptr %lex.373, align 8
  %112 = getelementptr inbounds nuw %Lexer, ptr %111, i32 0, i32 2
  %113 = load i32, ptr %112, align 4
  %114 = getelementptr inbounds nuw %Token, ptr %107, i32 0, i32 2
  store i32 %113, ptr %114, align 4
  %115 = getelementptr inbounds nuw %Token, ptr %107, i32 0, i32 3
  store ptr @.str.s54, ptr %115, align 8
  ret ptr %107

label_298:                                        ; preds = %label_294
  %116 = call ptr @malloc(i64 ptrtoint (ptr getelementptr (%Token, ptr null, i32 1) to i64))
  %117 = getelementptr inbounds nuw %Token, ptr %116, i32 0, i32 0
  store i32 3, ptr %117, align 4
  %118 = load ptr, ptr %value.381, align 8
  %119 = getelementptr inbounds nuw %Token, ptr %116, i32 0, i32 1
  store ptr %118, ptr %119, align 8
  %120 = load ptr, ptr %lex.373, align 8
  %121 = getelementptr inbounds nuw %Lexer, ptr %120, i32 0, i32 2
  %122 = load i32, ptr %121, align 4
  %123 = getelementptr inbounds nuw %Token, ptr %116, i32 0, i32 2
  store i32 %122, ptr %123, align 4
  %124 = getelementptr inbounds nuw %Token, ptr %116, i32 0, i32 3
  store ptr @.str.s53, ptr %124, align 8
  ret ptr %116

label_303:                                        ; preds = %label_286
  %125 = load i8, ptr %c.374, align 1
  %126 = icmp eq i8 %125, 39
  br i1 %126, label %label_318, label %label_320

label_301:                                        ; preds = %label_286
  %127 = load ptr, ptr %lex.373, align 8
  call void @lexer_advance__Struct_Lexer(ptr %127)
  %128 = load ptr, ptr %lex.373, align 8
  %129 = getelementptr inbounds nuw %Lexer, ptr %128, i32 0, i32 1
  %130 = load i32, ptr %129, align 4
  store i32 %130, ptr %start.382, align 4
  store i1 false, ptr %has_escape.383, align 1
  br label %label_304

label_304:                                        ; preds = %label_311, %label_301
  %131 = load ptr, ptr %lex.373, align 8
  %132 = call i8 @lexer_current__Struct_Lexer(ptr %131)
  %133 = icmp ne i8 %132, 34
  store i1 %133, ptr %sc.14, align 1
  br i1 %133, label %label_307, label %label_308

label_308:                                        ; preds = %label_307, %label_304
  %134 = load i1, ptr %sc.14, align 1
  br i1 %134, label %label_305, label %label_306

label_307:                                        ; preds = %label_304
  %135 = load ptr, ptr %lex.373, align 8
  %136 = getelementptr inbounds nuw %Lexer, ptr %135, i32 0, i32 1
  %137 = load i32, ptr %136, align 4
  %138 = load ptr, ptr %lex.373, align 8
  %139 = getelementptr inbounds nuw %Lexer, ptr %138, i32 0, i32 0
  %140 = load ptr, ptr %139, align 8
  %141 = call i32 @str_length(ptr %140)
  %142 = icmp slt i32 %137, %141
  store i1 %142, ptr %sc.14, align 1
  br label %label_308

label_306:                                        ; preds = %label_308
  %143 = load ptr, ptr %lex.373, align 8
  %144 = getelementptr inbounds nuw %Lexer, ptr %143, i32 0, i32 1
  %145 = load i32, ptr %144, align 4
  %146 = load i32, ptr %start.382, align 4
  %147 = sub i32 %145, %146
  store i32 %147, ptr %length.384, align 4
  %148 = load ptr, ptr %lex.373, align 8
  %149 = getelementptr inbounds nuw %Lexer, ptr %148, i32 0, i32 0
  %150 = load ptr, ptr %149, align 8
  %151 = load i32, ptr %start.382, align 4
  %152 = load i32, ptr %length.384, align 4
  %153 = call ptr @str_substring(ptr %150, i32 %151, i32 %152)
  store ptr %153, ptr %raw.385, align 8
  %154 = load ptr, ptr %lex.373, align 8
  %155 = call i8 @lexer_current__Struct_Lexer(ptr %154)
  %156 = icmp eq i8 %155, 34
  br i1 %156, label %label_312, label %label_313

label_305:                                        ; preds = %label_308
  %157 = load ptr, ptr %lex.373, align 8
  %158 = call i8 @lexer_current__Struct_Lexer(ptr %157)
  %159 = icmp eq i8 %158, 92
  br i1 %159, label %label_309, label %label_311

label_311:                                        ; preds = %label_309, %label_305
  %160 = load ptr, ptr %lex.373, align 8
  call void @lexer_advance__Struct_Lexer(ptr %160)
  br label %label_304

label_309:                                        ; preds = %label_305
  store i1 true, ptr %has_escape.383, align 1
  %161 = load ptr, ptr %lex.373, align 8
  call void @lexer_advance__Struct_Lexer(ptr %161)
  br label %label_311

label_313:                                        ; preds = %label_306
  call void @print(ptr @.str.s55)
  %162 = load ptr, ptr %lex.373, align 8
  %163 = getelementptr inbounds nuw %Lexer, ptr %162, i32 0, i32 2
  %164 = load i32, ptr %163, align 4
  call void @print_int(i32 %164)
  call void @println(ptr @.str.s56)
  call void @exit(i32 1)
  br label %label_314

label_312:                                        ; preds = %label_306
  %165 = load ptr, ptr %lex.373, align 8
  call void @lexer_advance__Struct_Lexer(ptr %165)
  br label %label_314

label_314:                                        ; preds = %label_313, %label_312
  %166 = load ptr, ptr %raw.385, align 8
  store ptr %166, ptr %value.386, align 8
  %167 = load i1, ptr %has_escape.383, align 1
  br i1 %167, label %label_315, label %label_317

label_317:                                        ; preds = %label_315, %label_314
  %168 = call ptr @malloc(i64 ptrtoint (ptr getelementptr (%Token, ptr null, i32 1) to i64))
  %169 = getelementptr inbounds nuw %Token, ptr %168, i32 0, i32 0
  store i32 0, ptr %169, align 4
  %170 = load ptr, ptr %value.386, align 8
  %171 = getelementptr inbounds nuw %Token, ptr %168, i32 0, i32 1
  store ptr %170, ptr %171, align 8
  %172 = load ptr, ptr %lex.373, align 8
  %173 = getelementptr inbounds nuw %Lexer, ptr %172, i32 0, i32 2
  %174 = load i32, ptr %173, align 4
  %175 = getelementptr inbounds nuw %Token, ptr %168, i32 0, i32 2
  store i32 %174, ptr %175, align 4
  %176 = getelementptr inbounds nuw %Token, ptr %168, i32 0, i32 3
  store ptr @.str.s57, ptr %176, align 8
  ret ptr %168

label_315:                                        ; preds = %label_314
  %177 = load ptr, ptr %raw.385, align 8
  %178 = load ptr, ptr %lex.373, align 8
  %179 = getelementptr inbounds nuw %Lexer, ptr %178, i32 0, i32 2
  %180 = load i32, ptr %179, align 4
  %181 = call ptr @lexer_decode_escapes__String_Int(ptr %177, i32 %180)
  store ptr %181, ptr %value.386, align 8
  br label %label_317

label_320:                                        ; preds = %label_303
  %182 = load i8, ptr %c.374, align 1
  %183 = call i1 @is_operator__Char(i8 %182)
  br i1 %183, label %label_348, label %label_350

label_318:                                        ; preds = %label_303
  %184 = load ptr, ptr %lex.373, align 8
  call void @lexer_advance__Struct_Lexer(ptr %184)
  %185 = load ptr, ptr %lex.373, align 8
  %186 = call i8 @lexer_current__Struct_Lexer(ptr %185)
  store i8 %186, ptr %value_char.387, align 1
  %187 = load i8, ptr %value_char.387, align 1
  %188 = icmp eq i8 %187, 92
  br i1 %188, label %label_321, label %label_323

label_323:                                        ; preds = %label_344, %label_318
  %189 = load ptr, ptr %lex.373, align 8
  call void @lexer_advance__Struct_Lexer(ptr %189)
  %190 = load ptr, ptr %lex.373, align 8
  %191 = call i8 @lexer_current__Struct_Lexer(ptr %190)
  %192 = icmp eq i8 %191, 39
  br i1 %192, label %label_345, label %label_347

label_321:                                        ; preds = %label_318
  %193 = load ptr, ptr %lex.373, align 8
  call void @lexer_advance__Struct_Lexer(ptr %193)
  %194 = load ptr, ptr %lex.373, align 8
  %195 = call i8 @lexer_current__Struct_Lexer(ptr %194)
  store i8 %195, ptr %esc.388, align 1
  %196 = load i8, ptr %esc.388, align 1
  %197 = icmp eq i8 %196, 110
  br i1 %197, label %label_324, label %label_326

label_326:                                        ; preds = %label_324, %label_321
  %198 = load i8, ptr %esc.388, align 1
  %199 = icmp eq i8 %198, 116
  br i1 %199, label %label_327, label %label_329

label_324:                                        ; preds = %label_321
  store i8 10, ptr %value_char.387, align 1
  br label %label_326

label_329:                                        ; preds = %label_327, %label_326
  %200 = load i8, ptr %esc.388, align 1
  %201 = icmp eq i8 %200, 114
  br i1 %201, label %label_330, label %label_332

label_327:                                        ; preds = %label_326
  store i8 9, ptr %value_char.387, align 1
  br label %label_329

label_332:                                        ; preds = %label_330, %label_329
  %202 = load i8, ptr %esc.388, align 1
  %203 = icmp eq i8 %202, 48
  br i1 %203, label %label_333, label %label_335

label_330:                                        ; preds = %label_329
  store i8 13, ptr %value_char.387, align 1
  br label %label_332

label_335:                                        ; preds = %label_333, %label_332
  %204 = load i8, ptr %esc.388, align 1
  %205 = icmp eq i8 %204, 92
  br i1 %205, label %label_336, label %label_338

label_333:                                        ; preds = %label_332
  store i8 0, ptr %value_char.387, align 1
  br label %label_335

label_338:                                        ; preds = %label_336, %label_335
  %206 = load i8, ptr %esc.388, align 1
  %207 = icmp eq i8 %206, 39
  br i1 %207, label %label_339, label %label_341

label_336:                                        ; preds = %label_335
  store i8 92, ptr %value_char.387, align 1
  br label %label_338

label_341:                                        ; preds = %label_339, %label_338
  %208 = load i8, ptr %esc.388, align 1
  %209 = icmp eq i8 %208, 34
  br i1 %209, label %label_342, label %label_344

label_339:                                        ; preds = %label_338
  store i8 39, ptr %value_char.387, align 1
  br label %label_341

label_344:                                        ; preds = %label_342, %label_341
  br label %label_323

label_342:                                        ; preds = %label_341
  store i8 34, ptr %value_char.387, align 1
  br label %label_344

label_347:                                        ; preds = %label_345, %label_323
  %210 = call ptr @malloc(i64 ptrtoint (ptr getelementptr (%Token, ptr null, i32 1) to i64))
  %211 = getelementptr inbounds nuw %Token, ptr %210, i32 0, i32 0
  store i32 1, ptr %211, align 4
  %212 = load i8, ptr %value_char.387, align 1
  %213 = call i32 @char_code__Char(i8 %212)
  %214 = call ptr @int_to_str(i32 %213)
  %215 = getelementptr inbounds nuw %Token, ptr %210, i32 0, i32 1
  store ptr %214, ptr %215, align 8
  %216 = load ptr, ptr %lex.373, align 8
  %217 = getelementptr inbounds nuw %Lexer, ptr %216, i32 0, i32 2
  %218 = load i32, ptr %217, align 4
  %219 = getelementptr inbounds nuw %Token, ptr %210, i32 0, i32 2
  store i32 %218, ptr %219, align 4
  %220 = getelementptr inbounds nuw %Token, ptr %210, i32 0, i32 3
  store ptr @.str.s58, ptr %220, align 8
  ret ptr %210

label_345:                                        ; preds = %label_323
  %221 = load ptr, ptr %lex.373, align 8
  call void @lexer_advance__Struct_Lexer(ptr %221)
  br label %label_347

label_350:                                        ; preds = %label_320
  %222 = load i8, ptr %c.374, align 1
  %223 = icmp eq i8 %222, 46
  store i1 %223, ptr %sc.39, align 1
  br i1 %223, label %label_465, label %label_466

label_348:                                        ; preds = %label_320
  %224 = load ptr, ptr %lex.373, align 8
  %225 = getelementptr inbounds nuw %Lexer, ptr %224, i32 0, i32 1
  %226 = load i32, ptr %225, align 4
  store i32 %226, ptr %start.389, align 4
  %227 = load ptr, ptr %lex.373, align 8
  call void @lexer_advance__Struct_Lexer(ptr %227)
  %228 = load ptr, ptr %lex.373, align 8
  %229 = call i8 @lexer_current__Struct_Lexer(ptr %228)
  store i8 %229, ptr %next.390, align 1
  %230 = load i8, ptr %c.374, align 1
  %231 = icmp eq i8 %230, 61
  store i1 %231, ptr %sc.15, align 1
  br i1 %231, label %label_351, label %label_352

label_352:                                        ; preds = %label_351, %label_348
  %232 = load i1, ptr %sc.15, align 1
  br i1 %232, label %label_353, label %label_355

label_351:                                        ; preds = %label_348
  %233 = load i8, ptr %next.390, align 1
  %234 = icmp eq i8 %233, 61
  store i1 %234, ptr %sc.15, align 1
  br label %label_352

label_355:                                        ; preds = %label_353, %label_352
  %235 = load i8, ptr %c.374, align 1
  %236 = icmp eq i8 %235, 33
  store i1 %236, ptr %sc.16, align 1
  br i1 %236, label %label_356, label %label_357

label_353:                                        ; preds = %label_352
  %237 = load ptr, ptr %lex.373, align 8
  call void @lexer_advance__Struct_Lexer(ptr %237)
  br label %label_355

label_357:                                        ; preds = %label_356, %label_355
  %238 = load i1, ptr %sc.16, align 1
  br i1 %238, label %label_358, label %label_360

label_356:                                        ; preds = %label_355
  %239 = load i8, ptr %next.390, align 1
  %240 = icmp eq i8 %239, 61
  store i1 %240, ptr %sc.16, align 1
  br label %label_357

label_360:                                        ; preds = %label_358, %label_357
  %241 = load i8, ptr %c.374, align 1
  %242 = icmp eq i8 %241, 60
  store i1 %242, ptr %sc.17, align 1
  br i1 %242, label %label_361, label %label_362

label_358:                                        ; preds = %label_357
  %243 = load ptr, ptr %lex.373, align 8
  call void @lexer_advance__Struct_Lexer(ptr %243)
  br label %label_360

label_362:                                        ; preds = %label_361, %label_360
  %244 = load i1, ptr %sc.17, align 1
  br i1 %244, label %label_363, label %label_365

label_361:                                        ; preds = %label_360
  %245 = load i8, ptr %next.390, align 1
  %246 = icmp eq i8 %245, 61
  store i1 %246, ptr %sc.17, align 1
  br label %label_362

label_365:                                        ; preds = %label_363, %label_362
  %247 = load i8, ptr %c.374, align 1
  %248 = icmp eq i8 %247, 62
  store i1 %248, ptr %sc.18, align 1
  br i1 %248, label %label_366, label %label_367

label_363:                                        ; preds = %label_362
  %249 = load ptr, ptr %lex.373, align 8
  call void @lexer_advance__Struct_Lexer(ptr %249)
  br label %label_365

label_367:                                        ; preds = %label_366, %label_365
  %250 = load i1, ptr %sc.18, align 1
  br i1 %250, label %label_368, label %label_370

label_366:                                        ; preds = %label_365
  %251 = load i8, ptr %next.390, align 1
  %252 = icmp eq i8 %251, 61
  store i1 %252, ptr %sc.18, align 1
  br label %label_367

label_370:                                        ; preds = %label_368, %label_367
  %253 = load i8, ptr %c.374, align 1
  %254 = icmp eq i8 %253, 38
  store i1 %254, ptr %sc.19, align 1
  br i1 %254, label %label_371, label %label_372

label_368:                                        ; preds = %label_367
  %255 = load ptr, ptr %lex.373, align 8
  call void @lexer_advance__Struct_Lexer(ptr %255)
  br label %label_370

label_372:                                        ; preds = %label_371, %label_370
  %256 = load i1, ptr %sc.19, align 1
  br i1 %256, label %label_373, label %label_375

label_371:                                        ; preds = %label_370
  %257 = load i8, ptr %next.390, align 1
  %258 = icmp eq i8 %257, 38
  store i1 %258, ptr %sc.19, align 1
  br label %label_372

label_375:                                        ; preds = %label_373, %label_372
  %259 = load i8, ptr %c.374, align 1
  %260 = icmp eq i8 %259, 124
  store i1 %260, ptr %sc.20, align 1
  br i1 %260, label %label_376, label %label_377

label_373:                                        ; preds = %label_372
  %261 = load ptr, ptr %lex.373, align 8
  call void @lexer_advance__Struct_Lexer(ptr %261)
  br label %label_375

label_377:                                        ; preds = %label_376, %label_375
  %262 = load i1, ptr %sc.20, align 1
  br i1 %262, label %label_378, label %label_380

label_376:                                        ; preds = %label_375
  %263 = load i8, ptr %next.390, align 1
  %264 = icmp eq i8 %263, 124
  store i1 %264, ptr %sc.20, align 1
  br label %label_377

label_380:                                        ; preds = %label_378, %label_377
  %265 = load i8, ptr %c.374, align 1
  %266 = icmp eq i8 %265, 45
  store i1 %266, ptr %sc.21, align 1
  br i1 %266, label %label_381, label %label_382

label_378:                                        ; preds = %label_377
  %267 = load ptr, ptr %lex.373, align 8
  call void @lexer_advance__Struct_Lexer(ptr %267)
  br label %label_380

label_382:                                        ; preds = %label_381, %label_380
  %268 = load i1, ptr %sc.21, align 1
  br i1 %268, label %label_383, label %label_385

label_381:                                        ; preds = %label_380
  %269 = load i8, ptr %next.390, align 1
  %270 = icmp eq i8 %269, 62
  store i1 %270, ptr %sc.21, align 1
  br label %label_382

label_385:                                        ; preds = %label_383, %label_382
  %271 = load i8, ptr %c.374, align 1
  %272 = icmp eq i8 %271, 61
  store i1 %272, ptr %sc.22, align 1
  br i1 %272, label %label_386, label %label_387

label_383:                                        ; preds = %label_382
  %273 = load ptr, ptr %lex.373, align 8
  call void @lexer_advance__Struct_Lexer(ptr %273)
  br label %label_385

label_387:                                        ; preds = %label_386, %label_385
  %274 = load i1, ptr %sc.22, align 1
  br i1 %274, label %label_388, label %label_390

label_386:                                        ; preds = %label_385
  %275 = load i8, ptr %next.390, align 1
  %276 = icmp eq i8 %275, 62
  store i1 %276, ptr %sc.22, align 1
  br label %label_387

label_390:                                        ; preds = %label_388, %label_387
  %277 = load i8, ptr %c.374, align 1
  %278 = icmp eq i8 %277, 60
  store i1 %278, ptr %sc.23, align 1
  br i1 %278, label %label_391, label %label_392

label_388:                                        ; preds = %label_387
  %279 = load ptr, ptr %lex.373, align 8
  call void @lexer_advance__Struct_Lexer(ptr %279)
  br label %label_390

label_392:                                        ; preds = %label_391, %label_390
  %280 = load i1, ptr %sc.23, align 1
  br i1 %280, label %label_393, label %label_395

label_391:                                        ; preds = %label_390
  %281 = load i8, ptr %next.390, align 1
  %282 = icmp eq i8 %281, 60
  store i1 %282, ptr %sc.23, align 1
  br label %label_392

label_395:                                        ; preds = %label_393, %label_392
  %283 = load i8, ptr %c.374, align 1
  %284 = icmp eq i8 %283, 62
  store i1 %284, ptr %sc.24, align 1
  br i1 %284, label %label_396, label %label_397

label_393:                                        ; preds = %label_392
  %285 = load ptr, ptr %lex.373, align 8
  call void @lexer_advance__Struct_Lexer(ptr %285)
  br label %label_395

label_397:                                        ; preds = %label_396, %label_395
  %286 = load i1, ptr %sc.24, align 1
  br i1 %286, label %label_398, label %label_400

label_396:                                        ; preds = %label_395
  %287 = load i8, ptr %next.390, align 1
  %288 = icmp eq i8 %287, 62
  store i1 %288, ptr %sc.24, align 1
  br label %label_397

label_400:                                        ; preds = %label_398, %label_397
  %289 = load i8, ptr %next.390, align 1
  %290 = icmp eq i8 %289, 61
  br i1 %290, label %label_401, label %label_403

label_398:                                        ; preds = %label_397
  %291 = load ptr, ptr %lex.373, align 8
  call void @lexer_advance__Struct_Lexer(ptr %291)
  br label %label_400

label_403:                                        ; preds = %label_421, %label_400
  %292 = load ptr, ptr %lex.373, align 8
  %293 = getelementptr inbounds nuw %Lexer, ptr %292, i32 0, i32 1
  %294 = load i32, ptr %293, align 4
  %295 = load i32, ptr %start.389, align 4
  %296 = sub i32 %294, %295
  store i32 %296, ptr %length.391, align 4
  %297 = load ptr, ptr %lex.373, align 8
  %298 = getelementptr inbounds nuw %Lexer, ptr %297, i32 0, i32 0
  %299 = load ptr, ptr %298, align 8
  %300 = load i32, ptr %start.389, align 4
  %301 = load i32, ptr %length.391, align 4
  %302 = call ptr @str_substring(ptr %299, i32 %300, i32 %301)
  store ptr %302, ptr %value.392, align 8
  store i32 8, ptr %type.393, align 4
  %303 = load i32, ptr %length.391, align 4
  %304 = icmp eq i32 %303, 2
  br i1 %304, label %label_422, label %label_423

label_401:                                        ; preds = %label_400
  %305 = load i8, ptr %c.374, align 1
  %306 = icmp eq i8 %305, 43
  store i1 %306, ptr %sc.28, align 1
  br i1 %306, label %label_411, label %label_410

label_410:                                        ; preds = %label_401
  %307 = load i8, ptr %c.374, align 1
  %308 = icmp eq i8 %307, 45
  store i1 %308, ptr %sc.28, align 1
  br label %label_411

label_411:                                        ; preds = %label_410, %label_401
  %309 = load i1, ptr %sc.28, align 1
  store i1 %309, ptr %sc.27, align 1
  br i1 %309, label %label_409, label %label_408

label_408:                                        ; preds = %label_411
  %310 = load i8, ptr %c.374, align 1
  %311 = icmp eq i8 %310, 42
  store i1 %311, ptr %sc.27, align 1
  br label %label_409

label_409:                                        ; preds = %label_408, %label_411
  %312 = load i1, ptr %sc.27, align 1
  store i1 %312, ptr %sc.26, align 1
  br i1 %312, label %label_407, label %label_406

label_406:                                        ; preds = %label_409
  %313 = load i8, ptr %c.374, align 1
  %314 = icmp eq i8 %313, 47
  store i1 %314, ptr %sc.26, align 1
  br label %label_407

label_407:                                        ; preds = %label_406, %label_409
  %315 = load i1, ptr %sc.26, align 1
  store i1 %315, ptr %sc.25, align 1
  br i1 %315, label %label_405, label %label_404

label_404:                                        ; preds = %label_407
  %316 = load i8, ptr %c.374, align 1
  %317 = icmp eq i8 %316, 37
  store i1 %317, ptr %sc.25, align 1
  br label %label_405

label_405:                                        ; preds = %label_404, %label_407
  %318 = load i1, ptr %sc.25, align 1
  br i1 %318, label %label_412, label %label_414

label_414:                                        ; preds = %label_412, %label_405
  %319 = load i8, ptr %c.374, align 1
  %320 = icmp eq i8 %319, 38
  store i1 %320, ptr %sc.30, align 1
  br i1 %320, label %label_418, label %label_417

label_412:                                        ; preds = %label_405
  %321 = load ptr, ptr %lex.373, align 8
  call void @lexer_advance__Struct_Lexer(ptr %321)
  br label %label_414

label_417:                                        ; preds = %label_414
  %322 = load i8, ptr %c.374, align 1
  %323 = icmp eq i8 %322, 124
  store i1 %323, ptr %sc.30, align 1
  br label %label_418

label_418:                                        ; preds = %label_417, %label_414
  %324 = load i1, ptr %sc.30, align 1
  store i1 %324, ptr %sc.29, align 1
  br i1 %324, label %label_416, label %label_415

label_415:                                        ; preds = %label_418
  %325 = load i8, ptr %c.374, align 1
  %326 = icmp eq i8 %325, 94
  store i1 %326, ptr %sc.29, align 1
  br label %label_416

label_416:                                        ; preds = %label_415, %label_418
  %327 = load i1, ptr %sc.29, align 1
  br i1 %327, label %label_419, label %label_421

label_421:                                        ; preds = %label_419, %label_416
  br label %label_403

label_419:                                        ; preds = %label_416
  %328 = load ptr, ptr %lex.373, align 8
  call void @lexer_advance__Struct_Lexer(ptr %328)
  br label %label_421

label_423:                                        ; preds = %label_403
  %329 = load i8, ptr %c.374, align 1
  %330 = icmp eq i8 %329, 60
  store i1 %330, ptr %sc.38, align 1
  br i1 %330, label %label_455, label %label_454

label_422:                                        ; preds = %label_403
  %331 = load ptr, ptr %value.392, align 8
  %332 = call i32 @str_equals(ptr %331, ptr @.str.s59)
  %333 = icmp eq i32 %332, 1
  store i1 %333, ptr %sc.33, align 1
  br i1 %333, label %label_430, label %label_429

label_429:                                        ; preds = %label_422
  %334 = load ptr, ptr %value.392, align 8
  %335 = call i32 @str_equals(ptr %334, ptr @.str.s60)
  %336 = icmp eq i32 %335, 1
  store i1 %336, ptr %sc.33, align 1
  br label %label_430

label_430:                                        ; preds = %label_429, %label_422
  %337 = load i1, ptr %sc.33, align 1
  store i1 %337, ptr %sc.32, align 1
  br i1 %337, label %label_428, label %label_427

label_427:                                        ; preds = %label_430
  %338 = load ptr, ptr %value.392, align 8
  %339 = call i32 @str_equals(ptr %338, ptr @.str.s61)
  %340 = icmp eq i32 %339, 1
  store i1 %340, ptr %sc.32, align 1
  br label %label_428

label_428:                                        ; preds = %label_427, %label_430
  %341 = load i1, ptr %sc.32, align 1
  store i1 %341, ptr %sc.31, align 1
  br i1 %341, label %label_426, label %label_425

label_425:                                        ; preds = %label_428
  %342 = load ptr, ptr %value.392, align 8
  %343 = call i32 @str_equals(ptr %342, ptr @.str.s62)
  %344 = icmp eq i32 %343, 1
  store i1 %344, ptr %sc.31, align 1
  br label %label_426

label_426:                                        ; preds = %label_425, %label_428
  %345 = load i1, ptr %sc.31, align 1
  br i1 %345, label %label_431, label %label_433

label_433:                                        ; preds = %label_431, %label_426
  %346 = load ptr, ptr %value.392, align 8
  %347 = call i32 @str_equals(ptr %346, ptr @.str.s63)
  %348 = icmp eq i32 %347, 1
  store i1 %348, ptr %sc.34, align 1
  br i1 %348, label %label_435, label %label_434

label_431:                                        ; preds = %label_426
  store i32 9, ptr %type.393, align 4
  br label %label_433

label_434:                                        ; preds = %label_433
  %349 = load ptr, ptr %value.392, align 8
  %350 = call i32 @str_equals(ptr %349, ptr @.str.s64)
  %351 = icmp eq i32 %350, 1
  store i1 %351, ptr %sc.34, align 1
  br label %label_435

label_435:                                        ; preds = %label_434, %label_433
  %352 = load i1, ptr %sc.34, align 1
  br i1 %352, label %label_436, label %label_438

label_438:                                        ; preds = %label_441, %label_435
  %353 = load ptr, ptr %value.392, align 8
  %354 = call i8 @str_char_at(ptr %353, i32 1)
  %355 = icmp eq i8 %354, 61
  store i1 %355, ptr %sc.35, align 1
  br i1 %355, label %label_442, label %label_443

label_436:                                        ; preds = %label_435
  store i32 15, ptr %type.393, align 4
  %356 = load ptr, ptr %value.392, align 8
  %357 = call i32 @str_equals(ptr %356, ptr @.str.s65)
  %358 = icmp eq i32 %357, 1
  br i1 %358, label %label_439, label %label_441

label_441:                                        ; preds = %label_439, %label_436
  br label %label_438

label_439:                                        ; preds = %label_436
  store i32 16, ptr %type.393, align 4
  br label %label_441

label_443:                                        ; preds = %label_442, %label_438
  %359 = load i1, ptr %sc.35, align 1
  br i1 %359, label %label_444, label %label_446

label_442:                                        ; preds = %label_438
  %360 = load ptr, ptr %value.392, align 8
  %361 = call i8 @str_char_at(ptr %360, i32 0)
  %362 = icmp ne i8 %361, 61
  store i1 %362, ptr %sc.35, align 1
  br label %label_443

label_446:                                        ; preds = %label_453, %label_443
  br label %label_424

label_444:                                        ; preds = %label_443
  %363 = load ptr, ptr %value.392, align 8
  %364 = call i32 @str_equals(ptr %363, ptr @.str.s66)
  %365 = icmp eq i32 %364, 0
  store i1 %365, ptr %sc.37, align 1
  br i1 %365, label %label_449, label %label_450

label_450:                                        ; preds = %label_449, %label_444
  %366 = load i1, ptr %sc.37, align 1
  store i1 %366, ptr %sc.36, align 1
  br i1 %366, label %label_447, label %label_448

label_449:                                        ; preds = %label_444
  %367 = load ptr, ptr %value.392, align 8
  %368 = call i32 @str_equals(ptr %367, ptr @.str.s67)
  %369 = icmp eq i32 %368, 0
  store i1 %369, ptr %sc.37, align 1
  br label %label_450

label_448:                                        ; preds = %label_447, %label_450
  %370 = load i1, ptr %sc.36, align 1
  br i1 %370, label %label_451, label %label_453

label_447:                                        ; preds = %label_450
  %371 = load ptr, ptr %value.392, align 8
  %372 = call i32 @str_equals(ptr %371, ptr @.str.s68)
  %373 = icmp eq i32 %372, 0
  store i1 %373, ptr %sc.36, align 1
  br label %label_448

label_453:                                        ; preds = %label_451, %label_448
  br label %label_446

label_451:                                        ; preds = %label_448
  store i32 12, ptr %type.393, align 4
  br label %label_453

label_424:                                        ; preds = %label_464, %label_446
  %374 = call ptr @malloc(i64 ptrtoint (ptr getelementptr (%Token, ptr null, i32 1) to i64))
  %375 = load i32, ptr %type.393, align 4
  %376 = getelementptr inbounds nuw %Token, ptr %374, i32 0, i32 0
  store i32 %375, ptr %376, align 4
  %377 = load ptr, ptr %value.392, align 8
  %378 = getelementptr inbounds nuw %Token, ptr %374, i32 0, i32 1
  store ptr %377, ptr %378, align 8
  %379 = load ptr, ptr %lex.373, align 8
  %380 = getelementptr inbounds nuw %Lexer, ptr %379, i32 0, i32 2
  %381 = load i32, ptr %380, align 4
  %382 = getelementptr inbounds nuw %Token, ptr %374, i32 0, i32 2
  store i32 %381, ptr %382, align 4
  %383 = getelementptr inbounds nuw %Token, ptr %374, i32 0, i32 3
  store ptr @.str.s69, ptr %383, align 8
  ret ptr %374

label_454:                                        ; preds = %label_423
  %384 = load i8, ptr %c.374, align 1
  %385 = icmp eq i8 %384, 62
  store i1 %385, ptr %sc.38, align 1
  br label %label_455

label_455:                                        ; preds = %label_454, %label_423
  %386 = load i1, ptr %sc.38, align 1
  br i1 %386, label %label_456, label %label_458

label_458:                                        ; preds = %label_456, %label_455
  %387 = load i8, ptr %c.374, align 1
  %388 = icmp eq i8 %387, 61
  br i1 %388, label %label_459, label %label_461

label_456:                                        ; preds = %label_455
  store i32 9, ptr %type.393, align 4
  br label %label_458

label_461:                                        ; preds = %label_459, %label_458
  %389 = load i8, ptr %c.374, align 1
  %390 = icmp eq i8 %389, 33
  br i1 %390, label %label_462, label %label_464

label_459:                                        ; preds = %label_458
  store i32 12, ptr %type.393, align 4
  br label %label_461

label_464:                                        ; preds = %label_462, %label_461
  br label %label_424

label_462:                                        ; preds = %label_461
  store i32 10, ptr %type.393, align 4
  br label %label_464

label_466:                                        ; preds = %label_465, %label_350
  %391 = load i1, ptr %sc.39, align 1
  br i1 %391, label %label_467, label %label_469

label_465:                                        ; preds = %label_350
  %392 = load ptr, ptr %lex.373, align 8
  %393 = call i8 @lexer_peek__Struct_Lexer_Int(ptr %392, i32 1)
  %394 = icmp eq i8 %393, 46
  store i1 %394, ptr %sc.39, align 1
  br label %label_466

label_469:                                        ; preds = %label_466
  %395 = load i8, ptr %c.374, align 1
  %396 = call i1 @is_separator__Char(i8 %395)
  br i1 %396, label %label_470, label %label_472

label_467:                                        ; preds = %label_466
  %397 = load ptr, ptr %lex.373, align 8
  call void @lexer_advance__Struct_Lexer(ptr %397)
  %398 = load ptr, ptr %lex.373, align 8
  call void @lexer_advance__Struct_Lexer(ptr %398)
  %399 = call ptr @malloc(i64 ptrtoint (ptr getelementptr (%Token, ptr null, i32 1) to i64))
  %400 = getelementptr inbounds nuw %Token, ptr %399, i32 0, i32 0
  store i32 17, ptr %400, align 4
  %401 = getelementptr inbounds nuw %Token, ptr %399, i32 0, i32 1
  store ptr @.str.s70, ptr %401, align 8
  %402 = load ptr, ptr %lex.373, align 8
  %403 = getelementptr inbounds nuw %Lexer, ptr %402, i32 0, i32 2
  %404 = load i32, ptr %403, align 4
  %405 = getelementptr inbounds nuw %Token, ptr %399, i32 0, i32 2
  store i32 %404, ptr %405, align 4
  %406 = getelementptr inbounds nuw %Token, ptr %399, i32 0, i32 3
  store ptr @.str.s71, ptr %406, align 8
  ret ptr %399

label_472:                                        ; preds = %label_469
  %407 = load ptr, ptr %lex.373, align 8
  call void @lexer_advance__Struct_Lexer(ptr %407)
  %408 = call ptr @malloc(i64 ptrtoint (ptr getelementptr (%Token, ptr null, i32 1) to i64))
  %409 = getelementptr inbounds nuw %Token, ptr %408, i32 0, i32 0
  store i32 19, ptr %409, align 4
  %410 = getelementptr inbounds nuw %Token, ptr %408, i32 0, i32 1
  store ptr @.str.s73, ptr %410, align 8
  %411 = load ptr, ptr %lex.373, align 8
  %412 = getelementptr inbounds nuw %Lexer, ptr %411, i32 0, i32 2
  %413 = load i32, ptr %412, align 4
  %414 = getelementptr inbounds nuw %Token, ptr %408, i32 0, i32 2
  store i32 %413, ptr %414, align 4
  %415 = getelementptr inbounds nuw %Token, ptr %408, i32 0, i32 3
  store ptr @.str.s74, ptr %415, align 8
  ret ptr %408

label_470:                                        ; preds = %label_469
  %416 = load ptr, ptr %lex.373, align 8
  %417 = getelementptr inbounds nuw %Lexer, ptr %416, i32 0, i32 0
  %418 = load ptr, ptr %417, align 8
  %419 = load ptr, ptr %lex.373, align 8
  %420 = getelementptr inbounds nuw %Lexer, ptr %419, i32 0, i32 1
  %421 = load i32, ptr %420, align 4
  %422 = call ptr @str_substring(ptr %418, i32 %421, i32 1)
  store ptr %422, ptr %val.394, align 8
  %423 = load ptr, ptr %lex.373, align 8
  call void @lexer_advance__Struct_Lexer(ptr %423)
  %424 = call ptr @malloc(i64 ptrtoint (ptr getelementptr (%Token, ptr null, i32 1) to i64))
  %425 = getelementptr inbounds nuw %Token, ptr %424, i32 0, i32 0
  store i32 6, ptr %425, align 4
  %426 = load ptr, ptr %val.394, align 8
  %427 = getelementptr inbounds nuw %Token, ptr %424, i32 0, i32 1
  store ptr %426, ptr %427, align 8
  %428 = load ptr, ptr %lex.373, align 8
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
  %lex.395 = alloca ptr, align 8
  store ptr %0, ptr %lex.395, align 8
  %1 = load ptr, ptr %lex.395, align 8
  %2 = call ptr @lexer_next_token__Struct_Lexer(ptr %1)
  %3 = call ptr @token_to_ptr(ptr %2)
  %head_ptr.396 = alloca ptr, align 8
  store ptr %3, ptr %head_ptr.396, align 8
  %4 = load ptr, ptr %head_ptr.396, align 8
  %current_ptr.397 = alloca ptr, align 8
  store ptr %4, ptr %current_ptr.397, align 8
  %scanning.398 = alloca i1, align 1
  store i1 true, ptr %scanning.398, align 1
  %current.399 = alloca ptr, align 8
  %next_ptr.400 = alloca ptr, align 8
  br label %label_473

label_473:                                        ; preds = %label_478, %entry
  %5 = load i1, ptr %scanning.398, align 1
  br i1 %5, label %label_474, label %label_475

label_475:                                        ; preds = %label_473
  %6 = load ptr, ptr %head_ptr.396, align 8
  %7 = call ptr @ptr_to_token(ptr %6)
  ret ptr %7

label_474:                                        ; preds = %label_473
  %8 = load ptr, ptr %current_ptr.397, align 8
  %9 = call ptr @ptr_to_token(ptr %8)
  store ptr %9, ptr %current.399, align 8
  %10 = load ptr, ptr %current.399, align 8
  %11 = getelementptr inbounds nuw %Token, ptr %10, i32 0, i32 0
  %12 = load i32, ptr %11, align 4
  %13 = icmp eq i32 %12, 20
  br i1 %13, label %label_476, label %label_477

label_477:                                        ; preds = %label_474
  %14 = load ptr, ptr %lex.395, align 8
  %15 = call ptr @lexer_next_token__Struct_Lexer(ptr %14)
  %16 = call ptr @token_to_ptr(ptr %15)
  store ptr %16, ptr %next_ptr.400, align 8
  %17 = load ptr, ptr %current.399, align 8
  %18 = load ptr, ptr %next_ptr.400, align 8
  %19 = getelementptr inbounds nuw %Token, ptr %17, i32 0, i32 3
  store ptr %18, ptr %19, align 8
  %20 = load ptr, ptr %next_ptr.400, align 8
  store ptr %20, ptr %current_ptr.397, align 8
  br label %label_478

label_476:                                        ; preds = %label_474
  store i1 false, ptr %scanning.398, align 1
  br label %label_478

label_478:                                        ; preds = %label_477, %label_476
  br label %label_473
}

define ptr @create_node__Enum_NodeKind(i32 %0) {
entry:
  %kind.401 = alloca i32, align 4
  store i32 %0, ptr %kind.401, align 4
  %1 = call ptr @malloc(i64 ptrtoint (ptr getelementptr (%ASTNode, ptr null, i32 1) to i64))
  %2 = load i32, ptr %kind.401, align 4
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
  %tokens.402 = alloca ptr, align 8
  store ptr %0, ptr %tokens.402, align 8
  %1 = call ptr @malloc(i64 ptrtoint (ptr getelementptr (%Parser, ptr null, i32 1) to i64))
  %2 = load ptr, ptr %tokens.402, align 8
  %3 = call ptr @token_to_ptr(ptr %2)
  %4 = getelementptr inbounds nuw %Parser, ptr %1, i32 0, i32 0
  store ptr %3, ptr %4, align 8
  ret ptr %1
}

define ptr @parser_current__Struct_Parser(ptr %0) {
entry:
  %p.403 = alloca ptr, align 8
  store ptr %0, ptr %p.403, align 8
  %1 = load ptr, ptr %p.403, align 8
  %2 = getelementptr inbounds nuw %Parser, ptr %1, i32 0, i32 0
  %3 = load ptr, ptr %2, align 8
  %4 = call ptr @ptr_to_token(ptr %3)
  ret ptr %4
}

define ptr @parser_peek__Struct_Parser(ptr %0) {
entry:
  %p.404 = alloca ptr, align 8
  store ptr %0, ptr %p.404, align 8
  %1 = load ptr, ptr %p.404, align 8
  %2 = getelementptr inbounds nuw %Parser, ptr %1, i32 0, i32 0
  %3 = load ptr, ptr %2, align 8
  %4 = call ptr @ptr_to_token(ptr %3)
  %curr.405 = alloca ptr, align 8
  store ptr %4, ptr %curr.405, align 8
  %5 = load ptr, ptr %curr.405, align 8
  %6 = getelementptr inbounds nuw %Token, ptr %5, i32 0, i32 3
  %7 = load ptr, ptr %6, align 8
  %8 = call ptr @ptr_to_token(ptr %7)
  ret ptr %8
}

define void @parser_advance__Struct_Parser(ptr %0) {
entry:
  %p.406 = alloca ptr, align 8
  store ptr %0, ptr %p.406, align 8
  %1 = load ptr, ptr %p.406, align 8
  %2 = getelementptr inbounds nuw %Parser, ptr %1, i32 0, i32 0
  %3 = load ptr, ptr %2, align 8
  %4 = call ptr @ptr_to_token(ptr %3)
  %curr.407 = alloca ptr, align 8
  store ptr %4, ptr %curr.407, align 8
  %5 = load ptr, ptr %curr.407, align 8
  %6 = getelementptr inbounds nuw %Token, ptr %5, i32 0, i32 0
  %7 = load i32, ptr %6, align 4
  %8 = icmp ne i32 %7, 20
  br i1 %8, label %label_479, label %label_481

label_481:                                        ; preds = %label_479, %entry
  ret void

label_479:                                        ; preds = %entry
  %9 = load ptr, ptr %p.406, align 8
  %10 = load ptr, ptr %curr.407, align 8
  %11 = getelementptr inbounds nuw %Token, ptr %10, i32 0, i32 3
  %12 = load ptr, ptr %11, align 8
  %13 = getelementptr inbounds nuw %Parser, ptr %9, i32 0, i32 0
  store ptr %12, ptr %13, align 8
  br label %label_481
}

define i1 @parser_check__Struct_Parser_Enum_TokenType(ptr %0, i32 %1) {
entry:
  %p.408 = alloca ptr, align 8
  store ptr %0, ptr %p.408, align 8
  %t.409 = alloca i32, align 4
  store i32 %1, ptr %t.409, align 4
  %2 = load ptr, ptr %p.408, align 8
  %3 = call ptr @parser_current__Struct_Parser(ptr %2)
  %curr.410 = alloca ptr, align 8
  store ptr %3, ptr %curr.410, align 8
  %4 = load ptr, ptr %curr.410, align 8
  %5 = getelementptr inbounds nuw %Token, ptr %4, i32 0, i32 0
  %6 = load i32, ptr %5, align 4
  %7 = load i32, ptr %t.409, align 4
  %8 = icmp eq i32 %6, %7
  ret i1 %8
}

define i1 @parser_check_val__Struct_Parser_Enum_TokenType_String(ptr %0, i32 %1, ptr %2) {
entry:
  %p.411 = alloca ptr, align 8
  store ptr %0, ptr %p.411, align 8
  %t.412 = alloca i32, align 4
  store i32 %1, ptr %t.412, align 4
  %val.413 = alloca ptr, align 8
  store ptr %2, ptr %val.413, align 8
  %3 = load ptr, ptr %p.411, align 8
  %4 = call ptr @parser_current__Struct_Parser(ptr %3)
  %curr.414 = alloca ptr, align 8
  store ptr %4, ptr %curr.414, align 8
  %sc.40 = alloca i1, align 1
  %5 = load ptr, ptr %curr.414, align 8
  %6 = getelementptr inbounds nuw %Token, ptr %5, i32 0, i32 0
  %7 = load i32, ptr %6, align 4
  %8 = load i32, ptr %t.412, align 4
  %9 = icmp eq i32 %7, %8
  store i1 %9, ptr %sc.40, align 1
  br i1 %9, label %label_482, label %label_483

label_483:                                        ; preds = %label_482, %entry
  %10 = load i1, ptr %sc.40, align 1
  ret i1 %10

label_482:                                        ; preds = %entry
  %11 = load ptr, ptr %curr.414, align 8
  %12 = getelementptr inbounds nuw %Token, ptr %11, i32 0, i32 1
  %13 = load ptr, ptr %12, align 8
  %14 = load ptr, ptr %val.413, align 8
  %15 = call i32 @str_equals(ptr %13, ptr %14)
  %16 = icmp eq i32 %15, 1
  store i1 %16, ptr %sc.40, align 1
  br label %label_483
}

define i1 @parser_match__Struct_Parser_Enum_TokenType(ptr %0, i32 %1) {
entry:
  %p.415 = alloca ptr, align 8
  store ptr %0, ptr %p.415, align 8
  %t.416 = alloca i32, align 4
  store i32 %1, ptr %t.416, align 4
  %2 = load ptr, ptr %p.415, align 8
  %3 = load i32, ptr %t.416, align 4
  %4 = call i1 @parser_check__Struct_Parser_Enum_TokenType(ptr %2, i32 %3)
  br i1 %4, label %label_484, label %label_486

label_486:                                        ; preds = %entry
  ret i1 false

label_484:                                        ; preds = %entry
  %5 = load ptr, ptr %p.415, align 8
  call void @parser_advance__Struct_Parser(ptr %5)
  ret i1 true
}

define i1 @parser_match_val__Struct_Parser_Enum_TokenType_String(ptr %0, i32 %1, ptr %2) {
entry:
  %p.417 = alloca ptr, align 8
  store ptr %0, ptr %p.417, align 8
  %t.418 = alloca i32, align 4
  store i32 %1, ptr %t.418, align 4
  %val.419 = alloca ptr, align 8
  store ptr %2, ptr %val.419, align 8
  %3 = load ptr, ptr %p.417, align 8
  %4 = load i32, ptr %t.418, align 4
  %5 = load ptr, ptr %val.419, align 8
  %6 = call i1 @parser_check_val__Struct_Parser_Enum_TokenType_String(ptr %3, i32 %4, ptr %5)
  br i1 %6, label %label_487, label %label_489

label_489:                                        ; preds = %entry
  ret i1 false

label_487:                                        ; preds = %entry
  %7 = load ptr, ptr %p.417, align 8
  call void @parser_advance__Struct_Parser(ptr %7)
  ret i1 true
}

define void @parser_expect__Struct_Parser_Enum_TokenType_String(ptr %0, i32 %1, ptr %2) {
entry:
  %p.420 = alloca ptr, align 8
  store ptr %0, ptr %p.420, align 8
  %t.421 = alloca i32, align 4
  store i32 %1, ptr %t.421, align 4
  %context.422 = alloca ptr, align 8
  store ptr %2, ptr %context.422, align 8
  %3 = load ptr, ptr %p.420, align 8
  %4 = load i32, ptr %t.421, align 4
  %5 = call i1 @parser_check__Struct_Parser_Enum_TokenType(ptr %3, i32 %4)
  %6 = icmp eq i1 %5, false
  br i1 %6, label %label_490, label %label_492

label_492:                                        ; preds = %label_490, %entry
  %7 = load ptr, ptr %p.420, align 8
  call void @parser_advance__Struct_Parser(ptr %7)
  ret void

label_490:                                        ; preds = %entry
  call void @print(ptr @.str.s82)
  %8 = load ptr, ptr %context.422, align 8
  call void @print(ptr %8)
  call void @print(ptr @.str.s83)
  %9 = load i32, ptr %t.421, align 4
  call void @println_int(i32 %9)
  call void @exit(i32 1)
  br label %label_492
}

define void @parser_expect_val__Struct_Parser_Enum_TokenType_String_String(ptr %0, i32 %1, ptr %2, ptr %3) {
entry:
  %p.423 = alloca ptr, align 8
  store ptr %0, ptr %p.423, align 8
  %t.424 = alloca i32, align 4
  store i32 %1, ptr %t.424, align 4
  %val.425 = alloca ptr, align 8
  store ptr %2, ptr %val.425, align 8
  %context.426 = alloca ptr, align 8
  store ptr %3, ptr %context.426, align 8
  %4 = load ptr, ptr %p.423, align 8
  %5 = load i32, ptr %t.424, align 4
  %6 = load ptr, ptr %val.425, align 8
  %7 = call i1 @parser_check_val__Struct_Parser_Enum_TokenType_String(ptr %4, i32 %5, ptr %6)
  %8 = icmp eq i1 %7, false
  br i1 %8, label %label_493, label %label_495

label_495:                                        ; preds = %label_493, %entry
  %9 = load ptr, ptr %p.423, align 8
  call void @parser_advance__Struct_Parser(ptr %9)
  ret void

label_493:                                        ; preds = %entry
  call void @print(ptr @.str.s84)
  %10 = load ptr, ptr %context.426, align 8
  call void @print(ptr %10)
  call void @print(ptr @.str.s85)
  %11 = load ptr, ptr %val.425, align 8
  call void @print(ptr %11)
  call void @println(ptr @.str.s86)
  call void @exit(i32 1)
  br label %label_495
}

define ptr @parse_import_statement__Struct_Parser(ptr %0) {
entry:
  %p.427 = alloca ptr, align 8
  store ptr %0, ptr %p.427, align 8
  %1 = load ptr, ptr %p.427, align 8
  call void @parser_expect_val__Struct_Parser_Enum_TokenType_String_String(ptr %1, i32 18, ptr @.str.s87, ptr @.str.s88)
  %2 = call ptr @create_node__Enum_NodeKind(i32 1)
  %import_node.428 = alloca ptr, align 8
  store ptr %2, ptr %import_node.428, align 8
  %3 = load ptr, ptr %p.427, align 8
  %4 = call ptr @parser_current__Struct_Parser(ptr %3)
  %curr.429 = alloca ptr, align 8
  store ptr %4, ptr %curr.429, align 8
  %5 = load ptr, ptr %import_node.428, align 8
  %6 = load ptr, ptr %curr.429, align 8
  %7 = getelementptr inbounds nuw %Token, ptr %6, i32 0, i32 1
  %8 = load ptr, ptr %7, align 8
  %9 = getelementptr inbounds nuw %ASTNode, ptr %5, i32 0, i32 1
  store ptr %8, ptr %9, align 8
  %sc.41 = alloca i1, align 1
  %10 = load ptr, ptr %curr.429, align 8
  %11 = getelementptr inbounds nuw %Token, ptr %10, i32 0, i32 0
  %12 = load i32, ptr %11, align 4
  %13 = icmp eq i32 %12, 5
  store i1 %13, ptr %sc.41, align 1
  br i1 %13, label %label_497, label %label_496

label_496:                                        ; preds = %entry
  %14 = load ptr, ptr %curr.429, align 8
  %15 = getelementptr inbounds nuw %Token, ptr %14, i32 0, i32 0
  %16 = load i32, ptr %15, align 4
  %17 = icmp eq i32 %16, 18
  store i1 %17, ptr %sc.41, align 1
  br label %label_497

label_497:                                        ; preds = %label_496, %entry
  %18 = load i1, ptr %sc.41, align 1
  br i1 %18, label %label_498, label %label_499

label_499:                                        ; preds = %label_497
  call void @println(ptr @.str.s89)
  call void @exit(i32 1)
  br label %label_500

label_498:                                        ; preds = %label_497
  %19 = load ptr, ptr %p.427, align 8
  call void @parser_advance__Struct_Parser(ptr %19)
  br label %label_500

label_500:                                        ; preds = %label_499, %label_498
  %20 = load ptr, ptr %import_node.428, align 8
  ret ptr %20
}

define ptr @parse_declaration__Struct_Parser(ptr %0) {
entry:
  %p.430 = alloca ptr, align 8
  store ptr %0, ptr %p.430, align 8
  %1 = load ptr, ptr %p.430, align 8
  %2 = call i1 @parser_check_val__Struct_Parser_Enum_TokenType_String(ptr %1, i32 18, ptr @.str.s90)
  br i1 %2, label %label_501, label %label_503

label_503:                                        ; preds = %entry
  %3 = load ptr, ptr %p.430, align 8
  %4 = call i1 @parser_check_val__Struct_Parser_Enum_TokenType_String(ptr %3, i32 18, ptr @.str.s91)
  br i1 %4, label %label_504, label %label_506

label_501:                                        ; preds = %entry
  %5 = load ptr, ptr %p.430, align 8
  %6 = call ptr @parse_import_statement__Struct_Parser(ptr %5)
  ret ptr %6

label_506:                                        ; preds = %label_503
  %7 = load ptr, ptr %p.430, align 8
  %8 = call i1 @parser_check_val__Struct_Parser_Enum_TokenType_String(ptr %7, i32 18, ptr @.str.s92)
  br i1 %8, label %label_507, label %label_509

label_504:                                        ; preds = %label_503
  %9 = load ptr, ptr %p.430, align 8
  %10 = call ptr @parse_variable_decl__Struct_Parser(ptr %9)
  ret ptr %10

label_509:                                        ; preds = %label_506
  %11 = load ptr, ptr %p.430, align 8
  %12 = call i1 @parser_check_val__Struct_Parser_Enum_TokenType_String(ptr %11, i32 18, ptr @.str.s93)
  br i1 %12, label %label_510, label %label_512

label_507:                                        ; preds = %label_506
  %13 = load ptr, ptr %p.430, align 8
  %14 = call ptr @parse_extern_fn_decl__Struct_Parser(ptr %13)
  ret ptr %14

label_512:                                        ; preds = %label_509
  %15 = load ptr, ptr %p.430, align 8
  %16 = call i1 @parser_check_val__Struct_Parser_Enum_TokenType_String(ptr %15, i32 18, ptr @.str.s94)
  br i1 %16, label %label_513, label %label_515

label_510:                                        ; preds = %label_509
  %17 = load ptr, ptr %p.430, align 8
  %18 = call ptr @parse_function_decl__Struct_Parser(ptr %17)
  ret ptr %18

label_515:                                        ; preds = %label_512
  %19 = load ptr, ptr %p.430, align 8
  %20 = call i1 @parser_check_val__Struct_Parser_Enum_TokenType_String(ptr %19, i32 18, ptr @.str.s95)
  br i1 %20, label %label_516, label %label_518

label_513:                                        ; preds = %label_512
  %21 = load ptr, ptr %p.430, align 8
  %22 = call ptr @parse_struct_decl__Struct_Parser(ptr %21)
  ret ptr %22

label_518:                                        ; preds = %label_515
  call void @println(ptr @.str.s96)
  call void @exit(i32 1)
  %23 = call ptr @create_node__Enum_NodeKind(i32 0)
  ret ptr %23

label_516:                                        ; preds = %label_515
  %24 = load ptr, ptr %p.430, align 8
  %25 = call ptr @parse_enum_decl__Struct_Parser(ptr %24)
  ret ptr %25
}

define ptr @parse_variable_decl__Struct_Parser(ptr %0) {
entry:
  %p.437 = alloca ptr, align 8
  store ptr %0, ptr %p.437, align 8
  %1 = load ptr, ptr %p.437, align 8
  call void @parser_expect_val__Struct_Parser_Enum_TokenType_String_String(ptr %1, i32 18, ptr @.str.s107, ptr @.str.s108)
  %2 = call ptr @create_node__Enum_NodeKind(i32 3)
  %var_node.438 = alloca ptr, align 8
  store ptr %2, ptr %var_node.438, align 8
  %3 = load ptr, ptr %p.437, align 8
  %4 = call i1 @parser_match_val__Struct_Parser_Enum_TokenType_String(ptr %3, i32 18, ptr @.str.s109)
  %curr.439 = alloca ptr, align 8
  br i1 %4, label %label_535, label %label_537

label_537:                                        ; preds = %label_535, %entry
  %5 = load ptr, ptr %p.437, align 8
  %6 = call ptr @parser_current__Struct_Parser(ptr %5)
  store ptr %6, ptr %curr.439, align 8
  %7 = load ptr, ptr %var_node.438, align 8
  %8 = load ptr, ptr %curr.439, align 8
  %9 = getelementptr inbounds nuw %Token, ptr %8, i32 0, i32 1
  %10 = load ptr, ptr %9, align 8
  %11 = getelementptr inbounds nuw %ASTNode, ptr %7, i32 0, i32 1
  store ptr %10, ptr %11, align 8
  %12 = load ptr, ptr %p.437, align 8
  call void @parser_expect__Struct_Parser_Enum_TokenType_String(ptr %12, i32 5, ptr @.str.s110)
  %13 = load ptr, ptr %p.437, align 8
  %14 = call i1 @parser_match_val__Struct_Parser_Enum_TokenType_String(ptr %13, i32 6, ptr @.str.s111)
  br i1 %14, label %label_538, label %label_540

label_535:                                        ; preds = %entry
  %15 = load ptr, ptr %var_node.438, align 8
  %16 = getelementptr inbounds nuw %ASTNode, ptr %15, i32 0, i32 3
  store i32 1, ptr %16, align 4
  br label %label_537

label_540:                                        ; preds = %label_538, %label_537
  %17 = load ptr, ptr %p.437, align 8
  %18 = call i1 @parser_match_val__Struct_Parser_Enum_TokenType_String(ptr %17, i32 12, ptr @.str.s112)
  br i1 %18, label %label_541, label %label_543

label_538:                                        ; preds = %label_537
  %19 = load ptr, ptr %var_node.438, align 8
  %20 = load ptr, ptr %p.437, align 8
  %21 = call ptr @parse_type_annotation__Struct_Parser(ptr %20)
  %22 = call ptr @node_to_ptr(ptr %21)
  %23 = getelementptr inbounds nuw %ASTNode, ptr %19, i32 0, i32 5
  store ptr %22, ptr %23, align 8
  br label %label_540

label_543:                                        ; preds = %label_541, %label_540
  %24 = load ptr, ptr %var_node.438, align 8
  ret ptr %24

label_541:                                        ; preds = %label_540
  %25 = load ptr, ptr %var_node.438, align 8
  %26 = load ptr, ptr %p.437, align 8
  %27 = call ptr @parse_expression__Struct_Parser_Int(ptr %26, i32 0)
  %28 = call ptr @node_to_ptr(ptr %27)
  %29 = getelementptr inbounds nuw %ASTNode, ptr %25, i32 0, i32 6
  store ptr %28, ptr %29, align 8
  br label %label_543
}

define ptr @parse_extern_fn_decl__Struct_Parser(ptr %0) {
entry:
  %p.440 = alloca ptr, align 8
  store ptr %0, ptr %p.440, align 8
  %1 = load ptr, ptr %p.440, align 8
  call void @parser_expect_val__Struct_Parser_Enum_TokenType_String_String(ptr %1, i32 18, ptr @.str.s113, ptr @.str.s114)
  %2 = load ptr, ptr %p.440, align 8
  call void @parser_expect_val__Struct_Parser_Enum_TokenType_String_String(ptr %2, i32 18, ptr @.str.s115, ptr @.str.s116)
  %3 = call ptr @create_node__Enum_NodeKind(i32 2)
  %ext_node.441 = alloca ptr, align 8
  store ptr %3, ptr %ext_node.441, align 8
  %4 = load ptr, ptr %p.440, align 8
  %5 = call ptr @parser_current__Struct_Parser(ptr %4)
  %curr.442 = alloca ptr, align 8
  store ptr %5, ptr %curr.442, align 8
  %6 = load ptr, ptr %ext_node.441, align 8
  %7 = load ptr, ptr %curr.442, align 8
  %8 = getelementptr inbounds nuw %Token, ptr %7, i32 0, i32 1
  %9 = load ptr, ptr %8, align 8
  %10 = getelementptr inbounds nuw %ASTNode, ptr %6, i32 0, i32 1
  store ptr %9, ptr %10, align 8
  %11 = load ptr, ptr %p.440, align 8
  call void @parser_expect__Struct_Parser_Enum_TokenType_String(ptr %11, i32 5, ptr @.str.s117)
  %12 = load ptr, ptr %p.440, align 8
  call void @parser_expect_val__Struct_Parser_Enum_TokenType_String_String(ptr %12, i32 6, ptr @.str.s118, ptr @.str.s119)
  %last_param.443 = alloca ptr, align 8
  store ptr @.str.s120, ptr %last_param.443, align 8
  %13 = load ptr, ptr %p.440, align 8
  %14 = call i1 @parser_check_val__Struct_Parser_Enum_TokenType_String(ptr %13, i32 6, ptr @.str.s121)
  %15 = icmp eq i1 %14, false
  %is_looping.444 = alloca i1, align 1
  %param.445 = alloca ptr, align 8
  %curr.446 = alloca ptr, align 8
  %last.447 = alloca ptr, align 8
  br i1 %15, label %label_544, label %label_546

label_546:                                        ; preds = %label_549, %entry
  %16 = load ptr, ptr %p.440, align 8
  call void @parser_expect_val__Struct_Parser_Enum_TokenType_String_String(ptr %16, i32 6, ptr @.str.s127, ptr @.str.s128)
  %17 = load ptr, ptr %p.440, align 8
  %18 = call i1 @parser_match_val__Struct_Parser_Enum_TokenType_String(ptr %17, i32 15, ptr @.str.s129)
  br i1 %18, label %label_556, label %label_558

label_544:                                        ; preds = %entry
  store i1 true, ptr %is_looping.444, align 1
  br label %label_547

label_547:                                        ; preds = %label_555, %label_544
  %19 = load i1, ptr %is_looping.444, align 1
  br i1 %19, label %label_548, label %label_549

label_549:                                        ; preds = %label_547
  br label %label_546

label_548:                                        ; preds = %label_547
  %20 = call ptr @create_node__Enum_NodeKind(i32 30)
  store ptr %20, ptr %param.445, align 8
  %21 = load ptr, ptr %p.440, align 8
  %22 = call ptr @parser_current__Struct_Parser(ptr %21)
  store ptr %22, ptr %curr.446, align 8
  %23 = load ptr, ptr %param.445, align 8
  %24 = load ptr, ptr %curr.446, align 8
  %25 = getelementptr inbounds nuw %Token, ptr %24, i32 0, i32 1
  %26 = load ptr, ptr %25, align 8
  %27 = getelementptr inbounds nuw %ASTNode, ptr %23, i32 0, i32 1
  store ptr %26, ptr %27, align 8
  %28 = load ptr, ptr %p.440, align 8
  call void @parser_expect__Struct_Parser_Enum_TokenType_String(ptr %28, i32 5, ptr @.str.s122)
  %29 = load ptr, ptr %p.440, align 8
  call void @parser_expect_val__Struct_Parser_Enum_TokenType_String_String(ptr %29, i32 6, ptr @.str.s123, ptr @.str.s124)
  %30 = load ptr, ptr %param.445, align 8
  %31 = load ptr, ptr %p.440, align 8
  %32 = call ptr @parse_type_annotation__Struct_Parser(ptr %31)
  %33 = call ptr @node_to_ptr(ptr %32)
  %34 = getelementptr inbounds nuw %ASTNode, ptr %30, i32 0, i32 5
  store ptr %33, ptr %34, align 8
  %35 = load ptr, ptr %ext_node.441, align 8
  %36 = getelementptr inbounds nuw %ASTNode, ptr %35, i32 0, i32 5
  %37 = load ptr, ptr %36, align 8
  %38 = call i32 @str_equals(ptr %37, ptr @.str.s125)
  %39 = icmp eq i32 %38, 1
  br i1 %39, label %label_550, label %label_551

label_551:                                        ; preds = %label_548
  %40 = load ptr, ptr %last_param.443, align 8
  %41 = call ptr @ptr_to_node(ptr %40)
  store ptr %41, ptr %last.447, align 8
  %42 = load ptr, ptr %last.447, align 8
  %43 = load ptr, ptr %param.445, align 8
  %44 = call ptr @node_to_ptr(ptr %43)
  %45 = getelementptr inbounds nuw %ASTNode, ptr %42, i32 0, i32 8
  store ptr %44, ptr %45, align 8
  br label %label_552

label_550:                                        ; preds = %label_548
  %46 = load ptr, ptr %ext_node.441, align 8
  %47 = load ptr, ptr %param.445, align 8
  %48 = call ptr @node_to_ptr(ptr %47)
  %49 = getelementptr inbounds nuw %ASTNode, ptr %46, i32 0, i32 5
  store ptr %48, ptr %49, align 8
  br label %label_552

label_552:                                        ; preds = %label_551, %label_550
  %50 = load ptr, ptr %param.445, align 8
  %51 = call ptr @node_to_ptr(ptr %50)
  store ptr %51, ptr %last_param.443, align 8
  %52 = load ptr, ptr %p.440, align 8
  %53 = call i1 @parser_match_val__Struct_Parser_Enum_TokenType_String(ptr %52, i32 6, ptr @.str.s126)
  %54 = icmp eq i1 %53, false
  br i1 %54, label %label_553, label %label_555

label_555:                                        ; preds = %label_553, %label_552
  br label %label_547

label_553:                                        ; preds = %label_552
  store i1 false, ptr %is_looping.444, align 1
  br label %label_555

label_558:                                        ; preds = %label_556, %label_546
  %55 = load ptr, ptr %ext_node.441, align 8
  ret ptr %55

label_556:                                        ; preds = %label_546
  %56 = load ptr, ptr %ext_node.441, align 8
  %57 = load ptr, ptr %p.440, align 8
  %58 = call ptr @parse_type_annotation__Struct_Parser(ptr %57)
  %59 = call ptr @node_to_ptr(ptr %58)
  %60 = getelementptr inbounds nuw %ASTNode, ptr %56, i32 0, i32 6
  store ptr %59, ptr %60, align 8
  br label %label_558
}

define ptr @parse_function_decl__Struct_Parser(ptr %0) {
entry:
  %p.448 = alloca ptr, align 8
  store ptr %0, ptr %p.448, align 8
  %1 = load ptr, ptr %p.448, align 8
  call void @parser_expect_val__Struct_Parser_Enum_TokenType_String_String(ptr %1, i32 18, ptr @.str.s130, ptr @.str.s131)
  %2 = call ptr @create_node__Enum_NodeKind(i32 4)
  %fn_node.449 = alloca ptr, align 8
  store ptr %2, ptr %fn_node.449, align 8
  %3 = load ptr, ptr %p.448, align 8
  %4 = call ptr @parser_current__Struct_Parser(ptr %3)
  %curr.450 = alloca ptr, align 8
  store ptr %4, ptr %curr.450, align 8
  %5 = load ptr, ptr %fn_node.449, align 8
  %6 = load ptr, ptr %curr.450, align 8
  %7 = getelementptr inbounds nuw %Token, ptr %6, i32 0, i32 1
  %8 = load ptr, ptr %7, align 8
  %9 = getelementptr inbounds nuw %ASTNode, ptr %5, i32 0, i32 1
  store ptr %8, ptr %9, align 8
  %10 = load ptr, ptr %p.448, align 8
  call void @parser_expect__Struct_Parser_Enum_TokenType_String(ptr %10, i32 5, ptr @.str.s132)
  %11 = load ptr, ptr %p.448, align 8
  call void @parser_expect_val__Struct_Parser_Enum_TokenType_String_String(ptr %11, i32 6, ptr @.str.s133, ptr @.str.s134)
  %last_param.451 = alloca ptr, align 8
  store ptr @.str.s135, ptr %last_param.451, align 8
  %12 = load ptr, ptr %p.448, align 8
  %13 = call i1 @parser_check_val__Struct_Parser_Enum_TokenType_String(ptr %12, i32 6, ptr @.str.s136)
  %14 = icmp eq i1 %13, false
  %is_looping.452 = alloca i1, align 1
  %param.453 = alloca ptr, align 8
  %curr.454 = alloca ptr, align 8
  %last.455 = alloca ptr, align 8
  br i1 %14, label %label_559, label %label_561

label_561:                                        ; preds = %label_564, %entry
  %15 = load ptr, ptr %p.448, align 8
  call void @parser_expect_val__Struct_Parser_Enum_TokenType_String_String(ptr %15, i32 6, ptr @.str.s146, ptr @.str.s147)
  %16 = load ptr, ptr %p.448, align 8
  %17 = call i1 @parser_match_val__Struct_Parser_Enum_TokenType_String(ptr %16, i32 15, ptr @.str.s148)
  br i1 %17, label %label_577, label %label_579

label_559:                                        ; preds = %entry
  store i1 true, ptr %is_looping.452, align 1
  br label %label_562

label_562:                                        ; preds = %label_576, %label_559
  %18 = load i1, ptr %is_looping.452, align 1
  br i1 %18, label %label_563, label %label_564

label_564:                                        ; preds = %label_562
  br label %label_561

label_563:                                        ; preds = %label_562
  %19 = call ptr @create_node__Enum_NodeKind(i32 30)
  store ptr %19, ptr %param.453, align 8
  %20 = load ptr, ptr %p.448, align 8
  %21 = call i1 @parser_match_val__Struct_Parser_Enum_TokenType_String(ptr %20, i32 18, ptr @.str.s137)
  br i1 %21, label %label_565, label %label_566

label_566:                                        ; preds = %label_563
  %22 = load ptr, ptr %p.448, align 8
  %23 = call i1 @parser_match_val__Struct_Parser_Enum_TokenType_String(ptr %22, i32 18, ptr @.str.s139)
  br i1 %23, label %label_568, label %label_570

label_565:                                        ; preds = %label_563
  %24 = load ptr, ptr %param.453, align 8
  %25 = getelementptr inbounds nuw %ASTNode, ptr %24, i32 0, i32 2
  store ptr @.str.s138, ptr %25, align 8
  br label %label_567

label_567:                                        ; preds = %label_570, %label_565
  %26 = load ptr, ptr %p.448, align 8
  %27 = call ptr @parser_current__Struct_Parser(ptr %26)
  store ptr %27, ptr %curr.454, align 8
  %28 = load ptr, ptr %param.453, align 8
  %29 = load ptr, ptr %curr.454, align 8
  %30 = getelementptr inbounds nuw %Token, ptr %29, i32 0, i32 1
  %31 = load ptr, ptr %30, align 8
  %32 = getelementptr inbounds nuw %ASTNode, ptr %28, i32 0, i32 1
  store ptr %31, ptr %32, align 8
  %33 = load ptr, ptr %p.448, align 8
  call void @parser_expect__Struct_Parser_Enum_TokenType_String(ptr %33, i32 5, ptr @.str.s141)
  %34 = load ptr, ptr %p.448, align 8
  call void @parser_expect_val__Struct_Parser_Enum_TokenType_String_String(ptr %34, i32 6, ptr @.str.s142, ptr @.str.s143)
  %35 = load ptr, ptr %param.453, align 8
  %36 = load ptr, ptr %p.448, align 8
  %37 = call ptr @parse_type_annotation__Struct_Parser(ptr %36)
  %38 = call ptr @node_to_ptr(ptr %37)
  %39 = getelementptr inbounds nuw %ASTNode, ptr %35, i32 0, i32 5
  store ptr %38, ptr %39, align 8
  %40 = load ptr, ptr %fn_node.449, align 8
  %41 = getelementptr inbounds nuw %ASTNode, ptr %40, i32 0, i32 5
  %42 = load ptr, ptr %41, align 8
  %43 = call i32 @str_equals(ptr %42, ptr @.str.s144)
  %44 = icmp eq i32 %43, 1
  br i1 %44, label %label_571, label %label_572

label_570:                                        ; preds = %label_568, %label_566
  br label %label_567

label_568:                                        ; preds = %label_566
  %45 = load ptr, ptr %param.453, align 8
  %46 = getelementptr inbounds nuw %ASTNode, ptr %45, i32 0, i32 2
  store ptr @.str.s140, ptr %46, align 8
  br label %label_570

label_572:                                        ; preds = %label_567
  %47 = load ptr, ptr %last_param.451, align 8
  %48 = call ptr @ptr_to_node(ptr %47)
  store ptr %48, ptr %last.455, align 8
  %49 = load ptr, ptr %last.455, align 8
  %50 = load ptr, ptr %param.453, align 8
  %51 = call ptr @node_to_ptr(ptr %50)
  %52 = getelementptr inbounds nuw %ASTNode, ptr %49, i32 0, i32 8
  store ptr %51, ptr %52, align 8
  br label %label_573

label_571:                                        ; preds = %label_567
  %53 = load ptr, ptr %fn_node.449, align 8
  %54 = load ptr, ptr %param.453, align 8
  %55 = call ptr @node_to_ptr(ptr %54)
  %56 = getelementptr inbounds nuw %ASTNode, ptr %53, i32 0, i32 5
  store ptr %55, ptr %56, align 8
  br label %label_573

label_573:                                        ; preds = %label_572, %label_571
  %57 = load ptr, ptr %param.453, align 8
  %58 = call ptr @node_to_ptr(ptr %57)
  store ptr %58, ptr %last_param.451, align 8
  %59 = load ptr, ptr %p.448, align 8
  %60 = call i1 @parser_match_val__Struct_Parser_Enum_TokenType_String(ptr %59, i32 6, ptr @.str.s145)
  %61 = icmp eq i1 %60, false
  br i1 %61, label %label_574, label %label_576

label_576:                                        ; preds = %label_574, %label_573
  br label %label_562

label_574:                                        ; preds = %label_573
  store i1 false, ptr %is_looping.452, align 1
  br label %label_576

label_579:                                        ; preds = %label_577, %label_561
  %62 = load ptr, ptr %fn_node.449, align 8
  %63 = load ptr, ptr %p.448, align 8
  %64 = call ptr @parse_block__Struct_Parser(ptr %63)
  %65 = call ptr @node_to_ptr(ptr %64)
  %66 = getelementptr inbounds nuw %ASTNode, ptr %62, i32 0, i32 6
  store ptr %65, ptr %66, align 8
  %67 = load ptr, ptr %fn_node.449, align 8
  ret ptr %67

label_577:                                        ; preds = %label_561
  %68 = load ptr, ptr %fn_node.449, align 8
  %69 = load ptr, ptr %p.448, align 8
  %70 = call ptr @parse_type_annotation__Struct_Parser(ptr %69)
  %71 = call ptr @node_to_ptr(ptr %70)
  %72 = getelementptr inbounds nuw %ASTNode, ptr %68, i32 0, i32 7
  store ptr %71, ptr %72, align 8
  br label %label_579
}

define ptr @parse_struct_decl__Struct_Parser(ptr %0) {
entry:
  %p.456 = alloca ptr, align 8
  store ptr %0, ptr %p.456, align 8
  %1 = load ptr, ptr %p.456, align 8
  call void @parser_expect_val__Struct_Parser_Enum_TokenType_String_String(ptr %1, i32 18, ptr @.str.s149, ptr @.str.s150)
  %2 = call ptr @create_node__Enum_NodeKind(i32 5)
  %struct_node.457 = alloca ptr, align 8
  store ptr %2, ptr %struct_node.457, align 8
  %3 = load ptr, ptr %p.456, align 8
  %4 = call ptr @parser_current__Struct_Parser(ptr %3)
  %curr.458 = alloca ptr, align 8
  store ptr %4, ptr %curr.458, align 8
  %5 = load ptr, ptr %struct_node.457, align 8
  %6 = load ptr, ptr %curr.458, align 8
  %7 = getelementptr inbounds nuw %Token, ptr %6, i32 0, i32 1
  %8 = load ptr, ptr %7, align 8
  %9 = getelementptr inbounds nuw %ASTNode, ptr %5, i32 0, i32 1
  store ptr %8, ptr %9, align 8
  %10 = load ptr, ptr %p.456, align 8
  call void @parser_expect__Struct_Parser_Enum_TokenType_String(ptr %10, i32 5, ptr @.str.s151)
  %11 = load ptr, ptr %p.456, align 8
  call void @parser_expect_val__Struct_Parser_Enum_TokenType_String_String(ptr %11, i32 6, ptr @.str.s152, ptr @.str.s153)
  %last_field.459 = alloca ptr, align 8
  store ptr @.str.s154, ptr %last_field.459, align 8
  %field.460 = alloca ptr, align 8
  %curr.461 = alloca ptr, align 8
  %last.462 = alloca ptr, align 8
  br label %label_580

label_580:                                        ; preds = %label_585, %entry
  %12 = load ptr, ptr %p.456, align 8
  %13 = call i1 @parser_check_val__Struct_Parser_Enum_TokenType_String(ptr %12, i32 6, ptr @.str.s155)
  %14 = icmp eq i1 %13, false
  br i1 %14, label %label_581, label %label_582

label_582:                                        ; preds = %label_580
  %15 = load ptr, ptr %p.456, align 8
  call void @parser_expect_val__Struct_Parser_Enum_TokenType_String_String(ptr %15, i32 6, ptr @.str.s161, ptr @.str.s162)
  %16 = load ptr, ptr %struct_node.457, align 8
  ret ptr %16

label_581:                                        ; preds = %label_580
  %17 = call ptr @create_node__Enum_NodeKind(i32 32)
  store ptr %17, ptr %field.460, align 8
  %18 = load ptr, ptr %p.456, align 8
  %19 = call ptr @parser_current__Struct_Parser(ptr %18)
  store ptr %19, ptr %curr.461, align 8
  %20 = load ptr, ptr %field.460, align 8
  %21 = load ptr, ptr %curr.461, align 8
  %22 = getelementptr inbounds nuw %Token, ptr %21, i32 0, i32 1
  %23 = load ptr, ptr %22, align 8
  %24 = getelementptr inbounds nuw %ASTNode, ptr %20, i32 0, i32 1
  store ptr %23, ptr %24, align 8
  %25 = load ptr, ptr %p.456, align 8
  call void @parser_expect__Struct_Parser_Enum_TokenType_String(ptr %25, i32 5, ptr @.str.s156)
  %26 = load ptr, ptr %p.456, align 8
  call void @parser_expect_val__Struct_Parser_Enum_TokenType_String_String(ptr %26, i32 6, ptr @.str.s157, ptr @.str.s158)
  %27 = load ptr, ptr %field.460, align 8
  %28 = load ptr, ptr %p.456, align 8
  %29 = call ptr @parse_type_annotation__Struct_Parser(ptr %28)
  %30 = call ptr @node_to_ptr(ptr %29)
  %31 = getelementptr inbounds nuw %ASTNode, ptr %27, i32 0, i32 5
  store ptr %30, ptr %31, align 8
  %32 = load ptr, ptr %struct_node.457, align 8
  %33 = getelementptr inbounds nuw %ASTNode, ptr %32, i32 0, i32 5
  %34 = load ptr, ptr %33, align 8
  %35 = call i32 @str_equals(ptr %34, ptr @.str.s159)
  %36 = icmp eq i32 %35, 1
  br i1 %36, label %label_583, label %label_584

label_584:                                        ; preds = %label_581
  %37 = load ptr, ptr %last_field.459, align 8
  %38 = call ptr @ptr_to_node(ptr %37)
  store ptr %38, ptr %last.462, align 8
  %39 = load ptr, ptr %last.462, align 8
  %40 = load ptr, ptr %field.460, align 8
  %41 = call ptr @node_to_ptr(ptr %40)
  %42 = getelementptr inbounds nuw %ASTNode, ptr %39, i32 0, i32 8
  store ptr %41, ptr %42, align 8
  br label %label_585

label_583:                                        ; preds = %label_581
  %43 = load ptr, ptr %struct_node.457, align 8
  %44 = load ptr, ptr %field.460, align 8
  %45 = call ptr @node_to_ptr(ptr %44)
  %46 = getelementptr inbounds nuw %ASTNode, ptr %43, i32 0, i32 5
  store ptr %45, ptr %46, align 8
  br label %label_585

label_585:                                        ; preds = %label_584, %label_583
  %47 = load ptr, ptr %field.460, align 8
  %48 = call ptr @node_to_ptr(ptr %47)
  store ptr %48, ptr %last_field.459, align 8
  %49 = load ptr, ptr %p.456, align 8
  %50 = call i1 @parser_match_val__Struct_Parser_Enum_TokenType_String(ptr %49, i32 6, ptr @.str.s160)
  br label %label_580
}

define ptr @parse_enum_decl__Struct_Parser(ptr %0) {
entry:
  %p.463 = alloca ptr, align 8
  store ptr %0, ptr %p.463, align 8
  %1 = load ptr, ptr %p.463, align 8
  call void @parser_expect_val__Struct_Parser_Enum_TokenType_String_String(ptr %1, i32 18, ptr @.str.s163, ptr @.str.s164)
  %2 = call ptr @create_node__Enum_NodeKind(i32 6)
  %enum_node.464 = alloca ptr, align 8
  store ptr %2, ptr %enum_node.464, align 8
  %3 = load ptr, ptr %p.463, align 8
  %4 = call ptr @parser_current__Struct_Parser(ptr %3)
  %curr.465 = alloca ptr, align 8
  store ptr %4, ptr %curr.465, align 8
  %5 = load ptr, ptr %enum_node.464, align 8
  %6 = load ptr, ptr %curr.465, align 8
  %7 = getelementptr inbounds nuw %Token, ptr %6, i32 0, i32 1
  %8 = load ptr, ptr %7, align 8
  %9 = getelementptr inbounds nuw %ASTNode, ptr %5, i32 0, i32 1
  store ptr %8, ptr %9, align 8
  %10 = load ptr, ptr %p.463, align 8
  call void @parser_expect__Struct_Parser_Enum_TokenType_String(ptr %10, i32 5, ptr @.str.s165)
  %11 = load ptr, ptr %p.463, align 8
  call void @parser_expect_val__Struct_Parser_Enum_TokenType_String_String(ptr %11, i32 6, ptr @.str.s166, ptr @.str.s167)
  %last_var.466 = alloca ptr, align 8
  store ptr @.str.s168, ptr %last_var.466, align 8
  %variant.467 = alloca ptr, align 8
  %curr.468 = alloca ptr, align 8
  %last.469 = alloca ptr, align 8
  br label %label_586

label_586:                                        ; preds = %label_591, %entry
  %12 = load ptr, ptr %p.463, align 8
  %13 = call i1 @parser_check_val__Struct_Parser_Enum_TokenType_String(ptr %12, i32 6, ptr @.str.s169)
  %14 = icmp eq i1 %13, false
  br i1 %14, label %label_587, label %label_588

label_588:                                        ; preds = %label_586
  %15 = load ptr, ptr %p.463, align 8
  call void @parser_expect_val__Struct_Parser_Enum_TokenType_String_String(ptr %15, i32 6, ptr @.str.s173, ptr @.str.s174)
  %16 = load ptr, ptr %enum_node.464, align 8
  ret ptr %16

label_587:                                        ; preds = %label_586
  %17 = call ptr @create_node__Enum_NodeKind(i32 33)
  store ptr %17, ptr %variant.467, align 8
  %18 = load ptr, ptr %p.463, align 8
  %19 = call ptr @parser_current__Struct_Parser(ptr %18)
  store ptr %19, ptr %curr.468, align 8
  %20 = load ptr, ptr %variant.467, align 8
  %21 = load ptr, ptr %curr.468, align 8
  %22 = getelementptr inbounds nuw %Token, ptr %21, i32 0, i32 1
  %23 = load ptr, ptr %22, align 8
  %24 = getelementptr inbounds nuw %ASTNode, ptr %20, i32 0, i32 1
  store ptr %23, ptr %24, align 8
  %25 = load ptr, ptr %p.463, align 8
  call void @parser_expect__Struct_Parser_Enum_TokenType_String(ptr %25, i32 5, ptr @.str.s170)
  %26 = load ptr, ptr %enum_node.464, align 8
  %27 = getelementptr inbounds nuw %ASTNode, ptr %26, i32 0, i32 5
  %28 = load ptr, ptr %27, align 8
  %29 = call i32 @str_equals(ptr %28, ptr @.str.s171)
  %30 = icmp eq i32 %29, 1
  br i1 %30, label %label_589, label %label_590

label_590:                                        ; preds = %label_587
  %31 = load ptr, ptr %last_var.466, align 8
  %32 = call ptr @ptr_to_node(ptr %31)
  store ptr %32, ptr %last.469, align 8
  %33 = load ptr, ptr %last.469, align 8
  %34 = load ptr, ptr %variant.467, align 8
  %35 = call ptr @node_to_ptr(ptr %34)
  %36 = getelementptr inbounds nuw %ASTNode, ptr %33, i32 0, i32 8
  store ptr %35, ptr %36, align 8
  br label %label_591

label_589:                                        ; preds = %label_587
  %37 = load ptr, ptr %enum_node.464, align 8
  %38 = load ptr, ptr %variant.467, align 8
  %39 = call ptr @node_to_ptr(ptr %38)
  %40 = getelementptr inbounds nuw %ASTNode, ptr %37, i32 0, i32 5
  store ptr %39, ptr %40, align 8
  br label %label_591

label_591:                                        ; preds = %label_590, %label_589
  %41 = load ptr, ptr %variant.467, align 8
  %42 = call ptr @node_to_ptr(ptr %41)
  store ptr %42, ptr %last_var.466, align 8
  %43 = load ptr, ptr %p.463, align 8
  %44 = call i1 @parser_match_val__Struct_Parser_Enum_TokenType_String(ptr %43, i32 6, ptr @.str.s172)
  br label %label_586
}

define ptr @parse_type_annotation__Struct_Parser(ptr %0) {
entry:
  %p.431 = alloca ptr, align 8
  store ptr %0, ptr %p.431, align 8
  %1 = call ptr @create_node__Enum_NodeKind(i32 31)
  %type_node.432 = alloca ptr, align 8
  store ptr %1, ptr %type_node.432, align 8
  %2 = load ptr, ptr %p.431, align 8
  %3 = call i1 @parser_match_val__Struct_Parser_Enum_TokenType_String(ptr %2, i32 6, ptr @.str.s97)
  %curr.433 = alloca ptr, align 8
  %sc.42 = alloca i1, align 1
  %sc.43 = alloca i1, align 1
  br i1 %3, label %label_519, label %label_521

label_521:                                        ; preds = %entry
  %4 = load ptr, ptr %p.431, align 8
  %5 = call ptr @parser_current__Struct_Parser(ptr %4)
  store ptr %5, ptr %curr.433, align 8
  %6 = load ptr, ptr %curr.433, align 8
  %7 = getelementptr inbounds nuw %Token, ptr %6, i32 0, i32 0
  %8 = load i32, ptr %7, align 4
  %9 = icmp eq i32 %8, 5
  store i1 %9, ptr %sc.42, align 1
  br i1 %9, label %label_523, label %label_522

label_519:                                        ; preds = %entry
  %10 = load ptr, ptr %type_node.432, align 8
  %11 = getelementptr inbounds nuw %ASTNode, ptr %10, i32 0, i32 3
  store i32 1, ptr %11, align 4
  %12 = load ptr, ptr %type_node.432, align 8
  %13 = load ptr, ptr %p.431, align 8
  %14 = call ptr @parse_type_annotation__Struct_Parser(ptr %13)
  %15 = call ptr @node_to_ptr(ptr %14)
  %16 = getelementptr inbounds nuw %ASTNode, ptr %12, i32 0, i32 5
  store ptr %15, ptr %16, align 8
  %17 = load ptr, ptr %p.431, align 8
  call void @parser_expect_val__Struct_Parser_Enum_TokenType_String_String(ptr %17, i32 6, ptr @.str.s98, ptr @.str.s99)
  %18 = load ptr, ptr %type_node.432, align 8
  ret ptr %18

label_522:                                        ; preds = %label_521
  %19 = load ptr, ptr %curr.433, align 8
  %20 = getelementptr inbounds nuw %Token, ptr %19, i32 0, i32 0
  %21 = load i32, ptr %20, align 4
  %22 = icmp eq i32 %21, 18
  store i1 %22, ptr %sc.42, align 1
  br label %label_523

label_523:                                        ; preds = %label_522, %label_521
  %23 = load i1, ptr %sc.42, align 1
  br i1 %23, label %label_524, label %label_525

label_525:                                        ; preds = %label_523
  call void @println(ptr @.str.s100)
  call void @exit(i32 1)
  br label %label_526

label_524:                                        ; preds = %label_523
  %24 = load ptr, ptr %type_node.432, align 8
  %25 = load ptr, ptr %curr.433, align 8
  %26 = getelementptr inbounds nuw %Token, ptr %25, i32 0, i32 1
  %27 = load ptr, ptr %26, align 8
  %28 = getelementptr inbounds nuw %ASTNode, ptr %24, i32 0, i32 1
  store ptr %27, ptr %28, align 8
  %29 = load ptr, ptr %p.431, align 8
  call void @parser_advance__Struct_Parser(ptr %29)
  br label %label_526

label_526:                                        ; preds = %label_525, %label_524
  %30 = load ptr, ptr %type_node.432, align 8
  %31 = getelementptr inbounds nuw %ASTNode, ptr %30, i32 0, i32 1
  %32 = load ptr, ptr %31, align 8
  %33 = call i32 @str_equals(ptr %32, ptr @.str.s101)
  %34 = icmp eq i32 %33, 1
  store i1 %34, ptr %sc.43, align 1
  br i1 %34, label %label_527, label %label_528

label_528:                                        ; preds = %label_527, %label_526
  %35 = load i1, ptr %sc.43, align 1
  br i1 %35, label %label_529, label %label_531

label_527:                                        ; preds = %label_526
  %36 = load ptr, ptr %p.431, align 8
  %37 = call i1 @parser_match_val__Struct_Parser_Enum_TokenType_String(ptr %36, i32 9, ptr @.str.s102)
  store i1 %37, ptr %sc.43, align 1
  br label %label_528

label_531:                                        ; preds = %label_529, %label_528
  %38 = load ptr, ptr %type_node.432, align 8
  ret ptr %38

label_529:                                        ; preds = %label_528
  %39 = load ptr, ptr %type_node.432, align 8
  %40 = getelementptr inbounds nuw %ASTNode, ptr %39, i32 0, i32 4
  store i32 1, ptr %40, align 4
  %41 = load ptr, ptr %type_node.432, align 8
  %42 = load ptr, ptr %p.431, align 8
  %43 = call ptr @parse_type_annotation__Struct_Parser(ptr %42)
  %44 = call ptr @node_to_ptr(ptr %43)
  %45 = getelementptr inbounds nuw %ASTNode, ptr %41, i32 0, i32 5
  store ptr %44, ptr %45, align 8
  %46 = load ptr, ptr %p.431, align 8
  call void @parser_expect_close_angle__Struct_Parser_String(ptr %46, ptr @.str.s103)
  br label %label_531
}

define void @parser_expect_close_angle__Struct_Parser_String(ptr %0, ptr %1) {
entry:
  %p.434 = alloca ptr, align 8
  store ptr %0, ptr %p.434, align 8
  %context.435 = alloca ptr, align 8
  store ptr %1, ptr %context.435, align 8
  %2 = load ptr, ptr %p.434, align 8
  %3 = call ptr @parser_current__Struct_Parser(ptr %2)
  %curr.436 = alloca ptr, align 8
  store ptr %3, ptr %curr.436, align 8
  %4 = load ptr, ptr %curr.436, align 8
  %5 = getelementptr inbounds nuw %Token, ptr %4, i32 0, i32 1
  %6 = load ptr, ptr %5, align 8
  %7 = call i32 @str_equals(ptr %6, ptr @.str.s104)
  %8 = icmp eq i32 %7, 1
  br i1 %8, label %label_532, label %label_534

label_534:                                        ; preds = %entry
  %9 = load ptr, ptr %p.434, align 8
  %10 = load ptr, ptr %context.435, align 8
  call void @parser_expect_val__Struct_Parser_Enum_TokenType_String_String(ptr %9, i32 9, ptr @.str.s106, ptr %10)
  ret void

label_532:                                        ; preds = %entry
  %11 = load ptr, ptr %curr.436, align 8
  %12 = getelementptr inbounds nuw %Token, ptr %11, i32 0, i32 1
  store ptr @.str.s105, ptr %12, align 8
  ret void
}

define ptr @parse_expression__Struct_Parser_Int(ptr %0, i32 %1) {
entry:
  %p.516 = alloca ptr, align 8
  store ptr %0, ptr %p.516, align 8
  %precedence.517 = alloca i32, align 4
  store i32 %1, ptr %precedence.517, align 4
  %2 = load ptr, ptr %p.516, align 8
  %3 = call ptr @parse_unary__Struct_Parser(ptr %2)
  %left.518 = alloca ptr, align 8
  store ptr %3, ptr %left.518, align 8
  %is_looping.519 = alloca i1, align 1
  store i1 true, ptr %is_looping.519, align 1
  %curr.520 = alloca ptr, align 8
  %sc.62 = alloca i1, align 1
  %sc.63 = alloca i1, align 1
  %sc.64 = alloca i1, align 1
  %is_operator.521 = alloca i1, align 1
  %current_precedence.522 = alloca i32, align 4
  %sc.65 = alloca i1, align 1
  %op.523 = alloca ptr, align 8
  %right.524 = alloca ptr, align 8
  %bin_expr.525 = alloca ptr, align 8
  br label %label_736

label_736:                                        ; preds = %label_747, %entry
  %4 = load i1, ptr %is_looping.519, align 1
  br i1 %4, label %label_737, label %label_738

label_738:                                        ; preds = %label_736
  %5 = load ptr, ptr %left.518, align 8
  ret ptr %5

label_737:                                        ; preds = %label_736
  %6 = load ptr, ptr %p.516, align 8
  %7 = call ptr @parser_current__Struct_Parser(ptr %6)
  store ptr %7, ptr %curr.520, align 8
  %8 = load ptr, ptr %curr.520, align 8
  %9 = getelementptr inbounds nuw %Token, ptr %8, i32 0, i32 0
  %10 = load i32, ptr %9, align 4
  %11 = icmp eq i32 %10, 8
  store i1 %11, ptr %sc.64, align 1
  br i1 %11, label %label_744, label %label_743

label_743:                                        ; preds = %label_737
  %12 = load ptr, ptr %curr.520, align 8
  %13 = getelementptr inbounds nuw %Token, ptr %12, i32 0, i32 0
  %14 = load i32, ptr %13, align 4
  %15 = icmp eq i32 %14, 9
  store i1 %15, ptr %sc.64, align 1
  br label %label_744

label_744:                                        ; preds = %label_743, %label_737
  %16 = load i1, ptr %sc.64, align 1
  store i1 %16, ptr %sc.63, align 1
  br i1 %16, label %label_742, label %label_741

label_741:                                        ; preds = %label_744
  %17 = load ptr, ptr %curr.520, align 8
  %18 = getelementptr inbounds nuw %Token, ptr %17, i32 0, i32 1
  %19 = load ptr, ptr %18, align 8
  %20 = call i32 @str_equals(ptr %19, ptr @.str.s263)
  %21 = icmp eq i32 %20, 1
  store i1 %21, ptr %sc.63, align 1
  br label %label_742

label_742:                                        ; preds = %label_741, %label_744
  %22 = load i1, ptr %sc.63, align 1
  store i1 %22, ptr %sc.62, align 1
  br i1 %22, label %label_740, label %label_739

label_739:                                        ; preds = %label_742
  %23 = load ptr, ptr %curr.520, align 8
  %24 = getelementptr inbounds nuw %Token, ptr %23, i32 0, i32 1
  %25 = load ptr, ptr %24, align 8
  %26 = call i32 @str_equals(ptr %25, ptr @.str.s264)
  %27 = icmp eq i32 %26, 1
  store i1 %27, ptr %sc.62, align 1
  br label %label_740

label_740:                                        ; preds = %label_739, %label_742
  %28 = load i1, ptr %sc.62, align 1
  store i1 %28, ptr %is_operator.521, align 1
  %29 = load i1, ptr %is_operator.521, align 1
  %30 = icmp eq i1 %29, false
  br i1 %30, label %label_745, label %label_746

label_746:                                        ; preds = %label_740
  %31 = load ptr, ptr %curr.520, align 8
  %32 = call i32 @get_operator_precedence__Struct_Token(ptr %31)
  store i32 %32, ptr %current_precedence.522, align 4
  %33 = load i32, ptr %current_precedence.522, align 4
  %34 = icmp eq i32 %33, 0
  store i1 %34, ptr %sc.65, align 1
  br i1 %34, label %label_749, label %label_748

label_745:                                        ; preds = %label_740
  store i1 false, ptr %is_looping.519, align 1
  br label %label_747

label_747:                                        ; preds = %label_752, %label_745
  br label %label_736

label_748:                                        ; preds = %label_746
  %35 = load i32, ptr %current_precedence.522, align 4
  %36 = load i32, ptr %precedence.517, align 4
  %37 = icmp slt i32 %35, %36
  store i1 %37, ptr %sc.65, align 1
  br label %label_749

label_749:                                        ; preds = %label_748, %label_746
  %38 = load i1, ptr %sc.65, align 1
  br i1 %38, label %label_750, label %label_751

label_751:                                        ; preds = %label_749
  %39 = load ptr, ptr %curr.520, align 8
  %40 = getelementptr inbounds nuw %Token, ptr %39, i32 0, i32 1
  %41 = load ptr, ptr %40, align 8
  store ptr %41, ptr %op.523, align 8
  %42 = load ptr, ptr %p.516, align 8
  call void @parser_advance__Struct_Parser(ptr %42)
  %43 = load ptr, ptr %p.516, align 8
  %44 = load i32, ptr %current_precedence.522, align 4
  %45 = add i32 %44, 1
  %46 = call ptr @parse_expression__Struct_Parser_Int(ptr %43, i32 %45)
  store ptr %46, ptr %right.524, align 8
  %47 = call ptr @create_node__Enum_NodeKind(i32 20)
  store ptr %47, ptr %bin_expr.525, align 8
  %48 = load ptr, ptr %bin_expr.525, align 8
  %49 = load ptr, ptr %op.523, align 8
  %50 = getelementptr inbounds nuw %ASTNode, ptr %48, i32 0, i32 1
  store ptr %49, ptr %50, align 8
  %51 = load ptr, ptr %bin_expr.525, align 8
  %52 = load ptr, ptr %left.518, align 8
  %53 = call ptr @node_to_ptr(ptr %52)
  %54 = getelementptr inbounds nuw %ASTNode, ptr %51, i32 0, i32 5
  store ptr %53, ptr %54, align 8
  %55 = load ptr, ptr %bin_expr.525, align 8
  %56 = load ptr, ptr %right.524, align 8
  %57 = call ptr @node_to_ptr(ptr %56)
  %58 = getelementptr inbounds nuw %ASTNode, ptr %55, i32 0, i32 6
  store ptr %57, ptr %58, align 8
  %59 = load ptr, ptr %bin_expr.525, align 8
  store ptr %59, ptr %left.518, align 8
  br label %label_752

label_750:                                        ; preds = %label_749
  store i1 false, ptr %is_looping.519, align 1
  br label %label_752

label_752:                                        ; preds = %label_751, %label_750
  br label %label_747
}

define ptr @parse_block__Struct_Parser(ptr %0) {
entry:
  %p.470 = alloca ptr, align 8
  store ptr %0, ptr %p.470, align 8
  %1 = load ptr, ptr %p.470, align 8
  call void @parser_expect_val__Struct_Parser_Enum_TokenType_String_String(ptr %1, i32 6, ptr @.str.s175, ptr @.str.s176)
  %2 = call ptr @create_node__Enum_NodeKind(i32 9)
  %block_node.471 = alloca ptr, align 8
  store ptr %2, ptr %block_node.471, align 8
  %last_stmt.472 = alloca ptr, align 8
  store ptr @.str.s177, ptr %last_stmt.472, align 8
  %stmt.473 = alloca ptr, align 8
  %last.474 = alloca ptr, align 8
  br label %label_592

label_592:                                        ; preds = %label_597, %entry
  %3 = load ptr, ptr %p.470, align 8
  %4 = call i1 @parser_check_val__Struct_Parser_Enum_TokenType_String(ptr %3, i32 6, ptr @.str.s178)
  %5 = icmp eq i1 %4, false
  br i1 %5, label %label_593, label %label_594

label_594:                                        ; preds = %label_592
  %6 = load ptr, ptr %p.470, align 8
  call void @parser_expect_val__Struct_Parser_Enum_TokenType_String_String(ptr %6, i32 6, ptr @.str.s180, ptr @.str.s181)
  %7 = load ptr, ptr %block_node.471, align 8
  ret ptr %7

label_593:                                        ; preds = %label_592
  %8 = load ptr, ptr %p.470, align 8
  %9 = call ptr @parse_statement__Struct_Parser(ptr %8)
  store ptr %9, ptr %stmt.473, align 8
  %10 = load ptr, ptr %block_node.471, align 8
  %11 = getelementptr inbounds nuw %ASTNode, ptr %10, i32 0, i32 5
  %12 = load ptr, ptr %11, align 8
  %13 = call i32 @str_equals(ptr %12, ptr @.str.s179)
  %14 = icmp eq i32 %13, 1
  br i1 %14, label %label_595, label %label_596

label_596:                                        ; preds = %label_593
  %15 = load ptr, ptr %last_stmt.472, align 8
  %16 = call ptr @ptr_to_node(ptr %15)
  store ptr %16, ptr %last.474, align 8
  %17 = load ptr, ptr %last.474, align 8
  %18 = load ptr, ptr %stmt.473, align 8
  %19 = call ptr @node_to_ptr(ptr %18)
  %20 = getelementptr inbounds nuw %ASTNode, ptr %17, i32 0, i32 8
  store ptr %19, ptr %20, align 8
  br label %label_597

label_595:                                        ; preds = %label_593
  %21 = load ptr, ptr %block_node.471, align 8
  %22 = load ptr, ptr %stmt.473, align 8
  %23 = call ptr @node_to_ptr(ptr %22)
  %24 = getelementptr inbounds nuw %ASTNode, ptr %21, i32 0, i32 5
  store ptr %23, ptr %24, align 8
  br label %label_597

label_597:                                        ; preds = %label_596, %label_595
  %25 = load ptr, ptr %stmt.473, align 8
  %26 = call ptr @node_to_ptr(ptr %25)
  store ptr %26, ptr %last_stmt.472, align 8
  br label %label_592
}

define ptr @parse_statement__Struct_Parser(ptr %0) {
entry:
  %p.492 = alloca ptr, align 8
  store ptr %0, ptr %p.492, align 8
  %1 = load ptr, ptr %p.492, align 8
  %2 = call i1 @parser_check_val__Struct_Parser_Enum_TokenType_String(ptr %1, i32 18, ptr @.str.s224)
  %ret_node.493 = alloca ptr, align 8
  %curr.494 = alloca ptr, align 8
  %sc.44 = alloca i1, align 1
  %expr.495 = alloca ptr, align 8
  %assign_stmt.496 = alloca ptr, align 8
  %assign_tok.497 = alloca ptr, align 8
  %sc.45 = alloca i1, align 1
  %op.498 = alloca ptr, align 8
  %combined.499 = alloca ptr, align 8
  %compound.500 = alloca ptr, align 8
  %stmt.501 = alloca ptr, align 8
  br i1 %2, label %label_613, label %label_615

label_615:                                        ; preds = %entry
  %3 = load ptr, ptr %p.492, align 8
  %4 = call i1 @parser_check_val__Struct_Parser_Enum_TokenType_String(ptr %3, i32 18, ptr @.str.s225)
  br i1 %4, label %label_616, label %label_618

label_613:                                        ; preds = %entry
  %5 = load ptr, ptr %p.492, align 8
  %6 = call ptr @parse_if_statement__Struct_Parser(ptr %5)
  ret ptr %6

label_618:                                        ; preds = %label_615
  %7 = load ptr, ptr %p.492, align 8
  %8 = call i1 @parser_check_val__Struct_Parser_Enum_TokenType_String(ptr %7, i32 18, ptr @.str.s226)
  br i1 %8, label %label_619, label %label_621

label_616:                                        ; preds = %label_615
  %9 = load ptr, ptr %p.492, align 8
  %10 = call ptr @parse_while_statement__Struct_Parser(ptr %9)
  ret ptr %10

label_621:                                        ; preds = %label_618
  %11 = load ptr, ptr %p.492, align 8
  %12 = call i1 @parser_check_val__Struct_Parser_Enum_TokenType_String(ptr %11, i32 18, ptr @.str.s227)
  br i1 %12, label %label_622, label %label_624

label_619:                                        ; preds = %label_618
  %13 = load ptr, ptr %p.492, align 8
  %14 = call ptr @parse_loop_statement__Struct_Parser(ptr %13)
  ret ptr %14

label_624:                                        ; preds = %label_621
  %15 = load ptr, ptr %p.492, align 8
  %16 = call i1 @parser_check_val__Struct_Parser_Enum_TokenType_String(ptr %15, i32 18, ptr @.str.s228)
  br i1 %16, label %label_625, label %label_627

label_622:                                        ; preds = %label_621
  %17 = load ptr, ptr %p.492, align 8
  %18 = call ptr @parse_match_statement__Struct_Parser(ptr %17)
  ret ptr %18

label_627:                                        ; preds = %label_624
  %19 = load ptr, ptr %p.492, align 8
  %20 = call i1 @parser_match_val__Struct_Parser_Enum_TokenType_String(ptr %19, i32 18, ptr @.str.s229)
  br i1 %20, label %label_628, label %label_630

label_625:                                        ; preds = %label_624
  %21 = load ptr, ptr %p.492, align 8
  %22 = call ptr @parse_for_statement__Struct_Parser(ptr %21)
  ret ptr %22

label_630:                                        ; preds = %label_627
  %23 = load ptr, ptr %p.492, align 8
  %24 = call i1 @parser_match_val__Struct_Parser_Enum_TokenType_String(ptr %23, i32 18, ptr @.str.s230)
  br i1 %24, label %label_631, label %label_633

label_628:                                        ; preds = %label_627
  %25 = call ptr @create_node__Enum_NodeKind(i32 18)
  ret ptr %25

label_633:                                        ; preds = %label_630
  %26 = load ptr, ptr %p.492, align 8
  %27 = call i1 @parser_match_val__Struct_Parser_Enum_TokenType_String(ptr %26, i32 18, ptr @.str.s231)
  br i1 %27, label %label_634, label %label_636

label_631:                                        ; preds = %label_630
  %28 = call ptr @create_node__Enum_NodeKind(i32 19)
  ret ptr %28

label_636:                                        ; preds = %label_633
  %29 = load ptr, ptr %p.492, align 8
  %30 = call i1 @parser_check_val__Struct_Parser_Enum_TokenType_String(ptr %29, i32 18, ptr @.str.s233)
  br i1 %30, label %label_642, label %label_644

label_634:                                        ; preds = %label_633
  %31 = call ptr @create_node__Enum_NodeKind(i32 15)
  store ptr %31, ptr %ret_node.493, align 8
  %32 = load ptr, ptr %p.492, align 8
  %33 = call ptr @parser_current__Struct_Parser(ptr %32)
  store ptr %33, ptr %curr.494, align 8
  %34 = load ptr, ptr %curr.494, align 8
  %35 = getelementptr inbounds nuw %Token, ptr %34, i32 0, i32 0
  %36 = load i32, ptr %35, align 4
  %37 = icmp ne i32 %36, 6
  store i1 %37, ptr %sc.44, align 1
  br i1 %37, label %label_638, label %label_637

label_637:                                        ; preds = %label_634
  %38 = load ptr, ptr %curr.494, align 8
  %39 = getelementptr inbounds nuw %Token, ptr %38, i32 0, i32 1
  %40 = load ptr, ptr %39, align 8
  %41 = call i32 @str_equals(ptr %40, ptr @.str.s232)
  %42 = icmp eq i32 %41, 0
  store i1 %42, ptr %sc.44, align 1
  br label %label_638

label_638:                                        ; preds = %label_637, %label_634
  %43 = load i1, ptr %sc.44, align 1
  br i1 %43, label %label_639, label %label_641

label_641:                                        ; preds = %label_639, %label_638
  %44 = load ptr, ptr %ret_node.493, align 8
  ret ptr %44

label_639:                                        ; preds = %label_638
  %45 = load ptr, ptr %ret_node.493, align 8
  %46 = load ptr, ptr %p.492, align 8
  %47 = call ptr @parse_expression__Struct_Parser_Int(ptr %46, i32 0)
  %48 = call ptr @node_to_ptr(ptr %47)
  %49 = getelementptr inbounds nuw %ASTNode, ptr %45, i32 0, i32 5
  store ptr %48, ptr %49, align 8
  br label %label_641

label_644:                                        ; preds = %label_636
  %50 = load ptr, ptr %p.492, align 8
  %51 = call ptr @parse_expression__Struct_Parser_Int(ptr %50, i32 0)
  store ptr %51, ptr %expr.495, align 8
  %52 = load ptr, ptr %p.492, align 8
  %53 = call i1 @parser_match_val__Struct_Parser_Enum_TokenType_String(ptr %52, i32 12, ptr @.str.s234)
  br i1 %53, label %label_645, label %label_647

label_642:                                        ; preds = %label_636
  %54 = load ptr, ptr %p.492, align 8
  %55 = call ptr @parse_variable_decl__Struct_Parser(ptr %54)
  ret ptr %55

label_647:                                        ; preds = %label_644
  %56 = load ptr, ptr %p.492, align 8
  %57 = call ptr @parser_current__Struct_Parser(ptr %56)
  store ptr %57, ptr %assign_tok.497, align 8
  %58 = load ptr, ptr %assign_tok.497, align 8
  %59 = getelementptr inbounds nuw %Token, ptr %58, i32 0, i32 0
  %60 = load i32, ptr %59, align 4
  %61 = icmp eq i32 %60, 12
  store i1 %61, ptr %sc.45, align 1
  br i1 %61, label %label_648, label %label_649

label_645:                                        ; preds = %label_644
  %62 = call ptr @create_node__Enum_NodeKind(i32 16)
  store ptr %62, ptr %assign_stmt.496, align 8
  %63 = load ptr, ptr %assign_stmt.496, align 8
  %64 = load ptr, ptr %expr.495, align 8
  %65 = call ptr @node_to_ptr(ptr %64)
  %66 = getelementptr inbounds nuw %ASTNode, ptr %63, i32 0, i32 5
  store ptr %65, ptr %66, align 8
  %67 = load ptr, ptr %assign_stmt.496, align 8
  %68 = load ptr, ptr %p.492, align 8
  %69 = call ptr @parse_expression__Struct_Parser_Int(ptr %68, i32 0)
  %70 = call ptr @node_to_ptr(ptr %69)
  %71 = getelementptr inbounds nuw %ASTNode, ptr %67, i32 0, i32 6
  store ptr %70, ptr %71, align 8
  %72 = load ptr, ptr %assign_stmt.496, align 8
  ret ptr %72

label_649:                                        ; preds = %label_648, %label_647
  %73 = load i1, ptr %sc.45, align 1
  br i1 %73, label %label_650, label %label_652

label_648:                                        ; preds = %label_647
  %74 = load ptr, ptr %assign_tok.497, align 8
  %75 = getelementptr inbounds nuw %Token, ptr %74, i32 0, i32 1
  %76 = load ptr, ptr %75, align 8
  %77 = call i32 @str_length(ptr %76)
  %78 = icmp eq i32 %77, 2
  store i1 %78, ptr %sc.45, align 1
  br label %label_649

label_652:                                        ; preds = %label_649
  %79 = call ptr @create_node__Enum_NodeKind(i32 17)
  store ptr %79, ptr %stmt.501, align 8
  %80 = load ptr, ptr %stmt.501, align 8
  %81 = load ptr, ptr %expr.495, align 8
  %82 = call ptr @node_to_ptr(ptr %81)
  %83 = getelementptr inbounds nuw %ASTNode, ptr %80, i32 0, i32 5
  store ptr %82, ptr %83, align 8
  %84 = load ptr, ptr %stmt.501, align 8
  ret ptr %84

label_650:                                        ; preds = %label_649
  %85 = load ptr, ptr %assign_tok.497, align 8
  %86 = getelementptr inbounds nuw %Token, ptr %85, i32 0, i32 1
  %87 = load ptr, ptr %86, align 8
  %88 = call ptr @str_substring(ptr %87, i32 0, i32 1)
  store ptr %88, ptr %op.498, align 8
  %89 = load ptr, ptr %p.492, align 8
  call void @parser_advance__Struct_Parser(ptr %89)
  %90 = load ptr, ptr %expr.495, align 8
  %91 = getelementptr inbounds nuw %ASTNode, ptr %90, i32 0, i32 0
  %92 = load i32, ptr %91, align 4
  %93 = icmp ne i32 %92, 23
  br i1 %93, label %label_653, label %label_655

label_655:                                        ; preds = %label_653, %label_650
  %94 = call ptr @create_node__Enum_NodeKind(i32 20)
  store ptr %94, ptr %combined.499, align 8
  %95 = load ptr, ptr %combined.499, align 8
  %96 = load ptr, ptr %op.498, align 8
  %97 = getelementptr inbounds nuw %ASTNode, ptr %95, i32 0, i32 1
  store ptr %96, ptr %97, align 8
  %98 = load ptr, ptr %combined.499, align 8
  %99 = load ptr, ptr %expr.495, align 8
  %100 = call ptr @node_to_ptr(ptr %99)
  %101 = getelementptr inbounds nuw %ASTNode, ptr %98, i32 0, i32 5
  store ptr %100, ptr %101, align 8
  %102 = load ptr, ptr %combined.499, align 8
  %103 = load ptr, ptr %p.492, align 8
  %104 = call ptr @parse_expression__Struct_Parser_Int(ptr %103, i32 0)
  %105 = call ptr @node_to_ptr(ptr %104)
  %106 = getelementptr inbounds nuw %ASTNode, ptr %102, i32 0, i32 6
  store ptr %105, ptr %106, align 8
  %107 = call ptr @create_node__Enum_NodeKind(i32 16)
  store ptr %107, ptr %compound.500, align 8
  %108 = load ptr, ptr %compound.500, align 8
  %109 = load ptr, ptr %expr.495, align 8
  %110 = call ptr @node_to_ptr(ptr %109)
  %111 = getelementptr inbounds nuw %ASTNode, ptr %108, i32 0, i32 5
  store ptr %110, ptr %111, align 8
  %112 = load ptr, ptr %compound.500, align 8
  %113 = load ptr, ptr %combined.499, align 8
  %114 = call ptr @node_to_ptr(ptr %113)
  %115 = getelementptr inbounds nuw %ASTNode, ptr %112, i32 0, i32 6
  store ptr %114, ptr %115, align 8
  %116 = load ptr, ptr %compound.500, align 8
  ret ptr %116

label_653:                                        ; preds = %label_650
  call void @print(ptr @.str.s235)
  %117 = load ptr, ptr %assign_tok.497, align 8
  %118 = getelementptr inbounds nuw %Token, ptr %117, i32 0, i32 1
  %119 = load ptr, ptr %118, align 8
  call void @print(ptr %119)
  call void @println(ptr @.str.s236)
  call void @println(ptr @.str.s237)
  call void @exit(i32 1)
  br label %label_655
}

define ptr @parse_if_statement__Struct_Parser(ptr %0) {
entry:
  %p.475 = alloca ptr, align 8
  store ptr %0, ptr %p.475, align 8
  %1 = load ptr, ptr %p.475, align 8
  call void @parser_expect_val__Struct_Parser_Enum_TokenType_String_String(ptr %1, i32 18, ptr @.str.s182, ptr @.str.s183)
  %2 = call ptr @create_node__Enum_NodeKind(i32 10)
  %if_node.476 = alloca ptr, align 8
  store ptr %2, ptr %if_node.476, align 8
  %3 = load ptr, ptr %p.475, align 8
  call void @parser_expect_val__Struct_Parser_Enum_TokenType_String_String(ptr %3, i32 6, ptr @.str.s184, ptr @.str.s185)
  %4 = load ptr, ptr %if_node.476, align 8
  %5 = load ptr, ptr %p.475, align 8
  %6 = call ptr @parse_expression__Struct_Parser_Int(ptr %5, i32 0)
  %7 = call ptr @node_to_ptr(ptr %6)
  %8 = getelementptr inbounds nuw %ASTNode, ptr %4, i32 0, i32 5
  store ptr %7, ptr %8, align 8
  %9 = load ptr, ptr %p.475, align 8
  call void @parser_expect_val__Struct_Parser_Enum_TokenType_String_String(ptr %9, i32 6, ptr @.str.s186, ptr @.str.s187)
  %10 = load ptr, ptr %if_node.476, align 8
  %11 = load ptr, ptr %p.475, align 8
  %12 = call ptr @parse_block__Struct_Parser(ptr %11)
  %13 = call ptr @node_to_ptr(ptr %12)
  %14 = getelementptr inbounds nuw %ASTNode, ptr %10, i32 0, i32 6
  store ptr %13, ptr %14, align 8
  %15 = load ptr, ptr %p.475, align 8
  %16 = call i1 @parser_match_val__Struct_Parser_Enum_TokenType_String(ptr %15, i32 18, ptr @.str.s188)
  br i1 %16, label %label_598, label %label_600

label_600:                                        ; preds = %label_603, %entry
  %17 = load ptr, ptr %if_node.476, align 8
  ret ptr %17

label_598:                                        ; preds = %entry
  %18 = load ptr, ptr %p.475, align 8
  %19 = call i1 @parser_check_val__Struct_Parser_Enum_TokenType_String(ptr %18, i32 18, ptr @.str.s189)
  br i1 %19, label %label_601, label %label_602

label_602:                                        ; preds = %label_598
  %20 = load ptr, ptr %if_node.476, align 8
  %21 = load ptr, ptr %p.475, align 8
  %22 = call ptr @parse_block__Struct_Parser(ptr %21)
  %23 = call ptr @node_to_ptr(ptr %22)
  %24 = getelementptr inbounds nuw %ASTNode, ptr %20, i32 0, i32 7
  store ptr %23, ptr %24, align 8
  br label %label_603

label_601:                                        ; preds = %label_598
  %25 = load ptr, ptr %if_node.476, align 8
  %26 = load ptr, ptr %p.475, align 8
  %27 = call ptr @parse_if_statement__Struct_Parser(ptr %26)
  %28 = call ptr @node_to_ptr(ptr %27)
  %29 = getelementptr inbounds nuw %ASTNode, ptr %25, i32 0, i32 7
  store ptr %28, ptr %29, align 8
  br label %label_603

label_603:                                        ; preds = %label_602, %label_601
  br label %label_600
}

define ptr @parse_while_statement__Struct_Parser(ptr %0) {
entry:
  %p.477 = alloca ptr, align 8
  store ptr %0, ptr %p.477, align 8
  %1 = load ptr, ptr %p.477, align 8
  call void @parser_expect_val__Struct_Parser_Enum_TokenType_String_String(ptr %1, i32 18, ptr @.str.s190, ptr @.str.s191)
  %2 = call ptr @create_node__Enum_NodeKind(i32 13)
  %while_node.478 = alloca ptr, align 8
  store ptr %2, ptr %while_node.478, align 8
  %3 = load ptr, ptr %p.477, align 8
  call void @parser_expect_val__Struct_Parser_Enum_TokenType_String_String(ptr %3, i32 6, ptr @.str.s192, ptr @.str.s193)
  %4 = load ptr, ptr %while_node.478, align 8
  %5 = load ptr, ptr %p.477, align 8
  %6 = call ptr @parse_expression__Struct_Parser_Int(ptr %5, i32 0)
  %7 = call ptr @node_to_ptr(ptr %6)
  %8 = getelementptr inbounds nuw %ASTNode, ptr %4, i32 0, i32 5
  store ptr %7, ptr %8, align 8
  %9 = load ptr, ptr %p.477, align 8
  call void @parser_expect_val__Struct_Parser_Enum_TokenType_String_String(ptr %9, i32 6, ptr @.str.s194, ptr @.str.s195)
  %10 = load ptr, ptr %while_node.478, align 8
  %11 = load ptr, ptr %p.477, align 8
  %12 = call ptr @parse_block__Struct_Parser(ptr %11)
  %13 = call ptr @node_to_ptr(ptr %12)
  %14 = getelementptr inbounds nuw %ASTNode, ptr %10, i32 0, i32 6
  store ptr %13, ptr %14, align 8
  %15 = load ptr, ptr %while_node.478, align 8
  ret ptr %15
}

define ptr @parse_loop_statement__Struct_Parser(ptr %0) {
entry:
  %p.479 = alloca ptr, align 8
  store ptr %0, ptr %p.479, align 8
  %1 = load ptr, ptr %p.479, align 8
  call void @parser_expect_val__Struct_Parser_Enum_TokenType_String_String(ptr %1, i32 18, ptr @.str.s196, ptr @.str.s197)
  %2 = call ptr @create_node__Enum_NodeKind(i32 14)
  %loop_node.480 = alloca ptr, align 8
  store ptr %2, ptr %loop_node.480, align 8
  %3 = load ptr, ptr %loop_node.480, align 8
  %4 = load ptr, ptr %p.479, align 8
  %5 = call ptr @parse_block__Struct_Parser(ptr %4)
  %6 = call ptr @node_to_ptr(ptr %5)
  %7 = getelementptr inbounds nuw %ASTNode, ptr %3, i32 0, i32 5
  store ptr %6, ptr %7, align 8
  %8 = load ptr, ptr %loop_node.480, align 8
  ret ptr %8
}

define ptr @parse_for_statement__Struct_Parser(ptr %0) {
entry:
  %p.481 = alloca ptr, align 8
  store ptr %0, ptr %p.481, align 8
  %1 = load ptr, ptr %p.481, align 8
  call void @parser_expect_val__Struct_Parser_Enum_TokenType_String_String(ptr %1, i32 18, ptr @.str.s198, ptr @.str.s199)
  %2 = call ptr @create_node__Enum_NodeKind(i32 12)
  %for_node.482 = alloca ptr, align 8
  store ptr %2, ptr %for_node.482, align 8
  %3 = load ptr, ptr %p.481, align 8
  %4 = call ptr @parser_current__Struct_Parser(ptr %3)
  %curr.483 = alloca ptr, align 8
  store ptr %4, ptr %curr.483, align 8
  %5 = load ptr, ptr %for_node.482, align 8
  %6 = load ptr, ptr %curr.483, align 8
  %7 = getelementptr inbounds nuw %Token, ptr %6, i32 0, i32 1
  %8 = load ptr, ptr %7, align 8
  %9 = getelementptr inbounds nuw %ASTNode, ptr %5, i32 0, i32 1
  store ptr %8, ptr %9, align 8
  %10 = load ptr, ptr %p.481, align 8
  call void @parser_expect__Struct_Parser_Enum_TokenType_String(ptr %10, i32 5, ptr @.str.s200)
  %11 = load ptr, ptr %p.481, align 8
  call void @parser_expect_val__Struct_Parser_Enum_TokenType_String_String(ptr %11, i32 18, ptr @.str.s201, ptr @.str.s202)
  store i32 0, ptr @parser_allow_struct_lit, align 4
  %12 = load ptr, ptr %for_node.482, align 8
  %13 = load ptr, ptr %p.481, align 8
  %14 = call ptr @parse_expression__Struct_Parser_Int(ptr %13, i32 0)
  %15 = call ptr @node_to_ptr(ptr %14)
  %16 = getelementptr inbounds nuw %ASTNode, ptr %12, i32 0, i32 5
  store ptr %15, ptr %16, align 8
  %17 = load ptr, ptr %p.481, align 8
  call void @parser_expect_val__Struct_Parser_Enum_TokenType_String_String(ptr %17, i32 17, ptr @.str.s203, ptr @.str.s204)
  %18 = load ptr, ptr %for_node.482, align 8
  %19 = load ptr, ptr %p.481, align 8
  %20 = call ptr @parse_expression__Struct_Parser_Int(ptr %19, i32 0)
  %21 = call ptr @node_to_ptr(ptr %20)
  %22 = getelementptr inbounds nuw %ASTNode, ptr %18, i32 0, i32 6
  store ptr %21, ptr %22, align 8
  store i32 1, ptr @parser_allow_struct_lit, align 4
  %23 = load ptr, ptr %for_node.482, align 8
  %24 = load ptr, ptr %p.481, align 8
  %25 = call ptr @parse_block__Struct_Parser(ptr %24)
  %26 = call ptr @node_to_ptr(ptr %25)
  %27 = getelementptr inbounds nuw %ASTNode, ptr %23, i32 0, i32 7
  store ptr %26, ptr %27, align 8
  %28 = load ptr, ptr %for_node.482, align 8
  ret ptr %28
}

define ptr @parse_match_arm__Struct_Parser(ptr %0) {
entry:
  %p.484 = alloca ptr, align 8
  store ptr %0, ptr %p.484, align 8
  %1 = call ptr @create_node__Enum_NodeKind(i32 34)
  %arm.485 = alloca ptr, align 8
  store ptr %1, ptr %arm.485, align 8
  %2 = load ptr, ptr %p.484, align 8
  %3 = call i1 @parser_match_val__Struct_Parser_Enum_TokenType_String(ptr %2, i32 5, ptr @.str.s205)
  br i1 %3, label %label_604, label %label_605

label_605:                                        ; preds = %entry
  %4 = load ptr, ptr %arm.485, align 8
  %5 = load ptr, ptr %p.484, align 8
  %6 = call ptr @parse_expression__Struct_Parser_Int(ptr %5, i32 0)
  %7 = call ptr @node_to_ptr(ptr %6)
  %8 = getelementptr inbounds nuw %ASTNode, ptr %4, i32 0, i32 5
  store ptr %7, ptr %8, align 8
  br label %label_606

label_604:                                        ; preds = %entry
  %9 = load ptr, ptr %arm.485, align 8
  %10 = getelementptr inbounds nuw %ASTNode, ptr %9, i32 0, i32 1
  store ptr @.str.s206, ptr %10, align 8
  br label %label_606

label_606:                                        ; preds = %label_605, %label_604
  %11 = load ptr, ptr %p.484, align 8
  call void @parser_expect_val__Struct_Parser_Enum_TokenType_String_String(ptr %11, i32 16, ptr @.str.s207, ptr @.str.s208)
  %12 = load ptr, ptr %arm.485, align 8
  %13 = load ptr, ptr %p.484, align 8
  %14 = call ptr @parse_block__Struct_Parser(ptr %13)
  %15 = call ptr @node_to_ptr(ptr %14)
  %16 = getelementptr inbounds nuw %ASTNode, ptr %12, i32 0, i32 6
  store ptr %15, ptr %16, align 8
  %17 = load ptr, ptr %arm.485, align 8
  ret ptr %17
}

define ptr @parse_match_statement__Struct_Parser(ptr %0) {
entry:
  %p.486 = alloca ptr, align 8
  store ptr %0, ptr %p.486, align 8
  %1 = load ptr, ptr %p.486, align 8
  call void @parser_expect_val__Struct_Parser_Enum_TokenType_String_String(ptr %1, i32 18, ptr @.str.s209, ptr @.str.s210)
  %2 = call ptr @create_node__Enum_NodeKind(i32 11)
  %match_node.487 = alloca ptr, align 8
  store ptr %2, ptr %match_node.487, align 8
  %3 = load ptr, ptr %p.486, align 8
  call void @parser_expect_val__Struct_Parser_Enum_TokenType_String_String(ptr %3, i32 6, ptr @.str.s211, ptr @.str.s212)
  %4 = load ptr, ptr %match_node.487, align 8
  %5 = load ptr, ptr %p.486, align 8
  %6 = call ptr @parse_expression__Struct_Parser_Int(ptr %5, i32 0)
  %7 = call ptr @node_to_ptr(ptr %6)
  %8 = getelementptr inbounds nuw %ASTNode, ptr %4, i32 0, i32 5
  store ptr %7, ptr %8, align 8
  %9 = load ptr, ptr %p.486, align 8
  call void @parser_expect_val__Struct_Parser_Enum_TokenType_String_String(ptr %9, i32 6, ptr @.str.s213, ptr @.str.s214)
  %10 = load ptr, ptr %p.486, align 8
  call void @parser_expect_val__Struct_Parser_Enum_TokenType_String_String(ptr %10, i32 6, ptr @.str.s215, ptr @.str.s216)
  %head.488 = alloca ptr, align 8
  store ptr @.str.s217, ptr %head.488, align 8
  %tail_ptr.489 = alloca ptr, align 8
  store ptr @.str.s218, ptr %tail_ptr.489, align 8
  %arm.490 = alloca ptr, align 8
  %tail.491 = alloca ptr, align 8
  br label %label_607

label_607:                                        ; preds = %label_612, %entry
  %11 = load ptr, ptr %p.486, align 8
  %12 = call i1 @parser_check_val__Struct_Parser_Enum_TokenType_String(ptr %11, i32 6, ptr @.str.s219)
  %13 = icmp eq i1 %12, false
  br i1 %13, label %label_608, label %label_609

label_609:                                        ; preds = %label_607
  %14 = load ptr, ptr %p.486, align 8
  call void @parser_expect_val__Struct_Parser_Enum_TokenType_String_String(ptr %14, i32 6, ptr @.str.s222, ptr @.str.s223)
  %15 = load ptr, ptr %match_node.487, align 8
  %16 = load ptr, ptr %head.488, align 8
  %17 = getelementptr inbounds nuw %ASTNode, ptr %15, i32 0, i32 6
  store ptr %16, ptr %17, align 8
  %18 = load ptr, ptr %match_node.487, align 8
  ret ptr %18

label_608:                                        ; preds = %label_607
  %19 = load ptr, ptr %p.486, align 8
  %20 = call ptr @parse_match_arm__Struct_Parser(ptr %19)
  store ptr %20, ptr %arm.490, align 8
  %21 = load ptr, ptr %head.488, align 8
  %22 = call i32 @str_equals(ptr %21, ptr @.str.s220)
  %23 = icmp eq i32 %22, 1
  br i1 %23, label %label_610, label %label_611

label_611:                                        ; preds = %label_608
  %24 = load ptr, ptr %tail_ptr.489, align 8
  %25 = call ptr @ptr_to_node(ptr %24)
  store ptr %25, ptr %tail.491, align 8
  %26 = load ptr, ptr %tail.491, align 8
  %27 = load ptr, ptr %arm.490, align 8
  %28 = call ptr @node_to_ptr(ptr %27)
  %29 = getelementptr inbounds nuw %ASTNode, ptr %26, i32 0, i32 8
  store ptr %28, ptr %29, align 8
  %30 = load ptr, ptr %tail.491, align 8
  %31 = getelementptr inbounds nuw %ASTNode, ptr %30, i32 0, i32 8
  %32 = load ptr, ptr %31, align 8
  store ptr %32, ptr %tail_ptr.489, align 8
  br label %label_612

label_610:                                        ; preds = %label_608
  %33 = load ptr, ptr %arm.490, align 8
  %34 = call ptr @node_to_ptr(ptr %33)
  store ptr %34, ptr %head.488, align 8
  %35 = load ptr, ptr %head.488, align 8
  store ptr %35, ptr %tail_ptr.489, align 8
  br label %label_612

label_612:                                        ; preds = %label_611, %label_610
  %36 = load ptr, ptr %p.486, align 8
  %37 = call i1 @parser_match_val__Struct_Parser_Enum_TokenType_String(ptr %36, i32 6, ptr @.str.s221)
  br label %label_607
}

define i32 @get_operator_precedence__Struct_Token(ptr %0) {
entry:
  %t.502 = alloca ptr, align 8
  store ptr %0, ptr %t.502, align 8
  %1 = load ptr, ptr %t.502, align 8
  %2 = getelementptr inbounds nuw %Token, ptr %1, i32 0, i32 1
  %3 = load ptr, ptr %2, align 8
  %4 = call i32 @str_equals(ptr %3, ptr @.str.s238)
  %5 = icmp eq i32 %4, 1
  %sc.46 = alloca i1, align 1
  %sc.47 = alloca i1, align 1
  %sc.48 = alloca i1, align 1
  %sc.49 = alloca i1, align 1
  %sc.50 = alloca i1, align 1
  %sc.51 = alloca i1, align 1
  %sc.52 = alloca i1, align 1
  %sc.53 = alloca i1, align 1
  br i1 %5, label %label_656, label %label_658

label_658:                                        ; preds = %entry
  %6 = load ptr, ptr %t.502, align 8
  %7 = getelementptr inbounds nuw %Token, ptr %6, i32 0, i32 1
  %8 = load ptr, ptr %7, align 8
  %9 = call i32 @str_equals(ptr %8, ptr @.str.s239)
  %10 = icmp eq i32 %9, 1
  br i1 %10, label %label_659, label %label_661

label_656:                                        ; preds = %entry
  ret i32 1

label_661:                                        ; preds = %label_658
  %11 = load ptr, ptr %t.502, align 8
  %12 = getelementptr inbounds nuw %Token, ptr %11, i32 0, i32 0
  %13 = load i32, ptr %12, align 4
  %14 = icmp eq i32 %13, 18
  br i1 %14, label %label_662, label %label_664

label_659:                                        ; preds = %label_658
  ret i32 2

label_664:                                        ; preds = %label_661
  %15 = load ptr, ptr %t.502, align 8
  %16 = getelementptr inbounds nuw %Token, ptr %15, i32 0, i32 1
  %17 = load ptr, ptr %16, align 8
  %18 = call i32 @str_equals(ptr %17, ptr @.str.s240)
  %19 = icmp eq i32 %18, 1
  store i1 %19, ptr %sc.46, align 1
  br i1 %19, label %label_666, label %label_665

label_662:                                        ; preds = %label_661
  ret i32 0

label_665:                                        ; preds = %label_664
  %20 = load ptr, ptr %t.502, align 8
  %21 = getelementptr inbounds nuw %Token, ptr %20, i32 0, i32 1
  %22 = load ptr, ptr %21, align 8
  %23 = call i32 @str_equals(ptr %22, ptr @.str.s241)
  %24 = icmp eq i32 %23, 1
  store i1 %24, ptr %sc.46, align 1
  br label %label_666

label_666:                                        ; preds = %label_665, %label_664
  %25 = load i1, ptr %sc.46, align 1
  br i1 %25, label %label_667, label %label_669

label_669:                                        ; preds = %label_666
  %26 = load ptr, ptr %t.502, align 8
  %27 = getelementptr inbounds nuw %Token, ptr %26, i32 0, i32 1
  %28 = load ptr, ptr %27, align 8
  %29 = call i32 @str_equals(ptr %28, ptr @.str.s242)
  %30 = icmp eq i32 %29, 1
  store i1 %30, ptr %sc.49, align 1
  br i1 %30, label %label_675, label %label_674

label_667:                                        ; preds = %label_666
  ret i32 3

label_674:                                        ; preds = %label_669
  %31 = load ptr, ptr %t.502, align 8
  %32 = getelementptr inbounds nuw %Token, ptr %31, i32 0, i32 1
  %33 = load ptr, ptr %32, align 8
  %34 = call i32 @str_equals(ptr %33, ptr @.str.s243)
  %35 = icmp eq i32 %34, 1
  store i1 %35, ptr %sc.49, align 1
  br label %label_675

label_675:                                        ; preds = %label_674, %label_669
  %36 = load i1, ptr %sc.49, align 1
  store i1 %36, ptr %sc.48, align 1
  br i1 %36, label %label_673, label %label_672

label_672:                                        ; preds = %label_675
  %37 = load ptr, ptr %t.502, align 8
  %38 = getelementptr inbounds nuw %Token, ptr %37, i32 0, i32 1
  %39 = load ptr, ptr %38, align 8
  %40 = call i32 @str_equals(ptr %39, ptr @.str.s244)
  %41 = icmp eq i32 %40, 1
  store i1 %41, ptr %sc.48, align 1
  br label %label_673

label_673:                                        ; preds = %label_672, %label_675
  %42 = load i1, ptr %sc.48, align 1
  store i1 %42, ptr %sc.47, align 1
  br i1 %42, label %label_671, label %label_670

label_670:                                        ; preds = %label_673
  %43 = load ptr, ptr %t.502, align 8
  %44 = getelementptr inbounds nuw %Token, ptr %43, i32 0, i32 1
  %45 = load ptr, ptr %44, align 8
  %46 = call i32 @str_equals(ptr %45, ptr @.str.s245)
  %47 = icmp eq i32 %46, 1
  store i1 %47, ptr %sc.47, align 1
  br label %label_671

label_671:                                        ; preds = %label_670, %label_673
  %48 = load i1, ptr %sc.47, align 1
  br i1 %48, label %label_676, label %label_678

label_678:                                        ; preds = %label_671
  %49 = load ptr, ptr %t.502, align 8
  %50 = getelementptr inbounds nuw %Token, ptr %49, i32 0, i32 1
  %51 = load ptr, ptr %50, align 8
  %52 = call i32 @str_equals(ptr %51, ptr @.str.s246)
  %53 = icmp eq i32 %52, 1
  br i1 %53, label %label_679, label %label_681

label_676:                                        ; preds = %label_671
  ret i32 4

label_681:                                        ; preds = %label_678
  %54 = load ptr, ptr %t.502, align 8
  %55 = getelementptr inbounds nuw %Token, ptr %54, i32 0, i32 1
  %56 = load ptr, ptr %55, align 8
  %57 = call i32 @str_equals(ptr %56, ptr @.str.s247)
  %58 = icmp eq i32 %57, 1
  br i1 %58, label %label_682, label %label_684

label_679:                                        ; preds = %label_678
  ret i32 5

label_684:                                        ; preds = %label_681
  %59 = load ptr, ptr %t.502, align 8
  %60 = getelementptr inbounds nuw %Token, ptr %59, i32 0, i32 1
  %61 = load ptr, ptr %60, align 8
  %62 = call i32 @str_equals(ptr %61, ptr @.str.s248)
  %63 = icmp eq i32 %62, 1
  br i1 %63, label %label_685, label %label_687

label_682:                                        ; preds = %label_681
  ret i32 6

label_687:                                        ; preds = %label_684
  %64 = load ptr, ptr %t.502, align 8
  %65 = getelementptr inbounds nuw %Token, ptr %64, i32 0, i32 1
  %66 = load ptr, ptr %65, align 8
  %67 = call i32 @str_equals(ptr %66, ptr @.str.s249)
  %68 = icmp eq i32 %67, 1
  store i1 %68, ptr %sc.50, align 1
  br i1 %68, label %label_689, label %label_688

label_685:                                        ; preds = %label_684
  ret i32 7

label_688:                                        ; preds = %label_687
  %69 = load ptr, ptr %t.502, align 8
  %70 = getelementptr inbounds nuw %Token, ptr %69, i32 0, i32 1
  %71 = load ptr, ptr %70, align 8
  %72 = call i32 @str_equals(ptr %71, ptr @.str.s250)
  %73 = icmp eq i32 %72, 1
  store i1 %73, ptr %sc.50, align 1
  br label %label_689

label_689:                                        ; preds = %label_688, %label_687
  %74 = load i1, ptr %sc.50, align 1
  br i1 %74, label %label_690, label %label_692

label_692:                                        ; preds = %label_689
  %75 = load ptr, ptr %t.502, align 8
  %76 = getelementptr inbounds nuw %Token, ptr %75, i32 0, i32 1
  %77 = load ptr, ptr %76, align 8
  %78 = call i32 @str_equals(ptr %77, ptr @.str.s251)
  %79 = icmp eq i32 %78, 1
  store i1 %79, ptr %sc.51, align 1
  br i1 %79, label %label_694, label %label_693

label_690:                                        ; preds = %label_689
  ret i32 8

label_693:                                        ; preds = %label_692
  %80 = load ptr, ptr %t.502, align 8
  %81 = getelementptr inbounds nuw %Token, ptr %80, i32 0, i32 1
  %82 = load ptr, ptr %81, align 8
  %83 = call i32 @str_equals(ptr %82, ptr @.str.s252)
  %84 = icmp eq i32 %83, 1
  store i1 %84, ptr %sc.51, align 1
  br label %label_694

label_694:                                        ; preds = %label_693, %label_692
  %85 = load i1, ptr %sc.51, align 1
  br i1 %85, label %label_695, label %label_697

label_697:                                        ; preds = %label_694
  %86 = load ptr, ptr %t.502, align 8
  %87 = getelementptr inbounds nuw %Token, ptr %86, i32 0, i32 1
  %88 = load ptr, ptr %87, align 8
  %89 = call i32 @str_equals(ptr %88, ptr @.str.s253)
  %90 = icmp eq i32 %89, 1
  store i1 %90, ptr %sc.53, align 1
  br i1 %90, label %label_701, label %label_700

label_695:                                        ; preds = %label_694
  ret i32 9

label_700:                                        ; preds = %label_697
  %91 = load ptr, ptr %t.502, align 8
  %92 = getelementptr inbounds nuw %Token, ptr %91, i32 0, i32 1
  %93 = load ptr, ptr %92, align 8
  %94 = call i32 @str_equals(ptr %93, ptr @.str.s254)
  %95 = icmp eq i32 %94, 1
  store i1 %95, ptr %sc.53, align 1
  br label %label_701

label_701:                                        ; preds = %label_700, %label_697
  %96 = load i1, ptr %sc.53, align 1
  store i1 %96, ptr %sc.52, align 1
  br i1 %96, label %label_699, label %label_698

label_698:                                        ; preds = %label_701
  %97 = load ptr, ptr %t.502, align 8
  %98 = getelementptr inbounds nuw %Token, ptr %97, i32 0, i32 1
  %99 = load ptr, ptr %98, align 8
  %100 = call i32 @str_equals(ptr %99, ptr @.str.s255)
  %101 = icmp eq i32 %100, 1
  store i1 %101, ptr %sc.52, align 1
  br label %label_699

label_699:                                        ; preds = %label_698, %label_701
  %102 = load i1, ptr %sc.52, align 1
  br i1 %102, label %label_702, label %label_704

label_704:                                        ; preds = %label_699
  ret i32 0

label_702:                                        ; preds = %label_699
  ret i32 10
}

define ptr @parse_unary__Struct_Parser(ptr %0) {
entry:
  %p.503 = alloca ptr, align 8
  store ptr %0, ptr %p.503, align 8
  %1 = load ptr, ptr %p.503, align 8
  %2 = call ptr @parser_current__Struct_Parser(ptr %1)
  %curr.504 = alloca ptr, align 8
  store ptr %2, ptr %curr.504, align 8
  %sc.54 = alloca i1, align 1
  %3 = load ptr, ptr %curr.504, align 8
  %4 = getelementptr inbounds nuw %Token, ptr %3, i32 0, i32 0
  %5 = load i32, ptr %4, align 4
  %6 = icmp eq i32 %5, 8
  store i1 %6, ptr %sc.54, align 1
  %is_neg.505 = alloca i1, align 1
  %sc.55 = alloca i1, align 1
  %is_not.506 = alloca i1, align 1
  %sc.56 = alloca i1, align 1
  %is_bnot.507 = alloca i1, align 1
  %sc.57 = alloca i1, align 1
  %sc.58 = alloca i1, align 1
  %op.508 = alloca ptr, align 8
  %operand.509 = alloca ptr, align 8
  %sc.59 = alloca i1, align 1
  %sc.60 = alloca i1, align 1
  %is_number.510 = alloca i1, align 1
  %sc.61 = alloca i1, align 1
  %unary.511 = alloca ptr, align 8
  br i1 %6, label %label_705, label %label_706

label_706:                                        ; preds = %label_705, %entry
  %7 = load i1, ptr %sc.54, align 1
  store i1 %7, ptr %is_neg.505, align 1
  %8 = load ptr, ptr %curr.504, align 8
  %9 = getelementptr inbounds nuw %Token, ptr %8, i32 0, i32 0
  %10 = load i32, ptr %9, align 4
  %11 = icmp eq i32 %10, 10
  store i1 %11, ptr %sc.55, align 1
  br i1 %11, label %label_707, label %label_708

label_705:                                        ; preds = %entry
  %12 = load ptr, ptr %curr.504, align 8
  %13 = getelementptr inbounds nuw %Token, ptr %12, i32 0, i32 1
  %14 = load ptr, ptr %13, align 8
  %15 = call i32 @str_equals(ptr %14, ptr @.str.s256)
  %16 = icmp eq i32 %15, 1
  store i1 %16, ptr %sc.54, align 1
  br label %label_706

label_708:                                        ; preds = %label_707, %label_706
  %17 = load i1, ptr %sc.55, align 1
  store i1 %17, ptr %is_not.506, align 1
  %18 = load ptr, ptr %curr.504, align 8
  %19 = getelementptr inbounds nuw %Token, ptr %18, i32 0, i32 0
  %20 = load i32, ptr %19, align 4
  %21 = icmp eq i32 %20, 8
  store i1 %21, ptr %sc.56, align 1
  br i1 %21, label %label_709, label %label_710

label_707:                                        ; preds = %label_706
  %22 = load ptr, ptr %curr.504, align 8
  %23 = getelementptr inbounds nuw %Token, ptr %22, i32 0, i32 1
  %24 = load ptr, ptr %23, align 8
  %25 = call i32 @str_equals(ptr %24, ptr @.str.s257)
  %26 = icmp eq i32 %25, 1
  store i1 %26, ptr %sc.55, align 1
  br label %label_708

label_710:                                        ; preds = %label_709, %label_708
  %27 = load i1, ptr %sc.56, align 1
  store i1 %27, ptr %is_bnot.507, align 1
  %28 = load i1, ptr %is_neg.505, align 1
  store i1 %28, ptr %sc.58, align 1
  br i1 %28, label %label_714, label %label_713

label_709:                                        ; preds = %label_708
  %29 = load ptr, ptr %curr.504, align 8
  %30 = getelementptr inbounds nuw %Token, ptr %29, i32 0, i32 1
  %31 = load ptr, ptr %30, align 8
  %32 = call i32 @str_equals(ptr %31, ptr @.str.s258)
  %33 = icmp eq i32 %32, 1
  store i1 %33, ptr %sc.56, align 1
  br label %label_710

label_713:                                        ; preds = %label_710
  %34 = load i1, ptr %is_not.506, align 1
  store i1 %34, ptr %sc.58, align 1
  br label %label_714

label_714:                                        ; preds = %label_713, %label_710
  %35 = load i1, ptr %sc.58, align 1
  store i1 %35, ptr %sc.57, align 1
  br i1 %35, label %label_712, label %label_711

label_711:                                        ; preds = %label_714
  %36 = load i1, ptr %is_bnot.507, align 1
  store i1 %36, ptr %sc.57, align 1
  br label %label_712

label_712:                                        ; preds = %label_711, %label_714
  %37 = load i1, ptr %sc.57, align 1
  br i1 %37, label %label_715, label %label_717

label_717:                                        ; preds = %label_712
  %38 = load ptr, ptr %p.503, align 8
  %39 = call ptr @parse_postfix__Struct_Parser(ptr %38)
  ret ptr %39

label_715:                                        ; preds = %label_712
  %40 = load ptr, ptr %curr.504, align 8
  %41 = getelementptr inbounds nuw %Token, ptr %40, i32 0, i32 1
  %42 = load ptr, ptr %41, align 8
  store ptr %42, ptr %op.508, align 8
  %43 = load ptr, ptr %p.503, align 8
  call void @parser_advance__Struct_Parser(ptr %43)
  %44 = load ptr, ptr %p.503, align 8
  %45 = call ptr @parse_unary__Struct_Parser(ptr %44)
  store ptr %45, ptr %operand.509, align 8
  %46 = load ptr, ptr %op.508, align 8
  %47 = call i32 @str_equals(ptr %46, ptr @.str.s259)
  %48 = icmp eq i32 %47, 1
  store i1 %48, ptr %sc.59, align 1
  br i1 %48, label %label_718, label %label_719

label_719:                                        ; preds = %label_718, %label_715
  %49 = load i1, ptr %sc.59, align 1
  br i1 %49, label %label_720, label %label_722

label_718:                                        ; preds = %label_715
  %50 = load ptr, ptr %operand.509, align 8
  %51 = getelementptr inbounds nuw %ASTNode, ptr %50, i32 0, i32 0
  %52 = load i32, ptr %51, align 4
  %53 = icmp eq i32 %52, 22
  store i1 %53, ptr %sc.59, align 1
  br label %label_719

label_722:                                        ; preds = %label_729, %label_719
  %54 = call ptr @create_node__Enum_NodeKind(i32 21)
  store ptr %54, ptr %unary.511, align 8
  %55 = load ptr, ptr %unary.511, align 8
  %56 = load ptr, ptr %op.508, align 8
  %57 = getelementptr inbounds nuw %ASTNode, ptr %55, i32 0, i32 1
  store ptr %56, ptr %57, align 8
  %58 = load ptr, ptr %unary.511, align 8
  %59 = load ptr, ptr %operand.509, align 8
  %60 = call ptr @node_to_ptr(ptr %59)
  %61 = getelementptr inbounds nuw %ASTNode, ptr %58, i32 0, i32 5
  store ptr %60, ptr %61, align 8
  %62 = load ptr, ptr %unary.511, align 8
  ret ptr %62

label_720:                                        ; preds = %label_719
  %63 = load ptr, ptr %operand.509, align 8
  %64 = getelementptr inbounds nuw %ASTNode, ptr %63, i32 0, i32 3
  %65 = load i32, ptr %64, align 4
  %66 = icmp eq i32 %65, 2
  store i1 %66, ptr %sc.60, align 1
  br i1 %66, label %label_724, label %label_723

label_723:                                        ; preds = %label_720
  %67 = load ptr, ptr %operand.509, align 8
  %68 = getelementptr inbounds nuw %ASTNode, ptr %67, i32 0, i32 3
  %69 = load i32, ptr %68, align 4
  %70 = icmp eq i32 %69, 3
  store i1 %70, ptr %sc.60, align 1
  br label %label_724

label_724:                                        ; preds = %label_723, %label_720
  %71 = load i1, ptr %sc.60, align 1
  store i1 %71, ptr %is_number.510, align 1
  %72 = load i1, ptr %is_number.510, align 1
  store i1 %72, ptr %sc.61, align 1
  br i1 %72, label %label_725, label %label_726

label_726:                                        ; preds = %label_725, %label_724
  %73 = load i1, ptr %sc.61, align 1
  br i1 %73, label %label_727, label %label_729

label_725:                                        ; preds = %label_724
  %74 = load ptr, ptr %operand.509, align 8
  %75 = getelementptr inbounds nuw %ASTNode, ptr %74, i32 0, i32 1
  %76 = load ptr, ptr %75, align 8
  %77 = call i32 @str_starts_with(ptr %76, ptr @.str.s260)
  %78 = icmp eq i32 %77, 0
  store i1 %78, ptr %sc.61, align 1
  br label %label_726

label_729:                                        ; preds = %label_726
  br label %label_722

label_727:                                        ; preds = %label_726
  %79 = load ptr, ptr %operand.509, align 8
  %80 = load ptr, ptr %operand.509, align 8
  %81 = getelementptr inbounds nuw %ASTNode, ptr %80, i32 0, i32 1
  %82 = load ptr, ptr %81, align 8
  %83 = call ptr @str_concat(ptr @.str.s261, ptr %82)
  %84 = getelementptr inbounds nuw %ASTNode, ptr %79, i32 0, i32 1
  store ptr %83, ptr %84, align 8
  %85 = load ptr, ptr %operand.509, align 8
  ret ptr %85
}

define ptr @parse_postfix__Struct_Parser(ptr %0) {
entry:
  %p.512 = alloca ptr, align 8
  store ptr %0, ptr %p.512, align 8
  %1 = load ptr, ptr %p.512, align 8
  %2 = call ptr @parse_primary__Struct_Parser(ptr %1)
  %expr.513 = alloca ptr, align 8
  store ptr %2, ptr %expr.513, align 8
  %casting.514 = alloca i1, align 1
  store i1 true, ptr %casting.514, align 1
  %cast.515 = alloca ptr, align 8
  br label %label_730

label_730:                                        ; preds = %label_735, %entry
  %3 = load i1, ptr %casting.514, align 1
  br i1 %3, label %label_731, label %label_732

label_732:                                        ; preds = %label_730
  %4 = load ptr, ptr %expr.513, align 8
  ret ptr %4

label_731:                                        ; preds = %label_730
  %5 = load ptr, ptr %p.512, align 8
  %6 = call i1 @parser_match_val__Struct_Parser_Enum_TokenType_String(ptr %5, i32 18, ptr @.str.s262)
  br i1 %6, label %label_733, label %label_734

label_734:                                        ; preds = %label_731
  store i1 false, ptr %casting.514, align 1
  br label %label_735

label_733:                                        ; preds = %label_731
  %7 = call ptr @create_node__Enum_NodeKind(i32 29)
  store ptr %7, ptr %cast.515, align 8
  %8 = load ptr, ptr %cast.515, align 8
  %9 = load ptr, ptr %expr.513, align 8
  %10 = call ptr @node_to_ptr(ptr %9)
  %11 = getelementptr inbounds nuw %ASTNode, ptr %8, i32 0, i32 5
  store ptr %10, ptr %11, align 8
  %12 = load ptr, ptr %cast.515, align 8
  %13 = load ptr, ptr %p.512, align 8
  %14 = call ptr @parse_type_annotation__Struct_Parser(ptr %13)
  %15 = call ptr @node_to_ptr(ptr %14)
  %16 = getelementptr inbounds nuw %ASTNode, ptr %12, i32 0, i32 6
  store ptr %15, ptr %16, align 8
  %17 = load ptr, ptr %cast.515, align 8
  store ptr %17, ptr %expr.513, align 8
  br label %label_735

label_735:                                        ; preds = %label_734, %label_733
  br label %label_730
}

define ptr @parse_primary__Struct_Parser(ptr %0) {
entry:
  %p.526 = alloca ptr, align 8
  store ptr %0, ptr %p.526, align 8
  %1 = load ptr, ptr %p.526, align 8
  %2 = call ptr @parser_current__Struct_Parser(ptr %1)
  %curr.527 = alloca ptr, align 8
  store ptr %2, ptr %curr.527, align 8
  %sc.66 = alloca i1, align 1
  %sc.67 = alloca i1, align 1
  %sc.68 = alloca i1, align 1
  %sc.69 = alloca i1, align 1
  %3 = load ptr, ptr %curr.527, align 8
  %4 = getelementptr inbounds nuw %Token, ptr %3, i32 0, i32 0
  %5 = load i32, ptr %4, align 4
  %6 = icmp eq i32 %5, 2
  store i1 %6, ptr %sc.69, align 1
  %lit.528 = alloca ptr, align 8
  %next_tok.529 = alloca ptr, align 8
  %sc.70 = alloca i1, align 1
  %sc.71 = alloca i1, align 1
  %struct_lit.530 = alloca ptr, align 8
  %last_field.531 = alloca ptr, align 8
  %field.532 = alloca ptr, align 8
  %field_tok.533 = alloca ptr, align 8
  %last.534 = alloca ptr, align 8
  %ident.535 = alloca ptr, align 8
  %expr.536 = alloca ptr, align 8
  %is_looping.537 = alloca i1, align 1
  %call.538 = alloca ptr, align 8
  %last_arg.539 = alloca ptr, align 8
  %is_arg_looping.540 = alloca i1, align 1
  %arg.541 = alloca ptr, align 8
  %last.542 = alloca ptr, align 8
  %index_node.543 = alloca ptr, align 8
  %member_node.544 = alloca ptr, align 8
  %curr_mem.545 = alloca ptr, align 8
  %expr_inner.546 = alloca ptr, align 8
  %array_lit.547 = alloca ptr, align 8
  %last_elem.548 = alloca ptr, align 8
  %is_looping.549 = alloca i1, align 1
  %elem.550 = alloca ptr, align 8
  %last.551 = alloca ptr, align 8
  br i1 %6, label %label_760, label %label_759

label_759:                                        ; preds = %entry
  %7 = load ptr, ptr %curr.527, align 8
  %8 = getelementptr inbounds nuw %Token, ptr %7, i32 0, i32 0
  %9 = load i32, ptr %8, align 4
  %10 = icmp eq i32 %9, 3
  store i1 %10, ptr %sc.69, align 1
  br label %label_760

label_760:                                        ; preds = %label_759, %entry
  %11 = load i1, ptr %sc.69, align 1
  store i1 %11, ptr %sc.68, align 1
  br i1 %11, label %label_758, label %label_757

label_757:                                        ; preds = %label_760
  %12 = load ptr, ptr %curr.527, align 8
  %13 = getelementptr inbounds nuw %Token, ptr %12, i32 0, i32 0
  %14 = load i32, ptr %13, align 4
  %15 = icmp eq i32 %14, 0
  store i1 %15, ptr %sc.68, align 1
  br label %label_758

label_758:                                        ; preds = %label_757, %label_760
  %16 = load i1, ptr %sc.68, align 1
  store i1 %16, ptr %sc.67, align 1
  br i1 %16, label %label_756, label %label_755

label_755:                                        ; preds = %label_758
  %17 = load ptr, ptr %curr.527, align 8
  %18 = getelementptr inbounds nuw %Token, ptr %17, i32 0, i32 0
  %19 = load i32, ptr %18, align 4
  %20 = icmp eq i32 %19, 4
  store i1 %20, ptr %sc.67, align 1
  br label %label_756

label_756:                                        ; preds = %label_755, %label_758
  %21 = load i1, ptr %sc.67, align 1
  store i1 %21, ptr %sc.66, align 1
  br i1 %21, label %label_754, label %label_753

label_753:                                        ; preds = %label_756
  %22 = load ptr, ptr %curr.527, align 8
  %23 = getelementptr inbounds nuw %Token, ptr %22, i32 0, i32 0
  %24 = load i32, ptr %23, align 4
  %25 = icmp eq i32 %24, 1
  store i1 %25, ptr %sc.66, align 1
  br label %label_754

label_754:                                        ; preds = %label_753, %label_756
  %26 = load i1, ptr %sc.66, align 1
  br i1 %26, label %label_761, label %label_763

label_763:                                        ; preds = %label_754
  %27 = load ptr, ptr %curr.527, align 8
  %28 = getelementptr inbounds nuw %Token, ptr %27, i32 0, i32 0
  %29 = load i32, ptr %28, align 4
  %30 = icmp eq i32 %29, 5
  br i1 %30, label %label_764, label %label_766

label_761:                                        ; preds = %label_754
  %31 = call ptr @create_node__Enum_NodeKind(i32 22)
  store ptr %31, ptr %lit.528, align 8
  %32 = load ptr, ptr %lit.528, align 8
  %33 = load ptr, ptr %curr.527, align 8
  %34 = getelementptr inbounds nuw %Token, ptr %33, i32 0, i32 0
  %35 = load i32, ptr %34, align 4
  %36 = getelementptr inbounds nuw %ASTNode, ptr %32, i32 0, i32 3
  store i32 %35, ptr %36, align 4
  %37 = load ptr, ptr %lit.528, align 8
  %38 = load ptr, ptr %curr.527, align 8
  %39 = getelementptr inbounds nuw %Token, ptr %38, i32 0, i32 1
  %40 = load ptr, ptr %39, align 8
  %41 = getelementptr inbounds nuw %ASTNode, ptr %37, i32 0, i32 1
  store ptr %40, ptr %41, align 8
  %42 = load ptr, ptr %p.526, align 8
  call void @parser_advance__Struct_Parser(ptr %42)
  %43 = load ptr, ptr %lit.528, align 8
  ret ptr %43

label_766:                                        ; preds = %label_773, %label_763
  %44 = load ptr, ptr %curr.527, align 8
  %45 = getelementptr inbounds nuw %Token, ptr %44, i32 0, i32 0
  %46 = load i32, ptr %45, align 4
  %47 = icmp eq i32 %46, 5
  br i1 %47, label %label_780, label %label_782

label_764:                                        ; preds = %label_763
  %48 = load ptr, ptr %p.526, align 8
  %49 = call ptr @parser_peek__Struct_Parser(ptr %48)
  store ptr %49, ptr %next_tok.529, align 8
  %50 = load ptr, ptr %next_tok.529, align 8
  %51 = getelementptr inbounds nuw %Token, ptr %50, i32 0, i32 0
  %52 = load i32, ptr %51, align 4
  %53 = icmp eq i32 %52, 6
  store i1 %53, ptr %sc.71, align 1
  br i1 %53, label %label_769, label %label_770

label_770:                                        ; preds = %label_769, %label_764
  %54 = load i1, ptr %sc.71, align 1
  store i1 %54, ptr %sc.70, align 1
  br i1 %54, label %label_767, label %label_768

label_769:                                        ; preds = %label_764
  %55 = load ptr, ptr %next_tok.529, align 8
  %56 = getelementptr inbounds nuw %Token, ptr %55, i32 0, i32 1
  %57 = load ptr, ptr %56, align 8
  %58 = call i32 @str_equals(ptr %57, ptr @.str.s265)
  %59 = icmp eq i32 %58, 1
  store i1 %59, ptr %sc.71, align 1
  br label %label_770

label_768:                                        ; preds = %label_767, %label_770
  %60 = load i1, ptr %sc.70, align 1
  br i1 %60, label %label_771, label %label_773

label_767:                                        ; preds = %label_770
  %61 = load i32, ptr @parser_allow_struct_lit, align 4
  %62 = icmp eq i32 %61, 1
  store i1 %62, ptr %sc.70, align 1
  br label %label_768

label_773:                                        ; preds = %label_768
  br label %label_766

label_771:                                        ; preds = %label_768
  %63 = call ptr @create_node__Enum_NodeKind(i32 28)
  store ptr %63, ptr %struct_lit.530, align 8
  %64 = load ptr, ptr %struct_lit.530, align 8
  %65 = load ptr, ptr %curr.527, align 8
  %66 = getelementptr inbounds nuw %Token, ptr %65, i32 0, i32 1
  %67 = load ptr, ptr %66, align 8
  %68 = getelementptr inbounds nuw %ASTNode, ptr %64, i32 0, i32 1
  store ptr %67, ptr %68, align 8
  %69 = load ptr, ptr %p.526, align 8
  call void @parser_advance__Struct_Parser(ptr %69)
  %70 = load ptr, ptr %p.526, align 8
  call void @parser_expect_val__Struct_Parser_Enum_TokenType_String_String(ptr %70, i32 6, ptr @.str.s266, ptr @.str.s267)
  store ptr @.str.s268, ptr %last_field.531, align 8
  br label %label_774

label_774:                                        ; preds = %label_779, %label_771
  %71 = load ptr, ptr %p.526, align 8
  %72 = call i1 @parser_check_val__Struct_Parser_Enum_TokenType_String(ptr %71, i32 6, ptr @.str.s269)
  %73 = icmp eq i1 %72, false
  br i1 %73, label %label_775, label %label_776

label_776:                                        ; preds = %label_774
  %74 = load ptr, ptr %p.526, align 8
  call void @parser_expect_val__Struct_Parser_Enum_TokenType_String_String(ptr %74, i32 6, ptr @.str.s275, ptr @.str.s276)
  %75 = load ptr, ptr %struct_lit.530, align 8
  ret ptr %75

label_775:                                        ; preds = %label_774
  %76 = call ptr @create_node__Enum_NodeKind(i32 32)
  store ptr %76, ptr %field.532, align 8
  %77 = load ptr, ptr %p.526, align 8
  %78 = call ptr @parser_current__Struct_Parser(ptr %77)
  store ptr %78, ptr %field_tok.533, align 8
  %79 = load ptr, ptr %field.532, align 8
  %80 = load ptr, ptr %field_tok.533, align 8
  %81 = getelementptr inbounds nuw %Token, ptr %80, i32 0, i32 1
  %82 = load ptr, ptr %81, align 8
  %83 = getelementptr inbounds nuw %ASTNode, ptr %79, i32 0, i32 1
  store ptr %82, ptr %83, align 8
  %84 = load ptr, ptr %p.526, align 8
  call void @parser_expect__Struct_Parser_Enum_TokenType_String(ptr %84, i32 5, ptr @.str.s270)
  %85 = load ptr, ptr %p.526, align 8
  call void @parser_expect_val__Struct_Parser_Enum_TokenType_String_String(ptr %85, i32 6, ptr @.str.s271, ptr @.str.s272)
  %86 = load ptr, ptr %field.532, align 8
  %87 = load ptr, ptr %p.526, align 8
  %88 = call ptr @parse_expression__Struct_Parser_Int(ptr %87, i32 0)
  %89 = call ptr @node_to_ptr(ptr %88)
  %90 = getelementptr inbounds nuw %ASTNode, ptr %86, i32 0, i32 5
  store ptr %89, ptr %90, align 8
  %91 = load ptr, ptr %struct_lit.530, align 8
  %92 = getelementptr inbounds nuw %ASTNode, ptr %91, i32 0, i32 5
  %93 = load ptr, ptr %92, align 8
  %94 = call i32 @str_equals(ptr %93, ptr @.str.s273)
  %95 = icmp eq i32 %94, 1
  br i1 %95, label %label_777, label %label_778

label_778:                                        ; preds = %label_775
  %96 = load ptr, ptr %last_field.531, align 8
  %97 = call ptr @ptr_to_node(ptr %96)
  store ptr %97, ptr %last.534, align 8
  %98 = load ptr, ptr %last.534, align 8
  %99 = load ptr, ptr %field.532, align 8
  %100 = call ptr @node_to_ptr(ptr %99)
  %101 = getelementptr inbounds nuw %ASTNode, ptr %98, i32 0, i32 8
  store ptr %100, ptr %101, align 8
  br label %label_779

label_777:                                        ; preds = %label_775
  %102 = load ptr, ptr %struct_lit.530, align 8
  %103 = load ptr, ptr %field.532, align 8
  %104 = call ptr @node_to_ptr(ptr %103)
  %105 = getelementptr inbounds nuw %ASTNode, ptr %102, i32 0, i32 5
  store ptr %104, ptr %105, align 8
  br label %label_779

label_779:                                        ; preds = %label_778, %label_777
  %106 = load ptr, ptr %field.532, align 8
  %107 = call ptr @node_to_ptr(ptr %106)
  store ptr %107, ptr %last_field.531, align 8
  %108 = load ptr, ptr %p.526, align 8
  %109 = call i1 @parser_match_val__Struct_Parser_Enum_TokenType_String(ptr %108, i32 6, ptr @.str.s274)
  br label %label_774

label_782:                                        ; preds = %label_766
  %110 = load ptr, ptr %p.526, align 8
  %111 = call i1 @parser_match_val__Struct_Parser_Enum_TokenType_String(ptr %110, i32 6, ptr @.str.s289)
  br i1 %111, label %label_807, label %label_809

label_780:                                        ; preds = %label_766
  %112 = call ptr @create_node__Enum_NodeKind(i32 23)
  store ptr %112, ptr %ident.535, align 8
  %113 = load ptr, ptr %ident.535, align 8
  %114 = load ptr, ptr %curr.527, align 8
  %115 = getelementptr inbounds nuw %Token, ptr %114, i32 0, i32 1
  %116 = load ptr, ptr %115, align 8
  %117 = getelementptr inbounds nuw %ASTNode, ptr %113, i32 0, i32 1
  store ptr %116, ptr %117, align 8
  %118 = load ptr, ptr %p.526, align 8
  call void @parser_advance__Struct_Parser(ptr %118)
  %119 = load ptr, ptr %ident.535, align 8
  store ptr %119, ptr %expr.536, align 8
  store i1 true, ptr %is_looping.537, align 1
  br label %label_783

label_783:                                        ; preds = %label_788, %label_780
  %120 = load i1, ptr %is_looping.537, align 1
  br i1 %120, label %label_784, label %label_785

label_785:                                        ; preds = %label_783
  %121 = load ptr, ptr %expr.536, align 8
  ret ptr %121

label_784:                                        ; preds = %label_783
  %122 = load ptr, ptr %p.526, align 8
  %123 = call i1 @parser_match_val__Struct_Parser_Enum_TokenType_String(ptr %122, i32 6, ptr @.str.s277)
  br i1 %123, label %label_786, label %label_787

label_787:                                        ; preds = %label_784
  %124 = load ptr, ptr %p.526, align 8
  %125 = call i1 @parser_match_val__Struct_Parser_Enum_TokenType_String(ptr %124, i32 6, ptr @.str.s284)
  br i1 %125, label %label_801, label %label_802

label_786:                                        ; preds = %label_784
  %126 = call ptr @create_node__Enum_NodeKind(i32 24)
  store ptr %126, ptr %call.538, align 8
  %127 = load ptr, ptr %call.538, align 8
  %128 = load ptr, ptr %expr.536, align 8
  %129 = call ptr @node_to_ptr(ptr %128)
  %130 = getelementptr inbounds nuw %ASTNode, ptr %127, i32 0, i32 5
  store ptr %129, ptr %130, align 8
  store ptr @.str.s278, ptr %last_arg.539, align 8
  %131 = load ptr, ptr %p.526, align 8
  %132 = call i1 @parser_check_val__Struct_Parser_Enum_TokenType_String(ptr %131, i32 6, ptr @.str.s279)
  %133 = icmp eq i1 %132, false
  br i1 %133, label %label_789, label %label_791

label_791:                                        ; preds = %label_794, %label_786
  %134 = load ptr, ptr %p.526, align 8
  call void @parser_expect_val__Struct_Parser_Enum_TokenType_String_String(ptr %134, i32 6, ptr @.str.s282, ptr @.str.s283)
  %135 = load ptr, ptr %call.538, align 8
  store ptr %135, ptr %expr.536, align 8
  br label %label_788

label_789:                                        ; preds = %label_786
  store i1 true, ptr %is_arg_looping.540, align 1
  br label %label_792

label_792:                                        ; preds = %label_800, %label_789
  %136 = load i1, ptr %is_arg_looping.540, align 1
  br i1 %136, label %label_793, label %label_794

label_794:                                        ; preds = %label_792
  br label %label_791

label_793:                                        ; preds = %label_792
  %137 = load ptr, ptr %p.526, align 8
  %138 = call ptr @parse_expression__Struct_Parser_Int(ptr %137, i32 0)
  store ptr %138, ptr %arg.541, align 8
  %139 = load ptr, ptr %call.538, align 8
  %140 = getelementptr inbounds nuw %ASTNode, ptr %139, i32 0, i32 6
  %141 = load ptr, ptr %140, align 8
  %142 = call i32 @str_equals(ptr %141, ptr @.str.s280)
  %143 = icmp eq i32 %142, 1
  br i1 %143, label %label_795, label %label_796

label_796:                                        ; preds = %label_793
  %144 = load ptr, ptr %last_arg.539, align 8
  %145 = call ptr @ptr_to_node(ptr %144)
  store ptr %145, ptr %last.542, align 8
  %146 = load ptr, ptr %last.542, align 8
  %147 = load ptr, ptr %arg.541, align 8
  %148 = call ptr @node_to_ptr(ptr %147)
  %149 = getelementptr inbounds nuw %ASTNode, ptr %146, i32 0, i32 8
  store ptr %148, ptr %149, align 8
  br label %label_797

label_795:                                        ; preds = %label_793
  %150 = load ptr, ptr %call.538, align 8
  %151 = load ptr, ptr %arg.541, align 8
  %152 = call ptr @node_to_ptr(ptr %151)
  %153 = getelementptr inbounds nuw %ASTNode, ptr %150, i32 0, i32 6
  store ptr %152, ptr %153, align 8
  br label %label_797

label_797:                                        ; preds = %label_796, %label_795
  %154 = load ptr, ptr %arg.541, align 8
  %155 = call ptr @node_to_ptr(ptr %154)
  store ptr %155, ptr %last_arg.539, align 8
  %156 = load ptr, ptr %p.526, align 8
  %157 = call i1 @parser_match_val__Struct_Parser_Enum_TokenType_String(ptr %156, i32 6, ptr @.str.s281)
  %158 = icmp eq i1 %157, false
  br i1 %158, label %label_798, label %label_800

label_800:                                        ; preds = %label_798, %label_797
  br label %label_792

label_798:                                        ; preds = %label_797
  store i1 false, ptr %is_arg_looping.540, align 1
  br label %label_800

label_788:                                        ; preds = %label_803, %label_791
  br label %label_783

label_802:                                        ; preds = %label_787
  %159 = load ptr, ptr %p.526, align 8
  %160 = call i1 @parser_match_val__Struct_Parser_Enum_TokenType_String(ptr %159, i32 6, ptr @.str.s287)
  br i1 %160, label %label_804, label %label_805

label_801:                                        ; preds = %label_787
  %161 = call ptr @create_node__Enum_NodeKind(i32 26)
  store ptr %161, ptr %index_node.543, align 8
  %162 = load ptr, ptr %index_node.543, align 8
  %163 = load ptr, ptr %expr.536, align 8
  %164 = call ptr @node_to_ptr(ptr %163)
  %165 = getelementptr inbounds nuw %ASTNode, ptr %162, i32 0, i32 5
  store ptr %164, ptr %165, align 8
  %166 = load ptr, ptr %index_node.543, align 8
  %167 = load ptr, ptr %p.526, align 8
  %168 = call ptr @parse_expression__Struct_Parser_Int(ptr %167, i32 0)
  %169 = call ptr @node_to_ptr(ptr %168)
  %170 = getelementptr inbounds nuw %ASTNode, ptr %166, i32 0, i32 6
  store ptr %169, ptr %170, align 8
  %171 = load ptr, ptr %p.526, align 8
  call void @parser_expect_val__Struct_Parser_Enum_TokenType_String_String(ptr %171, i32 6, ptr @.str.s285, ptr @.str.s286)
  %172 = load ptr, ptr %index_node.543, align 8
  store ptr %172, ptr %expr.536, align 8
  br label %label_803

label_803:                                        ; preds = %label_806, %label_801
  br label %label_788

label_805:                                        ; preds = %label_802
  store i1 false, ptr %is_looping.537, align 1
  br label %label_806

label_804:                                        ; preds = %label_802
  %173 = call ptr @create_node__Enum_NodeKind(i32 25)
  store ptr %173, ptr %member_node.544, align 8
  %174 = load ptr, ptr %member_node.544, align 8
  %175 = load ptr, ptr %expr.536, align 8
  %176 = call ptr @node_to_ptr(ptr %175)
  %177 = getelementptr inbounds nuw %ASTNode, ptr %174, i32 0, i32 5
  store ptr %176, ptr %177, align 8
  %178 = load ptr, ptr %p.526, align 8
  %179 = call ptr @parser_current__Struct_Parser(ptr %178)
  store ptr %179, ptr %curr_mem.545, align 8
  %180 = load ptr, ptr %member_node.544, align 8
  %181 = load ptr, ptr %curr_mem.545, align 8
  %182 = getelementptr inbounds nuw %Token, ptr %181, i32 0, i32 1
  %183 = load ptr, ptr %182, align 8
  %184 = getelementptr inbounds nuw %ASTNode, ptr %180, i32 0, i32 1
  store ptr %183, ptr %184, align 8
  %185 = load ptr, ptr %p.526, align 8
  call void @parser_expect__Struct_Parser_Enum_TokenType_String(ptr %185, i32 5, ptr @.str.s288)
  %186 = load ptr, ptr %member_node.544, align 8
  store ptr %186, ptr %expr.536, align 8
  br label %label_806

label_806:                                        ; preds = %label_805, %label_804
  br label %label_803

label_809:                                        ; preds = %label_782
  %187 = load ptr, ptr %p.526, align 8
  %188 = call i1 @parser_match_val__Struct_Parser_Enum_TokenType_String(ptr %187, i32 6, ptr @.str.s292)
  br i1 %188, label %label_810, label %label_812

label_807:                                        ; preds = %label_782
  %189 = load ptr, ptr %p.526, align 8
  %190 = call ptr @parse_expression__Struct_Parser_Int(ptr %189, i32 0)
  store ptr %190, ptr %expr_inner.546, align 8
  %191 = load ptr, ptr %p.526, align 8
  call void @parser_expect_val__Struct_Parser_Enum_TokenType_String_String(ptr %191, i32 6, ptr @.str.s290, ptr @.str.s291)
  %192 = load ptr, ptr %expr_inner.546, align 8
  ret ptr %192

label_812:                                        ; preds = %label_809
  call void @print(ptr @.str.s299)
  %193 = load ptr, ptr %curr.527, align 8
  %194 = getelementptr inbounds nuw %Token, ptr %193, i32 0, i32 0
  %195 = load i32, ptr %194, align 4
  %196 = call ptr @type_to_string__Enum_TokenType(i32 %195)
  call void @print(ptr %196)
  call void @print(ptr @.str.s300)
  %197 = load ptr, ptr %curr.527, align 8
  %198 = getelementptr inbounds nuw %Token, ptr %197, i32 0, i32 1
  %199 = load ptr, ptr %198, align 8
  call void @print(ptr %199)
  call void @println(ptr @.str.s301)
  call void @exit(i32 1)
  %200 = call ptr @create_node__Enum_NodeKind(i32 0)
  ret ptr %200

label_810:                                        ; preds = %label_809
  %201 = call ptr @create_node__Enum_NodeKind(i32 27)
  store ptr %201, ptr %array_lit.547, align 8
  store ptr @.str.s293, ptr %last_elem.548, align 8
  %202 = load ptr, ptr %p.526, align 8
  %203 = call i1 @parser_check_val__Struct_Parser_Enum_TokenType_String(ptr %202, i32 6, ptr @.str.s294)
  %204 = icmp eq i1 %203, false
  br i1 %204, label %label_813, label %label_815

label_815:                                        ; preds = %label_818, %label_810
  %205 = load ptr, ptr %p.526, align 8
  call void @parser_expect_val__Struct_Parser_Enum_TokenType_String_String(ptr %205, i32 6, ptr @.str.s297, ptr @.str.s298)
  %206 = load ptr, ptr %array_lit.547, align 8
  ret ptr %206

label_813:                                        ; preds = %label_810
  store i1 true, ptr %is_looping.549, align 1
  br label %label_816

label_816:                                        ; preds = %label_824, %label_813
  %207 = load i1, ptr %is_looping.549, align 1
  br i1 %207, label %label_817, label %label_818

label_818:                                        ; preds = %label_816
  br label %label_815

label_817:                                        ; preds = %label_816
  %208 = load ptr, ptr %p.526, align 8
  %209 = call ptr @parse_expression__Struct_Parser_Int(ptr %208, i32 0)
  store ptr %209, ptr %elem.550, align 8
  %210 = load ptr, ptr %array_lit.547, align 8
  %211 = getelementptr inbounds nuw %ASTNode, ptr %210, i32 0, i32 5
  %212 = load ptr, ptr %211, align 8
  %213 = call i32 @str_equals(ptr %212, ptr @.str.s295)
  %214 = icmp eq i32 %213, 1
  br i1 %214, label %label_819, label %label_820

label_820:                                        ; preds = %label_817
  %215 = load ptr, ptr %last_elem.548, align 8
  %216 = call ptr @ptr_to_node(ptr %215)
  store ptr %216, ptr %last.551, align 8
  %217 = load ptr, ptr %last.551, align 8
  %218 = load ptr, ptr %elem.550, align 8
  %219 = call ptr @node_to_ptr(ptr %218)
  %220 = getelementptr inbounds nuw %ASTNode, ptr %217, i32 0, i32 8
  store ptr %219, ptr %220, align 8
  br label %label_821

label_819:                                        ; preds = %label_817
  %221 = load ptr, ptr %array_lit.547, align 8
  %222 = load ptr, ptr %elem.550, align 8
  %223 = call ptr @node_to_ptr(ptr %222)
  %224 = getelementptr inbounds nuw %ASTNode, ptr %221, i32 0, i32 5
  store ptr %223, ptr %224, align 8
  br label %label_821

label_821:                                        ; preds = %label_820, %label_819
  %225 = load ptr, ptr %elem.550, align 8
  %226 = call ptr @node_to_ptr(ptr %225)
  store ptr %226, ptr %last_elem.548, align 8
  %227 = load ptr, ptr %p.526, align 8
  %228 = call i1 @parser_match_val__Struct_Parser_Enum_TokenType_String(ptr %227, i32 6, ptr @.str.s296)
  %229 = icmp eq i1 %228, false
  br i1 %229, label %label_822, label %label_824

label_824:                                        ; preds = %label_822, %label_821
  br label %label_816

label_822:                                        ; preds = %label_821
  store i1 false, ptr %is_looping.549, align 1
  br label %label_824
}

define ptr @parse_module__Struct_Parser(ptr %0) {
entry:
  %p.552 = alloca ptr, align 8
  store ptr %0, ptr %p.552, align 8
  %1 = call ptr @create_node__Enum_NodeKind(i32 0)
  %module.553 = alloca ptr, align 8
  store ptr %1, ptr %module.553, align 8
  %last_stmt.554 = alloca ptr, align 8
  store ptr @.str.s302, ptr %last_stmt.554, align 8
  %is_looping.555 = alloca i1, align 1
  store i1 true, ptr %is_looping.555, align 1
  %curr.556 = alloca ptr, align 8
  %stmt.557 = alloca ptr, align 8
  %last.558 = alloca ptr, align 8
  br label %label_825

label_825:                                        ; preds = %label_830, %entry
  %2 = load i1, ptr %is_looping.555, align 1
  br i1 %2, label %label_826, label %label_827

label_827:                                        ; preds = %label_825
  %3 = load ptr, ptr %module.553, align 8
  ret ptr %3

label_826:                                        ; preds = %label_825
  %4 = load ptr, ptr %p.552, align 8
  %5 = call ptr @parser_current__Struct_Parser(ptr %4)
  store ptr %5, ptr %curr.556, align 8
  %6 = load ptr, ptr %curr.556, align 8
  %7 = getelementptr inbounds nuw %Token, ptr %6, i32 0, i32 0
  %8 = load i32, ptr %7, align 4
  %9 = icmp eq i32 %8, 20
  br i1 %9, label %label_828, label %label_829

label_829:                                        ; preds = %label_826
  %10 = load ptr, ptr %p.552, align 8
  %11 = call ptr @parse_declaration__Struct_Parser(ptr %10)
  store ptr %11, ptr %stmt.557, align 8
  %12 = load ptr, ptr %module.553, align 8
  %13 = getelementptr inbounds nuw %ASTNode, ptr %12, i32 0, i32 5
  %14 = load ptr, ptr %13, align 8
  %15 = call i32 @str_equals(ptr %14, ptr @.str.s303)
  %16 = icmp eq i32 %15, 1
  br i1 %16, label %label_831, label %label_832

label_828:                                        ; preds = %label_826
  store i1 false, ptr %is_looping.555, align 1
  br label %label_830

label_830:                                        ; preds = %label_833, %label_828
  br label %label_825

label_832:                                        ; preds = %label_829
  %17 = load ptr, ptr %last_stmt.554, align 8
  %18 = call ptr @ptr_to_node(ptr %17)
  store ptr %18, ptr %last.558, align 8
  %19 = load ptr, ptr %last.558, align 8
  %20 = load ptr, ptr %stmt.557, align 8
  %21 = call ptr @node_to_ptr(ptr %20)
  %22 = getelementptr inbounds nuw %ASTNode, ptr %19, i32 0, i32 8
  store ptr %21, ptr %22, align 8
  br label %label_833

label_831:                                        ; preds = %label_829
  %23 = load ptr, ptr %module.553, align 8
  %24 = load ptr, ptr %stmt.557, align 8
  %25 = call ptr @node_to_ptr(ptr %24)
  %26 = getelementptr inbounds nuw %ASTNode, ptr %23, i32 0, i32 5
  store ptr %25, ptr %26, align 8
  br label %label_833

label_833:                                        ; preds = %label_832, %label_831
  %27 = load ptr, ptr %stmt.557, align 8
  %28 = call ptr @node_to_ptr(ptr %27)
  store ptr %28, ptr %last_stmt.554, align 8
  br label %label_830
}

define ptr @type_make__Enum_TypeKind_String_String(i32 %0, ptr %1, ptr %2) {
entry:
  %kind.559 = alloca i32, align 4
  store i32 %0, ptr %kind.559, align 4
  %name.560 = alloca ptr, align 8
  store ptr %1, ptr %name.560, align 8
  %llvm.561 = alloca ptr, align 8
  store ptr %2, ptr %llvm.561, align 8
  %3 = call ptr @malloc(i64 ptrtoint (ptr getelementptr (%TypeInfo, ptr null, i32 1) to i64))
  %4 = load i32, ptr %kind.559, align 4
  %5 = getelementptr inbounds nuw %TypeInfo, ptr %3, i32 0, i32 0
  store i32 %4, ptr %5, align 4
  %6 = load ptr, ptr %name.560, align 8
  %7 = getelementptr inbounds nuw %TypeInfo, ptr %3, i32 0, i32 1
  store ptr %6, ptr %7, align 8
  %8 = load ptr, ptr %llvm.561, align 8
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
  %t.562 = alloca ptr, align 8
  store ptr %0, ptr %t.562, align 8
  %1 = load ptr, ptr %t.562, align 8
  %2 = getelementptr inbounds nuw %TypeInfo, ptr %1, i32 0, i32 0
  %3 = load i32, ptr %2, align 4
  %4 = load ptr, ptr %t.562, align 8
  %5 = getelementptr inbounds nuw %TypeInfo, ptr %4, i32 0, i32 1
  %6 = load ptr, ptr %5, align 8
  %7 = load ptr, ptr %t.562, align 8
  %8 = getelementptr inbounds nuw %TypeInfo, ptr %7, i32 0, i32 2
  %9 = load ptr, ptr %8, align 8
  %10 = call ptr @type_make__Enum_TypeKind_String_String(i32 %3, ptr %6, ptr %9)
  %dup.563 = alloca ptr, align 8
  store ptr %10, ptr %dup.563, align 8
  %11 = load ptr, ptr %dup.563, align 8
  %12 = load ptr, ptr %t.562, align 8
  %13 = getelementptr inbounds nuw %TypeInfo, ptr %12, i32 0, i32 3
  %14 = load ptr, ptr %13, align 8
  %15 = getelementptr inbounds nuw %TypeInfo, ptr %11, i32 0, i32 3
  store ptr %14, ptr %15, align 8
  %16 = load ptr, ptr %dup.563, align 8
  %17 = load ptr, ptr %t.562, align 8
  %18 = getelementptr inbounds nuw %TypeInfo, ptr %17, i32 0, i32 4
  %19 = load ptr, ptr %18, align 8
  %20 = getelementptr inbounds nuw %TypeInfo, ptr %16, i32 0, i32 4
  store ptr %19, ptr %20, align 8
  %21 = load ptr, ptr %dup.563, align 8
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
  %t.564 = alloca ptr, align 8
  store ptr %0, ptr %t.564, align 8
  %1 = load ptr, ptr %t.564, align 8
  %2 = getelementptr inbounds nuw %TypeInfo, ptr %1, i32 0, i32 2
  %3 = load ptr, ptr %2, align 8
  %4 = call i32 @str_equals(ptr %3, ptr @.str.s340)
  %5 = icmp eq i32 %4, 1
  br i1 %5, label %label_834, label %label_836

label_836:                                        ; preds = %entry
  %6 = load ptr, ptr %t.564, align 8
  %7 = getelementptr inbounds nuw %TypeInfo, ptr %6, i32 0, i32 2
  %8 = load ptr, ptr %7, align 8
  %9 = call i32 @str_equals(ptr %8, ptr @.str.s341)
  %10 = icmp eq i32 %9, 1
  br i1 %10, label %label_837, label %label_839

label_834:                                        ; preds = %entry
  ret i32 1

label_839:                                        ; preds = %label_836
  %11 = load ptr, ptr %t.564, align 8
  %12 = getelementptr inbounds nuw %TypeInfo, ptr %11, i32 0, i32 2
  %13 = load ptr, ptr %12, align 8
  %14 = call i32 @str_equals(ptr %13, ptr @.str.s342)
  %15 = icmp eq i32 %14, 1
  br i1 %15, label %label_840, label %label_842

label_837:                                        ; preds = %label_836
  ret i32 8

label_842:                                        ; preds = %label_839
  %16 = load ptr, ptr %t.564, align 8
  %17 = getelementptr inbounds nuw %TypeInfo, ptr %16, i32 0, i32 2
  %18 = load ptr, ptr %17, align 8
  %19 = call i32 @str_equals(ptr %18, ptr @.str.s343)
  %20 = icmp eq i32 %19, 1
  br i1 %20, label %label_843, label %label_845

label_840:                                        ; preds = %label_839
  ret i32 16

label_845:                                        ; preds = %label_842
  %21 = load ptr, ptr %t.564, align 8
  %22 = getelementptr inbounds nuw %TypeInfo, ptr %21, i32 0, i32 2
  %23 = load ptr, ptr %22, align 8
  %24 = call i32 @str_equals(ptr %23, ptr @.str.s344)
  %25 = icmp eq i32 %24, 1
  br i1 %25, label %label_846, label %label_848

label_843:                                        ; preds = %label_842
  ret i32 32

label_848:                                        ; preds = %label_845
  ret i32 0

label_846:                                        ; preds = %label_845
  ret i32 64
}

define i1 @type_int_is_unsigned__Struct_TypeInfo(ptr %0) {
entry:
  %t.565 = alloca ptr, align 8
  store ptr %0, ptr %t.565, align 8
  %1 = load ptr, ptr %t.565, align 8
  %2 = getelementptr inbounds nuw %TypeInfo, ptr %1, i32 0, i32 0
  %3 = load i32, ptr %2, align 4
  %4 = icmp ne i32 %3, 2
  br i1 %4, label %label_849, label %label_851

label_851:                                        ; preds = %entry
  %5 = load ptr, ptr %t.565, align 8
  %6 = getelementptr inbounds nuw %TypeInfo, ptr %5, i32 0, i32 1
  %7 = load ptr, ptr %6, align 8
  %8 = call i32 @str_starts_with(ptr %7, ptr @.str.s345)
  %9 = icmp eq i32 %8, 1
  ret i1 %9

label_849:                                        ; preds = %entry
  ret i1 false
}

define i1 @type_is_move_only__Struct_TypeInfo(ptr %0) {
entry:
  %t.566 = alloca ptr, align 8
  store ptr %0, ptr %t.566, align 8
  %1 = load ptr, ptr %t.566, align 8
  %2 = getelementptr inbounds nuw %TypeInfo, ptr %1, i32 0, i32 0
  %3 = load i32, ptr %2, align 4
  %4 = icmp eq i32 %3, 8
  ret i1 %4
}

define ptr @type_struct__String(ptr %0) {
entry:
  %name.567 = alloca ptr, align 8
  store ptr %0, ptr %name.567, align 8
  %1 = load ptr, ptr %name.567, align 8
  %2 = call ptr @type_make__Enum_TypeKind_String_String(i32 8, ptr %1, ptr @.str.s346)
  ret ptr %2
}

define ptr @type_enum__String(ptr %0) {
entry:
  %name.568 = alloca ptr, align 8
  store ptr %0, ptr %name.568, align 8
  %1 = load ptr, ptr %name.568, align 8
  %2 = call ptr @type_make__Enum_TypeKind_String_String(i32 9, ptr %1, ptr @.str.s347)
  ret ptr %2
}

define ptr @type_array__Struct_TypeInfo(ptr %0) {
entry:
  %elem.569 = alloca ptr, align 8
  store ptr %0, ptr %elem.569, align 8
  %1 = call ptr @type_make__Enum_TypeKind_String_String(i32 10, ptr @.str.s348, ptr @.str.s349)
  %t.570 = alloca ptr, align 8
  store ptr %1, ptr %t.570, align 8
  %2 = load ptr, ptr %t.570, align 8
  %3 = load ptr, ptr %elem.569, align 8
  %4 = call ptr @type_to_ptr(ptr %3)
  %5 = getelementptr inbounds nuw %TypeInfo, ptr %2, i32 0, i32 3
  store ptr %4, ptr %5, align 8
  %6 = load ptr, ptr %t.570, align 8
  ret ptr %6
}

define ptr @type_list__Struct_TypeInfo(ptr %0) {
entry:
  %elem.571 = alloca ptr, align 8
  store ptr %0, ptr %elem.571, align 8
  %1 = call ptr @type_make__Enum_TypeKind_String_String(i32 11, ptr @.str.s350, ptr @.str.s351)
  %t.572 = alloca ptr, align 8
  store ptr %1, ptr %t.572, align 8
  %2 = load ptr, ptr %t.572, align 8
  %3 = load ptr, ptr %elem.571, align 8
  %4 = call ptr @type_to_ptr(ptr %3)
  %5 = getelementptr inbounds nuw %TypeInfo, ptr %2, i32 0, i32 3
  store ptr %4, ptr %5, align 8
  %6 = load ptr, ptr %t.572, align 8
  ret ptr %6
}

define i1 @type_is_valid__Struct_TypeInfo(ptr %0) {
entry:
  %t.573 = alloca ptr, align 8
  store ptr %0, ptr %t.573, align 8
  %1 = load ptr, ptr %t.573, align 8
  %2 = getelementptr inbounds nuw %TypeInfo, ptr %1, i32 0, i32 0
  %3 = load i32, ptr %2, align 4
  %4 = icmp ne i32 %3, 0
  ret i1 %4
}

define ptr @type_display__Struct_TypeInfo(ptr %0) {
entry:
  %t.574 = alloca ptr, align 8
  store ptr %0, ptr %t.574, align 8
  %1 = load ptr, ptr %t.574, align 8
  %2 = getelementptr inbounds nuw %TypeInfo, ptr %1, i32 0, i32 0
  %3 = load i32, ptr %2, align 4
  %4 = icmp eq i32 %3, 8
  br i1 %4, label %label_852, label %label_854

label_854:                                        ; preds = %entry
  %5 = load ptr, ptr %t.574, align 8
  %6 = getelementptr inbounds nuw %TypeInfo, ptr %5, i32 0, i32 0
  %7 = load i32, ptr %6, align 4
  %8 = icmp eq i32 %7, 9
  br i1 %8, label %label_855, label %label_857

label_852:                                        ; preds = %entry
  %9 = load ptr, ptr %t.574, align 8
  %10 = getelementptr inbounds nuw %TypeInfo, ptr %9, i32 0, i32 1
  %11 = load ptr, ptr %10, align 8
  ret ptr %11

label_857:                                        ; preds = %label_854
  %12 = load ptr, ptr %t.574, align 8
  %13 = getelementptr inbounds nuw %TypeInfo, ptr %12, i32 0, i32 0
  %14 = load i32, ptr %13, align 4
  %15 = icmp eq i32 %14, 10
  br i1 %15, label %label_858, label %label_860

label_855:                                        ; preds = %label_854
  %16 = load ptr, ptr %t.574, align 8
  %17 = getelementptr inbounds nuw %TypeInfo, ptr %16, i32 0, i32 1
  %18 = load ptr, ptr %17, align 8
  ret ptr %18

label_860:                                        ; preds = %label_857
  %19 = load ptr, ptr %t.574, align 8
  %20 = getelementptr inbounds nuw %TypeInfo, ptr %19, i32 0, i32 0
  %21 = load i32, ptr %20, align 4
  %22 = icmp eq i32 %21, 11
  br i1 %22, label %label_864, label %label_866

label_858:                                        ; preds = %label_857
  %23 = load ptr, ptr %t.574, align 8
  %24 = getelementptr inbounds nuw %TypeInfo, ptr %23, i32 0, i32 3
  %25 = load ptr, ptr %24, align 8
  %26 = call i32 @str_equals(ptr %25, ptr @.str.s352)
  %27 = icmp eq i32 %26, 0
  br i1 %27, label %label_861, label %label_863

label_863:                                        ; preds = %label_858
  ret ptr @.str.s355

label_861:                                        ; preds = %label_858
  %28 = load ptr, ptr %t.574, align 8
  %29 = getelementptr inbounds nuw %TypeInfo, ptr %28, i32 0, i32 3
  %30 = load ptr, ptr %29, align 8
  %31 = call ptr @ptr_to_type(ptr %30)
  %32 = call ptr @type_display__Struct_TypeInfo(ptr %31)
  %33 = call ptr @str_concat(ptr @.str.s353, ptr %32)
  %34 = call ptr @str_concat(ptr %33, ptr @.str.s354)
  ret ptr %34

label_866:                                        ; preds = %label_860
  %35 = load ptr, ptr %t.574, align 8
  %36 = getelementptr inbounds nuw %TypeInfo, ptr %35, i32 0, i32 1
  %37 = load ptr, ptr %36, align 8
  ret ptr %37

label_864:                                        ; preds = %label_860
  %38 = load ptr, ptr %t.574, align 8
  %39 = getelementptr inbounds nuw %TypeInfo, ptr %38, i32 0, i32 3
  %40 = load ptr, ptr %39, align 8
  %41 = call i32 @str_equals(ptr %40, ptr @.str.s356)
  %42 = icmp eq i32 %41, 0
  br i1 %42, label %label_867, label %label_869

label_869:                                        ; preds = %label_864
  ret ptr @.str.s359

label_867:                                        ; preds = %label_864
  %43 = load ptr, ptr %t.574, align 8
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
  %a.575 = alloca ptr, align 8
  store ptr %0, ptr %a.575, align 8
  %b.576 = alloca ptr, align 8
  store ptr %1, ptr %b.576, align 8
  %2 = load ptr, ptr %a.575, align 8
  %3 = getelementptr inbounds nuw %TypeInfo, ptr %2, i32 0, i32 0
  %4 = load i32, ptr %3, align 4
  %5 = load ptr, ptr %b.576, align 8
  %6 = getelementptr inbounds nuw %TypeInfo, ptr %5, i32 0, i32 0
  %7 = load i32, ptr %6, align 4
  %8 = icmp ne i32 %4, %7
  %sc.72 = alloca i1, align 1
  %sc.73 = alloca i1, align 1
  %sc.74 = alloca i1, align 1
  %ac.577 = alloca ptr, align 8
  %bc.578 = alloca ptr, align 8
  %sc.75 = alloca i1, align 1
  br i1 %8, label %label_870, label %label_872

label_872:                                        ; preds = %entry
  %9 = load ptr, ptr %a.575, align 8
  %10 = getelementptr inbounds nuw %TypeInfo, ptr %9, i32 0, i32 0
  %11 = load i32, ptr %10, align 4
  %12 = icmp eq i32 %11, 8
  store i1 %12, ptr %sc.72, align 1
  br i1 %12, label %label_874, label %label_873

label_870:                                        ; preds = %entry
  ret i1 false

label_873:                                        ; preds = %label_872
  %13 = load ptr, ptr %a.575, align 8
  %14 = getelementptr inbounds nuw %TypeInfo, ptr %13, i32 0, i32 0
  %15 = load i32, ptr %14, align 4
  %16 = icmp eq i32 %15, 9
  store i1 %16, ptr %sc.72, align 1
  br label %label_874

label_874:                                        ; preds = %label_873, %label_872
  %17 = load i1, ptr %sc.72, align 1
  br i1 %17, label %label_875, label %label_877

label_877:                                        ; preds = %label_874
  %18 = load ptr, ptr %a.575, align 8
  %19 = getelementptr inbounds nuw %TypeInfo, ptr %18, i32 0, i32 0
  %20 = load i32, ptr %19, align 4
  %21 = icmp eq i32 %20, 2
  br i1 %21, label %label_878, label %label_880

label_875:                                        ; preds = %label_874
  %22 = load ptr, ptr %a.575, align 8
  %23 = getelementptr inbounds nuw %TypeInfo, ptr %22, i32 0, i32 1
  %24 = load ptr, ptr %23, align 8
  %25 = load ptr, ptr %b.576, align 8
  %26 = getelementptr inbounds nuw %TypeInfo, ptr %25, i32 0, i32 1
  %27 = load ptr, ptr %26, align 8
  %28 = call i32 @str_equals(ptr %24, ptr %27)
  %29 = icmp eq i32 %28, 1
  ret i1 %29

label_880:                                        ; preds = %label_877
  %30 = load ptr, ptr %a.575, align 8
  %31 = getelementptr inbounds nuw %TypeInfo, ptr %30, i32 0, i32 0
  %32 = load i32, ptr %31, align 4
  %33 = icmp eq i32 %32, 10
  br i1 %33, label %label_881, label %label_883

label_878:                                        ; preds = %label_877
  %34 = load ptr, ptr %a.575, align 8
  %35 = getelementptr inbounds nuw %TypeInfo, ptr %34, i32 0, i32 1
  %36 = load ptr, ptr %35, align 8
  %37 = load ptr, ptr %b.576, align 8
  %38 = getelementptr inbounds nuw %TypeInfo, ptr %37, i32 0, i32 1
  %39 = load ptr, ptr %38, align 8
  %40 = call i32 @str_equals(ptr %36, ptr %39)
  %41 = icmp eq i32 %40, 1
  ret i1 %41

label_883:                                        ; preds = %label_880
  %42 = load ptr, ptr %a.575, align 8
  %43 = getelementptr inbounds nuw %TypeInfo, ptr %42, i32 0, i32 0
  %44 = load i32, ptr %43, align 4
  %45 = icmp eq i32 %44, 11
  br i1 %45, label %label_889, label %label_891

label_881:                                        ; preds = %label_880
  %46 = load ptr, ptr %a.575, align 8
  %47 = getelementptr inbounds nuw %TypeInfo, ptr %46, i32 0, i32 3
  %48 = load ptr, ptr %47, align 8
  %49 = call i32 @str_equals(ptr %48, ptr @.str.s360)
  %50 = icmp eq i32 %49, 1
  store i1 %50, ptr %sc.73, align 1
  br i1 %50, label %label_885, label %label_884

label_884:                                        ; preds = %label_881
  %51 = load ptr, ptr %b.576, align 8
  %52 = getelementptr inbounds nuw %TypeInfo, ptr %51, i32 0, i32 3
  %53 = load ptr, ptr %52, align 8
  %54 = call i32 @str_equals(ptr %53, ptr @.str.s361)
  %55 = icmp eq i32 %54, 1
  store i1 %55, ptr %sc.73, align 1
  br label %label_885

label_885:                                        ; preds = %label_884, %label_881
  %56 = load i1, ptr %sc.73, align 1
  br i1 %56, label %label_886, label %label_888

label_888:                                        ; preds = %label_885
  %57 = load ptr, ptr %a.575, align 8
  %58 = getelementptr inbounds nuw %TypeInfo, ptr %57, i32 0, i32 3
  %59 = load ptr, ptr %58, align 8
  %60 = call ptr @ptr_to_type(ptr %59)
  %61 = load ptr, ptr %b.576, align 8
  %62 = getelementptr inbounds nuw %TypeInfo, ptr %61, i32 0, i32 3
  %63 = load ptr, ptr %62, align 8
  %64 = call ptr @ptr_to_type(ptr %63)
  %65 = call i1 @type_equals__Struct_TypeInfo_Struct_TypeInfo(ptr %60, ptr %64)
  ret i1 %65

label_886:                                        ; preds = %label_885
  %66 = load ptr, ptr %a.575, align 8
  %67 = getelementptr inbounds nuw %TypeInfo, ptr %66, i32 0, i32 3
  %68 = load ptr, ptr %67, align 8
  %69 = load ptr, ptr %b.576, align 8
  %70 = getelementptr inbounds nuw %TypeInfo, ptr %69, i32 0, i32 3
  %71 = load ptr, ptr %70, align 8
  %72 = call i32 @str_equals(ptr %68, ptr %71)
  %73 = icmp eq i32 %72, 1
  ret i1 %73

label_891:                                        ; preds = %label_883
  ret i1 true

label_889:                                        ; preds = %label_883
  %74 = load ptr, ptr %a.575, align 8
  %75 = getelementptr inbounds nuw %TypeInfo, ptr %74, i32 0, i32 3
  %76 = load ptr, ptr %75, align 8
  %77 = call i32 @str_equals(ptr %76, ptr @.str.s362)
  %78 = icmp eq i32 %77, 1
  store i1 %78, ptr %sc.74, align 1
  br i1 %78, label %label_893, label %label_892

label_892:                                        ; preds = %label_889
  %79 = load ptr, ptr %b.576, align 8
  %80 = getelementptr inbounds nuw %TypeInfo, ptr %79, i32 0, i32 3
  %81 = load ptr, ptr %80, align 8
  %82 = call i32 @str_equals(ptr %81, ptr @.str.s363)
  %83 = icmp eq i32 %82, 1
  store i1 %83, ptr %sc.74, align 1
  br label %label_893

label_893:                                        ; preds = %label_892, %label_889
  %84 = load i1, ptr %sc.74, align 1
  br i1 %84, label %label_894, label %label_896

label_896:                                        ; preds = %label_893
  %85 = load ptr, ptr %a.575, align 8
  %86 = getelementptr inbounds nuw %TypeInfo, ptr %85, i32 0, i32 3
  %87 = load ptr, ptr %86, align 8
  %88 = call ptr @ptr_to_type(ptr %87)
  store ptr %88, ptr %ac.577, align 8
  %89 = load ptr, ptr %b.576, align 8
  %90 = getelementptr inbounds nuw %TypeInfo, ptr %89, i32 0, i32 3
  %91 = load ptr, ptr %90, align 8
  %92 = call ptr @ptr_to_type(ptr %91)
  store ptr %92, ptr %bc.578, align 8
  %93 = load ptr, ptr %ac.577, align 8
  %94 = call i1 @type_is_valid__Struct_TypeInfo(ptr %93)
  %95 = icmp eq i1 %94, false
  store i1 %95, ptr %sc.75, align 1
  br i1 %95, label %label_898, label %label_897

label_894:                                        ; preds = %label_893
  ret i1 true

label_897:                                        ; preds = %label_896
  %96 = load ptr, ptr %bc.578, align 8
  %97 = call i1 @type_is_valid__Struct_TypeInfo(ptr %96)
  %98 = icmp eq i1 %97, false
  store i1 %98, ptr %sc.75, align 1
  br label %label_898

label_898:                                        ; preds = %label_897, %label_896
  %99 = load i1, ptr %sc.75, align 1
  br i1 %99, label %label_899, label %label_901

label_901:                                        ; preds = %label_898
  %100 = load ptr, ptr %ac.577, align 8
  %101 = load ptr, ptr %bc.578, align 8
  %102 = call i1 @type_equals__Struct_TypeInfo_Struct_TypeInfo(ptr %100, ptr %101)
  ret i1 %102

label_899:                                        ; preds = %label_898
  ret i1 true
}

define i1 @type_is_numeric__Struct_TypeInfo(ptr %0) {
entry:
  %t.579 = alloca ptr, align 8
  store ptr %0, ptr %t.579, align 8
  %sc.76 = alloca i1, align 1
  %1 = load ptr, ptr %t.579, align 8
  %2 = getelementptr inbounds nuw %TypeInfo, ptr %1, i32 0, i32 0
  %3 = load i32, ptr %2, align 4
  %4 = icmp eq i32 %3, 2
  store i1 %4, ptr %sc.76, align 1
  br i1 %4, label %label_903, label %label_902

label_902:                                        ; preds = %entry
  %5 = load ptr, ptr %t.579, align 8
  %6 = getelementptr inbounds nuw %TypeInfo, ptr %5, i32 0, i32 0
  %7 = load i32, ptr %6, align 4
  %8 = icmp eq i32 %7, 3
  store i1 %8, ptr %sc.76, align 1
  br label %label_903

label_903:                                        ; preds = %label_902, %entry
  %9 = load i1, ptr %sc.76, align 1
  ret i1 %9
}

define ptr @type_ir_key__Struct_TypeInfo(ptr %0) {
entry:
  %t.580 = alloca ptr, align 8
  store ptr %0, ptr %t.580, align 8
  %1 = load ptr, ptr %t.580, align 8
  %2 = getelementptr inbounds nuw %TypeInfo, ptr %1, i32 0, i32 0
  %3 = load i32, ptr %2, align 4
  %4 = icmp eq i32 %3, 1
  %elem.581 = alloca ptr, align 8
  br i1 %4, label %label_904, label %label_906

label_906:                                        ; preds = %entry
  %5 = load ptr, ptr %t.580, align 8
  %6 = getelementptr inbounds nuw %TypeInfo, ptr %5, i32 0, i32 0
  %7 = load i32, ptr %6, align 4
  %8 = icmp eq i32 %7, 2
  br i1 %8, label %label_907, label %label_909

label_904:                                        ; preds = %entry
  ret ptr @.str.s364

label_909:                                        ; preds = %label_906
  %9 = load ptr, ptr %t.580, align 8
  %10 = getelementptr inbounds nuw %TypeInfo, ptr %9, i32 0, i32 0
  %11 = load i32, ptr %10, align 4
  %12 = icmp eq i32 %11, 3
  br i1 %12, label %label_910, label %label_912

label_907:                                        ; preds = %label_906
  %13 = load ptr, ptr %t.580, align 8
  %14 = getelementptr inbounds nuw %TypeInfo, ptr %13, i32 0, i32 2
  %15 = load ptr, ptr %14, align 8
  ret ptr %15

label_912:                                        ; preds = %label_909
  %16 = load ptr, ptr %t.580, align 8
  %17 = getelementptr inbounds nuw %TypeInfo, ptr %16, i32 0, i32 0
  %18 = load i32, ptr %17, align 4
  %19 = icmp eq i32 %18, 4
  br i1 %19, label %label_913, label %label_915

label_910:                                        ; preds = %label_909
  ret ptr @.str.s365

label_915:                                        ; preds = %label_912
  %20 = load ptr, ptr %t.580, align 8
  %21 = getelementptr inbounds nuw %TypeInfo, ptr %20, i32 0, i32 0
  %22 = load i32, ptr %21, align 4
  %23 = icmp eq i32 %22, 5
  br i1 %23, label %label_916, label %label_918

label_913:                                        ; preds = %label_912
  ret ptr @.str.s366

label_918:                                        ; preds = %label_915
  %24 = load ptr, ptr %t.580, align 8
  %25 = getelementptr inbounds nuw %TypeInfo, ptr %24, i32 0, i32 0
  %26 = load i32, ptr %25, align 4
  %27 = icmp eq i32 %26, 6
  br i1 %27, label %label_919, label %label_921

label_916:                                        ; preds = %label_915
  ret ptr @.str.s367

label_921:                                        ; preds = %label_918
  %28 = load ptr, ptr %t.580, align 8
  %29 = getelementptr inbounds nuw %TypeInfo, ptr %28, i32 0, i32 0
  %30 = load i32, ptr %29, align 4
  %31 = icmp eq i32 %30, 7
  br i1 %31, label %label_922, label %label_924

label_919:                                        ; preds = %label_918
  ret ptr @.str.s368

label_924:                                        ; preds = %label_921
  %32 = load ptr, ptr %t.580, align 8
  %33 = getelementptr inbounds nuw %TypeInfo, ptr %32, i32 0, i32 0
  %34 = load i32, ptr %33, align 4
  %35 = icmp eq i32 %34, 9
  br i1 %35, label %label_925, label %label_927

label_922:                                        ; preds = %label_921
  ret ptr @.str.s369

label_927:                                        ; preds = %label_924
  %36 = load ptr, ptr %t.580, align 8
  %37 = getelementptr inbounds nuw %TypeInfo, ptr %36, i32 0, i32 0
  %38 = load i32, ptr %37, align 4
  %39 = icmp eq i32 %38, 8
  br i1 %39, label %label_928, label %label_930

label_925:                                        ; preds = %label_924
  ret ptr @.str.s370

label_930:                                        ; preds = %label_927
  %40 = load ptr, ptr %t.580, align 8
  %41 = getelementptr inbounds nuw %TypeInfo, ptr %40, i32 0, i32 0
  %42 = load i32, ptr %41, align 4
  %43 = icmp eq i32 %42, 11
  br i1 %43, label %label_931, label %label_933

label_928:                                        ; preds = %label_927
  %44 = load ptr, ptr %t.580, align 8
  %45 = getelementptr inbounds nuw %TypeInfo, ptr %44, i32 0, i32 1
  %46 = load ptr, ptr %45, align 8
  %47 = call ptr @str_concat(ptr @.str.s371, ptr %46)
  ret ptr %47

label_933:                                        ; preds = %label_930
  %48 = load ptr, ptr %t.580, align 8
  %49 = getelementptr inbounds nuw %TypeInfo, ptr %48, i32 0, i32 0
  %50 = load i32, ptr %49, align 4
  %51 = icmp eq i32 %50, 10
  br i1 %51, label %label_934, label %label_936

label_931:                                        ; preds = %label_930
  ret ptr @.str.s372

label_936:                                        ; preds = %label_933
  ret ptr @.str.s376

label_934:                                        ; preds = %label_933
  %52 = load ptr, ptr %t.580, align 8
  %53 = getelementptr inbounds nuw %TypeInfo, ptr %52, i32 0, i32 3
  %54 = load ptr, ptr %53, align 8
  %55 = call i32 @str_equals(ptr %54, ptr @.str.s373)
  %56 = icmp eq i32 %55, 0
  br i1 %56, label %label_937, label %label_939

label_939:                                        ; preds = %label_942, %label_934
  ret ptr @.str.s375

label_937:                                        ; preds = %label_934
  %57 = load ptr, ptr %t.580, align 8
  %58 = getelementptr inbounds nuw %TypeInfo, ptr %57, i32 0, i32 3
  %59 = load ptr, ptr %58, align 8
  %60 = call ptr @ptr_to_type(ptr %59)
  store ptr %60, ptr %elem.581, align 8
  %61 = load ptr, ptr %elem.581, align 8
  %62 = getelementptr inbounds nuw %TypeInfo, ptr %61, i32 0, i32 0
  %63 = load i32, ptr %62, align 4
  %64 = icmp eq i32 %63, 10
  br i1 %64, label %label_940, label %label_942

label_942:                                        ; preds = %label_937
  br label %label_939

label_940:                                        ; preds = %label_937
  ret ptr @.str.s374
}

define ptr @type_sem_key__Struct_TypeInfo(ptr %0) {
entry:
  %t.582 = alloca ptr, align 8
  store ptr %0, ptr %t.582, align 8
  %1 = load ptr, ptr %t.582, align 8
  %2 = getelementptr inbounds nuw %TypeInfo, ptr %1, i32 0, i32 0
  %3 = load i32, ptr %2, align 4
  %4 = icmp eq i32 %3, 1
  br i1 %4, label %label_943, label %label_945

label_945:                                        ; preds = %entry
  %5 = load ptr, ptr %t.582, align 8
  %6 = getelementptr inbounds nuw %TypeInfo, ptr %5, i32 0, i32 0
  %7 = load i32, ptr %6, align 4
  %8 = icmp eq i32 %7, 2
  br i1 %8, label %label_946, label %label_948

label_943:                                        ; preds = %entry
  ret ptr @.str.s377

label_948:                                        ; preds = %label_945
  %9 = load ptr, ptr %t.582, align 8
  %10 = getelementptr inbounds nuw %TypeInfo, ptr %9, i32 0, i32 0
  %11 = load i32, ptr %10, align 4
  %12 = icmp eq i32 %11, 3
  br i1 %12, label %label_949, label %label_951

label_946:                                        ; preds = %label_945
  %13 = load ptr, ptr %t.582, align 8
  %14 = getelementptr inbounds nuw %TypeInfo, ptr %13, i32 0, i32 1
  %15 = load ptr, ptr %14, align 8
  ret ptr %15

label_951:                                        ; preds = %label_948
  %16 = load ptr, ptr %t.582, align 8
  %17 = getelementptr inbounds nuw %TypeInfo, ptr %16, i32 0, i32 0
  %18 = load i32, ptr %17, align 4
  %19 = icmp eq i32 %18, 4
  br i1 %19, label %label_952, label %label_954

label_949:                                        ; preds = %label_948
  ret ptr @.str.s378

label_954:                                        ; preds = %label_951
  %20 = load ptr, ptr %t.582, align 8
  %21 = getelementptr inbounds nuw %TypeInfo, ptr %20, i32 0, i32 0
  %22 = load i32, ptr %21, align 4
  %23 = icmp eq i32 %22, 5
  br i1 %23, label %label_955, label %label_957

label_952:                                        ; preds = %label_951
  ret ptr @.str.s379

label_957:                                        ; preds = %label_954
  %24 = load ptr, ptr %t.582, align 8
  %25 = getelementptr inbounds nuw %TypeInfo, ptr %24, i32 0, i32 0
  %26 = load i32, ptr %25, align 4
  %27 = icmp eq i32 %26, 6
  br i1 %27, label %label_958, label %label_960

label_955:                                        ; preds = %label_954
  ret ptr @.str.s380

label_960:                                        ; preds = %label_957
  %28 = load ptr, ptr %t.582, align 8
  %29 = getelementptr inbounds nuw %TypeInfo, ptr %28, i32 0, i32 0
  %30 = load i32, ptr %29, align 4
  %31 = icmp eq i32 %30, 7
  br i1 %31, label %label_961, label %label_963

label_958:                                        ; preds = %label_957
  ret ptr @.str.s381

label_963:                                        ; preds = %label_960
  %32 = load ptr, ptr %t.582, align 8
  %33 = getelementptr inbounds nuw %TypeInfo, ptr %32, i32 0, i32 0
  %34 = load i32, ptr %33, align 4
  %35 = icmp eq i32 %34, 8
  br i1 %35, label %label_964, label %label_966

label_961:                                        ; preds = %label_960
  ret ptr @.str.s382

label_966:                                        ; preds = %label_963
  %36 = load ptr, ptr %t.582, align 8
  %37 = getelementptr inbounds nuw %TypeInfo, ptr %36, i32 0, i32 0
  %38 = load i32, ptr %37, align 4
  %39 = icmp eq i32 %38, 9
  br i1 %39, label %label_967, label %label_969

label_964:                                        ; preds = %label_963
  %40 = load ptr, ptr %t.582, align 8
  %41 = getelementptr inbounds nuw %TypeInfo, ptr %40, i32 0, i32 1
  %42 = load ptr, ptr %41, align 8
  %43 = call ptr @str_concat(ptr @.str.s383, ptr %42)
  ret ptr %43

label_969:                                        ; preds = %label_966
  %44 = load ptr, ptr %t.582, align 8
  %45 = getelementptr inbounds nuw %TypeInfo, ptr %44, i32 0, i32 0
  %46 = load i32, ptr %45, align 4
  %47 = icmp eq i32 %46, 10
  br i1 %47, label %label_970, label %label_972

label_967:                                        ; preds = %label_966
  %48 = load ptr, ptr %t.582, align 8
  %49 = getelementptr inbounds nuw %TypeInfo, ptr %48, i32 0, i32 1
  %50 = load ptr, ptr %49, align 8
  %51 = call ptr @str_concat(ptr @.str.s384, ptr %50)
  ret ptr %51

label_972:                                        ; preds = %label_969
  %52 = load ptr, ptr %t.582, align 8
  %53 = getelementptr inbounds nuw %TypeInfo, ptr %52, i32 0, i32 0
  %54 = load i32, ptr %53, align 4
  %55 = icmp eq i32 %54, 11
  br i1 %55, label %label_976, label %label_978

label_970:                                        ; preds = %label_969
  %56 = load ptr, ptr %t.582, align 8
  %57 = getelementptr inbounds nuw %TypeInfo, ptr %56, i32 0, i32 3
  %58 = load ptr, ptr %57, align 8
  %59 = call i32 @str_equals(ptr %58, ptr @.str.s385)
  %60 = icmp eq i32 %59, 0
  br i1 %60, label %label_973, label %label_975

label_975:                                        ; preds = %label_970
  ret ptr @.str.s387

label_973:                                        ; preds = %label_970
  %61 = load ptr, ptr %t.582, align 8
  %62 = getelementptr inbounds nuw %TypeInfo, ptr %61, i32 0, i32 3
  %63 = load ptr, ptr %62, align 8
  %64 = call ptr @ptr_to_type(ptr %63)
  %65 = call ptr @type_sem_key__Struct_TypeInfo(ptr %64)
  %66 = call ptr @str_concat(ptr @.str.s386, ptr %65)
  ret ptr %66

label_978:                                        ; preds = %label_972
  ret ptr @.str.s391

label_976:                                        ; preds = %label_972
  %67 = load ptr, ptr %t.582, align 8
  %68 = getelementptr inbounds nuw %TypeInfo, ptr %67, i32 0, i32 3
  %69 = load ptr, ptr %68, align 8
  %70 = call i32 @str_equals(ptr %69, ptr @.str.s388)
  %71 = icmp eq i32 %70, 0
  br i1 %71, label %label_979, label %label_981

label_981:                                        ; preds = %label_976
  ret ptr @.str.s390

label_979:                                        ; preds = %label_976
  %72 = load ptr, ptr %t.582, align 8
  %73 = getelementptr inbounds nuw %TypeInfo, ptr %72, i32 0, i32 3
  %74 = load ptr, ptr %73, align 8
  %75 = call ptr @ptr_to_type(ptr %74)
  %76 = call ptr @type_sem_key__Struct_TypeInfo(ptr %75)
  %77 = call ptr @str_concat(ptr @.str.s389, ptr %76)
  ret ptr %77
}

define ptr @type_storage_key__Struct_TypeInfo(ptr %0) {
entry:
  %t.583 = alloca ptr, align 8
  store ptr %0, ptr %t.583, align 8
  %1 = load ptr, ptr %t.583, align 8
  %2 = call ptr @type_ir_key__Struct_TypeInfo(ptr %1)
  %key.584 = alloca ptr, align 8
  store ptr %2, ptr %key.584, align 8
  %3 = load ptr, ptr %key.584, align 8
  %4 = call i32 @str_equals(ptr %3, ptr @.str.s392)
  %5 = icmp eq i32 %4, 1
  br i1 %5, label %label_982, label %label_984

label_984:                                        ; preds = %entry
  %6 = load ptr, ptr %key.584, align 8
  %7 = call i32 @str_starts_with(ptr %6, ptr @.str.s394)
  %8 = icmp eq i32 %7, 1
  br i1 %8, label %label_985, label %label_987

label_982:                                        ; preds = %entry
  ret ptr @.str.s393

label_987:                                        ; preds = %label_984
  %9 = load ptr, ptr %key.584, align 8
  ret ptr %9

label_985:                                        ; preds = %label_984
  ret ptr @.str.s395
}

define ptr @type_from_annotation__Struct_ASTNode(ptr %0) {
entry:
  %tn.585 = alloca ptr, align 8
  store ptr %0, ptr %tn.585, align 8
  %1 = load ptr, ptr %tn.585, align 8
  %2 = getelementptr inbounds nuw %ASTNode, ptr %1, i32 0, i32 3
  %3 = load i32, ptr %2, align 4
  %4 = icmp eq i32 %3, 1
  br i1 %4, label %label_988, label %label_990

label_990:                                        ; preds = %entry
  %5 = load ptr, ptr %tn.585, align 8
  %6 = getelementptr inbounds nuw %ASTNode, ptr %5, i32 0, i32 1
  %7 = load ptr, ptr %6, align 8
  %8 = call i32 @str_equals(ptr %7, ptr @.str.s397)
  %9 = icmp eq i32 %8, 1
  br i1 %9, label %label_994, label %label_996

label_988:                                        ; preds = %entry
  %10 = load ptr, ptr %tn.585, align 8
  %11 = getelementptr inbounds nuw %ASTNode, ptr %10, i32 0, i32 5
  %12 = load ptr, ptr %11, align 8
  %13 = call i32 @str_equals(ptr %12, ptr @.str.s396)
  %14 = icmp eq i32 %13, 0
  br i1 %14, label %label_991, label %label_993

label_993:                                        ; preds = %label_988
  %15 = call ptr @type_invalid__Void()
  %16 = call ptr @type_array__Struct_TypeInfo(ptr %15)
  ret ptr %16

label_991:                                        ; preds = %label_988
  %17 = load ptr, ptr %tn.585, align 8
  %18 = getelementptr inbounds nuw %ASTNode, ptr %17, i32 0, i32 5
  %19 = load ptr, ptr %18, align 8
  %20 = call ptr @ptr_to_node(ptr %19)
  %21 = call ptr @type_from_annotation__Struct_ASTNode(ptr %20)
  %22 = call ptr @type_array__Struct_TypeInfo(ptr %21)
  ret ptr %22

label_996:                                        ; preds = %label_990
  %23 = load ptr, ptr %tn.585, align 8
  %24 = getelementptr inbounds nuw %ASTNode, ptr %23, i32 0, i32 1
  %25 = load ptr, ptr %24, align 8
  %26 = call i32 @str_equals(ptr %25, ptr @.str.s398)
  %27 = icmp eq i32 %26, 1
  br i1 %27, label %label_997, label %label_999

label_994:                                        ; preds = %label_990
  %28 = call ptr @type_int__Void()
  ret ptr %28

label_999:                                        ; preds = %label_996
  %29 = load ptr, ptr %tn.585, align 8
  %30 = getelementptr inbounds nuw %ASTNode, ptr %29, i32 0, i32 1
  %31 = load ptr, ptr %30, align 8
  %32 = call i32 @str_equals(ptr %31, ptr @.str.s399)
  %33 = icmp eq i32 %32, 1
  br i1 %33, label %label_1000, label %label_1002

label_997:                                        ; preds = %label_996
  %34 = call ptr @type_float__Void()
  ret ptr %34

label_1002:                                       ; preds = %label_999
  %35 = load ptr, ptr %tn.585, align 8
  %36 = getelementptr inbounds nuw %ASTNode, ptr %35, i32 0, i32 1
  %37 = load ptr, ptr %36, align 8
  %38 = call i32 @str_equals(ptr %37, ptr @.str.s400)
  %39 = icmp eq i32 %38, 1
  br i1 %39, label %label_1003, label %label_1005

label_1000:                                       ; preds = %label_999
  %40 = call ptr @type_bool__Void()
  ret ptr %40

label_1005:                                       ; preds = %label_1002
  %41 = load ptr, ptr %tn.585, align 8
  %42 = getelementptr inbounds nuw %ASTNode, ptr %41, i32 0, i32 1
  %43 = load ptr, ptr %42, align 8
  %44 = call i32 @str_equals(ptr %43, ptr @.str.s401)
  %45 = icmp eq i32 %44, 1
  br i1 %45, label %label_1006, label %label_1008

label_1003:                                       ; preds = %label_1002
  %46 = call ptr @type_string__Void()
  ret ptr %46

label_1008:                                       ; preds = %label_1005
  %47 = load ptr, ptr %tn.585, align 8
  %48 = getelementptr inbounds nuw %ASTNode, ptr %47, i32 0, i32 1
  %49 = load ptr, ptr %48, align 8
  %50 = call i32 @str_equals(ptr %49, ptr @.str.s402)
  %51 = icmp eq i32 %50, 1
  br i1 %51, label %label_1009, label %label_1011

label_1006:                                       ; preds = %label_1005
  %52 = call ptr @type_char__Void()
  ret ptr %52

label_1011:                                       ; preds = %label_1008
  %53 = load ptr, ptr %tn.585, align 8
  %54 = getelementptr inbounds nuw %ASTNode, ptr %53, i32 0, i32 1
  %55 = load ptr, ptr %54, align 8
  %56 = call i32 @str_equals(ptr %55, ptr @.str.s403)
  %57 = icmp eq i32 %56, 1
  br i1 %57, label %label_1012, label %label_1014

label_1009:                                       ; preds = %label_1008
  %58 = call ptr @type_i8__Void()
  ret ptr %58

label_1014:                                       ; preds = %label_1011
  %59 = load ptr, ptr %tn.585, align 8
  %60 = getelementptr inbounds nuw %ASTNode, ptr %59, i32 0, i32 1
  %61 = load ptr, ptr %60, align 8
  %62 = call i32 @str_equals(ptr %61, ptr @.str.s404)
  %63 = icmp eq i32 %62, 1
  br i1 %63, label %label_1015, label %label_1017

label_1012:                                       ; preds = %label_1011
  %64 = call ptr @type_i16__Void()
  ret ptr %64

label_1017:                                       ; preds = %label_1014
  %65 = load ptr, ptr %tn.585, align 8
  %66 = getelementptr inbounds nuw %ASTNode, ptr %65, i32 0, i32 1
  %67 = load ptr, ptr %66, align 8
  %68 = call i32 @str_equals(ptr %67, ptr @.str.s405)
  %69 = icmp eq i32 %68, 1
  br i1 %69, label %label_1018, label %label_1020

label_1015:                                       ; preds = %label_1014
  %70 = call ptr @type_i64__Void()
  ret ptr %70

label_1020:                                       ; preds = %label_1017
  %71 = load ptr, ptr %tn.585, align 8
  %72 = getelementptr inbounds nuw %ASTNode, ptr %71, i32 0, i32 1
  %73 = load ptr, ptr %72, align 8
  %74 = call i32 @str_equals(ptr %73, ptr @.str.s406)
  %75 = icmp eq i32 %74, 1
  br i1 %75, label %label_1021, label %label_1023

label_1018:                                       ; preds = %label_1017
  %76 = call ptr @type_isize__Void()
  ret ptr %76

label_1023:                                       ; preds = %label_1020
  %77 = load ptr, ptr %tn.585, align 8
  %78 = getelementptr inbounds nuw %ASTNode, ptr %77, i32 0, i32 1
  %79 = load ptr, ptr %78, align 8
  %80 = call i32 @str_equals(ptr %79, ptr @.str.s407)
  %81 = icmp eq i32 %80, 1
  br i1 %81, label %label_1024, label %label_1026

label_1021:                                       ; preds = %label_1020
  %82 = call ptr @type_u8__Void()
  ret ptr %82

label_1026:                                       ; preds = %label_1023
  %83 = load ptr, ptr %tn.585, align 8
  %84 = getelementptr inbounds nuw %ASTNode, ptr %83, i32 0, i32 1
  %85 = load ptr, ptr %84, align 8
  %86 = call i32 @str_equals(ptr %85, ptr @.str.s408)
  %87 = icmp eq i32 %86, 1
  br i1 %87, label %label_1027, label %label_1029

label_1024:                                       ; preds = %label_1023
  %88 = call ptr @type_u16__Void()
  ret ptr %88

label_1029:                                       ; preds = %label_1026
  %89 = load ptr, ptr %tn.585, align 8
  %90 = getelementptr inbounds nuw %ASTNode, ptr %89, i32 0, i32 1
  %91 = load ptr, ptr %90, align 8
  %92 = call i32 @str_equals(ptr %91, ptr @.str.s409)
  %93 = icmp eq i32 %92, 1
  br i1 %93, label %label_1030, label %label_1032

label_1027:                                       ; preds = %label_1026
  %94 = call ptr @type_u32__Void()
  ret ptr %94

label_1032:                                       ; preds = %label_1029
  %95 = load ptr, ptr %tn.585, align 8
  %96 = getelementptr inbounds nuw %ASTNode, ptr %95, i32 0, i32 1
  %97 = load ptr, ptr %96, align 8
  %98 = call i32 @str_equals(ptr %97, ptr @.str.s410)
  %99 = icmp eq i32 %98, 1
  br i1 %99, label %label_1033, label %label_1035

label_1030:                                       ; preds = %label_1029
  %100 = call ptr @type_u64__Void()
  ret ptr %100

label_1035:                                       ; preds = %label_1032
  %101 = load ptr, ptr %tn.585, align 8
  %102 = getelementptr inbounds nuw %ASTNode, ptr %101, i32 0, i32 1
  %103 = load ptr, ptr %102, align 8
  %104 = call i32 @str_equals(ptr %103, ptr @.str.s411)
  %105 = icmp eq i32 %104, 1
  br i1 %105, label %label_1036, label %label_1038

label_1033:                                       ; preds = %label_1032
  %106 = call ptr @type_usize__Void()
  ret ptr %106

label_1038:                                       ; preds = %label_1035
  %107 = load ptr, ptr %tn.585, align 8
  %108 = getelementptr inbounds nuw %ASTNode, ptr %107, i32 0, i32 1
  %109 = load ptr, ptr %108, align 8
  %110 = call ptr @type_struct__String(ptr %109)
  ret ptr %110

label_1036:                                       ; preds = %label_1035
  %111 = call ptr @type_void__Void()
  ret ptr %111
}

define ptr @type_from_ir_key__String(ptr %0) {
entry:
  %key.586 = alloca ptr, align 8
  store ptr %0, ptr %key.586, align 8
  %1 = load ptr, ptr %key.586, align 8
  %2 = call i32 @str_equals(ptr %1, ptr @.str.s412)
  %3 = icmp eq i32 %2, 1
  br i1 %3, label %label_1039, label %label_1041

label_1041:                                       ; preds = %entry
  %4 = load ptr, ptr %key.586, align 8
  %5 = call i32 @str_equals(ptr %4, ptr @.str.s413)
  %6 = icmp eq i32 %5, 1
  br i1 %6, label %label_1042, label %label_1044

label_1039:                                       ; preds = %entry
  %7 = call ptr @type_int__Void()
  ret ptr %7

label_1044:                                       ; preds = %label_1041
  %8 = load ptr, ptr %key.586, align 8
  %9 = call i32 @str_equals(ptr %8, ptr @.str.s414)
  %10 = icmp eq i32 %9, 1
  br i1 %10, label %label_1045, label %label_1047

label_1042:                                       ; preds = %label_1041
  %11 = call ptr @type_float__Void()
  ret ptr %11

label_1047:                                       ; preds = %label_1044
  %12 = load ptr, ptr %key.586, align 8
  %13 = call i32 @str_equals(ptr %12, ptr @.str.s415)
  %14 = icmp eq i32 %13, 1
  br i1 %14, label %label_1048, label %label_1050

label_1045:                                       ; preds = %label_1044
  %15 = call ptr @type_bool__Void()
  ret ptr %15

label_1050:                                       ; preds = %label_1047
  %16 = load ptr, ptr %key.586, align 8
  %17 = call i32 @str_equals(ptr %16, ptr @.str.s416)
  %18 = icmp eq i32 %17, 1
  br i1 %18, label %label_1051, label %label_1053

label_1048:                                       ; preds = %label_1047
  %19 = call ptr @type_char__Void()
  ret ptr %19

label_1053:                                       ; preds = %label_1050
  %20 = load ptr, ptr %key.586, align 8
  %21 = call i32 @str_equals(ptr %20, ptr @.str.s417)
  %22 = icmp eq i32 %21, 1
  br i1 %22, label %label_1054, label %label_1056

label_1051:                                       ; preds = %label_1050
  %23 = call ptr @type_ptr__Void()
  ret ptr %23

label_1056:                                       ; preds = %label_1053
  %24 = load ptr, ptr %key.586, align 8
  %25 = call i32 @str_starts_with(ptr %24, ptr @.str.s418)
  %26 = icmp eq i32 %25, 1
  br i1 %26, label %label_1057, label %label_1059

label_1054:                                       ; preds = %label_1053
  %27 = call ptr @type_void__Void()
  ret ptr %27

label_1059:                                       ; preds = %label_1056
  %28 = call ptr @type_invalid__Void()
  ret ptr %28

label_1057:                                       ; preds = %label_1056
  %29 = load ptr, ptr %key.586, align 8
  %30 = load ptr, ptr %key.586, align 8
  %31 = call i32 @str_length(ptr %30)
  %32 = sub i32 %31, 7
  %33 = call ptr @str_substring(ptr %29, i32 7, i32 %32)
  %34 = call ptr @type_struct__String(ptr %33)
  ret ptr %34
}

define ptr @type_from_sem_key__String(ptr %0) {
entry:
  %key.587 = alloca ptr, align 8
  store ptr %0, ptr %key.587, align 8
  %1 = load ptr, ptr %key.587, align 8
  %2 = call i32 @str_equals(ptr %1, ptr @.str.s419)
  %3 = icmp eq i32 %2, 1
  br i1 %3, label %label_1060, label %label_1062

label_1062:                                       ; preds = %entry
  %4 = load ptr, ptr %key.587, align 8
  %5 = call i32 @str_equals(ptr %4, ptr @.str.s420)
  %6 = icmp eq i32 %5, 1
  br i1 %6, label %label_1063, label %label_1065

label_1060:                                       ; preds = %entry
  %7 = call ptr @type_int__Void()
  ret ptr %7

label_1065:                                       ; preds = %label_1062
  %8 = load ptr, ptr %key.587, align 8
  %9 = call i32 @str_equals(ptr %8, ptr @.str.s421)
  %10 = icmp eq i32 %9, 1
  br i1 %10, label %label_1066, label %label_1068

label_1063:                                       ; preds = %label_1062
  %11 = call ptr @type_float__Void()
  ret ptr %11

label_1068:                                       ; preds = %label_1065
  %12 = load ptr, ptr %key.587, align 8
  %13 = call i32 @str_equals(ptr %12, ptr @.str.s422)
  %14 = icmp eq i32 %13, 1
  br i1 %14, label %label_1069, label %label_1071

label_1066:                                       ; preds = %label_1065
  %15 = call ptr @type_bool__Void()
  ret ptr %15

label_1071:                                       ; preds = %label_1068
  %16 = load ptr, ptr %key.587, align 8
  %17 = call i32 @str_equals(ptr %16, ptr @.str.s423)
  %18 = icmp eq i32 %17, 1
  br i1 %18, label %label_1072, label %label_1074

label_1069:                                       ; preds = %label_1068
  %19 = call ptr @type_char__Void()
  ret ptr %19

label_1074:                                       ; preds = %label_1071
  %20 = load ptr, ptr %key.587, align 8
  %21 = call i32 @str_equals(ptr %20, ptr @.str.s424)
  %22 = icmp eq i32 %21, 1
  br i1 %22, label %label_1075, label %label_1077

label_1072:                                       ; preds = %label_1071
  %23 = call ptr @type_string__Void()
  ret ptr %23

label_1077:                                       ; preds = %label_1074
  %24 = load ptr, ptr %key.587, align 8
  %25 = call i32 @str_equals(ptr %24, ptr @.str.s425)
  %26 = icmp eq i32 %25, 1
  br i1 %26, label %label_1078, label %label_1080

label_1075:                                       ; preds = %label_1074
  %27 = call ptr @type_ptr__Void()
  ret ptr %27

label_1080:                                       ; preds = %label_1077
  %28 = load ptr, ptr %key.587, align 8
  %29 = call i32 @str_equals(ptr %28, ptr @.str.s426)
  %30 = icmp eq i32 %29, 1
  br i1 %30, label %label_1081, label %label_1083

label_1078:                                       ; preds = %label_1077
  %31 = call ptr @type_void__Void()
  ret ptr %31

label_1083:                                       ; preds = %label_1080
  %32 = load ptr, ptr %key.587, align 8
  %33 = call i32 @str_equals(ptr %32, ptr @.str.s427)
  %34 = icmp eq i32 %33, 1
  br i1 %34, label %label_1084, label %label_1086

label_1081:                                       ; preds = %label_1080
  %35 = call ptr @type_i8__Void()
  ret ptr %35

label_1086:                                       ; preds = %label_1083
  %36 = load ptr, ptr %key.587, align 8
  %37 = call i32 @str_equals(ptr %36, ptr @.str.s428)
  %38 = icmp eq i32 %37, 1
  br i1 %38, label %label_1087, label %label_1089

label_1084:                                       ; preds = %label_1083
  %39 = call ptr @type_i16__Void()
  ret ptr %39

label_1089:                                       ; preds = %label_1086
  %40 = load ptr, ptr %key.587, align 8
  %41 = call i32 @str_equals(ptr %40, ptr @.str.s429)
  %42 = icmp eq i32 %41, 1
  br i1 %42, label %label_1090, label %label_1092

label_1087:                                       ; preds = %label_1086
  %43 = call ptr @type_i64__Void()
  ret ptr %43

label_1092:                                       ; preds = %label_1089
  %44 = load ptr, ptr %key.587, align 8
  %45 = call i32 @str_equals(ptr %44, ptr @.str.s430)
  %46 = icmp eq i32 %45, 1
  br i1 %46, label %label_1093, label %label_1095

label_1090:                                       ; preds = %label_1089
  %47 = call ptr @type_isize__Void()
  ret ptr %47

label_1095:                                       ; preds = %label_1092
  %48 = load ptr, ptr %key.587, align 8
  %49 = call i32 @str_equals(ptr %48, ptr @.str.s431)
  %50 = icmp eq i32 %49, 1
  br i1 %50, label %label_1096, label %label_1098

label_1093:                                       ; preds = %label_1092
  %51 = call ptr @type_u8__Void()
  ret ptr %51

label_1098:                                       ; preds = %label_1095
  %52 = load ptr, ptr %key.587, align 8
  %53 = call i32 @str_equals(ptr %52, ptr @.str.s432)
  %54 = icmp eq i32 %53, 1
  br i1 %54, label %label_1099, label %label_1101

label_1096:                                       ; preds = %label_1095
  %55 = call ptr @type_u16__Void()
  ret ptr %55

label_1101:                                       ; preds = %label_1098
  %56 = load ptr, ptr %key.587, align 8
  %57 = call i32 @str_equals(ptr %56, ptr @.str.s433)
  %58 = icmp eq i32 %57, 1
  br i1 %58, label %label_1102, label %label_1104

label_1099:                                       ; preds = %label_1098
  %59 = call ptr @type_u32__Void()
  ret ptr %59

label_1104:                                       ; preds = %label_1101
  %60 = load ptr, ptr %key.587, align 8
  %61 = call i32 @str_equals(ptr %60, ptr @.str.s434)
  %62 = icmp eq i32 %61, 1
  br i1 %62, label %label_1105, label %label_1107

label_1102:                                       ; preds = %label_1101
  %63 = call ptr @type_u64__Void()
  ret ptr %63

label_1107:                                       ; preds = %label_1104
  %64 = load ptr, ptr %key.587, align 8
  %65 = call i32 @str_starts_with(ptr %64, ptr @.str.s435)
  %66 = icmp eq i32 %65, 1
  br i1 %66, label %label_1108, label %label_1110

label_1105:                                       ; preds = %label_1104
  %67 = call ptr @type_usize__Void()
  ret ptr %67

label_1110:                                       ; preds = %label_1107
  %68 = load ptr, ptr %key.587, align 8
  %69 = call i32 @str_starts_with(ptr %68, ptr @.str.s436)
  %70 = icmp eq i32 %69, 1
  br i1 %70, label %label_1111, label %label_1113

label_1108:                                       ; preds = %label_1107
  %71 = load ptr, ptr %key.587, align 8
  %72 = load ptr, ptr %key.587, align 8
  %73 = call i32 @str_length(ptr %72)
  %74 = sub i32 %73, 7
  %75 = call ptr @str_substring(ptr %71, i32 7, i32 %74)
  %76 = call ptr @type_struct__String(ptr %75)
  ret ptr %76

label_1113:                                       ; preds = %label_1110
  %77 = load ptr, ptr %key.587, align 8
  %78 = call i32 @str_starts_with(ptr %77, ptr @.str.s437)
  %79 = icmp eq i32 %78, 1
  br i1 %79, label %label_1114, label %label_1116

label_1111:                                       ; preds = %label_1110
  %80 = load ptr, ptr %key.587, align 8
  %81 = load ptr, ptr %key.587, align 8
  %82 = call i32 @str_length(ptr %81)
  %83 = sub i32 %82, 5
  %84 = call ptr @str_substring(ptr %80, i32 5, i32 %83)
  %85 = call ptr @type_enum__String(ptr %84)
  ret ptr %85

label_1116:                                       ; preds = %label_1113
  %86 = load ptr, ptr %key.587, align 8
  %87 = call i32 @str_starts_with(ptr %86, ptr @.str.s438)
  %88 = icmp eq i32 %87, 1
  br i1 %88, label %label_1117, label %label_1119

label_1114:                                       ; preds = %label_1113
  %89 = load ptr, ptr %key.587, align 8
  %90 = load ptr, ptr %key.587, align 8
  %91 = call i32 @str_length(ptr %90)
  %92 = sub i32 %91, 6
  %93 = call ptr @str_substring(ptr %89, i32 6, i32 %92)
  %94 = call ptr @type_from_sem_key__String(ptr %93)
  %95 = call ptr @type_array__Struct_TypeInfo(ptr %94)
  ret ptr %95

label_1119:                                       ; preds = %label_1116
  %96 = call ptr @type_invalid__Void()
  ret ptr %96

label_1117:                                       ; preds = %label_1116
  %97 = load ptr, ptr %key.587, align 8
  %98 = load ptr, ptr %key.587, align 8
  %99 = call i32 @str_length(ptr %98)
  %100 = sub i32 %99, 5
  %101 = call ptr @str_substring(ptr %97, i32 5, i32 %100)
  %102 = call ptr @type_from_sem_key__String(ptr %101)
  %103 = call ptr @type_list__Struct_TypeInfo(ptr %102)
  ret ptr %103
}

define void @node_set_type__Struct_ASTNode_Struct_TypeInfo(ptr %0, ptr %1) {
entry:
  %node.588 = alloca ptr, align 8
  store ptr %0, ptr %node.588, align 8
  %t.589 = alloca ptr, align 8
  store ptr %1, ptr %t.589, align 8
  %2 = load ptr, ptr %node.588, align 8
  %3 = load ptr, ptr %t.589, align 8
  %4 = call ptr @type_to_ptr(ptr %3)
  %5 = getelementptr inbounds nuw %ASTNode, ptr %2, i32 0, i32 9
  store ptr %4, ptr %5, align 8
  ret void
}

define i1 @node_has_type__Struct_ASTNode(ptr %0) {
entry:
  %node.590 = alloca ptr, align 8
  store ptr %0, ptr %node.590, align 8
  %1 = load ptr, ptr %node.590, align 8
  %2 = getelementptr inbounds nuw %ASTNode, ptr %1, i32 0, i32 9
  %3 = load ptr, ptr %2, align 8
  %4 = call i32 @str_equals(ptr %3, ptr @.str.s439)
  %5 = icmp eq i32 %4, 0
  ret i1 %5
}

define ptr @node_get_type__Struct_ASTNode(ptr %0) {
entry:
  %node.591 = alloca ptr, align 8
  store ptr %0, ptr %node.591, align 8
  %1 = load ptr, ptr %node.591, align 8
  %2 = call i1 @node_has_type__Struct_ASTNode(ptr %1)
  br i1 %2, label %label_1120, label %label_1122

label_1122:                                       ; preds = %entry
  %3 = call ptr @type_invalid__Void()
  ret ptr %3

label_1120:                                       ; preds = %entry
  %4 = load ptr, ptr %node.591, align 8
  %5 = getelementptr inbounds nuw %ASTNode, ptr %4, i32 0, i32 9
  %6 = load ptr, ptr %5, align 8
  %7 = call ptr @ptr_to_type(ptr %6)
  ret ptr %7
}

define void @ir_set_target_wasm__Bool(i1 %0) {
entry:
  %enabled.592 = alloca i1, align 1
  store i1 %0, ptr %enabled.592, align 1
  %1 = load i1, ptr %enabled.592, align 1
  store i1 %1, ptr @ir_target_wasm, align 1
  ret void
}

define ptr @ir_ptr_int_type__Void() {
entry:
  %0 = load i1, ptr @ir_target_wasm, align 1
  br i1 %0, label %label_1123, label %label_1125

label_1125:                                       ; preds = %entry
  ret ptr @.str.s441

label_1123:                                       ; preds = %entry
  ret ptr @.str.s440
}

define ptr @map_type__String(ptr %0) {
entry:
  %t.593 = alloca ptr, align 8
  store ptr %0, ptr %t.593, align 8
  %1 = load ptr, ptr %t.593, align 8
  %2 = call i32 @str_equals(ptr %1, ptr @.str.s442)
  %3 = icmp eq i32 %2, 1
  br i1 %3, label %label_1126, label %label_1128

label_1128:                                       ; preds = %entry
  %4 = load ptr, ptr %t.593, align 8
  %5 = call i32 @str_equals(ptr %4, ptr @.str.s444)
  %6 = icmp eq i32 %5, 1
  br i1 %6, label %label_1129, label %label_1131

label_1126:                                       ; preds = %entry
  ret ptr @.str.s443

label_1131:                                       ; preds = %label_1128
  %7 = load ptr, ptr %t.593, align 8
  %8 = call i32 @str_equals(ptr %7, ptr @.str.s446)
  %9 = icmp eq i32 %8, 1
  br i1 %9, label %label_1132, label %label_1134

label_1129:                                       ; preds = %label_1128
  ret ptr @.str.s445

label_1134:                                       ; preds = %label_1131
  %10 = load ptr, ptr %t.593, align 8
  %11 = call i32 @str_equals(ptr %10, ptr @.str.s448)
  %12 = icmp eq i32 %11, 1
  br i1 %12, label %label_1135, label %label_1137

label_1132:                                       ; preds = %label_1131
  ret ptr @.str.s447

label_1137:                                       ; preds = %label_1134
  %13 = load ptr, ptr %t.593, align 8
  %14 = call i32 @str_equals(ptr %13, ptr @.str.s450)
  %15 = icmp eq i32 %14, 1
  br i1 %15, label %label_1138, label %label_1140

label_1135:                                       ; preds = %label_1134
  ret ptr @.str.s449

label_1140:                                       ; preds = %label_1137
  %16 = load ptr, ptr %t.593, align 8
  %17 = call i32 @str_equals(ptr %16, ptr @.str.s452)
  %18 = icmp eq i32 %17, 1
  br i1 %18, label %label_1141, label %label_1143

label_1138:                                       ; preds = %label_1137
  ret ptr @.str.s451

label_1143:                                       ; preds = %label_1140
  %19 = load ptr, ptr %t.593, align 8
  %20 = call i32 @str_equals(ptr %19, ptr @.str.s454)
  %21 = icmp eq i32 %20, 1
  br i1 %21, label %label_1144, label %label_1146

label_1141:                                       ; preds = %label_1140
  ret ptr @.str.s453

label_1146:                                       ; preds = %label_1143
  %22 = load ptr, ptr %t.593, align 8
  %23 = call i32 @str_equals(ptr %22, ptr @.str.s456)
  %24 = icmp eq i32 %23, 1
  br i1 %24, label %label_1147, label %label_1149

label_1144:                                       ; preds = %label_1143
  ret ptr @.str.s455

label_1149:                                       ; preds = %label_1146
  %25 = load ptr, ptr %t.593, align 8
  %26 = call i32 @str_equals(ptr %25, ptr @.str.s458)
  %27 = icmp eq i32 %26, 1
  br i1 %27, label %label_1150, label %label_1152

label_1147:                                       ; preds = %label_1146
  ret ptr @.str.s457

label_1152:                                       ; preds = %label_1149
  %28 = load ptr, ptr %t.593, align 8
  %29 = call i32 @str_equals(ptr %28, ptr @.str.s459)
  %30 = icmp eq i32 %29, 1
  br i1 %30, label %label_1153, label %label_1155

label_1150:                                       ; preds = %label_1149
  %31 = call ptr @ir_ptr_int_type__Void()
  ret ptr %31

label_1155:                                       ; preds = %label_1152
  %32 = load ptr, ptr %t.593, align 8
  %33 = call i32 @str_equals(ptr %32, ptr @.str.s461)
  %34 = icmp eq i32 %33, 1
  br i1 %34, label %label_1156, label %label_1158

label_1153:                                       ; preds = %label_1152
  ret ptr @.str.s460

label_1158:                                       ; preds = %label_1155
  %35 = load ptr, ptr %t.593, align 8
  %36 = call i32 @str_equals(ptr %35, ptr @.str.s463)
  %37 = icmp eq i32 %36, 1
  br i1 %37, label %label_1159, label %label_1161

label_1156:                                       ; preds = %label_1155
  ret ptr @.str.s462

label_1161:                                       ; preds = %label_1158
  %38 = load ptr, ptr %t.593, align 8
  %39 = call i32 @str_equals(ptr %38, ptr @.str.s465)
  %40 = icmp eq i32 %39, 1
  br i1 %40, label %label_1162, label %label_1164

label_1159:                                       ; preds = %label_1158
  ret ptr @.str.s464

label_1164:                                       ; preds = %label_1161
  %41 = load ptr, ptr %t.593, align 8
  %42 = call i32 @str_equals(ptr %41, ptr @.str.s467)
  %43 = icmp eq i32 %42, 1
  br i1 %43, label %label_1165, label %label_1167

label_1162:                                       ; preds = %label_1161
  ret ptr @.str.s466

label_1167:                                       ; preds = %label_1164
  %44 = load ptr, ptr %t.593, align 8
  %45 = call i32 @str_equals(ptr %44, ptr @.str.s468)
  %46 = icmp eq i32 %45, 1
  br i1 %46, label %label_1168, label %label_1170

label_1165:                                       ; preds = %label_1164
  %47 = call ptr @ir_ptr_int_type__Void()
  ret ptr %47

label_1170:                                       ; preds = %label_1167
  ret ptr @.str.s470

label_1168:                                       ; preds = %label_1167
  ret ptr @.str.s469
}

define ptr @struct_type_key__String(ptr %0) {
entry:
  %name.594 = alloca ptr, align 8
  store ptr %0, ptr %name.594, align 8
  %1 = load ptr, ptr %name.594, align 8
  %2 = call ptr @str_concat(ptr @.str.s471, ptr %1)
  ret ptr %2
}

define i1 @is_struct_type_key__String(ptr %0) {
entry:
  %t.595 = alloca ptr, align 8
  store ptr %0, ptr %t.595, align 8
  %1 = load ptr, ptr %t.595, align 8
  %2 = call i32 @str_starts_with(ptr %1, ptr @.str.s472)
  %3 = icmp eq i32 %2, 1
  ret i1 %3
}

define ptr @struct_type_name__String(ptr %0) {
entry:
  %t.596 = alloca ptr, align 8
  store ptr %0, ptr %t.596, align 8
  %1 = load ptr, ptr %t.596, align 8
  %2 = load ptr, ptr %t.596, align 8
  %3 = call i32 @str_length(ptr %2)
  %4 = sub i32 %3, 7
  %5 = call ptr @str_substring(ptr %1, i32 7, i32 %4)
  ret ptr %5
}

define ptr @llvm_type_name__String(ptr %0) {
entry:
  %t.597 = alloca ptr, align 8
  store ptr %0, ptr %t.597, align 8
  %1 = load ptr, ptr %t.597, align 8
  %2 = call i1 @is_struct_type_key__String(ptr %1)
  br i1 %2, label %label_1171, label %label_1173

label_1173:                                       ; preds = %entry
  %3 = load ptr, ptr %t.597, align 8
  ret ptr %3

label_1171:                                       ; preds = %entry
  %4 = load ptr, ptr %t.597, align 8
  %5 = call ptr @struct_type_name__String(ptr %4)
  %6 = call ptr @str_concat(ptr @.str.s473, ptr %5)
  ret ptr %6
}

define ptr @map_type_node__Struct_ASTNode(ptr %0) {
entry:
  %tn.598 = alloca ptr, align 8
  store ptr %0, ptr %tn.598, align 8
  %1 = load ptr, ptr %tn.598, align 8
  %2 = getelementptr inbounds nuw %ASTNode, ptr %1, i32 0, i32 4
  %3 = load i32, ptr %2, align 4
  %4 = icmp eq i32 %3, 1
  %elem.599 = alloca ptr, align 8
  br i1 %4, label %label_1174, label %label_1176

label_1176:                                       ; preds = %entry
  %5 = load ptr, ptr %tn.598, align 8
  %6 = getelementptr inbounds nuw %ASTNode, ptr %5, i32 0, i32 3
  %7 = load i32, ptr %6, align 4
  %8 = icmp eq i32 %7, 1
  br i1 %8, label %label_1177, label %label_1179

label_1174:                                       ; preds = %entry
  ret ptr @.str.s474

label_1179:                                       ; preds = %label_1176
  %9 = load ptr, ptr %tn.598, align 8
  %10 = getelementptr inbounds nuw %ASTNode, ptr %9, i32 0, i32 1
  %11 = load ptr, ptr %10, align 8
  %12 = call i32 @ir_is_struct_type_name(ptr %11)
  %13 = icmp eq i32 %12, 1
  br i1 %13, label %label_1186, label %label_1188

label_1177:                                       ; preds = %label_1176
  %14 = load ptr, ptr %tn.598, align 8
  %15 = getelementptr inbounds nuw %ASTNode, ptr %14, i32 0, i32 5
  %16 = load ptr, ptr %15, align 8
  %17 = call i32 @str_equals(ptr %16, ptr @.str.s475)
  %18 = icmp eq i32 %17, 0
  br i1 %18, label %label_1180, label %label_1182

label_1182:                                       ; preds = %label_1185, %label_1177
  ret ptr @.str.s477

label_1180:                                       ; preds = %label_1177
  %19 = load ptr, ptr %tn.598, align 8
  %20 = getelementptr inbounds nuw %ASTNode, ptr %19, i32 0, i32 5
  %21 = load ptr, ptr %20, align 8
  %22 = call ptr @ptr_to_node(ptr %21)
  store ptr %22, ptr %elem.599, align 8
  %23 = load ptr, ptr %elem.599, align 8
  %24 = getelementptr inbounds nuw %ASTNode, ptr %23, i32 0, i32 3
  %25 = load i32, ptr %24, align 4
  %26 = icmp eq i32 %25, 1
  br i1 %26, label %label_1183, label %label_1185

label_1185:                                       ; preds = %label_1180
  br label %label_1182

label_1183:                                       ; preds = %label_1180
  ret ptr @.str.s476

label_1188:                                       ; preds = %label_1179
  %27 = load ptr, ptr %tn.598, align 8
  %28 = getelementptr inbounds nuw %ASTNode, ptr %27, i32 0, i32 1
  %29 = load ptr, ptr %28, align 8
  %30 = call ptr @map_type__String(ptr %29)
  ret ptr %30

label_1186:                                       ; preds = %label_1179
  %31 = load ptr, ptr %tn.598, align 8
  %32 = getelementptr inbounds nuw %ASTNode, ptr %31, i32 0, i32 1
  %33 = load ptr, ptr %32, align 8
  %34 = call ptr @struct_type_key__String(ptr %33)
  ret ptr %34
}

define ptr @storage_type__String(ptr %0) {
entry:
  %t.600 = alloca ptr, align 8
  store ptr %0, ptr %t.600, align 8
  %1 = load ptr, ptr %t.600, align 8
  %2 = call i32 @str_equals(ptr %1, ptr @.str.s478)
  %3 = icmp eq i32 %2, 1
  br i1 %3, label %label_1189, label %label_1191

label_1191:                                       ; preds = %entry
  %4 = load ptr, ptr %t.600, align 8
  %5 = call i1 @is_struct_type_key__String(ptr %4)
  br i1 %5, label %label_1192, label %label_1194

label_1189:                                       ; preds = %entry
  ret ptr @.str.s479

label_1194:                                       ; preds = %label_1191
  %6 = load ptr, ptr %t.600, align 8
  ret ptr %6

label_1192:                                       ; preds = %label_1191
  ret ptr @.str.s480
}

define i32 @count_list_nodes__String(ptr %0) {
entry:
  %first_ptr.601 = alloca ptr, align 8
  store ptr %0, ptr %first_ptr.601, align 8
  %count.602 = alloca i32, align 4
  store i32 0, ptr %count.602, align 4
  %1 = load ptr, ptr %first_ptr.601, align 8
  %curr.603 = alloca ptr, align 8
  store ptr %1, ptr %curr.603, align 8
  %node.604 = alloca ptr, align 8
  br label %label_1195

label_1195:                                       ; preds = %label_1196, %entry
  %2 = load ptr, ptr %curr.603, align 8
  %3 = call i32 @str_equals(ptr %2, ptr @.str.s481)
  %4 = icmp eq i32 %3, 0
  br i1 %4, label %label_1196, label %label_1197

label_1197:                                       ; preds = %label_1195
  %5 = load i32, ptr %count.602, align 4
  ret i32 %5

label_1196:                                       ; preds = %label_1195
  %6 = load ptr, ptr %curr.603, align 8
  %7 = call ptr @ptr_to_node(ptr %6)
  store ptr %7, ptr %node.604, align 8
  %8 = load i32, ptr %count.602, align 4
  %9 = add i32 %8, 1
  store i32 %9, ptr %count.602, align 4
  %10 = load ptr, ptr %node.604, align 8
  %11 = getelementptr inbounds nuw %ASTNode, ptr %10, i32 0, i32 8
  %12 = load ptr, ptr %11, align 8
  store ptr %12, ptr %curr.603, align 8
  br label %label_1195
}

define ptr @fn_key__String(ptr %0) {
entry:
  %name.605 = alloca ptr, align 8
  store ptr %0, ptr %name.605, align 8
  %1 = load ptr, ptr %name.605, align 8
  %2 = call ptr @str_concat(ptr @.str.s482, ptr %1)
  ret ptr %2
}

define ptr @function_symbol_name__Struct_ASTNode(ptr %0) {
entry:
  %func.606 = alloca ptr, align 8
  store ptr %0, ptr %func.606, align 8
  %1 = load ptr, ptr %func.606, align 8
  %2 = getelementptr inbounds nuw %ASTNode, ptr %1, i32 0, i32 2
  %3 = load ptr, ptr %2, align 8
  %4 = call i32 @str_equals(ptr %3, ptr @.str.s483)
  %5 = icmp eq i32 %4, 0
  br i1 %5, label %label_1198, label %label_1200

label_1200:                                       ; preds = %entry
  %6 = load ptr, ptr %func.606, align 8
  %7 = getelementptr inbounds nuw %ASTNode, ptr %6, i32 0, i32 1
  %8 = load ptr, ptr %7, align 8
  ret ptr %8

label_1198:                                       ; preds = %entry
  %9 = load ptr, ptr %func.606, align 8
  %10 = getelementptr inbounds nuw %ASTNode, ptr %9, i32 0, i32 2
  %11 = load ptr, ptr %10, align 8
  ret ptr %11
}

define ptr @get_declared_return_type__Struct_ASTNode_String(ptr %0, ptr %1) {
entry:
  %node.607 = alloca ptr, align 8
  store ptr %0, ptr %node.607, align 8
  %ret_child.608 = alloca ptr, align 8
  store ptr %1, ptr %ret_child.608, align 8
  %2 = load ptr, ptr %ret_child.608, align 8
  %3 = call i32 @str_equals(ptr %2, ptr @.str.s484)
  %4 = icmp eq i32 %3, 0
  %ret_node.609 = alloca ptr, align 8
  br i1 %4, label %label_1201, label %label_1203

label_1203:                                       ; preds = %entry
  ret ptr @.str.s485

label_1201:                                       ; preds = %entry
  %5 = load ptr, ptr %ret_child.608, align 8
  %6 = call ptr @ptr_to_node(ptr %5)
  store ptr %6, ptr %ret_node.609, align 8
  %7 = load ptr, ptr %ret_node.609, align 8
  %8 = call ptr @map_type_node__Struct_ASTNode(ptr %7)
  ret ptr %8
}

define ptr @get_expr_type__Struct_ASTNode(ptr %0) {
entry:
  %expr.610 = alloca ptr, align 8
  store ptr %0, ptr %expr.610, align 8
  %1 = load ptr, ptr %expr.610, align 8
  %2 = call i1 @node_has_type__Struct_ASTNode(ptr %1)
  %op.611 = alloca ptr, align 8
  %sc.77 = alloca i1, align 1
  %sc.78 = alloca i1, align 1
  %sc.79 = alloca i1, align 1
  %sc.80 = alloca i1, align 1
  %callee.612 = alloca ptr, align 8
  %func_name.613 = alloca ptr, align 8
  %sc.81 = alloca i1, align 1
  %sc.82 = alloca i1, align 1
  %sc.83 = alloca i1, align 1
  %sc.84 = alloca i1, align 1
  %sc.85 = alloca i1, align 1
  %obj_type.614 = alloca ptr, align 8
  %object_node.615 = alloca ptr, align 8
  %enum_val.616 = alloca i32, align 4
  %object_type.617 = alloca ptr, align 8
  br i1 %2, label %label_1204, label %label_1206

label_1206:                                       ; preds = %entry
  %3 = load ptr, ptr %expr.610, align 8
  %4 = getelementptr inbounds nuw %ASTNode, ptr %3, i32 0, i32 0
  %5 = load i32, ptr %4, align 4
  %6 = icmp eq i32 %5, 22
  br i1 %6, label %label_1207, label %label_1209

label_1204:                                       ; preds = %entry
  %7 = load ptr, ptr %expr.610, align 8
  %8 = call ptr @node_get_type__Struct_ASTNode(ptr %7)
  %9 = call ptr @type_ir_key__Struct_TypeInfo(ptr %8)
  ret ptr %9

label_1209:                                       ; preds = %label_1224, %label_1206
  %10 = load ptr, ptr %expr.610, align 8
  %11 = getelementptr inbounds nuw %ASTNode, ptr %10, i32 0, i32 0
  %12 = load i32, ptr %11, align 4
  %13 = icmp eq i32 %12, 23
  br i1 %13, label %label_1225, label %label_1227

label_1207:                                       ; preds = %label_1206
  %14 = load ptr, ptr %expr.610, align 8
  %15 = getelementptr inbounds nuw %ASTNode, ptr %14, i32 0, i32 3
  %16 = load i32, ptr %15, align 4
  %17 = icmp eq i32 %16, 2
  br i1 %17, label %label_1210, label %label_1212

label_1212:                                       ; preds = %label_1207
  %18 = load ptr, ptr %expr.610, align 8
  %19 = getelementptr inbounds nuw %ASTNode, ptr %18, i32 0, i32 3
  %20 = load i32, ptr %19, align 4
  %21 = icmp eq i32 %20, 3
  br i1 %21, label %label_1213, label %label_1215

label_1210:                                       ; preds = %label_1207
  ret ptr @.str.s486

label_1215:                                       ; preds = %label_1212
  %22 = load ptr, ptr %expr.610, align 8
  %23 = getelementptr inbounds nuw %ASTNode, ptr %22, i32 0, i32 3
  %24 = load i32, ptr %23, align 4
  %25 = icmp eq i32 %24, 4
  br i1 %25, label %label_1216, label %label_1218

label_1213:                                       ; preds = %label_1212
  ret ptr @.str.s487

label_1218:                                       ; preds = %label_1215
  %26 = load ptr, ptr %expr.610, align 8
  %27 = getelementptr inbounds nuw %ASTNode, ptr %26, i32 0, i32 3
  %28 = load i32, ptr %27, align 4
  %29 = icmp eq i32 %28, 1
  br i1 %29, label %label_1219, label %label_1221

label_1216:                                       ; preds = %label_1215
  ret ptr @.str.s488

label_1221:                                       ; preds = %label_1218
  %30 = load ptr, ptr %expr.610, align 8
  %31 = getelementptr inbounds nuw %ASTNode, ptr %30, i32 0, i32 3
  %32 = load i32, ptr %31, align 4
  %33 = icmp eq i32 %32, 0
  br i1 %33, label %label_1222, label %label_1224

label_1219:                                       ; preds = %label_1218
  ret ptr @.str.s489

label_1224:                                       ; preds = %label_1221
  br label %label_1209

label_1222:                                       ; preds = %label_1221
  ret ptr @.str.s490

label_1227:                                       ; preds = %label_1209
  %34 = load ptr, ptr %expr.610, align 8
  %35 = getelementptr inbounds nuw %ASTNode, ptr %34, i32 0, i32 0
  %36 = load i32, ptr %35, align 4
  %37 = icmp eq i32 %36, 21
  br i1 %37, label %label_1228, label %label_1230

label_1225:                                       ; preds = %label_1209
  %38 = load ptr, ptr %expr.610, align 8
  %39 = getelementptr inbounds nuw %ASTNode, ptr %38, i32 0, i32 1
  %40 = load ptr, ptr %39, align 8
  %41 = call ptr @ir_get_var_type(ptr %40)
  ret ptr %41

label_1230:                                       ; preds = %label_1227
  %42 = load ptr, ptr %expr.610, align 8
  %43 = getelementptr inbounds nuw %ASTNode, ptr %42, i32 0, i32 0
  %44 = load i32, ptr %43, align 4
  %45 = icmp eq i32 %44, 29
  br i1 %45, label %label_1234, label %label_1236

label_1228:                                       ; preds = %label_1227
  %46 = load ptr, ptr %expr.610, align 8
  %47 = getelementptr inbounds nuw %ASTNode, ptr %46, i32 0, i32 1
  %48 = load ptr, ptr %47, align 8
  %49 = call i32 @str_equals(ptr %48, ptr @.str.s491)
  %50 = icmp eq i32 %49, 1
  br i1 %50, label %label_1231, label %label_1233

label_1233:                                       ; preds = %label_1228
  %51 = load ptr, ptr %expr.610, align 8
  %52 = getelementptr inbounds nuw %ASTNode, ptr %51, i32 0, i32 5
  %53 = load ptr, ptr %52, align 8
  %54 = call ptr @ptr_to_node(ptr %53)
  %55 = call ptr @get_expr_type__Struct_ASTNode(ptr %54)
  ret ptr %55

label_1231:                                       ; preds = %label_1228
  ret ptr @.str.s492

label_1236:                                       ; preds = %label_1230
  %56 = load ptr, ptr %expr.610, align 8
  %57 = getelementptr inbounds nuw %ASTNode, ptr %56, i32 0, i32 0
  %58 = load i32, ptr %57, align 4
  %59 = icmp eq i32 %58, 20
  br i1 %59, label %label_1237, label %label_1239

label_1234:                                       ; preds = %label_1230
  %60 = load ptr, ptr %expr.610, align 8
  %61 = getelementptr inbounds nuw %ASTNode, ptr %60, i32 0, i32 6
  %62 = load ptr, ptr %61, align 8
  %63 = call ptr @ptr_to_node(ptr %62)
  %64 = call ptr @map_type_node__Struct_ASTNode(ptr %63)
  ret ptr %64

label_1239:                                       ; preds = %label_1236
  %65 = load ptr, ptr %expr.610, align 8
  %66 = getelementptr inbounds nuw %ASTNode, ptr %65, i32 0, i32 0
  %67 = load i32, ptr %66, align 4
  %68 = icmp eq i32 %67, 24
  br i1 %68, label %label_1260, label %label_1262

label_1237:                                       ; preds = %label_1236
  %69 = load ptr, ptr %expr.610, align 8
  %70 = getelementptr inbounds nuw %ASTNode, ptr %69, i32 0, i32 1
  %71 = load ptr, ptr %70, align 8
  store ptr %71, ptr %op.611, align 8
  %72 = load ptr, ptr %op.611, align 8
  %73 = call i32 @str_equals(ptr %72, ptr @.str.s493)
  %74 = icmp eq i32 %73, 1
  store i1 %74, ptr %sc.77, align 1
  br i1 %74, label %label_1241, label %label_1240

label_1240:                                       ; preds = %label_1237
  %75 = load ptr, ptr %op.611, align 8
  %76 = call i32 @str_equals(ptr %75, ptr @.str.s494)
  %77 = icmp eq i32 %76, 1
  store i1 %77, ptr %sc.77, align 1
  br label %label_1241

label_1241:                                       ; preds = %label_1240, %label_1237
  %78 = load i1, ptr %sc.77, align 1
  br i1 %78, label %label_1242, label %label_1244

label_1244:                                       ; preds = %label_1241
  %79 = load ptr, ptr %op.611, align 8
  %80 = call i32 @str_equals(ptr %79, ptr @.str.s496)
  %81 = icmp eq i32 %80, 1
  store i1 %81, ptr %sc.78, align 1
  br i1 %81, label %label_1246, label %label_1245

label_1242:                                       ; preds = %label_1241
  ret ptr @.str.s495

label_1245:                                       ; preds = %label_1244
  %82 = load ptr, ptr %op.611, align 8
  %83 = call i32 @str_equals(ptr %82, ptr @.str.s497)
  %84 = icmp eq i32 %83, 1
  store i1 %84, ptr %sc.78, align 1
  br label %label_1246

label_1246:                                       ; preds = %label_1245, %label_1244
  %85 = load i1, ptr %sc.78, align 1
  br i1 %85, label %label_1247, label %label_1249

label_1249:                                       ; preds = %label_1246
  %86 = load ptr, ptr %op.611, align 8
  %87 = call i32 @str_equals(ptr %86, ptr @.str.s499)
  %88 = icmp eq i32 %87, 1
  store i1 %88, ptr %sc.79, align 1
  br i1 %88, label %label_1251, label %label_1250

label_1247:                                       ; preds = %label_1246
  ret ptr @.str.s498

label_1250:                                       ; preds = %label_1249
  %89 = load ptr, ptr %op.611, align 8
  %90 = call i32 @str_equals(ptr %89, ptr @.str.s500)
  %91 = icmp eq i32 %90, 1
  store i1 %91, ptr %sc.79, align 1
  br label %label_1251

label_1251:                                       ; preds = %label_1250, %label_1249
  %92 = load i1, ptr %sc.79, align 1
  br i1 %92, label %label_1252, label %label_1254

label_1254:                                       ; preds = %label_1251
  %93 = load ptr, ptr %op.611, align 8
  %94 = call i32 @str_equals(ptr %93, ptr @.str.s502)
  %95 = icmp eq i32 %94, 1
  store i1 %95, ptr %sc.80, align 1
  br i1 %95, label %label_1256, label %label_1255

label_1252:                                       ; preds = %label_1251
  ret ptr @.str.s501

label_1255:                                       ; preds = %label_1254
  %96 = load ptr, ptr %op.611, align 8
  %97 = call i32 @str_equals(ptr %96, ptr @.str.s503)
  %98 = icmp eq i32 %97, 1
  store i1 %98, ptr %sc.80, align 1
  br label %label_1256

label_1256:                                       ; preds = %label_1255, %label_1254
  %99 = load i1, ptr %sc.80, align 1
  br i1 %99, label %label_1257, label %label_1259

label_1259:                                       ; preds = %label_1256
  %100 = load ptr, ptr %expr.610, align 8
  %101 = getelementptr inbounds nuw %ASTNode, ptr %100, i32 0, i32 5
  %102 = load ptr, ptr %101, align 8
  %103 = call ptr @ptr_to_node(ptr %102)
  %104 = call ptr @get_expr_type__Struct_ASTNode(ptr %103)
  ret ptr %104

label_1257:                                       ; preds = %label_1256
  ret ptr @.str.s504

label_1262:                                       ; preds = %label_1239
  %105 = load ptr, ptr %expr.610, align 8
  %106 = getelementptr inbounds nuw %ASTNode, ptr %105, i32 0, i32 0
  %107 = load i32, ptr %106, align 4
  %108 = icmp eq i32 %107, 26
  br i1 %108, label %label_1291, label %label_1293

label_1260:                                       ; preds = %label_1239
  %109 = load ptr, ptr %expr.610, align 8
  %110 = getelementptr inbounds nuw %ASTNode, ptr %109, i32 0, i32 5
  %111 = load ptr, ptr %110, align 8
  %112 = call ptr @ptr_to_node(ptr %111)
  store ptr %112, ptr %callee.612, align 8
  %113 = load ptr, ptr %callee.612, align 8
  %114 = getelementptr inbounds nuw %ASTNode, ptr %113, i32 0, i32 1
  %115 = load ptr, ptr %114, align 8
  store ptr %115, ptr %func_name.613, align 8
  %116 = load ptr, ptr %func_name.613, align 8
  %117 = call i32 @str_equals(ptr %116, ptr @.str.s505)
  %118 = icmp eq i32 %117, 1
  store i1 %118, ptr %sc.81, align 1
  br i1 %118, label %label_1264, label %label_1263

label_1263:                                       ; preds = %label_1260
  %119 = load ptr, ptr %func_name.613, align 8
  %120 = call i32 @str_equals(ptr %119, ptr @.str.s506)
  %121 = icmp eq i32 %120, 1
  store i1 %121, ptr %sc.81, align 1
  br label %label_1264

label_1264:                                       ; preds = %label_1263, %label_1260
  %122 = load i1, ptr %sc.81, align 1
  br i1 %122, label %label_1265, label %label_1267

label_1267:                                       ; preds = %label_1264
  %123 = load ptr, ptr %func_name.613, align 8
  %124 = call i32 @str_equals(ptr %123, ptr @.str.s508)
  %125 = icmp eq i32 %124, 1
  store i1 %125, ptr %sc.82, align 1
  br i1 %125, label %label_1269, label %label_1268

label_1265:                                       ; preds = %label_1264
  ret ptr @.str.s507

label_1268:                                       ; preds = %label_1267
  %126 = load ptr, ptr %func_name.613, align 8
  %127 = call i32 @str_equals(ptr %126, ptr @.str.s509)
  %128 = icmp eq i32 %127, 1
  store i1 %128, ptr %sc.82, align 1
  br label %label_1269

label_1269:                                       ; preds = %label_1268, %label_1267
  %129 = load i1, ptr %sc.82, align 1
  br i1 %129, label %label_1270, label %label_1272

label_1272:                                       ; preds = %label_1269
  %130 = load ptr, ptr %func_name.613, align 8
  %131 = call i32 @str_equals(ptr %130, ptr @.str.s511)
  %132 = icmp eq i32 %131, 1
  store i1 %132, ptr %sc.83, align 1
  br i1 %132, label %label_1274, label %label_1273

label_1270:                                       ; preds = %label_1269
  ret ptr @.str.s510

label_1273:                                       ; preds = %label_1272
  %133 = load ptr, ptr %func_name.613, align 8
  %134 = call i32 @str_equals(ptr %133, ptr @.str.s512)
  %135 = icmp eq i32 %134, 1
  store i1 %135, ptr %sc.83, align 1
  br label %label_1274

label_1274:                                       ; preds = %label_1273, %label_1272
  %136 = load i1, ptr %sc.83, align 1
  br i1 %136, label %label_1275, label %label_1277

label_1277:                                       ; preds = %label_1274
  %137 = load ptr, ptr %func_name.613, align 8
  %138 = call i32 @str_equals(ptr %137, ptr @.str.s514)
  %139 = icmp eq i32 %138, 1
  store i1 %139, ptr %sc.84, align 1
  br i1 %139, label %label_1279, label %label_1278

label_1275:                                       ; preds = %label_1274
  ret ptr @.str.s513

label_1278:                                       ; preds = %label_1277
  %140 = load ptr, ptr %func_name.613, align 8
  %141 = call i32 @str_equals(ptr %140, ptr @.str.s515)
  %142 = icmp eq i32 %141, 1
  store i1 %142, ptr %sc.84, align 1
  br label %label_1279

label_1279:                                       ; preds = %label_1278, %label_1277
  %143 = load i1, ptr %sc.84, align 1
  br i1 %143, label %label_1280, label %label_1282

label_1282:                                       ; preds = %label_1279
  %144 = load ptr, ptr %func_name.613, align 8
  %145 = call i32 @str_equals(ptr %144, ptr @.str.s517)
  %146 = icmp eq i32 %145, 1
  store i1 %146, ptr %sc.85, align 1
  br i1 %146, label %label_1284, label %label_1283

label_1280:                                       ; preds = %label_1279
  ret ptr @.str.s516

label_1283:                                       ; preds = %label_1282
  %147 = load ptr, ptr %func_name.613, align 8
  %148 = call i32 @str_equals(ptr %147, ptr @.str.s518)
  %149 = icmp eq i32 %148, 1
  store i1 %149, ptr %sc.85, align 1
  br label %label_1284

label_1284:                                       ; preds = %label_1283, %label_1282
  %150 = load i1, ptr %sc.85, align 1
  br i1 %150, label %label_1285, label %label_1287

label_1287:                                       ; preds = %label_1284
  %151 = load ptr, ptr %expr.610, align 8
  %152 = getelementptr inbounds nuw %ASTNode, ptr %151, i32 0, i32 2
  %153 = load ptr, ptr %152, align 8
  %154 = call i32 @str_equals(ptr %153, ptr @.str.s520)
  %155 = icmp eq i32 %154, 0
  br i1 %155, label %label_1288, label %label_1290

label_1285:                                       ; preds = %label_1284
  ret ptr @.str.s519

label_1290:                                       ; preds = %label_1287
  %156 = load ptr, ptr %func_name.613, align 8
  %157 = call ptr @fn_key__String(ptr %156)
  %158 = call ptr @ir_get_var_type(ptr %157)
  ret ptr %158

label_1288:                                       ; preds = %label_1287
  %159 = load ptr, ptr %expr.610, align 8
  %160 = getelementptr inbounds nuw %ASTNode, ptr %159, i32 0, i32 2
  %161 = load ptr, ptr %160, align 8
  %162 = call ptr @fn_key__String(ptr %161)
  %163 = call ptr @ir_get_var_type(ptr %162)
  ret ptr %163

label_1293:                                       ; preds = %label_1262
  %164 = load ptr, ptr %expr.610, align 8
  %165 = getelementptr inbounds nuw %ASTNode, ptr %164, i32 0, i32 0
  %166 = load i32, ptr %165, align 4
  %167 = icmp eq i32 %166, 25
  br i1 %167, label %label_1297, label %label_1299

label_1291:                                       ; preds = %label_1262
  %168 = load ptr, ptr %expr.610, align 8
  %169 = getelementptr inbounds nuw %ASTNode, ptr %168, i32 0, i32 5
  %170 = load ptr, ptr %169, align 8
  %171 = call ptr @ptr_to_node(ptr %170)
  %172 = call ptr @get_expr_type__Struct_ASTNode(ptr %171)
  store ptr %172, ptr %obj_type.614, align 8
  %173 = load ptr, ptr %obj_type.614, align 8
  %174 = call i32 @str_equals(ptr %173, ptr @.str.s521)
  %175 = icmp eq i32 %174, 1
  br i1 %175, label %label_1294, label %label_1296

label_1296:                                       ; preds = %label_1291
  ret ptr @.str.s523

label_1294:                                       ; preds = %label_1291
  ret ptr @.str.s522

label_1299:                                       ; preds = %label_1293
  %176 = load ptr, ptr %expr.610, align 8
  %177 = getelementptr inbounds nuw %ASTNode, ptr %176, i32 0, i32 0
  %178 = load i32, ptr %177, align 4
  %179 = icmp eq i32 %178, 27
  br i1 %179, label %label_1309, label %label_1311

label_1297:                                       ; preds = %label_1293
  %180 = load ptr, ptr %expr.610, align 8
  %181 = getelementptr inbounds nuw %ASTNode, ptr %180, i32 0, i32 5
  %182 = load ptr, ptr %181, align 8
  %183 = call ptr @ptr_to_node(ptr %182)
  store ptr %183, ptr %object_node.615, align 8
  %184 = load ptr, ptr %object_node.615, align 8
  %185 = getelementptr inbounds nuw %ASTNode, ptr %184, i32 0, i32 0
  %186 = load i32, ptr %185, align 4
  %187 = icmp eq i32 %186, 23
  br i1 %187, label %label_1300, label %label_1302

label_1302:                                       ; preds = %label_1305, %label_1297
  %188 = load ptr, ptr %object_node.615, align 8
  %189 = call ptr @get_expr_type__Struct_ASTNode(ptr %188)
  store ptr %189, ptr %object_type.617, align 8
  %190 = load ptr, ptr %object_type.617, align 8
  %191 = call i1 @is_struct_type_key__String(ptr %190)
  br i1 %191, label %label_1306, label %label_1308

label_1300:                                       ; preds = %label_1297
  %192 = load ptr, ptr %object_node.615, align 8
  %193 = getelementptr inbounds nuw %ASTNode, ptr %192, i32 0, i32 1
  %194 = load ptr, ptr %193, align 8
  %195 = load ptr, ptr %expr.610, align 8
  %196 = getelementptr inbounds nuw %ASTNode, ptr %195, i32 0, i32 1
  %197 = load ptr, ptr %196, align 8
  %198 = call i32 @ir_get_enum_variant(ptr %194, ptr %197)
  store i32 %198, ptr %enum_val.616, align 4
  %199 = load i32, ptr %enum_val.616, align 4
  %200 = icmp sge i32 %199, 0
  br i1 %200, label %label_1303, label %label_1305

label_1305:                                       ; preds = %label_1300
  br label %label_1302

label_1303:                                       ; preds = %label_1300
  ret ptr @.str.s524

label_1308:                                       ; preds = %label_1302
  ret ptr @.str.s525

label_1306:                                       ; preds = %label_1302
  %201 = load ptr, ptr %object_type.617, align 8
  %202 = call ptr @struct_type_name__String(ptr %201)
  %203 = load ptr, ptr %expr.610, align 8
  %204 = getelementptr inbounds nuw %ASTNode, ptr %203, i32 0, i32 1
  %205 = load ptr, ptr %204, align 8
  %206 = call ptr @ir_get_struct_field_type(ptr %202, ptr %205)
  ret ptr %206

label_1311:                                       ; preds = %label_1299
  %207 = load ptr, ptr %expr.610, align 8
  %208 = getelementptr inbounds nuw %ASTNode, ptr %207, i32 0, i32 0
  %209 = load i32, ptr %208, align 4
  %210 = icmp eq i32 %209, 28
  br i1 %210, label %label_1312, label %label_1314

label_1309:                                       ; preds = %label_1299
  ret ptr @.str.s526

label_1314:                                       ; preds = %label_1311
  ret ptr @.str.s527

label_1312:                                       ; preds = %label_1311
  %211 = load ptr, ptr %expr.610, align 8
  %212 = getelementptr inbounds nuw %ASTNode, ptr %211, i32 0, i32 1
  %213 = load ptr, ptr %212, align 8
  %214 = call ptr @struct_type_key__String(ptr %213)
  ret ptr %214
}

define ptr @generate_short_circuit__Struct_ASTNode(ptr %0) {
entry:
  %expr.618 = alloca ptr, align 8
  store ptr %0, ptr %expr.618, align 8
  %1 = load ptr, ptr %expr.618, align 8
  %2 = getelementptr inbounds nuw %ASTNode, ptr %1, i32 0, i32 1
  %3 = load ptr, ptr %2, align 8
  %4 = call i32 @str_equals(ptr %3, ptr @.str.s528)
  %5 = icmp eq i32 %4, 1
  %is_and.619 = alloca i1, align 1
  store i1 %5, ptr %is_and.619, align 1
  %6 = load i32, ptr @ir_short_circuit_counter, align 4
  %7 = call ptr @int_to_str(i32 %6)
  %8 = call ptr @str_concat(ptr @.str.s529, ptr %7)
  %slot.620 = alloca ptr, align 8
  store ptr %8, ptr %slot.620, align 8
  %9 = load i32, ptr @ir_short_circuit_counter, align 4
  %10 = add i32 %9, 1
  store i32 %10, ptr @ir_short_circuit_counter, align 4
  %11 = load ptr, ptr %slot.620, align 8
  %12 = call i32 @ir_alloca(ptr @.str.s530, ptr %11)
  %13 = call i32 @ir_get_label()
  %rhs_label.621 = alloca i32, align 4
  store i32 %13, ptr %rhs_label.621, align 4
  %14 = call i32 @ir_get_label()
  %done_label.622 = alloca i32, align 4
  store i32 %14, ptr %done_label.622, align 4
  %15 = load ptr, ptr %expr.618, align 8
  %16 = getelementptr inbounds nuw %ASTNode, ptr %15, i32 0, i32 5
  %17 = load ptr, ptr %16, align 8
  %18 = call ptr @ptr_to_node(ptr %17)
  %19 = call ptr @generate_expression__Struct_ASTNode(ptr %18)
  %left_val.623 = alloca ptr, align 8
  store ptr %19, ptr %left_val.623, align 8
  %20 = load ptr, ptr %left_val.623, align 8
  %21 = load ptr, ptr %slot.620, align 8
  call void @ir_store(ptr @.str.s531, ptr %20, ptr %21)
  %22 = load i1, ptr %is_and.619, align 1
  %right_val.624 = alloca ptr, align 8
  %result_id.625 = alloca i32, align 4
  br i1 %22, label %label_1315, label %label_1316

label_1316:                                       ; preds = %entry
  %23 = load ptr, ptr %left_val.623, align 8
  %24 = load i32, ptr %done_label.622, align 4
  %25 = load i32, ptr %rhs_label.621, align 4
  call void @ir_cond_br_numbered(ptr %23, i32 %24, i32 %25)
  br label %label_1317

label_1315:                                       ; preds = %entry
  %26 = load ptr, ptr %left_val.623, align 8
  %27 = load i32, ptr %rhs_label.621, align 4
  %28 = load i32, ptr %done_label.622, align 4
  call void @ir_cond_br_numbered(ptr %26, i32 %27, i32 %28)
  br label %label_1317

label_1317:                                       ; preds = %label_1316, %label_1315
  %29 = load i32, ptr %rhs_label.621, align 4
  call void @ir_label_numbered(i32 %29)
  %30 = load ptr, ptr %expr.618, align 8
  %31 = getelementptr inbounds nuw %ASTNode, ptr %30, i32 0, i32 6
  %32 = load ptr, ptr %31, align 8
  %33 = call ptr @ptr_to_node(ptr %32)
  %34 = call ptr @generate_expression__Struct_ASTNode(ptr %33)
  store ptr %34, ptr %right_val.624, align 8
  %35 = load ptr, ptr %right_val.624, align 8
  %36 = load ptr, ptr %slot.620, align 8
  call void @ir_store(ptr @.str.s532, ptr %35, ptr %36)
  %37 = load i32, ptr %done_label.622, align 4
  call void @ir_br_numbered(i32 %37)
  %38 = load i32, ptr %done_label.622, align 4
  call void @ir_label_numbered(i32 %38)
  %39 = load ptr, ptr %slot.620, align 8
  %40 = call i32 @ir_load(ptr @.str.s533, ptr %39)
  store i32 %40, ptr %result_id.625, align 4
  %41 = load i32, ptr %result_id.625, align 4
  %42 = call ptr @ir_get_temp_name(i32 %41)
  ret ptr %42
}

define ptr @generate_expression__Struct_ASTNode(ptr %0) {
entry:
  %expr.626 = alloca ptr, align 8
  store ptr %0, ptr %expr.626, align 8
  %1 = load ptr, ptr %expr.626, align 8
  %2 = getelementptr inbounds nuw %ASTNode, ptr %1, i32 0, i32 0
  %3 = load i32, ptr %2, align 4
  %4 = icmp eq i32 %3, 22
  %struct_name.627 = alloca ptr, align 8
  %mem_name.628 = alloca ptr, align 8
  %field_ptr.629 = alloca ptr, align 8
  %field.630 = alloca ptr, align 8
  %field_val.631 = alloca ptr, align 8
  %field_type.632 = alloca ptr, align 8
  %field_index.633 = alloca i32, align 4
  %slot.634 = alloca i32, align 4
  %val_type.635 = alloca ptr, align 8
  %load_type.636 = alloca ptr, align 8
  %object_node.637 = alloca ptr, align 8
  %enum_val.638 = alloca i32, align 4
  %object_val.639 = alloca ptr, align 8
  %object_type.640 = alloca ptr, align 8
  %struct_name.641 = alloca ptr, align 8
  %field_index.642 = alloca i32, align 4
  %field_type.643 = alloca ptr, align 8
  %slot.644 = alloca i32, align 4
  %elem_count.645 = alloca i32, align 4
  %first_elem.646 = alloca ptr, align 8
  %arr_t.647 = alloca ptr, align 8
  %elem_type.648 = alloca ptr, align 8
  %base.649 = alloca ptr, align 8
  %elem_ptr.650 = alloca ptr, align 8
  %elem_index.651 = alloca i32, align 4
  %elem_node.652 = alloca ptr, align 8
  %elem_val.653 = alloca ptr, align 8
  %slot.654 = alloca i32, align 4
  %array_val.655 = alloca ptr, align 8
  %index_val.656 = alloca ptr, align 8
  %elem_type.657 = alloca ptr, align 8
  %slot.658 = alloca i32, align 4
  %source.659 = alloca ptr, align 8
  %val.660 = alloca ptr, align 8
  %from_t.661 = alloca ptr, align 8
  %to_t.662 = alloca ptr, align 8
  %from_key.663 = alloca ptr, align 8
  %to_key.664 = alloca ptr, align 8
  %sc.86 = alloca i1, align 1
  %sc.87 = alloca i1, align 1
  %zero_extend.665 = alloca i1, align 1
  %operand_node.666 = alloca ptr, align 8
  %operand_val.667 = alloca ptr, align 8
  %uop.668 = alloca ptr, align 8
  %not_id.669 = alloca i32, align 4
  %int_type.670 = alloca ptr, align 8
  %operand_type.671 = alloca ptr, align 8
  %fneg_id.672 = alloca i32, align 4
  %neg_id.673 = alloca i32, align 4
  %sc.88 = alloca i1, align 1
  %left_val.674 = alloca ptr, align 8
  %right_val.675 = alloca ptr, align 8
  %op.676 = alloca ptr, align 8
  %temp_id.677 = alloca i32, align 4
  %left_node.678 = alloca ptr, align 8
  %op_type.679 = alloca ptr, align 8
  %is_unsigned.680 = alloca i1, align 1
  %callee.681 = alloca ptr, align 8
  %func_name.682 = alloca ptr, align 8
  %drop_arg.683 = alloca ptr, align 8
  %drop_val.684 = alloca ptr, align 8
  %is_print_bool.685 = alloca i32, align 4
  %bool_arg_ptr.686 = alloca ptr, align 8
  %bool_arg.687 = alloca ptr, align 8
  %bool_val.688 = alloca ptr, align 8
  %widened.689 = alloca i32, align 4
  %is_print.690 = alloca i32, align 4
  %arg_ptr.691 = alloca ptr, align 8
  %arg_node.692 = alloca ptr, align 8
  %arg_val.693 = alloca ptr, align 8
  %arg_type.694 = alloca ptr, align 8
  %arg_ptr.695 = alloca ptr, align 8
  %arg_node.696 = alloca ptr, align 8
  %arg_val.697 = alloca ptr, align 8
  %call_name.698 = alloca ptr, align 8
  %ret_type.699 = alloca ptr, align 8
  %temp_id.700 = alloca i32, align 4
  br i1 %4, label %label_1318, label %label_1320

label_1320:                                       ; preds = %label_1338, %entry
  %5 = load ptr, ptr %expr.626, align 8
  %6 = getelementptr inbounds nuw %ASTNode, ptr %5, i32 0, i32 0
  %7 = load i32, ptr %6, align 4
  %8 = icmp eq i32 %7, 28
  br i1 %8, label %label_1339, label %label_1341

label_1318:                                       ; preds = %entry
  %9 = load ptr, ptr %expr.626, align 8
  %10 = getelementptr inbounds nuw %ASTNode, ptr %9, i32 0, i32 3
  %11 = load i32, ptr %10, align 4
  %12 = icmp eq i32 %11, 2
  br i1 %12, label %label_1321, label %label_1323

label_1323:                                       ; preds = %label_1318
  %13 = load ptr, ptr %expr.626, align 8
  %14 = getelementptr inbounds nuw %ASTNode, ptr %13, i32 0, i32 3
  %15 = load i32, ptr %14, align 4
  %16 = icmp eq i32 %15, 3
  br i1 %16, label %label_1324, label %label_1326

label_1321:                                       ; preds = %label_1318
  %17 = load ptr, ptr %expr.626, align 8
  %18 = getelementptr inbounds nuw %ASTNode, ptr %17, i32 0, i32 1
  %19 = load ptr, ptr %18, align 8
  ret ptr %19

label_1326:                                       ; preds = %label_1323
  %20 = load ptr, ptr %expr.626, align 8
  %21 = getelementptr inbounds nuw %ASTNode, ptr %20, i32 0, i32 3
  %22 = load i32, ptr %21, align 4
  %23 = icmp eq i32 %22, 4
  br i1 %23, label %label_1327, label %label_1329

label_1324:                                       ; preds = %label_1323
  %24 = load ptr, ptr %expr.626, align 8
  %25 = getelementptr inbounds nuw %ASTNode, ptr %24, i32 0, i32 1
  %26 = load ptr, ptr %25, align 8
  ret ptr %26

label_1329:                                       ; preds = %label_1326
  %27 = load ptr, ptr %expr.626, align 8
  %28 = getelementptr inbounds nuw %ASTNode, ptr %27, i32 0, i32 3
  %29 = load i32, ptr %28, align 4
  %30 = icmp eq i32 %29, 1
  br i1 %30, label %label_1333, label %label_1335

label_1327:                                       ; preds = %label_1326
  %31 = load ptr, ptr %expr.626, align 8
  %32 = getelementptr inbounds nuw %ASTNode, ptr %31, i32 0, i32 1
  %33 = load ptr, ptr %32, align 8
  %34 = call i32 @str_equals(ptr %33, ptr @.str.s534)
  %35 = icmp eq i32 %34, 1
  br i1 %35, label %label_1330, label %label_1332

label_1332:                                       ; preds = %label_1327
  ret ptr @.str.s536

label_1330:                                       ; preds = %label_1327
  ret ptr @.str.s535

label_1335:                                       ; preds = %label_1329
  %36 = load ptr, ptr %expr.626, align 8
  %37 = getelementptr inbounds nuw %ASTNode, ptr %36, i32 0, i32 3
  %38 = load i32, ptr %37, align 4
  %39 = icmp eq i32 %38, 0
  br i1 %39, label %label_1336, label %label_1338

label_1333:                                       ; preds = %label_1329
  %40 = load ptr, ptr %expr.626, align 8
  %41 = getelementptr inbounds nuw %ASTNode, ptr %40, i32 0, i32 1
  %42 = load ptr, ptr %41, align 8
  ret ptr %42

label_1338:                                       ; preds = %label_1335
  br label %label_1320

label_1336:                                       ; preds = %label_1335
  %43 = load ptr, ptr %expr.626, align 8
  %44 = getelementptr inbounds nuw %ASTNode, ptr %43, i32 0, i32 2
  %45 = load ptr, ptr %44, align 8
  %46 = call i32 @ir_string_ptr(ptr %45)
  %47 = call ptr @ir_get_temp_name(i32 %46)
  ret ptr %47

label_1341:                                       ; preds = %label_1320
  %48 = load ptr, ptr %expr.626, align 8
  %49 = getelementptr inbounds nuw %ASTNode, ptr %48, i32 0, i32 0
  %50 = load i32, ptr %49, align 4
  %51 = icmp eq i32 %50, 23
  br i1 %51, label %label_1345, label %label_1347

label_1339:                                       ; preds = %label_1320
  %52 = load ptr, ptr %expr.626, align 8
  %53 = getelementptr inbounds nuw %ASTNode, ptr %52, i32 0, i32 1
  %54 = load ptr, ptr %53, align 8
  store ptr %54, ptr %struct_name.627, align 8
  %55 = load ptr, ptr %struct_name.627, align 8
  %56 = call i32 @ir_alloc_object(ptr %55)
  %57 = call ptr @ir_get_temp_name(i32 %56)
  store ptr %57, ptr %mem_name.628, align 8
  %58 = load ptr, ptr %expr.626, align 8
  %59 = getelementptr inbounds nuw %ASTNode, ptr %58, i32 0, i32 5
  %60 = load ptr, ptr %59, align 8
  store ptr %60, ptr %field_ptr.629, align 8
  br label %label_1342

label_1342:                                       ; preds = %label_1343, %label_1339
  %61 = load ptr, ptr %field_ptr.629, align 8
  %62 = call i32 @str_equals(ptr %61, ptr @.str.s537)
  %63 = icmp eq i32 %62, 0
  br i1 %63, label %label_1343, label %label_1344

label_1344:                                       ; preds = %label_1342
  %64 = load ptr, ptr %mem_name.628, align 8
  ret ptr %64

label_1343:                                       ; preds = %label_1342
  %65 = load ptr, ptr %field_ptr.629, align 8
  %66 = call ptr @ptr_to_node(ptr %65)
  store ptr %66, ptr %field.630, align 8
  %67 = load ptr, ptr %field.630, align 8
  %68 = getelementptr inbounds nuw %ASTNode, ptr %67, i32 0, i32 5
  %69 = load ptr, ptr %68, align 8
  %70 = call ptr @ptr_to_node(ptr %69)
  %71 = call ptr @generate_expression__Struct_ASTNode(ptr %70)
  store ptr %71, ptr %field_val.631, align 8
  %72 = load ptr, ptr %struct_name.627, align 8
  %73 = load ptr, ptr %field.630, align 8
  %74 = getelementptr inbounds nuw %ASTNode, ptr %73, i32 0, i32 1
  %75 = load ptr, ptr %74, align 8
  %76 = call ptr @ir_get_struct_field_type(ptr %72, ptr %75)
  %77 = call ptr @storage_type__String(ptr %76)
  store ptr %77, ptr %field_type.632, align 8
  %78 = load ptr, ptr %struct_name.627, align 8
  %79 = load ptr, ptr %field.630, align 8
  %80 = getelementptr inbounds nuw %ASTNode, ptr %79, i32 0, i32 1
  %81 = load ptr, ptr %80, align 8
  %82 = call i32 @ir_get_struct_field_index(ptr %78, ptr %81)
  store i32 %82, ptr %field_index.633, align 4
  %83 = load ptr, ptr %struct_name.627, align 8
  %84 = load ptr, ptr %mem_name.628, align 8
  %85 = load i32, ptr %field_index.633, align 4
  %86 = call i32 @ir_struct_field_ptr(ptr %83, ptr %84, i32 %85)
  store i32 %86, ptr %slot.634, align 4
  %87 = load ptr, ptr %field_type.632, align 8
  %88 = load ptr, ptr %field_val.631, align 8
  %89 = load i32, ptr %slot.634, align 4
  %90 = call ptr @ir_get_temp_name(i32 %89)
  call void @ir_store_ptr(ptr %87, ptr %88, ptr %90)
  %91 = load ptr, ptr %field.630, align 8
  %92 = getelementptr inbounds nuw %ASTNode, ptr %91, i32 0, i32 8
  %93 = load ptr, ptr %92, align 8
  store ptr %93, ptr %field_ptr.629, align 8
  br label %label_1342

label_1347:                                       ; preds = %label_1341
  %94 = load ptr, ptr %expr.626, align 8
  %95 = getelementptr inbounds nuw %ASTNode, ptr %94, i32 0, i32 0
  %96 = load i32, ptr %95, align 4
  %97 = icmp eq i32 %96, 25
  br i1 %97, label %label_1351, label %label_1353

label_1345:                                       ; preds = %label_1341
  %98 = load ptr, ptr %expr.626, align 8
  %99 = getelementptr inbounds nuw %ASTNode, ptr %98, i32 0, i32 1
  %100 = load ptr, ptr %99, align 8
  %101 = call ptr @ir_get_var_type(ptr %100)
  store ptr %101, ptr %val_type.635, align 8
  %102 = load ptr, ptr %val_type.635, align 8
  %103 = call ptr @storage_type__String(ptr %102)
  store ptr %103, ptr %load_type.636, align 8
  %104 = load ptr, ptr %expr.626, align 8
  %105 = getelementptr inbounds nuw %ASTNode, ptr %104, i32 0, i32 1
  %106 = load ptr, ptr %105, align 8
  %107 = call i32 @ir_var_is_global(ptr %106)
  %108 = icmp eq i32 %107, 1
  br i1 %108, label %label_1348, label %label_1350

label_1350:                                       ; preds = %label_1345
  %109 = load ptr, ptr %load_type.636, align 8
  %110 = load ptr, ptr %expr.626, align 8
  %111 = getelementptr inbounds nuw %ASTNode, ptr %110, i32 0, i32 1
  %112 = load ptr, ptr %111, align 8
  %113 = call ptr @ir_get_var_slot(ptr %112)
  %114 = call i32 @ir_load(ptr %109, ptr %113)
  %115 = call ptr @ir_get_temp_name(i32 %114)
  ret ptr %115

label_1348:                                       ; preds = %label_1345
  %116 = load ptr, ptr %load_type.636, align 8
  %117 = load ptr, ptr %expr.626, align 8
  %118 = getelementptr inbounds nuw %ASTNode, ptr %117, i32 0, i32 1
  %119 = load ptr, ptr %118, align 8
  %120 = call i32 @ir_load_global(ptr %116, ptr %119)
  %121 = call ptr @ir_get_temp_name(i32 %120)
  ret ptr %121

label_1353:                                       ; preds = %label_1347
  %122 = load ptr, ptr %expr.626, align 8
  %123 = getelementptr inbounds nuw %ASTNode, ptr %122, i32 0, i32 0
  %124 = load i32, ptr %123, align 4
  %125 = icmp eq i32 %124, 27
  br i1 %125, label %label_1360, label %label_1362

label_1351:                                       ; preds = %label_1347
  %126 = load ptr, ptr %expr.626, align 8
  %127 = getelementptr inbounds nuw %ASTNode, ptr %126, i32 0, i32 5
  %128 = load ptr, ptr %127, align 8
  %129 = call ptr @ptr_to_node(ptr %128)
  store ptr %129, ptr %object_node.637, align 8
  %130 = load ptr, ptr %object_node.637, align 8
  %131 = getelementptr inbounds nuw %ASTNode, ptr %130, i32 0, i32 0
  %132 = load i32, ptr %131, align 4
  %133 = icmp eq i32 %132, 23
  br i1 %133, label %label_1354, label %label_1356

label_1356:                                       ; preds = %label_1359, %label_1351
  %134 = load ptr, ptr %object_node.637, align 8
  %135 = call ptr @generate_expression__Struct_ASTNode(ptr %134)
  store ptr %135, ptr %object_val.639, align 8
  %136 = load ptr, ptr %object_node.637, align 8
  %137 = call ptr @get_expr_type__Struct_ASTNode(ptr %136)
  store ptr %137, ptr %object_type.640, align 8
  %138 = load ptr, ptr %object_type.640, align 8
  %139 = call ptr @struct_type_name__String(ptr %138)
  store ptr %139, ptr %struct_name.641, align 8
  %140 = load ptr, ptr %struct_name.641, align 8
  %141 = load ptr, ptr %expr.626, align 8
  %142 = getelementptr inbounds nuw %ASTNode, ptr %141, i32 0, i32 1
  %143 = load ptr, ptr %142, align 8
  %144 = call i32 @ir_get_struct_field_index(ptr %140, ptr %143)
  store i32 %144, ptr %field_index.642, align 4
  %145 = load ptr, ptr %struct_name.641, align 8
  %146 = load ptr, ptr %expr.626, align 8
  %147 = getelementptr inbounds nuw %ASTNode, ptr %146, i32 0, i32 1
  %148 = load ptr, ptr %147, align 8
  %149 = call ptr @ir_get_struct_field_type(ptr %145, ptr %148)
  %150 = call ptr @storage_type__String(ptr %149)
  store ptr %150, ptr %field_type.643, align 8
  %151 = load ptr, ptr %struct_name.641, align 8
  %152 = load ptr, ptr %object_val.639, align 8
  %153 = load i32, ptr %field_index.642, align 4
  %154 = call i32 @ir_struct_field_ptr(ptr %151, ptr %152, i32 %153)
  store i32 %154, ptr %slot.644, align 4
  %155 = load ptr, ptr %field_type.643, align 8
  %156 = load i32, ptr %slot.644, align 4
  %157 = call ptr @ir_get_temp_name(i32 %156)
  %158 = call i32 @ir_load_ptr(ptr %155, ptr %157)
  %159 = call ptr @ir_get_temp_name(i32 %158)
  ret ptr %159

label_1354:                                       ; preds = %label_1351
  %160 = load ptr, ptr %object_node.637, align 8
  %161 = getelementptr inbounds nuw %ASTNode, ptr %160, i32 0, i32 1
  %162 = load ptr, ptr %161, align 8
  %163 = load ptr, ptr %expr.626, align 8
  %164 = getelementptr inbounds nuw %ASTNode, ptr %163, i32 0, i32 1
  %165 = load ptr, ptr %164, align 8
  %166 = call i32 @ir_get_enum_variant(ptr %162, ptr %165)
  store i32 %166, ptr %enum_val.638, align 4
  %167 = load i32, ptr %enum_val.638, align 4
  %168 = icmp sge i32 %167, 0
  br i1 %168, label %label_1357, label %label_1359

label_1359:                                       ; preds = %label_1354
  br label %label_1356

label_1357:                                       ; preds = %label_1354
  %169 = load i32, ptr %enum_val.638, align 4
  %170 = call ptr @int_to_str(i32 %169)
  ret ptr %170

label_1362:                                       ; preds = %label_1353
  %171 = load ptr, ptr %expr.626, align 8
  %172 = getelementptr inbounds nuw %ASTNode, ptr %171, i32 0, i32 0
  %173 = load i32, ptr %172, align 4
  %174 = icmp eq i32 %173, 26
  br i1 %174, label %label_1372, label %label_1374

label_1360:                                       ; preds = %label_1353
  %175 = load ptr, ptr %expr.626, align 8
  %176 = getelementptr inbounds nuw %ASTNode, ptr %175, i32 0, i32 5
  %177 = load ptr, ptr %176, align 8
  %178 = call i32 @count_list_nodes__String(ptr %177)
  store i32 %178, ptr %elem_count.645, align 4
  %179 = load ptr, ptr %expr.626, align 8
  %180 = getelementptr inbounds nuw %ASTNode, ptr %179, i32 0, i32 5
  %181 = load ptr, ptr %180, align 8
  %182 = call ptr @ptr_to_node(ptr %181)
  store ptr %182, ptr %first_elem.646, align 8
  %183 = load ptr, ptr %expr.626, align 8
  %184 = call ptr @node_get_type__Struct_ASTNode(ptr %183)
  store ptr %184, ptr %arr_t.647, align 8
  store ptr @.str.s538, ptr %elem_type.648, align 8
  %185 = load ptr, ptr %arr_t.647, align 8
  %186 = getelementptr inbounds nuw %TypeInfo, ptr %185, i32 0, i32 3
  %187 = load ptr, ptr %186, align 8
  %188 = call i32 @str_equals(ptr %187, ptr @.str.s539)
  %189 = icmp eq i32 %188, 0
  br i1 %189, label %label_1363, label %label_1364

label_1364:                                       ; preds = %label_1360
  %190 = load ptr, ptr %first_elem.646, align 8
  %191 = getelementptr inbounds nuw %ASTNode, ptr %190, i32 0, i32 0
  %192 = load i32, ptr %191, align 4
  %193 = icmp eq i32 %192, 27
  br i1 %193, label %label_1366, label %label_1368

label_1363:                                       ; preds = %label_1360
  %194 = load ptr, ptr %arr_t.647, align 8
  %195 = getelementptr inbounds nuw %TypeInfo, ptr %194, i32 0, i32 3
  %196 = load ptr, ptr %195, align 8
  %197 = call ptr @ptr_to_type(ptr %196)
  %198 = call ptr @type_ir_key__Struct_TypeInfo(ptr %197)
  %199 = call ptr @storage_type__String(ptr %198)
  store ptr %199, ptr %elem_type.648, align 8
  br label %label_1365

label_1365:                                       ; preds = %label_1368, %label_1363
  %200 = load ptr, ptr %elem_type.648, align 8
  %201 = load i32, ptr %elem_count.645, align 4
  %202 = call i32 @ir_array_alloca(ptr %200, i32 %201)
  %203 = call ptr @ir_get_temp_name(i32 %202)
  store ptr %203, ptr %base.649, align 8
  %204 = load ptr, ptr %expr.626, align 8
  %205 = getelementptr inbounds nuw %ASTNode, ptr %204, i32 0, i32 5
  %206 = load ptr, ptr %205, align 8
  store ptr %206, ptr %elem_ptr.650, align 8
  store i32 0, ptr %elem_index.651, align 4
  br label %label_1369

label_1368:                                       ; preds = %label_1366, %label_1364
  br label %label_1365

label_1366:                                       ; preds = %label_1364
  store ptr @.str.s540, ptr %elem_type.648, align 8
  br label %label_1368

label_1369:                                       ; preds = %label_1370, %label_1365
  %207 = load ptr, ptr %elem_ptr.650, align 8
  %208 = call i32 @str_equals(ptr %207, ptr @.str.s541)
  %209 = icmp eq i32 %208, 0
  br i1 %209, label %label_1370, label %label_1371

label_1371:                                       ; preds = %label_1369
  %210 = load ptr, ptr %base.649, align 8
  ret ptr %210

label_1370:                                       ; preds = %label_1369
  %211 = load ptr, ptr %elem_ptr.650, align 8
  %212 = call ptr @ptr_to_node(ptr %211)
  store ptr %212, ptr %elem_node.652, align 8
  %213 = load ptr, ptr %elem_node.652, align 8
  %214 = call ptr @generate_expression__Struct_ASTNode(ptr %213)
  store ptr %214, ptr %elem_val.653, align 8
  %215 = load ptr, ptr %elem_type.648, align 8
  %216 = load ptr, ptr %base.649, align 8
  %217 = load i32, ptr %elem_index.651, align 4
  %218 = call ptr @int_to_str(i32 %217)
  %219 = call i32 @ir_elem_ptr(ptr %215, ptr %216, ptr %218)
  store i32 %219, ptr %slot.654, align 4
  %220 = load ptr, ptr %elem_type.648, align 8
  %221 = load ptr, ptr %elem_val.653, align 8
  %222 = load i32, ptr %slot.654, align 4
  %223 = call ptr @ir_get_temp_name(i32 %222)
  call void @ir_store_ptr(ptr %220, ptr %221, ptr %223)
  %224 = load i32, ptr %elem_index.651, align 4
  %225 = add i32 %224, 1
  store i32 %225, ptr %elem_index.651, align 4
  %226 = load ptr, ptr %elem_node.652, align 8
  %227 = getelementptr inbounds nuw %ASTNode, ptr %226, i32 0, i32 8
  %228 = load ptr, ptr %227, align 8
  store ptr %228, ptr %elem_ptr.650, align 8
  br label %label_1369

label_1374:                                       ; preds = %label_1362
  %229 = load ptr, ptr %expr.626, align 8
  %230 = getelementptr inbounds nuw %ASTNode, ptr %229, i32 0, i32 0
  %231 = load i32, ptr %230, align 4
  %232 = icmp eq i32 %231, 29
  br i1 %232, label %label_1378, label %label_1380

label_1372:                                       ; preds = %label_1362
  %233 = load ptr, ptr %expr.626, align 8
  %234 = getelementptr inbounds nuw %ASTNode, ptr %233, i32 0, i32 5
  %235 = load ptr, ptr %234, align 8
  %236 = call ptr @ptr_to_node(ptr %235)
  %237 = call ptr @generate_expression__Struct_ASTNode(ptr %236)
  store ptr %237, ptr %array_val.655, align 8
  %238 = load ptr, ptr %expr.626, align 8
  %239 = getelementptr inbounds nuw %ASTNode, ptr %238, i32 0, i32 6
  %240 = load ptr, ptr %239, align 8
  %241 = call ptr @ptr_to_node(ptr %240)
  %242 = call ptr @generate_expression__Struct_ASTNode(ptr %241)
  store ptr %242, ptr %index_val.656, align 8
  %243 = load ptr, ptr %expr.626, align 8
  %244 = call ptr @get_expr_type__Struct_ASTNode(ptr %243)
  %245 = call ptr @storage_type__String(ptr %244)
  store ptr %245, ptr %elem_type.657, align 8
  %246 = load ptr, ptr %elem_type.657, align 8
  %247 = call i32 @str_equals(ptr %246, ptr @.str.s542)
  %248 = icmp eq i32 %247, 1
  br i1 %248, label %label_1375, label %label_1377

label_1377:                                       ; preds = %label_1375, %label_1372
  %249 = load ptr, ptr %elem_type.657, align 8
  %250 = load ptr, ptr %array_val.655, align 8
  %251 = load ptr, ptr %index_val.656, align 8
  %252 = call i32 @ir_elem_ptr(ptr %249, ptr %250, ptr %251)
  store i32 %252, ptr %slot.658, align 4
  %253 = load ptr, ptr %elem_type.657, align 8
  %254 = load i32, ptr %slot.658, align 4
  %255 = call ptr @ir_get_temp_name(i32 %254)
  %256 = call i32 @ir_load_ptr(ptr %253, ptr %255)
  %257 = call ptr @ir_get_temp_name(i32 %256)
  ret ptr %257

label_1375:                                       ; preds = %label_1372
  store ptr @.str.s543, ptr %elem_type.657, align 8
  br label %label_1377

label_1380:                                       ; preds = %label_1374
  %258 = load ptr, ptr %expr.626, align 8
  %259 = getelementptr inbounds nuw %ASTNode, ptr %258, i32 0, i32 0
  %260 = load i32, ptr %259, align 4
  %261 = icmp eq i32 %260, 21
  br i1 %261, label %label_1406, label %label_1408

label_1378:                                       ; preds = %label_1374
  %262 = load ptr, ptr %expr.626, align 8
  %263 = getelementptr inbounds nuw %ASTNode, ptr %262, i32 0, i32 5
  %264 = load ptr, ptr %263, align 8
  %265 = call ptr @ptr_to_node(ptr %264)
  store ptr %265, ptr %source.659, align 8
  %266 = load ptr, ptr %source.659, align 8
  %267 = call ptr @generate_expression__Struct_ASTNode(ptr %266)
  store ptr %267, ptr %val.660, align 8
  %268 = load ptr, ptr %source.659, align 8
  %269 = call ptr @node_get_type__Struct_ASTNode(ptr %268)
  store ptr %269, ptr %from_t.661, align 8
  %270 = load ptr, ptr %expr.626, align 8
  %271 = call ptr @node_get_type__Struct_ASTNode(ptr %270)
  store ptr %271, ptr %to_t.662, align 8
  %272 = load ptr, ptr %from_t.661, align 8
  %273 = call ptr @type_ir_key__Struct_TypeInfo(ptr %272)
  store ptr %273, ptr %from_key.663, align 8
  %274 = load ptr, ptr %to_t.662, align 8
  %275 = call ptr @type_ir_key__Struct_TypeInfo(ptr %274)
  store ptr %275, ptr %to_key.664, align 8
  %276 = load ptr, ptr %from_key.663, align 8
  %277 = load ptr, ptr %to_key.664, align 8
  %278 = call i32 @str_equals(ptr %276, ptr %277)
  %279 = icmp eq i32 %278, 1
  br i1 %279, label %label_1381, label %label_1383

label_1383:                                       ; preds = %label_1378
  %280 = load ptr, ptr %to_key.664, align 8
  %281 = call i32 @str_equals(ptr %280, ptr @.str.s544)
  %282 = icmp eq i32 %281, 1
  br i1 %282, label %label_1384, label %label_1386

label_1381:                                       ; preds = %label_1378
  %283 = load ptr, ptr %val.660, align 8
  ret ptr %283

label_1386:                                       ; preds = %label_1383
  %284 = load ptr, ptr %from_key.663, align 8
  %285 = call i32 @str_equals(ptr %284, ptr @.str.s545)
  %286 = icmp eq i32 %285, 1
  br i1 %286, label %label_1390, label %label_1392

label_1384:                                       ; preds = %label_1383
  %287 = load ptr, ptr %from_t.661, align 8
  %288 = call i1 @type_int_is_unsigned__Struct_TypeInfo(ptr %287)
  br i1 %288, label %label_1387, label %label_1389

label_1389:                                       ; preds = %label_1384
  %289 = load ptr, ptr %from_key.663, align 8
  %290 = load ptr, ptr %val.660, align 8
  %291 = load ptr, ptr %to_key.664, align 8
  %292 = call i32 @ir_sitofp(ptr %289, ptr %290, ptr %291)
  %293 = call ptr @ir_get_temp_name(i32 %292)
  ret ptr %293

label_1387:                                       ; preds = %label_1384
  %294 = load ptr, ptr %from_key.663, align 8
  %295 = load ptr, ptr %val.660, align 8
  %296 = load ptr, ptr %to_key.664, align 8
  %297 = call i32 @ir_uitofp(ptr %294, ptr %295, ptr %296)
  %298 = call ptr @ir_get_temp_name(i32 %297)
  ret ptr %298

label_1392:                                       ; preds = %label_1386
  %299 = load ptr, ptr %from_t.661, align 8
  %300 = call i32 @type_int_bits__Struct_TypeInfo(ptr %299)
  %301 = load ptr, ptr %to_t.662, align 8
  %302 = call i32 @type_int_bits__Struct_TypeInfo(ptr %301)
  %303 = icmp sgt i32 %300, %302
  br i1 %303, label %label_1396, label %label_1398

label_1390:                                       ; preds = %label_1386
  %304 = load ptr, ptr %to_t.662, align 8
  %305 = call i1 @type_int_is_unsigned__Struct_TypeInfo(ptr %304)
  br i1 %305, label %label_1393, label %label_1395

label_1395:                                       ; preds = %label_1390
  %306 = load ptr, ptr %from_key.663, align 8
  %307 = load ptr, ptr %val.660, align 8
  %308 = load ptr, ptr %to_key.664, align 8
  %309 = call i32 @ir_fptosi(ptr %306, ptr %307, ptr %308)
  %310 = call ptr @ir_get_temp_name(i32 %309)
  ret ptr %310

label_1393:                                       ; preds = %label_1390
  %311 = load ptr, ptr %from_key.663, align 8
  %312 = load ptr, ptr %val.660, align 8
  %313 = load ptr, ptr %to_key.664, align 8
  %314 = call i32 @ir_fptoui(ptr %311, ptr %312, ptr %313)
  %315 = call ptr @ir_get_temp_name(i32 %314)
  ret ptr %315

label_1398:                                       ; preds = %label_1392
  %316 = load ptr, ptr %from_t.661, align 8
  %317 = call i1 @type_int_is_unsigned__Struct_TypeInfo(ptr %316)
  store i1 %317, ptr %sc.87, align 1
  br i1 %317, label %label_1402, label %label_1401

label_1396:                                       ; preds = %label_1392
  %318 = load ptr, ptr %from_key.663, align 8
  %319 = load ptr, ptr %val.660, align 8
  %320 = load ptr, ptr %to_key.664, align 8
  %321 = call i32 @ir_trunc(ptr %318, ptr %319, ptr %320)
  %322 = call ptr @ir_get_temp_name(i32 %321)
  ret ptr %322

label_1401:                                       ; preds = %label_1398
  %323 = load ptr, ptr %from_t.661, align 8
  %324 = getelementptr inbounds nuw %TypeInfo, ptr %323, i32 0, i32 0
  %325 = load i32, ptr %324, align 4
  %326 = icmp eq i32 %325, 5
  store i1 %326, ptr %sc.87, align 1
  br label %label_1402

label_1402:                                       ; preds = %label_1401, %label_1398
  %327 = load i1, ptr %sc.87, align 1
  store i1 %327, ptr %sc.86, align 1
  br i1 %327, label %label_1400, label %label_1399

label_1399:                                       ; preds = %label_1402
  %328 = load ptr, ptr %from_t.661, align 8
  %329 = getelementptr inbounds nuw %TypeInfo, ptr %328, i32 0, i32 0
  %330 = load i32, ptr %329, align 4
  %331 = icmp eq i32 %330, 4
  store i1 %331, ptr %sc.86, align 1
  br label %label_1400

label_1400:                                       ; preds = %label_1399, %label_1402
  %332 = load i1, ptr %sc.86, align 1
  store i1 %332, ptr %zero_extend.665, align 1
  %333 = load i1, ptr %zero_extend.665, align 1
  br i1 %333, label %label_1403, label %label_1405

label_1405:                                       ; preds = %label_1400
  %334 = load ptr, ptr %from_key.663, align 8
  %335 = load ptr, ptr %val.660, align 8
  %336 = load ptr, ptr %to_key.664, align 8
  %337 = call i32 @ir_sext(ptr %334, ptr %335, ptr %336)
  %338 = call ptr @ir_get_temp_name(i32 %337)
  ret ptr %338

label_1403:                                       ; preds = %label_1400
  %339 = load ptr, ptr %from_key.663, align 8
  %340 = load ptr, ptr %val.660, align 8
  %341 = load ptr, ptr %to_key.664, align 8
  %342 = call i32 @ir_zext(ptr %339, ptr %340, ptr %341)
  %343 = call ptr @ir_get_temp_name(i32 %342)
  ret ptr %343

label_1408:                                       ; preds = %label_1417, %label_1380
  %344 = load ptr, ptr %expr.626, align 8
  %345 = getelementptr inbounds nuw %ASTNode, ptr %344, i32 0, i32 0
  %346 = load i32, ptr %345, align 4
  %347 = icmp eq i32 %346, 20
  br i1 %347, label %label_1421, label %label_1423

label_1406:                                       ; preds = %label_1380
  %348 = load ptr, ptr %expr.626, align 8
  %349 = getelementptr inbounds nuw %ASTNode, ptr %348, i32 0, i32 5
  %350 = load ptr, ptr %349, align 8
  %351 = call ptr @ptr_to_node(ptr %350)
  store ptr %351, ptr %operand_node.666, align 8
  %352 = load ptr, ptr %operand_node.666, align 8
  %353 = call ptr @generate_expression__Struct_ASTNode(ptr %352)
  store ptr %353, ptr %operand_val.667, align 8
  %354 = load ptr, ptr %expr.626, align 8
  %355 = getelementptr inbounds nuw %ASTNode, ptr %354, i32 0, i32 1
  %356 = load ptr, ptr %355, align 8
  store ptr %356, ptr %uop.668, align 8
  %357 = load ptr, ptr %uop.668, align 8
  %358 = call i32 @str_equals(ptr %357, ptr @.str.s546)
  %359 = icmp eq i32 %358, 1
  br i1 %359, label %label_1409, label %label_1411

label_1411:                                       ; preds = %label_1406
  %360 = load ptr, ptr %uop.668, align 8
  %361 = call i32 @str_equals(ptr %360, ptr @.str.s549)
  %362 = icmp eq i32 %361, 1
  br i1 %362, label %label_1412, label %label_1414

label_1409:                                       ; preds = %label_1406
  %363 = load ptr, ptr %operand_val.667, align 8
  %364 = call i32 @ir_icmp_eq(ptr @.str.s547, ptr %363, ptr @.str.s548)
  store i32 %364, ptr %not_id.669, align 4
  %365 = load i32, ptr %not_id.669, align 4
  %366 = call ptr @ir_get_temp_name(i32 %365)
  ret ptr %366

label_1414:                                       ; preds = %label_1411
  %367 = load ptr, ptr %uop.668, align 8
  %368 = call i32 @str_equals(ptr %367, ptr @.str.s550)
  %369 = icmp eq i32 %368, 1
  br i1 %369, label %label_1415, label %label_1417

label_1412:                                       ; preds = %label_1411
  %370 = load ptr, ptr %operand_node.666, align 8
  %371 = call ptr @get_expr_type__Struct_ASTNode(ptr %370)
  store ptr %371, ptr %int_type.670, align 8
  %372 = load ptr, ptr %int_type.670, align 8
  %373 = load ptr, ptr %operand_val.667, align 8
  %374 = call i32 @ir_not(ptr %372, ptr %373)
  %375 = call ptr @ir_get_temp_name(i32 %374)
  ret ptr %375

label_1417:                                       ; preds = %label_1414
  br label %label_1408

label_1415:                                       ; preds = %label_1414
  %376 = load ptr, ptr %operand_node.666, align 8
  %377 = call ptr @get_expr_type__Struct_ASTNode(ptr %376)
  store ptr %377, ptr %operand_type.671, align 8
  %378 = load ptr, ptr %operand_type.671, align 8
  %379 = call i32 @str_equals(ptr %378, ptr @.str.s551)
  %380 = icmp eq i32 %379, 1
  br i1 %380, label %label_1418, label %label_1420

label_1420:                                       ; preds = %label_1415
  %381 = load ptr, ptr %operand_type.671, align 8
  %382 = load ptr, ptr %operand_val.667, align 8
  %383 = call i32 @ir_neg(ptr %381, ptr %382)
  store i32 %383, ptr %neg_id.673, align 4
  %384 = load i32, ptr %neg_id.673, align 4
  %385 = call ptr @ir_get_temp_name(i32 %384)
  ret ptr %385

label_1418:                                       ; preds = %label_1415
  %386 = load ptr, ptr %operand_val.667, align 8
  %387 = call i32 @ir_fsub(ptr @.str.s552, ptr @.str.s553, ptr %386)
  store i32 %387, ptr %fneg_id.672, align 4
  %388 = load i32, ptr %fneg_id.672, align 4
  %389 = call ptr @ir_get_temp_name(i32 %388)
  ret ptr %389

label_1423:                                       ; preds = %label_1408
  %390 = load ptr, ptr %expr.626, align 8
  %391 = getelementptr inbounds nuw %ASTNode, ptr %390, i32 0, i32 0
  %392 = load i32, ptr %391, align 4
  %393 = icmp eq i32 %392, 24
  br i1 %393, label %label_1537, label %label_1539

label_1421:                                       ; preds = %label_1408
  %394 = load ptr, ptr %expr.626, align 8
  %395 = getelementptr inbounds nuw %ASTNode, ptr %394, i32 0, i32 1
  %396 = load ptr, ptr %395, align 8
  %397 = call i32 @str_equals(ptr %396, ptr @.str.s554)
  %398 = icmp eq i32 %397, 1
  store i1 %398, ptr %sc.88, align 1
  br i1 %398, label %label_1425, label %label_1424

label_1424:                                       ; preds = %label_1421
  %399 = load ptr, ptr %expr.626, align 8
  %400 = getelementptr inbounds nuw %ASTNode, ptr %399, i32 0, i32 1
  %401 = load ptr, ptr %400, align 8
  %402 = call i32 @str_equals(ptr %401, ptr @.str.s555)
  %403 = icmp eq i32 %402, 1
  store i1 %403, ptr %sc.88, align 1
  br label %label_1425

label_1425:                                       ; preds = %label_1424, %label_1421
  %404 = load i1, ptr %sc.88, align 1
  br i1 %404, label %label_1426, label %label_1428

label_1428:                                       ; preds = %label_1425
  %405 = load ptr, ptr %expr.626, align 8
  %406 = getelementptr inbounds nuw %ASTNode, ptr %405, i32 0, i32 5
  %407 = load ptr, ptr %406, align 8
  %408 = call ptr @ptr_to_node(ptr %407)
  %409 = call ptr @generate_expression__Struct_ASTNode(ptr %408)
  store ptr %409, ptr %left_val.674, align 8
  %410 = load ptr, ptr %expr.626, align 8
  %411 = getelementptr inbounds nuw %ASTNode, ptr %410, i32 0, i32 6
  %412 = load ptr, ptr %411, align 8
  %413 = call ptr @ptr_to_node(ptr %412)
  %414 = call ptr @generate_expression__Struct_ASTNode(ptr %413)
  store ptr %414, ptr %right_val.675, align 8
  %415 = load ptr, ptr %expr.626, align 8
  %416 = getelementptr inbounds nuw %ASTNode, ptr %415, i32 0, i32 1
  %417 = load ptr, ptr %416, align 8
  store ptr %417, ptr %op.676, align 8
  store i32 0, ptr %temp_id.677, align 4
  %418 = load ptr, ptr %expr.626, align 8
  %419 = getelementptr inbounds nuw %ASTNode, ptr %418, i32 0, i32 5
  %420 = load ptr, ptr %419, align 8
  %421 = call ptr @ptr_to_node(ptr %420)
  store ptr %421, ptr %left_node.678, align 8
  %422 = load ptr, ptr %left_node.678, align 8
  %423 = call ptr @get_expr_type__Struct_ASTNode(ptr %422)
  store ptr %423, ptr %op_type.679, align 8
  store i1 false, ptr %is_unsigned.680, align 1
  %424 = load ptr, ptr %left_node.678, align 8
  %425 = call i1 @node_has_type__Struct_ASTNode(ptr %424)
  br i1 %425, label %label_1429, label %label_1431

label_1426:                                       ; preds = %label_1425
  %426 = load ptr, ptr %expr.626, align 8
  %427 = call ptr @generate_short_circuit__Struct_ASTNode(ptr %426)
  ret ptr %427

label_1431:                                       ; preds = %label_1429, %label_1428
  %428 = load ptr, ptr %op_type.679, align 8
  %429 = call i32 @str_equals(ptr %428, ptr @.str.s556)
  %430 = icmp eq i32 %429, 1
  br i1 %430, label %label_1432, label %label_1433

label_1429:                                       ; preds = %label_1428
  %431 = load ptr, ptr %left_node.678, align 8
  %432 = call ptr @node_get_type__Struct_ASTNode(ptr %431)
  %433 = call i1 @type_int_is_unsigned__Struct_TypeInfo(ptr %432)
  store i1 %433, ptr %is_unsigned.680, align 1
  br label %label_1431

label_1433:                                       ; preds = %label_1431
  %434 = load ptr, ptr %op.676, align 8
  %435 = call i32 @str_equals(ptr %434, ptr @.str.s567)
  %436 = icmp eq i32 %435, 1
  br i1 %436, label %label_1465, label %label_1467

label_1432:                                       ; preds = %label_1431
  %437 = load ptr, ptr %op.676, align 8
  %438 = call i32 @str_equals(ptr %437, ptr @.str.s557)
  %439 = icmp eq i32 %438, 1
  br i1 %439, label %label_1435, label %label_1437

label_1437:                                       ; preds = %label_1435, %label_1432
  %440 = load ptr, ptr %op.676, align 8
  %441 = call i32 @str_equals(ptr %440, ptr @.str.s558)
  %442 = icmp eq i32 %441, 1
  br i1 %442, label %label_1438, label %label_1440

label_1435:                                       ; preds = %label_1432
  %443 = load ptr, ptr %op_type.679, align 8
  %444 = load ptr, ptr %left_val.674, align 8
  %445 = load ptr, ptr %right_val.675, align 8
  %446 = call i32 @ir_fadd(ptr %443, ptr %444, ptr %445)
  store i32 %446, ptr %temp_id.677, align 4
  br label %label_1437

label_1440:                                       ; preds = %label_1438, %label_1437
  %447 = load ptr, ptr %op.676, align 8
  %448 = call i32 @str_equals(ptr %447, ptr @.str.s559)
  %449 = icmp eq i32 %448, 1
  br i1 %449, label %label_1441, label %label_1443

label_1438:                                       ; preds = %label_1437
  %450 = load ptr, ptr %op_type.679, align 8
  %451 = load ptr, ptr %left_val.674, align 8
  %452 = load ptr, ptr %right_val.675, align 8
  %453 = call i32 @ir_fsub(ptr %450, ptr %451, ptr %452)
  store i32 %453, ptr %temp_id.677, align 4
  br label %label_1440

label_1443:                                       ; preds = %label_1441, %label_1440
  %454 = load ptr, ptr %op.676, align 8
  %455 = call i32 @str_equals(ptr %454, ptr @.str.s560)
  %456 = icmp eq i32 %455, 1
  br i1 %456, label %label_1444, label %label_1446

label_1441:                                       ; preds = %label_1440
  %457 = load ptr, ptr %op_type.679, align 8
  %458 = load ptr, ptr %left_val.674, align 8
  %459 = load ptr, ptr %right_val.675, align 8
  %460 = call i32 @ir_fmul(ptr %457, ptr %458, ptr %459)
  store i32 %460, ptr %temp_id.677, align 4
  br label %label_1443

label_1446:                                       ; preds = %label_1444, %label_1443
  %461 = load ptr, ptr %op.676, align 8
  %462 = call i32 @str_equals(ptr %461, ptr @.str.s561)
  %463 = icmp eq i32 %462, 1
  br i1 %463, label %label_1447, label %label_1449

label_1444:                                       ; preds = %label_1443
  %464 = load ptr, ptr %op_type.679, align 8
  %465 = load ptr, ptr %left_val.674, align 8
  %466 = load ptr, ptr %right_val.675, align 8
  %467 = call i32 @ir_fdiv(ptr %464, ptr %465, ptr %466)
  store i32 %467, ptr %temp_id.677, align 4
  br label %label_1446

label_1449:                                       ; preds = %label_1447, %label_1446
  %468 = load ptr, ptr %op.676, align 8
  %469 = call i32 @str_equals(ptr %468, ptr @.str.s562)
  %470 = icmp eq i32 %469, 1
  br i1 %470, label %label_1450, label %label_1452

label_1447:                                       ; preds = %label_1446
  %471 = load ptr, ptr %op_type.679, align 8
  %472 = load ptr, ptr %left_val.674, align 8
  %473 = load ptr, ptr %right_val.675, align 8
  %474 = call i32 @ir_fcmp_oeq(ptr %471, ptr %472, ptr %473)
  store i32 %474, ptr %temp_id.677, align 4
  br label %label_1449

label_1452:                                       ; preds = %label_1450, %label_1449
  %475 = load ptr, ptr %op.676, align 8
  %476 = call i32 @str_equals(ptr %475, ptr @.str.s563)
  %477 = icmp eq i32 %476, 1
  br i1 %477, label %label_1453, label %label_1455

label_1450:                                       ; preds = %label_1449
  %478 = load ptr, ptr %op_type.679, align 8
  %479 = load ptr, ptr %left_val.674, align 8
  %480 = load ptr, ptr %right_val.675, align 8
  %481 = call i32 @ir_fcmp_one(ptr %478, ptr %479, ptr %480)
  store i32 %481, ptr %temp_id.677, align 4
  br label %label_1452

label_1455:                                       ; preds = %label_1453, %label_1452
  %482 = load ptr, ptr %op.676, align 8
  %483 = call i32 @str_equals(ptr %482, ptr @.str.s564)
  %484 = icmp eq i32 %483, 1
  br i1 %484, label %label_1456, label %label_1458

label_1453:                                       ; preds = %label_1452
  %485 = load ptr, ptr %op_type.679, align 8
  %486 = load ptr, ptr %left_val.674, align 8
  %487 = load ptr, ptr %right_val.675, align 8
  %488 = call i32 @ir_fcmp_olt(ptr %485, ptr %486, ptr %487)
  store i32 %488, ptr %temp_id.677, align 4
  br label %label_1455

label_1458:                                       ; preds = %label_1456, %label_1455
  %489 = load ptr, ptr %op.676, align 8
  %490 = call i32 @str_equals(ptr %489, ptr @.str.s565)
  %491 = icmp eq i32 %490, 1
  br i1 %491, label %label_1459, label %label_1461

label_1456:                                       ; preds = %label_1455
  %492 = load ptr, ptr %op_type.679, align 8
  %493 = load ptr, ptr %left_val.674, align 8
  %494 = load ptr, ptr %right_val.675, align 8
  %495 = call i32 @ir_fcmp_ole(ptr %492, ptr %493, ptr %494)
  store i32 %495, ptr %temp_id.677, align 4
  br label %label_1458

label_1461:                                       ; preds = %label_1459, %label_1458
  %496 = load ptr, ptr %op.676, align 8
  %497 = call i32 @str_equals(ptr %496, ptr @.str.s566)
  %498 = icmp eq i32 %497, 1
  br i1 %498, label %label_1462, label %label_1464

label_1459:                                       ; preds = %label_1458
  %499 = load ptr, ptr %op_type.679, align 8
  %500 = load ptr, ptr %left_val.674, align 8
  %501 = load ptr, ptr %right_val.675, align 8
  %502 = call i32 @ir_fcmp_ogt(ptr %499, ptr %500, ptr %501)
  store i32 %502, ptr %temp_id.677, align 4
  br label %label_1461

label_1464:                                       ; preds = %label_1462, %label_1461
  br label %label_1434

label_1462:                                       ; preds = %label_1461
  %503 = load ptr, ptr %op_type.679, align 8
  %504 = load ptr, ptr %left_val.674, align 8
  %505 = load ptr, ptr %right_val.675, align 8
  %506 = call i32 @ir_fcmp_oge(ptr %503, ptr %504, ptr %505)
  store i32 %506, ptr %temp_id.677, align 4
  br label %label_1464

label_1434:                                       ; preds = %label_1482, %label_1464
  %507 = load ptr, ptr %op.676, align 8
  %508 = call i32 @str_equals(ptr %507, ptr @.str.s582)
  %509 = icmp eq i32 %508, 1
  br i1 %509, label %label_1513, label %label_1515

label_1467:                                       ; preds = %label_1465, %label_1433
  %510 = load ptr, ptr %op.676, align 8
  %511 = call i32 @str_equals(ptr %510, ptr @.str.s568)
  %512 = icmp eq i32 %511, 1
  br i1 %512, label %label_1468, label %label_1470

label_1465:                                       ; preds = %label_1433
  %513 = load ptr, ptr %op_type.679, align 8
  %514 = load ptr, ptr %left_val.674, align 8
  %515 = load ptr, ptr %right_val.675, align 8
  %516 = call i32 @ir_add(ptr %513, ptr %514, ptr %515)
  store i32 %516, ptr %temp_id.677, align 4
  br label %label_1467

label_1470:                                       ; preds = %label_1468, %label_1467
  %517 = load ptr, ptr %op.676, align 8
  %518 = call i32 @str_equals(ptr %517, ptr @.str.s569)
  %519 = icmp eq i32 %518, 1
  br i1 %519, label %label_1471, label %label_1473

label_1468:                                       ; preds = %label_1467
  %520 = load ptr, ptr %op_type.679, align 8
  %521 = load ptr, ptr %left_val.674, align 8
  %522 = load ptr, ptr %right_val.675, align 8
  %523 = call i32 @ir_sub(ptr %520, ptr %521, ptr %522)
  store i32 %523, ptr %temp_id.677, align 4
  br label %label_1470

label_1473:                                       ; preds = %label_1471, %label_1470
  %524 = load ptr, ptr %op.676, align 8
  %525 = call i32 @str_equals(ptr %524, ptr @.str.s570)
  %526 = icmp eq i32 %525, 1
  br i1 %526, label %label_1474, label %label_1476

label_1471:                                       ; preds = %label_1470
  %527 = load ptr, ptr %op_type.679, align 8
  %528 = load ptr, ptr %left_val.674, align 8
  %529 = load ptr, ptr %right_val.675, align 8
  %530 = call i32 @ir_mul(ptr %527, ptr %528, ptr %529)
  store i32 %530, ptr %temp_id.677, align 4
  br label %label_1473

label_1476:                                       ; preds = %label_1474, %label_1473
  %531 = load ptr, ptr %op.676, align 8
  %532 = call i32 @str_equals(ptr %531, ptr @.str.s571)
  %533 = icmp eq i32 %532, 1
  br i1 %533, label %label_1477, label %label_1479

label_1474:                                       ; preds = %label_1473
  %534 = load ptr, ptr %op_type.679, align 8
  %535 = load ptr, ptr %left_val.674, align 8
  %536 = load ptr, ptr %right_val.675, align 8
  %537 = call i32 @ir_icmp_eq(ptr %534, ptr %535, ptr %536)
  store i32 %537, ptr %temp_id.677, align 4
  br label %label_1476

label_1479:                                       ; preds = %label_1477, %label_1476
  %538 = load i1, ptr %is_unsigned.680, align 1
  br i1 %538, label %label_1480, label %label_1481

label_1477:                                       ; preds = %label_1476
  %539 = load ptr, ptr %op_type.679, align 8
  %540 = load ptr, ptr %left_val.674, align 8
  %541 = load ptr, ptr %right_val.675, align 8
  %542 = call i32 @ir_icmp_ne(ptr %539, ptr %540, ptr %541)
  store i32 %542, ptr %temp_id.677, align 4
  br label %label_1479

label_1481:                                       ; preds = %label_1479
  %543 = load ptr, ptr %op.676, align 8
  %544 = call i32 @str_equals(ptr %543, ptr @.str.s577)
  %545 = icmp eq i32 %544, 1
  br i1 %545, label %label_1498, label %label_1500

label_1480:                                       ; preds = %label_1479
  %546 = load ptr, ptr %op.676, align 8
  %547 = call i32 @str_equals(ptr %546, ptr @.str.s572)
  %548 = icmp eq i32 %547, 1
  br i1 %548, label %label_1483, label %label_1485

label_1485:                                       ; preds = %label_1483, %label_1480
  %549 = load ptr, ptr %op.676, align 8
  %550 = call i32 @str_equals(ptr %549, ptr @.str.s573)
  %551 = icmp eq i32 %550, 1
  br i1 %551, label %label_1486, label %label_1488

label_1483:                                       ; preds = %label_1480
  %552 = load ptr, ptr %op_type.679, align 8
  %553 = load ptr, ptr %left_val.674, align 8
  %554 = load ptr, ptr %right_val.675, align 8
  %555 = call i32 @ir_udiv(ptr %552, ptr %553, ptr %554)
  store i32 %555, ptr %temp_id.677, align 4
  br label %label_1485

label_1488:                                       ; preds = %label_1486, %label_1485
  %556 = load ptr, ptr %op.676, align 8
  %557 = call i32 @str_equals(ptr %556, ptr @.str.s574)
  %558 = icmp eq i32 %557, 1
  br i1 %558, label %label_1489, label %label_1491

label_1486:                                       ; preds = %label_1485
  %559 = load ptr, ptr %op_type.679, align 8
  %560 = load ptr, ptr %left_val.674, align 8
  %561 = load ptr, ptr %right_val.675, align 8
  %562 = call i32 @ir_icmp_ult(ptr %559, ptr %560, ptr %561)
  store i32 %562, ptr %temp_id.677, align 4
  br label %label_1488

label_1491:                                       ; preds = %label_1489, %label_1488
  %563 = load ptr, ptr %op.676, align 8
  %564 = call i32 @str_equals(ptr %563, ptr @.str.s575)
  %565 = icmp eq i32 %564, 1
  br i1 %565, label %label_1492, label %label_1494

label_1489:                                       ; preds = %label_1488
  %566 = load ptr, ptr %op_type.679, align 8
  %567 = load ptr, ptr %left_val.674, align 8
  %568 = load ptr, ptr %right_val.675, align 8
  %569 = call i32 @ir_icmp_ule(ptr %566, ptr %567, ptr %568)
  store i32 %569, ptr %temp_id.677, align 4
  br label %label_1491

label_1494:                                       ; preds = %label_1492, %label_1491
  %570 = load ptr, ptr %op.676, align 8
  %571 = call i32 @str_equals(ptr %570, ptr @.str.s576)
  %572 = icmp eq i32 %571, 1
  br i1 %572, label %label_1495, label %label_1497

label_1492:                                       ; preds = %label_1491
  %573 = load ptr, ptr %op_type.679, align 8
  %574 = load ptr, ptr %left_val.674, align 8
  %575 = load ptr, ptr %right_val.675, align 8
  %576 = call i32 @ir_icmp_ugt(ptr %573, ptr %574, ptr %575)
  store i32 %576, ptr %temp_id.677, align 4
  br label %label_1494

label_1497:                                       ; preds = %label_1495, %label_1494
  br label %label_1482

label_1495:                                       ; preds = %label_1494
  %577 = load ptr, ptr %op_type.679, align 8
  %578 = load ptr, ptr %left_val.674, align 8
  %579 = load ptr, ptr %right_val.675, align 8
  %580 = call i32 @ir_icmp_uge(ptr %577, ptr %578, ptr %579)
  store i32 %580, ptr %temp_id.677, align 4
  br label %label_1497

label_1482:                                       ; preds = %label_1512, %label_1497
  br label %label_1434

label_1500:                                       ; preds = %label_1498, %label_1481
  %581 = load ptr, ptr %op.676, align 8
  %582 = call i32 @str_equals(ptr %581, ptr @.str.s578)
  %583 = icmp eq i32 %582, 1
  br i1 %583, label %label_1501, label %label_1503

label_1498:                                       ; preds = %label_1481
  %584 = load ptr, ptr %op_type.679, align 8
  %585 = load ptr, ptr %left_val.674, align 8
  %586 = load ptr, ptr %right_val.675, align 8
  %587 = call i32 @ir_sdiv(ptr %584, ptr %585, ptr %586)
  store i32 %587, ptr %temp_id.677, align 4
  br label %label_1500

label_1503:                                       ; preds = %label_1501, %label_1500
  %588 = load ptr, ptr %op.676, align 8
  %589 = call i32 @str_equals(ptr %588, ptr @.str.s579)
  %590 = icmp eq i32 %589, 1
  br i1 %590, label %label_1504, label %label_1506

label_1501:                                       ; preds = %label_1500
  %591 = load ptr, ptr %op_type.679, align 8
  %592 = load ptr, ptr %left_val.674, align 8
  %593 = load ptr, ptr %right_val.675, align 8
  %594 = call i32 @ir_icmp_slt(ptr %591, ptr %592, ptr %593)
  store i32 %594, ptr %temp_id.677, align 4
  br label %label_1503

label_1506:                                       ; preds = %label_1504, %label_1503
  %595 = load ptr, ptr %op.676, align 8
  %596 = call i32 @str_equals(ptr %595, ptr @.str.s580)
  %597 = icmp eq i32 %596, 1
  br i1 %597, label %label_1507, label %label_1509

label_1504:                                       ; preds = %label_1503
  %598 = load ptr, ptr %op_type.679, align 8
  %599 = load ptr, ptr %left_val.674, align 8
  %600 = load ptr, ptr %right_val.675, align 8
  %601 = call i32 @ir_icmp_sle(ptr %598, ptr %599, ptr %600)
  store i32 %601, ptr %temp_id.677, align 4
  br label %label_1506

label_1509:                                       ; preds = %label_1507, %label_1506
  %602 = load ptr, ptr %op.676, align 8
  %603 = call i32 @str_equals(ptr %602, ptr @.str.s581)
  %604 = icmp eq i32 %603, 1
  br i1 %604, label %label_1510, label %label_1512

label_1507:                                       ; preds = %label_1506
  %605 = load ptr, ptr %op_type.679, align 8
  %606 = load ptr, ptr %left_val.674, align 8
  %607 = load ptr, ptr %right_val.675, align 8
  %608 = call i32 @ir_icmp_sgt(ptr %605, ptr %606, ptr %607)
  store i32 %608, ptr %temp_id.677, align 4
  br label %label_1509

label_1512:                                       ; preds = %label_1510, %label_1509
  br label %label_1482

label_1510:                                       ; preds = %label_1509
  %609 = load ptr, ptr %op_type.679, align 8
  %610 = load ptr, ptr %left_val.674, align 8
  %611 = load ptr, ptr %right_val.675, align 8
  %612 = call i32 @ir_icmp_sge(ptr %609, ptr %610, ptr %611)
  store i32 %612, ptr %temp_id.677, align 4
  br label %label_1512

label_1515:                                       ; preds = %label_1518, %label_1434
  %613 = load ptr, ptr %op.676, align 8
  %614 = call i32 @str_equals(ptr %613, ptr @.str.s583)
  %615 = icmp eq i32 %614, 1
  br i1 %615, label %label_1519, label %label_1521

label_1513:                                       ; preds = %label_1434
  %616 = load i1, ptr %is_unsigned.680, align 1
  br i1 %616, label %label_1516, label %label_1517

label_1517:                                       ; preds = %label_1513
  %617 = load ptr, ptr %op_type.679, align 8
  %618 = load ptr, ptr %left_val.674, align 8
  %619 = load ptr, ptr %right_val.675, align 8
  %620 = call i32 @ir_srem(ptr %617, ptr %618, ptr %619)
  store i32 %620, ptr %temp_id.677, align 4
  br label %label_1518

label_1516:                                       ; preds = %label_1513
  %621 = load ptr, ptr %op_type.679, align 8
  %622 = load ptr, ptr %left_val.674, align 8
  %623 = load ptr, ptr %right_val.675, align 8
  %624 = call i32 @ir_urem(ptr %621, ptr %622, ptr %623)
  store i32 %624, ptr %temp_id.677, align 4
  br label %label_1518

label_1518:                                       ; preds = %label_1517, %label_1516
  br label %label_1515

label_1521:                                       ; preds = %label_1519, %label_1515
  %625 = load ptr, ptr %op.676, align 8
  %626 = call i32 @str_equals(ptr %625, ptr @.str.s584)
  %627 = icmp eq i32 %626, 1
  br i1 %627, label %label_1522, label %label_1524

label_1519:                                       ; preds = %label_1515
  %628 = load ptr, ptr %op_type.679, align 8
  %629 = load ptr, ptr %left_val.674, align 8
  %630 = load ptr, ptr %right_val.675, align 8
  %631 = call i32 @ir_and(ptr %628, ptr %629, ptr %630)
  store i32 %631, ptr %temp_id.677, align 4
  br label %label_1521

label_1524:                                       ; preds = %label_1522, %label_1521
  %632 = load ptr, ptr %op.676, align 8
  %633 = call i32 @str_equals(ptr %632, ptr @.str.s585)
  %634 = icmp eq i32 %633, 1
  br i1 %634, label %label_1525, label %label_1527

label_1522:                                       ; preds = %label_1521
  %635 = load ptr, ptr %op_type.679, align 8
  %636 = load ptr, ptr %left_val.674, align 8
  %637 = load ptr, ptr %right_val.675, align 8
  %638 = call i32 @ir_or(ptr %635, ptr %636, ptr %637)
  store i32 %638, ptr %temp_id.677, align 4
  br label %label_1524

label_1527:                                       ; preds = %label_1525, %label_1524
  %639 = load ptr, ptr %op.676, align 8
  %640 = call i32 @str_equals(ptr %639, ptr @.str.s586)
  %641 = icmp eq i32 %640, 1
  br i1 %641, label %label_1528, label %label_1530

label_1525:                                       ; preds = %label_1524
  %642 = load ptr, ptr %op_type.679, align 8
  %643 = load ptr, ptr %left_val.674, align 8
  %644 = load ptr, ptr %right_val.675, align 8
  %645 = call i32 @ir_xor(ptr %642, ptr %643, ptr %644)
  store i32 %645, ptr %temp_id.677, align 4
  br label %label_1527

label_1530:                                       ; preds = %label_1528, %label_1527
  %646 = load ptr, ptr %op.676, align 8
  %647 = call i32 @str_equals(ptr %646, ptr @.str.s587)
  %648 = icmp eq i32 %647, 1
  br i1 %648, label %label_1531, label %label_1533

label_1528:                                       ; preds = %label_1527
  %649 = load ptr, ptr %op_type.679, align 8
  %650 = load ptr, ptr %left_val.674, align 8
  %651 = load ptr, ptr %right_val.675, align 8
  %652 = call i32 @ir_shl(ptr %649, ptr %650, ptr %651)
  store i32 %652, ptr %temp_id.677, align 4
  br label %label_1530

label_1533:                                       ; preds = %label_1536, %label_1530
  %653 = load i32, ptr %temp_id.677, align 4
  %654 = call ptr @ir_get_temp_name(i32 %653)
  ret ptr %654

label_1531:                                       ; preds = %label_1530
  %655 = load i1, ptr %is_unsigned.680, align 1
  br i1 %655, label %label_1534, label %label_1535

label_1535:                                       ; preds = %label_1531
  %656 = load ptr, ptr %op_type.679, align 8
  %657 = load ptr, ptr %left_val.674, align 8
  %658 = load ptr, ptr %right_val.675, align 8
  %659 = call i32 @ir_ashr(ptr %656, ptr %657, ptr %658)
  store i32 %659, ptr %temp_id.677, align 4
  br label %label_1536

label_1534:                                       ; preds = %label_1531
  %660 = load ptr, ptr %op_type.679, align 8
  %661 = load ptr, ptr %left_val.674, align 8
  %662 = load ptr, ptr %right_val.675, align 8
  %663 = call i32 @ir_lshr(ptr %660, ptr %661, ptr %662)
  store i32 %663, ptr %temp_id.677, align 4
  br label %label_1536

label_1536:                                       ; preds = %label_1535, %label_1534
  br label %label_1533

label_1539:                                       ; preds = %label_1423
  ret ptr @.str.s630

label_1537:                                       ; preds = %label_1423
  %664 = load ptr, ptr %expr.626, align 8
  %665 = getelementptr inbounds nuw %ASTNode, ptr %664, i32 0, i32 5
  %666 = load ptr, ptr %665, align 8
  %667 = call ptr @ptr_to_node(ptr %666)
  store ptr %667, ptr %callee.681, align 8
  %668 = load ptr, ptr %callee.681, align 8
  %669 = getelementptr inbounds nuw %ASTNode, ptr %668, i32 0, i32 1
  %670 = load ptr, ptr %669, align 8
  store ptr %670, ptr %func_name.682, align 8
  %671 = load ptr, ptr %func_name.682, align 8
  %672 = call i32 @str_equals(ptr %671, ptr @.str.s588)
  %673 = icmp eq i32 %672, 1
  br i1 %673, label %label_1540, label %label_1542

label_1542:                                       ; preds = %label_1537
  store i32 0, ptr %is_print_bool.685, align 4
  %674 = load ptr, ptr %func_name.682, align 8
  %675 = call i32 @str_equals(ptr %674, ptr @.str.s594)
  %676 = icmp eq i32 %675, 1
  br i1 %676, label %label_1546, label %label_1548

label_1540:                                       ; preds = %label_1537
  %677 = load ptr, ptr %expr.626, align 8
  %678 = getelementptr inbounds nuw %ASTNode, ptr %677, i32 0, i32 6
  %679 = load ptr, ptr %678, align 8
  store ptr %679, ptr %drop_arg.683, align 8
  %680 = load ptr, ptr %drop_arg.683, align 8
  %681 = call i32 @str_equals(ptr %680, ptr @.str.s589)
  %682 = icmp eq i32 %681, 0
  br i1 %682, label %label_1543, label %label_1545

label_1545:                                       ; preds = %label_1543, %label_1540
  ret ptr @.str.s593

label_1543:                                       ; preds = %label_1540
  %683 = load ptr, ptr %drop_arg.683, align 8
  %684 = call ptr @ptr_to_node(ptr %683)
  %685 = call ptr @generate_expression__Struct_ASTNode(ptr %684)
  store ptr %685, ptr %drop_val.684, align 8
  call void @ir_call_begin()
  %686 = load ptr, ptr %drop_val.684, align 8
  call void @ir_call_arg(ptr @.str.s590, ptr %686)
  %687 = call i32 @ir_call_end(ptr @.str.s591, ptr @.str.s592)
  br label %label_1545

label_1548:                                       ; preds = %label_1546, %label_1542
  %688 = load ptr, ptr %func_name.682, align 8
  %689 = call i32 @str_equals(ptr %688, ptr @.str.s595)
  %690 = icmp eq i32 %689, 1
  br i1 %690, label %label_1549, label %label_1551

label_1546:                                       ; preds = %label_1542
  store i32 1, ptr %is_print_bool.685, align 4
  br label %label_1548

label_1551:                                       ; preds = %label_1549, %label_1548
  %691 = load i32, ptr %is_print_bool.685, align 4
  %692 = icmp sgt i32 %691, 0
  br i1 %692, label %label_1552, label %label_1554

label_1549:                                       ; preds = %label_1548
  store i32 2, ptr %is_print_bool.685, align 4
  br label %label_1551

label_1554:                                       ; preds = %label_1551
  store i32 0, ptr %is_print.690, align 4
  %693 = load ptr, ptr %func_name.682, align 8
  %694 = call i32 @str_equals(ptr %693, ptr @.str.s605)
  %695 = icmp eq i32 %694, 1
  br i1 %695, label %label_1561, label %label_1563

label_1552:                                       ; preds = %label_1551
  %696 = load ptr, ptr %expr.626, align 8
  %697 = getelementptr inbounds nuw %ASTNode, ptr %696, i32 0, i32 6
  %698 = load ptr, ptr %697, align 8
  store ptr %698, ptr %bool_arg_ptr.686, align 8
  %699 = load ptr, ptr %bool_arg_ptr.686, align 8
  %700 = call i32 @str_equals(ptr %699, ptr @.str.s596)
  %701 = icmp eq i32 %700, 0
  br i1 %701, label %label_1555, label %label_1557

label_1557:                                       ; preds = %label_1560, %label_1552
  ret ptr @.str.s604

label_1555:                                       ; preds = %label_1552
  %702 = load ptr, ptr %bool_arg_ptr.686, align 8
  %703 = call ptr @ptr_to_node(ptr %702)
  store ptr %703, ptr %bool_arg.687, align 8
  %704 = load ptr, ptr %bool_arg.687, align 8
  %705 = call ptr @generate_expression__Struct_ASTNode(ptr %704)
  store ptr %705, ptr %bool_val.688, align 8
  %706 = load ptr, ptr %bool_val.688, align 8
  %707 = call i32 @ir_zext(ptr @.str.s597, ptr %706, ptr @.str.s598)
  store i32 %707, ptr %widened.689, align 4
  call void @ir_call_begin()
  %708 = load i32, ptr %widened.689, align 4
  %709 = call ptr @ir_get_temp_name(i32 %708)
  call void @ir_call_arg(ptr @.str.s599, ptr %709)
  %710 = load i32, ptr %is_print_bool.685, align 4
  %711 = icmp eq i32 %710, 1
  br i1 %711, label %label_1558, label %label_1559

label_1559:                                       ; preds = %label_1555
  %712 = call i32 @ir_call_end(ptr @.str.s602, ptr @.str.s603)
  br label %label_1560

label_1558:                                       ; preds = %label_1555
  %713 = call i32 @ir_call_end(ptr @.str.s600, ptr @.str.s601)
  br label %label_1560

label_1560:                                       ; preds = %label_1559, %label_1558
  br label %label_1557

label_1563:                                       ; preds = %label_1561, %label_1554
  %714 = load ptr, ptr %func_name.682, align 8
  %715 = call i32 @str_equals(ptr %714, ptr @.str.s606)
  %716 = icmp eq i32 %715, 1
  br i1 %716, label %label_1564, label %label_1566

label_1561:                                       ; preds = %label_1554
  store i32 1, ptr %is_print.690, align 4
  br label %label_1563

label_1566:                                       ; preds = %label_1564, %label_1563
  %717 = load i32, ptr %is_print.690, align 4
  %718 = icmp sgt i32 %717, 0
  br i1 %718, label %label_1567, label %label_1569

label_1564:                                       ; preds = %label_1563
  store i32 2, ptr %is_print.690, align 4
  br label %label_1566

label_1569:                                       ; preds = %label_1566
  call void @ir_call_begin()
  %719 = load ptr, ptr %expr.626, align 8
  %720 = getelementptr inbounds nuw %ASTNode, ptr %719, i32 0, i32 6
  %721 = load ptr, ptr %720, align 8
  store ptr %721, ptr %arg_ptr.695, align 8
  br label %label_1588

label_1567:                                       ; preds = %label_1566
  %722 = load ptr, ptr %expr.626, align 8
  %723 = getelementptr inbounds nuw %ASTNode, ptr %722, i32 0, i32 6
  %724 = load ptr, ptr %723, align 8
  store ptr %724, ptr %arg_ptr.691, align 8
  %725 = load ptr, ptr %arg_ptr.691, align 8
  %726 = call i32 @str_equals(ptr %725, ptr @.str.s607)
  %727 = icmp eq i32 %726, 0
  br i1 %727, label %label_1570, label %label_1572

label_1572:                                       ; preds = %label_1575, %label_1567
  ret ptr @.str.s624

label_1570:                                       ; preds = %label_1567
  %728 = load ptr, ptr %arg_ptr.691, align 8
  %729 = call ptr @ptr_to_node(ptr %728)
  store ptr %729, ptr %arg_node.692, align 8
  %730 = load ptr, ptr %arg_node.692, align 8
  %731 = call ptr @generate_expression__Struct_ASTNode(ptr %730)
  store ptr %731, ptr %arg_val.693, align 8
  %732 = load ptr, ptr %arg_node.692, align 8
  %733 = call ptr @get_expr_type__Struct_ASTNode(ptr %732)
  store ptr %733, ptr %arg_type.694, align 8
  call void @ir_call_begin()
  %734 = load ptr, ptr %arg_type.694, align 8
  %735 = call i32 @str_equals(ptr %734, ptr @.str.s608)
  %736 = icmp eq i32 %735, 1
  br i1 %736, label %label_1573, label %label_1574

label_1574:                                       ; preds = %label_1570
  %737 = load ptr, ptr %arg_type.694, align 8
  %738 = call i32 @str_equals(ptr %737, ptr @.str.s614)
  %739 = icmp eq i32 %738, 1
  br i1 %739, label %label_1579, label %label_1580

label_1573:                                       ; preds = %label_1570
  %740 = load ptr, ptr %arg_val.693, align 8
  call void @ir_call_arg(ptr @.str.s609, ptr %740)
  %741 = load i32, ptr %is_print.690, align 4
  %742 = icmp eq i32 %741, 1
  br i1 %742, label %label_1576, label %label_1577

label_1577:                                       ; preds = %label_1573
  %743 = call i32 @ir_call_end(ptr @.str.s612, ptr @.str.s613)
  br label %label_1578

label_1576:                                       ; preds = %label_1573
  %744 = call i32 @ir_call_end(ptr @.str.s610, ptr @.str.s611)
  br label %label_1578

label_1578:                                       ; preds = %label_1577, %label_1576
  br label %label_1575

label_1575:                                       ; preds = %label_1581, %label_1578
  br label %label_1572

label_1580:                                       ; preds = %label_1574
  %745 = load ptr, ptr %arg_type.694, align 8
  %746 = call ptr @storage_type__String(ptr %745)
  %747 = load ptr, ptr %arg_val.693, align 8
  call void @ir_call_arg(ptr %746, ptr %747)
  %748 = load i32, ptr %is_print.690, align 4
  %749 = icmp eq i32 %748, 1
  br i1 %749, label %label_1585, label %label_1586

label_1579:                                       ; preds = %label_1574
  %750 = load ptr, ptr %arg_val.693, align 8
  call void @ir_call_arg(ptr @.str.s615, ptr %750)
  %751 = load i32, ptr %is_print.690, align 4
  %752 = icmp eq i32 %751, 1
  br i1 %752, label %label_1582, label %label_1583

label_1583:                                       ; preds = %label_1579
  %753 = call i32 @ir_call_end(ptr @.str.s618, ptr @.str.s619)
  br label %label_1584

label_1582:                                       ; preds = %label_1579
  %754 = call i32 @ir_call_end(ptr @.str.s616, ptr @.str.s617)
  br label %label_1584

label_1584:                                       ; preds = %label_1583, %label_1582
  br label %label_1581

label_1581:                                       ; preds = %label_1587, %label_1584
  br label %label_1575

label_1586:                                       ; preds = %label_1580
  %755 = call i32 @ir_call_end(ptr @.str.s622, ptr @.str.s623)
  br label %label_1587

label_1585:                                       ; preds = %label_1580
  %756 = call i32 @ir_call_end(ptr @.str.s620, ptr @.str.s621)
  br label %label_1587

label_1587:                                       ; preds = %label_1586, %label_1585
  br label %label_1581

label_1588:                                       ; preds = %label_1589, %label_1569
  %757 = load ptr, ptr %arg_ptr.695, align 8
  %758 = call i32 @str_equals(ptr %757, ptr @.str.s625)
  %759 = icmp eq i32 %758, 0
  br i1 %759, label %label_1589, label %label_1590

label_1590:                                       ; preds = %label_1588
  %760 = load ptr, ptr %func_name.682, align 8
  store ptr %760, ptr %call_name.698, align 8
  %761 = load ptr, ptr %expr.626, align 8
  %762 = getelementptr inbounds nuw %ASTNode, ptr %761, i32 0, i32 2
  %763 = load ptr, ptr %762, align 8
  %764 = call i32 @str_equals(ptr %763, ptr @.str.s626)
  %765 = icmp eq i32 %764, 0
  br i1 %765, label %label_1591, label %label_1593

label_1589:                                       ; preds = %label_1588
  %766 = load ptr, ptr %arg_ptr.695, align 8
  %767 = call ptr @ptr_to_node(ptr %766)
  store ptr %767, ptr %arg_node.696, align 8
  %768 = load ptr, ptr %arg_node.696, align 8
  %769 = call ptr @generate_expression__Struct_ASTNode(ptr %768)
  store ptr %769, ptr %arg_val.697, align 8
  %770 = load ptr, ptr %arg_node.696, align 8
  %771 = call ptr @get_expr_type__Struct_ASTNode(ptr %770)
  %772 = call ptr @storage_type__String(ptr %771)
  %773 = load ptr, ptr %arg_val.697, align 8
  call void @ir_call_arg(ptr %772, ptr %773)
  %774 = load ptr, ptr %arg_node.696, align 8
  %775 = getelementptr inbounds nuw %ASTNode, ptr %774, i32 0, i32 8
  %776 = load ptr, ptr %775, align 8
  store ptr %776, ptr %arg_ptr.695, align 8
  br label %label_1588

label_1593:                                       ; preds = %label_1591, %label_1590
  %777 = load ptr, ptr %expr.626, align 8
  %778 = call ptr @get_expr_type__Struct_ASTNode(ptr %777)
  %779 = call ptr @storage_type__String(ptr %778)
  store ptr %779, ptr %ret_type.699, align 8
  %780 = load ptr, ptr %ret_type.699, align 8
  %781 = call i32 @str_equals(ptr %780, ptr @.str.s627)
  %782 = icmp eq i32 %781, 1
  br i1 %782, label %label_1594, label %label_1596

label_1591:                                       ; preds = %label_1590
  %783 = load ptr, ptr %expr.626, align 8
  %784 = getelementptr inbounds nuw %ASTNode, ptr %783, i32 0, i32 2
  %785 = load ptr, ptr %784, align 8
  store ptr %785, ptr %call_name.698, align 8
  br label %label_1593

label_1596:                                       ; preds = %label_1593
  %786 = load ptr, ptr %ret_type.699, align 8
  %787 = load ptr, ptr %call_name.698, align 8
  %788 = call i32 @ir_call_end(ptr %786, ptr %787)
  store i32 %788, ptr %temp_id.700, align 4
  %789 = load i32, ptr %temp_id.700, align 4
  %790 = call ptr @ir_get_temp_name(i32 %789)
  ret ptr %790

label_1594:                                       ; preds = %label_1593
  %791 = load ptr, ptr %call_name.698, align 8
  %792 = call i32 @ir_call_end(ptr @.str.s628, ptr %791)
  ret ptr @.str.s629
}

define void @generate_statement__Struct_ASTNode(ptr %0) {
entry:
  %stmt.701 = alloca ptr, align 8
  store ptr %0, ptr %stmt.701, align 8
  %1 = load ptr, ptr %stmt.701, align 8
  %2 = getelementptr inbounds nuw %ASTNode, ptr %1, i32 0, i32 0
  %3 = load i32, ptr %2, align 4
  %4 = icmp eq i32 %3, 3
  %var_name.702 = alloca ptr, align 8
  %var_type.703 = alloca ptr, align 8
  %type_node.704 = alloca ptr, align 8
  %init_val.705 = alloca ptr, align 8
  %has_init.706 = alloca i1, align 1
  %slot.707 = alloca ptr, align 8
  %store_type.708 = alloca ptr, align 8
  %target_node.709 = alloca ptr, align 8
  %var_name.710 = alloca ptr, align 8
  %var_type.711 = alloca ptr, align 8
  %store_type.712 = alloca ptr, align 8
  %val.713 = alloca ptr, align 8
  %object_node.714 = alloca ptr, align 8
  %object_val.715 = alloca ptr, align 8
  %object_type.716 = alloca ptr, align 8
  %struct_name.717 = alloca ptr, align 8
  %field_index.718 = alloca i32, align 4
  %field_type.719 = alloca ptr, align 8
  %val.720 = alloca ptr, align 8
  %slot.721 = alloca i32, align 4
  %ret_val.722 = alloca ptr, align 8
  %cond_val.723 = alloca ptr, align 8
  %then_label.724 = alloca i32, align 4
  %else_label.725 = alloca i32, align 4
  %end_label.726 = alloca i32, align 4
  %else_node.727 = alloca ptr, align 8
  %cond_label.728 = alloca i32, align 4
  %body_label.729 = alloca i32, align 4
  %end_label.730 = alloca i32, align 4
  %cond_val.731 = alloca ptr, align 8
  %body_label.732 = alloca i32, align 4
  %end_label.733 = alloca i32, align 4
  %loop_var.734 = alloca ptr, align 8
  %start_val.735 = alloca ptr, align 8
  %cond_label.736 = alloca i32, align 4
  %body_label.737 = alloca i32, align 4
  %incr_label.738 = alloca i32, align 4
  %end_label.739 = alloca i32, align 4
  %iv.740 = alloca i32, align 4
  %end_val.741 = alloca ptr, align 8
  %cmp.742 = alloca i32, align 4
  %iv2.743 = alloca i32, align 4
  %next.744 = alloca i32, align 4
  %target.745 = alloca i32, align 4
  %target.746 = alloca i32, align 4
  %scrut_val.747 = alloca ptr, align 8
  %scrut_type.748 = alloca ptr, align 8
  %end_label.749 = alloca i32, align 4
  %needs_final_br.750 = alloca i1, align 1
  %arm_ptr.751 = alloca ptr, align 8
  %arm.752 = alloca ptr, align 8
  %pat_val.753 = alloca ptr, align 8
  %cmp.754 = alloca i32, align 4
  %arm_label.755 = alloca i32, align 4
  %next_label.756 = alloca i32, align 4
  br i1 %4, label %label_1597, label %label_1599

label_1599:                                       ; preds = %label_1611, %entry
  %5 = load ptr, ptr %stmt.701, align 8
  %6 = getelementptr inbounds nuw %ASTNode, ptr %5, i32 0, i32 0
  %7 = load i32, ptr %6, align 4
  %8 = icmp eq i32 %7, 16
  br i1 %8, label %label_1612, label %label_1614

label_1597:                                       ; preds = %entry
  %9 = load ptr, ptr %stmt.701, align 8
  %10 = getelementptr inbounds nuw %ASTNode, ptr %9, i32 0, i32 1
  %11 = load ptr, ptr %10, align 8
  store ptr %11, ptr %var_name.702, align 8
  store ptr @.str.s631, ptr %var_type.703, align 8
  %12 = load ptr, ptr %stmt.701, align 8
  %13 = getelementptr inbounds nuw %ASTNode, ptr %12, i32 0, i32 5
  %14 = load ptr, ptr %13, align 8
  %15 = call i32 @str_equals(ptr %14, ptr @.str.s632)
  %16 = icmp eq i32 %15, 0
  br i1 %16, label %label_1600, label %label_1601

label_1601:                                       ; preds = %label_1597
  %17 = load ptr, ptr %stmt.701, align 8
  %18 = getelementptr inbounds nuw %ASTNode, ptr %17, i32 0, i32 6
  %19 = load ptr, ptr %18, align 8
  %20 = call i32 @str_equals(ptr %19, ptr @.str.s633)
  %21 = icmp eq i32 %20, 0
  br i1 %21, label %label_1603, label %label_1605

label_1600:                                       ; preds = %label_1597
  %22 = load ptr, ptr %stmt.701, align 8
  %23 = getelementptr inbounds nuw %ASTNode, ptr %22, i32 0, i32 5
  %24 = load ptr, ptr %23, align 8
  %25 = call ptr @ptr_to_node(ptr %24)
  store ptr %25, ptr %type_node.704, align 8
  %26 = load ptr, ptr %type_node.704, align 8
  %27 = call ptr @map_type_node__Struct_ASTNode(ptr %26)
  store ptr %27, ptr %var_type.703, align 8
  br label %label_1602

label_1602:                                       ; preds = %label_1605, %label_1600
  store ptr @.str.s634, ptr %init_val.705, align 8
  %28 = load ptr, ptr %stmt.701, align 8
  %29 = getelementptr inbounds nuw %ASTNode, ptr %28, i32 0, i32 6
  %30 = load ptr, ptr %29, align 8
  %31 = call i32 @str_equals(ptr %30, ptr @.str.s635)
  %32 = icmp eq i32 %31, 0
  store i1 %32, ptr %has_init.706, align 1
  %33 = load i1, ptr %has_init.706, align 1
  br i1 %33, label %label_1606, label %label_1608

label_1605:                                       ; preds = %label_1603, %label_1601
  br label %label_1602

label_1603:                                       ; preds = %label_1601
  %34 = load ptr, ptr %stmt.701, align 8
  %35 = getelementptr inbounds nuw %ASTNode, ptr %34, i32 0, i32 6
  %36 = load ptr, ptr %35, align 8
  %37 = call ptr @ptr_to_node(ptr %36)
  %38 = call ptr @get_expr_type__Struct_ASTNode(ptr %37)
  store ptr %38, ptr %var_type.703, align 8
  br label %label_1605

label_1608:                                       ; preds = %label_1606, %label_1602
  %39 = load ptr, ptr %var_name.702, align 8
  %40 = load ptr, ptr %var_type.703, align 8
  call void @ir_set_var_type(ptr %39, ptr %40)
  %41 = load ptr, ptr %var_name.702, align 8
  %42 = call ptr @ir_get_var_slot(ptr %41)
  store ptr %42, ptr %slot.707, align 8
  %43 = load ptr, ptr %var_type.703, align 8
  %44 = call ptr @storage_type__String(ptr %43)
  store ptr %44, ptr %store_type.708, align 8
  %45 = load ptr, ptr %store_type.708, align 8
  %46 = load ptr, ptr %slot.707, align 8
  %47 = call i32 @ir_alloca(ptr %45, ptr %46)
  %48 = load i1, ptr %has_init.706, align 1
  br i1 %48, label %label_1609, label %label_1611

label_1606:                                       ; preds = %label_1602
  %49 = load ptr, ptr %stmt.701, align 8
  %50 = getelementptr inbounds nuw %ASTNode, ptr %49, i32 0, i32 6
  %51 = load ptr, ptr %50, align 8
  %52 = call ptr @ptr_to_node(ptr %51)
  %53 = call ptr @generate_expression__Struct_ASTNode(ptr %52)
  store ptr %53, ptr %init_val.705, align 8
  br label %label_1608

label_1611:                                       ; preds = %label_1609, %label_1608
  br label %label_1599

label_1609:                                       ; preds = %label_1608
  %54 = load ptr, ptr %store_type.708, align 8
  %55 = load ptr, ptr %init_val.705, align 8
  %56 = load ptr, ptr %slot.707, align 8
  call void @ir_store(ptr %54, ptr %55, ptr %56)
  br label %label_1611

label_1614:                                       ; preds = %label_1623, %label_1599
  %57 = load ptr, ptr %stmt.701, align 8
  %58 = getelementptr inbounds nuw %ASTNode, ptr %57, i32 0, i32 0
  %59 = load i32, ptr %58, align 4
  %60 = icmp eq i32 %59, 15
  br i1 %60, label %label_1624, label %label_1626

label_1612:                                       ; preds = %label_1599
  %61 = load ptr, ptr %stmt.701, align 8
  %62 = getelementptr inbounds nuw %ASTNode, ptr %61, i32 0, i32 5
  %63 = load ptr, ptr %62, align 8
  %64 = call ptr @ptr_to_node(ptr %63)
  store ptr %64, ptr %target_node.709, align 8
  %65 = load ptr, ptr %target_node.709, align 8
  %66 = getelementptr inbounds nuw %ASTNode, ptr %65, i32 0, i32 0
  %67 = load i32, ptr %66, align 4
  %68 = icmp eq i32 %67, 23
  br i1 %68, label %label_1615, label %label_1617

label_1617:                                       ; preds = %label_1620, %label_1612
  %69 = load ptr, ptr %target_node.709, align 8
  %70 = getelementptr inbounds nuw %ASTNode, ptr %69, i32 0, i32 0
  %71 = load i32, ptr %70, align 4
  %72 = icmp eq i32 %71, 25
  br i1 %72, label %label_1621, label %label_1623

label_1615:                                       ; preds = %label_1612
  %73 = load ptr, ptr %target_node.709, align 8
  %74 = getelementptr inbounds nuw %ASTNode, ptr %73, i32 0, i32 1
  %75 = load ptr, ptr %74, align 8
  store ptr %75, ptr %var_name.710, align 8
  %76 = load ptr, ptr %var_name.710, align 8
  %77 = call ptr @ir_get_var_type(ptr %76)
  store ptr %77, ptr %var_type.711, align 8
  %78 = load ptr, ptr %var_type.711, align 8
  %79 = call ptr @storage_type__String(ptr %78)
  store ptr %79, ptr %store_type.712, align 8
  %80 = load ptr, ptr %stmt.701, align 8
  %81 = getelementptr inbounds nuw %ASTNode, ptr %80, i32 0, i32 6
  %82 = load ptr, ptr %81, align 8
  %83 = call ptr @ptr_to_node(ptr %82)
  %84 = call ptr @generate_expression__Struct_ASTNode(ptr %83)
  store ptr %84, ptr %val.713, align 8
  %85 = load ptr, ptr %var_name.710, align 8
  %86 = call i32 @ir_var_is_global(ptr %85)
  %87 = icmp eq i32 %86, 1
  br i1 %87, label %label_1618, label %label_1619

label_1619:                                       ; preds = %label_1615
  %88 = load ptr, ptr %store_type.712, align 8
  %89 = load ptr, ptr %val.713, align 8
  %90 = load ptr, ptr %var_name.710, align 8
  %91 = call ptr @ir_get_var_slot(ptr %90)
  call void @ir_store(ptr %88, ptr %89, ptr %91)
  br label %label_1620

label_1618:                                       ; preds = %label_1615
  %92 = load ptr, ptr %store_type.712, align 8
  %93 = load ptr, ptr %val.713, align 8
  %94 = load ptr, ptr %var_name.710, align 8
  call void @ir_store_global(ptr %92, ptr %93, ptr %94)
  br label %label_1620

label_1620:                                       ; preds = %label_1619, %label_1618
  br label %label_1617

label_1623:                                       ; preds = %label_1621, %label_1617
  br label %label_1614

label_1621:                                       ; preds = %label_1617
  %95 = load ptr, ptr %target_node.709, align 8
  %96 = getelementptr inbounds nuw %ASTNode, ptr %95, i32 0, i32 5
  %97 = load ptr, ptr %96, align 8
  %98 = call ptr @ptr_to_node(ptr %97)
  store ptr %98, ptr %object_node.714, align 8
  %99 = load ptr, ptr %object_node.714, align 8
  %100 = call ptr @generate_expression__Struct_ASTNode(ptr %99)
  store ptr %100, ptr %object_val.715, align 8
  %101 = load ptr, ptr %object_node.714, align 8
  %102 = call ptr @get_expr_type__Struct_ASTNode(ptr %101)
  store ptr %102, ptr %object_type.716, align 8
  %103 = load ptr, ptr %object_type.716, align 8
  %104 = call ptr @struct_type_name__String(ptr %103)
  store ptr %104, ptr %struct_name.717, align 8
  %105 = load ptr, ptr %struct_name.717, align 8
  %106 = load ptr, ptr %target_node.709, align 8
  %107 = getelementptr inbounds nuw %ASTNode, ptr %106, i32 0, i32 1
  %108 = load ptr, ptr %107, align 8
  %109 = call i32 @ir_get_struct_field_index(ptr %105, ptr %108)
  store i32 %109, ptr %field_index.718, align 4
  %110 = load ptr, ptr %struct_name.717, align 8
  %111 = load ptr, ptr %target_node.709, align 8
  %112 = getelementptr inbounds nuw %ASTNode, ptr %111, i32 0, i32 1
  %113 = load ptr, ptr %112, align 8
  %114 = call ptr @ir_get_struct_field_type(ptr %110, ptr %113)
  %115 = call ptr @storage_type__String(ptr %114)
  store ptr %115, ptr %field_type.719, align 8
  %116 = load ptr, ptr %stmt.701, align 8
  %117 = getelementptr inbounds nuw %ASTNode, ptr %116, i32 0, i32 6
  %118 = load ptr, ptr %117, align 8
  %119 = call ptr @ptr_to_node(ptr %118)
  %120 = call ptr @generate_expression__Struct_ASTNode(ptr %119)
  store ptr %120, ptr %val.720, align 8
  %121 = load ptr, ptr %struct_name.717, align 8
  %122 = load ptr, ptr %object_val.715, align 8
  %123 = load i32, ptr %field_index.718, align 4
  %124 = call i32 @ir_struct_field_ptr(ptr %121, ptr %122, i32 %123)
  store i32 %124, ptr %slot.721, align 4
  %125 = load ptr, ptr %field_type.719, align 8
  %126 = load ptr, ptr %val.720, align 8
  %127 = load i32, ptr %slot.721, align 4
  %128 = call ptr @ir_get_temp_name(i32 %127)
  call void @ir_store_ptr(ptr %125, ptr %126, ptr %128)
  br label %label_1623

label_1626:                                       ; preds = %label_1629, %label_1614
  %129 = load ptr, ptr %stmt.701, align 8
  %130 = getelementptr inbounds nuw %ASTNode, ptr %129, i32 0, i32 0
  %131 = load i32, ptr %130, align 4
  %132 = icmp eq i32 %131, 17
  br i1 %132, label %label_1630, label %label_1632

label_1624:                                       ; preds = %label_1614
  %133 = load ptr, ptr %stmt.701, align 8
  %134 = getelementptr inbounds nuw %ASTNode, ptr %133, i32 0, i32 5
  %135 = load ptr, ptr %134, align 8
  %136 = call i32 @str_equals(ptr %135, ptr @.str.s636)
  %137 = icmp eq i32 %136, 0
  br i1 %137, label %label_1627, label %label_1628

label_1628:                                       ; preds = %label_1624
  call void @ir_ret_void()
  br label %label_1629

label_1627:                                       ; preds = %label_1624
  %138 = load ptr, ptr %stmt.701, align 8
  %139 = getelementptr inbounds nuw %ASTNode, ptr %138, i32 0, i32 5
  %140 = load ptr, ptr %139, align 8
  %141 = call ptr @ptr_to_node(ptr %140)
  %142 = call ptr @generate_expression__Struct_ASTNode(ptr %141)
  store ptr %142, ptr %ret_val.722, align 8
  %143 = load ptr, ptr %stmt.701, align 8
  %144 = getelementptr inbounds nuw %ASTNode, ptr %143, i32 0, i32 5
  %145 = load ptr, ptr %144, align 8
  %146 = call ptr @ptr_to_node(ptr %145)
  %147 = call ptr @get_expr_type__Struct_ASTNode(ptr %146)
  %148 = call ptr @storage_type__String(ptr %147)
  %149 = load ptr, ptr %ret_val.722, align 8
  call void @ir_ret(ptr %148, ptr %149)
  br label %label_1629

label_1629:                                       ; preds = %label_1628, %label_1627
  call void @ir_set_returned()
  br label %label_1626

label_1632:                                       ; preds = %label_1635, %label_1626
  %150 = load ptr, ptr %stmt.701, align 8
  %151 = getelementptr inbounds nuw %ASTNode, ptr %150, i32 0, i32 0
  %152 = load i32, ptr %151, align 4
  %153 = icmp eq i32 %152, 10
  br i1 %153, label %label_1636, label %label_1638

label_1630:                                       ; preds = %label_1626
  %154 = load ptr, ptr %stmt.701, align 8
  %155 = getelementptr inbounds nuw %ASTNode, ptr %154, i32 0, i32 5
  %156 = load ptr, ptr %155, align 8
  %157 = call i32 @str_equals(ptr %156, ptr @.str.s637)
  %158 = icmp eq i32 %157, 0
  br i1 %158, label %label_1633, label %label_1635

label_1635:                                       ; preds = %label_1633, %label_1630
  br label %label_1632

label_1633:                                       ; preds = %label_1630
  %159 = load ptr, ptr %stmt.701, align 8
  %160 = getelementptr inbounds nuw %ASTNode, ptr %159, i32 0, i32 5
  %161 = load ptr, ptr %160, align 8
  %162 = call ptr @ptr_to_node(ptr %161)
  %163 = call ptr @generate_expression__Struct_ASTNode(ptr %162)
  br label %label_1635

label_1638:                                       ; preds = %label_1647, %label_1632
  %164 = load ptr, ptr %stmt.701, align 8
  %165 = getelementptr inbounds nuw %ASTNode, ptr %164, i32 0, i32 0
  %166 = load i32, ptr %165, align 4
  %167 = icmp eq i32 %166, 13
  br i1 %167, label %label_1654, label %label_1656

label_1636:                                       ; preds = %label_1632
  %168 = load ptr, ptr %stmt.701, align 8
  %169 = getelementptr inbounds nuw %ASTNode, ptr %168, i32 0, i32 5
  %170 = load ptr, ptr %169, align 8
  %171 = call ptr @ptr_to_node(ptr %170)
  %172 = call ptr @generate_expression__Struct_ASTNode(ptr %171)
  store ptr %172, ptr %cond_val.723, align 8
  %173 = call i32 @ir_get_label()
  store i32 %173, ptr %then_label.724, align 4
  %174 = call i32 @ir_get_label()
  store i32 %174, ptr %else_label.725, align 4
  %175 = call i32 @ir_get_label()
  store i32 %175, ptr %end_label.726, align 4
  %176 = load ptr, ptr %stmt.701, align 8
  %177 = getelementptr inbounds nuw %ASTNode, ptr %176, i32 0, i32 7
  %178 = load ptr, ptr %177, align 8
  %179 = call i32 @str_equals(ptr %178, ptr @.str.s638)
  %180 = icmp eq i32 %179, 0
  br i1 %180, label %label_1639, label %label_1640

label_1640:                                       ; preds = %label_1636
  %181 = load ptr, ptr %cond_val.723, align 8
  %182 = load i32, ptr %then_label.724, align 4
  %183 = load i32, ptr %end_label.726, align 4
  call void @ir_cond_br_numbered(ptr %181, i32 %182, i32 %183)
  br label %label_1641

label_1639:                                       ; preds = %label_1636
  %184 = load ptr, ptr %cond_val.723, align 8
  %185 = load i32, ptr %then_label.724, align 4
  %186 = load i32, ptr %else_label.725, align 4
  call void @ir_cond_br_numbered(ptr %184, i32 %185, i32 %186)
  br label %label_1641

label_1641:                                       ; preds = %label_1640, %label_1639
  %187 = load i32, ptr %then_label.724, align 4
  call void @ir_label_numbered(i32 %187)
  %188 = load ptr, ptr %stmt.701, align 8
  %189 = getelementptr inbounds nuw %ASTNode, ptr %188, i32 0, i32 6
  %190 = load ptr, ptr %189, align 8
  %191 = call ptr @ptr_to_node(ptr %190)
  call void @generate_block__Struct_ASTNode(ptr %191)
  %192 = call i32 @ir_has_returned()
  %193 = icmp eq i32 %192, 0
  br i1 %193, label %label_1642, label %label_1644

label_1644:                                       ; preds = %label_1642, %label_1641
  call void @ir_clear_returned()
  %194 = load ptr, ptr %stmt.701, align 8
  %195 = getelementptr inbounds nuw %ASTNode, ptr %194, i32 0, i32 7
  %196 = load ptr, ptr %195, align 8
  %197 = call i32 @str_equals(ptr %196, ptr @.str.s639)
  %198 = icmp eq i32 %197, 0
  br i1 %198, label %label_1645, label %label_1647

label_1642:                                       ; preds = %label_1641
  %199 = load i32, ptr %end_label.726, align 4
  call void @ir_br_numbered(i32 %199)
  br label %label_1644

label_1647:                                       ; preds = %label_1653, %label_1644
  %200 = load i32, ptr %end_label.726, align 4
  call void @ir_label_numbered(i32 %200)
  br label %label_1638

label_1645:                                       ; preds = %label_1644
  %201 = load i32, ptr %else_label.725, align 4
  call void @ir_label_numbered(i32 %201)
  %202 = load ptr, ptr %stmt.701, align 8
  %203 = getelementptr inbounds nuw %ASTNode, ptr %202, i32 0, i32 7
  %204 = load ptr, ptr %203, align 8
  %205 = call ptr @ptr_to_node(ptr %204)
  store ptr %205, ptr %else_node.727, align 8
  %206 = load ptr, ptr %else_node.727, align 8
  %207 = getelementptr inbounds nuw %ASTNode, ptr %206, i32 0, i32 0
  %208 = load i32, ptr %207, align 4
  %209 = icmp eq i32 %208, 10
  br i1 %209, label %label_1648, label %label_1649

label_1649:                                       ; preds = %label_1645
  %210 = load ptr, ptr %else_node.727, align 8
  call void @generate_block__Struct_ASTNode(ptr %210)
  br label %label_1650

label_1648:                                       ; preds = %label_1645
  %211 = load ptr, ptr %else_node.727, align 8
  call void @generate_statement__Struct_ASTNode(ptr %211)
  br label %label_1650

label_1650:                                       ; preds = %label_1649, %label_1648
  %212 = call i32 @ir_has_returned()
  %213 = icmp eq i32 %212, 0
  br i1 %213, label %label_1651, label %label_1653

label_1653:                                       ; preds = %label_1651, %label_1650
  call void @ir_clear_returned()
  br label %label_1647

label_1651:                                       ; preds = %label_1650
  %214 = load i32, ptr %end_label.726, align 4
  call void @ir_br_numbered(i32 %214)
  br label %label_1653

label_1656:                                       ; preds = %label_1659, %label_1638
  %215 = load ptr, ptr %stmt.701, align 8
  %216 = getelementptr inbounds nuw %ASTNode, ptr %215, i32 0, i32 0
  %217 = load i32, ptr %216, align 4
  %218 = icmp eq i32 %217, 14
  br i1 %218, label %label_1660, label %label_1662

label_1654:                                       ; preds = %label_1638
  %219 = call i32 @ir_get_label()
  store i32 %219, ptr %cond_label.728, align 4
  %220 = call i32 @ir_get_label()
  store i32 %220, ptr %body_label.729, align 4
  %221 = call i32 @ir_get_label()
  store i32 %221, ptr %end_label.730, align 4
  %222 = load i32, ptr %cond_label.728, align 4
  call void @ir_br_numbered(i32 %222)
  %223 = load i32, ptr %cond_label.728, align 4
  call void @ir_label_numbered(i32 %223)
  %224 = load ptr, ptr %stmt.701, align 8
  %225 = getelementptr inbounds nuw %ASTNode, ptr %224, i32 0, i32 5
  %226 = load ptr, ptr %225, align 8
  %227 = call ptr @ptr_to_node(ptr %226)
  %228 = call ptr @generate_expression__Struct_ASTNode(ptr %227)
  store ptr %228, ptr %cond_val.731, align 8
  %229 = load ptr, ptr %cond_val.731, align 8
  %230 = load i32, ptr %body_label.729, align 4
  %231 = load i32, ptr %end_label.730, align 4
  call void @ir_cond_br_numbered(ptr %229, i32 %230, i32 %231)
  %232 = load i32, ptr %body_label.729, align 4
  call void @ir_label_numbered(i32 %232)
  %233 = load i32, ptr %cond_label.728, align 4
  %234 = load i32, ptr %end_label.730, align 4
  call void @ir_loop_push(i32 %233, i32 %234)
  %235 = load ptr, ptr %stmt.701, align 8
  %236 = getelementptr inbounds nuw %ASTNode, ptr %235, i32 0, i32 6
  %237 = load ptr, ptr %236, align 8
  %238 = call ptr @ptr_to_node(ptr %237)
  call void @generate_block__Struct_ASTNode(ptr %238)
  call void @ir_loop_pop()
  %239 = call i32 @ir_has_returned()
  %240 = icmp eq i32 %239, 0
  br i1 %240, label %label_1657, label %label_1659

label_1659:                                       ; preds = %label_1657, %label_1654
  call void @ir_clear_returned()
  %241 = load i32, ptr %end_label.730, align 4
  call void @ir_label_numbered(i32 %241)
  br label %label_1656

label_1657:                                       ; preds = %label_1654
  %242 = load i32, ptr %cond_label.728, align 4
  call void @ir_br_numbered(i32 %242)
  br label %label_1659

label_1662:                                       ; preds = %label_1665, %label_1656
  %243 = load ptr, ptr %stmt.701, align 8
  %244 = getelementptr inbounds nuw %ASTNode, ptr %243, i32 0, i32 0
  %245 = load i32, ptr %244, align 4
  %246 = icmp eq i32 %245, 12
  br i1 %246, label %label_1666, label %label_1668

label_1660:                                       ; preds = %label_1656
  %247 = call i32 @ir_get_label()
  store i32 %247, ptr %body_label.732, align 4
  %248 = call i32 @ir_get_label()
  store i32 %248, ptr %end_label.733, align 4
  %249 = load i32, ptr %body_label.732, align 4
  call void @ir_br_numbered(i32 %249)
  %250 = load i32, ptr %body_label.732, align 4
  call void @ir_label_numbered(i32 %250)
  %251 = load i32, ptr %body_label.732, align 4
  %252 = load i32, ptr %end_label.733, align 4
  call void @ir_loop_push(i32 %251, i32 %252)
  %253 = load ptr, ptr %stmt.701, align 8
  %254 = getelementptr inbounds nuw %ASTNode, ptr %253, i32 0, i32 5
  %255 = load ptr, ptr %254, align 8
  %256 = call ptr @ptr_to_node(ptr %255)
  call void @generate_block__Struct_ASTNode(ptr %256)
  call void @ir_loop_pop()
  %257 = call i32 @ir_has_returned()
  %258 = icmp eq i32 %257, 0
  br i1 %258, label %label_1663, label %label_1665

label_1665:                                       ; preds = %label_1663, %label_1660
  call void @ir_clear_returned()
  %259 = load i32, ptr %end_label.733, align 4
  call void @ir_label_numbered(i32 %259)
  br label %label_1662

label_1663:                                       ; preds = %label_1660
  %260 = load i32, ptr %body_label.732, align 4
  call void @ir_br_numbered(i32 %260)
  br label %label_1665

label_1668:                                       ; preds = %label_1671, %label_1662
  %261 = load ptr, ptr %stmt.701, align 8
  %262 = getelementptr inbounds nuw %ASTNode, ptr %261, i32 0, i32 0
  %263 = load i32, ptr %262, align 4
  %264 = icmp eq i32 %263, 18
  br i1 %264, label %label_1672, label %label_1674

label_1666:                                       ; preds = %label_1662
  call void @ir_scope_push()
  %265 = load ptr, ptr %stmt.701, align 8
  %266 = getelementptr inbounds nuw %ASTNode, ptr %265, i32 0, i32 1
  %267 = load ptr, ptr %266, align 8
  call void @ir_set_var_type(ptr %267, ptr @.str.s640)
  %268 = load ptr, ptr %stmt.701, align 8
  %269 = getelementptr inbounds nuw %ASTNode, ptr %268, i32 0, i32 1
  %270 = load ptr, ptr %269, align 8
  %271 = call ptr @ir_get_var_slot(ptr %270)
  store ptr %271, ptr %loop_var.734, align 8
  %272 = load ptr, ptr %loop_var.734, align 8
  %273 = call i32 @ir_alloca(ptr @.str.s641, ptr %272)
  %274 = load ptr, ptr %stmt.701, align 8
  %275 = getelementptr inbounds nuw %ASTNode, ptr %274, i32 0, i32 5
  %276 = load ptr, ptr %275, align 8
  %277 = call ptr @ptr_to_node(ptr %276)
  %278 = call ptr @generate_expression__Struct_ASTNode(ptr %277)
  store ptr %278, ptr %start_val.735, align 8
  %279 = load ptr, ptr %start_val.735, align 8
  %280 = load ptr, ptr %loop_var.734, align 8
  call void @ir_store(ptr @.str.s642, ptr %279, ptr %280)
  %281 = call i32 @ir_get_label()
  store i32 %281, ptr %cond_label.736, align 4
  %282 = call i32 @ir_get_label()
  store i32 %282, ptr %body_label.737, align 4
  %283 = call i32 @ir_get_label()
  store i32 %283, ptr %incr_label.738, align 4
  %284 = call i32 @ir_get_label()
  store i32 %284, ptr %end_label.739, align 4
  %285 = load i32, ptr %cond_label.736, align 4
  call void @ir_br_numbered(i32 %285)
  %286 = load i32, ptr %cond_label.736, align 4
  call void @ir_label_numbered(i32 %286)
  %287 = load ptr, ptr %loop_var.734, align 8
  %288 = call i32 @ir_load(ptr @.str.s643, ptr %287)
  store i32 %288, ptr %iv.740, align 4
  %289 = load ptr, ptr %stmt.701, align 8
  %290 = getelementptr inbounds nuw %ASTNode, ptr %289, i32 0, i32 6
  %291 = load ptr, ptr %290, align 8
  %292 = call ptr @ptr_to_node(ptr %291)
  %293 = call ptr @generate_expression__Struct_ASTNode(ptr %292)
  store ptr %293, ptr %end_val.741, align 8
  %294 = load i32, ptr %iv.740, align 4
  %295 = call ptr @ir_get_temp_name(i32 %294)
  %296 = load ptr, ptr %end_val.741, align 8
  %297 = call i32 @ir_icmp_slt(ptr @.str.s644, ptr %295, ptr %296)
  store i32 %297, ptr %cmp.742, align 4
  %298 = load i32, ptr %cmp.742, align 4
  %299 = call ptr @ir_get_temp_name(i32 %298)
  %300 = load i32, ptr %body_label.737, align 4
  %301 = load i32, ptr %end_label.739, align 4
  call void @ir_cond_br_numbered(ptr %299, i32 %300, i32 %301)
  %302 = load i32, ptr %body_label.737, align 4
  call void @ir_label_numbered(i32 %302)
  %303 = load i32, ptr %incr_label.738, align 4
  %304 = load i32, ptr %end_label.739, align 4
  call void @ir_loop_push(i32 %303, i32 %304)
  %305 = load ptr, ptr %stmt.701, align 8
  %306 = getelementptr inbounds nuw %ASTNode, ptr %305, i32 0, i32 7
  %307 = load ptr, ptr %306, align 8
  %308 = call ptr @ptr_to_node(ptr %307)
  call void @generate_block__Struct_ASTNode(ptr %308)
  call void @ir_loop_pop()
  %309 = call i32 @ir_has_returned()
  %310 = icmp eq i32 %309, 0
  br i1 %310, label %label_1669, label %label_1671

label_1671:                                       ; preds = %label_1669, %label_1666
  call void @ir_clear_returned()
  %311 = load i32, ptr %incr_label.738, align 4
  call void @ir_label_numbered(i32 %311)
  %312 = load ptr, ptr %loop_var.734, align 8
  %313 = call i32 @ir_load(ptr @.str.s645, ptr %312)
  store i32 %313, ptr %iv2.743, align 4
  %314 = load i32, ptr %iv2.743, align 4
  %315 = call ptr @ir_get_temp_name(i32 %314)
  %316 = call i32 @ir_add(ptr @.str.s646, ptr %315, ptr @.str.s647)
  store i32 %316, ptr %next.744, align 4
  %317 = load i32, ptr %next.744, align 4
  %318 = call ptr @ir_get_temp_name(i32 %317)
  %319 = load ptr, ptr %loop_var.734, align 8
  call void @ir_store(ptr @.str.s648, ptr %318, ptr %319)
  %320 = load i32, ptr %cond_label.736, align 4
  call void @ir_br_numbered(i32 %320)
  %321 = load i32, ptr %end_label.739, align 4
  call void @ir_label_numbered(i32 %321)
  call void @ir_scope_pop()
  br label %label_1668

label_1669:                                       ; preds = %label_1666
  %322 = load i32, ptr %incr_label.738, align 4
  call void @ir_br_numbered(i32 %322)
  br label %label_1671

label_1674:                                       ; preds = %label_1677, %label_1668
  %323 = load ptr, ptr %stmt.701, align 8
  %324 = getelementptr inbounds nuw %ASTNode, ptr %323, i32 0, i32 0
  %325 = load i32, ptr %324, align 4
  %326 = icmp eq i32 %325, 19
  br i1 %326, label %label_1678, label %label_1680

label_1672:                                       ; preds = %label_1668
  %327 = call i32 @ir_loop_break_label()
  store i32 %327, ptr %target.745, align 4
  %328 = load i32, ptr %target.745, align 4
  %329 = icmp sge i32 %328, 0
  br i1 %329, label %label_1675, label %label_1677

label_1677:                                       ; preds = %label_1675, %label_1672
  br label %label_1674

label_1675:                                       ; preds = %label_1672
  %330 = load i32, ptr %target.745, align 4
  call void @ir_br_numbered(i32 %330)
  call void @ir_set_returned()
  br label %label_1677

label_1680:                                       ; preds = %label_1683, %label_1674
  %331 = load ptr, ptr %stmt.701, align 8
  %332 = getelementptr inbounds nuw %ASTNode, ptr %331, i32 0, i32 0
  %333 = load i32, ptr %332, align 4
  %334 = icmp eq i32 %333, 11
  br i1 %334, label %label_1684, label %label_1686

label_1678:                                       ; preds = %label_1674
  %335 = call i32 @ir_loop_continue_label()
  store i32 %335, ptr %target.746, align 4
  %336 = load i32, ptr %target.746, align 4
  %337 = icmp sge i32 %336, 0
  br i1 %337, label %label_1681, label %label_1683

label_1683:                                       ; preds = %label_1681, %label_1678
  br label %label_1680

label_1681:                                       ; preds = %label_1678
  %338 = load i32, ptr %target.746, align 4
  call void @ir_br_numbered(i32 %338)
  call void @ir_set_returned()
  br label %label_1683

label_1686:                                       ; preds = %label_1701, %label_1680
  ret void

label_1684:                                       ; preds = %label_1680
  %339 = load ptr, ptr %stmt.701, align 8
  %340 = getelementptr inbounds nuw %ASTNode, ptr %339, i32 0, i32 5
  %341 = load ptr, ptr %340, align 8
  %342 = call ptr @ptr_to_node(ptr %341)
  %343 = call ptr @generate_expression__Struct_ASTNode(ptr %342)
  store ptr %343, ptr %scrut_val.747, align 8
  %344 = load ptr, ptr %stmt.701, align 8
  %345 = getelementptr inbounds nuw %ASTNode, ptr %344, i32 0, i32 5
  %346 = load ptr, ptr %345, align 8
  %347 = call ptr @ptr_to_node(ptr %346)
  %348 = call ptr @get_expr_type__Struct_ASTNode(ptr %347)
  store ptr %348, ptr %scrut_type.748, align 8
  %349 = call i32 @ir_get_label()
  store i32 %349, ptr %end_label.749, align 4
  store i1 true, ptr %needs_final_br.750, align 1
  %350 = load ptr, ptr %stmt.701, align 8
  %351 = getelementptr inbounds nuw %ASTNode, ptr %350, i32 0, i32 6
  %352 = load ptr, ptr %351, align 8
  store ptr %352, ptr %arm_ptr.751, align 8
  br label %label_1687

label_1687:                                       ; preds = %label_1692, %label_1684
  %353 = load ptr, ptr %arm_ptr.751, align 8
  %354 = call i32 @str_equals(ptr %353, ptr @.str.s649)
  %355 = icmp eq i32 %354, 0
  br i1 %355, label %label_1688, label %label_1689

label_1689:                                       ; preds = %label_1687
  %356 = load i1, ptr %needs_final_br.750, align 1
  br i1 %356, label %label_1699, label %label_1701

label_1688:                                       ; preds = %label_1687
  %357 = load ptr, ptr %arm_ptr.751, align 8
  %358 = call ptr @ptr_to_node(ptr %357)
  store ptr %358, ptr %arm.752, align 8
  %359 = load ptr, ptr %arm.752, align 8
  %360 = getelementptr inbounds nuw %ASTNode, ptr %359, i32 0, i32 1
  %361 = load ptr, ptr %360, align 8
  %362 = call i32 @str_equals(ptr %361, ptr @.str.s650)
  %363 = icmp eq i32 %362, 1
  br i1 %363, label %label_1690, label %label_1691

label_1691:                                       ; preds = %label_1688
  %364 = load ptr, ptr %arm.752, align 8
  %365 = getelementptr inbounds nuw %ASTNode, ptr %364, i32 0, i32 5
  %366 = load ptr, ptr %365, align 8
  %367 = call ptr @ptr_to_node(ptr %366)
  %368 = call ptr @generate_expression__Struct_ASTNode(ptr %367)
  store ptr %368, ptr %pat_val.753, align 8
  %369 = load ptr, ptr %scrut_type.748, align 8
  %370 = load ptr, ptr %scrut_val.747, align 8
  %371 = load ptr, ptr %pat_val.753, align 8
  %372 = call i32 @ir_icmp_eq(ptr %369, ptr %370, ptr %371)
  store i32 %372, ptr %cmp.754, align 4
  %373 = call i32 @ir_get_label()
  store i32 %373, ptr %arm_label.755, align 4
  %374 = call i32 @ir_get_label()
  store i32 %374, ptr %next_label.756, align 4
  %375 = load i32, ptr %cmp.754, align 4
  %376 = call ptr @ir_get_temp_name(i32 %375)
  %377 = load i32, ptr %arm_label.755, align 4
  %378 = load i32, ptr %next_label.756, align 4
  call void @ir_cond_br_numbered(ptr %376, i32 %377, i32 %378)
  %379 = load i32, ptr %arm_label.755, align 4
  call void @ir_label_numbered(i32 %379)
  %380 = load ptr, ptr %arm.752, align 8
  %381 = getelementptr inbounds nuw %ASTNode, ptr %380, i32 0, i32 6
  %382 = load ptr, ptr %381, align 8
  %383 = call ptr @ptr_to_node(ptr %382)
  call void @generate_block__Struct_ASTNode(ptr %383)
  %384 = call i32 @ir_has_returned()
  %385 = icmp eq i32 %384, 0
  br i1 %385, label %label_1696, label %label_1698

label_1690:                                       ; preds = %label_1688
  %386 = load ptr, ptr %arm.752, align 8
  %387 = getelementptr inbounds nuw %ASTNode, ptr %386, i32 0, i32 6
  %388 = load ptr, ptr %387, align 8
  %389 = call ptr @ptr_to_node(ptr %388)
  call void @generate_block__Struct_ASTNode(ptr %389)
  %390 = call i32 @ir_has_returned()
  %391 = icmp eq i32 %390, 0
  br i1 %391, label %label_1693, label %label_1695

label_1695:                                       ; preds = %label_1693, %label_1690
  call void @ir_clear_returned()
  store i1 false, ptr %needs_final_br.750, align 1
  br label %label_1692

label_1693:                                       ; preds = %label_1690
  %392 = load i32, ptr %end_label.749, align 4
  call void @ir_br_numbered(i32 %392)
  br label %label_1695

label_1692:                                       ; preds = %label_1698, %label_1695
  %393 = load ptr, ptr %arm.752, align 8
  %394 = getelementptr inbounds nuw %ASTNode, ptr %393, i32 0, i32 8
  %395 = load ptr, ptr %394, align 8
  store ptr %395, ptr %arm_ptr.751, align 8
  br label %label_1687

label_1698:                                       ; preds = %label_1696, %label_1691
  call void @ir_clear_returned()
  %396 = load i32, ptr %next_label.756, align 4
  call void @ir_label_numbered(i32 %396)
  store i1 true, ptr %needs_final_br.750, align 1
  br label %label_1692

label_1696:                                       ; preds = %label_1691
  %397 = load i32, ptr %end_label.749, align 4
  call void @ir_br_numbered(i32 %397)
  br label %label_1698

label_1701:                                       ; preds = %label_1699, %label_1689
  %398 = load i32, ptr %end_label.749, align 4
  call void @ir_label_numbered(i32 %398)
  br label %label_1686

label_1699:                                       ; preds = %label_1689
  %399 = load i32, ptr %end_label.749, align 4
  call void @ir_br_numbered(i32 %399)
  br label %label_1701
}

define void @generate_block__Struct_ASTNode(ptr %0) {
entry:
  %block.757 = alloca ptr, align 8
  store ptr %0, ptr %block.757, align 8
  call void @ir_scope_push()
  %1 = load ptr, ptr %block.757, align 8
  %2 = getelementptr inbounds nuw %ASTNode, ptr %1, i32 0, i32 5
  %3 = load ptr, ptr %2, align 8
  %stmt_ptr.758 = alloca ptr, align 8
  store ptr %3, ptr %stmt_ptr.758, align 8
  %stmt.759 = alloca ptr, align 8
  br label %label_1702

label_1702:                                       ; preds = %label_1703, %entry
  %4 = load ptr, ptr %stmt_ptr.758, align 8
  %5 = call i32 @str_equals(ptr %4, ptr @.str.s651)
  %6 = icmp eq i32 %5, 0
  br i1 %6, label %label_1703, label %label_1704

label_1704:                                       ; preds = %label_1702
  call void @ir_scope_pop()
  ret void

label_1703:                                       ; preds = %label_1702
  %7 = load ptr, ptr %stmt_ptr.758, align 8
  %8 = call ptr @ptr_to_node(ptr %7)
  store ptr %8, ptr %stmt.759, align 8
  %9 = load ptr, ptr %stmt.759, align 8
  call void @generate_statement__Struct_ASTNode(ptr %9)
  %10 = load ptr, ptr %stmt.759, align 8
  %11 = getelementptr inbounds nuw %ASTNode, ptr %10, i32 0, i32 8
  %12 = load ptr, ptr %11, align 8
  store ptr %12, ptr %stmt_ptr.758, align 8
  br label %label_1702
}

define void @generate_function__Struct_ASTNode(ptr %0) {
entry:
  %func.760 = alloca ptr, align 8
  store ptr %0, ptr %func.760, align 8
  %1 = load ptr, ptr %func.760, align 8
  %2 = getelementptr inbounds nuw %ASTNode, ptr %1, i32 0, i32 1
  %3 = load ptr, ptr %2, align 8
  %func_name.761 = alloca ptr, align 8
  store ptr %3, ptr %func_name.761, align 8
  %4 = load ptr, ptr %func.760, align 8
  %5 = call ptr @function_symbol_name__Struct_ASTNode(ptr %4)
  %emitted_name.762 = alloca ptr, align 8
  store ptr %5, ptr %emitted_name.762, align 8
  %ret_type.763 = alloca ptr, align 8
  store ptr @.str.s652, ptr %ret_type.763, align 8
  %6 = load ptr, ptr %func.760, align 8
  %7 = getelementptr inbounds nuw %ASTNode, ptr %6, i32 0, i32 7
  %8 = load ptr, ptr %7, align 8
  %9 = call i32 @str_equals(ptr %8, ptr @.str.s653)
  %10 = icmp eq i32 %9, 0
  %ret_node.764 = alloca ptr, align 8
  %is_main.765 = alloca i32, align 4
  %ret_sig_type.766 = alloca ptr, align 8
  %param_ptr.767 = alloca ptr, align 8
  %param_node.768 = alloca ptr, align 8
  %p_type_node.769 = alloca ptr, align 8
  %param_ptr2.770 = alloca ptr, align 8
  %param_node.771 = alloca ptr, align 8
  %p_type_node.772 = alloca ptr, align 8
  %p_type_str.773 = alloca ptr, align 8
  %p_store_type.774 = alloca ptr, align 8
  %p_slot.775 = alloca ptr, align 8
  br i1 %10, label %label_1705, label %label_1707

label_1707:                                       ; preds = %label_1705, %entry
  store i32 0, ptr %is_main.765, align 4
  %11 = load ptr, ptr %func_name.761, align 8
  %12 = call i32 @str_equals(ptr %11, ptr @.str.s654)
  %13 = icmp eq i32 %12, 1
  br i1 %13, label %label_1708, label %label_1710

label_1705:                                       ; preds = %entry
  %14 = load ptr, ptr %func.760, align 8
  %15 = getelementptr inbounds nuw %ASTNode, ptr %14, i32 0, i32 7
  %16 = load ptr, ptr %15, align 8
  %17 = call ptr @ptr_to_node(ptr %16)
  store ptr %17, ptr %ret_node.764, align 8
  %18 = load ptr, ptr %ret_node.764, align 8
  %19 = call ptr @map_type_node__Struct_ASTNode(ptr %18)
  store ptr %19, ptr %ret_type.763, align 8
  br label %label_1707

label_1710:                                       ; preds = %label_1708, %label_1707
  %20 = load ptr, ptr %ret_type.763, align 8
  %21 = call ptr @storage_type__String(ptr %20)
  store ptr %21, ptr %ret_sig_type.766, align 8
  %22 = load ptr, ptr %emitted_name.762, align 8
  %23 = load ptr, ptr %ret_sig_type.766, align 8
  call void @ir_function_begin(ptr %22, ptr %23)
  %24 = load i32, ptr %is_main.765, align 4
  %25 = icmp eq i32 %24, 1
  br i1 %25, label %label_1711, label %label_1713

label_1708:                                       ; preds = %label_1707
  store ptr @.str.s655, ptr %ret_type.763, align 8
  store i32 1, ptr %is_main.765, align 4
  br label %label_1710

label_1713:                                       ; preds = %label_1711, %label_1710
  %26 = load ptr, ptr %func.760, align 8
  %27 = getelementptr inbounds nuw %ASTNode, ptr %26, i32 0, i32 5
  %28 = load ptr, ptr %27, align 8
  store ptr %28, ptr %param_ptr.767, align 8
  br label %label_1714

label_1711:                                       ; preds = %label_1710
  call void @ir_function_param(ptr @.str.s656, ptr @.str.s657)
  call void @ir_function_param(ptr @.str.s658, ptr @.str.s659)
  br label %label_1713

label_1714:                                       ; preds = %label_1715, %label_1713
  %29 = load ptr, ptr %param_ptr.767, align 8
  %30 = call i32 @str_equals(ptr %29, ptr @.str.s660)
  %31 = icmp eq i32 %30, 0
  br i1 %31, label %label_1715, label %label_1716

label_1716:                                       ; preds = %label_1714
  call void @ir_function_body_start()
  call void @ir_clear_local_var_types()
  call void @ir_clear_returned()
  %32 = load i32, ptr %is_main.765, align 4
  %33 = icmp eq i32 %32, 1
  br i1 %33, label %label_1717, label %label_1719

label_1715:                                       ; preds = %label_1714
  %34 = load ptr, ptr %param_ptr.767, align 8
  %35 = call ptr @ptr_to_node(ptr %34)
  store ptr %35, ptr %param_node.768, align 8
  %36 = load ptr, ptr %param_node.768, align 8
  %37 = getelementptr inbounds nuw %ASTNode, ptr %36, i32 0, i32 5
  %38 = load ptr, ptr %37, align 8
  %39 = call ptr @ptr_to_node(ptr %38)
  store ptr %39, ptr %p_type_node.769, align 8
  %40 = load ptr, ptr %p_type_node.769, align 8
  %41 = call ptr @map_type_node__Struct_ASTNode(ptr %40)
  %42 = call ptr @storage_type__String(ptr %41)
  %43 = load ptr, ptr %param_node.768, align 8
  %44 = getelementptr inbounds nuw %ASTNode, ptr %43, i32 0, i32 1
  %45 = load ptr, ptr %44, align 8
  %46 = call ptr @str_concat(ptr @.str.s661, ptr %45)
  call void @ir_function_param(ptr %42, ptr %46)
  %47 = load ptr, ptr %param_node.768, align 8
  %48 = getelementptr inbounds nuw %ASTNode, ptr %47, i32 0, i32 8
  %49 = load ptr, ptr %48, align 8
  store ptr %49, ptr %param_ptr.767, align 8
  br label %label_1714

label_1719:                                       ; preds = %label_1717, %label_1716
  call void @ir_scope_push()
  %50 = load ptr, ptr %func.760, align 8
  %51 = getelementptr inbounds nuw %ASTNode, ptr %50, i32 0, i32 5
  %52 = load ptr, ptr %51, align 8
  store ptr %52, ptr %param_ptr2.770, align 8
  br label %label_1720

label_1717:                                       ; preds = %label_1716
  call void @ir_store_global(ptr @.str.s662, ptr @.str.s663, ptr @.str.s664)
  call void @ir_store_global(ptr @.str.s665, ptr @.str.s666, ptr @.str.s667)
  br label %label_1719

label_1720:                                       ; preds = %label_1721, %label_1719
  %53 = load ptr, ptr %param_ptr2.770, align 8
  %54 = call i32 @str_equals(ptr %53, ptr @.str.s668)
  %55 = icmp eq i32 %54, 0
  br i1 %55, label %label_1721, label %label_1722

label_1722:                                       ; preds = %label_1720
  %56 = load ptr, ptr %func.760, align 8
  %57 = getelementptr inbounds nuw %ASTNode, ptr %56, i32 0, i32 6
  %58 = load ptr, ptr %57, align 8
  %59 = call i32 @str_equals(ptr %58, ptr @.str.s670)
  %60 = icmp eq i32 %59, 0
  br i1 %60, label %label_1723, label %label_1725

label_1721:                                       ; preds = %label_1720
  %61 = load ptr, ptr %param_ptr2.770, align 8
  %62 = call ptr @ptr_to_node(ptr %61)
  store ptr %62, ptr %param_node.771, align 8
  %63 = load ptr, ptr %param_node.771, align 8
  %64 = getelementptr inbounds nuw %ASTNode, ptr %63, i32 0, i32 5
  %65 = load ptr, ptr %64, align 8
  %66 = call ptr @ptr_to_node(ptr %65)
  store ptr %66, ptr %p_type_node.772, align 8
  %67 = load ptr, ptr %p_type_node.772, align 8
  %68 = call ptr @map_type_node__Struct_ASTNode(ptr %67)
  store ptr %68, ptr %p_type_str.773, align 8
  %69 = load ptr, ptr %p_type_str.773, align 8
  %70 = call ptr @storage_type__String(ptr %69)
  store ptr %70, ptr %p_store_type.774, align 8
  %71 = load ptr, ptr %param_node.771, align 8
  %72 = getelementptr inbounds nuw %ASTNode, ptr %71, i32 0, i32 1
  %73 = load ptr, ptr %72, align 8
  %74 = load ptr, ptr %p_type_str.773, align 8
  call void @ir_set_var_type(ptr %73, ptr %74)
  %75 = load ptr, ptr %param_node.771, align 8
  %76 = getelementptr inbounds nuw %ASTNode, ptr %75, i32 0, i32 1
  %77 = load ptr, ptr %76, align 8
  %78 = call ptr @ir_get_var_slot(ptr %77)
  store ptr %78, ptr %p_slot.775, align 8
  %79 = load ptr, ptr %p_store_type.774, align 8
  %80 = load ptr, ptr %p_slot.775, align 8
  %81 = call i32 @ir_alloca(ptr %79, ptr %80)
  %82 = load ptr, ptr %p_store_type.774, align 8
  %83 = load ptr, ptr %param_node.771, align 8
  %84 = getelementptr inbounds nuw %ASTNode, ptr %83, i32 0, i32 1
  %85 = load ptr, ptr %84, align 8
  %86 = call ptr @str_concat(ptr @.str.s669, ptr %85)
  %87 = load ptr, ptr %p_slot.775, align 8
  call void @ir_store(ptr %82, ptr %86, ptr %87)
  %88 = load ptr, ptr %param_node.771, align 8
  %89 = getelementptr inbounds nuw %ASTNode, ptr %88, i32 0, i32 8
  %90 = load ptr, ptr %89, align 8
  store ptr %90, ptr %param_ptr2.770, align 8
  br label %label_1720

label_1725:                                       ; preds = %label_1723, %label_1722
  call void @ir_scope_pop()
  %91 = call i32 @ir_has_returned()
  %92 = icmp eq i32 %91, 0
  br i1 %92, label %label_1726, label %label_1728

label_1723:                                       ; preds = %label_1722
  %93 = load ptr, ptr %func.760, align 8
  %94 = getelementptr inbounds nuw %ASTNode, ptr %93, i32 0, i32 6
  %95 = load ptr, ptr %94, align 8
  %96 = call ptr @ptr_to_node(ptr %95)
  call void @generate_block__Struct_ASTNode(ptr %96)
  br label %label_1725

label_1728:                                       ; preds = %label_1731, %label_1725
  call void @ir_function_end()
  ret void

label_1726:                                       ; preds = %label_1725
  %97 = load ptr, ptr %ret_sig_type.766, align 8
  %98 = call i32 @str_equals(ptr %97, ptr @.str.s671)
  %99 = icmp eq i32 %98, 1
  br i1 %99, label %label_1729, label %label_1730

label_1730:                                       ; preds = %label_1726
  %100 = load i32, ptr %is_main.765, align 4
  %101 = icmp eq i32 %100, 1
  br i1 %101, label %label_1732, label %label_1733

label_1729:                                       ; preds = %label_1726
  call void @ir_ret_void()
  br label %label_1731

label_1731:                                       ; preds = %label_1734, %label_1729
  br label %label_1728

label_1733:                                       ; preds = %label_1730
  %102 = load ptr, ptr %ret_sig_type.766, align 8
  call void @ir_ret(ptr %102, ptr @.str.s674)
  br label %label_1734

label_1732:                                       ; preds = %label_1730
  call void @ir_ret(ptr @.str.s672, ptr @.str.s673)
  br label %label_1734

label_1734:                                       ; preds = %label_1733, %label_1732
  br label %label_1731
}

define void @collect_strings_expr__Struct_ASTNode(ptr %0) {
entry:
  %expr.776 = alloca ptr, align 8
  store ptr %0, ptr %expr.776, align 8
  %1 = load ptr, ptr %expr.776, align 8
  %2 = getelementptr inbounds nuw %ASTNode, ptr %1, i32 0, i32 0
  %3 = load i32, ptr %2, align 4
  %4 = icmp eq i32 %3, 22
  %str_name.777 = alloca ptr, align 8
  %sc.89 = alloca i1, align 1
  %arg_ptr.778 = alloca ptr, align 8
  %arg_node.779 = alloca ptr, align 8
  %elem_ptr.780 = alloca ptr, align 8
  %elem_node.781 = alloca ptr, align 8
  %field_ptr.782 = alloca ptr, align 8
  %field.783 = alloca ptr, align 8
  br i1 %4, label %label_1735, label %label_1737

label_1737:                                       ; preds = %label_1740, %entry
  %5 = load ptr, ptr %expr.776, align 8
  %6 = getelementptr inbounds nuw %ASTNode, ptr %5, i32 0, i32 0
  %7 = load i32, ptr %6, align 4
  %8 = icmp eq i32 %7, 21
  store i1 %8, ptr %sc.89, align 1
  br i1 %8, label %label_1742, label %label_1741

label_1735:                                       ; preds = %entry
  %9 = load ptr, ptr %expr.776, align 8
  %10 = getelementptr inbounds nuw %ASTNode, ptr %9, i32 0, i32 3
  %11 = load i32, ptr %10, align 4
  %12 = icmp eq i32 %11, 0
  br i1 %12, label %label_1738, label %label_1740

label_1740:                                       ; preds = %label_1738, %label_1735
  br label %label_1737

label_1738:                                       ; preds = %label_1735
  %13 = load i32, ptr @ir_string_counter, align 4
  %14 = call ptr @int_to_str(i32 %13)
  %15 = call ptr @str_concat(ptr @.str.s675, ptr %14)
  store ptr %15, ptr %str_name.777, align 8
  %16 = load i32, ptr @ir_string_counter, align 4
  %17 = add i32 %16, 1
  store i32 %17, ptr @ir_string_counter, align 4
  %18 = load ptr, ptr %str_name.777, align 8
  %19 = load ptr, ptr %expr.776, align 8
  %20 = getelementptr inbounds nuw %ASTNode, ptr %19, i32 0, i32 1
  %21 = load ptr, ptr %20, align 8
  call void @ir_global_string(ptr %18, ptr %21)
  %22 = load ptr, ptr %expr.776, align 8
  %23 = load ptr, ptr %str_name.777, align 8
  %24 = getelementptr inbounds nuw %ASTNode, ptr %22, i32 0, i32 2
  store ptr %23, ptr %24, align 8
  br label %label_1740

label_1741:                                       ; preds = %label_1737
  %25 = load ptr, ptr %expr.776, align 8
  %26 = getelementptr inbounds nuw %ASTNode, ptr %25, i32 0, i32 0
  %27 = load i32, ptr %26, align 4
  %28 = icmp eq i32 %27, 29
  store i1 %28, ptr %sc.89, align 1
  br label %label_1742

label_1742:                                       ; preds = %label_1741, %label_1737
  %29 = load i1, ptr %sc.89, align 1
  br i1 %29, label %label_1743, label %label_1745

label_1745:                                       ; preds = %label_1748, %label_1742
  %30 = load ptr, ptr %expr.776, align 8
  %31 = getelementptr inbounds nuw %ASTNode, ptr %30, i32 0, i32 0
  %32 = load i32, ptr %31, align 4
  %33 = icmp eq i32 %32, 20
  br i1 %33, label %label_1749, label %label_1751

label_1743:                                       ; preds = %label_1742
  %34 = load ptr, ptr %expr.776, align 8
  %35 = getelementptr inbounds nuw %ASTNode, ptr %34, i32 0, i32 5
  %36 = load ptr, ptr %35, align 8
  %37 = call i32 @str_equals(ptr %36, ptr @.str.s676)
  %38 = icmp eq i32 %37, 0
  br i1 %38, label %label_1746, label %label_1748

label_1748:                                       ; preds = %label_1746, %label_1743
  br label %label_1745

label_1746:                                       ; preds = %label_1743
  %39 = load ptr, ptr %expr.776, align 8
  %40 = getelementptr inbounds nuw %ASTNode, ptr %39, i32 0, i32 5
  %41 = load ptr, ptr %40, align 8
  %42 = call ptr @ptr_to_node(ptr %41)
  call void @collect_strings_expr__Struct_ASTNode(ptr %42)
  br label %label_1748

label_1751:                                       ; preds = %label_1757, %label_1745
  %43 = load ptr, ptr %expr.776, align 8
  %44 = getelementptr inbounds nuw %ASTNode, ptr %43, i32 0, i32 0
  %45 = load i32, ptr %44, align 4
  %46 = icmp eq i32 %45, 24
  br i1 %46, label %label_1758, label %label_1760

label_1749:                                       ; preds = %label_1745
  %47 = load ptr, ptr %expr.776, align 8
  %48 = getelementptr inbounds nuw %ASTNode, ptr %47, i32 0, i32 5
  %49 = load ptr, ptr %48, align 8
  %50 = call i32 @str_equals(ptr %49, ptr @.str.s677)
  %51 = icmp eq i32 %50, 0
  br i1 %51, label %label_1752, label %label_1754

label_1754:                                       ; preds = %label_1752, %label_1749
  %52 = load ptr, ptr %expr.776, align 8
  %53 = getelementptr inbounds nuw %ASTNode, ptr %52, i32 0, i32 6
  %54 = load ptr, ptr %53, align 8
  %55 = call i32 @str_equals(ptr %54, ptr @.str.s678)
  %56 = icmp eq i32 %55, 0
  br i1 %56, label %label_1755, label %label_1757

label_1752:                                       ; preds = %label_1749
  %57 = load ptr, ptr %expr.776, align 8
  %58 = getelementptr inbounds nuw %ASTNode, ptr %57, i32 0, i32 5
  %59 = load ptr, ptr %58, align 8
  %60 = call ptr @ptr_to_node(ptr %59)
  call void @collect_strings_expr__Struct_ASTNode(ptr %60)
  br label %label_1754

label_1757:                                       ; preds = %label_1755, %label_1754
  br label %label_1751

label_1755:                                       ; preds = %label_1754
  %61 = load ptr, ptr %expr.776, align 8
  %62 = getelementptr inbounds nuw %ASTNode, ptr %61, i32 0, i32 6
  %63 = load ptr, ptr %62, align 8
  %64 = call ptr @ptr_to_node(ptr %63)
  call void @collect_strings_expr__Struct_ASTNode(ptr %64)
  br label %label_1757

label_1760:                                       ; preds = %label_1763, %label_1751
  %65 = load ptr, ptr %expr.776, align 8
  %66 = getelementptr inbounds nuw %ASTNode, ptr %65, i32 0, i32 0
  %67 = load i32, ptr %66, align 4
  %68 = icmp eq i32 %67, 27
  br i1 %68, label %label_1764, label %label_1766

label_1758:                                       ; preds = %label_1751
  %69 = load ptr, ptr %expr.776, align 8
  %70 = getelementptr inbounds nuw %ASTNode, ptr %69, i32 0, i32 6
  %71 = load ptr, ptr %70, align 8
  store ptr %71, ptr %arg_ptr.778, align 8
  br label %label_1761

label_1761:                                       ; preds = %label_1762, %label_1758
  %72 = load ptr, ptr %arg_ptr.778, align 8
  %73 = call i32 @str_equals(ptr %72, ptr @.str.s679)
  %74 = icmp eq i32 %73, 0
  br i1 %74, label %label_1762, label %label_1763

label_1763:                                       ; preds = %label_1761
  br label %label_1760

label_1762:                                       ; preds = %label_1761
  %75 = load ptr, ptr %arg_ptr.778, align 8
  %76 = call ptr @ptr_to_node(ptr %75)
  store ptr %76, ptr %arg_node.779, align 8
  %77 = load ptr, ptr %arg_node.779, align 8
  call void @collect_strings_expr__Struct_ASTNode(ptr %77)
  %78 = load ptr, ptr %arg_node.779, align 8
  %79 = getelementptr inbounds nuw %ASTNode, ptr %78, i32 0, i32 8
  %80 = load ptr, ptr %79, align 8
  store ptr %80, ptr %arg_ptr.778, align 8
  br label %label_1761

label_1766:                                       ; preds = %label_1769, %label_1760
  %81 = load ptr, ptr %expr.776, align 8
  %82 = getelementptr inbounds nuw %ASTNode, ptr %81, i32 0, i32 0
  %83 = load i32, ptr %82, align 4
  %84 = icmp eq i32 %83, 26
  br i1 %84, label %label_1770, label %label_1772

label_1764:                                       ; preds = %label_1760
  %85 = load ptr, ptr %expr.776, align 8
  %86 = getelementptr inbounds nuw %ASTNode, ptr %85, i32 0, i32 5
  %87 = load ptr, ptr %86, align 8
  store ptr %87, ptr %elem_ptr.780, align 8
  br label %label_1767

label_1767:                                       ; preds = %label_1768, %label_1764
  %88 = load ptr, ptr %elem_ptr.780, align 8
  %89 = call i32 @str_equals(ptr %88, ptr @.str.s680)
  %90 = icmp eq i32 %89, 0
  br i1 %90, label %label_1768, label %label_1769

label_1769:                                       ; preds = %label_1767
  br label %label_1766

label_1768:                                       ; preds = %label_1767
  %91 = load ptr, ptr %elem_ptr.780, align 8
  %92 = call ptr @ptr_to_node(ptr %91)
  store ptr %92, ptr %elem_node.781, align 8
  %93 = load ptr, ptr %elem_node.781, align 8
  call void @collect_strings_expr__Struct_ASTNode(ptr %93)
  %94 = load ptr, ptr %elem_node.781, align 8
  %95 = getelementptr inbounds nuw %ASTNode, ptr %94, i32 0, i32 8
  %96 = load ptr, ptr %95, align 8
  store ptr %96, ptr %elem_ptr.780, align 8
  br label %label_1767

label_1772:                                       ; preds = %label_1778, %label_1766
  %97 = load ptr, ptr %expr.776, align 8
  %98 = getelementptr inbounds nuw %ASTNode, ptr %97, i32 0, i32 0
  %99 = load i32, ptr %98, align 4
  %100 = icmp eq i32 %99, 25
  br i1 %100, label %label_1779, label %label_1781

label_1770:                                       ; preds = %label_1766
  %101 = load ptr, ptr %expr.776, align 8
  %102 = getelementptr inbounds nuw %ASTNode, ptr %101, i32 0, i32 5
  %103 = load ptr, ptr %102, align 8
  %104 = call i32 @str_equals(ptr %103, ptr @.str.s681)
  %105 = icmp eq i32 %104, 0
  br i1 %105, label %label_1773, label %label_1775

label_1775:                                       ; preds = %label_1773, %label_1770
  %106 = load ptr, ptr %expr.776, align 8
  %107 = getelementptr inbounds nuw %ASTNode, ptr %106, i32 0, i32 6
  %108 = load ptr, ptr %107, align 8
  %109 = call i32 @str_equals(ptr %108, ptr @.str.s682)
  %110 = icmp eq i32 %109, 0
  br i1 %110, label %label_1776, label %label_1778

label_1773:                                       ; preds = %label_1770
  %111 = load ptr, ptr %expr.776, align 8
  %112 = getelementptr inbounds nuw %ASTNode, ptr %111, i32 0, i32 5
  %113 = load ptr, ptr %112, align 8
  %114 = call ptr @ptr_to_node(ptr %113)
  call void @collect_strings_expr__Struct_ASTNode(ptr %114)
  br label %label_1775

label_1778:                                       ; preds = %label_1776, %label_1775
  br label %label_1772

label_1776:                                       ; preds = %label_1775
  %115 = load ptr, ptr %expr.776, align 8
  %116 = getelementptr inbounds nuw %ASTNode, ptr %115, i32 0, i32 6
  %117 = load ptr, ptr %116, align 8
  %118 = call ptr @ptr_to_node(ptr %117)
  call void @collect_strings_expr__Struct_ASTNode(ptr %118)
  br label %label_1778

label_1781:                                       ; preds = %label_1784, %label_1772
  %119 = load ptr, ptr %expr.776, align 8
  %120 = getelementptr inbounds nuw %ASTNode, ptr %119, i32 0, i32 0
  %121 = load i32, ptr %120, align 4
  %122 = icmp eq i32 %121, 28
  br i1 %122, label %label_1785, label %label_1787

label_1779:                                       ; preds = %label_1772
  %123 = load ptr, ptr %expr.776, align 8
  %124 = getelementptr inbounds nuw %ASTNode, ptr %123, i32 0, i32 5
  %125 = load ptr, ptr %124, align 8
  %126 = call i32 @str_equals(ptr %125, ptr @.str.s683)
  %127 = icmp eq i32 %126, 0
  br i1 %127, label %label_1782, label %label_1784

label_1784:                                       ; preds = %label_1782, %label_1779
  br label %label_1781

label_1782:                                       ; preds = %label_1779
  %128 = load ptr, ptr %expr.776, align 8
  %129 = getelementptr inbounds nuw %ASTNode, ptr %128, i32 0, i32 5
  %130 = load ptr, ptr %129, align 8
  %131 = call ptr @ptr_to_node(ptr %130)
  call void @collect_strings_expr__Struct_ASTNode(ptr %131)
  br label %label_1784

label_1787:                                       ; preds = %label_1790, %label_1781
  ret void

label_1785:                                       ; preds = %label_1781
  %132 = load ptr, ptr %expr.776, align 8
  %133 = getelementptr inbounds nuw %ASTNode, ptr %132, i32 0, i32 5
  %134 = load ptr, ptr %133, align 8
  store ptr %134, ptr %field_ptr.782, align 8
  br label %label_1788

label_1788:                                       ; preds = %label_1793, %label_1785
  %135 = load ptr, ptr %field_ptr.782, align 8
  %136 = call i32 @str_equals(ptr %135, ptr @.str.s684)
  %137 = icmp eq i32 %136, 0
  br i1 %137, label %label_1789, label %label_1790

label_1790:                                       ; preds = %label_1788
  br label %label_1787

label_1789:                                       ; preds = %label_1788
  %138 = load ptr, ptr %field_ptr.782, align 8
  %139 = call ptr @ptr_to_node(ptr %138)
  store ptr %139, ptr %field.783, align 8
  %140 = load ptr, ptr %field.783, align 8
  %141 = getelementptr inbounds nuw %ASTNode, ptr %140, i32 0, i32 5
  %142 = load ptr, ptr %141, align 8
  %143 = call i32 @str_equals(ptr %142, ptr @.str.s685)
  %144 = icmp eq i32 %143, 0
  br i1 %144, label %label_1791, label %label_1793

label_1793:                                       ; preds = %label_1791, %label_1789
  %145 = load ptr, ptr %field.783, align 8
  %146 = getelementptr inbounds nuw %ASTNode, ptr %145, i32 0, i32 8
  %147 = load ptr, ptr %146, align 8
  store ptr %147, ptr %field_ptr.782, align 8
  br label %label_1788

label_1791:                                       ; preds = %label_1789
  %148 = load ptr, ptr %field.783, align 8
  %149 = getelementptr inbounds nuw %ASTNode, ptr %148, i32 0, i32 5
  %150 = load ptr, ptr %149, align 8
  %151 = call ptr @ptr_to_node(ptr %150)
  call void @collect_strings_expr__Struct_ASTNode(ptr %151)
  br label %label_1793
}

define void @declare_extern_function__Struct_ASTNode(ptr %0) {
entry:
  %ext.784 = alloca ptr, align 8
  store ptr %0, ptr %ext.784, align 8
  %1 = load ptr, ptr %ext.784, align 8
  %2 = load ptr, ptr %ext.784, align 8
  %3 = getelementptr inbounds nuw %ASTNode, ptr %2, i32 0, i32 6
  %4 = load ptr, ptr %3, align 8
  %5 = call ptr @get_declared_return_type__Struct_ASTNode_String(ptr %1, ptr %4)
  %ret_type.785 = alloca ptr, align 8
  store ptr %5, ptr %ret_type.785, align 8
  %6 = load ptr, ptr %ext.784, align 8
  %7 = call ptr @function_symbol_name__Struct_ASTNode(ptr %6)
  %8 = call ptr @fn_key__String(ptr %7)
  %9 = load ptr, ptr %ret_type.785, align 8
  call void @ir_set_var_type(ptr %8, ptr %9)
  %10 = load ptr, ptr %ext.784, align 8
  %11 = call ptr @function_symbol_name__Struct_ASTNode(ptr %10)
  %12 = load ptr, ptr %ret_type.785, align 8
  %13 = call ptr @storage_type__String(ptr %12)
  call void @ir_declare_function_begin(ptr %11, ptr %13)
  %14 = load ptr, ptr %ext.784, align 8
  %15 = getelementptr inbounds nuw %ASTNode, ptr %14, i32 0, i32 5
  %16 = load ptr, ptr %15, align 8
  %param_ptr.786 = alloca ptr, align 8
  store ptr %16, ptr %param_ptr.786, align 8
  %param_node.787 = alloca ptr, align 8
  %p_type_node.788 = alloca ptr, align 8
  br label %label_1794

label_1794:                                       ; preds = %label_1795, %entry
  %17 = load ptr, ptr %param_ptr.786, align 8
  %18 = call i32 @str_equals(ptr %17, ptr @.str.s686)
  %19 = icmp eq i32 %18, 0
  br i1 %19, label %label_1795, label %label_1796

label_1796:                                       ; preds = %label_1794
  call void @ir_declare_function_end()
  ret void

label_1795:                                       ; preds = %label_1794
  %20 = load ptr, ptr %param_ptr.786, align 8
  %21 = call ptr @ptr_to_node(ptr %20)
  store ptr %21, ptr %param_node.787, align 8
  %22 = load ptr, ptr %param_node.787, align 8
  %23 = getelementptr inbounds nuw %ASTNode, ptr %22, i32 0, i32 5
  %24 = load ptr, ptr %23, align 8
  %25 = call ptr @ptr_to_node(ptr %24)
  store ptr %25, ptr %p_type_node.788, align 8
  %26 = load ptr, ptr %p_type_node.788, align 8
  %27 = call ptr @map_type_node__Struct_ASTNode(ptr %26)
  %28 = call ptr @storage_type__String(ptr %27)
  call void @ir_declare_function_param(ptr %28)
  %29 = load ptr, ptr %param_node.787, align 8
  %30 = getelementptr inbounds nuw %ASTNode, ptr %29, i32 0, i32 8
  %31 = load ptr, ptr %30, align 8
  store ptr %31, ptr %param_ptr.786, align 8
  br label %label_1794
}

define i1 @module_has_function__Struct_ASTNode_String(ptr %0, ptr %1) {
entry:
  %module.789 = alloca ptr, align 8
  store ptr %0, ptr %module.789, align 8
  %name.790 = alloca ptr, align 8
  store ptr %1, ptr %name.790, align 8
  %2 = load ptr, ptr %module.789, align 8
  %3 = getelementptr inbounds nuw %ASTNode, ptr %2, i32 0, i32 5
  %4 = load ptr, ptr %3, align 8
  %stmt_ptr.791 = alloca ptr, align 8
  store ptr %4, ptr %stmt_ptr.791, align 8
  %stmt.792 = alloca ptr, align 8
  %sc.90 = alloca i1, align 1
  br label %label_1797

label_1797:                                       ; preds = %label_1804, %entry
  %5 = load ptr, ptr %stmt_ptr.791, align 8
  %6 = call i32 @str_equals(ptr %5, ptr @.str.s687)
  %7 = icmp eq i32 %6, 0
  br i1 %7, label %label_1798, label %label_1799

label_1799:                                       ; preds = %label_1797
  ret i1 false

label_1798:                                       ; preds = %label_1797
  %8 = load ptr, ptr %stmt_ptr.791, align 8
  %9 = call ptr @ptr_to_node(ptr %8)
  store ptr %9, ptr %stmt.792, align 8
  %10 = load ptr, ptr %stmt.792, align 8
  %11 = getelementptr inbounds nuw %ASTNode, ptr %10, i32 0, i32 0
  %12 = load i32, ptr %11, align 4
  %13 = icmp eq i32 %12, 4
  store i1 %13, ptr %sc.90, align 1
  br i1 %13, label %label_1800, label %label_1801

label_1801:                                       ; preds = %label_1800, %label_1798
  %14 = load i1, ptr %sc.90, align 1
  br i1 %14, label %label_1802, label %label_1804

label_1800:                                       ; preds = %label_1798
  %15 = load ptr, ptr %stmt.792, align 8
  %16 = getelementptr inbounds nuw %ASTNode, ptr %15, i32 0, i32 1
  %17 = load ptr, ptr %16, align 8
  %18 = load ptr, ptr %name.790, align 8
  %19 = call i32 @str_equals(ptr %17, ptr %18)
  %20 = icmp eq i32 %19, 1
  store i1 %20, ptr %sc.90, align 1
  br label %label_1801

label_1804:                                       ; preds = %label_1801
  %21 = load ptr, ptr %stmt.792, align 8
  %22 = getelementptr inbounds nuw %ASTNode, ptr %21, i32 0, i32 8
  %23 = load ptr, ptr %22, align 8
  store ptr %23, ptr %stmt_ptr.791, align 8
  br label %label_1797

label_1802:                                       ; preds = %label_1801
  ret i1 true
}

define void @register_enum_decl__Struct_ASTNode(ptr %0) {
entry:
  %enum_node.793 = alloca ptr, align 8
  store ptr %0, ptr %enum_node.793, align 8
  %1 = load ptr, ptr %enum_node.793, align 8
  %2 = getelementptr inbounds nuw %ASTNode, ptr %1, i32 0, i32 5
  %3 = load ptr, ptr %2, align 8
  %variant_ptr.794 = alloca ptr, align 8
  store ptr %3, ptr %variant_ptr.794, align 8
  %value.795 = alloca i32, align 4
  store i32 0, ptr %value.795, align 4
  %variant.796 = alloca ptr, align 8
  br label %label_1805

label_1805:                                       ; preds = %label_1806, %entry
  %4 = load ptr, ptr %variant_ptr.794, align 8
  %5 = call i32 @str_equals(ptr %4, ptr @.str.s688)
  %6 = icmp eq i32 %5, 0
  br i1 %6, label %label_1806, label %label_1807

label_1807:                                       ; preds = %label_1805
  ret void

label_1806:                                       ; preds = %label_1805
  %7 = load ptr, ptr %variant_ptr.794, align 8
  %8 = call ptr @ptr_to_node(ptr %7)
  store ptr %8, ptr %variant.796, align 8
  %9 = load ptr, ptr %enum_node.793, align 8
  %10 = getelementptr inbounds nuw %ASTNode, ptr %9, i32 0, i32 1
  %11 = load ptr, ptr %10, align 8
  %12 = load ptr, ptr %variant.796, align 8
  %13 = getelementptr inbounds nuw %ASTNode, ptr %12, i32 0, i32 1
  %14 = load ptr, ptr %13, align 8
  %15 = load i32, ptr %value.795, align 4
  call void @ir_register_enum_variant(ptr %11, ptr %14, i32 %15)
  %16 = load i32, ptr %value.795, align 4
  %17 = add i32 %16, 1
  store i32 %17, ptr %value.795, align 4
  %18 = load ptr, ptr %variant.796, align 8
  %19 = getelementptr inbounds nuw %ASTNode, ptr %18, i32 0, i32 8
  %20 = load ptr, ptr %19, align 8
  store ptr %20, ptr %variant_ptr.794, align 8
  br label %label_1805
}

define void @register_struct_name__Struct_ASTNode(ptr %0) {
entry:
  %struct_node.797 = alloca ptr, align 8
  store ptr %0, ptr %struct_node.797, align 8
  %1 = load ptr, ptr %struct_node.797, align 8
  %2 = getelementptr inbounds nuw %ASTNode, ptr %1, i32 0, i32 1
  %3 = load ptr, ptr %2, align 8
  call void @ir_register_struct(ptr %3)
  ret void
}

define void @generate_struct_decl__Struct_ASTNode(ptr %0) {
entry:
  %struct_node.798 = alloca ptr, align 8
  store ptr %0, ptr %struct_node.798, align 8
  %1 = load ptr, ptr %struct_node.798, align 8
  %2 = getelementptr inbounds nuw %ASTNode, ptr %1, i32 0, i32 5
  %3 = load ptr, ptr %2, align 8
  %first_field_ptr.799 = alloca ptr, align 8
  store ptr %3, ptr %first_field_ptr.799, align 8
  %4 = load ptr, ptr %first_field_ptr.799, align 8
  %5 = call i32 @str_equals(ptr %4, ptr @.str.s689)
  %6 = icmp eq i32 %5, 0
  %first_field.800 = alloca ptr, align 8
  %field_ptr.801 = alloca ptr, align 8
  %field.802 = alloca ptr, align 8
  %type_node.803 = alloca ptr, align 8
  %field_type.804 = alloca ptr, align 8
  br i1 %6, label %label_1808, label %label_1810

label_1810:                                       ; preds = %label_1813, %entry
  %7 = load ptr, ptr %struct_node.798, align 8
  %8 = getelementptr inbounds nuw %ASTNode, ptr %7, i32 0, i32 1
  %9 = load ptr, ptr %8, align 8
  call void @ir_struct_type_begin(ptr %9)
  %10 = load ptr, ptr %struct_node.798, align 8
  %11 = getelementptr inbounds nuw %ASTNode, ptr %10, i32 0, i32 5
  %12 = load ptr, ptr %11, align 8
  store ptr %12, ptr %field_ptr.801, align 8
  br label %label_1814

label_1808:                                       ; preds = %entry
  %13 = load ptr, ptr %first_field_ptr.799, align 8
  %14 = call ptr @ptr_to_node(ptr %13)
  store ptr %14, ptr %first_field.800, align 8
  %15 = load ptr, ptr %struct_node.798, align 8
  %16 = getelementptr inbounds nuw %ASTNode, ptr %15, i32 0, i32 1
  %17 = load ptr, ptr %16, align 8
  %18 = load ptr, ptr %first_field.800, align 8
  %19 = getelementptr inbounds nuw %ASTNode, ptr %18, i32 0, i32 1
  %20 = load ptr, ptr %19, align 8
  %21 = call i32 @ir_get_struct_field_index(ptr %17, ptr %20)
  %22 = icmp sge i32 %21, 0
  br i1 %22, label %label_1811, label %label_1813

label_1813:                                       ; preds = %label_1808
  br label %label_1810

label_1811:                                       ; preds = %label_1808
  ret void

label_1814:                                       ; preds = %label_1815, %label_1810
  %23 = load ptr, ptr %field_ptr.801, align 8
  %24 = call i32 @str_equals(ptr %23, ptr @.str.s690)
  %25 = icmp eq i32 %24, 0
  br i1 %25, label %label_1815, label %label_1816

label_1816:                                       ; preds = %label_1814
  call void @ir_struct_type_end()
  ret void

label_1815:                                       ; preds = %label_1814
  %26 = load ptr, ptr %field_ptr.801, align 8
  %27 = call ptr @ptr_to_node(ptr %26)
  store ptr %27, ptr %field.802, align 8
  %28 = load ptr, ptr %field.802, align 8
  %29 = getelementptr inbounds nuw %ASTNode, ptr %28, i32 0, i32 5
  %30 = load ptr, ptr %29, align 8
  %31 = call ptr @ptr_to_node(ptr %30)
  store ptr %31, ptr %type_node.803, align 8
  %32 = load ptr, ptr %type_node.803, align 8
  %33 = call ptr @map_type_node__Struct_ASTNode(ptr %32)
  %34 = call ptr @storage_type__String(ptr %33)
  store ptr %34, ptr %field_type.804, align 8
  %35 = load ptr, ptr %struct_node.798, align 8
  %36 = getelementptr inbounds nuw %ASTNode, ptr %35, i32 0, i32 1
  %37 = load ptr, ptr %36, align 8
  %38 = load ptr, ptr %field.802, align 8
  %39 = getelementptr inbounds nuw %ASTNode, ptr %38, i32 0, i32 1
  %40 = load ptr, ptr %39, align 8
  %41 = load ptr, ptr %field_type.804, align 8
  call void @ir_register_struct_field(ptr %37, ptr %40, ptr %41)
  %42 = load ptr, ptr %field_type.804, align 8
  call void @ir_struct_type_field(ptr %42)
  %43 = load ptr, ptr %field.802, align 8
  %44 = getelementptr inbounds nuw %ASTNode, ptr %43, i32 0, i32 8
  %45 = load ptr, ptr %44, align 8
  store ptr %45, ptr %field_ptr.801, align 8
  br label %label_1814
}

define void @collect_strings_child_expr__String(ptr %0) {
entry:
  %child.805 = alloca ptr, align 8
  store ptr %0, ptr %child.805, align 8
  %1 = load ptr, ptr %child.805, align 8
  %2 = call i32 @str_equals(ptr %1, ptr @.str.s691)
  %3 = icmp eq i32 %2, 0
  br i1 %3, label %label_1817, label %label_1819

label_1819:                                       ; preds = %label_1817, %entry
  ret void

label_1817:                                       ; preds = %entry
  %4 = load ptr, ptr %child.805, align 8
  %5 = call ptr @ptr_to_node(ptr %4)
  call void @collect_strings_expr__Struct_ASTNode(ptr %5)
  br label %label_1819
}

define void @collect_strings_child_block__String(ptr %0) {
entry:
  %child.806 = alloca ptr, align 8
  store ptr %0, ptr %child.806, align 8
  %1 = load ptr, ptr %child.806, align 8
  %2 = call i32 @str_equals(ptr %1, ptr @.str.s692)
  %3 = icmp eq i32 %2, 0
  br i1 %3, label %label_1820, label %label_1822

label_1822:                                       ; preds = %label_1820, %entry
  ret void

label_1820:                                       ; preds = %entry
  %4 = load ptr, ptr %child.806, align 8
  %5 = call ptr @ptr_to_node(ptr %4)
  call void @collect_strings_block__Struct_ASTNode(ptr %5)
  br label %label_1822
}

define void @collect_strings_block__Struct_ASTNode(ptr %0) {
entry:
  %block.811 = alloca ptr, align 8
  store ptr %0, ptr %block.811, align 8
  %1 = load ptr, ptr %block.811, align 8
  %2 = getelementptr inbounds nuw %ASTNode, ptr %1, i32 0, i32 5
  %3 = load ptr, ptr %2, align 8
  %s_ptr.812 = alloca ptr, align 8
  store ptr %3, ptr %s_ptr.812, align 8
  %s.813 = alloca ptr, align 8
  br label %label_1859

label_1859:                                       ; preds = %label_1860, %entry
  %4 = load ptr, ptr %s_ptr.812, align 8
  %5 = call i32 @str_equals(ptr %4, ptr @.str.s695)
  %6 = icmp eq i32 %5, 0
  br i1 %6, label %label_1860, label %label_1861

label_1861:                                       ; preds = %label_1859
  ret void

label_1860:                                       ; preds = %label_1859
  %7 = load ptr, ptr %s_ptr.812, align 8
  %8 = call ptr @ptr_to_node(ptr %7)
  store ptr %8, ptr %s.813, align 8
  %9 = load ptr, ptr %s.813, align 8
  call void @collect_strings_stmt__Struct_ASTNode(ptr %9)
  %10 = load ptr, ptr %s.813, align 8
  %11 = getelementptr inbounds nuw %ASTNode, ptr %10, i32 0, i32 8
  %12 = load ptr, ptr %11, align 8
  store ptr %12, ptr %s_ptr.812, align 8
  br label %label_1859
}

define void @collect_strings_stmt__Struct_ASTNode(ptr %0) {
entry:
  %stmt.807 = alloca ptr, align 8
  store ptr %0, ptr %stmt.807, align 8
  %1 = load ptr, ptr %stmt.807, align 8
  %2 = getelementptr inbounds nuw %ASTNode, ptr %1, i32 0, i32 0
  %3 = load i32, ptr %2, align 4
  %4 = icmp eq i32 %3, 3
  %else_node.808 = alloca ptr, align 8
  %arm_ptr.809 = alloca ptr, align 8
  %arm.810 = alloca ptr, align 8
  br i1 %4, label %label_1823, label %label_1825

label_1825:                                       ; preds = %label_1823, %entry
  %5 = load ptr, ptr %stmt.807, align 8
  %6 = getelementptr inbounds nuw %ASTNode, ptr %5, i32 0, i32 0
  %7 = load i32, ptr %6, align 4
  %8 = icmp eq i32 %7, 17
  br i1 %8, label %label_1826, label %label_1828

label_1823:                                       ; preds = %entry
  %9 = load ptr, ptr %stmt.807, align 8
  %10 = getelementptr inbounds nuw %ASTNode, ptr %9, i32 0, i32 6
  %11 = load ptr, ptr %10, align 8
  call void @collect_strings_child_expr__String(ptr %11)
  br label %label_1825

label_1828:                                       ; preds = %label_1826, %label_1825
  %12 = load ptr, ptr %stmt.807, align 8
  %13 = getelementptr inbounds nuw %ASTNode, ptr %12, i32 0, i32 0
  %14 = load i32, ptr %13, align 4
  %15 = icmp eq i32 %14, 15
  br i1 %15, label %label_1829, label %label_1831

label_1826:                                       ; preds = %label_1825
  %16 = load ptr, ptr %stmt.807, align 8
  %17 = getelementptr inbounds nuw %ASTNode, ptr %16, i32 0, i32 5
  %18 = load ptr, ptr %17, align 8
  call void @collect_strings_child_expr__String(ptr %18)
  br label %label_1828

label_1831:                                       ; preds = %label_1829, %label_1828
  %19 = load ptr, ptr %stmt.807, align 8
  %20 = getelementptr inbounds nuw %ASTNode, ptr %19, i32 0, i32 0
  %21 = load i32, ptr %20, align 4
  %22 = icmp eq i32 %21, 16
  br i1 %22, label %label_1832, label %label_1834

label_1829:                                       ; preds = %label_1828
  %23 = load ptr, ptr %stmt.807, align 8
  %24 = getelementptr inbounds nuw %ASTNode, ptr %23, i32 0, i32 5
  %25 = load ptr, ptr %24, align 8
  call void @collect_strings_child_expr__String(ptr %25)
  br label %label_1831

label_1834:                                       ; preds = %label_1832, %label_1831
  %26 = load ptr, ptr %stmt.807, align 8
  %27 = getelementptr inbounds nuw %ASTNode, ptr %26, i32 0, i32 0
  %28 = load i32, ptr %27, align 4
  %29 = icmp eq i32 %28, 10
  br i1 %29, label %label_1835, label %label_1837

label_1832:                                       ; preds = %label_1831
  %30 = load ptr, ptr %stmt.807, align 8
  %31 = getelementptr inbounds nuw %ASTNode, ptr %30, i32 0, i32 5
  %32 = load ptr, ptr %31, align 8
  call void @collect_strings_child_expr__String(ptr %32)
  %33 = load ptr, ptr %stmt.807, align 8
  %34 = getelementptr inbounds nuw %ASTNode, ptr %33, i32 0, i32 6
  %35 = load ptr, ptr %34, align 8
  call void @collect_strings_child_expr__String(ptr %35)
  br label %label_1834

label_1837:                                       ; preds = %label_1840, %label_1834
  %36 = load ptr, ptr %stmt.807, align 8
  %37 = getelementptr inbounds nuw %ASTNode, ptr %36, i32 0, i32 0
  %38 = load i32, ptr %37, align 4
  %39 = icmp eq i32 %38, 13
  br i1 %39, label %label_1844, label %label_1846

label_1835:                                       ; preds = %label_1834
  %40 = load ptr, ptr %stmt.807, align 8
  %41 = getelementptr inbounds nuw %ASTNode, ptr %40, i32 0, i32 5
  %42 = load ptr, ptr %41, align 8
  call void @collect_strings_child_expr__String(ptr %42)
  %43 = load ptr, ptr %stmt.807, align 8
  %44 = getelementptr inbounds nuw %ASTNode, ptr %43, i32 0, i32 6
  %45 = load ptr, ptr %44, align 8
  call void @collect_strings_child_block__String(ptr %45)
  %46 = load ptr, ptr %stmt.807, align 8
  %47 = getelementptr inbounds nuw %ASTNode, ptr %46, i32 0, i32 7
  %48 = load ptr, ptr %47, align 8
  %49 = call i32 @str_equals(ptr %48, ptr @.str.s693)
  %50 = icmp eq i32 %49, 0
  br i1 %50, label %label_1838, label %label_1840

label_1840:                                       ; preds = %label_1843, %label_1835
  br label %label_1837

label_1838:                                       ; preds = %label_1835
  %51 = load ptr, ptr %stmt.807, align 8
  %52 = getelementptr inbounds nuw %ASTNode, ptr %51, i32 0, i32 7
  %53 = load ptr, ptr %52, align 8
  %54 = call ptr @ptr_to_node(ptr %53)
  store ptr %54, ptr %else_node.808, align 8
  %55 = load ptr, ptr %else_node.808, align 8
  %56 = getelementptr inbounds nuw %ASTNode, ptr %55, i32 0, i32 0
  %57 = load i32, ptr %56, align 4
  %58 = icmp eq i32 %57, 10
  br i1 %58, label %label_1841, label %label_1842

label_1842:                                       ; preds = %label_1838
  %59 = load ptr, ptr %else_node.808, align 8
  call void @collect_strings_block__Struct_ASTNode(ptr %59)
  br label %label_1843

label_1841:                                       ; preds = %label_1838
  %60 = load ptr, ptr %else_node.808, align 8
  call void @collect_strings_stmt__Struct_ASTNode(ptr %60)
  br label %label_1843

label_1843:                                       ; preds = %label_1842, %label_1841
  br label %label_1840

label_1846:                                       ; preds = %label_1844, %label_1837
  %61 = load ptr, ptr %stmt.807, align 8
  %62 = getelementptr inbounds nuw %ASTNode, ptr %61, i32 0, i32 0
  %63 = load i32, ptr %62, align 4
  %64 = icmp eq i32 %63, 14
  br i1 %64, label %label_1847, label %label_1849

label_1844:                                       ; preds = %label_1837
  %65 = load ptr, ptr %stmt.807, align 8
  %66 = getelementptr inbounds nuw %ASTNode, ptr %65, i32 0, i32 5
  %67 = load ptr, ptr %66, align 8
  call void @collect_strings_child_expr__String(ptr %67)
  %68 = load ptr, ptr %stmt.807, align 8
  %69 = getelementptr inbounds nuw %ASTNode, ptr %68, i32 0, i32 6
  %70 = load ptr, ptr %69, align 8
  call void @collect_strings_child_block__String(ptr %70)
  br label %label_1846

label_1849:                                       ; preds = %label_1847, %label_1846
  %71 = load ptr, ptr %stmt.807, align 8
  %72 = getelementptr inbounds nuw %ASTNode, ptr %71, i32 0, i32 0
  %73 = load i32, ptr %72, align 4
  %74 = icmp eq i32 %73, 12
  br i1 %74, label %label_1850, label %label_1852

label_1847:                                       ; preds = %label_1846
  %75 = load ptr, ptr %stmt.807, align 8
  %76 = getelementptr inbounds nuw %ASTNode, ptr %75, i32 0, i32 5
  %77 = load ptr, ptr %76, align 8
  call void @collect_strings_child_block__String(ptr %77)
  br label %label_1849

label_1852:                                       ; preds = %label_1850, %label_1849
  %78 = load ptr, ptr %stmt.807, align 8
  %79 = getelementptr inbounds nuw %ASTNode, ptr %78, i32 0, i32 0
  %80 = load i32, ptr %79, align 4
  %81 = icmp eq i32 %80, 11
  br i1 %81, label %label_1853, label %label_1855

label_1850:                                       ; preds = %label_1849
  %82 = load ptr, ptr %stmt.807, align 8
  %83 = getelementptr inbounds nuw %ASTNode, ptr %82, i32 0, i32 5
  %84 = load ptr, ptr %83, align 8
  call void @collect_strings_child_expr__String(ptr %84)
  %85 = load ptr, ptr %stmt.807, align 8
  %86 = getelementptr inbounds nuw %ASTNode, ptr %85, i32 0, i32 6
  %87 = load ptr, ptr %86, align 8
  call void @collect_strings_child_expr__String(ptr %87)
  %88 = load ptr, ptr %stmt.807, align 8
  %89 = getelementptr inbounds nuw %ASTNode, ptr %88, i32 0, i32 7
  %90 = load ptr, ptr %89, align 8
  call void @collect_strings_child_block__String(ptr %90)
  br label %label_1852

label_1855:                                       ; preds = %label_1858, %label_1852
  ret void

label_1853:                                       ; preds = %label_1852
  %91 = load ptr, ptr %stmt.807, align 8
  %92 = getelementptr inbounds nuw %ASTNode, ptr %91, i32 0, i32 5
  %93 = load ptr, ptr %92, align 8
  call void @collect_strings_child_expr__String(ptr %93)
  %94 = load ptr, ptr %stmt.807, align 8
  %95 = getelementptr inbounds nuw %ASTNode, ptr %94, i32 0, i32 6
  %96 = load ptr, ptr %95, align 8
  store ptr %96, ptr %arm_ptr.809, align 8
  br label %label_1856

label_1856:                                       ; preds = %label_1857, %label_1853
  %97 = load ptr, ptr %arm_ptr.809, align 8
  %98 = call i32 @str_equals(ptr %97, ptr @.str.s694)
  %99 = icmp eq i32 %98, 0
  br i1 %99, label %label_1857, label %label_1858

label_1858:                                       ; preds = %label_1856
  br label %label_1855

label_1857:                                       ; preds = %label_1856
  %100 = load ptr, ptr %arm_ptr.809, align 8
  %101 = call ptr @ptr_to_node(ptr %100)
  store ptr %101, ptr %arm.810, align 8
  %102 = load ptr, ptr %arm.810, align 8
  %103 = getelementptr inbounds nuw %ASTNode, ptr %102, i32 0, i32 5
  %104 = load ptr, ptr %103, align 8
  call void @collect_strings_child_expr__String(ptr %104)
  %105 = load ptr, ptr %arm.810, align 8
  %106 = getelementptr inbounds nuw %ASTNode, ptr %105, i32 0, i32 6
  %107 = load ptr, ptr %106, align 8
  call void @collect_strings_child_block__String(ptr %107)
  %108 = load ptr, ptr %arm.810, align 8
  %109 = getelementptr inbounds nuw %ASTNode, ptr %108, i32 0, i32 8
  %110 = load ptr, ptr %109, align 8
  store ptr %110, ptr %arm_ptr.809, align 8
  br label %label_1856
}

define void @collect_strings_function__Struct_ASTNode(ptr %0) {
entry:
  %func.814 = alloca ptr, align 8
  store ptr %0, ptr %func.814, align 8
  %1 = load ptr, ptr %func.814, align 8
  %2 = getelementptr inbounds nuw %ASTNode, ptr %1, i32 0, i32 6
  %3 = load ptr, ptr %2, align 8
  %4 = call i32 @str_equals(ptr %3, ptr @.str.s696)
  %5 = icmp eq i32 %4, 0
  br i1 %5, label %label_1862, label %label_1864

label_1864:                                       ; preds = %label_1862, %entry
  ret void

label_1862:                                       ; preds = %entry
  %6 = load ptr, ptr %func.814, align 8
  %7 = getelementptr inbounds nuw %ASTNode, ptr %6, i32 0, i32 6
  %8 = load ptr, ptr %7, align 8
  %9 = call ptr @ptr_to_node(ptr %8)
  call void @collect_strings_block__Struct_ASTNode(ptr %9)
  br label %label_1864
}

define void @generate_module__Struct_ASTNode(ptr %0) {
entry:
  %module.815 = alloca ptr, align 8
  store ptr %0, ptr %module.815, align 8
  call void @ir_reset_globals()
  call void @ir_reset_types()
  call void @ir_clear_var_types()
  %1 = call ptr @ir_ptr_int_type__Void()
  call void @ir_set_pointer_int_type(ptr %1)
  %2 = load i1, ptr @ir_target_wasm, align 1
  %type_stmt_ptr.816 = alloca ptr, align 8
  %type_stmt.817 = alloca ptr, align 8
  %struct_stmt_ptr.818 = alloca ptr, align 8
  %struct_stmt.819 = alloca ptr, align 8
  %stmt_ptr.820 = alloca ptr, align 8
  %stmt.821 = alloca ptr, align 8
  %init_val.822 = alloca ptr, align 8
  %var_type.823 = alloca ptr, align 8
  %has_annotation.824 = alloca i1, align 1
  %type_node.825 = alloca ptr, align 8
  %init_node.826 = alloca ptr, align 8
  %ret_type.827 = alloca ptr, align 8
  %stmt_ptr2.828 = alloca ptr, align 8
  %stmt2.829 = alloca ptr, align 8
  br i1 %2, label %label_1865, label %label_1866

label_1866:                                       ; preds = %entry
  call void @ir_module_start(ptr @.str.s698)
  br label %label_1867

label_1865:                                       ; preds = %entry
  call void @ir_module_start_wasm(ptr @.str.s697)
  br label %label_1867

label_1867:                                       ; preds = %label_1866, %label_1865
  %3 = load ptr, ptr %module.815, align 8
  %4 = getelementptr inbounds nuw %ASTNode, ptr %3, i32 0, i32 5
  %5 = load ptr, ptr %4, align 8
  store ptr %5, ptr %type_stmt_ptr.816, align 8
  br label %label_1868

label_1868:                                       ; preds = %label_1876, %label_1867
  %6 = load ptr, ptr %type_stmt_ptr.816, align 8
  %7 = call i32 @str_equals(ptr %6, ptr @.str.s699)
  %8 = icmp eq i32 %7, 0
  br i1 %8, label %label_1869, label %label_1870

label_1870:                                       ; preds = %label_1868
  %9 = load ptr, ptr %module.815, align 8
  %10 = getelementptr inbounds nuw %ASTNode, ptr %9, i32 0, i32 5
  %11 = load ptr, ptr %10, align 8
  store ptr %11, ptr %struct_stmt_ptr.818, align 8
  br label %label_1877

label_1869:                                       ; preds = %label_1868
  %12 = load ptr, ptr %type_stmt_ptr.816, align 8
  %13 = call ptr @ptr_to_node(ptr %12)
  store ptr %13, ptr %type_stmt.817, align 8
  %14 = load ptr, ptr %type_stmt.817, align 8
  %15 = getelementptr inbounds nuw %ASTNode, ptr %14, i32 0, i32 0
  %16 = load i32, ptr %15, align 4
  %17 = icmp eq i32 %16, 6
  br i1 %17, label %label_1871, label %label_1873

label_1873:                                       ; preds = %label_1871, %label_1869
  %18 = load ptr, ptr %type_stmt.817, align 8
  %19 = getelementptr inbounds nuw %ASTNode, ptr %18, i32 0, i32 0
  %20 = load i32, ptr %19, align 4
  %21 = icmp eq i32 %20, 5
  br i1 %21, label %label_1874, label %label_1876

label_1871:                                       ; preds = %label_1869
  %22 = load ptr, ptr %type_stmt.817, align 8
  call void @register_enum_decl__Struct_ASTNode(ptr %22)
  br label %label_1873

label_1876:                                       ; preds = %label_1874, %label_1873
  %23 = load ptr, ptr %type_stmt.817, align 8
  %24 = getelementptr inbounds nuw %ASTNode, ptr %23, i32 0, i32 8
  %25 = load ptr, ptr %24, align 8
  store ptr %25, ptr %type_stmt_ptr.816, align 8
  br label %label_1868

label_1874:                                       ; preds = %label_1873
  %26 = load ptr, ptr %type_stmt.817, align 8
  call void @register_struct_name__Struct_ASTNode(ptr %26)
  br label %label_1876

label_1877:                                       ; preds = %label_1882, %label_1870
  %27 = load ptr, ptr %struct_stmt_ptr.818, align 8
  %28 = call i32 @str_equals(ptr %27, ptr @.str.s700)
  %29 = icmp eq i32 %28, 0
  br i1 %29, label %label_1878, label %label_1879

label_1879:                                       ; preds = %label_1877
  call void @ir_blank_line()
  call void @ir_global_var(ptr @.str.s701, ptr @.str.s702, ptr @.str.s703, i32 0)
  call void @ir_global_var(ptr @.str.s704, ptr @.str.s705, ptr @.str.s706, i32 0)
  call void @ir_declare_function_begin(ptr @.str.s707, ptr @.str.s708)
  %30 = call ptr @ir_ptr_int_type__Void()
  call void @ir_declare_function_param(ptr %30)
  call void @ir_declare_function_end()
  call void @ir_declare_function_begin(ptr @.str.s709, ptr @.str.s710)
  call void @ir_declare_function_param(ptr @.str.s711)
  call void @ir_declare_function_end()
  call void @ir_declare_function_begin(ptr @.str.s712, ptr @.str.s713)
  call void @ir_declare_function_end()
  call void @ir_declare_function_begin(ptr @.str.s714, ptr @.str.s715)
  call void @ir_declare_function_param(ptr @.str.s716)
  call void @ir_declare_function_param(ptr @.str.s717)
  call void @ir_declare_function_end()
  call void @ir_declare_function_begin(ptr @.str.s718, ptr @.str.s719)
  call void @ir_declare_function_param(ptr @.str.s720)
  call void @ir_declare_function_param(ptr @.str.s721)
  call void @ir_declare_function_end()
  call void @ir_declare_function_begin(ptr @.str.s722, ptr @.str.s723)
  call void @ir_declare_function_param(ptr @.str.s724)
  call void @ir_declare_function_param(ptr @.str.s725)
  call void @ir_declare_function_param(ptr @.str.s726)
  call void @ir_declare_function_end()
  call void @ir_declare_function_begin(ptr @.str.s727, ptr @.str.s728)
  call void @ir_declare_function_param(ptr @.str.s729)
  call void @ir_declare_function_end()
  call void @ir_declare_function_begin(ptr @.str.s730, ptr @.str.s731)
  call void @ir_declare_function_param(ptr @.str.s732)
  call void @ir_declare_function_end()
  call void @ir_declare_function_begin(ptr @.str.s733, ptr @.str.s734)
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
  call void @ir_blank_line()
  %31 = load ptr, ptr %module.815, align 8
  %32 = getelementptr inbounds nuw %ASTNode, ptr %31, i32 0, i32 5
  %33 = load ptr, ptr %32, align 8
  store ptr %33, ptr %stmt_ptr.820, align 8
  br label %label_1883

label_1878:                                       ; preds = %label_1877
  %34 = load ptr, ptr %struct_stmt_ptr.818, align 8
  %35 = call ptr @ptr_to_node(ptr %34)
  store ptr %35, ptr %struct_stmt.819, align 8
  %36 = load ptr, ptr %struct_stmt.819, align 8
  %37 = getelementptr inbounds nuw %ASTNode, ptr %36, i32 0, i32 0
  %38 = load i32, ptr %37, align 4
  %39 = icmp eq i32 %38, 5
  br i1 %39, label %label_1880, label %label_1882

label_1882:                                       ; preds = %label_1880, %label_1878
  %40 = load ptr, ptr %struct_stmt.819, align 8
  %41 = getelementptr inbounds nuw %ASTNode, ptr %40, i32 0, i32 8
  %42 = load ptr, ptr %41, align 8
  store ptr %42, ptr %struct_stmt_ptr.818, align 8
  br label %label_1877

label_1880:                                       ; preds = %label_1878
  %43 = load ptr, ptr %struct_stmt.819, align 8
  call void @generate_struct_decl__Struct_ASTNode(ptr %43)
  br label %label_1882

label_1883:                                       ; preds = %label_1912, %label_1879
  %44 = load ptr, ptr %stmt_ptr.820, align 8
  %45 = call i32 @str_equals(ptr %44, ptr @.str.s760)
  %46 = icmp eq i32 %45, 0
  br i1 %46, label %label_1884, label %label_1885

label_1885:                                       ; preds = %label_1883
  call void @ir_blank_line()
  %47 = load ptr, ptr %module.815, align 8
  %48 = getelementptr inbounds nuw %ASTNode, ptr %47, i32 0, i32 5
  %49 = load ptr, ptr %48, align 8
  store ptr %49, ptr %stmt_ptr2.828, align 8
  br label %label_1916

label_1884:                                       ; preds = %label_1883
  %50 = load ptr, ptr %stmt_ptr.820, align 8
  %51 = call ptr @ptr_to_node(ptr %50)
  store ptr %51, ptr %stmt.821, align 8
  %52 = load ptr, ptr %stmt.821, align 8
  %53 = getelementptr inbounds nuw %ASTNode, ptr %52, i32 0, i32 0
  %54 = load i32, ptr %53, align 4
  %55 = icmp eq i32 %54, 2
  br i1 %55, label %label_1886, label %label_1888

label_1888:                                       ; preds = %label_1891, %label_1884
  %56 = load ptr, ptr %stmt.821, align 8
  %57 = getelementptr inbounds nuw %ASTNode, ptr %56, i32 0, i32 0
  %58 = load i32, ptr %57, align 4
  %59 = icmp eq i32 %58, 3
  br i1 %59, label %label_1892, label %label_1894

label_1886:                                       ; preds = %label_1884
  %60 = load ptr, ptr %module.815, align 8
  %61 = load ptr, ptr %stmt.821, align 8
  %62 = getelementptr inbounds nuw %ASTNode, ptr %61, i32 0, i32 1
  %63 = load ptr, ptr %62, align 8
  %64 = call i1 @module_has_function__Struct_ASTNode_String(ptr %60, ptr %63)
  %65 = icmp eq i1 %64, false
  br i1 %65, label %label_1889, label %label_1891

label_1891:                                       ; preds = %label_1889, %label_1886
  br label %label_1888

label_1889:                                       ; preds = %label_1886
  %66 = load ptr, ptr %stmt.821, align 8
  call void @declare_extern_function__Struct_ASTNode(ptr %66)
  br label %label_1891

label_1894:                                       ; preds = %label_1900, %label_1888
  %67 = load ptr, ptr %stmt.821, align 8
  %68 = getelementptr inbounds nuw %ASTNode, ptr %67, i32 0, i32 0
  %69 = load i32, ptr %68, align 4
  %70 = icmp eq i32 %69, 4
  br i1 %70, label %label_1910, label %label_1912

label_1892:                                       ; preds = %label_1888
  store ptr @.str.s761, ptr %init_val.822, align 8
  store ptr @.str.s762, ptr %var_type.823, align 8
  %71 = load ptr, ptr %stmt.821, align 8
  %72 = getelementptr inbounds nuw %ASTNode, ptr %71, i32 0, i32 5
  %73 = load ptr, ptr %72, align 8
  %74 = call i32 @str_equals(ptr %73, ptr @.str.s763)
  %75 = icmp eq i32 %74, 0
  store i1 %75, ptr %has_annotation.824, align 1
  %76 = load i1, ptr %has_annotation.824, align 1
  br i1 %76, label %label_1895, label %label_1897

label_1897:                                       ; preds = %label_1895, %label_1892
  %77 = load ptr, ptr %stmt.821, align 8
  %78 = getelementptr inbounds nuw %ASTNode, ptr %77, i32 0, i32 6
  %79 = load ptr, ptr %78, align 8
  %80 = call i32 @str_equals(ptr %79, ptr @.str.s764)
  %81 = icmp eq i32 %80, 0
  br i1 %81, label %label_1898, label %label_1900

label_1895:                                       ; preds = %label_1892
  %82 = load ptr, ptr %stmt.821, align 8
  %83 = getelementptr inbounds nuw %ASTNode, ptr %82, i32 0, i32 5
  %84 = load ptr, ptr %83, align 8
  %85 = call ptr @ptr_to_node(ptr %84)
  store ptr %85, ptr %type_node.825, align 8
  %86 = load ptr, ptr %type_node.825, align 8
  %87 = call ptr @map_type_node__Struct_ASTNode(ptr %86)
  store ptr %87, ptr %var_type.823, align 8
  br label %label_1897

label_1900:                                       ; preds = %label_1906, %label_1897
  %88 = load ptr, ptr %stmt.821, align 8
  %89 = getelementptr inbounds nuw %ASTNode, ptr %88, i32 0, i32 1
  %90 = load ptr, ptr %89, align 8
  %91 = load ptr, ptr %var_type.823, align 8
  %92 = call ptr @storage_type__String(ptr %91)
  %93 = load ptr, ptr %init_val.822, align 8
  call void @ir_global_var(ptr %90, ptr %92, ptr %93, i32 0)
  %94 = load ptr, ptr %stmt.821, align 8
  %95 = getelementptr inbounds nuw %ASTNode, ptr %94, i32 0, i32 1
  %96 = load ptr, ptr %95, align 8
  call void @ir_register_global_name(ptr %96)
  %97 = load ptr, ptr %stmt.821, align 8
  %98 = getelementptr inbounds nuw %ASTNode, ptr %97, i32 0, i32 1
  %99 = load ptr, ptr %98, align 8
  %100 = load ptr, ptr %var_type.823, align 8
  call void @ir_set_global_var_type(ptr %99, ptr %100)
  br label %label_1894

label_1898:                                       ; preds = %label_1897
  %101 = load ptr, ptr %stmt.821, align 8
  %102 = getelementptr inbounds nuw %ASTNode, ptr %101, i32 0, i32 6
  %103 = load ptr, ptr %102, align 8
  %104 = call ptr @ptr_to_node(ptr %103)
  store ptr %104, ptr %init_node.826, align 8
  %105 = load i1, ptr %has_annotation.824, align 1
  %106 = icmp eq i1 %105, false
  br i1 %106, label %label_1901, label %label_1903

label_1903:                                       ; preds = %label_1901, %label_1898
  %107 = load ptr, ptr %init_node.826, align 8
  %108 = getelementptr inbounds nuw %ASTNode, ptr %107, i32 0, i32 0
  %109 = load i32, ptr %108, align 4
  %110 = icmp eq i32 %109, 22
  br i1 %110, label %label_1904, label %label_1905

label_1901:                                       ; preds = %label_1898
  %111 = load ptr, ptr %init_node.826, align 8
  %112 = call ptr @get_expr_type__Struct_ASTNode(ptr %111)
  store ptr %112, ptr %var_type.823, align 8
  br label %label_1903

label_1905:                                       ; preds = %label_1903
  call void @print(ptr @.str.s766)
  %113 = load ptr, ptr %stmt.821, align 8
  %114 = getelementptr inbounds nuw %ASTNode, ptr %113, i32 0, i32 1
  %115 = load ptr, ptr %114, align 8
  call void @print(ptr %115)
  call void @println(ptr @.str.s767)
  call void @exit(i32 1)
  br label %label_1906

label_1904:                                       ; preds = %label_1903
  %116 = load ptr, ptr %init_node.826, align 8
  %117 = getelementptr inbounds nuw %ASTNode, ptr %116, i32 0, i32 3
  %118 = load i32, ptr %117, align 4
  %119 = icmp eq i32 %118, 0
  br i1 %119, label %label_1907, label %label_1908

label_1908:                                       ; preds = %label_1904
  %120 = load ptr, ptr %init_node.826, align 8
  %121 = getelementptr inbounds nuw %ASTNode, ptr %120, i32 0, i32 1
  %122 = load ptr, ptr %121, align 8
  store ptr %122, ptr %init_val.822, align 8
  br label %label_1909

label_1907:                                       ; preds = %label_1904
  %123 = load ptr, ptr %init_node.826, align 8
  call void @collect_strings_expr__Struct_ASTNode(ptr %123)
  %124 = load ptr, ptr %init_node.826, align 8
  %125 = getelementptr inbounds nuw %ASTNode, ptr %124, i32 0, i32 2
  %126 = load ptr, ptr %125, align 8
  %127 = call ptr @str_concat(ptr @.str.s765, ptr %126)
  store ptr %127, ptr %init_val.822, align 8
  br label %label_1909

label_1909:                                       ; preds = %label_1908, %label_1907
  br label %label_1906

label_1906:                                       ; preds = %label_1905, %label_1909
  br label %label_1900

label_1912:                                       ; preds = %label_1915, %label_1894
  %128 = load ptr, ptr %stmt.821, align 8
  %129 = getelementptr inbounds nuw %ASTNode, ptr %128, i32 0, i32 8
  %130 = load ptr, ptr %129, align 8
  store ptr %130, ptr %stmt_ptr.820, align 8
  br label %label_1883

label_1910:                                       ; preds = %label_1894
  %131 = load ptr, ptr %stmt.821, align 8
  %132 = load ptr, ptr %stmt.821, align 8
  %133 = getelementptr inbounds nuw %ASTNode, ptr %132, i32 0, i32 7
  %134 = load ptr, ptr %133, align 8
  %135 = call ptr @get_declared_return_type__Struct_ASTNode_String(ptr %131, ptr %134)
  store ptr %135, ptr %ret_type.827, align 8
  %136 = load ptr, ptr %stmt.821, align 8
  %137 = getelementptr inbounds nuw %ASTNode, ptr %136, i32 0, i32 1
  %138 = load ptr, ptr %137, align 8
  %139 = call i32 @str_equals(ptr %138, ptr @.str.s768)
  %140 = icmp eq i32 %139, 1
  br i1 %140, label %label_1913, label %label_1915

label_1915:                                       ; preds = %label_1913, %label_1910
  %141 = load ptr, ptr %stmt.821, align 8
  %142 = call ptr @function_symbol_name__Struct_ASTNode(ptr %141)
  %143 = call ptr @fn_key__String(ptr %142)
  %144 = load ptr, ptr %ret_type.827, align 8
  call void @ir_set_var_type(ptr %143, ptr %144)
  %145 = load ptr, ptr %stmt.821, align 8
  call void @collect_strings_function__Struct_ASTNode(ptr %145)
  br label %label_1912

label_1913:                                       ; preds = %label_1910
  store ptr @.str.s769, ptr %ret_type.827, align 8
  br label %label_1915

label_1916:                                       ; preds = %label_1921, %label_1885
  %146 = load ptr, ptr %stmt_ptr2.828, align 8
  %147 = call i32 @str_equals(ptr %146, ptr @.str.s770)
  %148 = icmp eq i32 %147, 0
  br i1 %148, label %label_1917, label %label_1918

label_1918:                                       ; preds = %label_1916
  call void @ir_module_end()
  ret void

label_1917:                                       ; preds = %label_1916
  %149 = load ptr, ptr %stmt_ptr2.828, align 8
  %150 = call ptr @ptr_to_node(ptr %149)
  store ptr %150, ptr %stmt2.829, align 8
  %151 = load ptr, ptr %stmt2.829, align 8
  %152 = getelementptr inbounds nuw %ASTNode, ptr %151, i32 0, i32 0
  %153 = load i32, ptr %152, align 4
  %154 = icmp eq i32 %153, 4
  br i1 %154, label %label_1919, label %label_1921

label_1921:                                       ; preds = %label_1919, %label_1917
  %155 = load ptr, ptr %stmt2.829, align 8
  %156 = getelementptr inbounds nuw %ASTNode, ptr %155, i32 0, i32 8
  %157 = load ptr, ptr %156, align 8
  store ptr %157, ptr %stmt_ptr2.828, align 8
  br label %label_1916

label_1919:                                       ; preds = %label_1917
  %158 = load ptr, ptr %stmt2.829, align 8
  call void @generate_function__Struct_ASTNode(ptr %158)
  br label %label_1921
}

define i1 @sema_block_has_break__Struct_ASTNode(ptr %0) {
entry:
  %block.830 = alloca ptr, align 8
  store ptr %0, ptr %block.830, align 8
  %1 = load ptr, ptr %block.830, align 8
  %2 = getelementptr inbounds nuw %ASTNode, ptr %1, i32 0, i32 5
  %3 = load ptr, ptr %2, align 8
  %stmt_ptr.831 = alloca ptr, align 8
  store ptr %3, ptr %stmt_ptr.831, align 8
  %stmt.832 = alloca ptr, align 8
  %else_node.833 = alloca ptr, align 8
  %sc.91 = alloca i1, align 1
  %body.834 = alloca ptr, align 8
  %arm_ptr.835 = alloca ptr, align 8
  %arm.836 = alloca ptr, align 8
  br label %label_1922

label_1922:                                       ; preds = %label_1965, %entry
  %4 = load ptr, ptr %stmt_ptr.831, align 8
  %5 = call i32 @str_equals(ptr %4, ptr @.str.s771)
  %6 = icmp eq i32 %5, 0
  br i1 %6, label %label_1923, label %label_1924

label_1924:                                       ; preds = %label_1922
  ret i1 false

label_1923:                                       ; preds = %label_1922
  %7 = load ptr, ptr %stmt_ptr.831, align 8
  %8 = call ptr @ptr_to_node(ptr %7)
  store ptr %8, ptr %stmt.832, align 8
  %9 = load ptr, ptr %stmt.832, align 8
  %10 = getelementptr inbounds nuw %ASTNode, ptr %9, i32 0, i32 0
  %11 = load i32, ptr %10, align 4
  %12 = icmp eq i32 %11, 18
  br i1 %12, label %label_1925, label %label_1927

label_1927:                                       ; preds = %label_1923
  %13 = load ptr, ptr %stmt.832, align 8
  %14 = getelementptr inbounds nuw %ASTNode, ptr %13, i32 0, i32 0
  %15 = load i32, ptr %14, align 4
  %16 = icmp eq i32 %15, 10
  br i1 %16, label %label_1928, label %label_1930

label_1925:                                       ; preds = %label_1923
  ret i1 true

label_1930:                                       ; preds = %label_1936, %label_1927
  %17 = load ptr, ptr %stmt.832, align 8
  %18 = getelementptr inbounds nuw %ASTNode, ptr %17, i32 0, i32 0
  %19 = load i32, ptr %18, align 4
  %20 = icmp eq i32 %19, 13
  store i1 %20, ptr %sc.91, align 1
  br i1 %20, label %label_1947, label %label_1946

label_1928:                                       ; preds = %label_1927
  %21 = load ptr, ptr %stmt.832, align 8
  %22 = getelementptr inbounds nuw %ASTNode, ptr %21, i32 0, i32 6
  %23 = load ptr, ptr %22, align 8
  %24 = call ptr @ptr_to_node(ptr %23)
  %25 = call i1 @sema_block_has_break__Struct_ASTNode(ptr %24)
  br i1 %25, label %label_1931, label %label_1933

label_1933:                                       ; preds = %label_1928
  %26 = load ptr, ptr %stmt.832, align 8
  %27 = getelementptr inbounds nuw %ASTNode, ptr %26, i32 0, i32 7
  %28 = load ptr, ptr %27, align 8
  %29 = call i32 @str_equals(ptr %28, ptr @.str.s772)
  %30 = icmp eq i32 %29, 0
  br i1 %30, label %label_1934, label %label_1936

label_1931:                                       ; preds = %label_1928
  ret i1 true

label_1936:                                       ; preds = %label_1939, %label_1933
  br label %label_1930

label_1934:                                       ; preds = %label_1933
  %31 = load ptr, ptr %stmt.832, align 8
  %32 = getelementptr inbounds nuw %ASTNode, ptr %31, i32 0, i32 7
  %33 = load ptr, ptr %32, align 8
  %34 = call ptr @ptr_to_node(ptr %33)
  store ptr %34, ptr %else_node.833, align 8
  %35 = load ptr, ptr %else_node.833, align 8
  %36 = getelementptr inbounds nuw %ASTNode, ptr %35, i32 0, i32 0
  %37 = load i32, ptr %36, align 4
  %38 = icmp eq i32 %37, 10
  br i1 %38, label %label_1937, label %label_1938

label_1938:                                       ; preds = %label_1934
  %39 = load ptr, ptr %else_node.833, align 8
  %40 = call i1 @sema_block_has_break__Struct_ASTNode(ptr %39)
  br i1 %40, label %label_1943, label %label_1945

label_1937:                                       ; preds = %label_1934
  %41 = load ptr, ptr %else_node.833, align 8
  %42 = call i1 @sema_stmt_has_break_wrapper__Struct_ASTNode(ptr %41)
  br i1 %42, label %label_1940, label %label_1942

label_1942:                                       ; preds = %label_1937
  br label %label_1939

label_1940:                                       ; preds = %label_1937
  ret i1 true

label_1939:                                       ; preds = %label_1945, %label_1942
  br label %label_1936

label_1945:                                       ; preds = %label_1938
  br label %label_1939

label_1943:                                       ; preds = %label_1938
  ret i1 true

label_1946:                                       ; preds = %label_1930
  %43 = load ptr, ptr %stmt.832, align 8
  %44 = getelementptr inbounds nuw %ASTNode, ptr %43, i32 0, i32 0
  %45 = load i32, ptr %44, align 4
  %46 = icmp eq i32 %45, 14
  store i1 %46, ptr %sc.91, align 1
  br label %label_1947

label_1947:                                       ; preds = %label_1946, %label_1930
  %47 = load i1, ptr %sc.91, align 1
  br i1 %47, label %label_1948, label %label_1950

label_1950:                                       ; preds = %label_1956, %label_1947
  %48 = load ptr, ptr %stmt.832, align 8
  %49 = getelementptr inbounds nuw %ASTNode, ptr %48, i32 0, i32 0
  %50 = load i32, ptr %49, align 4
  %51 = icmp eq i32 %50, 12
  br i1 %51, label %label_1957, label %label_1959

label_1948:                                       ; preds = %label_1947
  %52 = load ptr, ptr %stmt.832, align 8
  %53 = getelementptr inbounds nuw %ASTNode, ptr %52, i32 0, i32 5
  %54 = load ptr, ptr %53, align 8
  %55 = call ptr @ptr_to_node(ptr %54)
  store ptr %55, ptr %body.834, align 8
  %56 = load ptr, ptr %stmt.832, align 8
  %57 = getelementptr inbounds nuw %ASTNode, ptr %56, i32 0, i32 0
  %58 = load i32, ptr %57, align 4
  %59 = icmp eq i32 %58, 13
  br i1 %59, label %label_1951, label %label_1953

label_1953:                                       ; preds = %label_1951, %label_1948
  %60 = load ptr, ptr %body.834, align 8
  %61 = call i1 @sema_block_has_break__Struct_ASTNode(ptr %60)
  br i1 %61, label %label_1954, label %label_1956

label_1951:                                       ; preds = %label_1948
  %62 = load ptr, ptr %stmt.832, align 8
  %63 = getelementptr inbounds nuw %ASTNode, ptr %62, i32 0, i32 6
  %64 = load ptr, ptr %63, align 8
  %65 = call ptr @ptr_to_node(ptr %64)
  store ptr %65, ptr %body.834, align 8
  br label %label_1953

label_1956:                                       ; preds = %label_1953
  br label %label_1950

label_1954:                                       ; preds = %label_1953
  ret i1 true

label_1959:                                       ; preds = %label_1962, %label_1950
  %66 = load ptr, ptr %stmt.832, align 8
  %67 = getelementptr inbounds nuw %ASTNode, ptr %66, i32 0, i32 0
  %68 = load i32, ptr %67, align 4
  %69 = icmp eq i32 %68, 11
  br i1 %69, label %label_1963, label %label_1965

label_1957:                                       ; preds = %label_1950
  %70 = load ptr, ptr %stmt.832, align 8
  %71 = getelementptr inbounds nuw %ASTNode, ptr %70, i32 0, i32 7
  %72 = load ptr, ptr %71, align 8
  %73 = call ptr @ptr_to_node(ptr %72)
  %74 = call i1 @sema_block_has_break__Struct_ASTNode(ptr %73)
  br i1 %74, label %label_1960, label %label_1962

label_1962:                                       ; preds = %label_1957
  br label %label_1959

label_1960:                                       ; preds = %label_1957
  ret i1 true

label_1965:                                       ; preds = %label_1968, %label_1959
  %75 = load ptr, ptr %stmt.832, align 8
  %76 = getelementptr inbounds nuw %ASTNode, ptr %75, i32 0, i32 8
  %77 = load ptr, ptr %76, align 8
  store ptr %77, ptr %stmt_ptr.831, align 8
  br label %label_1922

label_1963:                                       ; preds = %label_1959
  %78 = load ptr, ptr %stmt.832, align 8
  %79 = getelementptr inbounds nuw %ASTNode, ptr %78, i32 0, i32 6
  %80 = load ptr, ptr %79, align 8
  store ptr %80, ptr %arm_ptr.835, align 8
  br label %label_1966

label_1966:                                       ; preds = %label_1971, %label_1963
  %81 = load ptr, ptr %arm_ptr.835, align 8
  %82 = call i32 @str_equals(ptr %81, ptr @.str.s773)
  %83 = icmp eq i32 %82, 0
  br i1 %83, label %label_1967, label %label_1968

label_1968:                                       ; preds = %label_1966
  br label %label_1965

label_1967:                                       ; preds = %label_1966
  %84 = load ptr, ptr %arm_ptr.835, align 8
  %85 = call ptr @ptr_to_node(ptr %84)
  store ptr %85, ptr %arm.836, align 8
  %86 = load ptr, ptr %arm.836, align 8
  %87 = getelementptr inbounds nuw %ASTNode, ptr %86, i32 0, i32 6
  %88 = load ptr, ptr %87, align 8
  %89 = call ptr @ptr_to_node(ptr %88)
  %90 = call i1 @sema_block_has_break__Struct_ASTNode(ptr %89)
  br i1 %90, label %label_1969, label %label_1971

label_1971:                                       ; preds = %label_1967
  %91 = load ptr, ptr %arm.836, align 8
  %92 = getelementptr inbounds nuw %ASTNode, ptr %91, i32 0, i32 8
  %93 = load ptr, ptr %92, align 8
  store ptr %93, ptr %arm_ptr.835, align 8
  br label %label_1966

label_1969:                                       ; preds = %label_1967
  ret i1 true
}

define i1 @sema_stmt_has_break_wrapper__Struct_ASTNode(ptr %0) {
entry:
  %stmt.837 = alloca ptr, align 8
  store ptr %0, ptr %stmt.837, align 8
  %1 = load ptr, ptr %stmt.837, align 8
  %2 = getelementptr inbounds nuw %ASTNode, ptr %1, i32 0, i32 6
  %3 = load ptr, ptr %2, align 8
  %4 = call ptr @ptr_to_node(ptr %3)
  %5 = call i1 @sema_block_has_break__Struct_ASTNode(ptr %4)
  %else_node.838 = alloca ptr, align 8
  br i1 %5, label %label_1972, label %label_1974

label_1974:                                       ; preds = %entry
  %6 = load ptr, ptr %stmt.837, align 8
  %7 = getelementptr inbounds nuw %ASTNode, ptr %6, i32 0, i32 7
  %8 = load ptr, ptr %7, align 8
  %9 = call i32 @str_equals(ptr %8, ptr @.str.s774)
  %10 = icmp eq i32 %9, 0
  br i1 %10, label %label_1975, label %label_1977

label_1972:                                       ; preds = %entry
  ret i1 true

label_1977:                                       ; preds = %label_1974
  ret i1 false

label_1975:                                       ; preds = %label_1974
  %11 = load ptr, ptr %stmt.837, align 8
  %12 = getelementptr inbounds nuw %ASTNode, ptr %11, i32 0, i32 7
  %13 = load ptr, ptr %12, align 8
  %14 = call ptr @ptr_to_node(ptr %13)
  store ptr %14, ptr %else_node.838, align 8
  %15 = load ptr, ptr %else_node.838, align 8
  %16 = getelementptr inbounds nuw %ASTNode, ptr %15, i32 0, i32 0
  %17 = load i32, ptr %16, align 4
  %18 = icmp eq i32 %17, 10
  br i1 %18, label %label_1978, label %label_1980

label_1980:                                       ; preds = %label_1975
  %19 = load ptr, ptr %else_node.838, align 8
  %20 = call i1 @sema_block_has_break__Struct_ASTNode(ptr %19)
  ret i1 %20

label_1978:                                       ; preds = %label_1975
  %21 = load ptr, ptr %else_node.838, align 8
  %22 = call i1 @sema_stmt_has_break_wrapper__Struct_ASTNode(ptr %21)
  ret i1 %22
}

define i1 @sema_stmt_diverges__Struct_ASTNode(ptr %0) {
entry:
  %stmt.839 = alloca ptr, align 8
  store ptr %0, ptr %stmt.839, align 8
  %1 = load ptr, ptr %stmt.839, align 8
  %2 = getelementptr inbounds nuw %ASTNode, ptr %1, i32 0, i32 0
  %3 = load i32, ptr %2, align 4
  %4 = icmp eq i32 %3, 15
  %else_node.840 = alloca ptr, align 8
  %else_diverges.841 = alloca i1, align 1
  %sc.92 = alloca i1, align 1
  br i1 %4, label %label_1981, label %label_1983

label_1983:                                       ; preds = %entry
  %5 = load ptr, ptr %stmt.839, align 8
  %6 = getelementptr inbounds nuw %ASTNode, ptr %5, i32 0, i32 0
  %7 = load i32, ptr %6, align 4
  %8 = icmp eq i32 %7, 18
  br i1 %8, label %label_1984, label %label_1986

label_1981:                                       ; preds = %entry
  ret i1 true

label_1986:                                       ; preds = %label_1983
  %9 = load ptr, ptr %stmt.839, align 8
  %10 = getelementptr inbounds nuw %ASTNode, ptr %9, i32 0, i32 0
  %11 = load i32, ptr %10, align 4
  %12 = icmp eq i32 %11, 19
  br i1 %12, label %label_1987, label %label_1989

label_1984:                                       ; preds = %label_1983
  ret i1 true

label_1989:                                       ; preds = %label_1986
  %13 = load ptr, ptr %stmt.839, align 8
  %14 = getelementptr inbounds nuw %ASTNode, ptr %13, i32 0, i32 0
  %15 = load i32, ptr %14, align 4
  %16 = icmp eq i32 %15, 10
  br i1 %16, label %label_1990, label %label_1992

label_1987:                                       ; preds = %label_1986
  ret i1 true

label_1992:                                       ; preds = %label_1989
  %17 = load ptr, ptr %stmt.839, align 8
  %18 = getelementptr inbounds nuw %ASTNode, ptr %17, i32 0, i32 0
  %19 = load i32, ptr %18, align 4
  %20 = icmp eq i32 %19, 14
  br i1 %20, label %label_2001, label %label_2003

label_1990:                                       ; preds = %label_1989
  %21 = load ptr, ptr %stmt.839, align 8
  %22 = getelementptr inbounds nuw %ASTNode, ptr %21, i32 0, i32 7
  %23 = load ptr, ptr %22, align 8
  %24 = call i32 @str_equals(ptr %23, ptr @.str.s775)
  %25 = icmp eq i32 %24, 1
  br i1 %25, label %label_1993, label %label_1995

label_1995:                                       ; preds = %label_1990
  %26 = load ptr, ptr %stmt.839, align 8
  %27 = getelementptr inbounds nuw %ASTNode, ptr %26, i32 0, i32 7
  %28 = load ptr, ptr %27, align 8
  %29 = call ptr @ptr_to_node(ptr %28)
  store ptr %29, ptr %else_node.840, align 8
  store i1 false, ptr %else_diverges.841, align 1
  %30 = load ptr, ptr %else_node.840, align 8
  %31 = getelementptr inbounds nuw %ASTNode, ptr %30, i32 0, i32 0
  %32 = load i32, ptr %31, align 4
  %33 = icmp eq i32 %32, 10
  br i1 %33, label %label_1996, label %label_1997

label_1993:                                       ; preds = %label_1990
  ret i1 false

label_1997:                                       ; preds = %label_1995
  %34 = load ptr, ptr %else_node.840, align 8
  %35 = call i1 @sema_block_diverges__Struct_ASTNode(ptr %34)
  store i1 %35, ptr %else_diverges.841, align 1
  br label %label_1998

label_1996:                                       ; preds = %label_1995
  %36 = load ptr, ptr %else_node.840, align 8
  %37 = call i1 @sema_stmt_diverges__Struct_ASTNode(ptr %36)
  store i1 %37, ptr %else_diverges.841, align 1
  br label %label_1998

label_1998:                                       ; preds = %label_1997, %label_1996
  %38 = load ptr, ptr %stmt.839, align 8
  %39 = getelementptr inbounds nuw %ASTNode, ptr %38, i32 0, i32 6
  %40 = load ptr, ptr %39, align 8
  %41 = call ptr @ptr_to_node(ptr %40)
  %42 = call i1 @sema_block_diverges__Struct_ASTNode(ptr %41)
  store i1 %42, ptr %sc.92, align 1
  br i1 %42, label %label_1999, label %label_2000

label_2000:                                       ; preds = %label_1999, %label_1998
  %43 = load i1, ptr %sc.92, align 1
  ret i1 %43

label_1999:                                       ; preds = %label_1998
  %44 = load i1, ptr %else_diverges.841, align 1
  store i1 %44, ptr %sc.92, align 1
  br label %label_2000

label_2003:                                       ; preds = %label_1992
  ret i1 false

label_2001:                                       ; preds = %label_1992
  %45 = load ptr, ptr %stmt.839, align 8
  %46 = getelementptr inbounds nuw %ASTNode, ptr %45, i32 0, i32 5
  %47 = load ptr, ptr %46, align 8
  %48 = call ptr @ptr_to_node(ptr %47)
  %49 = call i1 @sema_block_has_break__Struct_ASTNode(ptr %48)
  %50 = icmp eq i1 %49, false
  ret i1 %50
}

define i1 @sema_block_diverges__Struct_ASTNode(ptr %0) {
entry:
  %block.842 = alloca ptr, align 8
  store ptr %0, ptr %block.842, align 8
  %1 = load ptr, ptr %block.842, align 8
  %2 = getelementptr inbounds nuw %ASTNode, ptr %1, i32 0, i32 5
  %3 = load ptr, ptr %2, align 8
  %stmt_ptr.843 = alloca ptr, align 8
  store ptr %3, ptr %stmt_ptr.843, align 8
  %stmt.844 = alloca ptr, align 8
  br label %label_2004

label_2004:                                       ; preds = %label_2009, %entry
  %4 = load ptr, ptr %stmt_ptr.843, align 8
  %5 = call i32 @str_equals(ptr %4, ptr @.str.s776)
  %6 = icmp eq i32 %5, 0
  br i1 %6, label %label_2005, label %label_2006

label_2006:                                       ; preds = %label_2004
  ret i1 false

label_2005:                                       ; preds = %label_2004
  %7 = load ptr, ptr %stmt_ptr.843, align 8
  %8 = call ptr @ptr_to_node(ptr %7)
  store ptr %8, ptr %stmt.844, align 8
  %9 = load ptr, ptr %stmt.844, align 8
  %10 = call i1 @sema_stmt_diverges__Struct_ASTNode(ptr %9)
  br i1 %10, label %label_2007, label %label_2009

label_2009:                                       ; preds = %label_2005
  %11 = load ptr, ptr %stmt.844, align 8
  %12 = getelementptr inbounds nuw %ASTNode, ptr %11, i32 0, i32 8
  %13 = load ptr, ptr %12, align 8
  store ptr %13, ptr %stmt_ptr.843, align 8
  br label %label_2004

label_2007:                                       ; preds = %label_2005
  ret i1 true
}

define ptr @sema_fn_key__String(ptr %0) {
entry:
  %name.845 = alloca ptr, align 8
  store ptr %0, ptr %name.845, align 8
  %1 = load ptr, ptr %name.845, align 8
  %2 = call ptr @str_concat(ptr @.str.s777, ptr %1)
  ret ptr %2
}

define ptr @sema_mangle_type__Struct_TypeInfo(ptr %0) {
entry:
  %t.846 = alloca ptr, align 8
  store ptr %0, ptr %t.846, align 8
  %1 = load ptr, ptr %t.846, align 8
  %2 = getelementptr inbounds nuw %TypeInfo, ptr %1, i32 0, i32 0
  %3 = load i32, ptr %2, align 4
  %4 = icmp eq i32 %3, 1
  br i1 %4, label %label_2010, label %label_2012

label_2012:                                       ; preds = %entry
  %5 = load ptr, ptr %t.846, align 8
  %6 = getelementptr inbounds nuw %TypeInfo, ptr %5, i32 0, i32 0
  %7 = load i32, ptr %6, align 4
  %8 = icmp eq i32 %7, 2
  br i1 %8, label %label_2013, label %label_2015

label_2010:                                       ; preds = %entry
  ret ptr @.str.s778

label_2015:                                       ; preds = %label_2012
  %9 = load ptr, ptr %t.846, align 8
  %10 = getelementptr inbounds nuw %TypeInfo, ptr %9, i32 0, i32 0
  %11 = load i32, ptr %10, align 4
  %12 = icmp eq i32 %11, 3
  br i1 %12, label %label_2016, label %label_2018

label_2013:                                       ; preds = %label_2012
  %13 = load ptr, ptr %t.846, align 8
  %14 = getelementptr inbounds nuw %TypeInfo, ptr %13, i32 0, i32 1
  %15 = load ptr, ptr %14, align 8
  ret ptr %15

label_2018:                                       ; preds = %label_2015
  %16 = load ptr, ptr %t.846, align 8
  %17 = getelementptr inbounds nuw %TypeInfo, ptr %16, i32 0, i32 0
  %18 = load i32, ptr %17, align 4
  %19 = icmp eq i32 %18, 4
  br i1 %19, label %label_2019, label %label_2021

label_2016:                                       ; preds = %label_2015
  ret ptr @.str.s779

label_2021:                                       ; preds = %label_2018
  %20 = load ptr, ptr %t.846, align 8
  %21 = getelementptr inbounds nuw %TypeInfo, ptr %20, i32 0, i32 0
  %22 = load i32, ptr %21, align 4
  %23 = icmp eq i32 %22, 5
  br i1 %23, label %label_2022, label %label_2024

label_2019:                                       ; preds = %label_2018
  ret ptr @.str.s780

label_2024:                                       ; preds = %label_2021
  %24 = load ptr, ptr %t.846, align 8
  %25 = getelementptr inbounds nuw %TypeInfo, ptr %24, i32 0, i32 0
  %26 = load i32, ptr %25, align 4
  %27 = icmp eq i32 %26, 6
  br i1 %27, label %label_2025, label %label_2027

label_2022:                                       ; preds = %label_2021
  ret ptr @.str.s781

label_2027:                                       ; preds = %label_2024
  %28 = load ptr, ptr %t.846, align 8
  %29 = getelementptr inbounds nuw %TypeInfo, ptr %28, i32 0, i32 0
  %30 = load i32, ptr %29, align 4
  %31 = icmp eq i32 %30, 7
  br i1 %31, label %label_2028, label %label_2030

label_2025:                                       ; preds = %label_2024
  ret ptr @.str.s782

label_2030:                                       ; preds = %label_2027
  %32 = load ptr, ptr %t.846, align 8
  %33 = getelementptr inbounds nuw %TypeInfo, ptr %32, i32 0, i32 0
  %34 = load i32, ptr %33, align 4
  %35 = icmp eq i32 %34, 8
  br i1 %35, label %label_2031, label %label_2033

label_2028:                                       ; preds = %label_2027
  ret ptr @.str.s783

label_2033:                                       ; preds = %label_2030
  %36 = load ptr, ptr %t.846, align 8
  %37 = getelementptr inbounds nuw %TypeInfo, ptr %36, i32 0, i32 0
  %38 = load i32, ptr %37, align 4
  %39 = icmp eq i32 %38, 9
  br i1 %39, label %label_2034, label %label_2036

label_2031:                                       ; preds = %label_2030
  %40 = load ptr, ptr %t.846, align 8
  %41 = getelementptr inbounds nuw %TypeInfo, ptr %40, i32 0, i32 1
  %42 = load ptr, ptr %41, align 8
  %43 = call ptr @str_concat(ptr @.str.s784, ptr %42)
  ret ptr %43

label_2036:                                       ; preds = %label_2033
  %44 = load ptr, ptr %t.846, align 8
  %45 = getelementptr inbounds nuw %TypeInfo, ptr %44, i32 0, i32 0
  %46 = load i32, ptr %45, align 4
  %47 = icmp eq i32 %46, 10
  br i1 %47, label %label_2037, label %label_2039

label_2034:                                       ; preds = %label_2033
  %48 = load ptr, ptr %t.846, align 8
  %49 = getelementptr inbounds nuw %TypeInfo, ptr %48, i32 0, i32 1
  %50 = load ptr, ptr %49, align 8
  %51 = call ptr @str_concat(ptr @.str.s785, ptr %50)
  ret ptr %51

label_2039:                                       ; preds = %label_2036
  %52 = load ptr, ptr %t.846, align 8
  %53 = getelementptr inbounds nuw %TypeInfo, ptr %52, i32 0, i32 0
  %54 = load i32, ptr %53, align 4
  %55 = icmp eq i32 %54, 11
  br i1 %55, label %label_2043, label %label_2045

label_2037:                                       ; preds = %label_2036
  %56 = load ptr, ptr %t.846, align 8
  %57 = getelementptr inbounds nuw %TypeInfo, ptr %56, i32 0, i32 3
  %58 = load ptr, ptr %57, align 8
  %59 = call i32 @str_equals(ptr %58, ptr @.str.s786)
  %60 = icmp eq i32 %59, 0
  br i1 %60, label %label_2040, label %label_2042

label_2042:                                       ; preds = %label_2037
  ret ptr @.str.s788

label_2040:                                       ; preds = %label_2037
  %61 = load ptr, ptr %t.846, align 8
  %62 = getelementptr inbounds nuw %TypeInfo, ptr %61, i32 0, i32 3
  %63 = load ptr, ptr %62, align 8
  %64 = call ptr @ptr_to_type(ptr %63)
  %65 = call ptr @sema_mangle_type__Struct_TypeInfo(ptr %64)
  %66 = call ptr @str_concat(ptr @.str.s787, ptr %65)
  ret ptr %66

label_2045:                                       ; preds = %label_2039
  ret ptr @.str.s792

label_2043:                                       ; preds = %label_2039
  %67 = load ptr, ptr %t.846, align 8
  %68 = getelementptr inbounds nuw %TypeInfo, ptr %67, i32 0, i32 3
  %69 = load ptr, ptr %68, align 8
  %70 = call i32 @str_equals(ptr %69, ptr @.str.s789)
  %71 = icmp eq i32 %70, 0
  br i1 %71, label %label_2046, label %label_2048

label_2048:                                       ; preds = %label_2043
  ret ptr @.str.s791

label_2046:                                       ; preds = %label_2043
  %72 = load ptr, ptr %t.846, align 8
  %73 = getelementptr inbounds nuw %TypeInfo, ptr %72, i32 0, i32 3
  %74 = load ptr, ptr %73, align 8
  %75 = call ptr @ptr_to_type(ptr %74)
  %76 = call ptr @sema_mangle_type__Struct_TypeInfo(ptr %75)
  %77 = call ptr @str_concat(ptr @.str.s790, ptr %76)
  ret ptr %77
}

define ptr @sema_param_signature__Struct_ASTNode_String(ptr %0, ptr %1) {
entry:
  %module.847 = alloca ptr, align 8
  store ptr %0, ptr %module.847, align 8
  %param_ptr.848 = alloca ptr, align 8
  store ptr %1, ptr %param_ptr.848, align 8
  %sig.849 = alloca ptr, align 8
  store ptr @.str.s793, ptr %sig.849, align 8
  %2 = load ptr, ptr %param_ptr.848, align 8
  %curr.850 = alloca ptr, align 8
  store ptr %2, ptr %curr.850, align 8
  %param.851 = alloca ptr, align 8
  %param_t.852 = alloca ptr, align 8
  br label %label_2049

label_2049:                                       ; preds = %label_2054, %entry
  %3 = load ptr, ptr %curr.850, align 8
  %4 = call i32 @str_equals(ptr %3, ptr @.str.s794)
  %5 = icmp eq i32 %4, 0
  br i1 %5, label %label_2050, label %label_2051

label_2051:                                       ; preds = %label_2049
  %6 = load ptr, ptr %sig.849, align 8
  %7 = call i32 @str_equals(ptr %6, ptr @.str.s797)
  %8 = icmp eq i32 %7, 1
  br i1 %8, label %label_2055, label %label_2057

label_2050:                                       ; preds = %label_2049
  %9 = load ptr, ptr %curr.850, align 8
  %10 = call ptr @ptr_to_node(ptr %9)
  store ptr %10, ptr %param.851, align 8
  %11 = load ptr, ptr %module.847, align 8
  %12 = load ptr, ptr %param.851, align 8
  %13 = getelementptr inbounds nuw %ASTNode, ptr %12, i32 0, i32 5
  %14 = load ptr, ptr %13, align 8
  %15 = call ptr @ptr_to_node(ptr %14)
  %16 = call ptr @sema_annotation_type__Struct_ASTNode_Struct_ASTNode(ptr %11, ptr %15)
  store ptr %16, ptr %param_t.852, align 8
  %17 = load ptr, ptr %sig.849, align 8
  %18 = call i32 @str_equals(ptr %17, ptr @.str.s795)
  %19 = icmp eq i32 %18, 1
  br i1 %19, label %label_2052, label %label_2053

label_2053:                                       ; preds = %label_2050
  %20 = load ptr, ptr %sig.849, align 8
  %21 = call ptr @str_concat(ptr %20, ptr @.str.s796)
  %22 = load ptr, ptr %param_t.852, align 8
  %23 = call ptr @sema_mangle_type__Struct_TypeInfo(ptr %22)
  %24 = call ptr @str_concat(ptr %21, ptr %23)
  store ptr %24, ptr %sig.849, align 8
  br label %label_2054

label_2052:                                       ; preds = %label_2050
  %25 = load ptr, ptr %param_t.852, align 8
  %26 = call ptr @sema_mangle_type__Struct_TypeInfo(ptr %25)
  store ptr %26, ptr %sig.849, align 8
  br label %label_2054

label_2054:                                       ; preds = %label_2053, %label_2052
  %27 = load ptr, ptr %param.851, align 8
  %28 = getelementptr inbounds nuw %ASTNode, ptr %27, i32 0, i32 8
  %29 = load ptr, ptr %28, align 8
  store ptr %29, ptr %curr.850, align 8
  br label %label_2049

label_2057:                                       ; preds = %label_2051
  %30 = load ptr, ptr %sig.849, align 8
  ret ptr %30

label_2055:                                       ; preds = %label_2051
  ret ptr @.str.s798
}

define ptr @sema_annotation_type__Struct_ASTNode_Struct_ASTNode(ptr %0, ptr %1) {
entry:
  %module.874 = alloca ptr, align 8
  store ptr %0, ptr %module.874, align 8
  %tn.875 = alloca ptr, align 8
  store ptr %1, ptr %tn.875, align 8
  %2 = load ptr, ptr %tn.875, align 8
  %3 = getelementptr inbounds nuw %ASTNode, ptr %2, i32 0, i32 3
  %4 = load i32, ptr %3, align 4
  %5 = icmp eq i32 %4, 1
  br i1 %5, label %label_2091, label %label_2093

label_2093:                                       ; preds = %entry
  %6 = load ptr, ptr %tn.875, align 8
  %7 = getelementptr inbounds nuw %ASTNode, ptr %6, i32 0, i32 4
  %8 = load i32, ptr %7, align 4
  %9 = icmp eq i32 %8, 1
  br i1 %9, label %label_2097, label %label_2099

label_2091:                                       ; preds = %entry
  %10 = load ptr, ptr %tn.875, align 8
  %11 = getelementptr inbounds nuw %ASTNode, ptr %10, i32 0, i32 5
  %12 = load ptr, ptr %11, align 8
  %13 = call i32 @str_equals(ptr %12, ptr @.str.s809)
  %14 = icmp eq i32 %13, 0
  br i1 %14, label %label_2094, label %label_2096

label_2096:                                       ; preds = %label_2091
  %15 = call ptr @type_invalid__Void()
  %16 = call ptr @type_array__Struct_TypeInfo(ptr %15)
  ret ptr %16

label_2094:                                       ; preds = %label_2091
  %17 = load ptr, ptr %module.874, align 8
  %18 = load ptr, ptr %tn.875, align 8
  %19 = getelementptr inbounds nuw %ASTNode, ptr %18, i32 0, i32 5
  %20 = load ptr, ptr %19, align 8
  %21 = call ptr @ptr_to_node(ptr %20)
  %22 = call ptr @sema_annotation_type__Struct_ASTNode_Struct_ASTNode(ptr %17, ptr %21)
  %23 = call ptr @type_array__Struct_TypeInfo(ptr %22)
  ret ptr %23

label_2099:                                       ; preds = %label_2093
  %24 = load ptr, ptr %tn.875, align 8
  %25 = getelementptr inbounds nuw %ASTNode, ptr %24, i32 0, i32 1
  %26 = load ptr, ptr %25, align 8
  %27 = call i32 @str_equals(ptr %26, ptr @.str.s811)
  %28 = icmp eq i32 %27, 1
  br i1 %28, label %label_2103, label %label_2105

label_2097:                                       ; preds = %label_2093
  %29 = load ptr, ptr %tn.875, align 8
  %30 = getelementptr inbounds nuw %ASTNode, ptr %29, i32 0, i32 5
  %31 = load ptr, ptr %30, align 8
  %32 = call i32 @str_equals(ptr %31, ptr @.str.s810)
  %33 = icmp eq i32 %32, 0
  br i1 %33, label %label_2100, label %label_2102

label_2102:                                       ; preds = %label_2097
  %34 = call ptr @type_invalid__Void()
  %35 = call ptr @type_list__Struct_TypeInfo(ptr %34)
  ret ptr %35

label_2100:                                       ; preds = %label_2097
  %36 = load ptr, ptr %module.874, align 8
  %37 = load ptr, ptr %tn.875, align 8
  %38 = getelementptr inbounds nuw %ASTNode, ptr %37, i32 0, i32 5
  %39 = load ptr, ptr %38, align 8
  %40 = call ptr @ptr_to_node(ptr %39)
  %41 = call ptr @sema_annotation_type__Struct_ASTNode_Struct_ASTNode(ptr %36, ptr %40)
  %42 = call ptr @type_list__Struct_TypeInfo(ptr %41)
  ret ptr %42

label_2105:                                       ; preds = %label_2099
  %43 = load ptr, ptr %tn.875, align 8
  %44 = getelementptr inbounds nuw %ASTNode, ptr %43, i32 0, i32 1
  %45 = load ptr, ptr %44, align 8
  %46 = call i32 @str_equals(ptr %45, ptr @.str.s812)
  %47 = icmp eq i32 %46, 1
  br i1 %47, label %label_2106, label %label_2108

label_2103:                                       ; preds = %label_2099
  %48 = call ptr @type_int__Void()
  ret ptr %48

label_2108:                                       ; preds = %label_2105
  %49 = load ptr, ptr %tn.875, align 8
  %50 = getelementptr inbounds nuw %ASTNode, ptr %49, i32 0, i32 1
  %51 = load ptr, ptr %50, align 8
  %52 = call i32 @str_equals(ptr %51, ptr @.str.s813)
  %53 = icmp eq i32 %52, 1
  br i1 %53, label %label_2109, label %label_2111

label_2106:                                       ; preds = %label_2105
  %54 = call ptr @type_float__Void()
  ret ptr %54

label_2111:                                       ; preds = %label_2108
  %55 = load ptr, ptr %tn.875, align 8
  %56 = getelementptr inbounds nuw %ASTNode, ptr %55, i32 0, i32 1
  %57 = load ptr, ptr %56, align 8
  %58 = call i32 @str_equals(ptr %57, ptr @.str.s814)
  %59 = icmp eq i32 %58, 1
  br i1 %59, label %label_2112, label %label_2114

label_2109:                                       ; preds = %label_2108
  %60 = call ptr @type_bool__Void()
  ret ptr %60

label_2114:                                       ; preds = %label_2111
  %61 = load ptr, ptr %tn.875, align 8
  %62 = getelementptr inbounds nuw %ASTNode, ptr %61, i32 0, i32 1
  %63 = load ptr, ptr %62, align 8
  %64 = call i32 @str_equals(ptr %63, ptr @.str.s815)
  %65 = icmp eq i32 %64, 1
  br i1 %65, label %label_2115, label %label_2117

label_2112:                                       ; preds = %label_2111
  %66 = call ptr @type_string__Void()
  ret ptr %66

label_2117:                                       ; preds = %label_2114
  %67 = load ptr, ptr %tn.875, align 8
  %68 = getelementptr inbounds nuw %ASTNode, ptr %67, i32 0, i32 1
  %69 = load ptr, ptr %68, align 8
  %70 = call i32 @str_equals(ptr %69, ptr @.str.s816)
  %71 = icmp eq i32 %70, 1
  br i1 %71, label %label_2118, label %label_2120

label_2115:                                       ; preds = %label_2114
  %72 = call ptr @type_char__Void()
  ret ptr %72

label_2120:                                       ; preds = %label_2117
  %73 = load ptr, ptr %tn.875, align 8
  %74 = getelementptr inbounds nuw %ASTNode, ptr %73, i32 0, i32 1
  %75 = load ptr, ptr %74, align 8
  %76 = call i32 @str_equals(ptr %75, ptr @.str.s817)
  %77 = icmp eq i32 %76, 1
  br i1 %77, label %label_2121, label %label_2123

label_2118:                                       ; preds = %label_2117
  %78 = call ptr @type_i8__Void()
  ret ptr %78

label_2123:                                       ; preds = %label_2120
  %79 = load ptr, ptr %tn.875, align 8
  %80 = getelementptr inbounds nuw %ASTNode, ptr %79, i32 0, i32 1
  %81 = load ptr, ptr %80, align 8
  %82 = call i32 @str_equals(ptr %81, ptr @.str.s818)
  %83 = icmp eq i32 %82, 1
  br i1 %83, label %label_2124, label %label_2126

label_2121:                                       ; preds = %label_2120
  %84 = call ptr @type_i16__Void()
  ret ptr %84

label_2126:                                       ; preds = %label_2123
  %85 = load ptr, ptr %tn.875, align 8
  %86 = getelementptr inbounds nuw %ASTNode, ptr %85, i32 0, i32 1
  %87 = load ptr, ptr %86, align 8
  %88 = call i32 @str_equals(ptr %87, ptr @.str.s819)
  %89 = icmp eq i32 %88, 1
  br i1 %89, label %label_2127, label %label_2129

label_2124:                                       ; preds = %label_2123
  %90 = call ptr @type_i64__Void()
  ret ptr %90

label_2129:                                       ; preds = %label_2126
  %91 = load ptr, ptr %tn.875, align 8
  %92 = getelementptr inbounds nuw %ASTNode, ptr %91, i32 0, i32 1
  %93 = load ptr, ptr %92, align 8
  %94 = call i32 @str_equals(ptr %93, ptr @.str.s820)
  %95 = icmp eq i32 %94, 1
  br i1 %95, label %label_2130, label %label_2132

label_2127:                                       ; preds = %label_2126
  %96 = call ptr @type_isize__Void()
  ret ptr %96

label_2132:                                       ; preds = %label_2129
  %97 = load ptr, ptr %tn.875, align 8
  %98 = getelementptr inbounds nuw %ASTNode, ptr %97, i32 0, i32 1
  %99 = load ptr, ptr %98, align 8
  %100 = call i32 @str_equals(ptr %99, ptr @.str.s821)
  %101 = icmp eq i32 %100, 1
  br i1 %101, label %label_2133, label %label_2135

label_2130:                                       ; preds = %label_2129
  %102 = call ptr @type_u8__Void()
  ret ptr %102

label_2135:                                       ; preds = %label_2132
  %103 = load ptr, ptr %tn.875, align 8
  %104 = getelementptr inbounds nuw %ASTNode, ptr %103, i32 0, i32 1
  %105 = load ptr, ptr %104, align 8
  %106 = call i32 @str_equals(ptr %105, ptr @.str.s822)
  %107 = icmp eq i32 %106, 1
  br i1 %107, label %label_2136, label %label_2138

label_2133:                                       ; preds = %label_2132
  %108 = call ptr @type_u16__Void()
  ret ptr %108

label_2138:                                       ; preds = %label_2135
  %109 = load ptr, ptr %tn.875, align 8
  %110 = getelementptr inbounds nuw %ASTNode, ptr %109, i32 0, i32 1
  %111 = load ptr, ptr %110, align 8
  %112 = call i32 @str_equals(ptr %111, ptr @.str.s823)
  %113 = icmp eq i32 %112, 1
  br i1 %113, label %label_2139, label %label_2141

label_2136:                                       ; preds = %label_2135
  %114 = call ptr @type_u32__Void()
  ret ptr %114

label_2141:                                       ; preds = %label_2138
  %115 = load ptr, ptr %tn.875, align 8
  %116 = getelementptr inbounds nuw %ASTNode, ptr %115, i32 0, i32 1
  %117 = load ptr, ptr %116, align 8
  %118 = call i32 @str_equals(ptr %117, ptr @.str.s824)
  %119 = icmp eq i32 %118, 1
  br i1 %119, label %label_2142, label %label_2144

label_2139:                                       ; preds = %label_2138
  %120 = call ptr @type_u64__Void()
  ret ptr %120

label_2144:                                       ; preds = %label_2141
  %121 = load ptr, ptr %tn.875, align 8
  %122 = getelementptr inbounds nuw %ASTNode, ptr %121, i32 0, i32 1
  %123 = load ptr, ptr %122, align 8
  %124 = call i32 @str_equals(ptr %123, ptr @.str.s825)
  %125 = icmp eq i32 %124, 1
  br i1 %125, label %label_2145, label %label_2147

label_2142:                                       ; preds = %label_2141
  %126 = call ptr @type_usize__Void()
  ret ptr %126

label_2147:                                       ; preds = %label_2144
  %127 = load ptr, ptr %module.874, align 8
  %128 = load ptr, ptr %tn.875, align 8
  %129 = getelementptr inbounds nuw %ASTNode, ptr %128, i32 0, i32 1
  %130 = load ptr, ptr %129, align 8
  %131 = call i1 @sema_has_enum__Struct_ASTNode_String(ptr %127, ptr %130)
  br i1 %131, label %label_2148, label %label_2150

label_2145:                                       ; preds = %label_2144
  %132 = call ptr @type_void__Void()
  ret ptr %132

label_2150:                                       ; preds = %label_2147
  %133 = load ptr, ptr %module.874, align 8
  %134 = load ptr, ptr %tn.875, align 8
  %135 = getelementptr inbounds nuw %ASTNode, ptr %134, i32 0, i32 1
  %136 = load ptr, ptr %135, align 8
  %137 = call i1 @sema_has_struct__Struct_ASTNode_String(ptr %133, ptr %136)
  br i1 %137, label %label_2151, label %label_2153

label_2148:                                       ; preds = %label_2147
  %138 = load ptr, ptr %tn.875, align 8
  %139 = getelementptr inbounds nuw %ASTNode, ptr %138, i32 0, i32 1
  %140 = load ptr, ptr %139, align 8
  %141 = call ptr @type_enum__String(ptr %140)
  ret ptr %141

label_2153:                                       ; preds = %label_2150
  %142 = load ptr, ptr %tn.875, align 8
  %143 = getelementptr inbounds nuw %ASTNode, ptr %142, i32 0, i32 1
  %144 = load ptr, ptr %143, align 8
  %145 = call ptr @str_concat(ptr @.str.s826, ptr %144)
  call void @sema_error__String(ptr %145)
  %146 = call ptr @type_invalid__Void()
  ret ptr %146

label_2151:                                       ; preds = %label_2150
  %147 = load ptr, ptr %tn.875, align 8
  %148 = getelementptr inbounds nuw %ASTNode, ptr %147, i32 0, i32 1
  %149 = load ptr, ptr %148, align 8
  %150 = call ptr @type_struct__String(ptr %149)
  ret ptr %150
}

define ptr @sema_function_symbol__Struct_ASTNode_Struct_ASTNode(ptr %0, ptr %1) {
entry:
  %module.853 = alloca ptr, align 8
  store ptr %0, ptr %module.853, align 8
  %fn_node.854 = alloca ptr, align 8
  store ptr %1, ptr %fn_node.854, align 8
  %2 = load ptr, ptr %fn_node.854, align 8
  %3 = getelementptr inbounds nuw %ASTNode, ptr %2, i32 0, i32 0
  %4 = load i32, ptr %3, align 4
  %5 = icmp eq i32 %4, 2
  br i1 %5, label %label_2058, label %label_2060

label_2060:                                       ; preds = %entry
  %6 = load ptr, ptr %fn_node.854, align 8
  %7 = getelementptr inbounds nuw %ASTNode, ptr %6, i32 0, i32 1
  %8 = load ptr, ptr %7, align 8
  %9 = call i32 @str_equals(ptr %8, ptr @.str.s799)
  %10 = icmp eq i32 %9, 1
  br i1 %10, label %label_2061, label %label_2063

label_2058:                                       ; preds = %entry
  %11 = load ptr, ptr %fn_node.854, align 8
  %12 = getelementptr inbounds nuw %ASTNode, ptr %11, i32 0, i32 1
  %13 = load ptr, ptr %12, align 8
  ret ptr %13

label_2063:                                       ; preds = %label_2060
  %14 = load ptr, ptr %fn_node.854, align 8
  %15 = getelementptr inbounds nuw %ASTNode, ptr %14, i32 0, i32 1
  %16 = load ptr, ptr %15, align 8
  %17 = call ptr @str_concat(ptr %16, ptr @.str.s801)
  %18 = load ptr, ptr %module.853, align 8
  %19 = load ptr, ptr %fn_node.854, align 8
  %20 = getelementptr inbounds nuw %ASTNode, ptr %19, i32 0, i32 5
  %21 = load ptr, ptr %20, align 8
  %22 = call ptr @sema_param_signature__Struct_ASTNode_String(ptr %18, ptr %21)
  %23 = call ptr @str_concat(ptr %17, ptr %22)
  ret ptr %23

label_2061:                                       ; preds = %label_2060
  ret ptr @.str.s800
}

define i32 @sema_function_symbol_count__Struct_ASTNode_String(ptr %0, ptr %1) {
entry:
  %module.855 = alloca ptr, align 8
  store ptr %0, ptr %module.855, align 8
  %symbol.856 = alloca ptr, align 8
  store ptr %1, ptr %symbol.856, align 8
  %count.857 = alloca i32, align 4
  store i32 0, ptr %count.857, align 4
  %2 = load ptr, ptr %module.855, align 8
  %3 = getelementptr inbounds nuw %ASTNode, ptr %2, i32 0, i32 5
  %4 = load ptr, ptr %3, align 8
  %stmt_ptr.858 = alloca ptr, align 8
  store ptr %4, ptr %stmt_ptr.858, align 8
  %stmt.859 = alloca ptr, align 8
  %sc.93 = alloca i1, align 1
  br label %label_2064

label_2064:                                       ; preds = %label_2071, %entry
  %5 = load ptr, ptr %stmt_ptr.858, align 8
  %6 = call i32 @str_equals(ptr %5, ptr @.str.s802)
  %7 = icmp eq i32 %6, 0
  br i1 %7, label %label_2065, label %label_2066

label_2066:                                       ; preds = %label_2064
  %8 = load i32, ptr %count.857, align 4
  ret i32 %8

label_2065:                                       ; preds = %label_2064
  %9 = load ptr, ptr %stmt_ptr.858, align 8
  %10 = call ptr @ptr_to_node(ptr %9)
  store ptr %10, ptr %stmt.859, align 8
  %11 = load ptr, ptr %stmt.859, align 8
  %12 = getelementptr inbounds nuw %ASTNode, ptr %11, i32 0, i32 0
  %13 = load i32, ptr %12, align 4
  %14 = icmp eq i32 %13, 4
  store i1 %14, ptr %sc.93, align 1
  br i1 %14, label %label_2068, label %label_2067

label_2067:                                       ; preds = %label_2065
  %15 = load ptr, ptr %stmt.859, align 8
  %16 = getelementptr inbounds nuw %ASTNode, ptr %15, i32 0, i32 0
  %17 = load i32, ptr %16, align 4
  %18 = icmp eq i32 %17, 2
  store i1 %18, ptr %sc.93, align 1
  br label %label_2068

label_2068:                                       ; preds = %label_2067, %label_2065
  %19 = load i1, ptr %sc.93, align 1
  br i1 %19, label %label_2069, label %label_2071

label_2071:                                       ; preds = %label_2074, %label_2068
  %20 = load ptr, ptr %stmt.859, align 8
  %21 = getelementptr inbounds nuw %ASTNode, ptr %20, i32 0, i32 8
  %22 = load ptr, ptr %21, align 8
  store ptr %22, ptr %stmt_ptr.858, align 8
  br label %label_2064

label_2069:                                       ; preds = %label_2068
  %23 = load ptr, ptr %module.855, align 8
  %24 = load ptr, ptr %stmt.859, align 8
  %25 = call ptr @sema_function_symbol__Struct_ASTNode_Struct_ASTNode(ptr %23, ptr %24)
  %26 = load ptr, ptr %symbol.856, align 8
  %27 = call i32 @str_equals(ptr %25, ptr %26)
  %28 = icmp eq i32 %27, 1
  br i1 %28, label %label_2072, label %label_2074

label_2074:                                       ; preds = %label_2072, %label_2069
  br label %label_2071

label_2072:                                       ; preds = %label_2069
  %29 = load i32, ptr %count.857, align 4
  %30 = add i32 %29, 1
  store i32 %30, ptr %count.857, align 4
  br label %label_2074
}

define ptr @sema_overload_key__Struct_ASTNode_Struct_ASTNode(ptr %0, ptr %1) {
entry:
  %module.860 = alloca ptr, align 8
  store ptr %0, ptr %module.860, align 8
  %fn_node.861 = alloca ptr, align 8
  store ptr %1, ptr %fn_node.861, align 8
  %2 = load ptr, ptr %module.860, align 8
  %3 = load ptr, ptr %fn_node.861, align 8
  %4 = call ptr @sema_function_symbol__Struct_ASTNode_Struct_ASTNode(ptr %2, ptr %3)
  %5 = call ptr @sema_fn_key__String(ptr %4)
  ret ptr %5
}

define void @sema_error__String(ptr %0) {
entry:
  %message.862 = alloca ptr, align 8
  store ptr %0, ptr %message.862, align 8
  call void @print(ptr @.str.s803)
  %1 = load ptr, ptr %message.862, align 8
  call void @println(ptr %1)
  call void @exit(i32 1)
  ret void
}

define void @sema_type_error__String_Struct_TypeInfo_Struct_TypeInfo(ptr %0, ptr %1, ptr %2) {
entry:
  %context.863 = alloca ptr, align 8
  store ptr %0, ptr %context.863, align 8
  %expected.864 = alloca ptr, align 8
  store ptr %1, ptr %expected.864, align 8
  %actual.865 = alloca ptr, align 8
  store ptr %2, ptr %actual.865, align 8
  call void @print(ptr @.str.s804)
  %3 = load ptr, ptr %context.863, align 8
  call void @print(ptr %3)
  call void @print(ptr @.str.s805)
  %4 = load ptr, ptr %expected.864, align 8
  %5 = call ptr @type_display__Struct_TypeInfo(ptr %4)
  call void @print(ptr %5)
  call void @print(ptr @.str.s806)
  %6 = load ptr, ptr %actual.865, align 8
  %7 = call ptr @type_display__Struct_TypeInfo(ptr %6)
  call void @println(ptr %7)
  call void @exit(i32 1)
  ret void
}

define i1 @sema_has_struct__Struct_ASTNode_String(ptr %0, ptr %1) {
entry:
  %module.866 = alloca ptr, align 8
  store ptr %0, ptr %module.866, align 8
  %name.867 = alloca ptr, align 8
  store ptr %1, ptr %name.867, align 8
  %2 = load ptr, ptr %module.866, align 8
  %3 = getelementptr inbounds nuw %ASTNode, ptr %2, i32 0, i32 5
  %4 = load ptr, ptr %3, align 8
  %stmt_ptr.868 = alloca ptr, align 8
  store ptr %4, ptr %stmt_ptr.868, align 8
  %stmt.869 = alloca ptr, align 8
  %sc.94 = alloca i1, align 1
  br label %label_2075

label_2075:                                       ; preds = %label_2082, %entry
  %5 = load ptr, ptr %stmt_ptr.868, align 8
  %6 = call i32 @str_equals(ptr %5, ptr @.str.s807)
  %7 = icmp eq i32 %6, 0
  br i1 %7, label %label_2076, label %label_2077

label_2077:                                       ; preds = %label_2075
  ret i1 false

label_2076:                                       ; preds = %label_2075
  %8 = load ptr, ptr %stmt_ptr.868, align 8
  %9 = call ptr @ptr_to_node(ptr %8)
  store ptr %9, ptr %stmt.869, align 8
  %10 = load ptr, ptr %stmt.869, align 8
  %11 = getelementptr inbounds nuw %ASTNode, ptr %10, i32 0, i32 0
  %12 = load i32, ptr %11, align 4
  %13 = icmp eq i32 %12, 5
  store i1 %13, ptr %sc.94, align 1
  br i1 %13, label %label_2078, label %label_2079

label_2079:                                       ; preds = %label_2078, %label_2076
  %14 = load i1, ptr %sc.94, align 1
  br i1 %14, label %label_2080, label %label_2082

label_2078:                                       ; preds = %label_2076
  %15 = load ptr, ptr %stmt.869, align 8
  %16 = getelementptr inbounds nuw %ASTNode, ptr %15, i32 0, i32 1
  %17 = load ptr, ptr %16, align 8
  %18 = load ptr, ptr %name.867, align 8
  %19 = call i32 @str_equals(ptr %17, ptr %18)
  %20 = icmp eq i32 %19, 1
  store i1 %20, ptr %sc.94, align 1
  br label %label_2079

label_2082:                                       ; preds = %label_2079
  %21 = load ptr, ptr %stmt.869, align 8
  %22 = getelementptr inbounds nuw %ASTNode, ptr %21, i32 0, i32 8
  %23 = load ptr, ptr %22, align 8
  store ptr %23, ptr %stmt_ptr.868, align 8
  br label %label_2075

label_2080:                                       ; preds = %label_2079
  ret i1 true
}

define i1 @sema_has_enum__Struct_ASTNode_String(ptr %0, ptr %1) {
entry:
  %module.870 = alloca ptr, align 8
  store ptr %0, ptr %module.870, align 8
  %name.871 = alloca ptr, align 8
  store ptr %1, ptr %name.871, align 8
  %2 = load ptr, ptr %module.870, align 8
  %3 = getelementptr inbounds nuw %ASTNode, ptr %2, i32 0, i32 5
  %4 = load ptr, ptr %3, align 8
  %stmt_ptr.872 = alloca ptr, align 8
  store ptr %4, ptr %stmt_ptr.872, align 8
  %stmt.873 = alloca ptr, align 8
  %sc.95 = alloca i1, align 1
  br label %label_2083

label_2083:                                       ; preds = %label_2090, %entry
  %5 = load ptr, ptr %stmt_ptr.872, align 8
  %6 = call i32 @str_equals(ptr %5, ptr @.str.s808)
  %7 = icmp eq i32 %6, 0
  br i1 %7, label %label_2084, label %label_2085

label_2085:                                       ; preds = %label_2083
  ret i1 false

label_2084:                                       ; preds = %label_2083
  %8 = load ptr, ptr %stmt_ptr.872, align 8
  %9 = call ptr @ptr_to_node(ptr %8)
  store ptr %9, ptr %stmt.873, align 8
  %10 = load ptr, ptr %stmt.873, align 8
  %11 = getelementptr inbounds nuw %ASTNode, ptr %10, i32 0, i32 0
  %12 = load i32, ptr %11, align 4
  %13 = icmp eq i32 %12, 6
  store i1 %13, ptr %sc.95, align 1
  br i1 %13, label %label_2086, label %label_2087

label_2087:                                       ; preds = %label_2086, %label_2084
  %14 = load i1, ptr %sc.95, align 1
  br i1 %14, label %label_2088, label %label_2090

label_2086:                                       ; preds = %label_2084
  %15 = load ptr, ptr %stmt.873, align 8
  %16 = getelementptr inbounds nuw %ASTNode, ptr %15, i32 0, i32 1
  %17 = load ptr, ptr %16, align 8
  %18 = load ptr, ptr %name.871, align 8
  %19 = call i32 @str_equals(ptr %17, ptr %18)
  %20 = icmp eq i32 %19, 1
  store i1 %20, ptr %sc.95, align 1
  br label %label_2087

label_2090:                                       ; preds = %label_2087
  %21 = load ptr, ptr %stmt.873, align 8
  %22 = getelementptr inbounds nuw %ASTNode, ptr %21, i32 0, i32 8
  %23 = load ptr, ptr %22, align 8
  store ptr %23, ptr %stmt_ptr.872, align 8
  br label %label_2083

label_2088:                                       ; preds = %label_2087
  ret i1 true
}

define ptr @sema_declared_return_type__Struct_ASTNode_String(ptr %0, ptr %1) {
entry:
  %module.876 = alloca ptr, align 8
  store ptr %0, ptr %module.876, align 8
  %ret_child.877 = alloca ptr, align 8
  store ptr %1, ptr %ret_child.877, align 8
  %2 = load ptr, ptr %ret_child.877, align 8
  %3 = call i32 @str_equals(ptr %2, ptr @.str.s827)
  %4 = icmp eq i32 %3, 0
  br i1 %4, label %label_2154, label %label_2156

label_2156:                                       ; preds = %entry
  %5 = call ptr @type_void__Void()
  ret ptr %5

label_2154:                                       ; preds = %entry
  %6 = load ptr, ptr %module.876, align 8
  %7 = load ptr, ptr %ret_child.877, align 8
  %8 = call ptr @ptr_to_node(ptr %7)
  %9 = call ptr @sema_annotation_type__Struct_ASTNode_Struct_ASTNode(ptr %6, ptr %8)
  ret ptr %9
}

define i1 @sema_enum_matches_int__Struct_TypeInfo_Struct_TypeInfo(ptr %0, ptr %1) {
entry:
  %a.878 = alloca ptr, align 8
  store ptr %0, ptr %a.878, align 8
  %b.879 = alloca ptr, align 8
  store ptr %1, ptr %b.879, align 8
  %2 = load ptr, ptr %a.878, align 8
  %3 = getelementptr inbounds nuw %TypeInfo, ptr %2, i32 0, i32 0
  %4 = load i32, ptr %3, align 4
  %5 = icmp ne i32 %4, 9
  br i1 %5, label %label_2157, label %label_2159

label_2159:                                       ; preds = %entry
  %6 = load ptr, ptr %b.879, align 8
  %7 = getelementptr inbounds nuw %TypeInfo, ptr %6, i32 0, i32 0
  %8 = load i32, ptr %7, align 4
  %9 = icmp ne i32 %8, 2
  br i1 %9, label %label_2160, label %label_2162

label_2157:                                       ; preds = %entry
  ret i1 false

label_2162:                                       ; preds = %label_2159
  %10 = load ptr, ptr %b.879, align 8
  %11 = getelementptr inbounds nuw %TypeInfo, ptr %10, i32 0, i32 1
  %12 = load ptr, ptr %11, align 8
  %13 = call i32 @str_equals(ptr %12, ptr @.str.s828)
  %14 = icmp eq i32 %13, 1
  ret i1 %14

label_2160:                                       ; preds = %label_2159
  ret i1 false
}

define i1 @sema_types_match__Struct_TypeInfo_Struct_TypeInfo(ptr %0, ptr %1) {
entry:
  %expected.880 = alloca ptr, align 8
  store ptr %0, ptr %expected.880, align 8
  %actual.881 = alloca ptr, align 8
  store ptr %1, ptr %actual.881, align 8
  %2 = load ptr, ptr %expected.880, align 8
  %3 = load ptr, ptr %actual.881, align 8
  %4 = call i1 @type_equals__Struct_TypeInfo_Struct_TypeInfo(ptr %2, ptr %3)
  br i1 %4, label %label_2163, label %label_2165

label_2165:                                       ; preds = %entry
  %5 = load ptr, ptr %expected.880, align 8
  %6 = load ptr, ptr %actual.881, align 8
  %7 = call i1 @sema_enum_matches_int__Struct_TypeInfo_Struct_TypeInfo(ptr %5, ptr %6)
  br i1 %7, label %label_2166, label %label_2168

label_2163:                                       ; preds = %entry
  ret i1 true

label_2168:                                       ; preds = %label_2165
  %8 = load ptr, ptr %actual.881, align 8
  %9 = load ptr, ptr %expected.880, align 8
  %10 = call i1 @sema_enum_matches_int__Struct_TypeInfo_Struct_TypeInfo(ptr %8, ptr %9)
  br i1 %10, label %label_2169, label %label_2171

label_2166:                                       ; preds = %label_2165
  ret i1 true

label_2171:                                       ; preds = %label_2168
  ret i1 false

label_2169:                                       ; preds = %label_2168
  ret i1 true
}

define void @sema_expect_assignable__String_Struct_TypeInfo_Struct_TypeInfo(ptr %0, ptr %1, ptr %2) {
entry:
  %context.882 = alloca ptr, align 8
  store ptr %0, ptr %context.882, align 8
  %expected.883 = alloca ptr, align 8
  store ptr %1, ptr %expected.883, align 8
  %actual.884 = alloca ptr, align 8
  store ptr %2, ptr %actual.884, align 8
  %3 = load ptr, ptr %expected.883, align 8
  %4 = load ptr, ptr %actual.884, align 8
  %5 = call i1 @sema_types_match__Struct_TypeInfo_Struct_TypeInfo(ptr %3, ptr %4)
  %6 = icmp eq i1 %5, false
  br i1 %6, label %label_2172, label %label_2174

label_2174:                                       ; preds = %label_2172, %entry
  ret void

label_2172:                                       ; preds = %entry
  %7 = load ptr, ptr %context.882, align 8
  %8 = load ptr, ptr %expected.883, align 8
  %9 = load ptr, ptr %actual.884, align 8
  call void @sema_type_error__String_Struct_TypeInfo_Struct_TypeInfo(ptr %7, ptr %8, ptr %9)
  br label %label_2174
}

define i1 @sema_is_int_literal__Struct_ASTNode(ptr %0) {
entry:
  %e.885 = alloca ptr, align 8
  store ptr %0, ptr %e.885, align 8
  %sc.96 = alloca i1, align 1
  %1 = load ptr, ptr %e.885, align 8
  %2 = getelementptr inbounds nuw %ASTNode, ptr %1, i32 0, i32 0
  %3 = load i32, ptr %2, align 4
  %4 = icmp eq i32 %3, 22
  store i1 %4, ptr %sc.96, align 1
  br i1 %4, label %label_2175, label %label_2176

label_2176:                                       ; preds = %label_2175, %entry
  %5 = load i1, ptr %sc.96, align 1
  ret i1 %5

label_2175:                                       ; preds = %entry
  %6 = load ptr, ptr %e.885, align 8
  %7 = getelementptr inbounds nuw %ASTNode, ptr %6, i32 0, i32 3
  %8 = load i32, ptr %7, align 4
  %9 = icmp eq i32 %8, 2
  store i1 %9, ptr %sc.96, align 1
  br label %label_2176
}

define void @sema_move_operand__Struct_ASTNode(ptr %0) {
entry:
  %node.886 = alloca ptr, align 8
  store ptr %0, ptr %node.886, align 8
  %1 = load ptr, ptr %node.886, align 8
  %2 = getelementptr inbounds nuw %ASTNode, ptr %1, i32 0, i32 0
  %3 = load i32, ptr %2, align 4
  %4 = icmp eq i32 %3, 23
  br i1 %4, label %label_2177, label %label_2179

label_2179:                                       ; preds = %label_2182, %entry
  ret void

label_2177:                                       ; preds = %entry
  %5 = load ptr, ptr %node.886, align 8
  %6 = call ptr @node_get_type__Struct_ASTNode(ptr %5)
  %7 = call i1 @type_is_move_only__Struct_TypeInfo(ptr %6)
  br i1 %7, label %label_2180, label %label_2182

label_2182:                                       ; preds = %label_2188, %label_2177
  br label %label_2179

label_2180:                                       ; preds = %label_2177
  %8 = load ptr, ptr %node.886, align 8
  %9 = getelementptr inbounds nuw %ASTNode, ptr %8, i32 0, i32 1
  %10 = load ptr, ptr %9, align 8
  %11 = call i32 @ir_is_borrowed(ptr %10)
  %12 = icmp eq i32 %11, 1
  br i1 %12, label %label_2183, label %label_2185

label_2185:                                       ; preds = %label_2183, %label_2180
  %13 = load ptr, ptr %node.886, align 8
  %14 = getelementptr inbounds nuw %ASTNode, ptr %13, i32 0, i32 1
  %15 = load ptr, ptr %14, align 8
  %16 = call i32 @ir_binding_predates_loop(ptr %15)
  %17 = icmp eq i32 %16, 1
  br i1 %17, label %label_2186, label %label_2188

label_2183:                                       ; preds = %label_2180
  %18 = load ptr, ptr %node.886, align 8
  %19 = getelementptr inbounds nuw %ASTNode, ptr %18, i32 0, i32 1
  %20 = load ptr, ptr %19, align 8
  %21 = call ptr @str_concat(ptr @.str.s829, ptr %20)
  call void @sema_error__String(ptr %21)
  br label %label_2185

label_2188:                                       ; preds = %label_2186, %label_2185
  %22 = load ptr, ptr %node.886, align 8
  %23 = getelementptr inbounds nuw %ASTNode, ptr %22, i32 0, i32 1
  %24 = load ptr, ptr %23, align 8
  call void @ir_mark_moved(ptr %24)
  br label %label_2182

label_2186:                                       ; preds = %label_2185
  %25 = load ptr, ptr %node.886, align 8
  %26 = getelementptr inbounds nuw %ASTNode, ptr %25, i32 0, i32 1
  %27 = load ptr, ptr %26, align 8
  %28 = call ptr @str_concat(ptr @.str.s830, ptr %27)
  call void @sema_error__String(ptr %28)
  br label %label_2188
}

define ptr @sema_check_value__Struct_ASTNode_Struct_ASTNode_Struct_TypeInfo_String(ptr %0, ptr %1, ptr %2, ptr %3) {
entry:
  %module.887 = alloca ptr, align 8
  store ptr %0, ptr %module.887, align 8
  %val_node.888 = alloca ptr, align 8
  store ptr %1, ptr %val_node.888, align 8
  %expected.889 = alloca ptr, align 8
  store ptr %2, ptr %expected.889, align 8
  %context.890 = alloca ptr, align 8
  store ptr %3, ptr %context.890, align 8
  %sc.97 = alloca i1, align 1
  %sc.98 = alloca i1, align 1
  %4 = load ptr, ptr %expected.889, align 8
  %5 = call i1 @type_is_valid__Struct_TypeInfo(ptr %4)
  store i1 %5, ptr %sc.98, align 1
  %actual.891 = alloca ptr, align 8
  br i1 %5, label %label_2191, label %label_2192

label_2192:                                       ; preds = %label_2191, %entry
  %6 = load i1, ptr %sc.98, align 1
  store i1 %6, ptr %sc.97, align 1
  br i1 %6, label %label_2189, label %label_2190

label_2191:                                       ; preds = %entry
  %7 = load ptr, ptr %expected.889, align 8
  %8 = getelementptr inbounds nuw %TypeInfo, ptr %7, i32 0, i32 0
  %9 = load i32, ptr %8, align 4
  %10 = icmp eq i32 %9, 2
  store i1 %10, ptr %sc.98, align 1
  br label %label_2192

label_2190:                                       ; preds = %label_2189, %label_2192
  %11 = load i1, ptr %sc.97, align 1
  br i1 %11, label %label_2193, label %label_2195

label_2189:                                       ; preds = %label_2192
  %12 = load ptr, ptr %val_node.888, align 8
  %13 = call i1 @sema_is_int_literal__Struct_ASTNode(ptr %12)
  store i1 %13, ptr %sc.97, align 1
  br label %label_2190

label_2195:                                       ; preds = %label_2190
  %14 = load ptr, ptr %module.887, align 8
  %15 = load ptr, ptr %val_node.888, align 8
  %16 = call ptr @sema_expr__Struct_ASTNode_Struct_ASTNode(ptr %14, ptr %15)
  store ptr %16, ptr %actual.891, align 8
  %17 = load ptr, ptr %context.890, align 8
  %18 = load ptr, ptr %expected.889, align 8
  %19 = load ptr, ptr %actual.891, align 8
  call void @sema_expect_assignable__String_Struct_TypeInfo_Struct_TypeInfo(ptr %17, ptr %18, ptr %19)
  %20 = load ptr, ptr %actual.891, align 8
  ret ptr %20

label_2193:                                       ; preds = %label_2190
  %21 = load ptr, ptr %val_node.888, align 8
  %22 = load ptr, ptr %expected.889, align 8
  call void @node_set_type__Struct_ASTNode_Struct_TypeInfo(ptr %21, ptr %22)
  %23 = load ptr, ptr %expected.889, align 8
  ret ptr %23
}

define ptr @sema_expr__Struct_ASTNode_Struct_ASTNode(ptr %0, ptr %1) {
entry:
  %module.954 = alloca ptr, align 8
  store ptr %0, ptr %module.954, align 8
  %expr.955 = alloca ptr, align 8
  store ptr %1, ptr %expr.955, align 8
  %2 = load ptr, ptr %expr.955, align 8
  %3 = call i1 @node_has_type__Struct_ASTNode(ptr %2)
  %t.956 = alloca ptr, align 8
  %t.957 = alloca ptr, align 8
  %source.958 = alloca ptr, align 8
  %from_t.959 = alloca ptr, align 8
  %to_t.960 = alloca ptr, align 8
  %sc.124 = alloca i1, align 1
  %sc.125 = alloca i1, align 1
  %sc.126 = alloca i1, align 1
  %sc.127 = alloca i1, align 1
  %from_scalar.961 = alloca i1, align 1
  %sc.128 = alloca i1, align 1
  %sc.129 = alloca i1, align 1
  %sc.130 = alloca i1, align 1
  %sc.131 = alloca i1, align 1
  %to_scalar.962 = alloca i1, align 1
  %sc.132 = alloca i1, align 1
  %operand.963 = alloca ptr, align 8
  %operand_t.964 = alloca ptr, align 8
  %uop.965 = alloca ptr, align 8
  %sc.133 = alloca i1, align 1
  %left_node.966 = alloca ptr, align 8
  %right_node.967 = alloca ptr, align 8
  %left_t.968 = alloca ptr, align 8
  %right_t.969 = alloca ptr, align 8
  %sc.134 = alloca i1, align 1
  %sc.135 = alloca i1, align 1
  %op.970 = alloca ptr, align 8
  %sc.136 = alloca i1, align 1
  %sc.137 = alloca i1, align 1
  %sc.138 = alloca i1, align 1
  %sc.139 = alloca i1, align 1
  %sc.140 = alloca i1, align 1
  %sc.141 = alloca i1, align 1
  %sc.142 = alloca i1, align 1
  %sc.143 = alloca i1, align 1
  %sc.144 = alloca i1, align 1
  %sc.145 = alloca i1, align 1
  %sc.146 = alloca i1, align 1
  %sc.147 = alloca i1, align 1
  %sc.148 = alloca i1, align 1
  %sc.149 = alloca i1, align 1
  %sc.150 = alloca i1, align 1
  %sc.151 = alloca i1, align 1
  %sc.152 = alloca i1, align 1
  %sc.153 = alloca i1, align 1
  %callee.971 = alloca ptr, align 8
  %name.972 = alloca ptr, align 8
  %builtin_t.973 = alloca ptr, align 8
  %fn_node.974 = alloca ptr, align 8
  %arg_ptr.975 = alloca ptr, align 8
  %param_ptr.976 = alloca ptr, align 8
  %sc.154 = alloca i1, align 1
  %arg_node.977 = alloca ptr, align 8
  %param_node.978 = alloca ptr, align 8
  %param_t.979 = alloca ptr, align 8
  %ret_t.980 = alloca ptr, align 8
  %object_node.981 = alloca ptr, align 8
  %sc.155 = alloca i1, align 1
  %object_t.982 = alloca ptr, align 8
  %field_t.983 = alloca ptr, align 8
  %elem_ptr.984 = alloca ptr, align 8
  %arr_t.985 = alloca ptr, align 8
  %first_t.986 = alloca ptr, align 8
  %elem.987 = alloca ptr, align 8
  %elem_t.988 = alloca ptr, align 8
  %arr_t2.989 = alloca ptr, align 8
  %array_t.990 = alloca ptr, align 8
  %index_t.991 = alloca ptr, align 8
  %elem_t.992 = alloca ptr, align 8
  %field_ptr.993 = alloca ptr, align 8
  %field.994 = alloca ptr, align 8
  %expected.995 = alloca ptr, align 8
  %struct_t.996 = alloca ptr, align 8
  br i1 %3, label %label_2420, label %label_2422

label_2422:                                       ; preds = %entry
  %4 = load ptr, ptr %expr.955, align 8
  %5 = getelementptr inbounds nuw %ASTNode, ptr %4, i32 0, i32 0
  %6 = load i32, ptr %5, align 4
  %7 = icmp eq i32 %6, 22
  br i1 %7, label %label_2423, label %label_2425

label_2420:                                       ; preds = %entry
  %8 = load ptr, ptr %expr.955, align 8
  %9 = call ptr @node_get_type__Struct_ASTNode(ptr %8)
  ret ptr %9

label_2425:                                       ; preds = %label_2422
  %10 = load ptr, ptr %expr.955, align 8
  %11 = getelementptr inbounds nuw %ASTNode, ptr %10, i32 0, i32 0
  %12 = load i32, ptr %11, align 4
  %13 = icmp eq i32 %12, 23
  br i1 %13, label %label_2441, label %label_2443

label_2423:                                       ; preds = %label_2422
  %14 = call ptr @type_invalid__Void()
  store ptr %14, ptr %t.956, align 8
  %15 = load ptr, ptr %expr.955, align 8
  %16 = getelementptr inbounds nuw %ASTNode, ptr %15, i32 0, i32 3
  %17 = load i32, ptr %16, align 4
  %18 = icmp eq i32 %17, 2
  br i1 %18, label %label_2426, label %label_2428

label_2428:                                       ; preds = %label_2426, %label_2423
  %19 = load ptr, ptr %expr.955, align 8
  %20 = getelementptr inbounds nuw %ASTNode, ptr %19, i32 0, i32 3
  %21 = load i32, ptr %20, align 4
  %22 = icmp eq i32 %21, 3
  br i1 %22, label %label_2429, label %label_2431

label_2426:                                       ; preds = %label_2423
  %23 = call ptr @type_int__Void()
  store ptr %23, ptr %t.956, align 8
  br label %label_2428

label_2431:                                       ; preds = %label_2429, %label_2428
  %24 = load ptr, ptr %expr.955, align 8
  %25 = getelementptr inbounds nuw %ASTNode, ptr %24, i32 0, i32 3
  %26 = load i32, ptr %25, align 4
  %27 = icmp eq i32 %26, 4
  br i1 %27, label %label_2432, label %label_2434

label_2429:                                       ; preds = %label_2428
  %28 = call ptr @type_float__Void()
  store ptr %28, ptr %t.956, align 8
  br label %label_2431

label_2434:                                       ; preds = %label_2432, %label_2431
  %29 = load ptr, ptr %expr.955, align 8
  %30 = getelementptr inbounds nuw %ASTNode, ptr %29, i32 0, i32 3
  %31 = load i32, ptr %30, align 4
  %32 = icmp eq i32 %31, 1
  br i1 %32, label %label_2435, label %label_2437

label_2432:                                       ; preds = %label_2431
  %33 = call ptr @type_bool__Void()
  store ptr %33, ptr %t.956, align 8
  br label %label_2434

label_2437:                                       ; preds = %label_2435, %label_2434
  %34 = load ptr, ptr %expr.955, align 8
  %35 = getelementptr inbounds nuw %ASTNode, ptr %34, i32 0, i32 3
  %36 = load i32, ptr %35, align 4
  %37 = icmp eq i32 %36, 0
  br i1 %37, label %label_2438, label %label_2440

label_2435:                                       ; preds = %label_2434
  %38 = call ptr @type_char__Void()
  store ptr %38, ptr %t.956, align 8
  br label %label_2437

label_2440:                                       ; preds = %label_2438, %label_2437
  %39 = load ptr, ptr %expr.955, align 8
  %40 = load ptr, ptr %t.956, align 8
  call void @node_set_type__Struct_ASTNode_Struct_TypeInfo(ptr %39, ptr %40)
  %41 = load ptr, ptr %t.956, align 8
  ret ptr %41

label_2438:                                       ; preds = %label_2437
  %42 = call ptr @type_string__Void()
  store ptr %42, ptr %t.956, align 8
  br label %label_2440

label_2443:                                       ; preds = %label_2425
  %43 = load ptr, ptr %expr.955, align 8
  %44 = getelementptr inbounds nuw %ASTNode, ptr %43, i32 0, i32 0
  %45 = load i32, ptr %44, align 4
  %46 = icmp eq i32 %45, 29
  br i1 %46, label %label_2450, label %label_2452

label_2441:                                       ; preds = %label_2425
  %47 = load ptr, ptr %expr.955, align 8
  %48 = getelementptr inbounds nuw %ASTNode, ptr %47, i32 0, i32 1
  %49 = load ptr, ptr %48, align 8
  %50 = call i32 @ir_has_var_type(ptr %49)
  %51 = icmp eq i32 %50, 0
  br i1 %51, label %label_2444, label %label_2446

label_2446:                                       ; preds = %label_2444, %label_2441
  %52 = load ptr, ptr %expr.955, align 8
  %53 = getelementptr inbounds nuw %ASTNode, ptr %52, i32 0, i32 1
  %54 = load ptr, ptr %53, align 8
  %55 = call i32 @ir_is_moved(ptr %54)
  %56 = icmp eq i32 %55, 1
  br i1 %56, label %label_2447, label %label_2449

label_2444:                                       ; preds = %label_2441
  %57 = load ptr, ptr %expr.955, align 8
  %58 = getelementptr inbounds nuw %ASTNode, ptr %57, i32 0, i32 1
  %59 = load ptr, ptr %58, align 8
  %60 = call ptr @str_concat(ptr @.str.s907, ptr %59)
  call void @sema_error__String(ptr %60)
  br label %label_2446

label_2449:                                       ; preds = %label_2447, %label_2446
  %61 = load ptr, ptr %expr.955, align 8
  %62 = getelementptr inbounds nuw %ASTNode, ptr %61, i32 0, i32 1
  %63 = load ptr, ptr %62, align 8
  %64 = call ptr @ir_get_var_type(ptr %63)
  %65 = call ptr @type_from_sem_key__String(ptr %64)
  store ptr %65, ptr %t.957, align 8
  %66 = load ptr, ptr %expr.955, align 8
  %67 = load ptr, ptr %t.957, align 8
  call void @node_set_type__Struct_ASTNode_Struct_TypeInfo(ptr %66, ptr %67)
  %68 = load ptr, ptr %t.957, align 8
  ret ptr %68

label_2447:                                       ; preds = %label_2446
  %69 = load ptr, ptr %expr.955, align 8
  %70 = getelementptr inbounds nuw %ASTNode, ptr %69, i32 0, i32 1
  %71 = load ptr, ptr %70, align 8
  %72 = call ptr @str_concat(ptr @.str.s908, ptr %71)
  call void @sema_error__String(ptr %72)
  br label %label_2449

label_2452:                                       ; preds = %label_2443
  %73 = load ptr, ptr %expr.955, align 8
  %74 = getelementptr inbounds nuw %ASTNode, ptr %73, i32 0, i32 0
  %75 = load i32, ptr %74, align 4
  %76 = icmp eq i32 %75, 21
  br i1 %76, label %label_2477, label %label_2479

label_2450:                                       ; preds = %label_2443
  %77 = load ptr, ptr %expr.955, align 8
  %78 = getelementptr inbounds nuw %ASTNode, ptr %77, i32 0, i32 5
  %79 = load ptr, ptr %78, align 8
  %80 = call ptr @ptr_to_node(ptr %79)
  store ptr %80, ptr %source.958, align 8
  %81 = load ptr, ptr %module.954, align 8
  %82 = load ptr, ptr %source.958, align 8
  %83 = call ptr @sema_expr__Struct_ASTNode_Struct_ASTNode(ptr %81, ptr %82)
  store ptr %83, ptr %from_t.959, align 8
  %84 = load ptr, ptr %module.954, align 8
  %85 = load ptr, ptr %expr.955, align 8
  %86 = getelementptr inbounds nuw %ASTNode, ptr %85, i32 0, i32 6
  %87 = load ptr, ptr %86, align 8
  %88 = call ptr @ptr_to_node(ptr %87)
  %89 = call ptr @sema_annotation_type__Struct_ASTNode_Struct_ASTNode(ptr %84, ptr %88)
  store ptr %89, ptr %to_t.960, align 8
  %90 = load ptr, ptr %from_t.959, align 8
  %91 = getelementptr inbounds nuw %TypeInfo, ptr %90, i32 0, i32 0
  %92 = load i32, ptr %91, align 4
  %93 = icmp eq i32 %92, 2
  store i1 %93, ptr %sc.127, align 1
  br i1 %93, label %label_2460, label %label_2459

label_2459:                                       ; preds = %label_2450
  %94 = load ptr, ptr %from_t.959, align 8
  %95 = getelementptr inbounds nuw %TypeInfo, ptr %94, i32 0, i32 0
  %96 = load i32, ptr %95, align 4
  %97 = icmp eq i32 %96, 3
  store i1 %97, ptr %sc.127, align 1
  br label %label_2460

label_2460:                                       ; preds = %label_2459, %label_2450
  %98 = load i1, ptr %sc.127, align 1
  store i1 %98, ptr %sc.126, align 1
  br i1 %98, label %label_2458, label %label_2457

label_2457:                                       ; preds = %label_2460
  %99 = load ptr, ptr %from_t.959, align 8
  %100 = getelementptr inbounds nuw %TypeInfo, ptr %99, i32 0, i32 0
  %101 = load i32, ptr %100, align 4
  %102 = icmp eq i32 %101, 5
  store i1 %102, ptr %sc.126, align 1
  br label %label_2458

label_2458:                                       ; preds = %label_2457, %label_2460
  %103 = load i1, ptr %sc.126, align 1
  store i1 %103, ptr %sc.125, align 1
  br i1 %103, label %label_2456, label %label_2455

label_2455:                                       ; preds = %label_2458
  %104 = load ptr, ptr %from_t.959, align 8
  %105 = getelementptr inbounds nuw %TypeInfo, ptr %104, i32 0, i32 0
  %106 = load i32, ptr %105, align 4
  %107 = icmp eq i32 %106, 4
  store i1 %107, ptr %sc.125, align 1
  br label %label_2456

label_2456:                                       ; preds = %label_2455, %label_2458
  %108 = load i1, ptr %sc.125, align 1
  store i1 %108, ptr %sc.124, align 1
  br i1 %108, label %label_2454, label %label_2453

label_2453:                                       ; preds = %label_2456
  %109 = load ptr, ptr %from_t.959, align 8
  %110 = getelementptr inbounds nuw %TypeInfo, ptr %109, i32 0, i32 0
  %111 = load i32, ptr %110, align 4
  %112 = icmp eq i32 %111, 9
  store i1 %112, ptr %sc.124, align 1
  br label %label_2454

label_2454:                                       ; preds = %label_2453, %label_2456
  %113 = load i1, ptr %sc.124, align 1
  store i1 %113, ptr %from_scalar.961, align 1
  %114 = load ptr, ptr %to_t.960, align 8
  %115 = getelementptr inbounds nuw %TypeInfo, ptr %114, i32 0, i32 0
  %116 = load i32, ptr %115, align 4
  %117 = icmp eq i32 %116, 2
  store i1 %117, ptr %sc.131, align 1
  br i1 %117, label %label_2468, label %label_2467

label_2467:                                       ; preds = %label_2454
  %118 = load ptr, ptr %to_t.960, align 8
  %119 = getelementptr inbounds nuw %TypeInfo, ptr %118, i32 0, i32 0
  %120 = load i32, ptr %119, align 4
  %121 = icmp eq i32 %120, 3
  store i1 %121, ptr %sc.131, align 1
  br label %label_2468

label_2468:                                       ; preds = %label_2467, %label_2454
  %122 = load i1, ptr %sc.131, align 1
  store i1 %122, ptr %sc.130, align 1
  br i1 %122, label %label_2466, label %label_2465

label_2465:                                       ; preds = %label_2468
  %123 = load ptr, ptr %to_t.960, align 8
  %124 = getelementptr inbounds nuw %TypeInfo, ptr %123, i32 0, i32 0
  %125 = load i32, ptr %124, align 4
  %126 = icmp eq i32 %125, 5
  store i1 %126, ptr %sc.130, align 1
  br label %label_2466

label_2466:                                       ; preds = %label_2465, %label_2468
  %127 = load i1, ptr %sc.130, align 1
  store i1 %127, ptr %sc.129, align 1
  br i1 %127, label %label_2464, label %label_2463

label_2463:                                       ; preds = %label_2466
  %128 = load ptr, ptr %to_t.960, align 8
  %129 = getelementptr inbounds nuw %TypeInfo, ptr %128, i32 0, i32 0
  %130 = load i32, ptr %129, align 4
  %131 = icmp eq i32 %130, 9
  store i1 %131, ptr %sc.129, align 1
  br label %label_2464

label_2464:                                       ; preds = %label_2463, %label_2466
  %132 = load i1, ptr %sc.129, align 1
  store i1 %132, ptr %sc.128, align 1
  br i1 %132, label %label_2462, label %label_2461

label_2461:                                       ; preds = %label_2464
  %133 = load ptr, ptr %to_t.960, align 8
  %134 = getelementptr inbounds nuw %TypeInfo, ptr %133, i32 0, i32 0
  %135 = load i32, ptr %134, align 4
  %136 = icmp eq i32 %135, 4
  store i1 %136, ptr %sc.128, align 1
  br label %label_2462

label_2462:                                       ; preds = %label_2461, %label_2464
  %137 = load i1, ptr %sc.128, align 1
  store i1 %137, ptr %to_scalar.962, align 1
  %138 = load ptr, ptr %to_t.960, align 8
  %139 = getelementptr inbounds nuw %TypeInfo, ptr %138, i32 0, i32 0
  %140 = load i32, ptr %139, align 4
  %141 = icmp eq i32 %140, 4
  br i1 %141, label %label_2469, label %label_2471

label_2471:                                       ; preds = %label_2469, %label_2462
  %142 = load i1, ptr %from_scalar.961, align 1
  %143 = icmp eq i1 %142, false
  store i1 %143, ptr %sc.132, align 1
  br i1 %143, label %label_2473, label %label_2472

label_2469:                                       ; preds = %label_2462
  call void @sema_error__String(ptr @.str.s909)
  br label %label_2471

label_2472:                                       ; preds = %label_2471
  %144 = load i1, ptr %to_scalar.962, align 1
  %145 = icmp eq i1 %144, false
  store i1 %145, ptr %sc.132, align 1
  br label %label_2473

label_2473:                                       ; preds = %label_2472, %label_2471
  %146 = load i1, ptr %sc.132, align 1
  br i1 %146, label %label_2474, label %label_2476

label_2476:                                       ; preds = %label_2474, %label_2473
  %147 = load ptr, ptr %expr.955, align 8
  %148 = load ptr, ptr %to_t.960, align 8
  call void @node_set_type__Struct_ASTNode_Struct_TypeInfo(ptr %147, ptr %148)
  %149 = load ptr, ptr %to_t.960, align 8
  ret ptr %149

label_2474:                                       ; preds = %label_2473
  %150 = load ptr, ptr %to_t.960, align 8
  %151 = load ptr, ptr %from_t.959, align 8
  call void @sema_type_error__String_Struct_TypeInfo_Struct_TypeInfo(ptr @.str.s910, ptr %150, ptr %151)
  br label %label_2476

label_2479:                                       ; preds = %label_2493, %label_2452
  %152 = load ptr, ptr %expr.955, align 8
  %153 = getelementptr inbounds nuw %ASTNode, ptr %152, i32 0, i32 0
  %154 = load i32, ptr %153, align 4
  %155 = icmp eq i32 %154, 20
  br i1 %155, label %label_2500, label %label_2502

label_2477:                                       ; preds = %label_2452
  %156 = load ptr, ptr %expr.955, align 8
  %157 = getelementptr inbounds nuw %ASTNode, ptr %156, i32 0, i32 5
  %158 = load ptr, ptr %157, align 8
  %159 = call ptr @ptr_to_node(ptr %158)
  store ptr %159, ptr %operand.963, align 8
  %160 = load ptr, ptr %module.954, align 8
  %161 = load ptr, ptr %operand.963, align 8
  %162 = call ptr @sema_expr__Struct_ASTNode_Struct_ASTNode(ptr %160, ptr %161)
  store ptr %162, ptr %operand_t.964, align 8
  %163 = load ptr, ptr %expr.955, align 8
  %164 = getelementptr inbounds nuw %ASTNode, ptr %163, i32 0, i32 1
  %165 = load ptr, ptr %164, align 8
  store ptr %165, ptr %uop.965, align 8
  %166 = load ptr, ptr %uop.965, align 8
  %167 = call i32 @str_equals(ptr %166, ptr @.str.s911)
  %168 = icmp eq i32 %167, 1
  br i1 %168, label %label_2480, label %label_2482

label_2482:                                       ; preds = %label_2477
  %169 = load ptr, ptr %uop.965, align 8
  %170 = call i32 @str_equals(ptr %169, ptr @.str.s913)
  %171 = icmp eq i32 %170, 1
  br i1 %171, label %label_2483, label %label_2485

label_2480:                                       ; preds = %label_2477
  %172 = call ptr @type_bool__Void()
  %173 = load ptr, ptr %operand_t.964, align 8
  call void @sema_expect_assignable__String_Struct_TypeInfo_Struct_TypeInfo(ptr @.str.s912, ptr %172, ptr %173)
  %174 = load ptr, ptr %expr.955, align 8
  %175 = call ptr @type_bool__Void()
  call void @node_set_type__Struct_ASTNode_Struct_TypeInfo(ptr %174, ptr %175)
  %176 = call ptr @type_bool__Void()
  ret ptr %176

label_2485:                                       ; preds = %label_2482
  %177 = load ptr, ptr %uop.965, align 8
  %178 = call i32 @str_equals(ptr %177, ptr @.str.s915)
  %179 = icmp eq i32 %178, 1
  br i1 %179, label %label_2491, label %label_2493

label_2483:                                       ; preds = %label_2482
  %180 = load ptr, ptr %operand_t.964, align 8
  %181 = getelementptr inbounds nuw %TypeInfo, ptr %180, i32 0, i32 0
  %182 = load i32, ptr %181, align 4
  %183 = icmp ne i32 %182, 2
  store i1 %183, ptr %sc.133, align 1
  br i1 %183, label %label_2486, label %label_2487

label_2487:                                       ; preds = %label_2486, %label_2483
  %184 = load i1, ptr %sc.133, align 1
  br i1 %184, label %label_2488, label %label_2490

label_2486:                                       ; preds = %label_2483
  %185 = load ptr, ptr %operand_t.964, align 8
  %186 = getelementptr inbounds nuw %TypeInfo, ptr %185, i32 0, i32 0
  %187 = load i32, ptr %186, align 4
  %188 = icmp ne i32 %187, 5
  store i1 %188, ptr %sc.133, align 1
  br label %label_2487

label_2490:                                       ; preds = %label_2488, %label_2487
  %189 = load ptr, ptr %expr.955, align 8
  %190 = load ptr, ptr %operand_t.964, align 8
  call void @node_set_type__Struct_ASTNode_Struct_TypeInfo(ptr %189, ptr %190)
  %191 = load ptr, ptr %operand_t.964, align 8
  ret ptr %191

label_2488:                                       ; preds = %label_2487
  call void @sema_error__String(ptr @.str.s914)
  br label %label_2490

label_2493:                                       ; preds = %label_2485
  %192 = load ptr, ptr %uop.965, align 8
  %193 = call ptr @str_concat(ptr @.str.s918, ptr %192)
  call void @sema_error__String(ptr %193)
  br label %label_2479

label_2491:                                       ; preds = %label_2485
  %194 = load ptr, ptr %operand_t.964, align 8
  %195 = call i1 @type_is_numeric__Struct_TypeInfo(ptr %194)
  %196 = icmp eq i1 %195, false
  br i1 %196, label %label_2494, label %label_2496

label_2496:                                       ; preds = %label_2494, %label_2491
  %197 = load ptr, ptr %operand_t.964, align 8
  %198 = call i1 @type_int_is_unsigned__Struct_TypeInfo(ptr %197)
  br i1 %198, label %label_2497, label %label_2499

label_2494:                                       ; preds = %label_2491
  call void @sema_error__String(ptr @.str.s916)
  br label %label_2496

label_2499:                                       ; preds = %label_2497, %label_2496
  %199 = load ptr, ptr %expr.955, align 8
  %200 = load ptr, ptr %operand_t.964, align 8
  call void @node_set_type__Struct_ASTNode_Struct_TypeInfo(ptr %199, ptr %200)
  %201 = load ptr, ptr %operand_t.964, align 8
  ret ptr %201

label_2497:                                       ; preds = %label_2496
  %202 = load ptr, ptr %operand_t.964, align 8
  %203 = call ptr @type_display__Struct_TypeInfo(ptr %202)
  %204 = call ptr @str_concat(ptr @.str.s917, ptr %203)
  call void @sema_error__String(ptr %204)
  br label %label_2499

label_2502:                                       ; preds = %label_2580, %label_2479
  %205 = load ptr, ptr %expr.955, align 8
  %206 = getelementptr inbounds nuw %ASTNode, ptr %205, i32 0, i32 0
  %207 = load i32, ptr %206, align 4
  %208 = icmp eq i32 %207, 24
  br i1 %208, label %label_2591, label %label_2593

label_2500:                                       ; preds = %label_2479
  %209 = load ptr, ptr %expr.955, align 8
  %210 = getelementptr inbounds nuw %ASTNode, ptr %209, i32 0, i32 5
  %211 = load ptr, ptr %210, align 8
  %212 = call ptr @ptr_to_node(ptr %211)
  store ptr %212, ptr %left_node.966, align 8
  %213 = load ptr, ptr %expr.955, align 8
  %214 = getelementptr inbounds nuw %ASTNode, ptr %213, i32 0, i32 6
  %215 = load ptr, ptr %214, align 8
  %216 = call ptr @ptr_to_node(ptr %215)
  store ptr %216, ptr %right_node.967, align 8
  %217 = load ptr, ptr %module.954, align 8
  %218 = load ptr, ptr %left_node.966, align 8
  %219 = call ptr @sema_expr__Struct_ASTNode_Struct_ASTNode(ptr %217, ptr %218)
  store ptr %219, ptr %left_t.968, align 8
  %220 = load ptr, ptr %module.954, align 8
  %221 = load ptr, ptr %right_node.967, align 8
  %222 = call ptr @sema_expr__Struct_ASTNode_Struct_ASTNode(ptr %220, ptr %221)
  store ptr %222, ptr %right_t.969, align 8
  %223 = load ptr, ptr %left_t.968, align 8
  %224 = getelementptr inbounds nuw %TypeInfo, ptr %223, i32 0, i32 0
  %225 = load i32, ptr %224, align 4
  %226 = icmp eq i32 %225, 2
  store i1 %226, ptr %sc.135, align 1
  br i1 %226, label %label_2505, label %label_2506

label_2506:                                       ; preds = %label_2505, %label_2500
  %227 = load i1, ptr %sc.135, align 1
  store i1 %227, ptr %sc.134, align 1
  br i1 %227, label %label_2503, label %label_2504

label_2505:                                       ; preds = %label_2500
  %228 = load ptr, ptr %right_t.969, align 8
  %229 = getelementptr inbounds nuw %TypeInfo, ptr %228, i32 0, i32 0
  %230 = load i32, ptr %229, align 4
  %231 = icmp eq i32 %230, 2
  store i1 %231, ptr %sc.135, align 1
  br label %label_2506

label_2504:                                       ; preds = %label_2503, %label_2506
  %232 = load i1, ptr %sc.134, align 1
  br i1 %232, label %label_2507, label %label_2509

label_2503:                                       ; preds = %label_2506
  %233 = load ptr, ptr %left_t.968, align 8
  %234 = load ptr, ptr %right_t.969, align 8
  %235 = call i1 @type_equals__Struct_TypeInfo_Struct_TypeInfo(ptr %233, ptr %234)
  %236 = icmp eq i1 %235, false
  store i1 %236, ptr %sc.134, align 1
  br label %label_2504

label_2509:                                       ; preds = %label_2512, %label_2504
  %237 = load ptr, ptr %expr.955, align 8
  %238 = getelementptr inbounds nuw %ASTNode, ptr %237, i32 0, i32 1
  %239 = load ptr, ptr %238, align 8
  store ptr %239, ptr %op.970, align 8
  %240 = load ptr, ptr %op.970, align 8
  %241 = call i32 @str_equals(ptr %240, ptr @.str.s919)
  %242 = icmp eq i32 %241, 1
  store i1 %242, ptr %sc.136, align 1
  br i1 %242, label %label_2517, label %label_2516

label_2507:                                       ; preds = %label_2504
  %243 = load ptr, ptr %right_node.967, align 8
  %244 = call i1 @sema_is_int_literal__Struct_ASTNode(ptr %243)
  br i1 %244, label %label_2510, label %label_2511

label_2511:                                       ; preds = %label_2507
  %245 = load ptr, ptr %left_node.966, align 8
  %246 = call i1 @sema_is_int_literal__Struct_ASTNode(ptr %245)
  br i1 %246, label %label_2513, label %label_2515

label_2510:                                       ; preds = %label_2507
  %247 = load ptr, ptr %right_node.967, align 8
  %248 = load ptr, ptr %left_t.968, align 8
  call void @node_set_type__Struct_ASTNode_Struct_TypeInfo(ptr %247, ptr %248)
  %249 = load ptr, ptr %left_t.968, align 8
  %250 = call ptr @type_copy__Struct_TypeInfo(ptr %249)
  store ptr %250, ptr %right_t.969, align 8
  br label %label_2512

label_2512:                                       ; preds = %label_2515, %label_2510
  br label %label_2509

label_2515:                                       ; preds = %label_2513, %label_2511
  br label %label_2512

label_2513:                                       ; preds = %label_2511
  %251 = load ptr, ptr %left_node.966, align 8
  %252 = load ptr, ptr %right_t.969, align 8
  call void @node_set_type__Struct_ASTNode_Struct_TypeInfo(ptr %251, ptr %252)
  %253 = load ptr, ptr %right_t.969, align 8
  %254 = call ptr @type_copy__Struct_TypeInfo(ptr %253)
  store ptr %254, ptr %left_t.968, align 8
  br label %label_2515

label_2516:                                       ; preds = %label_2509
  %255 = load ptr, ptr %op.970, align 8
  %256 = call i32 @str_equals(ptr %255, ptr @.str.s920)
  %257 = icmp eq i32 %256, 1
  store i1 %257, ptr %sc.136, align 1
  br label %label_2517

label_2517:                                       ; preds = %label_2516, %label_2509
  %258 = load i1, ptr %sc.136, align 1
  br i1 %258, label %label_2518, label %label_2520

label_2520:                                       ; preds = %label_2517
  %259 = load ptr, ptr %op.970, align 8
  %260 = call i32 @str_equals(ptr %259, ptr @.str.s923)
  %261 = icmp eq i32 %260, 1
  store i1 %261, ptr %sc.139, align 1
  br i1 %261, label %label_2526, label %label_2525

label_2518:                                       ; preds = %label_2517
  %262 = call ptr @type_bool__Void()
  %263 = load ptr, ptr %left_t.968, align 8
  call void @sema_expect_assignable__String_Struct_TypeInfo_Struct_TypeInfo(ptr @.str.s921, ptr %262, ptr %263)
  %264 = call ptr @type_bool__Void()
  %265 = load ptr, ptr %right_t.969, align 8
  call void @sema_expect_assignable__String_Struct_TypeInfo_Struct_TypeInfo(ptr @.str.s922, ptr %264, ptr %265)
  %266 = load ptr, ptr %expr.955, align 8
  %267 = call ptr @type_bool__Void()
  call void @node_set_type__Struct_ASTNode_Struct_TypeInfo(ptr %266, ptr %267)
  %268 = call ptr @type_bool__Void()
  ret ptr %268

label_2525:                                       ; preds = %label_2520
  %269 = load ptr, ptr %op.970, align 8
  %270 = call i32 @str_equals(ptr %269, ptr @.str.s924)
  %271 = icmp eq i32 %270, 1
  store i1 %271, ptr %sc.139, align 1
  br label %label_2526

label_2526:                                       ; preds = %label_2525, %label_2520
  %272 = load i1, ptr %sc.139, align 1
  store i1 %272, ptr %sc.138, align 1
  br i1 %272, label %label_2524, label %label_2523

label_2523:                                       ; preds = %label_2526
  %273 = load ptr, ptr %op.970, align 8
  %274 = call i32 @str_equals(ptr %273, ptr @.str.s925)
  %275 = icmp eq i32 %274, 1
  store i1 %275, ptr %sc.138, align 1
  br label %label_2524

label_2524:                                       ; preds = %label_2523, %label_2526
  %276 = load i1, ptr %sc.138, align 1
  store i1 %276, ptr %sc.137, align 1
  br i1 %276, label %label_2522, label %label_2521

label_2521:                                       ; preds = %label_2524
  %277 = load ptr, ptr %op.970, align 8
  %278 = call i32 @str_equals(ptr %277, ptr @.str.s926)
  %279 = icmp eq i32 %278, 1
  store i1 %279, ptr %sc.137, align 1
  br label %label_2522

label_2522:                                       ; preds = %label_2521, %label_2524
  %280 = load i1, ptr %sc.137, align 1
  br i1 %280, label %label_2527, label %label_2529

label_2529:                                       ; preds = %label_2522
  %281 = load ptr, ptr %op.970, align 8
  %282 = call i32 @str_equals(ptr %281, ptr @.str.s929)
  %283 = icmp eq i32 %282, 1
  br i1 %283, label %label_2533, label %label_2535

label_2527:                                       ; preds = %label_2522
  %284 = load ptr, ptr %left_t.968, align 8
  %285 = call i1 @type_is_numeric__Struct_TypeInfo(ptr %284)
  %286 = icmp eq i1 %285, false
  br i1 %286, label %label_2530, label %label_2532

label_2532:                                       ; preds = %label_2530, %label_2527
  %287 = load ptr, ptr %op.970, align 8
  %288 = call ptr @str_concat(ptr @.str.s928, ptr %287)
  %289 = load ptr, ptr %left_t.968, align 8
  %290 = load ptr, ptr %right_t.969, align 8
  call void @sema_expect_assignable__String_Struct_TypeInfo_Struct_TypeInfo(ptr %288, ptr %289, ptr %290)
  %291 = load ptr, ptr %expr.955, align 8
  %292 = load ptr, ptr %left_t.968, align 8
  call void @node_set_type__Struct_ASTNode_Struct_TypeInfo(ptr %291, ptr %292)
  %293 = load ptr, ptr %left_t.968, align 8
  ret ptr %293

label_2530:                                       ; preds = %label_2527
  %294 = load ptr, ptr %op.970, align 8
  %295 = call ptr @str_concat(ptr @.str.s927, ptr %294)
  call void @sema_error__String(ptr %295)
  br label %label_2532

label_2535:                                       ; preds = %label_2529
  %296 = load ptr, ptr %op.970, align 8
  %297 = call i32 @str_equals(ptr %296, ptr @.str.s932)
  %298 = icmp eq i32 %297, 1
  store i1 %298, ptr %sc.142, align 1
  br i1 %298, label %label_2544, label %label_2543

label_2533:                                       ; preds = %label_2529
  %299 = load ptr, ptr %left_t.968, align 8
  %300 = getelementptr inbounds nuw %TypeInfo, ptr %299, i32 0, i32 0
  %301 = load i32, ptr %300, align 4
  %302 = icmp ne i32 %301, 2
  store i1 %302, ptr %sc.140, align 1
  br i1 %302, label %label_2536, label %label_2537

label_2537:                                       ; preds = %label_2536, %label_2533
  %303 = load i1, ptr %sc.140, align 1
  br i1 %303, label %label_2538, label %label_2540

label_2536:                                       ; preds = %label_2533
  %304 = load ptr, ptr %left_t.968, align 8
  %305 = getelementptr inbounds nuw %TypeInfo, ptr %304, i32 0, i32 0
  %306 = load i32, ptr %305, align 4
  %307 = icmp ne i32 %306, 9
  store i1 %307, ptr %sc.140, align 1
  br label %label_2537

label_2540:                                       ; preds = %label_2538, %label_2537
  %308 = load ptr, ptr %left_t.968, align 8
  %309 = load ptr, ptr %right_t.969, align 8
  call void @sema_expect_assignable__String_Struct_TypeInfo_Struct_TypeInfo(ptr @.str.s931, ptr %308, ptr %309)
  %310 = load ptr, ptr %expr.955, align 8
  %311 = load ptr, ptr %left_t.968, align 8
  call void @node_set_type__Struct_ASTNode_Struct_TypeInfo(ptr %310, ptr %311)
  %312 = load ptr, ptr %left_t.968, align 8
  ret ptr %312

label_2538:                                       ; preds = %label_2537
  call void @sema_error__String(ptr @.str.s930)
  br label %label_2540

label_2543:                                       ; preds = %label_2535
  %313 = load ptr, ptr %op.970, align 8
  %314 = call i32 @str_equals(ptr %313, ptr @.str.s933)
  %315 = icmp eq i32 %314, 1
  store i1 %315, ptr %sc.142, align 1
  br label %label_2544

label_2544:                                       ; preds = %label_2543, %label_2535
  %316 = load i1, ptr %sc.142, align 1
  store i1 %316, ptr %sc.141, align 1
  br i1 %316, label %label_2542, label %label_2541

label_2541:                                       ; preds = %label_2544
  %317 = load ptr, ptr %op.970, align 8
  %318 = call i32 @str_equals(ptr %317, ptr @.str.s934)
  %319 = icmp eq i32 %318, 1
  store i1 %319, ptr %sc.141, align 1
  br label %label_2542

label_2542:                                       ; preds = %label_2541, %label_2544
  %320 = load i1, ptr %sc.141, align 1
  br i1 %320, label %label_2545, label %label_2547

label_2547:                                       ; preds = %label_2542
  %321 = load ptr, ptr %op.970, align 8
  %322 = call i32 @str_equals(ptr %321, ptr @.str.s937)
  %323 = icmp eq i32 %322, 1
  store i1 %323, ptr %sc.145, align 1
  br i1 %323, label %label_2556, label %label_2555

label_2545:                                       ; preds = %label_2542
  %324 = load ptr, ptr %left_t.968, align 8
  %325 = getelementptr inbounds nuw %TypeInfo, ptr %324, i32 0, i32 0
  %326 = load i32, ptr %325, align 4
  %327 = icmp ne i32 %326, 2
  store i1 %327, ptr %sc.144, align 1
  br i1 %327, label %label_2550, label %label_2551

label_2551:                                       ; preds = %label_2550, %label_2545
  %328 = load i1, ptr %sc.144, align 1
  store i1 %328, ptr %sc.143, align 1
  br i1 %328, label %label_2548, label %label_2549

label_2550:                                       ; preds = %label_2545
  %329 = load ptr, ptr %left_t.968, align 8
  %330 = getelementptr inbounds nuw %TypeInfo, ptr %329, i32 0, i32 0
  %331 = load i32, ptr %330, align 4
  %332 = icmp ne i32 %331, 9
  store i1 %332, ptr %sc.144, align 1
  br label %label_2551

label_2549:                                       ; preds = %label_2548, %label_2551
  %333 = load i1, ptr %sc.143, align 1
  br i1 %333, label %label_2552, label %label_2554

label_2548:                                       ; preds = %label_2551
  %334 = load ptr, ptr %left_t.968, align 8
  %335 = getelementptr inbounds nuw %TypeInfo, ptr %334, i32 0, i32 0
  %336 = load i32, ptr %335, align 4
  %337 = icmp ne i32 %336, 5
  store i1 %337, ptr %sc.143, align 1
  br label %label_2549

label_2554:                                       ; preds = %label_2552, %label_2549
  %338 = load ptr, ptr %op.970, align 8
  %339 = call ptr @str_concat(ptr @.str.s936, ptr %338)
  %340 = load ptr, ptr %left_t.968, align 8
  %341 = load ptr, ptr %right_t.969, align 8
  call void @sema_expect_assignable__String_Struct_TypeInfo_Struct_TypeInfo(ptr %339, ptr %340, ptr %341)
  %342 = load ptr, ptr %expr.955, align 8
  %343 = load ptr, ptr %left_t.968, align 8
  call void @node_set_type__Struct_ASTNode_Struct_TypeInfo(ptr %342, ptr %343)
  %344 = load ptr, ptr %left_t.968, align 8
  ret ptr %344

label_2552:                                       ; preds = %label_2549
  %345 = load ptr, ptr %op.970, align 8
  %346 = call ptr @str_concat(ptr @.str.s935, ptr %345)
  call void @sema_error__String(ptr %346)
  br label %label_2554

label_2555:                                       ; preds = %label_2547
  %347 = load ptr, ptr %op.970, align 8
  %348 = call i32 @str_equals(ptr %347, ptr @.str.s938)
  %349 = icmp eq i32 %348, 1
  store i1 %349, ptr %sc.145, align 1
  br label %label_2556

label_2556:                                       ; preds = %label_2555, %label_2547
  %350 = load i1, ptr %sc.145, align 1
  br i1 %350, label %label_2557, label %label_2559

label_2559:                                       ; preds = %label_2556
  %351 = load ptr, ptr %op.970, align 8
  %352 = call i32 @str_equals(ptr %351, ptr @.str.s941)
  %353 = icmp eq i32 %352, 1
  store i1 %353, ptr %sc.151, align 1
  br i1 %353, label %label_2577, label %label_2576

label_2557:                                       ; preds = %label_2556
  %354 = load ptr, ptr %left_t.968, align 8
  %355 = getelementptr inbounds nuw %TypeInfo, ptr %354, i32 0, i32 0
  %356 = load i32, ptr %355, align 4
  %357 = icmp ne i32 %356, 2
  store i1 %357, ptr %sc.146, align 1
  br i1 %357, label %label_2560, label %label_2561

label_2561:                                       ; preds = %label_2560, %label_2557
  %358 = load i1, ptr %sc.146, align 1
  br i1 %358, label %label_2562, label %label_2564

label_2560:                                       ; preds = %label_2557
  %359 = load ptr, ptr %left_t.968, align 8
  %360 = getelementptr inbounds nuw %TypeInfo, ptr %359, i32 0, i32 0
  %361 = load i32, ptr %360, align 4
  %362 = icmp ne i32 %361, 5
  store i1 %362, ptr %sc.146, align 1
  br label %label_2561

label_2564:                                       ; preds = %label_2562, %label_2561
  %363 = load ptr, ptr %right_t.969, align 8
  %364 = getelementptr inbounds nuw %TypeInfo, ptr %363, i32 0, i32 0
  %365 = load i32, ptr %364, align 4
  %366 = icmp ne i32 %365, 2
  br i1 %366, label %label_2565, label %label_2567

label_2562:                                       ; preds = %label_2561
  %367 = load ptr, ptr %op.970, align 8
  %368 = call ptr @str_concat(ptr @.str.s939, ptr %367)
  call void @sema_error__String(ptr %368)
  br label %label_2564

label_2567:                                       ; preds = %label_2565, %label_2564
  %369 = load ptr, ptr %expr.955, align 8
  %370 = load ptr, ptr %left_t.968, align 8
  call void @node_set_type__Struct_ASTNode_Struct_TypeInfo(ptr %369, ptr %370)
  %371 = load ptr, ptr %left_t.968, align 8
  ret ptr %371

label_2565:                                       ; preds = %label_2564
  %372 = load ptr, ptr %op.970, align 8
  %373 = call ptr @str_concat(ptr @.str.s940, ptr %372)
  call void @sema_error__String(ptr %373)
  br label %label_2567

label_2576:                                       ; preds = %label_2559
  %374 = load ptr, ptr %op.970, align 8
  %375 = call i32 @str_equals(ptr %374, ptr @.str.s942)
  %376 = icmp eq i32 %375, 1
  store i1 %376, ptr %sc.151, align 1
  br label %label_2577

label_2577:                                       ; preds = %label_2576, %label_2559
  %377 = load i1, ptr %sc.151, align 1
  store i1 %377, ptr %sc.150, align 1
  br i1 %377, label %label_2575, label %label_2574

label_2574:                                       ; preds = %label_2577
  %378 = load ptr, ptr %op.970, align 8
  %379 = call i32 @str_equals(ptr %378, ptr @.str.s943)
  %380 = icmp eq i32 %379, 1
  store i1 %380, ptr %sc.150, align 1
  br label %label_2575

label_2575:                                       ; preds = %label_2574, %label_2577
  %381 = load i1, ptr %sc.150, align 1
  store i1 %381, ptr %sc.149, align 1
  br i1 %381, label %label_2573, label %label_2572

label_2572:                                       ; preds = %label_2575
  %382 = load ptr, ptr %op.970, align 8
  %383 = call i32 @str_equals(ptr %382, ptr @.str.s944)
  %384 = icmp eq i32 %383, 1
  store i1 %384, ptr %sc.149, align 1
  br label %label_2573

label_2573:                                       ; preds = %label_2572, %label_2575
  %385 = load i1, ptr %sc.149, align 1
  store i1 %385, ptr %sc.148, align 1
  br i1 %385, label %label_2571, label %label_2570

label_2570:                                       ; preds = %label_2573
  %386 = load ptr, ptr %op.970, align 8
  %387 = call i32 @str_equals(ptr %386, ptr @.str.s945)
  %388 = icmp eq i32 %387, 1
  store i1 %388, ptr %sc.148, align 1
  br label %label_2571

label_2571:                                       ; preds = %label_2570, %label_2573
  %389 = load i1, ptr %sc.148, align 1
  store i1 %389, ptr %sc.147, align 1
  br i1 %389, label %label_2569, label %label_2568

label_2568:                                       ; preds = %label_2571
  %390 = load ptr, ptr %op.970, align 8
  %391 = call i32 @str_equals(ptr %390, ptr @.str.s946)
  %392 = icmp eq i32 %391, 1
  store i1 %392, ptr %sc.147, align 1
  br label %label_2569

label_2569:                                       ; preds = %label_2568, %label_2571
  %393 = load i1, ptr %sc.147, align 1
  br i1 %393, label %label_2578, label %label_2580

label_2580:                                       ; preds = %label_2569
  %394 = load ptr, ptr %op.970, align 8
  %395 = call ptr @str_concat(ptr @.str.s950, ptr %394)
  call void @sema_error__String(ptr %395)
  br label %label_2502

label_2578:                                       ; preds = %label_2569
  %396 = load ptr, ptr %left_t.968, align 8
  %397 = getelementptr inbounds nuw %TypeInfo, ptr %396, i32 0, i32 0
  %398 = load i32, ptr %397, align 4
  %399 = icmp eq i32 %398, 6
  store i1 %399, ptr %sc.152, align 1
  br i1 %399, label %label_2582, label %label_2581

label_2581:                                       ; preds = %label_2578
  %400 = load ptr, ptr %right_t.969, align 8
  %401 = getelementptr inbounds nuw %TypeInfo, ptr %400, i32 0, i32 0
  %402 = load i32, ptr %401, align 4
  %403 = icmp eq i32 %402, 6
  store i1 %403, ptr %sc.152, align 1
  br label %label_2582

label_2582:                                       ; preds = %label_2581, %label_2578
  %404 = load i1, ptr %sc.152, align 1
  br i1 %404, label %label_2583, label %label_2585

label_2585:                                       ; preds = %label_2583, %label_2582
  %405 = load ptr, ptr %left_t.968, align 8
  %406 = getelementptr inbounds nuw %TypeInfo, ptr %405, i32 0, i32 0
  %407 = load i32, ptr %406, align 4
  %408 = icmp eq i32 %407, 8
  store i1 %408, ptr %sc.153, align 1
  br i1 %408, label %label_2587, label %label_2586

label_2583:                                       ; preds = %label_2582
  call void @sema_error__String(ptr @.str.s947)
  br label %label_2585

label_2586:                                       ; preds = %label_2585
  %409 = load ptr, ptr %right_t.969, align 8
  %410 = getelementptr inbounds nuw %TypeInfo, ptr %409, i32 0, i32 0
  %411 = load i32, ptr %410, align 4
  %412 = icmp eq i32 %411, 8
  store i1 %412, ptr %sc.153, align 1
  br label %label_2587

label_2587:                                       ; preds = %label_2586, %label_2585
  %413 = load i1, ptr %sc.153, align 1
  br i1 %413, label %label_2588, label %label_2590

label_2590:                                       ; preds = %label_2588, %label_2587
  %414 = load ptr, ptr %op.970, align 8
  %415 = call ptr @str_concat(ptr @.str.s949, ptr %414)
  %416 = load ptr, ptr %left_t.968, align 8
  %417 = load ptr, ptr %right_t.969, align 8
  call void @sema_expect_assignable__String_Struct_TypeInfo_Struct_TypeInfo(ptr %415, ptr %416, ptr %417)
  %418 = load ptr, ptr %expr.955, align 8
  %419 = call ptr @type_bool__Void()
  call void @node_set_type__Struct_ASTNode_Struct_TypeInfo(ptr %418, ptr %419)
  %420 = call ptr @type_bool__Void()
  ret ptr %420

label_2588:                                       ; preds = %label_2587
  call void @sema_error__String(ptr @.str.s948)
  br label %label_2590

label_2593:                                       ; preds = %label_2502
  %421 = load ptr, ptr %expr.955, align 8
  %422 = getelementptr inbounds nuw %ASTNode, ptr %421, i32 0, i32 0
  %423 = load i32, ptr %422, align 4
  %424 = icmp eq i32 %423, 25
  br i1 %424, label %label_2611, label %label_2613

label_2591:                                       ; preds = %label_2502
  %425 = load ptr, ptr %expr.955, align 8
  %426 = getelementptr inbounds nuw %ASTNode, ptr %425, i32 0, i32 5
  %427 = load ptr, ptr %426, align 8
  %428 = call ptr @ptr_to_node(ptr %427)
  store ptr %428, ptr %callee.971, align 8
  %429 = load ptr, ptr %callee.971, align 8
  %430 = getelementptr inbounds nuw %ASTNode, ptr %429, i32 0, i32 1
  %431 = load ptr, ptr %430, align 8
  store ptr %431, ptr %name.972, align 8
  %432 = load ptr, ptr %module.954, align 8
  %433 = load ptr, ptr %name.972, align 8
  %434 = load ptr, ptr %expr.955, align 8
  %435 = getelementptr inbounds nuw %ASTNode, ptr %434, i32 0, i32 6
  %436 = load ptr, ptr %435, align 8
  %437 = call i1 @sema_check_builtin_call__Struct_ASTNode_String_String(ptr %432, ptr %433, ptr %436)
  br i1 %437, label %label_2594, label %label_2596

label_2596:                                       ; preds = %label_2591
  %438 = load ptr, ptr %module.954, align 8
  %439 = load ptr, ptr %name.972, align 8
  %440 = load ptr, ptr %expr.955, align 8
  %441 = getelementptr inbounds nuw %ASTNode, ptr %440, i32 0, i32 6
  %442 = load ptr, ptr %441, align 8
  %443 = call ptr @sema_find_function_overload__Struct_ASTNode_String_String(ptr %438, ptr %439, ptr %442)
  store ptr %443, ptr %fn_node.974, align 8
  %444 = load ptr, ptr %expr.955, align 8
  %445 = getelementptr inbounds nuw %ASTNode, ptr %444, i32 0, i32 6
  %446 = load ptr, ptr %445, align 8
  store ptr %446, ptr %arg_ptr.975, align 8
  %447 = load ptr, ptr %fn_node.974, align 8
  %448 = getelementptr inbounds nuw %ASTNode, ptr %447, i32 0, i32 5
  %449 = load ptr, ptr %448, align 8
  store ptr %449, ptr %param_ptr.976, align 8
  br label %label_2597

label_2594:                                       ; preds = %label_2591
  %450 = load ptr, ptr %name.972, align 8
  %451 = load ptr, ptr %expr.955, align 8
  %452 = getelementptr inbounds nuw %ASTNode, ptr %451, i32 0, i32 6
  %453 = load ptr, ptr %452, align 8
  %454 = call ptr @sema_builtin_call_type__String_String(ptr %450, ptr %453)
  store ptr %454, ptr %builtin_t.973, align 8
  %455 = load ptr, ptr %expr.955, align 8
  %456 = load ptr, ptr %builtin_t.973, align 8
  call void @node_set_type__Struct_ASTNode_Struct_TypeInfo(ptr %455, ptr %456)
  %457 = load ptr, ptr %builtin_t.973, align 8
  ret ptr %457

label_2597:                                       ; preds = %label_2604, %label_2596
  %458 = load ptr, ptr %arg_ptr.975, align 8
  %459 = call i32 @str_equals(ptr %458, ptr @.str.s951)
  %460 = icmp eq i32 %459, 0
  store i1 %460, ptr %sc.154, align 1
  br i1 %460, label %label_2600, label %label_2601

label_2601:                                       ; preds = %label_2600, %label_2597
  %461 = load i1, ptr %sc.154, align 1
  br i1 %461, label %label_2598, label %label_2599

label_2600:                                       ; preds = %label_2597
  %462 = load ptr, ptr %param_ptr.976, align 8
  %463 = call i32 @str_equals(ptr %462, ptr @.str.s952)
  %464 = icmp eq i32 %463, 0
  store i1 %464, ptr %sc.154, align 1
  br label %label_2601

label_2599:                                       ; preds = %label_2601
  %465 = call ptr @type_void__Void()
  store ptr %465, ptr %ret_t.980, align 8
  %466 = load ptr, ptr %fn_node.974, align 8
  %467 = getelementptr inbounds nuw %ASTNode, ptr %466, i32 0, i32 0
  %468 = load i32, ptr %467, align 4
  %469 = icmp eq i32 %468, 4
  br i1 %469, label %label_2605, label %label_2606

label_2598:                                       ; preds = %label_2601
  %470 = load ptr, ptr %arg_ptr.975, align 8
  %471 = call ptr @ptr_to_node(ptr %470)
  store ptr %471, ptr %arg_node.977, align 8
  %472 = load ptr, ptr %param_ptr.976, align 8
  %473 = call ptr @ptr_to_node(ptr %472)
  store ptr %473, ptr %param_node.978, align 8
  %474 = load ptr, ptr %module.954, align 8
  %475 = load ptr, ptr %param_node.978, align 8
  %476 = getelementptr inbounds nuw %ASTNode, ptr %475, i32 0, i32 5
  %477 = load ptr, ptr %476, align 8
  %478 = call ptr @ptr_to_node(ptr %477)
  %479 = call ptr @sema_annotation_type__Struct_ASTNode_Struct_ASTNode(ptr %474, ptr %478)
  store ptr %479, ptr %param_t.979, align 8
  %480 = load ptr, ptr %module.954, align 8
  %481 = load ptr, ptr %arg_node.977, align 8
  %482 = load ptr, ptr %param_t.979, align 8
  %483 = load ptr, ptr %name.972, align 8
  %484 = call ptr @str_concat(ptr %483, ptr @.str.s953)
  %485 = call ptr @sema_check_value__Struct_ASTNode_Struct_ASTNode_Struct_TypeInfo_String(ptr %480, ptr %481, ptr %482, ptr %484)
  %486 = load ptr, ptr %param_node.978, align 8
  %487 = getelementptr inbounds nuw %ASTNode, ptr %486, i32 0, i32 2
  %488 = load ptr, ptr %487, align 8
  %489 = call i32 @str_equals(ptr %488, ptr @.str.s954)
  %490 = icmp eq i32 %489, 1
  br i1 %490, label %label_2602, label %label_2604

label_2604:                                       ; preds = %label_2602, %label_2598
  %491 = load ptr, ptr %arg_node.977, align 8
  %492 = getelementptr inbounds nuw %ASTNode, ptr %491, i32 0, i32 8
  %493 = load ptr, ptr %492, align 8
  store ptr %493, ptr %arg_ptr.975, align 8
  %494 = load ptr, ptr %param_node.978, align 8
  %495 = getelementptr inbounds nuw %ASTNode, ptr %494, i32 0, i32 8
  %496 = load ptr, ptr %495, align 8
  store ptr %496, ptr %param_ptr.976, align 8
  br label %label_2597

label_2602:                                       ; preds = %label_2598
  %497 = load ptr, ptr %arg_node.977, align 8
  call void @sema_move_operand__Struct_ASTNode(ptr %497)
  br label %label_2604

label_2606:                                       ; preds = %label_2599
  %498 = load ptr, ptr %module.954, align 8
  %499 = load ptr, ptr %fn_node.974, align 8
  %500 = getelementptr inbounds nuw %ASTNode, ptr %499, i32 0, i32 6
  %501 = load ptr, ptr %500, align 8
  %502 = call ptr @sema_declared_return_type__Struct_ASTNode_String(ptr %498, ptr %501)
  store ptr %502, ptr %ret_t.980, align 8
  br label %label_2607

label_2605:                                       ; preds = %label_2599
  %503 = load ptr, ptr %module.954, align 8
  %504 = load ptr, ptr %fn_node.974, align 8
  %505 = getelementptr inbounds nuw %ASTNode, ptr %504, i32 0, i32 7
  %506 = load ptr, ptr %505, align 8
  %507 = call ptr @sema_declared_return_type__Struct_ASTNode_String(ptr %503, ptr %506)
  store ptr %507, ptr %ret_t.980, align 8
  %508 = load ptr, ptr %name.972, align 8
  %509 = call i32 @str_equals(ptr %508, ptr @.str.s955)
  %510 = icmp eq i32 %509, 1
  br i1 %510, label %label_2608, label %label_2610

label_2610:                                       ; preds = %label_2608, %label_2605
  br label %label_2607

label_2608:                                       ; preds = %label_2605
  %511 = call ptr @type_int__Void()
  store ptr %511, ptr %ret_t.980, align 8
  br label %label_2610

label_2607:                                       ; preds = %label_2606, %label_2610
  %512 = load ptr, ptr %expr.955, align 8
  %513 = load ptr, ptr %module.954, align 8
  %514 = load ptr, ptr %fn_node.974, align 8
  %515 = call ptr @sema_function_symbol__Struct_ASTNode_Struct_ASTNode(ptr %513, ptr %514)
  %516 = getelementptr inbounds nuw %ASTNode, ptr %512, i32 0, i32 2
  store ptr %515, ptr %516, align 8
  %517 = load ptr, ptr %expr.955, align 8
  %518 = load ptr, ptr %ret_t.980, align 8
  call void @node_set_type__Struct_ASTNode_Struct_TypeInfo(ptr %517, ptr %518)
  %519 = load ptr, ptr %ret_t.980, align 8
  ret ptr %519

label_2613:                                       ; preds = %label_2593
  %520 = load ptr, ptr %expr.955, align 8
  %521 = getelementptr inbounds nuw %ASTNode, ptr %520, i32 0, i32 0
  %522 = load i32, ptr %521, align 4
  %523 = icmp eq i32 %522, 27
  br i1 %523, label %label_2622, label %label_2624

label_2611:                                       ; preds = %label_2593
  %524 = load ptr, ptr %expr.955, align 8
  %525 = getelementptr inbounds nuw %ASTNode, ptr %524, i32 0, i32 5
  %526 = load ptr, ptr %525, align 8
  %527 = call ptr @ptr_to_node(ptr %526)
  store ptr %527, ptr %object_node.981, align 8
  %528 = load ptr, ptr %object_node.981, align 8
  %529 = getelementptr inbounds nuw %ASTNode, ptr %528, i32 0, i32 0
  %530 = load i32, ptr %529, align 4
  %531 = icmp eq i32 %530, 23
  store i1 %531, ptr %sc.155, align 1
  br i1 %531, label %label_2614, label %label_2615

label_2615:                                       ; preds = %label_2614, %label_2611
  %532 = load i1, ptr %sc.155, align 1
  br i1 %532, label %label_2616, label %label_2618

label_2614:                                       ; preds = %label_2611
  %533 = load ptr, ptr %module.954, align 8
  %534 = load ptr, ptr %object_node.981, align 8
  %535 = getelementptr inbounds nuw %ASTNode, ptr %534, i32 0, i32 1
  %536 = load ptr, ptr %535, align 8
  %537 = load ptr, ptr %expr.955, align 8
  %538 = getelementptr inbounds nuw %ASTNode, ptr %537, i32 0, i32 1
  %539 = load ptr, ptr %538, align 8
  %540 = call i1 @sema_enum_has_variant__Struct_ASTNode_String_String(ptr %533, ptr %536, ptr %539)
  store i1 %540, ptr %sc.155, align 1
  br label %label_2615

label_2618:                                       ; preds = %label_2615
  %541 = load ptr, ptr %module.954, align 8
  %542 = load ptr, ptr %object_node.981, align 8
  %543 = call ptr @sema_expr__Struct_ASTNode_Struct_ASTNode(ptr %541, ptr %542)
  store ptr %543, ptr %object_t.982, align 8
  %544 = load ptr, ptr %object_t.982, align 8
  %545 = getelementptr inbounds nuw %TypeInfo, ptr %544, i32 0, i32 0
  %546 = load i32, ptr %545, align 4
  %547 = icmp ne i32 %546, 8
  br i1 %547, label %label_2619, label %label_2621

label_2616:                                       ; preds = %label_2615
  %548 = load ptr, ptr %expr.955, align 8
  %549 = call ptr @type_int__Void()
  call void @node_set_type__Struct_ASTNode_Struct_TypeInfo(ptr %548, ptr %549)
  %550 = call ptr @type_int__Void()
  ret ptr %550

label_2621:                                       ; preds = %label_2619, %label_2618
  %551 = load ptr, ptr %module.954, align 8
  %552 = load ptr, ptr %object_t.982, align 8
  %553 = getelementptr inbounds nuw %TypeInfo, ptr %552, i32 0, i32 1
  %554 = load ptr, ptr %553, align 8
  %555 = load ptr, ptr %expr.955, align 8
  %556 = getelementptr inbounds nuw %ASTNode, ptr %555, i32 0, i32 1
  %557 = load ptr, ptr %556, align 8
  %558 = call ptr @sema_find_struct_field_type__Struct_ASTNode_String_String(ptr %551, ptr %554, ptr %557)
  store ptr %558, ptr %field_t.983, align 8
  %559 = load ptr, ptr %expr.955, align 8
  %560 = load ptr, ptr %field_t.983, align 8
  call void @node_set_type__Struct_ASTNode_Struct_TypeInfo(ptr %559, ptr %560)
  %561 = load ptr, ptr %field_t.983, align 8
  ret ptr %561

label_2619:                                       ; preds = %label_2618
  call void @sema_error__String(ptr @.str.s956)
  br label %label_2621

label_2624:                                       ; preds = %label_2613
  %562 = load ptr, ptr %expr.955, align 8
  %563 = getelementptr inbounds nuw %ASTNode, ptr %562, i32 0, i32 0
  %564 = load i32, ptr %563, align 4
  %565 = icmp eq i32 %564, 26
  br i1 %565, label %label_2631, label %label_2633

label_2622:                                       ; preds = %label_2613
  %566 = load ptr, ptr %expr.955, align 8
  %567 = getelementptr inbounds nuw %ASTNode, ptr %566, i32 0, i32 5
  %568 = load ptr, ptr %567, align 8
  store ptr %568, ptr %elem_ptr.984, align 8
  %569 = load ptr, ptr %elem_ptr.984, align 8
  %570 = call i32 @str_equals(ptr %569, ptr @.str.s957)
  %571 = icmp eq i32 %570, 1
  br i1 %571, label %label_2625, label %label_2627

label_2627:                                       ; preds = %label_2622
  %572 = load ptr, ptr %module.954, align 8
  %573 = load ptr, ptr %elem_ptr.984, align 8
  %574 = call ptr @ptr_to_node(ptr %573)
  %575 = call ptr @sema_expr__Struct_ASTNode_Struct_ASTNode(ptr %572, ptr %574)
  store ptr %575, ptr %first_t.986, align 8
  %576 = load ptr, ptr %elem_ptr.984, align 8
  %577 = call ptr @ptr_to_node(ptr %576)
  %578 = getelementptr inbounds nuw %ASTNode, ptr %577, i32 0, i32 8
  %579 = load ptr, ptr %578, align 8
  store ptr %579, ptr %elem_ptr.984, align 8
  br label %label_2628

label_2625:                                       ; preds = %label_2622
  %580 = call ptr @type_invalid__Void()
  %581 = call ptr @type_array__Struct_TypeInfo(ptr %580)
  store ptr %581, ptr %arr_t.985, align 8
  %582 = load ptr, ptr %expr.955, align 8
  %583 = load ptr, ptr %arr_t.985, align 8
  call void @node_set_type__Struct_ASTNode_Struct_TypeInfo(ptr %582, ptr %583)
  %584 = load ptr, ptr %arr_t.985, align 8
  ret ptr %584

label_2628:                                       ; preds = %label_2629, %label_2627
  %585 = load ptr, ptr %elem_ptr.984, align 8
  %586 = call i32 @str_equals(ptr %585, ptr @.str.s958)
  %587 = icmp eq i32 %586, 0
  br i1 %587, label %label_2629, label %label_2630

label_2630:                                       ; preds = %label_2628
  %588 = load ptr, ptr %first_t.986, align 8
  %589 = call ptr @type_array__Struct_TypeInfo(ptr %588)
  store ptr %589, ptr %arr_t2.989, align 8
  %590 = load ptr, ptr %expr.955, align 8
  %591 = load ptr, ptr %arr_t2.989, align 8
  call void @node_set_type__Struct_ASTNode_Struct_TypeInfo(ptr %590, ptr %591)
  %592 = load ptr, ptr %arr_t2.989, align 8
  ret ptr %592

label_2629:                                       ; preds = %label_2628
  %593 = load ptr, ptr %elem_ptr.984, align 8
  %594 = call ptr @ptr_to_node(ptr %593)
  store ptr %594, ptr %elem.987, align 8
  %595 = load ptr, ptr %module.954, align 8
  %596 = load ptr, ptr %elem.987, align 8
  %597 = call ptr @sema_expr__Struct_ASTNode_Struct_ASTNode(ptr %595, ptr %596)
  store ptr %597, ptr %elem_t.988, align 8
  %598 = load ptr, ptr %first_t.986, align 8
  %599 = load ptr, ptr %elem_t.988, align 8
  call void @sema_expect_assignable__String_Struct_TypeInfo_Struct_TypeInfo(ptr @.str.s959, ptr %598, ptr %599)
  %600 = load ptr, ptr %elem.987, align 8
  %601 = getelementptr inbounds nuw %ASTNode, ptr %600, i32 0, i32 8
  %602 = load ptr, ptr %601, align 8
  store ptr %602, ptr %elem_ptr.984, align 8
  br label %label_2628

label_2633:                                       ; preds = %label_2624
  %603 = load ptr, ptr %expr.955, align 8
  %604 = getelementptr inbounds nuw %ASTNode, ptr %603, i32 0, i32 0
  %605 = load i32, ptr %604, align 4
  %606 = icmp eq i32 %605, 28
  br i1 %606, label %label_2637, label %label_2639

label_2631:                                       ; preds = %label_2624
  %607 = load ptr, ptr %module.954, align 8
  %608 = load ptr, ptr %expr.955, align 8
  %609 = getelementptr inbounds nuw %ASTNode, ptr %608, i32 0, i32 5
  %610 = load ptr, ptr %609, align 8
  %611 = call ptr @ptr_to_node(ptr %610)
  %612 = call ptr @sema_expr__Struct_ASTNode_Struct_ASTNode(ptr %607, ptr %611)
  store ptr %612, ptr %array_t.990, align 8
  %613 = load ptr, ptr %module.954, align 8
  %614 = load ptr, ptr %expr.955, align 8
  %615 = getelementptr inbounds nuw %ASTNode, ptr %614, i32 0, i32 6
  %616 = load ptr, ptr %615, align 8
  %617 = call ptr @ptr_to_node(ptr %616)
  %618 = call ptr @sema_expr__Struct_ASTNode_Struct_ASTNode(ptr %613, ptr %617)
  store ptr %618, ptr %index_t.991, align 8
  %619 = call ptr @type_int__Void()
  %620 = load ptr, ptr %index_t.991, align 8
  call void @sema_expect_assignable__String_Struct_TypeInfo_Struct_TypeInfo(ptr @.str.s960, ptr %619, ptr %620)
  %621 = load ptr, ptr %array_t.990, align 8
  %622 = getelementptr inbounds nuw %TypeInfo, ptr %621, i32 0, i32 0
  %623 = load i32, ptr %622, align 4
  %624 = icmp ne i32 %623, 10
  br i1 %624, label %label_2634, label %label_2636

label_2636:                                       ; preds = %label_2634, %label_2631
  %625 = load ptr, ptr %array_t.990, align 8
  %626 = getelementptr inbounds nuw %TypeInfo, ptr %625, i32 0, i32 3
  %627 = load ptr, ptr %626, align 8
  %628 = call ptr @ptr_to_type(ptr %627)
  store ptr %628, ptr %elem_t.992, align 8
  %629 = load ptr, ptr %expr.955, align 8
  %630 = load ptr, ptr %elem_t.992, align 8
  call void @node_set_type__Struct_ASTNode_Struct_TypeInfo(ptr %629, ptr %630)
  %631 = load ptr, ptr %elem_t.992, align 8
  ret ptr %631

label_2634:                                       ; preds = %label_2631
  call void @sema_error__String(ptr @.str.s961)
  br label %label_2636

label_2639:                                       ; preds = %label_2633
  call void @sema_error__String(ptr @.str.s965)
  %632 = call ptr @type_invalid__Void()
  ret ptr %632

label_2637:                                       ; preds = %label_2633
  %633 = load ptr, ptr %module.954, align 8
  %634 = load ptr, ptr %expr.955, align 8
  %635 = getelementptr inbounds nuw %ASTNode, ptr %634, i32 0, i32 1
  %636 = load ptr, ptr %635, align 8
  %637 = call i1 @sema_has_struct__Struct_ASTNode_String(ptr %633, ptr %636)
  %638 = icmp eq i1 %637, false
  br i1 %638, label %label_2640, label %label_2642

label_2642:                                       ; preds = %label_2640, %label_2637
  %639 = load ptr, ptr %expr.955, align 8
  %640 = getelementptr inbounds nuw %ASTNode, ptr %639, i32 0, i32 5
  %641 = load ptr, ptr %640, align 8
  store ptr %641, ptr %field_ptr.993, align 8
  br label %label_2643

label_2640:                                       ; preds = %label_2637
  %642 = load ptr, ptr %expr.955, align 8
  %643 = getelementptr inbounds nuw %ASTNode, ptr %642, i32 0, i32 1
  %644 = load ptr, ptr %643, align 8
  %645 = call ptr @str_concat(ptr @.str.s962, ptr %644)
  call void @sema_error__String(ptr %645)
  br label %label_2642

label_2643:                                       ; preds = %label_2644, %label_2642
  %646 = load ptr, ptr %field_ptr.993, align 8
  %647 = call i32 @str_equals(ptr %646, ptr @.str.s963)
  %648 = icmp eq i32 %647, 0
  br i1 %648, label %label_2644, label %label_2645

label_2645:                                       ; preds = %label_2643
  %649 = load ptr, ptr %expr.955, align 8
  %650 = getelementptr inbounds nuw %ASTNode, ptr %649, i32 0, i32 1
  %651 = load ptr, ptr %650, align 8
  %652 = call ptr @type_struct__String(ptr %651)
  store ptr %652, ptr %struct_t.996, align 8
  %653 = load ptr, ptr %expr.955, align 8
  %654 = load ptr, ptr %struct_t.996, align 8
  call void @node_set_type__Struct_ASTNode_Struct_TypeInfo(ptr %653, ptr %654)
  %655 = load ptr, ptr %struct_t.996, align 8
  ret ptr %655

label_2644:                                       ; preds = %label_2643
  %656 = load ptr, ptr %field_ptr.993, align 8
  %657 = call ptr @ptr_to_node(ptr %656)
  store ptr %657, ptr %field.994, align 8
  %658 = load ptr, ptr %module.954, align 8
  %659 = load ptr, ptr %expr.955, align 8
  %660 = getelementptr inbounds nuw %ASTNode, ptr %659, i32 0, i32 1
  %661 = load ptr, ptr %660, align 8
  %662 = load ptr, ptr %field.994, align 8
  %663 = getelementptr inbounds nuw %ASTNode, ptr %662, i32 0, i32 1
  %664 = load ptr, ptr %663, align 8
  %665 = call ptr @sema_find_struct_field_type__Struct_ASTNode_String_String(ptr %658, ptr %661, ptr %664)
  store ptr %665, ptr %expected.995, align 8
  %666 = load ptr, ptr %module.954, align 8
  %667 = load ptr, ptr %field.994, align 8
  %668 = getelementptr inbounds nuw %ASTNode, ptr %667, i32 0, i32 5
  %669 = load ptr, ptr %668, align 8
  %670 = call ptr @ptr_to_node(ptr %669)
  %671 = load ptr, ptr %expected.995, align 8
  %672 = load ptr, ptr %field.994, align 8
  %673 = getelementptr inbounds nuw %ASTNode, ptr %672, i32 0, i32 1
  %674 = load ptr, ptr %673, align 8
  %675 = call ptr @str_concat(ptr @.str.s964, ptr %674)
  %676 = call ptr @sema_check_value__Struct_ASTNode_Struct_ASTNode_Struct_TypeInfo_String(ptr %666, ptr %670, ptr %671, ptr %675)
  %677 = load ptr, ptr %field.994, align 8
  %678 = getelementptr inbounds nuw %ASTNode, ptr %677, i32 0, i32 5
  %679 = load ptr, ptr %678, align 8
  %680 = call ptr @ptr_to_node(ptr %679)
  call void @sema_move_operand__Struct_ASTNode(ptr %680)
  %681 = load ptr, ptr %field.994, align 8
  %682 = getelementptr inbounds nuw %ASTNode, ptr %681, i32 0, i32 8
  %683 = load ptr, ptr %682, align 8
  store ptr %683, ptr %field_ptr.993, align 8
  br label %label_2643
}

define ptr @sema_find_function__Struct_ASTNode_String(ptr %0, ptr %1) {
entry:
  %module.892 = alloca ptr, align 8
  store ptr %0, ptr %module.892, align 8
  %name.893 = alloca ptr, align 8
  store ptr %1, ptr %name.893, align 8
  %2 = load ptr, ptr %module.892, align 8
  %3 = getelementptr inbounds nuw %ASTNode, ptr %2, i32 0, i32 5
  %4 = load ptr, ptr %3, align 8
  %stmt_ptr.894 = alloca ptr, align 8
  store ptr %4, ptr %stmt_ptr.894, align 8
  %stmt.895 = alloca ptr, align 8
  %sc.99 = alloca i1, align 1
  %sc.100 = alloca i1, align 1
  br label %label_2196

label_2196:                                       ; preds = %label_2205, %entry
  %5 = load ptr, ptr %stmt_ptr.894, align 8
  %6 = call i32 @str_equals(ptr %5, ptr @.str.s831)
  %7 = icmp eq i32 %6, 0
  br i1 %7, label %label_2197, label %label_2198

label_2198:                                       ; preds = %label_2196
  %8 = call ptr @create_node__Enum_NodeKind(i32 0)
  ret ptr %8

label_2197:                                       ; preds = %label_2196
  %9 = load ptr, ptr %stmt_ptr.894, align 8
  %10 = call ptr @ptr_to_node(ptr %9)
  store ptr %10, ptr %stmt.895, align 8
  %11 = load ptr, ptr %stmt.895, align 8
  %12 = getelementptr inbounds nuw %ASTNode, ptr %11, i32 0, i32 0
  %13 = load i32, ptr %12, align 4
  %14 = icmp eq i32 %13, 4
  store i1 %14, ptr %sc.100, align 1
  br i1 %14, label %label_2202, label %label_2201

label_2201:                                       ; preds = %label_2197
  %15 = load ptr, ptr %stmt.895, align 8
  %16 = getelementptr inbounds nuw %ASTNode, ptr %15, i32 0, i32 0
  %17 = load i32, ptr %16, align 4
  %18 = icmp eq i32 %17, 2
  store i1 %18, ptr %sc.100, align 1
  br label %label_2202

label_2202:                                       ; preds = %label_2201, %label_2197
  %19 = load i1, ptr %sc.100, align 1
  store i1 %19, ptr %sc.99, align 1
  br i1 %19, label %label_2199, label %label_2200

label_2200:                                       ; preds = %label_2199, %label_2202
  %20 = load i1, ptr %sc.99, align 1
  br i1 %20, label %label_2203, label %label_2205

label_2199:                                       ; preds = %label_2202
  %21 = load ptr, ptr %stmt.895, align 8
  %22 = getelementptr inbounds nuw %ASTNode, ptr %21, i32 0, i32 1
  %23 = load ptr, ptr %22, align 8
  %24 = load ptr, ptr %name.893, align 8
  %25 = call i32 @str_equals(ptr %23, ptr %24)
  %26 = icmp eq i32 %25, 1
  store i1 %26, ptr %sc.99, align 1
  br label %label_2200

label_2205:                                       ; preds = %label_2200
  %27 = load ptr, ptr %stmt.895, align 8
  %28 = getelementptr inbounds nuw %ASTNode, ptr %27, i32 0, i32 8
  %29 = load ptr, ptr %28, align 8
  store ptr %29, ptr %stmt_ptr.894, align 8
  br label %label_2196

label_2203:                                       ; preds = %label_2200
  %30 = load ptr, ptr %stmt.895, align 8
  ret ptr %30
}

define i1 @sema_arg_matches_type__Struct_ASTNode_Struct_ASTNode_Struct_TypeInfo(ptr %0, ptr %1, ptr %2) {
entry:
  %module.896 = alloca ptr, align 8
  store ptr %0, ptr %module.896, align 8
  %arg_node.897 = alloca ptr, align 8
  store ptr %1, ptr %arg_node.897, align 8
  %expected.898 = alloca ptr, align 8
  store ptr %2, ptr %expected.898, align 8
  %sc.101 = alloca i1, align 1
  %sc.102 = alloca i1, align 1
  %3 = load ptr, ptr %expected.898, align 8
  %4 = call i1 @type_is_valid__Struct_TypeInfo(ptr %3)
  store i1 %4, ptr %sc.102, align 1
  %actual.899 = alloca ptr, align 8
  br i1 %4, label %label_2208, label %label_2209

label_2209:                                       ; preds = %label_2208, %entry
  %5 = load i1, ptr %sc.102, align 1
  store i1 %5, ptr %sc.101, align 1
  br i1 %5, label %label_2206, label %label_2207

label_2208:                                       ; preds = %entry
  %6 = load ptr, ptr %expected.898, align 8
  %7 = getelementptr inbounds nuw %TypeInfo, ptr %6, i32 0, i32 0
  %8 = load i32, ptr %7, align 4
  %9 = icmp eq i32 %8, 2
  store i1 %9, ptr %sc.102, align 1
  br label %label_2209

label_2207:                                       ; preds = %label_2206, %label_2209
  %10 = load i1, ptr %sc.101, align 1
  br i1 %10, label %label_2210, label %label_2212

label_2206:                                       ; preds = %label_2209
  %11 = load ptr, ptr %arg_node.897, align 8
  %12 = call i1 @sema_is_int_literal__Struct_ASTNode(ptr %11)
  store i1 %12, ptr %sc.101, align 1
  br label %label_2207

label_2212:                                       ; preds = %label_2207
  %13 = load ptr, ptr %module.896, align 8
  %14 = load ptr, ptr %arg_node.897, align 8
  %15 = call ptr @sema_expr__Struct_ASTNode_Struct_ASTNode(ptr %13, ptr %14)
  store ptr %15, ptr %actual.899, align 8
  %16 = load ptr, ptr %expected.898, align 8
  %17 = load ptr, ptr %actual.899, align 8
  %18 = call i1 @sema_types_match__Struct_TypeInfo_Struct_TypeInfo(ptr %16, ptr %17)
  ret i1 %18

label_2210:                                       ; preds = %label_2207
  ret i1 true
}

define i1 @sema_signature_matches_call__Struct_ASTNode_Struct_ASTNode_String(ptr %0, ptr %1, ptr %2) {
entry:
  %module.900 = alloca ptr, align 8
  store ptr %0, ptr %module.900, align 8
  %fn_node.901 = alloca ptr, align 8
  store ptr %1, ptr %fn_node.901, align 8
  %arg_ptr.902 = alloca ptr, align 8
  store ptr %2, ptr %arg_ptr.902, align 8
  %3 = load ptr, ptr %arg_ptr.902, align 8
  %arg.903 = alloca ptr, align 8
  store ptr %3, ptr %arg.903, align 8
  %4 = load ptr, ptr %fn_node.901, align 8
  %5 = getelementptr inbounds nuw %ASTNode, ptr %4, i32 0, i32 5
  %6 = load ptr, ptr %5, align 8
  %param.904 = alloca ptr, align 8
  store ptr %6, ptr %param.904, align 8
  %sc.103 = alloca i1, align 1
  %arg_node.905 = alloca ptr, align 8
  %param_node.906 = alloca ptr, align 8
  %param_t.907 = alloca ptr, align 8
  %sc.104 = alloca i1, align 1
  br label %label_2213

label_2213:                                       ; preds = %label_2220, %entry
  %7 = load ptr, ptr %arg.903, align 8
  %8 = call i32 @str_equals(ptr %7, ptr @.str.s832)
  %9 = icmp eq i32 %8, 0
  store i1 %9, ptr %sc.103, align 1
  br i1 %9, label %label_2216, label %label_2217

label_2217:                                       ; preds = %label_2216, %label_2213
  %10 = load i1, ptr %sc.103, align 1
  br i1 %10, label %label_2214, label %label_2215

label_2216:                                       ; preds = %label_2213
  %11 = load ptr, ptr %param.904, align 8
  %12 = call i32 @str_equals(ptr %11, ptr @.str.s833)
  %13 = icmp eq i32 %12, 0
  store i1 %13, ptr %sc.103, align 1
  br label %label_2217

label_2215:                                       ; preds = %label_2217
  %14 = load ptr, ptr %arg.903, align 8
  %15 = call i32 @str_equals(ptr %14, ptr @.str.s834)
  %16 = icmp eq i32 %15, 1
  store i1 %16, ptr %sc.104, align 1
  br i1 %16, label %label_2221, label %label_2222

label_2214:                                       ; preds = %label_2217
  %17 = load ptr, ptr %arg.903, align 8
  %18 = call ptr @ptr_to_node(ptr %17)
  store ptr %18, ptr %arg_node.905, align 8
  %19 = load ptr, ptr %param.904, align 8
  %20 = call ptr @ptr_to_node(ptr %19)
  store ptr %20, ptr %param_node.906, align 8
  %21 = load ptr, ptr %module.900, align 8
  %22 = load ptr, ptr %param_node.906, align 8
  %23 = getelementptr inbounds nuw %ASTNode, ptr %22, i32 0, i32 5
  %24 = load ptr, ptr %23, align 8
  %25 = call ptr @ptr_to_node(ptr %24)
  %26 = call ptr @sema_annotation_type__Struct_ASTNode_Struct_ASTNode(ptr %21, ptr %25)
  store ptr %26, ptr %param_t.907, align 8
  %27 = load ptr, ptr %module.900, align 8
  %28 = load ptr, ptr %arg_node.905, align 8
  %29 = load ptr, ptr %param_t.907, align 8
  %30 = call i1 @sema_arg_matches_type__Struct_ASTNode_Struct_ASTNode_Struct_TypeInfo(ptr %27, ptr %28, ptr %29)
  %31 = icmp eq i1 %30, false
  br i1 %31, label %label_2218, label %label_2220

label_2220:                                       ; preds = %label_2214
  %32 = load ptr, ptr %arg_node.905, align 8
  %33 = getelementptr inbounds nuw %ASTNode, ptr %32, i32 0, i32 8
  %34 = load ptr, ptr %33, align 8
  store ptr %34, ptr %arg.903, align 8
  %35 = load ptr, ptr %param_node.906, align 8
  %36 = getelementptr inbounds nuw %ASTNode, ptr %35, i32 0, i32 8
  %37 = load ptr, ptr %36, align 8
  store ptr %37, ptr %param.904, align 8
  br label %label_2213

label_2218:                                       ; preds = %label_2214
  ret i1 false

label_2222:                                       ; preds = %label_2221, %label_2215
  %38 = load i1, ptr %sc.104, align 1
  ret i1 %38

label_2221:                                       ; preds = %label_2215
  %39 = load ptr, ptr %param.904, align 8
  %40 = call i32 @str_equals(ptr %39, ptr @.str.s835)
  %41 = icmp eq i32 %40, 1
  store i1 %41, ptr %sc.104, align 1
  br label %label_2222
}

define i1 @sema_has_function_definition__Struct_ASTNode_String(ptr %0, ptr %1) {
entry:
  %module.908 = alloca ptr, align 8
  store ptr %0, ptr %module.908, align 8
  %name.909 = alloca ptr, align 8
  store ptr %1, ptr %name.909, align 8
  %2 = load ptr, ptr %module.908, align 8
  %3 = getelementptr inbounds nuw %ASTNode, ptr %2, i32 0, i32 5
  %4 = load ptr, ptr %3, align 8
  %scan_ptr.910 = alloca ptr, align 8
  store ptr %4, ptr %scan_ptr.910, align 8
  %scan.911 = alloca ptr, align 8
  %sc.105 = alloca i1, align 1
  br label %label_2223

label_2223:                                       ; preds = %label_2230, %entry
  %5 = load ptr, ptr %scan_ptr.910, align 8
  %6 = call i32 @str_equals(ptr %5, ptr @.str.s836)
  %7 = icmp eq i32 %6, 0
  br i1 %7, label %label_2224, label %label_2225

label_2225:                                       ; preds = %label_2223
  ret i1 false

label_2224:                                       ; preds = %label_2223
  %8 = load ptr, ptr %scan_ptr.910, align 8
  %9 = call ptr @ptr_to_node(ptr %8)
  store ptr %9, ptr %scan.911, align 8
  %10 = load ptr, ptr %scan.911, align 8
  %11 = getelementptr inbounds nuw %ASTNode, ptr %10, i32 0, i32 0
  %12 = load i32, ptr %11, align 4
  %13 = icmp eq i32 %12, 4
  store i1 %13, ptr %sc.105, align 1
  br i1 %13, label %label_2226, label %label_2227

label_2227:                                       ; preds = %label_2226, %label_2224
  %14 = load i1, ptr %sc.105, align 1
  br i1 %14, label %label_2228, label %label_2230

label_2226:                                       ; preds = %label_2224
  %15 = load ptr, ptr %scan.911, align 8
  %16 = getelementptr inbounds nuw %ASTNode, ptr %15, i32 0, i32 1
  %17 = load ptr, ptr %16, align 8
  %18 = load ptr, ptr %name.909, align 8
  %19 = call i32 @str_equals(ptr %17, ptr %18)
  %20 = icmp eq i32 %19, 1
  store i1 %20, ptr %sc.105, align 1
  br label %label_2227

label_2230:                                       ; preds = %label_2227
  %21 = load ptr, ptr %scan.911, align 8
  %22 = getelementptr inbounds nuw %ASTNode, ptr %21, i32 0, i32 8
  %23 = load ptr, ptr %22, align 8
  store ptr %23, ptr %scan_ptr.910, align 8
  br label %label_2223

label_2228:                                       ; preds = %label_2227
  ret i1 true
}

define ptr @sema_find_function_overload__Struct_ASTNode_String_String(ptr %0, ptr %1, ptr %2) {
entry:
  %module.912 = alloca ptr, align 8
  store ptr %0, ptr %module.912, align 8
  %name.913 = alloca ptr, align 8
  store ptr %1, ptr %name.913, align 8
  %arg_ptr.914 = alloca ptr, align 8
  store ptr %2, ptr %arg_ptr.914, align 8
  %best_ptr.915 = alloca ptr, align 8
  store ptr @.str.s837, ptr %best_ptr.915, align 8
  %match_count.916 = alloca i32, align 4
  store i32 0, ptr %match_count.916, align 4
  %name_seen.917 = alloca i1, align 1
  store i1 false, ptr %name_seen.917, align 1
  %3 = load ptr, ptr %module.912, align 8
  %4 = load ptr, ptr %name.913, align 8
  %5 = call i1 @sema_has_function_definition__Struct_ASTNode_String(ptr %3, ptr %4)
  %definition_exists.918 = alloca i1, align 1
  store i1 %5, ptr %definition_exists.918, align 1
  %6 = load ptr, ptr %module.912, align 8
  %7 = getelementptr inbounds nuw %ASTNode, ptr %6, i32 0, i32 5
  %8 = load ptr, ptr %7, align 8
  %stmt_ptr.919 = alloca ptr, align 8
  store ptr %8, ptr %stmt_ptr.919, align 8
  %stmt.920 = alloca ptr, align 8
  %is_candidate.921 = alloca i1, align 1
  %sc.106 = alloca i1, align 1
  %sc.107 = alloca i1, align 1
  br label %label_2231

label_2231:                                       ; preds = %label_2243, %entry
  %9 = load ptr, ptr %stmt_ptr.919, align 8
  %10 = call i32 @str_equals(ptr %9, ptr @.str.s838)
  %11 = icmp eq i32 %10, 0
  br i1 %11, label %label_2232, label %label_2233

label_2233:                                       ; preds = %label_2231
  %12 = load i32, ptr %match_count.916, align 4
  %13 = icmp sgt i32 %12, 1
  br i1 %13, label %label_2247, label %label_2249

label_2232:                                       ; preds = %label_2231
  %14 = load ptr, ptr %stmt_ptr.919, align 8
  %15 = call ptr @ptr_to_node(ptr %14)
  store ptr %15, ptr %stmt.920, align 8
  %16 = load ptr, ptr %stmt.920, align 8
  %17 = getelementptr inbounds nuw %ASTNode, ptr %16, i32 0, i32 0
  %18 = load i32, ptr %17, align 4
  %19 = icmp eq i32 %18, 4
  store i1 %19, ptr %is_candidate.921, align 1
  %20 = load ptr, ptr %stmt.920, align 8
  %21 = getelementptr inbounds nuw %ASTNode, ptr %20, i32 0, i32 0
  %22 = load i32, ptr %21, align 4
  %23 = icmp eq i32 %22, 2
  store i1 %23, ptr %sc.106, align 1
  br i1 %23, label %label_2234, label %label_2235

label_2235:                                       ; preds = %label_2234, %label_2232
  %24 = load i1, ptr %sc.106, align 1
  br i1 %24, label %label_2236, label %label_2238

label_2234:                                       ; preds = %label_2232
  %25 = load i1, ptr %definition_exists.918, align 1
  %26 = icmp eq i1 %25, false
  store i1 %26, ptr %sc.106, align 1
  br label %label_2235

label_2238:                                       ; preds = %label_2236, %label_2235
  %27 = load i1, ptr %is_candidate.921, align 1
  store i1 %27, ptr %sc.107, align 1
  br i1 %27, label %label_2239, label %label_2240

label_2236:                                       ; preds = %label_2235
  store i1 true, ptr %is_candidate.921, align 1
  br label %label_2238

label_2240:                                       ; preds = %label_2239, %label_2238
  %28 = load i1, ptr %sc.107, align 1
  br i1 %28, label %label_2241, label %label_2243

label_2239:                                       ; preds = %label_2238
  %29 = load ptr, ptr %stmt.920, align 8
  %30 = getelementptr inbounds nuw %ASTNode, ptr %29, i32 0, i32 1
  %31 = load ptr, ptr %30, align 8
  %32 = load ptr, ptr %name.913, align 8
  %33 = call i32 @str_equals(ptr %31, ptr %32)
  %34 = icmp eq i32 %33, 1
  store i1 %34, ptr %sc.107, align 1
  br label %label_2240

label_2243:                                       ; preds = %label_2246, %label_2240
  %35 = load ptr, ptr %stmt.920, align 8
  %36 = getelementptr inbounds nuw %ASTNode, ptr %35, i32 0, i32 8
  %37 = load ptr, ptr %36, align 8
  store ptr %37, ptr %stmt_ptr.919, align 8
  br label %label_2231

label_2241:                                       ; preds = %label_2240
  store i1 true, ptr %name_seen.917, align 1
  %38 = load ptr, ptr %module.912, align 8
  %39 = load ptr, ptr %stmt.920, align 8
  %40 = load ptr, ptr %arg_ptr.914, align 8
  %41 = call i1 @sema_signature_matches_call__Struct_ASTNode_Struct_ASTNode_String(ptr %38, ptr %39, ptr %40)
  br i1 %41, label %label_2244, label %label_2246

label_2246:                                       ; preds = %label_2244, %label_2241
  br label %label_2243

label_2244:                                       ; preds = %label_2241
  %42 = load ptr, ptr %stmt_ptr.919, align 8
  store ptr %42, ptr %best_ptr.915, align 8
  %43 = load i32, ptr %match_count.916, align 4
  %44 = add i32 %43, 1
  store i32 %44, ptr %match_count.916, align 4
  br label %label_2246

label_2249:                                       ; preds = %label_2247, %label_2233
  %45 = load i32, ptr %match_count.916, align 4
  %46 = icmp eq i32 %45, 1
  br i1 %46, label %label_2250, label %label_2252

label_2247:                                       ; preds = %label_2233
  %47 = load ptr, ptr %name.913, align 8
  %48 = call ptr @str_concat(ptr @.str.s839, ptr %47)
  call void @sema_error__String(ptr %48)
  br label %label_2249

label_2252:                                       ; preds = %label_2249
  %49 = load i1, ptr %name_seen.917, align 1
  br i1 %49, label %label_2253, label %label_2255

label_2250:                                       ; preds = %label_2249
  %50 = load ptr, ptr %best_ptr.915, align 8
  %51 = call ptr @ptr_to_node(ptr %50)
  ret ptr %51

label_2255:                                       ; preds = %label_2253, %label_2252
  %52 = load ptr, ptr %name.913, align 8
  %53 = call ptr @str_concat(ptr @.str.s841, ptr %52)
  call void @sema_error__String(ptr %53)
  %54 = call ptr @create_node__Enum_NodeKind(i32 0)
  ret ptr %54

label_2253:                                       ; preds = %label_2252
  %55 = load ptr, ptr %name.913, align 8
  %56 = call ptr @str_concat(ptr @.str.s840, ptr %55)
  call void @sema_error__String(ptr %56)
  br label %label_2255
}

define ptr @sema_find_struct_field_type__Struct_ASTNode_String_String(ptr %0, ptr %1, ptr %2) {
entry:
  %module.922 = alloca ptr, align 8
  store ptr %0, ptr %module.922, align 8
  %struct_name.923 = alloca ptr, align 8
  store ptr %1, ptr %struct_name.923, align 8
  %field_name.924 = alloca ptr, align 8
  store ptr %2, ptr %field_name.924, align 8
  %3 = load ptr, ptr %module.922, align 8
  %4 = getelementptr inbounds nuw %ASTNode, ptr %3, i32 0, i32 5
  %5 = load ptr, ptr %4, align 8
  %stmt_ptr.925 = alloca ptr, align 8
  store ptr %5, ptr %stmt_ptr.925, align 8
  %stmt.926 = alloca ptr, align 8
  %sc.108 = alloca i1, align 1
  %field_ptr.927 = alloca ptr, align 8
  %field.928 = alloca ptr, align 8
  br label %label_2256

label_2256:                                       ; preds = %label_2263, %entry
  %6 = load ptr, ptr %stmt_ptr.925, align 8
  %7 = call i32 @str_equals(ptr %6, ptr @.str.s842)
  %8 = icmp eq i32 %7, 0
  br i1 %8, label %label_2257, label %label_2258

label_2258:                                       ; preds = %label_2256
  %9 = load ptr, ptr %field_name.924, align 8
  %10 = call ptr @str_concat(ptr @.str.s844, ptr %9)
  %11 = load ptr, ptr %struct_name.923, align 8
  %12 = call ptr @str_concat(ptr @.str.s845, ptr %11)
  %13 = call ptr @str_concat(ptr %10, ptr %12)
  call void @sema_error__String(ptr %13)
  %14 = call ptr @type_invalid__Void()
  ret ptr %14

label_2257:                                       ; preds = %label_2256
  %15 = load ptr, ptr %stmt_ptr.925, align 8
  %16 = call ptr @ptr_to_node(ptr %15)
  store ptr %16, ptr %stmt.926, align 8
  %17 = load ptr, ptr %stmt.926, align 8
  %18 = getelementptr inbounds nuw %ASTNode, ptr %17, i32 0, i32 0
  %19 = load i32, ptr %18, align 4
  %20 = icmp eq i32 %19, 5
  store i1 %20, ptr %sc.108, align 1
  br i1 %20, label %label_2259, label %label_2260

label_2260:                                       ; preds = %label_2259, %label_2257
  %21 = load i1, ptr %sc.108, align 1
  br i1 %21, label %label_2261, label %label_2263

label_2259:                                       ; preds = %label_2257
  %22 = load ptr, ptr %stmt.926, align 8
  %23 = getelementptr inbounds nuw %ASTNode, ptr %22, i32 0, i32 1
  %24 = load ptr, ptr %23, align 8
  %25 = load ptr, ptr %struct_name.923, align 8
  %26 = call i32 @str_equals(ptr %24, ptr %25)
  %27 = icmp eq i32 %26, 1
  store i1 %27, ptr %sc.108, align 1
  br label %label_2260

label_2263:                                       ; preds = %label_2266, %label_2260
  %28 = load ptr, ptr %stmt.926, align 8
  %29 = getelementptr inbounds nuw %ASTNode, ptr %28, i32 0, i32 8
  %30 = load ptr, ptr %29, align 8
  store ptr %30, ptr %stmt_ptr.925, align 8
  br label %label_2256

label_2261:                                       ; preds = %label_2260
  %31 = load ptr, ptr %stmt.926, align 8
  %32 = getelementptr inbounds nuw %ASTNode, ptr %31, i32 0, i32 5
  %33 = load ptr, ptr %32, align 8
  store ptr %33, ptr %field_ptr.927, align 8
  br label %label_2264

label_2264:                                       ; preds = %label_2269, %label_2261
  %34 = load ptr, ptr %field_ptr.927, align 8
  %35 = call i32 @str_equals(ptr %34, ptr @.str.s843)
  %36 = icmp eq i32 %35, 0
  br i1 %36, label %label_2265, label %label_2266

label_2266:                                       ; preds = %label_2264
  br label %label_2263

label_2265:                                       ; preds = %label_2264
  %37 = load ptr, ptr %field_ptr.927, align 8
  %38 = call ptr @ptr_to_node(ptr %37)
  store ptr %38, ptr %field.928, align 8
  %39 = load ptr, ptr %field.928, align 8
  %40 = getelementptr inbounds nuw %ASTNode, ptr %39, i32 0, i32 1
  %41 = load ptr, ptr %40, align 8
  %42 = load ptr, ptr %field_name.924, align 8
  %43 = call i32 @str_equals(ptr %41, ptr %42)
  %44 = icmp eq i32 %43, 1
  br i1 %44, label %label_2267, label %label_2269

label_2269:                                       ; preds = %label_2265
  %45 = load ptr, ptr %field.928, align 8
  %46 = getelementptr inbounds nuw %ASTNode, ptr %45, i32 0, i32 8
  %47 = load ptr, ptr %46, align 8
  store ptr %47, ptr %field_ptr.927, align 8
  br label %label_2264

label_2267:                                       ; preds = %label_2265
  %48 = load ptr, ptr %module.922, align 8
  %49 = load ptr, ptr %field.928, align 8
  %50 = getelementptr inbounds nuw %ASTNode, ptr %49, i32 0, i32 5
  %51 = load ptr, ptr %50, align 8
  %52 = call ptr @ptr_to_node(ptr %51)
  %53 = call ptr @sema_annotation_type__Struct_ASTNode_Struct_ASTNode(ptr %48, ptr %52)
  ret ptr %53
}

define i1 @sema_enum_has_variant__Struct_ASTNode_String_String(ptr %0, ptr %1, ptr %2) {
entry:
  %module.929 = alloca ptr, align 8
  store ptr %0, ptr %module.929, align 8
  %enum_name.930 = alloca ptr, align 8
  store ptr %1, ptr %enum_name.930, align 8
  %variant_name.931 = alloca ptr, align 8
  store ptr %2, ptr %variant_name.931, align 8
  %3 = load ptr, ptr %module.929, align 8
  %4 = getelementptr inbounds nuw %ASTNode, ptr %3, i32 0, i32 5
  %5 = load ptr, ptr %4, align 8
  %stmt_ptr.932 = alloca ptr, align 8
  store ptr %5, ptr %stmt_ptr.932, align 8
  %stmt.933 = alloca ptr, align 8
  %sc.109 = alloca i1, align 1
  %variant_ptr.934 = alloca ptr, align 8
  %variant.935 = alloca ptr, align 8
  br label %label_2270

label_2270:                                       ; preds = %label_2277, %entry
  %6 = load ptr, ptr %stmt_ptr.932, align 8
  %7 = call i32 @str_equals(ptr %6, ptr @.str.s846)
  %8 = icmp eq i32 %7, 0
  br i1 %8, label %label_2271, label %label_2272

label_2272:                                       ; preds = %label_2270
  ret i1 false

label_2271:                                       ; preds = %label_2270
  %9 = load ptr, ptr %stmt_ptr.932, align 8
  %10 = call ptr @ptr_to_node(ptr %9)
  store ptr %10, ptr %stmt.933, align 8
  %11 = load ptr, ptr %stmt.933, align 8
  %12 = getelementptr inbounds nuw %ASTNode, ptr %11, i32 0, i32 0
  %13 = load i32, ptr %12, align 4
  %14 = icmp eq i32 %13, 6
  store i1 %14, ptr %sc.109, align 1
  br i1 %14, label %label_2273, label %label_2274

label_2274:                                       ; preds = %label_2273, %label_2271
  %15 = load i1, ptr %sc.109, align 1
  br i1 %15, label %label_2275, label %label_2277

label_2273:                                       ; preds = %label_2271
  %16 = load ptr, ptr %stmt.933, align 8
  %17 = getelementptr inbounds nuw %ASTNode, ptr %16, i32 0, i32 1
  %18 = load ptr, ptr %17, align 8
  %19 = load ptr, ptr %enum_name.930, align 8
  %20 = call i32 @str_equals(ptr %18, ptr %19)
  %21 = icmp eq i32 %20, 1
  store i1 %21, ptr %sc.109, align 1
  br label %label_2274

label_2277:                                       ; preds = %label_2280, %label_2274
  %22 = load ptr, ptr %stmt.933, align 8
  %23 = getelementptr inbounds nuw %ASTNode, ptr %22, i32 0, i32 8
  %24 = load ptr, ptr %23, align 8
  store ptr %24, ptr %stmt_ptr.932, align 8
  br label %label_2270

label_2275:                                       ; preds = %label_2274
  %25 = load ptr, ptr %stmt.933, align 8
  %26 = getelementptr inbounds nuw %ASTNode, ptr %25, i32 0, i32 5
  %27 = load ptr, ptr %26, align 8
  store ptr %27, ptr %variant_ptr.934, align 8
  br label %label_2278

label_2278:                                       ; preds = %label_2283, %label_2275
  %28 = load ptr, ptr %variant_ptr.934, align 8
  %29 = call i32 @str_equals(ptr %28, ptr @.str.s847)
  %30 = icmp eq i32 %29, 0
  br i1 %30, label %label_2279, label %label_2280

label_2280:                                       ; preds = %label_2278
  br label %label_2277

label_2279:                                       ; preds = %label_2278
  %31 = load ptr, ptr %variant_ptr.934, align 8
  %32 = call ptr @ptr_to_node(ptr %31)
  store ptr %32, ptr %variant.935, align 8
  %33 = load ptr, ptr %variant.935, align 8
  %34 = getelementptr inbounds nuw %ASTNode, ptr %33, i32 0, i32 1
  %35 = load ptr, ptr %34, align 8
  %36 = load ptr, ptr %variant_name.931, align 8
  %37 = call i32 @str_equals(ptr %35, ptr %36)
  %38 = icmp eq i32 %37, 1
  br i1 %38, label %label_2281, label %label_2283

label_2283:                                       ; preds = %label_2279
  %39 = load ptr, ptr %variant.935, align 8
  %40 = getelementptr inbounds nuw %ASTNode, ptr %39, i32 0, i32 8
  %41 = load ptr, ptr %40, align 8
  store ptr %41, ptr %variant_ptr.934, align 8
  br label %label_2278

label_2281:                                       ; preds = %label_2279
  ret i1 true
}

define ptr @sema_builtin_call_type__String_String(ptr %0, ptr %1) {
entry:
  %name.936 = alloca ptr, align 8
  store ptr %0, ptr %name.936, align 8
  %arg_ptr.937 = alloca ptr, align 8
  store ptr %1, ptr %arg_ptr.937, align 8
  %sc.110 = alloca i1, align 1
  %2 = load ptr, ptr %name.936, align 8
  %3 = call i32 @str_equals(ptr %2, ptr @.str.s848)
  %4 = icmp eq i32 %3, 1
  store i1 %4, ptr %sc.110, align 1
  %sc.111 = alloca i1, align 1
  %sc.112 = alloca i1, align 1
  %sc.113 = alloca i1, align 1
  %sc.114 = alloca i1, align 1
  %lt.938 = alloca ptr, align 8
  %sc.115 = alloca i1, align 1
  br i1 %4, label %label_2285, label %label_2284

label_2284:                                       ; preds = %entry
  %5 = load ptr, ptr %name.936, align 8
  %6 = call i32 @str_equals(ptr %5, ptr @.str.s849)
  %7 = icmp eq i32 %6, 1
  store i1 %7, ptr %sc.110, align 1
  br label %label_2285

label_2285:                                       ; preds = %label_2284, %entry
  %8 = load i1, ptr %sc.110, align 1
  br i1 %8, label %label_2286, label %label_2288

label_2288:                                       ; preds = %label_2285
  %9 = load ptr, ptr %name.936, align 8
  %10 = call i32 @str_equals(ptr %9, ptr @.str.s852)
  %11 = icmp eq i32 %10, 1
  store i1 %11, ptr %sc.111, align 1
  br i1 %11, label %label_2293, label %label_2292

label_2286:                                       ; preds = %label_2285
  %12 = load ptr, ptr %arg_ptr.937, align 8
  %13 = call i32 @str_equals(ptr %12, ptr @.str.s850)
  %14 = icmp eq i32 %13, 1
  br i1 %14, label %label_2289, label %label_2291

label_2291:                                       ; preds = %label_2289, %label_2286
  %15 = call ptr @type_void__Void()
  ret ptr %15

label_2289:                                       ; preds = %label_2286
  %16 = load ptr, ptr %name.936, align 8
  %17 = call ptr @str_concat(ptr %16, ptr @.str.s851)
  call void @sema_error__String(ptr %17)
  br label %label_2291

label_2292:                                       ; preds = %label_2288
  %18 = load ptr, ptr %name.936, align 8
  %19 = call i32 @str_equals(ptr %18, ptr @.str.s853)
  %20 = icmp eq i32 %19, 1
  store i1 %20, ptr %sc.111, align 1
  br label %label_2293

label_2293:                                       ; preds = %label_2292, %label_2288
  %21 = load i1, ptr %sc.111, align 1
  br i1 %21, label %label_2294, label %label_2296

label_2296:                                       ; preds = %label_2293
  %22 = load ptr, ptr %name.936, align 8
  %23 = call i32 @str_equals(ptr %22, ptr @.str.s854)
  %24 = icmp eq i32 %23, 1
  store i1 %24, ptr %sc.112, align 1
  br i1 %24, label %label_2298, label %label_2297

label_2294:                                       ; preds = %label_2293
  %25 = call ptr @type_void__Void()
  ret ptr %25

label_2297:                                       ; preds = %label_2296
  %26 = load ptr, ptr %name.936, align 8
  %27 = call i32 @str_equals(ptr %26, ptr @.str.s855)
  %28 = icmp eq i32 %27, 1
  store i1 %28, ptr %sc.112, align 1
  br label %label_2298

label_2298:                                       ; preds = %label_2297, %label_2296
  %29 = load i1, ptr %sc.112, align 1
  br i1 %29, label %label_2299, label %label_2301

label_2301:                                       ; preds = %label_2298
  %30 = load ptr, ptr %name.936, align 8
  %31 = call i32 @str_equals(ptr %30, ptr @.str.s856)
  %32 = icmp eq i32 %31, 1
  store i1 %32, ptr %sc.113, align 1
  br i1 %32, label %label_2303, label %label_2302

label_2299:                                       ; preds = %label_2298
  %33 = call ptr @type_void__Void()
  ret ptr %33

label_2302:                                       ; preds = %label_2301
  %34 = load ptr, ptr %name.936, align 8
  %35 = call i32 @str_equals(ptr %34, ptr @.str.s857)
  %36 = icmp eq i32 %35, 1
  store i1 %36, ptr %sc.113, align 1
  br label %label_2303

label_2303:                                       ; preds = %label_2302, %label_2301
  %37 = load i1, ptr %sc.113, align 1
  br i1 %37, label %label_2304, label %label_2306

label_2306:                                       ; preds = %label_2303
  %38 = load ptr, ptr %name.936, align 8
  %39 = call i32 @str_equals(ptr %38, ptr @.str.s858)
  %40 = icmp eq i32 %39, 1
  store i1 %40, ptr %sc.114, align 1
  br i1 %40, label %label_2308, label %label_2307

label_2304:                                       ; preds = %label_2303
  %41 = call ptr @type_void__Void()
  ret ptr %41

label_2307:                                       ; preds = %label_2306
  %42 = load ptr, ptr %name.936, align 8
  %43 = call i32 @str_equals(ptr %42, ptr @.str.s859)
  %44 = icmp eq i32 %43, 1
  store i1 %44, ptr %sc.114, align 1
  br label %label_2308

label_2308:                                       ; preds = %label_2307, %label_2306
  %45 = load i1, ptr %sc.114, align 1
  br i1 %45, label %label_2309, label %label_2311

label_2311:                                       ; preds = %label_2308
  %46 = load ptr, ptr %name.936, align 8
  %47 = call i32 @str_equals(ptr %46, ptr @.str.s860)
  %48 = icmp eq i32 %47, 1
  br i1 %48, label %label_2312, label %label_2314

label_2309:                                       ; preds = %label_2308
  %49 = call ptr @type_void__Void()
  ret ptr %49

label_2314:                                       ; preds = %label_2311
  %50 = load ptr, ptr %name.936, align 8
  %51 = call i32 @str_equals(ptr %50, ptr @.str.s861)
  %52 = icmp eq i32 %51, 1
  br i1 %52, label %label_2315, label %label_2317

label_2312:                                       ; preds = %label_2311
  %53 = call ptr @type_void__Void()
  ret ptr %53

label_2317:                                       ; preds = %label_2314
  %54 = load ptr, ptr %name.936, align 8
  %55 = call i32 @str_equals(ptr %54, ptr @.str.s862)
  %56 = icmp eq i32 %55, 1
  br i1 %56, label %label_2318, label %label_2320

label_2315:                                       ; preds = %label_2314
  %57 = call ptr @type_invalid__Void()
  %58 = call ptr @type_list__Struct_TypeInfo(ptr %57)
  ret ptr %58

label_2320:                                       ; preds = %label_2317
  %59 = load ptr, ptr %name.936, align 8
  %60 = call i32 @str_equals(ptr %59, ptr @.str.s863)
  %61 = icmp eq i32 %60, 1
  br i1 %61, label %label_2321, label %label_2323

label_2318:                                       ; preds = %label_2317
  %62 = call ptr @type_int__Void()
  ret ptr %62

label_2323:                                       ; preds = %label_2320
  %63 = load ptr, ptr %name.936, align 8
  %64 = call i32 @str_equals(ptr %63, ptr @.str.s864)
  %65 = icmp eq i32 %64, 1
  br i1 %65, label %label_2324, label %label_2326

label_2321:                                       ; preds = %label_2320
  %66 = call ptr @type_void__Void()
  ret ptr %66

label_2326:                                       ; preds = %label_2323
  %67 = load ptr, ptr %name.936, align 8
  %68 = call i32 @str_equals(ptr %67, ptr @.str.s865)
  %69 = icmp eq i32 %68, 1
  br i1 %69, label %label_2327, label %label_2329

label_2324:                                       ; preds = %label_2323
  %70 = call ptr @type_void__Void()
  ret ptr %70

label_2329:                                       ; preds = %label_2326
  %71 = call ptr @type_invalid__Void()
  ret ptr %71

label_2327:                                       ; preds = %label_2326
  %72 = load ptr, ptr %arg_ptr.937, align 8
  %73 = call i32 @str_equals(ptr %72, ptr @.str.s866)
  %74 = icmp eq i32 %73, 0
  br i1 %74, label %label_2330, label %label_2332

label_2332:                                       ; preds = %label_2337, %label_2327
  %75 = call ptr @type_invalid__Void()
  ret ptr %75

label_2330:                                       ; preds = %label_2327
  %76 = load ptr, ptr %arg_ptr.937, align 8
  %77 = call ptr @ptr_to_node(ptr %76)
  %78 = call ptr @node_get_type__Struct_ASTNode(ptr %77)
  store ptr %78, ptr %lt.938, align 8
  %79 = load ptr, ptr %lt.938, align 8
  %80 = getelementptr inbounds nuw %TypeInfo, ptr %79, i32 0, i32 0
  %81 = load i32, ptr %80, align 4
  %82 = icmp eq i32 %81, 11
  store i1 %82, ptr %sc.115, align 1
  br i1 %82, label %label_2333, label %label_2334

label_2334:                                       ; preds = %label_2333, %label_2330
  %83 = load i1, ptr %sc.115, align 1
  br i1 %83, label %label_2335, label %label_2337

label_2333:                                       ; preds = %label_2330
  %84 = load ptr, ptr %lt.938, align 8
  %85 = getelementptr inbounds nuw %TypeInfo, ptr %84, i32 0, i32 3
  %86 = load ptr, ptr %85, align 8
  %87 = call i32 @str_equals(ptr %86, ptr @.str.s867)
  %88 = icmp eq i32 %87, 0
  store i1 %88, ptr %sc.115, align 1
  br label %label_2334

label_2337:                                       ; preds = %label_2334
  br label %label_2332

label_2335:                                       ; preds = %label_2334
  %89 = load ptr, ptr %lt.938, align 8
  %90 = getelementptr inbounds nuw %TypeInfo, ptr %89, i32 0, i32 3
  %91 = load ptr, ptr %90, align 8
  %92 = call ptr @ptr_to_type(ptr %91)
  ret ptr %92
}

define i1 @sema_check_builtin_call__Struct_ASTNode_String_String(ptr %0, ptr %1, ptr %2) {
entry:
  %module.939 = alloca ptr, align 8
  store ptr %0, ptr %module.939, align 8
  %name.940 = alloca ptr, align 8
  store ptr %1, ptr %name.940, align 8
  %arg_ptr.941 = alloca ptr, align 8
  store ptr %2, ptr %arg_ptr.941, align 8
  %sc.116 = alloca i1, align 1
  %3 = load ptr, ptr %name.940, align 8
  %4 = call i32 @str_equals(ptr %3, ptr @.str.s868)
  %5 = icmp eq i32 %4, 1
  store i1 %5, ptr %sc.116, align 1
  %sc.117 = alloca i1, align 1
  %sc.118 = alloca i1, align 1
  %arg.942 = alloca ptr, align 8
  %t.943 = alloca ptr, align 8
  %lt.944 = alloca ptr, align 8
  %a0.945 = alloca ptr, align 8
  %lt.946 = alloca ptr, align 8
  %a0.947 = alloca ptr, align 8
  %lt.948 = alloca ptr, align 8
  %a0.949 = alloca ptr, align 8
  %lt.950 = alloca ptr, align 8
  %a1.951 = alloca ptr, align 8
  %expected.952 = alloca ptr, align 8
  %sc.119 = alloca i1, align 1
  %sc.120 = alloca i1, align 1
  %sc.121 = alloca i1, align 1
  %sc.122 = alloca i1, align 1
  %sc.123 = alloca i1, align 1
  %actual.953 = alloca ptr, align 8
  br i1 %5, label %label_2339, label %label_2338

label_2338:                                       ; preds = %entry
  %6 = load ptr, ptr %name.940, align 8
  %7 = call i32 @str_equals(ptr %6, ptr @.str.s869)
  %8 = icmp eq i32 %7, 1
  store i1 %8, ptr %sc.116, align 1
  br label %label_2339

label_2339:                                       ; preds = %label_2338, %entry
  %9 = load i1, ptr %sc.116, align 1
  br i1 %9, label %label_2340, label %label_2342

label_2342:                                       ; preds = %label_2339
  %10 = load ptr, ptr %name.940, align 8
  %11 = call i32 @str_equals(ptr %10, ptr @.str.s873)
  %12 = icmp eq i32 %11, 1
  br i1 %12, label %label_2348, label %label_2350

label_2340:                                       ; preds = %label_2339
  %13 = load ptr, ptr %arg_ptr.941, align 8
  %14 = call i32 @str_equals(ptr %13, ptr @.str.s870)
  %15 = icmp eq i32 %14, 1
  store i1 %15, ptr %sc.117, align 1
  br i1 %15, label %label_2344, label %label_2343

label_2343:                                       ; preds = %label_2340
  %16 = load ptr, ptr %arg_ptr.941, align 8
  %17 = call ptr @ptr_to_node(ptr %16)
  %18 = getelementptr inbounds nuw %ASTNode, ptr %17, i32 0, i32 8
  %19 = load ptr, ptr %18, align 8
  %20 = call i32 @str_equals(ptr %19, ptr @.str.s871)
  %21 = icmp eq i32 %20, 0
  store i1 %21, ptr %sc.117, align 1
  br label %label_2344

label_2344:                                       ; preds = %label_2343, %label_2340
  %22 = load i1, ptr %sc.117, align 1
  br i1 %22, label %label_2345, label %label_2347

label_2347:                                       ; preds = %label_2345, %label_2344
  %23 = load ptr, ptr %module.939, align 8
  %24 = load ptr, ptr %arg_ptr.941, align 8
  %25 = call ptr @ptr_to_node(ptr %24)
  %26 = call ptr @sema_expr__Struct_ASTNode_Struct_ASTNode(ptr %23, ptr %25)
  ret i1 true

label_2345:                                       ; preds = %label_2344
  %27 = load ptr, ptr %name.940, align 8
  %28 = call ptr @str_concat(ptr %27, ptr @.str.s872)
  call void @sema_error__String(ptr %28)
  br label %label_2347

label_2350:                                       ; preds = %label_2342
  %29 = load ptr, ptr %name.940, align 8
  %30 = call i32 @str_equals(ptr %29, ptr @.str.s878)
  %31 = icmp eq i32 %30, 1
  br i1 %31, label %label_2359, label %label_2361

label_2348:                                       ; preds = %label_2342
  %32 = load ptr, ptr %arg_ptr.941, align 8
  %33 = call i32 @str_equals(ptr %32, ptr @.str.s874)
  %34 = icmp eq i32 %33, 1
  store i1 %34, ptr %sc.118, align 1
  br i1 %34, label %label_2352, label %label_2351

label_2351:                                       ; preds = %label_2348
  %35 = load ptr, ptr %arg_ptr.941, align 8
  %36 = call ptr @ptr_to_node(ptr %35)
  %37 = getelementptr inbounds nuw %ASTNode, ptr %36, i32 0, i32 8
  %38 = load ptr, ptr %37, align 8
  %39 = call i32 @str_equals(ptr %38, ptr @.str.s875)
  %40 = icmp eq i32 %39, 0
  store i1 %40, ptr %sc.118, align 1
  br label %label_2352

label_2352:                                       ; preds = %label_2351, %label_2348
  %41 = load i1, ptr %sc.118, align 1
  br i1 %41, label %label_2353, label %label_2355

label_2355:                                       ; preds = %label_2353, %label_2352
  %42 = load ptr, ptr %arg_ptr.941, align 8
  %43 = call ptr @ptr_to_node(ptr %42)
  store ptr %43, ptr %arg.942, align 8
  %44 = load ptr, ptr %module.939, align 8
  %45 = load ptr, ptr %arg.942, align 8
  %46 = call ptr @sema_expr__Struct_ASTNode_Struct_ASTNode(ptr %44, ptr %45)
  store ptr %46, ptr %t.943, align 8
  %47 = load ptr, ptr %t.943, align 8
  %48 = call i1 @type_is_move_only__Struct_TypeInfo(ptr %47)
  %49 = icmp eq i1 %48, false
  br i1 %49, label %label_2356, label %label_2358

label_2353:                                       ; preds = %label_2352
  call void @sema_error__String(ptr @.str.s876)
  br label %label_2355

label_2358:                                       ; preds = %label_2356, %label_2355
  %50 = load ptr, ptr %arg.942, align 8
  call void @sema_move_operand__Struct_ASTNode(ptr %50)
  ret i1 true

label_2356:                                       ; preds = %label_2355
  call void @sema_error__String(ptr @.str.s877)
  br label %label_2358

label_2361:                                       ; preds = %label_2350
  %51 = load ptr, ptr %name.940, align 8
  %52 = call i32 @str_equals(ptr %51, ptr @.str.s881)
  %53 = icmp eq i32 %52, 1
  br i1 %53, label %label_2365, label %label_2367

label_2359:                                       ; preds = %label_2350
  %54 = load ptr, ptr %arg_ptr.941, align 8
  %55 = call i32 @str_equals(ptr %54, ptr @.str.s879)
  %56 = icmp eq i32 %55, 0
  br i1 %56, label %label_2362, label %label_2364

label_2364:                                       ; preds = %label_2362, %label_2359
  ret i1 true

label_2362:                                       ; preds = %label_2359
  call void @sema_error__String(ptr @.str.s880)
  br label %label_2364

label_2367:                                       ; preds = %label_2361
  %57 = load ptr, ptr %name.940, align 8
  %58 = call i32 @str_equals(ptr %57, ptr @.str.s885)
  %59 = icmp eq i32 %58, 1
  br i1 %59, label %label_2374, label %label_2376

label_2365:                                       ; preds = %label_2361
  %60 = load ptr, ptr %arg_ptr.941, align 8
  %61 = call i32 @str_equals(ptr %60, ptr @.str.s882)
  %62 = icmp eq i32 %61, 1
  br i1 %62, label %label_2368, label %label_2370

label_2370:                                       ; preds = %label_2368, %label_2365
  %63 = load ptr, ptr %module.939, align 8
  %64 = load ptr, ptr %arg_ptr.941, align 8
  %65 = call ptr @ptr_to_node(ptr %64)
  %66 = call ptr @sema_expr__Struct_ASTNode_Struct_ASTNode(ptr %63, ptr %65)
  store ptr %66, ptr %lt.944, align 8
  %67 = load ptr, ptr %lt.944, align 8
  %68 = getelementptr inbounds nuw %TypeInfo, ptr %67, i32 0, i32 0
  %69 = load i32, ptr %68, align 4
  %70 = icmp ne i32 %69, 11
  br i1 %70, label %label_2371, label %label_2373

label_2368:                                       ; preds = %label_2365
  call void @sema_error__String(ptr @.str.s883)
  br label %label_2370

label_2373:                                       ; preds = %label_2371, %label_2370
  ret i1 true

label_2371:                                       ; preds = %label_2370
  call void @sema_error__String(ptr @.str.s884)
  br label %label_2373

label_2376:                                       ; preds = %label_2367
  %71 = load ptr, ptr %name.940, align 8
  %72 = call i32 @str_equals(ptr %71, ptr @.str.s888)
  %73 = icmp eq i32 %72, 1
  br i1 %73, label %label_2380, label %label_2382

label_2374:                                       ; preds = %label_2367
  %74 = load ptr, ptr %arg_ptr.941, align 8
  %75 = call ptr @ptr_to_node(ptr %74)
  store ptr %75, ptr %a0.945, align 8
  %76 = load ptr, ptr %module.939, align 8
  %77 = load ptr, ptr %a0.945, align 8
  %78 = call ptr @sema_expr__Struct_ASTNode_Struct_ASTNode(ptr %76, ptr %77)
  store ptr %78, ptr %lt.946, align 8
  %79 = load ptr, ptr %lt.946, align 8
  %80 = getelementptr inbounds nuw %TypeInfo, ptr %79, i32 0, i32 0
  %81 = load i32, ptr %80, align 4
  %82 = icmp ne i32 %81, 11
  br i1 %82, label %label_2377, label %label_2379

label_2379:                                       ; preds = %label_2377, %label_2374
  %83 = load ptr, ptr %module.939, align 8
  %84 = load ptr, ptr %a0.945, align 8
  %85 = getelementptr inbounds nuw %ASTNode, ptr %84, i32 0, i32 8
  %86 = load ptr, ptr %85, align 8
  %87 = call ptr @ptr_to_node(ptr %86)
  %88 = call ptr @type_int__Void()
  %89 = call ptr @sema_check_value__Struct_ASTNode_Struct_ASTNode_Struct_TypeInfo_String(ptr %83, ptr %87, ptr %88, ptr @.str.s887)
  ret i1 true

label_2377:                                       ; preds = %label_2374
  call void @sema_error__String(ptr @.str.s886)
  br label %label_2379

label_2382:                                       ; preds = %label_2376
  %90 = load ptr, ptr %name.940, align 8
  %91 = call i32 @str_equals(ptr %90, ptr @.str.s891)
  %92 = icmp eq i32 %91, 1
  br i1 %92, label %label_2386, label %label_2388

label_2380:                                       ; preds = %label_2376
  %93 = load ptr, ptr %arg_ptr.941, align 8
  %94 = call ptr @ptr_to_node(ptr %93)
  store ptr %94, ptr %a0.947, align 8
  %95 = load ptr, ptr %module.939, align 8
  %96 = load ptr, ptr %a0.947, align 8
  %97 = call ptr @sema_expr__Struct_ASTNode_Struct_ASTNode(ptr %95, ptr %96)
  store ptr %97, ptr %lt.948, align 8
  %98 = load ptr, ptr %lt.948, align 8
  %99 = getelementptr inbounds nuw %TypeInfo, ptr %98, i32 0, i32 0
  %100 = load i32, ptr %99, align 4
  %101 = icmp ne i32 %100, 11
  br i1 %101, label %label_2383, label %label_2385

label_2385:                                       ; preds = %label_2383, %label_2380
  %102 = load ptr, ptr %module.939, align 8
  %103 = load ptr, ptr %a0.947, align 8
  %104 = getelementptr inbounds nuw %ASTNode, ptr %103, i32 0, i32 8
  %105 = load ptr, ptr %104, align 8
  %106 = call ptr @ptr_to_node(ptr %105)
  %107 = load ptr, ptr %lt.948, align 8
  %108 = getelementptr inbounds nuw %TypeInfo, ptr %107, i32 0, i32 3
  %109 = load ptr, ptr %108, align 8
  %110 = call ptr @ptr_to_type(ptr %109)
  %111 = call ptr @sema_check_value__Struct_ASTNode_Struct_ASTNode_Struct_TypeInfo_String(ptr %102, ptr %106, ptr %110, ptr @.str.s890)
  ret i1 true

label_2383:                                       ; preds = %label_2380
  call void @sema_error__String(ptr @.str.s889)
  br label %label_2385

label_2388:                                       ; preds = %label_2382
  %112 = call ptr @type_invalid__Void()
  store ptr %112, ptr %expected.952, align 8
  %113 = load ptr, ptr %name.940, align 8
  %114 = call i32 @str_equals(ptr %113, ptr @.str.s895)
  %115 = icmp eq i32 %114, 1
  store i1 %115, ptr %sc.119, align 1
  br i1 %115, label %label_2393, label %label_2392

label_2386:                                       ; preds = %label_2382
  %116 = load ptr, ptr %arg_ptr.941, align 8
  %117 = call ptr @ptr_to_node(ptr %116)
  store ptr %117, ptr %a0.949, align 8
  %118 = load ptr, ptr %module.939, align 8
  %119 = load ptr, ptr %a0.949, align 8
  %120 = call ptr @sema_expr__Struct_ASTNode_Struct_ASTNode(ptr %118, ptr %119)
  store ptr %120, ptr %lt.950, align 8
  %121 = load ptr, ptr %lt.950, align 8
  %122 = getelementptr inbounds nuw %TypeInfo, ptr %121, i32 0, i32 0
  %123 = load i32, ptr %122, align 4
  %124 = icmp ne i32 %123, 11
  br i1 %124, label %label_2389, label %label_2391

label_2391:                                       ; preds = %label_2389, %label_2386
  %125 = load ptr, ptr %a0.949, align 8
  %126 = getelementptr inbounds nuw %ASTNode, ptr %125, i32 0, i32 8
  %127 = load ptr, ptr %126, align 8
  %128 = call ptr @ptr_to_node(ptr %127)
  store ptr %128, ptr %a1.951, align 8
  %129 = load ptr, ptr %module.939, align 8
  %130 = load ptr, ptr %a1.951, align 8
  %131 = call ptr @type_int__Void()
  %132 = call ptr @sema_check_value__Struct_ASTNode_Struct_ASTNode_Struct_TypeInfo_String(ptr %129, ptr %130, ptr %131, ptr @.str.s893)
  %133 = load ptr, ptr %module.939, align 8
  %134 = load ptr, ptr %a1.951, align 8
  %135 = getelementptr inbounds nuw %ASTNode, ptr %134, i32 0, i32 8
  %136 = load ptr, ptr %135, align 8
  %137 = call ptr @ptr_to_node(ptr %136)
  %138 = load ptr, ptr %lt.950, align 8
  %139 = getelementptr inbounds nuw %TypeInfo, ptr %138, i32 0, i32 3
  %140 = load ptr, ptr %139, align 8
  %141 = call ptr @ptr_to_type(ptr %140)
  %142 = call ptr @sema_check_value__Struct_ASTNode_Struct_ASTNode_Struct_TypeInfo_String(ptr %133, ptr %137, ptr %141, ptr @.str.s894)
  ret i1 true

label_2389:                                       ; preds = %label_2386
  call void @sema_error__String(ptr @.str.s892)
  br label %label_2391

label_2392:                                       ; preds = %label_2388
  %143 = load ptr, ptr %name.940, align 8
  %144 = call i32 @str_equals(ptr %143, ptr @.str.s896)
  %145 = icmp eq i32 %144, 1
  store i1 %145, ptr %sc.119, align 1
  br label %label_2393

label_2393:                                       ; preds = %label_2392, %label_2388
  %146 = load i1, ptr %sc.119, align 1
  br i1 %146, label %label_2394, label %label_2396

label_2396:                                       ; preds = %label_2394, %label_2393
  %147 = load ptr, ptr %name.940, align 8
  %148 = call i32 @str_equals(ptr %147, ptr @.str.s897)
  %149 = icmp eq i32 %148, 1
  store i1 %149, ptr %sc.120, align 1
  br i1 %149, label %label_2398, label %label_2397

label_2394:                                       ; preds = %label_2393
  %150 = call ptr @type_int__Void()
  store ptr %150, ptr %expected.952, align 8
  br label %label_2396

label_2397:                                       ; preds = %label_2396
  %151 = load ptr, ptr %name.940, align 8
  %152 = call i32 @str_equals(ptr %151, ptr @.str.s898)
  %153 = icmp eq i32 %152, 1
  store i1 %153, ptr %sc.120, align 1
  br label %label_2398

label_2398:                                       ; preds = %label_2397, %label_2396
  %154 = load i1, ptr %sc.120, align 1
  br i1 %154, label %label_2399, label %label_2401

label_2401:                                       ; preds = %label_2399, %label_2398
  %155 = load ptr, ptr %name.940, align 8
  %156 = call i32 @str_equals(ptr %155, ptr @.str.s899)
  %157 = icmp eq i32 %156, 1
  store i1 %157, ptr %sc.121, align 1
  br i1 %157, label %label_2403, label %label_2402

label_2399:                                       ; preds = %label_2398
  %158 = call ptr @type_float__Void()
  store ptr %158, ptr %expected.952, align 8
  br label %label_2401

label_2402:                                       ; preds = %label_2401
  %159 = load ptr, ptr %name.940, align 8
  %160 = call i32 @str_equals(ptr %159, ptr @.str.s900)
  %161 = icmp eq i32 %160, 1
  store i1 %161, ptr %sc.121, align 1
  br label %label_2403

label_2403:                                       ; preds = %label_2402, %label_2401
  %162 = load i1, ptr %sc.121, align 1
  br i1 %162, label %label_2404, label %label_2406

label_2406:                                       ; preds = %label_2404, %label_2403
  %163 = load ptr, ptr %name.940, align 8
  %164 = call i32 @str_equals(ptr %163, ptr @.str.s901)
  %165 = icmp eq i32 %164, 1
  store i1 %165, ptr %sc.122, align 1
  br i1 %165, label %label_2408, label %label_2407

label_2404:                                       ; preds = %label_2403
  %166 = call ptr @type_bool__Void()
  store ptr %166, ptr %expected.952, align 8
  br label %label_2406

label_2407:                                       ; preds = %label_2406
  %167 = load ptr, ptr %name.940, align 8
  %168 = call i32 @str_equals(ptr %167, ptr @.str.s902)
  %169 = icmp eq i32 %168, 1
  store i1 %169, ptr %sc.122, align 1
  br label %label_2408

label_2408:                                       ; preds = %label_2407, %label_2406
  %170 = load i1, ptr %sc.122, align 1
  br i1 %170, label %label_2409, label %label_2411

label_2411:                                       ; preds = %label_2409, %label_2408
  %171 = load ptr, ptr %expected.952, align 8
  %172 = call i1 @type_is_valid__Struct_TypeInfo(ptr %171)
  br i1 %172, label %label_2412, label %label_2414

label_2409:                                       ; preds = %label_2408
  %173 = call ptr @type_char__Void()
  store ptr %173, ptr %expected.952, align 8
  br label %label_2411

label_2414:                                       ; preds = %label_2411
  ret i1 false

label_2412:                                       ; preds = %label_2411
  %174 = load ptr, ptr %arg_ptr.941, align 8
  %175 = call i32 @str_equals(ptr %174, ptr @.str.s903)
  %176 = icmp eq i32 %175, 1
  store i1 %176, ptr %sc.123, align 1
  br i1 %176, label %label_2416, label %label_2415

label_2415:                                       ; preds = %label_2412
  %177 = load ptr, ptr %arg_ptr.941, align 8
  %178 = call ptr @ptr_to_node(ptr %177)
  %179 = getelementptr inbounds nuw %ASTNode, ptr %178, i32 0, i32 8
  %180 = load ptr, ptr %179, align 8
  %181 = call i32 @str_equals(ptr %180, ptr @.str.s904)
  %182 = icmp eq i32 %181, 0
  store i1 %182, ptr %sc.123, align 1
  br label %label_2416

label_2416:                                       ; preds = %label_2415, %label_2412
  %183 = load i1, ptr %sc.123, align 1
  br i1 %183, label %label_2417, label %label_2419

label_2419:                                       ; preds = %label_2417, %label_2416
  %184 = load ptr, ptr %module.939, align 8
  %185 = load ptr, ptr %arg_ptr.941, align 8
  %186 = call ptr @ptr_to_node(ptr %185)
  %187 = call ptr @sema_expr__Struct_ASTNode_Struct_ASTNode(ptr %184, ptr %186)
  store ptr %187, ptr %actual.953, align 8
  %188 = load ptr, ptr %name.940, align 8
  %189 = call ptr @str_concat(ptr %188, ptr @.str.s906)
  %190 = load ptr, ptr %expected.952, align 8
  %191 = load ptr, ptr %actual.953, align 8
  call void @sema_expect_assignable__String_Struct_TypeInfo_Struct_TypeInfo(ptr %189, ptr %190, ptr %191)
  ret i1 true

label_2417:                                       ; preds = %label_2416
  %192 = load ptr, ptr %name.940, align 8
  %193 = call ptr @str_concat(ptr %192, ptr @.str.s905)
  call void @sema_error__String(ptr %193)
  br label %label_2419
}

define void @sema_statement__Struct_ASTNode_Struct_ASTNode_Struct_TypeInfo(ptr %0, ptr %1, ptr %2) {
entry:
  %module.997 = alloca ptr, align 8
  store ptr %0, ptr %module.997, align 8
  %stmt.998 = alloca ptr, align 8
  store ptr %1, ptr %stmt.998, align 8
  %expected_return.999 = alloca ptr, align 8
  store ptr %2, ptr %expected_return.999, align 8
  %3 = load ptr, ptr %stmt.998, align 8
  %4 = getelementptr inbounds nuw %ASTNode, ptr %3, i32 0, i32 0
  %5 = load i32, ptr %4, align 4
  %6 = icmp eq i32 %5, 3
  %var_t.1000 = alloca ptr, align 8
  %has_annotation.1001 = alloca i1, align 1
  %has_init.1002 = alloca i1, align 1
  %target.1003 = alloca ptr, align 8
  %target_t.1004 = alloca ptr, align 8
  %value_t.1005 = alloca ptr, align 8
  %cond_t.1006 = alloca ptr, align 8
  %else_node.1007 = alloca ptr, align 8
  %cond_t2.1008 = alloca ptr, align 8
  %start_t.1009 = alloca ptr, align 8
  %end_t.1010 = alloca ptr, align 8
  %scrut_t.1011 = alloca ptr, align 8
  %sc.156 = alloca i1, align 1
  %pat_expected.1012 = alloca ptr, align 8
  %arm_ptr.1013 = alloca ptr, align 8
  %arm.1014 = alloca ptr, align 8
  br i1 %6, label %label_2646, label %label_2648

label_2648:                                       ; preds = %label_2663, %entry
  %7 = load ptr, ptr %stmt.998, align 8
  %8 = getelementptr inbounds nuw %ASTNode, ptr %7, i32 0, i32 0
  %9 = load i32, ptr %8, align 4
  %10 = icmp eq i32 %9, 16
  br i1 %10, label %label_2664, label %label_2666

label_2646:                                       ; preds = %entry
  %11 = call ptr @type_invalid__Void()
  store ptr %11, ptr %var_t.1000, align 8
  %12 = load ptr, ptr %stmt.998, align 8
  %13 = getelementptr inbounds nuw %ASTNode, ptr %12, i32 0, i32 5
  %14 = load ptr, ptr %13, align 8
  %15 = call i32 @str_equals(ptr %14, ptr @.str.s966)
  %16 = icmp eq i32 %15, 0
  store i1 %16, ptr %has_annotation.1001, align 1
  %17 = load ptr, ptr %stmt.998, align 8
  %18 = getelementptr inbounds nuw %ASTNode, ptr %17, i32 0, i32 6
  %19 = load ptr, ptr %18, align 8
  %20 = call i32 @str_equals(ptr %19, ptr @.str.s967)
  %21 = icmp eq i32 %20, 0
  store i1 %21, ptr %has_init.1002, align 1
  %22 = load i1, ptr %has_annotation.1001, align 1
  br i1 %22, label %label_2649, label %label_2651

label_2651:                                       ; preds = %label_2649, %label_2646
  %23 = load i1, ptr %has_init.1002, align 1
  br i1 %23, label %label_2652, label %label_2654

label_2649:                                       ; preds = %label_2646
  %24 = load ptr, ptr %module.997, align 8
  %25 = load ptr, ptr %stmt.998, align 8
  %26 = getelementptr inbounds nuw %ASTNode, ptr %25, i32 0, i32 5
  %27 = load ptr, ptr %26, align 8
  %28 = call ptr @ptr_to_node(ptr %27)
  %29 = call ptr @sema_annotation_type__Struct_ASTNode_Struct_ASTNode(ptr %24, ptr %28)
  store ptr %29, ptr %var_t.1000, align 8
  br label %label_2651

label_2654:                                       ; preds = %label_2657, %label_2651
  %30 = load ptr, ptr %var_t.1000, align 8
  %31 = call i1 @type_is_valid__Struct_TypeInfo(ptr %30)
  %32 = icmp eq i1 %31, false
  br i1 %32, label %label_2658, label %label_2660

label_2652:                                       ; preds = %label_2651
  %33 = load i1, ptr %has_annotation.1001, align 1
  br i1 %33, label %label_2655, label %label_2656

label_2656:                                       ; preds = %label_2652
  %34 = load ptr, ptr %module.997, align 8
  %35 = load ptr, ptr %stmt.998, align 8
  %36 = getelementptr inbounds nuw %ASTNode, ptr %35, i32 0, i32 6
  %37 = load ptr, ptr %36, align 8
  %38 = call ptr @ptr_to_node(ptr %37)
  %39 = call ptr @sema_expr__Struct_ASTNode_Struct_ASTNode(ptr %34, ptr %38)
  store ptr %39, ptr %var_t.1000, align 8
  br label %label_2657

label_2655:                                       ; preds = %label_2652
  %40 = load ptr, ptr %module.997, align 8
  %41 = load ptr, ptr %stmt.998, align 8
  %42 = getelementptr inbounds nuw %ASTNode, ptr %41, i32 0, i32 6
  %43 = load ptr, ptr %42, align 8
  %44 = call ptr @ptr_to_node(ptr %43)
  %45 = load ptr, ptr %var_t.1000, align 8
  %46 = load ptr, ptr %stmt.998, align 8
  %47 = getelementptr inbounds nuw %ASTNode, ptr %46, i32 0, i32 1
  %48 = load ptr, ptr %47, align 8
  %49 = call ptr @str_concat(ptr @.str.s968, ptr %48)
  %50 = call ptr @sema_check_value__Struct_ASTNode_Struct_ASTNode_Struct_TypeInfo_String(ptr %40, ptr %44, ptr %45, ptr %49)
  br label %label_2657

label_2657:                                       ; preds = %label_2656, %label_2655
  %51 = load ptr, ptr %stmt.998, align 8
  %52 = getelementptr inbounds nuw %ASTNode, ptr %51, i32 0, i32 6
  %53 = load ptr, ptr %52, align 8
  %54 = call ptr @ptr_to_node(ptr %53)
  call void @sema_move_operand__Struct_ASTNode(ptr %54)
  br label %label_2654

label_2660:                                       ; preds = %label_2658, %label_2654
  %55 = load ptr, ptr %stmt.998, align 8
  %56 = getelementptr inbounds nuw %ASTNode, ptr %55, i32 0, i32 1
  %57 = load ptr, ptr %56, align 8
  call void @ir_unmark_moved(ptr %57)
  %58 = load ptr, ptr %stmt.998, align 8
  %59 = getelementptr inbounds nuw %ASTNode, ptr %58, i32 0, i32 1
  %60 = load ptr, ptr %59, align 8
  %61 = load ptr, ptr %var_t.1000, align 8
  %62 = call ptr @type_sem_key__Struct_TypeInfo(ptr %61)
  call void @ir_set_var_type(ptr %60, ptr %62)
  %63 = load ptr, ptr %stmt.998, align 8
  %64 = getelementptr inbounds nuw %ASTNode, ptr %63, i32 0, i32 3
  %65 = load i32, ptr %64, align 4
  %66 = icmp eq i32 %65, 1
  br i1 %66, label %label_2661, label %label_2663

label_2658:                                       ; preds = %label_2654
  %67 = load ptr, ptr %stmt.998, align 8
  %68 = getelementptr inbounds nuw %ASTNode, ptr %67, i32 0, i32 1
  %69 = load ptr, ptr %68, align 8
  %70 = call ptr @str_concat(ptr @.str.s969, ptr %69)
  call void @sema_error__String(ptr %70)
  br label %label_2660

label_2663:                                       ; preds = %label_2661, %label_2660
  %71 = load ptr, ptr %stmt.998, align 8
  %72 = load ptr, ptr %var_t.1000, align 8
  call void @node_set_type__Struct_ASTNode_Struct_TypeInfo(ptr %71, ptr %72)
  br label %label_2648

label_2661:                                       ; preds = %label_2660
  %73 = load ptr, ptr %stmt.998, align 8
  %74 = getelementptr inbounds nuw %ASTNode, ptr %73, i32 0, i32 1
  %75 = load ptr, ptr %74, align 8
  call void @ir_mark_mutable(ptr %75)
  br label %label_2663

label_2666:                                       ; preds = %label_2669, %label_2648
  %76 = load ptr, ptr %stmt.998, align 8
  %77 = getelementptr inbounds nuw %ASTNode, ptr %76, i32 0, i32 0
  %78 = load i32, ptr %77, align 4
  %79 = icmp eq i32 %78, 15
  br i1 %79, label %label_2673, label %label_2675

label_2664:                                       ; preds = %label_2648
  %80 = load ptr, ptr %stmt.998, align 8
  %81 = getelementptr inbounds nuw %ASTNode, ptr %80, i32 0, i32 5
  %82 = load ptr, ptr %81, align 8
  %83 = call ptr @ptr_to_node(ptr %82)
  store ptr %83, ptr %target.1003, align 8
  %84 = load ptr, ptr %target.1003, align 8
  %85 = getelementptr inbounds nuw %ASTNode, ptr %84, i32 0, i32 0
  %86 = load i32, ptr %85, align 4
  %87 = icmp eq i32 %86, 23
  br i1 %87, label %label_2667, label %label_2669

label_2669:                                       ; preds = %label_2672, %label_2664
  %88 = load ptr, ptr %module.997, align 8
  %89 = load ptr, ptr %target.1003, align 8
  %90 = call ptr @sema_expr__Struct_ASTNode_Struct_ASTNode(ptr %88, ptr %89)
  store ptr %90, ptr %target_t.1004, align 8
  %91 = load ptr, ptr %module.997, align 8
  %92 = load ptr, ptr %stmt.998, align 8
  %93 = getelementptr inbounds nuw %ASTNode, ptr %92, i32 0, i32 6
  %94 = load ptr, ptr %93, align 8
  %95 = call ptr @ptr_to_node(ptr %94)
  %96 = call ptr @sema_expr__Struct_ASTNode_Struct_ASTNode(ptr %91, ptr %95)
  store ptr %96, ptr %value_t.1005, align 8
  %97 = load ptr, ptr %target_t.1004, align 8
  %98 = load ptr, ptr %value_t.1005, align 8
  call void @sema_expect_assignable__String_Struct_TypeInfo_Struct_TypeInfo(ptr @.str.s972, ptr %97, ptr %98)
  %99 = load ptr, ptr %stmt.998, align 8
  %100 = getelementptr inbounds nuw %ASTNode, ptr %99, i32 0, i32 6
  %101 = load ptr, ptr %100, align 8
  %102 = call ptr @ptr_to_node(ptr %101)
  call void @sema_move_operand__Struct_ASTNode(ptr %102)
  br label %label_2666

label_2667:                                       ; preds = %label_2664
  %103 = load ptr, ptr %target.1003, align 8
  %104 = getelementptr inbounds nuw %ASTNode, ptr %103, i32 0, i32 1
  %105 = load ptr, ptr %104, align 8
  %106 = call i32 @ir_var_is_mutable(ptr %105)
  %107 = icmp eq i32 %106, 0
  br i1 %107, label %label_2670, label %label_2672

label_2672:                                       ; preds = %label_2670, %label_2667
  br label %label_2669

label_2670:                                       ; preds = %label_2667
  %108 = load ptr, ptr %target.1003, align 8
  %109 = getelementptr inbounds nuw %ASTNode, ptr %108, i32 0, i32 1
  %110 = load ptr, ptr %109, align 8
  %111 = call ptr @str_concat(ptr @.str.s970, ptr %110)
  %112 = call ptr @str_concat(ptr %111, ptr @.str.s971)
  call void @sema_error__String(ptr %112)
  br label %label_2672

label_2675:                                       ; preds = %label_2678, %label_2666
  %113 = load ptr, ptr %stmt.998, align 8
  %114 = getelementptr inbounds nuw %ASTNode, ptr %113, i32 0, i32 0
  %115 = load i32, ptr %114, align 4
  %116 = icmp eq i32 %115, 17
  br i1 %116, label %label_2679, label %label_2681

label_2673:                                       ; preds = %label_2666
  %117 = load ptr, ptr %stmt.998, align 8
  %118 = getelementptr inbounds nuw %ASTNode, ptr %117, i32 0, i32 5
  %119 = load ptr, ptr %118, align 8
  %120 = call i32 @str_equals(ptr %119, ptr @.str.s973)
  %121 = icmp eq i32 %120, 0
  br i1 %121, label %label_2676, label %label_2677

label_2677:                                       ; preds = %label_2673
  %122 = load ptr, ptr %expected_return.999, align 8
  %123 = call ptr @type_void__Void()
  call void @sema_expect_assignable__String_Struct_TypeInfo_Struct_TypeInfo(ptr @.str.s975, ptr %122, ptr %123)
  br label %label_2678

label_2676:                                       ; preds = %label_2673
  %124 = load ptr, ptr %module.997, align 8
  %125 = load ptr, ptr %stmt.998, align 8
  %126 = getelementptr inbounds nuw %ASTNode, ptr %125, i32 0, i32 5
  %127 = load ptr, ptr %126, align 8
  %128 = call ptr @ptr_to_node(ptr %127)
  %129 = load ptr, ptr %expected_return.999, align 8
  %130 = call ptr @sema_check_value__Struct_ASTNode_Struct_ASTNode_Struct_TypeInfo_String(ptr %124, ptr %128, ptr %129, ptr @.str.s974)
  br label %label_2678

label_2678:                                       ; preds = %label_2677, %label_2676
  br label %label_2675

label_2681:                                       ; preds = %label_2684, %label_2675
  %131 = load ptr, ptr %stmt.998, align 8
  %132 = getelementptr inbounds nuw %ASTNode, ptr %131, i32 0, i32 0
  %133 = load i32, ptr %132, align 4
  %134 = icmp eq i32 %133, 10
  br i1 %134, label %label_2685, label %label_2687

label_2679:                                       ; preds = %label_2675
  %135 = load ptr, ptr %stmt.998, align 8
  %136 = getelementptr inbounds nuw %ASTNode, ptr %135, i32 0, i32 5
  %137 = load ptr, ptr %136, align 8
  %138 = call i32 @str_equals(ptr %137, ptr @.str.s976)
  %139 = icmp eq i32 %138, 0
  br i1 %139, label %label_2682, label %label_2684

label_2684:                                       ; preds = %label_2682, %label_2679
  br label %label_2681

label_2682:                                       ; preds = %label_2679
  %140 = load ptr, ptr %module.997, align 8
  %141 = load ptr, ptr %stmt.998, align 8
  %142 = getelementptr inbounds nuw %ASTNode, ptr %141, i32 0, i32 5
  %143 = load ptr, ptr %142, align 8
  %144 = call ptr @ptr_to_node(ptr %143)
  %145 = call ptr @sema_expr__Struct_ASTNode_Struct_ASTNode(ptr %140, ptr %144)
  br label %label_2684

label_2687:                                       ; preds = %label_2690, %label_2681
  %146 = load ptr, ptr %stmt.998, align 8
  %147 = getelementptr inbounds nuw %ASTNode, ptr %146, i32 0, i32 0
  %148 = load i32, ptr %147, align 4
  %149 = icmp eq i32 %148, 13
  br i1 %149, label %label_2694, label %label_2696

label_2685:                                       ; preds = %label_2681
  %150 = load ptr, ptr %module.997, align 8
  %151 = load ptr, ptr %stmt.998, align 8
  %152 = getelementptr inbounds nuw %ASTNode, ptr %151, i32 0, i32 5
  %153 = load ptr, ptr %152, align 8
  %154 = call ptr @ptr_to_node(ptr %153)
  %155 = call ptr @sema_expr__Struct_ASTNode_Struct_ASTNode(ptr %150, ptr %154)
  store ptr %155, ptr %cond_t.1006, align 8
  %156 = call ptr @type_bool__Void()
  %157 = load ptr, ptr %cond_t.1006, align 8
  call void @sema_expect_assignable__String_Struct_TypeInfo_Struct_TypeInfo(ptr @.str.s977, ptr %156, ptr %157)
  %158 = load ptr, ptr %module.997, align 8
  %159 = load ptr, ptr %stmt.998, align 8
  %160 = getelementptr inbounds nuw %ASTNode, ptr %159, i32 0, i32 6
  %161 = load ptr, ptr %160, align 8
  %162 = call ptr @ptr_to_node(ptr %161)
  %163 = load ptr, ptr %expected_return.999, align 8
  call void @sema_block__Struct_ASTNode_Struct_ASTNode_Struct_TypeInfo(ptr %158, ptr %162, ptr %163)
  %164 = load ptr, ptr %stmt.998, align 8
  %165 = getelementptr inbounds nuw %ASTNode, ptr %164, i32 0, i32 7
  %166 = load ptr, ptr %165, align 8
  %167 = call i32 @str_equals(ptr %166, ptr @.str.s978)
  %168 = icmp eq i32 %167, 0
  br i1 %168, label %label_2688, label %label_2690

label_2690:                                       ; preds = %label_2693, %label_2685
  br label %label_2687

label_2688:                                       ; preds = %label_2685
  %169 = load ptr, ptr %stmt.998, align 8
  %170 = getelementptr inbounds nuw %ASTNode, ptr %169, i32 0, i32 7
  %171 = load ptr, ptr %170, align 8
  %172 = call ptr @ptr_to_node(ptr %171)
  store ptr %172, ptr %else_node.1007, align 8
  %173 = load ptr, ptr %else_node.1007, align 8
  %174 = getelementptr inbounds nuw %ASTNode, ptr %173, i32 0, i32 0
  %175 = load i32, ptr %174, align 4
  %176 = icmp eq i32 %175, 10
  br i1 %176, label %label_2691, label %label_2692

label_2692:                                       ; preds = %label_2688
  %177 = load ptr, ptr %module.997, align 8
  %178 = load ptr, ptr %else_node.1007, align 8
  %179 = load ptr, ptr %expected_return.999, align 8
  call void @sema_block__Struct_ASTNode_Struct_ASTNode_Struct_TypeInfo(ptr %177, ptr %178, ptr %179)
  br label %label_2693

label_2691:                                       ; preds = %label_2688
  %180 = load ptr, ptr %module.997, align 8
  %181 = load ptr, ptr %else_node.1007, align 8
  %182 = load ptr, ptr %expected_return.999, align 8
  call void @sema_statement__Struct_ASTNode_Struct_ASTNode_Struct_TypeInfo(ptr %180, ptr %181, ptr %182)
  br label %label_2693

label_2693:                                       ; preds = %label_2692, %label_2691
  br label %label_2690

label_2696:                                       ; preds = %label_2694, %label_2687
  %183 = load ptr, ptr %stmt.998, align 8
  %184 = getelementptr inbounds nuw %ASTNode, ptr %183, i32 0, i32 0
  %185 = load i32, ptr %184, align 4
  %186 = icmp eq i32 %185, 14
  br i1 %186, label %label_2697, label %label_2699

label_2694:                                       ; preds = %label_2687
  %187 = load ptr, ptr %module.997, align 8
  %188 = load ptr, ptr %stmt.998, align 8
  %189 = getelementptr inbounds nuw %ASTNode, ptr %188, i32 0, i32 5
  %190 = load ptr, ptr %189, align 8
  %191 = call ptr @ptr_to_node(ptr %190)
  %192 = call ptr @sema_expr__Struct_ASTNode_Struct_ASTNode(ptr %187, ptr %191)
  store ptr %192, ptr %cond_t2.1008, align 8
  %193 = call ptr @type_bool__Void()
  %194 = load ptr, ptr %cond_t2.1008, align 8
  call void @sema_expect_assignable__String_Struct_TypeInfo_Struct_TypeInfo(ptr @.str.s979, ptr %193, ptr %194)
  call void @ir_loop_barrier_push()
  %195 = load ptr, ptr %module.997, align 8
  %196 = load ptr, ptr %stmt.998, align 8
  %197 = getelementptr inbounds nuw %ASTNode, ptr %196, i32 0, i32 6
  %198 = load ptr, ptr %197, align 8
  %199 = call ptr @ptr_to_node(ptr %198)
  %200 = load ptr, ptr %expected_return.999, align 8
  call void @sema_block__Struct_ASTNode_Struct_ASTNode_Struct_TypeInfo(ptr %195, ptr %199, ptr %200)
  call void @ir_loop_barrier_pop()
  br label %label_2696

label_2699:                                       ; preds = %label_2697, %label_2696
  %201 = load ptr, ptr %stmt.998, align 8
  %202 = getelementptr inbounds nuw %ASTNode, ptr %201, i32 0, i32 0
  %203 = load i32, ptr %202, align 4
  %204 = icmp eq i32 %203, 12
  br i1 %204, label %label_2700, label %label_2702

label_2697:                                       ; preds = %label_2696
  call void @ir_loop_barrier_push()
  %205 = load ptr, ptr %module.997, align 8
  %206 = load ptr, ptr %stmt.998, align 8
  %207 = getelementptr inbounds nuw %ASTNode, ptr %206, i32 0, i32 5
  %208 = load ptr, ptr %207, align 8
  %209 = call ptr @ptr_to_node(ptr %208)
  %210 = load ptr, ptr %expected_return.999, align 8
  call void @sema_block__Struct_ASTNode_Struct_ASTNode_Struct_TypeInfo(ptr %205, ptr %209, ptr %210)
  call void @ir_loop_barrier_pop()
  br label %label_2699

label_2702:                                       ; preds = %label_2700, %label_2699
  %211 = load ptr, ptr %stmt.998, align 8
  %212 = getelementptr inbounds nuw %ASTNode, ptr %211, i32 0, i32 0
  %213 = load i32, ptr %212, align 4
  %214 = icmp eq i32 %213, 11
  br i1 %214, label %label_2703, label %label_2705

label_2700:                                       ; preds = %label_2699
  %215 = load ptr, ptr %module.997, align 8
  %216 = load ptr, ptr %stmt.998, align 8
  %217 = getelementptr inbounds nuw %ASTNode, ptr %216, i32 0, i32 5
  %218 = load ptr, ptr %217, align 8
  %219 = call ptr @ptr_to_node(ptr %218)
  %220 = call ptr @sema_expr__Struct_ASTNode_Struct_ASTNode(ptr %215, ptr %219)
  store ptr %220, ptr %start_t.1009, align 8
  %221 = call ptr @type_int__Void()
  %222 = load ptr, ptr %start_t.1009, align 8
  call void @sema_expect_assignable__String_Struct_TypeInfo_Struct_TypeInfo(ptr @.str.s980, ptr %221, ptr %222)
  %223 = load ptr, ptr %module.997, align 8
  %224 = load ptr, ptr %stmt.998, align 8
  %225 = getelementptr inbounds nuw %ASTNode, ptr %224, i32 0, i32 6
  %226 = load ptr, ptr %225, align 8
  %227 = call ptr @ptr_to_node(ptr %226)
  %228 = call ptr @sema_expr__Struct_ASTNode_Struct_ASTNode(ptr %223, ptr %227)
  store ptr %228, ptr %end_t.1010, align 8
  %229 = call ptr @type_int__Void()
  %230 = load ptr, ptr %end_t.1010, align 8
  call void @sema_expect_assignable__String_Struct_TypeInfo_Struct_TypeInfo(ptr @.str.s981, ptr %229, ptr %230)
  call void @ir_scope_push()
  %231 = load ptr, ptr %stmt.998, align 8
  %232 = getelementptr inbounds nuw %ASTNode, ptr %231, i32 0, i32 1
  %233 = load ptr, ptr %232, align 8
  %234 = call ptr @type_int__Void()
  %235 = call ptr @type_sem_key__Struct_TypeInfo(ptr %234)
  call void @ir_set_var_type(ptr %233, ptr %235)
  call void @ir_loop_barrier_push()
  %236 = load ptr, ptr %module.997, align 8
  %237 = load ptr, ptr %stmt.998, align 8
  %238 = getelementptr inbounds nuw %ASTNode, ptr %237, i32 0, i32 7
  %239 = load ptr, ptr %238, align 8
  %240 = call ptr @ptr_to_node(ptr %239)
  %241 = load ptr, ptr %expected_return.999, align 8
  call void @sema_block__Struct_ASTNode_Struct_ASTNode_Struct_TypeInfo(ptr %236, ptr %240, ptr %241)
  call void @ir_loop_barrier_pop()
  call void @ir_scope_pop()
  br label %label_2702

label_2705:                                       ; preds = %label_2716, %label_2702
  ret void

label_2703:                                       ; preds = %label_2702
  %242 = load ptr, ptr %module.997, align 8
  %243 = load ptr, ptr %stmt.998, align 8
  %244 = getelementptr inbounds nuw %ASTNode, ptr %243, i32 0, i32 5
  %245 = load ptr, ptr %244, align 8
  %246 = call ptr @ptr_to_node(ptr %245)
  %247 = call ptr @sema_expr__Struct_ASTNode_Struct_ASTNode(ptr %242, ptr %246)
  store ptr %247, ptr %scrut_t.1011, align 8
  %248 = load ptr, ptr %scrut_t.1011, align 8
  %249 = getelementptr inbounds nuw %TypeInfo, ptr %248, i32 0, i32 0
  %250 = load i32, ptr %249, align 4
  %251 = icmp ne i32 %250, 2
  store i1 %251, ptr %sc.156, align 1
  br i1 %251, label %label_2706, label %label_2707

label_2707:                                       ; preds = %label_2706, %label_2703
  %252 = load i1, ptr %sc.156, align 1
  br i1 %252, label %label_2708, label %label_2710

label_2706:                                       ; preds = %label_2703
  %253 = load ptr, ptr %scrut_t.1011, align 8
  %254 = getelementptr inbounds nuw %TypeInfo, ptr %253, i32 0, i32 0
  %255 = load i32, ptr %254, align 4
  %256 = icmp ne i32 %255, 9
  store i1 %256, ptr %sc.156, align 1
  br label %label_2707

label_2710:                                       ; preds = %label_2708, %label_2707
  %257 = load ptr, ptr %scrut_t.1011, align 8
  %258 = call ptr @type_copy__Struct_TypeInfo(ptr %257)
  store ptr %258, ptr %pat_expected.1012, align 8
  %259 = load ptr, ptr %scrut_t.1011, align 8
  %260 = getelementptr inbounds nuw %TypeInfo, ptr %259, i32 0, i32 0
  %261 = load i32, ptr %260, align 4
  %262 = icmp eq i32 %261, 9
  br i1 %262, label %label_2711, label %label_2713

label_2708:                                       ; preds = %label_2707
  call void @sema_error__String(ptr @.str.s982)
  br label %label_2710

label_2713:                                       ; preds = %label_2711, %label_2710
  %263 = load ptr, ptr %stmt.998, align 8
  %264 = getelementptr inbounds nuw %ASTNode, ptr %263, i32 0, i32 6
  %265 = load ptr, ptr %264, align 8
  store ptr %265, ptr %arm_ptr.1013, align 8
  br label %label_2714

label_2711:                                       ; preds = %label_2710
  %266 = call ptr @type_int__Void()
  store ptr %266, ptr %pat_expected.1012, align 8
  br label %label_2713

label_2714:                                       ; preds = %label_2719, %label_2713
  %267 = load ptr, ptr %arm_ptr.1013, align 8
  %268 = call i32 @str_equals(ptr %267, ptr @.str.s983)
  %269 = icmp eq i32 %268, 0
  br i1 %269, label %label_2715, label %label_2716

label_2716:                                       ; preds = %label_2714
  br label %label_2705

label_2715:                                       ; preds = %label_2714
  %270 = load ptr, ptr %arm_ptr.1013, align 8
  %271 = call ptr @ptr_to_node(ptr %270)
  store ptr %271, ptr %arm.1014, align 8
  %272 = load ptr, ptr %arm.1014, align 8
  %273 = getelementptr inbounds nuw %ASTNode, ptr %272, i32 0, i32 1
  %274 = load ptr, ptr %273, align 8
  %275 = call i32 @str_equals(ptr %274, ptr @.str.s984)
  %276 = icmp eq i32 %275, 0
  br i1 %276, label %label_2717, label %label_2719

label_2719:                                       ; preds = %label_2717, %label_2715
  %277 = load ptr, ptr %module.997, align 8
  %278 = load ptr, ptr %arm.1014, align 8
  %279 = getelementptr inbounds nuw %ASTNode, ptr %278, i32 0, i32 6
  %280 = load ptr, ptr %279, align 8
  %281 = call ptr @ptr_to_node(ptr %280)
  %282 = load ptr, ptr %expected_return.999, align 8
  call void @sema_block__Struct_ASTNode_Struct_ASTNode_Struct_TypeInfo(ptr %277, ptr %281, ptr %282)
  %283 = load ptr, ptr %arm.1014, align 8
  %284 = getelementptr inbounds nuw %ASTNode, ptr %283, i32 0, i32 8
  %285 = load ptr, ptr %284, align 8
  store ptr %285, ptr %arm_ptr.1013, align 8
  br label %label_2714

label_2717:                                       ; preds = %label_2715
  %286 = load ptr, ptr %module.997, align 8
  %287 = load ptr, ptr %arm.1014, align 8
  %288 = getelementptr inbounds nuw %ASTNode, ptr %287, i32 0, i32 5
  %289 = load ptr, ptr %288, align 8
  %290 = call ptr @ptr_to_node(ptr %289)
  %291 = load ptr, ptr %pat_expected.1012, align 8
  %292 = call ptr @sema_check_value__Struct_ASTNode_Struct_ASTNode_Struct_TypeInfo_String(ptr %286, ptr %290, ptr %291, ptr @.str.s985)
  br label %label_2719
}

define void @sema_block__Struct_ASTNode_Struct_ASTNode_Struct_TypeInfo(ptr %0, ptr %1, ptr %2) {
entry:
  %module.1015 = alloca ptr, align 8
  store ptr %0, ptr %module.1015, align 8
  %block.1016 = alloca ptr, align 8
  store ptr %1, ptr %block.1016, align 8
  %expected_return.1017 = alloca ptr, align 8
  store ptr %2, ptr %expected_return.1017, align 8
  call void @ir_scope_push()
  %3 = load ptr, ptr %block.1016, align 8
  %4 = getelementptr inbounds nuw %ASTNode, ptr %3, i32 0, i32 5
  %5 = load ptr, ptr %4, align 8
  %stmt_ptr.1018 = alloca ptr, align 8
  store ptr %5, ptr %stmt_ptr.1018, align 8
  %stmt.1019 = alloca ptr, align 8
  %sc.157 = alloca i1, align 1
  br label %label_2720

label_2720:                                       ; preds = %label_2727, %entry
  %6 = load ptr, ptr %stmt_ptr.1018, align 8
  %7 = call i32 @str_equals(ptr %6, ptr @.str.s986)
  %8 = icmp eq i32 %7, 0
  br i1 %8, label %label_2721, label %label_2722

label_2722:                                       ; preds = %label_2720
  call void @ir_scope_pop()
  ret void

label_2721:                                       ; preds = %label_2720
  %9 = load ptr, ptr %stmt_ptr.1018, align 8
  %10 = call ptr @ptr_to_node(ptr %9)
  store ptr %10, ptr %stmt.1019, align 8
  %11 = load ptr, ptr %module.1015, align 8
  %12 = load ptr, ptr %stmt.1019, align 8
  %13 = load ptr, ptr %expected_return.1017, align 8
  call void @sema_statement__Struct_ASTNode_Struct_ASTNode_Struct_TypeInfo(ptr %11, ptr %12, ptr %13)
  %14 = load ptr, ptr %stmt.1019, align 8
  %15 = call i1 @sema_stmt_diverges__Struct_ASTNode(ptr %14)
  store i1 %15, ptr %sc.157, align 1
  br i1 %15, label %label_2723, label %label_2724

label_2724:                                       ; preds = %label_2723, %label_2721
  %16 = load i1, ptr %sc.157, align 1
  br i1 %16, label %label_2725, label %label_2727

label_2723:                                       ; preds = %label_2721
  %17 = load ptr, ptr %stmt.1019, align 8
  %18 = getelementptr inbounds nuw %ASTNode, ptr %17, i32 0, i32 8
  %19 = load ptr, ptr %18, align 8
  %20 = call i32 @str_equals(ptr %19, ptr @.str.s987)
  %21 = icmp eq i32 %20, 0
  store i1 %21, ptr %sc.157, align 1
  br label %label_2724

label_2727:                                       ; preds = %label_2725, %label_2724
  %22 = load ptr, ptr %stmt.1019, align 8
  %23 = getelementptr inbounds nuw %ASTNode, ptr %22, i32 0, i32 8
  %24 = load ptr, ptr %23, align 8
  store ptr %24, ptr %stmt_ptr.1018, align 8
  br label %label_2720

label_2725:                                       ; preds = %label_2724
  call void @sema_error__String(ptr @.str.s988)
  br label %label_2727
}

define void @sema_predeclare_function__Struct_ASTNode_Struct_ASTNode(ptr %0, ptr %1) {
entry:
  %module.1020 = alloca ptr, align 8
  store ptr %0, ptr %module.1020, align 8
  %fn_node.1021 = alloca ptr, align 8
  store ptr %1, ptr %fn_node.1021, align 8
  %2 = call ptr @type_void__Void()
  %ret_t.1022 = alloca ptr, align 8
  store ptr %2, ptr %ret_t.1022, align 8
  %3 = load ptr, ptr %fn_node.1021, align 8
  %4 = getelementptr inbounds nuw %ASTNode, ptr %3, i32 0, i32 0
  %5 = load i32, ptr %4, align 4
  %6 = icmp eq i32 %5, 4
  %symbol.1023 = alloca ptr, align 8
  %overload_key.1024 = alloca ptr, align 8
  br i1 %6, label %label_2728, label %label_2729

label_2729:                                       ; preds = %entry
  %7 = load ptr, ptr %module.1020, align 8
  %8 = load ptr, ptr %fn_node.1021, align 8
  %9 = getelementptr inbounds nuw %ASTNode, ptr %8, i32 0, i32 6
  %10 = load ptr, ptr %9, align 8
  %11 = call ptr @sema_declared_return_type__Struct_ASTNode_String(ptr %7, ptr %10)
  store ptr %11, ptr %ret_t.1022, align 8
  br label %label_2730

label_2728:                                       ; preds = %entry
  %12 = load ptr, ptr %module.1020, align 8
  %13 = load ptr, ptr %fn_node.1021, align 8
  %14 = getelementptr inbounds nuw %ASTNode, ptr %13, i32 0, i32 7
  %15 = load ptr, ptr %14, align 8
  %16 = call ptr @sema_declared_return_type__Struct_ASTNode_String(ptr %12, ptr %15)
  store ptr %16, ptr %ret_t.1022, align 8
  %17 = load ptr, ptr %fn_node.1021, align 8
  %18 = getelementptr inbounds nuw %ASTNode, ptr %17, i32 0, i32 1
  %19 = load ptr, ptr %18, align 8
  %20 = call i32 @str_equals(ptr %19, ptr @.str.s989)
  %21 = icmp eq i32 %20, 1
  br i1 %21, label %label_2731, label %label_2733

label_2733:                                       ; preds = %label_2731, %label_2728
  br label %label_2730

label_2731:                                       ; preds = %label_2728
  %22 = call ptr @type_int__Void()
  store ptr %22, ptr %ret_t.1022, align 8
  br label %label_2733

label_2730:                                       ; preds = %label_2729, %label_2733
  %23 = load ptr, ptr %module.1020, align 8
  %24 = load ptr, ptr %fn_node.1021, align 8
  %25 = call ptr @sema_function_symbol__Struct_ASTNode_Struct_ASTNode(ptr %23, ptr %24)
  store ptr %25, ptr %symbol.1023, align 8
  %26 = load ptr, ptr %fn_node.1021, align 8
  %27 = load ptr, ptr %symbol.1023, align 8
  %28 = getelementptr inbounds nuw %ASTNode, ptr %26, i32 0, i32 2
  store ptr %27, ptr %28, align 8
  %29 = load ptr, ptr %symbol.1023, align 8
  %30 = call ptr @sema_fn_key__String(ptr %29)
  store ptr %30, ptr %overload_key.1024, align 8
  %31 = load ptr, ptr %module.1020, align 8
  %32 = load ptr, ptr %symbol.1023, align 8
  %33 = call i32 @sema_function_symbol_count__Struct_ASTNode_String(ptr %31, ptr %32)
  %34 = icmp sgt i32 %33, 1
  br i1 %34, label %label_2734, label %label_2736

label_2736:                                       ; preds = %label_2734, %label_2730
  %35 = load ptr, ptr %overload_key.1024, align 8
  %36 = load ptr, ptr %ret_t.1022, align 8
  %37 = call ptr @type_sem_key__Struct_TypeInfo(ptr %36)
  call void @ir_set_var_type(ptr %35, ptr %37)
  ret void

label_2734:                                       ; preds = %label_2730
  %38 = load ptr, ptr %fn_node.1021, align 8
  %39 = getelementptr inbounds nuw %ASTNode, ptr %38, i32 0, i32 1
  %40 = load ptr, ptr %39, align 8
  %41 = call ptr @str_concat(ptr @.str.s990, ptr %40)
  call void @sema_error__String(ptr %41)
  br label %label_2736
}

define void @sema_predeclare_global__Struct_ASTNode_Struct_ASTNode(ptr %0, ptr %1) {
entry:
  %module.1025 = alloca ptr, align 8
  store ptr %0, ptr %module.1025, align 8
  %var_node.1026 = alloca ptr, align 8
  store ptr %1, ptr %var_node.1026, align 8
  %2 = call ptr @type_invalid__Void()
  %var_t.1027 = alloca ptr, align 8
  store ptr %2, ptr %var_t.1027, align 8
  %3 = load ptr, ptr %var_node.1026, align 8
  %4 = getelementptr inbounds nuw %ASTNode, ptr %3, i32 0, i32 5
  %5 = load ptr, ptr %4, align 8
  %6 = call i32 @str_equals(ptr %5, ptr @.str.s991)
  %7 = icmp eq i32 %6, 0
  br i1 %7, label %label_2737, label %label_2739

label_2739:                                       ; preds = %label_2737, %entry
  %8 = load ptr, ptr %var_node.1026, align 8
  %9 = getelementptr inbounds nuw %ASTNode, ptr %8, i32 0, i32 6
  %10 = load ptr, ptr %9, align 8
  %11 = call i32 @str_equals(ptr %10, ptr @.str.s992)
  %12 = icmp eq i32 %11, 0
  br i1 %12, label %label_2740, label %label_2742

label_2737:                                       ; preds = %entry
  %13 = load ptr, ptr %module.1025, align 8
  %14 = load ptr, ptr %var_node.1026, align 8
  %15 = getelementptr inbounds nuw %ASTNode, ptr %14, i32 0, i32 5
  %16 = load ptr, ptr %15, align 8
  %17 = call ptr @ptr_to_node(ptr %16)
  %18 = call ptr @sema_annotation_type__Struct_ASTNode_Struct_ASTNode(ptr %13, ptr %17)
  store ptr %18, ptr %var_t.1027, align 8
  br label %label_2739

label_2742:                                       ; preds = %label_2745, %label_2739
  %19 = load ptr, ptr %var_t.1027, align 8
  %20 = call i1 @type_is_valid__Struct_TypeInfo(ptr %19)
  %21 = icmp eq i1 %20, false
  br i1 %21, label %label_2746, label %label_2748

label_2740:                                       ; preds = %label_2739
  %22 = load ptr, ptr %var_t.1027, align 8
  %23 = call i1 @type_is_valid__Struct_TypeInfo(ptr %22)
  br i1 %23, label %label_2743, label %label_2744

label_2744:                                       ; preds = %label_2740
  %24 = load ptr, ptr %module.1025, align 8
  %25 = load ptr, ptr %var_node.1026, align 8
  %26 = getelementptr inbounds nuw %ASTNode, ptr %25, i32 0, i32 6
  %27 = load ptr, ptr %26, align 8
  %28 = call ptr @ptr_to_node(ptr %27)
  %29 = call ptr @sema_expr__Struct_ASTNode_Struct_ASTNode(ptr %24, ptr %28)
  store ptr %29, ptr %var_t.1027, align 8
  br label %label_2745

label_2743:                                       ; preds = %label_2740
  %30 = load ptr, ptr %module.1025, align 8
  %31 = load ptr, ptr %var_node.1026, align 8
  %32 = getelementptr inbounds nuw %ASTNode, ptr %31, i32 0, i32 6
  %33 = load ptr, ptr %32, align 8
  %34 = call ptr @ptr_to_node(ptr %33)
  %35 = load ptr, ptr %var_t.1027, align 8
  %36 = load ptr, ptr %var_node.1026, align 8
  %37 = getelementptr inbounds nuw %ASTNode, ptr %36, i32 0, i32 1
  %38 = load ptr, ptr %37, align 8
  %39 = call ptr @str_concat(ptr @.str.s993, ptr %38)
  %40 = call ptr @sema_check_value__Struct_ASTNode_Struct_ASTNode_Struct_TypeInfo_String(ptr %30, ptr %34, ptr %35, ptr %39)
  br label %label_2745

label_2745:                                       ; preds = %label_2744, %label_2743
  br label %label_2742

label_2748:                                       ; preds = %label_2746, %label_2742
  %41 = load ptr, ptr %var_node.1026, align 8
  %42 = getelementptr inbounds nuw %ASTNode, ptr %41, i32 0, i32 1
  %43 = load ptr, ptr %42, align 8
  call void @ir_register_global_name(ptr %43)
  %44 = load ptr, ptr %var_node.1026, align 8
  %45 = getelementptr inbounds nuw %ASTNode, ptr %44, i32 0, i32 1
  %46 = load ptr, ptr %45, align 8
  %47 = load ptr, ptr %var_t.1027, align 8
  %48 = call ptr @type_sem_key__Struct_TypeInfo(ptr %47)
  call void @ir_set_global_var_type(ptr %46, ptr %48)
  %49 = load ptr, ptr %var_node.1026, align 8
  %50 = getelementptr inbounds nuw %ASTNode, ptr %49, i32 0, i32 3
  %51 = load i32, ptr %50, align 4
  %52 = icmp eq i32 %51, 1
  br i1 %52, label %label_2749, label %label_2751

label_2746:                                       ; preds = %label_2742
  %53 = load ptr, ptr %var_node.1026, align 8
  %54 = getelementptr inbounds nuw %ASTNode, ptr %53, i32 0, i32 1
  %55 = load ptr, ptr %54, align 8
  %56 = call ptr @str_concat(ptr @.str.s994, ptr %55)
  call void @sema_error__String(ptr %56)
  br label %label_2748

label_2751:                                       ; preds = %label_2749, %label_2748
  %57 = load ptr, ptr %var_node.1026, align 8
  %58 = load ptr, ptr %var_t.1027, align 8
  call void @node_set_type__Struct_ASTNode_Struct_TypeInfo(ptr %57, ptr %58)
  ret void

label_2749:                                       ; preds = %label_2748
  %59 = load ptr, ptr %var_node.1026, align 8
  %60 = getelementptr inbounds nuw %ASTNode, ptr %59, i32 0, i32 1
  %61 = load ptr, ptr %60, align 8
  call void @ir_mark_mutable(ptr %61)
  br label %label_2751
}

define void @sema_function__Struct_ASTNode_Struct_ASTNode(ptr %0, ptr %1) {
entry:
  %module.1028 = alloca ptr, align 8
  store ptr %0, ptr %module.1028, align 8
  %fn_node.1029 = alloca ptr, align 8
  store ptr %1, ptr %fn_node.1029, align 8
  call void @ir_clear_local_var_types()
  call void @ir_clear_moved()
  call void @ir_clear_borrowed()
  call void @ir_scope_push()
  %2 = load ptr, ptr %module.1028, align 8
  %3 = load ptr, ptr %fn_node.1029, align 8
  %4 = getelementptr inbounds nuw %ASTNode, ptr %3, i32 0, i32 7
  %5 = load ptr, ptr %4, align 8
  %6 = call ptr @sema_declared_return_type__Struct_ASTNode_String(ptr %2, ptr %5)
  %expected_return.1030 = alloca ptr, align 8
  store ptr %6, ptr %expected_return.1030, align 8
  %7 = load ptr, ptr %fn_node.1029, align 8
  %8 = getelementptr inbounds nuw %ASTNode, ptr %7, i32 0, i32 1
  %9 = load ptr, ptr %8, align 8
  %10 = call i32 @str_equals(ptr %9, ptr @.str.s995)
  %11 = icmp eq i32 %10, 1
  %param_ptr.1031 = alloca ptr, align 8
  %param.1032 = alloca ptr, align 8
  %param_t.1033 = alloca ptr, align 8
  %sc.158 = alloca i1, align 1
  %body.1034 = alloca ptr, align 8
  br i1 %11, label %label_2752, label %label_2754

label_2754:                                       ; preds = %label_2752, %entry
  %12 = load ptr, ptr %fn_node.1029, align 8
  %13 = getelementptr inbounds nuw %ASTNode, ptr %12, i32 0, i32 5
  %14 = load ptr, ptr %13, align 8
  store ptr %14, ptr %param_ptr.1031, align 8
  br label %label_2755

label_2752:                                       ; preds = %entry
  %15 = call ptr @type_int__Void()
  store ptr %15, ptr %expected_return.1030, align 8
  br label %label_2754

label_2755:                                       ; preds = %label_2765, %label_2754
  %16 = load ptr, ptr %param_ptr.1031, align 8
  %17 = call i32 @str_equals(ptr %16, ptr @.str.s996)
  %18 = icmp eq i32 %17, 0
  br i1 %18, label %label_2756, label %label_2757

label_2757:                                       ; preds = %label_2755
  %19 = load ptr, ptr %fn_node.1029, align 8
  %20 = getelementptr inbounds nuw %ASTNode, ptr %19, i32 0, i32 6
  %21 = load ptr, ptr %20, align 8
  %22 = call i32 @str_equals(ptr %21, ptr @.str.s1000)
  %23 = icmp eq i32 %22, 0
  br i1 %23, label %label_2766, label %label_2768

label_2756:                                       ; preds = %label_2755
  %24 = load ptr, ptr %param_ptr.1031, align 8
  %25 = call ptr @ptr_to_node(ptr %24)
  store ptr %25, ptr %param.1032, align 8
  %26 = load ptr, ptr %module.1028, align 8
  %27 = load ptr, ptr %param.1032, align 8
  %28 = getelementptr inbounds nuw %ASTNode, ptr %27, i32 0, i32 5
  %29 = load ptr, ptr %28, align 8
  %30 = call ptr @ptr_to_node(ptr %29)
  %31 = call ptr @sema_annotation_type__Struct_ASTNode_Struct_ASTNode(ptr %26, ptr %30)
  store ptr %31, ptr %param_t.1033, align 8
  %32 = load ptr, ptr %param.1032, align 8
  %33 = getelementptr inbounds nuw %ASTNode, ptr %32, i32 0, i32 2
  %34 = load ptr, ptr %33, align 8
  %35 = call i32 @str_equals(ptr %34, ptr @.str.s997)
  %36 = icmp eq i32 %35, 1
  store i1 %36, ptr %sc.158, align 1
  br i1 %36, label %label_2758, label %label_2759

label_2759:                                       ; preds = %label_2758, %label_2756
  %37 = load i1, ptr %sc.158, align 1
  br i1 %37, label %label_2760, label %label_2762

label_2758:                                       ; preds = %label_2756
  %38 = load ptr, ptr %param_t.1033, align 8
  %39 = call i1 @type_is_move_only__Struct_TypeInfo(ptr %38)
  %40 = icmp eq i1 %39, false
  store i1 %40, ptr %sc.158, align 1
  br label %label_2759

label_2762:                                       ; preds = %label_2760, %label_2759
  %41 = load ptr, ptr %param.1032, align 8
  %42 = getelementptr inbounds nuw %ASTNode, ptr %41, i32 0, i32 2
  %43 = load ptr, ptr %42, align 8
  %44 = call i32 @str_equals(ptr %43, ptr @.str.s999)
  %45 = icmp eq i32 %44, 0
  br i1 %45, label %label_2763, label %label_2765

label_2760:                                       ; preds = %label_2759
  %46 = load ptr, ptr %param.1032, align 8
  %47 = getelementptr inbounds nuw %ASTNode, ptr %46, i32 0, i32 1
  %48 = load ptr, ptr %47, align 8
  %49 = call ptr @str_concat(ptr @.str.s998, ptr %48)
  call void @sema_error__String(ptr %49)
  br label %label_2762

label_2765:                                       ; preds = %label_2763, %label_2762
  %50 = load ptr, ptr %param.1032, align 8
  %51 = getelementptr inbounds nuw %ASTNode, ptr %50, i32 0, i32 1
  %52 = load ptr, ptr %51, align 8
  %53 = load ptr, ptr %param_t.1033, align 8
  %54 = call ptr @type_sem_key__Struct_TypeInfo(ptr %53)
  call void @ir_set_var_type(ptr %52, ptr %54)
  %55 = load ptr, ptr %param.1032, align 8
  %56 = load ptr, ptr %param_t.1033, align 8
  call void @node_set_type__Struct_ASTNode_Struct_TypeInfo(ptr %55, ptr %56)
  %57 = load ptr, ptr %param.1032, align 8
  %58 = getelementptr inbounds nuw %ASTNode, ptr %57, i32 0, i32 8
  %59 = load ptr, ptr %58, align 8
  store ptr %59, ptr %param_ptr.1031, align 8
  br label %label_2755

label_2763:                                       ; preds = %label_2762
  %60 = load ptr, ptr %param.1032, align 8
  %61 = getelementptr inbounds nuw %ASTNode, ptr %60, i32 0, i32 1
  %62 = load ptr, ptr %61, align 8
  call void @ir_mark_borrowed(ptr %62)
  br label %label_2765

label_2768:                                       ; preds = %label_2771, %label_2757
  call void @ir_scope_pop()
  ret void

label_2766:                                       ; preds = %label_2757
  %63 = load ptr, ptr %fn_node.1029, align 8
  %64 = getelementptr inbounds nuw %ASTNode, ptr %63, i32 0, i32 6
  %65 = load ptr, ptr %64, align 8
  %66 = call ptr @ptr_to_node(ptr %65)
  store ptr %66, ptr %body.1034, align 8
  %67 = load ptr, ptr %module.1028, align 8
  %68 = load ptr, ptr %body.1034, align 8
  %69 = load ptr, ptr %expected_return.1030, align 8
  call void @sema_block__Struct_ASTNode_Struct_ASTNode_Struct_TypeInfo(ptr %67, ptr %68, ptr %69)
  %70 = load ptr, ptr %expected_return.1030, align 8
  %71 = getelementptr inbounds nuw %TypeInfo, ptr %70, i32 0, i32 0
  %72 = load i32, ptr %71, align 4
  %73 = icmp ne i32 %72, 1
  br i1 %73, label %label_2769, label %label_2771

label_2771:                                       ; preds = %label_2774, %label_2766
  br label %label_2768

label_2769:                                       ; preds = %label_2766
  %74 = load ptr, ptr %body.1034, align 8
  %75 = call i1 @sema_block_diverges__Struct_ASTNode(ptr %74)
  %76 = icmp eq i1 %75, false
  br i1 %76, label %label_2772, label %label_2774

label_2774:                                       ; preds = %label_2772, %label_2769
  br label %label_2771

label_2772:                                       ; preds = %label_2769
  call void @print(ptr @.str.s1001)
  %77 = load ptr, ptr %fn_node.1029, align 8
  %78 = getelementptr inbounds nuw %ASTNode, ptr %77, i32 0, i32 1
  %79 = load ptr, ptr %78, align 8
  call void @print(ptr %79)
  call void @print(ptr @.str.s1002)
  %80 = load ptr, ptr %expected_return.1030, align 8
  %81 = call ptr @type_display__Struct_TypeInfo(ptr %80)
  call void @print(ptr %81)
  call void @println(ptr @.str.s1003)
  call void @exit(i32 1)
  br label %label_2774
}

define void @analyze_module__Struct_ASTNode(ptr %0) {
entry:
  %module.1035 = alloca ptr, align 8
  store ptr %0, ptr %module.1035, align 8
  call void @ir_clear_var_types()
  call void @ir_reset_globals()
  %1 = load ptr, ptr %module.1035, align 8
  %2 = getelementptr inbounds nuw %ASTNode, ptr %1, i32 0, i32 5
  %3 = load ptr, ptr %2, align 8
  %fn_ptr.1036 = alloca ptr, align 8
  store ptr %3, ptr %fn_ptr.1036, align 8
  %stmt.1037 = alloca ptr, align 8
  %sc.159 = alloca i1, align 1
  %global_ptr.1038 = alloca ptr, align 8
  %stmt2.1039 = alloca ptr, align 8
  %stmt_ptr.1040 = alloca ptr, align 8
  %stmt3.1041 = alloca ptr, align 8
  br label %label_2775

label_2775:                                       ; preds = %label_2782, %entry
  %4 = load ptr, ptr %fn_ptr.1036, align 8
  %5 = call i32 @str_equals(ptr %4, ptr @.str.s1004)
  %6 = icmp eq i32 %5, 0
  br i1 %6, label %label_2776, label %label_2777

label_2777:                                       ; preds = %label_2775
  %7 = load ptr, ptr %module.1035, align 8
  %8 = getelementptr inbounds nuw %ASTNode, ptr %7, i32 0, i32 5
  %9 = load ptr, ptr %8, align 8
  store ptr %9, ptr %global_ptr.1038, align 8
  br label %label_2783

label_2776:                                       ; preds = %label_2775
  %10 = load ptr, ptr %fn_ptr.1036, align 8
  %11 = call ptr @ptr_to_node(ptr %10)
  store ptr %11, ptr %stmt.1037, align 8
  %12 = load ptr, ptr %stmt.1037, align 8
  %13 = getelementptr inbounds nuw %ASTNode, ptr %12, i32 0, i32 0
  %14 = load i32, ptr %13, align 4
  %15 = icmp eq i32 %14, 4
  store i1 %15, ptr %sc.159, align 1
  br i1 %15, label %label_2779, label %label_2778

label_2778:                                       ; preds = %label_2776
  %16 = load ptr, ptr %stmt.1037, align 8
  %17 = getelementptr inbounds nuw %ASTNode, ptr %16, i32 0, i32 0
  %18 = load i32, ptr %17, align 4
  %19 = icmp eq i32 %18, 2
  store i1 %19, ptr %sc.159, align 1
  br label %label_2779

label_2779:                                       ; preds = %label_2778, %label_2776
  %20 = load i1, ptr %sc.159, align 1
  br i1 %20, label %label_2780, label %label_2782

label_2782:                                       ; preds = %label_2780, %label_2779
  %21 = load ptr, ptr %stmt.1037, align 8
  %22 = getelementptr inbounds nuw %ASTNode, ptr %21, i32 0, i32 8
  %23 = load ptr, ptr %22, align 8
  store ptr %23, ptr %fn_ptr.1036, align 8
  br label %label_2775

label_2780:                                       ; preds = %label_2779
  %24 = load ptr, ptr %module.1035, align 8
  %25 = load ptr, ptr %stmt.1037, align 8
  call void @sema_predeclare_function__Struct_ASTNode_Struct_ASTNode(ptr %24, ptr %25)
  br label %label_2782

label_2783:                                       ; preds = %label_2788, %label_2777
  %26 = load ptr, ptr %global_ptr.1038, align 8
  %27 = call i32 @str_equals(ptr %26, ptr @.str.s1005)
  %28 = icmp eq i32 %27, 0
  br i1 %28, label %label_2784, label %label_2785

label_2785:                                       ; preds = %label_2783
  %29 = load ptr, ptr %module.1035, align 8
  %30 = getelementptr inbounds nuw %ASTNode, ptr %29, i32 0, i32 5
  %31 = load ptr, ptr %30, align 8
  store ptr %31, ptr %stmt_ptr.1040, align 8
  br label %label_2789

label_2784:                                       ; preds = %label_2783
  %32 = load ptr, ptr %global_ptr.1038, align 8
  %33 = call ptr @ptr_to_node(ptr %32)
  store ptr %33, ptr %stmt2.1039, align 8
  %34 = load ptr, ptr %stmt2.1039, align 8
  %35 = getelementptr inbounds nuw %ASTNode, ptr %34, i32 0, i32 0
  %36 = load i32, ptr %35, align 4
  %37 = icmp eq i32 %36, 3
  br i1 %37, label %label_2786, label %label_2788

label_2788:                                       ; preds = %label_2786, %label_2784
  %38 = load ptr, ptr %stmt2.1039, align 8
  %39 = getelementptr inbounds nuw %ASTNode, ptr %38, i32 0, i32 8
  %40 = load ptr, ptr %39, align 8
  store ptr %40, ptr %global_ptr.1038, align 8
  br label %label_2783

label_2786:                                       ; preds = %label_2784
  %41 = load ptr, ptr %module.1035, align 8
  %42 = load ptr, ptr %stmt2.1039, align 8
  call void @sema_predeclare_global__Struct_ASTNode_Struct_ASTNode(ptr %41, ptr %42)
  br label %label_2788

label_2789:                                       ; preds = %label_2794, %label_2785
  %43 = load ptr, ptr %stmt_ptr.1040, align 8
  %44 = call i32 @str_equals(ptr %43, ptr @.str.s1006)
  %45 = icmp eq i32 %44, 0
  br i1 %45, label %label_2790, label %label_2791

label_2791:                                       ; preds = %label_2789
  ret void

label_2790:                                       ; preds = %label_2789
  %46 = load ptr, ptr %stmt_ptr.1040, align 8
  %47 = call ptr @ptr_to_node(ptr %46)
  store ptr %47, ptr %stmt3.1041, align 8
  %48 = load ptr, ptr %stmt3.1041, align 8
  %49 = getelementptr inbounds nuw %ASTNode, ptr %48, i32 0, i32 0
  %50 = load i32, ptr %49, align 4
  %51 = icmp eq i32 %50, 4
  br i1 %51, label %label_2792, label %label_2794

label_2794:                                       ; preds = %label_2792, %label_2790
  %52 = load ptr, ptr %stmt3.1041, align 8
  %53 = getelementptr inbounds nuw %ASTNode, ptr %52, i32 0, i32 8
  %54 = load ptr, ptr %53, align 8
  store ptr %54, ptr %stmt_ptr.1040, align 8
  br label %label_2789

label_2792:                                       ; preds = %label_2790
  %55 = load ptr, ptr %module.1035, align 8
  %56 = load ptr, ptr %stmt3.1041, align 8
  call void @sema_function__Struct_ASTNode_Struct_ASTNode(ptr %55, ptr %56)
  br label %label_2794
}

define i1 @is_named_top_level__Struct_ASTNode(ptr %0) {
entry:
  %stmt.1042 = alloca ptr, align 8
  store ptr %0, ptr %stmt.1042, align 8
  %1 = load ptr, ptr %stmt.1042, align 8
  %2 = getelementptr inbounds nuw %ASTNode, ptr %1, i32 0, i32 0
  %3 = load i32, ptr %2, align 4
  %4 = icmp eq i32 %3, 2
  br i1 %4, label %label_2795, label %label_2797

label_2797:                                       ; preds = %entry
  %5 = load ptr, ptr %stmt.1042, align 8
  %6 = getelementptr inbounds nuw %ASTNode, ptr %5, i32 0, i32 0
  %7 = load i32, ptr %6, align 4
  %8 = icmp eq i32 %7, 3
  br i1 %8, label %label_2798, label %label_2800

label_2795:                                       ; preds = %entry
  ret i1 true

label_2800:                                       ; preds = %label_2797
  %9 = load ptr, ptr %stmt.1042, align 8
  %10 = getelementptr inbounds nuw %ASTNode, ptr %9, i32 0, i32 0
  %11 = load i32, ptr %10, align 4
  %12 = icmp eq i32 %11, 4
  br i1 %12, label %label_2801, label %label_2803

label_2798:                                       ; preds = %label_2797
  ret i1 true

label_2803:                                       ; preds = %label_2800
  %13 = load ptr, ptr %stmt.1042, align 8
  %14 = getelementptr inbounds nuw %ASTNode, ptr %13, i32 0, i32 0
  %15 = load i32, ptr %14, align 4
  %16 = icmp eq i32 %15, 5
  br i1 %16, label %label_2804, label %label_2806

label_2801:                                       ; preds = %label_2800
  ret i1 true

label_2806:                                       ; preds = %label_2803
  %17 = load ptr, ptr %stmt.1042, align 8
  %18 = getelementptr inbounds nuw %ASTNode, ptr %17, i32 0, i32 0
  %19 = load i32, ptr %18, align 4
  %20 = icmp eq i32 %19, 6
  br i1 %20, label %label_2807, label %label_2809

label_2804:                                       ; preds = %label_2803
  ret i1 true

label_2809:                                       ; preds = %label_2806
  ret i1 false

label_2807:                                       ; preds = %label_2806
  ret i1 true
}

define i1 @same_top_level_name__Struct_ASTNode_Struct_ASTNode(ptr %0, ptr %1) {
entry:
  %a.1043 = alloca ptr, align 8
  store ptr %0, ptr %a.1043, align 8
  %b.1044 = alloca ptr, align 8
  store ptr %1, ptr %b.1044, align 8
  %2 = load ptr, ptr %a.1043, align 8
  %3 = getelementptr inbounds nuw %ASTNode, ptr %2, i32 0, i32 0
  %4 = load i32, ptr %3, align 4
  %5 = load ptr, ptr %b.1044, align 8
  %6 = getelementptr inbounds nuw %ASTNode, ptr %5, i32 0, i32 0
  %7 = load i32, ptr %6, align 4
  %8 = icmp ne i32 %4, %7
  br i1 %8, label %label_2810, label %label_2812

label_2812:                                       ; preds = %entry
  %9 = load ptr, ptr %a.1043, align 8
  %10 = getelementptr inbounds nuw %ASTNode, ptr %9, i32 0, i32 1
  %11 = load ptr, ptr %10, align 8
  %12 = load ptr, ptr %b.1044, align 8
  %13 = getelementptr inbounds nuw %ASTNode, ptr %12, i32 0, i32 1
  %14 = load ptr, ptr %13, align 8
  %15 = call i32 @str_equals(ptr %11, ptr %14)
  %16 = icmp eq i32 %15, 0
  br i1 %16, label %label_2813, label %label_2815

label_2810:                                       ; preds = %entry
  ret i1 false

label_2815:                                       ; preds = %label_2812
  %17 = load ptr, ptr %a.1043, align 8
  %18 = getelementptr inbounds nuw %ASTNode, ptr %17, i32 0, i32 0
  %19 = load i32, ptr %18, align 4
  %20 = icmp eq i32 %19, 4
  br i1 %20, label %label_2816, label %label_2818

label_2813:                                       ; preds = %label_2812
  ret i1 false

label_2818:                                       ; preds = %label_2815
  ret i1 true

label_2816:                                       ; preds = %label_2815
  ret i1 false
}

define i1 @has_named_top_level__Struct_ASTNode_Struct_ASTNode(ptr %0, ptr %1) {
entry:
  %module.1045 = alloca ptr, align 8
  store ptr %0, ptr %module.1045, align 8
  %stmt.1046 = alloca ptr, align 8
  store ptr %1, ptr %stmt.1046, align 8
  %2 = load ptr, ptr %stmt.1046, align 8
  %3 = call i1 @is_named_top_level__Struct_ASTNode(ptr %2)
  %4 = icmp eq i1 %3, false
  %scan_ptr.1047 = alloca ptr, align 8
  %scan.1048 = alloca ptr, align 8
  br i1 %4, label %label_2819, label %label_2821

label_2821:                                       ; preds = %entry
  %5 = load ptr, ptr %module.1045, align 8
  %6 = getelementptr inbounds nuw %ASTNode, ptr %5, i32 0, i32 5
  %7 = load ptr, ptr %6, align 8
  store ptr %7, ptr %scan_ptr.1047, align 8
  br label %label_2822

label_2819:                                       ; preds = %entry
  ret i1 false

label_2822:                                       ; preds = %label_2827, %label_2821
  %8 = load ptr, ptr %scan_ptr.1047, align 8
  %9 = call i32 @str_equals(ptr %8, ptr @.str.s1008)
  %10 = icmp eq i32 %9, 0
  br i1 %10, label %label_2823, label %label_2824

label_2824:                                       ; preds = %label_2822
  ret i1 false

label_2823:                                       ; preds = %label_2822
  %11 = load ptr, ptr %scan_ptr.1047, align 8
  %12 = call ptr @ptr_to_node(ptr %11)
  store ptr %12, ptr %scan.1048, align 8
  %13 = load ptr, ptr %scan.1048, align 8
  %14 = load ptr, ptr %stmt.1046, align 8
  %15 = call i1 @same_top_level_name__Struct_ASTNode_Struct_ASTNode(ptr %13, ptr %14)
  br i1 %15, label %label_2825, label %label_2827

label_2827:                                       ; preds = %label_2823
  %16 = load ptr, ptr %scan.1048, align 8
  %17 = getelementptr inbounds nuw %ASTNode, ptr %16, i32 0, i32 8
  %18 = load ptr, ptr %17, align 8
  store ptr %18, ptr %scan_ptr.1047, align 8
  br label %label_2822

label_2825:                                       ; preds = %label_2823
  ret i1 true
}

define ptr @parse_source__String(ptr %0) {
entry:
  %content.1049 = alloca ptr, align 8
  store ptr %0, ptr %content.1049, align 8
  %1 = load ptr, ptr %content.1049, align 8
  %2 = call ptr @create_lexer__String(ptr %1)
  %lex.1050 = alloca ptr, align 8
  store ptr %2, ptr %lex.1050, align 8
  %3 = load ptr, ptr %lex.1050, align 8
  %4 = call ptr @lex_all_tokens__Struct_Lexer(ptr %3)
  %head_token.1051 = alloca ptr, align 8
  store ptr %4, ptr %head_token.1051, align 8
  %5 = load ptr, ptr %head_token.1051, align 8
  %6 = call ptr @parser_create__Struct_Token(ptr %5)
  %p.1052 = alloca ptr, align 8
  store ptr %6, ptr %p.1052, align 8
  %7 = load ptr, ptr %p.1052, align 8
  %8 = call ptr @parse_module__Struct_Parser(ptr %7)
  ret ptr %8
}

define void @append_statement__Struct_ASTNode_Struct_ASTNode(ptr %0, ptr %1) {
entry:
  %module.1053 = alloca ptr, align 8
  store ptr %0, ptr %module.1053, align 8
  %stmt.1054 = alloca ptr, align 8
  store ptr %1, ptr %stmt.1054, align 8
  %2 = load ptr, ptr %module.1053, align 8
  %3 = load ptr, ptr %stmt.1054, align 8
  %4 = call i1 @has_named_top_level__Struct_ASTNode_Struct_ASTNode(ptr %2, ptr %3)
  %tail_ptr.1055 = alloca ptr, align 8
  %searching.1056 = alloca i1, align 1
  %tail.1057 = alloca ptr, align 8
  br i1 %4, label %label_2828, label %label_2830

label_2830:                                       ; preds = %entry
  %5 = load ptr, ptr %module.1053, align 8
  %6 = getelementptr inbounds nuw %ASTNode, ptr %5, i32 0, i32 5
  %7 = load ptr, ptr %6, align 8
  %8 = call i32 @str_equals(ptr %7, ptr @.str.s1009)
  %9 = icmp eq i32 %8, 1
  br i1 %9, label %label_2831, label %label_2833

label_2828:                                       ; preds = %entry
  ret void

label_2833:                                       ; preds = %label_2830
  %10 = load ptr, ptr %module.1053, align 8
  %11 = getelementptr inbounds nuw %ASTNode, ptr %10, i32 0, i32 5
  %12 = load ptr, ptr %11, align 8
  store ptr %12, ptr %tail_ptr.1055, align 8
  store i1 true, ptr %searching.1056, align 1
  br label %label_2834

label_2831:                                       ; preds = %label_2830
  %13 = load ptr, ptr %module.1053, align 8
  %14 = load ptr, ptr %stmt.1054, align 8
  %15 = call ptr @node_to_ptr(ptr %14)
  %16 = getelementptr inbounds nuw %ASTNode, ptr %13, i32 0, i32 5
  store ptr %15, ptr %16, align 8
  ret void

label_2834:                                       ; preds = %label_2839, %label_2833
  %17 = load i1, ptr %searching.1056, align 1
  br i1 %17, label %label_2835, label %label_2836

label_2836:                                       ; preds = %label_2834
  ret void

label_2835:                                       ; preds = %label_2834
  %18 = load ptr, ptr %tail_ptr.1055, align 8
  %19 = call ptr @ptr_to_node(ptr %18)
  store ptr %19, ptr %tail.1057, align 8
  %20 = load ptr, ptr %tail.1057, align 8
  %21 = getelementptr inbounds nuw %ASTNode, ptr %20, i32 0, i32 8
  %22 = load ptr, ptr %21, align 8
  %23 = call i32 @str_equals(ptr %22, ptr @.str.s1010)
  %24 = icmp eq i32 %23, 1
  br i1 %24, label %label_2837, label %label_2838

label_2838:                                       ; preds = %label_2835
  %25 = load ptr, ptr %tail.1057, align 8
  %26 = getelementptr inbounds nuw %ASTNode, ptr %25, i32 0, i32 8
  %27 = load ptr, ptr %26, align 8
  store ptr %27, ptr %tail_ptr.1055, align 8
  br label %label_2839

label_2837:                                       ; preds = %label_2835
  %28 = load ptr, ptr %tail.1057, align 8
  %29 = load ptr, ptr %stmt.1054, align 8
  %30 = call ptr @node_to_ptr(ptr %29)
  %31 = getelementptr inbounds nuw %ASTNode, ptr %28, i32 0, i32 8
  store ptr %30, ptr %31, align 8
  store i1 false, ptr %searching.1056, align 1
  br label %label_2839

label_2839:                                       ; preds = %label_2838, %label_2837
  br label %label_2834
}

define ptr @join_import_path__String_String(ptr %0, ptr %1) {
entry:
  %base_dir.1058 = alloca ptr, align 8
  store ptr %0, ptr %base_dir.1058, align 8
  %module_name.1059 = alloca ptr, align 8
  store ptr %1, ptr %module_name.1059, align 8
  %2 = load ptr, ptr %module_name.1059, align 8
  %3 = call ptr @str_concat(ptr %2, ptr @.str.s1011)
  %module_file.1060 = alloca ptr, align 8
  store ptr %3, ptr %module_file.1060, align 8
  %4 = load ptr, ptr %base_dir.1058, align 8
  %5 = call i32 @str_equals(ptr %4, ptr @.str.s1012)
  %6 = icmp eq i32 %5, 1
  br i1 %6, label %label_2840, label %label_2842

label_2842:                                       ; preds = %entry
  %7 = load ptr, ptr %base_dir.1058, align 8
  %8 = load ptr, ptr %module_file.1060, align 8
  %9 = call ptr @join_path(ptr %7, ptr %8)
  ret ptr %9

label_2840:                                       ; preds = %entry
  %10 = load ptr, ptr %module_file.1060, align 8
  ret ptr %10
}

define ptr @import_memo_key__String(ptr %0) {
entry:
  %import_path.1061 = alloca ptr, align 8
  store ptr %0, ptr %import_path.1061, align 8
  %1 = load ptr, ptr %import_path.1061, align 8
  %2 = call ptr @str_concat(ptr @.str.s1013, ptr %1)
  %3 = call ptr @str_concat(ptr %2, ptr @.str.s1014)
  ret ptr %3
}

define ptr @merge_module_imports__Struct_ASTNode_Struct_ASTNode_String_String(ptr %0, ptr %1, ptr %2, ptr %3) {
entry:
  %merged.1062 = alloca ptr, align 8
  store ptr %0, ptr %merged.1062, align 8
  %module.1063 = alloca ptr, align 8
  store ptr %1, ptr %module.1063, align 8
  %base_dir.1064 = alloca ptr, align 8
  store ptr %2, ptr %base_dir.1064, align 8
  %visited.1065 = alloca ptr, align 8
  store ptr %3, ptr %visited.1065, align 8
  %4 = load ptr, ptr %visited.1065, align 8
  %seen.1066 = alloca ptr, align 8
  store ptr %4, ptr %seen.1066, align 8
  %5 = load ptr, ptr %module.1063, align 8
  %6 = getelementptr inbounds nuw %ASTNode, ptr %5, i32 0, i32 5
  %7 = load ptr, ptr %6, align 8
  %stmt_ptr.1067 = alloca ptr, align 8
  store ptr %7, ptr %stmt_ptr.1067, align 8
  %stmt.1068 = alloca ptr, align 8
  %next_stmt.1069 = alloca ptr, align 8
  %import_path.1070 = alloca ptr, align 8
  %key.1071 = alloca ptr, align 8
  %import_content.1072 = alloca ptr, align 8
  %imported_module.1073 = alloca ptr, align 8
  br label %label_2843

label_2843:                                       ; preds = %label_2848, %entry
  %8 = load ptr, ptr %stmt_ptr.1067, align 8
  %9 = call i32 @str_equals(ptr %8, ptr @.str.s1015)
  %10 = icmp eq i32 %9, 0
  br i1 %10, label %label_2844, label %label_2845

label_2845:                                       ; preds = %label_2843
  %11 = load ptr, ptr %seen.1066, align 8
  ret ptr %11

label_2844:                                       ; preds = %label_2843
  %12 = load ptr, ptr %stmt_ptr.1067, align 8
  %13 = call ptr @ptr_to_node(ptr %12)
  store ptr %13, ptr %stmt.1068, align 8
  %14 = load ptr, ptr %stmt.1068, align 8
  %15 = getelementptr inbounds nuw %ASTNode, ptr %14, i32 0, i32 8
  %16 = load ptr, ptr %15, align 8
  store ptr %16, ptr %next_stmt.1069, align 8
  %17 = load ptr, ptr %stmt.1068, align 8
  %18 = getelementptr inbounds nuw %ASTNode, ptr %17, i32 0, i32 8
  store ptr @.str.s1016, ptr %18, align 8
  %19 = load ptr, ptr %stmt.1068, align 8
  %20 = getelementptr inbounds nuw %ASTNode, ptr %19, i32 0, i32 0
  %21 = load i32, ptr %20, align 4
  %22 = icmp eq i32 %21, 1
  br i1 %22, label %label_2846, label %label_2847

label_2847:                                       ; preds = %label_2844
  %23 = load ptr, ptr %merged.1062, align 8
  %24 = load ptr, ptr %stmt.1068, align 8
  call void @append_statement__Struct_ASTNode_Struct_ASTNode(ptr %23, ptr %24)
  br label %label_2848

label_2846:                                       ; preds = %label_2844
  %25 = load ptr, ptr %base_dir.1064, align 8
  %26 = load ptr, ptr %stmt.1068, align 8
  %27 = getelementptr inbounds nuw %ASTNode, ptr %26, i32 0, i32 1
  %28 = load ptr, ptr %27, align 8
  %29 = call ptr @join_import_path__String_String(ptr %25, ptr %28)
  store ptr %29, ptr %import_path.1070, align 8
  %30 = load ptr, ptr %import_path.1070, align 8
  %31 = call ptr @import_memo_key__String(ptr %30)
  store ptr %31, ptr %key.1071, align 8
  %32 = load ptr, ptr %seen.1066, align 8
  %33 = load ptr, ptr %key.1071, align 8
  %34 = call i32 @str_contains(ptr %32, ptr %33)
  %35 = icmp eq i32 %34, 0
  br i1 %35, label %label_2849, label %label_2851

label_2851:                                       ; preds = %label_2854, %label_2846
  br label %label_2848

label_2849:                                       ; preds = %label_2846
  %36 = load ptr, ptr %seen.1066, align 8
  %37 = load ptr, ptr %key.1071, align 8
  %38 = call ptr @str_concat(ptr %36, ptr %37)
  store ptr %38, ptr %seen.1066, align 8
  %39 = load ptr, ptr %import_path.1070, align 8
  %40 = call ptr @read_file(ptr %39)
  store ptr %40, ptr %import_content.1072, align 8
  %41 = load ptr, ptr %import_content.1072, align 8
  %42 = call i32 @str_equals(ptr %41, ptr @.str.s1017)
  %43 = icmp eq i32 %42, 1
  br i1 %43, label %label_2852, label %label_2854

label_2854:                                       ; preds = %label_2852, %label_2849
  %44 = load ptr, ptr %import_content.1072, align 8
  %45 = call ptr @parse_source__String(ptr %44)
  store ptr %45, ptr %imported_module.1073, align 8
  %46 = load ptr, ptr %merged.1062, align 8
  %47 = load ptr, ptr %imported_module.1073, align 8
  %48 = load ptr, ptr %base_dir.1064, align 8
  %49 = load ptr, ptr %seen.1066, align 8
  %50 = call ptr @merge_module_imports__Struct_ASTNode_Struct_ASTNode_String_String(ptr %46, ptr %47, ptr %48, ptr %49)
  store ptr %50, ptr %seen.1066, align 8
  br label %label_2851

label_2852:                                       ; preds = %label_2849
  call void @print(ptr @.str.s1018)
  %51 = load ptr, ptr %import_path.1070, align 8
  call void @println(ptr %51)
  call void @exit(i32 1)
  br label %label_2854

label_2848:                                       ; preds = %label_2847, %label_2851
  %52 = load ptr, ptr %next_stmt.1069, align 8
  store ptr %52, ptr %stmt_ptr.1067, align 8
  br label %label_2843
}

define ptr @resolve_imports__Struct_ASTNode_String(ptr %0, ptr %1) {
entry:
  %module.1074 = alloca ptr, align 8
  store ptr %0, ptr %module.1074, align 8
  %base_dir.1075 = alloca ptr, align 8
  store ptr %1, ptr %base_dir.1075, align 8
  %2 = call ptr @create_node__Enum_NodeKind(i32 0)
  %merged.1076 = alloca ptr, align 8
  store ptr %2, ptr %merged.1076, align 8
  %3 = load ptr, ptr %merged.1076, align 8
  %4 = load ptr, ptr %module.1074, align 8
  %5 = load ptr, ptr %base_dir.1075, align 8
  %6 = call ptr @merge_module_imports__Struct_ASTNode_Struct_ASTNode_String_String(ptr %3, ptr %4, ptr %5, ptr @.str.s1019)
  %7 = load ptr, ptr %merged.1076, align 8
  ret ptr %7
}

define void @print_usage__Void() {
entry:
  call void @println(ptr @.str.s1020)
  call void @println(ptr @.str.s1021)
  call void @println(ptr @.str.s1022)
  call void @println(ptr @.str.s1023)
  call void @println(ptr @.str.s1024)
  call void @println(ptr @.str.s1025)
  call void @println(ptr @.str.s1026)
  call void @println(ptr @.str.s1027)
  call void @println(ptr @.str.s1028)
  ret void
}

define void @check_runtime_freshness__Void() {
entry:
  %0 = call ptr @compiler_installed_runtime_hash()
  %installed.1077 = alloca ptr, align 8
  store ptr %0, ptr %installed.1077, align 8
  %1 = load ptr, ptr %installed.1077, align 8
  %2 = call i32 @str_equals(ptr %1, ptr @.str.s1029)
  %3 = icmp eq i32 %2, 1
  %current.1078 = alloca ptr, align 8
  br i1 %3, label %label_2855, label %label_2857

label_2857:                                       ; preds = %entry
  %4 = call ptr @compiler_runtime_source_hash()
  store ptr %4, ptr %current.1078, align 8
  %5 = load ptr, ptr %current.1078, align 8
  %6 = call i32 @str_equals(ptr %5, ptr @.str.s1030)
  %7 = icmp eq i32 %6, 1
  br i1 %7, label %label_2858, label %label_2860

label_2855:                                       ; preds = %entry
  ret void

label_2860:                                       ; preds = %label_2857
  %8 = load ptr, ptr %installed.1077, align 8
  %9 = load ptr, ptr %current.1078, align 8
  %10 = call i32 @str_equals(ptr %8, ptr %9)
  %11 = icmp eq i32 %10, 1
  br i1 %11, label %label_2861, label %label_2863

label_2858:                                       ; preds = %label_2857
  ret void

label_2863:                                       ; preds = %label_2860
  call void @println(ptr @.str.s1031)
  call void @print(ptr @.str.s1032)
  %12 = load ptr, ptr %installed.1077, align 8
  call void @println(ptr %12)
  call void @print(ptr @.str.s1033)
  %13 = load ptr, ptr %current.1078, align 8
  call void @println(ptr %13)
  call void @println(ptr @.str.s1034)
  call void @println(ptr @.str.s1035)
  call void @exit(i32 1)
  ret void

label_2861:                                       ; preds = %label_2860
  ret void
}

define i32 @compile_source__String_String_Bool_Bool(ptr %0, ptr %1, i1 %2, i1 %3) {
entry:
  %path.1079 = alloca ptr, align 8
  store ptr %0, ptr %path.1079, align 8
  %output_file.1080 = alloca ptr, align 8
  store ptr %1, ptr %output_file.1080, align 8
  %run_after_build.1081 = alloca i1, align 1
  store i1 %2, ptr %run_after_build.1081, align 1
  %bootstrap_mode.1082 = alloca i1, align 1
  store i1 %3, ptr %bootstrap_mode.1082, align 1
  %out_file.1083 = alloca ptr, align 8
  store ptr @.str.s1036, ptr %out_file.1083, align 8
  %emit_ir_only.1084 = alloca i1, align 1
  store i1 false, ptr %emit_ir_only.1084, align 1
  %4 = load i1, ptr %bootstrap_mode.1082, align 1
  %5 = icmp eq i1 %4, false
  %content.1085 = alloca ptr, align 8
  %lex.1086 = alloca ptr, align 8
  %head_token.1087 = alloca ptr, align 8
  %p.1088 = alloca ptr, align 8
  %ast_root.1089 = alloca ptr, align 8
  %base_dir.1090 = alloca ptr, align 8
  %merged_ast.1091 = alloca ptr, align 8
  %build_failed.1092 = alloca i32, align 4
  br i1 %5, label %label_2864, label %label_2866

label_2866:                                       ; preds = %label_2864, %entry
  %6 = load ptr, ptr %output_file.1080, align 8
  %7 = call i32 @str_ends_with(ptr %6, ptr @.str.s1037)
  %8 = icmp eq i32 %7, 1
  br i1 %8, label %label_2867, label %label_2868

label_2864:                                       ; preds = %entry
  call void @check_runtime_freshness__Void()
  br label %label_2866

label_2868:                                       ; preds = %label_2866
  %9 = load ptr, ptr %path.1079, align 8
  %10 = call ptr @compiler_temp_ir_path(ptr %9)
  store ptr %10, ptr %out_file.1083, align 8
  br label %label_2869

label_2867:                                       ; preds = %label_2866
  %11 = load ptr, ptr %output_file.1080, align 8
  store ptr %11, ptr %out_file.1083, align 8
  store i1 true, ptr %emit_ir_only.1084, align 1
  br label %label_2869

label_2869:                                       ; preds = %label_2868, %label_2867
  %12 = load ptr, ptr %path.1079, align 8
  %13 = call ptr @read_file(ptr %12)
  store ptr %13, ptr %content.1085, align 8
  %14 = load ptr, ptr %content.1085, align 8
  %15 = call i32 @str_equals(ptr %14, ptr @.str.s1038)
  %16 = icmp eq i32 %15, 1
  br i1 %16, label %label_2870, label %label_2872

label_2872:                                       ; preds = %label_2869
  %17 = load ptr, ptr %content.1085, align 8
  %18 = call ptr @create_lexer__String(ptr %17)
  store ptr %18, ptr %lex.1086, align 8
  %19 = load ptr, ptr %lex.1086, align 8
  %20 = call ptr @lex_all_tokens__Struct_Lexer(ptr %19)
  store ptr %20, ptr %head_token.1087, align 8
  %21 = load ptr, ptr %head_token.1087, align 8
  %22 = call ptr @parser_create__Struct_Token(ptr %21)
  store ptr %22, ptr %p.1088, align 8
  %23 = load ptr, ptr %p.1088, align 8
  %24 = call ptr @parse_module__Struct_Parser(ptr %23)
  store ptr %24, ptr %ast_root.1089, align 8
  %25 = load ptr, ptr %path.1079, align 8
  %26 = call ptr @get_directory(ptr %25)
  store ptr %26, ptr %base_dir.1090, align 8
  %27 = load ptr, ptr %ast_root.1089, align 8
  %28 = load ptr, ptr %base_dir.1090, align 8
  %29 = call ptr @resolve_imports__Struct_ASTNode_String(ptr %27, ptr %28)
  store ptr %29, ptr %merged_ast.1091, align 8
  %30 = load ptr, ptr %merged_ast.1091, align 8
  call void @analyze_module__Struct_ASTNode(ptr %30)
  call void @ir_reset()
  %31 = load ptr, ptr %merged_ast.1091, align 8
  call void @generate_module__Struct_ASTNode(ptr %31)
  %32 = load ptr, ptr %out_file.1083, align 8
  %33 = call i32 @ir_write_file(ptr %32)
  %34 = icmp ne i32 %33, 0
  br i1 %34, label %label_2876, label %label_2878

label_2870:                                       ; preds = %label_2869
  call void @print(ptr @.str.s1039)
  %35 = load ptr, ptr %path.1079, align 8
  call void @println(ptr %35)
  %36 = load i1, ptr %bootstrap_mode.1082, align 1
  br i1 %36, label %label_2873, label %label_2875

label_2875:                                       ; preds = %label_2873, %label_2870
  ret i32 1

label_2873:                                       ; preds = %label_2870
  call void @println(ptr @.str.s1040)
  call void @println(ptr @.str.s1041)
  call void @println(ptr @.str.s1042)
  br label %label_2875

label_2878:                                       ; preds = %label_2872
  %37 = load i1, ptr %emit_ir_only.1084, align 1
  br i1 %37, label %label_2879, label %label_2881

label_2876:                                       ; preds = %label_2872
  call void @println(ptr @.str.s1043)
  ret i32 1

label_2881:                                       ; preds = %label_2878
  store i32 0, ptr %build_failed.1092, align 4
  %38 = load i1, ptr %bootstrap_mode.1082, align 1
  br i1 %38, label %label_2882, label %label_2883

label_2879:                                       ; preds = %label_2878
  call void @print(ptr @.str.s1044)
  %39 = load ptr, ptr %out_file.1083, align 8
  call void @println(ptr %39)
  ret i32 0

label_2883:                                       ; preds = %label_2881
  %40 = load ptr, ptr %out_file.1083, align 8
  %41 = load ptr, ptr %output_file.1080, align 8
  %42 = call i32 @compiler_build_executable(ptr %40, ptr %41)
  store i32 %42, ptr %build_failed.1092, align 4
  br label %label_2884

label_2882:                                       ; preds = %label_2881
  %43 = load ptr, ptr %out_file.1083, align 8
  %44 = load ptr, ptr %output_file.1080, align 8
  %45 = call i32 @compiler_bootstrap_executable(ptr %43, ptr %44)
  store i32 %45, ptr %build_failed.1092, align 4
  br label %label_2884

label_2884:                                       ; preds = %label_2883, %label_2882
  %46 = load i32, ptr %build_failed.1092, align 4
  %47 = icmp ne i32 %46, 0
  br i1 %47, label %label_2885, label %label_2887

label_2887:                                       ; preds = %label_2884
  %48 = load ptr, ptr %out_file.1083, align 8
  %49 = call i32 @delete_file(ptr %48)
  call void @print(ptr @.str.s1046)
  %50 = load ptr, ptr %output_file.1080, align 8
  call void @println(ptr %50)
  %51 = load i1, ptr %run_after_build.1081, align 1
  br i1 %51, label %label_2888, label %label_2890

label_2885:                                       ; preds = %label_2884
  %52 = load ptr, ptr %out_file.1083, align 8
  %53 = call i32 @delete_file(ptr %52)
  call void @println(ptr @.str.s1045)
  ret i32 1

label_2890:                                       ; preds = %label_2893, %label_2887
  ret i32 0

label_2888:                                       ; preds = %label_2887
  %54 = load ptr, ptr %output_file.1080, align 8
  %55 = call i32 @compiler_run_executable(ptr %54)
  %56 = icmp ne i32 %55, 0
  br i1 %56, label %label_2891, label %label_2893

label_2893:                                       ; preds = %label_2888
  br label %label_2890

label_2891:                                       ; preds = %label_2888
  call void @println(ptr @.str.s1047)
  ret i32 1
}

define i32 @main(i32 %0, ptr %1) {
entry:
  store i32 %0, ptr @prismio_argc, align 4
  store ptr %1, ptr @prismio_argv, align 8
  %path.1093 = alloca ptr, align 8
  store ptr @.str.s1048, ptr %path.1093, align 8
  %output_file.1094 = alloca ptr, align 8
  store ptr @.str.s1049, ptr %output_file.1094, align 8
  %command.1095 = alloca ptr, align 8
  store ptr @.str.s1050, ptr %command.1095, align 8
  %run_after_build.1096 = alloca i1, align 1
  store i1 false, ptr %run_after_build.1096, align 1
  %bootstrap_mode.1097 = alloca i1, align 1
  store i1 false, ptr %bootstrap_mode.1097, align 1
  %arg_index.1098 = alloca i32, align 4
  store i32 0, ptr %arg_index.1098, align 4
  %2 = call i32 @cli_arg_count()
  %3 = icmp sle i32 %2, 1
  %first.1099 = alloca ptr, align 8
  %sc.160 = alloca i1, align 1
  %sc.161 = alloca i1, align 1
  %source_hash.1100 = alloca ptr, align 8
  %candidate.1101 = alloca ptr, align 8
  %sc.162 = alloca i1, align 1
  %barg.1102 = alloca ptr, align 8
  %sc.163 = alloca i1, align 1
  %sc.164 = alloca i1, align 1
  %arg.1103 = alloca ptr, align 8
  %sc.165 = alloca i1, align 1
  %level.1104 = alloca i32, align 4
  %sc.166 = alloca i1, align 1
  %sc.167 = alloca i1, align 1
  %sc.168 = alloca i1, align 1
  br i1 %3, label %label_2894, label %label_2896

label_2896:                                       ; preds = %entry
  %4 = call ptr @cli_arg(i32 1)
  store ptr %4, ptr %first.1099, align 8
  %5 = load ptr, ptr %first.1099, align 8
  %6 = call i32 @str_equals(ptr %5, ptr @.str.s1051)
  %7 = icmp eq i32 %6, 1
  store i1 %7, ptr %sc.160, align 1
  br i1 %7, label %label_2898, label %label_2897

label_2894:                                       ; preds = %entry
  call void @print_usage__Void()
  ret i32 1

label_2897:                                       ; preds = %label_2896
  %8 = load ptr, ptr %first.1099, align 8
  %9 = call i32 @str_equals(ptr %8, ptr @.str.s1052)
  %10 = icmp eq i32 %9, 1
  store i1 %10, ptr %sc.160, align 1
  br label %label_2898

label_2898:                                       ; preds = %label_2897, %label_2896
  %11 = load i1, ptr %sc.160, align 1
  br i1 %11, label %label_2899, label %label_2901

label_2901:                                       ; preds = %label_2898
  %12 = load ptr, ptr %first.1099, align 8
  %13 = call i32 @str_equals(ptr %12, ptr @.str.s1053)
  %14 = icmp eq i32 %13, 1
  store i1 %14, ptr %sc.161, align 1
  br i1 %14, label %label_2903, label %label_2902

label_2899:                                       ; preds = %label_2898
  call void @print_usage__Void()
  ret i32 0

label_2902:                                       ; preds = %label_2901
  %15 = load ptr, ptr %first.1099, align 8
  %16 = call i32 @str_equals(ptr %15, ptr @.str.s1054)
  %17 = icmp eq i32 %16, 1
  store i1 %17, ptr %sc.161, align 1
  br label %label_2903

label_2903:                                       ; preds = %label_2902, %label_2901
  %18 = load i1, ptr %sc.161, align 1
  br i1 %18, label %label_2904, label %label_2906

label_2906:                                       ; preds = %label_2903
  %19 = load ptr, ptr %first.1099, align 8
  %20 = call i32 @str_equals(ptr %19, ptr @.str.s1057)
  %21 = icmp eq i32 %20, 1
  br i1 %21, label %label_2907, label %label_2909

label_2904:                                       ; preds = %label_2903
  call void @print(ptr @.str.s1055)
  %22 = load ptr, ptr @PRISMIO_VERSION, align 8
  call void @println(ptr %22)
  call void @print(ptr @.str.s1056)
  %23 = call ptr @ir_llvm_version()
  call void @println(ptr %23)
  ret i32 0

label_2909:                                       ; preds = %label_2906
  %24 = load ptr, ptr %first.1099, align 8
  %25 = call i32 @str_equals(ptr %24, ptr @.str.s1060)
  %26 = icmp eq i32 %25, 1
  br i1 %26, label %label_2913, label %label_2915

label_2907:                                       ; preds = %label_2906
  %27 = call ptr @compiler_runtime_source_hash()
  store ptr %27, ptr %source_hash.1100, align 8
  %28 = load ptr, ptr %source_hash.1100, align 8
  %29 = call i32 @str_equals(ptr %28, ptr @.str.s1058)
  %30 = icmp eq i32 %29, 1
  br i1 %30, label %label_2910, label %label_2912

label_2912:                                       ; preds = %label_2907
  %31 = load ptr, ptr %source_hash.1100, align 8
  call void @println(ptr %31)
  ret i32 0

label_2910:                                       ; preds = %label_2907
  call void @println(ptr @.str.s1059)
  ret i32 1

label_2915:                                       ; preds = %label_2909
  %32 = load ptr, ptr %first.1099, align 8
  %33 = call i32 @str_equals(ptr %32, ptr @.str.s1068)
  %34 = icmp eq i32 %33, 1
  br i1 %34, label %label_2933, label %label_2934

label_2913:                                       ; preds = %label_2909
  store ptr @.str.s1061, ptr %command.1095, align 8
  store i1 true, ptr %bootstrap_mode.1097, align 1
  store i1 false, ptr %run_after_build.1096, align 1
  store ptr @.str.s1062, ptr %path.1093, align 8
  store i32 2, ptr %arg_index.1098, align 4
  %35 = call i32 @cli_arg_count()
  %36 = icmp sgt i32 %35, 2
  br i1 %36, label %label_2916, label %label_2918

label_2918:                                       ; preds = %label_2923, %label_2913
  %37 = load ptr, ptr %path.1093, align 8
  %38 = call ptr @compiler_default_exe_path(ptr %37)
  store ptr %38, ptr %output_file.1094, align 8
  br label %label_2924

label_2916:                                       ; preds = %label_2913
  %39 = call ptr @cli_arg(i32 2)
  store ptr %39, ptr %candidate.1101, align 8
  %40 = load ptr, ptr %candidate.1101, align 8
  %41 = call i32 @str_equals(ptr %40, ptr @.str.s1063)
  %42 = icmp eq i32 %41, 0
  store i1 %42, ptr %sc.162, align 1
  br i1 %42, label %label_2919, label %label_2920

label_2920:                                       ; preds = %label_2919, %label_2916
  %43 = load i1, ptr %sc.162, align 1
  br i1 %43, label %label_2921, label %label_2923

label_2919:                                       ; preds = %label_2916
  %44 = load ptr, ptr %candidate.1101, align 8
  %45 = call i32 @str_equals(ptr %44, ptr @.str.s1064)
  %46 = icmp eq i32 %45, 0
  store i1 %46, ptr %sc.162, align 1
  br label %label_2920

label_2923:                                       ; preds = %label_2921, %label_2920
  br label %label_2918

label_2921:                                       ; preds = %label_2920
  %47 = load ptr, ptr %candidate.1101, align 8
  store ptr %47, ptr %path.1093, align 8
  store i32 3, ptr %arg_index.1098, align 4
  br label %label_2923

label_2924:                                       ; preds = %label_2929, %label_2918
  %48 = load i32, ptr %arg_index.1098, align 4
  %49 = call i32 @cli_arg_count()
  %50 = icmp slt i32 %48, %49
  br i1 %50, label %label_2925, label %label_2926

label_2926:                                       ; preds = %label_2924
  %51 = load ptr, ptr %path.1093, align 8
  %52 = load ptr, ptr %output_file.1094, align 8
  %53 = load i1, ptr %run_after_build.1096, align 1
  %54 = load i1, ptr %bootstrap_mode.1097, align 1
  %55 = call i32 @compile_source__String_String_Bool_Bool(ptr %51, ptr %52, i1 %53, i1 %54)
  ret i32 %55

label_2925:                                       ; preds = %label_2924
  %56 = load i32, ptr %arg_index.1098, align 4
  %57 = call ptr @cli_arg(i32 %56)
  store ptr %57, ptr %barg.1102, align 8
  %58 = load ptr, ptr %barg.1102, align 8
  %59 = call i32 @str_equals(ptr %58, ptr @.str.s1065)
  %60 = icmp eq i32 %59, 1
  br i1 %60, label %label_2927, label %label_2928

label_2928:                                       ; preds = %label_2925
  call void @print(ptr @.str.s1067)
  %61 = load ptr, ptr %barg.1102, align 8
  call void @println(ptr %61)
  call void @print_usage__Void()
  ret i32 1

label_2927:                                       ; preds = %label_2925
  %62 = load i32, ptr %arg_index.1098, align 4
  %63 = add i32 %62, 1
  %64 = call i32 @cli_arg_count()
  %65 = icmp sge i32 %63, %64
  br i1 %65, label %label_2930, label %label_2932

label_2932:                                       ; preds = %label_2927
  %66 = load i32, ptr %arg_index.1098, align 4
  %67 = add i32 %66, 1
  %68 = call ptr @cli_arg(i32 %67)
  store ptr %68, ptr %output_file.1094, align 8
  %69 = load i32, ptr %arg_index.1098, align 4
  %70 = add i32 %69, 2
  store i32 %70, ptr %arg_index.1098, align 4
  br label %label_2929

label_2930:                                       ; preds = %label_2927
  call void @println(ptr @.str.s1066)
  ret i32 1

label_2929:                                       ; preds = %label_2932
  br label %label_2924

label_2934:                                       ; preds = %label_2915
  %71 = load ptr, ptr %first.1099, align 8
  %72 = call i32 @str_equals(ptr %71, ptr @.str.s1074)
  %73 = icmp eq i32 %72, 1
  br i1 %73, label %label_2944, label %label_2945

label_2933:                                       ; preds = %label_2915
  store ptr @.str.s1069, ptr %command.1095, align 8
  store i1 false, ptr %run_after_build.1096, align 1
  store i32 3, ptr %arg_index.1098, align 4
  %74 = call i32 @cli_arg_count()
  %75 = icmp sle i32 %74, 2
  br i1 %75, label %label_2936, label %label_2938

label_2938:                                       ; preds = %label_2933
  %76 = call ptr @cli_arg(i32 2)
  store ptr %76, ptr %path.1093, align 8
  %77 = load ptr, ptr %path.1093, align 8
  %78 = call i32 @str_equals(ptr %77, ptr @.str.s1071)
  %79 = icmp eq i32 %78, 1
  store i1 %79, ptr %sc.163, align 1
  br i1 %79, label %label_2940, label %label_2939

label_2936:                                       ; preds = %label_2933
  call void @println(ptr @.str.s1070)
  call void @print_usage__Void()
  ret i32 1

label_2939:                                       ; preds = %label_2938
  %80 = load ptr, ptr %path.1093, align 8
  %81 = call i32 @str_equals(ptr %80, ptr @.str.s1072)
  %82 = icmp eq i32 %81, 1
  store i1 %82, ptr %sc.163, align 1
  br label %label_2940

label_2940:                                       ; preds = %label_2939, %label_2938
  %83 = load i1, ptr %sc.163, align 1
  br i1 %83, label %label_2941, label %label_2943

label_2943:                                       ; preds = %label_2940
  br label %label_2935

label_2941:                                       ; preds = %label_2940
  call void @println(ptr @.str.s1073)
  ret i32 1

label_2935:                                       ; preds = %label_2946, %label_2943
  %84 = load ptr, ptr %path.1093, align 8
  %85 = call ptr @compiler_default_exe_path(ptr %84)
  store ptr %85, ptr %output_file.1094, align 8
  br label %label_2955

label_2945:                                       ; preds = %label_2934
  store ptr @.str.s1080, ptr %command.1095, align 8
  store i1 false, ptr %run_after_build.1096, align 1
  %86 = load ptr, ptr %first.1099, align 8
  store ptr %86, ptr %path.1093, align 8
  store i32 2, ptr %arg_index.1098, align 4
  br label %label_2946

label_2944:                                       ; preds = %label_2934
  store ptr @.str.s1075, ptr %command.1095, align 8
  store i1 true, ptr %run_after_build.1096, align 1
  store i32 3, ptr %arg_index.1098, align 4
  %87 = call i32 @cli_arg_count()
  %88 = icmp sle i32 %87, 2
  br i1 %88, label %label_2947, label %label_2949

label_2949:                                       ; preds = %label_2944
  %89 = call ptr @cli_arg(i32 2)
  store ptr %89, ptr %path.1093, align 8
  %90 = load ptr, ptr %path.1093, align 8
  %91 = call i32 @str_equals(ptr %90, ptr @.str.s1077)
  %92 = icmp eq i32 %91, 1
  store i1 %92, ptr %sc.164, align 1
  br i1 %92, label %label_2951, label %label_2950

label_2947:                                       ; preds = %label_2944
  call void @println(ptr @.str.s1076)
  call void @print_usage__Void()
  ret i32 1

label_2950:                                       ; preds = %label_2949
  %93 = load ptr, ptr %path.1093, align 8
  %94 = call i32 @str_equals(ptr %93, ptr @.str.s1078)
  %95 = icmp eq i32 %94, 1
  store i1 %95, ptr %sc.164, align 1
  br label %label_2951

label_2951:                                       ; preds = %label_2950, %label_2949
  %96 = load i1, ptr %sc.164, align 1
  br i1 %96, label %label_2952, label %label_2954

label_2954:                                       ; preds = %label_2951
  br label %label_2946

label_2952:                                       ; preds = %label_2951
  call void @println(ptr @.str.s1079)
  ret i32 1

label_2946:                                       ; preds = %label_2945, %label_2954
  br label %label_2935

label_2955:                                       ; preds = %label_2960, %label_2935
  %97 = load i32, ptr %arg_index.1098, align 4
  %98 = call i32 @cli_arg_count()
  %99 = icmp slt i32 %97, %98
  br i1 %99, label %label_2956, label %label_2957

label_2957:                                       ; preds = %label_2955
  %100 = load ptr, ptr %path.1093, align 8
  %101 = load ptr, ptr %output_file.1094, align 8
  %102 = load i1, ptr %run_after_build.1096, align 1
  %103 = load i1, ptr %bootstrap_mode.1097, align 1
  %104 = call i32 @compile_source__String_String_Bool_Bool(ptr %100, ptr %101, i1 %102, i1 %103)
  ret i32 %104

label_2956:                                       ; preds = %label_2955
  %105 = load i32, ptr %arg_index.1098, align 4
  %106 = call ptr @cli_arg(i32 %105)
  store ptr %106, ptr %arg.1103, align 8
  %107 = load ptr, ptr %arg.1103, align 8
  %108 = call i32 @str_equals(ptr %107, ptr @.str.s1081)
  %109 = icmp eq i32 %108, 1
  br i1 %109, label %label_2958, label %label_2959

label_2959:                                       ; preds = %label_2956
  %110 = load ptr, ptr %arg.1103, align 8
  %111 = call i32 @str_starts_with(ptr %110, ptr @.str.s1083)
  %112 = icmp eq i32 %111, 1
  store i1 %112, ptr %sc.165, align 1
  br i1 %112, label %label_2964, label %label_2965

label_2958:                                       ; preds = %label_2956
  %113 = load i32, ptr %arg_index.1098, align 4
  %114 = add i32 %113, 1
  %115 = call i32 @cli_arg_count()
  %116 = icmp sge i32 %114, %115
  br i1 %116, label %label_2961, label %label_2963

label_2963:                                       ; preds = %label_2958
  %117 = load i32, ptr %arg_index.1098, align 4
  %118 = add i32 %117, 1
  %119 = call ptr @cli_arg(i32 %118)
  store ptr %119, ptr %output_file.1094, align 8
  %120 = load i32, ptr %arg_index.1098, align 4
  %121 = add i32 %120, 2
  store i32 %121, ptr %arg_index.1098, align 4
  br label %label_2960

label_2961:                                       ; preds = %label_2958
  call void @println(ptr @.str.s1082)
  ret i32 1

label_2960:                                       ; preds = %label_2968, %label_2963
  br label %label_2955

label_2965:                                       ; preds = %label_2964, %label_2959
  %122 = load i1, ptr %sc.165, align 1
  br i1 %122, label %label_2966, label %label_2967

label_2964:                                       ; preds = %label_2959
  %123 = load ptr, ptr %arg.1103, align 8
  %124 = call i32 @str_length(ptr %123)
  %125 = icmp eq i32 %124, 3
  store i1 %125, ptr %sc.165, align 1
  br label %label_2965

label_2967:                                       ; preds = %label_2965
  %126 = load ptr, ptr %arg.1103, align 8
  %127 = call i32 @str_equals(ptr %126, ptr @.str.s1085)
  %128 = icmp eq i32 %127, 1
  br i1 %128, label %label_2974, label %label_2975

label_2966:                                       ; preds = %label_2965
  %129 = load ptr, ptr %arg.1103, align 8
  %130 = call ptr @str_substring(ptr %129, i32 2, i32 1)
  %131 = call i32 @str_to_int(ptr %130)
  store i32 %131, ptr %level.1104, align 4
  %132 = load i32, ptr %level.1104, align 4
  %133 = icmp slt i32 %132, 0
  store i1 %133, ptr %sc.166, align 1
  br i1 %133, label %label_2970, label %label_2969

label_2969:                                       ; preds = %label_2966
  %134 = load i32, ptr %level.1104, align 4
  %135 = icmp sgt i32 %134, 3
  store i1 %135, ptr %sc.166, align 1
  br label %label_2970

label_2970:                                       ; preds = %label_2969, %label_2966
  %136 = load i1, ptr %sc.166, align 1
  br i1 %136, label %label_2971, label %label_2973

label_2973:                                       ; preds = %label_2970
  %137 = load i32, ptr %level.1104, align 4
  call void @ir_set_opt_level(i32 %137)
  %138 = load i32, ptr %arg_index.1098, align 4
  %139 = add i32 %138, 1
  store i32 %139, ptr %arg_index.1098, align 4
  br label %label_2968

label_2971:                                       ; preds = %label_2970
  call void @print(ptr @.str.s1084)
  %140 = load ptr, ptr %arg.1103, align 8
  call void @println(ptr %140)
  ret i32 1

label_2968:                                       ; preds = %label_2976, %label_2973
  br label %label_2960

label_2975:                                       ; preds = %label_2967
  %141 = load ptr, ptr %arg.1103, align 8
  %142 = call i32 @str_equals(ptr %141, ptr @.str.s1088)
  %143 = icmp eq i32 %142, 1
  store i1 %143, ptr %sc.167, align 1
  br i1 %143, label %label_2984, label %label_2983

label_2974:                                       ; preds = %label_2967
  %144 = load i32, ptr %arg_index.1098, align 4
  %145 = add i32 %144, 1
  %146 = call i32 @cli_arg_count()
  %147 = icmp sge i32 %145, %146
  br i1 %147, label %label_2977, label %label_2979

label_2979:                                       ; preds = %label_2974
  %148 = load i32, ptr %arg_index.1098, align 4
  %149 = add i32 %148, 1
  %150 = call ptr @cli_arg(i32 %149)
  %151 = call i32 @str_equals(ptr %150, ptr @.str.s1087)
  %152 = icmp eq i32 %151, 1
  br i1 %152, label %label_2980, label %label_2982

label_2977:                                       ; preds = %label_2974
  call void @println(ptr @.str.s1086)
  ret i32 1

label_2982:                                       ; preds = %label_2980, %label_2979
  %153 = load i32, ptr %arg_index.1098, align 4
  %154 = add i32 %153, 2
  store i32 %154, ptr %arg_index.1098, align 4
  br label %label_2976

label_2980:                                       ; preds = %label_2979
  call void @ir_set_target_wasm__Bool(i1 true)
  br label %label_2982

label_2976:                                       ; preds = %label_2992, %label_2982
  br label %label_2968

label_2983:                                       ; preds = %label_2975
  %155 = load ptr, ptr %arg.1103, align 8
  %156 = call i32 @str_equals(ptr %155, ptr @.str.s1089)
  %157 = icmp eq i32 %156, 1
  store i1 %157, ptr %sc.167, align 1
  br label %label_2984

label_2984:                                       ; preds = %label_2983, %label_2975
  %158 = load i1, ptr %sc.167, align 1
  br i1 %158, label %label_2985, label %label_2987

label_2987:                                       ; preds = %label_2984
  %159 = load ptr, ptr %command.1095, align 8
  %160 = call i32 @str_equals(ptr %159, ptr @.str.s1091)
  %161 = icmp eq i32 %160, 1
  store i1 %161, ptr %sc.168, align 1
  br i1 %161, label %label_2988, label %label_2989

label_2985:                                       ; preds = %label_2984
  call void @println(ptr @.str.s1090)
  ret i32 1

label_2989:                                       ; preds = %label_2988, %label_2987
  %162 = load i1, ptr %sc.168, align 1
  br i1 %162, label %label_2990, label %label_2991

label_2988:                                       ; preds = %label_2987
  %163 = load i32, ptr %arg_index.1098, align 4
  %164 = icmp eq i32 %163, 2
  store i1 %164, ptr %sc.168, align 1
  br label %label_2989

label_2991:                                       ; preds = %label_2989
  call void @print(ptr @.str.s1092)
  %165 = load ptr, ptr %arg.1103, align 8
  call void @println(ptr %165)
  call void @print_usage__Void()
  ret i32 1

label_2990:                                       ; preds = %label_2989
  %166 = load ptr, ptr %arg.1103, align 8
  store ptr %166, ptr %output_file.1094, align 8
  %167 = load i32, ptr %arg_index.1098, align 4
  %168 = add i32 %167, 1
  store i32 %168, ptr %arg_index.1098, align 4
  br label %label_2992

label_2992:                                       ; preds = %label_2990
  br label %label_2976
}
