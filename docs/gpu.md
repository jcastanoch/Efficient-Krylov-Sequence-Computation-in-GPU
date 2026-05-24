## Implementación GPU

La implementación GPU en `src/gpu/matmul_gpu.cu` selecciona automáticamente el modo de ejecución según la VRAM disponible en tiempo de inicialización.

### Modo FULL

Si `A + Z_in + Z_out + snapshot` caben en el 85 % de la VRAM libre, se asignan todas las matrices directamente en la GPU y cada iteración lanza un único kernel.

### Modo SLAB (fallback)

Si `A` no cabe en VRAM, se almacena en memoria host *pinned* (`cudaMallocHost`) y se procesa en **slabs horizontales** con doble buffer y dos streams CUDA:

- `Z_in` y `Z_out` residen siempre completos en VRAM.
- El tamaño máximo del slab se calcula dinámicamente a partir de la VRAM restante.
- Mientras un stream ejecuta el kernel sobre el slab actual, el otro transfiere el siguiente slab por PCIe (`cudaMemcpyAsync`), ocultando la latencia de transferencia.

### Kernel tiled

Ambos modos usan el mismo kernel `tiled_mat_mul_kernel` con tiles de 32×32 en memoria compartida:

- Acceso coalescido a `A` y `Z_in`.
- Sin conflictos de bancos en memoria compartida.
- `#pragma unroll` en el bucle de acumulación interno.

([volver arriba](#cómputo-eficiente-de-secuencias-de-krylov-en-gpu))

---