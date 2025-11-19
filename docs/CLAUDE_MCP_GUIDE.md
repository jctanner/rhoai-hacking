# MCP Server Guide

## What is MCP

Model Context Protocol (MCP) is an open protocol that lets AI applications talk to external systems. Think of it like a standardized API layer between Claude (or any LLM) and your data/tools.

Instead of every app building custom integrations, MCP provides a common interface. You write an MCP server once, and any MCP-compatible client can use it.

## Core Concepts

MCP servers expose three things:

**Tools**: Functions Claude can call
- Takes arguments, returns results
- Like a normal function but callable by the LLM
- Example: `get_weather(city: str)`, `search_database(query: str)`

**Resources**: Data Claude can read
- Static or dynamic content
- URI-addressable (like `file://path` or `db://table/id`)
- Example: file contents, database records, API responses

**Prompts**: Templated messages
- Pre-built prompt templates Claude can use
- Less common than tools/resources

## Requirements

- Python 3.10 or higher
- The `mcp` package

```bash
pip install "mcp[cli]"
```

That's it. The SDK handles the protocol details.

## Writing a Simple Server

Basic example - a calculator server:

```python
from mcp.server.fastmcp import FastMCP

mcp = FastMCP("Calculator")

@mcp.tool()
def add(a: int, b: int) -> int:
    """Add two numbers"""
    return a + b

@mcp.tool()
def multiply(a: int, b: int) -> int:
    """Multiply two numbers"""
    return a * b

if __name__ == "__main__":
    mcp.run(transport="stdio")
```

Save as `calculator.py` and you have an MCP server.

**How it works:**
- `FastMCP()` creates a server instance
- `@mcp.tool()` decorator registers functions as callable tools
- `mcp.run(transport="stdio")` starts the server using stdin/stdout

The docstring is important - Claude sees it and uses it to understand what the function does.

## Adding Resources

Resources are for data retrieval:

```python
@mcp.resource("config://settings")
def get_settings() -> str:
    """Get application settings"""
    return '{"theme": "dark", "debug": true}'

@mcp.resource("user://{user_id}")
def get_user(user_id: str) -> str:
    """Get user data by ID"""
    # In real code, query a database
    return f'{{"id": "{user_id}", "name": "User {user_id}"}}'
```

Resources use URI patterns. The `{user_id}` part is a parameter.

## Async Tools

If your tool does I/O (database, API calls, file operations), use async:

```python
import asyncio
import httpx

@mcp.tool()
async def fetch_url(url: str) -> str:
    """Fetch content from a URL"""
    async with httpx.AsyncClient() as client:
        response = await client.get(url)
        return response.text
```

MCP handles the async/await for you.

## Testing Locally

The SDK includes a dev server:

```bash
mcp dev ./calculator.py
```

This launches a web interface where you can:
- See all registered tools/resources
- Call them with test inputs
- View responses and errors

Much faster than configuring Claude Desktop for every test.

## Integrating with Claude Desktop

Edit your Claude Desktop config. Location depends on OS:

**macOS**: `~/Library/Application Support/Claude/claude_desktop_config.json`
**Windows**: `%APPDATA%\Claude\claude_desktop_config.json`
**Linux**: `~/.config/Claude/claude_desktop_config.json`

Add your server:

```json
{
  "mcpServers": {
    "calculator": {
      "command": "python",
      "args": ["/absolute/path/to/calculator.py"]
    }
  }
}
```

Use absolute paths. Restart Claude Desktop.

If it worked, you'll see a small indicator showing connected MCP servers. Ask Claude to use your tools: "Add 5 and 3" should trigger the calculator.

## Integrating with Claude Code

Claude Code (this CLI) uses MCP servers through `~/.claude.json` config file.

**Config file location:**
- Primary: `~/.claude.json` (user-level)
- Project-specific: `.claude/config.json` (in your project root)
- Enterprise: `/etc/claude/config.json` (system-wide)

Claude Code loads configs in order: system → user → project. Project settings override user settings.

**Adding servers via CLI:**

```bash
# Add a stdio server
claude mcp add --transport stdio calculator /absolute/path/to/calculator.py

# Add with arguments
claude mcp add --transport stdio myserver /usr/bin/python -- /path/to/server.py --debug

# Add HTTP server
claude mcp add --transport http github https://api.github.com/mcp
```

**Adding servers manually:**

Edit `~/.claude.json`:

```json
{
  "mcpServers": {
    "calculator": {
      "command": "python",
      "args": ["/absolute/path/to/calculator.py"]
    },
    "weather": {
      "command": "/home/user/venv/bin/python",
      "args": ["/home/user/servers/weather.py"],
      "env": {
        "API_KEY": "your-api-key-here"
      }
    },
    "remote-api": {
      "type": "http",
      "url": "https://example.com/mcp",
      "headers": {
        "Authorization": "Bearer token-here"
      }
    }
  }
}
```

