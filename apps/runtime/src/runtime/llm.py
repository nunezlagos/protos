"""Gemini API client with conversation history support."""

import os
from pathlib import Path

from google import genai
from google.genai import types


def _resolve_instructions_dir() -> Path:
    cwd = Path.cwd()
    candidate = cwd / "instructions"
    if candidate.exists():
        return candidate
    src_dir = Path(__file__).resolve().parent
    for parent in src_dir.parents:
        candidate = parent / "instructions"
        if candidate.exists():
            return candidate
    return cwd / "instructions"


INSTRUCTIONS_DIR = _resolve_instructions_dir()


def _load_system_prompt() -> str:
    path = INSTRUCTIONS_DIR / "system.xml"
    if path.exists():
        return path.read_text().strip()
    return "You are a helpful voice assistant. Respond briefly and naturally."


class GeminiClient:
    def __init__(self):
        api_key = os.environ.get("API_LLM")
        if not api_key:
            raise RuntimeError("API_LLM env var not set")
        self._model = os.environ.get("LLM_MODEL", "gemini-3.1-flash-lite")
        self._client = genai.Client(api_key=api_key)
        self._system_prompt = _load_system_prompt()

    def ask(
        self, text: str, history: list[dict] | None = None
    ) -> str:
        session = self._client.chats.create(
            model=self._model,
            history=history or [],
            config=types.GenerateContentConfig(
                system_instruction=self._system_prompt,
            ),
        )
        response = session.send_message(text)
        return response.text
