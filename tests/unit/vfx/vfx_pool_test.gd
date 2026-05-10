## Unit tests for VFXManager particle pool logic: acquire, release, LRU
## eviction, reset on release, and expired particle sweeping.
##
## Covers: vfx-particles pool acquire/release/LRU logic only.
## Visual output is not testable (per testing standards).
extends GutTest

# ---------------------------------------------------------------------------
# Minimal particle pool implementation for unit testing.
# Matches VFXManager.ParticlePool logic.
# ---------------------------------------------------------------------------

class TestParticlePool:
	var available: Array[Node2D] = []
	var active: Array[Node2D] = []
	var spawn_timestamps: Array[int] = []

	func _init(initial_size: int) -> void:
		for i in range(initial_size):
			var node := Node2D.new()
			node.visible = false
			node.process_mode = Node.PROCESS_MODE_DISABLED
			available.append(node)

	func acquire(now_ms: int) -> Node2D:
		var particle: Node2D
		if available.size() > 0:
			particle = available.pop_back()
		elif active.size() > 0:
			# LRU eviction: recycle oldest active.
			particle = active.pop_front()
			spawn_timestamps.pop_front()
			_reset(particle)
		else:
			return null

		active.append(particle)
		spawn_timestamps.append(now_ms)
		particle.visible = true
		particle.process_mode = Node.PROCESS_MODE_INHERIT
		return particle

	func release(particle: Node2D) -> void:
		var idx := active.find(particle)
		if idx >= 0:
			active.remove_at(idx)
			spawn_timestamps.remove_at(idx)
		_reset(particle)
		available.append(particle)

	func _reset(p: Node2D) -> void:
		p.visible = false
		p.process_mode = Node.PROCESS_MODE_DISABLED
		p.scale = Vector2.ONE
		p.modulate = Color.WHITE
		p.rotation = 0.0

	func sweep_expired(now_ms: int, max_lifetime_ms: int) -> int:
		var swept := 0
		for i in range(active.size() - 1, -1, -1):
			if now_ms - spawn_timestamps[i] > max_lifetime_ms:
				var p := active[i]
				active.remove_at(i)
				spawn_timestamps.remove_at(i)
				_reset(p)
				available.append(p)
				swept += 1
		return swept

	func get_available_count() -> int:
		return available.size()

	func get_active_count() -> int:
		return active.size()


# ---------------------------------------------------------------------------
# Acquire tests
# ---------------------------------------------------------------------------

func test_acquire_returns_node_from_available() -> void:
	var pool := TestParticlePool.new(4)
	var node := pool.acquire(0)
	assert_not_null(node, "Acquire should return a node")
	assert_true(node.visible, "Acquired node should be visible")
	assert_eq(pool.get_available_count(), 3, "Available count should decrease")
	assert_eq(pool.get_active_count(), 1, "Active count should increase")


func test_acquire_exhausts_available_then_lru() -> void:
	var pool := TestParticlePool.new(2)

	var n1 := pool.acquire(0)
	var n2 := pool.acquire(1)
	assert_eq(pool.get_available_count(), 0, "Pool should be exhausted")
	assert_eq(pool.get_active_count(), 2)

	# Third acquire should recycle n1 (oldest active).
	var n3 := pool.acquire(2)
	assert_not_null(n3, "Should still return a node via LRU")
	assert_eq(pool.get_active_count(), 2, "Active count should stay at max")
	# n3 should be the recycled n1.
	assert_eq(n3, n1, "LRU should recycle the oldest active node")


func test_acquire_returns_null_when_empty_and_no_active() -> void:
	var pool := TestParticlePool.new(0)
	var node := pool.acquire(0)
	assert_null(node, "Empty pool with no active should return null")


func test_acquire_resets_recycled_node() -> void:
	var pool := TestParticlePool.new(1)

	var n1 := pool.acquire(0)
	n1.modulate = Color.RED
	n1.scale = Vector2(2.0, 2.0)
	n1.rotation = 1.5

	# Release to make available.
	pool.release(n1)
	assert_true(n1.modulate == Color.WHITE, "Released node should have reset color")
	assert_eq(n1.scale, Vector2.ONE, "Released node should have reset scale")
	assert_eq(n1.rotation, 0.0, "Released node should have reset rotation")
	assert_false(n1.visible, "Released node should be invisible")


# ---------------------------------------------------------------------------
# Release tests
# ---------------------------------------------------------------------------

