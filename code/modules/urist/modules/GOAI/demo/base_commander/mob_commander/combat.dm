/datum/goai/mob_commander/proc/GetAimTime(var/atom/target)
	if(isnull(target))
		return

	var/targ_distance = EuclidDistance(src.pawn, target)
	var/aim_time = rand(clamp(targ_distance*3, 1, 200)) + rand()*15
	return aim_time


/datum/goai/mob_commander/proc/GetTarget(var/list/searchspace = null, var/maxtries = 5)
	var/list/true_searchspace = (isnull(searchspace) ? brain?.perceptions?.Get(SENSE_SIGHT) : searchspace)

	if(!(true_searchspace))
		return

	var/atom/my_loc = src?.pawn?.loc
	if(!my_loc)
		world.log << "[src] attempted to get loc, but couldn't find one!"
		return

	var/PriorityQueue/target_queue = new /PriorityQueue(/datum/Tuple/proc/FirstCompare)

	for(var/mob/goai/enemy in true_searchspace)
		// CHECK RELATIONS!!!
		var/enemy_dist = ManhattanDistance(my_loc, enemy)

		if (enemy_dist <= 0)
			continue

		var/datum/Tuple/enemy_tup = new(-enemy_dist, enemy)
		target_queue.Enqueue(enemy_tup)

	var/tries = 0
	var/atom/target = null

	while (isnull(target) && target_queue.L.len && tries < maxtries)
		var/datum/Tuple/best_target_tup = target_queue.Dequeue()
		target = best_target_tup.right
		tries++

	return target


/datum/goai/mob_commander/proc/Shoot(var/obj/gun/cached_gun = null, var/atom/cached_target = null, var/datum/aim/cached_aim = null)
	. = FALSE

	if(!(src.pawn))
		world.log << "No mob not found for the [src.name] AI to shoot D;"
		return FALSE

	var/obj/gun/my_gun = (isnull(cached_gun) ? (locate(/obj/gun) in src.pawn.contents) : cached_gun)

	if(isnull(my_gun))
		world.log << "Gun not found for [src.pawn] to shoot D;"
		return FALSE

	var/atom/target = (isnull(cached_target) ? GetTarget() : cached_target)

	if(!isnull(target))
		my_gun.shoot(target, src.pawn)
		. = TRUE

	return .


/datum/goai/mob_commander/proc/GetActiveThreatDict() // -> /dict
	var/dict/threat_ghost = brain?.GetMemoryValue(MEM_THREAT, null, FALSE)
	return threat_ghost


/datum/goai/mob_commander/proc/GetActiveSecondaryThreatDict() // -> /dict
	var/dict/threat_ghost = brain?.GetMemoryValue(MEM_THREAT, null, FALSE)
	return threat_ghost


/datum/goai/mob_commander/proc/GetThreatPosTuple(var/dict/curr_threat = null) // -> num
	var/dict/threat_ghost = isnull(curr_threat) ? GetActiveThreatDict() : curr_threat

	var/threat_pos_x = 0
	var/threat_pos_y = 0

	if(!isnull(threat_ghost))
		threat_pos_x = threat_ghost.Get(KEY_GHOST_X, null)
		threat_pos_y = threat_ghost.Get(KEY_GHOST_Y, null)

		var/datum/Tuple/ghost_pos_tuple = new(threat_pos_x, threat_pos_y)

		return ghost_pos_tuple

	return


/datum/goai/mob_commander/proc/GetThreatDistance(var/atom/relative_to = null, var/dict/curr_threat = null, var/default = 0) // -> num
	var/datum/Tuple/ghost_pos_tuple = GetThreatPosTuple(curr_threat)

	if(isnull(ghost_pos_tuple))
		return default

	var/atom/rel_source = isnull(relative_to) ? src.pawn : relative_to
	var/threat_dist = default

	var/threat_pos_x = ghost_pos_tuple?.left
	var/threat_pos_y = ghost_pos_tuple?.right

	if(! (isnull(threat_pos_x) || isnull(threat_pos_y)) )
		threat_dist = ManhattanDistanceNumeric(rel_source.x, rel_source.y, threat_pos_x, threat_pos_y)

	return threat_dist


/datum/goai/mob_commander/proc/GetThreatChunk(var/dict/curr_threat) // -> turfchunk
	var/datum/Tuple/ghost_pos_tuple = GetThreatPosTuple(curr_threat)

	if(isnull(ghost_pos_tuple))
		return

	var/threat_pos_x = ghost_pos_tuple?.left
	var/threat_pos_y = ghost_pos_tuple?.right

	var/datum/chunk/threat_chunk = null

	if(! (isnull(threat_pos_x) || isnull(threat_pos_y)) )
		var/datum/chunkserver/chunkserver = GetOrSetChunkserver()
		threat_chunk = chunkserver.ChunkForTile(threat_pos_x, threat_pos_y, src.pawn.z)

	return threat_chunk


/datum/goai/mob_commander/proc/GetThreatAngle(var/atom/relative_to = null, var/dict/curr_threat = null, var/default = null)
	var/datum/Tuple/ghost_pos_tuple = GetThreatPosTuple(curr_threat)

	if(isnull(ghost_pos_tuple))
		return default

	var/atom/rel_source = isnull(relative_to) ? src.pawn : relative_to
	var/threat_angle = default

	var/threat_pos_x = ghost_pos_tuple?.left
	var/threat_pos_y = ghost_pos_tuple?.right

	if(! (isnull(threat_pos_x) || isnull(threat_pos_y)) )
		var/dx = (threat_pos_x - rel_source.x)
		var/dy = (threat_pos_y - rel_source.y)
		threat_angle = arctan(dx, dy)

	return threat_angle


