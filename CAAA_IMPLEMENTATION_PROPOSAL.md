# CAAA Implementation Proposal

**Date:** 2026-01-01  
**Status:** Ready for Approval  
**Version:** 1.0  

## Executive Summary

This proposal effectuates the COSMIC Accessible Agent Applet (CAAA) by implementing a native `libcosmic` applet on Pop!_OS with a headless Rust core daemon, integrating into the existing `airgapped_llm` bundle. The system compensates for visual-spatial deficit, 30-second working memory, and dyslexia through a single linear text chat interface with trustworthy STATUS_BLOCK computation, isolated audit trails, and LAN-only mTLS gRPC transport.

**Key Decisions Already Made:**
- ✅ Native COSMIC `libcosmic` applet (no Electron)
- ✅ Headless `caaa-core` daemon on System76 box
- ✅ mTLS gRPC for front-end ↔ core transport
- ✅ Local Ollama with model tiers (no cloud)
- ✅ Obsidian vault as first-class subsystem
- ✅ Prolog (taxonomy/persona) + Lisp (constitution) + Python (audit tools)
- ✅ Kata/KVM sandbox for Category 1 execution

---

## 1. Implementation Strategy

### Phase 0: Complete Missing Specifications (Week 1)

Before writing production code, author the remaining specification documents in `/workspace/specs/`:

| Spec # | Title | Owner | Dependencies |
|--------|-------|-------|--------------|
| 02 | API / RPC Specification | Core team | 01-system-architecture |
| 04 | UI/UX Specification | Core team | 01, 03 |
| 05 | Obsidian Vault Specification | Core team | 01, 03 |
| 06 | Security & Containment Model | Core team | 01, 02 |
| 07 | Deployment Manual | Core team | 01, 06 |
| 08 | Test Plan | Core team | 01-07 |
| 09 | Constitutional Layer Document | Core team | 01, 04 |
| 10 | User Manual | Core team | 04, 09 |

**Priority:** Specs 02 (API) and 04 (UI/UX) unblock M0/M1 implementation.

### Phase 1: Repository Scaffold (Week 2)

Create the Cargo workspace structure at `/workspace/caaa/`:

```bash
caaa/
├── Cargo.toml                 # workspace definition
├── crates/
│   ├── caaa-proto/            # mTLS gRPC service + message types
│   ├── caaa-state/            # JSON schemas + atomic IO
│   ├── caaa-llm/              # Ollama client, model-tier selection
│   ├── caaa-audit/            # isolated audit thread + channel
│   ├── caaa-persona/          # persona-non-grata filter (Prolog)
│   ├── caaa-constitution/     # 1-14 engine (Lisp)
│   ├── caaa-taxonomy/         # clearing taxonomy classifier (Prolog)
│   ├── caaa-sandbox/          # Kata/KVM spawn (Linux-only)
│   ├── caaa-vault/            # Obsidian vault management
│   ├── caaa-core/             # daemon, orchestrator, RPC server
│   ├── caaa-applet/           # libcosmic front-end (Linux-only)
│   └── caaa-client/           # optional Mac TUI (stub on macOS)
├── rules/
│   ├── persona.pl             # PNG pattern rules
│   ├── taxonomy.pl            # Level 1-6 classification rules
│   └── constitution.lisp      # 1-14 commit logic
├── tools/                     # Python: audit analysis, model-import verify
├── specs/                     # Phase 0 documents
├── config/                    # config.toml schema + defaults
└── docs/                      # user manual, deployment manual
```

### Phase 2: Milestone Implementation (Weeks 3-12)

Follow the 10-milestone roadmap from the build plan:

