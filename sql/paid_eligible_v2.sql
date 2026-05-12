-- v2: use CANONICAL active = SUM(app_active_leases_c) from account_daily_state at 24th
-- and CANONICAL paid = COUNT(DISTINCT lease_id) WHERE payments_month=...
-- Eligible = COUNT from leases_daily_snapshot where status=ACTIVE + active_tenant + MA

WITH cycles AS (
  SELECT '2025-03'::VARCHAR AS pmt_month, '2025-03-24'::DATE AS eod UNION ALL
  SELECT '2025-04', '2025-04-24' UNION ALL
  SELECT '2025-05', '2025-05-24' UNION ALL
  SELECT '2025-06', '2025-06-24' UNION ALL
  SELECT '2025-07', '2025-07-24' UNION ALL
  SELECT '2025-08', '2025-08-24' UNION ALL
  SELECT '2025-09', '2025-09-24' UNION ALL
  SELECT '2025-10', '2025-10-24' UNION ALL
  SELECT '2025-11', '2025-11-24' UNION ALL
  SELECT '2025-12', '2025-12-24' UNION ALL
  SELECT '2026-01', '2026-01-24' UNION ALL
  SELECT '2026-02', '2026-02-24' UNION ALL
  SELECT '2026-03', '2026-03-24' UNION ALL
  SELECT '2026-04', '2026-04-24'
),
active_canon AS (
  SELECT c.pmt_month, c.eod,
    SUM(ads.app_active_leases_c) AS active_leases
  FROM cycles c
  JOIN fivetran_database.analytics.account_daily_state ads ON ads.snapshot_date = c.eod
  GROUP BY 1, 2
),
eligible_snap AS (
  SELECT c.pmt_month,
    COUNT(DISTINCT l.lease_id) AS eligible_leases
  FROM cycles c
  JOIN fivetran_database.analytics.leases_daily_snapshot l ON l.snapshot_date = c.eod
  WHERE l.status='ACTIVE'
    AND l.active_tenant_flag=1
    AND l.merchant_account_flag=1
  GROUP BY 1
),
paid_canon AS (
  SELECT TO_CHAR(payments_month,'YYYY-MM') AS pmt_month,
         COUNT(DISTINCT lease_id) AS paid_leases
  FROM fivetran_database.analytics.stripe_payments
  WHERE payments_month BETWEEN '2025-03-01' AND '2026-04-01'
  GROUP BY 1
)
SELECT
  ac.pmt_month,
  ac.active_leases,
  es.eligible_leases,
  pc.paid_leases,
  ROUND(100.0 * es.eligible_leases / NULLIF(ac.active_leases,0), 2) AS pct_eligible_of_active,
  ROUND(100.0 * pc.paid_leases     / NULLIF(es.eligible_leases,0), 2) AS pct_paid_of_eligible,
  ROUND(100.0 * pc.paid_leases     / NULLIF(ac.active_leases,0),   2) AS pct_paid_of_active
FROM active_canon ac
LEFT JOIN eligible_snap es ON es.pmt_month = ac.pmt_month
LEFT JOIN paid_canon pc    ON pc.pmt_month = ac.pmt_month
ORDER BY ac.pmt_month;
