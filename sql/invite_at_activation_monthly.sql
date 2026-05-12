-- % of new active leases that had a portal invite sent ON or BEFORE
-- the lease's first ACTIVE date in leases_daily_snapshot.
-- Renders the slide 8 "invited at lease creation" narrative as a monthly trend.
-- Snapshot data begins mid-Aug '25; restrict to Sep '25 onward.

WITH new_leases AS (
  SELECT
    lease_id,
    MIN(snapshot_date) AS first_active_date
  FROM fivetran_database.analytics.leases_daily_snapshot
  WHERE status = 'ACTIVE'
    AND merchant_account_flag = 1
    AND rent_frequency IN ('Monthly','Every2Weeks','Weekly','Daily')
    AND monthly_rent > 0
  GROUP BY 1
  HAVING MIN(snapshot_date) >= '2025-09-01'
),
lease_invite AS (
  SELECT ltm.lease_id,
         MIN(t.portalinfo:invitationLastSentAt::timestamp) AS first_invite_sent_date
  FROM (
    SELECT DISTINCT lb._id AS lease_id, f.value:tenant::string AS tenant_id
    FROM airbyte_database.doorloop.leases lb,
         LATERAL FLATTEN(input => lb.tenants) f
    WHERE lb.deleted = 'false'
  ) ltm
  JOIN airbyte_database.doorloop.tenants t
    ON t._id = ltm.tenant_id
  WHERE t.portalinfo:invitationLastSentAt IS NOT NULL
  GROUP BY 1
)
SELECT
  TO_CHAR(DATE_TRUNC('month',
    CASE WHEN EXTRACT(DAY FROM nl.first_active_date) >= 25
         THEN DATEADD(month, 1, nl.first_active_date)
         ELSE nl.first_active_date END), 'YYYY-MM') AS cycle,
  COUNT(*) AS new_active_leases,
  SUM(CASE WHEN li.first_invite_sent_date IS NOT NULL
            AND li.first_invite_sent_date::date <= nl.first_active_date
           THEN 1 ELSE 0 END) AS invited_at_or_before_active,
  ROUND(100.0 * SUM(CASE WHEN li.first_invite_sent_date IS NOT NULL
            AND li.first_invite_sent_date::date <= nl.first_active_date
           THEN 1 ELSE 0 END) / COUNT(*), 2) AS pct_invited_at_or_before_active
FROM new_leases nl
LEFT JOIN lease_invite li ON li.lease_id = nl.lease_id
WHERE nl.first_active_date < '2026-04-25'    -- exclude post-Apr cycle
GROUP BY 1
ORDER BY 1;
