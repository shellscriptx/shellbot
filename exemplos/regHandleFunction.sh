#!/bin/bash

# script: regHandleFunction.sh
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

# Mensagem de ajuda
exibir_ajuda()
{
	msg="Olá *${callback_query_from_username[$id]}* , em que posso ajudar?\n"
	msg+="No momento minhas opções são limitadas, mas farei o possível."

	# Envia uma notificação em resposta ao botão pressionado.
	ShellBot.answerCallbackQuery --callback_query_id ${callback_query_id[$id]} \
									--text "Ajuda"
	# Envia mensagem
	ShellBot.sendMessage --chat_id ${callback_query_message_chat_id[$id]} \
							--text "$(echo -e $msg)" \
							--parse_mode markdown
		
							
	# retorno
	return 0
}

# Envia mensagem contendo informações sobre o bot
exibir_info()
{
	msg="*Sobre mim*\n\n"
	msg+="id: [$(ShellBot.id)]\n"
	msg+="username: [@$(ShellBot.username)]\n"
	msg+="firstname: [$(ShellBot.first_name)]"
	
	# Envia uma notificação em resposta ao botão pressionado.
	ShellBot.answerCallbackQuery --callback_query_id ${callback_query_id[$id]} \
									--text "Sobre mim"
	# Envia mensagem
	ShellBot.sendMessage --chat_id ${callback_query_message_chat_id[$id]} \
							--text "$(echo -e $msg)" \
							--parse_mode markdown

	# retorno
	return 0
}

# Botões
#
# [ Ajuda ]		
# [ Sobre mim ]
#
# limpa
unset botao1
# Define as configurações e atribui os valores de retorno (callback_data) para cada botão.
# Sempre que um InlineButton é pressionado pelo usuário, o valor definido no parâmetro 'callback_data'
# é retornado e armazenado na variável 'callback_query_data'.
ShellBot.InlineKeyboardButton --button 'botao1' --line 1 --text 'Ajuda' --callback_data 'btn_help' 			# valor: btn_help
ShellBot.InlineKeyboardButton --button 'botao1' --line 2 --text 'Sobre mim' --callback_data 'btn_about'		# varor: btn_about

# Registra o nome da função associando-a ao valor de 'callback_data'.
# [ ajuda ]     -> btn_help  -> exibir_ajuda
# [ Sobre mim ] -> btn_about -> exibir_info
ShellBot.regHandleFunction --function exibir_ajuda --callback_data btn_help
ShellBot.regHandleFunction --function exibir_info --callback_data btn_about

# limpa
unset keyboard1
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
		# Monitora as funções registradas por 'regHandleFunction'.
		# Se o valor de 'callback_query_data' for igual a um valor
		# associado a uma função, a mesma é chamada.
		ShellBot.watchHandle --callback_data ${callback_query_data[$id]} 
	
		# Verifica se a mensagem enviada pelo usuário é um comando válido.
		case ${message_text[$id]} in
			"/bot")	# bot comando
				# Envia a mensagem anexando o teclado "$keyboard1"
				ShellBot.sendMessage --chat_id ${message_chat_id[$id]} --text '*Inicio*' \
																		--reply_markup "$keyboard1" \
																		--parse_mode markdown 
			;;
		esac
    ) & # Utilize a thread se deseja que o bot responda a várias requisições simultâneas.
	done
done
#FIM
