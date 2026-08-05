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

  ARROW_RIGHT_ICON = <<~SVG.html_safe
    <svg xmlns="http://www.w3.org/2000/svg" width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
      <path d="M5 12h14M12 5l7 7-7 7" />
    </svg>
  SVG

  PENCIL_ICON = <<~SVG.html_safe
    <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
      <path d="M12 20h9" />
      <path d="M16.5 3.5a2.121 2.121 0 0 1 3 3L7 19l-4 1 1-4Z" />
    </svg>
  SVG

  TRASH_ICON = <<~SVG.html_safe
    <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
      <path d="M3 6h18" />
      <path d="M8 6V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2" />
      <path d="M19 6l-1 14a2 2 0 0 1-2 2H8a2 2 0 0 1-2-2L5 6" />
    </svg>
  SVG

  def new_quote_trigger_link
    link_to new_quote_path, class: "button", data: { turbo_frame: "new_quote" } do
      safe_join([ PLUS_ICON, t("quotes.new_quote") ])
    end
  end

  def new_item_trigger_button(quote)
    link_to new_quote_item_path(quote), class: "button", data: { turbo_frame: "new_item" } do
      safe_join([ PLUS_ICON, t("quotes.items.new_item") ])
    end
  end

  def back_button_content(text)
    safe_join([ ARROW_LEFT_ICON, text ])
  end

  def validate_button_content(text)
    safe_join([ text, ARROW_RIGHT_ICON ])
  end

  def pencil_icon
    PENCIL_ICON
  end

  def trash_icon
    TRASH_ICON
  end
end
