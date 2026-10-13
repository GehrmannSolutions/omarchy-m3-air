# Lid closed with two external displays

macOS drives two external displays on the MacBook Air M3 only with the lid closed. It then uses the
**internal** display pipeline (`dcp`, the one that normally drives the panel) for the second
external display, routed through the Type-C crossbar on DisplayPort core 0. Reference captured
read-only on macOS 26 on the same model.

## Phase 1 (done, development kernel)

A probe kernel routed the internal `dcp` to the front USB-C port when the lid is closed:
both external displays showed a picture in 6 of 6 lid-close cycles (first frame after ~28 ms),
and the panel came back on lid open. Remaining remarks in the log: the modeset is sent before the
crossbar is active ("Modeset done, but pipe not enabled"), and timings are set twice.

## Phase 2 (in progress)

Same behaviour as a clean addition to the series:

- device tree: the internal `dcp` gets a (disabled) Type-C route; the front connector gets two
  endpoints (`dcpext` first, `dcp` second), as on the t600x laptops;
- rule "dcpext first": the internal pipeline is used only when the lid is closed **and** `dcpext`
  is already busy; crossbar activation before the modeset;
- test plan: lid closed/open with one and two displays, port order both ways, suspend, replug.

Patches and a release follow once it passes the tests.
