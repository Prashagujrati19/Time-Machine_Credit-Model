# ==============================================================================
# The "Time Machine" Credit Model
# Stage 3: Build & Calibrate the Scorecard on 2012–2014 Build Data
# ==============================================================================

set.seed(42)

suppressPackageStartupMessages({
  library(tidyverse)
  library(scorecard)
  library(pROC)
})

# Load cleaned data
if (!exists("df")) {
  if (file.exists("data/df_cleaned.rds")) {
    df <- readRDS("data/df_cleaned.rds")
  } else {
    source("01_load_clean.R")
  }
}

feat <- setdiff(names(df), c("bad", "issue_year"))

# Out-of-time splits
build <- df %>% filter(issue_year %in% 2012:2014)
valid <- df %>% filter(issue_year == 2015)

cat("Build cohort (2012-2014) loans:", nrow(build), "| Bads:", sum(build$bad), 
    sprintf("(%.2f%%)\n", 100 * mean(build$bad)))
cat("Valid cohort (2015) loans:", nrow(valid), "| Bads:", sum(valid$bad), 
    sprintf("(%.2f%%)\n", 100 * mean(valid$bad)))

# ------------------------------------------------------------------------------
# Reusable Function: fit_scorecard()
# ------------------------------------------------------------------------------
fit_scorecard <- function(train, iv_min = 0.02) {
  dt <- train %>% select(all_of(c(feat, "bad"))) %>% as.data.frame()
  
  # Tree-based optimal WOE binning
  bins <- woebin(dt, y = "bad", method = "tree", print_step = 0)
  
  # Information Value (IV) filtering
  iv_vals <- sapply(bins, function(b) b$total_iv[1])
  kept <- names(iv_vals)[iv_vals >= iv_min & names(iv_vals) != "bad"]
  bins_keep <- bins[kept]
  
  # Apply WOE coding
  woe <- woebin_ply(dt[, c(kept, "bad")], bins_keep, print_step = 0)
  
  # Fit logistic regression on WOE variables
  model <- glm(bad ~ ., data = woe, family = binomial())
  
  # Scorecard points scaling: 600 pts @ odds 1/19 (PD=5%), +50 pts doubles odds
  card <- scorecard(bins_keep, model, points0 = 600, odds0 = 1/19, pdo = 50)
  
  list(bins = bins_keep, model = model, card = card, kept = kept, iv = iv_vals[kept])
}

# ------------------------------------------------------------------------------
# Reusable Function: score_with()
# ------------------------------------------------------------------------------
score_with <- function(fit, d) {
  x <- d %>% select(all_of(fit$kept)) %>% as.data.frame()
  w <- woebin_ply(x, fit$bins, print_step = 0)
  
  d %>% mutate(
    pd = as.numeric(predict(fit$model, newdata = w, type = "response")),
    score = scorecard_ply(x, fit$card, only_total_score = TRUE, print_step = 0)$score
  )
}

# ------------------------------------------------------------------------------
# Train the 2012-2014 Frozen Scorecard
# ------------------------------------------------------------------------------
message("Fitting scorecard on 2012-2014 build cohort...")
base_fit <- fit_scorecard(build, iv_min = 0.02)

cat("\n=== Scorecard Model Summary (Coefficients) ===\n")
print(summary(base_fit$model))

# ------------------------------------------------------------------------------
# Validate on 2015 and Establish Production Approval Cut-off
# ------------------------------------------------------------------------------
APPROVE <- 0.70
valid_s <- score_with(base_fit, valid)

# Score cut-off: 30th percentile of scores yields top 70% approvals
cutoff <- quantile(valid_s$score, 1 - APPROVE)

# Discrimination metrics on 2015 validation set
r_val <- roc(valid_s$bad, valid_s$pd, quiet = TRUE, direction = "<")
val_auc <- as.numeric(auc(r_val))
val_gini <- 2 * val_auc - 1

# Two-sample Kolmogorov-Smirnov (KS) statistic
ks_stat <- max(abs(ecdf(valid_s$score[valid_s$bad == 0])(valid_s$score) - 
                   ecdf(valid_s$score[valid_s$bad == 1])(valid_s$score)))

cat("\n=== 2015 Validation Benchmark ===\n")
cat("Approval Rate Target:     ", sprintf("%.1f%%", APPROVE * 100), "\n")
cat("Approval Score Cut-off:   ", round(cutoff, 2), "points\n")
cat("Validation AUC:           ", round(val_auc, 4), "\n")
cat("Validation Gini:          ", round(val_gini, 4), "\n")
cat("Validation KS Statistic:  ", round(ks_stat, 4), "\n")

# ------------------------------------------------------------------------------
# Model Card Table Deliverable
# ------------------------------------------------------------------------------
model_card_vars <- tibble(
  Variable = names(base_fit$iv),
  Information_Value = round(as.numeric(base_fit$iv), 4),
  Predictive_Strength = case_when(
    Information_Value >= 0.30 ~ "Strong",
    Information_Value >= 0.10 ~ "Medium",
    Information_Value >= 0.02 ~ "Weak",
    TRUE ~ "Useless"
  )
) %>% arrange(desc(Information_Value))

cat("\n=== Model Card: Kept Predictors & Information Value (Build 2012-2014) ===\n")
print(as.data.frame(model_card_vars))

# Cache base model objects for subsequent stages
if (!dir.exists("data")) dir.create("data")
saveRDS(base_fit, "data/base_fit.rds")
saveRDS(cutoff, "data/cutoff.rds")
message("Saved 'data/base_fit.rds' and 'data/cutoff.rds'")
