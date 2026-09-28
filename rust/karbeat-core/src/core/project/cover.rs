//! Project cover art: the persisted file reference and the decoded image header.

use std::{
    hash::{DefaultHasher, Hasher},
    path::{Path, PathBuf},
};

use serde::{Deserialize, Serialize};
use thiserror::Error;

/// Largest cover file accepted. FLAC picture blocks cap out at 16 MiB.
pub const MAX_COVER_BYTES: usize = 8 * 1024 * 1024;
/// Longest edge accepted when encoding a cropped cover.
pub const MAX_COVER_EDGE: u32 = 4096;
/// JPEG quality used for encoded covers.
const COVER_JPEG_QUALITY: u8 = 90;

/// Reference to the project's square cover image.
#[derive(Serialize, Deserialize, Clone, Debug, PartialEq, Eq)]
pub struct CoverImage {
    /// File the cover is read from. Absolute while a project is open; relative to
    /// the archive root (`cover/…`) inside a saved project.
    pub path: PathBuf,
    /// Absolute path of the image on the machine that saved the project. When it
    /// still exists at load time the project links to it instead of the embedded copy.
    #[serde(default)]
    pub linked_path: Option<PathBuf>,
}

impl CoverImage {
    /// A cover read straight from `path`, with no link recorded yet.
    pub fn new(path: impl Into<PathBuf>) -> Self {
        Self {
            path: path.into(),
            linked_path: None,
        }
    }

    /// Reads and validates the image this cover points at.
    pub fn load(&self) -> Result<CoverArt, CoverArtError> {
        CoverArt::read(&self.path)
    }
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum CoverFormat {
    Jpeg,
    Png,
}

impl CoverFormat {
    pub const fn mime_type(self) -> &'static str {
        match self {
            Self::Jpeg => "image/jpeg",
            Self::Png => "image/png",
        }
    }

    pub const fn extension(self) -> &'static str {
        match self {
            Self::Jpeg => "jpg",
            Self::Png => "png",
        }
    }
}

#[derive(Debug, Error)]
pub enum CoverArtError {
    #[error("cover image could not be read: {0}")]
    Io(#[from] std::io::Error),
    #[error("cover image must be a JPEG or PNG file")]
    UnsupportedFormat,
    #[error("cover image is corrupt or truncated")]
    Malformed,
    #[error("cover image must be square, but it is {width}×{height}")]
    NotSquare { width: u32, height: u32 },
    #[error("cover image is larger than {} MiB", MAX_COVER_BYTES / (1024 * 1024))]
    TooLarge,
    #[error("cover crop must be a {size}×{size} RGBA buffer between 1 and {MAX_COVER_EDGE} pixels")]
    InvalidPixels { size: u32 },
    #[error("cover image could not be encoded: {0}")]
    Encode(String),
    #[error("app cache directory is unavailable for cover images")]
    NoCacheDirectory,
}

/// A validated square cover image and the header details tag formats need.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct CoverArt {
    format: CoverFormat,
    width: u32,
    height: u32,
    /// Bits per pixel, as FLAC picture blocks record it
    color_depth: u32,
    bytes: Vec<u8>,
}

impl CoverArt {
    pub fn read(path: &Path) -> Result<Self, CoverArtError> {
        if std::fs::metadata(path)?.len() > MAX_COVER_BYTES as u64 {
            return Err(CoverArtError::TooLarge);
        }
        Self::from_bytes(std::fs::read(path)?)
    }

    /// Identifies a JPEG or PNG image from its header and checks it is square.
    pub fn from_bytes(bytes: Vec<u8>) -> Result<Self, CoverArtError> {
        if bytes.len() > MAX_COVER_BYTES {
            return Err(CoverArtError::TooLarge);
        }
        let (format, header) = if bytes.starts_with(&[0xFF, 0xD8]) {
            (CoverFormat::Jpeg, jpeg_header(&bytes))
        } else if bytes.starts_with(PNG_SIGNATURE) {
            (CoverFormat::Png, png_header(&bytes))
        } else {
            return Err(CoverArtError::UnsupportedFormat);
        };
        let (width, height, color_depth) = header.ok_or(CoverArtError::Malformed)?;

        if width == 0 || height == 0 {
            return Err(CoverArtError::Malformed);
        }
        if width != height {
            return Err(CoverArtError::NotSquare { width, height });
        }
        Ok(Self {
            format,
            width,
            height,
            color_depth,
            bytes,
        })
    }

    /// Encodes an opaque square RGBA crop as a JPEG cover.
    pub fn encode_rgba(size: u32, rgba: &[u8]) -> Result<Self, CoverArtError> {
        let edge = u16::try_from(size)
            .ok()
            .filter(|edge| *edge > 0 && u32::from(*edge) <= MAX_COVER_EDGE)
            .ok_or(CoverArtError::InvalidPixels { size })?;
        if rgba.len() != usize::from(edge) * usize::from(edge) * 4 {
            return Err(CoverArtError::InvalidPixels { size });
        }

        let mut jpeg = Vec::new();
        jpeg_encoder::Encoder::new(&mut jpeg, COVER_JPEG_QUALITY)
            .encode(rgba, edge, edge, jpeg_encoder::ColorType::Rgba)
            .map_err(|error| CoverArtError::Encode(error.to_string()))?;
        Self::from_bytes(jpeg)
    }

