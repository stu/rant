
#include <stdio.h>
#include "test.h"
#include "another_test.h"

int main(char argc, char** argv)
{
    test();
    another_test();
    printf("Hello, world!\n");
    return 0;
}
