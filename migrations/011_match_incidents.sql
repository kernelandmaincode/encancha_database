-- =============================================================
-- Migración 011 — Incidencias de partido por deporte
-- Idempotente: columnas, índice y FK vía information_schema + PREPARE;
-- catálogo con ON DUPLICATE KEY; los UPDATE se pueden repetir.
-- =============================================================

SET NAMES utf8mb4;

-- event_types.player_scope: a quién involucra la incidencia. Con esto la
-- app y el panel saben qué pedir (un jugador, dos, ninguno) y el API lo exige.
SET @sql = (SELECT IF(COUNT(*) = 0,
    'ALTER TABLE `event_types` ADD COLUMN `player_scope` ENUM(''optional'',''required'',''two'',''none'') NOT NULL DEFAULT ''optional'' AFTER `is_sending_off`',
    'SELECT 1')
    FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'event_types' AND COLUMN_NAME = 'player_scope');
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- match_events.related_tournament_roster_id: el segundo jugador de la
-- incidencia. En un cambio, tournament_roster_id es quien sale y este es
-- quien entra.
SET @sql = (SELECT IF(COUNT(*) = 0,
    'ALTER TABLE `match_events` ADD COLUMN `related_tournament_roster_id` BIGINT UNSIGNED NULL AFTER `tournament_roster_id`',
    'SELECT 1')
    FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'match_events' AND COLUMN_NAME = 'related_tournament_roster_id');
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @sql = (SELECT IF(COUNT(*) = 0,
    'ALTER TABLE `match_events` ADD KEY `idx_match_events_related` (`related_tournament_roster_id`), ADD CONSTRAINT `fk_match_events_related` FOREIGN KEY (`related_tournament_roster_id`) REFERENCES `tournament_rosters` (`id`)',
    'SELECT 1')
    FROM information_schema.TABLE_CONSTRAINTS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'match_events' AND CONSTRAINT_NAME = 'fk_match_events_related');
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

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
