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
    end

    Assets = AssetsApp.new
  end
end