**Checking configured servers:**

```bash
# List all MCP servers
claude mcp list

# Test a specific server
claude mcp test calculator

# Get server info
claude mcp info calculator
```

**Important differences from Claude Desktop:**

1. **Output limits**: MCP tools in Claude Code have a 10,000 token output limit by default. Change it:
   ```bash
   export MAX_MCP_OUTPUT_TOKENS=50000
   ```

2. **No restart required**: Unlike Claude Desktop, Claude Code picks up config changes automatically. Just save the file.

3. **Environment variables**: Pass secrets via `env` field rather than hardcoding:
   ```json
   {
     "mcpServers": {
       "myserver": {
         "command": "python",
         "args": ["/path/to/server.py"],
         "env": {
           "DATABASE_URL": "postgresql://...",
           "API_SECRET": "secret-here"
         }
       }
     }
   }
   ```

4. **Multiple transport types**:
   - `stdio`: Standard input/output (most common)
   - `http`: HTTP endpoint
   - `sse`: Server-Sent Events

**Verifying it works:**

After adding a server, just ask Claude Code to use it:

```
You: Use the calculator to add 15 and 27
Claude Code: [calls the calculator tool] The result is 42.
```

If tools aren't showing up, check:
- Run `claude mcp list` to see if server is registered
- Run `claude mcp test servername` to verify connection
- Check absolute paths in config
- Verify Python environment has dependencies installed

## Project-Specific MCP Configuration

Instead of configuring MCP servers globally in `~/.claude.json`, you can create a **project-specific** configuration using a `.mcp.json` file in your project directory.

**Why use project-specific configuration?**

- Different projects need different MCP servers
- Keep server configurations with the project code
- Share MCP setup with team members via version control
- Avoid cluttering global config with project-specific tools

**Creating a `.mcp.json` file:**

In your project root, create a `.mcp.json` file:

```json
{
  "mcpServers": {
    "rpm-query": {
      "type": "stdio",
      "command": "/home/user/project/mcp-server/venv/bin/python",
      "args": ["/home/user/project/mcp-server/server.py"]
    },
    "project-tools": {
      "type": "stdio",
      "command": "python",
      "args": ["./tools/mcp_server.py"],
      "env": {
        "PROJECT_ROOT": "/home/user/project"
      }
    }
  }
}
```

**Configuration structure:**

- Uses the same format as `~/.claude.json`
- `type`: Transport type (usually `"stdio"`)
- `command`: Path to Python interpreter (can be absolute or relative)
- `args`: Array of arguments (path to server script)
- `env`: (optional) Environment variables for the server

**Example from this project:**

```json
{
  "mcpServers": {
    "rpm-query": {
      "type": "stdio",
      "command": "/home/jtanner/workspace/github/jctanner.redhat/2025_11_19_claude_mcp_tests/rpm-query-mcp/venv/bin/python",
      "args": ["/home/jtanner/workspace/github/jctanner.redhat/2025_11_19_claude_mcp_tests/rpm-query-mcp/server.py"]
    }
  }
}
```

This configures an `rpm-query` MCP server that provides tools to query installed RPM packages on the system.

**How Claude Code finds the config:**

When you run Claude Code, it looks for MCP configurations in this order:

1. System-wide: `/etc/claude/config.json`
2. User-level: `~/.claude.json`
3. Project-specific: `.mcp.json` in current directory

Project-specific settings override user-level settings, which override system settings. This means you can have:
- Global servers available everywhere (in `~/.claude.json`)
- Project servers only available in specific directories (in `.mcp.json`)

**Best practices:**

1. **Use absolute paths** for production, relative paths for portability
2. **Use venv Python**: Point to the virtual environment's Python to ensure dependencies are available
3. **Document in README**: Tell collaborators about the `.mcp.json` file
4. **Version control**: Commit `.mcp.json` to git so the team gets the same tools
5. **Don't commit secrets**: Use environment variables or `.env` files (add to `.gitignore`)

**Reloading changes:**

Unlike some other tools, Claude Code automatically picks up changes to `.mcp.json`:
- No restart required
- Just save the file and the new configuration is active
- You may need to restart the chat session to use updated servers

## Transport Types

Servers can run in different modes:

**stdio**: Communicate via stdin/stdout (default)
- Used by Claude Desktop
- Simple, works everywhere
- Run with `mcp.run(transport="stdio")`

**HTTP/WebSocket**: Network-based
- For remote servers
- More complex but allows distributed architecture
- Run with `mcp.run(transport="sse")` for Server-Sent Events

Most local servers use stdio.

## Structured Outputs

You can use Pydantic models for type safety:

```python
from pydantic import BaseModel

class User(BaseModel):
    id: str
    name: str
    email: str

@mcp.tool()
def get_user_typed(user_id: str) -> User:
    """Get user with typed response"""
    return User(
        id=user_id,
        name=f"User {user_id}",
        email=f"user{user_id}@example.com"
    )
```

