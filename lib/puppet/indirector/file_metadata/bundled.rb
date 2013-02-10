require 'puppet/file_serving/metadata'
require 'puppet/indirector/file_metadata'
require 'puppet/indirector/direct_file_server'

class Puppet::Indirector::FileMetadata::Bundled < Puppet::Indirector::Code
  desc "Retrieve file metadata from a bundle."

  def self.location(index)
    @@index = index
  end

  def find(request)
    data = @@index[request.uri]
    return nil if data.nil?

    metadata = data["metadata"]

    instance = model.new("/" + request.key,
      "owner" => metadata["owner"],
      "group" => metadata["group"],
      "mode" => metadata["mode"],
      "checksum" => {
        "type" => metadata["checksum"]["type"],
        "value" => metadata["checksum"]["value"] },
      "type" => metadata["ftype"],
      "source" => metadata["source"])

    instance
  end

  def search(request)
    raise "No search of metadata for you!"
  end
end

