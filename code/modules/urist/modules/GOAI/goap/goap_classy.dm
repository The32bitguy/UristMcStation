/*
X================================================================X
|                                                                |
|                  GOAL-ORIENTED ACTION PLANNING                 |
|                                                                |
X================================================================X

  This is an implementation of the GOAP AI algorithm for DM.

  GOAP is a search-based planning algorithm that promises AIs
  that are smart, organic, modular, easily extensible (i.e.
  adding new behaviors is a breeze) and still fairly 'cheap'.

  TL;DR, we know how to pathfind gud and fast since the 60s;
  if you zoom your brain out, planning a path is just a sequence
  of steps - and so is planning *actions*. So, we can yoink some
  good pathfinding algorithms (A*) and use them for AI planning.

  This *works*, and there's a good chance you played something
  that uses this AI architecture, especially around 2010 - notably,
  F.E.A.R., TES: IV & V (although Radiant AI is a fairly cut-down
  version) or Deus Ex: Human Revolution, just to name the AAA titles.

  This is a fairly ambitious implementation; unlike classic GOAP
  as originally described by Jeff Orkin, we're (ab-)using assoc
  lists and proc dynamic dispatch to be much more flexible.

  =*=   FLEXIBILITY   =*=

  Notably, by default our states can be described not just as
  booleans (True/False), but as numeric values (or even strings or
  lists, if your custom logic can handle that).

  This means that we can create plans that track resource (e.g. money,
  energy, health) usage  smartly without creating a billion boolean
  flags for each variant and to account for their depletion when
  scoring each plan.

  This also allows for goals that are more elaborate; e.g. 'be at
  position (15, 30) while having at least 20$ and full health'.

  That said, use this sparingly - the more complex the goal, the
  more expensive the plan will be to compute.

  =*=    EFFICIENCY    =*=

  This brings us to another trick: this implementation has been
  designed to be portable and easily paused/resumed/stopped and
  support hard limits on resource consumption.

  Thanks to DM's sleep(), this algorithm runs fairly seamlessly
  in the background even for heavy jobs.

  We don't want to choke the server with unsatisfiable jobs though;
  you can set a hard limit on the number of iterations before the
  planner gives up - in that case, we simply get a null back.

  You can also limit the max queue size, to prevent bigger jobs
  from eating up all the RAM. This may even speed up the search
  sometimes!

  =*=      SETUP      =*=

  An unfortunate side-effect of trying to support ALL use-cases
  is that it's hard to support any specific one out of the box.

  GOAI takes in a *lot* of parameters, and you will likely need
  to define a bunch of procs to tailor it to your use-cases.

  Worse yet, as DM doesn't, to my knowledge, support closures,
  it's hard to provide generic procs that would work on simple
  customized variants of my preferred graph structure.

  At minimum, you will need to define:
  (1) at least one Action Graph
  (2) a proc to fetch Preconditions for each Action in the Graph as an assoc list
  (3) a proc to fetch Effects for each Action in the Graph as an assoc list
  (4) a proc that compares two assoc lists, Current & Preconds and returns 1 if
  the Current state meets the requirements of the Action, 0 otherwise.
  (5) a proc that compares two assoc lists, Current & Goal and returns 1 if
  the Current state meets the requirements of the Goal, 0 otherwise.

  You can see a sample setup in the goap_testing.dm file.
*/

/datum/GOAP
	/* Abstract class */
	var/list/graph


/datum/GOAP/proc/update_op(var/old_val, var/new_val)
	// REQUIRED!
	return


/datum/GOAP/proc/compare_op(var/curr_val, var/targ_val)
	// REQUIRED!
	return


/datum/GOAP/proc/neighbor_dist(var/start, var/end)
	// REQUIRED!
	return


/datum/GOAP/proc/goal_dist(var/start, var/end)
	// REQUIRED!
	return


/datum/GOAP/proc/check_preconds(var/current_pos)
	// REQUIRED!
	return


