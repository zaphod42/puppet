module Puppet::Function
  # @api private
  class Binder
    def initialize(bindings, context)
      @bindings = bindings
      @context = context
    end

    def bind(name_or_class, object = nil, &block)
      if block
        bind_callable(name_or_class, block)
      elsif object
        bind_callable(name_or_class, object)
      else
        bind_class(name_or_class)
      end
    end

  private

    def bind_callable(name, callable)
      @bindings.add(BoundFunction.new(name, callable))
    end

    def bind_class(implementation)
      instance = implementation.new(@context)
      instance.methods.each do |method_name|
        bind_callable(method_name, instance.method(method_name))
      end
    end

    # @api public
    class Bindings
      def initialize
        @bindings = {}
      end

      def add(binding)
        @bindings[binding.name] = binding
      end

      def invoke(name, *args)
        @bindings[name].invoke(*args)
      end

      def bound?(name)
        @bindings.include?(name)
      end
    end

    class BoundFunction
      attr_reader :name

      def initialize(name, implementor)
        @name = name
        @implementor = implementor
      end

      def invoke(*args)
        @implementor.call(*args)
      end
    end
  end
end
