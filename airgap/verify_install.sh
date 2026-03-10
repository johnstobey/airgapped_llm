#!/usr/bin/env bash
# Post-install verification script for CORVUS airgap bundle
# Verifies that CUDA, NVIDIA driver, Ollama (GPU-backed), Whisper.cpp, and
# Obsidian are all correctly installed and functional.
#
# Usage:
#   bash verify_install.sh [--quiet] [--json]
#
#   --quiet   Only print failures (no pass output)
#   --json    Emit a JSON summary to stdout at the end

set -eo pipefail

# ============
# Options
# ============
QUIET=false
JSON_OUT=false
for arg in "$@"; do
  case "$arg" in
    --quiet) QUIET=true ;;
    --json)  JSON_OUT=true ;;
  esac
done

# ============
# Colour helpers (disabled when not a tty)
# ============
if [[ -t 1 ]]; then
  GREEN='\033[0;32m'
  RED='\033[0;31m'
  YELLOW='\033[1;33m'
  BOLD='\033[1m'
  RESET='\033[0m'
else
  GREEN='' RED='' YELLOW='' BOLD='' RESET=''
fi

pass()  { [[ "$QUIET" == "false" ]] && echo -e "${GREEN}  ✓ PASS${RESET}  $*" || true; }
fail()  { echo -e "${RED}  ✗ FAIL${RESET}  $*"; }
warn()  { echo -e "${YELLOW}  ⚠ WARN${RESET}  $*"; }
info()  { [[ "$QUIET" == "false" ]] && echo -e "       $*" || true; }
header(){ [[ "$QUIET" == "false" ]] && echo -e "\n${BOLD}$*${RESET}" || true; }

# Counters
PASS_COUNT=0
FAIL_COUNT=0
WARN_COUNT=0
declare -a FAILURES=()
declare -a WARNINGS=()

record_pass() { ((PASS_COUNT++)) || true; }
record_fail() { ((FAIL_COUNT++)) || true; FAILURES+=("$1"); }
record_warn() { ((WARN_COUNT++)) || true; WARNINGS+=("$1"); }

# ============
# 1. CUDA Toolkit 12.8+
# ============
header "1. CUDA Toolkit"
MIN_CUDA_MAJOR=12
MIN_CUDA_MINOR=8

if command -v nvcc >/dev/null 2>&1; then
  NVCC_OUTPUT=$(nvcc --version 2>/dev/null || echo "")
  CUDA_VER=$(echo "$NVCC_OUTPUT" | grep -oP 'release \K[0-9]+\.[0-9]+' | head -n1 || echo "")
  if [[ -n "$CUDA_VER" ]]; then
    CUDA_MAJOR=$(echo "$CUDA_VER" | cut -d. -f1)
    CUDA_MINOR=$(echo "$CUDA_VER" | cut -d. -f2)
    if [[ "$CUDA_MAJOR" -gt "$MIN_CUDA_MAJOR" ]] || \
       { [[ "$CUDA_MAJOR" -eq "$MIN_CUDA_MAJOR" ]] && [[ "$CUDA_MINOR" -ge "$MIN_CUDA_MINOR" ]]; }; then
      pass "CUDA $CUDA_VER (≥ ${MIN_CUDA_MAJOR}.${MIN_CUDA_MINOR})"
      info "nvcc --version → $CUDA_VER"
      record_pass
    else
      fail "CUDA $CUDA_VER is installed but version < ${MIN_CUDA_MAJOR}.${MIN_CUDA_MINOR}"
      info "RTX 5070 Ti (Blackwell) requires CUDA 12.8+. Run the CUDA installer from the bundle."
      record_fail "CUDA version too old ($CUDA_VER)"
    fi
  else
    warn "nvcc found but version string could not be parsed"
    info "Raw output: $NVCC_OUTPUT"
    record_warn "nvcc version unparseable"
  fi
else
  fail "nvcc not found — CUDA Toolkit is not installed"
  info "Expected path: /usr/local/cuda/bin/nvcc"
  info "Fix: run the CUDA installer from \$BUNDLE_DIR/cuda/"
  record_fail "CUDA Toolkit not installed"
fi

# ============
# 2. NVIDIA Driver 570.x+
# ============
header "2. NVIDIA Driver"
MIN_DRIVER=570

