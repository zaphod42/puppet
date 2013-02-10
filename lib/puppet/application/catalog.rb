require 'puppet/application'
require 'digest/sha1'
require 'tmpdir'

class Puppet::Application::Catalog < Puppet::Application

  option("--debug","-d")
  option("--execute EXECUTE","-e") do |arg|
    options[:code] = arg
  end
  option("--verbose","-v")
  option("--use-nodes")
  option("--detailed-exitcodes")

  option("--output FILE", "-O")

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
    main
  end

  def main
    # Set our code or file to use.
    if options[:code] or command_line.args.length == 0
      Puppet[:code] = options[:code] || STDIN.read
    else
      manifest = command_line.args.shift
      raise "Could not find file #{manifest}" unless ::File.exist?(manifest)
      Puppet.warning("Only one file can be applied per run.  Skipping #{command_line.args.join(', ')}") if command_line.args.size > 0
      Puppet[:manifest] = manifest
    end

    unless Puppet[:node_name_fact].empty?
      # Collect our facts.
      unless facts = Puppet::Node::Facts.indirection.find(Puppet[:node_name_value])
        raise "Could not find facts for #{Puppet[:node_name_value]}"
      end

      Puppet[:node_name_value] = facts.values[Puppet[:node_name_fact]]
      facts.name = Puppet[:node_name_value]
    end

    # Find our Node
    unless node = Puppet::Node.indirection.find(Puppet[:node_name_value])
      raise "Could not find node #{Puppet[:node_name_value]}"
    end

    # Merge in the facts.
    node.merge(facts.values) if facts

    begin
      catalog = Puppet::Parser::Compiler.compile(node)
      file_resources = catalog.resources.find_all { |resource| resource.type == "File" }
      sources = file_resources.collect { |resource| resource[:source] }

      source_data = sources.collect do |source|
        metadata = Puppet::FileServing::Metadata.indirection.find(source, :environment => catalog.environment)
        file = Puppet::FileServing::Content.indirection.find(source, :environment => catalog.environment)
        if file.nil?
          raise "Unable to fetch contents of #{source}"
        end
        { :source => source, :file => file, :metadata => metadata }
      end

      Dir.mktmpdir do |dir|
        File.open(File.join(dir, 'catalog.json'), 'w') do |file|
          file.write(catalog.to_pson)
        end

        data_dir = File.join(dir, 'data')
        Dir.mkdir(data_dir)

        index = {}
        source_data.each do |data|
          digest = data[:file].digest
          File.open(File.join(data_dir, digest), 'wb') do |file|
            metadata = data[:metadata]
            index[data[:source]] = {
              :content => digest,
              :metadata => {
                :owner => metadata.owner,
                :group => metadata.group,
                :mode => metadata.mode,
                :ftype => metadata.ftype,
                :checksum => { :type => 'md5',
                               :value => metadata.checksum.gsub(/\{.*\}/, '') },
                :source => data[:source]
              }
            }
            data[:file].write_to(file)
          end
        end

        File.open(File.join(dir, 'index.json'), 'w') do |file|
          file.write(index.to_pson)
        end

        system("tar", "-czf", options[:output], "-C", dir, ".")
      end
    rescue => detail
      Puppet.log_exception(detail)
      exit(1)
    end
  end

  def setup
    Puppet::Util::Log.newdestination(:console) unless options[:logset]
    client = nil
    server = nil

    if options[:debug]
      Puppet::Util::Log.level = :debug
    elsif options[:verbose]
      Puppet::Util::Log.level = :info
    end
  end
end
