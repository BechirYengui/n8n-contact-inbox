#!/usr/bin/env bash
# Prépare le projet dans n8n : identifiants + workflow publié.
# n8n doit être ARRÊTÉ pendant ce script ; relance ./start.sh ensuite.
set -euo pipefail

cd "$(dirname "$0")"

WORKFLOW_ID="ContactInbox0001"

# 1. .env (avec un jeton admin aléatoire au premier lancement)
if [ ! -f .env ]; then
  cp .env.example .env
  TOKEN="$(openssl rand -hex 24)"
  sed -i "s|^ADMIN_TOKEN=.*|ADMIN_TOKEN=$TOKEN|" .env
  echo "Fichier .env créé, avec un ADMIN_TOKEN aléatoire."
fi

# 2. Fabrication des fichiers à importer (.env -> identifiants + workflow)
node scripts/prepare.mjs

# 3. Import dans n8n
# Dépublication d'abord : réimporter un workflow encore publié est refusé.
n8n unpublish:workflow --id="$WORKFLOW_ID" >/dev/null 2>&1 || true
n8n import:credentials --input=.build/credentials.json
n8n import:workflow --input=.build/contact-inbox.json

# 4. Publication : les URL de production deviennent actives au démarrage
n8n publish:workflow --id="$WORKFLOW_ID"

echo
echo "Terminé. Jeton admin (en-tête X-Admin-Token) :"
grep '^ADMIN_TOKEN=' .env | cut -d= -f2
echo
echo "Lance n8n avec ./start.sh, puis la page avec ./frontend.sh"
echo "La Data Table est créée toute seule à la réception du premier message."
