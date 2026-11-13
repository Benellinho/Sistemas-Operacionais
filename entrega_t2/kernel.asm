; Parte II — mini sistema operacional do Mancha
;
; Implementação em Assembly para manter o controle explícito de:
;   - processos em modo usuário (S=0 e I=0);
;   - tabela de processos e PIDs monotônicos;
;   - quadros de 16 palavras;
;   - chamadas de sistema;
;   - escalonamento quando o processo atual morre ou bloqueia;
;   - bloqueio de leitura e espera por outro processo.
;
; Convenção das chamadas de sistema:
;   r0 = número da chamada
;   r1..r4 = argumentos
;   r0 = resultado
;
; A BIOS desta entrega oferece escrita síncrona: SO_ESCREVE conclui
; imediatamente porque o dispositivo não expõe estado de saída ocupado.

        .equ    MAX_PROCESSOS        = 8

        .equ    SO_LE               = 0
        .equ    SO_ESCREVE          = 1
        .equ    SO_CRIA_PROC        = 2
        .equ    SO_MATA_PROC        = 3
        .equ    SO_ESPERA_PROC      = 4

        .equ    ERR_INVALIDO        = -1
        .equ    ERR_NAO_IMPLEMENTADO = -2

        .equ    ESTADO_LIVRE        = 0
        .equ    ESTADO_PRONTO       = 1
        .equ    ESTADO_EXECUTANDO   = 2
        .equ    ESTADO_MORTO        = 3
        .equ    ESTADO_BLOQUEADO    = 4

        .equ    BLOQUEIO_NENHUM     = 0
        .equ    BLOQUEIO_LEITURA    = 1
        .equ    BLOQUEIO_ESCRITA    = 2
        .equ    BLOQUEIO_ESPERA     = 3

        .equ    PROCESSO_OCIOSO     = -1
        .equ    SR_SUPERVISOR       = 0xA000

        ; SR do usuário: S=0, I=0 e D=0.
        .equ    SR_USUARIO          = 0
        ; Limite suficiente para o código, dados e pilhas desta entrega.
        .equ    LIMITE_USUARIO      = 0xD000


; ---------------------------------------------------------------------- boot

_kernel_inicio:
        ; Instala as cinco entradas da interface do SO.
        ld      r0, SO_LE
        add     r0, r0
        add     r0, tabela_syscalls
        ld      r1, sys_le_impl
        st      r1, (r0)

        ld      r0, SO_ESCREVE
        add     r0, r0
        add     r0, tabela_syscalls
        ld      r1, sys_escreve_impl
        st      r1, (r0)

        ld      r0, SO_CRIA_PROC
        add     r0, r0
        add     r0, tabela_syscalls
        ld      r1, sys_cria_proc_impl
        st      r1, (r0)

        ld      r0, SO_MATA_PROC
        add     r0, r0
        add     r0, tabela_syscalls
        ld      r1, sys_mata_proc_impl
        st      r1, (r0)

        ld      r0, SO_ESPERA_PROC
        add     r0, r0
        add     r0, tabela_syscalls
        ld      r1, sys_espera_proc_impl
        st      r1, (r0)

        ; Habilita somente a interrupção da console. O relógio fica para a
        ; Parte III, que instalará um escalonador preemptivo.
        ld      r0, 1
        outb    r0, (0x30)

        ; A BIOS chama este hook depois de alimentar o buffer da console.
        ld      r0, kernel_trata_console
        st      r0, (retomada_console)

        call    kernel_inicializa

        ; O quadro 0 já está pronto em quadro_processo_0. Copie-o para o
        ; endereço fixo onde rete espera encontrar o contexto.
        ld      sp, pilha_sistema
        add     sp, -32
        ld      r0, quadro_ptrs
        ld      r0, (r0)
        ld      r1, sp
        call    bios_copia_quadro
        rete

; ------------------------------------------------------------- inicialização

kernel_inicializa:
        ld      r0, ESTADO_EXECUTANDO
        st      r0, (proc_estado)

        ld      r0, 1
        st      r0, (proc_pid)

        ld      r0, 2
        st      r0, (proximo_pid)

        ld      r0, 0
        st      r0, (processo_atual)
        ret

; -------------------------------------------------------------- buscas tabela

; Entrada: r1 = PID procurado.
; Saída:   r0 = índice da entrada ou -1.
proc_encontra_pid:
        ld      r0, 0
        ld      r2, 0
