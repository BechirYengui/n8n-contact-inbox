#!/usr/bin/env bash
# Teste l'API Contact Inbox : validation, anti-spam, stockage et accès protégé.
set -uo pipefail

cd "$(dirname "$0")"

BASE="${BASE:-http://localhost:5678/webhook}"
TOKEN="${ADMIN_TOKEN:-$(grep '^ADMIN_TOKEN=' .env | cut -d= -f2)}"
STAMP="$(date +%s)"

call() {
  echo "==> $1"
  shift
  curl -sS -w '\n    HTTP %{http_code}\n\n' "$@"
}

post() {
  call "$1" -X POST "$BASE/contact" -H 'Content-Type: application/json' -d "$2"
}

post "Message valide" \
  "{\"name\":\"Alice\",\"email\":\"alice+$STAMP@example.com\",\"message\":\"Bonjour, je voudrais un devis pour un site vitrine.\"}"

post "Message urgent (priorité haute)" \
  "{\"name\":\"Bob\",\"email\":\"bob+$STAMP@example.com\",\"message\":\"URGENT : notre serveur de production est down !\"}"

post "Message invalide (attendu 400)" \
  '{"name":"X","email":"pas-un-email","message":"court"}'

post "Robot : champ piège rempli (attendu 201, rien enregistré)" \
  "{\"name\":\"Spam Bot\",\"email\":\"bot+$STAMP@example.com\",\"message\":\"Achetez nos produits maintenant !\",\"website\":\"http://spam.example\"}"

echo "==> Limitation du débit : 4 envois avec la même adresse (le 4e doit renvoyer 429)"
for i in 1 2 3 4; do
  code=$(curl -sS -o /dev/null -w '%{http_code}' -X POST "$BASE/contact" \
    -H 'Content-Type: application/json' \
    -d "{\"name\":\"Flood\",\"email\":\"flood+$STAMP@example.com\",\"message\":\"Message numero $i pour tester la limite.\"}")
  echo "    envoi $i -> HTTP $code"
done
echo

call "Lecture sans jeton (attendu 403)" "$BASE/contacts"

call "Lecture avec jeton" "$BASE/contacts" -H "X-Admin-Token: $TOKEN"

call "Lecture, priorité haute uniquement" "$BASE/contacts?priority=high" -H "X-Admin-Token: $TOKEN"
