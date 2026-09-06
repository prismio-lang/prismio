0000000100016c54 <_benchTransientAllocation__Int>:
100016c54:     	sub	sp, sp, #0x90
100016c58:     	stp	x28, x27, [sp, #0x30]
100016c5c:     	stp	x26, x25, [sp, #0x40]
100016c60:     	stp	x24, x23, [sp, #0x50]
100016c64:     	stp	x22, x21, [sp, #0x60]
100016c68:     	stp	x20, x19, [sp, #0x70]
100016c6c:     	stp	x29, x30, [sp, #0x80]
100016c70:     	mov	w8, #0xc8               ; =200
100016c74:     	mul	w21, w0, w8
100016c78:     	cmp	w21, #0x1
100016c7c:     	b.lt	0x100016f0c <_benchTransientAllocation__Int+0x2b8>
100016c80:     	mov	w19, #0x0               ; =0
100016c84:     	mov	w22, #0x0               ; =0
100016c88:     	mov	w24, #0x65f1            ; =26097
100016c8c:     	movk	w24, #0x8377, lsl #16
100016c90:     	mov	w25, #0x3e5             ; =997
100016c94:     	dup.4s	v1, w24
100016c98:     	dup.4s	v0, w25
100016c9c:     	stp	q0, q1, [sp, #0x10]
100016ca0:     	adrp	x8, 0x100020000 <_chan_send+0x30>
100016ca4:     	ldr	q0, [x8, #0x660]
100016ca8:     	str	q0, [sp]
100016cac:     	mov	w26, #0x4dd3            ; =19923
100016cb0:     	movk	w26, #0x1062, lsl #16
100016cb4:     	mov	w27, #0xfa0             ; =4000
100016cb8:     	mov	w28, #0x2f99            ; =12185
100016cbc:     	movk	w28, #0x44b8, lsl #16
100016cc0:     	mov	w23, #0xca07            ; =51719
100016cc4:     	movk	w23, #0x3b9a, lsl #16
100016cc8:     	b	0x100016cf8 <_benchTransientAllocation__Int+0xa4>
100016ccc:     	mov	w8, #0x0                ; =0
100016cd0:     	add	w8, w8, w19
100016cd4:     	smull	x9, w8, w28
100016cd8:     	asr	x10, x9, #60
100016cdc:     	add	x9, x10, x9, lsr #63
100016ce0:     	msub	w19, w9, w23, w8
100016ce4:     	mov	x0, x20
100016ce8:     	bl	0x10001da48 <_list_release>
100016cec:     	add	w22, w22, #0x1
100016cf0:     	cmp	w22, w21
100016cf4:     	b.eq	0x100016f10 <_benchTransientAllocation__Int+0x2bc>
100016cf8:     	bl	0x10001c6a0 <_list_new>
100016cfc:     	mov	x20, x0
100016d00:     	mov	w1, #0x4                ; =4
100016d04:     	bl	0x10001c88c <_list_set_elem_inline>
100016d08:     	ldr	w8, [x20, #0x24]
100016d0c:     	cmp	w8, #0x4
100016d10:     	b.ne	0x100016d6c <_benchTransientAllocation__Int+0x118>
100016d14:     	ldpsw	x8, x9, [x20, #0x8]
100016d18:     	sub	x9, x9, x8
100016d1c:     	cmp	x9, #0xf9f
100016d20:     	b.le	0x100016d6c <_benchTransientAllocation__Int+0x118>
100016d24:     	ldr	x9, [x20]
100016d28:     	mov	w10, #0xf061            ; =61537
100016d2c:     	movk	w10, #0x7fff, lsl #16
100016d30:     	cmp	w8, w10
100016d34:     	b.lt	0x100016e04 <_benchTransientAllocation__Int+0x1b0>
100016d38:     	mov	w10, #0x0               ; =0
100016d3c:     	add	w11, w22, w10
100016d40:     	smull	x12, w11, w24
100016d44:     	add	x12, x11, x12, lsr #32
100016d48:     	asr	w13, w12, #9
100016d4c:     	add	w12, w13, w12, lsr #31
100016d50:     	msub	w11, w12, w25, w11
100016d54:     	str	w11, [x9, w8, sxtw #2]
100016d58:     	add	w8, w8, #0x1
100016d5c:     	add	w10, w10, #0x1
100016d60:     	cmp	w10, #0xfa0
100016d64:     	b.ne	0x100016d3c <_benchTransientAllocation__Int+0xe8>
100016d68:     	b	0x100016ed4 <_benchTransientAllocation__Int+0x280>
100016d6c:     	mov	w26, #0x0               ; =0
100016d70:     	b	0x100016d8c <_benchTransientAllocation__Int+0x138>
100016d74:     	mov	x0, x20
100016d78:     	mov	w2, #0x4                ; =4
100016d7c:     	bl	0x10001d3f4 <_list_push_inline_scalar_slow>
100016d80:     	add	w26, w26, #0x1
100016d84:     	cmp	w26, #0xfa0
100016d88:     	b.eq	0x100016de0 <_benchTransientAllocation__Int+0x18c>
100016d8c:     	add	w8, w22, w26
100016d90:     	smull	x9, w8, w24
100016d94:     	add	x9, x8, x9, lsr #32
100016d98:     	asr	w10, w9, #9
100016d9c:     	add	w9, w10, w9, lsr #31
100016da0:     	msub	w1, w9, w25, w8
100016da4:     	ldr	w8, [x20, #0x24]
100016da8:     	cmp	w8, #0x4
100016dac:     	b.ne	0x100016d74 <_benchTransientAllocation__Int+0x120>
100016db0:     	ldp	w8, w9, [x20, #0x8]
100016db4:     	sxtw	x8, w8
100016db8:     	cmp	w8, w9
100016dbc:     	b.ge	0x100016d74 <_benchTransientAllocation__Int+0x120>
100016dc0:     	ldr	x9, [x20]
100016dc4:     	str	w1, [x9, x8, lsl #2]
100016dc8:     	ldr	w8, [x20, #0x8]
100016dcc:     	add	w8, w8, #0x1
100016dd0:     	str	w8, [x20, #0x8]
100016dd4:     	add	w26, w26, #0x1
100016dd8:     	cmp	w26, #0xfa0
100016ddc:     	b.ne	0x100016d8c <_benchTransientAllocation__Int+0x138>
100016de0:     	ldr	w8, [x20, #0x8]
100016de4:     	mov	w26, #0x4dd3            ; =19923
100016de8:     	movk	w26, #0x1062, lsl #16
100016dec:     	umull	x9, w22, w26
100016df0:     	lsr	x9, x9, #40
100016df4:     	msub	w9, w9, w27, w22
100016df8:     	cmp	w9, w8
100016dfc:     	b.hs	0x100016ccc <_benchTransientAllocation__Int+0x78>
100016e00:     	b	0x100016eec <_benchTransientAllocation__Int+0x298>
100016e04:     	dup.4s	v0, w22
100016e08:     	add	w10, w8, #0xfa0
100016e0c:     	movi.4s	v1, #0x4
100016e10:     	add.4s	v1, v0, v1
100016e14:     	movi.4s	v2, #0x8
100016e18:     	add.4s	v2, v0, v2
100016e1c:     	movi.4s	v3, #0xc
100016e20:     	add.4s	v3, v0, v3
100016e24:     	mov	w11, #0xfa0             ; =4000
100016e28:     	ldp	q4, q20, [sp]
100016e2c:     	ldr	q19, [sp, #0x20]
100016e30:     	movi.4s	v21, #0x10
100016e34:     	add.4s	v5, v4, v0
100016e38:     	add.4s	v6, v4, v1
100016e3c:     	add.4s	v7, v4, v2
100016e40:     	add.4s	v16, v4, v3
100016e44:     	smull2.2d	v17, v5, v19
100016e48:     	smull.2d	v18, v5, v19
100016e4c:     	uzp2.4s	v17, v18, v17
100016e50:     	add.4s	v17, v17, v5
100016e54:     	sshr.4s	v18, v17, #0x9
100016e58:     	usra.4s	v18, v17, #0x1f
100016e5c:     	mls.4s	v5, v18, v20
100016e60:     	smull2.2d	v17, v6, v19
100016e64:     	smull.2d	v18, v6, v19
100016e68:     	uzp2.4s	v17, v18, v17
100016e6c:     	add.4s	v17, v17, v6
100016e70:     	sshr.4s	v18, v17, #0x9
100016e74:     	usra.4s	v18, v17, #0x1f
100016e78:     	mls.4s	v6, v18, v20
100016e7c:     	smull2.2d	v17, v7, v19
100016e80:     	smull.2d	v18, v7, v19
100016e84:     	uzp2.4s	v17, v18, v17
100016e88:     	add.4s	v17, v17, v7
100016e8c:     	sshr.4s	v18, v17, #0x9
100016e90:     	usra.4s	v18, v17, #0x1f
100016e94:     	mls.4s	v7, v18, v20
100016e98:     	smull2.2d	v17, v16, v19
100016e9c:     	smull.2d	v18, v16, v19
100016ea0:     	uzp2.4s	v17, v18, v17
100016ea4:     	add.4s	v17, v17, v16
100016ea8:     	sshr.4s	v18, v17, #0x9
100016eac:     	usra.4s	v18, v17, #0x1f
100016eb0:     	mls.4s	v16, v18, v20
100016eb4:     	add	x12, x9, w8, sxtw #2
100016eb8:     	stp	q5, q6, [x12]
100016ebc:     	stp	q7, q16, [x12, #0x20]
100016ec0:     	add.4s	v4, v4, v21
100016ec4:     	add	w8, w8, #0x10
100016ec8:     	subs	w11, w11, #0x10
100016ecc:     	b.ne	0x100016e34 <_benchTransientAllocation__Int+0x1e0>
100016ed0:     	mov	x8, x10
100016ed4:     	str	w8, [x20, #0x8]
100016ed8:     	umull	x9, w22, w26
100016edc:     	lsr	x9, x9, #40
100016ee0:     	msub	w9, w9, w27, w22
100016ee4:     	cmp	w9, w8
100016ee8:     	b.hs	0x100016ccc <_benchTransientAllocation__Int+0x78>
100016eec:     	ldr	w10, [x20, #0x24]
100016ef0:     	ldr	x8, [x20]
100016ef4:     	cmp	w10, #0x4
100016ef8:     	b.ne	0x100016f04 <_benchTransientAllocation__Int+0x2b0>
100016efc:     	ldr	w8, [x8, w9, uxtw #2]
100016f00:     	b	0x100016cd0 <_benchTransientAllocation__Int+0x7c>
100016f04:     	ldr	x8, [x8, w9, uxtw #3]
100016f08:     	b	0x100016cd0 <_benchTransientAllocation__Int+0x7c>
100016f0c:     	mov	w19, #0x0               ; =0
100016f10:     	mov	x0, x19
100016f14:     	ldp	x29, x30, [sp, #0x80]
100016f18:     	ldp	x20, x19, [sp, #0x70]
100016f1c:     	ldp	x22, x21, [sp, #0x60]
100016f20:     	ldp	x24, x23, [sp, #0x50]
100016f24:     	ldp	x26, x25, [sp, #0x40]
100016f28:     	ldp	x28, x27, [sp, #0x30]
100016f2c:     	add	sp, sp, #0x90
100016f30:     	ret

