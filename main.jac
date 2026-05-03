# main.jac

import json;
import os;

node IncomingPrompt {
    has prompt: str;
    has session_id: str;
    has created_at: str;
}

node VisualizationSinkNode {
    has insight_id: str;
    has prompt: str;
    has created_at: str;
    has quant_summary: dict;
    has nodes: list;
    has edges: list;
    has root_node_id: str;
    has visualizer_pseudo_prompt: str;
    has suggested_chart_types: list;
    has rendered_payload: dict;
}

::py::
import json as _json
import os as _os
import uuid as _uuid
import traceback as _tb
from pathlib import Path as _Path
from datetime import datetime, timezone
from groq import Groq as _Groq

_client = _Groq(api_key=_os.environ.get("GROQ_API_KEY", ""))

SYNTH_DIR = _Path("data/raw/synthetic_visualization_sinks")

SYNTH_MAP = {
    "synthdata1":  "synthdata1.json",
    "synthdata2":  "synthdata2.json",
    "synthdata4":  "synthdata4.json",
    "synthdata5":  "synthdata5.json",
    "synthdata6":  "synthdata6.json",
    "synthdata7":  "synthdata7.json",
    "synthdata8":  "synthdata8.json",
    "synthdata9":  "synthdata9.json",
    "meta_sample": "meta_analysis_sample.json",
    "risk assessment": "synthdata6.json",
    "deep dive meta": "synthdata7.json",
    "rebalancing": "synthdata8.json",
    "compare meta pltr": "synthdata9.json",
}

def build_insight_id() -> str:
    return str(_uuid.uuid4())

def build_created_at() -> str:
    return datetime.now(timezone.utc).isoformat()

def _call(prompt: str, max_tokens: int = 2048) -> str:
    """Raw LLM call — returns string, caller handles parsing."""
    msg = _client.chat.completions.create(
        model="llama-3.3-70b-versatile",
        max_tokens=max_tokens,
        messages=[{"role": "user", "content": prompt}]
    )
    return msg.choices[0].message.content.strip()

def _parse_json(raw: str) -> dict:
    """Strip markdown fences and parse JSON."""
    if raw.startswith("```"):
        raw = raw.split("```")[1]
        if raw.startswith("json"):
            raw = raw[4:]
    return _json.loads(raw.strip())

def llm_propose(prompt: str) -> dict:
    """LLM 1 — Proposer: analyse the prompt and propose financial insight structure."""
    p = (
        "You are a financial data analyst. Given a user prompt, "
        "propose a complete financial insight structure.\n\n"
        "User prompt: " + prompt + "\n\n"
        "Return ONLY valid JSON, no markdown, no backticks:\n"
        "{\n"
        '  "title": string,\n'
        '  "summary_text": string (2-3 sentences of financial analysis),\n'
        '  "key_metrics": {metric_name: numeric_value},\n'
        '  "nodes": [\n'
        '    {\n'
        '      "node_id": string,\n'
        '      "schema": {field_name: field_type_string},\n'
        '      "data": {actual realistic financial data}\n'
        '    }\n'
        '  ],\n'
        '  "edges": [\n'
        '    {"source_id": string, "target_id": string, "reasoning": string}\n'
        '  ],\n'
        '  "root_node_id": string,\n'
        '  "visualizer_pseudo_prompt": string (detailed chart instructions),\n'
        '  "suggested_chart_types": [list from: heatmap, bar, line, scatter, pie, area, treemap, stacked_xy, histogram, waterfall, annotated_line],\n'
        '  "chart_reasoning": string\n'
        "}"
    )
    raw = _call(p, max_tokens=2048)
    return _parse_json(raw)

def llm_validate(proposal: dict, prompt: str) -> dict:
    """LLM 2 — Validator: review proposal for financial accuracy."""
    p = (
        "You are a critical financial data reviewer.\n\n"
        "Original prompt: " + prompt + "\n\n"
        "Proposal:\n" + _json.dumps(proposal, indent=2) + "\n\n"
        "Check:\n"
        "1. Are financial metrics realistic and internally consistent?\n"
        "2. Do nodes contain enough data to build a meaningful chart?\n"
        "3. Are edges meaningful financial relationships?\n"
        "4. Does the visualizer_pseudo_prompt match the data?\n\n"
        "Return ONLY valid JSON, no markdown:\n"
        "{\n"
        '  "agrees": bool,\n'
        '  "critique": string,\n'
        '  "corrected_title": string,\n'
        '  "corrected_summary_text": string,\n'
        '  "corrected_key_metrics": {metric_name: numeric_value},\n'
        '  "corrected_suggested_chart_types": [list],\n'
        '  "corrected_visualizer_pseudo_prompt": string,\n'
        '  "nodes_valid": bool,\n'
        '  "edges_valid": bool\n'
        "}"
    )
    raw = _call(p, max_tokens=1024)
    return _parse_json(raw)

