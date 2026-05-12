-- Cleaner FT cohort classification: PM age at FT customer's FIRST payment month.
-- Avoids the leases_daily_snapshot Aug '25 start-date anchoring bug.
-- Onboarding = PM had its first invoice <90 days before FT's first payment.
WITH first_pay AS (
  SELECT customer_id,
         MIN(payments_month) AS first_pay_month,
         MAX(db_tenant) AS db_tenant
  FROM fivetran_database.analytics.stripe_payments
  WHERE amounttotransfer > 0 AND type IN ('charge','payment')
  GROUP BY 1
),
pm_first AS (
  SELECT db_tenant, MIN(created) AS pm_first_invoice
  FROM fivetran_database.analytics.stripe_payments
  WHERE amounttotransfer > 0
  GROUP BY 1
)
SELECT
  TO_CHAR(fp.first_pay_month, 'YYYY-MM') AS cycle,
  CASE WHEN DATEDIFF('day', pf.pm_first_invoice, fp.first_pay_month) < 90
       THEN 'Onboarding' ELSE 'Mature' END AS cohort,
  COUNT(*) AS ft_count
FROM first_pay fp
LEFT JOIN pm_first pf ON pf.db_tenant = fp.db_tenant
WHERE fp.first_pay_month BETWEEN '2025-03-01' AND '2026-04-01'
GROUP BY 1, 2
ORDER BY 1, 2;
