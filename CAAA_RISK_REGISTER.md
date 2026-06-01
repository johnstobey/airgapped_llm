# CAAA Risk Register

**Version:** 1.0  
**Date:** 2024-05-23  
**Status:** Active  
**Owner:** Project Lead (johnstobey)  
**Review Cadence:** Weekly until M0, Bi-weekly thereafter.

## 1. Critical Risks (Blockers for M0-M2)

| ID | Risk Description | Impact | Probability | Mitigation Strategy | Owner | Review Date | Status |
|----|-------------------|--------|-------------|---------------------|-------|-------------|--------|
| **R01** | **libcosmic Instability**: Beta status may cause UI crashes or missing accessibility hooks. | High | Medium | **Fallback Plan**: Maintain parallel GTK3 branch. Prototype Orca integration by M1. If libcosmic fails WCAG tests, switch to GTK3. | Core Team | M1 Gate | Open |
| **R02** | **Embedded Engine Overhead**: Prolog/Lisp engines exceed memory/CPU budget on target hardware. | High | Medium | **Sandbox Benchmark**: Isolate engines in cgroups during M2. Measure RSS/CPU. If >200MB, switch to external daemon model or optimize queries. | AI Team | M2 Gate | Open |
| **R03** | **State Corruption**: Unclean shutdown corrupts SQLite vault or audit log, violating Invariant B. | Critical | Low | **WAL + Checksums**: Implement Write-Ahead Logging (Spec 11). Add `caaa-recover` CLI tool. Test `kill -9` scenarios in T05. | Core Team | M2 Gate | Open |
| **R04** | **Constitution Bypass**: LLM ignores constitutional rules via prompt injection or fingerprinting. | Critical | Medium | **Dual-Model Verification**: Small verifier model checks output against formal grammar (Spec 03) before display. Hard-block non-compliant outputs. | AI Team | M2 Gate | Open |

## 2. High-Priority Risks (Blockers for M5-M8)

| ID | Risk Description | Impact | Probability | Mitigation Strategy | Owner | Review Date | Status |
|----|-------------------|--------|-------------|---------------------|-------|-------------|--------|
| **R05** | **Accessibility Non-Compliance**: Orca screen reader fails to announce dynamic content within 200ms. | High | Medium | **Early Testing**: Integrate Orca testing at M5 (not M8). Use `at-spi2-inspector` to verify ARIA roles. | UX Team | M5 Gate | Open |
| **R06** | **Config Rigidity**: Hardcoded paths (`/run/user/1000`) break multi-user or custom vault setups. | Medium | High | **Dynamic Resolution**: Use `$XDG_RUNTIME_DIR` and `$OBSIDIAN_VAULT` env vars. Add config migration script for updates. | Core Team | M3 Gate | Open |
| **R07** | **Audit Log Growth**: Unbounded log growth fills disk, causing system crash. | Medium | High | **Rotation Policy**: Implement size-based rotation (max 100MB) with gzip compression. Retain last 10 files. | Core Team | M4 Gate | Open |
| **R08** | **Ollama Lifecycle**: Ollama crash leaves `caaa-core` hanging without recovery. | Medium | Medium | **Health Checks**: Core polls Ollama every 5s. Auto-restart Ollama subprocess. Queue requests during downtime. | AI Team | M3 Gate | Open |

## 3. Operational Risks (Post-M8)

| ID | Risk Description | Impact | Probability | Mitigation Strategy | Owner | Review Date | Status |
|----|-------------------|--------|-------------|---------------------|-------|-------------|--------|
| **R09** | **GPG Key Rotation**: Air-gapped system cannot receive new signing keys for bundle updates. | High | Low | **Offline Ceremony**: Define USB-based key rotation procedure. Include 3 backup keys in initial bundle. | DevOps | M7 Gate | Open |
| **R10** | **Hardware Incompatibility**: Target System76 box lacks KVM virtualization support. | Medium | Low | **Namespace Fallback**: Detect KVM failure at startup. Fallback to Linux namespaces/cgroups for isolation (reduced security guarantee). | Core Team | M0 Gate | Open |

## 4. Mitigation Verification Checklist

- [ ] **M0**: KVM availability check implemented.
- [ ] **M1**: libcosmic vs GTK3 decision made based on Orca prototype.
- [ ] **M2**: Constitution grammar validator passing 100% of test cases.
- [ ] **M2**: Embedded engine memory < 200MB under load.
- [ ] **M3**: Config paths fully dynamic; migration script tested.
- [ ] **M4**: Audit log rotation verified with 1GB+ dummy data.
- [ ] **M5**: Orca screen reader announces all UI elements < 200ms.
- [ ] **M7**: GPG key rotation ceremony documented and tested on VM.

---
*This document is living. Update status column weekly.*
