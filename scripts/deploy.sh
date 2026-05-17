#!/usr/bin/env bash
set -euo pipefail

REPO="iamsteveng/alphaclaw"

echo "Fetching latest commit from $REPO..."
SHA=$(git ls-remote "https://github.com/$REPO.git" HEAD | awk '{print $1}')
SHORT="${SHA:0:7}"

echo "Latest SHA: $SHA ($SHORT)"

CURRENT=$(node -e "const p=require('./package.json');console.log(p.dependencies['@chrysb/alphaclaw'])")
if [[ "$CURRENT" == *"$SHA"* ]]; then
  echo "Already at $SHORT — nothing to do."
  exit 0
fi

echo "Updating package.json..."
node -e "
const fs = require('fs');
const pkg = JSON.parse(fs.readFileSync('package.json', 'utf8'));
pkg.dependencies['@chrysb/alphaclaw'] = 'github:$REPO#$SHA';
fs.writeFileSync('package.json', JSON.stringify(pkg, null, 2) + '\n');
"

echo "Regenerating package-lock.json..."
npm install --prefer-online --package-lock-only

echo "Verifying lock file..."
grep -q "$SHA" package-lock.json && echo "Lock file OK." || { echo "ERROR: SHA not found in lock file"; exit 1; }

echo "Committing and pushing..."
git add package.json package-lock.json
git commit -m "Update alphaclaw to $SHORT"
git push origin main

echo "Done — Railway will redeploy automatically."
