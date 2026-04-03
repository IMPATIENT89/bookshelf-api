module Filterable
  extend ActiveSupport::Concern

  class_methods do
    def filter_by(params, allowed_filters)
      scope = all

      allowed_filters.each do |filter|
        next unless params[filter].present?

        scope = scope.public_send("by_#{filter}", params[filter])
      end

      scope
    end
  end
end
