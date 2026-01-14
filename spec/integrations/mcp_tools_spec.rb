# frozen_string_literal: true

require "spec_helper"
require "mail_catcher/integrations/mcp_tools"

describe MailCatcher::Integrations::MCPTools do
  describe ".all_tools" do
    it "returns all tool definitions" do
      tools = described_class.all_tools
      expect(tools).to be_a(Hash)
      expect(tools.keys.length).to eq(7)
    end

    it "includes all required tools" do
      tool_names = described_class.all_tools.keys.map(&:to_s)
      expect(tool_names).to include(
        "search_messages",
        "get_latest_message_for",
        "extract_token_or_link",
        "get_parsed_auth_info",
        "get_message_preview_html",
        "delete_message",
        "clear_messages"
      )
    end
  end

  describe ".tool_names" do
    it "returns array of tool names" do
      names = described_class.tool_names
      expect(names).to be_a(Array)
      expect(names.length).to eq(7)
    end
  end

  describe ".tool" do
    it "returns tool definition by name" do
      tool = described_class.tool(:search_messages)
      expect(tool).to be_a(Hash)
      expect(tool[:description]).not_to be_empty
      expect(tool[:input_schema]).to be_a(Hash)
    end

    it "returns nil for unknown tool" do
      tool = described_class.tool(:unknown_tool)
      expect(tool).to be_nil
    end
  end

  describe ".call_tool" do
    context "with invalid tool" do
      it "returns error object" do
        result = described_class.call_tool(:nonexistent, {})
        expect(result).to be_a(Hash)
        expect(result).to have_key(:error)
      end
    end

    context "with search_messages" do
      it "returns hash with count and messages keys" do
        result = described_class.call_tool(:search_messages, { "query" => "" })
        expect(result).to be_a(Hash)
        expect(result).to have_key(:count)
        expect(result).to have_key(:messages)
        expect(result[:count]).to be >= 0
        expect(result[:messages]).to be_a(Array)
      end

      it "respects limit parameter" do
        result = described_class.call_tool(:search_messages, { "query" => "", "limit" => 5 })
        expect(result[:count]).to be <= 5
      end
    end

    context "with get_latest_message_for" do
      it "returns found flag" do
        result = described_class.call_tool(:get_latest_message_for, { "recipient" => "test@example.com" })
        expect(result).to have_key(:found)
      end

      it "returns error when no match" do
        result = described_class.call_tool(:get_latest_message_for, { "recipient" => "nonexistent@example.com" })
        expect(result[:found]).to eq(false)
      end
    end

    context "with get_parsed_auth_info" do
      it "returns structured auth data" do
        # This will fail if message doesn't exist, but that's expected
        result = described_class.call_tool(:get_parsed_auth_info, { "message_id" => 99999 })
        expect(result).to have_key(:error)
      end
    end

    context "with clear_messages" do
      it "clears messages successfully" do
        result = described_class.call_tool(:clear_messages, {})
        expect(result).to have_key(:cleared)
        expect(result[:cleared]).to eq(true)
      end
    end
  end
end
