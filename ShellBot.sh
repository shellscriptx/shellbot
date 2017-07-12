#!/bin/bash

#-----------------------------------------------------------------------------------------------------------
#	Data:				07 de Março de 2017
#	Script:				ShellBot.sh
#	Versão:				4.2 
#	Desenvolvido por:	Juliano Santos [SHAMAN]
#	Página:				http://www.shellscriptx.blogspot.com.br
#	Fanpage:			https://www.facebook.com/shellscriptx
# 	Contato:			shellscriptx@gmail.com
#	Descrição:			O script é uma API genérica desenvolvida para facilitar	a criação de 
#						bots na plataforma TELEGRAM. A API contém funções relevantes
#						para o desenvolvimento; Mantendo a nomenclatura dos métodos registrados da
#						API original (Telegram), assim como seus campos e valores.
#						As funções instanciadas requerem parâmetros e argumentos para a chamada
#						do respectivo método.
#-----------------------------------------------------------------------------------------------------------

# Verifica se a API já foi instanciada.
[[ $_SHELLBOT_SH_ ]] && return 1

# Verifica se os pacotes necessários estão instalados.
for _PKG_ in curl jq; do
	# Se estiver ausente, trata o erro e finaliza o script.
	if ! which $_PKG_ &>/dev/null; then
		echo "ShellBot.sh: erro: '$_PKG_' O pacote requerido não está instalando." 1>&2
		exit 1	# Status
	fi
done

# Desabilitar globbing
set -f

declare -r _SHELLBOT_SH_=1		# API inicializada.
declare -r _BOT_SCRIPT_=$(basename "$0")

# Diretório temporário onde são gerados os arquivos json (JavaSCript Object Notation) sempre que um método é chamado. 
_TMP_DIR_=$(mktemp -q -d --tmpdir=/tmp ${_BOT_SCRIPT_%%.*}-XXXXXXXXXX) || {
	echo "ShellBot: erro: não foi possível criar o diretório JSON em '/tmp'" 1>&2
	echo "verifique se o diretório existe ou se possui permissões de escrita e tente novamente." 1>&2
	exit 1
} 

declare -r _TMP_DIR_ 

# Define a linha de comando para as chamadas GET e PUT do métodos da API via curl.
declare -r _GET_='curl --silent --request GET --url'
declare -r _POST_='curl --silent --request POST --url'
 
# Funções para extração dos objetos armazenados no arquivo "update.json"
# 
# Verifica o retorno após a chamada de um método, se for igual a true (sucesso) retorna 0, caso contrário, retorna 1
json() { jq -r "${*:2}" $1 2>/dev/null; }
json_status(){ [[ $(json $1 '.ok') != false ]] && return 0 || return 1; }
getFileJQ(){ echo $_TMP_DIR_/${1#*.}.json; return 0; } # Gera nomenclatura dos arquivos json.

# Remove diretório JSON se o script for interrompido.
trap "rm -rf $_TMP_DIR_ &>/dev/null; exit 1" SIGQUIT SIGINT SIGKILL SIGTERM SIGSTOP SIGPWR

# Erros registrados da API (Parâmetros/Argumentos)
declare -r _ERR_TYPE_BOOL_='tipo incompatível. Somente "true" ou "false".'
declare -r _ERR_TYPE_PARSE_MODE_='tipo incompatível. Somente "markdown" ou "html".'
declare -r _ERR_TYPE_INT_='tipo incompatível. Somente inteiro.'
declare -r _ERR_TYPE_FLOAT_='tipo incompatível. Somente float.'
declare -r _ERR_ACTION_MODE_='tipo da ação inválida.'
declare -r _ERR_PARAM_INVALID_='parâmetro inválido.'
declare -r _ERR_PARAM_REQUIRED_='parâmetro/argumento requerido.'
declare -r _ERR_TOKEN_='não autorizado. Verifique o número do TOKEN ou se possui privilégios.'
declare -r _ERR_INVALID_TOKEN_='número do TOKEN inválido.'
declare -r _ERR_FUNCTION_NOT_FOUND_='nome da função inválida ou não existe.'

# Trata os erros
message_error()
{
	# Variáveis locais
	local err_message err_code err_description assert jq_file

	# A variável 'BASH_LINENO' é dinâmica e armazena o número da linha onde foi expandida.
	# Quando chamada dentro de um subshell, passa ser instanciada como um array, armazenando diversos
	# valores onde cada índice refere-se a um shell/subshell. As mesmas caracteristicas se aplicam a variável
	# 'FUNCNAME', onde é armazenado o nome da função onde foi chamada.
	local err_line=${BASH_LINENO[1]}	# Obtem o número da linha no shell pai.
	local err_func=${FUNCNAME[1]}		# Obtem o nome da função no shell pai.
	
	# Lê o tipo de ocorrência do erro.
	# TG - Erro externo, retornado pelo core do telegram
	# API - Erro interno, gerado pela API ShellBot.
	case $1 in
		TG)
			# arquivo json
			jq_file=${*: -1}
			
			err_code=$(json $jq_file '.error_code')
			err_description=$(json $jq_file '.description')
			err_message="${err_code:-1}: ${err_description:-ocorreu um problema durante a tentativa de atualização.}"
			;;
		API)
			# Insere um '-', caso o valor de '_ERR_PARAM_' e '_ERR_ARG_VALUE_' for nulo; Se não houver
			# mensagem de erro, imprime 'Erro desconhecido'
			err_message="${3:--}: ${4:--}: ${2:-erro desconhecido}"
			assert=1
			;;
	esac

	# Imprime mensagem de erro
	echo "$_BOT_SCRIPT_: linha ${err_line:--}: ${err_func:--}: $err_message" 1>&2

	# Finaliza script em caso de erro interno, caso contrário retorna 1
	[[ $assert ]] && exit 1 || return 1
}

ShellBot.ListUpdates(){ echo ${!update_id[@]}; }
ShellBot.TotalUpdates(){ echo ${#update_id[@]}; }
ShellBot.OffsetEnd(){ local -i _OFFSET_=${update_id[@]: -1}; echo $_OFFSET_; }
ShellBot.OffsetNext(){ echo $(($(ShellBot.OffsetEnd)+1)); }

ShellBot.regHandleFunction()
{
	local _FUNCTION_ _CALLBACK_DATA_ _HANDLE_ _ARGS_

	local _PARAM_=$(getopt --name $FUNCNAME --options 'f:a:d:' \
									--longoptions 'function:,
													args:,
													callback_data:' \
													-- "$@")

	eval set -- "$_PARAM_"
	
	while :
	do
		case $1 in
			-f|--function)
				# Verifica se a função especificada existe.
				if ! declare -fp $2 &>/dev/null; then
					message_error API "$_ERR_FUNCTION_NOT_FOUND_" "$1" "$2"
					return 1
				fi
				_FUNCTION_="$2"
				shift 2
				;;
			-a|--args)
				_ARGS_="$2"
				shift 2
				;;
			-d|--callback_data)
				_CALLBACK_DATA_="$2"
				shift 2
				;;
			--)
				shift
				break
				;;
		esac
	done
	
	[[ $_FUNCTION_ ]] || message_error API "$_ERR_PARAM_REQUIRED_" "[-f, --function]"
	[[ $_CALLBACK_DATA_ ]] || message_error API "$_ERR_PARAM_REQUIRED_" "[-d, --callback_data]"

	# Testa se o indentificador armazenado em _HANDLE_ já existe. Caso já exista, repete
	# o procedimento até que um handle válido seja gerado; Evitando sobreescrever handle's existentes.
	until ! declare -fp $_HANDLE_ &>/dev/null; do
		_HANDLE_=HandleID:$(tr -dc A-Za-z0-9_ < /dev/urandom | head -c15)
	done

	# Cria a função com o nome gerado e adiciona a chamada com os argumentos especificados.
	# Anexa o novo handle a lista no índice associativo definindo em _CALLBACK_DATA_	
	_FUNCTION_="$_HANDLE_(){ $_FUNCTION_ $_ARGS_; }"
	eval "$_FUNCTION_"
	
	declare -Ag _LIST_REG_FUNC_HANDLE_
	_LIST_REG_FUNC_HANDLE_[$_CALLBACK_DATA_]+="$_HANDLE_ "

	return 0
}

ShellBot.watchHandle()
{
	local 	_CALLBACK_DATA_ \
			_FUNC_HANDLE_ \
			_PARAM_=$(getopt --name $FUNCNAME --options 'd' --longoptions 'callback_data' -- "$@")

	eval set -- "$_PARAM_"

	while :
	do
		case $1 in
			-d|--callback_data)
				shift 2
				_CALLBACK_DATA_="$1"
				;;
			*)
				shift
				break
				;;
		esac
	done
	
	# O parâmetro callback_data é parcial, ou seja, Se o handle for válido, os elementos
	# serão listados. Caso contrário a função é finalizada.
	[[ $_CALLBACK_DATA_ ]] || return 1

	# Lista todos os handles no índice _CALLBACK_DATA_  e executa-os
	# consecutivamente. A ordem de execução das funções é determinada
	# pela ordem de declaração.
	for _FUNC_HANDLE_ in ${_LIST_REG_FUNC_HANDLE_[$_CALLBACK_DATA_]}; do 
		$_FUNC_HANDLE_; done	# executa

	# retorno
	return 0
}

ShellBot.getWebhookInfo()
{
	# Variável local
	local _METHOD_=getWebhookInfo	# Método
	local _JSON_=$(getFileJQ $FUNCNAME)
		
	# Chama o método getMe passando o endereço da API, seguido do nome do método.
	eval $_GET_ $_API_TELEGRAM_/$_METHOD_ > $_JSON_
	
	# Verifica o status de retorno do método
	json_status $_JSON_ && {
		# Retorna as informações armazenadas em "result".
		json $_JSON_ '.result|
						.url,
						.has_custom_certificate,
						.pending_update_count,
						.last_error_date,
						.last_error_message,
						.max_connections,
						.allowed_updates' | sed ':a;$!N;s/\n/|/;ta'

	} || message_error TG $_JSON_
	
	return $?
}

ShellBot.deleteWebhook()
{
	# Variável local
	local _METHOD_=deleteWebhook	# Método
	local _JSON_=$(getFileJQ $FUNCNAME)
		
	# Chama o método getMe passando o endereço da API, seguido do nome do método.
	eval $_POST_ $_API_TELEGRAM_/$_METHOD_ > $_JSON_
	
	# Verifica o status de retorno do método
	json_status $_JSON_ || message_error TG $_JSON_
	
	return $?
}

ShellBot.setWebhook()
{
	local _URL_ _CERTIFICATE_ _MAX_CONNECTIONS_ _ALLOWED_UPDATES_
	local _METHOD_=setWebhook
	local _JSON_=$(getFileJQ $FUNCNAME)
	
	local _PARAM_=$(getopt --name $FUNCNAME --options 'u:c:m:a' \
												--longoptions 'url:, 
																certificate:,
																max_connections:,
																allowed_updates:' \
																-- "$@")
	
	eval set -- "$_PARAM_"
	
	while :
	do
		case $1 in
			-u|--url)
				_URL_="$2"
				shift 2
				;;
			-c|--certificate)
				_CERTIFICATE_="$2"
				shift 2
				;;
			-m|--max_connections)
				[[ "$2" =~ ^[0-9]+$ ]] || message_error API "$_ERR_TYPE_INT_" "$1" "$2"
				_MAX_CONNECTIONS_="$2"
				shift 2
				;;
			-a|--allowed_updates)
				_ALLOWED_UPDATES_="$2"
				shift 2
				;;
			--)
				shift 
				break
				;;
		esac
	done
	
	[[ $_URL_ ]] || message_error API "$_ERR_PARAM_REQUIRED_" "[-u, --url]"

	eval $_POST_ $_API_TELEGRAM_/$_METHOD_ ${_URL_:+-d url="'$_URL_'"} \
						${_CERTIFICATE_:+-d certificate="'$_CERTIFICATE_'"} \
						${_MAX_CONNECTIONS_:+-d max_connections="'$_MAX_CONNECTIONS_'"} \
						${_ALLOWED_UPDATES_:+-d allowed_updates="'$_ALLOWED_UPDATES_'"} > $_JSON_

	# Testa o retorno do método.
	json_status $_JSON_ || message_error TG $_JSON_
	
	# Status
	return $?
}	

# Inicializa o bot, definindo sua API e TOKEN.
# Atenção: Essa função precisa ser instanciada antes de qualquer outro método.
ShellBot.init()
{
	# Variável local
	local _PARAM_=$(getopt --name $FUNCNAME --options 't:' \
										--longoptions 'token:' \
										-- "$@")
	
	# Define os parâmetros posicionais
	eval set -- "$_PARAM_"

	while :
	do
		case $1 in
			-t|--token)
				[[ $2 =~ ^[0-9]+:[a-zA-Z0-9-]+$ ]] || message_error API "$_ERR_INVALID_TOKEN_" "$1" "$2"
				declare -gr _TOKEN_="$2"											# TOKEN
				# Visível em todo shell/subshell
				declare -gr _API_TELEGRAM_=https://api.telegram.org/bot$_TOKEN_		# API
				shift 2
				;;
			--)
				shift
				break
				;;
		esac
	done

	# Parâmetro obrigatório.	
	[[ $_TOKEN_ ]] || message_error API "$_ERR_PARAM_REQUIRED_" "[-t, --token]"

	_BOT_INFO_=$(ShellBot.getMe 2>/dev/null) || message_error API "$_ERR_TOKEN_"
	
	# Define o delimitador entre os campos.
	IFSbkp=$IFS; IFS='|'
	
	# Inicializa um array somente leitura contendo as informações do bot.
	declare -gr _BOT_INFO_=($_BOT_INFO_)
	
	# Restaura o delimitador
	IFS=$IFSbkp

	# Constroi as funções para as chamdas aos atributos do bot.
	ShellBot.token() { echo "${_TOKEN_:-null}"; }
	ShellBot.id() { echo "${_BOT_INFO_[0]:-null}"; }
	ShellBot.username() { echo "${_BOT_INFO_[1]:-null}"; }
	ShellBot.first_name() { echo "${_BOT_INFO_[2]:-null}"; }
	ShellBot.last_name() { echo "${_BOT_INFO_[3]:-null}"; }
	
	# Somente leitura.
	declare -rf ShellBot.token
	declare -rf ShellBot.id
	declare -rf ShellBot.username
	declare -rf ShellBot.first_name
	declare -rf Shellbot.last_name
		
	# status
	return 0
}

