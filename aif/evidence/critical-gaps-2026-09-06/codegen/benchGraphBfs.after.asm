000000010000dc04 <_benchGraphBfs__Int>:
10000dc04:     	stp	x28, x27, [sp, #-0x60]!
10000dc08:     	stp	x26, x25, [sp, #0x10]
10000dc0c:     	stp	x24, x23, [sp, #0x20]
10000dc10:     	stp	x22, x21, [sp, #0x30]
10000dc14:     	stp	x20, x19, [sp, #0x40]
10000dc18:     	stp	x29, x30, [sp, #0x50]
10000dc1c:     	lsl	w8, w0, #7
10000dc20:     	sub	w22, w8, w0, lsl #3
10000dc24:     	mul	w21, w22, w22
10000dc28:     	bl	0x10001a2c0 <_rt_arena_hint_push>
10000dc2c:     	mov	x0, x21
10000dc30:     	bl	0x10001c7f0 <_list_new_with_capacity>
10000dc34:     	mov	x19, x0
10000dc38:     	bl	0x10001a320 <_rt_arena_hint_pop>
10000dc3c:     	mov	x0, x19
10000dc40:     	mov	w1, #0x1                ; =1
10000dc44:     	bl	0x10001c818 <_list_set_elem_inline>
10000dc48:     	bl	0x10001a2c0 <_rt_arena_hint_push>
10000dc4c:     	mov	x0, x21
10000dc50:     	bl	0x10001c7f0 <_list_new_with_capacity>
10000dc54:     	mov	x20, x0
10000dc58:     	bl	0x10001a320 <_rt_arena_hint_pop>
10000dc5c:     	mov	x0, x20
10000dc60:     	mov	w1, #0x4                ; =4
10000dc64:     	bl	0x10001c818 <_list_set_elem_inline>
10000dc68:     	ldr	w8, [x19, #0x8]
10000dc6c:     	ldr	w9, [x19, #0x24]
10000dc70:     	sub	w23, w21, #0x40
10000dc74:     	mov	w10, #0x3fffffc0        ; =1073741760
10000dc78:     	cmp	w23, w10
10000dc7c:     	ccmp	w8, #0x0, #0x0, lo
10000dc80:     	ccmp	w9, #0x1, #0x0, eq
10000dc84:     	b.eq	0x10000dd80 <_benchGraphBfs__Int+0x17c>
10000dc88:     	cmp	w21, #0x1
10000dc8c:     	b.lt	0x10000dcd8 <_benchGraphBfs__Int+0xd4>
10000dc90:     	sxtw	x9, w21
10000dc94:     	ldr	w10, [x19, #0x24]
10000dc98:     	ldp	w8, w11, [x19, #0x8]
10000dc9c:     	sub	x11, x11, x8
10000dca0:     	cmp	w10, #0x1
10000dca4:     	ccmp	x11, x9, #0x8, eq
10000dca8:     	b.lt	0x10000dd60 <_benchGraphBfs__Int+0x15c>
10000dcac:     	ldr	x10, [x19]
10000dcb0:     	add	x9, x23, #0x40
10000dcb4:     	add	x10, x8, x10
10000dcb8:     	add	x10, x10, #0x1
10000dcbc:     	mov	x11, x9
10000dcc0:     	stur	wzr, [x10, #-0x1]
10000dcc4:     	add	x10, x10, #0x4
10000dcc8:     	subs	x11, x11, #0x4
10000dccc:     	b.ne	0x10000dcc0 <_benchGraphBfs__Int+0xbc>
10000dcd0:     	add	w8, w8, w9
10000dcd4:     	str	w8, [x19, #0x8]
10000dcd8:     	ldr	w8, [x20, #0x24]
10000dcdc:     	cmp	w8, #0x4
10000dce0:     	b.ne	0x10000dd98 <_benchGraphBfs__Int+0x194>
10000dce4:     	ldp	w8, w9, [x20, #0x8]
10000dce8:     	sxtw	x8, w8
10000dcec:     	cmp	w8, w9
10000dcf0:     	b.ge	0x10000dd98 <_benchGraphBfs__Int+0x194>
10000dcf4:     	ldr	x9, [x20]
10000dcf8:     	str	wzr, [x9, x8, lsl #2]
10000dcfc:     	ldr	w8, [x20, #0x8]
10000dd00:     	add	w8, w8, #0x1
10000dd04:     	str	w8, [x20, #0x8]
10000dd08:     	ldr	w8, [x19, #0x24]
10000dd0c:     	cmp	w8, #0x1
10000dd10:     	b.eq	0x10000ddb4 <_benchGraphBfs__Int+0x1b0>
10000dd14:     	mov	x0, x19
10000dd18:     	mov	w1, #0x0                ; =0
10000dd1c:     	mov	w2, #0x1                ; =1
10000dd20:     	bl	0x10001d21c <_list_set>
10000dd24:     	b	0x10000ddcc <_benchGraphBfs__Int+0x1c8>
10000dd28:     	mov	x0, x19
10000dd2c:     	mov	x1, #0x0                ; =0
10000dd30:     	mov	w2, #0x1                ; =1
10000dd34:     	bl	0x10001d380 <_list_push_inline_scalar_slow>
10000dd38:     	subs	w21, w21, #0x1
10000dd3c:     	b.ne	0x10000dd60 <_benchGraphBfs__Int+0x15c>
10000dd40:     	b	0x10000dcd8 <_benchGraphBfs__Int+0xd4>
10000dd44:     	ldr	x9, [x19]
10000dd48:     	strb	wzr, [x9, x8]
10000dd4c:     	ldr	w8, [x19, #0x8]
10000dd50:     	add	w8, w8, #0x1
10000dd54:     	str	w8, [x19, #0x8]
10000dd58:     	subs	w21, w21, #0x1
10000dd5c:     	b.eq	0x10000dcd8 <_benchGraphBfs__Int+0xd4>
10000dd60:     	ldr	w8, [x19, #0x24]
10000dd64:     	cmp	w8, #0x1
10000dd68:     	b.ne	0x10000dd28 <_benchGraphBfs__Int+0x124>
10000dd6c:     	ldp	w8, w9, [x19, #0x8]
10000dd70:     	sxtw	x8, w8
10000dd74:     	cmp	w8, w9
10000dd78:     	b.lt	0x10000dd44 <_benchGraphBfs__Int+0x140>
10000dd7c:     	b	0x10000dd28 <_benchGraphBfs__Int+0x124>
10000dd80:     	ldr	w8, [x19, #0xc]
10000dd84:     	cmp	w8, w21
10000dd88:     	b.ge	0x10000dc90 <_benchGraphBfs__Int+0x8c>
10000dd8c:     	mov	x0, x19
10000dd90:     	bl	0x10001c944 <_list_inline_grow>
10000dd94:     	b	0x10000dd80 <_benchGraphBfs__Int+0x17c>
10000dd98:     	mov	x0, x20
10000dd9c:     	mov	x1, #0x0                ; =0
10000dda0:     	mov	w2, #0x4                ; =4
10000dda4:     	bl	0x10001d380 <_list_push_inline_scalar_slow>
10000dda8:     	ldr	w8, [x19, #0x24]
10000ddac:     	cmp	w8, #0x1
10000ddb0:     	b.ne	0x10000dd14 <_benchGraphBfs__Int+0x110>
10000ddb4:     	ldr	w8, [x19, #0x8]
10000ddb8:     	cmp	w8, #0x1
10000ddbc:     	b.lt	0x10000ddcc <_benchGraphBfs__Int+0x1c8>
10000ddc0:     	ldr	x8, [x19]
10000ddc4:     	mov	w9, #0x1                ; =1
10000ddc8:     	strb	w9, [x8]
10000ddcc:     	ldr	w8, [x20, #0x8]
10000ddd0:     	cmp	w8, #0x1
10000ddd4:     	b.lt	0x10000e170 <_benchGraphBfs__Int+0x56c>
10000ddd8:     	mov	x21, #0x0               ; =0
10000dddc:     	mov	w23, #0x0               ; =0
10000dde0:     	mov	w25, #0xca07            ; =51719
10000dde4:     	movk	w25, #0x3b9a, lsl #16
10000dde8:     	b	0x10000de28 <_benchGraphBfs__Int+0x224>
10000ddec:     	add	w1, w27, w22
10000ddf0:     	mov	x0, x20
10000ddf4:     	mov	w2, #0x4                ; =4
10000ddf8:     	bl	0x10001d380 <_list_push_inline_scalar_slow>
10000ddfc:     	add	x21, x21, #0x1
10000de00:     	add	w8, w27, w23
10000de04:     	mov	w9, #0x2f99             ; =12185
10000de08:     	movk	w9, #0x44b8, lsl #16
10000de0c:     	smull	x9, w8, w9
10000de10:     	asr	x10, x9, #60
10000de14:     	add	x9, x10, x9, lsr #63
10000de18:     	msub	w23, w9, w25, w8
10000de1c:     	ldrsw	x8, [x20, #0x8]
10000de20:     	cmp	x21, x8
10000de24:     	b.ge	0x10000e168 <_benchGraphBfs__Int+0x564>
10000de28:     	cmp	x21, w8, uxtw
10000de2c:     	b.hs	0x10000de58 <_benchGraphBfs__Int+0x254>
10000de30:     	ldr	w9, [x20, #0x24]
10000de34:     	ldr	x8, [x20]
10000de38:     	cmp	w9, #0x4
10000de3c:     	b.ne	0x10000de70 <_benchGraphBfs__Int+0x26c>
10000de40:     	ldr	w27, [x8, x21, lsl #2]
10000de44:     	sdiv	w28, w27, w22
10000de48:     	msub	w26, w28, w22, w27
10000de4c:     	cmp	w26, #0x0
10000de50:     	b.gt	0x10000de84 <_benchGraphBfs__Int+0x280>
10000de54:     	b	0x10000df3c <_benchGraphBfs__Int+0x338>
10000de58:     	mov	w27, #0x0               ; =0
10000de5c:     	sdiv	w28, w27, w22
10000de60:     	msub	w26, w28, w22, w27
10000de64:     	cmp	w26, #0x0
10000de68:     	b.gt	0x10000de84 <_benchGraphBfs__Int+0x280>
10000de6c:     	b	0x10000df3c <_benchGraphBfs__Int+0x338>
10000de70:     	ldr	x27, [x8, x21, lsl #3]
10000de74:     	sdiv	w28, w27, w22
10000de78:     	msub	w26, w28, w22, w27
10000de7c:     	cmp	w26, #0x0
10000de80:     	b.le	0x10000df3c <_benchGraphBfs__Int+0x338>
10000de84:     	sub	w24, w27, #0x1
10000de88:     	ldr	w8, [x19, #0x8]
10000de8c:     	ldr	w9, [x19, #0x24]
10000de90:     	cmp	w24, w8
10000de94:     	b.hs	0x10000deb8 <_benchGraphBfs__Int+0x2b4>
10000de98:     	ldr	x10, [x19]
10000de9c:     	cmp	w9, #0x1
10000dea0:     	b.ne	0x10000deb0 <_benchGraphBfs__Int+0x2ac>
10000dea4:     	ldrb	w10, [x10, w24, sxtw]
10000dea8:     	tbz	w10, #0x0, 0x10000deb8 <_benchGraphBfs__Int+0x2b4>
10000deac:     	b	0x10000df3c <_benchGraphBfs__Int+0x338>
10000deb0:     	ldr	x10, [x10, w24, sxtw #3]
10000deb4:     	tbnz	w10, #0x0, 0x10000df3c <_benchGraphBfs__Int+0x338>
10000deb8:     	cmp	w9, #0x1
10000debc:     	b.ne	0x10000dee8 <_benchGraphBfs__Int+0x2e4>
10000dec0:     	tbnz	w24, #0x1f, 0x10000ded8 <_benchGraphBfs__Int+0x2d4>
10000dec4:     	cmp	w24, w8
10000dec8:     	b.ge	0x10000ded8 <_benchGraphBfs__Int+0x2d4>
10000decc:     	ldr	x8, [x19]
10000ded0:     	mov	w9, #0x1                ; =1
10000ded4:     	strb	w9, [x8, w24, uxtw]
10000ded8:     	ldr	w8, [x20, #0x24]
10000dedc:     	cmp	w8, #0x4
10000dee0:     	b.eq	0x10000df04 <_benchGraphBfs__Int+0x300>
10000dee4:     	b	0x10000df2c <_benchGraphBfs__Int+0x328>
10000dee8:     	sub	w1, w27, #0x1
10000deec:     	mov	x0, x19
10000def0:     	mov	w2, #0x1                ; =1
10000def4:     	bl	0x10001d21c <_list_set>
10000def8:     	ldr	w8, [x20, #0x24]
10000defc:     	cmp	w8, #0x4
10000df00:     	b.ne	0x10000df2c <_benchGraphBfs__Int+0x328>
10000df04:     	ldp	w8, w9, [x20, #0x8]
10000df08:     	sxtw	x8, w8
10000df0c:     	cmp	w8, w9
10000df10:     	b.ge	0x10000df2c <_benchGraphBfs__Int+0x328>
10000df14:     	ldr	x9, [x20]
10000df18:     	str	w24, [x9, x8, lsl #2]
10000df1c:     	ldr	w8, [x20, #0x8]
10000df20:     	add	w8, w8, #0x1
10000df24:     	str	w8, [x20, #0x8]
10000df28:     	b	0x10000df3c <_benchGraphBfs__Int+0x338>
10000df2c:     	sub	w1, w27, #0x1
10000df30:     	mov	x0, x20
10000df34:     	mov	w2, #0x4                ; =4
10000df38:     	bl	0x10001d380 <_list_push_inline_scalar_slow>
10000df3c:     	add	w8, w26, #0x1
10000df40:     	cmp	w8, w22
10000df44:     	b.ge	0x10000e000 <_benchGraphBfs__Int+0x3fc>
10000df48:     	add	w24, w27, #0x1
10000df4c:     	ldr	w8, [x19, #0x8]
10000df50:     	ldr	w9, [x19, #0x24]
10000df54:     	cmp	w24, w8
10000df58:     	b.hs	0x10000df7c <_benchGraphBfs__Int+0x378>
10000df5c:     	ldr	x10, [x19]
10000df60:     	cmp	w9, #0x1
10000df64:     	b.ne	0x10000df74 <_benchGraphBfs__Int+0x370>
10000df68:     	ldrb	w10, [x10, w24, sxtw]
10000df6c:     	tbz	w10, #0x0, 0x10000df7c <_benchGraphBfs__Int+0x378>
10000df70:     	b	0x10000e000 <_benchGraphBfs__Int+0x3fc>
10000df74:     	ldr	x10, [x10, w24, sxtw #3]
10000df78:     	tbnz	w10, #0x0, 0x10000e000 <_benchGraphBfs__Int+0x3fc>
10000df7c:     	cmp	w9, #0x1
10000df80:     	b.ne	0x10000dfac <_benchGraphBfs__Int+0x3a8>
10000df84:     	tbnz	w24, #0x1f, 0x10000df9c <_benchGraphBfs__Int+0x398>
10000df88:     	cmp	w24, w8
10000df8c:     	b.ge	0x10000df9c <_benchGraphBfs__Int+0x398>
10000df90:     	ldr	x8, [x19]
10000df94:     	mov	w9, #0x1                ; =1
10000df98:     	strb	w9, [x8, w24, uxtw]
10000df9c:     	ldr	w8, [x20, #0x24]
10000dfa0:     	cmp	w8, #0x4
10000dfa4:     	b.eq	0x10000dfc8 <_benchGraphBfs__Int+0x3c4>
10000dfa8:     	b	0x10000dff0 <_benchGraphBfs__Int+0x3ec>
10000dfac:     	add	w1, w27, #0x1
10000dfb0:     	mov	x0, x19
10000dfb4:     	mov	w2, #0x1                ; =1
10000dfb8:     	bl	0x10001d21c <_list_set>
10000dfbc:     	ldr	w8, [x20, #0x24]
10000dfc0:     	cmp	w8, #0x4
10000dfc4:     	b.ne	0x10000dff0 <_benchGraphBfs__Int+0x3ec>
10000dfc8:     	ldp	w8, w9, [x20, #0x8]
10000dfcc:     	sxtw	x8, w8
10000dfd0:     	cmp	w8, w9
10000dfd4:     	b.ge	0x10000dff0 <_benchGraphBfs__Int+0x3ec>
10000dfd8:     	ldr	x9, [x20]
10000dfdc:     	str	w24, [x9, x8, lsl #2]
10000dfe0:     	ldr	w8, [x20, #0x8]
10000dfe4:     	add	w8, w8, #0x1
10000dfe8:     	str	w8, [x20, #0x8]
10000dfec:     	b	0x10000e000 <_benchGraphBfs__Int+0x3fc>
10000dff0:     	add	w1, w27, #0x1
10000dff4:     	mov	x0, x20
10000dff8:     	mov	w2, #0x4                ; =4
10000dffc:     	bl	0x10001d380 <_list_push_inline_scalar_slow>
10000e000:     	cmp	w28, #0x0
10000e004:     	b.le	0x10000e0c0 <_benchGraphBfs__Int+0x4bc>
10000e008:     	ldr	w8, [x19, #0x8]
10000e00c:     	ldr	w9, [x19, #0x24]
10000e010:     	sub	w24, w27, w22
10000e014:     	cmp	w24, w8
10000e018:     	b.hs	0x10000e03c <_benchGraphBfs__Int+0x438>
10000e01c:     	ldr	x10, [x19]
10000e020:     	cmp	w9, #0x1
10000e024:     	b.ne	0x10000e034 <_benchGraphBfs__Int+0x430>
10000e028:     	ldrb	w10, [x10, w24, sxtw]
10000e02c:     	tbz	w10, #0x0, 0x10000e03c <_benchGraphBfs__Int+0x438>
10000e030:     	b	0x10000e0c0 <_benchGraphBfs__Int+0x4bc>
10000e034:     	ldr	x10, [x10, w24, sxtw #3]
10000e038:     	tbnz	w10, #0x0, 0x10000e0c0 <_benchGraphBfs__Int+0x4bc>
10000e03c:     	cmp	w9, #0x1
10000e040:     	b.ne	0x10000e06c <_benchGraphBfs__Int+0x468>
10000e044:     	tbnz	w24, #0x1f, 0x10000e05c <_benchGraphBfs__Int+0x458>
10000e048:     	cmp	w24, w8
10000e04c:     	b.ge	0x10000e05c <_benchGraphBfs__Int+0x458>
10000e050:     	ldr	x8, [x19]
10000e054:     	mov	w9, #0x1                ; =1
10000e058:     	strb	w9, [x8, w24, uxtw]
10000e05c:     	ldr	w8, [x20, #0x24]
10000e060:     	cmp	w8, #0x4
10000e064:     	b.eq	0x10000e088 <_benchGraphBfs__Int+0x484>
10000e068:     	b	0x10000e0b0 <_benchGraphBfs__Int+0x4ac>
10000e06c:     	sub	w1, w27, w22
10000e070:     	mov	x0, x19
10000e074:     	mov	w2, #0x1                ; =1
10000e078:     	bl	0x10001d21c <_list_set>
10000e07c:     	ldr	w8, [x20, #0x24]
10000e080:     	cmp	w8, #0x4
10000e084:     	b.ne	0x10000e0b0 <_benchGraphBfs__Int+0x4ac>
10000e088:     	ldp	w8, w9, [x20, #0x8]
10000e08c:     	sxtw	x8, w8
10000e090:     	cmp	w8, w9
10000e094:     	b.ge	0x10000e0b0 <_benchGraphBfs__Int+0x4ac>
10000e098:     	ldr	x9, [x20]
10000e09c:     	str	w24, [x9, x8, lsl #2]
10000e0a0:     	ldr	w8, [x20, #0x8]
10000e0a4:     	add	w8, w8, #0x1
10000e0a8:     	str	w8, [x20, #0x8]
10000e0ac:     	b	0x10000e0c0 <_benchGraphBfs__Int+0x4bc>
10000e0b0:     	sub	w1, w27, w22
10000e0b4:     	mov	x0, x20
10000e0b8:     	mov	w2, #0x4                ; =4
10000e0bc:     	bl	0x10001d380 <_list_push_inline_scalar_slow>
10000e0c0:     	add	w8, w28, #0x1
10000e0c4:     	cmp	w8, w22
10000e0c8:     	b.ge	0x10000ddfc <_benchGraphBfs__Int+0x1f8>
10000e0cc:     	ldr	w8, [x19, #0x8]
10000e0d0:     	ldr	w9, [x19, #0x24]
10000e0d4:     	add	w24, w27, w22
10000e0d8:     	cmp	w24, w8
10000e0dc:     	b.hs	0x10000e100 <_benchGraphBfs__Int+0x4fc>
10000e0e0:     	ldr	x10, [x19]
10000e0e4:     	cmp	w9, #0x1
10000e0e8:     	b.ne	0x10000e0f8 <_benchGraphBfs__Int+0x4f4>
10000e0ec:     	ldrb	w10, [x10, w24, sxtw]
10000e0f0:     	tbnz	w10, #0x0, 0x10000ddfc <_benchGraphBfs__Int+0x1f8>
10000e0f4:     	b	0x10000e100 <_benchGraphBfs__Int+0x4fc>
10000e0f8:     	ldr	x10, [x10, w24, sxtw #3]
10000e0fc:     	tbnz	w10, #0x0, 0x10000ddfc <_benchGraphBfs__Int+0x1f8>
10000e100:     	cmp	w9, #0x1
10000e104:     	b.ne	0x10000e124 <_benchGraphBfs__Int+0x520>
10000e108:     	tbnz	w24, #0x1f, 0x10000e134 <_benchGraphBfs__Int+0x530>
10000e10c:     	cmp	w24, w8
10000e110:     	b.ge	0x10000e134 <_benchGraphBfs__Int+0x530>
10000e114:     	ldr	x8, [x19]
10000e118:     	mov	w9, #0x1                ; =1
10000e11c:     	strb	w9, [x8, w24, uxtw]
10000e120:     	b	0x10000e134 <_benchGraphBfs__Int+0x530>
10000e124:     	add	w1, w27, w22
10000e128:     	mov	x0, x19
10000e12c:     	mov	w2, #0x1                ; =1
10000e130:     	bl	0x10001d21c <_list_set>
10000e134:     	ldr	w8, [x20, #0x24]
10000e138:     	cmp	w8, #0x4
10000e13c:     	b.ne	0x10000ddec <_benchGraphBfs__Int+0x1e8>
10000e140:     	ldp	w8, w9, [x20, #0x8]
10000e144:     	sxtw	x8, w8
10000e148:     	cmp	w8, w9
10000e14c:     	b.ge	0x10000ddec <_benchGraphBfs__Int+0x1e8>
10000e150:     	ldr	x9, [x20]
10000e154:     	str	w24, [x9, x8, lsl #2]
10000e158:     	ldr	w8, [x20, #0x8]
10000e15c:     	add	w8, w8, #0x1
10000e160:     	str	w8, [x20, #0x8]
10000e164:     	b	0x10000ddfc <_benchGraphBfs__Int+0x1f8>
10000e168:     	add	w0, w23, w21
10000e16c:     	b	0x10000e174 <_benchGraphBfs__Int+0x570>
10000e170:     	mov	w0, #0x0                ; =0
10000e174:     	ldp	x29, x30, [sp, #0x50]
10000e178:     	ldp	x20, x19, [sp, #0x40]
10000e17c:     	ldp	x22, x21, [sp, #0x30]
10000e180:     	ldp	x24, x23, [sp, #0x20]
10000e184:     	ldp	x26, x25, [sp, #0x10]
10000e188:     	ldp	x28, x27, [sp], #0x60
10000e18c:     	ret

