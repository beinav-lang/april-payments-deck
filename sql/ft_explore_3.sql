-- Exploration C: median rent of FT leases over time, plus split by Mature/Onboarding cohort
WITH first_pay AS (
  SELECT customer_id, MIN(payments_month) AS first_pay_month
  FROM fivetran_database.analytics.stripe_payments
  WHERE amounttotransfer > 0 AND type IN ('charge','payment')
  GROUP BY 1
),
ft_leases AS (
  SELECT DISTINCT
    sp.lease_id, sp.customer_id, sp.payments_month,
    MAX(sp.db_tenant) OVER (PARTITION BY sp.lease_id) AS db_tenant
  FROM fivetran_database.analytics.stripe_payments sp
  JOIN first_pay fp ON fp.customer_id = sp.customer_id AND sp.payments_month = fp.first_pay_month
  WHERE sp.amounttotransfer > 0 AND sp.type IN ('charge','payment')
    AND sp.payments_month BETWEEN '2025-03-01' AND '2026-04-01'
    AND sp.lease_id IS NOT NULL
),
lease_meta AS (
  SELECT lease_id,
    MAX(monthly_rent) AS monthly_rent,
    MIN(snapshot_date) AS first_active_date,
    MAX(dbt_first_invoice_date) AS pm_first_invoice
  FROM fivetran_database.analytics.leases_daily_snapshot
  GROUP BY 1
)
SELECT
  TO_CHAR(ft.payments_month,'YYYY-MM') AS cycle,
  CASE WHEN DATEDIFF('day', lm.pm_first_invoice, lm.first_active_date) < 90
       THEN 'Onboarding' ELSE 'Mature' END AS cohort,
  COUNT(*) AS ft_count,
  ROUND(MEDIAN(lm.monthly_rent), 0) AS median_rent,
  ROUND(AVG(lm.monthly_rent), 0) AS avg_rent,
  SUM(CASE WHEN lm.monthly_rent < 1200 THEN 1 ELSE 0 END) AS ft_lt1200,
  SUM(CASE WHEN lm.monthly_rent >= 1200 THEN 1 ELSE 0 END) AS ft_gte1200,
  ROUND(100.0 * SUM(CASE WHEN lm.monthly_rent < 1200 THEN 1 ELSE 0 END)/COUNT(*), 1) AS pct_lt1200
FROM ft_leases ft
LEFT JOIN lease_meta lm ON lm.lease_id = ft.lease_id
WHERE lm.monthly_rent > 0
GROUP BY 1, 2
ORDER BY 1, 2;
