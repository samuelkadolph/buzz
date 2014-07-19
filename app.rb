require "bundler/setup"
require "sinatra/base"

Bundler.require(:default, Sinatra::Base.environment)

class App < Sinatra::Base
  set :phone_number, ENV["PHONE_NUMBER"] or raise "PHONE_NUMBER must be set"

  get "/" do
    "Nothing to see here."
  end

  post "/call" do
    content_type "text/xml"
    "<Response><Dial>#{settings.phone_number}</Dial></Response>"
  end

  post "/sms" do
    content_type "text/xml"
    "<Response></Response>"
  end
end
