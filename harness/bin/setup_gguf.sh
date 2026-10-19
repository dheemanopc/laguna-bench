#!/bin/bash
# laguna-bench — llama.cpp (CUDA, sm_120) + Laguna S 2.1 GGUF Q5_K_M / Q6_K (bartowski) on the local NVMe
set -x; exec > >(tee -a /opt/bench/gguf-setup.log) 2>&1
N=/opt/dlami/nvme; sudo chown ubuntu:ubuntu $N; mkdir -p $N/gguf $N/src
export HF_HOME=/opt/bench/hf HF_XET_HIGH_PERFORMANCE=1
( /opt/bench/vllm/bin/hf download bartowski/Laguna-S-2.1-GGUF --include "Laguna-S-2.1-Q5_K_M*" --local-dir $N/gguf && echo "q5-downloaded $(date -u +%FT%TZ)" >> /opt/bench/status
  /opt/bench/vllm/bin/hf download bartowski/Laguna-S-2.1-GGUF --include "Laguna-S-2.1-Q6_K/*" --local-dir $N/gguf && echo "q6-downloaded $(date -u +%FT%TZ)" >> /opt/bench/status ) &
sudo apt-get install -y -q cmake build-essential libcurl4-openssl-dev >/dev/null
cd $N/src && git clone -q --depth 1 https://github.com/ggml-org/llama.cpp && cd llama.cpp && git rev-parse HEAD
export PATH=/usr/local/cuda/bin:$PATH
cmake -B build -DGGML_CUDA=ON -DCMAKE_CUDA_ARCHITECTURES=120 -DLLAMA_CURL=ON -DCMAKE_BUILD_TYPE=Release >/dev/null && cmake --build build -j 32 --target llama-server llama-cli >/dev/null && echo "llamacpp-built $(date -u +%FT%TZ) $(git rev-parse --short HEAD)" >> /opt/bench/status
wait; ls -la $N/gguf $N/gguf/*/ 2>/dev/null; echo "gguf-setup-done $(date -u +%FT%TZ)" >> /opt/bench/status
