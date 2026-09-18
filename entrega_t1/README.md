# Entrega T1 em C

Edite `t1_aleatorio.c`. Ele é o único fonte do seu programa; o compilador e a biblioteca Mancha ficam nas pastas existentes do projeto.

O programa gera um valor pseudoaleatório de 0 a 255 e imprime `36` seguido de uma quebra de linha. A semente fixa em 7 faz o resultado se repetir ao carregar novamente o programa. Esta é a versão inicial, sem semente variável ou laço para dez valores.

## Compilar e executar no WSL

Execute os comandos abaixo na **raiz do projeto**, no terminal WSL/Linux:

```bash
# Prepara o simulador, montador, compilador e biblioteca do projeto.
make

# Converte seu C em Assembly Mancha.
./compilador_c/bin/mcc -Icompilador_c/inc entrega_t1/t1_aleatorio.c -o entrega_t1/t1_aleatorio.asm

# Junta o Assembly com as rotinas de suporte e gera o executavel Mancha.
./simulador_completo/bin/montador compilador_c/rt/runtime.asm compilador_c/rt/biblioteca.asm entrega_t1/t1_aleatorio.asm -o entrega_t1/t1_aleatorio.mob

# Abre o programa no simulador.
./simulador_completo/bin/simulador entrega_t1/t1_aleatorio.mob
```

Digite `C` e Enter para executar, e `F` e Enter para sair. A saída aparece em `console (saida)`, no topo da tela.

Após editar o C, repita a conversão, a montagem e a execução. O `make` da raiz prepara as ferramentas, mas não compila automaticamente esta pasta.

O `.asm` e o `.mob` são arquivos gerados do mesmo programa. Não edite esse `.asm` para preservar mudanças: a próxima conversão do C o sobrescreve. O início anterior escrito diretamente em Assembly continua em `simulador_completo/exemplos/t1_aleatorio.asm` como referência independente.

## Sugestão de commit para avaliação

Nenhum commit foi realizado.

```text
feat: adiciona versao C do T1 na pasta entrega_t1

- cria programa inicial com geracao pseudoaleatoria e impressao
- documenta conversao para Assembly e montagem fora de exemplos
```
