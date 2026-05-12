-- For each payment cycle (25th→24th), compute at end-of-cycle (24th):
--   active_leases       = status='ACTIVE' on snapshot 24th
--   eligible_leases     = active AND active_tenant_flag=1 AND merchant_account_flag=1
--   paid_leases         = canonical: COUNT(DISTINCT lease_id) from stripe_payments WHERE payments_month='YYYY-MM-01'
-- Returns: cycle, totals + two derived ratios:
--   pct_eligible_of_active   (eligible / active)  from Mar '25
--   pct_paid_of_eligible     (paid / eligible)    from Sep '25 onward

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
active_snap AS (
  SELECT c.pmt_month, c.eod,
    COUNT(DISTINCT l.lease_id) AS active_leases,
    COUNT(DISTINCT CASE WHEN l.active_tenant_flag=1 AND l.merchant_account_flag=1
                        THEN l.lease_id END) AS eligible_leases
  FROM cycles c
  JOIN fivetran_database.analytics.leases_daily_snapshot l
    ON l.snapshot_date = c.eod
  WHERE l.status='ACTIVE'
  GROUP BY 1, 2
),
paid_per_cycle AS (
  SELECT TO_CHAR(payments_month,'YYYY-MM') AS pmt_month,
         COUNT(DISTINCT lease_id) AS paid_leases
  FROM fivetran_database.analytics.stripe_payments
  WHERE amounttotransfer > 0 AND type IN ('charge','payment')
    AND payments_month BETWEEN '2025-03-01' AND '2026-04-01'
  GROUP BY 1
)
SELECT
  a.pmt_month,
  a.active_leases,
  a.eligible_leases,
  p.paid_leases,
  ROUND(100.0 * a.eligible_leases / NULLIF(a.active_leases, 0), 2) AS pct_eligible_of_active,
  ROUND(100.0 * p.paid_leases     / NULLIF(a.eligible_leases, 0), 2) AS pct_paid_of_eligible,
  ROUND(100.0 * p.paid_leases     / NULLIF(a.active_leases, 0),   2) AS pct_paid_of_active
FROM active_snap a
LEFT JOIN paid_per_cycle p ON p.pmt_month = a.pmt_month
ORDER BY a.pmt_month;
