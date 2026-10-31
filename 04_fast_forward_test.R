# ==============================================================================
# The "Time Machine" Credit Model
# Stage 4: Fast-Forward Test (2015–2018 Frozen Model Evaluation)
# ==============================================================================

set.seed(42)

suppressPackageStartupMessages({
  library(tidyverse)
  library(scorecard)
  library(pROC)
  library(scales)
})

# Load required cached objects
if (!exists("base_fit")) base_fit <- readRDS("data/base_fit.rds")
if (!exists("cutoff")) cutoff <- readRDS("data/cutoff.rds")
if (!exists("df")) df <- readRDS("data/df_cleaned.rds")

# ------------------------------------------------------------------------------
# Unit Economic Assumptions
# ------------------------------------------------------------------------------
MARGIN <- 0.10  # Assumed cumulative return on funded loan amount for good loans
LGD    <- 0.60  # Assumed loss given default fraction on unpaid bad balances

# Break-even default rate
p_star <- MARGIN / (MARGIN + LGD)
cat("Break-Even Default Rate (p*):", sprintf("%.2f%%\n", p_star * 100))

# ------------------------------------------------------------------------------
# Score Future Longitudinal Cohorts (2015 to 2018)
# ------------------------------------------------------------------------------
test <- df %>% filter(issue_year >= 2015)

# Score using frozen 2012-2014 scorecard
scored <- score_with(base_fit, test)

# ------------------------------------------------------------------------------
# Longitudinal Evaluation Function
# ------------------------------------------------------------------------------
evaluate <- function(d, cut) {
  d %>%
    mutate(approved = score >= cut) %>%
    group_by(issue_year) %>%
    summarise(
      loans = n(),
      bad_rate = mean(bad),
      mean_pd = mean(pd),
      # Calibration Gap: +ve = model too pessimistic; -ve = model too optimistic
      calib_gap = mean_pd / bad_rate - 1,
      # Discrimination: Gini = 2 * AUC - 1
      gini = 2 * as.numeric(auc(roc(bad, pd, quiet = TRUE, direction = "<"))) - 1,
      approval_rate = mean(approved),
      bad_rate_approved = mean(bad[approved]),
      # Economic outcome per applicant across entire applicant pool
      profit_per_applicant = sum(
        ifelse(approved, ifelse(bad == 1, -LGD, MARGIN) * loan_amnt, 0)
      ) / n(),
      .groups = "drop"
    )
}

perf <- evaluate(scored, cutoff)

cat("\n=== Frozen Model Longitudinal Performance (2015-2018) ===\n")
print(as.data.frame(perf))

# ------------------------------------------------------------------------------
# Diagnostic Chart: Gini Decay by Year
# ------------------------------------------------------------------------------
p_gini <- ggplot(perf, aes(x = factor(issue_year), y = gini, group = 1)) +
  geom_line(color = "#2b5c8f", linewidth = 1.3) +
  geom_point(color = "#2b5c8f", size = 4) +
  geom_text(aes(label = sprintf("%.3f", gini)), vjust = -1, size = 3.8, fontface = "bold") +
  scale_y_continuous(limits = c(min(0.25, min(perf$gini) - 0.05), max(0.50, max(perf$gini) + 0.05))) +
  labs(
    title = "Frozen Scorecard Discrimination Over Time (Gini Index)",
    subtitle = "Tracking borrower rank-ordering power on future out-of-time vintages without retraining",
    x = "Origination Year",
    y = "Gini Coefficient (2 x AUC - 1)"
  ) +
  theme_minimal(base_size = 12) +
  theme(plot.title = element_text(face = "bold"), panel.grid.minor = element_blank())

ggsave("charts/06_gini_by_year.png", p_gini, width = 8, height = 5, dpi = 300)
message("Saved 'charts/06_gini_by_year.png'")

# ------------------------------------------------------------------------------
# Diagnostic Chart: Calibration Gap by Year
# ------------------------------------------------------------------------------
p_calib <- ggplot(perf, aes(x = factor(issue_year), y = calib_gap, fill = calib_gap > 0)) +
  geom_col(width = 0.6) +
  geom_hline(yintercept = 0, linetype = "dashed", color = "gray30") +
  geom_hline(yintercept = c(-0.25, 0.25), linetype = "dotted", color = "red") +
  geom_text(aes(label = percent(calib_gap, accuracy = 0.1)), 
            vjust = ifelse(perf$calib_gap >= 0, -0.4, 1.2), size = 3.8, fontface = "bold") +
  scale_fill_manual(values = c("TRUE" = "#e6550d", "FALSE" = "#3182bd"), guide = "none") +
  scale_y_continuous(labels = percent_format(accuracy = 1)) +
  labs(
    title = "Model Calibration Gap by Origination Vintage",
    subtitle = "Calib Gap = (Mean Predicted PD / Realized Bad Rate) - 1. Thresholds: +/- 25% alert",
    x = "Origination Year",
    y = "Calibration Gap (%)"
  ) +
  theme_minimal(base_size = 12) +
  theme(plot.title = element_text(face = "bold"))

ggsave("charts/07_calibration_gap_by_year.png", p_calib, width = 8, height = 5, dpi = 300)
message("Saved 'charts/07_calibration_gap_by_year.png'")

# Cache evaluation objects
saveRDS(scored, "data/scored.rds")
saveRDS(perf, "data/perf.rds")
message("Stage 4 Fast-forward evaluation complete.")
