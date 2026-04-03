module Api
  class AuthorsController < BaseController
    SORTABLE_FIELDS = {
      "last_name" => "authors.last_name",
      "first_name" => "authors.first_name",
      "created_at" => "authors.created_at",
      "book_count" => "book_count"
    }.freeze

    DEFAULT_SORT = { column: "authors.last_name", direction: "asc" }.freeze

    BOOK_SORTABLE_FIELDS = {
      "title" => "books.title",
      "published_year" => "books.published_year",
      "date_added" => "books.date_added",
      "rating" => "books.rating",
      "page_count" => "books.page_count"
    }.freeze

    BOOK_DEFAULT_SORT = { column: "books.date_added", direction: "desc" }.freeze

    before_action :set_author, only: [ :show, :update, :destroy, :books ]

    def index
      authors = Author.filter_by(params, %w[search])

      if books_table_exists?
        authors = authors
          .left_joins(:books)
          .select("authors.*, COUNT(books.id) AS book_count")
          .group("authors.id")

        authors = apply_sort(authors)
        result = paginate(authors)
        return unless result

        records, meta = result
        data = records.map { |author| serialize_author(author, book_count: author.read_attribute("book_count").to_i) }
      else
        authors = apply_sort(authors)
        result = paginate(authors)
        return unless result

        records, meta = result
        data = records.map { |author| serialize_author(author, book_count: 0) }
      end

      render_success(data: data, meta: meta)
    end

    def show
      book_count = books_table_exists? ? @author.books.count : 0
      recent_books = books_table_exists? ? @author.books.order(date_added: :desc).limit(5) : []

      data = serialize_author(@author, book_count: book_count)
      data[:recent_books] = recent_books.map { |book| serialize_book_summary(book) }

      render_success(data: data)
    end

    def create
      author = Author.new(author_params)

      if author.save
        render_success(data: serialize_author(author, book_count: 0), status: :created)
      else
        render_error("VALIDATION_ERROR", :unprocessable_entity, "Validation failed",
          details: format_errors(author))
      end
    end

    def update
      if @author.update(author_params)
        book_count = books_table_exists? ? @author.books.count : 0
        render_success(data: serialize_author(@author, book_count: book_count))
      else
        render_error("VALIDATION_ERROR", :unprocessable_entity, "Validation failed",
          details: format_errors(@author))
      end
    end

    def destroy
      @author.destroy!
      head :no_content
    rescue ActiveRecord::RecordNotDestroyed
      count = @author.books.count
      render_error("DEPENDENCY_EXISTS", :conflict,
        "Cannot delete author: #{count} #{count == 1 ? 'book is' : 'books are'} associated with this author")
    end

    def books
      books_scope = @author.books
      books_scope = apply_sort(books_scope, sortable_fields: BOOK_SORTABLE_FIELDS, default_sort: BOOK_DEFAULT_SORT)
      result = paginate(books_scope)
      return unless result

      records, meta = result
      data = records.map { |book| serialize_book_summary(book) }
      render_success(data: data, meta: meta)
    end

    private

    def set_author
      @author = Author.find(params[:id])
    end

    def author_params
      params.expect(author: [ :first_name, :last_name, :bio, :birth_year, :death_year, :website ])
    end

    def serialize_author(author, book_count: 0)
      {
        id: author.id,
        first_name: author.first_name,
        last_name: author.last_name,
        bio: author.bio,
        birth_year: author.birth_year,
        death_year: author.death_year,
        website: author.website,
        book_count: book_count,
        created_at: author.created_at,
        updated_at: author.updated_at
      }
    end

    def serialize_book_summary(book)
      {
        id: book.id,
        title: book.title,
        genre: book.genre,
        rating: book.rating,
        read_status: book.read_status,
        published_year: book.published_year
      }
    end

    def format_errors(record)
      record.errors.map { |error| { field: error.attribute.to_s, message: error.message } }
    end

    def books_table_exists?
      @books_table_exists = ActiveRecord::Base.connection.table_exists?("books") if @books_table_exists.nil?
      @books_table_exists
    end
  end
end