/datum/GOAP/proc/get_effects(var/action_key)
	// REQUIRED!
	return


/datum/GOAP/proc/blackboard_default()
	// Optional.
	return 0


/datum/GOAP/proc/pqueue_key_gen(var/curr_iter, var/curr_cost, var/heuristic)
	// Optional.
	return curr_iter


/datum/GOAP/proc/handle_backtrack(var/backtracked_action)
	// Optional.
	return


/datum/GOAP/proc/update_counts(var/list/old_state, var/list/new_state)
		/* Merges counts in two assoc lists. Returns the result as a new assoc list.
	//
	// o old_state - start state
	// o new_state - new state (neighbor for neighbor measure, goal for goal measure)
	// o default - default value to read from old_state if the key is missing there.
	// o op - Optional, proc to use to update values.
	//        Takes 2 args: (new, old).
	//        Default: op(A, B) -> A + B
	//        A custom op can be used e.g. to implement normal pathfinding (with op(A, B) -> B).
	*/
	var/list/result_state = old_state.Copy()

	for (var/key in new_state)
		if (key == GOAP_KEY_SRC)
			continue

		var/old_val = (key in result_state) ? result_state[key] : blackboard_default()
		var/add_val = new_state[key]
		var/result = update_op(old_val, add_val)

		result_state[key] = result

	return result_state


/datum/GOAP/proc/evaluate_neighbor(var/neigh, var/current_pos, var/goal, var/list/blackboard)
		/* Evaluates a single Candidate action based on the current state.
	//
	// This involves three essential steps:
	// - Check preconditions: the action cannot be taken if its requirements are not met
	//
	// - Check effects: obviously, we only care about actions that help us get closer to the goal
	//
	// - Scoring: we need to (de-)prioritize expanding plans using this Candidate based on how good it is.
	//   This breaks down further into two scores that are then added together:
	//
	//   - (1) Neighbor Measure - the raw cost of taking the Candidate action in the current state
	//         In pathfinding terms, the 'distance' from current position to the next position.
	//
	//   - (2) Goal Measure - a rough estimate of how much closer taking the Candidate gets us to the
	//         search goal; the *LOWER* the better (since the action gets us *closer* to the goal).
	//
	// o neigh - key in the Graph assoc list representing the Candidate action.
	// o current_pos - current position in the plan, i.e. the 'start' var in the SearchIteration() call.
	// o goal  - assoc list of the goal state we're trying to reach (or exceed, depending on cmp)
	// o blackboard - optional;
	//
	*/
	var/list/actual_blackboard = blackboard ? blackboard : list()

	var/is_valid = check_preconds(neigh, actual_blackboard)

	var/effects = actual_blackboard.Copy()
	var/list/curr_source = (GOAP_KEY_SRC in effects) ? effects[GOAP_KEY_SRC].Copy() : list()
	curr_source.Add(current_pos)

	effects[GOAP_KEY_SRC] = curr_source

	var/datum/Tuple/result = null
	if (!is_valid)
		result = new /datum/Tuple(PLUS_INF, effects)
		return result

	var/list/new_effects = get_effects(neigh)
	if(new_effects)
		effects = update_counts(effects, new_effects)

	var/neigh_distance = neighbor_dist(current_pos, neigh, graph)
	var/goal_distance = goal_dist(neigh, goal)

	var/heuristic = neigh_distance + goal_distance

	result = new /datum/Tuple(heuristic, effects)

	return result


