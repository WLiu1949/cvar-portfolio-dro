module TVFrontier

using JuMP
using Gurobi
using LinearAlgebra: dot

export solve_dro, scan_frontier

function solve_dro(R::Matrix{Float64}, L::Matrix{Float64}, p::Vector{Float64},
                   beta::Float64, eps::Float64)
    n, d = size(R)
    model = Model(Gurobi.Optimizer)
    set_silent(model)

    @variable(model, x[1:d])
    @variable(model, alpha)
    @variable(model, u[1:n] >= 0)
    @variable(model, M)

    @constraint(model, sum(x) == 1)
    @constraint(model, [i=1:n], u[i] >= -L[i,:]' * x - alpha)
    @constraint(model, [i=1:n], M >= u[i])

    cvar_term = (1.0 / (n * (1.0 - beta))) * sum(u)
    tv_term = (eps / (2.0 * (1.0 - beta))) * M
    @objective(model, Min, alpha + cvar_term + tv_term)

    optimize!(model)
    status = termination_status(model)
    if status != OPTIMAL
        @warn "TV solver: non-optimal status $status for eps=$eps"
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
