#! /usr/bin/env ruby
require 'spec_helper'

require 'stringio'
require 'puppet/function/reader'

describe Puppet::Function::Reader do
  let(:reader) { Puppet::Function::Reader.new }
  let(:no_context) { nil }

  it "evaluates an input for a function binding" do
    bindings = reader.evaluate("bind(:a) { 'bound' }", no_context)

    bindings.invoke(:a).should == 'bound'
  end

  it "binds everything declared" do
    bindings = reader.evaluate("bind(:a) { 'in a' }; bind(:b) { 'in b' }", no_context)

    bindings.invoke(:a).should == 'in a'
    bindings.invoke(:b).should == 'in b'
  end
end

