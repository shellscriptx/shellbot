#!/bin/bash
#
# SCRIPT: BotDownloadFile1.sh
#
# DESCRIÇÃO: Efetua download dos arquivos enviados para o privado, grupo ou canal.
#			 Em grupos/canais o bot precisa ser administrador para ter acesso a
#			 todas mensagens enviadas.
#
# Para melhor compreensão foram utilizados parâmetros longos nas funções; Podendo
# ser substituidos pelos parâmetros curtos respectivos.

# Importando API
source ShellBot.sh

# Token do bot
bot_token='<TOKEN_AQUI>'

# Inicializando o bot
ShellBot.init --token "$bot_token" --monitor --return map

function download_file()
{
	local file_id

	if [[ ${message_photo_file_id[$id]} ]]; then
		# Em alguns arquivos de imagem o telegram aplica uma escala de tamanho
		# gerando id's para diferentes resoluções da mesma iagem. São elas (baixa, média, alta).
		# Os id's são armazenados e separados pelo delimitador '|' (padrão).
		#
		# Exemplo:
		#     baixa_id|media_id|alta_id
		
		# Extrai o id da imagem com melhor resolução.
		file_id=${message_photo_file_id[$id]##*|}
	else 
		# Outros objetos.
		# Extrai o id do objeto da mensagem.
		# document, audio, sticker, voice
		file_id=$(cat << _eof
${message_document_file_id[$id]}
${message_audio_file_id[$id]}
${message_sticker_file_id[$id]}
${message_voice_file_id[$id]}
_eof
)
	fi

	# Verifica se 'file_id' contém um id válido.	
	if [[ $file_id ]]; then
		# Obtém informações do arquivo, incluindo sua localização nos servidores do Telegram.
		ShellBot.getFile --file_id $file_id

		# Baixa o arquivo do diretório remoto contido em '{return[file_path]}' após
		# a chamada do método 'ShellBot.getFile'.
		# Obs: Recurso disponível somente no modo de retorno 'map'.
		if ShellBot.downloadFile --file_path "${return[file_path]}" --dir "$HOME"; then
			ShellBot.sendMessage	--chat_id "${message_chat_id[$id]}" \
									--reply_to_message_id "${message_message_id[$id]}" \
									--text "Arquivo baixado com sucesso!!\n\nSalvo em: ${return[file_path]}"
		fi
	fi

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
		# Executa a função 'download_file' se a requisição não for um objeto de texto.
		[[ ${message_text[$id]} ]] || download_file

	) & # Utilize a thread se deseja que o bot responda a várias requisições simultâneas.
	done
done
#FIM
