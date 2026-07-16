# Climate data in infectious disease modelling (R Quarto)

Three sessions describing how one could use climate data in infectious disease
transmission modelling, with a case study of malaria in Thailand. An R Quarto port
of the existing Python analysis workflow, built on the SPARKLE `spectrum-spark`
template (same template as `course-advanced-id-modelling`).

## Status

**Initial R port: quantitatively verified against the Python, but everything still
needs checking.** The statistical pipeline reproduces the expert's Python notebook
(`python_workflow/malaria_workflow.ipynb`) to machine precision, checked
automatically (see Verification below); the mechanistic SEIRS reproduces the same
likelihood and predictions over the historical fit (its weakly-identified parameters
agree to a few percent), though its long-range forward projection diverges more between
R and Python as those small parameter differences are amplified (see Verification).
What still needs review: the content and andragogy (wording, questions, framing),
presenter details, and how much of the optional/advanced material to present. The
Python notebook remains the source of truth.

## Structure

- `index.qmd`: landing page.
- `session1_climate_primer/`, Session 1: links/embeds the climate science primer
  slides (`20260511_Kitsios_SPARKLE_EMCR-climate_science_primer.pdf`). No code.
- `session2_climate_data/session2_climate_data.qmd`, **Session 2, the main port**:
  opens by framing the **research question** (the first step of modelling), then
  obtaining + data-download instructions and the ideal-vs-achievable workflow
  framing (Part 1), malaria case data (Part 2), reanalysis climate (Part 3), CMIP6
  projections (Part 4), the statistical ARIMA/ARX ("panel method") fit linking
  climate to incidence (Part 5), pushing that fit forward under CMIP6 to project
  future cases (Part 6), and (behind an expandable box), an optional mechanistic
  SEIRS alternative ("Why an SEIRS model?"), which doubles as a worked code base for
  fitting a transmission model directly. Questions are scattered through each part at
  natural stopping points, each with a click-to-reveal answer, and a facilitator
  **90-minute run** plan at the top flags one core question per part. Part 6 and the
  SEIRS section each add a **model-consensus map** (where the CMIP6 models agree on the
  direction of change, following Sexton et al. 2026); the SEIRS section now also
  projects forward under CMIP6, mirroring the notebook.
- `session3_future_directions/`, Session 3: a code-free group discussion. Opens
  with "does the question even need climate data?" (weather vs climate; when not to
  project), then breakout-group project-planning prompts (starting from the research
  question, including the ideal-vs-achievable discussion), plus two reporting
  principles carried from Session 2 (prefer model agreement over a single ensemble
  number; climate is only one driver).
- `_extensions/`, `style_training.css`, `logo.png`: copied from the sparkle
  template.

The climate data and the Session 1 slides live in `data/` at the repository root,
shared separately and not tracked in git (see `.gitignore`). The session `.qmd`
files read it via the `data_dir <- "../data"` variable at the top of each file.

## Rendering

```sh
quarto render
```

Requires Quarto ≥ 1.7 and R with these packages:
`here`, `jsonlite`, `dplyr`, `tidyr`, `lubridate`, `ggplot2`, `patchwork`, `sf`,
`terra`, `ncdf4`, `tibble`. `execute: freeze: auto` caches results after the first
successful render.

## Verification against the Python source

The R port reproduces the Python notebook, checked automatically without duplicating
any analysis logic: each side saves its own real computed outputs and a small script
diffs them.

- The **notebook** writes `python_workflow/outputs/python_panel.json` (statistical
  fit) and `python_workflow/outputs/python_seirs.json` (fitted SEIRS).
- **Session 2** writes `outputs/r_panel.json` and `outputs/r_seirs.json`.
- **`python_workflow/compare.R`** loads both and reports the differences. It contains
  no analysis logic.

The Python reference is self-contained under `python_workflow/` (notebook,
`requirements.txt`, `setup.py`, `compare.R`, and its own `outputs/`), so a student
can ignore that folder entirely or dive in. The R course writes generated
figures/CSVs/JSON to the top-level `outputs/`. Both `outputs/` folders are git-ignored.

To run: execute the notebook once, render Session 2 once, then
`source("python_workflow/compare.R")` (or `Rscript python_workflow/compare.R`).

