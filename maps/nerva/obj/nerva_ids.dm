//ids

/obj/item/weapon/card/id/bodyguard
	name = "identification card"
	desc = "A card issued to those crazy enough to put their life on the line for the Officers."
	color = COLOR_GRAY40
	detail_color = COLOR_COMMAND_BLUE
	extra_details = list("goldstripe")
	job_access_type = /datum/job/blueshield

/obj/item/weapon/card/id/firstofficer
	name = "identification card"
	desc = "A card issued to the ship's first officer."
	item_state = "silver_id"
	detail_color = COLOR_COMMAND_BLUE
	job_access_type = /datum/job/firstofficer
	extra_details = list("goldstripe")

/obj/item/weapon/card/id/secondofficer
	name = "identification card"
	desc = "A card issued to the ship's second officer."
	item_state = "silver_id"
	detail_color = COLOR_COMMAND_BLUE
	job_access_type = /datum/job/hop

/obj/item/weapon/card/id/civilian/clown
	name = "identification card"
	desc = "A card issued to the ship's clown."
	detail_color = COLOR_CIVIE_GREEN
	job_access_type = /datum/job/clown

/obj/item/weapon/card/id/civilian/mime
	name = "identification card"
	desc = "A card issued to the ship's mime."
	detail_color = COLOR_CIVIE_GREEN
	job_access_type = /datum/job/mime

/obj/item/weapon/card/id/nerva_scientist
	name = "identification card"
	desc = "A card issued to Nanotrasen contract scientists."
	detail_color = COLOR_PURPLE
	job_access_type = /datum/job/scientist

/obj/item/weapon/card/id/nerva_senior_scientist
	name = "identification card"
	desc = "A card issued to senior Nanotrasen scientists."
	detail_color = COLOR_PALE_PURPLE_GRAY
	extra_details = list("goldstripe")
	job_access_type = /datum/job/seniorscientist

/obj/item/weapon/card/id/medical/psychiatrist/nerva
	job_access_type = /datum/job/chaplain
