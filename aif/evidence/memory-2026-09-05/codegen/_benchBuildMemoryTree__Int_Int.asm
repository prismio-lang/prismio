0000000100011f40 <_benchBuildMemoryTree__Int_Int>:
100011f40:     	stp	x24, x23, [sp, #-0x40]!
100011f44:     	stp	x22, x21, [sp, #0x10]
100011f48:     	stp	x20, x19, [sp, #0x20]
100011f4c:     	stp	x29, x30, [sp, #0x30]
100011f50:     	mov	x19, x1
100011f54:     	mov	x20, x0
100011f58:     	mov	w0, #0x18               ; =24
100011f5c:     	bl	0x10001a26c <_system+0x10001a26c>
100011f60:     	cbz	w20, 0x100011fe0 <_benchBuildMemoryTree__Int_Int+0xa0>
100011f64:     	mov	w8, #0x2                ; =2
100011f68:     	str	w8, [x0]
100011f6c:     	sub	w20, w20, #0x1
100011f70:     	add	w8, w19, w19, lsl #1
100011f74:     	add	w8, w8, #0x1
100011f78:     	mov	w22, #0x22c3            ; =8899
100011f7c:     	movk	w22, #0x81e7, lsl #16
100011f80:     	smull	x9, w8, w22
100011f84:     	add	x9, x8, x9, lsr #32
100011f88:     	asr	w10, w9, #9
100011f8c:     	add	w9, w10, w9, lsr #31
100011f90:     	mov	w23, #0x3f1             ; =1009
100011f94:     	msub	w1, w9, w23, w8
100011f98:     	mov	x21, x0
100011f9c:     	mov	x0, x20
100011fa0:     	bl	0x100011f40 <_benchBuildMemoryTree__Int_Int>
100011fa4:     	str	x0, [x21, #0x8]
100011fa8:     	str	w19, [x21, #0x4]
100011fac:     	add	w8, w19, w19, lsl #2
100011fb0:     	add	w8, w8, #0x7
100011fb4:     	smull	x9, w8, w22
100011fb8:     	add	x9, x8, x9, lsr #32
100011fbc:     	asr	w10, w9, #9
100011fc0:     	add	w9, w10, w9, lsr #31
100011fc4:     	msub	w1, w9, w23, w8
100011fc8:     	mov	x0, x20
100011fcc:     	bl	0x100011f40 <_benchBuildMemoryTree__Int_Int>
100011fd0:     	mov	x8, x0
100011fd4:     	mov	x0, x21
100011fd8:     	str	x8, [x21, #0x10]
100011fdc:     	b	0x100011ff4 <_benchBuildMemoryTree__Int_Int+0xb4>
100011fe0:     	mov	w8, #0x1                ; =1
100011fe4:     	str	w8, [x0]
100011fe8:     	stur	xzr, [x0, #0xc]
100011fec:     	stur	xzr, [x0, #0x4]
100011ff0:     	str	wzr, [x0, #0x14]
100011ff4:     	ldp	x29, x30, [sp, #0x30]
100011ff8:     	ldp	x20, x19, [sp, #0x20]
100011ffc:     	ldp	x22, x21, [sp, #0x10]
100012000:     	ldp	x24, x23, [sp], #0x40
100012004:     	ret

