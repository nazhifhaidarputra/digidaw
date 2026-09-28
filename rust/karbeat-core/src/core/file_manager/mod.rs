/// Audio decoding, resampling, caching, and waveform construction.
pub mod audio_loader;
/// Safe ownership wrapper for memory-mapped audio data.
pub mod memmap;
/// Project archive loading, migration, and extraction.
pub mod project_loader;

/// Returns the per-user application cache directory on disk, e.g. `~/.cache/digidaw` on Linux.
///
/// Large session files live here rather than in the temporary directory, which is often
/// RAM-backed tmpfs on Linux.
pub fn app_cache_dir() -> Option<std::path::PathBuf> {
    use std::path::PathBuf;
    let base = if cfg!(target_os = "windows") {
        std::env::var_os("LOCALAPPDATA").map(PathBuf::from)
    } else if cfg!(target_os = "macos") {
        std::env::var_os("HOME").map(|home| PathBuf::from(home).join("Library/Caches"))
    } else {
        std::env::var_os("XDG_CACHE_HOME")
            .filter(|value| !value.is_empty())
            .map(PathBuf::from)
            .or_else(|| std::env::var_os("HOME").map(|home| PathBuf::from(home).join(".cache")))
    }?;
    Some(base.join("digidaw"))
}
