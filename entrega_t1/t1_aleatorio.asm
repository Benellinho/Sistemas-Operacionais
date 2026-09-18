; ===== código gerado por mcc =====
.text
_f_gera_numero:
	push bp
	ld bp, sp
	ld r0, 5
	push r0
	ld r0, (_g_semente)
	ld r1, r0
	pop r0
	mul r0, r1
	push r0
	ld r0, 1
	ld r1, r0
	pop r0
	add r0, r1
	push r0
	ld r0, 255
	ld r1, r0
	pop r0
	and r0, r1
	st r0, (_g_semente)
	ld r0, (_g_semente)
	ld sp, bp
	pop bp
	ret
	ld sp, bp
	pop bp
	ret
_f_main:
	push bp
	ld bp, sp
	sub sp, 2
	call _f_gera_numero
	st r0, (bp+-2)
	ld r0, (bp+-2)
	push r0
	call _f_print_int
	add sp, 2
	ld r0, 10
	push r0
	call _f_putchar
	add sp, 2
	ld r0, 0
	ld sp, bp
	pop bp
	ret
	ld sp, bp
	pop bp
	ret

.data
_g_semente:
	.dw 7

; ----- literais de string -----
