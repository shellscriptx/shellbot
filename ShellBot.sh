#!/bin/bash

#-----------------------------------------------------------------------------------------------------------
#	DATA:				07 de Março de 2017
#	SCRIPT:				ShellBot.sh
#	VERSÃO:				5.5
#	DESENVOLVIDO POR:	Juliano Santos [SHAMAN]
#	PÁGINA:				http://www.shellscriptx.blogspot.com.br
#	FANPAGE:			https://www.facebook.com/shellscriptx
#	GITHUB:				https://github.com/shellscriptx
# 	CONTATO:			shellscriptx@gmail.com
#
#	DESCRIÇÃO:			ShellBot é uma API não-oficial desenvolvida para facilitar a criação de 
#						bots na plataforma TELEGRAM. Constituída por uma coleção de métodos
#						e funções que permitem ao desenvolvedor:
#
#							* Gerenciar grupos, canais e membros.
#							* Enviar mensagens, documentos, músicas, contatos e etc.
#							* Enviar teclados (KeyboardMarkup e InlineKeyboard).
#							* Obter informações sobre membros, arquivos, grupos e canais.
#							* Para mais informações consulte a documentação:
#							  
#							https://github.com/shellscriptx/ShellBot/wiki
#
#						O ShellBot mantém o padrão da nomenclatura dos métodos registrados da
#						API original (Telegram), assim como seus campos e valores. Os métodos
#						requerem parâmetros e argumentos para a chamada e execução. Parâmetros
#						obrigatórios retornam uma mensagem de erro caso o argumento seja omitido.
#						
#	NOTAS:				Desenvolvida na linguagem Shell Script, utilizando o interpretador de 
#						comandos BASH e explorando ao máximo os recursos built-in do mesmo,
#						reduzindo o nível de dependências de pacotes externos.
#-----------------------------------------------------------------------------------------------------------

if [[ "${BASH_VERSINFO[0]},${BASH_VERSINFO[1]}" -lt 4,3 ]]; then
    echo "ShellBot: erro: requer 'bash v4.3.0' ou superior" 1>&2
    echo "atual: bash $BASH_VERSION" 1>&2
    exit 1
fi

# Verifica se os pacotes necessários estão instalados.
for _pkg_ in curl jq getopt; do
	# Se estiver ausente, trata o erro e finaliza o script.
	if ! which $_pkg_ &>/dev/null; then
		echo "ShellBot.sh: erro: '$_pkg_' O pacote requerido não está instalado." 1>&2
		exit 1	# Status
	fi
done

# Verifica se a API já foi instanciada.
[[ $_SHELLBOT_SH_ ]] && return 1

# Script que importou a API.
declare -r _BOT_SCRIPT_=$(basename "$0")

# API inicializada.
declare -r _SHELLBOT_SH_=1

# Desabilitar globbing
set -f

# curl parâmetros
declare -r _CURL_OPT_='--silent --request'

# Erros registrados da API (Parâmetros/Argumentos)
declare -r _ERR_TYPE_BOOL_='Tipo incompatível: suporta somente "true" ou "false".'
declare -r _ERR_TYPE_PARSE_MODE_='Formatação inválida: suporta somente "markdown" ou "html".'
declare -r _ERR_TYPE_INT_='Tipo incompatível: suporta somente inteiro.'
declare -r _ERR_TYPE_FLOAT_='Tipo incompatível: suporta somente float.'
declare -r _ERR_TYPE_POINT_='Máscara inválida: deve ser “forehead”, “eyes”, “mouth” ou “chin”.'
declare -r _ERR_ACTION_MODE_='Ação inválida: a definição da ação não é suportada.'
declare -r _ERR_PARAM_REQUIRED_='Opção requerida: verique se o(s) parâmetro(s) ou argumento(s) obrigatório(s) estão presente(s).'
declare -r _ERR_TOKEN_UNAUTHORIZED_='Não autorizado: verifique se possui permissões para utilizar o token.'
declare -r _ERR_TOKEN_INVALID_='Token inválido: verique o número do token e tente novamente.'
declare -r _ERR_FUNCTION_NOT_FOUND_='Função inválida: verique se o nome está correto ou se a função existe.'
declare -r _ERR_BOT_ALREADY_INIT_='Ação não permitida: o bot já foi inicializado.'
declare -r _ERR_FILE_NOT_FOUND_='Arquivo não encontrado: não foi possível ler o arquivo especificado.'
declare -r _ERR_DIR_WRITE_DENIED_='Permissão negada: não é possível gravar no diretório.'
declare -r _ERR_DIR_NOT_FOUND_='Não foi possível acessar: diretório não encontrado.'
declare -r _ERR_FILE_DOWNLOAD_='Falha no download: arquivo não encontrado.'
declare -r _ERR_FILE_INVALID_ID_='Id inválido: arquivo não encontrado.'
declare -r _ERR_UNKNOWN_='Erro desconhecido: ocorreu uma falha inesperada. Reporte o problema ao desenvolvedor.'
declare -r _ERR_SERVICE_NOT_ROOT_='Acesso negado: requer privilégios de root.'
declare -r _ERR_SERVICE_EXISTS_='Erro ao criar o serviço: o nome do serviço já existe.'
declare -r _ERR_SERVICE_SYSTEMD_NOT_FOUND_='Erro ao ativar: o sistema não possui suporte ao gerenciamento de serviços "systemd".'
declare -r _ERR_SERVICE_USER_NOT_FOUND_='Usuário não encontrado: a conta de usuário informada é inválida.'
declare -r _ERR_VAR_NAME_='o identificador da variável é inválido.'
declare -r _ERR_FLAG_TYPE_RETURN_='Tipo inválido: somente "json", "map" ou "value".'

