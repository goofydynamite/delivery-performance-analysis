# Delivery SLA recommendation

Period: latest 12 full months (Feb 2017 to Jan 2018), 21,262 delivered orders, target 95% on time.

## Summary

Only 42.7% of orders arrive on time, which is 52 points below target. I estimate late deliveries cost about Rs 23.4 lakh a year.

The main problem is how the delivery promise is set for each shipping mode, not where the orders go. First Class misses its promise on every order: it promises 1 day and always takes 2. Changing that promise to 2 days alone would lift on-time to 58% and save about Rs 5.7 lakh a year. If we also move 30% of Second Class volume to Standard Class, on-time goes to 60.3% and the saving to about Rs 6.9 lakh.

## What the data shows

| Shipping mode | Orders | On-time | Gap to 95% | Late cost (Rs L / yr) | Share of cost |
|---|---:|---:|---:|---:|---:|
| First Class | 3,245 | 0.0% | -95.0 pts | 5.71 | 24% |
| Second Class | 4,153 | 20.3% | -74.7 pts | 7.11 | 30% |
| Same Day | 1,169 | 47.4% | -47.6 pts | 1.07 | 5% |
| Standard Class | 12,695 | 60.5% | -34.5 pts | 9.49 | 41% |
| All orders | 21,262 | 42.7% | -52.3 pts | 23.38 | 100% |

1. Late rates differ a lot by shipping mode, and the test backs it up (chi-square p < 0.001, Cramér's V 0.48).
2. The premium modes are the worst. First Class is promised in 1 day and delivered in exactly 2. Second Class is promised in 2 and takes 2 to 6 days, so 80% of its orders are late, by 2.5 days on average.
3. Standard Class has the best rate but the biggest share of the cost because it carries about 60% of the volume. Volume matters as much as the rate.
4. Location doesn't explain it. Market (p = 0.53), region (p = 0.10) and India city tier (p = 0.53) show no significant difference. Indian metros were 1.4 points worse than Tier 2/3 cities, which isn't significant. First Class is 0% on time in metros, Tier 2 and Tier 3 alike.
5. There's no trend. Monthly on-time stayed between 41.3% and 45.0%, so this is structural, not seasonal.

## What I'd do

1. Change the First Class promise from 1 day to 2, or only keep selling "1 day" if there is actually a next-day lane behind it. Owner: ops and the product team that sets the checkout promise. Impact: 3,245 fewer broken promises a year, on-time from 42.7% to 58.0%, about Rs 5.7 L saved.
2. Put Second Class on a performance plan. Renegotiate the transit SLA with the line-haul partner (3 days max, with a penalty per late order). Until it improves, move about 30% of Second Class volume to Standard Class. Impact of the shift alone: about 500 fewer late orders and Rs 1.2 L saved.
3. Don't fund a Tier 2/3-specific programme. The tier difference isn't real, so it wouldn't fix anything.
4. Look at Standard Class next. It promises 4 days, takes 2 to 6, and ends up 40% late. Either add a buffer day to the checkout estimate or reduce the variation in transit time. I'd size this once 1 and 2 are in place.

Even with 1 and 2 done, on-time is around 60%, still well short of 95%. Getting closer needs Second and Standard Class transit times to actually improve, not just better promises.

## Assumptions and caveats

- Cost model (all in `cost_params` in `sql/06_cost_impact.sql`): holding cost is delay days x order value x 25% a year / 365, plus Rs 150 per late order for support, vouchers and a share of cancellations/RTO, at Rs 85 to the dollar. Holding cost alone is only Rs 5.1 L. The Rs 150 part (Rs 18.3 L) is most of the total, so that's the number I'd most want to replace with real contact-centre data.
- DataCo has no carrier names, so shipping mode stands in for the carrier service level.
- The actual shipping days look simulated (almost perfectly even spread within each mode). This shows the method; I'd check it against real carrier scan data before acting.
- On-time is counted per order, not per item, so orders with several items aren't counted twice. Cancelled orders (7,754 lines, SUSPECTED_FRAUD or CANCELED) are left out.
- India tiers follow the government's HRA city list: X cities are Metro, Y cities are Tier 2, the rest are Tier 3.
