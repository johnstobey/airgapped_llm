# CAAA Model Manifest v1.0

This manifest tracks validated GGUF models for the air-gapped CAAA environment. All models must pass SHA-256 verification and safety testing before deployment.

## Validated Models

| Model Name | Quantization | Version | SHA-256 Hash | Source | Size | Ollama Tag | Status |
|-----------|--------------|---------|--------------|--------|------|------------|--------|
| llama-3-8b | q4_k_m | v1.0.0 | `PENDING_VALIDATION` | HuggingFace | 4.3 GB | llama3:8b | ⏳ Pending |
| mistral-7b | q4_k_m | v1.0.0 | `PENDING_VALIDATION` | HuggingFace | 3.8 GB | mistral:7b | ⏳ Pending |
| tinyllama | q4_k_m | v1.0.0 | `PENDING_VALIDATION` | HuggingFace | 0.8 GB | tinyllama:1.1b | ⏳ Pending |

## Validation Procedure

1. Download model to air-gapped reference machine via approved transfer method
2. Compute SHA-256: `sha256sum model.gguf`
3. Compare against manifest (update hash upon first validation)
4. Run benchmark suite (100 queries across categories: reasoning, creative, factual)
5. Run adversarial prompt suite (constitution violation attempts)
6. Sign off as "validated" in audit log with timestamp and validator ID

## Model Update Policy

- **Major Updates** (architecture change): Quarterly, requires full re-validation
- **Minor Updates** (quantization improvement): Monthly, requires benchmark comparison
- **Emergency Patches** (security vulnerability): As needed, expedited review

## Rollback Procedure

If a model exhibits unexpected behavior:
1. Flag model as "REVOKED" in this manifest
2. Revert to previous version in Ollama registry
3. Document failure mode in incident log
4. Notify all deployed sites via secure channel

---
*Last Updated: M0 Initialization*  
*Maintained by: Release Manager*
