# ==============================================================================
# The "Time Machine" Credit Model
# Stage 1: Load and Clean Lending Club Data
# ==============================================================================

# Set reproducible environment
set.seed(42)

suppressPackageStartupMessages({
  library(tidyverse)
  library(lubridate)
})

# Locate raw data file (check current directory, data/, or parent directories)
candidates <- c(
  "accepted_2007_to_2018Q4.csv.gz",
  "data/accepted_2007_to_2018Q4.csv.gz",
  "../accepted_2007_to_2018Q4.csv.gz",
  "../data/accepted_2007_to_2018Q4.csv.gz"
)
data_file <- candidates[file.exists(candidates)][1]

if (is.na(data_file)) {
  stop(
    "Data file 'accepted_2007_to_2018Q4.csv.gz' not found!\n",
    "Please download the file from Kaggle (wordsforthewise/lending-club) and place it in:\n",
    "  ", file.path(getwd(), "data", "accepted_2007_to_2018Q4.csv.gz")
  )
}

message("Reading raw data from: ", data_file)

# Columns required at application time (pre-origination only, avoiding leakage)
keep_cols <- c(
  "loan_amnt", "emp_length", "home_ownership", "annual_inc", "verification_status",
  "purpose", "addr_state", "dti", "delinq_2yrs", "inq_last_6mths", "open_acc",
  "pub_rec", "revol_bal", "revol_util", "total_acc", "mort_acc",
  "pub_rec_bankruptcies", "fico_range_low", "fico_range_high", "earliest_cr_line"
)

# Read only needed columns to preserve memory on laptop
raw <- read_csv(
  data_file,
  col_select = all_of(c("issue_d", "loan_status", "term", keep_cols)),
  show_col_types = FALSE
)

message("Raw rows loaded: ", nrow(raw))

# Filter to finished 36-month loans and engineer pre-decision features
df <- raw %>%
  # 36-month loans have a leading space in the raw data (" 36 months")
  filter(term == " 36 months", loan_status %in% c("Fully Paid", "Charged Off")) %>%
  mutate(
    # Target: bad = 1 if Charged Off, 0 if Fully Paid
    bad = as.integer(loan_status == "Charged Off"),
    
    # Parse dates robustly (handles 'Dec-2015' and 'Dec-15' patterns)
    issue_year = year(parse_date_time(issue_d, c("b-Y", "b-y"))),
    credit_hist_yrs = issue_year - year(parse_date_time(earliest_cr_line, c("b-Y", "b-y"))),
    
    # Midpoint of FICO range
    fico = (fico_range_low + fico_range_high) / 2,
    
    # Clean employment length into numeric years
    emp_len = case_when(
      emp_length == "< 1 year"  ~ 0,
      emp_length == "10+ years" ~ 10,
      TRUE ~ parse_number(emp_length)
    )
  ) %>%
  # Drop raw columns superseded by engineered variables or post-decision
  select(
    -term, -loan_status, -issue_d, -earliest_cr_line,
    -fico_range_low, -fico_range_high, -emp_length
  )

# Model candidate feature variables
feat <- setdiff(names(df), c("bad", "issue_year"))

message("Cleaned dataframe created: ", nrow(df), " loans across ", length(feat), " features.")

# Sanity checks
cat("\n--- Check 1: Issue Year Distribution ---\n")
print(table(df$issue_year, useNA = "ifany"))

cat("\n--- Check 2: Target (bad) Prevalence by Year ---\n")
df %>%
  group_by(issue_year) %>%
  summarise(
    n_loans = n(),
    bads = sum(bad),
    bad_rate = round(mean(bad), 4)
  ) %>%
  print(n = 20)

cat("\n--- Check 3: Feature List (", length(feat), " features) ---\n", sep = "")
print(feat)

# Cache clean data to disk for fast loading in subsequent stages
if (!dir.exists("data")) dir.create("data")
saveRDS(df, "data/df_cleaned.rds")
message("Saved clean data cache to 'data/df_cleaned.rds'")
