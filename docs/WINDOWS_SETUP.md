# Windows Development Setup (DSP & Audio)

Developing the audio engine on Windows requires compiling native C++ DSP libraries (like Rubber Band) and linking them to Rust and Flutter. Because Windows does not have a native package manager like Linux, we use Microsoft's **vcpkg** in **Manifest Mode** (a local virtual environment) to handle this.

If you skip these steps, the Flutter app will crash on startup with a generic `Failed to load dynamic library` error due to missing `.dll` files.

## 1. Prerequisites

Before you begin, ensure you have the following installed:
1. **Visual Studio Build Tools**: You MUST install the "Desktop development with C++" workload. (Rust and vcpkg need the MSVC compiler).
2. **Rust & Cargo**: Standard installation via `rustup`.
3. **Flutter**: Configured for Windows desktop development.
4. **Git**: Required for vcpkg to fetch packages.

## 2. Install vcpkg (One-time machine setup)

You need the `vcpkg` executable on your machine to build the C++ libraries. We recommend installing it at the root of your `C:\` drive to avoid Windows long-path limitations.

Open PowerShell or Command Prompt and run:
```cmd
cd C:\
git clone [https://github.com/microsoft/vcpkg.git](https://github.com/microsoft/vcpkg.git)
cd vcpkg
.\bootstrap-vcpkg.bat

```

*(Optional but recommended: Add `C:\vcpkg` to your Windows System `PATH` variable).*

## 3. Build the Local C++ Environment

We do **not** install C++ libraries globally. Instead, we use a `vcpkg.json` manifest file to create an isolated local environment for this project.

1. Open a terminal and navigate to the `rust/` folder in this repository:
```cmd
cd path\to\digidaw\rust

```


2. Run the install command, forcing the dynamic Windows triplet:
```cmd
C:\vcpkg\vcpkg.exe install --triplet=x64-windows

```



**What this does:**
This will download, compile, and install Rubber Band (and its heavy math dependencies like FFTW3) directly into a new folder at `rust/vcpkg_installed/`. This folder is ignored by git.

## 4. Run the App

That's it! You can now run the app normally:

```cmd
flutter run -d windows

```

### 🧠 How the Architecture Works (For Maintainers)

If you are modifying the build system, here is how the pieces talk to each other:

1. **Rust Linking (`build.rs`)**:
The Rust build script automatically detects the `rust/vcpkg_installed/x64-windows/lib/` directory and links `rubberband.lib`. We explicitly bypass the standard `vcpkg` Rust crate because it conflicts with Rubber Band's naming conventions (`rubberband-3.dll`).
*(Note: The build script also automatically sets `VCPKGRS_DYNAMIC=1` so you don't have to configure your terminal).*
2. **DLL Hell Automation (`CMakeLists.txt`)**:
Windows requires runtime dependencies (like `rubberband-3.dll` and `fftw3f.dll`) to sit exactly next to the generated `.exe`. To automate this, `windows/runner/CMakeLists.txt` contains a custom `POST_BUILD` command. Every time you run the Flutter app, CMake seamlessly copies all required `.dll` files from `rust/vcpkg_installed/x64-windows/bin/` into the final Flutter `Debug/` or `Release/` folder.