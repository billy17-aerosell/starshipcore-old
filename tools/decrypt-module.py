"""
StarshipCore Module Decryptor - Security Proof of Concept
Demonstrates that XOR encryption with key in response is NOT secure.
Usage:
  python decrypt-module.py                      # interactive mode
  python decrypt-module.py --url <get-module-url>  # fetch & decrypt live
  python decrypt-module.py --json response.json    # decrypt from saved JSON
"""

import base64
import json
import argparse
import sys

try:
    import requests
    HAS_REQUESTS = True
except ImportError:
    HAS_REQUESTS = False


def xor_decrypt(data: bytes, key: str) -> str:
    key_bytes = key.encode('utf-8')
    key_len = len(key_bytes)
    result = bytearray(len(data))
    for i in range(len(data)):
        result[i] = data[i] ^ key_bytes[i % key_len]
    return result.decode('utf-8', errors='replace')


def decrypt_response(json_data: dict) -> str:
    if json_data.get("status") != "success":
        print(f"[!] Response status: {json_data.get('status', 'unknown')}")
        if "error" in json_data:
            print(f"[!] Error: {json_data['error']}")
        return None

    key = json_data.get("key")
    blob = json_data.get("blob")
    module_name = json_data.get("module", "unknown")

    if not key or not blob:
        print("[!] Missing 'key' or 'blob' in response")
        return None

    print(f"[*] Module: {module_name}")
    print(f"[*] Key: {key}")
    print(f"[*] Blob length: {len(blob)} chars")

    decoded = base64.b64decode(blob)
    print(f"[*] Decoded blob: {len(decoded)} bytes")

    decrypted = xor_decrypt(decoded, key)
    print(f"[*] Decrypted: {len(decrypted)} chars")
    print("=" * 60)

    return decrypted


def mode_interactive():
    print("\n--- Interactive Mode ---")
    print("Choose input method:")
    print("  1) Paste full JSON response")
    print("  2) Enter key and blob separately")
    choice = input("\n> ").strip()

    if choice == "2":
        key = input("Key: ").strip()
        print("Paste blob (base64), then press Enter:")
        blob = input("Blob: ").strip()
        data = {"status": "success", "module": "manual", "key": key, "blob": blob}
    else:
        print("\nPaste JSON response (press Enter twice when done):\n")
        lines = []
        while True:
            try:
                line = input()
                if line == "" and lines:
                    break
                lines.append(line)
            except EOFError:
                break
        raw = "".join(lines).strip()

        # Try to extract JSON from input (in case extra text was pasted)
        json_start = raw.find("{")
        json_end = raw.rfind("}") + 1
        if json_start >= 0 and json_end > json_start:
            raw = raw[json_start:json_end]

        try:
            data = json.loads(raw)
        except json.JSONDecodeError as e:
            print(f"[!] Invalid JSON: {e}")
            print(f"[!] First 200 chars of input: {raw[:200]}")
            return

    result = decrypt_response(data)
    if result:
        print(result[:2000])
        if len(result) > 2000:
            print(f"\n... ({len(result) - 2000} more chars)")

        save = input("\n\nSave to file? (y/n): ").strip().lower()
        if save == 'y':
            filename = data.get("module", "decrypted") + ".lua"
            with open(filename, 'w', encoding='utf-8') as f:
                f.write(result)
            print(f"[*] Saved to {filename}")


def mode_url(url: str):
    if not HAS_REQUESTS:
        print("[!] 'requests' library not installed. Run: pip install requests")
        return

    print(f"\n[*] Fetching: {url}")
    resp = requests.get(url)
    print(f"[*] Status: {resp.status_code}")

    try:
        data = resp.json()
    except json.JSONDecodeError:
        print("[!] Response is not JSON:")
        print(resp.text[:500])
        return

    result = decrypt_response(data)
    if result:
        filename = data.get("module", "decrypted") + ".lua"
        with open(filename, 'w', encoding='utf-8') as f:
            f.write(result)
        print(result[:2000])
        if len(result) > 2000:
            print(f"\n... ({len(result) - 2000} more chars)")
        print(f"\n[*] Full source saved to {filename}")


def mode_json_file(filepath: str):
    print(f"\n[*] Reading: {filepath}")
    with open(filepath, 'r', encoding='utf-8') as f:
        data = json.load(f)

    result = decrypt_response(data)
    if result:
        filename = data.get("module", "decrypted") + ".lua"
        with open(filename, 'w', encoding='utf-8') as f:
            f.write(result)
        print(result[:2000])
        if len(result) > 2000:
            print(f"\n... ({len(result) - 2000} more chars)")
        print(f"\n[*] Full source saved to {filename}")


def main():
    parser = argparse.ArgumentParser(description="Decrypt StarshipCore XOR modules (security PoC)")
    parser.add_argument("--url", help="Full get-module URL to fetch and decrypt")
    parser.add_argument("--json", help="Path to saved JSON response file")
    parser.add_argument("--key", help="XOR key (manual mode)")
    parser.add_argument("--blob", help="Base64 blob (manual mode)")

    args = parser.parse_args()

    if args.key and args.blob:
        data = {"status": "success", "module": "manual", "key": args.key, "blob": args.blob}
        result = decrypt_response(data)
        if result:
            print(result[:2000])
    elif args.url:
        mode_url(args.url)
    elif args.json:
        mode_json_file(args.json)
    else:
        mode_interactive()


if __name__ == "__main__":
    main()