proc_pid_loop:
        cmp     r2, MAX_PROCESSOS
        jmpc    ge, proc_pid_nao_encontrado

        ld      r3, r2
        add     r3, r3
        add     r3, proc_estado
        ld      r4, (r3)
        cmp     r4, ESTADO_LIVRE
        jmpc    eq, proc_pid_proximo
        cmp     r4, ESTADO_MORTO
        jmpc    eq, proc_pid_proximo

        ld      r3, r2
        add     r3, r3
        add     r3, proc_pid
        ld      r4, (r3)
        cmp     r4, r1
        jmpc    eq, proc_pid_encontrado

proc_pid_proximo:
        add     r2, 1
        jmp     proc_pid_loop

proc_pid_encontrado:
        ld      r0, r2
        ret

proc_pid_nao_encontrado:
        ld      r0, ERR_INVALIDO
        ret

; Saída: r0 = primeira entrada livre/morta ou -1.
proc_encontra_entrada_livre:
        ld      r0, 0
        ld      r2, 0
proc_livre_loop:
        cmp     r2, MAX_PROCESSOS
        jmpc    ge, proc_livre_nao_encontrado

        ld      r3, r2
        add     r3, r3
        add     r3, proc_estado
        ld      r4, (r3)
        cmp     r4, ESTADO_LIVRE
        jmpc    eq, proc_livre_encontrado
        cmp     r4, ESTADO_MORTO
        jmpc    eq, proc_livre_encontrado

        add     r2, 1
        jmp     proc_livre_loop

proc_livre_encontrado:
        ld      r0, r2
        ret

proc_livre_nao_encontrado:
        ld      r0, ERR_INVALIDO
        ret

; Copia o quadro salvo do processo indicado para o quadro da interrupção.
proc_copia_para_sistema:
        ld      r2, r0
        add     r2, r2
        add     r2, quadro_ptrs
        ld      r0, (r2)
        ld      r1, (quadro_interrompido)
        call    bios_copia_quadro
        ret

; O handler da BIOS chama o kernel com profundidade diferente para syscall e
; console. Cada entrada grava o endereço do quadro em quadro_interrompido,
; evitando depender do sp depois de novas chamadas.
proc_registra_quadro_syscall:
        ld      r0, sp
        add     r0, 4
        st      r0, (quadro_interrompido)
        ret

proc_registra_quadro_console:
        ld      r0, sp
        add     r0, 6
        st      r0, (quadro_interrompido)
        ret

; Salva o quadro atual na área reservada do processo indicado por
; temporario_indice.
proc_salva_quadro_atual:
        ld      r0, (temporario_indice)
        add     r0, r0
        add     r0, quadro_ptrs
        ld      r0, (r0)
        ld      r1, (quadro_interrompido)
        ; bios_copia_quadro(origem, destino)
        ld      r2, r0
        ld      r0, r1
        ld      r1, r2
        call    bios_copia_quadro
        ret

; Coloca o resultado diretamente no r0 do quadro salvo.
; Entrada: r1 = índice do processo, r2 = resultado.
proc_grava_retorno:
        add     r1, r1
        add     r1, quadro_ptrs
        ld      r1, (r1)
        st      r2, (r1)
        ret

; Procura um PID mesmo que a entrada esteja morta. É usado pela espera para
; diferenciar PID inexistente de processo já terminado.
proc_encontra_pid_qualquer:
        ld      r0, 0
        ld      r2, 0
proc_pid_qualquer_loop:
        cmp     r2, MAX_PROCESSOS
        jmpc    ge, proc_pid_qualquer_nao_encontrado

        ld      r3, r2
        add     r3, r3
        add     r3, proc_estado
        ld      r4, (r3)
        cmp     r4, ESTADO_LIVRE
        jmpc    eq, proc_pid_qualquer_proximo

        ld      r3, r2
        add     r3, r3
        add     r3, proc_pid
        ld      r4, (r3)
        cmp     r4, r1
        jmpc    eq, proc_pid_qualquer_encontrado

proc_pid_qualquer_proximo:
        add     r2, 1
        jmp     proc_pid_qualquer_loop

proc_pid_qualquer_encontrado:
        ld      r0, r2
        ret

proc_pid_qualquer_nao_encontrado:
        ld      r0, ERR_INVALIDO
        ret

; Saída: r0 = primeira entrada com estado PRONTO ou -1.
proc_escolhe_pronto:
        ld      r0, 0
        ld      r2, 0
