require 'puppet/application'
require 'puppet/configurer'

class Puppet::Application::Apply < Puppet::Application

  option("--debug","-d")
  option("--verbose","-v")
  option("--detailed-exitcodes")

  option("--logdest LOGDEST", "-l") do |arg|
    begin
      Puppet::Util::Log.newdestination(arg)
      options[:logset] = true
    rescue => detail
      $stderr.puts detail.to_s
    end
  end

  def help
    ''
  end

  def app_defaults
    super.merge({
      :default_file_terminus => :file_server,
    })
  end

  def run_command
    apply
  end

  def apply
    if options[:catalog] == "-"
      text = $stdin.read
    else
      text = ::File.read(options[:catalog])
    end
    catalog = read_catalog(text)
    apply_catalog(catalog)
  end

  def setup
    exit(Puppet.settings.print_configs ? 0 : 1) if Puppet.settings.print_configs?

    Puppet::Util::Log.newdestination(:console) unless options[:logset]
    client = nil
    server = nil

    Signal.trap(:INT) do
      $stderr.puts "Exiting"
      exit(1)
    end

    # we want the last report to be persisted locally
    Puppet::Transaction::Report.indirection.cache_class = :yaml

    if options[:debug]
      Puppet::Util::Log.level = :debug
    elsif options[:verbose]
      Puppet::Util::Log.level = :info
    end
  end

  private

  def read_catalog(text)
    begin
      catalog = Puppet::Resource::Catalog.convert_from(Puppet::Resource::Catalog.default_format,text)
      catalog = Puppet::Resource::Catalog.pson_create(catalog) unless catalog.is_a?(Puppet::Resource::Catalog)
    rescue => detail
      raise Puppet::Error, "Could not deserialize catalog from pson: #{detail}"
    end

    catalog.to_ral
  end

  def apply_catalog(catalog)
    configurer = Puppet::Configurer.new
    configurer.run(:catalog => catalog, :pluginsync => false)
  end
end
