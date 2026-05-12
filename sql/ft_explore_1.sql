-- Exploration A: FT count + FT $ + FT share of paid leases + FT share of $, per cycle
-- Mar '25 -> Apr '26
WITH first_pay AS (
  SELECT customer_id, MIN(payments_month) AS first_pay_month
  FROM fivetran_database.analytics.stripe_payments
  WHERE amounttotransfer > 0 AND type IN ('charge','payment')
  GROUP BY 1
),
labeled AS (
  SELECT sp.customer_id, sp.lease_id, sp.payments_month, sp.type, sp.amounttotransfer,
         CASE WHEN sp.payments_month = fp.first_pay_month THEN 'FT' ELSE 'Returning' END AS tenant_type
  FROM fivetran_database.analytics.stripe_payments sp
  JOIN first_pay fp ON fp.customer_id = sp.customer_id
  WHERE sp.amounttotransfer > 0 AND sp.type IN ('charge','payment')
    AND sp.payments_month BETWEEN '2025-03-01' AND '2026-04-01'
)
SELECT
  TO_CHAR(payments_month,'YYYY-MM') AS cycle,
  COUNT(DISTINCT CASE WHEN tenant_type='FT' THEN lease_id END) AS ft_leases,
  COUNT(DISTINCT CASE WHEN tenant_type='FT' THEN customer_id END) AS ft_tenants,
  COUNT(DISTINCT lease_id) AS total_paid_leases,
  ROUND(100.0 * COUNT(DISTINCT CASE WHEN tenant_type='FT' THEN lease_id END) / COUNT(DISTINCT lease_id), 2) AS ft_pct_of_paid,
  ROUND(SUM(CASE WHEN tenant_type='FT' THEN amounttotransfer END)/1e6, 2) AS ft_vol_m,
  ROUND(SUM(amounttotransfer)/1e6, 2) AS total_vol_m,
  ROUND(100.0 * SUM(CASE WHEN tenant_type='FT' THEN amounttotransfer END) / SUM(amounttotransfer), 2) AS ft_vol_share_pct
FROM labeled
GROUP BY 1
ORDER BY 1;
