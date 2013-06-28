# Configures validation suitable for 3.1 + iteration
#
class Puppet::Pops::Validation::ValidatorFactory_3_1 < Puppet::Pops::Validation::Factory
  Issues = Puppet::Pops::Issues

  # Produces the checker to use
  def checker diagnostic_producer
    Puppet::Pops::Validation::Checker3_1.new(diagnostic_producer)
  end

  # Produces the label provider to use
  def label_provider
    Puppet::Pops::Model::ModelLabelProvider.new()
  end

  # Produces the severity producer to use
  def severity_producer
    p = super

    # Configure each issue that should **not** be an error
    #
    p[Issues::RT_NO_STORECONFIGS_EXPORT]    = :warning
    p[Issues::RT_NO_STORECONFIGS]           = :warning
    p[Issues::NAME_WITH_HYPHEN]             = :deprecation
    p[Issues::DEPRECATED_NAME_AS_TYPE]      = :deprecation

    p
  end
end
