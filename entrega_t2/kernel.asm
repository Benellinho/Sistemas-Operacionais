; Parte III — mini sistema operacional do Mancha
;
; Implementação em Assembly para manter o controle explícito de:
;   - processos em modo usuário (S=0 e I=0);
;   - tabela de processos e PIDs monotônicos;
;   - quadros de 16 palavras;
;   - chamadas de sistema;
;   - escalonamento quando o processo atual morre ou bloqueia;
;   - bloqueio de leitura e espera por outro processo;
;   - preempção por relógio, round-robin/prioridade e métricas.
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

        ; ESCALONADOR_ATIVO, QUANTUM_TICKS, INTERVALO_RELOGIO,
        ; PRIORIDADE_ESCALA e PRIORIDADE_INICIAL vêm do arquivo de
        ; configuração passado pelo Makefile.

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

        ; Instala o hook da console antes de habilitar interrupções externas.
        ld      r0, kernel_trata_console
        st      r0, (retomada_console)
        ld      r0, kernel_trata_disco
        st      r0, (retomada_disco)

        ; O relógio gera a interrupção 10 e chama o trampolim por JMP.
        ld      r0, INTERVALO_RELOGIO
        ld      r1, r0
        shr     r1, 8
        outb    r1, (0x22)
        outb    r0, (0x23)
        ld      r0, escalonador_trampolim
        st      r0, (retomada_escalonador)

        ; Console (bit 0) + relógio (bit 2) + disco (bit 1).
        ld      r0, 7
        outb    r0, (0x30)

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
        ld      r0, QUANTUM_TICKS
        st      r0, (quantum_restante)
        ld      r0, PRIORIDADE_INICIAL
        st      r0, (proc_prioridade)
        ld      r0, 1
        st      r0, (metricas_processos_criados)
        ld      r0, 0
        ld      r1, ESTADO_EXECUTANDO
        call    metricas_entrada_estado
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
        call    proc_atualiza_prioridade_atual

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
        ld      r0, (temporario_indice)
        ld      r1, ESTADO_BLOQUEADO
        call    metricas_entrada_estado

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
        call    escalonador_seleciona
        call    escalonador_instala_selecionado
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
        ld      r0, (metricas_interrupcoes_console)
        add     r0, 1
        st      r0, (metricas_interrupcoes_console)
        call    proc_acorda_leitores

        ld      r0, (processo_atual)
        cmp     r0, PROCESSO_OCIOSO
        jmpc    ne, kernel_console_fim
        call    escalonador_seleciona
        call    escalonador_instala_selecionado

kernel_console_fim:
        ret

; ------------------------------------------------------------- interrupções

kernel_trata_disco:
        ld      r0, (metricas_interrupcoes_disco)
        add     r0, 1
        st      r0, (metricas_interrupcoes_disco)
        ret

; A BIOS chega aqui por JMP, com sp apontando para o quadro fixo da
; interrupção. O trampolim termina diretamente com rete.
escalonador_trampolim:
        st      sp, (quadro_interrompido)
        call    metricas_atualiza_tick

        ld      r0, (metricas_interrupcoes_relogio)
        add     r0, 1
        st      r0, (metricas_interrupcoes_relogio)

        ld      r0, (processo_atual)
        cmp     r0, PROCESSO_OCIOSO
        jmpc    eq, escalonador_acorda_ocioso

        ld      r0, (quantum_restante)
        cmp     r0, 0
        jmpc    le, escalonador_quantum_expirou
        add     r0, -1
        st      r0, (quantum_restante)
        cmp     r0, 0
        jmpc    gt, escalonador_mantem

