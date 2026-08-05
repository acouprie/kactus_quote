module Quotes
  class ValidationsController < ApplicationController
    before_action :set_quote

    def create
      @quote.with_lock { @quote.finalize! }

      if @quote.errors.empty?
        redirect_to @quote, status: :see_other
      else
        render status: :unprocessable_content
      end
    end

    private

    def set_quote
      @quote = Quote.find(params[:quote_id])
    end
  end
end