if command -v nvidia-smi >/dev/null 2>&1; then
  if nvidia-smi >/dev/null 2>&1; then
    DRIVER_VER=$(nvidia-smi --query-gpu=driver_version --format=csv,noheader 2>/dev/null | head -n1 || echo "")
    GPU_NAME=$(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null | head -n1 || echo "unknown")
    CUDA_SMI=$(nvidia-smi --query-gpu=cuda_version --format=csv,noheader 2>/dev/null | head -n1 || echo "unknown")

    info "GPU:     $GPU_NAME"
    info "Driver:  $DRIVER_VER"
    info "CUDA:    $CUDA_SMI (as seen by driver)"

    if [[ -n "$DRIVER_VER" ]]; then
      DRIVER_MAJOR=$(echo "$DRIVER_VER" | cut -d. -f1)
      if [[ "$DRIVER_MAJOR" -ge "$MIN_DRIVER" ]]; then
        pass "NVIDIA Driver $DRIVER_VER (≥ $MIN_DRIVER)"
        record_pass
      else
        fail "NVIDIA Driver $DRIVER_VER is installed but < $MIN_DRIVER"
        info "RTX 5070 Ti requires driver 570+ with open kernel module."
        info "Fix: install driver packages from \$BUNDLE_DIR/nvidia-driver/ or use Pop!_OS driver manager."
        record_fail "NVIDIA driver too old ($DRIVER_VER)"
      fi
    else
      warn "nvidia-smi ran but driver version could not be read"
      record_warn "driver version unreadable"
    fi
  else
    fail "nvidia-smi command exists but returned an error"
    info "The driver may not be loaded. Try rebooting after driver installation."
    record_fail "nvidia-smi failed"
  fi
else
  fail "nvidia-smi not found — NVIDIA driver not installed"
  info "Fix: install driver packages from \$BUNDLE_DIR/nvidia-driver/ or use Pop!_OS driver manager."
  record_fail "NVIDIA driver not installed"
fi

# ============
# 3. Ollama — GPU-backed inference
# ============
header "3. Ollama (GPU inference)"

if ! command -v ollama >/dev/null 2>&1; then
  fail "ollama command not found"
  info "Fix: re-run install_offline.sh to install the Ollama binary."
  record_fail "Ollama not installed"
else
  OLLAMA_VER=$(ollama --version 2>/dev/null | head -n1 || echo "unknown")
  info "Ollama version: $OLLAMA_VER"

  # Check if server is running; if not, start it temporarily
  SERVER_STARTED=false
  if ! ollama list >/dev/null 2>&1; then
    info "Starting Ollama server for verification..."
    nohup ollama serve >/tmp/ollama-verify.log 2>&1 &
    VERIFY_PID=$!
    sleep 5
    SERVER_STARTED=true
  fi

  # Check which models are available
  AVAILABLE_MODELS=$(ollama list 2>/dev/null || echo "")

  for model in "dolphin-mistral" "codestral" "phi3:14b"; do
    if echo "$AVAILABLE_MODELS" | grep -q "^$model"; then
      pass "Model present: $model"
      record_pass
    else
      warn "Model not found: $model  (run: ollama pull $model)"
      record_warn "model missing: $model"
    fi
  done

  # Test GPU usage by running a quick prompt and checking ollama ps
  # We test with dolphin-mistral as it's smallest
  GPU_TEST_MODEL=""
  for m in "dolphin-mistral" "codestral" "phi3:14b"; do
    if echo "$AVAILABLE_MODELS" | grep -q "^$m"; then
      GPU_TEST_MODEL="$m"
      break
    fi
  done

  if [[ -n "$GPU_TEST_MODEL" ]]; then
    info "Running quick inference test with $GPU_TEST_MODEL..."
    START_TS=$(date +%s%N)
    RESPONSE=$(ollama run "$GPU_TEST_MODEL" "Reply with just the number: 2+2" 2>/dev/null | head -c 200 || echo "")
    END_TS=$(date +%s%N)
    ELAPSED_MS=$(( (END_TS - START_TS) / 1000000 ))

    if [[ -n "$RESPONSE" ]]; then
      info "Response: $RESPONSE"
      info "Time:     ${ELAPSED_MS}ms"
      if [[ $ELAPSED_MS -lt 5000 ]]; then
        pass "Inference completed in ${ELAPSED_MS}ms (fast — likely GPU)"
        record_pass
      else
        warn "Inference took ${ELAPSED_MS}ms (slow — may be CPU-only)"
        info "If CUDA and driver are installed, ensure ollama service was restarted after installation."
        info "Check: ollama ps (should show compute = gpu)"
        record_warn "slow inference (${ELAPSED_MS}ms) — possibly CPU-only"
      fi
    else
      fail "No response from $GPU_TEST_MODEL"
      info "Check Ollama logs: tail -f ~/.ollama/logs/server.log"
      record_fail "inference failed for $GPU_TEST_MODEL"
    fi

    # Check compute device via ollama ps
    PS_OUTPUT=$(ollama ps 2>/dev/null || echo "")
    if [[ -n "$PS_OUTPUT" ]]; then
      if echo "$PS_OUTPUT" | grep -qi "gpu"; then
        pass "Compute device: GPU (confirmed via ollama ps)"
        record_pass
      elif echo "$PS_OUTPUT" | grep -qi "cpu"; then
        fail "Compute device: CPU — Ollama is NOT using the GPU"
        info "Ensure CUDA 12.8+ and NVIDIA driver 570+ are installed and the machine has been rebooted."
        info "Then restart Ollama: sudo systemctl restart ollama"
        record_fail "Ollama using CPU instead of GPU"
      else
        warn "Could not determine compute device from 'ollama ps'"
        info "ollama ps output: $PS_OUTPUT"
        record_warn "compute device unknown"
      fi
    fi
  else
    warn "No models available to test GPU inference. Pull a model first."
    record_warn "no models available for GPU test"
  fi

  # Stop the temp server if we started it
  if [[ "$SERVER_STARTED" == "true" ]]; then
    kill "$VERIFY_PID" 2>/dev/null || true
    wait "$VERIFY_PID" 2>/dev/null || true
  fi
