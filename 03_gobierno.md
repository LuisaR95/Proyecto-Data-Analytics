# MetroBus Analytics — Fase 3: Gobierno del Dato

**Autor:** Luisa Fernanda Rincón Durán
**Fase:** 3 de 5 — Gobierno del dato

Este documento define el diccionario de datos, el registro de decisiones de limpieza y los KPIs formales que alimentarán el cuadro de mando de la Fase 4. Todas las cifras de calidad citadas aquí se obtuvieron ejecutando el análisis exploratorio de la Fase 1 (`01_eda.ipynb`) sobre el dataset original, sin modificarlo.

---

## 1. Diccionario de datos

### 1.1 `dim_depot` (3 filas)

| Campo | Tipo | Descripción | Valores válidos / rango | Observaciones de calidad |
|---|---|---|---|---|
| depot_id | INTEGER (PK) | Identificador único de cochera | 1–3, sin duplicados | Ninguna |
| nombre | VARCHAR | Nombre de la cochera | Texto libre | Ninguna |
| barrio | VARCHAR | Barrio donde se ubica | Texto libre | Ninguna |
| latitud | NUMERIC | Latitud GPS | Rango geográfico válido | Ninguna |
| longitud | NUMERIC | Longitud GPS | Rango geográfico válido | Ninguna |
| capacidad_vehiculos | INTEGER | Capacidad máxima de vehículos | > 0 | Ninguna |

### 1.2 `dim_linea` (10 filas)

| Campo | Tipo | Descripción | Valores válidos / rango | Observaciones de calidad |
|---|---|---|---|---|
| linea_id | INTEGER (PK) | Identificador único de línea | 1–10, sin duplicados | Ninguna |
| codigo | VARCHAR | Código corto de la línea | Único (ej. L1, N1) | Ninguna |
| nombre | VARCHAR | Nombre descriptivo de la línea | Texto libre | Ninguna |
| tipo | VARCHAR | Tipo de línea | `Urbana`, `Interurbana`, `Nocturna` | Ninguna |
| km_recorrido | NUMERIC | Kilómetros del recorrido completo | > 0 | Ninguna |
| n_paradas | INTEGER | Número de paradas de la línea | > 0 | Ninguna |
| frecuencia_min | INTEGER | Frecuencia programada en minutos | > 0 | Ninguna |

### 1.3 `dim_vehiculo` (45 filas)

| Campo | Tipo | Descripción | Valores válidos / rango | Observaciones de calidad |
|---|---|---|---|---|
| vehiculo_id | INTEGER (PK) | Identificador único de vehículo | 1–45, sin duplicados | Ninguna |
| matricula | VARCHAR | Matrícula del vehículo | Única | Ninguna |
| modelo | VARCHAR | Modelo del vehículo | Texto libre | Ninguna |
| combustible | VARCHAR | Tipo de combustible | `Diesel`, `Electrico`, `Hibrido` | **1 nulo (2.22%)**; **1 fila con `diesel` en minúscula (2.22%)**, misma categoría que `Diesel` |
| capacidad_sentados | INTEGER | Plazas sentadas | > 0, ≤ capacidad_total | Ninguna |
| capacidad_total | INTEGER | Plazas totales (sentadas + de pie) | ≥ capacidad_sentados | Ninguna |
| anno_fabricacion | INTEGER | Año de fabricación | Año calendario razonable | **1 fila con valor `2099`** (2.22%) — año de fabricación futuro e imposible |
| anno_incorporacion | INTEGER | Año de incorporación a la flota | ≥ año de fabricación esperado | Ver fila anómala anterior: para ese vehículo, incorporación (2024) es anterior a fabricación (2099) |
| km_totales | INTEGER | Kilómetros totales recorridos | ≥ 0 (no se aplica como `CHECK` en el DDL) | **1 valor negativo (-500, vehículo 16)**; ver Data Quality Log #10 |
| depot_id | INTEGER (FK → dim_depot) | Cochera asignada | 1–3 | Ninguna; 100% de integridad referencial verificada |
| emisiones_co2_gkm | INTEGER | Emisiones de CO₂ por km | ≥ 0 (0 en eléctricos) | Ninguna |
| en_servicio | BOOLEAN | Si el vehículo está operativo | `true` / `false` | Ninguna |

