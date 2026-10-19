#!/bin/bash
# laguna-bench — EC2 user-data for the GPU instance (g7e.12xlarge, 2x RTX PRO 6000 96GB).
# Role per rev 9: this box ONLY serves the model (vLLM), runs the capacity curve and exposes /metrics.
# No Memsys code, no Claude Code, no credentials ever land here.
# Everything is logged to /var/log/bench-setup.log; progress markers live in /opt/bench/status.
set -x
exec > >(tee -a /var/log/bench-setup.log) 2>&1

# 1) Dead-man switch: hard power-off (and terminate, via InstanceInitiatedShutdownBehavior) after 13h. Never extended.
shutdown -h +__DEADMAN_MIN__ "laguna-bench dead-man switch"

mkdir -p /opt/bench && chown ubuntu:ubuntu /opt/bench
echo "userdata-start $(date -u +%FT%TZ)" >> /opt/bench/status

# 2) Toolchain: uv + Python venv with vLLM (model card: vLLM >= 0.25.0; 0.25.1 is the version Poolside documents)
sudo -u ubuntu bash -lc '
set -x
curl -LsSf https://astral.sh/uv/install.sh | sh
export PATH=$HOME/.local/bin:$PATH
uv venv /opt/bench/vllm -p 3.12
uv pip install -p /opt/bench/vllm "vllm==0.25.1" "huggingface_hub[hf_xet]" --torch-backend=auto
/opt/bench/vllm/bin/python -c "import vllm,torch;print(\"vllm\",vllm.__version__,\"torch\",torch.__version__,torch.cuda.device_count())"
' && echo "vllm-installed $(date -u +%FT%TZ)" >> /opt/bench/status

# 3) Weights: FP8 checkpoint (~131GB) straight from Hugging Face (never via the laptop), then the matched DFlash draft for tuning
sudo -u ubuntu bash -lc '
export HF_HOME=/opt/bench/hf HF_XET_HIGH_PERFORMANCE=1
for i in 1 2 3; do /opt/bench/vllm/bin/hf download __MODEL__ && break; sleep 30; done
' && echo "weights-downloaded $(date -u +%FT%TZ)" >> /opt/bench/status

# 4) vLLM service: localhost only; flags from the model card plus rev-6 serve flags
cat > /etc/systemd/system/vllm.service <<'UNIT'
[Unit]
Description=laguna-bench vLLM server
After=network-online.target
[Service]
User=ubuntu
Environment=HF_HOME=/opt/bench/hf
Environment=HF_HUB_OFFLINE=1
Environment=VLLM_BLOCKSCALE_FP8_GEMM_FLASHINFER=0
EnvironmentFile=-/opt/bench/vllm.env
ExecStart=/bin/bash -c 'exec /opt/bench/vllm/bin/vllm serve __MODEL__ --served-model-name laguna-s-2.1 --host 127.0.0.1 --port 8000 --tensor-parallel-size __TP__ --kv-cache-dtype fp8 --enable-prefix-caching --max-model-len 327680 --gpu-memory-utilization 0.92 --enable-auto-tool-choice --tool-call-parser poolside_v1 --reasoning-parser poolside_v1 --default-chat-template-kwargs "{\"enable_thinking\": true}" $EXTRA_ARGS'
StandardOutput=append:/opt/bench/vllm.log
StandardError=append:/opt/bench/vllm.log
Restart=on-failure
RestartSec=20
[Install]
WantedBy=multi-user.target
UNIT
touch /opt/bench/vllm.env && chown ubuntu:ubuntu /opt/bench/vllm.env
systemctl daemon-reload && systemctl enable --now vllm.service
echo "vllm-service-started $(date -u +%FT%TZ)" >> /opt/bench/status

# 5) Optional DFlash draft for Phase 0f tuning (downloaded after the server is already starting)
sudo -u ubuntu bash -lc 'HF_HOME=/opt/bench/hf HF_XET_HIGH_PERFORMANCE=1 /opt/bench/vllm/bin/hf download __DRAFT__' \
  && echo "draft-downloaded $(date -u +%FT%TZ)" >> /opt/bench/status
echo "userdata-done $(date -u +%FT%TZ)" >> /opt/bench/status