ShellBot.setChatPhoto()
{
	local _CHAT_ID_ _PHOTO_
	local _METHOD_=setChatPhoto
	local _JSON_=$(getFileJQ $FUNCNAME)
	
	local _PARAM_=$(getopt --name $FUNCNAME --options 'c:p:' --longoptions 'chat_id:,photo:' -- "$@")
	
	eval set -- "$_PARAM_"
	
	while :
	do
		case $1 in
			-c|--chat_id)
				_CHAT_ID_="$2"
				shift 2
				;;
			-p|--photo)
				_PHOTO_="$2"
				shift 2
				;;
			--)
				shift
				break
				;;
		esac
	done
	
	[[ $_CHAT_ID_ ]] || message_error API "$_ERR_PARAM_REQUIRED_" "-c, --chat_id"
	[[ $_PHOTO_ ]] || message_error API "$_ERR_PARAM_REQUIRED_" "-p, --photo"
	
	eval $_POST_ $_API_TELEGRAM_/$_METHOD_ ${_CHAT_ID_:+-F chat_id="'$_CHAT_ID_'"} \
											${_PHOTO_:+-F photo="'$_PHOTO_'"} > $_JSON_

	json_status $_JSON_ || message_error TG $_JSON_
		
	# Status
	return $?
}

ShellBot.deleteChatPhoto()
{
	local _CHAT_ID_
	local _METHOD_=deleteChatPhoto
	local _JSON_=$(getFileJQ $FUNCNAME)
	
	local _PARAM_=$(getopt --name $FUNCNAME --options 'c:' --longoptions 'chat_id:' -- "$@")
	
	eval set -- "$_PARAM_"
	
	while :
	do
		case $1 in
			-c|--chat_id)
				_CHAT_ID_="$2"
				shift 2
				;;
			--)
				shift
				break
				;;
		esac
	done
	
	[[ $_CHAT_ID_ ]] || message_error API "$_ERR_PARAM_REQUIRED_" "-c, --chat_id"
	
	eval $_POST_ $_API_TELEGRAM_/$_METHOD_ ${_CHAT_ID_:+-d chat_id="'$_CHAT_ID_'"} > $_JSON_

	json_status $_JSON_ || message_error TG $_JSON_
		
	# Status
	return $?

}

ShellBot.setChatTitle()
{
	
	local _CHAT_ID_ _TITLE_
	local _METHOD_=setChatTitle
	local _JSON_=$(getFileJQ $FUNCNAME)
	
	local _PARAM_=$(getopt --name $FUNCNAME --options 'c:t:' --longoptions 'chat_id:,title:' -- "$@")
	
	eval set -- "$_PARAM_"
	
	while :
	do
		case $1 in
			-c|--chat_id)
				_CHAT_ID_="$2"
				shift 2
				;;
			-t|--title)
				_TITLE_="$2"
				shift 2
				;;
			--)
				shift
				break
				;;
		esac
	done
	
	[[ $_CHAT_ID_ ]] || message_error API "$_ERR_PARAM_REQUIRED_" "-c, --chat_id"
	[[ $_TITLE_ ]] || message_error API "$_ERR_PARAM_REQUIRED_" "-t, --title"
	
	eval $_POST_ $_API_TELEGRAM_/$_METHOD_ ${_CHAT_ID_:+-d chat_id="'$_CHAT_ID_'"} \
											${_TITLE_:+-d title="'$_TITLE_'"} > $_JSON_

	json_status $_JSON_ || message_error TG $_JSON_
		
	# Status
	return $?
}


ShellBot.setChatDescription()
{
	
	local _CHAT_ID_ _DESCRIPTION_
	local _METHOD_=setChatDescription
	local _JSON_=$(getFileJQ $FUNCNAME)
	
	local _PARAM_=$(getopt --name $FUNCNAME --options 'c:d:' --longoptions 'chat_id:,description:' -- "$@")
	
	eval set -- "$_PARAM_"
	
	while :
	do
		case $1 in
			-c|--chat_id)
				_CHAT_ID_="$2"
				shift 2
				;;
			-d|--description)
				_DESCRIPTION_="$2"
				shift 2
				;;
			--)
				shift
				break
				;;
		esac
	done
	
	[[ $_CHAT_ID_ ]] || message_error API "$_ERR_PARAM_REQUIRED_" "-c, --chat_id"
	[[ $_DESCRIPTION_ ]] || message_error API "$_ERR_PARAM_REQUIRED_" "-d, --description"
	
	eval $_POST_ $_API_TELEGRAM_/$_METHOD_ ${_CHAT_ID_:+-d chat_id="'$_CHAT_ID_'"} \
											${_DESCRIPTION_:+-d description="'$_DESCRIPTION_'"} > $_JSON_

	json_status $_JSON_ || message_error TG $_JSON_
		
	# Status
	return $?
}

ShellBot.pinChatMessage()
{
	
	local _CHAT_ID_ _MESSAGE_ID_ _DISABLE_NOTIFICATION_
	local _METHOD_=pinChatMessage
	local _JSON_=$(getFileJQ $FUNCNAME)
	
	local _PARAM_=$(getopt --name $FUNCNAME --options 'c:m:n:' --longoptions 'chat_id:,
																				message_id:,
																				disable_notification:' \
																				-- "$@")
	
	eval set -- "$_PARAM_"
	
	while :
	do
		case $1 in
			-c|--chat_id)
				_CHAT_ID_="$2"
				shift 2
				;;
			-m|--message_id)
				[[ "$2" =~ ^[0-9]+$ ]] || message_error API "$_ERR_TYPE_INT_" "$1" "$2"
				_MESSAGE_ID_="$2"
				shift 2
				;;
			-n|--disable_notification)
				[[ "$2" =~ ^(true|false)$ ]] || message_error API "$_ERR_TYPE_BOOL_" "$1" "$2"
				_DISABLE_NOTIFICATION_="$2"
				shift 2
				;;	
			--)
				shift
				break
				;;
		esac
	done
	
	[[ $_CHAT_ID_ ]] || message_error API "$_ERR_PARAM_REQUIRED_" "-c, --chat_id"
	[[ $_MESSAGE_ID_ ]] || message_error API "$_ERR_PARAM_REQUIRED_" "-m, --message_id"
	
	eval $_POST_ $_API_TELEGRAM_/$_METHOD_ ${_CHAT_ID_:+-d chat_id="'$_CHAT_ID_'"} \
											${_MESSAGE_ID_:+-d message_id="'$_MESSAGE_ID_'"} \
											${_DISABLE_NOTIFICATION_:+-d disable_notification="'$_DISABLE_NOTIFICATION_'"} > $_JSON_

	json_status $_JSON_ || message_error TG $_JSON_
		
	# Status
	return $?
}

ShellBot.unpinChatMessage()
{
	local _CHAT_ID_
	local _METHOD_=unpinChatMessage
	local _JSON_=$(getFileJQ $FUNCNAME)
	
	local _PARAM_=$(getopt --name $FUNCNAME --options 'c:' --longoptions 'chat_id:' -- "$@")
	
	eval set -- "$_PARAM_"
	
	while :
	do
		case $1 in
			-c|--chat_id)
				_CHAT_ID_="$2"
				shift 2
				;;
			--)
				shift
				break
				;;
		esac
	done
	
	[[ $_CHAT_ID_ ]] || message_error API "$_ERR_PARAM_REQUIRED_" "-c, --chat_id"
	
	eval $_POST_ $_API_TELEGRAM_/$_METHOD_ ${_CHAT_ID_:+-d chat_id="'$_CHAT_ID_'"} > $_JSON_

	json_status $_JSON_ || message_error TG $_JSON_
		
	# Status
	return $?
}

ShellBot.restrictChatMember()
{
	local	_CHAT_ID_ _USER_ID_ _UNTIL_DATE_ _CAN_SEND_MESSAGES_ \
			_CAN_SEND_MEDIA_MESSAGES_ _CAN_SEND_OTHER_MESSAGES_ \
			_CAN_ADD_WEB_PAGE_PREVIEWS_

	local _METHOD_=restrictChatMember
	local _JSON_=$(getFileJQ $FUNCNAME)
	
	local _PARAM_=$(getopt --name $FUNCNAME --options 'c:u:d:s:m:o:w:' \
												--longoptions 'chat_id:,
																user_id:,
																until_date:,
																can_send_messages:,
																can_send_media_messages:,
																can_send_other_messages:,
																can_add_web_page_previews:' -- "$@")
	
	eval set -- "$_PARAM_"
	
	while :
	do
		case $1 in
			-c|--chat_id)
				_CHAT_ID_="$2"
				shift 2
				;;
			-u|--user_id)
				[[ "$2" =~ ^[0-9]+$ ]] || message_error API "$_ERR_TYPE_INT_" "$1" "$2"
				_USER_ID_="$2"
				shift 2
				;;
			-d|--until_date)
				[[ "$2" =~ ^[0-9]+$ ]] || message_error API "$_ERR_TYPE_INT_" "$1" "$2"
				_UNTIL_DATE_="$2"
				shift 2
				;;
			-s|--can_send_messages)
				[[ "$2" =~ ^(true|false)$ ]] || message_error API "$_ERR_TYPE_BOOL_" "$1" "$2"
				_CAN_SEND_MESSAGES_="$2"
				shift 2
				;;
			-m|--can_send_media_messages)
				[[ "$2" =~ ^(true|false)$ ]] || message_error API "$_ERR_TYPE_BOOL_" "$1" "$2"
				_CAN_SEND_MEDIA_MESSAGES_="$2"
				shift 2
				;;
			-o|--can_send_other_messages)
				[[ "$2" =~ ^(true|false)$ ]] || message_error API "$_ERR_TYPE_BOOL_" "$1" "$2"
				_CAN_SEND_OTHER_MESSAGES_="$2"
				shift 2
				;;
			-w|--can_add_web_page_previews)
				[[ "$2" =~ ^(true|false)$ ]] || message_error API "$_ERR_TYPE_BOOL_" "$1" "$2"
				_CAN_ADD_WEB_PAGE_PREVIEWS_="$2"
				shift 2
				;;				
			--)
				shift
				break
				;;
		esac
	done
	
	[[ $_CHAT_ID_ ]] || message_error API "$_ERR_PARAM_REQUIRED_" "-c, --chat_id"
	[[ $_USER_ID_ ]] || message_error API "$_ERR_PARAM_REQUIRED_" "-c, --user_id"
	
	eval $_POST_ $_API_TELEGRAM_/$_METHOD_ ${_CHAT_ID_:+-d chat_id="'$_CHAT_ID_'"} \
											${_USER_ID_:+-d user_id="'$_USER_ID_'"} \
											${_UNTIL_DATE__:+-d until_date="'$_UNTIL_DATE_'"} \
											${_CAN_SEND_MESSAGES_:+-d can_send_messages="'$_CAN_SEND_MESSAGES_'"} \
											${_CAN_SEND_MEDIA_MESSAGES_:+-d can_send_media_messages="'$_CAN_SEND_MEDIA_MESSAGES_'"} \
											${_CAN_SEND_OTHER_MESSAGES_:+-d can_send_other_messages="'$_CAN_SEND_OTHER_MESSAGES_'"} \
											${_CAN_ADD_WEB_PAGE_PREVIEWS_:+-d can_add_web_page_previews="'$_CAN_ADD_WEB_PAGE_PREVIEWS_'"} > $_JSON_

	json_status $_JSON_ || message_error TG $_JSON_
		
	# Status
	return $?
	
}


ShellBot.promoteChatMember()
{
	local	_CHAT_ID_ _USER_ID_ _CAN_CHANGE_INFO_ _CAN_POST_MESSAGES_ \
			_CAN_EDIT_MESSAGES_ _CAN_DELETE_MESSAGES_ _CAN_INVITE_USERS_ \
			_CAN_RESTRICT_MEMBERS_ _CAN_PIN_MESSAGES_ _CAN_PROMOTE_MEMBERS_

	local _METHOD_=promoteChatMember
	local _JSON_=$(getFileJQ $FUNCNAME)
	
	local _PARAM_=$(getopt --name $FUNCNAME --options 'c:u:i:p:e:d:v:r:f:m:' \
												--longoptions 'chat_id:,
																user_id:,
																can_change_info:,
																can_post_messages:,
																can_edit_messages:,
																can_delete_messages:,
																can_invite_users:,
																can_restrict_members:,
																can_pin_messages:,
																can_promote_members:' -- "$@")
	
	eval set -- "$_PARAM_"
	
	while :
	do
		case $1 in
			-c|--chat_id)
				_CHAT_ID_="$2"
				shift 2
				;;
			-u|--user_id)
				[[ "$2" =~ ^[0-9]+$ ]] || message_error API "$_ERR_TYPE_INT_" "$1" "$2"
				_USER_ID_="$2"
				shift 2
				;;
			-i|--can_change_info)
				[[ "$2" =~ ^(true|false)$ ]] || message_error API "$_ERR_TYPE_BOOL_" "$1" "$2"
				_CAN_CHANGE_INFO_="$2"
				shift 2
				;;
			-p|--can_post_messages)
				[[ "$2" =~ ^(true|false)$ ]] || message_error API "$_ERR_TYPE_BOOL_" "$1" "$2"
				_CAN_POST_MESSAGES_="$2"
				shift 2
				;;
			-e|--can_edit_messages)
				[[ "$2" =~ ^(true|false)$ ]] || message_error API "$_ERR_TYPE_BOOL_" "$1" "$2"
				_CAN_EDIT_MESSAGES_="$2"
				shift 2
				;;
			-d|--can_delete_messages)
				[[ "$2" =~ ^(true|false)$ ]] || message_error API "$_ERR_TYPE_BOOL_" "$1" "$2"
				_CAN_DELETE_MESSAGES_="$2"
				shift 2
				;;
			-v|--can_invite_users)
				[[ "$2" =~ ^(true|false)$ ]] || message_error API "$_ERR_TYPE_BOOL_" "$1" "$2"
				_CAN_INVITE_USERS_="$2"
				shift 2
				;;
			-r|--can_restrict_members)
				[[ "$2" =~ ^(true|false)$ ]] || message_error API "$_ERR_TYPE_BOOL_" "$1" "$2"
				_CAN_RESTRICT_MEMBERS_="$2"
				shift 2
				;;
			-f|--can_pin_messages)
				[[ "$2" =~ ^(true|false)$ ]] || message_error API "$_ERR_TYPE_BOOL_" "$1" "$2"
				_CAN_PIN_MESSAGES_="$2"
				shift 2
				;;	
			-m|--can_promote_members)
				[[ "$2" =~ ^(true|false)$ ]] || message_error API "$_ERR_TYPE_BOOL_" "$1" "$2"
				_CAN_PROMOTE_MEMBERS_="$2"
				shift 2
				;;
			--)
				shift
				break
				;;
		esac
	done
	
	[[ $_CHAT_ID_ ]] || message_error API "$_ERR_PARAM_REQUIRED_" "-c, --chat_id"
	[[ $_USER_ID_ ]] || message_error API "$_ERR_PARAM_REQUIRED_" "-c, --user_id"
	
	eval $_POST_ $_API_TELEGRAM_/$_METHOD_ ${_CHAT_ID_:+-d chat_id="'$_CHAT_ID_'"} \
											${_USER_ID_:+-d user_id="'$_USER_ID_'"} \
											${_CAN_CHANGE_INFO_:+-d can_change_info="'$_CAN_CHANGE_INFO_'"} \
											${_CAN_POST_MESSAGES_:+-d can_post_messages="'$_CAN_POST_MESSAGES_'"} \
											${_CAN_EDIT_MESSAGES_:+-d can_edit_messages="'$_CAN_EDIT_MESSAGES_'"} \
											${_CAN_DELETE_MESSAGES_:+-d can_delete_messages="'$_CAN_DELETE_MESSAGES_'"} \
											${_CAN_INVITE_USERS_:+-d can_invite_users="'$_CAN_INVITE_USERS_'"} \
											${_CAN_RESTRICT_MEMBERS_:+-d can_restrict_members="'$_CAN_RESTRICT_MEMBERS_'"} \
											${_CAN_PIN_MESSAGES_:+-d can_pin_messages="'$_CAN_PIN_MESSAGES_'"} \
											${_CAN_PROMOTE_MEMBERS_:+-d can_promote_members="'$_CAN_PROMOTE_MEMBERS_'"} > $_JSON_

	json_status $_JSON_ || message_error TG $_JSON_
		
	# Status
	return $?
}

