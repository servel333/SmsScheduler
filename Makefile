
MK_FILES = $(filter %Makefile %.mk,$(MAKEFILE_LIST))

.PHONY: help devices wrapper build install uninstall clean lint logcat wireless emulator

help:
	@grep -hE '^[a-zA-Z0-9._-]+ *:' $(MK_FILES) \
		| grep -v 'default:' \
		| grep -v '.PHONY' \
		| sed 's/://' \
		| xargs -I{} echo "  make {}"
	@echo
	@invoke help

devices:
	adb devices -l

wrapper:
	./gradlew wrapper --gradle-version 8.14

build:
	./gradlew assembleDebug

lint:
	./gradlew lint

emulator:
	emulator -avd api35 &

install: build
	adb install -r app/build/outputs/apk/debug/app-debug.apk

uninstall:
	adb uninstall com.github.yeriomin.smsscheduler

clean:
	./gradlew clean

logcat:
	adb logcat --pid=$$(adb shell pidof -s com.github.yeriomin.smsscheduler)

wireless:
	adb tcpip 5555
	@echo "Unplug USB, then run: adb connect <phone-ip>:5555"
