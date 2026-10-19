#!/bin/bash
# laguna-bench — on-box setup for the single-GPU spot instance (run as ubuntu, in tmux 'setup').
# Rebuilds what the old 12xl disk had: vLLM 0.25.1 venv, Devstral pixtral compat patch, serve.sh + vllm/vllm2 units,
# Devstral Small 2 + Nemotron Puzzle 75B NVFP4 weights. One GPU → the two units are run one at a time (GPUS=0 for both).
set -x; exec > >(tee -a /opt/bench/setup.log) 2>&1
sudo mkdir -p /opt/bench && sudo chown ubuntu:ubuntu /opt/bench
curl -LsSf https://astral.sh/uv/install.sh | sh; export PATH=$HOME/.local/bin:$PATH
uv venv /opt/bench/vllm -p 3.12
uv pip install -p /opt/bench/vllm "vllm==0.25.1" "huggingface_hub[hf_xet]" ninja --torch-backend=auto
/opt/bench/vllm/bin/python -c "import vllm,torch;print('vllm',vllm.__version__,'torch',torch.__version__,torch.cuda.device_count())" && echo "vllm-installed $(date -u +%FT%TZ)" >> /opt/bench/status
export HF_HOME=/opt/bench/hf HF_XET_HIGH_PERFORMANCE=1
( /opt/bench/vllm/bin/hf download mistralai/Devstral-Small-2-24B-Instruct-2512 --revision 55c5b41e98c2dbd21b0c8afffc540dcfc9eb5128 && echo "devstral-downloaded $(date -u +%FT%TZ)" >> /opt/bench/status ) &
( /opt/bench/vllm/bin/hf download nvidia/NVIDIA-Nemotron-Labs-3-Puzzle-75B-A9B-NVFP4 && echo "puzzle-downloaded $(date -u +%FT%TZ)" >> /opt/bench/status ) &
# pixtral compat patch (transformers 5.19 vs vLLM 0.25.1) — same as the 12xl
P=/opt/bench/vllm/lib/python3.12/site-packages/vllm/model_executor/models/pixtral.py; cp -n $P $P.orig
/opt/bench/vllm/bin/python - "$P" <<'EOF'
import sys
p=sys.argv[1]; s=open(p).read()
old="""from transformers.models.pixtral.modeling_pixtral import (
    PixtralRotaryEmbedding,
    apply_rotary_pos_emb,
    position_ids_in_meshgrid,
)"""
new="""# laguna-bench compat patch: transformers 5.19 renamed/removed these (vLLM 0.25.1 still imports old names)
from transformers.models.pixtral.modeling_pixtral import apply_rotary_pos_emb
try:
    from transformers.models.pixtral.modeling_pixtral import PixtralRotaryEmbedding
except ImportError:
    from transformers.models.pixtral.modeling_pixtral import PixtralVisionRotaryEmbedding as PixtralRotaryEmbedding
try:
    from transformers.models.pixtral.modeling_pixtral import position_ids_in_meshgrid
except ImportError:
    def position_ids_in_meshgrid(patch_embeds_list, max_width):
        positions = []
        for patch in patch_embeds_list:
            height, width = patch.shape[-2:]
            mesh = torch.meshgrid(torch.arange(height), torch.arange(width), indexing="ij")
            h_grid, v_grid = torch.stack(mesh, dim=-1).reshape(-1, 2).chunk(2, -1)
            positions.append(h_grid * max_width + v_grid)
        return torch.cat(positions)[:, 0]"""
if new.splitlines()[0] in s: print("patch already applied")
else: assert old in s, "pixtral import block not found"; open(p,"w").write(s.replace(old,new)); print("pixtral patched")
EOF
echo "patched $(date -u +%FT%TZ)" >> /opt/bench/status
wait; echo "setup-done $(date -u +%FT%TZ)" >> /opt/bench/status