ShellBot.exportChatInviteLink()
{
	local _CHAT_ID_
	local _METHOD_=exportChatInviteLink
	local _JSON_=$(getFileJQ $FUNCNAME)

	local _PARAM_=$(getopt --name $FUNCNAME --options 'c:' --longoptions 'chat_id:' -- "$@")
	
	eval set -- "$_PARAM_"

	while :
	do
		case $1 in
			-c|--chat_id)
				_CHAT_ID_="$2"
				shift 2
				;;
			--)
				shift
				break
				;;
		esac
	done

	[[ $_CHAT_ID_ ]] || message_error API "$_ERR_PARAM_REQUIRED_" "-c, --chat_id"
	
	eval $_GET_ $_API_TELEGRAM_/$_METHOD_ ${_CHAT_ID_:+-d chat_id="'$_CHAT_ID_'"} > $_JSON_
	
	# Testa o retorno do método.
	json_status $_JSON_ && json $_JSON_ '.result' || message_error TG $_JSON_
		
	# Status
	return $?
}

ShellBot.sendVideoNote()
{
	local _CHAT_ID_ _VIDEO_NOTE_ _DURATION_ _LENGTH_ _DISABLE_NOTIFICATION_ \
			_REPLY_TO_MESSAGE_ID_ _REPLY_MARKUP_

	local _METHOD_=sendVideoNote
	local _JSON_=$(getFileJQ $FUNCNAME)
	
	local _PARAM_=$(getopt --name $FUNCNAME --options 'c:v:t:l:n:r:m:' \
										--longoptions 'chat_id:,
														video_note:,
														duration:,
														length:,
														disable_notification:,
														reply_to_message_id:,
														reply_markup:' \
														-- "$@")
	
	# Define os parâmetros posicionais
	eval set -- "$_PARAM_"
	
	while :
	do
		case $1 in
			-c|--chat_id)
				_CHAT_ID_="$2"
				shift 2
				;;
			-v|--video_note)
				_VIDEO_NOTE_="$2"
				shift 2
				;;
			-t|--duration)
				[[ "$2" =~ ^[0-9]+$ ]] || message_error API "$_ERR_TYPE_INT_" "$1" "$2"
				_DURATION_="$2"
				shift 2
				;;
			-l|--length)
				[[ "$2" =~ ^[0-9]+$ ]] || message_error API "$_ERR_TYPE_INT_" "$1" "$2"
				_LENGTH_="$2"
				shift 2
				;;
			-n|--disable_notification)
				[[ "$2" =~ ^(true|false)$ ]] || message_error API "$_ERR_TYPE_BOOL_" "$1" "$2"
				_DISABLE_NOTIFICATION_="$2"
				shift 2
				;;
			-r|--reply_to_message_id)
				[[ "$2" =~ ^[0-9]+$ ]] || message_error API "$_ERR_TYPE_INT_" "$1" "$2"
				_REPLY_TO_MESSAGE_ID_="$2"
				shift 2
				;;
			-m|--reply_markup)
				_REPLY_MARKUP_="$2"
				shift 2
				;;
			--)
				shift
				break
				;;
		esac
	done
	
	[[ $_CHAT_ID_ ]] || message_error API "$_ERR_PARAM_REQUIRED_" "-c, --chat_id"
	[[ $_VIDEO_NOTE_ ]] || message_error API "$_ERR_PARAM_REQUIRED_" "-v, --video_note"
	
	eval $_POST_ $_API_TELEGRAM_/$_METHOD_ ${_CHAT_ID_:+-F chat_id="'$_CHAT_ID_'"} \
						${_VIDEO_NOTE_:+-F video_note="'$_VIDEO_NOTE_'"} \
						${_DURATION_:+-F duration="'$_DURATION_'"} \
						${_LENGTH_:+-F length="'$_LENGTH_'"} \
						${_DISABLE_NOTIFICATION_:+-F disable_notification="'$_DISABLE_NOTIFICATION_'"} \
						${_REPLY_TO_MESSAGE_ID_:+-F reply_to_message_id="'$_REPLY_TO_MESSAGE_ID_'"} \
						${_REPLY_MARKUP_:+-F reply_markup="'$_REPLY_MARKUP_'"} > $_JSON_

	# Testa o retorno do método.
	json_status $_JSON_ || message_error TG $_JSON_
	
	# Status
	return $?
}

# Um método simples para testar o token de autenticação do seu bot. 
# Não requer parâmetros. Retorna informações básicas sobre o bot em forma de um objeto Usuário.
ShellBot.getMe()
{
	# Variável local
	local _METHOD_=getMe	# Método
	local _JSON_=$(getFileJQ $FUNCNAME)

	# Chama o método getMe passando o endereço da API, seguido do nome do método.
	eval $_GET_ $_API_TELEGRAM_/$_METHOD_ > $_JSON_
	
	# Verifica o status de retorno do método
	json_status $_JSON_ && {
		# Retorna as informações armazenadas em "result".
		json $_JSON_ '.result|.id,.username,.first_name,.last_name' | sed ':a;$!N;s/\n/|/;ta'
	} || message_error TG $_JSON_

	return $?
}

ShellBot.InlineKeyboardButton()
{
    local 	_BUTTON_ _LINE_ _TEXT_ _URL_ _CALLBACK_DATA_ \
            _SWITCH_INLINE_QUERY_ _SWITCH_INLINE_QUERY_CURRENT_CHAT_ \
			_DELM_

    local	_PARAM_=$(getopt --name $FUNCNAME --options 'b:l:t:u:c:q:s:' \
                                        --longoptions 'button:,
                                                        line:,
                                                        text:,
                                                        url:,
                                                        callback_data:,
                                                        switch_inline_query:,
                                                        switch_inline_query_chat:' \
                                                        -- "$@")

	eval set -- "$_PARAM_"

	while :
	do
		case $1 in
			-b|--button)
				# Ponteiro que recebe o endereço de "button" com as definições
				# da configuração do botão inserido.
				_BUTTON_="$2"
				shift 2
				;;
			-l|--line)
				[[ "$2" =~ ^[0-9]+$ ]] || message_error API "$_ERR_TYPE_INT_" "$1" "$2"
				_LINE_="$2"
				shift 2
				;;
			-t|--text)
				_TEXT_="$2"
				shift 2
				;;
			-u|--url)
				_URL_="$2"
				shift 2
				;;
			-c|--callback_data)
				_CALLBACK_DATA_="$2"
				shift 2
				;;
			-q|--switch_inline_query)
				_SWITCH_INLINE_QUERY_="$2"
				shift 2
				;;
			-s|--switch_inline_query_current_chat)
				_SWITCH_INLINE_QUERY_CURRENT_CHAT_="$2"
				shift 2
				;;
			--)
				shift
				break
				;;
		esac
	done

	[[ $_BUTTON_ ]] || message_error API "$_ERR_PARAM_REQUIRED_" "-b, --button"
	[[ $_TEXT_ ]] || message_error API "$_ERR_PARAM_REQUIRED_" "-t, --text"
	[[ $_CALLBACK_DATA_ ]] || message_error API "$_ERR_PARAM_REQUIRED_" "-c, --callback_data"
	[[ $_LINE_ ]] || message_error API "$_ERR_PARAM_REQUIRED_" "-l, --line"
	
	# Inicializa a variável armazenada em _BUTTON_, definindo seu
	# escopo como global, tornando-a visível em todo o projeto (source)
	# O ponteiro _BUTTON_ recebe o endereço do botão armazenado.
	declare -g $_BUTTON_
	declare -n _BUTTON_	# Ponteiro
	
	# Abre o array para receber o novo objeto
	_BUTTON_[$_LINE_]="${_BUTTON_[$_LINE_]#[}"
	_BUTTON_[$_LINE_]="${_BUTTON_[$_LINE_]%]}"

	# Verifica se já existe um botão na linha especificada.
	[[ ${_BUTTON_[$_LINE_]} ]] && _DELM_=','

	# Salva as configurações do botão.
	#
	# Obrigatório: text, callback_data 
	# Opcional: url, switch_inline_query, switch_inline_query_current_chat
	_BUTTON_[$_LINE_]+="${_DELM_}{ 
\"text\":\"${_TEXT_}\",
\"callback_data\":\"${_CALLBACK_DATA_}\"
${_URL_:+,\"url\":\"${_URL_}\"}
${_SWITCH_INLINE_QUERY_:+,\"switch_inline_query\":\"${_SWITCH_INLINE_QUERY_}\"}
${_SWITCH_INLINE_QUERY_CURRENT_CHAT_:+,\"switch_inline_query_current_chat\":\"${_SWITCH_INLINE_QUERY_CURRENT_CHAT_}\"}
}" || return 1	# Erro ao salvar o botão. 
	
	# Fecha o array
	_BUTTON_[$_LINE_]="${_BUTTON_[$_LINE_]/#/[}"
	_BUTTON_[$_LINE_]="${_BUTTON_[$_LINE_]/%/]}"

	# retorno
	return 0
}

ShellBot.InlineKeyboardMarkup()
{
	local 	_BUTTON_ _TEMP_KB_ 
    local 	_PARAM_=$(getopt --name $FUNCNAME --options 'b:' --longoptions 'button:' -- "$@")

	eval set -- "$_PARAM_"

	while :
	do
		case $1 in
			-b|--button)
				# Ponteiro que recebe o endereço da variável "teclado" com as definições
				# de configuração do botão inserido.
				_BUTTON_="$2"
				shift 2
				;;
			--)
				shift
				break
				;;
		esac
	done
	
	[[ $_BUTTON_ ]] || message_error API "$_ERR_PARAM_REQUIRED_" "-b, --button"
	
	# Ponteiro
	declare -n _BUTTON_

	# Salva todos elementos do array do teclado, convertendo-o em uma variável de índice 0.
	# Cria-se uma estrutura do tipo 'inline_keyboard' e anexa os botões e fecha a estrutura.
	# O ponteiro matriz é limpo para receber a nova estrutura contendo o layout do objeto.
	# O tipo 'inline_keyboard' é definido, adicionando os botões separando-os pelo delimitador
	# ',' vírgula. A posição dos botões é determinada pelo índice da linha na inicilização.
	#
	# Exemplo:
	#
	#	Linha					array
	#
	#	 1		[inline_botao1] [inline_botao2] [inline_botao3]
	#	 2				[inline_botao4] [inline_botao5]
	#	 3			            [inline_botao7]
	
	_KEYBOARD_="${_BUTTON_[@]}" || return 1
	
	# Cria estrutura do teclado
	_KEYBOARD_="${_KEYBOARD_/#/{\"inline_keyboard\":[}"
	_KEYBOARD_="${_KEYBOARD_//]/],}"					
	_KEYBOARD_="${_KEYBOARD_%,}"						
	_KEYBOARD_="${_KEYBOARD_/%/]\}}"					

	# Retorna a estrutura	
	echo $_KEYBOARD_

	# status
	return 0
}

ShellBot.answerCallbackQuery()
{
	local _CALLBACK_QUERY_ID_ _TEXT_ _SHOW_ALERT_ _URL_ _CACHE_TIME_
	local _METHOD_=answerCallbackQuery # Método
	local _JSON_=$(getFileJQ $FUNCNAME)
	
	local _PARAM_=$(getopt --name $FUNCNAME --options 'c:t:s:u:e:' \
										--longoptions 'callback_query_id:,
														text:,
														show_alert:,
														url:,
														cache_time:' \
														-- "$@")


	eval set -- "$_PARAM_"
	
	while :
	do
		case $1 in
			-c|--callback_query_id)
				_CALLBACK_QUERY_ID_="$2"
				shift 2
				;;
			-t|--text)
				_TEXT_="$2"
				shift 2
				;;
			-s|--show_alert)
				# boolean
				[[ "$2" =~ ^(true|false)$ ]] || message_error API "$_ERR_TYPE_BOOL_" "$1" "$2"
				_SHOW_ALERT_="$2"
				shift 2
				;;
			-u|--url)
				_URL_="$2"
				shift 2
				;;
			-e|--cache_time)
				# inteiro
				[[ "$2" =~ ^[0-9]+$ ]] || message_error API "$_ERR_TYPE_INT_" "$1" "$2"
				_CACHE_TIME_="$2"
				shift 2
				;;
			--)
				shift
				break
				;;
		esac
	done
	
	[[ $_CALLBACK_QUERY_ID_ ]] || message_error API "$_ERR_PARAM_REQUIRED_" "-c, --callback_query_id"
	
	eval $_POST_ $_API_TELEGRAM_/$_METHOD_ ${_CALLBACK_QUERY_ID_:+-d callback_query_id="'$_CALLBACK_QUERY_ID_'"} \
							${_TEXT_:+-d text="'$_TEXT_'"} \
							${_SHOW_ALERT_:+-d show_alert="'$_SHOW_ALERT_'"} \
							${_URL_:+-d url="'$_URL_'"} \
							${_CACHE_TIME_:+-d cache_time="'$_CACHE_TIME_'"} > $_JSON_

	json_status $_JSON_ || message_error TG $_JSON_

	return $?
}

