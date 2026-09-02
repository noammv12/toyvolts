class_name Skins
extends RefCounted
## The playable toy figures (KayKit Adventurers, CC0).

const DIR := "res://assets/characters/kaykit/"
const ALL := [
    {"id": "Knight", "name": "Sir Clank", "blurb": "Armoured action figure. Stands his ground."},
    {"id": "Barbarian", "name": "Brawn", "blurb": "Muscle-bound adventure toy with a loud roar."},
    {"id": "Mage", "name": "Wisp", "blurb": "Wizard doll from a fantasy playset."},
    {"id": "Rogue", "name": "Sneak", "blurb": "Hooded rogue figure from the same set."},
]


static func path(id: String) -> String:
    for s in ALL:
        if s.id == id:
            return DIR + id + ".glb"
    return DIR + "Knight.glb"


static func random_id() -> String:
    return ALL[randi() % ALL.size()].id


static func display_name(id: String) -> String:
    for s in ALL:
        if s.id == id:
            return s.name
    return id
