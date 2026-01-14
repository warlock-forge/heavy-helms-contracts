# Test Tool Installation

## Bulloak (BTT Test Generator)

Bulloak generates Solidity test scaffolds from `.tree` specification files and validates implementations match specs.

### Via Cargo from Git (Recommended)

The crates.io version (0.9.1) has a dependency bug with svm-rs-builds. Install from git instead:

```bash
# Install Rust if needed
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
source $HOME/.cargo/env

# Install bulloak from git (bypasses crates.io bug)
cargo install --git https://github.com/alexfertel/bulloak
```

### Via Cargo from crates.io (Currently Broken)

Once the upstream bug is fixed, you can use:
```bash
cargo install bulloak
```

### Via Homebrew (macOS)

```bash
brew install bulloak
```

### Verify Installation

```bash
bulloak --version
```

### Upgrading

```bash
cargo install bulloak --force
```

---

## Quick Setup

```bash
# Install Rust (if needed)
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
source $HOME/.cargo/env

# Install bulloak
cargo install bulloak

# Verify
bulloak --version
```

---

## Usage

### Scaffold Tests from Spec

```bash
# Generate Solidity from .tree file
bulloak scaffold test/specs/myFunction.tree

# Output to specific file
bulloak scaffold test/specs/myFunction.tree -o test/MyFunction.t.sol
```

### Validate Implementation

```bash
# Check if implementation matches spec
bulloak check test/specs/myFunction.tree

# Auto-fix missing tests
bulloak check --fix test/specs/myFunction.tree

# Check all tree files
bulloak check test/**/*.tree
```

---

## CI Integration

Add to your GitHub Actions workflow:

```yaml
- name: Install Bulloak
  run: cargo install bulloak

- name: Validate Test Specs
  run: bulloak check test/**/*.tree
```

Or in a Makefile:

```makefile
.PHONY: check-specs
check-specs:
	bulloak check test/**/*.tree

.PHONY: fix-specs
fix-specs:
	bulloak check --fix test/**/*.tree
```

---

## Troubleshooting

### "command not found: bulloak"

Source the cargo environment:
```bash
source $HOME/.cargo/env
```

Or add to your shell rc file:
```bash
echo 'source $HOME/.cargo/env' >> ~/.bashrc
source ~/.bashrc
```

### "error: could not compile" during install

Update Rust:
```bash
rustup update
cargo install bulloak --force
```

### Tree file syntax errors

Bulloak will report line numbers for syntax issues:
```
error: unexpected token at line 5
```

Common issues:
- Missing `├──` or `└──` box characters
- Incorrect indentation (must use spaces, not tabs)
- Missing period at end of action statements

### Generated tests don't compile

The scaffold generates a skeleton - you need to:
1. Add imports (`import {TestBase} from "../TestBase.sol";`)
2. Add inheritance (`contract MyTest is TestBase`)
3. Implement modifier bodies
4. Fill in test logic

---

## Editor Support

### VS Code

Install "Unicode Box Drawing" or similar extension to easily type:
- `├──` (branch)
- `└──` (last branch)
- `│` (vertical line)

Or copy/paste from examples.

### Keyboard shortcuts (macOS)

Create a text replacement or use:
- Option+Shift+L for `└`
- Option+Shift+I for `│`
- Option+Shift+T for `├`

### Vim/Neovim

Add abbreviations to config:
```vim
iabbrev bt- ├──
iabbrev bl- └──
iabbrev bv- │
```
