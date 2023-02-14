# Copyright 2023 Axini B.V. https://www.axini.com, see: LICENSE.txt.
# frozen_string_literal: true

# WebSocket::Driver requires the TCPSocket object to have an attribute url.
module OpenSSL
  module SSL
    class SSLSocket
      attr_accessor :url
    end
  end
end

# The SmartDoorConnection holds the WebSocket connection with the standalone
# SmartDoor SUT.
class SmartDoorConnection
  def initialize(url, handler)
    @url     = url
    @handler = handler
    @socket  = nil
    @driver  = nil
    @thread  = nil
  end

  # Connect to AMP's plugin adapter broker and register WebSocket callbacks.
  def connect
    uri = URI.parse(@url)
    @socket = TCPSocket.new(uri.host, uri.port)
    @socket.url = @url

    @driver = WebSocket::Driver.client(@socket)

    @driver.on :open do
      logger.info 'Connected to SUT.'
      logger.info "URL: #{@url}"
      @handler.send_reset_to_sut
      @handler.send_ready_to_amp
    end

    @driver.on :close do |event|
      logger.info 'Disconnected from the SUT.'
      logger.info "Reason: #{event.reason} (code: #{event.code})"
    end

    @driver.on :message do |event|
      message = event.data
      logger.info("received from SUT: #{message}")
      @handler&.send_response_to_amp(message)
    end

    @driver.on :error do |event|
      message = "Exception occured: #{event}"
      logger.info(message)
      @handler&.send_error_to_amp(message)
    end

    @driver.start
    @thread = Thread.new { start_listening }
  end

  # Maximum length of a close reason in bytes
  REASON_LENGTH = 123
  private_constant :REASON_LENGTH

  # Close the given websocket with the given response close code and reason.
  # @param [Integer] code
  # @param [String] reason
  def close(reason: nil, code: 1000)
    return if @socket.nil?

    if reason && reason.bytesize > REASON_LENGTH
      # The websocket protocol only allows REASON_LENGTH bytes (not characters).
      reason = "#{reason[0, REASON_LENGTH - 3]}..."
    end

    @driver.close(reason, code)
    @thread&.kill
  end

  def send(message)
    @driver.text(message)
  end

  private

  # Maximum number of bytes to read in one go
  READ_SIZE_LIMIT = 1024 * 1024
  private_constant :READ_SIZE_LIMIT

  # Start the read loop on the websocket.
  def start_listening
    loop do
      begin
        break if @socket.eof?

        data = @socket.read_nonblock(READ_SIZE_LIMIT)
      rescue IO::WaitReadable
        @socket.wait_readable
        retry
      rescue IO::WaitWritable
        @socket.wait_writable
        retry
      end

      # Parse method will emit :open, :close and :message.
      @driver.parse(data)
    end
  end
end
