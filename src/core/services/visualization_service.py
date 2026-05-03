import os
import json
import uuid
import logging
from datetime import datetime, timezone
from pathlib import Path

from src.core.primitives.financial_insight import InsightNode, InsightEdge, QuantSummary
from src.core.primitives.visualization_sink import VisualizationSink

logger = logging.getLogger(__name__)

USE_SYNTH = os.environ.get("USE_SYNTH", "false").lower() == "true"
SYNTH_DIR = Path(os.environ.get("SYNTH_DIR", "data/raw/synthetic_visualization_sinks"))

SYNTH_MAP = {
    "synthdata1":        "synthdata1.json",
    "synthdata2":        "synthdata2.json",
    "synthdata4":        "synthdata4.json",
    "synthdata5":        "synthdata5.json",
    "synthdata6":        "synthdata6.json",
    "synthdata7":        "synthdata7.json",
    "synthdata8":        "synthdata8.json",
    "synthdata9":        "synthdata9.json",
    "meta_sample":       "meta_analysis_sample.json",
    "risk assessment":   "synthdata6.json",
    "deep dive meta":    "synthdata7.json",
    "rebalancing":       "synthdata8.json",
    "compare meta pltr": "synthdata9.json",
}


def _match_synth_prompt(prompt: str) -> str:
    p = prompt.lower().strip()
    for key, filename in SYNTH_MAP.items():
        if key in p:
            return filename
    return ""


def create_visualization_sink(prompt: str) -> VisualizationSink:
    insight_id = str(uuid.uuid4())
    created_at = datetime.now(timezone.utc).isoformat()
    nodes = []

    if USE_SYNTH:
        filename = _match_synth_prompt(prompt)
        if filename:
            path = SYNTH_DIR / filename
            if path.exists():
                with open(path) as f:
                    synth = json.load(f)
                return VisualizationSink.from_dict({
                    **synth,
                    "insight_id": synth.get("insight_id", insight_id),
                    "prompt": prompt,
                    "created_at": synth.get("created_at", created_at),
                })
    else:
        # Try Jac backend first
        from src.core.services.jac_bridge import call_jac_backend
        jac_result = call_jac_backend(prompt, session_id=insight_id)

        if jac_result:
            quant = jac_result.get("quant_summary", {})
            rendered = jac_result.get("rendered_payload", {})
            nodes_raw = jac_result.get("nodes", [])
            edges_raw = jac_result.get("edges", [])

            jac_nodes = tuple(
                InsightNode(
                    node_id=n.get("node_id", f"node_{i}"),
                    schema=n.get("schema", {}),
                    data=n.get("data", {})
                )
                for i, n in enumerate(nodes_raw)
            )
            jac_edges = tuple(
                InsightEdge.from_dict(e) for e in edges_raw
            )

            return VisualizationSink(
                insight_id=insight_id,
                prompt=prompt,
                created_at=created_at,
                quant_summary=QuantSummary(
                    title=quant.get("title", "Analysis"),
                    summary_text=quant.get("summary_text", ""),
                    key_metrics=quant.get("key_metrics", {})
                ),
                nodes=jac_nodes,
                edges=jac_edges,
                root_node_id=jac_result.get("root_node_id", ""),
                visualizer_pseudo_prompt=jac_result.get("visualizer_pseudo_prompt", ""),
                suggested_chart_types=jac_result.get("suggested_chart_types", []),
                rendered_payload=rendered
            )

    # Fallback stub — Jac backend unreachable and no synth match
    logger.warning("Jac backend unavailable and no synth match; returning stub sink")
    nodes.append(InsightNode(
        node_id="stub_node",
        schema={"prompt": "string"},
        data={"prompt": prompt}
    ))

    return VisualizationSink(
        insight_id=insight_id,
        prompt=prompt,
        created_at=created_at,
        quant_summary=QuantSummary(
            title="Jac Backend Unavailable",
            summary_text="Could not reach the Jac backend. Run: jac serve main.jac",
            key_metrics={}
        ),
        nodes=tuple(nodes),
        edges=(),
        root_node_id="stub_node",
        visualizer_pseudo_prompt=prompt,
        suggested_chart_types=["bar"],
        rendered_payload={
            "chart_type": "bar",
            "plot_json": {},
            "plotly_code": "",
            "table_data": {"columns": [], "rows": []},
            "alternatives": [],
            "reasoning_chain": [{"role": "fallback", "reasoning": "Jac backend unavailable"}],
            "agent_message": "Jac backend is not running. Start it with: jac serve main.jac",
            "visualizer_pseudo_prompt": prompt
        }
    )
