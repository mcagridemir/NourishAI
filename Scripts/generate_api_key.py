#!/usr/bin/env python3
"""
generate_api_key.py — XOR-obfuscate an API key for APIKeyStore.swift

Usage:
    python3 Scripts/generate_api_key.py "sk-ant-api03-YOUR_KEY_HERE"

Paste the printed arrays into APIKeyStore.swift, replacing the existing ones.
"""

import sys
import random

def obfuscate(key: str, seed: int = 42) -> tuple[list[int], list[int]]:
    key_bytes = key.encode("utf-8")
    random.seed(seed)
    salt = [random.randint(1, 254) for _ in key_bytes]
    obfuscated = [b ^ s for b, s in zip(key_bytes, salt)]
    return obfuscated, salt

def fmt_array(name: str, values: list[int]) -> str:
    hex_vals = [f"0x{v:02X}" for v in values]
    lines = []
    for i in range(0, len(hex_vals), 12):
        lines.append("            " + ", ".join(hex_vals[i:i+12]))
    body = ",\n".join(lines)
    return f"    private static let {name}: [UInt8] = [\n{body}\n    ]"

def main():
    if len(sys.argv) < 2:
        print("Usage: python3 Scripts/generate_api_key.py \"sk-ant-api03-...\"")
        sys.exit(1)

    key = sys.argv[1].strip()
    obfuscated, salt = obfuscate(key)

    # Verify round-trip
    recovered = bytes(o ^ s for o, s in zip(obfuscated, salt)).decode("utf-8")
    assert recovered == key, "Round-trip failed!"

    print("// Paste into APIKeyStore.swift — replace _claudeObfuscated and _claudeSalt\n")
    print(fmt_array("_claudeObfuscated", obfuscated))
    print()
    print(fmt_array("_claudeSalt", salt))
    print(f"\n// Verified: round-trip OK, key length {len(key)}")

if __name__ == "__main__":
    main()
