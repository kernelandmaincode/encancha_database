-- =============================================================
-- Migración 016 — Multas por incidencia, definidas por la liga
-- Idempotente: tabla con IF NOT EXISTS; columna, índice y FK vía
-- information_schema + PREPARE; configuración con ON DUPLICATE KEY.
-- =============================================================

SET NAMES utf8mb4;

-- Cada liga decide, por tipo de incidencia de su deporte (tarjeta amarilla,
-- roja, falta técnica, descalificación…), cuánto le cuesta al equipo. Si la
-- incidencia además sanciona al jugador (una expulsión), `lifts_suspension`
-- dice si pagar la multa levanta la sanción o si se cobra y se cumple igual.
CREATE TABLE IF NOT EXISTS `league_fine_rules` (
    `id`               BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `league_id`        BIGINT UNSIGNED NOT NULL,
    `event_type_id`    BIGINT UNSIGNED NOT NULL,
    `amount`           DECIMAL(10,2) NOT NULL,
    `lifts_suspension` TINYINT(1) NOT NULL DEFAULT 0,
    `created_at`       DATETIME DEFAULT CURRENT_TIMESTAMP,
    `updated_at`       DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uq_league_fine_rules` (`league_id`, `event_type_id`),
    KEY `idx_league_fine_rules_event_type` (`event_type_id`),
    CONSTRAINT `fk_league_fine_rules_league` FOREIGN KEY (`league_id`) REFERENCES `leagues` (`id`) ON DELETE CASCADE,
    CONSTRAINT `fk_league_fine_rules_event_type` FOREIGN KEY (`event_type_id`) REFERENCES `event_types` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- internal_charges.origin_match_event_id: la incidencia que originó una
-- multa automática sin sanción (una amarilla). Con ella no se cobra dos veces
-- al recapturar, y si la incidencia se quita la multa sin pagar se cancela.
SET @sql = (SELECT IF(COUNT(*) = 0,
    'ALTER TABLE `internal_charges` ADD COLUMN `origin_match_event_id` BIGINT UNSIGNED NULL AFTER `match_id`',
    'SELECT 1')
    FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'internal_charges' AND COLUMN_NAME = 'origin_match_event_id');
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @sql = (SELECT IF(COUNT(*) = 0,
    'ALTER TABLE `internal_charges` ADD KEY `idx_internal_charges_origin_event` (`origin_match_event_id`), ADD CONSTRAINT `fk_internal_charges_origin_event` FOREIGN KEY (`origin_match_event_id`) REFERENCES `match_events` (`id`) ON DELETE SET NULL',
    'SELECT 1')
    FROM information_schema.TABLE_CONSTRAINTS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'internal_charges' AND CONSTRAINT_NAME = 'fk_internal_charges_origin_event');
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- El monto general queda para las sanciones automáticas sin monto propio.
INSERT INTO `config` (`scope`, `scope_id`, `config_key`, `value`, `value_type`, `description`, `league_editable`) VALUES
('global', 0, 'SANCION_MULTA_MONTO',   '0', 'int',  'Multa al equipo por una sanción automática sin monto propio, como la acumulación de tarjetas (0 = sin multa)', 1),
('global', 0, 'SANCION_MULTA_LEVANTA', '0', 'bool', 'Al pagar esa multa general se levanta la sanción del jugador', 1)
ON DUPLICATE KEY UPDATE
    `description` = VALUES(`description`);