fi

# ============
# 4. Whisper.cpp
# ============
header "4. Whisper.cpp"

# Match install_offline.sh: INSTALL_PREFIX default /usr/local/bin → share dir is .../share/whisper.cpp
INSTALL_PREFIX="${INSTALL_PREFIX:-/usr/local/bin}"
WHISPER_BASE="${INSTALL_PREFIX%/bin}/share/whisper.cpp"

WHISPER_BIN=""
if command -v whisper >/dev/null 2>&1; then
  WHISPER_BIN=$(command -v whisper)
elif [[ -L "$HOME/.local/bin/whisper" ]] || [[ -f "$HOME/.local/bin/whisper" ]]; then
  _w="$(readlink -f "$HOME/.local/bin/whisper" 2>/dev/null)"
  [[ -z "$_w" ]] && _w="$HOME/.local/bin/whisper"
  [[ -x "$_w" ]] && WHISPER_BIN="$_w"
fi
if [[ -z "$WHISPER_BIN" ]] && [[ -f "$WHISPER_BASE/build/bin/main" ]]; then
  WHISPER_BIN="$WHISPER_BASE/build/bin/main"
elif [[ -z "$WHISPER_BIN" ]] && [[ -f "$WHISPER_BASE/main" ]]; then
  WHISPER_BIN="$WHISPER_BASE/main"
fi

if [[ -n "$WHISPER_BIN" ]] && [[ -x "$WHISPER_BIN" ]]; then
  WHISPER_VER=$("$WHISPER_BIN" --version 2>/dev/null | head -n1 || echo "")
  pass "Whisper.cpp binary found: $WHISPER_BIN"
  info "Version: ${WHISPER_VER:-unknown}"
  record_pass

  # Check for model (same paths as install_offline)
  MODEL_FILE=$(find "$WHISPER_BASE/models" "$HOME/.local/share/whisper.cpp/models" 2>/dev/null \
    -name "ggml-base.en.bin" 2>/dev/null | head -n1 || echo "")
  if [[ -n "$MODEL_FILE" ]]; then
    MODEL_SIZE=$(du -sh "$MODEL_FILE" 2>/dev/null | cut -f1 || echo "unknown")
    pass "Whisper base.en model found: $MODEL_FILE ($MODEL_SIZE)"
    record_pass
  else
    warn "Whisper base.en model not found"
    info "Download it when internet is available:"
    info "  bash $WHISPER_BASE/models/download-ggml-model.sh base.en"
    record_warn "Whisper model not found"
  fi
