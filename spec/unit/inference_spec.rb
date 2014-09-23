require 'spec_helper'
require 'puppet/pops'

describe 'Type Inference' do
  {
    "undef" => "Undef",

    "1" => "Integer",
    "1.0" => "Float",
    "0xf" => "Integer",

    "'string'" => "String",
    "string" => "String",
    "\"string\"" => "String",

    "$a =~ /re/" => "Boolean",

    "$a and $b" => "Boolean",
    "$a or $b" => "Boolean",

    "1 + 1" => "Integer",
    "1 * 1" => "Integer",
    "1 / 1" => "Integer",
    "1 / 2.0" => "Float",
    "1 + 1.0" => "Float",
    "1.0 + 1" => "Float",

    "{}" => "Hash",
    "{ 1 => 1 }" => "Hash[Integer, Integer]",
    "{ 1 => 1, 2 => 2 }" => "Hash[Integer, Integer]",
    "{ 1 => 1, 2.0 => 2.0 }" => "Hash[Variant[Integer, Float], Variant[Integer, Float]]",
    "{ 1 => 1, a => {} }" => "Hash[Variant[Integer, String], Variant[Integer, Hash]]",

    "[]" => "Array",
    "[1]" => "Array[Integer]",

    "$var = 1" => "Integer",
    "if $b { 1 } else { 2 }" => "Integer",
    "if $b { 1 }" => "Variant[Integer, Undef]",

    "1; 'string'" => "String",
    "$var = 1; $var" => "Integer",
    "$h = { a => 1 }; $h[$x]" => "Optional[Integer]",
    "$h = { a => { b => 2.0 } }; $h[$x][$y]" => "Optional[Float]",

    "$a = [1]; $a[$x]" => "Optional[Integer]",
    "$a = [[1]]; $a[$x][$y]" => "Optional[Integer]",

    "notify { hi: }" => "Resource[Notify]"
  }.each do |example, expectation|
    it "infers <#{example}> to have type #{expectation}" do
      expect(example).to infer_type(expectation)
    end
  end

  class TypeInferer
    def initialize
      @infer_visitor = Puppet::Pops::Visitor.new(self, "infer", 0, 0)
      @type_factory = Puppet::Pops::Types::TypeFactory
      @type_calculator = Puppet::Pops::Types::TypeCalculator
      @variables = {}
    end

    def infer(ast)
      @infer_visitor.visit(ast)
    end

    def infer_Program(ast)
      @infer_visitor.visit(ast.body)
    end

    def infer_BlockExpression(ast)
      ast.statements.collect do |statement|
        infer(statement)
      end.last
    end

    def infer_LiteralUndef(ast)
      @type_factory.undef
    end

    def infer_LiteralInteger(ast)
      @type_factory.integer
    end

    def infer_LiteralFloat(ast)
      @type_factory.float
    end

    def infer_LiteralString(ast)
      @type_factory.string
    end

    def infer_QualifiedName(ast)
      @type_factory.string
    end

    def infer_LiteralHash(ast)
      entry_types = ast.entries.collect do |entry|
        [infer(entry.key), infer(entry.value)]
      end

      if entry_types.empty?
        @type_factory.hash_of_data
      else
        @type_factory.hash_of(union_type(entry_types.collect(&:last)),
                              union_type(entry_types.collect(&:first)))
      end
    end

    def infer_LiteralList(ast)
      value_types = ast.values.collect(&method(:infer))

      if value_types.empty?
        @type_factory.array_of_data
      else
        @type_factory.array_of(union_type(value_types))
      end
    end

    def infer_ArithmeticExpression(ast)
      left = infer(ast.left_expr)
      right = infer(ast.right_expr)

      if left == @type_factory.float || right == @type_factory.float
        @type_factory.float
      else
        @type_factory.integer
      end
    end

    def infer_AssignmentExpression(ast)
      type = infer(ast.right_expr)
      @variables[ast.left_expr.expr.value] = type
      type
    end

    def infer_IfExpression(ast)
      covering_type(infer(ast.then_expr), infer(ast.else_expr))
    end

    def infer_VariableExpression(ast)
      name = ast.expr.value
      if @variables.include?(name)
        @variables[name]
      else
        @type_factory.undef
      end
    end

    def infer_MatchExpression(ast)
      infer(ast.left_expr) # assert String
      infer(ast.right_expr) # assert Pattern
      @type_factory.boolean
    end

    def infer_OrExpression(ast)
      infer(ast.left_expr) # assert?
      infer(ast.right_expr) # assert?
      @type_factory.boolean
    end

    def infer_AndExpression(ast)
      infer(ast.left_expr) # assert?
      infer(ast.right_expr) # assert?
      @type_factory.boolean
    end

    def infer_LiteralRegularExpression(ast)
      @type_factory.regexp
    end

    def infer_AccessExpression(ast)
      left = infer(ast.left_expr)
      unpacked = if left.is_a?(Puppet::Pops::Types::POptionalType)
                   # WARNING!!!! Possible undef dereference
                   left.optional_type.element_type
                 else
                   left.element_type
                 end
      @type_factory.optional(unpacked)
    end

    def infer_ResourceExpression(ast)
      @type_factory.resource(ast.type_name.value)
    end

    def infer_Nop(ast)
      @type_factory.undef
    end

    # Given a set of types return the most restrictive type that will allow all
    # of the given types.
    def union_type(types)
      types.inject do |a, b|
        covering_type(a, b)
      end
    end

    # Return the most restrictive type that allows both given types
    def covering_type(a, b)
      if @type_calculator.assignable?(a, b)
        a
      elsif @type_calculator.assignable?(b, a)
        b
      else
        @type_factory.variant(a, b)
      end
    end
  end

  RSpec::Matchers.define :infer_type do |expected|
    match do |actual|
      type_parser = Puppet::Pops::Types::TypeParser.new
      parser = Puppet::Pops::Parser::Parser.new()
      type_inferer = TypeInferer.new

      ast = parser.parse_string(actual)
      @inferred_type = type_inferer.infer(ast.model)
      @inferred_type == type_parser.parse(expected)
    end

    failure_message_for_should do |actual|
      "expected to infer <#{actual}> to have type #{expected}, but got #{@inferred_type}"

    end
  end
end
