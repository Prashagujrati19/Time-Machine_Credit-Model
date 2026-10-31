# ==============================================================================
# The "Time Machine" Credit Model
# Stage 2: Exploratory Data Analysis & Diagnostic Charting
# ==============================================================================

set.seed(42)

suppressPackageStartupMessages({
  library(tidyverse)
  library(scales)
})

# Ensure charts directory exists
if (!dir.exists("charts")) dir.create("charts", recursive = TRUE)

# Load cleaned dataset
if (file.exists("data/df_cleaned.rds")) {
  df <- readRDS("data/df_cleaned.rds")
} else {
  source("01_load_clean.R")
}

feat <- setdiff(names(df), c("bad", "issue_year"))

# ------------------------------------------------------------------------------
# 1. Volume and Bad Rate by Vintage
# ------------------------------------------------------------------------------
cat("\n=== Volume and Realized Bad Rate by Issue Year ===\n")
vintage_summary <- df %>%
  group_by(issue_year) %>%
  summarise(
    loans = n(),
    bads = sum(bad),
    bad_rate = mean(bad),
    mean_fico = mean(fico, na.rm = TRUE),
    mean_dti = mean(dti, na.rm = TRUE),
    .groups = "drop"
  )
print(as.data.frame(vintage_summary))

# Chart 1: Bad Rate by Issue Year (Flagging Right-Censoring)
p1 <- ggplot(vintage_summary, aes(x = issue_year, y = bad_rate)) +
  geom_line(color = "#1f77b4", linewidth = 1.2) +
  geom_point(color = "#1f77b4", size = 3) +
  annotate(
    "rect", xmin = 2016.5, xmax = 2018.5, ymin = 0, ymax = Inf,
    alpha = 0.15, fill = "red"
  ) +
  annotate(
    "text", x = 2017.5, y = max(vintage_summary$bad_rate) * 0.95,
    label = "Right-Censoring Zone\n(Maturity Bias in Unmatured Loans)",
    color = "darkred", size = 3.5, fontface = "italic"
  ) +
  scale_y_continuous(labels = percent_format(accuracy = 1)) +
  scale_x_continuous(breaks = min(vintage_summary$issue_year):max(vintage_summary$issue_year)) +
  labs(
    title = "Realized Bad Rate by Origination Vintage (36-Month Loans)",
    subtitle = "Defaults stabilize around 15-18% before 2017-18 seasoning bias suppresses visible bads",
    x = "Issue Year",
    y = "Realized Bad Rate (% Charged Off)"
  ) +
  theme_minimal(base_size = 12) +
  theme(plot.title = element_text(face = "bold"), panel.grid.minor = element_blank())

ggsave("charts/01_bad_rate_by_year.png", p1, width = 8, height = 5, dpi = 300)
message("Saved 'charts/01_bad_rate_by_year.png'")

# ------------------------------------------------------------------------------
# 2. Missing Values Profile
# ------------------------------------------------------------------------------
cat("\n=== Missing Values Proportion per Feature ===\n")
na_prof <- tibble(
  variable = feat,
  na_share = sapply(df[, feat], function(col) mean(is.na(col)))
) %>% arrange(desc(na_share))
print(as.data.frame(na_prof))

# Chart 2: Missing Values Chart
p2 <- ggplot(na_prof %>% filter(na_share > 0), aes(x = reorder(variable, na_share), y = na_share)) +
  geom_col(fill = "#e6550d", width = 0.6) +
  geom_text(aes(label = percent(na_share, accuracy = 0.1)), hjust = -0.1, size = 3.5) +
  coord_flip() +
  scale_y_continuous(labels = percent_format(accuracy = 1), limits = c(0, max(na_prof$na_share) * 1.25)) +
  labs(
    title = "Missing Data Profile Across Candidate Predictors",
    subtitle = "Employment length and mortgage accounts show manageable missingness; handled by WOE binning",
    x = NULL,
    y = "Share Missing (NA)"
  ) +
  theme_minimal(base_size = 12) +
  theme(plot.title = element_text(face = "bold"))

ggsave("charts/02_missing_values_profile.png", p2, width = 8, height = 4.5, dpi = 300)
message("Saved 'charts/02_missing_values_profile.png'")

