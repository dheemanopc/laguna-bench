#!/bin/bash
# laguna-bench — g7e.24xlarge (4x RTX PRO 6000) full-precision throughput test, 2026-10-17 (Anand: "if we use a high end gpu at
# full capacity, ~30 concurrent users ... will it become profitable"). Laguna-S-2.1 BF16 on vLLM 0.25.1, TP=4 (model card).
set -x; exec > >(tee -a /opt/bench/setup.log) 2>&1
sudo mkdir -p /opt/bench && sudo chown ubuntu:ubuntu /opt/bench
N=/opt/dlami/nvme; mountpoint -q $N || N=/opt/bench/models; sudo mkdir -p $N && sudo chown ubuntu:ubuntu $N; mkdir -p $N/hf
ln -sfn $N/hf /opt/bench/hf; echo "models-dir $N" >> /opt/bench/status
export HF_HOME=$N/hf HF_XET_HIGH_PERFORMANCE=1
sudo apt-get install -y -q python3.12-dev build-essential >/dev/null
curl -LsSf https://astral.sh/uv/install.sh | sh; export PATH=$HOME/.local/bin:$PATH
uv venv /opt/bench/vllm -p 3.12
uv pip install -p /opt/bench/vllm "vllm==0.25.1" "huggingface_hub[hf_xet]" ninja --torch-backend=cu130
/opt/bench/vllm/bin/python -c "import vllm,torch;print('vllm',vllm.__version__,'torch',torch.__version__,torch.cuda.device_count())" \
  && echo "vllm-installed $(date -u +%FT%TZ)" >> /opt/bench/status
/opt/bench/vllm/bin/hf download poolside/Laguna-S-2.1 >/dev/null && echo "bf16-downloaded $(date -u +%FT%TZ)" >> /opt/bench/status
du -sh $N/hf; echo "setup-done $(date -u +%FT%TZ)" >> /opt/bench/status
