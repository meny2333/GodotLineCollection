shader_type canvas_item;

void fragment() {
	vec2 uv = UV - 0.5;
	float dist = length(uv);
	if (dist > 0.5) {
		discard;
	}
	COLOR = texture(TEXTURE, UV);
}
