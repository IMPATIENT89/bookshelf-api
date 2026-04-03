module Sanitizable
  extend ActiveSupport::Concern

  included do
    before_validation :sanitize_string_attributes
  end

  private

  def sanitize_string_attributes
    self.class.columns.each do |column|
      next unless column.type.in?(%i[string text])

      value = read_attribute(column.name)
      next if value.nil?

      sanitized = Rails::HTML5::FullSanitizer.new.sanitize(value).strip
      write_attribute(column.name, sanitized)
    end
  end
end
