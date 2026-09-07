class ModuleCost < ApplicationRecord
  validates :layer, presence: true, uniqueness: true
  validates :cost_in_credits, numericality: { greater_than_or_equal_to: 0 }

  def self.for(layer)
    @cache ||= {}
    @cache[layer.to_s] ||= find_by!(layer: layer.to_s).cost_in_credits
  end

  def self.reset_cache!
    @cache = {}
  end
end
