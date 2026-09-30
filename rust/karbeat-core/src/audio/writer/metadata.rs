use std::borrow::Cow;

use crate::core::project::{CoverArt, CoverArtError, CoverImage, ProjectMetadata};

/// Joins artists in tag formats that hold a single artist string (ID3v2.3,
/// RIFF INFO). Windows and most taggers read `;` as a multi-value separator.
pub const ARTIST_SEPARATOR: &str = "; ";

/// Ordered list of credited artists. Blank names are ignored.
#[derive(Clone, Debug, Default, PartialEq, Eq)]
pub struct Artists(Vec<String>);

impl Artists {
    pub fn new() -> Self {
        Self::default()
    }

    /// Appends an artist to the credits.
    #[allow(
        clippy::should_implement_trait,
        reason = "builder-style credit list, not arithmetic"
    )]
    #[must_use]
    pub fn add(mut self, name: impl Into<String>) -> Self {
        let name = name.into();
        let name = name.trim();
        if !name.is_empty() {
            self.0.push(name.to_owned());
        }
        self
    }

    /// Splits a `;`-separated credit line, the form project authors are entered in.
    pub fn parse(credits: &str) -> Self {
        credits.split(';').collect()
    }

    pub fn is_empty(&self) -> bool {
        self.0.is_empty()
    }

    pub fn iter(&self) -> impl Iterator<Item = &str> {
        self.0.iter().map(String::as_str)
    }

    /// All artists as one string, for formats without multi-value fields.
    pub fn joined(&self) -> String {
        self.0.join(ARTIST_SEPARATOR)
    }
}

impl<S: Into<String>> FromIterator<S> for Artists {
    fn from_iter<I: IntoIterator<Item = S>>(names: I) -> Self {
        names.into_iter().fold(Self::new(), Self::add)
    }
}

/// Descriptive tags embedded into exported audio files.
///
/// Blank fields are left out of every tag format, and a file gets no tag
/// block at all when every field is blank and there is no cover.
#[derive(Clone, Debug, Default, PartialEq, Eq)]
pub struct AudioMetadata {
    pub title: String,
    pub artists: Artists,
    pub genre: String,
    pub description: String,
    /// Recording date as `YYYY-MM-DD`
    pub date: String,
    pub cover: Option<CoverArt>,
}

impl AudioMetadata {
    /// Tags for a project export. Reads the cover image from disk, if set.
    pub fn from_project(metadata: &ProjectMetadata) -> Result<Self, CoverArtError> {
        Ok(Self {
            title: metadata.name.clone(),
            artists: Artists::parse(&metadata.author),
            genre: metadata.genre.clone(),
            description: metadata.description.clone(),
            date: metadata.created_at.strftime("%Y-%m-%d").to_string(),
            cover: metadata.cover.as_ref().map(CoverImage::load).transpose()?,
        })
    }
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
enum TagField {
    Title,
    Artist,
    Genre,
    Description,
    Date,
}

impl TagField {
    const fn vorbis_key(self) -> &'static str {
        match self {
            Self::Title => "TITLE",
            Self::Artist => "ARTIST",
            Self::Genre => "GENRE",
            // DESCRIPTION is the Xiph field that ffmpeg and TagLib read as the comment
            Self::Description => "DESCRIPTION",
            Self::Date => "DATE",
        }
    }

    const fn riff_info_id(self) -> &'static [u8; 4] {
        match self {
            Self::Title => b"INAM",
            Self::Artist => b"IART",
            Self::Genre => b"IGNR",
            Self::Description => b"ICMT",
            Self::Date => b"ICRD",
        }
    }
}

/// ID3 and FLAC picture type for the front cover
const FRONT_COVER: u8 = 3;

impl AudioMetadata {
    /// Non-blank text fields, trimmed, in a stable order. Artists are joined.
    fn text_fields(&self) -> impl Iterator<Item = (TagField, Cow<'_, str>)> {
        let artists = (!self.artists.is_empty()).then(|| Cow::Owned(self.artists.joined()));
        [
            (TagField::Title, Some(Cow::Borrowed(self.title.trim()))),
            (TagField::Artist, artists),
            (TagField::Genre, Some(Cow::Borrowed(self.genre.trim()))),
            (
                TagField::Description,
                Some(Cow::Borrowed(self.description.trim())),
            ),
            (TagField::Date, Some(Cow::Borrowed(self.date.trim()))),
        ]
        .into_iter()
        .filter_map(|(field, value)| Some((field, value?)))
        .filter(|(_, value)| !value.is_empty())
    }

