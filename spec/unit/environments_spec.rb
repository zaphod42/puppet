require 'spec_helper'
require 'puppet/environments'
require 'puppet/file_system'
require 'matchers/include'

describe Puppet::Environments do
  include Matchers::Include
  include PuppetSpec::Files

  FS = Puppet::FileSystem

  describe "directories loader" do
    def loader_from(options, &block)
      FS.overlay(*options[:filesystem]) do
        yield Puppet::Environments::Directories.new(
          options[:directory],
          options[:modulepath] || []
        )
      end
    end

    it "lists environments" do
      global_path_1_location = File.expand_path("global_path_1")
      global_path_2_location = File.expand_path("global_path_2")
      global_path_1 = FS::MemoryFile.a_directory(global_path_1_location)
      global_path_2 = FS::MemoryFile.a_directory(global_path_2_location)

      envdir = FS::MemoryFile.a_directory(File.expand_path("envdir"), [
        FS::MemoryFile.a_directory("env1", [
          FS::MemoryFile.a_directory("modules"),
          FS::MemoryFile.a_directory("manifests"),
        ]),
        FS::MemoryFile.a_directory("env2")
      ])

      loader_from(:filesystem => [envdir, global_path_1, global_path_2],
                  :directory => envdir,
                  :modulepath => [global_path_1_location, global_path_2_location]) do |loader|
        expect(loader.list).to include_in_any_order(
          environment(:env1).
            with_manifest("#{FS.path_string(envdir)}/env1/manifests").
            with_modulepath(["#{FS.path_string(envdir)}/env1/modules",
                             global_path_1_location,
                             global_path_2_location]),
          environment(:env2))
      end
    end

    it "does not list files" do
      envdir = FS::MemoryFile.a_directory("envdir", [
        FS::MemoryFile.a_regular_file_containing("foo", ''),
        FS::MemoryFile.a_directory("env1"),
        FS::MemoryFile.a_directory("env2"),
      ])

      loader_from(:filesystem => [envdir],
                  :directory => envdir) do |loader|
        expect(loader.list).to include_in_any_order(environment(:env1), environment(:env2))
      end
    end

    it "it ignores directories that are not valid env names (alphanumeric and _)" do
      envdir = FS::MemoryFile.a_directory("envdir", [
        FS::MemoryFile.a_directory(".foo"),
        FS::MemoryFile.a_directory("bar-thing"),
        FS::MemoryFile.a_directory("with spaces"),
        FS::MemoryFile.a_directory("some.thing"),
        FS::MemoryFile.a_directory("env1"),
        FS::MemoryFile.a_directory("env2"),
      ])

      loader_from(:filesystem => [envdir],
                  :directory => envdir) do |loader|
        expect(loader.list).to include_in_any_order(environment(:env1), environment(:env2))
      end
    end

    it "gets a particular environment" do
      directory_tree = FS::MemoryFile.a_directory("envdir", [
        FS::MemoryFile.a_directory("env1"),
        FS::MemoryFile.a_directory("env2"),
      ])

      loader_from(:filesystem => [directory_tree],
                  :directory => directory_tree) do |loader|
        expect(loader.get("env1")).to environment(:env1)
      end
    end

    it "returns nil if an environment can't be found" do
      directory_tree = FS::MemoryFile.a_directory("envdir", [])

      loader_from(:filesystem => [directory_tree],
                  :directory => directory_tree) do |loader|
        expect(loader.get("env_not_in_this_list")).to be_nil
      end
    end
  end

  describe "combined loader" do
    let(:modules) { File.expand_path("modules") }
    let(:missing_modules) { File.expand_path("missing_modules") }

    around :each do |example|
      FS.overlay(
        FS::MemoryFile.a_directory(modules),
        FS::MemoryFile.a_missing_file(missing_modules)) do

        example.call
      end
    end

    def an_environment(name, modulepath = [modules])
      Puppet::Node::Environment.create(name, modulepath, "")
    end

    it "lists environments from all of the source loaders" do
      loader1 = Puppet::Environments::Static.new(an_environment(:first), an_environment(:second))
      loader2 = Puppet::Environments::Static.new(an_environment(:third))
      combined = Puppet::Environments::Combined.new(loader1, loader2)

      expect(combined.list.collect(&:name)).to eq([:first, :second, :third])
    end

    it "gets the first environment matching the requested name" do
      loader1 = Puppet::Environments::Static.new(an_environment(:first), an_environment(:second))
      loader2 = Puppet::Environments::Static.new(an_environment(:first))
      combined = Puppet::Environments::Combined.new(loader1, loader2)

      expect(combined.get(:first)).to equal(loader1.get(:first))
    end

    it "ignores an environment if it has no modulepath" do
      loader1 = Puppet::Environments::Static.new(an_environment(:first, [missing_modules]))
      loader2 = Puppet::Environments::Static.new(an_environment(:first, [modules]))
      combined = Puppet::Environments::Combined.new(loader1, loader2)

      expect(combined.get(:first)).to equal(loader2.get(:first))
    end

    it "returns a legacy environment if there are no other suitable environments" do
      loader = Puppet::Environments::Static.new(an_environment(:first, [missing_modules]))
      combined = Puppet::Environments::Combined.new(loader)

      expect(combined.get(:first)).to environment(:first)
    end
  end

  RSpec::Matchers.define :environment do |name|
    match do |env|
      env.name == name &&
        (!@manifest || @manifest == env.manifest) &&
        (!@modulepath || @modulepath == env.modulepath)
    end

    chain :with_manifest do |manifest|
      @manifest = manifest
    end

    chain :with_modulepath do |modulepath|
      @modulepath = modulepath
    end

    description do
      "environment #{expected}" +
        (@manifest ? " with manifest #{@manifest}" : "") +
        (@modulepath ? " with modulepath [#{@modulepath.join(', ')}]" : "")
    end

    failure_message_for_should do |env|
      "expected <#{env.name}: modulepath = [#{env.modulepath.join(', ')}], manifest = #{env.manifest}> to be #{description}"
    end
  end
end
