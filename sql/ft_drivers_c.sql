-- 3-way activation-recency split of FT first-pays per cycle.
-- Replaces the 2-way split in ft_drivers_b.sql:
--   same_month_ft  = lease activated in the SAME payments_month as first-pay
--   m1_ft          = lease activated in the cycle immediately PRIOR (M-1)
--   older_ft       = lease activated in ANY earlier cycle (<= M-2)
--
-- A lease can fall into "older" only if it appears in leases_daily_snapshot
-- before that first-pay month. Snapshot data starts mid-Aug '25, so the
-- "older" bucket is artificially small for Sep-Nov '25 reads. Treat the
-- decomposition as clean from Dec '25 onward (any lease activated >=M-2
-- of Dec '25 = >=Oct '25, fully covered by the snapshot).
--
-- NOTE: same + m1 + older won't equal total because a small share of FT
-- first-pays have no snapshot ACTIVE record (left-join miss); that gap is
-- ~3-5% and is "unknown" activation recency.

WITH first_pay AS (
  SELECT customer_id, lease_id,
         MIN(payments_month) AS first_pay_month
  FROM fivetran_database.analytics.stripe_payments
  WHERE amounttotransfer > 0 AND type IN ('charge','payment')
    AND lease_id IS NOT NULL
  GROUP BY 1, 2
),
new_active AS (
  -- First day each lease appears as ACTIVE in leases_daily_snapshot,
  -- bucketed to payments_month (25th-to-24th cycle convention).
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
  SUM(CASE WHEN na.lease_activation_month = fp.first_pay_month
           THEN 1 ELSE 0 END)  AS same_month_ft,
  SUM(CASE WHEN na.lease_activation_month = DATEADD(month, -1, fp.first_pay_month)
           THEN 1 ELSE 0 END)  AS m1_ft,
  SUM(CASE WHEN na.lease_activation_month < DATEADD(month, -1, fp.first_pay_month)
           THEN 1 ELSE 0 END)  AS older_ft,
  SUM(CASE WHEN na.lease_activation_month IS NULL
           THEN 1 ELSE 0 END)  AS unknown_ft,
  ROUND(100.0 * SUM(CASE WHEN na.lease_activation_month = fp.first_pay_month
                         THEN 1 ELSE 0 END) / COUNT(*), 1) AS same_month_pct,
  ROUND(100.0 * SUM(CASE WHEN na.lease_activation_month = DATEADD(month, -1, fp.first_pay_month)
                         THEN 1 ELSE 0 END) / COUNT(*), 1) AS m1_pct,
  ROUND(100.0 * SUM(CASE WHEN na.lease_activation_month < DATEADD(month, -1, fp.first_pay_month)
                         THEN 1 ELSE 0 END) / COUNT(*), 1) AS older_pct
FROM first_pay fp
LEFT JOIN new_active na ON na.lease_id = fp.lease_id
WHERE fp.first_pay_month BETWEEN '2025-08-01' AND '2026-04-01'
GROUP BY 1
ORDER BY 1;
