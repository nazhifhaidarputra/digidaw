use thiserror::Error;

#[derive(Debug, Error)]
#[error("Audio resampling failed: {err_source}")]
pub struct AudioResamplingError {
    pub err_source: String,
}