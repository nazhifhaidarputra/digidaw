#!/usr/bin/env python3
import os
import subprocess
import sys

IS_WINDOWS = os.name == 'nt'

def main():
    # 1. Resolve absolute paths dynamically
    # This ensures the script works no matter where you call it from in the terminal
    script_dir = os.path.dirname(os.path.abspath(__file__))
    project_root = os.path.dirname(script_dir)
    rust_dir = os.path.join(project_root, 'rust')
    
    # Define the absolute path to the manifest output directory
    # Keep the Rust exporter and Dart generator on the same canonical manifest
    # directory. The previous singular path left newly exported plugins out of
    # generated Dart specs.
    manifest_dir = os.path.join(project_root, 'assets', 'manifests', 'audio-plugins')
    
    # Ensure the target directory exists before Rust tries to write to it
    os.makedirs(manifest_dir, exist_ok=True)
    
    print("🚀 Starting Plugin Generation Pipeline...\n")

    # Inject the environment variable into a copy of the current environment
    env = os.environ.copy()
    env['PLUGIN_MANIFEST_DIR'] = manifest_dir

    # 2. Step 1: Run Rust Exporter
    print(f"⚙️  [1/2] Running Rust export_manifest in {rust_dir}...")
    try:
        rust_process = subprocess.run(
            ['cargo', 'run', '--bin', 'export_manifest'],
            cwd=rust_dir,
            env=env,
            check=True, # Raises CalledProcessError on non-zero exit
            shell=IS_WINDOWS
        )
    except subprocess.CalledProcessError as e:
        print(f"\n❌ Rust export failed with exit code {e.returncode}. Aborting pipeline.")
        sys.exit(e.returncode)
    except FileNotFoundError:
        print("\n❌ Error: 'cargo' command not found. Ensure Rust is installed and in your PATH.")
        sys.exit(1)

    print("\n✅ Rust export successful.\n")

    # 3. Step 2: Run Dart Generator
    # Using the exact path you specified relative to the project root
    dart_script = os.path.join('lib', 'tool', 'generate_plugin_manifests.dart')
    print(f"🎯 [2/2] Running Dart generator: {dart_script}...")
    
    try:
        dart_process = subprocess.run(
            ['dart', 'run', dart_script],
            cwd=project_root,
            check=True,
            shell=IS_WINDOWS
        )
    except subprocess.CalledProcessError as e:
        print(f"\n❌ Dart generation failed with exit code {e.returncode}.")
        sys.exit(e.returncode)
    except FileNotFoundError:
        print("\n❌ Error: 'dart' command not found. Ensure the Flutter/Dart SDK is in your PATH.")
        sys.exit(1)

    print("\n🎉 Pipeline completed successfully!")

if __name__ == "__main__":
    main()
