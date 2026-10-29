class_name GameData
## Textos e regras fixas da Fase 1 (mochila, receitas, pistas, lápis).

const ITEM_INFO := {
	"corda": ["Corda", "🪢"], "gancho": ["Gancho de ferro", "🪝"], "gancho_corda": ["Gancho com corda", "🪝"],
	"engrenagem": ["Engrenagem", "⚙️"], "manivela_q": ["Manivela quebrada", "🔩"], "manivela": ["Manivela", "🔧"],
	"pavio": ["Pavio", "🧵"], "oleo": ["Lata de óleo", "🛢️"], "lanterna_acesa": ["Lanterna acesa", "🏮"],
	"picareta": ["Picareta", "⛏️"],
	"lona": ["Lona velha", "🧺"], "vela": ["Vela de moinho", "⛵"],
	"chave_a": ["Metade de chave", "🗝️"], "chave_b": ["Outra metade", "🗝️"], "chave": ["Chave da porteira", "🗝️"],
}
const RECIPES := [
	["corda", "gancho", "gancho_corda", "Você amarrou a corda no gancho!"],
	["engrenagem", "manivela_q", "manivela", "A engrenagem encaixou: a manivela está consertada!"],
	["oleo", "pavio", "lanterna_acesa", "Óleo e pavio novo: a lanterna acendeu de novo!"],
	["lona", "corda", "vela", "Você amarrou a lona na armação com a corda: uma vela nova para o moinho!"],
	["chave_a", "chave_b", "chave", "As duas metades se encaixaram: é a chave da porteira da mina!"],
]
const CLUE_INFO := {
	1: ["Um botão de uniforme", "Caído na varanda, ao lado dos lápis da Isis: um botão com o símbolo da picareta. É do uniforme da mina... mas não é meu."],
	2: ["Pegada de bota", "Uma pegada funda, com lama vermelha. Só existe lama dessa cor num lugar: lá embaixo, na mina."],
	3: ["Bilhete rasgado", "\"...ele nunca mais vai me denunciar ao patrão...\" Alguém escreveu isso com raiva. Eu denunciei os roubos da mina mês passado."],
	4: ["Páginas do livro-caixa", "As contas da mina, com números riscados e refeitos. Os roubos! Só o gerente mexia nesse livro."],
	5: ["Chaveiro com a letra V", "Um chaveiro de couro gravado com um V. As chaves do depósito da mina."],
	6: ["O crachá", "\"ADEMAR VARGAS — GERENTE\". Foi ele. Ele levou a Isis para se vingar de mim. E está indo para a mina."],
	7: ["Mapa rasgado", "Um mapa da mina com um X vermelho num veio de ouro que ninguém conhecia. A letra é do Vargas."],
	8: ["Saquinho de pepitas", "Pepitas de ouro com o selo da companhia, escondidas no meio da palha. Ouro roubado da mina."],
	9: ["Bilhete lacrado", "\"Leve a menina pelos trilhos de baixo. Ninguém procura lá.\" — V."],
	10: ["O livro verdadeiro", "As contas de verdade da mina: tudo o que o Vargas desviou, anotado com a letra dele."],
	11: ["Relógio de bolso", "Um relógio com um V gravado, parado nas seis horas: a hora em que a Isis sumiu."],
	12: ["Chave do cofre", "Uma chave grande de latão com o brasão do Vargas. Ela abre alguma porta lá no fundo da mina."],
}
const PEN_LIST := ["vermelho", "laranja", "amarelo", "verde", "azul", "roxo"]
const PEN_COL := {
	"vermelho": Color("#e0463a"), "laranja": Color("#f08c2a"), "amarelo": Color("#f2cc2e"),
	"verde": Color("#4caf50"), "azul": Color("#3a7bd5"), "roxo": Color("#8e4ec6"),
}
const SONGS := ["manha", "tarde", "chuva", "noite", "tunel"]
