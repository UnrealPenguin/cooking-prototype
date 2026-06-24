shader_type canvas_item;

// Chars the sprite as it burns: mild desaturation, real darkening, and a pull
// toward a warm charcoal so it reads as burnt food (not a flat grey blob).
// Drive burn_amount 0.0 (unburnt) -> 1.0 (fully charred). Alpha is preserved.
uniform float burn_amount : hint_range(0.0, 1.0) = 0.0;
uniform vec3 char_color : source_color = vec3(0.10, 0.055, 0.035);

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float gray = dot(tex.rgb, vec3(0.299, 0.587, 0.114));
	vec3 col = mix(tex.rgb, vec3(gray), burn_amount * 0.35); // mild desaturation
	col *= 1.0 - burn_amount * 0.55;                         // darken, keep detail
	col = mix(col, char_color, burn_amount * 0.45);          // warm charcoal
	COLOR = vec4(col, tex.a);
}
