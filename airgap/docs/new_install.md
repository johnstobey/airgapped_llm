# CORVUS System76 Machine — Install List for Rich

**From:** John Schumann Tobey
**Date:** 2026-02-13
**Machine:** System76 with RTX 5070 Ti (16GB VRAM), Pop!_OS

---

## Why This Order Matters

Everything below is sequenced so that each step depends on the one before it. If step 1 isn't right, nothing after it works. The GPU is installed but the software stack doesn't know it exists yet — that's why CUDA comes first.

---

## 1. CUDA Toolkit — Version 12.8 or newer

**Why:** The RTX 5070 Ti uses NVIDIA's new Blackwell architecture (compute capability sm_120). Older CUDA versions don't recognize this chip. Without CUDA 12.8+, every program that tries to use the GPU will either crash or silently fall back to CPU — which is what's happening now. Ollama is currently running on CPU only because the CUDA toolkit isn't installed.

**How to verify it worked:** Run `nvcc --version` in terminal. Output should show 12.8 or higher.

**Size:** ~3-4 GB download.

---

## 2. NVIDIA Driver — Version 570.x or newer (open kernel module)

**Why:** The driver is the layer between the operating system and the GPU hardware. Pop!_OS may already have a driver installed, but Blackwell GPUs require the 570 series with the open kernel module variant specifically. If the driver is older or uses the proprietary module, CUDA won't communicate with the card.

**How to verify it worked:** Run `nvidia-smi` in terminal. Should show the RTX 5070 Ti with driver version 570.x+ and CUDA version 12.8+.

**Note:** If Pop!_OS already installed a 570+ driver, this step may already be done. Check first.

---

## 3. Update Ollama to Latest Version

**Why:** The version of Ollama currently on the machine was installed before the CUDA toolkit. It needs to be updated (or reinstalled) AFTER CUDA is in place so it detects and links against the GPU libraries. The current state — `total vram: 0 B` and `inference compute: cpu` — means Ollama doesn't see the GPU at all.

**How to verify it worked:** After updating, run `ollama ps` while a model is loaded. The output should show VRAM usage (not 0 B) and the GPU should appear as the compute device.

---

## 4. Pull Model: Dolphin 2.6 Mistral 7B

**Why:** This is the uncensored base model. Standard models have safety guardrails that refuse to engage with astrological computation — they treat it as pseudoscience and hedge every answer. Dolphin removes those guardrails so the model follows instructions without editorial commentary. 7 billion parameters fits easily in 16GB VRAM with room to spare (~4-5 GB). This is the model we will fine-tune for domain-specific work.

**Command:** `ollama pull dolphin-mistral`

**Size:** ~4 GB

---

## 5. Pull Model: Codestral

**Why:** Primary coding model. Codestral is Mistral AI's dedicated code generation model, built by Mistral AI (Paris, France). We are building a 10,000+ line Rust application and need a model that is strong at code generation. Codestral handles Rust well and fits comfortably in 16GB VRAM.

**Command:** `ollama pull codestral`

**Size:** ~4-5 GB (depends on quantization)

---

## 6. Pull Model: Phi-3 Medium 14B

**Why:** Our largest and most capable general-purpose model. 14 billion parameters, developed by Microsoft Research (Redmond, WA). At 4-bit quantization it uses ~8-9 GB of VRAM, fitting within the 16GB budget. We use this for tasks that need more reasoning horsepower than the 7B Dolphin — architectural decisions, complex code review, and cross-referencing outputs from the other models. Two independent models producing the same answer is how we catch errors.

**Command:** `ollama pull phi3:14b`

**Size:** ~8-9 GB

---

## 7. Install Whisper.cpp

**Why:** Voice-to-text transcription that runs entirely on the local machine. John needs to dictate instructions and have them converted to text without sending audio to any cloud service. Whisper.cpp is the C++ port of OpenAI's Whisper model — it runs locally, uses the GPU for acceleration, and produces accurate transcription. No internet required after install.

**How to verify it worked:** Record a short audio clip and run it through whisper.cpp. Should produce accurate text output.

---

## 8. Install Obsidian

**Why:** Note-taking application that stores everything as local markdown files — no cloud sync, no account required. John will use this as the primary interface for reading and organizing project documents. The CORVUS design document uses `[[wikilinks]]` throughout which are native to Obsidian's format. This is not a nice-to-have — it's the front end of the system.

**How to verify it worked:** Open Obsidian, point it at a folder, confirm it renders markdown with wikilinks.

---

## Post-Install Verification Checklist

After all 8 steps, run these commands and confirm the expected output:

```
1. nvcc --version
   → Should show CUDA 12.8+

2. nvidia-smi
   → Should show RTX 5070 Ti, driver 570.x+, CUDA 12.8+

3. ollama run dolphin-mistral "What is 2+2?"
   → Should respond in <2 seconds (GPU) not 10+ seconds (CPU)

4. ollama run codestral "Write a Rust function that adds two numbers"
   → Should respond with valid Rust code in <5 seconds

5. ollama run phi3:14b "Explain the Pythagorean theorem in two sentences"
   → Should respond coherently in <5 seconds

6. ollama ps (while a model is running)
   → Should show VRAM usage > 0 B, compute = gpu
```

If any of these fail, the most likely cause is CUDA toolkit version (step 1) or driver version (step 2). Everything downstream depends on the GPU being properly recognized.

---

## Disk Space Budget

| Item | Size |
|------|------|
| CUDA Toolkit | ~3-4 GB |
| Dolphin 2.6 Mistral 7B | ~4 GB |
| Codestral | ~4-5 GB |
| Phi-3 Medium 14B | ~8-9 GB |
| Whisper.cpp + model | ~1-2 GB |
| Obsidian | ~200 MB |
| **Total** | **~21-25 GB** |

This is storage (SSD), not VRAM. Only one model loads into GPU memory at a time.