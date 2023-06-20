require "open3"
require "singleton"
require "timeout"

class LLM
  include Singleton

  def initialize
    current_model = App.current.current_model
    App.logger.info("Initializing LLM model #{current_model.dig("model")}")

    @stdin, @stdout, @stderr, @wait_thr = Open3.popen3(%(#{App.current.llama_bin} -m #{App.current.models_path}/#{current_model.dig("model")} #{current_model.dig("parameters")}))

    @stdout_reader = Thread.new { read_output }
    @output_queue = Queue.new
  end

  def send_prompt(input)
    return "" if input.nil? || input.strip == ""

    @stdin.puts(input)
    @stdin.flush
  end

  def read_result
    result = ""

    Timeout.timeout(App.current.current_model.dig("timeout") || 120) do
      until @output_queue.empty? && result != ""

        if !@output_queue.empty?
          result += @output_queue.pop
        end
        sleep 0.1 # Adjust the sleep duration as needed to avoid excessive CPU usage
      end
    end

    result
  rescue Timeout::Error
    App.logger.error("LLM model timed out")
    "Sorry, I could't process the input"
  end

  def read_output
    @stdout.each_line do |line|
      @output_queue.push(line.chomp)
    end
  end
end
