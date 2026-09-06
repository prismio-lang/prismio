000000010000c47c <_benchGcdLcm__Int>:
10000c47c:     	mov	w8, #0x93e0             ; =37856
10000c480:     	movk	w8, #0x4, lsl #16
10000c484:     	mul	w8, w0, w8
10000c488:     	cmp	w8, #0x1
10000c48c:     	b.lt	0x10000c534 <_benchGcdLcm__Int+0xb8>
10000c490:     	mov	w0, #0x0                ; =0
10000c494:     	mov	w9, #0x1                ; =1
10000c498:     	mov	w10, #0xb273            ; =45683
10000c49c:     	movk	w10, #0x45e7, lsl #16
10000c4a0:     	mov	w11, #0x7530            ; =30000
10000c4a4:     	mov	w12, #0x2f99            ; =12185
10000c4a8:     	movk	w12, #0x44b8, lsl #16
10000c4ac:     	mov	w13, #0xca07            ; =51719
10000c4b0:     	movk	w13, #0x3b9a, lsl #16
10000c4b4:     	b	0x10000c4e4 <_benchGcdLcm__Int+0x68>
10000c4b8:     	mov	x16, x14
10000c4bc:     	sdiv	w14, w14, w16
10000c4c0:     	add	w16, w16, w0
10000c4c4:     	madd	w14, w14, w15, w16
10000c4c8:     	smull	x15, w14, w12
10000c4cc:     	asr	x16, x15, #60
10000c4d0:     	add	x15, x16, x15, lsr #63
10000c4d4:     	msub	w0, w15, w13, w14
10000c4d8:     	cmp	w9, w8
10000c4dc:     	add	w9, w9, #0x1
10000c4e0:     	b.eq	0x10000c530 <_benchGcdLcm__Int+0xb4>
10000c4e4:     	umull	x14, w9, w10
10000c4e8:     	lsr	x14, x14, #45
10000c4ec:     	msub	w14, w14, w11, w9
10000c4f0:     	add	w14, w14, #0x1
10000c4f4:     	add	w15, w9, w9, lsl #4
10000c4f8:     	smull	x16, w15, w10
10000c4fc:     	asr	x17, x16, #45
10000c500:     	add	x16, x17, x16, lsr #63
10000c504:     	msub	w15, w16, w11, w15
10000c508:     	adds	w15, w15, #0x1
10000c50c:     	b.hs	0x10000c4b8 <_benchGcdLcm__Int+0x3c>
10000c510:     	mov	x17, x14
10000c514:     	mov	x1, x15
10000c518:     	mov	x16, x1
10000c51c:     	sdiv	w1, w17, w1
10000c520:     	msub	w1, w1, w16, w17
10000c524:     	mov	x17, x16
10000c528:     	cbnz	w1, 0x10000c518 <_benchGcdLcm__Int+0x9c>
10000c52c:     	b	0x10000c4bc <_benchGcdLcm__Int+0x40>
10000c530:     	ret
10000c534:     	mov	w0, #0x0                ; =0
10000c538:     	ret

