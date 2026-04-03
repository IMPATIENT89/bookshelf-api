module ErrorHandler
  extend ActiveSupport::Concern

  included do
    # Rails checks rescue_from handlers in reverse declaration order.
    # StandardError must be declared FIRST so it is checked LAST.
    rescue_from StandardError do |exception|
      Rails.logger.error("#{exception.class}: #{exception.message}\n#{exception.backtrace&.first(10)&.join("\n")}")
      render_error("INTERNAL_ERROR", :internal_server_error, "An unexpected error occurred")
    end

    rescue_from ActiveRecord::RecordNotFound do |exception|
      render_error("NOT_FOUND", :not_found, "#{exception.model} with id '#{exception.id}' not found")
    end

    rescue_from ActiveRecord::RecordNotUnique do |exception|
      field = if exception.message.to_s =~ /UNIQUE constraint failed: \w+\.(\w+)/
        $1
      end
      message = field ? "A record with this #{field} already exists" : "A record with this value already exists"
      render_error("CONFLICT", :conflict, message)
    end

    rescue_from ActionController::ParameterMissing do |exception|
      render_error("BAD_REQUEST", :bad_request, exception.message)
    end

    rescue_from ActionDispatch::Http::Parameters::ParseError do |_exception|
      render_error("BAD_REQUEST", :bad_request, "Invalid JSON in request body")
    end

    before_action :enforce_json_content_type, only: [ :create, :update ]
  end

  private

  def render_success(data:, meta: nil, status: :ok)
    body = { data: data }
    body[:meta] = meta if meta.present?
    render json: body, status: status
  end

  def render_error(code, status, message, details: nil)
    error = { code: code, message: message }
    error[:details] = details if details.present?
    render json: { error: error }, status: status
  end

  def enforce_json_content_type
    return if request.get? || request.delete?
    return if request.content_type&.include?("application/json")

    render_error("BAD_REQUEST", :bad_request, "Content-Type must be application/json")
  end
end
