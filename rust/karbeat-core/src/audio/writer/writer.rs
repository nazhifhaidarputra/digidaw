use std::{
    error::Error,
    fmt,
    path::{Path, PathBuf},
};
use thiserror::Error;

use crate::audio::writer::{
    flac::{FlacAudioWriter, FlacAudioWriterConfig},
    metadata::AudioMetadata,
    mp3::{Mp3AudioWriter, Mp3AudioWriterConfig},
    ogg::{OPUS_SAMPLE_RATE, OggOpusAudioWriter, OggOpusAudioWriterConfig},
    wav::{self, WavAudioWriterConfig},
};

/// Audio container/codec produced by an [`AudioWriter`]
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum AudioFileFormat {
    Wav,
    Mp3,
    Flac,
    OggOpus,
}

impl fmt::Display for AudioFileFormat {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        let name = match self {
            Self::Wav => "WAV",
            Self::Mp3 => "MP3",
            Self::Flac => "FLAC",
            Self::OggOpus => "OGG Opus",
        };
        f.write_str(name)
    }
}

/// Errors produced while creating, feeding, or finalizing an [`AudioWriter`]
#[derive(Debug, Error)]
pub enum AudioWriteError {
    #[error("{format} export does not support {reason}")]
    UnsupportedConfig {
        format: AudioFileFormat,
        reason: String,
    },
    #[error("output path is not valid UTF-8: {}", .0.display())]
    InvalidPath(PathBuf),
    #[error("audio writer has already been finalized")]
    Finalized,
    #[error("failed to write audio file: {0}")]
    Io(#[from] std::io::Error),
    #[error("{format} encoder error: {source}")]
    Encoder {
        format: AudioFileFormat,
        #[source]
        source: Box<dyn Error + Send + Sync>,
    },
}

impl AudioWriteError {
    pub(crate) fn unsupported(format: AudioFileFormat, reason: impl Into<String>) -> Self {
        Self::UnsupportedConfig {
            format,
            reason: reason.into(),
        }
    }

    pub(crate) fn encoder(
        format: AudioFileFormat,
        source: impl Into<Box<dyn Error + Send + Sync>>,
    ) -> Self {
        Self::Encoder {
            format,
            source: source.into(),
        }
    }
}

#[derive(Clone, Copy, Debug)]
#[repr(u16)]
pub enum BitPerSample {
    B8 = 8,
    B16 = 16,
    B24 = 24,
    B32 = 32,
}

impl BitPerSample {
    pub fn as_u16(self) -> u16 {
        self as u16
    }
}

#[derive(Debug)]
pub struct BitPerSampleError;

impl std::fmt::Display for BitPerSampleError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "Not a valid BitPerSample value")
    }
}

impl std::error::Error for BitPerSampleError {}

impl TryFrom<u16> for BitPerSample {
    type Error = BitPerSampleError;

    fn try_from(value: u16) -> Result<Self, Self::Error> {
        match value {
            8 => Ok(BitPerSample::B8),
            16 => Ok(BitPerSample::B16),
            24 => Ok(BitPerSample::B24),
            32 => Ok(BitPerSample::B32),
            _ => Err(BitPerSampleError),
        }
    }
}

#[derive(Clone, Copy, Debug)]
#[repr(u32)]
pub enum BitPerSecond {
    Kbps128 = 128,
    Kbps160 = 160,
    Kbps192 = 192,
    Kbps256 = 256,
    Kbps320 = 320,
}

impl BitPerSecond {
    pub fn as_kbps(self) -> u32 {
        self as u32
    }
}

/// Unified configuration payload for any supported audio exporter
pub enum AudioExportConfig {
    Wav(WavAudioWriterConfig),
    Mp3 {
        sample_rate: u32,
        channels: u8,
        bit_depth: BitDepth,
    },
    Flac(FlacAudioWriterConfig),
    Ogg(OggOpusAudioWriterConfig),
}

impl AudioExportConfig {
    /// Extracts the target sample rate for the audio engine
    pub fn sample_rate(&self) -> u32 {
        match self {
            Self::Wav(config) => config.sample_rate,
            Self::Mp3 { sample_rate, .. } => *sample_rate,
            Self::Flac(config) => config.sample_rate,
            // Opus only encodes fullband audio at 48 kHz, so the engine renders at that rate
            Self::Ogg(_) => OPUS_SAMPLE_RATE,
        }
    }

    /// Extracts the target channel count for the audio engine
    pub fn channels(&self) -> u16 {
        match self {
            Self::Wav(config) => config.channels,
            Self::Mp3 { channels, .. } => *channels as u16,
            Self::Flac(config) => config.channels,
            Self::Ogg(config) => u16::from(config.channels),
        }
    }
}

