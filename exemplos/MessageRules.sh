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

# FUNÇÕES (AÇÃO)
#
# AS FUNÇÕES DEVEM SER DECLARADAS PREVIAMENTE ANTES DE SEREM
# VINCULADAS AS REGRAS.
#
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
# XXX ATENÇÃO XXX
#
# AS REGRAS SÃO TRATADAS SEQUÊNCIALMENTE NA ORDEM EM QUE FORAM DEFINIDAS, CASO
# A MENSAGEM SATISFAÇA AO CONJUNTO DE CRITÉRIOS ESTABELECIDOS NA REGRA, A AÇÃO É
# APLICADA (SE PRESENTE) E SALTA PARA A PRÓXIMA REQUISIÇÃO.
#

# Criando duas regras sem ação que envia uma mensagem informativa sobre o horário
# de atendimento e ignora todas as requisições enviadas ao bot fora do dia/horário.

# Texto informativo
msg_info='Lamento, mas o horário para atendimento é das 8:00 às 18:00 de segunda à sexta.'

# Finais de semana em qualquer horário.
ShellBot.setMessageRules	--name 'bot_horario_operacao1' \
							--weekday 6 \
							--weekday 7 \
							--bot_reply_message "$msg_info"

# Dias da semana fora do horário operacional.
ShellBot.setMessageRules	--name 'bot_horario_operacao2' \
							--time '00:00-08:00,18:00-23:59' \
							--weekday '1,2,3,4,5' \
							--bot_reply_message "$msg_info"

# Define o comando e a quantidade de argumentos aceitos na mensagem.
# ex: /userinfo <usuario>
#         |        |
#       arg1      arg2
ShellBot.setMessageRules	--name 'ver_membro' \
							--user_status administrator

ShellBot.setMessageRules	--name 'obter_informacoes_do_usuario' \
							--action usuario_info \
							--command '/userinfo' \
							--num_args 2
							
# Liberar o comando 'ping' para uma lista de usuários em horários especificos.
ShellBot.setMessageRules	--name 'pingar_host' \
							--action ping_host \
							--command '/ping' \
							--username 'x_SHAMAN_x,admin1,admin2' \
							--time '12:00-14:30'
							
# Apagar as mensagens de divulgação em um grupo/super-grupo.
ShellBot.setMessageRules	--name 'apagar_postagem_de_grupos' \
							--action apagar_grupo_url \
							--entitie_type url \
							--chat_type 'supergroup,group' \
							--text 't.me/[a-zA-Z0-9_]+'

# Envia mensagem de boas-vindas ao usuário no momento que ingressar ao grupo.
ShellBot.setMessageRules	--name 'mensagem_boas_vindas' \
							--action msg_bem_vindo \
							--chat_type 'supergroup,group' \
							--chat_member new

# Envia mensagem de despedida quando o usuário deixar o grupo.
ShellBot.setMessageRules	--name 'mensagem_despedida' \
							--action msg_despedida \
							--chat_type 'supergroup,group' \
							--chat_member left

# Apagar todos os arquivos executaveis enviados entre 01:00 e 06:00 da manhã no mês de dezembro.
ShellBot.setMessageRules	--name 'apagar_executaveis' \
							--action apagar_msg	\
							--chat_type 'supergroup,group' \
							--date '01/12/2018-31/12/2018' \
							--time '01:00-06:00' \
							--mime_type 'application/x-executable'

# Apagar todas as fotos postadas no final de semana.
ShellBot.setMessageRules	--name 'apagar_fotos_final_de_semana' \
							--action apagar_msg \
							--chat_type 'supergroup,group' \
							--file_type photo \
							--weekday '6,7'

# Notifica o usuário sempre que o mesmo postar uma foto no grupo ou super-grupo.
ShellBot.setMessageRules	--name 'postagem_fotos' \
							--mime_type 'image/jpeg' \
							--chat_type 'supergroup,group' \
							--bot_reply_message 'Evite postar fotos no grupo, obrigado.'

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