def llm_judge_and_write_code(proposal: dict, validation: dict, prompt: str) -> dict:
    """
    LLM 3 — Judge + Code Writer.
    Makes final decision AND writes executable Plotly Python code
    that builds the chart from the data in the nodes.
    Returns the final structure plus plotly_code string.
    """
    nodes_json = _json.dumps(proposal.get("nodes", []), indent=2)
    p = (
        "You are the final decision maker for financial visualization.\n\n"
        "Original prompt: " + prompt + "\n\n"
        "Proposer:\n" + _json.dumps(proposal, indent=2) + "\n\n"
        "Validator:\n" + _json.dumps(validation, indent=2) + "\n\n"
        "Your job:\n"
        "1. Finalize the insight structure (merge corrections if validator disagreed)\n"
        "2. Write actual executable Python code using Plotly that visualizes this data\n\n"
        "The Python code must:\n"
        "- Import only plotly.graph_objects as go and plotly.express as px\n"
        "- Use the data directly from the nodes (hardcoded from the nodes above)\n"
        "- Create an interactive Plotly figure called 'fig'\n"
        "- Call fig.update_layout() to set dark theme: paper_bgcolor='rgba(0,0,0,0)', "
        "plot_bgcolor='rgba(0,0,0,0)', font=dict(color='#e0e0e0')\n"
        "- End with: result = fig.to_json()\n"
        "- Do NOT call fig.show()\n"
        "- Do NOT use any external data sources or APIs\n\n"
        "Return ONLY valid JSON, no markdown:\n"
        "{\n"
        '  "title": string,\n'
        '  "summary_text": string,\n'
        '  "key_metrics": {metric_name: numeric_value},\n'
        '  "nodes": [{node_id, schema, data}],\n'
        '  "edges": [{source_id, target_id, reasoning}],\n'
        '  "root_node_id": string,\n'
        '  "visualizer_pseudo_prompt": string,\n'
        '  "suggested_chart_types": [list],\n'
        '  "final_reasoning": string,\n'
        '  "plotly_code": string (the complete Python code as a single string with \\n for newlines)\n'
        "}"
    )
    raw = _call(p, max_tokens=3000)
    return _parse_json(raw)

def execute_plotly_code(code: str) -> dict:
    """
    Execute LLM-written Plotly code in a sandbox.
    Returns the Plotly figure JSON dict or an error fallback.
    """
    namespace = {}
    try:
        exec(code, namespace)
        result = namespace.get("result", None)
        if result:
            if isinstance(result, str):
                return _json.loads(result)
            return result
        fig = namespace.get("fig", None)
        if fig:
            return _json.loads(fig.to_json())
        return {"error": "No fig or result variable found in executed code"}
    except Exception as e:
        return {
            "error": str(e),
            "traceback": _tb.format_exc(),
            "data": [{"type": "scatter", "x": [], "y": []}],
            "layout": {"title": "Code execution failed — see error"}
        }

