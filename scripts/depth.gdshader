shader_type canvas_item;
// Volume no Tomé (e no que é desenhado junto com ele): parece um boneco de verdade, não um papel.
// - contorno escuro por fora do desenho (dilata o recorte em alguns pixels da pintura);
// - sombra de forma LARGA no lado oposto à luz (o corpo é redondo: escurece aos poucos até a borda);
// - luz larga e um brilho fino na borda virada para a luz.
// Tudo é medido no recorte (alfa) da própria pintura, então gira junto na meia-volta.
uniform vec2 light_uv = vec2(-0.7, -0.7);   // de onde vem a luz, no espaço da textura
uniform vec4 rim_col : source_color = vec4(1.0, 0.9, 0.7, 1.0);
uniform float rim_amt = 0.32;
uniform float shade_amt = 0.30;   // sombra fina da borda
uniform float form_amt = 0.42;    // sombra de forma (larga)
uniform float lit_amt = 0.16;     // luz larga do lado da luz
uniform float reach = 2.6;
uniform float line_px = 3.4;      // espessura do contorno, em pixels da pintura (0 = sem contorno)
uniform vec4 line_col : source_color = vec4(0.13, 0.08, 0.05, 0.92);

#define A(uv) texture(TEXTURE, uv).a
// loja: cor da jaqueta do Milis (troca só o verde do casaco). hue < 0 = a jaqueta verde de sempre
uniform float jacket_hue = -1.0;
uniform float jacket_sat = 1.0;
uniform float jacket_val = 1.0;

vec3 rgb2hsv(vec3 c) {
	vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	float d = q.x - min(q.w, q.y);
	float e = 1.0e-10;
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}
vec3 hsv2rgb(vec3 c) {
	vec3 p = abs(fract(c.xxx + vec3(0.0, 2.0 / 3.0, 1.0 / 3.0)) * 6.0 - 3.0);
	return c.z * clamp(p - 1.0, 0.0, 1.0);
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	if (jacket_hue >= 0.0 && c.a > 0.02) {
		vec3 h = rgb2hsv(c.rgb);
		float g = smoothstep(0.19, 0.24, h.x) * (1.0 - smoothstep(0.46, 0.52, h.x)) * smoothstep(0.18, 0.3, h.y);
		if (g > 0.0) {
			vec3 n = hsv2rgb(vec3(jacket_hue, clamp(h.y * jacket_sat, 0.0, 1.0), clamp(h.z * jacket_val, 0.0, 1.0)));
			c.rgb = mix(c.rgb, n, g);
		}
	}
	vec2 ps = TEXTURE_PIXEL_SIZE;
	vec2 L = normalize(light_uv);
	if (c.a > 0.02) {
		vec2 d = L * ps * reach;
		float rim = clamp((1.0 - A(UV + d)) * 0.7 + (1.0 - A(UV + d * 2.0)) * 0.3, 0.0, 1.0);
		float sh = clamp((1.0 - A(UV - d)) * 0.5 + (1.0 - A(UV - d * 2.2)) * 0.5, 0.0, 1.0);
		// forma: quanto mais perto da borda do lado da sombra, mais escuro (gradiente largo)
		vec2 q = L * ps;
		float f = (1.0 - A(UV - q * 7.0)) * 0.34 + (1.0 - A(UV - q * 14.0)) * 0.28
			+ (1.0 - A(UV - q * 23.0)) * 0.22 + (1.0 - A(UV - q * 34.0)) * 0.16;
		float h = (1.0 - A(UV + q * 9.0)) * 0.5 + (1.0 - A(UV + q * 20.0)) * 0.5;
		vec3 col = c.rgb;
		col = mix(col, col * vec3(0.5, 0.52, 0.66), clamp(f, 0.0, 1.0) * form_amt);
		col = mix(col, col * vec3(0.58, 0.6, 0.7), sh * shade_amt);
		col *= 1.0 + h * lit_amt;
		col += rim_col.rgb * rim * rim_amt * c.a;
		c.rgb = col;
		// por dentro da borda já existe o traço pintado; nas partes semitransparentes o contorno completa
		if (line_px > 0.0 && c.a < 0.98) {
			c.rgb = mix(line_col.rgb, c.rgb, c.a);
			c.a = max(c.a, line_col.a * 0.9);
		}
		COLOR = c * COLOR;
	} else if (line_px > 0.0) {
		// contorno por fora: algum vizinho é desenho?
		vec2 o = ps * line_px;
		float m = max(max(A(UV + vec2(o.x, 0.0)), A(UV - vec2(o.x, 0.0))), max(A(UV + vec2(0.0, o.y)), A(UV - vec2(0.0, o.y))));
		vec2 o2 = o * 0.72;
		m = max(m, max(max(A(UV + o2), A(UV - o2)), max(A(UV + vec2(o2.x, -o2.y)), A(UV + vec2(-o2.x, o2.y)))));
		COLOR = vec4(line_col.rgb * COLOR.rgb, smoothstep(0.25, 0.7, m) * line_col.a * COLOR.a);
	} else {
		COLOR = c * COLOR;
	}
}
