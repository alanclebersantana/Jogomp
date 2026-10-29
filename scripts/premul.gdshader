shader_type canvas_item;
render_mode blend_premul_alpha;
// cola a tela do mundo (fundo transparente, cor já pré-multiplicada) por cima do plano de fundo
void fragment() {
	COLOR = texture(TEXTURE, UV);
}
