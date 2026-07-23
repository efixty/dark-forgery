"""Entry point for `python -m feed_digester`.

The scheduler and pipeline wiring are backlog items (see STATUS.md). This stub exists so the
package is runnable and `make run` has a target; the factory replaces it with the real
one-cycle / scheduled-loop logic driven by DIGEST_RUN_ONCE.
"""

import os
import sys


def main() -> int:
    run_once = os.environ.get("DIGEST_RUN_ONCE") == "1"
    mode = "one-shot" if run_once else "scheduled"
    print(f"feed-digester: {mode} mode — pipeline not yet implemented (see STATUS.md backlog)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
