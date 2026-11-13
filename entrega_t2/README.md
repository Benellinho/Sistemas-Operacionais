# Entrega T2 — Parte II

Esta pasta contém a evolução da Parte I para bloqueios e espera entre
processos, usando o Assembly do Mancha e a BIOS fornecida no repositório.

## Arquivos

- `kernel.asm`: tabela de processos, estados, quadros salvos, syscalls,
  bloqueio de leitura, espera por PID e estado ocioso do kernel.
- `testes.asm`: testes de erros de espera, acordamento após morte, leitura
  bloqueante e compartilhamento da console.
- `Makefile`: montagem do módulo `entrega_t2_parte_II.mob`.

## Estados e retornos

Os estados usados são `LIVRE`, `PRONTO`, `EXECUTANDO`, `BLOQUEADO` e
`MORTO`. Um processo bloqueado registra se espera leitura, escrita ou a morte
de outro processo. Nesta parte, a escrita da BIOS é síncrona e sempre aceita o
caractere, então `SO_ESCREVE` retorna imediatamente.

`SO_ESPERA_PROC` retorna `0` quando o processo esperado já morreu ou quando o
acordamento acontece. Retorna `-1` para PID inexistente, PID inválido ou o
próprio PID.

## Teste padrão

Monte e execute:

```sh
make
make run
```

Sem entrada, o leitor e o processo que espera por ele ficam bloqueados, e o
kernel executa o quadro ocioso. Envie `Ex` no simulador para fornecer um
caractere. A saída esperada é:

```text
TDIxW
```

`T` confirma os erros de espera, `D` confirma a espera por um processo já
morto, `I` vem do processo inicial, `x` é lido e ecoado pelo leitor e `W` é
produzido pelo processo acordado após a morte do leitor.
