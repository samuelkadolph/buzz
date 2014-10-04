require "bundler/setup"
require "sinatra/base"

Bundler.require(:default, Sinatra::Base.environment)

class App < Sinatra::Application
  set :google_calendar, (ENV["GOOGLE_CALENDAR"] or raise "GOOGLE_CALENDAR must be set")
  set :google_email, (ENV["GOOGLE_EMAIL"] or raise "GOOGLE_EMAIL must be set")
  set :google_password, (ENV["GOOGLE_PASSWORD"] or raise "GOOGLE_PASSWORD must be set")
  set :phone_number, (ENV["PHONE_NUMBER"] or raise "PHONE_NUMBER must be set")
  set :twilio_account_sid, (ENV["TWILIO_ACCOUNT_SID"] or raise "TWILIO_ACCOUNT_SID must be set")
  set :twilio_auth_token, (ENV["TWILIO_AUTH_TOKEN"] or raise "TWILIO_AUTH_TOKEN must be set")
  set :twilio_number, (ENV["TWILIO_NUMBER"] or raise "TWILIO_NUMBER must be set")

  before do
    logger.info("Parameters: #{params.inspect}")
  end

  use Rack::TwilioWebhookAuthentication, settings.twilio_auth_token, "/call", "/sms"

  get "/" do
    "Nothing to see here"
  end

  post "/call" do
    events = Array(google_calendar.find_events_in_range(Time.now.utc, Time.now.utc + 1))

    respond do |r|
      if events.any?
        logger.info("Event exists (\"#{events.first.title}\"), letting guest in!")
        twilio.messages.create(from: settings.twilio_number, to: settings.phone_number, body: "Letting guest in!")
        r.Play("https://dq02iaaall1gx.cloudfront.net/dtmf_6.wav")
      else
        logger.info("No event exists, calling #{settings.phone_number}")
        r.Dial(settings.phone_number, callerId: settings.twilio_number)
      end
    end
  end

  post "/sms" do
    case params["Body"]
    when /\Ahelp\Z/i
      response = "<Insert help here>"
    when /\Aunlock (\d+)h\Z/i
      response = "Unlocked for #{$1} hours"
    when /\Aunlock(?: (\d+)m)?\Z/i
      minutes = $1 || "30"
      response = "Unlocked for #{minutes} minutes"
    else
      response = "Unrecognized command"
    end

    respond do |r|
      r.Message(response)
    end
  end

  private
  def google_calendar
    @google_calendar ||= Google::Calendar.new(app_name: "buzz", calendar: settings.google_calendar, password: settings.google_password, username: settings.google_email)
  end

  def respond(&block)
    status 200
    content_type "text/xml"
    body Twilio::TwiML::Response.new(&block).text
  end

  def twilio
    @twilio ||= Twilio::REST::Client.new(settings.twilio_account_sid, settings.twilio_auth_token)
  end
end
