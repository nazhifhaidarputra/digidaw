//! Control-port mapping between the host's normalized domain and LV2 plain values.
//!
//! The host addresses every external parameter as a normalized `[0, 1]` value. LV2 control ports
//! carry plain values with declared bounds, so each port keeps the mapping, its display text,
//! and the reverse parse here, free of lilv calls so the policy can be tested directly.

use karbeat_plugin_api::prelude::ParameterSpec;

/// Largest distance at which a plain value still counts as one of its port's scale points.
const SCALE_POINT_TOLERANCE: f32 = 1.0e-4;

/// One labelled value of a control port.
#[derive(Clone, Debug, PartialEq)]
pub(crate) struct ScalePoint {
    pub value: f32,
    pub label: String,
}

/// Declared bounds and value shape of one control port.
#[derive(Clone, Copy, Debug, PartialEq)]
pub(crate) struct ControlRange {
    pub minimum: f32,
    pub maximum: f32,
    pub default: f32,
    /// Exponential mapping; only kept when the lower bound is positive.
    pub logarithmic: bool,
    pub integer: bool,
    pub toggled: bool,
}

impl ControlRange {
    /// Builds a usable range from declared bounds, which plugins may omit or leave degenerate.
    pub fn new(
        minimum: Option<f32>,
        maximum: Option<f32>,
        default: Option<f32>,
        logarithmic: bool,
        integer: bool,
        toggled: bool,
    ) -> Self {
        let finite = |value: Option<f32>| value.filter(|value| value.is_finite());
        let mut minimum = finite(minimum).unwrap_or(0.0);
        let mut maximum = finite(maximum).unwrap_or(minimum.max(0.0) + 1.0);
        if maximum < minimum {
            std::mem::swap(&mut minimum, &mut maximum);
        }
        if maximum <= minimum {
            maximum = minimum + 1.0;
        }
        Self {
            minimum,
            maximum,
            default: finite(default).unwrap_or(minimum).clamp(minimum, maximum),
            logarithmic: logarithmic && minimum > 0.0,
            integer,
            toggled,
        }
    }

    /// Converts a normalized value to the port's plain domain.
    pub fn to_plain(self, normalized: f64) -> f32 {
        let normalized = if normalized.is_finite() {
            normalized.clamp(0.0, 1.0)
        } else {
            0.0
        };
        let (minimum, maximum) = (f64::from(self.minimum), f64::from(self.maximum));
        if self.toggled {
            return if normalized >= 0.5 {
                self.maximum
            } else {
                self.minimum
            };
        }
        let plain = if self.logarithmic {
            minimum * (maximum / minimum).powf(normalized)
        } else {
            minimum + normalized * (maximum - minimum)
        };
        let plain = if self.integer { plain.round() } else { plain };
        narrow(plain).clamp(self.minimum, self.maximum)
    }

    /// Converts a plain port value to the normalized `[0, 1]` domain.
    pub fn to_normalized(self, plain: f32) -> f64 {
        if !plain.is_finite() {
            return 0.0;
        }
        let plain = f64::from(plain.clamp(self.minimum, self.maximum));
        let (minimum, maximum) = (f64::from(self.minimum), f64::from(self.maximum));
        if self.toggled {
            return if plain > (minimum + maximum) * 0.5 {
                1.0
            } else {
                0.0
            };
        }
        let normalized = if self.logarithmic {
            (plain / minimum).ln() / (maximum / minimum).ln()
        } else {
            (plain - minimum) / (maximum - minimum)
        };
        if normalized.is_finite() {
            normalized.clamp(0.0, 1.0)
        } else {
            0.0
        }
    }

    /// Normalized distance between adjacent values, or zero for a continuous port.
    pub fn step(self) -> f64 {
        if self.toggled {
            return 1.0;
        }
        let span = f64::from(self.maximum) - f64::from(self.minimum);
        if self.integer && span >= 1.0 {
            1.0 / span
        } else {
            0.0
        }
    }
}

