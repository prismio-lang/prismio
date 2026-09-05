00000001000123f8 <_benchAllocationMutation__Int>:
1000123f8:     	sub	sp, sp, #0x40
1000123fc:     	stp	x22, x21, [sp, #0x10]
100012400:     	stp	x20, x19, [sp, #0x20]
100012404:     	stp	x29, x30, [sp, #0x30]
100012408:     	mov	w8, #0x86a0             ; =34464
10001240c:     	movk	w8, #0x1, lsl #16
100012410:     	mul	w20, w0, w8
100012414:     	mov	x0, x20
100012418:     	bl	0x100016840 <_list_new_with_capacity>
10001241c:     	mov	x19, x0
100012420:     	cbz	x0, 0x10001242c <_benchAllocationMutation__Int+0x34>
100012424:     	mov	w8, #0x1                ; =1
100012428:     	str	w8, [x19, #0x10]
10001242c:     	mov	x0, x19
100012430:     	mov	w1, #0x28               ; =40
100012434:     	bl	0x100016868 <_list_set_elem_inline>
100012438:     	cmp	w20, #0x1
10001243c:     	b.lt	0x1000125d0 <_benchAllocationMutation__Int+0x1d8>
100012440:     	adrp	x8, 0x10001a000 <_chan_recv+0x50>
100012444:     	ldr	q0, [x8, #0x550]
100012448:     	str	q0, [sp]
10001244c:     	mov	w21, #0x32              ; =50
100012450:     	mov	x22, x20
100012454:     	mov	x0, x19
100012458:     	mov	w1, #0x28               ; =40
10001245c:     	bl	0x100016c5c <_list_push_slot>
100012460:     	stp	xzr, xzr, [x0]
100012464:     	ldr	q0, [sp]
100012468:     	str	q0, [x0, #0x10]
10001246c:     	str	w21, [x0, #0x20]
100012470:     	subs	w22, w22, #0x1
100012474:     	b.ne	0x100012454 <_benchAllocationMutation__Int+0x5c>
100012478:     	mov	w8, #0x0                ; =0
10001247c:     	ldr	w9, [x19, #0x8]
100012480:     	mov	x10, x9
100012484:     	b	0x100012494 <_benchAllocationMutation__Int+0x9c>
100012488:     	add	w8, w8, #0x1
10001248c:     	cmp	w8, #0x14
100012490:     	b.eq	0x10001255c <_benchAllocationMutation__Int+0x164>
100012494:     	ldrsw	x11, [x19, #0x24]
100012498:     	cmp	w11, #0x28
10001249c:     	ccmp	w20, w9, #0x0, eq
1000124a0:     	b.lt	0x1000124e0 <_benchAllocationMutation__Int+0xe8>
1000124a4:     	ldr	x12, [x19]
1000124a8:     	cbz	w11, 0x10001252c <_benchAllocationMutation__Int+0x134>
1000124ac:     	mov	x13, #0x0               ; =0
1000124b0:     	add	x12, x12, #0x20
1000124b4:     	ldp	q0, q1, [x12, #-0x20]
1000124b8:     	fadd.2d	v0, v0, v1
1000124bc:     	stur	q0, [x12, #-0x20]
1000124c0:     	ldr	w14, [x12]
1000124c4:     	sub	w14, w14, #0x1
1000124c8:     	str	w14, [x12]
1000124cc:     	add	x13, x13, #0x1
1000124d0:     	add	x12, x12, x11
1000124d4:     	cmp	x20, x13
1000124d8:     	b.ne	0x1000124b4 <_benchAllocationMutation__Int+0xbc>
1000124dc:     	b	0x100012488 <_benchAllocationMutation__Int+0x90>
1000124e0:     	mov	x11, #0x0               ; =0
1000124e4:     	ldr	x12, [x19]
1000124e8:     	ldr	d0, [x12]
1000124ec:     	ldp	d1, d2, [x12, #0x10]
1000124f0:     	fadd	d0, d0, d1
1000124f4:     	ldr	w10, [x19, #0x8]
1000124f8:     	cmp	x11, x10
1000124fc:     	csel	x13, x12, xzr, lo
100012500:     	str	d0, [x12], #0x28
100012504:     	ldr	d0, [x13, #0x8]
100012508:     	fadd	d0, d0, d2
10001250c:     	str	d0, [x13, #0x8]
100012510:     	ldr	w14, [x13, #0x20]
100012514:     	sub	w14, w14, #0x1
100012518:     	str	w14, [x13, #0x20]
10001251c:     	add	x11, x11, #0x1
100012520:     	cmp	x20, x11
100012524:     	b.ne	0x1000124e8 <_benchAllocationMutation__Int+0xf0>
100012528:     	b	0x100012488 <_benchAllocationMutation__Int+0x90>
10001252c:     	mov	x11, #0x0               ; =0
100012530:     	ldr	x13, [x12, x11, lsl #3]
100012534:     	ldp	q0, q1, [x13]
100012538:     	fadd.2d	v0, v0, v1
10001253c:     	str	q0, [x13]
100012540:     	ldr	w14, [x13, #0x20]
100012544:     	sub	w14, w14, #0x1
100012548:     	str	w14, [x13, #0x20]
10001254c:     	add	x11, x11, #0x1
100012550:     	cmp	x20, x11
100012554:     	b.ne	0x100012530 <_benchAllocationMutation__Int+0x138>
100012558:     	b	0x100012488 <_benchAllocationMutation__Int+0x90>
10001255c:     	ldrsw	x9, [x19, #0x24]
100012560:     	cmp	w9, #0x28
100012564:     	ccmp	w20, w10, #0x0, eq
100012568:     	b.lt	0x1000125d8 <_benchAllocationMutation__Int+0x1e0>
10001256c:     	ldr	x8, [x19]
100012570:     	cbz	w9, 0x100012630 <_benchAllocationMutation__Int+0x238>
100012574:     	mov	x10, #0x0               ; =0
100012578:     	mov	w21, #0x0               ; =0
10001257c:     	mov	w11, #0x2f99            ; =12185
100012580:     	movk	w11, #0x44b8, lsl #16
100012584:     	mov	w12, #0xca07            ; =51719
100012588:     	movk	w12, #0x3b9a, lsl #16
10001258c:     	ldp	d0, d1, [x8]
100012590:     	fcvtzs	w13, d0
100012594:     	fcvtzs	w14, d1
100012598:     	add	w13, w21, w13
10001259c:     	ldr	w15, [x8, #0x20]
1000125a0:     	add	w14, w14, w15
1000125a4:     	add	w13, w13, w14
1000125a8:     	smull	x14, w13, w11
1000125ac:     	lsr	x15, x14, #32
1000125b0:     	asr	w15, w15, #28
1000125b4:     	add	x14, x15, x14, lsr #63
1000125b8:     	msub	w21, w14, w12, w13
1000125bc:     	add	x10, x10, #0x1
1000125c0:     	add	x8, x8, x9
1000125c4:     	cmp	x20, x10
1000125c8:     	b.ne	0x10001258c <_benchAllocationMutation__Int+0x194>
1000125cc:     	b	0x100012688 <_benchAllocationMutation__Int+0x290>
1000125d0:     	mov	w21, #0x0               ; =0
1000125d4:     	b	0x100012688 <_benchAllocationMutation__Int+0x290>
1000125d8:     	mov	w21, #0x0               ; =0
1000125dc:     	ldr	x8, [x19]
1000125e0:     	mov	w9, #0x2f99             ; =12185
1000125e4:     	movk	w9, #0x44b8, lsl #16
1000125e8:     	mov	w10, #0xca07            ; =51719
1000125ec:     	movk	w10, #0x3b9a, lsl #16
1000125f0:     	ldp	d0, d1, [x8]
1000125f4:     	fcvtzs	w11, d0
1000125f8:     	add	w11, w21, w11
1000125fc:     	fcvtzs	w12, d1
100012600:     	ldr	w13, [x8, #0x20]
100012604:     	add	w12, w12, w13
100012608:     	add	w11, w11, w12
10001260c:     	smull	x12, w11, w9
100012610:     	lsr	x13, x12, #32
100012614:     	asr	w13, w13, #28
100012618:     	add	x12, x13, x12, lsr #63
10001261c:     	msub	w21, w12, w10, w11
100012620:     	add	x8, x8, #0x28
100012624:     	subs	x20, x20, #0x1
100012628:     	b.ne	0x1000125f0 <_benchAllocationMutation__Int+0x1f8>
10001262c:     	b	0x100012688 <_benchAllocationMutation__Int+0x290>
100012630:     	mov	x9, #0x0                ; =0
100012634:     	mov	w21, #0x0               ; =0
100012638:     	mov	w10, #0x2f99            ; =12185
10001263c:     	movk	w10, #0x44b8, lsl #16
100012640:     	mov	w11, #0xca07            ; =51719
100012644:     	movk	w11, #0x3b9a, lsl #16
100012648:     	ldr	x12, [x8, x9, lsl #3]
10001264c:     	ldp	d0, d1, [x12]
100012650:     	fcvtzs	w13, d0
100012654:     	add	w13, w21, w13
100012658:     	fcvtzs	w14, d1
10001265c:     	ldr	w12, [x12, #0x20]
100012660:     	add	w12, w14, w12
100012664:     	add	w12, w13, w12
100012668:     	smull	x13, w12, w10
10001266c:     	lsr	x14, x13, #32
100012670:     	asr	w14, w14, #28
100012674:     	add	x13, x14, x13, lsr #63
100012678:     	msub	w21, w13, w11, w12
10001267c:     	add	x9, x9, #0x1
100012680:     	cmp	x20, x9
100012684:     	b.ne	0x100012648 <_benchAllocationMutation__Int+0x250>
100012688:     	mov	x0, x19
10001268c:     	bl	0x1000179e8 <_list_release>
100012690:     	mov	x0, x21
100012694:     	ldp	x29, x30, [sp, #0x30]
100012698:     	ldp	x20, x19, [sp, #0x20]
10001269c:     	ldp	x22, x21, [sp, #0x10]
1000126a0:     	add	sp, sp, #0x40
1000126a4:     	ret

