'use strict';
const crypto = require('node:crypto');

const UPLOAD_RULES = {
  maxSize: 5 * 1024 * 1024,
  maxFileCount: 5,
  allowedExtensions: ['.pdf', '.png', '.jpg', '.jpeg', '.csv'],
  allowedMimeTypes: [
    'application/pdf',
    'image/png',
    'image/jpeg',
    'application/vnd.ms-excel',
  ],
};

function assertAllowedUpload(file) {
  if (!file) return { ok: false, reason: 'no file' };
  if (Number(file.size) > UPLOAD_RULES.maxSize) {
    return { ok: false, reason: `exceeds maxSize ${UPLOAD_RULES.maxSize}` };
  }
  if (!UPLOAD_RULES.allowedExtensions.some((ext) => file.name.toLowerCase().endsWith(ext))) {
    return { ok: false, reason: 'extension not in allowedTypes' };
  }
  if (file.mimetype && !UPLOAD_RULES.allowedMimeTypes.includes(file.mimetype)) {
    return { ok: false, reason: 'mimetype not allowed' };
  }
  return { ok: true, reason: 'ok' };
}

class TokenBucket {
  constructor(capacity, refillPerSecond) {
    this.capacity = capacity;
    this.tokens = capacity;
    this.refill = refillPerSecond;
    this.updated = Date.now();
  }

  consume(cost = 1) {
    const now = Date.now();
    this.tokens = Math.min(this.capacity, this.tokens + ((now - this.updated) / 1000) * this.refill);
    this.updated = now;
    if (this.tokens >= cost) {
      this.tokens -= cost;
      return true;
    }
    return false;
  }
}

class RateLimiter {
  constructor(capacity, refillPerSecond) {
    this.buckets = new Map();
    this.capacity = capacity;
    this.refill = refillPerSecond;
  }

  check(key, limit = this.capacity, windowMs = 60000) {
    if (!this.buckets.has(key)) this.buckets.set(key, new TokenBucket(limit, limit / (windowMs / 1000)));
    const allowed = this.buckets.get(key).consume();
    if (this.buckets.size > 4096) {
      const cutoff = Date.now() - 3600000;
      for (const [k, bucket] of this.buckets) {
        if (bucket.updated < cutoff) this.buckets.delete(k);
      }
    }
    return allowed;
  }
}

const loginLimiter = new RateLimiter(30, 10);

const BASE32_ALPHABET = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';

function base32Decode(value) {
  let bits = 0;
  let valueIdx = 0;
  const decoded = [];
  for (const char of value.toUpperCase().replace(/\s/g, '')) {
    const index = BASE32_ALPHABET.indexOf(char);
    if (index < 0) continue;
    bits = (bits << 5) | index;
    valueIdx += 5;
    if (valueIdx >= 8) {
      decoded.push((bits >>> (valueIdx - 8)) & 0xff);
      valueIdx -= 8;
    }
  }
  return Buffer.from(decoded);
}