escalonador_quantum_expirou:
        ; Se não há outro pronto, reinicia o quantum sem trocar de processo.
        ld      r0, (fila_n)
        cmp     r0, 0
        jmpc    eq, escalonador_reinicia_atual

        ld      r0, (processo_atual)
        st      r0, (temporario_indice)
        call    proc_salva_quadro_atual
        call    proc_atualiza_prioridade_atual

        ld      r0, (processo_atual)
        st      r0, (temporario_indice)
        add     r0, r0
        add     r0, proc_estado
        ld      r1, ESTADO_PRONTO
        st      r1, (r0)
        ld      r0, (temporario_indice)
        ld      r1, ESTADO_PRONTO
        call    metricas_entrada_estado
        ld      r0, (metricas_preempcoes)
        add     r0, 1
        st      r0, (metricas_preempcoes)

        ld      r0, (temporario_indice)
        add     r0, r0
        add     r0, metricas_preempcoes_processo
        ld      r1, (r0)
        add     r1, 1
        st      r1, (r0)

        ld      r0, (temporario_indice)
        call    fila_insere
        call    escalonador_seleciona
        call    escalonador_instala_selecionado
        rete

escalonador_reinicia_atual:
        ld      r0, QUANTUM_TICKS
        st      r0, (quantum_restante)
        jmp     escalonador_mantem

escalonador_acorda_ocioso:
        call    escalonador_seleciona
        call    escalonador_instala_selecionado
        rete

escalonador_mantem:
        rete

; Retorna em r0 um processo pronto conforme o escalonador configurado.
escalonador_seleciona:
        ld      r0, ESCALONADOR_ATIVO
        cmp     r0, 0
        jmpc    eq, escalonador_seleciona_rr
        call    proc_reconstroi_fila
        call    proc_escolhe_prioridade
        ret

escalonador_seleciona_rr:
        call    fila_tira_inicio
        ret

; Instala o processo retornado por escalonador_seleciona. Entrada r0 = índice
; ou ERR_INVALIDO. O quadro salvo já contém a continuação do processo.
escalonador_instala_selecionado:
        cmp     r0, ERR_INVALIDO
        jmpc    eq, escalonador_instala_ocioso
        st      r0, (processo_atual)
        st      r0, (temporario_indice)

        add     r0, r0
        add     r0, proc_estado
        ld      r1, ESTADO_EXECUTANDO
        st      r1, (r0)
        ld      r0, (temporario_indice)
        ld      r1, ESTADO_EXECUTANDO
        call    metricas_entrada_estado
        call    metricas_registra_resposta

        ld      r0, QUANTUM_TICKS
        st      r0, (quantum_restante)
        ld      r0, (temporario_indice)
        call    proc_copia_para_sistema
        ret

escalonador_instala_ocioso:
        call    proc_escalona_ocioso
        ret

; Fila circular de índices da tabela de processos.
fila_insere:
        cmp     r0, 0
        jmpc    lt, fila_insere_fim
        cmp     r0, MAX_PROCESSOS
        jmpc    ge, fila_insere_fim
        st      r0, (temporario_indice)

        add     r0, r0
        add     r0, proc_na_fila
        ld      r1, (r0)
        cmp     r1, 0
        jmpc    ne, fila_insere_fim
        ld      r1, (fila_n)
        cmp     r1, MAX_PROCESSOS
        jmpc    ge, fila_insere_fim

        ld      r1, (fila_fim)
        add     r1, r1
        add     r1, fila_prontos
        ld      r2, (temporario_indice)
        st      r2, (r1)
        ld      r1, (temporario_indice)
        add     r1, r1
        add     r1, proc_na_fila
        ld      r2, 1
        st      r2, (r1)

        ld      r1, (fila_fim)
        add     r1, 1
        cmp     r1, MAX_PROCESSOS
        jmpc    lt, fila_insere_fim_ok
        ld      r1, 0
fila_insere_fim_ok:
        st      r1, (fila_fim)
        ld      r1, (fila_n)
        add     r1, 1
        st      r1, (fila_n)
fila_insere_fim:
        ret

