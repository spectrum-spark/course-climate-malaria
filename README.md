# Climate data in infectious disease modelling (R Quarto)

Three sessions describing how one could use climate data in infectious disease
transmission modelling, with a case study of malaria in Thailand. An R Quarto port
of the existing Python analysis workflow, built on the SPARKLE `spectrum-spark`
template (same template as `course-advanced-id-modelling`).

## Status

**Initial R port — quantitatively verified against the Python, but everything still
needs checking.** The statistical pipeline reproduces the expert's Python notebook
(`python_workflow/malaria_workflow.ipynb`) to machine precision, checked
automatically (see Verification below); the mechanistic SEIRS reproduces the same
likelihood and predictions (its weakly-identified parameters agree to a few percent).
What still needs review: the content and pedagogy (wording, questions, framing),
presenter details, the flagged question for Vassili about the spatial-averaging
choice, and how much of the optional/advanced material to present. The Python
notebook remains the source of truth.

## Structure

- `index.qmd` — landing page.
- `session1_climate_primer/` — Session 1: links/embeds the climate science primer
  slides (`20260511_Kitsios_SPARKLE_EMCR-climate_science_primer.pdf`). No code.
- `session2_climate_data/session2_climate_data.qmd` — **Session 2, the main port**:
  opens by framing the **research question** (the first step of modelling), then
  obtaining + data-download instructions and the ideal-vs-achievable workflow
  framing (Part 1), malaria case data (Part 2), reanalysis climate (Part 3), CMIP6
  projections (Part 4), the statistical ARIMA/ARX ("panel method") fit linking
  climate to incidence (Part 5), pushing that fit forward under CMIP6 to project
  future cases (Part 6), and — behind an expandable box — an optional mechanistic
  SEIRS alternative ("Why an SEIRS model?"), which doubles as a worked code base for
  fitting a transmission model directly.
- `session3_future_directions/` — Session 3: a code-free group discussion. Opens
  with "does the question even need climate data?" (weather vs climate; when not to
  project), then breakout-group project-planning prompts (starting from the research
  question, including the ideal-vs-achievable discussion).
- `_extensions/`, `style_training.css`, `logo.png` — copied from the sparkle
  template.

The climate data and the Session 1 slides live in `data/` at the repository root,
shared separately and not tracked in git (see `.gitignore`). The session `.qmd`
files read it via the `data_dir <- "../data"` variable at the top of each file.

## Rendering

```sh
quarto render
```

Requires Quarto ≥ 1.7 and R with these packages:
`jsonlite`, `dplyr`, `tidyr`, `lubridate`, `ggplot2`, `patchwork`, `sf`, `terra`,
`ncdf4`, `tibble`. `execute: freeze: auto` caches results after the first
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

**Statistical pipeline — machine precision.** Province set (15) and months identical,
`cases_mat` bit-identical, `clim_temp` ~5e-13 K, `clim_rain` ~5e-17 m, `panel_beta`
~6e-15, `arx_fit` ~1e-11.

**Mechanistic SEIRS — reproduces where it matters.** With both fits run to convergence
(`maxiter`/`maxit` = 200) the negative log-likelihood agrees to ~6e-3 and the fitted
case totals per province to ~0.3%; the climate sensitivities `b_temp`/`b_rain` to
~1–3%. The individual `beta0`/`scale` parameters differ by 1–3% — a symptom of the
model's weak identifiability, not a porting error (see the identifiability note in the
Session 2 SEIRS section). The integrator itself matches to ~1e-17 given identical
parameters.

Three things this verification surfaced and fixed: standardisation must use the
**population** SD (÷n) to match NumPy's `np.std` (a `popsd()` helper); the climate
extraction reproduces the notebook's chained `.mean('lat').mean('lon')` provincial
average (flagged for Vassili — see To do); and the province selection keeps every
province with >12 months (the updated notebook no longer drops the last two).

## Notes for first render

1. **CMIP6 (Session 2, Part 4)** is the heaviest step (per-model `terra::resample`
   onto the reanalysis grid). Set `CMIP_MODEL_CAP=3` while iterating to cap the
   ensemble; unset for the full run. The precipitation unit conversion is kept
   exactly as the original (`* 86400 / 1000`).
2. `execute: freeze: auto` caches results, so after the first successful render
   subsequent builds are fast. Editing a code chunk invalidates the cache and
   re-runs the document (including the heavy CMIP step).

## To do (course team)

- **Ask Vassili** why the provincial climate is averaged with the chained
  `.mean('lat').mean('lon')` rather than a flat or area-weighted mean (flagged in
  Session 2, Part 3) — so it can be explained and justified to students.
- Review all content and pedagogy (wording, questions, framing), and set presenter
  names in the `.qmd` front matter.
- Decide how much of the optional/advanced material to present — the Part 6
  statistical projection (drift caveat) and the SEIRS section (weakly identified,
  slower to fit in R).
- For a student-facing build, hide speaker notes by setting
  `.speaker-note { display: none; }` in `style_training.css` and re-rendering.
