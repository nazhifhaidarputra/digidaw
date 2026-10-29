//! Static assignment of graph nodes to workers, level by level.
//!
//! Each level's nodes are spread with longest-processing-time-first: the most expensive node
//! goes to the least loaded worker. Costs are measured and smoothed per node, but nodes only
//! move when a level becomes clearly unbalanced, so a plugin stays on one thread otherwise.
//! Every vector is sized when the schedule is built; reassigning never allocates.

/// Smoothing of measured node costs: the share a new measurement takes.
const COST_SMOOTHING: f32 = 0.05;
/// A level is rebalanced once its busiest worker exceeds the mean by this fraction...
const IMBALANCE_RATIO: f32 = 1.25;
/// ...and by at least this many microseconds, so tiny levels never churn.
const IMBALANCE_FLOOR_MICROS: f32 = 50.0;

pub(crate) struct LevelSchedule {
    workers: usize,
    levels: usize,
    /// Level of each node.
    node_level: Vec<u32>,
    /// Smoothed cost of each node, in microseconds.
    cost: Vec<f32>,
    /// Worker each node is assigned to.
    owner: Vec<u32>,
    /// Nodes grouped by level and then worker; `bounds[level * workers + worker]` and the next
    /// bound delimit one group.
    order: Vec<u32>,
    bounds: Vec<u32>,
    /// Nodes sorted by level, delimited by `level_bounds`.
    by_level: Vec<u32>,
    level_bounds: Vec<u32>,
    /// Per-worker load while assigning one level.
    load: Vec<f32>,
}

impl LevelSchedule {
    /// Schedules nodes whose level and seed cost are given per node. Allocates.
    pub fn new(node_level: Vec<u32>, seed_cost: Vec<f32>, workers: usize) -> Self {
        let workers = workers.max(1);
        let levels = node_level
            .iter()
            .max()
            .map_or(0, |level| *level as usize + 1);
        let nodes = node_level.len();
        let mut by_level: Vec<u32> = (0..nodes as u32).collect();
        by_level.sort_by_key(|&node| node_level[node as usize]);
        let mut level_bounds = vec![0_u32; levels + 1];
        for &level in &node_level {
            level_bounds[level as usize + 1] += 1;
        }
        for level in 0..levels {
            level_bounds[level + 1] += level_bounds[level];
        }
        let mut schedule = Self {
            workers,
            levels,
            node_level,
            cost: seed_cost,
            owner: vec![0; nodes],
            order: vec![0; nodes],
            bounds: vec![0; levels * workers + 1],
            by_level,
            level_bounds,
            load: vec![0.0; workers],
        };
        schedule.cost.resize(nodes, 1.0);
        for level in 0..levels {
            schedule.assign_level(level);
        }
        schedule.rebuild_order();
        schedule
    }

    pub fn levels(&self) -> usize {
        self.levels
    }

    #[cfg(test)]
    pub fn workers(&self) -> usize {
        self.workers
    }

    /// Nodes `worker` runs at `level`.
    pub fn nodes(&self, level: usize, worker: usize) -> &[u32] {
        let group = level * self.workers + worker;
        match (self.bounds.get(group), self.bounds.get(group + 1)) {
            (Some(&start), Some(&end)) => self
                .order
                .get(start as usize..end as usize)
                .unwrap_or_default(),
            _ => &[],
        }
    }

    /// Folds one measured run of `node` into its cost.
    pub fn observe(&mut self, node: usize, micros: f32) {
        if let Some(cost) = self.cost.get_mut(node)
            && micros.is_finite()
        {
            *cost += (micros - *cost) * COST_SMOOTHING;
        }
    }

    /// Reassigns the levels whose load has become unbalanced. Returns whether any node moved.
    pub fn rebalance(&mut self) -> bool {
        let mut moved = false;
        for level in 0..self.levels {
            if self.is_unbalanced(level) {
                moved |= self.assign_level(level);
            }
        }
        if moved {
            self.rebuild_order();
        }
        moved
    }

    fn level_nodes(&self, level: usize) -> std::ops::Range<usize> {
        let start = self.level_bounds.get(level).copied().unwrap_or(0) as usize;
        let end = self.level_bounds.get(level + 1).copied().unwrap_or(0) as usize;
        start..end
    }

    fn is_unbalanced(&mut self, level: usize) -> bool {
        self.load.fill(0.0);
        for &node in &self.by_level[self.level_nodes(level)] {
            let node = node as usize;
            if let Some(load) = self.load.get_mut(self.owner[node] as usize) {
                *load += self.cost[node];
            }
        }
        let total: f32 = self.load.iter().sum();
        let mean = total / self.workers as f32;
        let busiest = self.load.iter().copied().fold(0.0, f32::max);
        busiest > mean * IMBALANCE_RATIO && busiest - mean > IMBALANCE_FLOOR_MICROS
    }