func test_release_returns_node_to_available() -> void:
	var pool := TestParticlePool.new(3)
	var node := pool.acquire(0)

	assert_eq(pool.get_active_count(), 1)
	pool.release(node)
	assert_eq(pool.get_active_count(), 0)
	assert_eq(pool.get_available_count(), 3, "Available should be back to original size")
	assert_false(node.visible)


func test_release_nonexistent_node_is_noop() -> void:
	var pool := TestParticlePool.new(2)
	var external_node := Node2D.new()
	pool.release(external_node)
	assert_eq(pool.get_available_count(), 2)
	assert_eq(pool.get_active_count(), 0)


func test_release_and_reacquire_returns_same_node() -> void:
	var pool := TestParticlePool.new(1)
	var n1 := pool.acquire(0)
	pool.release(n1)
	var n2 := pool.acquire(10)
	assert_eq(n2, n1, "Reacquire after release should return the same node")


# ---------------------------------------------------------------------------
# LRU eviction tests
# ---------------------------------------------------------------------------

func test_lru_evicts_oldest_active() -> void:
	var pool := TestParticlePool.new(3)

	var n1 := pool.acquire(100)
	var n2 := pool.acquire(200)
	var n3 := pool.acquire(300)

	# Pool is exhausted. Acquire should evict n1 (oldest timestamp=100).
	var n4 := pool.acquire(400)
	assert_eq(n4, n1, "LRU should evict the oldest active (n1)")
	assert_eq(pool.get_active_count(), 3)

	# Active should now be [n2, n3, n1(reused)] and timestamps [200, 300, 400].
	# Next acquire should evict n2.
	var n5 := pool.acquire(500)
	assert_eq(n5, n2, "LRU should evict n2 next")


func test_lru_preserves_newest_on_exhaustion() -> void:
	var pool := TestParticlePool.new(2)

	var n1 := pool.acquire(100)
	var n2 := pool.acquire(200)

	# Evict n1, reuse it.
	var n3 := pool.acquire(300)
	assert_eq(n3, n1)

	# n2 should still be active (not evicted).
	assert_eq(pool.get_active_count(), 2)

	# Check that n2 is in active.
	var found_n2 := false
	for p in pool.active:
		if p == n2:
			found_n2 = true
			break
	assert_true(found_n2, "Newest active node should survive LRU eviction")


# ---------------------------------------------------------------------------
# Sweep expired tests
# ---------------------------------------------------------------------------

func test_sweep_removes_expired_particles() -> void:
	var pool := TestParticlePool.new(3)

	var n1 := pool.acquire(0)
	var n2 := pool.acquire(1000)
	pool.release(n2)  # n2 goes back to available
	var n2b := pool.acquire(2000)  # re-acquire n2, timestamp 2000

	# At time 12000: n1 has been active for 12000ms, n2b for 10000ms.
	# Max lifetime is 10000ms.
	var swept := pool.sweep_expired(12000, 10000)
	assert_eq(swept, 1, "Should sweep one expired particle")
	assert_eq(pool.get_active_count(), 1, "One particle should remain active")


func test_sweep_does_not_remove_fresh_particles() -> void:
	var pool := TestParticlePool.new(3)
	var n1 := pool.acquire(9000)

	var swept := pool.sweep_expired(10000, 5000)
	assert_eq(swept, 0, "Fresh particle should not be swept")
	assert_eq(pool.get_active_count(), 1)


func test_sweep_noop_when_nothing_expired() -> void:
	var pool := TestParticlePool.new(2)
	pool.acquire(0)
	pool.acquire(100)

	var swept := pool.sweep_expired(2000, 10000)
	assert_eq(swept, 0, "Nothing should be swept when all are under max lifetime")


# ---------------------------------------------------------------------------
# Pool state tests
# ---------------------------------------------------------------------------

func test_pool_initial_state_correct() -> void:
	var pool := TestParticlePool.new(5)
	assert_eq(pool.get_available_count(), 5)
	assert_eq(pool.get_active_count(), 0)


func test_pool_reset_after_full_cycle() -> void:
	var pool := TestParticlePool.new(3)

	var n1 := pool.acquire(0)
	var n2 := pool.acquire(100)
	var n3 := pool.acquire(200)

	pool.release(n1)
	pool.release(n2)
	pool.release(n3)

	assert_eq(pool.get_available_count(), 3)
	assert_eq(pool.get_active_count(), 0)
