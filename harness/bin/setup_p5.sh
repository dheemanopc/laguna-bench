#!/bin/bash
# laguna-bench — on-box setup for the H100 (p5.4xlarge) speed test, 2026-10-17 (Anand: "look at p class gpus .. quick 2 hours
# test with same laguna setup"). Same serving as F2-4: Poolside llama.cpp fork 06f8ceb + bartowski Q4_K_M + DFlash BF16 drafter.
# Only change: CUDA arch 90 (H100). No vLLM/NVFP4. Progress markers -> /opt/bench/status.
set -x; exec > >(tee -a /opt/bench/setup.log) 2>&1
sudo mkdir -p /opt/bench && sudo chown ubuntu:ubuntu /opt/bench
N=/opt/dlami/nvme; mountpoint -q $N || N=/opt/bench/models; sudo mkdir -p $N && sudo chown ubuntu:ubuntu $N; mkdir -p $N/gguf $N/src $N/hf
echo "models-dir $N" >> /opt/bench/status
export HF_HOME=$N/hf HF_XET_HIGH_PERFORMANCE=1
sudo apt-get install -y -q cmake build-essential libcurl4-openssl-dev >/dev/null
curl -LsSf https://astral.sh/uv/install.sh | sh; export PATH=$HOME/.local/bin:$PATH
uv tool install "huggingface_hub[hf_xet]" >/dev/null; H=$HOME/.local/bin/hf
( $H download bartowski/Laguna-S-2.1-GGUF --include "Laguna-S-2.1-Q4_K_M*" --local-dir $N/gguf >/dev/null \
    && $H download poolside/Laguna-S-2.1-GGUF laguna-s-2.1-DFlash-BF16.gguf --local-dir $N/gguf >/dev/null \
    && echo "q4-downloaded $(date -u +%FT%TZ)" >> /opt/bench/status ) &
cd $N/src && git clone -q --branch laguna https://github.com/poolsideai/llama.cpp llama.cpp-poolside && cd llama.cpp-poolside && git checkout -q 06f8ceb
export PATH=/usr/local/cuda/bin:$PATH
cmake -B build -DGGML_CUDA=ON -DCMAKE_CUDA_ARCHITECTURES=90 -DCMAKE_BUILD_TYPE=Release >/dev/null \
  && cmake --build build -j "$(nproc)" --target llama-server >/dev/null \
  && echo "fork-built $(date -u +%FT%TZ) $(git rev-parse --short HEAD)" >> /opt/bench/status
wait; du -sh $N/gguf; echo "setup-done $(date -u +%FT%TZ)" >> /opt/bench/status
