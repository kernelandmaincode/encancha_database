-- 017: candado de la foto del jugador.
--
-- La foto identifica al jugador ante el árbitro. Una vez que la liga aprueba
-- la primera, ya no se cambia: solo si un administrador de la liga lo libera
-- (para un jugador, un equipo o todo un torneo). El permiso es de un solo
-- uso: se consume cuando la liga aprueba la foto nueva.
--
-- Idempotente.

SET @sql = (SELECT IF(COUNT(*) = 0,
    'ALTER TABLE `players` ADD COLUMN `photo_change_allowed` TINYINT(1) NOT NULL DEFAULT 0 AFTER `photo_status`',
    'SELECT 1')
    FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'players' AND COLUMN_NAME = 'photo_change_allowed');
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;
