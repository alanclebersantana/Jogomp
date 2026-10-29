extends Node
## Progresso: melhor resultado de cada fase e opções. Fica em user://progresso.cfg.

const ARQ := "user://progresso.cfg"
var cfg := ConfigFile.new()


func _ready() -> void:
	cfg.load(ARQ)


func gravar() -> void:
	cfg.save(ARQ)


func opt(chave: String, padrao = null):
	return cfg.get_value("opcoes", chave, padrao)


func set_opt(chave: String, v) -> void:
	cfg.set_value("opcoes", chave, v)
	gravar()


func teste() -> bool:
	return OS.has_feature("teste")


## resultado guardado da fase (vazio se nunca terminou)
func fase(id: String) -> Dictionary:
	return cfg.get_value("fases", id, {})


func liberada(ordem: Array, id: String) -> bool:
	if teste():
		return true
	var i := ordem.find(id)
	if i <= 0:
		return true
	return not fase(ordem[i - 1]).is_empty()


## guarda o melhor de cada item (milhas, tempo que sobrou, selos)
func registra(id: String, r: Dictionary) -> Dictionary:
	var antes := fase(id)
	var novo := antes.duplicate()
	novo["milhas"] = maxi(int(antes.get("milhas", 0)), int(r.milhas))
	novo["total"] = int(r.total)
	novo["sobra"] = maxf(float(antes.get("sobra", 0.0)), float(r.sobra))
	novo["todas"] = bool(antes.get("todas", false)) or bool(r.todas)
	novo["rapido"] = bool(antes.get("rapido", false)) or bool(r.rapido)
	cfg.set_value("fases", id, novo)
	gravar()
	return novo
