#!/bin/bash
# laguna-bench — on-box setup for the F2-4 run (Anand 2026-10-17: "use laguna q4 and not q5"; "is gguf the only option?").
# Two 4-bit serving candidates, benchmarked before the run (bin/serve_bench.sh), best one wins:
#   A) vLLM 0.25.1 + poolside/Laguna-S-2.1-NVFP4 (+ DFlash-NVFP4 drafter) — native FP4 on sm_120, continuous batching
#   B) Poolside llama.cpp fork (branch laguna) + bartowski Q4_K_M GGUF (71.8 GB) + poolside DFlash BF16 GGUF drafter
# Run as ubuntu in tmux 'setup'. Progress markers go to /opt/bench/status.
set -x; exec > >(tee -a /opt/bench/setup.log) 2>&1
sudo mkdir -p /opt/bench && sudo chown ubuntu:ubuntu /opt/bench
N=/opt/dlami/nvme; mountpoint -q $N || N=/opt/bench/models; sudo mkdir -p $N && sudo chown ubuntu:ubuntu $N; mkdir -p $N/gguf $N/src $N/hf
echo "models-dir $N" >> /opt/bench/status
export HF_HOME=$N/hf HF_XET_HIGH_PERFORMANCE=1
sudo apt-get install -y -q python3.12-dev cmake build-essential libcurl4-openssl-dev >/dev/null
curl -LsSf https://astral.sh/uv/install.sh | sh; export PATH=$HOME/.local/bin:$PATH
uv venv /opt/bench/vllm -p 3.12
uv pip install -p /opt/bench/vllm "vllm==0.25.1" "huggingface_hub[hf_xet]" ninja --torch-backend=cu130
# FlashInfer nightly trio from the Poolside NVFP4 card: without flashinfer-python the NVFP4 path is not native
uv pip install -p /opt/bench/vllm "flashinfer-python==0.6.15.dev20260712" "flashinfer-cubin==0.6.15.dev20260712" \
  "flashinfer-jit-cache==0.6.15.dev20260712" --extra-index-url https://flashinfer.ai/whl/nightly/ \
  --extra-index-url https://flashinfer.ai/whl/nightly/cu130/ --index-strategy unsafe-best-match
/opt/bench/vllm/bin/python -c "import vllm,torch;print('vllm',vllm.__version__,'torch',torch.__version__)" && echo "vllm-installed $(date -u +%FT%TZ)" >> /opt/bench/status
H=/opt/bench/vllm/bin/hf
( $H download poolside/Laguna-S-2.1-NVFP4 >/dev/null && $H download poolside/Laguna-S-2.1-DFlash-NVFP4 >/dev/null \
    && echo "nvfp4-downloaded $(date -u +%FT%TZ)" >> /opt/bench/status ) &
( $H download bartowski/Laguna-S-2.1-GGUF --include "Laguna-S-2.1-Q4_K_M*" --local-dir $N/gguf >/dev/null \
    && $H download poolside/Laguna-S-2.1-GGUF laguna-s-2.1-DFlash-BF16.gguf --local-dir $N/gguf >/dev/null \
    && echo "q4-downloaded $(date -u +%FT%TZ)" >> /opt/bench/status ) &
cd $N/src && git clone -q --depth 1 --branch laguna https://github.com/poolsideai/llama.cpp llama.cpp-poolside && cd llama.cpp-poolside
export PATH=/usr/local/cuda/bin:$PATH
cmake -B build -DGGML_CUDA=ON -DCMAKE_CUDA_ARCHITECTURES=120 -DCMAKE_BUILD_TYPE=Release >/dev/null \
  && cmake --build build -j "$(nproc)" --target llama-server >/dev/null \
  && echo "fork-built $(date -u +%FT%TZ) $(git rev-parse --short HEAD)" >> /opt/bench/status
wait; du -sh $N/hf $N/gguf; echo "setup-done $(date -u +%FT%TZ)" >> /opt/bench/status
