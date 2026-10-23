//! Compiles the vendored, header-only Signalsmith Stretch behind the C ABI in `src/shim.cpp`,
//! and generates the Rust bindings for that ABI from `src/shim.h`.

#![allow(
    clippy::expect_used,
    reason = "a failed build step must stop the build with a direct diagnostic"
)]

use std::{env, path::PathBuf};

fn main() {
    println!("cargo:rerun-if-changed=src/shim.h");
    println!("cargo:rerun-if-changed=src/shim.cpp");
    println!("cargo:rerun-if-changed=vendor");

    let mut build = cc::Build::new();
    build
        .cpp(true)
        .std("c++14")
        .include("vendor")
        .file("src/shim.cpp")
        .warnings(false);
    if env::var("CARGO_CFG_TARGET_ENV").as_deref() == Ok("msvc") {
        // The FFT templates exceed MSVC's default section count.
        build.flag("/bigobj");
    }
    build.compile("karbeat_signalsmith");

    let bindings = bindgen::Builder::default()
        .header("src/shim.h")
        .allowlist_function("karbeat_stretch_.*")
        .allowlist_type("KarbeatStretch")
        .generate_comments(true)
        .parse_callbacks(Box::new(bindgen::CargoCallbacks::new()))
        .generate()
        .expect("Unable to generate the Signalsmith shim bindings");
    let out_path = PathBuf::from(env::var("OUT_DIR").expect("OUT_DIR not set"));
    bindings
        .write_to_file(out_path.join("signalsmith_bindings.rs"))
        .expect("Couldn't write the Signalsmith shim bindings");
}
