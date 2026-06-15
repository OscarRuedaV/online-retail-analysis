
SELECT 
    COUNT(*) AS Total_Filas,
    COUNT(CustomerID) AS Con_Cliente,
    MIN(InvoiceDate) AS Fecha_Inicio,
    MAX(InvoiceDate) AS Fecha_Fin,
    COUNT(CASE WHEN InvoiceNo LIKE 'C%' THEN 1 END) AS Cancelaciones
FROM online_retail;


-- Verificar precios negativos o ceros
SELECT COUNT(*) FROM online_retail WHERE UnitPrice <= 0;

-- Verificar cantidades raras
SELECT COUNT(*) FROM online_retail WHERE Quantity <= 0 AND InvoiceNo NOT LIKE 'C%';


---------------------------------------------------

CREATE VIEW online_retail_clean AS
SELECT 
    InvoiceNo,
    StockCode,
    Description,
    Quantity,
    InvoiceDate,
    UnitPrice,
    ROUND(Quantity * UnitPrice, 2) AS Ventas,
    CustomerID,
    Country
FROM online_retail
WHERE UnitPrice > 0
AND Quantity > 0
AND InvoiceNo NOT LIKE 'C%';



SELECT 
	COUNT(*)
FROM online_retail_clean;




-- ANALISIS

SELECT 
	*
FROM online_retail_clean;


SELECT 
	SUM(Ventas) AS Total_Ventas,
    COUNT(DISTINCT InvoiceNo) AS Ordenes_Unicas,
    COUNT(DISTINCT CustomerId) AS Clientes_Unicos,
    ROUND(SUM(Ventas) / COUNT(DISTINCT InvoiceNo),2) AS Ticket_Promedio
FROM online_retail_clean;


-- Tendencias

SELECT 
	Invoice_Year,
    Invoice_Month,
    Ordenes,
    Clientes_Unicos,
    Total_Ventas,
    Ticket_Promedio,
    LAG(Total_Ventas,1) OVER(ORDER BY Invoice_Year,Invoice_Month ASC) AS Ventas_Mes_Anterior,
    ROUND((Total_Ventas / LAG(Total_Ventas,1) OVER(ORDER BY Invoice_Year,Invoice_Month ASC) -1) * 100,2) AS Pct_Ventas_Mes_Anterior,
    SUM(Total_Ventas) OVER(PARTITION BY Invoice_Year ORDER BY Invoice_Year,Invoice_Month ASC)  AS Acumulado_YTD,
    ROUND(AVG(Total_Ventas) OVER(ORDER BY Invoice_Year,Invoice_Month ASC ROWS BETWEEN 2 PRECEDING AND CURRENT ROW),2) AS Promedio_Movil_3M,
    LAG(Total_Ventas,12) OVER(ORDER BY Invoice_Year,Invoice_Month ASC) AS Mes_Actual_vsYearPasado,
    ROUND((Total_Ventas / LAG(Total_Ventas,12) OVER(ORDER BY Invoice_Year,Invoice_Month ASC)-1) * 100,2) Pct_vs_YearPasado
FROM (
SELECT
	YEAR(InvoiceDate) AS Invoice_Year,
    MONTH(InvoiceDate) AS Invoice_Month,
    COUNT(DISTINCT InvoiceNo) Ordenes,
    COUNT(DISTINCT CustomerID) AS Clientes_Unicos,
    ROUND(SUM(Ventas),2) AS Total_Ventas,
    ROUND(AVG(Ventas),2) AS Ticket_Promedio 
FROM online_retail_clean
GROUP BY 1,2) a;


WITH Online_ReIni AS (
	SELECT
	YEAR(InvoiceDate) AS Invoice_Year,
    MONTH(InvoiceDate) AS Invoice_Month,
    COUNT(DISTINCT InvoiceNo) Ordenes,
    COUNT(DISTINCT CustomerID) AS Clientes_Unicos,
    ROUND(SUM(Ventas),2) AS Total_Ventas,
    ROUND(AVG(Ventas),2) AS Ticket_Promedio 
	FROM online_retail_clean
    GROUP BY 1,2
	)
