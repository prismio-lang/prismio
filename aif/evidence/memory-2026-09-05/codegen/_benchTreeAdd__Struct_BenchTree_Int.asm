0000000100012ccc <_benchTreeAdd__Struct_BenchTree_Int>:
100012ccc:     	ldr	w8, [x0]
100012cd0:     	cmp	w8, #0x1
100012cd4:     	b.eq	0x100012d34 <_benchTreeAdd__Struct_BenchTree_Int+0x68>
100012cd8:     	stp	x22, x21, [sp, #-0x30]!
100012cdc:     	stp	x20, x19, [sp, #0x10]
100012ce0:     	stp	x29, x30, [sp, #0x20]
100012ce4:     	cmp	w8, #0x2
100012ce8:     	b.ne	0x100012d48 <_benchTreeAdd__Struct_BenchTree_Int+0x7c>
100012cec:     	ldr	w22, [x0, #0x4]
100012cf0:     	ldp	x8, x19, [x0, #0x8]
100012cf4:     	mov	w9, #0x2                ; =2
100012cf8:     	str	w9, [x0]
100012cfc:     	mov	x21, x0
100012d00:     	mov	x0, x8
100012d04:     	mov	x20, x1
100012d08:     	bl	0x100012ccc <_benchTreeAdd__Struct_BenchTree_Int>
100012d0c:     	str	x0, [x21, #0x8]
100012d10:     	add	w8, w22, w20
100012d14:     	str	w8, [x21, #0x4]
100012d18:     	mov	x0, x19
100012d1c:     	mov	x1, x20
100012d20:     	bl	0x100012ccc <_benchTreeAdd__Struct_BenchTree_Int>
100012d24:     	mov	x8, x0
100012d28:     	mov	x0, x21
100012d2c:     	str	x8, [x21, #0x10]
100012d30:     	b	0x100012d64 <_benchTreeAdd__Struct_BenchTree_Int+0x98>
100012d34:     	str	w8, [x0]
100012d38:     	stur	xzr, [x0, #0xc]
100012d3c:     	stur	xzr, [x0, #0x4]
100012d40:     	str	wzr, [x0, #0x14]
100012d44:     	ret
100012d48:     	mov	w0, #0x18               ; =24
100012d4c:     	bl	0x10001a26c <_system+0x10001a26c>
100012d50:     	mov	w8, #0x1                ; =1
100012d54:     	str	w8, [x0]
100012d58:     	stur	xzr, [x0, #0xc]
100012d5c:     	stur	xzr, [x0, #0x4]
100012d60:     	str	wzr, [x0, #0x14]
100012d64:     	ldp	x29, x30, [sp, #0x20]
100012d68:     	ldp	x20, x19, [sp, #0x10]
100012d6c:     	ldp	x22, x21, [sp], #0x30
100012d70:     	ret

