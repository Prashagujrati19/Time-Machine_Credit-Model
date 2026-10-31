# The "Time Machine" Credit Model: Longitudinal Decay, Surveillance & Remediation

[![R 4.4+](https://img.shields.io/badge/R-4.4%2B-blue.svg)](https://www.r-project.org/)
[![License: CC0-1.0](https://img.shields.io/badge/License-CC0%201.0-lightgrey.svg)](http://creativecommons.org/publicdomain/zero/1.0/)
[![Model Governance: SR 11-7](https://img.shields.io/badge/Governance-SR%2011--7%20Compliant-green.svg)](https://www.federalreserve.gov/supervisionreg/srletters/sr1107.htm)

An end-to-end quantitative credit risk research project investigating **how fast a loan-approval scorecard goes out of date, which surveillance metrics detect deterioration first, and how management can optimally intervene**.

---

## 1. Problem Statement
Commercial banks operate credit scorecards subject to strict Model Risk Management regulations (Federal Reserve SR 11-7 / OCC 2011-12). However, customer risk profiles, economic cycles, and underwriting standards constantly evolve. 

This project simulates a **"Time Machine"** experiment:
- We build a standard bank credit scorecard using only completed loans originated in **2012–2014**.
- We **freeze** the model completely (no coefficient updates, no re-binning).
- We simulate running this frozen model in production across **2015 through 2018**.
- We measure how its **discrimination (Gini/KS)**, **calibration (expected vs realized default rates)**, and **portfolio profitability** decay over time.
- We establish an **early-warning surveillance engine** using the **Population Stability Index (PSI)** and **Characteristic Stability Index (CSI)**.
- We compare three actionable remediation strategies: **Strategy A (Do Nothing)**, **Strategy B (Reset Cut-off)**, and **Strategy C (Rolling Rebuild)** under unit credit economics.

---

## 2. Data and Out-of-Time (OOT) Split

### Data Source
- Dataset: [All Lending Club Loan Data (Kaggle wordsforthewise/lending-club)](https://www.kaggle.com/datasets/wordsforthewise/lending-club).
- File: `accepted_2007_to_2018Q4.csv.gz` (CC0 public domain license).
- Focus: 36-month amortizing personal loans with completed outcomes (`Fully Paid` or `Charged Off`).

### Strict Target Leakage Prevention
- **Target (`bad`):** $1$ if `loan_status == "Charged Off"`, $0$ if `loan_status == "Fully Paid"`. Active or open loans are excluded.
- **Leakage Dropped:** Post-origination performance fields (cumulative payments, collections, recoveries, delinquency dates).
- **Platform Models Dropped:** Lending Club's proprietary `grade`, `sub_grade`, and `int_rate` are excluded to evaluate raw credit fundamentals without copying Lending Club's internal decision algorithm.
- **Pre-Origination Predictors Retained:** FICO score midpoint, debt-to-income (DTI), credit history length, inquiries in last 6 months, revolving balance, revolving utilization, mortgage accounts, open accounts, annual income, employment length, home ownership, and loan purpose.

### The Time Split Architecture
Random train/test splits are strictly prohibited because they allow models to peek into future macroeconomic regimes. Instead, we enforce a chronological out-of-time (OOT) design:
- **Build Period (2012–2014):** Model estimation, tree-based WOE binning, IV filtering, and scorecard scaling.
- **Validation Period (2015):** Benchmark discrimination (Gini / KS) and calibrate the 70% approval cut-off (533 points).
- **Future Test Period (2016–2018):** Prospective out-of-time evaluation of the frozen scorecard with zero retraining.

---

## 3. Modelling Methodology
1. **Weight of Evidence (WOE) Binning:** Tree-based partitioning to optimize monotone default rates and isolate missing values into distinct risk bins.
2. **Information Value (IV) Filter:** Predictors with $IV \ge 0.02$ retained (`fico`, `dti`, `revol_util`, `inq_last_6mths`).
3. **Logistic Regression:** Generalized linear model fit on WOE-coded attributes, yielding intuitive, positive coefficients.
4. **Scorecard Points Scaling:** 
   $$\text{Factor} = \frac{PDO}{\ln(2)} = \frac{50}{\ln(2)} \approx 72.135$$
   $$\text{Offset} = Points_0 + \text{Factor} \times \ln(Odds_0) = 600 + 72.135 \times \ln(1/19) \approx 387.60$$
   $$\text{Score} = \text{Offset} - \text{Factor} \times \ln(\text{odds of bad})$$
   (600 points = odds of 1 bad per 19 goods, +50 points halves the odds of default).
5. **Approval Cut-off:** Calibrated on 2015 validation scores to approve the safest 70% of applicants ($Cutoff = 533\text{ points}$).

---

## 4. Key Findings

| Metric | 2015 (Valid) | 2016 (Test) | 2017 (Test) | 2018 (Test) | Finding |
| :--- | :---: | :---: | :---: | :---: | :--- |
| **Gini Index** | **0.329** | **0.317** | **0.344** | **0.333** | **Rank-order discrimination decays very slowly**, maintaining ~0.33 over 4 years. |
| **Calibration Gap** | **-1.2%** | **-0.9%** | **+20.9%** | **+40.0%** | **Calibration drifted severely** as right-censoring suppressed visible defaults. |
| **Scorecard PSI** | 0.002 | 0.007 | 0.011 | 0.023 | Score distribution shifted moderately as applicant profile matured. |
| **Surveillance Alert** | Green | Green | Watch | **Alert (Calib)** | Calibration alerted the committee **1 to 2 years before** ranking breakdown. |

### Remediation Policy Comparison (2016–2018 Avg)
- **Strategy A (Do Nothing):** Fixed cut-off allowed approval volume to drop from $70.0\%$ to $65.8\%$, forfeiting profitable loan volume.
- **Strategy B (Reset Cut-off):** Annually adjusting the cut-off restored the target 70% volume and **captured >95% of full model rebuild profit** with zero retraining or re-validation overhead.
- **Strategy C (Rolling Rebuild):** Retraining over a trailing 3-year rolling window yielded negligible Gini improvements (+0.005) while requiring costly model risk validation.

---

## 5. Key Diagnostic Charts

All figures are pre-rendered at 300 DPI in [`charts/`](charts/):
- **Origination Bad Rate & Right-Censoring:** [`charts/01_bad_rate_by_year.png`](charts/01_bad_rate_by_year.png)
- **FICO Default Monotonicity:** [`charts/03_bad_rate_by_fico.png`](charts/03_bad_rate_by_fico.png)
- **Longitudinal Gini Index:** [`charts/06_gini_by_year.png`](charts/06_gini_by_year.png)
- **Model Calibration Gap:** [`charts/07_calibration_gap_by_year.png`](charts/07_calibration_gap_by_year.png)
- **CSI Covariate Drift Heatmap:** [`charts/08_csi_heatmap.png`](charts/08_csi_heatmap.png)
- **Remediation Profit Comparison:** [`charts/09_strategy_profit_comparison.png`](charts/09_strategy_profit_comparison.png)

---

## 6. Limitations to State Honestly
1. **Right-Censoring / Maturity Bias:** 36-month loans issued in 2017 and 2018 had not completed repayment by the 2018 Q4 dataset cut-off. Unmatured loans create an artificial downward bias in observed default rates.
2. **Accepted Loans Only:** The dataset does not include declined applicants (sample selection bias; reject inference was not performed).
3. **Assumed Economics:** Profit estimates assume a fixed $10\%$ margin on good loans and $60\%$ Loss Given Default ($LGD$), though our sensitivity analysis confirms policy rankings hold across diverse parameter regimes.
4. **Peer-to-Peer vs Bank Cards:** Unsecured installment loans exhibit different seasoning dynamics than revolving credit cards.

---

## 7. How to Run the Project

### Prerequisites
- R (version 4.x)
- R packages: `tidyverse`, `lubridate`, `scorecard`, `pROC`, `scales`, `knitr`, `rmarkdown`

### Step 1: Clone or Extract the Project
Ensure you are in the project folder:
```bash
cd time-machine-credit-model
```

### Step 2: Add Raw Data (Optional)
If running on the full Kaggle dataset, download `accepted_2007_to_2018Q4.csv.gz` from Kaggle and place it in `data/`. *(If the raw file is omitted, `run_pipeline.R` automatically initializes a representative 60,000-loan benchmark cohort so all scripts and Rmd reports execute out-of-the-box).*

### Step 3: Run the Master Pipeline
In R or RStudio:
```r
source("run_pipeline.R")
```
Or from your shell:
```bash
Rscript run_pipeline.R
```

### Step 4: Knit the HTML Report
```r
rmarkdown::render("time_machine.Rmd")
```
Open `time_machine.html` in any web browser to view the interactive, publication-ready report.

---

## 8. Repository Structure
```
time-machine-credit-model/
├── README.md                          # Comprehensive project documentation
├── PROBLEM_STATEMENT.md               # One-page executive problem statement
├── INTERVIEW_PREP_AND_QNA.md          # 7 key technical interview questions & formulas
├── RESUME_AND_PITCH.md                # Quantitative resume bullets & 60-sec spoken pitch
├── time_machine.Rmd                   # End-to-end R Markdown report (knits to HTML)
├── time_machine.html                  # Pre-compiled HTML report
├── run_pipeline.R                     # Master pipeline script running Stages 1 through 6
├── 01_load_clean.R                    # Stage 1: Load and clean raw Lending Club data
├── 02_explore.R                       # Stage 2: Exploratory data analysis & 5 charts
├── 03_build_scorecard.R               # Stage 3: WOE binning, IV filter, logistic scorecard
├── 04_fast_forward_test.R             # Stage 4: Out-of-time longitudinal evaluation
├── 05_early_warning_signals.R         # Stage 5: PSI, CSI heatmap & alert lead time
├── 06_remediation_strategies.R        # Stage 6: Strategy A/B/C comparison & sensitivity
├── data/
│   ├── README.md                      # Kaggle download link & setup instructions
│   └── df_cleaned.rds                 # Pre-processed clean data cache
├── charts/                            # 9 publication-grade 300 DPI charts
└── deck/
    ├── 5_slide_executive_deck.md      # 5-slide executive presentation outline
    └── deck_presentation.html         # Interactive HTML slide deck
```
#   T i m e - M a c h i n e _ C r e d i t - M o d e l  
 #   T i m e - M a c h i n e _ C r e d i t - M o d e l  
 