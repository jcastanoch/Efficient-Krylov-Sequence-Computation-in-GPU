# Cómputo Eficiente de Secuencias de Krylov en GPU

> Benchmarking de multiplicación iterativa de matrices para generación de subespacios de Krylov, comparativa entre CPU base y GPU con CUDA.

![C](https://img.shields.io/badge/C-00599C?style=flat&logo=c&logoColor=white)
![CUDA](https://img.shields.io/badge/CUDA-76B900?style=flat&logo=nvidia&logoColor=white)
![Plataforma](https://img.shields.io/badge/plataforma-Windows-blue)

---

## Tabla de Contenidos

1. [Subespacios de Krylov](#subespacios-de-krylov)
2. [Algoritmo](#algoritmo)
3. [Estructura del Proyecto](#estructura-del-proyecto)
4. [Formato de Matrices](#formato-de-matrices)
5. [Documentación](#documentación)
6. [Inicio Rápido](#inicio-rápido)

---

## Subespacios de Krylov

Un **subespacio de Krylov** de orden *r* generado por una matriz *m×m* *A* y un vector *z* es el subespacio vectorial generado por los productos matriz-vector sucesivos:

$$\mathcal{K}_l(A, z) = \text{span}\{z,\ Az,\ \ldots,\ A^{l-1}z\}$$

Los subespacios de Krylov son la base de los solvers iterativos para sistemas lineales grandes y problemas de autovalores (GMRES, Lanczos, Arnoldi). Su cómputo eficiente es crítico cuando *m* es grande, lo que los convierte en un objetivo ideal para su optimización.

Para saber más, revisar la investigación que se hizo para el proyecto en <a href="docs/research.md">Ver investigación</a>

([volver arriba](#cómputo-eficiente-de-secuencias-de-krylov-en-gpu))

---

## Algoritmo

El benchmark computa una **secuencia de Krylov por bloques** que reemplaza el vector inicial por una matriz *Z*.

### Parámetros

| Símbolo | Descripción | Valor |
| ------- | ----------- | ----- |
| `m` | Tamaño del problema (dimensión de la matriz) | 2¹⁰ ≤ m ≤ 2²⁰ |
| `n` | Tamaño del bloque (constante) | 128 |
| `A` | Matriz cuadrada (*m × m*, float) | aleatoria row-estocástica |
| `Z` | Matriz de bloque (*m × n*, float) | aleatoria |
| `l` | Número de iteraciones | `l = 2m/n` |

### Bucle

Para `i = 0, 1, ..., l − 1`:

1. Calcular `A · Z` (multiplicación de matrices, *m×m* × *m×n*)
2. Guardar las primeras `n` filas del resultado como snapshot de la iteración `i`
3. Actualizar `Z ← A · Z` para la siguiente iteración

El resultado es una secuencia de *l* snapshots de tamaño *n×n*.

([volver arriba](#cómputo-eficiente-de-secuencias-de-krylov-en-gpu))

---

## Estructura del Proyecto

WIP

([volver arriba](#cómputo-eficiente-de-secuencias-de-krylov-en-gpu))

---

## Documentación

WIP


([volver arriba](#cómputo-eficiente-de-secuencias-de-krylov-en-gpu))

---

## Inicio Rápido

### Prerrequisitos

#### CPU

- MinGW-w64 (Windows)
- GNU Make

#### GPU

- GPU NVIDIA con CUDA Toolkit ≥ 11
- `nvcc` disponible en el PATH

### Clonar

```bash
git clone https://github.com/<your-username>/efficient-krylov-sequence-computation-in-gpu.git
cd efficient-krylov-sequence-computation-in-gpu
```

### Generar matrices de entrada

```bash
# Genera matrices para m = 2^EXP (default: 8)
make gen EXP=10
```

### Ejecutar benchmark CPU

```bash
# Un solo exponente
make cpu

# Con exponente específico
make cpu EXP=12
```

### Ejecutar benchmark GPU

```bash
# Kernel específico (NAIVE | COALESCED | TILED | CUBLAS)
make gpu GPU_KERNEL=TILED EXP=12

# Todos los kernels para un exponente
make gpu GPU_KERNEL=NAIVE     EXP=12
make gpu GPU_KERNEL=COALESCED EXP=12
make gpu GPU_KERNEL=TILED     EXP=12
make gpu GPU_KERNEL=CUBLAS    EXP=12
```

### Ejecutar benchmark completo

Corre CPU y los cuatro kernels GPU para cada exponente, en orden:

```bash
# Rango por defecto: exponentes 10 a 14
make benchmark

# Rango personalizado
make benchmark EXPS="8 9 10 11"
```

La salida agrupa los resultados por exponente, mostrando primero CPU y luego cada modo GPU:

```
============================================
  Exponente: 10  (N = 2^10)
============================================
--- CPU ---
...
--- GPU NAIVE ---
...
--- GPU COALESCED ---
...
--- GPU TILED ---
...
--- GPU CUBLAS ---
...
```

### Ejecutar benchmark solo GPU

Igual que `benchmark`, pero **omite la fase CPU**. Útil cuando solo interesa comparar kernels GPU o cuando la corrida CPU es muy lenta para los exponentes elegidos. Para cada exponente del rango, corre NAIVE → COALESCED → TILED → CUBLAS y pasa al siguiente.

```bash
# Rango personalizado (obligatorio)
make benchmark_gpu EXPS="10 11 12 13 14"
```

Salida:

```
============================================
  Exponente: 10  (N = 2^10)  [solo GPU]
============================================
--- GPU NAIVE ---
...
--- GPU COALESCED ---
...
--- GPU TILED ---
...
--- GPU CUBLAS ---
...
```

### Limpiar

```bash
make clean
```

([volver arriba](#cómputo-eficiente-de-secuencias-de-krylov-en-gpu))
