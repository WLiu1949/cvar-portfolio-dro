module BudgetedFrontier

using JuMP
using Gurobi

export solve_dro, scan_frontier

"""
Budgeted uncertainty set: q_i in [0, (1+eps)*p_i]
From Proposition 4.4 and Table 4.1(i)(c):
max_q E_q[u] = CVaR_{p, alpha_prime}(u) where alpha_prime = eps/(1+eps).

The full DRO-CVaR problem:
  min_{x, alpha, gamma, eta} alpha + gamma/(1-beta) + ((1+eps)/(1-beta)) * E_p[eta]
  s.t. u_i >= -R_i*x - alpha,  u_i >= 0
       eta_i >= u_i - gamma,  eta_i >= 0
       sum(x) = 1
"""
function solve_dro(R::Matrix{Float64}, L::Matrix{Float64}, p::Vector{Float64},
                   beta::Float64, eps::Float64)
    n, d = size(R)
    model = Model(Gurobi.Optimizer)
    set_silent(model)

    @variable(model, x[1:d])
    @variable(model, alpha)
    @variable(model, gamma)
    @variable(model, u[1:n] >= 0)
    @variable(model, eta[1:n] >= 0)

    @constraint(model, sum(x) == 1)
    @constraint(model, [i=1:n], u[i] >= -L[i,:]' * x - alpha)
    @constraint(model, [i=1:n], eta[i] >= u[i] - gamma)

    scale = (1.0 + eps) / (1.0 - beta)
    cvar_term = (1.0 / (n * (1.0 - beta))) * sum(u)
    budget_term = (scale / n) * sum(eta)
    @objective(model, Min, alpha + gamma / (1.0 - beta) + budget_term)

    optimize!(model)
    status = termination_status(model)
    if status != OPTIMAL
        @warn "Budgeted solver: non-optimal status $status for eps=$eps"
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
