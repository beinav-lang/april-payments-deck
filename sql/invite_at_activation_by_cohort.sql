-- % of new active leases invited ON or BEFORE lease activation,
-- split by PM-age cohort (Mature PM>=90d since first invoice vs Onboarding PM<90d).
-- Same cohort definition as /tmp/ft_paths_by_cohort_v2.sql for consistency.

WITH new_leases AS (
  SELECT lease_id, MIN(snapshot_date) AS first_active_date
  FROM fivetran_database.analytics.leases_daily_snapshot
  WHERE status = 'ACTIVE'
    AND merchant_account_flag = 1
    AND rent_frequency IN ('Monthly','Every2Weeks','Weekly','Daily')
    AND monthly_rent > 0
  GROUP BY 1
  HAVING MIN(snapshot_date) >= '2025-09-01'
),
lease_pm AS (
  SELECT lds.lease_id, MAX(lds.dbtenant) AS db_tenant,
         MAX(lds.dbt_first_invoice_date) AS dbt_first_invoice_date
  FROM fivetran_database.analytics.leases_daily_snapshot lds
  INNER JOIN new_leases nl ON nl.lease_id = lds.lease_id
  GROUP BY 1
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
  CASE
    WHEN lp.dbt_first_invoice_date IS NULL THEN 'Mature'  -- treat missing as Mature
    WHEN DATEDIFF('day', lp.dbt_first_invoice_date, nl.first_active_date) < 90
      THEN 'Onboarding'
    ELSE 'Mature'
  END AS cohort,
  COUNT(*) AS new_active_leases,
  SUM(CASE WHEN li.first_invite_sent_date IS NOT NULL
            AND li.first_invite_sent_date::date <= nl.first_active_date
           THEN 1 ELSE 0 END) AS invited_at_or_before_active,
  ROUND(100.0 * SUM(CASE WHEN li.first_invite_sent_date IS NOT NULL
            AND li.first_invite_sent_date::date <= nl.first_active_date
           THEN 1 ELSE 0 END) / COUNT(*), 2) AS pct_invited
FROM new_leases nl
LEFT JOIN lease_pm     lp ON lp.lease_id = nl.lease_id
LEFT JOIN lease_invite li ON li.lease_id = nl.lease_id
WHERE nl.first_active_date < '2026-04-25'
GROUP BY 1, 2
ORDER BY 1, 2;
