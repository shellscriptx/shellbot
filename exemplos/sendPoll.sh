#!/bin/bash
#
# script: sendPoll.sh
#
# Para melhor compreensão foram utilizados parâmetros longos nas funções; Podendo
# ser substituidos pelos parâmetros curtos respectivos.

# Importando API
source ShellBot.sh

# Token do bot
bot_token='<TOKEN_AQUI>'

# Inicializando o bot
ShellBot.init --token "$bot_token" --monitor --return map

function ajuda()
{
	local msg

	msg=$(cat << _eof
\U2753 *AJUDA* \U2753

/enquete - Publica uma enquete de pesquisa.
/teclado - Envia um botão para criação de enquete.
/tabuada - Publica uma enquete de teste.
/ajuda - Exibe ajuda e sai.
_eof
)

	ShellBot.sendChatAction --chat_id ${message_chat_id[$id]} --action 'typing'
	ShellBot.sendMessage	--chat_id ${message_chat_id[$id]} \
							--text "$msg" \
							--parse_mode markdown

	return 0
}

function enquete()
{
	# Opções disponíveis da enquete. (Min: 2, Max: 10)
	local arr='["Ubuntu", "Debian", "Manjaro", "CentOS", "Slackware"]'

	ShellBot.sendChatAction --chat_id ${message_chat_id[$id]} --action 'typing'

	# Envia uma enquete não anônima, ou seja, registra os usuários que participaram da votação.
	ShellBot.sendPoll	--chat_id ${message_chat_id[$id]} \
						--question 'Na sua opinião qual é a melhor distro Linux?' \
						--options "$arr" \
						--is_anonymous false \
						--type regular

	return 0
}

function teclado()
{
	local btn=''
	local msg=$(cat << _eof
\U203C *Atualmente há um coleção de distribuições Linux para cada perfil de usuário e propósito. Crie uma enquete e saiba a preferência da comunidade entre as mais populares.*  \U203C

_Para começar acesse o teclado abaixo._ \U1F447
_eof
)

	# Define o botão com a função de criação de enquete.
	ShellBot.KeyboardButton		--button 'btn' \
								--line 1 \
								--text '\U1F4CB Criar enquete' \
								--request_poll "$(ShellBot.KeyboardButtonPollType --type regular)"

	ShellBot.sendChatAction --chat_id ${message_chat_id[$id]} --action 'typing'
	ShellBot.sendMessage	--chat_id ${message_chat_id[$id]}	\
							--text "$msg" \
							--parse_mode markdown \
							--reply_markup "$(ShellBot.ReplyKeyboardMarkup --button 'btn')"

	return 0
}

function tabuada()
{
	local n ra op num1 num2 opts arr msg

	num1=$((RANDOM%9+1))	# Operando 1
	num2=$((RANDOM%9+1))	# Operando 2
	ra=$((RANDOM%3+1))		# Posição da resposta correta.
	op=('+' '-')			# Operador de variação.

	# Gera os resultados.
	for n in {0..3}; do
		if [[ $n -eq $ra ]]; then
			# Correto.
			opts[$n]=$((num1*num2))
		else
			# Incorreto.
			opts[$n]=$(((num1*num2)${op[RANDOM%2]}(RANDOM%9+n)))
		fi
	done

	# Converte os valores em um array de string.
	printf -v arr '"%s",' "${opts[@]}"
	printf -v arr '[%s]' "${arr%,}"

	msg=$(cat << _eof
\U2716 TABUADA \U2716

Vamos avaliar seu conhecimento em matemática.
Quanto é $num1 x $num2?
_eof
)
	# Ação.
	ShellBot.sendChatAction --chat_id ${message_chat_id[$id]} --action 'typing'

	# Envia enquete de teste (quiz) definindo a opção correta.
	ShellBot.sendPoll	--chat_id ${message_chat_id[$id]} \
						--question "$msg" \
						--options "$arr" \
						--is_anonymous false \
						--type quiz \
						--correct_option_id $ra
	
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
		case ${message_text[$id]} in
			'/enquete') enquete;;
			'/tabuada') tabuada;;
			'/teclado') teclado;;
			'/ajuda') ajuda;;
		esac
	) & # Utilize a thread se deseja que o bot responda a várias requisições simultâneas.
	done
done
#FIM
