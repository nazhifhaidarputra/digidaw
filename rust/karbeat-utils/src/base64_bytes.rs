//! Serde helpers for opaque byte blobs.
//!
//! Human-readable formats (JSON project files) store the bytes as one base64 string instead
//! of an array of numbers, which would be several times larger and slow to parse. Binary
//! formats store them as a native byte string.
//!
//! Deserializing accepts all three shapes: a base64 string, a byte string, and a sequence of
//! integers, which is how blobs were written before these helpers existed.
//!
//! ```rust,ignore
//! #[derive(Serialize, Deserialize)]
//! struct State {
//!     #[serde(default, with = "karbeat_utils::base64_bytes")]
//!     blob: Vec<u8>,
//!     #[serde(default, with = "karbeat_utils::base64_bytes::option")]
//!     extra: Option<Vec<u8>>,
//! }
//! ```

use std::fmt;

use base64::{Engine, engine::general_purpose::STANDARD};
use serde::{Deserializer, Serializer, de};

/// Serializes `bytes` as base64 in human-readable formats and as a byte string otherwise.
pub fn serialize<S: Serializer>(bytes: &[u8], serializer: S) -> Result<S::Ok, S::Error> {
    if serializer.is_human_readable() {
        serializer.serialize_str(&STANDARD.encode(bytes))
    } else {
        serializer.serialize_bytes(bytes)
    }
}

/// Deserializes a base64 string, a byte string, or a legacy sequence of integers.
pub fn deserialize<'de, D: Deserializer<'de>>(deserializer: D) -> Result<Vec<u8>, D::Error> {
    deserializer.deserialize_any(BytesVisitor)
}

struct BytesVisitor;

impl<'de> de::Visitor<'de> for BytesVisitor {
    type Value = Vec<u8>;

    fn expecting(&self, formatter: &mut fmt::Formatter) -> fmt::Result {
        formatter.write_str("a base64 string or a sequence of bytes")
    }

    fn visit_str<E: de::Error>(self, value: &str) -> Result<Self::Value, E> {
        STANDARD.decode(value).map_err(E::custom)
    }

    fn visit_bytes<E: de::Error>(self, value: &[u8]) -> Result<Self::Value, E> {
        Ok(value.to_vec())
    }

    fn visit_byte_buf<E: de::Error>(self, value: Vec<u8>) -> Result<Self::Value, E> {
        Ok(value)
    }

    fn visit_seq<A: de::SeqAccess<'de>>(self, mut seq: A) -> Result<Self::Value, A::Error> {
        // Cap the hint so a corrupt length prefix cannot trigger a huge allocation
        let mut bytes = Vec::with_capacity(seq.size_hint().unwrap_or(0).min(1 << 20));
        while let Some(byte) = seq.next_element::<u8>()? {
            bytes.push(byte);
        }
        Ok(bytes)
    }
}

/// The same encoding for `Option<Vec<u8>>`; `None` is written as null.
pub mod option {
    use std::fmt;

    use serde::{Deserializer, Serialize, Serializer, de};

    struct Blob<'a>(&'a [u8]);

    impl Serialize for Blob<'_> {
        fn serialize<S: Serializer>(&self, serializer: S) -> Result<S::Ok, S::Error> {
            super::serialize(self.0, serializer)
        }
    }

    /// Serializes `Some` like [`super::serialize`] and `None` as null.
    pub fn serialize<S: Serializer>(
        bytes: &Option<Vec<u8>>,
        serializer: S,
    ) -> Result<S::Ok, S::Error> {
        match bytes {
            Some(bytes) => serializer.serialize_some(&Blob(bytes)),
            None => serializer.serialize_none(),
        }
    }

    /// Deserializes null as `None` and anything [`super::deserialize`] accepts as `Some`.
    pub fn deserialize<'de, D: Deserializer<'de>>(
        deserializer: D,
    ) -> Result<Option<Vec<u8>>, D::Error> {
        deserializer.deserialize_option(OptionVisitor)
    }

    struct OptionVisitor;

    impl<'de> de::Visitor<'de> for OptionVisitor {
        type Value = Option<Vec<u8>>;

        fn expecting(&self, formatter: &mut fmt::Formatter) -> fmt::Result {
            formatter.write_str("null, a base64 string, or a sequence of bytes")
        }

        fn visit_none<E: de::Error>(self) -> Result<Self::Value, E> {
            Ok(None)
        }

        fn visit_unit<E: de::Error>(self) -> Result<Self::Value, E> {
            Ok(None)
        }

        fn visit_some<D: Deserializer<'de>>(
            self,
            deserializer: D,
        ) -> Result<Self::Value, D::Error> {
            super::deserialize(deserializer).map(Some)
        }
    }
}

#[cfg(test)]
#[allow(
    clippy::unwrap_used,
    reason = "serialization failures should fail these tests"
)]
mod tests {
    use serde::{Deserialize, Serialize};

    #[derive(Serialize, Deserialize, Debug, PartialEq)]
    struct Blobs {
        #[serde(with = "super")]
        bytes: Vec<u8>,
        #[serde(default, with = "super::option")]
        extra: Option<Vec<u8>>,
    }

    fn sample() -> Blobs {
        Blobs {
            bytes: vec![0, 1, 2, 250, 255],
            extra: Some(vec![42]),
        }
    }

    #[test]
    fn json_writes_base64_strings_and_round_trips() {
        let json = serde_json::to_string(&sample()).unwrap();
        assert_eq!(json, r#"{"bytes":"AAEC+v8=","extra":"Kg=="}"#);
        assert_eq!(serde_json::from_str::<Blobs>(&json).unwrap(), sample());
    }

    #[test]
    fn legacy_integer_arrays_and_null_still_load() {
        let blobs: Blobs =
            serde_json::from_str(r#"{"bytes":[0,1,2,250,255],"extra":null}"#).unwrap();
        assert_eq!(blobs.bytes, sample().bytes);
        assert_eq!(blobs.extra, None);
        let missing: Blobs = serde_json::from_str(r#"{"bytes":""}"#).unwrap();
        assert_eq!(missing.extra, None);
    }

    #[test]
    fn invalid_base64_is_rejected() {
        assert!(serde_json::from_str::<Blobs>(r#"{"bytes":"not base64!"}"#).is_err());
    }
}
