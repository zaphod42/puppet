require 'puppet/resource/type_collection'

module Puppet
  class Resource
    module TypeCollectionHelper
      def known_resource_types
        environment.known_resource_types
      end
    end
  end
end
