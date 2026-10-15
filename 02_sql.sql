-- =====================================================================
-- MetroBus Analytics — Fase 2: Modelo relacional y SQL
-- Autor: Luisa Fernanda Rincón Durán
-- Motor objetivo: PostgreSQL 14+
-- =====================================================================
--
-- CÓMO CARGAR LOS DATOS (detallado en el README, sección 3, Fase 2):
-- 1. Crear la base de datos "metrobus".
-- 2. Ejecutar este script completo (en DBeaver: Alt+X). Crea las 9 tablas vacías.
-- 3. Cargar los 9 CSV con el script auxiliar cargar_datos.py:
--      py cargar_datos.py                  (lee los CSV de la carpeta data/)
--    El script carga primero las dimensiones y después los hechos para respetar
--    las claves foráneas. Usa la conexión "postgresql+psycopg2://": con
--    "postgresql://" a secas, las versiones recientes de SQLAlchemy intentan usar
--    psycopg 3 y falla la carga de fechas y horas.
-- 4. Alternativa nativa de PostgreSQL (sin Python), con psql y en el mismo orden:
--      \copy dim_depot FROM 'data/dim_depot.csv' WITH (FORMAT csv, HEADER true);
--      (repetir para cada tabla: dimensiones antes que hechos)
-- 5. Comprobación. Filas esperadas: dim_depot 3, dim_linea 10, dim_vehiculo 45,
--    dim_conductor 30, dim_parada 120, dim_tarifa 9, fact_viajes 50.000,
--    fact_incidencias 4.000, fact_mantenimiento 876.
--
-- =====================================================================
-- 1. DDL — TABLAS DE DIMENSIÓN
-- =====================================================================

DROP TABLE IF EXISTS fact_incidencias CASCADE;
DROP TABLE IF EXISTS fact_mantenimiento CASCADE;
DROP TABLE IF EXISTS fact_viajes CASCADE;
DROP TABLE IF EXISTS dim_conductor CASCADE;
DROP TABLE IF EXISTS dim_vehiculo CASCADE;
DROP TABLE IF EXISTS dim_parada CASCADE;
DROP TABLE IF EXISTS dim_tarifa CASCADE;
DROP TABLE IF EXISTS dim_linea CASCADE;
DROP TABLE IF EXISTS dim_depot CASCADE;


CREATE TABLE dim_depot (
    depot_id             INTEGER PRIMARY KEY,
    nombre               VARCHAR(60) NOT NULL,
    barrio               VARCHAR(60) NOT NULL,
    latitud              NUMERIC(9,6) NOT NULL,
    longitud             NUMERIC(9,6) NOT NULL,
    capacidad_vehiculos  INTEGER NOT NULL CHECK (capacidad_vehiculos > 0)
);

CREATE TABLE dim_linea (
    linea_id         INTEGER PRIMARY KEY,
    codigo           VARCHAR(10) NOT NULL UNIQUE,
    nombre           VARCHAR(80) NOT NULL,
    tipo             VARCHAR(20) NOT NULL CHECK (tipo IN ('Urbana','Interurbana','Nocturna')),
    km_recorrido     NUMERIC(6,2) NOT NULL CHECK (km_recorrido > 0),
    n_paradas        INTEGER NOT NULL CHECK (n_paradas > 0),
    frecuencia_min   INTEGER NOT NULL CHECK (frecuencia_min > 0)
);



CREATE TABLE dim_vehiculo (
    vehiculo_id          INTEGER PRIMARY KEY,
    matricula            VARCHAR(15) NOT NULL UNIQUE,
    modelo               VARCHAR(60) NOT NULL,
    combustible          VARCHAR(20),                    -- nulo en 1 fila; texto sin normalizar (ver 03_gobierno.md)
    capacidad_sentados   INTEGER NOT NULL CHECK (capacidad_sentados > 0),
    capacidad_total      INTEGER NOT NULL CHECK (capacidad_total >= capacidad_sentados),
    anno_fabricacion     INTEGER NOT NULL,
    anno_incorporacion   INTEGER NOT NULL,
    km_totales           INTEGER NOT NULL,                -- contiene 1 valor negativo anómalo (-500, vehículo 16; ver 03_gobierno.md)
    depot_id             INTEGER NOT NULL REFERENCES dim_depot(depot_id),
    emisiones_co2_gkm    INTEGER NOT NULL CHECK (emisiones_co2_gkm >= 0),
    en_servicio          BOOLEAN NOT NULL
);

