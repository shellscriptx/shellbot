#!/bin/bash
#
# script: MessageRules2.sh
#
# XXX SOBRE XXX
# 
# O código abaixo demonstra como implementar um mecanismo genérico
# e dinámico de autenticação na validação de regras.
# Os comandos administrativos permitem adicionar e remover permissões
# de usuários sem reinicializar o bot para atualização das regras.
# 
# XXX REQUERIMENTOS XXX
#
# O exemplo requer dois arquivos no diretório base onde
# serão inseridos os usuários, são eles:
#
# users - Usuários que tem permissão para chamar ajuda do bot.
# admins - Administradores que podem chamar todos os comandos do bot.
#          (Requer no mínimo um usuário para execução dos comandos.)
#
# Obs: os arquivos devem conter um usuário por linha. 
# (Comentários são suportados)
#
# Exemplo: 
#	admin_id # isso é um comentário.
#	admin_name # outro comentário.
#   # admin  // linha ignorada.

# Importando API
source ShellBot.sh

# Token do bot
bot_token='<TOKEN_AQUI>'

# Inicializando o bot
ShellBot.init --token "$bot_token" --return map --monitor

# Funções
function bot_help()
{
	local text

	text=$(cat << _eof
*\U2753 AJUDA \U2753*

/useradd <user> [<comment>] - Adiciona usuário.
/userdel <user> - Remove usuário.
/userlist - lista os usuários cadatrados.
/delall - excluir todas as contas.
/help - Exibe ajuda.
_eof
)

	ShellBot.sendMessage	--chat_id ${message_chat_id[$id]} \
							--text "$text" \
							--parse_mode markdown

	return 0
}

function user_add()
{
	if grep -qw "^$2" "$PWD/users"; then
		ShellBot.sendMessage	--chat_id ${message_chat_id[$id]} \
								--reply_to_message_id ${message_message_id[$id]} \
								--text "*\U1F464 $2\n\U26A0 Usuário já existe.*" \
								--parse_mode markdown
	else
		# Atualiza a base de usuários.
		echo "$2 # ${*:3}" >> "$PWD/users"
	
		# Notificação.
		ShellBot.sendMessage	--chat_id ${message_chat_id[$id]} \
								--reply_to_message_id ${message_message_id[$id]} \
-								--text "*\U1F464 $2\n\U2705 Usuário adicionado com sucesso!!*" \
								--parse_mode markdown
	fi

	return 0
}

function user_del()
{
	if grep -qw "^$2" "$PWD/users"; then
		# Remove usuário.
		sed -i "/^$2 /d" "$PWD/users"
	
		ShellBot.sendMessage	--chat_id ${message_chat_id[$id]} \
								--reply_to_message_id ${message_message_id[$id]} \
-								--text "*\U1F464 $2\n\U26D4 Usuário removido com sucesso!!*" \
								--parse_mode markdown
	else
		ShellBot.sendMessage	--chat_id ${message_chat_id[$id]} \
								--reply_to_message_id ${message_message_id[$id]} \
								--text "*\U1F464 $2\n\U26A0 Usuário não encontrado.*" \
								--parse_mode markdown
	fi

	return 0
}

function user_list()
{
	local user comm header

	header='*\U1F465 USUÁRIOS \U1F465*'

	while read -r user comm; do
		# Ignora usuários desativados.
		[[ ${user###*} ]] || continue

		text+="\U1F464 [@$user]\n\U1F4CB ${comm##+([# ])}\n\n"
	done < "$PWD/users"

	ShellBot.sendMessage	--chat_id ${message_chat_id[$id]} \
							--reply_to_message_id ${message_message_id[$id]} \
							--text "${header}\n\n${text:-*\U26A0 Nâo há usuários cadastrados.*}" \
							--parse_mode markdown

	return 0
}

# Regras
# Nega todas requisições de usuários não cadastrados.
ShellBot.setMessageRules 	--name 'USERS_DENIED' \
							--auth_file "!($PWD/admins,$PWD/users)"

# Envia ação padrão do bot (digitando...) e continua verificando as regras.
ShellBot.setMessageRules	--name 'BOT_ACTION' \
							--bot_action 'typing' \
							--continue

# Administradores
#
# Obs: O uso da expressão em '--num_args' força o
# comando 'useradd' a suportar 2 ou mais argumentos
# que inclui uma expressão variática para os comentários.
ShellBot.setMessageRules	--name 'ADMIN_ADD_USER' \
							--auth_file "$PWD/admins" \
							--command '/useradd' \
							--num_args '[2-9]|[1-9]+([0-9])' \
							--action 'user_add'

ShellBot.setMessageRules 	--name 'ADMIN_DEL_USER' \
							--auth_file "$PWD/admins" \
							--command '/userdel' \
							--num_args 2 \
							--action 'user_del'

ShellBot.setMessageRules	--name 'ADMIN_LIST_USERS' \
							--auth_file "$PWD/admins" \
							--command '/userlist' \
							--action 'user_list'

ShellBot.setMessageRules	--name 'ADMIN_DEL_ALL' \
							--auth_file "$PWD/admins" \
							--command '/delall' \
							--exec "> $PWD/users" \
							--bot_reply_message '*\U274C Todos os usuários foram removidos!! \U274C*' \
							--bot_parse_mode markdown
# Usuários
ShellBot.setMessageRules 	--name 'USER_HELP' \
							--command '/help' \
							--action 'bot_help'

# Mensagem de erro.
ShellBot.setMessageRules 	--name 'COMMAND_NOT_FOUND' \
							--bot_reply_message '*\U26A0 Comando não encontrado ou requer argumentos.*' \
							--bot_parse_mode markdown

# Padrão
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
