//! Atom encoding for the audio path: event sequences, MIDI, transport, and UI message rings.
//!
//! Everything here writes into storage allocated at preparation, so it is safe to call from
//! `process`. Layouts follow the LV2 atom specification: every atom is a `{size, type}` header
//! followed by its body, padded to eight bytes inside a container.

/// `LV2_Atom` header size.
const ATOM_HEADER: usize = 8;
/// `LV2_Atom_Sequence` header: the atom header plus the sequence body (`unit`, `pad`).
const SEQUENCE_HEADER: usize = 16;
/// `LV2_Atom_Event` header: a 64-bit frame time plus the body's atom header.
const EVENT_HEADER: usize = 16;
/// Ring message header: port index, atom type, body size, padding.
const MESSAGE_HEADER: usize = 16;

const fn padded(size: usize) -> usize {
    (size + 7) & !7
}

/// One atom port buffer, 64-bit aligned as the atom specification requires.
///
/// The plugin keeps a pointer to the storage from when the port is connected, so the buffer is
/// allocated once at preparation and never resized.
pub(crate) struct AtomBuffer {
    storage: Vec<u64>,
}

impl AtomBuffer {
    /// Allocates a buffer of at least `capacity` bytes, and never less than a sequence header.
    pub fn new(capacity: usize) -> Self {
        let words = capacity.max(SEQUENCE_HEADER).div_ceil(8);
        Self {
            storage: vec![0; words],
        }
    }

    fn bytes(&self) -> usize {
        self.storage.len() * 8
    }

    /// Location the plugin's port is connected to.
    pub fn as_mut_ptr(&mut self) -> *mut u8 {
        self.storage.as_mut_ptr().cast()
    }

    fn set_header(&mut self, size: usize, atom_type: u32) {
        let mut header = [0_u8; 8];
        let (size_word, type_word) = header.split_at_mut(4);
        size_word.copy_from_slice(&u32::try_from(size).unwrap_or(0).to_ne_bytes());
        type_word.copy_from_slice(&atom_type.to_ne_bytes());
        if let Some(first) = self.storage.first_mut() {
            *first = u64::from_ne_bytes(header);
        }
    }

    /// Makes the buffer an empty sequence the host can append events to.
    pub fn begin_input(&mut self, sequence_type: u32) {
        self.set_header(SEQUENCE_HEADER - ATOM_HEADER, sequence_type);
        // Sequence body: time stamps are in frames, the default unit.
        if let Some(body) = self.storage.get_mut(1) {
            *body = 0;
        }
    }

    /// Offers the whole buffer to the plugin as a chunk of free space, which is how a host
    /// tells a plugin how much it may write to an output port.
    pub fn begin_output(&mut self, chunk_type: u32) {
        self.set_header(self.bytes() - ATOM_HEADER, chunk_type);
    }

    /// Appends one event, with its body taken from `parts` in order.
    ///
    /// Returns `false`, leaving the sequence unchanged, when the event does not fit.
    pub fn append(&mut self, frames: i64, atom_type: u32, parts: [&[u8]; 2]) -> bool {
        let total = self.bytes();
        // SAFETY: The storage is `total` writable bytes that `begin_input` gave a header.
        unsafe { append_to_sequence(self.as_mut_ptr(), total, frames, atom_type, parts) }
    }

    /// Visits `(atom type, body)` for every event a plugin wrote into this output buffer.
    ///
    /// The contents are plugin-written, so every size is checked against the buffer before it
    /// is used. Visiting stops at the first malformed event or when `visit` returns `false`.
    pub fn events(&self, sequence_type: u32, visit: impl FnMut(u32, &[u8]) -> bool) {
        let buffer = self.storage.as_ptr().cast::<u8>();
        // SAFETY: The storage is `bytes()` readable bytes.
        unsafe { read_from_sequence(buffer, self.bytes(), sequence_type, visit) };
    }
}

