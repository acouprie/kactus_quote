require "capybara/rspec"
require "socket"

# System specs run inside the "web" container, driven from the "selenium"
# container. Capybara must listen on all interfaces and advertise this
# container's own network address so Selenium can reach it back; the "web"
# hostname is not reliably resolved from the "selenium" container.
Capybara.server_host = "0.0.0.0"
Capybara.server_port = 45678
Capybara.app_host = "http://#{IPSocket.getaddress(Socket.gethostname)}:#{Capybara.server_port}"

Capybara.register_driver :selenium_remote_chrome do |app|
  Capybara::Selenium::Driver.new(
    app,
    browser: :remote,
    url: ENV.fetch("SELENIUM_URL", "http://selenium:4444"),
    options: Selenium::WebDriver::Options.chrome
  )
end

RSpec.configure do |config|
  config.before(:each, type: :system) do
    driven_by :selenium_remote_chrome
  end
end
