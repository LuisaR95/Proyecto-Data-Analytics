# MetroBus Analytics — De los datos crudos al cuadro de mando

**Autora:** Luisa Fernanda Rincón Durán
**Proyecto final — Data Analytics**

Análisis de tres años de operación de una red de autobuses urbana (2022-2024): exploración con Python, modelo y consultas en SQL, gobierno del dato, un dashboard en Power BI y una presentación con los hallazgos.

Las tres preguntas que guían el proyecto:

1. ¿Dónde y cuándo falla el servicio?
2. ¿Qué cuesta más: incidencias o mantenimiento?
3. ¿Cómo debe evolucionar la flota?

---

## 1. Contenido del repositorio

```
.
├── data/                      # 9 CSV originales (3 tablas de hechos y 6 dimensiones)
├── 01_eda.ipynb               # Fase 1 — Exploración con Python / pandas
├── 02_sql.sql                 # Fase 2 — DDL (PostgreSQL) y consultas de negocio
├── cargar_datos.py            # Fase 2 — Script auxiliar que carga los 9 CSV en PostgreSQL
├── 03_gobierno.md             # Fase 3 — Diccionario, Data Quality Log y definición de KPIs
├── 04_dashboard.pbix          # Fase 4 — Dashboard en Power BI (5 páginas)
├── 05_presentacion.pptx       # Fase 5 — Presentación de 8 diapositivas
└── README.md
```

| Tabla | Filas | Descripción |
|---|---|---|
| `fact_viajes` | 50.000 | Un registro por viaje: retraso, ocupación, franja horaria, paradas |
| `fact_incidencias` | 4.000 | Incidencias con categoría, severidad, coste estimado y retirada |
| `fact_mantenimiento` | 876 | Intervenciones por vehículo: coste, días fuera de servicio |
| `dim_vehiculo` | 45 | Flota: combustible, kilómetros, emisiones |
| `dim_linea` | 10 | Líneas urbanas, interurbanas y nocturna |
| `dim_parada` | 120 | Paradas con coordenadas y accesibilidad |
| `dim_conductor` | 30 | Conductores |
| `dim_depot` | 3 | Depósitos |
| `dim_tarifa` | 9 | Títulos de transporte |

Periodo cubierto: del 1 de enero de 2022 al 31 de diciembre de 2024.

---

## 2. Requisitos

- **Python 3.12** con `pandas`, `numpy`, `matplotlib`, `seaborn` y `jupyter`.
- **PostgreSQL 14 o superior** y un cliente SQL. Este proyecto se ejecutó con **DBeaver**; también sirve pgAdmin.
- Para cargar los datos desde Python: `sqlalchemy` y `psycopg2-binary`.
- **Power BI Desktop** (Windows).

En Windows, si `pip` no se reconoce en PowerShell, usa el lanzador de Python:

```powershell
py -m pip install pandas numpy matplotlib seaborn jupyter sqlalchemy psycopg2-binary
```

---

## 3. Cómo reproducir cada fase

### Fase 1 — EDA
1. Deja los 9 CSV en la carpeta `data/`, junto al notebook.
2. Ejecuta `jupyter notebook 01_eda.ipynb` y corre las celdas en orden (el notebook lee los datos con `DATA_DIR = 'data/'`).

### Fase 2 — SQL

Pasos completos para tener la base de datos lista, de cero a las 9 tablas cargadas.

**Paso 1. Crear la conexión y la base de datos (DBeaver)**
1. Abre DBeaver y crea una conexión nueva a **PostgreSQL**: servidor `localhost`, puerto `5432`, usuario `postgres` y la contraseña que definiste al instalar PostgreSQL.
2. Dentro de esa conexión, clic derecho sobre *Databases* → *Create New Database* y crea una base llamada `metrobus`.
3. Conéctate a `metrobus` (clic derecho → *SQL Editor* → *Open SQL script*). Comprueba que estás en la base correcta ejecutando:
   ```sql
   SELECT current_database();
   ```
   Debe responder `metrobus`.

**Paso 2. Crear las 9 tablas**
1. Abre `02_sql.sql` con *Archivo → Abrir archivo*.
2. Asegúrate de que la conexión activa del editor sea `metrobus`.
3. Sin seleccionar ningún texto, pulsa **Alt+X** (*Execute script*). Ctrl+Enter ejecuta solo la instrucción bajo el cursor y no sirve para esto.
4. El script empieza con `DROP TABLE IF EXISTS ... CASCADE`, así que se puede ejecutar varias veces para empezar de cero. Los avisos «la tabla no existe, omitiendo» de la primera ejecución son normales.
5. Comprueba que existen las 9 tablas:
   ```sql
   SELECT table_name FROM information_schema.tables
   WHERE table_schema = 'public' ORDER BY 1;
   ```

