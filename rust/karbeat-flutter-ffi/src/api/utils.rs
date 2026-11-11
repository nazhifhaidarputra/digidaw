use flutter_rust_bridge::frb;
use karbeat_utils::hash::hash_str;

/// Helper function to acquire u32 ID from string
/// using FNV1a hash functions
#[frb(sync)]
pub const fn hash_str_fnv1a(s: &str) -> u32 {
    hash_str(s)
}
