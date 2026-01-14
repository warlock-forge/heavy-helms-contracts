# Security Tool Installation

## Slither (Trail of Bits)

### Via dedicated venv (Recommended for Ubuntu/Debian)

Modern Ubuntu/Debian systems use PEP 668 "externally managed environment" which blocks system-wide pip installs. Use a dedicated venv:

```bash
# First, ensure python3-venv is installed (requires sudo)
sudo apt install python3-venv

# Create dedicated venv and install Slither
python3 -m venv ~/.slither-venv
~/.slither-venv/bin/pip install slither-analyzer
```

**Important:** Create an alias or symlink for easy access:
```bash
# Option 1: Add alias to ~/.bashrc or ~/.zshrc
echo 'alias slither="~/.slither-venv/bin/slither"' >> ~/.bashrc
source ~/.bashrc

# Option 2: Symlink to a directory in PATH
ln -s ~/.slither-venv/bin/slither ~/.local/bin/slither
```

### Via Homebrew (macOS)

```bash
brew install slither-analyzer
```

### Via pip (if your system allows it)

```bash
python3 -m pip install slither-analyzer
```

### Verify Installation

```bash
slither --version
# Or if using venv without alias:
~/.slither-venv/bin/slither --version
```

### Requirements
- Python 3.8+
- Foundry (already installed in this project)

### Foundry Integration
Slither auto-detects Foundry projects via `foundry.toml`. Just run `slither .` from project root.

---

## Aderyn (Cyfrin)

### Via curl installer (Recommended)

```bash
curl --proto '=https' --tlsv1.2 -LsSf https://github.com/cyfrin/aderyn/releases/latest/download/aderyn-installer.sh | bash
```

Then reload your shell or run:
```bash
source $HOME/.cargo/env
```

### Via Homebrew

```bash
brew install cyfrin/tap/aderyn
```

### Via npm

```bash
npm install @cyfrin/aderyn -g
```

### Via Cargo (if you have Rust)

```bash
cargo install aderyn
```

### Verify Installation

```bash
aderyn --version
```

### Upgrading

```bash
# If installed via curl
aderyn-update

# If installed via Homebrew
brew upgrade cyfrin/tap/aderyn
```

---

## Quick Setup (Ubuntu/Debian)

```bash
# Aderyn (easy)
curl --proto '=https' --tlsv1.2 -LsSf https://github.com/cyfrin/aderyn/releases/latest/download/aderyn-installer.sh | bash
source $HOME/.cargo/env

# Slither (needs venv on modern systems)
sudo apt install python3-venv  # one-time, requires password
python3 -m venv ~/.slither-venv
~/.slither-venv/bin/pip install slither-analyzer
echo 'alias slither="~/.slither-venv/bin/slither"' >> ~/.bashrc
source ~/.bashrc
```

---

## Troubleshooting

### "externally-managed-environment" error
Your system uses PEP 668. Use the venv method above instead of direct pip install.

### Slither "solc not found"
Foundry projects should work automatically. If not:
```bash
# Ensure forge build works first
forge build

# Or install solc directly
~/.slither-venv/bin/pip install solc-select
~/.slither-venv/bin/solc-select install 0.8.13
~/.slither-venv/bin/solc-select use 0.8.13
```

### Aderyn can't find contracts
Make sure you're in the project root where `foundry.toml` exists:
```bash
cd /path/to/your/project  # where foundry.toml lives
aderyn
```

### Aderyn command not found after install
Source the cargo env:
```bash
source $HOME/.cargo/env
```
Or add to your shell rc file:
```bash
echo 'source $HOME/.cargo/env' >> ~/.bashrc
```
