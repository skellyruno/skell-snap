#!/usr/bin/env python3
"""Convert JUCE VST3 moduleinfo trailing commas to strict release JSON.

Only commas before closing braces/brackets outside strings are removed.
Metadata is strictly parsed, checked and serialized without changing values.
"""
import argparse
import json
from pathlib import Path
import re


def remove_trailing_commas(source: str) -> str:
    output = []
    inside_string = False
    escaped = False
    for i, char in enumerate(source):
        if inside_string:
            output.append(char)
            if escaped:
                escaped = False
            elif char == "\\":
                escaped = True
            elif char == '"':
                inside_string = False
            continue
        if char == '"':
            inside_string = True
            output.append(char)
        elif char == ",":
            after = i + 1
            while after < len(source) and source[after].isspace():
                after += 1
            if after < len(source) and source[after] in "}]":
                continue
            output.append(char)
        else:
            output.append(char)
    return "".join(output)


def normalize(path: Path, expected_name: str) -> bool:
    original = path.read_text(encoding="utf-8-sig")
    data = json.loads(remove_trailing_commas(original))
    if not isinstance(data, dict):
        raise ValueError("moduleinfo root is not an object")
    if data.get("Name") != expected_name:
        raise ValueError("unexpected VST3 module name")
    if not isinstance(data.get("Version"), str) or not data["Version"]:
        raise ValueError("missing VST3 version")
    classes = data.get("Classes")
    if not isinstance(classes, list) or not classes:
        raise ValueError("VST3 Classes must be a non-empty array")
    cids = []
    for cls in classes:
        if not isinstance(cls, dict) or not isinstance(cls.get("CID"), str):
            raise ValueError("VST3 class missing CID")
        if re.fullmatch(r"[0-9a-fA-F]{32}", cls["CID"]) is None:
            raise ValueError("invalid VST3 CID")
        cids.append(cls["CID"].upper())
    if len(set(cids)) != len(cids):
        raise ValueError("duplicate VST3 class IDs")
    normalized = json.dumps(data, ensure_ascii=False, indent=2) + "\n"
    if json.loads(normalized) != data:
        raise ValueError("VST3 metadata changed during JSON normalization")
    if original == normalized:
        return False
    path.write_text(normalized, encoding="utf-8", newline="\n")
    return True


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--path", type=Path, required=True)
    parser.add_argument("--expected-name", required=True)
    args = parser.parse_args()
    try:
        changed = normalize(args.path, args.expected_name)
    except (OSError, ValueError) as exc:
        parser.exit(1, f"INVALID VST3 moduleinfo: {exc}\n")
    print(f"PASS: strict VST3 JSON ({'normalized' if changed else 'unchanged'}): {args.path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
