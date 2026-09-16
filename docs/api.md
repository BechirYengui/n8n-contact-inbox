# Référence de l'API

Deux points d'entrée, tous deux servis par n8n.

| Environnement | Adresse de base |
|---|---|
| Local | `http://localhost:5678/webhook` |
| Production | `https://ton-domaine.com/webhook` |

Les adresses en `/webhook-test/` visibles dans l'éditeur n8n servent uniquement
aux essais manuels, quand l'éditeur est ouvert et en écoute. Les URL utilisées
par le site et par la page de démonstration sont celles en `/webhook/`.

## POST /contact

Point d'entrée public. Reçoit un message de formulaire.

### Requête

En-tête : `Content-Type: application/json`

| Champ | Type | Contrainte |
|---|---|---|
| `name` | texte | 2 à 100 caractères |
| `email` | texte | format valide, 200 caractères au plus |
| `message` | texte | 10 à 2000 caractères |
| `website` | texte | champ piège, doit rester vide |

```bash
curl -X POST http://localhost:5678/webhook/contact \
  -H 'Content-Type: application/json' \
  -d '{"name":"Alice","email":"alice@example.com","message":"Bonjour, je voudrais un devis."}'
```

### Réponses

| Code | Corps | Signification |
|---|---|---|
| 201 | `{"ok":true,"id":7,"priority":"high"}` | Message enregistré |
| 201 | `{"ok":true,"id":"ignored"}` | Champ piège rempli. Le message est jeté |
| 400 | `{"ok":false,"errors":[...]}` | Un ou plusieurs champs invalides |
| 429 | `{"ok":false,"errors":["too many messages, try again later"]}` | Limite de débit atteinte |

L'identifiant `"ignored"` est la seule façon de distinguer un robot d'un vrai
message côté client. Ce choix est volontaire : un robot ne doit pas apprendre
qu'il a été repéré, mais la page de démonstration, elle, veut l'afficher.

### Catalogue des erreurs 400

Les messages sont renvoyés en anglais par le workflow. La page les traduit pour
l'affichage.

| Message | Cause |
|---|---|
| `name must be at least 2 characters` | Nom trop court |
| `name must be at most 100 characters` | Nom trop long |
| `email is not valid` | Format d'email refusé |
| `email must be at most 200 characters` | Email trop long |
| `message must be at least 10 characters` | Message trop court |
| `message must be at most 2000 characters` | Message trop long |

Toutes les erreurs détectées sont renvoyées ensemble, pas une par une.

### Priorité

La priorité vaut `high` si le message contient, sans tenir compte de la casse,
un de ces mots : `urgent`, `asap`, `down`, `broken`, `error`, `urgence`,
`panne`. Sinon `normal`.

### Limitation du débit

Trois messages par adresse email et dix par adresse IP, sur une fenêtre
glissante de dix minutes. Au delà, la réponse est 429 et rien n'est enregistré.

## GET /contacts

Point d'entrée protégé. Renvoie les messages enregistrés.

### Requête

En-tête obligatoire : `X-Admin-Token: <ADMIN_TOKEN>`

| Paramètre | Valeurs | Effet |
|---|---|---|
| `priority` | `high` ou `normal` | Ne renvoie que les messages de cette priorité |

```bash
TOKEN=$(grep ^ADMIN_TOKEN= .env | cut -d= -f2)

curl http://localhost:5678/webhook/contacts -H "X-Admin-Token: $TOKEN"
curl "http://localhost:5678/webhook/contacts?priority=high" -H "X-Admin-Token: $TOKEN"
```

### Réponses

| Code | Corps | Signification |
|---|---|---|
| 200 | `{"count":2,"submissions":[...]}` | Liste renvoyée |
| 403 | `Authorization data is wrong!` | Jeton absent ou faux |

Les messages sont triés du plus récent au plus ancien, et limités à 100.

```json
{
  "count": 1,
  "submissions": [
    {
      "id": 7,
      "name": "Bob Durand",
      "email": "bob@example.com",
      "message": "URGENT : notre serveur de production est down.",
      "priority": "high",
      "receivedAt": "2026-09-16T00:35:02.000Z"
    }
  ]
}
```

La réponse 403 est produite par n8n avant l'exécution du workflow. Son corps est
du texte, pas du JSON.

## Appels depuis un navigateur

Les deux points d'entrée renvoient des en-têtes CORS. Seule l'origine déclarée
dans `ALLOWED_ORIGINS` est acceptée par le navigateur. Une page servie depuis
une autre origine reçoit bien une réponse du serveur, mais le navigateur la
bloque avant de la transmettre au code JavaScript.

Pour autoriser plusieurs origines, sépare les par des virgules :

```bash
ALLOWED_ORIGINS=http://localhost:8080,https://contact.mondomaine.com
```

En production, la page et les webhooks sont servis par le même domaine. Les
appels sont donc de même origine et ne déclenchent aucun contrôle CORS.

## Intégrer le formulaire à un site existant

Aucune bibliothèque n'est nécessaire.

```html
<form id="contact">
  <input name="name" required>
  <input name="email" type="email" required>
  <textarea name="message" required></textarea>
  <input name="website" style="display:none" tabindex="-1" autocomplete="off">
  <button>Envoyer</button>
</form>

<script>
document.getElementById('contact').addEventListener('submit', async (event) => {
  event.preventDefault();
  const body = Object.fromEntries(new FormData(event.target));
  const response = await fetch('https://ton-domaine.com/webhook/contact', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  });
  const data = await response.json();
  console.log(response.status, data);
});
</script>
```

Le champ `website` doit être présent et invisible. C'est lui qui piège les
robots. Ne mets jamais le jeton admin dans une page publique : il ne sert qu'à
la lecture de la boîte.