/// # Safety
/// `buffer` must point to `total` readable bytes.
unsafe fn read_from_sequence(
    buffer: *const u8,
    total: usize,
    sequence_type: u32,
    mut visit: impl FnMut(u32, &[u8]) -> bool,
) {
    if total < SEQUENCE_HEADER {
        return;
    }
    let word = |offset: usize| {
        // SAFETY: Callers pass offsets whose four bytes lie inside `total`.
        unsafe { buffer.wrapping_add(offset).cast::<u32>().read_unaligned() }
    };
    let Ok(body_size) = usize::try_from(word(0)) else {
        return;
    };
    let Some(end) = ATOM_HEADER
        .checked_add(body_size)
        .filter(|end| *end <= total)
    else {
        return;
    };
    if word(4) != sequence_type || end < SEQUENCE_HEADER {
        return;
    }
    let mut offset = SEQUENCE_HEADER;
    while let Some(body) = offset.checked_add(EVENT_HEADER).filter(|body| *body <= end) {
        let Ok(size) = usize::try_from(word(offset + 8)) else {
            return;
        };
        let Some(next) = body.checked_add(size).filter(|next| *next <= end) else {
            return;
        };
        // SAFETY: `body..next` was just checked to lie inside the written sequence.
        let data = unsafe { std::slice::from_raw_parts(buffer.wrapping_add(body), size) };
        if !visit(word(offset + 12), data) {
            return;
        }
        offset = padded(next);
    }
}

/// # Safety
/// `buffer` must point to `total` writable bytes that begin with an initialised atom sequence
/// header, and `parts` must not alias that buffer.
unsafe fn append_to_sequence(
    buffer: *mut u8,
    total: usize,
    frames: i64,
    atom_type: u32,
    parts: [&[u8]; 2],
) -> bool {
    if total < SEQUENCE_HEADER {
        return false;
    }
    // SAFETY: The caller guarantees an initialised header, whose first word is its body size.
    let body_size = unsafe { buffer.cast::<u32>().read_unaligned() };
    let Ok(body_size) = usize::try_from(body_size) else {
        return false;
    };
    let payload = parts[0].len() + parts[1].len();
    let event = padded(EVENT_HEADER + payload);
    let (Ok(payload_size), Some(used)) =
        (u32::try_from(payload), ATOM_HEADER.checked_add(body_size))
    else {
        return false;
    };
    let Some(end) = used.checked_add(event) else {
        return false;
    };
    if used < SEQUENCE_HEADER || end > total {
        return false;
    }
    let Ok(new_body_size) = u32::try_from(end - ATOM_HEADER) else {
        return false;
    };
    // Every offset below stays within `used..end`, which the check above places in the buffer.
    let cursor = buffer.wrapping_add(used);
    // SAFETY: The event header's first eight bytes are inside the checked range.
    unsafe { cursor.cast::<i64>().write_unaligned(frames) };
    // SAFETY: The body size follows the frame time, inside the checked range.
    unsafe {
        cursor
            .wrapping_add(8)
            .cast::<u32>()
            .write_unaligned(payload_size)
    };
    // SAFETY: The body type follows its size, inside the checked range.
    unsafe {
        cursor
            .wrapping_add(12)
            .cast::<u32>()
            .write_unaligned(atom_type)
    };
    let mut offset = EVENT_HEADER;
    for part in parts {
        let target = cursor.wrapping_add(offset);
        // SAFETY: Both parts together are `payload` bytes inside the checked range, and the
        // caller guarantees they do not alias the sequence buffer.
        unsafe { std::ptr::copy_nonoverlapping(part.as_ptr(), target, part.len()) };
        offset += part.len();
    }
    for index in EVENT_HEADER + payload..event {
        // SAFETY: Padding up to the event's padded size is inside the checked range.
        unsafe { cursor.wrapping_add(index).write(0) };
    }
    // SAFETY: The sequence header is writable; its size word publishes the appended event.
    unsafe { buffer.cast::<u32>().write_unaligned(new_body_size) };
    true
}