#[derive(Debug)]
pub struct BitPerSecondError;

impl std::fmt::Display for BitPerSecondError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "Not a valid BitPerSecond value")
    }
}

impl std::error::Error for BitPerSecondError {}

impl TryFrom<u16> for BitPerSecond {
    type Error = BitPerSecondError;

    fn try_from(value: u16) -> Result<Self, Self::Error> {
        match value {
            128 => Ok(BitPerSecond::Kbps128),
            160 => Ok(BitPerSecond::Kbps160),
            192 => Ok(BitPerSecond::Kbps192),
            256 => Ok(BitPerSecond::Kbps256),
            320 => Ok(BitPerSecond::Kbps320),
            _ => Err(BitPerSecondError),
        }
    }
}

#[derive(Clone, Copy, Debug)]
pub enum BitDepth {
    BitPerSample(BitPerSample),
    BitPerSecond(BitPerSecond),
}

impl BitDepth {
    pub fn try_new_bits_per_sample(bps: u16) -> Result<BitDepth, Box<dyn Error>> {
        let bits_per_sample: BitPerSample = bps.try_into()?;
        Ok(BitDepth::BitPerSample(bits_per_sample))
    }

    pub fn try_new_bits_per_sec(bps: u16) -> Result<BitDepth, Box<dyn Error>> {
        let bits_per_sec: BitPerSecond = bps.try_into()?;
        Ok(BitDepth::BitPerSecond(bits_per_sec))
    }
}

/// The common trait implemented by all format-specific writers
pub trait AudioWriter: Send {
    /// Writes interleaved f32 samples (e.g., [L, R, L, R])
    fn write(&mut self, samples: &[f32]) -> Result<(), AudioWriteError>;

    /// Flushes buffers and writes trailing file headers.
    /// Must be called before the writer is dropped.
    fn finalize(&mut self) -> Result<(), AudioWriteError>;
}

impl AudioWriter for Box<dyn AudioWriter> {
    fn write(&mut self, buffer: &[f32]) -> Result<(), AudioWriteError> {
        (**self).write(buffer)
    }

    fn finalize(&mut self) -> Result<(), AudioWriteError> {
        (**self).finalize()
    }
}

/// Factory function to create the appropriate writer based on file extension.
/// Non-blank `metadata` fields are embedded using each format's native tags.
pub fn create_writer(
    path: &Path,
    config: AudioExportConfig,
    metadata: &AudioMetadata,
) -> Result<Box<dyn AudioWriter>, AudioWriteError> {
    match config {
        AudioExportConfig::Wav(format) => {
            Ok(Box::new(wav::WavAudioWriter::new(path, format, metadata)?))
        }
        AudioExportConfig::Mp3 {
            sample_rate,
            channels,
            bit_depth,
        } => {
            let path_str = path
                .to_str()
                .ok_or_else(|| AudioWriteError::InvalidPath(path.to_path_buf()))?;
            let config = Mp3AudioWriterConfig::try_new(sample_rate, channels, bit_depth)?;
            Ok(Box::new(Mp3AudioWriter::try_new(
                path_str, config, metadata,
            )?))
        }
        AudioExportConfig::Flac(config) => {
            Ok(Box::new(FlacAudioWriter::try_new(path, config, metadata)?))
        }
        AudioExportConfig::Ogg(config) => Ok(Box::new(OggOpusAudioWriter::try_new(
            path, config, metadata,
        )?)),
    }
}

pub trait AudioExporter {
    fn config(&self) -> AudioExportConfig;
    fn writer(&self) -> Box<dyn AudioExporter>;
}

#[cfg(test)]
#[allow(
    clippy::unwrap_used,
    clippy::indexing_slicing,
    reason = "export fixtures assert written files and read-back tags"
)]
mod tag_tests {
    use super::*;
    use crate::audio::writer::metadata::{ggez, test_cover};
    use std::{fs::File, io::BufReader};
    use symphonia::core::{
        formats::FormatOptions, io::MediaSourceStream, meta::MetadataOptions, probe::Hint,
    };

    fn ggez_with_cover() -> AudioMetadata {
        AudioMetadata {
            cover: Some(test_cover()),
            ..ggez()
        }
    }

    fn export(path: &Path, config: AudioExportConfig, metadata: &AudioMetadata, samples: &[f32]) {
        let mut writer = create_writer(path, config, metadata).unwrap();
        writer.write(samples).unwrap();
        writer.finalize().unwrap();
    }

