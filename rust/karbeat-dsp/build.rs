fn main() {
    // Link the system-installed rubberband library.
    // Requires the `rubberband-devel` (Fedora) / `librubberband-dev` (Debian) package.
    println!("cargo:rustc-link-lib=rubberband");

    // Tell Cargo to re-run this script only if Cargo.toml changes.
    println!("cargo:rerun-if-changed=build.rs");
}
