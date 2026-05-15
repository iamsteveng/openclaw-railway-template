#!/bin/bash
set -e

# Initialize gbrain on the persistent volume (idempotent — safe to run on every start)
echo "[gbrain] Initializing brain at /data/gbrain..."
gbrain init 2>&1 | head -20
if [ "${PIPESTATUS[0]}" -ne 0 ]; then
  echo "[gbrain] init warning (may be first run on this volume)"
fi

# Lock in conservative search mode — 25x cheaper than tokenmax
gbrain config set search.mode conservative 2>/dev/null || true

# Wire gbrain MCP server into Claude Code settings (atomic write, safe JSON merge)
node -e "
const fs = require('fs');
const dir = '/data/.claude';
const file = dir + '/settings.json';
let cfg = {};
try {
  cfg = JSON.parse(fs.readFileSync(file, 'utf8'));
} catch (e) {
  if (e.code !== 'ENOENT') console.warn('[gbrain] Warning: could not parse existing settings.json:', e.message);
}
cfg.mcpServers = cfg.mcpServers || {};
if (!cfg.mcpServers.gbrain) {
  cfg.mcpServers.gbrain = { command: 'gbrain', args: ['serve'] };
  fs.mkdirSync(dir, { recursive: true });
  const tmp = file + '.tmp';
  fs.writeFileSync(tmp, JSON.stringify(cfg, null, 2));
  fs.renameSync(tmp, file);
  console.log('[gbrain] MCP server registered in Claude Code settings');
} else {
  console.log('[gbrain] MCP server already registered, skipping');
}
"

echo "[gbrain] Ready."
exec alphaclaw start
