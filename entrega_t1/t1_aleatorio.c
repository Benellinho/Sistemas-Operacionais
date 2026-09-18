#include <mancha.h>

/* Semente fixa: ao carregar o programa novamente, o resultado se repete. */
int semente = 7;

/* Gera um valor de 0 a 255 e guarda o estado para a proxima chamada. */
int gera_numero(void) {
    semente = (5 * semente + 1) & 255;
    return semente;
}

int main(void) {
    int numero = gera_numero();

    print_int(numero);
    putchar(10); /* Quebra de linha. */

    return 0;
}
