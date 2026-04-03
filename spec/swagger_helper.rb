require "rails_helper"

RSpec.configure do |config|
  config.openapi_root = Rails.root.join("swagger").to_s

  config.openapi_specs = {
    "v1/swagger.yaml" => {
      openapi: "3.0.1",
      info: {
        title: "BookShelf API",
        version: "v1",
        description: "Personal library management API"
      },
      paths: {},
      servers: [
        { url: "http://localhost:3000", description: "Development server" }
      ],
      components: {
        schemas: {
          author_input: {
            type: :object,
            properties: {
              first_name: { type: :string, maxLength: 100 },
              last_name: { type: :string, maxLength: 100 },
              bio: { type: :string, maxLength: 2000, nullable: true },
              birth_year: { type: :integer, nullable: true },
              death_year: { type: :integer, nullable: true },
              website: { type: :string, nullable: true }
            },
            required: %w[first_name last_name]
          },
          author_response: {
            type: :object,
            properties: {
              id: { type: :integer },
              first_name: { type: :string },
              last_name: { type: :string },
              bio: { type: :string, nullable: true },
              birth_year: { type: :integer, nullable: true },
              death_year: { type: :integer, nullable: true },
              website: { type: :string, nullable: true },
              book_count: { type: :integer },
              created_at: { type: :string, format: "date-time" },
              updated_at: { type: :string, format: "date-time" }
            }
          },
          pagination_meta: {
            type: :object,
            properties: {
              page: { type: :integer },
              per_page: { type: :integer },
              total_items: { type: :integer },
              total_pages: { type: :integer }
            }
          },
          error_response: {
            type: :object,
            properties: {
              error: {
                type: :object,
                properties: {
                  code: { type: :string },
                  message: { type: :string },
                  details: { type: :array, items: { type: :object }, nullable: true }
                }
              }
            }
          }
        }
      }
    }
  }

  config.openapi_format = :yaml
end
