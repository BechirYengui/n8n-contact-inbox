# Contact Inbox

Un backend de formulaire de contact construit entièrement dans n8n, sans écrire
de serveur. Il reçoit les messages d'un site web, les valide, écarte les robots,
les enregistre, prévient le propriétaire, et expose une boîte de réception
protégée par jeton.

Le projet sert deux objectifs : comprendre n8n en le voyant fonctionner, et
disposer d'une base réellement utilisable en production.

## Ce que le projet contient

* Un workflow n8n de 16 nœuds, avec trois pipelines indépendants.
* Une page web de démonstration qui montre, à chaque appel, le chemin suivi dans
  le workflow et le détail des échanges HTTP.
* Un stockage persistant dans une Data Table n8n.
* Deux canaux de notification optionnels : email et Telegram.
* Quatre protections contre les abus : jeton, champ piège, limitation du débit,
  tailles plafonnées.
* Une pile Docker prête à déployer, avec HTTPS automatique.

## Démarrage rapide

```bash
cd ~/n8n-contact-inbox
./setup.sh      # n8n doit être arrêté. Crée .env, importe et publie le workflow
./start.sh      # terminal 1 : n8n sur http://localhost:5678
./frontend.sh   # terminal 2 : la page sur http://localhost:8080
```

Ouvre ensuite http://localhost:8080. La page demande le **jeton admin** pour
afficher la boîte de réception. `setup.sh` l'affiche à la fin, et tu peux le
relire à tout moment :

```bash
grep ^ADMIN_TOKEN= .env | cut -d= -f2
```

Deux règles à retenir :

1. n8n doit être **arrêté** pendant `setup.sh`, et **redémarré** après. Les
   modifications ne sont prises en compte qu'au démarrage.
2. `setup.sh` se relance autant de fois que nécessaire. Il dépublie le workflow
   avant de le réimporter, car n8n refuse d'écraser un workflow publié.

## Comment ça marche

Trois pipelines, déclenchés par trois événements différents. Ils ne communiquent
jamais directement : leur seul point de rencontre est la Data Table.

```
1. Réception d'un message (déclenché par le visiteur)

POST /contact
  → Valider & Anti-spam
    → Accepté ?
      oui → À enregistrer ?
              oui → Créer la table si besoin → Enregistrer → 201 Created
              non → 201 ignoré          (robot démasqué, rien n'est stocké)
      non → 400 (champs invalides) ou 429 (trop de messages)

2. Notifications (prolonge le pipeline 1, après la réponse au visiteur)

201 Created → Email au propriétaire → Priorité haute ? → oui → Alerte Telegram

3. Lecture de la boîte (déclenché par le propriétaire, jeton exigé)

GET /contacts → Lire la Data Table → Formater la liste → 200 { count, submissions }
```

Le détail nœud par nœud, et les raisons de chaque choix, sont dans
[docs/architecture.md](docs/architecture.md).

## Documentation

| Document | Contenu |
|---|---|
| [docs/architecture.md](docs/architecture.md) | Les trois pipelines nœud par nœud, le modèle de données, les décisions de conception |
| [docs/api.md](docs/api.md) | Référence HTTP complète : requêtes, réponses, codes, exemples curl |
| [docs/configuration.md](docs/configuration.md) | Chaque variable de `.env`, comment obtenir un jeton Telegram ou un accès SMTP |
| [docs/securite.md](docs/securite.md) | Les protections en place, ce qu'elles couvrent et ce qu'elles ne couvrent pas |
| [docs/deploiement.md](docs/deploiement.md) | Mise en ligne avec Docker et Caddy, sauvegardes, mises à jour |
| [docs/depannage.md](docs/depannage.md) | Les erreurs fréquentes et leur cause exacte |

## Les fichiers

| Fichier | Rôle |
|---|---|
| `workflows/contact-inbox.json` | Le workflow n8n, source de vérité du projet |
| `scripts/prepare.mjs` | Injecte les valeurs de `.env` dans le workflow et les identifiants |
| `setup.sh` | Dépublie, importe, publie. À lancer n8n arrêté |
| `start.sh` | Démarre n8n en local, à l'écoute de `127.0.0.1` uniquement |
| `frontend/index.html` | La page de démonstration, sans dépendance externe |
| `frontend.sh` | Sert la page sur le port 8080 |
| `test.sh` | Neuf tests en ligne de commande, anti-spam compris |
| `deploy/` | `docker-compose.yml`, `Caddyfile` et `deploy.sh` pour la mise en ligne |
| `.env` | Tes secrets et ta configuration. Jamais versionné |
| `.env.example` | Le modèle commenté de `.env` |
| `.build/` | Fichiers générés par `prepare.mjs`. Jamais versionné |

## Tests

```bash
./test.sh
```

Le script couvre neuf cas : message valide, message urgent classé en priorité
haute, message invalide (400), robot ignoré (201 sans enregistrement), quatre
envois successifs dont le dernier dépasse la limite (429), lecture sans jeton
(403), lecture avec jeton (200), et filtre par priorité.

La variable `BASE` permet de viser une autre instance :

```bash
BASE=https://contact.mondomaine.com/webhook ./test.sh
```

## Limites connues

* Les notifications sont câblées mais leur livraison réelle dépend de tes
  identifiants. Tant que `.env` est vide, les deux nœuds restent désactivés.
* La limitation par adresse IP suppose un proxy qui transmet l'adresse du
  visiteur, comme Caddy en production. En local, tous les appels comptent pour
  une seule adresse.
* Les compteurs anti-spam vivent dans les static data du workflow. Ils sont
  remis à zéro si tu republies le workflow.
* La lecture renvoie au maximum 100 messages, sans pagination.

## Pour aller plus loin

* Envoyer un email de confirmation au visiteur.
* Créer une tâche dans Notion, Trello ou un CRM à partir de chaque message.
* Classer les messages par sujet avec un nœud IA, puis router vers la bonne
  équipe.
* Ajouter un export CSV des messages, protégé par le même jeton.
