/*
 * dietcompat – small compatibility shim for packages that expect a few glibc
 * interfaces which dietlibc does not provide.
 *
 * This was carried over from CLEANUX (src/_compat/shim.c).  Unlike the CLEANUX
 * version it is compiled with the dietlibc toolchain, not with the host gcc, so
 * it does not drag glibc objects into a dietlibc link.
 *
 * All symbols are weak: if a package or dietlibc itself provides a real
 * implementation, the real one wins.
 */

#include <stddef.h>
#include <stdlib.h>
#include <math.h>

#include <pthread.h>

__attribute__((weak))
int pthread_mutexattr_settype(pthread_mutexattr_t *attr, int type)
{
    (void)attr;
    (void)type;
    return 0;
}

__attribute__((weak))
char *initstate(unsigned int seed, char *state, size_t n)
{
    (void)n;
    srand(seed);
    return state;
}

__attribute__((weak))
char *setstate(char *state)
{
    (void)state;
    return NULL;
}

__attribute__((weak))
double modf(double x, double *iptr)
{
    double i;

    if (x >= 0.0) {
        if (x < 9223372036854775808.0)
            i = (double)(long long)x;
        else {
            *iptr = x;
            return 0.0;
        }
    } else {
        if (x > -9223372036854775808.0)
            i = (double)(long long)x;
        else {
            *iptr = x;
            return 0.0;
        }
    }

    *iptr = i;
    return x - i;
}
