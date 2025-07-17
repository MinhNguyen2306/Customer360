
select customerid, 
       max(Purchase_Date) as latest_purchase_date,
       datediff(year, min(created_date), '2022-09-01') as contract_age,
       datediff(day, max(Purchase_Date), '2022-09-01') as recency,
       1.0 * count(*) / nullif(datediff(year, min(created_date), '2022-09-01'), 0) as frequency,
       1.0 * sum(GMV) / nullif(datediff(year, min(created_date), '2022-09-01'), 0) as monetary,
       row_number() over (order by datediff(day, max(Purchase_Date), '2022-09-01') asc) as rn_recency,
       row_number() over (order by 1.0 * count(*) / nullif(datediff(year, min(created_date), '2022-09-01'), 0) asc) as rn_frequency,
       row_number() over (order by 1.0 * sum(GMV) / nullif(datediff(year, min(created_date), '2022-09-01'), 0) asc) as rn_monetary
into #customer_statistics
from customer_transaction ct
join Customer_Registered cr 
on ct.customerid = cr.ID
where customerid != 0
group by customerID;


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

, RFM as (
    select 
        cs.customerid,
        cs.recency, cs.frequency, cs.monetary,
        case
            when cs.recency >= r.min_r and cs.recency < r.q1_r then '4'
            when cs.recency >= r.q1_r and cs.recency < r.q2_r then '3'
            when cs.recency >= r.q2_r and cs.recency < r.q3_r then '2'
            else '1'
        end as R,
        case
            when cs.frequency >= f.min_f and cs.frequency < f.q1_f then '1'
            when cs.frequency >= f.q1_f and cs.frequency < f.q2_f then '2'
            when cs.frequency >= f.q2_f and cs.frequency < f.q3_f then '3'
            else '4'
        end as F,
        case
            when cs.monetary >= m.min_m and cs.monetary < m.q1_m then '1'
            when cs.monetary >= m.q1_m and cs.monetary < m.q2_m then '2'
            when cs.monetary >= m.q2_m and cs.monetary < m.q3_m then '3'
            else '4'
        end as M
    from #customer_statistics cs
    cross join IQR_R r
    cross join IQR_F f
    cross join IQR_M m
)

-- Step 4: Trả kết quả cuối cùng, có cột RFM_Score (nối các giá trị R, F, M)
select
    customerid,
    recency,
    frequency,
    monetary,
    R, F, M,
    R + F + M as RFM_Score 
from final_rfm