| Milestone | Week | Deliverable | SRS Coverage | Success Criteria |
|-----------|------|-------------|--------------|------------------|
| **M0** | 3 | Scaffold + mTLS gRPC + cert provisioning | DC-1, MA-1 | Handshake succeeds, certs generated |
| **M1** | 4 | Accessible chat + STATUS_BLOCK | UI-1..10, AC-1..6, PE-2 | Chat turn completes, STATUS_BLOCK rendered |
| **M2** | 5 | State + audit thread | PM-1..5, AE-1..12, AL-1..8 | ledger/audit/history persisted, audit isolated |
| **M3** | 6-7 | Persona + constitution | NL-1..5, PNG-1..10 | Rejection/retry works, `/allow` functional |
| **M4** | 8 | Taxonomy classifier | DC-5, FL-4 | L5/L6 alerts raised correctly |
| **M5** | 9 | Obsidian vault | VL-* | Notes created via NL, audit-on-write |
| **M6** | 10 | Category 1 exec | CE-1..10, CV-1..11, SE-1..4 | Kata microVM spawns, CV verified |
| **M7** | 11 | Provisioning + bundle integration | MP-1..7, A-1..6 | USB import works, bundle folds CAAA |
| **M8** | 12 | libcosmic applet | FL-1..7, UI-* | Panel icon, popup, badges functional |
| **M9** | TBD | Mac client (optional) | UI-*, AC-* | Deprioritized |

---

## 2. Technical Architecture

### 2.1 Component Diagram

```
┌─────────────────────────────────────────────────────────────┐
│ SYSTEM76 BOX (Pop!_OS / COSMIC, LAN-only)                  │
│                                                             │
│ ┌──────────────────┐      mTLS gRPC       ┌──────────────┐ │
│ │ caaa-applet      │ ◄──────────────────► │ caaa-core    │ │
│ │ (libcosmic)      │   :51515 (loopback)  │ (daemon)     │ │
│ │ - STATUS_BLOCK   │                      │              │ │
│ │ - chat UI        │                      │ ┌──────────┐ │ │
│ └──────────────────┘                      │ │orchestr. │ │ │
│                                            │ └────┬─────┘ │ │
│ ┌──────────────────┐      mTLS gRPC       │ │          │ │ │
│ │ caaa-client      │ ◄──────────────────► │ ├─ LLM     │ │ │
│ │ (Mac, optional)  │   :51515 (LAN)       │ ├─ Audit   │ │ │
│ │ - TUI            │                      │ ├─ State   │ │ │
│ └──────────────────┘                      │ ├─ Vault   │ │ │
│                                            │ └──────────┘ │ │
│ ┌──────────────────────────────────────┐                  │ │
│ │ Ollama                               │ ◄───────────────┘ │
│ │ localhost:11434                      │   HTTP            │
│ └──────────────────────────────────────┘                   │
│                                                             │
│ ┌──────────────────────────────────────┐                   │
│ │ Kata Containers + KVM                │                   │
│ │ (Category 1 microVM sandbox)         │                   │
│ └──────────────────────────────────────┘                   │
└─────────────────────────────────────────────────────────────┘
```

### 2.2 Data Flow (Chat Turn)

```
1. User types message → caaa-applet
2. applet --SendMessage(text)--> caaa-core (mTLS gRPC)
3. orchestrator receives request
4. [M3] Constitution gate (Lisp 1-14) → reject/retry if violation
5. orchestrator --pre-snapshot--> audit thread (channel)
6. orchestrator --HTTP POST--> Ollama /api/chat (model tier)
7. Ollama --response text--> orchestrator
8. [M3] Persona-non-grata filter (Prolog) → retry if hedging/refusal
9. orchestrator --extract claims + code blocks-->
10. [M6] Execute in Kata microVM (if code present)
11. [M4] Taxonomy classify discrepancies (Prolog) → alert if L5/L6
12. orchestrator --persist--> ledger.json, history.json, artifacts/
13. [M5] Write vault notes (if spec/decision-log/pattern)
14. orchestrator --compute STATUS_BLOCK--> from ground truth
15. orchestrator --claim+post-snapshot--> audit thread (channel)
16. caaa-core --TurnResponse{reply, status_block, audit_ref}--> applet
17. applet renders response + STATUS_BLOCK
```

### 2.3 Critical Invariants

#### STATUS_BLOCK Computation (Accessibility-Critical)

