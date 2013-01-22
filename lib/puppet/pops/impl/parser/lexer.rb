# the scanner/lexer

require 'forwardable'
require 'strscan'
require 'puppet'
require 'puppet/util/methodhelper'

module Puppet
  class LexError < RuntimeError; end
end

module Puppet::Pops::Impl::Parser; end

class Puppet::Pops::Impl::Parser::Lexer
  extend Forwardable

  attr_reader :last, :file, :lexing_context, :token_queue

  attr_accessor :line, :indefine
  alias :indefine? :indefine

  def lex_error msg
    raise Puppet::LexError.new(msg)
  end

  class Token
    include Puppet::Util::MethodHelper

    attr_accessor :regex, :name, :string, :skip, :incr_line, :skip_text, :accumulate
    alias skip? skip
    alias accumulate? accumulate

    # @param string_or_regex[String] a literal string token matcher
    # @param string_or_regex[Regexp] a regular expression token text matcher
    # @param name [String] the token name (what it is known as in the grammar)
    # @param options [Hash] see {#set_options}
    #
    def initialize(string_or_regex, name, options = {})
      if string_or_regex.is_a?(String)
        @name, @string = name, string_or_regex
        @regex = Regexp.new(Regexp.escape(string_or_regex))
      else
        @name, @regex = name, string_or_regex
      end

      set_options(options)
    end

    # @return [String] human readable token reference; the String if literal, else the token name
    def to_s
      string or @name.to_s
    end

    # @return [Boolean] if the token is acceptable in the given context or not.
    #   this implementation always returns true.
    # @param context [Hash] ? ? ? 
    #
    def acceptable?(context={})
      # By default tokens are acceptable in any context
      true
    end
    
    def assert_numeric(value)
      if value =~ /^0[xX].*$/ 
          lex_error "Not a valid hex number #{value}" unless value =~ /^0[xX][0-9A-Fa-f]+$/
      elsif value =~ /^0[^.].*$/ 
        lex_error "Not a valid octal number #{value}" unless value =~ /^0[0-7]+$/
      else 
        lex_error "Not a valid decimal number #{value}" unless value =~ /0?\d+(?:\.\d+)?(?:[eE]-?\d+)?/
      end
    end

  end

  # Maintains a list of tokens.
  class TokenList
    extend Forwardable

    attr_reader :regex_tokens, :string_tokens
    def_delegator :@tokens, :[]

    # Adds a new token to the set of regognized tokens
    # @param name [String] the token name
    # @param regex [Regexp, String] source text token matcher, a litral string or regular expression
    # @param options [Hash] see {Token::set_options}
    # @param block [Proc] optional block set as the created tokens `convert` method
    # @raise [ArgumentError] if the token with the given name is already defined
    #
    def add_token(name, regex, options = {}, &block)
      raise(ArgumentError, "Token #{name} already exists") if @tokens.include?(name)
      token = Token.new(regex, name, options)
      @tokens[token.name] = token
      if token.string
        @string_tokens << token
        @tokens_by_string[token.string] = token
      else
        @regex_tokens << token
      end

      token.meta_def(:convert, &block) if block_given?

      token
    end

    # Creates an empty token list
    #
    def initialize
      @tokens = {}
      @regex_tokens = []
      @string_tokens = []
      @tokens_by_string = {}
    end

    # Look up a token by its literal (match) value, rather than name.
    # @param string [String, nil] the literal match string to obtain a {Token} for, or nil if it does not exist.
    def lookup(string)
      @tokens_by_string[string]
    end

    # Adds tokens from a hash where key is a matcher (literal string or regexp) and the
    # value is the token's name
    # @param hash [Hash<{String => Symbol}, Hash<{Regexp => Symbol}] map token text matcher to token name
    # @return [void]
    #
    def add_tokens(hash)
      hash.each do |regex, name|
        add_token(name, regex)
      end
    end

    # Sort literal (string-) tokens by length, so we know once we match, we're done.
    # This helps avoid the O(n^2) nature of token matching.
    # The tokens are sorted in place.
    # @return [void]
    def sort_tokens
      @string_tokens.sort! { |a, b| b.string.length <=> a.string.length }
    end
  end

  TOKENS = TokenList.new
  TOKENS.add_tokens(
    '['   => :LBRACK,
    ']'   => :RBRACK,
#    '{'   => :LBRACE, # Specialized to handle lambda
    '}'   => :RBRACE,
    '('   => :LPAREN,
    ')'   => :RPAREN,
    '='   => :EQUALS,
    '+='  => :APPENDS,
    '=='  => :ISEQUAL,
    '>='  => :GREATEREQUAL,
    '>'   => :GREATERTHAN,
    '<'   => :LESSTHAN,
    '<='  => :LESSEQUAL,
    '!='  => :NOTEQUAL,
    '!'   => :NOT,
    ','   => :COMMA,
    '.'   => :DOT,
    ':'   => :COLON,
    '@'   => :AT,
    '|'   => :PIPE,
    '<<|' => :LLCOLLECT,
    '|>>' => :RRCOLLECT,
    '->'  => :IN_EDGE,
    '<-'  => :OUT_EDGE,
    '~>'  => :IN_EDGE_SUB,
    '<~'  => :OUT_EDGE_SUB,
    '<|'  => :LCOLLECT,
    '|>'  => :RCOLLECT,
    ';'   => :SEMIC,
    '?'   => :QMARK,
    '\\'  => :BACKSLASH,
    '=>'  => :FARROW,
    '+>'  => :PARROW,
    '+'   => :PLUS,
    '-'   => :MINUS,
    '/'   => :DIV,
    '*'   => :TIMES,
    '<<'  => :LSHIFT,
    '>>'  => :RSHIFT,
    '=~'  => :MATCH,
    '!~'  => :NOMATCH,
    %r{((::){0,1}[A-Z][-\w]*)+} => :CLASSREF,
    "<string>" => :STRING,
    "<dqstring up to first interpolation>" => :DQPRE,
    "<dqstring between two interpolations>" => :DQMID,
    "<dqstring after final interpolation>" => :DQPOST,
    "<boolean>" => :BOOLEAN,
    "<lambda start>" => :LAMBDA # A LBRACE followed by '|'
  )

  # LBRACE needs look ahead to differentiate between '{' and a '{' followed by a '|' (start of lambda)
  # The racc grammar can only do one token lookahead.
  #
  TOKENS.add_token :LBRACE, /\{/ do | lexer, value |
    if lexer.match?(/[ \t\r]*\|/)
      [TOKENS[:LAMBDA], value]
    else    
      [TOKENS[:LBRACE], value]
    end
  end
  
  #:stopdoc: # Issue #4161 - this method declaration made RDoc have a hissy fit in year 2000
  # Numbers are treated separately from names, so that they may contain dots.
  TOKENS.add_token :NUMBER, %r{\b(?:0[xX][0-9A-Fa-f]+|0?\d+(?:\.\d+)?(?:[eE]-?\d+)?)\b} do |lexer, value|
    assert_numeric(value)
    [TOKENS[:NAME], value]
  end
  #:startdoc:
  
  #:stopdoc: # Issue #4161 - this method declaration made RDoc have a hissy fit in year 2000
  def (TOKENS[:NUMBER]).acceptable?(context={})
    ![:DQPRE,:DQMID].include? context[:after]
  end
  #:startdoc:

  TOKENS.add_token :NAME, %r{((::)?[a-z0-9][-\w]*)(::[a-z0-9][-\w]*)*} do |lexer, value|
    # A name starting with a number must be a valid numeric string (not that
    # NUMBER token captures those names that do not comply with the name rule.
    if value =~ /^[0-9].*$/ 
      lexer.assert_numeric(value)
    end
    
    string_token = self
    # we're looking for keywords here
    if tmp = KEYWORDS.lookup(value)
      string_token = tmp
      if [:TRUE, :FALSE].include?(string_token.name)
        value = eval(value)
        string_token = TOKENS[:BOOLEAN]
      end
    end
    [string_token, value]
  end
  [:NAME,:CLASSNAME,:CLASSREF].each { |name_token|
    #:stopdoc: # Issue #4161
    def (TOKENS[name_token]).acceptable?(context={})
      ![:DQPRE,:DQMID].include? context[:after]
    end
    #:startdoc:
  }

  TOKENS.add_token :COMMENT, %r{#.*}, :accumulate => true, :skip => true do |lexer,value|
    value.sub!(/# ?/,'')
    [self, value]
  end

  TOKENS.add_token :MLCOMMENT, %r{/\*(.*?)\*/}m, :accumulate => true, :skip => true do |lexer, value|
    lexer.line += value.count("\n")
    value.sub!(/^\/\* ?/,'')
    value.sub!(/ ?\*\/$/,'')
    [self,value]
  end

  TOKENS.add_token :REGEX, %r{/[^/\n]*/} do |lexer, value|
    # Make sure we haven't matched an escaped /
    while value[-2..-2] == '\\'
      other = lexer.scan_until(%r{/})
      value += other
    end
    regex = value.sub(%r{\A/}, "").sub(%r{/\Z}, '').gsub("\\/", "/")
    [self, Regexp.new(regex)]
  end

  #:stopdoc: # Issue #4161
  def (TOKENS[:REGEX]).acceptable?(context={})
    [:NODE,:LBRACE,:RBRACE,:MATCH,:NOMATCH,:COMMA].include? context[:after]
  end
  #:startdoc:

  TOKENS.add_token :RETURN, "\n", :skip => true, :incr_line => true, :skip_text => true

  TOKENS.add_token :SQUOTE, "'" do |lexer, value|
    [TOKENS[:STRING], lexer.slurpstring(value,["'"],:ignore_invalid_escapes).first ]
  end

  DQ_initial_token_types      = {'$' => :DQPRE,'"' => :STRING}
  DQ_continuation_token_types = {'$' => :DQMID,'"' => :DQPOST}

  TOKENS.add_token :DQUOTE, /"/ do |lexer, value|
    lexer.tokenize_interpolated_string(DQ_initial_token_types)
  end

  TOKENS.add_token :DQCONT, /\}/ do |lexer, value|
    lexer.tokenize_interpolated_string(DQ_continuation_token_types)
  end
  #:stopdoc: # Issue #4161
  def (TOKENS[:DQCONT]).acceptable?(context={})
    context[:string_interpolation_depth] > 0
  end
  #:startdoc:

  TOKENS.add_token :DOLLAR_VAR, %r{\$(::)?(\w+::)*\w+} do |lexer, value|
    [TOKENS[:VARIABLE],value[1..-1]]
  end

  TOKENS.add_token :VARIABLE, %r{(::)?(\w+::)*\w+}
  #:stopdoc: # Issue #4161
  def (TOKENS[:VARIABLE]).acceptable?(context={})
    [:DQPRE,:DQMID].include? context[:after]
  end
  #:startdoc:


  TOKENS.sort_tokens

  @@pairs = {
    "{"   => "}",
    "("   => ")",
    "["   => "]",
    "<|"  => "|>",
    "<<|" => "|>>"
  }

  KEYWORDS = TokenList.new
  KEYWORDS.add_tokens(
    "case"     => :CASE,
    "class"    => :CLASS,
    "default"  => :DEFAULT,
    "define"   => :DEFINE,
    "import"   => :IMPORT,
    "if"       => :IF,
    "elsif"    => :ELSIF,
    "else"     => :ELSE,
    "inherits" => :INHERITS,
    "node"     => :NODE,
    "and"      => :AND,
    "or"       => :OR,
    "undef"    => :UNDEF,
    "false"    => :FALSE,
    "true"     => :TRUE,
    "in"       => :IN,
    "unless"   => :UNLESS
  )

  def clear
    initvars
  end

  def expected
    return nil if @expected.empty?
    name = @expected[-1]
    TOKENS.lookup(name) or lex_error "Could not find expected token #{name}"
  end

  # scan the whole file
  # basically just used for testing
  def fullscan
    array = []

    self.scan { |token, str|
      # Ignore any definition nesting problems
      @indefine = false
      array.push([token,str])
    }
    array
  end

  def file=(file)
    @file = file
    @line = 1
    contents = File.exists?(file) ? File.read(file) : ""
    @scanner = StringScanner.new(contents)
  end

  def_delegator :@token_queue, :shift, :shift_token

  def find_string_token
    # We know our longest string token is three chars, so try each size in turn
    # until we either match or run out of chars.  This way our worst-case is three
    # tries, where it is otherwise the number of string token we have.  Also,
    # the lookups are optimized hash lookups, instead of regex scans.
    #
    s = @scanner.peek(3)
    token = TOKENS.lookup(s[0,3]) || TOKENS.lookup(s[0,2]) || TOKENS.lookup(s[0,1])
    [ token, token && @scanner.scan(token.regex) ]
  end

  # Find the next token that matches a regex.  We look for these first.
  def find_regex_token
    best_token = nil
    best_length = 0

    # I tried optimizing based on the first char, but it had
    # a slightly negative affect and was a good bit more complicated.
    TOKENS.regex_tokens.each do |token|
      if length = @scanner.match?(token.regex) and token.acceptable?(lexing_context)
        # We've found a longer match
        if length > best_length
          best_length = length
          best_token = token
        end
      end
    end

    return best_token, @scanner.scan(best_token.regex) if best_token
  end

  # Find the next token, returning the string and the token.
  def find_token
    shift_token || find_regex_token || find_string_token
  end

  def initialize
    initvars
  end

  def initvars
    @line = 1
    @previous_token = nil
    @scanner = nil
    @file = nil
    # AAARRGGGG! okay, regexes in ruby are bloody annoying
    # no one else has "\n" =~ /\s/
    @skip = %r{[ \t\r]+}

    @namestack = []
    @token_queue = []
    @indefine = false
    @expected = []
    @commentstack = [ ['', @line] ]
    @lexing_context = {
      :after => nil,
      :start_of_line => true,
      :string_interpolation_depth => 0
      }
  end

  # Make any necessary changes to the token and/or value.
  def munge_token(token, value)
    @line += 1 if token.incr_line

    skip if token.skip_text

    return if token.skip and not token.accumulate?

    token, value = token.convert(self, value) if token.respond_to?(:convert)

    return unless token

    if token.accumulate?
      comment = @commentstack.pop
      comment[0] << value + "\n"
      @commentstack.push(comment)
    end

    return if token.skip

    return token, { :value => value, :line => @line }
  end

  # Handling the namespace stack
  def_delegator :@namestack, :pop, :namepop
  # This value might have :: in it, but we don't care -- it'll be handled
  # normally when joining, and when popping we want to pop this full value,
  # however long the namespace is.
  def_delegator :@namestack, :<<, :namestack

  # Collect the current namespace.
  def namespace
    @namestack.join("::")
  end

  def_delegator :@scanner, :rest

  # this is the heart of the lexer
  def scan
    #Puppet.debug("entering scan")
    lex_error "Invalid or empty string" unless @scanner

    # Skip any initial whitespace.
    skip

    until token_queue.empty? and @scanner.eos? do
      yielded = false
      matched_token, value = find_token

      # error out if we didn't match anything at all
      lex_error "Could not match #{@scanner.rest[/^(\S+|\s+|.*)/]}" unless matched_token

      newline = matched_token.name == :RETURN

      # this matches a blank line; eat the previously accumulated comments
      getcomment if lexing_context[:start_of_line] and newline
      lexing_context[:start_of_line] = newline

      final_token, token_value = munge_token(matched_token, value)

      unless final_token
        skip
        next
      end

      lexing_context[:after]         = final_token.name unless newline
      lexing_context[:string_interpolation_depth] += 1 if final_token.name == :DQPRE
      lexing_context[:string_interpolation_depth] -= 1 if final_token.name == :DQPOST

      value = token_value[:value]

      if match = @@pairs[value] and final_token.name != :DQUOTE and final_token.name != :SQUOTE
        @expected << match
      elsif exp = @expected[-1] and exp == value and final_token.name != :DQUOTE and final_token.name != :SQUOTE
        @expected.pop
      end

      if final_token.name == :LBRACE or final_token.name == :LPAREN
        commentpush
      end
      if final_token.name == :RPAREN
        commentpop
      end

      yield [final_token.name, token_value]

      if @previous_token
        namestack(value) if @previous_token.name == :CLASS and value != '{'

        if @previous_token.name == :DEFINE
          if indefine?
            msg = "Cannot nest definition #{value} inside #{@indefine}"
            self.indefine = false
            raise Puppet::ParseError, msg
          end

          @indefine = value
        end
      end
      @previous_token = final_token
      skip
    end
    @scanner = nil

    # This indicates that we're done parsing.
    yield [false,false]
  end

  # Skip any skipchars in our remaining string.
  def skip
    @scanner.skip(@skip)
  end

  def match? r
    @scanner.match?(r)
  end
  
  # Provide some limited access to the scanner, for those
  # tokens that need it.
  def_delegator :@scanner, :scan_until

  # we've encountered the start of a string...
  # slurp in the rest of the string and return it
  def slurpstring(terminators,escapes=%w{ \\  $ ' " r n t s }+["\n"],ignore_invalid_escapes=false)
    # we search for the next quote that isn't preceded by a
    # backslash; the caret is there to match empty strings
    str = @scanner.scan_until(/([^\\]|^|[^\\])([\\]{2})*[#{terminators}]/) or lex_error "Unclosed quote after '#{last}' in '#{rest}'"
    @line += str.count("\n") # literal carriage returns add to the line count.
    str.gsub!(/\\(.)/m) {
      ch = $1
      if escapes.include? ch
        case ch
        when 'r'; "\r"
        when 'n'; "\n"
        when 't'; "\t"
        when 's'; " "
        when "\n"; ''
        else      ch
        end
      else
        Puppet.warning "Unrecognised escape sequence '\\#{ch}'#{file && " in file #{file}"}#{line && " at line #{line}"}" unless ignore_invalid_escapes
        "\\#{ch}"
      end
    }
    [ str[0..-2],str[-1,1] ]
  end

  def tokenize_interpolated_string(token_type,preamble='')
    value,terminator = slurpstring('"$')
    token_queue << [TOKENS[token_type[terminator]],preamble+value]
    if terminator != '$' or @scanner.scan(/\{/)
      token_queue.shift
    elsif var_name = @scanner.scan(TOKENS[:VARIABLE].regex)
      token_queue << [TOKENS[:VARIABLE],var_name]
      tokenize_interpolated_string(DQ_continuation_token_types)
    else
      tokenize_interpolated_string(token_type,token_queue.pop.last + terminator)
    end
  end

  # just parse a string, not a whole file
  def string=(string)
    @scanner = StringScanner.new(string)
  end

  # returns the content of the currently accumulated content cache
  def commentpop
    @commentstack.pop[0]
  end

  def getcomment(line = nil)
    comment = @commentstack.last
    if line.nil? or comment[1] <= line
      @commentstack.pop
      @commentstack.push(['', @line])
      return comment[0]
    end
    ''
  end

  def commentpush
    @commentstack.push(['', @line])
  end

end