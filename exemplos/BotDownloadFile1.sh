#!/bin/bash
#
# SCRIPT: BotDownloadFile.sh
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
ShellBot.init --token "$bot_token" --monitor
ShellBot.username

while :
do
	# Obtem as atualizações
	ShellBot.getUpdates --limit 100 --offset $(ShellBot.OffsetNext) --timeout 30
	
	# Lista o índice das atualizações
	for id in $(ShellBot.ListUpdates)
	do
	# Inicio thread
	(
		# Desativa download
		download_file=0

		# Lê a atualização armazenada em 'id'
    	if [ "${update_id[$id]}" ]; then
			
			# Monitora o envio de arquivos do tipo:
			#
			# 	* Documento
			#	* Foto
			# 	* Sticker
			# 	* Musica
			# 
			# Se a variável do tipo for inicializada, salva o ID do arquivo enviado em 'file_id' e ativa o download.
			[[ ${message_document_file_id[$id]} ]] && file_id=${message_document_file_id[$id]} && download_file=1
			[[ ${message_photo_file_id[$id]} ]] && file_id=${message_photo_file_id[$id]} && download_file=1
			[[ ${message_sticker_file_id[$id]} ]] && file_id=${message_sticker_file_id[$id]} && download_file=1
			[[ ${message_audio_file_id[$id]} ]] && file_id=${message_audio_file_id[$id]} && download_file=1
			
			# Verifica se o download está ativado.
			[[ $download_file -eq 1 ]] && {
				# Inicializa um array se houver mais de um ID salvo em 'file_id'.
				# (É recomendado para fotos e vídeos, pois haverá o mesmo arquivo com diversas resoluções e ID's)
				file_id=($file_id)
				# Realiza o download do arquivo no indíce 0 (zero) do array e salva no HOME do usuário.
				ShellBot.downloadFile --file_id "${file_id[0]}" --dir "$HOME" 
			}
			
			case ${message_text[$id]} in
				'/teste') # comando teste
					ShellBot.sendMessage --chat_id "${message_chat_id[$id]}" --text "Mensagem de teste."
				;;
			esac
    	fi
		) & # Utilize a thread se deseja que o bot responda a várias requisições simultâneas.
	done
	
done
#FIM
