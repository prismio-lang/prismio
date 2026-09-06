000000010000dc40 <_benchGraphBfs__Int>:
10000dc40:     	stp	x28, x27, [sp, #-0x60]!
10000dc44:     	stp	x26, x25, [sp, #0x10]
10000dc48:     	stp	x24, x23, [sp, #0x20]
10000dc4c:     	stp	x22, x21, [sp, #0x30]
10000dc50:     	stp	x20, x19, [sp, #0x40]
10000dc54:     	stp	x29, x30, [sp, #0x50]
10000dc58:     	lsl	w8, w0, #7
10000dc5c:     	sub	w22, w8, w0, lsl #3
10000dc60:     	mul	w21, w22, w22
10000dc64:     	bl	0x10001a334 <_rt_arena_hint_push>
10000dc68:     	mov	x0, x21
10000dc6c:     	bl	0x10001c864 <_list_new_with_capacity>
10000dc70:     	mov	x19, x0
10000dc74:     	bl	0x10001a394 <_rt_arena_hint_pop>
10000dc78:     	mov	x0, x19
10000dc7c:     	mov	w1, #0x1                ; =1
10000dc80:     	bl	0x10001c88c <_list_set_elem_inline>
10000dc84:     	bl	0x10001a334 <_rt_arena_hint_push>
10000dc88:     	mov	x0, x21
10000dc8c:     	bl	0x10001c864 <_list_new_with_capacity>
10000dc90:     	mov	x20, x0
10000dc94:     	bl	0x10001a394 <_rt_arena_hint_pop>
10000dc98:     	mov	x0, x20
10000dc9c:     	mov	w1, #0x4                ; =4
10000dca0:     	bl	0x10001c88c <_list_set_elem_inline>
10000dca4:     	cmp	w21, #0x1
10000dca8:     	b.lt	0x10000dd70 <_benchGraphBfs__Int+0x130>
10000dcac:     	ldr	w9, [x19, #0x24]
10000dcb0:     	ldpsw	x8, x10, [x19, #0x8]
10000dcb4:     	sub	x10, x10, x8
10000dcb8:     	cmp	w9, #0x1
10000dcbc:     	ccmp	x10, x21, #0x8, eq
10000dcc0:     	b.lt	0x10000dd24 <_benchGraphBfs__Int+0xe4>
10000dcc4:     	ldr	x9, [x19]
10000dcc8:     	add	w10, w21, w8
10000dccc:     	sub	w10, w10, #0x1
10000dcd0:     	cmp	w10, w8
10000dcd4:     	b.ge	0x10000dd44 <_benchGraphBfs__Int+0x104>
10000dcd8:     	strb	wzr, [x9, w8, sxtw]
10000dcdc:     	add	w8, w8, #0x1
10000dce0:     	subs	w21, w21, #0x1
10000dce4:     	b.ne	0x10000dcd8 <_benchGraphBfs__Int+0x98>
10000dce8:     	b	0x10000dd6c <_benchGraphBfs__Int+0x12c>
10000dcec:     	mov	x0, x19
10000dcf0:     	mov	x1, #0x0                ; =0
10000dcf4:     	mov	w2, #0x1                ; =1
10000dcf8:     	bl	0x10001d3f4 <_list_push_inline_scalar_slow>
10000dcfc:     	subs	w21, w21, #0x1
10000dd00:     	b.ne	0x10000dd24 <_benchGraphBfs__Int+0xe4>
10000dd04:     	b	0x10000dd70 <_benchGraphBfs__Int+0x130>
10000dd08:     	ldr	x9, [x19]
10000dd0c:     	strb	wzr, [x9, x8]
10000dd10:     	ldr	w8, [x19, #0x8]
10000dd14:     	add	w8, w8, #0x1
10000dd18:     	str	w8, [x19, #0x8]
10000dd1c:     	subs	w21, w21, #0x1
10000dd20:     	b.eq	0x10000dd70 <_benchGraphBfs__Int+0x130>
10000dd24:     	ldr	w8, [x19, #0x24]
10000dd28:     	cmp	w8, #0x1
10000dd2c:     	b.ne	0x10000dcec <_benchGraphBfs__Int+0xac>
10000dd30:     	ldp	w8, w9, [x19, #0x8]
10000dd34:     	sxtw	x8, w8
10000dd38:     	cmp	w8, w9
10000dd3c:     	b.lt	0x10000dd08 <_benchGraphBfs__Int+0xc8>
10000dd40:     	b	0x10000dcec <_benchGraphBfs__Int+0xac>
10000dd44:     	add	w10, w8, w21
10000dd48:     	add	w11, w8, #0x1
10000dd4c:     	add	w12, w8, #0x3
10000dd50:     	strb	wzr, [x9, w8, sxtw]
10000dd54:     	strh	wzr, [x9, w11, sxtw]
10000dd58:     	strb	wzr, [x9, w12, sxtw]
10000dd5c:     	add	w8, w8, #0x4
10000dd60:     	subs	w21, w21, #0x4
10000dd64:     	b.ne	0x10000dd48 <_benchGraphBfs__Int+0x108>
10000dd68:     	mov	x8, x10
10000dd6c:     	str	w8, [x19, #0x8]
10000dd70:     	ldr	w8, [x20, #0x24]
10000dd74:     	cmp	w8, #0x4
10000dd78:     	b.ne	0x10000ddc0 <_benchGraphBfs__Int+0x180>
10000dd7c:     	ldp	w8, w9, [x20, #0x8]
10000dd80:     	sxtw	x8, w8
10000dd84:     	cmp	w8, w9
10000dd88:     	b.ge	0x10000ddc0 <_benchGraphBfs__Int+0x180>
10000dd8c:     	ldr	x9, [x20]
10000dd90:     	str	wzr, [x9, x8, lsl #2]
10000dd94:     	ldr	w8, [x20, #0x8]
10000dd98:     	add	w8, w8, #0x1
10000dd9c:     	str	w8, [x20, #0x8]
10000dda0:     	ldr	w8, [x19, #0x24]
10000dda4:     	cmp	w8, #0x1
10000dda8:     	b.eq	0x10000dddc <_benchGraphBfs__Int+0x19c>
10000ddac:     	mov	x0, x19
10000ddb0:     	mov	w1, #0x0                ; =0
10000ddb4:     	mov	w2, #0x1                ; =1
10000ddb8:     	bl	0x10001d290 <_list_set>
10000ddbc:     	b	0x10000ddf4 <_benchGraphBfs__Int+0x1b4>
10000ddc0:     	mov	x0, x20
10000ddc4:     	mov	x1, #0x0                ; =0
10000ddc8:     	mov	w2, #0x4                ; =4
10000ddcc:     	bl	0x10001d3f4 <_list_push_inline_scalar_slow>
10000ddd0:     	ldr	w8, [x19, #0x24]
10000ddd4:     	cmp	w8, #0x1
10000ddd8:     	b.ne	0x10000ddac <_benchGraphBfs__Int+0x16c>
10000dddc:     	ldr	w8, [x19, #0x8]
10000dde0:     	cmp	w8, #0x1
10000dde4:     	b.lt	0x10000ddf4 <_benchGraphBfs__Int+0x1b4>
10000dde8:     	ldr	x8, [x19]
10000ddec:     	mov	w9, #0x1                ; =1
10000ddf0:     	strb	w9, [x8]
10000ddf4:     	ldr	w8, [x20, #0x8]
10000ddf8:     	cmp	w8, #0x1
10000ddfc:     	b.lt	0x10000e198 <_benchGraphBfs__Int+0x558>
10000de00:     	mov	x21, #0x0               ; =0
10000de04:     	mov	w23, #0x0               ; =0
10000de08:     	mov	w25, #0xca07            ; =51719
10000de0c:     	movk	w25, #0x3b9a, lsl #16
10000de10:     	b	0x10000de50 <_benchGraphBfs__Int+0x210>
10000de14:     	add	w1, w27, w22
10000de18:     	mov	x0, x20
10000de1c:     	mov	w2, #0x4                ; =4
10000de20:     	bl	0x10001d3f4 <_list_push_inline_scalar_slow>
10000de24:     	add	x21, x21, #0x1
10000de28:     	add	w8, w27, w23
10000de2c:     	mov	w9, #0x2f99             ; =12185
10000de30:     	movk	w9, #0x44b8, lsl #16
10000de34:     	smull	x9, w8, w9
10000de38:     	asr	x10, x9, #60
10000de3c:     	add	x9, x10, x9, lsr #63
10000de40:     	msub	w23, w9, w25, w8
10000de44:     	ldrsw	x8, [x20, #0x8]
10000de48:     	cmp	x21, x8
10000de4c:     	b.ge	0x10000e190 <_benchGraphBfs__Int+0x550>
10000de50:     	cmp	x21, w8, uxtw
10000de54:     	b.hs	0x10000de80 <_benchGraphBfs__Int+0x240>
10000de58:     	ldr	w9, [x20, #0x24]
10000de5c:     	ldr	x8, [x20]
10000de60:     	cmp	w9, #0x4
10000de64:     	b.ne	0x10000de98 <_benchGraphBfs__Int+0x258>
10000de68:     	ldr	w27, [x8, x21, lsl #2]
10000de6c:     	sdiv	w28, w27, w22
10000de70:     	msub	w26, w28, w22, w27
10000de74:     	cmp	w26, #0x0
10000de78:     	b.gt	0x10000deac <_benchGraphBfs__Int+0x26c>
10000de7c:     	b	0x10000df64 <_benchGraphBfs__Int+0x324>
10000de80:     	mov	w27, #0x0               ; =0
10000de84:     	sdiv	w28, w27, w22
10000de88:     	msub	w26, w28, w22, w27
10000de8c:     	cmp	w26, #0x0
10000de90:     	b.gt	0x10000deac <_benchGraphBfs__Int+0x26c>
10000de94:     	b	0x10000df64 <_benchGraphBfs__Int+0x324>
10000de98:     	ldr	x27, [x8, x21, lsl #3]
10000de9c:     	sdiv	w28, w27, w22
10000dea0:     	msub	w26, w28, w22, w27
10000dea4:     	cmp	w26, #0x0
10000dea8:     	b.le	0x10000df64 <_benchGraphBfs__Int+0x324>
10000deac:     	sub	w24, w27, #0x1
10000deb0:     	ldr	w8, [x19, #0x8]
10000deb4:     	ldr	w9, [x19, #0x24]
10000deb8:     	cmp	w24, w8
10000debc:     	b.hs	0x10000dee0 <_benchGraphBfs__Int+0x2a0>
10000dec0:     	ldr	x10, [x19]
10000dec4:     	cmp	w9, #0x1
10000dec8:     	b.ne	0x10000ded8 <_benchGraphBfs__Int+0x298>
10000decc:     	ldrb	w10, [x10, w24, sxtw]
10000ded0:     	tbz	w10, #0x0, 0x10000dee0 <_benchGraphBfs__Int+0x2a0>
10000ded4:     	b	0x10000df64 <_benchGraphBfs__Int+0x324>
10000ded8:     	ldr	x10, [x10, w24, sxtw #3]
10000dedc:     	tbnz	w10, #0x0, 0x10000df64 <_benchGraphBfs__Int+0x324>
10000dee0:     	cmp	w9, #0x1
10000dee4:     	b.ne	0x10000df10 <_benchGraphBfs__Int+0x2d0>
10000dee8:     	tbnz	w24, #0x1f, 0x10000df00 <_benchGraphBfs__Int+0x2c0>
10000deec:     	cmp	w24, w8
10000def0:     	b.ge	0x10000df00 <_benchGraphBfs__Int+0x2c0>
10000def4:     	ldr	x8, [x19]
10000def8:     	mov	w9, #0x1                ; =1
10000defc:     	strb	w9, [x8, w24, uxtw]
10000df00:     	ldr	w8, [x20, #0x24]
10000df04:     	cmp	w8, #0x4
10000df08:     	b.eq	0x10000df2c <_benchGraphBfs__Int+0x2ec>
10000df0c:     	b	0x10000df54 <_benchGraphBfs__Int+0x314>
10000df10:     	sub	w1, w27, #0x1
10000df14:     	mov	x0, x19
10000df18:     	mov	w2, #0x1                ; =1
10000df1c:     	bl	0x10001d290 <_list_set>
10000df20:     	ldr	w8, [x20, #0x24]
10000df24:     	cmp	w8, #0x4
10000df28:     	b.ne	0x10000df54 <_benchGraphBfs__Int+0x314>
10000df2c:     	ldp	w8, w9, [x20, #0x8]
10000df30:     	sxtw	x8, w8
10000df34:     	cmp	w8, w9
10000df38:     	b.ge	0x10000df54 <_benchGraphBfs__Int+0x314>
10000df3c:     	ldr	x9, [x20]
10000df40:     	str	w24, [x9, x8, lsl #2]
10000df44:     	ldr	w8, [x20, #0x8]
10000df48:     	add	w8, w8, #0x1
10000df4c:     	str	w8, [x20, #0x8]
10000df50:     	b	0x10000df64 <_benchGraphBfs__Int+0x324>
10000df54:     	sub	w1, w27, #0x1
10000df58:     	mov	x0, x20
10000df5c:     	mov	w2, #0x4                ; =4
10000df60:     	bl	0x10001d3f4 <_list_push_inline_scalar_slow>
10000df64:     	add	w8, w26, #0x1
10000df68:     	cmp	w8, w22
10000df6c:     	b.ge	0x10000e028 <_benchGraphBfs__Int+0x3e8>
10000df70:     	add	w24, w27, #0x1
10000df74:     	ldr	w8, [x19, #0x8]
10000df78:     	ldr	w9, [x19, #0x24]
10000df7c:     	cmp	w24, w8
10000df80:     	b.hs	0x10000dfa4 <_benchGraphBfs__Int+0x364>
10000df84:     	ldr	x10, [x19]
10000df88:     	cmp	w9, #0x1
10000df8c:     	b.ne	0x10000df9c <_benchGraphBfs__Int+0x35c>
10000df90:     	ldrb	w10, [x10, w24, sxtw]
10000df94:     	tbz	w10, #0x0, 0x10000dfa4 <_benchGraphBfs__Int+0x364>
10000df98:     	b	0x10000e028 <_benchGraphBfs__Int+0x3e8>
10000df9c:     	ldr	x10, [x10, w24, sxtw #3]
10000dfa0:     	tbnz	w10, #0x0, 0x10000e028 <_benchGraphBfs__Int+0x3e8>
10000dfa4:     	cmp	w9, #0x1
10000dfa8:     	b.ne	0x10000dfd4 <_benchGraphBfs__Int+0x394>
10000dfac:     	tbnz	w24, #0x1f, 0x10000dfc4 <_benchGraphBfs__Int+0x384>
10000dfb0:     	cmp	w24, w8
10000dfb4:     	b.ge	0x10000dfc4 <_benchGraphBfs__Int+0x384>
10000dfb8:     	ldr	x8, [x19]
10000dfbc:     	mov	w9, #0x1                ; =1
10000dfc0:     	strb	w9, [x8, w24, uxtw]
10000dfc4:     	ldr	w8, [x20, #0x24]
10000dfc8:     	cmp	w8, #0x4
10000dfcc:     	b.eq	0x10000dff0 <_benchGraphBfs__Int+0x3b0>
10000dfd0:     	b	0x10000e018 <_benchGraphBfs__Int+0x3d8>
10000dfd4:     	add	w1, w27, #0x1
10000dfd8:     	mov	x0, x19
10000dfdc:     	mov	w2, #0x1                ; =1
10000dfe0:     	bl	0x10001d290 <_list_set>
10000dfe4:     	ldr	w8, [x20, #0x24]
10000dfe8:     	cmp	w8, #0x4
10000dfec:     	b.ne	0x10000e018 <_benchGraphBfs__Int+0x3d8>
10000dff0:     	ldp	w8, w9, [x20, #0x8]
10000dff4:     	sxtw	x8, w8
10000dff8:     	cmp	w8, w9
10000dffc:     	b.ge	0x10000e018 <_benchGraphBfs__Int+0x3d8>
10000e000:     	ldr	x9, [x20]
10000e004:     	str	w24, [x9, x8, lsl #2]
10000e008:     	ldr	w8, [x20, #0x8]
10000e00c:     	add	w8, w8, #0x1
10000e010:     	str	w8, [x20, #0x8]
10000e014:     	b	0x10000e028 <_benchGraphBfs__Int+0x3e8>
10000e018:     	add	w1, w27, #0x1
10000e01c:     	mov	x0, x20
10000e020:     	mov	w2, #0x4                ; =4
10000e024:     	bl	0x10001d3f4 <_list_push_inline_scalar_slow>
10000e028:     	cmp	w28, #0x0
10000e02c:     	b.le	0x10000e0e8 <_benchGraphBfs__Int+0x4a8>
10000e030:     	ldr	w8, [x19, #0x8]
10000e034:     	ldr	w9, [x19, #0x24]
10000e038:     	sub	w24, w27, w22
10000e03c:     	cmp	w24, w8
10000e040:     	b.hs	0x10000e064 <_benchGraphBfs__Int+0x424>
10000e044:     	ldr	x10, [x19]
10000e048:     	cmp	w9, #0x1
10000e04c:     	b.ne	0x10000e05c <_benchGraphBfs__Int+0x41c>
10000e050:     	ldrb	w10, [x10, w24, sxtw]
10000e054:     	tbz	w10, #0x0, 0x10000e064 <_benchGraphBfs__Int+0x424>
10000e058:     	b	0x10000e0e8 <_benchGraphBfs__Int+0x4a8>
10000e05c:     	ldr	x10, [x10, w24, sxtw #3]
10000e060:     	tbnz	w10, #0x0, 0x10000e0e8 <_benchGraphBfs__Int+0x4a8>
10000e064:     	cmp	w9, #0x1
10000e068:     	b.ne	0x10000e094 <_benchGraphBfs__Int+0x454>
10000e06c:     	tbnz	w24, #0x1f, 0x10000e084 <_benchGraphBfs__Int+0x444>
10000e070:     	cmp	w24, w8
10000e074:     	b.ge	0x10000e084 <_benchGraphBfs__Int+0x444>
10000e078:     	ldr	x8, [x19]
10000e07c:     	mov	w9, #0x1                ; =1
10000e080:     	strb	w9, [x8, w24, uxtw]
10000e084:     	ldr	w8, [x20, #0x24]
10000e088:     	cmp	w8, #0x4
10000e08c:     	b.eq	0x10000e0b0 <_benchGraphBfs__Int+0x470>
10000e090:     	b	0x10000e0d8 <_benchGraphBfs__Int+0x498>
10000e094:     	sub	w1, w27, w22
10000e098:     	mov	x0, x19
10000e09c:     	mov	w2, #0x1                ; =1
10000e0a0:     	bl	0x10001d290 <_list_set>
10000e0a4:     	ldr	w8, [x20, #0x24]
10000e0a8:     	cmp	w8, #0x4
10000e0ac:     	b.ne	0x10000e0d8 <_benchGraphBfs__Int+0x498>
10000e0b0:     	ldp	w8, w9, [x20, #0x8]
10000e0b4:     	sxtw	x8, w8
10000e0b8:     	cmp	w8, w9
10000e0bc:     	b.ge	0x10000e0d8 <_benchGraphBfs__Int+0x498>
10000e0c0:     	ldr	x9, [x20]
10000e0c4:     	str	w24, [x9, x8, lsl #2]
10000e0c8:     	ldr	w8, [x20, #0x8]
10000e0cc:     	add	w8, w8, #0x1
10000e0d0:     	str	w8, [x20, #0x8]
10000e0d4:     	b	0x10000e0e8 <_benchGraphBfs__Int+0x4a8>
10000e0d8:     	sub	w1, w27, w22
10000e0dc:     	mov	x0, x20
10000e0e0:     	mov	w2, #0x4                ; =4
10000e0e4:     	bl	0x10001d3f4 <_list_push_inline_scalar_slow>
10000e0e8:     	add	w8, w28, #0x1
10000e0ec:     	cmp	w8, w22
10000e0f0:     	b.ge	0x10000de24 <_benchGraphBfs__Int+0x1e4>
10000e0f4:     	ldr	w8, [x19, #0x8]
10000e0f8:     	ldr	w9, [x19, #0x24]
10000e0fc:     	add	w24, w27, w22
10000e100:     	cmp	w24, w8
10000e104:     	b.hs	0x10000e128 <_benchGraphBfs__Int+0x4e8>
10000e108:     	ldr	x10, [x19]
10000e10c:     	cmp	w9, #0x1
10000e110:     	b.ne	0x10000e120 <_benchGraphBfs__Int+0x4e0>
10000e114:     	ldrb	w10, [x10, w24, sxtw]
10000e118:     	tbnz	w10, #0x0, 0x10000de24 <_benchGraphBfs__Int+0x1e4>
10000e11c:     	b	0x10000e128 <_benchGraphBfs__Int+0x4e8>
10000e120:     	ldr	x10, [x10, w24, sxtw #3]
10000e124:     	tbnz	w10, #0x0, 0x10000de24 <_benchGraphBfs__Int+0x1e4>
10000e128:     	cmp	w9, #0x1
10000e12c:     	b.ne	0x10000e14c <_benchGraphBfs__Int+0x50c>
10000e130:     	tbnz	w24, #0x1f, 0x10000e15c <_benchGraphBfs__Int+0x51c>
10000e134:     	cmp	w24, w8
10000e138:     	b.ge	0x10000e15c <_benchGraphBfs__Int+0x51c>
10000e13c:     	ldr	x8, [x19]
10000e140:     	mov	w9, #0x1                ; =1
10000e144:     	strb	w9, [x8, w24, uxtw]
10000e148:     	b	0x10000e15c <_benchGraphBfs__Int+0x51c>
10000e14c:     	add	w1, w27, w22
10000e150:     	mov	x0, x19
10000e154:     	mov	w2, #0x1                ; =1
10000e158:     	bl	0x10001d290 <_list_set>
10000e15c:     	ldr	w8, [x20, #0x24]
10000e160:     	cmp	w8, #0x4
10000e164:     	b.ne	0x10000de14 <_benchGraphBfs__Int+0x1d4>
10000e168:     	ldp	w8, w9, [x20, #0x8]
10000e16c:     	sxtw	x8, w8
10000e170:     	cmp	w8, w9
10000e174:     	b.ge	0x10000de14 <_benchGraphBfs__Int+0x1d4>
10000e178:     	ldr	x9, [x20]
10000e17c:     	str	w24, [x9, x8, lsl #2]
10000e180:     	ldr	w8, [x20, #0x8]
10000e184:     	add	w8, w8, #0x1
10000e188:     	str	w8, [x20, #0x8]
10000e18c:     	b	0x10000de24 <_benchGraphBfs__Int+0x1e4>
10000e190:     	add	w0, w23, w21
10000e194:     	b	0x10000e19c <_benchGraphBfs__Int+0x55c>
10000e198:     	mov	w0, #0x0                ; =0
10000e19c:     	ldp	x29, x30, [sp, #0x50]
10000e1a0:     	ldp	x20, x19, [sp, #0x40]
10000e1a4:     	ldp	x22, x21, [sp, #0x30]
10000e1a8:     	ldp	x24, x23, [sp, #0x20]
10000e1ac:     	ldp	x26, x25, [sp, #0x10]
10000e1b0:     	ldp	x28, x27, [sp], #0x60
10000e1b4:     	ret

