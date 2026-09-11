use std::{
    collections::HashMap,
    sync::{Arc, mpsc},
};

use parking_lot::Mutex;

use crate::commands::AudioFeedback;

/// Routes correlated save replies on control workers, independently of the Flutter stream.
#[derive(Default)]
pub struct ProjectStateFeedback {
    active: Option<(HashMap<u32, bool>, mpsc::SyncSender<AudioFeedback>)>,
}

impl ProjectStateFeedback {
    pub fn register(
        owner: &Arc<Mutex<Self>>,
        ids: impl Iterator<Item = u32>,
    ) -> anyhow::Result<ProjectStateReceiver> {
        let mut router = owner.lock();
        anyhow::ensure!(
            router.active.is_none(),
            "A project state capture is already pending"
        );
        let ids: HashMap<_, _> = ids.map(|id| (id, false)).collect();
        let (sender, receiver) = mpsc::sync_channel(ids.len().max(1));
        router.active = Some((ids, sender));
        Ok(ProjectStateReceiver {
            owner: owner.clone(),
            receiver,
        })
    }

    /// Returns unrelated feedback for normal UI delivery. Never called by the audio thread.
    pub fn route(&mut self, feedback: AudioFeedback) -> Option<AudioFeedback> {
        let id = match &feedback {
            AudioFeedback::PluginStateSnapshot { request_id, .. } => Some(*request_id),
            AudioFeedback::MixerChannelSnapshot(snapshot) => snapshot.request_id,
            _ => None,
        };
        if let Some((ids, sender)) = &mut self.active {
            if let Some(delivered) = id.and_then(|id| ids.get_mut(&id)) {
                if !*delivered {
                    *delivered = sender.try_send(feedback).is_ok();
                }
                return None;
            }
        }
        Some(feedback)
    }
}

pub struct ProjectStateReceiver {
    owner: Arc<Mutex<ProjectStateFeedback>>,
    pub receiver: mpsc::Receiver<AudioFeedback>,
}

impl Drop for ProjectStateReceiver {
    fn drop(&mut self) {
        self.owner.lock().active = None;
    }
}
