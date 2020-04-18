#!/bin/bash

# Importando API
source ShellBot.sh

# Token do bot
bot_token='371714654:AAF1Vujtoi81zjwFjpb-qdGJFspK0HuwUD0'

# Inicializando o bot
ShellBot.init --token "$bot_token" --return map --monitor

readonly TIME=(🕐 🕑 🕒 🕓 🕔 🕕 🕖 🕗 🕘 🕙 🕚 🕛)

crono(){

	local i c

	for i in {5..60..5}; do
		if [[ $i -eq 5 ]]; then
			ShellBot.sendMessage	--chat_id ${message_chat_id[$id]} \
									--text "Cronômetro...${i}s ${TIME[c++]}"
		else
			ShellBot.editMessageText 	--chat_id ${return[chat_id]} \
										--message_id ${return[message_id]} \
										--text "Cronômetro...${i}s ${TIME[c++]}"
			sleep 0.30
		fi
	done

	return
}

function dado(){
	ShellBot.sendDice --chat_id ${message_chat_id[$id]}
}

ShellBot.setMessageRules	--name 'LETREIRO' \
							--command '/banner' \
							--exec 'figlet -t SHAMAN'

ShellBot.setMessageRules	--name 'REGRA1' \
							--command '/crono' \
							--chat_type 'private' \
							--action crono

ShellBot.setMessageRules	--name 'GET_IFRIENDS_COUNT' \
							--command '/vertotalifriends' \
							--chat_type 'private' \
							--username 'x_SHAMAN_x' \
							--exec 'mysql -u ifriend-dba -r -D ifriend_v2 -p"DTg2XTD(TE0(" --host 127.0.0.1 < /home/juliano/cmd.sql' \
							--bot_reply_message 'Processando...'

ShellBot.setMessageRules	--name 'SEND_DICE' \
							--command '/test' \
							--username 'x_SHAMAN_x' \
							--action 'dado'
while :
do
  # Obtem as atualizações
  ShellBot.getUpdates --limit 100 --offset $(ShellBot.OffsetNext) --timeout 30

  # Lista o índice das atualizações
  for id in $(ShellBot.ListUpdates)
  do
  # Inicio thread
  (
    # Gerenciar regras
    ShellBot.manageRules --update_id $id

  ) & # Utilize a thread se deseja que o bot responda a várias requisições simultâneas.
  done
done
