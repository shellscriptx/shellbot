#!/bin/bash
#
# script: ReplyKeyboardMarkup2.sh
#
# Para melhor compreensão foram utilizados parâmetros longos nas funções; Podendo
# ser substituidos pelos parâmetros curtos respectivos.

# Importando API
source ShellBot.sh

# Token do bot
bot_token='<TOKEN_AQUI>'

# Inicializando o bot
ShellBot.init --token "$bot_token" --monitor --flush --return map

while :
do
	# Obtem as atualizações
	ShellBot.getUpdates --limit 100 --offset $(ShellBot.OffsetNext) --timeout 30
	
	# Lista o índice das atualizações
	for id in $(ShellBot.ListUpdates)
	do
	# Inicio thread
	(
		# Requisições somente no privado.
		[[ ${message_chat_type[$id]} != private ]] && continue

		# Gera o arquivo temporário com base no 'id' do usuário.
		CAD_ARQ=/tmp/cad.${message_from_id[$id]}

		# Verifica se a mensagem enviada pelo usuário é um comando válido.
		case ${message_text[$id]} in
			'/start')
				
				# Cria e define um botão simples.
				btn_ajuda='["❓Ajuda ❓"]'
				
				# Inicia a conversa com o bot.
				ShellBot.sendMessage	--chat_id ${message_from_id[$id]} \
										--text "Olá *${message_from_first_name[$id]}* !! em que posso ajudar?" \
										--reply_markup "$(ShellBot.ReplyKeyboardMarkup --button 'btn_ajuda' -o true)" \
										--parse_mode markdown
				;;
			'/ajuda'|'❓Ajuda ❓')

				msg='❓*Ajuda* ❓\n\n'
				msg+='*Comandos:*\n\n'
				msg+='/start - inicia conversão com bot.\n'
				msg+='/cadastro - cadastra o usuário.\n'
				msg+='/contato - envia informações para contato.\n'
				msg+='/ajuda - exibe ajuda.'

				# Envia menu de ajuda.
				ShellBot.sendMessage	--chat_id ${message_from_id[$id]} \
										--text "$msg" \
										--reply_markup "$(ShellBot.ReplyKeyboardRemove)" \
										--parse_mode markdown
				;;
			'/cadastro')

				# Cria o arquivo temporário.
				> $CAD_ARQ 

				# Primeiro campo.
				ShellBot.sendMessage	--chat_id ${message_from_id[$id]} \
										--text "Nome:" \
										--reply_markup "$(ShellBot.ForceReply)"
				;;
			'/contato')

				btn_contato=''
				# Cria e define uma configuração personalizada para cada botão.
				ShellBot.KeyboardButton --button 'btn_contato' --line 1 --text '🏠 enviar local' --request_location true
				ShellBot.KeyboardButton --button 'btn_contato' --line 2 --text '📞 enviar telefone' --request_contact true

				# Envia o teclado personalizado.
				ShellBot.sendMessage	--chat_id ${message_from_id[$id]} \
										--text '*Me ajude a encontrá-lo enviando automaticamente sua localização.*'	\
										--reply_markup "$(ShellBot.ReplyKeyboardMarkup --button 'btn_contato')" \
										--parse_mode markdown
				;;
			/*)	# Comando inválido

				# Envia uma mensagem de erro ao usuário e remove o teclado personalizado atual.
				ShellBot.sendMessage	--chat_id ${message_from_id[$id]} \
										--text '*comando inválido !!*' \
										--reply_markup "$(ShellBot.ReplyKeyboardRemove)" \
										--parse_mode markdown
				;;
		esac

		# Verifica se há respostas.
		if [[ ${message_reply_to_message_message_id[$id]} ]]; then

			# Analisa a interface de resposta.
			case ${message_reply_to_message_text[$id]} in
					'Nome:')
						# Salva os dados referentes e envia o próximo campo
						# repetindo o processo até a finalização do cadastro.
						echo "Nome: ${message_text[$id]}" >> $CAD_ARQ
						
						ShellBot.sendMessage	--chat_id ${message_from_id[$id]} \
												--text 'Endereço:' \
												--reply_markup "$(ShellBot.ForceReply)"	# Força a resposta.
						;;
					'Endereço:')
						echo "Endereço: ${message_text[$id]}" >> $CAD_ARQ
						
						# Próximo campo.
						ShellBot.sendMessage	--chat_id ${message_from_id[$id]} \
												--text 'Cidade:' \
												--reply_markup "$(ShellBot.ForceReply)"
						;;
					'Cidade:')
						echo "Cidade: ${message_text[$id]}" >> $CAD_ARQ

						# Próximo campo.
						ShellBot.sendMessage	--chat_id ${message_from_id[$id]} \
												--text 'Telefone:' \
												--reply_markup "$(ShellBot.ForceReply)"
						;;
						
					'Telefone:')
						echo "Telefone: ${message_text[$id]}" >> $CAD_ARQ

						# Finaliza o cadastro removendo o teclado personalizado atual.
						ShellBot.sendMessage	--chat_id ${message_from_id[$id]} \
												--text "✅ *Cadastro realizado com sucesso.* ✅\n\n$(< $CAD_ARQ)" \
												--parse_mode markdown
						
						# Limpa o arquivo temporário.
						> $CAD_ARQ
						;;
			esac
		fi
	) & # Utilize a thread se deseja que o bot responda a várias requisições simultâneas.
	done
done
#FIM
