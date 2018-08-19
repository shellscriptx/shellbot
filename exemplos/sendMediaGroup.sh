#!/bin/bash

# script: sendMediaGroup.sh
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

# Inicializa a variável onde será anexado as fotos/videos.
album=""

# Anexando as mídias.
# Fotos (url)
ShellBot.inputMedia --input album --type photo --media 'http://2.bp.blogspot.com/-M53JjEuGjvE/WXM2uL0QpxI/AAAAAAAAI2k/HDEa368-yecsQG7_dgCevxYoIonS4MnmgCK4BGAYYCw/w800/14650669_269510070111655_4132757982135640193_n.png' --caption "SHELL x SCRIPT (blog wallpaper)"
ShellBot.inputMedia --input album --type photo --media 'https://www.ibm.com/developerworks/mydeveloperworks/blogs/752a690f-8e93-4948-b7a3-c060117e8665/resource/BLOGS_UPLOADED_IMAGES/post-50_applinux.jpg' --caption "Família Linux (IBM)"

# Fotos (ID)
ShellBot.inputMedia --input album --type photo --media 'AgADAQADyqcxGx10kUbF0VrzCBAH-d4n9y8ABAMBhyFEYQ0EO00BAAEC' --caption "ShellBot e os Pinguins de Madagascar."
ShellBot.inputMedia --input album --type photo --media 'AgADAQADy6cxGx10kUZzXYXre8OzfbZrDDAABJKQDsFvckP4RlQAAgI' --caption "Foto do grupo no Telegram: t.me/shellscript_x"

# Vídeo (ID)
ShellBot.inputMedia --input album --type video --media 'BAADAQADEgADHXSRRgkpayiIdrXjAg' --caption 'MATRIX (Proteção de Tela)'

while :
do
	# Obtem as atualizações
	ShellBot.getUpdates --limit 100 --offset $(ShellBot.OffsetNext) --timeout 30
	
	# Lista o índice das atualizações
	for id in $(ShellBot.ListUpdates)
	do
	# Inicio thread
	(
		# Verifica se a mensagem enviada pelo usuário é um comando válido.
		case ${message_text[$id]%%@*} in
			/album) # comando
				# ação
				ShellBot.sendChatAction --chat_id ${message_chat_id[$id]} --action upload_video 

				# Envia o álbum contendo as mídias.
				ShellBot.sendMediaGroup --chat_id ${message_chat_id[$id]} --media "$album"	
			;;
		esac
	) & # Utilize a thread se deseja que o bot responda a várias requisições simultâneas.
	done
done
#FIM
