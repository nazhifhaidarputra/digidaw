use std::{fs::File, io::Write, mem::MaybeUninit, slice};

use crate::audio::writer::{
    AudioFileFormat, AudioWriteError, AudioWriter, BitDepth, metadata::AudioMetadata,
};
use mp3lame_encoder::{Bitrate, Builder, DualPcm, Encoder, FlushNoGap, Quality};

pub struct Mp3AudioWriter {
    pub encoder: Encoder,
    pub mp3_out_buffer: Vec<u8>,
    pub output_path: String,
    pub channels: u8,
    /// ID3v2 tag written ahead of the audio; empty when there is no metadata.
    /// Built here rather than by LAME, whose tag setters only accept Latin-1.
    id3_tag: Vec<u8>,
}

impl TryFrom<BitDepth> for mp3lame_encoder::Bitrate {
    type Error = AudioWriteError;

    fn try_from(value: BitDepth) -> Result<Self, Self::Error> {
        match value {
            BitDepth::BitPerSample(_) => {
                return Err(AudioWriteError::unsupported(
                    AudioFileFormat::Mp3,
                    "a bit depth in bits per sample; use a bitrate instead",
                ));
            }
            BitDepth::BitPerSecond(bit_per_second) => {
                let lame_encoder = match bit_per_second {
                    super::BitPerSecond::Kbps128 => mp3lame_encoder::Bitrate::Kbps128,
                    super::BitPerSecond::Kbps160 => mp3lame_encoder::Bitrate::Kbps160,
                    super::BitPerSecond::Kbps192 => mp3lame_encoder::Bitrate::Kbps192,
                    super::BitPerSecond::Kbps256 => mp3lame_encoder::Bitrate::Kbps256,
                    super::BitPerSecond::Kbps320 => mp3lame_encoder::Bitrate::Kbps320,
                };

                Ok(lame_encoder)
            }
        }
    }
}

pub struct Mp3AudioWriterConfig {
    pub sample_rate: u32,
    pub num_channels: u8,
    pub bit_rate: Bitrate,
    pub quality: Quality,
}

impl Mp3AudioWriterConfig {
    pub fn try_new(
        sample_rate: u32,
        num_channels: u8,
        bit_depth: BitDepth,
    ) -> Result<Self, AudioWriteError> {
        Ok(Self {
            sample_rate,
            num_channels,
            bit_rate: bit_depth.try_into()?,
            quality: Quality::Best,
        })
    }
}

impl Mp3AudioWriter {
    pub fn try_new(
        output_path: impl Into<String>,
        config: Mp3AudioWriterConfig,
        metadata: &AudioMetadata,
    ) -> Result<Self, AudioWriteError> {
        let mut builder = Builder::new().ok_or_else(|| {
            AudioWriteError::encoder(AudioFileFormat::Mp3, "failed to allocate LAME encoder")
        })?;
        builder
            .set_num_channels(config.num_channels)
            .map_err(mp3_error)?;
        builder
            .set_sample_rate(config.sample_rate)
            .map_err(mp3_error)?;
        builder.set_brate(config.bit_rate).map_err(mp3_error)?;
        builder.set_quality(config.quality).map_err(mp3_error)?;

        let encoder = builder.build().map_err(mp3_error)?;

        Ok(Self {
            encoder,
            mp3_out_buffer: Vec::new(),
            output_path: output_path.into(),
            channels: config.num_channels,
            id3_tag: metadata.id3v2_tag().unwrap_or_default(),
        })
    }
}

impl AudioWriter for Mp3AudioWriter {
    fn write(&mut self, samples: &[f32]) -> Result<(), AudioWriteError> {
        if samples.is_empty() {
            return Ok(());
        }

        let mut left = Vec::with_capacity(samples.len() / (self.channels as usize));
        let mut right = Vec::with_capacity(samples.len() / (self.channels as usize));

        if self.channels == 2 {
            for chunk in samples.chunks_exact(2) {
                left.push(chunk[0]);
                right.push(chunk[1]);
            }
        } else {
            // If mono, feed the same signal to both channels safely
            left.extend_from_slice(samples);
            right.extend_from_slice(samples);
        }

        let input = DualPcm {
            left: &left,
            right: &right,
        };

        // Pre-allocate required space before encoding
        let req_size = mp3lame_encoder::max_required_buffer_size(left.len());
        self.mp3_out_buffer.reserve(req_size);

        // Encode and append to our master buffer
        let encoded_size = self
            .encoder
            .encode(input, self.mp3_out_buffer.spare_capacity_mut())
            .map_err(mp3_error)?;

        // SAFETY: The encoder initialized exactly `encoded_size` bytes in the spare capacity.
        unsafe {
            let new_len = self.mp3_out_buffer.len().wrapping_add(encoded_size);
            self.mp3_out_buffer.set_len(new_len);
        }

        Ok(())
    }

    fn finalize(&mut self) -> Result<(), AudioWriteError> {
        // Flush any remaining data from the encoder without gaps
        self.mp3_out_buffer
            .reserve(mp3lame_encoder::max_required_buffer_size(0));
        let encoded_size = self
            .encoder
            .flush::<FlushNoGap>(self.mp3_out_buffer.spare_capacity_mut())
            .map_err(mp3_error)?;

        // SAFETY: The encoder initialized exactly `encoded_size` bytes in the spare capacity.
        unsafe {
            let new_len = self.mp3_out_buffer.len().wrapping_add(encoded_size);
            self.mp3_out_buffer.set_len(new_len);
        }

        // Open output file for the final write
        let mut file = File::create(&self.output_path)?;

        // Layout: [ID3v2] -> [Lame Tag] -> [Audio Data]
        file.write_all(&self.id3_tag)?;
        if self.encoder.lame_tag_size() > 0 {
            let mut lame_tag = [MaybeUninit::uninit(); 1024];

            let lame_tag_size = self.encoder.lame_tag_encode(&mut lame_tag).ok_or_else(|| {
                AudioWriteError::encoder(
                    AudioFileFormat::Mp3,
                    "failed to encode LAME tag because it is empty",
                )
            })?;

            // SAFETY: `lame_tag_encode` initialized `lame_tag_size` bytes in `lame_tag`.
            let lame_tag_slice = unsafe {
                slice::from_raw_parts(lame_tag.as_ptr() as *const u8, lame_tag_size.get())
            };

            file.write_all(lame_tag_slice)?;
        }
        file.write_all(&self.mp3_out_buffer)?;

        Ok(())
    }
}

/// LAME errors only implement `std::error::Error` behind the crate's `std` feature
fn mp3_error(error: impl std::fmt::Debug) -> AudioWriteError {
    AudioWriteError::encoder(AudioFileFormat::Mp3, format!("{error:?}"))
}