/// One control input exposed to the host as a parameter.
#[derive(Clone, Debug, PartialEq)]
pub(crate) struct ControlPort {
    /// LV2 port index, used as the host parameter identifier.
    pub index: u32,
    /// Port symbol, the identifier LV2 keeps stable between plugin versions.
    pub symbol: String,
    pub name: String,
    pub range: ControlRange,
    /// Whether only the scale points are valid values.
    pub enumeration: bool,
    pub scale_points: Vec<ScalePoint>,
    /// Display suffix such as `dB` or `Hz`.
    pub unit: Option<String>,
    pub automatable: bool,
}

impl ControlPort {
    /// Converts a normalized value to the plain value written to the port.
    pub fn to_plain(&self, normalized: f64) -> f32 {
        let plain = self.range.to_plain(normalized);
        if !self.enumeration {
            return plain;
        }
        self.scale_points
            .iter()
            .map(|point| point.value)
            .min_by(|left, right| (left - plain).abs().total_cmp(&(right - plain).abs()))
            .unwrap_or(plain)
    }

    /// Converts a plain port value to the normalized domain.
    pub fn to_normalized(&self, plain: f32) -> f64 {
        self.range.to_normalized(plain)
    }

    /// Normalized step reported to the host.
    pub fn step(&self) -> f64 {
        let step = self.range.step();
        if step > 0.0 || !self.enumeration || self.scale_points.len() < 2 {
            return step;
        }
        1.0 / f64::from(u32::try_from(self.scale_points.len() - 1).unwrap_or(u32::MAX))
    }

    /// Formats a normalized value the way the plugin's port metadata describes it.
    pub fn text(&self, normalized: f64) -> String {
        let plain = self.to_plain(normalized);
        if let Some(point) = self
            .scale_points
            .iter()
            .find(|point| (point.value - plain).abs() <= SCALE_POINT_TOLERANCE)
        {
            return point.label.clone();
        }
        if self.range.toggled {
            return if plain > self.range.minimum {
                "On".to_owned()
            } else {
                "Off".to_owned()
            };
        }
        let number = if self.range.integer {
            format!("{plain:.0}")
        } else if plain.abs() >= 100.0 {
            format!("{plain:.1}")
        } else if plain.abs() >= 10.0 {
            format!("{plain:.2}")
        } else {
            format!("{plain:.3}")
        };
        match self.unit.as_deref() {
            Some(unit) if !unit.is_empty() => format!("{number} {unit}"),
            _ => number,
        }
    }

    /// Parses display text back to a normalized value.
    ///
    /// Accepts a scale-point label, `on`/`off` for toggles, or a number with an optional unit
    /// suffix. Numbers outside the port's bounds are clamped.
    pub fn parse(&self, text: &str) -> Option<f64> {
        let text = text.trim();
        if text.is_empty() {
            return None;
        }
        if let Some(point) = self
            .scale_points
            .iter()
            .find(|point| point.label.eq_ignore_ascii_case(text))
        {
            return Some(self.to_normalized(point.value));
        }
        if self.range.toggled {
            if text.eq_ignore_ascii_case("on") {
                return Some(1.0);
            }
            if text.eq_ignore_ascii_case("off") {
                return Some(0.0);
            }
        }
        let numeric_end = text
            .char_indices()
            .find(|(_, character)| {
                !(character.is_ascii_digit() || matches!(character, '+' | '-' | '.' | 'e' | 'E'))
            })
            .map_or(text.len(), |(index, _)| index);
        let (number, suffix) = text.split_at(numeric_end);
        let suffix = suffix.trim();
        let unit_matches = self
            .unit
            .as_deref()
            .is_some_and(|unit| unit.eq_ignore_ascii_case(suffix));
        if !suffix.is_empty() && !unit_matches {
            return None;
        }
        let plain = number
            .parse::<f32>()
            .ok()
            .filter(|value| value.is_finite())?;
        Some(self.to_normalized(plain))
    }

