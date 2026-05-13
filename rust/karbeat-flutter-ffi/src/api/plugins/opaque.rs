use flutter_rust_bridge::frb;
use karbeat_plugin_api::types::{BufferDataType, ZeroCopyBuffer};

use crate::api::plugin::UiPluginTarget;

#[frb(opaque)]
pub struct ZeroCopyHandle {
    buffer: ZeroCopyBuffer,
}
impl ZeroCopyHandle {
    /// Tells Dart what kind of TypedList to create
    #[frb(sync)]
    pub fn data_type(&self) -> BufferDataType {
        match &self.buffer {
            ZeroCopyBuffer::Float32(_) => BufferDataType::Float32,
            ZeroCopyBuffer::Uint8(_) => BufferDataType::Uint8,
            ZeroCopyBuffer::Int32(_) => BufferDataType::Int32,
        }
    }
    /// Gets the raw memory address
    #[frb(sync)]
    pub fn memory_address(&self) -> usize {
        match &self.buffer {
            ZeroCopyBuffer::Float32(b) => b.as_ptr() as usize,
            ZeroCopyBuffer::Uint8(b) => b.as_ptr() as usize,
            ZeroCopyBuffer::Int32(b) => b.as_ptr() as usize,
        }
    }
    /// Gets the number of elements (NOT bytes, making Dart's job easier)
    #[frb(sync)]
    pub fn length_elements(&self) -> usize {
        match &self.buffer {
            ZeroCopyBuffer::Float32(b) => b.len(),
            ZeroCopyBuffer::Uint8(b) => b.len(),
            ZeroCopyBuffer::Int32(b) => b.len(),
        }
    }
}
/// The universal FFI fetch function
pub fn get_zero_copy_buffer(target: UiPluginTarget, name: String) -> Option<ZeroCopyHandle> {
    // let plugin = get_plugin_instance(&target)?;
    // let buffer = plugin.get_zero_copy_buffer(&name)?;
    Some(ZeroCopyHandle {
        buffer: ZeroCopyBuffer::Float32(std::sync::Arc::new(Box::new([1.0_f32, 2.0_f32, 3.0_f32]))),
    })
}
