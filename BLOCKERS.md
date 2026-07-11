# Roadmap blockers

## PLAN-save-panel-flow

The implementation was applied exactly as specified and `/bin/zsh scripts/verify.sh`
completed with `VERIFY OK`, but the required manual acceptance criteria could not be
performed in the current Codex execution environment. Per the failure protocol, the
uncommitted implementation was reverted to the last green commit.

### Failing command 1

```sh
osascript -e 'tell application "System Events" to get name of every process whose name is "DewQRaft"' -e 'tell application "System Events" to tell process "DewQRaft" to get description of every menu bar item of menu bar 1'
```

Full output:

```text
154:165: execution error: System Events got an error: osascript is not allowed assistive access. (-1719)
```

### Failing command 2

```sh
screencapture -x /private/tmp/dewqraft-save-flow-start.png
```

Full output:

```text
could not create image from display
```

### What was tried

1. Ran the plan's required pre-change `/bin/zsh scripts/verify.sh`; it exited 0 and
   printed `VERIFY OK`.
2. Applied Steps 1–4 exactly to `macos/DewQRaftApp.swift`; `git diff --name-only`
   listed only that file and `git diff --check` passed.
3. Ran the plan's required post-change `/bin/zsh scripts/verify.sh`; it exited 0 and
   printed `VERIFY OK`, including all 38 smoke checks.
4. Launched the required artifact with `open build/DewQRaft.app`; the process ran.
5. Tried to drive and inspect the menu-bar UI with macOS Accessibility through
   System Events; the environment denied assistive access with error `-1719`.
6. Tried to gather direct visual evidence with `screencapture`; the environment
   could not create an image from the display.
7. Stopped the launched app and reverted the uncommitted implementation with
   `git checkout -- .` as required. No manual result was assumed.

## PLAN-launch-at-login

The ServiceManagement feasibility probe printed `PROBE-OK`, the pre-change gate
completed with `VERIFY OK`, and the implementation was applied exactly as specified.
The post-change hard gate failed because the system volume ran out of space while
rendering the generated app icon. Per the failure protocol, the implementation was
reverted and was not committed.

### Failing command

```sh
/bin/zsh scripts/verify.sh > /private/tmp/dewqraft-launch-post-verify.log 2>&1
```

Full output:

