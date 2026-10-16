"""Wizard prompts and the settings review."""

from dataclasses import replace
from typing import Any

import questionary

from nixos_setup.common import GIB, HOSTS, Disk, Plan
from nixos_setup.planning import (
    detect_ram,
    discover_disks,
    find_windows,
    key_fingerprint,
    plan_storage,
    suggested_swap,
    swap_error,
    username_error,
)


def ask(question: questionary.Question) -> Any:
    answer = question.unsafe_ask()
    if answer is None:
        raise KeyboardInterrupt
    return answer


def choose_disk() -> Disk:
    disks = tuple(d for d in discover_disks() if not d.mounted and not d.busy)
    if not disks:
        raise ValueError("No writable disks found.")
    return ask(
        questionary.select(
            "Target disk",
            choices=[
                questionary.Choice(
                    f"{d.path} — {d.size / GIB:.1f} GiB — {d.model}",
                    value=d,
                )
                for d in disks
            ],
        )
    )


def choose_host() -> str:
    return ask(questionary.select("Machine", choices=list(HOSTS)))


def collect_plan() -> Plan:
    host = choose_host()
    storage = plan_storage(choose_disk(), "erase")

    def validate_username(text: str) -> str | bool:
        return username_error(text) or True

    username = ask(
        questionary.text("Installed username", validate=validate_username)
    )
    ram = detect_ram()
    suggestion = suggested_swap(ram)
    windows = find_windows(storage.disk)
    plan = Plan(host, username, "", "none", storage, ram, suggestion, windows)
    if swap_error(str(suggestion), storage.capacity):
        print(f"Suggested swap ({suggestion} GiB) will not fit.")
        plan = change_setting(plan, "Swap size")
    return plan


def change_setting(plan: Plan, setting: str) -> Plan:
    if setting == "SSH public key":
        while True:
            key = ask(questionary.text(setting, default=plan.ssh_key))
            try:
                return replace(
                    plan, ssh_key=key, fingerprint=key_fingerprint(key)
                )
            except ValueError as error:
                print(error)
    if setting == "Username":

        def validate_username(text: str) -> str | bool:
            return username_error(text) or True

        name = ask(
            questionary.text(
                setting,
                default=plan.username,
                validate=validate_username,
            )
        )
        return replace(plan, username=name)
    if setting == "Machine":
        return replace(plan, host=choose_host())
    if setting == "Disk":
        storage = plan_storage(choose_disk(), "erase")
        plan = replace(
            plan, storage=storage, windows=find_windows(storage.disk)
        )
        if not swap_error(str(plan.swap_gib), plan.storage.capacity):
            return plan

    def validate_swap(text: str) -> str | bool:
        return swap_error(text, plan.storage.capacity) or True

    swap = ask(
        questionary.text(
            "Swap size in whole GiB",
            default=str(plan.swap_gib),
            validate=validate_swap,
        )
    )
    return replace(plan, swap_gib=int(swap))


def show_plan(plan: Plan) -> None:
    storage = plan.storage
    print("\n--- Installation review ---")
    print(f"Host: {plan.host}\nUser: {plan.username}")
    print(f"SSH key: {plan.fingerprint}")
    print(
        f"Disk: {storage.disk.path} ({storage.disk.size / GIB:.1f} GiB)"
        f" — {storage.disk.model}"
    )
    if storage.disk.identity[1]:
        print(f"Disk serial: {storage.disk.identity[1]}")
    if storage.disk.identity[2]:
        print(f"Disk WWN: {storage.disk.identity[2]}")
    print(f"Mode: {storage.mode}")
    print("ERASE: all existing data on this disk will be lost.")
    print("Layout: 4 GiB EFI + LUKS2-encrypted Btrfs.")
    if plan.windows:
        print(f"Windows: boot menu entry for partition {plan.windows}")
    else:
        print("Windows: none found on other disks")
    print(f"RAM: {plan.ram / GIB:.1f} GiB")
    fraction = plan.swap_gib * GIB / storage.capacity
    remaining = storage.capacity / GIB - plan.swap_gib
    print(f"Swap: {plan.swap_gib} GiB ({fraction:.1%} of candidate space)")
    print(f"Space after swap: {remaining:.1f} GiB, before overhead/packages.")
    if plan.swap_gib < suggested_swap(plan.ram):
        print("WARNING: Swap is below the suggestion; hibernation may fail.")
    print(
        f"Checkout: /home/{plan.username}/Projects/nix"
        " (latest main, locked inputs)"
    )
    print("Password: shared by disk encryption, root and your user.")


def review_plan(plan: Plan, *, dry_run: bool) -> Plan:
    while True:
        show_plan(plan)
        action = ask(
            questionary.select(
                "Review",
                choices=[
                    "Finish preview"
                    if dry_run
                    else "Continue to installation",
                    "Change settings",
                    "Cancel",
                ],
            )
        )
        if action == "Cancel":
            raise KeyboardInterrupt
        if action != "Change settings":
            return plan
        setting = ask(
            questionary.select(
                "Change settings",
                choices=[
                    "Machine",
                    "Disk",
                    "Username",
                    "SSH public key",
                    "Swap size",
                    "Back",
                ],
            )
        )
        if setting != "Back":
            plan = change_setting(plan, setting)
