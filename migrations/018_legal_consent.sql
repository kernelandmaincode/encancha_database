-- 018: aceptación de términos y consentimiento de tutor.
--
--  - users.terms_accepted_at / terms_version: cuándo y qué versión del aviso de
--    privacidad y los términos aceptó la persona al crear su cuenta.
--  - players.guardian_consent_at / guardian_consent_by_user_id: cuando quien
--    registra a una persona menor de 18 años declara contar con la autorización
--    de su madre, padre o tutor, y quién lo declaró.
--
-- Idempotente.

SET @sql = (SELECT IF(COUNT(*) = 0,
    'ALTER TABLE `users` ADD COLUMN `terms_accepted_at` DATETIME NULL AFTER `status`',
    'SELECT 1')
    FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'users' AND COLUMN_NAME = 'terms_accepted_at');
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @sql = (SELECT IF(COUNT(*) = 0,
    'ALTER TABLE `users` ADD COLUMN `terms_version` VARCHAR(20) NULL AFTER `terms_accepted_at`',
    'SELECT 1')
    FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'users' AND COLUMN_NAME = 'terms_version');
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @sql = (SELECT IF(COUNT(*) = 0,
    'ALTER TABLE `players` ADD COLUMN `guardian_consent_at` DATETIME NULL AFTER `pending_changes`',
    'SELECT 1')
    FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'players' AND COLUMN_NAME = 'guardian_consent_at');
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @sql = (SELECT IF(COUNT(*) = 0,
    'ALTER TABLE `players` ADD COLUMN `guardian_consent_by_user_id` BIGINT UNSIGNED NULL AFTER `guardian_consent_at`',
    'SELECT 1')
    FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'players' AND COLUMN_NAME = 'guardian_consent_by_user_id');
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;