/datum/GOAP/proc/rebuild_effects(var/list/action_plan)
	/* Rebuilds the world-state after the given plan is applied.
	//
	// We need this proc so that we can check action preconds without carrying the blackboards on the stack
	// the whole time; most queued actions will never actually get evaluated, so it would chew up the RAM
	// for no discernible benefit. Of course, this does mean we chew up some CPU instead rebuilding these.
	//
	// o action_plan - plain old list of Actions in the current plan (in FIFO order from left to right)
	// o blackboard_default - optional; the default value to use for unset keys in the blackboard (only when necessary, e.g. comparing values). Default: 0.
	//
	*/
	var/list/rebuilt_blackboard = list()

	for (var/action in action_plan)
		var/list/act_effects = list()

		if (islist(action))
			var/list/state = action
			var/is_state = 0

			for (var/stitm in state)
				MAYBE_LOG("STITM: [stitm]")

				if (stitm in graph)
					var/list/statitm_fx = get_effects(stitm)
					act_effects = update_counts(act_effects, statitm_fx)

				else
					is_state = 1

			if (is_state)
				act_effects = update_counts(act_effects, state)

		else
			act_effects = get_effects(action)

		rebuilt_blackboard = update_counts(rebuilt_blackboard, act_effects)

	return rebuilt_blackboard


/datum/GOAP/proc/adjacent(var/current_pos)
	var/list/all_actions = list()
	for (var/act in graph)
		all_actions.Add(act)
	return all_actions


/datum/GOAP/proc/goal_check(var/current_pos, var/list/goal)
	var/list/pos_effects = islist(current_pos) ? current_pos : get_effects(current_pos)
	var/match = 1

	for (var/state in goal)
		var/goal_val = goal[state]

		if (isnull(goal_val))
			continue


		var/curr_value = (state in pos_effects) ? pos_effects[state] : 0
		var/cmp_result = compare_op(curr_value, goal_val)

		if (cmp_result <= 0)
			match = 0
			break

	return match


