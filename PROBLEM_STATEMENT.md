# Problem Statement: The "Time Machine" Credit Model

## 1. Executive Context & The Core Question
In credit risk management, bank scorecards are developed on historical loan cohorts, approved through rigorous Model Risk Governance (e.g., Federal Reserve SR 11-7 / OCC 2011-12 standards), and deployed into production lending systems. However, real-world economic environments, customer demographics, and underwriting policies are non-stationary. Over time, models decay.

This project investigates the central quantitative question:
> **"How fast does an unsecured consumer loan scorecard go out of date, which surveillance metric warns you first, and what is the optimal remediation policy?"**

By creating a **"Time Machine"** experiment, we build a standardized logistic credit scorecard strictly using loans originated in **2012–2014**, freeze its parameters entirely, and simulate running that frozen model in production across **2015 through 2018**.

---

## 2. Experimental Design & The Out-of-Time (OOT) Split
Standard machine learning workflows often rely on randomized cross-validation (e.g., 80/20 train/test splits). In credit risk, **random splits are invalid** because they introduce future data leakage—allowing the model to peek into future macroeconomic regimes and overstating real-world predictive durability.

To enforce strict out-of-time discipline:
- **Build Period (2012–2014):** Model training, tree-based Weight of Evidence (WOE) binning, Information Value (IV) filtering, and logistic regression estimation.
- **Validation Period (2015):** In-sample validation to measure baseline discrimination (Gini / KS), check calibration, and benchmark the initial 70% approval cut-off.
- **Future Test Period (2016–2018):** Longitudinal out-of-time evaluation of the frozen scorecard with zero parameter retraining, observing the trajectory of model decay.

```
       2012      2013      2014      2015      2016      2017      2018
Build: [======== 3-Year Window ========]
Valid:                               [ 1 Year ] (Set Cut-off @ 70% Approval)
Test:                                          [=== 3-Year Frozen Run ===>]
```

---

## 3. Data Integrity, Target Definition & Leakage Prevention
We utilize the Lending Club accepted loans database, focusing exclusively on completed 36-month amortizing loans:
1. **Target Variable (`bad`):** Defined as $1$ if `loan_status == "Charged Off"` and $0$ if `loan_status == "Fully Paid"`. Unfinished or actively amortizing loans ("Current", "Late") are excluded to ensure clean ground truth.
2. **Strict Leakage Prevention:** All post-origination performance metrics (cumulative payments, collections, recoveries, delinquency history during loan life) are purged. Crucially, Lending Club's proprietary `grade`, `sub_grade`, and `int_rate` are dropped; these represent outputs of Lending Club's internal risk models, and including them would simply copy the platform's proprietary underwriting rather than assessing raw credit fundamentals.
3. **Application Information:** Features retained are strictly observable at the time of application: credit bureau records (FICO score midpoint, credit history length, inquiries, delinquency history, open accounts, revolving utilization) and applicant disclosures (annual income, debt-to-income ratio, home ownership, employment duration, loan purpose).

---

## 4. Key Quantitative Metrics & The Surveillance Framework
Model surveillance must decouple **discrimination** from **calibration**:
- **Discrimination (Gini / KS):** Measures how effectively the score rank-orders borrowers from safest to riskiest ($Gini = 2 \times AUC - 1$). A declining Gini signifies that the scorecard is losing its ability to separate good borrowers from bad.
- **Calibration (Calibration Gap):** Measures whether the predicted Probability of Default (PD) aligns with realized default rates ($\text{Calib Gap} = \frac{\text{Mean PD}}{\text{Observed Bad Rate}} - 1$). A model can maintain strong ranking power while suffering severe calibration drift due to macroeconomic shifts.
- **Early-Warning Indicators (PSI & CSI):** The Population Stability Index (PSI) tracks distributional divergence in customer credit scores against the build benchmark, while the Characteristic Stability Index (CSI) pinpoints which specific input feature (e.g., debt-to-income, credit inquiries) drove the shift.

---

## 5. Economic Impact & Policy Remediation
A decaying model directly erodes balance-sheet performance. We benchmark unit economics using stylized portfolio parameters:
- **Good Loan Margin ($MARGIN$):** $+10\%$ cumulative return on funded loan amount.
- **Loss Given Default ($LGD$):** $-60\%$ net loss on defaulted principal.
- **Break-Even Bad Rate ($p^*$):** $\frac{MARGIN}{MARGIN + LGD} = \frac{0.10}{0.10 + 0.60} \approx 14.29\%$. Any approval tranche with a default rate exceeding $14.29\%$ generates negative economic value.

When the early-warning trigger fires ($\text{PSI} > 0.25$ or $|\text{Calib Gap}| > 0.25$), we compare three actionable management interventions:
1. **Strategy A (Do Nothing):** Retain the frozen 2012–2014 scorecard and the fixed 2015 score cut-off.
2. **Strategy B (Reset Cut-off):** Maintain the frozen scorecard but dynamically reset the cut-off score each year based on the trailing year's score distribution to enforce a constant 70% approval rate.
3. **Strategy C (Periodic Rebuild):** Retrain the scorecard (re-binning, re-filtering, re-estimating logistic coefficients) over a rolling 3-year historical window and calibrate the cut-off on trailing originations.

---

## 6. Known Structural Limitations
1. **Right-Censoring / Maturity Bias:** 36-month loans issued in 2017 and 2018 have not fully matured by the dataset cut-off (2018 Q4). Rapid defaults occur early, while surviving loans remain uncounted, artificially suppressing observed default rates in recent cohorts.
2. **Survivorship / Reject Inference:** The dataset observes only accepted borrowers. Applicants rejected by Lending Club are unobserved, creating standard sample selection bias.
3. **External Validity:** Peer-to-peer personal loans exhibit distinct behavioral dynamics relative to revolving bank credit cards or secured mortgages.
