# Compilar e executar C com o Mancha no WSL

Guia rápido para compilar programas C com o compilador do projeto (`mcc`), montar o resultado e executá-lo no simulador Mancha. Execute os comandos no terminal do WSL (Ubuntu ou Debian).

## 1. Preparar o ambiente (uma vez)

```bash
sudo apt update
sudo apt install build-essential libncurses-dev
```

`build-essential` instala as ferramentas necessárias para construir o próprio compilador, montador e simulador. O Makefile usa GCC nessa preparação; seus programas para o Mancha são compilados pelo `mcc`. `libncurses-dev` é necessário para a interface do simulador.

## 2. Entrar na pasta deste projeto

Abra o terminal do WSL e execute:

```bash
cd "/mnt/c/Users/1luca/EU/03_Faculdade/4 Semestre/Sistemas Operacionais"
```

No WSL, a unidade `C:` fica normalmente em `/mnt/c`. Mantenha as aspas porque o caminho contém espaços.

## 3. Compilar e executar o projeto Mancha

Na pasta principal do projeto:

```bash
# Compila o simulador, o montador, o compilador C e os exemplos
make

# Executa o exemplo C "ola" no simulador
./simulador_completo/bin/simulador compilador_c/exemplos/ola.mob
```

No simulador, use `C` para continuar a execução, `1` para executar uma instrução e `F` para sair. Use um terminal com pelo menos 90 colunas e 36 linhas.

Para executar outro exemplo, troque `ola.mob` por `fatorial.mob`, `operadores.mob`, `structs.mob`, `lista.mob`, `preprocessador.mob` ou `eco.mob`.

### Recompilar após alterar o código

Execute na pasta principal:

```bash
make
```

Para limpar os resultados da compilação e compilar novamente:

```bash
make clean
make
```

`make clean` remove os executáveis e os arquivos gerados dos exemplos, incluindo os `.asm` e `.mob` de `compilador_c/exemplos/`. Guarde código Assembly escrito manualmente em outra pasta.

### Compilar um programa C próprio para o Mancha

Primeiro execute `make` na pasta principal. Depois, considerando que seu arquivo está em `compilador_c/meuprograma.c`:

```bash
cd compilador_c

# C → Assembly Mancha
./bin/mcc -Iinc meuprograma.c -o meuprograma.asm

# Assembly + rotinas de suporte → arquivo do simulador
../simulador_completo/bin/montador rt/runtime.asm rt/biblioteca.asm meuprograma.asm -o meuprograma.mob

# Executar
../simulador_completo/bin/simulador meuprograma.mob

# Voltar à pasta principal
cd ..
```

O `mcc` aceita um subconjunto de C e usa a biblioteca `mancha.h`. Consulte [a documentação do compilador](compilador_c/README.md) para os recursos disponíveis.

## 4. Problemas comuns

| Mensagem ou situação | O que fazer |
|---|---|
| `gcc: command not found` ou `make: command not found` | Instale `build-essential` conforme a seção 1. |
| `curses.h: No such file or directory` ou `cannot find -lcurses` | Instale `libncurses-dev`. |
| `No rule to make target` ou nenhum Makefile encontrado | Confira a pasta atual com `pwd` e os arquivos com `ls`. |
| `./bin/mcc` ou montador não encontrado | Execute `make` na pasta principal e confira o diretório indicado em cada etapa. |
| Arquivo ou diretório não encontrado | Confira o nome com `ls`; Linux diferencia maiúsculas de minúsculas. |

Os comandos do projeto foram conferidos com os Makefiles e READMEs locais. Este guia não implica que a compilação tenha sido executada no seu WSL.