### 1.4 `dim_conductor` (30 filas)

| Campo | Tipo | Descripción | Valores válidos / rango | Observaciones de calidad |
|---|---|---|---|---|
| conductor_id | INTEGER (PK) | Identificador único de conductor | 1–30, sin duplicados | Ninguna |
| nombre | VARCHAR | Nombre del conductor | Texto libre | Ninguna |
| anno_incorporacion | INTEGER | Año de incorporación | Año calendario razonable | Ninguna |
| antiguedad_anos | NUMERIC | Antigüedad en años | ≥ 0 | **1 nulo (3.33%)** |
| turno_habitual | VARCHAR | Turno habitual | `Manana (06-14h)`, `Tarde (14-22h)`, `Noche (22-06h)`, `Partido` | Ninguna |
| depot_id | INTEGER (FK → dim_depot) | Cochera asignada | 1–3 | Ninguna; 100% de integridad referencial verificada |
| formacion | VARCHAR | Nivel de formación | Texto libre / categórico | Ninguna |
| licencia_tipo | VARCHAR | Tipo de licencia de conducción | Categórico (ej. D, D+E) | Ninguna |
| activo | BOOLEAN | Si el conductor está activo | `true` / `false` | Ninguna |
| ausencias_2024 | INTEGER | Nº de ausencias en 2024 | ≥ 0 | Ninguna |

### 1.5 `dim_parada` (120 filas)

| Campo | Tipo | Descripción | Valores válidos / rango | Observaciones de calidad |
|---|---|---|---|---|
| parada_id | INTEGER (PK) | Identificador único de parada | 1–120, sin duplicados | Ninguna |
| nombre_parada | VARCHAR | Nombre de la parada | Texto libre | Ninguna |
| barrio | VARCHAR | Barrio donde se ubica | Texto libre | **2 filas con formato inconsistente (1.67%)**; ver Data Quality Log #12 |
| tipo | VARCHAR | Tipo de parada | Categórico | Ninguna |
| latitud | NUMERIC | Latitud GPS | Rango geográfico válido | **1 nulo (0.83%) y 1 valor 999 (0.83%)**; ver Data Quality Log #9 y #11 |
| longitud | NUMERIC | Longitud GPS | Rango geográfico válido | Ninguna |
| accesible_silla | BOOLEAN | Accesibilidad para silla de ruedas | `true` / `false` | **1 nulo (0.83%)** |
| marquesina | BOOLEAN | Si tiene marquesina | `true` / `false` | Ninguna |
| panel_informacion | BOOLEAN | Si tiene panel informativo | `true` / `false` | Ninguna |
| activa | BOOLEAN | Si la parada está en uso | `true` / `false` | Ninguna |

### 1.6 `dim_tarifa` (9 filas)

| Campo | Tipo | Descripción | Valores válidos / rango | Observaciones de calidad |
|---|---|---|---|---|
| tarifa_id | INTEGER (PK) | Identificador único de tarifa | 1–9, sin duplicados | Ninguna |
| tipo_titulo | VARCHAR | Tipo de título de transporte | Categórico (ordinario, bono, abono mensual, turístico, escolar, gratuito social) | Ninguna |
| categoria | VARCHAR | Categoría de la tarifa | Categórico | Ninguna |
| precio_eur | NUMERIC | Precio en euros | ≥ 0 (0 en gratuito social) | Ninguna |
| es_abono | BOOLEAN | Si es un abono | `true` / `false` | Ninguna |
| bonificado | BOOLEAN | Si tiene bonificación | `true` / `false` | Ninguna |

