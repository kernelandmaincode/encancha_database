-- =============================================================
-- Migración 010 — Límite de jugadores por equipo
-- Idempotente: columna vía information_schema + PREPARE; claves con
-- ON DUPLICATE KEY (no pisa `value`).
-- =============================================================

SET NAMES utf8mb4;

-- leagues.roster_limit_unlocked: el super admin libera a esta liga para
-- que fije su propio máximo de jugadores por equipo. Con 0 rige el
-- parámetro global (salvo que ROSTER_LIMIT_LEAGUES_DECIDE libere a todas).
SET @sql = (SELECT IF(COUNT(*) = 0,
    'ALTER TABLE `leagues` ADD COLUMN `roster_limit_unlocked` TINYINT(1) NOT NULL DEFAULT 0 AFTER `public_code`',
    'SELECT 1')
    FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'leagues' AND COLUMN_NAME = 'roster_limit_unlocked');
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- Máximo de jugadores vigentes por equipo en un torneo, por deporte
-- (0 = sin límite). En pádel y tenis aplica a dobles; en individual
-- siempre es 1. league_editable = 0: una liga solo lo cambia si el super
-- admin la liberó.
INSERT INTO `config` (`scope`, `scope_id`, `config_key`, `value`, `value_type`, `description`, `league_editable`) VALUES
('global', 0, 'ROSTER_LIMIT_LEAGUES_DECIDE',         '0',  'bool', 'Todas las ligas pueden fijar su propio máximo de jugadores por equipo', 0),
('global', 0, 'FUTBOL_MAX_JUGADORES_POR_EQUIPO',     '25', 'int',  'Máximo de jugadores por equipo (0 = sin límite)', 0),
('global', 0, 'BASQUET_MAX_JUGADORES_POR_EQUIPO',    '15', 'int',  'Máximo de jugadores por equipo (0 = sin límite)', 0),
('global', 0, 'VOLEY_MAX_JUGADORES_POR_EQUIPO',      '14', 'int',  'Máximo de jugadores por equipo (0 = sin límite)', 0),
('global', 0, 'PADEL_MAX_JUGADORES_POR_EQUIPO',      '2',  'int',  'Máximo de jugadores por pareja en dobles (0 = sin límite; en individual siempre es 1)', 0),
('global', 0, 'TENIS_MAX_JUGADORES_POR_EQUIPO',      '2',  'int',  'Máximo de jugadores por pareja en dobles (0 = sin límite; en individual siempre es 1)', 0)
ON DUPLICATE KEY UPDATE
    `value_type` = VALUES(`value_type`),
    `description` = VALUES(`description`),
    `league_editable` = VALUES(`league_editable`);
