# frozen_string_literal: true

require "sprockets"
require "fileutils"

module MailCatcher
  module Web
    class AssetsApp
      def initialize
        @root = File.expand_path("#{__FILE__}/../../../..")

        # In development, symlink npm dependencies into assets/javascripts so Sprockets can serve them
        setup_npm_assets_for_development if development?

        @environment = Sprockets::Environment.new(@root).tap do |sprockets|
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

      private

      def development?
        ENV['MAILCATCHER_ENV'] == 'development' || ENV['RAILS_ENV'] == 'development'
      end

      def setup_npm_assets_for_development
        # Create symlinks from node_modules packages into assets/javascripts for Sprockets to serve
        npm_assets = {
          # JavaScript files
          'node_modules/jquery/dist/jquery.min.js' => 'assets/javascripts/jquery.min.js',
          'node_modules/jquery/dist/jquery.min.map' => 'assets/javascripts/jquery.min.map',
          'node_modules/@popperjs/core/dist/umd/popper.min.js' => 'assets/javascripts/popper.min.js',
          'node_modules/@popperjs/core/dist/umd/popper.min.js.map' => 'assets/javascripts/popper.min.js.map',
          'node_modules/tippy.js/dist/tippy-bundle.umd.min.js' => 'assets/javascripts/tippy.min.js',
          # CSS files (moved from local assets to npm)
          'node_modules/tippy.js/themes/light.css' => 'assets/stylesheets/tippy-light.min.css',
          'node_modules/highlight.js/styles/atom-one-light.min.css' => 'assets/stylesheets/atom-one-light.min.css'
        }

        npm_assets.each do |source, link|
          source_path = File.expand_path(source, @root)
          link_path = File.expand_path(link, @root)

          # Skip if source doesn't exist
          next unless File.exist?(source_path)

          # Remove existing link if it's a symlink
          if File.symlink?(link_path) || File.exist?(link_path)
            begin
              File.delete(link_path)
            rescue Errno::EISDIR
              # It's a directory, skip it
              next
            end
          end

          # Create symlink
          begin
            FileUtils.mkdir_p(File.dirname(link_path))
            File.symlink(source_path, link_path)
          rescue Errno::EEXIST
            # Link already exists, that's fine
          end
        end
      end
    end

    Assets = AssetsApp.new
  end
end
