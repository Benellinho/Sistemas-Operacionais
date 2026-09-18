# Início do T1

O programa está em `simulador_completo/exemplos/t1_aleatorio.asm`. Todas as suas rotinas estão nesse único arquivo, conforme a orientação de fazer só um programa.

## O que já faz

1. Inicializa a execução e a pilha.
2. Chama `gera_numero`, que calcula `(5 * semente + 1) % 256` e guarda o novo estado.
3. Chama `imprime_numero`, que escreve o resultado na console com três dígitos.
4. Escreve uma quebra de linha e termina com `halt`.

Com a semente inicial `7`, a saída é `036`. Os zeros à esquerda são intencionais para simplificar este início. A faixa de 0 a 255 é uma escolha didática baseada na sugestão do guia.

É um gerador **pseudoaleatório**: a mesma semente produz a mesma sequência. Recarregar o programa com a semente 7 produz novamente 036. Esse início ainda não resolve a variação automática entre execuções. Chamadas adicionais a `gera_numero` avançam o estado guardado em memória.

## Montar e executar no WSL

Na pasta principal do projeto:

```bash
make -C simulador_completo
./simulador_completo/bin/simulador simulador_completo/exemplos/t1_aleatorio.mob
```

O Makefile existente já reconhece o novo `.asm`. No simulador, pressione `C` para executar, `1` para observar uma instrução por vez e `F` para sair.

## Para continuar o exercício

- Experimente mudar `semente` e conferir o primeiro resultado pela fórmula.
- Acrescente um laço no `main` para gerar e imprimir dez valores.
- Depois, escolha como fornecer uma semente variável, por exemplo por entrada do usuário.

## Sugestão de commit para avaliação

Nenhum commit foi realizado.

```text
feat: adiciona inicio do T1 em um unico programa Assembly

- implementa gerador pseudoaleatorio com semente fixa
- imprime um valor de 0 a 255 com tres digitos na console
- documenta execucao e proximas etapas
```
