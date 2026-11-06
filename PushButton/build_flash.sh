
#!/bin/bash

set -e

# ==========================================
# STM32 Rust Build and Flash Script
# Target: STM32L476RG
# Architecture: ARM Cortex-M4F
# ==========================================

TARGET="thumbv7em-none-eabihf"
CHIP="STM32L476RG"
PROJECT_NAME="stm32_push_buttton"

ELF="target/$TARGET/release/$PROJECT_NAME"

echo "======================================"
echo " STM32 Rust Build and Flash"
echo "======================================"

# 1. Check Rust
echo "[1/7] Checking Rust installation..."

if ! command -v rustc >/dev/null 2>&1; then
    echo "ERROR: Rust is not installed."
    exit 1
fi

rustc --version
cargo --version

# 2. Check target
echo
echo "[2/7] Checking ARM target..."

if rustup target list --installed | grep -qx "$TARGET"; then
    echo "Target already installed: $TARGET"
else
    echo "Installing target: $TARGET"
    rustup target add "$TARGET"
fi

# 3. Check Cargo configuration
echo
echo "[3/7] Checking Cargo configuration..."

if [ ! -f ".cargo/config.toml" ]; then
    echo "ERROR: .cargo/config.toml missing"
    exit 1
fi

echo "Cargo configuration found."

# 4. Clean
echo
echo "[4/7] Cleaning previous build..."

cargo clean

# 5. Compile
echo
echo "[5/7] Compiling firmware..."

cargo build --release --target "$TARGET"

# 6. Verify ELF
echo
echo "[6/7] Verifying firmware..."

if [ ! -f "$ELF" ]; then
    echo "ERROR: ELF binary not found: $ELF"
    exit 1
fi

echo "Firmware generated successfully."

if command -v arm-none-eabi-size >/dev/null 2>&1; then
    arm-none-eabi-size "$ELF"
fi

# 7. Flash
echo
echo "[7/7] Flashing STM32..."

if ! command -v probe-rs >/dev/null 2>&1; then
    echo "ERROR: probe-rs is not installed."
    exit 1
fi


echo "[7/7] Flashing STM32..."

probe-rs download \
    --chip "$CHIP" \
    "$ELF" \
    --format elf

echo "Firmware downloaded."

echo "Resetting STM32..."

probe-rs reset --chip "$CHIP"

echo "STM32 firmware execution started."

echo
echo "======================================"
echo " STM32 build and flash completed"
echo "======================================"

