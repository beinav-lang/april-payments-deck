# % Card Share Drop — full analysis from previous session

Source: prior session "% card drop analysis" (2026-04-30).

## Headline
April share **18.02% → 17.75% (−0.27pp)**. Card volume actually grew +3.6% ($52.8M → $54.7M); ACH grew +5.6% ($240.0M → $253.3M).

## The four tenant groups in April

| Group | Tenants | Apr volume | Charge share |
|---|---:|---:|---:|
| **A. Stayers** (paid both Mar + Apr) | 157,868 | $265.11M | Mar 16.75% → Apr **16.07%** (−0.68pp) |
| **B. Mar-only** (churned/skipped Apr) | 18,677 | $28.71M (Mar) | 29.71% |
| **C. April first-timers** | 15,254 | $26.28M | **29.24%** |
| **D. Returners-after-gap** (paid before, skipped Mar, returned Apr) | 10,763 | $16.59M | **26.29%** |

## Mar→Apr decomposition of the −0.27pp drop

| Lever | Δ | Contribution |
|---|---|---|
| Stayer rate ↓ (16.34 → 16.07) | −0.27pp | **−0.23pp** |
| Stayer weight ↓ (87.74 → 86.08) | −1.66pp | −0.27pp |
| First-timer rate ↓ (29.87 → 29.24) | −0.63pp | −0.05pp |
| First-timer weight ↑ (8.18 → 8.53) | +0.35pp | +0.10pp |
| **Returner-gap rate ↓ (30.34 → 26.29)** | **−4.05pp** | **−0.19pp** |
| Returner-gap weight ↑ (4.08 → 5.39) | +1.31pp | +0.37pp |
| **Net** | | **−0.27pp** |

## The real WHY (debunked + confirmed)

1. **Stayer drift is steady-state, not an April spike.** ~157K constant-cohort tenants drift off card at **~0.65pp/month every month** (range −0.36 to −0.97). April's −0.68pp is unremarkable. So this drag exists every month — gets normally offset by high-card inflow.

2. **The April change is the OFFSET weakening.** Blended inflow card share hit **28.10% in April — the lowest in the 15-month series** (typical 29–32%, Q1'25 peak 35%). With less high-card inflow, the steady-drift drag stops getting offset.

3. **Within inflow, the big mover was Returners-after-gap, not first-timers.** First-timers fell only −0.63pp MoM (29.87 → 29.24). Returners-after-gap **collapsed −4.05pp** (30.34 → 26.29). This is the single biggest single-group rate change.

4. **Long arc:** First-time card share peaked at 38.32% in Mar 2025 → drifted down to 29.24% in Apr 2026. **−9pp from peak.** Returning peaked Jan 2026 at 17.16%, declined 3 straight months to 16.68% Apr.

5. **Cohort dilution mechanism:** Each cohort enters at ~30% card, decays toward the legacy floor of ~14.42% over time. New cohorts haven't faded yet so they prop returning *up*, not drag it down. Q1'26 graduates: 21.98%. Q4'25 graduates: 20.80%. Legacy (pre-Oct '25): 14.42%.

6. **Ended-leases contribution:** Leases that ended in March were 24.3% card-funded (vs 18% portfolio-wide). Their disappearance accounts for **~0.11pp of the 0.27pp drop (~40%)**.

## Hypotheses that were tested and DEBUNKED

- ❌ "Recent first-timer graduates have lower card share and drag returning down" — opposite is true. Graduates have *higher* card share than legacy. They prop returning *up*; the boost is just shrinking.
- ❌ "Active card→ACH switching spike in April" — switching is steady-state at ~0.65pp/month for 15 months running.

## What this means for the deck

The current "ACH outpacing, not card weakness" framing is partially right but understates the structural concern. The richer story:

- **Card share decline is a slow-burn cohort dilution.** Stayers leak ~0.65pp of card share per month every month. Usually fresh first-timers (entering at ~30% card) refill the bucket.
- **April's drop happened because the refill weakened.** Inflow card share hit a 15-month low. Returners-after-gap was the biggest single mover (−4pp).
- **Long-arc story:** First-time card share is in a 13-month decline (38% peak → 29% Apr). Each new cohort enters with less card → cumulative drag on the headline as cohorts age.
- **Plan miss is structural, not a one-off.** If first-time card share keeps falling, the offset against stayer drift will keep weakening, and the share will keep declining.

## Proposed action items (additional to current 5)

- Investigate WHY first-time card share has fallen ~9pp since Mar '25. Candidates: PM-side defaults, payment-method defaults in the wizard, channel mix of new tenants.
- The reduced-fee 2nd-cycle experiment targets stayer drift. The bigger lever may be **first-timer card adoption at sign-up**.
