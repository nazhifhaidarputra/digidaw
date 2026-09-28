/// Timing constants in `f32` and `f64` forms.
pub mod constants;
/// Shared target enums used across project APIs.
pub mod enums;
/// Generation-aware slot-map key types and wire conversions.
pub mod id;
/// Bounded scalar newtypes used by project models.
pub mod types;

pub use id::*;
