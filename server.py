"""
HTTP bridge server — run this alongside `jac serve main.jac`.

  Terminal 1:  jac serve main.jac
  Terminal 2:  python server.py
  Browser:     open chat_dashboard.html
               (the dashboard talks directly to the Jac backend on :8000)

This server exposes a /prompt endpoint on :8001 for programmatic use
and can be used instead of the ACP stdio transport in non-IDE contexts.
"""
import uvicorn
from src.transport.http_server import app

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8001, log_level="info")
