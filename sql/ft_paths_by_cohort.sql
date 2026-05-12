-- FT split by PM age cohort × activation recency (same-cycle vs earlier-cycle)
-- Required for the Mature / Onboarding / All toggle on slide 8 (composition chart).
--
-- Output columns:
--   cycle        : payments_month YYYY-MM (25-to-24 cycle)
--   cohort       : 'Mature' (PM >=90 days since first invoice) or 'Onboarding' (<90 days)
--   total_ft     : count of FT customer+lease pairs in this cycle/cohort
--   same_cycle_ft: of those, lease activation month == first-pay month
--   earlier_ft   : lease activation month < first-pay month
--   unknown_ft   : no snapshot ACTIVE record (lease active before mid-Aug '25)
--
-- For the chart, sum same_cycle_ft and earlier_ft per (cycle, cohort) to build
-- the three toggle views: All (sum across cohorts), Mature, Onboarding.

WITH first_pay AS (
  SELECT customer_id, lease_id,
         MIN(payments_month) AS first_pay_month,
         MAX(db_tenant)      AS db_tenant
  FROM fivetran_database.analytics.stripe_payments
  WHERE amounttotransfer > 0 AND type IN ('charge','payment')
    AND lease_id IS NOT NULL
  GROUP BY 1, 2
),
pm_first AS (
  -- PM (db_tenant) age proxy: first invoice month
  SELECT db_tenant, MIN(created) AS pm_first_invoice
  FROM fivetran_database.analytics.stripe_payments
  WHERE amounttotransfer > 0
  GROUP BY 1
),
new_active AS (
  -- First day each lease appears as ACTIVE in leases_daily_snapshot,
  -- bucketed to payments_month (25-to-24 cycle).
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
  CASE WHEN DATEDIFF('day', pf.pm_first_invoice, fp.first_pay_month) < 90
       THEN 'Onboarding' ELSE 'Mature' END AS cohort,
  COUNT(*) AS total_ft,
  SUM(CASE WHEN na.lease_activation_month = fp.first_pay_month
           THEN 1 ELSE 0 END) AS same_cycle_ft,
  SUM(CASE WHEN na.lease_activation_month < fp.first_pay_month
           THEN 1 ELSE 0 END) AS earlier_ft,
  SUM(CASE WHEN na.lease_activation_month IS NULL
           THEN 1 ELSE 0 END) AS unknown_ft
FROM first_pay fp
LEFT JOIN new_active na ON na.lease_id = fp.lease_id
LEFT JOIN pm_first   pf ON pf.db_tenant = fp.db_tenant
WHERE fp.first_pay_month BETWEEN '2025-09-01' AND '2026-04-01'
GROUP BY 1, 2
ORDER BY 1, 2;