proc_pronto_loop:
        cmp     r2, MAX_PROCESSOS
        jmpc    ge, proc_pronto_nao_encontrado

        ld      r3, r2
        add     r3, r3
        add     r3, proc_estado
        ld      r4, (r3)
        cmp     r4, ESTADO_PRONTO
        jmpc    eq, proc_pronto_encontrado

        add     r2, 1
        jmp     proc_pronto_loop

proc_pronto_encontrado:
        ld      r0, r2
        ret

proc_pronto_nao_encontrado:
        ld      r0, ERR_INVALIDO
        ret

; --------------------------------------------------------- SO_LE (Parte II)

; SO_LE conclui imediatamente quando já há entrada no buffer. Caso contrário,
; salva o quadro do chamador e troca para outro processo pronto.
sys_le_impl:
        call    proc_registra_quadro_syscall
        call    bios_console_disponivel
        cmp     r0, 0
        jmpc    eq, sys_le_bloqueia
        call    bios_console_le
        ret

sys_le_bloqueia:
        ld      r0, (processo_atual)
        st      r0, (temporario_indice)

        ; motivo_bloqueio[atual] = BLOQUEIO_LEITURA
        add     r0, r0
        add     r0, proc_motivo
        ld      r1, BLOQUEIO_LEITURA
        st      r1, (r0)

        ; estado[atual] = BLOQUEADO
        ld      r0, (temporario_indice)
        add     r0, r0
        add     r0, proc_estado
        ld      r1, ESTADO_BLOQUEADO
        st      r1, (r0)

        call    proc_salva_quadro_atual
        call    proc_escalona_bloqueado
        ; O quadro já foi trocado. Não retorne ao dispatcher da syscall:
        ; rete deve restaurar o processo escolhido ou o quadro ocioso.
        rete

; ------------------------------------------------------ SO_ESCREVE (Parte I)

; Entrada: r1 = caractere.
; O processo de usuário não acessa a porta; a BIOS escreve em modo supervisor.
sys_escreve_impl:
        ld      r0, r1
        call    bios_putc
        ld      r0, 0
        ret

; Troca o processo atual depois que ele foi bloqueado. Se não houver nenhum
; pronto, restaura quadro_ocioso, que aguarda interrupções com S=1 e I=1.
proc_escalona_bloqueado:
        call    proc_escolhe_pronto
        cmp     r0, ERR_INVALIDO
        jmpc    eq, proc_escalona_ocioso

        st      r0, (processo_atual)
        ld      r2, r0
        add     r2, r2
        add     r2, proc_estado
        ld      r3, ESTADO_EXECUTANDO
        st      r3, (r2)
        call    proc_copia_para_sistema
        ret

proc_escalona_ocioso:
        ld      r0, PROCESSO_OCIOSO
        st      r0, (processo_atual)
        ld      r0, quadro_ocioso
        ld      r1, (quadro_interrompido)
        call    bios_copia_quadro
        ret

; A interrupção da console chega depois que a BIOS colocou todos os caracteres
; disponíveis no buffer circular. Acorde leitores em ordem de tabela, um por
; caractere, e se a CPU estava ociosa escolha imediatamente um deles.
kernel_trata_console:
        call    proc_registra_quadro_console
        call    proc_acorda_leitores

        ld      r0, (processo_atual)
        cmp     r0, PROCESSO_OCIOSO
        jmpc    ne, kernel_console_fim
        call    proc_escolhe_pronto
        cmp     r0, ERR_INVALIDO
        jmpc    eq, kernel_console_fim

        st      r0, (processo_atual)
        ld      r2, r0
        add     r2, r2
        add     r2, proc_estado
        ld      r3, ESTADO_EXECUTANDO
        st      r3, (r2)
        call    proc_copia_para_sistema

kernel_console_fim:
        ret

; Acorda todos os processos bloqueados em SO_LE enquanto houver caracteres.
proc_acorda_leitores:
proc_acorda_leitores_loop:
        call    bios_console_disponivel
        cmp     r0, 0
        jmpc    eq, proc_acorda_leitores_fim

        call    proc_encontra_leitor_bloqueado
        cmp     r0, ERR_INVALIDO
        jmpc    eq, proc_acorda_leitores_fim
        st      r0, (temporario_indice)

        call    bios_console_le
        st      r0, (temporario_resultado)

        ld      r1, (temporario_indice)
        ld      r2, (temporario_resultado)
        call    proc_grava_retorno

        ld      r0, (temporario_indice)
        add     r0, r0
        add     r0, proc_estado
        ld      r1, ESTADO_PRONTO
        st      r1, (r0)

        ld      r0, (temporario_indice)
        add     r0, r0
        add     r0, proc_motivo
        ld      r1, BLOQUEIO_NENHUM
        st      r1, (r0)
        jmp     proc_acorda_leitores_loop