; Remove e valida o primeiro item da fila.
fila_tira_inicio:
fila_tira_inicio_loop:
        ld      r1, (fila_n)
        cmp     r1, 0
        jmpc    le, fila_tira_vazia
        ld      r1, (fila_inicio)
        add     r1, r1
        add     r1, fila_prontos
        ld      r0, (r1)
        st      r0, (temporario_indice)

        ld      r1, (fila_inicio)
        add     r1, 1
        cmp     r1, MAX_PROCESSOS
        jmpc    lt, fila_tira_inicio_ok
        ld      r1, 0
fila_tira_inicio_ok:
        st      r1, (fila_inicio)
        ld      r1, (fila_n)
        add     r1, -1
        st      r1, (fila_n)

        ld      r1, (temporario_indice)
        add     r1, r1
        add     r1, proc_na_fila
        ld      r2, 0
        st      r2, (r1)
        ld      r0, (temporario_indice)
        ld      r1, r0
        add     r1, r0
        add     r1, r0
        add     r1, proc_estado
        ld      r2, (r1)
        cmp     r2, ESTADO_PRONTO
        jmpc    eq, fila_tira_encontrou
        jmp     fila_tira_inicio_loop

fila_tira_encontrou:
        ld      r0, (temporario_indice)
        ret

fila_tira_vazia:
        ld      r0, ERR_INVALIDO
        ret

; Reconstrói a fila a partir dos processos atualmente PRONTO. Isso também
; remove entradas obsoletas quando o escalonador por prioridade está ativo.
proc_reconstroi_fila:
        ld      r0, 0
        st      r0, (fila_inicio)
        st      r0, (fila_fim)
        st      r0, (fila_n)
        ld      r2, 0
proc_reconstroi_limpa:
        cmp     r2, MAX_PROCESSOS
        jmpc    ge, proc_reconstroi_varre
        ld      r0, r2
        add     r0, r0
        add     r0, proc_na_fila
        ld      r1, 0
        st      r1, (r0)
        add     r2, 1
        jmp     proc_reconstroi_limpa
proc_reconstroi_varre:
        ld      r2, 0
proc_reconstroi_loop:
        cmp     r2, MAX_PROCESSOS
        jmpc    ge, proc_reconstroi_fim
        ld      r0, r2
        add     r0, r0
        add     r0, proc_estado
        ld      r1, (r0)
        cmp     r1, ESTADO_PRONTO
        jmpc    ne, proc_reconstroi_proximo
        ld      r0, r2
        call    fila_insere
proc_reconstroi_proximo:
        add     r2, 1
        jmp     proc_reconstroi_loop
proc_reconstroi_fim:
        ret

; Escolhe o menor valor de prioridade entre os processos PRONTO.
proc_escolhe_prioridade:
        ld      r0, ERR_INVALIDO
        st      r0, (temporario_resultado)
        ld      r2, 0
        ld      r3, 0x7FFF
proc_prioridade_loop:
        cmp     r2, MAX_PROCESSOS
        jmpc    ge, proc_prioridade_fim
        ld      r1, r2
        add     r1, r1
        add     r1, proc_estado
        ld      r4, (r1)
        cmp     r4, ESTADO_PRONTO
        jmpc    ne, proc_prioridade_proximo
        ld      r1, r2
        add     r1, r1
        add     r1, proc_prioridade
        ld      r4, (r1)
        cmp     r4, r3
        jmpc    ge, proc_prioridade_proximo
        ld      r3, r4
        st      r2, (temporario_resultado)
proc_prioridade_proximo:
        add     r2, 1
        jmp     proc_prioridade_loop
proc_prioridade_fim:
        ld      r0, (temporario_resultado)
        ret

