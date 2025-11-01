#!/usr/bin/env python3
"""Cloud CDN Signed URL generator.

Usage:
  python sign_url.py --base https://cdn.example.com --path /hls/vid/master.m3u8 \
    --key-name mychannel-key --key BASE64URL_KEY --expires 3600
"""

import argparse
import base64
import hashlib
import hmac
import time
from urllib.parse import urlencode, urlunparse


def b64url_decode(s: str) -> bytes:
  s = s.replace('-', '+').replace('_', '/')
  s += '=' * ((4 - len(s) % 4) % 4)
  return base64.b64decode(s)


def b64url_encode(b: bytes) -> str:
  return base64.urlsafe_b64encode(b).decode().rstrip('=')


def sign(base: str, path: str, key_name: str, key: str, expires: int = 3600) -> str:
  now = int(time.time())
  exp = now + int(expires)
  string_to_sign = f"{path}{exp}".encode()
  hkey = b64url_decode(key)
  sig = hmac.new(hkey, string_to_sign, hashlib.sha1).digest()
  signature = b64url_encode(sig)

  query = urlencode({
      'Expires': str(exp),
      'KeyName': key_name,
      'Signature': signature,
  })
  return f"{base}{path}?{query}"


def main():
  ap = argparse.ArgumentParser()
  ap.add_argument('--base', required=True)
  ap.add_argument('--path', required=True)
  ap.add_argument('--key-name', required=True)
  ap.add_argument('--key', required=True, help='base64url (unpadded) key')
  ap.add_argument('--expires', type=int, default=3600)
  args = ap.parse_args()
  print(sign(args.base, args.path, args.key_name, args.key, args.expires))


if __name__ == '__main__':
  main()




