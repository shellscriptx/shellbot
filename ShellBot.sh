#!/bin/bash

#--------------------------------------------------------------------------------------------------
#	Data:				7 de março de 2017
#	Script:				ShellBot.sh
#	Versão:				1.0
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
#--------------------------------------------------------------------------------------------------

# Verifica se os pacotes necessários estão instalados.
for __PKG__ in curl jq getopt; do
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

# Inicia o script sem erros.
declare -i __ERR__=0

# Arquivo JSON (JavaScript Object Notation) onde são gravados os objetos sempre que função getUpdates é chamada.
# O arquivo armazena os dados da atualização que serão acessados durante a execução de outros métodos; Onde o mesmo
# é sobrescrito sempre que um valor é retornado.
__JSON__=/tmp/update.json

# Define a linha de comando para as chamadas GET e PUT do métodos da API via curl.
__GET__='curl --silent --request GET --url'
__POST__='curl --silent --request POST --url'
 
# Funções para extração dos objetos armazenados no arquivo "update.json"
# 
# Extrai os valores da(s) primeira(s) chave(s) passadas na chamada da função.
JSON.result(){ jq -r ".$1" $__JSON__ 2>/dev/null; }

# Extrai os valores das subchaves contidas em "result", se o nome da subchave for especifcado, sobe-se um nível
# e lista a próxima camada de subchaves e se a segunda subchave for especificada, repete o processo.
JSON.getval() { jq -r ".result$1${2:+|.[]|.$2}${3:+|.[]|.$3}" $__JSON__ 2>/dev/null; }

# Verifica o retorno após a chamada de um método, se for igual a true (sucesso) retorna 0, caso contrário, retorna 1
JSON.getstatus(){ [ "$(JSON.result 'ok')" = true ] && return 0 || return 1; }

# Lẽ somente as chaves únicas
JSON.getkeys(){ jq -r ".result|.[]${1:+|.$1}|keys|.[]" $__JSON__ 2>/dev/null | sort | uniq; }

# Extrai o comprimento da string removendo o caractere nova-linha (\n)
str.len(){ echo $(($(wc -c <<< "$*")-1)); return 0; }

# Trata os erros
message.error()
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
			__ERR_CODE__=$(JSON.result error_code)
			__DESCRIPTION__=$(JSON.result description)
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

# Um método simples para testar o token de autenticação do seu bot. 
# Não requer parâmetros. Retorna informações básicas sobre o bot em forma de um objeto Usuário.
ShellBot.getMe()
{
	# Variável local
	local __METHOD__=getMe	# Método
	
	# Inicia a função sem erros
	__ERR__=0

	# Chama o método getMe passando o endereço da API, seguido do nome do método.
	$__GET__ $__API_TELEGRAM__/$__METHOD__ > $__JSON__
	
	# Verifica o status de retorno do método
	JSON.getstatus || message.error TG

	# Retorna as informações armazenadas em "result".
	printf '%s|%s|%s|%s\n' "$(JSON.getval '.id')" \
							"$(JSON.getval '.username')" \
							"$(JSON.getval '.first_name')" \
				  		   	"$(JSON.getval '.last_name')" \
	
	# status
	return $__ERR__

}

