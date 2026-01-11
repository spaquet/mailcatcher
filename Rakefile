# frozen_string_literal: true

require 'fileutils'
require 'rubygems'

require 'mail_catcher/version'

# XXX: Would prefer to use Rake::SprocketsTask but can't populate
# non-digest assets, and we don't want sprockets at runtime so
# can't use manifest directly. Perhaps index.html should be
# precompiled with digest assets paths?

desc 'Compile assets'
task 'assets' do
  compiled_path = File.expand_path('public/assets', __dir__)
  FileUtils.mkdir_p(compiled_path)

  require 'mail_catcher/web/assets'
  sprockets = MailCatcher::Web::Assets

  # Sprockets 4.x compatibility: access the internal environment
  environment = sprockets.instance_variable_get(:@environment)
  require 'uglifier'

  # Custom compressor that conditionally minifies based on file extension
  class SelectiveUglifier
    def initialize(uglifier)
      @uglifier = uglifier
    end

    def call(input)
      # Skip minification for already-minified files
      filename = input[:filename] || ''
      if filename.include?('.min.')
        input[:data]
      else
        @uglifier.compress(input[:data])
      end
    end
  end

  uglifier = Uglifier.new(harmony: true)
  environment.js_compressor = SelectiveUglifier.new(uglifier)

  # Compile specific assets
  # Note: CSS is now inline in views/index.erb, so we compile JavaScript and dependencies
  # Development: Sprockets serves these directly from assets/ with correct MIME types
  # Production: These are minified and compiled to public/assets/
  asset_names = ['mailcatcher.js', 'highlight.min.js', 'atom-one-light.min.css']
  asset_names.each do |asset_name|
    if asset = environment.find_asset(asset_name)
      target = File.join(compiled_path, asset_name)
      asset.write_to target
    end
  end

  # Copy image assets referenced by stylesheets
  assets_dir = File.expand_path('assets/images', __dir__)
  if Dir.exist?(assets_dir)
    Dir.glob("#{assets_dir}/*.png").each do |image_path|
      filename = File.basename(image_path)
      target = File.join(compiled_path, filename)
      FileUtils.cp(image_path, target)
    end
  end
end

desc 'Package as Gem'
task 'package' => ['assets'] do
  require 'rubygems/package'
  require 'rubygems/specification'

  spec_file = File.expand_path('mailcatcher-ng.gemspec', __dir__)
  spec = Gem::Specification.load(spec_file)

  Gem::Package.build spec
end

desc 'Release Gem to RubyGems'
task 'release' => ['package'] do
  `gem push mailcatcher-#{MailCatcher::VERSION}.gem`
end

desc "Build and push Docker images (optional: VERSION=#{MailCatcher::VERSION})"
task 'docker' do
  version = ENV.fetch('VERSION', MailCatcher::VERSION)

  Dir.chdir(__dir__) do
    system 'docker', 'buildx', 'build',
           # Push straight to Docker Hub (only way to do multi-arch??)
           '--push',
           # Build for both intel and arm (apple, graviton, etc)
           '--platform', 'linux/amd64',
           '--platform', 'linux/arm64',
           # Version respected within Dockerfile
           '--build-arg', "VERSION=#{version}",
           # Push latest and version
           '-t', 'sj26/mailcatcher:latest',
           '-t', "sj26/mailcatcher:v#{version}",
           # Use current dir as context
           '.'
  end
end

require 'rdoc/task'

RDoc::Task.new(rdoc: 'doc', clobber_rdoc: 'doc:clean', rerdoc: 'doc:force') do |rdoc|
  rdoc.title = "MailCatcher #{MailCatcher::VERSION}"
  rdoc.rdoc_dir = 'doc'
  rdoc.main = 'README.md'
  rdoc.rdoc_files.include 'lib/**/*.rb'
end

require 'rspec/core/rake_task'

RSpec::Core::RakeTask.new(:test) do |rspec|
  rspec.rspec_opts = '--format doc'
end

task test: :assets

task default: :test
