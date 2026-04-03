module Api
  class BaseController < ApplicationController
    include ErrorHandler
    include Paginatable
    include Sortable
  end
end
