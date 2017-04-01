#!/bin/bash

#-----------------------------------------------------------------------------------------------------------
#	Data:				7 de março de 2017
#	Script:				ShellBot.sh
#	Versão:				2.0
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

# Verifica se os pacotes necessários estão instalados.
for __PKG__ in curl jq; do
	# Se estiver ausente, trata o erro e finaliza o script.
	if ! which $__PKG__ &>/dev/null; then
		echo "ShellBot.sh: erro: '$__PKG__' O pacote requerido não está instalando." 1>&2
		exit 1	# Status
	fi
done

# Verifica se a API já foi instanciada.
[ "$__INIT__" ] && return 1

# Inicializada
declare -r __INIT__=1

# Inicia o script sem erros.
declare -i __ERR__=0

# Arquivo JSON (JavaScript Object Notation) onde são gravados os objetos sempre que função getUpdates é chamada.
# O arquivo armazena os dados da atualização que serão acessados durante a execução de outros métodos; Onde o mesmo
# é sobrescrito sempre que um valor é retornado.
declare -r __JSON__=/tmp/update.json

# Define a linha de comando para as chamadas GET e PUT do métodos da API via curl.
declare -r __GET__='curl --silent --request GET --url'
declare -r __POST__='curl --silent --request POST --url'
 
# Funções para extração dos objetos armazenados no arquivo "update.json"
# 
# Verifica o retorno após a chamada de um método, se for igual a true (sucesso) retorna 0, caso contrário, retorna 1
json() { jq -r "$*" $__JSON__ 2>/dev/null; }
json_status(){ [ "$(json '.ok')" = true ] && return 0 || return 1; }

# Extrai o comprimento da string removendo o caractere nova-linha (\n)
str_len(){ echo $(($(wc -c <<< "$*")-1)); return 0; }

# Erros registrados da API (Parâmetros/Argumentos)
declare -r __ERR_TYPE_BOOL__='Tipo incompatível. Somente "true" ou "false".'
declare -r __ERR_TYPE_PARSE_MODE__='Tipo incompatível. Somente "markdown" ou "html".'
declare -r __ERR_TYPE_INT__='Tipo incompatível. Somente inteiro.'
declare -r __ERR_TYPE_FLOAT__='Tipo incompatível. Somente float.'
declare -r __ERR_CAPTION_MAX_CHAR__='Número máximo de caracteres excedido.'
declare -r __ERR_ACTION_MODE__='Ação inválida. Somente "typing" ou "upload_photo" ou "record_video" ou "upload_video" ou "record_audio" ou "upload_audio" ou "upload_document" ou "find_location".'
declare -r __ERR_PARAM_INVALID__='Parâmetro inválido.'
declare -r __ERR_PARAM_REQUIRED__='Parâmetro/argumento requerido.'
declare -r __ERR_TOKEN__="Não autorizado. Verifique o número do TOKEN ou se possui privilégios."

# Trata os erros
message_error()
{
	# Variáveis locais
	local __ERR_MESSAGE__ __ERR_ARG_VALUE__ __ERR_PARAM__ __ERR_CODE__ __DESCRIPTION__ __EXIT__
	
	# A variável 'BASH_LINENO' é dinâmica e armazena o número da linha onde foi expandida.
	# Quando chamada dentro de um subshell, passa ser instanciada como um array, armazenando diversos
	# valores onde cada índice refere-se a um shell/subshell. As mesmas caracteristicas se aplicam a variável
	# 'FUNCNAME', onde é armazenado o nome da função onde foi chamada.
	local __LINE=${BASH_LINENO[$((${#BASH_LINENO[*]}-2))]}	# Obtem o número da linha no shell pai.
	local __FUNC=${FUNCNAME[$((${#FUNCNAME[*]}-2))]}		# Obtem o nome da função no shell pai.

	# Define a execução com a tag de erro.
	__ERR__=1

	# Lê o tipo de ocorrência do erro.
	# TG - Erro externo, retornado pelo core do telegram
	# API - Erro interno, gerado pela API ShellBot.
	case $1 in
		TG)
			# Extrai as informações de erro no arquivo "update.json"
			__ERR_CODE__=$(json '.error_code')
			__DESCRIPTION__=$(json '.description')
			__ERR_MESSAGE__="${__ERR_CODE__:-1}: ${__DESCRIPTION__:-Ocorreu um problema durante a tentativa de atualização.}"
			;;
		API)
			# Define as variáveis com os valores passados na função "error.message"
			__ERR_PARAM__="$3"
			__ERR_ARG_VALUE__="$4"
			# Insere um '-', caso o valor de '__ERR_PARAM__' e '__ERR_ARG_VALUE__' for nulo; Se não houver
			# mensagem de erro, imprime 'Erro desconhecido'
			__ERR_MESSAGE__="${__ERR_PARAM__:--}: ${__ERR_ARG_VALUE__:--}: ${2:-Erro desconhecido}"
			__EXIT__=1
			;;
	esac
	
	# Imprime mensagem de erro
	echo "$(basename "$0"): linha ${__LINE:--}: ${__FUNC:-NULL}: ${__ERR_MESSAGE__}" 1>&2
	
	# Finaliza script em caso de erro interno, caso contrário retorna o valor $__ERR__
	[ "$__EXIT__" ] && exit 1 || return $__ERR__
}

# Inicializa o bot, definindo sua API e TOKEN.
# Atenção: Essa função precisa ser instanciada antes de qualquer outro método.
ShellBot.init()
{
	# Variável local
	local __PARAM__=$(getopt --quiet --options 't:' \
										--longoptions 'token:' \
										-- "$@")
	
	# Inicia a função sem erros
	__ERR__=0

	# Define os parâmetros posicionais
	eval set -- "$__PARAM__"

	while :
	do
		case $1 in
			-t|--token)
				declare -gr __TOKEN__="$2"																# TOKEN
				# Visível em todo shell/subshell
				declare -gr __API_TELEGRAM__=https://api.telegram.org/bot$__TOKEN__		# API
				shift 2
				;;
			--)
				shift
				break
				;;
		esac
	done

	# Parâmetro obrigatório.	
	[ "$__TOKEN__" ] || message_error API "$__ERR_PARAM_REQUIRED__" "[-t, --token]"

	__BOT_INFO__=$(ShellBot.getMe 2>/dev/null)
	
	# Se o token for inválido, imprime mensagem de erro e finaliza o script.
	[ $? -eq 0 ] || message_error API "$__ERR_TOKEN__"
	
	# Define o delimitador entre os campos.
	IFSbkp=$IFS; IFS='|'
	
	# Inicializa um array somente leitura contendo as informações do bot.
	declare -gr __BOT_INFO__=($__BOT_INFO__)
	
	# Restaura o delimitador
	IFS=$IFSbkp

	# Constroi as funções para as chamdas aos atributos do bot.
	ShellBot.token() { echo "${__TOKEN__:-null}"; }
	ShellBot.id() { echo "${__BOT_INFO__[0]:-null}"; }
	ShellBot.username() { echo "${__BOT_INFO__[1]:-null}"; }
	ShellBot.first_name() { echo "${__BOT_INFO__[2]:-null}"; }
	ShellBot.last_name() { echo "${__BOT_INFO__[3]:-null}"; }
	
	# Somente leitura.
	declare -rf ShellBot.token
	declare -rf ShellBot.id
	declare -rf ShellBot.username
	declare -rf ShellBot.first_name
	declare -rf Shellbot.last_name
		
	# status
	return $__ERR__
}

# Um método simples para testar o token de autenticação do seu bot. 
# Não requer parâmetros. Retorna informações básicas sobre o bot em forma de um objeto Usuário.
ShellBot.getMe()
{
	# Variável local
	local __METHOD__=getMe	# Método
	
	# Inicia a função sem erros
	__ERR__=0

	# Chama o método getMe passando o endereço da API, seguido do nome do método.
	eval $__GET__ $__API_TELEGRAM__/$__METHOD__ > $__JSON__
	
	# Verifica o status de retorno do método
	json_status || message_error TG

	# Retorna as informações armazenadas em "result".
	json '.result|.id,.username,.first_name,.last_name' | sed ':a;$!N;s/\n/|/;ta'
	
	# status
	return $__ERR__

}

# Cria objeto que representa um teclado personalizado com opções de resposta
ShellBot.ReplyKeyboardMarkup()
{
	# Variáveis locais
	local __KEYBOARD__ __RESIZE_KEYBOARD__ __ON_TIME_KEYBOARD__ __SELECTIVE__
	
	# Lê os parâmetros da função.
	local __PARAM__=$(getopt --quiet --options 'k:r:t:s:' \
										--longoptions 'keyboard:,
														resize_keyboard:,
														one_time_keyboard:,
														selective:' \
														-- "$@")
	# Iniciliaza a função sem erros.
	__ERR__=0
	
	# Transforma os parâmetros da função em parâmetros posicionais
	#
	# Exemplo:
	#	--param1 arg1 --param2 arg2 --param3 arg3 ...
	# 		$1			  $2			$3
	eval set -- "$__PARAM__"
	
	# Aguarda leitura dos parâmetros
	while :
	do
		# Lê o parâmetro da primeira posição "$1"; Se for um parâmetro válido,
		# salva o valor do argumento na posição '$2' e desloca duas posições a esquerda (shift 2); Repete o processo
		# até que o valor de '$1' seja igual '--' e finaliza o loop.
		case $1 in
			-k|--keyboard)
				__KEYBOARD__="$2"
				shift 2
				;;
			-r|--resize_keyboard)
				# Tipo: boolean
				[[ "$2" =~ ^(true|false)$ ]] || message_error API "$__ERR_TYPE_BOOL__" "$1" "$2"
				__RESIZE_KEYBOARD__="$2"
				shift 2
				;;
			-t|--one_time_keyboard)
				# Tipo: boolean
				[[ "$2" =~ ^(true|false)$ ]] || message_error API "$__ERR_TYPE_BOOL__" "$1" "$2"
				__ON_TIME_KEYBOARD__="$2"
				shift 2
				;;
			-s|--selective)
				# Tipo: boolean
				[[ "$2" =~ ^(true|false)$ ]] || message_error API "$__ERR_TYPE_BOOL__" "$1" "$2"
				__SELECTIVE__="$2"
				shift 2
				;;
			--)
				shift
				break
				;;
		esac
	done
	
	# Imprime mensagem de erro se o parâmetro obrigatório for omitido.
	[ "$__KEYBOARD__" ] || message_error API "$__ERR_PARAM_REQUIRED__" "-k, --keyboard"
	
	# Constroi a estrutura dos objetos + array keyboard, define os valores das configurações e retorna a estrutura.
	# Por padrão todos os valores são 'false', até que seja definido.
	echo {'"keyboard"':$__KEYBOARD__,'"resize_keyboard"': ${__RESIZE_KEYBOARD__:-false}, '"one_time_keyboard"': ${__ON_TIME_KEYBOARD__:-false}, '"selective"': ${__SELECTIVE__:-false}}

	# status
	return $__ERR__
}

# Envia mensagens 
ShellBot.sendMessage()
{
	# Variáveis locais 
	local __CHAT_ID__ __TEXT__ __PARSE_MODE__ __DISABLE_WEB_PAGE_PREVIEW__ __DISABLE_NOTIFICATION__ __REPLY_TO_MESSAGE_ID__ __REPLY_MARKUP__
	local __METHOD__=sendMessage # Método
	
	# Lê os parâmetros da função
	local __PARAM__=$(getopt --quiet --options 'c:t:p:w:n:r:k:' \
										--longoptions 'chat_id:,
														text:,
														parse_mode:,
														disable_web_page_preview:,
														disable_notification:,
														reply_to_message_id:,
														reply_markup:' \
														-- "$@")

	# Sem erros
	__ERR__=0
	
	# Define os parâmetros posicionais
	eval set -- "$__PARAM__"
	
	while :
	do
		case $1 in
			-c|--chat_id)
				__CHAT_ID__="$2"
				shift 2
				;;
			-t|--text)
				__TEXT__="$2"
				shift 2
				;;
			-p|--parse_mode)
				# Tipo: "markdown" ou "html"
				[[ "$2" =~ ^(markdown|html)$ ]] || message_error API "$__ERR_TYPE_PARSE_MODE__" "$1" "$2"
				__PARSE_MODE__="$2"
				shift 2
				;;
			-w|--disable_web_page_preview)
				# Tipo: boolean
				[[ "$2" =~ ^(true|false)$ ]] || message_error API "$__ERR_TYPE_BOOL__" "$1" "$2"
				__DISABLE_WEB_PAGE_PREVIEW__="$2"
				shift 2
				;;
			-n|--disable_notification)
				# Tipo: boolean
				[[ "$2" =~ ^(true|false)$ ]] || message_error API "$__ERR_TYPE_BOOL__" "$1" "$2"
				__DISABLE_NOTIFICATION__="$2"
				shift 2
				;;
			-r|--reply_to_message_id)
				# Tipo: inteiro
				[[ "$2" =~ ^[0-9]+$ ]] || message_error API "$__ERR_TYPE_INT__" "$1" "$2"
				__REPLY_TO_MESSAGE_ID__="$2"
				shift 2
				;;
			-k|--reply_markup)
				__REPLY_MARKUP__="$2"
				shift 2
				;;
			--)
				shift
				break
				;;
		esac
	done

	# Parâmetros obrigatórios.
	[ "$__CHAT_ID__" ] || message_error API "$__ERR_PARAM_REQUIRED__" "[-c, --chat_id]"
	[ "$__TEXT__" ] || message_error API "$__ERR_PARAM_REQUIRED__" "[-t, --text]"

	# Chama o método da API, utilizando o comando request especificado; Os parâmetros 
	# e valores são passados no form e lidos pelo método. O retorno do método é redirecionado para o arquivo 'update.json'.
	# Variáveis com valores nulos são ignoradas e consequentemente os respectivos parâmetros omitidos.
	eval $__POST__ $__API_TELEGRAM__/$__METHOD__ ${__CHAT_ID__:+-d chat_id="'$__CHAT_ID__'"} \
							${__TEXT__:+-d text="'$__TEXT__'"} \
							${__PARSE_MODE__:+-d parse_mode="'$__PARSE_MODE__'"} \
							${__DISABLE_WEB_PAGE_PREVIEW__:+-d disable_web_page_preview="'$__DISABLE_WEB_PAGE_PREVIEW__'"} \
							${__DISABLE_NOTIFICATION__:+-d disable_notification="'$__DISABLE_NOTIFICATION__'"} \
							${__REPLY_TO_MESSAGE_ID__:+-d reply_to_message_id="'$__REPLY_TO_MESSAGE_ID__'"} \
							${__REPLY_MARKUP__:+-d reply_markup="'$__REPLY_MARKUP__'"} > $__JSON__

	# Testa o retorno do método.
	json_status || message_error TG
	
	# Status
	return $__ERR__
}

# Função para reencaminhar mensagens de qualquer tipo.
ShellBot.forwardMessage()
{
	# Variáveis locais
	local __CHAT_ID__ __FORM_CHAT_ID__ __DISABLE_NOTIFICATION__ __MESSAGE_ID__
	local __METHOD__=forwardMessage # Método
	
	# Lê os parâmetros da função
	local __PARAM__=$(getopt --quiet --options 'c:f:n:m:' \
										--longoptions 'chat_id:,
														from_chat_id:,
														disable_notification:,
														message_id:' \
														-- "$@")

	# Sem erros
	__ERR__=0
	
	# Define os parâmetros posicionais
	eval set -- "$__PARAM__"

	while :
	do
		case $1 in
			-c|--chat_id)
				__CHAT_ID__="$2"
				shift 2
				;;
			-f|--from_chat_id)
				__FROM_CHAT_ID__="$2"
				shift 2
				;;
			-n|--disable_notification)
				# Tipo: boolean
				[[ "$2" =~ ^(true|false)$ ]] || message_error API "$__ERR_TYPE_BOOL__" "$1" "$2"
				__DISABLE_NOTIFICATION__="$2"
				shift 2
				;;
			-m|--message_id)
				# Tipo: inteiro
				[[ "$2" =~ ^[0-9]+$ ]] || message_error API "$__ERR_TYPE_INT__" "$1" "$2"
				__MESSAGE_ID__="$2"
				shift 2
				;;
			--)
				shift
				break
				;;
		esac
	done
	
	# Parâmetros obrigatórios.
	[ "$__CHAT_ID__" ] || message_error API "$__ERR_PARAM_REQUIRED__" "[-c, --chat_id]"
	[ "$__FROM_CHAT_ID__" ] || message_error API "$__ERR_PARAM_REQUIRED__" "[-f, --from_chat_id]"
	[ "$__MESSAGE_ID__" ] || message_error API "$__ERR_PARAM_REQUIRED__" "[-m, --message_id]"

	# Chama o método
	eval $__POST__ $__API_TELEGRAM__/$__METHOD__ ${__CHAT_ID__:+-d chat_id="'$__CHAT_ID__'"} \
							${__FROM_CHAT_ID__:+-d from_chat_id="'$__FROM_CHAT_ID__'"} \
							${__DISABLE_NOTIFICATION__:+-d disable_notification="'$__DISABLE_NOTIFICATION__'"} \
							${__MESSAGE_ID__:+-d message_id="'$__MESSAGE_ID__'"} > $__JSON__
	
	# Retorno do método
	json_status || message_error TG

	# status
	return $__ERR__
}

