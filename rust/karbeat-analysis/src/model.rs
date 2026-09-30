//! Beat This! model backend with a capped thread pool and cooperative cancellation.
//!
//! The rten adapter follows `beat-this`'s own `RtenModel` (MIT, danigb and JKU Linz) and adds
//! a per-worker thread pool, a loaded graph shared between workers, and a cancellation check before every inference call, which stops
//! `BeatThis::analyze_audio` between chunks.

use std::{
    collections::HashMap,
    path::Path,
    sync::{
        Arc,
        atomic::{AtomicBool, Ordering},
    },
};

use anyhow::{Result, anyhow};
use beat_this::{Model, Tensor};
use parking_lot::Mutex;
use rten::{Model as RtenGraph, NodeId, RunOptions, ThreadPool, Value};
use rten_tensor::{AsView, Layout};

/// Error message returned from a run skipped by cancellation.
pub(crate) const CANCELLED: &str = "analysis cancelled";

/// Settings shared by the mel and beat models of one tracker, changed between jobs.
pub(crate) struct RunControl {
    cancel: Mutex<Option<Arc<AtomicBool>>>,
    /// Inference pool and its thread count.
    pool: Mutex<(usize, Arc<ThreadPool>)>,
}

impl RunControl {
    pub(crate) fn new(threads: usize) -> Self {
        Self {
            cancel: Mutex::new(None),
            pool: Mutex::new(pool(threads)),
        }
    }

    /// Prepares the next job: its cancellation flag and inference thread count.
    pub(crate) fn begin(&self, cancel: Arc<AtomicBool>, threads: usize) {
        *self.cancel.lock() = Some(cancel);
        self.set_threads(threads);
    }

    /// Changes the inference thread count, keeping the job's cancellation flag.
    pub(crate) fn set_threads(&self, threads: usize) {
        let mut current = self.pool.lock();
        if current.0 != threads.max(1) {
            *current = pool(threads);
        }
    }

    pub(crate) fn is_cancelled(&self) -> bool {
        self.cancel
            .lock()
            .as_ref()
            .is_some_and(|flag| flag.load(Ordering::Acquire))
    }

    fn pool(&self) -> Arc<ThreadPool> {
        Arc::clone(&self.pool.lock().1)
    }
}

fn pool(threads: usize) -> (usize, Arc<ThreadPool>) {
    let threads = threads.max(1);
    (threads, Arc::new(ThreadPool::with_num_threads(threads)))
}

/// One loaded ONNX graph run on its worker's thread pool. Copies made with [`Self::share`]
/// run the same loaded graph, so parallel workers do not load the weights again.
pub(crate) struct ThrottledRtenModel {
    graph: Arc<RtenGraph>,
    inputs: Arc<HashMap<String, NodeId>>,
    outputs: Arc<Vec<(NodeId, String)>>,
    output_ids: Arc<Vec<NodeId>>,
    control: Arc<RunControl>,
}

impl ThrottledRtenModel {
    pub(crate) fn load(path: &Path, control: Arc<RunControl>) -> Result<Self> {
        let graph = RtenGraph::load_file(path)?;
        let inputs = graph
            .input_ids()
            .iter()
            .filter_map(|&id| Some((graph.node_info(id)?.name()?.to_owned(), id)))
            .collect();
        let outputs = graph
            .output_ids()
            .iter()
            .filter_map(|&id| Some((id, graph.node_info(id)?.name()?.to_owned())))
            .collect();
        let output_ids = graph.output_ids().to_vec();
        Ok(Self {
            graph: Arc::new(graph),
            inputs: Arc::new(inputs),
            outputs: Arc::new(outputs),
            output_ids: Arc::new(output_ids),
            control,
        })
    }

    /// The same loaded graph, run under `control`.
    pub(crate) fn share(&self, control: Arc<RunControl>) -> Self {
        Self {
            graph: Arc::clone(&self.graph),
            inputs: Arc::clone(&self.inputs),
            outputs: Arc::clone(&self.outputs),
            output_ids: Arc::clone(&self.output_ids),
            control,
        }
    }
}

impl Model for ThrottledRtenModel {
    fn run(&mut self, inputs: &[(&str, &Tensor)]) -> Result<HashMap<String, Tensor>> {
        if self.control.is_cancelled() {
            return Err(anyhow!(CANCELLED));
        }
        let values = inputs
            .iter()
            .map(|(name, tensor)| {
                let id = self
                    .inputs
                    .get(*name)
                    .ok_or_else(|| anyhow!("unknown model input '{name}'"))?;
                let value = Value::from_shape(tensor.shape.as_slice(), tensor.data.clone())
                    .map_err(|error| anyhow!("invalid model input '{name}': {error}"))?;
                Ok((*id, value))
            })
            .collect::<Result<Vec<_>>>()?;
        let views = values
            .iter()
            .map(|(id, value)| (*id, value.into()))
            .collect();

        let mut options = RunOptions::default();
        options.thread_pool = Some(self.control.pool());
        let results = self.graph.run(views, &self.output_ids, Some(options))?;

        let mut named = HashMap::with_capacity(results.len());
        for (id, value) in self.output_ids.iter().zip(results) {
            let name = self
                .outputs
                .iter()
                .find(|(output, _)| output == id)
                .map_or_else(|| format!("output_{id:?}"), |(_, name)| name.clone());
            let tensor = value
                .into_tensor::<f32>()
                .ok_or_else(|| anyhow!("model output '{name}' is not f32"))?;
            named.insert(
                name,
                Tensor {
                    shape: tensor.shape().to_vec(),
                    data: tensor.to_vec(),
                },
            );
        }
        Ok(named)
    }
}
