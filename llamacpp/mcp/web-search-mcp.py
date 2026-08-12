# /// script
# requires-python = ">=3.11"
# dependencies = [
#   # Local pins; rationale and history: README.md in this directory.
#   "mcp>=1.9,<2",
#   "ollama>=0.6.2,<1",
# ]
# ///
# pyright: reportMissingImports=false
# (Deps resolve from the PEP 723 block at run time; editor envs cannot see
# them, so the missing-import diagnostic is noise here.)
"""MCP stdio server exposing Ollama web_search and web_fetch as tools.

Environment:
- OLLAMA_API_KEY (required): sent as the Authorization header to ollama.com;
  requests fail without it.
"""

from __future__ import annotations

from typing import Any

from mcp.server.fastmcp import FastMCP
from ollama import Client

client = Client()


def _web_search_impl(query: str, max_results: int = 3) -> dict[str, Any]:
    res = client.web_search(query=query, max_results=max_results)
    return res.model_dump()


def _web_fetch_impl(url: str) -> dict[str, Any]:
    res = client.web_fetch(url=url)
    return res.model_dump()


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
    return _web_search_impl(query=query, max_results=max_results)


@app.tool()
def web_fetch(url: str) -> dict[str, Any]:
    """Fetch the content of a web page for the provided URL.

    Args:
      url: The absolute URL to fetch.

    Returns:
      JSON-serializable dict matching ollama.WebFetchResponse.model_dump()
    """
    return _web_fetch_impl(url=url)


if __name__ == "__main__":
    app.run()
