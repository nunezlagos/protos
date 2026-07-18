.PHONY: install install-all test test-all lint fmt run

PYTHON = python3
ifneq ($(wildcard venv/bin/python),)
PYTHON = venv/bin/python
endif
PIP = $(PYTHON) -m pip

install:
	./install.sh

install-all: install
	$(PIP) install -e libs/kokoro
	$(PIP) install -e apps/runtime

test:
	cd libs/kokoro && $(PYTHON) -m pytest tests/ -v

test-all:
	cd libs/kokoro && $(PYTHON) -m pytest tests/ -v
	cd apps/runtime && $(PYTHON) -m pytest tests/ -v

lint:
	ruff check libs/ apps/ 2>/dev/null || true

fmt:
	ruff format libs/ apps/ 2>/dev/null || true

run:
	cd apps/runtime && $(PYTHON) -m runtime.main
