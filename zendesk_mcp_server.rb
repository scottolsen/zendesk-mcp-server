#!/usr/bin/env ruby

require 'json'
require 'net/http'
require 'uri'
require 'base64'
require 'logger'

class ZendeskMCPServer
  def initialize
    @logger = Logger.new(STDERR)
    @logger.level = Logger::INFO

    @zendesk_domain = ENV['ZENDESK_DOMAIN']
    @zendesk_email = ENV['ZENDESK_EMAIL']
    @zendesk_token = ENV['ZENDESK_TOKEN']

    validate_configuration!
  end

  def run
    @logger.info("Starting Zendesk MCP Server")

    # MCP protocol communication happens over stdio
    STDOUT.sync = true

    while line = STDIN.gets
      begin
        request = JSON.parse(line.strip)
        response = handle_request(request)
        puts JSON.generate(response)
      rescue JSON::ParserError => e
        @logger.error("Invalid JSON received: #{e.message}")
        error_response = {
          jsonrpc: "2.0",
          id: nil,
          error: {
            code: -32700,
            message: "Parse error"
          }
        }
        puts JSON.generate(error_response)
      rescue => e
        @logger.error("Error handling request: #{e.message}")
        error_response = {
          jsonrpc: "2.0",
          id: request&.dig("id"),
          error: {
            code: -32603,
            message: "Internal error: #{e.message}"
          }
        }
        puts JSON.generate(error_response)
      end
    end
  end

  private

  def validate_configuration!
    missing = []
    missing << "ZENDESK_DOMAIN" unless @zendesk_domain
    missing << "ZENDESK_EMAIL" unless @zendesk_email
    missing << "ZENDESK_TOKEN" unless @zendesk_token

    if missing.any?
      raise "Missing required environment variables: #{missing.join(', ')}"
    end
  end

  def handle_request(request)
    case request["method"]
    when "initialize"
      handle_initialize(request)
    when "tools/list"
      handle_tools_list(request)
    when "tools/call"
      handle_tools_call(request)
    when "resources/list"
      handle_resources_list(request)
    when "resources/read"
      handle_resources_read(request)
    else
      {
        jsonrpc: "2.0",
        id: request["id"],
        error: {
          code: -32601,
          message: "Method not found"
        }
      }
    end
  end

  def handle_initialize(request)
    {
      jsonrpc: "2.0",
      id: request["id"],
      result: {
        protocolVersion: "2024-11-05",
        capabilities: {
          tools: {},
          resources: {}
        },
        serverInfo: {
          name: "zendesk-mcp-server",
          version: "1.0.0"
        }
      }
    }
  end

  def handle_tools_list(request)
    {
      jsonrpc: "2.0",
      id: request["id"],
      result: {
        tools: [
          {
            name: "search_tickets",
            description: "Search for Zendesk tickets",
            inputSchema: {
              type: "object",
              properties: {
                query: {
                  type: "string",
                  description: "Search query for tickets"
                },
                status: {
                  type: "string",
                  description: "Filter by ticket status (new, open, pending, hold, solved, closed)",
                  enum: ["new", "open", "pending", "hold", "solved", "closed"]
                },
                limit: {
                  type: "integer",
                  description: "Maximum number of results to return (default: 25)",
                  default: 25
                }
              },
              required: ["query"]
            }
          },
          {
            name: "get_ticket",
            description: "Get details of a specific ticket",
            inputSchema: {
              type: "object",
              properties: {
                ticket_id: {
                  type: "integer",
                  description: "The ticket ID"
                }
              },
              required: ["ticket_id"]
            }
          },
          {
            name: "create_ticket",
            description: "Create a new ticket",
            inputSchema: {
              type: "object",
              properties: {
                subject: {
                  type: "string",
                  description: "Ticket subject"
                },
                description: {
                  type: "string",
                  description: "Ticket description/body"
                },
                requester_email: {
                  type: "string",
                  description: "Email of the requester"
                },
                priority: {
                  type: "string",
                  description: "Ticket priority",
                  enum: ["low", "normal", "high", "urgent"]
                },
                type: {
                  type: "string",
                  description: "Ticket type",
                  enum: ["problem", "incident", "question", "task"]
                }
              },
              required: ["subject", "description", "requester_email"]
            }
          },
          {
            name: "update_ticket",
            description: "Update an existing ticket",
            inputSchema: {
              type: "object",
              properties: {
                ticket_id: {
                  type: "integer",
                  description: "The ticket ID"
                },
                status: {
                  type: "string",
                  description: "New ticket status",
                  enum: ["new", "open", "pending", "hold", "solved", "closed"]
                },
                priority: {
                  type: "string",
                  description: "New ticket priority",
                  enum: ["low", "normal", "high", "urgent"]
                },
                comment: {
                  type: "string",
                  description: "Add a comment to the ticket"
                }
              },
              required: ["ticket_id"]
            }
          },
          {
            name: "list_users",
            description: "List Zendesk users",
            inputSchema: {
              type: "object",
              properties: {
                role: {
                  type: "string",
                  description: "Filter by user role",
                  enum: ["end-user", "agent", "admin"]
                },
                limit: {
                  type: "integer",
                  description: "Maximum number of results (default: 25)",
                  default: 25
                }
              }
            }
          }
        ]
      }
    }
  end

  def handle_tools_call(request)
    tool_name = request.dig("params", "name")
    arguments = request.dig("params", "arguments") || {}

    result = case tool_name
             when "search_tickets"
               search_tickets(arguments)
             when "get_ticket"
               get_ticket(arguments)
             when "create_ticket"
               create_ticket(arguments)
             when "update_ticket"
               update_ticket(arguments)
             when "list_users"
               list_users(arguments)
             else
               { error: "Unknown tool: #{tool_name}" }
             end

    {
      jsonrpc: "2.0",
      id: request["id"],
      result: {
        content: [
          {
            type: "text",
            text: JSON.pretty_generate(result)
          }
        ]
      }
    }
  end

  def handle_resources_list(request)
    {
      jsonrpc: "2.0",
      id: request["id"],
      result: {
        resources: [
          {
            uri: "zendesk://tickets/recent",
            name: "Recent Tickets",
            description: "List of recently updated tickets",
            mimeType: "application/json"
          },
          {
            uri: "zendesk://users/agents",
            name: "Active Agents",
            description: "List of active support agents",
            mimeType: "application/json"
          }
        ]
      }
    }
  end

  def handle_resources_read(request)
    uri = request.dig("params", "uri")

    result = case uri
             when "zendesk://tickets/recent"
               search_tickets({ "query" => "updated>24hours" })
             when "zendesk://users/agents"
               list_users({ "role" => "agent" })
             else
               { error: "Unknown resource: #{uri}" }
             end

    {
      jsonrpc: "2.0",
      id: request["id"],
      result: {
        contents: [
          {
            uri: uri,
            mimeType: "application/json",
            text: JSON.pretty_generate(result)
          }
        ]
      }
    }
  end

  # Zendesk API methods
  def search_tickets(args)
    query = args["query"]
    status = args["status"]
    limit = args["limit"] || 25

    search_query = query
    search_query += " status:#{status}" if status

    zendesk_request("GET", "/api/v2/search.json?query=#{URI.encode_www_form_component(search_query)}&sort_by=updated_at&sort_order=desc&per_page=#{limit}")
  end

  def get_ticket(args)
    ticket_id = args["ticket_id"]
    zendesk_request("GET", "/api/v2/tickets/#{ticket_id}.json?include=comments,users")
  end

  def create_ticket(args)
    ticket_data = {
      ticket: {
        subject: args["subject"],
        comment: {
          body: args["description"]
        },
        requester: {
          email: args["requester_email"]
        }
      }
    }

    ticket_data[:ticket][:priority] = args["priority"] if args["priority"]
    ticket_data[:ticket][:type] = args["type"] if args["type"]

    zendesk_request("POST", "/api/v2/tickets.json", ticket_data)
  end

  def update_ticket(args)
    ticket_id = args["ticket_id"]
    update_data = { ticket: {} }

    update_data[:ticket][:status] = args["status"] if args["status"]
    update_data[:ticket][:priority] = args["priority"] if args["priority"]

    if args["comment"]
      update_data[:ticket][:comment] = { body: args["comment"] }
    end

    zendesk_request("PUT", "/api/v2/tickets/#{ticket_id}.json", update_data)
  end

  def list_users(args)
    role = args["role"]
    limit = args["limit"] || 25

    endpoint = "/api/v2/users.json?per_page=#{limit}"
    endpoint += "&role=#{role}" if role

    zendesk_request("GET", endpoint)
  end

  def zendesk_request(method, endpoint, data = nil)
    uri = URI("https://#{@zendesk_domain}#{endpoint}")

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true

    case method.upcase
    when "GET"
      request = Net::HTTP::Get.new(uri)
    when "POST"
      request = Net::HTTP::Post.new(uri)
      request.body = data.to_json if data
    when "PUT"
      request = Net::HTTP::Put.new(uri)
      request.body = data.to_json if data
    else
      raise "Unsupported HTTP method: #{method}"
    end

    # Set authentication header
    credentials = Base64.strict_encode64("#{@zendesk_email}/token:#{@zendesk_token}")
    request["Authorization"] = "Basic #{credentials}"
    request["Content-Type"] = "application/json"
    request["Accept"] = "application/json"

    response = http.request(request)

    if response.code.to_i >= 200 && response.code.to_i < 300
      JSON.parse(response.body)
    else
      {
        error: "HTTP #{response.code}: #{response.message}",
        body: response.body
      }
    end
  rescue => e
    {
      error: "Request failed: #{e.message}"
    }
  end
end

# Run the server if this file is executed directly
if __FILE__ == $0
  begin
    server = ZendeskMCPServer.new
    server.run
  rescue => e
    STDERR.puts "Failed to start server: #{e.message}"
    exit 1
  end
end