; Atualiza a prioridade fixa do processo atual usando t_exec = quantum -
; quantum_restante e a fórmula definida no planejamento.
proc_atualiza_prioridade_atual:
        ld      r0, (processo_atual)
        cmp     r0, PROCESSO_OCIOSO
        jmpc eq, proc_atualiza_prioridade_fim
        st      r0, (temporario_indice)
        add     r0, r0
        add     r0, proc_prioridade
        ld      r1, (r0)
        ld      r2, QUANTUM_TICKS
        ld      r3, (quantum_restante)
        sub     r2, r3
        ld      r4, PRIORIDADE_ESCALA
        mul     r2, r4
        div     r2, QUANTUM_TICKS
        add     r1, r2
        div     r1, 2
        ld      r0, (temporario_indice)
        add     r0, r0
        add     r0, proc_prioridade
        st      r1, (r0)
proc_atualiza_prioridade_fim:
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
        ld      r0, (temporario_indice)
        ld      r1, ESTADO_PRONTO
        call    metricas_entrada_estado
        ld      r0, (temporario_indice)
        call    proc_marca_desbloqueio
        ld      r0, (temporario_indice)
        call    fila_insere
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

        ld      r0, (temporario_indice)
        ld      r1, ESTADO_PRONTO
        call    metricas_entrada_estado
        ld      r0, (temporario_indice)
        call    metricas_processo_criado
        ld      r0, (temporario_indice)
        call    proc_marca_desbloqueio
        ld      r0, (temporario_indice)
        call    fila_insere

        ld      r0, (temporario_indice)
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

        ld      r2, (processo_atual)
        cmp     r2, r0
        jmpc    ne, sys_mata_nao_atual
        call    proc_atualiza_prioridade_atual
sys_mata_nao_atual:

        ; Marca o alvo como morto.
        ld      r0, (temporario_indice)
        ld      r2, r0
        add     r2, r2
        add     r2, proc_estado
        ld      r3, ESTADO_MORTO
        st      r3, (r2)
        ld      r0, (temporario_indice)
        ld      r1, ESTADO_MORTO
        call    metricas_entrada_estado
        ld      r0, (temporario_indice)
        call    metricas_registra_morte

        call    acorda_esperando_processo

        ld      r0, (temporario_pid)
        cmp     r0, 1
        jmpc    ne, sys_mata_sem_relatorio
        ld      r0, (temporario_indice)
        st      r0, (temporario_resultado)
        call    imprime_metricas_finais
        ld      r0, (temporario_resultado)
        st      r0, (temporario_indice)
sys_mata_sem_relatorio:

        ; Se o alvo não é o atual, basta retornar sucesso ao chamador.
        ld      r2, (processo_atual)
        ld      r3, (temporario_indice)
        cmp     r2, r3
        jmpc    ne, sys_mata_sucesso

        ; O processo atual morreu: escolhe o próximo processo pronto.
        call    escalonador_seleciona
        call    escalonador_instala_selecionado
        rete

sys_mata_sucesso:
        ld      r0, 0
        ret

sys_mata_erro:
        ld      r0, ERR_INVALIDO
        ret

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

        ld      r0, (temporario_indice)
        ld      r1, ESTADO_PRONTO
        call    metricas_entrada_estado
        ld      r0, (temporario_indice)
        call    proc_marca_desbloqueio
        ld      r0, (temporario_indice)
        call    fila_insere

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
        call    proc_atualiza_prioridade_atual

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
        ld      r0, (temporario_indice)
        ld      r1, ESTADO_BLOQUEADO
        call    metricas_entrada_estado

        call    proc_salva_quadro_atual
        call    proc_escalona_bloqueado
        rete

sys_espera_ja_morto:
        ld      r0, 0
        ret

sys_espera_erro:
        ld      r0, ERR_INVALIDO
        ret

; --------------------------------------------------------------- métricas

; Entrada: r0 = índice, r1 = estado. Conta uma entrada no estado.
metricas_entrada_estado:
        cmp     r1, ESTADO_PRONTO
        jmpc    eq, metricas_entrada_pronto
        cmp     r1, ESTADO_EXECUTANDO
        jmpc    eq, metricas_entrada_exec
        cmp     r1, ESTADO_BLOQUEADO
        jmpc    eq, metricas_entrada_bloqueado
        cmp     r1, ESTADO_MORTO
        jmpc    eq, metricas_entrada_morto
        ret
