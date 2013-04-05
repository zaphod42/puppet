Puppet::Parser::Functions::newfunction(
:reject,
:type => :rvalue,
:arity => 2,
:doc => <<-'ENDHEREDOC') do |args|
  Applies a parameterized block to each element in a sequence of entries from the first
  argument and returns an array with the entires for which the block did *not* evaluate to true.

  This function takes two mandatory arguments: the first should be an Array or a Hash, and the second
  a parameterized block as produced by the puppet syntax:

    $a.reject |$x| { ... }

  When the first argument is an Array, the block is called with each entry in turn. When the first argument
  is a hash the entry is an array with `[key, value]`.

  *Examples*

    # selects all that does not end with berry
    $a = ["rasberry", "blueberry", "orange"]
    $a.reject |$x| { $x =~ /berry$/ }

  Since 3.2
  ENDHEREDOC

  require 'puppet/parser/ast/lambda'
  raise ArgumentError, ("reject(): wrong number of arguments (#{args.length}; must be 2)") if args.length != 2
  receiver = args[0]
  pblock = args[1]
  raise ArgumentError, ("reject(): wrong argument type (#{args[1].class}; must be a parameterized block.") unless pblock.is_a? Puppet::Parser::AST::Lambda
  case receiver
  when Array
  when Hash
  else
    raise ArgumentError, ("reject(): wrong argument type (#{args[0].class}; must be an Array or a Hash.")
  end

  receiver.reject {|x| pblock.call(self, x) }
end
