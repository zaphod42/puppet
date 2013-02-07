#! /usr/bin/env ruby
require 'spec_helper'

require 'stringio'
require 'puppet/function/binder'

describe Puppet::Function::Binder do
  let(:binder) { Puppet::Function::Binder.new }

  it "binds a block to the given name" do
    binder.bind(:a) { 'bound' }

    binder.bindings.invoke(:a).should == 'bound'
  end

  it "allows multiple functions in the same binding collection" do
    binder.bind(:a) { 'a binding' }
    binder.bind(:b) { 'b binding' }

    binder.bindings.invoke(:a).should == 'a binding'
    binder.bindings.invoke(:b).should == 'b binding'
  end

  it "binds an object with a 'call' method" do
    binder.bind(:add1, 1.method(:+))

    binder.bindings.invoke(:add1, 2).should == 3
  end

  context "when binding a class" do
    class ClassForTestingBindings
      def initialize(context)
        @context = context
      end

      def a_method(argument)
        argument + " was seen"
      end

      def another_method(argument)
        argument + " was also seen"
      end

      def method_using_context
        @context[:data]
      end

      def set_something(value)
        @something = value
      end

      def get_something
        @something
      end
    end

    it "binds all public instance methods of a class" do
      binder.bind(ClassForTestingBindings)

      binder.bindings.invoke(:a_method, "first method").should == "first method was seen"
      binder.bindings.invoke(:another_method, "second method").should == "second method was also seen"
    end

    it "binds instance methods all on the same instance" do
      binder.bind(ClassForTestingBindings)

      bindings = binder.bindings
      bindings.invoke(:set_something, "my secret value")

      bindings.invoke(:get_something).should == "my secret value"
    end

    it "binds instance methods along with the context" do
      context = { :data => "dummy context" }
      binder.bind(ClassForTestingBindings)

      bindings = binder.bindings(context)

      bindings.invoke(:method_using_context).should == "dummy context"
    end
  end
end


