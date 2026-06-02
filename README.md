# COSMIC Accessible Agent Applet (CAAA)

[![M0 Gate](https://img.shields.io/badge/status-M0_Approved-green)](https://github.com/johnstobey/airgapped_llm)
[![Air-Gap Ready](https://img.shields.io/badge/security-Air--Gap-blue)](docs/CAAA_DEPLOYMENT_OPERATIONS.md)
[![Accessibility](https://img.shields.io/badge/WCAG-2.1_AA-orange)](docs/CAAA_IMPLEMENTATION_PROPOSAL.md)

A production-grade, air-gapped accessibility agent built with Rust, libcosmic, and local LLMs. Designed for System76/Pop!_OS environments with strict security isolation and WCAG 2.1 AA compliance.

## 🚀 Quick Start

```bash
git clone https://github.com/johnstobey/airgapped_llm.git
cd airgapped_llm
./scripts/m0_init.sh
```

## 📚 Documentation Index

| Document | Purpose | Status |
|----------|---------|--------|
| **[Implementation Proposal](docs/CAAA_IMPLEMENTATION_PROPOSAL.md)** | Engineering blueprint, roadmap, gRPC specs | ✅ M0 Approved |
| **[Risk Register](docs/CAAA_RISK_REGISTER.md)** | 10 risks with mitigation strategies | ✅ Active |
| **[Constitution Spec](docs/CAAA_CONSTITUTION_SPEC.md)** | Rule syntax, dual-model verification | ✅ M0 Baseline |
| **[State Recovery](docs/CAAA_STATE_RECOVERY.md)** | WAL architecture, chaos tests | ✅ M0 Baseline |
| **[Deployment Operations](docs/CAAA_DEPLOYMENT_OPERATIONS.md)** | GPG ceremony, model lifecycle, runbooks | ✅ Production Ready |
| **[Model Manifest](docs/CAAA_MODEL_MANIFEST.md)** | SHA-256 hashes, validation procedures | ⏳ Pending |

## 🏗️ Architecture

**Key Invariants:**
- **Invariant A**: STATUS_BLOCK from ground-truth state (never LLM)
- **Invariant B**: All vault writes via isolated audit thread
- **Invariant C**: mTLS required; self-signed PKI at M0

**Reasoning Engine**: Option B (Subprocess) for fault isolation and sandboxing.

## 📋 Development Workflow

- **main**: Protected branch; PRs required
- **Feedback**: Inline comments on PRs for audit trail
- **Testing**: `cargo test --workspace`, air-gap verification, Orca suite

## 🔧 Deployment

- **OS**: Pop!_OS 24.04 LTS
- **RAM**: 16 GB min (32 GB recommended)
- **Storage**: 50 GB per user

See [Deployment Operations](docs/CAAA_DEPLOYMENT_OPERATIONS.md) for full procedures.

---

**Version**: 0.1.0 (M0 Scaffold) | **License**: MIT