else
  warn "whisper binary not found"
  info "If source was installed to $WHISPER_BASE, build with:"
  info "  cd $WHISPER_BASE && mkdir -p build && cd build && cmake .. && make -j\$(nproc)"
  record_warn "Whisper.cpp not built"
fi

# ============
# 5. Obsidian
# ============
header "5. Obsidian"

OBSIDIAN_BIN=""
if command -v obsidian >/dev/null 2>&1; then
  OBSIDIAN_BIN=$(command -v obsidian)
elif [[ -f "$HOME/.local/bin/obsidian" ]]; then
  OBSIDIAN_BIN="$HOME/.local/bin/obsidian"
else
  OBSIDIAN_BIN=$(find "$HOME/.local/share/obsidian" -maxdepth 1 -name "*.AppImage" 2>/dev/null | head -n1 || echo "")
fi

if [[ -n "$OBSIDIAN_BIN" ]] && [[ -f "$OBSIDIAN_BIN" ]]; then
  OBSIDIAN_SIZE=$(du -sh "$OBSIDIAN_BIN" 2>/dev/null | cut -f1 || echo "unknown")
  pass "Obsidian AppImage found: $OBSIDIAN_BIN ($OBSIDIAN_SIZE)"
  record_pass

  DESKTOP_FILE="$HOME/.local/share/applications/obsidian.desktop"
  if [[ -f "$DESKTOP_FILE" ]]; then
    pass "Desktop entry present: $DESKTOP_FILE"
    record_pass
  else
    warn "Desktop entry not found. Obsidian will not appear in the app launcher."
    info "Fix: re-run install_offline.sh to recreate the desktop entry."
    record_warn "Obsidian desktop entry missing"
  fi
else
  warn "Obsidian not found"
  info "Copy the Obsidian AppImage to \$HOME/.local/share/obsidian/ and chmod +x it."
  record_warn "Obsidian not installed"
fi

# ============
# Summary
# ============
echo ""
echo -e "${BOLD}=========================================="
echo    "POST-INSTALL VERIFICATION SUMMARY"
echo -e "==========================================${RESET}"
echo ""
echo -e "  ${GREEN}Passed:${RESET}   $PASS_COUNT"
echo -e "  ${RED}Failed:${RESET}   $FAIL_COUNT"
echo -e "  ${YELLOW}Warnings:${RESET} $WARN_COUNT"
echo ""

if [[ ${#FAILURES[@]} -gt 0 ]]; then
  echo -e "${RED}Failures:${RESET}"
  for f in "${FAILURES[@]}"; do
    echo "  • $f"
  done
  echo ""
fi

if [[ ${#WARNINGS[@]} -gt 0 ]]; then
  echo -e "${YELLOW}Warnings:${RESET}"
  for w in "${WARNINGS[@]}"; do
    echo "  • $w"
  done
  echo ""
fi

if [[ $FAIL_COUNT -eq 0 ]]; then
  echo -e "${GREEN}${BOLD}All critical checks passed. System is ready.${RESET}"
else
  echo -e "${RED}${BOLD}$FAIL_COUNT critical check(s) failed.${RESET}"
  echo "Most likely cause: CUDA Toolkit version or NVIDIA Driver version."
  echo "Everything downstream (Ollama GPU, Whisper GPU) depends on these."
fi
echo ""

# ============
# JSON output (optional)
# ============
if [[ "$JSON_OUT" == "true" ]]; then
  # Build failures JSON array
  FAILURES_JSON="["
  for i in "${!FAILURES[@]}"; do
    [[ $i -gt 0 ]] && FAILURES_JSON+=","
    FAILURES_JSON+="\"${FAILURES[$i]}\""
  done
  FAILURES_JSON+="]"

  WARNINGS_JSON="["
  for i in "${!WARNINGS[@]}"; do
    [[ $i -gt 0 ]] && WARNINGS_JSON+=","
    WARNINGS_JSON+="\"${WARNINGS[$i]}\""
  done
  WARNINGS_JSON+="]"

  echo "{\"pass\":$PASS_COUNT,\"fail\":$FAIL_COUNT,\"warn\":$WARN_COUNT,\"failures\":$FAILURES_JSON,\"warnings\":$WARNINGS_JSON}"
fi

# Exit non-zero if any hard failures
[[ $FAIL_COUNT -eq 0 ]]
