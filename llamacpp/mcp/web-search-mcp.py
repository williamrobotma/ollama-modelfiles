# /// script
# requires-python = ">=3.11"
# dependencies = [
#   # Pin history: README.md in this directory.
#   "mcp>=1.9,<2",  # mcp 2.0 removed FastMCP, imported below
#   "ollama>=0.6.2,<1",  # floor = the known-working resolved version
# ]
# ///
"""MCP stdio server exposing Ollama web_search and web_fetch as tools.

Environment:
- OLLAMA_API_KEY (required): sent as the Authorization header to ollama.com.
"""

from typing import Any

# Editor-only ignores: the deps resolve from the PEP 723 block at run time.
from mcp.server.fastmcp import FastMCP  # pyright: ignore[reportMissingImports]
from ollama import Client  # pyright: ignore[reportMissingImports]

client = Client()
app = FastMCP("ollama-search-fetch")


@app.tool()
def web_search(query: str, max_results: int = 3) -> dict[str, Any]:
    """Perform a web search using Ollama's hosted search API.

    Args:
      query: The search query to run.
      max_results: Maximum results to return (default: 3).

    Returns:
      JSON-serializable dict matching ollama.WebSearchResponse.model_dump()
    """
    return client.web_search(query=query, max_results=max_results).model_dump()


@app.tool()
def web_fetch(url: str) -> dict[str, Any]:
    """Fetch the content of a web page for the provided URL.

    Args:
      url: The absolute URL to fetch.

    Returns:
      JSON-serializable dict matching ollama.WebFetchResponse.model_dump()
    """
    return client.web_fetch(url=url).model_dump()


if __name__ == "__main__":
    app.run()