# Inicializa o bot, definindo sua API e TOKEN.
# Atenção: Essa função precisa ser instanciada antes de qualquer outro método.
ShellBot.init()
{
	local __TOKEN__

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
				__TOKEN__="$2"																# TOKEN
				# Visível em todo shell/subshell
				declare -gr  __API_TELEGRAM__=https://api.telegram.org/bot$__TOKEN__		# API
				shift 2
				;;
			--)
				shift
				break
				;;
		esac
	done

	# Parâmetro obrigatório.	
	[ "$__TOKEN__" ] || message.error API "$__ERR_PARAM_REQUIRED__" "[-t, --token]"

	if ! ShellBot.getMe &>/dev/null; then
		message.error API "$__ERR_TOKEN__"; fi

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
				[[ "$2" =~ ^(true|false)$ ]] || message.error API "$__ERR_TYPE_BOOL__" "$1" "$2"
				__RESIZE_KEYBOARD__="$2"
				shift 2
				;;
			-t|--one_time_keyboard)
				# Tipo: boolean
				[[ "$2" =~ ^(true|false)$ ]] || message.error API "$__ERR_TYPE_BOOL__" "$1" "$2"
				__ON_TIME_KEYBOARD__="$2"
				shift 2
				;;
			-s|--selective)
				# Tipo: boolean
				[[ "$2" =~ ^(true|false)$ ]] || message.error API "$__ERR_TYPE_BOOL__" "$1" "$2"
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
	[ "$__KEYBOARD__" ] || message.error API "$__ERR_PARAM_REQUIRED__" "-k, --keyboard"
	
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
				[[ "$2" =~ ^(markdown|html)$ ]] || message.error API "$__ERR_TYPE_PARSE_MODE__" "$1" "$2"
				__PARSE_MODE__="$2"
				shift 2
				;;
			-w|--disable_web_page_preview)
				# Tipo: boolean
				[[ "$2" =~ ^(true|false)$ ]] || message.error API "$__ERR_TYPE_BOOL__" "$1" "$2"
				__DISABLE_WEB_PAGE_PREVIEW__="$2"
				shift 2
				;;
			-n|--disable_notification)
				# Tipo: boolean
				[[ "$2" =~ ^(true|false)$ ]] || message.error API "$__ERR_TYPE_BOOL__" "$1" "$2"
				__DISABLE_NOTIFICATION__="$2"
				shift 2
				;;
			-r|--reply_to_message_id)
				# Tipo: inteiro
				[[ "$2" =~ ^[0-9]+$ ]] || message.error API "$__ERR_TYPE_INT__" "$1" "$2"
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
	[ "$__CHAT_ID__" ] || message.error API "$__ERR_PARAM_REQUIRED__" "[-c, --chat_id]"
	[ "$__TEXT__" ] || message.error API "$__ERR_PARAM_REQUIRED__" "[-t, --text]"

	# Chama o método da API, utilizando o comando request especificado; Os parâmetros 
	# e valores são passados no form e lidos pelo método. O retorno do método é redirecionado para o arquivo 'update.json'.
	# Variáveis com valores nulos são ignoradas e consequentemente os respectivos parâmetros omitidos.
	eval $__POST__ $__API_TELEGRAM__/$__METHOD__ ${__CHAT_ID__:+-F chat_id="'$__CHAT_ID__'"} \
							${__TEXT__:+-F text="'$__TEXT__'"} \
							${__PARSE_MODE__:+-F parse_mode="'$__PARSE_MODE__'"} \
							${__DISABLE_WEB_PAGE_PREVIEW__:+-F disable_web_page_preview="'$__DISABLE_WEB_PAGE_PREVIEW__'"} \
							${__DISABLE_NOTIFICATION__:+-F disable_notification="'$__DISABLE_NOTIFICATION__'"} \
							${__REPLY_TO_MESSAGE_ID__:+-F reply_to_message_id="'$__REPLY_TO_MESSAGE_ID__'"} \
							${__REPLY_MARKUP__:+-F reply_markup="'$__REPLY_MARKUP__'"} > $__JSON__

	# Testa o retorno do método.
	JSON.getstatus || message.error TG
	
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
				[[ "$2" =~ ^(true|false)$ ]] || message.error API "$__ERR_TYPE_BOOL__" "$1" "$2"
				__DISABLE_NOTIFICATION__="$2"
				shift 2
				;;
			-m|--message_id)
				# Tipo: inteiro
				[[ "$2" =~ ^[0-9]+$ ]] || message.error API "$__ERR_TYPE_INT__" "$1" "$2"
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
	[ "$__CHAT_ID__" ] || message.error API "$__ERR_PARAM_REQUIRED__" "[-c, --chat_id]"
	[ "$__FROM_CHAT_ID__" ] || message.error API "$__ERR_PARAM_REQUIRED__" "[-f, --from_chat_id]"
	[ "$__MESSAGE_ID__" ] || message.error API "$__ERR_PARAM_REQUIRED__" "[-m, --message_id]"

	# Chama o método
	eval $__POST__ $__API_TELEGRAM__/$__METHOD__ ${__CHAT_ID__:+-F chat_id="'$__CHAT_ID__'"} \
							${__FROM_CHAT_ID__:+-F from_chat_id="'$__FROM_CHAT_ID__'"} \
							${__DISABLE_NOTIFICATION__:+-F disable_notification="'$__DISABLE_NOTIFICATION__'"} \
							${__MESSAGE_ID__:+-F message_id="'$__MESSAGE_ID__'"} > $__JSON__
	
	# Retorno do método
	JSON.getstatus || message.error TG

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
				[ $(str.len "$2") -gt 200 ] && message.error API "$__ERR_CAPTION_MAX_CHAR__" "$1" 
				__CAPTION__="$2"
				shift 2
				;;
			-n|--disable_notification)
				# Tipo: boolean
				[[ "$2" =~ ^(true|false)$ ]] || message.error API "$__ERR_TYPE_BOOL__" "$1" "$2"
				__DISABLE_NOTIFICATION__="$2"
				shift 2
				;;
			-r|--reply_to_message_id)
				# Tipo: inteiro
				[[ "$2" =~ ^[0-9]+$ ]] || message.error API "$__ERR_TYPE_INT__" "$1" "$2"
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
	[ "$__CHAT_ID__" ] || message.error API "$__ERR_PARAM_REQUIRED__" "[-c, --chat_id]"
	[ "$__PHOTO__" ] || message.error API "$__ERR_PARAM_REQUIRED__" "[-p, --photo]"
	
	# Chama o método
	eval $__POST__ $__API_TELEGRAM__/$__METHOD__ ${__CHAT_ID__:+-F chat_id="'$__CHAT_ID__'"} \
							${__PHOTO__:+-F photo="'$__PHOTO__'"} \
							${__CAPTION__:+-F caption="'$__CAPTION__'"} \
							${__DISABLE_NOTIFICATION__:+-F disable_notification="'$__DISABLE_NOTIFICATION__'"} \
							${__REPLY_TO_MESSAGE_ID__:+-F reply_to_message_id="'$__REPLY_TO_MESSAGE_ID__'"} \
							${__REPLY_MARKUP__:+-F reply_markup="'$__REPLY_MARKUP__'"} > $__JSON__
	
	# Retorno do método
	JSON.getstatus || message.error TG

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
				[[ "$2" =~ ^[0-9]+$ ]] || message.error API "$__ERR_TYPE_INT__" "$1" "$2"
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
				[[ "$2" =~ ^(true|false)$ ]] || message.error API "$__ERR_TYPE_BOOL__" "$1" "$2"
				__DISABLE_NOTIFICATION__="$2"
				shift 2
				;;
			-r|--reply_to_message_id)
				# Tipo: inteiro
				[[ "$2" =~ ^[0-9]+$ ]] || message.error API "$__ERR_TYPE_INT__" "$1" "$2"
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
	[ "$__CHAT_ID__" ] || message.error API "$__ERR_PARAM_REQUIRED__" "[-c, --chat_id]"
	[ "$__AUDIO__" ] || message.error API "$__ERR_PARAM_REQUIRED__" "[-a, --audio]"
	
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
	JSON.getstatus || message.error TG

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
				[[ "$2" =~ ^(true|false)$ ]] || message.error API "$__ERR_TYPE_BOOL__" "$1" "$2"
				__DISABLE_NOTIFICATION__="$2"
				shift 2
				;;
			-r|--reply_to_message_id)
				[[ "$2" =~ ^[0-9]+$ ]] || message.error API "$__ERR_TYPE_INT__" "$1" "$2"
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
	[ "$__CHAT_ID__" ] || message.error API "$__ERR_PARAM_REQUIRED__" "[-c, --chat_id]"
	[ "$__DOCUMENT__" ] || message.error API "$__ERR_PARAM_REQUIRED__" "[-d, --document]"
	
	# Chama o método
	eval $__POST__ $__API_TELEGRAM__/$__METHOD__ ${__CHAT_ID__:+-F chat_id="'$__CHAT_ID__'"} \
							${__DOCUMENT__:+-F document="'$__DOCUMENT__'"} \
							${__CAPTION__:+-F caption="'$__CAPTION__'"} \
							${__DISABLE_NOTIFICATION__:+-F disable_notification="'$__DISABLE_NOTIFICATION__'"} \
							${__REPLY_TO_MESSAGE_ID__:+-F reply_to_message_id="'$__REPLY_TO_MESSAGE_ID__'"} \
							${__REPLY_MARKUP__:+-F reply_markup="'$__REPLY_MARKUP__'"} > $__JSON__

	# Retorno do método
	JSON.getstatus || message.error TG

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
				[[ "$2" =~ ^(true|false)$ ]] || message.error API "$__ERR_TYPE_BOOL__" "$1" "$2"
				__DISABLE_NOTIFICATION__="$2"
				shift 2
				;;
			-r|--reply_to_message_id)
				# Tipo: inteiro
				[[ "$2" =~ ^[0-9]+$ ]] || message.error API "$__ERR_TYPE_INT__" "$1" "$2"
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
	[ "$__CHAT_ID__" ] || message.error API "$__ERR_PARAM_REQUIRED__" "[-c, --chat_id]"
	[ "$__STICKER__" ] || message.error API "$__ERR_PARAM_REQUIRED__" "[-s, --sticker]"

	# Chama o método
	eval $__POST__ $__API_TELEGRAM__/$__METHOD__ ${__CHAT_ID__:+-F chat_id="'$__CHAT_ID__'"} \
							${__STICKER__:+-F sticker="'$__STICKER__'"} \
							${__DISABLE_NOTIFICATION__:+-F disable_notification="'$__DISABLE_NOTIFICATION__'"} \
							${__REPLY_TO_MESSAGE_ID__:+-F reply_to_message_id="'$__REPLY_TO_MESSAGE_ID__'"} \
							${__REPLY_MARKUP__:+-F reply_markup="'$__REPLY_MARKUP__'"} > $__JSON__

	# Testa o retorno do método
	JSON.getstatus || message.error TG

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
				[[ "$2" =~ ^[0-9]+$ ]] || message.error API "$__ERR_TYPE_INT__" "$1" "$2"
				__DURATION_="$2"
				shift 2
				;;
			-w|--width)
				# Tipo: inteiro
				[[ "$2" =~ ^[0-9]+$ ]] || message.error API "$__ERR_TYPE_INT__" "$1" "$2"
				__WIDTH__="$2"
				shift 2
				;;
			-h|--height)
				# Tipo: inteiro
				[[ "$2" =~ ^[0-9]+$ ]] || message.error API "$__ERR_TYPE_INT__" "$1" "$2"
				__HEIGHT__="$2"
				shift 2
				;;
			-t|--caption)
				__CAPTION__="$2"
				shift 2
				;;
			-n|--disable_notification)
				# Tipo: boolean
				[[ "$2" =~ ^(true|false)$ ]] || message.error API "$__ERR_TYPE_BOOL__" "$1" "$2"
				__DISABLE_NOTIFICATION__="$2"
				shift 2
				;;
			-r|--reply_to_message_id)
				[[ "$2" =~ ^[0-9]+$ ]] || message.error API "$__ERR_TYPE_INT__" "$1" "$2"
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
	[ "$__CHAT_ID__" ] || message.error API "$__ERR_PARAM_REQUIRED__" "[-c, --chat_id]"
	[ "$__VIDEO__" ] || message.error API "$__ERR_PARAM_REQUIRED__" "[-v, --video]"

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
	JSON.getstatus || message.error TG

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
				[[ "$2" =~ ^[0-9]+$ ]] || message.error API "$__ERR_TYPE_INT__" "$1" "$2"
				__DURATION__="$2"
				shift 2
				;;
			-n|--disable_notification)
				# Tipo: boolean
				[[ "$2" =~ ^(true|false)$ ]] || message.error API "$__ERR_TYPE_BOOL__" "$1" "$2"
				__DISABLE_NOTIFICATION__="$2"
				shift 2
				;;
			-r|--reply_to_message_id)
				# Tipo: inteiro
				[[ "$2" =~ ^[0-9]+$ ]] || message.error API "$__ERR_TYPE_INT__" "$1" "$2"
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
	[ "$__CHAT_ID__" ] || message.error API "$__ERR_PARAM_REQUIRED__" "[-c, --chat_id]"
	[ "$__VOICE__" ] || message.error API "$__ERR_PARAM_REQUIRED__" "[-v, --voice]"
	
	# Chama o método
	eval $__POST__ $__API_TELEGRAM__/$__METHOD__ ${__CHAT_ID__:+-F chat_id="'$__CHAT_ID__'"} \
							${__VOICE__:+-F voice="'$__VOICE__'"} \
							${__CAPTION__:+-F caption="'$__CAPTION__'"} \
							${__DURATION__:+-F duration="'$__DURATION__'"} \
							${__DISABLE_NOTIFICATION__:+-F disable_notification="'$__DISABLE_NOTIFICATION__'"} \
							${__REPLY_TO_MESSAGE_ID__:+-F reply_to_message_id="'$__REPLY_TO_MESSAGE_ID__'"} \
							${__REPLY_MARKUP__:+-F reply_markup="'$__REPLY_MARKUP__'"} > $__JSON__

	# Testa o retorno do método
	JSON.getstatus || message.error TG

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
				[[ "$2" =~ ^-?[0-9]+\.[0-9]+$ ]] || message.error API "$__ERR_TYPE_FLOAT__" "$1" "$2"
				__LATITUDE__="$2"
				shift 2
				;;
			-g|--longitude)
				# Tipo: float
				[[ "$2" =~ ^-?[0-9]+\.[0-9]+$ ]] || message.error API "$__ERR_TYPE_FLOAT__" "$1" "$2"
				__LONGITUDE__="$2"
				shift 2
				;;
			-n|--disable_notification)
				# Tipo: boolean
				[[ "$2" =~ ^(true|false)$ ]] || message.error API "$__ERR_TYPE_BOOL__" "$1" "$2"
				__DISABLE_NOTIFICATION__="$2"
				shift 2
				;;
			-r|--reply_to_message_id)
				# Tipo: inteiro
				[[ "$2" =~ ^[0-9]+$ ]] || message.error API "$__ERR_TYPE_INT__" "$1" "$2"
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
	[ "$__CHAT_ID__" ] || message.error API "$__ERR_PARAM_REQUIRED__" "[-c, --chat_id]"
	[ "$__LATITUDE__" ] || message.error API "$__ERR_PARAM_REQUIRED__" "[-l, --latitude]"
	[ "$__LONGITUDE__" ] || message.error API "$__ERR_PARAM_REQUIRED__" "[-g, --longitude]"
			
	# Chama o método
	eval $__POST__ $__API_TELEGRAM__/$__METHOD__ ${__CHAT_ID__:+-F chat_id="'$__CHAT_ID__'"} \
							${__LATITUDE__:+-F latitude="'$__LATITUDE__'"} \
							${__LONGITUDE__:+-F longitude="'$__LONGITUDE__'"} \
							${__DISABLE_NOTIFICATION__:+-F disable_notification="'$__DISABLE_NOTIFICATION__'"} \
							${__REPLY_TO_MESSAGE_ID__:+-F reply_to_message_id="'$__REPLY_TO_MESSAGE_ID__'"} \
							${__REPLY_MARKUP__:+-F reply_markup="'$__REPLY_MARKUP__'"} > $__JSON__

	# Testa o retorno do método
	JSON.getstatus || message.error TG

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
				[[ "$2" =~ ^-?[0-9]+\.[0-9]+$ ]] || message.error API "$__ERR_TYPE_FLOAT__" "$1" "$2"
				__LATITUDE__="$2"
				shift 2
				;;
			-g|--longitude)
				# Tipo: float
				[[ "$2" =~ ^-?[0-9]+\.[0-9]+$ ]] || message.error API "$__ERR_TYPE_FLOAT__" "$1" "$2"
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
				[[ "$2" =~ ^(true|false)$ ]] || message.error API "$__ERR_TYPE_BOOL__" "$1" "$2"
				__DISABLE_NOTIFICATION__="$2"
				shift 2
				;;
			-r|--reply_to_message_id)
				# Tipo: inteiro
				[[ "$2" =~ ^[0-9]+$ ]] || message.error API "$__ERR_TYPE_INT__" "$1" "$2"
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
	[ "$__CHAT_ID__" ] || message.error API "$__ERR_PARAM_REQUIRED__" "[-c, --chat_id]"
	[ "$__LATITUDE__" ] || message.error API "$__ERR_PARAM_REQUIRED__" "[-l, --latitude]"
	[ "$__LONGITUDE__" ] || message.error API "$__ERR_PARAM_REQUIRED__" "[-g, --longitude]"
	[ "$__TITLE__" ] || message.error API "$__ERR_PARAM_REQUIRED__" "[-i, --title]"
	[ "$__ADDRESS__" ] || message.error API "$__ERR_PARAM_REQUIRED__" "[-a, --address]"
	
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
	JSON.getstatus || message.error TG

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
				[[ "$2" =~ ^(true|false)$ ]] || message.error API "$__ERR_TYPE_BOOL__" "$1" "$2"
				__DISABLE_NOTIFICATION__="$2"
				shift 2
				;;
			-r|--reply_to_message_id)
				# Tipo: inteiro
				[[ "$2" =~ ^[0-9]+$ ]] || message.error API "$__ERR_TYPE_INT__" "$1" "$2"
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
	[ "$__CHAT_ID__" ] || message.error API "$__ERR_PARAM_REQUIRED__" "[-c, --chat_id]"
	[ "$__PHONE_NUMBER__" ] || message.error API "$__ERR_PARAM_REQUIRED__" "[-p, --phone_number]"
	[ "$__FIRST_NAME__" ] || message.error API "$__ERR_PARAM_REQUIRED__" "[-f, --first_name]"
	
	# Chama o método
	eval $__POST__ $__API_TELEGRAM__/$__METHOD__ ${__CHAT_ID__:+-F chat_id="'$__CHAT_ID__'"} \
							${__PHONE_NUMBER__:+-F phone_number="'$__PHONE_NUMBER__'"} \
							${__FIRST_NAME__:+-F first_name="'$__FIRST_NAME__'"} \
							${__LAST_NAME__:+-F last_name="'$__LAST_NAME__'"} \
							${__DISABLE_NOTIFICATION__:+-F disable_notification="'$__DISABLE_NOTIFICATION__'"} \
							${__REPLY_TO_MESSAGE_ID__:+-F reply_to_message_id="'$__REPLY_TO_MESSAGE_ID__'"} \
							${__REPLY_MARKUP__:+-F reply_markup="'$__REPLY_MARKUP__'"} > $__JSON__

	# Testa o retorno do método
	JSON.getstatus || message.error TG

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
				[[ "$2" =~ ^(typing|upload_photo|record_video|upload_video|record_audio|upload_audio|upload_document|find_location)$ ]] || message.error API "$__ERR_ACTION_MODE__" "$1" "$2"
				__ACTION__="$2"
				shift 2
				;;
			--)
				shift
				break
		esac
	done

	# Parâmetros obrigatórios.		
	[ "$__CHAT_ID__" ] || message.error API "$__ERR_PARAM_REQUIRED__" "[-c, --chat_id]"
	[ "$__ACTION__" ] || message.error API "$__ERR_PARAM_REQUIRED__" "[-a, --action]"
	
	# Chama o método
	eval $__POST__ $__API_TELEGRAM__/$__METHOD__ ${__CHAT_ID__:+-F chat_id="'$__CHAT_ID__'"} \
													${__ACTION__:+-F action="'$__ACTION__'"} > $__JSON__
	
	# Testa o retorno do método
	JSON.getstatus || message.error TG

	# Status
	return $__ERR__
}

