## Model

"""
$(TYPEDEF)

A generative model for graphs with node features, which combines a Stochastic Block Model with a mixture of Gaussians.

Reference: <https://arxiv.org/abs/2306.07948>

# Fields

$(TYPEDFIELDS)
"""
struct CSBM{R} <: AbstractSBM
    "graph size"
    N::Int
    "feature dimension"
    P::Int
    "average degree"
    d::R
    "SNR of the communities"
    λ::R
    "SNR of the features"
    μ::R
    "fraction of node assignments observed"
    ρ::R

    function CSBM(; N::Integer, P::Integer, d::R1, λ::R2, μ::R3, ρ::R4) where {R1,R2,R3,R4}
        R = promote_type(R1, R2, R3, R4)
        return new{R}(N, P, d, λ, μ, ρ)
    end
end

Base.length(csbm::CSBM) = csbm.N
nb_features(csbm::CSBM) = csbm.P
average_degree(csbm::CSBM) = csbm.d
communities_snr(csbm::CSBM) = csbm.λ
features_snr(csbm::CSBM) = csbm.μ
fraction_observed(csbm::CSBM) = csbm.ρ

"""
    effective_snr(csbm)

Compute the effective SNR `λ² + μ² / (N/P)`.
"""
function effective_snr(csbm::CSBM)
    (; λ, μ, N, P) = csbm
    return abs2(λ) + abs2(μ) / (N / P)
end

## Latents

"""
$(TYPEDEF)

The hidden variables generated by sampling from a [`CSBM`](@ref).

# Fields

$(TYPEDFIELDS)
"""
@kwdef struct LatentsCSBM{R<:Real} <: AbstractLatents
    "community assignments, length `N`"
    u::Vector{Int}
    "feature centroids, length `P`"
    v::Vector{R}
end

discrete_values(latents::LatentsCSBM) = latents.u
continuous_values(latents::LatentsCSBM) = latents.v

## Observations

"""
$(TYPEDEF)

The observations generated by sampling from a [`CSBM`](@ref).

# Fields

$(TYPEDFIELDS)
"""
@kwdef struct ObservationsCSBM{R<:Real,G<:AbstractGraph{Int}} <: AbstractObservations
    "undirected unweighted graph with `N` nodes (~ adjacency matrix `A`)"
    g::G
    "revealed communities `±1` for a fraction `ρ` of nodes and `missing` for the rest, length `N`"
    Ξ::Vector{Union{Int,Missing}}
    "feature matrix, size `(P, N)`"
    B::Matrix{R}
end

## Simulation

function Random.rand!(rng::AbstractRNG, B::Matrix, csbm::CSBM)
    (; N, P, μ) = csbm

    u = rand(rng, (-1, +1), N)
    v = randn(rng, P)

    g = sample_graph(rng, csbm, u)
    Ξ = sample_mask(rng, csbm, u)

    randn!(rng, B)
    B .+= sqrt(μ / N) .* v .* u'

    latents = LatentsCSBM(; u, v)
    observations = ObservationsCSBM(; g, Ξ, B)
    return (; latents, observations)
end

function Base.rand(rng::AbstractRNG, csbm::CSBM)
    (; N, P) = csbm
    B = Matrix{Float64}(undef, P, N)
    return rand!(rng, B, csbm)
end