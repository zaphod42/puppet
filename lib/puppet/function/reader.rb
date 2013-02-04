require 'puppet/function/binder'
module Puppet::Function
  # @api private
  class Reader
    def evaluate(code, context)
      bindings = Puppet::Function::Bindings.new
      binder = Puppet::Function::Binder.new(bindings, context)
      binder.send(:eval, code)
      bindings
    end
  end
end
