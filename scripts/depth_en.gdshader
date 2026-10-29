shader_type canvas_item;
// Volume nos inimigos (mesma ideia do depth.gdshader): a borda virada para a luz ganha um brilho
// fino por dentro do desenho e o lado oposto escurece de leve.
// No Godot 4 o COLOR que chega aqui já vem com a cor da textura multiplicada; multiplicar pela
// textura de novo (como no depth.gdshader) eleva as cores ao quadrado e deixa os bichos quase
// pretos (o javali marrom virava uma mancha escura). Aqui a cor da pintura fica como foi pintada.
uniform vec2 light_uv = vec2(-0.7, -0.7);   // de onde vem a luz, no espaço da textura
uniform vec4 rim_col : source_color = vec4(1.0, 0.9, 0.7, 1.0);
uniform float rim_amt = 0.32;
uniform float shade_amt = 0.30;
uniform float reach = 2.6;
uniform float form_amt = 0.36;    // sombra de forma larga (corpo redondo, não papel)
uniform float lit_amt = 0.12;
void fragment() {
	vec4 c = COLOR;
	if (texture(TEXTURE, UV).a > 0.02) {
		vec2 d = light_uv * TEXTURE_PIXEL_SIZE * reach;
		float al = texture(TEXTURE, UV + d).a;
		float al2 = texture(TEXTURE, UV + d * 2.0).a;
		float as1 = texture(TEXTURE, UV - d).a;
		float as2 = texture(TEXTURE, UV - d * 2.2).a;
		float rim = clamp((1.0 - al) * 0.7 + (1.0 - al2) * 0.3, 0.0, 1.0);
		float sh = clamp((1.0 - as1) * 0.5 + (1.0 - as2) * 0.5, 0.0, 1.0);
		vec2 q = normalize(light_uv) * TEXTURE_PIXEL_SIZE;
		float f = (1.0 - texture(TEXTURE, UV - q * 7.0).a) * 0.34 + (1.0 - texture(TEXTURE, UV - q * 14.0).a) * 0.28
			+ (1.0 - texture(TEXTURE, UV - q * 23.0).a) * 0.22 + (1.0 - texture(TEXTURE, UV - q * 34.0).a) * 0.16;
		float h = (1.0 - texture(TEXTURE, UV + q * 9.0).a) * 0.5 + (1.0 - texture(TEXTURE, UV + q * 20.0).a) * 0.5;
		vec3 col = c.rgb;
		col = mix(col, col * vec3(0.5, 0.52, 0.66), clamp(f, 0.0, 1.0) * form_amt);
		col *= 1.0 + h * lit_amt;
		col = mix(col, col * vec3(0.58, 0.6, 0.7), sh * shade_amt);
		col += rim_col.rgb * rim * rim_amt * c.a;
		c.rgb = col;
	}
	COLOR = c;
}
