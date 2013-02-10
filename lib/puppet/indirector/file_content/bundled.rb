require 'puppet/file_serving/content'
require 'puppet/indirector/file_content'

class Puppet::Indirector::FileContent::Bundled < Puppet::Indirector::Code
  desc "Retrieve file contents from a bundle."

  def self.location(index, data_dir)
    @@index = index
    @@data_dir = data_dir
  end

  def find(request)
    index_entry = @@index[request.uri]
    return nil if index_entry.nil?

    file = File.join(@@data_dir, index_entry["content"])
    return nil if not FileTest.exists?(file)
    instance = model.new(file)
    instance
  end

  def search(request)
    raise "no search for you!"
  end
end

