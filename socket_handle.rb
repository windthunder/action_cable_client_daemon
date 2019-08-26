#!/usr/bin/env ruby

# You might want to change this
ENV["RAILS_ENV"] ||= "production"

root = File.expand_path(File.dirname(__FILE__))
root = File.dirname(root) until File.exists?(File.join(root, 'config'))
Dir.chdir(root)

require File.join(root, "config", "environment")

Rails.logger.info 'socket handle start'

EventMachine.run do
  Signal.trap("TERM") { EventMachine.stop }

  uri = "ws://localhost:16384/cable/"
  client = ActionCableClient.new(uri, 'RefershChannel')

  # called whenever a welcome message is received from the server
  client.connected do
    puts 'successfully connected.'
  end

  client.subscribed do
    puts 'subscribed'
  end

  # called whenever a message is received from the server
  client.received do |message|
    # {"identifier"=>"{\"channel\":\"RefershChannel\"}", "message"=>[1, 2, 6]}
    # 從這邊不會知道server端用的channel名稱 所以要在message部分送來
    puts message
    SocketHandleWorker.perform_async(message['message']['type'], message['message']['data'])
    File.write Rails.root + 'log' + 'api_result' + "#{message['message']['type']}-#{Time.now.to_i}", message['message']['data']
  end

  retry_times = 0
  client.disconnected do
    if retry_times < 10
      client.reconnect!
      retry_times += 1
      Rails.logger.info 'try reconnect'
    else
      Rails.logger.info 'reconnect fail'
    end
  end

  EventMachine.add_periodic_timer 10 do
    Rails.logger.info "socket handle alive @ #{Time.now}"
  end
end