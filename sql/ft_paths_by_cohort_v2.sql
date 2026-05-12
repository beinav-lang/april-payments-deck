-- FT split by PM age cohort × activation recency
-- Aligned with slide 7's "Paid Leases Breakdown · first_time" definition:
--   stripe_connect, COUNT(DISTINCT lease_id) where the lease's MIN(payments_month) = the cycle.
-- Adds:
--   * PM-age cohort (Mature PM>=90d since first invoice vs Onboarding PM<90d)
--   * Activation-recency split (same-cycle / earlier-cycle / unknown)
-- The lease_id is the unit of count; total_ft summed across cohorts per cycle
-- should match slide 7's first_time_paid_leases exactly.

WITH paid_leases_by_month AS (
  SELECT DISTINCT
    lease_id::STRING        AS lease_id,
    TO_DATE(payments_month) AS month
  FROM fivetran_database.analytics.stripe_connect
  WHERE lease_id IS NOT NULL
),
first_paid AS (
  SELECT lease_id, MIN(month) AS first_pay_month
  FROM paid_leases_by_month
  GROUP BY 1
),
-- Pull db_tenant (PM) for each FT lease from the rows in the first-paid month.
-- Use stripe_payments because stripe_connect doesn't carry db_tenant the same way.
lease_pm AS (
  SELECT
    sp.lease_id::STRING AS lease_id,
    MAX(sp.db_tenant)   AS db_tenant
  FROM fivetran_database.analytics.stripe_payments sp
  WHERE sp.lease_id IS NOT NULL
  GROUP BY 1
),
pm_first AS (
  SELECT db_tenant, MIN(created) AS pm_first_invoice
  FROM fivetran_database.analytics.stripe_payments
  WHERE amounttotransfer > 0
  GROUP BY 1
),
new_active AS (
  SELECT
    lease_id,
    DATE_TRUNC('month',
      CASE WHEN EXTRACT(DAY FROM first_active_date) >= 25
           THEN DATEADD(month, 1, first_active_date)
           ELSE first_active_date END) AS lease_activation_month
  FROM (
    SELECT lease_id, MIN(snapshot_date) AS first_active_date
    FROM fivetran_database.analytics.leases_daily_snapshot
    WHERE status = 'ACTIVE'
      AND merchant_account_flag = 1
      AND rent_frequency IN ('Monthly','Every2Weeks','Weekly','Daily')
      AND monthly_rent > 0
    GROUP BY 1
  )
)
SELECT
  TO_CHAR(fp.first_pay_month,'YYYY-MM') AS cycle,
  CASE
    WHEN pf.pm_first_invoice IS NULL THEN 'Mature'   -- treat missing PM as Mature
    WHEN DATEDIFF('day', pf.pm_first_invoice, fp.first_pay_month) < 90 THEN 'Onboarding'
    ELSE 'Mature'
  END AS cohort,
  COUNT(DISTINCT fp.lease_id) AS total_ft,
  COUNT(DISTINCT CASE WHEN na.lease_activation_month = fp.first_pay_month
       THEN fp.lease_id END) AS same_cycle_ft,
  COUNT(DISTINCT CASE WHEN na.lease_activation_month < fp.first_pay_month
       THEN fp.lease_id END) AS earlier_ft,
  COUNT(DISTINCT CASE WHEN na.lease_activation_month IS NULL
       THEN fp.lease_id END) AS unknown_ft
FROM first_paid fp
LEFT JOIN lease_pm   lp ON lp.lease_id = fp.lease_id
LEFT JOIN new_active na ON na.lease_id = fp.lease_id
LEFT JOIN pm_first   pf ON pf.db_tenant = lp.db_tenant
WHERE fp.first_pay_month BETWEEN '2025-09-01' AND '2026-04-01'
GROUP BY 1, 2
ORDER BY 1, 2;
