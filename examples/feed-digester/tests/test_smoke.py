"""Smoke test — the package imports and the toolchain is wired up.

The real behavior tests (Item schema, dedupe, deterministic clustering, digest format) are
written by the factory alongside each backlog item, using fixtures under docs/qa/fixtures/.
"""

import importlib


def test_package_imports():
    mod = importlib.import_module("feed_digester")
    assert mod.__version__