# Cria objeto que representa um teclado personalizado com opções de resposta
ShellBot.ReplyKeyboardMarkup()
{
	# Variáveis locais
	local 	_BUTTON_ _RESIZE_KEYBOARD_ _ON_TIME_KEYBOARD_ _SELECTIVE_
	
	# Lê os parâmetros da função.
	local _PARAM_=$(getopt --name $FUNCNAME --options 'b:r:t:s:' \
										--longoptions 'button:,
														resize_keyboard:,
														one_time_keyboard:,
														selective:' \
														-- "$@")
	
	# Transforma os parâmetros da função em parâmetros posicionais
	#
	# Exemplo:
	#	--param1 arg1 --param2 arg2 --param3 arg3 ...
	# 		$1			  $2			$3
	eval set -- "$_PARAM_"
	
	# Aguarda leitura dos parâmetros
	while :
	do
		# Lê o parâmetro da primeira posição "$1"; Se for um parâmetro válido,
		# salva o valor do argumento na posição '$2' e desloca duas posições a esquerda (shift 2); Repete o processo
		# até que o valor de '$1' seja igual '--' e finaliza o loop.
		case $1 in
			-b|--button)
				_BUTTON_="$2"
				shift 2
				;;
			-r|--resize_keyboard)
				# Tipo: boolean
				[[ "$2" =~ ^(true|false)$ ]] || message_error API "$_ERR_TYPE_BOOL_" "$1" "$2"
				_RESIZE_KEYBOARD_="$2"
				shift 2
				;;
			-t|--one_time_keyboard)
				# Tipo: boolean
				[[ "$2" =~ ^(true|false)$ ]] || message_error API "$_ERR_TYPE_BOOL_" "$1" "$2"
				_ON_TIME_KEYBOARD_="$2"
				shift 2
				;;
			-s|--selective)
				# Tipo: boolean
				[[ "$2" =~ ^(true|false)$ ]] || message_error API "$_ERR_TYPE_BOOL_" "$1" "$2"
				_SELECTIVE_="$2"
				shift 2
				;;
			--)
				shift
				break
				;;
		esac
	done
	
	# Imprime mensagem de erro se o parâmetro obrigatório for omitido.
	[[ $_BUTTON_ ]] || message_error API "$_ERR_PARAM_REQUIRED_" "-b, --button"

	# Ponteiro	
	declare -n _BUTTON_

	# Constroi a estrutura dos objetos + array keyboard, define os valores e salva as configurações.
	# Por padrão todos os valores são 'false', até que seja definido.
	cat << _EOF
{"keyboard":$_BUTTON_,
"resize_keyboard":${_RESIZE_KEYBOARD_:-false},
"one_time_keyboard":${_ON_TIME_KEYBOARD_:-false},
"selective": ${_SELECTIVE_:-false}}
_EOF

	# status
	return 0
}

# Envia mensagens 
ShellBot.sendMessage()
{
	# Variáveis locais 
	local _CHAT_ID_ _TEXT_ _PARSE_MODE_ _DISABLE_WEB_PAGE_PREVIEW_ _DISABLE_NOTIFICATION_ _REPLY_TO_MESSAGE_ID_ _REPLY_MARKUP_
	local _METHOD_=sendMessage # Método
	local _JSON_=$(getFileJQ $FUNCNAME)
	
	# Lê os parâmetros da função
	local _PARAM_=$(getopt --name $FUNCNAME --options 'c:t:p:w:n:r:k:' \
										--longoptions 'chat_id:,
														text:,
														parse_mode:,
														disable_web_page_preview:,
														disable_notification:,
														reply_to_message_id:,
														reply_markup:' \
														-- "$@")

	
	# Define os parâmetros posicionais
	eval set -- "$_PARAM_"
	
	while :
	do
		case $1 in
			-c|--chat_id)
				_CHAT_ID_="$2"
				shift 2
				;;
			-t|--text)
				_TEXT_="$2"
				shift 2
				;;
			-p|--parse_mode)
				# Tipo: "markdown" ou "html"
				[[ "$2" =~ ^(markdown|html)$ ]] || message_error API "$_ERR_TYPE_PARSE_MODE_" "$1" "$2"
				_PARSE_MODE_="$2"
				shift 2
				;;
			-w|--disable_web_page_preview)
				# Tipo: boolean
				[[ "$2" =~ ^(true|false)$ ]] || message_error API "$_ERR_TYPE_BOOL_" "$1" "$2"
				_DISABLE_WEB_PAGE_PREVIEW_="$2"
				shift 2
				;;
			-n|--disable_notification)
				# Tipo: boolean
				[[ "$2" =~ ^(true|false)$ ]] || message_error API "$_ERR_TYPE_BOOL_" "$1" "$2"
				_DISABLE_NOTIFICATION_="$2"
				shift 2
				;;
			-r|--reply_to_message_id)
				# Tipo: inteiro
				[[ "$2" =~ ^[0-9]+$ ]] || message_error API "$_ERR_TYPE_INT_" "$1" "$2"
				_REPLY_TO_MESSAGE_ID_="$2"
				shift 2
				;;
			-k|--reply_markup)
				_REPLY_MARKUP_="$2"
				shift 2
				;;
			--)
				shift
				break
				;;
		esac
	done

	# Parâmetros obrigatórios.
	[[ $_CHAT_ID_ ]] || message_error API "$_ERR_PARAM_REQUIRED_" "[-c, --chat_id]"
	[[ $_TEXT_ ]] || message_error API "$_ERR_PARAM_REQUIRED_" "[-t, --text]"

	# Chama o método da API, utilizando o comando request especificado; Os parâmetros 
	# e valores são passados no form e lidos pelo método. O retorno do método é redirecionado para o arquivo 'update.json'.
	# Variáveis com valores nulos são ignoradas e consequentemente os respectivos parâmetros omitidos.
	eval $_POST_ $_API_TELEGRAM_/$_METHOD_ ${_CHAT_ID_:+-d chat_id="'$_CHAT_ID_'"} \
						${_TEXT_:+-d text="'$_TEXT_'"} \
						${_PARSE_MODE_:+-d parse_mode="'$_PARSE_MODE_'"} \
						${_DISABLE_WEB_PAGE_PREVIEW_:+-d disable_web_page_preview="'$_DISABLE_WEB_PAGE_PREVIEW_'"} \
						${_DISABLE_NOTIFICATION_:+-d disable_notification="'$_DISABLE_NOTIFICATION_'"} \
						${_REPLY_TO_MESSAGE_ID_:+-d reply_to_message_id="'$_REPLY_TO_MESSAGE_ID_'"} \
						${_REPLY_MARKUP_:+-d reply_markup="'$_REPLY_MARKUP_'"} > $_JSON_

	# Testa o retorno do método.
	json_status $_JSON_ || message_error TG $_JSON_
	
	# Status
	return $?
}

# Função para reencaminhar mensagens de qualquer tipo.
ShellBot.forwardMessage()
{
	# Variáveis locais
	local _CHAT_ID_ _FORM_CHAT_ID_ _DISABLE_NOTIFICATION_ _MESSAGE_ID_
	local _JSON_=$(getFileJQ $FUNCNAME)
	local _METHOD_=forwardMessage # Método
	
	# Lê os parâmetros da função
	local _PARAM_=$(getopt --name $FUNCNAME --options 'c:f:n:m:' \
										--longoptions 'chat_id:,
														from_chat_id:,
														disable_notification:,
														message_id:' \
														-- "$@")

	
	# Define os parâmetros posicionais
	eval set -- "$_PARAM_"

	while :
	do
		case $1 in
			-c|--chat_id)
				_CHAT_ID_="$2"
				shift 2
				;;
			-f|--from_chat_id)
				_FROM_CHAT_ID_="$2"
				shift 2
				;;
			-n|--disable_notification)
				# Tipo: boolean
				[[ "$2" =~ ^(true|false)$ ]] || message_error API "$_ERR_TYPE_BOOL_" "$1" "$2"
				_DISABLE_NOTIFICATION_="$2"
				shift 2
				;;
			-m|--message_id)
				# Tipo: inteiro
				[[ "$2" =~ ^[0-9]+$ ]] || message_error API "$_ERR_TYPE_INT_" "$1" "$2"
				_MESSAGE_ID_="$2"
				shift 2
				;;
			--)
				shift
				break
				;;
		esac
	done
	
	# Parâmetros obrigatórios.
	[[ $_CHAT_ID_ ]] || message_error API "$_ERR_PARAM_REQUIRED_" "[-c, --chat_id]"
	[[ $_FROM_CHAT_ID_ ]] || message_error API "$_ERR_PARAM_REQUIRED_" "[-f, --from_chat_id]"
	[[ $_MESSAGE_ID_ ]] || message_error API "$_ERR_PARAM_REQUIRED_" "[-m, --message_id]"

	# Chama o método
	eval $_POST_ $_API_TELEGRAM_/$_METHOD_ ${_CHAT_ID_:+-d chat_id="'$_CHAT_ID_'"} \
							${_FROM_CHAT_ID_:+-d from_chat_id="'$_FROM_CHAT_ID_'"} \
							${_DISABLE_NOTIFICATION_:+-d disable_notification="'$_DISABLE_NOTIFICATION_'"} \
							${_MESSAGE_ID_:+-d message_id="'$_MESSAGE_ID_'"} > $_JSON_
	
	# Retorno do método
	json_status $_JSON_ || message_error TG $_JSON_

	# status
	return $?
}

# Utilize essa função para enviar fotos.
ShellBot.sendPhoto()
{
	# Variáveis locais
	local _CHAT_ID_ _PHOTO_ _CAPTION_ _DISABLE_NOTIFICATION_ _REPLY_TO_MESSAGE_ID_ _REPLY_MARKUP_
	local _JSON_=$(getFileJQ $FUNCNAME)
	local _METHOD_=sendPhoto	# Método

	# Lê os parâmetros da função
	local _PARAM_=$(getopt --name $FUNCNAME --options 'c:p:t:n:r:k:' \
										--longoptions 'chat_id:, 
														photo:,
														caption:,
														disable_notification:,
														reply_to_message_id:,
														reply_markup:' \
														-- "$@")


	# Define os parâmetros posicionais
	eval set -- "$_PARAM_"

	while :
	do
		case $1 in
			-c|--chat_id)
				_CHAT_ID_="$2"
				shift 2
				;;
			-p|--photo)
				_PHOTO_="$2"
				shift 2
				;;
			-t|--caption)
				# Limite máximo de caracteres: 200
				_CAPTION_="$2"
				shift 2
				;;
			-n|--disable_notification)
				# Tipo: boolean
				[[ "$2" =~ ^(true|false)$ ]] || message_error API "$_ERR_TYPE_BOOL_" "$1" "$2"
				_DISABLE_NOTIFICATION_="$2"
				shift 2
				;;
			-r|--reply_to_message_id)
				# Tipo: inteiro
				[[ "$2" =~ ^[0-9]+$ ]] || message_error API "$_ERR_TYPE_INT_" "$1" "$2"
				_REPLY_TO_MESSAGE_ID_="$2"
				shift 2
				;;
			-k|--reply_markup)
				_REPLY_MARKUP_="$2"
				shift 2
				;;
			--)
				shift
				break
				;;
		esac
	done
	
	# Parâmetros obrigatórios
	[[ $_CHAT_ID_ ]] || message_error API "$_ERR_PARAM_REQUIRED_" "[-c, --chat_id]"
	[[ $_PHOTO_ ]] || message_error API "$_ERR_PARAM_REQUIRED_" "[-p, --photo]"
	
	# Chama o método
	eval $_POST_ $_API_TELEGRAM_/$_METHOD_ ${_CHAT_ID_:+-F chat_id="'$_CHAT_ID_'"} \
							${_PHOTO_:+-F photo="'$_PHOTO_'"} \
							${_CAPTION_:+-F caption="'$_CAPTION_'"} \
							${_DISABLE_NOTIFICATION_:+-F disable_notification="'$_DISABLE_NOTIFICATION_'"} \
							${_REPLY_TO_MESSAGE_ID_:+-F reply_to_message_id="'$_REPLY_TO_MESSAGE_ID_'"} \
							${_REPLY_MARKUP_:+-F reply_markup="'$_REPLY_MARKUP_'"} > $_JSON_
	
	# Retorno do método
	json_status $_JSON_ || message_error TG $_JSON_

	# Status
	return $?
}

# Utilize essa função para enviar arquivos de audio.
ShellBot.sendAudio()
{
	# Variáveis locais
	local _CHAT_ID_ _AUDIO_ _CAPTION_ _DURATION_ _PERFORMER_ _TITLE_ _DISABLE_NOTIFICATION_ _REPLY_TO_MESSAGE_ID_ _REPLY_MARKUP_	
	local _JSON_=$(getFileJQ $FUNCNAME)
	local _METHOD_=sendAudio	# Método
	
	# Lê os parâmetros da função
	local _PARAM_=$(getopt --name $FUNCNAME --options 'c:a:t:d:e:i:n:r:k' \
										 --longoptions 'chat_id:,
														audio:,
														caption:,
														duration:,
														performer:,
														title:,
														disable_notification:,
														reply_to_message_id:,	
														reply_markup:' \
														-- "$@")

	# Define os parâmetros posicionais
	eval set -- "$_PARAM_"

	while :
	do
		case $1 in
			-c|--chat_id)
				_CHAT_ID_="$2"
				shift 2
				;;
			-a|--audio)
				_AUDIO_="$2"
				shift 2
				;;
			-t|--caption)
				_CAPTION_="$2"
				shift 2
				;;
			-d|--duration)
				# Tipo: inteiro
				[[ "$2" =~ ^[0-9]+$ ]] || message_error API "$_ERR_TYPE_INT_" "$1" "$2"
				_DURATION_="$2"
				shift 2
				;;
			-e|--performer)
				_PERFORMER_="$2"
				shift 2
				;;
			-i|--title)
				_TITLE_="$2"
				shift 2
				;;
			-n|--disable_notification)
				# Tipo: boolean
				[[ "$2" =~ ^(true|false)$ ]] || message_error API "$_ERR_TYPE_BOOL_" "$1" "$2"
				_DISABLE_NOTIFICATION_="$2"
				shift 2
				;;
			-r|--reply_to_message_id)
				# Tipo: inteiro
				[[ "$2" =~ ^[0-9]+$ ]] || message_error API "$_ERR_TYPE_INT_" "$1" "$2"
				_REPLY_TO_MESSAGE_ID_="$2"
				shift 2
				;;
			-k|--reply_markup)
				_REPLY_MARKUP_="$2"
				shift 2
				;;
			--)
				shift
				break
				;;
		esac
	done
	
	# Parâmetros obrigatórios
	[[ $_CHAT_ID_ ]] || message_error API "$_ERR_PARAM_REQUIRED_" "[-c, --chat_id]"
	[[ $_AUDIO_ ]] || message_error API "$_ERR_PARAM_REQUIRED_" "[-a, --audio]"
	
	# Chama o método
	eval $_POST_ $_API_TELEGRAM_/$_METHOD_ ${_CHAT_ID_:+-F chat_id="'$_CHAT_ID_'"} \
							${_AUDIO_:+-F audio="'$_AUDIO_'"} \
							${_CAPTION_:+-F caption="'$_CAPTION_'"} \
							${_DURATION_:+-F duration="'$_DURATION_'"} \
							${_PERFORMER_:+-F performer="'$_PERFORMER_'"} \
							${_TITLE_:+-F title="'$_TITLE_'"} \
							${_DISABLE_NOTIFICATION_:+-F disable_notification="'$_DISABLE_NOTIFICATION_'"} \
							${_REPLY_TO_MESSAGE_ID_:+-F reply_to_message_id="'$_REPLY_TO_MESSAGE_ID_'"} \
							${_REPLY_MARKUP_:+-F reply_markup="'$_REPLY_MARKUP_'"} > $_JSON_

	# Retorno do método
	json_status $_JSON_ || message_error TG $_JSON_

	# Status
	return $?
		
}

