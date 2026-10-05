-- =============================================================
-- Migración 002 — Seed de catálogos: sports, event_types, packages
-- Idempotente: INSERT ... ON DUPLICATE KEY UPDATE
-- Fuente: ENCANCHA_PHASE2_DESIGN.md §1.2 y §1.8
-- =============================================================

SET NAMES utf8mb4;

-- -------------------------------------------------------------
-- sports
-- -------------------------------------------------------------
INSERT INTO `sports` (`code`, `name`, `score_unit`, `has_periods`, `allows_draw`) VALUES
('futbol',  'Fútbol',     'goles',  0, 1),
('basquet', 'Básquetbol', 'puntos', 1, 0),
('voley',   'Voleibol',   'sets',   1, 0),
('padel',   'Pádel',      'sets',   1, 0),
('tenis',   'Tenis',      'sets',   1, 0)
ON DUPLICATE KEY UPDATE
    `name` = VALUES(`name`), `score_unit` = VALUES(`score_unit`),
    `has_periods` = VALUES(`has_periods`), `allows_draw` = VALUES(`allows_draw`);

-- -------------------------------------------------------------
-- event_types — fútbol
-- -------------------------------------------------------------
INSERT INTO `event_types` (`sport_id`, `code`, `name`, `category`, `score_value`, `is_sending_off`, `color`, `sort_order`)
SELECT s.`id`, t.`code`, t.`name`, t.`category`, t.`score_value`, t.`is_sending_off`, t.`color`, t.`sort_order`
FROM `sports` s
JOIN (
    SELECT 'gol' AS `code`, 'Gol' AS `name`, 'score' AS `category`, 1 AS `score_value`, 0 AS `is_sending_off`, NULL AS `color`, 10 AS `sort_order`
    UNION ALL SELECT 'gol_penal',        'Gol de penal',         'score',      1, 0, NULL,      20
    UNION ALL SELECT 'autogol',          'Autogol',              'score',      1, 0, NULL,      30
    UNION ALL SELECT 'asistencia',       'Asistencia',           'other',      0, 0, NULL,      40
    UNION ALL SELECT 'tarjeta_amarilla', 'Tarjeta amarilla',     'discipline', 0, 0, '#FFD600', 50
    UNION ALL SELECT 'tarjeta_roja',     'Tarjeta roja',         'discipline', 0, 1, '#E53935', 60
    UNION ALL SELECT 'penal_fallado',    'Penal fallado',        'other',      0, 0, NULL,      70
    UNION ALL SELECT 'tanda_anotado',    'Penal de tanda anotado', 'other',    0, 0, NULL,      80
    UNION ALL SELECT 'tanda_fallado',    'Penal de tanda fallado', 'other',    0, 0, NULL,      90
    UNION ALL SELECT 'cambio',           'Cambio',               'other',      0, 0, NULL,      100
    UNION ALL SELECT 'mvp',              'Jugador del partido',  'other',      0, 0, NULL,      110
) t
WHERE s.`code` = 'futbol'
ON DUPLICATE KEY UPDATE
    `name` = VALUES(`name`), `category` = VALUES(`category`), `score_value` = VALUES(`score_value`),
    `is_sending_off` = VALUES(`is_sending_off`), `color` = VALUES(`color`), `sort_order` = VALUES(`sort_order`);

-- -------------------------------------------------------------
-- event_types — básquetbol
-- -------------------------------------------------------------
INSERT INTO `event_types` (`sport_id`, `code`, `name`, `category`, `score_value`, `is_sending_off`, `color`, `sort_order`)
SELECT s.`id`, t.`code`, t.`name`, t.`category`, t.`score_value`, t.`is_sending_off`, t.`color`, t.`sort_order`
FROM `sports` s
JOIN (
    SELECT 'tiro_libre' AS `code`, 'Tiro libre' AS `name`, 'score' AS `category`, 1 AS `score_value`, 0 AS `is_sending_off`, NULL AS `color`, 10 AS `sort_order`
    UNION ALL SELECT 'canasta_2',           'Canasta de 2',        'score',      2, 0, NULL,      20
    UNION ALL SELECT 'canasta_3',           'Canasta de 3',        'score',      3, 0, NULL,      30
    UNION ALL SELECT 'asistencia',          'Asistencia',          'other',      0, 0, NULL,      40
    UNION ALL SELECT 'rebote',              'Rebote',              'other',      0, 0, NULL,      50
    UNION ALL SELECT 'falta_personal',      'Falta personal',      'discipline', 0, 0, '#FFD600', 60
    UNION ALL SELECT 'falta_tecnica',       'Falta técnica',       'discipline', 0, 0, '#FB8C00', 70
    UNION ALL SELECT 'falta_antideportiva', 'Falta antideportiva', 'discipline', 0, 0, '#FB8C00', 80
    UNION ALL SELECT 'descalificacion',     'Descalificación',     'discipline', 0, 1, '#E53935', 90
    UNION ALL SELECT 'mvp',                 'Jugador del partido', 'other',      0, 0, NULL,      100
) t
WHERE s.`code` = 'basquet'
ON DUPLICATE KEY UPDATE
    `name` = VALUES(`name`), `category` = VALUES(`category`), `score_value` = VALUES(`score_value`),
    `is_sending_off` = VALUES(`is_sending_off`), `color` = VALUES(`color`), `sort_order` = VALUES(`sort_order`);

