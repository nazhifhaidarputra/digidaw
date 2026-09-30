use std::{
    collections::hash_map::RandomState,
    fs::File,
    hash::{BuildHasher, Hasher},
    io::{BufWriter, Write},
    path::Path,
};

use ogg::writing::{PacketWriteEndInfo, PacketWriter};
use opus::{Application, Bitrate, Channels, Encoder};

use crate::audio::writer::{
    AudioFileFormat, AudioWriteError, AudioWriter, BitPerSecond, metadata::AudioMetadata,
};

/// Opus always operates on 48 kHz audio for fullband encoding, and granule
/// positions in an Ogg Opus stream are always counted at this rate.
pub const OPUS_SAMPLE_RATE: u32 = 48_000;
/// 20 ms per packet, the libopus recommended frame duration for music
const FRAME_SIZE: usize = 960;
/// Recommended upper bound for a single encoded Opus packet
const MAX_PACKET_SIZE: usize = 4000;

#[derive(Clone, Copy, Debug)]
pub struct OggOpusAudioWriterConfig {
    pub channels: u8,
    pub bitrate: BitPerSecond,
}

/// A struct which handles audio encoding for OGG Opus.
/// It utilizes the [`opus`] crate, a safe binding of the libopus library,
/// and muxes the encoded packets into an Ogg container (RFC 7845).
///
/// Input must already be rendered at [`OPUS_SAMPLE_RATE`].
pub struct OggOpusAudioWriter {
    encoder: Encoder,
    packet_writer: Option<PacketWriter<'static, BufWriter<File>>>,
    serial: u32,
    channels: usize,
    pre_skip: u16,
    /// Interleaved samples waiting for a full frame
    pending: Vec<f32>,
    packet: Vec<u8>,
    frame_len: usize,
    /// Per-channel samples fed by the caller
    input_samples: u64,
    /// Per-channel samples encoded so far, including pre-skip and padding
    encoded_samples: u64,
}

impl OggOpusAudioWriter {
    pub fn try_new(
        path: &Path,
        config: OggOpusAudioWriterConfig,
        metadata: &AudioMetadata,
    ) -> Result<Self, AudioWriteError> {
        let opus_channels = match config.channels {
            1 => Channels::Mono,
            2 => Channels::Stereo,
            n => {
                return Err(AudioWriteError::unsupported(
                    AudioFileFormat::OggOpus,
                    format!("{n} channels; use mono or stereo"),
                ));
            }
        };

        let mut encoder = Encoder::new(OPUS_SAMPLE_RATE, opus_channels, Application::Audio)
            .map_err(opus_error)?;
        let bits_per_second = config.bitrate.as_kbps() * 1000;
        encoder
            .set_bitrate(Bitrate::Bits(bits_per_second as i32))
            .map_err(opus_error)?;
        let lookahead = encoder.get_lookahead().map_err(opus_error)?;
        let pre_skip = u16::try_from(lookahead)
            .map_err(|e| AudioWriteError::encoder(AudioFileFormat::OggOpus, e))?;

        let channels = usize::from(config.channels);
        let frame_len = FRAME_SIZE * channels;
        let serial = random_serial();
        let mut packet_writer = PacketWriter::new(BufWriter::new(File::create(path)?));

        // Each header packet must sit on its own page with granule position 0
        packet_writer.write_packet(
            opus_head(config.channels, pre_skip),
            serial,
            PacketWriteEndInfo::EndPage,
            0,
        )?;
        packet_writer.write_packet(opus_tags(metadata), serial, PacketWriteEndInfo::EndPage, 0)?;

        Ok(Self {
            encoder,
            packet_writer: Some(packet_writer),
            serial,
            channels,
            pre_skip,
            pending: Vec::with_capacity(frame_len),
            packet: vec![0; MAX_PACKET_SIZE],
            frame_len,
            input_samples: 0,
            encoded_samples: 0,
        })
    }

    /// Encodes one full frame from `frame` and appends it to the Ogg stream.
    /// `end_granule` marks the final packet and trims the decoded output to it.
    fn encode_frame(
        encoder: &mut Encoder,
        packet: &mut [u8],
        packet_writer: &mut PacketWriter<'static, BufWriter<File>>,
        serial: u32,
        encoded_samples: &mut u64,
        frame: &[f32],
        end_granule: Option<u64>,
    ) -> Result<(), AudioWriteError> {
        let len = encoder.encode_float(frame, packet).map_err(opus_error)?;
        *encoded_samples += FRAME_SIZE as u64;

        let (end_info, granule) = match end_granule {
            Some(granule) => (PacketWriteEndInfo::EndStream, granule),
            None => (PacketWriteEndInfo::NormalPacket, *encoded_samples),
        };
        packet_writer.write_packet(packet[..len].to_vec(), serial, end_info, granule)?;
        Ok(())
    }
}

impl AudioWriter for OggOpusAudioWriter {
    fn write(&mut self, samples: &[f32]) -> Result<(), AudioWriteError> {
        let packet_writer = self
            .packet_writer
            .as_mut()
            .ok_or(AudioWriteError::Finalized)?;
        self.input_samples += (samples.len() / self.channels) as u64;

        let mut remaining = samples;
        while !remaining.is_empty() {
            let space = self.frame_len - self.pending.len();
            let (head, tail) = remaining.split_at(space.min(remaining.len()));
            self.pending.extend_from_slice(head);
            remaining = tail;

            if self.pending.len() == self.frame_len {
                Self::encode_frame(
                    &mut self.encoder,
                    &mut self.packet,
                    packet_writer,
                    self.serial,
                    &mut self.encoded_samples,
                    &self.pending,
                    None,
                )?;
                self.pending.clear();
            }
        }
        Ok(())
    }

