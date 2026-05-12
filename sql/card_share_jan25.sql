-- Card volume share Jan '25 - Apr '25 (extend the trend back to Jan '25)
WITH vol AS (
  SELECT payments_month,
    SUM(CASE WHEN type='charge'  THEN amounttotransfer END) AS card_vol,
    SUM(CASE WHEN type IN ('charge','payment') THEN amounttotransfer END) AS total_vol
  FROM fivetran_database.analytics.stripe_payments
  WHERE amounttotransfer > 0 AND type IN ('charge','payment')
    AND payments_month BETWEEN '2025-01-01' AND '2025-04-01'
  GROUP BY 1
)
SELECT TO_CHAR(payments_month,'YYYY-MM') AS cycle,
  ROUND(card_vol/1e6, 2)  AS card_volume_m,
  ROUND(total_vol/1e6, 2) AS total_volume_m,
  ROUND(100.0 * card_vol / total_vol, 2) AS card_share_pct
FROM vol
ORDER BY 1;
