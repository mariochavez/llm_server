# frozen_string_literal: true

require "open3"

class LLMLegacy
  def initilize
    current_model = App.current.current_model
    App.logger.info("Initializing LLM Legacy model #{current_model.dig("model")}")
  end

  def send_prompt(prompt)
    return "" if prompt.nil? || prompt.strip == ""

    lines = []
    Open3.popen3(%(#{App.current.llama_bin} -m #{App.current.models_path}/#{current_model.dig("model")} #{current_model.dig("parameters")})) do |stdin, stdout, stderr, wait_thr|
      while line = stdout.gets
        lines << line
      end

      exit_status = wait_thr.value
      unless exit_status.success?
        error = []
        while line = stderr.gets
          error << line
        end
        return "Command failed with exit status #{exit_status.exitstatus} #{error.join}"
      end
    end

    lines.join
  end
end