### 1.7 `fact_viajes` (50.000 filas)

| Campo | Tipo | Descripción | Valores válidos / rango | Observaciones de calidad |
|---|---|---|---|---|
| viaje_id | INTEGER (PK) | Identificador único del viaje | Sin duplicados | Ninguna |
| linea_id | INTEGER (FK) | Línea del viaje | 1–10 | Ninguna; integridad referencial 100% |
| vehiculo_id | INTEGER (FK) | Vehículo asignado | 1–45 | Ninguna; integridad referencial 100% |
| conductor_id | INTEGER (FK) | Conductor asignado | 1–30 | Ninguna; integridad referencial 100% |
| parada_origen_id | INTEGER (FK) | Parada de origen | 1–120 | Ninguna; integridad referencial 100% |
| parada_destino_id | INTEGER (FK) | Parada de destino | 1–120 | Ninguna; integridad referencial 100% |
| fecha | DATE | Fecha del viaje | 2022–2024 | Ninguna |
| anno / mes | INTEGER | Año y mes del viaje | Coherentes con `fecha` | Ninguna |
| dia_semana | VARCHAR | Día de la semana | `Monday`…`Sunday` | **30 filas (0.06%) con variantes en mayúsculas** (`MONDAY`, `FRIDAY`, etc.), misma categoría que su equivalente en formato estándar |
| es_festivo | BOOLEAN | Si es festivo | `true` / `false` | Ninguna |
| franja_horaria | VARCHAR | Franja horaria del viaje | Categórico (Madrugada, Mañana punta, Valle mañana, Tarde, Tarde punta, Noche) | Ninguna |
| hora_salida_prog / hora_salida_real / hora_llegada_real | TIME | Horas programada y reales | 00:00–23:59 | Ninguna |
| retraso_salida_min | INTEGER | Retraso en la salida (min) | Normalmente entre -10 y +30 | **80 filas (0.16%) con valor fijo `-99`**, fuera de todo rango operativo plausible |
| duracion_real_min | INTEGER | Duración real del viaje (min) | > 0 | Ninguna |
| pasajeros_subidos | INTEGER | Pasajeros que subieron | ≥ 0 | **40 nulos (0.08%)** |
| ocupacion_pct | NUMERIC | % de ocupación del vehículo | 0–1 | Ninguna |
| km_programados / km_recorridos | NUMERIC | Km programados y realmente recorridos | > 0 | Ninguna |
| viaje_completado | BOOLEAN | Si el viaje se completó | `true` / `false` | Ninguna |
| consumo | NUMERIC | Consumo del vehículo en el viaje | ≥ 0 | **1.065 nulos (2.13%)** |
| tarifa_predominante_id | INTEGER (FK) | Tarifa predominante del viaje | 1–9 | Ninguna; integridad referencial 100% |

### 1.8 `fact_incidencias` (4.000 filas)

| Campo | Tipo | Descripción | Valores válidos / rango | Observaciones de calidad |
|---|---|---|---|---|
| incidencia_id | INTEGER (PK) | Identificador único | Sin duplicados | Ninguna |
| viaje_id | INTEGER (FK → fact_viajes) | Viaje asociado | Existente en fact_viajes | Ninguna; integridad referencial 100% |
| vehiculo_id / conductor_id / linea_id | INTEGER (FK) | Entidades asociadas | Existentes en sus dimensiones | Ninguna; integridad referencial 100% |
| fecha / anno / mes / hora_incidencia | DATE / INTEGER / TIME | Momento de la incidencia | 2022–2024 | Ninguna |
| tipo_incidencia | VARCHAR | Tipo específico de incidencia | Categórico | Ninguna |
| categoria | VARCHAR | Categoría de la incidencia | `Seguridad`, `Vehiculo`, `Servicio`, `Externo`, `Operacional` | Ninguna nulo, pero ver KPI de coste — la severidad pesa más que la categoría en el coste total |
| severidad | VARCHAR | Severidad de la incidencia | `Baja`, `Media`, `Alta`, `Critica` | Ninguna |
| requiere_retirada | BOOLEAN | Si el vehículo se retiró de servicio | `true` / `false` | Ninguna |
| duracion_resolucion_min | INTEGER | Minutos hasta resolución | ≥ 0 | Ninguna |
| vehiculo_sustituto | BOOLEAN | Si se usó vehículo sustituto | `true` / `false` | Ninguna |
| coste_estimado_eur | NUMERIC | Coste estimado en euros | ≥ 0 | Ninguna |