# Utilize essa função para enviar documentos.
ShellBot.sendDocument()
{
	# Variáveis locais
	local _CHAT_ID_ _DOCUMENT_ _CAPTION_ _DISABLE_NOTIFICATION_ _REPLY_TO_MESSAGE_ID_ _REPLY_MARKUP_
	local _JSON_=$(getFileJQ $FUNCNAME)
	local _METHOD_=sendDocument	# Método
	
	# Lê os parâmetros da função
	local _PARAM_=$(getopt --name $FUNCNAME --options 'c:d:t:n:r:k:' \
										--longoptions 'chat_id:,
														document:,
														caption:,
														disable_notification:,
														reply_to_message_id:,
														reply_markup:' \
														-- "$@")

	
	# Define os parâmetros posicionais
	eval set -- "$_PARAM_"

	while :
	do
		case $1 in
			-c|--chat_id)
				_CHAT_ID_="$2"
				shift 2
				;;
			-d|--document)
				_DOCUMENT_="$2"
				shift 2
				;;
			-t|--caption)
				_CAPTION_="$2"
				shift 2
				;;
			-n|--disable_notification)
				[[ "$2" =~ ^(true|false)$ ]] || message_error API "$_ERR_TYPE_BOOL_" "$1" "$2"
				_DISABLE_NOTIFICATION_="$2"
				shift 2
				;;
			-r|--reply_to_message_id)
				[[ "$2" =~ ^[0-9]+$ ]] || message_error API "$_ERR_TYPE_INT_" "$1" "$2"
				_REPLY_TO_MESSAGE_ID_="$2"
				shift 2
				;;
			-k|--reply_markup)
				_REPLY_MARKUP="$2"
				shift 2
				;;
			--)
				shift
				break
				;;
		esac
	done
	
	# Parâmetros obrigatórios
	[[ $_CHAT_ID_ ]] || message_error API "$_ERR_PARAM_REQUIRED_" "[-c, --chat_id]"
	[[ $_DOCUMENT_ ]] || message_error API "$_ERR_PARAM_REQUIRED_" "[-d, --document]"
	
	# Chama o método
	eval $_POST_ $_API_TELEGRAM_/$_METHOD_ ${_CHAT_ID_:+-F chat_id="'$_CHAT_ID_'"} \
							${_DOCUMENT_:+-F document="'$_DOCUMENT_'"} \
							${_CAPTION_:+-F caption="'$_CAPTION_'"} \
							${_DISABLE_NOTIFICATION_:+-F disable_notification="'$_DISABLE_NOTIFICATION_'"} \
							${_REPLY_TO_MESSAGE_ID_:+-F reply_to_message_id="'$_REPLY_TO_MESSAGE_ID_'"} \
							${_REPLY_MARKUP_:+-F reply_markup="'$_REPLY_MARKUP_'"} > $_JSON_

	# Retorno do método
	json_status $_JSON_ || message_error TG $_JSON_

	# Status
	return $?
	
}

# Utilize essa função para enviat stickers
ShellBot.sendSticker()
{
	# Variáveis locais
	local _CHAT_ID_ _STICKER_ _DISABLE_NOTIFICATION_ _REPLY_TO_MESSAGE_ID_ _REPLY_MARKUP_
	local _JSON_=$(getFileJQ $FUNCNAME)
	local _METHOD_=sendSticker	# Método

	# Lê os parâmetros da função
	local _PARAM_=$(getopt --name $FUNCNAME --options 'c:s:n:r:k:' \
										--longoptions 'chat_id:,
														sticker:,
														disable_notification:,
														reply_to_message_id:,
														reply_markup:' \
														-- "$@")

	# Define os parâmetros posicionais
	eval set -- "$_PARAM_"

	while :
	do
		case $1 in
			-c|--chat_id)
				_CHAT_ID_="$2"
				shift 2
				;;
			-s|--sticker)
				_STICKER_="$2"
				shift 2
				;;
			-n|--disable_notification)
				# Tipo: boolean
				[[ "$2" =~ ^(true|false)$ ]] || message_error API "$_ERR_TYPE_BOOL_" "$1" "$2"
				_DISABLE_NOTIFICATION_="$2"
				shift 2
				;;
			-r|--reply_to_message_id)
				# Tipo: inteiro
				[[ "$2" =~ ^[0-9]+$ ]] || message_error API "$_ERR_TYPE_INT_" "$1" "$2"
				_REPLY_TO_MESSAGE_ID_="$2"
				shift 2
				;;
			-k|--reply_markup)
				_REPLY_MARKUP_="$2"
				shift 2
				;;
			--)
				shift
				break
				;;
		esac
	done
	
	# Parâmetros obrigatórios
	[[ $_CHAT_ID_ ]] || message_error API "$_ERR_PARAM_REQUIRED_" "[-c, --chat_id]"
	[[ $_STICKER_ ]] || message_error API "$_ERR_PARAM_REQUIRED_" "[-s, --sticker]"

	# Chama o método
	eval $_POST_ $_API_TELEGRAM_/$_METHOD_ ${_CHAT_ID_:+-F chat_id="'$_CHAT_ID_'"} \
							${_STICKER_:+-F sticker="'$_STICKER_'"} \
							${_DISABLE_NOTIFICATION_:+-F disable_notification="'$_DISABLE_NOTIFICATION_'"} \
							${_REPLY_TO_MESSAGE_ID_:+-F reply_to_message_id="'$_REPLY_TO_MESSAGE_ID_'"} \
							${_REPLY_MARKUP_:+-F reply_markup="'$_REPLY_MARKUP_'"} > $_JSON_

	# Testa o retorno do método
	json_status $_JSON_ || message_error TG $_JSON_

	# Status
	return $?
}

# Função para enviar arquivos de vídeo.
ShellBot.sendVideo()
{
	# Variáveis locais
	local _CHAT_ID_ _VIDEO_ _DURATION_ _WIDTH_ _HEIGHT_ _CAPTION_ _DISABLE_NOTIFICATION_ _REPLY_TO_MESSAGE_ID_ _REPLY_MARKUP_
	local _JSON_=$(getFileJQ $FUNCNAME)
	local _METHOD_=sendVideo	# Método

	# Lê os parâmetros da função
	local _PARAM_=$(getopt --name $FUNCNAME --options 'c:v:d:w:h:t:n:r:k:' \
										--longoptions 'chat_id:,
														video:,
														duration:,
														width:,
														height:,
														caption:,
														disable_notification:,
														reply_to_message_id:,
														reply_markup:' \
														-- "$@")

	
	# Define os parâmetros posicionais
	eval set -- "$_PARAM_"

	while :
	do
		case $1 in
			-c|--chat_id)
				_CHAT_ID_="$2"
				shift 2
				;;
			-v|--video)
				_VIDEO_="$2"
				shift 2
				;;
			-d|--duration)
				# Tipo: inteiro
				[[ "$2" =~ ^[0-9]+$ ]] || message_error API "$_ERR_TYPE_INT_" "$1" "$2"
				_DURATION_="$2"
				shift 2
				;;
			-w|--width)
				# Tipo: inteiro
				[[ "$2" =~ ^[0-9]+$ ]] || message_error API "$_ERR_TYPE_INT_" "$1" "$2"
				_WIDTH_="$2"
				shift 2
				;;
			-h|--height)
				# Tipo: inteiro
				[[ "$2" =~ ^[0-9]+$ ]] || message_error API "$_ERR_TYPE_INT_" "$1" "$2"
				_HEIGHT_="$2"
				shift 2
				;;
			-t|--caption)
				_CAPTION_="$2"
				shift 2
				;;
			-n|--disable_notification)
				# Tipo: boolean
				[[ "$2" =~ ^(true|false)$ ]] || message_error API "$_ERR_TYPE_BOOL_" "$1" "$2"
				_DISABLE_NOTIFICATION_="$2"
				shift 2
				;;
			-r|--reply_to_message_id)
				[[ "$2" =~ ^[0-9]+$ ]] || message_error API "$_ERR_TYPE_INT_" "$1" "$2"
				_REPLY_TO_MESSAGE_ID_="$2"
				shift 2
				;;
			-k|--reply_markup)
				_REPLY_MARKUP_="$2"
				shift 2
				;;
			--)
				shift
				break
				;;
		esac
	done
	
	# Parâmetros obrigatórios.
	[[ $_CHAT_ID_ ]] || message_error API "$_ERR_PARAM_REQUIRED_" "[-c, --chat_id]"
	[[ $_VIDEO_ ]] || message_error API "$_ERR_PARAM_REQUIRED_" "[-v, --video]"

	# Chama o método
	eval $_POST_ $_API_TELEGRAM_/$_METHOD_ ${_CHAT_ID_:+-F chat_id="'$_CHAT_ID_'"} \
							${_VIDEO_:+-F video="'$_VIDEO_'"} \
							${_DURATION_:+-F duration="'$_DURATION_'"} \
							${_WIDTH_:+-F width="'$_WIDTH_'"} \
							${_HEIGHT_:+-F height="'$_HEIGHT_'"} \
							${_CAPTION_:+-F caption="'$_CAPTION_'"} \
							${_DISABLE_NOTIFICATION_:+-F disable_notification="'$_DISABLE_NOTIFICATION_'"} \
							${_REPLY_TO_MESSAGE_ID_:+-F reply_to_message_id="'$_REPLY_TO_MESSAGE_ID_'"} \
							${_REPLY_MARKUP_:+-F reply_markup="'$_REPLY_MARKUP_'"} > $_JSON_

	# Testa o retorno do método
	json_status $_JSON_ || message_error TG $_JSON_

	# Status
	return $?
	
}

# Função para enviar audio.
ShellBot.sendVoice()
{
	# Variáveis locais
	local _CHAT_ID_ _VOICE_ _CAPTION_ _DURATION_ _DISABLE_NOTIFICATION_ _REPLY_TO_MESSAGE_ID_ _REPLY_MARKUP_
	local _JSON_=$(getFileJQ $FUNCNAME)
	local _METHOD_=sendVoice	# Método

	# Lê os parâmetros da função
	local _PARAM_=$(getopt --name $FUNCNAME --options 'c:v:t:d:n:r:k:' \
										--longoptions 'chat_id:,
														voice:,
														caption:,
														duration:,
														disable_notification:,
														reply_to_message_id:,
														reply_markup:' \
														-- "$@")

	
	# Define os parâmetros posicionais
	eval set -- "$_PARAM_"

	while :
	do
		case $1 in
			-c|--chat_id)
				_CHAT_ID_="$2"
				shift 2
				;;
			-v|--voice)
				_VOICE_="$2"
				shift 2
				;;
			-t|--caption)
				_CAPTION_="$2"
				shift 2
				;;
			-d|--duration)
				# Tipo: inteiro
				[[ "$2" =~ ^[0-9]+$ ]] || message_error API "$_ERR_TYPE_INT_" "$1" "$2"
				_DURATION_="$2"
				shift 2
				;;
			-n|--disable_notification)
				# Tipo: boolean
				[[ "$2" =~ ^(true|false)$ ]] || message_error API "$_ERR_TYPE_BOOL_" "$1" "$2"
				_DISABLE_NOTIFICATION_="$2"
				shift 2
				;;
			-r|--reply_to_message_id)
				# Tipo: inteiro
				[[ "$2" =~ ^[0-9]+$ ]] || message_error API "$_ERR_TYPE_INT_" "$1" "$2"
				_REPLY_TO_MESSAGE_ID_="$2"
				shift 2
				;;
			-k|--reply_markup)
				_REPLY_MARKUP_="$2"
				shift 2
				;;
			--)
				shift
				break
		esac
	done
	
	# Parâmetros obrigatórios.
	[[ $_CHAT_ID_ ]] || message_error API "$_ERR_PARAM_REQUIRED_" "[-c, --chat_id]"
	[[ $_VOICE_ ]] || message_error API "$_ERR_PARAM_REQUIRED_" "[-v, --voice]"
	
	# Chama o método
	eval $_POST_ $_API_TELEGRAM_/$_METHOD_ ${_CHAT_ID_:+-F chat_id="'$_CHAT_ID_'"} \
							${_VOICE_:+-F voice="'$_VOICE_'"} \
							${_CAPTION_:+-F caption="'$_CAPTION_'"} \
							${_DURATION_:+-F duration="'$_DURATION_'"} \
							${_DISABLE_NOTIFICATION_:+-F disable_notification="'$_DISABLE_NOTIFICATION_'"} \
							${_REPLY_TO_MESSAGE_ID_:+-F reply_to_message_id="'$_REPLY_TO_MESSAGE_ID_'"} \
							${_REPLY_MARKUP_:+-F reply_markup="'$_REPLY_MARKUP_'"} > $_JSON_

	# Testa o retorno do método
	json_status $_JSON_ || message_error TG $_JSON_

	# Status
	return $?
	
}

