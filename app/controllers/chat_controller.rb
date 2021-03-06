class ChatController < WebsocketRails::BaseController
  include ActionView::Helpers::SanitizeHelper

  def initialize_session

  end

  def system_wide_message(event, message)
    channels = connection_store.collect_all(:channels).flatten.uniq
    channels.each do |channel|
      WebsocketRails[channel].trigger(event, {
        user_name: 'Admin',
        received: Time.now.to_s(:short),
        message_body: message,
        channel_name: channel
      })
    end
  end

  def user_message(event, message, channel)
    WebsocketRails[channel].trigger(event, {
      user_name: current_user.handle,
      received: Time.now.to_s(:short),
      message_body: ERB::Util.html_escape(message),
      channel_name: channel
    })
  end

  def channel_message(event, channel, action)
    WebsocketRails[channel].trigger(event, {
        user_name: 'Server',
        received: Time.now.to_s(:short),
        message_body: "#{connection_store[:user][:handle]} #{action} the channel.",
        channel_name: channel
      })
  end

  def client_connected
    connection_store[:user] = { handle: current_user.handle }
    connection_store[:channels] = []
  end

  def new_message
    if current_user.admin && message[:message_body].start_with?('/admin')
      system_wide_message(:new_message, message[:message_body][7..-1])
    else
      user_message(:new_message, message[:message_body], message[:channel_name])
    end
  end

  def new_channel_message
    channel_message(:new_message, message[:channel_name], message[:user_action])
    connection_store[:channels] << message[:channel_name]
    broadcast_user_list(message[:channel_name])
  end

  def delete_user
    user_channels = []
    connection_store[:channels].each do |channel|
      user_channels << channel
      channel_message(:new_message, channel, "has left")
    end
    connection_store[:user] = nil
    user_channels.each do |channel|
      broadcast_user_list(channel)
    end
  end

  def broadcast_user_list(channel)
    users = []
    WebsocketRails[channel].subscribers.each do |conn|
      users << conn.user.handle
    end
    WebsocketRails[channel].trigger(:user_list, {
      users: users,
      channel_name: channel
      })
  end
end
