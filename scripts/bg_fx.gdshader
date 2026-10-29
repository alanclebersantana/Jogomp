shader_type canvas_item;
// Fundo pintado: tremor de ar quente perto do horizonte (tarde), perspectiva atmosférica
// (longe = menos saturado e puxado para a cor do céu), clarão do relâmpago e um pontilhado
// mínimo para não aparecer faixas nos degradês do céu. Uma amostra de textura por pixel.
uniform float t = 0.0;            // tempo do jogo (para quando pausa)
uniform float shimmer = 0.0;      // 0..1 ar quente
uniform float flash = 0.0;        // 0..1 relâmpago
uniform vec3 haze_col = vec3(0.8, 0.88, 0.95);
uniform float haze_amt = 0.0;     // 0..~.2
uniform float desat = 0.0;        // 0..~.2

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 uv = UV;
	if (shimmer > 0.0) {
		// só na faixa do horizonte (meio da pintura), ondinhas finas subindo
		float band = smoothstep(0.38, 0.55, uv.y) * (1.0 - smoothstep(0.72, 0.9, uv.y));
		uv.x += sin(uv.y * 340.0 - t * 0.09) * sin(uv.y * 57.0 + t * 0.03) * 0.00055 * shimmer * band;
	}
	vec4 c = texture(TEXTURE, uv) * COLOR;
	// perspectiva atmosférica: o alto/longe da pintura mais apagado que a base (mais perto)
	float depth = 1.0 - smoothstep(0.62, 0.98, UV.y);
	float l = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	c.rgb = mix(c.rgb, vec3(l), desat * depth);
	c.rgb = mix(c.rgb, haze_col, haze_amt * depth);
	// relâmpago: o que é claro (céu, bordas iluminadas) acende mais
	c.rgb += flash * (0.10 + 0.55 * l) * vec3(0.86, 0.92, 1.0);
	// pontilhado de 1/255 contra faixas de cor
	c.rgb += (hash(FRAGCOORD.xy) - 0.5) / 255.0;
	COLOR = c;
}