# Função utilizada para enviar uma localidade utilizando coordenadas de latitude e longitude.
ShellBot.sendLocation()
{
	# Variáveis locais
	local _CHAT_ID_ _LATITUDE_ _LONGITUDE_ _DISABLE_NOTIFICATION_ _REPLY_TO_MESSAGE_ID_ _REPLY_MARKUP_
	local _JSON_=$(getFileJQ $FUNCNAME)
	local _METHOD_=sendLocation	# Método

	# Lê os parâmetros da função
	local _PARAM_=$(getopt --name $FUNCNAME --options 'c:l:g:n:r:k:' \
										--longoptions 'chat_id:,
														latitude:,
														longitude:,
														disable_notification:,
														reply_to_message_id:,
														reply_markup:' \
														-- "$@")

	
	# Define os parâmetros posicionais
	eval set -- "$_PARAM_"
	
	while :
	do
		case $1 in
			-c|--chat_id)
				_CHAT_ID_="$2"
				shift 2
				;;
			-l|--latitude)
				# Tipo: float
				[[ "$2" =~ ^-?[0-9]+\.[0-9]+$ ]] || message_error API "$_ERR_TYPE_FLOAT_" "$1" "$2"
				_LATITUDE_="$2"
				shift 2
				;;
			-g|--longitude)
				# Tipo: float
				[[ "$2" =~ ^-?[0-9]+\.[0-9]+$ ]] || message_error API "$_ERR_TYPE_FLOAT_" "$1" "$2"
				_LONGITUDE_="$2"
				shift 2
				;;
			-n|--disable_notification)
				# Tipo: boolean
				[[ "$2" =~ ^(true|false)$ ]] || message_error API "$_ERR_TYPE_BOOL_" "$1" "$2"
				_DISABLE_NOTIFICATION_="$2"
				shift 2
				;;
			-r|--reply_to_message_id)
				# Tipo: inteiro
				[[ "$2" =~ ^[0-9]+$ ]] || message_error API "$_ERR_TYPE_INT_" "$1" "$2"
				_REPLY_TO_MESSAGE_ID_="$2"
				shift 2
				;;
			-k|--reply_markup)
				_REPLY_MARKUP_="$2"
				shift 2
				;;
			--)
				shift
				break
		esac
	done
	
	# Parâmetros obrigatórios
	[[ $_CHAT_ID_ ]] || message_error API "$_ERR_PARAM_REQUIRED_" "[-c, --chat_id]"
	[[ $_LATITUDE_ ]] || message_error API "$_ERR_PARAM_REQUIRED_" "[-l, --latitude]"
	[[ $_LONGITUDE_ ]] || message_error API "$_ERR_PARAM_REQUIRED_" "[-g, --longitude]"
			
	# Chama o método
	eval $_POST_ $_API_TELEGRAM_/$_METHOD_ ${_CHAT_ID_:+-F chat_id="'$_CHAT_ID_'"} \
							${_LATITUDE_:+-F latitude="'$_LATITUDE_'"} \
							${_LONGITUDE_:+-F longitude="'$_LONGITUDE_'"} \
							${_DISABLE_NOTIFICATION_:+-F disable_notification="'$_DISABLE_NOTIFICATION_'"} \
							${_REPLY_TO_MESSAGE_ID_:+-F reply_to_message_id="'$_REPLY_TO_MESSAGE_ID_'"} \
							${_REPLY_MARKUP_:+-F reply_markup="'$_REPLY_MARKUP_'"} > $_JSON_

	# Testa o retorno do método
	json_status $_JSON_ || message_error TG $_JSON_

	return $?
	
}

# Função utlizada para enviar detalhes de um local.
ShellBot.sendVenue()
{
	# Variáveis locais
	local _CHAT_ID_ _LATITUDE_ _LONGITUDE_ _TITLE_ _ADDRESS_ _FOURSQUARE_ID_ _DISABLE_NOTIFICATION_ _REPLY_TO_MESSAGE_ID_ _REPLY_MARKUP_
	local _JSON_=$(getFileJQ $FUNCNAME)
	local _METHOD_=sendVenue	# Método
	
	# Lê os parâmetros da função
	local _PARAM_=$(getopt --name $FUNCNAME --options 'c:l:g:i:a:f:n:r:k:' \
										--longoptions 'chat_id:,
														latitude:,
														longitude:,
														title:,
														address:,
														foursquare_id:,
														disable_notification:,
														reply_to_message_id:,
														reply_markup:' \
														-- "$@")

	# Define os parâmetros posicionais
	eval set -- "$_PARAM_"
	
	while :
	do
		case $1 in
			-c|--chat_id)
				_CHAT_ID_="$2"
				shift 2
				;;
			-l|--latitude)
				# Tipo: float
				[[ "$2" =~ ^-?[0-9]+\.[0-9]+$ ]] || message_error API "$_ERR_TYPE_FLOAT_" "$1" "$2"
				_LATITUDE_="$2"
				shift 2
				;;
			-g|--longitude)
				# Tipo: float
				[[ "$2" =~ ^-?[0-9]+\.[0-9]+$ ]] || message_error API "$_ERR_TYPE_FLOAT_" "$1" "$2"
				_LONGITUDE_="$2"
				shift 2
				;;
			-i|--title)
				_TITLE_="$2"
				shift 2
				;;
			-a|--address)
				_ADDRESS_="$2"
				shift 2
				;;
			-f|--foursquare_id)
				_FOURSQUARE_ID_="$2"
				shift 2
				;;
			-n|--disable_notification)
				# Tipo: boolean
				[[ "$2" =~ ^(true|false)$ ]] || message_error API "$_ERR_TYPE_BOOL_" "$1" "$2"
				_DISABLE_NOTIFICATION_="$2"
				shift 2
				;;
			-r|--reply_to_message_id)
				# Tipo: inteiro
				[[ "$2" =~ ^[0-9]+$ ]] || message_error API "$_ERR_TYPE_INT_" "$1" "$2"
				_REPLY_TO_MESSAGE_ID_="$2"
				shift 2
				;;
			-k|--reply_markup)
				_REPLY_MARKUP_="$2"
				shift 2
				;;
			--)
				shift
				break
		esac
	done
			
	# Parâmetros obrigatórios.
	[[ $_CHAT_ID_ ]] || message_error API "$_ERR_PARAM_REQUIRED_" "[-c, --chat_id]"
	[[ $_LATITUDE_ ]] || message_error API "$_ERR_PARAM_REQUIRED_" "[-l, --latitude]"
	[[ $_LONGITUDE_ ]] || message_error API "$_ERR_PARAM_REQUIRED_" "[-g, --longitude]"
	[[ $_TITLE_ ]] || message_error API "$_ERR_PARAM_REQUIRED_" "[-i, --title]"
	[[ $_ADDRESS_ ]] || message_error API "$_ERR_PARAM_REQUIRED_" "[-a, --address]"
	
	# Chama o método
	eval $_POST_ $_API_TELEGRAM_/$_METHOD_ ${_CHAT_ID_:+-F chat_id="'$_CHAT_ID_'"} \
							${_LATITUDE_:+-F latitude="'$_LATITUDE_'"} \
							${_LONGITUDE_:+-F longitude="'$_LONGITUDE_'"} \
							${_TITLE_:+-F title="'$_TITLE_'"} \
							${_ADDRESS_:+-F address="'$_ADDRESS_'"} \
							${_FOURSQUARE_ID_:+-F foursquare_id="'$_FOURSQUARE_ID_'"} \
							${_DISABLE_NOTIFICATION_:+-F disable_notification="'$_DISABLE_NOTIFICATION_'"} \
							${_REPLY_TO_MESSAGE_ID_:+-F reply_to_message_id="'$_REPLY_TO_MESSAGE_ID_'"} \
							${_REPLY_MARKUP_:+-F reply_markup="'$_REPLY_MARKUP_'"} > $_JSON_

	# Testa o retorno do método
	json_status $_JSON_ || message_error TG $_JSON_

	# Status
	return $?
}

# Utilize essa função para enviar um contato + numero
ShellBot.sendContact()
{
	# Variáveis locais
	local _CHAT_ID_ _PHONE_NUMBER_ _FIRST_NAME_ _LAST_NAME_ _DISABLE_NOTIFICATION_ _REPLY_TO_MESSAGE_ID_ _REPLY_MARKUP_
	local _JSON_=$(getFileJQ $FUNCNAME)
	local _METHOD_=sendContact	# Método
	
	# Lê os parâmetros da função
	local _PARAM_=$(getopt --name $FUNCNAME --options 'c:p:f:l:n:r:k:' \
										--longoptions 'chat_id:,
														phone_number:,
														first_name:,
														last_name:,
														disable_notification:,
														reply_to_message_id:,
														reply_markup:' \
														-- "$@")


	# Define os parâmetros posicionais
	eval set -- "$_PARAM_"

	while :
	do
		case $1 in
			-c|--chat_id)
				_CHAT_ID_="$2"
				shift 2
				;;
			-p|--phone_number)
				_PHONE_NUMBER_="$2"
				shift 2
				;;
			-f|--first_name)
				_FIRST_NAME_="$2"
				shift 2
				;;
			-l|--last_name)
				_LAST_NAME_="$2"
				shift 2
				;;
			-n|--disable_notification)
				# Tipo: boolean
				[[ "$2" =~ ^(true|false)$ ]] || message_error API "$_ERR_TYPE_BOOL_" "$1" "$2"
				_DISABLE_NOTIFICATION_="$2"
				shift 2
				;;
			-r|--reply_to_message_id)
				# Tipo: inteiro
				[[ "$2" =~ ^[0-9]+$ ]] || message_error API "$_ERR_TYPE_INT_" "$1" "$2"
				_REPLY_TO_MESSAGE_ID_="$2"
				shift 2
				;;
			-k|--reply_markup)
				_REPLY_MARKUP_="$2"
				shift 2
				;;
			--)
				shift
				break
		esac
	done
	
	# Parâmetros obrigatórios.	
	[[ $_CHAT_ID_ ]] || message_error API "$_ERR_PARAM_REQUIRED_" "[-c, --chat_id]"
	[[ $_PHONE_NUMBER_ ]] || message_error API "$_ERR_PARAM_REQUIRED_" "[-p, --phone_number]"
	[[ $_FIRST_NAME_ ]] || message_error API "$_ERR_PARAM_REQUIRED_" "[-f, --first_name]"
	
	# Chama o método
	eval $_POST_ $_API_TELEGRAM_/$_METHOD_ ${_CHAT_ID_:+-F chat_id="'$_CHAT_ID_'"} \
							${_PHONE_NUMBER_:+-F phone_number="'$_PHONE_NUMBER_'"} \
							${_FIRST_NAME_:+-F first_name="'$_FIRST_NAME_'"} \
							${_LAST_NAME_:+-F last_name="'$_LAST_NAME_'"} \
							${_DISABLE_NOTIFICATION_:+-F disable_notification="'$_DISABLE_NOTIFICATION_'"} \
							${_REPLY_TO_MESSAGE_ID_:+-F reply_to_message_id="'$_REPLY_TO_MESSAGE_ID_'"} \
							${_REPLY_MARKUP_:+-F reply_markup="'$_REPLY_MARKUP_'"} > $_JSON_

	# Testa o retorno do método
	json_status $_JSON_ || message_error TG $_JSON_

	# Status
	return $?
}

# Envia uma ação para bot.
ShellBot.sendChatAction()
{
	# Variáveis locais
	local _CHAT_ID_ _ACTION_
	local _JSON_=$(getFileJQ $FUNCNAME)
	local _METHOD_=sendChatAction		# Método
	
	# Lê os parâmetros da função
	local _PARAM_=$(getopt --name $FUNCNAME --options 'c:a:' \
										--longoptions 'chat_id:,
														action:' \
														-- "$@")

	# Define os parâmetros posicionais
	eval set -- "$_PARAM_"

	while :
	do
		case $1 in
			-c|--chat_id)
				_CHAT_ID_="$2"
				shift 2
				;;
			-a|--action)
				[[ $2 =~ ^(typing|upload_photo|record_video|upload_video|
							record_audio|upload_audio|upload_document|
							find_location|record_video_note|upload_video_note)$ ]] || \
							# erro
							message_error API "$_ERR_ACTION_MODE_" "$1" "$2"
				_ACTION_="$2"
				shift 2
				;;
			--)
				shift
				break
		esac
	done

	# Parâmetros obrigatórios.		
	[[ $_CHAT_ID_ ]] || message_error API "$_ERR_PARAM_REQUIRED_" "[-c, --chat_id]"
	[[ $_ACTION_ ]] || message_error API "$_ERR_PARAM_REQUIRED_" "[-a, --action]"
	
	# Chama o método
	eval $_POST_ $_API_TELEGRAM_/$_METHOD_ ${_CHAT_ID_:+-d chat_id="'$_CHAT_ID_'"} \
													${_ACTION_:+-d action="'$_ACTION_'"} > $_JSON_
	
	# Testa o retorno do método
	json_status $_JSON_ || message_error TG $_JSON_

	# Status
	return $?
}

# Utilize essa função para obter as fotos de um determinado usuário.
ShellBot.getUserProfilePhotos()
{
	# Variáveis locais 
	local _USER_ID_ _OFFSET_ _LIMIT_ _IND_ _LAST_ _INDEX_ _MAX_ _ITEM_ _TOTAL_
	local _METHOD_=getUserProfilePhotos # Método
    local _JSON_=$(getFileJQ $FUNCNAME)

	# Lê os parâmetros da função
	local _PARAM_=$(getopt --name $FUNCNAME --options 'u:o:l:' \
										--longoptions 'user_id:,
														offset:,
														limit:' \
														-- "$@")

	
	# Define os parâmetros posicionais
	eval set -- "$_PARAM_"
	
	while :
	do
		case $1 in
			-u|--user_id)
				[[ "$2" =~ ^[0-9]+$ ]] || message_error API "$_ERR_TYPE_INT_" "$1" "$2"
				_USER_ID_="$2"
				shift 2
				;;
			-o|--offset)
				[[ "$2" =~ ^[0-9]+$ ]] || message_error API "$_ERR_TYPE_INT_" "$1" "$2"
				_OFFSET_="$2"
				shift 2
				;;
			-l|--limit)
				[[ "$2" =~ ^[0-9]+$ ]] || message_error API "$_ERR_TYPE_INT_" "$1" "$2"
				_LIMIT_="$2"
				shift 2
				;;
			--)
				shift
				break
				;;
		esac
	done
	
	# Parâmetros obrigatórios.
	[[ $_USER_ID_ ]] || message_error API "$_ERR_PARAM_REQUIRED_" "[-u, --user_id]"
	
	# Chama o método
	eval $_GET_ $_API_TELEGRAM_/$_METHOD_ ${_USER_ID_:+-d user_id="'$_USER_ID_'"} \
													${_OFFSET_:+-d offset="'$_OFFSET_'"} \
													${_LIMIT_:+-d limit="'$_LIMIT_'"} > $_JSON_

	# Verifica se ocorreu erros durante a chamada do método	
	json_status $_JSON_ && {

		_TOTAL_=$(json $_JSON_ '.result.total_count')

		if [[ $_TOTAL_ -gt 0 ]]; then	
			for _INDEX_ in $(seq 0 $((_TOTAL_-1)))
			do
				_MAX_=$(json $_JSON_ ".result.photos[$_INDEX_]|length")
				for _ITEM_ in $(seq 0 $((_MAX_-1)))
				do
					json $_JSON_ ".result.photos[$_INDEX_][$_ITEM_]|.file_id, .file_size, .width, .height" | sed ':a;$!N;s/\n/|/;ta'
				done
			done
		fi	

	} || message_error TG $_JSON_

	# Status
	return $?
}