# Utilize essa função para obter as fotos de um determinado usuário.
ShellBot.getUserProfilePhotos()
{
	# Variáveis locais 
	local __USER_ID__ __OFFSET__ __LIMIT__ __IND__ __TOTAL__ __LAST__
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
				[[ "$2" =~ ^[0-9]+$ ]] || message.error API "$__ERR_TYPE_INT__" "$1" "$2"
				__USER_ID__="$2"
				shift 2
				;;
			-o|--offset)
				[[ "$2" =~ ^[0-9]+$ ]] || message.error API "$__ERR_TYPE_INT__" "$1" "$2"
				__OFFSET__="$2"
				shift 2
				;;
			-l|--limit)
				[[ "$2" =~ ^[0-9]+$ ]] || message.error API "$__ERR_TYPE_INT__" "$1" "$2"
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
	[ "$__USER_ID__" ] || message.error API "$__ERR_PARAM_REQUIRED__" "[-u, --user_id]"
	
	# Chama o método
	eval $__POST__ $__API_TELEGRAM__/$__METHOD__ ${__USER_ID__:+-F user_id="'$__USER_ID__'"} \
													${__OFFSET__:+-F offset="'$__OFFSET__'"} \
													${__LIMIT__:+-F limit="'$__LIMIT__'"} > $__JSON__

	# Verifica se ocorreu erros durante a chamada do método	
	JSON.getstatus || message.error TG

	# Obtem o total de chaves do objeto "photos"
	__TOTAL__=$(JSON.getval '.photos|length')

	# Se houver objetos
	if [ $__TOTAL__ -gt 0 ]; then
	
		# Obtem o índice do último elemento da chave. 
		__LAST__=$(($(JSON.getval '.photos[0]|length')-1))
		
		# Lê todos os objetos 
		for __IND__ in $(seq 0 $(($__TOTAL__-1)))
		do
			# Retorna as informações do último elemento de cada chave.
			printf '%s|%s|%s|%s|%s\n'	"$(JSON.getval ".photos[$__IND__][$__LAST__].file_id")" \
										"$(JSON.getval ".photos[$__IND__][$__LAST__].file_path")" \
										"$(JSON.getval ".photos[$__IND__][$__LAST__].file_size")" \
										"$(JSON.getval ".photos[$__IND__][$__LAST__].height")" \
										"$(JSON.getval ".photos[$__IND__][$__LAST__].width")" 
		done
	else
		# Se não houver objetos, retorna null.
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
	[ "$__FILE_ID__" ] || message.error API "$__ERR_PARAM_REQUIRED__" "[-f, --file_id]"
	
	# Chama o método.
	eval $__GET__ $__API_TELEGRAM__/$__METHOD__ ${__FILE_ID__:+-F file_id="'$__FILE_ID__'"} > $__JSON__

	# Testa o retorno do método.
	JSON.getstatus || message.error TG

	# Extrai as informações, agrupando-as em uma única linha e insere o delimitador '|' PIPE entre os campos.
	printf '%s|%s|%s\n' "$(JSON.getval '.file_id')" \
						"$(JSON.getval '.file_size')" \
						"$(JSON.getval '.file_path')" 

	
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
				[[ "$2" =~ ^[0-9]+$ ]] || message.error API "$__ERR_TYPE_INT__" "$1" "$2"
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
	[ "$__CHAT_ID__" ] || message.error API "$__ERR_PARAM_REQUIRED__" "[-c, --chat_id]"
	[ "$__USER_ID__" ] || message.error API "$__ERR_PARAM_REQUIRED__" "[-u, --user_id]"
	
	# Chama o método
	eval $__POST__ $__API_TELEGRAM__/$__METHOD__ ${__CHAT_ID__:+-F chat_id="'$__CHAT_ID__'"} \
												${__USER_ID__:+-F user_id="'$__USER_ID__'"} > $__JSON__

	# Verifica se ocorreu erros durante a chamada do método	
	JSON.getstatus || message.error TG

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

	[ "$__CHAT_ID__" ] || message.error API "$__ERR_PARAM_REQUIRED__" "[-c, --chat_id]"
	
	eval $__POST__ $__API_TELEGRAM__/$__METHOD__ ${__CHAT_ID__:+-F chat_id="'$__CHAT_ID__'"} > $__JSON__

	# Verifica se ocorreu erros durante a chamada do método	
	JSON.getstatus || message.error TG

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
				[[ "$2" =~ ^[0-9]+$ ]] || message.error API "$__ERR_TYPE_INT__" "$1" "$2"
				__USER_ID__="$2"
				shift 2
				;;
			--)
				shift
				break
				;;
		esac
	done
	
	[ "$__CHAT_ID__" ] || message.error API "$__ERR_PARAM_REQUIRED__" "[-c, --chat_id]"
	[ "$__USER_ID__" ] || message.error API "$__ERR_PARAM_REQUIRED__" "[-u, --user_id]"
	
	eval $__POST__ $__API_TELEGRAM__/$__METHOD__ ${__CHAT_ID__:+-F chat_id="'$__CHAT_ID__'"} \
												${__USER_ID__:+-F user_id="'$__USER_ID__'"} > $__JSON__

	# Verifica se ocorreu erros durante a chamada do método	
	JSON.getstatus || message.error TG

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

	[ "$__CHAT_ID__" ] || message.error API "$__ERR_PARAM_REQUIRED__" "[-c, --chat_id]"
	
	eval $__GET__ $__API_TELEGRAM__/$__METHOD__ ${__CHAT_ID__:+-F chat_id="'$__CHAT_ID__'"} > $__JSON__

	# Verifica se ocorreu erros durante a chamada do método	
	JSON.getstatus || message.error TG

	#JSON.getval '|.[]' | sed ':a;$!{ N;s/\n/|/;ta }'
	printf '%s|%s|%s|%s|%s|%s|%s\n' "$(JSON.getval '.id')" \
									"$(JSON.getval '.type')" \
									"$(JSON.getval '.username')" \
									"$(JSON.getval '.frist_name')" \
									"$(JSON.getval '.last_name')" \
									"$(JSON.getval '.title')" \
									"$(JSON.getval '.all_members_are_administrators')" 

#type
#title
#username
#frist_name
#last_name
#admins
	return $__ERR__
}

ShellBot.getChatAdministrators()
{
	local __CHAT_ID__ __TOTAL__ __KEY__

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

	[ "$__CHAT_ID__" ] || message.error API "$__ERR_PARAM_REQUIRED__" "[-c, --chat_id]"
	
	eval $__GET__ $__API_TELEGRAM__/$__METHOD__ ${__CHAT_ID__:+-F chat_id="'$__CHAT_ID__'"} > $__JSON__

	# Verifica se ocorreu erros durante a chamada do método	
	JSON.getstatus || message.error TG

	__TOTAL__=$(JSON.getval '|length')

	if [ $__TOTAL__ -gt 0 ]; then
	
		for __IND__ in $(seq 0 $(($__TOTAL__-1)))
		do
			__KEY__="|.[$__IND__]|"

			printf '%s|%s|%s|%s|%s\n' "$(JSON.getval "${__KEY__}.user.id")" \
					                  "$(JSON.getval "${__KEY__}.user.username")" \
						  		   	  "$(JSON.getval "${__KEY__}.user.first_name")" \
						  		   	  "$(JSON.getval "${__KEY__}.user.last_name")" \
									  "$(JSON.getval "${__KEY__}.status")"
		done 
	else
		echo null
	fi

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

	[ "$__CHAT_ID__" ] || message.error API "$__ERR_PARAM_REQUIRED__" "[-c, --chat_id]"
	
	eval $__GET__ $__API_TELEGRAM__/$__METHOD__ ${__CHAT_ID__:+-F chat_id="'$__CHAT_ID__'"} > $__JSON__

	# Verifica se ocorreu erros durante a chamada do método	
	JSON.getstatus || message.error TG

	JSON.getval

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
				[[ "$2" =~ ^[0-9]+$ ]] || message.error API "$__ERR_TYPE_INT__" "$1" "$2"
				__USER_ID__="$2"
				shift 2
				;;
			--)
				shift
				break
				;;
		esac
	done
	
	[ "$__CHAT_ID__" ] || message.error API "$__ERR_PARAM_REQUIRED__" "[-c, --chat_id]"
	[ "$__USER_ID__" ] || message.error API "$__ERR_PARAM_REQUIRED__" "[-u, --user_id]"
	
	eval $__POST__ $__API_TELEGRAM__/$__METHOD__ ${__CHAT_ID__:+-F chat_id="'$__CHAT_ID__'"} \
												${__USER_ID__:+-F user_id="'$__USER_ID__'"} > $__JSON__

	# Verifica se ocorreu erros durante a chamada do método	
	JSON.getstatus || message.error TG
	
	printf '%s|%s|%s|%s|%s\n' "$(JSON.getval '.user.id')" \
			                  "$(JSON.getval '.user.username')" \
				  		   	  "$(JSON.getval '.user.first_name')" \
				  		   	  "$(JSON.getval '.user.last_name')" \
							  "$(JSON.getval '.status')" 

	
	return $__ERR__
}

