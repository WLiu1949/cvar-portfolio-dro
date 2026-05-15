#!/usr/bin/env julia

using Pkg
Pkg.activate(joinpath(@__DIR__, ".."))

using LinearAlgebra: dot
using Statistics: mean, var
using Plots

include(joinpath(@__DIR__, "..", "src", "data_loader.jl"))
include(joinpath(@__DIR__, "..", "src", "cvar_utils.jl"))
include(joinpath(@__DIR__, "..", "src", "sensitivity_metrics.jl"))
include(joinpath(@__DIR__, "..", "src", "tv_frontier.jl"))
include(joinpath(@__DIR__, "..", "src", "budgeted_frontier.jl"))
include(joinpath(@__DIR__, "..", "src", "chi2_frontier.jl"))

using .DataLoader
using .CvarUtils
using .SensitivityMetrics
using .TVFrontier
using .BudgetedFrontier
using .Chi2Frontier

const BETA = 0.9

function nominal_cvar(R, L, p, beta)
    # Use the TV solver with eps=0 (all solvers should agree)
    return TVFrontier.solve_dro(R, L, p, beta, 0.0)
end

function compute_frontier_points(solver_fn, R, L, p, beta, epsilons)
    results = solver_fn(R, L, p, beta, epsilons)
    points = []
    for res in results
        x = res.x
        loss = -R * x
        cvar_val = cvar_risk(loss, beta)
        s_tv, s_bud, s_chi2 = all_sensitivities(loss, beta)
        push!(points, (eps=res.eps, x=x, cvar=cvar_val,
                       s_tv=s_tv, s_bud=s_bud, s_chi2=s_chi2,
                       dr_obj=res.obj))
    end
    return points
end

