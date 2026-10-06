-- =============================================================
-- Migración 012 — Reingreso de jugadores en los cambios
-- Idempotente: ON DUPLICATE KEY no pisa `value`.
-- =============================================================

SET NAMES utf8mb4;

-- En fútbol hay ligas de cambios libres (quien sale puede volver a entrar,
-- lo normal en ligas amateur) y ligas donde quien sale ya no regresa. Cada
-- liga o torneo lo decide. En básquetbol y voleibol el reingreso es parte
-- del reglamento y no se configura.
INSERT INTO `config` (`scope`, `scope_id`, `config_key`, `value`, `value_type`, `description`, `league_editable`) VALUES
('global', 0, 'FUTBOL_REINGRESO_ENABLED', '1', 'bool', 'Cambios libres: un jugador que salió de cambio puede volver a entrar', 1)
ON DUPLICATE KEY UPDATE
    `value_type` = VALUES(`value_type`),
    `description` = VALUES(`description`),
    `league_editable` = VALUES(`league_editable`);
