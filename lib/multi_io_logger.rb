# frozen_string_literal: true

class MultiIOLogger < Logger
  def initialize(*targets)
    @targets = targets
  end

  def add(*args)
    @targets.each { |target| target.add(*args) }
  end

  def close
    @targets.each(&:close)
  end
end
