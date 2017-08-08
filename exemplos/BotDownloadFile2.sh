#!/bin/bash
#
# SCRIPT: BotDownloadFile2.sh
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
				# Executa o método 'ShellBot.downloadFile', captura os dados de retorno e salva em 'file_path'
				file_path=$(ShellBot.downloadFile --file_id "${file_id[0]}" --dir "$HOME") && {
					# Se o download foi bem-sucedido
					#
					# Separa as informações armazenadas em 'file_path'
					id=$(echo $file_path | cut -d'|' -f1)		# ID do arquivo
					size=$(echo $file_path | cut -d'|' -f2)		# Tamanho
					dir=$(echo $file_path | cut -d'|' -f3)		# Diretório de destino

					# Layout da mensagem
					msg='*Download do arquivo realizado com sucesso.*\n\n'
					msg+="*Informações*\n\n"
					msg+="*ID*: $id\n"
					msg+="*Tamanho*: $size bytes\n"
					msg+="*Salvo em*: $dir"
					
					# Envia a mensagem de confirmação e anexa as informações
					ShellBot.sendMessage --chat_id ${message_chat_id[$id]} \
											--text "$(echo -e "$msg")" \
											--parse_mode markdown
		
				}
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
