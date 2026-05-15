#!/bin/sh
set -e

# Initialize gbrain on the persistent volume (idempotent — safe to run on every start)
echo "[gbrain] Initializing brain at /data/gbrain..."
gbrain init 2>&1 | head -20 || echo "[gbrain] init warning (may be first run)"

# Lock in conservative search mode — 25x cheaper than tokenmax
gbrain config set search.mode conservative 2>/dev/null || true

# Wire gbrain MCP server into Claude Code settings (safe JSON merge)
node -e "
const fs = require('fs');
const dir = '/data/.claude';
const file = dir + '/settings.json';
let cfg = {};
try { cfg = JSON.parse(fs.readFileSync(file, 'utf8')); } catch (e) {}
cfg.mcpServers = cfg.mcpServers || {};
if (!cfg.mcpServers.gbrain) {
  cfg.mcpServers.gbrain = { command: 'gbrain', args: ['serve'] };
  fs.mkdirSync(dir, { recursive: true });
  fs.writeFileSync(file, JSON.stringify(cfg, null, 2));
  console.log('[gbrain] MCP server registered in Claude Code settings');
} else {
  console.log('[gbrain] MCP server already registered, skipping');
}
"

echo "[gbrain] Ready."
exec alphaclaw start
