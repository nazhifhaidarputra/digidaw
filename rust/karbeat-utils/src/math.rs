use num_traits::Float;

/// Function that returns ```true``` if the input number is a positive to-the-power-of-2 number
///
#[inline(always)]
pub fn is_power_of_two(n: u64) -> bool {
    return n > 0 && (n & (n - 1)) == 0;
}

/// Extremely fast 4-point, 3rd-order Hermite interpolation.
/// Optimized for Fused Multiply-Add (FMA) instructions.
#[inline(always)]
#[allow(clippy::unwrap_used)]
pub fn hermite_interp<T>(frac: T, p0: T, p1: T, p2: T, p3: T) -> T
where
    T: Float,
{
    let half: T = T::from(0.5).unwrap();
    let two: T = T::from(2.0).unwrap();
    let two_half: T = T::from(2.5).unwrap();
    let one_half: T = T::from(1.5).unwrap(); 

    let c1: T = half * (p2 - p0);
    let c2: T = p0 - two_half * p1 + two * p2 - half * p3;
    let c3: T = half * (p3 - p0) + one_half * (p1 - p2);

    // Horner's method for polynomial evaluation
    ((c3 * frac + c2) * frac + c1) * frac + p1
}
