.PHONY: install install-all test test-all lint fmt run

install:
	./scripts/install.sh

install-all: install
	pip install -e libs/kokoro
	pip install -e apps/runtime

test:
	cd libs/kokoro && python -m pytest tests/ -v

test-all:
	find libs -name tests -type d -exec sh -c 'cd {}/.. && python -m pytest -v' \;

lint:
	ruff check libs/ apps/ 2>/dev/null || true

fmt:
	ruff format libs/ apps/ 2>/dev/null || true

run:
	cd apps/runtime && python -m runtime.main
