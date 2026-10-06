-- =============================================================
-- Migración 009 — Actualización obligatoria de la app
-- Idempotente: ON DUPLICATE KEY no pisa `value`.
-- =============================================================

SET NAMES utf8mb4;

-- Versión mínima que la app acepta en cada plataforma y a dónde mandar a
-- actualizar. La app las consulta al abrir (sin sesión) y al volver a
-- primer plano; si su versión es menor, solo deja ir a la tienda.
-- Solo las cambia el super admin.
INSERT INTO `config` (`scope`, `scope_id`, `config_key`, `value`, `value_type`, `description`, `league_editable`) VALUES
('global', 0, 'APP_MIN_VERSION_IOS',     '1.0.0', 'string', 'Versión mínima de la app en iOS (x.y.z); por debajo, obliga a actualizar', 0),
('global', 0, 'APP_MIN_VERSION_ANDROID', '1.0.0', 'string', 'Versión mínima de la app en Android (x.y.z); por debajo, obliga a actualizar', 0),
('global', 0, 'APP_STORE_URL_IOS',       '',      'string', 'Enlace de la app en App Store', 0),
('global', 0, 'APP_STORE_URL_ANDROID',   '',      'string', 'Enlace de la app en Google Play', 0)
ON DUPLICATE KEY UPDATE
    `value_type` = VALUES(`value_type`),
    `description` = VALUES(`description`),
    `league_editable` = VALUES(`league_editable`);
