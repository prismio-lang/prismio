0000000100010c24 <_benchKeyValueUpdate__Int>:
100010c24:     	stp	x24, x23, [sp, #-0x40]!
100010c28:     	stp	x22, x21, [sp, #0x10]
100010c2c:     	stp	x20, x19, [sp, #0x20]
100010c30:     	stp	x29, x30, [sp, #0x30]
100010c34:     	mov	w8, #0x4e20             ; =20000
100010c38:     	mul	w22, w0, w8
100010c3c:     	bl	0x10000fed4 <_mapNew$Int$Int__Void>
100010c40:     	mov	x19, x0
100010c44:     	cmp	w22, #0x1
100010c48:     	b.lt	0x100010d50 <_benchKeyValueUpdate__Int+0x12c>
100010c4c:     	mov	w20, #0x0               ; =0
100010c50:     	mov	w21, #0x8657            ; =34391
100010c54:     	movk	w21, #0x446f, lsl #16
100010c58:     	mov	w23, #-0x65             ; =-101
100010c5c:     	umull	x8, w20, w21
100010c60:     	lsr	x8, x8, #32
100010c64:     	sub	w9, w20, w8
100010c68:     	add	w8, w8, w9, lsr #1
100010c6c:     	lsr	w8, w8, #6
100010c70:     	madd	w2, w8, w23, w20
100010c74:     	mov	x0, x19
100010c78:     	mov	x1, x20
100010c7c:     	bl	0x10000ffa0 <_mapSet$Int$Int__Struct_Map$Int$Int_Int_Int>
100010c80:     	add	w20, w20, #0x1
100010c84:     	cmp	w22, w20
100010c88:     	b.ne	0x100010c5c <_benchKeyValueUpdate__Int+0x38>
100010c8c:     	mov	w21, #0x0               ; =0
100010c90:     	mov	w20, #0x0               ; =0
100010c94:     	mov	x0, x19
100010c98:     	mov	x1, x20
100010c9c:     	mov	w2, #0x0                ; =0
100010ca0:     	bl	0x100010200 <_mapGetOr$Int$Int__Struct_Map$Int$Int_Int_Int>
100010ca4:     	add	w2, w0, #0x1
100010ca8:     	mov	x0, x19
100010cac:     	mov	x1, x20
100010cb0:     	bl	0x10000ffa0 <_mapSet$Int$Int__Struct_Map$Int$Int_Int_Int>
100010cb4:     	add	w20, w20, #0x1
100010cb8:     	cmp	w22, w20
100010cbc:     	b.ne	0x100010c94 <_benchKeyValueUpdate__Int+0x70>
100010cc0:     	add	w21, w21, #0x1
100010cc4:     	cmp	w21, #0x14
100010cc8:     	b.ne	0x100010c90 <_benchKeyValueUpdate__Int+0x6c>
100010ccc:     	mov	w21, #0x0               ; =0
100010cd0:     	mov	w20, #0x0               ; =0
100010cd4:     	mov	w23, #0x2f99            ; =12185
100010cd8:     	movk	w23, #0x44b8, lsl #16
100010cdc:     	mov	w24, #0xca07            ; =51719
100010ce0:     	movk	w24, #0x3b9a, lsl #16
100010ce4:     	mov	x0, x19
100010ce8:     	mov	x1, x21
100010cec:     	mov	w2, #0x0                ; =0
100010cf0:     	bl	0x100010200 <_mapGetOr$Int$Int__Struct_Map$Int$Int_Int_Int>
100010cf4:     	add	w8, w0, w20
100010cf8:     	smull	x9, w8, w23
100010cfc:     	asr	x10, x9, #60
100010d00:     	add	x9, x10, x9, lsr #63
100010d04:     	msub	w20, w9, w24, w8
100010d08:     	add	w21, w21, #0x1
100010d0c:     	cmp	w22, w21
100010d10:     	b.ne	0x100010ce4 <_benchKeyValueUpdate__Int+0xc0>
100010d14:     	cbz	x19, 0x100010d38 <_benchKeyValueUpdate__Int+0x114>
100010d18:     	ldr	x0, [x19, #0x8]
100010d1c:     	bl	0x1000179e8 <_list_release>
100010d20:     	ldr	x0, [x19, #0x10]
100010d24:     	bl	0x1000179e8 <_list_release>
100010d28:     	ldr	x0, [x19]
100010d2c:     	bl	0x1000179e8 <_list_release>
100010d30:     	mov	x0, x19
100010d34:     	bl	0x100014564 <_rt_free>
100010d38:     	mov	x0, x20
100010d3c:     	ldp	x29, x30, [sp, #0x30]
100010d40:     	ldp	x20, x19, [sp, #0x20]
100010d44:     	ldp	x22, x21, [sp, #0x10]
100010d48:     	ldp	x24, x23, [sp], #0x40
100010d4c:     	ret
100010d50:     	mov	w20, #0x0               ; =0
100010d54:     	cbnz	x19, 0x100010d18 <_benchKeyValueUpdate__Int+0xf4>
100010d58:     	b	0x100010d38 <_benchKeyValueUpdate__Int+0x114>