    pub fn has_text(&self) -> bool {
        self.text_fields().next().is_some()
    }

    pub fn is_empty(&self) -> bool {
        !self.has_text() && self.cover.is_none()
    }

    /// Vorbis comment payload (no framing bit) with text fields only, for FLAC,
    /// which carries the cover in its own PICTURE block. One `ARTIST` per artist.
    pub(crate) fn vorbis_comment(&self, vendor: &str) -> Vec<u8> {
        self.vorbis_comment_inner(vendor, false)
    }

    /// Vorbis comment payload for Ogg, carrying the cover as a base64
    /// `METADATA_BLOCK_PICTURE`. Always valid, with zero comments when empty.
    pub(crate) fn vorbis_comment_with_cover(&self, vendor: &str) -> Vec<u8> {
        self.vorbis_comment_inner(vendor, true)
    }

    fn vorbis_comment_inner(&self, vendor: &str, embed_cover: bool) -> Vec<u8> {
        let mut comments = Vec::new();
        for (field, value) in self.text_fields() {
            if field == TagField::Artist {
                comments.extend(self.artists.iter().map(|artist| format!("ARTIST={artist}")));
            } else {
                comments.push(format!("{}={value}", field.vorbis_key()));
            }
        }
        if embed_cover && let Some(picture) = self.flac_picture_block() {
            comments.push(format!("METADATA_BLOCK_PICTURE={}", base64(&picture)));
        }

        let mut out = Vec::new();
        put_u32_le(&mut out, len_u32(vendor.len()));
        out.extend_from_slice(vendor.as_bytes());
        put_u32_le(&mut out, len_u32(comments.len()));
        for comment in &comments {
            put_u32_le(&mut out, len_u32(comment.len()));
            out.extend_from_slice(comment.as_bytes());
        }
        out
    }

    /// FLAC PICTURE block payload (without the block header) for the cover,
    /// also the binary form behind Ogg's `METADATA_BLOCK_PICTURE`.
    pub(crate) fn flac_picture_block(&self) -> Option<Vec<u8>> {
        let cover = self.cover.as_ref()?;
        let mime = cover.format().mime_type();
        let mut out = Vec::with_capacity(32 + mime.len() + cover.bytes().len());
        out.extend_from_slice(&u32::from(FRONT_COVER).to_be_bytes());
        out.extend_from_slice(&len_u32(mime.len()).to_be_bytes());
        out.extend_from_slice(mime.as_bytes());
        out.extend_from_slice(&0_u32.to_be_bytes()); // empty description
        out.extend_from_slice(&cover.width().to_be_bytes());
        out.extend_from_slice(&cover.height().to_be_bytes());
        out.extend_from_slice(&cover.color_depth().to_be_bytes());
        out.extend_from_slice(&0_u32.to_be_bytes()); // not an indexed-color image
        out.extend_from_slice(&len_u32(cover.bytes().len()).to_be_bytes());
        out.extend_from_slice(cover.bytes());
        Some(out)
    }

    /// ID3v2.3 tag, the version with the widest player support.
    /// Returns `None` when there is no text and no cover.
    pub(crate) fn id3v2_tag(&self) -> Option<Vec<u8>> {
        let mut frames = Vec::new();
        for (field, value) in self.text_fields() {
            match field {
                TagField::Title => id3_text_frame(&mut frames, b"TIT2", &value),
                TagField::Artist => id3_text_frame(&mut frames, b"TPE1", &value),
                TagField::Genre => id3_text_frame(&mut frames, b"TCON", &value),
                TagField::Description => id3_comment_frame(&mut frames, &value),
                // v2.3 only has a four-digit year frame
                TagField::Date => {
                    if let Some(year) = value
                        .get(..4)
                        .filter(|y| y.bytes().all(|b| b.is_ascii_digit()))
                    {
                        id3_text_frame(&mut frames, b"TYER", year);
                    }
                }
            }
        }
        if let Some(cover) = &self.cover {
            id3_picture_frame(&mut frames, cover);
        }
        if frames.is_empty() {
            return None;
        }

        let mut tag = Vec::with_capacity(10 + frames.len());
        tag.extend_from_slice(b"ID3");
        tag.extend_from_slice(&[3, 0, 0]); // v2.3.0, no flags
        tag.extend_from_slice(&syncsafe(len_u32(frames.len())));
        tag.extend_from_slice(&frames);
        Some(tag)
    }

