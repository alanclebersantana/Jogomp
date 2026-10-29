extends RefCounted
class_name Fase
## Lê uma fase de assets/fases/<id>.txt: cabeçalho "chave=valor" e, depois de "---", a grade de letras
## (cada letra é um quadrado de 40 x 40). Ver a legenda em tools/fases.py.

const ORDEM := ["1-1", "1-2", "1-3", "1-4", "1-5", "1-6", "1-7", "1-8", "1-chefe"]
const PRONTAS := ["1-1", "1-2"]

var id := ""
var meta := {}
var dicas: Array[String] = []
var linhas: PackedStringArray = []
var w := 0
var h := 0


static func existe(fid: String) -> bool:
	return FileAccess.file_exists("res://assets/fases/%s.txt" % fid)


static func abre(fid: String) -> Fase:
	var f := Fase.new()
	f.id = fid
	var arq := FileAccess.open("res://assets/fases/%s.txt" % fid, FileAccess.READ)
	if arq == null:
		return null
	var grade := false
	while not arq.eof_reached():
		var l := arq.get_line()
		if not grade:
			if l.strip_edges() == "---":
				grade = true
				continue
			var k := l.find("=")
			if k > 0:
				var chave := l.substr(0, k).strip_edges()
				var valor := l.substr(k + 1).strip_edges()
				if chave == "dica":
					f.dicas.append(valor)
				else:
					f.meta[chave] = valor
		else:
			if l.length() > 0 or f.linhas.size() > 0:
				f.linhas.append(l)
	while f.linhas.size() > 0 and f.linhas[f.linhas.size() - 1].strip_edges() == "":
		f.linhas.remove_at(f.linhas.size() - 1)
	f.h = f.linhas.size()
	for l in f.linhas:
		f.w = maxi(f.w, l.length())
	return f


func m(chave: String, padrao := "") -> String:
	return str(meta.get(chave, padrao))


func mf(chave: String, padrao := 0.0) -> float:
	return float(meta.get(chave, padrao))


func letra(cx: int, cy: int) -> String:
	if cy < 0 or cy >= h or cx < 0:
		return " "
	var l := linhas[cy]
	if cx >= l.length():
		return " "
	return l[cx]