    /// Longest-processing-time-first over one level. Returns whether any owner changed.
    fn assign_level(&mut self, level: usize) -> bool {
        let range = self.level_nodes(level);
        let cost = &self.cost;
        // Ties keep node order, so equal costs always land the same way.
        self.by_level[range.clone()].sort_unstable_by(|&a, &b| {
            cost[b as usize]
                .total_cmp(&cost[a as usize])
                .then(a.cmp(&b))
        });
        self.load.fill(0.0);
        let mut moved = false;
        for &node in &self.by_level[range] {
            let node = node as usize;
            let (worker, _) =
                self.load
                    .iter()
                    .enumerate()
                    .fold((0, f32::INFINITY), |best, (worker, &load)| {
                        if load < best.1 { (worker, load) } else { best }
                    });
            self.load[worker] += self.cost[node].max(f32::EPSILON);
            moved |= self.owner[node] != worker as u32;
            self.owner[node] = worker as u32;
        }
        moved
    }

    /// Counting sort of the nodes into their (level, worker) groups, in node order.
    fn rebuild_order(&mut self) {
        self.bounds.fill(0);
        for node in 0..self.node_level.len() {
            let group = self.node_level[node] as usize * self.workers + self.owner[node] as usize;
            self.bounds[group + 1] += 1;
        }
        for group in 0..self.levels * self.workers {
            self.bounds[group + 1] += self.bounds[group];
        }
        // Fill each group in node order. Quadratic in the group count, which is small, and
        // only runs when the schedule is built or nodes move.
        let groups = self.levels * self.workers;
        for group in 0..groups {
            let mut cursor = self.bounds[group] as usize;
            for node in 0..self.node_level.len() {
                let node_group =
                    self.node_level[node] as usize * self.workers + self.owner[node] as usize;
                if node_group == group {
                    self.order[cursor] = node as u32;
                    cursor += 1;
                }
            }
        }
    }
}

#[cfg(test)]
mod tests {
    use super::LevelSchedule;

    fn assigned(schedule: &LevelSchedule, level: usize) -> Vec<Vec<u32>> {
        (0..schedule.workers())
            .map(|worker| schedule.nodes(level, worker).to_vec())
            .collect()
    }

    #[test]
    fn every_node_runs_once_at_its_level() {
        let levels = vec![0, 0, 0, 1, 1, 2, 0];
        let schedule = LevelSchedule::new(levels.clone(), vec![1.0; 7], 3);
        assert_eq!(schedule.levels(), 3);
        let mut seen = vec![0; levels.len()];
        for level in 0..schedule.levels() {
            for worker in 0..3 {
                for &node in schedule.nodes(level, worker) {
                    assert_eq!(levels[node as usize] as usize, level);
                    seen[node as usize] += 1;
                }
            }
        }
        assert!(seen.iter().all(|&count| count == 1));
    }

    #[test]
    fn longest_first_balances_a_level() {
        // Costs 8, 4, 4, 2, 1, 1 over two workers: LPT gives {8, 2} and {4, 4, 1, 1}.
        let schedule = LevelSchedule::new(vec![0; 6], vec![8.0, 4.0, 4.0, 2.0, 1.0, 1.0], 2);
        let load = |nodes: &[u32]| -> f32 {
            nodes
                .iter()
                .map(|&node| [8.0, 4.0, 4.0, 2.0, 1.0, 1.0][node as usize])
                .sum()
        };
        let groups = assigned(&schedule, 0);
        assert_eq!(load(&groups[0]), 10.0);
        assert_eq!(load(&groups[1]), 10.0);
    }

    #[test]
    fn small_cost_drift_keeps_the_assignment() {
        let mut schedule = LevelSchedule::new(vec![0; 4], vec![100.0; 4], 2);
        let before = assigned(&schedule, 0);
        for _ in 0..200 {
            schedule.observe(0, 110.0);
        }
        assert!(!schedule.rebalance());
        assert_eq!(assigned(&schedule, 0), before);
    }

    #[test]
    fn a_clearly_unbalanced_level_is_reassigned() {
        let mut schedule = LevelSchedule::new(vec![0; 4], vec![100.0; 4], 2);
        // Both nodes of worker 0 become expensive.
        let heavy = schedule.nodes(0, 0).to_vec();
        for _ in 0..400 {
            for &node in &heavy {
                schedule.observe(node as usize, 1_000.0);
            }
        }
        assert!(schedule.rebalance());
        let groups = assigned(&schedule, 0);
        // One heavy node per worker now.
        for group in groups {
            assert_eq!(group.iter().filter(|node| heavy.contains(node)).count(), 1);
        }
    }
}