    /// RIFF `LIST` chunk of type `INFO` for WAV files. INFO has no picture
    /// field, so the cover travels in the WAV's ID3 chunk instead.
    /// Returns `None` when every text field is blank.
    pub(crate) fn riff_info_chunk(&self) -> Option<Vec<u8>> {
        let mut body = b"INFO".to_vec();
        for (field, value) in self.text_fields() {
            // INFO strings are NUL-terminated
            let mut data = value.as_bytes().to_vec();
            data.push(0);
            put_riff_chunk(&mut body, field.riff_info_id(), &data);
        }
        if body.len() == 4 {
            return None;
        }

        let mut chunk = Vec::with_capacity(8 + body.len());
        put_riff_chunk(&mut chunk, b"LIST", &body);
        Some(chunk)
    }
}

/// Appends a RIFF chunk, padding its data to an even length
pub(crate) fn put_riff_chunk(out: &mut Vec<u8>, id: &[u8; 4], data: &[u8]) {
    out.extend_from_slice(id);
    put_u32_le(out, len_u32(data.len()));
    out.extend_from_slice(data);
    if data.len() % 2 == 1 {
        out.push(0);
    }
}

fn id3_text_frame(out: &mut Vec<u8>, id: &[u8; 4], text: &str) {
    let mut body = Vec::new();
    let encoding = id3_encoding(text);
    body.push(encoding);
    id3_string(&mut body, encoding, text);
    id3_frame(out, id, &body);
}

fn id3_comment_frame(out: &mut Vec<u8>, text: &str) {
    let mut body = Vec::new();
    let encoding = id3_encoding(text);
    body.push(encoding);
    body.extend_from_slice(b"eng");
    // Empty short description, terminated in the frame's encoding
    id3_string(&mut body, encoding, "");
    body.extend_from_slice(if encoding == ID3_LATIN1 { &[0] } else { &[0, 0] });
    id3_string(&mut body, encoding, text);
    id3_frame(out, b"COMM", &body);
}

fn id3_picture_frame(out: &mut Vec<u8>, cover: &CoverArt) {
    let mime = cover.format().mime_type();
    let mut body = Vec::with_capacity(mime.len() + 4 + cover.bytes().len());
    body.push(ID3_LATIN1);
    body.extend_from_slice(mime.as_bytes());
    body.push(0);
    body.push(FRONT_COVER);
    body.push(0); // empty Latin-1 description
    body.extend_from_slice(cover.bytes());
    id3_frame(out, b"APIC", &body);
}

fn id3_frame(out: &mut Vec<u8>, id: &[u8; 4], body: &[u8]) {
    out.extend_from_slice(id);
    // v2.3 frame sizes are plain big-endian, unlike the syncsafe tag size
    out.extend_from_slice(&len_u32(body.len()).to_be_bytes());
    out.extend_from_slice(&[0, 0]); // no frame flags
    out.extend_from_slice(body);
}

const ID3_LATIN1: u8 = 0;
const ID3_UTF16: u8 = 1;

/// Plain ASCII is stored as Latin-1 for the broadest reader support,
/// anything else as UTF-16 with a byte order mark.
fn id3_encoding(text: &str) -> u8 {
    if text.is_ascii() { ID3_LATIN1 } else { ID3_UTF16 }
}

fn id3_string(out: &mut Vec<u8>, encoding: u8, text: &str) {
    if encoding == ID3_LATIN1 {
        out.extend_from_slice(text.as_bytes());
    } else {
        out.extend_from_slice(&[0xFF, 0xFE]);
        for unit in text.encode_utf16() {
            out.extend_from_slice(&unit.to_le_bytes());
        }
    }
}

