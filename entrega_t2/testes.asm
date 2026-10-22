; Testes da Parte I.
;
; Os processos abaixo são executados em modo usuário. Eles só fazem E/S
; chamando trap 7; não usam in/out/inb/outb nem halt.
;
        .equ    T_SO_LE             = 0
        .equ    T_SO_ESCREVE        = 1
        .equ    T_SO_CRIA_PROC      = 2
        .equ    T_SO_MATA_PROC      = 3

; ---------------------------------------------------------------------- init
;
; PID 1 é reservado para init. Ele cria três processos, escreve uma marca e
; mata a si próprio. A morte de init faz o kernel escolher o primeiro pronto.

init_codigo:
        ld      r0, T_SO_CRIA_PROC
        ld      r1, processo_a
        trap    7

        ld      r0, T_SO_CRIA_PROC
        ld      r1, processo_b
        trap    7

        ld      r0, T_SO_CRIA_PROC
        ld      r1, processo_c
        trap    7

        ld      r0, T_SO_ESCREVE
        ld      r1, 'I'
        trap    7

        ld      r0, T_SO_MATA_PROC
        ld      r1, 1
        trap    7

init_fim:
        ; Só seria alcançado se SO_MATA_PROC falhasse.
        jmp     init_fim

; ---------------------------------------------------------------- processo A
;
; A recebe PID 2 na sequência de criação feita por init.

processo_a:
        ld      r0, T_SO_ESCREVE
        ld      r1, 'A'
        trap    7

        ld      r0, T_SO_MATA_PROC
        ld      r1, 2
        trap    7

processo_a_fim:
        jmp     processo_a_fim

; ---------------------------------------------------------------- processo B
;
; B recebe PID 3.

processo_b:
        ld      r0, T_SO_ESCREVE
        ld      r1, 'B'
        trap    7

        ld      r0, T_SO_MATA_PROC
        ld      r1, 3
        trap    7

processo_b_fim:
        jmp     processo_b_fim

; ---------------------------------------------------------------- processo C
;
; C recebe PID 4 e termina a demonstração com uma quebra de linha.

processo_c:
        ld      r0, T_SO_ESCREVE
        ld      r1, 'C'
        trap    7

        ld      r0, SO_ESCREVE
        ld      r1, 10
        trap    7

        ld      r0, T_SO_MATA_PROC
        ld      r1, 4
        trap    7

processo_c_fim:
        jmp     processo_c_fim

; --------------------------------------------------------------- teste SO_LE
;
; Este processo é opcional: para testá-lo, troque processo_c por processo_leitor
; em uma das chamadas SO_CRIA_PROC de init. Ele recebe o próximo PID disponível,
; lê um caractere com espera ocupada, ecoa-o e então deve ser adaptado para
; matar a si próprio com o PID correspondente.

processo_leitor:
        ld      r0, T_SO_LE
        trap    7
        ld      r1, r0

        ld      r0, T_SO_ESCREVE
        trap    7

processo_leitor_fim:
        jmp     processo_leitor_fim

