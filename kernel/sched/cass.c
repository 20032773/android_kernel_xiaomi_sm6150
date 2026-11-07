// SPDX-License-Identifier: GPL-2.0
/*
 * Copyright (C) 2023-2024 Sultan Alsawaf <sultan@kerneltoast.com>.
 * Adapted for Qualcomm SM7150 (Kryo 470, Linux 4.14 Non-GKI).
 *
 * Capacity Aware Superset Scheduler (CASS) task placement algorithm:
 * Evaluates all eligible CPUs across Little (Cortex-A55) and Big (Cortex-A76)
 * clusters as a unified capacity-scaled superset, eliminating legacy cluster
 * group blind spots while preserving idle C-state residency and EAS efficiency.
 */

struct cass_cpu_cand {
	int cpu;
	unsigned int exit_lat;
	unsigned long cap;
	unsigned long cap_max;
	unsigned long cap_orig;
	unsigned long util;
};

static __always_inline unsigned long cass_cpu_util(int cpu, struct task_struct *p,
						   bool sync)
{
	struct rq *rq = cpu_rq(cpu);
	struct task_struct *curr = rq->curr;
	unsigned long util = cpu_util_without(cpu, p);

	/*
	 * Discount the current task's utilization if this is a synchronous
	 * wakeup and the current task is the sole runnable CFS task about to
	 * sleep on this CPU.
	 */
	if (sync && curr != p && !rt_task(curr) && !dl_task(curr) &&
	    rq->nr_running == 1) {
		unsigned long curr_util = task_util_est(curr);

		util = (util > curr_util) ? (util - curr_util) : 0;
	}

	return min(util, capacity_orig_of(cpu));
}

/*
 * Returns true if @a is a better CPU candidate than @b for task placement.
 */
static __always_inline bool cass_better_cand(const struct cass_cpu_cand *a,
					     const struct cass_cpu_cand *b,
					     int prev_cpu, int sync_cpu,
					     bool prefer_idle)
{
#define cass_cmp(x, y) ({ res = (long)(x) - (long)(y); })
	long res;

	/* Prefer the CPU that is not overutilized (> 100% normalized util) */
	if (unlikely(a->util > SCHED_CAPACITY_SCALE ||
		     b->util > SCHED_CAPACITY_SCALE)) {
		if (a->util > SCHED_CAPACITY_SCALE &&
		    b->util > SCHED_CAPACITY_SCALE) {
			if (cass_cmp(b->util, a->util))
				goto done;
		} else {
			return a->util <= SCHED_CAPACITY_SCALE;
		}
	}

	/*
	 * For latency-sensitive / top-app tasks (prefer_idle), prefer an idle
	 * CPU (exit_lat > 0; exit_lat == 1 means active/sync idle without C-state
	 * wakeup penalty) that fits the task within its current OPP if possible.
	 */
	if (prefer_idle) {
		bool a_idle = a->exit_lat > 0;
		bool b_idle = b->exit_lat > 0;

		if (a_idle != b_idle)
			return a_idle;
	}

	/* Prefer the CPU that fits within its current clock capacity */
	if ((a->util <= a->cap) != (b->util <= b->cap))
		return a->util <= a->cap;

	/* Prefer shallower idle C-state exit latency when both CPUs are idle */
	if (a->exit_lat && b->exit_lat && cass_cmp(b->exit_lat, a->exit_lat))
		goto done;

	/*
	 * Prefer smaller maximum capacity cluster (Cortex-A55 over Cortex-A76)
	 * when the task comfortably fits (< 80% of cluster capacity), saving
	 * dynamic power without sacrificing frame pacing.
	 */
	if (a->cap_orig != b->cap_orig) {
		bool a_fits_comfortably = (a->util * 5) <= (SCHED_CAPACITY_SCALE * 4);
		bool b_fits_comfortably = (b->util * 5) <= (SCHED_CAPACITY_SCALE * 4);

		if (a_fits_comfortably && b_fits_comfortably && !prefer_idle &&
		    cass_cmp(b->cap_orig, a->cap_orig))
			goto done;
	}

	/* Prefer lower capacity-normalized utilization (more headroom) */
	if (cass_cmp(b->util, a->util))
		goto done;

	/* Prefer higher thermal-throttled ceiling if tied */
	if (cass_cmp(a->cap_max, b->cap_max))
		goto done;

	/* Prefer sync waker CPU or cache-warm previous CPU */
	if (a->cpu == sync_cpu || b->cpu == sync_cpu)
		return a->cpu == sync_cpu;

	if (a->cpu == prev_cpu || b->cpu == prev_cpu)
		return a->cpu == prev_cpu;

	/* Tie-breaker: higher current capacity */
	cass_cmp(a->cap, b->cap);
done:
	return res > 0;
#undef cass_cmp
}

