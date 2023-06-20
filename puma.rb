# frozen_string_literal: true

workers Integer(ENV["WEB_CONCURRENY"] || 0)
threads_count = Integer(ENV["MAX_THREADS"] || 1)
threads threads_count, threads_count

preload_app!

port ENV["PORT"] || 9292
environment ENV["RACK_ENV"] || "production"
