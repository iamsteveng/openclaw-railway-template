# TOOLS.md - Local Notes

Skills define _how_ tools work. This file is for _your_ specifics — the stuff that's unique to your setup.

## What Goes Here

Things like:

- Camera names and locations
- SSH hosts and aliases
- Preferred voices for TTS
- Speaker/room names
- Device nicknames
- Anything environment-specific

## Examples

```markdown
### Cameras

- living-room → Main area, 180° wide angle
- front-door → Entrance, motion-triggered

### SSH

- home-server → 192.168.1.100, user: admin

### TTS

- Preferred voice: "Nova" (warm, slightly British)
- Default speaker: Kitchen HomePod
```

## Why Separate?

Skills are shared. Your setup is yours. Keeping them apart means you can update skills without losing your notes, and share skills without leaking your infrastructure.

---

Add whatever helps you do your job. This is your cheat sheet.

## Related

- [Agent workspace](/concepts/agent-workspace)

---

## Market Risk Score

**Trigger phrases:** any prompt containing "market risk score", "risk score", "risk on/off", or asking for DXY/HYG/SPY/VIX composite risk.

**Script location:** `/data/.openclaw/workspace/skills/market-risk-score/market_risk_score.py`

**Usage:**

```bash
# Today's score
python3 /data/.openclaw/workspace/skills/market-risk-score/market_risk_score.py

# Specific date
python3 /data/.openclaw/workspace/skills/market-risk-score/market_risk_score.py --date "last monday"
python3 /data/.openclaw/workspace/skills/market-risk-score/market_risk_score.py --date 2026-05-16

# Machine-readable JSON (for downstream processing)
python3 /data/.openclaw/workspace/skills/market-risk-score/market_risk_score.py --date today --json
```

**What it measures:**

| Factor | Ticker | Bearish when |
|--------|--------|-------------|
| Dollar | DXY | Price > SMA20 AND 5d return > +0.5% |
| HY Bonds | HYG | Price < SMA20 AND 5d return < -0.3% |
| S&P 500 | SPY | RSI(14) < 50 OR price < SMA20 |
| Volatility | VIX | VIX level < 18 (complacency) |

**Classifications:**
- ✅ **Risk On** — 0 bearish signals
- 🟡 **Neutral** — 1 bearish signal
- ⚠️ **Caution** — 2 bearish signals
- 🔴 **Risk Off** — 3–4 bearish signals

**Notes:**
- Weekend/holiday dates automatically roll back to the prior trading day
- Data source: Yahoo Finance public JSON API (no auth required)
- To switch data source: pass `--source browser-json --data '<json>'` where `<json>` is `{"DX-Y.NYB":[{"date":"YYYY-MM-DD","close":N},...], "HYG":[...], "SPY":[...], "^VIX":[...]}` with ≥25 trading days of history per ticker
