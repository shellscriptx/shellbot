#!/bin/bash

#-----------------------------------------------------------------------------------------------------------
#	Data:				16 de Junho de 2017
#	Script:				ShellBot.sh
#	Versão:				3.5
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
for _PKG_ in curl jq; do
	# Se estiver ausente, trata o erro e finaliza o script.
	if ! which $_PKG_ &>/dev/null; then
		echo "ShellBot.sh: erro: '$_PKG_' O pacote requerido não está instalando." 1>&2
		exit 1	# Status
	fi
done

# Verifica se a API já foi instanciada.
[[ $_INIT_ ]] && return 1

# Desabilitar globbing
set -f

declare -r _INIT_=1		# API inicializada.
declare -i _STATUS_=0	# Inicia sem erros.

# Arquivo JSON (JavaScript Object Notation) onde são gravados os objetos sempre que função getUpdates é chamada.
# O arquivo armazena os dados da atualização que serão acessados durante a execução de outros métodos; Onde o mesmo
# é sobrescrito sempre que um valor é retornado.
_JSON_=$(mktemp -q --tmpdir=/tmp --suffix=.json update-XXXXX) && \
declare -r _JSON_ || { echo "Falha ao tentar criar o arquivo JSON updates em '/tmp'." 1>&2; exit 1; } 

# Define a linha de comando para as chamadas GET e PUT do métodos da API via curl.
declare -r _GET_='curl --silent --request GET --url'
declare -r _POST_='curl --silent --request POST --url'
 
# Funções para extração dos objetos armazenados no arquivo "update.json"
# 
# Verifica o retorno após a chamada de um método, se for igual a true (sucesso) retorna 0, caso contrário, retorna 1
json() { jq -r "$*" $_JSON_ 2>/dev/null; }
json_status(){ [[ $(json '.ok') = true ]] && return 0 || return 1; }
# Extrai o comprimento da string removendo o caractere nova-linha (\n)
str_len(){ echo $(($(wc -c <<< "$*")-1)); return 0; }

# Remove arquivo JSON se o script for interrompido.
trap "rm -f $_JSON_ &>/dev/null; exit 1" SIGQUIT SIGINT SIGKILL SIGTERM SIGSTOP SIGPWR

# Erros registrados da API (Parâmetros/Argumentos)
declare -r _ERR_TYPE_BOOL_='tipo incompatível. Somente "true" ou "false".'
declare -r _ERR_TYPE_PARSE_MODE_='tipo incompatível. Somente "markdown" ou "html".'
declare -r _ERR_TYPE_INT_='tipo incompatível. Somente inteiro.'
declare -r _ERR_TYPE_FLOAT_='tipo incompatível. Somente float.'
declare -r _ERR_CAPTION_MAX_CHAR_='número máximo de caracteres excedido.'
declare -r _ERR_ACTION_MODE_='tipo da ação inválida.'
declare -r _ERR_PARAM_INVALID_='parâmetro inválido.'
declare -r _ERR_PARAM_REQUIRED_='parâmetro/argumento requerido.'
declare -r _ERR_TOKEN_='não autorizado. Verifique o número do TOKEN ou se possui privilégios.'
declare -r _ERR_FUNCTION_NOT_FOUND_='nome da função inválida ou não existe.'

