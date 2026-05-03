# JacOfAllTrades

Submitted to **JacHacks** at **University of Michigan - Ann Arbor**

A financial data visualization agent built on [Jaclang](https://www.jac-lang.org/). Takes natural language prompts and returns interactive Plotly charts backed by a 3-stage LLM reasoning pipeline.

## How it works

Each prompt goes through three LLM calls (via Groq):

1. **Proposer** — analyses the prompt and generates a financial insight structure with data nodes, edges, and chart suggestions
2. **Validator** — reviews the proposal for financial accuracy and internal consistency
3. **Judge + Code Writer** — makes the final decision, merges corrections, and writes executable Plotly Python code

The Plotly code is executed server-side and the resulting chart JSON is returned to the frontend.

## Running the app

**Prerequisites:** set `GROQ_API_KEY` in your environment.

```bash
pip install -r requirements.txt
```

**Option 1 — Jac backend + browser dashboard**

```bash
# Terminal 1
jac serve main.jac

# Terminal 2
python server.py

# Then open chat_dashboard.html in your browser
```

- Jac backend runs on `:8000`
- HTTP bridge (`/prompt` endpoint) runs on `:8001`

**Option 2 — ACP stdio transport (DataSpell IDE integration)**

```bash
python main.py
```

## API

`POST /prompt` on `:8001`

```json
{
  "prompt": "Show me a risk assessment of my tech portfolio",
  "session_id": "optional-string"
}
```

Returns a visualization sink with `plot_json` (Plotly figure), `plotly_code`, `quant_summary`, `nodes`, `edges`, and a `reasoning_chain`.

## Walkers (main.jac)

| Walker | Description |
|---|---|
| `analyze_prompt` | Full LLM pipeline — generates live financial insights |
| `test_prompt` | Loads from synthetic data files in `data/raw/` for dev/testing |
| `modify_chart` | Rewrites existing Plotly code based on a modification request |

## Tech stack

- [Jaclang](https://www.jac-lang.org/) — graph-based agent runtime
- [Groq](https://groq.com/) — LLM inference (llama-3.3-70b-versatile)
- [Plotly](https://plotly.com/python/) — interactive chart rendering
- [FastAPI](https://fastapi.tiangolo.com/) + [Uvicorn](https://www.uvicorn.org/) — HTTP server
- [Agent Client Protocol](https://github.com/i-am-bee/acp) — IDE integration transport

## Environment variables

| Variable | Description |
|---|---|
| `GROQ_API_KEY` | Required. Your Groq API key. |
| `AGENT_LOG_PATH` | Optional. Override the default log file path. |

See [.env.example](.env.example) for a template.
