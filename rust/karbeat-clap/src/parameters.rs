//! Parameter mapping between the host's normalized domain and CLAP plain values.
//!
//! The host addresses every external parameter as a normalized `[0, 1]` value. CLAP parameters
//! carry plain values within declared bounds, so each one keeps the mapping and its
//! specification here, free of plugin calls so the policy can be tested directly.

use clack_extensions::params::{ParamInfo, ParamInfoFlags};
use karbeat_plugin_api::prelude::ParameterSpec;

/// One CLAP parameter exposed to the host.
#[derive(Clone, Debug, PartialEq)]
pub(crate) struct ClapParameter {
    /// CLAP parameter ID, used as the host parameter identifier.
    pub id: u32,
    pub name: String,
    /// Slash-separated group path the plugin files the parameter under.
    pub module: String,
    pub minimum: f64,
    pub maximum: f64,
    pub default: f64,
    /// Whether only whole plain values are valid.
    pub stepped: bool,
    pub automatable: bool,
    /// Whether the plugin only reports the value and ignores host changes.
    pub read_only: bool,
}

impl ClapParameter {
    /// Reads a parameter description, or returns `None` for one the plugin hides from users.
    ///
    /// Bounds that are not finite or are reversed become a usable range.
    pub fn from_info(info: &ParamInfo<'_>) -> Option<Self> {
        if info.flags.contains(ParamInfoFlags::IS_HIDDEN) {
            return None;
        }
        let finite = |value: f64, fallback: f64| if value.is_finite() { value } else { fallback };
        let mut minimum = finite(info.min_value, 0.0);
        let mut maximum = finite(info.max_value, minimum + 1.0);
        if maximum < minimum {
            std::mem::swap(&mut minimum, &mut maximum);
        }
        let name = String::from_utf8_lossy(info.name).trim().to_owned();
        Some(Self {
            id: info.id.get(),
            name: if name.is_empty() {
                format!("Parameter {}", info.id.get())
            } else {
                name
            },
            module: String::from_utf8_lossy(info.module).trim().to_owned(),
            minimum,
            maximum,
            default: finite(info.default_value, minimum).clamp(minimum, maximum),
            stepped: info.flags.contains(ParamInfoFlags::IS_STEPPED),
            automatable: info.flags.contains(ParamInfoFlags::IS_AUTOMATABLE)
                && !info.flags.contains(ParamInfoFlags::IS_READONLY),
            read_only: info.flags.contains(ParamInfoFlags::IS_READONLY),
        })
    }

    /// Converts a normalized value to the plain value sent to the plugin.
    pub fn to_plain(&self, normalized: f64) -> f64 {
        let normalized = if normalized.is_finite() {
            normalized.clamp(0.0, 1.0)
        } else {
            0.0
        };
        let plain = self.minimum + normalized * (self.maximum - self.minimum);
        let plain = if self.stepped { plain.round() } else { plain };
        plain.clamp(self.minimum, self.maximum)
    }

    /// Converts a plain value reported by the plugin to the normalized domain.
    pub fn to_normalized(&self, plain: f64) -> f64 {
        let span = self.maximum - self.minimum;
        if !plain.is_finite() || span <= 0.0 {
            return 0.0;
        }
        ((plain - self.minimum) / span).clamp(0.0, 1.0)
    }

    /// Normalized distance between adjacent values, or zero for a continuous parameter.
    pub fn step(&self) -> f64 {
        let span = self.maximum - self.minimum;
        if self.stepped && span >= 1.0 {
            1.0 / span
        } else {
            0.0
        }
    }

    /// Builds the host parameter specification for the current normalized value.
    pub fn spec(&self, normalized: f64) -> ParameterSpec {
        let group = self
            .module
            .rsplit('/')
            .find(|segment| !segment.trim().is_empty())
            .unwrap_or("Parameters");
        let mut spec = ParameterSpec::new_float(
            self.id,
            &self.name,
            group,
            normalized,
            0.0,
            1.0,
            self.to_normalized(self.default),
            self.step(),
        );
        // CLAP parameter IDs are stable between plugin versions.
        spec.path = format!("clap/{}", self.id);
        spec.automatable = self.automatable;
        spec
    }
}

/// Sorts parameters by ID and drops repeated IDs, as the parameter exchange requires.
pub(crate) fn sorted(mut parameters: Vec<ClapParameter>) -> Vec<ClapParameter> {
    parameters.sort_by_key(|parameter| parameter.id);
    parameters.dedup_by_key(|parameter| parameter.id);
    parameters
}

/// Encodes plain parameter values for plugins without the state extension.
pub(crate) fn encode_values(values: &[(u32, f64)]) -> Vec<u8> {
    values
        .iter()
        .flat_map(|(id, value)| {
            id.to_le_bytes()
                .into_iter()
                .chain(value.to_le_bytes())
                .collect::<Vec<_>>()
        })
        .collect()
}

