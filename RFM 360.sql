
SELECT *,
    row_number() over (ORDER BY Recency ASC) as rn_recency,
    row_number() over (ORDER BY Frequency ASC) as rn_frequency,
    row_number() over (ORDER BY Duration ASC) as rn_duration
INTO #customer_statistics
FROM res


;WITH 
IQR_R AS (
    SELECT 
        MIN(Recency) AS min_r,
        (SELECT Recency FROM #customer_statistics WHERE rn_recency = ROUND((SELECT MAX(rn_recency) * 0.25 FROM #customer_statistics), 0)) AS q1_r,
        (SELECT Recency FROM #customer_statistics WHERE rn_recency = ROUND((SELECT MAX(rn_recency) * 0.5 FROM #customer_statistics), 0)) AS q2_r,
        (SELECT Recency FROM #customer_statistics WHERE rn_recency = ROUND((SELECT MAX(rn_recency) * 0.75 FROM #customer_statistics), 0)) AS q3_r
    FROM #customer_statistics
), 
IQR_F AS (
    SELECT 
        MIN(Frequency) AS min_f,
        (SELECT Frequency FROM #customer_statistics WHERE rn_frequency = ROUND((SELECT MAX(rn_frequency) * 0.25 FROM #customer_statistics), 0)) AS q1_f,
        (SELECT Frequency FROM #customer_statistics WHERE rn_frequency = ROUND((SELECT MAX(rn_frequency) * 0.5 FROM #customer_statistics), 0)) AS q2_f,
        (SELECT Frequency FROM #customer_statistics WHERE rn_frequency = ROUND((SELECT MAX(rn_frequency) * 0.75 FROM #customer_statistics), 0)) AS q3_f
    FROM #customer_statistics
), 
IQR_M AS (
    SELECT 
        MIN(Duration) AS min_m,
        (SELECT Duration FROM #customer_statistics WHERE rn_duration = ROUND((SELECT MAX(rn_duration) * 0.25 FROM #customer_statistics), 0)) AS q1_m,
        (SELECT Duration FROM #customer_statistics WHERE rn_duration = ROUND((SELECT MAX(rn_duration) * 0.5 FROM #customer_statistics), 0)) AS q2_m,
        (SELECT Duration FROM #customer_statistics WHERE rn_duration = ROUND((SELECT MAX(rn_duration) * 0.75 FROM #customer_statistics), 0)) AS q3_m
    FROM #customer_statistics
)

, final_rfm AS (
    SELECT 
        cs.MAC,
        cs.Recency, 
        cs.Frequency, 
        cs.Duration,

        -- Recency: Giá trị nhỏ là tốt hơn → R cao hơn
        CASE
            WHEN cs.Recency >= r.min_r AND cs.Recency < r.q1_r THEN '4'
            WHEN cs.Recency >= r.q1_r AND cs.Recency < r.q2_r THEN '3'
            WHEN cs.Recency >= r.q2_r AND cs.Recency < r.q3_r THEN '2'
            ELSE '1'
        END AS R,

        -- Frequency: Giá trị lớn là tốt hơn → F cao hơn
        CASE
            WHEN cs.Frequency >= f.min_f AND cs.Frequency < f.q1_f THEN '1'
            WHEN cs.Frequency >= f.q1_f AND cs.Frequency < f.q2_f THEN '2'
            WHEN cs.Frequency >= f.q2_f AND cs.Frequency < f.q3_f THEN '3'
            ELSE '4'
        END AS F,

        -- Duration: Giá trị lớn là tốt hơn → M cao hơn
        CASE
            WHEN cs.Duration >= m.min_m AND cs.Duration < m.q1_m THEN '1'
            WHEN cs.Duration >= m.q1_m AND cs.Duration < m.q2_m THEN '2'
            WHEN cs.Duration >= m.q2_m AND cs.Duration < m.q3_m THEN '3'
            ELSE '4'
        END AS M

    FROM #customer_statistics cs
    CROSS JOIN IQR_R r
    CROSS JOIN IQR_F f
    CROSS JOIN IQR_M m
)

SELECT *,
       R + F + M AS RFM_Score
FROM final_rfm 
