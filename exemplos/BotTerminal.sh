#!/bin/bash
#
# script: BotTerminal.sh
#
# Para melhor compreensão foram utilizados parâmetros longos nas funções; Podendo
# ser substituidos pelos parâmetros curtos respectivos.

# Importando API
source ShellBot.sh

# Token do bot
bot_token='<TOKEN_AQUI>'

# Inicializando o bot com log.
ShellBot.init --token "$bot_token" --monitor --flush --log_file "/tmp/${0##*/}.log"
ShellBot.username

# A definição da regra a seguir utiliza uma construção curta na declaração 
# de múltiplos comandos. Aplicando o recurso de expansão de variáveis e 
# argumentos posicionais é possível criar comandos/argumentos para adequação 
# da sintaxe, podendo ser distribuida em regras e tratamentos distintos.
#
# Comandos: /who, /date, /df e /du (regex)
ShellBot.setMessageRules 	--name 'terminal_comandos' 	\
							--chat_type	private			\
							--entitie_type bot_command	\
							--text '^/(who|date|df|du)[ ]+' \
							--exec '${1#/} ${*:2}'	# Remove a barra inicial do argumento posicional '$1' (bot comando) transformando-o
													# em um comando de shell válido e passa os argumentos posicionais subsequentes.
													#
													# Exemplo:
													#
													# Exibindo o contéudo do arquivo e enumerando as respectivas linhas.
													#
													# bot comando: /cat -n /etc/group /etc/passwd
													# exec: cat -n /etc/group /etc/passwd

# A regra abaixo demonstra a construção de uma linha de comando personalizada
# que recebe os elementos do texto como argumentos.
ShellBot.setMessageRules	--name 'filtrar_arquivo' 		\
							--chat_type private				\
							--entitie_type bot_command		\
							--command '/filtrar'			\
							--num_args 3					\
							--exec 'cat "$3" | egrep "$2"'	# Utilizando os argumentos posicionais.
															#
															# Exemplo:
															#
															# bot comando: /filtrar root /etc/group
															# exec: cat "/etc/group" | egrep "root"

# Definindo uma regra que contém um comando que lista recursivamente
# o contéudo do diretório especificado.
# Obs: Dependendo do diretório informado a saída poderá ser dividida
# em várias mensagens de retorno e no pior dos cenários o possível
# excesso de requisições.
ShellBot.setMessageRules	--name 'listar_diretorio'		\
							--chat_type private				\
							--entitie_type bot_command		\
							--command '/listar'				\
							--num_args 2					\
							--exec 'ls -R $2'				# Exemplo:
															#
															# bot comando: /listar /etc
															# exec: ls -R /etc

# Aplica regra de erro caso nenhuma das regras anteriores forem satisfeitas.
ShellBot.setMessageRules	--name 'comando_invalido'		\
							--chat_type private				\
							--entitie_type bot_command		\
							--bot_reply_message 'erro: comando não encontrado.'
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
#FIM
