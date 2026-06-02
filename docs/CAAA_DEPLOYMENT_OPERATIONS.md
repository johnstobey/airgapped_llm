# CAAA Deployment Operations Manual

**Version:** 1.0  
**Status:** Production Ready  
**Target Environment:** Air-gapped System76 Workstations (Pop!_OS)  
**Audience:** System Administrators, Security Officers, Accessibility Leads

---

## 1. Executive Summary

This manual defines the operational procedures for deploying, maintaining, and auditing the COSMIC Accessible Agent Applet (CAAA) in strictly air-gapped environments. It covers the offline GPG signing ceremony, model lifecycle management, multi-user isolation, and accessibility regression testing ownership.

### Key Operational Principles
- **Zero Trust:** No network access assumed; all integrity verified via cryptographic signatures.
- **Deterministic Builds:** Binaries are reproducible and hashed against known-good values.
- **Accessibility Continuity:** Regression testing is a mandatory gate for every update.
- **State Preservation:** User vaults and audit logs survive system upgrades and crashes.

---

## 2. Offline Bundle Distribution & Verification

### 2.1 The Air-Gap Challenge
Since the target system has no network access, software updates must be transferred via physical media (USB drive) using a "Sneakernet" workflow. This introduces risks of tampering during transfer.

### 2.2 GPG Signing Ceremony (Offline)

#### Roles
- **Release Manager:** Holds the private signing key (`caaa-release@system76.com`). Never touches the air-gapped machine.
- **Security Officer:** Verifies the fingerprint of the public key on the air-gapped machine before trusting it.
- **System Admin:** Performs the physical transfer and installation.

#### Step-by-Step Ceremony

**Phase A: Key Bootstrap (One-Time Setup)**
1. **Generate Key Pair (Online Machine):**
   ```bash
   gpg --full-generate-key
   # Real Name: CAAA Release Team
   # Email: caaa-release@system76.com
   # Expiration: 2 years
   ```
2. **Export Public Key:**
   ```bash
   gpg --armor --export caaa-release@system76.com > caaa-release-public.key
   ```
3. **Print Fingerprint for Verification:**
   ```bash
   gpg --fingerprint caaa-release@system76.com
   # Output: ABCD 1234 ... (Write this down physically)
   ```
4. **Transfer Public Key to USB:**
   ```bash
   cp caaa-release-public.key /mnt/usb-drive/
   ```

**Phase B: Trust Establishment (Air-Gapped Machine)**
1. **Insert USB into Air-Gapped Machine.**
2. **Import Public Key:**
   ```bash
   gpg --import /media/usb/caaa-release-public.key
   ```
3. **Verify Fingerprint (Critical Step):**
   - Security Officer reads the fingerprint from the printed paper.
   - System Admin runs:
     ```bash
     gpg --fingerprint caaa-release@system76.com
     ```
   - **Match Check:** If the fingerprints match exactly, sign the key as ultimate trust:
     ```bash
     gpg --edit-key caaa-release@system76.com
     > trust
     > 5 (Ultimate)
     > sign
     > save
     ```
   - **Mismatch Protocol:** If fingerprints do not match, **DO NOT PROCEED**. Destroy the USB key and investigate the transfer chain.

**Phase C: Bundle Signing (Online Machine)**
1. **Create Tarball:**
   ```bash
   tar -czvf caaa-bundle-v1.0.tar.gz \
       caaa-core \
       caaa-applet \
       caaa-recover \
       models/ \
       systemd/
   ```
2. **Sign the Bundle:**
   ```bash
   gpg --detach-sign --armor caaa-bundle-v1.0.tar.gz
   # Produces: caaa-bundle-v1.0.tar.gz.asc
   ```
3. **Copy Both Files to USB:**
   - `caaa-bundle-v1.0.tar.gz`
   - `caaa-bundle-v1.0.tar.gz.asc`

**Phase D: Verification & Installation (Air-Gapped Machine)**
1. **Verify Signature:**
   ```bash
   gpg --verify /media/usb/caaa-bundle-v1.0.tar.gz.asc /media/usb/caaa-bundle-v1.0.tar.gz
   # Expected: "Good signature from 'CAAA Release Team'"
   ```
2. **If Verification Fails:** Abort immediately. Do not extract.
3. **If Verification Succeeds:** Proceed to extraction and installation.

### 2.3 Key Rotation Policy
- **Frequency:** Every 12 months or upon personnel change.
- **Procedure:**
  1. Generate new key pair online.
  2. Sign the *new* public key with the *old* private key (cross-certification).
  3. Transfer new public key via USB.
  4. Verify cross-signature on air-gapped machine:
     ```bash
     gpg --check-sigs caaa-release@system76.com
     ```
  5. Once verified, import and set trust to Ultimate.
  6. Revoke old key (optional but recommended) and distribute revocation certificate.

---

## 3. Model Lifecycle Management

### 3.1 Model Versioning Scheme
CAAA uses a semantic versioning scheme for AI models to ensure reproducibility and rollback capability.

**Format:** `MODEL_NAME-QUANTIZATION-VERSION.gguf`
- **Example:** `llama-3-8b-q4_k_m-v1.2.0.gguf`

