## Model

"""
    ContextualSBM

A generative model for graphs with node features, which combines a Stochastic Block Model with a mixture of Gaussians.

Reference: <https://arxiv.org/abs/2306.07948>

# Fields

- `N`: graph size
- `P`: feature dimension
- `d`: average degree
- `λ`: SNR of the communities
- `μ`: SNR of the features
- `ρ`: fraction of nodes revealed
"""
struct ContextualSBM{R<:Real} <: AbstractSBM
    N::Int
    P::Int
    d::R
    λ::R
    μ::R
    ρ::R

    function ContextualSBM(;
        N::Integer, P::Integer, d::R1, λ::R2, μ::R3, ρ::R4
    ) where {R1,R2,R3,R4}
        R = promote_type(R1, R2, R3, R4)
        return new{R}(N, P, d, λ, μ, ρ)
    end
end

average_degree(csbm::CSBM) = csbm.d
communities_snr(csbm::CSBM) = csbm.λ

"""
    effective_snr(csbm)

Compute the effective SNR `λ² + μ² / (N/P)`.
"""
function effective_snr(csbm::ContextualSBM)
    (; λ, μ, N, P) = csbm
    return abs2(λ) + abs2(μ) / (N / P)
end


## Latents

"""
    ContextualSBMLatents

The hidden variables generated by sampling from a [`ContextualSBM`](@ref).

# Fields

- `u::Vector`: community assignments, length `N`
- `v::Vector`: feature centroids, length `P`
"""
@kwdef struct ContextualSBMLatents{R<:Real}
    u::Vector{Int}
    v::Vector{R}
end

## Observations

"""
    ContextualSBMObservations

The observations generated by sampling from a [`ContextualSBM`](@ref).

# Fields
- `A::AbstractMatrix`: symmetric boolean adjacency matrix, size `(N, N)`
- `g::AbstractGraph`: undirected unweighted graph generated from `A`
- `B::Matrix`: feature matrix, size `(P, N)`
- `Ξ::Vector`: revealed communities `±1` for a fraction of nodes and `0` for the rest, length `N`
"""
@kwdef struct ContextualSBMObservations{
    R<:Real,M<:AbstractMatrix{Bool},G<:AbstractGraph{Int}
}
    A::M
    g::G
    B::Matrix{R}
    Ξ::Vector{Int}
end

## Simulation

"""
    rand(rng, csbm)

Sample from a [`ContextualSBM`](@ref) and return a named tuple `(; latents, observations)`.
"""
function Base.rand(rng::AbstractRNG, csbm::ContextualSBM)
    (; N, P, μ, ρ) = csbm
    (; cᵢ, cₒ) = affinities(csbm)

    u = rand(rng, (-1, +1), N)
    v = randn(rng, P)
    latents = ContextualSBMLatents(; u, v)

    Is, Js = Int[], Int[]
    for i in 1:N, j in (i + 1):N
        r = rand(rng)
        if (
            ((u[i] == u[j]) && (r < cᵢ / N)) ||  # same community
            ((u[i] != u[j]) && (r < cₒ / N))  # different community
        )
            push!(Is, i)
            push!(Is, j)
            push!(Js, j)
            push!(Js, i)
        end
    end
    Vs = fill(true, length(Is))
    A = sparse(Is, Js, Vs, N, N)
    g = SimpleWeightedGraph(A)

    B = randn(rng, P, N)
    B .+= sqrt(μ / N) .* v .* u'

    Ξ = zeros(Int, N)
    for i in 1:N
        if rand(rng) < ρ
            Ξ[i] = u[i]
        end
    end

    observations = ContextualSBMObservations(; A, g, B, Ξ)
    return (; latents, observations)
end
