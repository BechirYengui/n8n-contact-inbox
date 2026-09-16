# Configuration

Toute la configuration tient dans le fichier `.env`, à la racine du projet.
`setup.sh` le crée à partir de `.env.example` au premier lancement, avec un
jeton admin aléatoire.

Après chaque modification de `.env` :

```bash
./setup.sh      # n8n arrêté
./start.sh
```

`scripts/prepare.mjs` relit alors `.env` et régénère le workflow et les
identifiants dans `.build/`.

## Sécurité

### `ADMIN_TOKEN`

Le jeton exigé par `GET /webhook/contacts`, dans l'en-tête `X-Admin-Token`.
Généré automatiquement avec `openssl rand -hex 24`, soit 48 caractères
hexadécimaux.

Il est importé dans n8n comme identifiant « Header Auth » et y est chiffré. Pour
le changer, remplace sa valeur dans `.env` et relance `setup.sh`.

### `ALLOWED_ORIGINS`

Les origines autorisées à appeler les webhooks depuis un navigateur, séparées
par des virgules, sans espace.

| Situation | Valeur |
|---|---|
| Développement local | `http://localhost:8080` |
| Production | `https://contact.mondomaine.com` |
| Les deux | `http://localhost:8080,https://contact.mondomaine.com` |

L'origine comprend le protocole et le port. `http://localhost:8080` et
`http://localhost:8085` sont deux origines différentes.

`deploy/deploy.sh` force cette variable à `https://$DOMAIN` au moment du
déploiement.

## Notifications Telegram

| Variable | Description |
|---|---|
| `TELEGRAM_BOT_TOKEN` | Le jeton du bot |
| `TELEGRAM_CHAT_ID` | L'identifiant du destinataire |

Les deux doivent être remplis, sinon le nœud reste désactivé.

Pour les obtenir :

1. Sur Telegram, écris à [@BotFather](https://t.me/BotFather), envoie
   `/newbot` et suis les instructions. Il répond avec un jeton de la forme
   `123456789:AAF...`.
2. Écris à [@userinfobot](https://t.me/userinfobot). Il répond avec ton
   identifiant numérique, qui est ton `TELEGRAM_CHAT_ID`.
3. Envoie un premier message à ton bot. Un bot ne peut pas écrire à quelqu'un
   qui ne lui a jamais parlé.

Le bot ne reçoit une alerte que pour les messages de priorité haute.

## Notifications par email

| Variable | Description | Exemple |
|---|---|---|
| `SMTP_HOST` | Serveur d'envoi | `smtp.gmail.com` |
| `SMTP_PORT` | Port | `587` |
| `SMTP_USER` | Identifiant | `toi@gmail.com` |
| `SMTP_PASSWORD` | Mot de passe | mot de passe d'application |
| `SMTP_SECURE` | TLS direct | `false` pour le port 587, `true` pour le port 465 |
| `MAIL_FROM` | Expéditeur affiché | `contact@mondomaine.com` |
| `MAIL_TO` | Destinataire des messages | `toi@gmail.com` |

`SMTP_HOST`, `MAIL_FROM` et `MAIL_TO` doivent être remplis, sinon le nœud reste
désactivé.

Avec Gmail, ton mot de passe habituel ne fonctionne pas. Active la validation en
deux étapes sur ton compte Google, puis crée un **mot de passe d'application**
et utilise celui là. Il ne donne accès qu'à l'envoi d'emails et se révoque
indépendamment.

Un email part pour chaque message enregistré, pas seulement pour les urgents.

## Déploiement

| Variable | Description | Défaut |
|---|---|---|
| `DOMAIN` | Le domaine public, qui doit pointer vers le serveur | aucun |
| `N8N_ENCRYPTION_KEY` | Clé de chiffrement des identifiants n8n | générée au premier déploiement |
| `EDITOR_PORT` | Port local du serveur pour atteindre l'éditeur par tunnel SSH | `5678` |
| `HTTP_PORT` | Port public en clair, utilisé pour la redirection et les certificats | `80` |
| `HTTPS_PORT` | Port public en HTTPS | `443` |

`N8N_ENCRYPTION_KEY` est critique : sans elle, les identifiants enregistrés dans
la base n8n deviennent illisibles. Sauvegarde la en même temps que les données.

## Variables d'environnement de n8n

Elles ne sont pas dans `.env` mais dans `start.sh` pour le local, et dans
`deploy/docker-compose.yml` pour la production.

| Variable | Valeur | Raison |
|---|---|---|
| `N8N_LISTEN_ADDRESS` | `127.0.0.1` | En local, n8n n'est joignable que depuis la machine |
| `N8N_PAYLOAD_SIZE_MAX` | `1` | Corps de requête limité à 1 Mo |
| `N8N_BLOCK_ENV_ACCESS_IN_NODE` | `true` | Un nœud Code ne peut pas lire les variables d'environnement |
| `N8N_UNVERIFIED_PACKAGES_ENABLED` | `false` | Pas d'installation de paquets communautaires non vérifiés |
| `N8N_RUNNERS_TASK_TIMEOUT` | `60` | Un nœud Code bloqué est interrompu au bout d'une minute |
| `N8N_DIAGNOSTICS_ENABLED` | `false` | Pas de télémétrie |
| `N8N_PROXY_HOPS` | `1` | En production, n8n fait confiance à l'adresse transmise par Caddy |
| `GENERIC_TIMEZONE` | `Europe/Paris` | Fuseau utilisé par les nœuds |

Pour lancer n8n sur un autre port en local :

```bash
N8N_PORT=5680 ./start.sh
FRONTEND_PORT=8090 ./frontend.sh
```

Si tu changes le port de la page, mets `ALLOWED_ORIGINS` à jour, sinon le
navigateur bloquera ses appels.

## Adresse de l'API vue par la page

La page choisit seule l'adresse des webhooks :

| Situation | Adresse utilisée |
|---|---|
| Servie sur le port 8080 en local | `http://localhost:5678/webhook` |
| Servie par Caddy en production | `/webhook`, sur le même domaine |

Pour viser une autre instance pendant un test, ajoute `?api=` à l'adresse de la
page :

```
http://localhost:8085/?api=http://localhost:5699/webhook
```

Ce paramètre n'est accepté que si la page est ouverte depuis `localhost`. En
production il est ignoré, pour qu'un lien piégé ne puisse pas faire dialoguer la
page avec un serveur tiers et récupérer un jeton saisi par erreur.
