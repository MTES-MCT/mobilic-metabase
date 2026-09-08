# Mobilic Metabase

Configuration et déploiement de l'instance [Metabase](https://www.metabase.com/) de Mobilic, hébergée sur [Scalingo](https://scalingo.com/), protégée par un proxy d'authentification et alimentée par une réplique analytique anonymisée de la production.

## À propos

Metabase sert les tableaux de bord analytiques de Mobilic. Ce dépôt ne contient pas Metabase lui-même (fourni par un buildpack) mais sa configuration de déploiement et son durcissement :

- **Isolation de la production** : Metabase n'interroge pas la base de production mais une copie rafraîchie chaque nuit, pour ne pas peser sur les performances de l'application.
- **Zéro donnée personnelle réelle** : cette copie est anonymisée (masquage statique) avant d'être exposée.
- **Accès protégé** : un proxy d'authentification (oauth2-proxy) filtre tout accès en amont de Metabase, en réponse à une faille de sécurité non authentifiée (CVE-2026-72898).

## Architecture

Trois applications Scalingo :

```
mobilic-api ────────── base de production (source des sauvegardes, jamais interrogée directement)
mobilic-metabase ───── Metabase derrière oauth2-proxy + cron de refresh nocturne   (ce dépôt)
mobilic-analytics ──── copie analytique anonymisée (addon PostgreSQL Dedicated)
```

Metabase se connecte à la copie de `mobilic-analytics`, pas à la production. Le cron de refresh vit sur `mobilic-metabase` et alimente la copie chaque nuit.

## Déploiement

Déploiement Scalingo par `git push` sur la branche `prod`.

- **Buildpacks** (multi-buildpack, versions pinnées par SHA) : `apt` (installe `postgresql-client`), `jvm-common` (JRE), `metabase-buildpack` (binaire Metabase).
- Le process `web` (`Procfile`) lance **oauth2-proxy** en frontal sur le port public, qui proxifie vers Metabase écoutant en local (`127.0.0.1`).
- oauth2-proxy est installé par `bin/install-oauth2-proxy` (version et checksum SHA256 figés).

## Variables d'environnement

Toutes posées côté Scalingo. **Aucune valeur secrète n'est commitée dans ce dépôt** : les secrets sont stockés dans le Vaultwarden beta.gouv.

| Variable | Rôle | Secret |
|----------|------|--------|
| `OAUTH2_PROXY_CLIENT_ID` | Client ID de l'OAuth App GitHub | non |
| `OAUTH2_PROXY_CLIENT_SECRET` | Client secret de l'OAuth App GitHub | oui |
| `OAUTH2_PROXY_COOKIE_SECRET` | Secret de cookie (générer : `openssl rand -base64 32`) | oui |
| `OAUTH2_PROXY_GITHUB_ORG` | Organisation GitHub autorisée (`MTES-MCT`) | non |
| `OAUTH2_PROXY_GITHUB_TEAM` | Équipe GitHub autorisée (`mobilic`) | non |
| `OAUTH2_PROXY_REDIRECT_URL` | URL de callback (`https://<host>/oauth2/callback`) | non |
| `MB_ENCRYPTION_SECRET_KEY` | Chiffre les secrets Metabase au repos (générer : `openssl rand -base64 32`) | oui |
| `SCALINGO_API_TOKEN` | Télécharge la sauvegarde de production (refresh) | oui |
| `ANALYTICS_DATABASE_URL` | URL admin de l'addon copie, jamais la base métadonnées (refresh) | oui |
| `METABASE_DB_USER` | Rôle read-only utilisé par Metabase sur la copie (refresh) | non |

## Sécurité

- **oauth2-proxy** : authentification GitHub restreinte à l'organisation `MTES-MCT` et à l'équipe `mobilic`, forcée sur **toutes** les routes (y compris les endpoints pré-auth). Metabase n'est joignable que via le proxy (bind `127.0.0.1`).
- **`MB_ENCRYPTION_SECRET_KEY`** : les secrets Metabase, dont les identifiants de la source de données, sont chiffrés au repos.
- **Addon Dedicated** pour la copie analytique : isolation réseau, firewall deny-by-default.

## Réplique analytique anonymisée

Un cron nocturne (Scalingo Scheduler) exécute `refresh_analytics_replica.sh` :

1. Coupe l'accès de Metabase à la copie (fail-closed).
2. Télécharge la dernière sauvegarde de production et la restaure dans la copie.
3. Applique le masquage (extension PostgreSQL [`anon`](https://postgresql-anonymizer.readthedocs.io/) + `masking_rules.sql`), puis vérifie qu'aucune colonne personnelle n'échappe aux règles.
4. Rouvre l'accès de Metabase, uniquement si toutes les étapes ont réussi.

Si le job échoue à n'importe quelle étape, l'accès reste coupé : une copie non masquée n'est jamais interrogeable.

## Structure du dépôt

| Chemin | Rôle |
|--------|------|
| `bin/start` | Démarre Metabase (port interne) puis oauth2-proxy (port public) |
| `bin/install-oauth2-proxy` | Installe le binaire oauth2-proxy (checksum vérifié) |
| `.buildpacks`, `Aptfile`, `Procfile`, `scalingo.json` | Configuration de build et de déploiement Scalingo |
| `cron.json` | Planification du refresh nocturne |
| `refresh_analytics_replica.sh`, `masking_rules.sql` | Job de réplique anonymisée |

## Licence

Voir le fichier [LICENSE](./LICENSE).
