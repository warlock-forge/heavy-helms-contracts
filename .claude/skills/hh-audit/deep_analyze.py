#!/usr/bin/env python3
"""
Heavy Helms Deep Security Analyzer

Performs case-by-case analysis of security findings.
Reads actual code, applies analysis rules, stores verdicts in memory.
"""

import json
import hashlib
from pathlib import Path
from dataclasses import dataclass, asdict
from typing import Optional
from datetime import datetime

# Paths - detect from script location
SCRIPT_DIR = Path(__file__).resolve().parent
PROJECT_ROOT = SCRIPT_DIR.parent.parent.parent  # .claude/skills/hh-audit -> project root
REPORTS_DIR = PROJECT_ROOT / ".claude/audit-reports"
MEMORY_FILE = REPORTS_DIR / "findings_memory.json"
SLITHER_REPORT = REPORTS_DIR / "slither-report.json"
ADERYN_REPORT = REPORTS_DIR / "aderyn-report.json"

# Slither detectors that need deep analysis (Medium+)
SLITHER_DEEP_ANALYSIS_DETECTORS = [
    "reentrancy-no-eth",
    "unused-return",
    "divide-before-multiply",
    "incorrect-equality",
    "uninitialized-local",
    "reentrancy-benign",
]

# Aderyn HIGH detectors that need deep analysis
ADERYN_DEEP_ANALYSIS_DETECTORS = [
    "abi-encode-packed-hash-collision",
    "unsafe-casting",
    "incorrect-shift-order",
    "storage-array-memory-edit",
    "weak-randomness",
    "contract-locks-ether",
    "reentrancy-state-change",
    "reused-contract-name",
]


@dataclass
class AnalyzedFinding:
    detector: str
    file: str
    line: int
    code_hash: str
    verdict: str  # confirmed, false_positive, needs_review, acknowledged
    reason: str
    analyzed_date: str
    code_snippet: str = ""


def load_memory() -> dict:
    """Load previously analyzed findings from memory."""
    if MEMORY_FILE.exists():
        with open(MEMORY_FILE, 'r') as f:
            return json.load(f)
    return {"findings": [], "version": 1}


def save_memory(memory: dict):
    """Save analyzed findings to memory."""
    MEMORY_FILE.parent.mkdir(parents=True, exist_ok=True)
    with open(MEMORY_FILE, 'w') as f:
        json.dump(memory, f, indent=2)


def get_raw_code(file_path: str, line: int, context: int = 15) -> str:
    """Extract raw code snippet for hashing."""
    full_path = PROJECT_ROOT / file_path
    if not full_path.exists():
        return ""

    try:
        with open(full_path, 'r') as f:
            lines = f.readlines()

        start = max(0, line - context - 1)
        end = min(len(lines), line + context)
        return "".join(lines[start:end])
    except Exception:
        return ""


def get_code_snippet(file_path: str, line: int, context: int = 15) -> str:
    """Extract formatted code snippet for display."""
    full_path = PROJECT_ROOT / file_path
    if not full_path.exists():
        return ""

    try:
        with open(full_path, 'r') as f:
            lines = f.readlines()

        start = max(0, line - context - 1)
        end = min(len(lines), line + context)

        snippet_lines = []
        for i, l in enumerate(lines[start:end], start=start+1):
            marker = ">>>" if i == line else "   "
            snippet_lines.append(f"{marker} {i:4d} | {l.rstrip()}")

        return "\n".join(snippet_lines)
    except Exception as e:
        return f"Error reading file: {e}"


def hash_code(code: str) -> str:
    """Create hash of code snippet for change detection."""
    return hashlib.md5(code.encode()).hexdigest()[:12]


def find_in_memory(memory: dict, detector: str, file: str, line: int, code_hash: str) -> Optional[dict]:
    """Check if we've analyzed this exact finding before."""
    for finding in memory.get("findings", []):
        if (finding["detector"] == detector and
            finding["file"] == file and
            finding["line"] == line and
            finding["code_hash"] == code_hash):
            return finding
    return None


def load_slither_findings() -> list:
    """Load findings that need deep analysis from Slither report."""
    findings = []

    try:
        with open(SLITHER_REPORT, 'r') as f:
            data = json.load(f)
    except Exception as e:
        print(f"Error loading Slither report: {e}")
        return findings

    for det in data.get('results', {}).get('detectors', []):
        detector = det.get('check', '')
        impact = det.get('impact', '')

        # Only analyze medium+ findings that need deep analysis
        if detector not in SLITHER_DEEP_ANALYSIS_DETECTORS:
            continue
        if impact not in ['High', 'Medium']:
            continue

        elements = det.get('elements', [])
        if not elements:
            continue

        sm = elements[0].get('source_mapping', {})
        file = sm.get('filename_relative', '')
        lines = sm.get('lines', [])
        line = lines[0] if lines else 0

        # Skip lib files
        if file.startswith('lib/'):
            continue

        findings.append({
            'detector': detector,
            'impact': impact,
            'confidence': det.get('confidence', ''),
            'description': det.get('description', ''),
            'file': file,
            'line': line,
            'source': 'slither',
        })

    return findings


def load_aderyn_findings() -> list:
    """Load HIGH findings from Aderyn report."""
    findings = []

    try:
        with open(ADERYN_REPORT, 'r') as f:
            data = json.load(f)
    except Exception as e:
        print(f"Error loading Aderyn report: {e}")
        return findings

    # Process high issues
    for issue in data.get('high_issues', {}).get('issues', []):
        detector = issue.get('detector_name', '')

        if detector not in ADERYN_DEEP_ANALYSIS_DETECTORS:
            continue

        for instance in issue.get('instances', []):
            file = instance.get('contract_path', '')
            line = instance.get('line_no', 0)

            # Skip lib files
            if file.startswith('lib/'):
                continue

            findings.append({
                'detector': detector,
                'impact': 'High',
                'confidence': 'High',
                'description': issue.get('description', ''),
                'file': file,
                'line': line,
                'source': 'aderyn',
            })

    return findings


