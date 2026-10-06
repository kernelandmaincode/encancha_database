-- =============================================================
-- EnCancha — Esquema de Base de Datos MySQL
-- Base de datos: leaguesp_encancha
-- Versión: 1.0.0
-- Fase: 3 — Construcción inicial (diseño: ENCANCHA_PHASE2_DESIGN.md)
-- BUILD LIMPIO: empieza con DROP TABLE. Nunca ejecutar sobre una base
-- con datos reales; para eso están migrations/NNN_*.sql.
-- Migraciones incluidas:
--   001 — schema inicial (42 tablas; con 004 son 43)
--   002 — seed de catálogos (sports, event_types, packages)
--   003 — seed de config global
--   004 — acceso de jugadores: invitations, roster 'requested', interruptor de registro libre
--   005 — columnas del API: pending_changes (players, tournament_rosters), payments.metadata
-- =============================================================

SET NAMES utf8mb4;
SET FOREIGN_KEY_CHECKS = 0;

-- -------------------------------------------------------------
-- DROP (FOREIGN_KEY_CHECKS=0, el orden no importa)
-- -------------------------------------------------------------
DROP TABLE IF EXISTS `invitations`;
DROP TABLE IF EXISTS `config`;
DROP TABLE IF EXISTS `shared_cards`;
DROP TABLE IF EXISTS `notification_preferences`;
DROP TABLE IF EXISTS `notifications`;
DROP TABLE IF EXISTS `payments`;
DROP TABLE IF EXISTS `internal_charges`;
DROP TABLE IF EXISTS `team_subscriptions`;
DROP TABLE IF EXISTS `match_claims`;
DROP TABLE IF EXISTS `match_signatures`;
DROP TABLE IF EXISTS `match_media`;
DROP TABLE IF EXISTS `league_player_bans`;
DROP TABLE IF EXISTS `player_suspensions`;
DROP TABLE IF EXISTS `attendance_confirmations`;
DROP TABLE IF EXISTS `identity_verifications`;
DROP TABLE IF EXISTS `match_events`;
DROP TABLE IF EXISTS `match_lineups`;
DROP TABLE IF EXISTS `match_periods`;
DROP TABLE IF EXISTS `matches`;
DROP TABLE IF EXISTS `bracket_nodes`;
DROP TABLE IF EXISTS `brackets`;
DROP TABLE IF EXISTS `roster_transfers`;
DROP TABLE IF EXISTS `tournament_rosters`;
DROP TABLE IF EXISTS `tournament_teams`;
DROP TABLE IF EXISTS `players`;
DROP TABLE IF EXISTS `team_managers`;
DROP TABLE IF EXISTS `teams`;
DROP TABLE IF EXISTS `tournament_groups`;
DROP TABLE IF EXISTS `tournaments`;
DROP TABLE IF EXISTS `fields`;
DROP TABLE IF EXISTS `venues`;
DROP TABLE IF EXISTS `league_referees`;
DROP TABLE IF EXISTS `referees`;
DROP TABLE IF EXISTS `league_followers`;
DROP TABLE IF EXISTS `league_admins`;
DROP TABLE IF EXISTS `leagues`;
DROP TABLE IF EXISTS `event_types`;
DROP TABLE IF EXISTS `sports`;
DROP TABLE IF EXISTS `subscription_events`;
DROP TABLE IF EXISTS `account_subscriptions`;
DROP TABLE IF EXISTS `packages`;
DROP TABLE IF EXISTS `accounts`;
DROP TABLE IF EXISTS `device_tokens`;
DROP TABLE IF EXISTS `auth_tokens`;
DROP TABLE IF EXISTS `users`;

-- =============================================================
-- 1. IDENTIDAD Y ACCESO
-- =============================================================

