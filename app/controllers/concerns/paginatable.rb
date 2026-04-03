module Paginatable
  extend ActiveSupport::Concern

  private

  def paginate(scope)
    page = parse_positive_integer(params[:page], default: 1)
    per_page = parse_positive_integer(params[:per_page], default: 20)

    return if performed?

    per_page = per_page.clamp(1, 100)

    total_count = scope.count
    total_items = total_count.is_a?(Hash) ? total_count.length : total_count
    total_pages = [ (total_items.to_f / per_page).ceil, 1 ].max

    records = scope.offset((page - 1) * per_page).limit(per_page)

    meta = {
      page: page,
      per_page: per_page,
      total_items: total_items,
      total_pages: total_pages
    }

    [ records, meta ]
  end

  def parse_positive_integer(value, default:)
    return default if value.blank?

    integer = Integer(value, exception: false)

    if integer.nil? || integer < 1
      render_error("BAD_REQUEST", :bad_request, "#{value} is not a valid positive integer")
      return nil
    end

    integer
  end
end