```text
== Info.plist lint
/Users/kevinyongcj/Programming/dewQRaft/macos/Info.plist: OK
== shell script syntax
syntax OK: build-mac-app.sh
syntax OK: package-release.sh
syntax OK: verify.sh
== build (swift compile + bundle + ad-hoc sign)
Swift/ErrorType.swift:254: Fatal error: Error raised at top level: Error Domain=NSCocoaErrorDomain Code=640 "You can’t save the file “icon_512x512.png” because the volume “Macintosh HD” is out of space." UserInfo={NSFilePath=/Users/kevinyongcj/Programming/dewQRaft/build/DewQRaft.iconset/icon_512x512.png, NSURL=file:///Users/kevinyongcj/Programming/dewQRaft/build/DewQRaft.iconset/icon_512x512.png, NSUnderlyingError=0x971aa0810 {Error Domain=NSPOSIXErrorDomain Code=28 "No space left on device"}}
Stack dump:
0.	Program arguments: /Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/swift-frontend -frontend -interpret /Users/kevinyongcj/Programming/dewQRaft/scripts/render-app-icon.swift -Xllvm -aarch64-use-tbi -enable-objc-interop -stack-check -sdk /Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX26.5.sdk -no-color-diagnostics -Xcc -fno-color-diagnostics -new-driver-path /Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/swift-driver -empty-abi-descriptor -no-auto-bridging-header-chaining -module-name main -disable-clang-spi -target-sdk-version 26.5 -target-sdk-name macosx26.5 -external-plugin-path /Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/usr/lib/swift/host/plugins#/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/usr/bin/swift-plugin-server -external-plugin-path /Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/usr/local/lib/swift/host/plugins#/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/usr/bin/swift-plugin-server -in-process-plugin-server-path /Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/host/libSwiftInProcPluginServer.dylib -plugin-path /Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/host/plugins -plugin-path /Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/local/lib/swift/host/plugins -- /Users/kevinyongcj/Programming/dewQRaft/build/DewQRaft.iconset
1.	Apple Swift version 6.3.2 (swiftlang-6.3.2.1.108 clang-2100.1.1.101)
2.	Compiling with effective version 5.10
3.	While running user code "/Users/kevinyongcj/Programming/dewQRaft/scripts/render-app-icon.swift"
Stack dump without symbol names (ensure you have llvm-symbolizer in your PATH or set the environment var `LLVM_SYMBOLIZER_PATH` to point to it):
0  swift-frontend           0x000000010939ca30 llvm::sys::PrintStackTrace(llvm::raw_ostream&, int) + 56
1  swift-frontend           0x0000000109399ed0 llvm::sys::RunSignalHandlers() + 172
2  swift-frontend           0x000000010939d020 SignalHandler(int, __siginfo*, void*) + 356
3  libsystem_platform.dylib 0x000000018e82f744 _sigtramp + 56
4  libswiftCore.dylib       0x00000001a2044cc8 $ss17_assertionFailure__4file4line5flagss5NeverOs12StaticStringV_SSAHSus6UInt32VtF + 172
5  libswiftCore.dylib       0x00000001a1f25258 swift_errorInMain + 632
6  (error)                  0x0000000119700ba8
7  swift-frontend           0x0000000103090c48 llvm::orc::runAsMain(int (*)(int, char**), llvm::ArrayRef<std::__1::basic_string<char, std::__1::char_traits<char>, std::__1::allocator<char>>>, std::__1::optional<llvm::StringRef>) + 908
8  swift-frontend           0x0000000102f8df94 swift::SwiftJIT::runMain(llvm::ArrayRef<std::__1::basic_string<char, std::__1::char_traits<char>, std::__1::allocator<char>>>) + 636
9  swift-frontend           0x0000000102f9a23c swift::RunImmediately(swift::CompilerInstance&, std::__1::vector<std::__1::basic_string<char, std::__1::char_traits<char>, std::__1::allocator<char>>, std::__1::allocator<std::__1::basic_string<char, std::__1::char_traits<char>, std::__1::allocator<char>>>> const&, swift::IRGenOptions const&, swift::SILOptions const&, std::__1::unique_ptr<swift::SILModule, std::__1::default_delete<swift::SILModule>>&&) + 964
10 swift-frontend           0x0000000102f0e0d0 processCommandLineAndRunImmediately(swift::CompilerInstance&, std::__1::unique_ptr<swift::SILModule, std::__1::default_delete<swift::SILModule>>&&, llvm::PointerUnion<swift::ModuleDecl*, swift::SourceFile*>, swift::FrontendObserver*, int&) + 484
11 swift-frontend           0x0000000102f0789c performCompileStepsPostSILGen(swift::CompilerInstance&, std::__1::unique_ptr<swift::SILModule, std::__1::default_delete<swift::SILModule>>, llvm::PointerUnion<swift::ModuleDecl*, swift::SourceFile*>, swift::PrimarySpecificPaths const&, int&, swift::FrontendObserver*, llvm::ArrayRef<char const*>) + 2068
12 swift-frontend           0x0000000102f06ecc swift::performCompileStepsPostSema(swift::CompilerInstance&, int&, swift::FrontendObserver*, llvm::ArrayRef<char const*>) + 4560
13 swift-frontend           0x0000000102f0c3a0 performCompile(swift::CompilerInstance&, int&, swift::FrontendObserver*, llvm::ArrayRef<char const*>) + 4028
14 swift-frontend           0x0000000102f08818 swift::performFrontend(llvm::ArrayRef<char const*>, char const*, void*, swift::FrontendObserver*) + 3308
15 swift-frontend           0x0000000102e88424 swift::mainEntry(int, char const**) + 5224
16 dyld                     0x000000018e467e00 start + 6992
```

### Revert obstacle

The first two mandated revert attempts also failed because Git could not create its
lock file:

```sh
git checkout -- .
```

Full output from each attempt:

```text
fatal: Unable to create '/Users/kevinyongcj/Programming/dewQRaft/.git/index.lock': No space left on device
```

### What was tried

1. Created the exact temporary feasibility probe in `/tmp`; `swiftc -typecheck`
   completed with `PROBE-OK`.
2. Ran the plan's required pre-change `/bin/zsh scripts/verify.sh`; all 41 smoke
   checks passed and it printed `VERIFY OK`.
3. Applied Steps 1–4 exactly. `git diff --name-only` listed only
   `macos/DewQRaftApp.swift` and `scripts/build-mac-app.sh`; `git diff --check`
   passed.
4. Ran the post-change gate, which failed with the full disk error above.
5. Tried the required revert twice; both attempts failed with the lock-file error
   above.
6. Confirmed that only 115 MiB was available and that the ignored, generated
   `build/` directory used 2.5 MiB. Removed only that disposable build output; the
   build script recreates it and AGENTS.md forbids committing it.
7. Retried `git checkout -- .`; the revert then succeeded. No launch-at-login code
   was committed.
