# analysis.R
#
# The analysis step. It reads the dataset from the gocryptfs FUSE mount, so the
# data is decrypted block-by-block in memory as the file is read. No plaintext
# copy is ever written to disk.
#
# Usage:  Rscript analysis.R <path to dataset> [output directory]
#
# Only non-disclosive aggregate results are written to the output directory.

args <- commandArgs(trailingOnly = TRUE)

dataset <- if (length(args) >= 1) args[1] else "plain/example.dta"
outdir  <- if (length(args) >= 2) args[2] else "results"

library(haven)

cat("Reading", dataset, "via the gocryptfs mount\n\n")
dat <- read_dta(dataset)

cat("Rows:", nrow(dat), " Columns:", ncol(dat), "\n\n")

# --- Aggregate summaries (non-disclosive) ------------------------------------

summary_tab <- data.frame(
  n           = nrow(dat),
  mean_age    = round(mean(dat$age), 1),
  sd_age      = round(sd(dat$age), 1),
  mean_sbp    = round(mean(dat$sbp), 1),
  pct_treated = round(100 * mean(dat$treated), 1),
  pct_event   = round(100 * mean(dat$event), 1)
)

cat("Summary statistics\n")
print(summary_tab, row.names = FALSE)
cat("\n")

# --- Model -------------------------------------------------------------------

fit <- glm(event ~ treated + age + sbp, family = binomial, data = dat)

cat("Logistic regression: event ~ treated + age + sbp\n")
print(round(summary(fit)$coefficients, 4))
cat("\n")

# --- Write results out -------------------------------------------------------
#
# Results go to a normal (unencrypted) directory because they are aggregate and
# non-disclosive. Anything still containing record-level data must be written
# back inside the mount so that it is encrypted.

dir.create(outdir, showWarnings = FALSE, recursive = TRUE)
write.csv(summary_tab, file.path(outdir, "summary.csv"), row.names = FALSE)
write.csv(round(summary(fit)$coefficients, 4),
          file.path(outdir, "model-coefficients.csv"))

cat("Results written to", outdir, "\n")