/// Decodes values written by [`encode_values`], or returns `None` for malformed bytes.
pub(crate) fn decode_values(bytes: &[u8]) -> Option<Vec<(u32, f64)>> {
    let (records, rest) = bytes.as_chunks::<12>();
    if !rest.is_empty() {
        return None;
    }
    records
        .iter()
        .map(|record| {
            let (id, value) = record.split_at(4);
            Some((
                u32::from_le_bytes(id.try_into().ok()?),
                f64::from_le_bytes(value.try_into().ok()?),
            ))
        })
        .collect()
}

#[cfg(test)]
#[allow(clippy::unwrap_used, reason = "test fixtures decode known bytes")]
mod tests {
    use super::*;
    use clack_host::utils::{ClapId, Cookie};

    fn info<'a>(flags: ParamInfoFlags, name: &'a [u8], bounds: (f64, f64, f64)) -> ParamInfo<'a> {
        ParamInfo {
            id: ClapId::new(7),
            flags,
            cookie: Cookie::empty(),
            name,
            module: b"Filter/Cutoff",
            min_value: bounds.0,
            max_value: bounds.1,
            default_value: bounds.2,
        }
    }

    #[test]
    fn continuous_parameters_round_trip_and_clamp() {
        let gain = ClapParameter::from_info(&info(
            ParamInfoFlags::IS_AUTOMATABLE,
            b"Gain",
            (-24.0, 24.0, 0.0),
        ))
        .unwrap();
        assert!((gain.to_plain(0.75) - 12.0).abs() < 1.0e-9);
        assert!((gain.to_plain(2.0) - 24.0).abs() < 1.0e-9);
        assert!((gain.to_plain(f64::NAN) + 24.0).abs() < 1.0e-9);
        assert!((gain.to_normalized(12.0) - 0.75).abs() < 1.0e-9);
        assert!((gain.to_normalized(99.0) - 1.0).abs() < 1.0e-9);
        assert!(gain.step().abs() < f64::EPSILON);
        assert!(gain.automatable);
    }

    #[test]
    fn stepped_parameters_snap_and_report_steps() {
        let mode = ClapParameter::from_info(&info(
            ParamInfoFlags::IS_STEPPED | ParamInfoFlags::IS_AUTOMATABLE,
            b"Mode",
            (0.0, 4.0, 1.0),
        ))
        .unwrap();
        assert!((mode.to_plain(0.3) - 1.0).abs() < 1.0e-9);
        assert!((mode.step() - 0.25).abs() < 1.0e-9);
    }

    #[test]
    fn hidden_parameters_are_skipped_and_degenerate_bounds_are_repaired() {
        assert!(
            ClapParameter::from_info(&info(ParamInfoFlags::IS_HIDDEN, b"x", (0.0, 1.0, 0.0)))
                .is_none()
        );
        let reversed = ClapParameter::from_info(&info(
            ParamInfoFlags::IS_READONLY | ParamInfoFlags::IS_AUTOMATABLE,
            b"  ",
            (5.0, 1.0, 9.0),
        ))
        .unwrap();
        assert_eq!(
            (reversed.minimum, reversed.maximum, reversed.default),
            (1.0, 5.0, 5.0)
        );
        assert_eq!(reversed.name, "Parameter 7");
        assert!(reversed.read_only && !reversed.automatable);
        let flat =
            ClapParameter::from_info(&info(ParamInfoFlags::empty(), b"Flat", (3.0, 3.0, 3.0)))
                .unwrap();
        assert!(flat.to_normalized(3.0).abs() < f64::EPSILON);
        assert!((flat.to_plain(0.5) - 3.0).abs() < f64::EPSILON);
    }

    #[test]
    fn specs_are_normalized_with_an_id_path_and_module_group() {
        let gain = ClapParameter::from_info(&info(
            ParamInfoFlags::IS_AUTOMATABLE,
            b"Gain",
            (-24.0, 24.0, 12.0),
        ))
        .unwrap();
        let spec = gain.spec(0.5);
        assert_eq!((spec.id, spec.path.as_str()), (7, "clap/7"));
        assert_eq!(spec.group, "Cutoff");
        assert_eq!((spec.min, spec.max), (0.0, 1.0));
        assert!((spec.default_value - 0.75).abs() < 1.0e-9);
        assert!((spec.value - 0.5).abs() < 1.0e-9);
    }

    #[test]
    fn plain_values_round_trip_and_malformed_bytes_are_rejected() {
        let values = [(1, 0.25), (u32::MAX - 1, -3.5)];
        assert_eq!(decode_values(&encode_values(&values)).unwrap(), values);
        assert!(decode_values(&[0; 11]).is_none());
        assert_eq!(decode_values(&[]).unwrap(), []);
    }
}