function main()
    println("="^60)
    println("  Reproducing Gotoh, Kim, Lim (2026) — Section 5.3")
    println("  Minimum CVaR Portfolio — Mean-Sensitivity Frontiers")
    println("="^60)

    # Load data
    println("\n[1] Loading data...")
    R, L, p, n, d = DataLoader.load_returns()
    println("    $n months, $d industries")

    # Nominal solution
    println("\n[2] Computing nominal (ambiguity-neutral) CVaR portfolio...")
    nom_sol = nominal_cvar(R, L, p, BETA)
    if nom_sol === nothing
        error("Failed to solve nominal problem")
    end
    x_nom, alpha_nom, cvar_nom_obj = nom_sol
    loss_nom = -R * x_nom
    cvar_nom = cvar_risk(loss_nom, BETA)
    s_tv_nom, s_bud_nom, s_chi2_nom = all_sensitivities(loss_nom, BETA)
    println("    CVaR₀.₉ = $(round(cvar_nom, digits=4))")
    println("    S_TV    = $(round(s_tv_nom, digits=4))")
    println("    S_bud   = $(round(s_bud_nom, digits=4))")

    # ε ranges (paper uses TV: 0.004, budgeted: 0.15)
    eps_tv = vcat(0.0, 10.0 .^ range(-4, -1.8, length=15))
    eps_bud = vcat(0.0, 10.0 .^ range(-2.5, -0.3, length=15))
    eps_chi2 = vcat(0.0, 10.0 .^ range(-5, -2.0, length=15))

    # Compute frontiers
    println("\n[3] TV frontier...")
    tv_pts = compute_frontier_points(TVFrontier.scan_frontier, R, L, p, BETA, eps_tv)
    println("    $(length(tv_pts)) points")

    println("[4] Budgeted frontier...")
    bud_pts = compute_frontier_points(BudgetedFrontier.scan_frontier, R, L, p, BETA, eps_bud)
    println("    $(length(bud_pts)) points")

    println("[5] Chi2 frontier...")
    chi2_pts = compute_frontier_points(Chi2Frontier.scan_frontier, R, L, p, BETA, eps_chi2)
    println("    $(length(chi2_pts)) points")

    # Plot: Figure 5.8
    println("\n[6] Plotting...")
    output_dir = joinpath(@__DIR__, "..", "output")
    mkpath(output_dir)

    # Left plot: CVaR vs TV sensitivity
    p1 = plot(title="CVaR vs TV Sensitivity",
              xlabel="TV Sensitivity (S_TV)", ylabel="CVaR₀.₉",
              legend=:topright, dpi=150)
    plot_tv = [pt.s_tv for pt in tv_pts]
    plot_bud = [pt.s_tv for pt in bud_pts]
    plot_chi2 = [pt.s_tv for pt in chi2_pts]
    scatter!(p1, plot_tv, [pt.cvar for pt in tv_pts],
             label="TV", marker=:circle, mc=:blue, ms=3)
    scatter!(p1, plot_bud, [pt.cvar for pt in bud_pts],
             label="Budgeted", marker=:diamond, mc=:red, ms=3)
    scatter!(p1, plot_chi2, [pt.cvar for pt in chi2_pts],
             label="Modified χ²", marker=:square, mc=:green, ms=3)
    # Mark nominal
    scatter!(p1, [s_tv_nom], [cvar_nom], label="Nominal (ε=0)",
             marker=:star, mc=:black, ms=6)
    savefig(p1, joinpath(output_dir, "fig58_left_cvar_vs_tv.png"))
    println("    Saved fig58_left_cvar_vs_tv.png")

    # Right plot: CVaR vs Budgeted sensitivity
    p2 = plot(title="CVaR vs Budgeted Sensitivity",
              xlabel="Budgeted Sensitivity (S_b)", ylabel="CVaR₀.₉",
              legend=:topright, dpi=150)
    scatter!(p2, [pt.s_bud for pt in tv_pts], [pt.cvar for pt in tv_pts],
             label="TV", marker=:circle, mc=:blue, ms=3)
    scatter!(p2, [pt.s_bud for pt in bud_pts], [pt.cvar for pt in bud_pts],
             label="Budgeted", marker=:diamond, mc=:red, ms=3)
    scatter!(p2, [pt.s_bud for pt in chi2_pts], [pt.cvar for pt in chi2_pts],
             label="Modified χ²", marker=:square, mc=:green, ms=3)
    scatter!(p2, [s_bud_nom], [cvar_nom], label="Nominal (ε=0)",
             marker=:star, mc=:black, ms=6)
    savefig(p2, joinpath(output_dir, "fig58_right_cvar_vs_budgeted.png"))
    println("    Saved fig58_right_cvar_vs_budgeted.png")

    # Summary table
    println("\n[7] Summary")
    println("-"^70)
    println(rpad("Method", 14), rpad("ε range", 14), rpad("Min CVaR", 12),
            rpad("Min S_TV", 12), rpad("Min S_bud", 12))
    println("-"^70)
    for (name, pts) in [("Nominal", [tv_pts[1]]), ("TV", tv_pts),
                        ("Budgeted", bud_pts), ("χ²", chi2_pts)]
        if length(pts) > 1
            min_cvar_pt = pts[argmin([p.cvar for p in pts])]
            min_tv_pt = pts[argmin([p.s_tv for p in pts])]
            min_bud_pt = pts[argmin([p.s_bud for p in pts])]
            println(rpad(name, 14),
                    rpad("$(round(pts[1].eps,digits=5))–$(round(pts[end].eps,digits=5))", 14),
                    rpad(round(min_cvar_pt.cvar, digits=4), 12),
                    rpad(round(min_tv_pt.s_tv, digits=4), 12),
                    rpad(round(min_bud_pt.s_bud, digits=4), 12))
        else
            pt = pts[1]
            println(rpad(name, 14), rpad("0", 14),
                    rpad(round(pt.cvar, digits=4), 12),
                    rpad(round(pt.s_tv, digits=4), 12),
                    rpad(round(pt.s_bud, digits=4), 12))
        end
    end
    println("-"^70)

    println("\nDone. Output in $output_dir/")
end

main()
