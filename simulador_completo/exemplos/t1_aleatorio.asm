; Inicio do T1: um unico programa Assembly para o Mancha.
; Gera um numero pseudoaleatorio de 0 a 255 e imprime tres digitos.
; Com a semente 7, a primeira saida e 036 seguida de nova linha.
; A mesma semente repete a sequencia: ainda nao varia entre execucoes.

        .equ pilha = 0x3F0
        .org 0
        .dw main, pilha, 0, 0

        .org 0x80
main:
        call gera_numero
        call imprime_numero
        ld r0, 10                   ; ASCII da quebra de linha
        out r0, (1)
        halt

; Atualiza o estado: semente = (5 * semente + 1) modulo 256.
; Saida: r0 entre 0 e 255. Altera r0 e flags.
; AND com 255 conserva os oito bits baixos (resto por 256).
gera_numero:
        ld r0, (semente)
        mul r0, 5
        add r0, 1
        and r0, 255
        st r0, (semente)
        ret

; Entrada: r0 entre 0 e 255. Saida: tres caracteres, como 007 ou 255.
; Altera r0 e flags; preserva r1 e r2 com a pilha.
imprime_numero:
        push r1
        push r2
        ld r1, 0                    ; centenas
        ld r2, 0                    ; dezenas
centenas:
        cmp r0, 100
        jmpc lt, dezenas
        sub r0, 100
        add r1, 1
        jmp centenas
dezenas:
        cmp r0, 10
        jmpc lt, escreve
        sub r0, 10
        add r2, 1
        jmp dezenas
escreve:
        add r1, 48                  ; numero -> caractere ASCII
        out r1, (1)
        add r2, 48
        out r2, (1)
        add r0, 48                  ; resto: unidades
        out r0, (1)
        pop r2
        pop r1
        ret

        .data
semente: .dw 7                      ; troque por outro valor de 0 a 255