# Utilize essa função para enviar fotos.
ShellBot.sendPhoto()
{
	# Variáveis locais
	local __CHAT_ID__ __PHOTO__ __CAPTION__ __DISABLE_NOTIFICATION__ __REPLY_TO_MESSAGE_ID__ __REPLY_MARKUP__
	local __METHOD__=sendPhoto	# Método

	# Lê os parâmetros da função
	local __PARAM__=$(getopt --quiet --options 'c:p:t:n:r:k:' \
										--longoptions 'chat_id:, 
														photo:,
														caption:,
														disable_notification:,
														reply_to_message_id:,
														reply_markup:' \
														-- "$@")


	# Sem erros
	__ERR__=0
	
	# Define os parâmetros posicionais
	eval set -- "$__PARAM__"

	while :
	do
		case $1 in
			-c|--chat_id)
				__CHAT_ID__="$2"
				shift 2
				;;
			-p|--photo)
				__PHOTO__="$2"
				shift 2
				;;
			-t|--caption)
				# Limite máximo de caracteres: 200
				[ $(str_len "$2") -gt 200 ] && message_error API "$__ERR_CAPTION_MAX_CHAR__" "$1" 
				__CAPTION__="$2"
				shift 2
				;;
			-n|--disable_notification)
				# Tipo: boolean
				[[ "$2" =~ ^(true|false)$ ]] || message_error API "$__ERR_TYPE_BOOL__" "$1" "$2"
				__DISABLE_NOTIFICATION__="$2"
				shift 2
				;;
			-r|--reply_to_message_id)
				# Tipo: inteiro
				[[ "$2" =~ ^[0-9]+$ ]] || message_error API "$__ERR_TYPE_INT__" "$1" "$2"
				__REPLY_TO_MESSAGE_ID__="$2"
				shift 2
				;;
			-k|--reply_markup)
				__REPLY_MARKUP__="$2"
				shift 2
				;;
			--)
				shift
				break
				;;
		esac
	done
	
	# Parâmetros obrigatórios
	[ "$__CHAT_ID__" ] || message_error API "$__ERR_PARAM_REQUIRED__" "[-c, --chat_id]"
	[ "$__PHOTO__" ] || message_error API "$__ERR_PARAM_REQUIRED__" "[-p, --photo]"
	
	# Chama o método
	eval $__POST__ $__API_TELEGRAM__/$__METHOD__ ${__CHAT_ID__:+-F chat_id="'$__CHAT_ID__'"} \
							${__PHOTO__:+-F photo="'$__PHOTO__'"} \
							${__CAPTION__:+-F caption="'$__CAPTION__'"} \
							${__DISABLE_NOTIFICATION__:+-F disable_notification="'$__DISABLE_NOTIFICATION__'"} \
							${__REPLY_TO_MESSAGE_ID__:+-F reply_to_message_id="'$__REPLY_TO_MESSAGE_ID__'"} \
							${__REPLY_MARKUP__:+-F reply_markup="'$__REPLY_MARKUP__'"} > $__JSON__
	
	# Retorno do método
	json_status || message_error TG

	# Status
	return $__ERR__
}

# Utilize essa função para enviar arquivos de audio.
ShellBot.sendAudio()
{
	# Variáveis locais
	local __CHAT_ID__ __AUDIO__ __CAPTION__ __DURATION__ __PERFORMER__ __TITLE__ __DISABLE_NOTIFICATION__ __REPLY_TO_MESSAGE_ID__ __REPLY_MARKUP__	
	local __METHOD__=sendAudio	# Método
	
	# Lê os parâmetros da função
	local __PARAM__=$(getopt --quiet --options 'c:a:t:d:e:i:n:r:k' \
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

	# Sem erros
	__ERR__=0
	
	# Define os parâmetros posicionais
	eval set -- "$__PARAM__"

	while :
	do
		case $1 in
			-c|--chat_id)
				__CHAT_ID__="$2"
				shift 2
				;;
			-a|--audio)
				__AUDIO__="$2"
				shift 2
				;;
			-t|--caption)
				__CAPTION__="$2"
				shift 2
				;;
			-d|--duration)
				# Tipo: inteiro
				[[ "$2" =~ ^[0-9]+$ ]] || message_error API "$__ERR_TYPE_INT__" "$1" "$2"
				__DURATION__="$2"
				shift 2
				;;
			-e|--performer)
				__PERFORMER__="$2"
				shift 2
				;;
			-i|--title)
				__TITLE__="$2"
				shift 2
				;;
			-n|--disable_notification)
				# Tipo: boolean
				[[ "$2" =~ ^(true|false)$ ]] || message_error API "$__ERR_TYPE_BOOL__" "$1" "$2"
				__DISABLE_NOTIFICATION__="$2"
				shift 2
				;;
			-r|--reply_to_message_id)
				# Tipo: inteiro
				[[ "$2" =~ ^[0-9]+$ ]] || message_error API "$__ERR_TYPE_INT__" "$1" "$2"
				__REPLY_TO_MESSAGE_ID__="$2"
				shift 2
				;;
			-k|--reply_markup)
				__REPLY_MARKUP__="$2"
				shift 2
				;;
			--)
				shift
				break
				;;
		esac
	done
	
	# Parâmetros obrigatórios
	[ "$__CHAT_ID__" ] || message_error API "$__ERR_PARAM_REQUIRED__" "[-c, --chat_id]"
	[ "$__AUDIO__" ] || message_error API "$__ERR_PARAM_REQUIRED__" "[-a, --audio]"
	
	# Chama o método
	eval $__POST__ $__API_TELEGRAM__/$__METHOD__ ${__CHAT_ID__:+-F chat_id="'$__CHAT_ID__'"} \
							${__AUDIO__:+-F audio="'$__AUDIO__'"} \
							${__CAPTION__:+-F caption="'$__CAPTION__'"} \
							${__DURATION__:+-F duration="'$__DURATION__'"} \
							${__PERFORMER__:+-F performer="'$__PERFORMER__'"} \
							${__TITLE__:+-F title="'$__TITLE__'"} \
							${__DISABLE_NOTIFICATION__:+-F disable_notification="'$__DISABLE_NOTIFICATION__'"} \
							${__REPLY_TO_MESSAGE_ID__:+-F reply_to_message_id="'$__REPLY_TO_MESSAGE_ID__'"} \
							${__REPLY_MARKUP__:+-F reply_markup="'$__REPLY_MARKUP__'"} > $__JSON__

	# Retorno do método
	json_status || message_error TG

	# Status
	return $__ERR__
		
}

# Utilize essa função para enviar documentos.
ShellBot.sendDocument()
{
	# Variáveis locais
	local __CHAT_ID__ __DOCUMENT__ __CAPTION__ __DISABLE_NOTIFICATION__ __REPLY_TO_MESSAGE_ID__ __REPLY_MARKUP__
	local __METHOD__=sendDocument	# Método
	
	# Lê os parâmetros da função
	local __PARAM__=$(getopt --quiet --options 'c:d:t:n:r:k:' \
										--longoptions 'chat_id:,
														document:,
														caption:,
														disable_notification:,
														reply_to_message_id:,
														reply_markup:' \
														-- "$@")

	# Sem erros
	__ERR__=0
	
	# Define os parâmetros posicionais
	eval set -- "$__PARAM__"

	while :
	do
		case $1 in
			-c|--chat_id)
				__CHAT_ID__="$2"
				shift 2
				;;
			-d|--document)
				__DOCUMENT__="$2"
				shift 2
				;;
			-t|--caption)
				__CAPTION__="$2"
				shift 2
				;;
			-n|--disable_notification)
				[[ "$2" =~ ^(true|false)$ ]] || message_error API "$__ERR_TYPE_BOOL__" "$1" "$2"
				__DISABLE_NOTIFICATION__="$2"
				shift 2
				;;
			-r|--reply_to_message_id)
				[[ "$2" =~ ^[0-9]+$ ]] || message_error API "$__ERR_TYPE_INT__" "$1" "$2"
				__REPLY_TO_MESSAGE_ID__="$2"
				shift 2
				;;
			-k|--reply_markup)
				__REPLY_MARKUP="$2"
				shift 2
				;;
			--)
				shift
				break
				;;
		esac
	done
	
	# Parâmetros obrigatórios
	[ "$__CHAT_ID__" ] || message_error API "$__ERR_PARAM_REQUIRED__" "[-c, --chat_id]"
	[ "$__DOCUMENT__" ] || message_error API "$__ERR_PARAM_REQUIRED__" "[-d, --document]"
	
	# Chama o método
	eval $__POST__ $__API_TELEGRAM__/$__METHOD__ ${__CHAT_ID__:+-F chat_id="'$__CHAT_ID__'"} \
							${__DOCUMENT__:+-F document="'$__DOCUMENT__'"} \
							${__CAPTION__:+-F caption="'$__CAPTION__'"} \
							${__DISABLE_NOTIFICATION__:+-F disable_notification="'$__DISABLE_NOTIFICATION__'"} \
							${__REPLY_TO_MESSAGE_ID__:+-F reply_to_message_id="'$__REPLY_TO_MESSAGE_ID__'"} \
							${__REPLY_MARKUP__:+-F reply_markup="'$__REPLY_MARKUP__'"} > $__JSON__

	# Retorno do método
	json_status || message_error TG

	# Status
	return $__ERR__
	
}

# Utilize essa função para enviat stickers
ShellBot.sendSticker()
{
	# Variáveis locais
	local __CHAT_ID__ __STICKER__ __DISABLE_NOTIFICATION__ __REPLY_TO_MESSAGE_ID__ __REPLY_MARKUP__
	local __METHOD__=sendSticker	# Método

	# Lê os parâmetros da função
	local __PARAM__=$(getopt --quiet --options 'c:s:n:r:k:' \
										--longoptions 'chat_id:,
														sticker:,
														disable_notification:,
														reply_to_message_id:,
														reply_markup:' \
														-- "$@")

	# Sem erros
	__ERR__=0
	
	# Define os parâmetros posicionais
	eval set -- "$__PARAM__"

	while :
	do
		case $1 in
			-c|--chat_id)
				__CHAT_ID__="$2"
				shift 2
				;;
			-s|--sticker)
				__STICKER__="$2"
				shift 2
				;;
			-n|--disable_notification)
				# Tipo: boolean
				[[ "$2" =~ ^(true|false)$ ]] || message_error API "$__ERR_TYPE_BOOL__" "$1" "$2"
				__DISABLE_NOTIFICATION__="$2"
				shift 2
				;;
			-r|--reply_to_message_id)
				# Tipo: inteiro
				[[ "$2" =~ ^[0-9]+$ ]] || message_error API "$__ERR_TYPE_INT__" "$1" "$2"
				__REPLY_TO_MESSAGE_ID__="$2"
				shift 2
				;;
			-k|--reply_markup)
				__REPLY_MARKUP__="$2"
				shift 2
				;;
			--)
				shift
				break
				;;
		esac
	done
	
	# Parâmetros obrigatórios
	[ "$__CHAT_ID__" ] || message_error API "$__ERR_PARAM_REQUIRED__" "[-c, --chat_id]"
	[ "$__STICKER__" ] || message_error API "$__ERR_PARAM_REQUIRED__" "[-s, --sticker]"

	# Chama o método
	eval $__POST__ $__API_TELEGRAM__/$__METHOD__ ${__CHAT_ID__:+-F chat_id="'$__CHAT_ID__'"} \
							${__STICKER__:+-F sticker="'$__STICKER__'"} \
							${__DISABLE_NOTIFICATION__:+-F disable_notification="'$__DISABLE_NOTIFICATION__'"} \
							${__REPLY_TO_MESSAGE_ID__:+-F reply_to_message_id="'$__REPLY_TO_MESSAGE_ID__'"} \
							${__REPLY_MARKUP__:+-F reply_markup="'$__REPLY_MARKUP__'"} > $__JSON__

	# Testa o retorno do método
	json_status || message_error TG

	# Status
	return $__ERR__
}

# Função para enviar arquivos de vídeo.
ShellBot.sendVideo()
{
	# Variáveis locais
	local __CHAT_ID__ __VIDEO__ __DURATION__ __WIDTH__ __HEIGHT__ __CAPTION__ __DISABLE_NOTIFICATION__ __REPLY_TO_MESSAGE_ID__ __REPLY_MARKUP__
	local __METHOD__=sendVideo	# Método

	# Lê os parâmetros da função
	local __PARAM__=$(getopt --quiet --options 'c:v:d:w:h:t:n:r:k:' \
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

	# Sem erros
	__ERR__=0
	
	# Define os parâmetros posicionais
	eval set -- "$__PARAM__"

	while :
	do
		case $1 in
			-c|--chat_id)
				__CHAT_ID__="$2"
				shift 2
				;;
			-v|--video)
				__VIDEO__="$2"
				shift 2
				;;
			-d|--duration)
				# Tipo: inteiro
				[[ "$2" =~ ^[0-9]+$ ]] || message_error API "$__ERR_TYPE_INT__" "$1" "$2"
				__DURATION_="$2"
				shift 2
				;;
			-w|--width)
				# Tipo: inteiro
				[[ "$2" =~ ^[0-9]+$ ]] || message_error API "$__ERR_TYPE_INT__" "$1" "$2"
				__WIDTH__="$2"
				shift 2
				;;
			-h|--height)
				# Tipo: inteiro
				[[ "$2" =~ ^[0-9]+$ ]] || message_error API "$__ERR_TYPE_INT__" "$1" "$2"
				__HEIGHT__="$2"
				shift 2
				;;
			-t|--caption)
				__CAPTION__="$2"
				shift 2
				;;
			-n|--disable_notification)
				# Tipo: boolean
				[[ "$2" =~ ^(true|false)$ ]] || message_error API "$__ERR_TYPE_BOOL__" "$1" "$2"
				__DISABLE_NOTIFICATION__="$2"
				shift 2
				;;
			-r|--reply_to_message_id)
				[[ "$2" =~ ^[0-9]+$ ]] || message_error API "$__ERR_TYPE_INT__" "$1" "$2"
				__REPLY_TO_MESSAGE_ID__="$2"
				shift 2
				;;
			-k|--reply_markup)
				__REPLY_MARKUP__="$2"
				shift 2
				;;
			--)
				shift
				break
				;;
		esac
	done
	
	# Parâmetros obrigatórios.
	[ "$__CHAT_ID__" ] || message_error API "$__ERR_PARAM_REQUIRED__" "[-c, --chat_id]"
	[ "$__VIDEO__" ] || message_error API "$__ERR_PARAM_REQUIRED__" "[-v, --video]"

	# Chama o método
	eval $__POST__ $__API_TELEGRAM__/$__METHOD__ ${__CHAT_ID__:+-F chat_id="'$__CHAT_ID__'"} \
							${__VIDEO__:+-F video="'$__VIDEO__'"} \
							${__DURATION__:+-F duration="'$__DURATION__'"} \
							${__WIDTH__:+-F width="'$__WIDTH__'"} \
							${__HEIGHT__:+-F height="'$__HEIGHT__'"} \
							${__CAPTION__:+-F caption="'$__CAPTION__'"} \
							${__DISABLE_NOTIFICATION__:+-F disable_notification="'$__DISABLE_NOTIFICATION__'"} \
							${__REPLY_TO_MESSAGE_ID__:+-F reply_to_message_id="'$__REPLY_TO_MESSAGE_ID__'"} \
							${__REPLY_MARKUP__:+-F reply_markup="'$__REPLY_MARKUP__'"} > $__JSON__

	# Testa o retorno do método
	json_status || message_error TG

	# Status
	return $__ERR__
	
}

