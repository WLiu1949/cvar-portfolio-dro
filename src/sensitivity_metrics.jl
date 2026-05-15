module SensitivityMetrics

using Statistics: mean, var, quantile

export chi2_sensitivity, tv_sensitivity, budgeted_sensitivity, all_sensitivities

# Inline helpers to avoid cross-module dependency
_var_risk(sample, beta) = quantile(sample, beta)

function _cvar_deviation(sample, beta)
    v = _var_risk(sample, beta)
    excess = max.(sample .- v, 0.0)
    return mean(excess) / (1.0 - beta)
end

function _tail_excess(sample, beta)
    v = _var_risk(sample, beta)
    return max.(sample .- v, 0.0)
end

"""
Table 4.1⟨ii⟩ — Worst-case sensitivity of CVaR_beta under various ambiguity sets.

(a) Modified chi2: S = sqrt(2*V_p(tail_excess)) / (1-beta)
(b) Total variation: S = (max(loss) - VaR) / (2*(1-beta))
(c) Budgeted: S = CVaR - VaR
"""
function chi2_sensitivity(loss::AbstractVector{<:Real}, beta::Real)
    excess = _tail_excess(loss, beta)
    return sqrt(2.0 * var(excess; corrected=false)) / (1.0 - beta)
end

function tv_sensitivity(loss::AbstractVector{<:Real}, beta::Real)
    v = _var_risk(loss, beta)
    return (maximum(loss) - v) / (2.0 * (1.0 - beta))
end

function budgeted_sensitivity(loss::AbstractVector{<:Real}, beta::Real)
    return _cvar_deviation(loss, beta)
end

function all_sensitivities(loss::AbstractVector{<:Real}, beta::Real)
    return (
        tv_sensitivity(loss, beta),
        budgeted_sensitivity(loss, beta),
        chi2_sensitivity(loss, beta),
    )
end

end
