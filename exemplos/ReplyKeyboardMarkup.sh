#!/bin/bash
#
# script: ReplyKeyboardMarkup.sh
#
# Para melhor compreensão foram utilizados parâmetros longos nas funções; Podendo
# ser substituidos pelos parâmetros curtos respectivos.

# Importando API
source ShellBot.sh

# Token do bot
bot_token='<TOKEN_AQUI>'

# Inicializando o bot
ShellBot.init --token "$bot_token"
ShellBot.username

# Limpa o array que irá receber a estrutura.
unset botao

# array
# Nota: Cada elemento do array precisa estar entre aspas duplas enquanto
# a atribuição da estrutura entre aspas simples. Caso o uso das aspas duplas
# na atribuição seja necessário para expansão de variáveis, é preciso escapar
# as aspas internas com '\' (contra barra).
#
# Exemplo:
#
# botao="
# [\"$num1\",\"$num2\",\"$num3\"],
# [\"$num4\",\"$num5\",\"$num6\"],
# [\"$num7\",\"$num8\",\"$num9\"],
# [\"$num0\"]
# "

# teclado - array
botao='
["1","2","3"],
["4","5","6"],
["7","8","9"],
["0"]
'

# Cria o teclado, define a configuração de auto ocultação após o uso e salva em 'keyboard1'
keyboard1="$(ShellBot.ReplyKeyboardMarkup --button 'botao' --one_time_keyboard true)"

while :
do
	# Obtem as atualizações
	ShellBot.getUpdates --limit 100 --offset $(ShellBot.OffsetNext) --timeout 30
	
	# Lista o índice das atualizações
	for id in $(ShellBot.ListUpdates)
	do
	# Inicio thread
	(
		# Verifica se a mensagem enviada pelo usuário é um comando válido.
		case ${message_text[$id]} in
			"/key")	# bot comando
				# Envia a mensagem anexando o teclado "$keyboard1"
				ShellBot.sendMessage --chat_id ${message_chat_id[$id]} --text '*Teclado numérico*' \
																		--reply_markup "$keyboard1" \
																		--parse_mode markdown 
			;;
		esac
	) & # Utilize a thread se deseja que o bot responda a várias requisições simultâneas.
	done
done
#FIM
