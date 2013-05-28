#!/usr/bin/env ruby

require 'benchmark'
require 'yaml'
require 'msgpack'

require File.expand_path("../lib/satt.rb", __FILE__)
require File.expand_path("../test/examples.rb", __FILE__)

obj = EXAMPLES

algs = [ YAML, Marshal, Satt ]

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
