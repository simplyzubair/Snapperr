#!/usr/bin/env bash
# Copies the download page to Contabo (ssh host "co") and reloads nginx.
# The page links to the newest GitHub release by itself, so deploy only when the page changes.
set -euo pipefail
cd "$(dirname "$0")/.."

ssh co 'mkdir -p /var/www/snapperr'
for f in website/index.html website/version.js website/icon.png; do
  ssh co "cat > /var/www/snapperr/$(basename "$f")" < "$f"
done
ssh co 'chmod 644 /var/www/snapperr/* && nginx -t && systemctl reload nginx'
echo "Deployed to https://snapperr.skillsgeek.com"
