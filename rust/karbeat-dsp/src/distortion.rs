use karbeat_macros::EnumParam;
use serde::{Deserialize, Serialize};

#[derive(Clone, PartialEq, Debug, Copy, Deserialize, Serialize, EnumParam)]
pub enum DistortionType {
    None,
    Sync,
    FormantWarp,
    Bend,
    Squeeze,
    Fold,
    PulseWidth,
}