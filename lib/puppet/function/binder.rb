module Puppet::Function
  # @api private
  class Binder
    def initialize
      @binders = []
      @context = nil
    end

    def bind(name_or_class, object = nil, &block)
      binder = if block
                 bind_callable(name_or_class, block)
               elsif object
                 bind_callable(name_or_class, object)
               else
                 bind_class(name_or_class)
               end
      @binders << binder
    end

    def bindings(context = nil)
      Bindings.new(@binders.collect do |binder|
        binder.call(context)
      end.flatten)
    end

  private

    def bind_callable(name, callable)
      Proc.new { |context| [BoundFunction.new(name, callable)] }
    end

    def bind_class(implementation)
      Proc.new do |context|
        instance = implementation.new(context)
        instance.methods.collect do |method_name|
          BoundFunction.new(method_name, instance.method(method_name))
        end.flatten
      end
    end

    # @api public
    class Bindings
      def initialize(bindings)
        @bindings = {}
        bindings.each do |binding|
          @bindings[binding.name] = binding
        end
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
