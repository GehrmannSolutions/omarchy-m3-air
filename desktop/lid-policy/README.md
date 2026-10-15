# lid-policy (active, 2026-10-13; charger rule 2026-10-16)

User service `fay-lid-policy.service` + script `fay-lid-policy`. It takes the lid switch from
logind and applies logind's default rule with a grace period, plus a charger rule:

- lid closed and **no external display for 10 s**, on battery → lock (`omarchy-system-lock`) and suspend;
- lid closed and no external display, **on the charger** → lock only, no suspend (working in bed or on
  the sofa with a charger there; also keeps the machine awake overnight);
- charger pulled while the lid stays closed → suspend 10 s later, unless it comes back;
- lid closed with an external display → nothing (clamshell use);
- an external display coming back or the lid opening within the 10 s → nothing.

"Charger" is the SMC's AC input (`/sys/class/power_supply/*` of type `Mains`, online), which also
counts a display that powers the Mac over USB-C.

## Why

logind suspends a closed laptop the moment it counts zero external displays, and while the lid is
closed it counts again after every event it handles. With the lid closed and two external displays,
a display that changes display pipeline on this Mac (the left-front display moving to the internal
pipeline so that `dcpext` can drive a display on the rear port) is unplugged for about 3–5 s, and
logind suspended in the middle of every such move. GNOME and KDE also take the lid switch from
logind with a `handle-lid-switch` inhibitor and decide themselves; this does the same for Omarchy.

The service runs the script under `systemd-inhibit --what=handle-lid-switch --mode=block`. If it
stops or crashes, the inhibitor goes with it and logind's own lid handling applies again at once.

## Install / remove

```sh
install -m 0755 fay-lid-policy ~/.local/bin/
install -m 0644 fay-lid-policy.service ~/.config/systemd/user/
systemctl --user daemon-reload && systemctl --user enable --now fay-lid-policy.service
systemd-inhibit --list | grep handle-lid-switch      # shows fay-lid-policy

systemctl --user disable --now fay-lid-policy.service   # remove
```

`FAY_LID_GRACE=<seconds>` changes the grace period, `FAY_LID_DRYRUN=1` only logs what it would do
(note: in dry-run mode a closed lid never suspends). Journal: `journalctl --user -t fay-lid-policy`.

Tested on 2026-10-13 with the test kernel r11: lid closed without a display → locked, suspended
after the grace period; lid closed with one or two external displays → no suspend; a display moving
to the internal pipeline (~4.5 s without an external display) → "external display back: not
suspending". Charger rule tested on 2026-10-16: lid closed on a USB-C PD charger without a display →
locked after 10 s, no suspend.
