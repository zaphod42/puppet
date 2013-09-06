require 'spec_helper'
require 'securerandom'
require 'benchmark'
require 'json'

require 'rspec-prof'

describe "pson serialization" do
  let!(:string_data) do
    Hash[0.upto(1000).collect { [SecureRandom.uuid, 0.upto(500).collect { SecureRandom.uuid }] }]
  end

  let!(:hash_data) do
    Hash[0.upto(1000).collect { |v| [v, Hash[0.upto(500).collect { |v| [v, { v => v }] }]] }]
  end

  let!(:array_data) do
    { "array" => 0.upto(1000).collect { 0.upto(500).collect { |v| [v] } } }
  end

  after :each do
    GC.disable
  end

  after :each do
    GC.start
  end

  profile do
    it "is fast for strings" do
      serializes_pson_speedily_for(string_data)
    end

    it "is fast for hashes" do
      serializes_pson_speedily_for(hash_data)
    end

    it "is fast for arrays" do
      serializes_pson_speedily_for(array_data)
    end
  end

  def serializes_pson_speedily_for(data)
    pson_time = Benchmark.measure { data.to_pson }
    json_time = Benchmark.measure { JSON.generate(data) }

    expect(pson_time.real).to be_within_10_percent_of(json_time.real)
  end

  def be_within_10_percent_of(value)
    be_within(value * 0.1).of(value)
  end
end