-- -------------------------------------------------------------
-- event_types — voleibol
-- -------------------------------------------------------------
INSERT INTO `event_types` (`sport_id`, `code`, `name`, `category`, `score_value`, `is_sending_off`, `color`, `sort_order`)
SELECT s.`id`, t.`code`, t.`name`, t.`category`, t.`score_value`, t.`is_sending_off`, t.`color`, t.`sort_order`
FROM `sports` s
JOIN (
    SELECT 'punto_ataque' AS `code`, 'Punto de ataque' AS `name`, 'score' AS `category`, 1 AS `score_value`, 0 AS `is_sending_off`, NULL AS `color`, 10 AS `sort_order`
    UNION ALL SELECT 'punto_saque',      'Punto de saque (ace)', 'score',      1, 0, NULL,      20
    UNION ALL SELECT 'punto_bloqueo',    'Punto de bloqueo',     'score',      1, 0, NULL,      30
    UNION ALL SELECT 'tarjeta_amarilla', 'Tarjeta amarilla',     'discipline', 0, 0, '#FFD600', 40
    UNION ALL SELECT 'tarjeta_roja',     'Tarjeta roja',         'discipline', 0, 0, '#E53935', 50
    UNION ALL SELECT 'expulsion',        'Expulsión',            'discipline', 0, 1, '#E53935', 60
    UNION ALL SELECT 'descalificacion',  'Descalificación',      'discipline', 0, 1, '#E53935', 70
    UNION ALL SELECT 'mvp',              'Jugador del partido',  'other',      0, 0, NULL,      80
) t
WHERE s.`code` = 'voley'
ON DUPLICATE KEY UPDATE
    `name` = VALUES(`name`), `category` = VALUES(`category`), `score_value` = VALUES(`score_value`),
    `is_sending_off` = VALUES(`is_sending_off`), `color` = VALUES(`color`), `sort_order` = VALUES(`sort_order`);

-- -------------------------------------------------------------
-- event_types — pádel y tenis (mismo catálogo)
-- -------------------------------------------------------------
INSERT INTO `event_types` (`sport_id`, `code`, `name`, `category`, `score_value`, `is_sending_off`, `color`, `sort_order`)
SELECT s.`id`, t.`code`, t.`name`, t.`category`, t.`score_value`, t.`is_sending_off`, t.`color`, t.`sort_order`
FROM `sports` s
JOIN (
    SELECT 'ace' AS `code`, 'Ace' AS `name`, 'other' AS `category`, 0 AS `score_value`, 0 AS `is_sending_off`, NULL AS `color`, 10 AS `sort_order`
    UNION ALL SELECT 'doble_falta',         'Doble falta',            'other',      0, 0, NULL,      20
    UNION ALL SELECT 'winner',              'Golpe ganador',          'other',      0, 0, NULL,      30
    UNION ALL SELECT 'advertencia',         'Advertencia',            'discipline', 0, 0, '#FFD600', 40
    UNION ALL SELECT 'punto_penalizacion',  'Punto de penalización',  'discipline', 0, 0, '#FB8C00', 50
    UNION ALL SELECT 'descalificacion',     'Descalificación',        'discipline', 0, 1, '#E53935', 60
    UNION ALL SELECT 'mvp',                 'Jugador del partido',    'other',      0, 0, NULL,      70
) t
WHERE s.`code` IN ('padel', 'tenis')
ON DUPLICATE KEY UPDATE
    `name` = VALUES(`name`), `category` = VALUES(`category`), `score_value` = VALUES(`score_value`),
    `is_sending_off` = VALUES(`is_sending_off`), `color` = VALUES(`color`), `sort_order` = VALUES(`sort_order`);

-- -------------------------------------------------------------
-- packages — sin paquete gratuito (D13). La prueba corre en 'liga_1x1'.
-- PRECIOS EN 0.00: pendientes de definir por el dueño de la plataforma.
-- El ON DUPLICATE no toca precios para no pisar los que se capturen después.
-- -------------------------------------------------------------
INSERT INTO `packages` (`code`, `name`, `max_leagues`, `max_tournaments_per_league`, `price_monthly`, `price_yearly`, `sort_order`) VALUES
('liga_1x1', 'Básico — 1 liga, 1 torneo',            1, 1, 0.00, 0.00, 10),
('liga_1x2', '1 liga, 2 torneos',                    1, 2, 0.00, 0.00, 20),
('liga_2x2', '2 ligas, 2 torneos por liga',          2, 2, 0.00, 0.00, 30),
('liga_3x3', '3 ligas, 3 torneos por liga',          3, 3, 0.00, 0.00, 40)
ON DUPLICATE KEY UPDATE
    `name` = VALUES(`name`), `max_leagues` = VALUES(`max_leagues`),
    `max_tournaments_per_league` = VALUES(`max_tournaments_per_league`), `sort_order` = VALUES(`sort_order`);