# Função para listar informações do arquivo especificado.
ShellBot.getFile()
{
	# Variáveis locais
	local _FILE_ID_
	local _METHOD_=getFile # Método
	local _JSON_=$(getFileJQ $FUNCNAME)

	# Lê os parâmetros da função
	local _PARAM_=$(getopt --name $FUNCNAME --options 'f:' \
										--longoptions 'file_id:' \
														-- "$@")

	
	# Define os parâmetros posicionais
	eval set -- "$_PARAM_"

	while :
	do
		case $1 in
			-f|--file_id)
				_FILE_ID_="$2"
				shift 2
				;;
			--)
				shift
				break
				;;
		esac
	done
	
	# Parâmetros obrigatórios.
	[[ $_FILE_ID_ ]] || message_error API "$_ERR_PARAM_REQUIRED_" "[-f, --file_id]"
	
	# Chama o método.
	eval $_GET_ $_API_TELEGRAM_/$_METHOD_ ${_FILE_ID_:+-d file_id="'$_FILE_ID_'"} > $_JSON_

	# Testa o retorno do método.
	json_status $_JSON_ && {
		# Extrai as informações, agrupando-as em uma única linha e insere o delimitador '|' PIPE entre os campos.
		json $_JSON_ '.result|.file_id, .file_size, .file_path' | sed ':a;$!N;s/\n/|/;ta'
	} || message_error TG $_JSON_

	# Status
	return $?
}		

# Essa função kicka o usuário do chat ou canal. (somente administradores)
ShellBot.kickChatMember()
{
	# Variáveis locais
	local _CHAT_ID_ _USER_ID_ _UNTIL_DATE_
	local _JSON_=$(getFileJQ $FUNCNAME)
	local _METHOD_=kickChatMember		# Método

	# Lê os parâmetros da função
	local _PARAM_=$(getopt --name $FUNCNAME --options 'c:u:d:' \
										--longoptions 'chat_id:,
														user_id:,
														until_date:' \
														-- "$@")

	# Define os parâmetros posicionais
	eval set -- "$_PARAM_"

	# Trata os parâmetros
	while :
	do
		case $1 in
			-c|--chat_id)
				_CHAT_ID_="$2"
				shift 2
				;;
			-u|--user_id)
				[[ "$2" =~ ^[0-9]+$ ]] || message_error API "$_ERR_TYPE_INT_" "$1" "$2"
				_USER_ID_="$2"
				shift 2
				;;
			-d|--until_date)
				[[ "$2" =~ ^[0-9]+$ ]] || message_error API "$_ERR_TYPE_INT_" "$1" "$2"
				_UNTIL_DATE_="$2"
				shift 2
				;;
			--)
				shift
				break
				;;
		esac
	done
	
	# Parametros obrigatórios.
	[[ $_CHAT_ID_ ]] || message_error API "$_ERR_PARAM_REQUIRED_" "[-c, --chat_id]"
	[[ $_USER_ID_ ]] || message_error API "$_ERR_PARAM_REQUIRED_" "[-u, --user_id]"
	
	# Chama o método
	eval $_POST_ $_API_TELEGRAM_/$_METHOD_ ${_CHAT_ID_:+-d chat_id="'$_CHAT_ID_'"} \
												${_USER_ID_:+-d user_id="'$_USER_ID_'"} \
												${_UNTIL_DATE_:+-d until_date="'$_UNTIL_DATE_'"} > $_JSON_

	# Verifica se ocorreu erros durante a chamada do método	
	json_status $_JSON_ || message_error TG $_JSON_

	# Status
	return $?
}

# Utilize essa função para remove o bot do grupo ou canal.
ShellBot.leaveChat()
{
	# Variáveis locais
	local _CHAT_ID_
	local _JSON_=$(getFileJQ $FUNCNAME)
	local _METHOD_=leaveChat	# Método

	# Lê os parâmetros da função
	local _PARAM_=$(getopt --name $FUNCNAME --options 'c:' \
										--longoptions 'chat_id:' \
														-- "$@")

	
	# Define os parâmetros posicionais
	eval set -- "$_PARAM_"

	while :
	do
		case $1 in
			-c|--chat_id)
				_CHAT_ID_="$2"
				shift 2
				;;
			--)
				shift
				break
				;;
		esac
	done

	[[ $_CHAT_ID_ ]] || message_error API "$_ERR_PARAM_REQUIRED_" "[-c, --chat_id]"
	
	eval $_POST_ $_API_TELEGRAM_/$_METHOD_ ${_CHAT_ID_:+-d chat_id="'$_CHAT_ID_'"} > $_JSON_

	# Verifica se ocorreu erros durante a chamada do método	
	json_status $_JSON_ || message_error TG $_JSON_

	return $?
	
}

ShellBot.unbanChatMember()
{
	local _CHAT_ID_ _USER_ID_
	local _JSON_=$(getFileJQ $FUNCNAME)

	# Lê os parâmetros da função
	local _PARAM_=$(getopt --name $FUNCNAME --options 'c:u:' \
										--longoptions 'chat_id:,
														user_id:' \
														-- "$@")

	local _METHOD_=unbanChatMember
	
	# Define os parâmetros posicionais
	eval set -- "$_PARAM_"

	while :
	do
		case $1 in
			-c|--chat_id)
				_CHAT_ID_="$2"
				shift 2
				;;
			-u|--user_id)
				[[ "$2" =~ ^[0-9]+$ ]] || message_error API "$_ERR_TYPE_INT_" "$1" "$2"
				_USER_ID_="$2"
				shift 2
				;;
			--)
				shift
				break
				;;
		esac
	done
	
	[[ $_CHAT_ID_ ]] || message_error API "$_ERR_PARAM_REQUIRED_" "[-c, --chat_id]"
	[[ $_USER_ID_ ]] || message_error API "$_ERR_PARAM_REQUIRED_" "[-u, --user_id]"
	
	eval $_POST_ $_API_TELEGRAM_/$_METHOD_ ${_CHAT_ID_:+-d chat_id="'$_CHAT_ID_'"} \
												${_USER_ID_:+-d user_id="'$_USER_ID_'"} > $_JSON_

	# Verifica se ocorreu erros durante a chamada do método	
	json_status $_JSON_ || message_error TG $_JSON_

	return $?
}

ShellBot.getChat()
{
	# Variáveis locais
	local _CHAT_ID_
	local _METHOD_=getChat	# Método
	local _JSON_=$(getFileJQ $FUNCNAME)

	# Lê os parâmetros da função
	local _PARAM_=$(getopt --name $FUNCNAME --options 'c:' \
										--longoptions 'chat_id:' \
														-- "$@")

	
	# Define os parâmetros posicionais
	eval set -- "$_PARAM_"

	while :
	do
		case $1 in
			-c|--chat_id)
				_CHAT_ID_="$2"
				shift 2
				;;
			--)
				shift
				break
				;;
		esac
	done

	[[ $_CHAT_ID_ ]] || message_error API "$_ERR_PARAM_REQUIRED_" "[-c, --chat_id]"
	
	eval $_GET_ $_API_TELEGRAM_/$_METHOD_ ${_CHAT_ID_:+-d chat_id="'$_CHAT_ID_'"} > $_JSON_

	# Verifica se ocorreu erros durante a chamada do método	
	json_status $_JSON_ && {
		# Imprime os dados.
		json $_JSON_ '.result|
						.id, 
						.username,
						.type,
						.title,
						.username,
						.first_name,
						.last_name,
						.all_members_are_administrators,
						.photo[],
						.description,
						.invite_link' | sed ':a;$!N;s/\n/|/;ta'

	} || message_error TG $_JSON_

	# Status
	return $?
}

ShellBot.getChatAdministrators()
{
	local _CHAT_ID_ _TOTAL_ _KEY_ _INDEX_
	local _JSON_=$(getFileJQ $FUNCNAME)

	# Lê os parâmetros da função
	local _PARAM_=$(getopt --name $FUNCNAME --options 'c:' \
										--longoptions 'chat_id:' \
														-- "$@")

	local _METHOD_=getChatAdministrators
	
	# Define os parâmetros posicionais
	eval set -- "$_PARAM_"

	while :
	do
		case $1 in
			-c|--chat_id)
				_CHAT_ID_="$2"
				shift 2
				;;
			--)
				shift
				break
				;;
		esac
	done

	[[ $_CHAT_ID_ ]] || message_error API "$_ERR_PARAM_REQUIRED_" "[-c, --chat_id]"
	
	eval $_GET_ $_API_TELEGRAM_/$_METHOD_ ${_CHAT_ID_:+-d chat_id="'$_CHAT_ID_'"} > $_JSON_

	# Verifica se ocorreu erros durante a chamada do método	
	json_status $_JSON_ && {

		# Total de administratores
		declare -i _TOTAL_=$(json $_JSON_ '.result|length')

		# Lê os administradores do grupo se houver.
		if [ $_TOTAL_ -gt 0 ]; then
			for _INDEX_ in $(seq 0 $((_TOTAL_-1)))
			do
				# Lê as informações do usuário armazenadas em '_INDEX_'.
				json $_JSON_ ".result[$_INDEX_]|[.user|
								.id,
								.username,
								.first_name,
								.last_name][], 
								.status,
								.until_date,
								.can_be_edited,
								.can_change_info,
								.can_post_messages,
								.can_edit_messages,
								.can_delete_messages,
								.can_invite_users,
								.can_restrict_members,
								.can_pin_messages,
								.can_promote_members,
								.can_send_messages,
								.can_send_media_messages,
								.can_send_other_messages,
								.can_add_web_page_previews" | sed ':a;$!N;s/\n/|/;ta'
			done
		fi

	} || message_error TG $_JSON_

	# Status	
	return $?
}

ShellBot.getChatMembersCount()
{
	local _CHAT_ID_
	local _JSON_=$(getFileJQ $FUNCNAME)

	# Lê os parâmetros da função
	local _PARAM_=$(getopt --name $FUNCNAME --options 'c:' \
										--longoptions 'chat_id:' \
														-- "$@")

	local _METHOD_=getChatMembersCount
	
	# Define os parâmetros posicionais
	eval set -- "$_PARAM_"

	while :
	do
		case $1 in
			-c|--chat_id)
				_CHAT_ID_="$2"
				shift 2
				;;
			--)
				shift
				break
				;;
		esac
	done

	[[ $_CHAT_ID_ ]] || message_error API "$_ERR_PARAM_REQUIRED_" "[-c, --chat_id]"
	
	eval $_GET_ $_API_TELEGRAM_/$_METHOD_ ${_CHAT_ID_:+-d chat_id="'$_CHAT_ID_'"} > $_JSON_

	# Verifica se ocorreu erros durante a chamada do método	
	json_status $_JSON_ && json $_JSON_ '.result' || message_error TG $_JSON_

	return $?
}

ShellBot.getChatMember()
{
	# Variáveis locais
	local _CHAT_ID_ _USER_ID_
	local _METHOD_=getChatMember	# Método
	local _JSON_=$(getFileJQ $FUNCNAME)

	# Lê os parâmetros da função
	local _PARAM_=$(getopt --name $FUNCNAME --options 'c:u:' \
										--longoptions 'chat_id:,
														user_id:' \
														-- "$@")

	
	# Define os parâmetros posicionais
	eval set -- "$_PARAM_"

	while :
	do
		case $1 in
			-c|--chat_id)
				_CHAT_ID_="$2"
				shift 2
				;;
			-u|--user_id)
				[[ "$2" =~ ^[0-9]+$ ]] || message_error API "$_ERR_TYPE_INT_" "$1" "$2"
				_USER_ID_="$2"
				shift 2
				;;
			--)
				shift
				break
				;;
		esac
	done
	
	[[ $_CHAT_ID_ ]] || message_error API "$_ERR_PARAM_REQUIRED_" "[-c, --chat_id]"
	[[ $_USER_ID_ ]] || message_error API "$_ERR_PARAM_REQUIRED_" "[-u, --user_id]"
	
	eval $_GET_ $_API_TELEGRAM_/$_METHOD_ ${_CHAT_ID_:+-d chat_id="'$_CHAT_ID_'"} \
												${_USER_ID_:+-d user_id="'$_USER_ID_'"} > $_JSON_

	# Verifica se ocorreu erros durante a chamada do método	
	json_status $_JSON_ && {
		json $_JSON_ ".result|[.user|
							.id,
							.username,
							.first_name,
							.last_name][], 
							.status,
							.until_date,
							.can_be_edited,
							.can_change_info,
							.can_post_messages,
							.can_edit_messages,
							.can_delete_messages,
							.can_invite_users,
							.can_restrict_members,
							.can_pin_messages,
							.can_promote_members,
							.can_send_messages,
							.can_send_media_messages,
							.can_send_other_messages,
							.can_add_web_page_previews" | sed ':a;$!N;s/\n/|/;ta'

	} || message_error TG $_JSON_

	return $?
}

ShellBot.editMessageText()
{
	local _CHAT_ID_ _MESSAGE_ID_ _INLINE_MESSAGE_ID_ _TEXT_ _PARSE_MODE_ _DISABLE_WEB_PAGE_PREVIEW_ _REPLY_MARKUP_
	local _JSON_=$(getFileJQ $FUNCNAME)
	local _METHOD_=editMessageText
	
	local _PARAM_=$(getopt --name $FUNCNAME --options 'c:m:i:t:p:w:r:' \
										--longoptions 'chat_id:,
														message_id:,
														inline_message_id:,
														text:,
														parse_mode:,
														disable_web_page_preview:,
														reply_markup:' \
														-- "$@")
	
	eval set -- "$_PARAM_"

	while :
	do
			case $1 in
				-c|--chat_id)
					_CHAT_ID_="$2"
					shift 2
					;;
				-m|--message_id)
					[[ "$2" =~ ^[0-9]+$ ]] || message_error API "$_ERR_TYPE_INT_" "$1" "$2"
					_MESSAGE_ID_="$2"
					shift 2
					;;
				-i|--inline_message_id)
					[[ "$2" =~ ^[0-9]+$ ]] || message_error API "$_ERR_TYPE_INT_" "$1" "$2"
					_INLINE_MESSAGE_ID_="$2"
					shift 2
					;;
				-t|--text)
					_TEXT_="$2"
					shift 2
					;;
				-p|--parse_mode)
					[[ "$2" =~ ^(markdown|html)$ ]] || message_error API "$_ERR_TYPE_PARSE_MODE_" "$1" "$2"
					_PARSE_MODE_="$2"
					shift 2
					;;
				-w|--disable_web_page_preview)
					[[ "$2" =~ ^(true|false)$ ]] || message_error API "$_ERR_TYPE_BOOL_" "$1" "$2"
					_DISABLE_WEB_PAGE_PREVIEW_="$2"
					shift 2
					;;
				-r|--reply_markup)
					_REPLY_MARKUP_="$2"
					shift 2
					;;
				--)
					shift
					break
			esac
	done
	
	[[ ! $_CHAT_ID_ && ! $_MESSAGE_ID_ ]] && {
		[[ $_INLINE_MESSAGE_ID ]] || message_error API "$_ERR_PARAM_REQUIRED_" "[-i, --inline_message_id]"
		unset _CHAT_ID_ _MESSAGE_ID_
	} || {
		[[ $_CHAT_ID_ ]] || message_error API "$_ERR_PARAM_REQUIRED_" "[-c, --chat_id]"
		[[ $_MESSAGE_ID_ ]] || message_error API "$_ERR_PARAM_REQUIRED_" "[-m, --message_id]"
		unset _INLINE_MESSAGE_ID_
	} 
	
	[[ $_TEXT_ ]] || message_error API "$_ERR_PARAM_REQUIRED_" "[-t, --text]"

	eval $_POST_ $_API_TELEGRAM_/$_METHOD_ ${_CHAT_ID_:+-d chat_id="'$_CHAT_ID_'"} \
											${_MESSAGE_ID_:+-d message_id="'$_MESSAGE_ID_'"} \
											${_INLINE_MESSAGE_ID_:+-d inline_message_id="'$_INLINE_MESSAGE_ID_'"} \
											${_TEXT_:+-d text="'$_TEXT_'"} \
											${_PARSE_MODE_:+-d parse_mode="'$_PARSE_MODE_'"} \
											${_DISABLE_WEB_PAGE_PREVIEW_:+-d disable_web_page_preview="'$_DISABLE_WEB_PAGE_PREVIEW_'"} \
											${_REPLY_MARKUP_:+-d reply_markup="'$_REPLY_MARKUP_'"} > $_JSON_

	# Verifica se ocorreu erros durante a chamada do método	
	json_status $_JSON_ || message_error TG $_JSON_
	
	return $?
	
}

