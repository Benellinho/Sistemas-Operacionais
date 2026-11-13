MCC = ../compilador_c/bin/mcc
MONTADOR = ../simulador_completo/bin/montador
SIMULADOR = ../simulador_completo/bin/simulador
BIOS = ../bios_mancha/src/bios.asm

all: entrega_t2_parte_II.mob

entrega_t2_parte_II.mob: $(BIOS) kernel.asm testes.asm
	$(MONTADOR) $(BIOS) kernel.asm testes.asm -o entrega_t2_parte_II.mob

run: entrega_t2_parte_II.mob
	$(SIMULADOR) entrega_t2_parte_II.mob

clean:
	rm -f entrega_t2_parte_II.mob

.PHONY: all run clean

