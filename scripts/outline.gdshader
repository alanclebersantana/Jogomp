shader_type canvas_item;
// Contorno de desenho animado em volta de tudo o que é do mundo (cenário fixo, objetos, bichos, o Tomé),
// sem o plano de fundo. Lê o recorte (alfa) da tela do mundo — desenhada à parte, com fundo
// transparente — e pinta só o traço, PRETO PURO, numa camada por cima de tudo (luz, escuridão,
// névoa e tons do período já foram aplicados embaixo): o preto não vira marrom.
// Borda lisa: mede QUANTO de dois anéis em volta do ponto cai dentro do desenho (a média suaviza os
// degraus do recorte) e a beira de fora sai numa rampa curta, sem serrilhado.
uniform sampler2D world_tex : filter_linear;
uniform float px = 2.2;          // espessura do traço, em pixels da tela do mundo
uniform vec2 texel = vec2(0.00104, 0.00185);
uniform float amt = 1.0;

void fragment() {
	vec2 uv = SCREEN_UV;
	float a0 = texture(world_tex, uv).a;
	float e = 0.0;
	vec2 o = texel * px;
	// atalho (a maior parte da tela): longe de qualquer borda, 4 leituras bastam para saber que não
	// tem traço ali — só perto do desenho faz as 24 leituras
	float q = texture(world_tex, uv + vec2(o.x, 0.0)).a + texture(world_tex, uv - vec2(o.x, 0.0)).a
		+ texture(world_tex, uv + vec2(0.0, o.y)).a + texture(world_tex, uv - vec2(0.0, o.y)).a;
	bool near_edge = abs(q - a0 * 4.0) > 0.02 || a0 > 0.02;
	if (amt > 0.0 && a0 < 0.985 && near_edge) {
		float s1 = 0.0;
		float s2 = 0.0;
		float mx = a0;
		for (int i = 0; i < 16; i++) {
			float a = float(i) * 0.3926991;
			vec2 d = vec2(cos(a), sin(a)) * o;
			float a1 = texture(world_tex, uv + d).a;
			s1 += a1;
			mx = max(mx, a1);
			if (i % 2 == 0) {
				float a2 = texture(world_tex, uv + d * 0.55).a;
				s2 += a2;
				mx = max(mx, a2);
			}
		}
		s1 /= 16.0;
		s2 /= 8.0;
		float cov = smoothstep(0.0, 1.0, clamp(max(s1 * 6.0, s2 * 3.0), 0.0, 1.0));
		// só onde a vizinhança é bem mais cheia que o ponto (não pinta o miolo da água, da névoa etc.)
		e = cov * smoothstep(0.05, 0.3, mx - a0 + 0.05) * amt;
		// o traço passa por baixo do desenho: na beira do próprio desenho some junto com o alfa dele
		e *= 1.0 - a0;
	}
	COLOR = vec4(0.0, 0.0, 0.0, e);
}
