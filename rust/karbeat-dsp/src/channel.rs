use karbeat_macros::EnumParam;
use serde::{Deserialize, Serialize};

#[derive(Clone, Copy, Debug, PartialEq, Default, EnumParam, Deserialize, Serialize)]
pub enum StandardChannelMode {
    Mono = 0,
    #[default]
    Stereo = 1,
}
