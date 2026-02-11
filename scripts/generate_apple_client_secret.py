#!/usr/bin/env python3
"""
Generate an Apple OAuth client secret JWT from a .p8 key.

Usage:
  python scripts/generate_apple_client_secret.py \
    --team-id 4WBYD78AZD \
    --key-id C6KCA9ASH8 \
    --client-id com.statusxp.statusxp.signin \
    --p8-path C:\\path\\to\\AuthKey_C6KCA9ASH8.p8
"""

from __future__ import annotations

import argparse
import base64
import json
import pathlib
import sys
import time
from datetime import datetime, timezone

from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import ec
from cryptography.hazmat.primitives.asymmetric.utils import decode_dss_signature


def _b64url(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode("ascii")


def _load_private_key(p8_path: pathlib.Path):
    pem = p8_path.read_bytes()
    key = serialization.load_pem_private_key(pem, password=None)
    if not isinstance(key, ec.EllipticCurvePrivateKey):
        raise ValueError("Expected EC private key in .p8 file.")
    return key


def _to_raw_ecdsa_der_to_rs(signature_der: bytes) -> bytes:
    r, s = decode_dss_signature(signature_der)
    # P-256 => 32 bytes each
    return r.to_bytes(32, "big") + s.to_bytes(32, "big")


def _sign_es256(unsigned_token: str, key: ec.EllipticCurvePrivateKey) -> str:
    der_sig = key.sign(unsigned_token.encode("utf-8"), ec.ECDSA(hashes.SHA256()))
    try:
        r, s = decode_dss_signature(der_sig)
        raw_sig = r.to_bytes(32, "big") + s.to_bytes(32, "big")
    except Exception:
        # Fallback if import path changes in future cryptography versions
        raw_sig = _to_raw_ecdsa_der_to_rs(der_sig)
    return _b64url(raw_sig)


def main() -> int:
    parser = argparse.ArgumentParser(description="Generate Apple client secret JWT.")
    parser.add_argument("--team-id", required=True, help="Apple Team ID (iss)")
    parser.add_argument("--key-id", required=True, help="Apple Key ID (kid)")
    parser.add_argument(
        "--client-id",
        required=True,
        help="Apple client_id / sub (e.g. Services ID for web)",
    )
    parser.add_argument("--p8-path", required=True, help="Path to AuthKey_XXXXXX.p8")
    parser.add_argument(
        "--days",
        type=int,
        default=180,
        help="Validity days (max 180 per Apple rules). Default: 180",
    )
    args = parser.parse_args()

    if args.days < 1 or args.days > 180:
        print("Error: --days must be between 1 and 180.", file=sys.stderr)
        return 2

    p8_path = pathlib.Path(args.p8_path)
    if not p8_path.exists():
        print(f"Error: p8 file not found: {p8_path}", file=sys.stderr)
        return 2

    key = _load_private_key(p8_path)

    now = int(time.time())
    exp = now + args.days * 24 * 60 * 60

    header = {"alg": "ES256", "kid": args.key_id, "typ": "JWT"}
    payload = {
        "iss": args.team_id,
        "iat": now,
        "exp": exp,
        "aud": "https://appleid.apple.com",
        "sub": args.client_id,
    }

    encoded_header = _b64url(json.dumps(header, separators=(",", ":")).encode("utf-8"))
    encoded_payload = _b64url(json.dumps(payload, separators=(",", ":")).encode("utf-8"))
    unsigned = f"{encoded_header}.{encoded_payload}"
    encoded_sig = _sign_es256(unsigned, key)
    token = f"{unsigned}.{encoded_sig}"

    expires_at = datetime.fromtimestamp(exp, tz=timezone.utc).isoformat()
    print(token)
    print(f"\nExpires (UTC): {expires_at}", file=sys.stderr)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