```rust
// STATUS_BLOCK is computed by caaa-core from persisted ground-truth state
// The LLM NEVER generates it (prevents hallucination for 30-second memory user)

pub struct StatusBlock {
    pub last_action: String,      // from ledger.last_action
    pub current_state: String,    // derived from ledger.current_state
    pub next_step: String,        // from ledger.next_step
    pub project: String,          // from ledger.project
    pub turn: u64,                // from ledger.turn
    pub computed_at: String,      // RFC 3339 UTC timestamp
}

impl StatusBlock {
    pub fn from_ledger(ledger: &Ledger) -> Self {
        Self {
            last_action: ledger.last_action.clone(),
            current_state: ledger.current_state.clone(),
            next_step: ledger.next_step.clone(),
            project: ledger.project.clone(),
            turn: ledger.turn,
            computed_at: chrono::Utc::now().to_rfc3339(),
        }
    }
}
```

#### Audit Thread Isolation (SRS AE-9..AE-12)

```rust
// Audit thread is a dedicated std::thread (not Tokio task)
// Orchestrator holds ONLY the SyncSender end of an unbuffered channel
// Audit thread holds the ONLY open file handle to audit.json

pub struct AuditThread {
    rx: std::sync::mpsc::SyncReceiver<AuditMsg>,
    file: File,  // exclusive append handle
}

impl AuditThread {
    pub fn spawn(path: &Path) -> Self {
        let (tx, rx) = std::sync::mpsc::sync_channel(0);  // unbuffered
        let file = OpenOptions::new()
            .create(true)
            .append(true)
            .open(path)
            .expect("audit.json");
        
        let mut audit = Self { rx, file };
        std::thread::spawn(move || audit.run());
        Self { rx: audit.rx, file }  // file stays with spawned thread
    }
    
    fn run(&mut self) {
        while let Ok(msg) = self.rx.recv() {
            // write to audit.json (exclusive handle)
            // no other component can mutate audit state
        }
    }
}
```

### 2.4 mTLS gRPC Service Definition

```protobuf
// crates/caaa-proto/proto/caaa.proto

syntax = "proto3";
package caaa.v1;

service CaaaService {
  // Send a chat message or command
  rpc SendMessage (SendMessageRequest) returns (TurnResponse);
  
  // Get current STATUS_BLOCK
  rpc GetStatus (GetStatusRequest) returns (StatusResponse);
  
  // List available commands
  rpc GetMenu (GetMenuRequest) returns (MenuResponse);
  
  // Escalate to larger model tier
  rpc EscalateModel (EscalateRequest) returns (EscalateResponse);
}

message SendMessageRequest {
  string project = 1;
  string text = 2;
  optional string artifact_id = 3;  // for follow-ups
}

message TurnResponse {
  string reply = 1;
  StatusBlock status_block = 2;
  optional string audit_ref = 3;  // UUID of audit record
  optional ExecutionResult execution = 4;
}

message StatusBlock {
  string last_action = 1;
  string current_state = 2;
  string next_step = 3;
  string project = 4;
  uint64 turn = 5;
  string computed_at = 6;
}

message ExecutionResult {
  bool success = 1;
  string output = 2;
  int32 exit_code = 3;
  string duration_ms = 4;
}
```

---

## 3. Integration with Existing Airgap Bundle

### 3.1 Bundle Modifications

The CAAA will integrate into the existing `airgapped_llm` bundle by:

1. **Adding CAAA binaries** to the bundle's `bin/` directory:
   - `caaa-core` (headless daemon)
   - `caaa-applet` (libcosmic front-end)
   - Optional: `caaa-client` (Mac TUI)

2. **Updating `install_offline.sh`** to:
   - Install CAAA binaries to `/usr/local/bin/`
   - Create systemd service for `caaa-core` daemon
   - Generate PKI certificates at first launch
   - Set up Obsidian vault directory structure