/// Three-byte channel voice message for the engine's MIDI events.
pub(crate) fn midi_bytes(status: u8, channel: u8, first: u8, second: u8) -> [u8; 3] {
    [status | (channel & 0x0F), first & 0x7F, second & 0x7F]
}

/// Encodes a signed pitch-bend value (`-8192..=8191`) as its two seven-bit data bytes.
pub(crate) fn pitch_bend_bytes(channel: u8, value: i16) -> [u8; 3] {
    let centered = (i32::from(value) + 8192).clamp(0, 16_383);
    let low = u8::try_from(centered & 0x7F).unwrap_or(0);
    let high = u8::try_from(centered >> 7).unwrap_or(0);
    midi_bytes(0xE0, channel, low, high)
}

/// URIDs of the `time:Position` object and its properties, mapped at preparation.
#[derive(Clone, Copy, Debug, Default, PartialEq, Eq)]
pub(crate) struct PositionUrids {
    pub object: u32,
    pub position: u32,
    pub long: u32,
    pub int: u32,
    pub float: u32,
    pub frame: u32,
    pub speed: u32,
    pub bar: u32,
    pub bar_beat: u32,
    pub beat_unit: u32,
    pub beats_per_bar: u32,
    pub beats_per_minute: u32,
}

/// Transport facts reported to a plugin through a `time:Position` object.
#[derive(Clone, Copy, Debug, PartialEq)]
pub(crate) struct Position {
    pub frame: i64,
    pub speed: f32,
    pub bar: i64,
    pub bar_beat: f32,
    pub beat_unit: i32,
    pub beats_per_bar: f32,
    pub beats_per_minute: f32,
}

/// Size of an encoded `time:Position` object body: the object header and seven properties.
pub(crate) const POSITION_BODY: usize = 8 + 7 * 24;

/// Encodes the body of a `time:Position` atom object.
pub(crate) fn position_body(urids: &PositionUrids, position: &Position) -> [u8; POSITION_BODY] {
    let mut body = [0_u8; POSITION_BODY];
    let mut cursor = 0;
    let mut put = |bytes: &[u8]| {
        if let Some(target) = body.get_mut(cursor..cursor + bytes.len()) {
            target.copy_from_slice(bytes);
        }
        cursor += bytes.len();
    };
    // Object body: blank-node identifier, then the object type.
    put(&0_u32.to_ne_bytes());
    put(&urids.position.to_ne_bytes());
    let mut property = |key: u32, value_type: u32, value: [u8; 8], size: u32| {
        put(&key.to_ne_bytes());
        put(&0_u32.to_ne_bytes());
        put(&size.to_ne_bytes());
        put(&value_type.to_ne_bytes());
        put(&value);
    };
    let wide = |value: i64| value.to_ne_bytes();
    let narrow = |bytes: [u8; 4]| {
        let mut value = [0_u8; 8];
        if let Some(target) = value.get_mut(..4) {
            target.copy_from_slice(&bytes);
        }
        value
    };
    property(urids.frame, urids.long, wide(position.frame), 8);
    property(
        urids.speed,
        urids.float,
        narrow(position.speed.to_ne_bytes()),
        4,
    );
    property(urids.bar, urids.long, wide(position.bar), 8);
    property(
        urids.bar_beat,
        urids.float,
        narrow(position.bar_beat.to_ne_bytes()),
        4,
    );
    property(
        urids.beat_unit,
        urids.int,
        narrow(position.beat_unit.to_ne_bytes()),
        4,
    );
    property(
        urids.beats_per_bar,
        urids.float,
        narrow(position.beats_per_bar.to_ne_bytes()),
        4,
    );
    property(
        urids.beats_per_minute,
        urids.float,
        narrow(position.beats_per_minute.to_ne_bytes()),
        4,
    );
    body
}

