000000010000cfd0 <_benchKnapsack__Int>:
10000cfd0:     	sub	sp, sp, #0x70
10000cfd4:     	stp	x28, x27, [sp, #0x10]
10000cfd8:     	stp	x26, x25, [sp, #0x20]
10000cfdc:     	stp	x24, x23, [sp, #0x30]
10000cfe0:     	stp	x22, x21, [sp, #0x40]
10000cfe4:     	stp	x20, x19, [sp, #0x50]
10000cfe8:     	stp	x29, x30, [sp, #0x60]
10000cfec:     	mov	w8, #0x320              ; =800
10000cff0:     	mul	w20, w0, w8
10000cff4:     	bl	0x10001443c <_rt_arena_hint_push>
10000cff8:     	orr	w0, w20, #0x1
10000cffc:     	bl	0x100016840 <_list_new_with_capacity>
10000d000:     	mov	x19, x0
10000d004:     	bl	0x10001449c <_rt_arena_hint_pop>
10000d008:     	mov	x0, x19
10000d00c:     	mov	w1, #0x4                ; =4
10000d010:     	bl	0x100016868 <_list_set_elem_inline>
10000d014:     	str	x20, [sp, #0x8]
10000d018:     	tbnz	w20, #0x1f, 0x10000d078 <_benchKnapsack__Int+0xa8>
10000d01c:     	ldr	x8, [sp, #0x8]
10000d020:     	add	w20, w8, #0x1
10000d024:     	b	0x10000d040 <_benchKnapsack__Int+0x70>
10000d028:     	mov	x0, x19
10000d02c:     	mov	x1, #0x0                ; =0
10000d030:     	mov	w2, #0x4                ; =4
10000d034:     	bl	0x100017394 <_list_push_inline_scalar_slow>
10000d038:     	subs	w20, w20, #0x1
10000d03c:     	b.eq	0x10000d078 <_benchKnapsack__Int+0xa8>
10000d040:     	ldr	w8, [x19, #0x24]
10000d044:     	cmp	w8, #0x4
10000d048:     	b.ne	0x10000d028 <_benchKnapsack__Int+0x58>
10000d04c:     	ldp	w8, w9, [x19, #0x8]
10000d050:     	sxtw	x8, w8
10000d054:     	cmp	w8, w9
10000d058:     	b.ge	0x10000d028 <_benchKnapsack__Int+0x58>
10000d05c:     	ldr	x9, [x19]
10000d060:     	str	wzr, [x9, x8, lsl #2]
10000d064:     	ldr	w8, [x19, #0x8]
10000d068:     	add	w8, w8, #0x1
10000d06c:     	str	w8, [x19, #0x8]
10000d070:     	subs	w20, w20, #0x1
10000d074:     	b.ne	0x10000d040 <_benchKnapsack__Int+0x70>
10000d078:     	ldr	x8, [sp, #0x8]
10000d07c:     	sxtw	x22, w8
10000d080:     	sub	w23, w8, #0x26
10000d084:     	mov	w24, #0x1               ; =1
10000d088:     	mov	w25, #-0x26             ; =-38
10000d08c:     	mov	w26, #0x25              ; =37
10000d090:     	b	0x10000d0ac <_benchKnapsack__Int+0xdc>
10000d094:     	add	w24, w24, #0x1
10000d098:     	sub	w25, w25, #0x25
10000d09c:     	add	w26, w26, #0x25
10000d0a0:     	sub	w23, w23, #0x25
10000d0a4:     	cmp	w24, #0xb5
10000d0a8:     	b.eq	0x10000d268 <_benchKnapsack__Int+0x298>
10000d0ac:     	mov	w8, #0x25               ; =37
10000d0b0:     	mul	w8, w24, w8
10000d0b4:     	and	w9, w8, #0xffff
10000d0b8:     	mov	w10, #0x51d1            ; =20945
10000d0bc:     	mul	w9, w9, w10
10000d0c0:     	lsr	w9, w9, #16
10000d0c4:     	sub	w10, w8, w9
10000d0c8:     	and	w10, w10, #0xfffe
10000d0cc:     	add	w9, w9, w10, lsr #1
10000d0d0:     	lsr	w9, w9, #6
10000d0d4:     	mov	w10, #0x61              ; =97
10000d0d8:     	msub	w10, w9, w10, w8
10000d0dc:     	and	w8, w10, #0xffff
10000d0e0:     	ldr	x9, [sp, #0x8]
10000d0e4:     	cmp	w9, w8
10000d0e8:     	b.le	0x10000d094 <_benchKnapsack__Int+0xc4>
10000d0ec:     	mov	w9, #0x7eaf             ; =32431
10000d0f0:     	movk	w9, #0x51d0, lsl #16
10000d0f4:     	umull	x9, w26, w9
10000d0f8:     	lsr	x9, x9, #32
10000d0fc:     	sub	w11, w26, w9
10000d100:     	add	w9, w9, w11, lsr #1
10000d104:     	lsr	w9, w9, #6
10000d108:     	mov	w11, #0x61              ; =97
10000d10c:     	mul	w9, w9, w11
10000d110:     	add	w21, w25, w9
10000d114:     	mov	w11, #0x35              ; =53
10000d118:     	mul	w11, w24, w11
10000d11c:     	and	w12, w11, #0xffff
10000d120:     	mov	w13, #0x9b4d            ; =39757
10000d124:     	mul	w12, w12, w13
10000d128:     	lsr	w12, w12, #23
10000d12c:     	mov	w13, #0xd3              ; =211
10000d130:     	msub	w11, w12, w13, w11
10000d134:     	add	w11, w11, #0x1
10000d138:     	and	w27, w11, #0xffff
10000d13c:     	ldrsw	x11, [x19, #0x8]
10000d140:     	and	x28, x10, #0xffff
10000d144:     	mov	x20, x22
10000d148:     	ldr	x10, [sp, #0x8]
10000d14c:     	cmp	w10, w11
10000d150:     	b.ge	0x10000d1cc <_benchKnapsack__Int+0x1fc>
10000d154:     	ldr	w10, [x19, #0x24]
10000d158:     	mov	x20, x22
10000d15c:     	cmp	w10, #0x4
10000d160:     	b.ne	0x10000d1cc <_benchKnapsack__Int+0x1fc>
10000d164:     	add	w8, w8, #0x1
10000d168:     	sub	x8, x22, w8, uxtw
10000d16c:     	mov	x20, x22
10000d170:     	cmp	x8, x11
10000d174:     	b.ge	0x10000d1cc <_benchKnapsack__Int+0x1fc>
10000d178:     	add	w8, w23, w9
10000d17c:     	mov	x9, x22
10000d180:     	b	0x10000d194 <_benchKnapsack__Int+0x1c4>
10000d184:     	sub	x9, x9, #0x1
10000d188:     	sub	w8, w8, #0x1
10000d18c:     	cmp	x9, x28
10000d190:     	b.le	0x10000d094 <_benchKnapsack__Int+0xc4>
10000d194:     	ldr	x10, [x19]
10000d198:     	ldr	w11, [x10, w8, sxtw #2]
10000d19c:     	ldr	w12, [x10, x9, lsl #2]
10000d1a0:     	add	w11, w11, w27
10000d1a4:     	cmp	w11, w12
10000d1a8:     	b.le	0x10000d184 <_benchKnapsack__Int+0x1b4>
10000d1ac:     	str	w11, [x10, x9, lsl #2]
10000d1b0:     	b	0x10000d184 <_benchKnapsack__Int+0x1b4>
10000d1b4:     	mov	x0, x19
10000d1b8:     	mov	x1, x20
10000d1bc:     	bl	0x100017230 <_list_set>
10000d1c0:     	sub	x20, x20, #0x1
10000d1c4:     	cmp	x20, x28
10000d1c8:     	b.le	0x10000d094 <_benchKnapsack__Int+0xc4>
10000d1cc:     	ldrsw	x8, [x19, #0x8]
10000d1d0:     	add	w9, w21, w20
10000d1d4:     	cmp	w9, w8
10000d1d8:     	b.hs	0x10000d1fc <_benchKnapsack__Int+0x22c>
10000d1dc:     	ldr	w11, [x19, #0x24]
10000d1e0:     	ldr	x10, [x19]
10000d1e4:     	cmp	w11, #0x4
10000d1e8:     	b.ne	0x10000d220 <_benchKnapsack__Int+0x250>
10000d1ec:     	ldr	w9, [x10, w9, sxtw #2]
10000d1f0:     	cmp	w8, w20
10000d1f4:     	b.hi	0x10000d208 <_benchKnapsack__Int+0x238>
10000d1f8:     	b	0x10000d22c <_benchKnapsack__Int+0x25c>
10000d1fc:     	mov	w9, #0x0                ; =0
10000d200:     	cmp	w8, w20
10000d204:     	b.ls	0x10000d22c <_benchKnapsack__Int+0x25c>
10000d208:     	ldr	w11, [x19, #0x24]
10000d20c:     	ldr	x10, [x19]
10000d210:     	cmp	w11, #0x4
10000d214:     	b.ne	0x10000d234 <_benchKnapsack__Int+0x264>
10000d218:     	ldr	w10, [x10, x20, lsl #2]
10000d21c:     	b	0x10000d238 <_benchKnapsack__Int+0x268>
10000d220:     	ldr	x9, [x10, w9, sxtw #3]
10000d224:     	cmp	w8, w20
10000d228:     	b.hi	0x10000d208 <_benchKnapsack__Int+0x238>
10000d22c:     	mov	w10, #0x0               ; =0
10000d230:     	b	0x10000d238 <_benchKnapsack__Int+0x268>
10000d234:     	ldr	x10, [x10, x20, lsl #3]
10000d238:     	add	w2, w9, w27
10000d23c:     	cmp	w2, w10
10000d240:     	b.le	0x10000d1c0 <_benchKnapsack__Int+0x1f0>
10000d244:     	ldr	w9, [x19, #0x24]
10000d248:     	cmp	w9, #0x4
10000d24c:     	b.ne	0x10000d1b4 <_benchKnapsack__Int+0x1e4>
10000d250:     	tbnz	x20, #0x3f, 0x10000d1c0 <_benchKnapsack__Int+0x1f0>
10000d254:     	cmp	x20, x8
10000d258:     	b.ge	0x10000d1c0 <_benchKnapsack__Int+0x1f0>
10000d25c:     	ldr	x8, [x19]
10000d260:     	str	w2, [x8, x20, lsl #2]
10000d264:     	b	0x10000d1c0 <_benchKnapsack__Int+0x1f0>
10000d268:     	ldr	w8, [x19, #0x8]
10000d26c:     	ldr	x9, [sp, #0x8]
10000d270:     	cmp	w9, w8
10000d274:     	b.hs	0x10000d290 <_benchKnapsack__Int+0x2c0>
10000d278:     	ldr	w9, [x19, #0x24]
10000d27c:     	ldr	x8, [x19]
10000d280:     	cmp	w9, #0x4
10000d284:     	b.ne	0x10000d298 <_benchKnapsack__Int+0x2c8>
10000d288:     	ldr	w0, [x8, x22, lsl #2]
10000d28c:     	b	0x10000d29c <_benchKnapsack__Int+0x2cc>
10000d290:     	mov	w0, #0x0                ; =0
10000d294:     	b	0x10000d29c <_benchKnapsack__Int+0x2cc>
10000d298:     	ldr	x0, [x8, x22, lsl #3]
10000d29c:     	ldp	x29, x30, [sp, #0x60]
10000d2a0:     	ldp	x20, x19, [sp, #0x50]
10000d2a4:     	ldp	x22, x21, [sp, #0x40]
10000d2a8:     	ldp	x24, x23, [sp, #0x30]
10000d2ac:     	ldp	x26, x25, [sp, #0x20]
10000d2b0:     	ldp	x28, x27, [sp, #0x10]
10000d2b4:     	add	sp, sp, #0x70
10000d2b8:     	ret

