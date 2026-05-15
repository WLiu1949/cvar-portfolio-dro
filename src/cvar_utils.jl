module CvarUtils

using Statistics: mean, var, std, quantile

export cvar_risk, var_risk, cvar_deviation, tail_excess, cvar_min_alpha

"""
    VaR(sample, beta)

Value-at-Risk at level beta (e.g., 0.9) from empirical sample.
VaR(0.9) = the smallest value such that P(X ≤ VaR) ≥ 0.9.
Equivalently: quantile(sample, beta).
"""
function var_risk(sample::AbstractVector{<:Real}, beta::Real)
    return quantile(sample, beta)
end

"""
    CVaR(sample, beta)

Conditional Value-at-Risk: average of values exceeding VaR(beta).
For discrete empirical distribution with equal weights 1/n:
CVaR = (1/(1-beta)) * mean(max(sample - VaR(beta), 0)) + VaR(beta)
"""
function cvar_risk(sample::AbstractVector{<:Real}, beta::Real)
    v = var_risk(sample, beta)
    excess = max.(sample .- v, 0.0)
    return v + mean(excess) / (1.0 - beta)
end

"""
    cvar_deviation(sample, beta)

CVaR deviation: CVaR_beta - VaR_beta.
Used as budgeted WCS for CVaR (Table 4.1(ii)(c)).
"""
function cvar_deviation(sample::AbstractVector{<:Real}, beta::Real)
    v = var_risk(sample, beta)
    excess = max.(sample .- v, 0.0)
    return mean(excess) / (1.0 - beta)
end

"""
    tail_excess(sample, beta)

Returns the excess vector (sample_i - VaR(beta))_+ used in WCS formulas.
"""
function tail_excess(sample::AbstractVector{<:Real}, beta::Real)
    v = var_risk(sample, beta)
    return max.(sample .- v, 0.0)
end

"""
    CVaR from VaR and excess — LP formulation helper:
    CVaR(beta) = min_alpha { alpha + mean(max(sample - alpha, 0)) / (1-beta) }
"""
function cvar_min_alpha(sample::AbstractVector{<:Real}, beta::Real)
    # Returns optimal alpha = VaR and the CVaR value
    n = length(sample)
    # This equals var_risk at optimum
    v = var_risk(sample, beta)
    excess = max.(sample .- v, 0.0)
    val = v + mean(excess) / (1.0 - beta)
    return v, val
end

end
