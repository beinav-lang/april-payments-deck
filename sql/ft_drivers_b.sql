-- Same-month activation+payment (M0 first-payment) per cycle.
-- Many FT cohort first-pays come from leases activated in months prior;
-- here we isolate the ones activated SAME MONTH as their first-payment.

WITH first_pay AS (
  SELECT customer_id, lease_id,
         MIN(payments_month) AS first_pay_month
  FROM fivetran_database.analytics.stripe_payments
  WHERE amounttotransfer > 0 AND type IN ('charge','payment')
    AND lease_id IS NOT NULL
  GROUP BY 1, 2
),
new_active AS (
  -- First day each lease appears as ACTIVE in leases_daily_snapshot, bucketed to payments_month
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
  COUNT(*) AS total_ft,
  SUM(CASE WHEN na.lease_activation_month = fp.first_pay_month THEN 1 ELSE 0 END) AS same_month_ft,
  SUM(CASE WHEN na.lease_activation_month < fp.first_pay_month THEN 1 ELSE 0 END) AS prior_month_ft,
  ROUND(100.0 * SUM(CASE WHEN na.lease_activation_month = fp.first_pay_month THEN 1 ELSE 0 END) / COUNT(*), 1) AS same_month_pct
FROM first_pay fp
LEFT JOIN new_active na ON na.lease_id = fp.lease_id
WHERE fp.first_pay_month BETWEEN '2025-08-01' AND '2026-04-01'  -- snapshot data starts mid-Aug
GROUP BY 1
ORDER BY 1;
