0000000100017204 <_benchAllocationMutation__Int>:
100017204:     	sub	sp, sp, #0x40
100017208:     	stp	x22, x21, [sp, #0x10]
10001720c:     	stp	x20, x19, [sp, #0x20]
100017210:     	stp	x29, x30, [sp, #0x30]
100017214:     	mov	w8, #0x86a0             ; =34464
100017218:     	movk	w8, #0x1, lsl #16
10001721c:     	mul	w20, w0, w8
100017220:     	mov	x0, x20
100017224:     	bl	0x10001c864 <_list_new_with_capacity>
100017228:     	mov	x19, x0
10001722c:     	cbz	x0, 0x100017238 <_benchAllocationMutation__Int+0x34>
100017230:     	mov	w8, #0x1                ; =1
100017234:     	str	w8, [x19, #0x10]
100017238:     	mov	x0, x19
10001723c:     	mov	w1, #0x28               ; =40
100017240:     	bl	0x10001c88c <_list_set_elem_inline>
100017244:     	cmp	w20, #0x1
100017248:     	b.lt	0x1000172dc <_benchAllocationMutation__Int+0xd8>
10001724c:     	ldr	w8, [x19, #0x24]
100017250:     	ldpsw	x10, x9, [x19, #0x8]
100017254:     	sub	x9, x9, x10
100017258:     	cmp	w8, #0x28
10001725c:     	ccmp	x9, x20, #0x8, eq
100017260:     	b.ge	0x1000172a0 <_benchAllocationMutation__Int+0x9c>
100017264:     	adrp	x8, 0x100020000 <_chan_send+0x30>
100017268:     	ldr	q0, [x8, #0x670]
10001726c:     	str	q0, [sp]
100017270:     	mov	w21, #0x32              ; =50
100017274:     	mov	x22, x20
100017278:     	mov	x0, x19
10001727c:     	mov	w1, #0x28               ; =40
100017280:     	bl	0x10001ce24 <_list_push_slot>
100017284:     	stp	xzr, xzr, [x0]
100017288:     	ldr	q0, [sp]
10001728c:     	str	q0, [x0, #0x10]
100017290:     	str	w21, [x0, #0x20]
100017294:     	subs	w22, w22, #0x1
100017298:     	b.ne	0x100017278 <_benchAllocationMutation__Int+0x74>
10001729c:     	b	0x1000172dc <_benchAllocationMutation__Int+0xd8>
1000172a0:     	ldr	x8, [x19]
1000172a4:     	mov	w9, #0x28               ; =40
1000172a8:     	adrp	x10, 0x100020000 <_chan_send+0x30>
1000172ac:     	ldr	q0, [x10, #0x670]
1000172b0:     	mov	w10, #0x32              ; =50
1000172b4:     	mov	x11, x20
1000172b8:     	ldrsw	x12, [x19, #0x8]
1000172bc:     	add	w13, w12, #0x1
1000172c0:     	str	w13, [x19, #0x8]
1000172c4:     	smaddl	x12, w12, w9, x8
1000172c8:     	stp	xzr, xzr, [x12]
1000172cc:     	str	q0, [x12, #0x10]
1000172d0:     	str	w10, [x12, #0x20]
1000172d4:     	subs	w11, w11, #0x1
1000172d8:     	b.ne	0x1000172b8 <_benchAllocationMutation__Int+0xb4>
1000172dc:     	ldr	w9, [x19, #0x24]
1000172e0:     	ldr	w8, [x19, #0x8]
1000172e4:     	cmp	w9, #0x28
1000172e8:     	b.ne	0x100017674 <_benchAllocationMutation__Int+0x470>
1000172ec:     	cmp	w20, w8
1000172f0:     	b.le	0x100017744 <_benchAllocationMutation__Int+0x540>
1000172f4:     	cmp	w20, #0x1
1000172f8:     	b.lt	0x100017a70 <_benchAllocationMutation__Int+0x86c>
1000172fc:     	mov	x9, #0x0                ; =0
100017300:     	ldr	x8, [x19]
100017304:     	add	x10, x8, #0x20
100017308:     	ldp	q0, q1, [x10, #-0x20]
10001730c:     	fadd.2d	v0, v0, v1
100017310:     	stur	q0, [x10, #-0x20]
100017314:     	ldr	w11, [x10]
100017318:     	sub	w11, w11, #0x1
10001731c:     	str	w11, [x10], #0x28
100017320:     	add	x9, x9, #0x1
100017324:     	cmp	x20, x9
100017328:     	b.ne	0x100017308 <_benchAllocationMutation__Int+0x104>
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
100017354:     	b.ne	0x100017334 <_benchAllocationMutation__Int+0x130>
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
100017380:     	b.ne	0x100017360 <_benchAllocationMutation__Int+0x15c>
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
1000173ac:     	b.ne	0x10001738c <_benchAllocationMutation__Int+0x188>
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
1000173d8:     	b.ne	0x1000173b8 <_benchAllocationMutation__Int+0x1b4>
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
100017404:     	b.ne	0x1000173e4 <_benchAllocationMutation__Int+0x1e0>
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
100017430:     	b.ne	0x100017410 <_benchAllocationMutation__Int+0x20c>
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
10001745c:     	b.ne	0x10001743c <_benchAllocationMutation__Int+0x238>
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
100017488:     	b.ne	0x100017468 <_benchAllocationMutation__Int+0x264>
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
1000174b4:     	b.ne	0x100017494 <_benchAllocationMutation__Int+0x290>
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
1000174e0:     	b.ne	0x1000174c0 <_benchAllocationMutation__Int+0x2bc>
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
10001750c:     	b.ne	0x1000174ec <_benchAllocationMutation__Int+0x2e8>
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
100017538:     	b.ne	0x100017518 <_benchAllocationMutation__Int+0x314>
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
100017564:     	b.ne	0x100017544 <_benchAllocationMutation__Int+0x340>
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
100017590:     	b.ne	0x100017570 <_benchAllocationMutation__Int+0x36c>
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
1000175bc:     	b.ne	0x10001759c <_benchAllocationMutation__Int+0x398>
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
1000175e8:     	b.ne	0x1000175c8 <_benchAllocationMutation__Int+0x3c4>
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
100017614:     	b.ne	0x1000175f4 <_benchAllocationMutation__Int+0x3f0>
100017618:     	mov	x9, #0x0                ; =0
10001761c:     	add	x10, x8, #0x20
100017620:     	ldp	q0, q1, [x10, #-0x20]
100017624:     	fadd.2d	v0, v0, v1
100017628:     	stur	q0, [x10, #-0x20]
10001762c:     	ldr	w11, [x10]
100017630:     	sub	w11, w11, #0x1
100017634:     	str	w11, [x10], #0x28
100017638:     	add	x9, x9, #0x1
10001763c:     	cmp	x20, x9
100017640:     	b.ne	0x100017620 <_benchAllocationMutation__Int+0x41c>
100017644:     	mov	x9, #0x0                ; =0
100017648:     	add	x8, x8, #0x20
10001764c:     	ldp	q0, q1, [x8, #-0x20]
100017650:     	fadd.2d	v0, v0, v1
100017654:     	stur	q0, [x8, #-0x20]
100017658:     	ldr	w10, [x8]
10001765c:     	sub	w10, w10, #0x1
100017660:     	str	w10, [x8], #0x28
100017664:     	add	x9, x9, #0x1
100017668:     	cmp	x20, x9
10001766c:     	b.ne	0x10001764c <_benchAllocationMutation__Int+0x448>
100017670:     	b	0x100017a70 <_benchAllocationMutation__Int+0x86c>
100017674:     	mov	w9, #0x0                ; =0
100017678:     	b	0x100017688 <_benchAllocationMutation__Int+0x484>
10001767c:     	add	w9, w9, #0x1
100017680:     	cmp	w9, #0x14
100017684:     	b.eq	0x100017a70 <_benchAllocationMutation__Int+0x86c>
100017688:     	ldrsw	x10, [x19, #0x24]
10001768c:     	cmp	w10, #0x28
100017690:     	ccmp	w20, w8, #0x0, eq
100017694:     	b.le	0x1000176dc <_benchAllocationMutation__Int+0x4d8>
100017698:     	cmp	w20, #0x1
10001769c:     	b.lt	0x10001767c <_benchAllocationMutation__Int+0x478>
1000176a0:     	ldr	x12, [x19]
1000176a4:     	cbz	w10, 0x100017714 <_benchAllocationMutation__Int+0x510>
1000176a8:     	mov	x11, #0x0               ; =0
1000176ac:     	add	x12, x12, #0x20
1000176b0:     	ldp	q0, q1, [x12, #-0x20]
1000176b4:     	fadd.2d	v0, v0, v1
1000176b8:     	stur	q0, [x12, #-0x20]
1000176bc:     	ldr	w13, [x12]
1000176c0:     	sub	w13, w13, #0x1
1000176c4:     	str	w13, [x12]
1000176c8:     	add	x11, x11, #0x1
1000176cc:     	add	x12, x12, x10
1000176d0:     	cmp	x20, x11
1000176d4:     	b.ne	0x1000176b0 <_benchAllocationMutation__Int+0x4ac>
1000176d8:     	b	0x10001767c <_benchAllocationMutation__Int+0x478>
1000176dc:     	cmp	w20, #0x1
1000176e0:     	b.lt	0x10001767c <_benchAllocationMutation__Int+0x478>
1000176e4:     	ldr	x10, [x19]
1000176e8:     	add	x10, x10, #0x20
1000176ec:     	mov	x11, x20
1000176f0:     	ldp	q0, q1, [x10, #-0x20]
1000176f4:     	fadd.2d	v0, v0, v1
1000176f8:     	stur	q0, [x10, #-0x20]
1000176fc:     	ldr	w12, [x10]
100017700:     	sub	w12, w12, #0x1
100017704:     	str	w12, [x10], #0x28
100017708:     	subs	x11, x11, #0x1
10001770c:     	b.ne	0x1000176f0 <_benchAllocationMutation__Int+0x4ec>
100017710:     	b	0x10001767c <_benchAllocationMutation__Int+0x478>
100017714:     	mov	x10, #0x0               ; =0
100017718:     	ldr	x11, [x12, x10, lsl #3]
10001771c:     	ldp	q0, q1, [x11]
100017720:     	fadd.2d	v0, v0, v1
100017724:     	str	q0, [x11]
100017728:     	ldr	w13, [x11, #0x20]
10001772c:     	sub	w13, w13, #0x1
100017730:     	str	w13, [x11, #0x20]
100017734:     	add	x10, x10, #0x1
100017738:     	cmp	x20, x10
10001773c:     	b.ne	0x100017718 <_benchAllocationMutation__Int+0x514>
100017740:     	b	0x10001767c <_benchAllocationMutation__Int+0x478>
100017744:     	cmp	w20, #0x1
100017748:     	b.lt	0x100017a70 <_benchAllocationMutation__Int+0x86c>
10001774c:     	ldr	x8, [x19]
100017750:     	add	x9, x8, #0x20
100017754:     	mov	x10, x20
100017758:     	ldp	q0, q1, [x9, #-0x20]
10001775c:     	fadd.2d	v0, v0, v1
100017760:     	stur	q0, [x9, #-0x20]
100017764:     	ldr	w11, [x9]
100017768:     	sub	w11, w11, #0x1
10001776c:     	str	w11, [x9], #0x28
100017770:     	subs	x10, x10, #0x1
100017774:     	b.ne	0x100017758 <_benchAllocationMutation__Int+0x554>
100017778:     	add	x9, x8, #0x20
10001777c:     	mov	x10, x20
100017780:     	ldp	q0, q1, [x9, #-0x20]
100017784:     	fadd.2d	v0, v0, v1
100017788:     	stur	q0, [x9, #-0x20]
10001778c:     	ldr	w11, [x9]
100017790:     	sub	w11, w11, #0x1
100017794:     	str	w11, [x9], #0x28
100017798:     	subs	x10, x10, #0x1
10001779c:     	b.ne	0x100017780 <_benchAllocationMutation__Int+0x57c>
1000177a0:     	add	x9, x8, #0x20
1000177a4:     	mov	x10, x20
1000177a8:     	ldp	q0, q1, [x9, #-0x20]
1000177ac:     	fadd.2d	v0, v0, v1
1000177b0:     	stur	q0, [x9, #-0x20]
1000177b4:     	ldr	w11, [x9]
1000177b8:     	sub	w11, w11, #0x1
1000177bc:     	str	w11, [x9], #0x28
1000177c0:     	subs	x10, x10, #0x1
1000177c4:     	b.ne	0x1000177a8 <_benchAllocationMutation__Int+0x5a4>
1000177c8:     	add	x9, x8, #0x20
1000177cc:     	mov	x10, x20
1000177d0:     	ldp	q0, q1, [x9, #-0x20]
1000177d4:     	fadd.2d	v0, v0, v1
1000177d8:     	stur	q0, [x9, #-0x20]
1000177dc:     	ldr	w11, [x9]
1000177e0:     	sub	w11, w11, #0x1
1000177e4:     	str	w11, [x9], #0x28
1000177e8:     	subs	x10, x10, #0x1
1000177ec:     	b.ne	0x1000177d0 <_benchAllocationMutation__Int+0x5cc>
1000177f0:     	add	x9, x8, #0x20
1000177f4:     	mov	x10, x20
1000177f8:     	ldp	q0, q1, [x9, #-0x20]
1000177fc:     	fadd.2d	v0, v0, v1
100017800:     	stur	q0, [x9, #-0x20]
100017804:     	ldr	w11, [x9]
100017808:     	sub	w11, w11, #0x1
10001780c:     	str	w11, [x9], #0x28
100017810:     	subs	x10, x10, #0x1
100017814:     	b.ne	0x1000177f8 <_benchAllocationMutation__Int+0x5f4>
100017818:     	add	x9, x8, #0x20
10001781c:     	mov	x10, x20
100017820:     	ldp	q0, q1, [x9, #-0x20]
100017824:     	fadd.2d	v0, v0, v1
100017828:     	stur	q0, [x9, #-0x20]
10001782c:     	ldr	w11, [x9]
100017830:     	sub	w11, w11, #0x1
100017834:     	str	w11, [x9], #0x28
100017838:     	subs	x10, x10, #0x1
10001783c:     	b.ne	0x100017820 <_benchAllocationMutation__Int+0x61c>
100017840:     	add	x9, x8, #0x20
100017844:     	mov	x10, x20
100017848:     	ldp	q0, q1, [x9, #-0x20]
10001784c:     	fadd.2d	v0, v0, v1
100017850:     	stur	q0, [x9, #-0x20]
100017854:     	ldr	w11, [x9]
100017858:     	sub	w11, w11, #0x1
10001785c:     	str	w11, [x9], #0x28
100017860:     	subs	x10, x10, #0x1
100017864:     	b.ne	0x100017848 <_benchAllocationMutation__Int+0x644>
100017868:     	add	x9, x8, #0x20
10001786c:     	mov	x10, x20
100017870:     	ldp	q0, q1, [x9, #-0x20]
100017874:     	fadd.2d	v0, v0, v1
100017878:     	stur	q0, [x9, #-0x20]
10001787c:     	ldr	w11, [x9]
100017880:     	sub	w11, w11, #0x1
100017884:     	str	w11, [x9], #0x28
100017888:     	subs	x10, x10, #0x1
10001788c:     	b.ne	0x100017870 <_benchAllocationMutation__Int+0x66c>
100017890:     	add	x9, x8, #0x20
100017894:     	mov	x10, x20
100017898:     	ldp	q0, q1, [x9, #-0x20]
10001789c:     	fadd.2d	v0, v0, v1
1000178a0:     	stur	q0, [x9, #-0x20]
1000178a4:     	ldr	w11, [x9]
1000178a8:     	sub	w11, w11, #0x1
1000178ac:     	str	w11, [x9], #0x28
1000178b0:     	subs	x10, x10, #0x1
1000178b4:     	b.ne	0x100017898 <_benchAllocationMutation__Int+0x694>
1000178b8:     	add	x9, x8, #0x20
1000178bc:     	mov	x10, x20
1000178c0:     	ldp	q0, q1, [x9, #-0x20]
1000178c4:     	fadd.2d	v0, v0, v1
1000178c8:     	stur	q0, [x9, #-0x20]
1000178cc:     	ldr	w11, [x9]
1000178d0:     	sub	w11, w11, #0x1
1000178d4:     	str	w11, [x9], #0x28
1000178d8:     	subs	x10, x10, #0x1
1000178dc:     	b.ne	0x1000178c0 <_benchAllocationMutation__Int+0x6bc>
1000178e0:     	add	x9, x8, #0x20
1000178e4:     	mov	x10, x20
1000178e8:     	ldp	q0, q1, [x9, #-0x20]
1000178ec:     	fadd.2d	v0, v0, v1
1000178f0:     	stur	q0, [x9, #-0x20]
1000178f4:     	ldr	w11, [x9]
1000178f8:     	sub	w11, w11, #0x1
1000178fc:     	str	w11, [x9], #0x28
100017900:     	subs	x10, x10, #0x1
100017904:     	b.ne	0x1000178e8 <_benchAllocationMutation__Int+0x6e4>
100017908:     	add	x9, x8, #0x20
10001790c:     	mov	x10, x20
100017910:     	ldp	q0, q1, [x9, #-0x20]
100017914:     	fadd.2d	v0, v0, v1
100017918:     	stur	q0, [x9, #-0x20]
10001791c:     	ldr	w11, [x9]
100017920:     	sub	w11, w11, #0x1
100017924:     	str	w11, [x9], #0x28
100017928:     	subs	x10, x10, #0x1
10001792c:     	b.ne	0x100017910 <_benchAllocationMutation__Int+0x70c>
100017930:     	add	x9, x8, #0x20
100017934:     	mov	x10, x20
100017938:     	ldp	q0, q1, [x9, #-0x20]
10001793c:     	fadd.2d	v0, v0, v1
100017940:     	stur	q0, [x9, #-0x20]
100017944:     	ldr	w11, [x9]
100017948:     	sub	w11, w11, #0x1
10001794c:     	str	w11, [x9], #0x28
100017950:     	subs	x10, x10, #0x1
100017954:     	b.ne	0x100017938 <_benchAllocationMutation__Int+0x734>
100017958:     	add	x9, x8, #0x20
10001795c:     	mov	x10, x20
100017960:     	ldp	q0, q1, [x9, #-0x20]
100017964:     	fadd.2d	v0, v0, v1
100017968:     	stur	q0, [x9, #-0x20]
10001796c:     	ldr	w11, [x9]
100017970:     	sub	w11, w11, #0x1
100017974:     	str	w11, [x9], #0x28
100017978:     	subs	x10, x10, #0x1
10001797c:     	b.ne	0x100017960 <_benchAllocationMutation__Int+0x75c>
100017980:     	add	x9, x8, #0x20
100017984:     	mov	x10, x20
100017988:     	ldp	q0, q1, [x9, #-0x20]
10001798c:     	fadd.2d	v0, v0, v1
100017990:     	stur	q0, [x9, #-0x20]
100017994:     	ldr	w11, [x9]
100017998:     	sub	w11, w11, #0x1
10001799c:     	str	w11, [x9], #0x28
1000179a0:     	subs	x10, x10, #0x1
1000179a4:     	b.ne	0x100017988 <_benchAllocationMutation__Int+0x784>
1000179a8:     	add	x9, x8, #0x20
1000179ac:     	mov	x10, x20
1000179b0:     	ldp	q0, q1, [x9, #-0x20]
1000179b4:     	fadd.2d	v0, v0, v1
1000179b8:     	stur	q0, [x9, #-0x20]
1000179bc:     	ldr	w11, [x9]
1000179c0:     	sub	w11, w11, #0x1
1000179c4:     	str	w11, [x9], #0x28
1000179c8:     	subs	x10, x10, #0x1
1000179cc:     	b.ne	0x1000179b0 <_benchAllocationMutation__Int+0x7ac>
1000179d0:     	add	x9, x8, #0x20
1000179d4:     	mov	x10, x20
1000179d8:     	ldp	q0, q1, [x9, #-0x20]
1000179dc:     	fadd.2d	v0, v0, v1
1000179e0:     	stur	q0, [x9, #-0x20]
1000179e4:     	ldr	w11, [x9]
1000179e8:     	sub	w11, w11, #0x1
1000179ec:     	str	w11, [x9], #0x28
1000179f0:     	subs	x10, x10, #0x1
1000179f4:     	b.ne	0x1000179d8 <_benchAllocationMutation__Int+0x7d4>
1000179f8:     	add	x9, x8, #0x20
1000179fc:     	mov	x10, x20
100017a00:     	ldp	q0, q1, [x9, #-0x20]
100017a04:     	fadd.2d	v0, v0, v1
100017a08:     	stur	q0, [x9, #-0x20]
100017a0c:     	ldr	w11, [x9]
100017a10:     	sub	w11, w11, #0x1
100017a14:     	str	w11, [x9], #0x28
100017a18:     	subs	x10, x10, #0x1
100017a1c:     	b.ne	0x100017a00 <_benchAllocationMutation__Int+0x7fc>
100017a20:     	add	x9, x8, #0x20
100017a24:     	mov	x10, x20
100017a28:     	ldp	q0, q1, [x9, #-0x20]
100017a2c:     	fadd.2d	v0, v0, v1
100017a30:     	stur	q0, [x9, #-0x20]
100017a34:     	ldr	w11, [x9]
100017a38:     	sub	w11, w11, #0x1
100017a3c:     	str	w11, [x9], #0x28
100017a40:     	subs	x10, x10, #0x1
100017a44:     	b.ne	0x100017a28 <_benchAllocationMutation__Int+0x824>
100017a48:     	add	x8, x8, #0x20
100017a4c:     	mov	x9, x20
100017a50:     	ldp	q0, q1, [x8, #-0x20]
100017a54:     	fadd.2d	v0, v0, v1
100017a58:     	stur	q0, [x8, #-0x20]
100017a5c:     	ldr	w10, [x8]
100017a60:     	sub	w10, w10, #0x1
100017a64:     	str	w10, [x8], #0x28
100017a68:     	subs	x9, x9, #0x1
100017a6c:     	b.ne	0x100017a50 <_benchAllocationMutation__Int+0x84c>
100017a70:     	ldrsw	x8, [x19, #0x24]
100017a74:     	ldr	w9, [x19, #0x8]
100017a78:     	cmp	w8, #0x28
100017a7c:     	ccmp	w20, w9, #0x0, eq
100017a80:     	b.le	0x100017b04 <_benchAllocationMutation__Int+0x900>
100017a84:     	cmp	w20, #0x1
100017a88:     	b.lt	0x100017b64 <_benchAllocationMutation__Int+0x960>
100017a8c:     	mov	x9, #0x0                ; =0
100017a90:     	mov	w21, #0x0               ; =0
100017a94:     	ldr	x10, [x19]
100017a98:     	mov	w11, #0x2f99            ; =12185
100017a9c:     	movk	w11, #0x44b8, lsl #16
100017aa0:     	mov	w12, #0xca07            ; =51719
100017aa4:     	movk	w12, #0x3b9a, lsl #16
100017aa8:     	mov	x13, x10
100017aac:     	b	0x100017af4 <_benchAllocationMutation__Int+0x8f0>
100017ab0:     	ldp	d0, d1, [x14]
100017ab4:     	fcvtzs	w15, d0
100017ab8:     	add	w15, w21, w15
100017abc:     	fcvtzs	w16, d1
100017ac0:     	ldr	w14, [x14, #0x20]
100017ac4:     	add	w14, w16, w14
100017ac8:     	add	w14, w15, w14
100017acc:     	smull	x15, w14, w11
100017ad0:     	lsr	x16, x15, #32
100017ad4:     	asr	w16, w16, #28
100017ad8:     	add	x15, x16, x15, lsr #63
100017adc:     	msub	w21, w15, w12, w14
100017ae0:     	add	x9, x9, #0x1
100017ae4:     	add	x13, x13, #0x8
100017ae8:     	add	x10, x10, x8
100017aec:     	cmp	x20, x9
100017af0:     	b.eq	0x100017b68 <_benchAllocationMutation__Int+0x964>
100017af4:     	mov	x14, x10
100017af8:     	cbnz	w8, 0x100017ab0 <_benchAllocationMutation__Int+0x8ac>
100017afc:     	ldr	x14, [x13]
100017b00:     	b	0x100017ab0 <_benchAllocationMutation__Int+0x8ac>
100017b04:     	cmp	w20, #0x1
100017b08:     	b.lt	0x100017b64 <_benchAllocationMutation__Int+0x960>
100017b0c:     	mov	w21, #0x0               ; =0
100017b10:     	ldr	x8, [x19]
100017b14:     	mov	w9, #0x2f99             ; =12185
100017b18:     	movk	w9, #0x44b8, lsl #16
100017b1c:     	mov	w10, #0xca07            ; =51719
100017b20:     	movk	w10, #0x3b9a, lsl #16
100017b24:     	ldp	d0, d1, [x8]
100017b28:     	fcvtzs	w11, d0
100017b2c:     	add	w11, w21, w11
100017b30:     	fcvtzs	w12, d1
100017b34:     	ldr	w13, [x8, #0x20]
100017b38:     	add	w12, w12, w13
100017b3c:     	add	w11, w11, w12
100017b40:     	smull	x12, w11, w9
100017b44:     	lsr	x13, x12, #32
100017b48:     	asr	w13, w13, #28
100017b4c:     	add	x12, x13, x12, lsr #63
100017b50:     	msub	w21, w12, w10, w11
100017b54:     	add	x8, x8, #0x28
100017b58:     	subs	x20, x20, #0x1
100017b5c:     	b.ne	0x100017b24 <_benchAllocationMutation__Int+0x920>
100017b60:     	b	0x100017b68 <_benchAllocationMutation__Int+0x964>
100017b64:     	mov	w21, #0x0               ; =0
100017b68:     	mov	x0, x19
100017b6c:     	bl	0x10001da48 <_list_release>
100017b70:     	mov	x0, x21
100017b74:     	ldp	x29, x30, [sp, #0x30]
100017b78:     	ldp	x20, x19, [sp, #0x20]
100017b7c:     	ldp	x22, x21, [sp, #0x10]
100017b80:     	add	sp, sp, #0x40
100017b84:     	ret