metricas_entrada_pronto:
        add     r0, r0
        add     r0, metricas_entradas_pronto
        jmp     metricas_incrementa_endereco
metricas_entrada_exec:
        add     r0, r0
        add     r0, metricas_entradas_exec
        jmp     metricas_incrementa_endereco
metricas_entrada_bloqueado:
        add     r0, r0
        add     r0, metricas_entradas_bloqueado
        jmp     metricas_incrementa_endereco
metricas_entrada_morto:
        add     r0, r0
        add     r0, metricas_entradas_morto
        jmp     metricas_incrementa_endereco
metricas_incrementa_endereco:
        ld      r2, (r0)
        add     r2, 1
        st      r2, (r0)
        ret

; Entrada: r0 = índice, r1 = estado. Soma um tique ao tempo no estado.
metricas_incrementa_tempo:
        cmp     r1, ESTADO_PRONTO
        jmpc    eq, metricas_tempo_pronto
        cmp     r1, ESTADO_EXECUTANDO
        jmpc    eq, metricas_tempo_exec
        cmp     r1, ESTADO_BLOQUEADO
        jmpc    eq, metricas_tempo_bloqueado
        cmp     r1, ESTADO_MORTO
        jmpc    eq, metricas_tempo_morto
        ret
metricas_tempo_pronto:
        add     r0, r0
        add     r0, metricas_tempo_pronto_proc
        jmp     metricas_soma_tempo
metricas_tempo_exec:
        add     r0, r0
        add     r0, metricas_tempo_exec_proc
        jmp     metricas_soma_tempo
metricas_tempo_bloqueado:
        add     r0, r0
        add     r0, metricas_tempo_bloqueado_proc
        jmp     metricas_soma_tempo
metricas_tempo_morto:
        add     r0, r0
        add     r0, metricas_tempo_morto_proc
        jmp     metricas_soma_tempo
metricas_soma_tempo:
        ld      r2, (r0)
        add     r2, 1
        st      r2, (r0)
        ret

metricas_atualiza_tick:
        ld      r0, (metricas_tempo_total)
        add     r0, 1
        st      r0, (metricas_tempo_total)
        ld      r0, (processo_atual)
        cmp     r0, PROCESSO_OCIOSO
        jmpc    eq, metricas_tick_ocioso
        ld      r1, ESTADO_EXECUTANDO
        call    metricas_incrementa_tempo
        ret
metricas_tick_ocioso:
        ld      r0, (metricas_tempo_ocioso)
        add     r0, 1
        st      r0, (metricas_tempo_ocioso)
        ret

metricas_processo_criado:
        ld      r2, (metricas_processos_criados)
        add     r2, 1
        st      r2, (metricas_processos_criados)
        st      r0, (temporario_indice)
        add     r0, r0
        add     r0, metricas_tempo_criacao
        ld      r1, (metricas_tempo_total)
        st      r1, (r0)
        ld      r0, (temporario_indice)
        add     r0, r0
        add     r0, proc_prioridade
        ld      r1, PRIORIDADE_INICIAL
        st      r1, (r0)
        ret

proc_marca_desbloqueio:
        st      r0, (temporario_indice)
        add     r0, r0
        add     r0, metricas_instante_desbloqueio
        ld      r1, (metricas_tempo_total)
        st      r1, (r0)
        ld      r0, (temporario_indice)
        add     r0, r0
        add     r0, metricas_aguarda_resposta
        ld      r1, 1
        st      r1, (r0)
        ret

