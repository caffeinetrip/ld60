class_name DialogueLines
extends RefCounted
## Every conversation of the game, by id. `who` is a key of Dialogue.CAST.
## "$N" is replaced with the week's quota when the line is shown. `point` = a HUD spot the
## light slides to before the line (Dialogue.spots).

const LINES := {
	&"intro": [
		{who = &"sister", text = "We need $N from drink sales this week."},
	],
	# Guides: only what the screen doesn't say itself, one new thing a night.
	&"prep": [
		{who = &"sister", text = "Every drink has one best combination. Find it.", point = &"glass"},
	],
	&"report": [
		{who = &"sister", text = "\"It's ok\" means close, but not the best yet.", point = &"feedback"},
		{who = &"sister", text = "The first three days I pay back your mistakes.", point = &"feedback"},
	],
	&"stock": [
		{who = &"sister", text = "Restock buys only what's missing for this many drinks.", point = &"target"},
	],
	&"price": [
		{who = &"sister", text = "Too pricey and customers walk away.", point = &"price"},
	],
	&"special": [
		{who = &"sister", text = "Click when the marker is in the zone. Good drinks give relics."},
	],
	&"inventory": [
		{who = &"sister", text = "Drag relics into the backpack. Only those work.", point = &"backpack"},
		{who = &"sister", text = "Relics boost their neighbors, diagonals too.", point = &"backpack"},
	],
	&"newspaper": [
		{who = &"sister", text = "We made the paper. Street cats will come and scare customers."},
		{who = &"sister", text = "Click one to kick it out."},
	],
	&"boss_lose": [
		{who = &"sister", text = "Try again. Three Good or Perfect hits beat him."},
	],
	# after the boss: the run in numbers (Dialogue.vars from main), then it goes on, endless
	&"win": [
		{who = &"sister", text = "{days} days. ${earned} earned, {sold} drinks sold."},
		{who = &"sister", text = "{upgrades} upgrades, {relics} relics. Boss beaten on try {tries}."},
		{who = &"sister", text = "Someday we'll open new shops."},
		{who = &"sister", text = "For now we stay here and grow as much as we want."},
	],
}