The SDK validates return types and converts them to JSON.

## Real-World Example

Weather server using an actual API:

```python
import httpx
from mcp.server.fastmcp import FastMCP

mcp = FastMCP("Weather")

@mcp.tool()
async def get_forecast(lat: float, lon: float) -> dict:
    """Get weather forecast for coordinates"""
    url = f"https://api.weather.gov/points/{lat},{lon}"

    async with httpx.AsyncClient() as client:
        # Get forecast URL for location
        response = await client.get(url)
        data = response.json()
        forecast_url = data["properties"]["forecast"]

        # Get actual forecast
        forecast_response = await client.get(forecast_url)
        return forecast_response.json()

@mcp.tool()
async def get_alerts(state: str) -> dict:
    """Get weather alerts for a US state"""
    url = f"https://api.weather.gov/alerts?area={state.upper()}"

    async with httpx.AsyncClient() as client:
        response = await client.get(url)
        return response.json()

if __name__ == "__main__":
    mcp.run(transport="stdio")
```

## Caveats and Gotchas

**Don't write to stdout**
The server uses stdout for protocol messages. Use stderr for logging or use Python's logging module:

```python
import logging
logging.basicConfig(level=logging.INFO, handlers=[logging.StreamHandler()])
logger = logging.getLogger(__name__)

@mcp.tool()
def my_tool():
    logger.info("This goes to stderr, not stdout")
    return "result"
```

**Use absolute paths**
In config files, always use absolute paths to your Python scripts. Relative paths won't work because Claude Desktop's working directory isn't predictable.

**Dependencies**
Your server needs its dependencies installed in the Python environment that runs it. If you use a virtual environment, point the config to that Python:

```json
{
  "mcpServers": {
    "myserver": {
      "command": "/path/to/venv/bin/python",
      "args": ["/path/to/server.py"]
    }
  }
}
```

**Error handling**
Exceptions in tools bubble up to Claude as error messages. Handle expected errors gracefully:

```python
@mcp.tool()
async def divide(a: float, b: float) -> float:
    """Divide two numbers"""
    if b == 0:
        raise ValueError("Cannot divide by zero")
    return a / b
```

**Type hints matter**
The SDK uses type hints for validation. Always annotate your parameters and return types:

```python
# Good
@mcp.tool()
def add(a: int, b: int) -> int:
    return a + b

# Bad - no type hints
@mcp.tool()
def add(a, b):
    return a + b
```

**Server restarts**
Changes to your server code require restarting Claude Desktop (or whatever client you're using). The client doesn't hot-reload MCP servers.

**Security**
MCP servers run with your user's permissions. Be careful about what tools you expose. If Claude can call it, Claude can do whatever that function does.

Don't expose tools like `run_shell_command(cmd: str)` unless you really trust the model not to do something destructive.

## Debugging

**For Claude Desktop:**

If your server isn't showing up:

1. Check Claude Desktop logs (Help > Debug Info > View Logs)
2. Run your server manually: `python server.py` - does it crash?
3. Verify JSON syntax in config file
4. Use absolute paths everywhere
5. Check Python environment has all dependencies
6. Restart Claude Desktop after config changes

Common error: config file has syntax errors. JSON doesn't allow trailing commas.

**For Claude Code:**

If your server isn't working:

1. List servers: `claude mcp list` - is it registered?
2. Test connection: `claude mcp test servername`
3. Check server info: `claude mcp info servername`
4. Run server manually: `python server.py` - look for crashes
5. Verify absolute paths in `~/.claude.json`
6. Check environment variables are set correctly

The CLI tools make debugging much easier than Claude Desktop since you get immediate feedback.

## Finding Existing Servers

The MCP community has built hundreds of servers. Check:
- https://github.com/modelcontextprotocol/servers
- MCP Registry (if it exists by the time you read this)

Many handle common tasks (file systems, databases, APIs) so you don't have to write them yourself.

## Other Languages

While this guide focuses on Python, MCP has SDKs for:
- TypeScript/JavaScript
- Java
- Kotlin
- C#
- Go
- PHP
- Ruby
- Rust
- Swift

The concepts are the same, just different syntax.

## Summary

**Quick start:**

1. Install: `pip install "mcp[cli]"`
2. Write a server with `FastMCP` and `@mcp.tool()` decorators
3. Test with `mcp dev ./server.py`
4. Configure your client:
   - **Claude Desktop**: Edit `claude_desktop_config.json` and restart
   - **Claude Code**: Run `claude mcp add --transport stdio myserver /path/to/server.py`
5. Ask Claude to use your tools

MCP is just a protocol. The server is just a Python script. No magic, no complex setup. You write functions, decorate them, and Claude can call them.
