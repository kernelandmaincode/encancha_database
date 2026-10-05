-- =============================================================
-- Migración 003 — Seed de config (scope global, scope_id = 0)
-- Idempotente: ON DUPLICATE KEY UPDATE solo refresca description,
-- value_type y league_editable; NO pisa `value`, para no revertir lo que
-- el super admin haya cambiado en producción.
-- Fuente: ENCANCHA_PHASE2_DESIGN.md §1.7
-- league_editable = 1 → el admin de liga puede sobrescribirla para su
-- liga o para un torneo. 0 → solo el super admin de la plataforma.
-- =============================================================

SET NAMES utf8mb4;

INSERT INTO `config` (`scope`, `scope_id`, `config_key`, `value`, `value_type`, `description`, `league_editable`) VALUES

-- Plataforma (solo super admin)
('global', 0, 'TRIAL_DAYS',              '30',       'int',    'Días de prueba de una cuenta nueva; se materializa en trial_ends_at al registrarse', 0),
('global', 0, 'TRIAL_PACKAGE_CODE',      'liga_1x1', 'string', 'Paquete en el que corre toda prueba (siempre el básico)', 0),
('global', 0, 'YEARLY_DISCOUNT_PERCENT', '10',       'int',    'Descuento informativo del pago anual frente al mensual', 0),
('global', 0, 'ADS_ENABLED_DEFAULT',     '0',        'bool',   'Valor inicial de accounts.ads_enabled en cuentas nuevas', 0),
('global', 0, 'PAGINATION_DEFAULT',      '20',       'int',    'Tamaño de página por defecto en listados', 0),
('global', 0, 'PHOTO_MAX_SIZE_MB',       '10',       'int',    'Tamaño máximo de imagen en MB', 0),

-- Operación de la liga (el admin de liga las ajusta)
('global', 0, 'IDENTITY_VERIFICATION_MODE',     'flexible', 'string', 'strict = solo juegan registrados y verificados; flexible = se admiten invitados', 1),
('global', 0, 'MATCH_SHEET_SIGNATURE_MODE',     'accept',   'string', 'accept = gesto de aceptación; drawn = además trazo de firma', 1),
('global', 0, 'MATCH_SHEET_CLAIM_WINDOW_HOURS', '48',       'int',    'Horas para firmar la cédula o reclamar desde que se captura el marcador', 1),
('global', 0, 'BLOCK_MATCH_ON_UNPAID_FEES',     '0',        'bool',   'Bloquear el partido de un equipo con adeudos vencidos', 1),
('global', 0, 'NOTIF_RECORDATORIO_1_DIA_ENABLED',  '1',     'bool',   'Recordatorio de partido un día antes', 1),
('global', 0, 'NOTIF_RECORDATORIO_1_HORA_ENABLED', '1',     'bool',   'Recordatorio de partido una hora antes', 1),

-- Fútbol
('global', 0, 'FUTBOL_PUNTOS_GANADOR',            '3', 'int',  'Puntos por partido ganado', 1),
('global', 0, 'FUTBOL_PUNTOS_EMPATE',             '1', 'int',  'Puntos por empate', 1),
('global', 0, 'FUTBOL_PUNTOS_PERDEDOR',           '0', 'int',  'Puntos por partido perdido', 1),
('global', 0, 'FUTBOL_DESEMPATE_PENALES_ENABLED', '0', 'bool', 'En fase regular, desempatar por penales', 1),
('global', 0, 'FUTBOL_PUNTO_EXTRA_PENALES',       '1', 'int',  'Punto extra al ganador de los penales de desempate', 1),
('global', 0, 'FUTBOL_GOL_VISITANTE_ENABLED',     '0', 'bool', 'En llaves a ida y vuelta, el gol de visitante desempata', 1),
('global', 0, 'FUTBOL_AMARILLAS_PARA_SUSPENSION', '5', 'int',  'Amarillas acumuladas que generan un partido de suspensión (0 = no aplica)', 1),
('global', 0, 'FUTBOL_PARTIDOS_POR_ROJA',         '1', 'int',  'Partidos de suspensión por tarjeta roja', 1),

-- Básquetbol
('global', 0, 'BASQUET_PUNTOS_GANADOR',          '2', 'int', 'Puntos de tabla por partido ganado', 1),
('global', 0, 'BASQUET_PUNTOS_PERDEDOR',         '1', 'int', 'Puntos de tabla por partido perdido', 1),
('global', 0, 'BASQUET_PERIODOS',                '4', 'int', 'Número de periodos reglamentarios', 1),
('global', 0, 'BASQUET_FALTAS_PARA_EXPULSION',   '5', 'int', 'Faltas personales que sacan al jugador del partido', 1),
('global', 0, 'BASQUET_PARTIDOS_POR_DESCALIFICACION', '1', 'int', 'Partidos de suspensión por descalificación', 1),

-- Voleibol
('global', 0, 'VOLEY_PUNTOS_GANADOR',  '3', 'int', 'Puntos de tabla por partido ganado', 1),
('global', 0, 'VOLEY_PUNTOS_PERDEDOR', '0', 'int', 'Puntos de tabla por partido perdido', 1),
('global', 0, 'VOLEY_SETS_PARA_GANAR', '3', 'int', 'Sets necesarios para ganar el partido', 1),

-- Pádel
('global', 0, 'PADEL_PUNTOS_GANADOR',  '3', 'int', 'Puntos de tabla por partido ganado', 1),
('global', 0, 'PADEL_PUNTOS_PERDEDOR', '0', 'int', 'Puntos de tabla por partido perdido', 1),
('global', 0, 'PADEL_SETS_PARA_GANAR', '2', 'int', 'Sets necesarios para ganar el partido', 1),

-- Tenis
('global', 0, 'TENIS_PUNTOS_GANADOR',  '3', 'int', 'Puntos de tabla por partido ganado', 1),
('global', 0, 'TENIS_PUNTOS_PERDEDOR', '0', 'int', 'Puntos de tabla por partido perdido', 1),
('global', 0, 'TENIS_SETS_PARA_GANAR', '2', 'int', 'Sets necesarios para ganar el partido', 1)

ON DUPLICATE KEY UPDATE
    `value_type` = VALUES(`value_type`),
    `description` = VALUES(`description`),
    `league_editable` = VALUES(`league_editable`);
