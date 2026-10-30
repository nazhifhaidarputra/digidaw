use super::{
    AudioFileFormat, AudioWriteError, AudioWriter, BitDepth,
    metadata::{AudioMetadata, put_riff_chunk},
};
use derive_builder::Builder;
use hound::{SampleFormat, WavSpec, WavWriter};
use std::{
    fs::{File, OpenOptions},
    io::{BufWriter, Seek, SeekFrom, Write},
    path::{Path, PathBuf},
};

pub struct WavAudioWriter {
    writer: Option<WavWriter<BufWriter<File>>>,
    spec: WavSpec,
    path: PathBuf,
    /// `LIST`/`INFO` and `id3 ` chunks appended after the audio data;
    /// empty when there is no metadata to embed
    tag_chunks: Vec<u8>,
}

#[derive(Clone, Copy, Debug, Builder)]
/// Standard definition for audio metadata required by all encoders
pub struct WavAudioWriterConfig {
    pub sample_rate: u32,
    pub channels: u16,
    pub bit_depth: BitDepth,
}

impl WavAudioWriter {
    pub fn new(
        path: &Path,
        format: WavAudioWriterConfig,
        metadata: &AudioMetadata,
    ) -> Result<Self, AudioWriteError> {
        let bits_per_sample = match format.bit_depth {
            BitDepth::BitPerSample(bps) => bps.as_u16(),
            BitDepth::BitPerSecond(_) => {
                return Err(AudioWriteError::unsupported(
                    AudioFileFormat::Wav,
                    "a bitrate in bits per second",
                ));
            }
        };

        let sample_format = if bits_per_sample == 32 {
            SampleFormat::Float
        } else {
            SampleFormat::Int
        };

        let spec = WavSpec {
            channels: format.channels,
            sample_rate: format.sample_rate,
            bits_per_sample,
            sample_format,
        };

        let writer = WavWriter::create(path, spec).map_err(wav_error)?;

        // INFO is what Windows reads; the ID3 chunk carries Unicode reliably for
        // TagLib and ffmpeg based players
        let mut tag_chunks = metadata.riff_info_chunk().unwrap_or_default();
        if let Some(id3) = metadata.id3v2_tag() {
            put_riff_chunk(&mut tag_chunks, b"id3 ", &id3);
        }

        Ok(Self {
            writer: Some(writer),
            spec,
            path: path.to_path_buf(),
            tag_chunks,
        })
    }

    /// Appends the tag chunks after the `data` chunk and grows the RIFF size.
    /// RIFF allows chunks in any order, and libsndfile writes tags here too.
    fn append_tag_chunks(&self) -> Result<(), AudioWriteError> {
        let mut file = OpenOptions::new().read(true).write(true).open(&self.path)?;
        let mut end = file.seek(SeekFrom::End(0))?;
        // hound does not pad an odd-sized data chunk; chunks must start word-aligned
        if end % 2 == 1 {
            file.write_all(&[0])?;
            end += 1;
        }
        file.write_all(&self.tag_chunks)?;

        let riff_size = u32::try_from(end + self.tag_chunks.len() as u64 - 8).map_err(|_| {
            AudioWriteError::encoder(AudioFileFormat::Wav, "file exceeds the 4 GiB RIFF limit")
        })?;
        file.seek(SeekFrom::Start(4))?;
        file.write_all(&riff_size.to_le_bytes())?;
        file.flush()?;
        Ok(())
    }
}

impl AudioWriter for WavAudioWriter {
    fn write(&mut self, samples: &[f32]) -> Result<(), AudioWriteError> {
        let writer = self.writer.as_mut().ok_or(AudioWriteError::Finalized)?;

        match self.spec.sample_format {
            SampleFormat::Float => {
                // For 32-bit float, we can write the f32 samples directly
                for &sample in samples {
                    writer
                        .write_sample(sample.clamp(-1.0, 1.0))
                        .map_err(wav_error)?;
                }
            }
            SampleFormat::Int => {
                // For Integer formats, we must scale the f32 [-1.0, 1.0] range to the integer bounds
                match self.spec.bits_per_sample {
                    16 => {
                        let multiplier = i16::MAX as f32; // 32767.0
                        for &sample in samples {
                            let clamped = sample.clamp(-1.0, 1.0);
                            let int_sample = (clamped * multiplier) as i16;
                            writer.write_sample(int_sample).map_err(wav_error)?;
                        }
                    }
                    24 => {
                        // 24-bit is written using i32, and Hound truncates it to 3 bytes internally.
                        let multiplier = 8_388_607.0; // 2^23 - 1
                        for &sample in samples {
                            let clamped = sample.clamp(-1.0, 1.0);
                            let int_sample = (clamped * multiplier) as i32;
                            writer.write_sample(int_sample).map_err(wav_error)?;
                        }
                    }
                    8 => {
                        let multiplier = i8::MAX as f32; // 127.0
                        for &sample in samples {
                            let clamped = sample.clamp(-1.0, 1.0);
                            let int_sample = (clamped * multiplier) as i8;
                            writer.write_sample(int_sample).map_err(wav_error)?;
                        }
                    }
                    bits => {
                        return Err(AudioWriteError::unsupported(
                            AudioFileFormat::Wav,
                            format!("{bits}-bit integer samples"),
                        ));
                    }
                }
            }
        }
        Ok(())
    }

    fn finalize(&mut self) -> Result<(), AudioWriteError> {
        if let Some(writer) = self.writer.take() {
            writer.finalize().map_err(wav_error)?;
            if !self.tag_chunks.is_empty() {
                self.append_tag_chunks()?;
            }
        }
        Ok(())
    }
}

fn wav_error(error: hound::Error) -> AudioWriteError {
    match error {
        hound::Error::IoError(io) => AudioWriteError::Io(io),
        other => AudioWriteError::encoder(AudioFileFormat::Wav, other),
    }
}