-- users: toda persona que inicia sesión. Los roles NO viven aquí (D2):
-- se derivan de league_admins / team_managers / referees / players.
CREATE TABLE IF NOT EXISTS `users` (
    `id`                BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `full_name`         VARCHAR(150)    NOT NULL,
    `email`             VARCHAR(190)    NULL,
    `phone`             VARCHAR(30)     NULL,
    `password_hash`     VARCHAR(255)    NULL,
    `google_sub`        VARCHAR(64)     NULL,
    `avatar_url`        VARCHAR(500)    NULL,
    `is_platform_admin` TINYINT(1)      NOT NULL DEFAULT 0,
    `status`            ENUM('active','disabled') NOT NULL DEFAULT 'active',
    `last_login_at`     DATETIME        NULL,
    `created_at`        DATETIME DEFAULT CURRENT_TIMESTAMP,
    `updated_at`        DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uq_users_email` (`email`),
    UNIQUE KEY `uq_users_phone` (`phone`),
    UNIQUE KEY `uq_users_google_sub` (`google_sub`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- auth_tokens: se guarda el SHA-256 del token, nunca el token.
CREATE TABLE IF NOT EXISTS `auth_tokens` (
    `id`                 BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `user_id`            BIGINT UNSIGNED NOT NULL,
    `access_token_hash`  CHAR(64)     NOT NULL,
    `refresh_token_hash` CHAR(64)     NOT NULL,
    `device_id`          VARCHAR(100) NULL,
    `expires_at`         DATETIME     NOT NULL,
    `refresh_expires_at` DATETIME     NOT NULL,
    `revoked_at`         DATETIME     NULL,
    `created_at`         DATETIME DEFAULT CURRENT_TIMESTAMP,
    `updated_at`         DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uq_auth_tokens_access` (`access_token_hash`),
    UNIQUE KEY `uq_auth_tokens_refresh` (`refresh_token_hash`),
    KEY `idx_auth_tokens_user` (`user_id`),
    CONSTRAINT `fk_auth_tokens_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- device_tokens: destino de las notificaciones push (FCM).
CREATE TABLE IF NOT EXISTS `device_tokens` (
    `id`           BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `user_id`      BIGINT UNSIGNED NOT NULL,
    `token`        VARCHAR(255) NOT NULL,
    `platform`     ENUM('ios','android','web') NOT NULL,
    `last_seen_at` DATETIME NULL,
    `created_at`   DATETIME DEFAULT CURRENT_TIMESTAMP,
    `updated_at`   DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uq_device_tokens_token` (`token`),
    KEY `idx_device_tokens_user` (`user_id`),
    CONSTRAINT `fk_device_tokens_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =============================================================
-- 2. CUENTAS, PAQUETES Y SUSCRIPCIÓN (D11, D13, D14)
-- =============================================================

-- accounts: la cuenta del cliente, dueña de N ligas y de la suscripción.
-- ads_enabled solo lo cambia el super admin (D6).
CREATE TABLE IF NOT EXISTS `accounts` (
    `id`            BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `owner_user_id` BIGINT UNSIGNED NOT NULL,
    `name`          VARCHAR(150)    NOT NULL,
    `ads_enabled`   TINYINT(1)      NOT NULL DEFAULT 0,
    `status`        ENUM('active','suspended') NOT NULL DEFAULT 'active',
    `created_at`    DATETIME DEFAULT CURRENT_TIMESTAMP,
    `updated_at`    DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_accounts_owner` (`owner_user_id`),
    CONSTRAINT `fk_accounts_owner` FOREIGN KEY (`owner_user_id`) REFERENCES `users` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- packages: catálogo de paquetes de pago. No existe paquete gratuito (D13).
CREATE TABLE IF NOT EXISTS `packages` (
    `id`                         BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `code`                       VARCHAR(30)   NOT NULL,
    `name`                       VARCHAR(100)  NOT NULL,
    `max_leagues`                INT UNSIGNED  NOT NULL,
    `max_tournaments_per_league` INT UNSIGNED  NOT NULL,
    `price_monthly`              DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    `price_yearly`               DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    `currency`                   CHAR(3)       NOT NULL DEFAULT 'MXN',
    `sort_order`                 INT           NOT NULL DEFAULT 0,
    `is_active`                  TINYINT(1)    NOT NULL DEFAULT 1,
    `created_at`                 DATETIME DEFAULT CURRENT_TIMESTAMP,
    `updated_at`                 DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uq_packages_code` (`code`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- account_subscriptions: una por cuenta. Nace en 'trialing' sin pago.
-- 'past_due' = cuenta en solo lectura hasta que pague (D13).
CREATE TABLE IF NOT EXISTS `account_subscriptions` (
    `id`                 BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `account_id`         BIGINT UNSIGNED NOT NULL,
    `package_id`         BIGINT UNSIGNED NOT NULL,
    `billing_cycle`      ENUM('monthly','yearly') NOT NULL DEFAULT 'monthly',
    `provider`           ENUM('mercadopago','manual') NULL,
    `provider_reference` VARCHAR(190) NULL,
    `status`             ENUM('trialing','active','past_due','canceled') NOT NULL DEFAULT 'trialing',
    `trial_ends_at`      DATETIME NULL,
    `current_period_end` DATETIME NULL,
    `created_at`         DATETIME DEFAULT CURRENT_TIMESTAMP,
    `updated_at`         DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uq_account_subscriptions_account` (`account_id`),
    KEY `idx_account_subscriptions_package` (`package_id`),
    KEY `idx_account_subscriptions_status_trial` (`status`, `trial_ends_at`),
    CONSTRAINT `fk_account_subscriptions_account` FOREIGN KEY (`account_id`) REFERENCES `accounts` (`id`) ON DELETE CASCADE,
    CONSTRAINT `fk_account_subscriptions_package` FOREIGN KEY (`package_id`) REFERENCES `packages` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- subscription_events: bitácora de lo que el super admin cambia a mano.
CREATE TABLE IF NOT EXISTS `subscription_events` (
    `id`            BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `account_id`    BIGINT UNSIGNED NOT NULL,
    `actor_user_id` BIGINT UNSIGNED NOT NULL,
    `event`         ENUM('trial_extended','manual_payment','package_changed','ads_toggled','status_changed') NOT NULL,
    `old_value`     VARCHAR(255) NULL,
    `new_value`     VARCHAR(255) NULL,
    `note`          VARCHAR(500) NULL,
    `created_at`    DATETIME DEFAULT CURRENT_TIMESTAMP,
    `updated_at`    DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_subscription_events_account` (`account_id`, `created_at`),
    KEY `idx_subscription_events_actor` (`actor_user_id`),
    CONSTRAINT `fk_subscription_events_account` FOREIGN KEY (`account_id`) REFERENCES `accounts` (`id`) ON DELETE CASCADE,
    CONSTRAINT `fk_subscription_events_actor` FOREIGN KEY (`actor_user_id`) REFERENCES `users` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =============================================================
-- 3. CATÁLOGO DEPORTIVO (D7)
-- =============================================================

CREATE TABLE IF NOT EXISTS `sports` (
    `id`          BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `code`        VARCHAR(20)  NOT NULL,
    `name`        VARCHAR(60)  NOT NULL,
    `score_unit`  ENUM('goles','puntos','sets') NOT NULL,
    `has_periods` TINYINT(1)   NOT NULL DEFAULT 0,
    `allows_draw` TINYINT(1)   NOT NULL DEFAULT 0,
    `is_active`   TINYINT(1)   NOT NULL DEFAULT 1,
    `created_at`  DATETIME DEFAULT CURRENT_TIMESTAMP,
    `updated_at`  DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uq_sports_code` (`code`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- event_types: qué se puede anotar en la cédula de cada deporte.
-- score_value alimenta la estadística del jugador (ej. triple = 3);
-- el marcador oficial del partido vive en matches/match_periods.
CREATE TABLE IF NOT EXISTS `event_types` (
    `id`             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `sport_id`       BIGINT UNSIGNED NOT NULL,
    `code`           VARCHAR(40)  NOT NULL,
    `name`           VARCHAR(80)  NOT NULL,
    `category`       ENUM('score','discipline','other') NOT NULL DEFAULT 'other',
    `score_value`    INT          NOT NULL DEFAULT 0,
    `is_sending_off` TINYINT(1)   NOT NULL DEFAULT 0,
    `player_scope`   ENUM('optional','required','two','none') NOT NULL DEFAULT 'optional',
    `color`          VARCHAR(20)  NULL,
    `sort_order`     INT          NOT NULL DEFAULT 0,
    `is_active`      TINYINT(1)   NOT NULL DEFAULT 1,
    `created_at`     DATETIME DEFAULT CURRENT_TIMESTAMP,
    `updated_at`     DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uq_event_types_sport_code` (`sport_id`, `code`),
    CONSTRAINT `fk_event_types_sport` FOREIGN KEY (`sport_id`) REFERENCES `sports` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =============================================================
-- 4. LIGA, SEDES Y TORNEO
-- =============================================================

-- leagues: la liga fija el deporte de todos sus torneos (D11).
CREATE TABLE IF NOT EXISTS `leagues` (
    `id`            BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `account_id`    BIGINT UNSIGNED NOT NULL,
    `sport_id`      BIGINT UNSIGNED NOT NULL,
    `name`          VARCHAR(150) NOT NULL,
    `logo_url`      VARCHAR(500) NULL,
    `timezone`      VARCHAR(50)  NOT NULL DEFAULT 'America/Mexico_City',
    `payment_model` ENUM('league_pays','teams_pay') NOT NULL DEFAULT 'league_pays',
    `is_public`     TINYINT(1)   NOT NULL DEFAULT 1,
    `public_code`   VARCHAR(12)  NULL,
    `roster_limit_unlocked` TINYINT(1) NOT NULL DEFAULT 0,
    `status`        ENUM('active','archived') NOT NULL DEFAULT 'active',
    `created_at`    DATETIME DEFAULT CURRENT_TIMESTAMP,
    `updated_at`    DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uq_leagues_public_code` (`public_code`),
    KEY `idx_leagues_account` (`account_id`, `status`),
    KEY `idx_leagues_sport` (`sport_id`),
    CONSTRAINT `fk_leagues_account` FOREIGN KEY (`account_id`) REFERENCES `accounts` (`id`),
    CONSTRAINT `fk_leagues_sport` FOREIGN KEY (`sport_id`) REFERENCES `sports` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `league_admins` (
    `id`         BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `league_id`  BIGINT UNSIGNED NOT NULL,
    `user_id`    BIGINT UNSIGNED NOT NULL,
    `role`       ENUM('owner','admin') NOT NULL DEFAULT 'admin',
    `created_at` DATETIME DEFAULT CURRENT_TIMESTAMP,
    `updated_at` DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uq_league_admins_league_user` (`league_id`, `user_id`),
    KEY `idx_league_admins_user` (`user_id`),
    CONSTRAINT `fk_league_admins_league` FOREIGN KEY (`league_id`) REFERENCES `leagues` (`id`) ON DELETE CASCADE,
    CONSTRAINT `fk_league_admins_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- league_followers: quien sigue una liga la ve en su inicio y recibe sus
-- avisos, sin ser jugador ni responsable de un equipo.
CREATE TABLE IF NOT EXISTS `league_followers` (
    `id`         BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `league_id`  BIGINT UNSIGNED NOT NULL,
    `user_id`    BIGINT UNSIGNED NOT NULL,
    `created_at` DATETIME DEFAULT CURRENT_TIMESTAMP,
    `updated_at` DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uq_league_followers` (`league_id`, `user_id`),
    KEY `idx_league_followers_user` (`user_id`),
    CONSTRAINT `fk_league_followers_league` FOREIGN KEY (`league_id`) REFERENCES `leagues` (`id`) ON DELETE CASCADE,
    CONSTRAINT `fk_league_followers_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- referees: el árbitro siempre tiene cuenta (user_id obligatorio) y es una
-- sola identidad para toda la plataforma; a qué ligas pita lo dice league_referees.
CREATE TABLE IF NOT EXISTS `referees` (
    `id`                  BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `user_id`             BIGINT UNSIGNED NOT NULL,
    `verification_status` ENUM('pending','verified','rejected') NOT NULL DEFAULT 'pending',
    `status`              ENUM('active','inactive') NOT NULL DEFAULT 'active',
    `created_at`          DATETIME DEFAULT CURRENT_TIMESTAMP,
    `updated_at`          DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uq_referees_user` (`user_id`),
    CONSTRAINT `fk_referees_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- league_referees: un árbitro puede pitar en N ligas con la misma cuenta (D19).
-- Solo se le pueden asignar partidos de ligas donde su fila esté 'active'.
CREATE TABLE IF NOT EXISTS `league_referees` (
    `id`               BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `league_id`        BIGINT UNSIGNED NOT NULL,
    `referee_id`       BIGINT UNSIGNED NOT NULL,
    `status`           ENUM('invited','active','inactive') NOT NULL DEFAULT 'active',
    `added_by_user_id` BIGINT UNSIGNED NULL,
    `created_at`       DATETIME DEFAULT CURRENT_TIMESTAMP,
    `updated_at`       DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uq_league_referees` (`league_id`, `referee_id`),
    KEY `idx_league_referees_referee` (`referee_id`, `status`),
    KEY `idx_league_referees_added_by` (`added_by_user_id`),
    CONSTRAINT `fk_league_referees_league` FOREIGN KEY (`league_id`) REFERENCES `leagues` (`id`) ON DELETE CASCADE,
    CONSTRAINT `fk_league_referees_referee` FOREIGN KEY (`referee_id`) REFERENCES `referees` (`id`) ON DELETE CASCADE,
    CONSTRAINT `fk_league_referees_added_by` FOREIGN KEY (`added_by_user_id`) REFERENCES `users` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `venues` (
    `id`         BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `league_id`  BIGINT UNSIGNED NOT NULL,
    `name`       VARCHAR(150) NOT NULL,
    `address`    VARCHAR(300) NULL,
    `lat`        DECIMAL(10,7) NULL,
    `lng`        DECIMAL(10,7) NULL,
    `is_active`  TINYINT(1) NOT NULL DEFAULT 1,
    `created_at` DATETIME DEFAULT CURRENT_TIMESTAMP,
    `updated_at` DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_venues_league` (`league_id`),
    CONSTRAINT `fk_venues_league` FOREIGN KEY (`league_id`) REFERENCES `leagues` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `fields` (
    `id`         BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `venue_id`   BIGINT UNSIGNED NOT NULL,
    `sport_id`   BIGINT UNSIGNED NULL,
    `name`       VARCHAR(100) NOT NULL,
    `is_active`  TINYINT(1) NOT NULL DEFAULT 1,
    `created_at` DATETIME DEFAULT CURRENT_TIMESTAMP,
    `updated_at` DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_fields_venue` (`venue_id`),
    KEY `idx_fields_sport` (`sport_id`),
    CONSTRAINT `fk_fields_venue` FOREIGN KEY (`venue_id`) REFERENCES `venues` (`id`) ON DELETE CASCADE,
    CONSTRAINT `fk_fields_sport` FOREIGN KEY (`sport_id`) REFERENCES `sports` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- tournaments: settings guarda las respuestas del asistente de creación
-- (nº de grupos, clasificados por grupo, ronda inicial de liguilla, etc.).
CREATE TABLE IF NOT EXISTS `tournaments` (
    `id`         BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `league_id`  BIGINT UNSIGNED NOT NULL,
    `name`       VARCHAR(150) NOT NULL,
    `format`     ENUM('groups','knockout','round_robin','groups_knockout','groups_two_legs') NOT NULL,
    `settings`   JSON NULL,
    `starts_at`  DATE NULL,
    `ends_at`    DATE NULL,
    `status`     ENUM('draft','registration','in_progress','finished','archived') NOT NULL DEFAULT 'draft',
    `created_at` DATETIME DEFAULT CURRENT_TIMESTAMP,
    `updated_at` DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_tournaments_league` (`league_id`, `status`),
    CONSTRAINT `fk_tournaments_league` FOREIGN KEY (`league_id`) REFERENCES `leagues` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `tournament_groups` (
    `id`                BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `tournament_id`     BIGINT UNSIGNED NOT NULL,
    `name`              VARCHAR(60) NOT NULL,
    `is_knockout_stage` TINYINT(1)  NOT NULL DEFAULT 0,
    `sort_order`        INT         NOT NULL DEFAULT 0,
    `created_at`        DATETIME DEFAULT CURRENT_TIMESTAMP,
    `updated_at`        DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uq_tournament_groups_name` (`tournament_id`, `name`),
    CONSTRAINT `fk_tournament_groups_tournament` FOREIGN KEY (`tournament_id`) REFERENCES `tournaments` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =============================================================
-- 5. EQUIPOS Y JUGADORES PERSISTENTES, INSCRIPCIÓN Y TRANSFERENCIAS
-- =============================================================

-- teams: sin league_id ni tournament_id. Un equipo existe por sí mismo
-- y se inscribe a N torneos de N ligas vía tournament_teams.
CREATE TABLE IF NOT EXISTS `teams` (
    `id`                 BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `sport_id`           BIGINT UNSIGNED NOT NULL,
    `name`               VARCHAR(150) NOT NULL,
    `logo_url`           VARCHAR(500) NULL,
    `created_by_user_id` BIGINT UNSIGNED NULL,
    `status`             ENUM('active','archived') NOT NULL DEFAULT 'active',
    `created_at`         DATETIME DEFAULT CURRENT_TIMESTAMP,
    `updated_at`         DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_teams_sport` (`sport_id`),
    KEY `idx_teams_name` (`name`),
    KEY `idx_teams_created_by` (`created_by_user_id`),
    CONSTRAINT `fk_teams_sport` FOREIGN KEY (`sport_id`) REFERENCES `sports` (`id`),
    CONSTRAINT `fk_teams_created_by` FOREIGN KEY (`created_by_user_id`) REFERENCES `users` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `team_managers` (
    `id`         BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `team_id`    BIGINT UNSIGNED NOT NULL,
    `user_id`    BIGINT UNSIGNED NOT NULL,
    `role`       ENUM('owner','delegado','capitan') NOT NULL DEFAULT 'delegado',
    `created_at` DATETIME DEFAULT CURRENT_TIMESTAMP,
    `updated_at` DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uq_team_managers_team_user` (`team_id`, `user_id`),
    KEY `idx_team_managers_user` (`user_id`),
    CONSTRAINT `fk_team_managers_team` FOREIGN KEY (`team_id`) REFERENCES `teams` (`id`) ON DELETE CASCADE,
    CONSTRAINT `fk_team_managers_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- players: user_id NULL = perfil dado de alta por un delegado y aún no
-- reclamado por el jugador (D1). Las estadísticas de carrera cuelgan de aquí
-- a través de tournament_rosters.
CREATE TABLE IF NOT EXISTS `players` (
    `id`                 BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `user_id`            BIGINT UNSIGNED NULL,
    `full_name`          VARCHAR(150) NOT NULL,
    `birthdate`          DATE         NULL,
    `phone`              VARCHAR(30)  NULL,
    `email`              VARCHAR(190) NULL,
    `photo_url`          VARCHAR(500) NULL,
    `photo_status`       ENUM('none','pending','approved','rejected') NOT NULL DEFAULT 'none',
    `pending_changes`    JSON NULL,
    `created_by_user_id` BIGINT UNSIGNED NULL,
    `created_at`         DATETIME DEFAULT CURRENT_TIMESTAMP,
    `updated_at`         DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uq_players_user` (`user_id`),
    KEY `idx_players_name` (`full_name`),
    KEY `idx_players_photo_status` (`photo_status`),
    KEY `idx_players_created_by` (`created_by_user_id`),
    CONSTRAINT `fk_players_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE SET NULL,
    CONSTRAINT `fk_players_created_by` FOREIGN KEY (`created_by_user_id`) REFERENCES `users` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- tournament_teams: inscripción de un equipo a un torneo. Una fila por
-- (torneo, equipo); si el equipo se retira y regresa, se reactiva la misma.
-- Las columnas de tabla de posiciones son caché recalculada por StandingsService.
CREATE TABLE IF NOT EXISTS `tournament_teams` (
    `id`              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `tournament_id`   BIGINT UNSIGNED NOT NULL,
    `team_id`         BIGINT UNSIGNED NOT NULL,
    `group_id`        BIGINT UNSIGNED NULL,
    `status`          ENUM('pending','active','rejected','withdrawn') NOT NULL DEFAULT 'pending',
    `identity_policy` ENUM('strict','flexible') NULL,
    `played`          INT UNSIGNED NOT NULL DEFAULT 0,
    `won`             INT UNSIGNED NOT NULL DEFAULT 0,
    `drawn`           INT UNSIGNED NOT NULL DEFAULT 0,
    `lost`            INT UNSIGNED NOT NULL DEFAULT 0,
    `score_for`       INT UNSIGNED NOT NULL DEFAULT 0,
    `score_against`   INT UNSIGNED NOT NULL DEFAULT 0,
    `detail_for`      INT UNSIGNED NOT NULL DEFAULT 0,
    `detail_against`  INT UNSIGNED NOT NULL DEFAULT 0,
    `points`          INT          NOT NULL DEFAULT 0,
    `created_at`      DATETIME DEFAULT CURRENT_TIMESTAMP,
    `updated_at`      DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uq_tournament_teams` (`tournament_id`, `team_id`),
    KEY `idx_tournament_teams_team` (`team_id`),
    KEY `idx_tournament_teams_group` (`group_id`),
    KEY `idx_tournament_teams_standings` (`tournament_id`, `status`, `points`),
    CONSTRAINT `fk_tournament_teams_tournament` FOREIGN KEY (`tournament_id`) REFERENCES `tournaments` (`id`),
    CONSTRAINT `fk_tournament_teams_team` FOREIGN KEY (`team_id`) REFERENCES `teams` (`id`),
    CONSTRAINT `fk_tournament_teams_group` FOREIGN KEY (`group_id`) REFERENCES `tournament_groups` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- tournament_rosters: plantel de una inscripción. valid_to NULL = vigente.
-- Regla a nivel Service (MySQL no la expresa): un jugador no puede tener dos
-- filas approved y vigentes en el MISMO torneo; sí en torneos distintos.
-- Nunca se reasigna una fila histórica: se cierra y se abre otra, así los
-- eventos anotados quedan con el club con el que se jugaron.
CREATE TABLE IF NOT EXISTS `tournament_rosters` (
    `id`                 BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `tournament_team_id` BIGINT UNSIGNED NOT NULL,
    `player_id`          BIGINT UNSIGNED NOT NULL,
    `jersey_number`      SMALLINT UNSIGNED NULL,
    `position`           VARCHAR(40) NULL,
    `status`             ENUM('requested','pending','approved','rejected') NOT NULL DEFAULT 'pending',
    `reviewed_by_user_id` BIGINT UNSIGNED NULL,
    `pending_changes`    JSON NULL,
    `valid_from`         DATE NOT NULL,
    `valid_to`           DATE NULL,
    `created_at`         DATETIME DEFAULT CURRENT_TIMESTAMP,
    `updated_at`         DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_tournament_rosters_team` (`tournament_team_id`, `status`, `valid_to`),
    KEY `idx_tournament_rosters_player` (`player_id`, `status`, `valid_to`),
    KEY `idx_tournament_rosters_reviewer` (`reviewed_by_user_id`),
    CONSTRAINT `fk_tournament_rosters_team` FOREIGN KEY (`tournament_team_id`) REFERENCES `tournament_teams` (`id`),
    CONSTRAINT `fk_tournament_rosters_player` FOREIGN KEY (`player_id`) REFERENCES `players` (`id`),
    CONSTRAINT `fk_tournament_rosters_reviewer` FOREIGN KEY (`reviewed_by_user_id`) REFERENCES `users` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- roster_transfers: bitácora de migraciones. Migrar un equipo completo
-- genera una fila por jugador con el mismo batch_id.
CREATE TABLE IF NOT EXISTS `roster_transfers` (
    `id`                        BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `batch_id`                  CHAR(36) NOT NULL,
    `transfer_type`             ENUM('full_team','players_only') NOT NULL,
    `player_id`                 BIGINT UNSIGNED NOT NULL,
    `from_tournament_roster_id` BIGINT UNSIGNED NULL,
    `to_tournament_team_id`     BIGINT UNSIGNED NOT NULL,
    `to_tournament_roster_id`   BIGINT UNSIGNED NULL,
    `requested_by_user_id`      BIGINT UNSIGNED NOT NULL,
    `approved_by_user_id`       BIGINT UNSIGNED NULL,
    `status`                    ENUM('pending','approved','rejected') NOT NULL DEFAULT 'pending',
    `effective_at`              DATETIME NULL,
    `created_at`                DATETIME DEFAULT CURRENT_TIMESTAMP,
    `updated_at`                DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_roster_transfers_batch` (`batch_id`),
    KEY `idx_roster_transfers_player` (`player_id`),
    KEY `idx_roster_transfers_from` (`from_tournament_roster_id`),
    KEY `idx_roster_transfers_to_team` (`to_tournament_team_id`, `status`),
    KEY `idx_roster_transfers_to_roster` (`to_tournament_roster_id`),
    KEY `idx_roster_transfers_requested_by` (`requested_by_user_id`),
    KEY `idx_roster_transfers_approved_by` (`approved_by_user_id`),
    CONSTRAINT `fk_roster_transfers_player` FOREIGN KEY (`player_id`) REFERENCES `players` (`id`),
    CONSTRAINT `fk_roster_transfers_from` FOREIGN KEY (`from_tournament_roster_id`) REFERENCES `tournament_rosters` (`id`),
    CONSTRAINT `fk_roster_transfers_to_team` FOREIGN KEY (`to_tournament_team_id`) REFERENCES `tournament_teams` (`id`),
    CONSTRAINT `fk_roster_transfers_to_roster` FOREIGN KEY (`to_tournament_roster_id`) REFERENCES `tournament_rosters` (`id`),
    CONSTRAINT `fk_roster_transfers_requested_by` FOREIGN KEY (`requested_by_user_id`) REFERENCES `users` (`id`),
    CONSTRAINT `fk_roster_transfers_approved_by` FOREIGN KEY (`approved_by_user_id`) REFERENCES `users` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- invitations: puertas de entrada de jugadores y árbitros.
--   player_claim → enlace que el delegado manda a un jugador que él dio de
--                  alta; al registrarse, la cuenta se liga a ese perfil.
--                  Se guarda solo el SHA-256 del token (token_hash).
--   team_join    → código corto del equipo en un torneo; quien lo captura
--                  pide entrar al plantel. Se guarda en claro (code) porque
--                  el delegado necesita volver a verlo y compartirlo.
--   referee_join → enlace con el que el admin de liga suma a un árbitro a
--                  su liga (league_id); crea o activa su fila en league_referees.
CREATE TABLE IF NOT EXISTS `invitations` (
    `id`                 BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `type`               ENUM('player_claim','team_join','referee_join') NOT NULL,
    `code`               VARCHAR(12) NULL,
    `token_hash`         CHAR(64)    NULL,
    `player_id`          BIGINT UNSIGNED NULL,
    `tournament_team_id` BIGINT UNSIGNED NULL,
    `league_id`          BIGINT UNSIGNED NULL,
    `created_by_user_id` BIGINT UNSIGNED NOT NULL,
    `max_uses`           INT UNSIGNED NULL,
    `uses`               INT UNSIGNED NOT NULL DEFAULT 0,
    `expires_at`         DATETIME NULL,
    `status`             ENUM('active','used','revoked') NOT NULL DEFAULT 'active',
    `created_at`         DATETIME DEFAULT CURRENT_TIMESTAMP,
    `updated_at`         DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uq_invitations_code` (`code`),
    UNIQUE KEY `uq_invitations_token` (`token_hash`),
    KEY `idx_invitations_player` (`player_id`),
    KEY `idx_invitations_tt` (`tournament_team_id`, `status`),
    KEY `idx_invitations_league` (`league_id`),
    KEY `idx_invitations_created_by` (`created_by_user_id`),
    CONSTRAINT `fk_invitations_player` FOREIGN KEY (`player_id`) REFERENCES `players` (`id`) ON DELETE CASCADE,
    CONSTRAINT `fk_invitations_tt` FOREIGN KEY (`tournament_team_id`) REFERENCES `tournament_teams` (`id`) ON DELETE CASCADE,
    CONSTRAINT `fk_invitations_league` FOREIGN KEY (`league_id`) REFERENCES `leagues` (`id`) ON DELETE CASCADE,
    CONSTRAINT `fk_invitations_created_by` FOREIGN KEY (`created_by_user_id`) REFERENCES `users` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =============================================================
-- 6. LLAVES (BRACKETS)
-- =============================================================

-- brackets: una fila por ronda eliminatoria. round_name es libre
-- ("16vos", "8vos", "4tos", "semifinal", "final") para arrancar desde cualquiera.
CREATE TABLE IF NOT EXISTS `brackets` (
    `id`                       BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `tournament_id`            BIGINT UNSIGNED NOT NULL,
    `round_name`               VARCHAR(30) NOT NULL,
    `round_order`              INT         NOT NULL,
    `two_legs`                 TINYINT(1)  NOT NULL DEFAULT 0,
    `penalty_shootout_enabled` TINYINT(1)  NOT NULL DEFAULT 0,
    `created_at`               DATETIME DEFAULT CURRENT_TIMESTAMP,
    `updated_at`               DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uq_brackets_round` (`tournament_id`, `round_order`),
    CONSTRAINT `fk_brackets_tournament` FOREIGN KEY (`tournament_id`) REFERENCES `tournaments` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- bracket_nodes: un cruce del cuadro. next_node_id = a dónde avanza el ganador.
CREATE TABLE IF NOT EXISTS `bracket_nodes` (
    `id`                        BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `bracket_id`                BIGINT UNSIGNED NOT NULL,
    `position`                  INT NOT NULL,
    `home_tournament_team_id`   BIGINT UNSIGNED NULL,
    `away_tournament_team_id`   BIGINT UNSIGNED NULL,
    `winner_tournament_team_id` BIGINT UNSIGNED NULL,
    `next_node_id`              BIGINT UNSIGNED NULL,
    `created_at`                DATETIME DEFAULT CURRENT_TIMESTAMP,
    `updated_at`                DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uq_bracket_nodes_position` (`bracket_id`, `position`),
    KEY `idx_bracket_nodes_home` (`home_tournament_team_id`),
    KEY `idx_bracket_nodes_away` (`away_tournament_team_id`),
    KEY `idx_bracket_nodes_winner` (`winner_tournament_team_id`),
    KEY `idx_bracket_nodes_next` (`next_node_id`),
    CONSTRAINT `fk_bracket_nodes_bracket` FOREIGN KEY (`bracket_id`) REFERENCES `brackets` (`id`) ON DELETE CASCADE,
    CONSTRAINT `fk_bracket_nodes_home` FOREIGN KEY (`home_tournament_team_id`) REFERENCES `tournament_teams` (`id`) ON DELETE SET NULL,
    CONSTRAINT `fk_bracket_nodes_away` FOREIGN KEY (`away_tournament_team_id`) REFERENCES `tournament_teams` (`id`) ON DELETE SET NULL,
    CONSTRAINT `fk_bracket_nodes_winner` FOREIGN KEY (`winner_tournament_team_id`) REFERENCES `tournament_teams` (`id`) ON DELETE SET NULL,
    CONSTRAINT `fk_bracket_nodes_next` FOREIGN KEY (`next_node_id`) REFERENCES `bracket_nodes` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =============================================================
-- 7. PARTIDOS, CÉDULA Y RESULTADOS
-- =============================================================

-- matches: home_score/away_score es el marcador oficial (goles, puntos o
-- sets ganados). Basta con él para la tabla de posiciones (D15); el detalle
-- en match_periods/match_events/match_lineups es opcional.
-- score_captured_at arranca el plazo de firma y reclamos (D16).
CREATE TABLE IF NOT EXISTS `matches` (
    `id`                         BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `tournament_id`              BIGINT UNSIGNED NOT NULL,
    `group_id`                   BIGINT UNSIGNED NULL,
    `bracket_node_id`            BIGINT UNSIGNED NULL,
    `matchday`                   INT UNSIGNED NULL,
    `home_tournament_team_id`    BIGINT UNSIGNED NOT NULL,
    `away_tournament_team_id`    BIGINT UNSIGNED NOT NULL,
    `field_id`                   BIGINT UNSIGNED NULL,
    `referee_id`                 BIGINT UNSIGNED NULL,
    `scheduled_at`               DATETIME NULL,
    `status`                     ENUM('scheduled','in_progress','finished','walkover','postponed','canceled') NOT NULL DEFAULT 'scheduled',
    `is_second_leg`              TINYINT(1) NOT NULL DEFAULT 0,
    `home_score`                 INT UNSIGNED NULL,
    `away_score`                 INT UNSIGNED NULL,
    `home_penalties`             INT UNSIGNED NULL,
    `away_penalties`             INT UNSIGNED NULL,
    `winner_tournament_team_id`  BIGINT UNSIGNED NULL,
    `result_source`              ENUM('referee_app','admin_panel') NULL,
    `result_captured_by_user_id` BIGINT UNSIGNED NULL,
    `score_captured_at`          DATETIME NULL,
    `started_at`                 DATETIME NULL,
    `finished_at`                DATETIME NULL,
    `notes`                      TEXT NULL,
    `created_at`                 DATETIME DEFAULT CURRENT_TIMESTAMP,
    `updated_at`                 DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_matches_tournament_schedule` (`tournament_id`, `scheduled_at`),
    KEY `idx_matches_tournament_status` (`tournament_id`, `status`),
    KEY `idx_matches_scheduled` (`scheduled_at`),
    KEY `idx_matches_group` (`group_id`),
    KEY `idx_matches_bracket_node` (`bracket_node_id`),
    KEY `idx_matches_home` (`home_tournament_team_id`),
    KEY `idx_matches_away` (`away_tournament_team_id`),
    KEY `idx_matches_field` (`field_id`, `scheduled_at`),
    KEY `idx_matches_referee` (`referee_id`, `scheduled_at`),
    KEY `idx_matches_winner` (`winner_tournament_team_id`),
    KEY `idx_matches_captured_by` (`result_captured_by_user_id`),
    CONSTRAINT `fk_matches_tournament` FOREIGN KEY (`tournament_id`) REFERENCES `tournaments` (`id`),
    CONSTRAINT `fk_matches_group` FOREIGN KEY (`group_id`) REFERENCES `tournament_groups` (`id`) ON DELETE SET NULL,
    CONSTRAINT `fk_matches_bracket_node` FOREIGN KEY (`bracket_node_id`) REFERENCES `bracket_nodes` (`id`) ON DELETE SET NULL,
    CONSTRAINT `fk_matches_home` FOREIGN KEY (`home_tournament_team_id`) REFERENCES `tournament_teams` (`id`),
    CONSTRAINT `fk_matches_away` FOREIGN KEY (`away_tournament_team_id`) REFERENCES `tournament_teams` (`id`),
    CONSTRAINT `fk_matches_field` FOREIGN KEY (`field_id`) REFERENCES `fields` (`id`) ON DELETE SET NULL,
    CONSTRAINT `fk_matches_referee` FOREIGN KEY (`referee_id`) REFERENCES `referees` (`id`) ON DELETE SET NULL,
    CONSTRAINT `fk_matches_winner` FOREIGN KEY (`winner_tournament_team_id`) REFERENCES `tournament_teams` (`id`) ON DELETE SET NULL,
    CONSTRAINT `fk_matches_captured_by` FOREIGN KEY (`result_captured_by_user_id`) REFERENCES `users` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- match_periods: desglose del marcador. Básquet = cuartos; vóley = sets
-- (puntos del set); pádel/tenis = sets (games del set, con tie-break opcional).
CREATE TABLE IF NOT EXISTS `match_periods` (
    `id`            BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `match_id`      BIGINT UNSIGNED NOT NULL,
    `period_number` TINYINT UNSIGNED NOT NULL,
    `home_score`    INT UNSIGNED NOT NULL DEFAULT 0,
    `away_score`    INT UNSIGNED NOT NULL DEFAULT 0,
    `home_tiebreak` INT UNSIGNED NULL,
    `away_tiebreak` INT UNSIGNED NULL,
    -- inicio y cierre reales del segmento; con started_at y sin ended_at es el que se está jugando
    `started_at`    DATETIME NULL,
    `ended_at`      DATETIME NULL,
    `created_at`    DATETIME DEFAULT CURRENT_TIMESTAMP,
    `updated_at`    DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uq_match_periods` (`match_id`, `period_number`),
    CONSTRAINT `fk_match_periods_match` FOREIGN KEY (`match_id`) REFERENCES `matches` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- match_lineups: quién jugó. tournament_roster_id NULL + guest_name =
-- jugador no registrado admitido en modo flexible (D12).
CREATE TABLE IF NOT EXISTS `match_lineups` (
    `id`                   BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `match_id`             BIGINT UNSIGNED NOT NULL,
    `tournament_team_id`   BIGINT UNSIGNED NOT NULL,
    `tournament_roster_id` BIGINT UNSIGNED NULL,
    `guest_name`           VARCHAR(150) NULL,
    `jersey_number`        SMALLINT UNSIGNED NULL,
    `started`              TINYINT(1) NOT NULL DEFAULT 1,
    `identity_verified`    TINYINT(1) NOT NULL DEFAULT 0,
    `created_at`           DATETIME DEFAULT CURRENT_TIMESTAMP,
    `updated_at`           DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uq_match_lineups_roster` (`match_id`, `tournament_roster_id`),
    KEY `idx_match_lineups_team` (`match_id`, `tournament_team_id`),
    KEY `idx_match_lineups_tt` (`tournament_team_id`),
    KEY `idx_match_lineups_roster` (`tournament_roster_id`),
    CONSTRAINT `fk_match_lineups_match` FOREIGN KEY (`match_id`) REFERENCES `matches` (`id`) ON DELETE CASCADE,
    CONSTRAINT `fk_match_lineups_tt` FOREIGN KEY (`tournament_team_id`) REFERENCES `tournament_teams` (`id`),
    CONSTRAINT `fk_match_lineups_roster` FOREIGN KEY (`tournament_roster_id`) REFERENCES `tournament_rosters` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- match_events: gol, tarjeta, falta, punto, etc. según event_types del deporte.
-- El jugador se referencia por tournament_roster_id (nunca player_id): así el
-- mismo SUM da estadística de carrera, por club, por liga o por torneo.
-- Evento de invitado: tournament_roster_id NULL y guest_lineup_id lleno.
-- tournament_team_id = equipo al que se le acredita (en un autogol, el rival).
CREATE TABLE IF NOT EXISTS `match_events` (
    `id`                   BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `match_id`             BIGINT UNSIGNED NOT NULL,
    `event_type_id`        BIGINT UNSIGNED NOT NULL,
    `tournament_team_id`   BIGINT UNSIGNED NOT NULL,
    `tournament_roster_id` BIGINT UNSIGNED NULL,
    `related_tournament_roster_id` BIGINT UNSIGNED NULL,
    `guest_lineup_id`      BIGINT UNSIGNED NULL,
    `period_number`        TINYINT UNSIGNED NULL,
    `minute`               SMALLINT UNSIGNED NULL,
    `metadata`             JSON NULL,
    `created_by_user_id`   BIGINT UNSIGNED NULL,
    `created_at`           DATETIME DEFAULT CURRENT_TIMESTAMP,
    `updated_at`           DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_match_events_match` (`match_id`),
    KEY `idx_match_events_roster_type` (`tournament_roster_id`, `event_type_id`),
    KEY `idx_match_events_team_type` (`tournament_team_id`, `event_type_id`),
    KEY `idx_match_events_type` (`event_type_id`),
    KEY `idx_match_events_related` (`related_tournament_roster_id`),
    KEY `idx_match_events_guest` (`guest_lineup_id`),
    KEY `idx_match_events_created_by` (`created_by_user_id`),
    CONSTRAINT `fk_match_events_match` FOREIGN KEY (`match_id`) REFERENCES `matches` (`id`) ON DELETE CASCADE,
    CONSTRAINT `fk_match_events_type` FOREIGN KEY (`event_type_id`) REFERENCES `event_types` (`id`),
    CONSTRAINT `fk_match_events_tt` FOREIGN KEY (`tournament_team_id`) REFERENCES `tournament_teams` (`id`),
    CONSTRAINT `fk_match_events_roster` FOREIGN KEY (`tournament_roster_id`) REFERENCES `tournament_rosters` (`id`),
    CONSTRAINT `fk_match_events_related` FOREIGN KEY (`related_tournament_roster_id`) REFERENCES `tournament_rosters` (`id`),
    CONSTRAINT `fk_match_events_guest` FOREIGN KEY (`guest_lineup_id`) REFERENCES `match_lineups` (`id`) ON DELETE CASCADE,
    CONSTRAINT `fk_match_events_created_by` FOREIGN KEY (`created_by_user_id`) REFERENCES `users` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- identity_verifications: validación del árbitro antes de iniciar (D12).
CREATE TABLE IF NOT EXISTS `identity_verifications` (
    `id`                   BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `match_id`             BIGINT UNSIGNED NOT NULL,
    `tournament_roster_id` BIGINT UNSIGNED NOT NULL,
    `referee_id`           BIGINT UNSIGNED NOT NULL,
    `method`               ENUM('manual_visual','id_photo_match') NOT NULL DEFAULT 'manual_visual',
    `result`               ENUM('verified','rejected','skipped') NOT NULL,
    `note`                 VARCHAR(300) NULL,
    `verified_at`          DATETIME NOT NULL,
    `created_at`           DATETIME DEFAULT CURRENT_TIMESTAMP,
    `updated_at`           DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uq_identity_verifications` (`match_id`, `tournament_roster_id`),
    KEY `idx_identity_verifications_roster` (`tournament_roster_id`),
    KEY `idx_identity_verifications_referee` (`referee_id`),
    CONSTRAINT `fk_identity_verifications_match` FOREIGN KEY (`match_id`) REFERENCES `matches` (`id`) ON DELETE CASCADE,
    CONSTRAINT `fk_identity_verifications_roster` FOREIGN KEY (`tournament_roster_id`) REFERENCES `tournament_rosters` (`id`),
    CONSTRAINT `fk_identity_verifications_referee` FOREIGN KEY (`referee_id`) REFERENCES `referees` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- attendance_confirmations: el jugador confirma asistencia al capitán/delegado.
CREATE TABLE IF NOT EXISTS `attendance_confirmations` (
    `id`                   BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `match_id`             BIGINT UNSIGNED NOT NULL,
    `tournament_roster_id` BIGINT UNSIGNED NOT NULL,
    `status`               ENUM('pending','confirmed','declined') NOT NULL DEFAULT 'pending',
    `responded_at`         DATETIME NULL,
    `created_at`           DATETIME DEFAULT CURRENT_TIMESTAMP,
    `updated_at`           DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uq_attendance_confirmations` (`match_id`, `tournament_roster_id`),
    KEY `idx_attendance_confirmations_roster` (`tournament_roster_id`),
    CONSTRAINT `fk_attendance_confirmations_match` FOREIGN KEY (`match_id`) REFERENCES `matches` (`id`) ON DELETE CASCADE,
    CONSTRAINT `fk_attendance_confirmations_roster` FOREIGN KEY (`tournament_roster_id`) REFERENCES `tournament_rosters` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- player_suspensions: por regla del deporte (config) o impuestas a mano (D17).
CREATE TABLE IF NOT EXISTS `player_suspensions` (
    `id`                    BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `tournament_roster_id`  BIGINT UNSIGNED NOT NULL,
    `origin_match_event_id` BIGINT UNSIGNED NULL,
    `imposed_by_user_id`    BIGINT UNSIGNED NULL,
    `matches_total`         SMALLINT UNSIGNED NOT NULL DEFAULT 1,
    `matches_served`        SMALLINT UNSIGNED NOT NULL DEFAULT 0,
    `reason`                VARCHAR(300) NULL,
    -- multa al equipo ligada a la sanción; con fine_lifts = 1, pagarla la levanta (status 'lifted')
    `fine_charge_id`        BIGINT UNSIGNED NULL,
    `fine_lifts`            TINYINT(1) NOT NULL DEFAULT 0,
    `status`                ENUM('active','served','revoked','lifted') NOT NULL DEFAULT 'active',
    `created_at`            DATETIME DEFAULT CURRENT_TIMESTAMP,
    `updated_at`            DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_player_suspensions_roster` (`tournament_roster_id`, `status`),
    KEY `idx_player_suspensions_event` (`origin_match_event_id`),
    KEY `idx_player_suspensions_imposed_by` (`imposed_by_user_id`),
    KEY `idx_player_suspensions_fine` (`fine_charge_id`),
    CONSTRAINT `fk_player_suspensions_roster` FOREIGN KEY (`tournament_roster_id`) REFERENCES `tournament_rosters` (`id`),
    CONSTRAINT `fk_player_suspensions_event` FOREIGN KEY (`origin_match_event_id`) REFERENCES `match_events` (`id`) ON DELETE SET NULL,
    CONSTRAINT `fk_player_suspensions_imposed_by` FOREIGN KEY (`imposed_by_user_id`) REFERENCES `users` (`id`) ON DELETE SET NULL,
    CONSTRAINT `fk_player_suspensions_fine` FOREIGN KEY (`fine_charge_id`) REFERENCES `internal_charges` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- league_player_bans: veto de liga; el jugador no puede ser alineado ni dado de alta en ningún torneo de la liga.
CREATE TABLE IF NOT EXISTS `league_player_bans` (
    `id`                 BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `league_id`          BIGINT UNSIGNED NOT NULL,
    `player_id`          BIGINT UNSIGNED NOT NULL,
    `reason`             VARCHAR(300) NOT NULL,
    `ends_on`            DATE NULL,
    `status`             ENUM('active','lifted') NOT NULL DEFAULT 'active',
    `imposed_by_user_id` BIGINT UNSIGNED NULL,
    `lifted_by_user_id`  BIGINT UNSIGNED NULL,
    `created_at`         DATETIME DEFAULT CURRENT_TIMESTAMP,
    `updated_at`         DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_league_player_bans_league` (`league_id`, `status`),
    KEY `idx_league_player_bans_player` (`player_id`, `status`),
    KEY `idx_league_player_bans_imposed_by` (`imposed_by_user_id`),
    KEY `idx_league_player_bans_lifted_by` (`lifted_by_user_id`),
    CONSTRAINT `fk_league_player_bans_league` FOREIGN KEY (`league_id`) REFERENCES `leagues` (`id`) ON DELETE CASCADE,
    CONSTRAINT `fk_league_player_bans_player` FOREIGN KEY (`player_id`) REFERENCES `players` (`id`) ON DELETE CASCADE,
    CONSTRAINT `fk_league_player_bans_imposed_by` FOREIGN KEY (`imposed_by_user_id`) REFERENCES `users` (`id`) ON DELETE SET NULL,
    CONSTRAINT `fk_league_player_bans_lifted_by` FOREIGN KEY (`lifted_by_user_id`) REFERENCES `users` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `match_media` (
    `id`                   BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `match_id`             BIGINT UNSIGNED NOT NULL,
    `uploaded_by_user_id`  BIGINT UNSIGNED NULL,
    `type`                 ENUM('photo','video') NOT NULL DEFAULT 'photo',
    `cloudinary_public_id` VARCHAR(255) NOT NULL,
    `url`                  VARCHAR(500) NOT NULL,
    `created_at`           DATETIME DEFAULT CURRENT_TIMESTAMP,
    `updated_at`           DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_match_media_match` (`match_id`),
    KEY `idx_match_media_uploader` (`uploaded_by_user_id`),
    CONSTRAINT `fk_match_media_match` FOREIGN KEY (`match_id`) REFERENCES `matches` (`id`) ON DELETE CASCADE,
    CONSTRAINT `fk_match_media_uploader` FOREIGN KEY (`uploaded_by_user_id`) REFERENCES `users` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- match_signatures: firma de cédula por equipo (D16). method 'accept' =
-- gesto de aceptación; 'drawn' = trazo de firma guardado como imagen.
CREATE TABLE IF NOT EXISTS `match_signatures` (
    `id`                 BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `match_id`           BIGINT UNSIGNED NOT NULL,
    `tournament_team_id` BIGINT UNSIGNED NOT NULL,
    `signed_by_user_id`  BIGINT UNSIGNED NOT NULL,
    `method`             ENUM('accept','drawn') NOT NULL DEFAULT 'accept',
    `signature_url`      VARCHAR(500) NULL,
    `conformity`         ENUM('agreed','under_protest') NOT NULL DEFAULT 'agreed',
    `signed_at`          DATETIME NOT NULL,
    `created_at`         DATETIME DEFAULT CURRENT_TIMESTAMP,
    `updated_at`         DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uq_match_signatures` (`match_id`, `tournament_team_id`),
    KEY `idx_match_signatures_tt` (`tournament_team_id`),
    KEY `idx_match_signatures_user` (`signed_by_user_id`),
    CONSTRAINT `fk_match_signatures_match` FOREIGN KEY (`match_id`) REFERENCES `matches` (`id`) ON DELETE CASCADE,
    CONSTRAINT `fk_match_signatures_tt` FOREIGN KEY (`tournament_team_id`) REFERENCES `tournament_teams` (`id`),
    CONSTRAINT `fk_match_signatures_user` FOREIGN KEY (`signed_by_user_id`) REFERENCES `users` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- match_claims: reclamo de un equipo sobre la cédula (D16). Puede apuntar a
-- un evento propio o del rival. original_tournament_roster_id conserva a quién
-- se le había anotado aunque el evento se corrija después.
CREATE TABLE IF NOT EXISTS `match_claims` (
    `id`                            BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `match_id`                      BIGINT UNSIGNED NOT NULL,
    `claimant_tournament_team_id`   BIGINT UNSIGNED NOT NULL,
    `raised_by_user_id`             BIGINT UNSIGNED NOT NULL,
    `claim_type`                    ENUM('wrong_player','missing_event','event_did_not_happen','wrong_score') NOT NULL,
    `match_event_id`                BIGINT UNSIGNED NULL,
    `event_type_id`                 BIGINT UNSIGNED NULL,
    `original_tournament_roster_id` BIGINT UNSIGNED NULL,
    `proposed_tournament_roster_id` BIGINT UNSIGNED NULL,
    `description`                   TEXT NULL,
    `evidence_url`                  VARCHAR(500) NULL,
    `status`                        ENUM('pending','accepted','rejected') NOT NULL DEFAULT 'pending',
    `resolved_by_user_id`           BIGINT UNSIGNED NULL,
    `resolution_note`               VARCHAR(500) NULL,
    `resolved_at`                   DATETIME NULL,
    `created_at`                    DATETIME DEFAULT CURRENT_TIMESTAMP,
    `updated_at`                    DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_match_claims_match` (`match_id`, `status`),
    KEY `idx_match_claims_status` (`status`, `created_at`),
    KEY `idx_match_claims_claimant` (`claimant_tournament_team_id`),
    KEY `idx_match_claims_raised_by` (`raised_by_user_id`),
    KEY `idx_match_claims_event` (`match_event_id`),
    KEY `idx_match_claims_event_type` (`event_type_id`),
    KEY `idx_match_claims_original` (`original_tournament_roster_id`),
    KEY `idx_match_claims_proposed` (`proposed_tournament_roster_id`),
    KEY `idx_match_claims_resolved_by` (`resolved_by_user_id`),
    CONSTRAINT `fk_match_claims_match` FOREIGN KEY (`match_id`) REFERENCES `matches` (`id`) ON DELETE CASCADE,
    CONSTRAINT `fk_match_claims_claimant` FOREIGN KEY (`claimant_tournament_team_id`) REFERENCES `tournament_teams` (`id`),
    CONSTRAINT `fk_match_claims_raised_by` FOREIGN KEY (`raised_by_user_id`) REFERENCES `users` (`id`),
    CONSTRAINT `fk_match_claims_event` FOREIGN KEY (`match_event_id`) REFERENCES `match_events` (`id`) ON DELETE SET NULL,
    CONSTRAINT `fk_match_claims_event_type` FOREIGN KEY (`event_type_id`) REFERENCES `event_types` (`id`),
    CONSTRAINT `fk_match_claims_original` FOREIGN KEY (`original_tournament_roster_id`) REFERENCES `tournament_rosters` (`id`),
    CONSTRAINT `fk_match_claims_proposed` FOREIGN KEY (`proposed_tournament_roster_id`) REFERENCES `tournament_rosters` (`id`),
    CONSTRAINT `fk_match_claims_resolved_by` FOREIGN KEY (`resolved_by_user_id`) REFERENCES `users` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =============================================================
-- 8. COBROS Y PAGOS (D5)
-- =============================================================

-- team_subscriptions: cuota del equipo vía RevenueCat, solo si la liga
-- eligió payment_model = 'teams_pay'.
CREATE TABLE IF NOT EXISTS `team_subscriptions` (
    `id`                     BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `team_id`                BIGINT UNSIGNED NOT NULL,
    `league_id`              BIGINT UNSIGNED NOT NULL,
    `revenuecat_customer_id` VARCHAR(190) NULL,
    `status`                 ENUM('active','past_due','canceled') NOT NULL DEFAULT 'active',
    `current_period_end`     DATETIME NULL,
    `created_at`             DATETIME DEFAULT CURRENT_TIMESTAMP,
    `updated_at`             DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uq_team_subscriptions` (`team_id`, `league_id`),
    KEY `idx_team_subscriptions_league` (`league_id`, `status`),
    CONSTRAINT `fk_team_subscriptions_team` FOREIGN KEY (`team_id`) REFERENCES `teams` (`id`),
    CONSTRAINT `fk_team_subscriptions_league` FOREIGN KEY (`league_id`) REFERENCES `leagues` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- internal_charges: lo que la liga cobra a sus equipos o jugadores.
-- subject_id apunta a teams.id o players.id según subject_type (sin FK).
CREATE TABLE IF NOT EXISTS `internal_charges` (
    `id`                 BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `league_id`          BIGINT UNSIGNED NOT NULL,
    `tournament_id`      BIGINT UNSIGNED NULL,
    `match_id`           BIGINT UNSIGNED NULL,
    `subject_type`       ENUM('team','player') NOT NULL,
    `subject_id`         BIGINT UNSIGNED NOT NULL,
    `charge_type`        ENUM('inscripcion','arbitraje','credencial','multa','otro') NOT NULL,
    `concept`            VARCHAR(200) NULL,
    `amount`             DECIMAL(10,2) NOT NULL,
    `amount_paid`        DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    `due_date`           DATE NULL,
    `status`             ENUM('pending','partial','paid','overdue','waived') NOT NULL DEFAULT 'pending',
    `created_by_user_id` BIGINT UNSIGNED NULL,
    `created_at`         DATETIME DEFAULT CURRENT_TIMESTAMP,
    `updated_at`         DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_internal_charges_league_status` (`league_id`, `status`, `due_date`),
    KEY `idx_internal_charges_subject` (`subject_type`, `subject_id`, `status`),
    KEY `idx_internal_charges_tournament` (`tournament_id`),
    KEY `idx_internal_charges_match` (`match_id`),
    KEY `idx_internal_charges_created_by` (`created_by_user_id`),
    CONSTRAINT `fk_internal_charges_league` FOREIGN KEY (`league_id`) REFERENCES `leagues` (`id`),
    CONSTRAINT `fk_internal_charges_tournament` FOREIGN KEY (`tournament_id`) REFERENCES `tournaments` (`id`),
    CONSTRAINT `fk_internal_charges_match` FOREIGN KEY (`match_id`) REFERENCES `matches` (`id`) ON DELETE SET NULL,
    CONSTRAINT `fk_internal_charges_created_by` FOREIGN KEY (`created_by_user_id`) REFERENCES `users` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- payments: un pago de suscripción de cuenta o de un cobro interno.
-- payable_id apunta a account_subscriptions.id o internal_charges.id (sin FK).
-- 'pending_review' = depósito/transferencia reportado, falta que lo validen.
CREATE TABLE IF NOT EXISTS `payments` (
    `id`                  BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `payable_type`        ENUM('account_subscription','internal_charge') NOT NULL,
    `payable_id`          BIGINT UNSIGNED NOT NULL,
    `provider`            ENUM('mercadopago','manual','revenuecat') NOT NULL,
    `amount`              DECIMAL(10,2) NOT NULL,
    `currency`            CHAR(3) NOT NULL DEFAULT 'MXN',
    `status`              ENUM('pending','pending_review','approved','rejected','refunded') NOT NULL DEFAULT 'pending',
    `provider_reference`  VARCHAR(190) NULL,
    `receipt_url`         VARCHAR(500) NULL,
    `metadata`            JSON NULL,
    `reported_by_user_id` BIGINT UNSIGNED NULL,
    `reviewed_by_user_id` BIGINT UNSIGNED NULL,
    `paid_at`             DATETIME NULL,
    `created_at`          DATETIME DEFAULT CURRENT_TIMESTAMP,
    `updated_at`          DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uq_payments_provider_ref` (`provider`, `provider_reference`),
    KEY `idx_payments_payable` (`payable_type`, `payable_id`),
    KEY `idx_payments_status` (`status`, `created_at`),
    KEY `idx_payments_reported_by` (`reported_by_user_id`),
    KEY `idx_payments_reviewed_by` (`reviewed_by_user_id`),
    CONSTRAINT `fk_payments_reported_by` FOREIGN KEY (`reported_by_user_id`) REFERENCES `users` (`id`) ON DELETE SET NULL,
    CONSTRAINT `fk_payments_reviewed_by` FOREIGN KEY (`reviewed_by_user_id`) REFERENCES `users` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =============================================================
-- 9. NOTIFICACIONES Y PERFIL SOCIAL
-- =============================================================

-- notifications: dedupe_key evita que el cron programe dos veces el mismo
-- recordatorio (ej. "match:123:reminder_1h:user:45").
CREATE TABLE IF NOT EXISTS `notifications` (
    `id`           BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `user_id`      BIGINT UNSIGNED NOT NULL,
    `type`         VARCHAR(50)  NOT NULL,
    `title`        VARCHAR(150) NULL,
    `body`         VARCHAR(500) NULL,
    `payload`      JSON NULL,
    `channel`      ENUM('push','email') NOT NULL DEFAULT 'push',
    `dedupe_key`   VARCHAR(150) NULL,
    `scheduled_at` DATETIME NOT NULL,
    `sent_at`      DATETIME NULL,
    `read_at`      DATETIME NULL,
    `status`       ENUM('scheduled','sent','failed','canceled') NOT NULL DEFAULT 'scheduled',
    `created_at`   DATETIME DEFAULT CURRENT_TIMESTAMP,
    `updated_at`   DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uq_notifications_dedupe` (`dedupe_key`),
    KEY `idx_notifications_dispatch` (`status`, `scheduled_at`),
    KEY `idx_notifications_user` (`user_id`, `created_at`),
    CONSTRAINT `fk_notifications_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `notification_preferences` (
    `id`         BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `user_id`    BIGINT UNSIGNED NOT NULL,
    `type`       VARCHAR(50) NOT NULL,
    `enabled`    TINYINT(1)  NOT NULL DEFAULT 1,
    `created_at` DATETIME DEFAULT CURRENT_TIMESTAMP,
    `updated_at` DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uq_notification_preferences` (`user_id`, `type`),
    CONSTRAINT `fk_notification_preferences_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- shared_cards: tarjetas compartibles del jugador ("goleador de la liga").
-- scope_id apunta a teams/leagues/tournaments según scope (sin FK).
CREATE TABLE IF NOT EXISTS `shared_cards` (
    `id`         BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `player_id`  BIGINT UNSIGNED NOT NULL,
    `scope`      ENUM('career','team','league','tournament') NOT NULL,
    `scope_id`   BIGINT UNSIGNED NULL,
    `card_type`  VARCHAR(50)  NOT NULL,
    `image_url`  VARCHAR(500) NULL,
    `shared_at`  DATETIME NULL,
    `created_at` DATETIME DEFAULT CURRENT_TIMESTAMP,
    `updated_at` DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_shared_cards_player` (`player_id`),
    CONSTRAINT `fk_shared_cards_player` FOREIGN KEY (`player_id`) REFERENCES `players` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =============================================================
-- 10. CONFIG (D7)
-- =============================================================

-- config: parámetros en cascada torneo > liga > global.
-- scope_id = 0 para 'global' (no NULL, para que el UNIQUE funcione).
-- league_editable solo aplica a filas globales: indica si el admin de liga
-- puede sobrescribir esa clave para su liga o sus torneos.
CREATE TABLE IF NOT EXISTS `config` (
    `id`              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `scope`           ENUM('global','league','tournament') NOT NULL DEFAULT 'global',
    `scope_id`        BIGINT UNSIGNED NOT NULL DEFAULT 0,
    `config_key`      VARCHAR(100) NOT NULL,
    `value`           TEXT NULL,
    `value_type`      ENUM('string','int','bool','json') NOT NULL DEFAULT 'string',
    `description`     VARCHAR(255) NULL,
    `league_editable` TINYINT(1) NOT NULL DEFAULT 0,
    `created_at`      DATETIME DEFAULT CURRENT_TIMESTAMP,
    `updated_at`      DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uq_config_scope_key` (`scope`, `scope_id`, `config_key`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

SET FOREIGN_KEY_CHECKS = 1;

-- =============================================================
-- SEEDS (migración 002)
-- =============================================================

-- -------------------------------------------------------------
-- sports
-- -------------------------------------------------------------
INSERT INTO `sports` (`code`, `name`, `score_unit`, `has_periods`, `allows_draw`) VALUES
('futbol',  'Fútbol',     'goles',  0, 1),
('basquet', 'Básquetbol', 'puntos', 1, 0),
('voley',   'Voleibol',   'sets',   1, 0),
('padel',   'Pádel',      'sets',   1, 0),
('tenis',   'Tenis',      'sets',   1, 0)
ON DUPLICATE KEY UPDATE
    `name` = VALUES(`name`), `score_unit` = VALUES(`score_unit`),
    `has_periods` = VALUES(`has_periods`), `allows_draw` = VALUES(`allows_draw`);

-- -------------------------------------------------------------
-- event_types — fútbol
-- -------------------------------------------------------------
INSERT INTO `event_types` (`sport_id`, `code`, `name`, `category`, `score_value`, `is_sending_off`, `color`, `sort_order`)
SELECT s.`id`, t.`code`, t.`name`, t.`category`, t.`score_value`, t.`is_sending_off`, t.`color`, t.`sort_order`
FROM `sports` s
JOIN (
    SELECT 'gol' AS `code`, 'Gol' AS `name`, 'score' AS `category`, 1 AS `score_value`, 0 AS `is_sending_off`, NULL AS `color`, 10 AS `sort_order`
    UNION ALL SELECT 'gol_penal',        'Gol de penal',         'score',      1, 0, NULL,      20
    UNION ALL SELECT 'autogol',          'Autogol',              'score',      1, 0, NULL,      30
    UNION ALL SELECT 'asistencia',       'Asistencia',           'other',      0, 0, NULL,      40
    UNION ALL SELECT 'tarjeta_amarilla', 'Tarjeta amarilla',     'discipline', 0, 0, '#FFD600', 50
    UNION ALL SELECT 'tarjeta_roja',     'Tarjeta roja',         'discipline', 0, 1, '#E53935', 60
    UNION ALL SELECT 'penal_fallado',    'Penal fallado',        'other',      0, 0, NULL,      70
    UNION ALL SELECT 'tanda_anotado',    'Penal de tanda anotado', 'other',    0, 0, NULL,      80
    UNION ALL SELECT 'tanda_fallado',    'Penal de tanda fallado', 'other',    0, 0, NULL,      90
    UNION ALL SELECT 'cambio',           'Cambio',               'other',      0, 0, NULL,      100
    UNION ALL SELECT 'mvp',              'Jugador del partido',  'other',      0, 0, NULL,      110
) t
WHERE s.`code` = 'futbol'
ON DUPLICATE KEY UPDATE
    `name` = VALUES(`name`), `category` = VALUES(`category`), `score_value` = VALUES(`score_value`),
    `is_sending_off` = VALUES(`is_sending_off`), `color` = VALUES(`color`), `sort_order` = VALUES(`sort_order`);

-- -------------------------------------------------------------
-- event_types — básquetbol
-- -------------------------------------------------------------
INSERT INTO `event_types` (`sport_id`, `code`, `name`, `category`, `score_value`, `is_sending_off`, `color`, `sort_order`)
SELECT s.`id`, t.`code`, t.`name`, t.`category`, t.`score_value`, t.`is_sending_off`, t.`color`, t.`sort_order`
FROM `sports` s
JOIN (
    SELECT 'tiro_libre' AS `code`, 'Tiro libre' AS `name`, 'score' AS `category`, 1 AS `score_value`, 0 AS `is_sending_off`, NULL AS `color`, 10 AS `sort_order`
    UNION ALL SELECT 'canasta_2',           'Canasta de 2',        'score',      2, 0, NULL,      20
    UNION ALL SELECT 'canasta_3',           'Canasta de 3',        'score',      3, 0, NULL,      30
    UNION ALL SELECT 'asistencia',          'Asistencia',          'other',      0, 0, NULL,      40
    UNION ALL SELECT 'rebote',              'Rebote',              'other',      0, 0, NULL,      50
    UNION ALL SELECT 'falta_personal',      'Falta personal',      'discipline', 0, 0, '#FFD600', 60
    UNION ALL SELECT 'falta_tecnica',       'Falta técnica',       'discipline', 0, 0, '#FB8C00', 70
    UNION ALL SELECT 'falta_antideportiva', 'Falta antideportiva', 'discipline', 0, 0, '#FB8C00', 80
    UNION ALL SELECT 'descalificacion',     'Descalificación',     'discipline', 0, 1, '#E53935', 90
    UNION ALL SELECT 'mvp',                 'Jugador del partido', 'other',      0, 0, NULL,      100
) t
WHERE s.`code` = 'basquet'
ON DUPLICATE KEY UPDATE
    `name` = VALUES(`name`), `category` = VALUES(`category`), `score_value` = VALUES(`score_value`),
    `is_sending_off` = VALUES(`is_sending_off`), `color` = VALUES(`color`), `sort_order` = VALUES(`sort_order`);

-- -------------------------------------------------------------
-- event_types — voleibol
-- -------------------------------------------------------------
INSERT INTO `event_types` (`sport_id`, `code`, `name`, `category`, `score_value`, `is_sending_off`, `color`, `sort_order`)
SELECT s.`id`, t.`code`, t.`name`, t.`category`, t.`score_value`, t.`is_sending_off`, t.`color`, t.`sort_order`
FROM `sports` s
JOIN (
    SELECT 'punto_ataque' AS `code`, 'Punto de ataque' AS `name`, 'score' AS `category`, 1 AS `score_value`, 0 AS `is_sending_off`, NULL AS `color`, 10 AS `sort_order`
    UNION ALL SELECT 'punto_saque',      'Punto de saque (ace)', 'score',      1, 0, NULL,      20
    UNION ALL SELECT 'punto_bloqueo',    'Punto de bloqueo',     'score',      1, 0, NULL,      30
    UNION ALL SELECT 'tarjeta_amarilla', 'Tarjeta amarilla',     'discipline', 0, 0, '#FFD600', 40
    UNION ALL SELECT 'tarjeta_roja',     'Tarjeta roja',         'discipline', 0, 0, '#E53935', 50
    UNION ALL SELECT 'expulsion',        'Expulsión',            'discipline', 0, 1, '#E53935', 60
    UNION ALL SELECT 'descalificacion',  'Descalificación',      'discipline', 0, 1, '#E53935', 70
    UNION ALL SELECT 'mvp',              'Jugador del partido',  'other',      0, 0, NULL,      80
) t
WHERE s.`code` = 'voley'
ON DUPLICATE KEY UPDATE
    `name` = VALUES(`name`), `category` = VALUES(`category`), `score_value` = VALUES(`score_value`),
    `is_sending_off` = VALUES(`is_sending_off`), `color` = VALUES(`color`), `sort_order` = VALUES(`sort_order`);

-- -------------------------------------------------------------
-- event_types — pádel y tenis (mismo catálogo)
-- -------------------------------------------------------------
INSERT INTO `event_types` (`sport_id`, `code`, `name`, `category`, `score_value`, `is_sending_off`, `color`, `sort_order`)
SELECT s.`id`, t.`code`, t.`name`, t.`category`, t.`score_value`, t.`is_sending_off`, t.`color`, t.`sort_order`
FROM `sports` s
JOIN (
    SELECT 'ace' AS `code`, 'Ace' AS `name`, 'other' AS `category`, 0 AS `score_value`, 0 AS `is_sending_off`, NULL AS `color`, 10 AS `sort_order`
    UNION ALL SELECT 'doble_falta',         'Doble falta',            'other',      0, 0, NULL,      20
    UNION ALL SELECT 'winner',              'Golpe ganador',          'other',      0, 0, NULL,      30
    UNION ALL SELECT 'advertencia',         'Advertencia',            'discipline', 0, 0, '#FFD600', 40
    UNION ALL SELECT 'punto_penalizacion',  'Punto de penalización',  'discipline', 0, 0, '#FB8C00', 50
    UNION ALL SELECT 'descalificacion',     'Descalificación',        'discipline', 0, 1, '#E53935', 60
    UNION ALL SELECT 'mvp',                 'Jugador del partido',    'other',      0, 0, NULL,      70
) t
WHERE s.`code` IN ('padel', 'tenis')
ON DUPLICATE KEY UPDATE
    `name` = VALUES(`name`), `category` = VALUES(`category`), `score_value` = VALUES(`score_value`),
    `is_sending_off` = VALUES(`is_sending_off`), `color` = VALUES(`color`), `sort_order` = VALUES(`sort_order`);

-- -------------------------------------------------------------
-- event_types — incidencias por deporte (migración 011)
-- -------------------------------------------------------------
-- Incidencias que faltaban en cada deporte: cambios, salidas por lesión,
-- tiempos muertos y la segunda amarilla.
INSERT INTO `event_types` (`sport_id`, `code`, `name`, `category`, `score_value`, `is_sending_off`, `color`, `sort_order`)
SELECT s.`id`, t.`code`, t.`name`, t.`category`, t.`score_value`, t.`is_sending_off`, t.`color`, t.`sort_order`
FROM `sports` s
JOIN (
    SELECT 'futbol' AS `sport`, 'segunda_amarilla' AS `code`, 'Segunda amarilla (expulsión)' AS `name`, 'discipline' AS `category`, 0 AS `score_value`, 1 AS `is_sending_off`, '#E53935' AS `color`, 55 AS `sort_order`
    UNION ALL SELECT 'futbol',  'salida_lesion',   'Salida por lesión', 'other', 0, 0, NULL, 105
    UNION ALL SELECT 'basquet', 'cambio',          'Cambio',            'other', 0, 0, NULL, 92
    UNION ALL SELECT 'basquet', 'salida_lesion',   'Salida por lesión', 'other', 0, 0, NULL, 94
    UNION ALL SELECT 'basquet', 'tiempo_muerto',   'Tiempo muerto',     'other', 0, 0, NULL, 96
    UNION ALL SELECT 'voley',   'cambio',          'Cambio',            'other', 0, 0, NULL, 72
    UNION ALL SELECT 'voley',   'salida_lesion',   'Salida por lesión', 'other', 0, 0, NULL, 74
    UNION ALL SELECT 'voley',   'tiempo_muerto',   'Tiempo muerto',     'other', 0, 0, NULL, 76
    UNION ALL SELECT 'padel',   'atencion_medica', 'Atención médica',   'other', 0, 0, NULL, 62
    UNION ALL SELECT 'padel',   'retiro_lesion',   'Retiro por lesión', 'other', 0, 0, NULL, 64
    UNION ALL SELECT 'tenis',   'atencion_medica', 'Atención médica',   'other', 0, 0, NULL, 62
    UNION ALL SELECT 'tenis',   'retiro_lesion',   'Retiro por lesión', 'other', 0, 0, NULL, 64
) t ON t.`sport` = s.`code`
ON DUPLICATE KEY UPDATE
    `name` = VALUES(`name`), `category` = VALUES(`category`), `score_value` = VALUES(`score_value`),
    `is_sending_off` = VALUES(`is_sending_off`), `color` = VALUES(`color`), `sort_order` = VALUES(`sort_order`);

-- A quién involucra cada incidencia:
--   two      → dos jugadores del mismo equipo (cambio: quién sale y quién entra)
--   required → siempre lleva jugador (sanciones, lesiones, jugador del partido)
--   none     → es del equipo, sin jugador (tiempo muerto)
--   optional → el jugador se puede dejar sin especificar (lo demás)
UPDATE `event_types` SET `player_scope` = 'two' WHERE `code` = 'cambio';
UPDATE `event_types` SET `player_scope` = 'none' WHERE `code` = 'tiempo_muerto';
UPDATE `event_types` SET `player_scope` = 'required'
WHERE `category` = 'discipline' OR `code` IN ('salida_lesion', 'retiro_lesion', 'atencion_medica', 'mvp');

-- -------------------------------------------------------------
-- packages — sin paquete gratuito (D13). La prueba corre en 'liga_1x1'.
-- PRECIOS EN 0.00: pendientes de definir por el dueño de la plataforma.
-- El ON DUPLICATE no toca precios para no pisar los que se capturen después.
-- -------------------------------------------------------------
INSERT INTO `packages` (`code`, `name`, `max_leagues`, `max_tournaments_per_league`, `price_monthly`, `price_yearly`, `sort_order`) VALUES
('liga_1x1', 'Básico — 1 liga, 1 torneo',            1, 1, 0.00, 0.00, 10),
('liga_1x2', '1 liga, 2 torneos',                    1, 2, 0.00, 0.00, 20),
('liga_2x2', '2 ligas, 2 torneos por liga',          2, 2, 0.00, 0.00, 30),
('liga_3x3', '3 ligas, 3 torneos por liga',          3, 3, 0.00, 0.00, 40)
ON DUPLICATE KEY UPDATE
    `name` = VALUES(`name`), `max_leagues` = VALUES(`max_leagues`),
    `max_tournaments_per_league` = VALUES(`max_tournaments_per_league`), `sort_order` = VALUES(`sort_order`);

-- =============================================================
-- SEEDS (migración 003)
-- =============================================================

INSERT INTO `config` (`scope`, `scope_id`, `config_key`, `value`, `value_type`, `description`, `league_editable`) VALUES

-- Plataforma (solo super admin)
('global', 0, 'TRIAL_DAYS',              '30',       'int',    'Días de prueba de una cuenta nueva; se materializa en trial_ends_at al registrarse', 0),
('global', 0, 'TRIAL_PACKAGE_CODE',      'liga_1x1', 'string', 'Paquete en el que corre toda prueba (siempre el básico)', 0),
('global', 0, 'YEARLY_DISCOUNT_PERCENT', '10',       'int',    'Descuento informativo del pago anual frente al mensual', 0),
('global', 0, 'ADS_ENABLED_DEFAULT',     '0',        'bool',   'Valor inicial de accounts.ads_enabled en cuentas nuevas', 0),
('global', 0, 'PAGINATION_DEFAULT',      '20',       'int',    'Tamaño de página por defecto en listados', 0),
('global', 0, 'PHOTO_MAX_SIZE_MB',       '10',       'int',    'Tamaño máximo de imagen en MB', 0),
('global', 0, 'PAYMENT_MODEL_DEFAULT',   'league_pays', 'string', 'Quién paga la plataforma en las ligas nuevas: league_pays (la liga) o teams_pay (los equipos)', 0),
('global', 0, 'APP_MIN_VERSION_IOS',     '1.0.0', 'string', 'Versión mínima de la app en iOS (x.y.z); por debajo, obliga a actualizar', 0),
('global', 0, 'APP_MIN_VERSION_ANDROID', '1.0.0', 'string', 'Versión mínima de la app en Android (x.y.z); por debajo, obliga a actualizar', 0),
('global', 0, 'APP_STORE_URL_IOS',       '',      'string', 'Enlace de la app en App Store', 0),
('global', 0, 'APP_STORE_URL_ANDROID',   '',      'string', 'Enlace de la app en Google Play', 0),
('global', 0, 'ROSTER_LIMIT_LEAGUES_DECIDE',      '0',  'bool', 'Todas las ligas pueden fijar su propio máximo de jugadores por equipo', 0),
('global', 0, 'FUTBOL_MAX_JUGADORES_POR_EQUIPO',  '25', 'int',  'Máximo de jugadores por equipo (0 = sin límite)', 0),
('global', 0, 'BASQUET_MAX_JUGADORES_POR_EQUIPO', '15', 'int',  'Máximo de jugadores por equipo (0 = sin límite)', 0),
('global', 0, 'VOLEY_MAX_JUGADORES_POR_EQUIPO',   '14', 'int',  'Máximo de jugadores por equipo (0 = sin límite)', 0),
('global', 0, 'PADEL_MAX_JUGADORES_POR_EQUIPO',   '2',  'int',  'Máximo de jugadores por pareja en dobles (0 = sin límite; en individual siempre es 1)', 0),
('global', 0, 'TENIS_MAX_JUGADORES_POR_EQUIPO',   '2',  'int',  'Máximo de jugadores por pareja en dobles (0 = sin límite; en individual siempre es 1)', 0),
('global', 0, 'PLAYER_SELF_REGISTRATION_ENABLED', '1', 'bool', 'Permitir que un jugador se registre por su cuenta sin invitación de un equipo', 0),

-- Operación de la liga (el admin de liga las ajusta)
('global', 0, 'IDENTITY_VERIFICATION_MODE',     'flexible', 'string', 'strict = solo juegan registrados y verificados; flexible = se admiten invitados', 1),
('global', 0, 'MATCH_SHEET_SIGNATURE_MODE',     'accept',   'string', 'accept = gesto de aceptación; drawn = además trazo de firma', 1),
('global', 0, 'MATCH_SHEET_CLAIM_WINDOW_HOURS', '48',       'int',    'Horas para firmar la cédula o reclamar desde que se captura el marcador', 1),
('global', 0, 'BLOCK_MATCH_ON_UNPAID_FEES',     '0',        'bool',   'Bloquear el partido de un equipo con adeudos vencidos', 1),
('global', 0, 'SANCION_MULTA_MONTO',           '0',        'int',    'Multa al equipo por cada sanción automática de un jugador (0 = sin multa)', 1),
('global', 0, 'SANCION_MULTA_LEVANTA',         '0',        'bool',   'Al pagar la multa se levanta la sanción del jugador', 1),
('global', 0, 'NOTIF_RECORDATORIO_1_DIA_ENABLED',  '1',     'bool',   'Recordatorio de partido un día antes', 1),
('global', 0, 'NOTIF_RECORDATORIO_1_HORA_ENABLED', '1',     'bool',   'Recordatorio de partido una hora antes', 1),

-- Fútbol
('global', 0, 'FUTBOL_PUNTOS_GANADOR',            '3', 'int',  'Puntos por partido ganado', 1),
('global', 0, 'FUTBOL_PUNTOS_EMPATE',             '1', 'int',  'Puntos por empate', 1),
('global', 0, 'FUTBOL_PUNTOS_PERDEDOR',           '0', 'int',  'Puntos por partido perdido', 1),
('global', 0, 'FUTBOL_DESEMPATE_PENALES_ENABLED', '0', 'bool', 'En fase regular, desempatar por penales', 1),
('global', 0, 'FUTBOL_PUNTO_EXTRA_PENALES',       '1', 'int',  'Punto extra al ganador de los penales de desempate', 1),
('global', 0, 'FUTBOL_GOL_VISITANTE_ENABLED',     '0', 'bool', 'En llaves a ida y vuelta, el gol de visitante desempata', 1),
('global', 0, 'FUTBOL_AMARILLAS_PARA_SUSPENSION', '5', 'int',  'Amarillas acumuladas que generan un partido de suspensión (0 = no aplica)', 1),
('global', 0, 'FUTBOL_PARTIDOS_POR_ROJA',         '1', 'int',  'Partidos de suspensión por tarjeta roja', 1),
('global', 0, 'FUTBOL_MINUTOS_POR_TIEMPO',         '45', 'int', 'Minutos de cada tiempo', 1),
('global', 0, 'FUTBOL_REINGRESO_ENABLED',          '1', 'bool', 'Cambios libres: un jugador que salió de cambio puede volver a entrar', 1),

-- Básquetbol
('global', 0, 'BASQUET_PUNTOS_GANADOR',          '2', 'int', 'Puntos de tabla por partido ganado', 1),
('global', 0, 'BASQUET_PUNTOS_PERDEDOR',         '1', 'int', 'Puntos de tabla por partido perdido', 1),
('global', 0, 'BASQUET_PERIODOS',                '4', 'int', 'Número de periodos reglamentarios', 1),
('global', 0, 'BASQUET_FALTAS_PARA_EXPULSION',   '5', 'int', 'Faltas personales que sacan al jugador del partido', 1),
('global', 0, 'BASQUET_PARTIDOS_POR_DESCALIFICACION', '1', 'int', 'Partidos de suspensión por descalificación', 1),
('global', 0, 'BASQUET_MINUTOS_POR_PERIODO',    '10', 'int', 'Minutos de cada periodo', 1),
('global', 0, 'BASQUET_PUNTOS_INCOMPARECENCIA', '0',  'int', 'Puntos de tabla para el equipo que pierde por no presentarse', 1),

-- Voleibol
('global', 0, 'VOLEY_PUNTOS_GANADOR',  '3', 'int', 'Puntos de tabla por partido ganado', 1),
('global', 0, 'VOLEY_PUNTOS_PERDEDOR', '0', 'int', 'Puntos de tabla por partido perdido', 1),
('global', 0, 'VOLEY_SETS_PARA_GANAR', '3', 'int', 'Sets necesarios para ganar el partido', 1),
('global', 0, 'VOLEY_PUNTOS_GANADOR_SET_DECISIVO',  '2',  'int', 'Puntos de tabla por ganar en el set decisivo (ej. 3-2)', 1),
('global', 0, 'VOLEY_PUNTOS_PERDEDOR_SET_DECISIVO', '1',  'int', 'Puntos de tabla por perder en el set decisivo (ej. 2-3)', 1),
('global', 0, 'VOLEY_PUNTOS_POR_SET',               '25', 'int', 'Puntos para ganar un set', 1),
('global', 0, 'VOLEY_PUNTOS_SET_DECISIVO',          '15', 'int', 'Puntos para ganar el set decisivo', 1),

-- Pádel
('global', 0, 'PADEL_PUNTOS_GANADOR',  '3', 'int', 'Puntos de tabla por partido ganado', 1),
('global', 0, 'PADEL_PUNTOS_PERDEDOR', '0', 'int', 'Puntos de tabla por partido perdido', 1),
('global', 0, 'PADEL_SETS_PARA_GANAR', '2', 'int', 'Sets necesarios para ganar el partido', 1),
('global', 0, 'PADEL_JUEGOS_POR_SET',          '6', 'int',  'Juegos para ganar un set', 1),
('global', 0, 'PADEL_SUPER_TIEBREAK_ENABLED',  '1', 'bool', 'El set decisivo se juega a súper tie-break de 10 puntos', 1),
('global', 0, 'PADEL_PUNTO_DE_ORO_ENABLED',    '1', 'bool', 'Con 40 iguales se juega punto de oro (sin ventaja)', 1),

-- Tenis
('global', 0, 'TENIS_PUNTOS_GANADOR',  '3', 'int', 'Puntos de tabla por partido ganado', 1),
('global', 0, 'TENIS_PUNTOS_PERDEDOR', '0', 'int', 'Puntos de tabla por partido perdido', 1),
('global', 0, 'TENIS_SETS_PARA_GANAR', '2', 'int', 'Sets necesarios para ganar el partido', 1),
('global', 0, 'TENIS_JUEGOS_POR_SET',          '6', 'int',  'Juegos para ganar un set', 1),
('global', 0, 'TENIS_SUPER_TIEBREAK_ENABLED',  '0', 'bool', 'El set decisivo se juega a súper tie-break de 10 puntos', 1),
('global', 0, 'TENIS_SIN_VENTAJA_ENABLED',     '0', 'bool', 'Con 40 iguales se juega punto decisivo (sin ventaja)', 1)

ON DUPLICATE KEY UPDATE
    `value_type` = VALUES(`value_type`),
    `description` = VALUES(`description`),
    `league_editable` = VALUES(`league_editable`);
