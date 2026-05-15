module Chi2Frontier

using JuMP
using Gurobi
using LinearAlgebra: dot, norm

export solve_dro, scan_frontier

"""
Modified chi2 divergence: phi(z) = (z-1)^2/2, phi''(1) = 1.

From the dual (Appendix C.1), the DRO problem reduces to:
  min_{x, alpha} E_p[f_alpha] + sqrt(2*eps) * std(f_alpha)
where f_alpha = alpha + max(L - alpha, 0) / (1 - beta).

Since alpha is a constant shift:
  std(f_alpha) = std(max(L - alpha, 0)) / (1 - beta)

Full SOCP:
  min_{x, alpha, u, t}  alpha + mean(u)/(1-beta) + sqrt(2*eps)/(1-beta) * t
  s.t.  u_i >= L_i - alpha,  u_i >= 0
        t >= std(u)  (formulated via SOC)
        sum(x) = 1

SOC formulation: ||u - mean(u)|| <= sqrt(n) * t
"""
function solve_dro(R::Matrix{Float64}, L::Matrix{Float64}, p::Vector{Float64},
                   beta::Float64, eps::Float64)
    n, d = size(R)
    model = Model(Gurobi.Optimizer)
    set_silent(model)

    @variable(model, x[1:d])
    @variable(model, alpha)
    @variable(model, u[1:n] >= 0)
    @variable(model, v[1:n])
    @variable(model, t >= 0)

    @constraint(model, sum(x) == 1)
    @constraint(model, [i=1:n], u[i] >= -L[i,:]' * x - alpha)
    @constraint(model, [i=1:n], v[i] == u[i] - sum(u) / n)

    soc_rhs = sqrt(n) * t
    @constraint(model, [soc_rhs; v] in SecondOrderCone())

    lambda = sqrt(2.0 * eps) / (1.0 - beta)
    @objective(model, Min, alpha + sum(u) / (n * (1.0 - beta)) + lambda * t)

    optimize!(model)
    status = termination_status(model)
    if status != OPTIMAL
        @warn "Chi2 solver: non-optimal status $status for eps=$eps"
        return nothing
    end
    return value.(x), value(alpha), objective_value(model)
end

function scan_frontier(R, L, p, beta, epsilons::Vector{Float64})
    results = []
    for eps in epsilons
        sol = solve_dro(R, L, p, beta, eps)
        if sol !== nothing
            x_opt, alpha_opt, obj = sol
            push!(results, (eps=eps, x=x_opt, alpha=alpha_opt, obj=obj))
        end
    end
    return results
end

end