CREATE TABLE dim_conductor (
    conductor_id         INTEGER PRIMARY KEY,
    nombre               VARCHAR(80) NOT NULL,
    anno_incorporacion   INTEGER NOT NULL,
    antiguedad_anos      NUMERIC(4,1),                   -- nulo en 1 fila
    turno_habitual       VARCHAR(30) NOT NULL,
    depot_id             INTEGER NOT NULL REFERENCES dim_depot(depot_id),
    formacion            VARCHAR(60) NOT NULL,
    licencia_tipo        VARCHAR(10) NOT NULL,
    activo               BOOLEAN NOT NULL,
    ausencias_2024       INTEGER NOT NULL CHECK (ausencias_2024 >= 0)
);

CREATE TABLE dim_parada (
    parada_id            INTEGER PRIMARY KEY,
    nombre_parada        VARCHAR(80) NOT NULL,
    barrio               VARCHAR(60) NOT NULL,
    tipo                 VARCHAR(30) NOT NULL,
    latitud              NUMERIC(9,6),                   -- nulo en 1 fila
    longitud             NUMERIC(9,6) NOT NULL,
    accesible_silla      BOOLEAN,                        -- nulo en 1 fila
    marquesina           BOOLEAN NOT NULL,
    panel_informacion    BOOLEAN NOT NULL,
    activa               BOOLEAN NOT NULL
);

CREATE TABLE dim_tarifa (
    tarifa_id     INTEGER PRIMARY KEY,
    tipo_titulo   VARCHAR(40) NOT NULL,
    categoria     VARCHAR(30) NOT NULL,
    precio_eur    NUMERIC(6,2) NOT NULL CHECK (precio_eur >= 0),
    es_abono      BOOLEAN NOT NULL,
    bonificado    BOOLEAN NOT NULL
);


-- =====================================================================
-- 2. DDL — TABLAS DE HECHOS
-- =====================================================================

CREATE TABLE fact_viajes (
    viaje_id                INTEGER PRIMARY KEY,
    linea_id                INTEGER NOT NULL REFERENCES dim_linea(linea_id),
    vehiculo_id             INTEGER NOT NULL REFERENCES dim_vehiculo(vehiculo_id),
    conductor_id            INTEGER NOT NULL REFERENCES dim_conductor(conductor_id),
    parada_origen_id        INTEGER NOT NULL REFERENCES dim_parada(parada_id),
    parada_destino_id       INTEGER NOT NULL REFERENCES dim_parada(parada_id),
    fecha                   DATE NOT NULL,
    anno                    INTEGER NOT NULL,
    mes                     INTEGER NOT NULL CHECK (mes BETWEEN 1 AND 12),
    dia_semana              VARCHAR(15) NOT NULL,          -- sin normalizar: mezcla 'Monday'/'MONDAY' (ver 03_gobierno.md)
    es_festivo              BOOLEAN NOT NULL,
    franja_horaria          VARCHAR(20) NOT NULL,
    hora_salida_prog        TIME NOT NULL,
    hora_salida_real        TIME NOT NULL,
    hora_llegada_real       TIME NOT NULL,
    retraso_salida_min      INTEGER NOT NULL,              -- contiene valores negativos anómalos (ver 03_gobierno.md)
    duracion_real_min       INTEGER NOT NULL,
    pasajeros_subidos       INTEGER,                       -- nulo en 40 filas
    ocupacion_pct           NUMERIC(5,4) NOT NULL CHECK (ocupacion_pct BETWEEN 0 AND 1),
    km_programados          NUMERIC(6,2) NOT NULL,
    km_recorridos           NUMERIC(6,2) NOT NULL,
    viaje_completado        BOOLEAN NOT NULL,
    consumo                 NUMERIC(6,2),                  -- nulo en 1065 filas
    tarifa_predominante_id  INTEGER NOT NULL REFERENCES dim_tarifa(tarifa_id)
);

CREATE TABLE fact_incidencias (
    incidencia_id            INTEGER PRIMARY KEY,
    viaje_id                 INTEGER NOT NULL REFERENCES fact_viajes(viaje_id),
    vehiculo_id              INTEGER NOT NULL REFERENCES dim_vehiculo(vehiculo_id),
    conductor_id             INTEGER NOT NULL REFERENCES dim_conductor(conductor_id),
    linea_id                 INTEGER NOT NULL REFERENCES dim_linea(linea_id),
    fecha                    DATE NOT NULL,
    anno                     INTEGER NOT NULL,
    mes                      INTEGER NOT NULL CHECK (mes BETWEEN 1 AND 12),
    hora_incidencia          TIME NOT NULL,
    tipo_incidencia          VARCHAR(40) NOT NULL,
    categoria                VARCHAR(30) NOT NULL CHECK (categoria IN ('Seguridad','Vehiculo','Servicio','Externo','Operacional')),
    severidad                VARCHAR(15) NOT NULL CHECK (severidad IN ('Baja','Media','Alta','Critica')),
    requiere_retirada        BOOLEAN NOT NULL,
    duracion_resolucion_min  INTEGER NOT NULL CHECK (duracion_resolucion_min >= 0),
    vehiculo_sustituto       BOOLEAN NOT NULL,
    coste_estimado_eur       NUMERIC(10,2) NOT NULL CHECK (coste_estimado_eur >= 0)
);

