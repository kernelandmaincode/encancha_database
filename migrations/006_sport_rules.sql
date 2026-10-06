-- =============================================================
-- Migración 006 — Reglas específicas por deporte
-- Idempotente: columnas vía information_schema + PREPARE; claves de
-- config con ON DUPLICATE KEY (no pisa `value`).
-- =============================================================

SET NAMES utf8mb4;

-- tournament_teams.detail_for / detail_against: el "segundo marcador" de
-- los deportes por sets. En pádel y tenis son juegos; en voleibol, puntos.
-- Sirven para desempatar la tabla (diferencia de juegos, cociente de
-- puntos). En fútbol y básquetbol quedan en 0.
SET @sql = (SELECT IF(COUNT(*) = 0,
    'ALTER TABLE `tournament_teams` ADD COLUMN `detail_for` INT UNSIGNED NOT NULL DEFAULT 0 AFTER `score_against`',
    'SELECT 1')
    FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'tournament_teams' AND COLUMN_NAME = 'detail_for');
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @sql = (SELECT IF(COUNT(*) = 0,
    'ALTER TABLE `tournament_teams` ADD COLUMN `detail_against` INT UNSIGNED NOT NULL DEFAULT 0 AFTER `detail_for`',
    'SELECT 1')
    FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'tournament_teams' AND COLUMN_NAME = 'detail_against');
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

INSERT INTO `config` (`scope`, `scope_id`, `config_key`, `value`, `value_type`, `description`, `league_editable`) VALUES
-- Fútbol
('global', 0, 'FUTBOL_MINUTOS_POR_TIEMPO', '45', 'int', 'Minutos de cada tiempo', 1),
-- Básquetbol
('global', 0, 'BASQUET_MINUTOS_POR_PERIODO',    '10', 'int', 'Minutos de cada periodo', 1),
('global', 0, 'BASQUET_PUNTOS_INCOMPARECENCIA', '0',  'int', 'Puntos de tabla para el equipo que pierde por no presentarse', 1),
-- Voleibol
('global', 0, 'VOLEY_PUNTOS_GANADOR_SET_DECISIVO',  '2',  'int', 'Puntos de tabla por ganar en el set decisivo (ej. 3-2)', 1),
('global', 0, 'VOLEY_PUNTOS_PERDEDOR_SET_DECISIVO', '1',  'int', 'Puntos de tabla por perder en el set decisivo (ej. 2-3)', 1),
('global', 0, 'VOLEY_PUNTOS_POR_SET',               '25', 'int', 'Puntos para ganar un set', 1),
('global', 0, 'VOLEY_PUNTOS_SET_DECISIVO',          '15', 'int', 'Puntos para ganar el set decisivo', 1),
-- Pádel
('global', 0, 'PADEL_JUEGOS_POR_SET',          '6', 'int',  'Juegos para ganar un set', 1),
('global', 0, 'PADEL_SUPER_TIEBREAK_ENABLED',  '1', 'bool', 'El set decisivo se juega a súper tie-break de 10 puntos', 1),
('global', 0, 'PADEL_PUNTO_DE_ORO_ENABLED',    '1', 'bool', 'Con 40 iguales se juega punto de oro (sin ventaja)', 1),
-- Tenis
('global', 0, 'TENIS_JUEGOS_POR_SET',          '6', 'int',  'Juegos para ganar un set', 1),
('global', 0, 'TENIS_SUPER_TIEBREAK_ENABLED',  '0', 'bool', 'El set decisivo se juega a súper tie-break de 10 puntos', 1),
('global', 0, 'TENIS_SIN_VENTAJA_ENABLED',     '0', 'bool', 'Con 40 iguales se juega punto decisivo (sin ventaja)', 1)
ON DUPLICATE KEY UPDATE
    `value_type` = VALUES(`value_type`),
    `description` = VALUES(`description`),
    `league_editable` = VALUES(`league_editable`);
