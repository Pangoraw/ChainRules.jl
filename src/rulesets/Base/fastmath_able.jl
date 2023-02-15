let
    # Include inside this quote any rules that should have FastMath versions
    # IMPORTANT:
    # Do not add any rules here for functions that do not have varients in Base.FastMath
    # e.g. do not add `foo` unless `Base.FastMath.foo_fast` exists.
    fastable_ast = quote
        #  Trig-Basics
        ## use `sincos` to compute `sin` and `cos` at the same time
        ## for the rules for `sin` and `cos`
        ## See issue: https://github.com/JuliaDiff/ChainRules.jl/issues/291
        ## sin
        function rrule(::typeof(sin), x::Number)
            sinx, cosx = sincos(x)
            sin_pullback(Δy) = (NoTangent(), cosx' * Δy)
            return (sinx, sin_pullback)
        end

        function frule((_, Δx), ::typeof(sin), x::Number)
            sinx, cosx = sincos(x)
            return (sinx, cosx * Δx)
        end

        ## cos
        function rrule(::typeof(cos), x::Number)
            sinx, cosx = sincos(x)
            cos_pullback(Δy) = (NoTangent(), -sinx' * Δy)
            return (cosx, cos_pullback)
        end
        
        function frule((_, Δx), ::typeof(cos), x::Number)
            sinx, cosx = sincos(x)
            return (cosx, -sinx * Δx)
        end
        
        @scalar_rule tan(x) 1 + Ω ^ 2


        # Trig-Hyperbolic
        @scalar_rule cosh(x) sinh(x)
        @scalar_rule sinh(x) cosh(x)
        @scalar_rule tanh(x) 1 - Ω ^ 2

        # Trig- Inverses
        @scalar_rule acos(x) -(inv(sqrt(1 - x ^ 2)))
        @scalar_rule asin(x) inv(sqrt(1 - x ^ 2))
        @scalar_rule atan(x) inv(1 + x ^ 2)

        # Trig-Multivariate
        @scalar_rule atan(y, x) @setup(u = x ^ 2 + y ^ 2) (x / u, -y / u)
        @scalar_rule sincos(x) @setup((sinx, cosx) = Ω) cosx -sinx

        # exponents
        @scalar_rule cbrt(x) inv(3 * Ω ^ 2)
        @scalar_rule inv(x) -(Ω ^ 2)
        @scalar_rule sqrt(x) inv(2Ω)  # gradient +Inf at x==0
        @scalar_rule exp(x) Ω
        @scalar_rule exp10(x) logten * Ω
        @scalar_rule exp2(x) logtwo * Ω
        @scalar_rule expm1(x) exp(x)
        @scalar_rule log(x) inv(x)
        @scalar_rule log10(x) inv(logten * x)
        @scalar_rule log1p(x) inv(x + 1)
        @scalar_rule log2(x) inv(logtwo * x)

        # Unary complex functions
        ## abs
        function frule((_, Δx), ::typeof(abs), x::Union{Real, Complex})
            Ω = abs(x)
            # `ifelse` is applied only to denominator to ensure type-stability.
            signx = x isa Real ? sign(x) : x / ifelse(iszero(x), one(Ω), Ω)
            return Ω, realdot(signx, Δx)
        end

        function rrule(::typeof(abs), x::Union{Real, Complex})
            Ω = abs(x)
            function abs_pullback(ΔΩ)
                signx = x isa Real ? sign(x) : x / ifelse(iszero(x), one(Ω), Ω)
                return (NoTangent(), signx * real(ΔΩ))
            end
            return Ω, abs_pullback
        end

        function ChainRulesCore.derivatives_given_output(Ω, ::typeof(abs), x::Union{Real, Complex})
            signx = x isa Real ? sign(x) : x / ifelse(iszero(x), one(Ω), Ω)
            return tuple(tuple(signx))
        end

        ## abs2
        function frule((_, Δz), ::typeof(abs2), z::Union{Real, Complex})
            return abs2(z), 2 * realdot(z, Δz)
        end

        function rrule(::typeof(abs2), z::Union{Real, Complex})
            function abs2_pullback(ΔΩ)
                Δu = real(ΔΩ)
                return (NoTangent(), 2Δu*z)
            end
            return abs2(z), abs2_pullback
        end

        ## conj
        function frule((_, Δz), ::typeof(conj), z::Union{Real, Complex})
            return conj(z), conj(Δz)
        end
        function rrule(::typeof(conj), z::Union{Real, Complex})
            function conj_pullback(ΔΩ)
                return (NoTangent(), conj(ΔΩ))
            end
            return conj(z), conj_pullback
        end

        ## angle
        function frule((_, Δx), ::typeof(angle), x)
            Ω = angle(x)
            # `ifelse` is applied only to denominator to ensure type-stability.
            n = ifelse(iszero(x), one(real(x)), abs2(x))
            ∂Ω = _imagconjtimes(x, Δx) / n
            return Ω, ∂Ω
        end

        function rrule(::typeof(angle), x::Real)
            function angle_pullback(ΔΩ::Real)
                return (NoTangent(), ZeroTangent())
            end
            function angle_pullback(ΔΩ)
                Δu, Δv = reim(ΔΩ)
                return (NoTangent(), im*Δu/ifelse(iszero(x), one(x), x))
                # `ifelse` is applied only to denominator to ensure type-stability.
            end
            return angle(x), angle_pullback
        end
        function rrule(::typeof(angle), z::Complex)
            function angle_pullback(ΔΩ)
                x,  y  = reim(z)
                Δu, Δv = reim(ΔΩ)
                # `ifelse` is applied only to denominator to ensure type-stability.
                n = ifelse(iszero(z), one(real(z)), abs2(z))
                return (NoTangent(), (-y + im*x)*Δu/n)
            end
            return angle(z), angle_pullback
        end

        # Binary functions

        ## `hypot`
        function frule(
            (_, Δx, Δy),
            ::typeof(hypot),
            x::T,
            y::T,
        ) where {T<:Union{Real,Complex}}
            Ω = hypot(x, y)
            n = ifelse(iszero(Ω), one(Ω), Ω)
            ∂Ω = (realdot(x, Δx) + realdot(y, Δy)) / n
            return Ω, ∂Ω
        end

        function rrule(::typeof(hypot), x::T, y::T) where {T<:Union{Real,Complex}}
            Ω = hypot(x, y)
            function hypot_pullback(ΔΩ)
                c = real(ΔΩ) / ifelse(iszero(Ω), one(Ω), Ω)
                return (NoTangent(), c * x, c * y)
            end
            return (Ω, hypot_pullback)
        end

        @scalar_rule x + y (true, true)
        @scalar_rule x - y (true, -1)
        @scalar_rule x / y (one(x) / y, -(Ω / y))
        
        ## many-arg +
        function frule((_, Δx, Δy...), ::typeof(+), x::Number, ys::Number...)
            +(x, ys...), +(Δx, Δy...)
        end
        
        function rrule(::typeof(+), x::Number, ys::Number...)
            plus_back(dz) = (NoTangent(), dz, map(Returns(dz), ys)...)
            +(x, ys...), plus_back
        end        

        ## power
        # literal_pow is in base.jl
        function frule((_, Δx, Δp), ::typeof(^), x::Number, p::Number)
            if isinteger(p)
                tmp = x ^ (p - 1)
                y = x * tmp
                _dx = p * tmp
            else
                y = x ^ p
                _dx = _pow_grad_x(x, p, float(y))
            end
            if iszero(Δp)
                # Treat this as a strong zero, to avoid NaN, and save the cost of log
                return y, _dx * Δx
            else
                # This may do real(log(complex(...))) which matches ProjectTo in rrule
                _dp = _pow_grad_p(x, p, float(y))
                return y, muladd(_dp, Δp, _dx * Δx)
            end
        end

        function rrule(::typeof(^), x::Number, p::Number)
            y = x^p
            project_x = ProjectTo(x)
            project_p = ProjectTo(p)
            function power_pullback(dy)
                _dx = _pow_grad_x(x, p, float(y))
                return (
                    NoTangent(), 
                    project_x(conj(_dx) * dy),
                    # _pow_grad_p contains log, perhaps worth thunking:
                    @thunk project_p(conj(_pow_grad_p(x, p, float(y))) * dy)
                )
            end
            return y, power_pullback
        end

        ## `rem`
        @scalar_rule(
            rem(x, y),
            @setup((u, nan) = promote(x / y, NaN16), isint = isinteger(x / y)),
            (ifelse(isint, nan, one(u)), ifelse(isint, nan, -trunc(u))),
        )
        ## `min`, `max`
        @scalar_rule max(x, y) @setup(gt = x > y) (gt, !gt)
        @scalar_rule min(x, y) @setup(gt = x > y) (!gt, gt)

        # Unary functions
        @scalar_rule +x true
        @scalar_rule -x -1

        ## `sign`
        function frule((_, Δx), ::typeof(sign), x)
            n = ifelse(iszero(x), one(real(x)), abs(x))
            Ω = x isa Real ? sign(x) : x / n
            ∂Ω = Ω * (_imagconjtimes(Ω, Δx) / n) * im
            return Ω, ∂Ω
        end

        function rrule(::typeof(sign), x)
            n = ifelse(iszero(x), one(real(x)), abs(x))
            Ω = x isa Real ? sign(x) : x / n
            function sign_pullback(ΔΩ)
                ∂x = Ω * (_imagconjtimes(Ω, ΔΩ) / n) * im
                return (NoTangent(), ∂x)
            end
            return Ω, sign_pullback
        end

        # product rule requires special care for arguments where `mul` is non-commutative
        function frule((_, Δx, Δy), ::typeof(*), x::Number, y::Number)
            # Optimized version of `Δx .* y .+ x .* Δy`. Also, it is potentially more
            # accurate on machines with FMA instructions, since there are only two
            # rounding operations, one in `muladd/fma` and the other in `*`.
            ∂xy = muladd(Δx, y, x * Δy)
            return x * y, ∂xy
        end
        frule((_, Δx), ::typeof(*), x::Number) = x, Δx

        function rrule(::typeof(*), x::Number, y::Number)
            function times_pullback2(Ω̇)
                ΔΩ = unthunk(Ω̇)
                return (NoTangent(), ProjectTo(x)(ΔΩ * y'), ProjectTo(y)(x' * ΔΩ))
            end
            return x * y, times_pullback2
        end
        # While 3-arg * calls 2-arg *, this is currently slow in Zygote:
        # https://github.com/JuliaDiff/ChainRules.jl/issues/544
        function rrule(::typeof(*), x::Number, y::Number, z::Number)
            function times_pullback3(Ω̇)
                ΔΩ = unthunk(Ω̇)
                return (
                    NoTangent(), 
                    ProjectTo(x)(ΔΩ * y' * z'),
                    ProjectTo(y)(x' * ΔΩ * z'),
                    ProjectTo(z)(x' * y' * ΔΩ),
                )
            end
            return x * y * z, times_pullback3
        end
        # Instead of this recursive rule for N args, you could write the generic case
        # directly, by nesting ntuples, but this didn't infer well:
        # https://github.com/JuliaDiff/ChainRules.jl/pull/547/commits/3558951c9f1b3c70e7135fd61d29cc3b96a68dea
        function rrule(::typeof(*), x::Number, y::Number, z::Number, more::Number...)
            Ω3, back3 = rrule(*, x, y, z)
            Ω4, back4 = rrule(*, Ω3, more...)
            function times_pullback4(Ω̇)
                Δ4 = back4(unthunk(Ω̇))  # (0, ΔΩ3, Δmore...)
                Δ3 = back3(Δ4[2])       # (0, Δx, Δy, Δz)
                return (Δ3..., Δ4[3:end]...)
            end
            return Ω4, times_pullback4
        end
        rrule(::typeof(*), x::Number) = rrule(identity, x)
        
        # This is used to choose a faster path in some broadcasting operations:
        ChainRulesCore.derivatives_given_output(Ω, ::typeof(*), x::Number, y::Number) = tuple((y', x'))
        ChainRulesCore.derivatives_given_output(Ω, ::typeof(*), x::Number, y::Number, z::Number) = tuple((y'z', x'z', x'y'))
    end  # fastable_ast

    # Rewrite everything to use fast_math functions, including the type-constraints
    fast_ast = Base.FastMath.make_fastmath(fastable_ast)

    # Guard against mistakenly defining something as fast-able when it isn't.
    # NOTE: this check is not infallible, it will be tricked if a function itself is not
    # fastmath_able but it's pullback uses something that is. So manual check should also be
    # done.
    non_transformed_definitions = intersect(fastable_ast.args, fast_ast.args)
    filter!(expr->!(expr isa LineNumberNode), non_transformed_definitions)
    if !isempty(non_transformed_definitions)
        error(
            "Non-FastMath compatible rules defined in fastmath_able.jl. \n Definitions:\n" *
            join(non_transformed_definitions, "\n")
        )
        # This error() may not play well with Revise. But a wanring @error does, we should change it:
        @error "Non-FastMath compatible rules defined in fastmath_able.jl." non_transformed_definitions
    end

    eval(fast_ast)
    eval(fastable_ast)  # Get original definitions
    # we do this second so it overwrites anything we included by mistake in the fastable
end

## power
# Thes functions need to be defined outside the eval() block.
# The special cases they aim to hit are in POWERGRADS in tests.
_pow_grad_x(x, p, y) = (p * y / x)
function _pow_grad_x(x::Real, p::Real, y)
    return if !iszero(x) || p < 0
        p * y / x
    elseif isone(p)
        one(y)
    elseif iszero(p) || p > 1
        zero(y)
    else
        oftype(y, Inf)
    end
end

_pow_grad_p(x, p, y) = y * log(complex(x))
function _pow_grad_p(x::Real, p::Real, y)
    return if !iszero(x)
        y * real(log(complex(x)))
    elseif p > 0
        zero(y)
    else
        oftype(y, NaN)
    end
end