# Função para enviar audio.
ShellBot.sendVoice()
{
	# Variáveis locais
	local __CHAT_ID__ __VOICE__ __CAPTION__ __DURATION__ __DISABLE_NOTIFICATION__ __REPLY_TO_MESSAGE_ID__ __REPLY_MARKUP__
	local __METHOD__=sendVoice	# Método

	# Lê os parâmetros da função
	local __PARAM__=$(getopt --quiet --options 'c:v:t:d:n:r:k:' \
										--longoptions 'chat_id:,
														voice:,
														caption:,
														duration:,
														disable_notification:,
														reply_to_message_id:,
														reply_markup:' \
														-- "$@")

	# Sem erros
	__ERR__=0
	
	# Define os parâmetros posicionais
	eval set -- "$__PARAM__"

	while :
	do
		case $1 in
			-c|--chat_id)
				__CHAT_ID__="$2"
				shift 2
				;;
			-v|--voice)
				__VOICE__="$2"
				shift 2
				;;
			-t|--caption)
				__CAPTION__="$2"
				shift 2
				;;
			-d|--duration)
				# Tipo: inteiro
				[[ "$2" =~ ^[0-9]+$ ]] || message_error API "$__ERR_TYPE_INT__" "$1" "$2"
				__DURATION__="$2"
				shift 2
				;;
			-n|--disable_notification)
				# Tipo: boolean
				[[ "$2" =~ ^(true|false)$ ]] || message_error API "$__ERR_TYPE_BOOL__" "$1" "$2"
				__DISABLE_NOTIFICATION__="$2"
				shift 2
				;;
			-r|--reply_to_message_id)
				# Tipo: inteiro
				[[ "$2" =~ ^[0-9]+$ ]] || message_error API "$__ERR_TYPE_INT__" "$1" "$2"
				__REPLY_TO_MESSAGE_ID__="$2"
				shift 2
				;;
			-k|--reply_markup)
				__REPLY_MARKUP__="$2"
				shift 2
				;;
			--)
				shift
				break
		esac
	done
	
	# Parâmetros obrigatórios.
	[ "$__CHAT_ID__" ] || message_error API "$__ERR_PARAM_REQUIRED__" "[-c, --chat_id]"
	[ "$__VOICE__" ] || message_error API "$__ERR_PARAM_REQUIRED__" "[-v, --voice]"
	
	# Chama o método
	eval $__POST__ $__API_TELEGRAM__/$__METHOD__ ${__CHAT_ID__:+-F chat_id="'$__CHAT_ID__'"} \
							${__VOICE__:+-F voice="'$__VOICE__'"} \
							${__CAPTION__:+-F caption="'$__CAPTION__'"} \
							${__DURATION__:+-F duration="'$__DURATION__'"} \
							${__DISABLE_NOTIFICATION__:+-F disable_notification="'$__DISABLE_NOTIFICATION__'"} \
							${__REPLY_TO_MESSAGE_ID__:+-F reply_to_message_id="'$__REPLY_TO_MESSAGE_ID__'"} \
							${__REPLY_MARKUP__:+-F reply_markup="'$__REPLY_MARKUP__'"} > $__JSON__

	# Testa o retorno do método
	json_status || message_error TG

	# Status
	return $__ERR__
	
}

# Função utilizada para enviar uma localidade utilizando coordenadas de latitude e longitude.
ShellBot.sendLocation()
{
	# Variáveis locais
	local __CHAT_ID__ __LATITUDE__ __LONGITUDE__ __DISABLE_NOTIFICATION__ __REPLY_TO_MESSAGE_ID__ __REPLY_MARKUP__
	local __METHOD__=sendLocation	# Método

	# Lê os parâmetros da função
	local __PARAM__=$(getopt --quiet --options 'c:l:g:n:r:k:' \
										--longoptions 'chat_id:,
														latitude:,
														longitude:,
														disable_notification:,
														reply_to_message_id:,
														reply_markup:' \
														-- "$@")

	# Sem erros
	__ERR__=0
	
	# Define os parâmetros posicionais
	eval set -- "$__PARAM__"
	
	while :
	do
		case $1 in
			-c|--chat_id)
				__CHAT_ID__="$2"
				shift 2
				;;
			-l|--latitude)
				# Tipo: float
				[[ "$2" =~ ^-?[0-9]+\.[0-9]+$ ]] || message_error API "$__ERR_TYPE_FLOAT__" "$1" "$2"
				__LATITUDE__="$2"
				shift 2
				;;
			-g|--longitude)
				# Tipo: float
				[[ "$2" =~ ^-?[0-9]+\.[0-9]+$ ]] || message_error API "$__ERR_TYPE_FLOAT__" "$1" "$2"
				__LONGITUDE__="$2"
				shift 2
				;;
			-n|--disable_notification)
				# Tipo: boolean
				[[ "$2" =~ ^(true|false)$ ]] || message_error API "$__ERR_TYPE_BOOL__" "$1" "$2"
				__DISABLE_NOTIFICATION__="$2"
				shift 2
				;;
			-r|--reply_to_message_id)
				# Tipo: inteiro
				[[ "$2" =~ ^[0-9]+$ ]] || message_error API "$__ERR_TYPE_INT__" "$1" "$2"
				__REPLY_TO_MESSAGE_ID__="$2"
				shift 2
				;;
			-k|--reply_markup)
				__REPLY_MARKUP__="$2"
				shift 2
				;;
			--)
				shift
				break
		esac
	done
	
	# Parâmetros obrigatórios
	[ "$__CHAT_ID__" ] || message_error API "$__ERR_PARAM_REQUIRED__" "[-c, --chat_id]"
	[ "$__LATITUDE__" ] || message_error API "$__ERR_PARAM_REQUIRED__" "[-l, --latitude]"
	[ "$__LONGITUDE__" ] || message_error API "$__ERR_PARAM_REQUIRED__" "[-g, --longitude]"
			
	# Chama o método
	eval $__POST__ $__API_TELEGRAM__/$__METHOD__ ${__CHAT_ID__:+-F chat_id="'$__CHAT_ID__'"} \
							${__LATITUDE__:+-F latitude="'$__LATITUDE__'"} \
							${__LONGITUDE__:+-F longitude="'$__LONGITUDE__'"} \
							${__DISABLE_NOTIFICATION__:+-F disable_notification="'$__DISABLE_NOTIFICATION__'"} \
							${__REPLY_TO_MESSAGE_ID__:+-F reply_to_message_id="'$__REPLY_TO_MESSAGE_ID__'"} \
							${__REPLY_MARKUP__:+-F reply_markup="'$__REPLY_MARKUP__'"} > $__JSON__

	# Testa o retorno do método
	json_status || message_error TG

	return $__ERR__
	
}

# Função utlizada para enviar detalhes de um local.
ShellBot.sendVenue()
{
	# Variáveis locais
	local __CHAT_ID__ __LATITUDE__ __LONGITUDE__ __TITLE__ __ADDRESS__ __FOURSQUARE_ID__ __DISABLE_NOTIFICATION__ __REPLY_TO_MESSAGE_ID__ __REPLY_MARKUP__
	local __METHOD__=sendVenue	# Método
	
	# Lê os parâmetros da função
	local __PARAM__=$(getopt --quiet --options 'c:l:g:i:a:f:n:r:k:' \
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

	# Sem erros
	__ERR__=0
	
	# Define os parâmetros posicionais
	eval set -- "$__PARAM__"
	
	while :
	do
		case $1 in
			-c|--chat_id)
				__CHAT_ID__="$2"
				shift 2
				;;
			-l|--latitude)
				# Tipo: float
				[[ "$2" =~ ^-?[0-9]+\.[0-9]+$ ]] || message_error API "$__ERR_TYPE_FLOAT__" "$1" "$2"
				__LATITUDE__="$2"
				shift 2
				;;
			-g|--longitude)
				# Tipo: float
				[[ "$2" =~ ^-?[0-9]+\.[0-9]+$ ]] || message_error API "$__ERR_TYPE_FLOAT__" "$1" "$2"
				__LONGITUDE__="$2"
				shift 2
				;;
			-i|--title)
				__TITLE__="$2"
				shift 2
				;;
			-a|--address)
				__ADDRESS__="$2"
				shift 2
				;;
			-f|--foursquare_id)
				__FOURSQUARE_ID__="$2"
				shift 2
				;;
			-n|--disable_notification)
				# Tipo: boolean
				[[ "$2" =~ ^(true|false)$ ]] || message_error API "$__ERR_TYPE_BOOL__" "$1" "$2"
				__DISABLE_NOTIFICATION__="$2"
				shift 2
				;;
			-r|--reply_to_message_id)
				# Tipo: inteiro
				[[ "$2" =~ ^[0-9]+$ ]] || message_error API "$__ERR_TYPE_INT__" "$1" "$2"
				__REPLY_TO_MESSAGE_ID__="$2"
				shift 2
				;;
			-k|--reply_markup)
				__REPLY_MARKUP__="$2"
				shift 2
				;;
			--)
				shift
				break
		esac
	done
			
	# Parâmetros obrigatórios.
	[ "$__CHAT_ID__" ] || message_error API "$__ERR_PARAM_REQUIRED__" "[-c, --chat_id]"
	[ "$__LATITUDE__" ] || message_error API "$__ERR_PARAM_REQUIRED__" "[-l, --latitude]"
	[ "$__LONGITUDE__" ] || message_error API "$__ERR_PARAM_REQUIRED__" "[-g, --longitude]"
	[ "$__TITLE__" ] || message_error API "$__ERR_PARAM_REQUIRED__" "[-i, --title]"
	[ "$__ADDRESS__" ] || message_error API "$__ERR_PARAM_REQUIRED__" "[-a, --address]"
	
	# Chama o método
	eval $__POST__ $__API_TELEGRAM__/$__METHOD__ ${__CHAT_ID__:+-F chat_id="'$__CHAT_ID__'"} \
							${__LATITUDE__:+-F latitude="'$__LATITUDE__'"} \
							${__LONGITUDE__:+-F longitude="'$__LONGITUDE__'"} \
							${__TITLE__:+-F title="'$__TITLE__'"} \
							${__ADDRESS__:+-F address="'$__ADDRESS__'"} \
							${__FOURSQUARE_ID__:+-F foursquare_id="'$__FOURSQUARE_ID__'"} \
							${__DISABLE_NOTIFICATION__:+-F disable_notification="'$__DISABLE_NOTIFICATION__'"} \
							${__REPLY_TO_MESSAGE_ID__:+-F reply_to_message_id="'$__REPLY_TO_MESSAGE_ID__'"} \
							${__REPLY_MARKUP__:+-F reply_markup="'$__REPLY_MARKUP__'"} > $__JSON__

	# Testa o retorno do método
	json_status || message_error TG

	# Status
	return $__ERR__
}

# Utilize essa função para enviar um contato + numero
ShellBot.sendContact()
{
	# Variáveis locais
	local __CHAT_ID__ __PHONE_NUMBER__ __FIRST_NAME__ __LAST_NAME__ __DISABLE_NOTIFICATION__ __REPLY_TO_MESSAGE_ID__ __REPLY_MARKUP__
	local __METHOD__=sendContact	# Método
	
	# Lê os parâmetros da função
	local __PARAM__=$(getopt --quiet --options 'c:p:f:l:n:r:k:' \
										--longoptions 'chat_id:,
														phone_number:,
														first_name:,
														last_name:,
														disable_notification:,
														reply_to_message_id:,
														reply_markup:' \
														-- "$@")


	# Sem erros
	__ERR__=0
	
	# Define os parâmetros posicionais
	eval set -- "$__PARAM__"

	while :
	do
		case $1 in
			-c|--chat_id)
				__CHAT_ID__="$2"
				shift 2
				;;
			-p|--phone_number)
				__PHONE_NUMBER__="$2"
				shift 2
				;;
			-f|--first_name)
				__FIRST_NAME__="$2"
				shift 2
				;;
			-l|--last_name)
				__LAST_NAME__="$2"
				shift 2
				;;
			-n|--disable_notification)
				# Tipo: boolean
				[[ "$2" =~ ^(true|false)$ ]] || message_error API "$__ERR_TYPE_BOOL__" "$1" "$2"
				__DISABLE_NOTIFICATION__="$2"
				shift 2
				;;
			-r|--reply_to_message_id)
				# Tipo: inteiro
				[[ "$2" =~ ^[0-9]+$ ]] || message_error API "$__ERR_TYPE_INT__" "$1" "$2"
				__REPLY_TO_MESSAGE_ID__="$2"
				shift 2
				;;
			-k|--reply_markup)
				__REPLY_MARKUP__="$2"
				shift 2
				;;
			--)
				shift
				break
		esac
	done
	
	# Parâmetros obrigatórios.	
	[ "$__CHAT_ID__" ] || message_error API "$__ERR_PARAM_REQUIRED__" "[-c, --chat_id]"
	[ "$__PHONE_NUMBER__" ] || message_error API "$__ERR_PARAM_REQUIRED__" "[-p, --phone_number]"
	[ "$__FIRST_NAME__" ] || message_error API "$__ERR_PARAM_REQUIRED__" "[-f, --first_name]"
	
	# Chama o método
	eval $__POST__ $__API_TELEGRAM__/$__METHOD__ ${__CHAT_ID__:+-F chat_id="'$__CHAT_ID__'"} \
							${__PHONE_NUMBER__:+-F phone_number="'$__PHONE_NUMBER__'"} \
							${__FIRST_NAME__:+-F first_name="'$__FIRST_NAME__'"} \
							${__LAST_NAME__:+-F last_name="'$__LAST_NAME__'"} \
							${__DISABLE_NOTIFICATION__:+-F disable_notification="'$__DISABLE_NOTIFICATION__'"} \
							${__REPLY_TO_MESSAGE_ID__:+-F reply_to_message_id="'$__REPLY_TO_MESSAGE_ID__'"} \
							${__REPLY_MARKUP__:+-F reply_markup="'$__REPLY_MARKUP__'"} > $__JSON__

	# Testa o retorno do método
	json_status || message_error TG

	# Status
	return $__ERR__
}

# Envia uma ação para bot.
ShellBot.sendChatAction()
{
	# Variáveis locais
	local __CHAT_ID__ __ACTION__
	local __METHOD__=sendChatAction		# Método
	
	# Lê os parâmetros da função
	local __PARAM__=$(getopt --quiet --options 'c:a:' \
										--longoptions 'chat_id:,
														action:' \
														-- "$@")

	# Sem erros
	__ERR__=0

	# Define os parâmetros posicionais
	eval set -- "$__PARAM__"

	while :
	do
		case $1 in
			-c|--chat_id)
				__CHAT_ID__="$2"
				shift 2
				;;
			-a|--action)
				[[ "$2" =~ ^(typing|upload_photo|record_video|upload_video|record_audio|upload_audio|upload_document|find_location)$ ]] || message_error API "$__ERR_ACTION_MODE__" "$1" "$2"
				__ACTION__="$2"
				shift 2
				;;
			--)
				shift
				break
		esac
	done

	# Parâmetros obrigatórios.		
	[ "$__CHAT_ID__" ] || message_error API "$__ERR_PARAM_REQUIRED__" "[-c, --chat_id]"
	[ "$__ACTION__" ] || message_error API "$__ERR_PARAM_REQUIRED__" "[-a, --action]"
	
	# Chama o método
	eval $__POST__ $__API_TELEGRAM__/$__METHOD__ ${__CHAT_ID__:+-d chat_id="'$__CHAT_ID__'"} \
													${__ACTION__:+-d action="'$__ACTION__'"} > $__JSON__
	
	# Testa o retorno do método
	json_status || message_error TG

	# Status
	return $__ERR__
}

# Utilize essa função para obter as fotos de um determinado usuário.
ShellBot.getUserProfilePhotos()
{
	# Variáveis locais 
	local __USER_ID__ __OFFSET__ __LIMIT__ __IND__ __TOTAL__ __LAST__ __INDEX__ __MAX__ __ITEM__
	local __METHOD__=getUserProfilePhotos # Método
	
	# Lê os parâmetros da função
	local __PARAM__=$(getopt --quiet --options 'u:o:l:' \
										--longoptions 'user_id:,
														offset:,
														limit:' \
														-- "$@")

	# Sem erros
	__ERR__=0

	# Define os parâmetros posicionais
	eval set -- "$__PARAM__"
	
	while :
	do
		case $1 in
			-u|--user_id)
				[[ "$2" =~ ^[0-9]+$ ]] || message_error API "$__ERR_TYPE_INT__" "$1" "$2"
				__USER_ID__="$2"
				shift 2
				;;
			-o|--offset)
				[[ "$2" =~ ^[0-9]+$ ]] || message_error API "$__ERR_TYPE_INT__" "$1" "$2"
				__OFFSET__="$2"
				shift 2
				;;
			-l|--limit)
				[[ "$2" =~ ^[0-9]+$ ]] || message_error API "$__ERR_TYPE_INT__" "$1" "$2"
				__LIMIT__="$2"
				shift 2
				;;
			--)
				shift
				break
				;;
		esac
	done
	
	# Parâmetros obrigatórios.
	[ "$__USER_ID__" ] || message_error API "$__ERR_PARAM_REQUIRED__" "[-u, --user_id]"
	
	# Chama o método
	eval $__GET__ $__API_TELEGRAM__/$__METHOD__ ${__USER_ID__:+-d user_id="'$__USER_ID__'"} \
													${__OFFSET__:+-d offset="'$__OFFSET__'"} \
													${__LIMIT__:+-d limit="'$__LIMIT__'"} > $__JSON__

	# Verifica se ocorreu erros durante a chamada do método	
	json_status || message_error TG


	__TOTAL__=$(json '.result.total_count')

	if [ $__TOTAL__ -gt 0 ]; then	
		for __INDEX__ in $(seq 0 $((__TOTAL__-1)))
		do
			__MAX__=$(json ".result.photos[$__INDEX__]|length")
			for __ITEM__ in $(seq 0 $((__MAX__-1)))
			do
				json ".result.photos[$__INDEX__][$__ITEM__]|.file_id, .file_size, .width, .height" | sed ':a;$!N;s/\n/|/;ta'
			done
		done
	else
		echo null
	fi

	# Status
	return $__ERR__
}

