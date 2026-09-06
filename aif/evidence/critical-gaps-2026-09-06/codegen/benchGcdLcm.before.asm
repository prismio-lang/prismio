000000010000c4b0 <_benchGcdLcm__Int>:
10000c4b0:     	mov	w8, #0x93e0             ; =37856
10000c4b4:     	movk	w8, #0x4, lsl #16
10000c4b8:     	mul	w8, w0, w8
10000c4bc:     	cmp	w8, #0x1
10000c4c0:     	b.lt	0x10000c568 <_benchGcdLcm__Int+0xb8>
10000c4c4:     	mov	w0, #0x0                ; =0
10000c4c8:     	mov	w9, #0x1                ; =1
10000c4cc:     	mov	w10, #0xb273            ; =45683
10000c4d0:     	movk	w10, #0x45e7, lsl #16
10000c4d4:     	mov	w11, #0x7530            ; =30000
10000c4d8:     	mov	w12, #0x2f99            ; =12185
10000c4dc:     	movk	w12, #0x44b8, lsl #16
10000c4e0:     	mov	w13, #0xca07            ; =51719
10000c4e4:     	movk	w13, #0x3b9a, lsl #16
10000c4e8:     	b	0x10000c518 <_benchGcdLcm__Int+0x68>
10000c4ec:     	mov	x16, x14
10000c4f0:     	sdiv	w14, w14, w16
10000c4f4:     	add	w16, w16, w0
10000c4f8:     	madd	w14, w14, w15, w16
10000c4fc:     	smull	x15, w14, w12
10000c500:     	asr	x16, x15, #60
10000c504:     	add	x15, x16, x15, lsr #63
10000c508:     	msub	w0, w15, w13, w14
10000c50c:     	cmp	w9, w8
10000c510:     	add	w9, w9, #0x1
10000c514:     	b.eq	0x10000c564 <_benchGcdLcm__Int+0xb4>
10000c518:     	umull	x14, w9, w10
10000c51c:     	lsr	x14, x14, #45
10000c520:     	msub	w14, w14, w11, w9
10000c524:     	add	w14, w14, #0x1
10000c528:     	add	w15, w9, w9, lsl #4
10000c52c:     	smull	x16, w15, w10
10000c530:     	asr	x17, x16, #45
10000c534:     	add	x16, x17, x16, lsr #63
10000c538:     	msub	w15, w16, w11, w15
10000c53c:     	adds	w15, w15, #0x1
10000c540:     	b.hs	0x10000c4ec <_benchGcdLcm__Int+0x3c>
10000c544:     	mov	x17, x14
10000c548:     	mov	x1, x15
10000c54c:     	mov	x16, x1
10000c550:     	sdiv	w1, w17, w1
10000c554:     	msub	w1, w1, w16, w17
10000c558:     	mov	x17, x16
10000c55c:     	cbnz	w1, 0x10000c54c <_benchGcdLcm__Int+0x9c>
10000c560:     	b	0x10000c4f0 <_benchGcdLcm__Int+0x40>
10000c564:     	ret
10000c568:     	mov	w0, #0x0                ; =0
10000c56c:     	ret