metricas_registra_resposta:
        ld      r0, (processo_atual)
        cmp     r0, PROCESSO_OCIOSO
        jmpc    eq, metricas_resposta_fim
        st      r0, (temporario_indice)
        add     r0, r0
        add     r0, metricas_aguarda_resposta
        ld      r1, (r0)
        cmp     r1, 0
        jmpc    eq, metricas_resposta_fim
        ld      r0, (temporario_indice)
        add     r0, r0
        add     r0, metricas_instante_desbloqueio
        ld      r1, (metricas_tempo_total)
        ld      r2, (r0)
        sub     r1, r2
        ld      r0, (temporario_indice)
        add     r0, r0
        add     r0, metricas_resposta_total
        ld      r2, (r0)
        add     r2, r1
        st      r2, (r0)
        ld      r0, (temporario_indice)
        add     r0, r0
        add     r0, metricas_resposta_contagem
        ld      r2, (r0)
        add     r2, 1
        st      r2, (r0)
        ld      r0, (temporario_indice)
        add     r0, r0
        add     r0, metricas_aguarda_resposta
        ld      r1, 0
        st      r1, (r0)
metricas_resposta_fim:
        ret

metricas_registra_morte:
        st      r0, (temporario_indice)
        add     r0, r0
        add     r0, metricas_tempo_criacao
        ld      r1, (metricas_tempo_total)
        ld      r2, (r0)
        sub     r1, r2
        ld      r0, (temporario_indice)
        add     r0, r0
        add     r0, metricas_turnaround
        st      r1, (r0)
        ret

; Relatório compacto impresso quando o PID 1 termina.
imprime_metricas_finais:
        ld      r0, msg_metricas_inicio
        call    bios_imprime
        ld      r0, (metricas_processos_criados)
        call    bios_imprime_dec
        ld      r0, msg_metricas_tempo
        call    bios_imprime
        ld      r0, (metricas_tempo_total)
        call    bios_imprime_dec
        ld      r0, msg_metricas_ocioso
        call    bios_imprime
        ld      r0, (metricas_tempo_ocioso)
        call    bios_imprime_dec
        ld      r0, msg_metricas_preempcoes
        call    bios_imprime
        ld      r0, (metricas_preempcoes)
        call    bios_imprime_dec
        ld      r0, msg_metricas_console
        call    bios_imprime
        ld      r0, (metricas_interrupcoes_console)
        call    bios_imprime_dec
        ld      r0, msg_metricas_disco
        call    bios_imprime
        ld      r0, (metricas_interrupcoes_disco)
        call    bios_imprime_dec
        ld      r0, msg_metricas_relogio
        call    bios_imprime
        ld      r0, (metricas_interrupcoes_relogio)
        call    bios_imprime_dec
        ld      r0, msg_metricas_nl
        call    bios_imprime

        ld      r2, 0
metricas_relatorio_loop:
        st      r2, (temporario_indice)
        cmp     r2, MAX_PROCESSOS
        jmpc    ge, metricas_relatorio_fim
        ld      r0, r2
        add     r0, r0
        add     r0, proc_estado
        ld      r1, (r0)
        cmp     r1, ESTADO_LIVRE
        jmpc    eq, metricas_relatorio_proximo
        ld      r0, msg_metricas_proc
        call    bios_imprime
        ld      r2, (temporario_indice)
        ld      r0, r2
        add     r0, r0
        add     r0, proc_pid
        ld      r0, (r0)
        call    bios_imprime_dec
        ld      r0, msg_metricas_turnaround
        call    bios_imprime
        ld      r2, (temporario_indice)
        ld      r0, r2
        add     r0, r0
        add     r0, metricas_turnaround
        ld      r0, (r0)
        call    bios_imprime_dec
        ld      r0, msg_metricas_preemp_proc
        call    bios_imprime
        ld      r2, (temporario_indice)
        ld      r0, r2
        add     r0, r0
        add     r0, metricas_preempcoes_processo
        ld      r0, (r0)
        call    bios_imprime_dec
        ld      r0, msg_metricas_exec
        call    bios_imprime
        ld      r2, (temporario_indice)
        ld      r0, r2
        add     r0, r0
        add     r0, metricas_tempo_exec_proc
        ld      r0, (r0)
        call    bios_imprime_dec
        ld      r0, msg_metricas_bloqueado
        call    bios_imprime
        ld      r2, (temporario_indice)
        ld      r0, r2
        add     r0, r0
        add     r0, metricas_tempo_bloqueado_proc
        ld      r0, (r0)
        call    bios_imprime_dec
        ld      r0, msg_metricas_nl
        call    bios_imprime
