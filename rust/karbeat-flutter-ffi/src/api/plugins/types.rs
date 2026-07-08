use std::collections::HashMap;

use karbeat_core::audio::engine::PluginTelemetrySnapshot;
use karbeat_plugin_api::types::BufferDataType;

use crate::api::plugins::opaque::ZeroCopyHandle;

pub struct PluginTelemetrySnapshotDto {
    pub parameters: Vec<(u32, f32)>,
    pub buffer_handles: HashMap<String, ZeroCopyHandle>,
}

impl From<PluginTelemetrySnapshot> for PluginTelemetrySnapshotDto {
    fn from(ss: PluginTelemetrySnapshot) -> Self {
        Self {
            parameters: ss.parameters,
            buffer_handles: ss
                .buffers
                .into_iter()
                .map(|(id, buf)| (id, ZeroCopyHandle::new(buf)))
                .collect(),
        }
    }
}

#[derive(Clone)]
pub enum BufferDataTypeDto {
    Float32,
    Uint8,
    Int32,
    Int8
}

impl BufferDataTypeDto {
    pub fn data_type_str(&self) -> String {
        match self {
            BufferDataTypeDto::Float32 => "f32".to_owned(),
            BufferDataTypeDto::Uint8 => "u8".to_owned(),
            BufferDataTypeDto::Int32 => "i32".to_owned(),
            BufferDataTypeDto::Int8 => "i8".to_owned(),
        }
    }
}

impl From<BufferDataType> for BufferDataTypeDto {
    fn from(value: BufferDataType) -> Self {
        match value {
            BufferDataType::Float32 => BufferDataTypeDto::Float32,
            BufferDataType::Uint8 => BufferDataTypeDto::Uint8,
            BufferDataType::Int32 => BufferDataTypeDto::Int32,
            BufferDataType::Int8 => BufferDataTypeDto::Int8,
        }
    }
}