# Função para listar informações do arquivo especificado.
ShellBot.getFile()
{
	# Variáveis locais
	local __FILE_ID__
	local __METHOD__=getFile # Método

	# Lê os parâmetros da função
	local __PARAM__=$(getopt --quiet --options 'f:' \
										--longoptions 'file_id:' \
														-- "$@")

	# Sem erros
	__ERR__=0

	# Define os parâmetros posicionais
	eval set -- "$__PARAM__"

	while :
	do
		case $1 in
			-f|--file_id)
				__FILE_ID__="$2"
				shift 2
				;;
			--)
				shift
				break
				;;
		esac
	done
	
	# Parâmetros obrigatórios.
	[ "$__FILE_ID__" ] || message_error API "$__ERR_PARAM_REQUIRED__" "[-f, --file_id]"
	
	# Chama o método.
	eval $__GET__ $__API_TELEGRAM__/$__METHOD__ ${__FILE_ID__:+-d file_id="'$__FILE_ID__'"} > $__JSON__

	# Testa o retorno do método.
	json_status || message_error TG

	# Extrai as informações, agrupando-as em uma única linha e insere o delimitador '|' PIPE entre os campos.
	json '.result|.file_id, .file_size, .file_path' | sed ':a;$!N;s/\n/|/;ta'

	# Status
	return $__ERR__
}		

# Essa função kicka o usuário do chat ou canal. (somente administradores)
ShellBot.kickChatMember()
{
	# Variáveis locais
	local __CHAT_ID__ __USER_ID__
	local __METHOD__=kickChatMember		# Método

	# Lê os parâmetros da função
	local __PARAM__=$(getopt --quiet --options 'c:u:' \
										--longoptions 'chat_id:,
														user_id:' \
														-- "$@")

	# Sem erros
	__ERR__=0

	# Define os parâmetros posicionais
	eval set -- "$__PARAM__"

	# Trata os parâmetros
	while :
	do
		case $1 in
			-c|--chat_id)
				__CHAT_ID__="$2"
				shift 2
				;;
			-u|--user_id)
				[[ "$2" =~ ^[0-9]+$ ]] || message_error API "$__ERR_TYPE_INT__" "$1" "$2"
				__USER_ID__="$2"
				shift 2
				;;
			--)
				shift
				break
				;;
		esac
	done
	
	# Parametros obrigatórios.
	[ "$__CHAT_ID__" ] || message_error API "$__ERR_PARAM_REQUIRED__" "[-c, --chat_id]"
	[ "$__USER_ID__" ] || message_error API "$__ERR_PARAM_REQUIRED__" "[-u, --user_id]"
	
	# Chama o método
	eval $__POST__ $__API_TELEGRAM__/$__METHOD__ ${__CHAT_ID__:+-d chat_id="'$__CHAT_ID__'"} \
												${__USER_ID__:+-d user_id="'$__USER_ID__'"} > $__JSON__

	# Verifica se ocorreu erros durante a chamada do método	
	json_status || message_error TG

	# Status
	return $__ERR__
}

# Utilize essa função para remove o bot do grupo ou canal.
ShellBot.leaveChat()
{
	# Variáveis locais
	local __CHAT_ID__
	local __METHOD__=leaveChat	# Método

	# Lê os parâmetros da função
	local __PARAM__=$(getopt --quiet --options 'c:' \
										--longoptions 'chat_id:' \
														-- "$@")

	
	__ERR__=0

	# Define os parâmetros posicionais
	eval set -- "$__PARAM__"

	while :
	do
		case $1 in
			-c|--chat_id)
				__CHAT_ID__="$2"
				shift 2
				;;
			--)
				shift
				break
				;;
		esac
	done

	[ "$__CHAT_ID__" ] || message_error API "$__ERR_PARAM_REQUIRED__" "[-c, --chat_id]"
	
	eval $__POST__ $__API_TELEGRAM__/$__METHOD__ ${__CHAT_ID__:+-d chat_id="'$__CHAT_ID__'"} > $__JSON__

	# Verifica se ocorreu erros durante a chamada do método	
	json_status || message_error TG

	return $__ERR__
	
}

ShellBot.unbanChatMember()
{
	local __CHAT_ID__ __USER_ID__

	# Lê os parâmetros da função
	local __PARAM__=$(getopt --quiet --options 'c:u:' \
										--longoptions 'chat_id:,
														user_id:' \
														-- "$@")

	local __METHOD__=unbanChatMember
	
	__ERR__=0

	# Define os parâmetros posicionais
	eval set -- "$__PARAM__"

	while :
	do
		case $1 in
			-c|--chat_id)
				__CHAT_ID__="$2"
				shift 2
				;;
			-u|--user_id)
				[[ "$2" =~ ^[0-9]+$ ]] || message_error API "$__ERR_TYPE_INT__" "$1" "$2"
				__USER_ID__="$2"
				shift 2
				;;
			--)
				shift
				break
				;;
		esac
	done
	
	[ "$__CHAT_ID__" ] || message_error API "$__ERR_PARAM_REQUIRED__" "[-c, --chat_id]"
	[ "$__USER_ID__" ] || message_error API "$__ERR_PARAM_REQUIRED__" "[-u, --user_id]"
	
	eval $__POST__ $__API_TELEGRAM__/$__METHOD__ ${__CHAT_ID__:+-d chat_id="'$__CHAT_ID__'"} \
												${__USER_ID__:+-d user_id="'$__USER_ID__'"} > $__JSON__

	# Verifica se ocorreu erros durante a chamada do método	
	json_status || message_error TG

	return $__ERR__
}

ShellBot.getChat()
{
	# Variáveis locais
	local __CHAT_ID__
	local __METHOD__=getChat	# Método

	# Lê os parâmetros da função
	local __PARAM__=$(getopt --quiet --options 'c:' \
										--longoptions 'chat_id:' \
														-- "$@")

	
	__ERR__=0

	# Define os parâmetros posicionais
	eval set -- "$__PARAM__"

	while :
	do
		case $1 in
			-c|--chat_id)
				__CHAT_ID__="$2"
				shift 2
				;;
			--)
				shift
				break
				;;
		esac
	done

	[ "$__CHAT_ID__" ] || message_error API "$__ERR_PARAM_REQUIRED__" "[-c, --chat_id]"
	
	eval $__GET__ $__API_TELEGRAM__/$__METHOD__ ${__CHAT_ID__:+-d chat_id="'$__CHAT_ID__'"} > $__JSON__

	# Verifica se ocorreu erros durante a chamada do método	
	json_status || message_error TG

	# Imprime os dados.
	json '.result|.id, .username, .type, .title' |  sed ':a;$!N;s/\n/|/;ta'
	
	# Status
	return $__ERR__
}

ShellBot.getChatAdministrators()
{
	local __CHAT_ID__ __TOTAL__ __KEY__ __INDEX__

	# Lê os parâmetros da função
	local __PARAM__=$(getopt --quiet --options 'c:' \
										--longoptions 'chat_id:' \
														-- "$@")

	local __METHOD__=getChatAdministrators
	
	__ERR__=0

	# Define os parâmetros posicionais
	eval set -- "$__PARAM__"

	while :
	do
		case $1 in
			-c|--chat_id)
				__CHAT_ID__="$2"
				shift 2
				;;
			--)
				shift
				break
				;;
		esac
	done

	[ "$__CHAT_ID__" ] || message_error API "$__ERR_PARAM_REQUIRED__" "[-c, --chat_id]"
	
	eval $__GET__ $__API_TELEGRAM__/$__METHOD__ ${__CHAT_ID__:+-d chat_id="'$__CHAT_ID__'"} > $__JSON__

	# Verifica se ocorreu erros durante a chamada do método	
	json_status || message_error TG

	# Total de administratores
	__TOTAL__=$(json '.result|length')

	# Lê os administradores do grupo se houver.
	if [ $__TOTAL__ -gt 0 ]; then
		for __INDEX__ in $(seq 0 $((__TOTAL__-1)))
		do
			# Lê as informações do usuário armazenadas em '__INDEX__'.
			json ".result[$__INDEX__]|.user.id, .user.username, .user.first_name, .user.last_name, .status" | sed ':a;$!N;s/\n/|/;ta'
		done
	else
		# Retorna 'null' se o grupo não possui administradores.
		echo null
	fi

	# Status	
	return $__ERR__
}

ShellBot.getChatMembersCount()
{
	local __CHAT_ID__

	# Lê os parâmetros da função
	local __PARAM__=$(getopt --quiet --options 'c:' \
										--longoptions 'chat_id:' \
														-- "$@")

	local __METHOD__=getChatMembersCount
	
	__ERR__=0

	# Define os parâmetros posicionais
	eval set -- "$__PARAM__"

	while :
	do
		case $1 in
			-c|--chat_id)
				__CHAT_ID__="$2"
				shift 2
				;;
			--)
				shift
				break
				;;
		esac
	done

	[ "$__CHAT_ID__" ] || message_error API "$__ERR_PARAM_REQUIRED__" "[-c, --chat_id]"
	
	eval $__GET__ $__API_TELEGRAM__/$__METHOD__ ${__CHAT_ID__:+-d chat_id="'$__CHAT_ID__'"} > $__JSON__

	# Verifica se ocorreu erros durante a chamada do método	
	json_status || message_error TG

	json '.result'

	return $__ERR__
}

ShellBot.getChatMember()
{
	# Variáveis locais
	local __CHAT_ID__ __USER_ID__
	local __METHOD__=getChatMember	# Método

	# Lê os parâmetros da função
	local __PARAM__=$(getopt --quiet --options 'c:u:' \
										--longoptions 'chat_id:,
														user_id:' \
														-- "$@")

	
	__ERR__=0

	# Define os parâmetros posicionais
	eval set -- "$__PARAM__"

	while :
	do
		case $1 in
			-c|--chat_id)
				__CHAT_ID__="$2"
				shift 2
				;;
			-u|--user_id)
				[[ "$2" =~ ^[0-9]+$ ]] || message_error API "$__ERR_TYPE_INT__" "$1" "$2"
				__USER_ID__="$2"
				shift 2
				;;
			--)
				shift
				break
				;;
		esac
	done
	
	[ "$__CHAT_ID__" ] || message_error API "$__ERR_PARAM_REQUIRED__" "[-c, --chat_id]"
	[ "$__USER_ID__" ] || message_error API "$__ERR_PARAM_REQUIRED__" "[-u, --user_id]"
	
	eval $__GET__ $__API_TELEGRAM__/$__METHOD__ ${__CHAT_ID__:+-d chat_id="'$__CHAT_ID__'"} \
												${__USER_ID__:+-d user_id="'$__USER_ID__'"} > $__JSON__

	# Verifica se ocorreu erros durante a chamada do método	
	json_status || message_error TG
	
	json '.result| .user.id, .user.username, .user.first_name, .user.last_name, .status' | sed ':a;$!N;s/\n/|/;ta'
	
	return $__ERR__
}

ShellBot.editMessageText()
{
	local __CHAT_ID__ __MESSAGE_ID__ __INLINE_MESSAGE_ID__ __TEXT__ __PARSE_MODE__ __DISABLE_WEB_PAGE_PREVIEW__ __REPLY_MARKUP__
	local __METHOD__=editMessageText
	
	local __PARAM__=$(getopt --quiet --options 'c:m:i:t:p:w:r:' \
										--longoptions 'chat_id:,
														message_id:,
														inline_message_id:,
														text:,
														parse_mode:,
														disable_web_page_preview:,
														reply_markup:' \
														-- "$@")
	
	__ERR__=0

	eval set -- "$__PARAM__"

	while :
	do
			case $1 in
				-c|--chat_id)
					__CHAT_ID__="$2"
					shift 2
					;;
				-m|--message_id)
					[[ "$2" =~ ^[0-9]+$ ]] || message_error API "$__ERR_TYPE_INT__" "$1" "$2"
					__MESSAGE_ID__="$2"
					shift 2
					;;
				-i|--inline_message_id)
					[[ "$2" =~ ^[0-9]+$ ]] || message_error API "$__ERR_TYPE_INT__" "$1" "$2"
					__INLINE_MESSAGE_ID__="$2"
					shift 2
					;;
				-t|--text)
					__TEXT__="$2"
					shift 2
					;;
				-p|--parse_mode)
					[[ "$2" =~ ^(markdown|html)$ ]] || message_error API "$__ERR_TYPE_PARSE_MODE__" "$1" "$2"
					__PARSE_MODE__="$2"
					shift 2
					;;
				-w|--disable_web_page_preview)
					[[ "$2" =~ ^(true|false)$ ]] || message_error API "$__ERR_TYPE_BOOL__" "$1" "$2"
					__DISABLE_WEB_PAGE_PREVIEW__="$2"
					shift 2
					;;
				-r|--reply_markup)
					__REPLY_MARKUP__="$2"
					shift 2
					;;
				--)
					shift
					break
			esac
	done
				
	[ "$__CHAT_ID__" ] || message_error API "$__ERR_PARAM_REQUIRED__" "[-c, --chat_id]"
	[ "$__MESSAGE_ID__" ] || message_error API "$__ERR_PARAM_REQUIRED__" "[-m, --message_id]"
	
	eval $__POST__ $__API_TELEGRAM__/$__METHOD__ ${__CHAT_ID__:+-d chat_id="'$__CHAT_ID__'"} \
													${__MESSAGE_ID__:+-d message_id="'$__MESSAGE_ID__'"} \
													${__INLINE_MESSAGE_ID__:+-d inline_message_id="'$__INLINE_MESSAGE_ID__'"} \
													${__TEXT__:+-d text="'$__TEXT__'"} \
													${__PARSE_MODE__:+-d parse_mode="'$__PARSE_MODE__'"} \
													${__DISABLE_WEB_PAGE_PREVIEW__:+-d disable_web_page_preview="'$__DISABLE_WEB_PAGE_PREVIEW__'"} \
													${__REPLY_MARKUP__:+-d reply_markup="'$__REPLY_MARKUP__'"} > $__JSON__

	# Verifica se ocorreu erros durante a chamada do método	
	json_status || message_error TG
	
	return $__ERR__
	
}

ShellBot.editMessageCaption()
{
	local __CHAT_ID__ __MESSAGE_ID__ __INLINE_MESSAGE_ID__ __CAPTION__ __REPLY_MARKUP__
	local __METHOD__=editMessageCaption
	
	local __PARAM__=$(getopt --quiet --options 'c:m:i:t:r:' \
										--longoptions 'chat_id:,
														message_id:,
														inline_message_id:,
														caption:,
														reply_markup:' \
														-- "$@")
	
	__ERR__=0

	eval set -- "$__PARAM__"

	while :
	do
			case $1 in
				-c|--chat_id)
					__CHAT_ID__="$2"
					shift 2
					;;
				-m|--message_id)
					[[ "$2" =~ ^[0-9]+$ ]] || message_error API "$__ERR_TYPE_INT__" "$1" "$2"
					__MESSAGE_ID__="$2"
					shift 2
					;;
				-i|--inline_message_id)
					[[ "$2" =~ ^[0-9]+$ ]] || message_error API "$__ERR_TYPE_INT__" "$1" "$2"
					__INLINE_MESSAGE_ID__="$2"
					shift 2
					;;
				-t|--caption)
					__CAPTION__="$2"
					shift 2
					;;
				-r|--reply_markup)
					__REPLY_MARKUP__="$2"
					shift 2
					;;
				--)
					shift
					break
			esac
	done
				
	[ "$__CHAT_ID__" ] || message_error API "$__ERR_PARAM_REQUIRED__" "[-c, --chat_id]"
	[ "$__MESSAGE_ID__" ] || message_error API "$__ERR_PARAM_REQUIRED__" "[-m, --message_id]"
	
	eval $__POST__ $__API_TELEGRAM__/$__METHOD__ ${__CHAT_ID__:+-d chat_id="'$__CHAT_ID__'"} \
													${__MESSAGE_ID__:+-d message_id="'$__MESSAGE_ID__'"} \
													${__INLINE_MESSAGE_ID__:+-d inline_message_id="'$__INLINE_MESSAGE_ID__'"} \
													${__CAPTION__:+-d caption="'$__CAPTION__'"} \
													${__REPLY_MARKUP__:+-d reply_markup="'$__REPLY_MARKUP__'"} > $__JSON__

	# Verifica se ocorreu erros durante a chamada do método	
	json_status || message_error TG
	
	return $__ERR__
	
}

