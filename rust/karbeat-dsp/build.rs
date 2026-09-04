#![allow(
    clippy::unwrap_used,
    clippy::expect_used,
    reason = "missing build dependencies must fail the build with a direct diagnostic"
)]

use std::env;
use std::path::PathBuf;

fn main() {
    let target_os = env::var("CARGO_CFG_TARGET_OS").expect("CARGO_CFG_TARGET_OS not set");
    let mut header_path: Option<PathBuf> = None;

    if target_os == "windows" {
        let manifest_dir = std::env::var("CARGO_MANIFEST_DIR").unwrap();
        let vcpkg_env = format!("{}\\..\\vcpkg_installed\\x64-windows", manifest_dir);

        // Tell Cargo where the .lib is
        println!("cargo:rustc-link-search=native={}\\lib", vcpkg_env);
        println!("cargo:rustc-link-lib=rubberband");
        header_path = Some(PathBuf::from(format!(
            "{}\\include\\rubberband\\rubberband-c.h",
            vcpkg_env
        )));
    } else if target_os == "linux" || target_os == "macos" {
        let lib = pkg_config::Config::new()
            .probe("rubberband")
            .expect("Failed to find rubberband via pkg-config!");

        if let Some(include_dir) = lib.include_paths.first() {
            header_path = Some(include_dir.join("rubberband").join("rubberband-c.h"));
        }
    } else if target_os == "android" {
        // Android: Manual linking to the JNI libs folder
        let manifest_dir = env::var("CARGO_MANIFEST_DIR").unwrap();
        println!(
            "cargo:rustc-link-search=native={}/../android/app/src/main/jniLibs/arm64-v8a",
            manifest_dir
        );

        // Only manually link for Android. vcpkg and pkg-config do this automatically for desktop!
        println!("cargo:rustc-link-lib=rubberband");

        // Note: Cross-compiling for Android usually means the system headers aren't available locally.
        // If you need bindgen on Android, you will need to download the header and hardcode a fallback path here.
    }

    // Generate Bindings & Documentation
    if let Some(header) = header_path {
        if header.exists() {
            println!("cargo:rerun-if-changed={}", header.display());

            let bindings = bindgen::Builder::default()
                .header(header.to_string_lossy())
                .generate_comments(true)
                .clang_arg("-fretain-comments-from-system-headers")
                .clang_arg("-fparse-all-comments")
                .parse_callbacks(Box::new(bindgen::CargoCallbacks::new()))
                .generate()
                .expect("Unable to generate bindings");

            let out_path = PathBuf::from(env::var("OUT_DIR").unwrap());
            bindings
                .write_to_file(out_path.join("rubberband_bindings.rs"))
                .expect("Couldn't write bindings!");
        } else {
            println!(
                "cargo:warning=Rubberband header not found at {}, skipping bindgen.",
                header.display()
            );
        }
    }
}
