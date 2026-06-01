# CAAA State Recovery Procedures

**Version:** 1.0  
**Date:** 2024-05-23  
**Status:** Draft (Requires M2 Validation)  
**Owner:** Core Team

## 1. Overview

This document defines recovery procedures for state corruption scenarios, ensuring **Invariant B** (Audit-Only Write) is maintained even after unclean shutdowns, disk failures, or SQLite corruption.

## 2. Architecture: Write-Ahead Logging (WAL)

### 2.1 WAL Strategy

All vault writes follow a two-phase commit:
1. **Append to WAL**: Write operation logged to `vault.wal` (sequential append, atomic).
2. **Apply to Main DB**: Checkpoint WAL entries to `vault.sqlite` in background.

```rust
// Pseudocode for audit thread write
fn write_to_vault(operation: VaultOp) -> Result<()> {
    // Phase 1: Append to WAL (atomic fsync)
    let wal_entry = serialize(operation);
    fs::append("vault.wal", wal_entry)?;
    fs::sync_all("vault.wal")?; // Ensure durability
    
    // Phase 2: Async checkpoint to main DB
    tx.checkpoint_wal()?;
    
    Ok(())
}
```

### 2.2 File Structure

```
~/Documents/ObsidianVault/.caaa/
├── vault.sqlite       # Main SQLite database
├── vault.wal          # Write-ahead log (unbounded until checkpoint)
├── vault.shm          # SQLite shared memory (safe to delete on recovery)
├── audit.log          # Human-readable audit trail
└── snapshots/         # Hourly compressed backups (last 24h)
    ├── snapshot-20240523-1400.bin.gz
    └── ...
```

## 3. Corruption Detection

### 3.1 Integrity Checks on Startup

`caaa-core` performs these checks before accepting connections:

1. **SQLite Integrity**: `PRAGMA integrity_check;`
2. **WAL Checksum**: Verify CRC32 of last 100 WAL entries.
3. **Snapshot Consistency**: Compare latest snapshot hash with main DB.

### 3.2 Failure Modes

| Scenario | Detection Method | Recovery Action |
|----------|------------------|-----------------|
| **Main DB corrupted** | `integrity_check` fails | Restore from latest valid snapshot + replay WAL |
| **WAL corrupted** | CRC32 mismatch | Truncate WAL to last valid entry; restore from snapshot |
| **Both corrupted** | Both checks fail | Restore from oldest valid snapshot; warn user of data loss |
| **Snapshot corrupted** | Gzip decompression fails | Skip corrupted snapshot; use next-oldest |

## 4. Recovery Tool: `caaa-recover`

A standalone CLI tool for manual intervention:

```bash
# Usage
caaa-recover [OPTIONS] <VAULT_PATH>

OPTIONS:
    --dry-run           # Show what would be recovered
    --force             # Skip prompts, auto-recover
    --snapshot <PATH>   # Use specific snapshot file
    --export            # Export recovered data to JSON
```

### 4.1 Recovery Algorithm

1. **Scan Snapshots**: Find all valid `.gz` files in `snapshots/`.
2. **Select Baseline**: Choose latest snapshot passing integrity check.
3. **Replay WAL**: Apply WAL entries sequentially until first corruption.
4. **Verify**: Run `integrity_check` on reconstructed DB.
5. **Replace**: Atomically swap corrupted DB with recovered version.

## 5. Test Scenarios (T05 Extension)

| Test ID | Scenario | Expected Outcome |
|---------|----------|------------------|
| T05-01 | `kill -9` during WAL write | WAL entry complete (atomic fsync); no corruption |
| T05-02 | Corrupt main DB with hex editor | Auto-recovery from snapshot + WAL on startup |
| T05-03 | Delete `vault.shm` | Silent regeneration; no data loss |
| T05-04 | Fill disk to 100% during write | Graceful failure; WAL not truncated; retry on space free |
| T05-05 | Power loss during checkpoint | Recovery via WAL replay; <1min data loss |

## 6. Operational Procedures

### 6.1 Automatic Recovery (Default)

On startup, if corruption detected:
1. Log error to systemd journal.
2. Attempt automatic recovery using algorithm in Section 4.
3. If successful, continue normal operation.
4. If failed, enter **read-only mode** and alert user via applet.

### 6.2 Manual Intervention

If automatic recovery fails:
1. User runs `caaa-recover --export` to salvage data.
2. Support team analyzes exported JSON.
3. Manual reconstruction if needed.

### 6.3 Backup Policy

- **Hourly**: Compressed snapshot to `snapshots/` (retained 24h).
- **Daily**: Copy to external USB (if mounted).
- **Weekly**: GPG-signed archive for long-term storage.

## 7. Implementation Plan (M2)

- [ ] Implement WAL layer in `caaa-core` (Rusqlite WAL mode).
- [ ] Create `caaa-recover` CLI tool.
- [ ] Add hourly snapshot scheduler.
- [ ] Write chaos tests (T05-01 through T05-05).
- [ ] Document recovery runbook for support team.

---
*This spec is prerequisite for M2 milestone approval.*
