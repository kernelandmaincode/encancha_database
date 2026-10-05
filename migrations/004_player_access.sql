-- =============================================================
-- Migración 004 — Acceso de jugadores a la app (D18)
-- Idempotente: CREATE TABLE IF NOT EXISTS, MODIFY COLUMN, ON DUPLICATE KEY
-- Fuente: ENCANCHA_PHASE2_DESIGN.md D18
-- =============================================================

SET NAMES utf8mb4;

-- invitations: las dos puertas de entrada de un jugador.
--   player_claim → enlace que el delegado manda a un jugador que él dio de
--                  alta; al registrarse, la cuenta se liga a ese perfil.
--                  Se guarda solo el SHA-256 del token (token_hash).
--   team_join    → código corto del equipo en un torneo; quien lo captura
--                  pide entrar al plantel. Se guarda en claro (code) porque
--                  el delegado necesita volver a verlo y compartirlo.
CREATE TABLE IF NOT EXISTS `invitations` (
    `id`                 BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `type`               ENUM('player_claim','team_join') NOT NULL,
    `code`               VARCHAR(12) NULL,
    `token_hash`         CHAR(64)    NULL,
    `player_id`          BIGINT UNSIGNED NULL,
    `tournament_team_id` BIGINT UNSIGNED NULL,
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
    KEY `idx_invitations_created_by` (`created_by_user_id`),
    CONSTRAINT `fk_invitations_player` FOREIGN KEY (`player_id`) REFERENCES `players` (`id`) ON DELETE CASCADE,
    CONSTRAINT `fk_invitations_tt` FOREIGN KEY (`tournament_team_id`) REFERENCES `tournament_teams` (`id`) ON DELETE CASCADE,
    CONSTRAINT `fk_invitations_created_by` FOREIGN KEY (`created_by_user_id`) REFERENCES `users` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- tournament_rosters.status gana 'requested': el jugador pidió entrar con un
-- código y falta que el delegado lo acepte. Después sigue el flujo normal
-- (pending → approved/rejected por el admin de liga).
ALTER TABLE `tournament_rosters`
    MODIFY COLUMN `status` ENUM('requested','pending','approved','rejected') NOT NULL DEFAULT 'pending';

-- Interruptor del registro libre de jugadores (solo super admin).
-- Apagado: solo se puede crear cuenta de jugador con una invitación.
INSERT INTO `config` (`scope`, `scope_id`, `config_key`, `value`, `value_type`, `description`, `league_editable`) VALUES
('global', 0, 'PLAYER_SELF_REGISTRATION_ENABLED', '1', 'bool', 'Permitir que un jugador se registre por su cuenta sin invitación de un equipo', 0)
ON DUPLICATE KEY UPDATE
    `value_type` = VALUES(`value_type`),
    `description` = VALUES(`description`),
    `league_editable` = VALUES(`league_editable`);
