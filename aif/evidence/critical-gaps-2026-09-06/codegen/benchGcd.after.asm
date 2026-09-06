000000010000be90 <_benchGcd__Int_Int>:
10000be90:     	cbz	w1, 0x10000beac <_benchGcd__Int_Int+0x1c>
10000be94:     	mov	x8, x1
10000be98:     	sdiv	w9, w0, w1
10000be9c:     	msub	w1, w9, w1, w0
10000bea0:     	mov	x0, x8
10000bea4:     	cbnz	w1, 0x10000be94 <_benchGcd__Int_Int+0x4>
10000bea8:     	mov	x0, x8
10000beac:     	ret

