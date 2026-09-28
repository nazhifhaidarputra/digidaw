/// Project archives, audio import caches, and memory-mapped file helpers.
pub mod file_manager;
/// Reversible project actions and bounded undo/redo management.
pub mod history;
/// Auto save and Crash handlers
pub mod mitigation;
/// Persisted project model and domain operations.
pub mod project;