**Components:**
- `MODEL_NAME`: Base architecture (e.g., `llama-3-8b`, `mistral-7b`).
- `QUANTIZATION`: Precision level (e.g., `q4_k_m`, `q5_k_m`, `f16`).
- `VERSION`: Specific fine-tune or patch level (e.g., `v1.2.0`).

### 3.2 Update Frequency
- **Major Models (e.g., Llama 3 → Llama 3.1):** Quarterly review.
- **Quantization Optimizations:** Monthly (if performance gains >5%).
- **Safety Patches:** Immediate (upon discovery of jailbreak vulnerabilities).

### 3.3 Model Validation Protocol
Before deploying a new model to the air-gapped environment:

1. **Hash Verification:**
   - Compute SHA-256 hash of the `.gguf` file on the online machine.
   - Compare against the official hash from the model provider (HuggingFace/Ollama).
   - Document the hash in the release notes.

2. **Benchmarking:**
   - Run standard prompt suite (100 queries) on reference hardware.
   - Metrics: Tokens/sec, Time-to-First-Token (TTFT), Memory Peak.
   - Pass Criteria: No regression >10% from previous version.

3. **Safety Testing:**
   - Run adversarial prompt suite (jailbreak attempts).
   - Verify Constitutional Layer blocks prohibited outputs.
   - Log false negatives for rule tuning.

### 3.4 Hot-Swapping vs. Cold Update
- **Cold Update (Default):** Restart `caaa-core` service to load new model. Ensures clean memory state.
- **Hot-Swap (Advanced):** Ollama supports loading multiple models simultaneously.
  - Configuration: Define `active_model` in `caaa.toml`.
  - Procedure:
    1. Copy new model to `/opt/caaa/models/`.
    2. Update `caaa.toml` with new model path.
    3. Send `SIGHUP` to `caaa-core`:
       ```bash
       systemctl kill --kill-who=main --signal=SIGHUP caaa-core
       ```
    4. Core gracefully drains current requests, unloads old model, loads new model.
  - **Risk:** Higher memory usage during transition; potential race conditions. Recommended only for high-availability setups.

---

## 4. Multi-User Isolation Architecture

### 4.1 Single-User Default
By default, CAAA installs for the primary user (UID 1000):
- **Socket:** `/run/user/1000/caaa.sock`
- **Vault:** `~/Documents/ObsidianVault`
- **Config:** `~/.config/caaa/caaa.toml`

### 4.2 Multi-User Scenarios
For shared workstations (e.g., library kiosks, shared lab machines), CAAA supports two isolation modes:

#### Mode A: Per-User Instances (Recommended)
- **Architecture:** Each user runs their own `caaa-core` daemon instance.
- **Isolation:**
  - Separate Unix sockets: `/run/user/<UID>/caaa.sock`
  - Separate Vaults: `/home/<user>/Documents/ObsidianVault`
  - Separate Audit Logs: `/var/log/caaa/<user>-audit.log`
- **Resource Cost:** Higher RAM usage (one core daemon per user).
- **Configuration:**
  - Systemd template unit: `caaa-core@.service`
  - Enable for user: `systemctl --user enable caaa-core`

#### Mode B: Shared Core, Isolated Vaults
- **Architecture:** Single system-wide `caaa-core` daemon serving multiple users.
- **Isolation:**
  - Single socket: `/run/caaa/system.sock` (root-owned, group `caaa-users`)
  - Vault paths determined by PAM session UID.
  - Audit logs multiplexed by UID.
- **Security Requirement:** Strict filesystem permissions on vault directories (700).
- **Configuration:**
  - System unit: `caaa-core-system.service`
  - Group membership: `usermod -aG caaa-users <username>`

### 4.3 Testing Multi-User Isolation
- **Test T11 (New):** Concurrent Access
  - Spawn 3 users simultaneously.
  - Verify User A cannot read User B's vault files.
  - Verify audit logs correctly tag entries with UID.
  - Verify resource contention (CPU/RAM) does not cause deadlock.

---

## 5. Accessibility Maintenance & Regression Testing

### 5.1 Ownership Model
Accessibility is not a "one-and-done" feature. Continuous validation is required.

- **Primary Owner:** Accessibility Lead (internal team or contracted specialist).
- **Responsibilities:**
  - Review every UI change for WCAG 2.1 AA compliance.
  - Maintain the Orca test script suite.
  - Conduct quarterly user testing with visually impaired participants.

### 5.2 Regression Testing Workflow
Every software update (Milestone or Patch) must pass the Accessibility Gate before deployment.

**Step 1: Automated Checks (CI/CD or Local Script)**
- Run `orca-test-suite.sh` against the new build.
- Checks include:
  - Focus traversal order (Tab/Arrow keys).
  - Screen reader announcement latency (<200ms).
  - High contrast mode rendering.
  - Keyboard trap detection.

**Step 2: Manual Verification**
- Accessibility Lead performs a "Day in the Life" test:
  - Launch applet via keyboard (Super+Space).
  - Navigate entire workflow without mouse.
  - Verify status block announcements.
  - Test error states (network loss, model crash).