/datum/GOAP/proc/SearchIteration(var/list/start, var/list/goal, var/paths = null, var/PriorityQueue/queue = null, var/visited = null, var/cutoff_iter = null, var/max_queue_size = null, var/list/blackboard = null, var/curr_cost = 0, var/curr_iter = 0)
	/* The main 'worker' logic of the search.
	//
	// Takes in a graph, the starting position/state, the target position/state and a pile of configuration options/procs,
	// then evaluates all possible Candidates (followup actions available for the current state), simulating their results,
	// and returns the best Candidate to look at in the next SearchIteration call.
	// That is, unless our current start state already DOES satisfy the goals - in that case, we simply return the path to the goal.
	//
	// Where's the search then? It's done via the first branch (i.e. goal not found).
	// While evaluating the Candidates we're doing some magic to the Queue and Paths lists
	// and forwarding them to the next SearchIteration call.
	//
	// This code implements a 'trampoline' pattern; in other words, it's pseudo-recursive. What would
	// normally be a recursive call to SearchIteration is moved to another associated function (here, it's
	// the 'Plan' proc) which pipes the outputs of one SearchIteration calls to the inputs of the next one.
	//
	// The cool thing about this is that this lets us pause the search between any two iterations safely.
	// We could even serialize the output of one call to JSON or whatever, then deserialize it a day later,
	// on a completely different computer and it would pick up right where it left off!
	//
	//
	// o start - assoc list of the currently-evaluated start state
	// o goal  - assoc list of the goal state we're trying to reach (or exceed, depending on cmp)
	// o paths - optional; assoc list of best neighbors for each action seen so far. Will default to a new list.
	// o queue - optional; PriorityQueue instance from previous iteration(s). Will default to a new instance.
	// o visited - optional; assoc list of visited nodes. If null, *WILL NOT SKIP VISITED NODES*!
	// o cutoff_iter - optional; maximum iteration allowed for the search. If exceeded, search terminates w/o finding a valid path. If null - unlimited.
	// o max_queue_size - optional; maximum space allocated for the Priority Queue. Unlimited if null, otherwise trims the worst candidates from the list tail.
	// o blackboard - optional assoc list; represents the total expected state of the world before the Start action/state is applied. Default - empty list.
	// o curr_cost - *PRIVATE* optional; the total cost of getting from search root to current start pos. You shouldn't need to mess with it.
	// o curr_iter - *PRIVATE* optional; the search iteration index. You shouldn't need to mess with it.
	//
	// Returns: 2-tuple, (continue_search, next_iteration_params (usually) | best_path (if found))
	//
	*/
	MAYBE_LOG("    ")
	MAYBE_LOG("CURR ITER: [curr_iter]")
	MAYBE_LOG("CURR POS: [start]")

	var/list/_paths = isnull(paths) ? list() : paths
	var/PriorityQueue/_pqueue = isnull(queue) ? new /PriorityQueue(/datum/Quadruple/proc/ActionCompare) : queue

	# ifdef DEBUG_LOGGING
	MAYBE_LOG("START BB is [blackboard]")
	for (var/bbitem in blackboard)
		MAYBE_LOG("START BB ITEM: [bbitem] @ [blackboard[bbitem]]")
	# endif

	var/list/_blackboard = isnull(blackboard) ? list() : blackboard.Copy()

	var/list/updated_state = update_counts(_blackboard, start)

	var/goal_check_result = goal_check(updated_state, goal)
	if (goal_check_result > 0)
		MAYBE_LOG("GOAL CHECK SUCCEEDED.")

		var/raw_final_result = updated_state[GOAP_KEY_SRC]
		var/list/full_final_result = islist(start) ? list(raw_final_result, start) : raw_final_result + list(start)
		var/datum/Tuple/final_result = new /datum/Tuple(0, full_final_result)

		return final_result

	if (visited)
		var/curr_visit_count = visited[start] ? visited[start] : 0
		visited[start] = curr_visit_count + 1

	var/list/neighbors = adjacent(start)

	for (var/neigh in neighbors)
		if (visited && visited[neigh])
			continue

		var/datum/Tuple/evaluation = evaluate_neighbor(neigh, start, goal, updated_state)
		var/heuristic = evaluation.left
		var/effects = evaluation.right
		var/source = (GOAP_KEY_SRC in effects) ? effects[GOAP_KEY_SRC] : null

		var/datum/Triple/stored_data = _paths[neigh] ? _paths[neigh] : new /datum/Triple(PLUS_INF, null, null)
		var/stored_neigh_cost = stored_data.left

		var/total_cost = curr_cost + heuristic

		if (total_cost < stored_neigh_cost)
			_paths[neigh] = new /datum/Triple(total_cost, start, source)

		var/priority_key = pqueue_key_gen(curr_iter, curr_cost, heuristic)

		var/datum/Quadruple/cand_tuple = new /datum/Quadruple (priority_key, total_cost, neigh, source)

		if (total_cost < PLUS_INF && (!(cand_tuple in _pqueue)))
			_pqueue.Enqueue(cand_tuple)

			if (!isnull(max_queue_size))
				_pqueue.L.Cut(1, max_queue_size)

	if (_pqueue.L.len <= 0)
		to_world_log("Exhausted all candidates before a path was found!")
		return

	var/datum/Quadruple/next_cand_tuple = _pqueue.Dequeue()
	var/cand_cost = next_cand_tuple.second
	var/cand_pos = next_cand_tuple.third
	var/list/source_pos = next_cand_tuple.fourth

	MAYBE_LOG("CAND: [next_cand_tuple.third]")
	MAYBE_LOG("CAND SRCp: [source_pos]")

	# ifdef DEBUG_LOGGING
	/*for (var/srcpit in source_pos)
		MAYBE_LOG("SRCp item: [srcpit]")*/
	# endif

	var/list/action_stack = list(source_pos ? source_pos.Copy() : list())
	action_stack.Add(cand_pos)

	# ifdef DEBUG_LOGGING
	/*for (var/actpit in source_pos)
		MAYBE_LOG("ACTp item: [actpit]")*/
	# endif

	var/cand_blackboard = rebuild_effects(action_stack)
	cand_blackboard[GOAP_KEY_SRC] = source_pos

	# ifdef DEBUG_LOGGING
	for (var/blit in cand_blackboard)
		MAYBE_LOG("BLIT: [blit] = [cand_blackboard[blit]]")
	# endif

	var/list/new_params = list()

	new_params["start"] = cand_pos
	new_params["goal"] = goal
	new_params["paths"] = paths
	new_params["visited"] = visited
	new_params["cutoff_iter"] = cutoff_iter
	new_params["max_queue_size"] = max_queue_size
	new_params["blackboard"] = cand_blackboard
	new_params["curr_cost"] = cand_cost
	new_params["curr_iter"] = curr_iter + 1

	var/datum/Tuple/result = new /datum/Tuple (1, new_params)

	# ifdef DEBUG_LOGGING
	var/list/pathli = result.right
	MAYBE_LOG("Result tuple: ([result.left], [pathli] ([pathli.len]))")
	# endif

	return result


