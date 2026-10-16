# Mobilic Metabase _(mobilic-metabase)_

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](./LICENSE)

Configuration et déploiement de l'instance Metabase pour la plateforme Mobilic.

[Metabase](https://www.metabase.com/) sert les tableaux de bord analytiques de Mobilic. Ce dépôt fournit sa configuration de déploiement sur [Scalingo](https://scalingo.com/) et son durcissement ; Metabase lui-même provient d'un buildpack.

## À propos

- **Isolation de la production** : Metabase interroge une copie rafraîchie chaque nuit, jamais la base de production.
- **Zéro donnée personnelle** : cette copie est anonymisée (masquage statique).
- **Accès restreint** : oauth2-proxy filtre tout accès en amont de Metabase.

## Réplique analytique anonymisée

Un cron nocturne (Scalingo Scheduler) rafraîchit la copie analytique depuis la dernière sauvegarde de production, applique un masquage (extension PostgreSQL [`anon`](https://postgresql-anonymizer.readthedocs.io/)), et ne rouvre l'accès de Metabase qu'en cas de succès. Sinon l'accès reste coupé.

## Déploiement

Déploiement Scalingo par `git push` sur la branche `prod`.

- Buildpacks (multi-buildpack, pinnés par SHA) : `apt` (`postgresql-client`), `jvm-common`, `metabase-buildpack`.
- Le process `web` (`Procfile`) lance oauth2-proxy sur le port public, qui proxifie vers Metabase en local (`127.0.0.1:3001`).
- oauth2-proxy est installé par `bin/install-oauth2-proxy` (version et checksum figés).
- Variables d'environnement posées côté Scalingo ; secrets dans le Vaultwarden beta.gouv, rien de commité.

## Usage

Metabase est accessible sur l'URL Scalingo de `mobilic-metabase`, derrière une double authentification.

## Licence

Sous licence [MIT](./LICENSE), © 2026 Fabrique numérique du Ministère de la Transition écologique.
