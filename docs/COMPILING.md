# Compiling Pool of Radiance

There are four useful ways to build this project. Pick the result you want:

| I want to run the game on... | Build on... | Go to... |
| --- | --- | --- |
| 64-bit Windows | 64-bit Linux, or Windows through WSL 2 | [Windows native build](#windows-native-build) |
| 32-bit Windows | 64-bit Linux, or Windows through WSL 2 | [Windows native build](#windows-native-build) |
| Apple Silicon macOS | An Apple Silicon Mac | [macOS native build](#macos-native-build) |
| 64-bit Linux | 64-bit Linux | [Linux native build](#linux-native-build) |
| DOS or DOSBox/DOSBox-X | DOSBox or DOSBox-X | [DOS build](#dos-build) |

The native ports use Free Pascal and SDL 3. The DOS version uses the original-era Borland and Microsoft tools. They are separate toolchains; setting up one does not set up the other.

You do not need the retail game files to compile. You do need a legally purchased copy of *Pool of Radiance* to run what you build. The game is sold in *Forgotten Realms: The Archives — Collection Two* on [GOG](https://www.gog.com/en/game/forgotten_realms_the_archives_collection_two) and [Steam](https://store.steampowered.com/app/1904580/Forgotten_Realms_The_Archives__Collection_Two/).

All commands in the native sections are run from the repository's top-level directory unless a step says otherwise.

If you do not have the source yet, clone it and enter the checkout:

```sh
git clone https://github.com/talonius/bc-pool-of-radiance.git
cd pool-of-radiance
```

## Native build: what the scripts do

The native build uses three scripts:

- `scripts/fpc-setup.sh` downloads a Free Pascal bootstrap compiler, builds the pinned compiler named in `build/toolchain`, and builds the supported cross-compilers.
- `scripts/sdl3-setup.sh` downloads and builds the pinned SDL 3 release named in `build/toolchain`.
- `build-native.sh` creates the game and its setup program.

The setup scripts normally install everything below `~/fpc`. They are safe to run again: a completed, matching toolchain is reused. To put the tools somewhere else, set `FPC_PREFIX` for every setup and build command:

```sh
export FPC_PREFIX="$HOME/por-toolchains"
scripts/fpc-setup.sh
scripts/sdl3-setup.sh
scripts/build-native.sh
```

The first setup takes a while and requires internet access. Later builds do not download or rebuild the toolchain unless the pinned versions change. A distribution-provided Free Pascal or SDL installation does not replace this setup; the scripts deliberately use known versions.

Every native build produces two programs:

- `poolrad` or `poolrad.exe` is the game.
- `poolcfg` or `poolcfg.exe` is the terminal-based setup program.

Run `poolcfg` from a terminal before starting the game if you want to change video, audio, save-directory, introduction, or gameplay settings.

## Windows native build

### Where to build it

The Windows executables are cross-compiled on an x86-64 Linux system. On a Windows computer, use WSL 2 with an x86-64 Linux distribution such as Ubuntu. The setup scripts do not currently build the toolchain in PowerShell, Command Prompt, MSYS2, or Cygwin.

If WSL is not installed, open an Administrator PowerShell window and run:

```powershell
wsl --install -d Ubuntu
```

Restart if Windows asks, then open Ubuntu. Keeping the checkout in the WSL filesystem (for example, below `~/src`) generally makes compilation much faster than building below `/mnt/c`.

### Install the prerequisites

On Ubuntu or Debian, this installs the build tools, MinGW cross-compilers, and the development packages used while SDL is built:

```sh
sudo apt update
sudo apt install build-essential git curl tar python3 pkg-config cmake ninja-build \
  mingw-w64 libasound2-dev libpulse-dev libaudio-dev libfribidi-dev \
  libjack-dev libsndio-dev libx11-dev libxext-dev libxrandr-dev \
  libxcursor-dev libxfixes-dev libxi-dev libxss-dev libxtst-dev \
  libxkbcommon-dev libdrm-dev libgbm-dev libgl1-mesa-dev \
  libgles2-mesa-dev libegl1-mesa-dev libdbus-1-dev libibus-1.0-dev \
  libudev-dev libthai-dev libpipewire-0.3-dev libwayland-dev \
  libdecor-0-dev liburing-dev
```

Some older distributions do not have every optional SDL package in that list. If `apt` names one unavailable package, remove that package and try again. The essential pieces for the Windows cross-build are the normal C/C++ build tools, Git, curl, tar, Python 3, CMake, Ninja, and both MinGW toolchains (`i686-w64-mingw32-*` and `x86_64-w64-mingw32-*`).

### Build 64-bit Windows

```sh
scripts/fpc-setup.sh
scripts/sdl3-setup.sh
scripts/build-native.sh x86_64-win64

sdl_root="$(scripts/sdl3-setup.sh --print)"
cp "$sdl_root/x86_64-win64/bin/SDL3.dll" obj/native/x86_64-win64/
```

The files to keep are:

```text
obj/native/x86_64-win64/poolrad.exe
obj/native/x86_64-win64/poolcfg.exe
obj/native/x86_64-win64/SDL3.dll
```

`SDL3.dll` must remain beside `poolrad.exe` and must have the same architecture as the executable.

### Build 32-bit Windows instead

```sh
scripts/build-native.sh i386-win32

sdl_root="$(scripts/sdl3-setup.sh --print)"
cp "$sdl_root/i386-win32/bin/SDL3.dll" obj/native/i386-win32/
```

The 32-bit files are in `obj/native/i386-win32`. Do not mix their `SDL3.dll` with the 64-bit build.

### Test the Windows build

Windows unit tests are also built on Linux and run through Wine. Install and configure Wine first, then run the matching target:

```sh
scripts/build-native.sh --test x86_64-win64
```

or:

```sh
scripts/build-native.sh --test i386-win32
```

Test executables, compiler output, and `TEST.LOG` are written below `obj/native/<target>/tests`.

### Run it on Windows

Make a backup of the installed game, then place `poolrad.exe`, `poolcfg.exe`, and the matching `SDL3.dll` in the directory containing the retail game data. For the complete Brazen Crows presentation and digital audio, also copy the files from `src/binaries` into that directory. Run `poolcfg.exe` in a terminal, then start `poolrad.exe` normally.

The Windows programs built here are native Windows programs. The warning in the DOS section applies to the old DOS compilers and DOS build, not to `poolrad.exe`.

## macOS native build

### Supported Mac

The current macOS target is Apple Silicon (`arm64`/`aarch64`) and requires macOS 11 or later. Intel Macs are not currently a build target.

Install Xcode or the Xcode Command Line Tools:

```sh
xcode-select --install
```

The build also needs Git, curl, tar, Make, and Python 3. The command-line tools supply most of these. Confirm Python is present:

```sh
python3 --version
```

If it is missing, install Python 3 from [python.org](https://www.python.org/downloads/macos/) or with Homebrew. `scripts/sdl3-setup.sh` will download its own pinned CMake and Ninja binaries if neither is already on `PATH`.

### Build and test

```sh
scripts/fpc-setup.sh
scripts/sdl3-setup.sh
scripts/build-native.sh --test macos
scripts/build-native.sh macos
```

The results are:

```text
obj/native/macos/Pool of Radiance.app
obj/native/aarch64-darwin/poolcfg
obj/native/aarch64-darwin/poolrad
```

The `.app` is the normal game application. The separate `poolcfg` program is run from Terminal. The raw `poolrad` executable is retained mostly for development and diagnosis.

The application is ad-hoc signed automatically, which is enough for a local build on the Mac that created it. Ad-hoc signing is not a substitute for Developer ID signing and notarization when distributing the application to other people.

### Run it on macOS

Make a backup of the retail game. Put `Pool of Radiance.app` and `poolcfg` in the directory containing its data files, then copy the files from `src/binaries` there as well. From Terminal:

```sh
cd "/path/to/your/Pool of Radiance directory"
./poolcfg
open "Pool of Radiance.app"
```

The game also honors `POOLRAD_DIR`. This is useful when you want to leave the build output where it is:

```sh
export POOLRAD_DIR="/path/to/your/Pool of Radiance directory"
open "obj/native/macos/Pool of Radiance.app"
```

### Optional: sign a distributable app

This step is only for someone with an Apple Developer ID Application certificate. After building, the signing helper can use a keychain identity and a saved `notarytool` profile named `poolrad`:

```sh
scripts/macos-sign.sh
```

To apply a Developer ID signature without submitting to Apple, use:

```sh
NOTARY_PROFILE=none scripts/macos-sign.sh
```

See the comments at the top of `scripts/macos-sign.sh` for API-key and `.p12` options used by unattended builders. A successful notarized build produces `obj/native/macos/Pool of Radiance.zip`.

## Linux native build

### Supported host and target

The Linux game builds for x86-64 (`x86_64-linux`) and, on an x86-64 host with a 32-bit C library installed, for 32-bit x86 (`i386-linux`): `scripts/sdl3-setup.sh` builds the 32-bit SDL3 only when `gcc -m32` can link, and says so when it cannot. Install the 32-bit C library first: `gcc-multilib` on Debian or Ubuntu, `glibc-devel.i686` and `libgcc.i686` on Fedora, `lib32-glibc` and `lib32-gcc-libs` on Arch. Then `scripts/build-native.sh i386-linux` builds it.

### Install the prerequisites

On Ubuntu or Debian:

```sh
sudo apt update
sudo apt install build-essential git curl tar python3 pkg-config cmake ninja-build \
  libasound2-dev libpulse-dev libaudio-dev libfribidi-dev libjack-dev \
  libsndio-dev libx11-dev libxext-dev libxrandr-dev libxcursor-dev \
  libxfixes-dev libxi-dev libxss-dev libxtst-dev libxkbcommon-dev \
  libdrm-dev libgbm-dev libgl1-mesa-dev libgles2-mesa-dev \
  libegl1-mesa-dev libdbus-1-dev libibus-1.0-dev libudev-dev \
  libthai-dev libpipewire-0.3-dev libwayland-dev libdecor-0-dev \
  liburing-dev
```

On Fedora, install the corresponding development toolchain and SDL build dependencies:

```sh
sudo dnf install gcc gcc-c++ git-core make curl tar python3 cmake ninja-build \
  pkgconf-pkg-config alsa-lib-devel fribidi-devel pulseaudio-libs-devel \
  pipewire-devel libX11-devel libXext-devel libXrandr-devel \
  libXcursor-devel libXfixes-devel libXi-devel libXScrnSaver-devel \
  libXtst-devel dbus-devel ibus-devel systemd-devel mesa-libGL-devel \
  libxkbcommon-devel mesa-libGLES-devel mesa-libEGL-devel vulkan-devel \
  wayland-devel wayland-protocols-devel libdrm-devel mesa-libgbm-devel \
  libusb1-devel libdecor-devel pipewire-jack-audio-connection-kit-devel \
  libthai-devel
```

Package names vary on other distributions. In addition to the C/C++ build toolchain, make sure Git, curl, tar, Python 3, CMake, Ninja, `pkg-config`, and the SDL audio/video development dependencies are available.

### Build and test

```sh
scripts/fpc-setup.sh
scripts/sdl3-setup.sh
scripts/build-native.sh --test x86_64-linux
scripts/build-native.sh x86_64-linux
```

The results are:

```text
obj/native/x86_64-linux/poolrad
obj/native/x86_64-linux/poolcfg
```

SDL is linked statically on Linux, so no separate SDL shared library needs to be copied beside the game.

### Run it on Linux

Make a backup of the retail game, then copy both programs and the project-generated data files into its directory:

```sh
cp obj/native/x86_64-linux/poolrad /path/to/game/
cp obj/native/x86_64-linux/poolcfg /path/to/game/
cp src/binaries/* /path/to/game/
cd /path/to/game
./poolcfg
./poolrad
```

Instead of copying the executables, you can point them at the game data with `POOLRAD_DIR`:

```sh
export POOLRAD_DIR="/path/to/game"
obj/native/x86_64-linux/poolcfg
obj/native/x86_64-linux/poolrad
```

The native game looks for its data in `POOLRAD_DIR`, the current directory, and the executable's directory, in that order. A directory is recognized as a game directory when it contains `POOL.CFG` or `GEO1.DAX`.

## DOS build

### Read this before doing anything

The DOS compiler, assembler, packer, and `BUILD.BAT` must run **inside DOSBox or DOSBox-X**.

**DO NOT RUN THE DOS BUILD TOOLS IN NATIVE WINDOWS.**

Really. **Do not run them in Windows.** Old Turbo Pascal setup programs and executables are DOS applications. A modern Windows command prompt or PowerShell window is not DOS, even when the prompt looks familiar. Start DOSBox or DOSBox-X first, mount a working directory as its `C:` drive, and perform the installation and build there.

This warning does not prohibit using a Windows computer. DOSBox may run on Windows, and its mounted directory may live on a Windows disk. It is the DOS applications themselves that must execute inside the emulated DOS environment.

The proprietary compiler, assembler, and packer are not included in this repository. You must supply legitimate copies.

### Choose the correct Turbo Pascal version

| Source being built | Required compiler |
| --- | --- |
| Pool of Radiance v1.1 | Turbo Pascal 5.0 in `C:\TP50` |
| Pool of Radiance v1.2 | Turbo Pascal 5.0 in `C:\TP50` |
| Pool of Radiance v1.3 | Turbo Pascal 6.0 with the 1991 runtime library in `C:\TP6-1991` |
| Any Brazen Crows release or current source | Turbo Pascal 6.0 with the 1991 runtime library in `C:\TP6-1991` |

The runtime-library detail matters. A different `TURBO.TPL` can change the resulting program or prevent a historical reconstruction from matching.

For every version, install Turbo Assembler in `C:\TASM`. Install Microsoft EXEPACK 4.05 or 4.06 in `C:\EXEPACK`. Perform all three installations from inside DOSBox or DOSBox-X.

### Manual, all-inside-DOSBox workflow

This is the most literal DOS build and the easiest one to understand.

1. Create a host directory that will act as the emulated DOS `C:` drive. The exact host path is up to you. Mount it in DOSBox or DOSBox-X. For example, on Linux:

   ```text
   MOUNT C /home/you/por-dos
   C:
   ```

   On a Windows host, the first argument is still the DOS drive and the second is a host directory, for example:

   ```text
   MOUNT C C:\POR-DOS
   C:
   ```

2. While running inside DOSBox, install the required Turbo Pascal version into `C:\TP50` or `C:\TP6-1991`, according to the table above.

3. Still inside DOSBox, install TASM into `C:\TASM`.

4. Still inside DOSBox, install EXEPACK 4.05 or 4.06 into `C:\EXEPACK`.

5. Create `C:\POR-SRC`. Copy everything inside this repository's `src` directory into it, including every subdirectory. The result should contain files such as these:

   ```text
   C:\POR-SRC\FIXMAIN.PAS
   C:\POR-SRC\TPC.CFG
   C:\POR-SRC\INCLUDES\...
   C:\POR-SRC\NATIVE\...
   C:\POR-SRC\BINARIES\...
   ```

6. Copy the repository's [`scripts/BUILD.BAT`](../scripts/BUILD.BAT) into `C:\POR-SRC`.

7. In DOSBox, build from that directory:

   ```text
   C:
   CD \POR-SRC
   BUILD.BAT
   ```

   If both supported compilers are installed, name the one to use explicitly:

   ```text
   BUILD.BAT TP50
   ```

   or:

   ```text
   BUILD.BAT TP6-1991
   ```

8. A successful build writes its results to `C:\POR-SRC\OBJ`:

   ```text
   START.EXE
   GAME.OVR
   POOLCFG.EXE    (Brazen Crows sources only)
   ```

   Compiler, assembler, and packer logs are written to `C:\POR-SRC\LOGS`. If the batch file reports a failure, begin with the log it names.

9. Back up the retail game's `START.EXE`, `GAME.OVR`, saved games, and characters. Copy the new `START.EXE`, `GAME.OVR`, and, when present, `POOLCFG.EXE` into the game directory. For a current Brazen Crows build, also copy the files from `C:\POR-SRC\BINARIES`.

Historical v1.1, v1.2, and v1.3 source is available through the matching Git tag. Check out or export the desired tag before copying the contents of `src`. The standalone `scripts/BUILD.BAT` was added after those historical tags, so save a copy before switching tags or retrieve it from the current branch afterward. It knows that TP 5.0 builds use the historical rename step while TP 6.0 builds use EXEPACK.

### Automated DOSBox-X workflow

The repository also has a host-side driver for repeat builds and tests. The driver itself runs in the host shell, but it launches TPC, TASM, EXEPACK, and all DOS tests inside DOSBox-X. It does not run those DOS programs as native Windows applications.

This workflow requires:

- DOSBox-X 2025.02.01 or later on the host `PATH`.
- GNU `timeout` and `flock` on the host.
- The selected compiler in `drive_c/TP50` or `drive_c/TP6-1991`.
- TASM in `drive_c/TASM`.
- EXEPACK in `drive_c/EXEPACK`.

`build/toolchain` selects the compiler directory. Current source selects `TP6-1991`; the old version tags select the toolchain appropriate to them.

Build the game with:

```sh
scripts/build.sh
```

The results are written to the repository's `obj` directory. Logs go to `build/logs`.

Build and run the DOS unit tests with:

```sh
scripts/build.sh --test
```

To install directly into `drive_c/POOLRAD`, first put a backed-up retail installation there, then run:

```sh
scripts/build.sh --install
```

`--install` replaces `START.EXE` and `GAME.OVR` in that directory, so do not use it as your first backup step.

## Troubleshooting

### The native build cannot find Free Pascal or SDL

Run both setup scripts again and read the first reported missing command or package:

```sh
scripts/fpc-setup.sh
scripts/sdl3-setup.sh
```

If you set `FPC_PREFIX`, it must have the same value during setup and compilation.

### The native compiler reports an error

The main compiler logs are:

```text
obj/native/<target>/FPC.OUT
obj/native/<target>/POOLCFG.OUT
```

Test compiler logs and `TEST.LOG` are below `obj/native/<target>/tests`.

### Windows says SDL3.dll is missing or invalid

Put the target's own `SDL3.dll` beside `poolrad.exe`. A 32-bit DLL cannot be used with the 64-bit program, or the other way around.

### The game starts but cannot find its data

The built executable is not a complete copy of the game. Put it beside the files from your purchased installation, or set `POOLRAD_DIR` for a native build. In particular, `GEO1.DAX` should be present in the selected game-data directory.

### The DOS build fails immediately

Confirm that you are inside DOSBox or DOSBox-X, in `C:\POR-SRC`, and that these files exist:

```text
C:\TP50\TPC.EXE             (v1.1 or v1.2)
C:\TP6-1991\TPC.EXE         (v1.3 or Brazen Crows)
C:\TASM\TASM.EXE
C:\EXEPACK\EXEPACK.EXE
C:\POR-SRC\FIXMAIN.PAS
C:\POR-SRC\TPC.CFG
C:\POR-SRC\BUILD.BAT
```

Then read the corresponding file in `C:\POR-SRC\LOGS`.