**Paso 3. Cargar los CSV con Python**
1. Deja los 9 CSV en la carpeta `data/` junto a `cargar_datos.py`.
2. Desde PowerShell, en la carpeta del script:
   ```powershell
   py cargar_datos.py
   ```
   Si los CSV están en otra carpeta, pásala como argumento: `py cargar_datos.py "C:\ruta\a\los\csv"`.
3. El script pide la contraseña de PostgreSQL por teclado y carga las tablas **en este orden: primero las 6 dimensiones y después los 3 hechos**, para respetar las claves foráneas.
4. Al terminar imprime el número de filas de cada tabla. Debe coincidir con esta lista:

| Tabla | Filas |
|---|---|
| `dim_depot` | 3 |
| `dim_linea` | 10 |
| `dim_vehiculo` | 45 |
| `dim_conductor` | 30 |
| `dim_parada` | 120 |
| `dim_tarifa` | 9 |
| `fact_viajes` | 50.000 |
| `fact_incidencias` | 4.000 |
| `fact_mantenimiento` | 876 |

**Alternativa sin Python.** Con `psql` y desde la carpeta que contiene `data/`, una línea por tabla y en el mismo orden:
```
\copy dim_depot FROM 'data/dim_depot.csv' WITH (FORMAT csv, HEADER true);
```
(repetir para `dim_linea`, `dim_vehiculo`, `dim_conductor`, `dim_parada`, `dim_tarifa`, `fact_viajes`, `fact_incidencias` y `fact_mantenimiento`).

**Paso 4. Ejecutar las consultas**
Abre la sección 3 de `02_sql.sql` y ejecuta cada consulta con **Ctrl+Enter** sobre ella. Cada una responde a una pregunta de negocio, indicada en el comentario que la precede:

| Consulta | Pregunta | Técnica |
|---|---|---|
| Q1 | ¿Qué líneas tienen mayor retraso medio de salida? | `JOIN`, `AVG`, `GROUP BY` |
| Q2 | ¿Cómo se distribuye la ocupación por tipo de línea y franja horaria? | `JOIN`, `GROUP BY` con dos claves |
| Q3 | ¿Qué 5 vehículos acumulan más coste de mantenimiento? | `JOIN`, `SUM`, `LIMIT` |
| Q4 | ¿Qué categoría y severidad de incidencia cuesta más y en qué % obliga a retirar el vehículo? | `GROUP BY`, `CASE` |
| Q5 | ¿Cómo varía el coste correctivo medio entre combustibles? | `LOWER(TRIM())` para normalizar |
| Q6 | ¿Qué conductores tienen más incidencias por viaje? | CTE, `LEFT JOIN`, `COALESCE` |
| Q7 | ¿Cómo evolucionan ocupación y retraso mes a mes en 2024? | `GROUP BY` temporal |
| Q8 | ¿Qué 10 paradas concentran más salidas y cuáles son accesibles? | `JOIN`, `GROUP BY` |
| Q9 | ¿Qué líneas tienen más coste de incidencias por 1.000 viajes? | CTE y función de ventana `RANK() OVER` |

El script termina con un bloque de verificación de índices: `EXPLAIN ANALYZE` sobre una consulta por fecha, donde el plan debe mostrar `Index Only Scan using idx_viajes_fecha`.

**Problemas frecuentes**

| Mensaje | Causa y solución |
|---|---|
| `pip` no se reconoce | Usa `py -m pip install ...` |
| `No module named 'psycopg'` | La dirección de conexión usa `postgresql://`. Debe ser `postgresql+psycopg2://` (ya está así en `cargar_datos.py`) |
| `la columna «fecha» es de tipo date pero la expresión es de tipo character varying` | Se está usando `psycopg` 3 en lugar de `psycopg2`. Misma solución que la fila anterior |
| `viola la restricción «check» «dim_vehiculo_km_totales_check»` | Es la versión antigua del DDL. El vehículo 16 tiene `km_totales = -500` y la restricción se eliminó (ver decisión 11). Usa el `02_sql.sql` actual |
| `la tabla «...» no existe, omitiendo` | Aviso normal de los `DROP TABLE IF EXISTS`. Si aparece al ejecutar el script por segunda vez, estás en otra base de datos: comprueba `SELECT current_database();` |
| Clave foránea violada o `duplicate key` | Se cargó en otro orden o dos veces. Vuelve a ejecutar `02_sql.sql` con Alt+X y carga de nuevo |

### Fase 3 — Gobierno
`03_gobierno.md` se lee directamente. Contiene el diccionario de las 9 tablas, el Data Quality Log (12 decisiones de limpieza) y la definición formal de los 7 KPIs.

