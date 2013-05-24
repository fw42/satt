#!/usr/bin/env ruby

require 'benchmark'
require 'yaml'
require 'msgpack'
require "satt"

algs = [ YAML, Marshal, Satt ]

obj = {}

SAMPLES = 5000

Benchmark.bmbm do |r|
  algs.each do |alg|
    r.report(alg.to_s) do
      SAMPLES.times do
        alg.load(alg.dump(obj))
      end
    end

    r.report(alg.to_s + "_dump") do
      SAMPLES.times do
        alg.dump(obj)
      end
    end

    str = alg.dump(obj).freeze
    r.report(alg.to_s + "_load") do
      SAMPLES.times do
        alg.load(str)
      end
    end
  end
end
