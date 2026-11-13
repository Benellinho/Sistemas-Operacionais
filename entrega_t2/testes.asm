; Testes da Parte II.
;
; Fluxo principal:
;   1. init valida erros de SO_ESPERA_PROC;
;   2. espera o processo curto, que morre e acorda init;
;   3. espera novamente o mesmo PID já morto;
;   4. cria um leitor e um processo que espera por ele;
;   5. sem entrada, ambos ficam bloqueados e o kernel entra em ocioso;
;   6. ao receber um caractere, o leitor é acordado e depois acorda o waiter.
;
        .equ    T_SO_LE             = 0
        .equ    T_SO_ESCREVE        = 1
        .equ    T_SO_CRIA_PROC      = 2
        .equ    T_SO_MATA_PROC      = 3
        .equ    T_SO_ESPERA_PROC    = 4

; ---------------------------------------------------------------------- init

init_codigo:
        ; PID inexistente deve produzir ERR_INVALIDO sem bloquear.
        ld      r0, T_SO_ESPERA_PROC
        ld      r1, 99
        trap    7
        cmp     r0, -1
        jmpc    ne, teste_falhou

        ; Esperar o próprio PID também deve produzir ERR_INVALIDO.
        ld      r0, T_SO_ESPERA_PROC
        ld      r1, 1
        trap    7
        cmp     r0, -1
        jmpc    ne, teste_falhou

        ld      r0, T_SO_ESCREVE
        ld      r1, 'T'
        trap    7

        ; O processo curto recebe PID 2 e termina sozinho.
        ld      r0, T_SO_CRIA_PROC
        ld      r1, processo_curto
        trap    7

        ; init bloqueia. A morte do PID 2 deve acordá-lo com retorno 0.
        ld      r0, T_SO_ESPERA_PROC
        ld      r1, 2
        trap    7
        cmp     r0, 0
        jmpc    ne, teste_falhou

        ; Esperar novamente um processo morto retorna imediatamente.
        ld      r0, T_SO_ESPERA_PROC
        ld      r1, 2
        trap    7
        cmp     r0, 0
        jmpc    ne, teste_falhou

        ld      r0, T_SO_ESCREVE
        ld      r1, 'D'
        trap    7

        ; O leitor recebe PID 3 e o waiter recebe PID 4.
        ld      r0, T_SO_CRIA_PROC
        ld      r1, processo_leitor
        trap    7

        ld      r0, T_SO_CRIA_PROC
        ld      r1, processo_espera
        trap    7

        ld      r0, T_SO_ESCREVE
        ld      r1, 'I'
        trap    7

        ; Ao terminar, init deixa o leitor ser escalonado.
        ld      r0, T_SO_MATA_PROC
        ld      r1, 1
        trap    7

teste_falhou:
        ld      r0, T_SO_ESCREVE
        ld      r1, 'F'
        trap    7
teste_falhou_laco:
        jmp     teste_falhou_laco

; ------------------------------------------------------------ processo curto

processo_curto:
        ld      r0, T_SO_MATA_PROC
        ld      r1, 2
        trap    7
processo_curto_fim:
        jmp     processo_curto_fim

; ----------------------------------------------------------- processo leitor

; PID 3. SO_LE deve bloquear quando a console estiver vazia. Depois de
; acordado, o caractere retorna em r0 e é ecoado pela syscall de escrita.
processo_leitor:
        ld      r0, T_SO_LE
        trap    7
        ld      r1, r0

        ld      r0, T_SO_ESCREVE
        trap    7

        ld      r0, T_SO_MATA_PROC
        ld      r1, 3
        trap    7
processo_leitor_fim:
        jmp     processo_leitor_fim

; ------------------------------------------------------------- processo wait

; PID 4. Fica bloqueado esperando o PID 3 e só continua depois da morte do
; leitor. A saída esperada com entrada "x" é: TDIxW\n.
processo_espera:
        ld      r0, T_SO_ESPERA_PROC
        ld      r1, 3
        trap    7

        ld      r0, T_SO_ESCREVE
        ld      r1, 'W'
        trap    7
        ld      r0, T_SO_ESCREVE
        ld      r1, 10
        trap    7

        ld      r0, T_SO_MATA_PROC
        ld      r1, 4
        trap    7
processo_espera_fim:
        jmp     processo_espera_fim
