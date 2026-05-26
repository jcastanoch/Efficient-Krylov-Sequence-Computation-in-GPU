ifeq ($(OS),Windows_NT)
    SHELL := C:/Program Files/Git/usr/bin/sh.exe
endif

CC     = gcc
NVCC   = nvcc
CFLAGS = -O0 -Wall -I include
NFLAGS = -O3 -Xptxas -O3 -I include

SRC_COMMON = src/common/benchmark.c  \
             src/common/main.c       \
             src/common/matrices.c   \
             src/common/metricas.c   \
             src/common/parametros.c

SRC_GEN      = src/common/gen_main.c \
               src/common/gen.c
SRC_GEN_DEPS = src/common/matrices.c \
               src/common/parametros.c

SRC_CPU = src/cpu/matmul_cpu.c

SRC_GPU = src/gpu/matmul_gpu.cu                \
          src/gpu/gpu_memory.cu                \
          src/gpu/kernels/kernel_naive.cu      \
          src/gpu/kernels/kernel_coalesced.cu  \
          src/gpu/kernels/kernel_tiled.cu      \
          src/gpu/kernels/kernel_cublas.cu

BUILD = build

$(BUILD):
	mkdir -p $(BUILD)

cpu: $(BUILD)
	$(CC) $(CFLAGS) $(SRC_COMMON) $(SRC_CPU) -o $(BUILD)/benchmark_cpu
ifdef EXP
	./$(BUILD)/benchmark_cpu $(EXP)
else ifneq ($(wildcard data/params.txt),)
	./$(BUILD)/benchmark_cpu
else
	$(error No se especifico EXP y no existe data/params.txt. Corre 'make gen EXP=<n>' primero)
endif

gpu: $(BUILD)
ifndef GPU_KERNEL
	$(error Especifica el kernel: make gpu GPU_KERNEL=<NAIVE|COALESCED|TILED|CUBLAS>)
endif
	$(NVCC) $(NFLAGS) -DUSE_CUDA -DSEL_$(GPU_KERNEL) \
	    $(SRC_COMMON) $(SRC_GPU) -lcublas -o $(BUILD)/benchmark_gpu
ifdef EXP
	./$(BUILD)/benchmark_gpu $(EXP)
else ifneq ($(wildcard data/params.txt),)
	./$(BUILD)/benchmark_gpu
else
	$(error No se especifico EXP y no existe data/params.txt. Corre 'make gen EXP=<n>' primero)
endif

gen: $(BUILD)
ifndef EXP
	$(error Especifica el exponente: make gen EXP=<n>)
endif
	$(CC) $(CFLAGS) $(SRC_GEN) $(SRC_GEN_DEPS) -o $(BUILD)/gen_matrices
	./$(BUILD)/gen_matrices $(EXP)

clean:
	rm -rf $(BUILD)

benchmark: $(BUILD)
ifndef EXPS
	$(error Especifica los exponentes: make benchmark EXPS="10 11 12")
endif
	@echo "=== Compilando binarios ==="
	$(CC) $(CFLAGS) $(SRC_COMMON) $(SRC_CPU) -o $(BUILD)/benchmark_cpu
	$(CC) $(CFLAGS) $(SRC_GEN) $(SRC_GEN_DEPS) -o $(BUILD)/gen_matrices
	$(NVCC) $(NFLAGS) -DUSE_CUDA -DSEL_NAIVE \
	    $(SRC_COMMON) $(SRC_GPU) -lcublas -o $(BUILD)/benchmark_gpu_naive
	$(NVCC) $(NFLAGS) -DUSE_CUDA -DSEL_COALESCED \
	    $(SRC_COMMON) $(SRC_GPU) -lcublas -o $(BUILD)/benchmark_gpu_coalesced
	$(NVCC) $(NFLAGS) -DUSE_CUDA -DSEL_TILED \
	    $(SRC_COMMON) $(SRC_GPU) -lcublas -o $(BUILD)/benchmark_gpu_tiled
	$(NVCC) $(NFLAGS) -DUSE_CUDA -DSEL_CUBLAS \
	    $(SRC_COMMON) $(SRC_GPU) -lcublas -o $(BUILD)/benchmark_gpu_cublas

	$(MAKE) _run_exps

_run_exps:
	$(foreach exp,$(EXPS),$(MAKE) _run_one EXP=$(exp) &&) true

_run_one:
	@echo ""
	@echo "============================================"
	@echo "  Exponente: $(EXP)  (N = 2^$(EXP))"
	@echo "============================================"
	@echo "--- Generando matrices ---"
	echo s | ./$(BUILD)/gen_matrices $(EXP)
	@echo "--- CPU ---"
	./$(BUILD)/benchmark_cpu $(EXP)
	@echo "--- GPU NAIVE ---"
	./$(BUILD)/benchmark_gpu_naive $(EXP)
	@echo "--- GPU COALESCED ---"
	./$(BUILD)/benchmark_gpu_coalesced $(EXP)
	@echo "--- GPU TILED ---"
	./$(BUILD)/benchmark_gpu_tiled $(EXP)
	@echo "--- GPU CUBLAS ---"
	./$(BUILD)/benchmark_gpu_cublas $(EXP)

benchmark_gpu: $(BUILD)
ifndef EXPS
	$(error Especifica los exponentes: make benchmark_gpu EXPS="10 11 12")
endif
	@echo "=== Compilando binarios (solo GPU) ==="
	$(CC) $(CFLAGS) $(SRC_GEN) $(SRC_GEN_DEPS) -o $(BUILD)/gen_matrices
	$(NVCC) $(NFLAGS) -DUSE_CUDA -DSEL_NAIVE \
	    $(SRC_COMMON) $(SRC_GPU) -lcublas -o $(BUILD)/benchmark_gpu_naive
	$(NVCC) $(NFLAGS) -DUSE_CUDA -DSEL_COALESCED \
	    $(SRC_COMMON) $(SRC_GPU) -lcublas -o $(BUILD)/benchmark_gpu_coalesced
	$(NVCC) $(NFLAGS) -DUSE_CUDA -DSEL_TILED \
	    $(SRC_COMMON) $(SRC_GPU) -lcublas -o $(BUILD)/benchmark_gpu_tiled
	$(NVCC) $(NFLAGS) -DUSE_CUDA -DSEL_CUBLAS \
	    $(SRC_COMMON) $(SRC_GPU) -lcublas -o $(BUILD)/benchmark_gpu_cublas

	$(MAKE) _run_exps_gpu

_run_exps_gpu:
	$(foreach exp,$(EXPS),$(MAKE) _run_one_gpu EXP=$(exp) &&) true

_run_one_gpu:
	@echo ""
	@echo "============================================"
	@echo "  Exponente: $(EXP)  (N = 2^$(EXP))  [solo GPU]"
	@echo "============================================"
	@echo "--- Generando matrices ---"
	echo s | ./$(BUILD)/gen_matrices $(EXP)
	@echo "--- GPU NAIVE ---"
	./$(BUILD)/benchmark_gpu_naive $(EXP)
	@echo "--- GPU COALESCED ---"
	./$(BUILD)/benchmark_gpu_coalesced $(EXP)
	@echo "--- GPU TILED ---"
	./$(BUILD)/benchmark_gpu_tiled $(EXP)
	@echo "--- GPU CUBLAS ---"
	./$(BUILD)/benchmark_gpu_cublas $(EXP)