**Statistical pipeline: machine precision where it matters.** Province set (15) and
months identical, `cases_mat` bit-identical, `panel_beta` ~1e-10 (the fitted
statistical coefficient, renamed `B` in both R and Python so `β` is free for the SEIRS
transmission rate; the JSON key stays `panel_beta`, so `compare.R` is unchanged),
`arx_fit` ~2e-7. The area-weighted `clim` fields agree to
~3e-5 K (temperature) and ~1e-9 m (rainfall). The temperature residual is floating
point in the cos-latitude weights (terra's reconstructed cell centres vs the netCDF
coordinate); it sits ~30x below ERA5's own ~1e-3 K storage resolution and does not
touch any downstream result. `compare.R` still flags it against the strict 1e-6
tolerance (shown as **CHECK**) as an honest reminder that the two grids' weights
differ at the floating-point level.

**Mechanistic SEIRS: reproduces where it matters.** With both fits run to convergence
(`maxiter`/`maxit` = 200) the negative log-likelihood agrees to ~6e-3 and the fitted
case totals per province to ~0.3%; the climate sensitivities `b_temp`/`b_rain` to
~1–3%. The individual `beta0`/`scale` parameters differ by 1–3%, a symptom of the
model's weak identifiability, not a porting error (see the identifiability note in the
Session 2 SEIRS section). The integrator itself matches to ~1e-17 given identical
parameters.

`compare.R` checks the **historical fit** only (`r_seirs.json` / `python_seirs.json`),
not the forward projection. The R SEIRS forward projection (new, mirroring notebook
cells 61–65) diverges more visibly from Python's, for two reasons: the weakly-identified
parameters are amplified over the ~85-year nonlinear integration and the large
out-of-sample climate anomalies (`beta_t = beta0·exp(b_temp·z + b_rain·z)` is sensitive
to small `b` differences when `z` is large), and R excludes unstable models *per
scenario* whereas the notebook drops a model from *both* scenarios if it is unstable in
either. This is expected given the identifiability, not a porting bug.

Three things this verification surfaced and fixed: standardisation must use the
**population** SD (÷n) to match NumPy's `np.std` (a `popsd()` helper); the climate
extraction uses an **area-weighted** (cos-latitude) provincial mean (both the R and
the notebook were switched to this, on Vassili's advice, from the notebook's earlier
chained `.mean('lat').mean('lon')`); and the province selection keeps every province
with >12 months (the updated notebook no longer drops the last two).

## Notes for first render

1. **CMIP6 (Session 2, Part 4)** is the heaviest step (per-model `terra::resample`
   onto the reanalysis grid). Set `CMIP_MODEL_CAP=3` while iterating to cap the
   ensemble; unset for the full run. Precipitation is converted to a monthly total via
   `PR_FLUX_TO_M = 86400 * DAYS_PER_MONTH / 1000` (with `DAYS_PER_MONTH = 30`, defined
   once in Part 3 and reused in Part 4; set it to `1` for daily rates). The same change
   was mirrored in the notebook.
2. `execute: freeze: auto` caches results, so after the first successful render
   subsequent builds are fast. Editing a code chunk invalidates the cache and
   re-runs the document (including the heavy CMIP step).
3. Session 2 in full is a 3–4 hour hands-on session; a **90-minute run** plan
   (pre-rendered so there is no live compute wait, facilitator-driven, one core
   question per part) is in the speaker-note at the top of the document. Pre-render
   before the session so the `freeze` cache is warm.

## To do (course team)

- Review all content and andragogy (wording, questions, framing), and set presenter
  names in the `.qmd` front matter.
- Decide how much of the optional/advanced material to present: the Part 6
  statistical projection (drift caveat) and the SEIRS section (weakly identified,
  slower to fit in R).
- The **model-consensus maps** (Part 6 and the SEIRS section) are an R-side teaching
  extension not in the notebook; decide whether to add a matching cell to the notebook,
  and whether to align the SEIRS forward-projection's unstable-model exclusion to the
  notebook's (drop a model from both scenarios if unstable in either) or keep the
  divergence as part of the identifiability story.
- For a student-facing build, hide speaker notes by setting
  `.speaker-note { display: none; }` in `style_training.css` and re-rendering. Note the
  **90-minute run** plan and the per-question "core question" cues are themselves
  speaker-notes, so hiding them removes that facilitator guidance too.