/// Creates a bounded single-producer, single-consumer ring for atom messages.
pub(crate) fn atom_ring(capacity: usize) -> (AtomSender, AtomReceiver) {
    let (producer, consumer) = rtrb::RingBuffer::new(capacity.max(MESSAGE_HEADER));
    (AtomSender(producer), AtomReceiver(consumer))
}

/// Writing end of an atom message ring.
pub(crate) struct AtomSender(rtrb::Producer<u8>);

impl AtomSender {
    /// Queues one atom for `port`, or returns `false` when the ring has no room for all of it.
    pub fn send(&mut self, port: u32, atom_type: u32, body: &[u8]) -> bool {
        let Ok(size) = u32::try_from(body.len()) else {
            return false;
        };
        let Some(needed) = MESSAGE_HEADER.checked_add(body.len()) else {
            return false;
        };
        let Ok(chunk) = self.0.write_chunk_uninit(needed) else {
            return false;
        };
        let header = port
            .to_ne_bytes()
            .into_iter()
            .chain(atom_type.to_ne_bytes())
            .chain(size.to_ne_bytes())
            .chain(0_u32.to_ne_bytes());
        chunk.fill_from_iter(header.chain(body.iter().copied()));
        true
    }
}

/// Reading end of an atom message ring.
pub(crate) struct AtomReceiver(rtrb::Consumer<u8>);

impl AtomReceiver {
    /// Delivers every queued atom as `(port, atom type, body parts)`.
    ///
    /// A body that wraps around the ring arrives as two slices. A truncated message, which a
    /// well-behaved sender never produces, discards the rest of the ring.
    pub fn drain(&mut self, mut deliver: impl FnMut(u32, u32, [&[u8]; 2])) {
        loop {
            let Ok(header) = self.0.read_chunk(MESSAGE_HEADER) else {
                return;
            };
            let mut bytes = [0_u8; MESSAGE_HEADER];
            let (first, second) = header.as_slices();
            for (target, source) in bytes.iter_mut().zip(first.iter().chain(second)) {
                *target = *source;
            }
            let word = |index: usize| {
                let mut word = [0_u8; 4];
                if let Some(source) = bytes.get(index..index + 4) {
                    word.copy_from_slice(source);
                }
                u32::from_ne_bytes(word)
            };
            let (port, atom_type) = (word(0), word(4));
            let Ok(size) = usize::try_from(word(8)) else {
                return;
            };
            header.commit_all();
            let Ok(body) = self.0.read_chunk(size) else {
                let pending = self.0.slots();
                if let Ok(rest) = self.0.read_chunk(pending) {
                    rest.commit_all();
                }
                return;
            };
            let (first, second) = body.as_slices();
            deliver(port, atom_type, [first, second]);
            body.commit_all();
        }
    }
}

#[cfg(test)]
#[allow(
    clippy::unwrap_used,
    clippy::panic,
    reason = "test fixtures hold the expected bytes"
)]
mod tests {
    use super::*;

    fn word(bytes: &[u8], offset: usize) -> u32 {
        u32::from_ne_bytes(bytes[offset..offset + 4].try_into().unwrap())
    }

    /// An empty sequence in aligned storage: body size 8, then `unit` and `pad`.
    fn empty_sequence(bytes: usize) -> Vec<u64> {
        let mut storage = vec![0_u64; bytes / 8];
        storage[0] = u64::from_ne_bytes({
            let mut header = [0_u8; 8];
            header[..4].copy_from_slice(&8_u32.to_ne_bytes());
            header[4..].copy_from_slice(&77_u32.to_ne_bytes());
            header
        });
        storage
    }

    fn bytes(storage: &[u64]) -> Vec<u8> {
        storage.iter().flat_map(|word| word.to_ne_bytes()).collect()
    }

