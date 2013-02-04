#! /usr/bin/env ruby
require 'spec_helper'

require 'stringio'
require 'puppet/function/reader'

describe Puppet::Function::Reader do
  let(:reader) { Puppet::Function::Reader.new }
  let(:no_context) { nil }

  it "evaluates an input for a function binding" do
    bindings = reader.evaluate(StringIO.new("bind(:a) { || 'bound' }"), no_context)

    bindings.invoke(:a).should == 'bound'
  end

  it "binds everything declared" do
    bindings = reader.evaluate(StringIO.new("bind(:a) { }; bind(:b) { }"), no_context)

    bindings.bound?(:a).should == true
    bindings.bound?(:b).should == true
    bindings.bound?(:c).should == false
  end

  it "binds an object with a 'call' method" do
    bindings = reader.evaluate(StringIO.new("bind(:add1, 1.method(:+))"), no_context)

    bindings.invoke(:add1, 2).should == 3
  end

  it "binds all public instance methods of a class" do
    bindings = reader.evaluate(StringIO.new(<<-BINDINGS), no_context)
    class MyClass
      def initialize(context) end

      def a_method(argument)
        argument + " was seen"
      end

      def another_method(argument)
        argument + " was also seen"
      end
    end

    bind(MyClass)
    BINDINGS

    bindings.invoke(:a_method, "first method").should == "first method was seen"
    bindings.invoke(:another_method, "second method").should == "second method was also seen"
  end

  it "binds instance methods all on the same instance" do
    bindings = reader.evaluate(StringIO.new(<<-BINDINGS), no_context)
    class MyClass
      def initialize(context) end

      def a_method(argument)
        @argument_from_a_method = argument
        "a_method called"
      end

      def another_method(argument)
        argument + " was seen after " + @argument_from_a_method
      end
    end

    bind(MyClass)
    BINDINGS

    bindings.invoke(:a_method, "first").should == "a_method called"
    bindings.invoke(:another_method, "second").should == "second was seen after first"
  end

  it "binds instance methods along with the context" do
    context = { :something => "dummy context" }

    bindings = reader.evaluate(StringIO.new(<<-BINDINGS), context)
    class MyClass
      def initialize(context)
        @context = context
      end

      def a_method(argument)
        argument + " " + @context[:something]
      end
    end

    bind(MyClass)
    BINDINGS

    bindings.invoke(:a_method, "method saw").should == "method saw dummy context"
  end
end

