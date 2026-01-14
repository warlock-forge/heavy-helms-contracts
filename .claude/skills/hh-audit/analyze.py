#!/usr/bin/env python3
"""
Heavy Helms Security Audit Analyzer
Parses Slither and Aderyn output, filters false positives, generates report.
"""

import json
import sys
from pathlib import Path
from dataclasses import dataclass
from typing import Optional

# === FALSE POSITIVES CONFIG ===
# Detector + file patterns that are known acceptable

FALSE_POSITIVE_RULES = [
    # weak-prng for timestamp-based timing (not randomness)
    {"detector": "weak-prng", "file_contains": "TournamentGame.sol", "reason": "Timestamp used for time checking, not randomness"},

    # weak-prng for cosmetic name generation
    {"detector": "weak-prng", "file_contains": "PlayerTickets.sol", "reason": "Name generation entropy - cosmetic only"},

    # encode-packed for tokenURI construction (safe pattern)
    {"detector": "encode-packed-collision", "file_contains": "NFT.sol", "reason": "tokenURI construction with unique ID - no collision risk"},

    # Blockhash randomness in GauntletGame (commit-reveal scheme)
    {"detector": "weak-prng", "file_contains": "GauntletGame.sol", "reason": "Intentional commit-reveal scheme"},
    {"detector": "weak-randomness", "file_contains": "GauntletGame.sol", "reason": "Intentional commit-reveal scheme"},

    # Timestamp for game mechanics
    {"detector": "timestamp", "file_contains": "Player.sol", "reason": "Daily reset timing - acceptable precision"},
    {"detector": "timestamp", "file_contains": "Game.sol", "reason": "Game timing mechanics - acceptable precision"},

    # Reentrancy in GameEngine (stateless combat)
    {"detector": "reentrancy-benign", "file_contains": "GameEngine.sol", "reason": "Combat is stateless, no ETH transfers"},

    # Assembly in Solady
    {"detector": "assembly", "file_contains": "lib/solady", "reason": "Audited Solady library"},

    # Centralization (intentional during development)
    {"detector": "centralization", "reason": "Intentional admin control during development"},
]

# Detectors to completely ignore (noise)
IGNORED_DETECTORS = [
    "solc-version",
    "naming-convention",
    "similar-names",
    "too-many-digits",
    "dead-code",
    "literal-instead-of-constant",  # Aderyn noise - 1000+ findings
    "unspecific-solidity-pragma",   # Style preference
    "push-zero-opcode",             # EVM version awareness, not a bug
    "large-numeric-literal",        # Style preference
    "internal-function-used-once",  # Style preference
    "modifier-used-only-once",      # Style preference
    "unused-public-function",       # Style preference
    "todo",                         # Not security
]


@dataclass
class Finding:
    detector: str
    impact: str
    confidence: str
    description: str
    file: str
    lines: list
    is_false_positive: bool = False
    fp_reason: str = ""


def load_slither_report(path: str) -> list[Finding]:
    """Load and parse Slither JSON report."""
    findings = []

    try:
        with open(path, 'r') as f:
            data = json.load(f)
    except (FileNotFoundError, json.JSONDecodeError) as e:
        print(f"ERROR: Could not load Slither report: {e}")
        return findings

    if not data.get('success'):
        print(f"WARNING: Slither reported error: {data.get('error')}")

    for det in data.get('results', {}).get('detectors', []):
        elements = det.get('elements', [])
        file = ""
        lines = []

        if elements:
            sm = elements[0].get('source_mapping', {})
            file = sm.get('filename_relative', '')
            lines = sm.get('lines', [])

        findings.append(Finding(
            detector=det.get('check', 'unknown'),
            impact=det.get('impact', 'Unknown'),
            confidence=det.get('confidence', 'Unknown'),
            description=det.get('description', ''),
            file=file,
            lines=lines,
        ))

    return findings


def load_aderyn_report(path: str) -> tuple[list[Finding], dict]:
    """Load and parse Aderyn JSON report."""
    findings = []
    summary = {}

    try:
        with open(path, 'r') as f:
            data = json.load(f)
    except (FileNotFoundError, json.JSONDecodeError) as e:
        print(f"ERROR: Could not load Aderyn report: {e}")
        return findings, summary

    summary = {
        'files_scanned': data.get('files_summary', {}).get('total_source_units', 0),
        'sloc': data.get('files_summary', {}).get('total_sloc', 0),
    }

    # Parse high issues
    for issue in data.get('high_issues', {}).get('issues', []):
        for instance in issue.get('instances', []):
            findings.append(Finding(
                detector=issue.get('detector_name', 'unknown'),
                impact='High',
                confidence='High',
                description=issue.get('description', ''),
                file=instance.get('contract_path', ''),
                lines=[instance.get('line_no', 0)],
            ))

    # Parse low issues
    for issue in data.get('low_issues', {}).get('issues', []):
        for instance in issue.get('instances', []):
            findings.append(Finding(
                detector=issue.get('detector_name', 'unknown'),
                impact='Low',
                confidence='Medium',
                description=issue.get('description', ''),
                file=instance.get('contract_path', ''),
                lines=[instance.get('line_no', 0)],
            ))

    return findings, summary


def check_false_positive(finding: Finding) -> tuple[bool, str]:
    """Check if a finding matches known false positive patterns."""

    # Check ignored detectors
    if finding.detector in IGNORED_DETECTORS:
        return True, "Ignored detector (noise)"

    # Check false positive rules
    for rule in FALSE_POSITIVE_RULES:
        if rule.get('detector') and rule['detector'] not in finding.detector:
            continue

        file_pattern = rule.get('file_contains')
        if file_pattern and file_pattern not in finding.file:
            continue

        # Matched rule
        return True, rule.get('reason', 'Known false positive')

    return False, ""


