# Climate data in infectious disease modelling (R Quarto)

Three sessions describing how one could use climate data in infectious  disease transmission modelling, with a case study of malaria in Thailand. An R Quarto port of the existing Python analysis workflow, built on the SPARKLE `spectrum-spark` template.

## Quick start

1. **Install** Quarto (≥ 1.7) and R, then the R packages:
   ```r
   install.packages(c("here", "jsonlite", "dplyr", "tidyr", "lubridate",
                      "ggplot2", "patchwork", "sf", "terra", "ncdf4", "tibble"))
   ```
2. **Add the data.** The climate and malaria data (reanalysis, CMIP6, boundaries, cases)
   are shared separately and not tracked in git; put the `data/` folder at the repository
   root. Session 2, Part 1 lists the original sources.
3. **Render:** `quarto render`. The first build is slow (the CMIP6 regridding in Session
   2, Part 4); `execute: freeze: auto` then caches results so later builds are fast. To
   iterate quicker, cap the ensemble with `CMIP_MODEL_CAP=3`.
4. **View:** open `_site/index.html`.
5. **(Optional) verify against the Python:** run `python_workflow/malaria_workflow.ipynb`,
   then `Rscript python_workflow/compare.R`.

## Structure

- `index.qmd`: landing page.
- `session1_climate_primer/`, Session 1: links/embeds the climate science primer slides (`202607123_Kitsios_SPARKLE_climate_science_primer.pdf`. No code.
- `session2_climate_data/session2_climate_data.qmd`, **Session 2, the main port**: opens by framing the **research question** (the first step of modelling), the obtaining + data-download instructions and the ideal-vs-achievable workflow framing (Part 1), malaria case data (Part 2), reanalysis climate (Part 3), CMIP6 projections (Part 4), the statistical ARIMA/ARX ("panel method") fit linking climate to incidence (Part 5), pushing that fit forward under CMIP6 to project future cases (Part 6), and (behind an expandable box), an optional mechanistic SEIRS alternative ("Why an SEIRS model?"), which doubles as a worked code base for fitting a transmission model directly. Questions are scattered through each part to help guide learning, each with a click-to-reveal answer, and a facilitator **90-minute run** plan at the top flags one core question per part. Part 6 and the SEIRS section each add a **model-consensus map** (where the CMIP6 models agree on the direction of change); the SEIRS section also projects forward under CMIP6, continuing from the fitted end-of-history state (the same way the Part 6 ARX projection continues from the last observed month), and reports a per-province parameter table. 
- `session3_future_directions/`, Session 3: a code-free group discussion. Opens with "does the question even need climate data?" (weather vs climate; when not to project), then breakout-group project-planning prompts (starting from the research question, including the ideal-vs-achievable discussion), plus two reporting principles carried from Session 2 (prefer model agreement over a single ensemble number; climate is only one driver).
- `_extensions/`, `style_training.css`, `logo.png`: copied from the sparkle template.

The climate data lives in `data/` at the repository root, shared separately and not tracked in git (see `.gitignore`); the session `.qmd` files read it via the `data_dir <- "../data"` variable at the top of each file. The Session 1 slides live in the Session 1 folder itself.

## Rendering

```sh
quarto render
```

Requires Quarto ≥ 1.7 and R with these packages: `here`, `jsonlite`, `dplyr`, `tidyr`, `lubridate`, `ggplot2`, `patchwork`, `sf`, `terra`, `ncdf4`, `tibble`. `execute: freeze: auto` caches results after the first successful render.

## Verification against the Python source

The R port reproduces the Python notebook, checked using `compare.R`.

- The **notebook** writes `python_workflow/outputs/python_panel.json` (statistical fit) and `python_workflow/outputs/python_seirs.json` (fitted SEIRS).
- **Session 2** writes `outputs/r_panel.json` and `outputs/r_seirs.json`.
- **`python_workflow/compare.R`** loads both and reports the differences. It contains no analysis logic.

The Python reference is self-contained under `python_workflow/` (notebook, `requirements.txt`, `setup.py`, `compare.R`, and its own `outputs/`), so one can ignore that folder entirely or dive in. The R course writes generated figures/CSVs/JSON to the top-level `outputs/`. Both `outputs/` folders are git-ignored.

To run: execute the notebook once, render Session 2 once, then `source("python_workflow/compare.R")` (or `Rscript python_workflow/compare.R`).

**Statistical pipeline: machine precision where it matters.** Province set (15) and months identical, `cases_mat` bit-identical, `panel_beta` ~1e-10 (the fitted statistical coefficient, renamed `B` in both R and Python so `β` is free for the SEIRS transmission rate; the JSON key stays `panel_beta`, so `compare.R` is unchanged), `arx_fit` ~2e-7. The area-weighted `clim` fields agree to ~3e-5 K (temperature) and ~1e-9 m (rainfall). The temperature residual is floating point in the cos-latitude weights (terra's reconstructed cell centres vs the netCDF coordinate); it sits ~30x below ERA5's own ~1e-3 K storage resolution and does not touch any downstream result. `compare.R` still flags it against the strict 1e-6 tolerance (shown as **CHECK**) as an honest reminder that the two grids' weights differ at the floating-point level.

**Mechanistic SEIRS: reproduces where it matters.** Both fits run at `maxit`/`maxiter`= 200 with a relaxed convergence tolerance (`factr` in R, the matching `ftol` in Python), because the `beta0`/`scale` ridge is flat and the default tight tolerance never triggers on it. The negative log-likelihood agrees to ~0%, and the climate sensitivities `b_temp`/`b_rain` and natural-history rates (`sigma`/`gamma`/`omega`) to a few percent.
The level parameters `beta0`/`scale`, and the per-province fitted case totals, differ more (order 10%), a symptom of the model's weak identifiability (see the identifiability note in the Session 2 SEIRS section). The integrator itself matches to ~1e-17 given identical parameters. The diagnostic transmission rate is clipped exactly like the likelihood, so the fitted `lam_fit` cannot overflow to `NaN`.

`compare.R` checks the **historical fit** only (`r_seirs.json` / `python_seirs.json`), not the forward projection. Both the R and the notebook projections *continue from the fitted end-of-history disease state* and run the future months only (the same way the Part 6 ARX projection continues from the last observed month), partial first/last calendar years are dropped before annual aggregation, and both sides drop a model from both scenarios if it is unstable in either. Residual R-vs-Python differences in the projection come from the weakly-identified fit parameters amplified over the long nonlinear integration. 

## Notes for first render

1. **CMIP6 (Session 2, Part 4)** is the heaviest step (per-model `terra::resample` onto the reanalysis grid). Set `CMIP_MODEL_CAP=3` while iterating to cap the ensemble; unset for the full run. Precipitation is converted to a monthly total via `PR_FLUX_TO_M = 86400 * DAYS_PER_MONTH / 1000` (with `DAYS_PER_MONTH = 30`, defined once in Part 3 and reused in Part 4; set it to `1` for daily rates). 
2. `execute: freeze: auto` caches results, so after the first successful render subsequent builds are fast. Editing a code chunk invalidates the cache and re-runs the document (including the heavy CMIP step).
3. Session 2 in full is probably a 3–4 hour hands-on session; a **90-minute run** plan is in the speaker-note at the top of the document. Pre-render before the session so the `freeze` cache is warm.

