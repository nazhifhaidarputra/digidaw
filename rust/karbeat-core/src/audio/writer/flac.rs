use std::{
    fs::File,
    io::{BufWriter, Seek, SeekFrom, Write},
    path::Path,
};

use flacenc::{
    bitsink::ByteSink,
    component::{BitRepr, StreamInfo},
    config,
    error::{Verified, Verify},
    source::{Context, Fill, FrameBuf},
};

use crate::audio::writer::{
    AudioFileFormat, AudioWriteError, AudioWriter, BitPerSample, metadata::AudioMetadata,
};

const FLAC_MARKER: &[u8; 4] = b"fLaC";
/// STREAMINFO payload position: after the marker and its 4 byte block header
const STREAM_INFO_OFFSET: u64 = 8;
const STREAM_INFO_LEN: usize = 34;
const BLOCK_STREAM_INFO: u8 = 0;
const BLOCK_VORBIS_COMMENT: u8 = 4;
const BLOCK_PICTURE: u8 = 6;
const LAST_METADATA_BLOCK: u8 = 0x80;
const VORBIS_VENDOR: &str = "DigiDAW";

#[derive(Clone, Copy, Debug)]
pub struct FlacAudioWriterConfig {
    pub sample_rate: u32,
    pub channels: u16,
    pub bits_per_sample: BitPerSample,
}

/// Struct which manages FLAC audio encoder/writer.
///
/// Frames are encoded with [`flacenc`] as soon as a full block is buffered and
/// streamed to disk. The STREAMINFO block is patched in on [`AudioWriter::finalize`],
/// once the frame sizes, total sample count, and MD5 signature are known.
pub struct FlacAudioWriter {
    file: Option<BufWriter<File>>,
    encoder_config: Verified<config::Encoder>,
    stream_info: StreamInfo,
    frame_buf: FrameBuf,
    context: Context,
    sink: ByteSink,
    /// Interleaved samples waiting for a full block
    pending: Vec<i32>,
    block_len: usize,
    block_size: usize,
    scale: f32,
}

impl FlacAudioWriter {
    pub fn try_new(
        path: &Path,
        config: FlacAudioWriterConfig,
        metadata: &AudioMetadata,
    ) -> Result<Self, AudioWriteError> {
        let bits_per_sample = usize::from(config.bits_per_sample.as_u16());
        if bits_per_sample > flacenc::constant::MAX_BITS_PER_SAMPLE {
            return Err(AudioWriteError::unsupported(
                AudioFileFormat::Flac,
                format!("{bits_per_sample}-bit samples; use 24-bit or lower"),
            ));
        }
        let channels = usize::from(config.channels);
        let sample_rate = usize::try_from(config.sample_rate)
            .map_err(|e| AudioWriteError::encoder(AudioFileFormat::Flac, e))?;

        let encoder_config = config::Encoder::default()
            .into_verified()
            .map_err(|(_, e)| flac_error(e))?;
        let block_size = encoder_config.block_size;
        let stream_info =
            StreamInfo::new(sample_rate, channels, bits_per_sample).map_err(flac_error)?;
        let frame_buf = FrameBuf::with_size(channels, block_size).map_err(flac_error)?;
        let block_len = block_size * channels;

        let mut blocks = Vec::new();
        if metadata.has_text() {
            blocks.push((BLOCK_VORBIS_COMMENT, metadata.vorbis_comment(VORBIS_VENDOR)));
        }
        if let Some(picture) = metadata.flac_picture_block() {
            blocks.push((BLOCK_PICTURE, picture));
        }

        let mut file = BufWriter::new(File::create(path)?);
        file.write_all(FLAC_MARKER)?;
        // STREAMINFO is unknown until every frame is encoded; reserve its space for now
        write_block_header(
            &mut file,
            BLOCK_STREAM_INFO,
            blocks.is_empty(),
            STREAM_INFO_LEN,
        )?;
        file.write_all(&[0; STREAM_INFO_LEN])?;
        let last = blocks.len();
        for (index, (block_type, data)) in blocks.iter().enumerate() {
            write_block_header(&mut file, *block_type, index + 1 == last, data.len())?;
            file.write_all(data)?;
        }

        Ok(Self {
            file: Some(file),
            encoder_config,
            stream_info,
            frame_buf,
            context: Context::new(bits_per_sample, channels),
            sink: ByteSink::new(),
            pending: Vec::with_capacity(block_len),
            block_len,
            block_size,
            scale: ((1_i32 << (bits_per_sample - 1)) - 1) as f32,
        })
    }

