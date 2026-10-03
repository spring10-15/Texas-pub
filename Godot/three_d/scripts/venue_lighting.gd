extends RefCounted
## Initial Godot color script; geometry and final art approval remain separate.
const PROFILES := {
	"stash":{"ambient":Color("b0b7c0"),"background":Color("171d22"),"warm":Color("ffc580"),"cool":Color("83a6ce")},
	"smoky-den":{"ambient":Color("bfb19c"),"background":Color("1b1c17"),"warm":Color("ffca85"),"cool":Color("93b2ce")},
	"high-rise-suite":{"ambient":Color("9db3cf"),"background":Color("151c29"),"warm":Color("f0d5ad"),"cool":Color("84aadd")},
	"rooftop-club":{"ambient":Color("adc0d6"),"background":Color("141d2b"),"warm":Color("ffcf98"),"cool":Color("88a6cd")},
	"neon-poker-club":{"ambient":Color("acafd0"),"background":Color("151322"),"warm":Color("c18adc"),"cool":Color("65bed2")}
}
var world: Node3D
func _init(owner: Node3D) -> void: world = owner
func apply(room: Node3D, profile_id: String) -> void:
	var profile: Dictionary = PROFILES[profile_id]
	world.scene_environment.ambient_light_color = profile.ambient
	world.scene_environment.background_color = profile.background
	for light: OmniLight3D in room.find_children("*","OmniLight3D",true,false):
		if not light.has_meta("original_color"): light.set_meta("original_color",light.light_color)
		var original: Color = light.get_meta("original_color")
		light.light_color = original if profile_id=="stash" else original.lerp(profile.cool if original.b>original.r else profile.warm,0.65)
