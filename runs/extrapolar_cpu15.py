"""
Extrapolacion de resultados del benchmark exp15 en CPU.

El run real (runs/cpu_15_0525_230241/) se realizó para 128 iteraciones pues la run completa ~60 horas. 
Para poder compararlo con los datos de GPU, este script genera datos sintéticos para las iteraciones restantes
basándose en el comportamiendo observado en el estado estable de las iteraciones reales.

Salidas (en runs/cpu_15_extrapolado/):
  - benchmark.csv         : CSV con iter, tiempo_ms, gflops (real + extrapolado)
  - benchmark_info.txt    : resumen estadistico actualizado
  - extrapolacion_info.txt: detalles del modelo y separacion real vs sintetico
"""

import csv
import math
import random
from pathlib import Path

SOURCE_DIR  = Path(__file__).parent / "cpu_15_0525_230241"
OUTPUT_DIR  = Path(__file__).parent / "cpu_15_extrapolado"
SOURCE_CSV  = SOURCE_DIR / "benchmark.csv"

TARGET_ITERS = 512        # exp15 completo
WARMUP_ITERS = 5          # primeras iteraciones que se excluyen del modelo para esperar a que los valores alcancen el estado estable
SEED         = 20260526   

MATRIX_N = 32768
BLOCK_M  = 128


def read_real_rows(path):
    rows = []
    with open(path, newline="") as fh:
        reader = csv.DictReader(fh)
        for r in reader:
            rows.append((
                int(r["iter"]),
                float(r["tiempo_ms"]),
                float(r["gflops"]),
            ))
    return rows


def mean_std(values):
    n = len(values)
    mean = sum(values) / n
    var = sum((v - mean) ** 2 for v in values) / (n - 1)
    return mean, math.sqrt(var)


def main():
    OUTPUT_DIR.mkdir(exist_ok=True)
    real = read_real_rows(SOURCE_CSV)
    n_real = len(real)
    if n_real >= TARGET_ITERS:
        raise SystemExit(f"El CSV ya tiene {n_real} filas (>= {TARGET_ITERS}).")

    # FLOPs por iteracion: constante derivada de cualquier fila real
    # (gflops = flops_iter / (tiempo_ms * 1e6)).
    # Usamos el promedio sobre el estado estable para reducir ruido numerico.
    flops_iter_samples = [g * t * 1e6 for (_, t, g) in real[WARMUP_ITERS:]]
    flops_iter = sum(flops_iter_samples) / len(flops_iter_samples)

    steady_times = [t for (_, t, _) in real[WARMUP_ITERS:]]
    mu_t, sigma_t = mean_std(steady_times)
    t_min = min(steady_times)
    t_max = max(steady_times)

    rng = random.Random(SEED)

    synthetic = []
    for i in range(n_real, TARGET_ITERS):
        # Muestreo gaussiano en torno al estado estable, recortado al rango
        # observado para no inventar valores fuera del comportamiento real.
        t = rng.gauss(mu_t, sigma_t)
        # Truncado simetrico al rango observado (clamp).
        if t < t_min:
            t = t_min + abs(rng.gauss(0, sigma_t * 0.5))
        elif t > t_max:
            t = t_max - abs(rng.gauss(0, sigma_t * 0.5))
        t = max(t_min, min(t_max, t))
        g = flops_iter / (t * 1e6)
        synthetic.append((i, t, g))

    # Escribir CSV combinado
    out_csv = OUTPUT_DIR / "benchmark.csv"
    with open(out_csv, "w", newline="") as fh:
        w = csv.writer(fh)
        w.writerow(["iter", "tiempo_ms", "gflops"])
        for (i, t, g) in real + synthetic:
            w.writerow([i, f"{t:.6f}", f"{g:.6f}"])

    all_times  = [t for (_, t, _) in real + synthetic]
    all_gflops = [g for (_, _, g) in real + synthetic]
    total_ms = sum(all_times)
    mu_all, sigma_all = mean_std(all_times)
    mu_g, sigma_g     = mean_std(all_gflops)
    gflops_total = sum(all_gflops)

    info = OUTPUT_DIR / "benchmark_info.txt"
    with open(info, "w") as fh:
        fh.write("=== Benchmark Info (real + extrapolado) ===\n")
        fh.write(f"Dimensiones     : A({MATRIX_N} x {MATRIX_N}) x Z({MATRIX_N} x {BLOCK_M})\n")
        fh.write(f"Iteraciones     : {len(all_times)}\n")
        fh.write(f"Tiempo total    : {total_ms:.3f} ms\n")
        fh.write(f"Tiempo promedio : {mu_all:.3f} ms\n")
        fh.write(f"Tiempo min      : {min(all_times):.3f} ms\n")
        fh.write(f"Tiempo max      : {max(all_times):.3f} ms\n")
        fh.write(f"Desv. estandar del tiempo  : {sigma_all:.3f} ms\n")
        fh.write(f"GFLOPs totales  : {gflops_total:.3f}\n")
        fh.write(f"GFLOPs promedio : {mu_g:.3f}\n")
        fh.write(f"Desv. estandar de GFLOPs : {sigma_g:.3f}\n")

    detalle = OUTPUT_DIR / "extrapolacion_info.txt"
    with open(detalle, "w") as fh:
        fh.write("=== Detalle de la extrapolacion ===\n")
        fh.write(f"Iteraciones reales    : {n_real} (0..{n_real-1})\n")
        fh.write(f"Iteraciones objetivo  : {TARGET_ITERS}\n")
        fh.write(f"Iteraciones sinteticas: {len(synthetic)} ({n_real}..{TARGET_ITERS-1})\n")
        fh.write(f"Warmup excluido       : primeras {WARMUP_ITERS} iter\n")
        fh.write("\nModelo: tiempo ~ N(mu, sigma) recortado a [min, max] del estado estable.\n")
        fh.write(f"  mu    (ms) = {mu_t:.3f}\n")
        fh.write(f"  sigma (ms) = {sigma_t:.3f}\n")
        fh.write(f"  min   (ms) = {t_min:.3f}\n")
        fh.write(f"  max   (ms) = {t_max:.3f}\n")
        fh.write(f"  FLOPs/iter = {flops_iter:.3e}\n")
        fh.write(f"  semilla    = {SEED}\n")
        fh.write("\ngflops sintetico se deriva como flops_iter / (tiempo_ms * 1e6),\n")
        fh.write("preservando la relacion exacta vista en los datos reales.\n")

    print(f"Listo. {len(synthetic)} iteraciones sinteticas anadidas.")
    print(f"  CSV : {out_csv}")
    print(f"  info: {info}")
    print(f"  doc : {detalle}")


if __name__ == "__main__":
    main()