    fn stereo_sine(frames: usize) -> Vec<f32> {
        (0..frames * 2)
            .map(|i| ((i / 2) as f32 * 0.02).sin() * 0.5)
            .collect()
    }

    /// What a real reader (symphonia) sees: tag values and embedded pictures,
    /// from the probe (leading ID3v2) and the container itself
    struct ReadBack {
        values: Vec<String>,
        pictures: Vec<(String, Vec<u8>)>,
    }

    fn read_back(path: &Path, extension: &str) -> ReadBack {
        let source =
            MediaSourceStream::new(Box::new(File::open(path).unwrap()), Default::default());
        let mut hint = Hint::new();
        hint.with_extension(extension);
        let mut probed = symphonia::default::get_probe()
            .format(
                &hint,
                source,
                &FormatOptions::default(),
                &MetadataOptions::default(),
            )
            .unwrap();
        // Ogg delivers its comment header as the stream is read
        let _ = probed.format.next_packet();

        let mut read = ReadBack {
            values: Vec::new(),
            pictures: Vec::new(),
        };
        let mut collect = |revision: &symphonia::core::meta::MetadataRevision| {
            read.values
                .extend(revision.tags().iter().map(|tag| tag.value.to_string()));
            read.pictures.extend(
                revision
                    .visuals()
                    .iter()
                    .map(|visual| (visual.media_type.clone(), visual.data.to_vec())),
            );
        };
        if let Some(revision) = probed.metadata.get().as_ref().and_then(|m| m.current()) {
            collect(revision);
        }
        if let Some(revision) = probed.format.metadata().current() {
            collect(revision);
        }
        read
    }

    fn assert_values(read: &ReadBack, expected: &[&str]) {
        for value in expected {
            assert!(
                read.values.iter().any(|v| v == value),
                "{value} missing from {:?}",
                read.values
            );
        }
    }

    fn flac_config() -> AudioExportConfig {
        AudioExportConfig::Flac(FlacAudioWriterConfig {
            sample_rate: 48_000,
            channels: 2,
            bits_per_sample: BitPerSample::B16,
        })
    }

    fn mp3_config() -> AudioExportConfig {
        AudioExportConfig::Mp3 {
            sample_rate: 48_000,
            channels: 2,
            bit_depth: BitDepth::BitPerSecond(BitPerSecond::Kbps192),
        }
    }

    fn ogg_config() -> AudioExportConfig {
        AudioExportConfig::Ogg(OggOpusAudioWriterConfig {
            channels: 2,
            bitrate: BitPerSecond::Kbps192,
        })
    }

    #[test]
    fn flac_mp3_and_opus_tags_and_covers_are_readable() {
        let dir = tempfile::tempdir().unwrap();
        let samples = stereo_sine(24_000);
        let metadata = ggez_with_cover();
        let common = ["GGEZ", "Slop Pop", "Hey don't say that"];
        let each_artist = ["Kaien", "Sugar", "M. Sasuke"];

        for (extension, config) in [("flac", flac_config()), ("opus", ogg_config())] {
            let path = dir.path().join(format!("ggez.{extension}"));
            export(&path, config, &metadata, &samples);
            let read = read_back(&path, extension);
            assert_values(&read, &common);
            // Vorbis comments carry one ARTIST field per artist
            assert_values(&read, &each_artist);
            assert_values(&read, &["2025-04-01"]);
            assert_eq!(
                read.pictures,
                [("image/jpeg".to_owned(), test_cover().bytes().to_vec())],
                "{extension} cover"
            );
        }

        let path = dir.path().join("ggez.mp3");
        export(&path, mp3_config(), &metadata, &samples);
        let read = read_back(&path, "mp3");
        assert_values(&read, &common);
        // ID3v2.3 holds one artist string and a four-digit year
        assert_values(&read, &["Kaien; Sugar; M. Sasuke", "2025"]);
        assert_eq!(
            read.pictures,
            [("image/jpeg".to_owned(), test_cover().bytes().to_vec())]
        );
    }

    #[test]
    fn cover_alone_is_embedded_without_text_tags() {
        let dir = tempfile::tempdir().unwrap();
        let metadata = AudioMetadata {
            cover: Some(test_cover()),
            ..AudioMetadata::default()
        };
        let path = dir.path().join("cover_only.flac");
        export(&path, flac_config(), &metadata, &stereo_sine(4_800));

        let read = read_back(&path, "flac");
        assert!(read.values.is_empty());
        assert_eq!(read.pictures.len(), 1);
    }

