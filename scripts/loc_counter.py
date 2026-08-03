import os
from pathlib import Path


def count_lines(directory="."):
    # Target extensions based on Digidaw's stack
    extensions = {
        '.rs': 'Rust',
        '.dart': 'Dart',
        '.c': 'C',
        '.cpp': 'C++',
        '.h': 'Header',
        '.hpp': 'C++ Header',
        '.sh': 'Shell',
        '.py': 'Python',
        '.yaml': 'YAML',
        '.toml': 'TOML'
    }
    
    # Ignore generated, third-party, and platform-specific build folders
    ignore_dirs = {
        'target', 
        'build', 
        '.git', 
        '.dart_tool', 
        'dist', 
        'rubberband_src', # Ignore the cloned C++ library
        'android',        # Flutter platform dirs (mostly auto-generated)
        'ios', 
        'windows', 
        'macos', 
        'linux' 
    }

    total_files = 0
    total_lines = 0
    blank_lines = 0
    lang_breakdown = {ext: 0 for ext in extensions}

    for root, dirs, files in os.walk(directory):
        # Modify dirs in-place to skip the ignored directories
        dirs[:] = [d for d in dirs if d not in ignore_dirs]

        for file in files:
            ext = Path(file).suffix
            if ext in extensions:
                file_path = os.path.join(root, file)
                
                try:
                    with open(file_path, 'r', encoding='utf-8') as f:
                        lines_in_file = 0
                        for line in f:
                            lines_in_file += 1
                            if not line.strip():
                                blank_lines += 1
                        
                        lang_breakdown[ext] += lines_in_file
                        total_lines += lines_in_file
                        total_files += 1
                except UnicodeDecodeError:
                    # Skip files that fail UTF-8 decoding (e.g., binaries accidentally matching an extension)
                    continue

    # Print the results
    print("=" * 40)
    print(" 📊 Digidaw Codebase Statistics")
    print("=" * 40)
    print(f"Total Files Analyzed:  **{total_files}**")
    print(f"Total Lines of Code:   **{total_lines}**")
    print(f"Actual Code (No blank):**{total_lines - blank_lines}**")
    print("-" * 40)
    print(" Breakdown by Language:")
    
    # Sort the breakdown by line count (highest to lowest)
    sorted_breakdown = sorted(lang_breakdown.items(), key=lambda item: item[1], reverse=True)
    
    for ext, count in sorted_breakdown:
        if count > 0:
            lang_name = extensions[ext]
            print(f"  {lang_name.ljust(12)} ({ext.ljust(5)}): {count:,} lines")
    print("=" * 40)

if __name__ == "__main__":
    count_lines()