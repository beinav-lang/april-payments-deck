-- For each ACTIVATION COHORT month (Sep '25 → Apr '26), count:
--   total_new_active = leases first-active in that month (cycle 25→24)
--   eligible_at_eom  = of those, how many had ≥1 active tenant + MA enabled at cycle-end (24th)
--   Split by Mature vs Onboarding (PM age at lease activation)

WITH new_leases AS (
  SELECT lease_id FROM fivetran_database.analytics.leases_daily_snapshot
  GROUP BY lease_id HAVING MIN(snapshot_date) >= '2025-09-01'
),
first_active AS (
  SELECT
    lease_id,
    first_active_date,
    dbt_first_invoice_date,
    dbtenant,
    DATE_TRUNC('month',
      CASE WHEN EXTRACT(DAY FROM first_active_date) >= 25
           THEN DATEADD(month, 1, first_active_date)
           ELSE first_active_date END) AS LeaseActivationMonth,
    CASE WHEN DATEDIFF('day', dbt_first_invoice_date, first_active_date) < 90
         THEN 'Onboarding' ELSE 'Mature' END AS cohort_status
  FROM (
    SELECT lds.lease_id, lds.snapshot_date AS first_active_date,
           lds.dbt_first_invoice_date, lds.dbtenant,
           ROW_NUMBER() OVER (PARTITION BY lds.lease_id ORDER BY lds.snapshot_date) AS rn
    FROM fivetran_database.analytics.leases_daily_snapshot lds
    INNER JOIN new_leases nl ON lds.lease_id = nl.lease_id
    WHERE lds.status='ACTIVE' AND lds.snapshot_date BETWEEN '2025-09-01' AND '2026-04-24'
      AND lds.rent_frequency IN ('Monthly','Every2Weeks','Weekly','Daily')
      AND lds.merchant_account_flag = 1
  ) WHERE rn = 1
),
-- For each lease, take the END-OF-CYCLE snapshot (last day of its activation cycle = 24th)
-- to determine eligibility (active + active_tenant_flag + MA flag).
-- We'll use the snapshot closest to but not after cycle-end.
eod_snap AS (
  SELECT fa.lease_id, fa.LeaseActivationMonth, fa.cohort_status,
    -- Cycle-end date = 24th of LeaseActivationMonth (if month >= Sep '25)
    DATEADD('day', 23, fa.LeaseActivationMonth) AS cycle_end_date
  FROM first_active fa
),
eligibility AS (
  SELECT
    es.lease_id, es.LeaseActivationMonth, es.cohort_status,
    MAX(CASE WHEN lds.snapshot_date = es.cycle_end_date
              AND lds.status='ACTIVE'
              AND lds.active_tenant_flag = 1
              AND lds.merchant_account_flag = 1
         THEN 1 ELSE 0 END) AS is_eligible
  FROM eod_snap es
  LEFT JOIN fivetran_database.analytics.leases_daily_snapshot lds
    ON lds.lease_id = es.lease_id AND lds.snapshot_date = es.cycle_end_date
  GROUP BY 1, 2, 3
)
SELECT
  TO_CHAR(LeaseActivationMonth,'YYYY-MM') AS cohort_month,
  cohort_status,
  COUNT(*) AS new_active_leases,
  SUM(is_eligible) AS eligible_at_eom,
  ROUND(100.0 * SUM(is_eligible) / COUNT(*), 2) AS pct_eligible
FROM eligibility
WHERE LeaseActivationMonth BETWEEN '2025-09-01' AND '2026-04-01'
GROUP BY 1, 2
ORDER BY 1, 2;