### Fase 4 — Dashboard
1. Abre `04_dashboard.pbix` en Power BI Desktop.
2. **Las consultas de Power Query apuntan a una ruta local del equipo donde se construyó.** Si los datos no se encuentran, ve a *Inicio → Transformar datos → Configuración del origen de datos* y usa *Cambiar origen* para apuntar a tu carpeta `data/`. Hay que hacerlo para cada tabla.
3. Pulsa *Actualizar*.
4. Las coordenadas de `dim_parada` se leen con cultura `en-US`. Si se cargan con una configuración regional que usa la coma decimal (por ejemplo, la de Colombia), el punto se interpreta como separador de miles y el mapa no muestra las paradas.

### Fase 5 — Presentación
`05_presentacion.pptx` se abre con PowerPoint. Las cifras son del periodo completo 2022-2024 y se pueden verificar con el notebook, las consultas SQL y el dashboard.

---

## 4. Modelo de datos (Power BI)

Esquema en estrella con 3 tablas de hechos (`fact_viajes`, `fact_incidencias`, `fact_mantenimiento`) y 7 dimensiones: las 6 originales más `dim_calendario`, creada en Power Query para el rango 2022-2024. Todas las relaciones son de muchos a uno, con filtro en una sola dirección desde la dimensión. En total hay 15 relaciones, de las cuales 2 están inactivas (ver decisiones 2 y 3).

---

## 5. Decisiones no obvias

Estas son las decisiones de diseño que no se deducen directamente del enunciado y que conviene explicar.

1. **`dim_depot` no se relaciona con `dim_vehiculo` ni `dim_conductor`.** En los datos origen, vehículos y conductores tienen un `depot_id`. Si se relacionan con `dim_depot` además de `fact_mantenimiento`, el esquema deja de ser una estrella (pasa a copo de nieve) y Power BI rechaza la relación entre `fact_mantenimiento` y `dim_vehiculo` por rutas ambiguas: todos los vehículos mostraban el mismo coste total. La solución fue incorporar `depot_nombre` y `depot_barrio` dentro de `dim_vehiculo` y `dim_conductor` con una combinación en Power Query, y eliminar `depot_id` de ambas. `dim_depot` queda conectada solo con `fact_mantenimiento`.

2. **`dim_parada` tiene dos roles (origen y destino) y solo una relación activa.** Power BI no admite dos relaciones activas entre las mismas tablas. Queda activa la de `parada_origen_id`, porque las preguntas de tráfico y accesibilidad se analizan desde el origen. Para analizar destino se usaría `USERELATIONSHIP` en una medida concreta. Lo mismo ocurre con `fecha_entrada` (activa) y `fecha_salida` (inactiva) en `fact_mantenimiento`.

3. **`franja_horaria` no está en `dim_calendario`.** Es un atributo del viaje (depende de la hora de salida), no de la fecha: un mismo día tiene viajes en varias franjas, y meterla en el calendario rompería la relación de uno a muchos. Se queda en `fact_viajes` y se usa como segmentador independiente.

4. **Los valores anómalos no se corrigen en el origen: se tratan en las medidas.** `retraso_salida_min = -99` (80 filas) se excluye de los KPIs de puntualidad y los costes de mantenimiento negativos (25 filas) se excluyen de los KPIs de coste, ambos con filtros en DAX. No se imputan ni se elimina la fila, porque el resto de columnas del registro es válido. Está justificado en el Data Quality Log.

5. **La normalización de texto se hace en Power Query, no en DAX.** `combustible` y `dia_semana` se unifican antes de cargar el modelo, para que las inconsistencias de mayúsculas no lleguen a las visualizaciones.

6. **Valores vacíos con etiqueta explícita.** El vehículo sin combustible (6032 BUS) se etiqueta como «Sin dato», y se oculta en los gráficos por combustible pero cuenta en los totales de flota. Lo mismo se hace con `accesible_silla` vacío en una parada.

7. **Coordenadas de paradas.** La latitud `999` (un código de error evidente: las demás van de 40,38 a 40,43) se convierte en nulo, y la parada con latitud vacía queda fuera del mapa. Las columnas se tipan como número decimal con cultura `en-US`.

8. **Definiciones de KPI que condicionan el resultado.** Un viaje es **puntual si la salida se retrasa 5 minutos o menos**. Las emisiones medias de la flota se **ponderan por kilómetros totales** de cada vehículo, no se promedian simplemente. La disponibilidad es `1 − días fuera de servicio / (vehículos × días del periodo)`.