proc_acorda_leitores_fim:
        ret

; Saída: r0 = índice de um processo bloqueado esperando leitura ou -1.
proc_encontra_leitor_bloqueado:
        ld      r0, 0
        ld      r2, 0
proc_leitor_loop:
        cmp     r2, MAX_PROCESSOS
        jmpc    ge, proc_leitor_nao_encontrado

        ld      r3, r2
        add     r3, r3
        add     r3, proc_estado
        ld      r4, (r3)
        cmp     r4, ESTADO_BLOQUEADO
        jmpc    ne, proc_leitor_proximo

        ld      r3, r2
        add     r3, r3
        add     r3, proc_motivo
        ld      r4, (r3)
        cmp     r4, BLOQUEIO_LEITURA
        jmpc    eq, proc_leitor_encontrado

proc_leitor_proximo:
        add     r2, 1
        jmp     proc_leitor_loop

proc_leitor_encontrado:
        ld      r0, r2
        ret

proc_leitor_nao_encontrado:
        ld      r0, ERR_INVALIDO
        ret

; ---------------------------------------------------- SO_CRIA_PROC (Parte I)

; Entrada: r1 = endereço de entrada do novo processo.
; Saída:   r0 = PID novo ou ERR_INVALIDO.
sys_cria_proc_impl:
        st      r1, (temporario_entrada)
        cmp     r1, 0
        jmpc    eq, sys_cria_erro

        call    proc_encontra_entrada_livre
        cmp     r0, ERR_INVALIDO
        jmpc    eq, sys_cria_erro
        st      r0, (temporario_indice)

        ; Marca a entrada como pronta.
        ld      r2, r0
        add     r2, r2
        add     r2, proc_estado
        ld      r3, ESTADO_PRONTO
        st      r3, (r2)

        ld      r2, (temporario_indice)
        add     r2, r2
        add     r2, proc_motivo
        ld      r3, BLOQUEIO_NENHUM
        st      r3, (r2)

        ld      r2, (temporario_indice)
        add     r2, r2
        add     r2, proc_espera_pid
        ld      r3, 0
        st      r3, (r2)

        ; Dá um PID novo e não reutilizável.
        ld      r3, (proximo_pid)
        ld      r4, r0
        add     r4, r4
        add     r4, proc_pid
        st      r3, (r4)
        add     r3, 1
        st      r3, (proximo_pid)

        ; Zera as 16 palavras do quadro salvo da entrada reutilizada.
        ld      r2, (temporario_indice)
        add     r2, r2
        add     r2, quadro_ptrs
        ld      r2, (r2)
        ld      r3, 0
        ld      r4, 0
sys_cria_zera_quadro:
        st      r3, (r2+)
        add     r4, 1
        cmp     r4, 16
        jmpc    lt, sys_cria_zera_quadro

        ; Quadro inicial: sp, ip, sr, cs/cl e ds/dl.
        ld      r2, (temporario_indice)
        add     r2, r2
        add     r2, quadro_ptrs
        ld      r2, (r2)
        add     r2, 12

        ld      r3, (temporario_indice)
        add     r3, r3
        add     r3, pilha_topos
        ld      r3, (r3)
        st      r3, (r2)
        add     r2, 2

        ld      r3, (temporario_entrada)
        st      r3, (r2)
        add     r2, 2

        ld      r3, SR_USUARIO
        st      r3, (r2)               ; sr
        add     r2, 2
        st      r3, (r2)               ; s1
        add     r2, 2
        st      r3, (r2)               ; s2
        add     r2, 2
        st      r3, (r2)               ; s3
        add     r2, 2
        st      r3, (r2)               ; cs
        add     r2, 2

        ld      r3, LIMITE_USUARIO
        st      r3, (r2)               ; cl
        add     r2, 2
        ld      r3, SR_USUARIO
        st      r3, (r2)               ; ds
        add     r2, 2
        ld      r3, LIMITE_USUARIO
        st      r3, (r2)               ; dl

        ; Retorna o PID que foi guardado na entrada.
        ld      r2, (temporario_indice)
        add     r2, r2
        add     r2, proc_pid
        ld      r0, (r2)
        ret

sys_cria_erro:
        ld      r0, ERR_INVALIDO
        ret

