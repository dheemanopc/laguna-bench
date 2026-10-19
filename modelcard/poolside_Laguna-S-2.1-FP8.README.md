---
library_name: vllm
inference: false
extra_gated_description: >-
  To learn more about how we process your personal data, please read our <a
  href="https://poolside.ai/legal/privacy">Privacy Policy</a>.
tags:
- laguna-s-2.1
license: openmdw-1.1
pipeline_tag: text-generation
base_model:
- poolside/Laguna-S-2.1
---

<p align="center">
  <img alt="poolside-banner" src="https://poolside.ai/assets/laguna/laguna-s-2-1-banner.svg" width="800px">
</p>

<p align="center">
  <a href="https://openrouter.ai/poolside/laguna-s-2.1"><strong>Use on OpenRouter</strong></a> ·
  <a href="https://vercel.com/ai-gateway/models/laguna-s-2.1"><strong>Use on Vercel AI Gateway</strong></a> ·
  <a href="https://poolside.ai/blog/introducing-laguna-s-2-1"><strong>Release blog post</strong></a>
</p>

<br>

# Laguna S 2.1-FP8
Laguna S 2.1-FP8 is a 117.6B total parameter Mixture-of-Experts model with 8.5B activated parameters per token designed for agentic coding and long-horizon work on a local machine. It uses Sliding Window Attention with per-head gating in 36 out of 48 layers for fast inference and low KV cache requirements.

> **Updated release (August 2026).** This is a new checkpoint that supersedes the earlier version of this repository. The weights have changed, not only the config, so if you downloaded a previous copy please re-download to pick up the current checkpoint.


