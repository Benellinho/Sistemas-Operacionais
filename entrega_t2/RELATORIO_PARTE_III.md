# Relatório de execuções — Parte III

## Configurações

| Execução | Escalonador | `QUANTUM_TICKS` | `INTERVALO_RELOGIO` | Entrada |
|---|---|---:|---:|---|
| 1 | Round-robin | 2 | 4000 | `Ex` |
| 2 | Round-robin | 4 | 4000 | `Ex` |
| 3 | Prioridade | 2 | 4000 | `Ex` |
| 4 | Prioridade | 4 | 4000 | `Ex` |

## Resultados

Preencha os valores exibidos pelo relatório do kernel:

| Execução | Processos | Tempo total | Tempo ocioso | Preempções |
|---|---:|---:|---:|---:|
| 1 |  |  |  |  |
| 2 |  |  |  |  |
| 3 |  |  |  |  |
| 4 |  |  |  |  |

## Métricas por processo

Preencha uma tabela para cada execução:

| PID | Turnaround | Preempções | Pronto (entradas/tempo) | Bloqueado (entradas/tempo) | Executando (entradas/tempo) | Morto (entradas/tempo) | Resposta média |
|---:|---:|---:|---:|---:|---:|---:|---:|
|  |  |  |  |  |  |  |  |

O tempo em `MORTO` representa o período em que a entrada permaneceu ocupada
após o término, até ser reutilizada ou até o fim da execução. O relatório do
kernel imprime esses valores junto com as métricas globais.

## Análise

- Quantuns menores tendem a aumentar a quantidade de preempções e o custo do
  escalonador.
- O processo de E/S não consome CPU enquanto aguarda entrada.
- O processo CPU-bound deve sofrer preempção mesmo sem chamar o kernel.
- O tempo ocioso aparece enquanto o processo de E/S está bloqueado e as outras
  cargas já terminaram.