    fn encode_pending(&mut self) -> Result<(), AudioWriteError> {
        if self.pending.is_empty() {
            return Ok(());
        }
        let file = self.file.as_mut().ok_or(AudioWriteError::Finalized)?;

        // Fills the frame buffer and updates the running MD5/frame counter together
        (&mut self.frame_buf, &mut self.context)
            .fill_interleaved(&self.pending)
            .map_err(flac_message_error)?;
        let frame_number = self.context.current_frame_number().ok_or_else(|| {
            AudioWriteError::encoder(AudioFileFormat::Flac, "frame counter was not advanced")
        })?;
        let frame = flacenc::encode_fixed_size_frame(
            &self.encoder_config,
            &self.frame_buf,
            frame_number,
            &self.stream_info,
        )
        .map_err(flac_message_error)?;
        self.stream_info.update_frame_info(&frame);

        self.sink.clear();
        frame.write(&mut self.sink).map_err(flac_error)?;
        file.write_all(self.sink.as_slice())?;
        self.pending.clear();
        Ok(())
    }

    fn quantize(&self, sample: f32) -> i32 {
        (sample.clamp(-1.0, 1.0) * self.scale).round() as i32
    }
}

impl AudioWriter for FlacAudioWriter {
    fn write(&mut self, samples: &[f32]) -> Result<(), AudioWriteError> {
        if self.file.is_none() {
            return Err(AudioWriteError::Finalized);
        }

        let mut remaining = samples;
        while !remaining.is_empty() {
            let space = self.block_len - self.pending.len();
            let (head, tail) = remaining.split_at(space.min(remaining.len()));
            for &sample in head {
                let quantized = self.quantize(sample);
                self.pending.push(quantized);
            }
            remaining = tail;

            if self.pending.len() == self.block_len {
                self.encode_pending()?;
            }
        }
        Ok(())
    }

    fn finalize(&mut self) -> Result<(), AudioWriteError> {
        if self.file.is_none() {
            return Ok(());
        }
        // The trailing partial block becomes the (shorter) last frame
        self.encode_pending()?;

        if self.context.total_samples() == 0 {
            // No frames were written, so frame sizes are unknown (encoded as 0)
            self.stream_info.set_frame_sizes(0, 0).map_err(flac_error)?;
        }
        // Min block size excludes the last block, so a fixed-size stream reports one size
        self.stream_info
            .set_block_sizes(self.block_size, self.block_size)
            .map_err(flac_error)?;
        self.stream_info.set_md5_digest(&self.context.md5_digest());

        self.sink.clear();
        self.stream_info.write(&mut self.sink).map_err(flac_error)?;

        let Some(mut file) = self.file.take() else {
            return Ok(());
        };
        file.seek(SeekFrom::Start(STREAM_INFO_OFFSET))?;
        file.write_all(self.sink.as_slice())?;
        file.flush()?;
        Ok(())
    }
}

/// Writes a metadata block header: last-block flag, block type, 24-bit length
fn write_block_header(
    file: &mut impl Write,
    block_type: u8,
    is_last: bool,
    len: usize,
) -> Result<(), AudioWriteError> {
    let len = u32::try_from(len)
        .ok()
        .filter(|len| *len < 1 << 24)
        .ok_or_else(|| {
            AudioWriteError::encoder(AudioFileFormat::Flac, "metadata block too large")
        })?;
    let flag = if is_last { LAST_METADATA_BLOCK } else { 0 };
    let [_, a, b, c] = len.to_be_bytes();
    file.write_all(&[flag | block_type, a, b, c])?;
    Ok(())
}

