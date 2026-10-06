-- =============================================================
-- Migración 014 — Vetos de liga y multas ligadas a una sanción
-- Idempotente: tabla con IF NOT EXISTS; columnas, índice y FK vía
-- information_schema + PREPARE; el MODIFY del ENUM se puede repetir;
-- configuración con ON DUPLICATE KEY (no pisa `value`).
-- =============================================================

SET NAMES utf8mb4;

-- Una sanción puede llevar una multa al equipo del jugador (un cargo de
-- internal_charges, tipo 'multa'). Si `fine_lifts` = 1, al quedar pagada
-- la multa la sanción se levanta: status 'lifted'. Si es 0, la multa se
-- cobra y la sanción se cumple igual.
SET @sql = (SELECT IF(COUNT(*) = 0,
    'ALTER TABLE `player_suspensions` ADD COLUMN `fine_charge_id` BIGINT UNSIGNED NULL AFTER `reason`',
    'SELECT 1')
    FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'player_suspensions' AND COLUMN_NAME = 'fine_charge_id');
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @sql = (SELECT IF(COUNT(*) = 0,
    'ALTER TABLE `player_suspensions` ADD COLUMN `fine_lifts` TINYINT(1) NOT NULL DEFAULT 0 AFTER `fine_charge_id`',
    'SELECT 1')
    FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'player_suspensions' AND COLUMN_NAME = 'fine_lifts');
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @sql = (SELECT IF(COUNT(*) = 0,
    'ALTER TABLE `player_suspensions` ADD KEY `idx_player_suspensions_fine` (`fine_charge_id`), ADD CONSTRAINT `fk_player_suspensions_fine` FOREIGN KEY (`fine_charge_id`) REFERENCES `internal_charges` (`id`) ON DELETE SET NULL',
    'SELECT 1')
    FROM information_schema.TABLE_CONSTRAINTS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'player_suspensions' AND CONSTRAINT_NAME = 'fk_player_suspensions_fine');
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

ALTER TABLE `player_suspensions`
    MODIFY COLUMN `status` ENUM('active','served','revoked','lifted') NOT NULL DEFAULT 'active';

-- Veto de liga: para problemas que escalan, la liga saca a un jugador de
-- todos sus torneos. Mientras esté activo (y no haya vencido `ends_on`,
-- si lo tiene) no puede ser alineado ni dado de alta en ningún equipo.
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

-- Multa automática: cada liga (o torneo) decide si una sanción que sale
-- de la cédula le cuesta al equipo, cuánto, y si pagarla la levanta.
INSERT INTO `config` (`scope`, `scope_id`, `config_key`, `value`, `value_type`, `description`, `league_editable`) VALUES
('global', 0, 'SANCION_MULTA_MONTO',   '0', 'int',  'Multa al equipo por cada sanción automática de un jugador (0 = sin multa)', 1),
('global', 0, 'SANCION_MULTA_LEVANTA', '0', 'bool', 'Al pagar la multa se levanta la sanción del jugador', 1)
ON DUPLICATE KEY UPDATE
    `value_type` = VALUES(`value_type`),
    `description` = VALUES(`description`),
    `league_editable` = VALUES(`league_editable`);
