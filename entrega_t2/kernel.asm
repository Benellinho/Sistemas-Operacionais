; Parte I — mini sistema operacional do Mancha
;
; Implementação em Assembly para manter o controle explícito de:
;   - processos em modo usuário (S=0 e I=0);
;   - tabela de processos e PIDs monotônicos;
;   - quadros de 16 palavras;
;   - chamadas de sistema;
;   - escalonamento quando o processo atual morre.
;
; Convenção das chamadas de sistema:
;   r0 = número da chamada
;   r1..r4 = argumentos
;   r0 = resultado
;
; Parte I ainda não faz bloqueio nem preempção. SO_LE usa espera ocupada e
; SO_ESPERA_PROC devolve ERR_NAO_IMPLEMENTADO; esses comportamentos pertencem
; à Parte II.

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

; Entrada: r0 = índice do processo.
; Copia o quadro salvo desse processo para pilha_sistema - 32.
proc_copia_para_sistema:
        ld      r2, r0
        add     r2, r2
        add     r2, quadro_ptrs
        ld      r0, (r2)
        ld      r1, sp
        ; Esta rotina é chamada de dentro do handler de syscall da BIOS e
        ; também recebeu um call do próprio handler. Há dois retornos acima
        ; do quadro: o retorno desta rotina e o retorno que a BIOS fará para
        ; o chamador da syscall. O quadro interrompido começa em sp+4.
        add     r1, 4
        call    bios_copia_quadro
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

; --------------------------------------------------------- SO_LE (Parte I)

; SO_LE não bloqueia nesta parte. Enquanto o buffer da BIOS estiver vazio,
; o processo permanece em espera ocupada. A interrupção 8 da BIOS alimenta
; o buffer da console quando um caractere é digitado.
sys_le_impl:
sys_le_espera:
        call    bios_console_disponivel
        cmp     r0, 0
        jmpc    eq, sys_le_espera
        call    bios_console_le
        ret

; ------------------------------------------------------ SO_ESCREVE (Parte I)

; Entrada: r1 = caractere.
; O processo de usuário não acessa a porta; a BIOS escreve em modo supervisor.
sys_escreve_impl:
        ld      r0, r1
        call    bios_putc
        ld      r0, 0
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

; ----------------------------------------------------- SO_MATA_PROC (Parte I)

; Entrada: r1 = PID a matar.
; Se for o processo atual, escolhe outro pronto e troca o quadro antes do rete.
sys_mata_proc_impl:
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

        ; O endereço sp ainda aponta para o quadro da interrupção/trap.
        call    proc_copia_para_sistema
        ld      r0, 0
        ret

sys_mata_sucesso:
        ld      r0, 0
        ret

sys_mata_erro:
        ld      r0, ERR_INVALIDO
        ret

sys_mata_sem_processos:
        ; O init e todos os processos terminaram. Não existe outro quadro.
        halt

; -------------------------------------------------- SO_ESPERA_PROC (Parte I)

; A espera real depende de bloqueio e será implementada na Parte II.
; Manter a entrada instalada torna a interface completa e devolve erro claro.
sys_espera_proc_impl:
        ld      r0, ERR_NAO_IMPLEMENTADO
        ret

; -------------------------------------------------------------------- dados

        .data

processo_atual:     .dw     0
proximo_pid:        .dw     2

; Entrada 0 é o init; as demais começam livres.
proc_estado:        .dw     ESTADO_EXECUTANDO, ESTADO_LIVRE, ESTADO_LIVRE, ESTADO_LIVRE
                    .dw     ESTADO_LIVRE, ESTADO_LIVRE, ESTADO_LIVRE, ESTADO_LIVRE
proc_pid:           .dw     1, 0, 0, 0, 0, 0, 0, 0

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

