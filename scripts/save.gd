extends Node
## Salva progresso e opções em user://save.cfg (fica guardado no celular).
## Gravação à prova de queda: grava primeiro em save.cfg.tmp, confere, guarda o anterior em
## save.cfg.bak e só então troca o nome. Ao abrir, se o principal estiver estragado, usa o .tmp ou o .bak.

const PATH := "user://save.cfg"
const TMP := "user://save.cfg.tmp"
const BAK := "user://save.cfg.bak"
var cfg := ConfigFile.new()
## chamado antes de gravar o ponto de retorno: quem montou o jogo (main.gd) completa os dados
## (lápis/frutas caídos no chão, chefe vencido no meio da queda, tempo jogado)
var before_save_run: Callable
## segundos de jogo de verdade desta partida (contados em main.gd; vão junto com o ponto de retorno)
var run_secs := 0.0

func _ready() -> void:
	_load_safe()

func _notification(what: int) -> void:
	# saindo ou indo para o fundo: termina de gravar antes
	if what in [NOTIFICATION_WM_CLOSE_REQUEST, NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_PREDELETE, NOTIFICATION_WM_GO_BACK_REQUEST]:
		wait_written()

func _load_safe() -> void:
	wait_written()
	for p in [PATH, TMP, BAK]:
		if not FileAccess.file_exists(p):
			continue
		var c := ConfigFile.new()
		if c.load(p) == OK:
			cfg = c
			if p != PATH:
				push_warning("save.cfg estragado: recuperado de %s" % p)
				flush()
			return
	cfg = ConfigFile.new()

## grava no disco sem risco de perder tudo se o celular desligar no meio.
## A gravação vai para uma linha separada (gravar no meio do jogo — pegar um desenho, chegar na fogueira —
## dava uma travadinha no celular); várias gravações seguidas viram uma só.
var _mx := Mutex.new()
var _pending := ""
var _busy := false
var _task := -1

func flush() -> void:
	var txt := cfg.encode_to_text()
	_mx.lock()
	_pending = txt
	var start := not _busy
	_busy = true
	_mx.unlock()
	if start:
		# a tarefa anterior já terminou (_busy estava falso): recolhe antes de abrir outra
		if _task >= 0:
			WorkerThreadPool.wait_for_task_completion(_task)
		_task = WorkerThreadPool.add_task(_writer)

func _writer() -> void:
	while true:
		_mx.lock()
		var t := _pending
		_pending = ""
		if t == "":
			_busy = false
			_mx.unlock()
			return
		_mx.unlock()
		_write_text(t)

## espera a gravação em andamento terminar (ao sair do jogo / ir para o fundo)
func wait_written() -> void:
	var n := 0
	while n < 3000:
		_mx.lock()
		var b := _busy
		_mx.unlock()
		if not b:
			break
		OS.delay_msec(1)
		n += 1
	if _task >= 0:
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1

func _write_text(txt: String) -> void:
	var f := FileAccess.open(TMP, FileAccess.WRITE)
	if f == null:
		var f2 := FileAccess.open(PATH, FileAccess.WRITE)
		if f2:
			f2.store_string(txt)
			f2.close()
		return
	f.store_string(txt)
	f.close()
	var chk := ConfigFile.new()
	if chk.load(TMP) != OK:
		return
	var gp := ProjectSettings.globalize_path(PATH)
	var gt := ProjectSettings.globalize_path(TMP)
	var gb := ProjectSettings.globalize_path(BAK)
	if FileAccess.file_exists(PATH):
		DirAccess.remove_absolute(gb)
		DirAccess.rename_absolute(gp, gb)
	if DirAccess.rename_absolute(gt, gp) != OK:
		# sem troca de nome (sistema de arquivos estranho): grava direto
		var f3 := FileAccess.open(PATH, FileAccess.WRITE)
		if f3:
			f3.store_string(txt)
			f3.close()

func getv(sec: String, key: String, def = null):
	return cfg.get_value(sec, key, def)

func setv(sec: String, key: String, v) -> void:
	cfg.set_value(sec, key, v)
	flush()

## Progresso da fase: pistas, lápis especiais, desenhos e o ponto de retorno (fogueira)
func save_run(data: Dictionary) -> void:
	if before_save_run.is_valid():
		before_save_run.call(data)
	data["secs"] = run_secs
	cfg.set_value("run", "data", data)
	flush()

func load_run() -> Dictionary:
	return cfg.get_value("run", "data", {})

func clear_run() -> void:
	if cfg.has_section("run"):
		cfg.erase_section("run")
	flush()

func best(level: int) -> Dictionary:
	return cfg.get_value("best", str(level), {})

func set_best(level: int, d: Dictionary) -> void:
	var b := best(level)
	if d.get("stars", 0) >= b.get("stars", 0):
		cfg.set_value("best", str(level), d)
		flush()
