# Experimental Amiga LLAPI / SNAC variants

Based on MiSTer-devel/Minimig-AGA_MiSTer `bf5d061b414fa0c8cd56f0e6941c586202ebfbaa` (2026-10-28), including its latest Action Replay changes. Independent MiSTer-LLAPI fork; original authors, commit history and license notices are preserved. No Kickstart or game data is supplied.

These are **separate RBFs**, selected in the MiSTer core browser. They use the **official Main** without adding a new USER-port selector to its custom Amiga menu.

| RBF variant | USER port | Players |
|---|---|---|
| Original-USER | Official MT32-pi / physical floppy support | USB as upstream |
| LLAPI-2P | LLAPI, both sockets | 2 |
| SNAC-DB15-2P | Original Jotego/Antonio Villena DB15 splitter | 2 |
| SNAC-SNES-2P | Official SNES dual-port wiring | 2 |
| SNAC-DB9-1P | Mega Drive 3/6-button protocol | 1 + USB P2 |
| SNAC-NES-2P | Official NES dual-port wiring | 2 |
| SNAC-SATURN-1P | Saturn digital pad | 1 + USB P2 |

In controller RBFs, the USER connector belongs exclusively to the named controller protocol. MT32-pi is held in reset, its input is isolated, and physical floppy support is disabled. The stock Main's MT32-pi/floppy menu does not change the compiled protocol. Load Original-USER for those peripherals; they cannot share USER with these controllers. Virtual ADF/HDF storage remains available in controller variants.

Keep the DE10-Nano SW1 **OFF**, as the standard framework uses some USER pins for I2S when it is ON. Use a compatible adapter for the selected protocol. No Bliss-Box cable profile, multitap, lightgun or Saturn analog handshake is included.

Controller P1 replaces HPS joystick 0, P2 replaces joystick 1, preserving upstream joystick swapping. Normally P1 reaches the Amiga joystick port and P2 the mouse port; press Fire to activate joystick use of that port. Existing mouse, keyboard and USB handling otherwise remains upstream. LLAPI falls back to USB when no socket is active. SNAC variants reserve their declared player slots because passive pads do not provide reliable presence detection. Single-player SNAC variants use USB joystick 0 for P2.

## Wiring

USER pin indices are **0..6**, not connector contact numbers.

- SNES: shared latch USER0; P1 clock/data USER1/5; P2 clock/data USER3/6.
- NES: shared latch USER0; P1 clock/data USER3/5; P2 clock/data USER1/6. Both clocks are polled together. Ordinary 8-bit NES pads only.
- DB15 splitter: load USER0, clock USER1, data USER5; original Jotego push-pull load/clock drive is retained. This requires the serial DB15 adapter, not a direct parallel DB15 joystick cable.
- Mega Drive: TH USER4; C/B/R/L/D/U on USER6/2/3/5/0/1.
- Saturn: TH USER4, TR USER6, D3..D0 USER3/5/0/1; TL USER2 released.
- LLAPI: socket 1 latch/data USER0/1; socket 2 USER4/5; OSD USER2.

Reference pinouts: [SNES](https://github.com/MiSTer-devel/SNES_MiSTer), [NES](https://github.com/MiSTer-devel/NES_MiSTer/blob/master/NES.sv), [Genesis](https://github.com/MiSTer-devel/Genesis_MiSTer), [Saturn](https://github.com/MiSTer-devel/Saturn_MiSTer). DB15 and MIT LLAPI engines are carried with their original license notices from the MiSTer-LLAPI 1943 integration.

## Amiga / CD32 button mapping

| Source | Red / Fire | Blue | Yellow | Green | RT | LT | Pause |
|---|---|---|---|---|---|---|---|
| LLAPI common IDs | 0 | 1 | 2 | 3 | 7 | 6 | Start (5) |
| DB15 | A | B | C | D | E | F | Start |
| SNES | B | Y | A | X | R | L | Start |
| Mega Drive | B | C | A | X (6-button) | Z (6-button) | Y (6-button) | Start |
| NES | A | B | — | — | — | — | Start |
| Saturn digital | B | C | A | X | R | L | Start |

Select+Start opens OSD on SNES, NES and DB15. Down+Start+Fire opens OSD on LLAPI, Mega Drive and Saturn. Either player can open OSD, and controller game input is inhibited while OSD is active. F12 remains available.

## Validation and limitations

Automated tests cover independent SNES/NES players, full button mapping and release, original DB15 serial chain, Mega Drive 3/6-button handshake, Saturn digital signals, LLAPI decoded packet mapping/USB fallback/CDC and OSD inhibition. The unchanged MIT LLAPI wire engine is not independently reimplemented by the mapping test.

**Physical hardware validation is pending for every new Amiga variant.** The previously reported Mega Drive three-button issue on the 1943 pilot remains unresolved; passing this simulation is not evidence that the hardware issue is fixed. No measured latency claim is made.

The build workflow compiles all seven variants with Quartus 17.0, requires non-negative setup, hold, recovery, removal and pulse-width slack, and publishes a pre-release only if every variant passes. Reports and source identity accompany the binaries.

Build locally with Quartus 17.0.2: `bash tests/controllers/build.sh MODE NAME`, using MODE 0..6 in the table order above. `AMIGA_SERIAL_MODE` defaults to 1 (LLAPI) if not explicitly set. Run controller simulation with `bash tests/controllers/run.sh`.
