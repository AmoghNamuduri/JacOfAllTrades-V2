import logging
import uvicorn
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from src.agent.handlers import JacPromptHandler
from src.interfaces.protocols import PromptInput

logger = logging.getLogger(__name__)

app = FastAPI(title="JOATberg HTTP Bridge", version="1.0.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"]
)

_handler = JacPromptHandler()


class PromptRequest(BaseModel):
    prompt: str
    session_id: str = "browser-session"


@app.post("/prompt")
def handle_prompt(request: PromptRequest) -> dict:
    input_data = PromptInput(
        prompt=request.prompt,
        session_id=request.session_id
    )
    output = _handler.handle_prompt(input_data)
    return {
        "text": output.text,
        "visualization_sink": output.visualization_sink,
        "stop_reason": output.stop_reason
    }


@app.get("/healthz")
def health() -> dict:
    return {"status": "ok"}


if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8001, log_level="info")