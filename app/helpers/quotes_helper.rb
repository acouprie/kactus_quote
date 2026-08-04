module QuotesHelper
  def new_quote_trigger_link
    link_to t("quotes.new_quote"), new_quote_path, data: { turbo_frame: "new_quote" }
  end
end
