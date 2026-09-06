0000000100016b44 <_benchTransientAllocation__Int>:
100016b44:     	sub	sp, sp, #0x90
100016b48:     	stp	x28, x27, [sp, #0x30]
100016b4c:     	stp	x26, x25, [sp, #0x40]
100016b50:     	stp	x24, x23, [sp, #0x50]
100016b54:     	stp	x22, x21, [sp, #0x60]
100016b58:     	stp	x20, x19, [sp, #0x70]
100016b5c:     	stp	x29, x30, [sp, #0x80]
100016b60:     	mov	w8, #0xc8               ; =200
100016b64:     	mul	w21, w0, w8
100016b68:     	cmp	w21, #0x1
100016b6c:     	b.lt	0x100016dfc <_benchTransientAllocation__Int+0x2b8>
100016b70:     	mov	w19, #0x0               ; =0
100016b74:     	mov	w22, #0x0               ; =0
100016b78:     	adrp	x8, 0x100020000 <_chan_recv+0x4>
100016b7c:     	ldr	q1, [x8, #0x5e0]
100016b80:     	mov	w23, #0xfa0             ; =4000
100016b84:     	mov	w24, #0x65f1            ; =26097
100016b88:     	movk	w24, #0x8377, lsl #16
100016b8c:     	dup.4s	v0, w24
100016b90:     	str	q0, [sp, #0x20]
100016b94:     	mov	w25, #0x3e5             ; =997
100016b98:     	dup.4s	v0, w25
100016b9c:     	stp	q1, q0, [sp]
100016ba0:     	mov	w26, #0x4dd3            ; =19923
100016ba4:     	movk	w26, #0x1062, lsl #16
100016ba8:     	mov	w27, #0x2f99            ; =12185
100016bac:     	movk	w27, #0x44b8, lsl #16
100016bb0:     	mov	w28, #0xca07            ; =51719
100016bb4:     	movk	w28, #0x3b9a, lsl #16
100016bb8:     	b	0x100016be8 <_benchTransientAllocation__Int+0xa4>
100016bbc:     	mov	w8, #0x0                ; =0
100016bc0:     	add	w8, w8, w19
100016bc4:     	smull	x9, w8, w27
100016bc8:     	asr	x10, x9, #60
100016bcc:     	add	x9, x10, x9, lsr #63
100016bd0:     	msub	w19, w9, w28, w8
100016bd4:     	mov	x0, x20
100016bd8:     	bl	0x10001d9d4 <_list_release>
100016bdc:     	add	w22, w22, #0x1
100016be0:     	cmp	w22, w21
100016be4:     	b.eq	0x100016e00 <_benchTransientAllocation__Int+0x2bc>
100016be8:     	bl	0x10001c62c <_list_new>
100016bec:     	mov	x20, x0
100016bf0:     	mov	w1, #0x4                ; =4
100016bf4:     	bl	0x10001c818 <_list_set_elem_inline>
100016bf8:     	ldr	w10, [x20, #0x24]
100016bfc:     	ldp	w9, w8, [x20, #0x8]
100016c00:     	cmp	w9, #0x0
100016c04:     	ccmp	w10, #0x4, #0x0, eq
100016c08:     	b.ne	0x100016c1c <_benchTransientAllocation__Int+0xd8>
100016c0c:     	cmp	w8, #0xf9f
100016c10:     	b.le	0x100016d20 <_benchTransientAllocation__Int+0x1dc>
100016c14:     	mov	w9, #0x0                ; =0
100016c18:     	mov	w10, #0x4               ; =4
100016c1c:     	cmp	w10, #0x4
100016c20:     	ldp	q20, q19, [sp, #0x10]
100016c24:     	movi.4s	v21, #0x10
100016c28:     	b.ne	0x100016d4c <_benchTransientAllocation__Int+0x208>
100016c2c:     	mov	w9, w9
100016c30:     	sub	x8, x8, x9
100016c34:     	cmp	x8, #0xf9f
100016c38:     	b.le	0x100016d4c <_benchTransientAllocation__Int+0x208>
100016c3c:     	ldr	x10, [x20]
100016c40:     	add	w8, w9, #0xfa0
100016c44:     	dup.4s	v0, w22
100016c48:     	movi.4s	v1, #0x4
100016c4c:     	add.4s	v1, v0, v1
100016c50:     	movi.4s	v2, #0x8
100016c54:     	add.4s	v2, v0, v2
100016c58:     	movi.4s	v3, #0xc
100016c5c:     	add.4s	v3, v0, v3
100016c60:     	add	x9, x10, x9, lsl #2
100016c64:     	add	x9, x9, #0x20
100016c68:     	mov	w10, #0xfa0             ; =4000
100016c6c:     	ldr	q4, [sp]
100016c70:     	add.4s	v5, v4, v0
100016c74:     	add.4s	v6, v4, v1
100016c78:     	add.4s	v7, v4, v2
100016c7c:     	add.4s	v16, v4, v3
100016c80:     	smull2.2d	v17, v5, v19
100016c84:     	smull.2d	v18, v5, v19
100016c88:     	uzp2.4s	v17, v18, v17
100016c8c:     	add.4s	v17, v17, v5
100016c90:     	sshr.4s	v18, v17, #0x9
100016c94:     	usra.4s	v18, v17, #0x1f
100016c98:     	mls.4s	v5, v18, v20
100016c9c:     	smull2.2d	v17, v6, v19
100016ca0:     	smull.2d	v18, v6, v19
100016ca4:     	uzp2.4s	v17, v18, v17
100016ca8:     	add.4s	v17, v17, v6
100016cac:     	sshr.4s	v18, v17, #0x9
100016cb0:     	usra.4s	v18, v17, #0x1f
100016cb4:     	mls.4s	v6, v18, v20
100016cb8:     	smull2.2d	v17, v7, v19
100016cbc:     	smull.2d	v18, v7, v19
100016cc0:     	uzp2.4s	v17, v18, v17
100016cc4:     	add.4s	v17, v17, v7
100016cc8:     	sshr.4s	v18, v17, #0x9
100016ccc:     	usra.4s	v18, v17, #0x1f
100016cd0:     	mls.4s	v7, v18, v20
100016cd4:     	smull2.2d	v17, v16, v19
100016cd8:     	smull.2d	v18, v16, v19
100016cdc:     	uzp2.4s	v17, v18, v17
100016ce0:     	add.4s	v17, v17, v16
100016ce4:     	sshr.4s	v18, v17, #0x9
100016ce8:     	usra.4s	v18, v17, #0x1f
100016cec:     	mls.4s	v16, v18, v20
100016cf0:     	stp	q5, q6, [x9, #-0x20]
100016cf4:     	stp	q7, q16, [x9], #0x40
100016cf8:     	add.4s	v4, v4, v21
100016cfc:     	subs	x10, x10, #0x10
100016d00:     	b.ne	0x100016c70 <_benchTransientAllocation__Int+0x12c>
100016d04:     	str	w8, [x20, #0x8]
100016d08:     	umull	x9, w22, w26
100016d0c:     	lsr	x9, x9, #40
100016d10:     	msub	w9, w9, w23, w22
100016d14:     	cmp	w9, w8
100016d18:     	b.hs	0x100016bbc <_benchTransientAllocation__Int+0x78>
100016d1c:     	b	0x100016ddc <_benchTransientAllocation__Int+0x298>
100016d20:     	mov	x0, x20
100016d24:     	bl	0x10001c944 <_list_inline_grow>
100016d28:     	ldr	w8, [x20, #0xc]
100016d2c:     	cmp	w8, #0xf9f
100016d30:     	b.le	0x100016d20 <_benchTransientAllocation__Int+0x1dc>
100016d34:     	ldr	w10, [x20, #0x24]
100016d38:     	ldr	w9, [x20, #0x8]
100016d3c:     	cmp	w10, #0x4
100016d40:     	ldp	q20, q19, [sp, #0x10]
100016d44:     	movi.4s	v21, #0x10
100016d48:     	b.eq	0x100016c2c <_benchTransientAllocation__Int+0xe8>
100016d4c:     	mov	w23, #0x0               ; =0
100016d50:     	b	0x100016d6c <_benchTransientAllocation__Int+0x228>
100016d54:     	mov	x0, x20
100016d58:     	mov	w2, #0x4                ; =4
100016d5c:     	bl	0x10001d380 <_list_push_inline_scalar_slow>
100016d60:     	add	w23, w23, #0x1
100016d64:     	cmp	w23, #0xfa0
100016d68:     	b.eq	0x100016dc0 <_benchTransientAllocation__Int+0x27c>
100016d6c:     	add	w8, w22, w23
100016d70:     	smull	x9, w8, w24
100016d74:     	add	x9, x8, x9, lsr #32
100016d78:     	asr	w10, w9, #9
100016d7c:     	add	w9, w10, w9, lsr #31
100016d80:     	msub	w1, w9, w25, w8
100016d84:     	ldr	w8, [x20, #0x24]
100016d88:     	cmp	w8, #0x4
100016d8c:     	b.ne	0x100016d54 <_benchTransientAllocation__Int+0x210>
100016d90:     	ldp	w8, w9, [x20, #0x8]
100016d94:     	sxtw	x8, w8
100016d98:     	cmp	w8, w9
100016d9c:     	b.ge	0x100016d54 <_benchTransientAllocation__Int+0x210>
100016da0:     	ldr	x9, [x20]
100016da4:     	str	w1, [x9, x8, lsl #2]
100016da8:     	ldr	w8, [x20, #0x8]
100016dac:     	add	w8, w8, #0x1
100016db0:     	str	w8, [x20, #0x8]
100016db4:     	add	w23, w23, #0x1
100016db8:     	cmp	w23, #0xfa0
100016dbc:     	b.ne	0x100016d6c <_benchTransientAllocation__Int+0x228>
100016dc0:     	ldr	w8, [x20, #0x8]
100016dc4:     	mov	w23, #0xfa0             ; =4000
100016dc8:     	umull	x9, w22, w26
100016dcc:     	lsr	x9, x9, #40
100016dd0:     	msub	w9, w9, w23, w22
100016dd4:     	cmp	w9, w8
100016dd8:     	b.hs	0x100016bbc <_benchTransientAllocation__Int+0x78>
100016ddc:     	ldr	w10, [x20, #0x24]
100016de0:     	ldr	x8, [x20]
100016de4:     	cmp	w10, #0x4
100016de8:     	b.ne	0x100016df4 <_benchTransientAllocation__Int+0x2b0>
100016dec:     	ldr	w8, [x8, w9, uxtw #2]
100016df0:     	b	0x100016bc0 <_benchTransientAllocation__Int+0x7c>
100016df4:     	ldr	x8, [x8, w9, uxtw #3]
100016df8:     	b	0x100016bc0 <_benchTransientAllocation__Int+0x7c>
100016dfc:     	mov	w19, #0x0               ; =0
100016e00:     	mov	x0, x19
100016e04:     	ldp	x29, x30, [sp, #0x80]
100016e08:     	ldp	x20, x19, [sp, #0x70]
100016e0c:     	ldp	x22, x21, [sp, #0x60]
100016e10:     	ldp	x24, x23, [sp, #0x50]
100016e14:     	ldp	x26, x25, [sp, #0x40]
100016e18:     	ldp	x28, x27, [sp, #0x30]
100016e1c:     	add	sp, sp, #0x90
100016e20:     	ret

