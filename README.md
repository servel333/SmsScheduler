
# SMS Scheduler

An Android app that lets you schedule a text message to be sent at a specific
time — once, or recurring daily/weekly/monthly/yearly.

This app is for you if:

* You keep forgetting to send a birthday sms to someone
* You have that friend who doesn't seem to know what an alarm is

## Features

* Schedule a one-off sms for a future date and time.
* Recurring messages: daily, weekly, monthly, or yearly.
* Optional reminder notification an hour before a message sends.
* Optional delivery reports (some carriers charge for these, so it's off by
  default).
* Dual-SIM support — pick which SIM a message sends from; if the device only
  has one active SIM, it's chosen automatically.
* Survives a reboot: pending messages are rescheduled on boot.

## Permissions

* `SEND_SMS` — required to actually send the message.
* `READ_CONTACTS` — powers the recipient autocomplete field.
* `READ_PHONE_STATE` — needed to enumerate SIMs for dual-SIM devices.
* `RECEIVE_BOOT_COMPLETED` — reschedules pending messages after a reboot,
  since Android clears app alarms on reboot.
* `WAKE_LOCK` — keeps the device awake just long enough to send a message
  when its alarm fires.

## Building

Requires the Android SDK (`ANDROID_HOME`/`local.properties` pointing at it)
and JDK 17+. The project ships its own Gradle wrapper, so no separate Gradle
install is needed.

```bash
./gradlew assembleDebug
```

or, using the bundled `Makefile` (`make help` lists every target):

```bash
make build       # ./gradlew assembleDebug
make install      # build + adb install -r onto a connected device/emulator
make uninstall
make clean
make lint
make logcat        # tail logcat filtered to this app's process
make devices       # adb devices -l
make emulator       # boot the api35 AVD
make wireless        # adb tcpip 5555, for switching a USB-connected device to wifi debugging
make wrapper           # regenerate/upgrade the Gradle wrapper
```

`compileSdk` is 34, `minSdk` 21, `targetSdk` 30. Target 30 is intentional —
staying at or below 30 keeps exact-alarm scheduling working the old
(pre-Android 12) way, without requiring the user to separately grant the
`SCHEDULE_EXACT_ALARM` permission. See `todo.md` for the tradeoffs of raising
it later.

## Known limitations

* No automated tests yet (see `todo.md`).
* Aggressive OEM battery management (Samsung/Xiaomi/etc., less so stock
  Pixel/AOSP) can still delay or drop alarms after the device has been idle
  for a while. Exempting the app from battery optimization on such devices
  helps. This is an OS/OEM behavior, not something the app can fully control.

Tested on Android 2.2 and Android 7 historically; current builds have been
verified on Android 15 (emulator) and a Pixel 8a.

## License

GPLv2 — see `LICENSE`.