metricas_relatorio_proximo:
        ld      r2, (temporario_indice)
        add     r2, 1
        jmp     metricas_relatorio_loop
metricas_relatorio_fim:
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

quantum_restante:   .dw     QUANTUM_TICKS
fila_prontos:       .ds     MAX_PROCESSOS
fila_inicio:        .dw     0
fila_fim:           .dw     0
fila_n:             .dw     0
proc_na_fila:       .dw     0, 0, 0, 0, 0, 0, 0, 0
proc_prioridade:    .dw     PRIORIDADE_INICIAL, 0, 0, 0, 0, 0, 0, 0

metricas_processos_criados:     .dw 0
metricas_tempo_total:           .dw 0
metricas_tempo_ocioso:          .dw 0
metricas_interrupcoes_console:  .dw 0
metricas_interrupcoes_disco:    .dw 0
metricas_interrupcoes_relogio:  .dw 0
metricas_preempcoes:            .dw 0
metricas_entradas_pronto:       .dw 0, 0, 0, 0, 0, 0, 0, 0
metricas_entradas_exec:         .dw 0, 0, 0, 0, 0, 0, 0, 0
metricas_entradas_bloqueado:    .dw 0, 0, 0, 0, 0, 0, 0, 0
metricas_entradas_morto:        .dw 0, 0, 0, 0, 0, 0, 0, 0
metricas_tempo_pronto_proc:     .dw 0, 0, 0, 0, 0, 0, 0, 0
metricas_tempo_exec_proc:       .dw 0, 0, 0, 0, 0, 0, 0, 0
metricas_tempo_bloqueado_proc:  .dw 0, 0, 0, 0, 0, 0, 0, 0
metricas_tempo_morto_proc:      .dw 0, 0, 0, 0, 0, 0, 0, 0
metricas_tempo_criacao:         .dw 0, 0, 0, 0, 0, 0, 0, 0
metricas_turnaround:            .dw 0, 0, 0, 0, 0, 0, 0, 0
metricas_preempcoes_processo:   .dw 0, 0, 0, 0, 0, 0, 0, 0
metricas_instante_desbloqueio:  .dw 0, 0, 0, 0, 0, 0, 0, 0
metricas_resposta_total:        .dw 0, 0, 0, 0, 0, 0, 0, 0
metricas_resposta_contagem:     .dw 0, 0, 0, 0, 0, 0, 0, 0
metricas_aguarda_resposta:      .dw 0, 0, 0, 0, 0, 0, 0, 0

msg_metricas_inicio:    .db "METRICAS processos=", 0
msg_metricas_tempo:     .db " tempo=", 0
msg_metricas_ocioso:    .db " ocioso=", 0
msg_metricas_preempcoes:.db " preempcoes=", 0
msg_metricas_console:   .db " int_console=", 0
msg_metricas_disco:     .db " int_disco=", 0
msg_metricas_relogio:   .db " int_relogio=", 0
msg_metricas_proc:      .db "PID ", 0
msg_metricas_turnaround:.db " turnaround=", 0
msg_metricas_preemp_proc:.db " preempcoes=", 0
msg_metricas_exec:      .db " exec=", 0
msg_metricas_bloqueado: .db " bloqueado=", 0
msg_metricas_nl:        .db 10, 0

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

