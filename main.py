import os
import sys
import asyncio
import logging
from pathlib import Path
from src.transport.stdio_handler import run_stdio_transport

LOG_PATH = os.environ.get(
    "AGENT_LOG_PATH",
    str(Path(__file__).parent / "logs" / "agent.log")
)
os.makedirs(os.path.dirname(LOG_PATH), exist_ok=True)

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s [%(levelname)s] %(name)s: %(message)s',
    handlers=[
        logging.StreamHandler(sys.stderr),
        logging.FileHandler(LOG_PATH)
    ]
)
logging.captureWarnings(True)

logger = logging.getLogger("main")


def main() -> None:
    """Launch the JOAT ACP Agent (stdio transport for DataSpell)."""
    logger.info("Starting JOAT ACP Agent...")
    try:
        asyncio.run(run_stdio_transport())
    except KeyboardInterrupt:
        logger.info("Agent stopped by user")
    except Exception as e:
        logger.exception(f"Agent crashed: {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()