# Trata os erros
message_error()
{
	# Variáveis locais
	local _ERR_MESSAGE_ _ERR_ARG_VALUE_ _ERR_PARAM_ _ERR_CODE_ _DESCRIPTION_ _EXIT_
	
	# A variável 'BASH_LINENO' é dinâmica e armazena o número da linha onde foi expandida.
	# Quando chamada dentro de um subshell, passa ser instanciada como um array, armazenando diversos
	# valores onde cada índice refere-se a um shell/subshell. As mesmas caracteristicas se aplicam a variável
	# 'FUNCNAME', onde é armazenado o nome da função onde foi chamada.
	local _LINE=${BASH_LINENO[$((${#BASH_LINENO[*]}-2))]}	# Obtem o número da linha no shell pai.
	local _FUNC=${FUNCNAME[$((${#FUNCNAME[*]}-2))]}			# Obtem o nome da função no shell pai.

	# Define a execução com a tag de erro.
	_STATUS_=1

	# Lê o tipo de ocorrência do erro.
	# TG - Erro externo, retornado pelo core do telegram
	# API - Erro interno, gerado pela API ShellBot.
	case $1 in
		TG)
			# Extrai as informações de erro no arquivo "update.json"
			_ERR_CODE_=$(json '.error_code')
			_DESCRIPTION_=$(json '.description')
			_ERR_MESSAGE_="${_ERR_CODE_:-1}: ${_DESCRIPTION_:-Ocorreu um problema durante a tentativa de atualização.}"
			;;
		API)
			# Define as variáveis com os valores passados na função "error.message"
			_ERR_PARAM_="$3"
			_ERR_ARG_VALUE_="$4"
			# Insere um '-', caso o valor de '_ERR_PARAM_' e '_ERR_ARG_VALUE_' for nulo; Se não houver
			# mensagem de erro, imprime 'Erro desconhecido'
			_ERR_MESSAGE_="${_ERR_PARAM_:--}: ${_ERR_ARG_VALUE_:--}: ${2:-Erro desconhecido}"
			_EXIT_=1
			;;
	esac
	
	# Imprime mensagem de erro
	echo "$(basename "$0"): linha ${_LINE:--}: ${_FUNC:-NULL}: ${_ERR_MESSAGE_}" 1>&2
	
	# Finaliza script em caso de erro interno, caso contrário retorna o valor $_STATUS_
	[[ $_EXIT_ ]] && exit 1 || return $_STATUS_
}

ShellBot.regHandleFunction()
{
	local _FUNCTION_ _CALLBACK_DATA_ _HANDLE_ _ARGS_

	local _PARAM_=$(getopt --quiet --options 'f:a:d:' \
									--longoptions 'function:,
													args:,
													callback_data:' \
													-- "$@")

	_STATUS_=0
	
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
	eval "$_HANDLE_(){ $_FUNCTION_ $_ARGS_; }"
	
	declare -Ag _LIST_REG_FUNC_HANDLE_
	_LIST_REG_FUNC_HANDLE_[$_CALLBACK_DATA_]+="$_HANDLE_ "

	return $_STATUS_
}

ShellBot.watchHandle()
{
	local 	_CALLBACK_DATA_ \
			_FUNC_HANDLE_ \
			_PARAM_=$(getopt --quiet --options 'd:' --longoptions '--callback_data:' -- "$@")

	_STATUS_=0
	
	eval set -- "$_PARAM_"

	while :
	do
		case $1 in
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
	
	# O parâmetro callback_data é parcial, ou seja, Se o handle for válido, os elementos
	# serão listados. Caso contrário a função é finalizada.
	[[ $_CALLBACK_DATA_ ]] || return 1

	# Lista todos os handles no índice _CALLBACK_DATA_  e executa-os
	# consecutivamente. A ordem de execução das funções é determinada
	# pela ordem de declaração.
	for _FUNC_HANDLE_ in ${_LIST_REG_FUNC_HANDLE_[$_CALLBACK_DATA_]}; do 
		$_FUNC_HANDLE_; done	# executa

	# retorno
	return $_STATUS_
}
	
# Inicializa o bot, definindo sua API e TOKEN.
# Atenção: Essa função precisa ser instanciada antes de qualquer outro método.
ShellBot.init()
{
	# Variável local
	local _PARAM_=$(getopt --quiet --options 't:' \
										--longoptions 'token:' \
										-- "$@")
	
	# Inicia a função sem erros
	_STATUS_=0

	# Define os parâmetros posicionais
	eval set -- "$_PARAM_"

	while :
	do
		case $1 in
			-t|--token)
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
	return $_STATUS_
}

# Um método simples para testar o token de autenticação do seu bot. 
# Não requer parâmetros. Retorna informações básicas sobre o bot em forma de um objeto Usuário.
ShellBot.getMe()
{
	# Variável local
	local _METHOD_=getMe	# Método
	
	# Inicia a função sem erros
	_STATUS_=0

	# Chama o método getMe passando o endereço da API, seguido do nome do método.
	eval $_GET_ $_API_TELEGRAM_/$_METHOD_ > $_JSON_
	
	# Verifica o status de retorno do método
	json_status || message_error TG

	# Retorna as informações armazenadas em "result".
	json '.result|.id,.username,.first_name,.last_name' | sed ':a;$!N;s/\n/|/;ta'
	
	# status
	return $_STATUS_

}

ShellBot.InlineKeyboardButton()
{
    local 	_BUTTON_ _LINE_ _TEXT_ _URL_ _CALLBACK_DATA_ \
            _SWITCH_INLINE_QUERY_ _SWITCH_INLINE_QUERY_CURRENT_CHAT_ \
			_DELM_

    local	_PARAM_=$(getopt --quiet --options 'b:l:t:u:c:q:s:' \
                                        --longoptions 'button:,
                                                        line:,
                                                        text:,
                                                        url:,
                                                        callback_data:,
                                                        switch_inline_query:,
                                                        switch_inline_query_chat:' \
                                                        -- "$@")

	# Sem erros
	_STATUS_=0

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
}" || _STATUS_=1	# Erro ao salvar o botão. 
	
	# Fecha o array
	_BUTTON_[$_LINE_]="${_BUTTON_[$_LINE_]/#/[}"
	_BUTTON_[$_LINE_]="${_BUTTON_[$_LINE_]/%/]}"

	# retorno
	return $_STATUS_
}

ShellBot.InlineKeyboardMarkup()
{
	local 	_BUTTON_ _TEMP_KB_ \
			_DEL_=false

    local 	_PARAM_=$(getopt --quiet --options 'b:d' --longoptions 'button:,delete' -- "$@")

	# Sem erros
	_STATUS_=0

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
			-d|--delete)
				_DEL_=true
				shift 1
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

	# Apaga o objeto teclado (se ele existir) e finaliza a função.
	[[ $_DEL_ = true ]] && { unset $_BUTTON_; return $_STATUS_; }


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
	
	_KEYBOARD_="${_BUTTON_[@]}" || _STATUS_=1 
	
	# Cria estrutura do teclado
	_KEYBOARD_="${_KEYBOARD_/#/{\"inline_keyboard\":[}"
	_KEYBOARD_="${_KEYBOARD_//]/],}"					
	_KEYBOARD_="${_KEYBOARD_%,}"						
	_KEYBOARD_="${_KEYBOARD_/%/]\}}"					

	# Retorna a estrutura	
	echo $_KEYBOARD_

	# status
	return $_STATUS_
}

ShellBot.answerCallbackQuery()
{
	local _CALLBACK_QUERY_ID_ _TEXT_ _SHOW_ALERT_ _URL_ _CACHE_TIME_
	local _METHOD_=answerCallbackQuery # Método
	local _PARAM_=$(getopt --quiet --options 'c:t:s:u:t:' \
										--longoptions 'callback_query_id:,
														text:,
														show_alert:,
														url:,
														cache_time:' \
														-- "$@")


	# Sem erros
	_STATUS_=0
	
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
			-t|--cache_time)
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

	json_status || message_error TG

	return $_STATUS_
														
}

# Cria objeto que representa um teclado personalizado com opções de resposta
ShellBot.ReplyKeyboardMarkup()
{
	# Variáveis locais
	local 	_BUTTON_ _RESIZE_KEYBOARD_ _ON_TIME_KEYBOARD_ _SELECTIVE_
	
	# Lê os parâmetros da função.
	local _PARAM_=$(getopt --quiet --options 'b:r:t:s:' \
										--longoptions 'button:,
														resize_keyboard:,
														one_time_keyboard:,
														selective:' \
														-- "$@")
	# Iniciliaza a função sem erros.
	_STATUS_=0
	
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
	return $_STATUS_
}

# Envia mensagens 
ShellBot.sendMessage()
{
	# Variáveis locais 
	local _CHAT_ID_ _TEXT_ _PARSE_MODE_ _DISABLE_WEB_PAGE_PREVIEW_ _DISABLE_NOTIFICATION_ _REPLY_TO_MESSAGE_ID_ _REPLY_MARKUP_
	local _METHOD_=sendMessage # Método
	
	# Lê os parâmetros da função
	local _PARAM_=$(getopt --quiet --options 'c:t:p:w:n:r:k:' \
										--longoptions 'chat_id:,
														text:,
														parse_mode:,
														disable_web_page_preview:,
														disable_notification:,
														reply_to_message_id:,
														reply_markup:' \
														-- "$@")

	# Sem erros
	_STATUS_=0
	
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
	json_status || message_error TG
	
	# Status
	return $_STATUS_
}

# Função para reencaminhar mensagens de qualquer tipo.
ShellBot.forwardMessage()
{
	# Variáveis locais
	local _CHAT_ID_ _FORM_CHAT_ID_ _DISABLE_NOTIFICATION_ _MESSAGE_ID_
	local _METHOD_=forwardMessage # Método
	
	# Lê os parâmetros da função
	local _PARAM_=$(getopt --quiet --options 'c:f:n:m:' \
										--longoptions 'chat_id:,
														from_chat_id:,
														disable_notification:,
														message_id:' \
														-- "$@")

	# Sem erros
	_STATUS_=0
	
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
	json_status || message_error TG

	# status
	return $_STATUS_
}

# Utilize essa função para enviar fotos.
ShellBot.sendPhoto()
{
	# Variáveis locais
	local _CHAT_ID_ _PHOTO_ _CAPTION_ _DISABLE_NOTIFICATION_ _REPLY_TO_MESSAGE_ID_ _REPLY_MARKUP_
	local _METHOD_=sendPhoto	# Método

	# Lê os parâmetros da função
	local _PARAM_=$(getopt --quiet --options 'c:p:t:n:r:k:' \
										--longoptions 'chat_id:, 
														photo:,
														caption:,
														disable_notification:,
														reply_to_message_id:,
														reply_markup:' \
														-- "$@")


	# Sem erros
	_STATUS_=0
	
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
				[ $(str_len "$2") -gt 200 ] && message_error API "$_ERR_CAPTION_MAX_CHAR_" "$1" 
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
	json_status || message_error TG

	# Status
	return $_STATUS_
}

# Utilize essa função para enviar arquivos de audio.
ShellBot.sendAudio()
{
	# Variáveis locais
	local _CHAT_ID_ _AUDIO_ _CAPTION_ _DURATION_ _PERFORMER_ _TITLE_ _DISABLE_NOTIFICATION_ _REPLY_TO_MESSAGE_ID_ _REPLY_MARKUP_	
	local _METHOD_=sendAudio	# Método
	
	# Lê os parâmetros da função
	local _PARAM_=$(getopt --quiet --options 'c:a:t:d:e:i:n:r:k' \
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
	_STATUS_=0
	
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
	json_status || message_error TG

	# Status
	return $_STATUS_
		
}

# Utilize essa função para enviar documentos.
ShellBot.sendDocument()
{
	# Variáveis locais
	local _CHAT_ID_ _DOCUMENT_ _CAPTION_ _DISABLE_NOTIFICATION_ _REPLY_TO_MESSAGE_ID_ _REPLY_MARKUP_
	local _METHOD_=sendDocument	# Método
	
	# Lê os parâmetros da função
	local _PARAM_=$(getopt --quiet --options 'c:d:t:n:r:k:' \
										--longoptions 'chat_id:,
														document:,
														caption:,
														disable_notification:,
														reply_to_message_id:,
														reply_markup:' \
														-- "$@")

	# Sem erros
	_STATUS_=0
	
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
	json_status || message_error TG

	# Status
	return $_STATUS_
	
}

# Utilize essa função para enviat stickers
ShellBot.sendSticker()
{
	# Variáveis locais
	local _CHAT_ID_ _STICKER_ _DISABLE_NOTIFICATION_ _REPLY_TO_MESSAGE_ID_ _REPLY_MARKUP_
	local _METHOD_=sendSticker	# Método

	# Lê os parâmetros da função
	local _PARAM_=$(getopt --quiet --options 'c:s:n:r:k:' \
										--longoptions 'chat_id:,
														sticker:,
														disable_notification:,
														reply_to_message_id:,
														reply_markup:' \
														-- "$@")

	# Sem erros
	_STATUS_=0
	
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
	json_status || message_error TG

	# Status
	return $_STATUS_
}

# Função para enviar arquivos de vídeo.
ShellBot.sendVideo()
{
	# Variáveis locais
	local _CHAT_ID_ _VIDEO_ _DURATION_ _WIDTH_ _HEIGHT_ _CAPTION_ _DISABLE_NOTIFICATION_ _REPLY_TO_MESSAGE_ID_ _REPLY_MARKUP_
	local _METHOD_=sendVideo	# Método

	# Lê os parâmetros da função
	local _PARAM_=$(getopt --quiet --options 'c:v:d:w:h:t:n:r:k:' \
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
	_STATUS_=0
	
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
	json_status || message_error TG

	# Status
	return $_STATUS_
	
}

# Função para enviar audio.
ShellBot.sendVoice()
{
	# Variáveis locais
	local _CHAT_ID_ _VOICE_ _CAPTION_ _DURATION_ _DISABLE_NOTIFICATION_ _REPLY_TO_MESSAGE_ID_ _REPLY_MARKUP_
	local _METHOD_=sendVoice	# Método

	# Lê os parâmetros da função
	local _PARAM_=$(getopt --quiet --options 'c:v:t:d:n:r:k:' \
										--longoptions 'chat_id:,
														voice:,
														caption:,
														duration:,
														disable_notification:,
														reply_to_message_id:,
														reply_markup:' \
														-- "$@")

	# Sem erros
	_STATUS_=0
	
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
	json_status || message_error TG

	# Status
	return $_STATUS_
	
}

# Função utilizada para enviar uma localidade utilizando coordenadas de latitude e longitude.
ShellBot.sendLocation()
{
	# Variáveis locais
	local _CHAT_ID_ _LATITUDE_ _LONGITUDE_ _DISABLE_NOTIFICATION_ _REPLY_TO_MESSAGE_ID_ _REPLY_MARKUP_
	local _METHOD_=sendLocation	# Método

	# Lê os parâmetros da função
	local _PARAM_=$(getopt --quiet --options 'c:l:g:n:r:k:' \
										--longoptions 'chat_id:,
														latitude:,
														longitude:,
														disable_notification:,
														reply_to_message_id:,
														reply_markup:' \
														-- "$@")

	# Sem erros
	_STATUS_=0
	
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
	json_status || message_error TG

	return $_STATUS_
	
}

# Função utlizada para enviar detalhes de um local.
ShellBot.sendVenue()
{
	# Variáveis locais
	local _CHAT_ID_ _LATITUDE_ _LONGITUDE_ _TITLE_ _ADDRESS_ _FOURSQUARE_ID_ _DISABLE_NOTIFICATION_ _REPLY_TO_MESSAGE_ID_ _REPLY_MARKUP_
	local _METHOD_=sendVenue	# Método
	
	# Lê os parâmetros da função
	local _PARAM_=$(getopt --quiet --options 'c:l:g:i:a:f:n:r:k:' \
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
	_STATUS_=0
	
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
	json_status || message_error TG

	# Status
	return $_STATUS_
}

# Utilize essa função para enviar um contato + numero
ShellBot.sendContact()
{
	# Variáveis locais
	local _CHAT_ID_ _PHONE_NUMBER_ _FIRST_NAME_ _LAST_NAME_ _DISABLE_NOTIFICATION_ _REPLY_TO_MESSAGE_ID_ _REPLY_MARKUP_
	local _METHOD_=sendContact	# Método
	
	# Lê os parâmetros da função
	local _PARAM_=$(getopt --quiet --options 'c:p:f:l:n:r:k:' \
										--longoptions 'chat_id:,
														phone_number:,
														first_name:,
														last_name:,
														disable_notification:,
														reply_to_message_id:,
														reply_markup:' \
														-- "$@")


	# Sem erros
	_STATUS_=0
	
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
	json_status || message_error TG

	# Status
	return $_STATUS_
}

# Envia uma ação para bot.
ShellBot.sendChatAction()
{
	# Variáveis locais
	local _CHAT_ID_ _ACTION_
	local _METHOD_=sendChatAction		# Método
	
	# Lê os parâmetros da função
	local _PARAM_=$(getopt --quiet --options 'c:a:' \
										--longoptions 'chat_id:,
														action:' \
														-- "$@")

	# Sem erros
	_STATUS_=0

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
	json_status || message_error TG

	# Status
	return $_STATUS_
}

# Utilize essa função para obter as fotos de um determinado usuário.
ShellBot.getUserProfilePhotos()
{
	# Variáveis locais 
	local _USER_ID_ _OFFSET_ _LIMIT_ _IND_ _TOTAL_ _LAST_ _INDEX_ _MAX_ _ITEM_
	local _METHOD_=getUserProfilePhotos # Método
	
	# Lê os parâmetros da função
	local _PARAM_=$(getopt --quiet --options 'u:o:l:' \
										--longoptions 'user_id:,
														offset:,
														limit:' \
														-- "$@")

	# Sem erros
	_STATUS_=0

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
	json_status || message_error TG


	_TOTAL_=$(json '.result.total_count')

	if [ $_TOTAL_ -gt 0 ]; then	
		for _INDEX_ in $(seq 0 $((_TOTAL_-1)))
		do
			_MAX_=$(json ".result.photos[$_INDEX_]|length")
			for _ITEM_ in $(seq 0 $((_MAX_-1)))
			do
				json ".result.photos[$_INDEX_][$_ITEM_]|.file_id, .file_size, .width, .height" | sed ':a;$!N;s/\n/|/;ta'
			done
		done
	else
		echo null
	fi

	# Status
	return $_STATUS_
}

# Função para listar informações do arquivo especificado.
ShellBot.getFile()
{
	# Variáveis locais
	local _FILE_ID_
	local _METHOD_=getFile # Método

	# Lê os parâmetros da função
	local _PARAM_=$(getopt --quiet --options 'f:' \
										--longoptions 'file_id:' \
														-- "$@")

	# Sem erros
	_STATUS_=0

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
	json_status || message_error TG

	# Extrai as informações, agrupando-as em uma única linha e insere o delimitador '|' PIPE entre os campos.
	json '.result|.file_id, .file_size, .file_path' | sed ':a;$!N;s/\n/|/;ta'

	# Status
	return $_STATUS_
}		

# Essa função kicka o usuário do chat ou canal. (somente administradores)
ShellBot.kickChatMember()
{
	# Variáveis locais
	local _CHAT_ID_ _USER_ID_
	local _METHOD_=kickChatMember		# Método

	# Lê os parâmetros da função
	local _PARAM_=$(getopt --quiet --options 'c:u:' \
										--longoptions 'chat_id:,
														user_id:' \
														-- "$@")

	# Sem erros
	_STATUS_=0

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
												${_USER_ID_:+-d user_id="'$_USER_ID_'"} > $_JSON_

	# Verifica se ocorreu erros durante a chamada do método	
	json_status || message_error TG

	# Status
	return $_STATUS_
}

# Utilize essa função para remove o bot do grupo ou canal.
ShellBot.leaveChat()
{
	# Variáveis locais
	local _CHAT_ID_
	local _METHOD_=leaveChat	# Método

	# Lê os parâmetros da função
	local _PARAM_=$(getopt --quiet --options 'c:' \
										--longoptions 'chat_id:' \
														-- "$@")

	
	_STATUS_=0

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
	json_status || message_error TG

	return $_STATUS_
	
}

ShellBot.unbanChatMember()
{
	local _CHAT_ID_ _USER_ID_

	# Lê os parâmetros da função
	local _PARAM_=$(getopt --quiet --options 'c:u:' \
										--longoptions 'chat_id:,
														user_id:' \
														-- "$@")

	local _METHOD_=unbanChatMember
	
	_STATUS_=0

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
	json_status || message_error TG

	return $_STATUS_
}

ShellBot.getChat()
{
	# Variáveis locais
	local _CHAT_ID_
	local _METHOD_=getChat	# Método

	# Lê os parâmetros da função
	local _PARAM_=$(getopt --quiet --options 'c:' \
										--longoptions 'chat_id:' \
														-- "$@")

	
	_STATUS_=0

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
	json_status || message_error TG

	# Imprime os dados.
	json '.result|.id, .username, .type, .title' |  sed ':a;$!N;s/\n/|/;ta'
	
	# Status
	return $_STATUS_
}

ShellBot.getChatAdministrators()
{
	local _CHAT_ID_ _TOTAL_ _KEY_ _INDEX_

	# Lê os parâmetros da função
	local _PARAM_=$(getopt --quiet --options 'c:' \
										--longoptions 'chat_id:' \
														-- "$@")

	local _METHOD_=getChatAdministrators
	
	_STATUS_=0

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
	json_status || message_error TG

	# Total de administratores
	declare -i _TOTAL_=$(json '.result|length')

	# Lê os administradores do grupo se houver.
	if [ $_TOTAL_ -gt 0 ]; then
		for _INDEX_ in $(seq 0 $((_TOTAL_-1)))
		do
			# Lê as informações do usuário armazenadas em '_INDEX_'.
			json ".result[$_INDEX_]|.user.id, .user.username, .user.first_name, .user.last_name, .status" | sed ':a;$!N;s/\n/|/;ta'
		done
	else
		# Retorna 'null' se o grupo não possui administradores.
		echo null
	fi

	# Status	
	return $_STATUS_
}

ShellBot.getChatMembersCount()
{
	local _CHAT_ID_

	# Lê os parâmetros da função
	local _PARAM_=$(getopt --quiet --options 'c:' \
										--longoptions 'chat_id:' \
														-- "$@")

	local _METHOD_=getChatMembersCount
	
	_STATUS_=0

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
	json_status || message_error TG

	json '.result'

	return $_STATUS_
}

ShellBot.getChatMember()
{
	# Variáveis locais
	local _CHAT_ID_ _USER_ID_
	local _METHOD_=getChatMember	# Método

	# Lê os parâmetros da função
	local _PARAM_=$(getopt --quiet --options 'c:u:' \
										--longoptions 'chat_id:,
														user_id:' \
														-- "$@")

	
	_STATUS_=0

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
	json_status || message_error TG
	
	json '.result| .user.id, .user.username, .user.first_name, .user.last_name, .status' | sed ':a;$!N;s/\n/|/;ta'
	
	return $_STATUS_
}

ShellBot.editMessageText()
{
	local _CHAT_ID_ _MESSAGE_ID_ _INLINE_MESSAGE_ID_ _TEXT_ _PARSE_MODE_ _DISABLE_WEB_PAGE_PREVIEW_ _REPLY_MARKUP_
	local _METHOD_=editMessageText
	
	local _PARAM_=$(getopt --quiet --options 'c:m:i:t:p:w:r:' \
										--longoptions 'chat_id:,
														message_id:,
														inline_message_id:,
														text:,
														parse_mode:,
														disable_web_page_preview:,
														reply_markup:' \
														-- "$@")
	
	_STATUS_=0

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
	json_status || message_error TG
	
	return $_STATUS_
	
}

ShellBot.editMessageCaption()
{
	local _CHAT_ID_ _MESSAGE_ID_ _INLINE_MESSAGE_ID_ _CAPTION_ _REPLY_MARKUP_
	local _METHOD_=editMessageCaption
	
	local _PARAM_=$(getopt --quiet --options 'c:m:i:t:r:' \
										--longoptions 'chat_id:,
														message_id:,
														inline_message_id:,
														caption:,
														reply_markup:' \
														-- "$@")
	
	_STATUS_=0

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
	json_status || message_error TG
	
	return $_STATUS_
	
}

ShellBot.editMessageReplyMarkup()
{
	local _CHAT_ID_ _MESSAGE_ID_ _INLINE_MESSAGE_ID_ _REPLY_MARKUP_
	local _METHOD_=editMessageReplyMarkup
	
	local _PARAM_=$(getopt --quiet --options 'c:m:i:r:' \
										--longoptions 'chat_id:,
														message_id:,
														inline_message_id:,
														reply_markup:' \
														-- "$@")
	
	_STATUS_=0

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
	json_status || message_error TG
	
	return $_STATUS_
	
}

ShellBot.deleteMessage()
{
	local _CHAT_ID_ _MESSAGE_ID_
	local _METHOD_=deleteMessage
	
	local _PARAM_=$(getopt --quiet --options 'c:m' \
										--longoptions 'chat_id:,
														message_id:' \
														-- "$@")
	
	_STATUS_=0

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
	json_status || message_error TG
	
	return $_STATUS_

}


ShellBot.getUpdates()
{
	local -i _TOTAL_KEYS_ _TOTAL_PHOTO_ _OFFSET_ _LIMIT_ _TIMEOUT_ _ALLOWED_UPDATES_
	local _KEY_ _SUBKEY_ _UPDATE_

	local _METHOD_=getUpdates	# Mètodo

	# Define os parâmetros da função
	local _PARAM_=$(getopt  --quiet --options 'o:l:t:a:' \
										--longoptions 'offset:,
														limit:,
														timeout:,
														allowed_updates:' \
														-- "$@")

	
	_STATUS_=0

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

	# Verifica se ocorreu erros durante a chamada do método	
	json_status || message_error TG
	
	# Limpa todas as variáveis.
	unset update_id ${!message_*} ${!edited_message_*} ${!channel_post_*} ${!edited_channel_post_*} ${!callback_query_*}

	# Total de atualizações
	_TOTAL_KEYS_=$(json '.result|length')

	if [ $_TOTAL_KEYS_ -gt 0 ]; then

		for _INDEX_ in $(seq 0 $((_TOTAL_KEYS_-1)))
		do
			_UPDATE_=".result[$_INDEX_]"

			for _KEY_ in $(json "$_UPDATE_|keys|.[]")
			do
				case $_KEY_ in
					'update_id')
						# UPDATE_ID
						update_id[$_INDEX_]=$(json "$_UPDATE_.update_id")
						;;
					'message')
						# MESSAGE
						for _SUBKEY_ in $(json "$_UPDATE_.$_KEY_|keys|.[]")
						do
							case $_SUBKEY_ in
								'message_id')
									# MESSAGE_ID
									message_message_id[$_INDEX_]="$(json $_UPDATE_.message.message_id)"
									;;
								'from')
								# FROM
									 message_from_id[$_INDEX_]="$(json $_UPDATE_.message.from.id)"
									 message_from_first_name[$_INDEX_]="$(json $_UPDATE_.message.from.first_name)"
									 message_from_last_name[$_INDEX_]="$(json $_UPDATE_.message.from.last_name)"
									 message_from_username[$_INDEX_]="$(json $_UPDATE_.message.from.username)"
									;;
								'date')
									# DATE
									 message_date[$_INDEX_]="$(json $_UPDATE_.message.date)"
									;;
								'chat')
									# CHAT
									 message_chat_id[$_INDEX_]="$(json $_UPDATE_.message.chat.id)"
									 message_chat_type[$_INDEX_]="$(json $_UPDATE_.message.chat.type)"
									 message_chat_title[$_INDEX_]="$(json $_UPDATE_.message.chat.title)"
									 message_chat_username[$_INDEX_]="$(json $_UPDATE_.message.chat.username)"
									 message_chat_first_name[$_INDEX_]="$(json $_UPDATE_.message.chat.first_name)"
									 message_chat_last_name[$_INDEX_]="$(json $_UPDATE_.message.chat.last_name)"
									 message_chat_all_members_are_administrators[$_INDEX_]="$(json $_UPDATE_.message.chat.all_members_are_administrators)"
									;;
								'forward_from')
									# FORWARD_FROM
									 message_forward_from_id[$_INDEX_]="$(json $_UPDATE_.message.forward_from.id)"
									 message_forward_from_first_name[$_INDEX_]="$(json $_UPDATE_.message.forward_from.first_name)"
									 message_forward_from_last_name[$_INDEX_]="$(json $_UPDATE_.message.forward_from.last_name)"
									 message_forward_from_username[$_INDEX_]="$(json $_UPDATE_.message.forward_from.username)"
						
									 message_forward_from_chat_id[$_INDEX_]="$(json $_UPDATE_.message.forward_from_chat.id)"
									 message_forward_from_chat_type[$_INDEX_]="$(json $_UPDATE_.message.forward_from_chat.type)"
									 message_forward_from_chat_title[$_INDEX_]="$(json $_UPDATE_.message.forward_from_chat.title)"
									 message_forward_from_chat_username[$_INDEX_]="$(json $_UPDATE_.message.forward_from_chat.username)"
									 message_forward_from_chat_first_name[$_INDEX_]="$(json $_UPDATE_.message.forward_from_chat.first_name)"
									 message_forward_from_chat_last_name[$_INDEX_]="$(json $_UPDATE_.message.forward_from_chat.last_name)"
									 message_forward_from_chat_all_members_are_administrators[$_INDEX_]="$(json $_UPDATE_.message.forward_from_chat.all_members_are_administrators)"
									 message_forward_from_message_id[$_INDEX_]="$(json $_UPDATE_.message.forward_from_message_id)"
									;;
								'forward_date')
									 message_forward_date[$_INDEX_]="$(json $_UPDATE_.message.forward_date)"
									;;
									# REPLY_TO_MESSAGE
								'reply_to_message')
									 message_reply_to_message_message_id[$_INDEX_]="$(json $_UPDATE_.message.reply_to_message.message_id)"
									 message_reply_to_message_from_id[$_INDEX_]="$(json $_UPDATE_.message.reply_to_message.from.id)"
									 message_reply_to_message_from_username[$_INDEX_]="$(json $_UPDATE_.message.reply_to_message.from.username)"
									 message_reply_to_message_from_first_name[$_INDEX_]="$(json $_UPDATE_.message.reply_to_message.from.first_name)"
									 message_reply_to_message_from_last_name[$_INDEX_]="$(json $_UPDATE_.message.reply_to_message.from.last_name)"
									 message_reply_to_message_date[$_INDEX_]="$(json $_UPDATE_.message.reply_to_message.date)"
									 message_reply_to_message_chat_id[$_INDEX_]="$(json $_UPDATE_.message.reply_to_message.chat.id)"
									 message_reply_to_message_chat_type[$_INDEX_]="$(json $_UPDATE_.message.reply_to_message.chat.type)"
									 message_reply_to_message_chat_title[$_INDEX_]="$(json $_UPDATE_.message.reply_to_message.chat.title)"
									 message_reply_to_message_chat_username[$_INDEX_]="$(json $_UPDATE_.message.reply_to_message.chat.username)"
									 message_reply_to_message_chat_first_name[$_INDEX_]="$(json $_UPDATE_.message.reply_to_message.chat.first_name)"
									 message_reply_to_message_chat_last_name[$_INDEX_]="$(json $_UPDATE_.message.reply_to_message.chat.last_name)"
									 message_reply_to_message_chat_all_members_are_administrators[$_INDEX_]="$(json $_UPDATE_.message.reply_to_message.chat.all_members_are_administrators)"
									 message_reply_to_message_forward_from_message_id[$_INDEX_]="$(json $_UPDATE_.message.reply_to_message.forward_from_message_id)"
									 message_reply_to_message_forward_date[$_INDEX_]="$(json $_UPDATE_.message.reply_to_message.forward_date)"
									 message_reply_to_message_edit_date[$_INDEX_]="$(json $_UPDATE_.message.reply_to_message.edit_date)"
									 message_reply_to_message_text[$_INDEX_]="$(json $_UPDATE_.message.reply_to_message.text)"
									;;
								'text')
									# TEXT
									 message_text[$_INDEX_]="$(json $_UPDATE_.message.text)"
									;;
								'entities')
									# ENTITIES
									 message_entities_type[$_INDEX_]="$(json $_UPDATE_.message.entities[].type)"
									 message_entities_offset[$_INDEX_]="$(json $_UPDATE_.message.entities[].offset)"
									 message_entities_length[$_INDEX_]="$(json $_UPDATE_.message.entities[].length)"
									 message_entities_url[$_INDEX_]="$(json $_UPDATE_.message.entities[].url)"
									;;
								'audio')
									# AUDIO
									 message_audio_file_id[$_INDEX_]="$(json $_UPDATE_.message.audio.file_id)"
									 message_audio_duration[$_INDEX_]="$(json $_UPDATE_.message.audio.duration)"
									 message_audio_performer[$_INDEX_]="$(json $_UPDATE_.message.audio.performer)"
									 message_audio_title[$_INDEX_]="$(json $_UPDATE_.message.audio.title)"
									 message_audio_mime_type[$_INDEX_]="$(json $_UPDATE_.message.audio.mime_type)"
									 message_audio_file_size[$_INDEX_]="$(json $_UPDATE_.message.audio.file_size)"
					
									 message_document_file_id[$_INDEX_]="$(json $_UPDATE_.message.document.file_id)"
									 message_document_file_name[$_INDEX_]="$(json $_UPDATE_.message.document.file_name)"
									 message_document_mime_type[$_INDEX_]="$(json $_UPDATE_.message.document.mime_type)"
									 message_document_file_size[$_INDEX_]="$(json $_UPDATE_.message.document.file_size)"
									;;
								'photo')
									_TOTAL_PHOTO_=$(json "$_UPDATE_.message.photo|length" | head -n1)
	
									 message_photo_file_id[$_INDEX_]="$(json $_UPDATE_.message.photo[$((_TOTAL_PHOTO_-1))].file_id)"
									 message_photo_width[$_INDEX_]="$(json $_UPDATE_.message.photo[$((_TOTAL_PHOTO_-1))].width)"
									 message_photo_height[$_INDEX_]="$(json $_UPDATE_.message.photo[$((_TOTAL_PHOTO_-1))].height)"
									 message_photo_file_size[$_INDEX_]="$(json $_UPDATE_.message.photo[$((_TOTAL_PHOTO_-1))].file_size)"
									;;
								'sticker')
									# STICKER
									 message_sticker_file_id[$_INDEX_]="$(json $_UPDATE_.message.sticker.file_id)"
									 message_sticker_width[$_INDEX_]="$(json $_UPDATE_.message.sticker.width)"
									 message_sticker_height[$_INDEX_]="$(json $_UPDATE_.message.sticker.height)"
									 message_sticker_emoji[$_INDEX_]="$(json $_UPDATE_.message.sticker.emoji)"
									 message_sticker_file_size[$_INDEX_]="$(json $_UPDATE_.message.sticker.file_size)"
									;;
								'video')
									# VIDEO
									 message_video_file_id[$_INDEX_]="$(json $_UPDATE_.message.video.file_id)"
									 message_video_width[$_INDEX_]="$(json $_UPDATE_.message.video.width)"
									 message_video_height[$_INDEX_]="$(json $_UPDATE_.message.video.height)"
									 message_video_duration[$_INDEX_]="$(json $_UPDATE_.message.video.duration)"
									 message_video_mime_type[$_INDEX_]="$(json $_UPDATE_.message.video.mime_type)"
									 message_video_file_size[$_INDEX_]="$(json $_UPDATE_.message.video.file_size)"
									;;
								'voice')
									# VOICE
									 message_voice_file_id[$_INDEX_]="$(json $_UPDATE_.message.voice.file_id)"
									 message_voice_duration[$_INDEX_]="$(json $_UPDATE_.message.voice.duration)"
									 message_voice_mime_type[$_INDEX_]="$(json $_UPDATE_.message.voice.mime_type)"
									 message_voice_file_size[$_INDEX_]="$(json $_UPDATE_.message.voice.file_size)"
									;;
								'caption')
									# CAPTION - DOCUMENT, PHOTO ou VIDEO
									 message_caption[$_INDEX_]="$(json $_UPDATE_.message.caption)"
									;;
								'contact')
									# CONTACT
									 message_contact_phone_number[$_INDEX_]="$(json $_UPDATE_.message.contact.phone_number)"
									 message_contact_first_name[$_INDEX_]="$(json $_UPDATE_.message.contact.first_name)"
									 message_contact_last_name[$_INDEX_]="$(json $_UPDATE_.message.contact.last_name)"
									 message_contact_user_id[$_INDEX_]="$(json $_UPDATE_.message.contact.user_id)"
									;;
								'location')
									# LOCATION
									 message_location_longitude[$_INDEX_]="$(json $_UPDATE_.message.location.longitude)"
									 message_location_latitude[$_INDEX_]="$(json $_UPDATE_.message.location.latitude)"
									;;
								'venue')
									# VENUE
									 message_venue_location_longitude[$_INDEX_]="$(json $_UPDATE_.message.venue.location[].longitude)"
									 message_venue_location_latitude[$_INDEX_]="$(json $_UPDATE_.message.venue.location[].latitude)"
									 message_venue_title[$_INDEX_]="$(json $_UPDATE_.message.venue.title)"
									 message_venue_address[$_INDEX_]="$(json $_UPDATE_.message.venue.address)"
									 message_venue_foursquare_id[$_INDEX_]="$(json $_UPDATE_.message.venue.foursquare_id)"
									;;
								'new_chat_member')
									# NEW_MEMBER
									 message_new_chat_member_id[$_INDEX_]="$(json $_UPDATE_.message.new_chat_member.id)"
									 message_new_chat_member_first_name[$_INDEX_]="$(json $_UPDATE_.message.new_chat_member.first_name)"
									 message_new_chat_member_last_name[$_INDEX_]="$(json $_UPDATE_.message.new_chat_member.last_name)"
									 message_new_chat_member_username[$_INDEX_]="$(json $_UPDATE_.message.new_chat_member.username)"
									;;
								'left_chat_member')
									# LEFT_CHAT_MEMBER
									 message_left_chat_member_id[$_INDEX_]="$(json $_UPDATE_.message.left_chat_member.id)"
									 message_left_chat_member_first_name[$_INDEX_]="$(json $_UPDATE_.message.left_chat_member.first_name)"
									 message_left_chat_member_last_name[$_INDEX_]="$(json $_UPDATE_.message.left_chat_member.last_name)"
									 message_left_chat_member_username[$_INDEX_]="$(json $_UPDATE_.message.left_chat_member.username)"
									;;
								'new_chat_title')
									# NEW_CHAT_TITLE
									 message_new_chat_title[$_INDEX_]="$(json $_UPDATE_.message.new_chat_title)"
									;;
								'new_chat_photo')
									# NEW_CHAT_PHOTO
									_TOTAL_PHOTO_=$(json "$_UPDATE_.message.new_chat_photo|length" | head -n1)
					
									 message_new_chat_photo_file_id[$_INDEX_]="$(json $_UPDATE_.message.new_chat_photo[$((_TOTAL_PHOTO_-1))].file_id)"
									 message_new_chat_photo_width[$_INDEX_]="$(json $_UPDATE_.message.new_chat_photo[$((_TOTAL_PHOTO_-1))].width)"
									 message_new_chat_photo_height[$_INDEX_]="$(json $_UPDATE_.message.new_chat_photo[$((_TOTAL_PHOTO_-1))].height)"
									 message_new_chat_photo_file_size[$_INDEX_]="$(json $_UPDATE_.message.new_chat_photo[$((_TOTAL_PHOTO_-1))].file_size)"
									;;
								'delete_chat_photo')
									# DELETE_CHAT_PHOTO
									 message_delete_chat_photo[$_INDEX_]="$(json $_UPDATE_.message.delete_chat_photo)"
									;;
								'group_chat_created')
									# GROUP_CHAT_CREATED
									 message_group_chat_created[$_INDEX_]="$(json $_UPDATE_.message.group_chat_created)"
									;;
								'supergroup_chat_created')
									# SUPERGROUP_CHAT_CREATED
									 message_supergroup_chat_created[$_INDEX_]="$(json $_UPDATE_.message.supergroup_chat_created)"
									;;
								'channel_chat_created')
									# CHANNEL_CHAT_CREATED
									 message_channel_chat_created[$_INDEX_]="$(json $_UPDATE_.message.channel_chat_created)"
									;;
								'migrate_to_chat_id')					
									# MIGRATE_TO_CHAT_ID
									 message_migrate_to_chat_id[$_INDEX_]="$(json $_UPDATE_.message.migrate_to_chat_id)"
									;;
								'migrate_from_chat_id')
									# MIGRATE_FROM_CHAT_ID
									 message_migrate_from_chat_id[$_INDEX_]="$(json $_UPDATE_.message.migrate_from_chat_id)"
									;;
							esac
						done
						;;
					'edited_message')	
						# EDITED_MESSAGE
						for _SUBKEY_ in $(json "$_UPDATE_.$_KEY_|keys|.[]")
						do
							case $_SUBKEY_ in
								'message_id')
									 edited_message_message_id[$_INDEX_]="$(json $_UPDATE_.edited_message.message_id)"
									;;
								'from')
									 edited_message_from_id[$_INDEX_]="$(json $_UPDATE_.edited_message.from.id)"
									 edited_message_from_first_name[$_INDEX_]="$(json $_UPDATE_.edited_message.from.first_name)"
									 edited_message_from_last_name[$_INDEX_]="$(json $_UPDATE_.edited_message.from.last_name)"
									 edited_message_from_username[$_INDEX_]="$(json $_UPDATE_.edited_message.from.username)"
									;;
								'date')
									 edited_message_date[$_INDEX_]="$(json $_UPDATE_.edited_message.date)"
									;;
								'chat')
									 edited_message_chat_id[$_INDEX_]="$(json $_UPDATE_.edited_message.chat.id)"
									 edited_message_chat_type[$_INDEX_]="$(json $_UPDATE_.edited_message.chat.type)"
									 edited_message_chat_title[$_INDEX_]="$(json $_UPDATE_.edited_message.chat.title)"
									 edited_message_chat_username[$_INDEX_]="$(json $_UPDATE_.edited_message.chat.username)"
									 edited_message_chat_first_name[$_INDEX_]="$(json $_UPDATE_.edited_message.chat.first_name)"
									 edited_message_chat_last_name[$_INDEX_]="$(json $_UPDATE_.edited_message.chat.last_name)"
									 edited_message_chat_all_members_are_administrators[$_INDEX_]="$(json $_UPDATE_.edited_message.chat.all_members_are_administrators)"
									;;
								'forward_from')
									 edited_message_forward_from_id[$_INDEX_]="$(json $_UPDATE_.edited_message.forward_from.id)"
									 edited_message_forward_from_first_name[$_INDEX_]="$(json $_UPDATE_.edited_message.forward_from.first_name)"
									 edited_message_forward_from_last_name[$_INDEX_]="$(json $_UPDATE_.edited_message.forward_from.last_name)"
									 edited_message_forward_from_username[$_INDEX_]="$(json $_UPDATE_.edited_message.forward_from.username)"
									 edited_message_forward_from_chat_id[$_INDEX_]="$(json $_UPDATE_.edited_message.forward_from_chat.id)"
									 edited_message_forward_from_chat_type[$_INDEX_]="$(json $_UPDATE_.edited_message.forward_from_chat.type)"
									 edited_message_forward_from_chat_title[$_INDEX_]="$(json $_UPDATE_.edited_message.forward_from_chat.title)"
									 edited_message_forward_from_chat_username[$_INDEX_]="$(json $_UPDATE_.edited_message.forward_from_chat.username)"
									 edited_message_forward_from_chat_first_name[$_INDEX_]="$(json $_UPDATE_.edited_message.forward_from_chat.first_name)"
									 edited_message_forward_from_chat_last_name[$_INDEX_]="$(json $_UPDATE_.edited_message.forward_from_chat.last_name)"
									 edited_message_forward_from_chat_all_members_are_administrators[$_INDEX_]="$(json $_UPDATE_.edited_message.forward_from_chat.all_members_are_administrators)"
									 edited_message_forward_from_message_id[$_INDEX_]="$(json $_UPDATE_.edited_message.forward_from_message_id)"
									;;
								'forward_date')
									 edited_message_forward_date[$_INDEX_]="$(json $_UPDATE_.edited_message.forward_date)"
									;;
								'reply_to_message')
									 edited_message_reply_to_message_message_id[$_INDEX_]="$(json $_UPDATE_.edited_message.reply_to_message.message_id)"
									 edited_message_reply_to_message_from_id[$_INDEX_]="$(json $_UPDATE_.edited_message.reply_to_message.from.id)"
									 edited_message_reply_to_message_from_username[$_INDEX_]="$(json $_UPDATE_.edited_message.reply_to_message.from.username)"
									 edited_message_reply_to_message_from_first_name[$_INDEX_]="$(json $_UPDATE_.edited_message.reply_to_message.from.first_name)"
									 edited_message_reply_to_message_from_last_name[$_INDEX_]="$(json $_UPDATE_.edited_message.reply_to_message.from.last_name)"
									 edited_message_reply_to_message_date[$_INDEX_]="$(json $_UPDATE_.edited_message.reply_to_message.date)"
									 edited_message_reply_to_message_chat_id[$_INDEX_]="$(json $_UPDATE_.edited_message.reply_to_message.chat.id)"
									 edited_message_reply_to_message_chat_type[$_INDEX_]="$(json $_UPDATE_.edited_message.reply_to_message.chat.type)"
									 edited_message_reply_to_message_chat_title[$_INDEX_]="$(json $_UPDATE_.edited_message.reply_to_message.chat.title)"
									 edited_message_reply_to_message_chat_username[$_INDEX_]="$(json $_UPDATE_.edited_message.reply_to_message.chat.username)"
									 edited_message_reply_to_message_chat_first_name[$_INDEX_]="$(json $_UPDATE_.edited_message.reply_to_message.chat.first_name)"
									 edited_message_reply_to_message_chat_last_name[$_INDEX_]="$(json $_UPDATE_.edited_message.reply_to_message.chat.last_name)"
									 edited_message_reply_to_message_chat_all_members_are_administrators[$_INDEX_]="$(json $_UPDATE_.edited_message.reply_to_message.chat.all_members_are_administrators)"
									 edited_message_reply_to_message_forward_from_message_id[$_INDEX_]="$(json $_UPDATE_.edited_message.reply_to_message.forward_from_message_id)"
									 edited_message_reply_to_message_forward_date[$_INDEX_]="$(json $_UPDATE_.edited_message.reply_to_message.forward_date)"
									 edited_message_reply_to_message_edit_date[$_INDEX_]="$(json $_UPDATE_.edited_message.reply_to_message.edit_date)"
									 edited_message_reply_to_message_text[$_INDEX_]="$(json $_UPDATE_.edited_message.reply_to_message.text)"
									;;
								'text')
									 edited_message_text[$_INDEX_]="$(json $_UPDATE_.edited_message.text)"
									;;
								'entities')
									 edited_message_entities_type[$_INDEX_]="$(json $_UPDATE_.edited_message.entities[].type)"
									 edited_message_entities_offset[$_INDEX_]="$(json $_UPDATE_.edited_message.entities[].offset)"
									 edited_message_entities_length[$_INDEX_]="$(json $_UPDATE_.edited_message.entities[].length)"
									 edited_message_entities_url[$_INDEX_]="$(json $_UPDATE_.edited_message.entities[].url)"
									;;
								'audio')
									 edited_message_audio_file_id[$_INDEX_]="$(json $_UPDATE_.edited_message.audio.file_id)"
									 edited_message_audio_duration[$_INDEX_]="$(json $_UPDATE_.edited_message.audio.duration)"
									 edited_message_audio_performer[$_INDEX_]="$(json $_UPDATE_.edited_message.audio.performer)"
									 edited_message_audio_title[$_INDEX_]="$(json $_UPDATE_.edited_message.audio.title)"
									 edited_message_audio_mime_type[$_INDEX_]="$(json $_UPDATE_.edited_message.audio.mime_type)"
									 edited_message_audio_file_size[$_INDEX_]="$(json $_UPDATE_.edited_message.audio.file_size)"
									;;
								'document')
									 edited_message_document_file_id[$_INDEX_]="$(json $_UPDATE_.edited_message.document.file_id)"
									 edited_message_document_file_name[$_INDEX_]="$(json $_UPDATE_.edited_message.document.file_name)"
									 edited_message_document_mime_type[$_INDEX_]="$(json $_UPDATE_.edited_message.document.mime_type)"
									 edited_message_document_file_size[$_INDEX_]="$(json $_UPDATE_.edited_message.document.file_size)"
									;;
								'photo')
					
									_TOTAL_PHOTO_=$(json "$_UPDATE_.edited_message.photo|length" | head -n1)
					
									 edited_message_photo_file_id[$_INDEX_]="$(json $_UPDATE_.edited_message.photo[$((_TOTAL_PHOTO_-1))].file_id)"
									 edited_message_photo_width[$_INDEX_]="$(json $_UPDATE_.edited_message.photo[$((_TOTAL_PHOTO_-1))].width)"
									 edited_message_photo_height[$_INDEX_]="$(json $_UPDATE_.edited_message.photo[$((_TOTAL_PHOTO_-1))].height)"
									 edited_message_photo_file_size[$_INDEX_]="$(json $_UPDATE_.edited_message.photo[$((_TOTAL_PHOTO_-1))].file_size)"
									;;
								'sticker')
									 edited_message_sticker_file_id[$_INDEX_]="$(json $_UPDATE_.edited_message.sticker.file_id)"
									 edited_message_sticker_width[$_INDEX_]="$(json $_UPDATE_.edited_message.sticker.width)"
									 edited_message_sticker_height[$_INDEX_]="$(json $_UPDATE_.edited_message.sticker.height)"
									 edited_message_sticker_emoji[$_INDEX_]="$(json $_UPDATE_.edited_message.sticker.emoji)"
									 edited_message_sticker_file_size[$_INDEX_]="$(json $_UPDATE_.edited_message.sticker.file_size)"
									;;
								'video')
									 edited_message_video_file_id[$_INDEX_]="$(json $_UPDATE_.edited_message.video.file_id)"
									 edited_message_video_width[$_INDEX_]="$(json $_UPDATE_.edited_message.video.width)"
									 edited_message_video_height[$_INDEX_]="$(json $_UPDATE_.edited_message.video.height)"
									 edited_message_video_duration[$_INDEX_]="$(json $_UPDATE_.edited_message.video.duration)"
									 edited_message_video_mime_type[$_INDEX_]="$(json $_UPDATE_.edited_message.video.mime_type)"
									 edited_message_video_file_size[$_INDEX_]="$(json $_UPDATE_.edited_message.video.file_size)"
									;;
								'voice')
									 edited_message_voice_file_id[$_INDEX_]="$(json $_UPDATE_.edited_message.voice.file_id)"
									 edited_message_voice_duration[$_INDEX_]="$(json $_UPDATE_.edited_message.voice.duration)"
									 edited_message_voice_mime_type[$_INDEX_]="$(json $_UPDATE_.edited_message.voice.mime_type)"
									 edited_message_voice_file_size[$_INDEX_]="$(json $_UPDATE_.edited_message.voice.file_size)"
									;;
								'caption')
									 edited_message_caption[$_INDEX_]="$(json $_UPDATE_.edited_message.caption)"
									;;
								'contact')
									 edited_message_contact_phone_number[$_INDEX_]="$(json $_UPDATE_.edited_message.contact.phone_number)"
									 edited_message_contact_first_name[$_INDEX_]="$(json $_UPDATE_.edited_message.contact.first_name)"
									 edited_message_contact_last_name[$_INDEX_]="$(json $_UPDATE_.edited_message.contact.last_name)"
									 edited_message_contact_user_id[$_INDEX_]="$(json $_UPDATE_.edited_message.contact.user_id)"
									;;
								'location')
									 edited_message_location_longitude[$_INDEX_]="$(json $_UPDATE_.edited_message.location.longitude)"
									 edited_message_location_latitude[$_INDEX_]="$(json $_UPDATE_.edited_message.location.latitude)"
									;;
								'venue')
									 edited_message_venue_location_longitude[$_INDEX_]="$(json $_UPDATE_.edited_message.venue.location[].longitude)"
									 edited_message_venue_location_latitude[$_INDEX_]="$(json $_UPDATE_.edited_message.venue.location[].latitude)"
									 edited_message_venue_title[$_INDEX_]="$(json $_UPDATE_.edited_message.venue.title)"
									 edited_message_venue_address[$_INDEX_]="$(json $_UPDATE_.edited_message.venue.address)"
									 edited_message_venue_foursquare_id[$_INDEX_]="$(json $_UPDATE_.edited_message.venue.foursquare_id)"
									;;
								'new_chat_member')
									 edited_message_new_chat_member_id[$_INDEX_]="$(json $_UPDATE_.edited_message.new_chat_member.id)"
									 edited_message_new_chat_member_first_name[$_INDEX_]="$(json $_UPDATE_.edited_message.new_chat_member.first_name)"
									 edited_message_new_chat_member_last_name[$_INDEX_]="$(json $_UPDATE_.edited_message.new_chat_member.last_name)"
									 edited_message_new_chat_member_username[$_INDEX_]="$(json $_UPDATE_.edited_message.new_chat_member.username)"
									;;
								'left_chat_member')
									 edited_message_left_chat_member_id[$_INDEX_]="$(json $_UPDATE_.edited_message.left_chat_member.id)"
									 edited_message_left_chat_member_first_name[$_INDEX_]="$(json $_UPDATE_.edited_message.left_chat_member.first_name)"
									 edited_message_left_chat_member_last_name[$_INDEX_]="$(json $_UPDATE_.edited_message.left_chat_member.last_name)"
									 edited_message_left_chat_member_username[$_INDEX_]="$(json $_UPDATE_.edited_message.left_chat_member.username)"
									;;
								'new_chat_title')
									 edited_message_new_chat_title[$_INDEX_]="$(json $_UPDATE_.edited_message.new_chat_title)"
									;;
								'new_chat_photo')
									_TOTAL_PHOTO_=$(json "$_UPDATE_.edited_message.new_chat_photo|length" | head -n1)
	
									 edited_message_new_chat_photo_file_id[$_INDEX_]="$(json $_UPDATE_.edited_message.new_chat_photo[$((_TOTAL_PHOTO_-1))].file_id)"
									 edited_message_new_chat_photo_width[$_INDEX_]="$(json $_UPDATE_.edited_message.new_chat_photo[$((_TOTAL_PHOTO_-1))].width)"
									 edited_message_new_chat_photo_height[$_INDEX_]="$(json $_UPDATE_.edited_message.new_chat_photo[$((_TOTAL_PHOTO_-1))].height)"
									 edited_message_new_chat_photo_file_size[$_INDEX_]="$(json $_UPDATE_.edited_message.new_chat_photo[$((_TOTAL_PHOTO_-1))].file_size)"
									;;
								'delete_chat_photo')
									 edited_message_delete_chat_photo[$_INDEX_]="$(json $_UPDATE_.edited_message.delete_chat_photo)"
									;;
								'group_chat_created')
									 edited_message_group_chat_created[$_INDEX_]="$(json $_UPDATE_.edited_message.group_chat_created)"
									;;
								'supergroup_chat_created')
									 edited_message_supergroup_chat_created[$_INDEX_]="$(json $_UPDATE_.edited_message.supergroup_chat_created)"
									;;
								'channel_chat_created')
									 edited_message_channel_chat_created[$_INDEX_]="$(json $_UPDATE_.edited_message.channel_chat_created)"
									;;
								'migrate_to_chat_id')
									 edited_message_migrate_to_chat_id[$_INDEX_]="$(json $_UPDATE_.edited_message.migrate_to_chat_id)"
									;;
								'migrate_from_chat_id')
									 edited_message_migrate_from_chat_id[$_INDEX_]="$(json $_UPDATE_.edited_message.migrate_from_chat_id)"
									;;
							esac
						done
						;;
					'channel_post')
						for _SUBKEY_ in $(json "$_UPDATE_.$_KEY_|keys|.[]")
						do
							case $_SUBKEY_ in
								'message_id')
									# XXX CHANNEL_POST XXX
									 channel_post_message_id[$_INDEX_]="$(json $_UPDATE_.channel_post.message_id)"
									;;
								'from')
									 channel_post_from_id[$_INDEX_]="$(json $_UPDATE_.channel_post.from.id)"
									 channel_post_from_first_name[$_INDEX_]="$(json $_UPDATE_.channel_post.from.first_name)"
									 channel_post_from_last_name[$_INDEX_]="$(json $_UPDATE_.channel_post.from.last_name)"
									 channel_post_from_username[$_INDEX_]="$(json $_UPDATE_.channel_post.from.username)"
									;;
								'date')
									 channel_post_date[$_INDEX_]="$(json $_UPDATE_.channel_post.date)"
									;;
								'chat')
									 channel_post_chat_id[$_INDEX_]="$(json $_UPDATE_.channel_post.chat.id)"
									 channel_post_chat_type[$_INDEX_]="$(json $_UPDATE_.channel_post.chat.type)"
									 channel_post_chat_title[$_INDEX_]="$(json $_UPDATE_.channel_post.chat.title)"
									 channel_post_chat_username[$_INDEX_]="$(json $_UPDATE_.channel_post.chat.username)"
									 channel_post_chat_first_name[$_INDEX_]="$(json $_UPDATE_.channel_post.chat.first_name)"
									 channel_post_chat_last_name[$_INDEX_]="$(json $_UPDATE_.channel_post.chat.last_name)"
									 channel_post_chat_all_members_are_administrators[$_INDEX_]="$(json $_UPDATE_.channel_post.chat.all_members_are_administrators)"
									;;
								'forward_from')
									 channel_post_forward_from_id[$_INDEX_]="$(json $_UPDATE_.channel_post.forward_from.id)"
									 channel_post_forward_from_first_name[$_INDEX_]="$(json $_UPDATE_.channel_post.forward_from.first_name)"
									 channel_post_forward_from_last_name[$_INDEX_]="$(json $_UPDATE_.channel_post.forward_from.last_name)"
									 channel_post_forward_from_username[$_INDEX_]="$(json $_UPDATE_.channel_post.forward_from.username)"
									 channel_post_forward_from_chat_id[$_INDEX_]="$(json $_UPDATE_.channel_post.forward_from_chat.id)"
									 channel_post_forward_from_chat_type[$_INDEX_]="$(json $_UPDATE_.channel_post.forward_from_chat.type)"
									 channel_post_forward_from_chat_title[$_INDEX_]="$(json $_UPDATE_.channel_post.forward_from_chat.title)"
									 channel_post_forward_from_chat_username[$_INDEX_]="$(json $_UPDATE_.channel_post.forward_from_chat.username)"
									 channel_post_forward_from_chat_first_name[$_INDEX_]="$(json $_UPDATE_.channel_post.forward_from_chat.first_name)"
									 channel_post_forward_from_chat_last_name[$_INDEX_]="$(json $_UPDATE_.channel_post.forward_from_chat.last_name)"
									 channel_post_forward_from_chat_all_members_are_administrators[$_INDEX_]="$(json $_UPDATE_.channel_post.forward_from_chat.all_members_are_administrators)"
									 channel_post_forward_from_message_id[$_INDEX_]="$(json $_UPDATE_.channel_post.forward_from_message_id)"
									;;
								'forward_date')
									 channel_post_forward_date[$_INDEX_]="$(json $_UPDATE_.channel_post.forward_date)"
									;;
								'reply_to_message')
									 channel_post_reply_to_message_message_id[$_INDEX_]="$(json $_UPDATE_.channel_post.reply_to_message.message_id)"
									 channel_post_reply_to_message_from_id[$_INDEX_]="$(json $_UPDATE_.channel_post.reply_to_message.from.id)"
									 channel_post_reply_to_message_from_username[$_INDEX_]="$(json $_UPDATE_.channel_post.reply_to_message.from.username)"
									 channel_post_reply_to_message_from_first_name[$_INDEX_]="$(json $_UPDATE_.channel_post.reply_to_message.from.first_name)"
									 channel_post_reply_to_message_from_last_name[$_INDEX_]="$(json $_UPDATE_.channel_post.reply_to_message.from.last_name)"
									 channel_post_reply_to_message_date[$_INDEX_]="$(json $_UPDATE_.channel_post.reply_to_message.date)"
									 channel_post_reply_to_message_chat_id[$_INDEX_]="$(json $_UPDATE_.channel_post.reply_to_message.chat.id)"
									 channel_post_reply_to_message_chat_type[$_INDEX_]="$(json $_UPDATE_.channel_post.reply_to_message.chat.type)"
									 channel_post_reply_to_message_chat_title[$_INDEX_]="$(json $_UPDATE_.channel_post.reply_to_message.chat.title)"
									 channel_post_reply_to_message_chat_username[$_INDEX_]="$(json $_UPDATE_.channel_post.reply_to_message.chat.username)"
									 channel_post_reply_to_message_chat_first_name[$_INDEX_]="$(json $_UPDATE_.channel_post.reply_to_message.chat.first_name)"
									 channel_post_reply_to_message_chat_last_name[$_INDEX_]="$(json $_UPDATE_.channel_post.reply_to_message.chat.last_name)"
									 channel_post_reply_to_message_chat_all_members_are_administrators[$_INDEX_]="$(json $_UPDATE_.channel_post.reply_to_message.chat.all_members_are_administrators)"
									 channel_post_reply_to_message_forward_from_message_id[$_INDEX_]="$(json $_UPDATE_.channel_post.reply_to_message.forward_from_message_id)"
									 channel_post_reply_to_message_forward_date[$_INDEX_]="$(json $_UPDATE_.channel_post.reply_to_message.forward_date)"
									 channel_post_reply_to_message_edit_date[$_INDEX_]="$(json $_UPDATE_.channel_post.reply_to_message.edit_date)"
									 channel_post_reply_to_message_text[$_INDEX_]="$(json $_UPDATE_.channel_post.reply_to_message.text)"
									;;
								'text')
									 channel_post_text[$_INDEX_]="$(json $_UPDATE_.channel_post.text)"
									;;
								'entities')
									 channel_post_entities_type[$_INDEX_]="$(json $_UPDATE_.channel_post.entities[].type)"
									 channel_post_entities_offset[$_INDEX_]="$(json $_UPDATE_.channel_post.entities[].offset)"
									 channel_post_entities_length[$_INDEX_]="$(json $_UPDATE_.channel_post.entities[].length)"
									 channel_post_entities_url[$_INDEX_]="$(json $_UPDATE_.channel_post.entities[].url)"
									;;
								'audio')
									 channel_post_audio_file_id[$_INDEX_]="$(json $_UPDATE_.channel_post.audio.file_id)"
									 channel_post_audio_duration[$_INDEX_]="$(json $_UPDATE_.channel_post.audio.duration)"
									 channel_post_audio_performer[$_INDEX_]="$(json $_UPDATE_.channel_post.audio.performer)"
									 channel_post_audio_title[$_INDEX_]="$(json $_UPDATE_.channel_post.audio.title)"
									 channel_post_audio_mime_type[$_INDEX_]="$(json $_UPDATE_.channel_post.audio.mime_type)"
									 channel_post_audio_file_size[$_INDEX_]="$(json $_UPDATE_.channel_post.audio.file_size)"
									;;
								'document')
									 channel_post_document_file_id[$_INDEX_]="$(json $_UPDATE_.channel_post.document.file_id)"
									 channel_post_document_file_name[$_INDEX_]="$(json $_UPDATE_.channel_post.document.file_name)"
									 channel_post_document_mime_type[$_INDEX_]="$(json $_UPDATE_.channel_post.document.mime_type)"
									 channel_post_document_file_size[$_INDEX_]="$(json $_UPDATE_.channel_post.document.file_size)"
									;;
								'photo')
									_TOTAL_PHOTO_=$(json "$_UPDATE_.channel_post.photo|length" | head -n1)
		
									 channel_post_photo_file_id[$_INDEX_]="$(json $_UPDATE_.channel_post.photo[$((_TOTAL_PHOTO_-1))].file_id)"
									 channel_post_photo_width[$_INDEX_]="$(json $_UPDATE_.channel_post.photo[$((_TOTAL_PHOTO_-1))].width)"
									 channel_post_photo_height[$_INDEX_]="$(json $_UPDATE_.channel_post.photo[$((_TOTAL_PHOTO_-1))].height)"
									 channel_post_photo_file_size[$_INDEX_]="$(json $_UPDATE_.channel_post.photo[$((_TOTAL_PHOTO_-1))].file_size)"
									;;
								'sticker')
									 channel_post_sticker_file_id[$_INDEX_]="$(json $_UPDATE_.channel_post.sticker.file_id)"
									 channel_post_sticker_width[$_INDEX_]="$(json $_UPDATE_.channel_post.sticker.width)"
									 channel_post_sticker_height[$_INDEX_]="$(json $_UPDATE_.channel_post.sticker.height)"
									 channel_post_sticker_emoji[$_INDEX_]="$(json $_UPDATE_.channel_post.sticker.emoji)"
									 channel_post_sticker_file_size[$_INDEX_]="$(json $_UPDATE_.channel_post.sticker.file_size)"
									;;
								'video')
									 channel_post_video_file_id[$_INDEX_]="$(json $_UPDATE_.channel_post.video.file_id)"
									 channel_post_video_width[$_INDEX_]="$(json $_UPDATE_.channel_post.video.width)"
									 channel_post_video_height[$_INDEX_]="$(json $_UPDATE_.channel_post.video.height)"
									 channel_post_video_duration[$_INDEX_]="$(json $_UPDATE_.channel_post.video.duration)"
									 channel_post_video_mime_type[$_INDEX_]="$(json $_UPDATE_.channel_post.video.mime_type)"
									 channel_post_video_file_size[$_INDEX_]="$(json $_UPDATE_.channel_post.video.file_size)"
									;;
								'voice')
									 channel_post_voice_file_id[$_INDEX_]="$(json $_UPDATE_.channel_post.voice.file_id)"
									 channel_post_voice_duration[$_INDEX_]="$(json $_UPDATE_.channel_post.voice.duration)"
									 channel_post_voice_mime_type[$_INDEX_]="$(json $_UPDATE_.channel_post.voice.mime_type)"
									 channel_post_voice_file_size[$_INDEX_]="$(json $_UPDATE_.channel_post.voice.file_size)"
									;;
								'caption')
									 channel_post_caption[$_INDEX_]="$(json $_UPDATE_.channel_post.caption)"
									;;
								'contact')
									 channel_post_contact_phone_number[$_INDEX_]="$(json $_UPDATE_.channel_post.contact.phone_number)"
									 channel_post_contact_first_name[$_INDEX_]="$(json $_UPDATE_.channel_post.contact.first_name)"
									 channel_post_contact_last_name[$_INDEX_]="$(json $_UPDATE_.channel_post.contact.last_name)"
									 channel_post_contact_user_id[$_INDEX_]="$(json $_UPDATE_.channel_post.contact.user_id)"
									;;
								'location')
									 channel_post_location_longitude[$_INDEX_]="$(json $_UPDATE_.channel_post.location.longitude)"
									 channel_post_location_latitude[$_INDEX_]="$(json $_UPDATE_.channel_post.location.latitude)"
									;;
								'venue')
									 channel_post_venue_location_longitude[$_INDEX_]="$(json $_UPDATE_.channel_post.venue.location[].longitude)"
									 channel_post_venue_location_latitude[$_INDEX_]="$(json $_UPDATE_.channel_post.venue.location[].latitude)"
									 channel_post_venue_title[$_INDEX_]="$(json $_UPDATE_.channel_post.venue.title)"
									 channel_post_venue_address[$_INDEX_]="$(json $_UPDATE_.channel_post.venue.address)"
									 channel_post_venue_foursquare_id[$_INDEX_]="$(json $_UPDATE_.channel_post.venue.foursquare_id)"
									;;
								'new_chat_member')
									 channel_post_new_chat_member_id[$_INDEX_]="$(json $_UPDATE_.channel_post.new_chat_member.id)"
									 channel_post_new_chat_member_first_name[$_INDEX_]="$(json $_UPDATE_.channel_post.new_chat_member.first_name)"
									 channel_post_new_chat_member_last_name[$_INDEX_]="$(json $_UPDATE_.channel_post.new_chat_member.last_name)"
									 channel_post_new_chat_member_username[$_INDEX_]="$(json $_UPDATE_.channel_post.new_chat_member.username)"
									;;
								'left_chat_member')
									 channel_post_left_chat_member_id[$_INDEX_]="$(json $_UPDATE_.channel_post.left_chat_member.id)"
									 channel_post_left_chat_member_first_name[$_INDEX_]="$(json $_UPDATE_.channel_post.left_chat_member.first_name)"
									 channel_post_left_chat_member_last_name[$_INDEX_]="$(json $_UPDATE_.channel_post.left_chat_member.last_name)"
									 channel_post_left_chat_member_username[$_INDEX_]="$(json $_UPDATE_.channel_post.left_chat_member.username)"
									;;
								'new_chat_title')
									 channel_post_new_chat_title[$_INDEX_]="$(json $_UPDATE_.channel_post.new_chat_title)"
									;;
								'photo')
						
									_TOTAL_PHOTO_=$(json "$_UPDATE_.channel_post.new_chat_photo|length" | head -n1)
						
									 channel_post_new_chat_photo_file_id[$_INDEX_]="$(json $_UPDATE_.channel_post.new_chat_photo[$((_TOTAL_PHOTO_-1))].file_id)"
									 channel_post_new_chat_photo_width[$_INDEX_]="$(json $_UPDATE_.channel_post.new_chat_photo[$((_TOTAL_PHOTO_-1))].width)"
									 channel_post_new_chat_photo_height[$_INDEX_]="$(json $_UPDATE_.channel_post.new_chat_photo[$((_TOTAL_PHOTO_-1))].height)"
									 channel_post_new_chat_photo_file_size[$_INDEX_]="$(json $_UPDATE_.channel_post.new_chat_photo[$((_TOTAL_PHOTO_-1))].file_size)"
									 channel_post_delete_chat_photo[$_INDEX_]="$(json $_UPDATE_.channel_post.delete_chat_photo)"
									;;
								'group_chat_created')
									 channel_post_group_chat_created[$_INDEX_]="$(json $_UPDATE_.channel_post.group_chat_created)"
									 channel_post_supergroup_chat_created[$_INDEX_]="$(json $_UPDATE_.channel_post.supergroup_chat_created)"
									 channel_post_channel_chat_created[$_INDEX_]="$(json $_UPDATE_.channel_post.channel_chat_created)"
									;;
								'migrate_to_chat_id')
									 channel_post_migrate_to_chat_id[$_INDEX_]="$(json $_UPDATE_.channel_post.migrate_to_chat_id)"
									;;
								'migrate_from_chat_id')
									 channel_post_migrate_from_chat_id[$_INDEX_]="$(json $_UPDATE_.channel_post.migrate_from_chat_id)"
									;;
								esac
							done
						;;
					'edited_channel_post')
						for _SUBKEY_ in $(json "$_UPDATE_.$_KEY_|keys|.[]")
						do
							case $_SUBKEY_ in
								'message_id')			
									# EDITED_CHANNEL_POST
									 edited_channel_post_message_id[$_INDEX_]="$(json $_UPDATE_.edited_channel_post.message_id)"
									;;
								'from')
									 edited_channel_post_from_id[$_INDEX_]="$(json $_UPDATE_.edited_channel_post.from.id)"
									 edited_channel_post_from_first_name[$_INDEX_]="$(json $_UPDATE_.edited_channel_post.from.first_name)"
									 edited_channel_post_from_last_name[$_INDEX_]="$(json $_UPDATE_.edited_channel_post.from.last_name)"
									 edited_channel_post_from_username[$_INDEX_]="$(json $_UPDATE_.edited_channel_post.from.username)"
									;;
								'date')
									 edited_channel_post_date[$_INDEX_]="$(json $_UPDATE_.edited_channel_post.date)"
									;;
								'chat')
									 edited_channel_post_chat_id[$_INDEX_]="$(json $_UPDATE_.edited_channel_post.chat.id)"
									 edited_channel_post_chat_type[$_INDEX_]="$(json $_UPDATE_.edited_channel_post.chat.type)"
									 edited_channel_post_chat_title[$_INDEX_]="$(json $_UPDATE_.edited_channel_post.chat.title)"
									 edited_channel_post_chat_username[$_INDEX_]="$(json $_UPDATE_.edited_channel_post.chat.username)"
									 edited_channel_post_chat_first_name[$_INDEX_]="$(json $_UPDATE_.edited_channel_post.chat.first_name)"
									 edited_channel_post_chat_last_name[$_INDEX_]="$(json $_UPDATE_.edited_channel_post.chat.last_name)"
									 edited_channel_post_chat_all_members_are_administrators[$_INDEX_]="$(json $_UPDATE_.edited_channel_post.chat.all_members_are_administrators)"
									;;
								'forward_from')
									 edited_channel_post_forward_from_id[$_INDEX_]="$(json $_UPDATE_.edited_channel_post.forward_from.id)"
									 edited_channel_post_forward_from_first_name[$_INDEX_]="$(json $_UPDATE_.edited_channel_post.forward_from.first_name)"
									 edited_channel_post_forward_from_last_name[$_INDEX_]="$(json $_UPDATE_.edited_channel_post.forward_from.last_name)"
									 edited_channel_post_forward_from_username[$_INDEX_]="$(json $_UPDATE_.edited_channel_post.forward_from.username)"
									 edited_channel_post_forward_from_chat_id[$_INDEX_]="$(json $_UPDATE_.edited_channel_post.forward_from_chat.id)"
									 edited_channel_post_forward_from_chat_type[$_INDEX_]="$(json $_UPDATE_.edited_channel_post.forward_from_chat.type)"
									 edited_channel_post_forward_from_chat_title[$_INDEX_]="$(json $_UPDATE_.edited_channel_post.forward_from_chat.title)"
									 edited_channel_post_forward_from_chat_username[$_INDEX_]="$(json $_UPDATE_.edited_channel_post.forward_from_chat.username)"
									 edited_channel_post_forward_from_chat_first_name[$_INDEX_]="$(json $_UPDATE_.edited_channel_post.forward_from_chat.first_name)"
									 edited_channel_post_forward_from_chat_last_name[$_INDEX_]="$(json $_UPDATE_.edited_channel_post.forward_from_chat.last_name)"
									 edited_channel_post_forward_from_chat_all_members_are_administrators[$_INDEX_]="$(json $_UPDATE_.edited_channel_post.forward_from_chat.all_members_are_administrators)"
									 edited_channel_post_forward_from_message_id[$_INDEX_]="$(json $_UPDATE_.edited_channel_post.forward_from_message_id)"
									;;
								'forward_date')
									 edited_channel_post_forward_date[$_INDEX_]="$(json $_UPDATE_.edited_channel_post.forward_date)"
									;;
								'reply_to_message')
									 edited_channel_post_reply_to_message_message_id[$_INDEX_]="$(json $_UPDATE_.edited_channel_post.reply_to_message.message_id)"
									 edited_channel_post_reply_to_message_from_id[$_INDEX_]="$(json $_UPDATE_.edited_channel_post.reply_to_message.from.id)"
									 edited_channel_post_reply_to_message_from_username[$_INDEX_]="$(json $_UPDATE_.edited_channel_post.reply_to_message.from.username)"
									 edited_channel_post_reply_to_message_from_first_name[$_INDEX_]="$(json $_UPDATE_.edited_channel_post.reply_to_message.from.first_name)"
									 edited_channel_post_reply_to_message_from_last_name[$_INDEX_]="$(json $_UPDATE_.edited_channel_post.reply_to_message.from.last_name)"
									 edited_channel_post_reply_to_message_date[$_INDEX_]="$(json $_UPDATE_.edited_channel_post.reply_to_message.date)"
									 edited_channel_post_reply_to_message_chat_id[$_INDEX_]="$(json $_UPDATE_.edited_channel_post.reply_to_message.chat.id)"
									 edited_channel_post_reply_to_message_chat_type[$_INDEX_]="$(json $_UPDATE_.edited_channel_post.reply_to_message.chat.type)"
									 edited_channel_post_reply_to_message_chat_title[$_INDEX_]="$(json $_UPDATE_.edited_channel_post.reply_to_message.chat.title)"
									 edited_channel_post_reply_to_message_chat_username[$_INDEX_]="$(json $_UPDATE_.edited_channel_post.reply_to_message.chat.username)"
									 edited_channel_post_reply_to_message_chat_first_name[$_INDEX_]="$(json $_UPDATE_.edited_channel_post.reply_to_message.chat.first_name)"
									 edited_channel_post_reply_to_message_chat_last_name[$_INDEX_]="$(json $_UPDATE_.edited_channel_post.reply_to_message.chat.last_name)"
									 edited_channel_post_reply_to_message_chat_all_members_are_administrators[$_INDEX_]="$(json $_UPDATE_.edited_channel_post.reply_to_message.chat.all_members_are_administrators)"
									 edited_channel_post_reply_to_message_forward_from_message_id[$_INDEX_]="$(json $_UPDATE_.edited_channel_post.reply_to_message.forward_from_message_id)"
									 edited_channel_post_reply_to_message_forward_date[$_INDEX_]="$(json $_UPDATE_.edited_channel_post.reply_to_message.forward_date)"
									 edited_channel_post_reply_to_message_edit_date[$_INDEX_]="$(json $_UPDATE_.edited_channel_post.reply_to_message.edit_date)"
									 edited_channel_post_reply_to_message_text[$_INDEX_]="$(json $_UPDATE_.edited_channel_post.reply_to_message.text)"
									;;
								'text')
									 edited_channel_post_text[$_INDEX_]="$(json $_UPDATE_.edited_channel_post.text)"
									;;
								'entities')
									 edited_channel_post_entities_type[$_INDEX_]="$(json $_UPDATE_.edited_channel_post.entities[].type)"
									 edited_channel_post_entities_offset[$_INDEX_]="$(json $_UPDATE_.edited_channel_post.entities[].offset)"
									 edited_channel_post_entities_length[$_INDEX_]="$(json $_UPDATE_.edited_channel_post.entities[].length)"
									 edited_channel_post_entities_url[$_INDEX_]="$(json $_UPDATE_.edited_channel_post.entities[].url)"
									;;
								'audio')
									 edited_channel_post_audio_file_id[$_INDEX_]="$(json $_UPDATE_.edited_channel_post.audio.file_id)"
									 edited_channel_post_audio_duration[$_INDEX_]="$(json $_UPDATE_.edited_channel_post.audio.duration)"
									 edited_channel_post_audio_performer[$_INDEX_]="$(json $_UPDATE_.edited_channel_post.audio.performer)"
									 edited_channel_post_audio_title[$_INDEX_]="$(json $_UPDATE_.edited_channel_post.audio.title)"
									 edited_channel_post_audio_mime_type[$_INDEX_]="$(json $_UPDATE_.edited_channel_post.audio.mime_type)"
									 edited_channel_post_audio_file_size[$_INDEX_]="$(json $_UPDATE_.edited_channel_post.audio.file_size)"
									;;
								'document')
									 edited_channel_post_document_file_id[$_INDEX_]="$(json $_UPDATE_.edited_channel_post.document.file_id)"
									 edited_channel_post_document_file_name[$_INDEX_]="$(json $_UPDATE_.edited_channel_post.document.file_name)"
									 edited_channel_post_document_mime_type[$_INDEX_]="$(json $_UPDATE_.edited_channel_post.document.mime_type)"
									 edited_channel_post_document_file_size[$_INDEX_]="$(json $_UPDATE_.edited_channel_post.document.file_size)"
									;;
								'photo')
						
									_TOTAL_PHOTO_=$(json "$_UPDATE_.edited_channel_post.photo|length" | head -n1)
		
									 edited_channel_post_photo_file_id[$_INDEX_]="$(json $_UPDATE_.edited_channel_post.photo[$((_TOTAL_PHOTO_-1))].file_id)"
									 edited_channel_post_photo_width[$_INDEX_]="$(json $_UPDATE_.edited_channel_post.photo[$((_TOTAL_PHOTO_-1))].width)"
									 edited_channel_post_photo_height[$_INDEX_]="$(json $_UPDATE_.edited_channel_post.photo[$((_TOTAL_PHOTO_-1))].height)"
									 edited_channel_post_photo_file_size[$_INDEX_]="$(json $_UPDATE_.edited_channel_post.photo[$((_TOTAL_PHOTO_-1))].file_size)"
									;;
								'sticker')
									 edited_channel_post_sticker_file_id[$_INDEX_]="$(json $_UPDATE_.edited_channel_post.sticker.file_id)"
									 edited_channel_post_sticker_width[$_INDEX_]="$(json $_UPDATE_.edited_channel_post.sticker.width)"
									 edited_channel_post_sticker_height[$_INDEX_]="$(json $_UPDATE_.edited_channel_post.sticker.height)"
									 edited_channel_post_sticker_emoji[$_INDEX_]="$(json $_UPDATE_.edited_channel_post.sticker.emoji)"
									 edited_channel_post_sticker_file_size[$_INDEX_]="$(json $_UPDATE_.edited_channel_post.sticker.file_size)"
									;;
								'video')
									 edited_channel_post_video_file_id[$_INDEX_]="$(json $_UPDATE_.edited_channel_post.video.file_id)"
									 edited_channel_post_video_width[$_INDEX_]="$(json $_UPDATE_.edited_channel_post.video.width)"
									 edited_channel_post_video_height[$_INDEX_]="$(json $_UPDATE_.edited_channel_post.video.height)"
									 edited_channel_post_video_duration[$_INDEX_]="$(json $_UPDATE_.edited_channel_post.video.duration)"
									 edited_channel_post_video_mime_type[$_INDEX_]="$(json $_UPDATE_.edited_channel_post.video.mime_type)"
									 edited_channel_post_video_file_size[$_INDEX_]="$(json $_UPDATE_.edited_channel_post.video.file_size)"
									;;
								'voice')
									 edited_channel_post_voice_file_id[$_INDEX_]="$(json $_UPDATE_.edited_channel_post.voice.file_id)"
									 edited_channel_post_voice_duration[$_INDEX_]="$(json $_UPDATE_.edited_channel_post.voice.duration)"
									 edited_channel_post_voice_mime_type[$_INDEX_]="$(json $_UPDATE_.edited_channel_post.voice.mime_type)"
									 edited_channel_post_voice_file_size[$_INDEX_]="$(json $_UPDATE_.edited_channel_post.voice.file_size)"
									;;
								'caption')
									 edited_channel_post_caption[$_INDEX_]="$(json $_UPDATE_.edited_channel_post.caption)"
									;;
								'contact')
									 edited_channel_post_contact_phone_number[$_INDEX_]="$(json $_UPDATE_.edited_channel_post.contact.phone_number)"
									 edited_channel_post_contact_first_name[$_INDEX_]="$(json $_UPDATE_.edited_channel_post.contact.first_name)"
									 edited_channel_post_contact_last_name[$_INDEX_]="$(json $_UPDATE_.edited_channel_post.contact.last_name)"
									 edited_channel_post_contact_user_id[$_INDEX_]="$(json $_UPDATE_.edited_channel_post.contact.user_id)"
									;;
								'location')
									 edited_channel_post_location_longitude[$_INDEX_]="$(json $_UPDATE_.edited_channel_post.location.longitude)"
									 edited_channel_post_location_latitude[$_INDEX_]="$(json $_UPDATE_.edited_channel_post.location.latitude)"
									;;
								'venue')
									 edited_channel_post_venue_location_longitude[$_INDEX_]="$(json $_UPDATE_.edited_channel_post.venue.location[].longitude)"
									 edited_channel_post_venue_location_latitude[$_INDEX_]="$(json $_UPDATE_.edited_channel_post.venue.location[].latitude)"
									 edited_channel_post_venue_title[$_INDEX_]="$(json $_UPDATE_.edited_channel_post.venue.title)"
									 edited_channel_post_venue_address[$_INDEX_]="$(json $_UPDATE_.edited_channel_post.venue.address)"
									 edited_channel_post_venue_foursquare_id[$_INDEX_]="$(json $_UPDATE_.edited_channel_post.venue.foursquare_id)"
									;;
								'new_chat_member')
									 edited_channel_post_new_chat_member_id[$_INDEX_]="$(json $_UPDATE_.edited_channel_post.new_chat_member.id)"
									 edited_channel_post_new_chat_member_first_name[$_INDEX_]="$(json $_UPDATE_.edited_channel_post.new_chat_member.first_name)"
									 edited_channel_post_new_chat_member_last_name[$_INDEX_]="$(json $_UPDATE_.edited_channel_post.new_chat_member.last_name)"
									 edited_channel_post_new_chat_member_username[$_INDEX_]="$(json $_UPDATE_.edited_channel_post.new_chat_member.username)"
									;;
								'left_chat_member')
									 edited_channel_post_left_chat_member_id[$_INDEX_]="$(json $_UPDATE_.edited_channel_post.left_chat_member.id)"
									 edited_channel_post_left_chat_member_first_name[$_INDEX_]="$(json $_UPDATE_.edited_channel_post.left_chat_member.first_name)"
									 edited_channel_post_left_chat_member_last_name[$_INDEX_]="$(json $_UPDATE_.edited_channel_post.left_chat_member.last_name)"
									 edited_channel_post_left_chat_member_username[$_INDEX_]="$(json $_UPDATE_.edited_channel_post.left_chat_member.username)"
									;;
								'new_chat_title')
									 edited_channel_post_new_chat_title[$_INDEX_]="$(json $_UPDATE_.edited_channel_post.new_chat_title)"
									;;
								'photo')
						
									_TOTAL_PHOTO_=$(json "$_UPDATE_.edited_channel_post.new_chat_photo|length" | head -n1)
		
									 edited_channel_post_new_chat_photo_file_id[$_INDEX_]="$(json $_UPDATE_.edited_channel_post.new_chat_photo[$((_TOTAL_PHOTO_-1))].file_id)"
									 edited_channel_post_new_chat_photo_width[$_INDEX_]="$(json $_UPDATE_.edited_channel_post.new_chat_photo[$((_TOTAL_PHOTO_-1))].width)"
									 edited_channel_post_new_chat_photo_height[$_INDEX_]="$(json $_UPDATE_.edited_channel_post.new_chat_photo[$((_TOTAL_PHOTO_-1))].height)"
									 edited_channel_post_new_chat_photo_file_size[$_INDEX_]="$(json $_UPDATE_.edited_channel_post.new_chat_photo[$((_TOTAL_PHOTO_-1))].file_size)"
									 edited_channel_post_delete_chat_photo[$_INDEX_]="$(json $_UPDATE_.edited_channel_post.delete_chat_photo)"
									;;
								'group_chat_created')
									 edited_channel_post_group_chat_created[$_INDEX_]="$(json $_UPDATE_.edited_channel_post.group_chat_created)"
									;;
								'supergroup_chat_created')
									 edited_channel_post_supergroup_chat_created[$_INDEX_]="$(json $_UPDATE_.edited_channel_post.supergroup_chat_created)"
									;;
								'channel_chat_created')
									 edited_channel_post_channel_chat_created[$_INDEX_]="$(json $_UPDATE_.edited_channel_post.channel_chat_created)"
									;;
								'migrate_to_chat_id')
									 edited_channel_post_migrate_to_chat_id[$_INDEX_]="$(json $_UPDATE_.edited_channel_post.migrate_to_chat_id)"
									;;
								'migrate_from_chat_id')
									 edited_channel_post_migrate_from_chat_id[$_INDEX_]="$(json $_UPDATE_.edited_channel_post.migrate_from_chat_id)"
									;;
							esac
						done
						;;
					'callback_query')
						for _SUBKEY_ in $(json "$_UPDATE_.$_KEY_|keys|.[]")
						do
							case $_SUBKEY_ in
								'id')
									callback_query_id[$_INDEX_]="$(json $_UPDATE_.callback_query.id)"
									;;
								'chat_instance')
									callback_query_chat_instance[$_INDEX_]="$(json $_UPDATE_.callback_query.chat_instance)"
									;;
								'data')
									callback_query_data[$_INDEX_]="$(json $_UPDATE_.callback_query.data)"
									;;
								'from')
									callback_query_from_id[$_INDEX_]="$(json $_UPDATE_.callback_query.from.id)"
									callback_query_from_first_name[$_INDEX_]="$(json $_UPDATE_.callback_query.from.first_name)"
									callback_query_from_username[$_INDEX_]="$(json $_UPDATE_.callback_query.from.username)"
									callback_query_from_language_code[$_INDEX_]="$(json $_UPDATE_.callback_query.from.language_code)"
									;;
								'message')
									callback_query_message_message_id[$_INDEX_]="$(json $_UPDATE_.callback_query.message.message_id)"
									callback_query_message_from_id[$_INDEX_]="$(json $_UPDATE_.callback_query.message.from.id)"
									callback_query_message_from_first_name[$_INDEX_]="$(json $_UPDATE_.callback_query.message.from.first_name)"
									callback_query_message_from_username[$_INDEX_]="$(json $_UPDATE_.callback_query.message.from.username)"
									callback_query_message_chat_id[$_INDEX_]="$(json $_UPDATE_.callback_query.message.chat.id)"
									callback_query_message_chat_title[$_INDEX_]="$(json $_UPDATE_.callback_query.message.chat.title)"
									callback_query_message_chat_type[$_INDEX_]="$(json $_UPDATE_.callback_query.message.chat.type)"
									callback_query_message_date[$_INDEX_]="$(json $_UPDATE_.callback_query.message.date)"
									callback_query_message_text[$_INDEX_]="$(json $_UPDATE_.callback_query.message.text)"
									callback_query_message_edit_date[$_INDEX_]="$(json $_UPDATE_.callback_query.message.edit_date)"
									;;
							esac
						done			
					esac
				done
			done
		fi
	
	# Status
	return $_STATUS_
}

# Funções somente leitura
declare -rf json_status
declare -rf str_len
declare -rf message_error

# API
declare -rf ShellBot.regHandleFunction
declare -rf ShellBot.watchHandle

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
declare -rf ShellBot.InlineKeyboardMarkup
declare -rf ShellBot.InlineKeyboardButton
declare -rf ShellBot.answerCallbackQuery
declare -rf ShellBot.deleteMessage
declare -rf ShellBot.getUpdates
#FIM