### 1.9 `fact_mantenimiento` (876 filas)

| Campo | Tipo | Descripción | Valores válidos / rango | Observaciones de calidad |
|---|---|---|---|---|
| mantenimiento_id | INTEGER (PK) | Identificador único | Sin duplicados | Ninguna |
| vehiculo_id | INTEGER (FK) | Vehículo intervenido | 1–45 | Ninguna; integridad referencial 100% |
| depot_id | INTEGER (FK) | Cochera donde se realizó | 1–3 | Ninguna; integridad referencial 100% |
| fecha_entrada / fecha_salida | DATE | Fechas de entrada y salida de taller | fecha_salida ≥ fecha_entrada | Ninguna violación detectada |
| anno / mes | INTEGER | Año y mes de la intervención | Coherentes con fecha_entrada | Ninguna |
| tipo_mantenimiento | VARCHAR | Tipo de intervención | Categórico (preventivo, correctivo, legal, estético) | Ninguna |
| categoria | VARCHAR | Categoría de la intervención | Categórico | **15 nulos (1.71%)** |
| es_correctivo | BOOLEAN | Si es una intervención correctiva | `true` / `false` | Ninguna |
| dias_fuera_servicio | INTEGER | Días fuera de servicio | ≥ 0 | Ninguna |
| km_en_revision | INTEGER | Km del vehículo al momento de la revisión | ≥ 0 | Ninguna |
| coste_eur | NUMERIC | Coste de la intervención en euros | ≥ 0 | **25 filas (2.85%) con valor negativo**, mínimo -4.083,03€ |
| proveedor | VARCHAR | Proveedor del servicio | Texto libre | Ninguna |
| garantia_meses | INTEGER | Meses de garantía de la intervención | ≥ 0 | Ninguna |

---

## 2. Registro de decisiones de limpieza (Data Quality Log)