    /// Builds the host parameter specification for the current normalized value.
    pub fn spec(&self, normalized: f64) -> ParameterSpec {
        let mut spec = ParameterSpec::new_float(
            self.index,
            &self.name,
            "Parameters",
            normalized,
            0.0,
            1.0,
            self.to_normalized(self.range.default),
            self.step(),
        );
        spec.path = format!("lv2/{}", self.symbol);
        spec.automatable = self.automatable;
        spec
    }
}

/// Display symbol for a unit from the LV2 units vocabulary, by the name after its `#`.
pub(crate) fn standard_unit_symbol(name: &str) -> Option<&'static str> {
    Some(match name {
        "db" => "dB",
        "hz" => "Hz",
        "khz" => "kHz",
        "mhz" => "MHz",
        "ms" => "ms",
        "s" => "s",
        "min" => "min",
        "pc" => "%",
        "bpm" => "BPM",
        "cent" => "ct",
        "semitone12TET" => "st",
        "oct" => "oct",
        "degree" => "°",
        "m" => "m",
        "cm" => "cm",
        "mm" => "mm",
        "km" => "km",
        "inch" => "in",
        "mile" => "mi",
        "bar" => "bars",
        "beat" => "beats",
        "frame" => "frames",
        _ => return None,
    })
}

#[allow(
    clippy::as_conversions,
    clippy::cast_possible_truncation,
    reason = "LV2 control ports carry single-precision values"
)]
fn narrow(value: f64) -> f32 {
    if value.is_finite() { value as f32 } else { 0.0 }
}

#[cfg(test)]
#[allow(clippy::unwrap_used, reason = "test fixtures parse known text")]
mod tests {
    use super::*;

    fn port(range: ControlRange) -> ControlPort {
        ControlPort {
            index: 7,
            symbol: "gain".into(),
            name: "Gain".into(),
            range,
            enumeration: false,
            scale_points: Vec::new(),
            unit: Some("dB".into()),
            automatable: true,
        }
    }

    #[test]
    fn linear_ports_round_trip_and_clamp() {
        let range = ControlRange::new(Some(-24.0), Some(24.0), Some(0.0), false, false, false);
        assert!((range.to_plain(0.5)).abs() < 1.0e-6);
        assert!((range.to_plain(2.0) - 24.0).abs() < 1.0e-6);
        assert!((range.to_plain(f64::NAN) + 24.0).abs() < 1.0e-6);
        assert!((range.to_normalized(12.0) - 0.75).abs() < 1.0e-9);
        assert!((range.to_normalized(99.0) - 1.0).abs() < 1.0e-9);
        assert!(range.step().abs() < f64::EPSILON);
    }

    #[test]
    fn logarithmic_mapping_needs_a_positive_lower_bound() {
        let log = ControlRange::new(
            Some(20.0),
            Some(20_000.0),
            Some(1_000.0),
            true,
            false,
            false,
        );
        assert!(log.logarithmic);
        assert!((log.to_plain(0.5) - 632.455_5).abs() < 0.01);
        assert!((log.to_normalized(log.to_plain(0.25)) - 0.25).abs() < 1.0e-6);
        // LSP declares gains as logarithmic from zero, which has no exponential mapping.
        let from_zero = ControlRange::new(Some(0.0), Some(10.0), Some(1.0), true, false, false);
        assert!(!from_zero.logarithmic);
        assert!((from_zero.to_plain(0.1) - 1.0).abs() < 1.0e-6);
    }

