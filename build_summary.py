#!/usr/bin/env python3
"""Build a single analyst-ready summary of all April 2026 payments month data."""
import json, os, sys
from pathlib import Path

DIR = Path('/Users/bene/Projects/april_payments_deck')

def load(name):
    p = DIR / name
    if not p.exists() or p.stat().st_size == 0:
        return None
    with open(p) as f:
        return json.load(f)

def f(x):
    return None if x is None else float(x)

def pct(x):
    return None if x is None else f(x)*100 if abs(f(x)) < 1 else f(x)

summary = {}

# ---- Paid leases overall + drivers ----
pl = load('paid_leases.json')
plc = load('paid_lease_calc.json')
plb = load('paid_leases_breakdown.json')

if pl:
    rows = sorted(pl, key=lambda r: r['MONTH'])
    summary['paid_leases_trend'] = [
        {'month': r['MONTH'][:7], 'active': int(r['ACTIVE_LEASES']), 'paid': r['PAID_LEASES'],
         'pct_paid': round(r['PCT_PAID']*100, 2)} for r in rows
    ]

if plc:
    apr = next((r for r in plc if r['MONTH']=='2026-04-01'), None)
    mar = next((r for r in plc if r['MONTH']=='2026-03-01'), None)
    feb = next((r for r in plc if r['MONTH']=='2026-02-01'), None)
    summary['paid_leases_drivers'] = {
        'apr': apr, 'mar': mar, 'feb': feb,
        'apr_vs_mar': {
            'paid_mom': apr['PAID_LEASES_MOM_CHANGE'],
            'pct_paid_pp': apr['PCT_PAID_PP_CHANGE'],
            'retained_paid_delta': apr['RETAINED_PAID'] - mar['RETAINED_PAID'],
            'converted_unpaid_to_paid_delta': apr['CONVERTED_UNPAID_TO_PAID'] - mar['CONVERTED_UNPAID_TO_PAID'],
            'churn_delta': apr['PAID_CHURN_OR_DOWNGRADE'] - mar['PAID_CHURN_OR_DOWNGRADE'],
            'first_time_delta': apr['FIRST_TIME_PAID_ACTIVE_EOM'] - mar['FIRST_TIME_PAID_ACTIVE_EOM'],
        }
    }

if plb:
    rows = sorted(plb, key=lambda r: r['MONTH'])
    summary['paid_leases_breakdown'] = [
        {'month': r['MONTH'][:7], 'paid': r['PAID_LEASES'], 'existing': r['EXISTING_LEASES'],
         'first_time': r['FIRST_TIME_PAID_LEASES'], 'reactivated': r['REACTIVATED_LEASES'],
         'churned': r['CHURNED_LEASES']} for r in rows
    ]

# ---- KPI Dashboard ----
kpi = load('kpi_dashboard.json')
if kpi:
    by_month = {}
    for r in kpi:
        m = r['LEASEACTIVATIONMONTH'][:7]
        by_month.setdefault(m, {})[r['COHORT_STATUS']] = r
    summary['kpi_dashboard_by_month'] = by_month

# ---- Card volume ----
card = load('card_distribution.json')
if card:
    rows = sorted(card, key=lambda r: r['PAYMENTS_MONTH'])
    summary['card_volume_trend'] = [
        {'month': r['PAYMENTS_MONTH'][:7],
         'card_total': float(r['TOTAL_CARD_VOLUME_USD']),
         'ach_total': float(r['TOTAL_ACH_VOLUME_USD']),
         'total': float(r['TOTAL_VOLUME_USD']),
         'card_share': float(r['PCT_CARD_OF_TOTAL_VOLUME'])*100,
         'new_card': float(r['NEW_CARD_VOLUME_USD']),
         'returning_card': float(r['RETURNING_CARD_VOLUME_USD']),
         'pct_new_of_card': float(r['PCT_NEW_OF_CARD_VOLUME'])*100,
        } for r in rows
    ]