fn syncsafe(value: u32) -> [u8; 4] {
    [
        ((value >> 21) & 0x7F) as u8,
        ((value >> 14) & 0x7F) as u8,
        ((value >> 7) & 0x7F) as u8,
        (value & 0x7F) as u8,
    ]
}

/// Standard base64 with padding, as `METADATA_BLOCK_PICTURE` requires
fn base64(bytes: &[u8]) -> String {
    const ALPHABET: &[u8; 64] = b"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
    let symbol = |index: u32| char::from(ALPHABET[(index & 0x3F) as usize]);

    let mut out = String::with_capacity(bytes.len().div_ceil(3) * 4);
    for chunk in bytes.chunks(3) {
        let [a, b, c] = [0, 1, 2].map(|i| chunk.get(i).copied().map_or(0, u32::from));
        let triple = (a << 16) | (b << 8) | c;
        out.push(symbol(triple >> 18));
        out.push(symbol(triple >> 12));
        out.push(if chunk.len() > 1 { symbol(triple >> 6) } else { '=' });
        out.push(if chunk.len() > 2 { symbol(triple) } else { '=' });
    }
    out
}

fn put_u32_le(out: &mut Vec<u8>, value: u32) {
    out.extend_from_slice(&value.to_le_bytes());
}

/// Tag payloads are bounded by metadata validation and the 8 MiB cover limit
fn len_u32(len: usize) -> u32 {
    u32::try_from(len).unwrap_or(u32::MAX)
}

/// Shared tag fixture for writer tests
#[cfg(test)]
pub(crate) fn ggez() -> AudioMetadata {
    AudioMetadata {
        title: "GGEZ".into(),
        artists: Artists::new().add("Kaien").add("Sugar").add("M. Sasuke"),
        genre: "Slop Pop".into(),
        description: "Hey don't say that".into(),
        date: "2025-04-01".into(),
        cover: None,
    }
}

/// A small solid-color square JPEG cover for writer tests
#[cfg(test)]
#[allow(clippy::unwrap_used, reason = "fixed fixture input always encodes")]
pub(crate) fn test_cover() -> CoverArt {
    CoverArt::encode_rgba(16, &[255_u8, 0, 128, 255].repeat(16 * 16)).unwrap()
}

#[cfg(test)]
#[allow(
    clippy::unwrap_used,
    clippy::indexing_slicing,
    reason = "tag fixtures assert encoded layouts"
)]
mod tests {
    use super::*;

    fn find(haystack: &[u8], needle: &[u8]) -> usize {
        haystack
            .windows(needle.len())
            .position(|w| w == needle)
            .unwrap()
    }

    #[test]
    fn artists_skip_blank_names_and_parse_credit_lines() {
        let artists = Artists::parse(" Kaien; Sugar ;;M. Sasuke; ");
        assert_eq!(
            artists,
            Artists::new().add("Kaien").add("Sugar").add(" ").add("M. Sasuke")
        );
        assert_eq!(artists.joined(), "Kaien; Sugar; M. Sasuke");
        assert!(Artists::parse(" ; ").is_empty());
    }

    #[test]
    fn blank_metadata_produces_no_tags() {
        let blank = AudioMetadata {
            title: " ".into(),
            ..AudioMetadata::default()
        };
        assert!(blank.is_empty());
        assert_eq!(blank.id3v2_tag(), None);
        assert_eq!(blank.riff_info_chunk(), None);
        assert_eq!(blank.flac_picture_block(), None);
        // vendor length + "v" + zero comments
        assert_eq!(
            blank.vorbis_comment_with_cover("v"),
            [1, 0, 0, 0, b'v', 0, 0, 0, 0]
        );
    }

    #[test]
    fn vorbis_comment_lists_each_artist() {
        let payload = ggez().vorbis_comment("v");
        let text = String::from_utf8_lossy(&payload);
        assert_eq!(payload[5], 7, "title, 3 artists, genre, description, date");
        for comment in [
            "TITLE=GGEZ",
            "ARTIST=Kaien",
            "ARTIST=Sugar",
            "ARTIST=M. Sasuke",
            "GENRE=Slop Pop",
            "DESCRIPTION=Hey don't say that",
            "DATE=2025-04-01",
        ] {
            assert!(text.contains(comment), "{comment}");
        }
    }