3. **Extending `Cargo.toml`** in `/workspace/airgap/` to include CAAA crates for offline vendoring:
   ```toml
   [dependencies]
   # ... existing dependencies ...
   
   # CAAA workspace crates (for offline build)
   caaa-proto = { path = "../caaa/crates/caaa-proto" }
   caaa-state = { path = "../caaa/crates/caaa-state" }
   caaa-llm = { path = "../caaa/crates/caaa-llm" }
   caaa-audit = { path = "../caaa/crates/caaa-audit" }
   caaa-persona = { path = "../caaa/crates/caaa-persona" }
   caaa-constitution = { path = "../caaa/crates/caaa-constitution" }
   caaa-taxonomy = { path = "../caaa/crates/caaa-taxonomy" }
   caaa-sandbox = { path = "../caaa/crates/caaa-sandbox" }
   caaa-vault = { path = "../caaa/crates/caaa-vault" }
   caaa-core = { path = "../caaa/crates/caaa-core" }
   caaa-applet = { path = "../caaa/crates/caaa-applet" }
   ```

4. **Adding PKI provisioning script** (`tools/generate_certs.py`):
   ```python
   # Generates self-signed CA + server/client certs
   # Stores in ~/.local/share/caaa/pki/
   # No internet required
   ```

### 3.2 Systemd Service Configuration

Create `/etc/systemd/system/caaa-core.service`:

```ini
[Unit]
Description=CAAA Core Daemon
After=network.target ollama.service
Wants=ollama.service

[Service]
Type=simple
User=jacobcavazos
ExecStart=/usr/local/bin/caaa-core --config /home/jacobcavazos/.local/share/caaa/config.toml
Restart=on-failure
RestartSec=5

# Security hardening
NoNewPrivileges=true
ProtectSystem=strict
ProtectHome=read-only
ReadWritePaths=/home/jacobcavazos/.local/share/caaa

[Install]
WantedBy=multi-user.target
```

---

## 4. Risk Mitigation

### 4.1 Technical Risks

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| **Kata/KVM not available** | High | Medium | Verify CPU virt flags, `kvm` group membership; fallback to Docker seccomp if needed (reduced isolation) |
| **Embedded Prolog/Lisp limitations** | Medium | Medium | Spike in M3: test `scryer-prolog` and `steel` expressiveness; fall back to `swipl`/`sbcl` subprocess if needed |
| **libcosmic API instability** | Medium | Low | Track cosmic-libcosmic releases; isolate applet UI code behind trait boundaries |
| **mTLS cert rotation complexity** | Low | Low | Initial: long-lived certs; add `/reset-pki` command for regeneration; document manual rotation |
| **Obsidian vault sync conflicts** | Medium | Low | Single-writer model (only caaa-core writes); use atomic rename; audit all writes |

### 4.2 Accessibility Risks

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| **STATUS_BLOCK hallucination** | Critical | Low | Enforced by architecture: computed from ledger, never from LLM |
| **Audit trail tampering** | Critical | Low | Isolated thread, exclusive file handle, append-only |
| **Spatial UI creep** | High | Medium | Design review gate: every UI element must pass accessibility test (linear text only) |
| **Working memory overload** | High | Medium | Collapsed traces by default; `/expand <id>` for details; chunked output |

---

## 5. Testing Strategy

### 5.1 Test Matrix (Mapped to SRS §4)

| Test Type | Scope | Tools | SRS Mapping |
|-----------|-------|-------|-------------|
| **Unit tests** | Individual crates | `cargo test`, `proptest` | All functional requirements |
| **Integration tests** | crate→crate RPC | `tokio-test`, mock gRPC | IPC, state persistence |
| **Accessibility tests** | STATUS_BLOCK, TUI | Manual + screen reader simulation | AC-1..AC-6, UI-1..UI-10 |
| **Air-gap tests** | Network egress | `strace`, firewall rules | SI-6, SE-1..SE-4 |
| **Containment tests** | Kata microVM breach | Fuzzing, syscall filtering | CV-1..CV-11 |
| **Persona tests** | Hedging/refusal rejection | Golden test corpus | PNG-1..PNG-10, NL-1..NL-5 |
| **Constitution tests** | 1-14 commit violations | Violation scenarios | LC-1..LC-4 |
| **Taxonomy tests** | Discrepancy classification | L1-L6 test cases | DC-5, FL-4 |
| **Vault tests** | Note creation, sync | Obsidian CLI verification | VL-* requirements |
| **Failure recovery** | Ollama disconnect, crash | Chaos testing | RE-1..RE-3 |