; ---------------------------------------------------- SO_MATA_PROC (Parte II)

; Entrada: r1 = PID a matar.
; Acorda todos os processos que aguardavam o PID morto. Se for o processo
; atual, troca o quadro antes do rete.
sys_mata_proc_impl:
        call    proc_registra_quadro_syscall
        st      r1, (temporario_pid)
        call    proc_encontra_pid
        cmp     r0, ERR_INVALIDO
        jmpc    eq, sys_mata_erro
        st      r0, (temporario_indice)

        ; Marca o alvo como morto.
        ld      r2, r0
        add     r2, r2
        add     r2, proc_estado
        ld      r3, ESTADO_MORTO
        st      r3, (r2)

        call    acorda_esperando_processo

        ; Se o alvo não é o atual, basta retornar sucesso ao chamador.
        ld      r2, (processo_atual)
        ld      r3, (temporario_indice)
        cmp     r2, r3
        jmpc    ne, sys_mata_sucesso

        ; O processo atual morreu: escolhe o próximo processo pronto.
        call    proc_escolhe_pronto
        cmp     r0, ERR_INVALIDO
        jmpc    eq, sys_mata_sem_processos

        st      r0, (processo_atual)
        ld      r2, r0
        add     r2, r2
        add     r2, proc_estado
        ld      r3, ESTADO_EXECUTANDO
        st      r3, (r2)

        ; O quadro da interrupção já está endereçado por quadro_interrompido.
        call    proc_copia_para_sistema
        rete

sys_mata_sucesso:
        ld      r0, 0
        ret

sys_mata_erro:
        ld      r0, ERR_INVALIDO
        ret

sys_mata_sem_processos:
        ; Todos os demais processos podem estar bloqueados. Aguarde uma
        ; interrupção sem restaurar um quadro de processo inválido.
        call    proc_escalona_ocioso
        rete

; Acorda todos os processos bloqueados esperando pelo PID em temporario_pid.
acorda_esperando_processo:
        ld      r2, 0
acorda_esperando_loop:
        cmp     r2, MAX_PROCESSOS
        jmpc    ge, acorda_esperando_fim

        ld      r3, r2
        add     r3, r3
        add     r3, proc_estado
        ld      r4, (r3)
        cmp     r4, ESTADO_BLOQUEADO
        jmpc    ne, acorda_esperando_proximo

        ld      r3, r2
        add     r3, r3
        add     r3, proc_motivo
        ld      r4, (r3)
        cmp     r4, BLOQUEIO_ESPERA
        jmpc    ne, acorda_esperando_proximo

        ld      r3, r2
        add     r3, r3
        add     r3, proc_espera_pid
        ld      r4, (r3)
        ld      r1, (temporario_pid)
        cmp     r4, r1
        jmpc    ne, acorda_esperando_proximo

        st      r2, (temporario_indice)
        ld      r1, r2
        ld      r2, 0
        call    proc_grava_retorno

        ld      r0, (temporario_indice)
        add     r0, r0
        add     r0, proc_estado
        ld      r1, ESTADO_PRONTO
        st      r1, (r0)

        ld      r0, (temporario_indice)
        add     r0, r0
        add     r0, proc_motivo
        ld      r1, BLOQUEIO_NENHUM
        st      r1, (r0)

        ld      r2, (temporario_indice)
        add     r2, 1
        jmp     acorda_esperando_loop

acorda_esperando_proximo:
        add     r2, 1
        jmp     acorda_esperando_loop

acorda_esperando_fim:
        ret

; --------------------------------------------------- SO_ESPERA_PROC (Parte II)

; Entrada: r1 = PID esperado. Retorna 0 se o processo já morreu ou quando a
; espera for liberada; retorna -1 para PID inválido ou o próprio processo.
sys_espera_proc_impl:
        call    proc_registra_quadro_syscall
        st      r1, (temporario_pid)
        cmp     r1, 0
        jmpc    le, sys_espera_erro

        call    proc_encontra_pid_qualquer
        cmp     r0, ERR_INVALIDO
        jmpc    eq, sys_espera_erro
        st      r0, (temporario_indice)

        ld      r1, (processo_atual)
        cmp     r1, r0
        jmpc    eq, sys_espera_erro

        ld      r2, r0
        add     r2, r2
        add     r2, proc_estado
        ld      r3, (r2)
        cmp     r3, ESTADO_MORTO
        jmpc    eq, sys_espera_ja_morto

        ; Registra a dependência do chamador e bloqueia-o.
        ld      r0, (processo_atual)
        st      r0, (temporario_indice)

        ld      r2, r0
        add     r2, r2
        add     r2, proc_motivo
        ld      r3, BLOQUEIO_ESPERA
        st      r3, (r2)

        ld      r2, (temporario_indice)
        add     r2, r2
        add     r2, proc_espera_pid
        ld      r3, (temporario_pid)
        st      r3, (r2)

        ld      r2, (temporario_indice)
        add     r2, r2
        add     r2, proc_estado
        ld      r3, ESTADO_BLOQUEADO
        st      r3, (r2)

        call    proc_salva_quadro_atual
        call    proc_escalona_bloqueado
        rete

