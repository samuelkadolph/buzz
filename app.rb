require "bundler/setup"
require "sinatra/base"

Bundler.require(:default, Sinatra::Base.environment)

class App < Sinatra::Application
  set :phone_number, (ENV["PHONE_NUMBER"] or raise "PHONE_NUMBER must be set")
  set :twilio_account_id, (ENV["TWILIO_ACCOUNT_SID"] or raise "TWILIO_NUMBER must be set")
  set :twilio_auth_token, (ENV["TWILIO_AUTH_TOKEN"] or raise "TWILIO_NUMBER must be set")
  set :twilio_number, (ENV["TWILIO_NUMBER"] or raise "TWILIO_NUMBER must be set")

  before do
    logger.info("Parameters: #{params.inspect}")
  end

  get "/" do
    "Nothing to see here."
  end

  post "/call" do
    respond do |r|
      r.Dial(settings.phone_number, callerId: settings.twilio_number)
      # r.Pause(length: 60)
      # r.Say("No answer")
    end

    # call_sid = params["CallSid"]
    # logger.info("CallSid: #{call_sid}")

    # Thread.start do
    #   logger.info("wtf")
    #   sleep 5
    #   logger.info("wtf")

    #   client = Twilio::REST::Client.new(twilio_account_id, twilio_auth_token)
    #   call = client.account.calls.get(call_sid)
    #   logger.info("here?")
    #   logger.info(call.inspect)
    #   call.update(method: "POST", url: "https://samuelkadolph-buzz.herokuapp.com/connect")
    # end
  end

  post "/connect" do
    respond do |r|
      r.Say("IT WORKS!!")
    end
  end

  post "/done" do
    respond do |r|
    end
  end

  post "/sms" do
    case params["Body"]
    when /\A\Z/
    when /\Ahelp\Z/
      response = "<Insert help here>"
    else
      response = "Unrecognized command"
    end

    respond do |r|
      r.Message(response)
    end
  end

  private
  # def client
  #   @client ||= Twilio::REST::Client.new(twilio_account_id, twilio_auth_token)
  # end

  def respond(&block)
    status 200
    content_type "text/xml"
    body Twilio::TwiML::Response.new(&block).text
  end
end