### 5.2 Test Infrastructure

```bash
caaa/
├── tests/
│   ├── integration/
│   │   ├── mtls_handshake.rs
│   │   ├── chat_turn.rs
│   │   ├── audit_isolation.rs
│   │   └── kata_execution.rs
│   ├── accessibility/
│   │   ├── status_block_render.rs
│   │   └── linear_output.rs
│   └── airgap/
│       ├── network_egress.rs
│       └── pki_provisioning.rs
└── tools/
    ├── audit_analyzer.py      # Python: claim/reality diff metrics
    └── taxonomy_metrics.py    # Prolog rule coverage analysis
```

---

## 6. Deployment Workflow

### 6.1 Development Environment Setup

```bash
# On online Pop!_OS machine (with internet)
cd /workspace

# 1. Clone/fork CAAA repo (when created)
git clone https://github.com/richtobey/caaa.git

# 2. Build CAAA with vendored dependencies
cd caaa
cargo build --release --offline  # uses airgap vendored crates

# 3. Run test suite
cargo test --all

# 4. Generate PKI certs for local dev
python3 tools/generate_certs.py --output ~/.local/share/caaa/pki/

# 5. Start Ollama (from airgap bundle)
ollama serve &

# 6. Pull test models
ollama pull mistral:7b-instruct
ollama pull mistral:7b-instruct-q4_K_M

# 7. Run caaa-core daemon
cargo run --bin caaa-core -- --config config/dev.toml

# 8. In another terminal, run applet
cargo run --bin caaa-applet
```

### 6.2 Production Deployment (Airgapped System76 Box)

```bash
# On online Pop!_OS machine
cd /workspace/airgap

# 1. Add CAAA to bundle
export CAAA_DIR="/workspace/caaa"
./get_bundle.sh  # vendors CAAA crates + builds binaries

# 2. Copy bundle to USB drive
cp -r airgap_bundle /media/usb/

# --- AIR GAP ---

# On airgapped System76 box
cd /media/usb/airgap_bundle

# 3. Run installation script (includes CAAA)
sudo ./install_offline.sh

# 4. Enable caaa-core systemd service
sudo systemctl enable caaa-core
sudo systemctl start caaa-core

# 5. Verify service status
systemctl status caaa-core

# 6. Launch applet from COSMIC panel
# (Add to autostart if desired)
```

### 6.3 First Launch Sequence

1. **PKI Generation**: `caaa-core` detects missing certs → generates CA + server/client certs → stores in `~/.local/share/caaa/pki/`
2. **Vault Initialization**: Creates Obsidian vault structure (`vault/specs/`, `vault/logs/`, `vault/patterns/`)
3. **Ollama Discovery**: Connects to `localhost:11434` → queries available models → sets default tier
4. **Applet Connection**: `caaa-applet` starts → loads client cert → connects to `127.0.0.1:51515` → renders STATUS_BLOCK
5. **First Chat Turn**: User types → full pipeline executes → audit record appended

---

## 7. SRS v1.2 Defect Resolutions

As identified in the build plan, these SRS contradictions are resolved:

| Defect | Resolution | Spec Amendment |
|--------|------------|----------------|
| **Air-gap vs Hybrid** | Reframe as "LAN-only, no WAN" | Update SI-6/DC-4/SE-4 |
| **"Code only" vs accessibility** | STATUS_BLOCK/TUI are system-generated (exempt from persona filter) | Constitutional Layer Doc §3 |
| **Duplicate DC-* namespace** | Rename Design Constraints to `DZ-*` | SRS v1.3 errata |
| **"Single binary" vs daemon+applet** | Amend to "small set of static binaries" | DC-3 revision |
| **Obsidian vault not in SRS tables** | Add `VL-*` requirement group | SRS v1.3 addition |
| **Embedded vs subprocess (Prolog/Lisp)** | Prefer embedded (`scryer-prolog`, `steel`), subprocess fallback | M3 spike decision |

