# frozen_string_literal: true

workers Integer(ENV["WEB_CONCURRENY"] || 2)
threads_count = Integer(ENV["MAX_THREADS"] || 2)
threads threads_count, threads_count

preload_app!

rackup DefaultRackup
port ENV["PORT"] || 9292
environment ENV["RACK_ENV"] || "production"
