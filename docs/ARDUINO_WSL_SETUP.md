# Arduino on WSL2 (Arduino Uno)

## Outcome

Programming an Arduino Uno from WSL2 works on this machine.

Verified result:

- The Uno was attached from Windows into WSL with `usbipd-win`.
- WSL exposed the board as `/dev/ttyACM0`.
- `arduino-cli` was installed in WSL at `/usr/local/bin/arduino-cli`.
- The `arduino:avr` core was installed.
- A sketch named `Blink` was compiled and uploaded successfully to the Uno.
- A real LED blink sketch was later compiled and uploaded successfully to the Uno.

Important caveat:

- The uploaded sketch was the default empty template created by `arduino-cli sketch new`, not the Arduino example that toggles the onboard LED.
- That means a blinking `L` LED should not be expected from the current sketch.
- The LED was not visually observed by the agent.

## Environment We Verified

- Host: Windows with `usbipd-win` installed via `winget`
- WSL: `WSL 2`
- Distro: `Ubuntu 24.04.2 LTS`
- Kernel: `6.6.87.2-microsoft-standard-WSL2`
- Board: `Arduino Uno`
- Windows device identity when present: `VID:PID 2341:0043`

## What We Found

1. WSL2 is the correct path for Arduino USB programming. This would not be a good setup on WSL1.
2. `usbipd-win` was not initially installed and had to be added from Windows.
3. After install, `usbipd` was not immediately available by short name in the same PowerShell session because PATH had not refreshed yet.
4. The full executable path worked immediately:
   `C:\Program Files\usbipd-win\usbipd.exe`
5. The Uno did not appear in `usbipd list` at one point even though Windows still had an `Arduino Uno (COM5)` device. Replugging and checking again restored the current USB bus entry.
6. `BUSID` is not stable. A previously valid bus ID can become invalid if the device disconnects or re-enumerates.
7. `usbipd bind` requires an Administrator PowerShell.
8. After attach, `usbipd` reported the device would be available to all WSL2 distributions.
9. Inside WSL, the Uno appeared as `/dev/ttyACM0`.
10. The serial device was owned by `root:dialout`, so the user needed `dialout` group access to upload.
11. Before adding `surya` to `dialout`, uploads failed with `Permission denied` on `/dev/ttyACM0`.
12. After adding `surya` to `dialout`, upload succeeded.
13. During a later upload attempt, `/dev/ttyACM0` disappeared from WSL even though Windows still showed the Uno as `Shared`.
14. Re-running `usbipd attach --wsl --busid <BUSID>` restored the device in WSL and uploads worked again.

## Windows Setup

Install `usbipd-win` in an Administrator PowerShell:

```powershell
winget install --interactive --exact dorssel.usbipd-win
```

If `usbipd` is not recognized in the current PowerShell session, either:

- open a new PowerShell window, or
- use the full path:

```powershell
& 'C:\Program Files\usbipd-win\usbipd.exe' list
```

With the Arduino plugged in, find the current `BUSID`:

```powershell
& 'C:\Program Files\usbipd-win\usbipd.exe' list
```

Then bind and attach it:

```powershell
& 'C:\Program Files\usbipd-win\usbipd.exe' bind --busid <BUSID>
& 'C:\Program Files\usbipd-win\usbipd.exe' attach --wsl --busid <BUSID>
```

On this machine, the Uno was seen as:

- `Arduino Uno (COM5)`
- `BUSID 1-3` at the time of successful attach

Do not hardcode `1-3` in the future. Always rerun `list` first and use the current bus ID.

## WSL Setup

Verify the board is exposed:

```bash
ls /dev/ttyACM0 /dev/ttyUSB0 2>/dev/null
```

Install `arduino-cli`:

```bash
cd /tmp
curl -fsSL https://raw.githubusercontent.com/arduino/arduino-cli/master/install.sh | sh
sudo install /tmp/bin/arduino-cli /usr/local/bin/arduino-cli
```

Install the Uno toolchain:

```bash
arduino-cli core update-index
arduino-cli core install arduino:avr
```

Fix serial permissions:

```bash
sudo usermod -aG dialout "$USER"
```

Then open a new WSL shell, or run:

```bash
newgrp dialout
```

Verify board detection:

```bash
arduino-cli board list
```

Expected output should include something like:

- Port: `/dev/ttyACM0`
- Board: `Arduino UNO`
- FQBN: `arduino:avr:uno`

## Verified Compile and Upload

Create a sketch:

```bash
arduino-cli sketch new ~/Blink
```

Compile:

```bash
arduino-cli compile --fqbn arduino:avr:uno ~/Blink
```

Upload:

```bash
arduino-cli upload -p /dev/ttyACM0 --fqbn arduino:avr:uno ~/Blink
```

On this machine, compile succeeded and the `Blink` upload completed successfully to `/dev/ttyACM0`.

Clarification:

- This was the default empty sketch template named `Blink`.
- It was not the built-in Arduino LED blink example.
- If the actual blink example is desired, the sketch must be replaced with code that toggles `LED_BUILTIN`.

## Real Blink Example

A real blink sketch was later created here:

- [arduino-blink.ino](/home/surya/tiny-tpu/arduino-blink/arduino-blink.ino)

That sketch toggles `LED_BUILTIN` high for 1 second, then low for 1 second, in a continuous loop.

It was compiled and uploaded successfully to the Uno.

## What You Should See On The Board

For the real Arduino blink example on an Uno:

- The green power LED should stay on solid.
- The orange `L` LED should blink continuously.
- The blink timing should be about 1 second on, then 1 second off.

Notes:

- The green LED is only a power indicator. It should not blink during normal Blink operation.
- The `TX` and `RX` LEDs may flash briefly during upload, but they should not keep blinking after upload unless serial traffic is active.
- If the orange `L` LED stays solid or stays off, the real Blink example is not running correctly.

## Normal Day-to-Day Use

If the Uno is unplugged, replugged, or after a reboot:

1. In Windows, rerun `usbipd list`.
2. Use the current `BUSID`.
3. Reattach it to WSL:

```powershell
& 'C:\Program Files\usbipd-win\usbipd.exe' attach --wsl --busid <BUSID>
```

Then in WSL:

```bash
arduino-cli board list
```

If it shows up, compile and upload as usual.

If Windows still shows the board as `Shared` but WSL has lost `/dev/ttyACM0`, re-run the `attach` command anyway. That restored the device on this machine.

## Known Good State On This Machine

- `arduino-cli` is installed at `/usr/local/bin/arduino-cli`
- `arduino:avr` is installed
- User `surya` has been added to `dialout`
- The Uno was successfully detected in WSL as `/dev/ttyACM0`
- A blank sketch named `Blink` was successfully uploaded
- A real LED blink sketch was later uploaded from [arduino-blink.ino](/home/surya/tiny-tpu/arduino-blink/arduino-blink.ino)
- After the real blink upload, the expected visible result is a solid green power LED and a blinking orange `L` LED
