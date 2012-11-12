# Bundler and rubygems maintain a set of directories from which to
# load gems. If Bundler is loaded, let it determine what can be
# loaded. If it's not loaded, then use rubygems. But do this before
# loading any puppet code, so that our gem loading system is sane.
if not defined? ::Bundler
  begin
    require 'rubygems'
  rescue LoadError
  end
end

require 'puppet'
require 'puppet/util/rubygems'

module Puppet
  module Util
    class CommandLine
      OPTION_OR_MANIFEST_FILE = /^-|\.pp$|\.rb$/

      attr_reader :subcommand_name
      attr_reader :args

      ##
      # @api public
      # @param [String] unused
      # @param [Array<String>] the arguments to the executable
      # @param [IO] unused
      def initialize(zero = $0, argv = ARGV, stdin = STDIN)
        @subcommand_name, @args = subcommand_and_args(argv)
      end

      def execute
        if args.include? "--version" or args.include? "-V" then
          puts Puppet.version
        elsif subcommand_name then
          Puppet.initialize_settings(subcommand_name.to_sym, args)

          include_in_load_path Puppet.settings.value(:modulepath, subcommand_name.to_sym)
          begin
            Puppet::Application.
              find(subcommand_name).
              new(self).
              run
          rescue LoadError
            puts "Error: Unknown Puppet subcommand '#{subcommand_name}'"
          end
        else
          puts "See 'puppet help' for help on available puppet subcommands"
        end
      end

      private

      def include_in_load_path(paths)
        $LOAD_PATH.push(*library_directories_in(paths.split(File::PATH_SEPARATOR)))
      end

      def library_directories_in(paths)
        paths.
          collect { |path| Dir.glob(File.join(path, '*', 'lib')) }.
          flatten
      end

      def subcommand_and_args(argv)
        if argv.first =~ OPTION_OR_MANIFEST_FILE
          [nil, argv]
        else
          [argv.first, argv[1..-1]]
        end
      end
    end
  end
end
