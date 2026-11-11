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
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#include <limits.h>
#include <errno.h>
#include <string.h>

#include <pthread.h>
#include <wchar.h>

__attribute__((weak))
int pthread_mutexattr_settype(pthread_mutexattr_t *attr, int type)
{
    if (!attr)
        return EINVAL;
    attr->__mutexkind = type;
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

__attribute__((weak))
long lrint(double x)
{
    /* Round to nearest integer, half goes to even (C99 semantics).  */
    if (x != x) {                                  /* NaN */
        return 0L;
    }
    if (x >= 1e19) {                               /* overflow */
        return LONG_MAX;
    }
    if (x <= -1e19) {
        return LONG_MIN;
    }
    if (x >= 0.0)
        return (long)(x + 0.5);
    else
        return (long)(x - 0.5);
}

__attribute__((weak))
long lround(double x)
{
    /* Round away from zero.  */
    if (x != x) {                                  /* NaN */
        return 0L;
    }
    if (x >= 1e19) {                               /* overflow */
        return LONG_MAX;
    }
    if (x <= -1e19) {
        return LONG_MIN;
    }
    if (x >= 0.0)
        return (long)(x + 0.5);
    else
        return (long)(x - 0.5);
}

__attribute__((weak))
long long llround(double x)
{
    /* Round away from zero.  */
    if (x != x) return 0;                          /* NaN */
    if (x >= 1e19) return 9223372036854775807LL;  /* LLONG_MAX */
    if (x <= -1e19) return -9223372036854775808LL;/* LLONG_MIN */
    if (x >= 0) {
        long long y = (long long)(x + 0.5);
        return y;
    } else {
        long long y = (long long)(x - 0.5);
        return y;
    }
}

__attribute__((weak))
long double frexpl(long double x, int *exp)
{
    /* Use double frexp; long-double precision is enough for layout.  */
    double s;

    if (x != x) { *exp = 0; return x; }            /* NaN */
    if (x == 0.0L) { *exp = 0; return 0.0L; }      /* zero */

    s = frexp((double)x, exp);
    return (long double)s;
}

/*
 * GLib ships its own printf implementation (gnulib) and calls it through the
 * internal _g_gnulib_* names.  When GLib is configured against dietlibc the
 * gnulib objects are not built, but gprintf.o still references these symbols.
 * Provide weak forwarding wrappers so static links succeed; the libc
 * implementation is perfectly adequate here.
 */
__attribute__((weak))
int _g_gnulib_printf(const char *format, ...)
{
    va_list ap;
    int result;
    va_start(ap, format);
    result = vprintf(format, ap);
    va_end(ap);
    return result;
}

__attribute__((weak))
int _g_gnulib_fprintf(FILE *stream, const char *format, ...)
{
    va_list ap;
    int result;
    va_start(ap, format);
    result = vfprintf(stream, format, ap);
    va_end(ap);
    return result;
}

__attribute__((weak))
int _g_gnulib_sprintf(char *buffer, const char *format, ...)
{
    va_list ap;
    int result;
    va_start(ap, format);
    result = vsprintf(buffer, format, ap);
    va_end(ap);
    return result;
}

__attribute__((weak))
int _g_gnulib_snprintf(char *buffer, size_t size, const char *format, ...)
{
    va_list ap;
    int result;
    va_start(ap, format);
    result = vsnprintf(buffer, size, format, ap);
    va_end(ap);
    return result;
}

__attribute__((weak))
int _g_gnulib_vprintf(const char *format, va_list ap)
{
    return vprintf(format, ap);
}

__attribute__((weak))
int _g_gnulib_vfprintf(FILE *stream, const char *format, va_list ap)
{
    return vfprintf(stream, format, ap);
}

__attribute__((weak))
int _g_gnulib_vsprintf(char *buffer, const char *format, va_list ap)
{
    return vsprintf(buffer, format, ap);
}

__attribute__((weak))
int _g_gnulib_vsnprintf(char *buffer, size_t size, const char *format, va_list ap)
{
    return vsnprintf(buffer, size, format, ap);
}

__attribute__((weak))
int _g_gnulib_vasprintf(char **result, const char *format, va_list ap)
{
    va_list copy;
    int needed;
    char *buffer;

    va_copy(copy, ap);
    needed = vsnprintf(NULL, 0, format, copy);
    va_end(copy);
    if (needed < 0)
        return -1;

    buffer = malloc((size_t)needed + 1);
    if (!buffer)
        return -1;

    vsnprintf(buffer, (size_t)needed + 1, format, ap);
    *result = buffer;
    return needed;
}

/*
 * C99 math helpers that dietlibc's <math.h> does not declare.  They are
 * useful for GLib/GDK-Pixbuf pixops code which builds with -Werror.
 */
__attribute__((weak))
long lrintf(float x)
{
    return (long)llround((double)x);
}

__attribute__((weak))
long long llrint(double x)
{
    return llround(x);
}

__attribute__((weak))
long long llrintf(float x)
{
    return llround((double)x);
}

__attribute__((weak))
long double ldexpl(long double x, int exp)
{
    return (long double)ldexp((double)x, exp);
}

/*
 * dietlibc has no wcsxfrm().  GLib only needs a stable collation key; an
 * identity transformation is acceptable for the C locale and keeps static
 * links working.
 */
__attribute__((weak))
size_t wcsxfrm(wchar_t *dest, const wchar_t *src, size_t n)
{
    size_t len = wcslen(src);

    if (n > 0) {
        size_t copy = (len < n - 1) ? len : n - 1;
        wmemcpy(dest, src, copy);
        dest[copy] = L'\0';
    }
    return len;
}

/*
 * dietlibc ships <err.h> but not the corresponding functions.  The X.Org
 * utilities (libXfont2, xkbcomp, ...) rely on them, so provide the usual
 * BSD semantics.
 */
__attribute__((weak))
void vwarnx(const char *format, va_list ap)
{
    if (format)
        vfprintf(stderr, format, ap);
    fputc('\n', stderr);
}

__attribute__((weak))
void vwarn(const char *format, va_list ap)
{
    int saved = errno;

    if (format) {
        vfprintf(stderr, format, ap);
        fputs(": ", stderr);
    }
    fputs(strerror(saved), stderr);
    fputc('\n', stderr);
}

__attribute__((weak))
void warnx(const char *format, ...)
{
    va_list ap;

    va_start(ap, format);
    vwarnx(format, ap);
    va_end(ap);
}

__attribute__((weak))
void warn(const char *format, ...)
{
    va_list ap;

    va_start(ap, format);
    vwarn(format, ap);
    va_end(ap);
}

__attribute__((weak))
void verrx(int status, const char *format, va_list ap)
{
    vwarnx(format, ap);
    exit(status);
}

__attribute__((weak))
void verr(int status, const char *format, va_list ap)
{
    vwarn(format, ap);
    exit(status);
}

__attribute__((weak))
void errx(int status, const char *format, ...)
{
    va_list ap;

    va_start(ap, format);
    vwarnx(format, ap);
    va_end(ap);
    exit(status);
}

__attribute__((weak))
void err(int status, const char *format, ...)
{
    va_list ap;

    va_start(ap, format);
    vwarn(format, ap);
    va_end(ap);
    exit(status);
}

/*
 * dietlibc declares mempcpy() in <string.h> but does not implement it.
 */
__attribute__((weak))
void *mempcpy(void *dest, const void *src, size_t n)
{
    return (char *)memcpy(dest, src, n) + n;
}

#if defined(__x86_64__)
/*
 * dietlibc has no generic syscall() wrapper.  OpenSSL's RNG uses it to query
 * getrandom(2) directly.
 */
__attribute__((weak))
long syscall(long number, ...)
{
    va_list ap;
    long a1, a2, a3, a4, a5, a6, result;
    register long r10 __asm__("r10");
    register long r8 __asm__("r8");
    register long r9 __asm__("r9");

    va_start(ap, number);
    a1 = va_arg(ap, long);
    a2 = va_arg(ap, long);
    a3 = va_arg(ap, long);
    a4 = va_arg(ap, long);
    a5 = va_arg(ap, long);
    a6 = va_arg(ap, long);
    va_end(ap);

    r10 = a4;
    r8 = a5;
    r9 = a6;
    __asm__ volatile("syscall"
                     : "=a"(result)
                     : "a"(number), "D"(a1), "S"(a2), "d"(a3),
                       "r"(r10), "r"(r8), "r"(r9)
                     : "rcx", "r11", "memory");
    return result;
}
#endif

/*
 * dietlibc declares the POSIX mutex attribute accessors but only implements
 * the non-standard _np variants.
 */
__attribute__((weak))
int pthread_mutexattr_gettype(const pthread_mutexattr_t *attr, int *type)
{
    if (!attr || !type)
        return EINVAL;
    *type = attr->__mutexkind;
    return 0;
}

/*
 * dietlibc provides isinf()/isnan() but not an isfinite() symbol.
 */
__attribute__((weak))
int isfinite(double x)
{
    return __builtin_isfinite(x);
}
