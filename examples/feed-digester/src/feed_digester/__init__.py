"""Feed Digester — RSS/newsletter to daily briefing.

Only the shared data contract (`Item`) ships in the scaffold. The pipeline stages
(ingest, dedupe, cluster, render, deliver, schedule) are the backlog the factory builds.
"""

from .models import Item

__all__ = ["Item"]