/datum/GOAP/proc/Plan(var/list/start, var/list/goal, var/paths = null, var/visited = null, var/cutoff_iter, var/max_queue_size = null)
	/* Main planning proc. Runs the full Astar search over a graph of Actions until either a path
	// satisfying the Goal criteria is found or the iteration cutoff has been exceeded (if set).
	//
	// Technically speaking, this proc doesn't *do* much. It's primarily a trampoline for one or more
	// SearchIteration() proc calls that handle the bulk of the work; this proc just manages their work
	// by forwarding parameters between iterations, deciding when to give up the search, and handling
	// the wrap-up of a successful pathfind.
	//
	// Somewhat surprisingly, this is a shockingly fast search (at least on relatively small action spaces)!
	// For larger spaces, you might want to break things down hierarchically - run one planner for the
	// 'strategy' level and then another for the 'tactical' level, whose action-space is constrained to
	// the RoE of the strategy - this way, two searches look at small spaces, rather than having one search
	// over a huge space.
	//
	// o start - assoc list of the currently-evaluated Start state
	// o goal  - assoc list of the Goal state we're trying to reach (or exceed, depending on cmp)
	// o paths - optional; assoc list of best neighbors for each action seen so far. Will default to a new list.
	// o visited - optional; assoc list of visited nodes. If null, *WILL NOT SKIP VISITED NODES*!
	// o cutoff_iter - optional; maximum iteration allowed for the search. If exceeded, search terminates w/o finding a valid path. If null - unlimited.
	// o max_queue_size - optional; maximum space allocated for the Priority Queue. Unlimited if null, otherwise trims the worst candidates from the list tail.
	// o pqueue_key_gen - optional proc; a hook to allow custom queue sort keys. Default - simply uses the iteration as the primary sort key.
	//
	// Returns: 2-tuple, (continue_search, best_path (if found)) if a path is found; null otherwise.
	*/
	var/curr_iter = 0
	var/continue_search = 1

	var/list/true_paths = isnull(paths) ? list() : paths
	var/list/next_params = list()
	var/datum/Tuple/result = null
	var/PriorityQueue/queue = new /PriorityQueue (/datum/Quadruple/proc/ActionCompare)

	next_params["start"] = start
	next_params["goal"] = goal
	next_params["queue"] = queue
	next_params["paths"] = true_paths
	next_params["visited"] = visited
	next_params["cutoff_iter"] = cutoff_iter
	next_params["max_queue_size"] = max_queue_size

	while (next_params && continue_search)
		sleep(-1) // this is a safe time to pause things and catch up with reality

		result = SearchIteration(arglist(next_params))
		continue_search = result?.left || FALSE
		var/list/new_params = result?.right

		next_params = new_params

		if (continue_search > 0)

			if (!isnull(cutoff_iter)) // 0 is *technically* valid, so let's use ifnull...
				curr_iter = curr_iter + 1
				if (curr_iter >= cutoff_iter)
					MAYBE_LOG("Path not found within [cutoff_iter] iterations!")
					return


	MAYBE_LOG("Broken out of the Plan loop!")
	var/datum/Triple/best_opt = result ? result.right : null
	var/best_path = best_opt

	for (var/parent_elem in best_path)
		handle_backtrack(parent_elem)

	return result


/datum/GOAP/New(var/list/graphmap)
	..()
	graph = graphmap


