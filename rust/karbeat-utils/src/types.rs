use serde::{Deserialize, Serialize};
use std::ops::Deref;

// ============================================================================
// SHARED TRAIT: the one piece of clamping logic every bounded type needs.
// Implemented once per primitive; the macros below never re-implement it.
// ============================================================================

pub trait BoundedNum: Copy + PartialOrd + PartialEq + std::fmt::Debug {
    fn clamp_to(self, min: Self, max: Self) -> Self;
}

macro_rules! impl_bounded_num {
    ($($t:ty),* $(,)?) => {
        $(
            impl BoundedNum for $t {
                #[inline]
                fn clamp_to(self, min: Self, max: Self) -> Self {
                    if self < min { min } else if self > max { max } else { self }
                }
            }
        )*
    };
}

impl_bounded_num!(f32, f64, i8, i16, i32, i64, isize, u8, u16, u32, u64, usize);

// ============================================================================
// MACRO #1: fixed-bound wrapper -- bounds are compile-time constants.
// Generates the `NormalizedF32` / `BipolarF32` pattern for any inner type.
// ============================================================================

macro_rules! bounded_fixed {
// Float variant: Adds `from_range` and `to_range` interpolation methods
    (
        $(#[$meta:meta])*
        $name:ident($inner:ty), min = $min:expr, max = $max:expr, default = $default:expr, float = true
    ) => {
        bounded_fixed!(@base $(#[$meta])* $name($inner), min = $min, max = $max, default = $default);

        impl $name {
            /// Generates this bounded newtype from a raw value mapped from an arbitrary `[range_min, range_max]` range.
            pub fn from_range(raw_value: $inner, range_min: $inner, range_max: $inner) -> Self {
                let range = range_max - range_min;
                if range.abs() < <$inner>::EPSILON {
                    Self::default()
                } else {
                    let t = (raw_value - range_min) / range;
                    let mapped = Self::MIN + t * (Self::MAX - Self::MIN);
                    Self::new(mapped)
                }
            }

            /// Maps this bounded value into an arbitrary `[range_min, range_max]` range.
            pub fn to_range(self, range_min: $inner, range_max: $inner) -> $inner {
                let t = (self.0 - Self::MIN) / (Self::MAX - Self::MIN);
                range_min + t * (range_max - range_min)
            }
        }
    };

    // Standard variant: Excludes range math (useful if you ever generate bounded ints here)
    (
        $(#[$meta:meta])*
        $name:ident($inner:ty), min = $min:expr, max = $max:expr, default = $default:expr
    ) => {
        bounded_fixed!(@base $(#[$meta])* $name($inner), min = $min, max = $max, default = $default);
    };

    // Shared internal implementation for constructors, traits, and deref
    (@base
        $(#[$meta:meta])*
        $name:ident($inner:ty), min = $min:expr, max = $max:expr, default = $default:expr
    ) => {
        $(#[$meta])*
        #[derive(Debug, Clone, Copy, PartialEq, PartialOrd, Serialize, Deserialize)]
        #[serde(transparent)]
        pub struct $name($inner);

        impl $name {
            /// Lower bound (inclusive).
            pub const MIN: $inner = $min;
            /// Upper bound (inclusive).
            pub const MAX: $inner = $max;

            /// Creates a new value, clamping the input to `MIN..=MAX`.
            pub fn new(value: $inner) -> Self {
                Self(BoundedNum::clamp_to(value, Self::MIN, Self::MAX))
            }

            /// Creates a new value without clamping.
            ///
            /// # Safety
            /// The caller must guarantee `value` lies within `MIN..=MAX`.
            pub const unsafe fn new_unchecked(value: $inner) -> Self {
                Self(value)
            }

            /// Returns the inner value.
            pub fn get(self) -> $inner {
                self.0
            }
        }

        impl TryFrom<$inner> for $name {
            type Error = &'static str;

            fn try_from(value: $inner) -> Result<Self, Self::Error> {
                if value >= Self::MIN && value <= Self::MAX {
                    Ok(unsafe { Self::new_unchecked(value) })
                } else {
                    Err(concat!("Value is out of bounds for ", stringify!($name)))
                }
            }
        }

        impl Default for $name {
            fn default() -> Self {
                Self($default)
            }
        }

        impl Deref for $name {
            type Target = $inner;
            fn deref(&self) -> &Self::Target {
                &self.0
            }
        }
    };
}

// ---- types generated from macro #1 ----------------------------------------

bounded_fixed!(
    /// A floating point value strictly bounded between 0.0 and 1.0.
    NormalizedF32(f32), min = 0.0, max = 1.0, default = 0.0, float = true
);

bounded_fixed!(
    /// A floating point value strictly bounded between -1.0 and 1.0.
    BipolarF32(f32), min = -1.0, max = 1.0, default = 0.0, float = true
);

bounded_fixed!(
    /// A double precision value strictly bounded between 0.0 and 1.0.
    NormalizedF64(f64), min = 0.0, max = 1.0, default = 0.0, float = true
);

bounded_fixed!(
    /// A double precision value strictly bounded between -1.0 and 1.0.
    BipolarF64(f64), min = -1.0, max = 1.0, default = 0.0, float = true
);

// ============================================================================
// MACRO #2: dynamic-bound wrapper -- min/max are chosen at runtime.
// Generates the `BoundedF32` pattern for any inner type.
// ============================================================================

macro_rules! bounded_dynamic {
    // Variant with a `normalize_to` clause: adds `as_normalized` and `from_normalized`.
    (
        $(#[$meta:meta])*
        $name:ident($inner:ty), normalize_to = $norm:ty
    ) => {
        bounded_dynamic!(@base $(#[$meta])* $name($inner));

        impl $name {
            /// Generates a dynamic bounded newtype from a normalized value and the desired bounds.
            pub fn from_normalized(norm: $norm, min: $inner, max: $inner) -> Self {
                let range = max - min;
                let mapped = min + norm.get() * range;
                Self::new(mapped, min, max)
            }

            /// Returns how far along the value is between `min` and `max` (0.0 to 1.0).
            pub fn as_normalized(&self) -> $norm {
                let range = self.max - self.min;
                if range.abs() < <$inner>::EPSILON {
                    <$norm>::new(0.0)
                } else {
                    <$norm>::new((self.value - self.min) / range)
                }
            }
        }
    };

    // Plain variant: works for any `BoundedNum`, including integers.
    (
        $(#[$meta:meta])*
        $name:ident($inner:ty)
    ) => {
        bounded_dynamic!(@base $(#[$meta])* $name($inner));
    };

    // Shared base
    (@base $(#[$meta:meta])* $name:ident($inner:ty)) => {
        $(#[$meta])*
        #[derive(Debug, Clone, Copy, PartialEq, PartialOrd, Serialize, Deserialize)]
        pub struct $name {
            value: $inner,
            min: $inner,
            max: $inner,
        }

        impl $name {
            /// Creates a new value, clamping `value` between `min` and `max`.
            ///
            /// Panics if `min > max`.
            pub fn new(value: $inner, min: $inner, max: $inner) -> Self {
                assert!(min <= max, "min must be less than or equal to max");
                Self {
                    value: BoundedNum::clamp_to(value, min, max),
                    min,
                    max,
                }
            }

            /// Updates the value, strictly clamping it to the existing bounds.
            pub fn set(&mut self, value: $inner) {
                self.value = BoundedNum::clamp_to(value, self.min, self.max);
            }

            pub fn get(&self) -> $inner {
                self.value
            }

            pub fn min(&self) -> $inner {
                self.min
            }

            pub fn max(&self) -> $inner {
                self.max
            }
        }
    };
}

// ---- types generated from macro #2 -----------------------------------------

bounded_dynamic!(
    /// A floating point value strictly bounded between an arbitrary `min` and `max`.
    BoundedF32(f32), normalize_to = NormalizedF32
);

bounded_dynamic!(
    /// A double precision value strictly bounded between an arbitrary `min` and `max`.
    BoundedF64(f64), normalize_to = NormalizedF64
);

// Integers skip `normalize_to` (division semantics differ) but still get
// the full new/set/get/min/max API for free:
bounded_dynamic!(
    /// An i32 value strictly bounded between an arbitrary `min` and `max`.
    BoundedI32(i32)
);

// ============================================================================
// Sanity checks
// ============================================================================
#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn from_range_works() {
        // 50 mapped from [0, 100] to Normalized bounds [0.0, 1.0] -> 0.5
        let n = NormalizedF32::from_range(50.0, 0.0, 100.0);
        assert_eq!(n.get(), 0.5);

        // 50 mapped from [0, 100] to Bipolar bounds [-1.0, 1.0] -> 0.0
        let b = BipolarF32::from_range(50.0, 0.0, 100.0);
        assert_eq!(b.get(), 0.0);
    }

    #[test]
    fn to_range_works() {
        let n = NormalizedF32::new(0.75);
        assert_eq!(n.to_range(0.0, 100.0), 75.0);

        let b = BipolarF32::new(-0.5); // 25% across the -1.0 to 1.0 range
        assert_eq!(b.to_range(0.0, 100.0), 25.0);
    }

    #[test]
    fn dynamic_from_normalized_works() {
        let n = NormalizedF32::new(0.5);
        let dyn_val = BoundedF32::from_normalized(n, 20.0, 80.0);
        assert_eq!(dyn_val.get(), 50.0);
    }

    #[test]
    fn bounded_f32_normalizes() {
        let b = BoundedF32::new(75.0, 0.0, 100.0);
        assert_eq!(b.as_normalized().get(), 0.75);
    }
}
