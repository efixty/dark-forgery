.PHONY: setup build test run lint

VENV := .venv
PY := $(VENV)/bin/python
PIP := $(VENV)/bin/pip

setup:
	python3 -m venv $(VENV)
	$(PIP) install --upgrade pip
	$(PIP) install -r requirements.txt

build:
	$(PY) -m compileall src

test:
	$(VENV)/bin/pytest -q

run:
	DIGEST_RUN_ONCE=1 $(PY) -m feed_digester

lint:
	$(VENV)/bin/ruff check src tests
