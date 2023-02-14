# Copyright 2023 Axini B.V. https://www.axini.com, see: LICENSE.txt.
# frozen_string_literal: true

# The AdapterCore holds the state of the adapter. It communicates with the
# BrokerConnection and the Handler.
# The AdapterCore implements the core of a plugin-adapter. It handles the
# connection with AMP's broker (via @broker_connection) and the connection
# to the SUT (via @handler).
# The AdapterCore is responsible for encoding/decoding the Protobuf messages.
# One can see the AdapterCore as the generic part of the adapter and the
# Handler as the implementation specific part of the adapter.
class AdapterCore

  # Possible states of the Adapter(Core).
  module State
    DISCONNECTED  = :disconnected
    CONNECTED     = :connected
    ANNOUNCED     = :announced
    CONFIGURED    = :configured
    READY         = :ready
    ERROR         = :error
  end

  def initialize(name, broker_connection, handler)
    @name = name
    @broker_connection = broker_connection
    @handler = handler
    @state = State::DISCONNECTED
  end

  # Start the adapter core, which connects to AMP.
  def start
    case @state
    when State::DISCONNECTED
      logger.info "Connecting to AMP's broker."
      @broker_connection.connect
    else
      message = 'Adapter started while already connected.'
      logger.info(message)
      send_error(message)
    end
  end

  # BrokerConnection: WebSocket connection is opened.
  # - send announcement to AMP.
  def on_open
    logger.info 'on_open'

    case @state
    when State::DISCONNECTED
      @state = State::CONNECTED
      logger.info 'Sending announcement to AMP.'

      labels = @handler.supported_labels
      configuration = @handler.configuration
      send_announcement(@name, labels, configuration)
      @state = State::ANNOUNCED
    else
      message = 'Connection opened while already connected.'
      logger.info(message)
      send_error(message)
    end
  end

  # BrokerConnection: connection is closed.
  # - stop the handler
  def on_close(code, reason)
    @state = State::DISCONNECTED
    message = "Connection closed with code #{code}, and reason: #{reason}."
    message += ' The server may not be reachable.' if code == 1006

    logger.info(message)
    @handler.stop
    logger.info 'Reconnecting to AMP.'
    start # reconnect to AMP - keep the adapter alive
  end

  # Configuration received from AMP.
  # - configure the handler,
  # - start the handler,
  # - send ready to AMP (should be done by handler).
  def on_configuration(configuration)
    logger.info 'on_configuration'

    case @state
    when State::ANNOUNCED
      logger.info 'Test run is started.'
      logger.info 'Registered configuration.'
      @handler.configuration = configuration
      @state = State::CONFIGURED
      @handler.start
      # The handler should call send_ready as it knows when it is ready.
    when State::CONNECTED
      message = 'Configuration received from AMP while not yet announced.'
      logger.info(message)
      send_error(message)
    else
      message = 'Configuration received while already configured.'
      logger.info(message)
      send_error(message)
    end
  end

  # Label (stimulus) received from AMP.
  # - make handler offer the stimulus to the SUT,
  # - acknowledge the actual stimulus back to AMP.
  def on_label(label)
    logger.info "on_label: #{label.label}"

    case @state
    when State::READY
      # We do not check that the label is indeed a stimulus
      logger.info 'Forwarding label to Handler object.'
      physical_label = @handler.stimulate(label)
      send_stimulus(label, physical_label, Time.now, label.correlation_id)
    else
      message = 'Label received from AMP while not ready.'
      logger.info(message)
      send_error(message)
    end
  end

  # Reset message received from AMP.
  # - reset the handler,
  # - send ready to AMP (should be done by handler).
  def on_reset
    case @state
    when State::READY
      @handler.reset
      # The handler should call send_ready as it knows when it is ready.
    else
      message = 'Reset received from AMP while not ready.'
      logger.info(message)
      send_error(message)
    end
  end

  # Error message received from AMP.
  # - close the connection to AMP
  def on_error(message)
    @state = State::ERROR
    logger.info "Error message received from AMP: #{message}"
    @broker_connection.close(reason: message, code: 1000) # 1000 is normal closure
  end

  # Parse the binary message from AMP to a Protobuf message and call the
  # appropriate method of this AdapterCore.
  def handle_message(data)
    logger.info 'handle_message'

    payload = data.pack('c*')
    message = PluginAdapter::Api::Message.decode(payload)

    case message.type
    when :configuration
      logger.info 'Received configuration from AMP.'
      on_configuration(message.configuration)

    when :label
      logger.info "Received label from AMP: #{message.label.label}."
      on_label(message.label)

    when :reset
      logger.info "'Reset' received from AMP."
      on_reset

    when :error
      on_error(message.error.message)

    else
      message = "Received message with type #{message.type} which "\
                'is *not* supported.'
      logger.error(message)
    end
  end

  # Send response to AMP (callback for Handler).
  # We do not check whether the label is actual a response.
  def send_response(label, physical_label, timestamp)
    logger.info "Sending response to AMP: #{label.label}."
    label = label.dup
    label.physical_label = physical_label if physical_label
    label.timestamp = time_to_nsec(timestamp)
    send_message(PluginAdapter::Api::Message.new(label: label))
  end

  # Send Ready message to AMP (callback for Handler).
  def send_ready
    logger.info "Sending 'Ready' to AMP."
    ready = PluginAdapter::Api::Message::Ready.new
    send_message(PluginAdapter::Api::Message.new(ready: ready))
    @state = State::READY
  end

  # Send Error message to AMP (also callback for Handler).
  # - close the connection with AMP
  def send_error(message)
    logger.info "Sending 'Error' to AMP and closing the connection."
    error = PluginAdapter::Api::Message::Error.new(message: message)
    send_message(PluginAdapter::Api::Message.new(error: error))
    @broker_connection.close(reason: message, code: 1000) # 1000 is normal closure
  end

  def send_announcement(name, labels, configuration)
    announcement = PluginAdapter::Api::Announcement.new(
      name: name,
      labels: labels,
      configuration: configuration
    )
    send_message(PluginAdapter::Api::Message.new(announcement: announcement))
  end

  private

  # Send stimulus (back) to AMP.
  # We do not check that the label is indeed a stimulus.
  def send_stimulus(label, physical_label, timestamp, correlation_id)
    logger.info "Sending stimulus (back) to AMP: #{label.label}."
    label = label.dup
    label.physical_label = physical_label if physical_label
    label.timestamp = time_to_nsec(timestamp)
    label.correlation_id = correlation_id
    send_message(PluginAdapter::Api::Message.new(label: label))
  end

  # Sends the given `message` to the broker.
  # @param [PluginAdapter::Api::Message] message
  def send_message(message)
    @broker_connection.binary(message.to_proto.bytes)
  end

  # Number of nanoseconds in a second
  NSEC_PER_SEC = 1_000_000_000
  private_constant :NSEC_PER_SEC

  # Number of microseconds in a nanosecond
  USEC_PER_NSEC = 1_000
  private_constant :USEC_PER_NSEC

  # @param [Time, nil] time Time value (optional)
  # @return [Integer] Number of nanoseconds since epoch
  def time_to_nsec(time)
    return 0 if time.nil?

    seconds = time.to_i
    nanoseconds = time.nsec
    (seconds * NSEC_PER_SEC) + nanoseconds
  end
end