## Highlights
- **Mixed SWA and global attention layout**: Laguna S 2.1 uses softplus gating with per-layer rotary scales, enabling mixed SWA (Sliding Window Attention) and global attention layers in a 3:1 ratio (across 48 total layers)
- **KV cache in FP8**: KV cache quantized to FP8, reducing memory per token
- **Native reasoning support**: Interleaved thinking between tool calls with support for enabling and disabling thinking per-request
- **Local-ready**: At 117.6B total parameters and 8.5B activated, the FP8 weights are roughly 121 GB. Available on [Ollama](https://ollama.com/laguna-s-2.1) and [llama.cpp](https://github.com/ggml-org/llama.cpp/pull/25165) (BF16 and Q4\_K\_M only)
- **OpenMDW-1.1 license**: Use and modify the model and associated materials freely for commercial and non-commercial purposes ([learn more about OpenMDW](https://openmdw.ai/))

---

## Model overview

- Training: pre-training, post-training and reinforcement learning stages
- Number of parameters: 117.6B total with 8.5B activated per token
- Optimizer: Muon
- Layers: 48 layers (12 layers with global attention, 36 layers with sliding window attention)
- Experts: 256 experts with 1 shared expert
- Sliding Window: 512 tokens
- Modality: text-to-text
- Context window: 1,048,576 tokens
- Reasoning support: interleaved thinking with preserved thinking


## Benchmark results

<p align="center">
  <img alt="benchmarks" src="https://poolside.ai/assets/laguna/laguna-s-2-1-chart.svg" width="800px">
</p>

| Model | Size | Terminal-Bench 2.1 | SWE-bench Multilingual | SWE-Bench Pro (Public Dataset) | DeepSWE | SWE Atlas (Codebase QnA) | Toolathlon Verified |
|---|---|---|---|---|---|---|---|
| **Laguna S 2.1** | 118B-A8B | **70.2%** | **78.5%** | **59.4%** | **40.4%** | **46.2%** | **49.7%** |
| Tencent Hy3 | 295B-A21B | 71.7% | 75.8% | 57.9% | - | - | - |
| Inkling | 975B-A41B | 63.8% | - | 54.3% | - | - | 45.5%* |
| Nemotron 3 Ultra | 550B-A55B | 56.4% | 67.7% | - | - | - | 34.3%* |
| DeepSeek-V4-Pro Max | 1.6T-A49B | 64.0%* | 76.2% | 55.4% | 9.0%* | 27.2%* | 55.9%* |
| Kimi K3 | 2800B-A50B | 88.3% | - | - | 69% | - | - |
| Qwen 3.7 Max | - | 74.5%* | 78.3% | 60.6% | - | - | - |
| Muse Spark 1.1 | - | 80% | - | 61.5% | 53.3% | 42.2%* | 75.6% |
| Claude Fable 5 | - | 88% | - | 80.3% | 70% | - | - |

Benchmarks as of 21 July 2026. Laguna S 2.1 in **bold**; a dash (-) marks a benchmark a model was not evaluated on. Scores marked * are as reported by third parties: Terminal-Bench 2.1 and DeepSWE via Artificial Analysis, SWE Atlas via Scale AI's official leaderboard, and Toolathlon Verified via its official leaderboard. Full evaluation trajectories: [trajectories.poolside.ai](https://trajectories.poolside.ai).

## Usage

### Context length

This checkpoint ships configured for a 1,048,576-token (1M) context window. The weights are native 1M checkpoints: training included a long-context extension stage up to 1,048,576 tokens, and quantization was calibrated at the 1M configuration.

If you prefer to cap the context at 262,144 tokens (256K), edit `config.json`:

```json
"rope_parameters": {
  "full_attention": {
    "factor": 32.0,
    "attention_factor": 1.3465735902799727
  }
},
"max_position_embeddings": 262144
```

At long context you may experience some quality degradation.

### Sampling

The sampling defaults in the checkpoint's `generation_config.json` are authoritative (`top_k 20` is eval-certified truncation). Serve with those defaults rather than setting a separate temperature or top_p.


### Local deployment

Laguna S 2.1-FP8 is supported in vLLM, SGLang and Transformers, and TRT-LLM thanks to the support of the team at NVIDIA. Use Laguna S 2.1 with Ollama (with MLX support) or Llama.cpp (BF16 and Q4\_K\_M only) for the best results on your local machine.

#### vLLM

> Serving requires vLLM 0.25.0 or later. See the main [Laguna S 2.1 model card](https://huggingface.co/poolside/Laguna-S-2.1) for the full recipe.

The full vLLM recipe is on the main [Laguna S 2.1 model card](https://huggingface.co/poolside/Laguna-S-2.1) and on the [vLLM recipes page](https://recipes.vllm.ai/poolside/Laguna-S-2.1). Quantization is detected automatically from `quantization_config` in this checkpoint, so the same command works with `poolside/Laguna-S-2.1-FP8` substituted for the model ID. Set `VLLM_BLOCKSCALE_FP8_GEMM_FLASHINFER=0` when serving with vLLM.
> [!NOTE]
> **Optional: speculative decoding with DFlash.** Pair with the quantization-matched draft model [poolside/Laguna-S-2.1-DFlash-FP8](https://huggingface.co/poolside/Laguna-S-2.1-DFlash-FP8) by adding `--speculative-config '{"model":"poolside/Laguna-S-2.1-DFlash-FP8","num_speculative_tokens":7,"method":"dflash"}'` to the serve command.

#### SGLang

Laguna S 2.1 is supported in SGLang via [sgl-project/sglang#24204](https://github.com/sgl-project/sglang/pull/24204). Quantization is detected automatically from `quantization_config`, so no extra flags are required. See the [SGLang cookbook entry](https://docs.sglang.io/cookbook/autoregressive/Poolside/Laguna-S-2.1) and the main [Laguna S 2.1 model card](https://huggingface.co/poolside/Laguna-S-2.1) for a serving recipe.

#### Transformers

The full Transformers recipe is on the main [Laguna S 2.1 model card](https://huggingface.co/poolside/Laguna-S-2.1). Substitute `poolside/Laguna-S-2.1-FP8` for the model ID; quantization is detected automatically from `quantization_config`.

#### TRT-LLM

Laguna S 2.1 support ships in TensorRT-LLM `>=1.3.0rc16`; see the install recipe on the main [Laguna S 2.1 model card](https://huggingface.co/poolside/Laguna-S-2.1). Substitute `poolside/Laguna-S-2.1-FP8` for the model ID; quantization is detected automatically from `quantization_config`, no extra flags required.

```python
from tensorrt_llm import LLM

llm = LLM(model="poolside/Laguna-S-2.1-FP8", trust_remote_code=True)
```

#### llama.cpp

Serve the GGUF builds with Poolside's llama.cpp fork, branch [`laguna`](https://github.com/poolsideai/llama.cpp/tree/laguna). See the main [Laguna S 2.1 model card](https://huggingface.co/poolside/Laguna-S-2.1) for the build recipe. llama.cpp serves the BF16, Q8\_0, and Q4\_K\_M GGUF builds, not the FP8 safetensors.

#### Ollama

Available on the [Ollama library](https://ollama.com/laguna-s-2.1).

## Controlling reasoning

Laguna S 2.1-FP8 uses the same reasoning controls (interleaved thinking, preserved reasoning, and the `enable_thinking` flag) as the base model. See the [Controlling reasoning](https://huggingface.co/poolside/Laguna-S-2.1#controlling-reasoning) section of the main Laguna S 2.1 model card.

## License

This model is licensed under the [OpenMDW-1.1 License](https://huggingface.co/poolside/Laguna-S-2.1-FP8/blob/main/LICENSE.md).

## Intended and Responsible Use 

Laguna S 2.1-FP8 is designed for software engineering and agentic coding use cases, and you are responsible for confirming that it is appropriate for your intended application. Laguna S 2.1-FP8 is subject to the [OpenMDW-1.1 License](https://huggingface.co/poolside/Laguna-S-2.1-FP8/blob/main/LICENSE.md), and should be used consistently with Poolside's [Acceptable Use Policy](https://poolside.ai/legal/acceptable-use-policy). We advise against circumventing Laguna S 2.1-FP8 safety guardrails without implementing substantially equivalent mitigations appropriate for your use case.

Please report security vulnerabilities or safety concerns to [<email>](mailto:<email>).