static int cass_select_task_rq_fair(struct task_struct *p, int prev_cpu,
				    int sd_flag, int wake_flags,
				    int sibling_count_hint __maybe_unused)
{
	struct cass_cpu_cand best = { .cpu = -1 };
	bool sync = (wake_flags & WF_SYNC) && !(current->flags & PF_EXITING);
	int this_cpu = smp_processor_id();
	int sync_cpu = sync ? this_cpu : -1;
	unsigned long p_util;
	bool prefer_idle;
	cpumask_t valid_cpus;
	int cpu;

	if (sd_flag & SD_BALANCE_WAKE)
		record_wakee(p);

	/* Avoid redundant load sync on fresh forks */
	if (!(sd_flag & SD_BALANCE_FORK))
		sync_entity_load_avg(&p->se);

	p_util = (sd_flag & SD_BALANCE_FORK) ? 0 : boosted_task_util(p);
	prefer_idle = schedtune_prefer_idle(p) > 0;

	rcu_read_lock();

	cpumask_and(&valid_cpus, &p->cpus_allowed, cpu_active_mask);

	for_each_cpu(cpu, &valid_cpus) {
		struct rq *rq = cpu_rq(cpu);
		struct cass_cpu_cand curr;
		unsigned long cap_orig;
		unsigned long raw_util;

		if (unlikely(cpu_isolated(cpu)))
			continue;

		cap_orig = max_t(unsigned long, capacity_orig_of(cpu), 1);
		curr.cpu = cpu;
		curr.cap_orig = cap_orig;
		curr.cap_max = capacity_of(cpu);

		/* Normalize current OPP capacity to SCHED_CAPACITY_SCALE */
		curr.cap = capacity_curr_of(cpu) * SCHED_CAPACITY_SCALE / cap_orig;

		if (idle_cpu(cpu)) {
			/* Offset by +2 so active sync idle (1) beats C-states (>=2) */
			curr.exit_lat = idle_get_state_idx(rq) + 2;
		} else if (cpu == sync_cpu && rq->nr_running == 1 &&
			   !rt_task(rq->curr) && !dl_task(rq->curr)) {
			curr.exit_lat = 1;
		} else {
			curr.exit_lat = 0;
		}

		/* Penalize CPUs currently running RT or DL threads */
		if (rt_task(rq->curr) || dl_task(rq->curr)) {
			if (!prefer_idle || best.cpu == -1) {
				raw_util = cass_cpu_util(cpu, p, cpu == sync_cpu) + p_util;
				curr.util = (raw_util * SCHED_CAPACITY_SCALE / cap_orig) +
					    (SCHED_CAPACITY_SCALE >> 2);
			} else {
				continue;
			}
		} else {
			raw_util = cass_cpu_util(cpu, p, cpu == sync_cpu) + p_util;
			/* Account for thermal pressure reducing cap_max below cap_orig */
			if (unlikely(curr.cap_max < cap_orig && curr.cap_max > 0))
				curr.util = raw_util * SCHED_CAPACITY_SCALE / curr.cap_max;
			else
				curr.util = raw_util * SCHED_CAPACITY_SCALE / cap_orig;
		}

		if (best.cpu == -1 ||
		    cass_better_cand(&curr, &best, prev_cpu, sync_cpu, prefer_idle))
			best = curr;
	}

	rcu_read_unlock();

	if (unlikely(best.cpu < 0))
		return cpumask_any_and(&p->cpus_allowed, cpu_online_mask);

	return best.cpu;
}