| # | Tabla | Campo | Tipo de problema | Frecuencia | Decisión tomada | Justificación |
|---|---|---|---|---|---|---|
| 1 | fact_viajes | retraso_salida_min | Valor imposible (constante -99) | 80 filas (0.16%) | Tratar como código de "dato no disponible" y excluir de los cálculos de puntualidad; no imputar ni eliminar la fila (el resto de columnas del viaje son válidas) | El valor exacto -99, siempre idéntico, es un patrón típico de código de error/sentinel, no un retraso real. Excluirlo evita distorsionar el KPI de puntualidad; conservar la fila preserva el resto de la información del viaje |
| 2 | fact_mantenimiento | coste_eur | Valor negativo | 25 filas (2.85%) | Excluir estas filas de los KPIs de coste de mantenimiento; marcarlas para revisión manual con el proveedor de facturación, no invertir el signo automáticamente | Un coste no puede ser negativo; invertir el signo asumiría que se trata de un error de signo, pero también podría ser una nota de abono mal registrada como coste total — se requiere confirmación externa antes de reinterpretar el valor |
| 3 | dim_vehiculo | anno_fabricacion | Valor imposible (año futuro) | 1 fila (2.22%) | Marcar como dato erróneo y excluir el vehículo de los análisis de antigüedad de flota hasta su corrección; no excluirlo de los análisis operativos (viajes, incidencias) | `anno_fabricacion = 2099` es un año futuro imposible, e implica que la fabricación es posterior a la incorporación (2024) del mismo vehículo — inconsistencia lógica clara. Afecta solo a análisis de antigüedad, no a los operativos |
| 4 | dim_vehiculo / fact_viajes | combustible / dia_semana | Inconsistencia de formato (mayúsculas/minúsculas) | 1 fila (2.22%) en combustible; 30 filas (0.06%) en dia_semana | Normalizar con `LOWER(TRIM(...))` o `INITCAP(...)` en la capa de transformación (vistas o medidas del modelo BI), sin modificar el dato origen | Son la misma categoría de negocio (`Diesel` = `diesel`, `Monday` = `MONDAY`); agruparlas sin normalizar duplicaría categorías y distorsionaría cualquier `GROUP BY` sobre estas columnas |
| 5 | fact_viajes | consumo | Valor nulo | 1.065 filas (2.13%) | No imputar; excluir de los cálculos de consumo medio (`AVG` ya ignora nulos por defecto) y reportar el % de cobertura junto a cualquier KPI de consumo | El consumo depende de sensores del vehículo; imputar un valor inventado introduciría sesgo en el KPI de eficiencia energética, un dato sensible para la decisión de inversión en flota eléctrica |
| 6 | fact_viajes | pasajeros_subidos | Valor nulo | 40 filas (0.08%) | No imputar; excluir de los cálculos de demanda de pasajeros | Volumen muy bajo (0.08%) sin patrón aparente; el riesgo de introducir sesgo con una imputación supera el beneficio de rellenar tan pocas filas |
| 7 | fact_mantenimiento | categoria | Valor nulo | 15 filas (1.71%) | Clasificar temporalmente como `'Sin categorizar'` en el modelo BI (no en el dato origen) y reportarlas aparte en cualquier desglose por categoría | Permite seguir usando la fila en KPIs de coste total sin descartar el registro, dejando explícito que la categorización real está pendiente de completar por el equipo de mantenimiento |
| 8 | dim_conductor | antiguedad_anos | Valor nulo | 1 fila (3.33%) | No imputar; calcular una antigüedad de respaldo como `anno_actual - anno_incorporacion` solo para fines de visualización, dejando el campo original intacto | El dato de respaldo existe en la misma tabla (`anno_incorporacion`), por lo que no hace falta imputar arbitrariamente; se prioriza no alterar el campo fuente |
| 9 | dim_parada | latitud / accesible_silla | Valor nulo | 1 fila (0.83%) cada uno | No imputar; excluir la parada de los mapas geográficos y del KPI de accesibilidad hasta que se confirme el dato con el equipo de infraestructura | Son atributos físicos verificables sobre el terreno; una imputación (p. ej. la media de latitudes) sería geográficamente incorrecta |
| 10 | dim_vehiculo | km_totales | Valor imposible (negativo) | 1 fila (2.22%) | Conservar el dato origen; excluir el vehículo de los cálculos ponderados por kilómetros (emisiones medias); no imputar ni invertir el signo | Un kilometraje total no puede ser negativo. El valor -500 (vehículo 16, 6016 BUS) bloqueó la carga en PostgreSQL por la restricción `CHECK`, que se eliminó en esa columna, igual que en `coste_eur` y `retraso_salida_min`. El efecto sobre la flota es mínimo (500 km sobre unos 16 millones), pero queda trazado |
| 11 | dim_parada | latitud | Valor imposible (constante 999) | 1 fila (0.83%) | Convertir a nulo en Power Query y excluir la parada del mapa; no imputar | Las demás latitudes están entre 40,38 y 40,43; 999 es un código de error, no una coordenada válida |
| 12 | dim_parada | barrio | Inconsistencia de formato (mayúsculas/minúsculas) | 2 filas (1.67%) | Normalizar con `Text.Proper` en Power Query (`centro` → `Centro`, `BARRIO NORTE` → `Barrio Norte`), sin modificar el dato origen | Misma categoría de negocio escrita de forma distinta; sin normalizar, los barrios se contarían como categorías separadas |

