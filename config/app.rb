# frozen_string_literal: true

require "singleton"
require "yaml"
require_relative "../lib/multi_io_logger"

class App
  include Singleton

  attr_accessor :logger
  attr_reader :root_path

  CONFIG_FILE = "config.yml"

  def self.logger
    instance.logger
  end

  def config(root)
    @root_path = root

    load_configuration_file

    self.logger = MultiIOLogger.new(Logger.new($stdout), Logger.new(File.join(root_path, "tmp", "server.log"), "daily"))
  end

  def current_model
    model_name = @config.dig("current_model")

    if !model_name.nil?
      @current_model ||= @config.dig("models", model_name)
      return @current_model
    end

    {}
  end

  def interactive?
    @interactive ||= begin
      return true if !current_model.key?("interactive")
      current_model.dig("interactive")
    end
  end

  def llama_bin
    @llama_bin ||= @config.dig("llama_bin")
  end

  def models_path
    @models_path ||= @config.dig("models_path")
  end

  private

  def load_configuration_file
    config_file_path = validate_config_file(File.join("config", CONFIG_FILE))
    @config = YAML.load_file(config_file_path)
  end

  def validate_config_file(file_path)
    config_file_path = File.join(root_path, file_path)
    raise SecurityError, "Configuration file not found. #{file_path}" unless File.file?(config_file_path)

    config_file_path
  end
end
