# Dépannage

Les erreurs ci dessous ont toutes été rencontrées pendant la mise au point du
projet. La cause indiquée est la vraie cause, pas une hypothèse.

## Les modifications ne sont pas prises en compte

n8n charge les workflows publiés **au démarrage**. Le message
« Please restart n8n for changes to take effect » le rappelle à chaque
importation.

Arrête n8n avec `Ctrl+C`, puis relance `./start.sh`.

## « You do not have permission to deactivate this workflow »

Apparaît en relançant `setup.sh` alors que le workflow est déjà publié. n8n
refuse d'écraser un workflow publié par une importation.

`setup.sh` dépublie automatiquement avant d'importer. Si tu importes à la main,
fais la même chose :

```bash
n8n unpublish:workflow --id=ContactInbox0001
n8n import:workflow --input=.build/contact-inbox.json
n8n publish:workflow --id=ContactInbox0001
```

## « Attempted to use Data table node but the module is disabled »

Les nœuds Data Table ne fonctionnent que dans un serveur n8n en cours
d'exécution. La commande `n8n execute` ne charge pas le module, et aucune
variable d'environnement n'y change quoi que ce soit.

C'est la raison pour laquelle la table est créée par le workflow lui même, au
premier message reçu. Si tu vois cette erreur, c'est que tu essaies de manipuler
une Data Table en ligne de commande : passe par un webhook ou par l'éditeur.

## « n8n Task Broker's port 5679 is already in use »

Une autre instance de n8n tourne déjà sur la machine. Le port 5679 n'est pas
celui de l'interface, mais celui du service qui exécute les nœuds Code.

Soit tu arrêtes l'autre instance, soit tu déplaces les deux ports :

```bash
N8N_PORT=5699 N8N_RUNNERS_BROKER_PORT=5690 ./start.sh
```

## Le webhook répond 404

Trois causes possibles, dans l'ordre de fréquence :

1. Le workflow n'est pas publié. Lance `./setup.sh`.
2. n8n n'a pas été redémarré depuis la publication.
3. L'adresse utilisée est en `/webhook-test/` au lieu de `/webhook/`. Les
   adresses d'essai ne répondent que lorsque l'éditeur est ouvert et en écoute.

Vérifie l'activation au démarrage :

```
Activated workflow "Contact Inbox API" (ID: ContactInbox0001)
```

## La lecture répond 403

Le jeton est absent, mal recopié, ou n'est plus celui de `.env`.

```bash
grep ^ADMIN_TOKEN= .env | cut -d= -f2
```

Si tu viens de changer `ADMIN_TOKEN`, il faut relancer `setup.sh` puis
redémarrer n8n : l'ancien jeton reste valable tant que l'identifiant n'est pas
réimporté.

## Le navigateur bloque les appels (CORS)

Message typique dans la console :

> Response to preflight request doesn't pass access control check: The
> 'Access-Control-Allow-Origin' header has a value 'http://localhost:8080' that
> is not equal to the supplied origin.

La page est servie depuis une origine absente de `ALLOWED_ORIGINS`. L'origine
comprend le protocole et le port : `http://localhost:8085` n'est pas
`http://localhost:8080`.

Corrige `ALLOWED_ORIGINS` dans `.env`, relance `setup.sh`, redémarre n8n.

En ligne de commande, curl n'est pas concerné : le CORS est une règle appliquée
par les navigateurs.

## La page affiche « n8n injoignable »

n8n ne tourne pas, ou pas sur le port attendu.

```bash
curl -sf http://localhost:5678/healthz && echo OK
```

La page appelle `http://localhost:5678` quand elle est servie sur le port 8080,
et le même domaine qu'elle dans tous les autres cas. Si tu changes le port de
n8n, adapte cette règle dans `frontend/index.html`.

## La boîte reste vide alors que des messages ont été envoyés

Regarde le filtre : si « Priorité haute » est actif, seuls les messages urgents
apparaissent. Sinon, vérifie directement la source :

```bash
curl http://localhost:5678/webhook/contacts -H "X-Admin-Token: $(grep ^ADMIN_TOKEN= .env | cut -d= -f2)"
```

Si l'API renvoie bien des messages, le problème est dans la page. Si elle
renvoie `{"count":0,...}`, regarde la table dans l'éditeur n8n, onglet
*Data tables*.

## Tous les envois répondent 429

La limite est de trois messages par adresse email sur dix minutes. Pendant des
tests répétés, elle est vite atteinte.

Utilise une adresse différente à chaque envoi, comme le fait `test.sh` avec
`alice+<horodatage>@example.com`, ou attends dix minutes. Republier le workflow
remet aussi les compteurs à zéro, puisqu'ils vivent dans les static data.

## n8n est tué par le système

Message du noyau ou arrêt brutal sans erreur dans les journaux n8n : la machine
manque de mémoire. n8n a besoin de quelques centaines de mégaoctets.

```bash
free -h
```

Ferme les applications gourmandes, ou ajoute de la mémoire au serveur.

## Erreurs de réseau dans les journaux au démarrage

```
Error fetching from Strapi API (https://api.n8n.io/api/mcp-servers): timeout of 6000ms exceeded
```

n8n tente de récupérer la liste des nœuds communautaires. Sans internet, ou
derrière un pare feu, l'appel échoue. C'est sans conséquence : le workflow
fonctionne normalement.

## Repartir de zéro

Les données de n8n en local sont dans `~/.n8n`. Supprimer ce dossier efface
**tout** : workflows, identifiants et messages enregistrés.

```bash
mv ~/.n8n ~/.n8n.sauvegarde
./setup.sh
./start.sh
```

Renommer plutôt que supprimer permet de revenir en arrière.
