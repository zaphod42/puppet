# Analyzes a Pops::Model to count the kinds of elements involved and any other
# interesting statistics about them.
class Puppet::Pops::Model::ModelTreeAnalyzer
  def analyze(model)
    counts = count_classes(model)

    {
      :model_counts => counts,
      :stats => statistics(counts)
    }
  end

  private

  def count_classes(model)
    counts = Hash.new(0)

    model.model.eAllContents.each do |m|
      counts[m.class.name] += 1
    end

    counts
  end

  def statistics(class_counts)
    total = sum_values(class_counts)
    resource_count = class_counts["Puppet::Pops::Model::ResourceExpression"]
    {
      :total => total,
      :operations_per_resource => total / resource_count
    }
  end

  def sum_values(hash)
    hash.values.inject(0, &:+)
  end
end
