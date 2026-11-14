"""Significance checks for the delivery findings.

Reads exports/orders.csv (one row per delivered order, built by sql/08_export_for_tableau.sql)
and tests whether late-delivery rates really differ by shipping mode, market and India city tier.
Run from the project folder:  py python/stat_tests.py
"""
from pathlib import Path

import numpy as np
import pandas as pd
from scipy.stats import chi2_contingency
from statsmodels.stats.proportion import proportions_ztest

ROOT = Path(__file__).resolve().parents[1]
orders = pd.read_csv(ROOT / "exports" / "orders.csv")


def cramers_v(table: pd.DataFrame) -> float:
    chi2 = chi2_contingency(table)[0]
    n = table.to_numpy().sum()
    return float(np.sqrt(chi2 / (n * (min(table.shape) - 1))))


def chi_square(df: pd.DataFrame, column: str) -> dict:
    table = pd.crosstab(df[column], df["is_late"])
    p = chi2_contingency(table)[1]
    return {"test": f"Late rate by {column}", "n_orders": len(df),
            "p_value": p, "cramers_v": round(cramers_v(table), 3)}


results = [
    chi_square(orders, "shipping_mode"),
    chi_square(orders, "market"),
    chi_square(orders, "order_region"),
]

india = orders[orders["india_tier"].notna()]
results.append(chi_square(india, "india_tier"))

# Metro vs Tier 2/3 two-proportion z-test
metro = india[india["india_tier"] == "Metro"]["is_late"]
non_metro = india[india["india_tier"] != "Metro"]["is_late"]
z, p = proportions_ztest([metro.sum(), non_metro.sum()], [len(metro), len(non_metro)])
results.append({"test": "India Metro vs Tier 2/3 (two-proportion z)",
                "n_orders": len(india), "p_value": p,
                "cramers_v": None,
                "diff_pp": round(100 * (metro.mean() - non_metro.mean()), 1)})

out = pd.DataFrame(results)
out["significant_at_5pct"] = out["p_value"] < 0.05
out["p_value"] = out["p_value"].map(lambda v: f"{v:.3g}")
print(out.to_string(index=False))
(ROOT / "reports").mkdir(exist_ok=True)
out.to_csv(ROOT / "reports" / "stat_tests.csv", index=False)
