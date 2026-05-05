extends Resource
class_name ItemResource

enum Rarity {
	GREEN,
	BLUE,
	PURPLE,
	GOLD,
}

@export var item_name: String = ""
@export var quantity: int = 1
@export var weight_lbs: float = 0.0
@export var value_usd: float = 0.0
@export var description: String = ""
@export var rarity: Rarity = Rarity.GREEN
@export var icon: Texture2D
