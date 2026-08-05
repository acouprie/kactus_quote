module Quotes
  class ItemsController < ApplicationController
    before_action :set_quote
    before_action :set_item, only: %i[edit update destroy]

    def new
      @item = @quote.quote_items.new
      render layout: false
    end

    def create
      @item = @quote.quote_items.new(item_params)
      @quote.with_lock { @item.save }

      @totals = QuoteTotals.new(@quote) if @item.persisted?
      render status: @item.persisted? ? :ok : :unprocessable_content
    end

    def edit
      @totals = QuoteTotals.new(@quote)
      render layout: false
    end

    def update
      @quote.with_lock { @item.update(item_params) }

      @totals = QuoteTotals.new(@quote)
      render status: @item.errors.empty? ? :ok : :unprocessable_content
    end

    def destroy
      @quote.with_lock { @item.destroy! }
      @totals = QuoteTotals.new(@quote)
    end

    private

    def set_quote
      @quote = Quote.find(params[:quote_id])
    end

    def set_item
      @item = @quote.quote_items.find(params[:id])
    end

    def item_params
      params.require(:quote_item).permit(:name, :quantity, :unit_price_excl_vat, :vat_rate)
    end
  end
end
