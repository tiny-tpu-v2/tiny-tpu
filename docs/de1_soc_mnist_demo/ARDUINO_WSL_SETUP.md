# ABOUTME: Records the verified Arduino-on-WSL setup used for this MNIST demo.
# ABOUTME: Keeps the required attach, compile, and upload commands inside this project folder.

# Arduino On WSL2 For This Demo

This project was verified with an Arduino Uno attached to WSL2 and programmed from WSL.

Known-good environment:

- board: Arduino Uno
- WSL device path: `/dev/ttyACM0`
- CLI: `/usr/local/bin/arduino-cli`
- core: `arduino:avr`

## 1. Attach the Uno into WSL

From Windows, use `usbipd-win`:

```powershell
& 'C:\Program Files\usbipd-win\usbipd.exe' list
& 'C:\Program Files\usbipd-win\usbipd.exe' attach --wsl --busid <BUSID>
```

`BUSID` is not stable. Always rerun `list` first.

## 2. Verify the board from WSL

```bash
arduino-cli board list
```

Expected output includes:

- port: `/dev/ttyACM0`
- board: `Arduino UNO`
- fqbn: `arduino:avr:uno`

## 3. Fix serial permissions if needed

If uploads fail with `Permission denied` on `/dev/ttyACM0`:

```bash
sudo usermod -aG dialout "$USER"
newgrp dialout
```

Then retry `arduino-cli board list`.

## 4. Compile and upload the MNIST touchscreen sketch

From this folder:

```bash
arduino-cli compile --fqbn arduino:avr:uno arduino_touch_sender
arduino-cli upload -p /dev/ttyACM0 --fqbn arduino:avr:uno arduino_touch_sender
```

## 5. Common recovery case

If the Uno disappears from WSL during an upload:

1. Check Windows still sees it with `usbipd.exe list`
2. Re-run:

```powershell
& 'C:\Program Files\usbipd-win\usbipd.exe' attach --wsl --busid <BUSID>
```

3. Verify `arduino-cli board list` again in WSL
4. Retry the upload
