0000000100017100 <_benchAllocationMutation__Int>:
100017100:     	sub	sp, sp, #0x40
100017104:     	stp	x22, x21, [sp, #0x10]
100017108:     	stp	x20, x19, [sp, #0x20]
10001710c:     	stp	x29, x30, [sp, #0x30]
100017110:     	mov	w8, #0x86a0             ; =34464
100017114:     	movk	w8, #0x1, lsl #16
100017118:     	mul	w20, w0, w8
10001711c:     	mov	x0, x20
100017120:     	bl	0x10001c7f0 <_list_new_with_capacity>
100017124:     	mov	x19, x0
100017128:     	cbz	x0, 0x100017134 <_benchAllocationMutation__Int+0x34>
10001712c:     	mov	w8, #0x1                ; =1
100017130:     	str	w8, [x19, #0x10]
100017134:     	mov	x0, x19
100017138:     	mov	w1, #0x28               ; =40
10001713c:     	bl	0x10001c818 <_list_set_elem_inline>
100017140:     	ldr	w9, [x19, #0x24]
100017144:     	cmp	w20, #0x1
100017148:     	b.lt	0x10001719c <_benchAllocationMutation__Int+0x9c>
10001714c:     	ldp	w8, w10, [x19, #0x8]
100017150:     	sub	x10, x10, x8
100017154:     	cmp	w9, #0x28
100017158:     	ccmp	x10, x20, #0x8, eq
10001715c:     	b.ge	0x10001728c <_benchAllocationMutation__Int+0x18c>
100017160:     	adrp	x8, 0x100020000 <_chan_recv+0x4>
100017164:     	ldr	q0, [x8, #0x5f0]
100017168:     	str	q0, [sp]
10001716c:     	mov	w21, #0x32              ; =50
100017170:     	mov	x22, x20
100017174:     	mov	x0, x19
100017178:     	mov	w1, #0x28               ; =40
10001717c:     	bl	0x10001cdb0 <_list_push_slot>
100017180:     	stp	xzr, xzr, [x0]
100017184:     	ldr	q0, [sp]
100017188:     	str	q0, [x0, #0x10]
10001718c:     	str	w21, [x0, #0x20]
100017190:     	subs	w22, w22, #0x1
100017194:     	b.ne	0x100017174 <_benchAllocationMutation__Int+0x74>
100017198:     	ldr	w9, [x19, #0x24]
10001719c:     	ldr	w8, [x19, #0x8]
1000171a0:     	cmp	w9, #0x28
1000171a4:     	b.ne	0x1000171bc <_benchAllocationMutation__Int+0xbc>
1000171a8:     	cmp	w20, w8
1000171ac:     	b.le	0x100017648 <_benchAllocationMutation__Int+0x548>
1000171b0:     	cmp	w20, #0x1
1000171b4:     	b.ge	0x1000172d0 <_benchAllocationMutation__Int+0x1d0>
1000171b8:     	b	0x100017974 <_benchAllocationMutation__Int+0x874>
1000171bc:     	mov	w9, #0x0                ; =0
1000171c0:     	b	0x1000171d0 <_benchAllocationMutation__Int+0xd0>
1000171c4:     	add	w9, w9, #0x1
1000171c8:     	cmp	w9, #0x14
1000171cc:     	b.eq	0x100017974 <_benchAllocationMutation__Int+0x874>
1000171d0:     	ldrsw	x10, [x19, #0x24]
1000171d4:     	cmp	w10, #0x28
1000171d8:     	ccmp	w20, w8, #0x0, eq
1000171dc:     	b.le	0x100017224 <_benchAllocationMutation__Int+0x124>
1000171e0:     	cmp	w20, #0x1
1000171e4:     	b.lt	0x1000171c4 <_benchAllocationMutation__Int+0xc4>
1000171e8:     	ldr	x12, [x19]
1000171ec:     	cbz	w10, 0x10001725c <_benchAllocationMutation__Int+0x15c>
1000171f0:     	mov	x11, #0x0               ; =0
1000171f4:     	add	x12, x12, #0x20
1000171f8:     	ldp	q0, q1, [x12, #-0x20]
1000171fc:     	fadd.2d	v0, v0, v1
100017200:     	stur	q0, [x12, #-0x20]
100017204:     	ldr	w13, [x12]
100017208:     	sub	w13, w13, #0x1
10001720c:     	str	w13, [x12]
100017210:     	add	x11, x11, #0x1
100017214:     	add	x12, x12, x10
100017218:     	cmp	x20, x11
10001721c:     	b.ne	0x1000171f8 <_benchAllocationMutation__Int+0xf8>
100017220:     	b	0x1000171c4 <_benchAllocationMutation__Int+0xc4>
100017224:     	cmp	w20, #0x1
100017228:     	b.lt	0x1000171c4 <_benchAllocationMutation__Int+0xc4>
10001722c:     	ldr	x10, [x19]
100017230:     	add	x10, x10, #0x20
100017234:     	mov	x11, x20
100017238:     	ldp	q0, q1, [x10, #-0x20]
10001723c:     	fadd.2d	v0, v0, v1
100017240:     	stur	q0, [x10, #-0x20]
100017244:     	ldr	w12, [x10]
100017248:     	sub	w12, w12, #0x1
10001724c:     	str	w12, [x10], #0x28
100017250:     	subs	x11, x11, #0x1
100017254:     	b.ne	0x100017238 <_benchAllocationMutation__Int+0x138>
100017258:     	b	0x1000171c4 <_benchAllocationMutation__Int+0xc4>
10001725c:     	mov	x10, #0x0               ; =0
100017260:     	ldr	x11, [x12, x10, lsl #3]
100017264:     	ldp	q0, q1, [x11]
100017268:     	fadd.2d	v0, v0, v1
10001726c:     	str	q0, [x11]
100017270:     	ldr	w13, [x11, #0x20]
100017274:     	sub	w13, w13, #0x1
100017278:     	str	w13, [x11, #0x20]
10001727c:     	add	x10, x10, #0x1
100017280:     	cmp	x20, x10
100017284:     	b.ne	0x100017260 <_benchAllocationMutation__Int+0x160>
100017288:     	b	0x1000171c4 <_benchAllocationMutation__Int+0xc4>
10001728c:     	ldr	x9, [x19]
100017290:     	mov	w10, #0x28              ; =40
100017294:     	umaddl	x9, w8, w10, x9
100017298:     	add	x9, x9, #0x20
10001729c:     	add	w8, w8, w20
1000172a0:     	adrp	x10, 0x100020000 <_chan_recv+0x4>
1000172a4:     	ldr	q0, [x10, #0x5f0]
1000172a8:     	mov	w10, #0x32              ; =50
1000172ac:     	mov	x11, x20
1000172b0:     	stp	xzr, xzr, [x9, #-0x20]
1000172b4:     	stur	q0, [x9, #-0x10]
1000172b8:     	str	w10, [x9], #0x28
1000172bc:     	subs	w11, w11, #0x1
1000172c0:     	b.ne	0x1000172b0 <_benchAllocationMutation__Int+0x1b0>
1000172c4:     	str	w8, [x19, #0x8]
1000172c8:     	cmp	w20, w8
1000172cc:     	b.le	0x100017650 <_benchAllocationMutation__Int+0x550>
1000172d0:     	mov	x9, #0x0                ; =0
1000172d4:     	ldr	x8, [x19]
1000172d8:     	add	x10, x8, #0x20
1000172dc:     	ldp	q0, q1, [x10, #-0x20]
1000172e0:     	fadd.2d	v0, v0, v1
1000172e4:     	stur	q0, [x10, #-0x20]
1000172e8:     	ldr	w11, [x10]
1000172ec:     	sub	w11, w11, #0x1
1000172f0:     	str	w11, [x10], #0x28
1000172f4:     	add	x9, x9, #0x1
1000172f8:     	cmp	x20, x9
1000172fc:     	b.ne	0x1000172dc <_benchAllocationMutation__Int+0x1dc>
100017300:     	mov	x9, #0x0                ; =0
100017304:     	add	x10, x8, #0x20
100017308:     	ldp	q0, q1, [x10, #-0x20]
10001730c:     	fadd.2d	v0, v0, v1
100017310:     	stur	q0, [x10, #-0x20]
100017314:     	ldr	w11, [x10]
100017318:     	sub	w11, w11, #0x1
10001731c:     	str	w11, [x10], #0x28
100017320:     	add	x9, x9, #0x1
100017324:     	cmp	x20, x9
100017328:     	b.ne	0x100017308 <_benchAllocationMutation__Int+0x208>
10001732c:     	mov	x9, #0x0                ; =0
100017330:     	add	x10, x8, #0x20
100017334:     	ldp	q0, q1, [x10, #-0x20]
100017338:     	fadd.2d	v0, v0, v1
10001733c:     	stur	q0, [x10, #-0x20]
100017340:     	ldr	w11, [x10]
100017344:     	sub	w11, w11, #0x1
100017348:     	str	w11, [x10], #0x28
10001734c:     	add	x9, x9, #0x1
100017350:     	cmp	x20, x9
100017354:     	b.ne	0x100017334 <_benchAllocationMutation__Int+0x234>
100017358:     	mov	x9, #0x0                ; =0
10001735c:     	add	x10, x8, #0x20
100017360:     	ldp	q0, q1, [x10, #-0x20]
100017364:     	fadd.2d	v0, v0, v1
100017368:     	stur	q0, [x10, #-0x20]
10001736c:     	ldr	w11, [x10]
100017370:     	sub	w11, w11, #0x1
100017374:     	str	w11, [x10], #0x28
100017378:     	add	x9, x9, #0x1
10001737c:     	cmp	x20, x9
100017380:     	b.ne	0x100017360 <_benchAllocationMutation__Int+0x260>
100017384:     	mov	x9, #0x0                ; =0
100017388:     	add	x10, x8, #0x20
10001738c:     	ldp	q0, q1, [x10, #-0x20]
100017390:     	fadd.2d	v0, v0, v1
100017394:     	stur	q0, [x10, #-0x20]
100017398:     	ldr	w11, [x10]
10001739c:     	sub	w11, w11, #0x1
1000173a0:     	str	w11, [x10], #0x28
1000173a4:     	add	x9, x9, #0x1
1000173a8:     	cmp	x20, x9
1000173ac:     	b.ne	0x10001738c <_benchAllocationMutation__Int+0x28c>
1000173b0:     	mov	x9, #0x0                ; =0
1000173b4:     	add	x10, x8, #0x20
1000173b8:     	ldp	q0, q1, [x10, #-0x20]
1000173bc:     	fadd.2d	v0, v0, v1
1000173c0:     	stur	q0, [x10, #-0x20]
1000173c4:     	ldr	w11, [x10]
1000173c8:     	sub	w11, w11, #0x1
1000173cc:     	str	w11, [x10], #0x28
1000173d0:     	add	x9, x9, #0x1
1000173d4:     	cmp	x20, x9
1000173d8:     	b.ne	0x1000173b8 <_benchAllocationMutation__Int+0x2b8>
1000173dc:     	mov	x9, #0x0                ; =0
1000173e0:     	add	x10, x8, #0x20
1000173e4:     	ldp	q0, q1, [x10, #-0x20]
1000173e8:     	fadd.2d	v0, v0, v1
1000173ec:     	stur	q0, [x10, #-0x20]
1000173f0:     	ldr	w11, [x10]
1000173f4:     	sub	w11, w11, #0x1
1000173f8:     	str	w11, [x10], #0x28
1000173fc:     	add	x9, x9, #0x1
100017400:     	cmp	x20, x9
100017404:     	b.ne	0x1000173e4 <_benchAllocationMutation__Int+0x2e4>
100017408:     	mov	x9, #0x0                ; =0
10001740c:     	add	x10, x8, #0x20
100017410:     	ldp	q0, q1, [x10, #-0x20]
100017414:     	fadd.2d	v0, v0, v1
100017418:     	stur	q0, [x10, #-0x20]
10001741c:     	ldr	w11, [x10]
100017420:     	sub	w11, w11, #0x1
100017424:     	str	w11, [x10], #0x28
100017428:     	add	x9, x9, #0x1
10001742c:     	cmp	x20, x9
100017430:     	b.ne	0x100017410 <_benchAllocationMutation__Int+0x310>
100017434:     	mov	x9, #0x0                ; =0
100017438:     	add	x10, x8, #0x20
10001743c:     	ldp	q0, q1, [x10, #-0x20]
100017440:     	fadd.2d	v0, v0, v1
100017444:     	stur	q0, [x10, #-0x20]
100017448:     	ldr	w11, [x10]
10001744c:     	sub	w11, w11, #0x1
100017450:     	str	w11, [x10], #0x28
100017454:     	add	x9, x9, #0x1
100017458:     	cmp	x20, x9
10001745c:     	b.ne	0x10001743c <_benchAllocationMutation__Int+0x33c>
100017460:     	mov	x9, #0x0                ; =0
100017464:     	add	x10, x8, #0x20
100017468:     	ldp	q0, q1, [x10, #-0x20]
10001746c:     	fadd.2d	v0, v0, v1
100017470:     	stur	q0, [x10, #-0x20]
100017474:     	ldr	w11, [x10]
100017478:     	sub	w11, w11, #0x1
10001747c:     	str	w11, [x10], #0x28
100017480:     	add	x9, x9, #0x1
100017484:     	cmp	x20, x9
100017488:     	b.ne	0x100017468 <_benchAllocationMutation__Int+0x368>
10001748c:     	mov	x9, #0x0                ; =0
100017490:     	add	x10, x8, #0x20
100017494:     	ldp	q0, q1, [x10, #-0x20]
100017498:     	fadd.2d	v0, v0, v1
10001749c:     	stur	q0, [x10, #-0x20]
1000174a0:     	ldr	w11, [x10]
1000174a4:     	sub	w11, w11, #0x1
1000174a8:     	str	w11, [x10], #0x28
1000174ac:     	add	x9, x9, #0x1
1000174b0:     	cmp	x20, x9
1000174b4:     	b.ne	0x100017494 <_benchAllocationMutation__Int+0x394>
1000174b8:     	mov	x9, #0x0                ; =0
1000174bc:     	add	x10, x8, #0x20
1000174c0:     	ldp	q0, q1, [x10, #-0x20]
1000174c4:     	fadd.2d	v0, v0, v1
1000174c8:     	stur	q0, [x10, #-0x20]
1000174cc:     	ldr	w11, [x10]
1000174d0:     	sub	w11, w11, #0x1
1000174d4:     	str	w11, [x10], #0x28
1000174d8:     	add	x9, x9, #0x1
1000174dc:     	cmp	x20, x9
1000174e0:     	b.ne	0x1000174c0 <_benchAllocationMutation__Int+0x3c0>
1000174e4:     	mov	x9, #0x0                ; =0
1000174e8:     	add	x10, x8, #0x20
1000174ec:     	ldp	q0, q1, [x10, #-0x20]
1000174f0:     	fadd.2d	v0, v0, v1
1000174f4:     	stur	q0, [x10, #-0x20]
1000174f8:     	ldr	w11, [x10]
1000174fc:     	sub	w11, w11, #0x1
100017500:     	str	w11, [x10], #0x28
100017504:     	add	x9, x9, #0x1
100017508:     	cmp	x20, x9
10001750c:     	b.ne	0x1000174ec <_benchAllocationMutation__Int+0x3ec>
100017510:     	mov	x9, #0x0                ; =0
100017514:     	add	x10, x8, #0x20
100017518:     	ldp	q0, q1, [x10, #-0x20]
10001751c:     	fadd.2d	v0, v0, v1
100017520:     	stur	q0, [x10, #-0x20]
100017524:     	ldr	w11, [x10]
100017528:     	sub	w11, w11, #0x1
10001752c:     	str	w11, [x10], #0x28
100017530:     	add	x9, x9, #0x1
100017534:     	cmp	x20, x9
100017538:     	b.ne	0x100017518 <_benchAllocationMutation__Int+0x418>
10001753c:     	mov	x9, #0x0                ; =0
100017540:     	add	x10, x8, #0x20
100017544:     	ldp	q0, q1, [x10, #-0x20]
100017548:     	fadd.2d	v0, v0, v1
10001754c:     	stur	q0, [x10, #-0x20]
100017550:     	ldr	w11, [x10]
100017554:     	sub	w11, w11, #0x1
100017558:     	str	w11, [x10], #0x28
10001755c:     	add	x9, x9, #0x1
100017560:     	cmp	x20, x9
100017564:     	b.ne	0x100017544 <_benchAllocationMutation__Int+0x444>
100017568:     	mov	x9, #0x0                ; =0
10001756c:     	add	x10, x8, #0x20
100017570:     	ldp	q0, q1, [x10, #-0x20]
100017574:     	fadd.2d	v0, v0, v1
100017578:     	stur	q0, [x10, #-0x20]
10001757c:     	ldr	w11, [x10]
100017580:     	sub	w11, w11, #0x1
100017584:     	str	w11, [x10], #0x28
100017588:     	add	x9, x9, #0x1
10001758c:     	cmp	x20, x9
100017590:     	b.ne	0x100017570 <_benchAllocationMutation__Int+0x470>
100017594:     	mov	x9, #0x0                ; =0
100017598:     	add	x10, x8, #0x20
10001759c:     	ldp	q0, q1, [x10, #-0x20]
1000175a0:     	fadd.2d	v0, v0, v1
1000175a4:     	stur	q0, [x10, #-0x20]
1000175a8:     	ldr	w11, [x10]
1000175ac:     	sub	w11, w11, #0x1
1000175b0:     	str	w11, [x10], #0x28
1000175b4:     	add	x9, x9, #0x1
1000175b8:     	cmp	x20, x9
1000175bc:     	b.ne	0x10001759c <_benchAllocationMutation__Int+0x49c>
1000175c0:     	mov	x9, #0x0                ; =0
1000175c4:     	add	x10, x8, #0x20
1000175c8:     	ldp	q0, q1, [x10, #-0x20]
1000175cc:     	fadd.2d	v0, v0, v1
1000175d0:     	stur	q0, [x10, #-0x20]
1000175d4:     	ldr	w11, [x10]
1000175d8:     	sub	w11, w11, #0x1
1000175dc:     	str	w11, [x10], #0x28
1000175e0:     	add	x9, x9, #0x1
1000175e4:     	cmp	x20, x9
1000175e8:     	b.ne	0x1000175c8 <_benchAllocationMutation__Int+0x4c8>
1000175ec:     	mov	x9, #0x0                ; =0
1000175f0:     	add	x10, x8, #0x20
1000175f4:     	ldp	q0, q1, [x10, #-0x20]
1000175f8:     	fadd.2d	v0, v0, v1
1000175fc:     	stur	q0, [x10, #-0x20]
100017600:     	ldr	w11, [x10]
100017604:     	sub	w11, w11, #0x1
100017608:     	str	w11, [x10], #0x28
10001760c:     	add	x9, x9, #0x1
100017610:     	cmp	x20, x9
100017614:     	b.ne	0x1000175f4 <_benchAllocationMutation__Int+0x4f4>
100017618:     	mov	x9, #0x0                ; =0
10001761c:     	add	x8, x8, #0x20
100017620:     	ldp	q0, q1, [x8, #-0x20]
100017624:     	fadd.2d	v0, v0, v1
100017628:     	stur	q0, [x8, #-0x20]
10001762c:     	ldr	w10, [x8]
100017630:     	sub	w10, w10, #0x1
100017634:     	str	w10, [x8], #0x28
100017638:     	add	x9, x9, #0x1
10001763c:     	cmp	x20, x9
100017640:     	b.ne	0x100017620 <_benchAllocationMutation__Int+0x520>
100017644:     	b	0x100017974 <_benchAllocationMutation__Int+0x874>
100017648:     	cmp	w20, #0x1
10001764c:     	b.lt	0x100017974 <_benchAllocationMutation__Int+0x874>
100017650:     	ldr	x8, [x19]
100017654:     	add	x9, x8, #0x20
100017658:     	mov	x10, x20
10001765c:     	ldp	q0, q1, [x9, #-0x20]
100017660:     	fadd.2d	v0, v0, v1
100017664:     	stur	q0, [x9, #-0x20]
100017668:     	ldr	w11, [x9]
10001766c:     	sub	w11, w11, #0x1
100017670:     	str	w11, [x9], #0x28
100017674:     	subs	x10, x10, #0x1
100017678:     	b.ne	0x10001765c <_benchAllocationMutation__Int+0x55c>
10001767c:     	add	x9, x8, #0x20
100017680:     	mov	x10, x20
100017684:     	ldp	q0, q1, [x9, #-0x20]
100017688:     	fadd.2d	v0, v0, v1
10001768c:     	stur	q0, [x9, #-0x20]
100017690:     	ldr	w11, [x9]
100017694:     	sub	w11, w11, #0x1
100017698:     	str	w11, [x9], #0x28
10001769c:     	subs	x10, x10, #0x1
1000176a0:     	b.ne	0x100017684 <_benchAllocationMutation__Int+0x584>
1000176a4:     	add	x9, x8, #0x20
1000176a8:     	mov	x10, x20
1000176ac:     	ldp	q0, q1, [x9, #-0x20]
1000176b0:     	fadd.2d	v0, v0, v1
1000176b4:     	stur	q0, [x9, #-0x20]
1000176b8:     	ldr	w11, [x9]
1000176bc:     	sub	w11, w11, #0x1
1000176c0:     	str	w11, [x9], #0x28
1000176c4:     	subs	x10, x10, #0x1
1000176c8:     	b.ne	0x1000176ac <_benchAllocationMutation__Int+0x5ac>
1000176cc:     	add	x9, x8, #0x20
1000176d0:     	mov	x10, x20
1000176d4:     	ldp	q0, q1, [x9, #-0x20]
1000176d8:     	fadd.2d	v0, v0, v1
1000176dc:     	stur	q0, [x9, #-0x20]
1000176e0:     	ldr	w11, [x9]
1000176e4:     	sub	w11, w11, #0x1
1000176e8:     	str	w11, [x9], #0x28
1000176ec:     	subs	x10, x10, #0x1
1000176f0:     	b.ne	0x1000176d4 <_benchAllocationMutation__Int+0x5d4>
1000176f4:     	add	x9, x8, #0x20
1000176f8:     	mov	x10, x20
1000176fc:     	ldp	q0, q1, [x9, #-0x20]
100017700:     	fadd.2d	v0, v0, v1
100017704:     	stur	q0, [x9, #-0x20]
100017708:     	ldr	w11, [x9]
10001770c:     	sub	w11, w11, #0x1
100017710:     	str	w11, [x9], #0x28
100017714:     	subs	x10, x10, #0x1
100017718:     	b.ne	0x1000176fc <_benchAllocationMutation__Int+0x5fc>
10001771c:     	add	x9, x8, #0x20
100017720:     	mov	x10, x20
100017724:     	ldp	q0, q1, [x9, #-0x20]
100017728:     	fadd.2d	v0, v0, v1
10001772c:     	stur	q0, [x9, #-0x20]
100017730:     	ldr	w11, [x9]
100017734:     	sub	w11, w11, #0x1
100017738:     	str	w11, [x9], #0x28
10001773c:     	subs	x10, x10, #0x1
100017740:     	b.ne	0x100017724 <_benchAllocationMutation__Int+0x624>
100017744:     	add	x9, x8, #0x20
100017748:     	mov	x10, x20
10001774c:     	ldp	q0, q1, [x9, #-0x20]
100017750:     	fadd.2d	v0, v0, v1
100017754:     	stur	q0, [x9, #-0x20]
100017758:     	ldr	w11, [x9]
10001775c:     	sub	w11, w11, #0x1
100017760:     	str	w11, [x9], #0x28
100017764:     	subs	x10, x10, #0x1
100017768:     	b.ne	0x10001774c <_benchAllocationMutation__Int+0x64c>
10001776c:     	add	x9, x8, #0x20
100017770:     	mov	x10, x20
100017774:     	ldp	q0, q1, [x9, #-0x20]
100017778:     	fadd.2d	v0, v0, v1
10001777c:     	stur	q0, [x9, #-0x20]
100017780:     	ldr	w11, [x9]
100017784:     	sub	w11, w11, #0x1
100017788:     	str	w11, [x9], #0x28
10001778c:     	subs	x10, x10, #0x1
100017790:     	b.ne	0x100017774 <_benchAllocationMutation__Int+0x674>
100017794:     	add	x9, x8, #0x20
100017798:     	mov	x10, x20
10001779c:     	ldp	q0, q1, [x9, #-0x20]
1000177a0:     	fadd.2d	v0, v0, v1
1000177a4:     	stur	q0, [x9, #-0x20]
1000177a8:     	ldr	w11, [x9]
1000177ac:     	sub	w11, w11, #0x1
1000177b0:     	str	w11, [x9], #0x28
1000177b4:     	subs	x10, x10, #0x1
1000177b8:     	b.ne	0x10001779c <_benchAllocationMutation__Int+0x69c>
1000177bc:     	add	x9, x8, #0x20
1000177c0:     	mov	x10, x20
1000177c4:     	ldp	q0, q1, [x9, #-0x20]
1000177c8:     	fadd.2d	v0, v0, v1
1000177cc:     	stur	q0, [x9, #-0x20]
1000177d0:     	ldr	w11, [x9]
1000177d4:     	sub	w11, w11, #0x1
1000177d8:     	str	w11, [x9], #0x28
1000177dc:     	subs	x10, x10, #0x1
1000177e0:     	b.ne	0x1000177c4 <_benchAllocationMutation__Int+0x6c4>
1000177e4:     	add	x9, x8, #0x20
1000177e8:     	mov	x10, x20
1000177ec:     	ldp	q0, q1, [x9, #-0x20]
1000177f0:     	fadd.2d	v0, v0, v1
1000177f4:     	stur	q0, [x9, #-0x20]
1000177f8:     	ldr	w11, [x9]
1000177fc:     	sub	w11, w11, #0x1
100017800:     	str	w11, [x9], #0x28
100017804:     	subs	x10, x10, #0x1
100017808:     	b.ne	0x1000177ec <_benchAllocationMutation__Int+0x6ec>
10001780c:     	add	x9, x8, #0x20
100017810:     	mov	x10, x20
100017814:     	ldp	q0, q1, [x9, #-0x20]
100017818:     	fadd.2d	v0, v0, v1
10001781c:     	stur	q0, [x9, #-0x20]
100017820:     	ldr	w11, [x9]
100017824:     	sub	w11, w11, #0x1
100017828:     	str	w11, [x9], #0x28
10001782c:     	subs	x10, x10, #0x1
100017830:     	b.ne	0x100017814 <_benchAllocationMutation__Int+0x714>
100017834:     	add	x9, x8, #0x20
100017838:     	mov	x10, x20
10001783c:     	ldp	q0, q1, [x9, #-0x20]
100017840:     	fadd.2d	v0, v0, v1
100017844:     	stur	q0, [x9, #-0x20]
100017848:     	ldr	w11, [x9]
10001784c:     	sub	w11, w11, #0x1
100017850:     	str	w11, [x9], #0x28
100017854:     	subs	x10, x10, #0x1
100017858:     	b.ne	0x10001783c <_benchAllocationMutation__Int+0x73c>
10001785c:     	add	x9, x8, #0x20
100017860:     	mov	x10, x20
100017864:     	ldp	q0, q1, [x9, #-0x20]
100017868:     	fadd.2d	v0, v0, v1
10001786c:     	stur	q0, [x9, #-0x20]
100017870:     	ldr	w11, [x9]
100017874:     	sub	w11, w11, #0x1
100017878:     	str	w11, [x9], #0x28
10001787c:     	subs	x10, x10, #0x1
100017880:     	b.ne	0x100017864 <_benchAllocationMutation__Int+0x764>
100017884:     	add	x9, x8, #0x20
100017888:     	mov	x10, x20
10001788c:     	ldp	q0, q1, [x9, #-0x20]
100017890:     	fadd.2d	v0, v0, v1
100017894:     	stur	q0, [x9, #-0x20]
100017898:     	ldr	w11, [x9]
10001789c:     	sub	w11, w11, #0x1
1000178a0:     	str	w11, [x9], #0x28
1000178a4:     	subs	x10, x10, #0x1
1000178a8:     	b.ne	0x10001788c <_benchAllocationMutation__Int+0x78c>
1000178ac:     	add	x9, x8, #0x20
1000178b0:     	mov	x10, x20
1000178b4:     	ldp	q0, q1, [x9, #-0x20]
1000178b8:     	fadd.2d	v0, v0, v1
1000178bc:     	stur	q0, [x9, #-0x20]
1000178c0:     	ldr	w11, [x9]
1000178c4:     	sub	w11, w11, #0x1
1000178c8:     	str	w11, [x9], #0x28
1000178cc:     	subs	x10, x10, #0x1
1000178d0:     	b.ne	0x1000178b4 <_benchAllocationMutation__Int+0x7b4>
1000178d4:     	add	x9, x8, #0x20
1000178d8:     	mov	x10, x20
1000178dc:     	ldp	q0, q1, [x9, #-0x20]
1000178e0:     	fadd.2d	v0, v0, v1
1000178e4:     	stur	q0, [x9, #-0x20]
1000178e8:     	ldr	w11, [x9]
1000178ec:     	sub	w11, w11, #0x1
1000178f0:     	str	w11, [x9], #0x28
1000178f4:     	subs	x10, x10, #0x1
1000178f8:     	b.ne	0x1000178dc <_benchAllocationMutation__Int+0x7dc>
1000178fc:     	add	x9, x8, #0x20
100017900:     	mov	x10, x20
100017904:     	ldp	q0, q1, [x9, #-0x20]
100017908:     	fadd.2d	v0, v0, v1
10001790c:     	stur	q0, [x9, #-0x20]
100017910:     	ldr	w11, [x9]
100017914:     	sub	w11, w11, #0x1
100017918:     	str	w11, [x9], #0x28
10001791c:     	subs	x10, x10, #0x1
100017920:     	b.ne	0x100017904 <_benchAllocationMutation__Int+0x804>
100017924:     	add	x9, x8, #0x20
100017928:     	mov	x10, x20
10001792c:     	ldp	q0, q1, [x9, #-0x20]
100017930:     	fadd.2d	v0, v0, v1
100017934:     	stur	q0, [x9, #-0x20]
100017938:     	ldr	w11, [x9]
10001793c:     	sub	w11, w11, #0x1
100017940:     	str	w11, [x9], #0x28
100017944:     	subs	x10, x10, #0x1
100017948:     	b.ne	0x10001792c <_benchAllocationMutation__Int+0x82c>
10001794c:     	add	x8, x8, #0x20
100017950:     	mov	x9, x20
100017954:     	ldp	q0, q1, [x8, #-0x20]
100017958:     	fadd.2d	v0, v0, v1
10001795c:     	stur	q0, [x8, #-0x20]
100017960:     	ldr	w10, [x8]
100017964:     	sub	w10, w10, #0x1
100017968:     	str	w10, [x8], #0x28
10001796c:     	subs	x9, x9, #0x1
100017970:     	b.ne	0x100017954 <_benchAllocationMutation__Int+0x854>
100017974:     	ldrsw	x8, [x19, #0x24]
100017978:     	ldr	w9, [x19, #0x8]
10001797c:     	cmp	w8, #0x28
100017980:     	ccmp	w20, w9, #0x0, eq
100017984:     	b.le	0x100017a08 <_benchAllocationMutation__Int+0x908>
100017988:     	cmp	w20, #0x1
10001798c:     	b.lt	0x100017a68 <_benchAllocationMutation__Int+0x968>
100017990:     	mov	x9, #0x0                ; =0
100017994:     	mov	w21, #0x0               ; =0
100017998:     	ldr	x10, [x19]
10001799c:     	mov	w11, #0x2f99            ; =12185
1000179a0:     	movk	w11, #0x44b8, lsl #16
1000179a4:     	mov	w12, #0xca07            ; =51719
1000179a8:     	movk	w12, #0x3b9a, lsl #16
1000179ac:     	mov	x13, x10
1000179b0:     	b	0x1000179f8 <_benchAllocationMutation__Int+0x8f8>
1000179b4:     	ldp	d0, d1, [x14]
1000179b8:     	fcvtzs	w15, d0
1000179bc:     	add	w15, w21, w15
1000179c0:     	fcvtzs	w16, d1
1000179c4:     	ldr	w14, [x14, #0x20]
1000179c8:     	add	w14, w16, w14
1000179cc:     	add	w14, w15, w14
1000179d0:     	smull	x15, w14, w11
1000179d4:     	lsr	x16, x15, #32
1000179d8:     	asr	w16, w16, #28
1000179dc:     	add	x15, x16, x15, lsr #63
1000179e0:     	msub	w21, w15, w12, w14
1000179e4:     	add	x9, x9, #0x1
1000179e8:     	add	x13, x13, #0x8
1000179ec:     	add	x10, x10, x8
1000179f0:     	cmp	x20, x9
1000179f4:     	b.eq	0x100017a6c <_benchAllocationMutation__Int+0x96c>
1000179f8:     	mov	x14, x10
1000179fc:     	cbnz	w8, 0x1000179b4 <_benchAllocationMutation__Int+0x8b4>
100017a00:     	ldr	x14, [x13]
100017a04:     	b	0x1000179b4 <_benchAllocationMutation__Int+0x8b4>
100017a08:     	cmp	w20, #0x1
100017a0c:     	b.lt	0x100017a68 <_benchAllocationMutation__Int+0x968>
100017a10:     	mov	w21, #0x0               ; =0
100017a14:     	ldr	x8, [x19]
100017a18:     	mov	w9, #0x2f99             ; =12185
100017a1c:     	movk	w9, #0x44b8, lsl #16
100017a20:     	mov	w10, #0xca07            ; =51719
100017a24:     	movk	w10, #0x3b9a, lsl #16
100017a28:     	ldp	d0, d1, [x8]
100017a2c:     	fcvtzs	w11, d0
100017a30:     	add	w11, w21, w11
100017a34:     	fcvtzs	w12, d1
100017a38:     	ldr	w13, [x8, #0x20]
100017a3c:     	add	w12, w12, w13
100017a40:     	add	w11, w11, w12
100017a44:     	smull	x12, w11, w9
100017a48:     	lsr	x13, x12, #32
100017a4c:     	asr	w13, w13, #28
100017a50:     	add	x12, x13, x12, lsr #63
100017a54:     	msub	w21, w12, w10, w11
100017a58:     	add	x8, x8, #0x28
100017a5c:     	subs	x20, x20, #0x1
100017a60:     	b.ne	0x100017a28 <_benchAllocationMutation__Int+0x928>
100017a64:     	b	0x100017a6c <_benchAllocationMutation__Int+0x96c>
100017a68:     	mov	w21, #0x0               ; =0
100017a6c:     	mov	x0, x19
100017a70:     	bl	0x10001d9d4 <_list_release>
100017a74:     	mov	x0, x21
100017a78:     	ldp	x29, x30, [sp, #0x30]
100017a7c:     	ldp	x20, x19, [sp, #0x20]
100017a80:     	ldp	x22, x21, [sp, #0x10]
100017a84:     	add	sp, sp, #0x40
100017a88:     	ret

