"""Sliding window of conversation exchanges for Gemini context."""

from collections.abc import Sequence


class HistoryWindow:
    MAX_EXCHANGES = 20

    def __init__(self, max_exchanges: int = MAX_EXCHANGES):
        self._exchanges: list[dict[str, str]] = []
        self._max = max_exchanges

    def append(self, role: str, text: str):
        self._exchanges.append({"role": role, "text": text})
        if len(self._exchanges) > self._max:
            self._exchanges.pop(0)

    def pop(self) -> dict[str, str] | None:
        if self._exchanges:
            return self._exchanges.pop()
        return None

    def format(self) -> list[dict[str, str | list[dict[str, str]]]]:
        return [
            {"role": e["role"], "parts": [{"text": e["text"]}]}
            for e in self._exchanges
        ]

    def __len__(self) -> int:
        return len(self._exchanges)
