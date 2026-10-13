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

## Phase 2 (works in a test kernel, 2026-10-13)

The same behaviour as a clean set on top of the series:
[../kernel/patches-clamshell/](../kernel/patches-clamshell/) (patches 0013–0022, unsigned work in
progress), the device tree from that set in boot.bin ([../boot/](../boot/)), and the desktop helper
[../desktop/lid-policy/](../desktop/lid-policy/).

### How it works

- **Lid closed:** the driver tells the internal DCP firmware (A475(2)), powers the panel off
  (A472(0)) and reports the panel connector (`eDP-1`) **disconnected** until the lid opens. The
  panel is never powered while the lid is closed; a compositor that tries gets a warning, no
  firmware call.
- **Internal pipe for the left-front port:** while the lid is closed and the panel is off, the
  internal pipeline can drive a display on the left-front port (DisplayPort core 0, crossbar state
  `dispext0,0`). The rear port can only be driven by `dcpext`.
- **Ranking that matches the compositor:** Hyprland (aquamarine) gives each connected display the
  lowest free CRTC it may use and keeps it. The internal pipe's CRTC has the lower index, so while
  the lid is closed the kernel also routes a new front display to the internal pipe first. Kernel
  and compositor then always pick the same pipeline.
- **Move when needed:** if the front display already sits on `dcpext` (plugged in with the lid
  open) and a display on the rear port needs `dcpext` while the lid is closed (it arrives then, or
  it was already waiting when the lid closed), the front display moves to the internal pipe and
  `dcpext` takes the rear display (r12). Otherwise nothing moves on a lid close.
- **Lid open:** A475(1), the display on the internal pipe lets go of it (it waits for `dcpext`
  again, with the usual log line), the panel reconnects and powers on. A front display that can
  have a free `dcpext` reports itself only after the panel is connected again, so the panel gets
  its CRTC back.
- **Suspend policy:** a display that changes pipeline is unplugged for 3–5 s, and logind suspends a
  closed laptop the moment it counts no external display. The lid-policy helper takes the lid
  switch from logind and waits 10 s before it locks and suspends.

### Test results (test kernels r11/r12 + lid-policy)

| Test | Result |
|---|---|
| Lid closed, no display → locked, then suspended (lid-policy) | ✅ |
| Lid closed, portable display plugged into the front port → internal pipe, picture | ✅ |
| Lid closed, ultrawide plugged into the rear port as well → `dcpext`, both displays with a picture | ✅ |
| Lid open → panel back after 33–173 ms, front display waits, rear display stays | ✅ |
| 5 close/open cycles with both displays | ✅ 5/5, front display on the internal pipe ~2.5 s after closing |
| Lid open, rear display waits, lid closed | ❌ r11 (rear display not offered `dcpext` until replugged) → ✅ r12: front display to the internal pipe after ~2.5 s, rear display takes `dcpext` after ~5 s, no suspend |
| Front display on `dcpext`, lid closed (nothing moves), rear display arrives → move | ✅ r12, ~3 s without an external display bridged by lid-policy |
| Suspend with the lid closed and both displays, wake by opening the lid | ✅ r12: locked before suspend, panel and rear display back at once, front display waits (lid open). A USB keyboard cannot wake the Mac from s2idle, so a resume with the lid still closed cannot be tested |
| Boot with the lid closed, both displays plugged in | ✅ r12: panel never powered, rear display on `dcpext`, front display on the internal pipe |

### What went wrong on the way (and why the design looks like this)

- **Panel powered with the lid closed (r7):** after A475(2) the firmware treats the internal pipe
  as the second external display and swallows panel frames; the next call times out and the
  internal DCP is gone until a reboot. Omarchy powers the panel whenever no external display is
  left, and Hyprland does at start-up. → the panel is reported disconnected while the lid is
  closed and is never powered then.
- **Suspend in the middle of a move (r8, r10):** logind counted zero external displays for a few
  milliseconds and suspended at once. Keeping the moving display "connected" does not work with
  aquamarine (it keeps a connected display's CRTC, so the other display never gets one). → the
  lid-policy helper with a grace period.
- **CRTC mismatch (r10):** with the panel disconnected, Hyprland gave a newly plugged front display
  the internal pipe's CRTC while the kernel had routed it to `dcpext`: every mode was refused, and
  on lid open the panel found its CRTC taken. → the internal-pipe-first ranking while the lid is
  closed (r11).

### Open items

- After a resume, the two ports renegotiate and whichever display comes back first gets `dcpext`;
  with the lid open the other one waits (once the front display got it although the rear display
  had it before the suspend).
- A late power-off after a quick unplug/replug of the rear display can still drop the new
  connection (seen on r7, diagnostics in the test kernels).
- Not specific to the lid-closed work: when the desktop blanks the screens (DPMS off, e.g. on the
  lock screen), the internal panel goes black but keeps its backlight on. This has been so since
  the first Omarchy start on this Mac.
- Patches without `Signed-off-by`; no release yet.
