module Sortable
  extend ActiveSupport::Concern

  private

  def apply_sort(scope, sortable_fields: self.class::SORTABLE_FIELDS, default_sort: self.class::DEFAULT_SORT)
    sort_by = params[:sort_by]
    sort_order = params[:sort_order]

    if sort_by.present? && sortable_fields.key?(sort_by)
      column = sortable_fields[sort_by]
    else
      column = default_sort[:column]
      sort_order = default_sort[:direction] if sort_order.blank?
    end

    direction = %w[asc desc].include?(sort_order&.downcase) ? sort_order.downcase : "asc"

    scope.order(Arel.sql(column).send(direction))
  end
end