ShellBot.editMessageReplyMarkup()
{
	local __CHAT_ID__ __MESSAGE_ID__ __INLINE_MESSAGE_ID__ __REPLY_MARKUP__
	local __METHOD__=editMessageReplyMarkup
	
	local __PARAM__=$(getopt --quiet --options 'c:m:i:r:' \
										--longoptions 'chat_id:,
														message_id:,
														inline_message_id:,
														reply_markup:' \
														-- "$@")
	
	__ERR__=0

	eval set -- "$__PARAM__"

	while :
	do
			case $1 in
				-c|--chat_id)
					__CHAT_ID__="$2"
					shift 2
					;;
				-m|--message_id)
					[[ "$2" =~ ^[0-9]+$ ]] || message_error API "$__ERR_TYPE_INT__" "$1" "$2"
					__MESSAGE_ID__="$2"
					shift 2
					;;
				-i|--inline_message_id)
					[[ "$2" =~ ^[0-9]+$ ]] || message_error API "$__ERR_TYPE_INT__" "$1" "$2"
					__INLINE_MESSAGE_ID__="$2"
					shift 2
					;;
				-r|--reply_markup)
					__REPLY_MARKUP__="$2"
					shift 2
					;;
				--)
					shift
					break
			esac
	done
				
	[ "$__CHAT_ID__" ] || message_error API "$__ERR_PARAM_REQUIRED__" "[-c, --chat_id]"
	[ "$__MESSAGE_ID__" ] || message_error API "$__ERR_PARAM_REQUIRED__" "[-m, --message_id]"
	
	eval $__POST__ $__API_TELEGRAM__/$__METHOD__ ${__CHAT_ID__:+-d chat_id="'$__CHAT_ID__'"} \
													${__MESSAGE_ID__:+-d message_id="'$__MESSAGE_ID__'"} \
													${__INLINE_MESSAGE_ID__:+-d inline_message_id="'$__INLINE_MESSAGE_ID__'"} \
													${__REPLY_MARKUP__:+-d reply_markup="'$__REPLY_MARKUP__'"} > $__JSON__

	# Verifica se ocorreu erros durante a chamada do método	
	json_status || message_error TG
	
	return $__ERR__
	
}

