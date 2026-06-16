-- ============================================================
-- ANÁLISIS COMPLETO — ONLINE RETAIL UK (2009-2011)
-- Herramienta: MySQL 8.0
-- Autor: Oscar Rueda Varela
-- Descripción: Análisis de ventas, retención de clientes,
--              supervivencia, CLTV y devoluciones
-- ============================================================


-- ============================================================
-- 1. PERFILACIÓN Y LIMPIEZA DE DATOS
-- ============================================================

-- Perfil general del dataset
SELECT 
    COUNT(*)                                            AS Total_Filas,
    COUNT(CustomerID)                                   AS Con_Cliente,
    MIN(InvoiceDate)                                    AS Fecha_Inicio,
    MAX(InvoiceDate)                                    AS Fecha_Fin,
    COUNT(CASE WHEN InvoiceNo LIKE 'C%' THEN 1 END)    AS Cancelaciones
FROM online_retail;

-- Verificar precios negativos o ceros
SELECT COUNT(*) AS Precios_Invalidos
FROM online_retail
WHERE UnitPrice <= 0;

-- Verificar cantidades negativas que no son cancelaciones
SELECT COUNT(*) AS Cantidades_Invalidas
FROM online_retail
WHERE Quantity <= 0
AND InvoiceNo NOT LIKE 'C%';

-- Vista limpia: excluye precios inválidos, cantidades negativas
-- y cancelaciones. Agrega columna de ventas calculada.
CREATE VIEW online_retail_clean AS
SELECT 
    InvoiceNo,
    StockCode,
    Description,
    Quantity,
    InvoiceDate,
    UnitPrice,
    ROUND(Quantity * UnitPrice, 2) AS Ventas,
    CAST(CustomerID AS UNSIGNED)   AS CustomerID,
    Country
FROM online_retail
WHERE UnitPrice > 0
AND Quantity > 0
AND InvoiceNo NOT LIKE 'C%'
AND CustomerID IS NOT NULL
AND CustomerID != 0
AND CustomerID != '';

-- Verificar filas después de limpieza
SELECT COUNT(*) AS Total_Filas_Limpias
FROM online_retail_clean;


-- ============================================================
-- 2. KPIs GENERALES
-- ============================================================

SELECT 
    ROUND(SUM(Ventas), 2)                           AS Total_Ventas,
    COUNT(DISTINCT InvoiceNo)                        AS Ordenes_Unicas,
    COUNT(DISTINCT CustomerID)                       AS Clientes_Unicos,
    ROUND(SUM(Ventas) / COUNT(DISTINCT InvoiceNo), 2) AS Ticket_Promedio
FROM online_retail_clean;


-- ============================================================
-- 3. TENDENCIAS DE VENTAS
-- ============================================================

-- Tendencias mensuales con variación vs mes anterior,
-- acumulado YTD, promedio móvil 3 meses y comparación vs año anterior
WITH Ventas_Mensuales AS (
    SELECT
        YEAR(InvoiceDate)           AS Invoice_Year,
        MONTH(InvoiceDate)          AS Invoice_Month,
        COUNT(DISTINCT InvoiceNo)   AS Ordenes,
        COUNT(DISTINCT CustomerID)  AS Clientes_Unicos,
        ROUND(SUM(Ventas), 2)       AS Total_Ventas,
        ROUND(AVG(Ventas), 2)       AS Ticket_Promedio
    FROM online_retail_clean
    GROUP BY 1, 2
)
SELECT 
    Invoice_Year,
    Invoice_Month,
    Ordenes,
    Clientes_Unicos,
    Total_Ventas,
    Ticket_Promedio,
    LAG(Total_Ventas, 1)  OVER(ORDER BY Invoice_Year, Invoice_Month)                                    AS Ventas_Mes_Anterior,
    ROUND((Total_Ventas / LAG(Total_Ventas, 1) OVER(ORDER BY Invoice_Year, Invoice_Month) - 1) * 100, 2) AS Pct_vs_Mes_Anterior,
    SUM(Total_Ventas)     OVER(PARTITION BY Invoice_Year ORDER BY Invoice_Year, Invoice_Month)           AS Acumulado_YTD,
    ROUND(AVG(Total_Ventas) OVER(ORDER BY Invoice_Year, Invoice_Month ROWS BETWEEN 2 PRECEDING AND CURRENT ROW), 2) AS Promedio_Movil_3M,
    LAG(Total_Ventas, 12) OVER(ORDER BY Invoice_Year, Invoice_Month)                                    AS Ventas_Mismo_Mes_Año_Anterior,
    ROUND((Total_Ventas / LAG(Total_Ventas, 12) OVER(ORDER BY Invoice_Year, Invoice_Month) - 1) * 100, 2) AS Pct_vs_Año_Anterior
FROM Ventas_Mensuales
ORDER BY Invoice_Year, Invoice_Month;


-- ============================================================
-- 4. ESTACIONALIDAD
-- ============================================================