SELECT 
	Invoice_Year,
    Invoice_Month,
    Ordenes,
    Clientes_Unicos,
    Total_Ventas,
    Ticket_Promedio,
    LAG(Total_Ventas,1) OVER(ORDER BY Invoice_Year,Invoice_Month ASC) AS Ventas_Mes_Anterior,
    ROUND((Total_Ventas / LAG(Total_Ventas,1) OVER(ORDER BY Invoice_Year,Invoice_Month ASC) -1) * 100,2) AS Pct_Ventas_Mes_Anterior,
    SUM(Total_Ventas) OVER(PARTITION BY Invoice_Year ORDER BY Invoice_Year,Invoice_Month ASC)  AS Acumulado_YTD,
    ROUND(AVG(Total_Ventas) OVER(ORDER BY Invoice_Year,Invoice_Month ASC ROWS BETWEEN 2 PRECEDING AND CURRENT ROW),2) AS Promedio_Movil_3M,
    LAG(Total_Ventas,12) OVER(ORDER BY Invoice_Year,Invoice_Month ASC) AS Mes_Actual_vsYearPasado,
    ROUND((Total_Ventas / LAG(Total_Ventas,12) OVER(ORDER BY Invoice_Year,Invoice_Month ASC)-1) * 100,2) Pct_vs_YearPasado
    FROM Online_ReIni;
    



	-- Estacionalidad

SELECT 
	Mes,
    Mes_Nom,
    ROUND(SUM(Total_Ventas),2) AS Total_Ventas,
    ROUND(AVG(Total_Ventas),2) AS Ventas_Promedio
FROM (
SELECT 
	YEAR(InvoiceDate) AS Year,
	MONTH(InvoiceDate) AS Mes,
    MONTHNAME(InvoiceDate) AS Mes_Nom,
    ROUND(SUM(Ventas),2) AS Total_Ventas
FROM online_retail_clean
GROUP BY 1,2,3) a
GROUP BY 1,2
ORDER BY 1,2 ASC;

	-- Semestres

SELECT
	Year,
	Semestre,
    Ordenes,
    Clientes_Unicos,
    Total_Ventas,
    LAG(Total_Ventas,1) OVER(PARTITION BY Semestre ORDER BY Semestre) AS Total_Ventas_SAnterior,
    ROUND((Total_Ventas / LAG(Total_Ventas,1) OVER(PARTITION BY Semestre ORDER BY Semestre) -1) * 100 ,2) AS Pct_Diff_SAnterior
FROM (    
SELECT
	YEAR(InvoiceDAte) AS Year,
	CASE WHEN YEAR(InvoiceDate) = '2010' AND MONTH(InvoiceDate) BETWEEN 1 AND 6 THEN 'S1' 
		WHEN YEAR(InvoiceDate) = '2010' AND MONTH(InvoiceDate) BETWEEN 7 AND 12 THEN 'S2'
        WHEN YEAR(InvoiceDate) = '2011' AND MONTH(InvoiceDate) BETWEEN 1 AND 6 THEN 'S1'
        WHEN YEAR(InvoiceDate) = '2011' AND MONTH(InvoiceDate) BETWEEN 7 AND 12 THEN 'S2'
        ELSE 'Periodo Incompleto' END AS Semestre,
	COUNT(DISTINCT InvoiceNo) AS Ordenes,
    COUNT(DISTINCT CustomerID) AS Clientes_Unicos,
    SUM(Ventas) AS Total_Ventas
FROM online_retail_clean
GROUP BY 1,2) a
WHERE Semestre != 'Periodo Incompleto';


-- Retencion de Clientes

SELECT 
	Periodos,
    Clientes,
	FIRST_VALUE(Clientes) OVER(ORDER BY Periodos) AS Tamaño_Cohort,
    ROUND(Clientes / FIRST_VALUE(Clientes) OVER(ORDER BY Periodos),2) * 100 AS Pct_Retencion