/*
// This is commented out to prevent confusion between the plural, array methods
// and the singular, 'scalar' Threat methods.
// These will probably get removed, unless I figure out why it's such a pain right now.

/datum/goai/mob_commander/proc/GetActiveThreatDicts() // -> list(/dict)
	var/datum/memory/threat_mem_block = brain?.GetMemory(MEM_THREAT, null, FALSE)
	//world.log << "[src.pawn] threat memory: [threat_mem]"
	var/list/threat_block = threat_mem_block?.val // list(memory)
	var/list/threats = list() // list(/dict)

	for(var/datum/memory/threat_mem in threat_block)
		if(isnull(threat_mem))
			continue

		var/dict/threat_ghost = threat_mem?.val
		world.log << "THREAT GHOST: [threat_ghost]"
		if(istype(threat_ghost))
			threats.Add(threat_ghost)

	return threats


/datum/goai/mob_commander/proc/GetThreatDistances(var/atom/relative_to = null, var/list/curr_threats = null, var/default = 0, var/check_max = null) // -> num
	var/atom/rel_source = isnull(relative_to) ? src.pawn : relative_to
	var/list/threat_distances = list()
	var/list/threat_ghosts = isnull(curr_threats) ? GetActiveThreatDicts() : curr_threats

	var/checked_count = 0

	for(var/dict/threat_ghost in threat_ghosts)
		if(isnull(threat_ghost))
			continue

		if(!(isnull(check_max)) && (checked_count++ >= check_max))
			break

		var/threat_dist = default

		var/threat_pos_x = 0
		var/threat_pos_y = 0

		//world.log << "[src.pawn] threat ghost: [threat_ghost]"

		threat_pos_x = threat_ghost.Get(KEY_GHOST_X, null)
		threat_pos_y = threat_ghost.Get(KEY_GHOST_Y, null)
		//world.log << "[src.pawn] believes there's a threat at ([threat_pos_x], [threat_pos_y])"

		if(! (isnull(threat_pos_x) || isnull(threat_pos_y)) )
			threat_dist = ManhattanDistanceNumeric(rel_source.x, rel_source.y, threat_pos_x, threat_pos_y)

			// long-term, it might be nicer to index by obj/str here
			threat_distances.Add(threat_dist)

	//world.log << "[src.pawn]: GetThreatDistances => [threat_distances] LEN [threat_distances.len]"
	return threat_distances


/datum/goai/mob_commander/proc/GetThreatAngles(var/atom/relative_to = null, var/list/curr_threats = null, var/check_max = null)
	var/atom/rel_source = isnull(relative_to) ? src.pawn : relative_to
	var/list/threat_angles = list()
	var/list/threat_ghosts = isnull(curr_threats) ? GetActiveThreatDicts() : curr_threats

	var/checked_count = 0

	for(var/dict/threat_ghost in threat_ghosts)
		if(isnull(threat_ghost))
			continue

		if(!(isnull(check_max)) && (checked_count++ >= check_max))
			break

		var/threat_angle = null

		var/threat_pos_x = 0
		var/threat_pos_y = 0

		//world.log << "[src.pawn] threat ghost: [threat_ghost]"

		threat_pos_x = threat_ghost.Get(KEY_GHOST_X, null)
		threat_pos_y = threat_ghost.Get(KEY_GHOST_Y, null)
		//world.log << "[src.pawn] believes there's a threat at ([threat_pos_x], [threat_pos_y])"

		if(! (isnull(threat_pos_x) || isnull(threat_pos_y)) )
			var/dx = (threat_pos_x - rel_source.x)
			var/dy = (threat_pos_y - rel_source.y)
			threat_angle = arctan(dx, dy)

			// long-term, it might be nicer to index by obj/str here
			threat_angles.Add(threat_angle)

	return threat_angles
*/


/datum/goai/mob_commander/proc/Hit(var/angle, var/atom/shotby = null)
	. = ..(angle)

	var/impact_angle = IMPACT_ANGLE(angle)
	/* NOTE: impact_angle is in degrees from *positive X axis* towards Y, i.e.:
	//
	// impact_angle = +0   => hit from straight East
	// impact_angle = +180 => hit from straight West
	// impact_angle = -180 => hit from straight West
	// impact_angle = -90  => hit from straight North
	// impact_angle = +90  => hit from straight South
	// impact_angle = +45  => hit from North-East
	// impact_angle = -45  => hit from South-East
	//
	// Everything else - extrapolate from the above.
	*/
	//world.log << "Impact angle [impact_angle]"

	if(brain)
		var/list/shot_memory_data = list(
			KEY_GHOST_X = src.pawn.x,
			KEY_GHOST_Y = src.pawn.y,
			KEY_GHOST_Z = src.pawn.z,
			KEY_GHOST_POS_TUPLE = src.pawn.CurrentPositionAsTuple(),
			KEY_GHOST_ANGLE = impact_angle,
		)
		var/dict/shot_memory_ghost = new(shot_memory_data)

		brain.SetMemory(MEM_SHOTAT, shot_memory_ghost, src.ai_tick_delay*10)

		var/datum/brain/concrete/needybrain = brain
		if(needybrain)
			needybrain.AddMotive(NEED_COMPOSURE, -MAGICNUM_COMPOSURE_LOSS_ONHIT)