-- Promedio de ventas por mes del año para identificar
-- meses sistemáticamente más fuertes o débiles
WITH Ventas_Por_Mes_Año AS (
    SELECT 
        YEAR(InvoiceDate)       AS Year,
        MONTH(InvoiceDate)      AS Mes,
        MONTHNAME(InvoiceDate)  AS Mes_Nom,
        ROUND(SUM(Ventas), 2)   AS Total_Ventas
    FROM online_retail_clean
    GROUP BY 1, 2, 3
)
SELECT 
    Mes,
    Mes_Nom,
    ROUND(SUM(Total_Ventas), 2) AS Total_Ventas,
    ROUND(AVG(Total_Ventas), 2) AS Ventas_Promedio
FROM Ventas_Por_Mes_Año
GROUP BY 1, 2
ORDER BY 1;


-- ============================================================
-- 5. COMPARACIÓN SEMESTRAL
-- ============================================================

-- Compara S1 y S2 de cada año contra el mismo semestre
-- del año anterior usando PARTITION BY para el LAG
WITH Semestres AS (
    SELECT
        YEAR(InvoiceDate) AS Year,
        CASE 
            WHEN YEAR(InvoiceDate) = 2010 AND MONTH(InvoiceDate) BETWEEN 1 AND 6  THEN 'S1'
            WHEN YEAR(InvoiceDate) = 2010 AND MONTH(InvoiceDate) BETWEEN 7 AND 12 THEN 'S2'
            WHEN YEAR(InvoiceDate) = 2011 AND MONTH(InvoiceDate) BETWEEN 1 AND 6  THEN 'S1'
            WHEN YEAR(InvoiceDate) = 2011 AND MONTH(InvoiceDate) BETWEEN 7 AND 12 THEN 'S2'
            ELSE 'Periodo Incompleto'
        END                             AS Semestre,
        COUNT(DISTINCT InvoiceNo)       AS Ordenes,
        COUNT(DISTINCT CustomerID)      AS Clientes_Unicos,
        ROUND(SUM(Ventas), 2)           AS Total_Ventas
    FROM online_retail_clean
    GROUP BY 1, 2
)
SELECT
    Year,
    Semestre,
    Ordenes,
    Clientes_Unicos,
    Total_Ventas,
    LAG(Total_Ventas, 1) OVER(PARTITION BY Semestre ORDER BY Year)                                    AS Total_Ventas_Semestre_Anterior,
    ROUND((Total_Ventas / LAG(Total_Ventas, 1) OVER(PARTITION BY Semestre ORDER BY Year) - 1) * 100, 2) AS Pct_vs_Semestre_Anterior
FROM Semestres
WHERE Semestre != 'Periodo Incompleto'
ORDER BY Year, Semestre;


-- ============================================================
-- 6. RETENCIÓN DE CLIENTES
-- ============================================================

-- Análisis de cohortes: porcentaje de clientes que regresa
-- en cada mes posterior a su primera compra
WITH Primera_Compra AS (
    SELECT
        CustomerID,
        MIN(InvoiceDate) AS Primera_Orden
    FROM online_retail_clean
    GROUP BY 1
),
Ordenes_Unicas AS (
    SELECT 
        CustomerID,
        InvoiceNo,
        MIN(InvoiceDate) AS Fecha_Orden
    FROM online_retail_clean
    GROUP BY 1, 2
),
Periodos AS (
    SELECT 
        TIMESTAMPDIFF(MONTH, a.Primera_Orden, b.Fecha_Orden) AS Periodos,
        COUNT(DISTINCT a.CustomerID)                          AS Clientes
    FROM Primera_Compra a
    JOIN Ordenes_Unicas b ON a.CustomerID = b.CustomerID
    GROUP BY 1
)
SELECT 
    Periodos,
    Clientes,
    FIRST_VALUE(Clientes) OVER(ORDER BY Periodos)                                        AS Tamaño_Cohort,
    ROUND(Clientes / FIRST_VALUE(Clientes) OVER(ORDER BY Periodos) * 100, 2)            AS Pct_Retencion
FROM Periodos
ORDER BY Periodos;


-- ============================================================
-- 7. ANÁLISIS DE SUPERVIVENCIA
-- ============================================================

-- Mide qué porcentaje de clientes alcanzó umbrales
-- de permanencia de 6, 12 y 24 meses
WITH Permanencia_Cliente AS (
    SELECT 
        CustomerID,
        MIN(InvoiceDate)                                            AS Primera_Orden,
        MAX(InvoiceDate)                                            AS Ultima_Orden,
        TIMESTAMPDIFF(MONTH, MIN(InvoiceDate), MAX(InvoiceDate))    AS Permanencia
    FROM online_retail_clean
    GROUP BY 1
),
Supervivencia AS (
    SELECT 
        COUNT(DISTINCT CustomerID)                                              AS Tamaño_Cohort,
        COUNT(DISTINCT CASE WHEN Permanencia >= 6  THEN CustomerID END)         AS Surv_6M,
        COUNT(DISTINCT CASE WHEN Permanencia >= 12 THEN CustomerID END)         AS Surv_12M,
        COUNT(DISTINCT CASE WHEN Permanencia >= 24 THEN CustomerID END)         AS Surv_24M
    FROM Permanencia_Cliente
)
SELECT 
    Tamaño_Cohort,
    Surv_6M,
    ROUND(Surv_6M  / Tamaño_Cohort * 100, 2) AS Pct_Surv_6M,
    Surv_12M,
    ROUND(Surv_12M / Tamaño_Cohort * 100, 2) AS Pct_Surv_12M,
    Surv_24M,
    ROUND(Surv_24M / Tamaño_Cohort * 100, 2) AS Pct_Surv_24M