# ---- Paid leases by segment ----
seg = load('paid_leases_segment.json')
if seg:
    by_month = {}
    for r in seg:
        m = r['MONTH'][:7]
        by_month.setdefault(m, []).append({
            'segment': r['SEGMENT'], 'active': r['ACTIVE_LEASES'],
            'paid': r['PAID_LEASES'],
            'pct_paid': round(r['PCT_PAID']*100, 2) if r['PCT_PAID'] else None
        })
    summary['paid_leases_by_segment'] = by_month

# ---- Attach rate (by payments month) ----
att = load('leases_attach_rate.json')
if att:
    by_month = {}
    for r in att:
        m = r['PAYMENTS_MONTH'][:7]
        by_month.setdefault(m, {})[r['COHORT_STATUS']] = {
            'new_active': r['NEW_ACTIVE_LEASES'],
            'with_portal': r['LEASES_WITH_PORTAL_ACTIVE'],
            'attach_rate': float(r['ATTACH_RATE'])
        }
    summary['attach_rate_by_payments_month'] = by_month

# ---- First-time payers by account age ----
ftpa = load('ftp_account_age.json')
if ftpa:
    by_month = {}
    for r in ftpa:
        m = r['MONTH'][:7]
        by_month.setdefault(m, []).append({
            'bucket': r['ACCOUNT_AGE_BUCKET'],
            'tenants': r['FIRST_TIME_PAYING_TENANTS'],
            'card_tenants': r['CARD_TENANTS'],
            'pct_card': float(r['PCT_CARD'])*100 if r['PCT_CARD'] else None,
            'pct_card_amount': float(r['PCT_CARD_AMOUNT'])*100 if r['PCT_CARD_AMOUNT'] else None,
        })
    summary['ftp_by_account_age'] = by_month

# ---- First-time paying accounts (ACCOUNT level) ----
ftpt = load('ftp_account_type.json')
if ftpt:
    by_month = {}
    for r in ftpt:
        m = r['MONTH'][:7]
        by_month.setdefault(m, {})[r['ACCOUNT_PAID_SEGMENT']] = {
            'tenants': r['TENANTS'], 'dbtenants': r['DBTENANTS']
        }
    summary['ftp_account_type_by_month'] = by_month

# ---- Method stickiness ----
ms = load('method_stickiness.json')
if ms:
    summary['method_stickiness'] = [
        {'first_method': r['FIRST_METHOD'], 'm_offset': r['M_OFFSET'],
         'active_tenants': r['ACTIVE_TENANTS'],
         'stuck': r['STUCK_TO_FIRST_METHOD'],
         'switchers': r['SWITCHERS_TO_OTHER_METHOD'],
         'retention_pct': float(r['RETENTION_PCT'])} for r in ms
    ]

# ---- Cohort ----
cohort = load('paid_leases_cohort.json')
if cohort:
    summary['account_cohort_paid_pct'] = [
        {'cohort_month': r['COHORT_MONTH'][:7], 'new_accounts': r['NEW_ACCOUNTS'],
         **{f'M{i}_pct': float(r.get(f'M{i}_PCT', 0) or 0)*100 for i in range(7) if r.get(f'M{i}_PCT')}}
        for r in cohort
    ]

# ---- Optional add-ons (may be None) ----
for name, key in [('paid_accounts.json', 'paid_accounts'),
                   ('ftp_segment.json', 'ftp_segment'),
                   ('invitation_funnel.json', 'invitation_funnel'),
                   ('card_new_vs_returning.json', 'card_new_vs_returning')]:
    d = load(name)
    if d:
        summary[key] = d

with open(DIR / 'summary.json', 'w') as out:
    json.dump(summary, out, indent=2, default=str)
print('Wrote', DIR / 'summary.json', os.path.getsize(DIR / 'summary.json'), 'bytes')
print('Sections:', list(summary.keys()))
