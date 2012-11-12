require 'pathname'
require 'puppet/util/rubygems'
require 'puppet/util/warnings'
require 'puppet/util/methodhelper'
require 'puppet/node/environment'

# Autoload paths, either based on names or all at once.
class Puppet::Util::Autoload
  include Puppet::Util::MethodHelper

  @autoloaders = {}
  @loaded = {}

  class << self
    attr_reader :autoloaders
    attr_accessor :loaded
    private :autoloaders, :loaded

    def gem_source
      @gem_source ||= Puppet::Util::RubyGems::Source.new
    end

    # List all loaded files.
    def list_loaded
      loaded.keys.sort { |a,b| a[0] <=> b[0] }.collect do |path, hash|
        "#{path}: #{hash[:file]}"
      end
    end

    # Has a given path been loaded?  This is used for testing whether a
    # changed file should be loaded or just ignored.  This is only
    # used in network/client/master, when downloading plugins, to
    # see if a given plugin is currently loaded and thus should be
    # reloaded.
    def loaded?(path)
      path = cleanpath(path).chomp('.rb')
      loaded.include?(path)
    end

    # Save the fact that a given path has been loaded.  This is so
    # we can load downloaded plugins if they've already been loaded
    # into memory.
    def mark_loaded(name, file)
      name = cleanpath(name).chomp('.rb')
      ruby_file = name + ".rb"
      $LOADED_FEATURES << ruby_file unless $LOADED_FEATURES.include?(ruby_file)
      loaded[name] = [file, File.mtime(file)]
    end

    def changed?(name)
      name = cleanpath(name).chomp('.rb')
      return true unless loaded.include?(name)
      file, old_mtime = loaded[name]
      return true unless file == get_file(name)
      begin
        old_mtime != File.mtime(file)
      rescue Errno::ENOENT
        true
      end
    end

    # Load a single plugin by name.  We use 'load' here so we can reload a
    # given plugin.
    def load_file(name, env=nil)
      file = get_file(name.to_s, env)
      return false unless file
      begin
        mark_loaded(name, file)
        Kernel.load file, @wrap
        return true
      rescue SystemExit,NoMemoryError
        raise
      rescue Exception => detail
        message = "Could not autoload #{name}: #{detail}"
        Puppet.log_exception(detail, message)
        raise Puppet::Error, message
      end
    end

    def loadall(path)
      # Load every instance of everything we can find.
      files_to_load(path).each do |file|
        name = file.chomp(".rb")
        load_file(name) unless loaded?(name)
      end
    end

    def reload_changed
      loaded.keys.each { |file| load_file(file) if changed?(file) }
    end

    # Get the correct file to load for a given path
    # returns nil if no file is found
    def get_file(name, env=nil)
      name = name + '.rb' unless name =~ /\.rb$/
      dirname, base = File.split(name)
      path = search_directories(env).find { |dir| File.exist?(File.join(dir, name)) }
      path and File.join(path, name)
    end

    def files_to_load(path)
      search_directories.map {|dir| files_in_dir(dir, path) }.flatten.uniq
    end

    def files_in_dir(dir, path)
      dir = Pathname.new(File.expand_path(dir))
      Dir.glob(File.join(dir, path, "*.rb")).collect do |file|
        Pathname.new(file).relative_path_from(dir).to_s
      end
    end

    def module_directories(env=nil)
      real_env = Puppet::Node::Environment.new(env)

      # We're using a per-thread cache of module directories so that we don't
      # scan the filesystem each time we try to load something. This is reset
      # at the beginning of compilation and at the end of an agent run.
      Thread.current[:env_module_directories] ||= {}

      Thread.current[:env_module_directories][real_env] ||= real_env.modulepath.collect do |dir|
        Dir.entries(dir).reject { |f| f =~ /^\./ }.collect { |f| File.join(dir, f) }
      end.flatten.collect { |d| File.join(d, "lib") }.find_all do |d|
        FileTest.directory?(d)
      end
    end

    def libdirs()
      Puppet[:libdir].split(File::PATH_SEPARATOR)
    end

    def gem_directories
      gem_source.directories
    end

    def search_directories(env=nil)
      [gem_directories, module_directories(env), libdirs(), $LOAD_PATH].flatten
    end

    # Normalize a path. This converts ALT_SEPARATOR to SEPARATOR on Windows
    # and eliminates unnecessary parts of a path.
    def cleanpath(path)
      # There are two cases here because cleanpath does not handle absolute
      # paths correctly on windows (c:\ and c:/ are treated as distinct) but
      # we don't want to convert relative paths to absolute
      if Puppet::Util.absolute_path?(path)
        File.expand_path(path)
      else
        Pathname.new(path).cleanpath.to_s
      end
    end
  end

  # Send [] and []= to the @autoloaders hash
  Puppet::Util.classproxy self, :autoloaders, "[]", "[]="

  attr_accessor :object, :path, :objwarn, :wrap

  def initialize(obj, path, options = {})
    @path = path.to_s
    raise ArgumentError, "Autoload paths cannot be fully qualified" if Puppet::Util.absolute_path?(@path)
    @object = obj

    self.class[obj] = self

    set_options(options)

    @wrap = true unless defined?(@wrap)
  end

  def load(name, env=nil)
    self.class.load_file(File.join(@path, name.to_s), env)
  end

  # Load all instances that we can.  This uses require, rather than load,
  # so that already-loaded files don't get reloaded unnecessarily.
  def loadall
    self.class.loadall(@path)
  end

  def loaded?(name)
    self.class.loaded?(File.join(@path, name.to_s))
  end

  def changed?(name)
    self.class.changed?(File.join(@path, name.to_s))
  end

  def files_to_load
    self.class.files_to_load(@path)
  end
end
