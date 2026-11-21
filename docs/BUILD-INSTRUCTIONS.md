# FIELDLEDGER Build & Release Instructions

## 1. Compiler Requirements

FIELDLEDGER is implemented in modern, free-format COBOL (`>>SOURCE FORMAT FREE`) and verified on:

- **Compiler:** `cobc (GnuCOBOL) 3.2.0`
- **C Backend (tested on Windows):** MinGW-w64 UCRT64 GCC (`x86_64-w64-mingw32`, GMP math library, BDB, json-c, libxml2)
- **Compiler Flags:** `-free -Wall -O2 -I copybooks`

Official GnuCOBOL documentation:
- https://gnucobol.sourceforge.io/
- https://gnucobol.sourceforge.io/documentation.html

---

## 2. Installing GnuCOBOL

### Windows (MSYS2 UCRT64 — Verified)

1. Install MSYS2 from https://www.msys2.org/ into `C:\msys64`.
2. Open the MSYS2 shell and install the UCRT64 GCC toolchain and GnuCOBOL:
   ```sh
   pacman -Sy --noconfirm mingw-w64-ucrt-x86_64-gcc mingw-w64-ucrt-x86_64-gnucobol
   ```
3. Note on native PowerShell execution: MSYS2's `cobc.exe` embeds `/ucrt64/...` default paths. `scripts/build.ps1` automatically detects `C:\msys64\ucrt64` and sets `COB_CONFIG_DIR`, `COB_COPY_DIR`, `COB_CFLAGS`, and `COB_LIBS` for native PowerShell builds without requiring MSYS2 bash.

### Linux (Debian / Ubuntu)

```sh
sudo apt-get update && sudo apt-get install -y gnucobol gcc
```

### Linux (Fedora / RHEL)

```sh
sudo dnf install -y gnucobol gcc
```

### macOS (Homebrew)

```sh
brew install gnucobol
```

---

## 3. Building FIELDLEDGER

### Windows (PowerShell)

```powershell
.\scripts\build.ps1
# Or clean rebuild:
.\scripts\build.ps1 -Clean
```

Outputs:
- `build\fieldledger.exe`
- Object files in `build\obj\*.o`
- Required MinGW runtime DLLs staged alongside `build\fieldledger.exe` (`libcob-4.dll`, `libgmp-10.dll`, `libdb-6.2.dll`, `libintl-8.dll`, `libjson-c-5.dll`, `libncursesw6.dll`, `libwinpthread-1.dll`, `libxml2-16.dll`, `libiconv-2.dll`, `zlib1.dll`) so `.\build\fieldledger.exe` runs cleanly from any PowerShell terminal without modifying system `PATH`.

### Linux / macOS (POSIX sh)

```sh
chmod +x scripts/*.sh
./scripts/build.sh
# Or clean rebuild:
./scripts/build.sh --clean
```

Outputs:
- `build/fieldledger`

---

## 4. Offline Usage & Release Packaging

FIELDLEDGER requires **no internet connection** at runtime. To package a portable release directory on Windows:

1. Run `.\scripts\build.ps1 -Clean` and `.\scripts\test.ps1`.
2. Archive the following together so `fieldledger.exe` can resolve `scripts/manifest.ps1` and `scripts/verify.ps1` relative to its parent directory:
   - `build\fieldledger.exe` and staged `build\*.dll`
   - `scripts\manifest.ps1`, `scripts\verify.ps1`, `scripts\manifest.sh`, `scripts\verify.sh`
   - `examples\wetland-demo\`
   - `docs\`, `README.md`, `LICENSE`, `CHANGELOG.md`

On Linux/macOS, bundle `build/fieldledger` alongside `scripts/manifest.sh`, `scripts/verify.sh`, `examples/`, and `docs/`.
