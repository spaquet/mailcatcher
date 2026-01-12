# frozen_string_literal: true

require "pathname"
require "net/http"
require "uri"

require "faye/websocket"
require "sinatra"

require "mail_catcher/bus"
require "mail_catcher/mail"

Faye::WebSocket.load_adapter("thin")

# Faye's adapter isn't smart enough to close websockets when thin is stopped,
# so we teach it to do so.
class Thin::Backends::Base
  alias :thin_stop :stop

  def stop
    thin_stop
    @connections.each_value do |connection|
      if connection.socket_stream
        connection.socket_stream.close_connection_after_writing
      end
    end
  end
end

class Sinatra::Request
  include Faye::WebSocket::Adapter
end

module MailCatcher
  module Web
    class Application < Sinatra::Base
      set :environment, MailCatcher.env
      set :prefix, MailCatcher.options[:http_path]
      set :asset_prefix, File.join(prefix, "assets")
      set :root, File.expand_path("#{__FILE__}/../../../..")

      if development?
        require "sprockets-helpers"

        configure do
          require "mail_catcher/web/assets"
          Sprockets::Helpers.configure do |config|
            config.environment = Assets
            config.prefix      = settings.asset_prefix
            config.digest      = false
            config.public_path = public_folder
            config.debug       = true
          end
        end

        helpers do
          include Sprockets::Helpers
        end
      else
        helpers do
          def asset_path(filename)
            File.join(settings.asset_prefix, filename)
          end
        end
      end

      get "/" do
        @version = MailCatcher::VERSION
        erb :index
      end

      get "/websocket-test" do
        erb :websocket_test
      end

      get "/version.json" do
        content_type :json
        JSON.generate({
          version: MailCatcher::VERSION
        })
      end

      get "/server-info" do
        @version = MailCatcher::VERSION
        @smtp_ip = MailCatcher.options[:smtp_ip]
        @smtp_port = MailCatcher.options[:smtp_port]
        @http_ip = MailCatcher.options[:http_ip]
        @http_port = MailCatcher.options[:http_port]
        @http_path = MailCatcher.options[:http_path]

        # Get current connection counts
        @http_connections = MailCatcher.http_server&.backend&.size || 0
        @smtp_connections = MailCatcher::Smtp.connection_count

        require "socket"
        if @http_ip == "127.0.0.1"
          @hostname = "localhost"
          @fqdn = "localhost"
        else
          begin
            hostname = Socket.gethostname
            fqdn = Socket.getfqdn(Socket.gethostname)
          rescue
            hostname = "unknown"
            fqdn = "unknown"
          end
          @hostname = hostname
          @fqdn = fqdn
        end

        # Fetch all SMTP transcripts and flatten entries for display
        transcripts = Mail.all_transcript_entries
        @log_entries = transcripts.flat_map do |transcript|
          transcript['entries'].map do |entry|
            entry.merge({
              'session_id' => transcript['session_id'],
              'client_ip' => transcript['client_ip'],
              'server_port' => transcript['server_port'],
              'tls_enabled' => transcript['tls_enabled']
            })
          end
        end.sort_by { |e| e['timestamp'] }

        erb :server_info
      end

      get "/logs.json" do
        content_type :json
        transcripts = Mail.all_transcript_entries
        log_entries = transcripts.flat_map do |transcript|
          transcript['entries'].map do |entry|
            entry.merge({
              'session_id' => transcript['session_id'],
              'client_ip' => transcript['client_ip'],
              'server_port' => transcript['server_port'],
              'tls_enabled' => transcript['tls_enabled']
            })
          end
        end.sort_by { |e| e['timestamp'] }

        JSON.generate(entries: log_entries)
      end

      delete "/" do
        if MailCatcher.quittable?
          MailCatcher.quit!
          status 204
        else
          status 403
        end
      end

      get "/messages" do
        if request.websocket?
          bus_subscription = nil
          ping_timer = nil
          session_id = SecureRandom.uuid
          client_ip = request.ip

          ws = Faye::WebSocket.new(request.env)

          ws.on(:open) do |_|
            $stderr.puts "[WebSocket] Connection opened (session: #{session_id}, ip: #{client_ip})"
            MailCatcher::Mail.create_websocket_connection(session_id, client_ip)

            bus_subscription = MailCatcher::Bus.subscribe do |message|
              begin
                $stderr.puts "[WebSocket] Sending message: #{message.inspect}"
                ws.send(JSON.generate(message))
              rescue => exception
                $stderr.puts "[WebSocket] Error sending message: #{exception.message}"
                MailCatcher.log_exception("Error sending message through websocket", message, exception)
              end
            end

            # Send initial ping and set up periodic ping timer (every 30 seconds)
            ping_interval = 30
            ping_timer = EventMachine.add_periodic_timer(ping_interval) do
              begin
                $stderr.puts "[WebSocket] Sending ping (session: #{session_id})"
                MailCatcher::Mail.record_websocket_ping(session_id)
                ws.send(JSON.generate({ type: "ping" }))
              rescue => exception
                $stderr.puts "[WebSocket] Error sending ping: #{exception.message}"
              end
            end
          end

          ws.on(:message) do |event|
            begin
              data = JSON.parse(event.data)
              if data["type"] == "pong"
                $stderr.puts "[WebSocket] Received pong (session: #{session_id})"
                MailCatcher::Mail.record_websocket_pong(session_id)
              end
            rescue => exception
              $stderr.puts "[WebSocket] Error processing message: #{exception.message}"
            end
          end

          ws.on(:close) do |_|
            $stderr.puts "[WebSocket] Connection closed (session: #{session_id})"
            EventMachine.cancel_timer(ping_timer) if ping_timer
            MailCatcher::Bus.unsubscribe(bus_subscription) if bus_subscription
            MailCatcher::Mail.close_websocket_connection(session_id)
          end

          ws.on(:error) do |event|
            $stderr.puts "[WebSocket] WebSocket error: #{event} (session: #{session_id})"
          end

          ws.rack_response
        else
          content_type :json
          JSON.generate(Mail.messages)
        end
      end

      delete "/messages" do
        Mail.delete!
        status 204
      end

      get "/messages/:id.json" do
        id = params[:id].to_i
        if message = Mail.message(id)
          content_type :json
          JSON.generate(message.merge({
            "formats" => [
              "source",
              ("html" if Mail.message_has_html? id),
              ("plain" if Mail.message_has_plain? id),
              ("transcript" if Mail.message_transcript(id))
            ].compact,
            "attachments" => Mail.message_attachments(id),
            "bimi_location" => Mail.message_bimi_location(id),
            "preview_text" => Mail.message_preview_text(id),
            "authentication_results" => Mail.message_authentication_results(id),
            "encryption_data" => Mail.message_encryption_data(id),
            "from_header" => Mail.message_from(id),
            "to_header" => Mail.message_to(id)
          }))
        else
          not_found
        end
      end

      get "/messages/:id.html" do
        id = params[:id].to_i
        if part = Mail.message_part_html(id)
          content_type :html, :charset => (part["charset"] || "utf8")

          body = part["body"]

          # Rewrite body to link to embedded attachments served by cid
          body = body.gsub /cid:([^'"> ]+)/, "#{id}/parts/\\1"

          body
        else
          not_found
        end
      end

      get "/messages/:id.plain" do
        id = params[:id].to_i
        if part = Mail.message_part_plain(id)
          content_type part["type"], :charset => (part["charset"] || "utf8")
          part["body"]
        else
          not_found
        end
      end

      get "/messages/:id.source" do
        id = params[:id].to_i
        if message_source = Mail.message_source(id)
          content_type "text/plain"
          message_source
        else
          not_found
        end
      end

      get "/messages/:id.eml" do
        id = params[:id].to_i
        if message_source = Mail.message_source(id)
          content_type "message/rfc822"
          message_source
        else
          not_found
        end
      end

      get "/messages/:id/transcript.json" do
        id = params[:id].to_i
        if transcript = Mail.message_transcript(id)
          content_type :json
          JSON.generate(transcript)
        else
          not_found
        end
      end

      get "/messages/:id.transcript" do
        id = params[:id].to_i
        if transcript = Mail.message_transcript(id)
          content_type :html, charset: "utf-8"
          erb :transcript, locals: { transcript: transcript }
        else
          not_found
        end
      end

      get "/messages/:id/parts/:cid" do
        id = params[:id].to_i
        if part = Mail.message_part_cid(id, params[:cid])
          content_type part["type"], :charset => (part["charset"] || "utf8")
          attachment part["filename"] if part["is_attachment"] == 1
          body part["body"].to_s
        else
          not_found
        end
      end

      delete "/messages/:id" do
        id = params[:id].to_i
        if Mail.message(id)
          Mail.delete_message!(id)
          status 204
        else
          not_found
        end
      end

      not_found do
        erb :"404"
      end
    end
  end
end
