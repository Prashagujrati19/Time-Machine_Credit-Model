# The "Time Machine" Credit Model
## Executive Slide Deck: Out-of-Time Scorecard Decay & Surveillance

---

### Slide 1: The Executive Question
* **The Industry Dilemma:** Bank credit scorecards are approved through rigorous governance (SR 11-7) on historical data, but economic conditions, borrower behaviors, and underwriting regimes constantly drift.
* **The Question:** *How fast does an unsecured consumer loan scorecard go out of date, what surveillance metric warns you first, and what is the optimal remediation policy?*
* **The "Time Machine" Method:** Build a standard logistic scorecard strictly on loans originated in **2012–2014**, freeze its weights entirely, and simulate operating it in production across **2015 through 2018** without retraining.

---

### Slide 2: Data Discipline & The Time Split
* **Look-Ahead Leakage vs Reality:** Random 80/20 train/test splits leak future regimes into historical models, overstating predictive stability. Chronological out-of-time (OOT) testing is the only regulatory-compliant benchmark.
* **Target & Cohort Definition:**
  * **Portfolio:** Completed 36-month amortizing loans from Lending Club (`bad = 1` if Charged Off, `0` if Fully Paid).
  * **Strict Leakage Prevention:** Post-origination servicing history and internal platform models (`grade`, `sub_grade`, `int_rate`) purged to evaluate true credit fundamentals.
* **The Time Split:**
  * **Build (2012–2014):** Feature engineering, WOE binning, IV filtering, logistic scorecard estimation.
  * **Validation (2015):** Benchmark discrimination (Gini / KS) and establish the 70% approval cut-off (533 points).
  * **Future Run (2016–2018):** Longitudinal frozen deployment tracking degradation.

---

### Slide 3: Model Architecture & Longitudinal Decay
* **Scorecard Specification:** Standard points system ($Points_0 = 600$, $Odds_0 = 1/19$, $PDO = 50$). Features selected: FICO Score, Debt-to-Income (DTI), Revolving Utilization, Credit Inquiries.
* **2015 Validation Benchmark:** Validation Gini = **0.329**, KS = **0.237**, Cut-off = **533 points** (70.0% approval).
* **The Aging Trajectory (2015 $\rightarrow$ 2018):**
  * **Discrimination Resilience:** Gini stayed exceptionally resilient (0.317 to 0.344), showing the model never lost its capacity to rank-order relative risk.
  * **Calibration & Mix Drift:** Realized bad rates and score distributions shifted, causing the model to appear pessimistic in later years as seasoning bias (right-censoring) suppressed visible defaults.

---

### Slide 4: Early-Warning Surveillance & Lead Time
* **The Surveillance Framework:** Decoupling population drift (PSI) and feature shift (CSI) from lagging credit loss outcomes.
  * **PSI (Population Stability Index):** Tracks shifts in total scorecard point distributions against the 2012–14 baseline.
  * **CSI (Characteristic Stability Index):** Pinpoints covariate drift in individual variables (DTI and inquiries drifted first).
* **Alert Trigger:** Alert fires if $\text{PSI} > 0.25$ or $|\text{Calib Gap}| > 0.25$.
* **Key Finding:** *Surveillance alerts triggered via calibration gap and covariate drift 1 to 2 years before any structural breakdown in borrower rank-ordering power occurred.*

---

### Slide 5: Remediation Strategy & Ongoing Monitoring Plan
* **Policy Cost Comparison (2016–2018):**
  * **Strategy A (Do Nothing):** Fixed cut-off allows approval volume to fluctuate with applicant drift ($65.8\% - 68.3\%$).
  * **Strategy B (Reset Cut-off):** Annually adjusting the score threshold restores the target 70% volume and captures >95% of rebuild economic value with **zero retraining overhead**.
  * **Strategy C (Rolling Rebuild):** Retraining over a trailing 3-year window yields marginal discrimination gains but introduces high validation and deployment costs.
* **Three-Line Recommendation:**
  1. Rely on dynamic cut-off resets (Strategy B) for routine annual maintenance.
  2. Reserve full model retraining (Strategy C) strictly for multi-point Gini degradation ($\Delta Gini > 0.05$) combined with major population drift ($\text{PSI} > 0.25$).
  3. Maintain quarterly CSI tracking to proactively detect shifting credit tier applicant mixes.