ShellBot.getUpdates()
{
	local -i __TOTAL_KEYS__ __TOTAL_PHOTO__ __OFFSET__ __LIMIT__ __TIMEOUT__ __ALLOWED_UPDATES__
	local __KEY__ __SUBKEY__ __UPDATE__

	local __METHOD__=getUpdates	# Mètodo

	# Define os parâmetros da função
	local __PARAM__=$(getopt  --quiet --options 'o:l:t:a:' \
										--longoptions 'offset:,
														limit:,
														timeout:,
														allowed_updates:' \
														-- "$@")

	
	__ERR__=0

	eval set -- "$__PARAM__"
	
	while :
	do
		case $1 in
			-o|--offset)
				[[ "$2" =~ ^[0-9]+$ ]] || message_error API "$__ERR_TYPE_INT__" "$1" "$2"
				__OFFSET__="$2"
				shift 2
				;;
			-l|--limit)
				[[ "$2" =~ ^[0-9]+$ ]] || message_error API "$__ERR_TYPE_INT__" "$1" "$2"
				__LIMIT__="$2"
				shift 2
				;;
			-t|--timeout)
				[[ "$2" =~ ^[0-9]+$ ]] || message_error API "$__ERR_TYPE_INT__" "$1" "$2"
				__TIMEOUT__="$2"
				shift 2
				;;
			-a|--allowed_updates)
				__ALLOWED_UPDATES__="$2"
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
	eval $__GET__ $__API_TELEGRAM__/$__METHOD__ ${__OFFSET__:+-d offset="'$__OFFSET__'"} \
						${__LIMIT__:+-d limit="'$__LIMIT__'"} \
						${__TIMEOUT__:+-d timeout="'$__TIMEOUT__'"} \
						${__ALLOWED_UPDATES__:+-d allowed_updates="'$__ALLOWED_UPDATES__'"} > $__JSON__

	# Verifica se ocorreu erros durante a chamada do método	
	json_status || message_error TG
	
	# Limpa todas as variáveis.
	unset update_id ${!message_*} ${!edited_message_*} ${!channel_post_*} ${!edited_channel_post_*} 

	# Total de atualizações
	__TOTAL_KEYS__=$(json '.result|length')

	if [ $__TOTAL_KEYS__ -gt 0 ]; then

		for __INDEX__ in $(seq 0 $((__TOTAL_KEYS__-1)))
		do
			__UPDATE__=".result[$__INDEX__]"

			for __KEY__ in $(json "$__UPDATE__|keys|.[]")
			do
				case $__KEY__ in
					'update_id')
						# UPDATE_ID
						update_id[$__INDEX__]=$(json "$__UPDATE__.update_id")
						;;
					'message')
						# MESSAGE
						for __SUBKEY__ in $(json "$__UPDATE__.$__KEY__|keys|.[]")
						do
							case $__SUBKEY__ in
								'message_id')
									# MESSAGE_ID
									message_message_id[$__INDEX__]="$(json $__UPDATE__.message.message_id)"
									;;
								'from')
								# FROM
									 message_from_id[$__INDEX__]="$(json $__UPDATE__.message.from.id)"
									 message_from_first_name[$__INDEX__]="$(json $__UPDATE_.message.from.first_name)"
									 message_from_last_name[$__INDEX__]="$(json $__UPDATE__.message.from.last_name)"
									 message_from_username[$__INDEX__]="$(json $__UPDATE__.message.from.username)"
									;;
								'date')
									# DATE
									 message_date[$__INDEX__]="$(json $__UPDATE__.message.date)"
									;;
								'chat')
									# CHAT
									 message_chat_id[$__INDEX__]="$(json $__UPDATE__.message.chat.id)"
									 message_chat_type[$__INDEX__]="$(json $__UPDATE__.message.chat.type)"
									 message_chat_title[$__INDEX__]="$(json $__UPDATE__.message.chat.title)"
									 message_chat_username[$__INDEX__]="$(json $__UPDATE__.message.chat.username)"
									 message_chat_first_name[$__INDEX__]="$(json $__UPDATE__.message.chat.first_name)"
									 message_chat_last_name[$__INDEX__]="$(json $__UPDATE__.message.chat.last_name)"
									 message_chat_all_members_are_administrators[$__INDEX__]="$(json $__UPDATE__.message.chat.all_members_are_administrators)"
									;;
								'forward_from')
									# FORWARD_FROM
									 message_forward_from_id[$__INDEX__]="$(json $__UPDATE__.message.forward_from.id)"
									 message_forward_from_first_name[$__INDEX__]="$(json $__UPDATE__.message.forward_from.first_name)"
									 message_forward_from_last_name[$__INDEX__]="$(json $__UPDATE__.message.forward_from.last_name)"
									 message_forward_from_username[$__INDEX__]="$(json $__UPDATE__.message.forward_from.username)"
						
									 message_forward_from_chat_id[$__INDEX__]="$(json $__UPDATE__.message.forward_from_chat.id)"
									 message_forward_from_chat_type[$__INDEX__]="$(json $__UPDATE__.message.forward_from_chat.type)"
									 message_forward_from_chat_title[$__INDEX__]="$(json $__UPDATE__.message.forward_from_chat.title)"
									 message_forward_from_chat_username[$__INDEX__]="$(json $__UPDATE__.message.forward_from_chat.username)"
									 message_forward_from_chat_first_name[$__INDEX__]="$(json $__UPDATE__.message.forward_from_chat.first_name)"
									 message_forward_from_chat_last_name[$__INDEX__]="$(json $__UPDATE__.message.forward_from_chat.last_name)"
									 message_forward_from_chat_all_members_are_administrators[$__INDEX__]="$(json $__UPDATE__.message.forward_from_chat.all_members_are_administrators)"
									 message_forward_from_message_id[$__INDEX__]="$(json $__UPDATE__.message.forward_from_message_id)"
									;;
								'forward_date')
									 message_forward_date[$__INDEX__]="$(json $__UPDATE__.message.forward_date)"
									;;
									# REPLY_TO_MESSAGE
								'reply_to_message')
									 message_reply_to_message_message_id[$__INDEX__]="$(json $__UPDATE__.message.reply_to_message.message_id)"
									 message_reply_to_message_from_id[$__INDEX__]="$(json $__UPDATE__.message.reply_to_message.from.id)"
									 message_reply_to_message_from_username[$__INDEX__]="$(json $__UPDATE__.message.reply_to_message.from.username)"
									 message_reply_to_message_from_first_name[$__INDEX__]="$(json $__UPDATE__.message.reply_to_message.from.first_name)"
									 message_reply_to_message_from_last_name[$__INDEX__]="$(json $__UPDATE__.message.reply_to_message.from.last_name)"
									 message_reply_to_message_date[$__INDEX__]="$(json $__UPDATE__.message.reply_to_message.date)"
									 message_reply_to_message_chat_id[$__INDEX__]="$(json $__UPDATE__.message.reply_to_message.chat.id)"
									 message_reply_to_message_chat_type[$__INDEX__]="$(json $__UPDATE__.message.reply_to_message.chat.type)"
									 message_reply_to_message_chat_title[$__INDEX__]="$(json $__UPDATE__.message.reply_to_message.chat.title)"
									 message_reply_to_message_chat_username[$__INDEX__]="$(json $__UPDATE__.message.reply_to_message.chat.username)"
									 message_reply_to_message_chat_first_name[$__INDEX__]="$(json $__UPDATE__.message.reply_to_message.chat.first_name)"
									 message_reply_to_message_chat_last_name[$__INDEX__]="$(json $__UPDATE__.message.reply_to_message.chat.last_name)"
									 message_reply_to_message_chat_all_members_are_administrators[$__INDEX__]="$(json $__UPDATE__.message.reply_to_message.chat.all_members_are_administrators)"
									 message_reply_to_message_forward_from_message_id[$__INDEX__]="$(json $__UPDATE__.message.reply_to_message.forward_from_message_id)"
									 message_reply_to_message_forward_date[$__INDEX__]="$(json $__UPDATE__.message.reply_to_message.forward_date)"
									 message_reply_to_message_edit_date[$__INDEX__]="$(json $__UPDATE__.message.reply_to_message.edit_date)"
									 message_reply_to_message_text[$__INDEX__]="$(json $__UPDATE__.message.reply_to_message.text)"
									;;
								'text')
									# TEXT
									 message_text[$__INDEX__]="$(json $__UPDATE__.message.text)"
									;;
								'entities')
									# ENTITIES
									 message_entities_type[$__INDEX__]="$(json $__UPDATE__.message.entities[].type)"
									 message_entities_offset[$__INDEX__]="$(json $__UPDATE__.message.entities[].offset)"
									 message_entities_length[$__INDEX__]="$(json $__UPDATE__.message.entities[].length)"
									 message_entities_url[$__INDEX__]="$(json $__UPDATE__.message.entities[].url)"
									;;
								'audio')
									# AUDIO
									 message_audio_file_id[$__INDEX__]="$(json $__UPDATE__.message.audio.file_id)"
									 message_audio_duration[$__INDEX__]="$(json $__UPDATE__.message.audio.duration)"
									 message_audio_performer[$__INDEX__]="$(json $__UPDATE__.message.audio.performer)"
									 message_audio_title[$__INDEX__]="$(json $__UPDATE__.message.audio.title)"
									 message_audio_mime_type[$__INDEX__]="$(json $__UPDATE__.message.audio.mime_type)"
									 message_audio_file_size[$__INDEX__]="$(json $__UPDATE__.message.audio.file_size)"
					
									 message_document_file_id[$__INDEX__]="$(json $__UPDATE__.message.document.file_id)"
									 message_document_file_name[$__INDEX__]="$(json $__UPDATE__.message.document.file_name)"
									 message_document_mime_type[$__INDEX__]="$(json $__UPDATE__.message.document.mime_type)"
									 message_document_file_size[$__INDEX__]="$(json $__UPDATE__.message.document.file_size)"
									;;
								'photo')
									__TOTAL_PHOTO__=$(json "$__UPDATE__.message.photo|length" | head -n1)
	
									 message_photo_file_id[$__INDEX__]="$(json $__UPDATE__.message.photo[$((__TOTAL_PHOTO__-1))].file_id)"
									 message_photo_width[$__INDEX__]="$(json $__UPDATE__.message.photo[$((__TOTAL_PHOTO__-1))].width)"
									 message_photo_height[$__INDEX__]="$(json $__UPDATE__.message.photo[$((__TOTAL_PHOTO__-1))].height)"
									 message_photo_file_size[$__INDEX__]="$(json $__UPDATE__.message.photo[$((__TOTAL_PHOTO__-1))].file_size)"
									;;
								'sticker')
									# STICKER
									 message_sticker_file_id[$__INDEX__]="$(json $__UPDATE__.message.sticker.file_id)"
									 message_sticker_width[$__INDEX__]="$(json $__UPDATE__.message.sticker.width)"
									 message_sticker_height[$__INDEX__]="$(json $__UPDATE__.message.sticker.height)"
									 message_sticker_emoji[$__INDEX__]="$(json $__UPDATE__.message.sticker.emoji)"
									 message_sticker_file_size[$__INDEX__]="$(json $__UPDATE__.message.sticker.file_size)"
									;;
								'video')
									# VIDEO
									 message_video_file_id[$__INDEX__]="$(json $__UPDATE__.message.video.file_id)"
									 message_video_width[$__INDEX__]="$(json $__UPDATE__.message.video.width)"
									 message_video_height[$__INDEX__]="$(json $__UPDATE__.message.video.height)"
									 message_video_duration[$__INDEX__]="$(json $__UPDATE__.message.video.duration)"
									 message_video_mime_type[$__INDEX__]="$(json $__UPDATE__.message.video.mime_type)"
									 message_video_file_size[$__INDEX__]="$(json $__UPDATE__.message.video.file_size)"
									;;
								'voice')
									# VOICE
									 message_voice_file_id[$__INDEX__]="$(json $__UPDATE__.message.voice.file_id)"
									 message_voice_duration[$__INDEX__]="$(json $__UPDATE__.message.voice.duration)"
									 message_voice_mime_type[$__INDEX__]="$(json $__UPDATE__.message.voice.mime_type)"
									 message_voice_file_size[$__INDEX__]="$(json $__UPDATE__.message.voice.file_size)"
									;;
								'caption')
									# CAPTION - DOCUMENT, PHOTO ou VIDEO
									 message_caption[$__INDEX__]="$(json $__UPDATE__.message.caption)"
									;;
								'contact')
									# CONTACT
									 message_contact_phone_number[$__INDEX__]="$(json $__UPDATE__.message.contact.phone_number)"
									 message_contact_first_name[$__INDEX__]="$(json $__UPDATE__.message.contact.first_name)"
									 message_contact_last_name[$__INDEX__]="$(json $__UPDATE__.message.contact.last_name)"
									 message_contact_user_id[$__INDEX__]="$(json $__UPDATE__.message.contact.user_id)"
									;;
								'location')
									# LOCATION
									 message_location_longitude[$__INDEX__]="$(json $__UPDATE__.message.location.longitude)"
									 message_location_latitude[$__INDEX__]="$(json $__UPDATE__.message.location.latitude)"
									;;
								'venue')
									# VENUE
									 message_venue_location_longitude[$__INDEX__]="$(json $__UPDATE__.message.venue.location[].longitude)"
									 message_venue_location_latitude[$__INDEX__]="$(json $__UPDATE__.message.venue.location[].latitude)"
									 message_venue_title[$__INDEX__]="$(json $__UPDATE__.message.venue.title)"
									 message_venue_address[$__INDEX__]="$(json $__UPDATE__.message.venue.address)"
									 message_venue_foursquare_id[$__INDEX__]="$(json $__UPDATE__.message.venue.foursquare_id)"
									;;
								'new_chat_member')
									# NEW_MEMBER
									 message_new_chat_member_id[$__INDEX__]="$(json $__UPDATE__.message.new_chat_member.id)"
									 message_new_chat_member_first_name[$__INDEX__]="$(json $__UPDATE__.message.new_chat_member.first_name)"
									 message_new_chat_member_last_name[$__INDEX__]="$(json $__UPDATE__.message.new_chat_member.last_name)"
									 message_new_chat_member_username[$__INDEX__]="$(json $__UPDATE__.message.new_chat_member.username)"
									;;
								'left_chat_member')
									# LEFT_CHAT_MEMBER
									 message_left_chat_member_id[$__INDEX__]="$(json $__UPDATE__.message.left_chat_member.id)"
									 message_left_chat_member_first_name[$__INDEX__]="$(json $__UPDATE__.message.left_chat_member.first_name)"
									 message_left_chat_member_last_name[$__INDEX__]="$(json $__UPDATE__.message.left_chat_member.last_name)"
									 message_left_chat_member_username[$__INDEX__]="$(json $__UPDATE__.message.left_chat_member.username)"
									;;
								'new_chat_title')
									# NEW_CHAT_TITLE
									 message_new_chat_title[$__INDEX__]="$(json $__UPDATE__.message.new_chat_title)"
									;;
								'new_chat_photo')
									# NEW_CHAT_PHOTO
									__TOTAL_PHOTO__=$(json "$__UPDATE__.message.new_chat_photo|length" | head -n1)
					
									 message_new_chat_photo_file_id[$__INDEX__]="$(json $__UPDATE__.message.new_chat_photo[$((__TOTAL_PHOTO__-1))].file_id)"
									 message_new_chat_photo_width[$__INDEX__]="$(json $__UPDATE__.message.new_chat_photo[$((__TOTAL_PHOTO__-1))].width)"
									 message_new_chat_photo_height[$__INDEX__]="$(json $__UPDATE__.message.new_chat_photo[$((__TOTAL_PHOTO__-1))].height)"
									 message_new_chat_photo_file_size[$__INDEX__]="$(json $__UPDATE__.message.new_chat_photo[$((__TOTAL_PHOTO__-1))].file_size)"
									;;
								'delete_chat_photo')
									# DELETE_CHAT_PHOTO
									 message_delete_chat_photo[$__INDEX__]="$(json $__UPDATE__.message.delete_chat_photo)"
									;;
								'group_chat_created')
									# GROUP_CHAT_CREATED
									 message_group_chat_created[$__INDEX__]="$(json $__UPDATE__.message.group_chat_created)"
									;;
								'supergroup_chat_created')
									# SUPERGROUP_CHAT_CREATED
									 message_supergroup_chat_created[$__INDEX__]="$(json $__UPDATE__.message.supergroup_chat_created)"
									;;
								'channel_chat_created')
									# CHANNEL_CHAT_CREATED
									 message_channel_chat_created[$__INDEX__]="$(json $__UPDATE__.message.channel_chat_created)"
									;;
								'migrate_to_chat_id')					
									# MIGRATE_TO_CHAT_ID
									 message_migrate_to_chat_id[$__INDEX__]="$(json $__UPDATE__.message.migrate_to_chat_id)"
									;;
								'migrate_from_chat_id')
									# MIGRATE_FROM_CHAT_ID
									 message_migrate_from_chat_id[$__INDEX__]="$(json $__UPDATE__.message.migrate_from_chat_id)"
									;;
							esac
						done
						;;
					'edited_message')	
						# EDITED_MESSAGE
						for __SUBKEY__ in $(json "$__UPDATE__.$__KEY__|keys|.[]")
						do
							case $__SUBKEY__ in
								'message_id')
									 edited_message_message_id[$__INDEX__]="$(json $__UPDATE__.edited_message.message_id)"
									;;
								'from')
									 edited_message_from_id[$__INDEX__]="$(json $__UPDATE__.edited_message.from.id)"
									 edited_message_from_first_name[$__INDEX__]="$(json $__UPDATE__.edited_message.from.first_name)"
									 edited_message_from_last_name[$__INDEX__]="$(json $__UPDATE__.edited_message.from.last_name)"
									 edited_message_from_username[$__INDEX__]="$(json $__UPDATE__.edited_message.from.username)"
									;;
								'date')
									 edited_message_date[$__INDEX__]="$(json $__UPDATE__.edited_message.date)"
									;;
								'chat')
									 edited_message_chat_id[$__INDEX__]="$(json $__UPDATE__.edited_message.chat.id)"
									 edited_message_chat_type[$__INDEX__]="$(json $__UPDATE__.edited_message.chat.type)"
									 edited_message_chat_title[$__INDEX__]="$(json $__UPDATE__.edited_message.chat.title)"
									 edited_message_chat_username[$__INDEX__]="$(json $__UPDATE__.edited_message.chat.username)"
									 edited_message_chat_first_name[$__INDEX__]="$(json $__UPDATE__.edited_message.chat.first_name)"
									 edited_message_chat_last_name[$__INDEX__]="$(json $__UPDATE__.edited_message.chat.last_name)"
									 edited_message_chat_all_members_are_administrators[$__INDEX__]="$(json $__UPDATE__.edited_message.chat.all_members_are_administrators)"
									;;
								'forward_from')
									 edited_message_forward_from_id[$__INDEX__]="$(json $__UPDATE__.edited_message.forward_from.id)"
									 edited_message_forward_from_first_name[$__INDEX__]="$(json $__UPDATE__.edited_message.forward_from.first_name)"
									 edited_message_forward_from_last_name[$__INDEX__]="$(json $__UPDATE__.edited_message.forward_from.last_name)"
									 edited_message_forward_from_username[$__INDEX__]="$(json $__UPDATE__.edited_message.forward_from.username)"
									 edited_message_forward_from_chat_id[$__INDEX__]="$(json $__UPDATE__.edited_message.forward_from_chat.id)"
									 edited_message_forward_from_chat_type[$__INDEX__]="$(json $__UPDATE__.edited_message.forward_from_chat.type)"
									 edited_message_forward_from_chat_title[$__INDEX__]="$(json $__UPDATE__.edited_message.forward_from_chat.title)"
									 edited_message_forward_from_chat_username[$__INDEX__]="$(json $__UPDATE__.edited_message.forward_from_chat.username)"
									 edited_message_forward_from_chat_first_name[$__INDEX__]="$(json $__UPDATE__.edited_message.forward_from_chat.first_name)"
									 edited_message_forward_from_chat_last_name[$__INDEX__]="$(json $__UPDATE__.edited_message.forward_from_chat.last_name)"
									 edited_message_forward_from_chat_all_members_are_administrators[$__INDEX__]="$(json $__UPDATE__.edited_message.forward_from_chat.all_members_are_administrators)"
									 edited_message_forward_from_message_id[$__INDEX__]="$(json $__UPDATE__.edited_message.forward_from_message_id)"
									;;
								'forward_date')
									 edited_message_forward_date[$__INDEX__]="$(json $__UPDATE__.edited_message.forward_date)"
									;;
								'reply_to_message')
									 edited_message_reply_to_message_message_id[$__INDEX__]="$(json $__UPDATE__.edited_message.reply_to_message.message_id)"
									 edited_message_reply_to_message_from_id[$__INDEX__]="$(json $__UPDATE__.edited_message.reply_to_message.from.id)"
									 edited_message_reply_to_message_from_username[$__INDEX__]="$(json $__UPDATE__.edited_message.reply_to_message.from.username)"
									 edited_message_reply_to_message_from_first_name[$__INDEX__]="$(json $__UPDATE__.edited_message.reply_to_message.from.first_name)"
									 edited_message_reply_to_message_from_last_name[$__INDEX__]="$(json $__UPDATE__.edited_message.reply_to_message.from.last_name)"
									 edited_message_reply_to_message_date[$__INDEX__]="$(json $__UPDATE__.edited_message.reply_to_message.date)"
									 edited_message_reply_to_message_chat_id[$__INDEX__]="$(json $__UPDATE__.edited_message.reply_to_message.chat.id)"
									 edited_message_reply_to_message_chat_type[$__INDEX__]="$(json $__UPDATE__.edited_message.reply_to_message.chat.type)"
									 edited_message_reply_to_message_chat_title[$__INDEX__]="$(json $__UPDATE__.edited_message.reply_to_message.chat.title)"
									 edited_message_reply_to_message_chat_username[$__INDEX__]="$(json $__UPDATE__.edited_message.reply_to_message.chat.username)"
									 edited_message_reply_to_message_chat_first_name[$__INDEX__]="$(json $__UPDATE__.edited_message.reply_to_message.chat.first_name)"
									 edited_message_reply_to_message_chat_last_name[$__INDEX__]="$(json $__UPDATE__.edited_message.reply_to_message.chat.last_name)"
									 edited_message_reply_to_message_chat_all_members_are_administrators[$__INDEX__]="$(json $__UPDATE__.edited_message.reply_to_message.chat.all_members_are_administrators)"
									 edited_message_reply_to_message_forward_from_message_id[$__INDEX__]="$(json $__UPDATE__.edited_message.reply_to_message.forward_from_message_id)"
									 edited_message_reply_to_message_forward_date[$__INDEX__]="$(json $__UPDATE__.edited_message.reply_to_message.forward_date)"
									 edited_message_reply_to_message_edit_date[$__INDEX__]="$(json $__UPDATE__.edited_message.reply_to_message.edit_date)"
									 edited_message_reply_to_message_text[$__INDEX__]="$(json $__UPDATE__.edited_message.reply_to_message.text)"
									;;
								'text')
									 edited_message_text[$__INDEX__]="$(json $__UPDATE__.edited_message.text)"
									;;
								'entities')
									 edited_message_entities_type[$__INDEX__]="$(json $__UPDATE__.edited_message.entities[].type)"
									 edited_message_entities_offset[$__INDEX__]="$(json $__UPDATE__.edited_message.entities[].offset)"
									 edited_message_entities_length[$__INDEX__]="$(json $__UPDATE__.edited_message.entities[].length)"
									 edited_message_entities_url[$__INDEX__]="$(json $__UPDATE__.edited_message.entities[].url)"
									;;
								'audio')
									 edited_message_audio_file_id[$__INDEX__]="$(json $__UPDATE__.edited_message.audio.file_id)"
									 edited_message_audio_duration[$__INDEX__]="$(json $__UPDATE__.edited_message.audio.duration)"
									 edited_message_audio_performer[$__INDEX__]="$(json $__UPDATE__.edited_message.audio.performer)"
									 edited_message_audio_title[$__INDEX__]="$(json $__UPDATE__.edited_message.audio.title)"
									 edited_message_audio_mime_type[$__INDEX__]="$(json $__UPDATE__.edited_message.audio.mime_type)"
									 edited_message_audio_file_size[$__INDEX__]="$(json $__UPDATE__.edited_message.audio.file_size)"
									;;
								'document')
									 edited_message_document_file_id[$__INDEX__]="$(json $__UPDATE__.edited_message.document.file_id)"
									 edited_message_document_file_name[$__INDEX__]="$(json $__UPDATE__.edited_message.document.file_name)"
									 edited_message_document_mime_type[$__INDEX__]="$(json $__UPDATE__.edited_message.document.mime_type)"
									 edited_message_document_file_size[$__INDEX__]="$(json $__UPDATE__.edited_message.document.file_size)"
									;;
								'photo')
					
									__TOTAL_PHOTO__=$(json "$__UPDATE__.edited_message.photo|length" | head -n1)
					
									 edited_message_photo_file_id[$__INDEX__]="$(json $__UPDATE__.edited_message.photo[$((__TOTAL_PHOTO__-1))].file_id)"
									 edited_message_photo_width[$__INDEX__]="$(json $__UPDATE__.edited_message.photo[$((__TOTAL_PHOTO__-1))].width)"
									 edited_message_photo_height[$__INDEX__]="$(json $__UPDATE__.edited_message.photo[$((__TOTAL_PHOTO__-1))].height)"
									 edited_message_photo_file_size[$__INDEX__]="$(json $__UPDATE__.edited_message.photo[$((__TOTAL_PHOTO__-1))].file_size)"
									;;
								'sticker')
									 edited_message_sticker_file_id[$__INDEX__]="$(json $__UPDATE__.edited_message.sticker.file_id)"
									 edited_message_sticker_width[$__INDEX__]="$(json $__UPDATE__.edited_message.sticker.width)"
									 edited_message_sticker_height[$__INDEX__]="$(json $__UPDATE__.edited_message.sticker.height)"
									 edited_message_sticker_emoji[$__INDEX__]="$(json $__UPDATE__.edited_message.sticker.emoji)"
									 edited_message_sticker_file_size[$__INDEX__]="$(json $__UPDATE__.edited_message.sticker.file_size)"
									;;
								'video')
									 edited_message_video_file_id[$__INDEX__]="$(json $__UPDATE__.edited_message.video.file_id)"
									 edited_message_video_width[$__INDEX__]="$(json $__UPDATE__.edited_message.video.width)"
									 edited_message_video_height[$__INDEX__]="$(json $__UPDATE__.edited_message.video.height)"
									 edited_message_video_duration[$__INDEX__]="$(json $__UPDATE__.edited_message.video.duration)"
									 edited_message_video_mime_type[$__INDEX__]="$(json $__UPDATE__.edited_message.video.mime_type)"
									 edited_message_video_file_size[$__INDEX__]="$(json $__UPDATE__.edited_message.video.file_size)"
									;;
								'voice')
									 edited_message_voice_file_id[$__INDEX__]="$(json $__UPDATE__.edited_message.voice.file_id)"
									 edited_message_voice_duration[$__INDEX__]="$(json $__UPDATE__.edited_message.voice.duration)"
									 edited_message_voice_mime_type[$__INDEX__]="$(json $__UPDATE__.edited_message.voice.mime_type)"
									 edited_message_voice_file_size[$__INDEX__]="$(json $__UPDATE__.edited_message.voice.file_size)"
									;;
								'caption')
									 edited_message_caption[$__INDEX__]="$(json $__UPDATE__.edited_message.caption)"
									;;
								'contact')
									 edited_message_contact_phone_number[$__INDEX__]="$(json $__UPDATE__.edited_message.contact.phone_number)"
									 edited_message_contact_first_name[$__INDEX__]="$(json $__UPDATE__.edited_message.contact.first_name)"
									 edited_message_contact_last_name[$__INDEX__]="$(json $__UPDATE__.edited_message.contact.last_name)"
									 edited_message_contact_user_id[$__INDEX__]="$(json $__UPDATE__.edited_message.contact.user_id)"
									;;
								'location')
									 edited_message_location_longitude[$__INDEX__]="$(json $__UPDATE__.edited_message.location.longitude)"
									 edited_message_location_latitude[$__INDEX__]="$(json $__UPDATE__.edited_message.location.latitude)"
									;;
								'venue')
									 edited_message_venue_location_longitude[$__INDEX__]="$(json $__UPDATE__.edited_message.venue.location[].longitude)"
									 edited_message_venue_location_latitude[$__INDEX__]="$(json $__UPDATE__.edited_message.venue.location[].latitude)"
									 edited_message_venue_title[$__INDEX__]="$(json $__UPDATE__.edited_message.venue.title)"
									 edited_message_venue_address[$__INDEX__]="$(json $__UPDATE__.edited_message.venue.address)"
									 edited_message_venue_foursquare_id[$__INDEX__]="$(json $__UPDATE__.edited_message.venue.foursquare_id)"
									;;
								'new_chat_member')
									 edited_message_new_chat_member_id[$__INDEX__]="$(json $__UPDATE__.edited_message.new_chat_member.id)"
									 edited_message_new_chat_member_first_name[$__INDEX__]="$(json $__UPDATE__.edited_message.new_chat_member.first_name)"
									 edited_message_new_chat_member_last_name[$__INDEX__]="$(json $__UPDATE__.edited_message.new_chat_member.last_name)"
									 edited_message_new_chat_member_username[$__INDEX__]="$(json $__UPDATE__.edited_message.new_chat_member.username)"
									;;
								'left_chat_member')
									 edited_message_left_chat_member_id[$__INDEX__]="$(json $__UPDATE__.edited_message.left_chat_member.id)"
									 edited_message_left_chat_member_first_name[$__INDEX__]="$(json $__UPDATE__.edited_message.left_chat_member.first_name)"
									 edited_message_left_chat_member_last_name[$__INDEX__]="$(json $__UPDATE__.edited_message.left_chat_member.last_name)"
									 edited_message_left_chat_member_username[$__INDEX__]="$(json $__UPDATE__.edited_message.left_chat_member.username)"
									;;
								'new_chat_title')
									 edited_message_new_chat_title[$__INDEX__]="$(json $__UPDATE__.edited_message.new_chat_title)"
									;;
								'new_chat_photo')
									__TOTAL_PHOTO__=$(json "$__UPDATE__.edited_message.new_chat_photo|length" | head -n1)
	
									 edited_message_new_chat_photo_file_id[$__INDEX__]="$(json $__UPDATE__.edited_message.new_chat_photo[$((__TOTAL_PHOTO__-1))].file_id)"
									 edited_message_new_chat_photo_width[$__INDEX__]="$(json $__UPDATE__.edited_message.new_chat_photo[$((__TOTAL_PHOTO__-1))].width)"
									 edited_message_new_chat_photo_height[$__INDEX__]="$(json $__UPDATE__.edited_message.new_chat_photo[$((__TOTAL_PHOTO__-1))].height)"
									 edited_message_new_chat_photo_file_size[$__INDEX__]="$(json $__UPDATE__.edited_message.new_chat_photo[$((__TOTAL_PHOTO__-1))].file_size)"
									;;
								'delete_chat_photo')
									 edited_message_delete_chat_photo[$__INDEX__]="$(json $__UPDATE__.edited_message.delete_chat_photo)"
									;;
								'group_chat_created')
									 edited_message_group_chat_created[$__INDEX__]="$(json $__UPDATE__.edited_message.group_chat_created)"
									;;
								'supergroup_chat_created')
									 edited_message_supergroup_chat_created[$__INDEX__]="$(json $__UPDATE__.edited_message.supergroup_chat_created)"
									;;
								'channel_chat_created')
									 edited_message_channel_chat_created[$__INDEX__]="$(json $__UPDATE__.edited_message.channel_chat_created)"
									;;
								'migrate_to_chat_id')
									 edited_message_migrate_to_chat_id[$__INDEX__]="$(json $__UPDATE__.edited_message.migrate_to_chat_id)"
									;;
								'migrate_from_chat_id')
									 edited_message_migrate_from_chat_id[$__INDEX__]="$(json $__UPDATE__.edited_message.migrate_from_chat_id)"
									;;
							esac
						done
						;;
					'channel_post')
						for __SUBKEY__ in $(json "$__UPDATE__.$__KEY__|keys|.[]")
						do
							case $__SUBKEY__ in
								'message_id')
									# XXX CHANNEL_POST XXX
									 channel_post_message_id[$__INDEX__]="$(json $__UPDATE__.channel_post.message_id)"
									;;
								'from')
									 channel_post_from_id[$__INDEX__]="$(json $__UPDATE__.channel_post.from.id)"
									 channel_post_from_first_name[$__INDEX__]="$(json $__UPDATE__.channel_post.from.first_name)"
									 channel_post_from_last_name[$__INDEX__]="$(json $__UPDATE__.channel_post.from.last_name)"
									 channel_post_from_username[$__INDEX__]="$(json $__UPDATE__.channel_post.from.username)"
									;;
								'date')
									 channel_post_date[$__INDEX__]="$(json $__UPDATE__.channel_post.date)"
									;;
								'chat')
									 channel_post_chat_id[$__INDEX__]="$(json $__UPDATE__.channel_post.chat.id)"
									 channel_post_chat_type[$__INDEX__]="$(json $__UPDATE__.channel_post.chat.type)"
									 channel_post_chat_title[$__INDEX__]="$(json $__UPDATE__.channel_post.chat.title)"
									 channel_post_chat_username[$__INDEX__]="$(json $__UPDATE__.channel_post.chat.username)"
									 channel_post_chat_first_name[$__INDEX__]="$(json $__UPDATE__.channel_post.chat.first_name)"
									 channel_post_chat_last_name[$__INDEX__]="$(json $__UPDATE__.channel_post.chat.last_name)"
									 channel_post_chat_all_members_are_administrators[$__INDEX__]="$(json $__UPDATE__.channel_post.chat.all_members_are_administrators)"
									;;
								'forward_from')
									 channel_post_forward_from_id[$__INDEX__]="$(json $__UPDATE__.channel_post.forward_from.id)"
									 channel_post_forward_from_first_name[$__INDEX__]="$(json $__UPDATE__.channel_post.forward_from.first_name)"
									 channel_post_forward_from_last_name[$__INDEX__]="$(json $__UPDATE__.channel_post.forward_from.last_name)"
									 channel_post_forward_from_username[$__INDEX__]="$(json $__UPDATE__.channel_post.forward_from.username)"
									 channel_post_forward_from_chat_id[$__INDEX__]="$(json $__UPDATE__.channel_post.forward_from_chat.id)"
									 channel_post_forward_from_chat_type[$__INDEX__]="$(json $__UPDATE__.channel_post.forward_from_chat.type)"
									 channel_post_forward_from_chat_title[$__INDEX__]="$(json $__UPDATE__.channel_post.forward_from_chat.title)"
									 channel_post_forward_from_chat_username[$__INDEX__]="$(json $__UPDATE__.channel_post.forward_from_chat.username)"
									 channel_post_forward_from_chat_first_name[$__INDEX__]="$(json $__UPDATE__.channel_post.forward_from_chat.first_name)"
									 channel_post_forward_from_chat_last_name[$__INDEX__]="$(json $__UPDATE__.channel_post.forward_from_chat.last_name)"
									 channel_post_forward_from_chat_all_members_are_administrators[$__INDEX__]="$(json $__UPDATE__.channel_post.forward_from_chat.all_members_are_administrators)"
									 channel_post_forward_from_message_id[$__INDEX__]="$(json $__UPDATE__.channel_post.forward_from_message_id)"
									;;
								'forward_date')
									 channel_post_forward_date[$__INDEX__]="$(json $__UPDATE__.channel_post.forward_date)"
									;;
								'reply_to_message')
									 channel_post_reply_to_message_message_id[$__INDEX__]="$(json $__UPDATE__.channel_post.reply_to_message.message_id)"
									 channel_post_reply_to_message_from_id[$__INDEX__]="$(json $__UPDATE__.channel_post.reply_to_message.from.id)"
									 channel_post_reply_to_message_from_username[$__INDEX__]="$(json $__UPDATE__.channel_post.reply_to_message.from.username)"
									 channel_post_reply_to_message_from_first_name[$__INDEX__]="$(json $__UPDATE__.channel_post.reply_to_message.from.first_name)"
									 channel_post_reply_to_message_from_last_name[$__INDEX__]="$(json $__UPDATE__.channel_post.reply_to_message.from.last_name)"
									 channel_post_reply_to_message_date[$__INDEX__]="$(json $__UPDATE__.channel_post.reply_to_message.date)"
									 channel_post_reply_to_message_chat_id[$__INDEX__]="$(json $__UPDATE__.channel_post.reply_to_message.chat.id)"
									 channel_post_reply_to_message_chat_type[$__INDEX__]="$(json $__UPDATE__.channel_post.reply_to_message.chat.type)"
									 channel_post_reply_to_message_chat_title[$__INDEX__]="$(json $__UPDATE__.channel_post.reply_to_message.chat.title)"
									 channel_post_reply_to_message_chat_username[$__INDEX__]="$(json $__UPDATE__.channel_post.reply_to_message.chat.username)"
									 channel_post_reply_to_message_chat_first_name[$__INDEX__]="$(json $__UPDATE__.channel_post.reply_to_message.chat.first_name)"
									 channel_post_reply_to_message_chat_last_name[$__INDEX__]="$(json $__UPDATE__.channel_post.reply_to_message.chat.last_name)"
									 channel_post_reply_to_message_chat_all_members_are_administrators[$__INDEX__]="$(json $__UPDATE__.channel_post.reply_to_message.chat.all_members_are_administrators)"
									 channel_post_reply_to_message_forward_from_message_id[$__INDEX__]="$(json $__UPDATE__.channel_post.reply_to_message.forward_from_message_id)"
									 channel_post_reply_to_message_forward_date[$__INDEX__]="$(json $__UPDATE__.channel_post.reply_to_message.forward_date)"
									 channel_post_reply_to_message_edit_date[$__INDEX__]="$(json $__UPDATE__.channel_post.reply_to_message.edit_date)"
									 channel_post_reply_to_message_text[$__INDEX__]="$(json $__UPDATE__.channel_post.reply_to_message.text)"
									;;
								'text')
									 channel_post_text[$__INDEX__]="$(json $__UPDATE__.channel_post.text)"
									;;
								'entities')
									 channel_post_entities_type[$__INDEX__]="$(json $__UPDATE__.channel_post.entities[].type)"
									 channel_post_entities_offset[$__INDEX__]="$(json $__UPDATE__.channel_post.entities[].offset)"
									 channel_post_entities_length[$__INDEX__]="$(json $__UPDATE__.channel_post.entities[].length)"
									 channel_post_entities_url[$__INDEX__]="$(json $__UPDATE__.channel_post.entities[].url)"
									;;
								'audio')
									 channel_post_audio_file_id[$__INDEX__]="$(json $__UPDATE__.channel_post.audio.file_id)"
									 channel_post_audio_duration[$__INDEX__]="$(json $__UPDATE__.channel_post.audio.duration)"
									 channel_post_audio_performer[$__INDEX__]="$(json $__UPDATE__.channel_post.audio.performer)"
									 channel_post_audio_title[$__INDEX__]="$(json $__UPDATE__.channel_post.audio.title)"
									 channel_post_audio_mime_type[$__INDEX__]="$(json $__UPDATE__.channel_post.audio.mime_type)"
									 channel_post_audio_file_size[$__INDEX__]="$(json $__UPDATE__.channel_post.audio.file_size)"
									;;
								'document')
									 channel_post_document_file_id[$__INDEX__]="$(json $__UPDATE__.channel_post.document.file_id)"
									 channel_post_document_file_name[$__INDEX__]="$(json $__UPDATE__.channel_post.document.file_name)"
									 channel_post_document_mime_type[$__INDEX__]="$(json $__UPDATE__.channel_post.document.mime_type)"
									 channel_post_document_file_size[$__INDEX__]="$(json $__UPDATE__.channel_post.document.file_size)"
									;;
								'photo')
									__TOTAL_PHOTO__=$(json "$__UPDATE__.channel_post.photo|length" | head -n1)
		
									 channel_post_photo_file_id[$__INDEX__]="$(json $__UPDATE__.channel_post.photo[$((__TOTAL_PHOTO__-1))].file_id)"
									 channel_post_photo_width[$__INDEX__]="$(json $__UPDATE__.channel_post.photo[$((__TOTAL_PHOTO__-1))].width)"
									 channel_post_photo_height[$__INDEX__]="$(json $__UPDATE__.channel_post.photo[$((__TOTAL_PHOTO__-1))].height)"
									 channel_post_photo_file_size[$__INDEX__]="$(json $__UPDATE__.channel_post.photo[$((__TOTAL_PHOTO__-1))].file_size)"
									;;
								'sticker')
									 channel_post_sticker_file_id[$__INDEX__]="$(json $__UPDATE__.channel_post.sticker.file_id)"
									 channel_post_sticker_width[$__INDEX__]="$(json $__UPDATE__.channel_post.sticker.width)"
									 channel_post_sticker_height[$__INDEX__]="$(json $__UPDATE__.channel_post.sticker.height)"
									 channel_post_sticker_emoji[$__INDEX__]="$(json $__UPDATE__.channel_post.sticker.emoji)"
									 channel_post_sticker_file_size[$__INDEX__]="$(json $__UPDATE__.channel_post.sticker.file_size)"
									;;
								'video')
									 channel_post_video_file_id[$__INDEX__]="$(json $__UPDATE__.channel_post.video.file_id)"
									 channel_post_video_width[$__INDEX__]="$(json $__UPDATE__.channel_post.video.width)"
									 channel_post_video_height[$__INDEX__]="$(json $__UPDATE__.channel_post.video.height)"
									 channel_post_video_duration[$__INDEX__]="$(json $__UPDATE__.channel_post.video.duration)"
									 channel_post_video_mime_type[$__INDEX__]="$(json $__UPDATE__.channel_post.video.mime_type)"
									 channel_post_video_file_size[$__INDEX__]="$(json $__UPDATE__.channel_post.video.file_size)"
									;;
								'voice')
									 channel_post_voice_file_id[$__INDEX__]="$(json $__UPDATE__.channel_post.voice.file_id)"
									 channel_post_voice_duration[$__INDEX__]="$(json $__UPDATE__.channel_post.voice.duration)"
									 channel_post_voice_mime_type[$__INDEX__]="$(json $__UPDATE__.channel_post.voice.mime_type)"
									 channel_post_voice_file_size[$__INDEX__]="$(json $__UPDATE__.channel_post.voice.file_size)"
									;;
								'caption')
									 channel_post_caption[$__INDEX__]="$(json $__UPDATE__.channel_post.caption)"
									;;
								'contact')
									 channel_post_contact_phone_number[$__INDEX__]="$(json $__UPDATE__.channel_post.contact.phone_number)"
									 channel_post_contact_first_name[$__INDEX__]="$(json $__UPDATE__.channel_post.contact.first_name)"
									 channel_post_contact_last_name[$__INDEX__]="$(json $__UPDATE__.channel_post.contact.last_name)"
									 channel_post_contact_user_id[$__INDEX__]="$(json $__UPDATE__.channel_post.contact.user_id)"
									;;
								'location')
									 channel_post_location_longitude[$__INDEX__]="$(json $__UPDATE__.channel_post.location.longitude)"
									 channel_post_location_latitude[$__INDEX__]="$(json $__UPDATE__.channel_post.location.latitude)"
									;;
								'venue')
									 channel_post_venue_location_longitude[$__INDEX__]="$(json $__UPDATE__.channel_post.venue.location[].longitude)"
									 channel_post_venue_location_latitude[$__INDEX__]="$(json $__UPDATE__.channel_post.venue.location[].latitude)"
									 channel_post_venue_title[$__INDEX__]="$(json $__UPDATE__.channel_post.venue.title)"
									 channel_post_venue_address[$__INDEX__]="$(json $__UPDATE__.channel_post.venue.address)"
									 channel_post_venue_foursquare_id[$__INDEX__]="$(json $__UPDATE__.channel_post.venue.foursquare_id)"
									;;
								'new_chat_member')
									 channel_post_new_chat_member_id[$__INDEX__]="$(json $__UPDATE__.channel_post.new_chat_member.id)"
									 channel_post_new_chat_member_first_name[$__INDEX__]="$(json $__UPDATE__.channel_post.new_chat_member.first_name)"
									 channel_post_new_chat_member_last_name[$__INDEX__]="$(json $__UPDATE__.channel_post.new_chat_member.last_name)"
									 channel_post_new_chat_member_username[$__INDEX__]="$(json $__UPDATE__.channel_post.new_chat_member.username)"
									;;
								'left_chat_member')
									 channel_post_left_chat_member_id[$__INDEX__]="$(json $__UPDATE__.channel_post.left_chat_member.id)"
									 channel_post_left_chat_member_first_name[$__INDEX__]="$(json $__UPDATE__.channel_post.left_chat_member.first_name)"
									 channel_post_left_chat_member_last_name[$__INDEX__]="$(json $__UPDATE__.channel_post.left_chat_member.last_name)"
									 channel_post_left_chat_member_username[$__INDEX__]="$(json $__UPDATE__.channel_post.left_chat_member.username)"
									;;
								'new_chat_title')
									 channel_post_new_chat_title[$__INDEX__]="$(json $__UPDATE__.channel_post.new_chat_title)"
									;;
								'photo')
						
									__TOTAL_PHOTO__=$(json "$__UPDATE__.channel_post.new_chat_photo|length" | head -n1)
						
									 channel_post_new_chat_photo_file_id[$__INDEX__]="$(json $__UPDATE__.channel_post.new_chat_photo[$((__TOTAL_PHOTO__-1))].file_id)"
									 channel_post_new_chat_photo_width[$__INDEX__]="$(json $__UPDATE__.channel_post.new_chat_photo[$((__TOTAL_PHOTO__-1))].width)"
									 channel_post_new_chat_photo_height[$__INDEX__]="$(json $__UPDATE__.channel_post.new_chat_photo[$((__TOTAL_PHOTO__-1))].height)"
									 channel_post_new_chat_photo_file_size[$__INDEX__]="$(json $__UPDATE__.channel_post.new_chat_photo[$((__TOTAL_PHOTO__-1))].file_size)"
									 channel_post_delete_chat_photo[$__INDEX__]="$(json $__UPDATE__.channel_post.delete_chat_photo)"
									;;
								'group_chat_created')
									 channel_post_group_chat_created[$__INDEX__]="$(json $__UPDATE__.channel_post.group_chat_created)"
									 channel_post_supergroup_chat_created[$__INDEX__]="$(json $__UPDATE__.channel_post.supergroup_chat_created)"
									 channel_post_channel_chat_created[$__INDEX__]="$(json $__UPDATE__.channel_post.channel_chat_created)"
									;;
								'migrate_to_chat_id')
									 channel_post_migrate_to_chat_id[$__INDEX__]="$(json $__UPDATE__.channel_post.migrate_to_chat_id)"
									;;
								'migrate_from_chat_id')
									 channel_post_migrate_from_chat_id[$__INDEX__]="$(json $__UPDATE__.channel_post.migrate_from_chat_id)"
									;;
								esac
							done
						;;
					'edited_channel_post')
						for __SUBKEY__ in $(json "$__UPDATE__.$__KEY__|keys|.[]")
						do
							case $__SUBKEY__ in
								'message_id')			
									# EDITED_CHANNEL_POST
									 edited_channel_post_message_id[$__INDEX__]="$(json $__UPDATE__.edited_channel_post.message_id)"
									;;
								'from')
									 edited_channel_post_from_id[$__INDEX__]="$(json $__UPDATE__.edited_channel_post.from.id)"
									 edited_channel_post_from_first_name[$__INDEX__]="$(json $__UPDATE__.edited_channel_post.from.first_name)"
									 edited_channel_post_from_last_name[$__INDEX__]="$(json $__UPDATE__.edited_channel_post.from.last_name)"
									 edited_channel_post_from_username[$__INDEX__]="$(json $__UPDATE__.edited_channel_post.from.username)"
									;;
								'date')
									 edited_channel_post_date[$__INDEX__]="$(json $__UPDATE__.edited_channel_post.date)"
									;;
								'chat')
									 edited_channel_post_chat_id[$__INDEX__]="$(json $__UPDATE__.edited_channel_post.chat.id)"
									 edited_channel_post_chat_type[$__INDEX__]="$(json $__UPDATE__.edited_channel_post.chat.type)"
									 edited_channel_post_chat_title[$__INDEX__]="$(json $__UPDATE__.edited_channel_post.chat.title)"
									 edited_channel_post_chat_username[$__INDEX__]="$(json $__UPDATE__.edited_channel_post.chat.username)"
									 edited_channel_post_chat_first_name[$__INDEX__]="$(json $__UPDATE__.edited_channel_post.chat.first_name)"
									 edited_channel_post_chat_last_name[$__INDEX__]="$(json $__UPDATE__.edited_channel_post.chat.last_name)"
									 edited_channel_post_chat_all_members_are_administrators[$__INDEX__]="$(json $__UPDATE__.edited_channel_post.chat.all_members_are_administrators)"
									;;
								'forward_from')
									 edited_channel_post_forward_from_id[$__INDEX__]="$(json $__UPDATE__.edited_channel_post.forward_from.id)"
									 edited_channel_post_forward_from_first_name[$__INDEX__]="$(json $__UPDATE__.edited_channel_post.forward_from.first_name)"
									 edited_channel_post_forward_from_last_name[$__INDEX__]="$(json $__UPDATE__.edited_channel_post.forward_from.last_name)"
									 edited_channel_post_forward_from_username[$__INDEX__]="$(json $__UPDATE__.edited_channel_post.forward_from.username)"
									 edited_channel_post_forward_from_chat_id[$__INDEX__]="$(json $__UPDATE__.edited_channel_post.forward_from_chat.id)"
									 edited_channel_post_forward_from_chat_type[$__INDEX__]="$(json $__UPDATE__.edited_channel_post.forward_from_chat.type)"
									 edited_channel_post_forward_from_chat_title[$__INDEX__]="$(json $__UPDATE__.edited_channel_post.forward_from_chat.title)"
									 edited_channel_post_forward_from_chat_username[$__INDEX__]="$(json $__UPDATE__.edited_channel_post.forward_from_chat.username)"
									 edited_channel_post_forward_from_chat_first_name[$__INDEX__]="$(json $__UPDATE__.edited_channel_post.forward_from_chat.first_name)"
									 edited_channel_post_forward_from_chat_last_name[$__INDEX__]="$(json $__UPDATE__.edited_channel_post.forward_from_chat.last_name)"
									 edited_channel_post_forward_from_chat_all_members_are_administrators[$__INDEX__]="$(json $__UPDATE__.edited_channel_post.forward_from_chat.all_members_are_administrators)"
									 edited_channel_post_forward_from_message_id[$__INDEX__]="$(json $__UPDATE__.edited_channel_post.forward_from_message_id)"
									;;
								'forward_date')
									 edited_channel_post_forward_date[$__INDEX__]="$(json $__UPDATE__.edited_channel_post.forward_date)"
									;;
								'reply_to_message')
									 edited_channel_post_reply_to_message_message_id[$__INDEX__]="$(json $__UPDATE__.edited_channel_post.reply_to_message.message_id)"
									 edited_channel_post_reply_to_message_from_id[$__INDEX__]="$(json $__UPDATE__.edited_channel_post.reply_to_message.from.id)"
									 edited_channel_post_reply_to_message_from_username[$__INDEX__]="$(json $__UPDATE__.edited_channel_post.reply_to_message.from.username)"
									 edited_channel_post_reply_to_message_from_first_name[$__INDEX__]="$(json $__UPDATE__.edited_channel_post.reply_to_message.from.first_name)"
									 edited_channel_post_reply_to_message_from_last_name[$__INDEX__]="$(json $__UPDATE__.edited_channel_post.reply_to_message.from.last_name)"
									 edited_channel_post_reply_to_message_date[$__INDEX__]="$(json $__UPDATE__.edited_channel_post.reply_to_message.date)"
									 edited_channel_post_reply_to_message_chat_id[$__INDEX__]="$(json $__UPDATE__.edited_channel_post.reply_to_message.chat.id)"
									 edited_channel_post_reply_to_message_chat_type[$__INDEX__]="$(json $__UPDATE__.edited_channel_post.reply_to_message.chat.type)"
									 edited_channel_post_reply_to_message_chat_title[$__INDEX__]="$(json $__UPDATE__.edited_channel_post.reply_to_message.chat.title)"
									 edited_channel_post_reply_to_message_chat_username[$__INDEX__]="$(json $__UPDATE__.edited_channel_post.reply_to_message.chat.username)"
									 edited_channel_post_reply_to_message_chat_first_name[$__INDEX__]="$(json $__UPDATE__.edited_channel_post.reply_to_message.chat.first_name)"
									 edited_channel_post_reply_to_message_chat_last_name[$__INDEX__]="$(json $__UPDATE__.edited_channel_post.reply_to_message.chat.last_name)"
									 edited_channel_post_reply_to_message_chat_all_members_are_administrators[$__INDEX__]="$(json $__UPDATE__.edited_channel_post.reply_to_message.chat.all_members_are_administrators)"
									 edited_channel_post_reply_to_message_forward_from_message_id[$__INDEX__]="$(json $__UPDATE__.edited_channel_post.reply_to_message.forward_from_message_id)"
									 edited_channel_post_reply_to_message_forward_date[$__INDEX__]="$(json $__UPDATE__.edited_channel_post.reply_to_message.forward_date)"
									 edited_channel_post_reply_to_message_edit_date[$__INDEX__]="$(json $__UPDATE__.edited_channel_post.reply_to_message.edit_date)"
									 edited_channel_post_reply_to_message_text[$__INDEX__]="$(json $__UPDATE__.edited_channel_post.reply_to_message.text)"
									;;
								'text')
									 edited_channel_post_text[$__INDEX__]="$(json $__UPDATE__.edited_channel_post.text)"
									;;
								'entities')
									 edited_channel_post_entities_type[$__INDEX__]="$(json $__UPDATE__.edited_channel_post.entities[].type)"
									 edited_channel_post_entities_offset[$__INDEX__]="$(json $__UPDATE__.edited_channel_post.entities[].offset)"
									 edited_channel_post_entities_length[$__INDEX__]="$(json $__UPDATE__.edited_channel_post.entities[].length)"
									 edited_channel_post_entities_url[$__INDEX__]="$(json $__UPDATE__.edited_channel_post.entities[].url)"
									;;
								'audio')
									 edited_channel_post_audio_file_id[$__INDEX__]="$(json $__UPDATE__.edited_channel_post.audio.file_id)"
									 edited_channel_post_audio_duration[$__INDEX__]="$(json $__UPDATE__.edited_channel_post.audio.duration)"
									 edited_channel_post_audio_performer[$__INDEX__]="$(json $__UPDATE__.edited_channel_post.audio.performer)"
									 edited_channel_post_audio_title[$__INDEX__]="$(json $__UPDATE__.edited_channel_post.audio.title)"
									 edited_channel_post_audio_mime_type[$__INDEX__]="$(json $__UPDATE__.edited_channel_post.audio.mime_type)"
									 edited_channel_post_audio_file_size[$__INDEX__]="$(json $__UPDATE__.edited_channel_post.audio.file_size)"
									;;
								'document')
									 edited_channel_post_document_file_id[$__INDEX__]="$(json $__UPDATE__.edited_channel_post.document.file_id)"
									 edited_channel_post_document_file_name[$__INDEX__]="$(json $__UPDATE__.edited_channel_post.document.file_name)"
									 edited_channel_post_document_mime_type[$__INDEX__]="$(json $__UPDATE__.edited_channel_post.document.mime_type)"
									 edited_channel_post_document_file_size[$__INDEX__]="$(json $__UPDATE__.edited_channel_post.document.file_size)"
									;;
								'photo')
						
									__TOTAL_PHOTO__=$(json "$__UPDATE__.edited_channel_post.photo|length" | head -n1)
		
									 edited_channel_post_photo_file_id[$__INDEX__]="$(json $__UPDATE__.edited_channel_post.photo[$((__TOTAL_PHOTO__-1))].file_id)"
									 edited_channel_post_photo_width[$__INDEX__]="$(json $__UPDATE__.edited_channel_post.photo[$((__TOTAL_PHOTO__-1))].width)"
									 edited_channel_post_photo_height[$__INDEX__]="$(json $__UPDATE__.edited_channel_post.photo[$((__TOTAL_PHOTO__-1))].height)"
									 edited_channel_post_photo_file_size[$__INDEX__]="$(json $__UPDATE__.edited_channel_post.photo[$((__TOTAL_PHOTO__-1))].file_size)"
									;;
								'sticker')
									 edited_channel_post_sticker_file_id[$__INDEX__]="$(json $__UPDATE__.edited_channel_post.sticker.file_id)"
									 edited_channel_post_sticker_width[$__INDEX__]="$(json $__UPDATE__.edited_channel_post.sticker.width)"
									 edited_channel_post_sticker_height[$__INDEX__]="$(json $__UPDATE__.edited_channel_post.sticker.height)"
									 edited_channel_post_sticker_emoji[$__INDEX__]="$(json $__UPDATE__.edited_channel_post.sticker.emoji)"
									 edited_channel_post_sticker_file_size[$__INDEX__]="$(json $__UPDATE__.edited_channel_post.sticker.file_size)"
									;;
								'video')
									 edited_channel_post_video_file_id[$__INDEX__]="$(json $__UPDATE__.edited_channel_post.video.file_id)"
									 edited_channel_post_video_width[$__INDEX__]="$(json $__UPDATE__.edited_channel_post.video.width)"
									 edited_channel_post_video_height[$__INDEX__]="$(json $__UPDATE__.edited_channel_post.video.height)"
									 edited_channel_post_video_duration[$__INDEX__]="$(json $__UPDATE__.edited_channel_post.video.duration)"
									 edited_channel_post_video_mime_type[$__INDEX__]="$(json $__UPDATE__.edited_channel_post.video.mime_type)"
									 edited_channel_post_video_file_size[$__INDEX__]="$(json $__UPDATE__.edited_channel_post.video.file_size)"
									;;
								'voice')
									 edited_channel_post_voice_file_id[$__INDEX__]="$(json $__UPDATE__.edited_channel_post.voice.file_id)"
									 edited_channel_post_voice_duration[$__INDEX__]="$(json $__UPDATE__.edited_channel_post.voice.duration)"
									 edited_channel_post_voice_mime_type[$__INDEX__]="$(json $__UPDATE__.edited_channel_post.voice.mime_type)"
									 edited_channel_post_voice_file_size[$__INDEX__]="$(json $__UPDATE__.edited_channel_post.voice.file_size)"
									;;
								'caption')
									 edited_channel_post_caption[$__INDEX__]="$(json $__UPDATE__.edited_channel_post.caption)"
									;;
								'contact')
									 edited_channel_post_contact_phone_number[$__INDEX__]="$(json $__UPDATE__.edited_channel_post.contact.phone_number)"
									 edited_channel_post_contact_first_name[$__INDEX__]="$(json $__UPDATE__.edited_channel_post.contact.first_name)"
									 edited_channel_post_contact_last_name[$__INDEX__]="$(json $__UPDATE__.edited_channel_post.contact.last_name)"
									 edited_channel_post_contact_user_id[$__INDEX__]="$(json $__UPDATE__.edited_channel_post.contact.user_id)"
									;;
								'location')
									 edited_channel_post_location_longitude[$__INDEX__]="$(json $__UPDATE__.edited_channel_post.location.longitude)"
									 edited_channel_post_location_latitude[$__INDEX__]="$(json $__UPDATE__.edited_channel_post.location.latitude)"
									;;
								'venue')
									 edited_channel_post_venue_location_longitude[$__INDEX__]="$(json $__UPDATE__.edited_channel_post.venue.location[].longitude)"
									 edited_channel_post_venue_location_latitude[$__INDEX__]="$(json $__UPDATE__.edited_channel_post.venue.location[].latitude)"
									 edited_channel_post_venue_title[$__INDEX__]="$(json $__UPDATE__.edited_channel_post.venue.title)"
									 edited_channel_post_venue_address[$__INDEX__]="$(json $__UPDATE__.edited_channel_post.venue.address)"
									 edited_channel_post_venue_foursquare_id[$__INDEX__]="$(json $__UPDATE__.edited_channel_post.venue.foursquare_id)"
									;;
								'new_chat_member')
									 edited_channel_post_new_chat_member_id[$__INDEX__]="$(json $__UPDATE__.edited_channel_post.new_chat_member.id)"
									 edited_channel_post_new_chat_member_first_name[$__INDEX__]="$(json $__UPDATE__.edited_channel_post.new_chat_member.first_name)"
									 edited_channel_post_new_chat_member_last_name[$__INDEX__]="$(json $__UPDATE__.edited_channel_post.new_chat_member.last_name)"
									 edited_channel_post_new_chat_member_username[$__INDEX__]="$(json $__UPDATE__.edited_channel_post.new_chat_member.username)"
									;;
								'left_chat_member')
									 edited_channel_post_left_chat_member_id[$__INDEX__]="$(json $__UPDATE__.edited_channel_post.left_chat_member.id)"
									 edited_channel_post_left_chat_member_first_name[$__INDEX__]="$(json $__UPDATE__.edited_channel_post.left_chat_member.first_name)"
									 edited_channel_post_left_chat_member_last_name[$__INDEX__]="$(json $__UPDATE__.edited_channel_post.left_chat_member.last_name)"
									 edited_channel_post_left_chat_member_username[$__INDEX__]="$(json $__UPDATE__.edited_channel_post.left_chat_member.username)"
									;;
								'new_chat_title')
									 edited_channel_post_new_chat_title[$__INDEX__]="$(json $__UPDATE__.edited_channel_post.new_chat_title)"
									;;
								'photo')
						
									__TOTAL_PHOTO__=$(json "$__UPDATE__.edited_channel_post.new_chat_photo|length" | head -n1)
		
									 edited_channel_post_new_chat_photo_file_id[$__INDEX__]="$(json $__UPDATE__.edited_channel_post.new_chat_photo[$((__TOTAL_PHOTO__-1))].file_id)"
									 edited_channel_post_new_chat_photo_width[$__INDEX__]="$(json $__UPDATE__.edited_channel_post.new_chat_photo[$((__TOTAL_PHOTO__-1))].width)"
									 edited_channel_post_new_chat_photo_height[$__INDEX__]="$(json $__UPDATE__.edited_channel_post.new_chat_photo[$((__TOTAL_PHOTO__-1))].height)"
									 edited_channel_post_new_chat_photo_file_size[$__INDEX__]="$(json $__UPDATE__.edited_channel_post.new_chat_photo[$((__TOTAL_PHOTO__-1))].file_size)"
									 edited_channel_post_delete_chat_photo[$__INDEX__]="$(json $__UPDATE__.edited_channel_post.delete_chat_photo)"
									;;
								'group_chat_created')
									 edited_channel_post_group_chat_created[$__INDEX__]="$(json $__UPDATE__.edited_channel_post.group_chat_created)"
									;;
								'supergroup_chat_created')
									 edited_channel_post_supergroup_chat_created[$__INDEX__]="$(json $__UPDATE__.edited_channel_post.supergroup_chat_created)"
									;;
								'channel_chat_created')
									 edited_channel_post_channel_chat_created[$__INDEX__]="$(json $__UPDATE__.edited_channel_post.channel_chat_created)"
									;;
								'migrate_to_chat_id')
									 edited_channel_post_migrate_to_chat_id[$__INDEX__]="$(json $__UPDATE__.edited_channel_post.migrate_to_chat_id)"
									;;
								'migrate_from_chat_id')
									 edited_channel_post_migrate_from_chat_id[$__INDEX__]="$(json $__UPDATE__.edited_channel_post.migrate_from_chat_id)"
									;;
							esac
						done
						;;
					esac
				done
			done
		fi
	
	# Status
	return $__ERR__
}