sys_espera_ja_morto:
        ld      r0, 0
        ret

sys_espera_erro:
        ld      r0, ERR_INVALIDO
        ret

; -------------------------------------------------------------------- dados

        .data

processo_atual:     .dw     0
proximo_pid:        .dw     2

; Entrada 0 é o init; as demais começam livres.
proc_estado:        .dw     ESTADO_EXECUTANDO, ESTADO_LIVRE, ESTADO_LIVRE, ESTADO_LIVRE
                    .dw     ESTADO_LIVRE, ESTADO_LIVRE, ESTADO_LIVRE, ESTADO_LIVRE
proc_pid:           .dw     1, 0, 0, 0, 0, 0, 0, 0
proc_motivo:        .dw     BLOQUEIO_NENHUM, BLOQUEIO_NENHUM, BLOQUEIO_NENHUM, BLOQUEIO_NENHUM
                    .dw     BLOQUEIO_NENHUM, BLOQUEIO_NENHUM, BLOQUEIO_NENHUM, BLOQUEIO_NENHUM
proc_espera_pid:    .dw     0, 0, 0, 0, 0, 0, 0, 0

; Ponteiros para os 8 quadros salvos, em ordem de entrada da tabela.
quadro_ptrs:        .dw     quadro_processo_0, quadro_processo_1
                    .dw     quadro_processo_2, quadro_processo_3
                    .dw     quadro_processo_4, quadro_processo_5
                    .dw     quadro_processo_6, quadro_processo_7

; Topos das pilhas de trabalho dos processos.
pilha_topos:        .dw     topo_pilha_0, topo_pilha_1
                    .dw     topo_pilha_2, topo_pilha_3
                    .dw     topo_pilha_4, topo_pilha_5
                    .dw     topo_pilha_6, topo_pilha_7

temporario_entrada: .dw     0
temporario_indice:  .dw     0
temporario_pid:     .dw     0
temporario_resultado:.dw     0
quadro_interrompido:.dw     0

; Quadro na ordem usada por rete/bios_copia_quadro:
; r0,r1,r2,r3,r4,bp,sp,ip,sr,s1,s2,s3,cs,cl,ds,dl.
quadro_processo_0:
        .dw     0, 0, 0, 0, 0, 0, topo_pilha_0, init_codigo
        .dw     SR_USUARIO, 0, 0, 0, 0, LIMITE_USUARIO, 0, LIMITE_USUARIO
quadro_processo_1: .ds 16
quadro_processo_2: .ds 16
quadro_processo_3: .ds 16
quadro_processo_4: .ds 16
quadro_processo_5: .ds 16
quadro_processo_6: .ds 16
quadro_processo_7: .ds 16

; Quadro usado quando todos os processos estão bloqueados ou mortos. Ele fica
; em modo supervisor, com interrupções habilitadas, e só executa um laço até
; que o hook da console copie um processo pronto para o quadro interrompido.
quadro_ocioso:
        .dw     0, 0, 0, 0, 0, 0, topo_pilha_ociosa, kernel_ocioso
        .dw     SR_SUPERVISOR, 0, 0, 0, 0, 0, 0, 0

; Cada pilha tem 64 palavras. A pilha cresce para endereços menores.
pilha_0:            .ds     64
topo_pilha_0:
pilha_1:            .ds     64
topo_pilha_1:
pilha_2:            .ds     64
topo_pilha_2:
pilha_3:            .ds     64
topo_pilha_3:
pilha_4:            .ds     64
topo_pilha_4:
pilha_5:            .ds     64
topo_pilha_5:
pilha_6:            .ds     64
topo_pilha_6:
pilha_7:            .ds     64
topo_pilha_7:

pilha_ociosa:       .ds     32
topo_pilha_ociosa:

kernel_ocioso:
        jmp     kernel_ocioso

