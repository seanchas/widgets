# This file is used by Rack-based servers to start the application.

require ::File.expand_path('../config/environment',  __FILE__)

require 'rack/proxy'

use Rack::Proxy do |request|
  result = false

  if request.path.start_with?("/cs")
    result = URI.parse("http://beta.micex.ru#{request.path}?#{request.query_string}")
  end
  
  if request.path.start_with?("/iss")
    result = URI.parse("http://beta.micex.ru#{request.path}?#{request.query_string}")
  end

  result
end

run Widgets::Application
