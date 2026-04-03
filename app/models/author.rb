class Author < ApplicationRecord
  include Sanitizable
  include Filterable

  has_many :books, dependent: :restrict_with_error

  validates :first_name, presence: true, length: { maximum: 100 }
  validates :last_name, presence: true, length: { maximum: 100 }
  validates :bio, length: { maximum: 2000 }, allow_blank: true
  validates :birth_year, numericality: { only_integer: true, less_than_or_equal_to: ->(_) { Date.current.year } }, allow_nil: true
  validates :death_year, numericality: { only_integer: true }, allow_nil: true
  validate :death_year_after_birth_year
  validates :website, format: { with: URI::DEFAULT_PARSER.make_regexp(%w[http https]), message: "must be a valid URL" }, allow_blank: true

  scope :by_search, ->(query) {
    where("first_name LIKE :q OR last_name LIKE :q", q: "%#{sanitize_sql_like(query)}%")
  }

  def full_name
    "#{first_name} #{last_name}"
  end

  private

  def death_year_after_birth_year
    return unless birth_year.present? && death_year.present?

    if death_year < birth_year
      errors.add(:death_year, "must be greater than or equal to birth year")
    end
  end
end