ShellBot.editMessageCaption()
{
	local _CHAT_ID_ _MESSAGE_ID_ _INLINE_MESSAGE_ID_ _CAPTION_ _REPLY_MARKUP_
	local _JSON_=$(getFileJQ $FUNCNAME)
	local _METHOD_=editMessageCaption
	
	local _PARAM_=$(getopt --name $FUNCNAME --options 'c:m:i:t:r:' \
										--longoptions 'chat_id:,
														message_id:,
														inline_message_id:,
														caption:,
														reply_markup:' \
														-- "$@")
	
	eval set -- "$_PARAM_"

	while :
	do
			case $1 in
				-c|--chat_id)
					_CHAT_ID_="$2"
					shift 2
					;;
				-m|--message_id)
					[[ "$2" =~ ^[0-9]+$ ]] || message_error API "$_ERR_TYPE_INT_" "$1" "$2"
					_MESSAGE_ID_="$2"
					shift 2
					;;
				-i|--inline_message_id)
					[[ "$2" =~ ^[0-9]+$ ]] || message_error API "$_ERR_TYPE_INT_" "$1" "$2"
					_INLINE_MESSAGE_ID_="$2"
					shift 2
					;;
				-t|--caption)
					_CAPTION_="$2"
					shift 2
					;;
				-r|--reply_markup)
					_REPLY_MARKUP_="$2"
					shift 2
					;;
				--)
					shift
					break
			esac
	done
				
	[[ $_CHAT_ID_ ]] || message_error API "$_ERR_PARAM_REQUIRED_" "[-c, --chat_id]"
	[[ $_MESSAGE_ID_ ]] || message_error API "$_ERR_PARAM_REQUIRED_" "[-m, --message_id]"
	
	eval $_POST_ $_API_TELEGRAM_/$_METHOD_ ${_CHAT_ID_:+-d chat_id="'$_CHAT_ID_'"} \
													${_MESSAGE_ID_:+-d message_id="'$_MESSAGE_ID_'"} \
													${_INLINE_MESSAGE_ID_:+-d inline_message_id="'$_INLINE_MESSAGE_ID_'"} \
													${_CAPTION_:+-d caption="'$_CAPTION_'"} \
													${_REPLY_MARKUP_:+-d reply_markup="'$_REPLY_MARKUP_'"} > $_JSON_

	# Verifica se ocorreu erros durante a chamada do método	
	json_status $_JSON_ || message_error TG $_JSON_
	
	return $?
	
}

ShellBot.editMessageReplyMarkup()
{
	local _CHAT_ID_ _MESSAGE_ID_ _INLINE_MESSAGE_ID_ _REPLY_MARKUP_
	local _JSON_=$(getFileJQ $FUNCNAME)
	local _METHOD_=editMessageReplyMarkup
	
	local _PARAM_=$(getopt --name $FUNCNAME --options 'c:m:i:r:' \
										--longoptions 'chat_id:,
														message_id:,
														inline_message_id:,
														reply_markup:' \
														-- "$@")
	
	eval set -- "$_PARAM_"

	while :
	do
			case $1 in
				-c|--chat_id)
					_CHAT_ID_="$2"
					shift 2
					;;
				-m|--message_id)
					[[ "$2" =~ ^[0-9]+$ ]] || message_error API "$_ERR_TYPE_INT_" "$1" "$2"
					_MESSAGE_ID_="$2"
					shift 2
					;;
				-i|--inline_message_id)
					[[ "$2" =~ ^[0-9]+$ ]] || message_error API "$_ERR_TYPE_INT_" "$1" "$2"
					_INLINE_MESSAGE_ID_="$2"
					shift 2
					;;
				-r|--reply_markup)
					_REPLY_MARKUP_="$2"
					shift 2
					;;
				--)
					shift
					break
			esac
	done

	[[ ! $_CHAT_ID_ && ! $_MESSAGE_ID_ ]] && {
		[[ $_INLINE_MESSAGE_ID ]] || message_error API "$_ERR_PARAM_REQUIRED_" "[-i, --inline_message_id]"
		unset _CHAT_ID_ _MESSAGE_ID_
	} || {
		[[ $_CHAT_ID_ ]] || message_error API "$_ERR_PARAM_REQUIRED_" "[-c, --chat_id]"
		[[ $_MESSAGE_ID_ ]] || message_error API "$_ERR_PARAM_REQUIRED_" "[-m, --message_id]"
		unset _INLINE_MESSAGE_ID_
	} 
	
	eval $_POST_ $_API_TELEGRAM_/$_METHOD_ ${_CHAT_ID_:+-d chat_id="'$_CHAT_ID_'"} \
													${_MESSAGE_ID_:+-d message_id="'$_MESSAGE_ID_'"} \
													${_INLINE_MESSAGE_ID_:+-d inline_message_id="'$_INLINE_MESSAGE_ID_'"} \
													${_REPLY_MARKUP_:+-d reply_markup="'$_REPLY_MARKUP_'"} > $_JSON_

	# Verifica se ocorreu erros durante a chamada do método	
	json_status $_JSON_ || message_error TG $_JSON_
	
	return $?
	
}

ShellBot.deleteMessage()
{
	local _CHAT_ID_ _MESSAGE_ID_
	local _JSON_=$(getFileJQ $FUNCNAME)
	local _METHOD_=deleteMessage
	
	local _PARAM_=$(getopt --name $FUNCNAME --options 'c:m:' \
										--longoptions 'chat_id:,
														message_id:' \
														-- "$@")
	
	eval set -- "$_PARAM_"

	while :
	do
			case $1 in
				-c|--chat_id)
					_CHAT_ID_="$2"
					shift 2
					;;
				-m|--message_id)
					[[ "$2" =~ ^[0-9]+$ ]] || message_error API "$_ERR_TYPE_INT_" "$1" "$2"
					_MESSAGE_ID_="$2"
					shift 2
					;;
				--)
					shift
					break
			esac
	done
	
	[[ $_CHAT_ID_ ]] || message_error API "$_ERR_PARAM_REQUIRED_" "[-c, --chat_id]"
	[[ $_MESSAGE_ID_ ]] || message_error API "$_ERR_PARAM_REQUIRED_" "[-m, --message_id]"

	eval $_POST_ $_API_TELEGRAM_/$_METHOD_ ${_CHAT_ID_:+-d chat_id="'$_CHAT_ID_'"} \
													${_MESSAGE_ID_:+-d message_id="'$_MESSAGE_ID_'"}  > $_JSON_

	# Verifica se ocorreu erros durante a chamada do método	
	json_status $_JSON_ || message_error TG $_JSON_
	
	return $?

}


ShellBot.getUpdates()
{
	local -i _TOTAL_KEYS_ _TOTAL_PHOTO_ _OFFSET_ _LIMIT_ _TIMEOUT_ _ALLOWED_UPDATES_
	local _KEY_ _SUBKEY_ _UPDATE_

	local _METHOD_=getUpdates	# Mètodo
	local _JSON_=$(getFileJQ $FUNCNAME)

	# Define os parâmetros da função
	local _PARAM_=$(getopt  --name $FUNCNAME --options 'o:l:t:a:' \
												--longoptions 'offset:,
														limit:,
														timeout:,
														allowed_updates:' \
														-- "$@")

	
	eval set -- "$_PARAM_"
	
	while :
	do
		case $1 in
			-o|--offset)
				[[ "$2" =~ ^[0-9]+$ ]] || message_error API "$_ERR_TYPE_INT_" "$1" "$2"
				_OFFSET_="$2"
				shift 2
				;;
			-l|--limit)
				[[ "$2" =~ ^[0-9]+$ ]] || message_error API "$_ERR_TYPE_INT_" "$1" "$2"
				_LIMIT_="$2"
				shift 2
				;;
			-t|--timeout)
				[[ "$2" =~ ^[0-9]+$ ]] || message_error API "$_ERR_TYPE_INT_" "$1" "$2"
				_TIMEOUT_="$2"
				shift 2
				;;
			-a|--allowed_updates)
				_ALLOWED_UPDATES_="$2"
				shift 2
				;;
			--)
				# Se não houver mais parâmetros
				shift 
				break
				;;
		esac
	done

	# Seta os parâmetros
	eval $_GET_ $_API_TELEGRAM_/$_METHOD_ ${_OFFSET_:+-d offset="'$_OFFSET_'"} \
						${_LIMIT_:+-d limit="'$_LIMIT_'"} \
						${_TIMEOUT_:+-d timeout="'$_TIMEOUT_'"} \
						${_ALLOWED_UPDATES_:+-d allowed_updates="'$_ALLOWED_UPDATES_'"} > $_JSON_

	
	# Limpa todas as variáveis inicializadas.
	unset update_id ${!message_*} ${!edited_message_*} ${!channel_post_*} ${!edited_channel_post_*} ${!callback_query_*} \
					${!inline_query_*} ${!chosen_inline_result} ${!shipping_query_*} ${!pre_checkout_query_*} 
	
	# Verifica se ocorreu erros durante a chamada do método	
	json_status $_JSON_ && {

	# Total de atualizações
	_TOTAL_KEYS_=$(json $_JSON_ '.result|length')

	if [[ $_TOTAL_KEYS_ -gt 0 ]]; then
		
		# inicializada
		local key key_list obj obj_cur obj_type var_name i
			
		# Salva e fecha o descritor de erro
		exec 5<&2
		exec 2<&-

		for _INDEX_ in $(seq 0 $((_TOTAL_KEYS_-1)))
		do
			_UPDATE_=".result[$_INDEX_]"
			
			# Inicializa.
			unset key_list
			key_list[0]=$_UPDATE_
				
			# Lê todas as chaves do arquivo json $_JSON_ recursivamente enquanto houver objetos.
			while [[ ${key_list[@]} ]]
			do
			    i=0
				
			    # Lista objetos.
				for key in ${key_list[@]}
			    do
					# Limpa o buffer
			        unset key_list

					# Lê as chaves do atual objeto
			        for obj in $(json $_JSON_ "$key|keys[]")
			        do
						# Se o tipo da chave for string, number ou boolean, imprime o valor armazenado.
						# Se for object salva o nível atual em key_list. Caso contrário, lê o próximo
						# elemento da lista.
            			obj_cur="$key.$obj"
			            obj_type=$(json $_JSON_ "$obj_cur|type")

            			if [[ $obj_type =~ (string|number|boolean) ]]; then
							# Define a nomenclatura válida para a variável que irá armazenar o valor da chave.
            				var_name=${obj_cur#.result\[$_INDEX_\].}
							var_name=${var_name//[]/}
		            	    var_name=${var_name//./_}
							
							# Salva o valor.
							eval $var_name[$_INDEX_]="'$(json $_JSON_ "$obj_cur")'"
				
			            elif [[ $obj_type = object ]]; then
			                key_list[$((i++))]=$obj_cur
						elif [[ $obj_type = array ]]; then
							key_list[$((i++))]=$obj_cur[]
            			fi
			        done
			    done
			done
		done
	
		# restaura o descritor de erro
		exec 2<&5
	fi

	} || message_error TG $_JSON_

	# Status
	return $?
}

# Funções somente leitura
declare -rf json_status \
			message_error \
			getFileJQ \
			ShellBot.regHandleFunction \
			ShellBot.watchHandle \
			ShellBot.ListUpdates \
			ShellBot.TotalUpdates \
			ShellBot.OffsetEnd \
			ShellBot.OffsetNext \
			ShellBot.getMe \
			ShellBot.getWebhookInfo \
			ShellBot.deleteWebhook \
			ShellBot.setWebhook \
			ShellBot.init \
			ShellBot.ReplyKeyboardMarkup \
			ShellBot.sendMessage \
			ShellBot.forwardMessage \
			ShellBot.sendPhoto \
			ShellBot.sendAudio \
			ShellBot.sendDocument \
			ShellBot.sendSticker \
			ShellBot.sendVideo \
			ShellBot.sendVideoNote \
			ShellBot.sendVoice \
			ShellBot.sendLocation \
			ShellBot.sendVenue \
			ShellBot.sendContact \
			ShellBot.sendChatAction \
			ShellBot.getUserProfilePhotos \
			ShellBot.getFile \
			ShellBot.kickChatMember \
			ShellBot.leaveChat \
			ShellBot.unbanChatMember \
			ShellBot.getChat \
			ShellBot.getChatAdministrators \
			ShellBot.getChatMembersCount \
			ShellBot.getChatMember \
			ShellBot.editMessageText \
			ShellBot.editMessageCaption \
			ShellBot.editMessageReplyMarkup \
			ShellBot.InlineKeyboardMarkup \
			ShellBot.InlineKeyboardButton \
			ShellBot.answerCallbackQuery \
			ShellBot.deleteMessage \
			ShellBot.exportChatInviteLink \
			ShellBot.setChatPhoto \
			ShellBot.deleteChatPhoto \
			ShellBot.setChatTitle \
			ShellBot.setChatDescription \
			ShellBot.pinChatMessage \
			ShellBot.unpinChatMessage \
			ShellBot.promoteChatMember \
			ShellBot.restrictChatMember \
			ShellBot.getUpdates
#FIM
