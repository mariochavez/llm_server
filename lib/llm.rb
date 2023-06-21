require "open3"
require "singleton"
require "timeout"

class LLM
  include Singleton

  def initialize
    current_model = App.instance.current_model

    model = current_model.dig("model")
    reverse_prompt = current_model.dig("reverse_prompt")
    parameters = current_model.dig("parameters")

    @suffix = current_model.dig("suffix")

    if model.nil? || model == "" || @suffix.nil? || @suffix == "" || reverse_prompt.nil? || reverse_prompt == ""
      raise ConfigurationError.new("Model configuration is invalid or incomplete: #{current_model}")
    end

    interactive_parameters = %(--interactive-first -i -r "#{reverse_prompt}" --in-prefix " " --in-suffix "#{@suffix}")
    command = %(#{App.instance.llama_bin} -m #{App.instance.models_path}/#{model} #{interactive_parameters} #{parameters})

    App.logger.info("Initializing LLM model #{model}")
    App.logger.info(command)

    @timeout = App.instance.current_model.dig("timeout") || 120
    @init = true

    @stdin, @stdout, @stderr, @wait_thr = Open3.popen3(command)

    @stdout_reader = Thread.new { read_output }
    @output_queue = Queue.new
  end

  def send_prompt(input)
    return if input.nil? || input.strip == ""

    @stdin.puts(input)
    @stdin.flush
  end

  def read_result
    result = ""

    suffix_present = false

    Timeout.timeout(@timeout) do
      until @output_queue.empty? && result != ""

        if !@output_queue.empty?
          line = @output_queue.pop

          if line.include?(@suffix)
            suffix_present = true
            line = ""

            App.logger.debug("Got suffix, waiting for response ...")
            sleep 0.1
          elsif suffix_present
            if !@output_queue.empty?
              App.logger.debug("Waiting for response ...")
              sleep 0.1
            end
          else
            suffix_present = false
          end

          result += line
        end
      end
    end

    result
  rescue Timeout::Error
    @output_queue.clear
    App.logger.error("LLM model timed out")
    "Sorry, I could't process the input"
  end

  def read_output
    @stdout.each_line do |line|
      if @init && line.include?("llama_init_from_file")
        @init = false
        App.logger.info("Model initiated")
      else
        @output_queue.push(line.chomp)
      end
    end
  end
end
