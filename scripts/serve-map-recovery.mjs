// Native Roblox serialization transport, loopback only. Never overwrites a different backup.
// No cloud calls, arbitrary file paths, source execution, or place publication.
import http from 'node:http';
import { createHash } from 'node:crypto';
import { mkdirSync, existsSync, readFileSync, writeFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { join } from 'node:path';

const directory = fileURLToPath(new URL('../place/recovery-2026-11-03/version-428/', import.meta.url));
mkdirSync(directory, { recursive: true });
const files = new Map([
  ['/map.rbxm', ['map.rbxm', 'application/octet-stream', 128 * 1024 * 1024]],
  ['/manifest.json', ['manifest.json', 'application/json', 8 * 1024 * 1024]],
]);
const hash = bytes => createHash('sha256').update(bytes).digest('hex');
const respond = (response, status, data) => {
  response.writeHead(status, { 'content-type': 'application/json' });
  response.end(JSON.stringify(data));
};
http.createServer((request, response) => {
  const entry = files.get(request.url);
  if (!entry) return respond(response, 404, { error: 'Unknown recovery file' });
  const [name, contentType, limit] = entry;
  const path = join(directory, name);
  if (request.method === 'GET') {
    if (!existsSync(path)) return respond(response, 404, { error: 'Export not ready' });
    const bytes = readFileSync(path);
    response.writeHead(200, { 'content-type': contentType, 'content-length': bytes.length });
    return response.end(bytes);
  }
  if (request.method !== 'POST') return respond(response, 405, { error: 'GET or POST only' });
  let size = 0, rejected = false;
  const chunks = [];
  request.on('data', chunk => {
    size += chunk.length;
    if (rejected) return;
    if (size > limit) {
      rejected = true;
      chunks.length = 0;
      return respond(response, 413, { error: 'Export exceeds bounded transport size' });
    }
    chunks.push(chunk);
  });
  request.on('end', () => {
    if (rejected) return;
    try {
      const bytes = Buffer.concat(chunks);
      if (bytes.length === 0) return respond(response, 400, { error: 'Empty export' });
      if (name.endsWith('.json')) JSON.parse(bytes.toString('utf8'));
      const digest = hash(bytes);
      if (existsSync(path)) {
        const old = readFileSync(path);
        if (!old.equals(bytes)) return respond(response, 409, { error: 'Existing backup differs; refusing overwrite' });
      } else {
        writeFileSync(path, bytes, { flag: 'wx' });
      }
      respond(response, 200, { saved: true, bytes: bytes.length, sha256: digest });
      console.log(`${name}: ${bytes.length} bytes, sha256 ${digest}`);
    } catch (error) {
      respond(response, 500, { error: String(error.message) });
    }
  });
  request.on('error', () => { chunks.length = 0; });
}).listen(8778, '127.0.0.1', () => console.log(`Recovery transport on 127.0.0.1:8778; ${directory}`));
