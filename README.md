![alt text](https://img.shields.io/badge/License-MIT-yellow.svg)

![alt text](https://img.shields.io/badge/platform-macOS-lightgrey.svg)

![alt text](https://img.shields.io/badge/Swift-5.9+-orange.svg)

# Swift-BepInEx-Launcher
#### © 2025 - Gregorio Litenstein Goldzweig
---

**OVERVIEW**: A Swift reimplementation of the BepInEx launcher script for macOS.

**USAGE**:
```
Swift-BepInEx-Launcher [<options>] --executable-name <executable-name> [<game-arguments> ...]
```

**ARGUMENTS**:
  ` <game-arguments> `
  > Arguments to pass through to the game executable.

**OPTIONS**:

  `--enable-doorstop` / `--disable-doorstop`
  > Doorstop injection. (default: `--enable-doorstop`)

  `--doorstop-ignore-disabled` / `--ignoreDisable`
  > If true, the `DOORSTOP_DISABLE` environment variable is ignored.

  `--enable-mono-debug` / `--disable-mono-debug`
  > Enable the Mono debugger server. (default: `--disable-mono-debug`)

  `--enable-mono-debug-suspend` / `--enableDebugSuspend` / `--disable-mono-debug-suspend` / `--disableDebugSuspend`
  > Suspend game on start until a Mono debugger is attached. (default: `--disable-mono-debug-suspend`)

  `--baseDir` / `--base` / `--in-base-dir <baseDir>`
  > Base folder used for resolving other relative paths. (default: `$(PWD)`)

  `--doorstop-dir <doorstop-dir>`
  > Folder in which to look for libdoorstop. (default: `doorstop_libs`)

  `--doorstop-name <doorstop-name>`
  > Doorstop library name.

  `--target-arch <target-arch>`
  > Override architecture detection for target executable. Useful when target is a shell script.

  `--dll-paths` / `--dllSearch` / `--searchpathOverride <dll-paths>`
  > Override path for Mono DLLs.

  `--mono-debug-address` / `--debugAddress <mono-debug-address>`
  > Address for the Mono debugger server. (default: `127.0.0.1:10000`)

  `--executable-name` / `--executable <executable-name>`
  > Path to the game's `.app` bundle or executable.

  `--boot-config <boot-config>`
  > Override path to `boot.config`.

  `--target-assembly` / `--doorstopAssembly <target-assembly>`
  > Path to the .NET assembly to preload. (default: `BepInEx/core/BepInEx.Preloader.dll`)

  `--profile` / `--r2Profile <profile>`
  > Path to the folder containing the `doorstop-dir`. (default: `Default`)

  `--help`
  > Show help information.