    #[test]
    fn events_are_appended_padded_and_bounded_by_the_buffer() {
        let mut storage = empty_sequence(64);
        let buffer = storage.as_mut_ptr().cast::<u8>();
        // SAFETY: `storage` is 64 writable bytes starting with a sequence header.
        assert!(unsafe { append_to_sequence(buffer, 64, 5, 9, [&[1, 2], &[3]]) });
        let written = bytes(&storage);
        // Sequence body: 8 header bytes plus one event of 16 + 3 bytes padded to 24.
        assert_eq!(word(&written, 0), 32);
        assert_eq!(word(&written, 4), 77);
        assert_eq!(i64::from_ne_bytes(written[16..24].try_into().unwrap()), 5);
        assert_eq!((word(&written, 24), word(&written, 28)), (3, 9));
        assert_eq!(written[32..40], [1, 2, 3, 0, 0, 0, 0, 0]);
        // 24 bytes remain: an eight-byte body fits exactly, a nine-byte body does not.
        // SAFETY: As above.
        assert!(!unsafe { append_to_sequence(buffer, 64, 6, 9, [&[0; 9], &[]]) });
        assert_eq!(word(&bytes(&storage), 0), 32);
        // SAFETY: As above.
        assert!(unsafe { append_to_sequence(buffer, 64, 6, 9, [&[4; 8], &[]]) });
        assert_eq!(word(&bytes(&storage), 0), 56);
        // SAFETY: As above.
        assert!(!unsafe { append_to_sequence(buffer, 64, 7, 9, [&[], &[]]) });
    }

    #[test]
    fn written_events_are_read_back_and_malformed_sizes_stop_the_walk() {
        let mut storage = empty_sequence(96);
        let buffer = storage.as_mut_ptr().cast::<u8>();
        // SAFETY: `storage` is 96 writable bytes starting with a sequence header.
        assert!(unsafe { append_to_sequence(buffer, 96, 0, 9, [&[1, 2, 3], &[]]) });
        // SAFETY: As above.
        assert!(unsafe { append_to_sequence(buffer, 96, 4, 8, [&[5; 8], &[]]) });
        let read = |storage: &[u64], sequence_type: u32| {
            let mut events = Vec::new();
            // SAFETY: `storage` is 96 readable bytes.
            unsafe {
                read_from_sequence(storage.as_ptr().cast(), 96, sequence_type, |kind, data| {
                    events.push((kind, data.to_vec()));
                    true
                });
            };
            events
        };
        assert_eq!(read(&storage, 77), [(9, vec![1, 2, 3]), (8, vec![5; 8])]);
        // A buffer that is not a sequence, such as an untouched chunk, yields nothing.
        assert!(read(&storage, 78).is_empty());
        // The second event now claims a body that runs past the written sequence.
        let mut corrupt = bytes(&storage);
        corrupt[48..52].copy_from_slice(&64_u32.to_ne_bytes());
        let corrupt = corrupt
            .chunks_exact(8)
            .map(|chunk| u64::from_ne_bytes(chunk.try_into().unwrap()))
            .collect::<Vec<_>>();
        assert_eq!(read(&corrupt, 77), [(9, vec![1, 2, 3])]);
        // A sequence size larger than the buffer is rejected outright.
        let mut oversized = empty_sequence(96);
        oversized[0] = u64::from_ne_bytes({
            let mut header = [0_u8; 8];
            header[..4].copy_from_slice(&4096_u32.to_ne_bytes());
            header[4..].copy_from_slice(&77_u32.to_ne_bytes());
            header
        });
        assert!(read(&oversized, 77).is_empty());
    }

    #[test]
    fn buffers_hold_input_sequences_and_offer_outputs_as_free_space() {
        let mut buffer = AtomBuffer::new(60);
        assert_eq!(buffer.bytes(), 64);
        buffer.begin_input(77);
        assert!(buffer.append(3, 9, [&[1, 2], &[3]]));
        let mut seen = Vec::new();
        buffer.events(77, |kind, data| {
            seen.push((kind, data.to_vec()));
            true
        });
        assert_eq!(seen, [(9, vec![1, 2, 3])]);
        // Starting the next block empties the sequence again.
        buffer.begin_input(77);
        buffer.events(77, |_, _| panic!("an emptied sequence has no events"));
        // An output buffer is a chunk until the plugin writes a sequence into it.
        buffer.begin_output(5);
        let header = bytes(&buffer.storage);
        assert_eq!((word(&header, 0), word(&header, 4)), (56, 5));
        buffer.events(77, |_, _| panic!("a chunk is not a sequence"));
        assert_eq!(AtomBuffer::new(0).bytes(), 16);
    }

