000000010000d3ac <_benchTreeTraversal__Int>:
10000d3ac:     	stp	x20, x19, [sp, #-0x20]!
10000d3b0:     	stp	x29, x30, [sp, #0x10]
10000d3b4:     	mov	x19, x0
10000d3b8:     	add	w8, w0, #0x3
10000d3bc:     	cmp	w0, #0x0
10000d3c0:     	csel	w8, w8, w0, mi
10000d3c4:     	asr	w8, w8, #2
10000d3c8:     	add	w0, w8, #0xd
10000d3cc:     	mov	w1, #0x1                ; =1
10000d3d0:     	bl	0x10000d2bc <_benchBuildTree__Int_Int>
10000d3d4:     	lsl	w20, w19, #3
10000d3d8:     	cmp	w20, #0x1
10000d3dc:     	b.lt	0x10000d424 <_benchTreeTraversal__Int+0x78>
10000d3e0:     	mov	x19, x0
10000d3e4:     	bl	0x10000d344 <_benchTreeSum__Struct_BenchTree>
10000d3e8:     	mov	x8, x0
10000d3ec:     	mov	x0, x19
10000d3f0:     	mov	w19, #0x0               ; =0
10000d3f4:     	mov	w9, #0x2f99             ; =12185
10000d3f8:     	movk	w9, #0x44b8, lsl #16
10000d3fc:     	mov	w10, #0xca07            ; =51719
10000d400:     	movk	w10, #0x3b9a, lsl #16
10000d404:     	add	w11, w8, w19
10000d408:     	smull	x12, w11, w9
10000d40c:     	asr	x13, x12, #60
10000d410:     	add	x12, x13, x12, lsr #63
10000d414:     	msub	w19, w12, w10, w11
10000d418:     	subs	w20, w20, #0x1
10000d41c:     	b.ne	0x10000d404 <_benchTreeTraversal__Int+0x58>
10000d420:     	b	0x10000d428 <_benchTreeTraversal__Int+0x7c>
10000d424:     	mov	w19, #0x0               ; =0
10000d428:     	bl	0x1000006d8 <___aif_release_BenchTree>
10000d42c:     	mov	x0, x19
10000d430:     	ldp	x29, x30, [sp, #0x10]
10000d434:     	ldp	x20, x19, [sp], #0x20
10000d438:     	ret

