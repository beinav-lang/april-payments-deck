-- Verify: are PMs sending portal invites at/around lease activation more for Onboarding accounts?
-- For each cohort_month × cohort_status, compute % of new leases with invite sent within ±45d of activation.

WITH new_leases AS (
  SELECT lease_id FROM fivetran_database.analytics.leases_daily_snapshot
  GROUP BY lease_id HAVING MIN(snapshot_date) >= '2025-09-01'
),
first_active AS (
  SELECT
    lease_id, first_active_date, dbt_first_invoice_date, dbtenant,
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
lease_invite AS (
  SELECT ltm.lease_id, MIN(t.portalinfo:invitationLastSentAt::timestamp) AS first_invite_sent_date
  FROM (SELECT DISTINCT lb._id AS lease_id, f.value:tenant::string AS tenant_id
        FROM airbyte_database.doorloop.leases lb, LATERAL FLATTEN(input => lb.tenants) f
        WHERE lb.deleted='false') ltm
  JOIN airbyte_database.doorloop.tenants t ON t._id = ltm.tenant_id
  WHERE t.portalinfo:invitationLastSentAt IS NOT NULL
  GROUP BY 1
)
SELECT
  TO_CHAR(fa.LeaseActivationMonth,'YYYY-MM') AS cohort_month,
  fa.cohort_status,
  COUNT(*) AS new_leases,
  SUM(CASE WHEN li.first_invite_sent_date IS NOT NULL
           AND ABS(DATEDIFF('day', fa.first_active_date, li.first_invite_sent_date)) <= 45
           THEN 1 ELSE 0 END) AS invited_in_window,
  ROUND(100.0 * SUM(CASE WHEN li.first_invite_sent_date IS NOT NULL
           AND ABS(DATEDIFF('day', fa.first_active_date, li.first_invite_sent_date)) <= 45
           THEN 1 ELSE 0 END) / COUNT(*), 2) AS pct_invited
FROM first_active fa
LEFT JOIN lease_invite li ON li.lease_id = fa.lease_id
WHERE fa.LeaseActivationMonth BETWEEN '2025-09-01' AND '2026-04-01'
GROUP BY 1, 2
ORDER BY 1, 2;
