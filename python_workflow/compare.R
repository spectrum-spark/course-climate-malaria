# Compare the saved Python and R panel outputs directly.
#
# This script contains NO analysis logic. It only loads the two artefacts that
# each side writes when it runs its own real code, and reports the differences:
#
#   * python_workflow/outputs/python_panel.json  -- written by malaria_workflow.ipynb
#   * outputs/r_panel.json                        -- written by session2_climate_data.qmd
#
# So run the notebook once and render Session 2 once, then:
#   source("python_workflow/compare.R")            # inside R / RStudio
#   # or:  Rscript python_workflow/compare.R
#
# Requires: jsonlite.

suppressPackageStartupMessages(library(jsonlite))

# find this script's own directory (works via Rscript, source(), or RStudio)
get_script_dir <- function() {
  ca <- commandArgs(FALSE); m <- grep("^--file=", ca)
  if (length(m)) return(dirname(normalizePath(sub("^--file=", "", ca[m[1]]))))
  for (i in rev(seq_len(sys.nframe()))) {
    of <- sys.frame(i)$ofile
    if (!is.null(of)) return(dirname(normalizePath(of)))
  }
  if (requireNamespace("rstudioapi", quietly = TRUE) && rstudioapi::isAvailable()) {
    p <- tryCatch(rstudioapi::getSourceEditorContext()$path, error = function(e) "")
    if (nzchar(p)) return(dirname(normalizePath(p)))
  }
  getwd()
}
here <- get_script_dir()                          # python_workflow/
py_path <- file.path(here, "outputs", "python_panel.json")          # python_workflow/outputs/
r_path  <- file.path(dirname(here), "outputs", "r_panel.json")      # repo-root outputs/

need <- function(path, hint) {
  if (!file.exists(path))
    stop(basename(path), " not found at ", path, "\n  ", hint, call. = FALSE)
  fromJSON(path)
}
py <- need(py_path, "run python_workflow/malaria_workflow.ipynb")
r  <- need(r_path,  "render session2_climate_data/session2_climate_data.qmd")

# align R rows/cols to the Python order (by province name and by month value)
oi <- match(py$selected, r$selected)
oj <- match(py$months,   r$months)
if (anyNA(oi)) stop("province sets differ: ",
                    paste(setdiff(py$selected, r$selected), collapse = ", "))
if (anyNA(oj)) stop("month sets differ.")
al <- function(m) m[oi, oj, drop = FALSE]

md  <- function(a, b) max(abs(a - b))
tol <- 1e-6
chk <- function(name, d, unit = "")
  cat(sprintf("  %-11s max|R - Py| = %.3e %s   %s\n", name, d, unit,
              if (d < tol) "PASS" else "**CHECK**"))

cat("\nDirect comparison of saved outputs: R (Quarto) vs Python (notebook)\n")
cat(sprintf("  provinces    %d, identical set: %s\n",
            length(py$selected), identical(sort(py$selected), sort(r$selected))))
chk("cases_mat",  md(al(r$cases_mat),  py$cases_mat))
# clim_temp trips the 1e-6 tolerance at ~3e-5 K: floating point in the cos-latitude
# area weights (terra's reconstructed cell centres vs the netCDF coordinate). It is
# ~30x below ERA5's own ~1e-3 K storage resolution, so the CHECK is informational, not
# a sign of a real discrepancy.
chk("clim_temp",  md(al(r$clim_temp),  py$clim_temp), "(K)")
chk("clim_rain",  md(al(r$clim_rain),  py$clim_rain), "(m)")
chk("panel_beta", md(r$panel_beta,     py$panel_beta))
chk("arx_fit",    md(al(r$arx_fit),    py$arx_fit))
cat(sprintf("\n  R beta : %s\n  Py beta: %s\n",
            paste(sprintf("%.8f", r$panel_beta),  collapse = ", "),
            paste(sprintf("%.8f", py$panel_beta), collapse = ", ")))

# ---- optional: fitted SEIRS comparison --------------------------------------
# The SEIRS *integrator* is deterministic (matches exactly given the same params),
# but the fitted parameters come from an optimiser: SciPy L-BFGS-B vs R optim's
# L-BFGS-B. With a matched gradient step they track closely, but at the notebook's
# capped iteration count they are not fully converged, so expect CLOSE, not exact.
sp <- file.path(here, "outputs", "python_seirs.json")            # python_workflow/outputs
sr <- file.path(dirname(here), "outputs", "r_seirs.json")        # repo-root outputs
if (file.exists(sp) && file.exists(sr)) {
  pys <- fromJSON(sp); rs <- fromJSON(sr)
  cat("\nFitted SEIRS (optimiser-dependent, expect close, not bit-identical):\n")
  for (nm in c("nll", "sigma", "gamma", "omega", "b_temp", "b_rain")) {
    d <- abs(pys[[nm]] - rs[[nm]]); rel <- d / max(abs(pys[[nm]]), 1e-12)
    cat(sprintf("  %-7s Py=% .6g  R=% .6g  |diff|=%.3e (%.2f%%)\n",
                nm, pys[[nm]], rs[[nm]], d, 100 * rel))
  }
  oi <- match(pys$selected, rs$selected)
  oj <- match(pys$months,   rs$months)
  relmax <- function(a, b) 100 * max(abs(a - b) / pmax(abs(a), 1e-12))
  cat(sprintf("  %-7s max|R - Py| = %.3e  (%.2f%%)  weakly identified (trades off with scale)\n",
              "beta0", max(abs(pys$beta0 - rs$beta0[oi])), relmax(pys$beta0, rs$beta0[oi])))
  cat(sprintf("  %-7s max|R - Py| = %.3e  (%.2f%%)  population x reporting rate\n",
              "scale", max(abs(pys$scale - rs$scale[oi])), relmax(pys$scale, rs$scale[oi])))
  as_m <- function(x, nr) if (is.matrix(x)) x else matrix(unlist(x), nrow = nr, byrow = TRUE)
  lam_r <- as_m(rs$lam_fit,  length(rs$selected))[oi, oj, drop = FALSE]
  lam_p <- as_m(pys$lam_fit, length(pys$selected))
  cat(sprintf("  %-7s max|R - Py| = %.3f cases;  per-province total agrees to %.2f%%\n",
              "lam_fit", max(abs(lam_r - lam_p)), relmax(rowSums(lam_p), rowSums(lam_r))))
} else {
  cat("\n(SEIRS outputs not found: run the notebook's SEIRS cells and render",
      "Session 2's SEIRS block to include the fitted-SEIRS comparison.)\n")
}
