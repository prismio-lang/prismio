00000001000128dc <_benchLargeBufferCopy__Int>:
1000128dc:     	stp	x26, x25, [sp, #-0x50]!
1000128e0:     	stp	x24, x23, [sp, #0x10]
1000128e4:     	stp	x22, x21, [sp, #0x20]
1000128e8:     	stp	x20, x19, [sp, #0x30]
1000128ec:     	stp	x29, x30, [sp, #0x40]
1000128f0:     	mov	w8, #0xa120             ; =41248
1000128f4:     	movk	w8, #0x7, lsl #16
1000128f8:     	mul	w19, w0, w8
1000128fc:     	bl	0x10001443c <_rt_arena_hint_push>
100012900:     	mov	x0, x19
100012904:     	bl	0x100016840 <_list_new_with_capacity>
100012908:     	mov	x21, x0
10001290c:     	bl	0x10001449c <_rt_arena_hint_pop>
100012910:     	mov	x0, x21
100012914:     	mov	w1, #0x4                ; =4
100012918:     	bl	0x100016868 <_list_set_elem_inline>
10001291c:     	bl	0x10001443c <_rt_arena_hint_push>
100012920:     	mov	x0, x19
100012924:     	bl	0x100016840 <_list_new_with_capacity>
100012928:     	mov	x20, x0
10001292c:     	bl	0x10001449c <_rt_arena_hint_pop>
100012930:     	mov	x0, x20
100012934:     	mov	w1, #0x4                ; =4
100012938:     	bl	0x100016868 <_list_set_elem_inline>
10001293c:     	cmp	w19, #0x1
100012940:     	b.lt	0x100012c20 <_benchLargeBufferCopy__Int+0x344>
100012944:     	mov	x22, #0x0               ; =0
100012948:     	mov	x23, #0xf33             ; =3891
10001294c:     	movk	x23, #0xb051, lsl #16
100012950:     	movk	x23, #0x901, lsl #32
100012954:     	movk	x23, #0x30, lsl #48
100012958:     	mov	w24, #0xffd             ; =4093
10001295c:     	mov	x25, x19
100012960:     	b	0x100012980 <_benchLargeBufferCopy__Int+0xa4>
100012964:     	mov	x0, x20
100012968:     	mov	x1, #0x0                ; =0
10001296c:     	mov	w2, #0x4                ; =4
100012970:     	bl	0x100017394 <_list_push_inline_scalar_slow>
100012974:     	add	x22, x22, #0x1
100012978:     	subs	w25, w25, #0x1
10001297c:     	b.eq	0x100012a08 <_benchLargeBufferCopy__Int+0x12c>
100012980:     	umulh	x8, x22, x23
100012984:     	sub	x9, x22, x8
100012988:     	add	x8, x8, x9, lsr #1
10001298c:     	lsr	x8, x8, #11
100012990:     	msub	x1, x8, x24, x22
100012994:     	ldr	w8, [x21, #0x24]
100012998:     	cmp	w8, #0x4
10001299c:     	b.ne	0x1000129c8 <_benchLargeBufferCopy__Int+0xec>
1000129a0:     	ldp	w8, w9, [x21, #0x8]
1000129a4:     	sxtw	x8, w8
1000129a8:     	cmp	w8, w9
1000129ac:     	b.ge	0x1000129c8 <_benchLargeBufferCopy__Int+0xec>
1000129b0:     	ldr	x9, [x21]
1000129b4:     	str	w1, [x9, x8, lsl #2]
1000129b8:     	ldr	w8, [x21, #0x8]
1000129bc:     	add	w8, w8, #0x1
1000129c0:     	str	w8, [x21, #0x8]
1000129c4:     	b	0x1000129d4 <_benchLargeBufferCopy__Int+0xf8>
1000129c8:     	mov	x0, x21
1000129cc:     	mov	w2, #0x4                ; =4
1000129d0:     	bl	0x100017394 <_list_push_inline_scalar_slow>
1000129d4:     	ldr	w8, [x20, #0x24]
1000129d8:     	cmp	w8, #0x4
1000129dc:     	b.ne	0x100012964 <_benchLargeBufferCopy__Int+0x88>
1000129e0:     	ldp	w8, w9, [x20, #0x8]
1000129e4:     	sxtw	x8, w8
1000129e8:     	cmp	w8, w9
1000129ec:     	b.ge	0x100012964 <_benchLargeBufferCopy__Int+0x88>
1000129f0:     	ldr	x9, [x20]
1000129f4:     	str	wzr, [x9, x8, lsl #2]
1000129f8:     	ldr	w8, [x20, #0x8]
1000129fc:     	add	w8, w8, #0x1
100012a00:     	str	w8, [x20, #0x8]
100012a04:     	b	0x100012974 <_benchLargeBufferCopy__Int+0x98>
100012a08:     	mov	w23, #0x0               ; =0
100012a0c:     	sub	x8, x19, #0x1
100012a10:     	mov	x9, #-0x5555555555555556 ; =-6148914691236517206
100012a14:     	movk	x9, #0xaaab
100012a18:     	umulh	x9, x8, x9
100012a1c:     	lsr	x9, x9, #2
100012a20:     	mov	w10, #0x6               ; =6
100012a24:     	msub	x8, x9, x10, x8
100012a28:     	add	x24, x8, #0x1
100012a2c:     	cmp	x24, #0x6
100012a30:     	csinc	x25, xzr, x8, eq
100012a34:     	sub	x26, x19, x25
100012a38:     	b	0x100012a48 <_benchLargeBufferCopy__Int+0x16c>
100012a3c:     	add	w23, w23, #0x1
100012a40:     	cmp	w23, #0x8
100012a44:     	b.eq	0x100012bb0 <_benchLargeBufferCopy__Int+0x2d4>
100012a48:     	ldr	w8, [x21, #0x24]
100012a4c:     	ldr	w9, [x20, #0x8]
100012a50:     	ldr	w10, [x21, #0x8]
100012a54:     	cmp	w8, #0x4
100012a58:     	ccmp	w19, w9, #0x0, eq
100012a5c:     	ccmp	w19, w10, #0x0, lt
100012a60:     	b.lt	0x100012adc <_benchLargeBufferCopy__Int+0x200>
100012a64:     	mov	x22, #0x0               ; =0
100012a68:     	b	0x100012a84 <_benchLargeBufferCopy__Int+0x1a8>
100012a6c:     	mov	x0, x20
100012a70:     	mov	x1, x22
100012a74:     	bl	0x100017230 <_list_set>
100012a78:     	add	x22, x22, #0x1
100012a7c:     	cmp	x19, x22
100012a80:     	b.eq	0x100012a3c <_benchLargeBufferCopy__Int+0x160>
100012a84:     	ldr	w8, [x21, #0x8]
100012a88:     	cmp	x22, x8
100012a8c:     	b.hs	0x100012aa8 <_benchLargeBufferCopy__Int+0x1cc>
100012a90:     	ldr	w9, [x21, #0x24]
100012a94:     	ldr	x8, [x21]
100012a98:     	cmp	w9, #0x4
100012a9c:     	b.ne	0x100012ab0 <_benchLargeBufferCopy__Int+0x1d4>
100012aa0:     	ldr	w2, [x8, x22, lsl #2]
100012aa4:     	b	0x100012ab8 <_benchLargeBufferCopy__Int+0x1dc>
100012aa8:     	mov	x2, #0x0                ; =0
100012aac:     	b	0x100012ab8 <_benchLargeBufferCopy__Int+0x1dc>
100012ab0:     	lsl	x9, x22, #3
100012ab4:     	ldr	w2, [x8, x9]
100012ab8:     	ldr	w8, [x20, #0x24]
100012abc:     	cmp	w8, #0x4
100012ac0:     	b.ne	0x100012a6c <_benchLargeBufferCopy__Int+0x190>
100012ac4:     	ldrsw	x8, [x20, #0x8]
100012ac8:     	cmp	x22, x8
100012acc:     	b.ge	0x100012a78 <_benchLargeBufferCopy__Int+0x19c>
100012ad0:     	ldr	x8, [x20]
100012ad4:     	str	w2, [x8, x22, lsl #2]
100012ad8:     	b	0x100012a78 <_benchLargeBufferCopy__Int+0x19c>
100012adc:     	mov	x9, #0x0                ; =0
100012ae0:     	mov	w10, #0x18              ; =24
100012ae4:     	ldr	x8, [x21]
100012ae8:     	lsl	x11, x9, #2
100012aec:     	ldr	w12, [x8, x11]
100012af0:     	mov	x8, x10
100012af4:     	ldr	x10, [x20]
100012af8:     	str	w12, [x10, x11]
100012afc:     	ldr	x10, [x21]
100012b00:     	add	x10, x10, x11
100012b04:     	ldr	w10, [x10, #0x4]
100012b08:     	ldr	x12, [x20]
100012b0c:     	add	x12, x12, x11
100012b10:     	str	w10, [x12, #0x4]
100012b14:     	ldr	x10, [x21]
100012b18:     	add	x10, x10, x11
100012b1c:     	ldr	w10, [x10, #0x8]
100012b20:     	ldr	x12, [x20]
100012b24:     	add	x12, x12, x11
100012b28:     	str	w10, [x12, #0x8]
100012b2c:     	ldr	x10, [x21]
100012b30:     	add	x10, x10, x11
100012b34:     	ldr	w10, [x10, #0xc]
100012b38:     	ldr	x12, [x20]
100012b3c:     	add	x12, x12, x11
100012b40:     	str	w10, [x12, #0xc]
100012b44:     	ldr	x10, [x21]
100012b48:     	add	x10, x10, x11
100012b4c:     	ldr	w10, [x10, #0x10]
100012b50:     	ldr	x12, [x20]
100012b54:     	add	x12, x12, x11
100012b58:     	str	w10, [x12, #0x10]
100012b5c:     	ldr	x10, [x21]
100012b60:     	add	x10, x10, x11
100012b64:     	ldr	w10, [x10, #0x14]
100012b68:     	ldr	x12, [x20]
100012b6c:     	add	x11, x12, x11
100012b70:     	str	w10, [x11, #0x14]
100012b74:     	add	x9, x9, #0x6
100012b78:     	add	x10, x8, #0x18
100012b7c:     	cmp	x26, x9
100012b80:     	b.ne	0x100012ae4 <_benchLargeBufferCopy__Int+0x208>
100012b84:     	cmp	x24, #0x6
100012b88:     	b.eq	0x100012a3c <_benchLargeBufferCopy__Int+0x160>
100012b8c:     	mov	x9, x25
100012b90:     	ldr	x10, [x21]
100012b94:     	ldr	w10, [x10, x8]
100012b98:     	ldr	x11, [x20]
100012b9c:     	str	w10, [x11, x8]
100012ba0:     	add	x8, x8, #0x4
100012ba4:     	subs	x9, x9, #0x1
100012ba8:     	b.ne	0x100012b90 <_benchLargeBufferCopy__Int+0x2b4>
100012bac:     	b	0x100012a3c <_benchLargeBufferCopy__Int+0x160>
100012bb0:     	ldr	w9, [x20, #0x24]
100012bb4:     	ldr	w8, [x20, #0x8]
100012bb8:     	cmp	w9, #0x4
100012bbc:     	ccmp	w19, w8, #0x0, eq
100012bc0:     	b.lt	0x100012c28 <_benchLargeBufferCopy__Int+0x34c>
100012bc4:     	cmp	w9, #0x4
100012bc8:     	b.ne	0x100012c78 <_benchLargeBufferCopy__Int+0x39c>
100012bcc:     	mov	x9, #0x0                ; =0
100012bd0:     	mov	w0, #0x0                ; =0
100012bd4:     	mov	w10, #0x2f99            ; =12185
100012bd8:     	movk	w10, #0x44b8, lsl #16
100012bdc:     	mov	w11, #0xca07            ; =51719
100012be0:     	movk	w11, #0x3b9a, lsl #16
100012be4:     	b	0x100012c10 <_benchLargeBufferCopy__Int+0x334>
100012be8:     	ldr	x12, [x20]
100012bec:     	ldr	w12, [x12, x9, lsl #2]
100012bf0:     	add	w12, w12, w0
100012bf4:     	smull	x13, w12, w10
100012bf8:     	asr	x14, x13, #60
100012bfc:     	add	x13, x14, x13, lsr #63
100012c00:     	msub	w0, w13, w11, w12
100012c04:     	add	x9, x9, #0x1
100012c08:     	cmp	x19, x9
100012c0c:     	b.eq	0x100012c60 <_benchLargeBufferCopy__Int+0x384>
100012c10:     	cmp	x9, x8
100012c14:     	b.lo	0x100012be8 <_benchLargeBufferCopy__Int+0x30c>
100012c18:     	mov	w12, #0x0               ; =0
100012c1c:     	b	0x100012bf0 <_benchLargeBufferCopy__Int+0x314>
100012c20:     	mov	w0, #0x0                ; =0
100012c24:     	b	0x100012c60 <_benchLargeBufferCopy__Int+0x384>
100012c28:     	mov	w0, #0x0                ; =0
100012c2c:     	ldr	x8, [x20]
100012c30:     	mov	w9, #0x2f99             ; =12185
100012c34:     	movk	w9, #0x44b8, lsl #16
100012c38:     	mov	w10, #0xca07            ; =51719
100012c3c:     	movk	w10, #0x3b9a, lsl #16
100012c40:     	ldr	w11, [x8], #0x4
100012c44:     	add	w11, w11, w0
100012c48:     	smull	x12, w11, w9
100012c4c:     	asr	x13, x12, #60
100012c50:     	add	x12, x13, x12, lsr #63
100012c54:     	msub	w0, w12, w10, w11
100012c58:     	subs	x19, x19, #0x1
100012c5c:     	b.ne	0x100012c40 <_benchLargeBufferCopy__Int+0x364>
100012c60:     	ldp	x29, x30, [sp, #0x40]
100012c64:     	ldp	x20, x19, [sp, #0x30]
100012c68:     	ldp	x22, x21, [sp, #0x20]
100012c6c:     	ldp	x24, x23, [sp, #0x10]
100012c70:     	ldp	x26, x25, [sp], #0x50
100012c74:     	ret
100012c78:     	mov	x9, #0x0                ; =0
100012c7c:     	mov	w0, #0x0                ; =0
100012c80:     	mov	w10, #0x2f99            ; =12185
100012c84:     	movk	w10, #0x44b8, lsl #16
100012c88:     	mov	w11, #0xca07            ; =51719
100012c8c:     	movk	w11, #0x3b9a, lsl #16
100012c90:     	b	0x100012cbc <_benchLargeBufferCopy__Int+0x3e0>
100012c94:     	ldr	x12, [x20]
100012c98:     	ldr	x12, [x12, x9, lsl #3]
100012c9c:     	add	w12, w12, w0
100012ca0:     	smull	x13, w12, w10
100012ca4:     	asr	x14, x13, #60
100012ca8:     	add	x13, x14, x13, lsr #63
100012cac:     	msub	w0, w13, w11, w12
100012cb0:     	add	x9, x9, #0x1
100012cb4:     	cmp	x19, x9
100012cb8:     	b.eq	0x100012c60 <_benchLargeBufferCopy__Int+0x384>
100012cbc:     	cmp	x9, x8
100012cc0:     	b.lo	0x100012c94 <_benchLargeBufferCopy__Int+0x3b8>
100012cc4:     	mov	w12, #0x0               ; =0
100012cc8:     	b	0x100012c9c <_benchLargeBufferCopy__Int+0x3c0>

