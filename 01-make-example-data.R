# 01-make-example-data.R
#
# Creates the synthetic plaintext dataset used by this example.
#
# In a real project this step does not exist: the plaintext dataset comes from
# the data provider (e.g. NHS) and is only ever held on an approved
# encryption-at-rest solution such as an encrypted hard drive. Here we generate
# a fake dataset so that the example is fully reproducible and no real data is
# involved.
#
# Output: data/example.dta  (Stata format, read with haven::read_dta)
#
# Run inside the container, so that no R installation is needed on the host:
#
#   docker run --rm --user "$(id -u):$(id -g)" -v "$PWD":/work \
#       gocryptfs-example Rscript /work/01-make-example-data.R
#
# --user keeps the generated file owned by you rather than by root.

set.seed(20260304)

n <- 500

dat <- data.frame(
  patid     = sprintf("P%05d", seq_len(n)),
  age       = round(rnorm(n, mean = 62, sd = 11)),
  sex       = factor(sample(c("Female", "Male"), n, replace = TRUE)),
  sbp       = round(rnorm(n, mean = 138, sd = 18)),
  treated   = rbinom(n, 1, 0.5),
  stringsAsFactors = FALSE
)

# Outcome depends on treatment, age and blood pressure
lp <- -1 + 0.04 * (dat$age - 62) + 0.02 * (dat$sbp - 138) - 0.7 * dat$treated
dat$event <- rbinom(n, 1, plogis(lp))

dir.create("data", showWarnings = FALSE)
haven::write_dta(dat, "data/example.dta")

cat("Wrote data/example.dta:", nrow(dat), "rows,", ncol(dat), "columns\n")
