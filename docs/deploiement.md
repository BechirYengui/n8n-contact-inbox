# Déploiement

Le dossier `deploy/` contient une pile Docker complète : n8n pour le workflow,
Caddy pour servir la page et obtenir un certificat HTTPS.

## Ce dont tu as besoin

* Un serveur accessible depuis internet, avec Docker et le plugin Compose.
* Un nom de domaine dont l'enregistrement A pointe vers l'adresse IP du serveur.
* Les ports 80 et 443 libres. Le port 80 est nécessaire pour la validation du
  certificat.
* Environ 1 Go de mémoire disponible pour n8n.

## Mise en ligne

```bash
git clone <ton-depot> contact-inbox    # ou copie du dossier
cd contact-inbox

cp .env.example .env
nano .env
```

Renseigne au minimum :

```bash
ADMIN_TOKEN=$(openssl rand -hex 24)   # à coller dans .env
DOMAIN=contact.mondomaine.com
```

Puis lance le déploiement :

```bash
./deploy/deploy.sh
```

Le script enchaîne les étapes suivantes :

1. Génère `N8N_ENCRYPTION_KEY` si elle est vide, et l'écrit dans `.env`.
2. Force `ALLOWED_ORIGINS` à `https://$DOMAIN`.
3. Prépare les fichiers à importer avec `scripts/prepare.mjs`.
4. Importe les identifiants et le workflow dans le n8n du conteneur, puis le
   publie.
5. Démarre les deux conteneurs.

Caddy demande son certificat au premier appel. Compte quelques secondes avant
que `https://ton-domaine.com` réponde.

## Ce qui est exposé

| Adresse | Accessible publiquement | Contenu |
|---|---|---|
| `https://ton-domaine.com/` | oui | La page |
| `https://ton-domaine.com/webhook/*` | oui | Les deux points d'entrée |
| `/rest/*` | non, 404 | API interne de n8n |
| `/webhook-test/*` | non, 404 | URL d'essai de l'éditeur |
| Éditeur n8n | non | Écoute sur `127.0.0.1` du serveur |

## Atteindre l'éditeur

L'éditeur n'est pas exposé. On y accède par un tunnel SSH depuis ton poste :

```bash
ssh -L 5678:localhost:5678 utilisateur@ton-serveur
```

Puis ouvre http://localhost:5678 dans ton navigateur. Le trafic passe dans le
tunnel chiffré, et rien n'est ouvert sur internet. Si tu as changé
`EDITOR_PORT`, utilise ce port des deux côtés.

Au premier accès, n8n demande de créer un compte propriétaire. Ce compte protège
l'éditeur, indépendamment du jeton admin qui protège la lecture des messages.

## Vérifier le déploiement

```bash
BASE=https://ton-domaine.com/webhook ./test.sh
```

Les neuf tests doivent passer. Vérifie aussi que l'éditeur n'est pas exposé :

```bash
curl -o /dev/null -w '%{http_code}\n' https://ton-domaine.com/rest/login   # 404 attendu
```

## Commandes utiles

Toutes se lancent depuis `deploy/`.

```bash
export COMPOSE_PROJECT_NAME=contact-inbox

docker compose --env-file ../.env logs -f n8n     # suivre les journaux
docker compose --env-file ../.env ps              # état des conteneurs
docker compose --env-file ../.env restart n8n     # redémarrer n8n
docker compose --env-file ../.env down            # tout arrêter
```

## Sauvegardes

Deux éléments, tous les deux indispensables.

| Élément | Contenu |
|---|---|
| `deploy/data/n8n/` | Base n8n : workflow, identifiants, messages de la Data Table |
| `N8N_ENCRYPTION_KEY` dans `.env` | Sans elle, les identifiants de la base sont illisibles |

Sauvegarde conteneurs arrêtés, pour éviter de copier une base en cours
d'écriture :

```bash
cd deploy
docker compose --env-file ../.env stop
tar czf ~/contact-inbox-$(date +%F).tar.gz data/n8n ../.env
docker compose --env-file ../.env start
```

## Modifier le workflow en production

```bash
nano workflows/contact-inbox.json     # ou modifie .env
./deploy/deploy.sh
```

Le script réimporte et republie, puis relance les conteneurs. Les messages déjà
enregistrés ne sont pas touchés : ils vivent dans la base, pas dans le workflow.
Les compteurs anti-spam, eux, repartent de zéro.

## Changer de version de n8n

La version est figée dans `deploy/docker-compose.yml`, à la ligne
`image: n8nio/n8n:2.39.5`. Figer la version évite qu'une mise à jour surprise
casse le workflow.

Pour monter de version : sauvegarde, change le numéro, puis

```bash
cd deploy
docker compose --env-file ../.env pull
docker compose --env-file ../.env up -d
```

Vérifie ensuite avec `./test.sh`.

## Tester la pile en local

C'est possible sans domaine, avec un certificat auto-signé :

```bash
# dans .env
DOMAIN=localhost
HTTP_PORT=8081
HTTPS_PORT=8444
EDITOR_PORT=5688      # si un n8n local occupe déjà 5678

./deploy/deploy.sh
curl -k https://localhost:8444/
```

L'option `-k` de curl accepte le certificat auto-signé que Caddy génère pour
`localhost`. Un navigateur affichera un avertissement, ce qui est normal dans ce
cas précis.
