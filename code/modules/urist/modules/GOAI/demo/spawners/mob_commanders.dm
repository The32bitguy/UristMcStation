/proc/spawn_commanded_combatant(var/atom/loc, var/name = null, var/mob_icon = null, var/mob_icon_state = null, var/spawn_commander = TRUE)
	var/true_name = name

	var/mob/goai/combatant/M = new(active = FALSE)
	if(true_name)
		M.name = true_name

	M.pLobotomizeGoai(stop_life = FALSE) // probably should refactor to not make a brain in the first place!

	if(mob_icon)
		M.icon = mob_icon

	if(mob_icon_state)
		M.icon_state = mob_icon_state

	M.loc = loc

	if(spawn_commander)
		var/datum/goai/mob_commander/combat_commander/new_commander = new()

		new_commander.pawn = M
		var/dict/pawn_attachments = M.attachments

		if(isnull(pawn_attachments))
			pawn_attachments = new()
			M.attachments = pawn_attachments

		pawn_attachments[ATTACHMENT_CONTROLLER_BACKREF] = new_commander.registry_index
		world.log << "Pawn of [new_commander.name] is [new_commander.pawn]"

		true_name = true_name || "AI of [M.name]"
		if(true_name)
			new_commander.name = true_name

		world.log << "Spawned [new_commander.name]/[M]"

	return



/obj/spawner/oneshot/commanded_mob
	var/commander_name = null
	var/mob_icon = null
	var/mob_icon_state = null
	var/spawn_commander = TRUE

	icon = 'icons/uristmob/simpleanimals.dmi'
	icon_state = "ANTAG"

	script = /proc/spawn_commanded_combatant


/obj/spawner/oneshot/commanded_mob/CallScript()
	if(!active)
		return

	var/true_mob_icon = src.mob_icon || src.icon
	var/true_mob_icon_state = src.mob_icon_state || src.icon_state

	var/script_args = list(
		loc = src.loc,
		name = src.commander_name,
		mob_icon = true_mob_icon,
		mob_icon_state = true_mob_icon_state,
		spawn_commander = spawn_commander
	)

	call(script)(arglist(script_args))



/proc/spawn_commanded_object(var/atom/loc, var/name = null)
	var/true_name = name

	var/obj/gun/M = new(loc)
	if(true_name)
		M.name = true_name

	var/datum/goai/mob_commander/combat_commander/new_commander = new()

	new_commander.pawn = M
	new_commander.name = "AI of [M.name]"

	world.log << "Pawn of [new_commander.name] is [new_commander.pawn]"
	world.log << "Spawned [new_commander.name]/[M]"

	return



/obj/spawner/oneshot/commanded_object
	var/commander_name = null

	icon = 'icons/obj/guns/small_egun.dmi'
	icon_state = "smallgunkill75"

	script = /proc/spawn_commanded_object


/obj/spawner/oneshot/commanded_object/CallScript()
	if(!active)
		return

	var/script_args = list(
		loc = src.loc,
		name = src.commander_name
	)

	call(script)(arglist(script_args))


/*
/proc/spawn_commanded_sim(var/atom/loc, var/name = null)
	var/true_name = name

	var/obj/gun/M = new(loc)
	if(true_name)
		M.name = true_name

	var/datum/goai/mob_commander/sim_commander/new_commander = new()

	new_commander.pawn = M
	new_commander.name = "AI of [M.name]"

	world.log << "Pawn of [new_commander.name] is [new_commander.pawn]"
	world.log << "Spawned [new_commander.name]/[M]"

	return


/obj/spawner/oneshot/sim_mob
	var/commander_name = null
	var/mob_icon = null
	var/mob_icon_state = null

	icon = 'icons/uristmob/scommobs.dmi'
	icon_state = "civ10"

	script = /proc/spawn_commanded_sim


/obj/spawner/oneshot/sim_mob/CallScript()
	if(!active)
		return

	var/script_args = list(
		loc = src.loc,
		name = src.commander_name,
	)

	call(script)(arglist(script_args))
*/
