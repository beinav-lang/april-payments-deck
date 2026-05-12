-- For each payments_month, decompose FT volume:
--   pms_with_ft   = # of distinct PMs that contributed any FT that month
--   avg_ft_per_pm = mean FT per PM
--   p50_ft_per_pm = median FT per PM
--   top10_share   = share of FT from the top 10 PMs (concentration check)
--   new_active_leases = how many leases became active that month (from leases_daily_snapshot)
--   invites_in_window = how many of those got an invite within ±45d
-- Compare Jan-Apr '26 vs Mar-Dec '25.

WITH first_pay AS (
  SELECT customer_id,
         MIN(payments_month) AS first_pay_month,
         MAX(db_tenant) AS db_tenant
  FROM fivetran_database.analytics.stripe_payments
  WHERE amounttotransfer > 0 AND type IN ('charge','payment')
  GROUP BY 1
),
ft_by_pm AS (
  SELECT TO_CHAR(first_pay_month,'YYYY-MM') AS cycle,
         db_tenant,
         COUNT(*) AS ft_at_pm
  FROM first_pay
  WHERE first_pay_month BETWEEN '2025-03-01' AND '2026-04-01'
  GROUP BY 1, 2
),
ranked AS (
  SELECT cycle, db_tenant, ft_at_pm,
    ROW_NUMBER() OVER (PARTITION BY cycle ORDER BY ft_at_pm DESC) AS rk,
    SUM(ft_at_pm) OVER (PARTITION BY cycle) AS total_ft
  FROM ft_by_pm
)
SELECT cycle,
  COUNT(*) AS pms_with_ft,
  SUM(ft_at_pm) AS total_ft,
  ROUND(SUM(ft_at_pm)*1.0/COUNT(*), 1) AS avg_ft_per_pm,
  MEDIAN(ft_at_pm) AS median_ft_per_pm,
  ROUND(100.0 * SUM(CASE WHEN rk <= 10 THEN ft_at_pm ELSE 0 END) / SUM(ft_at_pm), 1) AS top10_pm_share_pct
FROM ranked
GROUP BY 1
ORDER BY 1;
