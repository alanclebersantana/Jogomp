class_name GameData
## Textos e regras fixas da Fase 1 (mochila, receitas, pistas, lápis).

const ITEM_INFO := {
	"cartao_acesso": ["Cartão de acesso", "💳"], "cordao": ["Cordão de crachá", "🎗️"], "cracha": ["Crachá da área restrita", "🪪"],
	"fusivel": ["Fusível queimado", "🔌"], "fita": ["Fita isolante", "🩹"], "fusivel_ok": ["Fusível emendado", "⚡"],
	"bastao": ["Bastão de sinalização", "🦯"],
	"botas_foguete": ["Botas-foguete", "🚀"], "gancho": ["Gancho magnético", "🧲"],
	"luvas": ["Luvas isolantes", "🧤"],
	"picareta": ["Bastão de sinalização", "🦯"],
}
const RECIPES := [
	["cartao_acesso", "cordao", "cracha", "Você prendeu o cartão no cordão: um crachá da área restrita!"],
	["fusivel", "fita", "fusivel_ok", "Fita isolante bem apertada: o fusível está emendado!"],
]
const CLUE_INFO := {
	1: ["Recibo de venda", "Um recibo de milhas vendidas por fora, com um carimbo de cifrão dourado no canto. Quem anda por aí com um cifrão desses?"],
	2: ["Capuz esquecido", "O capuz escuro do vulto, largado na sala secreta. Dentro, um fio de bigode fino e grisalho. O vulto é só um capanga... ou é o chefe?"],
	3: ["Lista de capangas", "\"Seguranças falsos no saguão, robôs falsos na segurança, drones espiões no mezanino. Ninguém passa!\" — assinado só com um B cheio de floreios."],
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