def rewrite_plotly_code(existing_code: str, modification: str, existing_data: dict) -> dict:
    """
    LLM call to modify existing Plotly code based on user request.
    Returns updated plotly_code string and new plot_json.
    """
    p = (
        "You are a Plotly chart modification expert.\n\n"
        "Existing chart code:\n" + existing_code + "\n\n"
        "User modification request: " + modification + "\n\n"
        "Rewrite the code to apply the modification.\n"
        "Keep all existing data. Only change what the user asked for.\n"
        "Rules:\n"
        "- Import only plotly.graph_objects as go and plotly.express as px\n"
        "- Keep dark theme: paper_bgcolor='rgba(0,0,0,0)', plot_bgcolor='rgba(0,0,0,0)', font=dict(color='#e0e0e0')\n"
        "- End with: result = fig.to_json()\n"
        "- Do NOT call fig.show()\n\n"
        "Return ONLY valid JSON, no markdown:\n"
        "{\n"
        '  "needs_new_data": bool (true only if modification requires data not in the code),\n'
        '  "reason": string,\n'
        '  "new_prompt": string (if needs_new_data true, suggested new prompt, else empty),\n'
        '  "updated_code": string (complete updated Python code)\n'
        "}"
    )
    raw = _call(p, max_tokens=2048)
    result = _parse_json(raw)
    if not result.get("needs_new_data", False):
        plot_json = execute_plotly_code(result.get("updated_code", ""))
        result["plot_json"] = plot_json
    return result

def load_synth_file(filename: str) -> dict:
    """Load a synthetic data file and return its contents."""
    path = SYNTH_DIR / filename
    if path.exists():
        with open(path, "r") as f:
            return _json.load(f)
    return {}

def match_synth_prompt(prompt: str) -> str:
    """Check if prompt matches a synth test case. Returns filename or empty string."""
    p = prompt.lower().strip()
    for key, filename in SYNTH_MAP.items():
        if key in p:
            return filename
    return ""
::py::

