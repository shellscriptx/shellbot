#!/bin/bash
#
# script: InlineKeyboard.sh
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

# Limpa o array que irá receber a estrutura inline_button e suas configurações.
botao1=''

# INLINE_BUTTON - CONFIGURAÇÕES.
#
# Cria e define as configurações do objeto inline_button,
# armazenando-as na variável 'botao1'.
# O parâmetro '-l, --line' determinada a posição do objeto na exibição.
# É possível especificar um ou mais botões na mesma linha. Neste caso
# os serão redimencionados e dispostos em paralelo.
#
# Layout defino abaixo:
#
#   [                  Blog                 ]  	-> linha 1
#   [ Telegram (Grupo) ] [ Telegram (Canal) ]   -> linha 2
#   [                 Github                ]	-> linha 3
#
#
# 
# Quando um botão é pressionado o usuário é redirecionado para o endereço configurando em '--url'
ShellBot.InlineKeyboardButton --button 'botao1' --line 1 --text 'Blog' --callback_data '1' --url 'http://shellscriptx.blogspot.com.br' 		# linha 1
ShellBot.InlineKeyboardButton --button 'botao1' --line 2 --text 'Telegram (Grupo)' --callback_data '3' --url 't.me/shellscript_x'			# linha 2
ShellBot.InlineKeyboardButton --button 'botao1' --line 2 --text 'Telegram (Canal)' --callback_data '4' --url 't.me/shellscriptx'			# linha 2
ShellBot.InlineKeyboardButton --button 'botao1' --line 3 --text 'Github' --callback_data '5' --url 'https://github.com/shellscriptx'		# linha 3

# Cria o objeto inline_keyboard contendo os elementos armazenados na variável 'botao1'
# É retornada a nova estrutura e armazena em 'keyboard1'.
keyboard1="$(ShellBot.InlineKeyboardMarkup -b 'botao1')"

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
			"/sigame")	# bot comando
				# Envia a mensagem anexando o teclado "$keyboard1"
				ShellBot.sendMessage --chat_id ${message_chat_id[$id]} --text '*Siga-me*' \
																		--reply_markup "$keyboard1" \
																		--parse_mode markdown 
			;;
		esac
	) & # Utilize a thread se deseja que o bot responda a várias requisições simultâneas.
	done
done
#FIM
