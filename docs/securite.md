# Sécurité

Le projet part d'un principe simple : `POST /contact` est ouvert à tout
internet, donc tout ce qui en vient est suspect, et `GET /contacts` expose des
données personnelles, donc il doit être fermé.

## Ce qui protège la lecture

La lecture des messages exige l'en-tête `X-Admin-Token`. Le contrôle est fait
par le nœud Webhook lui même, à l'aide d'un identifiant n8n de type
« Header Auth ». Deux conséquences utiles :

* Le jeton est chiffré dans la base n8n, pas écrit dans le workflow.
* Un jeton absent ou faux donne un 403 immédiat, **avant** l'exécution du
  moindre nœud. Aucune donnée n'est lue, aucune exécution n'est enregistrée.

Le jeton fait 48 caractères hexadécimaux tirés au hasard. La page de
démonstration le garde dans le `sessionStorage` de l'onglet, jamais dans un
cookie ni dans l'URL, et ne l'affiche jamais dans son journal des appels.

## Ce qui protège l'écriture

### Champ piège

Le formulaire contient un champ `website` invisible pour un humain, placé hors
de l'écran et retiré de la navigation au clavier. Un robot qui remplit
automatiquement tous les champs le remplit aussi.

Dans ce cas le message reçoit un 201 normal, mais n'est jamais enregistré. Le
robot repart avec l'impression d'avoir réussi, ce qui évite qu'il adapte sa
méthode.

### Limitation du débit

Trois messages par adresse email et dix par adresse IP sur dix minutes
glissantes. Au delà, réponse 429.

Les compteurs sont gardés dans les static data du workflow, limités aux 500
dernières entrées pour que la mémoire n'enfle pas.

Le compteur par IP suppose un proxy de confiance qui transmet l'adresse du
visiteur dans `X-Forwarded-For`, ce que fait Caddy en production. En local, tous
les appels partagent la même valeur.

### Tailles plafonnées

| Élément | Limite |
|---|---|
| Nom | 100 caractères |
| Email | 200 caractères |
| Message | 2000 caractères |
| Corps de la requête | 1 Mo |

Le plafond global vient de `N8N_PAYLOAD_SIZE_MAX` et s'applique avant même que
le workflow démarre.

### Validation stricte

Le workflow ne fait jamais confiance au navigateur : la page n'effectue aucune
validation, tout est contrôlé côté serveur. Les champs sont nettoyés, l'email
est mis en minuscules, et seules les quatre valeurs attendues sont écrites en
base. Un champ supplémentaire envoyé par un client malveillant est ignoré.

## Ce qui protège la surface exposée

* **En local**, n8n n'écoute que sur `127.0.0.1`. Aucune autre machine du réseau
  ne peut l'atteindre.
* **En production**, Caddy ne laisse passer que la page et `/webhook/*`.
  L'éditeur n8n, ses API internes `/rest/*` et les URL d'essai
  `/webhook-test/*` répondent 404 depuis l'extérieur.
* **L'éditeur** n'est joignable que depuis le serveur lui même, par tunnel SSH.
* **HTTPS** est obtenu et renouvelé automatiquement par Caddy.
* **Les en-têtes** `X-Content-Type-Options`, `X-Frame-Options` et
  `Referrer-Policy` sont envoyés avec chaque page.

## CORS

`ALLOWED_ORIGINS` limite les origines autorisées à appeler les webhooks depuis
un navigateur. Si l'origine ne correspond pas, le navigateur refuse la réponse.

Cette protection vise les autres sites web, pas les robots : un script en ligne
de commande n'est pas soumis au CORS. Elle empêche qu'une page tierce fasse
appeler ton API par le navigateur de tes visiteurs, mais elle ne remplace ni le
jeton ni la limitation du débit.

## Ce qui n'est pas couvert

* **Le contenu des messages n'est pas filtré.** Un message peut contenir du
  texte indésirable ou des liens. La page les affiche comme du texte, jamais
  comme du HTML, donc il n'y a pas d'injection possible dans le navigateur, mais
  aucun classement anti spam n'est fait sur le fond.
* **L'email n'est pas vérifié.** Personne ne confirme qu'il appartient à
  l'expéditeur. Pour cela, il faudrait envoyer un lien de confirmation.
* **Pas de CAPTCHA.** Le champ piège arrête les robots simples, pas un attaquant
  déterminé. Un service comme Turnstile ou hCaptcha se brancherait avant le nœud
  d'enregistrement.
* **Pas de chiffrement des messages au repos.** Ils sont lisibles par qui a
  accès au serveur et à la base n8n.
* **Un seul jeton, partagé.** Il n'y a ni comptes, ni rôles, ni journal des
  lectures. Pour révoquer l'accès, il faut changer le jeton.
* **Pas de sauvegarde automatique.** Voir [deploiement.md](deploiement.md).

## Si un jeton fuit

1. Remplace `ADMIN_TOKEN` dans `.env`.
2. Arrête n8n, lance `./setup.sh`, redémarre n8n.
3. L'ancien jeton est refusé immédiatement, y compris dans les onglets encore
   ouverts.

## Données personnelles

Le projet conserve un nom, un email et un message, c'est à dire des données
personnelles. Si tu le mets en ligne pour un usage réel, préviens tes visiteurs
de ce que tu collectes et de la durée de conservation, et prévois une façon de
supprimer un message sur demande. La suppression se fait pour l'instant à la
main, dans l'onglet *Data tables* de l'éditeur n8n.
