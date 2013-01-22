#
#= The Puppet Pops Metamodel
#
# This module contains a formal description of the Puppet Pops (Puppet OPeration instructionS).
# It describes a Metamodel containing DSL instructions, a description of PuppetType and related
# classes needed to evaluate puppet logic.
# The metamodel resembles the existing AST model, but it is a semantic model of instructions and
# the types that they operate on rather than a Abstract Syntax Tree, although closely related.
#
# The metamodel is anemic (has no behavior) except basic datatype and type
# assertions and reference/containment assertions.
# The metamodel is also a generalized description of the Puppet DSL to enable the
# same metamodel to be used to express Puppet DSL models (instances) with different semantics as
# the language evolves.
#
# The metamodel is concretized by a validator for a particular version of
# the Puppet DSL language.
#
# This metamodel is expressed using RGen.
#
# TODO: Names vs FullyQualifiedName - now they are all just String
# TODO: Hash Datatype ?
# TODO: Anonymous Enums - probably ok, but they can be named (don't know if that is meaningsful)
# TODO: Source Location - either have reference in objects, or separate model / map, tie them in a "Resource"
# TODO: is it better to have a String instead of Expression for key in KeyedEntry
# TODO: Terms for parameters, arguments, and attributes are all over the place

require 'rgen/metamodel_builder'
require 'puppet/pops/api'
module Puppet; module Pops; module API; module Model
  # A base class for modeled objects that makes them Visitable, and Adaptable.
  # @todo currently  includes Containment which will not be needed when the corresponding methods
  #   are added to RGen.
  #
  class PopsObject < RGen::MetamodelBuilder::MMBase
    include Puppet::Pops::Visitable
    include Puppet::Pops::Adaptable
    include Puppet::Pops::Containment 
    abstract
  end

  # @abstract base class for expressions
  class Expression < PopsObject
    abstract
  end

  # A Nop - the "no op" expression.
  # @note not really needed since the evaluator can evaluate nil with the meaning of NoOp
  # @todo deprecate?
  # This is *bold*, and `teletype` and _italic_ in RDoc
  #
  # # Heading 1
  # this is text below heading
  # ## Heading 2
  # Compared against 3x
  #--
  # Corresponds to `Nop`
  #
  class Nop < Expression
  end

  # A binary expression is abstract and has a left and a right expression. The order of evaluation
  # and semantics are determined by the concrete subclass.
  #
  # Compared against 3x
  #--
  # Does not correspond to something existing.
  #
  class BinaryExpression < Expression
    abstract
    #
    # @!attribute [rw] left_expr
    #   @return [Expression]
    contains_one_uni 'left_expr', Expression, :lowerBound => 1
    contains_one_uni 'right_expr', Expression, :lowerBound => 1
  end

  # An unary expression is abstract and contains one expression. The semantics are determined by
  # a concrete subclass.
  #--
  # Does not correspond to something existing.
  #
  class UnaryExpression < Expression
    abstract
    contains_one_uni 'expr', Expression, :lowerBound => 1
  end

  # A boolean not expression, reversing the truth of the unary expr.
  #--
  # Corresponds to Not
  #
  class NotExpression < UnaryExpression; end

  # An arithmetic expression reversing the polarity of the numeric unary expr.
  #--
  # Corresponds to MinusOperator
  #
  class UnaryMinusExpression < UnaryExpression; end

  # An assignment expression assigns a value to the lval() of the left_expr.
  #--
  # Corresponds somewhat to Vardef, but is generic
  #
  class AssignmentExpression < BinaryExpression
    has_attr 'operator', RGen::MetamodelBuilder::DataTypes::Enum.new([:'=', :'+=']), :lowerBound => 1
  end

  # An arithmetic expression applies an arithmetic operator on left and right expressions.
  #--
  # Corresponds to : ArithmeticOperator
  #
  class ArithmeticExpression < BinaryExpression
    has_attr 'operator', RGen::MetamodelBuilder::DataTypes::Enum.new([:'+', :'-', :'*', :'/', :'<<', :'>>' ]), :lowerBound => 1
  end

  # A relationship expression associates the left and right expressions
  #--
  # Corresponds to : Relationship
  #
  class RelationshipExpression < BinaryExpression
    has_attr 'operator', RGen::MetamodelBuilder::DataTypes::Enum.new([:'->', :'<-', :'~>', :'<~']), :lowerBound => 1
  end

  # A binary expression, that accesses the value denoted by right in left. i.e. typically
  # expressed concretely in a language as left[right].
  #--
  # Corresponds to HashOrArrayAccess
  #
  class AccessExpression < BinaryExpression; end


  # A comparison expression compares left and right using a comparison operator.
  #--
  # Corresponds to : ComparisonOperator
  #
  class ComparisonExpression < BinaryExpression
    has_attr 'operator', RGen::MetamodelBuilder::DataTypes::Enum.new([:'==', :'!=', :'<', :'>', :'<=', :'>=' ]), :lowerBound => 1
  end

  # A match expression matches left and right using a matching operator.
  #--
  # Corresponds to : MatchOperator
  #
  class MatchExpression < BinaryExpression
    has_attr 'operator', RGen::MetamodelBuilder::DataTypes::Enum.new([:'!~', :'=~']), :lowerBound => 1
  end

  # An 'in' expression checks if left is 'in' right
  #--
  # Corresponds to InOperator
  #
  class InExpression < BinaryExpression; end

  # A boolean expression applies a logical connective operator (and, or) to left and right expressions.
  #--
  # Corresponds to BooleanOperator
  #
  class BooleanExpression < BinaryExpression
    abstract
  end
  
  # An and expression applies the logical connective operator and to left and right expression
  # and does not evaluate the right expression if the left expression is false.
  class AndExpression < BooleanExpression
  end
  
  # An or expression applies the logical connective operator or to the left and right expression
  # and does not evaluate the right expression if the left expression is true
  class OrExpression < BooleanExpression
  end
  
  # A literal list / array containing 0:M expressions.
  #--
  # Corresponds to ASTArray
  #
  class LiteralList < Expression
    contains_many_uni 'values', Expression
  end

  # A Keyed entry has a key and a value expression. It it typically used as an entry in a Hash.
  #--
  # No corresponding definition
  #
  class KeyedEntry < PopsObject
    contains_one_uni 'key', Expression, :lowerBound => 1
    contains_one_uni 'value', Expression, :lowerBound => 1
  end

  # A literal hash is a collection of KeyedEntry objects
  #--
  # Corresponds to ASTHash
  #
  class LiteralHash < Expression
    contains_many_uni 'entries', KeyedEntry
  end

  # A block contains a list of expressions
  #--
  # Has no direct corresponding class, concept spread over several
  #
  class BlockExpression < Expression
    contains_many_uni 'statements', Expression
  end
  
  # A case option entry in a CaseStatement
  #--
  # Corresponds to CaseOpt
  #
  class CaseOption < Expression
    contains_many_uni 'values', Expression, :lowerBound => 1
    contains_one_uni 'then_expr', Expression, :lowerBound => 1
  end

  # A case expression has a test, a list of options (multi values => block map).
  # One CaseOption may contain a LiteralDefault as value. This option will be picked if nothing
  # else matched.  
  #--
  # Corresponds to CaseStatement
  #
  class CaseExpression < Expression
    contains_one_uni 'test', Expression, :lowerBound => 1
    contains_many_uni 'options', CaseOption
  end

  # A query expression is an expression that is applied to some collection.
  # The contained expression may contain different types of relational expressions depending
  # on what the query is applied to.
  #--
  # Corresponds to internal objects/logic in CollExpr
  #
  class QueryExpression < UnaryExpression
    abstract
  end

  # An exported query is a special form of query that searches for exported objects.
  #--
  # Corresponds to form :exported in a CollExpr
  #
  class ExportedQuery < QueryExpression
  end

  # A virtual query is a special form of query that searches for virtual objects.
  #--
  # Corresponds to form :virtual in a CollExpr
  #
  class VirtualQuery < QueryExpression
  end

  # An attribute operation sets or appends a value to a named attribute.
  #--
  # Corresponds to property operations in CollExpr
  #
  class AttributeOperation < PopsObject
    has_attr 'attribute_name', String, :lowerBound => 1
    has_attr 'operator', RGen::MetamodelBuilder::DataTypes::Enum.new([:'=>', :'+>', ]), :lowerBound => 1
    contains_one_uni 'value_expr', Expression, :lowerBound => 1
  end
  
  # An optional attribute operation sets or appends a value to a named attribute unless
  # the value is undef/nil in which case the opereration is a Nop.
  #..
  # This is a new feature proposed to solve the undef as antimatter problem
  class OptionalAttributeOperation < AttributeOperation
  end
  
  # An object that collects stored objects from the central cache and returns
  # them to the current host. Operations may optionally be applied.
  #--
  # Corresponds to Collection
  #
  class CollectExpression < Expression
    contains_one_uni 'type_expr', Expression, :lowerBound => 1
    contains_one_uni 'query', QueryExpression, :lowerBound => 1
    contains_many_uni 'operations', AttributeOperation
  end

  class Parameter < PopsObject
    has_attr 'name', String, :lowerBound => 1
    contains_one_uni 'value', Expression
  end

  # Abstract base class for definitions
  #--
  # Does not have a corresponding class - is implemented twice (in Definition and Class)
  #
  class Definition < Expression
    abstract
    contains_many_uni 'parameters', Parameter
    contains_one_uni 'body', Expression
  end

  class NamedDefinition < Definition
    abstract
    has_attr 'name', String, :lowerBound => 1
  end

  # A resource type definition
  #--
  # Corresponds to Definition
  #
  class ResourceTypeDefinition < NamedDefinition
    # FUTURE
    # contains_one_uni 'producer', Producer
  end

  # A node definition matches hosts using Strings, or Regular expressions. It may inherit from
  # a parent node (also using a String or Regular expression).
  #--
  # Corresponds to Node
  #
  class NodeDefinition < Expression
    contains_one_uni 'parent', Expression
    contains_many_uni 'host_matches', Expression, :lowerBound => 1
    contains_one_uni 'body', Expression
  end

  # A class definition
  #--
  # Corresponds to HostClass
  #
  class HostClassDefinition < NamedDefinition
    has_attr 'parent_class', String
  end

  # i.e {|paramters| body }
  class LambdaExpression < Definition
  end

  # If expression. If test is true, the then_expr part should be evaluated, else the (optional)
  # else_expr. An 'elsif' is simply an else_expr = IfExpression, and 'else' is simply else == Block.
  # a 'then' is typically a Block.
  # ---
  # Corresponds to IfStatement, and Else, ElseIf
  class IfExpression < Expression
    contains_one_uni 'test', Expression, :lowerBound => 1
    contains_one_uni 'then_expr', Expression, :lowerBound => 1
    contains_one_uni 'else_expr', Expression
  end

  # An if expression with reverse test
  class UnlessExpression < IfExpression
  end
  
  class CallExpression < Expression
    abstract
    # A bit of a crutch; functions are either procedures (void return) or has an rvalue
    # this flag tells the evaluator that it is a failure to call a function that is void/procedure
    # where a value is expected.
    #
    has_attr 'rval_required', Boolean, :defaultValueLiteral => "false"
    contains_one_uni 'functor_expr', Expression, :lowerBound => 1
    contains_many_uni 'arguments', Expression
  end

  # A function call where the functor_expr should evaluate to something callable.
  class CallFunctionExpression < CallExpression
  end

  # A function call where the given functor_expr should evaluate to the name
  # of a function.
  #--
  # Corresponds to Function
  class CallNamedFunctionExpression < CallExpression
  end

  # A method/function call where the function expr is a NamedAccess and with support for
  # an optional lambda block
  #
  class CallMethodExpression < CallExpression
    contains_one_uni 'lambda', Expression  
  end
  # Abstract base class for literals.
  #
  class Literal < Expression
    abstract
  end

  # A literal value is an abstract value holder. The type of the contained value is
  # determined by the concrete subclass.
  #--
  # Corresponds somewhat to Leaf which has value and type
  class LiteralValue < Expression
    abstract
    has_attr 'value', Object, :lowerBound => 1
  end

  class LiteralRegularExpression < LiteralValue; end
  class LiteralString < LiteralValue; end
    
  # A literal text is like a literal string, but has other rules for escaped characters. It
  # is used as part of a ConcatenatedString
  class LiteralText < LiteralValue; end
  
  # A litral number has a radix of decimal (10), octal (8), or hex (16) to enable output in the same for as it was entered.
  # By default, a radix of 10 is used.    
  class LiteralNumber < LiteralValue
    has_attr 'radix', Integer, :lowerBound => 1, :defaultValueLiteral => "10"
  end
  class LiteralUndef < Literal; end
  class LiteralDefault < Literal; end
  class LiteralBoolean < LiteralValue; end

  # A text expression is an interpolation of an expression. If the embedded expression is
  # a Qualified name, it it taken as a variable name and resolved. All other expressions are evaluated.
  # The result is transformed to a string.
  #--
  # This corresponds to the current Concat having a list of object, strings, expressions
  #
  class TextExpression < UnaryExpression
  end

  # An interpolated/concatenated string. The contained segments are expressions. Verbatim sections
  # should be LiteralString instances, and interpolated expressions should either be
  # TextExpression instances (if QualifiedNames should be turned into variables), or any other expression
  # if such treatment is not needed.
  #--
  # Corresponds to Concat
  #
  class ConcatenatedString < Expression
    contains_many_uni 'segments', Expression
  end

  #--
  # Corresponds to Lexer's NAME
  #
  class QualifiedName < LiteralValue; end

  #--
  # Corresponds to lexer's CLASSREF token
  #
  class QualifiedReference < LiteralValue; end

  # A Variable expression looks up value of expr (some kind of name) in scope.
  # The expression is typically a QualifiedName, or QualifiedReference.
  #--
  # This corresponds to the Leaf called Variable
  #
  class VariableExpression < UnaryExpression; end

  # A type reference is a reference to a type.
  #--
  # Does not correspond to something existing
  #
  class TypeReference < Expression
    contains_one_uni 'type_name', QualifiedReference, :lowerBound => 1
  end

  # An instance reference is a reference to one or many named instances of a particular type
  #--
  # This corresponds to TypeReference
  #
  class InstanceReferences < TypeReference
    contains_many_uni 'names', Expression, :lowerBound => 1
  end

  # A resource body describes one resource instance
  #--
  # Corresponds to ResourceInstance (renamed because this is a description, not an instance)
  #
  class ResourceBody < PopsObject
    contains_one_uni 'title', Expression
    contains_many_uni 'operations', AttributeOperation
  end

  # An abstract resource describes the form of the resource (regular, virtual or exported)
  # and adds convenience methods to ask if it is virtual or exported.
  # All derived classes may not support all forms, and these needs to be validated
  #
  class AbstractResource < Expression
    has_attr 'form', RGen::MetamodelBuilder::DataTypes::Enum.new([:regular, :virtual, :exported ]), :lowerBound => 1, :defaultValueLiteral => "regular"
    has_attr 'virtual', Boolean, :derived => true
    has_attr 'exported', Boolean, :derived => true
    module ClassModule
      def virtual_derived
        form == :virtual || form == :exported
      end
      def exported_derived
        form == :exported 
      end
    end

  end
  # A resource expression is used to instantiate one or many resource. Resources may optionally
  # be virtual or exported, an exported resource is always virtual.
  #--
  # Corresponds to Resource
  #
  class ResourceExpression < AbstractResource
    contains_one_uni 'type_name', Expression, :lowerBound => 1
    contains_many_uni 'bodies', ResourceBody
  end

  # A resource defaults sets defaults for a resource type. This class inherits from AbstractResource
  # but does only support the :regular form (this is intentional to be able to produce better error messages
  # when illegal forms are applied to a model.
  # TODO: parameters is a bad name for attribute operations / arguments
  #--
  # Corresponds to ResourceDefaults
  #
  class ResourceDefaultsExpression < AbstractResource
    contains_one_uni 'type_ref', QualifiedReference
    contains_many_uni 'operations', AttributeOperation
  end

  # A resource override overrides already set values.
  #--
  # Corresponds to ResourceOverride
  #
  class ResourceOverrideExpression < Expression
    contains_one_uni 'resources', InstanceReferences
    contains_many_uni 'operations', AttributeOperation
  end

  # A selector entry describes a map from matching_expr to value_expr.
  #--
  # Corresponds to internal handling in Selector
  #
  class SelectorEntry < PopsObject
    contains_one_uni 'matching_expr', Expression, :lowerBound => 1
    contains_one_uni 'value_expr', Expression, :lowerBound => 1
  end

  # A selector expression represents a mapping from a left_expr to a matching SelectorEntry.
  #--
  # Corresponds to Selector
  #
  class SelectorExpression < Expression
    contains_one_uni 'left_expr', Expression, :lowerBound => 1
    contains_many_uni 'selectors', SelectorEntry
  end

  class CreateInvariantExpression < Expression
    has_attr 'name', String
    contains_one_uni 'message_expr', Expression, :lowerBound => 1
    contains_one_uni 'constraint_expr', Expression, :lowerBound => 1
  end

  class CreateAttributeExpression < Expression
    has_attr 'name', String, :lowerBound => 1
    
    # Should evaluate to name of datatype (String, Integer, Float, Boolean) or an EEnum metadata
    # (created by CreateEnumExpression). If omitted, the type is a String.
    #
    contains_one_uni 'type', Expression 
    contains_one_uni 'min_expr', Expression
    contains_one_uni 'max_expr', Expression
    contains_one_uni 'default_value', Expression
    contains_one_uni 'input_transformer', Expression
    contains_one_uni 'derived_expr', Expression
  end
  
  class CreateEnumExpression < Expression
    has_attr 'name', String
    contains_one_uni 'values', Expression
  end
  
  class CreateTypeExpression < Expression
    has_attr 'name', String, :lowerBound => 1
    has_attr 'super_name', String
    contains_many_uni 'attributes', CreateAttributeExpression
    contains_many_uni 'invariants', CreateInvariantExpression 
  end
    
  class CreateResourceType < CreateTypeExpression
    # TODO CreateResourceType
    # - has features required by the provider - provider invariant?
    # - super type must be a ResourceType
  end
  
  # A named access expression looks up a named part. (e.g. $a.b)
  #--
  # This is currently not supported in Puppet 3.x
  #
  class NamedAccessExpression < BinaryExpression; end

  # A named function definition declares and defines a new function
  class NamedFunctionDefinition < NamedDefinition; end
    
  # A function definition defines an unnamed function (lambda).
  class FunctionExpression < Definition; end

  module Injection
    # A producer expression produces an instance of a type. The instance is initialized
    # from an expression (or from the current scope if this expression is missing).
    #--
    # new. to handle production of injections
    #
    class Producer < Expression
      contains_one_uni 'type_name', TypeReference, :lowerBound => 1
      contains_one_uni 'instantiation_expr', Expression
    end

    # A binding entry binds one capability generically or named, specifies default bindings or
    # composition of other bindings.
    #
    class BindingEntry < PopsObject
      contains_one_uni 'key', Expression
      contains_one_uni 'value', Expression
    end

    # Defines an optionally named binding.
    #
    class Binding < Expression
      contains_one_uni 'title_expr', Expression
      contains_many_uni 'bindings', BindingEntry
    end


    # An injection provides a value bound in the effective binding scope. The injection
    # is based on a type (a capability) and an optional list of instance names (i.e. an InstanceReference).
    # Invariants: optional and instantiation are mutually exclusive
    #
    class InjectExpression < Expression
      has_attr 'optional', Boolean
      contains_one_uni 'binding', Expression, :lowerBound => 1
      contains_one_uni 'instantiation', Expression
    end
  end
end; end; end; end