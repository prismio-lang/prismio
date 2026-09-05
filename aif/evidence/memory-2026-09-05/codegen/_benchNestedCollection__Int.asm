00000001000126a8 <_benchNestedCollection__Int>:
1000126a8:     	stp	x26, x25, [sp, #-0x50]!
1000126ac:     	stp	x24, x23, [sp, #0x10]
1000126b0:     	stp	x22, x21, [sp, #0x20]
1000126b4:     	stp	x20, x19, [sp, #0x30]
1000126b8:     	stp	x29, x30, [sp, #0x40]
1000126bc:     	mov	w8, #0xc8               ; =200
1000126c0:     	mul	w19, w0, w8
1000126c4:     	bl	0x10001443c <_rt_arena_hint_push>
1000126c8:     	mov	x0, x19
1000126cc:     	bl	0x100016840 <_list_new_with_capacity>
1000126d0:     	mov	x20, x0
1000126d4:     	bl	0x10001449c <_rt_arena_hint_pop>
1000126d8:     	cmp	w19, #0x1
1000126dc:     	b.lt	0x1000128c0 <_benchNestedCollection__Int+0x218>
1000126e0:     	mov	w23, #0x0               ; =0
1000126e4:     	mov	w24, #0x4837            ; =18487
1000126e8:     	movk	w24, #0x8060, lsl #16
1000126ec:     	mov	w25, #0x3fd             ; =1021
1000126f0:     	mov	w26, #0x1               ; =1
1000126f4:     	b	0x100012714 <_benchNestedCollection__Int+0x6c>
1000126f8:     	ldr	x9, [x20]
1000126fc:     	str	x21, [x9, w8, sxtw #3]
100012700:     	add	w8, w8, #0x1
100012704:     	str	w8, [x20, #0x8]
100012708:     	add	w23, w23, #0x1
10001270c:     	cmp	w23, w19
100012710:     	b.eq	0x100012828 <_benchNestedCollection__Int+0x180>
100012714:     	bl	0x10001443c <_rt_arena_hint_push>
100012718:     	mov	w0, #0x3e8              ; =1000
10001271c:     	bl	0x100016840 <_list_new_with_capacity>
100012720:     	mov	x22, x0
100012724:     	bl	0x10001449c <_rt_arena_hint_pop>
100012728:     	mov	x0, x22
10001272c:     	mov	w1, #0x4                ; =4
100012730:     	bl	0x100016868 <_list_set_elem_inline>
100012734:     	mov	w21, #0x0               ; =0
100012738:     	b	0x100012754 <_benchNestedCollection__Int+0xac>
10001273c:     	mov	x0, x22
100012740:     	mov	w2, #0x4                ; =4
100012744:     	bl	0x100017394 <_list_push_inline_scalar_slow>
100012748:     	add	w21, w21, #0x1
10001274c:     	cmp	w21, #0x3e8
100012750:     	b.eq	0x1000127a0 <_benchNestedCollection__Int+0xf8>
100012754:     	add	w8, w23, w21
100012758:     	smull	x9, w8, w24
10001275c:     	add	x9, x8, x9, lsr #32
100012760:     	asr	w10, w9, #9
100012764:     	add	w9, w10, w9, lsr #31
100012768:     	msub	w1, w9, w25, w8
10001276c:     	ldr	w8, [x22, #0x24]
100012770:     	cmp	w8, #0x4
100012774:     	b.ne	0x10001273c <_benchNestedCollection__Int+0x94>
100012778:     	ldp	w8, w9, [x22, #0x8]
10001277c:     	sxtw	x8, w8
100012780:     	cmp	w8, w9
100012784:     	b.ge	0x10001273c <_benchNestedCollection__Int+0x94>
100012788:     	ldr	x9, [x22]
10001278c:     	str	w1, [x9, x8, lsl #2]
100012790:     	ldr	w8, [x22, #0x8]
100012794:     	add	w8, w8, #0x1
100012798:     	str	w8, [x22, #0x8]
10001279c:     	b	0x100012748 <_benchNestedCollection__Int+0xa0>
1000127a0:     	mov	w0, #0x8                ; =8
1000127a4:     	bl	0x100015530 <_arena_alloc>
1000127a8:     	mov	x21, x0
1000127ac:     	str	x22, [x0]
1000127b0:     	ldr	w8, [x20, #0x10]
1000127b4:     	cmp	w8, #0x5
1000127b8:     	b.eq	0x1000127d4 <_benchNestedCollection__Int+0x12c>
1000127bc:     	cmp	w8, #0x3
1000127c0:     	b.ne	0x1000127e0 <_benchNestedCollection__Int+0x138>
1000127c4:     	ldur	x8, [x21, #-0x8]
1000127c8:     	add	x8, x8, #0x1
1000127cc:     	stur	x8, [x21, #-0x8]
1000127d0:     	b	0x10001280c <_benchNestedCollection__Int+0x164>
1000127d4:     	mov	x0, x21
1000127d8:     	bl	0x100016230 <_cyc_retain>
1000127dc:     	ldr	w8, [x20, #0x10]
1000127e0:     	cmp	w8, #0x6
1000127e4:     	b.ne	0x1000127f4 <_benchNestedCollection__Int+0x14c>
1000127e8:     	sub	x8, x21, #0x8
1000127ec:     	ldadd	x26, x8, [x8]
1000127f0:     	ldr	w8, [x20, #0x10]
1000127f4:     	cmp	w8, #0x7
1000127f8:     	b.ne	0x10001280c <_benchNestedCollection__Int+0x164>
1000127fc:     	sub	x8, x21, #0x8
100012800:     	ldadd	x26, x8, [x8]
100012804:     	mov	x0, x21
100012808:     	bl	0x100016230 <_cyc_retain>
10001280c:     	ldp	w8, w9, [x20, #0x8]
100012810:     	cmp	w8, w9
100012814:     	b.lt	0x1000126f8 <_benchNestedCollection__Int+0x50>
100012818:     	mov	x0, x20
10001281c:     	bl	0x1000177b8 <_list_push_grow>
100012820:     	ldr	w8, [x20, #0x8]
100012824:     	b	0x1000126f8 <_benchNestedCollection__Int+0x50>
100012828:     	mov	x8, #0x0                ; =0
10001282c:     	mov	w0, #0x0                ; =0
100012830:     	ldr	x9, [x20]
100012834:     	mov	w10, #0x2f99            ; =12185
100012838:     	movk	w10, #0x44b8, lsl #16
10001283c:     	mov	w11, #0xca07            ; =51719
100012840:     	movk	w11, #0x3b9a, lsl #16
100012844:     	b	0x100012854 <_benchNestedCollection__Int+0x1ac>
100012848:     	add	x8, x8, #0x1
10001284c:     	cmp	x8, x19
100012850:     	b.eq	0x1000128c4 <_benchNestedCollection__Int+0x21c>
100012854:     	ldr	x12, [x9, x8, lsl #3]
100012858:     	ldr	x13, [x12]
10001285c:     	ldr	w12, [x13, #0x8]
100012860:     	cmp	w12, #0x1
100012864:     	b.lt	0x100012848 <_benchNestedCollection__Int+0x1a0>
100012868:     	ldr	w14, [x13, #0x24]
10001286c:     	ldr	x13, [x13]
100012870:     	cmp	w14, #0x4
100012874:     	b.ne	0x10001289c <_benchNestedCollection__Int+0x1f4>
100012878:     	ldr	w14, [x13], #0x4
10001287c:     	add	w14, w14, w0
100012880:     	smull	x15, w14, w10
100012884:     	asr	x16, x15, #60
100012888:     	add	x15, x16, x15, lsr #63
10001288c:     	msub	w0, w15, w11, w14
100012890:     	subs	x12, x12, #0x1
100012894:     	b.ne	0x100012878 <_benchNestedCollection__Int+0x1d0>
100012898:     	b	0x100012848 <_benchNestedCollection__Int+0x1a0>
10001289c:     	ldr	w14, [x13], #0x8
1000128a0:     	add	w14, w0, w14
1000128a4:     	smull	x15, w14, w10
1000128a8:     	asr	x16, x15, #60
1000128ac:     	add	x15, x16, x15, lsr #63
1000128b0:     	msub	w0, w15, w11, w14
1000128b4:     	subs	x12, x12, #0x1
1000128b8:     	b.ne	0x10001289c <_benchNestedCollection__Int+0x1f4>
1000128bc:     	b	0x100012848 <_benchNestedCollection__Int+0x1a0>
1000128c0:     	mov	w0, #0x0                ; =0
1000128c4:     	ldp	x29, x30, [sp, #0x40]
1000128c8:     	ldp	x20, x19, [sp, #0x30]
1000128cc:     	ldp	x22, x21, [sp, #0x20]
1000128d0:     	ldp	x24, x23, [sp, #0x10]
1000128d4:     	ldp	x26, x25, [sp], #0x50
1000128d8:     	ret

