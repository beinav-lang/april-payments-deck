-- Exploration B: FT split by PM segment (Upper/Mid/SMB/Emerging), per cycle
-- See where FT growth is coming from
WITH first_pay AS (
  SELECT customer_id, MIN(payments_month) AS first_pay_month
  FROM fivetran_database.analytics.stripe_payments
  WHERE amounttotransfer > 0 AND type IN ('charge','payment')
  GROUP BY 1
),
pm_seg AS (
  SELECT db_tenant,
    CASE
      WHEN MAX(stripe_subscription_price_quantity_c) <= 10  THEN '1.Emerging'
      WHEN MAX(stripe_subscription_price_quantity_c) <= 50  THEN '2.SMB'
      WHEN MAX(stripe_subscription_price_quantity_c) <= 300 THEN '3.MidMarket'
      WHEN MAX(stripe_subscription_price_quantity_c) >  300 THEN '4.UpperMarket'
      ELSE '0.Unknown'
    END AS segment
  FROM fivetran_database.analytics.stripe_payments
  WHERE stripe_subscription_price_quantity_c IS NOT NULL
  GROUP BY 1
),
ft AS (
  SELECT fp.customer_id, fp.first_pay_month,
         MAX(sp.db_tenant) AS db_tenant
  FROM first_pay fp
  JOIN fivetran_database.analytics.stripe_payments sp
    ON sp.customer_id = fp.customer_id
   AND sp.payments_month = fp.first_pay_month
   AND sp.amounttotransfer > 0 AND sp.type IN ('charge','payment')
  WHERE fp.first_pay_month BETWEEN '2025-03-01' AND '2026-04-01'
  GROUP BY 1, 2
)
SELECT
  TO_CHAR(first_pay_month,'YYYY-MM') AS cycle,
  COALESCE(ps.segment, '0.Unknown') AS segment,
  COUNT(*) AS ft_count
FROM ft
LEFT JOIN pm_seg ps ON ps.db_tenant = ft.db_tenant
GROUP BY 1, 2
ORDER BY 1, 2;
