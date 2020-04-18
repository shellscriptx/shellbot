#!/bin/bash
#

# Importando API
source ShellBot.sh

# Token do bot
bot_token='371714654:AAF1Vujtoi81zjwFjpb-qdGJFspK0HuwUD0'

# Inicializando o bot
ShellBot.init --token "$bot_token" --monitor --return map --flush

readonly ICON_ARROW_DOWN='\U2B07'
readonly ICON_OUTBOX='\U1F4E4'
readonly ICON_CLIPBOARD='\U1F4CB'
readonly ICON_HOUSE='\U1F3E0'
readonly ICON_CLOCK='\U23F0'

function form_aviso()
{
	local btn=
	
	ShellBot.InlineKeyboardButton --button 'btn' --line 1 --text "$ICON_CLIPBOARD Aviso" --callback_data 'btn_aviso'
	ShellBot.InlineKeyboardButton --button 'btn' --line 2 --text "$ICON_HOUSE Cidade" --callback_data 'btn_cidade'
	ShellBot.InlineKeyboardButton --button 'btn' --line 3 --text "$ICON_CLOCK Previsão" --callback_data 'btn_previsao'
	ShellBot.InlineKeyboardButton --button 'btn' --line 4 --text "$ICON_OUTBOX Enviar" --callback_data 'btn_enviar'

	ShellBot.sendMessage	--chat_id ${message_chat_id[$id]} \
							--text 'Selecione todas as opções do formulário.' \
							--parse_mode markdown \
							--reply_markup "$(ShellBot.InlineKeyboardMarkup --button 'btn')"

	return 0
}

function btn_aviso()
{
	local avisos aviso btn

	btn=
	avisos=('Ligar' 'Desligar')

	echo "${callback_query_message_reply_markup_inline_keyboard_text[$id]}" > /tmp/${callback_query_id[$id]}

	for aviso in "${avisos[@]}"; do
		ShellBot.InlineKeyboardButton --button 'btn' --line $((++c)) --text "$aviso" --callback_data 'form_aviso'
	done

	ShellBot.sendPhoto --chat_id ${callback_query_message_chat_id[$id]} --photo '@ShellBot.png'

	ShellBot.editMessageText	--chat_id ${callback_query_chat_id[$id]} \
								--message_id ${callback_query_message_message_id[$id]} \
								--parse_mode markdown
	
	
}

while :
do
	# Obtem as atualizações
	ShellBot.getUpdates --limit 100 --offset $(ShellBot.OffsetNext) --timeout 30
	
	# Lista o índice das atualizações
	for id in $(ShellBot.ListUpdates)
	do
	# Inicio thread
	(
		# Se a mensagem enviada é uma url.
		case ${message_text[$id]} in
			'/aviso') form_aviso; continue;;
		esac

		# Envia notificação.
		${callback_query_id[$id]:+ShellBot.answerCallbackQuery --callback_query_id ${callback_query_id[$id]} --text 'Tudo certo jovem' --show_alert true}

		case ${callback_query_data[$id]} in
			'btn_aviso') btn_aviso;;
		esac

	) & # Utilize a thread se deseja que o bot responda a várias requisições simultâneas.
	done
done
#FIM
