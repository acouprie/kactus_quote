class QuotesController < ApplicationController
  before_action :set_quote, only: %i[show update destroy]

  def index
    @quotes = Quote.order(created_at: :desc)
  end

  def show
    @totals = QuoteTotals.new(@quote)
  end

  def new
    @quote = Quote.new
    render layout: false
  end

  def create
    @quote = Quote.new(quote_params)

    if @quote.save
      redirect_to @quote, status: :see_other
    else
      @quotes = Quote.order(created_at: :desc)
      render :index, status: :unprocessable_content
    end
  end

  def update
    if @quote.with_lock { @quote.update(quote_params) }
      redirect_to quotes_path, status: :see_other
    else
      @totals = QuoteTotals.new(@quote)
      render :show, status: :unprocessable_content
    end
  end

  def destroy
    @quote.with_lock { @quote.destroy! }
    redirect_to quotes_path, status: :see_other
  end

  private

  def set_quote
    @quote = Quote.find(params[:id])
  end

  def quote_params
    params.require(:quote).permit(:name)
  end
end
