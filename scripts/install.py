"""NixOS installation wizard with a read-only dry-run."""

import argparse
import subprocess
import sys

from nixos_setup.installation import install
from nixos_setup.wizard import collect_plan, review_plan


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(prog="nixos-setup", description=__doc__)
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Run the wizard and preview without making changes.",
    )
    args = parser.parse_args(argv)
    if args.dry_run:
        print("NixOS setup — dry run. Ctrl+C cancels; no changes are made.")
    else:
        print("NixOS setup. Erasure follows typed disk confirmation.")
        print(
            "Ctrl+C stops installation; changes already made cannot be undone."
        )
    try:
        plan = collect_plan()
        if not args.dry_run:
            return install(plan)
        review_plan(plan, dry_run=True)
    except KeyboardInterrupt, EOFError:
        print("\nPlanning cancelled. No changes made.")
        return 0
    except (
        OSError,
        ValueError,
        KeyError,
        TypeError,
        subprocess.SubprocessError,
    ) as error:
        print(f"Planning failed: {error}\nNo changes made.", file=sys.stderr)
        return 1
    print("Preview complete. Nothing saved or changed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
