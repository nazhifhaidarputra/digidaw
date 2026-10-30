//! Parallel execution of the render graph: a fixed pool of DSP workers that runs the graph
//! level by level under a static bulk-synchronous schedule.
//!
//! A node's level is its depth in the routing DAG, floored by its stage: device input is level
//! −1, tracks start at 0, buses at 1, and master always comes last. Nodes of one level never
//! read each other, so a level runs on every worker at once and ends at a barrier.

pub(crate) mod schedule;
mod sync;
mod worker;

pub use worker::{
    AudioWorkerPool, LevelJob, MAX_DSP_WORKERS, REALTIME_SLICE, RealtimeSlice, auto_worker_count,
    promote_current_thread,
};
