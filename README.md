# Zendesk MCP Server

A Model Context Protocol (MCP) server that provides integration with Zendesk Support, allowing AI assistants to interact with your Zendesk instance through a standardized interface.

## Features

This MCP server enables the following Zendesk operations:

- **Search tickets** - Search for tickets with custom queries and filters
- **Get ticket details** - Retrieve full details of a specific ticket including comments
- **Create tickets** - Create new support tickets
- **Update tickets** - Update ticket status, priority, or add comments
- **List users** - List Zendesk users with role filtering

## Prerequisites

- Ruby (tested with Ruby 2.7+)
- A Zendesk account with API access
- Zendesk API credentials (email and API token)

## Setup

### 1. Environment Variables

Add the following environment variables to your shell configuration file (e.g., `~/.bashrc`, `~/.zshrc`, or `~/.bash_profile`):

```bash
export ZENDESK_DOMAIN="your-subdomain.zendesk.com"
export ZENDESK_EMAIL="your-email@example.com"
export ZENDESK_TOKEN="your-zendesk-api-token"
```

To generate a Zendesk API token:
1. Log into your Zendesk Admin Center
2. Navigate to Apps and integrations > APIs > Zendesk API
3. Click on the Settings tab
4. Click "Add API token" and follow the prompts

After adding these variables, reload your shell configuration:
```bash
source ~/.bashrc  # or ~/.zshrc, ~/.bash_profile depending on your shell
```

### 2. MCP Configuration

Configure the MCP server in your `.mcp.json` file. This file tells AI assistants how to connect to this server.

Create or update your `.mcp.json` file (typically located in your project root or home directory) with:

```json
{
  "mcpServers": {
    "zendesk": {
      "command": "ruby",
      "args": ["path/to/zendesk_mcp_server.rb"]
    }
  }
}
```

Replace `path/to/zendesk_mcp_server.rb` with the actual path to the `zendesk_mcp_server.rb` file in this repository.

## Usage

Once configured, AI assistants that support MCP can use this server to interact with your Zendesk instance. The server provides the following tools:

### search_tickets
Search for tickets using Zendesk's search syntax.
- `query`: Search query (required)
- `status`: Filter by status (optional: new, open, pending, hold, solved, closed)
- `limit`: Maximum results to return (optional, default: 25)

### get_ticket
Get detailed information about a specific ticket.
- `ticket_id`: The ticket ID (required)

### create_ticket
Create a new support ticket.
- `subject`: Ticket subject (required)
- `description`: Ticket body (required)
- `requester_email`: Email of the requester (required)
- `priority`: Ticket priority (optional: low, normal, high, urgent)
- `type`: Ticket type (optional: problem, incident, question, task)

### update_ticket
Update an existing ticket.
- `ticket_id`: The ticket ID (required)
- `status`: New status (optional)
- `priority`: New priority (optional)
- `comment`: Add a comment (optional)

### list_users
List Zendesk users.
- `role`: Filter by role (optional: end-user, agent, admin)
- `limit`: Maximum results (optional, default: 25)

## Resources

The server also provides these read-only resources:
- `zendesk://tickets/recent` - Recently updated tickets (last 24 hours)
- `zendesk://users/agents` - List of active support agents

## Troubleshooting

1. **Authentication errors**: Ensure your environment variables are set correctly and your API token is valid
2. **Connection errors**: Verify your ZENDESK_DOMAIN is correct (should be your-subdomain.zendesk.com)
3. **Missing dependencies**: This server uses only Ruby standard library, no gems required

## Security

- Store your API credentials securely as environment variables
- Never commit credentials to version control
- Use read-only API tokens when possible for enhanced security