# Funções somente leitura
declare -rf json_status
declare -rf str_len
declare -rf message_error

# Bot métodos
declare -rf ShellBot.getMe
declare -rf ShellBot.init
declare -rf ShellBot.ReplyKeyboardMarkup
declare -rf ShellBot.sendMessage
declare -rf ShellBot.forwardMessage
declare -rf ShellBot.sendPhoto
declare -rf ShellBot.sendAudio
declare -rf ShellBot.sendDocument
declare -rf ShellBot.sendSticker
declare -rf ShellBot.sendVideo
declare -rf ShellBot.sendVoice
declare -rf ShellBot.sendLocation
declare -rf ShellBot.sendVenue
declare -rf ShellBot.sendContact
declare -rf ShellBot.sendChatAction
declare -rf ShellBot.getUserProfilePhotos
declare -rf ShellBot.getFile
declare -rf ShellBot.kickChatMember
declare -rf ShellBot.leaveChat
declare -rf ShellBot.unbanChatMember
declare -rf ShellBot.getChat
declare -rf ShellBot.getChatAdministrators
declare -rf ShellBot.getChatMembersCount
declare -rf ShellBot.getChatMember
declare -rf ShellBot.editMessageText
declare -rf ShellBot.editMessageCaption
declare -rf ShellBot.editMessageReplyMarkup
declare -rf ShellBot.getUpdates
#FIM
