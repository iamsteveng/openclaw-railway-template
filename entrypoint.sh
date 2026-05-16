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

# Register x-list-ingest cron job (idempotent — skipped if already registered or X_INGEST_LIST_ID unset)
if [ -n "${X_INGEST_LIST_ID:-}" ]; then
  if openclaw cron list --json 2>/dev/null | jq -e '.[] | select(.name=="x-list-ingest")' >/dev/null 2>&1; then
    echo "[x-list-ingest] Cron job already registered, skipping"
  else
    echo "[x-list-ingest] Registering cron job for list ${X_INGEST_LIST_ID}..."
    JOB_ID=$(openclaw cron add \
      --name x-list-ingest \
      --agent main \
      --cron "0 * * * *" \
      --session isolated \
      --disabled \
      --message "Fetch the 10 most recent posts from X list ID ${X_INGEST_LIST_ID} using the xurl skill.

For each post:
- Use note_tweet text if present (X articles), otherwise use the regular tweet text. Never concatenate both.
- Include any quoted or referenced posts inline under a '## Quoted' section, with the author handle and URL resolved from the API response.
- Ingest each post into gbrain using slug exactly 'twitter/post/<tweet_id>' — no variations, no date suffixes. Skip if already exists. On check error, skip and count as error — never ingest under a different slug.
- Each page frontmatter: type=tweet, tweet_id, author (with @), list_id=${X_INGEST_LIST_ID}, posted_at (ISO-8601), url=https://twitter.com/<handle>/status/<tweet_id>, tags=[twitter, x-list-ingest], quoted_ids if any.

After processing all posts, your reply MUST end with exactly this line:
RESULT: ingested=<n>, skipped_existing=<n>, errors=<n>, slugs=<comma-separated list>" \
      --announce \
      --timeout-seconds 300 \
      --thinking low \
      --tz UTC \
      --json 2>/dev/null | jq -r '.id')
    if [ -n "${JOB_ID:-}" ] && [ "$JOB_ID" != "null" ]; then
      openclaw cron edit "$JOB_ID" \
        --failure-alert \
        --failure-alert-channel last \
        --failure-alert-after 1 \
        --failure-alert-mode announce 2>/dev/null || true
      openclaw cron edit "$JOB_ID" --enable 2>/dev/null || true
      echo "[x-list-ingest] Registered and enabled: $JOB_ID"
    else
      echo "[x-list-ingest] Warning: cron registration failed, skipping"
    fi
  fi
else
  echo "[x-list-ingest] X_INGEST_LIST_ID not set, skipping cron registration"
fi

exec alphaclaw start
