"""The `Item` data contract — every ingested entry normalizes to this shape.

This is the interface contract documented in CLAUDE.md ("Item schema"). It is intentionally
part of the scaffold because every pipeline stage depends on it. Changing it is an interface
change under CONSTITUTION rule 3.
"""

from __future__ import annotations

import hashlib
from dataclasses import dataclass
from typing import Literal

SourceType = Literal["rss", "newsletter"]


@dataclass(frozen=True)
class Item:
    id: str
    source: str
    source_type: SourceType
    title: str
    url: str
    published: str  # ISO-8601 UTC, e.g. "2026-07-23T08:00:00Z"
    summary: str

    @staticmethod
    def make_id(source_url: str, guid: str) -> str:
        """Stable dedupe identity: sha256 of source_url + guid."""
        return hashlib.sha256(f"{source_url}{guid}".encode()).hexdigest()