    #[test]
    fn pitch_bend_is_centered_and_clamped() {
        assert_eq!(pitch_bend_bytes(1, 0), [0xE1, 0x00, 0x40]);
        assert_eq!(pitch_bend_bytes(0, 8191), [0xE0, 0x7F, 0x7F]);
        assert_eq!(pitch_bend_bytes(0, -8192), [0xE0, 0x00, 0x00]);
        assert_eq!(pitch_bend_bytes(0, i16::MAX), [0xE0, 0x7F, 0x7F]);
        assert_eq!(midi_bytes(0x90, 0x12, 60, 200), [0x92, 60, 72]);
    }

    #[test]
    fn position_objects_follow_the_atom_property_layout() {
        let urids = PositionUrids {
            object: 1,
            position: 2,
            long: 3,
            int: 4,
            float: 5,
            frame: 6,
            speed: 7,
            bar: 8,
            bar_beat: 9,
            beat_unit: 10,
            beats_per_bar: 11,
            beats_per_minute: 12,
        };
        let body = position_body(
            &urids,
            &Position {
                frame: 48_000,
                speed: 1.0,
                bar: 2,
                bar_beat: 1.5,
                beat_unit: 4,
                beats_per_bar: 3.0,
                beats_per_minute: 140.0,
            },
        );
        assert_eq!((word(&body, 0), word(&body, 4)), (0, 2));
        // First property: key, context, value size, value type, then the value itself.
        assert_eq!(
            (
                word(&body, 8),
                word(&body, 12),
                word(&body, 16),
                word(&body, 20)
            ),
            (6, 0, 8, 3)
        );
        assert_eq!(i64::from_ne_bytes(body[24..32].try_into().unwrap()), 48_000);
        // Second property is a float, padded to the next eight-byte boundary.
        assert_eq!(
            (word(&body, 32), word(&body, 40), word(&body, 44)),
            (7, 4, 5)
        );
        assert_eq!(f32::from_ne_bytes(body[48..52].try_into().unwrap()), 1.0);
        assert_eq!(word(&body, 52), 0);
        // Last property is the tempo.
        let last = POSITION_BODY - 24;
        assert_eq!(word(&body, last), 12);
        assert_eq!(
            f32::from_ne_bytes(body[last + 16..last + 20].try_into().unwrap()),
            140.0
        );
    }

    #[test]
    fn rings_deliver_whole_messages_in_order_and_reject_overflow() {
        let (mut sender, mut receiver) = atom_ring(64);
        assert!(sender.send(3, 9, &[1, 2, 3]));
        assert!(sender.send(4, 9, &[]));
        // 16 + 3 and 16 + 0 bytes are queued, so a 30-byte body no longer fits.
        assert!(!sender.send(5, 9, &[0; 30]));
        let mut seen = Vec::new();
        receiver.drain(|port, atom_type, parts| {
            seen.push((port, atom_type, [parts[0], parts[1]].concat()));
        });
        assert_eq!(seen, [(3, 9, vec![1, 2, 3]), (4, 9, vec![])]);
        // The read position has advanced, so the next body wraps around the ring's end.
        assert!(sender.send(6, 1, &[7; 40]));
        let mut wrapped = Vec::new();
        receiver.drain(|port, _, parts| {
            assert!(!parts[1].is_empty(), "body should wrap");
            wrapped.push((port, [parts[0], parts[1]].concat()));
        });
        assert_eq!(wrapped, [(6, vec![7; 40])]);
    }
}