FROM (
		SELECT 
			TIMESTAMPDIFF(MONTH,a.Primera_Compra,InvoiceDate) AS Periodos,
			COUNT(DISTINCT a.CustomerID) AS Clientes
		FROM (
				SELECT 
					CustomerID,
					MIN(InvoiceDate) AS Primera_Compra
				FROM online_retail_clean 
				GROUP BY 1) a
				JOIN online_retail_clean b
				ON a.CustomerID = b.CustomerID
				GROUP BY 1) aa;


WITH Online_Retencion AS (
	SELECT
		CustomerID,
        MIN(InvoiceDate) AS Primera_Orden
        FROM online_retail_clean
        GROUP BY 1
),
Periodos AS (
SELECT 
	TIMESTAMPDIFF(MONTH,a.Primera_Orden,b.InvoiceDate) AS Periodos,
    COUNT(DISTINCT a.CustomerID) AS Clientes
	FROM Online_Retencion a
	JOIN online_retail_clean b
	ON a.CustomerID = b.CustomerID
	GROUP BY 1
)
SELECT 
	Periodos,
    Clientes,
    FIRST_VALUE(Clientes) OVER(ORDER BY Periodos) AS Tamaño_Cohort,
    ROUND(Clientes / FIRST_VALUE(Clientes) OVER(ORDER BY Periodos) * 100,2) AS Pct_Retencion
FROM Periodos;




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
        COUNT(DISTINCT a.CustomerID) AS Clientes
    FROM Primera_Compra a
    JOIN Ordenes_Unicas b
    ON a.CustomerID = b.CustomerID
    GROUP BY 1
)
SELECT 
    Periodos,
    Clientes,
    FIRST_VALUE(Clientes) OVER(ORDER BY Periodos) AS Tamaño_Cohort,
    ROUND(Clientes / FIRST_VALUE(Clientes) OVER(ORDER BY Periodos) * 100, 2) AS Pct_Retencion
FROM Periodos;




-- Supervivencia

SELECT 
	Tamaño_Cohort,
    Surv6M,
    ROUND(Surv6M / Tamaño_cohort,2) * 100 AS Pct_Surv6M,
    Surv12M,
    ROUND(Surv12M / Tamaño_cohort,2) * 100 AS Pct_Surv12M,
    Surv24M,
    ROUND(Surv24M / Tamaño_cohort,2) * 100 AS Pct_Surv24M
FROM (
SELECT 
    COUNT(DISTINCT CustomerID) AS Tamaño_Cohort,
    COUNT(DISTINCT CASE WHEN Permanencia >= 6 THEN CustomerID END) AS Surv6M,
    COUNT(DISTINCT CASE WHEN Permanencia >=12 THEN CustomerID END) AS Surv12M,
    COUNT(DISTINCT CASE WHEN Permanencia >=24 THEN CustomerID END) AS Surv24M
FROM (
SELECT 
	CustomerID,
    MIN(InvoiceDate) AS Primer_Periodo,
    MAX(InvoiceDate) AS Ultimo_Periodo,
    TIMESTAMPDIFF(MONTH,MIN(InvoiceDate),MAX(InvoiceDate)) AS Permanencia
FROM online_retail_clean
GROUP BY 1) a) aa;



WITH Online_Supervivencia AS (
	SELECT 
		CustomerID,
        MIN(InvoiceDate) AS Primera_Orden,
        MAX(InvoiceDate) AS Ultima_Orden,
        TIMESTAMPDIFF(MONTH,MIN(InvoiceDate),MAX(InvoiceDate)) AS Permanencia
    FROM online_retail_clean
    GROUP BY 1
),
Periodos AS (
	SELECT 
		COUNT(DISTINCT CustomerID) AS Tamaño_Cohort,
		COUNT(DISTINCT CASE WHEN Permanencia >= 6 THEN CustomerID END) AS Surv6M,
        COUNT(DISTINCT CASE WHEN Permanencia >= 12 THEN CustomerID END) AS Surv12M,
        COUNT(DISTINCT CASE WHEN Permanencia >= 24 THEN CustomerID END) AS Surv24M
    FROM Online_Supervivencia
	)
