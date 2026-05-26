//! parametros.c - Implementación de funciones para manejo de parámetros de entrada y creación de directorio de salida.
//!
//! Este módulo contiene funciones para imprimir los parámetros de entrada, leerlos desde un archivo de texto y 
//! crear un directorio de salida basado en el input y la fecha/hora actual.
//!
#include <stdio.h>
#include <time.h>
#include <direct.h>
#include "common/parametros.h"

/// Imprime los parámetros de entrada de forma formateada en la consola.
///
/// # Argumentos
/// - `p`: Estructura Parametros que contiene los valores a imprimir.
/// 
void print_parametros(Parametros p) {
    printf("\n================================================\n");
    printf("            PARAMETROS DE ENTRADA\n");
    printf("================================================\n");
    printf("  Exponente (input)  : %d\n",      p.input);
    printf("  Dimension A        : %d x %d\n", p.m, p.m);
    printf("  Columnas Z (n)     : %d\n",      p.n);
    printf("  Iteraciones (l)    : %d\n",      p.l);
    printf("================================================\n");
}

/// Lectura de parámetros desde el archivo "params.txt" ubicado en el directorio dado.
///
/// Lee el archivo de texto generado por guardar_parametros() y llena la estructura Parametros.
/// 
/// # Argumentos
/// - `dir`: Directorio donde se encuentra el archivo "params.txt".
/// - `p`: Puntero a la estructura Parametros que se llenará con los valores leídos.
///
int leer_params(const char *dir, Parametros *p) {
    
    char ruta[256];
    snprintf(ruta, sizeof(ruta), "%s/params.txt", dir);

    FILE *f = fopen(ruta, "r");
    if (!f) {
        fprintf(stderr, "Error: no se pudo abrir %s\n", ruta);
        fprintf(stderr, "Tip: corre 'make gen EXP=<n>' primero\n");
        return -1;
    }

    int leidos = fscanf(f,
        "input %d\n"
        "m %d\n"
        "n %d\n"
        "l %d\n",
        &p->input, &p->m, &p->n, &p->l);
    
    fclose(f);

    if (leidos != 4) {
        fprintf(stderr, "Error: params.txt mal formado (leidos: %d/4)\n", leidos);
        return -1;
    }

    return 0;
}

/// Crea un directorio de salida con un nombre basado en el input y la fecha/hora actual.
/// 
/// El nombre del directorio sigue el formato "gpu_input_MMDD_HHMMSS" o "cpu_input_MMDD_HHMMSS" dependiendo
/// de si se compila con CUDA o no. También escribe el nombre del directorio creado en un archivo
/// ".last_outdir" para facilitar su acceso por scripts de análisis.
///
/// # Argumentos
/// - `input`: Exponente dado por el usuario (m = 2^input).
/// - `outdir`: Buffer donde se almacenará el nombre del directorio creado.
/// - `size`: Tamaño del buffer `outdir`.
///
int crear_outdir(int input, char *outdir, size_t size) {

    time_t t = time(NULL);
    struct tm *tm_info = localtime(&t);
    char ts[16];
    strftime(ts, sizeof(ts), "%m%d_%H%M%S", tm_info);

    #if defined(USE_CUDA)
        #if defined(SEL_TILED)
            snprintf(outdir, size, "runs/gpu_tiled_%d_%s", input, ts);
        #elif defined(SEL_COALESCED)
            snprintf(outdir, size, "runs/gpu_coalesced_%d_%s", input, ts);
        #elif defined(SEL_CUBLAS)
            snprintf(outdir, size, "runs/gpu_cublas_%d_%s", input, ts);
        #else
            snprintf(outdir, size, "runs/gpu_naive_%d_%s", input, ts);
        #endif
    #else
        snprintf(outdir, size, "runs/cpu_%d_%s", input, ts);
    #endif

    _mkdir("runs");         

    if (_mkdir(outdir) != 0) {
        fprintf(stderr, "Error: no se pudo crear %s\n", outdir);
        return -1;
    }

    printf("Directorio de salida: %s\n", outdir);
    return 0;
}