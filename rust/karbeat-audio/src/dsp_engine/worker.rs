pub struct AudioJobId(u64);

pub struct AudioJob {
    id: AudioJobId,
}

/// Pool of ongoing audio job for multithreaded and parallel DSP implementation
///
/// The system uses Bulk Synchronous Parallel (BSP) with many steps of level to
/// process each level at the mixer routing DAG
///
/// Barrier are handled with event listener via MPI for lock-free and wait-free
/// approach of parallelism
///
/// Because plugin assume thread affinity, we use static BSP and fixed
/// worker assignment to guarantee thread affinity the compiler cannot
/// verify
pub struct AudioWorkerPool {
    /// pool arena
    pool: SlotMap,
}
