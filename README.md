# CVaR Portfolio DRO — Reproducing Gotoh, Kim, Lim (2026) Section 5.3

Reproduces the minimum-CVaR portfolio frontier experiment with three distributionally robust ambiguity sets.

## Dependencies

- Julia 1.12
- Gurobi 12.0.3 (with valid license)
- Packages: JuMP, CSV, DataFrames, Downloads, Plots

## Usage

```bash
cd ~/Projects/cvar-portfolio-dro
julia --project=. -e 'import Pkg; Pkg.instantiate()'
julia --project=. scripts/run_frontiers.jl
```

Data auto-downloads on first run (Fama-French 30 Industry Portfolios).

## Output

- `output/fig58_left_cvar_vs_tv.png` — CVaR vs TV sensitivity frontier
- `output/fig58_right_cvar_vs_budgeted.png` — CVaR vs Budgeted sensitivity frontier

## Code structure

- `src/data_loader.jl` — auto-download and parse Fama-French CSV
- `src/cvar_utils.jl` — VaR, CVaR, CVaR deviation helpers
- `src/sensitivity_metrics.jl` — Table 4.1⟨ii⟩ WCS formulas
- `src/tv_frontier.jl` — LP for TV ambiguity set
- `src/budgeted_frontier.jl` — LP for budgeted ambiguity set
- `src/chi2_frontier.jl` — SOCP for modified χ² ambiguity set
- `scripts/run_frontiers.jl` — main driver
