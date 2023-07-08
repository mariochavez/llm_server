require "open3"
require "singleton"
require "timeout"

class LLM
  include Singleton

  def initialize
    current_model = App.instance.current_model

    @model = current_model.dig("model")
    @reverse_prompt = current_model.dig("reverse_prompt")
    @parameters = current_model.dig("parameters")
    @suffix = current_model.dig("suffix")

    run_interactive_model(model: @model, reverse_prompt: @reverse_prompt, parameters: @parameters, suffix: @suffix) if App.instance.interactive?
  end

  def send_prompt(input)
    return "" if input.nil? || input.strip == ""

    if App.instance.interactive?
      @output_queue.clear

      @stdin.puts(input)
      @stdin.flush

      return ""
    end

    run_non_interactive_model(model: @model, parameters: @parameters, prompt: input)
  end

  def read_result
    result = ""

    Timeout.timeout(@timeout) do
      until @output_queue.empty? && result != ""

        if !@output_queue.empty?
          line = @output_queue.pop

          result += "#{line}\n"
          sleep 2
        end
      end
    end

    result
  rescue Timeout::Error
    @output_queue.clear
    App.logger.error("LLM model timed out")
    "Sorry, I could't process the input"
  end

  private

  def read_output
    @stdout.each_line do |line|
      if @init && line.include?("llama_new_context")
        @init = false
        App.logger.info("Model initiated")
      else
        @output_queue.push(line.chomp)
      end
    end
  end

  def run_interactive_model(model:, reverse_prompt:, parameters:, suffix:)
    if model.nil? || model == "" || suffix.nil? || suffix == "" || reverse_prompt.nil? || reverse_prompt == ""
      raise ConfigurationError.new("Model configuration is invalid or incomplete: #{current_model}")
    end

    interactive_parameters = %(--interactive-first -i -r "#{reverse_prompt}" -r "###" --in-prefix " " --in-suffix "#{suffix}")
    command = %(#{App.instance.llama_bin} -m #{App.instance.models_path}/#{model} #{interactive_parameters} #{parameters})

    App.logger.info("Initializing LLM model #{model}")
    App.logger.info(command)

    @timeout = App.instance.current_model.dig("timeout") || 120
    @init = true

    @stdin, @stdout, @stderr, @wait_thr = Open3.popen3(command)

    @stdout_reader = Thread.new { read_output }
    @output_queue = Queue.new
  end

  def run_non_interactive_model(model:, parameters:, prompt:)
    current_model = App.instance.current_model

    if model.nil? || model == ""
      raise ConfigurationError.new("Model configuration is invalid or incomplete: #{current_model}")
    end

    command = %(#{App.instance.llama_bin} -m #{App.instance.models_path}/#{model} -p '#{prompt.gsub(/'/, "\"")}' #{parameters})

    App.logger.info("Initializing LLM model #{model}")
    App.logger.info(command)

    stdout_str, error_str, status = Open3.capture3(command)
    if status.success?
      result = stdout_str
      strip_before = current_model.dig("strip_before")
      result = result.split(strip_before)[-1] if !strip_before.nil?

      return result
    end

    App.logger.debug("LLM Error: #{error_str}")
    "Model had a problem executing your command"
  end
end
