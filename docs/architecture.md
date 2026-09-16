# Architecture

Le workflow `Contact Inbox API` (identifiant `ContactInbox0001`) contient 16
nœuds répartis en trois pipelines. Chaque pipeline a son propre déclencheur.

## Pipeline 1 : réception d'un message

Déclenché par le visiteur du site. C'est le seul qui reçoit des données de
l'extérieur, donc le seul qui doit se méfier de ce qu'il reçoit.

| Nœud | Type | Rôle |
|---|---|---|
| `POST /contact` | Webhook | Ouvre l'URL publique. Le mode de réponse est « Respond to Webhook », donc la réponse est décidée plus loin dans le workflow |
| `Valider & Anti-spam` | Code | Nettoie, valide, compte, classe. Voir le détail ci-dessous |
| `Accepté ?` | IF | Aiguille selon la décision du nœud précédent |
| `À enregistrer ?` | IF | Sépare un message légitime d'un robot démasqué |
| `Créer la table si besoin` | Data Table | Crée `contact_submissions` si elle n'existe pas |
| `Enregistrer (Data Table)` | Data Table | Écrit la ligne et attribue l'identifiant et la date |
| `Respond 201 Created` | Respond | Renvoie `{ ok, id, priority }` |
| `Respond 201 (robot ignoré)` | Respond | Renvoie un faux succès au robot |
| `Respond 400 / 429` | Respond | Renvoie l'erreur, avec le code choisi par le nœud Code |

### Le nœud `Valider & Anti-spam` en détail

Ce nœud ne transmet pas le message tel quel : il transmet une **décision**, sous
la forme `{ action, status, ... }` où `action` vaut `store`, `ignore` ou
`reject`. Les nœuds suivants ne font qu'appliquer cette décision.

Il procède dans cet ordre, et s'arrête au premier verdict :

1. **Champ piège.** Si `website` est rempli, la décision est `ignore`. Aucune
   validation n'est faite, aucune donnée n'est conservée.
2. **Validation des champs.** Nom entre 2 et 100 caractères, email au format
   valide et jusqu'à 200 caractères, message entre 10 et 2000 caractères. Toutes
   les erreurs sont collectées, pas seulement la première, pour que le visiteur
   corrige tout en une fois. La décision est alors `reject` avec le code 400.
3. **Limitation du débit.** Les envois récents sont comptés par adresse email et
   par adresse IP sur une fenêtre glissante de 10 minutes. Au delà de 3 par
   email ou 10 par IP, la décision est `reject` avec le code 429.
4. **Classement.** Le message passe en priorité `high` s'il contient un des mots
   suivants : urgent, asap, down, broken, error, urgence, panne. Sinon
   `normal`. La décision est `store`.

Le nettoyage est fait avant tout le reste : espaces retirés en début et fin de
champ, email mis en minuscules. Deux visiteurs qui écrivent `Alice@Example.com`
et `alice@example.com` sont donc bien la même personne pour le compteur.

Les compteurs sont gardés dans les static data du workflow, limités aux 500
dernières entrées. C'est une mémoire interne à n8n, suffisante pour des
compteurs éphémères, mais inadaptée aux messages eux mêmes, qui vont en
Data Table.

## Pipeline 2 : notifications

Ce n'est pas un pipeline séparé : il prolonge le premier, **après** que le
visiteur a reçu sa réponse. Un nœud `Respond to Webhook` envoie la réponse HTTP
puis laisse le workflow continuer.

| Nœud | Type | Rôle |
|---|---|---|
| `Email au propriétaire` | Email | Envoie chaque message enregistré |
| `Priorité haute ?` | IF | Ne laisse passer que les messages urgents |
| `Alerte Telegram` | Telegram | Ping instantané pour les urgences |

Trois choix de conception :

* **Après la réponse**, pour que le visiteur n'attende jamais un serveur SMTP
  lent. Sa page répond en quelques centaines de millisecondes.
* **Désactivés par défaut.** `scripts/prepare.mjs` n'active un nœud que si les
  variables correspondantes sont remplies dans `.env`. Un nœud désactivé laisse
  passer les données sans rien faire.
* **Continuer en cas d'erreur.** Les deux nœuds utilisent
  `onError: continueRegularOutput`. Une panne d'email ou de Telegram ne remonte
  jamais jusqu'au visiteur et n'annule jamais l'enregistrement.

## Pipeline 3 : lecture de la boîte

Déclenché par le propriétaire. Il ne modifie rien.

| Nœud | Type | Rôle |
|---|---|---|
| `GET /contacts` | Webhook | Vérifie le jeton avant d'exécuter la suite |
| `Lire la Data Table` | Data Table | Lit toutes les lignes, les plus récentes d'abord |
| `Formater la liste` | Code | Applique le filtre, limite à 100, choisit les champs |
| `Respond avec la liste` | Respond | Renvoie `{ count, submissions }` |

L'authentification est portée par le nœud Webhook lui même, avec un identifiant
n8n de type « Header Auth ». Si le jeton est absent ou faux, n8n répond 403 et
**aucun nœud suivant ne s'exécute**. La vérification ne dépend donc pas du code
du workflow.

Le nœud de lecture a deux réglages qui évitent un blocage au premier démarrage :
`alwaysOutputData` et `onError: continueRegularOutput`. Tant qu'aucun message
n'est arrivé, la table n'existe pas encore : le nœud n'échoue pas, il ne renvoie
rien d'exploitable, et le nœud Code renvoie une liste vide.

## Le modèle de données

La Data Table `contact_submissions` contient quatre colonnes déclarées, plus
trois colonnes gérées par n8n.

| Colonne | Type | Origine |
|---|---|---|
| `name` | texte | Formulaire, nettoyé |
| `email` | texte | Formulaire, nettoyé et en minuscules |
| `message` | texte | Formulaire, nettoyé |
| `priority` | texte | Calculé : `high` ou `normal` |
| `id` | entier | n8n |
| `createdAt` | date | n8n, renvoyé sous le nom `receivedAt` par l'API |
| `updatedAt` | date | n8n |

L'adresse IP sert à compter les envois, mais n'est pas enregistrée avec le
message.

## Pourquoi la table est créée par le workflow

C'est la contrainte technique la plus importante du projet.

Les nœuds Data Table ne fonctionnent que dans un serveur n8n en cours
d'exécution. La commande `n8n execute` ne charge pas le module correspondant et
échoue avec le message « Attempted to use Data table node but the module is
disabled ». Il est donc impossible de préparer la table depuis un script
d'installation.

La solution retenue est le nœud `Créer la table si besoin`, avec l'option
« réutiliser les tables existantes ». Il s'exécute à chaque message, mais ne
crée réellement la table qu'une seule fois. Avantages : aucune étape manuelle,
aucun ordre à respecter entre installation et démarrage, et un déploiement
neuf qui fonctionne dès le premier message.

## Modifier le workflow

`workflows/contact-inbox.json` est la source de vérité. `scripts/prepare.mjs`
en produit une copie dans `.build/`, en y injectant les valeurs de `.env` :
origines autorisées, identifiants, activation des nœuds de notification. C'est
cette copie qui est importée dans n8n, jamais l'originale.

Pour une modification durable, édite le fichier source puis relance
`./setup.sh`. Pour une expérimentation rapide, modifie dans l'éditeur n8n, puis
reporte le résultat dans le fichier source, sinon le prochain `setup.sh`
écrasera tes changements.

Exporter ce que contient n8n :

```bash
n8n export:workflow --id=ContactInbox0001 --output=/tmp/export.json
```
