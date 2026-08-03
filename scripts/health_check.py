import os
import sys
import shutil
import subprocess

# --- Terminal Colors ---
class Colors:
    GREEN = '\033[92m'
    RED = '\033[91m'
    YELLOW = '\033[93m'
    CYAN = '\033[96m'
    RESET = '\033[0m'

def print_status(name, status, details=""):
    if status == "PASS":
        print(f"[{Colors.GREEN}✓{Colors.RESET}] {name.ljust(25)} {details}")
    elif status == "WARN":
        print(f"[{Colors.YELLOW}!{Colors.RESET}] {name.ljust(25)} {Colors.YELLOW}{details}{Colors.RESET}")
    else:
        print(f"[{Colors.RED}✗{Colors.RESET}] {name.ljust(25)} {Colors.RED}{details}{Colors.RESET}")

def check_cli_tool(command_name, display_name=None):
    """Checks if a CLI tool is available in the system PATH."""
    display_name = display_name or command_name
    path = shutil.which(command_name)
    if path:
        print_status(display_name, "PASS", f"Found at {path}")
        return True
    else:
        print_status(display_name, "FAIL", "Not found in PATH")
        return False

def check_pkg_config(lib_name, display_name=None):
    """Uses pkg-config to check if a C/C++ library is installed and linked to the OS."""
    display_name = display_name or lib_name
    if not shutil.which("pkg-config"):
        print_status(display_name, "FAIL", "Cannot check (pkg-config is missing)")
        return False
    
    try:
        # Check if it exists and grab the version
        result = subprocess.run(
            ['pkg-config', '--modversion', lib_name], 
            stdout=subprocess.PIPE, 
            stderr=subprocess.PIPE, 
            text=True
        )
        if result.returncode == 0:
            version = result.stdout.strip()
            print_status(display_name, "PASS", f"Version {version} installed")
            return True
        else:
            print_status(display_name, "FAIL", "Library not found by pkg-config")
            return False
    except Exception as e:
        print_status(display_name, "FAIL", str(e))
        return False

def check_env_var(var_name):
    """Checks if an environment variable is set."""
    val = os.environ.get(var_name)
    if val:
        print_status(var_name, "PASS", f"Set to {val}")
        return True
    else:
        print_status(var_name, "WARN", "Environment variable not set")
        return False

def main():
    print(f"\n{Colors.CYAN}==> Digidaw System Health Check <=={Colors.RESET}\n")
    
    all_passed = True
    
    # 1. Core Build Tools
    print(f"{Colors.CYAN}--- Core Toolchain ---{Colors.RESET}")
    tools = ['flutter', 'cargo', 'rustup', 'cmake', 'ninja', 'clang', 'pkg-config']
    for tool in tools:
        if not check_cli_tool(tool):
            all_passed = False

    # Check FRB specifically
    if not check_cli_tool('flutter_rust_bridge_codegen', 'FRB Codegen'):
        print(f"    {Colors.YELLOW}Run: cargo install flutter_rust_bridge_codegen{Colors.RESET}")
        all_passed = False

    # 2. Third-Party C/C++ Dependencies (The crucial part)
    print(f"\n{Colors.CYAN}--- External C/C++ Libraries ---{Colors.RESET}")
    # ADD NEW DEPENDENCIES HERE IN THE FUTURE
    libraries = [
        ('rubberband', 'Rubber Band Library'),
    ]
    
    if sys.platform.startswith('linux'):
        # Linux-specific audio backends
        libraries.extend([
            ('jack', 'JACK Audio'),
            ('alsa', 'ALSA')
        ])

    for lib_name, display_name in libraries:
        if not check_pkg_config(lib_name, display_name):
            all_passed = False

    # 3. Android Cross-Compilation Environment
    print(f"\n{Colors.CYAN}--- Android Environment ---{Colors.RESET}")
    has_android_home = check_env_var('ANDROID_HOME')
    has_android_sdk = check_env_var('ANDROID_SDK_ROOT')
    
    if not (has_android_home or has_android_sdk):
        print(f"    {Colors.YELLOW}Warning: Android cross-compilation will fail. Set ANDROID_HOME.{Colors.RESET}")
        # Not strictly failing the whole script if they are just building desktop, 
        # but you can toggle all_passed = False here if Android is mandatory.

    print("\n" + "="*45)
    if all_passed:
        print(f"{Colors.GREEN}SUCCESS: System is fully ready to build Digidaw!{Colors.RESET}")
        sys.exit(0)
    else:
        print(f"{Colors.RED}FAILURE: Missing dependencies detected. Please install them before building.{Colors.RESET}")
        sys.exit(1)

if __name__ == "__main__":
    main()