    fn finalize(&mut self) -> Result<(), AudioWriteError> {
        let Some(mut packet_writer) = self.packet_writer.take() else {
            return Ok(());
        };

        // Pad with silence covering the encoder lookahead, so the tail of the input
        // is fully flushed, then round up to whole frames. At least one packet is
        // always emitted so the stream can be terminated.
        let pending_samples = self.pending.len() / self.channels;
        let frames = (pending_samples + usize::from(self.pre_skip))
            .div_ceil(FRAME_SIZE)
            .max(1);
        self.pending.resize(frames * self.frame_len, 0.0);
        // Decoders discard `pre_skip` samples up front and trim the padding at the end
        let end_granule = u64::from(self.pre_skip) + self.input_samples;

        for (index, frame) in self.pending.chunks_exact(self.frame_len).enumerate() {
            let is_last = index + 1 == frames;
            Self::encode_frame(
                &mut self.encoder,
                &mut self.packet,
                &mut packet_writer,
                self.serial,
                &mut self.encoded_samples,
                frame,
                is_last.then_some(end_granule),
            )?;
        }
        self.pending.clear();

        packet_writer.into_inner().flush()?;
        Ok(())
    }
}

/// Identification header (RFC 7845, section 5.1), channel mapping family 0
fn opus_head(channels: u8, pre_skip: u16) -> Vec<u8> {
    let mut head = Vec::with_capacity(19);
    head.extend_from_slice(b"OpusHead");
    head.push(1); // version
    head.push(channels);
    head.extend_from_slice(&pre_skip.to_le_bytes());
    head.extend_from_slice(&OPUS_SAMPLE_RATE.to_le_bytes()); // input sample rate
    head.extend_from_slice(&0_i16.to_le_bytes()); // output gain
    head.push(0); // mapping family: mono/stereo
    head
}

/// Comment header (RFC 7845, section 5.2) with the libopus vendor string.
/// The header is mandatory, so blank metadata still yields zero comments.
fn opus_tags(metadata: &AudioMetadata) -> Vec<u8> {
    let mut tags = b"OpusTags".to_vec();
    tags.extend_from_slice(&metadata.vorbis_comment_with_cover(opus::version()));
    tags
}

/// Ogg logical streams should carry a random serial number
fn random_serial() -> u32 {
    let hash = RandomState::new().build_hasher().finish();
    (hash >> 32) as u32
}

fn opus_error(error: opus::Error) -> AudioWriteError {
    AudioWriteError::encoder(AudioFileFormat::OggOpus, error)
}

#[cfg(test)]
#[allow(
    clippy::unwrap_used,
    reason = "writer fixtures assert setup and decoded output"
)]
mod tests {
    use super::*;
    use ogg::reading::PacketReader;
    use std::io::BufReader;

    #[test]
    fn ogg_opus_stream_has_headers_and_trims_to_input_length() {
        let dir = tempfile::tempdir().unwrap();
        let path = dir.path().join("out.ogg");
        let frames = 48_000 + 123;
        let input: Vec<f32> = (0..frames * 2)
            .map(|i| ((i / 2) as f32 * 0.02).sin() * 0.5)
            .collect();

        let mut writer = OggOpusAudioWriter::try_new(
            &path,
            OggOpusAudioWriterConfig {
                channels: 2,
                bitrate: BitPerSecond::Kbps192,
            },
            &AudioMetadata::default(),
        )
        .unwrap();
        for chunk in input.chunks(4096 * 2) {
            writer.write(chunk).unwrap();
        }
        writer.finalize().unwrap();
        let pre_skip = writer.pre_skip;

        let mut reader = PacketReader::new(BufReader::new(File::open(&path).unwrap()));
        let head = reader.read_packet_expected().unwrap();
        assert_eq!(&head.data[..8], b"OpusHead");
        assert_eq!(head.data[9], 2);
        assert_eq!(u16::from_le_bytes([head.data[10], head.data[11]]), pre_skip);
        let tags = reader.read_packet_expected().unwrap();
        assert_eq!(&tags.data[..8], b"OpusTags");

        let mut decoder = opus::Decoder::new(OPUS_SAMPLE_RATE, Channels::Stereo).unwrap();
        let mut out = vec![0.0; 5760 * 2];
        let mut decoded = 0;
        let mut last_granule = 0;
        let mut saw_end = false;
        while let Some(packet) = reader.read_packet().unwrap() {
            decoded += decoder.decode_float(&packet.data, &mut out, false).unwrap();
            last_granule = packet.absgp_page();
            saw_end = packet.last_in_stream();
        }

        assert!(saw_end, "final packet must end the logical stream");
        assert_eq!(last_granule, u64::from(pre_skip) + frames as u64);
        assert!(
            decoded as u64 >= last_granule,
            "padding must cover pre-skip"
        );
    }

    #[test]
    fn ogg_opus_rejects_surround_layouts() {
        let dir = tempfile::tempdir().unwrap();
        let result = OggOpusAudioWriter::try_new(
            &dir.path().join("out.ogg"),
            OggOpusAudioWriterConfig {
                channels: 6,
                bitrate: BitPerSecond::Kbps256,
            },
            &AudioMetadata::default(),
        );
        assert!(matches!(
            result,
            Err(AudioWriteError::UnsupportedConfig { .. })
        ));
    }
}
