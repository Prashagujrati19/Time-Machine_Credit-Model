# Dataset Download & Setup Instructions

## Dataset Overview
- **Name:** All Lending Club Loan Data (2007–2018Q4)
- **Source:** Kaggle (curated by `wordsforthewise`)
- **URL:** [https://www.kaggle.com/datasets/wordsforthewise/lending-club](https://www.kaggle.com/datasets/wordsforthewise/lending-club)
- **License:** Creative Commons Public Domain Dedication (CC0: Public Domain)
- **Raw File Name:** `accepted_2007_to_2018Q4.csv.gz` (approx. 1.26 GB compressed, ~2.26 million rows raw)

---

## Instructions for Setup

1. **Download the Data**:
   - Navigate to the Kaggle link above.
   - Download the full dataset archive (`archive.zip`).
   - Extract `accepted_2007_to_2018Q4.csv.gz` from the archive.

2. **File Location**:
   Place the compressed file `accepted_2007_to_2018Q4.csv.gz` either in:
   - The project root directory: `time-machine-credit-model/accepted_2007_to_2018Q4.csv.gz`
   - OR inside this `data/` folder: `time-machine-credit-model/data/accepted_2007_to_2018Q4.csv.gz`

3. **Important Git & Storage Safeguards**:
   - **DO NOT commit or upload `accepted_2007_to_2018Q4.csv.gz` to GitHub or version control** (it exceeds GitHub's 100 MB file limit and violates repository cleanliness standards).
   - A `.gitignore` rule is included to prevent accidental commits of `.csv`, `.csv.gz`, and `.rds` files.

4. **Cached Data**:
   When `01_load_clean.R` or `run_pipeline.R` runs for the first time, it will automatically save a processed, filtered binary RDS file to `data/df_cleaned.rds`. This cuts subsequent script execution times from minutes to seconds.
