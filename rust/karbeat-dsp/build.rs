fn main() {
    if std::env::var("CARGO_CFG_TARGET_OS").unwrap() == "android" {
        let manifest_dir = std::env::var("CARGO_MANIFEST_DIR").unwrap();
        println!("cargo:rustc-link-search=native={}/../android/app/src/main/jniLibs/arm64-v8a", manifest_dir);
    }
    println!("cargo:rustc-link-lib=rubberband");
}
