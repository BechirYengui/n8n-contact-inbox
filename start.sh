#!/usr/bin/env bash
# Démarre n8n pour ce projet, accessible uniquement depuis cette machine.
set -euo pipefail

export N8N_PORT="${N8N_PORT:-5678}"
export N8N_LISTEN_ADDRESS="${N8N_LISTEN_ADDRESS:-127.0.0.1}"
export N8N_HOST="${N8N_HOST:-localhost}"
export N8N_ENFORCE_SETTINGS_FILE_PERMISSIONS=true
export N8N_DIAGNOSTICS_ENABLED=false
export N8N_PERSONALIZATION_ENABLED=false
export N8N_VERSION_NOTIFICATIONS_ENABLED=false
# Sécurité : corps de requête limité à 1 Mo, pas d'accès aux variables
# d'environnement depuis les nœuds, pas de paquets communautaires non vérifiés.
export N8N_PAYLOAD_SIZE_MAX="${N8N_PAYLOAD_SIZE_MAX:-1}"
export N8N_BLOCK_ENV_ACCESS_IN_NODE=true
export N8N_UNVERIFIED_PACKAGES_ENABLED=false
export N8N_RUNNERS_TASK_TIMEOUT=60
export GENERIC_TIMEZONE="${GENERIC_TIMEZONE:-Europe/Paris}"

exec n8n start