9. **Las metas de los KPIs son supuestos míos, no vienen del enunciado:** puntualidad 90 %, ocupación 60 %, coste de incidencias 80.000 € por 1.000 viajes, disponibilidad 90 %, tiempo de resolución de incidencias graves 30 min y emisiones 70 g/km.

10. **Las tarjetas KPI con eje de tendencia mensual muestran el valor del último mes del periodo seleccionado.** La visual KPI de Power BI toma el último punto del eje de tendencia (`anno_mes`). Afecta a las tarjetas de la Página 1, a la de disponibilidad de la Página 4 y a la de tiempo de resolución de la Página 3. La de emisiones usa el mismo eje, pero su medida no depende de la fecha, así que muestra el valor de toda la flota. Las cifras de la presentación y de la sección 6 son del periodo completo, y por eso no coinciden con las tarjetas.

11. **`dim_vehiculo.km_totales` no tiene `CHECK (km_totales >= 0)`.** El vehículo 16 (6016 BUS) tiene `km_totales = -500` en los datos origen, y la restricción impedía cargar la tabla. Se sigue el mismo criterio que con `coste_eur` y `retraso_salida_min`: el DDL no rechaza el valor anómalo, se conserva en el dato origen y se excluye en los cálculos que dependen de él (por ejemplo, las emisiones ponderadas por kilómetros).

12. **Las consultas SQL aplican los mismos criterios de exclusión que el dashboard.** Q1 y Q7 excluyen los retrasos de `-99`, y Q3 y Q5 excluyen los costes de mantenimiento negativos, de modo que las cifras de SQL y de Power BI son comparables.

---

## 6. KPIs (periodo completo 2022-2024)

| KPI | Definición | Valor | Meta |
|---|---|---|---|
| Puntualidad | Viajes con retraso ≤ 5 min / viajes válidos | 75,4 % | 90 % |
| Ocupación media | Media de `ocupacion_pct` | 45,5 % | 60 % |
| Coste de incidencias por 1.000 viajes | Coste estimado total / viajes × 1.000 | 95.902 € | 80.000 € |
| Coste medio de mantenimiento por vehículo | Coste válido total / vehículos con mantenimiento | 14.896 € | — |
| Disponibilidad de flota | 1 − días fuera de servicio / (vehículos × días) | 96,6 % | 90 % |
| Incidencias graves con retirada | Alta o Crítica con `requiere_retirada` / Alta o Crítica | 100 % | — |
| Emisiones medias de CO₂ | Media ponderada por km totales | 87,1 g/km | 70 g/km |
| Tiempo de resolución de incidencias graves (KPI adicional del dashboard) | Media de `duracion_resolucion_min` en Alta y Crítica | 43,7 min | 30 min |

---

## 7. Hallazgos principales

Detallados en la presentación, con los gráficos del dashboard.

1. **El retraso es cosa de las horas punta, no de las líneas.** La puntualidad cae a ~58 % en la mañana y la tarde punta, frente a ~87 % el resto del día, con una ocupación del 71 % frente al 28 %. Las líneas diurnas están todas entre 73 y 74 %.
2. **El coste de incidencias se concentra en Seguridad y en las graves.** Seguridad suma el 77 % del coste con el 25 % de las incidencias, y las de severidad Alta y Crítica el 94 %.
3. **En la flota, el coste está concentrado y las emisiones superan la meta.** 10 vehículos suman el 35 % del coste de mantenimiento, y la flota emite 87 g/km frente a la meta de 70. El coste de mantenimiento por vehículo es similar entre diésel y eléctrico, así que la electrificación se justifica por emisiones, no por ahorro de mantenimiento.

Hallazgo adicional del dashboard (Página 3): las incidencias graves tardan de media **43,7 minutos** en resolverse, un 46 % por encima de la meta de 30, y no mejoran con los años (42, 45 y 44 minutos en 2022, 2023 y 2024).

---

## 8. Limitaciones

- Los costes de incidencias son **estimados**, no facturados.
- No hay datos de tráfico, clima ni causa del retraso: se sabe dónde y cuándo falla el servicio, pero no por qué.
- No hay precio de compra ni coste de energía: no se puede calcular el ahorro de electrificar.
- La puntualidad es del 75 % en 2022, 2023 y 2024, así que no hay una tendencia que explicar.

---

## 9. Uso de herramientas de IA

Usé Claude (Anthropic) como apoyo para resolver dudas de Power BI, DAX y Power Query; para escribir y depurar el script de carga `cargar_datos.py` y resolver los errores de la carga en PostgreSQL; para contrastar las cifras de la presentación con los datos; y para estructurar la presentación y este README. El análisis, las decisiones de diseño y el montaje del dashboard son míos, y puedo explicar cada uno.
