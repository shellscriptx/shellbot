#!/bin/bash

# XXX SOBRE XXX
#
# script: InlineYoutube.sh
#
# O script implementa um Bot Inline semelhante ao '@vid' que realiza
# consultas de vídeos no site do youtube.
#
# Para melhor compreensão foram utilizados parâmetros longos nas funções; Podendo
# ser substituidos pelos parâmetros curtos respectivos.
#
# XXX ATENÇÃO XXX
#
# É necessário habilitar o modo inline. Para ativar essa opção, envie o
# comando /setinline para @BotFather e forneça o texto de espaço reservado
# que o usuário verá no campo de entrada depois de digitar o nome do seu bot.

# Importando API
source ShellBot.sh

# Token do bot
bot_token='<TOKEN_AQUI>'

# Inicializando o bot
ShellBot.init --token "$bot_token" --flush --monitor --return map

yt_video()
{
	local vid title views
	local resp yt_video query vids i
	local re_vid re_vt re_vv

	yt_video='https://www.youtube.com/watch?v='			# URI
	
	# Regex
	re_vid='href="/watch\?v=([a-zA-Z0-9_-]+)"'			# ID
	re_vt='title="([^"]+)'								# Título
	re_vv='<li>([0-9.]+\s+(visualizações|views))</li>'	# Visualizações
	
	query=''

	while read -r resp; do
		# Extrai as informações do video. (se presente)
		if 	[[ $resp =~ $re_vid ]] && vid=${BASH_REMATCH[1]}	&&
			[[ $resp =~ $re_vt 	]] && title=${BASH_REMATCH[1]}  &&
			[[ $resp =~ $re_vv 	]] && views=${BASH_REMATCH[1]};	then
		
			# Salta para o próximo elemento caso já exista.
			[[ $vid == @($vids) ]] && continue
			
			# Cria/anexa o objeto video a query de resultado.
			ShellBot.InlineQueryResult 	--input query 													\
										--type video													\
										--mime_type 'video/mp4'											\
										--id "$vid"														\
										--video_url "${yt_video}${vid}"									\
										--thumb_url "https://i.ytimg.com/vi/${vid}/hqdefault.jpg"		\
										--title "${title}"												\
										--description "${views}"										\
										--input_message_content "$(ShellBot.InputMessageContent --message_text "${yt_video}${vid}")" # Envia o link caso o usuário clique no video da lista.
		
				# 50 resultados por query. (limite máximo suportado pelo Telegram)
				[[ $((++i)) -eq 50 ]] && break

				# Atualiza a lista com o objeto criado.
				vids+=${vids:+|}$vid
		fi
		# Envia uma requisição a uri de pesquisa do youtube com o video especificado na query de consulta.
	done < <(wget -qO- "https://www.youtube.com/results?search_query=${inline_query_query[$id]// /+}")

	# Envia a query com os resultados da consulta.
	ShellBot.answerInlineQuery 	--inline_query_id ${inline_query_id[$id]} 	\
								--results "$query"

	return $?
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
		# Executa a função caso uma consulta inline for iniciada.
		[[ $inline_query_id ]] && yt_video

	) & # Utilize a thread se deseja que o bot responda a várias requisições simultâneas.
	done
done
#FIM
