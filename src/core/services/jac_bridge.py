import logging
import requests
from typing import Optional

logger = logging.getLogger(__name__)

JAC_BACKEND_URL = "http://localhost:8000/walker/analyze_prompt"


def call_jac_backend(prompt: str, session_id: str = "default") -> Optional[dict]:
    """
    POST a prompt to the Jac backend.
    Returns the first report dict or None on failure.
    """
    try:
        response = requests.post(
            JAC_BACKEND_URL,
            json={"prompt": prompt, "session_id": session_id},
            timeout=120
        )
        response.raise_for_status()
        data = response.json()
        if "reports" in data and data["reports"]:
            logger.info(f"Jac backend responded for session={session_id}")
            return data["reports"][0]
        logger.warning(f"Jac backend returned no reports: {data}")
        return None
    except requests.exceptions.ConnectionError:
        logger.error("Cannot connect to Jac backend — run: jac serve main.jac")
        return None
    except requests.exceptions.Timeout:
        logger.error("Jac backend timed out after 120s")
        return None
    except Exception as e:
        logger.error(f"Jac backend call failed: {e}")
        return None