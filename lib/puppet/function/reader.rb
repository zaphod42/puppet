require 'puppet/function/binder'

module Puppet::Function
  # @api private
  class Reader
    def evaluate(code, context)
      binder = Puppet::Function::Binder.new()
      binder.send(:eval, code)
      binder.bindings(context)
    end
  end
end
