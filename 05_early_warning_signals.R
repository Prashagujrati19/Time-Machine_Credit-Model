# ==============================================================================
# The "Time Machine" Credit Model
# Stage 5: Early-Warning Surveillance Framework (PSI & CSI Monitoring)
# ==============================================================================

set.seed(42)

suppressPackageStartupMessages({
  library(tidyverse)
  library(scorecard)
  library(scales)
})

# Load cached data and models
if (!exists("base_fit")) base_fit <- readRDS("data/base_fit.rds")
if (!exists("df")) df <- readRDS("data/df_cleaned.rds")
if (!exists("perf")) perf <- readRDS("data/perf.rds")
if (!exists("scored")) scored <- readRDS("data/scored.rds")

build <- df %>% filter(issue_year %in% 2012:2014)

# ------------------------------------------------------------------------------
# 1. Population Stability Index (PSI) on Credit Scores
# ------------------------------------------------------------------------------
message("Scoring build cohort for baseline score distribution...")
build_s <- score_with(base_fit, build)

# Create 10 decile bins from baseline build set
brk <- unique(quantile(build_s$score, seq(0, 1, 0.1)))
brk[1] <- -Inf
brk[length(brk)] <- Inf

# PSI Calculation Function with smoothing to prevent log(0) or division by zero
psi_calc <- function(expected, actual, breaks) {
  pe <- prop.table(table(cut(expected, breaks)))
  pa <- prop.table(table(cut(actual, breaks)))
  sum((pa - pe) * log((pa + 1e-6) / (pe + 1e-6)))
}

psi_tbl <- scored %>%
  group_by(issue_year) %>%
  summarise(
    psi = psi_calc(build_s$score, score, brk),
    psi_status = case_when(
      psi < 0.10 ~ "Green (Stable)",
      psi <= 0.25 ~ "Yellow (Moderate Shift)",
      TRUE ~ "Red (Significant Drift)"
    ),
    .groups = "drop"
  )

cat("\n=== Population Stability Index (PSI) by Vintage ===\n")
print(as.data.frame(psi_tbl))

# ------------------------------------------------------------------------------
# 2. Characteristic Stability Index (CSI) on Individual Feature Bins
# ------------------------------------------------------------------------------
message("Evaluating Characteristic Stability Index (CSI) across candidate variables...")

bin_of <- function(d) {
  woebin_ply(as.data.frame(d[, base_fit$kept]), base_fit$bins, to = "bin", print_step = 0)
}

build_bin <- bin_of(build)
test_bin  <- bin_of(scored)
bin_cols  <- names(build_bin)[grepl("_bin$", names(build_bin))]

csi_one <- function(e, a) {
  lv <- union(unique(e), unique(a))
  pe <- prop.table(table(factor(e, levels = lv)))
  pa <- prop.table(table(factor(a, levels = lv)))
  sum((pa - pe) * log((pa + 1e-6) / (pe + 1e-6)))
}

csi_tbl <- expand_grid(year = sort(unique(scored$issue_year)), var = bin_cols) %>%
  mutate(
    clean_var = gsub("_bin$", "", var),
    csi = map2_dbl(
      year, var,
      ~ csi_one(build_bin[[.y]], test_bin[[.y]][scored$issue_year == .x])
    )
  )

# CSI Heatmap Chart
p_csi <- ggplot(csi_tbl, aes(x = factor(year), y = clean_var, fill = csi)) +
  geom_tile(color = "white", linewidth = 0.5) +
  geom_text(aes(label = sprintf("%.3f", csi)), size = 3.5, color = ifelse(csi_tbl$csi > 0.15, "white", "black")) +
  scale_fill_gradient2(
    low = "#f7fbff", mid = "#fd8d3c", high = "#b30000",
    midpoint = 0.15, limits = c(0, max(0.25, max(csi_tbl$csi)))
  ) +
  labs(
    title = "Characteristic Stability Index (CSI) Heatmap",
    subtitle = "Tracking covariate drift across applicant predictors against the 2012-14 baseline",
    x = "Origination Year",
    y = "Scorecard Predictor",
    fill = "CSI Value"
  ) +
  theme_minimal(base_size = 12) +
  theme(plot.title = element_text(face = "bold"), panel.grid = element_blank())

ggsave("charts/08_csi_heatmap.png", p_csi, width = 8.5, height = 6, dpi = 300)
message("Saved 'charts/08_csi_heatmap.png'")

# ------------------------------------------------------------------------------
# 3. Surveillance Alert Rule & Lead Time Quantification
# ------------------------------------------------------------------------------
alerts <- perf %>%
  left_join(psi_tbl, by = "issue_year") %>%
  mutate(
    gini_drop = gini[issue_year == 2015] - gini,
    alert = (psi > 0.25) | (abs(calib_gap) > 0.25),
    decayed = gini_drop > 0.05
  )

cat("\n=== Early-Warning Surveillance Alert Log ===\n")
print(as.data.frame(alerts %>% select(issue_year, gini, gini_drop, calib_gap, psi, alert, decayed)))

first_alert_yr <- min(alerts$issue_year[alerts$alert], na.rm = TRUE)
first_decay_yr <- if (any(alerts$decayed)) min(alerts$issue_year[alerts$decayed]) else NA

cat("\n--- Lead Time Analysis ---\n")
if (!is.na(first_decay_yr)) {
  cat(sprintf("Alert fired in %d. Gini decay confirmed in %d. Surveillance Lead Time = %d year(s).\n",
              first_alert_yr, first_decay_yr, first_decay_yr - first_alert_yr))
} else {
  cat(sprintf("Alert triggered in %d via calibration/PSI drift while Gini ranking power remained durable.\n",
              first_alert_yr))
}

# Cache alert objects
saveRDS(psi_tbl, "data/psi_tbl.rds")
saveRDS(csi_tbl, "data/csi_tbl.rds")
saveRDS(alerts, "data/alerts.rds")
message("Stage 5 Early-warning surveillance complete.")
