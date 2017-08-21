#!/bin/bash

# script: WelcomeBot.sh
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

# boas vindas
msg_bem_vindo()
{
	local msg

	# Texto da mensagem
	msg="🆔 [@${message_new_chat_member_username[$id]:-null}]\n"
    msg+="🗣 Olá *${message_new_chat_member_first_name[$id]}*"'!!\n\n'
    msg+="Seja bem-vindo(a) ao *${message_chat_title[$id]}*.\n\n"
    msg+='`Se precisar de ajuda ou informações sobre meus comandos, é só me chamar no privado.`'"[@$(ShellBot.username)]"

	# Envia a mensagem de boas vindas.
	ShellBot.sendMessage --chat_id ${message_chat_id[$id]} \
							--text "$(echo -e $msg)" \
							--parse_mode markdown

	return 0	
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
		# Chama a função 'msg_bem_vindo' se o valor de 'message_new_chat_member_id' não for nulo.
		[[ ${message_new_chat_member_id[$id]} ]] && msg_bem_vindo

		# Verifica se a mensagem enviada pelo usuário é um comando válido.
		case ${message_text[$id]} in
			*)
				:
				# <BOT COMANDOS> ...
			;;
		esac
	) & # Utilize a thread se deseja que o bot responda a várias requisições simultâneas.
	done
done
#FIM
