# USBPcap capture guide — Mystic Light (1462:921b)

Goal: record the USB traffic that **MSI Center → Mystic Light** sends when
you change a color, so we can identify the missing "apply" command for the
Linux driver (`src/msi-mystic.c`). Takes ~10 minutes.

## 1. Prepare (in Windows)

1. Install **Wireshark** (includes USBPcap — keep the "Install USBPcap"
   checkbox ticked during setup): https://www.wireshark.org/
2. Make sure **MSI Center** is installed and its **Mystic Light** module
   shows your fans/cooler/strips.

## 2. Capture

1. Launch **USBPcapUI** (Start menu → USBPcap).
2. In the device list pick the root hub / device that shows
   **"MSI MYSTIC LIGHT"** (VID `1462`, PID `921B`). If unsure which entry:
   expand each root hub — the device is named "MYSTIC LIGHT" or "MSI".
   Safe fallback: sniff **all root hubs** (file gets bigger, still fine).
3. Leave filters empty, click **Start**. Save as `mystic.pcapng`
   (e.g. on the Desktop). Keep it running.
4. Now perform EXACTLY this script in MSI Center → Mystic Light,
   with ~10 s pauses between steps (the pauses make the steps findable):

   | Step | Action                                   |
   |------|------------------------------------------|
   | 1    | Select ALL channels → Static → **red** → Apply |
   | 2    | wait 10 s                                |
   | 3    | Static → **blue** → Apply                |
   | 4    | wait 10 s                                |
   | 5    | Effect **Rainbow** → Apply               |
   | 6    | wait 10 s                                |
   | 7    | **Off** → Apply                          |
   | 8    | wait 10 s                                |
   | 9    | back to your preferred setting → Apply  |

5. Stop the capture (USBPcapUI window → Stop). Close MSI Center first if
   the file stays locked.

## 3. Bring it back to Omarchy

Copy `mystic.pcapng` to the Linux side, e.g. into the repo:

```bash
# from Omarchy, if the file is on a shared/accessible partition:
cp /path/to/mystic.pcapng ~/Projects/localconf/omarchy-msi-rgb/assets/
```

Then: `tshark -r assets/mystic.pcapng -Y 'usb.capdata' -T fields -e usb.dst -e usb.capdata`
already shows every report MSI Center sent — from there we diff against our
own write sequence and implement the apply step in `msi-mystic`.

## Troubleshooting

- **Device not listed in USBPcapUI:** unplug/replug is not possible (it's
  internal) — try "Install device driver" in USBPcapUI first.
- **Capture is empty:** you sniffed the wrong hub — restart and pick the
  next root hub, or sniff all of them.
- **MSI Center missing:** get it from MSI support page for "MEG Vision X AI".