ShellBot.getUpdates()
{
	local -i __TOTAL_KEYS__ __TOTAL_PHOTO__ __OFFSET__ __LIMIT__ __TIMEOUT__ __ALLOWED_UPDATES__
	local __KEY__ __SUBKEY__ 
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
				[[ "$2" =~ ^[0-9]+$ ]] || message.error API "$__ERR_TYPE_INT__" "$1" "$2"
				__OFFSET__="$2"
				shift 2
				;;
			-l|--limit)
				[[ "$2" =~ ^[0-9]+$ ]] || message.error API "$__ERR_TYPE_INT__" "$1" "$2"
				__LIMIT__="$2"
				shift 2
				;;
			-t|--timeout)
				[[ "$2" =~ ^[0-9]+$ ]] || message.error API "$__ERR_TYPE_INT__" "$1" "$2"
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
	eval $__GET__ $__API_TELEGRAM__/$__METHOD__ ${__OFFSET__:+-F offset="'$__OFFSET__'"} \
						${__LIMIT__:+-F limit="'$__LIMIT__'"} \
						${__TIMEOUT__:+-F timeout="'$__TIMEOUT__'"} \
						${__ALLOWED_UPDATES__:+-F allowed_updates="'$__ALLOWED_UPDATES__'"} > $__JSON__

	# Verifica se ocorreu erros durante a chamada do método	
	JSON.getstatus || message.error TG

	if [ "$(JSON.getkeys)" ]; then
		
		for __KEY__ in $(JSON.getkeys)
		do
			case $__KEY__ in
				'update_id')
					# UPDATE_ID
					readarray -t update_id < <(JSON.getval '' update_id)	
					;;
				'message')
					# MESSAGE
					for __SUBKEY__ in $(JSON.getkeys $__KEY__)
					do
						case $__SUBKEY__ in
							'message_id')
								# MESSAGE_ID
								readarray -t message_message_id < <(JSON.getval '' message.message_id)
								;;
							'from')
								# FROM
								readarray -t message_from_id < <(JSON.getval '' message.from.id)
								readarray -t message_from_first_name < <(JSON.getval '' message.from.first_name)
								readarray -t message_from_last_name < <(JSON.getval '' message.from.last_name)
								readarray -t message_from_username < <(JSON.getval '' message.from.username)
								;;
							'date')
								# DATE
								readarray -t message_date < <(JSON.getval '' message.date)
								;;
							'chat')
								# CHAT
								readarray -t message_chat_id < <(JSON.getval '' message.chat.id)
								readarray -t message_chat_type < <(JSON.getval '' message.chat.type)
								readarray -t message_chat_title < <(JSON.getval '' message.chat.title)
								readarray -t message_chat_username < <(JSON.getval '' message.chat.username)
								readarray -t message_chat_first_name < <(JSON.getval '' message.chat.first_name)
								readarray -t message_chat_last_name < <(JSON.getval '' message.chat.last_name)
								readarray -t message_chat_all_members_are_administrators < <(JSON.getval '' message.chat.all_members_are_administrators)
								;;
							'forward_from')
								# FORWARD_FROM
								readarray -t message_forward_from_id < <(JSON.getval '' message.forward_from.id)
								readarray -t message_forward_from_first_name < <(JSON.getval '' message.forward_from.first_name)
								readarray -t message_forward_from_last_name < <(JSON.getval '' message.forward_from.last_name)
								readarray -t message_forward_from_username < <(JSON.getval '' message.forward_from.username)
					
								readarray -t message_forward_from_chat_id < <(JSON.getval '' message.forward_from_chat.id)
								readarray -t message_forward_from_chat_type < <(JSON.getval '' message.forward_from_chat.type)
								readarray -t message_forward_from_chat_title < <(JSON.getval '' message.forward_from_chat.title)
								readarray -t message_forward_from_chat_username < <(JSON.getval '' message.forward_from_chat.username)
								readarray -t message_forward_from_chat_first_name < <(JSON.getval '' message.forward_from_chat.first_name)
								readarray -t message_forward_from_chat_last_name < <(JSON.getval '' message.forward_from_chat.last_name)
								readarray -t message_forward_from_chat_all_members_are_administrators < <(JSON.getval '' message.forward_from_chat.all_members_are_administrators)
								readarray -t message_forward_from_message_id < <(JSON.getval '' message.forward_from_message_id)
								;;
							'forward_date')
								readarray -t message_forward_date < <(JSON.getval '' message.forward_date)
								;;
								# REPLY_TO_MESSAGE
							'reply_to_message')
								readarray -t message_reply_to_message_message_id < <(JSON.getval '' message.reply_to_message.message_id)
								readarray -t message_reply_to_message_from_id < <(JSON.getval '' message.reply_to_message.from.id)
								readarray -t message_reply_to_message_from_username < <(JSON.getval '' message.reply_to_message.from.username)
								readarray -t message_reply_to_message_from_first_name < <(JSON.getval '' message.reply_to_message.from.first_name)
								readarray -t message_reply_to_message_from_last_name < <(JSON.getval '' message.reply_to_message.from.last_name)
								readarray -t message_reply_to_message_date < <(JSON.getval '' message.reply_to_message.date)
								readarray -t message_reply_to_message_chat_id < <(JSON.getval '' message.reply_to_message.chat.id)
								readarray -t message_reply_to_message_chat_type < <(JSON.getval '' message.reply_to_message.chat.type)
								readarray -t message_reply_to_message_chat_title < <(JSON.getval '' message.reply_to_message.chat.title)
								readarray -t message_reply_to_message_chat_username < <(JSON.getval '' message.reply_to_message.chat.username)
								readarray -t message_reply_to_message_chat_first_name < <(JSON.getval '' message.reply_to_message.chat.first_name)
								readarray -t message_reply_to_message_chat_last_name < <(JSON.getval '' message.reply_to_message.chat.last_name)
								readarray -t message_reply_to_message_chat_all_members_are_administrators < <(JSON.getval '' message.reply_to_message.chat.all_members_are_administrators)
								readarray -t message_reply_to_message_forward_from_message_id < <(JSON.getval '' message.reply_to_message.forward_from_message_id)
								readarray -t message_reply_to_message_forward_date < <(JSON.getval '' message.reply_to_message.forward_date)
								readarray -t message_reply_to_message_edit_date < <(JSON.getval '' message.reply_to_message.edit_date)
								;;
							'text')
								# TEXT
								readarray -t message_text < <(JSON.getval '' message.text)
								;;
							'entities')
								# ENTITIES
								readarray -t message_entities_type < <(JSON.getval '' message.entities type)
								readarray -t message_entities_offset < <(JSON.getval '' message.entities offset)
								readarray -t message_entities_length < <(JSON.getval '' message.entities length)
								readarray -t message_entities_url < <(JSON.getval '' message.entities url)
								;;
							'audio')
								# AUDIO
								readarray -t message_audio_file_id < <(JSON.getval '' message.audio.file_id)
								readarray -t message_audio_duration < <(JSON.getval '' message.audio.duration)
								readarray -t message_audio_performer < <(JSON.getval '' message.audio.performer)
								readarray -t message_audio_title < <(JSON.getval '' message.audio.title)
								readarray -t message_audio_mime_type < <(JSON.getval '' message.audio.mime_type)
								readarray -t message_audio_file_size < <(JSON.getval '' message.audio.file_size)
				
								readarray -t message_document_file_id < <(JSON.getval '' message.document.file_id)
								readarray -t message_document_file_name < <(JSON.getval '' message.document.file_name)
								readarray -t message_document_mime_type < <(JSON.getval '' message.document.mime_type)
								readarray -t message_document_file_size < <(JSON.getval '' message.document.file_size)
								;;
							'photo')
								__TOTAL_PHOTO__=$(JSON.getval '' "message.photo|length" | head -n1)

								readarray -t message_photo_file_id < <(JSON.getval '' message.photo[$((__TOTAL_PHOTO__-1))].file_id)
								readarray -t message_photo_width < <(JSON.getval '' message.photo[$((__TOTAL_PHOTO__-1))].width)
								readarray -t message_photo_height < <(JSON.getval '' message.photo[$((__TOTAL_PHOTO__-1))].height)
								readarray -t message_photo_file_size < <(JSON.getval '' message.photo[$((__TOTAL_PHOTO__-1))].file_size)
								;;
							'sticker')
								# STICKER
								readarray -t message_sticker_file_id < <(JSON.getval '' message.sticker.file_id)
								readarray -t message_sticker_width < <(JSON.getval '' message.sticker.width)
								readarray -t message_sticker_height < <(JSON.getval '' message.sticker.height)
								readarray -t message_sticker_emoji < <(JSON.getval '' message.sticker.emoji)
								readarray -t message_sticker_file_size < <(JSON.getval '' message.sticker.file_size)
								;;
							'video')
								# VIDEO
								readarray -t message_video_file_id < <(JSON.getval '' message.video.file_id)
								readarray -t message_video_width < <(JSON.getval '' message.video.width)
								readarray -t message_video_height < <(JSON.getval '' message.video.height)
								readarray -t message_video_duration < <(JSON.getval '' message.video.duration)
								readarray -t message_video_mime_type < <(JSON.getval '' message.video.mime_type)
								readarray -t message_video_file_size < <(JSON.getval '' message.video.file_size)
								;;
							'voice')
								# VOICE
								readarray -t message_voice_file_id < <(JSON.getval '' message.voice.file_id)
								readarray -t message_voice_duration < <(JSON.getval '' message.voice.duration)
								readarray -t message_voice_mime_type < <(JSON.getval '' message.voice.mime_type)
								readarray -t message_voice_file_size < <(JSON.getval '' message.voice.file_size)
								;;
							'caption')
								# CAPTION - DOCUMENT, PHOTO ou VIDEO
								readarray -t message_caption < <(JSON.getval '' message.caption)
								;;
							'contact')
								# CONTACT
								readarray -t message_contact_phone_number	< <(JSON.getval '' message.contact.phone_number)
								readarray -t message_contact_first_name < <(JSON.getval '' message.contact.first_name)
								readarray -t message_contact_last_name < <(JSON.getval '' message.contact.last_name)
								readarray -t message_contact_user_id < <(JSON.getval '' message.contact.user_id)
								;;
							'location')
								# LOCATION
								readarray -t message_location_longitude < <(JSON.getval '' message.location.longitude)
								readarray -t message_location_latitude < <(JSON.getval '' message.location.latitude)
								;;
							'venue')
								# VENUE
								readarray -t message_venue_location_longitude < <(JSON.getval '' message.venue.location longitude)
								readarray -t message_venue_location_latitude < <(JSON.getval '' message.venue.location latitude)
								readarray -t message_venue_title < <(JSON.getval '' message.venue.title)
								readarray -t message_venue_address < <(JSON.getval '' message.venue.address)
								readarray -t message_venue_foursquare_id < <(JSON.getval '' message.venue.foursquare_id)
								;;
							'new_chat_member')
								# NEW_MEMBER
								readarray -t message_new_chat_member_id < <(JSON.getval '' message.new_chat_member.id)
								readarray -t message_new_chat_member_first_name < <(JSON.getval '' message.new_chat_member.first_name)
								readarray -t message_new_chat_member_last_name < <(JSON.getval '' message.new_chat_member.last_name)
								readarray -t message_new_chat_member_username < <(JSON.getval '' message.new_chat_member.username)
								;;
							'left_chat_member')
								# LEFT_CHAT_MEMBER
								readarray -t message_left_chat_member_id < <(JSON.getval '' message.left_chat_member.id)
								readarray -t message_left_chat_member_first_name < <(JSON.getval '' message.left_chat_member.first_name)
								readarray -t message_left_chat_member_last_name < <(JSON.getval '' message.left_chat_member.last_name)
								readarray -t message_left_chat_member_username < <(JSON.getval '' message.left_chat_member.username)
								;;
							'new_chat_title')
								# NEW_CHAT_TITLE
								readarray -t message_new_chat_title < <(JSON.getval '' message.new_chat_title)
								;;
							'new_chat_photo')
								# NEW_CHAT_PHOTO
								__TOTAL_PHOTO__=$(JSON.getval '' "message.new_chat_photo|length" | head -n1)
				
								readarray -t message_new_chat_photo_file_id < <(JSON.getval '' message.new_chat_photo[$((__TOTAL_PHOTO__-1))].file_id)
								readarray -t message_new_chat_photo_width < <(JSON.getval '' message.new_chat_photo[$((__TOTAL_PHOTO__-1))].width)
								readarray -t message_new_chat_photo_height < <(JSON.getval '' message.new_chat_photo[$((__TOTAL_PHOTO__-1))].height)
								readarray -t message_new_chat_photo_file_size < <(JSON.getval '' message.new_chat_photo[$((__TOTAL_PHOTO__-1))].file_size)
								;;
							'delete_chat_photo')
								# DELETE_CHAT_PHOTO
								readarray -t message_delete_chat_photo < <(JSON.getval '' message.delete_chat_photo)
								;;
							'group_chat_created')
								# GROUP_CHAT_CREATED
								readarray -t message_group_chat_created < <(JSON.getval '' message.group_chat_created)
								;;
							'supergroup_chat_created')
								# SUPERGROUP_CHAT_CREATED
								readarray -t message_supergroup_chat_created < <(JSON.getval '' message.supergroup_chat_created)
								;;
							'channel_chat_created')
								# CHANNEL_CHAT_CREATED
								readarray -t message_channel_chat_created < <(JSON.getval '' message.channel_chat_created)
								;;
							'migrate_to_chat_id')					
								# MIGRATE_TO_CHAT_ID
								readarray -t message_migrate_to_chat_id < <(JSON.getval '' message.migrate_to_chat_id)
								;;
							'migrate_from_chat_id')
								# MIGRATE_FROM_CHAT_ID
								readarray -t message_migrate_from_chat_id < <(JSON.getval '' message.migrate_from_chat_id)
								;;
						esac
					done
					;;
				'edited_message')	
					# EDITED_MESSAGE
					for __SUBKEY__ in $(JSON.getkeys $__KEY__)
					do
						case $__SUBKEY__ in
							'message_id')
								readarray -t edited_message_message_id < <(JSON.getval '' edited_message.message_id)
								;;
							'from')
								readarray -t edited_message_from_id < <(JSON.getval '' edited_message.from.id)
								readarray -t edited_message_from_first_name < <(JSON.getval '' edited_message.from.first_name)
								readarray -t edited_message_from_last_name < <(JSON.getval '' edited_message.from.last_name)
								readarray -t edited_message_from_username < <(JSON.getval '' edited_message.from.username)
								;;
							'date')
								readarray -t edited_message_date < <(JSON.getval '' edited_message.date)
								;;
							'chat')
								readarray -t edited_message_chat_id < <(JSON.getval '' edited_message.chat.id)
								readarray -t edited_message_chat_type < <(JSON.getval '' edited_message.chat.type)
								readarray -t edited_message_chat_title < <(JSON.getval '' edited_message.chat.title)
								readarray -t edited_message_chat_username < <(JSON.getval '' edited_message.chat.username)
								readarray -t edited_message_chat_first_name < <(JSON.getval '' edited_message.chat.first_name)
								readarray -t edited_message_chat_last_name < <(JSON.getval '' edited_message.chat.last_name)
								readarray -t edited_message_chat_all_members_are_administrators < <(JSON.getval '' edited_message.chat.all_members_are_administrators)
								;;
							'forward_from')
								readarray -t edited_message_forward_from_id < <(JSON.getval '' edited_message.forward_from.id)
								readarray -t edited_message_forward_from_first_name < <(JSON.getval '' edited_message.forward_from.first_name)
								readarray -t edited_message_forward_from_last_name < <(JSON.getval '' edited_message.forward_from.last_name)
								readarray -t edited_message_forward_from_username < <(JSON.getval '' edited_message.forward_from.username)
								readarray -t edited_message_forward_from_chat_id < <(JSON.getval '' edited_message.forward_from_chat.id)
								readarray -t edited_message_forward_from_chat_type < <(JSON.getval '' edited_message.forward_from_chat.type)
								readarray -t edited_message_forward_from_chat_title < <(JSON.getval '' edited_message.forward_from_chat.title)
								readarray -t edited_message_forward_from_chat_username < <(JSON.getval '' edited_message.forward_from_chat.username)
								readarray -t edited_message_forward_from_chat_first_name < <(JSON.getval '' edited_message.forward_from_chat.first_name)
								readarray -t edited_message_forward_from_chat_last_name < <(JSON.getval '' edited_message.forward_from_chat.last_name)
								readarray -t edited_message_forward_from_chat_all_members_are_administrators < <(JSON.getval '' edited_message.forward_from_chat.all_members_are_administrators)
								readarray -t edited_message_forward_from_message_id < <(JSON.getval '' edited_message.forward_from_message_id)
								;;
							'forward_date')
								readarray -t edited_message_forward_date < <(JSON.getval '' edited_message.forward_date)
								;;
							'reply_to_message')
								readarray -t edited_message_reply_to_message_message_id < <(JSON.getval '' edited_message.reply_to_message.message_id)
								readarray -t edited_message_reply_to_message_from_id < <(JSON.getval '' edited_message.reply_to_message.from.id)
								readarray -t edited_message_reply_to_message_from_username < <(JSON.getval '' edited_message.reply_to_message.from.username)
								readarray -t edited_message_reply_to_message_from_first_name < <(JSON.getval '' edited_message.reply_to_message.from.first_name)
								readarray -t edited_message_reply_to_message_from_last_name < <(JSON.getval '' edited_message.reply_to_message.from.last_name)
								readarray -t edited_message_reply_to_message_date < <(JSON.getval '' edited_message.reply_to_message.date)
								readarray -t edited_message_reply_to_message_chat_id < <(JSON.getval '' edited_message.reply_to_message.chat.id)
								readarray -t edited_message_reply_to_message_chat_type < <(JSON.getval '' edited_message.reply_to_message.chat.type)
								readarray -t edited_message_reply_to_message_chat_title < <(JSON.getval '' edited_message.reply_to_message.chat.title)
								readarray -t edited_message_reply_to_message_chat_username < <(JSON.getval '' edited_message.reply_to_message.chat.username)
								readarray -t edited_message_reply_to_message_chat_first_name < <(JSON.getval '' edited_message.reply_to_message.chat.first_name)
								readarray -t edited_message_reply_to_message_chat_last_name < <(JSON.getval '' edited_message.reply_to_message.chat.last_name)
								readarray -t edited_message_reply_to_message_chat_all_members_are_administrators < <(JSON.getval '' edited_message.reply_to_message.chat.all_members_are_administrators)
								readarray -t edited_message_reply_to_message_forward_from_message_id < <(JSON.getval '' edited_message.reply_to_message.forward_from_message_id)
								readarray -t edited_message_reply_to_message_forward_date < <(JSON.getval '' edited_message.reply_to_message.forward_date)
								readarray -t edited_message_reply_to_message_edit_date < <(JSON.getval '' edited_message.reply_to_message.edit_date)
								;;
							'text')
								readarray -t edited_message_text < <(JSON.getval '' edited_message.text)
								;;
							'entities')
								readarray -t edited_message_entities_type < <(JSON.getval '' edited_message.entities type)
								readarray -t edited_message_entities_offset < <(JSON.getval '' edited_message.entities offset)
								readarray -t edited_message_entities_length < <(JSON.getval '' edited_message.entities length)
								readarray -t edited_message_entities_url < <(JSON.getval '' edited_message.entities url)
								;;
							'audio')
								readarray -t edited_message_audio_file_id < <(JSON.getval '' edited_message.audio.file_id)
								readarray -t edited_message_audio_duration < <(JSON.getval '' edited_message.audio.duration)
								readarray -t edited_message_audio_performer < <(JSON.getval '' edited_message.audio.performer)
								readarray -t edited_message_audio_title < <(JSON.getval '' edited_message.audio.title)
								readarray -t edited_message_audio_mime_type < <(JSON.getval '' edited_message.audio.mime_type)
								readarray -t edited_message_audio_file_size < <(JSON.getval '' edited_message.audio.file_size)
								;;
							'document')
								readarray -t edited_message_document_file_id < <(JSON.getval '' edited_message.document.file_id)
								readarray -t edited_message_document_file_name < <(JSON.getval '' edited_message.document.file_name)
								readarray -t edited_message_document_mime_type < <(JSON.getval '' edited_message.document.mime_type)
								readarray -t edited_message_document_file_size < <(JSON.getval '' edited_message.document.file_size)
								;;
							'photo')
				
								__TOTAL_PHOTO__=$(JSON.getval '' "edited_message.photo|length" | head -n1)
				
								readarray -t edited_message_photo_file_id < <(JSON.getval '' edited_message.photo[$((__TOTAL_PHOTO__-1))].file_id)
								readarray -t edited_message_photo_width < <(JSON.getval '' edited_message.photo[$((__TOTAL_PHOTO__-1))].width)
								readarray -t edited_message_photo_height < <(JSON.getval '' edited_message.photo[$((__TOTAL_PHOTO__-1))].height)
								readarray -t edited_message_photo_file_size < <(JSON.getval '' edited_message.photo[$((__TOTAL_PHOTO__-1))].file_size)
								;;
							'sticker')
								readarray -t edited_message_sticker_file_id < <(JSON.getval '' edited_message.sticker.file_id)
								readarray -t edited_message_sticker_width < <(JSON.getval '' edited_message.sticker.width)
								readarray -t edited_message_sticker_height < <(JSON.getval '' edited_message.sticker.height)
								readarray -t edited_message_sticker_emoji < <(JSON.getval '' edited_message.sticker.emoji)
								readarray -t edited_message_sticker_file_size < <(JSON.getval '' edited_message.sticker.file_size)
								;;
							'video')
								readarray -t edited_message_video_file_id < <(JSON.getval '' edited_message.video.file_id)
								readarray -t edited_message_video_width < <(JSON.getval '' edited_message.video.width)
								readarray -t edited_message_video_height < <(JSON.getval '' edited_message.video.height)
								readarray -t edited_message_video_duration < <(JSON.getval '' edited_message.video.duration)
								readarray -t edited_message_video_mime_type < <(JSON.getval '' edited_message.video.mime_type)
								readarray -t edited_message_video_file_size < <(JSON.getval '' edited_message.video.file_size)
								;;
							'voice')
								readarray -t edited_message_voice_file_id < <(JSON.getval '' edited_message.voice.file_id)
								readarray -t edited_message_voice_duration < <(JSON.getval '' edited_message.voice.duration)
								readarray -t edited_message_voice_mime_type < <(JSON.getval '' edited_message.voice.mime_type)
								readarray -t edited_message_voice_file_size < <(JSON.getval '' edited_message.voice.file_size)
								;;
							'caption')
								readarray -t edited_message_caption < <(JSON.getval '' edited_message.caption)
								;;
							'contact')
								readarray -t edited_message_contact_phone_number	< <(JSON.getval '' edited_message.contact.phone_number)
								readarray -t edited_message_contact_first_name < <(JSON.getval '' edited_message.contact.first_name)
								readarray -t edited_message_contact_last_name < <(JSON.getval '' edited_message.contact.last_name)
								readarray -t edited_message_contact_user_id < <(JSON.getval '' edited_message.contact.user_id)
								;;
							'location')
								readarray -t edited_message_location_longitude < <(JSON.getval '' edited_message.location.longitude)
								readarray -t edited_message_location_latitude < <(JSON.getval '' edited_message.location.latitude)
								;;
							'venue')
								readarray -t edited_message_venue_location_longitude < <(JSON.getval '' edited_message.venue.location longitude)
								readarray -t edited_message_venue_location_latitude < <(JSON.getval '' edited_message.venue.location latitude)
								readarray -t edited_message_venue_title < <(JSON.getval '' edited_message.venue.title)
								readarray -t edited_message_venue_address < <(JSON.getval '' edited_message.venue.address)
								readarray -t edited_message_venue_foursquare_id < <(JSON.getval '' edited_message.venue.foursquare_id)
								;;
							'new_chat_member')
								readarray -t edited_message_new_chat_member_id < <(JSON.getval '' edited_message.new_chat_member.id)
								readarray -t edited_message_new_chat_member_first_name < <(JSON.getval '' edited_message.new_chat_member.first_name)
								readarray -t edited_message_new_chat_member_last_name < <(JSON.getval '' edited_message.new_chat_member.last_name)
								readarray -t edited_message_new_chat_member_username < <(JSON.getval '' edited_message.new_chat_member.username)
								;;
							'left_chat_member')
								readarray -t edited_message_left_chat_member_id < <(JSON.getval '' edited_message.left_chat_member.id)
								readarray -t edited_message_left_chat_member_first_name < <(JSON.getval '' edited_message.left_chat_member.first_name)
								readarray -t edited_message_left_chat_member_last_name < <(JSON.getval '' edited_message.left_chat_member.last_name)
								readarray -t edited_message_left_chat_member_username < <(JSON.getval '' edited_message.left_chat_member.username)
								;;
							'new_chat_title')
								readarray -t edited_message_new_chat_title < <(JSON.getval '' edited_message.new_chat_title)
								;;
							'new_chat_photo')
								__TOTAL_PHOTO__=$(JSON.getval '' "edited_message.new_chat_photo|length" | head -n1)

								readarray -t edited_message_new_chat_photo_file_id < <(JSON.getval '' edited_message.new_chat_photo[$((__TOTAL_PHOTO__-1))].file_id)
								readarray -t edited_message_new_chat_photo_width < <(JSON.getval '' edited_message.new_chat_photo[$((__TOTAL_PHOTO__-1))].width)
								readarray -t edited_message_new_chat_photo_height < <(JSON.getval '' edited_message.new_chat_photo[$((__TOTAL_PHOTO__-1))].height)
								readarray -t edited_message_new_chat_photo_file_size < <(JSON.getval '' edited_message.new_chat_photo[$((__TOTAL_PHOTO__-1))].file_size)
								;;
							'delete_chat_photo')
								readarray -t edited_message_delete_chat_photo < <(JSON.getval '' edited_message.delete_chat_photo)
								;;
							'group_chat_created')
								readarray -t edited_message_group_chat_created < <(JSON.getval '' edited_message.group_chat_created)
								;;
							'supergroup_chat_created')
								readarray -t edited_message_supergroup_chat_created < <(JSON.getval '' edited_message.supergroup_chat_created)
								;;
							'channel_chat_created')
								readarray -t edited_message_channel_chat_created < <(JSON.getval '' edited_message.channel_chat_created)
								;;
							'migrate_to_chat_id')
								readarray -t edited_message_migrate_to_chat_id < <(JSON.getval '' edited_message.migrate_to_chat_id)
								;;
							'migrate_from_chat_id')
								readarray -t edited_message_migrate_from_chat_id < <(JSON.getval '' edited_message.migrate_from_chat_id)
								;;
						esac
					done
					;;
				'channel_post')
					for __SUBKEY__ in $(JSON.getkeys $__KEY__)
					do
						case $__SUBKEY__ in
							'message_id')
								# XXX CHANNEL_POST XXX
								readarray -t channel_post_message_id < <(JSON.getval '' channel_post.message_id)
								;;
							'from')
								readarray -t channel_post_from_id < <(JSON.getval '' channel_post.from.id)
								readarray -t channel_post_from_first_name < <(JSON.getval '' channel_post.from.first_name)
								readarray -t channel_post_from_last_name < <(JSON.getval '' channel_post.from.last_name)
								readarray -t channel_post_from_username < <(JSON.getval '' channel_post.from.username)
								;;
							'date')
								readarray -t channel_post_date < <(JSON.getval '' channel_post.date)
								;;
							'chat')
								readarray -t channel_post_chat_id < <(JSON.getval '' channel_post.chat.id)
								readarray -t channel_post_chat_type < <(JSON.getval '' channel_post.chat.type)
								readarray -t channel_post_chat_title < <(JSON.getval '' channel_post.chat.title)
								readarray -t channel_post_chat_username < <(JSON.getval '' channel_post.chat.username)
								readarray -t channel_post_chat_first_name < <(JSON.getval '' channel_post.chat.first_name)
								readarray -t channel_post_chat_last_name < <(JSON.getval '' channel_post.chat.last_name)
								readarray -t channel_post_chat_all_members_are_administrators < <(JSON.getval '' channel_post.chat.all_members_are_administrators)
								;;
							'forward_from')
								readarray -t channel_post_forward_from_id < <(JSON.getval '' channel_post.forward_from.id)
								readarray -t channel_post_forward_from_first_name < <(JSON.getval '' channel_post.forward_from.first_name)
								readarray -t channel_post_forward_from_last_name < <(JSON.getval '' channel_post.forward_from.last_name)
								readarray -t channel_post_forward_from_username < <(JSON.getval '' channel_post.forward_from.username)
								readarray -t channel_post_forward_from_chat_id < <(JSON.getval '' channel_post.forward_from_chat.id)
								readarray -t channel_post_forward_from_chat_type < <(JSON.getval '' channel_post.forward_from_chat.type)
								readarray -t channel_post_forward_from_chat_title < <(JSON.getval '' channel_post.forward_from_chat.title)
								readarray -t channel_post_forward_from_chat_username < <(JSON.getval '' channel_post.forward_from_chat.username)
								readarray -t channel_post_forward_from_chat_first_name < <(JSON.getval '' channel_post.forward_from_chat.first_name)
								readarray -t channel_post_forward_from_chat_last_name < <(JSON.getval '' channel_post.forward_from_chat.last_name)
								readarray -t channel_post_forward_from_chat_all_members_are_administrators < <(JSON.getval '' channel_post.forward_from_chat.all_members_are_administrators)
								readarray -t channel_post_forward_from_message_id < <(JSON.getval '' channel_post.forward_from_message_id)
								;;
							'forward_date')
								readarray -t channel_post_forward_date < <(JSON.getval '' channel_post.forward_date)
								;;
							'reply_to_message')
								readarray -t channel_post_reply_to_message_message_id < <(JSON.getval '' channel_post.reply_to_message.message_id)
								readarray -t channel_post_reply_to_message_from_id < <(JSON.getval '' channel_post.reply_to_message.from.id)
								readarray -t channel_post_reply_to_message_from_username < <(JSON.getval '' channel_post.reply_to_message.from.username)
								readarray -t channel_post_reply_to_message_from_first_name < <(JSON.getval '' channel_post.reply_to_message.from.first_name)
								readarray -t channel_post_reply_to_message_from_last_name < <(JSON.getval '' channel_post.reply_to_message.from.last_name)
								readarray -t channel_post_reply_to_message_date < <(JSON.getval '' channel_post.reply_to_message.date)
								readarray -t channel_post_reply_to_message_chat_id < <(JSON.getval '' channel_post.reply_to_message.chat.id)
								readarray -t channel_post_reply_to_message_chat_type < <(JSON.getval '' channel_post.reply_to_message.chat.type)
								readarray -t channel_post_reply_to_message_chat_title < <(JSON.getval '' channel_post.reply_to_message.chat.title)
								readarray -t channel_post_reply_to_message_chat_username < <(JSON.getval '' channel_post.reply_to_message.chat.username)
								readarray -t channel_post_reply_to_message_chat_first_name < <(JSON.getval '' channel_post.reply_to_message.chat.first_name)
								readarray -t channel_post_reply_to_message_chat_last_name < <(JSON.getval '' channel_post.reply_to_message.chat.last_name)
								readarray -t channel_post_reply_to_message_chat_all_members_are_administrators < <(JSON.getval '' channel_post.reply_to_message.chat.all_members_are_administrators)
								readarray -t channel_post_reply_to_message_forward_from_message_id < <(JSON.getval '' channel_post.reply_to_message.forward_from_message_id)
								readarray -t channel_post_reply_to_message_forward_date < <(JSON.getval '' channel_post.reply_to_message.forward_date)
								readarray -t channel_post_reply_to_message_edit_date < <(JSON.getval '' channel_post.reply_to_message.edit_date)
								;;
							'text')
								readarray -t channel_post_text < <(JSON.getval '' channel_post.text)
								;;
							'entities')
								readarray -t channel_post_entities_type < <(JSON.getval '' channel_post.entities type)
								readarray -t channel_post_entities_offset < <(JSON.getval '' channel_post.entities offset)
								readarray -t channel_post_entities_length < <(JSON.getval '' channel_post.entities length)
								readarray -t channel_post_entities_url < <(JSON.getval '' channel_post.entities url)
								;;
							'audio')
								readarray -t channel_post_audio_file_id < <(JSON.getval '' channel_post.audio.file_id)
								readarray -t channel_post_audio_duration < <(JSON.getval '' channel_post.audio.duration)
								readarray -t channel_post_audio_performer < <(JSON.getval '' channel_post.audio.performer)
								readarray -t channel_post_audio_title < <(JSON.getval '' channel_post.audio.title)
								readarray -t channel_post_audio_mime_type < <(JSON.getval '' channel_post.audio.mime_type)
								readarray -t channel_post_audio_file_size < <(JSON.getval '' channel_post.audio.file_size)
								;;
							'document')
								readarray -t channel_post_document_file_id < <(JSON.getval '' channel_post.document.file_id)
								readarray -t channel_post_document_file_name < <(JSON.getval '' channel_post.document.file_name)
								readarray -t channel_post_document_mime_type < <(JSON.getval '' channel_post.document.mime_type)
								readarray -t channel_post_document_file_size < <(JSON.getval '' channel_post.document.file_size)
								;;
							'photo')
								__TOTAL_PHOTO__=$(JSON.getval '' "channel_post.photo|length" | head -n1)
	
								readarray -t channel_post_photo_file_id < <(JSON.getval '' channel_post.photo[$((__TOTAL_PHOTO__-1))].file_id)
								readarray -t channel_post_photo_width < <(JSON.getval '' channel_post.photo[$((__TOTAL_PHOTO__-1))].width)
								readarray -t channel_post_photo_height < <(JSON.getval '' channel_post.photo[$((__TOTAL_PHOTO__-1))].height)
								readarray -t channel_post_photo_file_size < <(JSON.getval '' channel_post.photo[$((__TOTAL_PHOTO__-1))].file_size)
								;;
							'sticker')
								readarray -t channel_post_sticker_file_id < <(JSON.getval '' channel_post.sticker.file_id)
								readarray -t channel_post_sticker_width < <(JSON.getval '' channel_post.sticker.width)
								readarray -t channel_post_sticker_height < <(JSON.getval '' channel_post.sticker.height)
								readarray -t channel_post_sticker_emoji < <(JSON.getval '' channel_post.sticker.emoji)
								readarray -t channel_post_sticker_file_size < <(JSON.getval '' channel_post.sticker.file_size)
								;;
							'video')
								readarray -t channel_post_video_file_id < <(JSON.getval '' channel_post.video.file_id)
								readarray -t channel_post_video_width < <(JSON.getval '' channel_post.video.width)
								readarray -t channel_post_video_height < <(JSON.getval '' channel_post.video.height)
								readarray -t channel_post_video_duration < <(JSON.getval '' channel_post.video.duration)
								readarray -t channel_post_video_mime_type < <(JSON.getval '' channel_post.video.mime_type)
								readarray -t channel_post_video_file_size < <(JSON.getval '' channel_post.video.file_size)
								;;
							'voice')
								readarray -t channel_post_voice_file_id < <(JSON.getval '' channel_post.voice.file_id)
								readarray -t channel_post_voice_duration < <(JSON.getval '' channel_post.voice.duration)
								readarray -t channel_post_voice_mime_type < <(JSON.getval '' channel_post.voice.mime_type)
								readarray -t channel_post_voice_file_size < <(JSON.getval '' channel_post.voice.file_size)
								;;
							'caption')
								readarray -t channel_post_caption < <(JSON.getval '' channel_post.caption)
								;;
							'contact')
								readarray -t channel_post_contact_phone_number	< <(JSON.getval '' channel_post.contact.phone_number)
								readarray -t channel_post_contact_first_name < <(JSON.getval '' channel_post.contact.first_name)
								readarray -t channel_post_contact_last_name < <(JSON.getval '' channel_post.contact.last_name)
								readarray -t channel_post_contact_user_id < <(JSON.getval '' channel_post.contact.user_id)
								;;
							'location')
								readarray -t channel_post_location_longitude < <(JSON.getval '' channel_post.location.longitude)
								readarray -t channel_post_location_latitude < <(JSON.getval '' channel_post.location.latitude)
								;;
							'venue')
								readarray -t channel_post_venue_location_longitude < <(JSON.getval '' channel_post.venue.location longitude)
								readarray -t channel_post_venue_location_latitude < <(JSON.getval '' channel_post.venue.location latitude)
								readarray -t channel_post_venue_title < <(JSON.getval '' channel_post.venue.title)
								readarray -t channel_post_venue_address < <(JSON.getval '' channel_post.venue.address)
								readarray -t channel_post_venue_foursquare_id < <(JSON.getval '' channel_post.venue.foursquare_id)
								;;
							'new_chat_member')
								readarray -t channel_post_new_chat_member_id < <(JSON.getval '' channel_post.new_chat_member.id)
								readarray -t channel_post_new_chat_member_first_name < <(JSON.getval '' channel_post.new_chat_member.first_name)
								readarray -t channel_post_new_chat_member_last_name < <(JSON.getval '' channel_post.new_chat_member.last_name)
								readarray -t channel_post_new_chat_member_username < <(JSON.getval '' channel_post.new_chat_member.username)
								;;
							'left_chat_member')
								readarray -t channel_post_left_chat_member_id < <(JSON.getval '' channel_post.left_chat_member.id)
								readarray -t channel_post_left_chat_member_first_name < <(JSON.getval '' channel_post.left_chat_member.first_name)
								readarray -t channel_post_left_chat_member_last_name < <(JSON.getval '' channel_post.left_chat_member.last_name)
								readarray -t channel_post_left_chat_member_username < <(JSON.getval '' channel_post.left_chat_member.username)
								;;
							'new_chat_title')
								readarray -t channel_post_new_chat_title < <(JSON.getval '' channel_post.new_chat_title)
								;;
							'photo')
					
								__TOTAL_PHOTO__=$(JSON.getval '' "channel_post.new_chat_photo|length" | head -n1)
					
								readarray -t channel_post_new_chat_photo_file_id < <(JSON.getval '' channel_post.new_chat_photo[$((__TOTAL_PHOTO__-1))].file_id)
								readarray -t channel_post_new_chat_photo_width < <(JSON.getval '' channel_post.new_chat_photo[$((__TOTAL_PHOTO__-1))].width)
								readarray -t channel_post_new_chat_photo_height < <(JSON.getval '' channel_post.new_chat_photo[$((__TOTAL_PHOTO__-1))].height)
								readarray -t channel_post_new_chat_photo_file_size < <(JSON.getval '' channel_post.new_chat_photo[$((__TOTAL_PHOTO__-1))].file_size)
								readarray -t channel_post_delete_chat_photo < <(JSON.getval '' channel_post.delete_chat_photo)
								;;
							'group_chat_created')
								readarray -t channel_post_group_chat_created < <(JSON.getval '' channel_post.group_chat_created)
								readarray -t channel_post_supergroup_chat_created < <(JSON.getval '' channel_post.supergroup_chat_created)
								readarray -t channel_post_channel_chat_created < <(JSON.getval '' channel_post.channel_chat_created)
								;;
							'migrate_to_chat_id')
								readarray -t channel_post_migrate_to_chat_id < <(JSON.getval '' channel_post.migrate_to_chat_id)
								;;
							'migrate_from_chat_id')
								readarray -t channel_post_migrate_from_chat_id < <(JSON.getval '' channel_post.migrate_from_chat_id)
								;;
							esac
						done
					;;
				'edited_channel_post')
					for __SUBKEY__ in $(JSON.getkeys $__KEY__)
					do
						case $__SUBKEY__ in
							'message_id')			
								# EDITED_CHANNEL_POST
								readarray -t edited_channel_post_message_id < <(JSON.getval '' edited_channel_post.message_id)
								;;
							'from')
								readarray -t edited_channel_post_from_id < <(JSON.getval '' edited_channel_post.from.id)
								readarray -t edited_channel_post_from_first_name < <(JSON.getval '' edited_channel_post.from.first_name)
								readarray -t edited_channel_post_from_last_name < <(JSON.getval '' edited_channel_post.from.last_name)
								readarray -t edited_channel_post_from_username < <(JSON.getval '' edited_channel_post.from.username)
								;;
							'date')
								readarray -t edited_channel_post_date < <(JSON.getval '' edited_channel_post.date)
								;;
							'chat')
								readarray -t edited_channel_post_chat_id < <(JSON.getval '' edited_channel_post.chat.id)
								readarray -t edited_channel_post_chat_type < <(JSON.getval '' edited_channel_post.chat.type)
								readarray -t edited_channel_post_chat_title < <(JSON.getval '' edited_channel_post.chat.title)
								readarray -t edited_channel_post_chat_username < <(JSON.getval '' edited_channel_post.chat.username)
								readarray -t edited_channel_post_chat_first_name < <(JSON.getval '' edited_channel_post.chat.first_name)
								readarray -t edited_channel_post_chat_last_name < <(JSON.getval '' edited_channel_post.chat.last_name)
								readarray -t edited_channel_post_chat_all_members_are_administrators < <(JSON.getval '' edited_channel_post.chat.all_members_are_administrators)
								;;
							'forward_from')
								readarray -t edited_channel_post_forward_from_id < <(JSON.getval '' edited_channel_post.forward_from.id)
								readarray -t edited_channel_post_forward_from_first_name < <(JSON.getval '' edited_channel_post.forward_from.first_name)
								readarray -t edited_channel_post_forward_from_last_name < <(JSON.getval '' edited_channel_post.forward_from.last_name)
								readarray -t edited_channel_post_forward_from_username < <(JSON.getval '' edited_channel_post.forward_from.username)
								readarray -t edited_channel_post_forward_from_chat_id < <(JSON.getval '' edited_channel_post.forward_from_chat.id)
								readarray -t edited_channel_post_forward_from_chat_type < <(JSON.getval '' edited_channel_post.forward_from_chat.type)
								readarray -t edited_channel_post_forward_from_chat_title < <(JSON.getval '' edited_channel_post.forward_from_chat.title)
								readarray -t edited_channel_post_forward_from_chat_username < <(JSON.getval '' edited_channel_post.forward_from_chat.username)
								readarray -t edited_channel_post_forward_from_chat_first_name < <(JSON.getval '' edited_channel_post.forward_from_chat.first_name)
								readarray -t edited_channel_post_forward_from_chat_last_name < <(JSON.getval '' edited_channel_post.forward_from_chat.last_name)
								readarray -t edited_channel_post_forward_from_chat_all_members_are_administrators < <(JSON.getval '' edited_channel_post.forward_from_chat.all_members_are_administrators)
								readarray -t edited_channel_post_forward_from_message_id < <(JSON.getval '' edited_channel_post.forward_from_message_id)
								;;
							'forward_date')
								readarray -t edited_channel_post_forward_date < <(JSON.getval '' edited_channel_post.forward_date)
								;;
							'reply_to_message')
								readarray -t edited_channel_post_reply_to_message_message_id < <(JSON.getval '' edited_channel_post.reply_to_message.message_id)
								readarray -t edited_channel_post_reply_to_message_from_id < <(JSON.getval '' edited_channel_post.reply_to_message.from.id)
								readarray -t edited_channel_post_reply_to_message_from_username < <(JSON.getval '' edited_channel_post.reply_to_message.from.username)
								readarray -t edited_channel_post_reply_to_message_from_first_name < <(JSON.getval '' edited_channel_post.reply_to_message.from.first_name)
								readarray -t edited_channel_post_reply_to_message_from_last_name < <(JSON.getval '' edited_channel_post.reply_to_message.from.last_name)
								readarray -t edited_channel_post_reply_to_message_date < <(JSON.getval '' edited_channel_post.reply_to_message.date)
								readarray -t edited_channel_post_reply_to_message_chat_id < <(JSON.getval '' edited_channel_post.reply_to_message.chat.id)
								readarray -t edited_channel_post_reply_to_message_chat_type < <(JSON.getval '' edited_channel_post.reply_to_message.chat.type)
								readarray -t edited_channel_post_reply_to_message_chat_title < <(JSON.getval '' edited_channel_post.reply_to_message.chat.title)
								readarray -t edited_channel_post_reply_to_message_chat_username < <(JSON.getval '' edited_channel_post.reply_to_message.chat.username)
								readarray -t edited_channel_post_reply_to_message_chat_first_name < <(JSON.getval '' edited_channel_post.reply_to_message.chat.first_name)
								readarray -t edited_channel_post_reply_to_message_chat_last_name < <(JSON.getval '' edited_channel_post.reply_to_message.chat.last_name)
								readarray -t edited_channel_post_reply_to_message_chat_all_members_are_administrators < <(JSON.getval '' edited_channel_post.reply_to_message.chat.all_members_are_administrators)
								readarray -t edited_channel_post_reply_to_message_forward_from_message_id < <(JSON.getval '' edited_channel_post.reply_to_message.forward_from_message_id)
								readarray -t edited_channel_post_reply_to_message_forward_date < <(JSON.getval '' edited_channel_post.reply_to_message.forward_date)
								readarray -t edited_channel_post_reply_to_message_edit_date < <(JSON.getval '' edited_channel_post.reply_to_message.edit_date)
								;;
							'text')
								readarray -t edited_channel_post_text < <(JSON.getval '' edited_channel_post.text)
								;;
							'entities')
								readarray -t edited_channel_post_entities_type < <(JSON.getval '' edited_channel_post.entities type)
								readarray -t edited_channel_post_entities_offset < <(JSON.getval '' edited_channel_post.entities offset)
								readarray -t edited_channel_post_entities_length < <(JSON.getval '' edited_channel_post.entities length)
								readarray -t edited_channel_post_entities_url < <(JSON.getval '' edited_channel_post.entities url)
								;;
							'audio')
								readarray -t edited_channel_post_audio_file_id < <(JSON.getval '' edited_channel_post.audio.file_id)
								readarray -t edited_channel_post_audio_duration < <(JSON.getval '' edited_channel_post.audio.duration)
								readarray -t edited_channel_post_audio_performer < <(JSON.getval '' edited_channel_post.audio.performer)
								readarray -t edited_channel_post_audio_title < <(JSON.getval '' edited_channel_post.audio.title)
								readarray -t edited_channel_post_audio_mime_type < <(JSON.getval '' edited_channel_post.audio.mime_type)
								readarray -t edited_channel_post_audio_file_size < <(JSON.getval '' edited_channel_post.audio.file_size)
								;;
							'document')
								readarray -t edited_channel_post_document_file_id < <(JSON.getval '' edited_channel_post.document.file_id)
								readarray -t edited_channel_post_document_file_name < <(JSON.getval '' edited_channel_post.document.file_name)
								readarray -t edited_channel_post_document_mime_type < <(JSON.getval '' edited_channel_post.document.mime_type)
								readarray -t edited_channel_post_document_file_size < <(JSON.getval '' edited_channel_post.document.file_size)
								;;
							'photo')
					
								__TOTAL_PHOTO__=$(JSON.getval '' "edited_channel_post.photo|length" | head -n1)
	
								readarray -t edited_channel_post_photo_file_id < <(JSON.getval '' edited_channel_post.photo[$((__TOTAL_PHOTO__-1))].file_id)
								readarray -t edited_channel_post_photo_width < <(JSON.getval '' edited_channel_post.photo[$((__TOTAL_PHOTO__-1))].width)
								readarray -t edited_channel_post_photo_height < <(JSON.getval '' edited_channel_post.photo[$((__TOTAL_PHOTO__-1))].height)
								readarray -t edited_channel_post_photo_file_size < <(JSON.getval '' edited_channel_post.photo[$((__TOTAL_PHOTO__-1))].file_size)
								;;
							'sticker')
								readarray -t edited_channel_post_sticker_file_id < <(JSON.getval '' edited_channel_post.sticker.file_id)
								readarray -t edited_channel_post_sticker_width < <(JSON.getval '' edited_channel_post.sticker.width)
								readarray -t edited_channel_post_sticker_height < <(JSON.getval '' edited_channel_post.sticker.height)
								readarray -t edited_channel_post_sticker_emoji < <(JSON.getval '' edited_channel_post.sticker.emoji)
								readarray -t edited_channel_post_sticker_file_size < <(JSON.getval '' edited_channel_post.sticker.file_size)
								;;
							'video')
								readarray -t edited_channel_post_video_file_id < <(JSON.getval '' edited_channel_post.video.file_id)
								readarray -t edited_channel_post_video_width < <(JSON.getval '' edited_channel_post.video.width)
								readarray -t edited_channel_post_video_height < <(JSON.getval '' edited_channel_post.video.height)
								readarray -t edited_channel_post_video_duration < <(JSON.getval '' edited_channel_post.video.duration)
								readarray -t edited_channel_post_video_mime_type < <(JSON.getval '' edited_channel_post.video.mime_type)
								readarray -t edited_channel_post_video_file_size < <(JSON.getval '' edited_channel_post.video.file_size)
								;;
							'voice')
								readarray -t edited_channel_post_voice_file_id < <(JSON.getval '' edited_channel_post.voice.file_id)
								readarray -t edited_channel_post_voice_duration < <(JSON.getval '' edited_channel_post.voice.duration)
								readarray -t edited_channel_post_voice_mime_type < <(JSON.getval '' edited_channel_post.voice.mime_type)
								readarray -t edited_channel_post_voice_file_size < <(JSON.getval '' edited_channel_post.voice.file_size)
								;;
							'caption')
								readarray -t edited_channel_post_caption < <(JSON.getval '' edited_channel_post.caption)
								;;
							'contact')
								readarray -t edited_channel_post_contact_phone_number	< <(JSON.getval '' edited_channel_post.contact.phone_number)
								readarray -t edited_channel_post_contact_first_name < <(JSON.getval '' edited_channel_post.contact.first_name)
								readarray -t edited_channel_post_contact_last_name < <(JSON.getval '' edited_channel_post.contact.last_name)
								readarray -t edited_channel_post_contact_user_id < <(JSON.getval '' edited_channel_post.contact.user_id)
								;;
							'location')
								readarray -t edited_channel_post_location_longitude < <(JSON.getval '' edited_channel_post.location.longitude)
								readarray -t edited_channel_post_location_latitude < <(JSON.getval '' edited_channel_post.location.latitude)
								;;
							'venue')
								readarray -t edited_channel_post_venue_location_longitude < <(JSON.getval '' edited_channel_post.venue.location longitude)
								readarray -t edited_channel_post_venue_location_latitude < <(JSON.getval '' edited_channel_post.venue.location latitude)
								readarray -t edited_channel_post_venue_title < <(JSON.getval '' edited_channel_post.venue.title)
								readarray -t edited_channel_post_venue_address < <(JSON.getval '' edited_channel_post.venue.address)
								readarray -t edited_channel_post_venue_foursquare_id < <(JSON.getval '' edited_channel_post.venue.foursquare_id)
								;;
							'new_chat_member')
								readarray -t edited_channel_post_new_chat_member_id < <(JSON.getval '' edited_channel_post.new_chat_member.id)
								readarray -t edited_channel_post_new_chat_member_first_name < <(JSON.getval '' edited_channel_post.new_chat_member.first_name)
								readarray -t edited_channel_post_new_chat_member_last_name < <(JSON.getval '' edited_channel_post.new_chat_member.last_name)
								readarray -t edited_channel_post_new_chat_member_username < <(JSON.getval '' edited_channel_post.new_chat_member.username)
								;;
							'left_chat_member')
								readarray -t edited_channel_post_left_chat_member_id < <(JSON.getval '' edited_channel_post.left_chat_member.id)
								readarray -t edited_channel_post_left_chat_member_first_name < <(JSON.getval '' edited_channel_post.left_chat_member.first_name)
								readarray -t edited_channel_post_left_chat_member_last_name < <(JSON.getval '' edited_channel_post.left_chat_member.last_name)
								readarray -t edited_channel_post_left_chat_member_username < <(JSON.getval '' edited_channel_post.left_chat_member.username)
								;;
							'new_chat_title')
								readarray -t edited_channel_post_new_chat_title < <(JSON.getval '' edited_channel_post.new_chat_title)
								;;
							'photo')
					
								__TOTAL_PHOTO__=$(JSON.getval '' "edited_channel_post.new_chat_photo|length" | head -n1)
	
								readarray -t edited_channel_post_new_chat_photo_file_id < <(JSON.getval '' edited_channel_post.new_chat_photo[$((__TOTAL_PHOTO__-1))].file_id)
								readarray -t edited_channel_post_new_chat_photo_width < <(JSON.getval '' edited_channel_post.new_chat_photo[$((__TOTAL_PHOTO__-1))].width)
								readarray -t edited_channel_post_new_chat_photo_height < <(JSON.getval '' edited_channel_post.new_chat_photo[$((__TOTAL_PHOTO__-1))].height)
								readarray -t edited_channel_post_new_chat_photo_file_size < <(JSON.getval '' edited_channel_post.new_chat_photo[$((__TOTAL_PHOTO__-1))].file_size)
								readarray -t edited_channel_post_delete_chat_photo < <(JSON.getval '' edited_channel_post.delete_chat_photo)
								;;
							'group_chat_created')
								readarray -t edited_channel_post_group_chat_created < <(JSON.getval '' edited_channel_post.group_chat_created)
								;;
							'supergroup_chat_created')
								readarray -t edited_channel_post_supergroup_chat_created < <(JSON.getval '' edited_channel_post.supergroup_chat_created)
								;;
							'channel_chat_created')
								readarray -t edited_channel_post_channel_chat_created < <(JSON.getval '' edited_channel_post.channel_chat_created)
								;;
							'migrate_to_chat_id')
								readarray -t edited_channel_post_migrate_to_chat_id < <(JSON.getval '' edited_channel_post.migrate_to_chat_id)
								;;
							'migrate_from_chat_id')
								readarray -t edited_channel_post_migrate_from_chat_id < <(JSON.getval '' edited_channel_post.migrate_from_chat_id)
								;;
						esac
					done
					;;
				esac
			done
		else
			# Limpa todas as variáveis.
			unset update_id ${!message_*} ${!edited_message_*} ${!channel_post_*} ${!edited_channel_post_*} 
	fi

	# Status
	return $__ERR__
}

# Funções somente leitura
declare -rf JSON.result
declare -rf JSON.getval
declare -rf JSON.getstatus
declare -rf JSON.getkeys
declare -rf str.len
declare -rf message.error
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
declare -rf ShellBot.getUpdates
#FIM