function totpSecret(bytes = 20) {
  return crypto.randomBytes(bytes).toString('base64').replace(/=+$/g, '').replace(/\+/g, '7').replace(/\//g, 'J');
}

function hmacCounter(secret, counter, algorithm = 'sha1') {
  const key = base32Decode(secret);
  const buf = Buffer.alloc(8);
  buf.writeBigUInt64BE(BigInt(counter));
  const digest = crypto.createHmac(algorithm, key).update(buf).digest();
  const offset = digest[digest.length - 1] & 0x0f;
  const code = digest.readUInt32BE(offset) & 0x7fffffff;
  return (code % 1000000).toString().padStart(6, '0');
}

function totp(secret, now = Date.now(), step = 30) {
  return hmacCounter(secret, Math.floor(now / 1000 / step));
}

function verifyTotp(secret, code, now = Date.now(), window = 1) {
  const counter = Math.floor(now / 1000 / 30);
  for (let i = -window; i <= window; i += 1) {
    if (hmacCounter(secret, counter + i) === String(code)) return true;
  }
  return false;
}

function csrfToken(secret, sessionId) {
  return crypto.createHmac('sha256', secret).update(sessionId).digest('base64url');
}

function verifyCsrf(token, secret, sessionId) {
  const expected = csrfToken(secret, sessionId);
  const a = Buffer.from(String(token));
  const b = Buffer.from(expected);
  return a.length === b.length && crypto.timingSafeEqual(a, b);
}

function honeypotField(name = 'website') {
  return {
    name,
    style: 'position:absolute;left:-9999px',
    value: name,
    ok(input) {
      return !String(input).trim();
    },
  };
}

async function verifyTurnstile(token, secretKey, remoteIp) {
  if (!token || !secretKey) return false;
  const body = new URLSearchParams({ secret: secretKey, response: token, remoteip: remoteIp || '' });
  const response = await fetch('https://challenges.cloudflare.com/turnstile/v0/siteverify', {
    method: 'POST',
    body,
  });
  const data = await response.json();
  return data.success === true;
}

function sha256Hex(value) {
  return crypto.createHash('sha256').update(value).digest('hex');
}

function hashPassword(password, salt = crypto.randomBytes(16).toString('hex'), iterations = 210000, keylen = 32) {
  const digest = crypto.pbkdf2Sync(password, salt, iterations, keylen, 'sha256');
  return { salt, iterations, hash: digest.toString('hex') };
}

function verifyPassword(password, salt, iterations, expectedHash) {
  const computed = hashPassword(password, salt, iterations).hash;
  const a = Buffer.from(computed);
  const b = Buffer.from(expectedHash);
  return a.length === b.length && crypto.timingSafeEqual(a, b);
}

function aesKeyFrom(password) {
  return crypto.createHash('sha256').update(password).digest();
}

function encrypt(plaintext, key) {
  const iv = crypto.randomBytes(12);
  const cipher = crypto.createCipheriv('aes-256-gcm', aesKeyFrom(key), iv);
  const encrypted = Buffer.concat([cipher.update(String(plaintext), 'utf8'), cipher.final()]);
  const tag = cipher.getAuthTag();
  return {
    version: 1,
    algorithm: 'aes-256-gcm',
    iv: iv.toString('base64'),
    tag: tag.toString('base64'),
    data: encrypted.toString('base64'),
  };
}

function decrypt(payload, key) {
  const decipher = crypto.createDecipheriv(
    'aes-256-gcm',
    aesKeyFrom(key),
    Buffer.from(payload.iv, 'base64'),
  );
  decipher.setAuthTag(Buffer.from(payload.tag, 'base64'));
  return Buffer.concat([
    decipher.update(Buffer.from(payload.data, 'base64')),
    decipher.final(),
  ]).toString('utf8');
}

function log(level, message, fields = {}) {
  const entry = {
    level,
    message,
    time: new Date().toISOString(),
    ...fields,
  };
  const line = JSON.stringify(entry);
  if (level === 'error') {
    console.error(line);
  } else if (level === 'warn') {
    console.warn(line);
  } else {
    console.info(line);
  }
  return entry;
}

const logger = {
  info: (message, fields) => log('info', message, fields),
  warn: (message, fields) => log('warn', message, fields),
  error: (message, fields) => log('error', message, fields),
  child: () => logger,
};

const auditStore = [];

function audit(event, { actor, action, resource, tenantId, outcome }) {
  const record = {
    audit_log: {
      id: crypto.randomUUID(),
      event,
      actor,
      action,
      resource,
      tenantId,
      outcome,
      occurred_at: new Date().toISOString(),
    },
  };
  auditStore.push(record);
  if (auditStore.length > 5000) auditStore.shift();
  logger.info('security.audit', { actor, action, resource, outcome, auditEvent: event });
  return record;
}

function healthCheck(meta = {}) {
  return {
    status: 'ok',
    healthz: true,
    health: '/health',
    timestamp: new Date().toISOString(),
    uptimeSeconds: process.uptime ? Math.floor(process.uptime()) : 0,
    ...meta,
  };
}

module.exports = {
  UPLOAD_RULES,
  assertAllowedUpload,
  RateLimiter,
  loginLimiter,
  totpSecret,
  totp,
  verifyTotp,
  csrfToken,
  verifyCsrf,
  honeypotField,
  verifyTurnstile,
  sha256Hex,
  hashPassword,
  verifyPassword,
  encrypt,
  decrypt,
  logger,
  audit,
  healthCheck,
};