---

## 8. Open Items Requiring Decision

| Item | Options | Recommendation | Owner |
|------|---------|----------------|-------|
| **Cert rotation policy** | Auto-rotate yearly vs manual `/reset-pki` | Manual (simpler, audited) | Security lead |
| **Applet linkage** | In-process vs loopback gRPC | Loopback gRPC (single code path) | Architecture |
| **Vault location** | `~/CAAA/vault` vs `~/.local/share/caaa/vault` | `~/.local/share/caaa/projects/<proj>/vault` (per-project) | Product |
| **Kata runtime** | `kata-runtime` vs `containerd-shim-kata` | `kata-runtime` (official) | Platform |
| **Prolog engine** | `scryer-prolog` (embedded) vs `swipl` (subprocess) | Spike in M3; prefer embedded | Core team |
| **Lisp engine** | `steel` (embedded) vs `sbcl` (subprocess) | Spike in M3; prefer embedded | Core team |

---

## 9. Success Metrics

### 9.1 Functional Success

- ✅ M0-M8 milestones completed within 12 weeks
- ✅ All SRS v1.2 requirements verified (test matrix §5.1)
- ✅ Zero network egress on airgapped system (verified by `strace`)
- ✅ STATUS_BLOCK 100% computed from ground truth (code review + test)
- ✅ Audit thread isolation verified (no callable surface from orchestrator)

### 9.2 Accessibility Success

- ✅ Linear text output only (no spatial UI elements)
- ✅ STATUS_BLOCK visible in ≤1 glance (user validation)
- ✅ Traces collapsed by default (dyslexia accommodation)
- ✅ Screen reader compatibility tested (NVDA/ORCA)
- ✅ Working memory load reduced (30-second user validation sessions)

### 9.3 Reliability Success

- ✅ Zero audit record loss under crash testing
- ✅ Auto-save every turn + 30s timer (RE-3)
- ✅ Graceful degradation on Ollama disconnect
- ✅ Kata microVM breach containment (CV-1..CV-11 verified)
- ✅ Vault writes atomic + audited (no silent edits)

---

## 10. Next Actions (On Approval)

### Immediate (Week 1)

1. **Author Spec 02 (API/RPC)** — Define gRPC service, message schemas, error model
2. **Author Spec 04 (UI/UX)** — STATUS_BLOCK layout, TUI key bindings, command grammar
3. **Resolve open items** — Cert rotation, vault location, embedded engine decisions
4. **Update SRS v1.2** — Issue errata for 6 defects (namespace, vault, binary count)

### Short-Term (Week 2)

5. **Scaffold Cargo workspace** — Create `/workspace/caaa/` with 11 crates
6. **Implement M0** — mTLS gRPC handshake, PKI provisioning, offline build
7. **Integrate with airgap bundle** — Update `get_bundle.sh`, `install_offline.sh`
8. **Write M0 tests** — mTLS handshake, cert generation, RPC connectivity

### Medium-Term (Weeks 3-4)

9. **Implement M1** — Ollama tier query, STATUS_BLOCK computation, linear chat
10. **Implement M2** — ledger/history/artifacts persistence, isolated audit thread
11. **Validate accessibility** — User testing with 30-second memory constraints
12. **Document deployment** — Draft Deployment Manual (Spec 07)

---

## Appendix A: Crate Dependency Graph

