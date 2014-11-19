require "bundler/setup"
require "sinatra/base"

Bundler.require(:default, Sinatra::Base.environment)

class App < Sinatra::Application
  set :google_calendar, (ENV["GOOGLE_CALENDAR"] or raise "GOOGLE_CALENDAR must be set")
  set :google_client_id, (ENV["GOOGLE_CLIENT_ID"] or raise "GOOGLE_CLIENT_ID must be set")
  set :google_client_secret, (ENV["GOOGLE_CLIENT_SECRET"] or raise "GOOGLE_CLIENT_SECRET must be set")
  set :google_refresh_token, (ENV["GOOGLE_REFRESH_TOKEN"] or raise "GOOGLE_REFRESH_TOKEN must be set")
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
    respond do |r|
      if (blocks = active_blocks).any?
        unlock_door(r, blocks)
      else
        forward_to_phone(r)
      end
    end
  end

  post "/sms" do
    case params["Body"]
    when /\Ahelp\Z/i
      response = <<-HELP
Help - print this message
Lock - remove any active unlock blocks
Unlock - add unlock block for 30 minutes
Unlock NNm - add unlock block for NN minutes
Unlock NNh - add unlock block for NN hours
      HELP
    when /\Alock\Z/i
      if (blocks = active_blocks).any?
        blocks.each(&:delete)
        response = "Deleted active unlock blocks"
      else
        response = "No active unlock blocks"
      end
    when /\Aunlock (\d+) ?(?:h|hours)\Z/i
      if add_unlock_block($1.to_i * 60)
        response = "Unlocked for #{$1} hours"
      else
        response = "Failed to add unlock"
      end
    when /\Aunlock(?: (\d+) ?(?:m|minutes))?\Z/i
      minutes = ($1 || "30").to_i

      if add_unlock_block(minutes)
        response = "Unlocked for #{minutes} minutes"
      else
        response = "Failed to add unlock"
      end
    else
      response = "Unrecognized command"
    end

    respond do |r|
      r.Message(response)
    end
  end

  private
  def active_blocks
    Array(google_calendar.find_events_in_range(Time.now.utc, Time.now.utc + 1))
  end

  def add_unlock_block(minutes)
    event = google_calendar.create_event
    event.title = "Allow Guests In"
    event.start_time = Time.now
    event.end_time = Time.now + minutes * 60
    event.save
    true
  rescue => e
    logger.error("#{e} (#{e.class})")
    false
  end

  def forward_to_phone(response)
    logger.info("No event exists, calling #{settings.phone_number}")

    response.Dial(settings.phone_number, callerId: settings.twilio_number)
  end

  def google_calendar
    @google_calendar ||= Google::Calendar.new(calendar: settings.google_calendar, client_id: settings.google_client_id, client_secret: settings.google_client_secret, refresh_token: settings.google_refresh_token)
  end

  def respond(&block)
    status 200
    content_type "text/xml"
    body Twilio::TwiML::Response.new(&block).text
  end

  def twilio
    @twilio ||= Twilio::REST::Client.new(settings.twilio_account_sid, settings.twilio_auth_token)
  end

  def unlock_door(response, blocks)
    logger.info("Event exists (\"#{blocks.first.title}\"), letting guest in!")

    twilio.messages.create(from: settings.twilio_number, to: settings.phone_number, body: "Letting guest in!")

    response.Say("Unlocking")
    response.Play("https://dq02iaaall1gx.cloudfront.net/dtmf_6.wav")
    response.Say("Goodbye")
    response.Hangup
  end
end