    #[test]
    fn id3_joins_artists_and_embeds_the_cover() {
        let metadata = AudioMetadata {
            cover: Some(test_cover()),
            ..ggez()
        };
        let tag = metadata.id3v2_tag().unwrap();
        assert_eq!(&tag[..6], b"ID3\x03\x00\x00");

        let artist = find(&tag, b"TPE1");
        assert_eq!(&tag[artist + 10..artist + 34], b"\0Kaien; Sugar; M. Sasuke");

        let comm = find(&tag, b"COMM");
        assert_eq!(&tag[comm + 10..comm + 33], b"\0eng\0Hey don't say that");

        let apic = find(&tag, b"APIC");
        assert_eq!(&tag[apic + 10..apic + 24], b"\0image/jpeg\0\x03\0");
        assert_eq!(&tag[apic + 24..apic + 26], [0xFF, 0xD8], "JPEG data follows");
        assert_eq!(&tag[tag.len() - 2..], [0xFF, 0xD9], "APIC ends the tag");
    }

    #[test]
    fn id3_uses_utf16_for_non_ascii_text() {
        let metadata = AudioMetadata {
            title: "Café".into(),
            ..AudioMetadata::default()
        };
        let tag = metadata.id3v2_tag().unwrap();
        let title = find(&tag, b"TIT2");
        // UTF-16 encoding byte, BOM, then C a f é
        assert_eq!(tag[title + 10], 1);
        assert_eq!(&tag[title + 11..title + 13], [0xFF, 0xFE]);
        assert_eq!(&tag[title + 19..title + 21], 0x00E9_u16.to_le_bytes());
    }

    #[test]
    fn picture_block_describes_the_cover() {
        let cover = test_cover();
        let block = AudioMetadata {
            cover: Some(cover.clone()),
            ..AudioMetadata::default()
        }
        .flac_picture_block()
        .unwrap();
        assert_eq!(&block[..4], 3_u32.to_be_bytes(), "front cover");
        assert_eq!(&block[8..18], b"image/jpeg");
        assert_eq!(&block[22..26], 16_u32.to_be_bytes(), "width");
        assert_eq!(&block[26..30], 16_u32.to_be_bytes(), "height");
        assert_eq!(&block[42..], cover.bytes());
    }

    #[test]
    fn base64_matches_rfc_4648_vectors() {
        for (input, expected) in [
            ("", ""),
            ("f", "Zg=="),
            ("fo", "Zm8="),
            ("foo", "Zm9v"),
            ("foobar", "Zm9vYmFy"),
        ] {
            assert_eq!(base64(input.as_bytes()), expected);
        }
    }

    #[test]
    fn riff_info_chunk_is_word_aligned() {
        let chunk = ggez().riff_info_chunk().unwrap();
        assert_eq!(&chunk[..4], b"LIST");
        assert_eq!(&chunk[8..12], b"INFO");
        let declared = u32::from_le_bytes(chunk[4..8].try_into().unwrap()) as usize;
        assert_eq!(declared, chunk.len() - 8);
        assert_eq!(chunk.len() % 2, 0);
        // "GGEZ\0" is odd, so a pad byte follows it
        let inam = find(&chunk, b"INAM");
        assert_eq!(&chunk[inam + 4..inam + 14], b"\x05\0\0\0GGEZ\0\0");
        let iart = find(&chunk, b"IART");
        assert_eq!(&chunk[iart + 8..iart + 32], b"Kaien; Sugar; M. Sasuke\0");
    }

    #[test]
    fn project_metadata_maps_to_tags() {
        let project = ProjectMetadata {
            name: "GGEZ".into(),
            author: "Kaien; Sugar; M. Sasuke".into(),
            description: "Hey don't say that".into(),
            genre: "Slop Pop".into(),
            version: "1".into(),
            created_at: "2025-04-01T23:30:00Z".parse().unwrap(),
            cover: None,
        };
        assert_eq!(AudioMetadata::from_project(&project).unwrap(), ggez());
    }
}