```
caaa-applet ──────┐
                  ├──► caaa-proto ────────────────► (tonic, prost)
caaa-client ──────┘

caaa-core ────────┬──► caaa-llm ──────────────────► (reqwest, serde_json)
                  ├──► caaa-sandbox ───────────────► (nix, libc, Linux-only)
                  ├──► caaa-audit ─────────────────► (crossbeam-channel)
                  ├──► caaa-persona ───────────────► (scryer-prolog or swipl)
                  ├──► caaa-constitution ──────────► (steel or sbcl)
                  ├──► caaa-taxonomy ──────────────► (scryer-prolog or swipl)
                  ├──► caaa-vault ─────────────────► (caaa-state, caaa-audit)
                  └──► caaa-state ─────────────────► (serde_json, atomic-std)

caaa-llm ─────────┴──► caaa-state

caaa-persona ────────┴──► caaa-state
caaa-taxonomy ──────────┴──► caaa-state
caaa-vault ───────────────┴──► caaa-state
```

---

## Appendix B: Configuration Schema (config.toml)

```toml
# ~/.local/share/caaa/config.toml

[core]
project_root = "~/.local/share/caaa/projects"
default_project = "main"
log_level = "info"

[rpc]
bind_address = "127.0.0.1"
port = 51515
cert_path = "~/.local/share/caaa/pki/server.crt"
key_path = "~/.local/share/caaa/pki/server.key"
ca_cert_path = "~/.local/share/caaa/pki/ca.crt"

[ollama]
base_url = "http://127.0.0.1:11434"
default_model_tier = "small"
models.small = "mistral:7b-instruct-q4_K_M"
models.large = "mistral:7b-instruct"
timeout_sec = 30

[audit]
path = "~/.local/share/caaa/projects/main/audit.json"
flush_on_write = true

[vault]
enabled = true
path = "~/.local/share/caaa/projects/main/vault"
auto_sync = false

[sandbox]
enabled = true
runtime = "kata-runtime"
timeout_sec = 10
max_output_bytes = 1048576  # 1MB

[persona]
rules_path = "rules/persona.pl"
strictness = "standard"  # standard | strict | extreme

[constitution]
rules_path = "rules/constitution.lisp"
enforce = true

[taxonomy]
rules_path = "rules/taxonomy.pl"
alert_threshold = 5  # alert on L5/L6 discrepancies

[retention]
max_artifacts = 1000
max_age_days = 90
```

---

## Appendix C: Command Grammar

```
/help              Show available commands
/status            Show current STATUS_BLOCK
/menu              Show project menu (tasks, artifacts, vault)
/escalate          Switch to large model tier (audited)
/allow <pattern>   Temporarily allow persona-non-grata pattern (audited)
/export <id>       Export artifact to USB transfer drive
/reset-pki         Regenerate PKI certificates (requires restart)
/quit              Exit applet (core continues running)

# Project management
/new-project <name>   Create new project context
/switch <name>        Switch active project
/archive <name>       Archive project (move to cold storage)

# Audit navigation
/audit                Show recent audit records
/audit <uuid>         Show specific audit record with claim/reality diff
/audit search <term>  Search audit records

# Vault operations
/vault note <title>   Create new note (spec/decision-log/pattern)
/vault list           List vault notes
/vault open <id>      Open note in external editor (optional)
```

---

## Approval Checklist

- [ ] Reviewed system architecture (Spec 01)
- [ ] Reviewed state schema (Spec 03)
- [ ] Approved implementation strategy (Phases 0-2)
- [ ] Approved milestone roadmap (M0-M8, 12 weeks)
- [ ] Approved technical architecture (§2)
- [ ] Approved airgap bundle integration (§3)
- [ ] Acknowledged risk mitigations (§4)
- [ ] Approved testing strategy (§5)
- [ ] Approved deployment workflow (§6)
- [ ] Resolved SRS v1.2 defects (§7)
- [ ] Made decisions on open items (§8)
- [ ] Accepted success metrics (§9)

**Approved by:** ________________________  
**Date:** ________________________  
**Next Review:** After Spec 02/04 completion (Week 1)

---

*This proposal implements the CAAA as specified in the build plan (`caaa-build-plan-f4d3c5`), system architecture (`01-system-architecture`), and state schema (`03-state-schema`), integrating with the existing `airgapped_llm` bundle for offline deployment on Pop!_OS.*
