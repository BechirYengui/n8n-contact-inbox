// Lit .env et fabrique, dans .build/, les fichiers à importer dans n8n :
//   - credentials.json : jeton admin (+ Telegram / SMTP si configurés)
//   - contact-inbox.json : le workflow, avec les identifiants et les origines CORS
//   - storage-setup.json : le workflow qui crée la Data Table
import { readFileSync, writeFileSync, mkdirSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = dirname(dirname(fileURLToPath(import.meta.url)));
const build = join(root, '.build');
mkdirSync(build, { recursive: true });

// --- .env ------------------------------------------------------------------
const env = {};
for (const line of readFileSync(join(root, '.env'), 'utf8').split('\n')) {
  const match = /^\s*([A-Z0-9_]+)\s*=\s*(.*)\s*$/.exec(line);
  if (match) env[match[1]] = match[2].replace(/^["']|["']$/g, '').trim();
}

if (!env.ADMIN_TOKEN) {
  console.error('ADMIN_TOKEN est vide dans .env. Relance ./setup.sh');
  process.exit(1);
}

const CRED_ADMIN = 'contactInboxAdm1';
const CRED_TELEGRAM = 'contactInboxTel1';
const CRED_SMTP = 'contactInboxSmt1';

const telegramOn = Boolean(env.TELEGRAM_BOT_TOKEN && env.TELEGRAM_CHAT_ID);
const smtpOn = Boolean(env.SMTP_HOST && env.MAIL_FROM && env.MAIL_TO);

// --- identifiants ----------------------------------------------------------
const credentials = [
  {
    id: CRED_ADMIN,
    name: 'Contact Inbox (jeton admin)',
    type: 'httpHeaderAuth',
    data: { name: 'X-Admin-Token', value: env.ADMIN_TOKEN },
  },
];

if (telegramOn) {
  credentials.push({
    id: CRED_TELEGRAM,
    name: 'Contact Inbox (Telegram)',
    type: 'telegramApi',
    data: { accessToken: env.TELEGRAM_BOT_TOKEN, baseUrl: 'https://api.telegram.org' },
  });
}

if (smtpOn) {
  credentials.push({
    id: CRED_SMTP,
    name: 'Contact Inbox (SMTP)',
    type: 'smtp',
    data: {
      user: env.SMTP_USER || '',
      password: env.SMTP_PASSWORD || '',
      host: env.SMTP_HOST,
      port: Number(env.SMTP_PORT || 587),
      secure: String(env.SMTP_SECURE).toLowerCase() === 'true',
      disableStartTls: false,
    },
  });
}

writeFileSync(join(build, 'credentials.json'), JSON.stringify(credentials, null, 2));

// --- workflow --------------------------------------------------------------
const workflow = JSON.parse(readFileSync(join(root, 'workflows', 'contact-inbox.json'), 'utf8'));
const origins = env.ALLOWED_ORIGINS || 'http://localhost:8080';
const node = (name) => {
  const found = workflow.nodes.find((n) => n.name === name);
  if (!found) throw new Error(`Nœud introuvable dans le workflow : ${name}`);
  return found;
};

node('POST /contact').parameters.options.allowedOrigins = origins;

const getWebhook = node('GET /contacts');
getWebhook.parameters.options.allowedOrigins = origins;
getWebhook.credentials = { httpHeaderAuth: { id: CRED_ADMIN, name: 'Contact Inbox (jeton admin)' } };

const telegram = node('Alerte Telegram');
if (telegramOn) {
  telegram.disabled = false;
  telegram.parameters.chatId = env.TELEGRAM_CHAT_ID;
  telegram.credentials = { telegramApi: { id: CRED_TELEGRAM, name: 'Contact Inbox (Telegram)' } };
}

const email = node('Email au propriétaire');
if (smtpOn) {
  email.disabled = false;
  email.parameters.fromEmail = env.MAIL_FROM;
  email.parameters.toEmail = env.MAIL_TO;
  email.credentials = { smtp: { id: CRED_SMTP, name: 'Contact Inbox (SMTP)' } };
}

writeFileSync(join(build, 'contact-inbox.json'), JSON.stringify(workflow, null, 2));

console.log(`Origines autorisées : ${origins}`);
console.log(`Notifications Telegram : ${telegramOn ? 'activées' : 'désactivées (nœud désactivé)'}`);
console.log(`Notifications email    : ${smtpOn ? 'activées' : 'désactivées (nœud désactivé)'}`);