def filter_findings(findings: list[Finding]) -> list[Finding]:
    """Apply false positive filtering to findings."""
    for f in findings:
        is_fp, reason = check_false_positive(f)
        f.is_false_positive = is_fp
        f.fp_reason = reason
    return findings


def generate_report(slither_findings: list[Finding], aderyn_findings: list[Finding],
                   aderyn_summary: dict) -> str:
    """Generate the final audit report."""

    lines = []
    lines.append("=" * 60)
    lines.append("HEAVY HELMS SECURITY AUDIT REPORT")
    lines.append("=" * 60)
    lines.append("")

    # Summary
    total_slither = len(slither_findings)
    fp_slither = sum(1 for f in slither_findings if f.is_false_positive)
    actionable_slither = total_slither - fp_slither

    total_aderyn = len(aderyn_findings)
    fp_aderyn = sum(1 for f in aderyn_findings if f.is_false_positive)
    actionable_aderyn = total_aderyn - fp_aderyn

    lines.append("## SCAN SUMMARY")
    lines.append("")
    lines.append(f"Slither: {total_slither} total findings")
    lines.append(f"  - False Positives Filtered: {fp_slither}")
    lines.append(f"  - Actionable Findings: {actionable_slither}")
    lines.append("")
    lines.append(f"Aderyn: {total_aderyn} total findings")
    lines.append(f"  - False Positives Filtered: {fp_aderyn}")
    lines.append(f"  - Actionable Findings: {actionable_aderyn}")
    lines.append(f"  - Files Scanned: {aderyn_summary.get('files_scanned', 0)}")
    lines.append(f"  - Lines of Code: {aderyn_summary.get('sloc', 0)}")
    lines.append("")

    # Validation
    if aderyn_summary.get('files_scanned', 0) == 0:
        lines.append("WARNING: Aderyn scanned 0 files - check configuration!")
        lines.append("")

    # Combine all actionable findings from both tools
    all_actionable = [f for f in slither_findings if not f.is_false_positive]
    all_actionable += [f for f in aderyn_findings if not f.is_false_positive]

    by_impact = {'High': [], 'Medium': [], 'Low': [], 'Informational': []}
    for f in all_actionable:
        by_impact.get(f.impact, by_impact['Informational']).append(f)

    # Report by severity
    for impact in ['High', 'Medium', 'Low', 'Informational']:
        findings = by_impact[impact]
        if not findings:
            continue

        lines.append("-" * 60)
        lines.append(f"## {impact.upper()} SEVERITY ({len(findings)} findings)")
        lines.append("-" * 60)
        lines.append("")

        # Group by detector
        by_detector = {}
        for f in findings:
            by_detector.setdefault(f.detector, []).append(f)

        for detector, det_findings in sorted(by_detector.items()):
            lines.append(f"### [{detector}] ({len(det_findings)} instances)")
            lines.append("")

            # Show first finding's description
            lines.append(f"**Issue:** {det_findings[0].description.split(chr(10))[0][:200]}")
            lines.append("")
            lines.append("**Locations:**")

            for f in det_findings[:5]:  # Limit to 5 examples
                line_str = f"{f.lines[0]}" if f.lines else "?"
                lines.append(f"  - {f.file}:{line_str}")

            if len(det_findings) > 5:
                lines.append(f"  - ... and {len(det_findings) - 5} more")

            lines.append("")

    # False positives summary
    lines.append("-" * 60)
    lines.append("## FALSE POSITIVES FILTERED")
    lines.append("-" * 60)
    lines.append("")

    fp_by_detector = {}
    all_findings = slither_findings + aderyn_findings
    for f in all_findings:
        if f.is_false_positive:
            key = f"{f.detector}: {f.fp_reason}"
            fp_by_detector[key] = fp_by_detector.get(key, 0) + 1

    for key, count in sorted(fp_by_detector.items(), key=lambda x: -x[1]):
        lines.append(f"  - {key} ({count})")

    lines.append("")
    lines.append("=" * 60)
    lines.append("END OF REPORT")
    lines.append("=" * 60)

    return "\n".join(lines)


def main():
    # Reports folder - detect from script location
    script_dir = Path(__file__).resolve().parent
    project_root = script_dir.parent.parent.parent  # .claude/skills/hh-audit -> project root
    reports_dir = project_root / ".claude/audit-reports"
    reports_dir.mkdir(parents=True, exist_ok=True)

    slither_path = reports_dir / "slither-report.json"
    aderyn_path = reports_dir / "aderyn-report.json"

    print("Loading Slither report...")
    slither_findings = load_slither_report(str(slither_path))

    print("Loading Aderyn report...")
    aderyn_findings, aderyn_summary = load_aderyn_report(str(aderyn_path))

    print("Filtering false positives...")
    slither_findings = filter_findings(slither_findings)
    aderyn_findings = filter_findings(aderyn_findings)

    print("Generating report...")
    report = generate_report(slither_findings, aderyn_findings, aderyn_summary)

    print("")
    print(report)

    # Save to reports folder
    report_path = reports_dir / "audit-report.txt"
    with open(report_path, "w") as f:
        f.write(report)
    print(f"\nReport saved to: {report_path}")


if __name__ == "__main__":
    main()
