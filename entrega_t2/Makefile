MCC = ../compilador_c/bin/mcc
MONTADOR = ../simulador_completo/bin/montador
SIMULADOR = ../simulador_completo/bin/simulador
BIOS = ../bios_mancha/src/bios.asm
CONFIG_RR = config_round_robin.asm
CONFIG_PRIO = config_prioridade.asm
CONFIG_RR_Q4 = config_round_robin_q4.asm
CONFIG_PRIO_Q4 = config_prioridade_q4.asm

all: entrega_t2_parte_III_rr.mob entrega_t2_parte_III_prio.mob entrega_t2_parte_III_rr_q4.mob entrega_t2_parte_III_prio_q4.mob

entrega_t2_parte_III_rr.mob: $(BIOS) $(CONFIG_RR) kernel.asm testes.asm
	$(MONTADOR) $(BIOS) $(CONFIG_RR) kernel.asm testes.asm -o entrega_t2_parte_III_rr.mob

entrega_t2_parte_III_prio.mob: $(BIOS) $(CONFIG_PRIO) kernel.asm testes.asm
	$(MONTADOR) $(BIOS) $(CONFIG_PRIO) kernel.asm testes.asm -o entrega_t2_parte_III_prio.mob

entrega_t2_parte_III_rr_q4.mob: $(BIOS) $(CONFIG_RR_Q4) kernel.asm testes.asm
	$(MONTADOR) $(BIOS) $(CONFIG_RR_Q4) kernel.asm testes.asm -o entrega_t2_parte_III_rr_q4.mob

entrega_t2_parte_III_prio_q4.mob: $(BIOS) $(CONFIG_PRIO_Q4) kernel.asm testes.asm
	$(MONTADOR) $(BIOS) $(CONFIG_PRIO_Q4) kernel.asm testes.asm -o entrega_t2_parte_III_prio_q4.mob

run: round-robin

round-robin: entrega_t2_parte_III_rr.mob
	$(SIMULADOR) entrega_t2_parte_III_rr.mob

prioridade: entrega_t2_parte_III_prio.mob
	$(SIMULADOR) entrega_t2_parte_III_prio.mob

round-robin-q4: entrega_t2_parte_III_rr_q4.mob
	$(SIMULADOR) entrega_t2_parte_III_rr_q4.mob

prioridade-q4: entrega_t2_parte_III_prio_q4.mob
	$(SIMULADOR) entrega_t2_parte_III_prio_q4.mob

clean:
	rm -f entrega_t2_parte_III.mob entrega_t2_parte_III_rr.mob entrega_t2_parte_III_prio.mob entrega_t2_parte_III_rr_q4.mob entrega_t2_parte_III_prio_q4.mob

.PHONY: all run round-robin prioridade round-robin-q4 prioridade-q4 clean

