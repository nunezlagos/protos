.PHONY: install test lint fmt

install:
	./scripts/install.sh

test:
	cd libs/kokoro && python -m pytest tests/ -v

test-all:
	find libs -name tests -type d -exec sh -c 'cd {}/.. && python -m pytest -v' \;

lint:
	ruff check libs/ apps/ 2>/dev/null || true

fmt:
	ruff format libs/ apps/ 2>/dev/null || true