    /// Writes the encoded cover into the persistent app cache and returns its path.
    ///
    /// Files are named by content, so saving the same crop twice reuses one file,
    /// and the path stays valid across sessions for projects that link to it.
    pub fn store_in_cache(&self) -> Result<PathBuf, CoverArtError> {
        let directory = crate::core::file_manager::app_cache_dir()
            .ok_or(CoverArtError::NoCacheDirectory)?
            .join("covers");
        std::fs::create_dir_all(&directory)?;

        let mut hasher = DefaultHasher::new();
        hasher.write(&self.bytes);
        let path = directory.join(format!(
            "{:016x}.{}",
            hasher.finish(),
            self.format.extension()
        ));
        if !path.is_file() {
            // Write beside the target first so a crash never leaves a partial cover
            let temporary = path.with_extension("partial");
            std::fs::write(&temporary, &self.bytes)?;
            std::fs::rename(&temporary, &path)?;
        }
        Ok(path)
    }

    pub const fn format(&self) -> CoverFormat {
        self.format
    }

    pub const fn width(&self) -> u32 {
        self.width
    }

    pub const fn height(&self) -> u32 {
        self.height
    }

    pub const fn color_depth(&self) -> u32 {
        self.color_depth
    }

    pub fn bytes(&self) -> &[u8] {
        &self.bytes
    }
}

const PNG_SIGNATURE: &[u8] = b"\x89PNG\r\n\x1a\n";

fn be_u16(bytes: &[u8], at: usize) -> Option<u32> {
    let pair = bytes.get(at..at.checked_add(2)?)?.try_into().ok()?;
    Some(u32::from(u16::from_be_bytes(pair)))
}

fn be_u32(bytes: &[u8], at: usize) -> Option<u32> {
    let quad = bytes.get(at..at.checked_add(4)?)?.try_into().ok()?;
    Some(u32::from_be_bytes(quad))
}

/// Width, height, and bits per pixel from the first start-of-frame segment
fn jpeg_header(bytes: &[u8]) -> Option<(u32, u32, u32)> {
    let mut at = 2;
    loop {
        if *bytes.get(at)? != 0xFF {
            return None;
        }
        let marker = *bytes.get(at + 1)?;
        match marker {
            // Fill byte before a marker
            0xFF => at += 1,
            // Standalone markers carry no length
            0x01 | 0xD0..=0xD8 => at += 2,
            // Image data or end of image before any frame header
            0xD9 | 0xDA => return None,
            _ => {
                let length = usize::try_from(be_u16(bytes, at + 2)?).ok()?;
                // SOF0..SOF15, excluding DHT (C4), JPG (C8), and DAC (CC)
                if (0xC0..=0xCF).contains(&marker) && !matches!(marker, 0xC4 | 0xC8 | 0xCC) {
                    let precision = u32::from(*bytes.get(at + 4)?);
                    let height = be_u16(bytes, at + 5)?;
                    let width = be_u16(bytes, at + 7)?;
                    let components = u32::from(*bytes.get(at + 9)?);
                    return Some((width, height, precision * components));
                }
                at = at.checked_add(2 + length)?;
            }
        }
    }
}

/// Width, height, and bits per pixel from the IHDR chunk
fn png_header(bytes: &[u8]) -> Option<(u32, u32, u32)> {
    if bytes.get(12..16)? != b"IHDR" {
        return None;
    }
    let width = be_u32(bytes, 16)?;
    let height = be_u32(bytes, 20)?;
    let bit_depth = u32::from(*bytes.get(24)?);
    let channels = match *bytes.get(25)? {
        0 | 3 => 1, // grayscale, indexed
        2 => 3,     // RGB
        4 => 2,     // grayscale + alpha
        6 => 4,     // RGBA
        _ => return None,
    };
    Some((width, height, bit_depth * channels))
}

#[cfg(test)]
#[allow(
    clippy::unwrap_used,
    clippy::indexing_slicing,
    reason = "cover fixtures assert encoded headers"
)]
mod tests {
    use super::*;

    fn solid(size: u32) -> Vec<u8> {
        [200_u8, 40, 90, 255].repeat((size * size) as usize)
    }

    #[test]
    fn encoded_rgba_is_a_square_jpeg() {
        let cover = CoverArt::encode_rgba(32, &solid(32)).unwrap();
        assert_eq!(cover.format(), CoverFormat::Jpeg);
        assert_eq!((cover.width(), cover.height()), (32, 32));
        assert_eq!(cover.color_depth(), 24);
        assert_eq!(&cover.bytes()[..2], [0xFF, 0xD8]);
    }

    #[test]
    fn rejects_mismatched_pixel_buffers() {
        assert!(matches!(
            CoverArt::encode_rgba(32, &solid(31)),
            Err(CoverArtError::InvalidPixels { .. })
        ));
        assert!(matches!(
            CoverArt::encode_rgba(0, &[]),
            Err(CoverArtError::InvalidPixels { .. })
        ));
    }

    #[test]
    fn reads_png_headers_and_rejects_non_square_images() {
        let mut png = PNG_SIGNATURE.to_vec();
        png.extend_from_slice(&13_u32.to_be_bytes());
        png.extend_from_slice(b"IHDR");
        png.extend_from_slice(&640_u32.to_be_bytes());
        png.extend_from_slice(&480_u32.to_be_bytes());
        png.extend_from_slice(&[8, 6, 0, 0, 0]);
        assert!(matches!(
            CoverArt::from_bytes(png),
            Err(CoverArtError::NotSquare {
                width: 640,
                height: 480
            })
        ));
    }

    #[test]
    fn rejects_unknown_and_truncated_data() {
        assert!(matches!(
            CoverArt::from_bytes(b"GIF89a".to_vec()),
            Err(CoverArtError::UnsupportedFormat)
        ));
        assert!(matches!(
            CoverArt::from_bytes(vec![0xFF, 0xD8, 0xFF, 0xE0, 0x00]),
            Err(CoverArtError::Malformed)
        ));
    }
}