SELECT 
	Tamaño_Cohort,
    Surv6M,
    ROUND(Surv6M / Tamaño_Cohort,2) * 100 AS Pct_Surv6M,
    Surv12M,
    ROUND(Surv12M / Tamaño_Cohort,2) * 100 AS Pct_Surv12M,
    Surv24M,
    ROUND(Surv24M / Tamaño_Cohort,2) * 100 AS Pct_Surv24M
FROM Periodos;


-- Devoluciones 

SELECT
	YEAR(InvoiceDate) AS Year,
    MONTH(InvoiceDate) AS Month,
	COUNT(DISTINCT CASE WHEN InvoiceNo NOT LIKE 'C%' THEN InvoiceNo END) Ordenes_Normales,
    COUNT(DISTINCT CASE WHEN InvoiceNo LIKE 'C%' THEN InvoiceNo END) AS Total_Devoluciones,
    SUM(CASE WHEN InvoiceNo NOT LIKE 'C%' THEN Ventas END) AS Total_Ventas,
    SUM(CASE WHEN InvoiceNo LIKE 'C%' THEN Ventas END) * -1 AS Total_Ventas_Devueltas,
    ROUND(COUNT(DISTINCT CASE WHEN InvoiceNo LIKE 'C%' THEN InvoiceNo END) / COUNT(DISTINCT CASE WHEN InvoiceNo NOT LIKE 'C%' THEN InvoiceNo END),2) * 100 AS Tasa_Devolucion,
    ROUND((SUM(CASE WHEN InvoiceNo LIKE 'C%' THEN Ventas END) * -1) * 100 / SUM(CASE WHEN InvoiceNo NOT LIKE 'C%' THEN Ventas END),2) AS Tasa_Devolucion_Valor
FROM(
	SELECT 
		*,
		Quantity * UnitPrice AS Ventas
	FROM online_retail) a
    GROUP BY 1,2;

SELECT *
FROM devoluciones_cli;

-- Devoluciones por Pais

ALTER VIEW devoluciones_pais AS
SELECT
	*,
	ROUND(Valor_Devuelto / SUM(Valor_Devuelto) OVER(),4) AS Tasa_de_Devolucion
FROM (
SELECT 
    Country,
    COUNT(DISTINCT CASE WHEN InvoiceNo LIKE 'C%' THEN InvoiceNo END) AS Cancelaciones,
    ROUND(SUM(CASE WHEN InvoiceNo LIKE 'C%' THEN Quantity * UnitPrice END) * -1, 2) AS Valor_Devuelto
FROM online_retail
GROUP BY 1
ORDER BY 2 DESC) a;

SELECT 
	*
FROM Devoluciones_pais;


-- Customer Life Time Value 

SELECT 
	*,
    ROUND(Ventas_Totales / (Ordenes / Tamaño_Cohort),2) AS Valor_Promedio_Cliente,
    ROUND(Ventas_Totales / Tamaño_Cohort, 2) AS CLTV
FROM (
SELECT 
	Year,
    b.Country,
    COUNT(DISTINCT a.CustomerID) AS Tamaño_Cohort,
    COUNT(DISTINCT b.InvoiceNo) AS Ordenes,
    ROUND(COUNT(DISTINCT b.InvoiceNo) / COUNT(DISTINCT a.CustomerID),2) AS Promedio_Ordenes_Cliente,
    SUM(b.Ventas) AS Ventas_Totales
FROM (
SELECT 
	CustomerID,
    COUNTRY,
    MIN(InvoiceDate) AS Primera_Orden,
    MIN(InvoiceDate) + INTERVAL 12 MONTH AS Primeros12M,
    YEAR(MIN(InvoiceDate)) AS Year
FROM online_retail_clean
GROUP BY 1,2) a
LEFT JOIN online_retail_clean b
ON a.CustomerID = b.CustomerID
AND b.InvoiceDate BETWEEN a.primera_orden AND Primeros12M
GROUP BY 1,2) aa
WHERE Tamaño_Cohort > 10
ORDER BY 8 DESC;