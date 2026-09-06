000000010000bedc <_benchGcd__Int_Int>:
10000bedc:     	cbz	w1, 0x10000bef8 <_benchGcd__Int_Int+0x1c>
10000bee0:     	mov	x8, x1
10000bee4:     	sdiv	w9, w0, w1
10000bee8:     	msub	w1, w9, w1, w0
10000beec:     	mov	x0, x8
10000bef0:     	cbnz	w1, 0x10000bee0 <_benchGcd__Int_Int+0x4>
10000bef4:     	mov	x0, x8
10000bef8:     	ret

