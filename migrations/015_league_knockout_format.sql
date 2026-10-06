-- =============================================================
-- Migración 015 — Formato "liga y liguilla"
-- Idempotente: el MODIFY del ENUM se puede repetir.
-- =============================================================

SET NAMES utf8mb4;

-- league_knockout: una sola tabla, todos contra todos, y los mejores pasan
-- a la fase final por eliminación (liguilla, playoffs, cuadro final). Es el
-- formato de la Liga MX. Hasta ahora la fase final solo existía después de
-- una fase de grupos (groups_knockout), que exige al menos dos grupos.
ALTER TABLE `tournaments`
    MODIFY COLUMN `format` ENUM('groups','knockout','round_robin','groups_knockout','groups_two_legs','league_knockout') NOT NULL;
