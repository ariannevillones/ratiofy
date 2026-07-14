#!/usr/bin/env python3
"""Inspect or edit Ratiofy's locally persisted app data (dev/debug tool).

Ratiofy stores everything via shared_preferences. On macOS (sandboxed),
that's a UserDefaults plist inside the app's container, with each
preference value stored under a "flutter." prefix. This script loads that
plist, decodes the JSON-encoded preference values, and lets you dump or
edit them from the command line.

IMPORTANT: quit the running Ratiofy app before running this script with a
command that writes, and relaunch after. The app holds everything in
memory and rewrites the whole key on any change, so it will silently
overwrite an edit made while it's running (or was left running).

Usage:
    python3 scripts/manage_local_data.py dump presets.groups.v1
    python3 scripts/manage_local_data.py fix-units each piece
    python3 scripts/manage_local_data.py add-group "Spice Rack" --domain food
    python3 scripts/manage_local_data.py add-ingredient "Filipino Savory Staples" \\
        "Ginger" --unit g --quantity 15 --cost 0.50
"""

import argparse
import json
import plistlib
import time
from pathlib import Path

BUNDLE_ID = "com.example.ratiofy"
PLIST_PATH = (
    Path.home()
    / "Library/Containers"
    / BUNDLE_ID
    / "Data/Library/Preferences"
    / f"{BUNDLE_ID}.plist"
)


def load_plist(path: Path = PLIST_PATH) -> dict:
    with open(path, "rb") as f:
        return plistlib.load(f)


def save_plist(data: dict, path: Path = PLIST_PATH) -> None:
    with open(path, "wb") as f:
        plistlib.dump(data, f)


def dump_key(key: str, path: Path = PLIST_PATH) -> None:
    data = load_plist(path)
    value = data.get(f"flutter.{key}")
    if value is None:
        print(f"No value found for flutter.{key}")
        return
    try:
        print(json.dumps(json.loads(value), indent=2))
    except (TypeError, json.JSONDecodeError):
        print(value)


def fix_preset_units(old_unit: str, new_unit: str, path: Path = PLIST_PATH) -> None:
    """Renames every preset ingredient using `old_unit` to `new_unit` — e.g.
    cleaning up 'each' after it was removed from the app's unit list."""
    data = load_plist(path)
    key = "flutter.presets.groups.v1"
    groups = json.loads(data[key])
    changed = 0
    for group in groups:
        for ingredient in group["ingredients"]:
            if ingredient["unit"] == old_unit:
                ingredient["unit"] = new_unit
                changed += 1
    data[key] = json.dumps(groups)
    save_plist(data, path)
    print(f"Updated {changed} ingredient(s): '{old_unit}' -> '{new_unit}'")


# Built-in domain ids the app ships with — custom domains (created via
# Settings > Domains) have their own generated ids, visible via:
#   python3 scripts/manage_local_data.py dump domains.custom.v1
BUILT_IN_DOMAIN_IDS = {"food", "chemical", "cosmetics", "other"}


def add_preset_group(
    label: str, domain_id: str | None, path: Path = PLIST_PATH
) -> None:
    """Adds a new (initially empty) preset group — the same effect as
    using "New Group" in the Ingredients tab. `domain_id` scopes it to a
    domain (e.g. 'chemical') so it only shows up for recipes in that
    domain; leave it out for a group available in every domain."""
    if domain_id and domain_id not in BUILT_IN_DOMAIN_IDS:
        print(
            f"Note: '{domain_id}' isn't one of the built-in domains "
            f"({', '.join(sorted(BUILT_IN_DOMAIN_IDS))}) — assuming it's a "
            "custom domain id. Double-check it with 'dump domains.custom.v1' "
            "if the group doesn't show up where expected."
        )

    data = load_plist(path)
    groups_key = "flutter.presets.groups.v1"
    groups = json.loads(data[groups_key])

    if any(g["label"] == label for g in groups):
        print(f"Warning: a group named '{label}' already exists — adding another.")

    seq_key = "flutter.presets.sequenceCounters.v1"
    seq = json.loads(data.get(seq_key, "{}"))
    next_seq = seq.get("nextGroupSeq", 1)
    # Mirrors the app's own id scheme: preset_group_<seq>_<microsecondsSinceEpoch>.
    group_id = f"preset_group_{next_seq}_{int(time.time() * 1_000_000)}"

    groups.append(
        {
            "id": group_id,
            "label": label,
            "ingredients": [],
            "domainId": domain_id,
        }
    )
    seq["nextGroupSeq"] = next_seq + 1

    data[groups_key] = json.dumps(groups)
    data[seq_key] = json.dumps(seq)
    save_plist(data, path)
    scope = f"domain '{domain_id}'" if domain_id else "all domains"
    print(f"Added group '{label}' (id: {group_id}), scoped to {scope}.")


