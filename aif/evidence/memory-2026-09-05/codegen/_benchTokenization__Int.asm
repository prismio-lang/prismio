0000000100011ca8 <_benchTokenization__Int>:
100011ca8:     	sub	sp, sp, #0x80
100011cac:     	stp	x28, x27, [sp, #0x20]
100011cb0:     	stp	x26, x25, [sp, #0x30]
100011cb4:     	stp	x24, x23, [sp, #0x40]
100011cb8:     	stp	x22, x21, [sp, #0x50]
100011cbc:     	stp	x20, x19, [sp, #0x60]
100011cc0:     	stp	x29, x30, [sp, #0x70]
100011cc4:     	mov	w8, #0x5dc              ; =1500
100011cc8:     	mul	w19, w0, w8
100011ccc:     	bic	w8, w19, w19, asr #31
100011cd0:     	add	w8, w8, w8, lsl #4
100011cd4:     	lsl	w27, w8, #1
100011cd8:     	mov	x0, x27
100011cdc:     	bl	0x100014f10 <_str_with_capacity>
100011ce0:     	mov	x20, x0
100011ce4:     	cmp	w19, #0x1
100011ce8:     	b.lt	0x100011d64 <_benchTokenization__Int+0xbc>
100011cec:     	mov	w8, #0x0                ; =0
100011cf0:     	mov	w10, #0x0               ; =0
100011cf4:     	cmp	w27, #0x0
100011cf8:     	add	x9, sp, #0x10
100011cfc:     	csel	x9, x9, x20, mi
100011d00:     	mov	w11, #0xffde            ; =65502
100011d04:     	movk	w11, #0x7fff, lsl #16
100011d08:     	adrp	x12, 0x10001a000 <_chan_recv+0x50>
100011d0c:     	ldr	q0, [x12, #0x530]
100011d10:     	adrp	x12, 0x10001a000 <_chan_recv+0x50>
100011d14:     	ldr	q1, [x12, #0x540]
100011d18:     	adrp	x12, 0x10001a000 <_chan_recv+0x50>
100011d1c:     	add	x12, x12, #0x660
100011d20:     	cmp	w10, w11
100011d24:     	b.le	0x100011d30 <_benchTokenization__Int+0x88>
100011d28:     	mov	x13, #0x0               ; =0
100011d2c:     	b	0x100011d40 <_benchTokenization__Int+0x98>
100011d30:     	add	x13, x9, w10, sxtw
100011d34:     	add	w10, w10, #0x20
100011d38:     	stp	q0, q1, [x13]
100011d3c:     	mov	w13, #0x20              ; =32
100011d40:     	ldrb	w14, [x12, x13]
100011d44:     	strb	w14, [x9, w10, sxtw]
100011d48:     	add	w10, w10, #0x1
100011d4c:     	add	x13, x13, #0x1
100011d50:     	cmp	x13, #0x22
100011d54:     	b.ne	0x100011d40 <_benchTokenization__Int+0x98>
100011d58:     	add	w8, w8, #0x1
100011d5c:     	cmp	w19, w8
100011d60:     	b.ne	0x100011d20 <_benchTokenization__Int+0x78>
100011d64:     	ands	w22, w27, #0x7ffffff8
100011d68:     	b.eq	0x100011f0c <_benchTokenization__Int+0x264>
100011d6c:     	mov	w2, #0x0                ; =0
100011d70:     	mov	w23, #0x0               ; =0
100011d74:     	mov	w24, #0x0               ; =0
100011d78:     	sxtw	x21, w27
100011d7c:     	asr	w25, w27, #31
100011d80:     	and	x26, x21, #0x8
100011d84:     	str	x27, [sp, #0x8]
100011d88:     	cmp	w27, #0x0
100011d8c:     	add	x27, sp, #0x10
100011d90:     	csel	x28, x27, x20, mi
100011d94:     	b	0x100011de4 <_benchTokenization__Int+0x13c>
100011d98:     	mov	x19, x8
100011d9c:     	sub	w3, w19, w2
100011da0:     	mov	x0, x20
100011da4:     	mov	x1, x21
100011da8:     	bl	0x100000924 <_strSubstring__String_Int_Int>
100011dac:     	add	w23, w23, #0x1
100011db0:     	and	w8, w1, #0x7fffffff
100011db4:     	madd	w8, w8, w23, w24
100011db8:     	mov	w9, #0x2f99             ; =12185
100011dbc:     	movk	w9, #0x44b8, lsl #16
100011dc0:     	smull	x9, w8, w9
100011dc4:     	asr	x10, x9, #60
100011dc8:     	add	x9, x10, x9, lsr #63
100011dcc:     	mov	w10, #0xca07            ; =51719
100011dd0:     	movk	w10, #0x3b9a, lsl #16
100011dd4:     	msub	w24, w9, w10, w8
100011dd8:     	mov	x2, x19
100011ddc:     	cmp	w19, w22
100011de0:     	b.ge	0x100011f00 <_benchTokenization__Int+0x258>
100011de4:     	str	x20, [sp, #0x10]
100011de8:     	str	w25, [sp, #0x18]
100011dec:     	strb	wzr, [x27, x26]
100011df0:     	cmp	w2, w22
100011df4:     	b.hs	0x100011e24 <_benchTokenization__Int+0x17c>
100011df8:     	ldrb	w8, [x28, w2, uxtw]
100011dfc:     	cmp	w8, #0x20
100011e00:     	mov	w9, #0x1                ; =1
100011e04:     	lsl	x9, x9, x8
100011e08:     	mov	x10, #0x2600            ; =9728
100011e0c:     	movk	x10, #0x1, lsl #32
100011e10:     	and	x9, x9, x10
100011e14:     	ccmp	x9, #0x0, #0x4, ls
100011e18:     	b.eq	0x100011e28 <_benchTokenization__Int+0x180>
100011e1c:     	add	w19, w2, #0x1
100011e20:     	b	0x100011dd8 <_benchTokenization__Int+0x130>
100011e24:     	mov	w8, #0x0                ; =0
100011e28:     	cmp	w8, #0x5f
100011e2c:     	b.eq	0x100011e94 <_benchTokenization__Int+0x1ec>
100011e30:     	and	w9, w8, #0xffffffdf
100011e34:     	sub	w9, w9, #0x41
100011e38:     	cmp	w9, #0x19
100011e3c:     	b.ls	0x100011e94 <_benchTokenization__Int+0x1ec>
100011e40:     	sub	w8, w8, #0x30
100011e44:     	add	w19, w2, #0x1
100011e48:     	cmp	w8, #0x9
100011e4c:     	b.hi	0x100011d9c <_benchTokenization__Int+0xf4>
100011e50:     	cmp	w22, w19
100011e54:     	csel	w8, w22, w19, gt
100011e58:     	csel	w9, w22, w19, hi
100011e5c:     	mov	x19, x2
100011e60:     	add	w19, w19, #0x1
100011e64:     	cmp	w19, w22
100011e68:     	b.ge	0x100011d98 <_benchTokenization__Int+0xf0>
100011e6c:     	str	x20, [sp, #0x10]
100011e70:     	str	w25, [sp, #0x18]
100011e74:     	strb	wzr, [x27, x26]
100011e78:     	cmp	w19, w22
100011e7c:     	b.hs	0x100011ef8 <_benchTokenization__Int+0x250>
100011e80:     	ldrb	w10, [x28, w19, uxtw]
100011e84:     	sub	w10, w10, #0x30
100011e88:     	cmp	w10, #0xa
100011e8c:     	b.lo	0x100011e60 <_benchTokenization__Int+0x1b8>
100011e90:     	b	0x100011d9c <_benchTokenization__Int+0xf4>
100011e94:     	add	w8, w2, #0x1
100011e98:     	cmp	w22, w8
100011e9c:     	csinc	w8, w22, w2, gt
100011ea0:     	mov	x19, x2
100011ea4:     	add	w10, w19, #0x1
100011ea8:     	cmp	w10, w22
100011eac:     	b.ge	0x100011d98 <_benchTokenization__Int+0xf0>
100011eb0:     	mov	w9, #0x0                ; =0
100011eb4:     	str	x20, [sp, #0x10]
100011eb8:     	str	w25, [sp, #0x18]
100011ebc:     	strb	wzr, [x27, x26]
100011ec0:     	cmp	w10, w22
100011ec4:     	b.hs	0x100011ecc <_benchTokenization__Int+0x224>
100011ec8:     	ldrb	w9, [x28, w10, uxtw]
100011ecc:     	add	w19, w19, #0x1
100011ed0:     	cmp	w9, #0x5f
100011ed4:     	b.eq	0x100011ea4 <_benchTokenization__Int+0x1fc>
100011ed8:     	sub	w10, w9, #0x3a
100011edc:     	cmn	w10, #0xb
100011ee0:     	b.hi	0x100011ea4 <_benchTokenization__Int+0x1fc>
100011ee4:     	and	w9, w9, #0xffffffdf
100011ee8:     	sub	w9, w9, #0x5b
100011eec:     	cmn	w9, #0x1b
100011ef0:     	b.hi	0x100011ea4 <_benchTokenization__Int+0x1fc>
100011ef4:     	b	0x100011d9c <_benchTokenization__Int+0xf4>
100011ef8:     	mov	x19, x9
100011efc:     	b	0x100011d9c <_benchTokenization__Int+0xf4>
100011f00:     	add	w21, w23, w24
100011f04:     	ldr	x27, [sp, #0x8]
100011f08:     	b	0x100011f10 <_benchTokenization__Int+0x268>
100011f0c:     	mov	w21, #0x0               ; =0
100011f10:     	cmn	w27, #0x1
100011f14:     	csel	x0, x20, xzr, gt
100011f18:     	bl	0x100014564 <_rt_free>
100011f1c:     	mov	x0, x21
100011f20:     	ldp	x29, x30, [sp, #0x70]
100011f24:     	ldp	x20, x19, [sp, #0x60]
100011f28:     	ldp	x22, x21, [sp, #0x50]
100011f2c:     	ldp	x24, x23, [sp, #0x40]
100011f30:     	ldp	x26, x25, [sp, #0x30]
100011f34:     	ldp	x28, x27, [sp, #0x20]
100011f38:     	add	sp, sp, #0x80
100011f3c:     	ret