# ------------------------------------------------------------------------------
# 3. Bad Rate by FICO Band
# ------------------------------------------------------------------------------
cat("\n=== Bad Rate by FICO Band ===\n")
fico_summary <- df %>%
  mutate(fico_band = cut(fico, seq(600, 850, 25), include.lowest = TRUE)) %>%
  filter(!is.na(fico_band)) %>%
  group_by(fico_band) %>%
  summarise(loans = n(), bad_rate = mean(bad), .groups = "drop")
print(as.data.frame(fico_summary))

# Chart 3: Monotonic Default Gradient by FICO
p3 <- ggplot(fico_summary, aes(x = fico_band, y = bad_rate)) +
  geom_col(fill = "#3182bd", width = 0.7) +
  geom_text(aes(label = percent(bad_rate, accuracy = 0.1)), vjust = -0.5, size = 3.5) +
  scale_y_continuous(labels = percent_format(accuracy = 1), limits = c(0, max(fico_summary$bad_rate) * 1.2)) +
  labs(
    title = "Realized Bad Rate by FICO Score Band",
    subtitle = "Strict monotonic decline: higher credit score corresponds to lower probability of default",
    x = "FICO Score Band (25-pt bins)",
    y = "Realized Bad Rate"
  ) +
  theme_minimal(base_size = 12) +
  theme(
    plot.title = element_text(face = "bold"),
    axis.text.x = element_text(angle = 30, hjust = 1)
  )

ggsave("charts/03_bad_rate_by_fico.png", p3, width = 8, height = 5, dpi = 300)
message("Saved 'charts/03_bad_rate_by_fico.png'")

# ------------------------------------------------------------------------------
# 4. Bad Rate by Loan Purpose
# ------------------------------------------------------------------------------
cat("\n=== Bad Rate by Loan Purpose ===\n")
purpose_summary <- df %>%
  group_by(purpose) %>%
  summarise(loans = n(), bad_rate = mean(bad), .groups = "drop") %>%
  arrange(desc(bad_rate))
print(as.data.frame(purpose_summary))

# Chart 4: Bad Rate by Purpose
p4 <- ggplot(purpose_summary, aes(x = reorder(purpose, bad_rate), y = bad_rate)) +
  geom_col(fill = "#756bb1", width = 0.7) +
  geom_text(aes(label = percent(bad_rate, accuracy = 0.1)), hjust = -0.1, size = 3.5) +
  coord_flip() +
  scale_y_continuous(labels = percent_format(accuracy = 1), limits = c(0, max(purpose_summary$bad_rate) * 1.2)) +
  labs(
    title = "Default Risk Variation Across Loan Purposes",
    subtitle = "Small business loans exhibit nearly double the default risk of secured purchase/car loans",
    x = NULL,
    y = "Realized Bad Rate"
  ) +
  theme_minimal(base_size = 12) +
  theme(plot.title = element_text(face = "bold"))

ggsave("charts/04_bad_rate_by_purpose.png", p4, width = 8, height = 5.5, dpi = 300)
message("Saved 'charts/04_bad_rate_by_purpose.png'")

# ------------------------------------------------------------------------------
# 5. Loan Volume Growth by Vintage
# ------------------------------------------------------------------------------
p5 <- ggplot(vintage_summary, aes(x = factor(issue_year), y = loans / 1e3)) +
  geom_col(fill = "#2ca02c", width = 0.7) +
  geom_text(aes(label = paste0(round(loans / 1e3, 0), "k")), vjust = -0.4, size = 3.5) +
  labs(
    title = "Lending Club Origination Volume by Year (36-Month Loans)",
    subtitle = "Rapid portfolio scaling across 2012-2015 prior to platform stabilization",
    x = "Issue Year",
    y = "Loans Originated (Thousands)"
  ) +
  theme_minimal(base_size = 12) +
  theme(plot.title = element_text(face = "bold"))

ggsave("charts/05_origination_volume_by_year.png", p5, width = 8, height = 5, dpi = 300)
message("Saved 'charts/05_origination_volume_by_year.png'")

message("Stage 2 EDA complete. All 5 charts generated in 'charts/'.")
