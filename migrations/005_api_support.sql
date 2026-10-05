-- =============================================================
-- Migración 005 — Columnas que necesita el API (FASE 4)
-- Idempotente: cada columna se agrega solo si no existe. MySQL no tiene
-- ADD COLUMN IF NOT EXISTS, por eso se consulta information_schema y se
-- arma la sentencia con PREPARE. Se puede ejecutar completa desde phpMyAdmin.
-- =============================================================

SET NAMES utf8mb4;

-- players.pending_changes: nombre, fecha de nacimiento o foto propuestos
-- por un delegado o por el jugador, a la espera del admin de liga. Los
-- datos vigentes no cambian hasta que se aprueban.
SET @sql = (SELECT IF(COUNT(*) = 0,
    'ALTER TABLE `players` ADD COLUMN `pending_changes` JSON NULL AFTER `photo_status`',
    'SELECT 1')
    FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'players' AND COLUMN_NAME = 'pending_changes');
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- tournament_rosters.pending_changes: cambio de dorsal o posición
-- propuesto sobre un alta ya aprobada.
SET @sql = (SELECT IF(COUNT(*) = 0,
    'ALTER TABLE `tournament_rosters` ADD COLUMN `pending_changes` JSON NULL AFTER `reviewed_by_user_id`',
    'SELECT 1')
    FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'tournament_rosters' AND COLUMN_NAME = 'pending_changes');
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- payments.metadata: lo que se pidió al reportar un pago de suscripción
-- (paquete y ciclo), para activarlo al aprobar.
SET @sql = (SELECT IF(COUNT(*) = 0,
    'ALTER TABLE `payments` ADD COLUMN `metadata` JSON NULL AFTER `receipt_url`',
    'SELECT 1')
    FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'payments' AND COLUMN_NAME = 'metadata');
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;
