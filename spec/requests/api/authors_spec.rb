require "swagger_helper"

RSpec.describe "Authors API", type: :request do
  let(:json) { JSON.parse(response.body, symbolize_names: true) }

  # Book model does not exist yet. Stub Book constant and author.books association.
  before do
    book_relation = double("BookRelation")
    allow(book_relation).to receive(:group).and_return(book_relation)
    allow(book_relation).to receive(:count).and_return({})

    book_class = double("Book")
    allow(book_class).to receive(:where).and_return(book_relation)
    stub_const("Book", book_class)

    books_proxy = double("BooksProxy", exists?: false, count: 0)
    allow(books_proxy).to receive(:order).and_return(books_proxy)
    allow(books_proxy).to receive(:limit).and_return(books_proxy)
    allow(books_proxy).to receive(:offset).and_return(books_proxy)
    allow(books_proxy).to receive(:map).and_return([])
    allow_any_instance_of(Author).to receive(:books).and_return(books_proxy)
  end

  path "/api/authors" do
    get "Lists authors" do
      tags "Authors"
      produces "application/json"
      parameter name: :page, in: :query, type: :integer, required: false
      parameter name: :per_page, in: :query, type: :integer, required: false
      parameter name: :sort_by, in: :query, type: :string, required: false
      parameter name: :sort_order, in: :query, type: :string, required: false
      parameter name: :search, in: :query, type: :string, required: false

      response "200", "returns paginated authors" do
        let!(:authors) { create_list(:author, 3) }

        run_test! do
          expect(json[:data].length).to eq(3)
          expect(json[:meta]).to include(:page, :per_page, :total_items, :total_pages)
          expect(json[:data].first).to include(:id, :first_name, :last_name, :book_count)
        end
      end

      response "200", "paginates with custom page/per_page" do
        let!(:authors) { create_list(:author, 5) }
        let(:page) { 2 }
        let(:per_page) { 2 }

        run_test! do
          expect(json[:data].length).to eq(2)
          expect(json[:meta][:page]).to eq(2)
          expect(json[:meta][:per_page]).to eq(2)
          expect(json[:meta][:total_items]).to eq(5)
          expect(json[:meta][:total_pages]).to eq(3)
        end
      end

      response "200", "sorts by last_name ascending by default" do
        let!(:author_z) { create(:author, last_name: "Zebra") }
        let!(:author_a) { create(:author, last_name: "Alpha") }

        run_test! do
          names = json[:data].map { |a| a[:last_name] }
          expect(names).to eq(%w[Alpha Zebra])
        end
      end

      response "200", "sorts by first_name" do
        let!(:author1) { create(:author, first_name: "Zara") }
        let!(:author2) { create(:author, first_name: "Aaron") }
        let(:sort_by) { "first_name" }

        run_test! do
          names = json[:data].map { |a| a[:first_name] }
          expect(names).to eq(%w[Aaron Zara])
        end
      end

      response "200", "sorts by created_at desc" do
        let!(:author1) { create(:author) }
        let!(:author2) { create(:author) }
        let(:sort_by) { "created_at" }
        let(:sort_order) { "desc" }

        run_test! do
          expect(json[:data].first[:id]).to eq(author2.id)
        end
      end

      response "200", "filters by search param" do
        let!(:matching) { create(:author, first_name: "Gabriel", last_name: "Marquez") }
        let!(:non_matching) { create(:author, first_name: "Jane", last_name: "Austen") }
        let(:search) { "Marquez" }

        run_test! do
          expect(json[:data].length).to eq(1)
          expect(json[:data].first[:last_name]).to eq("Marquez")
        end
      end

      response "200", "returns empty data when no authors exist" do
        run_test! do
          expect(json[:data]).to eq([])
          expect(json[:meta][:total_items]).to eq(0)
        end
      end
    end

    post "Creates an author" do
      tags "Authors"
      consumes "application/json"
      produces "application/json"
      parameter name: :params, in: :body, schema: { "$ref" => "#/components/schemas/author_input" }

      let(:params) { { author: attributes } }

      response "201", "creates an author" do
        let(:attributes) { { first_name: "Gabriel", last_name: "Garcia Marquez", bio: "Colombian novelist", birth_year: 1927, death_year: 2014 } }

        run_test! do
          expect(json[:data]).to include(
            first_name: "Gabriel",
            last_name: "Garcia Marquez",
            book_count: 0
          )
          expect(json[:data][:id]).to be_present
        end
      end

      response "422", "rejects missing first_name" do
        let(:attributes) { { last_name: "Marquez" } }

        run_test! do
          expect(json[:error][:code]).to eq("VALIDATION_ERROR")
          expect(json[:error][:details]).to include(a_hash_including(field: "first_name"))
        end
      end

      response "422", "rejects missing last_name" do
        let(:attributes) { { first_name: "Gabriel" } }

        run_test! do
          expect(json[:error][:code]).to eq("VALIDATION_ERROR")
          expect(json[:error][:details]).to include(a_hash_including(field: "last_name"))
        end
      end

      response "422", "rejects bio exceeding 2000 characters" do
        let(:attributes) { { first_name: "Gabriel", last_name: "Marquez", bio: "x" * 2001 } }

        run_test! do
          expect(json[:error][:code]).to eq("VALIDATION_ERROR")
          expect(json[:error][:details]).to include(a_hash_including(field: "bio"))
        end
      end

      response "422", "rejects future birth_year" do
        let(:attributes) { { first_name: "Gabriel", last_name: "Marquez", birth_year: Date.current.year + 1 } }

        run_test! do
          expect(json[:error][:code]).to eq("VALIDATION_ERROR")
          expect(json[:error][:details]).to include(a_hash_including(field: "birth_year"))
        end
      end

      response "422", "rejects death_year before birth_year" do
        let(:attributes) { { first_name: "Gabriel", last_name: "Marquez", birth_year: 1950, death_year: 1940 } }

        run_test! do
          expect(json[:error][:code]).to eq("VALIDATION_ERROR")
          expect(json[:error][:details]).to include(a_hash_including(field: "death_year"))
        end
      end

      response "400", "rejects non-JSON Content-Type" do
        let(:attributes) { { first_name: "Gabriel", last_name: "Marquez" } }

        before do
          allow_any_instance_of(ActionDispatch::Request).to receive(:content_type).and_return("text/plain")
        end

        run_test! do
          expect(json[:error][:code]).to eq("BAD_REQUEST")
        end
      end
    end
  end

  path "/api/authors/{id}" do
    get "Retrieves an author" do
      tags "Authors"
      produces "application/json"
      parameter name: :id, in: :path, type: :integer

      response "200", "returns the author" do
        let!(:author) { create(:author, :full) }
        let(:id) { author.id }

        run_test! do
          expect(json[:data]).to include(id: author.id, book_count: 0)
          expect(json[:data]).to have_key(:recent_books)
        end
      end

      response "404", "author not found" do
        let(:id) { 999_999 }

        run_test! do
          expect(json[:error][:code]).to eq("NOT_FOUND")
        end
      end
    end

    put "Updates an author" do
      tags "Authors"
      consumes "application/json"
      produces "application/json"
      parameter name: :id, in: :path, type: :integer
      parameter name: :params, in: :body, schema: { "$ref" => "#/components/schemas/author_input" }

      let!(:author) { create(:author, first_name: "Gabriel", last_name: "Marquez") }
      let(:id) { author.id }
      let(:params) { { author: attributes } }

      response "200", "updates with partial params" do
        let(:attributes) { { last_name: "Garcia Marquez" } }

        run_test! do
          expect(json[:data][:last_name]).to eq("Garcia Marquez")
          expect(json[:data][:first_name]).to eq("Gabriel")
        end
      end

      response "422", "rejects invalid update" do
        let(:attributes) { { first_name: "" } }

        run_test! do
          expect(json[:error][:code]).to eq("VALIDATION_ERROR")
        end
      end

      response "404", "author not found" do
        let(:id) { 999_999 }
        let(:attributes) { { last_name: "Updated" } }

        run_test! do
          expect(json[:error][:code]).to eq("NOT_FOUND")
        end
      end
    end

    delete "Deletes an author" do
      tags "Authors"
      parameter name: :id, in: :path, type: :integer

      response "204", "deletes the author" do
        let!(:author) { create(:author) }
        let(:id) { author.id }

        before do
          # Stub destroy! to use delete directly, since Book model doesn't exist yet
          # and destroy! triggers dependent: :restrict_with_error on the books association
          allow_any_instance_of(Author).to receive(:destroy!) { |a| a.delete }
        end

        run_test! do
          expect(Author.find_by(id: author.id)).to be_nil
        end
      end

      response "404", "author not found" do
        let(:id) { 999_999 }

        run_test! do
          expect(response).to have_http_status(:not_found)
        end
      end

      response "409", "author has books" do
        let!(:author) { create(:author) }
        let(:id) { author.id }

        before do
          books_proxy = double("BooksProxy", count: 2)
          allow_any_instance_of(Author).to receive(:books).and_return(books_proxy)
          allow_any_instance_of(Author).to receive(:destroy!).and_raise(ActiveRecord::RecordNotDestroyed.new("", author))
        end

        run_test! do
          expect(json[:error][:code]).to eq("DEPENDENCY_EXISTS")
          expect(json[:error][:message]).to include("Cannot delete author")
        end
      end
    end
  end

  path "/api/authors/{id}/books" do
    get "Lists books by author" do
      tags "Authors"
      produces "application/json"
      parameter name: :id, in: :path, type: :integer
      parameter name: :page, in: :query, type: :integer, required: false
      parameter name: :per_page, in: :query, type: :integer, required: false

      response "200", "returns books for the author" do
        let!(:author) { create(:author) }
        let(:id) { author.id }

        pending "requires Book model and books table"
        run_test!
      end

      response "404", "author not found" do
        let(:id) { 999_999 }

        run_test! do
          expect(response).to have_http_status(:not_found)
        end
      end
    end
  end
end
