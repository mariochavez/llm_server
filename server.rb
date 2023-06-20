# frozen_string_literal: true

require "bundler/setup"

require "json"
require "rack"
require "open3"
require "logger"

require_relative "config/app"
require_relative "lib/llm"

class Server
  CONTENT = "application/json"
  PLAIN = "text/plain"

  def initialize
    App.config(__dir__)
    LLM.instance
  end

  def call(env)
    request = Rack::Request.new(env)

    if request.post? && request.path == "/completion"

      response_data = completion_action(request)

      success_response(JSON.generate(response_data), CONTENT)
    elsif request.get? && request.path == "/heartbeat"
      App.logger.info("#{request.request_method} #{request.ip} #{request.path}")

      success_response(Time.now.to_i.to_s, PLAIN)
    else
      error_response(404, "Not Found")
    end
  rescue Errno::EPIPE
    error_response(503, "Service Unavailable")
  end

  private

  def completion_action(request)
    result = negotiate_content!(request)
    return result if !result.nil?

    result = extract_content_type!(request)
    return result if !result.nil?

    App.logger.info("#{request.request_method} #{request.ip} #{request.path}")

    # Parse body
    data = parse_body(request.body.read)
    return error_response(400, "Bad request") if data.nil?

    LLM.instance.send_prompt(data.dig("prompt"))
    result = LLM.instance.read_result
    {response: result}
  end

  def success_response(data, content_type)
    status = 200
    App.logger.info(status)

    response = Rack::Response.new(data, status)
    response["Content-Type"] = content_type
    response.finish
  end

  def parse_body(content)
    JSON.parse(content)
  rescue
    nil
  end

  def negotiate_content!(request)
    # Extract Accept header
    accept_header = request.get_header("HTTP_ACCEPT") || CONTENT
    valid_header = accept_header.include?("*/*") || accept_header.include?(CONTENT)

    return error_response(406, "Not Acceptable") if !valid_header

    nil
  end

  def extract_content_type!(request)
    # Extract Content Type
    content_type_header = request.get_header("CONTENT_TYPE") || CONTENT

    return error_response(415, "Unsupported Media Type") if content_type_header != CONTENT

    nil
  end

  def error_response(status, message)
    App.logger.error("#{status}: #{message}")
    response = Rack::Response.new(message, status)
    response["Content-Type"] = PLAIN
    response.finish
  end
end
