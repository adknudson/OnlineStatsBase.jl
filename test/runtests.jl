module OnlineStatsBaseTests
using Test, OnlineStatsBase
O = OnlineStatsBase
import StatsBase: countmap
import DataStructures: OrderedDict, SortedDict

#-----------------------------------------------------------------------# test utils
const y = randn(1000)
const y2 = randn(1000)
const x = randn(1000, 5)
const x2 = randn(1000, 5)

function test_merge(o, y1, y2, compare = ≈; kw...)
    o2 = copy(o)
    fit!(o, y1)
    fit!(o2, y2)
    merge!(o, o2)
    fit!(o2, y1)
    for (v1, v2) in zip(value(o), value(o2))
        result = compare(v1, v2; kw...)
        result || @warn("Test Failure: $v1 != $v2")
        @test result
    end
    @test nobs(o) == nobs(o2)
end

function test_exact(o, y, fo, fy, compare = ≈; kw...)
    fit!(o, y)
    for (v1, v2) in zip(fo(o), fy(y))
        @test compare(v1, v2; kw...)
    end
end

#-----------------------------------------------------------------------# Weight
@testset "Weight" begin
function test_weight(w::OnlineStatsBase.Weight, f::Function)
    println("  > $w")
    @test w == copy(w)
    for i in 1:20
        @test w(i) == f(i)
    end
end
test_weight(@inferred(EqualWeight()),                   i -> 1 / i)
test_weight(@inferred(ExponentialWeight(.1)),           i -> ifelse(i==1, 1.0, .1))
test_weight(@inferred(LearningRate(.6)),                i -> 1 / i^.6)
test_weight(@inferred(LearningRate2(.5)),               i -> 1 / (1 + .5*(i-1)))
test_weight(@inferred(HarmonicWeight(4.)),              i -> 4 / (4 + i - 1))
test_weight(@inferred(Bounded(EqualWeight(), .1)),      i -> max(.1, 1 / i))
test_weight(@inferred(max(LearningRate(.6), .1)),       i -> max(.1, 1 / i^.6))
test_weight(@inferred(Scaled(EqualWeight(), .1)),       i -> .1 * (1 / i))
test_weight(@inferred(.1 * EqualWeight()),              i -> .1 * (1 / i))
test_weight(Bounded(.5 * EqualWeight(), .1),            i -> max(.1, .5 / i))
@test ExponentialWeight(20) == ExponentialWeight(2 / 21)
@test max(.1, EqualWeight()) == max(EqualWeight(), .1)
@test .1 * EqualWeight() == EqualWeight() * .1
@testset "McclainWeight" begin 
    w = McclainWeight(.1)
    for i in 2:100
        @test .1 < w(i) < 1
    end
end
@testset "first weight is one" begin
    for w in [EqualWeight(), ExponentialWeight(), LearningRate(), LearningRate2(), 
              HarmonicWeight(), McclainWeight()]
        @test w(1) == 1 
    end
end
end  # Weight


println("\n\n")
@info("Testing Stats")
#-----------------------------------------------------------------------# AutoCov
@testset "AutoCov" begin 
    test_exact(AutoCov(10), y, autocov, x -> autocov(x, 0:10))
    test_exact(AutoCov(10), y, autocor, x -> autocor(x, 0:10))
    test_exact(AutoCov(10), y, nobs, length)
end
#-----------------------------------------------------------------------# Bootstrap 
@testset "Bootstrap" begin 
    o = fit!(Bootstrap(Mean(), 100, [1]), y)
    @test all(value.(o.replicates) .== value(o.stat))
    @test length(confint(o)) == 2
end
#-----------------------------------------------------------------------# Count 
@testset "Count" begin 
    test_exact(Count(), randn(100), value, length)
    test_merge(Count(), rand(100), rand(100), ==)
end
#-----------------------------------------------------------------------# CountMap
@testset "CountMap" begin
    test_exact(CountMap(Int), rand(1:10, 100), nobs, length, ==)
    test_exact(CountMap(Int), rand(1:10, 100), o->sort(value(o)), x->sort(countmap(x)), ==)
    test_exact(CountMap(Int), [1,2,3,4], o->O.pdf(o,1), x->.25, ==)
    test_merge(CountMap(SortedDict{Bool, Int}()), [rand(Bool, 100)], rand(Bool, 100), ==)
    test_merge(CountMap(SortedDict{Bool, Int}()), trues(100), falses(100), ==)
    test_merge(CountMap(SortedDict{Int, Int}()), rand(1:4, 100), rand(5:123, 50), ==)
    test_merge(CountMap(SortedDict{Int, Int}()), rand(1:4, 100), rand(5:123, 50), ==)
    o = fit!(CountMap(Int), [1,2,3,4])
    @test all([1,2,3,4] .∈ keys(o.value))
    @test probs(o) == fill(.25, 4)
    @test probs(o, 7:9) == zeros(3)
end
#-----------------------------------------------------------------------# CStat 
@testset "CStat" begin 
    data = y + y2 * im 
    data2 = y2 + y * im
    test_exact(CStat(Mean()), data, o->value(o)[1], x -> mean(y))
    test_exact(CStat(Mean()), data, o->value(o)[2], x -> mean(y2))
    test_exact(CStat(Mean()), data, nobs, length, ==)
    test_merge(CStat(Mean()), y, y2)
    test_merge(CStat(Mean()), data, data2)
end
#-----------------------------------------------------------------------# Mean 
@testset "Mean" begin 
    test_exact(Mean(), y, mean, mean)
    test_merge(Mean(), y, y2)
end
#-----------------------------------------------------------------------# Variance 
@testset "Variance" begin 
    test_exact(Variance(), y, mean, mean)
    test_exact(Variance(), y, std, std)
    test_exact(Variance(), y, var, var)
    test_merge(Variance(), y, y2)
end

end #module