**Step 3: Sign-Off**
- If any check fails, the release is blocked.
- Fix must be implemented and re-tested.
- Documentation updated if behavior changes.

### 5.3 Tooling
- **Orca Scripts:** Located in `/opt/caaa/tests/accessibility/orca/`.
- **Contrast Checker:** Integrated into build pipeline (fails if ratio < 4.5:1).
- **Focus Logger:** Debug tool to record focus path for audit.

---

## 6. Capacity Planning & State Recovery SLA

### 6.1 Disk Space Budget
CAAA state management requires predictable disk allocation.

| Component | Estimated Size (per user) | Retention Policy | Total Allocation |
| :--- | :--- | :--- | :--- |
| **Obsidian Vault** | 500 MB (avg) | Unlimited (user data) | 5 GB (soft limit) |
| **Audit Logs** | 50 MB / day | 90 days | 15 GB |
| **State Snapshots** | 200 MB / hour | 24 hours (24 snapshots) | 5 GB |
| **Models** | 4 GB (quantized) | 2 versions (current + backup) | 8 GB |
| **Binaries & Libs** | 500 MB | N/A | 1 GB |
| **Total per User** | | | **~34 GB** |

**Recommendation:** Allocate minimum **50 GB** per user partition to accommodate growth.

### 6.2 Recovery Time Objective (RTO)
- **Target:** < 30 seconds from service start to ready state.
- **Breakdown:**
  - Snapshot load: < 5 seconds (for <1GB vault).
  - Model load: < 15 seconds (7B model on NVMe).
  - Integrity check: < 10 seconds.
- **Timeout Configuration:**
  - systemd `TimeoutStartSec=60` (allows 2x buffer).
  - If recovery exceeds 60s, service fails and triggers `caaa-recover` CLI.

### 6.3 Large Vault Handling
For vaults > 1 GB:
- **Lazy Loading:** Load metadata first, content on demand.
- **Snapshot Throttling:** Create snapshots every 4 hours instead of hourly to reduce I/O latency.
- **Compression:** Enable ZSTD compression for snapshots (trade CPU for disk I/O).

---

## 7. Operational Troubleshooting Runbook

### 7.1 Service Won't Start
**Symptoms:** `systemctl status caaa-core` shows `failed`.
**Diagnosis:**
1. Check logs: `journalctl -u caaa-core -n 50`
2. Common causes:
   - **Port Conflict:** Another process bound to socket? `ss -xl | grep caaa`
   - **Permission Denied:** Vault directory owned by root? `ls -ld ~/Documents/ObsidianVault`
   - **Corrupt Snapshot:** Last snapshot invalid? Run `caaa-recover --verify`.

### 7.2 High CPU Usage
**Symptoms:** Fan noise, sluggish UI.
**Diagnosis:**
1. Identify thread: `top -H -p $(pidof caaa-core)`
2. Common causes:
   - **Reasoning Loop:** Prolog engine stuck in recursion? Check `caaa.toml` for `max_reasoning_steps`.
   - **Model Inference:** Large batch size? Reduce `batch_size` in config.
   - **Audit Lag:** Disk I/O bottleneck? Check `iostat -x 1`.

### 7.3 Accessibility Glitches
**Symptoms:** Orca silent, focus lost.
**Diagnosis:**
1. Verify AT-SPI bus: `dbus-monitor --session "interface='org.a11y.atspi.Registry'"`
2. Restart Orca: `orca --replace &`
3. Check libcosmic version: Ensure compatible with GNOME shell version.

---

## 8. Security Incident Response

### 8.1 Suspected Compromise
If the air-gap is breached or malicious activity detected:
1. **Isolate:** Physically disconnect network cards (if present) and USB ports.
2. **Preserve:** Copy audit logs and state snapshots to evidence USB.
3. **Wipe:** Reformat system partition; reinstall from known-good image.
4. **Rotate:** Generate new GPG keys; revoke old keys.
5. **Analyze:** Forensic analysis of preserved logs on separate machine.

### 8.2 Data Loss
If vault corruption occurs:
1. **Stop Service:** `systemctl stop caaa-core`
2. **Restore:** Use `caaa-recover --restore --snapshot <timestamp>`
3. **Verify:** Run integrity check on restored vault.
4. **Resume:** Start service and verify user data.

---

## 9. Appendix: Command Reference

| Task | Command |
| :--- | :--- |
| **Verify Bundle** | `gpg --verify bundle.tar.gz.asc bundle.tar.gz` |
| **Install Service** | `/opt/caaa/install.sh --user $USER` |
| **Check Status** | `systemctl --user status caaa-core` |
| **View Logs** | `journalctl --user -u caaa-core -f` |
| **Trigger Snapshot** | `caaa-ctl snapshot create` |
| **Recover State** | `caaa-recover --auto` |
| **List Models** | `caaa-ctl model list` |
| **Switch Model** | `caaa-ctl model switch llama-3-8b-q4_v1.2` |
| **Test A11y** | `/opt/caaa/tests/run-a11y-suite.sh` |

---

**End of Document**
