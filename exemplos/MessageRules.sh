#!/bin/bash
#
# script: MessageRules.sh
#
# Para melhor compreensão foram utilizados parâmetros longos nas funções; Podendo
# ser substituidos pelos parâmetros curtos respectivos.

# Importando API
source ShellBot.sh

# Token do bot
bot_token='<TOKEN_AQUI>'

# Inicializando o bot
ShellBot.init --token "$bot_token" --monitor --flush
ShellBot.username

# AÇÕES
# Definindo as funções que serão vinculadas as regras de ação.

apagar_grupo_url(){
	ShellBot.deleteMessage	--chat_id ${message_chat_id[$id]} \
							--message_id ${message_message_id[$id]}

	ShellBot.sendMessage 	--chat_id ${message_chat_id[$id]} \
							--text "Prezado [@${message_from_username[$id]}], não é permitido a divulgação de grupos/canais."  \
							--parse_mode markdown
}

ping_host(){
	ShellBot.sendMessage	--chat_id ${message_chat_id[$id]} \
							--text "$(ping -c4 ${message_text[$id]#* })"
}

msg_bem_vindo(){
	ShellBot.sendMessage	--chat_id ${message_chat_id[$id]} \
							--text "Seja bem vindo(a) [@${message_new_chat_member_username[$id]}] "'!!' \
							--parse_mode markdown
}

msg_despedida(){
	ShellBot.sendMessage	--chat_id ${message_chat_id[$id]} \
							--text "Tchau [@${message_left_chat_member_username[$id]}], esperamos que volte em breve." \
							--parse_mode markdown
}

apagar_msg(){
	ShellBot.deleteMessage 	--chat_id ${message_chat_id[$id]} \
							--message_id ${message_message_id[$id]}
}

usuario_info(){
	# A função recebe como argumento posicional os elementos contidos na
	# mensagem, onde '$2' contém o nome do usuário a ser consultado.
	ShellBot.sendMessage --chat_id ${message_chat_id[$id]} --text "$(id $2)"
}

# REGRAS
#

# Define o comando e a quantidade de argumentos aceitos na mensagem.
# ex: /userinfo <usuario>
#         |        |
#       arg1      arg2
ShellBot.setMessageRules	--action usuario_info \
							--command '/userinfo' \
							--num_args 2
							
# Liberar o comando 'ping' para uma lista de usuários em horários especificos.
ShellBot.setMessageRules	--action ping_host \
							--command '/ping' \
							--username 'x_SHAMAN_x' \
							--username 'x_admin1' \
							--username 'x_admin2' \
							--time '12:00-14:30'
							
# Apagar as mensagens de divulgação em um grupo/super-grupo.
ShellBot.setMessageRules	--action apagar_grupo_url \
							--entitie_type url \
							--chat_type supergroup \
							--chat_type group \
							--text 't.me/[a-zA-Z0-9_]+'

# Envia mensagem de boas-vindas ao usuário no momento que ingressar ao grupo.
ShellBot.setMessageRules	--action msg_bem_vindo \
							--chat_type supergroup \
							--chat_type group \
							--chat_member new

# Envia mensagem de despedida quando o usuário deixar o grupo.
ShellBot.setMessageRules	--action msg_despedida \
							--chat_type supergroup \
							--chat_type group \
							--chat_member left

# Apagar todos os arquivos executaveis enviados entre 01:00 e 06:00 da manhã no mês de dezembro.
ShellBot.setMessageRules	--action apagar_msg	\
							--chat_type supergroup \
							--chat_type group \
							--date '01/12/2018-31/12/2018' \
							--time '01:00-06:00' \
							--mime_type 'application/x-executable'

# Apagar todas as fotos postadas no final de semana.
ShellBot.setMessageRules	--action apagar_msg \
							--chat_type supergroup \
							--chat_type group \
							--file_type photo \
							--weekday 6 \
							--weekday 7

while :
do
	# Obtem as atualizações
	ShellBot.getUpdates --limit 100 --offset $(ShellBot.OffsetNext) --timeout 30
	
	# Lista o índice das atualizações
	for id in $(ShellBot.ListUpdates)
	do
	# Inicio thread
	(
		# Gerenciar regras
		ShellBot.manageRules --update_id $id
		
	) & # Utilize a thread se deseja que o bot responda a várias requisições simultâneas.
	done
done
#FIM
