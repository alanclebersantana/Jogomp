shader_type canvas_item;
// Acerto final de cor do mundo (por cima do cenário, da luz e dos efeitos; o HUD fica fora):
// cores mais saturadas e vivas, contraste um pouco maior, contornos escuros reforçados e luz de sol
// quente nos realces. Uma leitura da tela (mais 4 vizinhos para o contorno, só na qualidade alta).
uniform sampler2D scr : hint_screen_texture, filter_linear_mipmap;
uniform float sat = 1.16;        // saturação geral
uniform float vib = 0.26;        // a mais nas cores apagadas (céu, água, folhagem cinzenta)
uniform float contrast = 1.05;
uniform float bright = 1.02;
uniform float lift = 0.015;     // sombras um tiquinho mais abertas (nada fica "lavado" de preto)
uniform float edge = 0.0;       // força do reforço dos contornos (0 = desligado)
uniform float px = 1.5;         // espessura da amostra do contorno, em pixels da tela
uniform float warm = 0.03;      // luz quente nos realces (sol); de noite cai para ~0
uniform float glow_sat = 0.12;   // luzes (lanterna, fogo, cristais) mais coloridas
uniform float bloom = 0.55;     // brilho que se espalha em volta das luzes fortes (fogo, lanterna, sol)
uniform float bloom_th = 0.62;  // a partir de que claridade a luz "vaza"
uniform float vig = 0.12;       // vinheta: cantos um pouco mais escuros (olho vai para o meio)

float luma(vec3 c) {
	return dot(c, vec3(0.299, 0.587, 0.114));
}

void fragment() {
	vec3 c = textureLod(scr, SCREEN_UV, 0.0).rgb;
	// brilho (bloom): as partes mais claras da tela, lidas bem desfocadas (níveis pequenos da tela),
	// somadas de volta — fogo, lanterna, cristais e o sol "vazam" luz em volta
	vec3 bl = vec3(0.0);
	if (bloom > 0.0) {
		vec2 o = SCREEN_PIXEL_SIZE * 10.0;
		vec3 b1 = textureLod(scr, SCREEN_UV, 3.0).rgb;
		vec3 b2 = (textureLod(scr, SCREEN_UV + vec2(o.x, o.y), 4.0).rgb + textureLod(scr, SCREEN_UV + vec2(-o.x, o.y), 4.0).rgb
			+ textureLod(scr, SCREEN_UV + vec2(o.x, -o.y), 4.0).rgb + textureLod(scr, SCREEN_UV - o, 4.0).rgb) * 0.25;
		vec3 b3 = textureLod(scr, SCREEN_UV, 5.5).rgb;
		vec3 b = b1 * 0.4 + b2 * 0.35 + b3 * 0.25;
		float bm = max(b.r, max(b.g, b.b));
		// luzes coloridas (fogo, lanterna, cristal) vazam mais; branco liso (neve, céu) quase nada
		float ch = bm - min(b.r, min(b.g, b.b));
		bl = b * smoothstep(bloom_th, 1.0, bm) * bloom * (0.25 + 0.75 * smoothstep(0.08, 0.35, ch));
	}
	if (edge > 0.0) {
		vec2 o = SCREEN_PIXEL_SIZE * px;
		vec3 n = texture(scr, SCREEN_UV + vec2(o.x, 0.0)).rgb + texture(scr, SCREEN_UV - vec2(o.x, 0.0)).rgb
			+ texture(scr, SCREEN_UV + vec2(0.0, o.y)).rgb + texture(scr, SCREEN_UV - vec2(0.0, o.y)).rgb;
		// só escurece o que já é traço (pixel mais escuro que a vizinhança): o contorno aparece firme
		float d = luma(n * 0.25) - luma(c);
		c *= 1.0 - clamp(d * edge, 0.0, 0.55);
	}
	float L = luma(c);
	float mx = max(c.r, max(c.g, c.b));
	float s = mx - min(c.r, min(c.g, c.b));
	// saturação + "vibrance": as cores já fortes sobem pouco (pele não fica laranja), as apagadas sobem mais
	float k = sat + vib * (1.0 - s) * (1.0 - s);
	// luzes brilhantes e coloridas (chama, cristal, vaga-lume) ganham ainda mais cor
	k += glow_sat * smoothstep(0.7, 1.0, mx) * smoothstep(0.15, 0.5, s);
	c = mix(vec3(L), c, k);
	c = (c - 0.5) * contrast + 0.5;
	c = c * bright + lift;
	// sol: realces puxam para o dourado, sombras para um azul bem leve (luz viva, não cinza)
	float L2 = luma(c);
	c += warm * vec3(1.0, 0.62, 0.18) * smoothstep(0.55, 1.0, L2);
	c -= warm * 0.35 * vec3(0.3, 0.12, -0.2) * (1.0 - smoothstep(0.05, 0.4, L2));
	// luz que vaza, por cima (soma suave: não estoura o branco)
	c = c + bl * (1.0 - c * 0.6);
	// vinheta suave
	vec2 vq = SCREEN_UV - 0.5;
	c *= 1.0 - vig * smoothstep(0.25, 0.85, dot(vq, vq) * 2.2);
	COLOR = vec4(clamp(c, 0.0, 1.0), 1.0);
}
