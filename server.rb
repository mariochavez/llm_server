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

  def initialize
    App.config(__dir__)
    LLM.instance
  end

  def call(env)
    request = Rack::Request.new(env)

    # Extract Accept header
    accept_header = request.get_header("HTTP_ACCEPT") || CONTENT
    return error_response(406, "Not Acceptable") if !accept_header.include?(CONTENT)

    # Extract Content Type
    content_type_header = request.get_header("CONTENT_TYPE") || CONTENT
    return error_response(415, "Unsupported Media Type") if content_type_header != CONTENT

    # Check verb and path
    if request.post? && request.path == "/completion"
      App.logger.info("#{request.request_method} #{request.ip} #{request.path}")

      # Parse body
      data = parse_body(request.body.read)
      return error_response(400, "Bad request") if data.nil?

      # Call Llama
      # llm_response = query_llm(data.dig("prompt"))
      # response_data = {response: llm_response}

      LLM.instance.send_prompt(data.dig("prompt"))
      result = LLM.instance.read_result
      response_data = {response: result}

      # Build response
      status = 200
      App.logger.info(status)
      response = Rack::Response.new(JSON.generate(response_data), status)
      response["Content-Type"] = CONTENT
      response.finish
    else
      error_response(404, "Not Found")
    end
  rescue Errno::EPIPE
    error_response(503, "Service Unavailable")
  end

  private

  def parse_body(content)
    JSON.parse(content)
  rescue
    nil
  end

  def error_response(status, message)
    App.logger.error("#{status}: #{message}")
    response = Rack::Response.new(message, status)
    response["Content-Type"] = "text/plain"
    response.finish
  end
end
