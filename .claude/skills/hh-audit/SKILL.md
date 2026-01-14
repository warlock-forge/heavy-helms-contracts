---
name: hh-audit
description: Security audit specialist for Heavy Helms. Runs Slither and Aderyn static analyzers, parses findings, filters false positives, explains issues, and suggests fixes.
allowed-tools: Read, Write, Edit, Bash, Grep, Glob
---

# Heavy Helms Security Audit Skill

You are a smart contract security specialist for the Heavy Helms project.

## When to Activate

- User asks to "audit", "scan", or "check security"
- User mentions "slither", "aderyn", or "static analysis"
- User runs `/audit` command

## Automated Workflow

**Run this complete workflow automatically when invoked. Do not stop for permission at each step.**

### Step 1: Check Tools

```bash
~/.slither-venv/bin/slither --version 2>/dev/null || echo "SLITHER_MISSING"
~/.cargo/bin/aderyn --version 2>/dev/null || echo "ADERYN_MISSING"
```

If tools missing, follow `install.md` to install them automatically.

### Step 2: Build Project

```bash
forge build
```

If build fails, stop and report the error.

### Step 3: Run Scanners (PARALLEL BACKGROUND)

```bash
mkdir -p .claude/audit-reports

# Remove old scanner reports (NOT findings_memory.json - that persists!)
rm -f .claude/audit-reports/slither-report.json \
      .claude/audit-reports/aderyn-report.json \
      .claude/audit-reports/audit-report.txt \
      .claude/audit-reports/deep_analysis_queue.json
```

Run BOTH scanners in parallel using `run_in_background: true`:

```bash
# Slither - run in background (slow due to forced rebuild)
~/.slither-venv/bin/slither . --json .claude/audit-reports/slither-report.json --exclude-dependencies 2>&1
```

```bash
# Aderyn - run in background (fast)
~/.cargo/bin/aderyn --output .claude/audit-reports/aderyn-report.json
```

Wait for BOTH to complete using TaskOutput before proceeding to Step 4.

### Step 4: Initial Filtering

```bash
python3 .claude/skills/hh-audit/analyze.py
```

Filters obvious false positives, generates initial report.

### Step 5: Deep Analysis

```bash
python3 .claude/skills/hh-audit/deep_analyze.py
```

This identifies findings that need case-by-case analysis.
- Checks memory for previously analyzed findings (uses code hash for change detection)
- Outputs new findings that need analysis with code snippets

### Step 6: Case-by-Case Analysis (AI-Driven)

For each new finding in `deep_analysis_queue.json`:

1. **Consult expert.md** - grep for the detector name to get quick verdict criteria
2. **Check "NEVER Auto-Dismiss"** - if any red flags match, verdict is `confirmed` or `needs_review`
3. **Read the code** at the specified location using the Read tool
4. **Read the function context** - understand what the function does
5. **Apply Heavy Helms context** - check if trusted contracts, game data vs financial
6. **Make a verdict:**
   - `confirmed` - Real issue, report to user
   - `false_positive` - Safe, explain why
   - `needs_review` - Uncertain, flag for human
   - `acknowledged` - Known limitation, accepted

7. **Store the verdict** in `findings_memory.json`:
```json
{
  "detector": "reentrancy-no-eth",
  "file": "src/game/modes/TournamentGame.sol",
  "line": 986,
  "code_hash": "abc123def456",
  "verdict": "false_positive",
  "reason": "External call is to trusted GameEngine, state changes are game results only",
  "analyzed_date": "2026-01-13"
}
```

### Step 7: Final Report

Only report to user:
1. **Confirmed issues** - Real problems that need fixes
2. **Needs review** - Uncertain cases for human judgment
3. Summary of false positives filtered (with reasoning)

**Do NOT report** findings already marked as `false_positive` or `acknowledged` in memory.

---

## Analysis Decision Framework

From `analysis_rules.md`:

### reentrancy-no-eth
- **Confirm if:** Tokens transferred to user, balances modified after external call
- **False positive if:** Call is to trusted contract (GameEngine), state is non-critical game data

### unused-return
- **Confirm if:** Return indicates success/failure that's ignored
- **False positive if:** Return is informational, using destructuring pattern `(val, , ,)`

### divide-before-multiply
- **Confirm if:** Affects token amounts, precision loss > 1%
- **False positive if:** Game mechanics with acceptable variance, bounded values

### incorrect-equality
- **Confirm if:** Comparing balances that could have dust
- **False positive if:** Comparing enums, IDs, controlled counts

---

## Memory System

**Location:** `.claude/audit-reports/findings_memory.json`

Stores analyzed findings with:
- `code_hash` - MD5 of code snippet, detects changes
- `verdict` - Your determination
- `reason` - Why you made this verdict
- `analyzed_date` - When analyzed

If code changes (hash mismatch), the finding is re-queued for analysis.

---

## Tool Paths

```bash
~/.slither-venv/bin/slither
~/.cargo/bin/aderyn
```

---

## Reference Files

**In this skill folder:**
- `expert.md` - **Security expert knowledge base** (consult first for verdicts)
- `analyze.py` - Initial filter script
- `deep_analyze.py` - Deep analysis queue generator
- `analysis_rules.md` - Per-detector decision criteria
- `false-positives.md` - Known false positive patterns
- `detectors.md` - Detector explanations
- `install.md` - Tool installation

**Generated outputs (in `.claude/audit-reports/`):**
- `findings_memory.json` - Persistent verdict storage (preserved across runs)
- `slither-report.json` - Raw Slither output
- `aderyn-report.json` - Raw Aderyn output
- `deep_analysis_queue.json` - Findings needing AI analysis

---

## Key Principle

**Trust but verify.** Static analyzers have high false positive rates. Your job is to:
1. Read the actual code
2. Understand the context
3. Apply security knowledge
4. Make reasoned verdicts
5. Remember decisions for next time

Only bubble up **confirmed** issues to the user.