CREATE TABLE fact_mantenimiento (
    mantenimiento_id     INTEGER PRIMARY KEY,
    vehiculo_id          INTEGER NOT NULL REFERENCES dim_vehiculo(vehiculo_id),
    depot_id             INTEGER NOT NULL REFERENCES dim_depot(depot_id),
    fecha_entrada        DATE NOT NULL,
    fecha_salida         DATE NOT NULL,
    anno                 INTEGER NOT NULL,
    mes                  INTEGER NOT NULL CHECK (mes BETWEEN 1 AND 12),
    tipo_mantenimiento   VARCHAR(30) NOT NULL,
    categoria            VARCHAR(30),                     -- nulo en 15 filas
    es_correctivo        BOOLEAN NOT NULL,
    dias_fuera_servicio  INTEGER NOT NULL CHECK (dias_fuera_servicio >= 0),
    km_en_revision       INTEGER NOT NULL CHECK (km_en_revision >= 0),
    coste_eur            NUMERIC(10,2) NOT NULL,          -- contiene 25 valores negativos anómalos (ver 03_gobierno.md)
    proveedor            VARCHAR(60) NOT NULL,
    garantia_meses       INTEGER NOT NULL CHECK (garantia_meses >= 0)
);

-- Índices sobre las claves foráneas y la fecha, para acelerar los JOINs y los filtros más frecuentes
CREATE INDEX idx_viajes_linea      ON fact_viajes(linea_id);
CREATE INDEX idx_viajes_vehiculo   ON fact_viajes(vehiculo_id);
CREATE INDEX idx_viajes_conductor  ON fact_viajes(conductor_id);
CREATE INDEX idx_viajes_fecha      ON fact_viajes(fecha);
CREATE INDEX idx_incidencias_veh   ON fact_incidencias(vehiculo_id);
CREATE INDEX idx_mantenimiento_veh ON fact_mantenimiento(vehiculo_id);


-- =====================================================================
-- 3. CONSULTAS DE NEGOCIO
-- =====================================================================

-- Q1: ¿Qué líneas tienen mayor retraso medio de salida y cuántos viajes las respaldan?
SELECT l.codigo, l.tipo,
       ROUND(AVG(v.retraso_salida_min), 2) AS retraso_medio_min,
       COUNT(*) AS n_viajes
FROM fact_viajes v
JOIN dim_linea l ON v.linea_id = l.linea_id
WHERE v.retraso_salida_min <> -99           -- excluye los 80 retrasos con código de error -99 (ver 03_gobierno.md)
GROUP BY l.codigo, l.tipo
ORDER BY retraso_medio_min DESC;


-- Q2: ¿Cómo se distribuye la ocupación media por tipo de línea y franja horaria?
SELECT l.tipo, v.franja_horaria,
       ROUND(AVG(v.ocupacion_pct) * 100, 1) AS ocupacion_media_pct
FROM fact_viajes v
JOIN dim_linea l ON v.linea_id = l.linea_id
GROUP BY l.tipo, v.franja_horaria
ORDER BY l.tipo, ocupacion_media_pct DESC;


-- Q3: ¿Qué 5 vehículos acumulan mayor coste total de mantenimiento y de qué combustible son?
SELECT m.vehiculo_id, veh.matricula, veh.combustible,
       ROUND(SUM(m.coste_eur), 2) AS coste_total_mantenimiento,
       COUNT(*) AS n_intervenciones
FROM fact_mantenimiento m
JOIN dim_vehiculo veh ON m.vehiculo_id = veh.vehiculo_id
WHERE m.coste_eur >= 0                      -- excluye los 25 costes negativos anómalos (ver 03_gobierno.md)
GROUP BY m.vehiculo_id, veh.matricula, veh.combustible
ORDER BY coste_total_mantenimiento DESC
LIMIT 5;


-- Q4: ¿Qué categoría y severidad de incidencia genera más coste, y en qué % obliga a retirar el vehículo?
SELECT categoria, severidad,
       COUNT(*) AS n_incidencias,
       ROUND(SUM(coste_estimado_eur), 2) AS coste_total,
       ROUND(100.0 * SUM(CASE WHEN requiere_retirada THEN 1 ELSE 0 END) / COUNT(*), 1) AS pct_requiere_retirada