fn flac_error(error: impl std::error::Error + Send + Sync + 'static) -> AudioWriteError {
    AudioWriteError::encoder(AudioFileFormat::Flac, error)
}

/// flacenc's source/encode errors hold an `Rc`, so only their message can cross threads
fn flac_message_error(error: impl std::error::Error) -> AudioWriteError {
    AudioWriteError::encoder(AudioFileFormat::Flac, error.to_string())
}

#[cfg(test)]
#[allow(
    clippy::unwrap_used,
    reason = "writer fixtures assert setup and decoded output"
)]
mod tests {
    use super::*;
    use std::io::{BufReader, Read};

    fn sine(frames: usize, channels: usize) -> Vec<f32> {
        (0..frames * channels)
            .map(|i| ((i / channels) as f32 * 0.01).sin() * 0.5)
            .collect()
    }

    fn write_flac(path: &Path, samples: &[f32], bits: BitPerSample, metadata: &AudioMetadata) {
        let mut writer = FlacAudioWriter::try_new(
            path,
            FlacAudioWriterConfig {
                sample_rate: 48_000,
                channels: 2,
                bits_per_sample: bits,
            },
            metadata,
        )
        .unwrap();
        // Uneven chunks exercise block boundary handling
        for chunk in samples.chunks(1234) {
            writer.write(chunk).unwrap();
        }
        writer.finalize().unwrap();
    }

    #[test]
    fn flac_round_trips_through_a_decoder() {
        let dir = tempfile::tempdir().unwrap();
        let path = dir.path().join("out.flac");
        let frames = 10_000;
        let input = sine(frames, 2);
        // A comment block must not disturb decoding
        let metadata = AudioMetadata {
            title: "Round Trip".into(),
            ..AudioMetadata::default()
        };
        write_flac(&path, &input, BitPerSample::B24, &metadata);

        let decoder = rodio::Decoder::new(BufReader::new(File::open(&path).unwrap())).unwrap();
        assert_eq!(rodio::Source::channels(&decoder).get(), 2);
        assert_eq!(rodio::Source::sample_rate(&decoder).get(), 48_000);
        let decoded: Vec<f32> = decoder.collect();

        assert_eq!(decoded.len(), input.len());
        for (a, b) in input.iter().zip(&decoded) {
            assert!((a - b).abs() < 1e-4, "{a} vs {b}");
        }
    }

    #[test]
    fn flac_stream_info_is_patched_on_finalize() {
        let dir = tempfile::tempdir().unwrap();
        let path = dir.path().join("out.flac");
        let frames = 5_000;
        write_flac(
            &path,
            &sine(frames, 2),
            BitPerSample::B16,
            &AudioMetadata::default(),
        );

        let mut bytes = Vec::new();
        File::open(&path).unwrap().read_to_end(&mut bytes).unwrap();
        // Without metadata STREAMINFO is the last and only metadata block
        assert_eq!(&bytes[..8], b"fLaC\x80\x00\x00\x22");
        let info = &bytes[8..8 + STREAM_INFO_LEN];
        // Total samples: low 36 bits of bytes 13..18
        let total = (u64::from(info[13] & 0x0F) << 32)
            | u64::from(u32::from_be_bytes([info[14], info[15], info[16], info[17]]));
        assert_eq!(total, frames as u64);
        assert_ne!(&info[18..34], &[0; 16], "MD5 signature must be set");
    }

    #[test]
    fn flac_rejects_32_bit_samples() {
        let dir = tempfile::tempdir().unwrap();
        let result = FlacAudioWriter::try_new(
            &dir.path().join("out.flac"),
            FlacAudioWriterConfig {
                sample_rate: 48_000,
                channels: 2,
                bits_per_sample: BitPerSample::B32,
            },
            &AudioMetadata::default(),
        );
        assert!(matches!(
            result,
            Err(AudioWriteError::UnsupportedConfig { .. })
        ));
    }
}
