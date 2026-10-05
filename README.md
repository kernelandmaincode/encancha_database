# encancha_database

Esquema MySQL de EnCancha (base `leaguesp_encancha`, HostGator). El diseño y sus decisiones (D1-D17) están en `ENCANCHA_PHASE2_DESIGN.md`, en la carpeta central del proyecto (`Desarrollos/EnCancha/`, fuera de este repo).

- **`schema.sql`** — build limpio: `DROP TABLE` + las 42 tablas + seeds. Para una base nueva o para reconstruir desarrollo. **Nunca sobre una base con datos reales.** Es un solo archivo sin `SOURCE`, así que se puede importar tal cual desde phpMyAdmin.
- **`migrations/NNN_*.sql`** — cambios incrementales idempotentes, se aplican en orden sobre una base existente. Cada feature toca **ambos**: una migración nueva y `schema.sql`.

`schema.sql` refleja el estado final tras aplicar todas las migraciones, en forma de `CREATE` limpio (sin `ALTER`). Si agregas una migración, actualiza `schema.sql` a mano.

## Estado de verificación

Revisado de forma estática (sintaxis con parser MySQL, 97 FKs con destino, tipo e índice correctos). **Todavía no se ha ejecutado contra un MySQL real**: falta crear la base en cPanel e importarlo. Al hacerlo, confirmar la versión de MySQL/MariaDB del hosting; el esquema usa columnas `JSON` (MySQL 5.7+ / MariaDB 10.2+).

## Migraciones

| # | Resumen |
|---|---------|
| 001 | Schema inicial, 41 tablas |
| 002 | Catálogos: 5 deportes, 43 tipos de evento, 4 paquetes |
| 003 | 34 claves de `config` global |
| 004 | Acceso de jugadores: tabla `invitations`, estado `requested` en `tournament_rosters`, clave `PLAYER_SELF_REGISTRATION_ENABLED` |

**Pendiente del dueño de la plataforma:** los precios de `packages` están en `0.00`. La migración 002 no pisa precios al re-ejecutarse.

## Convenciones

Las de CredenPass/Momentia: `InnoDB`, `utf8mb4_unicode_ci`, `snake_case`, PK `BIGINT UNSIGNED AUTO_INCREMENT`, `created_at`/`updated_at` en toda tabla, banderas `TINYINT(1)`, FKs explícitas con índice.

Borrado: el detalle de un partido (`match_*`) cae en cascada con el partido; lo que tiene valor histórico (inscripciones, planteles, cobros) usa `RESTRICT` y se archiva por `status`, no se borra.

## Tablas por bloque

| Bloque | Tablas |
|---|---|
| Identidad y acceso | `users`, `auth_tokens`, `device_tokens` |
| Cuenta y suscripción | `accounts`, `packages`, `account_subscriptions`, `subscription_events` |
| Catálogo deportivo | `sports`, `event_types` |
| Liga y torneo | `leagues`, `league_admins`, `referees`, `venues`, `fields`, `tournaments`, `tournament_groups` |
| Equipos y jugadores | `teams`, `team_managers`, `players`, `tournament_teams`, `tournament_rosters`, `roster_transfers`, `invitations` |
| Llaves | `brackets`, `bracket_nodes` |
| Partido y cédula | `matches`, `match_periods`, `match_lineups`, `match_events`, `identity_verifications`, `attendance_confirmations`, `player_suspensions`, `match_media`, `match_signatures`, `match_claims` |
| Cobros y pagos | `team_subscriptions`, `internal_charges`, `payments` |
| Notificaciones y social | `notifications`, `notification_preferences`, `shared_cards` |
| Config | `config` |

## Notas de diseño que no se ven en el DDL

- **Equipos y jugadores son persistentes.** `teams` y `players` no tienen `league_id` ni `tournament_id`. Un equipo se inscribe a un torneo con `tournament_teams` y arma su plantel con `tournament_rosters`; puede tener varias inscripciones activas a la vez en torneos y ligas distintas.
- **Un jugador, un plantel vigente por torneo.** No puede haber dos filas de `tournament_rosters` aprobadas y con `valid_to IS NULL` para el mismo jugador en el mismo torneo; en torneos distintos sí. MySQL no lo expresa: lo valida el Service dentro de una transacción.
- **Un plantel histórico nunca se reasigna.** Al transferir, la fila de origen se cierra (`valid_to`) y se abre otra. Por eso los eventos del jugador quedan con el club con el que se jugaron.
- **Estadísticas seccionables.** `match_events` apunta a `tournament_roster_id`, no a `player_id`. El mismo `SUM` da carrera, club, liga o torneo según el filtro.
- **Marcador oficial en `matches`.** `home_score`/`away_score` (goles, puntos o sets ganados) bastan para la tabla de posiciones. `match_periods`, `match_events` y `match_lineups` son detalle opcional. `event_types.score_value` alimenta la estadística del jugador, no el marcador.
- **Invitados.** Un jugador no registrado es una fila de `match_lineups` con `guest_name` y sin plantel; sus eventos usan `guest_lineup_id` y no cuentan para estadísticas de carrera.
- **`match_events.tournament_team_id`** es el equipo al que se acredita el evento; en un autogol es el rival de quien lo anotó.
- **`config` en cascada** torneo > liga > global. Las filas globales usan `scope_id = 0` (no `NULL`) para que el índice único funcione. `league_editable` marca qué claves puede sobrescribir el admin de liga.
- **Solo lectura por falta de pago.** No hay columna para eso: se deriva de `account_subscriptions.status = 'past_due'`.
- **Referencias sin FK** (polimórficas): `internal_charges.subject_id`, `payments.payable_id`, `shared_cards.scope_id`, `config.scope_id`.
- **Acceso de jugadores (D18).** Un jugador puede existir sin cuenta (`players.user_id` nulo). Entra a la app por un enlace de reclamo de su perfil (`invitations` tipo `player_claim`), por un código de equipo (`team_join`, deja el plantel en `requested` hasta que el delegado acepte) o registrándose libre si `PLAYER_SELF_REGISTRATION_ENABLED` está encendido.
- **Sin documentos de identidad.** El esquema no guarda identificaciones oficiales; el árbitro valida contra la foto aprobada del jugador.
