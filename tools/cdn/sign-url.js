#!/usr/bin/env node
// Minimal Cloud CDN Signed URL generator (Signed URL key on Backend Bucket)
// Usage:
//   node sign-url.js --baseUrl https://cdn.example.com --path /hls/vid/master.m3u8 \
//     --keyName mychannel-key --key <BASE64URL_KEY> [--expiresSec 3600]

const crypto = require('crypto')

function parseArgs() {
  const args = {}
  for (let i = 2; i < process.argv.length; i += 2) {
    const k = process.argv[i]
    const v = process.argv[i + 1]
    if (!k || !v || !k.startsWith('--')) continue
    args[k.slice(2)] = v
  }
  return args
}

function b64urlDecode(input) {
  // convert base64url -> base64
  let b64 = input.replace(/-/g, '+').replace(/_/g, '/')
  while (b64.length % 4) b64 += '='
  return Buffer.from(b64, 'base64')
}

function b64urlEncode(buf) {
  return Buffer.from(buf)
    .toString('base64')
    .replace(/\+/g, '-')
    .replace(/\//g, '_')
    .replace(/=+$/, '')
}

function sign({ baseUrl, path, keyName, key, expiresSec }) {
  if (!baseUrl || !path || !keyName || !key) {
    throw new Error('Missing required args: baseUrl, path, keyName, key')
  }
  const now = Math.floor(Date.now() / 1000)
  const exp = now + (Number(expiresSec || 3600))
  // StringToSign is path + Expires
  const stringToSign = `${path}${exp}`
  const hmacKey = b64urlDecode(key)
  const sig = crypto.createHmac('sha1', hmacKey).update(stringToSign).digest()
  const signature = b64urlEncode(sig)
  const url = new URL(baseUrl)
  url.pathname = path
  url.searchParams.set('Expires', String(exp))
  url.searchParams.set('KeyName', keyName)
  url.searchParams.set('Signature', signature)
  return { url: url.toString(), exp, signature }
}

if (require.main === module) {
  const args = parseArgs()
  const result = sign({
    baseUrl: args.baseUrl,
    path: args.path,
    keyName: args.keyName,
    key: args.key,
    expiresSec: args.expiresSec,
  })
  console.log(result.url)
}

module.exports = { sign }




