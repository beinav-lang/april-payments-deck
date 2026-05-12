-- FT cohort split into 3 buckets: Onboarding (0-2 mo), Post-onboarding (2-3 mo), Mature (3+ mo)
-- Boundaries by days (calendar): <60 / 60-89 / >=90.
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
  CASE
    WHEN DATEDIFF('day', pf.pm_first_invoice, fp.first_pay_month) < 60  THEN '1.Onboarding'
    WHEN DATEDIFF('day', pf.pm_first_invoice, fp.first_pay_month) < 90  THEN '2.PostOnboarding'
    ELSE '3.Mature'
  END AS cohort,
  COUNT(*) AS ft_count
FROM first_pay fp
LEFT JOIN pm_first pf ON pf.db_tenant = fp.db_tenant
WHERE fp.first_pay_month BETWEEN '2025-03-01' AND '2026-04-01'
GROUP BY 1, 2
ORDER BY 1, 2;
