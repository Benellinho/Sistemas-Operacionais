; Cargas da Parte III.
;
; O init cria três cargas e espera seus términos. O processo CPU-bound consome
; instruções sem syscall para demonstrar preempção. O processo de E/S bloqueia
; em SO_LE. O criador gera um filho, espera sua morte e termina.
;
        .equ    T_SO_LE             = 0
        .equ    T_SO_ESCREVE        = 1
        .equ    T_SO_CRIA_PROC      = 2
        .equ    T_SO_MATA_PROC      = 3
        .equ    T_SO_ESPERA_PROC    = 4

; ---------------------------------------------------------------------- init

; PID 1: CPU=2, E/S=3 e criador=4. O init só termina depois dos três.
init_codigo:
        ld      r0, T_SO_CRIA_PROC
        ld      r1, processo_cpu_bound
        trap    7

        ld      r0, T_SO_CRIA_PROC
        ld      r1, processo_io
        trap    7

        ld      r0, T_SO_CRIA_PROC
        ld      r1, processo_criador
        trap    7

        ld      r0, T_SO_ESCREVE
        ld      r1, 'I'
        trap    7

        ld      r0, T_SO_ESPERA_PROC
        ld      r1, 2
        trap    7

        ld      r0, T_SO_ESPERA_PROC
        ld      r1, 3
        trap    7

        ld      r0, T_SO_ESPERA_PROC
        ld      r1, 4
        trap    7

        ld      r0, T_SO_ESCREVE
        ld      r1, 10
        trap    7

        ld      r0, T_SO_MATA_PROC
        ld      r1, 1
        trap    7

init_fim:
        jmp     init_fim

; --------------------------------------------------------- CPU-bound PID 2

; Não chama syscall durante o laço. Com INTERVALO_RELOGIO=4000 e
; QUANTUM_TICKS=2, a execução precisa ser interrompida pelo relógio.
processo_cpu_bound:
        ld      r2, 12000
cpu_bound_laco:
        add     r2, -1
        cmp     r2, 0
        jmpc    gt, cpu_bound_laco

        ld      r0, T_SO_ESCREVE
        ld      r1, 'U'
        trap    7
        ld      r0, T_SO_MATA_PROC
        ld      r1, 2
        trap    7
processo_cpu_bound_fim:
        jmp     processo_cpu_bound_fim

; -------------------------------------------------------------- E/S PID 3

; Fica bloqueado até o operador enviar um caractere com Ex. O caractere é
; ecoado e o processo termina, acordando o init.
processo_io:
        ld      r0, T_SO_LE
        trap    7
        ld      r1, r0
        ld      r0, T_SO_ESCREVE
        trap    7
        ld      r0, T_SO_MATA_PROC
        ld      r1, 3
        trap    7
processo_io_fim:
        jmp     processo_io_fim

; --------------------------------------------------------- criador PID 4

; Cria o filho PID 5, espera sua morte e termina depois dele.
processo_criador:
        ld      r0, T_SO_CRIA_PROC
        ld      r1, processo_filho
        trap    7

        ld      r0, T_SO_ESPERA_PROC
        ld      r1, 5
        trap    7

        ld      r0, T_SO_ESCREVE
        ld      r1, 'R'
        trap    7
        ld      r0, T_SO_MATA_PROC
        ld      r1, 4
        trap    7
processo_criador_fim:
        jmp     processo_criador_fim

; -------------------------------------------------------------- filho PID 5

processo_filho:
        ld      r0, T_SO_ESCREVE
        ld      r1, 'C'
        trap    7
        ld      r0, T_SO_MATA_PROC
        ld      r1, 5
        trap    7
processo_filho_fim:
        jmp     processo_filho_fim
