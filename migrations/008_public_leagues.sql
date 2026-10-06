-- =============================================================
-- Migración 008 — Ligas visibles para espectadores
-- Idempotente: columnas e índice vía information_schema + PREPARE,
-- CREATE TABLE IF NOT EXISTS, y el código solo se llena donde falta.
-- =============================================================

SET NAMES utf8mb4;

-- leagues.is_public: la liga aparece en la búsqueda de la app. Apagado,
-- solo se abre con su código o enlace.
SET @sql = (SELECT IF(COUNT(*) = 0,
    'ALTER TABLE `leagues` ADD COLUMN `is_public` TINYINT(1) NOT NULL DEFAULT 1 AFTER `payment_model`',
    'SELECT 1')
    FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'leagues' AND COLUMN_NAME = 'is_public');
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- leagues.public_code: código corto que la liga comparte (enlace o QR)
-- para que cualquiera abra su perfil público sin cuenta.
SET @sql = (SELECT IF(COUNT(*) = 0,
    'ALTER TABLE `leagues` ADD COLUMN `public_code` VARCHAR(12) NULL AFTER `is_public`',
    'SELECT 1')
    FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'leagues' AND COLUMN_NAME = 'public_code');
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @sql = (SELECT IF(COUNT(*) = 0,
    'ALTER TABLE `leagues` ADD UNIQUE KEY `uq_leagues_public_code` (`public_code`)',
    'SELECT 1')
    FROM information_schema.STATISTICS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'leagues' AND INDEX_NAME = 'uq_leagues_public_code');
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- Las ligas que ya existen reciben su código (10 caracteres; el id lo hace único).
UPDATE `leagues`
SET `public_code` = UPPER(CONCAT(LPAD(CONV(`id`, 10, 36), 4, '0'), SUBSTRING(MD5(CONCAT(`id`, '-', RAND())), 1, 6)))
WHERE `public_code` IS NULL;

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
