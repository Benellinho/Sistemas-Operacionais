; ===== código gerado por mcc, com semente variável =====
; t1_aleatorio.c foi usado somente como modelo/base inicial do trabalho.
; A implementação final foi feita diretamente sobre o Assembly gerado a
; partir desse arquivo C, sem alterar o compilador ou o simulador.
.text
_f_gera_numero:
	push bp
	ld bp, sp
	; O relógio só avança quando possui um limite diferente de zero.
	; Configuramos 0xFFFF para contar enquanto getchar aguarda uma entrada.
	ld r0, 255
	out r0, (0x22)              ; limite alto do relógio
	ld r0, 255
	out r0, (0x23)              ; limite baixo do relógio

	; A duração até o operador fornecer um caractere varia entre execuções.
	; getchar consome esse caractere e deixa seu valor em r0.
	call _f_getchar
	ld r2, r0                   ; primeira fonte de entropia: caractere
	in r1, (0x21)               ; segunda fonte: byte baixo do relógio

	; Mistura as fontes com a constante inicial e garante semente != 0.
	ld r0, (_g_semente)
	xor r0, r2
	xor r0, r1
	and r0, 255
	or r0, 1                    ; evita a semente degenerada zero
	st r0, (_g_semente)

	; LCG de 8 bits: semente = (5 * semente + 1) mod 256.
	; A saída final permanece na faixa completa de 0..255.
	ld r0, (_g_semente)
	mul r0, 5
	add r0, 1
	and r0, 255
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
