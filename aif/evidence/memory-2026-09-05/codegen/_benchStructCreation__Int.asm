00000001000121d0 <_benchStructCreation__Int>:
1000121d0:     	sub	sp, sp, #0x80
1000121d4:     	stp	d9, d8, [sp, #0x10]
1000121d8:     	stp	x28, x27, [sp, #0x20]
1000121dc:     	stp	x26, x25, [sp, #0x30]
1000121e0:     	stp	x24, x23, [sp, #0x40]
1000121e4:     	stp	x22, x21, [sp, #0x50]
1000121e8:     	stp	x20, x19, [sp, #0x60]
1000121ec:     	stp	x29, x30, [sp, #0x70]
1000121f0:     	mov	w8, #0xd090             ; =53392
1000121f4:     	movk	w8, #0x3, lsl #16
1000121f8:     	mul	w20, w0, w8
1000121fc:     	mov	x0, x20
100012200:     	bl	0x100016840 <_list_new_with_capacity>
100012204:     	mov	x19, x0
100012208:     	cbz	x0, 0x100012214 <_benchStructCreation__Int+0x44>
10001220c:     	mov	w8, #0x1                ; =1
100012210:     	str	w8, [x19, #0x10]
100012214:     	mov	x0, x19
100012218:     	mov	w1, #0x28               ; =40
10001221c:     	bl	0x100016868 <_list_set_elem_inline>
100012220:     	cmp	w20, #0x1
100012224:     	b.lt	0x100012314 <_benchStructCreation__Int+0x144>
100012228:     	mov	w21, #0x0               ; =0
10001222c:     	movi.2d	v8, #0000000000000000
100012230:     	mov	w22, #0x1085            ; =4229
100012234:     	movk	w22, #0x842, lsl #16
100012238:     	mov	w23, #0x851f            ; =34079
10001223c:     	movk	w23, #0x51eb, lsl #16
100012240:     	adrp	x8, 0x10001a000 <_chan_recv+0x50>
100012244:     	ldr	q0, [x8, #0x550]
100012248:     	str	q0, [sp]
10001224c:     	mov	w24, #0x64              ; =100
100012250:     	fmov	d9, #1.00000000
100012254:     	mov	x25, x20
100012258:     	umull	x8, w21, w22
10001225c:     	lsr	x8, x8, #32
100012260:     	sub	w9, w21, w8
100012264:     	add	w8, w8, w9, lsr #1
100012268:     	lsr	w8, w8, #4
10001226c:     	sub	w8, w8, w8, lsl #5
100012270:     	add	w26, w21, w8
100012274:     	umull	x8, w21, w23
100012278:     	lsr	x8, x8, #37
10001227c:     	msub	w27, w8, w24, w21
100012280:     	mov	x0, x19
100012284:     	mov	w1, #0x28               ; =40
100012288:     	bl	0x100016c5c <_list_push_slot>
10001228c:     	ucvtf	d0, w26
100012290:     	stp	d8, d0, [x0]
100012294:     	ldr	q0, [sp]
100012298:     	str	q0, [x0, #0x10]
10001229c:     	str	w27, [x0, #0x20]
1000122a0:     	fadd	d8, d8, d9
1000122a4:     	add	w21, w21, #0x1
1000122a8:     	subs	w25, w25, #0x1
1000122ac:     	b.ne	0x100012258 <_benchStructCreation__Int+0x88>
1000122b0:     	ldrsw	x8, [x19, #0x24]
1000122b4:     	cmp	w8, #0x28
1000122b8:     	b.ne	0x10001231c <_benchStructCreation__Int+0x14c>
1000122bc:     	ldr	w9, [x19, #0x8]
1000122c0:     	cmp	w20, w9
1000122c4:     	b.ge	0x10001231c <_benchStructCreation__Int+0x14c>
1000122c8:     	mov	w21, #0x0               ; =0
1000122cc:     	ldr	x8, [x19]
1000122d0:     	add	x8, x8, #0x20
1000122d4:     	mov	w9, #0x2f99             ; =12185
1000122d8:     	movk	w9, #0x44b8, lsl #16
1000122dc:     	mov	w10, #0xca07            ; =51719
1000122e0:     	movk	w10, #0x3b9a, lsl #16
1000122e4:     	ldur	d0, [x8, #-0x20]
1000122e8:     	fcvtzs	w11, d0
1000122ec:     	ldr	w12, [x8], #0x28
1000122f0:     	add	w12, w21, w12
1000122f4:     	add	w11, w12, w11
1000122f8:     	smull	x12, w11, w9
1000122fc:     	asr	x13, x12, #60
100012300:     	add	x12, x13, x12, lsr #63
100012304:     	msub	w21, w12, w10, w11
100012308:     	subs	x20, x20, #0x1
10001230c:     	b.ne	0x1000122e4 <_benchStructCreation__Int+0x114>
100012310:     	b	0x1000123c8 <_benchStructCreation__Int+0x1f8>
100012314:     	mov	w21, #0x0               ; =0
100012318:     	b	0x1000123c8 <_benchStructCreation__Int+0x1f8>
10001231c:     	ldr	x9, [x19]
100012320:     	cbz	w8, 0x100012378 <_benchStructCreation__Int+0x1a8>
100012324:     	mov	x10, #0x0               ; =0
100012328:     	mov	w21, #0x0               ; =0
10001232c:     	add	x9, x9, #0x20
100012330:     	mov	w11, #0x2f99            ; =12185
100012334:     	movk	w11, #0x44b8, lsl #16
100012338:     	mov	w12, #0xca07            ; =51719
10001233c:     	movk	w12, #0x3b9a, lsl #16
100012340:     	ldur	d0, [x9, #-0x20]
100012344:     	fcvtzs	w13, d0
100012348:     	ldr	w14, [x9]
10001234c:     	add	w14, w21, w14
100012350:     	add	w13, w14, w13
100012354:     	smull	x14, w13, w11
100012358:     	asr	x15, x14, #60
10001235c:     	add	x14, x15, x14, lsr #63
100012360:     	msub	w21, w14, w12, w13
100012364:     	add	x10, x10, #0x1
100012368:     	add	x9, x9, x8
10001236c:     	cmp	x20, x10
100012370:     	b.ne	0x100012340 <_benchStructCreation__Int+0x170>
100012374:     	b	0x1000123c8 <_benchStructCreation__Int+0x1f8>
100012378:     	mov	x8, #0x0                ; =0
10001237c:     	mov	w21, #0x0               ; =0
100012380:     	mov	w10, #0x2f99            ; =12185
100012384:     	movk	w10, #0x44b8, lsl #16
100012388:     	mov	w11, #0xca07            ; =51719
10001238c:     	movk	w11, #0x3b9a, lsl #16
100012390:     	ldr	x12, [x9, x8, lsl #3]
100012394:     	ldr	d0, [x12]
100012398:     	fcvtzs	w13, d0
10001239c:     	ldr	w12, [x12, #0x20]
1000123a0:     	add	w12, w21, w12
1000123a4:     	add	w12, w12, w13
1000123a8:     	smull	x13, w12, w10
1000123ac:     	lsr	x14, x13, #32
1000123b0:     	asr	w14, w14, #28
1000123b4:     	add	x13, x14, x13, lsr #63
1000123b8:     	msub	w21, w13, w11, w12
1000123bc:     	add	x8, x8, #0x1
1000123c0:     	cmp	x20, x8
1000123c4:     	b.ne	0x100012390 <_benchStructCreation__Int+0x1c0>
1000123c8:     	mov	x0, x19
1000123cc:     	bl	0x1000179e8 <_list_release>
1000123d0:     	mov	x0, x21
1000123d4:     	ldp	x29, x30, [sp, #0x70]
1000123d8:     	ldp	x20, x19, [sp, #0x60]
1000123dc:     	ldp	x22, x21, [sp, #0x50]
1000123e0:     	ldp	x24, x23, [sp, #0x40]
1000123e4:     	ldp	x26, x25, [sp, #0x30]
1000123e8:     	ldp	x28, x27, [sp, #0x20]
1000123ec:     	ldp	d9, d8, [sp, #0x10]
1000123f0:     	add	sp, sp, #0x80
1000123f4:     	ret