walker analyze_prompt {
    has prompt: str;
    has session_id: str = "default";

    obj __specs__ {
        static has auth: bool = False;
        static has methods: list = ["post"];
    }

    can handle with `root entry {
        insight_id = build_insight_id();
        created_at = build_created_at();

        incoming = IncomingPrompt(
            prompt=self.prompt,
            session_id=self.session_id,
            created_at=created_at
        );
        here ++> incoming;

        proposal = llm_propose(self.prompt);
        validation = llm_validate(proposal, self.prompt);
        final = llm_judge_and_write_code(proposal, validation, self.prompt);

        plotly_code = final.get("plotly_code", "");
        plot_json = execute_plotly_code(plotly_code);

        reasoning_chain = [
            {
                "role": "proposer",
                "chart_types": proposal.get("suggested_chart_types", []),
                "reasoning": proposal.get("chart_reasoning", "")
            },
            {
                "role": "validator",
                "agrees": validation.get("agrees", True),
                "critique": validation.get("critique", ""),
                "nodes_valid": validation.get("nodes_valid", True),
                "edges_valid": validation.get("edges_valid", True)
            },
            {
                "role": "judge",
                "final_types": final.get("suggested_chart_types", []),
                "reasoning": final.get("final_reasoning", ""),
                "wrote_code": len(plotly_code) > 0
            }
        ];

        rendered_payload = {
            "chart_type": final.get("suggested_chart_types", ["bar"])[0],
            "plot_json": plot_json,
            "plotly_code": plotly_code,
            "table_data": {
                "columns": [],
                "rows": []
            },
            "alternatives": final.get("suggested_chart_types", [])[1:],
            "reasoning_chain": reasoning_chain,
            "agent_message": final.get("summary_text", ""),
            "visualizer_pseudo_prompt": final.get("visualizer_pseudo_prompt", "")
        };

        sink = VisualizationSinkNode(
            insight_id=insight_id,
            prompt=self.prompt,
            created_at=created_at,
            quant_summary={
                "title": final.get("title", ""),
                "summary_text": final.get("summary_text", ""),
                "key_metrics": final.get("key_metrics", {})
            },
            nodes=final.get("nodes", []),
            edges=final.get("edges", []),
            root_node_id=final.get("root_node_id", ""),
            visualizer_pseudo_prompt=final.get("visualizer_pseudo_prompt", ""),
            suggested_chart_types=final.get("suggested_chart_types", []),
            rendered_payload=rendered_payload
        );
        here ++> sink;

        report {
            "insight_id": sink.insight_id,
            "prompt": sink.prompt,
            "created_at": sink.created_at,
            "quant_summary": sink.quant_summary,
            "nodes": sink.nodes,
            "edges": sink.edges,
            "root_node_id": sink.root_node_id,
            "visualizer_pseudo_prompt": sink.visualizer_pseudo_prompt,
            "suggested_chart_types": sink.suggested_chart_types,
            "rendered_payload": sink.rendered_payload
        };
    }
}

walker test_prompt {
    has prompt: str;
    has session_id: str = "default";
    has synth_file: str = "";

    obj __specs__ {
        static has auth: bool = False;
        static has methods: list = ["post"];
    }

    can handle with `root entry {
        insight_id = build_insight_id();
        created_at = build_created_at();

        target_file = self.synth_file;
        if not target_file {
            target_file = match_synth_prompt(self.prompt);
        }

        synth_data = {};
        if target_file {
            synth_data = load_synth_file(target_file);
        }

        if not synth_data {
            report {
                "error": "No synthetic data found for prompt: " + self.prompt,
                "available": list(SYNTH_MAP.keys())
            };
            disengage;
        }

        plotly_code = "";
        plot_json = {};

        if synth_data.get("rendered_payload", {}).get("plotly_code") {
            plotly_code = synth_data["rendered_payload"]["plotly_code"];
            plot_json = execute_plotly_code(plotly_code);
        } else {
            nodes = synth_data.get("nodes", []);
            pseudo_prompt = synth_data.get("visualizer_pseudo_prompt", "");
            chart_types = synth_data.get("suggested_chart_types", ["bar"]);

            code_prompt = (
                "You are a Plotly chart code writer.\n\n"
                "Write Python code to visualize this financial data.\n\n"
                "Visualizer instruction: " + pseudo_prompt + "\n\n"
                "Data nodes:\n" + _json.dumps(nodes, indent=2) + "\n\n"
                "Chart types suggested: " + _json.dumps(chart_types) + "\n\n"
                "Rules:\n"
                "- Import only plotly.graph_objects as go and plotly.express as px\n"
                "- Use the data from the nodes above (hardcoded values)\n"
                "- Create an interactive Plotly figure called fig\n"
                "- Dark theme: paper_bgcolor='rgba(0,0,0,0)', plot_bgcolor='rgba(0,0,0,0)', font=dict(color='#e0e0e0')\n"
                "- End with: result = fig.to_json()\n"
                "- Do NOT call fig.show()\n\n"
                "Return ONLY the Python code as a plain string, no JSON wrapper, no markdown fences."
            );
            plotly_code = _call(code_prompt, max_tokens=2048);
            if plotly_code.startswith("```") {
                plotly_code = plotly_code.split("```")[1];
                if plotly_code.startswith("python") {
                    plotly_code = plotly_code[6:];
                }
            }
            plot_json = execute_plotly_code(plotly_code);
        }

        rendered_payload = {
            "chart_type": synth_data.get("suggested_chart_types", ["bar"])[0],
            "plot_json": plot_json,
            "plotly_code": plotly_code,
            "table_data": {"columns": [], "rows": []},
            "alternatives": synth_data.get("suggested_chart_types", [])[1:],
            "reasoning_chain": [
                {"role": "test_pipeline", "source_file": target_file, "reasoning": "Loaded from synthetic test data"}
            ],
            "agent_message": synth_data.get("quant_summary", {}).get("summary_text", ""),
            "visualizer_pseudo_prompt": synth_data.get("visualizer_pseudo_prompt", "")
        };

        report {
            "insight_id": synth_data.get("insight_id", insight_id),
            "prompt": self.prompt,
            "created_at": synth_data.get("created_at", created_at),
            "quant_summary": synth_data.get("quant_summary", {}),
            "nodes": synth_data.get("nodes", []),
            "edges": synth_data.get("edges", []),
            "root_node_id": synth_data.get("root_node_id", ""),
            "visualizer_pseudo_prompt": synth_data.get("visualizer_pseudo_prompt", ""),
            "suggested_chart_types": synth_data.get("suggested_chart_types", []),
            "rendered_payload": rendered_payload
        };
    }
}

walker modify_chart {
    has existing_code: str;
    has modification: str;
    has session_id: str = "default";

    obj __specs__ {
        static has auth: bool = False;
        static has methods: list = ["post"];
    }

    can handle with `root entry {
        result = rewrite_plotly_code(
            self.existing_code,
            self.modification,
            {}
        );

        report {
            "needs_new_data": result.get("needs_new_data", False),
            "reason": result.get("reason", ""),
            "new_prompt": result.get("new_prompt", ""),
            "updated_code": result.get("updated_code", ""),
            "plot_json": result.get("plot_json", {})
        };
    }
}