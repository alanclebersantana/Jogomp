shader_type canvas_item;
// fundo levemente desfocado (profundidade de campo): média de 5 amostras em volta do pixel
uniform float radius = 1.6;
void fragment() {
	vec2 px = TEXTURE_PIXEL_SIZE * radius;
	vec4 c = texture(TEXTURE, UV) * 0.36;
	c += texture(TEXTURE, UV + vec2(px.x, 0.0)) * 0.16;
	c += texture(TEXTURE, UV - vec2(px.x, 0.0)) * 0.16;
	c += texture(TEXTURE, UV + vec2(0.0, px.y)) * 0.16;
	c += texture(TEXTURE, UV - vec2(0.0, px.y)) * 0.16;
	COLOR = c * COLOR;
}
