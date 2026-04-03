FactoryBot.define do
  factory :author do
    sequence(:first_name) { |n| "Author#{n}" }
    sequence(:last_name) { |n| "Surname#{n}" }

    trait :with_bio do
      bio { "A prolific writer known for their imaginative works." }
    end

    trait :with_years do
      birth_year { 1950 }
      death_year { 2020 }
    end

    trait :with_website do
      website { "https://example.com" }
    end

    trait :full do
      with_bio
      with_years
      with_website
    end
  end
end