def add_preset_ingredient(
    group_label: str,
    name: str,
    unit: str,
    quantity: float,
    cost: float | None,
    path: Path = PLIST_PATH,
) -> None:
    """Appends a new preset ingredient to the group named `group_label` —
    the same effect as using "Add ingredient to group" in the app."""
    data = load_plist(path)
    groups_key = "flutter.presets.groups.v1"
    groups = json.loads(data[groups_key])

    group = next((g for g in groups if g["label"] == group_label), None)
    if group is None:
        available = ", ".join(g["label"] for g in groups) or "(none)"
        raise SystemExit(
            f"No group named '{group_label}'. Available groups: {available}"
        )

    seq_key = "flutter.presets.sequenceCounters.v1"
    seq = json.loads(data.get(seq_key, "{}"))
    next_seq = seq.get("nextIngredientSeq", 1)
    # Mirrors the app's own id scheme: preset_ing_<seq>_<microsecondsSinceEpoch>.
    ingredient_id = f"preset_ing_{next_seq}_{int(time.time() * 1_000_000)}"

    group["ingredients"].append(
        {
            "id": ingredient_id,
            "name": name,
            "unit": unit,
            "quantity": quantity,
            "cost": cost,
        }
    )
    seq["nextIngredientSeq"] = next_seq + 1

    data[groups_key] = json.dumps(groups)
    data[seq_key] = json.dumps(seq)
    save_plist(data, path)
    print(f"Added '{name}' ({quantity} {unit}) to '{group_label}'.")


def update_preset_ingredient(
    ingredient_id: str,
    name: str | None,
    unit: str | None,
    quantity: float | None,
    cost: float | None,
    clear_cost: bool,
    path: Path = PLIST_PATH,
) -> None:
    """Updates fields on an existing preset ingredient, found by id across
    all groups. Only the fields you pass are changed."""
    data = load_plist(path)
    groups_key = "flutter.presets.groups.v1"
    groups = json.loads(data[groups_key])

    ingredient = None
    for group in groups:
        for ing in group["ingredients"]:
            if ing["id"] == ingredient_id:
                ingredient = ing
                break
        if ingredient:
            break

    if ingredient is None:
        raise SystemExit(f"No ingredient found with id '{ingredient_id}'")

    if name is not None:
        ingredient["name"] = name
    if unit is not None:
        ingredient["unit"] = unit
    if quantity is not None:
        ingredient["quantity"] = quantity
    if clear_cost:
        ingredient["cost"] = None
    elif cost is not None:
        ingredient["cost"] = cost

    data[groups_key] = json.dumps(groups)
    save_plist(data, path)
    print(f"Updated {ingredient_id}: {json.dumps(ingredient)}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    subparsers = parser.add_subparsers(dest="command", required=True)

    dump_parser = subparsers.add_parser("dump", help="Print a stored key as JSON")
    dump_parser.add_argument("key", help="e.g. presets.groups.v1")

    fix_parser = subparsers.add_parser(
        "fix-units", help="Rename a unit across all preset ingredients"
    )
    fix_parser.add_argument("old_unit")
    fix_parser.add_argument("new_unit")

    add_group_parser = subparsers.add_parser(
        "add-group", help="Add a new (empty) preset group"
    )
    add_group_parser.add_argument("label", help='e.g. "Spice Rack"')
    add_group_parser.add_argument(
        "--domain",
        default=None,
        help="Scope to a domain id, e.g. food/chemical/cosmetics/other "
        "(omit for all domains)",
    )

    add_parser = subparsers.add_parser(
        "add-ingredient", help="Add a preset ingredient to an existing group"
    )
    add_parser.add_argument("group_label", help='e.g. "Filipino Savory Staples"')
    add_parser.add_argument("name", help='e.g. "Ginger"')
    add_parser.add_argument("--unit", default="g", help="Default: g")
    add_parser.add_argument("--quantity", type=float, default=0.0)
    add_parser.add_argument(
        "--cost", type=float, default=None, help="Omit for no default cost"
    )

    update_parser = subparsers.add_parser(
        "update-ingredient", help="Edit fields on an existing preset ingredient"
    )
    update_parser.add_argument("ingredient_id", help="e.g. preset_ing_8_...")
    update_parser.add_argument("--name", default=None)
    update_parser.add_argument("--unit", default=None)
    update_parser.add_argument("--quantity", type=float, default=None)
    update_parser.add_argument("--cost", type=float, default=None)
    update_parser.add_argument(
        "--clear-cost", action="store_true", help="Set cost back to blank/null"
    )

    args = parser.parse_args()

    if args.command == "dump":
        dump_key(args.key)
    elif args.command == "fix-units":
        fix_preset_units(args.old_unit, args.new_unit)
    elif args.command == "add-group":
        add_preset_group(args.label, args.domain)
    elif args.command == "add-ingredient":
        add_preset_ingredient(
            args.group_label, args.name, args.unit, args.quantity, args.cost
        )
    elif args.command == "update-ingredient":
        update_preset_ingredient(
            args.ingredient_id,
            args.name,
            args.unit,
            args.quantity,
            args.cost,
            args.clear_cost,
        )