FROM fact_incidencias
GROUP BY categoria, severidad
ORDER BY coste_total DESC;


-- Q5: ¿Cómo varía el coste medio de mantenimiento correctivo entre tipos de combustible, tras normalizar el texto?
SELECT LOWER(TRIM(veh.combustible)) AS combustible_normalizado,
       ROUND(AVG(m.coste_eur), 2) AS coste_medio_correctivo,
       COUNT(*) AS n_intervenciones
FROM fact_mantenimiento m
JOIN dim_vehiculo veh ON m.vehiculo_id = veh.vehiculo_id
WHERE m.es_correctivo AND m.coste_eur >= 0
GROUP BY LOWER(TRIM(veh.combustible))
ORDER BY coste_medio_correctivo DESC;


-- Q6: ¿Qué conductores tienen mayor tasa de incidencias por viaje realizado?
WITH viajes_conductor AS (
    SELECT conductor_id, COUNT(*) AS n_viajes
    FROM fact_viajes
    GROUP BY conductor_id
),
incidencias_conductor AS (
    SELECT conductor_id, COUNT(*) AS n_incidencias
    FROM fact_incidencias
    GROUP BY conductor_id
)
SELECT c.conductor_id, c.nombre, c.turno_habitual,
       vc.n_viajes,
       COALESCE(ic.n_incidencias, 0) AS n_incidencias,
       ROUND(100.0 * COALESCE(ic.n_incidencias, 0) / vc.n_viajes, 2) AS pct_incidencia_por_viaje
FROM viajes_conductor vc
JOIN dim_conductor c ON c.conductor_id = vc.conductor_id
LEFT JOIN incidencias_conductor ic ON ic.conductor_id = vc.conductor_id
ORDER BY pct_incidencia_por_viaje DESC
LIMIT 10;


-- Q7: ¿Cómo evolucionan mes a mes la ocupación media y el retraso medio durante 2024?
SELECT anno, mes,
       ROUND(AVG(ocupacion_pct) * 100, 1) AS ocupacion_media_pct,
       ROUND(AVG(retraso_salida_min), 2) AS retraso_medio_min,
       COUNT(*) AS n_viajes
FROM fact_viajes
WHERE anno = 2024
  AND retraso_salida_min <> -99             -- excluye los retrasos con código de error -99 (ver 03_gobierno.md)
GROUP BY anno, mes
ORDER BY mes;


-- Q8: ¿Qué 10 paradas concentran más salidas de viajes y cuáles de ellas son accesibles para silla de ruedas?
SELECT p.parada_id, p.nombre_parada, p.barrio, p.accesible_silla,
       COUNT(*) AS n_salidas
FROM fact_viajes v
JOIN dim_parada p ON v.parada_origen_id = p.parada_id
GROUP BY p.parada_id, p.nombre_parada, p.barrio, p.accesible_silla
ORDER BY n_salidas DESC
LIMIT 10;


-- Q9 (bonus, función de ventana): ranking de líneas por coste de incidencias cada 1.000 viajes,
-- para priorizar dónde reforzar seguridad frente a dónde reforzar mantenimiento de flota.
WITH viajes_linea AS (
    SELECT linea_id, COUNT(*) AS n_viajes
    FROM fact_viajes
    GROUP BY linea_id
),
incidencias_linea AS (
    SELECT linea_id, SUM(coste_estimado_eur) AS coste_total
    FROM fact_incidencias
    GROUP BY linea_id
)
SELECT l.codigo, l.tipo, vl.n_viajes,
       ROUND(COALESCE(il.coste_total, 0), 2) AS coste_incidencias_total,
       ROUND(1000.0 * COALESCE(il.coste_total, 0) / vl.n_viajes, 2) AS coste_por_1000_viajes,
       RANK() OVER (ORDER BY 1000.0 * COALESCE(il.coste_total, 0) / vl.n_viajes DESC) AS ranking_riesgo
FROM viajes_linea vl
JOIN dim_linea l ON l.linea_id = vl.linea_id
LEFT JOIN incidencias_linea il ON il.linea_id = vl.linea_id
ORDER BY ranking_riesgo;


-- =====================================================================
-- 4. VERIFICACIÓN DE ÍNDICES
-- =====================================================================
-- Comprueba que el planificador usa idx_viajes_fecha (Index Only Scan, Heap Fetches: 0).
-- Con 50.000 filas la diferencia de tiempo es pequeña; lo que se verifica es el tipo de lectura.
ANALYZE fact_viajes;

EXPLAIN ANALYZE
SELECT COUNT(*) FROM fact_viajes WHERE fecha = '2023-08-14';
