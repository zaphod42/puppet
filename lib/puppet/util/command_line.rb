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
require "puppet/util/rubygems"

module Puppet
  module Util
    class CommandLine

      def initialize(zero = $0, argv = ARGV, stdin = STDIN)
        @zero  = zero
        @argv  = argv.dup
        @stdin = stdin

        @subcommand_name, @args = subcommand_and_args(@zero, @argv, @stdin)
      end

      attr :subcommand_name
      attr :args

      def appdir
        File.join('puppet', 'application')
      end

      def self.available_subcommands
        # Eventually we probably want to replace this with a call to the
        # autoloader.  however, at the moment the autoloader considers the
        # module path when loading, and we don't want to allow apps / faces to
        # load from there.  Once that is resolved, this should be replaced.
        # --cprice 2012-03-06
        #
        # But we do want to load from rubygems --hightower
        search_path = Puppet::Util::RubyGems::Source.new.directories + $LOAD_PATH
        absolute_appdirs = search_path.uniq.collect do |x|
          File.join(x,'puppet','application')
        end.select{ |x| File.directory?(x) }
        absolute_appdirs.inject([]) do |commands, dir|
          commands + Dir[File.join(dir, '*.rb')].map{|fn| File.basename(fn, '.rb')}
        end.uniq
      end
      # available_subcommands was previously an instance method, not a class
      # method, and we have an unknown number of user-implemented applications
      # that depend on that behaviour.  Forwarding allows us to preserve a
      # backward compatible API. --daniel 2011-04-11
      def available_subcommands
        self.class.available_subcommands
      end

      def require_application(application)
        require File.join(appdir, application)
      end

      # This is the main entry point for all puppet applications / faces; it
      # is basically where the bootstrapping process / lifecycle of an app
      # begins.
      def execute
        Puppet.settings.initialize_global_settings(args)
        Puppet.settings.set_value(:confdir, Puppet.run_mode.conf_dir, :memory)

        if subcommand_name then
          include_in_load_path Puppet.settings.value(:modulepath, subcommand_name.to_sym)
          begin
            require_application subcommand_name
          rescue LoadError
            puts "Error: Unknown Puppet subcommand '#{subcommand_name}'"
          end
          app = Puppet::Application.find(subcommand_name).new(self)

          app.run
        elsif @argv.include? "--version" or @argv.include? "-V" then
          puts Puppet.version
        else
          puts "See 'puppet help' for help on available puppet subcommands"
        end
      end

      private

      def include_in_load_path(paths)
        paths.split(File::PATH_SEPARATOR).each do |path|
          Dir.glob(File.join(path, '*')).each do |module_path|
            module_library_path = File.join(module_path, 'lib')
            puts "Adding #{module_library_path}"
            $LOAD_PATH << module_library_path
          end
        end
      end

      def subcommand_and_args(zero, argv, stdin)
        zero = File.basename(zero, '.rb')

        if zero == 'puppet'
          case argv.first
            # if they didn't pass a command, or passed a help flag, we will
            # fall back to showing a usage message.  we no longer default to
            # 'apply'
            when nil, "--help", "-h", /^-|\.pp$|\.rb$/
              [nil, argv]
            else
              [argv.first, argv[1..-1]]
          end
        else
          [zero, argv]
        end
      end

    end
  end
end