Json() { local obj=$(jq "$1" <<< "${*:2}"); obj=${obj#\"}; echo "${obj%\"}"; }
JsonStatus(){ [[ $(jq -r '.ok' <<< "$*") == true ]] && return 0 || return 1; }

GetAllValues(){ 
	local obj=$(jq "[..|select(type == \"number\" or type == \"string\" or type == \"boolean\")|tostring]|join(\"${_BOT_DELM_/\"/\\\"}\")" <<< $*)
	obj=${obj#\"}; echo "${obj%\"}"
}

GetAllKeys(){
	local key; jq -r 'path(..)|map(if type == "number" then .|tostring|"["+.+"]" else . end)|join(".")|gsub(".\\[";"[")' <<< $* | \
	while read key; do [[ $(jq -r ".$key|type" <<< $*) == @(string|number|boolean) ]] && echo $key; done
}

CreateLog()
{
	local i fmt

	for ((i=0; i < $1; i++)); do
		printf -v fmt "$_BOT_LOG_FORMAT_" || MessageError API

		# FLAGS
		fmt=${fmt//\{OK\}/${return[ok]:-$ok}}
		fmt=${fmt//\{UPDATE_ID\}/${update_id[$i]}}
		fmt=${fmt//\{MESSAGE_ID\}/${return[message_id]:-${message_message_id[$i]:-${callback_query_id[$i]}}}}
		fmt=${fmt//\{FROM_ID\}/${return[from_id]:-${message_from_id[$i]:-${callback_query_from_id[$i]}}}}
		fmt=${fmt//\{FROM_IS_BOT\}/${return[from_is_bot]:-${message_from_is_bot[$i]:-${callback_query_from_is_bot[$i]}}}}
		fmt=${fmt//\{FROM_FIRST_NAME\}/${return[from_first_name]:-${message_from_firstname[$i]:-${callback_query_from_first_name[$i]}}}}
		fmt=${fmt//\{FROM_USERNAME\}/${return[from_username]:-${message_from_username[$i]:-${callback_query_from_username[$i]}}}}
		fmt=${fmt//\{FROM_LANGUAGE_CODE\}/${message_from_language_code[$i]:-${callback_query_from_language_code[$i]}}}
		fmt=${fmt//\{CHAT_ID\}/${return[chat_id]:-${message_chat_id[$i]:-${callback_query_message_chat_id[$i]}}}}
		fmt=${fmt//\{CHAT_TITLE\}/${return[chat_title]:-${message_chat_title[$i]:-${callback_query_message_chat_title[$i]}}}}
		fmt=${fmt//\{CHAT_TYPE\}/${return[chat_type]:-${message_chat_type[$i]:-${callback_query_message_chat_type[$i]}}}}
		fmt=${fmt//\{MESSAGE_DATE\}/${return[date]:-${message_date[$i]:-${callback_query_message_date[$i]}}}}
		fmt=${fmt//\{MESSAGE_TEXT\}/${return[text]:-${message_text[$i]:-${callback_query_message_text[$i]}}}}
		fmt=${fmt//\{ENTITIES_TYPE\}/${return[entities_type]:-${message_entities_type[$i]:-${callback_query_data[$i]}}}}
		fmt=${fmt//\{BOT_TOKEN\}/${_BOT_INFO_[0]}}
		fmt=${fmt//\{BOT_ID\}/${_BOT_INFO_[1]}}
		fmt=${fmt//\{BOT_FIRST_NAME\}/${_BOT_INFO_[2]}}
		fmt=${fmt//\{BOT_USERNAME\}/${_BOT_INFO_[3]}}
		fmt=${fmt//\{BASENAME\}/$_BOT_SCRIPT_}
		fmt=${fmt//\{METHOD\}/${FUNCNAME[2]/main/ShellBot.getUpdates}}
		fmt=${fmt//\{RETURN\}/$(GetAllValues ${*:2})}

		# log
		echo "$fmt" >> $_BOT_LOG_FILE_ || MessageError API
	done

	return $?
}

MethodReturn()
{
	shopt -s extglob

	# Retorno
	case $_BOT_TYPE_RETURN_ in
		json) echo "$*";;
		value) GetAllValues $*;;
		map)
			local key val obj
			declare -Ag return=() || MessageError API

			for obj in $(GetAllKeys $*); do
				key=${obj//\[+([0-9])\]/}
				key=${key#result.}
				key=${key//./_}

				val=$(Json ".$obj" $*)
				
				[[ ${return[$key]} ]] && return[$key]+=${_BOT_DELM_}${val} || return[$key]=$val
				[[ $_BOT_MONITOR_ ]] && printf "[%s]: return[%s] = '%s'\n" "${FUNCNAME[1]}" "$key" "$val"
			done
			;;
	esac
	
	[[ $_BOT_LOG_FILE_ ]] && CreateLog 1 $* &

	return 0
}

MessageError()
{
	# Variáveis locais
	local err_message err_param err_line err_func assert ind
	
	# A variável 'BASH_LINENO' é dinâmica e armazena o número da linha onde foi expandida.
	# Quando chamada dentro de um subshell, passa ser instanciada como um array, armazenando diversos
	# valores onde cada índice refere-se a um shell/subshell. As mesmas caracteristicas se aplicam a variável
	# 'FUNCNAME', onde é armazenado o nome da função onde foi chamada.
	
	# Obtem o índice da função na hierarquia de chamada.
	[[ ${FUNCNAME[1]} == CheckArgType ]] && ind=2 || ind=1
	err_line=${BASH_LINENO[$ind]}	# linha
	err_func=${FUNCNAME[$ind]}		# função
	
	# Lê o tipo de ocorrência.
	# TG - Erro externo retornado pelo core do telegram.
	# API - Erro interno gerado pela API do ShellBot.
	case $1 in
		TG)
			# arquivo Json
			err_param="$(Json '.error_code' ${*:2})"
			err_message="$(Json '.description' ${*:2})"
			;;
		API)
			err_param="${3:--}: ${4:--}"
			err_message="$2"
			assert=1
			;;
	esac

	# Imprime erro
	printf "%s: erro: linha %s: %s: %s: %s\n" "${_BOT_SCRIPT_}" \
												"${err_line:--}" \
												"${err_func:--}" \
												"${err_param:--}" \
												"${err_message:-$_ERR_UNKNOWN_}" 1>&2 

	# Finaliza script/thread em caso de erro interno, caso contrário retorna 1
	[[ $assert ]] && exit 1 || return 1
}

CheckArgType(){

	local ctype="$1"
	local param="$2"
	local value="$3"

	# CheckArgType recebe os dados da função chamadora e verifica
	# o dado recebido com o tipo suportado pelo parâmetro.
	# É retornado '0' para sucesso, caso contrário uma mensagem
	# de erro é retornada e o script/thread é finalizado com status '1'.
	
	case $ctype in
		var)		[[ $value =~ ^[a-zA-Z_]+[a-zA-Z0-9_]*$ ]]		|| MessageError API "$_ERR_VAR_NAME_" "$param" "$value";;
		int)		[[ $value =~ ^[0-9]+$ ]]						|| MessageError API "$_ERR_TYPE_INT_" "$param" "$value";;
		float)		[[ $value =~ ^-?[0-9]+\.[0-9]+$ ]]				|| MessageError API "$_ERR_TYPE_FLOAT_" "$param" "$value";;
		bool)		[[ $value =~ ^(true|false)$ ]]					|| MessageError API "$_ERR_TYPE_BOOL_" "$param" "$value";;
		token)		[[ $value =~ ^[0-9]+:[a-zA-Z0-9_-]+$ ]]			|| MessageError API "$_ERR_TOKEN_INVALID_" "$param" "$value";;
		file)		[[ $value =~ ^@ && ! -f ${value#@} ]]			&& MessageError API "$_ERR_FILE_NOT_FOUND_" "$param" "$value";;
		parsemode)	[[ $value =~ ^(markdown|html)$ ]]				|| MessageError API "$_ERR_TYPE_PARSE_MODE_" "$param" "$value";;
		point)		[[ $value =~ ^(forehead|eyes|mouth|chin)$ ]]	|| MessageError API "$_ERR_TYPE_POINT_" "$param" "$value";;
		action)		[[ $value =~ ^(typing|upload_photo|record_video)$ ]] || 
					[[ $value =~ ^(upload_video|record_audio|upload_audio)$ ]] || 
					[[ $value =~ ^(upload_document|find_location)$ ]] ||
					[[ $value =~ ^(record_video_note|upload_video_note)$ ]]	|| MessageError API "$_ERR_ACTION_MODE_" "$param" "$value";;
    esac

	return 0
}

FlushOffset()
{    
	local first_id last_id cod end jq_obj
	
	# Sem erro
	cod=0
	update_id=0
	
	while [[ $update_id ]]
	do
		# Lê as atualizações do offset atual. É possível listar no máximo 100 objetos por offset.
		if jq_obj=$(ShellBot.getUpdates --limit 100 --offset $(ShellBot.OffsetNext))
		then
			# Lê os IDs das atualizações disponíveis, salva o primeiro e último elemento da lista.
			# Interrompe o laço se não houver mais atualizações.
			unset update_id
			update_id=($(Json '.result|.[]|.update_id' $jq_obj))

			first_id=${first_id:-$update_id}
			end=$(ShellBot.OffsetEnd)
			((end > 0)) && last_id=$end
		else
			# Seta o erro e finaliza o laço em caso de falha na chamada do método.
			cod=1
			break
		fi	
	done
	
	# Retorna '0' se não houver registro.
	# Saída: 0|0
	echo "${first_id:-0}|${last_id:-0}"

	# Desativa a flag
	unset _FLUSH_OFFSET_

	# Status
	return $cod
}    

CreateUnitService()
{
	local service=${1%.*}.service
	local ok='\033[0;32m[OK]\033[0;m'
	local fail='\033[0;31m[FALHA]\033[0;m'
	
	((UID == 0)) || MessageError API "$_ERR_SERVICE_NOT_ROOT_"

	# O modo 'service' requer que o sistema de gerenciamento de processos 'systemd'
	# esteja presente para que o Unit target seja linkado ao serviço.
	if ! which systemctl &>/dev/null; then
		MessageError API "$_ERR_SERVICE_SYSTEMD_NOT_FOUND_"; fi


	# Se o serviço existe.
	test -e /lib/systemd/system/$service && \
	MessageError API "$_ERR_SERVICE_EXISTS_" "$service"

	# Gerando as configurações do target.
	cat > /lib/systemd/system/$service << _eof
[Unit]
Description=$1 - (SHELLBOT)
After=network-online.target

[Service]
User=$2
WorkingDirectory=$PWD
ExecStart=/bin/bash $1
ExecReload=/bin/kill -HUP \$MAINPID
ExecStop=/bin/kill -KILL \$MAINPID
KillMode=process
Restart=on-failure
RestartPreventExitStatus=255
Type=simple

[Install]
WantedBy=multi-user.target
_eof

	[[ $? -eq 0 ]] && {	
		
		printf '%s foi criado com sucesso !!\n' $service	
		echo -n "Habilitando..."
 		systemctl enable $service &>/dev/null && echo -e $ok || \
		{ echo -e $fail; MessageError API; }

		sed -i -r '/^\s*ShellBot.init\s/s/\s--?(s(ervice)?|u(ser)?\s+\w+)\b//g' "$1"
		systemctl daemon-reload

		echo -n "Iniciando..."
		systemctl start $service &>/dev/null && {
		
			echo -e $ok
			systemctl status $service
			echo -e "\nUso: sudo systemctl {start|stop|restart|reload|status} $service"
		
		} || echo -e $fail
	
	} || MessageError API

	exit 0
}

# Inicializa o bot, definindo sua API e _TOKEN_.
ShellBot.init()
{
	# Verifica se o bot já foi inicializado.
	[[ $_SHELLBOT_INIT_ ]] && MessageError API "$_ERR_BOT_ALREADY_INIT_"
	
	local enable_service user_unit _jq_bot_info method_return delm ret logfmt
	
	local param=$(getopt --name "$FUNCNAME" \
						 --options 't:mfsu:l:o:r:d:' \
						 --longoptions 'token:,
										monitor,
										flush,
										service,
										user:,
										log_file:,
										log_format:,
										return:,
										delimiter:' \
    					 -- "$@")
    
    # Define os parâmetros posicionais
    eval set -- "$param"
   
	while :
    do
    	case $1 in
    		-t|--token)
    			CheckArgType token "$1" "$2"
    			declare -gr _TOKEN_="$2"												# TOKEN
    			declare -gr _API_TELEGRAM_="https://api.telegram.org/bot$_TOKEN_"		# API
    			shift 2
   				;;
   			-m|--monitor)
				# Ativa modo monitor
   				declare -gr _BOT_MONITOR_=1
   				shift
   				;;
			-f|--flush)
				# Define a FLAG flush para o método 'ShellBot.getUpdates'. Se ativada, faz com que
				# o método obtenha somente as atualizações disponíveis, ignorando a extração dos
				# objetos JSON e a inicialização das variáveis.
				declare -x _FLUSH_OFFSET_=1
				shift
				;;
			-s|--service)
				enable_service=1
				shift
				;;
			-u|--user)
				if ! id "$2" &>/dev/null; then
					MessageError API "$_ERR_SERVICE_USER_NOT_FOUND_" "[-u, --user]" "$2"; fi

				user_unit="$2"
				shift 2
				;;
			-l|--log_file)
				declare -gr _BOT_LOG_FILE_=$2
				shift 2
				;;
			-o|--log_format)
				logfmt=$2
				shift 2
				;;
			-r|--return)
				[[ $2 == @(json|map|value) ]] || MessageError API "$_ERR_FLAG_TYPE_RETURN_" '[-r, --return]' "$2"
				ret=$2
				shift 2
				;;
			-d|--delimiter)
				delm=$2
				shift 2
				;;
   			--)
   				shift
   				break
   				;;
   		esac
   	done
  
   	# Parâmetro obrigatório.	
   	[[ $_TOKEN_ ]] || MessageError API "$_ERR_PARAM_REQUIRED_" "[-t, --token]"
	[[ $user_unit && ! $enable_service ]] && MessageError API "$_ERR_PARAM_REQUIRED_" "[-s, --service]" 
	[[ $enable_service ]] && CreateUnitService "$_BOT_SCRIPT_" "${user_unit:-$USER}"
		   
    # Um método simples para testar o token de autenticação do seu bot. 
    # Não requer parâmetros. Retorna informações básicas sobre o bot em forma de um objeto Usuário.
    
	ShellBot.getMe()
    {
    	# Chama o método getMe passando o endereço da API, seguido do nome do método.
    	local jq_obj=$(curl $_CURL_OPT_ GET $_API_TELEGRAM_/${FUNCNAME#*.})

    	_jq_bot_info=$jq_obj

		# Verifica o status de retorno do método
    	JsonStatus $jq_obj && MethodReturn $jq_obj || MessageError TG $jq_obj
    
    	return $?
    }

   	ShellBot.getMe &>/dev/null || MessageError API "$_ERR_TOKEN_UNAUTHORIZED_" '[-t, --token]'
	
	# Salva as informações do bot.
	_BOT_INFO_[0]=$_TOKEN_
	_BOT_INFO_[1]=$(Json '.result.id' $_jq_bot_info)
	_BOT_INFO_[2]=$(Json '.result.first_name' $_jq_bot_info)
	_BOT_INFO_[3]=$(Json '.result.username' $_jq_bot_info)

	# Configuração. (padrão)
	declare -gr _BOT_LOG_FORMAT_=${logfmt:-"%(%d/%m/%Y %H:%M:%S)T: {BASENAME}: {BOT_USERNAME}: {UPDATE_ID}: {METHOD}: {FROM_USERNAME}: {MESSAGE_TEXT}"}
	declare -gr _BOT_TYPE_RETURN_=${ret:-value}
	declare -gr _BOT_DELM_=${delm:-|}
	declare -gr _BOT_INFO_
	declare -gr _SHELLBOT_INIT_=1 
	
    # SHELLBOT (FUNÇÕES)
	# Inicializa as funções para chamadas aos métodos da API do telegram.
	ShellBot.ListUpdates(){ echo ${!update_id[@]}; }
	ShellBot.TotalUpdates(){ echo ${#update_id[@]}; }
	ShellBot.OffsetEnd(){ local -i offset=${update_id[@]: -1}; echo $offset; }
	ShellBot.OffsetNext(){ echo $(($(ShellBot.OffsetEnd)+1)); }
   	
	ShellBot.token() { echo "${_BOT_INFO_[0]}"; }
	ShellBot.id() { echo "${_BOT_INFO_[1]}"; }
	ShellBot.first_name() { echo "${_BOT_INFO_[2]}"; }
	ShellBot.username() { echo "${_BOT_INFO_[3]}"; }
  
    ShellBot.regHandleFunction()
    {
    	local function callback_data handle args
    
    	local param=$(getopt --name "$FUNCNAME" \
							 --options 'f:a:d:' \
							 --longoptions 'function:,
											args:,
											callback_data:' \
							 -- "$@")
    
    	eval set -- "$param"
    		
    	while :
    	do
    		case $1 in
    			-f|--function)
    				# Verifica se a função especificada existe.
    				if ! declare -fp $2 &>/dev/null; then
    					MessageError API "$_ERR_FUNCTION_NOT_FOUND_" "$1" "$2"
    					return 1
    				fi
    				function="$2"
    				shift 2
    				;;
    			-a|--args)
    				args="$2"
    				shift 2
    				;;
    			-d|--callback_data)
    				callback_data="$2"
    				shift 2
    				;;
    			--)
    				shift
    				break
    				;;
    		esac
    	done
    	
    	[[ $function ]] || MessageError API "$_ERR_PARAM_REQUIRED_" "[-f, --function]"
    	[[ $callback_data ]] || MessageError API "$_ERR_PARAM_REQUIRED_" "[-d, --callback_data]"
    
    	declare -Ag _reg_func_handle_list_
    	_reg_func_handle_list_[$callback_data]+="$function $args|"

    	return 0
    }
    
    ShellBot.watchHandle()
    {
    	local 	callback_data func func_handle \
    			param=$(getopt --name "$FUNCNAME" \
								--options 'd' \
								--longoptions 'callback_data' \
								-- "$@")
    
    	eval set -- "$param"
    
    	while :
    	do
    		case $1 in
    			-d|--callback_data)
    				shift 2
    				callback_data="$1"
    				;;
    			*)
    				shift
    				break
    				;;
    		esac
    	done
    	
    	# O parâmetro callback_data é parcial, ou seja, Se o handle for válido, os elementos
    	# serão listados. Caso contrário a função é finalizada.
    	[[ $callback_data ]] || return 1
   	
		while read -d'|' func; do $func
		done <<< ${_reg_func_handle_list_[$callback_data]}
    
    	# retorno
    	return 0
    }
    
    ShellBot.getWebhookInfo()
    {
    	# Variável local
    	local jq_obj
	
    	# Chama o método getMe passando o endereço da API, seguido do nome do método.
    	jq_obj=$(curl $_CURL_OPT_ GET $_API_TELEGRAM_/${FUNCNAME#*.})
    	
    	# Verifica o status de retorno do método
    	JsonStatus $jq_obj && MethodReturn $jq_obj || MessageError TG $jq_obj
    	
    	return $?
    }
    
    ShellBot.deleteWebhook()
    {
    	# Variável local
    	local jq_obj
	
    	# Chama o método getMe passando o endereço da API, seguido do nome do método.
    	jq_obj=$(curl $_CURL_OPT_ POST $_API_TELEGRAM_/${FUNCNAME#*.})
    	
    	# Verifica o status de retorno do método
    	JsonStatus $jq_obj && MethodReturn $jq_obj || MessageError TG $jq_obj
    	
    	return $?
    }
    
    ShellBot.setWebhook()
    {
    	local url certificate max_connections allowed_updates jq_obj
    	
    	local param=$(getopt --name "$FUNCNAME" \
							 --options 'u:c:m:a:' \
							 --longoptions 'url:, 
    										certificate:,
    										max_connections:,
    										allowed_updates:' \
    						 -- "$@")
    	
    	eval set -- "$param"
    	
    	while :
    	do
    		case $1 in
    			-u|--url)
    				url="$2"
    				shift 2
    				;;
    			-c|--certificate)
					CheckArgType file "$1" "$2"
    				certificate="$2"
    				shift 2
    				;;
    			-m|--max_connections)
    				CheckArgType int "$1" "$2"
    				max_connections="$2"
    				shift 2
    				;;
    			-a|--allowed_updates)
    				allowed_updates="$2"
    				shift 2
    				;;
    			--)
    				shift 
    				break
    				;;
    		esac
    	done
    	
    	[[ $url ]] || MessageError API "$_ERR_PARAM_REQUIRED_" "[-u, --url]"
    
    	jq_obj=$(curl $_CURL_OPT_ POST $_API_TELEGRAM_/${FUNCNAME#*.} ${url:+-d url="$url"} \
    								 ${certificate:+-d certificate="$certificate"} \
    								 ${max_connections:+-d max_connections="$max_connections"} \
    								 ${allowed_updates:+-d allowed_updates="$allowed_updates"})
    
    	# Testa o retorno do método.
    	JsonStatus $jq_obj && MethodReturn $jq_obj || MessageError TG $jq_obj
    	
    	# Status
    	return $?
    }	
    
    ShellBot.setChatPhoto()
    {
    	local chat_id photo jq_obj
    	
    	local param=$(getopt --name "$FUNCNAME" \
							 --options 'c:p:' \
							 --longoptions 'chat_id:,photo:' \
							 -- "$@")
    	
    	eval set -- "$param"
    	
    	while :
    	do
    		case $1 in
    			-c|--chat_id)
    				chat_id="$2"
    				shift 2
    				;;
    			-p|--photo)
					CheckArgType file "$1" "$2"
    				photo="$2"
    				shift 2
    				;;
    			--)
    				shift
    				break
    				;;
    		esac
    	done
    	
    	[[ $chat_id ]] || MessageError API "$_ERR_PARAM_REQUIRED_" "[-c, --chat_id]"
    	[[ $photo ]] || MessageError API "$_ERR_PARAM_REQUIRED_" "[-p, --photo]"
    	
    	jq_obj=$(curl $_CURL_OPT_ POST $_API_TELEGRAM_/${FUNCNAME#*.} ${chat_id:+-F chat_id="$chat_id"} \
    								 ${photo:+-F photo="$photo"})
    
    	JsonStatus $jq_obj || MessageError TG $jq_obj
    		
    	# Status
    	return $?
    }
    
    ShellBot.deleteChatPhoto()
    {
    	local chat_id jq_obj
    	
    	local param=$(getopt --name "$FUNCNAME" \
							 --options 'c:' \
							 --longoptions 'chat_id:' \
							 -- "$@")
    	
    	eval set -- "$param"
    	
    	while :
    	do
    		case $1 in
    			-c|--chat_id)
    				chat_id="$2"
    				shift 2
    				;;
    			--)
    				shift
    				break
    				;;
    		esac
    	done
    	
    	[[ $chat_id ]] || MessageError API "$_ERR_PARAM_REQUIRED_" "[-c, --chat_id]"
    	
    	jq_obj=$(curl $_CURL_OPT_ POST $_API_TELEGRAM_/${FUNCNAME#*.} ${chat_id:+-d chat_id="$chat_id"})
    
		JsonStatus $jq_obj && MethodReturn $jq_obj || MessageError TG $jq_obj
    	
		# Status
    	return $?
    
    }
    
    ShellBot.setChatTitle()
    {
    	
    	local chat_id title jq_obj
    	
    	local param=$(getopt --name "$FUNCNAME" \
							 --options 'c:t:' \
							 --longoptions 'chat_id:,title:' \
							 -- "$@")
    	
    	eval set -- "$param"
    	
    	while :
    	do
    		case $1 in
    			-c|--chat_id)
    				chat_id="$2"
    				shift 2
    				;;
    			-t|--title)
    				title="$2"
    				shift 2
    				;;
    			--)
    				shift
    				break
    				;;
    		esac
    	done
    	
    	[[ $chat_id ]] || MessageError API "$_ERR_PARAM_REQUIRED_" "[-c, --chat_id]"
    	[[ $title ]] || MessageError API "$_ERR_PARAM_REQUIRED_" "[-t, --title]"
    	
    	jq_obj=$(curl $_CURL_OPT_ POST $_API_TELEGRAM_/${FUNCNAME#*.} ${chat_id:+-d chat_id="$chat_id"} \
    								 ${title:+-d title="$title"})
    
		JsonStatus $jq_obj && MethodReturn $jq_obj || MessageError TG $jq_obj
    	
		# Status
    	return $?
    }
    
    
    ShellBot.setChatDescription()
    {
    	
    	local chat_id description jq_obj
    	
    	local param=$(getopt --name "$FUNCNAME" \
							 --options 'c:d:' \
							 --longoptions 'chat_id:,description:' \
							 -- "$@")
    	
    	eval set -- "$param"
    	
    	while :
    	do
    		case $1 in
    			-c|--chat_id)
    				chat_id="$2"
    				shift 2
    				;;
    			-d|--description)
    				description="$2"
    				shift 2
    				;;
    			--)
    				shift
    				break
    				;;
    		esac
    	done
    	
    	[[ $chat_id ]] || MessageError API "$_ERR_PARAM_REQUIRED_" "[-c, --chat_id]"
    	[[ $description ]] || MessageError API "$_ERR_PARAM_REQUIRED_" "[-d, --description]"
    	
    	jq_obj=$(curl $_CURL_OPT_ POST $_API_TELEGRAM_/${FUNCNAME#*.} ${chat_id:+-d chat_id="$chat_id"} \
    								 ${description:+-d description="$description"})
    
		JsonStatus $jq_obj && MethodReturn $jq_obj || MessageError TG $jq_obj
    		
    	# Status
    	return $?
    }
    
    ShellBot.pinChatMessage()
    {
    	
    	local chat_id message_id disable_notification jq_obj
    	
    	local param=$(getopt --name "$FUNCNAME" \
							 --options 'c:m:n:' \
							 --longoptions 'chat_id:,
											message_id:,
    										disable_notification:' \
    						 -- "$@")
    	
    	eval set -- "$param"
    	
    	while :
    	do
    		case $1 in
    			-c|--chat_id)
    				chat_id="$2"
    				shift 2
    				;;
    			-m|--message_id)
    				CheckArgType int "$1" "$2"
    				message_id="$2"
    				shift 2
    				;;
    			-n|--disable_notification)
    				CheckArgType bool "$1" "$2"
    				disable_notification="$2"
    				shift 2
    				;;	
    			--)
    				shift
    				break
    				;;
    		esac
    	done
    	
    	[[ $chat_id ]] || MessageError API "$_ERR_PARAM_REQUIRED_" "[-c, --chat_id]"
    	[[ $message_id ]] || MessageError API "$_ERR_PARAM_REQUIRED_" "[-m, --message_id]"
    	
    	jq_obj=$(curl $_CURL_OPT_ POST $_API_TELEGRAM_/${FUNCNAME#*.} ${chat_id:+-d chat_id="$chat_id"} \
    								 ${message_id:+-d message_id="$message_id"} \
    								 ${disable_notification:+-d disable_notification="$disable_notification"})
    
		JsonStatus $jq_obj && MethodReturn $jq_obj || MessageError TG $jq_obj
    		
    	# Status
    	return $?
    }
    
    ShellBot.unpinChatMessage()
    {
    	local chat_id jq_obj
    	
    	local param=$(getopt --name "$FUNCNAME" \
							 --options 'c:' \
							 --longoptions 'chat_id:' \
							 -- "$@")
    	
    	eval set -- "$param"
    	
    	while :
    	do
    		case $1 in
    			-c|--chat_id)
    				chat_id="$2"
    				shift 2
    				;;
    			--)
    				shift
    				break
    				;;
    		esac
    	done
    	
    	[[ $chat_id ]] || MessageError API "$_ERR_PARAM_REQUIRED_" "[-c, --chat_id]"
    	
    	jq_obj=$(curl $_CURL_OPT_ POST $_API_TELEGRAM_/${FUNCNAME#*.} ${chat_id:+-d chat_id="$chat_id"})
    
		JsonStatus $jq_obj && MethodReturn $jq_obj || MessageError TG $jq_obj
    		
    	# Status
    	return $?
    }
    
    ShellBot.restrictChatMember()
    {
    	local	chat_id user_id until_date can_send_messages \
    			can_send_media_messages can_send_other_messages \
    			can_add_web_page_previews jq_obj
    
    	local param=$(getopt --name "$FUNCNAME" \
							 --options 'c:u:d:s:m:o:w:' \
    						 --longoptions 'chat_id:,
    										user_id:,
    										until_date:,
    										can_send_messages:,
    										can_send_media_messages:,
    										can_send_other_messages:,
    										can_add_web_page_previews:' \
							 -- "$@")
    	
    	eval set -- "$param"
    	
    	while :
    	do
    		case $1 in
    			-c|--chat_id)
    				chat_id="$2"
    				shift 2
    				;;
    			-u|--user_id)
    				CheckArgType int "$1" "$2"
    				user_id="$2"
    				shift 2
    				;;
    			-d|--until_date)
    				CheckArgType int "$1" "$2"
    				until_date="$2"
    				shift 2
    				;;
    			-s|--can_send_messages)
    				CheckArgType bool "$1" "$2"
    				can_send_messages="$2"
    				shift 2
    				;;
    			-m|--can_send_media_messages)
    				CheckArgType bool "$1" "$2"
    				can_send_media_messages="$2"
    				shift 2
    				;;
    			-o|--can_send_other_messages)
    				CheckArgType bool "$1" "$2"
    				can_send_other_messages="$2"
    				shift 2
    				;;
    			-w|--can_add_web_page_previews)
    				CheckArgType bool "$1" "$2"
    				can_add_web_page_previews="$2"
    				shift 2
    				;;				
    			--)
    				shift
    				break
    				;;
    		esac
    	done
    	
    	[[ $chat_id ]] || MessageError API "$_ERR_PARAM_REQUIRED_" "[-c, --chat_id]"
    	[[ $user_id ]] || MessageError API "$_ERR_PARAM_REQUIRED_" "[-c, --user_id]"
    	
    	jq_obj=$(curl $_CURL_OPT_ POST $_API_TELEGRAM_/${FUNCNAME#*.} ${chat_id:+-d chat_id="$chat_id"} \
    								 ${user_id:+-d user_id="$user_id"} \
    								 ${until_date_:+-d until_date="$until_date"} \
    								 ${can_send_messages:+-d can_send_messages="$can_send_messages"} \
    								 ${can_send_media_messages:+-d can_send_media_messages="$can_send_media_messages"} \
    								 ${can_send_other_messages:+-d can_send_other_messages="$can_send_other_messages"} \
    								 ${can_add_web_page_previews:+-d can_add_web_page_previews="$can_add_web_page_previews"})
    
		JsonStatus $jq_obj && MethodReturn $jq_obj || MessageError TG $jq_obj
    		
    	# Status
    	return $?
    	
    }
    
    
    ShellBot.promoteChatMember()
    {
    	local	chat_id user_id can_change_info can_post_messages \
    			can_edit_messages can_delete_messages can_invite_users \
    			can_restrict_members can_pin_messages can_promote_members \
				jq_obj
    
    	local param=$(getopt --name "$FUNCNAME" \
							 --options 'c:u:i:p:e:d:v:r:f:m:' \
							 --longoptions 'chat_id:,
    										user_id:,
    										can_change_info:,
    										can_post_messages:,
    										can_edit_messages:,
    										can_delete_messages:,
    										can_invite_users:,
    										can_restrict_members:,
    										can_pin_messages:,
    										can_promote_members:' \
							 -- "$@")
    	
    	eval set -- "$param"
    	
    	while :
    	do
    		case $1 in
    			-c|--chat_id)
    				chat_id="$2"
    				shift 2
    				;;
    			-u|--user_id)
    				CheckArgType int "$1" "$2"
    				user_id="$2"
    				shift 2
    				;;
    			-i|--can_change_info)
    				CheckArgType bool "$1" "$2"
    				can_change_info="$2"
    				shift 2
    				;;
    			-p|--can_post_messages)
    				CheckArgType bool "$1" "$2"
    				can_post_messages="$2"
    				shift 2
    				;;
    			-e|--can_edit_messages)
    				CheckArgType bool "$1" "$2"
    				can_edit_messages="$2"
    				shift 2
    				;;
    			-d|--can_delete_messages)
    				CheckArgType bool "$1" "$2"
    				can_delete_messages="$2"
    				shift 2
    				;;
    			-v|--can_invite_users)
    				CheckArgType bool "$1" "$2"
    				can_invite_users="$2"
    				shift 2
    				;;
    			-r|--can_restrict_members)
    				CheckArgType bool "$1" "$2"
    				can_restrict_members="$2"
    				shift 2
    				;;
    			-f|--can_pin_messages)
    				CheckArgType bool "$1" "$2"
    				can_pin_messages="$2"
    				shift 2
    				;;	
    			-m|--can_promote_members)
    				CheckArgType bool "$1" "$2"
    				can_promote_members="$2"
    				shift 2
    				;;
    			--)
    				shift
    				break
    				;;
    		esac
    	done
    	
    	[[ $chat_id ]] || MessageError API "$_ERR_PARAM_REQUIRED_" "[-c, --chat_id]"
    	[[ $user_id ]] || MessageError API "$_ERR_PARAM_REQUIRED_" "[-c, --user_id]"
    	
    	jq_obj=$(curl $_CURL_OPT_ POST $_API_TELEGRAM_/${FUNCNAME#*.} ${chat_id:+-d chat_id="$chat_id"} \
    								 ${user_id:+-d user_id="$user_id"} \
    								 ${can_change_info:+-d can_change_info="$can_change_info"} \
    								 ${can_post_messages:+-d can_post_messages="$can_post_messages"} \
    								 ${can_edit_messages:+-d can_edit_messages="$can_edit_messages"} \
    								 ${can_delete_messages:+-d can_delete_messages="$can_delete_messages"} \
    								 ${can_invite_users:+-d can_invite_users="$can_invite_users"} \
    								 ${can_restrict_members:+-d can_restrict_members="$can_restrict_members"} \
    								 ${can_pin_messages:+-d can_pin_messages="$can_pin_messages"} \
    								 ${can_promote_members:+-d can_promote_members="$can_promote_members"})
    
		JsonStatus $jq_obj && MethodReturn $jq_obj || MessageError TG $jq_obj
    		
    	# Status
    	return $?
    }
    
    ShellBot.exportChatInviteLink()
    {
    	local chat_id jq_obj
    
    	local param=$(getopt --name "$FUNCNAME" \
							 --options 'c:' \
							 --longoptions 'chat_id:' \
							 -- "$@")
    	
    	eval set -- "$param"
    
    	while :
    	do
    		case $1 in
    			-c|--chat_id)
    				chat_id="$2"
    				shift 2
    				;;
    			--)
    				shift
    				break
    				;;
    		esac
    	done
    
    	[[ $chat_id ]] || MessageError API "$_ERR_PARAM_REQUIRED_" "[-c, --chat_id]"
    	
    	jq_obj=$(curl $_CURL_OPT_ GET $_API_TELEGRAM_/${FUNCNAME#*.} ${chat_id:+-d chat_id="$chat_id"})
    	
    	# Testa o retorno do método.
    	JsonStatus $jq_obj && MethodReturn $jq_obj || MessageError TG $jq_obj
    		
    	# Status
    	return $?
    }
    
    ShellBot.sendVideoNote()
    {
    	local chat_id video_note duration length disable_notification \
    			reply_to_message_id reply_markup jq_obj
    
    	local param=$(getopt --name "$FUNCNAME" \
							 --options 'c:v:t:l:n:r:m:s:' \
							 --longoptions 'chat_id:,
    										video_note:,
    										duration:,
    										length:,
    										disable_notification:,
    										reply_to_message_id:,
    										reply_markup:' \
    						 -- "$@")
    	
    	# Define os parâmetros posicionais
    	eval set -- "$param"
    	
    	while :
    	do
    		case $1 in
    			-c|--chat_id)
    				chat_id="$2"
    				shift 2
    				;;
    			-v|--video_note)
					CheckArgType file "$1" "$2"
    				video_note="$2"
    				shift 2
    				;;
    			-t|--duration)
    				CheckArgType int "$1" "$2"
    				duration="$2"
    				shift 2
    				;;
    			-l|--length)
    				CheckArgType int "$1" "$2"
    				length="$2"
    				shift 2
    				;;
    			-n|--disable_notification)
    				CheckArgType bool "$1" "$2"
    				disable_notification="$2"
    				shift 2
    				;;
    			-r|--reply_to_message_id)
    				CheckArgType int "$1" "$2"
    				reply_to_message_id="$2"
    				shift 2
    				;;
    			-m|--reply_markup)
    				reply_markup="$2"
    				shift 2
    				;;
    			--)
    				shift
    				break
    				;;
    		esac
    	done
    	
    	[[ $chat_id ]] || MessageError API "$_ERR_PARAM_REQUIRED_" "[-c, --chat_id]"
    	[[ $video_note ]] || MessageError API "$_ERR_PARAM_REQUIRED_" "[-v, --video_note]"
    	
    	jq_obj=$(curl $_CURL_OPT_ POST $_API_TELEGRAM_/${FUNCNAME#*.} ${chat_id:+-F chat_id="$chat_id"} \
    								 ${video_note:+-F video_note="$video_note"} \
    								 ${duration:+-F duration="$duration"} \
    								 ${length:+-F length="$length"} \
    								 ${disable_notification:+-F disable_notification="$disable_notification"} \
    								 ${reply_to_message_id:+-F reply_to_message_id="$reply_to_message_id"} \
    								 ${reply_markup:+-F reply_markup="$reply_markup"})
    
    	# Testa o retorno do método.
    	JsonStatus $jq_obj && MethodReturn $jq_obj || MessageError TG $jq_obj
    	
    	# Status
    	return $?
    }
    
    
    ShellBot.InlineKeyboardButton()
    {
        local 	__button __line __text __url __callback_data \
                __switch_inline_query __switch_inline_query_current_chat \
    			__delm
    
        local __param=$(getopt --name "$FUNCNAME" \
							 --options 'b:l:t:u:c:q:s:' \
							 --longoptions 'button:,
											line:,
											text:,
											url:,
											callback_data:,
											switch_inline_query:,
											switch_inline_query_chat:' \
							 -- "$@")
    
    	eval set -- "$__param"
    
    	while :
    	do
    		case $1 in
    			-b|--button)
    				# Ponteiro que recebe o endereço de "button" com as definições
    				# da configuração do botão inserido.
					CheckArgType var "$1" "$2"
    				__button="$2"
    				shift 2
    				;;
    			-l|--line)
    				CheckArgType int "$1" "$2"
    				__line="$2"
    				shift 2
    				;;
    			-t|--text)
    				__text="$2"
    				shift 2
    				;;
    			-u|--url)
    				__url="$2"
    				shift 2
    				;;
    			-c|--callback_data)
    				__callback_data="$2"
    				shift 2
    				;;
    			-q|--switch_inline_query)
    				__switch_inline_query="$2"
    				shift 2
    				;;
    			-s|--switch_inline_query_current_chat)
    				__switch_inline_query_current_chat="$2"
    				shift 2
    				;;
    			--)
    				shift
    				break
    				;;
    		esac
    	done
    
    	[[ $__button ]] || MessageError API "$_ERR_PARAM_REQUIRED_" "[-b, --button]"
    	[[ $__text ]] || MessageError API "$_ERR_PARAM_REQUIRED_" "[-t, --text]"
    	[[ $__callback_data ]] || MessageError API "$_ERR_PARAM_REQUIRED_" "[-c, --callback_data]"
    	[[ $__line ]] || MessageError API "$_ERR_PARAM_REQUIRED_" "[-l, --line]"
    	
    	# Inicializa a variável armazenada em button, definindo seu
    	# escopo como global, tornando-a visível em todo o projeto (source)
    	# O ponteiro button recebe o endereço do botão armazenado.
		declare -n __button	# Ponteiro
    	
    	# Abre o array para receber o novo objeto
    	__button[$__line]="${__button[$__line]#[}"
    	__button[$__line]="${__button[$__line]%]}"
    
    	# Verifica se já existe um botão na linha especificada.
    	[[ ${__button[$__line]} ]] && __delm=','
    
    	# Salva as configurações do botão.
    	#
    	# Obrigatório: text, callback_data 
    	# Opcional: url, switch_inline_query, switch_inline_query_current_chat
    	__button[$__line]+="$__delm{ 
    					\"text\":\"$__text\",
						\"callback_data\":\"$__callback_data\"
						${__url:+,\"url\":\"$__url\"}
						${__switch_inline_query:+,\"switch_inline_query\":\"$__switch_inline_query\"}
						${__switch_inline_query_current_chat:+,\"switch_inline_query_current_chat\":\"$__switch_inline_query_current_chat\"}
						}" || return 1	# Erro ao salvar o botão. 
    	
    	# Fecha o array
    	__button[$__line]="${__button[$__line]/#/[}"
    	__button[$__line]="${__button[$__line]/%/]}"
    
    	# retorno
    	return 0
    }
    
    ShellBot.InlineKeyboardMarkup()
    {
    	local __button __keyboard

        local __param=$(getopt --name "$FUNCNAME" \
							 --options 'b:' \
							 --longoptions 'button:' \
							 -- "$@")
    
    	eval set -- "$__param"
    
    	while :
    	do
    		case $1 in
    			-b|--button)
    				# Ponteiro que recebe o endereço da variável "teclado" com as definições
    				# de configuração do botão inserido.
					CheckArgType var "$1" "$2"
    				__button="$2"
    				shift 2
    				;;
    			--)
    				shift
    				break
    				;;
    		esac
    	done
    	
    	[[ $__button ]] || MessageError API "$_ERR_PARAM_REQUIRED_" "[-b, --button]"
    	
    	# Ponteiro
    	declare -n __button
    
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
    	
    	__keyboard="${__button[@]}" || return 1
    	
    	# Cria estrutura do teclado
    	__keyboard="${__keyboard/#/{\"inline_keyboard\":[}"
    	__keyboard="${__keyboard//]/],}"					
    	__keyboard="${__keyboard%,}"						
    	__keyboard="${__keyboard/%/]\}}"					
    
    	# Retorna a estrutura	
    	echo $__keyboard
    
    	# status
    	return 0
    }
    
    ShellBot.answerCallbackQuery()
    {
    	local callback_query_id text show_alert url cache_time jq_obj
    	
    	local param=$(getopt --name "$FUNCNAME" \
							 --options 'c:t:s:u:e:' \
    						 --longoptions 'callback_query_id:,
    										text:,
    										show_alert:,
    										url:,
    										cache_time:' \
    						 -- "$@")
    
    
    	eval set -- "$param"
    	
    	while :
    	do
    		case $1 in
    			-c|--callback_query_id)
    				callback_query_id="$2"
    				shift 2
    				;;
    			-t|--text)
    				text="$2"
    				shift 2
    				;;
    			-s|--show_alert)
    				# boolean
    				CheckArgType bool "$1" "$2"
    				show_alert="$2"
    				shift 2
    				;;
    			-u|--url)
    				url="$2"
    				shift 2
    				;;
    			-e|--cache_time)
    				# inteiro
    				CheckArgType int "$1" "$2"
    				cache_time="$2"
    				shift 2
    				;;
    			--)
    				shift
    				break
    				;;
    		esac
    	done
    	
    	[[ $callback_query_id ]] || MessageError API "$_ERR_PARAM_REQUIRED_" "[-c, --callback_query_id]"
    	
    	jq_obj=$(curl $_CURL_OPT_ POST $_API_TELEGRAM_/${FUNCNAME#*.} ${callback_query_id:+-d callback_query_id="$callback_query_id"} \
    								 ${text:+-d text="$text"} \
    								 ${show_alert:+-d show_alert="$show_alert"} \
    								 ${url:+-d url="$url"} \
    								 ${cache_time:+-d cache_time="$cache_time"})
    
		JsonStatus $jq_obj && MethodReturn $jq_obj || MessageError TG $jq_obj
    
    	return $?
    }
    
    # Cria objeto que representa um teclado personalizado com opções de resposta
    ShellBot.ReplyKeyboardMarkup()
    {
    	# Variáveis locais
    	local __button __resize_keyboard __on_time_keyboard __selective
    	
    	# Lê os parâmetros da função.
    	local __param=$(getopt --name "$FUNCNAME" \
							 --options 'b:r:t:s:' \
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
    	eval set -- "$__param"
    	
    	# Aguarda leitura dos parâmetros
    	while :
    	do
    		# Lê o parâmetro da primeira posição "$1"; Se for um parâmetro válido,
    		# salva o valor do argumento na posição '$2' e desloca duas posições a esquerda (shift 2); Repete o processo
    		# até que o valor de '$1' seja igual '--' e finaliza o loop.
    		case $1 in
    			-b|--button)
					CheckArgType var "$1" "$2"
    				__button="$2"
    				shift 2
    				;;
    			-r|--resize_keyboard)
    				# Tipo: boolean
    				CheckArgType bool "$1" "$2"
    				__resize_keyboard="$2"
    				shift 2
    				;;
    			-t|--one_time_keyboard)
    				# Tipo: boolean
    				CheckArgType bool "$1" "$2"
    				__on_time_keyboard="$2"
    				shift 2
    				;;
    			-s|--selective)
    				# Tipo: boolean
    				CheckArgType bool "$1" "$2"
    				__selective="$2"
    				shift 2
    				;;
    			--)
    				shift
    				break
    				;;
    		esac
    	done
    	
    	# Imprime mensagem de erro se o parâmetro obrigatório for omitido.
    	[[ $__button ]] || MessageError API "$_ERR_PARAM_REQUIRED_" "[-b, --button]"
    
    	# Ponteiro	
    	declare -n __button
    
    	# Constroi a estrutura dos objetos + array keyboard, define os valores e salva as configurações.
    	# Por padrão todos os valores são 'false', até que seja definido.
    	cat << _EOF
{"keyboard":$__button,
"resize_keyboard":${__resize_keyboard:-false},
"one_time_keyboard":${__on_time_keyboard:-false},
"selective": ${__selective:-false}}
_EOF
    
    	# status
    	return 0
    }
    
    # Envia mensagens 
    ShellBot.sendMessage()
    {
    	# Variáveis locais 
    	local chat_id text parse_mode disable_web_page_preview
		local disable_notification reply_to_message_id reply_markup jq_obj
    	
    	# Lê os parâmetros da função
    	local param=$(getopt --name "$FUNCNAME" \
							 --options 'c:t:p:w:n:r:k:' \
							 --longoptions 'chat_id:,
    										text:,
    										parse_mode:,
    										disable_web_page_preview:,
    										disable_notification:,
    										reply_to_message_id:,
    										reply_markup:' \
    						 -- "$@")
    
    	# Define os parâmetros posicionais
    	eval set -- "$param"
    	
    	while :
    	do
    		case $1 in
    			-c|--chat_id)
    				chat_id="$2"
    				shift 2
    				;;
    			-t|--text)
    				text="$2"
    				shift 2
    				;;
    			-p|--parse_mode)
    				# Tipo: "markdown" ou "html"
    				CheckArgType parsemode "$1" "$2"
    				parse_mode="$2"
    				shift 2
    				;;
    			-w|--disable_web_page_preview)
    				# Tipo: boolean
    				CheckArgType bool "$1" "$2"
    				disable_web_page_preview="$2"
    				shift 2
    				;;
    			-n|--disable_notification)
    				# Tipo: boolean
    				CheckArgType bool "$1" "$2"
    				disable_notification="$2"
    				shift 2
    				;;
    			-r|--reply_to_message_id)
    				# Tipo: inteiro
    				CheckArgType int "$1" "$2"
    				reply_to_message_id="$2"
    				shift 2
    				;;
    			-k|--reply_markup)
    				reply_markup="$2"
    				shift 2
    				;;
    			--)
    				shift
    				break
    				;;
    		esac
    	done
    
    	# Parâmetros obrigatórios.
    	[[ $chat_id ]] || MessageError API "$_ERR_PARAM_REQUIRED_" "[-c, --chat_id]"
    	[[ $text ]] || MessageError API "$_ERR_PARAM_REQUIRED_" "[-t, --text]"
    
    	# Chama o método da API, utilizando o comando request especificado; Os parâmetros 
    	# e valores são passados no form e lidos pelo método. O retorno do método é redirecionado para o arquivo 'update.Json'.
    	# Variáveis com valores nulos são ignoradas e consequentemente os respectivos parâmetros omitidos.
    	jq_obj=$(curl $_CURL_OPT_ POST $_API_TELEGRAM_/${FUNCNAME#*.} ${chat_id:+-d chat_id="$chat_id"} \
    								 ${text:+-d text="$text"} \
    								 ${parse_mode:+-d parse_mode="$parse_mode"} \
    								 ${disable_web_page_preview:+-d disable_web_page_preview="$disable_web_page_preview"} \
    								 ${disable_notification:+-d disable_notification="$disable_notification"} \
    								 ${reply_to_message_id:+-d reply_to_message_id="$reply_to_message_id"} \
    								 ${reply_markup:+-d reply_markup="$reply_markup"})
   
    	# Testa o retorno do método.
    	JsonStatus $jq_obj && MethodReturn $jq_obj || MessageError TG $jq_obj
    	
    	# Status
    	return $?
    }
    
    # Função para reencaminhar mensagens de qualquer tipo.
    ShellBot.forwardMessage()
    {
    	# Variáveis locais
    	local chat_id form_chat_id disable_notification message_id jq_obj
    	
    	# Lê os parâmetros da função
    	local param=$(getopt --name "$FUNCNAME" \
							 --options 'c:f:n:m:' \
    						 --longoptions 'chat_id:,
    										from_chat_id:,
    										disable_notification:,
    										message_id:' \
    						 -- "$@")
    
    	
    	# Define os parâmetros posicionais
    	eval set -- "$param"
    
    	while :
    	do
    		case $1 in
    			-c|--chat_id)
    				chat_id="$2"
    				shift 2
    				;;
    			-f|--from_chat_id)
    				from_chat_id="$2"
    				shift 2
    				;;
    			-n|--disable_notification)
    				# Tipo: boolean
    				CheckArgType bool "$1" "$2"
    				disable_notification="$2"
    				shift 2
    				;;
    			-m|--message_id)
    				# Tipo: inteiro
    				CheckArgType int "$1" "$2"
    				message_id="$2"
    				shift 2
    				;;
    			--)
    				shift
    				break
    				;;
    		esac
    	done
    	
    	# Parâmetros obrigatórios.
    	[[ $chat_id ]] || MessageError API "$_ERR_PARAM_REQUIRED_" "[-c, --chat_id]"
    	[[ $from_chat_id ]] || MessageError API "$_ERR_PARAM_REQUIRED_" "[-f, --from_chat_id]"
    	[[ $message_id ]] || MessageError API "$_ERR_PARAM_REQUIRED_" "[-m, --message_id]"
    
    	# Chama o método
    	jq_obj=$(curl $_CURL_OPT_ POST $_API_TELEGRAM_/${FUNCNAME#*.} ${chat_id:+-d chat_id="$chat_id"} \
    		 						 ${from_chat_id:+-d from_chat_id="$from_chat_id"} \
    								 ${disable_notification:+-d disable_notification="$disable_notification"} \
    								 ${message_id:+-d message_id="$message_id"})
    	
    	# Retorno do método
    	JsonStatus $jq_obj && MethodReturn $jq_obj || MessageError TG $jq_obj
    
    	# status
    	return $?
    }
    
    # Utilize essa função para enviar fotos.
    ShellBot.sendPhoto()
    {
    	# Variáveis locais
    	local chat_id photo caption disable_notification reply_to_message_id reply_markup jq_obj
    
    	# Lê os parâmetros da função
    	local param=$(getopt --name "$FUNCNAME" \
							 --options 'c:p:t:n:r:k:' \
    						 --longoptions 'chat_id:, 
    										photo:,
    										caption:,
    										disable_notification:,
    										reply_to_message_id:,
    										reply_markup:' \
    						 -- "$@")
    
    
    	# Define os parâmetros posicionais
    	eval set -- "$param"
    
    	while :
    	do
    		case $1 in
    			-c|--chat_id)
    				chat_id="$2"
    				shift 2
    				;;
    			-p|--photo)
					CheckArgType file "$1" "$2"
    				photo="$2"
    				shift 2
    				;;
    			-t|--caption)
    				# Limite máximo de caracteres: 200
    				caption="$2"
    				shift 2
    				;;
    			-n|--disable_notification)
    				# Tipo: boolean
    				CheckArgType bool "$1" "$2"
    				disable_notification="$2"
    				shift 2
    				;;
    			-r|--reply_to_message_id)
    				# Tipo: inteiro
    				CheckArgType int "$1" "$2"
    				reply_to_message_id="$2"
    				shift 2
    				;;
    			-k|--reply_markup)
    				reply_markup="$2"
    				shift 2
    				;;
    			--)
    				shift
    				break
    				;;
    		esac
    	done
    	
    	# Parâmetros obrigatórios
    	[[ $chat_id ]] || MessageError API "$_ERR_PARAM_REQUIRED_" "[-c, --chat_id]"
    	[[ $photo ]] || MessageError API "$_ERR_PARAM_REQUIRED_" "[-p, --photo]"
    	
    	# Chama o método
    	jq_obj=$(curl $_CURL_OPT_ POST $_API_TELEGRAM_/${FUNCNAME#*.} ${chat_id:+-F chat_id="$chat_id"} \
    								 ${photo:+-F photo="$photo"} \
    								 ${caption:+-F caption="$caption"} \
    								 ${disable_notification:+-F disable_notification="$disable_notification"} \
    								 ${reply_to_message_id:+-F reply_to_message_id="$reply_to_message_id"} \
    								 ${reply_markup:+-F reply_markup="$reply_markup"})
    	
    	# Retorno do método
    	JsonStatus $jq_obj && MethodReturn $jq_obj || MessageError TG $jq_obj
    
    	# Status
    	return $?
    }
    
    # Utilize essa função para enviar arquivos de audio.
    ShellBot.sendAudio()
    {
    	# Variáveis locais
    	local chat_id audio caption duration performer title disable_notification reply_to_message_id reply_markup jq_obj
    	
    	# Lê os parâmetros da função
    	local param=$(getopt --name "$FUNCNAME" \
							 --options 'c:a:t:d:e:i:n:r:k' \
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
    	eval set -- "$param"
    
    	while :
    	do
    		case $1 in
    			-c|--chat_id)
    				chat_id="$2"
    				shift 2
    				;;
    			-a|--audio)
					CheckArgType file "$1" "$2"
    				audio="$2"
    				shift 2
    				;;
    			-t|--caption)
    				caption="$2"
    				shift 2
    				;;
    			-d|--duration)
    				# Tipo: inteiro
    				CheckArgType int "$1" "$2"
    				duration="$2"
    				shift 2
    				;;
    			-e|--performer)
    				performer="$2"
    				shift 2
    				;;
    			-i|--title)
    				title="$2"
    				shift 2
    				;;
    			-n|--disable_notification)
    				# Tipo: boolean
    				CheckArgType bool "$1" "$2"
    				disable_notification="$2"
    				shift 2
    				;;
    			-r|--reply_to_message_id)
    				# Tipo: inteiro
    				CheckArgType int "$1" "$2"
    				reply_to_message_id="$2"
    				shift 2
    				;;
    			-k|--reply_markup)
    				reply_markup="$2"
    				shift 2
    				;;
    			--)
    				shift
    				break
    				;;
    		esac
    	done
    	
    	# Parâmetros obrigatórios
    	[[ $chat_id ]] || MessageError API "$_ERR_PARAM_REQUIRED_" "[-c, --chat_id]"
    	[[ $audio ]] || MessageError API "$_ERR_PARAM_REQUIRED_" "[-a, --audio]"
    	
    	# Chama o método
    	jq_obj=$(curl $_CURL_OPT_ POST $_API_TELEGRAM_/${FUNCNAME#*.} ${chat_id:+-F chat_id="$chat_id"} \
    								 ${audio:+-F audio="$audio"} \
    								 ${caption:+-F caption="$caption"} \
    								 ${duration:+-F duration="$duration"} \
    								 ${performer:+-F performer="$performer"} \
    								 ${title:+-F title="$title"} \
    								 ${disable_notification:+-F disable_notification="$disable_notification"} \
    								 ${reply_to_message_id:+-F reply_to_message_id="$reply_to_message_id"} \
    								 ${reply_markup:+-F reply_markup="$reply_markup"})
    
    	# Retorno do método
    	JsonStatus $jq_obj && MethodReturn $jq_obj || MessageError TG $jq_obj
    
    	# Status
    	return $?
    		
    }
    
    # Utilize essa função para enviar documentos.
    ShellBot.sendDocument()
    {
    	# Variáveis locais
    	local chat_id document caption disable_notification reply_to_message_id reply_markup jq_obj
    	
    	# Lê os parâmetros da função
    	local param=$(getopt --name "$FUNCNAME" \
							 --options 'c:d:t:n:r:k:' \
    						 --longoptions 'chat_id:,
											document:,
    										caption:,
    										disable_notification:,
    										reply_to_message_id:,
    										reply_markup:' \
    						 -- "$@")
    
    	
    	# Define os parâmetros posicionais
    	eval set -- "$param"
    
    	while :
    	do
    		case $1 in
    			-c|--chat_id)
    				chat_id="$2"
    				shift 2
    				;;
    			-d|--document)
					CheckArgType file "$1" "$2"
    				document="$2"
    				shift 2
    				;;
    			-t|--caption)
    				caption="$2"
    				shift 2
    				;;
    			-n|--disable_notification)
    				CheckArgType bool "$1" "$2"
    				disable_notification="$2"
    				shift 2
    				;;
    			-r|--reply_to_message_id)
    				CheckArgType int "$1" "$2"
    				reply_to_message_id="$2"
    				shift 2
    				;;
    			-k|--reply_markup)
    				reply_MARKUP="$2"
    				shift 2
    				;;
    			--)
    				shift
    				break
    				;;
    		esac
    	done
    	
    	# Parâmetros obrigatórios
    	[[ $chat_id ]] || MessageError API "$_ERR_PARAM_REQUIRED_" "[-c, --chat_id]"
    	[[ $document ]] || MessageError API "$_ERR_PARAM_REQUIRED_" "[-d, --document]"
    	
    	# Chama o método
    	jq_obj=$(curl $_CURL_OPT_ POST $_API_TELEGRAM_/${FUNCNAME#*.} ${chat_id:+-F chat_id="$chat_id"} \
    								 ${document:+-F document="$document"} \
    								 ${caption:+-F caption="$caption"} \
    								 ${disable_notification:+-F disable_notification="$disable_notification"} \
    								 ${reply_to_message_id:+-F reply_to_message_id="$reply_to_message_id"} \
    								 ${reply_markup:+-F reply_markup="$reply_markup"})
    
    	# Retorno do método
    	JsonStatus $jq_obj && MethodReturn $jq_obj || MessageError TG $jq_obj
    
    	# Status
    	return $?
    	
    }
    
    # Utilize essa função para enviat stickers
    ShellBot.sendSticker()
    {
    	# Variáveis locais
    	local chat_id sticker disable_notification reply_to_message_id reply_markup jq_obj
    
    	# Lê os parâmetros da função
    	local param=$(getopt --name "$FUNCNAME" \
							 --options 'c:s:n:r:k:' \
    						 --longoptions 'chat_id:,
    										sticker:,
    										disable_notification:,
    										reply_to_message_id:,
    										reply_markup:' \
    						 -- "$@")
    
    	# Define os parâmetros posicionais
    	eval set -- "$param"
    
    	while :
    	do
    		case $1 in
    			-c|--chat_id)
    				chat_id="$2"
    				shift 2
    				;;
    			-s|--sticker)
					CheckArgType file "$1" "$2"
    				sticker="$2"
    				shift 2
    				;;
    			-n|--disable_notification)
    				# Tipo: boolean
    				CheckArgType bool "$1" "$2"
    				disable_notification="$2"
    				shift 2
    				;;
    			-r|--reply_to_message_id)
    				# Tipo: inteiro
    				CheckArgType int "$1" "$2"
    				reply_to_message_id="$2"
    				shift 2
    				;;
    			-k|--reply_markup)
    				reply_markup="$2"
    				shift 2
    				;;
    			--)
    				shift
    				break
    				;;
    		esac
    	done
    	
    	# Parâmetros obrigatórios
    	[[ $chat_id ]] || MessageError API "$_ERR_PARAM_REQUIRED_" "[-c, --chat_id]"
    	[[ $sticker ]] || MessageError API "$_ERR_PARAM_REQUIRED_" "[-s, --sticker]"
    
    	# Chama o método
    	jq_obj=$(curl $_CURL_OPT_ POST $_API_TELEGRAM_/${FUNCNAME#*.} ${chat_id:+-F chat_id="$chat_id"} \
    								 ${sticker:+-F sticker="$sticker"} \
    								 ${disable_notification:+-F disable_notification="$disable_notification"} \
    								 ${reply_to_message_id:+-F reply_to_message_id="$reply_to_message_id"} \
    								 ${reply_markup:+-F reply_markup="$reply_markup"})
    
    	# Testa o retorno do método
    	JsonStatus $jq_obj && MethodReturn $jq_obj || MessageError TG $jq_obj
    
    	# Status
    	return $?
    }
   
	ShellBot.getStickerSet()
	{
		local name jq_obj
		
		local param=$(getopt --name "$FUNCNAME" \
							 --options 'n:' \
							 --longoptions 'name:' \
							 -- "$@")
		
		# parâmetros posicionais
		eval set -- "$param"

		while :
		do
			case $1 in
				-n|--name)
					name="$2"
					shift 2
					;;
				--)
					shift
					break
					;;
			esac
		done
    	
		[[ $name ]] || MessageError API "$_ERR_PARAM_REQUIRED_" "[-n, --name]"
    	
		jq_obj=$(curl $_CURL_OPT_ GET $_API_TELEGRAM_/${FUNCNAME#*.} ${name:+-d name="$name"})
    
		# Testa o retorno do método
    	JsonStatus $jq_obj && MethodReturn $jq_obj || MessageError TG $jq_obj
    
    	# Status
    	return $?
	} 
	
	ShellBot.uploadStickerFile()
	{
		local user_id png_sticker jq_obj
		
		local param=$(getopt --name "$FUNCNAME" \
							 --options 'u:s:' \
							 --longoptions 'user_id:,
											png_sticker:' \
							 -- "$@")
		
		eval set -- "$param"
		
		while :
		do
			case $1 in
				-u|--user_id)
    				CheckArgType int "$1" "$2"
					user_id="$2"
					shift 2
					;;
				-s|--png_sticker)
					CheckArgType file "$1" "$2"
					png_sticker="$2"
					shift 2
					;;
				--)
					shift
					break
					;;
				esac
		done

		[[ $user_id ]] || MessageError API "$_ERR_PARAM_REQUIRED_" "[-u, --user_id]"
		[[ $png_sticker ]] || MessageError API "$_ERR_PARAM_REQUIRED_" "[-s, --png_sticker]"
    	
		jq_obj=$(curl $_CURL_OPT_ POST $_API_TELEGRAM_/${FUNCNAME#*.} ${user_id:+-F user_id="$user_id"} \
									 ${png_sticker:+-F png_sticker="$png_sticker"})
    	
		# Testa o retorno do método
    	JsonStatus $jq_obj && MethodReturn $jq_obj || MessageError TG $jq_obj
    
    	# Status
    	return $?
					
	}

	ShellBot.setStickerPositionInSet()
	{
		local sticker position jq_obj

		local param=$(getopt --name "$FUNCNAME" \
							 --options 's:p:' \
							 --longoptions 'sticker:,
											position:' \
							 -- "$@")
		
		eval set -- "$param"

		while :
		do
			case $1 in
				-s|--sticker)
					sticker="$2"
					shift 2
					;;
				-p|--position)
					CheckArgType int "$1" "$2"
					position="$2"
					shift 2
					;;
				--)
					shift
					break
					;;
			esac
		done
		
		[[ $sticker ]] || MessageError API "$_ERR_PARAM_REQUIRED_" "[-s, --sticker]"
		[[ $position ]] || MessageError API "$_ERR_PARAM_REQUIRED_" "[-p, --position]"
    	
		jq_obj=$(curl $_CURL_OPT_ POST $_API_TELEGRAM_/${FUNCNAME#*.} ${sticker:+-d sticker="$sticker"} \
									 ${position:+-d position="$position"})
    	
		# Testa o retorno do método
    	JsonStatus $jq_obj && MethodReturn $jq_obj || MessageError TG $jq_obj
    
		# Status
    	return $?
				
	}
	
	ShellBot.deleteStickerFromSet()
	{
		local sticker jq_obj

		local param=$(getopt --name "$FUNCNAME" \
							 --options 's:' \
							 --longoptions 'sticker:' \
							 -- "$@")
		
		eval set -- "$param"

		while :
		do
			case $1 in
				-s|--sticker)
					sticker="$2"
					shift 2
					;;
				--)
					shift
					break
					;;
			esac
		done
		
		[[ $sticker ]] || MessageError API "$_ERR_PARAM_REQUIRED_" "[-s, --sticker]"
    	
		jq_obj=$(curl $_CURL_OPT_ POST $_API_TELEGRAM_/${FUNCNAME#*.} ${sticker:+-d sticker="$sticker"})
    	
		# Testa o retorno do método
    	JsonStatus $jq_obj && MethodReturn $jq_obj || MessageError TG $jq_obj
    	
		# Status
    	return $?
				
	}
	
	ShellBot.stickerMaskPosition()
	{

		local point x_shift y_shift scale zoom
		
		local param=$(getopt --name "$FUNCNAME" \
							 --options 'p:x:y:s:z:' \
							 --longoptions 'point:,
											x_shift:,
											y_shift:,
											scale:,
											zoom:' \
							 -- "$@")

		eval set -- "$param"
		
		while :
		do
			case $1 in
				-p|--point)
					CheckArgType point "$1" "$2"
					point="$2"
					shift 2
					;;
				-x|--x_shift)
					CheckArgType float "$1" "$2"
					x_shift="$2"
					shift 2
					;;
				-y|--y_shift)
					CheckArgType float "$1" "$2"
					y_shift="$2"
					shift 2
					;;
				-s|--scale)
					CheckArgType float "$1" "$2"
					scale="$2"
					shift 2
					;;
				-z|--zoom)
					CheckArgType float "$1" "$2"
					zoom="$2"
					shift 2
					;;
				--)
					shift
					break
					;;
			esac
		done
		
		[[ $point ]] || MessageError API "$_ERR_PARAM_REQUIRED_" "[-p, --point]"
		[[ $x_shift ]] || MessageError API "$_ERR_PARAM_REQUIRED_" "[-x, --x_shift]"
		[[ $y_shift ]] || MessageError API "$_ERR_PARAM_REQUIRED_" "[-y, --y_shift]"
		[[ $scale ]] || MessageError API "$_ERR_PARAM_REQUIRED_" "[-s, --scale]"
		[[ $zoom ]] || MessageError API "$_ERR_PARAM_REQUIRED_" "[-z, --zoom]"
		
		cat << _EOF
{ "point": "$point", "x_shift": $x_shift, "y_shift": $y_shift, "scale": $scale, "zoom": $zoom }
_EOF

	return 0

	}

	ShellBot.createNewStickerSet()
	{
		local user_id name title png_sticker emojis contains_masks mask_position jq_obj
		
		local param=$(getopt --name "$FUNCNAME" \
							 --options 'u:n:t:s:e:c:m:' \
							 --longoptions 'user_id:,
											name:,
											title:,
											png_sticker:,
											emojis:,
											contains_mask:,
											mask_position:' \
							 -- "$@")

		eval set -- "$param"
		
		while :
		do
			case $1 in
				-u|--user_id)
					CheckArgType int "$1" "$2"
					user_id="$2"
					shift 2
					;;
				-n|--name)
					name="$2"
					shift 2
					;;
				-t|--title)
					title="$2"
					shift 2
					;;
				-s|--png_sticker)
					CheckArgType file "$1" "$2"
					png_sticker="$2"
					shift 2
					;;
				-e|--emojis)
					emojis="$2"
					shift 2
					;;
				-c|--contains_masks)
    				CheckArgType bool "$1" "$2"
					contains_masks="$2"
					shift 2
					;;
				-m|--mask_position)
					mask_position="$2"
					shift 2
					;;
				--)
					shift
					break
					;;
			esac
		done
		
		[[ $user_id ]] || MessageError API "$_ERR_PARAM_REQUIRED_" "[-u, --user_id]"
		[[ $name ]] || MessageError API "$_ERR_PARAM_REQUIRED_" "[-n, --name]"
		[[ $title ]] || MessageError API "$_ERR_PARAM_REQUIRED_" "[-t, --title]"
		[[ $png_sticker ]] || MessageError API "$_ERR_PARAM_REQUIRED_" "[-s, --png_sticker]"
		[[ $emojis ]] || MessageError API "$_ERR_PARAM_REQUIRED_" "[-e, --emojis]"
	
		jq_obj=$(curl $_CURL_OPT_ POST $_API_TELEGRAM_/${FUNCNAME#*.} ${user_id:+-F user_id="$user_id"} \
									 ${name:+-F name="$name"} \
									 ${title:+-F title="$title"} \
									 ${png_sticker:+-F png_sticker="$png_sticker"} \
									 ${emojis:+-F emojis="$emojis"} \
									 ${contains_masks:+-F contains_masks="$contains_masks"} \
									 ${mask_position:+-F mask_position="$mask_position"})
    	
		# Testa o retorno do método
    	JsonStatus $jq_obj && MethodReturn $jq_obj || MessageError TG $jq_obj
    	
		# Status
    	return $?
			
	}
	
	ShellBot.addStickerToSet()
	{
		local user_id name png_sticker emojis mask_position jq_obj
		
		local param=$(getopt --name "$FUNCNAME" \
							 --options 'u:n:s:e:m:' \
							 --longoptions 'user_id:,
											name:,
											png_sticker:,
											emojis:,
											mask_position:' \
							 -- "$@")

		eval set -- "$param"
		
		while :
		do
			case $1 in
				-u|--user_id)
					CheckArgType int "$1" "$2"
					user_id="$2"
					shift 2
					;;
				-n|--name)
					name="$2"
					shift 2
					;;
				-s|--png_sticker)
					CheckArgType file "$1" "$2"
					png_sticker="$2"
					shift 2
					;;
				-e|--emojis)
					emojis="$2"
					shift 2
					;;
				-m|--mask_position)
					mask_position="$2"
					shift 2
					;;
				--)
					shift
					break
					;;
			esac
		done
		
		[[ $user_id ]] || MessageError API "$_ERR_PARAM_REQUIRED_" "[-u, --user_id]"
		[[ $name ]] || MessageError API "$_ERR_PARAM_REQUIRED_" "[-n, --name]"
		[[ $png_sticker ]] || MessageError API "$_ERR_PARAM_REQUIRED_" "[-s, --png_sticker]"
		[[ $emojis ]] || MessageError API "$_ERR_PARAM_REQUIRED_" "[-e, --emojis]"
	
		jq_obj=$(curl $_CURL_OPT_ POST $_API_TELEGRAM_/${FUNCNAME#*.} ${user_id:+-F user_id="$user_id"} \
									 ${name:+-F name="$name"} \
									 ${png_sticker:+-F png_sticker="$png_sticker"} \
									 ${emojis:+-F emojis="$emojis"} \
									 ${mask_position:+-F mask_position="$mask_position"})
    	
		# Testa o retorno do método
    	JsonStatus $jq_obj && MethodReturn $jq_obj || MessageError TG $jq_obj
    	
		# Status
    	return $?
			
	}

    # Função para enviar arquivos de vídeo.
    ShellBot.sendVideo()
    {
    	# Variáveis locais
    	local chat_id video duration width height caption disable_notification \
				reply_to_message_id reply_markup jq_obj supports_streaming
    
    	# Lê os parâmetros da função
    	local param=$(getopt --name "$FUNCNAME" \
							 --options 'c:v:d:w:h:t:n:r:k:s:' \
							 --longoptions 'chat_id:,
    										video:,
    										duration:,
    										width:,
    										height:,
    										caption:,
    										disable_notification:,
    										reply_to_message_id:,
    										reply_markup:,
											supports_streaming:' \
    						 -- "$@")
    
    	
    	# Define os parâmetros posicionais
    	eval set -- "$param"
    
    	while :
    	do
    		case $1 in
    			-c|--chat_id)
    				chat_id="$2"
    				shift 2
    				;;
    			-v|--video)
					CheckArgType file "$1" "$2"
    				video="$2"
    				shift 2
    				;;
    			-d|--duration)
    				# Tipo: inteiro
    				CheckArgType int "$1" "$2"
    				duration="$2"
    				shift 2
    				;;
    			-w|--width)
    				# Tipo: inteiro
    				CheckArgType int "$1" "$2"
    				width="$2"
    				shift 2
    				;;
    			-h|--height)
    				# Tipo: inteiro
    				CheckArgType int "$1" "$2"
    				height="$2"
    				shift 2
    				;;
    			-t|--caption)
    				caption="$2"
    				shift 2
    				;;
    			-n|--disable_notification)
    				# Tipo: boolean
    				CheckArgType bool "$1" "$2"
    				disable_notification="$2"
    				shift 2
    				;;
    			-r|--reply_to_message_id)
    				CheckArgType int "$1" "$2"
    				reply_to_message_id="$2"
    				shift 2
    				;;
    			-k|--reply_markup)
    				reply_markup="$2"
    				shift 2
    				;;
				-s|--supports_streaming)
    				CheckArgType bool "$1" "$2"
					supports_streaming=$2
					shift 2
					;;
    			--)
    				shift
    				break
    				;;
    		esac
    	done
    	
    	# Parâmetros obrigatórios.
    	[[ $chat_id ]] || MessageError API "$_ERR_PARAM_REQUIRED_" "[-c, --chat_id]"
    	[[ $video ]] || MessageError API "$_ERR_PARAM_REQUIRED_" "[-v, --video]"
    
    	# Chama o método
    	jq_obj=$(curl $_CURL_OPT_ POST $_API_TELEGRAM_/${FUNCNAME#*.} ${chat_id:+-F chat_id="$chat_id"} \
    								 ${video:+-F video="$video"} \
    								 ${duration:+-F duration="$duration"} \
    								 ${width:+-F width="$width"} \
    								 ${height:+-F height="$height"} \
    								 ${caption:+-F caption="$caption"} \
    								 ${disable_notification:+-F disable_notification="$disable_notification"} \
    								 ${reply_to_message_id:+-F reply_to_message_id="$reply_to_message_id"} \
    								 ${reply_markup:+-F reply_markup="$reply_markup"} \
									 ${supports_streaming:+-F supports_streaming="$supports_streaming"})
    
    	# Testa o retorno do método
    	JsonStatus $jq_obj && MethodReturn $jq_obj || MessageError TG $jq_obj
    
    	# Status
    	return $?
    	
    }
    
    # Função para enviar audio.
    ShellBot.sendVoice()
    {
    	# Variáveis locais
    	local chat_id voice caption duration disable_notification reply_to_message_id reply_markup jq_obj
    
    	# Lê os parâmetros da função
    	local param=$(getopt --name "$FUNCNAME" \
							 --options 'c:v:t:d:n:r:k:' \
    						 --longoptions 'chat_id:,
    										voice:,
    										caption:,
    										duration:,
    										disable_notification:,
    										reply_to_message_id:,
    										reply_markup:' \
    						 -- "$@")
    
    	
    	# Define os parâmetros posicionais
    	eval set -- "$param"
    
    	while :
    	do
    		case $1 in
    			-c|--chat_id)
    				chat_id="$2"
    				shift 2
    				;;
    			-v|--voice)
					CheckArgType file "$1" "$2"
    				voice="$2"
    				shift 2
    				;;
    			-t|--caption)
    				caption="$2"
    				shift 2
    				;;
    			-d|--duration)
    				# Tipo: inteiro
    				CheckArgType int "$1" "$2"
    				duration="$2"
    				shift 2
    				;;
    			-n|--disable_notification)
    				# Tipo: boolean
    				CheckArgType bool "$1" "$2"
    				disable_notification="$2"
    				shift 2
    				;;
    			-r|--reply_to_message_id)
    				# Tipo: inteiro
    				CheckArgType int "$1" "$2"
    				reply_to_message_id="$2"
    				shift 2
    				;;
    			-k|--reply_markup)
    				reply_markup="$2"
    				shift 2
    				;;
    			--)
    				shift
    				break
					;;
    		esac
    	done
    	
    	# Parâmetros obrigatórios.
    	[[ $chat_id ]] || MessageError API "$_ERR_PARAM_REQUIRED_" "[-c, --chat_id]"
    	[[ $voice ]] || MessageError API "$_ERR_PARAM_REQUIRED_" "[-v, --voice]"
    	
    	# Chama o método
    	jq_obj=$(curl $_CURL_OPT_ POST $_API_TELEGRAM_/${FUNCNAME#*.} ${chat_id:+-F chat_id="$chat_id"} \
    								 ${voice:+-F voice="$voice"} \
    								 ${caption:+-F caption="$caption"} \
    								 ${duration:+-F duration="$duration"} \
    								 ${disable_notification:+-F disable_notification="$disable_notification"} \
    								 ${reply_to_message_id:+-F reply_to_message_id="$reply_to_message_id"} \
    								 ${reply_markup:+-F reply_markup="$reply_markup"})
    
    	# Testa o retorno do método
    	JsonStatus $jq_obj && MethodReturn $jq_obj || MessageError TG $jq_obj
    
    	# Status
    	return $?
    	
    }
    
    # Função utilizada para enviar uma localidade utilizando coordenadas de latitude e longitude.
    ShellBot.sendLocation()
    {
    	# Variáveis locais
    	local chat_id latitude longitude live_period
		local disable_notification reply_to_message_id reply_markup jq_obj
    
    	# Lê os parâmetros da função
    	local param=$(getopt --name "$FUNCNAME" \
							 --options 'c:l:g:p:n:r:k:' \
    						 --longoptions 'chat_id:,
    										latitude:,
    										longitude:,
											live_period:,
    										disable_notification:,
    										reply_to_message_id:,
    										reply_markup:' \
    						 -- "$@")
    
    	
    	# Define os parâmetros posicionais
    	eval set -- "$param"
    	
    	while :
    	do
    		case $1 in
    			-c|--chat_id)
    				chat_id="$2"
    				shift 2
    				;;
    			-l|--latitude)
    				# Tipo: float
    				CheckArgType float "$1" "$2"
    				latitude="$2"
    				shift 2
    				;;
    			-g|--longitude)
    				# Tipo: float
    				CheckArgType float "$1" "$2"
    				longitude="$2"
    				shift 2
    				;;
				-p|--live_period)
    				CheckArgType int "$1" "$2"
					live_period="$2"
					shift 2
					;;
    			-n|--disable_notification)
    				# Tipo: boolean
    				CheckArgType bool "$1" "$2"
    				disable_notification="$2"
    				shift 2
    				;;
    			-r|--reply_to_message_id)
    				# Tipo: inteiro
    				CheckArgType int "$1" "$2"
    				reply_to_message_id="$2"
    				shift 2
    				;;
    			-k|--reply_markup)
    				reply_markup="$2"
    				shift 2
    				;;
    			--)
    				shift
    				break
					;;
    		esac
    	done
    	
    	# Parâmetros obrigatórios
    	[[ $chat_id ]] || MessageError API "$_ERR_PARAM_REQUIRED_" "[-c, --chat_id]"
    	[[ $latitude ]] || MessageError API "$_ERR_PARAM_REQUIRED_" "[-l, --latitude]"
    	[[ $longitude ]] || MessageError API "$_ERR_PARAM_REQUIRED_" "[-g, --longitude]"
    			
    	# Chama o método
    	jq_obj=$(curl $_CURL_OPT_ POST $_API_TELEGRAM_/${FUNCNAME#*.} ${chat_id:+-F chat_id="$chat_id"} \
    								 ${latitude:+-F latitude="$latitude"} \
    								 ${longitude:+-F longitude="$longitude"} \
									 ${live_period:+-F live_period="$live_period"} \
    								 ${disable_notification:+-F disable_notification="$disable_notification"} \
    								 ${reply_to_message_id:+-F reply_to_message_id="$reply_to_message_id"} \
    								 ${reply_markup:+-F reply_markup="$reply_markup"})
    
    	# Testa o retorno do método
    	JsonStatus $jq_obj && MethodReturn $jq_obj || MessageError TG $jq_obj
    
    	return $?
    	
    }
    
    # Função utlizada para enviar detalhes de um local.
    ShellBot.sendVenue()
    {
    	# Variáveis locais
    	local chat_id latitude longitude title address foursquare_id disable_notification reply_to_message_id reply_markup jq_obj
    	
    	# Lê os parâmetros da função
    	local param=$(getopt --name "$FUNCNAME" \
							 --options 'c:l:g:i:a:f:n:r:k:' \
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
    	eval set -- "$param"
    	
    	while :
    	do
    		case $1 in
    			-c|--chat_id)
    				chat_id="$2"
    				shift 2
    				;;
    			-l|--latitude)
    				# Tipo: float
    				CheckArgType float "$1" "$2"
    				latitude="$2"
    				shift 2
    				;;
    			-g|--longitude)
    				# Tipo: float
    				CheckArgType float "$1" "$2"
    				longitude="$2"
    				shift 2
    				;;
    			-i|--title)
    				title="$2"
    				shift 2
    				;;
    			-a|--address)
    				address="$2"
    				shift 2
    				;;
    			-f|--foursquare_id)
    				foursquare_id="$2"
    				shift 2
    				;;
    			-n|--disable_notification)
    				# Tipo: boolean
    				CheckArgType bool "$1" "$2"
    				disable_notification="$2"
    				shift 2
    				;;
    			-r|--reply_to_message_id)
    				# Tipo: inteiro
    				CheckArgType int "$1" "$2"
    				reply_to_message_id="$2"
    				shift 2
    				;;
    			-k|--reply_markup)
    				reply_markup="$2"
    				shift 2
    				;;
    			--)
    				shift
    				break
					;;
    		esac
    	done
    			
    	# Parâmetros obrigatórios.
    	[[ $chat_id ]] || MessageError API "$_ERR_PARAM_REQUIRED_" "[-c, --chat_id]"
    	[[ $latitude ]] || MessageError API "$_ERR_PARAM_REQUIRED_" "[-l, --latitude]"
    	[[ $longitude ]] || MessageError API "$_ERR_PARAM_REQUIRED_" "[-g, --longitude]"
    	[[ $title ]] || MessageError API "$_ERR_PARAM_REQUIRED_" "[-i, --title]"
    	[[ $address ]] || MessageError API "$_ERR_PARAM_REQUIRED_" "[-a, --address]"
    	
    	# Chama o método
    	jq_obj=$(curl $_CURL_OPT_ POST $_API_TELEGRAM_/${FUNCNAME#*.} ${chat_id:+-F chat_id="$chat_id"} \
    								 ${latitude:+-F latitude="$latitude"} \
    								 ${longitude:+-F longitude="$longitude"} \
    								 ${title:+-F title="$title"} \
    								 ${address:+-F address="$address"} \
    								 ${foursquare_id:+-F foursquare_id="$foursquare_id"} \
    								 ${disable_notification:+-F disable_notification="$disable_notification"} \
    								 ${reply_to_message_id:+-F reply_to_message_id="$reply_to_message_id"} \
    								 ${reply_markup:+-F reply_markup="$reply_markup"})
    
    	# Testa o retorno do método
    	JsonStatus $jq_obj && MethodReturn $jq_obj || MessageError TG $jq_obj
    
    	# Status
    	return $?
    }
    
    # Utilize essa função para enviar um contato + numero
    ShellBot.sendContact()
    {
    	# Variáveis locais
    	local chat_id phone_number first_name last_name disable_notification reply_to_message_id reply_markup jq_obj
    	
    	# Lê os parâmetros da função
    	local param=$(getopt --name "$FUNCNAME" \
							 --options 'c:p:f:l:n:r:k:' \
    						 --longoptions 'chat_id:,
    										phone_number:,
    										first_name:,
    										last_name:,
    										disable_notification:,
    										reply_to_message_id:,
    										reply_markup:' \
    						 -- "$@")
    
    
    	# Define os parâmetros posicionais
    	eval set -- "$param"
    
    	while :
    	do
    		case $1 in
    			-c|--chat_id)
    				chat_id="$2"
    				shift 2
    				;;
    			-p|--phone_number)
    				phone_number="$2"
    				shift 2
    				;;
    			-f|--first_name)
    				first_name="$2"
    				shift 2
    				;;
    			-l|--last_name)
    				last_name="$2"
    				shift 2
    				;;
    			-n|--disable_notification)
    				# Tipo: boolean
    				CheckArgType bool "$1" "$2"
    				disable_notification="$2"
    				shift 2
    				;;
    			-r|--reply_to_message_id)
    				# Tipo: inteiro
    				CheckArgType int "$1" "$2"
    				reply_to_message_id="$2"
    				shift 2
    				;;
    			-k|--reply_markup)
    				reply_markup="$2"
    				shift 2
    				;;
    			--)
    				shift
    				break
					;;
    		esac
    	done
    	
    	# Parâmetros obrigatórios.	
    	[[ $chat_id ]] || MessageError API "$_ERR_PARAM_REQUIRED_" "[-c, --chat_id]"
    	[[ $phone_number ]] || MessageError API "$_ERR_PARAM_REQUIRED_" "[-p, --phone_number]"
    	[[ $first_name ]] || MessageError API "$_ERR_PARAM_REQUIRED_" "[-f, --first_name]"
    	
    	# Chama o método
    	jq_obj=$(curl $_CURL_OPT_ POST $_API_TELEGRAM_/${FUNCNAME#*.} ${chat_id:+-F chat_id="$chat_id"} \
    								 ${phone_number:+-F phone_number="$phone_number"} \
    								 ${first_name:+-F first_name="$first_name"} \
    								 ${last_name:+-F last_name="$last_name"} \
    								 ${disable_notification:+-F disable_notification="$disable_notification"} \
    								 ${reply_to_message_id:+-F reply_to_message_id="$reply_to_message_id"} \
    								 ${reply_markup:+-F reply_markup="$reply_markup"})
    
    	# Testa o retorno do método
    	JsonStatus $jq_obj && MethodReturn $jq_obj || MessageError TG $jq_obj
    
    	# Status
    	return $?
    }
    
    # Envia uma ação para bot.
    ShellBot.sendChatAction()
    {
    	# Variáveis locais
    	local chat_id action jq_obj
    	
    	# Lê os parâmetros da função
    	local param=$(getopt --name "$FUNCNAME" \
							 --options 'c:a:' \
    						 --longoptions 'chat_id:,
    										action:' \
    						 -- "$@")
    
    	# Define os parâmetros posicionais
    	eval set -- "$param"
    
    	while :
    	do
    		case $1 in
    			-c|--chat_id)
    				chat_id="$2"
    				shift 2
    				;;
    			-a|--action)
    				CheckArgType action "$1" "$2"
    				action="$2"
    				shift 2
    				;;
    			--)
    				shift
    				break
					;;
    		esac
    	done
    
    	# Parâmetros obrigatórios.		
    	[[ $chat_id ]] || MessageError API "$_ERR_PARAM_REQUIRED_" "[-c, --chat_id]"
    	[[ $action ]] || MessageError API "$_ERR_PARAM_REQUIRED_" "[-a, --action]"
    	
    	# Chama o método
    	jq_obj=$(curl $_CURL_OPT_ POST $_API_TELEGRAM_/${FUNCNAME#*.} ${chat_id:+-d chat_id="$chat_id"} \
    													${action:+-d action="$action"})
    	
    	# Testa o retorno do método
    	JsonStatus $jq_obj && MethodReturn $jq_obj || MessageError TG $jq_obj
    
    	# Status
    	return $?
    }
    
    # Utilize essa função para obter as fotos de um determinado usuário.
    ShellBot.getUserProfilePhotos()
    {
    	# Variáveis locais 
    	local user_id offset limit ind last index max item total jq_obj
    
    	# Lê os parâmetros da função
    	local param=$(getopt --name "$FUNCNAME" \
							 --options 'u:o:l:' \
    						 --longoptions 'user_id:,
    										offset:,
    										limit:' \
    						 -- "$@")
    
    	
    	# Define os parâmetros posicionais
    	eval set -- "$param"
    	
    	while :
    	do
    		case $1 in
    			-u|--user_id)
    				CheckArgType int "$1" "$2"
    				user_id="$2"
    				shift 2
    				;;
    			-o|--offset)
    				CheckArgType int "$1" "$2"
    				offset="$2"
    				shift 2
    				;;
    			-l|--limit)
    				CheckArgType int "$1" "$2"
    				limit="$2"
    				shift 2
    				;;
    			--)
    				shift
    				break
    				;;
    		esac
    	done
    	
    	# Parâmetros obrigatórios.
    	[[ $user_id ]] || MessageError API "$_ERR_PARAM_REQUIRED_" "[-u, --user_id]"
    	
    	# Chama o método
    	jq_obj=$(curl $_CURL_OPT_ GET $_API_TELEGRAM_/${FUNCNAME#*.} ${user_id:+-d user_id="$user_id"} \
    													${offset:+-d offset="$offset"} \
    													${limit:+-d limit="$limit"})
  
    	# Verifica se ocorreu erros durante a chamada do método	
    	JsonStatus $jq_obj && MethodReturn $jq_obj || MessageError TG $jq_obj
    	
    	# Status
    	return $?
    }
    
    # Função para listar informações do arquivo especificado.
    ShellBot.getFile()
    {
    	# Variáveis locais
    	local file_id jq_obj
    
    	# Lê os parâmetros da função
    	local param=$(getopt --name "$FUNCNAME" \
							 --options 'f:' \
    						 --longoptions 'file_id:' \
    						 -- "$@")
    
    	
    	# Define os parâmetros posicionais
    	eval set -- "$param"
    
    	while :
    	do
    		case $1 in
    			-f|--file_id)
    				file_id="$2"
    				shift 2
    				;;
    			--)
    				shift
    				break
    				;;
    		esac
    	done
    	
    	# Parâmetros obrigatórios.
    	[[ $file_id ]] || MessageError API "$_ERR_PARAM_REQUIRED_" "[-f, --file_id]"
    	
    	# Chama o método.
    	jq_obj=$(curl $_CURL_OPT_ GET $_API_TELEGRAM_/${FUNCNAME#*.} ${file_id:+-d file_id="$file_id"})
    
    	# Testa o retorno do método.
    	JsonStatus $jq_obj && MethodReturn $jq_obj || MessageError TG $jq_obj
    
    	# Status
    	return $?
    }		
    
    # Essa função kicka o usuário do chat ou canal. (somente administradores)
    ShellBot.kickChatMember()
    {
    	# Variáveis locais
    	local chat_id user_id until_date jq_obj
    
    	# Lê os parâmetros da função
    	local param=$(getopt --name "$FUNCNAME" \
							 --options 'c:u:d:' \
    						 --longoptions 'chat_id:,
    										user_id:,
    										until_date:' \
    						 -- "$@")
    
    	# Define os parâmetros posicionais
    	eval set -- "$param"
    
    	# Trata os parâmetros
    	while :
    	do
    		case $1 in
    			-c|--chat_id)
    				chat_id="$2"
    				shift 2
    				;;
    			-u|--user_id)
    				CheckArgType int "$1" "$2"
    				user_id="$2"
    				shift 2
    				;;
    			-d|--until_date)
    				CheckArgType int "$1" "$2"
    				until_date="$2"
    				shift 2
    				;;
    			--)
    				shift
    				break
    				;;
    		esac
    	done
    	
    	# Parametros obrigatórios.
    	[[ $chat_id ]] || MessageError API "$_ERR_PARAM_REQUIRED_" "[-c, --chat_id]"
    	[[ $user_id ]] || MessageError API "$_ERR_PARAM_REQUIRED_" "[-u, --user_id]"
    	
    	# Chama o método
    	jq_obj=$(curl $_CURL_OPT_ POST $_API_TELEGRAM_/${FUNCNAME#*.} ${chat_id:+-d chat_id="$chat_id"} \
    								 ${user_id:+-d user_id="$user_id"} \
    								 ${until_date:+-d until_date="$until_date"})
    
    	# Verifica se ocorreu erros durante a chamada do método	
    	JsonStatus $jq_obj && MethodReturn $jq_obj || MessageError TG $jq_obj
    
    	# Status
    	return $?
    }
    
    # Utilize essa função para remove o bot do grupo ou canal.
    ShellBot.leaveChat()
    {
    	# Variáveis locais
    	local chat_id jq_obj
    
    	# Lê os parâmetros da função
    	local param=$(getopt --name "$FUNCNAME" \
							 --options 'c:' \
    						 --longoptions 'chat_id:' \
    						 -- "$@")
    
    	
    	# Define os parâmetros posicionais
    	eval set -- "$param"
    
    	while :
    	do
    		case $1 in
    			-c|--chat_id)
    				chat_id="$2"
    				shift 2
    				;;
    			--)
    				shift
    				break
    				;;
    		esac
    	done
    
    	[[ $chat_id ]] || MessageError API "$_ERR_PARAM_REQUIRED_" "[-c, --chat_id]"
    	
    	jq_obj=$(curl $_CURL_OPT_ POST $_API_TELEGRAM_/${FUNCNAME#*.} ${chat_id:+-d chat_id="$chat_id"})
    
    	# Verifica se ocorreu erros durante a chamada do método	
    	JsonStatus $jq_obj && MethodReturn $jq_obj || MessageError TG $jq_obj
    
    	return $?
    	
    }
    
    ShellBot.unbanChatMember()
    {
    	local chat_id user_id jq_obj
    
    	# Lê os parâmetros da função
    	local param=$(getopt --name "$FUNCNAME" \
							 --options 'c:u:' \
    						 --longoptions 'chat_id:,
    										user_id:' \
    						 -- "$@")
    
    	
    	# Define os parâmetros posicionais
    	eval set -- "$param"
    
    	while :
    	do
    		case $1 in
    			-c|--chat_id)
    				chat_id="$2"
    				shift 2
    				;;
    			-u|--user_id)
    				CheckArgType int "$1" "$2"
    				user_id="$2"
    				shift 2
    				;;
    			--)
    				shift
    				break
    				;;
    		esac
    	done
    	
    	[[ $chat_id ]] || MessageError API "$_ERR_PARAM_REQUIRED_" "[-c, --chat_id]"
    	[[ $user_id ]] || MessageError API "$_ERR_PARAM_REQUIRED_" "[-u, --user_id]"
    	
    	jq_obj=$(curl $_CURL_OPT_ POST $_API_TELEGRAM_/${FUNCNAME#*.} ${chat_id:+-d chat_id="$chat_id"} \
    								 ${user_id:+-d user_id="$user_id"})
    
    	# Verifica se ocorreu erros durante a chamada do método	
    	JsonStatus $jq_obj && MethodReturn $jq_obj || MessageError TG $jq_obj
    
    	return $?
    }
    
    ShellBot.getChat()
    {
    	# Variáveis locais
    	local chat_id jq_obj
    
    	# Lê os parâmetros da função
    	local param=$(getopt --name "$FUNCNAME" \
							 --options 'c:' \
    						 --longoptions 'chat_id:' \
    						 -- "$@")
    
    	
    	# Define os parâmetros posicionais
    	eval set -- "$param"
    
    	while :
    	do
    		case $1 in
    			-c|--chat_id)
    				chat_id="$2"
    				shift 2
    				;;
    			--)
    				shift
    				break
    				;;
    		esac
    	done
    
    	[[ $chat_id ]] || MessageError API "$_ERR_PARAM_REQUIRED_" "[-c, --chat_id]"
    	
    	jq_obj=$(curl $_CURL_OPT_ GET $_API_TELEGRAM_/${FUNCNAME#*.} ${chat_id:+-d chat_id="$chat_id"})
    
    	# Verifica se ocorreu erros durante a chamada do método	
    	JsonStatus $jq_obj && MethodReturn $jq_obj || MessageError TG $jq_obj
    	
    	# Status
    	return $?
    }
    
    ShellBot.getChatAdministrators()
    {
    	local chat_id total key index jq_obj
    
    	# Lê os parâmetros da função
    	local param=$(getopt --name "$FUNCNAME" \
							 --options 'c:' \
    						 --longoptions 'chat_id:' \
    						 -- "$@")
    
    	
    	# Define os parâmetros posicionais
    	eval set -- "$param"
    
    	while :
    	do
    		case $1 in
    			-c|--chat_id)
    				chat_id="$2"
    				shift 2
    				;;
    			--)
    				shift
    				break
    				;;
    		esac
    	done
    
    	[[ $chat_id ]] || MessageError API "$_ERR_PARAM_REQUIRED_" "[-c, --chat_id]"
    	
    	jq_obj=$(curl $_CURL_OPT_ GET $_API_TELEGRAM_/${FUNCNAME#*.} ${chat_id:+-d chat_id="$chat_id"})
    
    	# Verifica se ocorreu erros durante a chamada do método	
    	JsonStatus $jq_obj && MethodReturn $jq_obj || MessageError TG $jq_obj
    
    	# Status	
    	return $?
    }
    
    ShellBot.getChatMembersCount()
    {
    	local chat_id jq_obj
    
    	# Lê os parâmetros da função
    	local param=$(getopt --name "$FUNCNAME" \
							 --options 'c:' \
    						 --longoptions 'chat_id:' \
    						 -- "$@")
    
    	
    	# Define os parâmetros posicionais
    	eval set -- "$param"
    
    	while :
    	do
    		case $1 in
    			-c|--chat_id)
    				chat_id="$2"
    				shift 2
    				;;
    			--)
    				shift
    				break
    				;;
    		esac
    	done
    
    	[[ $chat_id ]] || MessageError API "$_ERR_PARAM_REQUIRED_" "[-c, --chat_id]"
    	
    	jq_obj=$(curl $_CURL_OPT_ GET $_API_TELEGRAM_/${FUNCNAME#*.} ${chat_id:+-d chat_id="$chat_id"})
    
    	# Verifica se ocorreu erros durante a chamada do método	
    	JsonStatus $jq_obj && MethodReturn $jq_obj || MessageError TG $jq_obj
    
    	return $?
    }
    
    ShellBot.getChatMember()
    {
    	# Variáveis locais
    	local chat_id user_id jq_obj
    
    	# Lê os parâmetros da função
    	local param=$(getopt --name "$FUNCNAME" \
							 --options 'c:u:' \
    						 --longoptions 'chat_id:,
    						 				user_id:' \
    						 -- "$@")
    
    	
    	# Define os parâmetros posicionais
    	eval set -- "$param"
    
    	while :
    	do
    		case $1 in
    			-c|--chat_id)
    				chat_id="$2"
    				shift 2
    				;;
    			-u|--user_id)
    				CheckArgType int "$1" "$2"
    				user_id="$2"
    				shift 2
    				;;
    			--)
    				shift
    				break
    				;;
    		esac
    	done
    	
    	[[ $chat_id ]] || MessageError API "$_ERR_PARAM_REQUIRED_" "[-c, --chat_id]"
    	[[ $user_id ]] || MessageError API "$_ERR_PARAM_REQUIRED_" "[-u, --user_id]"
    	
    	jq_obj=$(curl $_CURL_OPT_ GET $_API_TELEGRAM_/${FUNCNAME#*.} ${chat_id:+-d chat_id="$chat_id"} \
    								${user_id:+-d user_id="$user_id"})
    
    	# Verifica se ocorreu erros durante a chamada do método	
    	JsonStatus $jq_obj && MethodReturn $jq_obj || MessageError TG $jq_obj
    
    	return $?
    }
    
    ShellBot.editMessageText()
    {
    	local chat_id message_id inline_message_id text parse_mode disable_web_page_preview reply_markup jq_obj
    	
    	local param=$(getopt --name "$FUNCNAME" \
							 --options 'c:m:i:t:p:w:r:' \
    						 --longoptions 'chat_id:,
    										message_id:,
    										inline_message_id:,
    										text:,
    										parse_mode:,
    										disable_web_page_preview:,
    										reply_markup:' \
    						 -- "$@")
    	
    	eval set -- "$param"
    
    	while :
    	do
    			case $1 in
    				-c|--chat_id)
    					chat_id="$2"
    					shift 2
    					;;
    				-m|--message_id)
    					CheckArgType int "$1" "$2"
    					message_id="$2"
    					shift 2
    					;;
    				-i|--inline_message_id)
    					CheckArgType int "$1" "$2"
    					inline_message_id="$2"
    					shift 2
    					;;
    				-t|--text)
    					text="$2"
    					shift 2
    					;;
    				-p|--parse_mode)
    					CheckArgType parsemode "$1" "$2"
    					parse_mode="$2"
    					shift 2
    					;;
    				-w|--disable_web_page_preview)
    					CheckArgType bool "$1" "$2"
    					disable_web_page_preview="$2"
    					shift 2
    					;;
    				-r|--reply_markup)
    					reply_markup="$2"
    					shift 2
    					;;
    				--)
    					shift
    					break
						;;
    			esac
    	done
    	
    	[[ $text ]] || MessageError API "$_ERR_PARAM_REQUIRED_" "[-t, --text]"
		[[ $inline_message_id ]] && unset chat_id message_id || {
			[[ $chat_id ]] || MessageError API "$_ERR_PARAM_REQUIRED_" "[-c, --chat_id]"
			[[ $message_id ]] || MessageError API "$_ERR_PARAM_REQUIRED_" "[-m, --message_id]"
		}
    	
    
    	jq_obj=$(curl $_CURL_OPT_ POST $_API_TELEGRAM_/${FUNCNAME#*.} ${chat_id:+-d chat_id="$chat_id"} \
    								 ${message_id:+-d message_id="$message_id"} \
    								 ${inline_message_id:+-d inline_message_id="$inline_message_id"} \
    								 ${text:+-d text="$text"} \
    								 ${parse_mode:+-d parse_mode="$parse_mode"} \
    								 ${disable_web_page_preview:+-d disable_web_page_preview="$disable_web_page_preview"} \
    								 ${reply_markup:+-d reply_markup="$reply_markup"})
    
    	# Verifica se ocorreu erros durante a chamada do método	
    	JsonStatus $jq_obj && MethodReturn $jq_obj || MessageError TG $jq_obj
    	
    	return $?
    	
    }
    
    ShellBot.editMessageCaption()
    {
    	local chat_id message_id inline_message_id caption reply_markup jq_obj
    	
    	local param=$(getopt --name "$FUNCNAME" \
							 --options 'c:m:i:t:r:' \
    						 --longoptions 'chat_id:,
    										message_id:,
    										inline_message_id:,
    										caption:,
    										reply_markup:' \
    						 -- "$@")
    	
    	eval set -- "$param"
    
    	while :
    	do
    			case $1 in
    				-c|--chat_id)
    					chat_id="$2"
    					shift 2
    					;;
    				-m|--message_id)
    					CheckArgType int "$1" "$2"
    					message_id="$2"
    					shift 2
    					;;
    				-i|--inline_message_id)
    					CheckArgType int "$1" "$2"
    					inline_message_id="$2"
    					shift 2
    					;;
    				-t|--caption)
    					caption="$2"
    					shift 2
    					;;
    				-r|--reply_markup)
    					reply_markup="$2"
    					shift 2
    					;;
    				--)
    					shift
    					break
						;;
    			esac
    	done
    				
    	[[ $chat_id ]] || MessageError API "$_ERR_PARAM_REQUIRED_" "[-c, --chat_id]"
    	[[ $message_id ]] || MessageError API "$_ERR_PARAM_REQUIRED_" "[-m, --message_id]"
    	
    	jq_obj=$(curl $_CURL_OPT_ POST $_API_TELEGRAM_/${FUNCNAME#*.} ${chat_id:+-d chat_id="$chat_id"} \
    								 ${message_id:+-d message_id="$message_id"} \
    								 ${inline_message_id:+-d inline_message_id="$inline_message_id"} \
    								 ${caption:+-d caption="$caption"} \
    								 ${reply_markup:+-d reply_markup="$reply_markup"})
    
    	# Verifica se ocorreu erros durante a chamada do método	
    	JsonStatus $jq_obj && MethodReturn $jq_obj || MessageError TG $jq_obj
    	
    	return $?
    	
    }
    
    ShellBot.editMessageReplyMarkup()
    {
    	local chat_id message_id inline_message_id reply_markup jq_obj
    	
    	local param=$(getopt --name "$FUNCNAME" \
							 --options 'c:m:i:r:' \
    						 --longoptions 'chat_id:,
    										message_id:,
    										inline_message_id:,
    										reply_markup:' \
    						 -- "$@")
    	
    	eval set -- "$param"
    
    	while :
    	do
    			case $1 in
    				-c|--chat_id)
    					chat_id="$2"
    					shift 2
    					;;
    				-m|--message_id)
    					CheckArgType int "$1" "$2"
    					message_id="$2"
    					shift 2
    					;;
    				-i|--inline_message_id)
    					CheckArgType int "$1" "$2"
    					inline_message_id="$2"
    					shift 2
    					;;
    				-r|--reply_markup)
    					reply_markup="$2"
    					shift 2
    					;;
    				--)
    					shift
    					break
						;;
    			esac
    	done
		
		[[ $inline_message_id ]] && unset chat_id message_id || {
			[[ $chat_id ]] || MessageError API "$_ERR_PARAM_REQUIRED_" "[-c, --chat_id]"
			[[ $message_id ]] || MessageError API "$_ERR_PARAM_REQUIRED_" "[-m, --message_id]"
		}
    
    	jq_obj=$(curl $_CURL_OPT_ POST $_API_TELEGRAM_/${FUNCNAME#*.} ${chat_id:+-d chat_id="$chat_id"} \
    								 ${message_id:+-d message_id="$message_id"} \
     								 ${inline_message_id:+-d inline_message_id="$inline_message_id"} \
    								 ${reply_markup:+-d reply_markup="$reply_markup"})
    
    	# Verifica se ocorreu erros durante a chamada do método	
    	JsonStatus $jq_obj && MethodReturn $jq_obj || MessageError TG $jq_obj
    	
    	return $?
    	
    }
    
    ShellBot.deleteMessage()
    {
    	local chat_id message_id jq_obj
    	
    	local param=$(getopt --name "$FUNCNAME" \
							 --options 'c:m:' \
    						 --longoptions 'chat_id:,
    										message_id:' \
    						 -- "$@")
    	
    	eval set -- "$param"
    
    	while :
    	do
    			case $1 in
    				-c|--chat_id)
    					chat_id="$2"
    					shift 2
    					;;
    				-m|--message_id)
    					CheckArgType int "$1" "$2"
    					message_id="$2"
    					shift 2
    					;;
    				--)
    					shift
    					break
						;;
    			esac
    	done
    	
    	[[ $chat_id ]] || MessageError API "$_ERR_PARAM_REQUIRED_" "[-c, --chat_id]"
    	[[ $message_id ]] || MessageError API "$_ERR_PARAM_REQUIRED_" "[-m, --message_id]"
    
    	jq_obj=$(curl $_CURL_OPT_ POST $_API_TELEGRAM_/${FUNCNAME#*.} ${chat_id:+-d chat_id="$chat_id"} \
    								 ${message_id:+-d message_id="$message_id"})
    
    	# Verifica se ocorreu erros durante a chamada do método	
    	JsonStatus $jq_obj && MethodReturn $jq_obj || MessageError TG $jq_obj
    	
    	return $?
    
    }
   
	ShellBot.downloadFile() {
	
		local file_path dir
		local uri="https://api.telegram.org/file/bot$_TOKEN_"

		local param=$(getopt --name "$FUNCNAME" \
								--options 'f:d:' \
								--longoptions 'file_path:,
												dir:' \
								-- "$@")
		
		eval set -- "$param"

		while :
		do
			case $1 in
				-f|--file_path)
					file_path="$2"
					shift 2
					;;
				-d|--dir)
					[[ -d $2 ]] && {
						[[ -w $2 ]] || MessageError API "$_ERR_DIR_WRITE_DENIED_" "$1" "$2"
					} || MessageError API "$_ERR_DIR_NOT_FOUND_" "$1" "$2"
					dir="${2%/}"
					shift 2
					;;
				--)
					shift
					break
					;;
			esac
		done

		[[ $file_path ]] || MessageError API "$_ERR_PARAM_REQUIRED_" "[-f, --file_path]"
		[[ $dir ]] || MessageError API "$_ERR_PARAM_REQUIRED_" "[-d, --dir]"

		dir=$(mktemp -u --tmpdir="$dir" "file$(date +%d%m%Y%H%M%S)-XXXXX${ext:+.$ext}")
		wget "$uri/$file_path" -O "$dir" &>/dev/null || MessageError API "$_ERR_FILE_DOWNLOAD_" "$file_path"
				
		return $?
	}

	ShellBot.editMessageLiveLocation()
	{
		local chat_id message_id inline_message_id
		local latitude longitude reply_markup jq_obj
		
		local param=$(getopt --name "$FUNCNAME" \
								--options 'c:m:i:l:g:r:' \
								--longoptions 'chat_id:,
												message_id:,
												inline_message_id:,
												latitude:,
												longitude:,
												reply_markup:' \
								-- "$@")
		
		eval set -- "$param"

		while :
		do
			case $1 in
				-c|--chat_id)
					chat_id="$2"
					shift 2
					;;
				-m|--message_id)
    				CheckArgType int "$1" "$2"
					message_id="$2"
					shift 2
					;;
    			-i|--inline_message_id)
					CheckArgType int "$1" "$2"
					inline_message_id="$2"
					shift 2
					;;
    			-l|--latitude)
    				# Tipo: float
    				CheckArgType float "$1" "$2"
    				latitude="$2"
    				shift 2
    				;;
    			-g|--longitude)
    				# Tipo: float
    				CheckArgType float "$1" "$2"
    				longitude="$2"
    				shift 2
    				;;
    			-r|--reply_markup)
    				reply_markup="$2"
    				shift 2
    				;;
    			--)
    				shift
    				break
					;;
			esac
		done
	
		[[ $inline_message_id ]] && unset chat_id message_id || {
			[[ $chat_id ]] || MessageError API "$_ERR_PARAM_REQUIRED_" "[-c, --chat_id]"
			[[ $message_id ]] || MessageError API "$_ERR_PARAM_REQUIRED_" "[-m, --message_id]"
		}
    	
		jq_obj=$(curl $_CURL_OPT_ POST $_API_TELEGRAM_/${FUNCNAME#*.} ${chat_id:+-d chat_id="$chat_id"} \
									 ${message_id:+-d message_id="$message_id"} \
									 ${inline_message_id:+-d inline_message_id="$inline_message_id"} \
    								 ${latitude:+-d latitude="$latitude"} \
    								 ${longitude:+-d longitude="$longitude"} \
    								 ${reply_markup:+-d reply_markup="$reply_markup"})
    
    	# Testa o retorno do método
    	JsonStatus $jq_obj && MethodReturn $jq_obj || MessageError TG $jq_obj
    
    	return $?
	}	

	ShellBot.stopMessageLiveLocation()
	{
		local chat_id message_id inline_message_id reply_markup jq_obj
		
		local param=$(getopt --name "$FUNCNAME" \
								--options 'c:m:i:r:' \
								--longoptions 'chat_id:,
												message_id:,
												inline_message_id:,
												reply_markup:' \
								-- "$@")
		
		eval set -- "$param"

		while :
		do
			case $1 in
				-c|--chat_id)
					chat_id="$2"
					shift 2
					;;
				-m|--message_id)
    				CheckArgType int "$1" "$2"
					message_id="$2"
					shift 2
					;;
    			-i|--inline_message_id)
					CheckArgType int "$1" "$2"
					inline_message_id="$2"
					shift 2
					;;
    			-r|--reply_markup)
    				reply_markup="$2"
    				shift 2
    				;;
    			--)
    				shift
    				break
					;;
			esac
		done
	
		[[ $inline_message_id ]] && unset chat_id message_id || {
			[[ $chat_id ]] || MessageError API "$_ERR_PARAM_REQUIRED_" "[-c, --chat_id]"
			[[ $message_id ]] || MessageError API "$_ERR_PARAM_REQUIRED_" "[-m, --message_id]"
		}
    	
		jq_obj=$(curl $_CURL_OPT_ POST $_API_TELEGRAM_/${FUNCNAME#*.} ${chat_id:+-d chat_id="$chat_id"} \
									 ${message_id:+-d message_id="$message_id"} \
									 ${inline_message_id:+-d inline_message_id="$inline_message_id"} \
    								 ${reply_markup:+-d reply_markup="$reply_markup"})
    
    	# Testa o retorno do método
    	JsonStatus $jq_obj && MethodReturn $jq_obj || MessageError TG $jq_obj
    
    	return $?
	}

	ShellBot.setChatStickerSet()
	{
		local chat_id sticker_set_name jq_obj

		local param=$(getopt --name "$FUNCNAME" \
								--options 'c:s:' \
								--longoptions 'chat_id:,
												sticker_set_name:' \
								-- "$@")
		
		eval set -- "$param"
		
		while :
		do
			case $1 in
				-c|--chat_id)
					chat_id="$2"
					shift 2
					;;
				-s|--sticker_set_name)
					sticker_set_name="$2"
					shift 2
					;;
				--)
					shift
					break
					;;
			esac
		done

		[[ $chat_id ]] || MessageError API "$_ERR_PARAM_REQUIRED_" "[-c, --chat_id]"
		[[ $sticker_set_name ]] || MessageError API "$_ERR_PARAM_REQUIRED_" "[-s, --sticker_set_name]"
		
		jq_obj=$(curl $_CURL_OPT_ POST $_API_TELEGRAM_/${FUNCNAME#*.} ${chat_id:+-d chat_id="$chat_id"} \
																		${sticker_set_name:+-d sticker_set_name="$sticker_set_name"})
		
    	JsonStatus $jq_obj && MethodReturn $jq_obj || MessageError TG $jq_obj
    	
		return $?
	}

	ShellBot.deleteChatStickerSet()
	{
		local chat_id jq_obj

		local param=$(getopt --name "$FUNCNAME" \
								--options 'c:' \
								--longoptions 'chat_id:' \
								-- "$@")
		
		eval set -- "$param"
		
		while :
		do
			case $1 in
				-c|--chat_id)
					chat_id="$2"
					shift 2
					;;
				--)
					shift
					break
					;;
			esac
		done

		[[ $chat_id ]] || MessageError API "$_ERR_PARAM_REQUIRED_" "[-c, --chat_id]"
		
		jq_obj=$(curl $_CURL_OPT_ POST $_API_TELEGRAM_/${FUNCNAME#*.} ${chat_id:+-d chat_id="$chat_id"})
		
    	JsonStatus $jq_obj && MethodReturn $jq_obj || MessageError TG $jq_obj
    	
    	return $?
	}

	ShellBot.inputMediaPhoto()
	{
		local __media __caption __album __delm
		
		local __param=$(getopt --name "$FUNCNAME" \
								--options 'a:m:c:' \
								--longoptions 'album:,
												media:,
												caption:' \
								-- "$@")
	
	
		eval set -- "$__param"
		
		while :
		do
			case $1 in
				-a|--album)
					CheckArgType var "$1" "$2"
					__album="$2"
					shift 2
					;;
				-m|--media)
					CheckArgType file "$1" "$2"
					__media="$2"
					shift 2
					;;
				-c|--caption)
					__caption="$2"
					shift 2
					;;
				--)
					shift
					break
					;;
			esac
		done

		[[ $__album ]] || MessageError API "$_ERR_PARAM_REQUIRED_" "[-a, --album]"
		[[ $__media ]] || MessageError API "$_ERR_PARAM_REQUIRED_" "[-m, --media]"

		declare -n __album

    	__album=${__album#[}
    	__album=${__album%]}
    
    	[[ $__album ]] && __delm=','
    
    	__album+="$__delm{\"type\":\"photo\","
		__album+="\"media\":\"$__media\""
		__album+="${__caption:+,\"caption\":\"$__caption\"}}"
    	
    	__album=${__album/#/[}
		__album=${__album/%/]}

		return 0
	}
	
	ShellBot.inputMediaVideo()
	{
		local __media __album __delm
		local __width __height __duration __caption __supports_streaming
		
		local __param=$(getopt --name "$FUNCNAME" \
								--options 'a:m:c:w:h:d:s:' \
								--longoptions 'album:,
												media:,
												caption:,
												width:,
												height:,
												duration:,
												supports_streaming:' \
								-- "$@")
	
	
		eval set -- "$__param"
		
		while :
		do
			case $1 in
				-a|--album)
					CheckArgType var "$1" "$2"
					__album="$2"
					shift 2
					;;
				-m|--media)
					CheckArgType file "$1" "$2"
					__media="$2"
					shift 2
					;;
				-c|--caption)
					__caption="$2"
					shift 2
					;;
				-w|--width)
					CheckArgType int "$1" "$2"
					__width="$2"
					shift 2
					;;
				-h|--height)
					CheckArgType int "$1" "$2"
					__height="$2"
					shift 2
					;;
				-d|--duration)
					CheckArgType int "$1" "$2"
					__duration="$2"
					shift 2
					;;
				-s|--supports_streaming)
					CheckArgType bool "$1" "$2"
					__supports_streaming="$2"
					shift 2
					;;
				--)
					shift
					break
					;;
			esac
		done

		[[ $__album ]] || MessageError API "$_ERR_PARAM_REQUIRED_" "[-a, --album]"
		[[ $__media ]] || MessageError API "$_ERR_PARAM_REQUIRED_" "[-m, --media]"

		declare -n __album

    	__album=${__album#[}
    	__album=${__album%]}
    
    	[[ $__album ]] && __delm=','
    
		__album+="$__delm{\"type\":\"video\","
		__album+="\"media\":\"$__media\""
		__album+="${__caption:+,\"caption\":\"$__caption\"}"
		__album+="${__width:+,\"width\":$__width}"
		__album+="${__height:+,\"height\":$__height}"
		__album+="${__duration:+,\"duration\":$__duration}"
    	__album+="${__supports_streaming:+,\"supports_streaming\":$__supports_streaming}}"

    	__album=${__album/#/[}
		__album=${__album/%/]}

		return 0
	}

	ShellBot.sendMediaGroup()
	{
		local chat_id media disable_notification reply_to_message_id jq_obj
		
		local param=$(getopt --name "$FUNCNAME" \
								--options 'c:m:n:r:' \
								--longoptions 'chat_id:,
												media:,
												disable_notification:,
												reply_to_message_id:' \
								-- "$@")
	
		eval set -- "$param"
		
		while :
		do
			case $1 in
				-c|--chat_id)
					chat_id="$2"
					shift 2
					;;
				-m|--media)
					media="$2"
					shift 2
					;;
				-n|--disable_notification)
    				CheckArgType bool "$1" "$2"
					disable_notification="$2"
					shift 2
					;;
				-r|--reply_to_message_id)
    				CheckArgType int "$1" "$2"
    				reply_to_message_id="$2"
    				shift 2
					;;
				--)
					shift
					break
			esac
		done

		[[ $chat_id ]] || MessageError API "$_ERR_PARAM_REQUIRED_" "[-c, --chat_id]"
		[[ $media ]] || MessageError API "$_ERR_PARAM_REQUIRED_" "[-m, --media]"
		
		jq_obj=$(curl $_CURL_OPT_ POST $_API_TELEGRAM_/${FUNCNAME#*.} ${chat_id:+-F chat_id="$chat_id"} \
    								 ${media:+-F media="$media"} \
    								 ${disable_notification:+-F disable_notification="$disable_notification"} \
    								 ${reply_to_message_id:+-F reply_to_message_id="$reply_to_message_id"})
    
		# Retorno do método
    	JsonStatus $jq_obj && MethodReturn $jq_obj || MessageError TG $jq_obj
    
    	# Status
    	return $?
	}

    ShellBot.getUpdates()
    {
    	local total_keys offset limit timeout allowed_updates jq_obj

    	# Define os parâmetros da função
    	local param=$(getopt --name "$FUNCNAME" \
							 --options 'o:l:t:a:' \
    						 --longoptions 'offset:,
    										limit:,
    										timeout:,
    										allowed_updates:' \
    						 -- "$@")
    
		eval set -- "$param"

    	while :
    	do
    		case $1 in
    			-o|--offset)
    				CheckArgType int "$1" "$2"
    				offset="$2"
    				shift 2
    				;;
    			-l|--limit)
    				CheckArgType int "$1" "$2"
    				limit="$2"
    				shift 2
    				;;
    			-t|--timeout)
    				CheckArgType int "$1" "$2"
    				timeout="$2"
    				shift 2
    				;;
    			-a|--allowed_updates)
    				allowed_updates="$2"
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
    	jq_obj=$(curl $_CURL_OPT_ POST $_API_TELEGRAM_/${FUNCNAME#*.} 	${offset:+-d offset="$offset"} \
    																	${limit:+-d limit="$limit"} \
    																	${timeout:+-d timeout="$timeout"} \
    																	${allowed_updates:+-d allowed_updates="$allowed_updates"})

    	# Verifica se ocorreu erros durante a chamada do método	
    	JsonStatus $jq_obj && {
		
			# Habilita extensão globbing
			shopt -s extglob

			# Limpa as variáveis inicializadas.
			unset ${_var_init_list_//|/ }
			_var_init_list_=''
	
			# Se o modo flush estiver ativado, retorna uma coleção de objetos Json contendo as atualizações.
			[[ $_FLUSH_OFFSET_ ]] && { echo "$jq_obj"; return 0; }
    		
			[[ $(jq -r '.result|length' <<< $jq_obj) -eq 0 ]] && return 0

			local vet val var obj oldv bar ini
			
			printf -v bar '=%.s' {1..50}

			# Modo monitor
			[[ $_BOT_MONITOR_ ]] && cat << _eof
$bar
Data: $(date '+%d/%m/%Y %T')
Script: $_BOT_SCRIPT_
Bot (nome): ${_BOT_INFO_[2]}
Bot (usuario): ${_BOT_INFO_[3]}
Bot (id): ${_BOT_INFO_[1]}
_eof
    
   			# Salva e fecha o descritor de erro
			exec 5<&2
			exec 2<&-

			for obj in $(GetAllKeys $jq_obj); do
					
				vet=${obj%%.*}
				vet=${vet//[^0-9]/}
					
				var=${obj#result\[$vet\].}
				var=${var//\[+([0-9])\]/}
				var=${var//./_}
					
				declare -g $var
				local -n byref=$var # ponteiro
					
				val=$(Json ".$obj" $jq_obj)
				[[ ${byref[$vet]} ]] && byref[$vet]+=${_BOT_DELM_}${val} || byref[$vet]=$val

				[[ $_BOT_MONITOR_ ]] && {
					[[ $vet -ne $oldv || ! $ini ]] && cat << _eof
$bar
Mensagem: $((vet+1))
$bar
_eof
					printf "[ShellBot.getUpdates]: %s = '%s'\n" "$var" "$val"
				}

				unset -n byref
	
				[[ $var != @(${_var_init_list_%|}) ]] && _var_init_list_+="$var|"
				oldv=$vet
				ini=1
			done
    		
			exec 2<&5
			
			[[ $_BOT_MONITOR_ ]] && echo $bar
			[[ $_BOT_LOG_FILE_ ]] && CreateLog ${#update_id[@]} $jq_obj &

    	} || MessageError TG $jq_obj

    	# Status
    	return $?
    }
   
	# Bot métodos (somente leitura)
	declare -rf ShellBot.token \
				ShellBot.id \
				ShellBot.username \
				ShellBot.first_name \
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
				ShellBot.getStickerSet \
				ShellBot.uploadStickerFile \
				ShellBot.createNewStickerSet \
				ShellBot.addStickerToSet \
				ShellBot.setStickerPositionInSet \
				ShellBot.deleteStickerFromSet \
				ShellBot.stickerMaskPosition \
				ShellBot.downloadFile \
				ShellBot.editMessageLiveLocation \
				ShellBot.stopMessageLiveLocation \
				ShellBot.setChatStickerSet \
				ShellBot.deleteChatStickerSet \
				ShellBot.sendMediaGroup \
				ShellBot.inputMediaPhoto \
				ShellBot.inputMediaVideo \
				ShellBot.getUpdates
   
	# Retorna objetos
	echo "$(ShellBot.id)|$(ShellBot.username)|$(ShellBot.first_name)|$(((_FLUSH_OFFSET_)) && FlushOffset)"

	# status
   	return 0
}

# Funções (somente leitura)
declare -rf MessageError \
			Json \
			JsonStatus \
			FlushOffset \
			CreateUnitService \
			GetAllKeys \
			GetAllValues \
			MethodReturn \
			CheckArgType \
			CreateLog 