    #[test]
    fn integer_and_toggled_ports_snap_and_report_steps() {
        let integer = ControlRange::new(Some(0.0), Some(4.0), Some(1.0), false, true, false);
        assert!((integer.to_plain(0.3) - 1.0).abs() < 1.0e-6);
        assert!((integer.step() - 0.25).abs() < 1.0e-9);
        let toggle = ControlRange::new(Some(0.0), Some(1.0), Some(1.0), false, false, true);
        assert!((toggle.to_plain(0.49)).abs() < 1.0e-6);
        assert!((toggle.to_plain(0.5) - 1.0).abs() < 1.0e-6);
        assert!((toggle.to_normalized(1.0) - 1.0).abs() < 1.0e-9);
        assert!((toggle.step() - 1.0).abs() < 1.0e-9);
    }

    #[test]
    fn missing_or_degenerate_bounds_become_a_usable_range() {
        let unbounded = ControlRange::new(None, None, None, false, false, false);
        assert_eq!((unbounded.minimum, unbounded.maximum), (0.0, 1.0));
        let reversed = ControlRange::new(Some(5.0), Some(1.0), Some(9.0), false, false, false);
        assert_eq!(
            (reversed.minimum, reversed.maximum, reversed.default),
            (1.0, 5.0, 5.0)
        );
        let flat = ControlRange::new(Some(3.0), Some(3.0), None, false, false, false);
        assert_eq!((flat.minimum, flat.maximum), (3.0, 4.0));
    }

    #[test]
    fn text_uses_scale_points_units_and_toggle_words() {
        let mut gain = port(ControlRange::new(
            Some(-24.0),
            Some(24.0),
            Some(0.0),
            false,
            false,
            false,
        ));
        assert_eq!(gain.text(0.75), "12.00 dB");
        assert!((gain.parse("12 dB").unwrap() - 0.75).abs() < 1.0e-6);
        assert!((gain.parse(" -24 ").unwrap()).abs() < 1.0e-9);
        assert!((gain.parse("1e1db").unwrap() - 34.0 / 48.0).abs() < 1.0e-6);
        assert!((gain.parse("500").unwrap() - 1.0).abs() < 1.0e-9);
        assert!(gain.parse("12 Hz").is_none());
        assert!(gain.parse(&"x".repeat(128)).is_none());
        assert!(gain.parse("").is_none());

        gain.unit = None;
        gain.range = ControlRange::new(Some(0.0), Some(2.0), Some(0.0), false, true, false);
        gain.enumeration = true;
        gain.scale_points = vec![
            ScalePoint {
                value: 0.0,
                label: "Peak".into(),
            },
            ScalePoint {
                value: 2.0,
                label: "RMS".into(),
            },
        ];
        assert_eq!(gain.text(1.0), "RMS");
        // The middle value is not a scale point, so an enumeration snaps to the nearest one.
        assert_eq!(gain.text(0.4), "Peak");
        assert!((gain.parse("rms").unwrap() - 1.0).abs() < 1.0e-9);

        let toggle = port(ControlRange::new(
            Some(0.0),
            Some(1.0),
            Some(0.0),
            false,
            false,
            true,
        ));
        assert_eq!(toggle.text(1.0), "On");
        assert_eq!(toggle.text(0.0), "Off");
        assert!((toggle.parse("ON").unwrap() - 1.0).abs() < 1.0e-9);
    }

    #[test]
    fn specs_are_normalized_with_a_symbol_path() {
        let gain = port(ControlRange::new(
            Some(-24.0),
            Some(24.0),
            Some(12.0),
            false,
            false,
            false,
        ));
        let spec = gain.spec(0.5);
        assert_eq!((spec.id, spec.path.as_str()), (7, "lv2/gain"));
        assert_eq!((spec.min, spec.max), (0.0, 1.0));
        assert!((spec.default_value - 0.75).abs() < 1.0e-9);
        assert!((spec.value - 0.5).abs() < 1.0e-9);
    }

    #[test]
    fn standard_units_resolve_to_display_symbols() {
        assert_eq!(standard_unit_symbol("db"), Some("dB"));
        assert_eq!(standard_unit_symbol("pc"), Some("%"));
        assert_eq!(standard_unit_symbol("unknown"), None);
    }
}
