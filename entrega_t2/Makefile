MCC = ../compilador_c/bin/mcc
MONTADOR = ../simulador_completo/bin/montador
SIMULADOR = ../simulador_completo/bin/simulador
BIOS = ../bios_mancha/src/bios.asm
CONFIG_RR = config_round_robin.asm
CONFIG_PRIO = config_prioridade.asm

all: entrega_t2_parte_III_rr.mob

entrega_t2_parte_III_rr.mob: $(BIOS) $(CONFIG_RR) kernel.asm testes.asm
	$(MONTADOR) $(BIOS) $(CONFIG_RR) kernel.asm testes.asm -o entrega_t2_parte_III_rr.mob

entrega_t2_parte_III_prio.mob: $(BIOS) $(CONFIG_PRIO) kernel.asm testes.asm
	$(MONTADOR) $(BIOS) $(CONFIG_PRIO) kernel.asm testes.asm -o entrega_t2_parte_III_prio.mob

run: round-robin

round-robin: entrega_t2_parte_III_rr.mob
	$(SIMULADOR) entrega_t2_parte_III_rr.mob

prioridade: entrega_t2_parte_III_prio.mob
	$(SIMULADOR) entrega_t2_parte_III_prio.mob

clean:
	rm -f entrega_t2_parte_III.mob entrega_t2_parte_III_rr.mob entrega_t2_parte_III_prio.mob

.PHONY: all run round-robin prioridade clean