---

## 3. Definición formal de KPIs

### KPI 1 — Índice de Puntualidad
- **Fórmula:** `% de viajes con retraso_salida_min <= 5 minutos` = `COUNT(viajes con retraso_salida_min BETWEEN -10 AND 5) / COUNT(viajes válidos) × 100`
- **Fuente de datos:** `fact_viajes.retraso_salida_min`
- **Criterios de exclusión:** excluir filas con `retraso_salida_min = -99` (ver Data Quality Log #1)
- **Responsable de negocio:** Jefe de Operaciones

### KPI 2 — Ocupación Media
- **Fórmula:** `AVG(ocupacion_pct) × 100`, calculado por línea, tipo de línea y franja horaria
- **Fuente de datos:** `fact_viajes.ocupacion_pct`
- **Criterios de exclusión:** ninguno (columna sin nulos ni valores fuera de rango)
- **Responsable de negocio:** Director de Planificación de Rutas

### KPI 3 — Coste de Incidencias por 1.000 viajes
- **Fórmula:** `SUM(coste_estimado_eur) / COUNT(viaje_id) × 1000`, calculado por línea
- **Fuente de datos:** `fact_incidencias.coste_estimado_eur` (numerador), `fact_viajes.viaje_id` (denominador)
- **Criterios de exclusión:** ninguno
- **Responsable de negocio:** Responsable de Seguridad y Riesgos

### KPI 4 — Coste Medio de Mantenimiento por Vehículo
- **Fórmula:** `SUM(coste_eur) / COUNT(DISTINCT vehiculo_id)`, calculado por tipo de combustible
- **Fuente de datos:** `fact_mantenimiento.coste_eur`, `dim_vehiculo.combustible` (normalizado, ver Data Quality Log #4)
- **Criterios de exclusión:** excluir filas con `coste_eur < 0` (ver Data Quality Log #2)
- **Responsable de negocio:** Jefe de Flota y Mantenimiento

### KPI 5 — Tasa de Disponibilidad de Flota
- **Fórmula:** `1 - (SUM(dias_fuera_servicio) / (COUNT(DISTINCT vehiculo_id) × días del período))`, expresado en %
- **Fuente de datos:** `fact_mantenimiento.dias_fuera_servicio`, `dim_vehiculo.vehiculo_id`
- **Criterios de exclusión:** ninguno
- **Responsable de negocio:** Jefe de Flota y Mantenimiento

### KPI 6 — % de Incidencias Críticas con Retirada de Vehículo
- **Fórmula:** `COUNT(incidencias con requiere_retirada = true AND severidad IN ('Alta','Critica')) / COUNT(incidencias con severidad IN ('Alta','Critica')) × 100`
- **Fuente de datos:** `fact_incidencias.requiere_retirada`, `fact_incidencias.severidad`
- **Criterios de exclusión:** ninguno
- **Responsable de negocio:** Responsable de Seguridad y Riesgos

### KPI 7 — Emisiones Medias de CO₂ por km
- **Fórmula:** `SUM(emisiones_co2_gkm × km_totales) / SUM(km_totales)`, calculado por tipo de combustible
- **Fuente de datos:** `dim_vehiculo.emisiones_co2_gkm`, `dim_vehiculo.km_totales`, `dim_vehiculo.combustible` (normalizado)
- **Criterios de exclusión:** excluir el vehículo con `anno_fabricacion = 2099` de los cortes por antigüedad de flota (ver Data Quality Log #3), no de este KPI en sí; excluir de las sumas el vehículo con `km_totales < 0` (ver Data Quality Log #10)
- **Responsable de negocio:** Dirección de Sostenibilidad / Dirección General
