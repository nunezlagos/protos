"""HistoryWindow tests: append, sliding, format, pop."""

from runtime.history import HistoryWindow


class TestHistoryWindow:
    def test_append_single(self):
        h = HistoryWindow(max_exchanges=5)
        h.append("user", "hola")
        assert len(h) == 1

    def test_sliding_window(self):
        h = HistoryWindow(max_exchanges=3)
        for i in range(5):
            h.append("user", f"msg-{i}")
        assert len(h) == 3
        assert h._exchanges[0]["text"] == "msg-2"

    def test_format_structure(self):
        h = HistoryWindow(max_exchanges=5)
        h.append("user", "hola")
        h.append("assistant", "como vas")
        result = h.format()
        assert len(result) == 2
        assert result[0]["role"] == "user"
        assert result[0]["parts"][0]["text"] == "hola"
        assert result[1]["role"] == "assistant"

    def test_pop_removes_last(self):
        h = HistoryWindow(max_exchanges=5)
        h.append("user", "a")
        h.append("user", "b")
        popped = h.pop()
        assert popped["text"] == "b"
        assert len(h) == 1

    def test_pop_empty(self):
        h = HistoryWindow(max_exchanges=5)
        assert h.pop() is None

    def test_len(self):
        h = HistoryWindow(max_exchanges=5)
        assert len(h) == 0
        h.append("user", "x")
        assert len(h) == 1
