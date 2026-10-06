-- =============================================================
-- Migración 013 — Inicio y cierre de cada tiempo, periodo o set
-- Idempotente: columnas vía information_schema + PREPARE.
-- =============================================================

SET NAMES utf8mb4;

-- Quien dirige el partido marca cuándo empieza y cuándo termina cada
-- segmento (tiempo en fútbol, periodo en básquetbol, set en voleibol,
-- pádel y tenis). Con el inicio real de cada uno el minuto de una
-- incidencia ya no cuenta el descanso, y al cerrarlo queda su marcador
-- parcial. Un segmento con started_at y sin ended_at es el que se está
-- jugando. Los partidos capturados sin este registro dejan ambas en NULL.
SET @sql = (SELECT IF(COUNT(*) = 0,
    'ALTER TABLE `match_periods` ADD COLUMN `started_at` DATETIME NULL AFTER `away_tiebreak`',
    'SELECT 1')
    FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'match_periods' AND COLUMN_NAME = 'started_at');
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @sql = (SELECT IF(COUNT(*) = 0,
    'ALTER TABLE `match_periods` ADD COLUMN `ended_at` DATETIME NULL AFTER `started_at`',
    'SELECT 1')
    FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'match_periods' AND COLUMN_NAME = 'ended_at');
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;
