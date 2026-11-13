# Entrega T2 — Parte III

Esta versão acrescenta preempção por relógio, fila circular de prontos,
escalonamento round-robin, escalonamento por prioridade dinâmica e métricas.

## Configuração

As configurações ficam em arquivos separados:

- `config_round_robin.asm`: round-robin;
- `config_prioridade.asm`: prioridade dinâmica;
- `QUANTUM_TICKS`: quantidade de interrupções de relógio por fatia;
- `INTERVALO_RELOGIO`: intervalo do hardware em instruções.

O intervalo foi mantido maior que o custo do escalonador. Para comparar os
algoritmos, execute os dois alvos com a mesma carga:

## Compilação e execução

```sh
make
make round-robin
make prioridade
```

O teste cria uma carga CPU-bound, uma carga de E/S e um processo que cria e
espera um filho. O processo de E/S fica bloqueado até receber um caractere com
`Ex` no simulador. Ao final do init, o kernel imprime processos criados, tempo
total, tempo ocioso, preempções e turnaround/preempções por PID.

## Implementação

- `kernel.asm`: fila, quantum, trampolim do relógio, dois escalonadores e
  contadores.
- `testes.asm`: cargas CPU-bound, E/S e criação/espera.
- `bios_mancha/src/bios.asm`: hooks opcionais para interrupções da console e
  do disco.
- `RELATORIO_PARTE_III.md`: modelo para registrar as execuções comparativas.

`SO_ESCREVE` permanece síncrona porque a BIOS disponibilizada não expõe um
estado de saída ocupado.
