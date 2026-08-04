module QuotesHelper
  PLUS_ICON = <<~SVG.html_safe
    <svg xmlns="http://www.w3.org/2000/svg" width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
      <path d="M12 5v14M5 12h14" />
    </svg>
  SVG

  ARROW_LEFT_ICON = <<~SVG.html_safe
    <svg xmlns="http://www.w3.org/2000/svg" width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
      <path d="M19 12H5M12 19l-7-7 7-7" />
    </svg>
  SVG

  def new_quote_trigger_link
    link_to new_quote_path, class: "button", data: { turbo_frame: "new_quote" } do
      safe_join([ PLUS_ICON, t("quotes.new_quote") ])
    end
  end

  def back_button_content(text)
    safe_join([ ARROW_LEFT_ICON, text ])
  end
end
