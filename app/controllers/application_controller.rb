class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  rescue_from Quote::ImmutableError, with: :redirect_after_immutable_refusal

  private

  def redirect_after_immutable_refusal
    flash[:alert] = I18n.t("quotes.quote_screen.immutable_alert")
    redirect_to quote_path(params[:quote_id] || params[:id]), status: :see_other
  end
end
