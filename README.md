# CAAA - COSMIC Accessible Agent Applet

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Rust](https://img.shields.io/badge/rust-1.75+-orange.svg)](https://www.rust-lang.org)

**Air-gapped accessibility-first intelligent agent for Pop!_OS/COSMIC desktop.**

## Overview

CAAA is a secure, offline-capable intelligent agent designed for air-gapped systems requiring WCAG 2.1 AA compliance. It features:

- **mTLS-secured gRPC communication** between applet and daemon
- **Constitutional AI layer** with Prolog-based rule enforcement
- **Obsidian vault integration** as first-class knowledge substrate
- **Subprocess-sandboxed reasoning engines** (SWI-Prolog, TinyLisp)
- **Libcosmic native UI** with full Orca screen reader support
- **Zero network dependency** with strict air-gap enforcement

## Architecture

```
┌─────────────────┐     mTLS gRPC      ┌──────────────────────────────────────┐
│  caaa-applet    │◄──────────────────►│           caaa-core                  │
│  (libcosmic UI) │   Unix Domain       │  ┌────────────┐  ┌────────────────┐ │
│                 │     Socket          │  │ Reasoning  │  │ Constitutional │ │
│  - Chat UI      │                     │  │  Engines   │  │    Layer       │ │
│  - STATUS_BLOCK │                     │  │ (Prolog/   │  │  (Prolog rules)│ │
│  - Vault Nav    │                     │  │   Lisp)    │  │                │ │
└─────────────────┘                     │  └────────────┘  └────────────────┘ │
                                        │           ▲                          │
                                        │           │ IPC                      │
                                        │           ▼                          │
                                        │  ┌────────────────┐  ┌────────────┐ │
                                        │  │   Audit Thread │  │ Ollama     │ │
                                        │  │ (exclusive RW) │  │  Models    │ │
                                        │  └────────────────┘  └────────────┘ │
                                        └──────────────────────────────────────┘
```

## Workspace Structure

```
caaa/
├── Cargo.toml              # Workspace definition
├── crates/
│   ├── caaa-core/          # Main daemon (gRPC server, orchestration)
│   ├── caaa-applet/        # Libcosmic system tray applet
│   ├── caaa-proto/         # gRPC protocol definitions (.proto)
│   ├── caaa-pki/           # PKI provisioning & mTLS certificate management
│   ├── caaa-reasoning/     # Subprocess wrappers for Prolog/Lisp engines
│   ├── caaa-constitution/  # Constitutional rule engine & validation
│   ├── caaa-vault/         # Obsidian vault operations & indexing
│   ├── caaa-audit/         # Audit log with exclusive write locks
│   ├── caaa-ctl/           # CLI administration tool
│   ├── caaa-recover/       # State recovery & WAL management
│   └── caaa-sandbox/       # Seccomp/namespaces for subprocess isolation
├── scripts/
│   ├── m0_init.sh          # M0 initialization (PKI generation)
│   └── install.sh          # Production installation script (M7)
└── docs/
    ├── CAAA_IMPLEMENTATION_PROPOSAL.md
    ├── CAAA_RISK_REGISTER.md
    ├── CAAA_CONSTITUTION_SPEC.md
    ├── CAAA_STATE_RECOVERY.md
    ├── CAAA_DEPLOYMENT_OPERATIONS.md
    └── CAAA_MODEL_MANIFEST.md
```

## Quick Start (Development)

### Prerequisites

- Rust 1.75+ (`rustup install stable`)
- Protocol Buffers compiler (`apt install protobuf-compiler`)
- OpenSSL (`apt install libssl-dev pkg-config`)
- Pop!_OS 24.04+ (for libcosmic development)

### M0 Initialization

```bash
# Clone repository
git clone https://github.com/johnstobey/airgapped_llm.git
cd airgapped_llm/caaa

# Initialize PKI certificates
./scripts/m0_init.sh

# Build all crates
cargo build --workspace --release

# Run tests
cargo test --workspace
```

### Run Development Server

```bash
# Start caaa-core daemon
cargo run --release -p caaa-core

# In another terminal, start applet
cargo run --release -p caaa-applet
```

## Security Model

### mTLS Communication
- Self-signed PKI provisioned during installation
- Certificate validation on every gRPC connection
- Automatic certificate rotation (configurable, default: 365 days)

### Air-Gap Enforcement
- No outbound socket connections permitted
- Network namespace isolation for reasoning engines
- USB auto-mount disabled in production configuration

### Constitutional Layer
- All LLM outputs validated against Prolog rules before display
- Dual-model verification (primary + verifier) for critical operations
- Fingerprinting attack prevention via randomized query ordering

## Accessibility Features

- **100% keyboard navigable** (Tab, Arrow keys, Super+Space)
- **Orca screen reader tested** at every milestone
- **High contrast mode** (4.5:1 minimum ratio)
- **Focus management** to prevent keyboard traps
- **STATUS_BLOCK announcements** within 200ms

## Deployment

See [`CAAA_DEPLOYMENT_OPERATIONS.md`](docs/CAAA_DEPLOYMENT_OPERATIONS.md) for:
- Offline GPG signing ceremony
- Model lifecycle management
- Multi-user isolation modes
- State recovery procedures
- Troubleshooting runbook

## Roadmap

| Milestone | Status | Deliverables |
|-----------|--------|--------------|
| M0: Scaffold + PKI | ✅ Complete | Workspace, proto defs, PKI gen |
| M1: Core Daemon | 🚧 In Progress | gRPC server, session mgmt |
| M2: Reasoning Layer | ⏳ Planned | Subprocess wrappers, Ollama integration |
| M3: Constitution | ⏳ Planned | Rule engine, dual-model verification |
| M5: Accessibility | ⏳ Planned | Orca integration, keyboard nav |
| M8: Release Candidate | ⏳ Planned | Full test matrix pass |

## Contributing

This project is developed for air-gapped deployment. External contributions must be:
1. Reviewed offline by security team
2. Validated against SRS v1.2 requirements
3. Tested on reference Pop!_OS hardware

## License

MIT License - see LICENSE file for details.

## Contact

For questions about this implementation, refer to the documentation in the `docs/` directory or contact the project maintainer via secure channels.
