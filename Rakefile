require "bundler/setup"
require "google_calendar"

task :check do
  google_calendar = Google::Calendar.new(calendar: ENV["GOOGLE_CALENDAR"], client_id: ENV["GOOGLE_CLIENT_ID"], client_secret: ENV["GOOGLE_CLIENT_SECRET"], refresh_token: ENV["GOOGLE_REFRESH_TOKEN"])

  blocks = Array(google_calendar.find_events_in_range(Time.now.utc, Time.now.utc + 1))

  if blocks.any?
    puts "Active block: '#{blocks[0].title}' from #{blocks[0].start_time} to #{blocks[0].end_time}"
  else
    puts "No active block"
  end
end