FROM Supervivencia;


-- ============================================================
-- 8. CUSTOMER LIFETIME VALUE (CLTV)
-- ============================================================

-- CLTV por país y año de entrada al cohort
-- Ventana de análisis: primeros 12 meses desde primera compra
-- Solo países con más de 10 clientes para evitar distorsión por outliers
WITH Cohort_Cliente AS (
    SELECT
        CustomerID,
        Country,
        MIN(InvoiceDate)                        AS Primera_Orden,
        MIN(InvoiceDate) + INTERVAL 12 MONTH    AS Limite_12M,
        YEAR(MIN(InvoiceDate))                  AS Year
    FROM online_retail_clean
    GROUP BY 1, 2
),
Ventas_En_Ventana AS (
    SELECT
        a.Year,
        b.Country,
        COUNT(DISTINCT a.CustomerID)                        AS Tamaño_Cohort,
        COUNT(DISTINCT b.InvoiceNo)                         AS Ordenes,
        ROUND(COUNT(DISTINCT b.InvoiceNo) / COUNT(DISTINCT a.CustomerID), 2) AS Promedio_Ordenes_Cliente,
        ROUND(SUM(b.Ventas), 2)                             AS Ventas_Totales
    FROM Cohort_Cliente a
    LEFT JOIN online_retail_clean b
        ON  a.CustomerID = b.CustomerID
        AND b.InvoiceDate BETWEEN a.Primera_Orden AND a.Limite_12M
    GROUP BY 1, 2
)
SELECT 
    Year,
    Country,
    Tamaño_Cohort,
    Ordenes,
    Promedio_Ordenes_Cliente,
    Ventas_Totales,
    ROUND(Ventas_Totales / (Ordenes / Tamaño_Cohort), 2)    AS Valor_Promedio_Orden,
    ROUND(Ventas_Totales / Tamaño_Cohort, 2)                AS CLTV
FROM Ventas_En_Ventana
WHERE Tamaño_Cohort > 10
ORDER BY CLTV DESC;


-- ============================================================
-- 9. ANÁLISIS DE DEVOLUCIONES
-- ============================================================

-- Tasa de devolución mensual en órdenes y en valor
-- Se trabaja sobre la tabla original para incluir cancelaciones
WITH Transacciones AS (
    SELECT 
        *,
        Quantity * UnitPrice AS Ventas
    FROM online_retail
)
SELECT
    YEAR(InvoiceDate)                                                                                               AS Year,
    MONTH(InvoiceDate)                                                                                              AS Mes,
    COUNT(DISTINCT CASE WHEN InvoiceNo NOT LIKE 'C%' THEN InvoiceNo END)                                           AS Ordenes_Normales,
    COUNT(DISTINCT CASE WHEN InvoiceNo LIKE 'C%'     THEN InvoiceNo END)                                           AS Total_Cancelaciones,
    ROUND(SUM(CASE WHEN InvoiceNo NOT LIKE 'C%' THEN Ventas END), 2)                                               AS Ventas_Normales,
    ROUND(SUM(CASE WHEN InvoiceNo LIKE 'C%'     THEN Ventas END) * -1, 2)                                          AS Ventas_Devueltas,
    ROUND(COUNT(DISTINCT CASE WHEN InvoiceNo LIKE 'C%' THEN InvoiceNo END) /
          COUNT(DISTINCT CASE WHEN InvoiceNo NOT LIKE 'C%' THEN InvoiceNo END) * 100, 2)                           AS Tasa_Devolucion_Ordenes,
    ROUND(SUM(CASE WHEN InvoiceNo LIKE 'C%' THEN Ventas END) * -1 * 100 /
          SUM(CASE WHEN InvoiceNo NOT LIKE 'C%' THEN Ventas END), 2)                                               AS Tasa_Devolucion_Valor
FROM Transacciones
GROUP BY 1, 2
ORDER BY 1, 2;


-- Devoluciones por país: valor absoluto y porcentaje del total
WITH Devoluciones_Base AS (
    SELECT 
        Country,
        COUNT(DISTINCT CASE WHEN InvoiceNo LIKE 'C%' THEN InvoiceNo END)       AS Cancelaciones,
        ROUND(SUM(CASE WHEN InvoiceNo LIKE 'C%' THEN Quantity * UnitPrice END) * -1, 2) AS Valor_Devuelto
    FROM online_retail
    GROUP BY 1
)
SELECT 
    Country,
    Cancelaciones,
    Valor_Devuelto,
    ROUND(Valor_Devuelto / SUM(Valor_Devuelto) OVER() * 100, 2) AS Pct_Del_Total
FROM Devoluciones_Base
ORDER BY Valor_Devuelto DESC;
