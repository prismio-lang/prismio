000000010000d344 <_benchTreeSum__Struct_BenchTree>:
10000d344:     	ldr	w8, [x0]
10000d348:     	cmp	w8, #0x2
10000d34c:     	b.ne	0x10000d3a4 <_benchTreeSum__Struct_BenchTree+0x60>
10000d350:     	stp	x20, x19, [sp, #-0x20]!
10000d354:     	stp	x29, x30, [sp, #0x10]
10000d358:     	ldr	w20, [x0, #0x4]
10000d35c:     	ldp	x8, x19, [x0, #0x8]
10000d360:     	mov	x0, x8
10000d364:     	bl	0x10000d344 <_benchTreeSum__Struct_BenchTree>
10000d368:     	add	w20, w0, w20
10000d36c:     	mov	x0, x19
10000d370:     	bl	0x10000d344 <_benchTreeSum__Struct_BenchTree>
10000d374:     	add	w8, w20, w0
10000d378:     	mov	w9, #0x2f99             ; =12185
10000d37c:     	movk	w9, #0x44b8, lsl #16
10000d380:     	smull	x9, w8, w9
10000d384:     	asr	x10, x9, #60
10000d388:     	add	x9, x10, x9, lsr #63
10000d38c:     	mov	w10, #0xca07            ; =51719
10000d390:     	movk	w10, #0x3b9a, lsl #16
10000d394:     	msub	w0, w9, w10, w8
10000d398:     	ldp	x29, x30, [sp, #0x10]
10000d39c:     	ldp	x20, x19, [sp], #0x20
10000d3a0:     	ret
10000d3a4:     	mov	w0, #0x0                ; =0
10000d3a8:     	ret

