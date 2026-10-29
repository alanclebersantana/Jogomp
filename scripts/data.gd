class_name GameData
## Textos e regras fixas da Fase 1 (mochila, receitas, pistas, lápis).

const ITEM_INFO := {
	"cartao_acesso": ["Cartão de acesso", "💳"], "cordao": ["Cordão de crachá", "🎗️"], "cracha": ["Crachá da área restrita", "🪪"],
	"fusivel": ["Fusível queimado", "🔌"], "fita": ["Fita isolante", "🩹"], "fusivel_ok": ["Fusível emendado", "⚡"],
	"bastao": ["Bastão de sinalização", "🦯"],
	"picareta": ["Bastão de sinalização", "🦯"],
}
const RECIPES := [
	["cartao_acesso", "cordao", "cracha", "Você prendeu o cartão no cordão: um crachá da área restrita!"],
	["fusivel", "fita", "fusivel_ok", "Fita isolante bem apertada: o fusível está emendado!"],
]
const CLUE_INFO := {
	1: ["Recibo de milhas falsas", "Um recibo com o selo \"Barão das Milhas Falsas — compre já, voe nunca\". As milhas dos clientes foram vendidas como se fossem dele."],
	2: ["Cartola amassada", "Uma cartola preta esquecida na sala secreta, com um bigode postiço dentro. O Barão esteve aqui disfarçado."],
	3: ["Lista de capangas", "\"Cambistas no saguão, robôs falsos na segurança, pombos no mezanino. Ninguém passa!\" — B."],
	4: ["Etiqueta de mala adulterada", "Uma etiqueta de bagagem com o código trocado. As milhas estão sendo despachadas escondidas nas malas!"],
	5: ["Planilha do Barão", "Uma planilha com milhares de milhas LATAM desviadas, anotadas com uma letra cheia de floreios."],
	6: ["Plano de voo", "\"Motoboy leva o malote até a pista. Eu sigo para Maringá no voo das 23h59.\" — Barão."],
}
const PEN_LIST := ["vermelho", "laranja", "amarelo", "verde", "azul", "roxo"]
const PEN_COL := {
	"vermelho": Color("#e0463a"), "laranja": Color("#f08c2a"), "amarelo": Color("#f2cc2e"),
	"verde": Color("#4caf50"), "azul": Color("#3a7bd5"), "roxo": Color("#8e4ec6"),
}
const SONGS := ["manha", "tarde", "chuva", "noite", "tunel"]
