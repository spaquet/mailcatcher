# frozen_string_literal: true

require "sprockets"

module MailCatcher
  module Web
    class AssetsApp
      def initialize
        @environment = Sprockets::Environment.new(File.expand_path("#{__FILE__}/../../../..")).tap do |sprockets|
          Dir["#{sprockets.root}/{,vendor}/assets/*"].each do |path|
            sprockets.append_path(path)
          end
        end
      end

      def call(env)
        # Rack 3 compatibility: strip the /assets prefix before passing to Sprockets
        path_info = env["PATH_INFO"]
        if path_info.start_with?("/assets")
          env["PATH_INFO"] = path_info.sub(%r{^/assets}, "")
        end

        @environment.call(env)
      end

      # Delegate methods to the environment for Rakefile asset compilation
      def css_compressor=(compressor)
        @environment.css_compressor = compressor
      end

      def js_compressor=(compressor)
        @environment.js_compressor = compressor
      end

      def each_logical_path(pattern, &block)
        @environment.each_logical_path(pattern, &block)
      end

      def find_asset(logical_path)
        @environment.find_asset(logical_path)
      end
    end

    Assets = AssetsApp.new
  end
end
