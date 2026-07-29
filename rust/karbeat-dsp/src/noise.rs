use karbeat_macros::EnumParam;
use serde::{Deserialize, Serialize};

#[derive(Clone, PartialEq, Debug, Copy, Deserialize, Serialize, EnumParam)]
pub enum NoiseColor {
    White,
    Pink,
    Brown,
}
