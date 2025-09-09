# Qin-F22-DumbPhone-Mod
This project aims to transform your Qin F22 to a dumb phone and switch back when needed.

# Qin F22 – Dual Personality Mod (Magisk)

This project transforms the Qin F22 (and other Android phones with hardware keypads) into a dual-personality phone:  
- Dumb mode: Touchscreen disabled, dumb launcher, T9 input method, radios off  
- Normal mode: Full Android experience with touchscreen, stock launcher, Gboard, Wi-Fi/Bluetooth/Data enabled  

The switch is hardware key combo controlled, so you can live with two phones in one:  
a distraction-free "feature phone" and a full Android smartphone.  

## Features

- Disable and enable touchscreen input dynamically  
- Switch between two launchers (dumb vs. normal)  
- Switch between two keyboards (T9 vs. Gboard)  
- Automatically applies different display profiles (resolution and density)  
- Radio control: Wi-Fi, Bluetooth, and mobile data toggled in dumb mode  
- Boot routine ensures phone starts in dumb mode by default  
- Fully portable: works on other Android devices with minimal changes  

## File Structure

- `service.sh` – Main loop, listens for hardware key combos and switches modes  
- `post-fs-data.sh` – Ensures touchscreen is disabled very early in boot before Android input stack is initialized  

Both scripts log their actions into `/data/local/tmp/` for debugging.  

## Key Combos

- Enable normal mode → `KEY_3 + KEY_6 + VideoMode`  
- Enable dumb mode → `KEY_1 + KEY_4 + Pound (#)`  

You can change these by editing `service.sh` and mapping your own keycodes.  

## Installation

1. Clone or download this repository  
2. Copy the folder to Magisk modules location:  
   ```bash
   /data/adb/modules/dual_personality/
3. Inside the module folder, place your scripts:

- service.sh → runs in background after boot

- post-fs-data.sh → runs very early in boot

4. Reboot your phone

## Detecting Event Files

Run:
  ```bash
  getevent -il
  ```
- This lists all input devices and their capabilities.

Example for keypad:
  ```nocode
  add device 1: /dev/input/event2
  name: "mtk-kpd"
  KEY_1, KEY_2, KEY_3 ...
  ```
- Use this path as KEYPAD_DEV.

Example for touchscreen:
  ```nocode
  add device 3: /dev/input/event3
  name: "fts_ts"
  ABS_MT_POSITION_X, ABS_MT_POSITION_Y ...
  ```
- Use this path as TOUCHSCREEN_DEV.

## Detecting Major and Minor Numbers

Run:
  ```bash
  ls -l /dev/input/eventX
  ```
- Example output:
  ```nocode
  crw------- 1 root root 13, 64 2025-09-09 10:00 event3
  ```
- Major = 13 , Minor = 64

These values are required in service.sh so the script can recreate the node when switching touchscreen back on.

-Alternatives if Commands Fail

 - If `rm /dev/input/eventX` does not persist (kernel respawns it), use:

`chmod 000 /dev/input/eventX`


 - If `cmd wifi set-wifi-enabled disabled` does not work, try:

`svc wifi disable`


 - If `service call bluetooth_manager 8` does not work, try:

`svc bluetooth disable`


 - If `cmd package set-home-activity` fails, manually set launcher in Android Settings → Apps → Default apps.

## Logs

`service.sh` logs → `/data/local/tmp/touchscreen_log.txt`

`post-fs-data.sh` logs → `/data/local/tmp/touchscreen_postfs_log.txt`

- To debug:

 tail -f /data/local/tmp/touchscreen_log.txt

## Portability Notes

This module **can** work on other Android phones with hardware keypads. To adapt it:

1. Change **KEYPAD_DEV** and **TOUCHSCREEN_DEV** to match your device

2. Adjust **IME package names** (for example Gboard vs. T9)

3. Adjust **Launcher package names**

4. Update **major** and **minor** numbers for your touchscreen node

5. Change **key combos** in the loop to match your available keys

## Security Note

 - In the sample code, a **hardcoded PIN** (3216) is used for **waking** the phone.
**Replace this with your own PIN, or remove it entirely** if you don’t use lockscreen security.

## Credits

 Scripts built with lots of trial, error, and exploration

 Thanks to ChatGPT for guidance, brainstorming, and debugging assistance

 Inspired by the desire to have a dual-personality phone: one part productivity-free dumbphone, one part full Android

License
