# TODO List

Priority key:
- `[A]` do soon,
- `[B]` worth doing,
- `[C]` nice to have,
- `[D]` low priority / someday,
- `[x]` done (kept for context),
- `[?]` open question / needs a decision.

Dates are when the item was raised or last touched.

## Build / infra

- [A] @ci Add GitHub Actions CI: run `./gradlew assembleDebug` (and `lint`
      once it's clean) on push/PR (2026-08-11/12). This build was silently
      broken for a long time before this session — jcenter (the only
      configured repository) shut down and AGP 2.3.2 doesn't run on modern
      JDKs — and nothing would have surfaced that without someone trying to
      build it from scratch. CI would have caught it immediately.

- [x] DONE 2026-08-12: modernized the build off jcenter/AGP 2.3.2 to
      mavenCentral+google/AGP 8.5.2, bumped compileSdk to 34 and minSdk to
      21 (AGP 8 requires minSdk >= 21), committed the Gradle wrapper (it was
      previously gitignored by a leftover Android Studio template rule —
      `.gitignore` had a blanket `/gradle*`), and added a `Makefile` with
      build/install/uninstall/clean/lint/logcat/wireless/emulator/wrapper
      targets.

- [B] @tests No automated tests exist anywhere in the project (2026-08-12).
      `CalendarResolver` (`app/src/main/java/.../CalendarResolver.java`) is
      the highest-value target: it's the one class with zero Android
      framework dependency — pure `java.util.Calendar` date math — so it's
      trivially unit-testable without Robolectric/instrumentation, and it's
      exactly the "recurring date" logic this session's bug hunt centered
      on (see the SmsSentService item below). A regression here is the
      class of bug that's genuinely hard to notice locally (symptom is
      "stops working after a few days") and easy to catch with a few
      `advance()`/`setWeekDay()` test cases around month/year boundaries and
      DST transitions.

- [?] @release No release/signing config exists — only `assembleDebug`
      works out of the box (2026-08-12). Fine for personal sideloading
      (what this session did), but if this is ever meant to be shared as a
      built artifact rather than "clone and build," it needs a real
      keystore + signing config. Not decided whether that's wanted.

## Reliability (recurring sms)

- [x] DONE 2026-08-12: fixed the bug where a recurring message's status got
      clobbered. Root cause: `SmsSenderService` advances the row to the
      next occurrence and saves it as `PENDING` *before* the sms actually
      finishes sending; `SmsSentService`'s sent-confirmation callback then
      reloads the same row (recurring messages reuse one db row per
      series) and overwrote that `PENDING` back to `SENT`/`FAILED`. The
      underlying `AlarmManager` alarm was always correctly scheduled
      regardless — this only corrupted what the list screen displayed —
      but it's a very plausible source of "I thought it stopped working"
      reports, since a user seeing "Sent" for what should be a future
      occurrence could reasonably conclude it broke and delete it
      themselves. Fix: `SmsSentService` now checks if the row is recurring
      and its (already-advanced) scheduled time is still in the future,
      and if so leaves the status as `PENDING`. Verified end-to-end on an
      emulator: fired the alarm, confirmed the row advances a day, stays
      `PENDING`, and the next alarm gets armed (`dumpsys alarm`).

- [x] DONE 2026-08-12: fixed `Scheduler`'s `PendingIntent` flags
      (`app/src/main/java/.../Scheduler.java`), which were computed as
      `PendingIntent.FLAG_UPDATE_CURRENT & Intent.FILL_IN_DATA` — a bitwise
      AND of two unrelated flag namespaces that always evaluates to `0`.
      In practice this was likely inert for THIS app specifically (the
      alarm's extras never change between reschedules of the same series,
      and `AlarmManager.setExact*` replaces an existing alarm for a
      matching `PendingIntent` regardless of `FLAG_UPDATE_CURRENT`), but it
      was clearly not what the code intended, and it's exactly the kind of
      latent bug that becomes a real crash the moment `targetSdk` crosses
      31 (Android 12+ requires `FLAG_MUTABLE`/`FLAG_IMMUTABLE` to be
      explicitly set for apps targeting S+). Fixed to just
      `PendingIntent.FLAG_UPDATE_CURRENT`.

- [B] @reliability Aggressive OEM battery management (Samsung/Xiaomi/etc.,
      less so stock Pixel/AOSP) is a very common real-world cause of
      "scheduled thing silently stops after some days" for exactly this
      class of app, independent of anything fixable in this codebase
      (2026-08-12). Consider a one-tap "exempt this app from battery
      optimization" settings shortcut
      (`ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`) surfaced somewhere in
      the app (e.g. the settings screen), so future users on
      battery-aggressive devices have an obvious lever instead of hunting
      through OEM settings menus.

- [?] @targetsdk Deferred decision: `targetSdk` is pinned at 30
      (2026-08-12), specifically to keep legacy "always allowed" exact-alarm
      scheduling and avoid the Android 12+ `SCHEDULE_EXACT_ALARM` permission
      flow and the Android 13+ runtime notification permission. This was the
      right call to get unblocked, but it's not a permanent answer — if this
      app ever needs to target a newer SDK (e.g. to be published somewhere
      that enforces a minimum target), revisit:
  - `Scheduler`'s `PendingIntent`s and `SmsSenderService.getPendingIntent`
    (`PendingIntent.getBroadcast(this, 0, intent, 0)`, currently flags=0)
    both need an explicit `FLAG_MUTABLE`/`FLAG_IMMUTABLE` — required at
    targetSdk 31+, currently absent from both.
  - Need to request `SCHEDULE_EXACT_ALARM` (or check
    `AlarmManager.canScheduleExactAlarms()`) and handle the user-facing
    permission grant flow.
  - Need `POST_NOTIFICATIONS` runtime permission handling at targetSdk 33+
    (the app posts notifications for send success/failure/reminders today
    with no permission request path).

## Minor / cleanup

- [C] @db `DbHelper.delete()` calls `getReadableDatabase().delete(...)`
      (`app/src/main/java/.../DbHelper.java:160`) — should be
      `getWritableDatabase()` like every other mutating method in the file
      (`save`'s insert/update both correctly use `getWritableDatabase()`).
      In practice `SQLiteOpenHelper` usually hands back the same
      underlying writable connection either way, so this likely isn't
      causing an active bug, but it's misleading and inconsistent with the
      rest of the file. Cheap fix whenever `DbHelper.java` is next touched.

- [D] @scheduler `Scheduler.getAlarmPendingIntent`'s request code is
      `(int) (timestampCreated / 1000L)` — truncates a millisecond
      timestamp to seconds then casts to `int`. Fine today (current unix
      seconds fit in a 32-bit int), but this is the classic year-2038
      problem shape. Not urgent; noting it so it isn't a surprise someday.

## Explicitly decided against (kill notes)

- [x] KILL NOTE 2026-08-12: rewriting this in Dart/Flutter. Discussed as a
      "what would the lift be" hypothetical (user has Flutter experience
      via another project, Bakelorium). Estimated at roughly 2-4 days given
      existing Flutter fluency — UI/DB port is fast, the real cost is
      background-alarm reliability on Android, which would face the same
      class of Doze/battery-optimization problem this app already has, and
      SMS auto-send is Android-only regardless of framework (iOS doesn't
      allow it), so a rewrite wouldn't buy cross-platform reach either.
      User explicitly deprioritized this in favor of other work — revisit
      only if that changes.