def load_findings_for_deep_analysis() -> list:
    """Load all findings that need deep analysis from both tools."""
    slither = load_slither_findings()
    aderyn = load_aderyn_findings()
    return slither + aderyn


def generate_analysis_prompt(finding: dict, code_snippet: str) -> str:
    """Generate the analysis context for a finding."""
    return f"""
## Finding Analysis Required

**Detector:** {finding['detector']}
**Impact:** {finding['impact']}
**Confidence:** {finding['confidence']}
**Location:** {finding['file']}:{finding['line']}

**Description:**
{finding['description'][:500]}

**Code:**
```solidity
{code_snippet}
```

Analyze this finding and determine:
1. Is this a real security issue or false positive?
2. What is the actual risk in the Heavy Helms context?
3. Verdict: confirmed, false_positive, needs_review, or acknowledged
"""


def main():
    print("=" * 60)
    print("HEAVY HELMS DEEP SECURITY ANALYSIS")
    print("=" * 60)
    print()

    # Load memory
    memory = load_memory()
    print(f"Loaded memory: {len(memory.get('findings', []))} previously analyzed findings")

    # Load findings needing analysis
    findings = load_findings_for_deep_analysis()
    print(f"Found {len(findings)} findings requiring deep analysis")
    print()

    # Categorize findings
    new_findings = []
    cached_findings = []

    for f in findings:
        raw_code = get_raw_code(f['file'], f['line'])
        code_hash = hash_code(raw_code)

        cached = find_in_memory(memory, f['detector'], f['file'], f['line'], code_hash)
        if cached:
            cached_findings.append(cached)
        else:
            f['code_snippet'] = get_code_snippet(f['file'], f['line'])  # Formatted for display
            f['code_hash'] = code_hash
            new_findings.append(f)

    print(f"Cached (no re-analysis needed): {len(cached_findings)}")
    print(f"New/Changed (need analysis): {len(new_findings)}")
    print()

    # Summary of cached verdicts
    if cached_findings:
        print("-" * 60)
        print("CACHED VERDICTS (from previous analysis)")
        print("-" * 60)
        by_verdict = {}
        for f in cached_findings:
            v = f['verdict']
            by_verdict[v] = by_verdict.get(v, 0) + 1
        for verdict, count in sorted(by_verdict.items()):
            print(f"  {verdict}: {count}")
        print()

    # Output new findings that need analysis
    if new_findings:
        print("-" * 60)
        print("FINDINGS REQUIRING DEEP ANALYSIS")
        print("-" * 60)
        print()
        print("The following findings need case-by-case review.")
        print("For each, analyze the code and determine the verdict.")
        print()

        for i, f in enumerate(new_findings, 1):
            print(f"### [{i}/{len(new_findings)}] {f['detector']}")
            print(f"**Location:** {f['file']}:{f['line']}")
            print(f"**Impact:** {f['impact']} | **Confidence:** {f['confidence']}")
            print()
            print("**Code:**")
            print("```solidity")
            print(f['code_snippet'][:2000])  # Limit output
            print("```")
            print()
            print(f"**Description:** {f['description'][:300]}...")
            print()
            print("-" * 40)
            print()

    # Generate summary
    print("=" * 60)
    print("ANALYSIS SUMMARY")
    print("=" * 60)

    confirmed = [f for f in cached_findings if f['verdict'] == 'confirmed']
    needs_review = [f for f in cached_findings if f['verdict'] == 'needs_review']

    print(f"""
Total Findings for Deep Analysis: {len(findings)}
  - Previously Analyzed: {len(cached_findings)}
    - Confirmed Issues: {len(confirmed)}
    - False Positives: {len([f for f in cached_findings if f['verdict'] == 'false_positive'])}
    - Needs Review: {len(needs_review)}
    - Acknowledged: {len([f for f in cached_findings if f['verdict'] == 'acknowledged'])}
  - New (Need Analysis): {len(new_findings)}
""")

    if confirmed:
        print("CONFIRMED ISSUES FROM MEMORY:")
        for f in confirmed:
            print(f"  - [{f['detector']}] {f['file']}:{f['line']}")
            print(f"    Reason: {f['reason']}")
        print()

    if new_findings:
        print(f"ACTION REQUIRED: {len(new_findings)} findings need case-by-case analysis.")
        print("Use the code snippets above to determine verdicts.")
        print()
        print("To record a verdict, add to findings_memory.json:")
        print("""
{
  "detector": "detector-name",
  "file": "path/to/file.sol",
  "line": 123,
  "code_hash": "abc123...",
  "verdict": "false_positive|confirmed|needs_review|acknowledged",
  "reason": "Explanation of why this verdict",
  "analyzed_date": "2026-01-13"
}
""")
    else:
        print("All findings have been previously analyzed.")
        if not confirmed:
            print("No confirmed security issues!")

    # Save the analysis prompt data for the skill to use
    analysis_data = {
        "new_findings": new_findings,
        "cached_findings": cached_findings,
        "summary": {
            "total": len(findings),
            "cached": len(cached_findings),
            "new": len(new_findings),
            "confirmed": len(confirmed),
        }
    }

    with open(REPORTS_DIR / "deep_analysis_queue.json", 'w') as f:
        json.dump(analysis_data, f, indent=2)

    print(f"\nAnalysis queue saved to: {REPORTS_DIR / 'deep_analysis_queue.json'}")


if __name__ == "__main__":
    main()
