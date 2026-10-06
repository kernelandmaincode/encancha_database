-- =============================================================
-- Migración 007 — Quién paga la plataforma lo decide el super admin
-- Idempotente: ON DUPLICATE KEY no pisa `value`.
-- =============================================================

SET NAMES utf8mb4;

-- Valor con el que nace cada liga nueva en leagues.payment_model. El admin
-- de liga ya no lo cambia: el super admin lo fija para todas las ligas o
-- para las de una cuenta concreta.
INSERT INTO `config` (`scope`, `scope_id`, `config_key`, `value`, `value_type`, `description`, `league_editable`) VALUES
('global', 0, 'PAYMENT_MODEL_DEFAULT', 'league_pays', 'string', 'Quién paga la plataforma en las ligas nuevas: league_pays (la liga) o teams_pay (los equipos)', 0)
ON DUPLICATE KEY UPDATE
    `value_type` = VALUES(`value_type`),
    `description` = VALUES(`description`),
    `league_editable` = VALUES(`league_editable`);