    #[test]
    fn blank_metadata_writes_no_tags() {
        let dir = tempfile::tempdir().unwrap();
        let samples = stereo_sine(4_800);
        let blank = AudioMetadata::default();
        for (extension, config) in [
            ("flac", flac_config()),
            ("mp3", mp3_config()),
            ("opus", ogg_config()),
        ] {
            let path = dir.path().join(format!("blank.{extension}"));
            export(&path, config, &blank, &samples);
            let read = read_back(&path, extension);
            assert!(read.values.is_empty(), "{extension} has tags");
            assert!(read.pictures.is_empty(), "{extension} has a picture");
        }

        let mp3 = std::fs::read(dir.path().join("blank.mp3")).unwrap();
        assert_ne!(&mp3[..3], b"ID3");
        let flac = std::fs::read(dir.path().join("blank.flac")).unwrap();
        assert_eq!(flac[4], 0x80, "STREAMINFO stays the last metadata block");
    }

    /// Walks the top-level RIFF chunks, checking sizes and word alignment
    fn riff_chunks(bytes: &[u8]) -> Vec<([u8; 4], &[u8])> {
        assert_eq!(&bytes[..4], b"RIFF");
        let riff_size = u32::from_le_bytes(bytes[4..8].try_into().unwrap()) as usize;
        assert_eq!(riff_size, bytes.len() - 8);
        assert_eq!(&bytes[8..12], b"WAVE");

        let mut chunks = Vec::new();
        let mut pos = 12;
        while pos < bytes.len() {
            let id: [u8; 4] = bytes[pos..pos + 4].try_into().unwrap();
            let len = u32::from_le_bytes(bytes[pos + 4..pos + 8].try_into().unwrap()) as usize;
            chunks.push((id, &bytes[pos + 8..pos + 8 + len]));
            pos += 8 + len + len % 2;
        }
        assert_eq!(pos, bytes.len());
        chunks
    }

    fn contains(haystack: &[u8], needle: &[u8]) -> bool {
        haystack.windows(needle.len()).any(|w| w == needle)
    }

    #[test]
    fn wav_tags_follow_the_data_chunk() {
        let dir = tempfile::tempdir().unwrap();
        let path = dir.path().join("ggez.wav");
        // 8-bit mono with an odd sample count leaves an odd-sized data chunk
        let samples: Vec<f32> = (0..1001).map(|i| (i as f32 * 0.05).sin() * 0.5).collect();
        let config = AudioExportConfig::Wav(WavAudioWriterConfig {
            sample_rate: 48_000,
            channels: 1,
            bit_depth: BitDepth::BitPerSample(BitPerSample::B8),
        });
        export(&path, config, &ggez_with_cover(), &samples);

        let bytes = std::fs::read(&path).unwrap();
        let chunks = riff_chunks(&bytes);
        let ids: Vec<&[u8; 4]> = chunks.iter().map(|(id, _)| id).collect();
        assert_eq!(ids, [b"fmt ", b"data", b"LIST", b"id3 "]);

        let info = chunks[2].1;
        assert_eq!(&info[..4], b"INFO");
        for needle in [
            "INAM",
            "GGEZ\0",
            "IART",
            "Kaien; Sugar; M. Sasuke\0",
            "ICMT",
            "Hey don't say that\0",
            "ICRD",
            "2025-04-01\0",
        ] {
            assert!(contains(info, needle.as_bytes()), "{needle}");
        }
        // INFO has no picture field; the cover rides in the ID3 chunk
        let id3 = chunks[3].1;
        assert_eq!(&id3[..3], b"ID3");
        assert!(contains(id3, b"APIC"));
        assert!(contains(id3, test_cover().bytes()));

        // Readers that stop at the data chunk still decode every sample
        let decoder = rodio::Decoder::new(BufReader::new(File::open(&path).unwrap())).unwrap();
        assert_eq!(decoder.count(), samples.len());
    }

    #[test]
    fn wav_without_metadata_is_untouched() {
        let dir = tempfile::tempdir().unwrap();
        let path = dir.path().join("blank.wav");
        let config = AudioExportConfig::Wav(WavAudioWriterConfig {
            sample_rate: 48_000,
            channels: 2,
            bit_depth: BitDepth::BitPerSample(BitPerSample::B16),
        });
        export(&path, config, &AudioMetadata::default(), &stereo_sine(100));

        let bytes = std::fs::read(&path).unwrap();
        let ids: Vec<[u8; 4]> = riff_chunks(&bytes).into_iter().map(|(id, _)| id).collect();
        assert_eq!(ids, [*b"fmt ", *b"data"]);
    }
}
