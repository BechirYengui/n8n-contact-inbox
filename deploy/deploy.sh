#!/usr/bin/env bash
# Déploie le projet avec Docker : n8n + Caddy (HTTPS automatique).
# À lancer sur un serveur dont le domaine (DOMAIN dans ../.env) pointe vers lui.
set -euo pipefail

cd "$(dirname "$0")"
ENV_FILE="../.env"

[ -f "$ENV_FILE" ] || { echo "../.env manquant : lance d'abord ../setup.sh"; exit 1; }
set -a; . "$ENV_FILE"; set +a

[ -n "${DOMAIN:-}" ] || { echo "DOMAIN est vide dans ../.env"; exit 1; }

# Clé de chiffrement des identifiants n8n : générée une fois, puis conservée.
if [ -z "${N8N_ENCRYPTION_KEY:-}" ]; then
  KEY="$(openssl rand -hex 24)"
  sed -i "s|^N8N_ENCRYPTION_KEY=.*|N8N_ENCRYPTION_KEY=$KEY|" "$ENV_FILE"
  export N8N_ENCRYPTION_KEY="$KEY"
  echo "N8N_ENCRYPTION_KEY généré et enregistré dans .env (à sauvegarder !)."
fi

# En production, la page et les webhooks sont sur le même domaine.
if ! grep -q "^ALLOWED_ORIGINS=https://$DOMAIN$" "$ENV_FILE"; then
  sed -i "s|^ALLOWED_ORIGINS=.*|ALLOWED_ORIGINS=https://$DOMAIN|" "$ENV_FILE"
  echo "ALLOWED_ORIGINS fixé à https://$DOMAIN"
fi

mkdir -p data/n8n data/caddy data/caddy-config

# 1. Fabrication des fichiers à importer (sur l'hôte, avec node)
node ../scripts/prepare.mjs

# 2. Import dans le n8n du conteneur, avant de le démarrer
export COMPOSE_PROJECT_NAME="${COMPOSE_PROJECT_NAME:-contact-inbox}"
COMPOSE="docker compose --env-file $ENV_FILE"
$COMPOSE run --rm n8n import:credentials --input=/project/.build/credentials.json
$COMPOSE run --rm n8n import:workflow --input=/project/.build/contact-inbox.json
$COMPOSE run --rm n8n publish:workflow --id=ContactInbox0001

# 3. Démarrage
$COMPOSE up -d

echo
echo "Déployé. Page publique : https://$DOMAIN"
PORT="${EDITOR_PORT:-5678}"
echo "Éditeur n8n (tunnel SSH) : ssh -L $PORT:localhost:$PORT <user>@$DOMAIN puis http://localhost:$PORT"
