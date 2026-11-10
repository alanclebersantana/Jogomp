shader_type canvas_item;
// Aviões do aeroporto: só aparecem onde, atrás deles, a pintura do fundo mostra céu pela vidraça
// (azul claro). Colunas, faixas, bancos, painéis e paredes ficam NA FRENTE do avião (ele voa lá fora).
uniform sampler2D scr : hint_screen_texture, filter_linear;
void fragment() {
	vec4 c = texture(TEXTURE, UV) * COLOR;
	vec3 b = texture(scr, SCREEN_UV).rgb;
	float L = dot(b, vec3(0.299, 0.587, 0.114));
	// céu de dia: claro e puxado para o azul (o azul passa do vermelho com folga)
	float m = smoothstep(0.45, 0.58, L) * smoothstep(0.005, 0.045, b.b - b.r);
	COLOR = vec4(c.rgb, c.a * m);
}
